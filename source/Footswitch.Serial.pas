{*******************************************************************************
  Unit: Footswitch.Serial

  USB CDC footswitch link via MHumm TCommPortDriver (CPDrv / GetIt).
  Protocol: KED_SeePDFFootSw docs (P/N/PL/NL, identity SEEPDF-FS1[;version]).
*******************************************************************************}
unit Footswitch.Serial;

interface

uses
  System.SysUtils, System.Classes,
  Winapi.Windows,
  FMX.Types,
  CPDrv;

type
  TFootswitchPedal = (fpPrevShort, fpNextShort, fpPrevLong, fpNextLong);

  TFootswitchPedalEvent = procedure(Sender: TObject;
    Pedal: TFootswitchPedal) of object;
  TFootswitchNotifyEvent = procedure(Sender: TObject) of object;

  TFootswitchSerial = class
  private
    FPort: TCommPortDriver;
    FOwnsTimer: Boolean;
    FTimer: TTimer;
    FLineBuf: RawByteString;
    FSeenPorts: TStringList;
    FProbeQueue: TStringList;
    FActivePort: string;
    FFirmwareVersion: string;
    FLinked: Boolean;
    FProbing: Boolean;
    FProbeStart: TDateTime;
    FProbeDeadline: TDateTime;
    FProbeQueried: Boolean;
    FProbeQuerySent: TDateTime;
    FLastRepoke: TDateTime;
    FOnPedal: TFootswitchPedalEvent;
    FOnStatusChanged: TFootswitchNotifyEvent;
    procedure ConfigurePortDefaults;
    procedure ClearLinkState;
    procedure SetLinked(ALinked: Boolean);
    procedure NotifyStatus;
    procedure ListComPorts(APorts: TStrings);
    function PortDeviceName(const AComName: string): string;
    function ShortPortName(const ADeviceName: string): string;
    procedure FeedBytes(DataPtr: Pointer; DataSize: DWORD);
    procedure ProcessLine(const ALine: string);
    function TryParseIdentity(const ALine: string;
      out AVersion: string): Boolean;
    procedure BeginProbe(const AComName: string);
    procedure FinishProbeFailure;
    procedure FinishProbeSuccess(const AVersion: string);
    procedure QueueNewPortsForProbe;
    procedure CheckConnectedPortStillPresent;
    procedure AdvanceProbe;
    procedure TimerTick(Sender: TObject);
  public
    constructor Create(APort: TCommPortDriver; ATimer: TTimer = nil);
    destructor Destroy; override;

    procedure Start;
    procedure Stop;
    procedure FeedData(DataPtr: Pointer; DataSize: DWORD);
    procedure Tick;

    property Linked: Boolean read FLinked;
    property ActivePort: string read FActivePort;
    property FirmwareVersion: string read FFirmwareVersion;
    property OnPedal: TFootswitchPedalEvent read FOnPedal write FOnPedal;
    property OnStatusChanged: TFootswitchNotifyEvent
      read FOnStatusChanged write FOnStatusChanged;
  end; // TFootswitchSerial

implementation

uses
  System.DateUtils, System.Win.Registry,
  Configuration;

const
  CIdentityPrefix = 'SEEPDF-FS1';
  CProbeTimeoutMs = 2500;     // overall open window
  CProbeQueryDelayMs = 400;   // wait after open before '?'
  CProbeReplyWaitMs = 800;    // wait after '?' before giving up
  CProbeTimerMs = 100;        // while probing / searching
  CIdleTimerMs = 1000;        // while linked
  CRepokeLastPortMs = 3000;   // retry last port if still searching

//***************************************************************************
//
// OPERATION : Build a TCommPortDriver PortName for a short COM name.
//
// I/P       : AComName : string - e.g. 'COM5'
//
// O/P       : string - e.g. '\\.\COM5'
//
//***************************************************************************
function TFootswitchSerial.PortDeviceName(const AComName: string): string;
begin
  if AComName.StartsWith('\\.\', True) then
  begin
    Result := AComName
  end // if
  else
  begin
    Result := '\\.\' + AComName;
  end; // else
end; // PortDeviceName

//***************************************************************************
//
// OPERATION : Strip the \\.\ prefix from a device path for display / ini.
//
// I/P       : ADeviceName : string - PortName value.
//
// O/P       : string - Short COM name.
//
//***************************************************************************
function TFootswitchSerial.ShortPortName(const ADeviceName: string): string;
begin
  Result := ADeviceName;
  if Result.StartsWith('\\.\', True) then
  begin
    Result := Copy(Result, 5, MaxInt);
  end; // if
end; // ShortPortName

//***************************************************************************
//
// OPERATION : Enumerate present COM ports from the SerialComm registry map.
//
// I/P       : APorts : TStrings - Cleared and filled with names like 'COM5'.
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.ListComPorts(APorts: TStrings);
var
  reg: TRegistry;
  names: TStringList;
  i: Integer;
  value: string;

begin
  APorts.Clear;
  reg := TRegistry.Create;
  names := TStringList.Create;
  try
    reg.RootKey := HKEY_LOCAL_MACHINE;
    reg.Access := KEY_READ;
    if not reg.OpenKeyReadOnly('\Hardware\DeviceMap\SerialComm') then
    begin
      Exit;
    end; // if

    reg.GetValueNames(names);
    for i := 0 to names.Count - 1 do
    begin
      value := reg.ReadString(names[i]);
      if value.StartsWith('COM', True) then
      begin
        APorts.Add(value);
      end; // if
    end; // for
  finally
    names.Free;
    reg.Free;
  end; // try
end; // ListComPorts

//***************************************************************************
//
// OPERATION : Apply baud and framing defaults for the footswitch CDC link.
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.ConfigurePortDefaults;
begin
  if FPort.Connected then
  begin
    FPort.Disconnect;
  end; // if

  FPort.BaudRate := br115200;
  FPort.DataBits := db8BITS;
  FPort.Parity := ptNONE;
  FPort.StopBits := sb1BITS;
  FPort.HwFlow := hfNONE;
  FPort.SwFlow := sfNONE;
  FPort.PacketSize := -1;
  FPort.EnableDTROnOpen := True;
end; // ConfigurePortDefaults

//***************************************************************************
//
// OPERATION : Clear linked/probe fields without touching the COM handle.
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.ClearLinkState;
begin
  FLinked := False;
  FProbing := False;
  FProbeQueried := False;
  FActivePort := '';
  FFirmwareVersion := '';
  FLineBuf := '';
end; // ClearLinkState

//***************************************************************************
//
// OPERATION : Update linked flag and raise status when it changes.
//
// I/P       : ALinked : Boolean - New link state.
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.SetLinked(ALinked: Boolean);
begin
  if FLinked = ALinked then
  begin
    Exit;
  end; // if

  FLinked := ALinked;
  NotifyStatus;
end; // SetLinked

//***************************************************************************
//
// OPERATION : Raise OnStatusChanged when assigned.
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.NotifyStatus;
begin
  if Assigned(FOnStatusChanged) then
  begin
    FOnStatusChanged(Self);
  end; // if
end; // NotifyStatus

//***************************************************************************
//
// OPERATION : Create the footswitch helper around an existing port driver.
//
// I/P       : APort : TCommPortDriver - Form-owned CPDrv component.
//
//             ATimer : TTimer = nil - Optional form timer; if nil, one is
//             created and owned by this object (Interval 1000 ms).
//
// O/P       : None
//
//***************************************************************************
constructor TFootswitchSerial.Create(APort: TCommPortDriver;
  ATimer: TTimer = nil);
begin
  inherited Create;
  FPort := APort;
  FSeenPorts := TStringList.Create;
  FSeenPorts.Sorted := True;
  FSeenPorts.Duplicates := dupIgnore;
  FProbeQueue := TStringList.Create;
  ClearLinkState;

  if ATimer <> nil then
  begin
    FTimer := ATimer;
    FOwnsTimer := False;
  end // if
  else
  begin
    FTimer := TTimer.Create(nil);
    FTimer.Interval := 1000;
    FOwnsTimer := True;
  end; // else

  FTimer.Enabled := False;
  FTimer.Interval := CProbeTimerMs;
  FTimer.OnTimer := TimerTick;
  ConfigurePortDefaults;
end; // Create

//***************************************************************************
//
// OPERATION : Stop the link and free owned lists / timer.
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
destructor TFootswitchSerial.Destroy;
begin
  Stop;
  FreeAndNil(FProbeQueue);
  FreeAndNil(FSeenPorts);
  if FOwnsTimer then
  begin
    FreeAndNil(FTimer);
  end; // if
  inherited;
end; // Destroy

//***************************************************************************
//
// OPERATION : Begin watching for a footswitch (startup full probe + timer).
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.Start;
var
  ports: TStringList;
  i: Integer;
  lastPort: string;
  idx: Integer;

begin
  ConfigurePortDefaults;
  ClearLinkState;
  FProbeQueue.Clear;
  FSeenPorts.Clear;

  lastPort := ShortPortName(Trim(progConfig.ReadString('Footswitch', 'Port', '')));
  FLastRepoke := Now;

  ports := TStringList.Create;
  try
    ListComPorts(ports);

    // Prefer the last successful port when it is still present.
    if lastPort <> '' then
    begin
      idx := ports.IndexOf(lastPort);
      if idx >= 0 then
      begin
        FProbeQueue.Add(lastPort);
        ports.Delete(idx);
      end; // if
    end; // if

    for i := 0 to ports.Count - 1 do
    begin
      FProbeQueue.Add(ports[i]);
    end; // for

    for i := 0 to FProbeQueue.Count - 1 do
    begin
      FSeenPorts.Add(FProbeQueue[i]);
    end; // for
  finally
    ports.Free;
  end; // try

  FTimer.Enabled := True;
  NotifyStatus;
  AdvanceProbe;
end; // Start

//***************************************************************************
//
// OPERATION : Disconnect and stop the watch timer.
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.Stop;
begin
  FTimer.Enabled := False;
  FProbeQueue.Clear;
  if FPort.Connected then
  begin
    FPort.Disconnect;
  end; // if
  ClearLinkState;
  NotifyStatus;
end; // Stop

//***************************************************************************
//
// OPERATION : Accept RX bytes from the form OnReceiveData handler.
//
// I/P       : DataPtr : Pointer - Buffer from TCommPortDriver.
//
//             DataSize : DWORD - Byte count.
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.FeedData(DataPtr: Pointer; DataSize: DWORD);
begin
  FeedBytes(DataPtr, DataSize);
end; // FeedData

//***************************************************************************
//
// OPERATION : Append RX bytes and dispatch complete newline-terminated lines.
//
// I/P       : DataPtr : Pointer - Incoming bytes.
//
//             DataSize : DWORD - Count.
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.FeedBytes(DataPtr: Pointer; DataSize: DWORD);
var
  i: Integer;
  bytes: PByte;
  ch: AnsiChar;
  line: RawByteString;

begin
  if (DataPtr = nil) or (DataSize = 0) then
  begin
    Exit;
  end; // if

  bytes := DataPtr;
  for i := 0 to DataSize - 1 do
  begin
    ch := AnsiChar(bytes[i]);
    if (ch = #10) or (ch = #13) then
    begin
      if FLineBuf <> '' then
      begin
        line := FLineBuf;
        FLineBuf := '';
        ProcessLine(string(line));
      end; // if
    end // if
    else
    begin
      FLineBuf := FLineBuf + ch;
    end; // else
  end; // for
end; // FeedBytes

//***************************************************************************
//
// OPERATION : Parse SEEPDF-FS1 or SEEPDF-FS1;version identity lines.
//
// I/P       : ALine : string - Trimmed RX line.
//
// O/P       : AVersion : string - Firmware version or 'unknown'.
//
//             Boolean - True if the line is an identity banner/reply.
//
//***************************************************************************
function TFootswitchSerial.TryParseIdentity(const ALine: string;
  out AVersion: string): Boolean;
var
  rest: string;

begin
  Result := False;
  AVersion := '';
  if not ALine.StartsWith(CIdentityPrefix, True) then
  begin
    Exit;
  end; // if

  Result := True;
  rest := Copy(ALine, Length(CIdentityPrefix) + 1, MaxInt);
  if (rest <> '') and (rest[1] = ';') then
  begin
    AVersion := Copy(rest, 2, MaxInt)
  end // if
  else
  begin
    AVersion := 'unknown';
  end; // else
end; // TryParseIdentity

//***************************************************************************
//
// OPERATION : Handle one protocol line (identity or pedal event).
//
// I/P       : ALine : string - Line without CR/LF.
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.ProcessLine(const ALine: string);
var
  line: string;
  version: string;
  pedal: TFootswitchPedal;

begin
  line := Trim(ALine);
  if line = '' then
  begin
    Exit;
  end; // if

  if TryParseIdentity(line, version) then
  begin
    if FProbing or (not FLinked) then
    begin
      FinishProbeSuccess(version);
    end // if
    else
    begin
      FFirmwareVersion := version;
      NotifyStatus;
    end; // else
    Exit;
  end; // if

  if not FLinked then
  begin
    Exit;
  end; // if

  if line = 'P' then
  begin
    pedal := fpPrevShort
  end // if
  else if line = 'N' then
  begin
    pedal := fpNextShort
  end // if
  else if line = 'PL' then
  begin
    pedal := fpPrevLong
  end // if
  else if line = 'NL' then
  begin
    pedal := fpNextLong
  end // if
  else
  begin
    Exit;
  end; // else

  if Assigned(FOnPedal) then
  begin
    FOnPedal(Self, pedal);
  end; // if
end; // ProcessLine

//***************************************************************************
//
// OPERATION : Open one COM port and start the probe timeout window.
//
// I/P       : AComName : string - Short name such as 'COM5'.
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.BeginProbe(const AComName: string);
begin
  if FPort.Connected then
  begin
    FPort.Disconnect;
  end; // if

  FLineBuf := '';
  FProbing := True;
  FProbeQueried := False;
  FActivePort := AComName;
  FFirmwareVersion := '';
  FProbeStart := Now;
  FProbeDeadline := IncMilliSecond(Now, CProbeTimeoutMs);
  FPort.Port := pnCustom;
  FPort.PortName := PortDeviceName(AComName);

  if not FPort.Connect then
  begin
    FinishProbeFailure;
    Exit;
  end; // if

  NotifyStatus;
end; // BeginProbe

//***************************************************************************
//
// OPERATION : Close a failed probe and try the next queued port.
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.FinishProbeFailure;
begin
  if FPort.Connected then
  begin
    FPort.Disconnect;
  end; // if

  FProbing := False;
  FProbeQueried := False;
  FProbeQuerySent := 0;
  FActivePort := '';
  FFirmwareVersion := '';
  FLineBuf := '';
  FTimer.Interval := CProbeTimerMs;
  SetLinked(False);
  AdvanceProbe;
end; // FinishProbeFailure

//***************************************************************************
//
// OPERATION : Accept the current probe port as the live footswitch.
//
// I/P       : AVersion : string - Parsed firmware version.
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.FinishProbeSuccess(const AVersion: string);
begin
  FProbing := False;
  FProbeQueried := False;
  FProbeQueue.Clear;
  FFirmwareVersion := AVersion;
  if FActivePort <> '' then
  begin
    progConfig.WriteString('Footswitch', 'Port', ShortPortName(FActivePort));
  end; // if
  FTimer.Interval := CIdleTimerMs;
  SetLinked(True);
  NotifyStatus;
end; // FinishProbeSuccessend; // FinishProbeSuccess

//***************************************************************************
//
// OPERATION : Start the next queued probe, if any and not already probing.
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.AdvanceProbe;
var
  nextPort: string;

begin
  if FLinked or FProbing then
  begin
    Exit;
  end; // if

  if FProbeQueue.Count = 0 then
  begin
    NotifyStatus;
    Exit;
  end; // if

  nextPort := FProbeQueue[0];
  FProbeQueue.Delete(0);
  BeginProbe(nextPort);
end; // AdvanceProbe

//***************************************************************************
//
// OPERATION : Queue COM ports that appeared since the last seen snapshot.
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.QueueNewPortsForProbe;
var
  current: TStringList;
  i: Integer;
  name: string;

begin
  current := TStringList.Create;
  try
    ListComPorts(current);
    for i := 0 to current.Count - 1 do
    begin
      name := current[i];
      if FSeenPorts.IndexOf(name) < 0 then
      begin
        FProbeQueue.Add(name);
        FSeenPorts.Add(name);
      end; // if
    end; // for

    // Drop disappeared ports from the seen set so a later re-plug re-probes.
    for i := FSeenPorts.Count - 1 downto 0 do
    begin
      if current.IndexOf(FSeenPorts[i]) < 0 then
      begin
        FSeenPorts.Delete(i);
      end; // if
    end; // for
  finally
    current.Free;
  end; // try
end; // QueueNewPortsForProbe

//***************************************************************************
//
// OPERATION : If the linked COM port vanished, drop the link and rescan.
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.CheckConnectedPortStillPresent;
var
  current: TStringList;

begin
  if not FLinked then
  begin
    Exit;
  end; // if

  if (not FPort.Connected) or (FActivePort = '') then
  begin
    if FPort.Connected then
    begin
      FPort.Disconnect;
    end; // if
    ClearLinkState;
    NotifyStatus;
    QueueNewPortsForProbe;
    AdvanceProbe;
    Exit;
  end; // if

  current := TStringList.Create;
  try
    ListComPorts(current);
    if current.IndexOf(FActivePort) < 0 then
    begin
      FPort.Disconnect;
      ClearLinkState;
      NotifyStatus;
      QueueNewPortsForProbe;
      AdvanceProbe;
    end; // if
  finally
    current.Free;
  end; // try
end; // CheckConnectedPortStillPresent

//***************************************************************************
//
// OPERATION : Periodic watch: probe timeouts, hotplug, and unplug checks.
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.Tick;
var
  elapsedMs: Int64;
  lastPort: string;

begin
  if FProbing then
  begin
    elapsedMs := MilliSecondsBetween(Now, FProbeStart);

    if (not FProbeQueried) and FPort.Connected and
      (elapsedMs >= CProbeQueryDelayMs) then
    begin
      FProbeQueried := True;
      FProbeQuerySent := Now;
      FPort.SendString('?' + AnsiChar(10));
      Exit; // give RX a chance before any timeout check
    end; // if

    if FProbeQueried then
    begin
      if MilliSecondsBetween(Now, FProbeQuerySent) >= CProbeReplyWaitMs then
      begin
        FinishProbeFailure;
      end; // if
    end // if
    else if elapsedMs >= CProbeTimeoutMs then
    begin
      FinishProbeFailure;
    end; // else if
    Exit;
  end; // if

  if FLinked then
  begin
    FTimer.Interval := CIdleTimerMs;
    CheckConnectedPortStillPresent;
    Exit;
  end; // if

  FTimer.Interval := CProbeTimerMs;
  QueueNewPortsForProbe;

  // If the startup scan finished with nothing, periodically retry the
  // last-known port (it is already in FSeenPorts, so hotplug alone skips it).
  if (FProbeQueue.Count = 0) and
    (MilliSecondsBetween(Now, FLastRepoke) >= CRepokeLastPortMs) then
  begin
    FLastRepoke := Now;
    lastPort := ShortPortName(Trim(progConfig.ReadString('Footswitch', 'Port', '')));
    if lastPort <> '' then
    begin
      FProbeQueue.Add(lastPort);
    end; // if
  end; // if

  AdvanceProbe;
end; // Tick

//***************************************************************************
//
// OPERATION : Timer callback that forwards to Tick.
//
// I/P       : Sender : TObject - The timer.
//
// O/P       : None
//
//***************************************************************************
procedure TFootswitchSerial.TimerTick(Sender: TObject);
begin
  Tick;
end; // TimerTick

end. // Footswitch.Serial

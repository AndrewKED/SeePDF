{*******************************************************************************
  Unit: Main.Form

  FMX port of the VCL score viewer shell.
  Shows one PDF page, a menu button, and a status line.
*******************************************************************************}
unit Main.Form;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Dialogs,
  FMX.Controls.Presentation,
  FMX.StdCtrls,
  DX.Pdf.Viewer.FMX,
  DX.Pdf.Document,
  Pdf.PageTurn.Touch, CPDrv,
  Footswitch.Serial;

type
  TfMain = class(TForm)
    StatusBar: TStatusBar;
    StatusLabel: TLabel;
    bMenu: TButton;
    OpenDialog: TOpenDialog;
    cpDrv: TCommPortDriver;
    timEvents: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure bMenuClick(Sender: TObject);
    procedure cpDrvReceiveData(Sender: TObject; DataPtr: Pointer;
      DataSize: DWORD);
  private
    FPdfViewer: TPdfViewer;
    FCurrentPdfPath: string;
    FPageTurn: TPdfPageTurnTouch;
    FFoot: TFootswitchSerial;
    procedure CreatePdfViewer;
    procedure UpdateStatusBar;
    procedure OnPdfViewerPageChanged(Sender: TObject);
    procedure OpenSettings;
    procedure AboutInfo;
    procedure ManagePDFs;
    procedure ManageAudio;
    procedure ManageSets;
    procedure FootPedal(Sender: TObject; Pedal: TFootswitchPedal);
    procedure FootStatusChanged(Sender: TObject);
    function FootswitchStatusText: string;
  protected
    procedure LoadPdfFile(const AFilePath: string);
    procedure ProcessCommandLineParams;
  public
    procedure DragOver(const Data: TDragObject; const Point: TPointF;
      var Operation: TDragOperation); override;
    procedure DragDrop(const Data: TDragObject; const Point: TPointF); override;
  end;

var
  fMain: TfMain;

implementation

uses
  System.IOUtils,
  Configuration,
  Menu.Form, Settings.Form, ManagePDFs.Form, ManageAudio.Form, ManageSets.Form,
  About.Form,
  Font_Ops, Form_Ops;

{$R *.fmx}

//***************************************************************************
//
// OPERATION : Prepare the viewer, status line, and any PDF passed on the
//             command line.
//
// I/P       : Sender : TObject - The form being created.
//
// O/P       : None
//
//***************************************************************************
procedure TfMain.FormCreate(Sender: TObject);
begin
  Caption := 'KED PDF Viewer';

//  LoadResourceFont('FA_6_PRO_SOLID');

  LoadFormSizePosition(self, progConfig, 'Main\Form');

  FCurrentPdfPath := '';

  CreatePdfViewer;
  UpdateStatusBar;
  ProcessCommandLineParams;

  FFoot := TFootswitchSerial.Create(cpDrv, timEvents);
  FFoot.OnPedal := FootPedal;
  FFoot.OnStatusChanged := FootStatusChanged;
  FFoot.Start;
end; // FormCreate

//***************************************************************************
//
// OPERATION : Release the page-turn hook and the viewer.
//
// I/P       : Sender : TObject - The form being destroyed.
//
// O/P       : None
//
//***************************************************************************
procedure TfMain.FormDestroy(Sender: TObject);
begin
  SaveFormSizePosition(self, progConfig, 'Main\Form');

  FreeAndNil(FPageTurn);
  FreeAndNil(FFoot);
  FreeAndNil(FPdfViewer);
end; // FormDestroy

//***************************************************************************
//
// OPERATION :
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TfMain.ManagePDFs;
var
  fManagePDFs : TfManagePDFs;

begin
  fManagePDFs := TfManagePDFs.Create(Self);
  try
    if ((fManagePDFs.ShowModal = mrOk) and
        (fManagePDFs.SelectedFilePath <> '')) then
      LoadPdfFile(fManagePDFs.SelectedFilePath);
  finally
    FreeAndNil(fManagePDFs);
  end; // try
end; // ManagePDFs

//***************************************************************************
//
// OPERATION :
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TfMain.ManageAudio;
var
  fManageAudio : TfManageAudio;

begin
  fManageAudio := TfManageAudio.Create(Self);
  try
    if ((fManageAudio.ShowModal = mrOk) and
        (fManageAudio.SelectedFilePath <> '')) then
      LoadPdfFile(fManageAudio.SelectedFilePath);
  finally
    FreeAndNil(fManageAudio);
  end; // try
end; // ManagePDFs

//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
procedure TfMain.ManageSets;
begin
  if (not Assigned(fSettings)) then
  begin
    fSettings := TfSettings.Create(Self);
  end; // if
  try
    fSettings.ShowModal;
  finally
    FreeAndNil(fSettings);
  end; // try
end; // ManageSets

//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
procedure TfMain.OpenSettings;
begin
  if (not Assigned(fSettings)) then
  begin
    fSettings := TfSettings.Create(Self);
  end; // if
  try
    fSettings.ShowModal;
  finally
    FreeAndNil(fSettings);
  end; // try
end;

//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
procedure TfMain.AboutInfo;
begin
  if (not Assigned(fAbout)) then
  begin
    fAbout := TfAbout.Create(Self);
  end; // if
  try
    fAbout.ShowModal;
  finally
    FreeAndNil(fAbout);
  end; // try
end;

//***************************************************************************
//
// OPERATION : Show the operation menu and run the chosen command.
//
// I/P       : Sender : TObject - The menu button.
//
// O/P       : None
//
//***************************************************************************
procedure TfMain.bMenuClick(Sender: TObject);
begin
  if (not Assigned(fMenu)) then
  begin
    fMenu := TfMenu.Create(Self);
  end; // if
  try
    fMenu.ShowModal;
    case fMenu.idOperation of
      OP_PDFS :
        ManagePDFs;
      OP_AUDIO :
        ManageAudio;
      OP_SETS :
        ManageSets;
      OP_SETTINGS :
        OpenSettings;
      OP_EXIT :
        Close;
      OP_ABOUT :
        AboutInfo;
    end; // case
  finally
    FreeAndNil(fMenu);
  end; // try
end; // bMenuClick

//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
procedure TfMain.cpDrvReceiveData(Sender: TObject; DataPtr: Pointer;
  DataSize: DWORD);
begin
  if Assigned(FFoot) then
  begin
    FFoot.FeedData(DataPtr, DataSize);
  end; // if
end; // cpDrvReceiveData

//***************************************************************************
//
// OPERATION : Create the FMX PDF viewer and the tap/swipe page-turn hook.
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TfMain.CreatePdfViewer;
begin
  FPdfViewer := TPdfViewer.Create(Self);
  FPdfViewer.Parent := Self;
  FPdfViewer.Align := TAlignLayout.Client;
  FPdfViewer.BackgroundColor := TAlphaColors.White;
  FPdfViewer.OnPageChanged := OnPdfViewerPageChanged;
  FPdfViewer.OnClick := OnPdfViewerPageChanged;
  FPdfViewer.SendToBack;
  bMenu.BringToFront;

  FPageTurn := TPdfPageTurnTouch.Create(FPdfViewer);
end; // CreatePdfViewer

//***************************************************************************
//
// OPERATION : Load a PDF when one is passed as the first command-line
//             parameter.
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TfMain.ProcessCommandLineParams;
var
  LFilePath: string;

begin
  if ParamCount > 0 then
  begin
    LFilePath := ParamStr(1);

    if TFile.Exists(LFilePath) and
      (TPath.GetExtension(LFilePath).ToLower = '.pdf') then
    begin
      LoadPdfFile(LFilePath);
    end; // if
  end; // if
end; // ProcessCommandLineParams

//***************************************************************************
//
// OPERATION : Open a PDF file in the viewer and refresh the window title
//             and status line.
//
// I/P       : AFilePath : string - Full path of the PDF to open.
//
// O/P       : None
//
//***************************************************************************
procedure TfMain.LoadPdfFile(const AFilePath: string);
begin
  if not TFile.Exists(AFilePath) then
  begin
    ShowMessage('File not found: ' + AFilePath);
    Exit;
  end; // if

  try
    FPdfViewer.LoadFromFile(AFilePath);

    FCurrentPdfPath := AFilePath;
    Caption := 'KED PDF Viewer - ' + TPath.GetFileName(AFilePath);
    UpdateStatusBar;
    FPdfViewer.SetFocus;
  except
    on E: EPdfException do
    begin
      ShowMessage('Error loading PDF: ' + E.Message);
      UpdateStatusBar;
    end; // on
  end; // try
end; // LoadPdfFile

//***************************************************************************
//
// OPERATION : Refresh the status line after the visible page changes.
//
// I/P       : Sender : TObject - The viewer that changed page.
//
// O/P       : None
//
//***************************************************************************
procedure TfMain.OnPdfViewerPageChanged(Sender: TObject);
begin
  UpdateStatusBar;
end; // OnPdfViewerPageChanged

//***************************************************************************
//
// OPERATION : Accept a drag from Explorer when the first file is a PDF.
//             This replaces the VCL WM_DROPFILES handler.
//
// I/P       : Data : TDragObject - Drag payload, including file paths.
//
//             Point : TPointF - Pointer position over the form.
//
//             Operation : TDragOperation - Set to copy for a PDF, otherwise
//             none.
//
// O/P       : None
//
//***************************************************************************
procedure TfMain.DragOver(const Data: TDragObject; const Point: TPointF;
  var Operation: TDragOperation);
begin
  if (Length(Data.Files) > 0) and
    (TPath.GetExtension(Data.Files[0]).ToLower = '.pdf') then
  begin
    Operation := TDragOperation.Copy;
  end // if
  else
  begin
    Operation := TDragOperation.None;
  end; // else
end; // DragOver

//***************************************************************************
//
// OPERATION : Load a PDF dropped onto the form.
//
// I/P       : Data : TDragObject - Drag payload, including file paths.
//
//             Point : TPointF - Drop position over the form.
//
// O/P       : None
//
//***************************************************************************
procedure TfMain.DragDrop(const Data: TDragObject; const Point: TPointF);
begin
  if Length(Data.Files) > 0 then
  begin
    if TPath.GetExtension(Data.Files[0]).ToLower = '.pdf' then
    begin
      LoadPdfFile(Data.Files[0]);
    end // if
    else
    begin
      ShowMessage('Please drop PDF files only.');
    end; // else
  end; // if
end; // DragDrop

//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
procedure TfMain.FootPedal(Sender: TObject; Pedal: TFootswitchPedal);
begin
  if (FPdfViewer = nil) or (FPdfViewer.Document = nil) or
     (not FPdfViewer.Document.IsLoaded) then
  begin
    Exit;
  end; // if

  case Pedal of
    fpPrevShort:
      FPdfViewer.PreviousPage;
    fpNextShort:
      FPdfViewer.NextPage;
    fpPrevLong:
      FPdfViewer.FirstPage;
    fpNextLong:
      FPdfViewer.LastPage;
  end; // case
end; // FootPedal

//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
procedure TfMain.FootStatusChanged(Sender: TObject);
begin
  UpdateStatusBar;
end; // FootStatusChanged

//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
function TfMain.FootswitchStatusText: string;
begin
  if (FFoot <> nil) and FFoot.Linked then
  begin
    Result := Format('Footswitch: %s  fw %s',
      [FFoot.ActivePort, FFoot.FirmwareVersion])
  end // if
  else
  begin
    Result := 'Footswitch: searching…';
  end; // else
end; // FootswitchStatusText

//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
procedure TfMain.UpdateStatusBar;
var
  LFileName: string;
  LPdfVersion: string;
  LPdfAInfo: string;
  LStatusText: string;

begin
  if ((FCurrentPdfPath = '') or
      (FPdfViewer.Document = nil) or
      (not FPdfViewer.Document.IsLoaded)) then
  begin
    StatusLabel.Text := FootswitchStatusText;
    Exit;
  end; // if

  LFileName := TPath.GetFileName(FCurrentPdfPath);
  LPdfVersion := FPdfViewer.Document.GetFileVersionString;
  LPdfAInfo := FPdfViewer.Document.GetPdfAInfo;

  LStatusText := Format('File: %s  |  PDF Version: %s',
    [LFileName, LPdfVersion]);

  if LPdfAInfo <> '' then
  begin
    LStatusText := LStatusText + '  |  ' + LPdfAInfo;
  end; // if

  LStatusText := LStatusText + Format('  |  Page %d/%d  |  %s',
    [FPdfViewer.CurrentPageIndex + 1, FPdfViewer.PageCount,
     FootswitchStatusText]);

  StatusLabel.Text := LStatusText;
end; // UpdateStatusBar
end. // Main.Form

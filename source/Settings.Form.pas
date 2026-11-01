unit Settings.Form;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Edit, FMX.Controls.Presentation, FMX.Layouts;

type
  TfSettings = class(TForm)
    gbPDFLocation: TGroupBox;
    ePDFLocation: TEdit;
    bPDFLocation: TButton;
    GroupBox1: TGroupBox;
    eAudioLocation: TEdit;
    bAudioLocation: TButton;
    OpenDialog: TOpenDialog;
    Layout1: TLayout;
    Button1: TButton;
    procedure bPDFLocationClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure bAudioLocationClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  fSettings: TfSettings;

implementation

uses
  System.IOUtils,
{$IFDEF MSWINDOWS}
  Vcl.Dialogs,
{$ELSE}
  FMX.Dialogs,
{$ENDIF}
  Configuration;

{$R *.fmx}

//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
procedure TfSettings.bPDFLocationClick(Sender: TObject);
var
  folderDialog : TFileOpenDialog;

begin
  folderDialog := TFileOpenDialog.Create(self);
  try
    folderDialog.Options := [fdoPickfolders];
    folderDialog.DefaultFolder := progConfig.ReadString('Files', 'PDF Dir', TPath.GetDocumentsPath);
    if (folderDialog.Execute) then
    begin
      ePDFLocation.Text := folderDialog.FileName;
      progConfig.WriteString('Files', 'PDF Dir', folderDialog.FileName);
    end;
  finally
    folderDialog.Free;
  end;
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
procedure TfSettings.bAudioLocationClick(Sender: TObject);
var
  folderDialog : TFileOpenDialog;

begin
  folderDialog := TFileOpenDialog.Create(self);
  try
    folderDialog.Options := [fdoPickfolders];
    folderDialog.DefaultFolder := progConfig.ReadString('Files', 'Audio Dir', TPath.GetDocumentsPath);
    if (folderDialog.Execute) then
    begin
      eAudioLocation.Text := folderDialog.FileName;
      progConfig.WriteString('Files', 'Audio Dir', folderDialog.FileName);
    end;
  finally
    folderDialog.Free;
  end;
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
procedure TfSettings.FormCreate(Sender: TObject);
begin
  ePDFLocation.Text := progConfig.ReadString('Files', 'PDF Dir', TPath.GetDocumentsPath);
  eAudioLocation.Text := progConfig.ReadString('Files', 'Audio Dir', TPath.GetMusicPath);
end;

end.

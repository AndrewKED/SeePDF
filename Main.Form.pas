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
  Pdf.PageTurn.Touch;

type
  TfMain = class(TForm)
    StatusBar: TStatusBar;
    StatusLabel: TLabel;
    bMenu: TButton;
    OpenDialog: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure bMenuClick(Sender: TObject);
  private
    FPdfViewer: TPdfViewer;
    FCurrentPdfPath: string;
    FPageTurn: TPdfPageTurnTouch;
    procedure CreatePdfViewer;
    procedure UpdateStatusBar;
    procedure OnPdfViewerPageChanged(Sender: TObject);
    procedure OpenFile;
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
  Menu.Form;

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
  FCurrentPdfPath := '';

  CreatePdfViewer;
  UpdateStatusBar;
  ProcessCommandLineParams;
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
  FreeAndNil(FPageTurn);
  FreeAndNil(FPdfViewer);
end; // FormDestroy

//***************************************************************************
//
// OPERATION : Ask for a PDF and load it into the viewer.
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TfMain.OpenFile;
begin
  OpenDialog.Title := 'Open PDF File';
  OpenDialog.Filter := 'PDF Files (*.pdf)|*.pdf|All Files (*.*)|*.*';
  OpenDialog.DefaultExt := 'pdf';
  OpenDialog.Options := [TOpenOption.ofFileMustExist, TOpenOption.ofEnableSizing];

  if OpenDialog.Execute then
  begin
    if TPath.GetExtension(OpenDialog.FileName).ToLower = '.pdf' then
    begin
      LoadPdfFile(OpenDialog.FileName);
    end // if
    else
    begin
      ShowMessage('Please select a PDF file.');
    end; // else
  end; // if
end; // OpenFile

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
    try
      fMenu.ShowModal;
      case fMenu.idOperation of
        OP_OPEN_FILE :
          OpenFile;
        OP_SEARCH :
          ; //
        OP_SETTINGS :
          ; //
        OP_EXIT :
          Close;
        OP_ABOUT :
          ; //
      end; // case
    finally
      FreeAndNil(fMenu);
    end; // try
  end; // if
end; // bMenuClick

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
// OPERATION : Rebuild the status line from the open document.
//
// I/P       : None
//
// O/P       : None
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
    StatusLabel.Text := 'No document loaded';
    Exit;
  end; // if

  LFileName := TPath.GetFileName(FCurrentPdfPath);
  LPdfVersion := FPdfViewer.Document.GetFileVersionString;
  LPdfAInfo := FPdfViewer.Document.GetPdfAInfo;

  LStatusText := Format('File: %s  |  PDF Version: %s', [LFileName, LPdfVersion]);

  if LPdfAInfo <> '' then
    LStatusText := LStatusText + '  |  ' + LPdfAInfo;

  LStatusText := LStatusText + Format('  |  Page %d/%d',
    [FPdfViewer.CurrentPageIndex + 1, FPdfViewer.PageCount]);

  StatusLabel.Text := LStatusText;
end; // UpdateStatusBar

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

end. // Main.Form

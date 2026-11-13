program SeePDF;

{$R *.dres}

uses
  System.StartUpCopy,
  System.Classes,
  System.UITypes,
  Winapi.Windows,
  FMX.Forms,
  FMX.Dialogs,
  Main.Form in 'Source\Main.Form.pas' {fMain},
  Menu.Form in 'Source\Menu.Form.pas' {fMenu},
  Pdf.PageTurn.Touch in 'Source\Pdf.PageTurn.Touch.pas',
  DX.Pdf.API in 'E:\DC12\DX.Pdfium4D\src\DX.Pdf.API.pas',
  DX.Pdf.Document in 'E:\DC12\DX.Pdfium4D\src\DX.Pdf.Document.pas',
  DX.Pdf.Viewer.Core in 'E:\DC12\DX.Pdfium4D\src\DX.Pdf.Viewer.Core.pas',
  DX.Pdf.Viewer.FMX in 'E:\DC12\DX.Pdfium4D\src\DX.Pdf.Viewer.FMX.pas',
  DX.Pdf.Renderer.FMX in 'E:\DC12\DX.Pdfium4D\src\DX.Pdf.Renderer.FMX.pas',
  Font_Ops in '..\..\DUnits12\Font_Ops.pas',
  ManageSets.Form in 'Source\ManageSets.Form.pas' {fManageSets},
  Configuration in 'Source\Configuration.pas',
  File_Ops in '..\..\DUnits12\File_Ops.pas',
  Constants in 'Source\Constants.pas',
  Data in 'Source\Data.pas' {DataModule1: TDataModule},
  ManageAudio.Form in 'source\ManageAudio.Form.pas' {fManageAudio},
  Settings.Form in 'Source\Settings.Form.pas' {fSettings},
  Form_Ops in '..\..\DUnits12\Form_Ops.pas',
  Hash_Ops in '..\..\DUnits12\Hash_Ops.pas',
  FMX.Grid_Ops in '..\..\DUnits12\FMX.Grid_Ops.pas',
  Str_Ops in '..\..\DUnits12\Str_Ops.pas',
  About.Form in 'source\About.Form.pas' {fAbout},
  App_Ops in '..\..\DUnits12\App_Ops.pas',
  Footswitch.Serial in 'source\Footswitch.Serial.pas',
  ManagePDFs.Form in 'source\ManagePDFs.Form.pas' {fManagePDFs};

{$R *.res}
var
  fontStream : TResourceStream;
  hMutex: THandle;

begin
  hMutex := CreateMutex(nil, False, 'Local\' + ORIGINATOR + '_' + PROGRAM_NAME);

//  GlobalUseSkia := TRUE;
//
//  fontStream := TResourceStream.Create(HInstance, 'FA_6_PRO_SOLID', RT_RCDATA);
//  try
//    TSkDefaultProviders.RegisterTypeface(fontStream);
//  finally
//    fontStream.Free;
//  end; // try

(*
This works to have only one copy of the program run.  If you want the
program to reshow the form then you will have to search the windows list.
You could use API FindWindow, the Author says this routine is not reliable,
The third Approach is to search the windows lists looking for the FileName
of the executable if found then send a message to the window to become
visible.
*)
  if (WaitForSingleObject (hMutex, 0) <> wait_TimeOut) then
  begin
    Application.Initialize;
    Application.CreateForm(TfMain, fMain);
  Application.CreateForm(TDataModule1, DataModule1);
  Application.CreateForm(TfManagePDFs, fManagePDFs);
  Application.Run;
  end // if
  else
  begin
    MessageDlg(
      'Another copy of the ' + PROGRAM_NAME + ' software is already running.',
      TMsgDlgType.mtInformation, [TMsgDlgBtn.mbOK], 0
    );
  end; // else
end.

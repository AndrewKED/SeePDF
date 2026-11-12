program SeePDF;

{$R *.dres}

uses
  System.StartUpCopy,
  System.Classes,
  Winapi.Windows,
  FMX.Forms,
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
  ManageFiles.Form in 'Source\ManageFiles.Form.pas' {fManageFiles},
  Settings.Form in 'Source\Settings.Form.pas' {fSettings},
  Form_Ops in '..\..\DUnits12\Form_Ops.pas',
  Hash_Ops in '..\..\DUnits12\Hash_Ops.pas',
  FMX.Grid_Ops in '..\..\DUnits12\FMX.Grid_Ops.pas',
  Str_Ops in '..\..\DUnits12\Str_Ops.pas',
  About.Form in 'source\About.Form.pas' {fAbout},
  App_Ops in '..\..\DUnits12\App_Ops.pas',
  Footswitch.Serial in 'source\Footswitch.Serial.pas';

{$R *.res}
var
  fontStream : TResourceStream;

begin
//  GlobalUseSkia := TRUE;
//
//  fontStream := TResourceStream.Create(HInstance, 'FA_6_PRO_SOLID', RT_RCDATA);
//  try
//    TSkDefaultProviders.RegisterTypeface(fontStream);
//  finally
//    fontStream.Free;
//  end; // try

  Application.Initialize;
  Application.CreateForm(TfMain, fMain);
  Application.CreateForm(TDataModule1, DataModule1);
  Application.Run;
end.

program SeePDF;

{$R *.dres}

uses
  System.StartUpCopy,
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
  Form_Ops in '..\..\DUnits12\Form_Ops.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfMain, fMain);
  Application.CreateForm(TDataModule1, DataModule1);
  Application.CreateForm(TfManageFiles, fManageFiles);
  Application.CreateForm(TfSettings, fSettings);
  Application.Run;
end.

program SeePDF;

uses
  System.StartUpCopy,
FMX.Forms,
  Main.Form in 'Main.Form.pas' {fMain},
  Menu.Form in 'Menu.Form.pas' {fMenu},
  Pdf.PageTurn.Touch in 'Pdf.PageTurn.Touch.pas',
  DX.Pdf.API in '..\..\..\DC12\DX.Pdfium4D\src\DX.Pdf.API.pas',
  DX.Pdf.Document in '..\..\..\DC12\DX.Pdfium4D\src\DX.Pdf.Document.pas',
  DX.Pdf.Viewer.Core in '..\..\..\DC12\DX.Pdfium4D\src\DX.Pdf.Viewer.Core.pas',
  DX.Pdf.Viewer.FMX in '..\..\..\DC12\DX.Pdfium4D\src\DX.Pdf.Viewer.FMX.pas',
  DX.Pdf.Renderer.FMX in '..\..\..\DC12\DX.Pdfium4D\src\DX.Pdf.Renderer.FMX.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfMain, fMain);
  Application.Run;
end.

unit ManageFiles.Form;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Edit, FMX.Controls.Presentation, FMX.Layouts, System.Rtti, FMX.Grid.Style,
  FMX.Grid, FMX.ScrollBox, FMX.Memo.Types, FMX.Memo;

type
  TfManageFiles = class(TForm)
    OpenDialog: TOpenDialog;
    StringGrid1: TStringGrid;
    StringColumn1: TStringColumn;
    StringColumn2: TStringColumn;
    pBottom: TPanel;
    gbDetails: TGroupBox;
    eName: TEdit;
    eAlternateNames: TEdit;
    memNotes: TMemo;
    Name: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    pOptions: TPanel;
    bAdd: TButton;
    bEdit: TButton;
    bDelete: TButton;
    bSearch: TButton;
    bAudio: TButton;
    pEdit: TPanel;
    bAccept: TButton;
    bCancel: TButton;
    Button1: TButton;
    procedure bAddClick(Sender: TObject);
    procedure bEditClick(Sender: TObject);
    procedure bAcceptClick(Sender: TObject);
    procedure bCancelClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure StringColumn2Gesture(Sender: TObject;
      const EventInfo: TGestureEventInfo; var Handled: Boolean);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  fManageFiles: TfManageFiles;

implementation

uses
  System.IOUtils,
{$IFDEF MSWINDOWS}
  Vcl.Dialogs,
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
procedure TfManageFiles.bAddClick(Sender: TObject);
begin
  pOptions.Visible := FALSE;
  pEdit.Visible := TRUE;
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
procedure TfManageFiles.bCancelClick(Sender: TObject);
begin
  pOptions.Visible := TRUE;
  pEdit.Visible := FALSE;
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
procedure TfManageFiles.bEditClick(Sender: TObject);
begin
  pOptions.Visible := FALSE;
  pEdit.Visible := TRUE;
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
procedure TfManageFiles.Button1Click(Sender: TObject);
begin
  Close;
end;

procedure TfManageFiles.FormActivate(Sender: TObject);
begin
  StringColumn1.Width := 8 * (Width div 10);
  StringColumn2.Width := Width div 10;
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
procedure TfManageFiles.bAcceptClick(Sender: TObject);
begin
  pOptions.Visible := TRUE;
  pEdit.Visible := FALSE;
end;

end.

unit Menu.Form;

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
  FMX.StdCtrls;

type
  TOperations = (
    OP_NONE,
    OP_OPEN_FILE,
    OP_SEARCH,
    OP_SETTINGS,
    OP_BACK,
    OP_EXIT,
    OP_ABOUT
  );

  TfMenu = class(TForm)
    bAbout: TButton;
    bOpenfile: TButton;
    bExit: TButton;
    bSearch: TButton;
    bSettings: TButton;
    bBack: TButton;
    procedure FormCreate(Sender: TObject);
    procedure bOpenfileClick(Sender: TObject);
    procedure bAboutClick(Sender: TObject);
    procedure bSearchClick(Sender: TObject);
    procedure bSettingsClick(Sender: TObject);
    procedure bBackClick(Sender: TObject);
    procedure bExitClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    idOperation: TOperations;
  end;

var
  fMenu: TfMenu;

implementation

{$R *.fmx}

//***************************************************************************
//
// OPERATION : Record that About was chosen, then let the button close the
//             menu.
//
// I/P       : Sender : TObject - The About button.
//
// O/P       : None
//
//***************************************************************************
procedure TfMenu.bAboutClick(Sender: TObject);
begin
  idOperation := OP_ABOUT;
end; // bAboutClick

//***************************************************************************
//
// OPERATION : Record that the menu should close without another command.
//
// I/P       : Sender : TObject - The Back button.
//
// O/P       : None
//
//***************************************************************************
procedure TfMenu.bBackClick(Sender: TObject);
begin
  idOperation := OP_BACK;
end; // bBackClick

//***************************************************************************
//
// OPERATION : Record that the application should close.
//
// I/P       : Sender : TObject - The Exit button.
//
// O/P       : None
//
//***************************************************************************
procedure TfMenu.bExitClick(Sender: TObject);
begin
  idOperation := OP_EXIT;
end; // bExitClick

//***************************************************************************
//
// OPERATION : Record that a PDF should be opened.
//
// I/P       : Sender : TObject - The Open button.
//
// O/P       : None
//
//***************************************************************************
procedure TfMenu.bOpenfileClick(Sender: TObject);
begin
  idOperation := OP_OPEN_FILE;
end; // bOpenfileClick

//***************************************************************************
//
// OPERATION : Record that Search was chosen.
//
// I/P       : Sender : TObject - The Search button.
//
// O/P       : None
//
//***************************************************************************
procedure TfMenu.bSearchClick(Sender: TObject);
begin
  idOperation := OP_SEARCH;
end; // bSearchClick

//***************************************************************************
//
// OPERATION : Record that Settings was chosen.
//
// I/P       : Sender : TObject - The Settings button.
//
// O/P       : None
//
//***************************************************************************
procedure TfMenu.bSettingsClick(Sender: TObject);
begin
  idOperation := OP_SETTINGS;
end; // bSettingsClick

//***************************************************************************
//
// OPERATION : Clear the chosen operation before the menu is shown.
//
// I/P       : Sender : TObject - The menu form being created.
//
// O/P       : None
//
//***************************************************************************
procedure TfMenu.FormCreate(Sender: TObject);
begin
  idOperation := OP_NONE;
end; // FormCreate

end. // Menu.Form

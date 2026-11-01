unit Data;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef, FireDAC.Stan.ExprFuncs, FireDAC.FMXUI.Wait,
  FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt,
  FireDAC.Phys.SQLiteWrapper.Stat, Data.DB, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client, FireDAC.VCLUI.Wait;

type
  TDataModule1 = class(TDataModule)
    connection: TFDConnection;
    query: TFDQuery;
    FDPhysSQLiteDriverLink1: TFDPhysSQLiteDriverLink;
    procedure DataModuleCreate(Sender: TObject);
  private
    { Private declarations }
    procedure Connect;
    procedure CreateTables;

  public
    { Public declarations }
  end;

var
  DataModule1: TDataModule1;

implementation

uses
  System.IOUtils,
  Constants;

{%CLASSGROUP 'FMX.Controls.TControl'}

{$R *.dfm}

//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
procedure TDataModule1.Connect;
begin
  connection.Params.Clear;
  connection.Params.Add('DriverID=SQLite');
  connection.Params.Add('Database=' +
    TPath.GetPublicPath + TPath.DirectorySeparatorChar +
    ORIGINATOR + TPath.DirectorySeparatorChar +
    PROGRAM_NAME + TPath.DirectorySeparatorChar +
    'content.db'
  );
  connection.LoginPrompt := FALSE;
  connection.Connected := TRUE;
end; // Connect

//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
procedure TDataModule1.CreateTables;
begin
  connection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS scores (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    'title VARCHAR(100),' +
    'path TEXT' +
    'alternateTitle TEXT' +
    'notes TEXT' +
    'edits TEXT' +
    ')'
  );
  connection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS audio (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    'title VARCHAR(100),' +
    'path TEXT' +
    'alternateTitle TEXT' +
    'notes TEXT' +
    ')'
  );
  connection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS linking (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    'idScore INTEGER,' +
    'idAudio INTEGER,' +
    'notes TEXT' +
    ')'
  );
end; // CreateTables


//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
procedure TDataModule1.DataModuleCreate(Sender: TObject);
begin
  Connect;
  CreateTables;
end;

end.

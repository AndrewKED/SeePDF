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
  connection.Params.Add('ForeignKeys=True');

  connection.LoginPrompt := FALSE;
  connection.Connected := TRUE;
end; // Connect

//***************************************************************************
//
// OPERATION : Create the content tables, indexes, and foreign keys when
 //             they are not already present.
//
// I/P : None
//
// O/P : None
//
//***************************************************************************
procedure TDataModule1.CreateTables;
begin
  // Pieces / scores / PDFs
  connection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS scores (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    'title TEXT NOT NULL CHECK (length(trim(title)) > 0),' +
    'alternateTitle TEXT,' +
    'fileHash TEXT NOT NULL CHECK (length(trim(fileHash)) > 0),' +
    'timeSignature TEXT,' +
    'path TEXT NOT NULL CHECK (length(trim(path)) > 0),' +
    'genre TEXT,' +
    'composer TEXT,' +
    'pageCount INTEGER CHECK (pageCount IS NULL OR pageCount >= 0),' +
    'notes TEXT,' +
    'annotations TEXT' +
    ')'
  );

  // Audio files
  connection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS audio (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    'title TEXT NOT NULL CHECK (length(trim(title)) > 0),' +
    'fileHash TEXT NOT NULL CHECK (length(trim(fileHash)) > 0),' +
    'path TEXT NOT NULL CHECK (length(trim(path)) > 0),' +
    'alternateTitle TEXT,' +
    'performer TEXT,' +
    'notes TEXT' +
    ')'
  );

  // Score / audio linkage
  connection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS linking (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    'idScore INTEGER NOT NULL,' +
    'idAudio INTEGER NOT NULL,' +
    'notes TEXT,' +
    'FOREIGN KEY (idScore) REFERENCES scores (id) ON DELETE RESTRICT,' +
    'FOREIGN KEY (idAudio) REFERENCES audio (id) ON DELETE RESTRICT,' +
    'UNIQUE (idScore, idAudio)' +
    ')'
  );

  // One page-turn schedule per score/audio link
  connection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS audio_page_turns (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    'idLinking INTEGER NOT NULL,' +
    'FOREIGN KEY (idLinking) REFERENCES linking (id) ON DELETE CASCADE,' +
    'UNIQUE (idLinking)' +
    ')'
  );

  // Timed page-turn points within a schedule (seconds into the audio)
  connection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS audio_page_turn_points (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    'idAudioPageTurn INTEGER NOT NULL,' +
    'turnTime REAL NOT NULL CHECK (turnTime >= 0),' +
    'FOREIGN KEY (idAudioPageTurn) REFERENCES audio_page_turns (id) ' +
    'ON DELETE CASCADE' +
    ')'
  );

  // Sets
  connection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS sets (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    'name TEXT NOT NULL CHECK (length(trim(name)) > 0),' +
    'notes TEXT' +
    ')'
  );

  // Set items: either a score, or a score+audio link
  connection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS set_items (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    'idSet INTEGER NOT NULL,' +
    'idScore INTEGER,' +
    'idLinking INTEGER,' +
    'itemOrder INTEGER NOT NULL CHECK (itemOrder >= 0),' +
    'notes TEXT,' +
    'FOREIGN KEY (idSet) REFERENCES sets (id) ON DELETE CASCADE,' +
    'FOREIGN KEY (idScore) REFERENCES scores (id) ON DELETE RESTRICT,' +
    'FOREIGN KEY (idLinking) REFERENCES linking (id) ON DELETE RESTRICT,' +
    'CHECK (' +
    '  (idScore IS NOT NULL AND idLinking IS NULL) OR ' +
    '  (idScore IS NULL AND idLinking IS NOT NULL)' +
    '),' +
    'UNIQUE (idSet, itemOrder)' +
    ')'
  );

  connection.ExecSQL(
    'CREATE INDEX IF NOT EXISTS ix_scores_fileHash ON scores (fileHash)');
  connection.ExecSQL(
    'CREATE INDEX IF NOT EXISTS ix_scores_title ON scores (title COLLATE NOCASE)');
  connection.ExecSQL(
    'CREATE INDEX IF NOT EXISTS ix_audio_fileHash ON audio (fileHash)');
  connection.ExecSQL(
    'CREATE INDEX IF NOT EXISTS ix_audio_title ON audio (title COLLATE NOCASE)');
  connection.ExecSQL(
    'CREATE INDEX IF NOT EXISTS ix_linking_idScore ON linking (idScore)');
  connection.ExecSQL(
    'CREATE INDEX IF NOT EXISTS ix_linking_idAudio ON linking (idAudio)');
  connection.ExecSQL(
    'CREATE INDEX IF NOT EXISTS ix_audio_page_turn_points_parent ' +
    'ON audio_page_turn_points (idAudioPageTurn, turnTime)');
  connection.ExecSQL(
    'CREATE INDEX IF NOT EXISTS ix_set_items_idSet ON set_items (idSet, itemOrder)');
  connection.ExecSQL(
    'CREATE INDEX IF NOT EXISTS ix_sets_name ON sets (name COLLATE NOCASE)');
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

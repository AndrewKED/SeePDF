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
    sgFiles: TStringGrid;
    scTitle: TStringColumn;
    scAudio: TStringColumn;
    pBottom: TPanel;
    gbDetails: TGroupBox;
    eName: TEdit;
    eAlternateNames: TEdit;
    memNotes: TMemo;
    Name: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    lRelativeFileName: TLabel;
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
    bClose: TButton;
    bOpenFile: TButton;
    procedure bAddClick(Sender: TObject);
    procedure bEditClick(Sender: TObject);
    procedure bAcceptClick(Sender: TObject);
    procedure bCancelClick(Sender: TObject);
    procedure bCloseClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure sgFilesCellClick(const Column: TColumn; const Row: Integer);
    procedure sgFilesSelChanged(Sender: TObject);
    procedure bOpenFileClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure sgFilesHeaderClick(Column: TColumn);
    procedure sgFilesCellDblClick(const Column: TColumn; const Row: Integer);
  private
    { Private declarations }
    type
        TScoreDetail = record
          Id : Int64;
          AlternateTitle : String;
          Path : String;
          Notes : String;
        end;
    var
      scoreDetails : TArray<TScoreDetail>;
      editingScore : Boolean;
      addingScore : Boolean;
      sortFwd : Boolean;
      savedId : Int64;
      FselectedFilePath : String;
    procedure SetEditing(const editing : Boolean);
    procedure RepairScorePaths;
    procedure LoadScores(const selectId : Int64);
    procedure ShowSelectedScore;
    function ScoreAlreadyListed(const scoreHash : String;
                                const scorePath : String;
                                out existingTitle : String) : Boolean;
    procedure LayoutFileColumns;
    function VerticalScrollBarWidth : Single;
  public
    { Public declarations }
    property SelectedFilePath : String read FselectedFilePath;
  end;

var
  fManageFiles: TfManageFiles;

implementation

uses
  System.IOUtils,
{$IFDEF MSWINDOWS}
  WinApi.Windows,
  Vcl.Dialogs,
{$ENDIF}
  Configuration, Data,
  Hash_Ops, FMX.Grid_Ops, Str_Ops;

{$R *.fmx}

//***************************************************************************
//
// OPERATION : Show the score for the selected grid row in the details
//             panel. The location is the stored path relative to the
//             configured PDF folder.
//
// I/P : None
//
// O/P : None
//
//***************************************************************************
procedure TfManageFiles.ShowSelectedScore;
var
  row : Integer;
  pdfDir : String;
  storedPath : String;
  fullBase : String;
  fullPath : String;

begin
  row := sgFiles.Selected;
  if (row < 0) or (row >= Length(scoreDetails)) then
  begin
    eName.Text := '';
    eAlternateNames.Text := '';
    lRelativeFileName.Text := '';
    memNotes.Text := '';
    Exit;
  end; // if

  eName.Text := sgFiles.Cells[0, row];
  eAlternateNames.Text := scoreDetails[row].AlternateTitle;
  memNotes.Text := scoreDetails[row].Notes;

  storedPath := scoreDetails[row].Path;
  if storedPath = '' then
    lRelativeFileName.Text := ''
  else if TPath.IsRelativePath(storedPath) then
    lRelativeFileName.Text := storedPath
  else
  begin
    pdfDir := progConfig.ReadString('Files', 'PDF Dir', TPath.GetDocumentsPath);
    fullBase := IncludeTrailingPathDelimiter(TPath.GetFullPath(pdfDir));
    fullPath := TPath.GetFullPath(storedPath);
    if fullPath.StartsWith(fullBase, True) then
      lRelativeFileName.Text := fullPath.Substring(fullBase.Length)
    else
      lRelativeFileName.Text := storedPath;
  end; // if
end; // ShowSelectedScore

//***************************************************************************
//
// OPERATION : Report whether the scores table already has this PDF, by
//             file hash or by relative path.
//
// I/P : scoreHash : String - SHA-256 of the PDF file.
//
//       scorePath : String - Path relative to the PDF folder.
//
//       existingTitle : String - Title of the matching row, when found.
//
// O/P : Boolean - TRUE when a matching score already exists.
//
//***************************************************************************
function TfManageFiles.ScoreAlreadyListed(const scoreHash : String;
                                          const scorePath : String;
                                          out existingTitle : String) : Boolean;
begin
  existingTitle := '';
  DataModule1.query.Close;
  DataModule1.query.SQL.Text :=
    'SELECT title FROM scores ' +
    'WHERE (fileHash = :fileHash) OR ' +
    '(lower(path) = lower(:path)) ' +
    'LIMIT 1';
  DataModule1.query.ParamByName('fileHash').AsString := scoreHash;
  DataModule1.query.ParamByName('path').AsString := scorePath;
  DataModule1.query.Open;
  try
    Result := not DataModule1.query.IsEmpty;
    if Result then
      existingTitle := DataModule1.query.FieldByName('title').AsString;
  finally
    DataModule1.query.Close;
  end; // try
end; // ScoreAlreadyListed

//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
procedure TfManageFiles.SetEditing(const editing : Boolean);
begin
  editingScore := editing;

  eName.ReadOnly := not editing;
  eAlternateNames.ReadOnly := not editing;
  memNotes.ReadOnly := not editing;
  bOpenFile.Visible := editing;

  sgFiles.Enabled := not editing;
  pOptions.Visible := not editing;
  pEdit.Visible := editing;
end;

//***************************************************************************
//
// OPERATION : If a stored PDF is no longer at its path, find a file in
//             the PDF folder with the same SHA-256 and store that path.
//
// I/P : None
//
// O/P : None
//
//***************************************************************************
procedure TfManageFiles.RepairScorePaths;
type
  TScoreFile = record
    Id : Int64;
    Path : String;
    FileHash : String;
  end;

var
  pdfDir : String;
  fullBase : String;
  rows : TArray<TScoreFile>;
  pdfFiles : TArray<String>;
  row : Integer;
  fileIndex : Integer;
  missing : Boolean;
  fullFile : String;
  relativePath : String;

begin
  pdfDir := progConfig.ReadString('Files', 'PDF Dir', TPath.GetDocumentsPath);
  if not TDirectory.Exists(pdfDir) then
    Exit;

  DataModule1.query.Close;
  DataModule1.query.SQL.Text := 'SELECT id, path, fileHash FROM scores';
  DataModule1.query.Open;
  try
    row := 0;
    while not DataModule1.query.Eof do
    begin
      SetLength(rows, row + 1);
      rows[row].Id := DataModule1.query.FieldByName('id').AsLargeInt;
      rows[row].Path := DataModule1.query.FieldByName('path').AsString;
      rows[row].FileHash := DataModule1.query.FieldByName('fileHash').AsString;
      Inc(row);
      DataModule1.query.Next;
    end; // while
  finally
    DataModule1.query.Close;
  end; // try

  missing := False;
  for row := 0 to High(rows) do
  begin
    if TPath.IsRelativePath(rows[row].Path) then
      fullFile := TPath.Combine(pdfDir, rows[row].Path)
    else
      fullFile := rows[row].Path;
    if not TFile.Exists(fullFile) then
      missing := True;
  end; // for
  if not missing then
    Exit;

  try
    pdfFiles := TDirectory.GetFiles(pdfDir, '*.pdf',
      TSearchOption.soAllDirectories);
  except
    Exit;
  end; // try

  fullBase := IncludeTrailingPathDelimiter(TPath.GetFullPath(
    ExcludeTrailingPathDelimiter(pdfDir)));
  for row := 0 to High(rows) do
  begin
    if TPath.IsRelativePath(rows[row].Path) then
      fullFile := TPath.Combine(pdfDir, rows[row].Path)
    else
      fullFile := rows[row].Path;
    if TFile.Exists(fullFile) then
      Continue;

    for fileIndex := 0 to High(pdfFiles) do
    begin
      if not SameText(HashFile(pdfFiles[fileIndex]), rows[row].FileHash) then
        Continue;
      relativePath := TPath.GetFullPath(pdfFiles[fileIndex]);
      if not relativePath.StartsWith(fullBase, True) then
        Continue;
      relativePath := relativePath.Substring(fullBase.Length);
      DataModule1.query.Close;
      DataModule1.query.SQL.Text :=
        'UPDATE scores SET path = :path WHERE id = :id';
      DataModule1.query.ParamByName('path').AsString := relativePath;
      DataModule1.query.ParamByName('id').AsLargeInt := rows[row].Id;
      DataModule1.query.ExecSQL;
      Break;
    end; // for
  end; // for
end; // RepairScorePaths

//***************************************************************************
//
// OPERATION : Reload the scores grid in alphabetical order and select
//             the row with the given id.
//
// I/P : selectId : Int64 - Row to select. The first row is selected when
//             this id is not in the table.
//
// O/P : None
//
//***************************************************************************
procedure TfManageFiles.LoadScores(const selectId : Int64);
var
  row : Integer;
  selectRow : Integer;

begin
{TODO -oAndrew Spencer -cGeneric : Repairing should be a maintenance function, under Settings, - not every time}
  RepairScorePaths;

  if (sortFwd) then
  begin
    scTitle.Header := 'Name (ascending alphabetically)';
  end // if
  else
  begin
    scTitle.Header := 'Name (descending alphabetically)';
  end; // else

  selectRow := 0;
  sgFiles.BeginUpdate;
  try
    sgFiles.RowCount := 0;
    SetLength(scoreDetails, 0);
    DataModule1.query.Close;
    DataModule1.query.SQL.Text :=
      'SELECT id, title, path, alternateTitle, notes, ' +
      'CASE WHEN EXISTS (' +
      '  SELECT 1 FROM linking WHERE linking.idScore = scores.id' +
      ') THEN ''Yes'' ELSE ''No'' END AS audioAvailable ' +
      'FROM scores ' +
      ifthens(sortFwd,
        'ORDER BY title COLLATE NOCASE',
        'ORDER BY title COLLATE NOCASE DESC'
      );
    DataModule1.query.Open;

    row := 0;
    while not DataModule1.query.Eof do
    begin
      SetLength(scoreDetails, row + 1);
      sgFiles.RowCount := row + 1;
      sgFiles.Cells[0, row] :=
        DataModule1.query.FieldByName('title').AsString;
      sgFiles.Cells[1, row] :=
        DataModule1.query.FieldByName('audioAvailable').AsString;
      scoreDetails[row].Id :=
        DataModule1.query.FieldByName('id').AsLargeInt;
      scoreDetails[row].AlternateTitle :=
        DataModule1.query.FieldByName('alternateTitle').AsString;
      scoreDetails[row].Path :=
        DataModule1.query.FieldByName('path').AsString;
      scoreDetails[row].Notes :=
        DataModule1.query.FieldByName('notes').AsString;
      if scoreDetails[row].Id = selectId then
        selectRow := row;
      Inc(row);
      DataModule1.query.Next;
    end; // while
    DataModule1.query.Close;
  finally
    sgFiles.EndUpdate;
  end; // try

  bEdit.Enabled := sgFiles.RowCount > 0;
  if sgFiles.RowCount > 0 then
  begin
    sgFiles.Selected := selectRow;
    savedId := scoreDetails[selectRow].Id;
  end // if
  else
    sgFiles.Selected := -1;
  ShowSelectedScore;
end; // LoadScores

//***************************************************************************
//
// OPERATION : Refresh the details panel when the selected grid row changes.
//
// I/P : Sender : TObject - The grid whose selection changed.
//
// O/P : None
//
//***************************************************************************
procedure TfManageFiles.sgFilesSelChanged(Sender: TObject);
begin
  if ((sgFiles.Selected >= 0) and
      (sgFiles.Selected < Length(scoreDetails))) then
  begin
    savedId := scoreDetails[sgFiles.Selected].Id;
  end; // if
  ShowSelectedScore;
end; // sgFilesSelChanged

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
  addingScore := True;
  SetEditing(TRUE);
  eName.Text := '';
  eAlternateNames.Text := '';
  lRelativeFileName.Text := '';
  memNotes.Text := '';

  bOpenFile.SetFocus;
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
  addingScore := False;
  SetEditing(FALSE);
  ShowSelectedScore;
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
  if ((sgFiles.Selected < 0) or
      (sgFiles.Selected >= Length(scoreDetails))) then
  begin
    Exit;
  end;

  addingScore := False;
  SetEditing(TRUE);

  eName.SetFocus;
end;

//***************************************************************************
//
// OPERATION : Store the chosen PDF as a path relative to the configured
//             PDF folder, and fill a blank name from that file.
//
// I/P : Sender : TObject - The button that was clicked.
//
// O/P : None
//
//***************************************************************************
procedure TfManageFiles.bOpenFileClick(Sender: TObject);
var
  pdfDir : String;
  fullBase : String;
  fullPath : String;
  relativePath : String;

begin
  pdfDir := progConfig.ReadString('Files', 'PDF Dir', TPath.GetDocumentsPath);
  OpenDialog.InitialDir := pdfDir;
  if not OpenDialog.Execute then
    Exit;

  fullPath := OpenDialog.FileName;
  if TPath.IsRelativePath(fullPath) then
    fullPath := TPath.Combine(pdfDir, fullPath);
  fullPath := TPath.GetFullPath(fullPath);
  fullPath := fullPath.Replace('/', TPath.DirectorySeparatorChar);

  if not SameText(TPath.GetExtension(fullPath), '.pdf') then
  begin
    FMX.Dialogs.ShowMessage('Choose a PDF file.');
    Exit;
  end; // if

  fullBase := TPath.GetFullPath(ExcludeTrailingPathDelimiter(pdfDir));
  fullBase := IncludeTrailingPathDelimiter(
    fullBase.Replace('/', TPath.DirectorySeparatorChar));

  if not fullPath.StartsWith(fullBase, True) then
  begin
    FMX.Dialogs.ShowMessage(
      'Choose a PDF file inside the configured PDF folder.');
    Exit;
  end; // if

  relativePath := fullPath.Substring(fullBase.Length);
  lRelativeFileName.Text := relativePath;
  if Trim(eName.Text) = '' then
    eName.Text := TPath.GetFileNameWithoutExtension(relativePath);
end; // bOpenFileClick

//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
procedure TfManageFiles.bCloseClick(Sender: TObject);
begin
  Close;
end;

//***************************************************************************
//
// OPERATION : Return the thickness of the grid's vertical scrollbar.
//
// I/P : None
//
// O/P : Single - The scrollbar width, or 0 when it is not showing.
//
//***************************************************************************
function TfManageFiles.VerticalScrollBarWidth : Single;

  function FindBar(parent : TFmxObject) : TScrollBar;
  var
    i : Integer;
    child : TFmxObject;

  begin
    Result := nil;
    if parent = nil then
      Exit;

    for i := 0 to parent.ChildrenCount - 1 do
    begin
      child := parent.Children[i];
      if (child is TScrollBar) and
         (TScrollBar(child).Orientation = TOrientation.Vertical) then
        Exit(TScrollBar(child));
      Result := FindBar(child);
      if Result <> nil then
        Exit;
    end; // for
  end; // FindBar

var
  bar : TScrollBar;

begin
  Result := 0;
  bar := FindBar(sgFiles);
  if (bar <> nil) and bar.Visible then
    Result := bar.Width;
end; // VerticalScrollBarWidth

//***************************************************************************
//
// OPERATION : Give the name column about 90% of the grid, and the audio
//             column the rest, leaving room for the vertical scrollbar.
//
// I/P : None
//
// O/P : None
//
//***************************************************************************
procedure TfManageFiles.LayoutFileColumns;
begin
  ResizeGridColumns(sgFiles, [9, 1]);
end; // LayoutFileColumns

//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
procedure TfManageFiles.FormActivate(Sender: TObject);
begin
  LayoutFileColumns;
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
procedure TfManageFiles.FormResize(Sender: TObject);
begin
  LayoutFileColumns;
end;

//***************************************************************************
//
// OPERATION : Load the scores table into the grid, in alphabetical order
//             of title.
//
// I/P : Sender : TObject - The form being created.
//
// O/P : None
//
//***************************************************************************
procedure TfManageFiles.FormCreate(Sender: TObject);
begin
  FselectedFilePath := '';
  addingScore := False;
  SetEditing(FALSE);

  sortFwd := True;
  LoadScores(-1);
end; // FormCreate

//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
procedure TfManageFiles.sgFilesCellClick(const Column: TColumn;
  const Row: Integer);
begin
  ShowSelectedScore;
end;

//***************************************************************************
//
// OPERATION : Close the form and hand the chosen PDF path back to the
//             caller for display in the viewer.
//
// I/P : Column : TColumn - The column that was double-clicked.
//
//       Row : Integer - The row that was double-clicked.
//
// O/P : None
//
//***************************************************************************
procedure TfManageFiles.sgFilesCellDblClick(const Column: TColumn;
  const Row: Integer);
var
  pdfDir : String;
  storedPath : String;

begin
  if editingScore then
    Exit;
  if (Row < 0) or (Row >= Length(scoreDetails)) then
    Exit;

  storedPath := Trim(scoreDetails[Row].Path);
  if storedPath = '' then
  begin
    FMX.Dialogs.ShowMessage('This score has no file path.');
    Exit;
  end; // if

  pdfDir := progConfig.ReadString('Files', 'PDF Dir', TPath.GetDocumentsPath);
  if TPath.IsRelativePath(storedPath) then
    FselectedFilePath := TPath.Combine(pdfDir, storedPath)
  else
    FselectedFilePath := storedPath;

  if not TFile.Exists(selectedFilePath) then
  begin
    FMX.Dialogs.ShowMessage('File not found: ' + selectedFilePath);
    FselectedFilePath := '';
    Exit;
  end; // if

  ModalResult := mrOk;
end; // sgFilesCellDblClick

//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
procedure TfManageFiles.sgFilesHeaderClick(Column: TColumn);
begin
  if ((Column = scTitle) and (not editingScore)) then
  begin
    sortFwd := not sortFwd;
    LoadScores(savedId);
  end; // if
end;

//***************************************************************************
//
// OPERATION : Insert a new score, or update the selected score, then
//             reload the grid.
//
// I/P : Sender : TObject - The button that was clicked.
//
// O/P : None
//
//***************************************************************************
procedure TfManageFiles.bAcceptClick(Sender: TObject);
var
  scoreName : String;
  scorePath : String;
  row : Integer;
  fullFile : String;
  scoreHash : String;
  existingTitle : String;

begin
  scoreName := Trim(eName.Text);
  scorePath := Trim(lRelativeFileName.Text);
  if scoreName = '' then
  begin
    FMX.Dialogs.ShowMessage('Enter a name for this PDF.');
    eName.SetFocus;
    Exit;
  end; // if
  if scorePath = '' then
  begin
    FMX.Dialogs.ShowMessage('Choose a PDF file.');
    Exit;
  end; // if

  fullFile := TPath.Combine(
    progConfig.ReadString('Files', 'PDF Dir', TPath.GetDocumentsPath),
    scorePath);
  if not TFile.Exists(fullFile) then
  begin
    FMX.Dialogs.ShowMessage('The PDF file could not be found.');
    Exit;
  end; // if
  try
    scoreHash := HashFile(fullFile);
  except
    FMX.Dialogs.ShowMessage('The PDF file could not be read.');
    Exit;
  end; // try

  if addingScore then
  begin
    if ScoreAlreadyListed(scoreHash, scorePath, existingTitle) then
    begin
      if MessageDlg(
           Format(
             'This PDF is already in the list as "%s".%sAdd another entry for it?',
             [existingTitle, sLineBreak]),
           TMsgDlgType.mtWarning,
           [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) <> mrYes then
        Exit;
    end; // if
  end; // if

  eName.Text := scoreName;
  if addingScore then
  begin
    DataModule1.query.Close;
    DataModule1.query.SQL.Text :=
      'INSERT INTO scores (title, path, fileHash, alternateTitle, notes) ' +
      'VALUES (:title, :path, :fileHash, :alternateTitle, :notes)';
    DataModule1.query.ParamByName('title').AsString := scoreName;
    DataModule1.query.ParamByName('path').AsString := scorePath;
    DataModule1.query.ParamByName('fileHash').AsString := scoreHash;
    DataModule1.query.ParamByName('alternateTitle').AsString :=
      Trim(eAlternateNames.Text);
    DataModule1.query.ParamByName('notes').AsString := memNotes.Text;
    DataModule1.query.ExecSQL;
    savedId := DataModule1.connection.ExecSQLScalar(
      'SELECT last_insert_rowid()');
  end // if
  else
  begin
    row := sgFiles.Selected;
    if (row < 0) or (row >= Length(scoreDetails)) then
      Exit;
    savedId := scoreDetails[row].Id;
    DataModule1.query.Close;
    DataModule1.query.SQL.Text :=
      'UPDATE scores ' +
      'SET title = :title, path = :path, fileHash = :fileHash, ' +
      'alternateTitle = :alternateTitle, notes = :notes ' +
      'WHERE id = :id';
    DataModule1.query.ParamByName('title').AsString := scoreName;
    DataModule1.query.ParamByName('path').AsString := scorePath;
    DataModule1.query.ParamByName('fileHash').AsString := scoreHash;
    DataModule1.query.ParamByName('alternateTitle').AsString :=
      Trim(eAlternateNames.Text);
    DataModule1.query.ParamByName('notes').AsString := memNotes.Text;
    DataModule1.query.ParamByName('id').AsLargeInt := savedId;
    DataModule1.query.ExecSQL;
  end; // else

  addingScore := False;
  SetEditing(FALSE);
  LoadScores(savedId);
end; // bAcceptClick

end.

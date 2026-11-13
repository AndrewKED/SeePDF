unit ManagePDFs.Form;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Edit, FMX.Controls.Presentation, FMX.Layouts, System.Rtti, FMX.Grid.Style,
  FMX.Grid, FMX.ScrollBox, FMX.Memo.Types, FMX.Memo, FMX.ListBox;

type
  TfManagePDFs = class(TForm)
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
    bView: TButton;
    Label5: TLabel;
    eTimeSignature: TEdit;
    scTimeSignature: TStringColumn;
    Label3: TLabel;
    cbGenre: TComboBox;
    Label6: TLabel;
    eComposer: TEdit;
    Label7: TLabel;
    eTempo: TEdit;
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
    procedure bViewClick(Sender: TObject);
    procedure cbGenrePopup(Sender: TObject);
    procedure bDeleteClick(Sender: TObject);
  private
    { Private declarations }
    type
      TRecordDetail = record
        Id : Int64;
        AlternateTitle : String;
        Path : String;
        Notes : String;
        TimeSignature : String;
        Tempo : String;
        Genre : Integer;
        Composer : String;
      end;
    var
      recordDetails : TArray<TRecordDetail>;
      editingRecord : Boolean;
      addingRecord : Boolean;
      sortFwd : Boolean;
      savedId : Int64;
      FselectedFilePath : String;
    procedure SelectGenre(const genreId : Integer);
    procedure SetEditing(const editing : Boolean);
    procedure RepairFilePaths;
    procedure LoadRecords(const selectId : Int64);
    procedure ShowSelectedRecord;
    function FileAlreadyListed(const fileHash : String;
                               const filePath : String;
                               out existingTitle : String) : Boolean;
    procedure LayoutFileColumns;
    function VerticalScrollBarWidth : Single;
  public
    { Public declarations }
    property SelectedFilePath : String read FselectedFilePath;
  end;

var
  fManagePDFs: TfManagePDFs;

implementation

uses
  System.IOUtils,
{$IFDEF MSWINDOWS}
  WinApi.Windows,
{$ENDIF}
  Constants, Configuration, Data,
  Hash_Ops, FMX.Grid_Ops, Str_Ops;

{$R *.fmx}

//***************************************************************************
//
// OPERATION : Select the genre combo item that matches the stored value.
//
// I/P : genre : Integer - Genre id
//
// O/P : None
//
//***************************************************************************
procedure TfManagePDFs.SelectGenre(const genreId : Integer);
var
  i : Integer;

begin
  cbGenre.ItemIndex := 0;
  for i := 0 to cbGenre.Items.Count - 1 do
  begin
    if NativeInt(cbGenre.Items.Objects[i]) = genreId then
    begin
      cbGenre.ItemIndex := i;
      Exit;
    end; // if
  end; // for
end; // SelectGenre

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
procedure TfManagePDFs.ShowSelectedRecord;
var
  row : Integer;
  rootDir : String;
  storedPath : String;
  fullBase : String;
  fullPath : String;

begin
  row := sgFiles.Selected;
  if (row < 0) or (row >= Length(recordDetails)) then
  begin
    eName.Text := '';
    eAlternateNames.Text := '';
    eTimeSignature.Text := '';
    eTempo.Text := '';
    eComposer.Text := '';
    cbGenre.ItemIndex := 0;
    lRelativeFileName.Text := '';
    memNotes.Text := '';
    Exit;
  end; // if

  eName.Text := sgFiles.Cells[0, row];
  eAlternateNames.Text := recordDetails[row].AlternateTitle;
  eTimeSignature.Text := recordDetails[row].TimeSignature;
  eTempo.Text := recordDetails[row].Tempo;
  eComposer.Text := recordDetails[row].Composer;
  memNotes.Text := recordDetails[row].Notes;
  SelectGenre(recordDetails[row].Genre);

  storedPath := recordDetails[row].Path;
  if storedPath = '' then
    lRelativeFileName.Text := ''
  else if TPath.IsRelativePath(storedPath) then
    lRelativeFileName.Text := storedPath
  else
  begin
    rootDir := progConfig.ReadString('Files', 'PDF Dir', TPath.GetDocumentsPath);
    fullBase := IncludeTrailingPathDelimiter(TPath.GetFullPath(rootDir));
    fullPath := TPath.GetFullPath(storedPath);
    if fullPath.StartsWith(fullBase, True) then
      lRelativeFileName.Text := fullPath.Substring(fullBase.Length)
    else
      lRelativeFileName.Text := storedPath;
  end; // if
end; // ShowSelectedScore

//***************************************************************************
//
// OPERATION : Report whether the record table already has this file-, by
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
function TfManagePDFs.FileAlreadyListed(const fileHash : String;
                                        const filePath : String;
                                        out existingTitle : String) : Boolean;
begin
  existingTitle := '';
  DataModule1.query.Close;
  DataModule1.query.SQL.Text :=
    'SELECT title FROM scores ' +
    'WHERE (fileHash = :fileHash) OR ' +
    '(lower(path) = lower(:path)) ' +
    'LIMIT 1';
  DataModule1.query.ParamByName('fileHash').AsString := fileHash;
  DataModule1.query.ParamByName('path').AsString := filePath;
  DataModule1.query.Open;
  try
    Result := not DataModule1.query.IsEmpty;
    if Result then
      existingTitle := DataModule1.query.FieldByName('title').AsString;
  finally
    DataModule1.query.Close;
  end; // try
end; // FileAlreadyListed

//***************************************************************************
//
//  OPERATION :
//
//  I/P       :
//
//  O/P       :
//
//***************************************************************************
procedure TfManagePDFs.SetEditing(const editing : Boolean);
begin
  editingRecord := editing;

  eName.ReadOnly := not editing;
  eAlternateNames.ReadOnly := not editing;
  eTimeSignature.ReadOnly := not editing;
  eTempo.ReadOnly := not editing;
  eComposer.ReadOnly := not editing;
  memNotes.ReadOnly := not editing;
  cbGenre.HitTest := editing;
  cbGenre.CanFocus := editing;
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
procedure TfManagePDFs.RepairFilePaths;
type
  TRecordFile = record
    Id : Int64;
    Path : String;
    FileHash : String;
  end;

var
  pdfDir : String;
  fullBase : String;
  rows : TArray<TRecordFile>;
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
end; // RepairFilePaths

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
procedure TfManagePDFs.LoadRecords(const selectId : Int64);
var
  row : Integer;
  selectRow : Integer;

begin
{TODO -oAndrew Spencer -cGeneric : Repairing should be a maintenance function, under Settings, - not every time}
  RepairfilePaths;

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
    SetLength(recordDetails, 0);
    DataModule1.query.Close;
    DataModule1.query.SQL.Text :=
      'SELECT id, title, path, alternateTitle, notes, ' +
      'timeSignature, tempo, genre, composer, ' +
      'CASE WHEN EXISTS (' +
      '  SELECT 1 FROM linking WHERE linking.idScore = scores.id' +
      ') THEN ''Yes'' ELSE ''No'' END AS audioAvailable ' +
      'FROM scores ' +
      IfThenS(sortFwd,
        'ORDER BY title COLLATE NOCASE',
        'ORDER BY title COLLATE NOCASE DESC'
      );
    DataModule1.query.Open;

    row := 0;
    while not DataModule1.query.Eof do
    begin
      SetLength(recordDetails, row + 1);
      sgFiles.RowCount := row + 1;
      sgFiles.Cells[0, row] :=
        DataModule1.query.FieldByName('title').AsString;
      sgFiles.Cells[1, row] :=
        DataModule1.query.FieldByName('timeSignature').AsString;
      sgFiles.Cells[2, row] :=
        DataModule1.query.FieldByName('audioAvailable').AsString;
      recordDetails[row].Id :=
        DataModule1.query.FieldByName('id').AsLargeInt;
      recordDetails[row].AlternateTitle :=
        DataModule1.query.FieldByName('alternateTitle').AsString;
      recordDetails[row].Path :=
        DataModule1.query.FieldByName('path').AsString;
      recordDetails[row].Notes :=
        DataModule1.query.FieldByName('notes').AsString;
      recordDetails[row].TimeSignature :=
        DataModule1.query.FieldByName('timeSignature').AsString;
      recordDetails[row].Tempo :=
        DataModule1.query.FieldByName('tempo').AsString;
      recordDetails[row].Genre :=
        DataModule1.query.FieldByName('genre').AsInteger;
        recordDetails[row].Composer :=
        DataModule1.query.FieldByName('composer').AsString;
      if recordDetails[row].Id = selectId then
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
    savedId := recordDetails[selectRow].Id;
  end // if
  else
    sgFiles.Selected := -1;
  ShowSelectedRecord;
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
procedure TfManagePDFs.sgFilesSelChanged(Sender: TObject);
begin
  if ((sgFiles.Selected >= 0) and
      (sgFiles.Selected < Length(recordDetails))) then
  begin
    savedId := recordDetails[sgFiles.Selected].Id;
  end; // if
  ShowSelectedRecord;
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
procedure TfManagePDFs.bAddClick(Sender: TObject);
begin
  addingRecord := True;
  SetEditing(TRUE);

  eName.Text := '';
  eAlternateNames.Text := '';
  eTimeSignature.Text := '';
  eTempo.Text := '';
  eComposer.Text := '';
  cbGenre.ItemIndex := 0;
  lRelativeFileName.Text := '';
  memNotes.Text := '';

  bOpenFile.SetFocus;
  bOpenFileClick(Sender);
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
procedure TfManagePDFs.bCancelClick(Sender: TObject);
begin
  addingRecord := False;
  SetEditing(FALSE);
  ShowSelectedRecord;
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
procedure TfManagePDFs.bEditClick(Sender: TObject);
begin
  if ((sgFiles.Selected < 0) or
      (sgFiles.Selected >= Length(recordDetails))) then
  begin
    Exit;
  end;

  addingRecord := False;
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
procedure TfManagePDFs.bOpenFileClick(Sender: TObject);
var
  rootDir : String;
  fullBase : String;
  fullPath : String;
  relativePath : String;

begin
  rootDir := progConfig.ReadString('Files', 'PDF Dir', TPath.GetDocumentsPath);

  relativePath := Trim(lRelativeFileName.Text);
  if relativePath = '' then
  begin
    // Adding, or no file chosen yet
    OpenDialog.InitialDir := rootDir;
    OpenDialog.FileName := '';
  end // if
  else
  begin
    // Editing: show the current file (may be in a subfolder)
    fullPath := TPath.GetFullPath(TPath.Combine(rootDir, relativePath));
    OpenDialog.InitialDir := TPath.GetDirectoryName(fullPath);
    OpenDialog.FileName := TPath.GetFileName(relativePath);;
  end; // else

  if not OpenDialog.Execute then
    Exit;

  fullPath := OpenDialog.FileName;
  if TPath.IsRelativePath(fullPath) then
    fullPath := TPath.Combine(rootDir, fullPath);
  fullPath := TPath.GetFullPath(fullPath);
  fullPath := fullPath.Replace('/', TPath.DirectorySeparatorChar);

  if not SameText(TPath.GetExtension(fullPath), '.pdf') then
  begin
    FMX.Dialogs.ShowMessage('Choose a PDF file.');
    Exit;
  end; // if

  fullBase := TPath.GetFullPath(ExcludeTrailingPathDelimiter(rootDir));
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
procedure TfManagePDFs.bViewClick(Sender: TObject);
begin
  sgFilesCellDblClick(sgFiles.Columns[0], sgFiles.Row);
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
procedure TfManagePDFs.cbGenrePopup(Sender: TObject);
begin
 if not editingRecord then
    cbGenre.DropDown; // already open → toggle closed
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
procedure TfManagePDFs.bCloseClick(Sender: TObject);
begin
  Close;
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
procedure TfManagePDFs.bDeleteClick(Sender: TObject);
begin
  // this will delete the row and any link to an audio file.
  // It will not delete the PDF or the audio file
  // The row can not be deleted if it is in a set
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
function TfManagePDFs.VerticalScrollBarWidth : Single;

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
procedure TfManagePDFs.LayoutFileColumns;
begin
  ResizeGridColumns(sgFiles, [7, 2, 1]);
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
procedure TfManagePDFs.FormActivate(Sender: TObject);
begin
  LayoutFileColumns;

  sgFiles.SetFocus;
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
procedure TfManagePDFs.FormResize(Sender: TObject);
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
procedure TfManagePDFs.FormCreate(Sender: TObject);
var
  n : Integer;

begin
  FselectedFilePath := '';
  addingRecord := False;
  SetEditing(FALSE);

  cbGenre.Items.Clear;
  for n := Low(TUNE_TYPES) to High(TUNE_TYPES) do
  begin
    cbGenre.Items.AddObject(TUNE_TYPES[n].name, TObject(TUNE_TYPES[n].id));
  end; // for

  sortFwd := True;
  LoadRecords(-1);
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
procedure TfManagePDFs.sgFilesCellClick(const Column: TColumn;
  const Row: Integer);
begin
  ShowSelectedRecord;
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
procedure TfManagePDFs.sgFilesCellDblClick(const Column: TColumn;
  const Row: Integer);
var
  rootDir : String;
  storedPath : String;

begin
  if editingRecord then
    Exit;
  if (Row < 0) or (Row >= Length(recordDetails)) then
    Exit;

  storedPath := Trim(recordDetails[Row].Path);
  if storedPath = '' then
  begin
    FMX.Dialogs.ShowMessage('This score has no file path.');
    Exit;
  end; // if

  rootDir := progConfig.ReadString('Files', 'PDF Dir', TPath.GetDocumentsPath);
  if TPath.IsRelativePath(storedPath) then
    FselectedFilePath := TPath.Combine(rootDir, storedPath)
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
procedure TfManagePDFs.sgFilesHeaderClick(Column: TColumn);
begin
  if ((Column = scTitle) and (not editingRecord)) then
  begin
    sortFwd := not sortFwd;
    LoadRecords(savedId);
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
procedure TfManagePDFs.bAcceptClick(Sender: TObject);
var
  fileName : String;
  filePath : String;
  row : Integer;
  fullFile : String;
  fileHash : String;
  existingTitle : String;
  fileGenre : Integer;

begin
  fileName := Trim(eName.Text);
  filePath := Trim(lRelativeFileName.Text);
  if fileName = '' then
  begin
    FMX.Dialogs.ShowMessage('Enter a name for this PDF.');
    eName.SetFocus;
    Exit;
  end; // if
  if filePath = '' then
  begin
    FMX.Dialogs.ShowMessage('Choose a PDF file.');
    Exit;
  end; // if

  fullFile := TPath.Combine(
    progConfig.ReadString('Files', 'PDF Dir', TPath.GetDocumentsPath),
    filePath);
  if not TFile.Exists(fullFile) then
  begin
    FMX.Dialogs.ShowMessage('The PDF file could not be found.');
    Exit;
  end; // if
  try
    fileHash := HashFile(fullFile);
  except
    FMX.Dialogs.ShowMessage('The PDF file could not be read.');
    Exit;
  end; // try

  if cbGenre.ItemIndex >= 0 then
    fileGenre := NativeInt(cbGenre.Items.Objects[cbGenre.ItemIndex])
  else
    fileGenre := Ord(TYPE_OTHER);

  if addingRecord then
  begin
    if FileAlreadyListed(fileHash, filePath, existingTitle) then
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

  eName.Text := fileName;
  if addingRecord then
  begin
    DataModule1.query.Close;
    DataModule1.query.SQL.Text :=
      'INSERT INTO scores (title, path, fileHash, alternateTitle, ' +
      'timeSignature, tempo, genre, composer, notes) ' +
      'VALUES (:title, :path, :fileHash, :alternateTitle, ' +
      ':timeSignature, :tempo, :genre, :composer, :notes)';
    DataModule1.query.ParamByName('title').AsString := fileName;
    DataModule1.query.ParamByName('path').AsString := filePath;
    DataModule1.query.ParamByName('fileHash').AsString := fileHash;
    DataModule1.query.ParamByName('alternateTitle').AsString :=
      Trim(eAlternateNames.Text);
    DataModule1.query.ParamByName('timeSignature').AsString :=
      Trim(eTimeSignature.Text);
    DataModule1.query.ParamByName('tempo').AsString :=
      Trim(eTempo.Text);
    DataModule1.query.ParamByName('genre').AsInteger := fileGenre;
    DataModule1.query.ParamByName('composer').AsString :=
      Trim(eComposer.Text);
    DataModule1.query.ParamByName('notes').AsString := memNotes.Text;
  end // if
  else
  begin
    row := sgFiles.Selected;
    if (row < 0) or (row >= Length(recordDetails)) then
      Exit;
    savedId := recordDetails[row].Id;
    DataModule1.query.Close;
    DataModule1.query.SQL.Text :=
      'UPDATE scores ' +
      'SET title = :title, path = :path, fileHash = :fileHash, ' +
      'alternateTitle = :alternateTitle, timeSignature = :timeSignature, ' +
      'tempo = :tempo, genre = :genre, composer = :composer, notes = :notes ' +
      'WHERE id = :id';
    DataModule1.query.ParamByName('title').AsString := fileName;
    DataModule1.query.ParamByName('path').AsString := filePath;
    DataModule1.query.ParamByName('fileHash').AsString := fileHash;
    DataModule1.query.ParamByName('alternateTitle').AsString :=
      Trim(eAlternateNames.Text);
    DataModule1.query.ParamByName('timeSignature').AsString :=
      Trim(eTimeSignature.Text);
    DataModule1.query.ParamByName('tempo').AsString :=
      Trim(eTempo.Text);
    DataModule1.query.ParamByName('genre').AsInteger := fileGenre;
    DataModule1.query.ParamByName('composer').AsString :=
      Trim(eComposer.Text);
    DataModule1.query.ParamByName('notes').AsString := memNotes.Text;
    DataModule1.query.ParamByName('id').AsLargeInt := savedId;
  end; // else
  DataModule1.query.ExecSQL;

  addingRecord := False;
  SetEditing(FALSE);
  LoadRecords(savedId);
end; // bAcceptClick

end.

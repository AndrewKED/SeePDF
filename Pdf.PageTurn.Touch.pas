{*******************************************************************************
  Unit: Pdf.PageTurn.Touch

  Touch and mouse page turning for the FMX PDF viewer.

  The VCL viewer draws the page on child controls that receive the pointer,
  so that version subclasses the viewer window. The FMX viewer turns hit
  testing off on those children, so TPdfViewer.MouseDown and MouseUp run.
  This unit handles those events.

  A tap on the right half advances one page. A tap on the left half goes
  back one page. A horizontal swipe does the same: finger moving left
  advances, finger moving right goes back.

  Distances are in FMX logical pixels. The VCL unit scales the same design
  distances from 96 DPI because VCL mouse positions are device pixels.
*******************************************************************************}
unit Pdf.PageTurn.Touch;

interface

uses
  System.Types,
  System.Classes,
  System.UITypes,
  FMX.Types,
  FMX.Controls,
  DX.Pdf.Viewer.FMX;

type
  TPdfPageTurnTouch = class
  private
    FViewer: TPdfViewer;
    FOldMouseDown: TMouseEvent;
    FOldMouseUp: TMouseEvent;
    FSavedSelectionEnabled: Boolean;
    FTracking: Boolean;
    FStart: TPointF;
    procedure ViewerMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure ViewerMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure BeginTurn(const APos: TPointF);
    procedure FinishTurn(const APos: TPointF);
    procedure CancelTurn;
    procedure CaptureViewer;
    procedure ReleaseViewer;
  public
    constructor Create(AViewer: TPdfViewer);
    destructor Destroy; override;
  end;

implementation

const
  // Logical-pixel distances. FMX pointer coordinates are already in this space.
  TAP_SLOP = 30;
  SWIPE_MIN = 80;

//***************************************************************************
//
// OPERATION : Attach page-turn handling to a PDF viewer.
//             The viewer must outlive this object. Free this object before
//             freeing the viewer. Text selection is turned off so a tap is
//             used to change page.
//
// I/P       : AViewer : TPdfViewer - Viewer that receives the pointer.
//
// O/P       : None
//
//***************************************************************************
constructor TPdfPageTurnTouch.Create(AViewer: TPdfViewer);
begin
  inherited Create;

  FViewer := AViewer;
  FSavedSelectionEnabled := FViewer.SelectionEnabled;
  FViewer.SelectionEnabled := False;
  FOldMouseDown := FViewer.OnMouseDown;
  FOldMouseUp := FViewer.OnMouseUp;
  FViewer.OnMouseDown := ViewerMouseDown;
  FViewer.OnMouseUp := ViewerMouseUp;
end; // Create

//***************************************************************************
//
// OPERATION : Remove the page-turn handlers and restore selection.
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
destructor TPdfPageTurnTouch.Destroy;
begin
  CancelTurn;
  if FViewer <> nil then
  begin
    FViewer.OnMouseDown := FOldMouseDown;
    FViewer.OnMouseUp := FOldMouseUp;
    FViewer.SelectionEnabled := FSavedSelectionEnabled;
  end; // if
  FOldMouseDown := nil;
  FOldMouseUp := nil;
  FViewer := nil;

  inherited Destroy;
end; // Destroy

//***************************************************************************
//
// OPERATION : Remember where the finger or mouse button went down, and
//             capture the pointer until it is released.
//
// I/P       : APos : TPointF - Position in the viewer.
//
// O/P       : None
//
//***************************************************************************
procedure TPdfPageTurnTouch.BeginTurn(const APos: TPointF);
begin
  FTracking := True;
  FStart := APos;
  if FViewer.CanFocus then
    FViewer.SetFocus;
  CaptureViewer;
end; // BeginTurn

//***************************************************************************
//
// OPERATION : Hold the pointer until it is released, including if it leaves
//             the viewer. TControl.Capture is not public, so this sets the
//             form's captured control directly.
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TPdfPageTurnTouch.CaptureViewer;
begin
  if (FViewer <> nil) and (FViewer.Root <> nil) then
    FViewer.Root.Captured := FViewer;
end; // CaptureViewer

//***************************************************************************
//
// OPERATION : Release the pointer if this viewer is the control that holds it.
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TPdfPageTurnTouch.ReleaseViewer;
begin
  if (FViewer <> nil) and (FViewer.Root <> nil) and
     (FViewer.Root.Captured <> nil) and
     (FViewer.Root.Captured.GetObject = FViewer) then
    FViewer.Root.Captured := nil;
end; // ReleaseViewer

//***************************************************************************
//
// OPERATION : Drop an in-progress touch without changing the page.
//
// I/P       : None
//
// O/P       : None
//
//***************************************************************************
procedure TPdfPageTurnTouch.CancelTurn;
begin
  FTracking := False;
  ReleaseViewer;
end; // CancelTurn

//***************************************************************************
//
// OPERATION : Turn one page from a completed tap or horizontal swipe.
//             The decision is made when the finger lifts, so a swipe is
//             not also treated as a tap.
//
// I/P       : APos : TPointF - Position in the viewer where the finger or
//             button was released.
//
// O/P       : None
//
//***************************************************************************
procedure TPdfPageTurnTouch.FinishTurn(const APos: TPointF);
var
  dx: Single;
  dy: Single;

begin
  dx := APos.X - FStart.X;
  dy := APos.Y - FStart.Y;

  if (Abs(dx) >= SWIPE_MIN) and (Abs(dx) > Abs(dy)) then
  begin
    // Finger moving left turns forward, matching a page turning over.
    if dx < 0 then
      FViewer.NextPage
    else
      FViewer.PreviousPage;
  end // if
  else if (Abs(dy) < SWIPE_MIN) or (Abs(dx) >= Abs(dy)) then
  begin
    if FStart.X >= (FViewer.Width / 2) then
      FViewer.NextPage
    else
      FViewer.PreviousPage;
  end; // if
end; // FinishTurn

//***************************************************************************
//
// OPERATION : Start a page turn from a left-button or finger press.
//
// I/P       : Sender : TObject - The viewer.
//
//             Button : TMouseButton - Button that went down.
//
//             Shift : TShiftState - Modifier keys and double-click state.
//
//             X, Y : Single - Press position in the viewer.
//
// O/P       : None
//
//***************************************************************************
procedure TPdfPageTurnTouch.ViewerMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  if Assigned(FOldMouseDown) then
    FOldMouseDown(Sender, Button, Shift, X, Y);

  if (FViewer = nil) or (not FViewer.IsDocumentLoaded) then
    Exit;

  if Button = TMouseButton.mbLeft then
    BeginTurn(TPointF.Create(X, Y));
end; // ViewerMouseDown

//***************************************************************************
//
// OPERATION : Finish a page turn when the finger or left button is released.
//
// I/P       : Sender : TObject - The viewer.
//
//             Button : TMouseButton - Button that was released.
//
//             Shift : TShiftState - Modifier keys.
//
//             X, Y : Single - Release position in the viewer.
//
// O/P       : None
//
//***************************************************************************
procedure TPdfPageTurnTouch.ViewerMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var
  turnPos: TPointF;

begin
  if Assigned(FOldMouseUp) then
    FOldMouseUp(Sender, Button, Shift, X, Y);

  if (Button = TMouseButton.mbLeft) and FTracking and (FViewer <> nil) then
  begin
    turnPos := TPointF.Create(X, Y);
    FTracking := False;
    ReleaseViewer;
    FinishTurn(turnPos);
  end; // if
end; // ViewerMouseUp

end. // Pdf.PageTurn.Touch

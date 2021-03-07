unit MvActivityIndicator;

interface
uses
  vcl.controls,vcl.winXCtrls,extctrls,Graphics, WInAPI.messages, Classes,
    System.syncObjs;
type
  TThreadTimer = class(TThread)
  private
    FInterval: Cardinal;
    FOnTimer: TNotifyEvent;
    FEnabled: Boolean;
    procedure SetEnabled(Value: Boolean);
    procedure SetInterval(Value: Cardinal);
    procedure SetOnTimer(Value: TNotifyEvent);
  protected

    property Enabled: Boolean read FEnabled write SetEnabled default False;
    property Interval: Cardinal read FInterval write SetInterval default 1000;
    property OnTimer: TNotifyEvent read FOnTimer write SetOnTimer;

    procedure Execute; override;
    constructor Create;
    destructor Destroy; override;

  end;


  TMvActivityIndicator = class(TCustomControl)
  private
    FAnimate: Boolean;
    FIndicatorColor: TActivityIndicatorColor;
    FIndicatorSize: TActivityIndicatorSize;
    FIndicatorType: TActivityIndicatorType;
    FFrameDelay: Word;
    FFrameIndex: Integer;
    FTimer: TThreadTimer;
    FFrameList: TImageList;
    FFrameCount: Integer;
    FFrameSize: Integer;
    FFrameBitmap: TBitmap;
    FLoadedFrames: Boolean;


    procedure TimerExpired(Sender: TObject);

    // Property Access Methods
    procedure SetAnimate(Value: Boolean);
    procedure SetFrameDelay(Value: Word);
    procedure SetIndicatorColor(Value: TActivityIndicatorColor);
    procedure SetIndicatorSize(Value: TActivityIndicatorSize);
    procedure SetIndicatorType(Value: TActivityIndicatorType);

    // Message Handling Methods
    procedure WMEraseBkgnd(var Msg: TWMEraseBkgnd); message WM_ERASEBKGND;
  protected

    /// <summary>ReloadFrames is used to reload the appropriate set of animation frames from resources based on the
    /// current values of IndicatorType, IndicatorSize, and IndicatorColor.</summary>
    procedure ReloadFrames; virtual;
    /// <summary>DrawFrame is used to display a single frame of the current activity indicator animation sequence.</summary>
    procedure DrawFrame; virtual;

    procedure Paint; override;
    procedure Resize; override;

    property IndicatorColor: TActivityIndicatorColor read FIndicatorColor write SetIndicatorColor default aicBlack;
    property IndicatorType: TActivityIndicatorType read FIndicatorType write SetIndicatorType default aitMomentumDots;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure StartAnimation;
    procedure StopAnimation;
    property Animate: Boolean read FAnimate write SetAnimate default False;
    property FrameDelay: Word read FFrameDelay write SetFrameDelay default DefaultActivityIndicatorFrameDelay;
    property IndicatorSize: TActivityIndicatorSize read FIndicatorSize write SetIndicatorSize default aisMedium;

    property Height stored False;
    property Width stored False;

  end;

implementation
{$R MvActivityIndicator.res}

uses VCL.ImgList,VCL.Imaging.pngimage, winapi.windows,vcl.forms,System.SysUtils;

{ TThreadTimer Methods }
constructor TThreadTimer.Create;
begin
  inherited Create(True);
  FreeOnTerminate:=true;
  Priority:=tpHigher;
  Resume;
end;

destructor TThreadTimer.Destroy;
begin
  FEnabled:= False;

  inherited;
end;

procedure TThreadTimer.SetEnabled(Value: Boolean);
begin
    FEnabled := Value;
end;
procedure TThreadTimer.SetInterval(Value: Cardinal);
begin
  if Value <> FInterval then
  begin
    FInterval := Value;
  end;
end;
procedure TThreadTimer.SetOnTimer(Value: TNotifyEvent);
begin
  FOnTimer := Value;
end;

procedure TThreadTimer.Execute;
begin
  while not Terminated do
  begin
    if not Terminated and FEnabled then
    begin
      FOnTimer(Self);
      Sleep(FInterval);
    end
    else
    begin
      sleep(10);
    end;
  end;
end;





//=====================================================================================

procedure DrawParentImage(Control: TControl; DC: HDC; InvalidateParent: Boolean = False);
var
  SaveIndex: Integer;
  P: TPoint;
  parentForm:TCustomForm;
begin

  if Control.Parent = nil then
    Exit;

  parentForm:=GetParentForm(Control);
  SaveIndex := SaveDC(DC);
  GetViewportOrgEx(DC, P);

  SetViewportOrgEx(DC, P.X - Control.Left, P.Y - Control.Top, nil);
  IntersectClipRect(DC, 0, 0, Control.Parent.ClientWidth, Control.Parent.ClientHeight);

  parentForm.Perform(WM_ERASEBKGND, DC, 0);
  parentForm.Perform(WM_PRINTCLIENT, DC, prf_Client);

  RestoreDC(DC, SaveIndex);

  if InvalidateParent then
  begin
    if not (Control.Parent is TCustomControl) and not (Control.Parent is TCustomForm) and
       not (csDesigning in Control.ComponentState) then
    begin
      Control.Parent.Invalidate;
    end;
  end;
end;

{ TMvActivityIndicator Methods }

constructor TMvActivityIndicator.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csOpaque];
  FFrameSize := 32;
  Height := FFrameSize;
  Width := FFrameSize;

  FFrameDelay := DefaultActivityIndicatorFrameDelay;

  FFrameList := TImageList.Create(nil);
  FFrameList.ColorDepth := cd32Bit;
  FFrameList.DrawingStyle := dsTransparent;

  FFrameBitmap := Graphics.TBitmap.Create;
  FFrameBitmap.PixelFormat := pf32bit;

  FTimer := TThreadTimer.Create();

  FTimer.Interval := FFrameDelay;
  FTimer.Enabled := False;
  FTimer.OnTimer := TimerExpired;

  FIndicatorColor := aicBlack;
  FIndicatorSize := aisMedium;
  FIndicatorType := aitMomentumDots;
  FLoadedFrames := False;
end;

destructor TMvActivityIndicator.Destroy;
begin
  FTimer.Terminate;
  FFrameBitmap.Free;
  FFrameList.Free;
  inherited;
end;

procedure TMvActivityIndicator.ReloadFrames;
var
  Png: TPngImage;
  Bmp: Graphics.TBitmap;
  ResourceName: string;
const
  SizeName: array [TActivityIndicatorSize] of string = ('24', '32', '48', '64');

begin

  ResourceName := 'MV_MOMENTUMDOTS_BLUE_'  + SizeName[FIndicatorSize];

  Png := TPngImage.Create;
  try
    Bmp := Graphics.TBitmap.Create;
    try
      Png.LoadFromResourceName(HInstance, ResourceName);
      FFrameSize := Png.Height;
      FFrameCount := Png.Width div FFrameSize;
      FFrameBitmap.SetSize(FFrameSize, FFrameSize);

      FFrameList.Width := FFrameSize;
      FFrameList.Height := FFrameSize;

      Bmp.Assign(Png);
      FFrameList.Clear;
      FFrameList.Add(Bmp, nil);

    finally
      Bmp.Free;
    end;
  finally
    Png.Free;
  end;
  FLoadedFrames := True;

end;

procedure TMvActivityIndicator.WMEraseBkgnd(var Msg: TWMEraseBkgnd);
begin

  if (Parent <> nil) and Parent.DoubleBuffered then
    PerformEraseBackground(Self, Msg.DC);
  DrawParentImage(Self, Msg.DC, false);
  Msg.Result := 1;

end;

procedure TMvActivityIndicator.DrawFrame;
begin

  if (FFrameSize <= 0) or not FLoadedFrames then
    Exit;

  FFrameBitmap.Canvas.TryLock;
  Canvas.TryLock;

  if (Parent <> nil) and Parent.DoubleBuffered then
    PerformEraseBackground(Self, FFrameBitmap.Canvas.Handle);
  DrawParentImage(Self, FFrameBitmap.Canvas.Handle);

  if FAnimate then
    FFrameList.Draw(FFrameBitmap.Canvas, 0, 0, FFrameIndex);

  Canvas.Draw(0, 0, FFrameBitmap);

  canvas.Unlock;
  FFrameBitmap.Canvas.Unlock;

end;

procedure TMvActivityIndicator.Paint;
begin
  inherited;


  if csDesigning in ComponentState then
  begin
    Canvas.Pen.Style := psDot;
    Canvas.Brush.Style := bsClear;
    Canvas.Rectangle(ClientRect);
  end
  else
    DrawFrame;

end;

procedure TMvActivityIndicator.TimerExpired(Sender: TObject);
begin

    try

      FTimer.Interval := FFrameDelay;
      if FFrameIndex >= FFrameCount then
        FFrameIndex := 0;

      DrawFrame;

      Inc(FFrameIndex);
      if FFrameIndex = FFrameCount then
        FFrameIndex := 0;

    except
      Animate := False;
      raise;
    end;

end;

procedure TMvActivityIndicator.StartAnimation;
begin
  Animate := True;
end;

procedure TMvActivityIndicator.StopAnimation;
begin
  Animate := False;
end;

procedure TMvActivityIndicator.SetAnimate(Value: Boolean);
begin
  FAnimate := Value;

  if FAnimate then
  begin
    FFrameIndex := 0;
    if not FLoadedFrames then
      ReloadFrames
  end
  else
    DrawFrame;

  FTimer.Enabled := FAnimate;
end;

procedure TMvActivityIndicator.SetFrameDelay(Value: Word);
begin
  if FFrameDelay <> Value then
  begin
    FFrameDelay := Value;
    FTimer.Interval := FFrameDelay;
  end;
end;

procedure TMvActivityIndicator.SetIndicatorColor(Value: TActivityIndicatorColor);
var
  SaveAnimate: Boolean;
begin
  if FIndicatorColor <> Value then
  begin
    FIndicatorColor := Value;
    SaveAnimate := Animate;
    Animate := False;
    ReloadFrames;
    Animate := SaveAnimate;
  end;
end;

procedure TMvActivityIndicator.SetIndicatorSize(Value: TActivityIndicatorSize);
var
  SaveAnimate: Boolean;
begin
  if FIndicatorSize <> Value then
  begin
    FIndicatorSize := Value;
    SaveAnimate := Animate;
    Animate := False;
    ReloadFrames;
    Resize;
    Animate := SaveAnimate;
  end;
end;

procedure TMvActivityIndicator.SetIndicatorType(Value: TActivityIndicatorType);
var
  SaveAnimate: Boolean;
begin
  if FIndicatorType <> Value then
  begin
    FIndicatorType := Value;
    SaveAnimate := Animate;
    Animate := False;
    ReloadFrames;
    Animate := SaveAnimate;
  end;
end;

procedure TMvActivityIndicator.Resize;
begin
  inherited;

  SetBounds(Left, Top, FFrameSize, FFrameSize);

end;


end.


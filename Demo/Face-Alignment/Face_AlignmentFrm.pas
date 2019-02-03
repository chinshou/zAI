unit Face_AlignmentFrm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Controls.Presentation,
  FMX.StdCtrls, FMX.Objects, FMX.ScrollBox, FMX.Memo, FMX.Layouts, FMX.ExtCtrls,

  System.IOUtils,

  CoreClasses, zAI, zAI_Common, zDrawEngineInterface_SlowFMX, zDrawEngine, MemoryRaster, MemoryStream64,
  PascalStrings, UnicodeMixedLib, Geometry2DUnit, Geometry3DUnit;

type
  TFace_DetForm = class(TForm)
    Memo1: TMemo;
    PaintBox1: TPaintBox;
    AddPicButton: TButton;
    OpenDialog: TOpenDialog;
    Timer1: TTimer;
    Scale2CheckBox: TCheckBox;
    procedure AddPicButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure PaintBox1MouseDown(Sender: TObject; Button: TMouseButton; Shift:
      TShiftState; X, Y: Single);
    procedure PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure PaintBox1MouseUp(Sender: TObject; Button: TMouseButton; Shift:
      TShiftState; X, Y: Single);
    procedure PaintBox1MouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta:
      Integer; var Handled: Boolean);
    procedure PaintBox1Paint(Sender: TObject; Canvas: TCanvas);
    procedure Timer1Timer(Sender: TObject);
  private
    { Private declarations }
    lbc_Down: Boolean;
    lbc_pt: TVec2;
  public
    { Public declarations }
    drawIntf: TDrawEngineInterface_FMX;
    rList: TMemoryRasterList;
    ai: TAI;
  end;

var
  Face_DetForm: TFace_DetForm;

implementation

{$R *.fmx}


procedure TFace_DetForm.AddPicButtonClick(Sender: TObject);
var
  i, j: Integer;
  mr, nmr: TMemoryRaster;
  d: TDrawEngine;
  face_hnd: TFACE_Handle;
  sp_desc: TArrayVec2;
  r: TRectV2;
begin
  OpenDialog.Filter := TBitmapCodecManager.GetFilterString;
  if not OpenDialog.Execute then
      exit;
  for i := 0 to OpenDialog.Files.Count - 1 do
    begin
      mr := NewRasterFromFile(OpenDialog.Files[i]);

      if Scale2CheckBox.IsChecked then
        begin
          nmr := NewRaster;
          nmr.ZoomFrom(mr, mr.width * 4, mr.height * 4);
          face_hnd := ai.Face_Detector_All(nmr, 150);
          disposeObject(nmr);
        end
      else
        begin
          face_hnd := ai.Face_Detector_All(mr, 150);
        end;

      if face_hnd <> nil then
        begin
          d := TDrawEngine.Create;
          d.Rasterization.Memory.SetWorkMemory(mr);
          d.SetSize(mr);
          for j := 0 to ai.Face_Rect_Num(face_hnd) - 1 do
            begin
              sp_desc := ai.Face_ShapeV2(face_hnd, j);
              if Scale2CheckBox.IsChecked then
                  sp_desc := Vec2Mul(sp_desc, 0.25);
              DrawFaceSP(sp_desc, DEColor(1, 0, 0, 0.5), d);

              r := ai.Face_RectV2(face_hnd, j);
              if Scale2CheckBox.IsChecked then
                  r := RectMul(r, 0.25);
              d.DrawCorner(TV2Rect4.Init(r, 0), DEColor(1, 0, 0, 0.9), 30, 4);
              d.DrawText(IntToStr(j), 20, r, DEColor(1, 1, 1, 1), False);
            end;
          d.Flush;
          disposeObject(d);
        end;

      ai.Face_Close(face_hnd);

      rList.Add(mr);
    end;
end;

procedure TFace_DetForm.FormCreate(Sender: TObject);
begin
  // ��ȡzAI������
  ReadAIConfig;
  // ��һ��������Key����������֤ZAI��Key
  // ���ӷ�������֤Key������������ʱһ���Ե���֤��ֻ�ᵱ��������ʱ�Ż���֤��������֤����ͨ����zAI����ܾ�����
  // �ڳ��������У���������TAI�����ᷢ��Զ����֤
  // ��֤��Ҫһ��userKey��ͨ��userkey�����ZAI������ʱ���ɵ����Key��userkey����ͨ��web���룬Ҳ������ϵ���߷���
  // ��֤key���ǿ����Ӽ����޷����ƽ�
  zAI.Prepare_AI_Engine();
  ai := TAI.OpenEngine();

  drawIntf := TDrawEngineInterface_FMX.Create;
  rList := TMemoryRasterList.Create;

  lbc_Down := False;
  lbc_pt := Vec2(0, 0);
end;

procedure TFace_DetForm.PaintBox1MouseDown(Sender: TObject; Button:
  TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  lbc_pt := Vec2(TControl(Sender).LocalToAbsolute(Pointf(X, Y)));
end;

procedure TFace_DetForm.PaintBox1MouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Single);
var
  abs_pt, pt: TVec2;
  d: TDrawEngine;
begin
  abs_pt := Vec2(TControl(Sender).LocalToAbsolute(Pointf(X, Y)));
  pt := Vec2Sub(abs_pt, lbc_pt);
  d := DrawPool(Sender);

  if (ssLeft in Shift) then
      d.Offset := Vec2Add(d.Offset, pt);

  lbc_pt := Vec2(TControl(Sender).LocalToAbsolute(Pointf(X, Y)));
end;

procedure TFace_DetForm.PaintBox1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  lbc_Down := False;
end;

procedure TFace_DetForm.PaintBox1MouseWheel(Sender: TObject; Shift:
  TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  Handled := True;
  if WheelDelta > 0 then
    begin
      with DrawPool(PaintBox1) do
          Scale := Scale + 0.05;
    end
  else
    begin
      with DrawPool(PaintBox1) do
          Scale := Scale - 0.05;
    end;
end;

procedure TFace_DetForm.PaintBox1Paint(Sender: TObject; Canvas: TCanvas);
var
  d: TDrawEngine;
begin
  // ��DrawIntf�Ļ�ͼʵ�������paintbox1
  drawIntf.SetSurface(Canvas, Sender);
  d := DrawPool(Sender, drawIntf);

  // ��ʾ�߿��֡��
  d.ViewOptions := [devpFrameEndge];

  // ���������ɺ�ɫ������Ļ�ͼָ���������ִ�еģ������γ����������д����DrawEngine��һ��������
  d.FillBox(d.ScreenRect, DEColor(0, 0, 0, 1));

  d.DrawTexturePackingInScene(rList, 5, Vec2(0, 0), 1.0);

  d.BeginCaptureShadow(Vec2(1, 1), 0.9);
  d.DrawText(d.LastDrawInfo + #13#10 + '�������任���꣬���ֿ�������', 12, d.ScreenRect, DEColor(0.5, 1, 0.5, 1), False);
  d.EndCaptureShadow;
  d.Flush;
end;

procedure TFace_DetForm.Timer1Timer(Sender: TObject);
begin
  EnginePool.Progress(Interval2Delta(Timer1.Interval));
  Invalidate;
end;

end.
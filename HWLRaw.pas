unit HWLRaw;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, Wave;

type
  TForm5 = class(TForm)
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure WMEraseBkgnd(var m : TWMEraseBkgnd);
    procedure FormPaint(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
    Bitmap : TBitmap;        //The Thingie to draw/load with (SLOW!! :(
    procedure ReLoad;        //ReSize Window/Bitmap
    procedure ReCalc;        //ReCalc Window
  end;

var
  Form5: TForm5;

implementation

uses Main, HWL;

{$R *.DFM}

procedure TForm5.ReLoad;
begin
  Bitmap.HandleType:=bmDIB;       //device independent
  Bitmap.PixelFormat:=pf32bit;    //32Bit
  bitmap.width:=form1.pic_width;  //new BMP/Window-Dimensions
  bitmap.height:=form1.pic_height;
  self.height := form1.pic_height + GetSystemMetrics(SM_CYDLGFRAME) + GetSystemMetrics(SM_CYCAPTION);
  self.width  := form1.pic_width  + GetSystemMetrics(SM_CXDLGFRAME);
end;

procedure TForm5.ReCalc;
 var x,y : cardinal;
     col : cardinal;
     offset : cardinal;
     p : pcarray;
     shifty,shiftu,shiftv : longint;
begin
  shifty:=(1 shl form1.pic_quantbitsy);
  shiftu:=(1 shl form1.pic_quantbitsu);
  shiftv:=(1 shl form1.pic_quantbitsv);

  if form1.pic_bpp=HWL_GS then begin //Greyscale

   for y:=0 to form1.pic_height-1 do begin //paint HWL-RAW
    p:=Bitmap.Scanline[y];
    offset:=y*form1.pic_width;
    for x:=0 to form1.pic_width-1 do begin
     if (form1.pic_qHWL^[x +offset]<0) then col:=((-form1.pic_qHWL^[x +offset]*256) div shifty) shl 8 //Neg=Green
      else begin
       col:=(form1.pic_qHWL^[x +offset]*256) div shifty;
       col:=col or (col shl 8) or (col shl 16); //Grey
      end;
     p^[x]:=col;
    end;
   end;

  end else if form1.pic_bpp=HWL_RGB then //RGB

   for y:=0 to form1.pic_height-1 do begin //paint HWL-RAW
    p:=Bitmap.Scanline[y];
    offset:=y*form1.pic_width;
    for x:=0 to form1.pic_width-1 do begin
     col:=(abs(form1.pic_qHWLb^[x +offset]*256) div shiftv) or ((abs(form1.pic_qHWLg^[x +offset]*256) div shiftu) shl 8) or ((abs(form1.pic_qHWLr^[x +offset]*256) div shifty) shl 16);
     p^[x]:=col;
    end;
   end;

  self.FormPaint(nil); //ReDraw
end;

procedure TForm5.WMEraseBkgnd(var m : TWMEraseBkgnd);
begin
  m.Result := LRESULT(False);
end;

procedure TForm5.FormPaint(Sender: TObject);
begin
  Canvas.Draw(0,0,Bitmap);
end;

procedure TForm5.FormDestroy(Sender: TObject);
begin
  Bitmap.Free;
end;

procedure TForm5.FormCreate(Sender: TObject);
begin
  Bitmap := TBitmap.Create;
end;

procedure TForm5.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Form1.HWLRaw1.checked:=false;
end;

end.

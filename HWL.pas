unit HWL;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, Wave;

type
  TForm3 = class(TForm)
    procedure WMEraseBkgnd(var m : TWMEraseBkgnd);
    procedure FormPaint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
    Bitmap : TBitmap;        //The Thingie to draw/load with (SLOW!! :(
    procedure ReCalc;        //ReSize Window/Bitmap
    procedure ReLoad;        //ReCalc Window
  end;

var
  Form3: TForm3;

implementation

uses Main;

{$R *.DFM}

procedure TForm3.ReLoad;
begin
  Bitmap.HandleType:=bmDIB;        //device independent
  Bitmap.PixelFormat:=pf32bit;     //32Bit
  bitmap.width:=form1.pic_width;   //new BMP/Window-Dimensions
  bitmap.height:=form1.pic_height;
  self.height := form1.pic_height + GetSystemMetrics(SM_CYDLGFRAME) + GetSystemMetrics(SM_CYCAPTION);
  self.width  := form1.pic_width  + GetSystemMetrics(SM_CXDLGFRAME);
end;

procedure TForm3.ReCalc;
 var zeroc : cardinal;
begin
  if form1.pic_bpp=HWL_GS then begin //GREYSCALE
   move(form1.pic_oBMP^,form1.pic_BMP^,form1.pic_height*form1.pic_width*sizeof(double)); //copy Original-FloatPoint-BMP
   WaveletGS(form1.pic_BMP,form1.pic_oHWL,form1.pic_width,form1.pic_height,form1.pic_width,form1.pic_height,form1.pic_subdivisiondepth); //make HWL

   Form1.CoefficientsKickedLabel.Caption:=inttostr(WaveletZeroOutGS(form1.pic_oHWL,form1.pic_eps,form1.pic_quantbitsy,form1.pic_width,form1.pic_height,form1.pic_subdivisiondepth)); //kick Coefficients and redraw Label

   WaveletQuantGS(form1.pic_oHWL,form1.pic_qHWL,form1.pic_width,form1.pic_height,form1.pic_subdivisiondepth,form1.pic_quantbitsy,form1.pic_quantfactor); //quant wavelet

   zeroc:=WaveletCountZerosGS(form1.pic_qHWL,form1.pic_width,form1.pic_height,form1.pic_subdivisiondepth);
   Form1.CoefficientsKickedLabel.Caption:=Form1.CoefficientsKickedLabel.Caption+'/'+inttostr(zeroc)+'  ('+inttostr(round((zeroc/strtoint(Form1.ByteSizeLabel.Caption))*100.0))+'%)'; //count zeros

   DeWaveletQuantGS(form1.pic_qHWL,form1.pic_HWL,form1.pic_width,form1.pic_height,form1.pic_subdivisiondepth,form1.pic_quantfactor); //dequant

   DeWaveletGS(form1.pic_HWL,form1.pic_BMP,form1.pic_width,form1.pic_height,form1.pic_width,form1.pic_height,form1.pic_subdivisiondepth); //restore BMP from HWL

   form1.copyDouble2BitmapGS(form1.pic_BMP,self.Bitmap); //copy to window
  end else if form1.pic_bpp=HWL_RGB then begin //RGB
   move(form1.pic_oBMPb^,form1.pic_BMPb^,form1.pic_height*form1.pic_width*sizeof(double)); //copy original-float-point-BMP (Blue)
   move(form1.pic_oBMPg^,form1.pic_BMPg^,form1.pic_height*form1.pic_width*sizeof(double)); //copy original-float-point-BMP (Green)
   move(form1.pic_oBMPr^,form1.pic_BMPr^,form1.pic_height*form1.pic_width*sizeof(double)); //copy original-float-point-BMP (Red)

   WaveletRGB(form1.pic_BMPr,form1.pic_BMPg,form1.pic_BMPb,form1.pic_oHWLr,form1.pic_oHWLg,form1.pic_oHWLb,form1.pic_width,form1.pic_height,form1.pic_width,form1.pic_height,form1.pic_subdivisiondepth); //make HWL (RGB)

   Form1.CoefficientsKickedLabel.Caption:=inttostr(WaveletZeroOutGS(form1.pic_oHWLb,form1.pic_eps,form1.pic_quantbitsy,form1.pic_width,form1.pic_height,form1.pic_subdivisiondepth)
                                                   +WaveletZeroOutGS(form1.pic_oHWLg,form1.pic_eps,form1.pic_quantbitsu,form1.pic_width,form1.pic_height,form1.pic_subdivisiondepth)
                                                   +WaveletZeroOutGS(form1.pic_oHWLr,form1.pic_eps,form1.pic_quantbitsv,form1.pic_width,form1.pic_height,form1.pic_subdivisiondepth)); //kick Coefficients and redraw Label

   WaveletQuantRGB(form1.pic_oHWLr,form1.pic_oHWLg,form1.pic_oHWLb,form1.pic_qHWLr,form1.pic_qHWLg,form1.pic_qHWLb,form1.pic_width,form1.pic_height,form1.pic_subdivisiondepth,form1.pic_quantbitsy,form1.pic_quantbitsu,form1.pic_quantbitsv,form1.pic_quantfactorr,form1.pic_quantfactorg,form1.pic_quantfactorb); //quant wavelet (RGB)

   zeroc:=WaveletCountZerosGS(form1.pic_qHWLb,form1.pic_width,form1.pic_height,form1.pic_subdivisiondepth)
         +WaveletCountZerosGS(form1.pic_qHWLg,form1.pic_width,form1.pic_height,form1.pic_subdivisiondepth)
         +WaveletCountZerosGS(form1.pic_qHWLr,form1.pic_width,form1.pic_height,form1.pic_subdivisiondepth);
   Form1.CoefficientsKickedLabel.Caption:=Form1.CoefficientsKickedLabel.Caption+'/'+inttostr(zeroc)+'  ('+inttostr(round((zeroc/strtoint(Form1.ByteSizeLabel.Caption))*100.0))+'%)'; //count zeros

   DeWaveletQuantRGB(form1.pic_qHWLr,form1.pic_qHWLg,form1.pic_qHWLb,form1.pic_HWLr,form1.pic_HWLg,form1.pic_HWLb,form1.pic_width,form1.pic_height,form1.pic_subdivisiondepth,form1.pic_quantfactorr,form1.pic_quantfactorg,form1.pic_quantfactorb); //dequant (RGB)

   DeWaveletRGB(form1.pic_HWLr,form1.pic_HWLg,form1.pic_HWLb,form1.pic_BMPr,form1.pic_BMPg,form1.pic_BMPb,form1.pic_width,form1.pic_height,form1.pic_width,form1.pic_height,form1.pic_subdivisiondepth); //restore BMP from HWL (RGB)

   form1.copyDouble2BitmapRGB(form1.pic_BMPr,form1.pic_BMPg,form1.pic_BMPb,self.Bitmap); //copy to Window
  end;

  self.FormPaint(nil); //ReDraw
end;

procedure TForm3.WMEraseBkgnd(var m : TWMEraseBkgnd); //Anti-Flicker
begin
  m.Result := LRESULT(False);
end;

procedure TForm3.FormPaint(Sender: TObject); //Redraw
begin
  Canvas.Draw(0,0,Bitmap);
end;

procedure TForm3.FormCreate(Sender: TObject);
begin
  Bitmap := TBitmap.Create;
end;

procedure TForm3.FormDestroy(Sender: TObject);
begin
  Bitmap.Free;
end;

procedure TForm3.FormClose(Sender: TObject; var Action: TCloseAction); //Window->HWL
begin
  Form1.HWL1.checked:=false;
end;

end.

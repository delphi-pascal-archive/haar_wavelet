unit Main;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Menus, ComCtrls, ExtCtrls, StdCtrls, Spin, Wave;

type
  TForm1 = class(TForm)
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    OpenBMP: TMenuItem;
    Save1: TMenuItem;
    Exit1: TMenuItem;
    N1: TMenuItem;
    About1: TMenuItem;
    OpenHWL: TMenuItem;
    Panel1: TPanel;
    Label1: TLabel;
    BmpSizeLabel: TLabel;
    Label3: TLabel;
    ByteSizeLabel: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    HWLsizeLabel: TLabel;
    CoefficientsKickedLabel: TLabel;
    Label9: TLabel;
    SubdivisionSpin: TSpinEdit;
    Label11: TLabel;
    EpsilonSpin: TSpinEdit;
    OpenDialog1: TOpenDialog;
    Window1: TMenuItem;
    BMP1: TMenuItem;
    HWL1: TMenuItem;
    HWLRaw1: TMenuItem;
    SaveDialog1: TSaveDialog;
    OpenDialog2: TOpenDialog;
    QuantBitsYSpin: TSpinEdit;
    Label2: TLabel;
    Label4: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    QuantBitsUVSpin: TSpinEdit;
    Image1: TImage;
    Image2: TImage;
    procedure Exit1Click(Sender: TObject);
    procedure EpsilonSpinChange(Sender: TObject);
    procedure SubdivisionSpinChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure OpenBMPClick(Sender: TObject);
    procedure About1Click(Sender: TObject);
    procedure BMP1Click(Sender: TObject);
    procedure HWL1Click(Sender: TObject);
    procedure HWLRaw1Click(Sender: TObject);
    procedure Save1Click(Sender: TObject);
    procedure OpenHWLClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure QuantBitsYSpinChange(Sender: TObject);
    procedure QuantBitsUVSpinChange(Sender: TObject);
    procedure Image1Click(Sender: TObject);
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
    BMPName : string;
    pic_height,pic_width,pic_bpp,pic_subdivisiondepth,pic_eps,pic_quantbitsy,pic_quantbitsu,pic_quantbitsv : cardinal; //Dimensions,BPP,SubdivisionDepth,Coeff.Epsilon,QuantizerBits
    pic_quantfactor,pic_quantfactorr,pic_quantfactorg,pic_quantfactorb : pfarray;       //Quantizer-Scaling-Factors
    pic_bitmap : TBitmap;       //Loaded Bitmap

    pic_oBMP,pic_BMP : PFarray; //Floating-Point Versions of GreyScale-BMPs
    pic_oBMPr,pic_BMPr,pic_oBMPg,pic_BMPg,pic_oBMPb,pic_BMPb : PFarray; //Fl.Point-RGB-BMPs

    pic_oHWL,pic_HWL : PFarray; //GreyScale-HWLs
    pic_oHWLr,pic_HWLr,pic_oHWLg,pic_HWLg,pic_oHWLb,pic_HWLb : PFarray; //RGB-HWLs

    pic_qHWL : PIarray; //GreyScale-Quantized-HWL
    pic_qHWLr,pic_qHWLg,pic_qHWLb : PIarray; //RGB-Quantized-HWLs

    procedure ReLoad;       //Load BMP, Set Dimensions, Init Defaults, etc.
    procedure ReCalc;       //Calc Transformations, etc.
    procedure allocMemGS;   //Allocate Memory for a GreyScale-Pic
    procedure allocMemRGB;  //Mem for a RGB-Pic
    procedure getMaxSubdivisionDepth;  //Calc Maximum SubdivisonDepth from pic_width,pic_height
    procedure getBPP(BMP : TBitmap);   //GreyScale or RGB ??!
    procedure copyDouble2BitmapGS(src : PFarray; BMP : TBitmap);    //Convert the Greyscale-"FloatingPoint-BMP" into a "Integer-BMP"
    procedure copyDouble2BitmapRGB(r,g,b : PFarray; BMP : TBitmap); //Same for RGB
    procedure copyBitmap2DoubleGS(BMP : TBitmap; dest : PFarray);   //And the Greyscale-Inverse (Int->Float)
    procedure copyBitmap2DoubleRGB(BMP : TBitmap; r,g,b : PFarray); //Same for RGB
    function  getFileSize(name : string) : cardinal;                //Get FileSize of File "name"
  end;

const
  defaultBMPName='hwltest.bmp'; //Test-Default-BMP

var
  Form1: TForm1;
  init_dirty_flag : boolean;            //Used for Initialization
  default_eps,default_bitsy,default_bitsuv : cardinal;  //Defaults

implementation

uses HWL, BMP, About, HWLRaw;

{$R *.DFM}

procedure TForm1.Exit1Click(Sender: TObject); //Menu->File->Exit
begin
  self.close;
end;

//On-Change-Stuff

procedure TForm1.EpsilonSpinChange(Sender: TObject); //Coefficient-Epsilon
begin
  if pic_eps<>EpsilonSpin.Value then begin
   pic_eps:=EpsilonSpin.Value;
   ReCalc;
  end;
end;

procedure TForm1.SubdivisionSpinChange(Sender: TObject); //Subdivision-Depth
begin
 if (SubdivisionSpin.MaxValue>0) then begin
  if (pic_subdivisiondepth<>SubdivisionSpin.Value) then begin
   if SubdivisionSpin.Value<SubdivisionSpin.MaxValue then pic_subdivisiondepth:=SubdivisionSpin.Value
    else pic_subdivisiondepth:=SubdivisionSpin.MaxValue;
   ReCalc;
  end;
 end else SubdivisionSpin.Value:=0;
end;

procedure TForm1.QuantBitsYSpinChange(Sender: TObject); //Quantizer-Bits
begin
  if pic_quantbitsy<>QuantBitsYSpin.Value then begin
   if QuantBitsYSpin.Value<QuantBitsYSpin.MaxValue then
    if QuantBitsYSpin.Value>QuantBitsYSpin.MinValue then pic_quantbitsy:=QuantBitsYSpin.Value
     else pic_quantbitsy:=QuantBitsYSpin.MinValue
      else pic_quantbitsy:=QuantBitsYSpin.MaxValue;
   ReCalc;
  end;
end;

//End On-Change-Stuff

procedure TForm1.FormCreate(Sender: TObject); //Creation of MainForm
begin
  BMPName:=defaultBMPName;     //Load Test-BMP on StartUp
  pic_bitmap:=TBitmap.Create;  //Create BMP
  getmem(pic_quantfactor,18*sizeof(double));  //Quantizer-Scaling-Factors
  getmem(pic_quantfactorr,18*sizeof(double));
  getmem(pic_quantfactorg,18*sizeof(double));
  getmem(pic_quantfactorb,18*sizeof(double));
  init_dirty_flag:=true;
end;

procedure TForm1.FormActivate(Sender: TObject); //Acvtivation of MainForm
begin
  if init_dirty_flag then begin
   pic_eps:=EpsilonSpin.Value;     //assign Defaults
   default_eps:=EpsilonSpin.Value;
   pic_quantbitsy:=QuantBitsYSpin.Value;
   pic_quantbitsu:=QuantBitsUVSpin.Value;
   pic_quantbitsv:=QuantBitsUVSpin.Value;
   default_bitsy:=QuantBitsYSpin.Value;
   default_bitsuv:=QuantBitsUVSpin.Value;

   ReLoad;                         //Load BMP

   pic_subdivisiondepth:=SubdivisionSpin.Value;

   ReCalc;                         //Calc Wavelet,etc.
   init_dirty_flag:=false;
  end;
end;

procedure TForm1.OpenBMPClick(Sender: TObject); //Load .BMP
begin
  if OpenDialog1.Execute then begin
   BMPName:=OpenDialog1.FileName;
   ReLoad;
   ReCalc;
  end;
end;

procedure TForm1.About1Click(Sender: TObject); //Menu->?->About
begin
  form4.showmodal;
end;

//Menu->Window

procedure TForm1.BMP1Click(Sender: TObject); //Window->BMP
begin
  if BMP1.checked then begin form2.close; BMP1.checked:=false; end
   else begin form2.show; BMP1.checked:=true; end;
end;

procedure TForm1.HWL1Click(Sender: TObject); //Window->HWL
begin
  if HWL1.checked then begin form3.close; HWL1.checked:=false; end
   else begin form3.show; HWL1.checked:=true; end;
end;

procedure TForm1.HWLRaw1Click(Sender: TObject); //Window->HWL-RAW
begin
  if HWLRaw1.checked then begin form5.close; HWLRaw1.checked:=false; end
   else begin form5.show; HWLRaw1.checked:=true; end;
end;

//End Menu->Window

procedure TForm1.Save1Click(Sender: TObject); //Save As .HWL
begin
  if SaveDialog1.Execute then
   if pic_bpp=HWL_GS then
    WriteHWL(SaveDialog1.Filename,pic_qHWL,nil,nil,pic_width,pic_height,pic_bpp,pic_subdivisiondepth,pic_quantfactor,nil,nil,pic_quantbitsy,0,0)
   else if pic_bpp=HWL_RGB then
    WriteHWL(SaveDialog1.Filename,pic_qHWLr,pic_qHWLg,pic_qHWLb,pic_width,pic_height,pic_bpp,pic_subdivisiondepth,pic_quantfactorr,pic_quantfactorg,pic_quantfactorb,pic_quantbitsy,pic_quantbitsu,pic_quantbitsv);
end;

procedure TForm1.OpenHWLClick(Sender: TObject); //Open .HWL
 Var hwl_head : HWL_Header;
begin
  if OpenDialog2.Execute then begin
   ReadHeaderHWL(OpenDialog2.Filename,hwl_head); //Get Information about the HWL-File

   pic_width:=hwl_head.width;                    //Assign Global Variables
   pic_height:=hwl_head.height;
   pic_bpp:=hwl_head.bpp;
   pic_subdivisiondepth:=hwl_head.depth;
   pic_eps:=0;
   pic_quantbitsy:=hwl_head.quantbitsy;
   pic_quantbitsu:=hwl_head.quantbitsu;
   pic_quantbitsv:=hwl_head.quantbitsv;

   pic_bitmap.width:=pic_width;                  //Assign Window
   pic_bitmap.height:=pic_height;
   pic_bitmap.HandleType:=bmDIB;                 //Device-Independent
   pic_bitmap.PixelFormat:=pf32bit;              //32Bit-RGB

   if pic_bpp=HWL_GS then begin                  //Greyscale
    QuantBitsUVSpin.Enabled:=false;
    ByteSizeLabel.Caption:=inttostr(pic_width*pic_height); //Byte-Size

    self.allocmemGS;                             //Getmem

    ReadHWL(OpenDialog2.Filename,pic_qHWL,nil,nil,pic_quantfactor,nil,nil); //Load HWL

    DeWaveletQuantGS(pic_qHWL,pic_oHWL,pic_width,pic_height,pic_subdivisiondepth,pic_quantfactor); //DeQuant

    DeWaveletGS(pic_oHWL,pic_oBMP,pic_width,pic_height,pic_width,pic_height,pic_subdivisiondepth); //Restore BMP from HWL

    self.copydouble2bitmapGS(pic_oBMP,pic_Bitmap); //Load into Window
   end else if pic_bpp=HWL_RGB then begin //RGB
    QuantBitsUVSpin.Enabled:=true;
    ByteSizeLabel.Caption:=inttostr(pic_width*pic_height*3); //Byte-Size

    self.allocmemRGB;                     //Getmem

    ReadHWL(OpenDialog2.Filename,pic_qHWLr,pic_qHWLg,pic_qHWLb,pic_quantfactorr,pic_quantfactorg,pic_quantfactorb); //Load HWL

    DeWaveletQuantRGB(pic_qHWLr,pic_qHWLg,pic_qHWLb,pic_oHWLr,pic_oHWLg,pic_oHWLb,pic_width,pic_height,pic_subdivisiondepth,pic_quantfactorr,pic_quantfactorg,pic_quantfactorb); //DeQuant Red/Green/Blue

    DeWaveletRGB(pic_oHWLr,pic_oHWLg,pic_oHWLb,pic_oBMPr,pic_oBMPg,pic_oBMPb,pic_width,pic_height,pic_width,pic_height,pic_subdivisiondepth); //Restore BMP from HWL (RGB)

    self.copydouble2bitmapRGB(pic_oBMPr,pic_oBMPg,pic_oBMPb,pic_bitmap); //Load into Window
   end;

   Form2.ReLoad; //ReSize/Draw Windows
   Form5.ReLoad;
   Form3.ReLoad;

   self.getMaxSubdivisionDepth;        //Assign Spin-Controls/Labels on Mainform
   QuantBitsYSpin.Value:=pic_quantbitsy;
   QuantBitsUVSpin.Value:=pic_quantbitsu;
   SubdivisionSpin.Value:=pic_subdivisiondepth;
   EpsilonSpin.Value:=pic_eps;
   BmpSizeLabel.Caption:='N.A.';

   Form5.ReCalc; //ReCalc HWL-RAW
   Form3.ReCalc; //HWL
  end;
end;

procedure TForm1.allocMemGS; //Getmem Greyscale
begin
   reallocmem(pic_oHWL,pic_width*pic_height*sizeof(double)); //alloc mem for BMPs/HWLs
   reallocmem(pic_HWL,pic_width*pic_height*sizeof(double));
   reallocmem(pic_oBMP,pic_width*pic_height*sizeof(double));
   reallocmem(pic_BMP,pic_width*pic_height*sizeof(double));
   reallocmem(pic_qHWL,pic_width*pic_height*sizeof(longint));
end;

procedure TForm1.allocMemRGB; //Getmem RGB
begin
   reallocmem(pic_oHWLr,pic_width*pic_height*sizeof(double)); //alloc mem for BMPs/HWLs R
   reallocmem(pic_HWLr,pic_width*pic_height*sizeof(double));
   reallocmem(pic_oBMPr,pic_width*pic_height*sizeof(double));
   reallocmem(pic_BMPr,pic_width*pic_height*sizeof(double));
   reallocmem(pic_qHWLr,pic_width*pic_height*sizeof(longint));

   reallocmem(pic_oHWLg,pic_width*pic_height*sizeof(double)); //alloc mem for BMPs/HWLs G
   reallocmem(pic_HWLg,pic_width*pic_height*sizeof(double));
   reallocmem(pic_oBMPg,pic_width*pic_height*sizeof(double));
   reallocmem(pic_BMPg,pic_width*pic_height*sizeof(double));
   reallocmem(pic_qHWLg,pic_width*pic_height*sizeof(longint));

   reallocmem(pic_oHWLb,pic_width*pic_height*sizeof(double)); //alloc mem for BMPs/HWLs B
   reallocmem(pic_HWLb,pic_width*pic_height*sizeof(double));
   reallocmem(pic_oBMPb,pic_width*pic_height*sizeof(double));
   reallocmem(pic_BMPb,pic_width*pic_height*sizeof(double));
   reallocmem(pic_qHWLb,pic_width*pic_height*sizeof(longint));
end;

procedure TForm1.getMaxSubdivisionDepth; //Get the Maximum Subdivision Depth
 var v,v2,m : longint;
begin
  v:=pic_width;
  v2:=pic_height;
  m:=0;
  while (v>0) and (v2>0) do begin
   inc(m);
   if (v mod 2=1) or (v2 mod 2=1) then break;
   v:=v div 2;
   v2:=v2 div 2;
  end;
  if m>2 then SubdivisionSpin.maxvalue:=m-2      //Assign
   else SubdivisionSpin.maxvalue:=0;
  if pic_subdivisiondepth>SubdivisionSpin.maxvalue then begin
   pic_subdivisiondepth:=SubdivisionSpin.maxvalue;
   SubdivisionSpin.value:=pic_subdivisiondepth;
  end;
end;

procedure TForm1.getBPP(BMP : TBitmap); //Greyscale/RGB ??
 var x,y : longint;
     p : pcarray;
begin
  pic_BPP:=HWL_GS;                  //"hope" we have a greyscale-pic
  for y:=0 to pic_height-1 do begin //check if not RGB
   p:=BMP.Scanline[y];
   for x:=0 to pic_width-1 do
    if ((p^[x] and $FF)<>(p^[x] and $FF00)shr 8)
       or ((p^[x] and $FF0000)shr 16<>(p^[x] and $FF00)shr 8)
       or ((p^[x] and $FF0000)shr 16<>(p^[x] and $FF)) then begin //if B=G or G=R or R=B (=GREYSCALE)
     pic_BPP:=HWL_RGB;
     exit;
    end;
  end;
end;

procedure TForm1.copyDouble2BitmapGS(src : PFarray; BMP : TBitmap); //Greyscale-FloatingPoint-BMP to Integer-BMP
 var x,y : longint;
     offset,col : cardinal;
     p : pcarray;
begin
    for y:=0 to pic_height-1 do begin
     p:=BMP.Scanline[y];
     offset:=y*pic_width;
     for x:=0 to pic_width-1 do begin
      if src^[x +offset]>0.0 then begin
       if src^[x +offset]<255.0 then begin
        col:=round(src^[x +offset]);
        col:=col or (col shl 8) or (col shl 16);
       end else col:=$FFFFFF;
      end else col:=0;
      p^[x]:=col;
     end;
    end;
end;

procedure TForm1.copyDouble2BitmapRGB(r,g,b : PFarray; BMP : TBitmap); //RGB-FloatingPoint-BMP to Integer-BMP
 var x,y : longint;
     offset,col : cardinal;
     p : pcarray;
begin
    for y:=0 to pic_height-1 do begin
     p:=BMP.Scanline[y];
     offset:=y*pic_width;
     for x:=0 to pic_width-1 do begin
      if b^[x +offset]>0.0 then begin
       if b^[x +offset]<255.0 then begin
        col:=round(b^[x +offset]);
       end else col:=$FF;
      end else col:=0;

      if g^[x +offset]>0.0 then begin
       if g^[x +offset]<255.0 then begin
        col:=col or (round(g^[x +offset])shl 8);
       end else col:=col or $FF00;
      end;

      if r^[x +offset]>0.0 then begin
       if r^[x +offset]<255.0 then begin
        col:=col or (round(r^[x +offset])shl 16);
       end else col:=col or $FF0000;
      end;

      p^[x]:=col;
     end;
    end;
end;

procedure TForm1.copyBitmap2DoubleGS(BMP : TBitmap; dest : PFarray); //Greyscale-Integer-BMP to FloatingPoint-BMP
 var x,y : longint;
     offset : cardinal;
     p : pcarray;
begin
   for y:=0 to pic_height-1 do begin
    p:=BMP.Scanline[y];
    offset:=y*pic_width;
    for x:=0 to pic_width-1 do
     dest^[x +offset]:=p^[x] and $FF;
   end;
end;

procedure TForm1.copyBitmap2DoubleRGB(BMP : TBitmap; r,g,b : PFarray); //RGB-Integer-BMP to FloatingPoint-BMP
 var x,y : longint;
     offset : cardinal;
     p : pcarray;
begin
   for y:=0 to pic_height-1 do begin
    p:=BMP.Scanline[y];
    offset:=y*pic_width;
    for x:=0 to pic_width-1 do begin
     b^[x +offset]:=p^[x] and $FF;
     g^[x +offset]:=(p^[x] and $FF00) shr 8;
     r^[x +offset]:=(p^[x] and $FF0000) shr 16;
    end;
   end;
end;

function  TForm1.getFileSize(name : string) : cardinal;
 var f : file;
begin
  AssignFile(f,Name);
  FileMode:=0;
  Reset(f,1);
  Result:=FileSize(f);
  CloseFile(f);
end;


procedure TForm1.ReCalc;
begin
  Form3.ReCalc; //HWL
  Form5.ReCalc; //HWL-RAW
end;

procedure TForm1.ReLoad;
begin
  pic_bitmap.HandleType:=bmDIB;
  pic_bitmap.PixelFormat:=pf32bit;
  pic_bitmap.LoadFromFile(BMPName); //to get dimensions and alloc bitmap-mem
  pic_bitmap.HandleType:=bmDIB;     //device independent
  pic_bitmap.PixelFormat:=pf32bit;  //32bits

  pic_width:=pic_bitmap.width;      //assign
  pic_height:=pic_bitmap.height;

  self.getbpp(pic_bitmap);

  //application.messagebox(@(inttostr(pic_bpp)+#0)[1],'PIC_BPP',0); //TESTING PURPOSE

  self.getMaxSubdivisionDepth;      //get Maximum Subdivison Depth

  BmpSizeLabel.Caption:=inttostr(self.getFileSize(BMPName)); //Original-BMP-Size

  if pic_bpp=HWL_GS then begin       //GREYSCALE
   QuantBitsUVSpin.Enabled:=false;
   ByteSizeLabel.Caption:=inttostr(pic_width*pic_height); //Byte-Size
   self.allocmemGS;
   self.copybitmap2doubleGS(pic_bitmap,pic_oBMP);
  end else if pic_bpp=HWL_RGB then begin //RGB
   QuantBitsUVSpin.Enabled:=true;
   ByteSizeLabel.Caption:=inttostr(pic_width*pic_height*3); //Byte-Size
   self.allocmemRGB;
   self.copybitmap2doubleRGB(pic_bitmap,pic_oBMPr,pic_oBMPg,pic_oBMPb);
  end;

  Form2.ReLoad; //BMP
  Form3.ReLoad; //HWL
  Form5.ReLoad; //HWL-RAW

  SubdivisionSpin.value:=SubdivisionSpin.maxvalue; //Assign Spin-Controls
  EpsilonSpin.value:=default_eps;
  QuantBitsYSpin.value:=default_bitsy;
  QuantBitsUVSpin.value:=default_bitsuv;
end;

procedure TForm1.QuantBitsUVSpinChange(Sender: TObject);
begin
  if pic_quantbitsu<>QuantBitsUVSpin.Value then begin
   if QuantBitsUVSpin.Value<QuantBitsUVSpin.MaxValue then
    if QuantBitsUVSpin.Value>QuantBitsUVSpin.MinValue then pic_quantbitsu:=QuantBitsUVSpin.Value
     else pic_quantbitsu:=QuantBitsUVSpin.MinValue
      else pic_quantbitsu:=QuantBitsUVSpin.MaxValue;
   pic_quantbitsv:=pic_quantbitsu;
   ReCalc;
  end;
end;

procedure TForm1.Image1Click(Sender: TObject);
begin
  form4.showmodal;
end;

end.

program waveletc;
{$APPTYPE CONSOLE}

(*  Wavelet encoder command line utility *)
(*  Version 1.0 by nitro/Ainc            *)
(*  Sorry, code is quite messy as it is  *)
(*  mostly copy/paste from the gui-src   *)
(*  which is a bit ehrrrm... messy   :-) *)

uses
  SysUtils,
  wave,
  windows,
  graphics;

var     pic_bitmap : TBitmap;
        pic_height,pic_width,
        pic_bpp,pic_subdivisiondepth,
        pic_eps,pic_maxsubdivisiondepth,
        pic_quantbitsy,
        pic_quantbitsu,pic_quantbitsv : cardinal; //Dimensions,BPP,SubdivisionDepth,Coeff.Epsilon,QuantizerBits
        inFilename         : string;
        outFilename     : string;


    pic_oBMP : PFarray; //Floating-Point Versions of GreyScale-BMPs
    pic_oBMPr, pic_oBMPg, pic_oBMPb : PFarray; //Fl.Point-RGB-BMPs

    pic_oHWL  : PFarray; //GreyScale-HWLs
    pic_oHWLr, pic_oHWLg, pic_oHWLb  : PFarray; //RGB-HWLs

    pic_qHWL : PIarray; //GreyScale-Quantized-HWL
    pic_qHWLr,pic_qHWLg,pic_qHWLb : PIarray; //RGB-Quantized-HWLs
    pic_quantfactor,pic_quantfactorr,pic_quantfactorg,pic_quantfactorb : pfarray;       //Quantizer-Scaling-Factors

procedure getMaxSubdivisionDepth; //Get the Maximum Subdivision Depth
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
  if m>2 then pic_maxsubdivisiondepth:=m-2      //Assign
   else pic_maxsubdivisiondepth:=0;
  if pic_subdivisiondepth>pic_maxsubdivisiondepth then
    pic_subdivisiondepth := pic_maxsubdivisiondepth;
end;


procedure EncodeWavelet;
begin

  if pic_bpp=HWL_GS then begin //GREYSCALE
   WaveletGS(pic_oBMP, pic_oHWL, pic_width, pic_height, pic_width, pic_height, pic_subdivisiondepth); //make HWL
   WaveletZeroOutGS(pic_oHWL,pic_eps,pic_quantbitsy,pic_width,pic_height,pic_subdivisiondepth);
   WaveletQuantGS(pic_oHWL, pic_qHWL, pic_width, pic_height, pic_subdivisiondepth, pic_quantbitsy, pic_quantfactor); //quant wavelet

  end else if pic_bpp=HWL_RGB then begin //RGB

   WaveletRGB(pic_oBMPr, pic_oBMPg, pic_oBMPb, pic_oHWLr, pic_oHWLg, pic_oHWLb, pic_width, pic_height, pic_width, pic_height, pic_subdivisiondepth); //make HWL (RGB)
   WaveletZeroOutGS(pic_oHWLb, pic_eps, pic_quantbitsy, pic_width, pic_height, pic_subdivisiondepth);
   WaveletZeroOutGS(pic_oHWLg, pic_eps, pic_quantbitsu, pic_width, pic_height, pic_subdivisiondepth);
   WaveletZeroOutGS(pic_oHWLr, pic_eps, pic_quantbitsv, pic_width, pic_height, pic_subdivisiondepth);

   WaveletQuantRGB(pic_oHWLr, pic_oHWLg, pic_oHWLb, pic_qHWLr, pic_qHWLg, pic_qHWLb, pic_width, pic_height, pic_subdivisiondepth, pic_quantbitsy, pic_quantbitsu, pic_quantbitsv, pic_quantfactorr, pic_quantfactorg, pic_quantfactorb); //quant wavelet (RGB)
  end;
end;

procedure getBPP(BMP : TBitmap); //Greyscale/RGB ??
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

procedure allocMemGS; //Getmem Greyscale
begin
   reallocmem(pic_oHWL,pic_width*pic_height*sizeof(double)); //alloc mem for BMPs/HWLs
   reallocmem(pic_oBMP,pic_width*pic_height*sizeof(double));
   reallocmem(pic_qHWL,pic_width*pic_height*sizeof(longint));
end;

procedure allocMemRGB; //Getmem RGB
begin
   reallocmem(pic_oHWLr,pic_width*pic_height*sizeof(double)); //alloc mem for BMPs/HWLs R
   reallocmem(pic_oBMPr,pic_width*pic_height*sizeof(double));
   reallocmem(pic_qHWLr,pic_width*pic_height*sizeof(longint));

   reallocmem(pic_oHWLg,pic_width*pic_height*sizeof(double)); //alloc mem for BMPs/HWLs G
   reallocmem(pic_oBMPg,pic_width*pic_height*sizeof(double));
   reallocmem(pic_qHWLg,pic_width*pic_height*sizeof(longint));

   reallocmem(pic_oHWLb,pic_width*pic_height*sizeof(double)); //alloc mem for BMPs/HWLs B
   reallocmem(pic_oBMPb,pic_width*pic_height*sizeof(double));
   reallocmem(pic_qHWLb,pic_width*pic_height*sizeof(longint));
end;

procedure copyBitmap2DoubleGS(BMP : TBitmap; dest : PFarray); //Greyscale-Integer-BMP to FloatingPoint-BMP
 var x,y : cardinal;
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

procedure copyBitmap2DoubleRGB(BMP : TBitmap; r,g,b : PFarray); //RGB-Integer-BMP to FloatingPoint-BMP
 var x,y : cardinal;
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

procedure exitUsage;
begin
  writeln('Usage: waveletc [options] <infile> <outfile>');
  writeln('Options: -s=<num> : subdivision depth');
  writeln('         -y=<num> : y quantiser');
  writeln('         -u=<num> : uv quantiser');
  writeln('         -e=<num> : epsilon');
  halt(1);
end;

procedure setDefaults;
begin
  pic_quantbitsy := 8;
  pic_quantbitsu := 4;
  pic_quantbitsv := 4;
  pic_subdivisiondepth := $FFFFFFFF; // max
  pic_eps := 10;
  inFilename := '';
  outFilename := '';
end;

procedure parseCommandline;
var i : integer;
begin
  for i := 1 to ParamCount do
  begin
    if (ParamStr(i)[1]='-') or (ParamStr(i)[1]='/') then
    begin  // option
      case ParamStr(i)[2] of
       's': begin
           pic_subdivisiondepth := strtoint(copy(ParamStr(i),4,255));
         end;
       'e': begin
           pic_eps := strtoint(copy(ParamStr(i),4,255));
         end;
       'y': begin
           pic_quantbitsy := strtoint(copy(ParamStr(i),4,255));
         end;
       'u': begin
           pic_quantbitsu := strtoint(copy(ParamStr(i),4,255));;
           pic_quantbitsv := strtoint(copy(ParamStr(i),4,255));;
         end;
      end;
    end
    else
    begin  // filename angabe
      if (outFilename <> '') and (inFilename <> '') then
      begin
        writeln ('Too many files given');
        exitUsage;
      end;
      if (outFilename = '') and (inFilename<>'') then outFilename := ParamStr(i);
      if inFilename = '' then inFilename := ParamStr(i);
    end
  end;
  if outFilename = '' then
  begin
    writeln('Input/output filename not given');
    exitUsage;
  end;
end;

procedure printSettings;
begin
  writeln('Encoding using the following settings:');
  writeln('  Subdivision Depth: ',pic_subdivisiondepth);
  writeln('  Y-Quantizer      : ',pic_quantbitsy);
  writeln('  UV-Quantizer     : ',pic_quantbitsu);
  writeln('  Epsilon          : ',pic_eps);
end;

procedure initApp;
begin
  getmem(pic_quantfactor,18*sizeof(double));  //Quantizer-Scaling-Factors
  getmem(pic_quantfactorr,18*sizeof(double));
  getmem(pic_quantfactorg,18*sizeof(double));
  getmem(pic_quantfactorb,18*sizeof(double));

end;

procedure loadBitmap;
begin
  pic_bitmap:=TBitmap.Create;  //Create BMP
  pic_bitmap.HandleType:=bmDIB;
  pic_bitmap.PixelFormat:=pf32bit;
  pic_bitmap.LoadFromFile(inFilename); //to get dimensions and alloc bitmap-mem
  pic_bitmap.HandleType:=bmDIB;     //device independent
  pic_bitmap.PixelFormat:=pf32bit;  //32bits

  pic_width:=pic_bitmap.width;      //assign
  pic_height:=pic_bitmap.height;

  getbpp(pic_bitmap);

  if pic_bpp=HWL_GS then begin       //GREYSCALE
    allocmemGS;
    copybitmap2doubleGS(pic_bitmap,pic_oBMP);
  end else if pic_bpp=HWL_RGB then begin //RGB
    allocmemRGB;
    copybitmap2doubleRGB(pic_bitmap,pic_oBMPr,pic_oBMPg,pic_oBMPb);
  end;
end;

begin
  setDefaults;
  parseCommandline;
  initApp;
  loadBitmap;
  getMaxSubdivisionDepth;      //get Maximum Subdivison Depth

  printSettings;
  EncodeWavelet;

  if pic_bpp=HWL_GS then
    WriteHWL(outFilename,pic_qHWL,nil,nil,pic_width,pic_height,pic_bpp,pic_subdivisiondepth,pic_quantfactor,nil,nil,pic_quantbitsy,0,0)
  else if pic_bpp=HWL_RGB then
    WriteHWL(outFilename,pic_qHWLr,pic_qHWLg,pic_qHWLb,pic_width,pic_height,pic_bpp,pic_subdivisiondepth,pic_quantfactorr,pic_quantfactorg,pic_quantfactorb,pic_quantbitsy,pic_quantbitsu,pic_quantbitsv);
end.


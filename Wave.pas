{
  Haar Wavelet v.0.6b

  (C)2K2 by CARSTEN WAECHTER aka THE TOXIC AVENGER/AINC.
            (streaming by Armindo aka ADS)

  This Unit/Prog is Public Domain..
   Feel free to use, enhance or even learn about this code..
  If you like it, please drop a message to:
   toxie@ainc.de
  To get the newest version of Haar Wavelet surf to:
   http://ainc.de

  All future changes will be listed below..
}

unit Wave;

interface

uses Classes;

TYPE tbarray = array[0..100000000]of byte;
     tfarray = array[0..100000000]of double;
     tcarray = array[0..100000000]of cardinal;
     tiarray = array[0..100000000]of longint;
     twarray = array[0..100000000]of word;
     pbarray = ^tbarray;
     pfarray = ^tfarray;
     pcarray = ^tcarray;
     piarray = ^tiarray;
     pwarray = ^twarray;

//

     HWL_Header = packed record
                   ID           : array[0..2]of char; //'HWL'
                   width,height : word;     //X,Y
                   bpp          : byte;     //BitsPerPixel (HWL_GS,HWL_RGB)
                   depth        : byte;     //TransformationDepth
                   bitsr,bitsg,bitsb,datar,datag,datab : cardinal; //Bits/Data in Buffers
                   quantbitsy,quantbitsu,quantbitsv : byte;        //Quantizer Bits Used (1..8)
                  end;
                  //Following the Header:
                  //1.   ((depth+2)*sizeof(double)) Bytes of Data for QuantizerFactors (One for HWL_GS, Three (R,G,B) for HWL_RGB)
                  //2.a. (bits*2/8) Bytes of Data for BitTable (HWL_ISO_ZERO,HWL_RLE_ZERO,etc)
                  //  b. (data*quantbits/8) Bytes of Data for DataTable
                  //  (One (R) for HWL_GS, Three (R,G,B) for HWL_RGB)

//

CONST HWL_GS=8;       //Valid BPP
      HWL_RGB=24;

      HWL_ISO_ZERO=0; //Valid En/Decoder-Values
      HWL_RLE_ZERO=1;
      HWL_POS=2;
      HWL_NEG=3;

//

PROCEDURE HWL2Mem(var pic : pointer; var head : HWL_Header; name : string; allocmem : boolean);
//For all who just want to get a HWL-File loaded into memory =)
//Everything else in this Unit is then TOTALLY unnecessary to work with / know about.
//Depending on the BPP the resulting "pic"-pointer will be filled with
//Bytes (HWL_GS) or Cardinals (HWL_RGB), the necessary infos are delivered inside "head".
//"allocmem" lets the procedure get memory for "pic" (TRUE) or awaits a already allocated "pic" (FALSE)

//

PROCEDURE WaveletGS(pic : pfarray; wl : pfarray; dx,dy,xres,yres,depth : cardinal);   //BMP to HWL
PROCEDURE WaveletRGB(rf,gf,bf : pfarray; wlr,wlg,wlb : pfarray; dx,dy,xres,yres,depth : cardinal);
PROCEDURE DeWaveletGS(wl : pfarray; pic : pfarray; dx,dy,xres,yres,depth : longint); //Inverse
PROCEDURE DeWaveletRGB(wlr,wlg,wlb : pfarray; rf,gf,bf : pfarray; dx,dy,xres,yres,depth : cardinal);

PROCEDURE WaveletQuantGS(wl : pfarray; wli : piarray; xres,yres,depth,bits : cardinal; quantfactor : pfarray); //Quantizer
PROCEDURE WaveletQuantRGB(rf,gf,bf : pfarray; yi,ui,vi : piarray; xres,yres,depth,bitsy,bitsu,bitsv : cardinal; quantfactory,quantfactoru,quantfactorv : pfarray);
PROCEDURE DeWaveletQuantGS(wli : piarray; wl : pfarray; xres,yres,depth : longint; quantfactor : pfarray);    //Inverse
PROCEDURE DeWaveletQuantRGB(yi,ui,vi : piarray; rf,gf,bf : pfarray; xres,yres,depth : cardinal; quantfactory,quantfactoru,quantfactorv : pfarray);

FUNCTION  WaveletZeroOutGS(wl : pfarray; eps : double; bits : byte; xres,yres,depth : cardinal) : cardinal; //Kick Coefficients smaller "eps"
FUNCTION  WaveletCountZerosGS(wli : piarray; xres,yres,depth : cardinal) : cardinal; //Count overall Zeros in HWL

PROCEDURE ReadHWL(name : string; wlr,wlg,wlb : piarray; quantfactorr,quantfactorg,quantfactorb : pfarray); //Read HWL-File
PROCEDURE WriteHWL(name : string; wlr,wlg,wlb : piarray; xres,yres,bpp,depth : cardinal; quantfactorr,quantfactorg,quantfactorb : pfarray; quantbitsy,quantbitsu,quantbitsv : byte); //Write HWL-File

PROCEDURE ReadHWLFromStream(Stream: TStream; wlr, wlg, wlb: piarray; quantfactorr, quantfactorg, quantfactorb: pfarray); //Read HWL-File
PROCEDURE WriteHWLToStream(Stream: TStream; wlr, wlg, wlb: piarray; xres, yres, bpp, depth: cardinal; quantfactorr, quantfactorg, quantfactorb: pfarray; quantbitsy, quantbitsu, quantbitsv: byte);  //Write HWL-File

PROCEDURE ReadHeaderHWL(name : string; var head : HWL_Header); //Get HWL-File-Information

implementation


PROCEDURE HWL2Mem(var pic : pointer; var head : HWL_Header; name : string; allocmem : boolean);
 Var pic_qHWL,pic_qHWLr,pic_qHWLg,pic_qHWLb : piarray;
     pic_oHWL,pic_oHWLr,pic_oHWLg,pic_oHWLb : pfarray;
     pic_oBMP,pic_oBMPr,pic_oBMPg,pic_oBMPb : pfarray;
     pic_quantfactor,pic_quantfactorr,pic_quantfactorg,pic_quantfactorb : pfarray;

 PROCEDURE CopyDouble2ByteGS(src : PFarray; dest : PBarray); //GreyScale-FloatingPoint-BMP to Byte-BMP
  Var v : longint;
 BEGIN
    for v:=0 to head.height*head.width-1 do begin
     if (src^[v]>0.0) then begin
      if (src^[v]<255.0) then dest^[v]:=round(src^[v])
       else dest^[v]:=255;
     end else dest^[v]:=0;
    end;
 END;

 PROCEDURE CopyDouble2CardinalRGB(r,g,b : PFarray; dest : PCarray); //RGB-FloatingPoint-BMP to 32Bit-BMP
  Var v : longint;
      col : longint;
 BEGIN
    for v:=0 to head.height*head.width-1 do begin
     if b^[v]>0.0 then begin
      if b^[v]<255.0 then col:=round(b^[v])
       else col:=255;
     end else col:=0;

     if g^[v]>0.0 then begin
      if g^[v]<255.0 then col:=col or (round(g^[v])shl 8)
       else col:=col or $FF00;
     end;

     if r^[v]>0.0 then begin
      if r^[v]<255.0 then col:=col or (round(r^[v])shl 16)
       else col:=col or $FF0000;
     end;
     dest^[v]:=col;
    end;
 END;


BEGIN

  ReadHeaderHWL(name,head);

  if allocmem then begin
   if head.bpp=HWL_GS then reallocmem(pic,head.width*head.height)
    else if head.bpp=HWL_RGB then reallocmem(pic,head.width*head.height*4);
  end;

  if head.bpp=HWL_GS then begin
   getmem(pic_qHWL,head.width*head.height*sizeof(longint));
   getmem(pic_oHWL,head.width*head.height*sizeof(double));
   getmem(pic_oBMP,head.width*head.height*sizeof(double));
   getmem(pic_quantfactor,18*sizeof(double));

   ReadHWL(name,pic_qHWL,nil,nil,pic_quantfactor,nil,nil); //Load HWL

   DeWaveletQuantGS(pic_qHWL,pic_oHWL,head.width,head.height,head.depth,pic_quantfactor); //DeQuant

   DeWaveletGS(pic_oHWL,pic_oBMP,head.width,head.height,head.width,head.height,head.depth); //Restore BMP from HWL

   CopyDouble2ByteGS(pic_oBMP,pic);

   freemem(pic_quantfactor);
   freemem(pic_oBMP);
   freemem(pic_oHWL);
   freemem(pic_qHWL);
  end else if head.bpp=HWL_RGB then begin
   getmem(pic_qHWLr,head.width*head.height*sizeof(longint));
   getmem(pic_oHWLr,head.width*head.height*sizeof(double));
   getmem(pic_oBMPr,head.width*head.height*sizeof(double));
   getmem(pic_qHWLg,head.width*head.height*sizeof(longint));
   getmem(pic_oHWLg,head.width*head.height*sizeof(double));
   getmem(pic_oBMPg,head.width*head.height*sizeof(double));
   getmem(pic_qHWLb,head.width*head.height*sizeof(longint));
   getmem(pic_oHWLb,head.width*head.height*sizeof(double));
   getmem(pic_oBMPb,head.width*head.height*sizeof(double));
   getmem(pic_quantfactorr,18*sizeof(double));
   getmem(pic_quantfactorg,18*sizeof(double));
   getmem(pic_quantfactorb,18*sizeof(double));

   ReadHWL(name,pic_qHWLr,pic_qHWLg,pic_qHWLb,pic_quantfactorr,pic_quantfactorg,pic_quantfactorb); //Load HWL

   DeWaveletQuantRGB(pic_qHWLr,pic_qHWLg,pic_qHWLb,pic_oHWLr,pic_oHWLg,pic_oHWLb,head.width,head.height,head.depth,pic_quantfactorr,pic_quantfactorg,pic_quantfactorb); //DeQuant

   DeWaveletRGB(pic_oHWLr,pic_oHWLg,pic_oHWLb,pic_oBMPr,pic_oBMPg,pic_oBMPb,head.width,head.height,head.width,head.height,head.depth); //Restore BMP from HWL

   CopyDouble2CardinalRGB(pic_oBMPr,pic_oBMPg,pic_oBMPb,pic);

   freemem(pic_quantfactorb);
   freemem(pic_quantfactorg);
   freemem(pic_quantfactorr);
   freemem(pic_oBMPb);
   freemem(pic_oHWLb);
   freemem(pic_qHWLb);
   freemem(pic_oBMPg);
   freemem(pic_oHWLg);
   freemem(pic_qHWLg);
   freemem(pic_oBMPr);
   freemem(pic_oHWLr);
   freemem(pic_qHWLr);
  end;

END;

//

PROCEDURE WaveletGS(pic : pfarray; wl : pfarray; dx,dy,xres,yres,depth : cardinal);
 Var x,y : longint;
     tempx,tempy : pfarray;
     factor : double;
     offset : cardinal;
BEGIN
  factor:=(1.0/sqrt(2.0)); //Normalized Haar

  getmem(tempx,xres*yres*sizeof(double)); //Temporary Transformation-Storage
  getmem(tempy,xres*yres*sizeof(double));

  for y:=0 to dy-1 do begin               //Transform Rows
   offset:=y*xres;
   for x:=0 to (dx div 2)-1 do begin
    tempx^[x +offset]            := (pic^[x*2 +offset] + pic^[(x*2+1) +offset]) *factor; //LOW-PASS
    tempx^[(x+dx div 2) +offset] := (pic^[x*2 +offset] - pic^[(x*2+1) +offset]) *factor; //HIGH-PASS
   end;
  end;

  for x:=0 to dx-1 do                     //Transform Columns
   for y:=0 to (dy div 2)-1 do begin
    tempy^[x +y*xres]            := (tempx^[x +y*2*xres] + tempx^[x +(y*2+1)*xres]) *factor; //LOW-PASS
    tempy^[x +(y+dy div 2)*xres] := (tempx^[x +y*2*xres] - tempx^[x +(y*2+1)*xres]) *factor; //HIGH-PASS
   end;

  for y:=0 to dy-1 do
   move(tempy^[y*xres],wl^[y*xres],dx*sizeof(double)); //Copy to Wavelet

  freemem(tempx); //Free Temp-Storage
  freemem(tempy);

  if depth>0 then waveletgs(wl,wl,dx div 2,dy div 2,xres,yres,depth-1); //Repeat for SubDivisionDepth
END;

PROCEDURE WaveletRGB(rf,gf,bf : pfarray; wlr,wlg,wlb : pfarray; dx,dy,xres,yres,depth : cardinal);
 Var yf,uf,vf : pfarray;
     offset : longint;
BEGIN
  getmem(yf,xres*yres*sizeof(double));
  getmem(uf,xres*yres*sizeof(double));
  getmem(vf,xres*yres*sizeof(double));

  for offset:=0 to xres*yres-1 do begin //Convert the RGB-Coefficients to YUV
   yf^[offset]:=0.3*rf^[offset]+0.59*gf^[offset]+0.11*bf^[offset];
   uf^[offset]:=(bf^[offset]-yf^[offset])*0.493;
   vf^[offset]:=(rf^[offset]-yf^[offset])*0.877;
  end;

  WaveletGS(yf,wlr,dx,dy,xres,yres,depth);
  WaveletGS(uf,wlg,dx,dy,xres,yres,depth);
  WaveletGS(vf,wlb,dx,dy,xres,yres,depth);

  freemem(vf);
  freemem(uf);
  freemem(yf);
END;

PROCEDURE DeWaveletGS(wl : pfarray; pic : pfarray; dx,dy,xres,yres,depth : longint);
 Var x,y : longint;
     tempx,tempy : pfarray;
     offset,offsetm1,offsetp1 : longint;
     factor : double;
     dyoff,yhalf,yhalfoff,yhalfoff2,yhalfoff3 : longint;
BEGIN
  if depth>0 then dewaveletgs(wl,wl,dx div 2,dy div 2,xres,yres,depth-1); //Repeat for SubDivisionDepth

  factor:=(1.0/sqrt(2.0)); //Normalized Haar

  getmem(tempx,xres*yres*sizeof(double)); //Temporary Transformation-Storage
  getmem(tempy,xres*yres*sizeof(double));

  ////

  yhalf:=(dy div 2)-1;
  dyoff:=(dy div 2)*xres;
  yhalfoff:=yhalf*xres;
  yhalfoff2:=(yhalf+(dy div 2))*xres;
  yhalfoff3:=yhalfoff*2 +xres;

  if (yhalf>0) then begin //The first and last pixel has to be done "normal"
   for x:=0 to dx-1 do begin
    tempy^[x]     := (wl^[x] + wl^[x+dyoff])*factor; //LOW-PASS
    tempy^[x+xres]:= (wl^[x] - wl^[x+dyoff])*factor; //HIGH-PASS

    tempy^[x +yhalfoff*2]:= (wl^[x +yhalfoff] + wl^[x +yhalfoff2])*factor; //LOW-PASS
    tempy^[x +yhalfoff3] := (wl^[x +yhalfoff] - wl^[x +yhalfoff2])*factor; //HIGH-PASS
   end;
  end else begin
   for x:=0 to dx-1 do begin
    tempy^[x]     := (wl^[x] + wl^[x+dyoff])*factor; //LOW-PASS
    tempy^[x+xres]:= (wl^[x] - wl^[x+dyoff])*factor; //HIGH-PASS
   end;
  end;

  //

  dyoff:=(dy div 2)*xres;
  yhalf:=(dy div 2)-2;

  if (yhalf>=1) then begin                  //More then 2 pixels in the row?
   //
   if (dy>=4) then begin                    //DY must be greater then 4 to make the faked algo look good.. else it must be done "normal"
   //
    for x:=0 to dx-1 do begin               //Inverse Transform Colums (fake: if (high-pass coefficient=0.0) and (surrounding high-pass coefficients=0.0) then interpolate between surrounding low-pass coefficients)
     offsetm1:=0;
     offset:=xres;
     offsetp1:=xres*2;

     for y:=1 to yhalf do begin
      if (wl^[x +offset+dyoff]<>0.0) then begin //!UPDATED
       tempy^[x +offset*2]       := (wl^[x +offset] + wl^[x +offset+dyoff])*factor; //LOW-PASS
       tempy^[x +offset*2 +xres] := (wl^[x +offset] - wl^[x +offset+dyoff])*factor; //HIGH-PASS
      end else begin //!UPDATED
       if (wl^[x +offsetm1 +dyoff]=0.0) and (wl^[x +offsetp1]<>wl^[x +offset]) and ((y=yhalf) or (wl^[x +offsetp1]<>wl^[x +offsetp1 +xres])) then tempy^[x +offset*2]:=(wl^[x +offset]*0.8 + wl^[x +offsetm1]*0.2)*factor //LOW-PASS
        else tempy^[x +offset*2]:=wl^[x +offset]*factor;
       if (wl^[x +offsetp1 +dyoff]=0.0) and (wl^[x +offsetm1]<>wl^[x +offset]) and ((y=1) or (wl^[x +offsetm1]<>wl^[x +offsetm1 -xres])) then tempy^[x +offset*2 +xres]:=(wl^[x +offset]*0.8 + wl^[x +offsetp1]*0.2)*factor //HIGH-PASS
        else tempy^[x +offset*2 +xres]:=wl^[x +offset]*factor;
      end;

      inc(offsetm1,xres);
      inc(offset,xres);
      inc(offsetp1,xres);
     end;

    end;
   //
   end else //DY<4
   //
    for x:=0 to dx-1 do begin
     offset:=xres;
     for y:=1 to yhalf do begin
      tempy^[x +offset*2]      := (wl^[x +offset] + wl^[x +offset +dyoff])*factor; //LOW-PASS
      tempy^[x +offset*2+xres] := (wl^[x +offset] - wl^[x +offset +dyoff])*factor; //HIGH-PASS

      inc(offset,xres);
     end;
    end;
   //
  end;

  ////

  offset:=0;
  yhalf:=(dx div 2)-1;
  yhalfoff:=(yhalf+dx div 2);
  yhalfoff2:=yhalf*2+1;

  if (yhalf>0) then begin
   for y:=0 to dy-1 do begin //The first and last pixel has to be done "normal"
    tempx^[offset]   :=(tempy^[offset] + tempy^[yhalf+1 +offset])*factor; //LOW-PASS
    tempx^[offset+1] :=(tempy^[offset] - tempy^[yhalf+1 +offset])*factor; //HIGH-PASS

    tempx^[yhalf*2 +offset]   :=(tempy^[yhalf +offset] + tempy^[yhalfoff +offset])*factor; //LOW-PASS
    tempx^[yhalfoff2 +offset] :=(tempy^[yhalf +offset] - tempy^[yhalfoff +offset])*factor; //HIGH-PASS

    inc(offset,xres);
   end;
  end else begin
   for y:=0 to dy-1 do begin //The first and last pixel has to be done "normal"
    tempx^[offset]   :=(tempy^[offset] + tempy^[yhalf+1 +offset])*factor; //LOW-PASS
    tempx^[offset+1] :=(tempy^[offset] - tempy^[yhalf+1 +offset])*factor; //HIGH-PASS

    inc(offset,xres);
   end;
  end;

  //

  dyoff:=(dx div 2);
  yhalf:=(dx div 2)-2;

  if (yhalf>=1) then begin

   if (dx>=4) then begin

    offset:=0;
    for y:=0 to dy-1 do begin               //Inverse Transform Rows (fake: if (high-pass coefficient=0.0) and (surrounding high-pass coefficients=0.0) then interpolate between surrounding low-pass coefficients)
     for x:=1 to yhalf do
      if (tempy^[x +dyoff +offset]<>0.0) then begin //!UPDATED
       tempx^[x*2 +offset]   :=(tempy^[x +offset] + tempy^[x +dyoff +offset])*factor; //LOW-PASS
       tempx^[x*2+1 +offset] :=(tempy^[x +offset] - tempy^[x +dyoff +offset])*factor; //HIGH-PASS
      end else begin //!UPDATED
       if (tempy^[x-1+dyoff +offset]=0.0) and (tempy^[x+1 +offset]<>tempy^[x +offset]) and ((x=yhalf) or (tempy^[x+1 +offset]<>tempy^[x+2 +offset])) then tempx^[x*2 +offset]:=(tempy^[x +offset]*0.8 + tempy^[x-1 +offset]*0.2)*factor //LOW-PASS
        else tempx^[x*2 +offset]:=tempy^[x +offset]*factor;
       if (tempy^[x+1+dyoff +offset]=0.0) and (tempy^[x-1 +offset]<>tempy^[x +offset]) and ((x=1) or (tempy^[x-1 +offset]<>tempy^[x-2 +offset])) then tempx^[x*2+1 +offset]:=(tempy^[x +offset]*0.8 + tempy^[x+1 +offset]*0.2)*factor //HIGH-PASS
        else tempx^[x*2+1 +offset]:=tempy^[x +offset]*factor;
      end;
     inc(offset,xres);
    end;

   end else begin //DX<4

    offset:=0;
    for y:=0 to dy-1 do begin               //Inverse Transform Rows (fake: if (high-pass coefficient=0.0) and (surrounding high-pass coefficients=0.0) then interpolate between surrounding low-pass coefficients)
     for x:=1 to yhalf do begin
      tempx^[x*2 +offset]   := (tempy^[x +offset] + tempy^[x +dyoff +offset])*factor; //LOW-PASS
      tempx^[x*2+1 +offset] := (tempy^[x +offset] - tempy^[x +dyoff +offset])*factor; //HIGH-PASS
     end;
     inc(offset,xres);
    end;
    
   end;

  end;

  ////

  for y:=0 to dy-1 do
   move(tempx^[y*xres],pic^[y*xres],dx*sizeof(double)); //Copy to Pic

  freemem(tempx); //Free Temp-Storage
  freemem(tempy);
END;

PROCEDURE DeWaveletRGB(wlr,wlg,wlb : pfarray; rf,gf,bf : pfarray; dx,dy,xres,yres,depth : cardinal);
 Var yf,uf,vf : pfarray;
     offset : longint;
BEGIN
  getmem(yf,xres*yres*sizeof(double));
  getmem(uf,xres*yres*sizeof(double));
  getmem(vf,xres*yres*sizeof(double));

  DeWaveletGS(wlr,yf,dx,dy,xres,yres,depth);
  DeWaveletGS(wlg,uf,dx,dy,xres,yres,depth);
  DeWaveletGS(wlb,vf,dx,dy,xres,yres,depth);

  for offset:=0 to xres*yres-1 do begin //Convert the RGB-Coefficients to YUV
   rf^[offset]:=yf^[offset]+vf^[offset]*1.140251;
   bf^[offset]:=yf^[offset]+uf^[offset]*2.028398;
   gf^[offset]:=(yf^[offset]-rf^[offset]*0.3-bf^[offset]*0.11)*1.694915;
  end;

  freemem(vf);
  freemem(uf);
  freemem(yf);
END;

PROCEDURE WaveletQuantGS(wl : pfarray; wli : piarray; xres,yres,depth,bits : cardinal; quantfactor : pfarray);
 Var startx,d,x,y,dx,dy,offset : longint;
     min,max,factor : double;
BEGIN
 //HIGH-PASS
 for d:=0 to depth do begin //Repeat for all SubDivisions
  min:=100000000.0;
  max:=-100000000.0;

  if d>0 then dy:=(yres shr d) -1 //Shifting Factors (to "navigate" within the Wavelet-HighPass)
   else dy:=yres-1;
  if d>0 then dx:=(xres shr d) -1
   else dx:=xres-1;

  for y:=0 to dy do begin //Get Minimum/Maximum Coefficient from current Subdivision-High-Pass
   offset:=y*xres;
   if (y>=(yres shr (d+1))) then startx:=0 //Only look inside the High-Pass
    else startx:=(xres shr (d+1));
   for x:=startx to dx do begin
    if wl^[x+offset]<min then min:=wl^[x+offset]; //Smaller/Bigger ??!
    if wl^[x+offset]>max then max:=wl^[x+offset];
   end;
  end;

  if (min<>0.0) or (max<>0.0) then //Calc Quantizer Factor
   if abs(min)>abs(max) then factor:=(1 shl bits -1)/abs(min)
   else factor:=(1 shl bits -1)/abs(max)
  else factor:=0.0;

  for y:=0 to dy do begin //Quantize (Linear Scale) the Coefficients
   offset:=y*xres;
   if (y>=(yres shr (d+1))) then startx:=0 //Only quantize inside the High-Pass
    else startx:=(xres shr (d+1));
   for x:=startx to dx do
    wli^[x+offset]:=round(wl^[x+offset]*factor);
  end;

  quantfactor^[d]:=factor; //Save current Quantize-Factor
 end;

  //LOW-PASS
  min:=100000000.0;
  max:=-100000000.0;

  for y:=0 to (yres shr (depth+1))-1 do begin //Get Minimum/Maximum Value from remaining Subdivision-Low-Pass
   offset:=y*xres;
   for x:=0 to (xres shr (depth+1))-1 do begin
    if wl^[x+offset]<min then min:=wl^[x+offset];
    if wl^[x+offset]>max then max:=wl^[x+offset];
   end;
  end;

  if (min<>0.0) or (max<>0.0) then begin //Calc Quantizer-factor
   if abs(min)>abs(max) then factor:=(1 shl bits -1)/abs(min)
    else factor:=(1 shl bits -1)/abs(max);
  end else factor:=0.0;

//  application.messagebox(@(floattostr(min)+'/'+floattostr(max)+'/'+floattostr(factor)+#0)[1],'min/max/factor',0); //TESTING PURPOSE

  for y:=0 to (yres shr (depth+1))-1 do begin //Quantize (Scale) Values
   offset:=y*xres;
   for x:=0 to (xres shr (depth+1))-1 do
    wli^[x+offset]:=round(wl^[x+offset]*factor);
  end;

  quantfactor^[depth+1]:=factor; //Save Factor

END;

PROCEDURE WaveletQuantRGB(rf,gf,bf : pfarray; yi,ui,vi : piarray; xres,yres,depth,bitsy,bitsu,bitsv : cardinal; quantfactory,quantfactoru,quantfactorv : pfarray);
BEGIN
  WaveletQuantGS(rf,yi,xres,yres,depth,bitsy,quantfactory);
  WaveletQuantGS(gf,ui,xres,yres,depth,bitsu,quantfactoru);
  WaveletQuantGS(bf,vi,xres,yres,depth,bitsv,quantfactorv);
END;

PROCEDURE DeWaveletQuantGS(wli : piarray; wl : pfarray; xres,yres,depth : longint; quantfactor : pfarray);
 Var dx,dy,x,y,offset,d,startx,yrsd,xrsd : longint;
     factor : double;
BEGIN
 //HIGH-PASS
 for d:=0 to depth do begin        //Repeat for all SubDivisions
  if d>0 then dy:=(yres shr d) -1  //Shifting Factors (to "navigate" within the Wavelet-HighPass)
   else dy:=yres-1;
  if d>0 then dx:=(xres shr d) -1
   else dx:=xres-1;

  if quantfactor^[d]<>0.0 then factor:=1.0/quantfactor^[d] //Invert QuantFactor
   else factor:=0.0;

  yrsd:=yres shr (d+1);
  xrsd:=xres shr (d+1);
  offset:=0;

  for y:=0 to dy do begin
   if (y>=yrsd) then startx:=0 //Only dequantize inside the High-Pass
    else startx:=xrsd;
   for x:=startx to dx do
    wl^[x+offset]:=wli^[x+offset]*factor;  //dequant
   inc(offset,xres);
  end;
 end;

  //LOW-PASS
  if quantfactor^[depth+1]<>0.0 then factor:=1.0/quantfactor^[depth+1] //Invert QuantFactor
   else factor:=0.0;

  yrsd:=(yres shr (depth+1))-1;
  xrsd:=(xres shr (depth+1))-1;

  offset:=0;
  for y:=0 to yrsd do begin
   for x:=0 to xrsd do
    wl^[x+offset]:=wli^[x+offset]*factor; //Dequant LowPass
   inc(offset,xres); 
  end;
END;

PROCEDURE DeWaveletQuantRGB(yi,ui,vi : piarray; rf,gf,bf : pfarray; xres,yres,depth : cardinal; quantfactory,quantfactoru,quantfactorv : pfarray);
BEGIN
  DeWaveletQuantGS(yi,rf,xres,yres,depth,quantfactory);
  DeWaveletQuantGS(ui,gf,xres,yres,depth,quantfactoru);
  DeWaveletQuantGS(vi,bf,xres,yres,depth,quantfactorv);
END;

FUNCTION  WaveletZeroOutGS(wl : pfarray; eps : double; bits : byte; xres,yres,depth : cardinal) : cardinal;
 Var x,y : longint;
     c,offset,startx : cardinal;
BEGIN
  c:=0; //Numbers of Coefficients kicked

  for y:=0 to yres-1 do begin
   offset:=y*xres;
   if (y>=(yres shr (depth+1))) then startx:=0  //Only High-Pass
    else startx:=(xres shr (depth+1));
   for x:=startx to xres-1 do                   //Search for all Coefficients<>0.0 and <=eps
    if (abs(wl^[x+offset])<=eps) and (wl^[x+offset]<>0.0) then begin wl^[x+offset]:=0.0; inc(c); end;
  end;

  WaveletZeroOutGS:=c;
END;

FUNCTION  WaveletCountZerosGS(wli : piarray; xres,yres,depth : cardinal) : cardinal;
 Var v : longint;
     c : cardinal;
BEGIN
  c:=0; //Count all Zeros in Wavelet

  for v:=0 to xres*yres-1 do
   if (wli^[v]=0) then inc(c);

  WaveletCountZerosGS:=c;
END;

PROCEDURE DeWaveletPackGS(wli : piarray; bitbuffer : pbarray; bitindex : cardinal; databuffer : pbarray; dataindex : cardinal; xres,yres,depth,bits : cardinal);
 Var v : cardinal;
     bitcounter,datacounter : cardinal;
BEGIN
  v:=0;           //Index for the Wavelet
  bitcounter:=0;  //Index for the 2Bit-Table (HWL_ISO_ZERO,HWL_RLE_ZERO,HWL_POS,HWL_NEG)
  datacounter:=0; //Index for the 8Bit-DataTable

  while (bitcounter<=bitindex) and (datacounter<=dataindex) and (v<xres*yres) do begin
   if (bitbuffer^[bitcounter]=HWL_ISO_ZERO) then wli^[v]:=0            //Single Zero found
   else if bitbuffer^[bitcounter]=HWL_RLE_ZERO then begin              //(databuffer^[datacounter]+1) Zeros found
     inc(bitcounter);                                                  //move on to read upper 2Bits of amount
     fillchar(wli^[v],(databuffer^[datacounter]+(bitbuffer^[bitcounter] shl bits)+1)*sizeof(longint),0);
     inc(v,databuffer^[datacounter]+(bitbuffer^[bitcounter] shl bits));
     inc(datacounter);
    end else if bitbuffer^[bitcounter]=HWL_POS then begin              //Positive Significant Coefficient found
     wli^[v]:=databuffer^[datacounter];
     inc(datacounter);
    end else begin                                                     //Negative Significant Coefficient found
     wli^[v]:=-databuffer^[datacounter];
     inc(datacounter);
    end;
   inc(bitcounter); //move on =)
   inc(v);
  end;
END;

PROCEDURE ReadHeaderHWL(name : string; var head : HWL_Header);
 Var f : file;
BEGIN
  Assignfile(f,name);
  filemode:=0;
  Reset(f,1);
  blockread(f,head,sizeof(head));
  Close(f);
END;


PROCEDURE ReadHWLFromStream(Stream: TStream; wlr, wlg, wlb: piarray; quantfactorr, quantfactorg, quantfactorb: pfarray);
 Var
  head              : HWL_Header;
  bitbuffer, pbitbuffer : pbarray;
  databuffer, pdatabuffer : pbarray;
  bitindex, dataindex, pbits, pdata, data, data2 : cardinal;
  v                 : longint;
BEGIN
  Stream.ReadBuffer(head, sizeof(head));

  //if head.ID<>'HWL' then ..

  if head.bpp = HWL_GS then
    begin                               //GREYSCALE
      Stream.ReadBuffer(quantfactorr^, (head.depth + 2) * sizeof(double)); //Read Quantizer-Factors

      bitindex := head.bitsr;           //2Bit-Packets in BitTable
      dataindex := head.datar;          //QuantBit-Packets in DataTable

      getmem(bitbuffer, bitindex);      //Alloc Mem for Byte-Storage of the Tables
      getmem(databuffer, dataindex);

      //UnPack the BitBuffer
      pbits := bitindex div 4;

      if (bitindex mod 4 = 0) then
        begin
          getmem(pbitbuffer, pbits);    //Temp-Storage for packed BitTable
          Stream.ReadBuffer(pbitbuffer^, pbits);
        end
      else
        begin
          getmem(pbitbuffer, pbits + 1);
          Stream.ReadBuffer(pbitbuffer^, pbits + 1);
        end;

      for v := 0 to pbits - 1 do
        begin                           //4 2Bit-Pakets match one Byte =)
          bitbuffer^[v * 4] := pbitbuffer^[v] and 3;
          bitbuffer^[v * 4 + 1] := (pbitbuffer^[v] and (3 shl 2)) shr 2;
          bitbuffer^[v * 4 + 2] := (pbitbuffer^[v] and (3 shl 4)) shr 4;
          bitbuffer^[v * 4 + 3] := pbitbuffer^[v] shr 6;
        end;

      if (bitindex mod 4 > 0) then
        begin
          bitbuffer^[pbits * 4] := pbitbuffer^[pbits] and 3;
          if (bitindex mod 4 > 1) then
            bitbuffer^[pbits * 4 + 1] := (pbitbuffer^[pbits] and (3 shl 2)) shr 2;
          if (bitindex mod 4 > 2) then
            bitbuffer^[pbits * 4 + 2] := (pbitbuffer^[pbits] and (3 shl 4)) shr 4;
        end;

      freemem(pbitbuffer);
      //End UnPack

      //Unpack the DataBuffer
      if (head.quantbitsy <> 8) then
        begin                           //Can we copy directly into databuffer?
          if ((dataindex * head.quantbitsy) mod 8 = 0) then
            pdata := (dataindex * head.quantbitsy) div 8
          else
            pdata := (dataindex * head.quantbitsy) div 8 + 1;

          getmem(pdatabuffer, pdata);   //Temp-Storage for packed DataTable
          Stream.ReadBuffer(pdatabuffer^, pdata);

          pbits := 0;
          for v := 0 to dataindex - 1 do
            begin                       //ReStore Bytes out of the "packed" BitStream
              if (pbits mod 8 = 0) then
                begin
                  data := pdatabuffer^[pbits div 8] and ((1 shl head.quantbitsy) - 1);
                end
              else
                begin
                  data := (cardinal(pdatabuffer^[pbits div 8]) shr (pbits mod 8)) and ((1 shl head.quantbitsy) - 1);
                  if ((pbits + head.quantbitsy) div 8 > pbits div 8) then
                    begin
                      data2 := cardinal(pdatabuffer^[(pbits div 8) + 1]) and ((1 shl ((pbits + head.quantbitsy) mod 8)) - 1);
                      data := data or (data2 shl (8 - (pbits mod 8)));
                    end;
                end;
              databuffer^[v] := data;
              inc(pbits, head.quantbitsy);
            end;

          freemem(pdatabuffer);
        end
      else
        Stream.ReadBuffer(databuffer^, dataindex);
      //End Unpack

      DeWaveletPackGS(wlr, bitbuffer, bitindex, databuffer, dataindex, head.width, head.height, head.depth, head.quantbitsy); //Restore Wavelet from the Byte-Tables

      freemem(bitbuffer);
      freemem(databuffer);
    end
  else if head.bpp = HWL_RGB then
    begin                               //RGB
      Stream.ReadBuffer(quantfactorr^, (head.depth + 2) * sizeof(double)); //Read Quantizer-Factors
      Stream.ReadBuffer(quantfactorg^, (head.depth + 2) * sizeof(double));
      Stream.ReadBuffer(quantfactorb^, (head.depth + 2) * sizeof(double));

      //RED

      bitindex := head.bitsr;           //2Bit-Packets in BitTable (Red)
      dataindex := head.datar;          //QuantBit-Packets in DataTable

      getmem(bitbuffer, bitindex);      //Alloc Mem for Byte-Storage of the Tables
      getmem(databuffer, dataindex);

      //UnPack the BitBuffer
      pbits := bitindex div 4;

      if (bitindex mod 4 = 0) then
        begin
          getmem(pbitbuffer, pbits);    //Temp-Storage for packed BitTable
          Stream.ReadBuffer(pbitbuffer^, pbits);
        end
      else
        begin
          getmem(pbitbuffer, pbits + 1);
          Stream.ReadBuffer(pbitbuffer^, pbits + 1);
        end;

      for v := 0 to pbits - 1 do
        begin                           //4 2Bit-Pakets match one Byte =)
          bitbuffer^[v * 4] := pbitbuffer^[v] and 3;
          bitbuffer^[v * 4 + 1] := (pbitbuffer^[v] and (3 shl 2)) shr 2;
          bitbuffer^[v * 4 + 2] := (pbitbuffer^[v] and (3 shl 4)) shr 4;
          bitbuffer^[v * 4 + 3] := pbitbuffer^[v] shr 6;
        end;

      if (bitindex mod 4 > 0) then
        begin
          bitbuffer^[pbits * 4] := pbitbuffer^[pbits] and 3;
          if (bitindex mod 4 > 1) then
            bitbuffer^[pbits * 4 + 1] := (pbitbuffer^[pbits] and (3 shl 2)) shr 2;
          if (bitindex mod 4 > 2) then
            bitbuffer^[pbits * 4 + 2] := (pbitbuffer^[pbits] and (3 shl 4)) shr 4;
        end;

      freemem(pbitbuffer);
      //End UnPack

      //Unpack the DataBuffer
      if (head.quantbitsy <> 8) then
        begin                           //Can we copy directly into databuffer?
          if ((dataindex * head.quantbitsy) mod 8 = 0) then
            pdata := (dataindex * head.quantbitsy) div 8
          else
            pdata := (dataindex * head.quantbitsy) div 8 + 1;

          getmem(pdatabuffer, pdata);   //Temp-Storage for packed DataTable
          Stream.ReadBuffer(pdatabuffer^, pdata);

          pbits := 0;
          for v := 0 to dataindex - 1 do
            begin                       //ReStore Bytes out of the "packed" BitStream
              if (pbits mod 8 = 0) then
                begin
                  data := pdatabuffer^[pbits div 8] and ((1 shl head.quantbitsy) - 1);
                end
              else
                begin
                  data := (cardinal(pdatabuffer^[pbits div 8]) shr (pbits mod 8)) and ((1 shl head.quantbitsy) - 1);
                  if ((pbits + head.quantbitsy) div 8 > pbits div 8) then
                    begin
                      data2 := cardinal(pdatabuffer^[(pbits div 8) + 1]) and ((1 shl ((pbits + head.quantbitsy) mod 8)) - 1);
                      data := data or (data2 shl (8 - (pbits mod 8)));
                    end;
                end;
              databuffer^[v] := data;
              inc(pbits, head.quantbitsy);
            end;

          freemem(pdatabuffer);
        end
      else
        Stream.ReadBuffer(databuffer^, dataindex);
      //End Unpack

      DeWaveletPackGS(wlr, bitbuffer, bitindex, databuffer, dataindex, head.width, head.height, head.depth, head.quantbitsy);

      freemem(bitbuffer);
      freemem(databuffer);

      //GREEN

      bitindex := head.bitsg;           //2Bit-Packets in BitTable (Green)
      dataindex := head.datag;          //QuantBit-Packets in DataTable

      getmem(bitbuffer, bitindex);      //Alloc Mem for Byte-Storage of the Tables
      getmem(databuffer, dataindex);

      //UnPack the BitBuffer
      pbits := bitindex div 4;

      if (bitindex mod 4 = 0) then
        begin
          getmem(pbitbuffer, pbits);    //Temp-Storage for packed BitTable
          Stream.ReadBuffer(pbitbuffer^, pbits);
        end
      else
        begin
          getmem(pbitbuffer, pbits + 1);
          Stream.ReadBuffer(pbitbuffer^, pbits + 1);
        end;

      for v := 0 to pbits - 1 do
        begin                           //4 2Bit-Pakets match one Byte =)
          bitbuffer^[v * 4] := pbitbuffer^[v] and 3;
          bitbuffer^[v * 4 + 1] := (pbitbuffer^[v] and (3 shl 2)) shr 2;
          bitbuffer^[v * 4 + 2] := (pbitbuffer^[v] and (3 shl 4)) shr 4;
          bitbuffer^[v * 4 + 3] := pbitbuffer^[v] shr 6;
        end;

      if (bitindex mod 4 > 0) then
        begin
          bitbuffer^[pbits * 4] := pbitbuffer^[pbits] and 3;
          if (bitindex mod 4 > 1) then
            bitbuffer^[pbits * 4 + 1] := (pbitbuffer^[pbits] and (3 shl 2)) shr 2;
          if (bitindex mod 4 > 2) then
            bitbuffer^[pbits * 4 + 2] := (pbitbuffer^[pbits] and (3 shl 4)) shr 4;
        end;

      freemem(pbitbuffer);
      //End UnPack

      //Unpack the DataBuffer
      if (head.quantbitsu <> 8) then
        begin                           //Can we copy directly into databuffer?
          if ((dataindex * head.quantbitsu) mod 8 = 0) then
            pdata := (dataindex * head.quantbitsu) div 8
          else
            pdata := (dataindex * head.quantbitsu) div 8 + 1;

          getmem(pdatabuffer, pdata);   //Temp-Storage for packed DataTable
          Stream.ReadBuffer(pdatabuffer^, pdata);

          pbits := 0;
          for v := 0 to dataindex - 1 do
            begin                       //ReStore Bytes out of the "packed" BitStream
              if (pbits mod 8 = 0) then
                begin
                  data := pdatabuffer^[pbits div 8] and ((1 shl head.quantbitsu) - 1);
                end
              else
                begin
                  data := (cardinal(pdatabuffer^[pbits div 8]) shr (pbits mod 8)) and ((1 shl head.quantbitsu) - 1);
                  if ((pbits + head.quantbitsu) div 8 > pbits div 8) then
                    begin
                      data2 := cardinal(pdatabuffer^[(pbits div 8) + 1]) and ((1 shl ((pbits + head.quantbitsu) mod 8)) - 1);
                      data := data or (data2 shl (8 - (pbits mod 8)));
                    end;
                end;
              databuffer^[v] := data;
              inc(pbits, head.quantbitsu);
            end;

          freemem(pdatabuffer);
        end
      else
        Stream.ReadBuffer(databuffer^, dataindex);
      //End Unpack

      DeWaveletPackGS(wlg, bitbuffer, bitindex, databuffer, dataindex, head.width, head.height, head.depth, head.quantbitsu);

      freemem(bitbuffer);
      freemem(databuffer);

      //BLUE

      bitindex := head.bitsb;           //2Bit-Packets in BitTable (Blue)
      dataindex := head.datab;          //QuantBit-Packets in DataTable

      getmem(bitbuffer, bitindex);      //Alloc Mem for Byte-Storage of the Tables
      getmem(databuffer, dataindex);

      //UnPack the BitBuffer
      pbits := bitindex div 4;

      if (bitindex mod 4 = 0) then
        begin
          getmem(pbitbuffer, pbits);    //Temp-Storage for packed BitTable
          Stream.ReadBuffer(pbitbuffer^, pbits);
        end
      else
        begin
          getmem(pbitbuffer, pbits + 1);
          Stream.ReadBuffer(pbitbuffer^, pbits + 1);
        end;

      for v := 0 to pbits - 1 do
        begin                           //4 2Bit-Pakets match one Byte =)
          bitbuffer^[v * 4] := pbitbuffer^[v] and 3;
          bitbuffer^[v * 4 + 1] := (pbitbuffer^[v] and (3 shl 2)) shr 2;
          bitbuffer^[v * 4 + 2] := (pbitbuffer^[v] and (3 shl 4)) shr 4;
          bitbuffer^[v * 4 + 3] := pbitbuffer^[v] shr 6;
        end;

      if (bitindex mod 4 > 0) then
        begin
          bitbuffer^[pbits * 4] := pbitbuffer^[pbits] and 3;
          if (bitindex mod 4 > 1) then
            bitbuffer^[pbits * 4 + 1] := (pbitbuffer^[pbits] and (3 shl 2)) shr 2;
          if (bitindex mod 4 > 2) then
            bitbuffer^[pbits * 4 + 2] := (pbitbuffer^[pbits] and (3 shl 4)) shr 4;
        end;

      freemem(pbitbuffer);
      //End UnPack

      //Unpack the DataBuffer
      if (head.quantbitsv <> 8) then
        begin                           //Can we copy directly into databuffer?
          if ((dataindex * head.quantbitsv) mod 8 = 0) then
            pdata := (dataindex * head.quantbitsv) div 8
          else
            pdata := (dataindex * head.quantbitsv) div 8 + 1;

          getmem(pdatabuffer, pdata);   //Temp-Storage for packed DataTable
          Stream.ReadBuffer(pdatabuffer^, pdata);

          pbits := 0;
          for v := 0 to dataindex - 1 do
            begin                       //ReStore Bytes out of the "packed" BitStream
              if (pbits mod 8 = 0) then
                begin
                  data := pdatabuffer^[pbits div 8] and ((1 shl head.quantbitsv) - 1);
                end
              else
                begin
                  data := (cardinal(pdatabuffer^[pbits div 8]) shr (pbits mod 8)) and ((1 shl head.quantbitsv) - 1);
                  if ((pbits + head.quantbitsv) div 8 > pbits div 8) then
                    begin
                      data2 := cardinal(pdatabuffer^[(pbits div 8) + 1]) and ((1 shl ((pbits + head.quantbitsv) mod 8)) - 1);
                      data := data or (data2 shl (8 - (pbits mod 8)));
                    end;
                end;
              databuffer^[v] := data;
              inc(pbits, head.quantbitsv);
            end;

          freemem(pdatabuffer);
        end
      else
        Stream.ReadBuffer(databuffer^, dataindex);
      //End Unpack

      DeWaveletPackGS(wlb, bitbuffer, bitindex, databuffer, dataindex, head.width, head.height, head.depth, head.quantbitsv);

      freemem(bitbuffer);
      freemem(databuffer);
    end;
END;


PROCEDURE ReadHWL(name : string; wlr,wlg,wlb : piarray; quantfactorr,quantfactorg,quantfactorb : pfarray);
 Var f : file;
     head : HWL_Header;
     bitbuffer,pbitbuffer : pbarray;
     databuffer,pdatabuffer : pbarray;
     bitindex,dataindex,pbits,pdata,data,data2 : cardinal;
     v : longint;
BEGIN
  Assignfile(f,name);
  filemode:=0;
  Reset(f,1);

  blockread(f,head,sizeof(head));

  //if head.ID<>'HWL' then ..

  if head.bpp=HWL_GS then begin //GREYSCALE
   blockread(f,quantfactorr^,(head.depth+2)*sizeof(double)); //Read Quantizer-Factors

   bitindex:=head.bitsr;  //2Bit-Packets in BitTable
   dataindex:=head.datar; //QuantBit-Packets in DataTable

   getmem(bitbuffer,bitindex);   //Alloc Mem for Byte-Storage of the Tables
   getmem(databuffer,dataindex);

   //UnPack the BitBuffer
   pbits:=bitindex div 4;

   if (bitindex mod 4=0) then begin
    getmem(pbitbuffer,pbits);    //Temp-Storage for packed BitTable
    blockread(f,pbitbuffer^,pbits);
   end else begin
    getmem(pbitbuffer,pbits+1);
    blockread(f,pbitbuffer^,pbits+1);
   end;

   for v:=0 to pbits-1 do begin //4 2Bit-Pakets match one Byte =)
    bitbuffer^[v*4]:=pbitbuffer^[v] and 3;
    bitbuffer^[v*4+1]:=(pbitbuffer^[v] and (3 shl 2)) shr 2;
    bitbuffer^[v*4+2]:=(pbitbuffer^[v] and (3 shl 4)) shr 4;
    bitbuffer^[v*4+3]:=pbitbuffer^[v] shr 6;
   end;

   if (bitindex mod 4>0) then begin
    bitbuffer^[pbits*4]:=pbitbuffer^[pbits] and 3;
    if (bitindex mod 4>1) then bitbuffer^[pbits*4+1]:=(pbitbuffer^[pbits] and (3 shl 2)) shr 2;
    if (bitindex mod 4>2) then bitbuffer^[pbits*4+2]:=(pbitbuffer^[pbits] and (3 shl 4)) shr 4;
   end;

   freemem(pbitbuffer);
   //End UnPack

   //Unpack the DataBuffer
   if (head.quantbitsy<>8) then begin //Can we copy directly into databuffer?
    if ((dataindex*head.quantbitsy) mod 8=0) then pdata:=(dataindex*head.quantbitsy) div 8
     else pdata:=(dataindex*head.quantbitsy) div 8 +1;

    getmem(pdatabuffer,pdata);       //Temp-Storage for packed DataTable
    blockread(f,pdatabuffer^,pdata);

    pbits:=0;
    for v:=0 to dataindex-1 do begin //ReStore Bytes out of the "packed" BitStream
     if (pbits mod 8=0) then begin
      data:=pdatabuffer^[pbits div 8] and ((1 shl head.quantbitsy)-1);
     end else begin
      data:=(cardinal(pdatabuffer^[pbits div 8]) shr (pbits mod 8)) and ((1 shl head.quantbitsy)-1);
      if ((pbits+head.quantbitsy) div 8>pbits div 8) then begin
       data2:=cardinal(pdatabuffer^[(pbits div 8)+1]) and ((1 shl ((pbits+head.quantbitsy) mod 8))-1);
       data:=data or (data2 shl (8-(pbits mod 8)));
      end;
     end;
     databuffer^[v]:=data;
     inc(pbits,head.quantbitsy);
    end;

    freemem(pdatabuffer);
   end else blockread(f,databuffer^,dataindex);
   //End Unpack

   DeWaveletPackGS(wlr,bitbuffer,bitindex,databuffer,dataindex,head.width,head.height,head.depth,head.quantbitsy); //Restore Wavelet from the Byte-Tables

   freemem(bitbuffer);
   freemem(databuffer);
  end else if head.bpp=HWL_RGB then begin //RGB
   blockread(f,quantfactorr^,(head.depth+2)*sizeof(double)); //Read Quantizer-Factors
   blockread(f,quantfactorg^,(head.depth+2)*sizeof(double));
   blockread(f,quantfactorb^,(head.depth+2)*sizeof(double));

   //RED

   bitindex:=head.bitsr;  //2Bit-Packets in BitTable (Red)
   dataindex:=head.datar; //QuantBit-Packets in DataTable

   getmem(bitbuffer,bitindex);  //Alloc Mem for Byte-Storage of the Tables
   getmem(databuffer,dataindex);

   //UnPack the BitBuffer
   pbits:=bitindex div 4;

   if (bitindex mod 4=0) then begin
    getmem(pbitbuffer,pbits);    //Temp-Storage for packed BitTable
    blockread(f,pbitbuffer^,pbits);
   end else begin
    getmem(pbitbuffer,pbits+1);
    blockread(f,pbitbuffer^,pbits+1);
   end;

   for v:=0 to pbits-1 do begin //4 2Bit-Pakets match one Byte =)
    bitbuffer^[v*4]:=pbitbuffer^[v] and 3;
    bitbuffer^[v*4+1]:=(pbitbuffer^[v] and (3 shl 2)) shr 2;
    bitbuffer^[v*4+2]:=(pbitbuffer^[v] and (3 shl 4)) shr 4;
    bitbuffer^[v*4+3]:=pbitbuffer^[v] shr 6;
   end;

   if (bitindex mod 4>0) then begin
    bitbuffer^[pbits*4]:=pbitbuffer^[pbits] and 3;
    if (bitindex mod 4>1) then bitbuffer^[pbits*4+1]:=(pbitbuffer^[pbits] and (3 shl 2)) shr 2;
    if (bitindex mod 4>2) then bitbuffer^[pbits*4+2]:=(pbitbuffer^[pbits] and (3 shl 4)) shr 4;
   end;

   freemem(pbitbuffer);
   //End UnPack

   //Unpack the DataBuffer
   if (head.quantbitsy<>8) then begin //Can we copy directly into databuffer?
    if ((dataindex*head.quantbitsy) mod 8=0) then pdata:=(dataindex*head.quantbitsy) div 8
     else pdata:=(dataindex*head.quantbitsy) div 8 +1;

    getmem(pdatabuffer,pdata); //Temp-Storage for packed DataTable
    blockread(f,pdatabuffer^,pdata);

    pbits:=0;
    for v:=0 to dataindex-1 do begin //ReStore Bytes out of the "packed" BitStream
     if (pbits mod 8=0) then begin
      data:=pdatabuffer^[pbits div 8] and ((1 shl head.quantbitsy)-1);
     end else begin
      data:=(cardinal(pdatabuffer^[pbits div 8]) shr (pbits mod 8)) and ((1 shl head.quantbitsy)-1);
      if ((pbits+head.quantbitsy) div 8>pbits div 8) then begin
       data2:=cardinal(pdatabuffer^[(pbits div 8)+1]) and ((1 shl ((pbits+head.quantbitsy) mod 8))-1);
       data:=data or (data2 shl (8-(pbits mod 8)));
      end;
     end;
     databuffer^[v]:=data;
     inc(pbits,head.quantbitsy);
    end;

    freemem(pdatabuffer);
   end else blockread(f,databuffer^,dataindex);
   //End Unpack

   DeWaveletPackGS(wlr,bitbuffer,bitindex,databuffer,dataindex,head.width,head.height,head.depth,head.quantbitsy);

   freemem(bitbuffer);
   freemem(databuffer);

   //GREEN

   bitindex:=head.bitsg;  //2Bit-Packets in BitTable (Green)
   dataindex:=head.datag; //QuantBit-Packets in DataTable

   getmem(bitbuffer,bitindex);  //Alloc Mem for Byte-Storage of the Tables
   getmem(databuffer,dataindex);

   //UnPack the BitBuffer
   pbits:=bitindex div 4;

   if (bitindex mod 4=0) then begin
    getmem(pbitbuffer,pbits);    //Temp-Storage for packed BitTable
    blockread(f,pbitbuffer^,pbits);
   end else begin
    getmem(pbitbuffer,pbits+1);
    blockread(f,pbitbuffer^,pbits+1);
   end;

   for v:=0 to pbits-1 do begin //4 2Bit-Pakets match one Byte =)
    bitbuffer^[v*4]:=pbitbuffer^[v] and 3;
    bitbuffer^[v*4+1]:=(pbitbuffer^[v] and (3 shl 2)) shr 2;
    bitbuffer^[v*4+2]:=(pbitbuffer^[v] and (3 shl 4)) shr 4;
    bitbuffer^[v*4+3]:=pbitbuffer^[v] shr 6;
   end;

   if (bitindex mod 4>0) then begin
    bitbuffer^[pbits*4]:=pbitbuffer^[pbits] and 3;
    if (bitindex mod 4>1) then bitbuffer^[pbits*4+1]:=(pbitbuffer^[pbits] and (3 shl 2)) shr 2;
    if (bitindex mod 4>2) then bitbuffer^[pbits*4+2]:=(pbitbuffer^[pbits] and (3 shl 4)) shr 4;
   end;

   freemem(pbitbuffer);
   //End UnPack

   //Unpack the DataBuffer
   if (head.quantbitsu<>8) then begin //Can we copy directly into databuffer?
    if ((dataindex*head.quantbitsu) mod 8=0) then pdata:=(dataindex*head.quantbitsu) div 8
     else pdata:=(dataindex*head.quantbitsu) div 8 +1;

    getmem(pdatabuffer,pdata); //Temp-Storage for packed DataTable
    blockread(f,pdatabuffer^,pdata);

    pbits:=0;
    for v:=0 to dataindex-1 do begin //ReStore Bytes out of the "packed" BitStream
     if (pbits mod 8=0) then begin
      data:=pdatabuffer^[pbits div 8] and ((1 shl head.quantbitsu)-1);
     end else begin
      data:=(cardinal(pdatabuffer^[pbits div 8]) shr (pbits mod 8)) and ((1 shl head.quantbitsu)-1);
      if ((pbits+head.quantbitsu) div 8>pbits div 8) then begin
       data2:=cardinal(pdatabuffer^[(pbits div 8)+1]) and ((1 shl ((pbits+head.quantbitsu) mod 8))-1);
       data:=data or (data2 shl (8-(pbits mod 8)));
      end;
     end;
     databuffer^[v]:=data;
     inc(pbits,head.quantbitsu);
    end;

    freemem(pdatabuffer);
   end else blockread(f,databuffer^,dataindex);
   //End Unpack

   DeWaveletPackGS(wlg,bitbuffer,bitindex,databuffer,dataindex,head.width,head.height,head.depth,head.quantbitsu);

   freemem(bitbuffer);
   freemem(databuffer);

   //BLUE

   bitindex:=head.bitsb;  //2Bit-Packets in BitTable (Blue)
   dataindex:=head.datab; //QuantBit-Packets in DataTable

   getmem(bitbuffer,bitindex);   //Alloc Mem for Byte-Storage of the Tables
   getmem(databuffer,dataindex);

   //UnPack the BitBuffer
   pbits:=bitindex div 4;

   if (bitindex mod 4=0) then begin
    getmem(pbitbuffer,pbits);    //Temp-Storage for packed BitTable
    blockread(f,pbitbuffer^,pbits);
   end else begin
    getmem(pbitbuffer,pbits+1);
    blockread(f,pbitbuffer^,pbits+1);
   end;

   for v:=0 to pbits-1 do begin //4 2Bit-Pakets match one Byte =)
    bitbuffer^[v*4]:=pbitbuffer^[v] and 3;
    bitbuffer^[v*4+1]:=(pbitbuffer^[v] and (3 shl 2)) shr 2;
    bitbuffer^[v*4+2]:=(pbitbuffer^[v] and (3 shl 4)) shr 4;
    bitbuffer^[v*4+3]:=pbitbuffer^[v] shr 6;
   end;

   if (bitindex mod 4>0) then begin
    bitbuffer^[pbits*4]:=pbitbuffer^[pbits] and 3;
    if (bitindex mod 4>1) then bitbuffer^[pbits*4+1]:=(pbitbuffer^[pbits] and (3 shl 2)) shr 2;
    if (bitindex mod 4>2) then bitbuffer^[pbits*4+2]:=(pbitbuffer^[pbits] and (3 shl 4)) shr 4;
   end;

   freemem(pbitbuffer);
   //End UnPack

   //Unpack the DataBuffer
   if (head.quantbitsv<>8) then begin //Can we copy directly into databuffer?
    if ((dataindex*head.quantbitsv) mod 8=0) then pdata:=(dataindex*head.quantbitsv) div 8
     else pdata:=(dataindex*head.quantbitsv) div 8 +1;

    getmem(pdatabuffer,pdata); //Temp-Storage for packed DataTable
    blockread(f,pdatabuffer^,pdata);

    pbits:=0;
    for v:=0 to dataindex-1 do begin //ReStore Bytes out of the "packed" BitStream
     if (pbits mod 8=0) then begin
      data:=pdatabuffer^[pbits div 8] and ((1 shl head.quantbitsv)-1);
     end else begin
      data:=(cardinal(pdatabuffer^[pbits div 8]) shr (pbits mod 8)) and ((1 shl head.quantbitsv)-1);
      if ((pbits+head.quantbitsv) div 8>pbits div 8) then begin
       data2:=cardinal(pdatabuffer^[(pbits div 8)+1]) and ((1 shl ((pbits+head.quantbitsv) mod 8))-1);
       data:=data or (data2 shl (8-(pbits mod 8)));
      end;
     end;
     databuffer^[v]:=data;
     inc(pbits,head.quantbitsv);
    end;

    freemem(pdatabuffer);
   end else blockread(f,databuffer^,dataindex);
   //End Unpack

   DeWaveletPackGS(wlb,bitbuffer,bitindex,databuffer,dataindex,head.width,head.height,head.depth,head.quantbitsv);

   freemem(bitbuffer);
   freemem(databuffer);
  end;

  Closefile(f);
END;

PROCEDURE WaveletPackGS(wl : piarray; bitbuffer : pbarray; var bitindex : cardinal; databuffer : pbarray; var dataindex : cardinal; xres,yres,depth,bits : cardinal);
Var v,c,maxlength,minlength : cardinal;

 FUNCTION Zeros2Come : cardinal; //Count overall Zeros AFTER the current position in the Wavelet
  Var t : cardinal;
 BEGIN
   t:=1;
   while (v+t<xres*yres-1) and (wl^[v+t]=0) and (t<maxlength) do inc(t);
   zeros2come:=t-1;
 END;

BEGIN
   maxlength:=1 shl (bits+2); //Maximum RLE-length (depends on the QuantizerBits!)
   minlength:=(bits+4) div 2; //Minimum RLE-length (otherwise the File gets bigger then possible!)

   v:=0;
   while (v<xres*yres) do begin //Go through Wavelet
     if wl^[v]=0 then begin     //Found a Zero
      c:=zeros2come;            //Count Zeros afterwards
      if c<=minlength then bitbuffer^[bitindex]:=HWL_ISO_ZERO //One (or only a few) Zeros found -> Encode Single Zero
       else begin
        bitbuffer^[bitindex]:=HWL_RLE_ZERO; //Found a lotta Zeros =)
        inc(bitindex);                      //continue in bitTable (+2Bits for the amount!)
        databuffer^[dataindex]:=c and ((1 shl bits)-1); //Store the first bits of the amount in the DataBuffer
        bitbuffer^[bitindex]:=c shr bits;   //Store the last 2 Bits in the next entry of the BitBuffer
        inc(dataindex);                     //inc databuffer-index
        inc(v,c);                           //inc position in wavelet
       end;
     end else if wl^[v]>0 then begin   //Significant Positive
      bitbuffer^[bitindex]:=HWL_POS;
      databuffer^[dataindex]:=wl^[v];  //store in databuffer
      inc(dataindex);
     end else begin                    //Significant Negative
      bitbuffer^[bitindex]:=HWL_NEG;
      databuffer^[dataindex]:=-wl^[v]; //store in databuffer
      inc(dataindex);
     end;
    inc(bitindex);                     //continue in wavelet/bitTable
    inc(v);
   end;
END;


PROCEDURE WriteHWLToStream(Stream: TStream; wlr, wlg, wlb: piarray; xres, yres, bpp, depth: cardinal; quantfactorr, quantfactorg, quantfactorb: pfarray; quantbitsy, quantbitsu, quantbitsv: byte);
 Var
  head              : HWL_Header;
  bitbuffer         : pbarray;
  databuffer        : pbarray;
  bitindex, dataindex, pbits, pbits2, data, data2 : cardinal;
  v                 : longint;
BEGIN
  head.ID := 'HWL';                     //Prepare HWL-Header
  head.width := xres;
  head.height := yres;
  head.bpp := bpp;
  head.depth := depth;
  head.quantbitsy := quantbitsy;
  head.quantbitsu := quantbitsu;
  head.quantbitsv := quantbitsv;

  getmem(bitbuffer, xres * yres);       //Alloc Mem for the Bit/Data-Table
  getmem(databuffer, xres * yres);

  if bpp = HWL_GS then
    begin                               //Greyscale
      bitindex := 0;
      dataindex := 0;

      WaveletPackGS(wlr, bitbuffer, bitindex, databuffer, dataindex, xres, yres, depth, quantbitsy); //Pack the Wavelet into Byte-Tables

      //Pack the BitBuffer
      pbits := bitindex div 4;

      for v := 0 to pbits - 1 do        //4 2Bit-Pakets match one Byte =)
        bitbuffer^[v] := bitbuffer^[v * 4] or (bitbuffer^[v * 4 + 1] shl 2) or (bitbuffer^[v * 4 + 2] shl 4) or (bitbuffer^[v * 4 + 3] shl 6);

      case (bitindex mod 4) of
        1: bitbuffer^[pbits] := bitbuffer^[pbits * 4];
        2: bitbuffer^[pbits] := bitbuffer^[pbits * 4] or (bitbuffer^[pbits * 4 + 1] shl 2);
        3: bitbuffer^[pbits] := bitbuffer^[pbits * 4] or (bitbuffer^[pbits * 4 + 1] shl 2) or (bitbuffer^[pbits * 4 + 2] shl 4);
      end;
      //End Pack

      head.bitsr := bitindex;           //Output Head,QuantizerFactors and BitTable
      head.datar := dataindex;
      Stream.WriteBuffer(head, sizeof(head));
      Stream.WriteBuffer(quantfactorr^, (depth + 2) * sizeof(double));
      if (bitindex mod 4 = 0) then
        Stream.WriteBuffer(bitbuffer^, pbits)
      else
        Stream.WriteBuffer(bitbuffer^, pbits + 1);

      //Pack the DataBuffer
      pbits := 0;
      for v := 0 to dataindex - 1 do
        begin                           //Pack single Bytes into a BitStream (depending on QuantizerBits)
          if (pbits mod 8 = 0) then
            begin
              data := databuffer^[v];
            end
          else
            begin
              data := cardinal(databuffer^[v]) shl (pbits mod 8);
              if ((pbits + quantbitsy) div 8 > pbits div 8) then
                begin
                  data2 := data shr 8;
                  data := data and $FF;
                  databuffer^[(pbits div 8) + 1] := data2;
                end;
              data := data or (cardinal(databuffer^[pbits div 8]) and ((1 shl (pbits mod 8)) - 1));
            end;
          databuffer^[pbits div 8] := data;
          inc(pbits, quantbitsy);
        end;
      //End Pack

      if (pbits mod 8 = 0) then
        Stream.WriteBuffer(databuffer^, pbits div 8) //Output Data-Bit-Table
      else
        Stream.WriteBuffer(databuffer^, (pbits div 8) + 1);
    end
  else if bpp = HWL_RGB then
    begin                               //RGB
      //RED
      bitindex := 0;
      dataindex := 0;

      WaveletPackGS(wlr, bitbuffer, bitindex, databuffer, dataindex, xres, yres, depth, quantbitsy); //Pack the Wavelet into Byte-Tables

      //Pack the BitBuffer
      pbits := bitindex div 4;

      for v := 0 to pbits - 1 do        //4 2Bit-Pakets match one Byte =)
        bitbuffer^[v] := bitbuffer^[v * 4] or (bitbuffer^[v * 4 + 1] shl 2) or (bitbuffer^[v * 4 + 2] shl 4) or (bitbuffer^[v * 4 + 3] shl 6);

      case (bitindex mod 4) of
        1: bitbuffer^[pbits] := bitbuffer^[pbits * 4];
        2: bitbuffer^[pbits] := bitbuffer^[pbits * 4] or (bitbuffer^[pbits * 4 + 1] shl 2);
        3: bitbuffer^[pbits] := bitbuffer^[pbits * 4] or (bitbuffer^[pbits * 4 + 1] shl 2) or (bitbuffer^[pbits * 4 + 2] shl 4);
      end;
      //End Pack

      if (bitindex mod 4 = 0) then
        pbits2 := pbits
      else
        pbits2 := pbits + 1;

      //Pack the DataBuffer
      pbits := 0;
      for v := 0 to dataindex - 1 do
        begin                           //Pack single Bytes into a BitStream (depending on QuantizerBits)
          if (pbits mod 8 = 0) then
            begin
              data := databuffer^[v];
            end
          else
            begin
              data := cardinal(databuffer^[v]) shl (pbits mod 8);
              if ((pbits + quantbitsy) div 8 > pbits div 8) then
                begin
                  data2 := data shr 8;
                  data := data and $FF;
                  databuffer^[(pbits div 8) + 1] := data2;
                end;
              data := data or (cardinal(databuffer^[pbits div 8]) and ((1 shl (pbits mod 8)) - 1));
            end;
          databuffer^[pbits div 8] := data;
          inc(pbits, quantbitsy);
        end;
      //End Pack

      head.bitsr := bitindex;           //Output Head,QuantizerFactors (Red,Green,Blue), BitTable (Red) and DataTable (Red)
      head.datar := dataindex;
      Stream.WriteBuffer(head, sizeof(head));
      Stream.WriteBuffer(quantfactorr^, (depth + 2) * sizeof(double));
      Stream.WriteBuffer(quantfactorg^, (depth + 2) * sizeof(double));
      Stream.WriteBuffer(quantfactorb^, (depth + 2) * sizeof(double));
      Stream.WriteBuffer(bitbuffer^, pbits2);
      if (pbits mod 8 = 0) then
        Stream.WriteBuffer(databuffer^, pbits div 8)
      else
        Stream.WriteBuffer(databuffer^, (pbits div 8) + 1);

      //GREEN

      bitindex := 0;
      dataindex := 0;

      WaveletPackGS(wlg, bitbuffer, bitindex, databuffer, dataindex, xres, yres, depth, quantbitsu); //Pack the Wavelet into Byte-Tables

      //Pack the BitBuffer
      pbits := bitindex div 4;

      for v := 0 to pbits - 1 do        //4 2Bit-Pakets match one Byte =)
        bitbuffer^[v] := bitbuffer^[v * 4] or (bitbuffer^[v * 4 + 1] shl 2) or (bitbuffer^[v * 4 + 2] shl 4) or (bitbuffer^[v * 4 + 3] shl 6);

      case (bitindex mod 4) of
        1: bitbuffer^[pbits] := bitbuffer^[pbits * 4];
        2: bitbuffer^[pbits] := bitbuffer^[pbits * 4] or (bitbuffer^[pbits * 4 + 1] shl 2);
        3: bitbuffer^[pbits] := bitbuffer^[pbits * 4] or (bitbuffer^[pbits * 4 + 1] shl 2) or (bitbuffer^[pbits * 4 + 2] shl 4);
      end;
      //End Pack

      if (bitindex mod 4 = 0) then
        pbits2 := pbits
      else
        pbits2 := pbits + 1;

      //Pack the DataBuffer
      pbits := 0;
      for v := 0 to dataindex - 1 do
        begin                           //Pack single Bytes into a BitStream (depending on QuantizerBits)
          if (pbits mod 8 = 0) then
            begin
              data := databuffer^[v];
            end
          else
            begin
              data := cardinal(databuffer^[v]) shl (pbits mod 8);
              if ((pbits + quantbitsu) div 8 > pbits div 8) then
                begin
                  data2 := data shr 8;
                  data := data and $FF;
                  databuffer^[(pbits div 8) + 1] := data2;
                end;
              data := data or (cardinal(databuffer^[pbits div 8]) and ((1 shl (pbits mod 8)) - 1));
            end;
          databuffer^[pbits div 8] := data;
          inc(pbits, quantbitsu);
        end;
      //End Pack

      head.bitsg := bitindex;           //Output BitTable (Green) and DataTable (Green)
      head.datag := dataindex;
      Stream.WriteBuffer(bitbuffer^, pbits2);
      if (pbits mod 8 = 0) then
        Stream.WriteBuffer(databuffer^, pbits div 8)
      else
        Stream.WriteBuffer(databuffer^, (pbits div 8) + 1);

      //BLUE

      bitindex := 0;
      dataindex := 0;

      WaveletPackGS(wlb, bitbuffer, bitindex, databuffer, dataindex, xres, yres, depth, quantbitsv); //Pack the Wavelet into Byte-Tables

      //Pack the BitBuffer
      pbits := bitindex div 4;

      for v := 0 to pbits - 1 do        //4 2Bit-Pakets match one Byte =)
        bitbuffer^[v] := bitbuffer^[v * 4] or (bitbuffer^[v * 4 + 1] shl 2) or (bitbuffer^[v * 4 + 2] shl 4) or (bitbuffer^[v * 4 + 3] shl 6);

      case (bitindex mod 4) of
        1: bitbuffer^[pbits] := bitbuffer^[pbits * 4];
        2: bitbuffer^[pbits] := bitbuffer^[pbits * 4] or (bitbuffer^[pbits * 4 + 1] shl 2);
        3: bitbuffer^[pbits] := bitbuffer^[pbits * 4] or (bitbuffer^[pbits * 4 + 1] shl 2) or (bitbuffer^[pbits * 4 + 2] shl 4);
      end;
      //End Pack

      if (bitindex mod 4 = 0) then
        pbits2 := pbits
      else
        pbits2 := pbits + 1;

      //Pack the DataBuffer
      pbits := 0;
      for v := 0 to dataindex - 1 do
        begin                           //Pack single Bytes into a BitStream (depending on QuantizerBits)
          if (pbits mod 8 = 0) then
            begin
              data := databuffer^[v];
            end
          else
            begin
              data := cardinal(databuffer^[v]) shl (pbits mod 8);
              if ((pbits + quantbitsv) div 8 > pbits div 8) then
                begin
                  data2 := data shr 8;
                  data := data and $FF;
                  databuffer^[(pbits div 8) + 1] := data2;
                end;
              data := data or (cardinal(databuffer^[pbits div 8]) and ((1 shl (pbits mod 8)) - 1));
            end;
          databuffer^[pbits div 8] := data;
          inc(pbits, quantbitsv);
        end;
      //End Pack

      head.bitsb := bitindex;           //Output BitTable (Blue) and DataTable (Blue)
      head.datab := dataindex;
      Stream.WriteBuffer(bitbuffer^, pbits2);
      if (pbits mod 8 = 0) then
        Stream.WriteBuffer(databuffer^, pbits div 8)
      else
        Stream.WriteBuffer(databuffer^, (pbits div 8) + 1);

      Stream.Position := 0;
      Stream.WriteBuffer(head, sizeof(head)); //Output Head (again =)
    end;

  freemem(bitbuffer, xres * yres);
  freemem(databuffer, xres * yres);

  {application.messagebox(@(inttostr(pbits)+#0)[1],'bits',0);
  application.messagebox(@(inttostr(dataindex)+#0)[1],'data',0);//TEST PURPOSE}
END;


PROCEDURE WriteHWL(name : string; wlr,wlg,wlb : piarray; xres,yres,bpp,depth : cardinal; quantfactorr,quantfactorg,quantfactorb : pfarray; quantbitsy,quantbitsu,quantbitsv : byte);
 Var f : file;
     head : HWL_Header;
     bitbuffer : pbarray;
     databuffer : pbarray;
     bitindex,dataindex,pbits,pbits2,data,data2 : cardinal;
     v : longint;
BEGIN
  head.ID:='HWL';    //Prepare HWL-Header
  head.width:=xres;
  head.height:=yres;
  head.bpp:=bpp;
  head.depth:=depth;
  head.quantbitsy:=quantbitsy;
  head.quantbitsu:=quantbitsu;
  head.quantbitsv:=quantbitsv;

  getmem(bitbuffer,xres*yres);  //Alloc Mem for the Bit/Data-Table
  getmem(databuffer,xres*yres);

  Assignfile(f,name);
  filemode:=2;
  Rewrite(f,1);

  if bpp=HWL_GS then begin //Greyscale
   bitindex:=0;
   dataindex:=0;

   WaveletPackGS(wlr,bitbuffer,bitindex,databuffer,dataindex,xres,yres,depth,quantbitsy); //Pack the Wavelet into Byte-Tables

   //Pack the BitBuffer
   pbits:=bitindex div 4;

   for v:=0 to pbits-1 do //4 2Bit-Pakets match one Byte =)
    bitbuffer^[v]:=bitbuffer^[v*4] or (bitbuffer^[v*4+1] shl 2) or (bitbuffer^[v*4+2] shl 4) or (bitbuffer^[v*4+3] shl 6);

   case (bitindex mod 4) of
    1: bitbuffer^[pbits]:=bitbuffer^[pbits*4];
    2: bitbuffer^[pbits]:=bitbuffer^[pbits*4] or (bitbuffer^[pbits*4+1] shl 2);
    3: bitbuffer^[pbits]:=bitbuffer^[pbits*4] or (bitbuffer^[pbits*4+1] shl 2) or (bitbuffer^[pbits*4+2] shl 4);
   end;
   //End Pack

   head.bitsr:=bitindex; //Output Head,QuantizerFactors and BitTable
   head.datar:=dataindex;
   blockwrite(f,head,sizeof(head));
   blockwrite(f,quantfactorr^,(depth+2)*sizeof(double));
   if (bitindex mod 4=0) then blockwrite(f,bitbuffer^,pbits)
    else blockwrite(f,bitbuffer^,pbits+1);

   //Pack the DataBuffer
   pbits:=0;
   for v:=0 to dataindex-1 do begin //Pack single Bytes into a BitStream (depending on QuantizerBits)
    if (pbits mod 8=0) then begin
     data:=databuffer^[v];
    end else begin
     data:=cardinal(databuffer^[v]) shl (pbits mod 8);
     if ((pbits+quantbitsy) div 8>pbits div 8) then begin
      data2:=data shr 8;
      data:=data and $FF;
      databuffer^[(pbits div 8)+1]:=data2;
     end;
     data:=data or (cardinal(databuffer^[pbits div 8]) and ((1 shl (pbits mod 8))-1));
    end;
    databuffer^[pbits div 8]:=data;
    inc(pbits,quantbitsy);
   end;
   //End Pack

   if (pbits mod 8=0) then blockwrite(f,databuffer^,pbits div 8) //Output Data-Bit-Table
    else blockwrite(f,databuffer^,(pbits div 8)+1);
  end else if bpp=HWL_RGB then begin //RGB
   //RED
   bitindex:=0;
   dataindex:=0;

   WaveletPackGS(wlr,bitbuffer,bitindex,databuffer,dataindex,xres,yres,depth,quantbitsy); //Pack the Wavelet into Byte-Tables

   //Pack the BitBuffer
   pbits:=bitindex div 4;

   for v:=0 to pbits-1 do //4 2Bit-Pakets match one Byte =)
    bitbuffer^[v]:=bitbuffer^[v*4] or (bitbuffer^[v*4+1] shl 2) or (bitbuffer^[v*4+2] shl 4) or (bitbuffer^[v*4+3] shl 6);

   case (bitindex mod 4) of
    1: bitbuffer^[pbits]:=bitbuffer^[pbits*4];
    2: bitbuffer^[pbits]:=bitbuffer^[pbits*4] or (bitbuffer^[pbits*4+1] shl 2);
    3: bitbuffer^[pbits]:=bitbuffer^[pbits*4] or (bitbuffer^[pbits*4+1] shl 2) or (bitbuffer^[pbits*4+2] shl 4);
   end;
   //End Pack

   if (bitindex mod 4=0) then pbits2:=pbits
    else pbits2:=pbits+1;

   //Pack the DataBuffer
   pbits:=0;
   for v:=0 to dataindex-1 do begin //Pack single Bytes into a BitStream (depending on QuantizerBits)
    if (pbits mod 8=0) then begin
     data:=databuffer^[v];
    end else begin
     data:=cardinal(databuffer^[v]) shl (pbits mod 8);
     if ((pbits+quantbitsy) div 8>pbits div 8) then begin
      data2:=data shr 8;
      data:=data and $FF;
      databuffer^[(pbits div 8)+1]:=data2;
     end;
     data:=data or (cardinal(databuffer^[pbits div 8]) and ((1 shl (pbits mod 8))-1));
    end;
    databuffer^[pbits div 8]:=data;
    inc(pbits,quantbitsy);
   end;
   //End Pack

   head.bitsr:=bitindex;  //Output Head,QuantizerFactors (Red,Green,Blue), BitTable (Red) and DataTable (Red)
   head.datar:=dataindex;
   blockwrite(f,head,sizeof(head));
   blockwrite(f,quantfactorr^,(depth+2)*sizeof(double));
   blockwrite(f,quantfactorg^,(depth+2)*sizeof(double));
   blockwrite(f,quantfactorb^,(depth+2)*sizeof(double));
   blockwrite(f,bitbuffer^,pbits2);
   if (pbits mod 8=0) then blockwrite(f,databuffer^,pbits div 8)
    else blockwrite(f,databuffer^,(pbits div 8)+1);

   //GREEN

   bitindex:=0;
   dataindex:=0;

   WaveletPackGS(wlg,bitbuffer,bitindex,databuffer,dataindex,xres,yres,depth,quantbitsu); //Pack the Wavelet into Byte-Tables

   //Pack the BitBuffer
   pbits:=bitindex div 4;

   for v:=0 to pbits-1 do //4 2Bit-Pakets match one Byte =)
    bitbuffer^[v]:=bitbuffer^[v*4] or (bitbuffer^[v*4+1] shl 2) or (bitbuffer^[v*4+2] shl 4) or (bitbuffer^[v*4+3] shl 6);

   case (bitindex mod 4) of
    1: bitbuffer^[pbits]:=bitbuffer^[pbits*4];
    2: bitbuffer^[pbits]:=bitbuffer^[pbits*4] or (bitbuffer^[pbits*4+1] shl 2);
    3: bitbuffer^[pbits]:=bitbuffer^[pbits*4] or (bitbuffer^[pbits*4+1] shl 2) or (bitbuffer^[pbits*4+2] shl 4);
   end;
   //End Pack

   if (bitindex mod 4=0) then pbits2:=pbits
    else pbits2:=pbits+1;

   //Pack the DataBuffer
   pbits:=0;
   for v:=0 to dataindex-1 do begin //Pack single Bytes into a BitStream (depending on QuantizerBits)
    if (pbits mod 8=0) then begin
     data:=databuffer^[v];
    end else begin
     data:=cardinal(databuffer^[v]) shl (pbits mod 8);
     if ((pbits+quantbitsu) div 8>pbits div 8) then begin
      data2:=data shr 8;
      data:=data and $FF;
      databuffer^[(pbits div 8)+1]:=data2;
     end;
     data:=data or (cardinal(databuffer^[pbits div 8]) and ((1 shl (pbits mod 8))-1));
    end;
    databuffer^[pbits div 8]:=data;
    inc(pbits,quantbitsu);
   end;
   //End Pack

   head.bitsg:=bitindex; //Output BitTable (Green) and DataTable (Green)
   head.datag:=dataindex;
   blockwrite(f,bitbuffer^,pbits2);
   if (pbits mod 8=0) then blockwrite(f,databuffer^,pbits div 8)
    else blockwrite(f,databuffer^,(pbits div 8)+1);

   //BLUE

   bitindex:=0;
   dataindex:=0;

   WaveletPackGS(wlb,bitbuffer,bitindex,databuffer,dataindex,xres,yres,depth,quantbitsv); //Pack the Wavelet into Byte-Tables

   //Pack the BitBuffer
   pbits:=bitindex div 4;

   for v:=0 to pbits-1 do //4 2Bit-Pakets match one Byte =)
    bitbuffer^[v]:=bitbuffer^[v*4] or (bitbuffer^[v*4+1] shl 2) or (bitbuffer^[v*4+2] shl 4) or (bitbuffer^[v*4+3] shl 6);

   case (bitindex mod 4) of
    1: bitbuffer^[pbits]:=bitbuffer^[pbits*4];
    2: bitbuffer^[pbits]:=bitbuffer^[pbits*4] or (bitbuffer^[pbits*4+1] shl 2);
    3: bitbuffer^[pbits]:=bitbuffer^[pbits*4] or (bitbuffer^[pbits*4+1] shl 2) or (bitbuffer^[pbits*4+2] shl 4);
   end;
   //End Pack

   if (bitindex mod 4=0) then pbits2:=pbits
    else pbits2:=pbits+1;

   //Pack the DataBuffer
   pbits:=0;
   for v:=0 to dataindex-1 do begin //Pack single Bytes into a BitStream (depending on QuantizerBits)
    if (pbits mod 8=0) then begin
     data:=databuffer^[v];
    end else begin
     data:=cardinal(databuffer^[v]) shl (pbits mod 8);
     if ((pbits+quantbitsv) div 8>pbits div 8) then begin
      data2:=data shr 8;
      data:=data and $FF;
      databuffer^[(pbits div 8)+1]:=data2;
     end;
     data:=data or (cardinal(databuffer^[pbits div 8]) and ((1 shl (pbits mod 8))-1));
    end;
    databuffer^[pbits div 8]:=data;
    inc(pbits,quantbitsv);
   end;
   //End Pack

   head.bitsb:=bitindex; //Output BitTable (Blue) and DataTable (Blue)
   head.datab:=dataindex;
   blockwrite(f,bitbuffer^,pbits2);
   if (pbits mod 8=0) then blockwrite(f,databuffer^,pbits div 8)
    else blockwrite(f,databuffer^,(pbits div 8)+1);

   seek(f,0);
   blockwrite(f,head,sizeof(head)); //Output Head (again =)
  end;

  freemem(bitbuffer,xres*yres);
  freemem(databuffer,xres*yres);

  Closefile(f);

  {application.messagebox(@(inttostr(pbits)+#0)[1],'bits',0);
  application.messagebox(@(inttostr(dataindex)+#0)[1],'data',0);//TEST PURPOSE}
END;

end.

{HISTORY: 02.02.2001: -added a little 'trick' to the DeWaveletGS-Routine..
                       it's based upon the idea of more complex wavelets, which
                       try to filter more "information" (-> pixeldata) into
                       single low/high-pass coefficients..
                       the 'trick' in my routine uses an idea i adopted from
                       alan watt's article about wavelets in his "3d games vol.1"-book..
                       he uses linear interpolation of the transformed coefficients
                       (-> results in an effect like gouraud shading =)
                       together with a (progressive) quadtree representation of the coefficient data..
                       DeWaveletGS simulates (read: "fakes" ;) this effect by interpolating
                       between the low-pass coefficients (if the related high-pass coefficient=0.0 (-> kicked data))..

                       Result: Amazing Quality Improvement! (-> CHECK IT OUT! 8-)
                       Best Thing: All previously stored .hwl-files remain valid.. 

                       (Search for //!UPDATED in the source)

          04.02.2001: -little bugfix for high contrasts (-> resulted in 'false' interpolation producing ugly artefacts!)

          05.05.2001: -added YUV-color-model..
                       the picture is converted into YUV before the wavelet transformation..
                       YUV allows to store more bits for the luminancy
                       of the picture (Y) and needs less bits for the color
                       information (U/V).. "without" quality loss.. (the human
                       eye can't recognize the pixel artefacts as easy as before ;)

                       it's converted back into RGB during loading..
                       so the header has been changed (two more bytes added!)
                       and the old (<v.0.6) .hwl-files can't be used anymore.. :(

                       Result: More Quality at Higher Compression Rates!
                       Bad Thing: due to "lame coding" =) the source-code
                                  isn't as readable as before.. :(

          06.05.2001: -improved RLE compression by using two additional bits for Zero-Packing..
          23.10.2002: -improved decompression speed a bit by optimizing the main loops with yucky code..
                      -added Stream functions (coded by Armindo aka ADS)
}
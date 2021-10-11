unit BMP;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs;

type
  TForm2 = class(TForm)
    procedure WMEraseBkgnd(var m : TWMEraseBkgnd);
    procedure FormPaint(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
    procedure ReLoad;        //ReSize/Draw Window
  end;

var
  Form2: TForm2;

implementation

uses Main;

{$R *.DFM}

procedure TForm2.ReLoad; //ReSize/Draw Window
begin
  self.height := form1.pic_height + GetSystemMetrics(SM_CYDLGFRAME) + GetSystemMetrics(SM_CYCAPTION);
  self.width  := form1.pic_width  + GetSystemMetrics(SM_CXDLGFRAME);
  self.FormPaint(nil);
end;

procedure TForm2.WMEraseBkgnd(var m : TWMEraseBkgnd);
begin
  m.Result:=LRESULT(False);
end;

procedure TForm2.FormPaint(Sender: TObject);
begin
  Canvas.Draw(0,0,Form1.pic_bitmap);
end;

procedure TForm2.FormClose(Sender: TObject; var Action: TCloseAction); //Window->BMP
begin
  Form1.BMP1.checked:=false;
end;

end.

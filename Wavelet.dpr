program Wavelet;

uses
  Forms,
  Main in 'Main.pas' {Form1},
  BMP in 'BMP.pas' {Form2},
  HWL in 'HWL.pas' {Form3},
  Wave in 'Wave.pas',
  About in 'About.pas' {Form4},
  HWLRaw in 'HWLRaw.pas' {Form5};

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TForm2, Form2);
  Application.CreateForm(TForm3, Form3);
  Application.CreateForm(TForm4, Form4);
  Application.CreateForm(TForm5, Form5);
  Application.Run;
end.

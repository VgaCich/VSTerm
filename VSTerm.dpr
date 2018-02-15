program VSTerm;

uses
  SysSfIni,
  Windows,
  AvL,
  MainForm;

{$R *.res}
{$R manifest.res}

begin
  InitCommonControls;
  FormMain := TMainForm.Create;
  FormMain.Run;
  FormMain.Free;
end.

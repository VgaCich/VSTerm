program VSTerm;

uses
  SysSfIni,
  Windows,
  AvL,
  MainForm,
  CustomBitRateForm;

{$R *.res}
{$R manifest.res}

begin
  InitCommonControls;
  FormMain := TMainForm.Create;
  FormCustomBitRate := TCustomBitRateForm.Create(FormMain);
  FormMain.Run;
  FormMain.Free;
end.

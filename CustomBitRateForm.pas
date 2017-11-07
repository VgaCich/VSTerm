unit CustomBitRateForm;

interface

uses
  Windows, AvL;

type
  TCustomBitRateForm = class(TForm)
  private
    BtnOK: TButton;
    EBitRate: TEdit;
    procedure OKClick(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
  public
    constructor Create(AParent: TWinControl);
    procedure Show(const CustomBitRate: string);
  end;

var
  FormCustomBitRate: TCustomBitRateForm;

implementation

uses
  MainForm;

constructor TCustomBitRateForm.Create(AParent: TWinControl);
begin
  inherited Create(AParent, 'Custom bitrate');
  BorderStyle := bsToolWindow;
  SetSize(200 + Width - ClientWidth, 35 + Height - ClientHeight);
  Position := poScreenCenter;
  OnKeyUp := FormKeyUp;
  OnShow := FormShow;
  EBitRate := TEdit.Create(Self, '');
  EBitRate.SetBounds(5, (ClientHeight - EBitRate.Height) div 2, 130, EBitRate.Height);
  EBitRate.OnKeyUp := FormKeyUp;
  BtnOK := TButton.Create(Self, 'OK');
  BtnOK.SetBounds(140, 5, 55, EBitRate.Height);
  BtnOK.OnClick := OKClick;
end;

procedure TCustomBitRateForm.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then OKClick(BtnOK);
  if Key = VK_ESCAPE then Close;
end;

procedure TCustomBitRateForm.FormShow(Sender: TObject);
begin
  EBitRate.SetFocus;
  EBitRate.SelectAll;
end;

procedure TCustomBitRateForm.OKClick(Sender: TObject);
begin
  FormMain.SetCustomBitRate(EBitRate.Text);
  Close;
end;

procedure TCustomBitRateForm.Show(const CustomBitRate: string);
begin
  EBitRate.Text := CustomBitRate;
  ShowModal;
end;

end.
 
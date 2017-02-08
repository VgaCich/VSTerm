unit ComboBoxEx;

interface

uses
  Windows, Messages, AvL;

type
  TComboBoxEx = class(TComboBox)
  private
    FOnDropDown: TOnEvent;
    function GetData(Index: Integer): Integer;
    procedure SetData(Index: Integer; Value: Integer);
    procedure WMCommand(var Msg: TWMCommand); message WM_COMMAND;
  public
    constructor Create(AParent: TWinControl; Style: TComboBoxStyle);
    function DataAdd(const S: ShortString; Value: Integer): Integer;
    property Data[Index: Integer]: Integer read GetData write SetData;
    property OnDropDown: TOnEvent read FOnDropDown write FOnDropDown;
  end;

implementation

const IDComboBoxEx = $CBBE;

function EditHookProc(hWnd: THandle; Msg: UINT; wParam, lParam: Longint): Longint; stdcall;
begin
  if (Msg = WM_KEYUP) and (wParam = VK_RETURN) then
    SendMessage(GetWindowLong(hWnd, GWL_HWNDPARENT), Msg, wParam, lParam);
  Result := CallWindowProc(Pointer(GetWindowLong(hWnd, GWL_USERDATA)), hWnd, Msg, wParam, lParam);
end;

function ParentHookProc(hWnd: THandle; Msg: UINT; wParam, lParam: Longint): Longint; stdcall;
begin
  if (Msg = WM_COMMAND) and (wParam = (CBN_DROPDOWN shl 16) or IDComboBoxEx) then
    SendMessage(THandle(lParam), Msg, wParam, lParam);
  Result := CallWindowProc(Pointer(GetWindowLong(hWnd, GWL_USERDATA)), hWnd, Msg, wParam, lParam);
end;

function TComboBoxEx.DataAdd(const S: ShortString; Value: Integer): Integer;
begin
  Result := ItemAdd(S);
  Data[Result] := Value;
end;

constructor TComboBoxEx.Create(AParent: TWinControl; Style: TComboBoxStyle);
begin
  inherited Create(AParent, Style);
  SetWindowLong(Handle, GWL_ID, IDComboBoxEx);
  SetWindowLong(GetWindow(Handle, GW_CHILD), GWL_USERDATA,
    SetWindowLong(GetWindow(Handle, GW_CHILD), GWL_WNDPROC, Longint(@EditHookProc)));
  if GetWindowLong(ParentHandle, GWL_WNDPROC) <> Integer(@ParentHookProc) then
    SetWindowLong(ParentHandle, GWL_USERDATA,
      SetWindowLong(ParentHandle, GWL_WNDPROC, Longint(@ParentHookProc)));
end;

function TComboBoxEx.GetData(Index: Integer): Integer;
begin
  if (Index >= 0) and (Index < ItemCount) then
    Result := Perform(CB_GETITEMDATA, Index, 0);
end;

procedure TComboBoxEx.SetData(Index, Value: Integer);
begin
  if (Index >= 0) and (Index < ItemCount) then
    Perform(CB_SETITEMDATA, Index, Value);
end;

procedure TComboBoxEx.WMCommand(var Msg: TWMCommand);
begin
  if (Msg.Ctl = Handle) and (Msg.ItemID = IDComboBoxEx) and
    (Msg.NotifyCode = CBN_DROPDOWN) and Assigned(FOnDropDown) then
      FOnDropDown(Self);
end;

end.
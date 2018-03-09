unit MainForm;

{.$DEFINE DEBUG_LOOPBACK}

interface

uses
  Windows, Messages, AvL, avlUtils, avlCOMPort, avlSettings, DataConverter, TermLog, ComboBoxEx;

type
  TSettingsItem = record
    Name: string;
    Value: Integer;
  end;
  TSettingsItems = array[0..MaxInt div SizeOf(TSettingsItem) - 1] of TSettingsItem;
  PSettingsItems = ^TSettingsItems;
  TMainForm = class(TForm)
  private
    TermLog: TTermLog;
    CBPort: TComboBoxEx;
    CBBitRate: TComboBoxEx;
    CBDataBits: TComboBoxEx;
    CBStopBits: TComboBoxEx;
    CBParity: TComboBoxEx;
    BtnConnect: TButton;
    BtnTogglePanels: TButton;
    Label1: TLabel;
    CBRecvMode: TComboBoxEx;
    CBSendMode: TComboBoxEx;
    Label2: TLabel;
    GroupBoxPort: TGroupBox;
    GroupBoxText: TGroupBox;
    CBShowCaps: TCheckBox;
    CBMute: TCheckBox;
    CBFlowCtrl: TComboBoxEx;
    CBSend: TComboBoxEx;
    MenuLog: TMenu;
    MenuSettings: TMenu;
    RecvTimer: TTimer;
    AccelTable: HAccel;
    COMPort: TCOMPort;
    ReceiveConverter: TReceiveConverter;
    MinWidth, MinHeight: Integer;
    FLogUpdateState, FLogUpdated: Boolean;
    FDumpFile: TFileStream;
    procedure BtnConnectClick(Sender: TObject);
    procedure BtnTogglePanelsClick(Sender: TObject);
    procedure CBBitRateChange(Sender: TObject);
    procedure CBDataBitsChange(Sender: TObject);
    procedure CBFlowCtrlChange(Sender: TObject);
    procedure CBParityChange(Sender: TObject);
    procedure CBPortDropDown(Sender: TObject);
    procedure CBRecvModeChange(Sender: TObject);
    procedure CBSendKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure CBStopBitsChange(Sender: TObject);
    procedure CBShowCapsClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    function FormProcessMsg(var Msg: TMsg): Boolean;
    procedure MIAboutClick(Sender: TObject);
    procedure MIClearClick(Sender: TObject);
    procedure MICopyClick(Sender: TObject);
    procedure MIDumpFileClick(Sender: TObject);
    procedure MISelectAllClick(Sender: TObject);
    procedure MISendFileClick(Sender: TObject);
    procedure MIStoreSettingsClick(Sender: TObject; Source: TSettingsSource);
    procedure ReceiveConverterConvert(Sender: TObject; const Data: string);
    procedure RecvTimerTimer(Sender: TObject);
    procedure TermLogMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Connect;
    procedure Disconnect;
    procedure SetControlsState(Connected: Boolean);
    procedure SetLogUpdateState(IsUpdating: Boolean);
    procedure FillComboBox(Combo: TComboBoxEx; const Settings: array of TSettingsItem; DefItem: Integer = 0);
    function GetComboValue(Combo: TComboBoxEx; Index: Integer = -MaxInt): Integer;
    function GetSettings: TSettings;
    procedure LoadSettings;
    procedure SaveSettings;
    procedure WMCommand(var Msg: TWMCommand); message WM_COMMAND;
    procedure WMSize(var Msg: TWMSize); message WM_SIZE;
    procedure WMSizing(var Msg: TWMMoving); message WM_SIZING;
    procedure WMSetFocus(var Msg: TWMSetFocus); message WM_SETFOCUS;
  public
    constructor Create;
  end;

var
  FormMain: TMainForm;

implementation

const
  CaptionRecv = 'Recv: ';
  CaptionSend = 'Send: ';
  AboutCaption = 'About ';
  CRLF = #13#10;
  AboutText = 'VgaSoft Terminal 2.0 alpha'+CRLF+CRLF+
              'Copyright '#169' VgaSoft, 2013-2018'+CRLF+
              'vgasoft@gmail.com';
  AboutIcon = 'MAINICON';
  BitRatesList: array[0..15] of TSettingsItem = (
    (Name: '110 Baud'; Value: CBR_110),
    (Name: '300 Baud'; Value: CBR_300),
    (Name: '600 Baud'; Value: CBR_600),
    (Name: '1200 Baud'; Value: CBR_1200),
    (Name: '2400 Baud'; Value: CBR_2400),
    (Name: '4800 Baud'; Value: CBR_4800),
    (Name: '9600 Baud'; Value: CBR_9600),
    (Name: '14.4k Baud'; Value: CBR_14400),
    (Name: '19.2k Baud'; Value: CBR_19200),
    (Name: '38.4k Baud'; Value: CBR_38400),
    (Name: '56k Baud'; Value: CBR_56000),
    (Name: '57.6k Baud'; Value: CBR_57600),
    (Name: '115.2k Baud'; Value: CBR_115200),
    (Name: '128k Baud'; Value: CBR_128000),
    (Name: '256k Baud'; Value: CBR_256000),
    (Name: 'Custom...'; Value: -1));
  DataBitsList: array[0..4] of TSettingsItem = (
    (Name: '5 Bits'; Value: 5),
    (Name: '6 Bits'; Value: 6),
    (Name: '7 Bits'; Value: 7),
    (Name: '8 Bits'; Value: 8),
    (Name: '16 Bits'; Value: 16));
  StopBitsList: array[0..2] of TSettingsItem = (
    (Name: '1 stop bit'; Value: ONESTOPBIT),
    (Name: '1.5 stop bits'; Value: ONE5STOPBITS),
    (Name: '2 stop bits'; Value: TWOSTOPBITS));
  ParityList: array[0..4] of TSettingsItem = (
    (Name: 'No parity'; Value: NOPARITY),
    (Name: 'Odd parity'; Value: ODDPARITY),
    (Name: 'Even parity'; Value: EVENPARITY),
    (Name: 'Mark parity'; Value: MARKPARITY),
    (Name: 'Space parity'; Value: SPACEPARITY));
  FlowCtrlList: array[TFlowControl] of TSettingsItem = (
    (Name: 'None'; Value: Integer(fcNone)),
    (Name: 'Hardware'; Value: Integer(fcHardware)),
    (Name: 'Software'; Value: Integer(fcSoftware)),
    (Name: 'HW+SW'; Value: Integer(fcBoth)));
  SendTextModeList: array[TTextMode] of TSettingsItem = (
    (Name: 'Disable'; Value: Integer(tmDisable)),
    (Name: 'ASCII'; Value: Integer(tmASCII)),
    (Name: 'ASCII C-style'; Value: Integer(tmASCIIC)),
    (Name: 'ASCII+LF'; Value: Integer(tmASCIILF)),
    (Name: 'ASCII+CR'; Value: Integer(tmASCIICR)),
    (Name: 'ASCII+CRLF'; Value: Integer(tmASCIICRLF)),
    (Name: 'ASCIIZ'; Value: Integer(tmASCIIZ)),
    (Name: 'Hex'; Value: Integer(tmHex)),
    (Name: 'Int8'; Value: Integer(tmInt8)),
    (Name: 'Int16'; Value: Integer(tmInt16)),
    (Name: 'Int32'; Value: Integer(tmInt32)));
  RecvTextModeList: array[0..5] of TSettingsItem = (
    (Name: 'Disable'; Value: Integer(tmDisable)),
    (Name: 'ASCII'; Value: Integer(tmASCII)),
    (Name: 'Hex'; Value: Integer(tmHex)),
    (Name: 'Int8'; Value: Integer(tmInt8)),
    (Name: 'Int16'; Value: Integer(tmInt16)),
    (Name: 'Int32'; Value: Integer(tmInt32)));
  AppName = 'VSTerm';
  IniSectMainForm = 'MainForm';
  IniSectSettings = 'Settings';
  IniSectHistory = 'History';
  IDSelectAll = 1001;
  IDCopy = 1002;
  IDSendFile = 1004;
  IDDumpFile = 1005;
  IDClear = 1006;
  IDAbout = 1008;
  IDSNowhere = 1020;
  IDSIniFile = 1021;
  IDSRegistry = 1022;
  MenuLogTemplate: array[0..8] of PChar = ('1001',
    '&Select All'#9'Ctrl-A',
    '&Copy'#9'Ctrl-C',
    '-',
    'S&end file...'#9'Ctrl-O',
    '&Dump to file...'#9'Ctrl-S',
    'C&lear'#9'Ctrl-N',
    '-',
    '&About...'#9'F1');
  MenuSettingsTemplate: array[0..3] of PChar = ('1020',
    '&Nowhere',
    '&In INI file',
    'In &registry');

var
  MaxHistory: Integer = 10;
  DefaultBitRate: Integer = 6;
  DefaultDataBits: Integer = 3;
  DefaultStopBits: Integer = 0;
  DefaultParity: Integer = 0;
  DefaultFlowCtrl: Integer = Integer(fcNone);
  DefaultSendTextMode: Integer = Integer(tmASCII);
  DefaultRecvTextMode: Integer = 1;
  Accels: array[0..5] of TAccel = (
    (fVirt: FCONTROL or FVIRTKEY; Key: Ord('A'); Cmd: IDSelectAll),
    (fVirt: FCONTROL or FVIRTKEY; Key: Ord('C'); Cmd: IDCopy),
    (fVirt: FCONTROL or FVIRTKEY; Key: Ord('O'); Cmd: IDSendFile),
    (fVirt: FCONTROL or FVIRTKEY; Key: Ord('S'); Cmd: IDDumpFile),
    (fVirt: FCONTROL or FVIRTKEY; Key: Ord('N'); Cmd: IDClear),
    (fVirt: FVIRTKEY; Key: VK_F1; Cmd: IDAbout));

constructor TMainForm.Create;
begin
  inherited Create(nil, 'VS Terminal');
  FLogUpdateState := false;
  OnDestroy := FormDestroy;
  OnProcessMsg := FormProcessMsg;
  SetSize(600, 400);
  Position := poScreenCenter;
  ReceiveConverter := TReceiveConverter.Create;
  ReceiveConverter.OnConvert := ReceiveConverterConvert;
  CBSend := TComboBoxEx.Create(Self, csDropDown);
  CBSend.Hint := 'Text to send';
  CBSend.ShowHint := true;
  CBSend.OnKeyUp := CBSendKeyUp;
  GroupBoxPort := TGroupBox.Create(Self, 'Port Settings');
  GroupBoxPort.SetSize(140, 230);
  CBPort := TComboBoxEx.Create(GroupBoxPort, csDropDownList);
  CBPort.SetBounds(5, 20, 130, CBPort.Height);
  CBPort.Hint := 'Port';
  CBPort.ShowHint := true;
  CBPort.OnDropDown := CBPortDropDown;
  CBBitRate := TComboBoxEx.Create(GroupBoxPort, csDropDownList);
  CBBitRate.SetBounds(5, 50, 130, CBBitRate.Height);
  CBBitRate.Hint := 'Bitrate';
  CBBitRate.ShowHint := true;
  CBBitRate.OnChange := CBBitRateChange;
  CBDataBits := TComboBoxEx.Create(GroupBoxPort, csDropDownList);
  CBDataBits.SetBounds(5, 80, 130, CBDataBits.Height);
  CBDataBits.Hint := 'Data bits';
  CBDataBits.ShowHint := true;
  CBDataBits.OnChange := CBDataBitsChange;
  CBStopBits := TComboBoxEx.Create(GroupBoxPort, csDropDownList);
  CBStopBits.SetBounds(5, 110, 130, CBStopBits.Height);
  CBStopBits.Hint := 'Stop bits';
  CBStopBits.ShowHint := true;
  CBStopBits.OnChange := CBStopBitsChange;
  CBParity := TComboBoxEx.Create(GroupBoxPort, csDropDownList);
  CBParity.SetBounds(5, 140, 130, CBParity.Height);
  CBParity.Hint := 'Parity';
  CBParity.ShowHint := true;
  CBParity.OnChange := CBParityChange;
  CBFlowCtrl := TComboBoxEx.Create(GroupBoxPort, csDropDownList);
  CBFlowCtrl.SetBounds(5, 170, 130, CBFlowCtrl.Height);
  CBFlowCtrl.Hint := 'Flow control';
  CBFlowCtrl.ShowHint := true;
  CBFlowCtrl.OnChange := CBFlowCtrlChange;
  BtnConnect := TButton.Create(GroupBoxPort, 'Connect');
  BtnConnect.SetBounds(5, 200, 130, 25);
  BtnConnect.OnClick := BtnConnectClick;
  GroupBoxText := TGroupBox.Create(Self, 'Text Settings');
  GroupBoxText.SetSize(140, 155);
  Label1 := TLabel.Create(GroupBoxText, 'Receive:');
  Label1.SetBounds(5, 20, 130, 15);
  Label2 := TLabel.Create(GroupBoxText, 'Send:');
  Label2.SetBounds(5, 65, 130, 15);
  CBRecvMode := TComboBoxEx.Create(GroupBoxText, csDropDownList);
  CBRecvMode.SetBounds(5, 35, 130, CBRecvMode.Height);
  CBRecvMode.OnChange := CBRecvModeChange;
  CBSendMode := TComboBoxEx.Create(GroupBoxText, csDropDownList);
  CBSendMode.SetBounds(5, 80, 130, CBSendMode.Height);
  CBShowCaps := TCheckBox.Create(GroupBoxText, 'Captions');
  CBShowCaps.SetBounds(5, 110, 130, CBShowCaps.Height);
  CBShowCaps.OnClick := CBShowCapsClick;
  CBMute := TCheckBox.Create(GroupBoxText, 'Mute on file transfer');
  CBMute.SetBounds(5, 130, 130, CBMute.Height);
  BtnTogglePanels := TButton.Create(Self, '>');
  BtnTogglePanels.Width := 12;
  BtnTogglePanels.Flat := true;
  BtnTogglePanels.OnClick := BtnTogglePanelsClick;
  MenuLog := TMenu.Create(Self, false, MenuLogTemplate);
  MenuSettings := TMenu.Create(Self, false, MenuSettingsTemplate);
  InsertMenu(MenuLog.Handle, IDAbout, MF_BYCOMMAND or MF_POPUP, MenuSettings.Handle, 'S&tore settings');
  AccelTable := CreateAcceleratorTable(Accels, Length(Accels));
  RecvTimer := TTimer.CreateEx(50, false);
  RecvTimer.OnTimer := RecvTimerTimer;
  TermLog := TTermLog.Create(Self);
  TermLog.SetPosition(5, 5);
  TermLog.OnMouseUp := TermLogMouseUp;
  Height := Height - ClientHeight + GroupBoxPort.Height + GroupBoxText.Height + 15;
  MinHeight := Height;
  MinWidth := GroupBoxPort.Width + 100;
  CBPortDropDown(CBPort);
  if CBPort.ItemCount > 0 then
    CBPort.ItemIndex := 0;
  LoadSettings;
  FillComboBox(CBBitRate, BitRatesList, DefaultBitRate);
  FillComboBox(CBDataBits, DataBitsList, DefaultDataBits);
  FillComboBox(CBStopBits, StopBitsList, DefaultStopBits);
  FillComboBox(CBParity, ParityList, DefaultParity);
  FillComboBox(CBFlowCtrl, FlowCtrlList, DefaultFlowCtrl);
  FillComboBox(CBSendMode, SendTextModeList, DefaultSendTextMode);
  FillComboBox(CBRecvMode, RecvTextModeList, DefaultRecvTextMode);
end;

procedure TMainForm.BtnConnectClick(Sender: TObject);
begin
  if Assigned(COMPort)
    then Disconnect
    else Connect;
end;

procedure TMainForm.BtnTogglePanelsClick(Sender: TObject);
const
  ToggleCaptions: array[Boolean] of Char = ('<', '>');
begin
  GroupBoxPort.Visible := not GroupBoxPort.Visible;
  GroupBoxText.Visible := GroupBoxPort.Visible;
  BtnTogglePanels.Caption := ToggleCaptions[GroupBoxPort.Visible];
  Perform(WM_SIZE, 0, 0);
end;

procedure TMainForm.CBBitRateChange(Sender: TObject);
var
  Bitrate: string;
begin
  if CBBitRate.ItemIndex = CBBitRate.ItemCount - 1 then
  begin
    Bitrate := CBBitRate.TagEx;
    if InputQuery(Handle, Caption, 'Bitrate:', Bitrate) then
      CBBitRate.TagEx := Bitrate
    else
      Exit;
  end;
  if Assigned(COMPort) then
    COMPort.BitRate := GetComboValue(CBBitRate);
end;

procedure TMainForm.CBDataBitsChange(Sender: TObject);
begin
  if Assigned(COMPort) then
    COMPort.DataBits := GetComboValue(Sender as TComboBoxEx);
end;

procedure TMainForm.CBFlowCtrlChange(Sender: TObject);
begin
  if Assigned(COMPort) then
    COMPort.FlowControl := TFlowControl(GetComboValue(Sender as TComboBoxEx));
end;

procedure TMainForm.CBParityChange(Sender: TObject);
begin
  if Assigned(COMPort) then
    COMPort.Parity := GetComboValue(Sender as TComboBoxEx);
end;

procedure TMainForm.CBPortDropDown(Sender: TObject);
var
  CurPort, i: Integer;
  Ports: TCOMPorts;
begin
  CurPort := GetComboValue(CBPort);
  EnumCOMPorts(Ports);
  CBPort.Clear;
  for i := 0 to High(Ports) do
    CBPort.DataAdd(Ports[i].Name, Ports[i].Index);
  if CurPort <> 0 then
    for i := 0 to CBPort.ItemCount - 1 do
      if CBPort.Data[i] = CurPort then
      begin
        CBPort.ItemIndex := i;
        Break;
      end;
end;

procedure TMainForm.CBRecvModeChange(Sender: TObject);
begin
  ReceiveConverter.Format := TTextMode(GetComboValue(Sender as TComboBoxEx));
end;

procedure TMainForm.CBSendKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  i: Integer;
  List: TStringList;
  S: string;
begin
  if Key = VK_RETURN then
  begin
    {$IFNDEF DEBUG_LOOPBACK}
    if not Assigned(COMPort) then Exit;
    {$ENDIF}
    S := CBSend.Text;
    CBSend.Text := '';
    TermLog.Add(S, CaptionSend, clGreen, Now);
    {$IFDEF DEBUG_LOOPBACK}
    if not Assigned(COMPort) then
    begin
      SetLogUpdateState(true);
      ReceiveConverter.Convert(TransmitConvert(S, TTextMode(GetComboValue(CBSendMode))));
      ReceiveConverter.Flush;
      SetLogUpdateState(false);
    end
    else
    {$ENDIF}
    COMPort.Write(TransmitConvert(S, TTextMode(GetComboValue(CBSendMode))));
    if Trim(S) = '' then Exit;
    List := TStringList.Create;
    for i := 0 to CBSend.ItemCount - 1 do
      List.Add(CBSend.Items[i]);
    List.Insert(0, S);
    S := Trim(S);
    for i := List.Count - 1 downto 1 do
      if Trim(List[i]) = S then
        List.Delete(i);
    CBSend.Clear;
    for i := 0 to Min(List.Count - 1, MaxHistory) do
      CBSend.ItemAdd(List[i]);
  end
  else if Key = VK_ESCAPE then
    CBSend.Text := '';
end;

procedure TMainForm.CBStopBitsChange(Sender: TObject);
begin
  if Assigned(COMPort) then
    COMPort.StopBits := GetComboValue(Sender as TComboBoxEx);
end;

procedure TMainForm.CBShowCapsClick(Sender: TObject);
begin
  TermLog.ShowCaptions := CBShowCaps.Checked;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  DestroyAcceleratorTable(AccelTable);
  if Assigned(COMPort) then
    Disconnect;
  ReceiveConverter.Free;
  FDumpFile.Free;
  SaveSettings;
end;

function TMainForm.FormProcessMsg(var Msg: TMsg): Boolean;
begin
  Result := TranslateAccelerator(Handle, AccelTable, Msg) <> 0;
end;

procedure TMainForm.MIAboutClick(Sender: TObject);
var
  Version: TOSVersionInfo;
  MsgBoxParamsW: TMsgBoxParamsW;
  MsgBoxParamsA: TMsgBoxParamsA;
begin
  Version.dwOSVersionInfoSize := SizeOf(TOSVersionInfo);
  GetVersionEx(Version);
  if Version.dwPlatformId = VER_PLATFORM_WIN32_NT then
  begin
    FillChar(MsgBoxParamsW, SizeOf(MsgBoxParamsW), #0);
    with MsgBoxParamsW do
    begin
      cbSize := SizeOf(MsgBoxParamsW);
      hwndOwner := Handle;
      hInstance := SysInit.hInstance;
      lpszText  := AboutText;
      lpszCaption := PWideChar(WideString(AboutCaption+Caption));
      lpszIcon := AboutIcon;
      dwStyle := MB_USERICON;
    end;
    MessageBoxIndirectW(MsgBoxParamsW);
  end
  else begin
    FillChar(MsgBoxParamsA, SizeOf(MsgBoxParamsA), #0);
    with MsgBoxParamsA do
    begin
      cbSize := SizeOf(MsgBoxParamsA);
      hwndOwner := Handle;
      hInstance := SysInit.hInstance;
      lpszText  := AboutText;
      lpszCaption := PAnsiChar(AboutCaption+Caption);
      lpszIcon := AboutIcon;
      dwStyle := MB_USERICON;
    end;
    MessageBoxIndirectA(MsgBoxParamsA);
  end;
end;

procedure TMainForm.MIClearClick(Sender: TObject);
begin
  TermLog.Text := '';
end;

procedure TMainForm.MICopyClick(Sender: TObject);
begin
  TermLog.Perform(WM_COPY, 0, 0);
end;

procedure TMainForm.MIDumpFileClick(Sender: TObject);
var
  FileName: string;
begin
  if Assigned(FDumpFile) then
    FreeAndNil(FDumpFile)
  else if OpenSaveDialog(Handle, false, '', '', 'All files|*.*', '', 0, OFN_OVERWRITEPROMPT, FileName) then
    FDumpFile := TFileStream.Create(FileName, fmCreate);
end;

procedure TMainForm.MISelectAllClick(Sender: TObject);
begin
  TermLog.Perform(EM_SETSEL, 0, -1);
end;

procedure TMainForm.MISendFileClick(Sender: TObject);
var
  FileName: string;
  F: TFileStream;
  Buf: array[0..63] of Byte;
  Len, Done: Integer;
begin
  if not Assigned(COMPort) or
     not OpenSaveDialog(Handle, true, '', '', 'All files|*.*', '', 0, OFN_FILEMUSTEXIST, FileName) or
     not FileExists(FileName)
       then Exit;
  F := TFileStream.Create(FileName, fmOpenRead);
  try
    TermLog.Add('File "' + FileName + '"', CaptionSend, clNavy, Now);
    if CBMute.Checked then
      ReceiveConverter.Format := tmDisable;
    while F.Position < F.Size do
    begin
      Len := F.Read(Buf[0], Length(Buf));
      Done := 0;
      while Done < Len do
        Done := Done + COMPort.Write(Buf[Done], Len - Done);
      ProcessMessages;
    end;
    TermLog.Add('File "' + FileName + '" sent', CaptionSend, clNavy, Now);
  finally
    if CBMute.Checked then
      CBRecvModeChange(CBRecvMode);
    FreeAndNil(F);
  end;
end;

procedure TMainForm.MIStoreSettingsClick(Sender: TObject; Source: TSettingsSource);
var
  Settings: TSettings;
begin
  Settings := GetSettings;
  try
    Settings.Source := Source;
  finally
    FreeAndNil(Settings);
  end;
end;

procedure TMainForm.ReceiveConverterConvert(Sender: TObject; const Data: string);
begin
  TermLog.Add(Data, CaptionRecv, clMaroon, Now);
  FLogUpdated := true;
end;

procedure TMainForm.RecvTimerTimer(Sender: TObject);
const
  BufferSize = 256;
var
  Buffer: string;
begin
  if not Assigned(COMPort) then Exit;
  SetLogUpdateState(true);
  repeat
    SetLength(Buffer, BufferSize);
    SetLength(Buffer, COMPort.Read(Buffer[1], BufferSize));
    if Assigned(FDumpFile) then FDumpFile.Write(Buffer[1], Length(Buffer));
    ReceiveConverter.Convert(Buffer);
  until Length(Buffer) < BufferSize;
  if Length(Buffer) = 0 then ReceiveConverter.Flush;
  SetLogUpdateState(false);
end;

procedure TMainForm.TermLogMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
const
  MenuCheck: array[Boolean] of UINT = (MF_UNCHECKED, MF_CHECKED);
  MenuEnable: array[Boolean] of UINT = (MF_GRAYED, MF_ENABLED);
  DumpName: array[Boolean] of PChar = ('&Dump to file...'#9'Ctrl-S', 'S&top dumping'#9'Ctrl-S');
var
  Settings: TSettings;
begin
  if Button <> mbRight then Exit;
  Settings := GetSettings;
  try
    CheckMenuItem(MenuSettings.Handle, IDSNowhere, MenuCheck[Settings.Source = ssNone] or MF_BYCOMMAND);
    CheckMenuItem(MenuSettings.Handle, IDSIniFile, MenuCheck[Settings.Source = ssIni] or MF_BYCOMMAND);
    CheckMenuItem(MenuSettings.Handle, IDSRegistry, MenuCheck[Settings.Source = ssRegistry] or MF_BYCOMMAND);
    EnableMenuItem(MenuLog.Handle, IDSendFile, MenuEnable[Assigned(COMPort)] or MF_BYCOMMAND);
    ModifyMenu(MenuLog.Handle, IDDumpFile, MF_BYCOMMAND or MF_STRING, IDDumpFile, DumpName[Assigned(FDumpFile)]);
    MenuLog.Popup(Left + X, Top + Y);
  finally
    FreeAndNil(Settings);
  end;
end;

procedure TMainForm.Connect;
begin
  if not Assigned(COMPort) and (GetComboValue(CBPort) > 0) then
    try
      COMPort := TCOMPort.Create(GetComboValue(CBPort), 4096);
      COMPort.ReadImmediately := true;
      COMPort.BitRate := GetComboValue(CBBitRate);
      COMPort.DataBits := GetComboValue(CBDataBits);
      COMPort.StopBits := GetComboValue(CBStopBits);
      COMPort.Parity := GetComboValue(CBParity);
      COMPort.FlowControl := TFlowControl(GetComboValue(CBFlowCtrl));
      SetControlsState(true);
    except
      on E: Exception do
      begin
        MessageBox(Handle, PChar(E.Message), PChar(Caption), MB_ICONERROR);
        FreeAndNil(COMPort);
        Exit;
      end;
    end;
end;

procedure TMainForm.Disconnect;
begin
  if Assigned(COMPort) then
  begin
    COMPort.Purge;
    ReceiveConverter.Flush(true);
    FreeAndNil(COMPort);
    SetControlsState(false);
  end;
end;

procedure TMainForm.SetControlsState(Connected: Boolean);
const
  BtnConnectCaptions: array[Boolean] of string = ('Connect', 'Disconnect');
begin
  CBPort.Enabled := not Connected;
  RecvTimer.Enabled := Connected;
  BtnConnect.Caption := BtnConnectCaptions[Connected];
end;

procedure TMainForm.SetLogUpdateState(IsUpdating: Boolean);
begin
  if IsUpdating = FLogUpdateState then Exit;
  FLogUpdateState := IsUpdating;
  if IsUpdating then
  begin
    TermLog.BeginUpdate;
    FLogUpdated := false;
  end
  else begin
    TermLog.EndUpdate;
    if FLogUpdated then TermLog.Refresh;
  end;
end;

procedure TMainForm.FillComboBox(Combo: TComboBoxEx; const Settings: array of TSettingsItem; DefItem: Integer = 0);
var
  i: Integer;
begin
  Combo.BeginUpdate;
  Combo.Clear;
  for i := Low(Settings) to High(Settings) do
    Combo.DataAdd(Settings[i].Name, Settings[i].Value);
  Combo.EndUpdate;
  if (DefItem >= 0) and (DefItem < Combo.ItemCount) then
  begin
    Combo.ItemIndex := DefItem;
    if Assigned(Combo.OnChange) then Combo.OnChange(Combo);
  end;
end;

function TMainForm.GetComboValue(Combo: TComboBoxEx; Index: Integer = -MaxInt): Integer;
begin
  if Index = -MaxInt then
    Index := Combo.ItemIndex;
  if (Index >= 0) and (Index < Combo.ItemCount) then
  begin
    Result := Combo.Data[Index];
    if Result = -1 then Result := StrToInt(Combo.TagEx);
  end
    else Result := 0;
end;

function TMainForm.GetSettings: TSettings;
begin
  Result := TSettings.Create(AppName);
end;

procedure TMainForm.LoadSettings;
var
  Settings: TSettings;
  i, Port: Integer;
begin
  Settings := GetSettings;
  try
    Settings.RestoreFormState(IniSectMainForm, Self);
    MaxHistory := Settings.ReadInteger(IniSectSettings, 'MaxHistory', MaxHistory);
    DefaultBitRate := Settings.ReadInteger(IniSectSettings, 'BitRate', DefaultBitRate);
    DefaultDataBits := Settings.ReadInteger(IniSectSettings, 'DataBits', DefaultDataBits);
    DefaultStopBits := Settings.ReadInteger(IniSectSettings, 'StopBits', DefaultStopBits);
    DefaultParity := Settings.ReadInteger(IniSectSettings, 'Parity', DefaultParity);
    DefaultFlowCtrl := Settings.ReadInteger(IniSectSettings, 'FlowCtrl', DefaultFlowCtrl);
    DefaultSendTextMode := Settings.ReadInteger(IniSectSettings, 'SendMode', DefaultSendTextMode);
    DefaultRecvTextMode := Settings.ReadInteger(IniSectSettings, 'RecvMode', DefaultRecvTextMode);
    CBShowCaps.Checked := Settings.ReadBool(IniSectSettings, 'ShowCaps', false);
    CBShowCapsClick(CBShowCaps);
    CBMute.Checked := Settings.ReadBool(IniSectSettings, 'Mute', false);
    CBBitRate.TagEx := Settings.ReadString(IniSectSettings, 'CustomBitRate', '0');
    for i := 0 to MaxHistory do
      if Settings.ValueExists(IniSectHistory, IntToStr(i)) then
        CBSend.ItemAdd(Settings.ReadString(IniSectHistory, IntToStr(i), ''));
    Port := Settings.ReadInteger(IniSectSettings, 'Port', 1);
    for i := 0 to CBPort.ItemCount - 1 do
      if GetComboValue(CBPort, i) = Port then
      begin
        CBPort.ItemIndex := i;
        Break;
      end;
  finally
    FreeAndNil(Settings);
  end;
end;

procedure TMainForm.SaveSettings;
var
  Settings: TSettings;
  i: Integer;
begin
  Settings := GetSettings;
  try
    if Settings.Source = ssNone then Exit;
    Settings.SaveFormState(IniSectMainForm, Self);
    Settings.WriteInteger(IniSectSettings, 'Port', GetComboValue(CBPort));
    Settings.WriteInteger(IniSectSettings, 'BitRate', CBBitRate.ItemIndex);
    Settings.WriteInteger(IniSectSettings, 'DataBits', CBDataBits.ItemIndex);
    Settings.WriteInteger(IniSectSettings, 'StopBits', CBStopBits.ItemIndex);
    Settings.WriteInteger(IniSectSettings, 'Parity', CBParity.ItemIndex);
    Settings.WriteInteger(IniSectSettings, 'FlowCtrl', CBFlowCtrl.ItemIndex);
    Settings.WriteInteger(IniSectSettings, 'SendMode', CBSendMode.ItemIndex);
    Settings.WriteInteger(IniSectSettings, 'RecvMode', CBRecvMode.ItemIndex);
    Settings.WriteBool(IniSectSettings, 'ShowCaps', CBShowCaps.Checked);
    Settings.WriteBool(IniSectSettings, 'Mute', CBMute.Checked);
    Settings.WriteString(IniSectSettings, 'CustomBitRate', CBBitRate.TagEx);
    Settings.EraseSection(IniSectHistory);
    for i := 0 to CBSend.ItemCount - 1 do
      Settings.WriteString(IniSectHistory, IntToStr(i), CBSend.Items[i]);
  finally
    FreeAndNil(Settings);
  end;
end;

procedure TMainForm.WMCommand(var Msg: TWMCommand);
begin
  if Msg.NotifyCode in [0, 1] then
    case Msg.ItemID of
      IDSelectAll: MISelectAllClick(MenuLog);
      IDCopy: MICopyClick(MenuLog);
      IDSendFile: MISendFileClick(MenuLog);
      IDDumpFile: MIDumpFileClick(MenuLog);
      IDClear: MIClearClick(MenuLog);
      IDAbout: MIAboutClick(MenuLog);
      IDSNowhere: MIStoreSettingsClick(MenuSettings, ssNone);
      IDSIniFile: MIStoreSettingsClick(MenuSettings, ssIni);
      IDSRegistry: MIStoreSettingsClick(MenuSettings, ssRegistry);
    end;
end;

procedure TMainForm.WMSize(var Msg: TWMSize);
var
  Cur: TWinControl;
begin
  if not Assigned(TermLog) then Exit;
  if GroupBoxPort.Visible then
  begin
    GroupBoxPort.SetPosition(ClientWidth - GroupBoxPort.Width - 5, 5);
    GroupBoxText.SetPosition(GroupBoxPort.Left, GroupBoxPort.Height + 10);
    BtnTogglePanels.SetBounds(GroupBoxPort.Left - BtnTogglePanels.Width - 2, 0, BtnTogglePanels.Width, ClientHeight);
  end
    else BtnTogglePanels.SetBounds(ClientWidth - BtnTogglePanels.Width, 0, BtnTogglePanels.Width, ClientHeight);
  CBSend.SetBounds(5, ClientHeight - CBSend.Height - 5, BtnTogglePanels.Left - 7, CBSend.Height);
  TermLog.SetSize(CBSend.Width, CBSend.Top - 10);
  Cur := NextControl;
  while Assigned(Cur) do
  begin
    Cur.Invalidate;
    UpdateWindow(Cur.Handle);
    Cur := Cur.NextControl;
  end;
end;

procedure TMainForm.WMSizing(var Msg: TWMMoving);
begin
  with Msg do
  begin
    if DragRect.Right - DragRect.Left < MinWidth then
      if (Edge = WMSZ_LEFT) or (Edge = WMSZ_TOPLEFT) or (Edge = WMSZ_BOTTOMLEFT)
        then DragRect.Left := DragRect.Right - MinWidth
        else DragRect.Right := DragRect.Left + MinWidth;
    if DragRect.Bottom - DragRect.Top < MinHeight then
      if (Edge = WMSZ_TOP) or (Edge = WMSZ_TOPLEFT) or (Edge = WMSZ_TOPRIGHT)
        then DragRect.Top := DragRect.Bottom - MinHeight
        else DragRect.Bottom := DragRect.Top + MinHeight;
  end;
end;

procedure TMainForm.WMSetFocus(var Msg: TWMSetFocus);
begin
  CBSend.SetFocus;
end;

end.

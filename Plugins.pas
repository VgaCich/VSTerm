unit Plugins;

interface

uses Windows, AvL, avlUtils, avlSettings, PluginAPI;

type
  TPluginsManager = class
  private
    FTerminal: TTerminal;
    FPlugins: array of record
      Plugin: PPlugin;
      LibInst: HMODULE;
      Enabled: Boolean;
    end;
    function GetCount: Integer;
    function GetEnabled(Index: Cardinal): Boolean;
    function GetName(Index: Cardinal): string;
    procedure SetEnabled(Index: Cardinal; const Value: Boolean);
  public
    constructor Create(Handle: THandle);
    destructor Destroy; override;
    procedure LoadPlugin(const FileName: string);
    procedure LoadPlugins;
    procedure LoadSettings(Settings: TSettings);
    procedure SaveSettings(Settings: TSettings);
    procedure Configure(Index: Cardinal);
    function OnReceive(Data: string): string;
    function OnSend(Data: string): string;
    property Enabled[Index: Cardinal]: Boolean read GetEnabled write SetEnabled;
    property Name[Index: Cardinal]: string read GetName;
    property Count: Integer read GetCount;
  end;

implementation

uses
  MainForm;

var
  PluginsManager: TPluginsManager = nil;

const
  IniSectPlugins = 'Plugins';

function FilterName(const Name: string): string;
var
  i: Integer;
begin
  Result := Name;
  for i := 1 to Length(Result) do
    if Result[i] in ['[', ']', ';', '=', ' '] then
      Result[i] := '_';
  if Result = '' then
    Result := 'Unnamed';
end;

function SetEnabled(Plugin: PPlugin; Enable: LongBool): LongBool; stdcall;
var
  i: Integer;
begin
  Result := false;
  if not Assigned(PluginsManager) then Exit;
  with PluginsManager do
    for i := 0 to High(FPlugins) do
      if FPlugins[i].Plugin = Plugin then
      begin
        Result := Enabled[i];
        Enabled[i] := Enable;
        Break;
      end;
end;

function GetOption(const Section, Key: PChar): PBuffer; stdcall;
var
  Settings: TSettings;
begin
  Result := nil;
  Settings := GetSettings;
  try
    Result := CreateBuffer(Settings.ReadString(string(Section), string(Key), ''));
  finally
    Settings.Free;
  end;
end;

procedure SetOption(const Section, Key, Value: PChar); stdcall;
var
  Settings: TSettings;
begin
  Settings := GetSettings;
  try
    Settings.WriteString(string(Section), string(Key), string(Value));
  finally
    Settings.Free;
  end;
end;

procedure AddToLog(const Text, Caption: PChar; Color: Integer); stdcall;
begin
  if not Assigned(FormMain) then Exit;
  FormMain.TermLog.BeginUpdate;
  FormMain.TermLog.Add(string(Text), string(Caption), Color, Now);
  FormMain.TermLog.EndUpdate;
  FormMain.TermLog.Refresh;
end;

{ TPluginsManager }

constructor TPluginsManager.Create(Handle: THandle);
begin
  FTerminal.Version := TerminalAPIVersion;
  FTerminal.WinHandle := Handle;
  FTerminal.SetEnabled := Plugins.SetEnabled;
  FTerminal.GetOption := GetOption;
  FTerminal.SetOption := SetOption;
  FTerminal.AddToLog := AddToLog;
  PluginsManager := Self;
end;

destructor TPluginsManager.Destroy;
var
  i: Integer;
begin
  for i := 0 to High(FPlugins) do
  begin
    FPlugins[i].Plugin.Free(FPlugins[i].Plugin);
    FreeLibrary(FPlugins[i].LibInst);
  end;
  Finalize(FPlugins);
  if PluginsManager = Self then
    PluginsManager := nil;
  inherited;
end;

procedure TPluginsManager.LoadPlugin(const FileName: string);
var
  Lib: HMODULE;
  CreatePlugin: TCreateVSTermPlugin;
  Plug: PPlugin;
begin
  Lib := LoadLibrary(PChar(FileName));
  if Lib = 0 then Exit;
  try
    CreatePlugin := GetProcAddress(Lib, CreateVSTermPluginFuncName);
    if not Assigned(CreatePlugin) then Exit;
    Plug := CreatePlugin(@FTerminal);
    if not Assigned(Plug) then Exit;
    if Plug.Version < PluginAPIVersion then
    begin
      Plug.Free(Plug);
      Exit;
    end;
    SetLength(FPlugins, Length(FPlugins) + 1);
    with FPlugins[High(FPlugins)] do
    begin
      Plugin := Plug;
      LibInst := Lib;
      Enabled := false; //TODO: Read from settings?
    end;
    Lib := 0;
  finally
    if Lib <> 0 then
      FreeLibrary(Lib);
  end;
end;

procedure TPluginsManager.LoadPlugins;
var
  Search: TSearchRec;
begin
  if FindFirst(AddTrailingBackslash(ExePath) + '*.dll', faAnyFile and not faDirectory, Search) = 0 then
    repeat
      LoadPlugin(AddTrailingBackslash(ExePath) + Search.Name);
    until FindNext(Search) <> 0;
  FindClose(Search);
end;

procedure TPluginsManager.LoadSettings(Settings: TSettings);
var
  i: Integer;
begin
  for i := 0 to High(FPlugins) do
    with FPlugins[i] do
      Enabled := Settings.ReadBool(IniSectPlugins, FilterName(string(Plugin.Name)), false);
end;

procedure TPluginsManager.SaveSettings(Settings: TSettings);
var
  i: Integer;
begin
  for i := 0 to High(FPlugins) do
    with FPlugins[i] do
      Settings.WriteBool(IniSectPlugins, FilterName(string(Plugin.Name)), Enabled);
end;

procedure TPluginsManager.Configure(Index: Cardinal);
begin
  if Index > High(FPlugins) then Exit;
  if Assigned(FPlugins[Index].Plugin.Configure) then
    FPlugins[Index].Plugin.Configure(FPlugins[Index].Plugin)
  else
    Enabled[Index] := not Enabled[Index];
end;

function TPluginsManager.OnReceive(Data: string): string;
var
  i: Integer;
  F: Boolean;
  Buf, Buf2: PBuffer;
begin
  Result := Data;
  F := false;
  for i := 0 to High(FPlugins) do
    if (FPlugins[i].Enabled) and Assigned(FPlugins[i].Plugin.OnReceive) then
    begin
      if not F then
      begin
        Buf := CreateBuffer(Data);
        F := true;
      end;
      Buf2 := FPlugins[i].Plugin.OnReceive(FPlugins[i].Plugin, Buf.Data, Buf.Len);
      Buf.Free(Buf);
      Buf := Buf2;
      if not Assigned(Buf) then Break;
    end;
  if F then
  begin
    Result := BufferToStr(Buf);
    if Assigned(Buf) then
      Buf.Free(Buf);
  end;
end;

function TPluginsManager.OnSend(Data: string): string;
var
  i: Integer;
  F: Boolean;
  Buf, Buf2: PBuffer;
begin
  Result := Data;
  F := false;
  for i := 0 to High(FPlugins) do
    if (FPlugins[i].Enabled) and Assigned(FPlugins[i].Plugin.OnSend) then
    begin
      if not F then
      begin
        Buf := CreateBuffer(Data);
        F := true;
      end;
      Buf2 := FPlugins[i].Plugin.OnSend(FPlugins[i].Plugin, Buf.Data, Buf.Len);
      Buf.Free(Buf);
      Buf := Buf2;
      if not Assigned(Buf) then Break;
    end;
  if F then
  begin
    Result := BufferToStr(Buf);
    if Assigned(Buf) then
      Buf.Free(Buf);
  end;
end;

function TPluginsManager.GetCount: Integer;
begin
  Result := Length(FPlugins);
end;

function TPluginsManager.GetEnabled(Index: Cardinal): Boolean;
begin
  Result := false;
  if Index > High(FPlugins) then Exit;
  Result := FPlugins[Index].Enabled;
end;

function TPluginsManager.GetName(Index: Cardinal): string;
begin
  Result := '';
  if Index > High(FPlugins) then Exit;
  Result := FilterName(string(FPlugins[Index].Plugin.Name));
end;

procedure TPluginsManager.SetEnabled(Index: Cardinal; const Value: Boolean);
begin
  if Index > High(FPlugins) then Exit;
  FPlugins[Index].Enabled := Value;
end;

end.

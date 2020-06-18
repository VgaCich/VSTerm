unit PluginAPI;

interface

const
  TerminalAPIVersion = 1;
  PluginAPIVersion = 1;
  CreateVSTermPluginFuncName = 'CreateVSTermPlugin';

type
  PTerminal = ^TTerminal;
  PPlugin = ^TPlugin;
  PBuffer = ^TBuffer;
  TBuffer = record //For returning (string) data from functions
    Data: PChar; //Data
    Len: Integer; //Data length
    Free: procedure(Self: PBuffer); stdcall; //Destructor
  end;
  TTerminal = record //API, provided by host
    Version: Integer; //API version, check to be no less than TerminalAPIVersion
    WinHandle: THandle; //Host main window handle
    SetEnabled: function(Plugin: PPlugin; Enable: LongBool): LongBool; stdcall; //Enadle or disable plugin
    GetOption: function(const Section, Key: PChar): PBuffer; stdcall; //Get option from host's settings store
    SetOption: procedure(const Section, Key, Value: PChar); stdcall; //Write option to host's settings store
    AddToLog: procedure(const Text, Caption: PChar; Color: Integer); stdcall; //Write line to terminal log
  end;
  TPlugin = record //Plugin instance
    Version: Integer; //Set to PluginAPIVersion
    Name: PChar; //Plugin name
    Free: procedure(Self: PPlugin); stdcall; //Plugin destructor. Mandatory.
    Configure: procedure(Self: PPlugin); stdcall; //Configure plugin (called when plugin's item in menu clicked). Optional.
    OnReceive: function(Self: PPlugin; const Data: PChar; Len: Integer): PBuffer; stdcall; //Filter received data. Optional.
    OnSend: function(Self: PPlugin; const Data: PChar; Len: Integer): PBuffer; stdcall; //Filter sent data. Optional.
  end;
  TCreateVSTermPlugin = function(Terminal: PTerminal): PPlugin; stdcall;

function CreateBuffer(const Str: string): PBuffer;
function BufferToStr(const Buffer: PBuffer): string;

implementation

procedure FreeBuffer(Self: PBuffer); stdcall;
begin
  FreeMem(Self.Data, Self.Len);
  Dispose(Self);
end;

function CreateBuffer(const Str: string): PBuffer;
begin
  New(Result);
  with Result^ do
  begin
    Len := Length(Str);
    GetMem(Data, Len);
    Move(Str[1], Data^, Len);
    Free := FreeBuffer;
  end;
end;

function BufferToStr(const Buffer: PBuffer): string;
begin
  Result := '';
  if not Assigned(Buffer) then Exit;
  SetLength(Result, Buffer.Len);
  Move(Buffer.Data^, Result[1], Buffer.Len);
end;

end.

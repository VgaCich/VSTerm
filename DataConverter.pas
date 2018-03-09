unit DataConverter;

interface

uses
  AvL, avlUtils;

type
  TTextMode = (tmDisable, tmASCII, tmASCIIC, tmASCIILF, tmASCIICR, tmASCIICRLF, tmASCIIZ, tmHex, tmInt8, tmInt16, tmInt32);
  TOnConvert = procedure(Sender: TObject; const ConvData: string) of object;
  TConverter = class
  protected
    FResult: string;
  public
    function Convert(const Data: string; Partial: Boolean = false): Integer; virtual; abstract;
    property Result: string read FResult;
  end;
  TReceiveConverter = class
  private
    FConverter: TConverter;
    FDataBuffer: string;
    FFormat: TTextMode;
    FOnConvert: TOnConvert;
    procedure SetFormat(Value: TTextMode);
  public
    constructor Create;
    procedure Convert(const Data: string);
    procedure Flush(Forced: Boolean = false);
    property Format: TTextMode read FFormat write SetFormat;
    property OnConvert: TOnConvert read FOnConvert write FOnConvert;
  end;

function TransmitConvert(const S: string; Format: TTextMode): string;

implementation

function HexChar(c: Char): Byte;
begin
  case c of
    '0'..'9':  Result := Byte(c) - Byte('0');
    'a'..'f':  Result := (Byte(c) - Byte('a')) + 10;
    'A'..'F':  Result := (Byte(c) - Byte('A')) + 10;
  else
    Result := 0;
  end;
end;

function ParseBackslash(const S: string): string;
const
  Codes: array[0..11] of record Code, Replace: Char end = (
    (Code: '\'; Replace: '\'),
    (Code: '"'; Replace: '"'),
    (Code: ''''; Replace: ''''),
    (Code: '?'; Replace: '?'),
    (Code: 'n'; Replace: #10),
    (Code: 'r'; Replace: #13),
    (Code: 'b'; Replace: #8),
    (Code: 't'; Replace: #9),
    (Code: 'f'; Replace: #12),
    (Code: 'a'; Replace: #7),
    (Code: 'v'; Replace: #11),
    (Code: 'e'; Replace: #27));
var
  i, j: Integer;
  c: Byte;
begin
  Result := '';
  i := 1;
  while i <= Length(S) do
  begin
    if (S[i] = '\') and (i < Length(S)) then
    begin
      case S[i + 1] of
        '\': Result := Result + '\';
        '"': Result := Result + '"';
        '''': Result := Result + '''';
        '?': Result := Result + '?';
        'a': Result := Result + #7;
        'b': Result := Result + #8;
        't': Result := Result + #9;
        'n': Result := Result + #10;
        'v': Result := Result + #11;
        'f': Result := Result + #12;
        'r': Result := Result + #13;
        'e': Result := Result + #27;
        'x': if i < Length(S) - 2 then
        begin
          Result := Result + Chr((HexChar(S[i + 2]) shl 4) or HexChar(S[i + 3]));
          Inc(i, 2);
        end;
        '0'..'7': begin
          c := 0;
          for j := 0 to 2 do
            if (i + 1 <= Length(S)) and (S[i + 1] in ['0' .. '7']) then
            begin
              c := 8 * c + (Byte(S[i + 1]) - Byte('0'));
              Inc(i);
            end
              else Break;
          Result := Result + Chr(c);    
          Dec(i);
        end;
        else Dec(i);
      end;
      Inc(i);
    end
      else Result := Result + S[i];
    Inc(i);
  end;
end;

function TransmitConvert(const S: string; Format: TTextMode): string;
var
  i, Len: Integer;
begin
  case Format of
    tmDisable: Result := '';
    tmASCII: Result := S;
    tmASCIIC: Result := ParseBackslash(S);
    tmASCIILF: Result := S + #10;
    tmASCIICR: Result := S + #13;
    tmASCIICRLF: Result := S + CRLF;
    tmASCIIZ: Result := S + #0;
    tmHex: begin
      Result := S;
      for i := Length(Result) downto 1 do
        if not (Result[i] in ['a'..'f', 'A'..'F', '0'..'9']) then
          Delete(Result, i, 1);
      Len := Length(Result) div 2;
      for i := 1 to Len do
        Result[i] := Chr((HexChar(Result[2 * i - 1]) shl 4) or HexChar(Result[2 * i]));
      SetLength(Result, Len);
    end;
    tmInt8: begin
      SetLength(Result, 1);
      PByte(@Result[1])^ := StrToInt(S);
    end;
    tmInt16: begin
      SetLength(Result, 2);
      PWord(@Result[1])^ := StrToInt(S);
    end;
    tmInt32: begin
      SetLength(Result, 4);
      PCardinal(@Result[1])^ := StrToCar(S);
    end;
  end;
end;

type
  TDisableRecvConverter = class(TConverter)
  public
    function Convert(const Data: string; Partial: Boolean = false): Integer; override;
  end;
  TASCIIRecvConverter = class(TConverter)
  public
    function Convert(const Data: string; Partial: Boolean = false): Integer; override;
  end;
  TIntRecvConverter = class(TConverter)
  private
    FWordSize: Integer;
  public
    constructor Create(WordSize: Integer);
    function Convert(const Data: string; Partial: Boolean = false): Integer; override;
  end;
  THexRecvConverter = class(TConverter)
  public
    function Convert(const Data: string; Partial: Boolean = false): Integer; override;
  end;

{ TDisableRecvConverter }

function TDisableRecvConverter.Convert(const Data: string; Partial: Boolean): Integer;
begin
  Result := 0;
end;

{ TASCIIRecvConverter }

function TASCIIRecvConverter.Convert(const Data: string; Partial: Boolean): Integer;
begin
  FResult := '';
  Result := 1;
  while Result <= Length(Data) do
    if Data[Result] in [#10, #13]
      then Break
      else Inc(Result);
  if (Result <= Length(Data)) or Partial then
  begin
    FResult := Copy(Data, 1, Result - 1);
    if (Result < Length(Data)) and (Data[Result] = #13) and (Data[Result + 1] = #10) then
        Inc(Result);
  end
    else Result := 0;
end;

{ TIntRecvConverter }

function TIntRecvConverter.Convert(const Data: string; Partial: Boolean): Integer;
var
  Temp: Cardinal;
begin
  FResult := '';
  if Length(Data) >= FWordSize then
  begin
    Temp := 0;
    Move(Data[1], Temp, FWordSize);
    Str(Temp, FResult);
    Result := FWordSize;
  end
    else Result := 0;
end;

constructor TIntRecvConverter.Create(WordSize: Integer);
begin
  inherited Create;
  FWordSize := WordSize;
end;

{ THexRecvConverter }

function THexRecvConverter.Convert(const Data: string; Partial: Boolean): Integer;
var
  i: Integer;
begin
  FResult := '';
  if (Length(Data) >= 16) or Partial then
  begin
    Result := Min(Length(Data), 16);
    FResult := StrToHex(Copy(Data, 1, Result));
    while Length(FResult) < 48 do FResult := FResult + ' ';
    for i := 1 to Result do
      if Ord(Data[i]) >= 32 then
        FResult := FResult + Data[i]
      else
        FResult := FResult +'.';
  end
    else Result := 0;
end;

{ TReceiveConverter }

constructor TReceiveConverter.Create;
begin
  inherited;
  Format := tmDisable;
end;

procedure TReceiveConverter.Convert(const Data: string);
var
  Converted: Integer;
begin
  FDataBuffer := FDataBuffer + Data;
  while Length(FDataBuffer) > 0 do
  begin
    Converted := FConverter.Convert(FDataBuffer);
    if Converted = 0 then
      Break
    else
      if Assigned(FOnConvert) then FOnConvert(Self, FConverter.Result);
    Delete(FDataBuffer, 1, Converted);
  end;
end;

procedure TReceiveConverter.SetFormat(Value: TTextMode);
begin
  Flush(true);
  FConverter.Free;
  case Value of
    tmDisable: FConverter := TDisableRecvConverter.Create;
    tmASCII: FConverter := TASCIIRecvConverter.Create;
    tmInt8: FConverter := TIntRecvConverter.Create(1);
    tmInt16: FConverter := TIntRecvConverter.Create(2);
    tmInt32: FConverter := TIntRecvConverter.Create(4);
    tmHex: FConverter := THexRecvConverter.Create;
  end;
end;

procedure TReceiveConverter.Flush(Forced: Boolean);
begin
  if (Length(FDataBuffer) > 0) and Assigned(FConverter) and (FConverter.Convert(FDataBuffer, true) > 0) then
  begin
    if Assigned(FOnConvert) then FOnConvert(Self, FConverter.Result);
    FDataBuffer := '';
  end;
  if Forced then FDataBuffer := '';
end;

end.

unit TermLog;

interface

uses
  Windows, Messages, RichEdit, AvL;

type
  TTermLog = class(TRichEdit)
  private
    FShowCaptions, FUpdated: Boolean;
    function GetCount: Integer;
  public
    constructor Create(AParent: TWinControl);
    procedure Add(Text, Caption: string; Color: TColor; Time: TDateTime);
    procedure Insert(const Line: string; Index: Integer);
    procedure ResetUpdates;
    procedure Refresh;
    property Count: Integer read GetCount;
    property ShowCaptions: Boolean read FShowCaptions write FShowCaptions;
  end;

implementation

procedure TTermLog.Add(Text, Caption: string; Color: TColor; Time: TDateTime);
var
  i: Integer;
  Format: TCharFormat;
begin
  FUpdated := true;
  for i := 1 to Length(Text) do
    if Text[i] in [#$00, #$09, #$0A, #$0B, #$0D, #$AD] then
      Text[i] := #$20;
  ZeroMemory(@Format, SizeOf(Format));
  Format.cbSize := SizeOf(Format);
  Format.dwMask := CFM_COLOR;
  if FShowCaptions then
  begin
    Caption:='['+TimeToStr(Time)+'] '+Caption;
    Insert(Caption + Text, Count);
    SelStart := Perform(EM_LINEINDEX, Count - 1, 0);
    SelLength := Length(Caption);
    Format.crTextColor := ColorToRGB(clGray);
    Perform(EM_SETCHARFORMAT, SCF_SELECTION, LPARAM(@Format));
    SelStart := SelStart + SelLength;
    SelLength := Length(Text);
    Format.crTextColor := ColorToRGB(Color);
    Perform(EM_SETCHARFORMAT, SCF_SELECTION, LPARAM(@Format));
    SelLength := 0;
  end
  else begin
    Insert(Text, Count);
    SelStart := Perform(EM_LINEINDEX, Count - 1, 0);
    SelLength := Length(Text);
    Format.crTextColor := ColorToRGB(Color);
    Perform(EM_SETCHARFORMAT, SCF_SELECTION, LPARAM(@Format));
    SelLength := 0;
  end;
  Perform(EM_SCROLLCARET, 0, 0);
end;

procedure TTermLog.Insert(const Line: string; Index: Integer);
var
  L: Integer;
  Selection: TCharRange;
  Fmt: PChar;
  Str: string;
begin
  FUpdated := true;
  if Index >= 0 then
  begin
    Selection.cpMin := Perform(EM_LINEINDEX, Index, 0);
    if Selection.cpMin >= 0 then
      Fmt := '%s'#13#10
    else begin
      Selection.cpMin := Perform(EM_LINEINDEX, Index - 1, 0);
      if Selection.cpMin < 0 then Exit;
      L := Perform(EM_LINELENGTH, Selection.cpMin, 0);
      if L = 0 then Exit;
      Inc(Selection.cpMin, L);
      Fmt := #13#10'%s';
    end;
    Selection.cpMax := Selection.cpMin;
    Perform(EM_EXSETSEL, 0, Longint(@Selection));
    Str := Format(Fmt, [Line]);
    Perform(EM_REPLACESEL, 0, LongInt(PChar(Str)));
  end;
end;

constructor TTermLog.Create(AParent: TWinControl);
var
  Format: TCharFormat;
begin
  inherited Create(AParent, '');
  ExStyle := ExStyle and not WS_EX_CLIENTEDGE or WS_EX_STATICEDGE;
  MaxLength := -1;
  ReadOnly := true;
  ZeroMemory(@Format, SizeOf(Format));
  Format.cbSize := SizeOf(Format);
  Format.dwMask := CFM_FACE;
  Format.bCharSet := ANSI_CHARSET;
  Format.bPitchAndFamily := FIXED_PITCH;
  Format.szFaceName := 'Courier New';
  Perform(EM_SETCHARFORMAT, 0, LPARAM(@Format));
  FUpdated := true;
end;

function TTermLog.GetCount: Integer;
begin
  Result := Perform(EM_GETLINECOUNT, 0, 0);
  if Perform(EM_LINELENGTH, Perform(EM_LINEINDEX, Result - 1, 0), 0) = 0 then
    Dec(Result);
end;

procedure TTermLog.ResetUpdates;
begin
  FUpdated := false;
end;

procedure TTermLog.Refresh;
begin
  if not FUpdated then Exit;
  Invalidate;
  UpdateWindow(Handle);
end;

end.



program httpsys2websocketserver;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  uWebSocketEchoServer in 'uWebSocketEchoServer.pas';

var
  fEchoServer: TWebSocketEchoServer;
  s: string;
begin
{$WARN SYMBOL_PLATFORM OFF}
  ReportMemoryLeaksOnShutdown := True;
{$WARN SYMBOL_PLATFORM ON}

  try
    fEchoServer := TWebSocketEchoServer.Create;
    try
      Writeln('Server is now running on ws://localhost:8801/');
      Writeln('Press [Enter] to quit');
      repeat
        Readln(s);

        if Pos('close ', s) = 1 then
        begin
          s := Trim(Copy(s, 7, Length(s)));
          fEchoServer.CloseWebSocketId(StrToInt(s), 1001, 'Manual Close!');
        end else if Pos('send ', s) = 1 then
        begin
          s := Trim(Copy(s, 6, Length(s)));
          fEchoServer.SendToWebSocketId(StrToInt(s), 'Manual Message!');
        end;
      until s = '';
    finally
      fEchoServer.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.

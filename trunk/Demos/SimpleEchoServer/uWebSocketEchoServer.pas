unit uWebSocketEchoServer;

interface

uses
  uOSWebSocket,
  uOSWebSocketHandler,
  uOSWebSocketServer,
  uOSHttpSys2WebSocketServer,
  dwsHTTPSysServer,
  dwsWebEnvironment;

type
  TWebSocketEchoServer = class
  private
    fEchoWebSocketHandler: TWebSocketHandler;

    //Handler Control Events
    procedure OnEchoAcceptConnection(aRequest: TWebRequest; aResponse: TWebResponse; var aAccept: Boolean);
    procedure OnEchoConnectWebSocket(const aWebSocket: TWebSocketServer);
    procedure OnEchoDisconnectWebSocket(const aWebSocket: TWebSocketServer);

    //Handler WebSocket Control Events
    procedure OnEchoWebSocketCloseBuffer(const aWebSocket: TWebSocketServer; const aStatus: Cardinal; const aReasonBuffer: Pointer; const aReasonBufferSize: Cardinal);

    //WebSocket Events
    procedure OnEchoWebSocketOpen(const aWebSocket: TWebSocket);
    procedure OnEchoWebSocketError(const aWebSocket: TWebSocket);
    procedure OnEchoWebSocketMessage(const aWebSocket: TWebSocket; const aMessage: TWebSocketMessage);
    procedure OnEchoWebSocketClose(const aWebSocket: TWebSocket; const aWasClean: Boolean; const aCode: Word; const aReason: UTF8String);
  protected
    fServer: THttpApi2WebSocketServer;

    procedure OnHttpServerRequest(aRequest : TWebRequest; aResponse : TWebResponse);
  public
    constructor Create;
    destructor Destroy; override;

    procedure CloseWebSocketId(const aId: Integer; const aCode: Integer; const aReason: UTF8String);
    procedure SendToWebSocketId(const aId: Integer; const aMsg: UTF8String);
  end;

implementation

uses
  SynZip,
  System.SysUtils;

{ THttpSys2WebSocketServer }

procedure TWebSocketEchoServer.CloseWebSocketId(const aId, aCode: Integer; const aReason: UTF8String);
begin
  fEchoWebSocketHandler.CloseWebSocketId(aId, aCode, aReason);
end;

constructor TWebSocketEchoServer.Create;
begin
  fEchoWebSocketHandler := TWebSocketHandler.Create;

  fEchoWebSocketHandler.OnAcceptConnection := OnEchoAcceptConnection;
  fEchoWebSocketHandler.OnConnectWebSocket := OnEchoConnectWebSocket;
  fEchoWebSocketHandler.OnDisconnectWebSocket := OnEchoDisconnectWebSocket;

  fEchoWebSocketHandler.OnWebSocketReceiveCloseBuffer := OnEchoWebSocketCloseBuffer;

  fServer := THttpApi2WebSocketServer.Create(False, 8, 8);

  //fServer.AddUrlAuthorize('', 8801, False, '+');
  fServer.AddUrl('', 8801, False, '+');
  fServer.AddWebSocketUrl(fEchoWebSocketHandler, '/echo/', 8801, False, '+');

  fServer.RegisterCompress(CompressDeflate);

  fServer.OnRequest := OnHttpServerRequest;

  fServer.MaxConnections := 0;
  fServer.MaxBandwidth := 0;
  fServer.MaxInputCountLength := 0;

  FServer.Clone(8-1);
end;

destructor TWebSocketEchoServer.Destroy;
begin
  fServer.Free;
  inherited;
end;

procedure TWebSocketEchoServer.OnHttpServerRequest(aRequest: TWebRequest; aResponse: TWebResponse);
begin
  aResponse.StatusCode := 404;
end;

procedure TWebSocketEchoServer.SendToWebSocketId(const aId: Integer; const aMsg: UTF8String);
begin
  fEchoWebSocketHandler.SendToWebSocketId(aId, aMsg);
end;

procedure TWebSocketEchoServer.OnEchoConnectWebSocket(const aWebSocket: TWebSocketServer);
begin
  WriteLn(Format('OnEchoConnectWebSocket(%d)', [aWebSocket.TransportEndpoint.Id]));

  aWebSocket.OnOpen := OnEchoWebSocketOpen;
  aWebSocket.OnError := OnEchoWebSocketError;
  aWebSocket.OnMessage := OnEchoWebSocketMessage;
  aWebSocket.OnClose := OnEchoWebSocketClose;
end;

procedure TWebSocketEchoServer.OnEchoAcceptConnection(aRequest: TWebRequest; aResponse: TWebResponse; var aAccept: Boolean);
begin
  WriteLn(Format('OnEchoAcceptConnection(%d)', [-1]));
  aAccept := True;
end;

procedure TWebSocketEchoServer.OnEchoWebSocketClose(const aWebSocket: TWebSocket; const aWasClean: Boolean;
  const aCode: Word; const aReason: UTF8String);
begin
  WriteLn(Format('OnEchoWebSocketClose(%d): %s, %d, %s',
    [TWebSocketServer(aWebSocket).TransportEndpoint.Id, BoolToStr(aWasClean, True), aCode, aReason]));
end;

procedure TWebSocketEchoServer.OnEchoWebSocketCloseBuffer(const aWebSocket: TWebSocketServer; const aStatus: Cardinal; const aReasonBuffer: Pointer; const aReasonBufferSize: Cardinal);
var
  reason: UTF8String;
begin
  reason := aWebSocket.BufferToUTF8(aReasonBuffer, aReasonBufferSize);

  WriteLn(Format('OnEchoWebSocketCloseBuffer(%d), code:%d, reason: %s', [aWebSocket.TransportEndpoint.Id, aStatus, reason]));

  aWebSocket.Close(aStatus, 'Server: ' + reason);
end;

procedure TWebSocketEchoServer.OnEchoDisconnectWebSocket(const aWebSocket: TWebSocketServer);
begin
  WriteLn(Format('OnEchoDisconnectWebSocket(%d)', [aWebSocket.TransportEndpoint.Id]));
end;

procedure TWebSocketEchoServer.OnEchoWebSocketError(const aWebSocket: TWebSocket);
begin
  WriteLn(Format('OnEchoWebSocketError(%d)', [TWebSocketServer(aWebSocket).TransportEndpoint.Id]));
end;

procedure TWebSocketEchoServer.OnEchoWebSocketMessage(const aWebSocket: TWebSocket; const aMessage: TWebSocketMessage);
begin
  WriteLn(Format('OnEchoWebSocketMessage(%d): IsUTF8:%s, IsFragment:%s, Size: %d, Data:%s',
    [TWebSocketServer(aWebSocket).TransportEndpoint.Id, BoolToStr(aMessage.MessageType = mtUTF8, True),
    BoolToStr(aMessage.IsFragment, True), aMessage.BufferSize, Copy(aMessage.AsUTF8, 1, 100)]));

  fEchoWebSocketHandler.Broadcast(aMessage);
end;

procedure TWebSocketEchoServer.OnEchoWebSocketOpen(const aWebSocket: TWebSocket);
begin
  WriteLn(Format('OnEchoWebSocketOpen(%d)', [TWebSocketServer(aWebSocket).TransportEndpoint.Id]));
end;

end.

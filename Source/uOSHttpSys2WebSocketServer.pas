{**********************************************************************}
{                                                                      }
{    "The contents of this file are subject to the Mozilla Public      }
{    License Version 1.1 (the "License"); you may not use this         }
{    file except in compliance with the License. You may obtain        }
{    a copy of the License at http://www.mozilla.org/MPL/              }
{                                                                      }
{    Software distributed under the License is distributed on an       }
{    "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express       }
{    or implied. See the License for the specific language             }
{    governing rights and limitations under the License.               }
{                                                                      }
{    Copyright OddStorm Ltd.                                           }
{    Current maintainer: Chavdar Kopoev                                }
{                                                                      }
{**********************************************************************}
{
  WebSocket Server based on Eric Grange's HTTP.sys 2.0 server
  Requires Windows 8, Windows Server 2012 or higher

  *** BEGIN LICENSE BLOCK *****
  Version: MPL 1.1/GPL 2.0/LGPL 2.1

  The contents of this file are subject to the Mozilla Public License Version
  1.1 (the "License"); you may not use this file except in compliance with
  the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL
}
unit uOSHttpSys2WebSocketServer;

interface

uses
  uOSWebSocketServer,
  uOSWebSocketHandler,
  uOSTransportHttpSys2,
  dwsHTTPSysAPI,
  dwsHTTPSysServer,
  dwsWebEnvironment;

type
  THttpApi2WebSocketServerRequestContext = record
    HttpRequest: PHTTP_REQUEST_V2;

    WebSocketHandler: TWebSocketHandler;
    WebSocketServer: TWebSocketServer;

    procedure Clear;
  end;

  THttpApi2WebSocketServer = class (THttpApi2Server)
  private
    fIsClone: Boolean;

    fRegisteredHandlers: array of TWebSocketHandler;
    fTransport: TTrasportHttpSys2;
    fWebSocketRequestContext: THttpApi2WebSocketServerRequestContext;
  protected
    procedure BeforeWaitForNextRequest; override;
    procedure AfterWaitForNextRequest(const aCurRequest: PHTTP_REQUEST_V2); override;
    function GetHttpResponseFlags: Cardinal; override;

    function UpgradeToWebSocket(aRequest: TWebRequest; aResponse: TWebResponse): Integer;
  public
    constructor Create(CreateSuspended : Boolean; const aWebSocketThreadsCount: Cardinal; const aConcurencyLevel: Cardinal);
    constructor CreateClone(From : THttpApi2Server);
    destructor Destroy; override;

    procedure Clone(ChildThreadCount: Integer);

    procedure DoRequest(aRequest : TWebRequest; aResponse : TWebResponse); override;

    function AddWebSocketUrl(const aHandler: TWebSocketHandler; const aRoot : string; aPort : Integer;
      isHttps : Boolean; const aDomainName : string = '*') : Integer;
  end;

implementation

uses
  uOSWebSocketAPI;

const
   C_KNOWNHEADERS_NAME : array [reqCacheControl..reqUserAgent] of PAnsiChar = (
      'Cache-Control', 'Connection', 'Date', 'Keep-Alive', 'Pragma', 'Trailer',
      'Transfer-Encoding', 'Upgrade', 'Via', 'Warning', 'Allow', 'Content-Length',
      'Content-Type', 'Content-Encoding', 'Content-Language', 'Content-Location',
      'Content-MD5', 'Content-Range', 'Expires', 'Last-Modified', 'Accept',
      'Accept-Charset', 'Accept-Encoding', 'Accept-Language', 'Authorization',
      'Cookie', 'Expect', 'From', 'Host', 'If-Match', 'If-Modified-Since',
      'If-None-Match', 'If-Range', 'If-Unmodified-Since', 'Max-Forwards',
      'Proxy-Authorization', 'Referer', 'Range', 'TE', 'Translate', 'User-Agent');

function HttpSys2ToWebSocketHeaders(const aHttpHeaders : HTTP_REQUEST_HEADERS): WEB_SOCKET_HTTP_HEADER_ARR;
var
  headerCnt: Integer;
  i, idx: Integer;
  h : THttpHeader;
  p : PHTTP_UNKNOWN_HEADER;
begin
  Assert(Low(C_KNOWNHEADERS_NAME) = Low(aHttpHeaders.KnownHeaders));
  Assert(High(C_KNOWNHEADERS_NAME) = High(aHttpHeaders.KnownHeaders));

  headerCnt := 0;
  for h := Low(C_KNOWNHEADERS_NAME) to High(C_KNOWNHEADERS_NAME) do
    if aHttpHeaders.KnownHeaders[h].RawValueLength <> 0 then
      Inc(headerCnt);

  p := aHttpHeaders.pUnknownHeaders;
  if p <> nil then
    Inc(headerCnt, aHttpHeaders.UnknownHeaderCount);

  SetLength(Result, headerCnt);
  idx := 0;
  for h := Low(C_KNOWNHEADERS_NAME) to High(C_KNOWNHEADERS_NAME) do
    if aHttpHeaders.KnownHeaders[h].RawValueLength <> 0 then
    begin
      Result[idx].pcName := C_KNOWNHEADERS_NAME[h];
      Result[idx].ulNameLength := Length(C_KNOWNHEADERS_NAME[h]);

      Result[idx].pcValue := aHttpHeaders.KnownHeaders[h].pRawValue;
      Result[idx].ulValueLength := aHttpHeaders.KnownHeaders[h].RawValueLength;

      Inc(idx);
    end;

  p := aHttpHeaders.pUnknownHeaders;
  if p <> nil then
    for i := 1 to aHttpHeaders.UnknownHeaderCount do
    begin
      Result[idx].pcName := p^.pName;
      Result[idx].ulNameLength := p^.NameLength;

      Result[idx].pcValue := p^.pRawValue;
      Result[idx].ulValueLength := p^.RawValueLength;

      Inc(idx);
      Inc(p);
    end;
end;

{ THttpApi2WebSocketServer }

function THttpApi2WebSocketServer.AddWebSocketUrl(const aHandler: TWebSocketHandler; const aRoot: String;
  aPort: Integer; isHttps: Boolean; const aDomainName: string): Integer;
var
  s : string;
  n : Integer;
begin
  Result := -1;

  if (Self = nil) or (FReqQueue = 0) or (HttpAPI.Module = 0) then
    Exit;

  s := RegURL(aRoot, aPort, isHttps, aDomainName);
  if s = '' then
    Exit; // invalid parameters

  HttpAPI.Check(
    HttpAPI.AddUrlToUrlGroup(FUrlGroupID, Pointer(s), HTTP_URL_CONTEXT(aHandler)),
    hAddUrlToUrlGroup);

  n := Length(fRegisteredHandlers);
  SetLength(fRegisteredHandlers, n+1);
  fRegisteredHandlers[n] := aHandler;

  n := Length(FRegisteredUrl);
  SetLength(FRegisteredUrl, n+1);
  FRegisteredUrl[n] := s;
end;

procedure THttpApi2WebSocketServer.AfterWaitForNextRequest(const aCurRequest: PHTTP_REQUEST_V2);
begin
  inherited;

  fWebSocketRequestContext.HttpRequest := aCurRequest;
end;

procedure THttpApi2WebSocketServer.BeforeWaitForNextRequest;
var
  transportEndpoint: TTransportEndpointHttpSys2;
begin
  inherited;

  with fWebSocketRequestContext do
  begin
    if Assigned(WebSocketServer) then
    begin
      with HttpRequest^ do
        transportEndpoint := TTransportEndpointHttpSys2.Create(ConnectionId, fTransport, ConnectionId, RequestId);

      WebSocketServer.Connect(transportEndpoint);
    end;

    Clear;
  end;
end;

procedure THttpApi2WebSocketServer.Clone(ChildThreadCount: Integer);
var
  i : Integer;
begin
  if (FReqQueue = 0) or not Assigned(OnRequest) or (ChildThreadCount <= 0) then
    Exit; // nothing to clone (need a queue and a process event)

  if ChildThreadCount > 256 then
    ChildThreadCount := 256; // not worth adding

  for i := 1 to ChildThreadCount do
    FClones.Add(THttpApi2WebSocketServer.CreateClone(Self));
end;

constructor THttpApi2WebSocketServer.Create(CreateSuspended : Boolean; const aWebSocketThreadsCount: Cardinal;
  const aConcurencyLevel: Cardinal);
begin
  inherited Create(CreateSuspended);

  fTransport := TTrasportHttpSys2.Create(FReqQueue, aWebSocketThreadsCount, aConcurencyLevel);

  SetLength(fRegisteredHandlers, 0);
end;

constructor THttpApi2WebSocketServer.CreateClone(From: THttpApi2Server);
begin
  inherited CreateClone(From);
  fIsClone := True;
  fTransport := THttpApi2WebSocketServer(from).fTransport;
end;

destructor THttpApi2WebSocketServer.Destroy;
var
  i: Integer;
begin
  if not fIsClone then
  begin
    for i := 0 to High(fRegisteredHandlers) do
      fRegisteredHandlers[i].Free;

    fTransport.Free;
  end;

  inherited;
end;

procedure THttpApi2WebSocketServer.DoRequest(aRequest: TWebRequest; aResponse: TWebResponse);
var
  acceptConnection: Boolean;
begin
  acceptConnection := False;

  //Check if handler can accept request based on http headers, e.g. extension and protocol match
  fWebSocketRequestContext.WebSocketHandler := TWebSocketHandler(fWebSocketRequestContext.HttpRequest^.UrlContext);
  if Assigned(fWebSocketRequestContext.WebSocketHandler) then
    fWebSocketRequestContext.WebSocketHandler.AcceptConnection(aRequest, aResponse, acceptConnection);

  if acceptConnection then
    aResponse.StatusCode := UpgradeToWebSocket(aRequest, aResponse)
  else
    inherited DoRequest(aRequest, aResponse);
end;

function THttpApi2WebSocketServer.GetHttpResponseFlags: Cardinal;
begin
  if Assigned(fWebSocketRequestContext.WebSocketHandler) then
    Result := HTTP_SEND_RESPONSE_FLAG_OPAQUE or HTTP_SEND_RESPONSE_FLAG_BUFFER_DATA or HTTP_SEND_RESPONSE_FLAG_MORE_DATA
  else
    Result := inherited;
end;

function THttpApi2WebSocketServer.UpgradeToWebSocket(aRequest: TWebRequest; aResponse: TWebResponse): Integer;
var
  webSocket: TWebSocketServer;
  wsRequestHeaders: WEB_SOCKET_HTTP_HEADER_ARR; //WEB_SOCKET_HTTP_HEADER_ARR;
  outHeaders: RawByteString;
begin
  webSocket := TWebSocketServer.Create(fWebSocketRequestContext.WebSocketHandler);
  wsRequestHeaders := HttpSys2ToWebSocketHeaders(fWebSocketRequestContext.HttpRequest^.Headers);

  aResponse.ContentData := '';
  aResponse.ContentType := '';

  if webSocket.PerformHandshake(@wsRequestHeaders[0], Length(wsRequestHeaders), outHeaders) then
  begin
    aResponse.Headers.Text := UTF8ToString(outHeaders);
    fWebSocketRequestContext.WebSocketServer := webSocket;
    Result := 101;
  end
  else
    begin
      webSocket.Free;
      Result := 404;
    end;
end;

{ THttpApi2WebSocketServerRequestContext }

procedure THttpApi2WebSocketServerRequestContext.Clear;
begin
  HttpRequest := nil;
  WebSocketHandler := nil;
  WebSocketServer := nil;
end;

end.

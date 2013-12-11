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
  WebSocket container and server side http.sys implementation

  *** BEGIN LICENSE BLOCK *****
  Version: MPL 1.1/GPL 2.0/LGPL 2.1

  The contents of this file are subject to the Mozilla Public License Version
  1.1 (the "License"); you may not use this file except in compliance with
  the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL
}
unit uOSWebSocketServer;

interface

uses
  uOSTransport,
  uOSWebSocketAPI,
  uOSWebSocket,
  SRWLock,
  Generics.Collections,
  System.SysUtils,
  System.Classes;

const
  C_TRANSPORT_BUFFER_SIZE = 4 * 1024; //Standart Buffer
  C_WEB_SOCKET_BUFFER_SIZE = 2;

type
  TWebSocketBufferDataArr = array [0 .. C_WEB_SOCKET_BUFFER_SIZE - 1] of WEB_SOCKET_BUFFER_DATA;
  PWebSocketBufferDataArr = ^TWebSocketBufferDataArr;
  TWebSocketBufferCloseArr = array [0 .. C_WEB_SOCKET_BUFFER_SIZE - 1] of WEB_SOCKET_BUFFER_CLOSE_STATUS;
  PWebSocketBufferCloseArr = ^TWebSocketBufferCloseArr;

  TWebSocketServer = class;

  TOnWebSocketReceiveUTF8Buffer = procedure (const aWebSocket: TWebSocketServer; const aBuffer: Pointer; const aBufferSize: Cardinal) of object;
  TOnWebSocketReceiveUTF8BufferFragment = procedure (const aWebSocket: TWebSocketServer; const aBuffer: Pointer; const aBufferSize: Cardinal) of object;
  TOnWebSocketReceiveBinaryBuffer = procedure (const aWebSocket: TWebSocketServer; const aBuffer: Pointer; const aBufferSize: Cardinal) of object;
  TOnWebSocketReceiveBinaryBufferFragment = procedure (const aWebSocket: TWebSocketServer; const aBuffer: Pointer; const aBufferSize: Cardinal) of object;
  TOnWebSocketReceiveCloseBuffer = procedure (const aWebSocket: TWebSocketServer; const aStatus: Cardinal; const aReasonBuffer: Pointer; const aReasonBufferSize: Cardinal) of object;
  TOnWebSocketReceivePingPongBuffer = procedure (const aWebSocket: TWebSocketServer) of object;

  TWebSocketCloseContext = record
    Status: Cardinal;
    Reason: UTF8String;
  end;

  TTransportActionResult = record
    TransportBytesProcessed: Cardinal;
    TransportStatus: TTrasportStatus;
  end;
  TTransportActionResultContextArr = array [0 ..C_TRANSPORT_BUFFER_SIZE] of TTransportActionResult;

  TWebSocketTransportContext = record
    WebSocketActionContext: Pointer;
    TransportActionResultArr: TTransportActionResultContextArr;
    TransportActionLength: Integer;
    TransportPendingActionCount: Integer;
  end;

  TWebSocketException = class (Exception);

  TOnWebSocketConnect = procedure (const aConnection: TWebSocketServer) of object;
  TOnWebSocketDisconnect = procedure (const aConnection: TWebSocketServer) of object;

  TWebSocketContainer = class
  private
    fConnectionsSRW: TSRWLock;
    fConnections: TList<TWebSocketServer>;

    fOnWebSocketReceiveUTF8Buffer: TOnWebSocketReceiveUTF8Buffer;
    fOnWebSocketReceiveUTF8BufferFragment: TOnWebSocketReceiveUTF8BufferFragment;
    fOnWebSocketReceiveBinaryBuffer: TOnWebSocketReceiveBinaryBuffer;
    fOnWebSocketReceiveBinaryBufferFragment: TOnWebSocketReceiveBinaryBufferFragment;
    fOnWebSocketReceiveCloseBuffer: TOnWebSocketReceiveCloseBuffer;
    fOnWebSocketReceivePingPongBuffer: TOnWebSocketReceivePingPongBuffer;
  protected
    fOnConnect: TOnWebSocketConnect;
    fOnDisconnect: TOnWebSocketDisconnect;

    procedure AddWebSocket(const aWebSocket: TWebSocketServer);
    procedure RemoveWebSocket(const aWebSocket: TWebSocketServer);

    procedure TriggerWebSocketConnect(const aWebSocket: TWebSocketServer);
    procedure TriggerWebSocketDisconnect(const aWebSocket: TWebSocketServer);

    procedure TriggerWebSocketReceiveUTF8Buffer(const aWebSocket: TWebSocketServer; const aBuffer: Pointer; const aBufferSize: Cardinal); virtual;
    procedure TriggerWebSocketReceiveUTF8BufferFragment(const aWebSocket: TWebSocketServer; const aBuffer: Pointer; const aBufferSize: Cardinal); virtual;
    procedure TriggerWebSocketReceiveBinaryBuffer(const aWebSocket: TWebSocketServer; const aBuffer: Pointer; const aBufferSize: Cardinal); virtual;
    procedure TriggerWebSocketReceiveBinaryBufferFragment(const aWebSocket: TWebSocketServer; const aBuffer: Pointer; const aBufferSize: Cardinal); virtual;
    procedure TriggerWebSocketReceiveCloseBuffer(const aWebSocket: TWebSocketServer; const aStatus: Cardinal; const aReasonBuffer: Pointer; const aReasonBufferSize: Cardinal); virtual;
    procedure TriggerWebSocketReceivePingPongBuffer(const aWebSocket: TWebSocketServer);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Broadcast(const aMessage: TWebSocketMessage);
    procedure BroadcastUTF8(const aMessage: UTF8String);
    procedure BroadcastBinary(const aMessage: Pointer; const aMessageSize: Cardinal);

    procedure CloseWebSocketId(const aId: Integer; const aCode: Integer; const aReason: UTF8String);
    procedure SendToWebSocketId(const aId: Integer; const aMsg: UTF8String);

    property OnConnectWebSocket: TOnWebSocketConnect read fOnConnect write fOnConnect;
    property OnDisconnectWebSocket: TOnWebSocketDisconnect read fOnDisconnect write fOnDisconnect;

    property OnWebSocketReceiveUTF8Buffer: TOnWebSocketReceiveUTF8Buffer read fOnWebSocketReceiveUTF8Buffer write fOnWebSocketReceiveUTF8Buffer;
    property OnWebSocketReceiveUTF8BufferFragment: TOnWebSocketReceiveUTF8BufferFragment read fOnWebSocketReceiveUTF8BufferFragment write fOnWebSocketReceiveUTF8BufferFragment;
    property OnWebSocketReceiveBinaryBuffer: TOnWebSocketReceiveBinaryBuffer read fOnWebSocketReceiveBinaryBuffer write fOnWebSocketReceiveBinaryBuffer;
    property OnWebSocketReceiveBinaryBufferFragment: TOnWebSocketReceiveBinaryBufferFragment read fOnWebSocketReceiveBinaryBufferFragment write fOnWebSocketReceiveBinaryBufferFragment;
    property OnWebSocketReceiveCloseBuffer: TOnWebSocketReceiveCloseBuffer read fOnWebSocketReceiveCloseBuffer write fOnWebSocketReceiveCloseBuffer;
    property OnWebSocketReceivePingPongBuffer: TOnWebSocketReceivePingPongBuffer read fOnWebSocketReceivePingPongBuffer write fOnWebSocketReceivePingPongBuffer;
  end;

  TWebSocketServer = class (TWebSocket)
  private
    fContainer: TWebSocketContainer;
    fTransportEndpoint: TTransportEndpoint;

    fHandle: WEB_SOCKET_HANDLE;
    fWebSocketBufferDataArr: TWebSocketBufferDataArr;

    fWriteContext: TWebSocketTransportContext;
    fReadContext: TWebSocketTransportContext;

    fTransportCloseContext: TWebSocketCloseContext;

    fUTF8Buffer: TMemoryStream;
    fBinaryBuffer: TMemoryStream;
  protected
    procedure DoWebSocketShutdown;

    //Transport Endpoint Callbacks
    procedure OnTransportShutdown;
    procedure OnTransportConnect(const aStatus: TTrasportStatus; const aContext: TTransportContext);
    procedure OnTransportDisconnect(const aStatus: TTrasportStatus; const aContext: TTransportContext);
    procedure OnTransportRead(const aStatus: TTrasportStatus; const aBytesProcessed: Cardinal; const aContext: TTransportContext);
    procedure OnTransportWrite(const aStatus: TTrasportStatus; const aBytesProcessed: Cardinal; const aContext: TTransportContext);

    //Handshake helpers
    function WebSocketHeadersToRawByteString(const aHeaders: PWEB_SOCKET_HTTP_HEADER; const aHeadersCount: Integer): RawByteString;

    procedure OnClientClose(const aStatus: Word; const aReasonBuffer: Pointer; const aReasonBufferSize: Cardinal);
    procedure OnTrasportError(const aStatus: TTrasportStatus);

    //WebsocketAPI processing
    function ProcessActions(const aActionQueue: Integer = WEB_SOCKET_ALL_ACTION_QUEUE): Boolean;
    procedure InternalSendDataBuffer(const aBufferType: WEB_SOCKET_BUFFER_TYPE; const aBuffer: Pointer; const aBufferSize: Cardinal);
    procedure InternalSendCloseBuffer(const aStatus: Word; const aReasonBuffer: Pointer; const aReasonBufferSize: Cardinal);

    //Request WebSocket receive over asyn transport
    procedure TryRead;
  public
    constructor Create(const aContainer: TWebSocketContainer);
    destructor Destroy; override;

    procedure Connect(var aTransportEndpoint); override;
    procedure Close(const aCode: Word = 1000; const aReason: UTF8String = ''); override;

    procedure SendUTF8(const aData: UTF8String); override;
    procedure SendBinary(const aData: Pointer; const aDataSize: Cardinal); override;

    function PerformHandshake(const aRequestHeaders: PWEB_SOCKET_HTTP_HEADER; const aRequestHeadersCount: Cardinal;
      var aResponseHeaders: RawByteString): Boolean; overload;

    procedure SetTransportEndpoint(const aTransportEndpoint: TTransportEndpoint);

    procedure SendUTF8Buffer(const aBuffer: Pointer; const aBufferSize: Cardinal); inline;
    procedure SendUTF8BufferFragment(const aBuffer: Pointer; const aBufferSize: Cardinal); inline;
    procedure SendBinaryBuffer(const aBuffer: Pointer; const aBufferSize: Cardinal); inline;
    procedure SendBinaryBufferFragment(const aBuffer: Pointer; const aBufferSize: Cardinal); inline;
    procedure SendCloseBuffer(const aStatus: Cardinal; const aReasonBuffer: Pointer; const aReasonBufferSize: Cardinal);

    property TransportEndpoint: TTransportEndpoint read fTransportEndpoint;

    property UTF8Buffer: TMemoryStream read fUTF8Buffer;
    property BinaryBuffer: TMemoryStream read fBinaryBuffer;
  end;

implementation

uses
  Winapi.Windows;

{ TWebSocketServer }

procedure TWebSocketServer.SendUTF8(const aData: UTF8String);
begin
  SendUTF8Buffer(@aData[1], Length(aData));
end;

procedure TWebSocketServer.SendBinary(const aData: Pointer; const aDataSize: Cardinal);
begin
  SendBinaryBuffer(aData, aDataSize);
end;

procedure TWebSocketServer.SendBinaryBuffer(const aBuffer: Pointer; const aBufferSize: Cardinal);
begin
  InternalSendDataBuffer(WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE, aBuffer, aBufferSize);
end;

procedure TWebSocketServer.SendBinaryBufferFragment(const aBuffer: Pointer; const aBufferSize: Cardinal);
begin
  InternalSendDataBuffer(WEB_SOCKET_BINARY_FRAGMENT_BUFFER_TYPE, aBuffer, aBufferSize);
end;

procedure TWebSocketServer.SendCloseBuffer(const aStatus: Cardinal; const aReasonBuffer: Pointer; const aReasonBufferSize: Cardinal);
begin
  InternalSendCloseBuffer(aStatus, aReasonBuffer, aReasonBufferSize);
end;

procedure TWebSocketServer.Close(const aCode: Word; const aReason: UTF8String);
begin
  if not ((aCode = 1000) or ((aCode >= 3000) and (aCode <= 4999))) then
    raise TWebSocketException.Create('InvalidAccessError')
  else
    if (Length(aReason) > 123) then
      raise TWebSocketException.Create('SyntaxError')
    else
      InternalSendCloseBuffer(aCode, @aReason[1], Length(aReason));
end;

procedure TWebSocketServer.Connect(var aTransportEndpoint);
var
  transportEndpoint: TTransportEndpoint absolute aTransportEndpoint;
begin
  fTransportEndpoint := transportEndpoint;
  fTransportEndpoint.OnConnect := OnTransportConnect;
  fTransportEndpoint.OnDisconnect := OnTransportDisconnect;
  fTransportEndpoint.OnShutdown := OnTransportShutdown;
  fTransportEndpoint.OnWrite := OnTransportWrite;
  fTransportEndpoint.OnRead := OnTransportRead;

  fContainer.AddWebSocket(Self);
  fTransportEndpoint.Connect;
end;

constructor TWebSocketServer.Create(const aContainer: TWebSocketContainer);
begin
  fContainer := aContainer;
  fTransportEndpoint := nil;

  WebSocketAPI.InitializeAPI;

  fHandle := nil;
  WebSocketAPI.Check(
    WebSocketAPI.CreateServerHandle(nil, 0, fHandle),
    hCreateServerHandle);

  fReadyState := rsConnecting;

  fUTF8Buffer := TMemoryStream.Create;
  fBinaryBuffer := TMemoryStream.Create;
end;

destructor TWebSocketServer.Destroy;
begin
  fBinaryBuffer.Free;
  fUTF8Buffer.Free;

  WebSocketAPI.DeleteHandle(fHandle);

  inherited;
end;

procedure TWebSocketServer.DoWebSocketShutdown;
begin
  fContainer.RemoveWebSocket(Self);
  fTransportEndpoint.Shutdown;
end;

procedure TWebSocketServer.InternalSendCloseBuffer(const aStatus: Word; const aReasonBuffer: Pointer; const aReasonBufferSize: Cardinal);
var
  wsSendBuf: WEB_SOCKET_BUFFER_CLOSE_STATUS;
begin
  if fReadyState = rsOpen then
  begin
    fReadyState := rsClosing;

    wsSendBuf.pbReason := aReasonBuffer;
    wsSendBuf.ulReasonLength := aReasonBufferSize;
    wsSendBuf.usStatus := aStatus;

    fTransportCloseContext.Status := aStatus;
    fTransportCloseContext.Reason := BufferToUTF8(aReasonBuffer, aReasonBufferSize);

    WebSocketAPI.Check(
      WebSocketAPI.Send(fHandle, WEB_SOCKET_CLOSE_BUFFER_TYPE, @wsSendBuf, nil),
      hSend);

    ProcessActions(WEB_SOCKET_SEND_ACTION_QUEUE);
  end else if fReadyState = rsClosing then
  begin
    wsSendBuf.pbReason := aReasonBuffer;
    wsSendBuf.ulReasonLength := aReasonBufferSize;
    wsSendBuf.usStatus := aStatus;

    WebSocketAPI.Check(
      WebSocketAPI.Send(fHandle, WEB_SOCKET_CLOSE_BUFFER_TYPE, @wsSendBuf, nil),
      hSend);

    ProcessActions(WEB_SOCKET_SEND_ACTION_QUEUE);

    fTransportEndpoint.Disconnect(TTransportContext(@fTransportCloseContext));
  end;
end;

procedure TWebSocketServer.InternalSendDataBuffer(const aBufferType: WEB_SOCKET_BUFFER_TYPE; const aBuffer: Pointer;
  const aBufferSize: Cardinal);
var
  wsSendBuf: WEB_SOCKET_BUFFER_DATA;
begin
  if fReadyState = rsConnecting then
    raise TWebSocketException.Create('InvalidStateError');

  wsSendBuf.pbBuffer := aBuffer;
  wsSendBuf.ulBufferLength := aBufferSize;

  InterlockedExchangeAdd(fBufferAmount, aBufferSize);

  WebSocketAPI.Check(
    WebSocketAPI.Send(fHandle, aBufferType, @wsSendBuf, nil),
    hSend);

  ProcessActions(WEB_SOCKET_SEND_ACTION_QUEUE);
end;

procedure TWebSocketServer.OnClientClose(const aStatus: Word; const aReasonBuffer: Pointer;
  const aReasonBufferSize: Cardinal);
begin
  if fReadyState = rsClosing then // we first initiated the close, and set the state to rsClosing
  begin
    fReadyState := rsClosed;
    TriggerOnClose(True, aStatus, BufferToUTF8(aReasonBuffer, aReasonBufferSize));
    fTransportEndpoint.Disconnect(TTransportContext(@fTransportCloseContext));
  end
  else if fReadyState = rsOpen then
  begin // close request received, waiting for protocol implementor to respond back
    fTransportCloseContext.Status := aStatus;
    fTransportCloseContext.Reason := BufferToUTF8(aReasonBuffer, aReasonBufferSize);

    fReadyState := rsClosing;
    fContainer.TriggerWebSocketReceiveCloseBuffer(Self, aStatus, aReasonBuffer, aReasonBufferSize);
  end;
end;

procedure TWebSocketServer.OnTransportConnect(const aStatus: TTrasportStatus; const aContext: TTransportContext);
begin
  fReadyState := rsOpen;
  TriggerOnOpen;
  TryRead;
end;

procedure TWebSocketServer.OnTransportDisconnect(const aStatus: TTrasportStatus; const aContext: TTransportContext);
var
  closeContextPtr: ^TWebSocketCloseContext absolute aContext;
begin
  if fReadyState = rsClosed then
    DoWebSocketShutdown
  else
    begin
      fReadyState := rsClosed;

      if (aStatus <> tsDone) or (closeContextPtr = nil) then
        TriggerOnError;

      if Assigned(aContext) then
        TriggerOnClose(True, closeContextPtr^.Status, closeContextPtr^.Reason)
      else
        TriggerOnClose(False, 1006, '');

      DoWebSocketShutdown;
    end;
end;

procedure TWebSocketServer.OnTransportRead(const aStatus: TTrasportStatus; const aBytesProcessed: Cardinal;
  const aContext: TTransportContext);
var
  actionIdx: Integer absolute aContext;
  i: Integer;
  pendingCount: Integer;
  bytesProcessed: Cardinal;
  transportResult: TTrasportStatus;
begin
  with fReadContext do
  begin
    TransportActionResultArr[actionIdx].TransportBytesProcessed := aBytesProcessed;
    TransportActionResultArr[actionIdx].TransportStatus := aStatus;
    pendingCount := InterlockedDecrement(TransportPendingActionCount);

    transportResult := tsDone;

    if pendingCount = 0 then
    begin
      bytesProcessed := 0;

      for i := 0 to TransportActionLength - 1 do
      case TransportActionResultArr[i].TransportStatus of
        tsDone: Inc(bytesProcessed, TransportActionResultArr[i].TransportBytesProcessed);
        tsError: if transportResult <> tsDisconnected then transportResult := tsError;
        tsDisconnected: transportResult := tsDisconnected;
      end;

      WebSocketAPI.Check(
        WebSocketAPI.CompleteAction(fHandle, WebSocketActionContext, bytesProcessed),
        hCompleteAction);

      case transportResult of
        tsDone: ProcessActions(WEB_SOCKET_RECEIVE_ACTION_QUEUE);
        tsError: OnTrasportError(transportResult);
        tsDisconnected:
          begin
            fTransportCloseContext.Status := 1006;
            fTransportCloseContext.Reason := '';
            fTransportEndpoint.Disconnect(TTransportContext(@fTransportCloseContext));
          end;
      end;
    end;
  end;
end;

procedure TWebSocketServer.OnTransportShutdown;
begin
  Free;
end;

procedure TWebSocketServer.OnTransportWrite(const aStatus: TTrasportStatus; const aBytesProcessed: Cardinal;
  const aContext: TTransportContext);
var
  actionIdx: Integer absolute aContext;
  i: Integer;
  pendingCount: Integer;
  bytesProcessed: Cardinal;
  transportResult: TTrasportStatus;
begin
  with fWriteContext do
  begin
    TransportActionResultArr[actionIdx].TransportBytesProcessed := aBytesProcessed;
    TransportActionResultArr[actionIdx].TransportStatus := aStatus;
    pendingCount := InterlockedDecrement(TransportPendingActionCount);

    transportResult := tsDone;

    if pendingCount = 0 then
    begin
      bytesProcessed := 0;

      for i := 0 to TransportActionLength - 1 do
      case TransportActionResultArr[i].TransportStatus of
        tsDone: Inc(bytesProcessed, TransportActionResultArr[i].TransportBytesProcessed);
        tsError: if transportResult <> tsDisconnected then transportResult := tsError;
        tsDisconnected: transportResult := tsDisconnected;
      end;

      WebSocketAPI.Check(
        WebSocketAPI.CompleteAction(fHandle, WebSocketActionContext, bytesProcessed),
        hCompleteAction);

      case transportResult of
        tsDone: ProcessActions(WEB_SOCKET_SEND_ACTION_QUEUE);
        tsError: OnTrasportError(transportResult);
        tsDisconnected:
          begin
            fTransportCloseContext.Status := 1006;
            fTransportCloseContext.Reason := '';
            fTransportEndpoint.Disconnect(TTransportContext(@fTransportCloseContext));
          end;
      end;
    end;
  end;
end;

procedure TWebSocketServer.OnTrasportError(const aStatus: TTrasportStatus);
begin
  case fReadyState of
    rsConnecting: ;
    rsOpen:
      begin
        TriggerOnError;
        InternalSendCloseBuffer(1001, nil, 0);
      end;
    rsClosing: ;
    rsClosed: DoWebSocketShutdown;
  end;
end;

procedure TWebSocketServer.SendUTF8Buffer(const aBuffer: Pointer; const aBufferSize: Cardinal);
begin
  InternalSendDataBuffer(WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE, aBuffer, aBufferSize);
end;

procedure TWebSocketServer.SendUTF8BufferFragment(const aBuffer: Pointer; const aBufferSize: Cardinal);
begin
  InternalSendDataBuffer(WEB_SOCKET_UTF8_FRAGMENT_BUFFER_TYPE, aBuffer, aBufferSize);
end;

function TWebSocketServer.WebSocketHeadersToRawByteString(const aHeaders: PWEB_SOCKET_HTTP_HEADER;
  const aHeadersCount: Integer): RawByteString;
var
  i: Integer;
  h: PWEB_SOCKET_HTTP_HEADER;
  len: Integer;
  d : PAnsiChar;
begin
  len := 0;

  h := aHeaders;
  for i := 1 to aHeadersCount do
  begin
    if h^.ulValueLength <> 0 then
      Inc(len, h^.ulNameLength + h^.ulValueLength + 4);
    Inc(h);
  end;

  SetString(Result, nil, len);
  d := Pointer(Result);

  h := aHeaders;
  for i := 1 to aHeadersCount do
  begin
    if h^.ulValueLength <> 0 then
    begin
      Move(h^.pcName^, d^, h^.ulNameLength);
      Inc(d, h^.ulNameLength);
      PWord(d)^ := Ord('=') + Ord(' ') shl 8;
      Inc(d, 2);
      Move(h^.pcValue^, d^, h^.ulValueLength);
      Inc(d, h^.ulValueLength);
      PWord(d)^ := 13 + 10 shl 8;
      Inc(d, 2);
    end;

    Inc(h);
  end;

  Assert(d - Pointer(Result) = len);
end;

procedure TWebSocketServer.SetTransportEndpoint(const aTransportEndpoint: TTransportEndpoint);
begin
  fTransportEndpoint := aTransportEndpoint;

  fTransportEndpoint.OnConnect := OnTransportConnect;
  fTransportEndpoint.OnDisconnect := OnTransportDisconnect;
  fTransportEndpoint.OnRead := OnTransportRead;
  fTransportEndpoint.OnWrite := OnTransportWrite;
end;

procedure TWebSocketServer.TryRead;
begin
  WebSocketAPI.Check(
    WebSocketAPI.Receive(fHandle, nil, nil),
    hReceive);

  ProcessActions(WEB_SOCKET_RECEIVE_ACTION_QUEUE);
end;

function TWebSocketServer.PerformHandshake(const aRequestHeaders: PWEB_SOCKET_HTTP_HEADER;
  const aRequestHeadersCount: Cardinal; var aResponseHeaders: RawByteString): Boolean;
var
  wsServerHeaders: PWEB_SOCKET_HTTP_HEADER;
  wsServerHeadersCount: ULONG;
begin
  Result := WebSocketAPI.BeginServerHandshake(fHandle, nil, nil, 0,
              aRequestHeaders, aRequestHeadersCount,
              wsServerHeaders, wsServerHeadersCount) = S_OK;

  if Result then
    try
      aResponseHeaders := WebSocketHeadersToRawByteString(wsServerHeaders, wsServerHeadersCount);
    finally
      Result := WebSocketAPI.EndServerHandshake(fHandle) = S_OK;
    end;
end;

function TWebSocketServer.ProcessActions(const aActionQueue: Integer = WEB_SOCKET_ALL_ACTION_QUEUE): Boolean;
var
  i: Integer;

  wsBufferType: WEB_SOCKET_BUFFER_TYPE;
  wsBufferArrCount: ULONG;

  wsAction: WEB_SOCKET_ACTION;
  wsApplicationContext: PVOID;
  wsActionContext: PVOID;

  wsBytesTransferred: Cardinal;

  hr: HRESULT;
  errorMsg: string;

  function CheckFailed(Status: HRESULT): BOOL;
  begin
    Result := winapi.Windows.Failed(Status) or (Status <> S_OK);
  end;

begin
  Result := True;
  errorMsg := '';

  wsBufferType := 0;
  repeat
    wsBytesTransferred := 0;
    wsBufferArrCount := Length(fWebSocketBufferDataArr);

    hr := WebSocketAPI.GetAction(fHandle, aActionQueue, @fWebSocketBufferDataArr[0], wsBufferArrCount, wsAction, wsBufferType, wsApplicationContext, wsActionContext);

    if CheckFailed(hr) then
    begin
      errorMsg := SysErrorMessage(hr);
      Result := False;
      //WebSocketAPI.AbortHandle(fHandle);
    end;

    case wsAction of
      WEB_SOCKET_NO_ACTION:
        begin
        end;
      WEB_SOCKET_SEND_TO_NETWORK_ACTION:
        begin
          Assert(wsBufferArrCount >= 1);

          with fWriteContext do
          begin
            WebSocketActionContext := wsActionContext;
            TransportActionLength := wsBufferArrCount;
            TransportPendingActionCount := wsBufferArrCount;
          end;

          for i := 0 to wsBufferArrCount - 1 do
            fTransportEndpoint.Write(fWebSocketBufferDataArr[i].pbBuffer, fWebSocketBufferDataArr[i].ulBufferLength, TTransportContext(i));

          Exit;
        end;
      WEB_SOCKET_INDICATE_SEND_COMPLETE_ACTION:
        begin
        end;
      WEB_SOCKET_RECEIVE_FROM_NETWORK_ACTION:
        begin
          Assert(wsBufferArrCount >= 1);

          with fReadContext do
          begin
            WebSocketActionContext := wsActionContext;
            TransportActionLength := wsBufferArrCount;
            TransportPendingActionCount := wsBufferArrCount;
          end;

          for i := 0 to wsBufferArrCount - 1 do
            fTransportEndpoint.Read(fWebSocketBufferDataArr[i].pbBuffer, fWebSocketBufferDataArr[i].ulBufferLength, TTransportContext(i));

          Exit;
        end;
      WEB_SOCKET_INDICATE_RECEIVE_COMPLETE_ACTION:
        begin
          try
            if wsBufferArrCount = 1 then
            begin
              if wsBufferType = WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE then
              begin
                fContainer.TriggerWebSocketReceiveUTF8Buffer(Self, fWebSocketBufferDataArr[0].pbBuffer, fWebSocketBufferDataArr[0].ulBufferLength);
              end
              else if wsBufferType = WEB_SOCKET_UTF8_FRAGMENT_BUFFER_TYPE then
              begin
                fContainer.TriggerWebSocketReceiveUTF8BufferFragment(Self, fWebSocketBufferDataArr[0].pbBuffer, fWebSocketBufferDataArr[0].ulBufferLength);
              end
              else if wsBufferType = WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE then
              begin
                fContainer.TriggerWebSocketReceiveBinaryBuffer(Self, fWebSocketBufferDataArr[0].pbBuffer, fWebSocketBufferDataArr[0].ulBufferLength);
              end
              else if wsBufferType = WEB_SOCKET_BINARY_FRAGMENT_BUFFER_TYPE then
              begin
                fContainer.TriggerWebSocketReceiveBinaryBufferFragment(Self, fWebSocketBufferDataArr[0].pbBuffer, fWebSocketBufferDataArr[0].ulBufferLength);
              end
              else if wsBufferType = WEB_SOCKET_CLOSE_BUFFER_TYPE then
              begin
                with TWebSocketBufferCloseArr(fWebSocketBufferDataArr)[0] do
                begin
                  OnClientClose(usStatus, pbReason, ulReasonLength);
                end;
              end
              else if wsBufferType = WEB_SOCKET_PING_PONG_BUFFER_TYPE then
              begin
                fContainer.TriggerWebSocketReceivePingPongBuffer(Self);
              end
              else if wsBufferType = WEB_SOCKET_UNSOLICITED_PONG_BUFFER_TYPE then
              begin
                //
              end;
            end;
          finally
            TryRead;
          end;
        end;
    end;

    hr := WebSocketAPI.CompleteAction(fHandle, wsActionContext, wsBytesTransferred);
    if hr <> 0 then
    begin
      if winapi.Windows.Failed(hr) then
        WebSocketAPI.Check(hr, hCompleteAction);
    end;
  until (wsAction = WEB_SOCKET_NO_ACTION);

  if not Result then
  begin
    fTransportEndpoint.Disconnect;
    //SendCloseBuffer(1006, @errorMsg[1], Length(errorMsg));
  end;
end;

{ TWebSocketContainer }

procedure TWebSocketContainer.AddWebSocket(const aWebSocket: TWebSocketServer);
begin
  fConnectionsSRW.AcquireExclusive;
  try
    fConnections.Add(aWebSocket);
  finally
    fConnectionsSRW.ReleaseExclusive;
  end;

  TriggerWebSocketConnect(aWebSocket);
end;

procedure TWebSocketContainer.BroadcastUTF8(const aMessage: UTF8String);
var
  i: Integer;
begin
  fConnectionsSRW.AcquireShared;
  try
    for i := 0 to fConnections.Count - 1 do
      fConnections[i].SendUTF8(aMessage);
  finally
    fConnectionsSRW.ReleaseShared;
  end;
end;

procedure TWebSocketContainer.BroadcastBinary(const aMessage: Pointer; const aMessageSize: Cardinal);
var
  i: Integer;
begin
  fConnectionsSRW.AcquireShared;
  try
    for i := 0 to fConnections.Count - 1 do
      fConnections[i].SendBinaryBuffer(aMessage, aMessageSize);
  finally
    fConnectionsSRW.ReleaseShared;
  end;
end;

procedure TWebSocketContainer.Broadcast(const aMessage: TWebSocketMessage);
var
  i: Integer;
begin
  fConnectionsSRW.AcquireShared;
  try
    case aMessage.MessageType of
      mtUTF8:
        for i := 0 to fConnections.Count - 1 do
          fConnections[i].SendUTF8Buffer(aMessage.Buffer, aMessage.BufferSize);
      mtBinary:
        for i := 0 to fConnections.Count - 1 do
          fConnections[i].SendBinaryBuffer(aMessage.Buffer, aMessage.BufferSize);
    end;
  finally
    fConnectionsSRW.ReleaseShared;
  end;
end;

procedure TWebSocketContainer.CloseWebSocketId(const aId, aCode: Integer; const aReason: UTF8String);
var
  i: Integer;
begin
  fConnectionsSRW.AcquireShared;
  try
    for i := 0 to fConnections.Count - 1 do
      if fConnections[i].TransportEndpoint.Id = Cardinal(aId) then
        fConnections[i].SendCloseBuffer(aCode, @aReason[1], Length(aReason));
  finally
    fConnectionsSRW.ReleaseShared;
  end;
end;

constructor TWebSocketContainer.Create;
begin
  fConnectionsSRW := TSRWLock.Create;
  fConnections := TList<TWebSocketServer>.Create;
end;

destructor TWebSocketContainer.Destroy;
const
  reason: UTF8String = 'Shutting down';

  function WaitForCleanShutDown(aMS: Integer): Boolean;
  begin
    while (fConnections.Count > 0) and (aMS > 0) do
    begin
      Sleep(10);
      Dec(aMS, 10);
    end;
    Result := fConnections.Count = 0;
  end;

  procedure SendCloseBuffer;
  var
    i: Integer;
  begin
    fConnectionsSRW.AcquireShared;
    try
      for i := 0 to fConnections.Count - 1 do
        fConnections[i].SendCloseBuffer(1001, @reason[1], Length(reason));
    finally
      fConnectionsSRW.ReleaseShared;
    end;
  end;

  procedure TransportDisconnect;
  var
    i: Integer;
  begin
    fConnectionsSRW.AcquireShared;
    try
      for i := 0 to fConnections.Count - 1 do
        if Assigned(fConnections[i].TransportEndpoint) then
          fConnections[i].TransportEndpoint.Disconnect;
    finally
      fConnectionsSRW.ReleaseShared;
    end;
  end;

begin
  SendCloseBuffer; //Try to close handshake

  if not WaitForCleanShutDown(1000) then //if still sockets availabe do transport disconnects
  begin
    TransportDisconnect;
    WaitForCleanShutDown(1000);
  end;

  fConnections.Free;
  fConnectionsSRW.Free;

  inherited;
end;

procedure TWebSocketContainer.RemoveWebSocket(const aWebSocket: TWebSocketServer);
begin
  TriggerWebSocketDisconnect(aWebSocket);

  fConnectionsSRW.AcquireExclusive;
  try
    fConnections.Remove(aWebSocket);
  finally
    fConnectionsSRW.ReleaseExclusive;
  end;
end;

procedure TWebSocketContainer.SendToWebSocketId(const aId: Integer; const aMsg: UTF8String);
var
  i: Integer;
begin
  fConnectionsSRW.AcquireShared;
  try
    for i := 0 to fConnections.Count - 1 do
      if fConnections[i].TransportEndpoint.Id = Cardinal(aId) then
        fConnections[i].SendUTF8(aMsg);
  finally
    fConnectionsSRW.ReleaseShared;
  end;
end;

procedure TWebSocketContainer.TriggerWebSocketConnect(const aWebSocket: TWebSocketServer);
begin
  if Assigned(fOnConnect) then
    fOnConnect(aWebSocket);
end;

procedure TWebSocketContainer.TriggerWebSocketDisconnect(const aWebSocket: TWebSocketServer);
begin
  if Assigned(fOnDisconnect) then
    fOnDisconnect(aWebSocket);
end;

procedure TWebSocketContainer.TriggerWebSocketReceiveBinaryBuffer(const aWebSocket: TWebSocketServer; const aBuffer: Pointer;
  const aBufferSize: Cardinal);
begin
  if Assigned(fOnWebSocketReceiveBinaryBuffer) then
    fOnWebSocketReceiveBinaryBuffer(aWebSocket, aBuffer, aBufferSize);
end;

procedure TWebSocketContainer.TriggerWebSocketReceiveBinaryBufferFragment(const aWebSocket: TWebSocketServer;
  const aBuffer: Pointer; const aBufferSize: Cardinal);
begin
  if Assigned(fOnWebSocketReceiveBinaryBufferFragment) then
    fOnWebSocketReceiveBinaryBufferFragment(aWebSocket, aBuffer, aBufferSize);
end;

procedure TWebSocketContainer.TriggerWebSocketReceiveCloseBuffer(const aWebSocket: TWebSocketServer; const aStatus: Cardinal;
  const aReasonBuffer: Pointer; const aReasonBufferSize: Cardinal);
begin
  if Assigned(fOnWebSocketReceiveCloseBuffer) then
    fOnWebSocketReceiveCloseBuffer(aWebSocket, aStatus, aReasonBuffer, aReasonBufferSize);
end;

procedure TWebSocketContainer.TriggerWebSocketReceivePingPongBuffer(const aWebSocket: TWebSocketServer);
begin
  if Assigned(fOnWebSocketReceivePingPongBuffer) then
    fOnWebSocketReceivePingPongBuffer(aWebSocket);
end;

procedure TWebSocketContainer.TriggerWebSocketReceiveUTF8Buffer(const aWebSocket: TWebSocketServer; const aBuffer: Pointer;
  const aBufferSize: Cardinal);
begin
  if Assigned(fOnWebSocketReceiveUTF8Buffer) then
    fOnWebSocketReceiveUTF8Buffer(aWebSocket, aBuffer, aBufferSize);
end;

procedure TWebSocketContainer.TriggerWebSocketReceiveUTF8BufferFragment(const aWebSocket: TWebSocketServer; const aBuffer: Pointer;
  const aBufferSize: Cardinal);
begin
  if Assigned(fOnWebSocketReceiveUTF8BufferFragment) then
    fOnWebSocketReceiveUTF8BufferFragment(aWebSocket, aBuffer, aBufferSize);
end;

end.

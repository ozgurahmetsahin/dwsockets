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
  WebSockets API definitions
  Requires Windows 8, Windows Server 2012 or higher

  *** BEGIN LICENSE BLOCK *****
  Version: MPL 1.1/GPL 2.0/LGPL 2.1

  The contents of this file are subject to the Mozilla Public License Version
  1.1 (the "License"); you may not use this file except in compliance with
  the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL
}
unit uOSWebSocketAPI;

interface

uses
  System.SysUtils,
  Winapi.Windows;

const
  C_WEBSOCKET_DLL = 'websocket.dll';

type
  TWebSocketAPIs = (
    hAbortHandle,
    hBeginClientHandshake,
    hBeginServerHandshake,
    hCompleteAction,
    hCreateClientHandle,
    hCreateServerHandle,
    hDeleteHandle,
    hEndClientHandshake,
    hEndServerHandshake,
    hGetAction,
    hGetGlobalProperty,
    hReceive,
    hSend
    );

const
  WebSocketFunctionNames : array [TWebSocketAPIs] of PChar = (
    'WebSocketAbortHandle',
    'WebSocketBeginClientHandshake',
    'WebSocketBeginServerHandshake',
    'WebSocketCompleteAction',
    'WebSocketCreateClientHandle',
    'WebSocketCreateServerHandle',
    'WebSocketDeleteHandle',
    'WebSocketEndClientHandshake',
    'WebSocketEndServerHandshake',
    'WebSocketGetAction',
    'WebSocketGetGlobalProperty',
    'WebSocketReceive',
    'WebSocketSend'
    );

type
  WEB_SOCKET_HANDLE = Pointer;

  WEB_SOCKET_HTTP_HEADER = record
    pcName: PAnsiChar;
    ulNameLength: ULONG;
    pcValue: PAnsiChar;
    ulValueLength: ULONG;
  end;
  PWEB_SOCKET_HTTP_HEADER = ^WEB_SOCKET_HTTP_HEADER;
  WEB_SOCKET_HTTP_HEADER_ARR = array of WEB_SOCKET_HTTP_HEADER;

  WEB_SOCKET_PROPERTY_TYPE = (
    WEB_SOCKET_RECEIVE_BUFFER_SIZE_PROPERTY_TYPE        = 0,
    WEB_SOCKET_SEND_BUFFER_SIZE_PROPERTY_TYPE           = 1,
    WEB_SOCKET_DISABLE_MASKING_PROPERTY_TYPE            = 2,
    WEB_SOCKET_ALLOCATED_BUFFER_PROPERTY_TYPE           = 3,
    WEB_SOCKET_DISABLE_UTF8_VERIFICATION_PROPERTY_TYPE  = 4,
    WEB_SOCKET_KEEPALIVE_INTERVAL_PROPERTY_TYPE         = 5,
    WEB_SOCKET_SUPPORTED_VERSIONS_PROPERTY_TYPE         = 6
  );

  WEB_SOCKET_PROPERTY = record
    PropType: WEB_SOCKET_PROPERTY_TYPE;
    pvValue: PVOID ;
    ulValueSize: ULONG;
  end;
  PWEB_SOCKET_PROPERTY = ^WEB_SOCKET_PROPERTY;

  WEB_SOCKET_ACTION = (
    WEB_SOCKET_NO_ACTION                            = 0,
    WEB_SOCKET_SEND_TO_NETWORK_ACTION               = 1,
    WEB_SOCKET_INDICATE_SEND_COMPLETE_ACTION        = 2,
    WEB_SOCKET_RECEIVE_FROM_NETWORK_ACTION          = 3,
    WEB_SOCKET_INDICATE_RECEIVE_COMPLETE_ACTION     = 4
  );
  PWEB_SOCKET_ACTION = ^WEB_SOCKET_ACTION;

  WEB_SOCKET_ACTION_QUEUE = Cardinal;

const
    WEB_SOCKET_SEND_ACTION_QUEUE                    = $1;
    WEB_SOCKET_RECEIVE_ACTION_QUEUE                 = $2;
    WEB_SOCKET_ALL_ACTION_QUEUE                     = WEB_SOCKET_SEND_ACTION_QUEUE or WEB_SOCKET_RECEIVE_ACTION_QUEUE;

type
  WEB_SOCKET_CLOSE_STATUS = USHORT;

const
    WEB_SOCKET_SUCCESS_CLOSE_STATUS                : WEB_SOCKET_CLOSE_STATUS = 1000;
    WEB_SOCKET_ENDPOINT_UNAVAILABLE_CLOSE_STATUS   : WEB_SOCKET_CLOSE_STATUS = 1001;
    WEB_SOCKET_PROTOCOL_ERROR_CLOSE_STATUS         : WEB_SOCKET_CLOSE_STATUS = 1002;
    WEB_SOCKET_INVALID_DATA_TYPE_CLOSE_STATUS      : WEB_SOCKET_CLOSE_STATUS = 1003;
    WEB_SOCKET_EMPTY_CLOSE_STATUS                  : WEB_SOCKET_CLOSE_STATUS = 1005;
    WEB_SOCKET_ABORTED_CLOSE_STATUS                : WEB_SOCKET_CLOSE_STATUS = 1006;
    WEB_SOCKET_INVALID_PAYLOAD_CLOSE_STATUS        : WEB_SOCKET_CLOSE_STATUS = 1007;
    WEB_SOCKET_POLICY_VIOLATION_CLOSE_STATUS       : WEB_SOCKET_CLOSE_STATUS = 1008;
    WEB_SOCKET_MESSAGE_TOO_BIG_CLOSE_STATUS        : WEB_SOCKET_CLOSE_STATUS = 1009;
    WEB_SOCKET_UNSUPPORTED_EXTENSIONS_CLOSE_STATUS : WEB_SOCKET_CLOSE_STATUS = 1010;
    WEB_SOCKET_SERVER_ERROR_CLOSE_STATUS           : WEB_SOCKET_CLOSE_STATUS = 1011;
    WEB_SOCKET_SECURE_HANDSHAKE_ERROR_CLOSE_STATUS : WEB_SOCKET_CLOSE_STATUS = 1015;

type
  WEB_SOCKET_BUFFER_DATA = record
    pbBuffer: PBYTE;
    ulBufferLength: ULONG;
    Reserved1: USHORT;
  end;
  WEB_SOCKET_BUFFER_CLOSE_STATUS = record
    pbReason: PBYTE;
    ulReasonLength: ULONG;
    usStatus: WEB_SOCKET_CLOSE_STATUS;
  end;

  WEB_SOCKET_BUFFER_TYPE = ULONG;

const
  WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE: WEB_SOCKET_BUFFER_TYPE             = $80000000;
  WEB_SOCKET_UTF8_FRAGMENT_BUFFER_TYPE: WEB_SOCKET_BUFFER_TYPE            = $80000001;
  WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE: WEB_SOCKET_BUFFER_TYPE           = $80000002;
  WEB_SOCKET_BINARY_FRAGMENT_BUFFER_TYPE: WEB_SOCKET_BUFFER_TYPE          = $80000003;
  WEB_SOCKET_CLOSE_BUFFER_TYPE: WEB_SOCKET_BUFFER_TYPE                    = $80000004;
  WEB_SOCKET_PING_PONG_BUFFER_TYPE: WEB_SOCKET_BUFFER_TYPE                = $80000005;
  WEB_SOCKET_UNSOLICITED_PONG_BUFFER_TYPE: WEB_SOCKET_BUFFER_TYPE         = $80000006;

type
  TWebSocketAPI = packed record
    Module : THandle;

    AbortHandle: procedure (hWebSocket: WEB_SOCKET_HANDLE); stdcall;

    BeginClientHandshake: function (hWebSocket: WEB_SOCKET_HANDLE; pszSubprotocols: PAnsiChar;
      ulSubprotocolCount: ULONG; pszExtensions: PAnsiChar; ulExtensionCount: ULONG;
      const pInitialHeaders: PWEB_SOCKET_HTTP_HEADER; ulInitialHeaderCount: ULONG;
      out pAdditionalHeaders: PWEB_SOCKET_HTTP_HEADER; out pulAdditionalHeaderCount: ULONG): HRESULT; stdcall;

    BeginServerHandshake: function (hWebSocket: WEB_SOCKET_HANDLE; pszSubprotocolSelected: PAnsiChar;
      pszExtensionSelected: PAnsiChar; ulExtensionSelectedCount: ULONG; const pRequestHeaders: PWEB_SOCKET_HTTP_HEADER;
      ulRequestHeaderCount: ULONG; out pResponseHeaders: PWEB_SOCKET_HTTP_HEADER;
      out pulResponseHeaderCount: ULONG): HRESULT; stdcall;

    CompleteAction: function (hWebSocket: WEB_SOCKET_HANDLE; pvActionContext: PVOID; ulBytesTransferred: ULONG): HRESULT; stdcall;

    CreateClientHandle: function (const pProperties: PWEB_SOCKET_PROPERTY; ulPropertyCount: ULONG;
      out phWebSocket: WEB_SOCKET_HANDLE): HRESULT; stdcall;

    CreateServerHandle: function (const pProperties: PWEB_SOCKET_PROPERTY; ulPropertyCount: ULONG;
      out phWebSocket: WEB_SOCKET_HANDLE): HRESULT; stdcall;

    DeleteHandle: function (hWebSocket: WEB_SOCKET_HANDLE): HRESULT; stdcall;

    EndClientHandshake: function (hWebSocket: WEB_SOCKET_HANDLE; const pResponseHeaders: PWEB_SOCKET_HTTP_HEADER;
      ulReponseHeaderCount: ULONG; var pulSelectedExtensions: ULONG; var pulSelectedExtensionCount: ULONG;
      var pulSelectedSubprotocol: ULONG): HRESULT; stdcall;

    EndServerHandshake: function (hWebSocket: WEB_SOCKET_HANDLE): HRESULT; stdcall;

    GetAction: function (hWebSocket: WEB_SOCKET_HANDLE; eActionQueue: WEB_SOCKET_ACTION_QUEUE;
      pDataBuffers: Pointer {WEB_SOCKET_BUFFER_DATA}; var pulDataBufferCount: ULONG; var pAction: WEB_SOCKET_ACTION;
      var pBufferType: WEB_SOCKET_BUFFER_TYPE; var pvApplicationContext: PVOID;
      var pvActionContext: PVOID): HRESULT; stdcall;

    GetGlobalProperty: function (eType: WEB_SOCKET_PROPERTY; var pvValue: PVOID; var ulSize: ULONG): HRESULT ; stdcall;

    Receive: function (hWebSocket: WEB_SOCKET_HANDLE; pBuffer: Pointer {PWEB_SOCKET_BUFFER_*}; pvContext: PVOID): HRESULT; stdcall;

    Send: function (hWebSocket: WEB_SOCKET_HANDLE; BufferType: WEB_SOCKET_BUFFER_TYPE;
      pBuffer: Pointer {PWEB_SOCKET_BUFFER_*}; Context: PVOID): HRESULT; stdcall;

    class procedure InitializeAPI; static;
    class procedure Check(const aError : HRESULT; const aApi : TWebSocketAPIs); static; inline;
  end;

  EWebSocketApi = class (Exception)
  public
    constructor Create(const aApi : TWebSocketAPIs; const aError : Integer);
  end;

var
  WebSocketAPI : TWebSocketAPI;

implementation

{ TWebSocketAPI }

class procedure TWebSocketAPI.Check(const aError: HRESULT; const aApi: TWebSocketAPIs);
begin
  if aError <> NO_ERROR then
    raise EWebSocketApi.Create(aApi, aError);
end;

class procedure TWebSocketAPI.InitializeAPI;
var
  api : TWebSocketAPIs;
  P : PPointer;
begin
  if WebSocketAPI.Module <> 0 then
    Exit; // already loaded

  try
    if WebSocketAPI.Module = 0 then
    begin
      WebSocketAPI.Module := LoadLibrary(C_WEBSOCKET_DLL);

      if WebSocketAPI.Module <= 255 then
        raise Exception.Create('Unable to find ' + C_WEBSOCKET_DLL + '!');

      P := @@WebSocketAPI.AbortHandle;
      for api := low(api) to high(api) do
      begin
        P^ := GetProcAddress(WebSocketAPI.Module, WebSocketFunctionNames[api]);
        if P^ = nil then
           raise Exception.CreateFmt('Unable to find %s in %s!', [WebSocketFunctionNames[api], C_WEBSOCKET_DLL]);
        inc(P);
      end;
    end;
  except
    on E : Exception do
    begin
      if WebSocketAPI.Module > 255 then
      begin
        FreeLibrary(WebSocketAPI.Module);
        WebSocketAPI.Module := 0;
      end;

      raise E;
    end;
  end;
end;

{ EWebSocketApi }

constructor EWebSocketApi.Create(const aApi: TWebSocketAPIs; const aError: Integer);
begin
  inherited CreateFmt('%s failed: %s (%d)!', [WebSocketFunctionNames[aApi], SysErrorMessage(aError), aError]);
end;

end.

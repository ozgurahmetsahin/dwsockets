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
  WebSocket client abstraction
  As recommended by Draft 4 December 2012 http://dev.w3.org/html5/websockets/

  *** BEGIN LICENSE BLOCK *****
  Version: MPL 1.1/GPL 2.0/LGPL 2.1

  The contents of this file are subject to the Mozilla Public License Version
  1.1 (the "License"); you may not use this file except in compliance with
  the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL
}
unit uOSWebSocket;

interface

type
  TWebSocketReadyState = (rsConnecting = 0, rsOpen = 1, rsClosing = 2, rsClosed = 3);
  TWebSocket = class;
  TWebSocketMessage = class;

  //Networking events
  TWebSocketOnOpenProc = procedure (const aWebSocket: TWebSocket) of object;
  TWebSocketOnErrorProc = procedure (const aWebSocket: TWebSocket) of object;
  TWebSocketOnCloseProc = procedure (const aWebSocket: TWebSocket; const aWasClean: Boolean; const aCode: Word; const aReason: UTF8String) of object;
  //Message events
  TWebSocketOnMessageProc = procedure (const aWebSocket: TWebSocket; const aMessage: TWebSocketMessage) of object;

  TWebSocketProtocols = array of UTF8String;

  TWebSocketMessageType = (mtUTF8, mtBinary);

  TWebSocketMessage = class
  protected
    fMessageType: TWebSocketMessageType;
    fIsFragment: Boolean;
    fBuffer: Pointer;
    fBufferSize: Cardinal;

    fAsUTF8: UTF8String;
  public
    constructor Create(const aMessageType: TWebSocketMessageType);
    destructor Destroy; override;

    function AsUTF8: UTF8String;

    property MessageType: TWebSocketMessageType read fMessageType;
    property IsFragment: Boolean read fIsFragment;
    property Buffer: Pointer read fBuffer;
    property BufferSize: Cardinal read fBufferSize;
  end;

  TWebSocket = class abstract
  protected
    fURL: UTF8String;
    fReadyState: TWebSocketReadyState;
    fBufferAmount: Cardinal;

    fOnOpen: TWebSocketOnOpenProc;
    fOnError: TWebSocketOnErrorProc;
    fOnClose: TWebSocketOnCloseProc;

    fExtensions: UTF8String;
    fProtocol: TWebSocketProtocols;

    fOnMessage: TWebSocketOnMessageProc;

    procedure TriggerOnOpen; inline;
    procedure TriggerOnError; inline;
    procedure TriggerOnClose(const aWasClean: Boolean; const aCode: Word; const aReason: UTF8String); inline;
  public
    procedure Connect(var aTransportEndpoint); virtual; abstract;
    procedure Close(const aCode: Word = 1000; const aReason: UTF8String = ''); virtual; abstract;

    procedure SendUTF8(const aData: UTF8String); virtual; abstract;
    procedure SendBinary(const aData: Pointer; const aDataSize: Cardinal); virtual; abstract;

    //Converting routines
    function BufferToUTF8(const aBuffer: Pointer; const aBufferSize: Cardinal): UTF8String; inline;

    property URL: UTF8String read fURL;
    property ReadyState: TWebSocketReadyState read fReadyState;
    property BufferAmount: Cardinal read fBufferAmount;

    property OnOpen: TWebSocketOnOpenProc read fOnOpen write fOnOpen;
    property OnError: TWebSocketOnErrorProc read fOnError write fOnError;
    property OnClose: TWebSocketOnCloseProc read fOnClose write fOnClose;

    property Extensions: UTF8String read fExtensions;
    property Protocol: TWebSocketProtocols read fProtocol;

    property OnMessage: TWebSocketOnMessageProc read fOnMessage write fOnMessage;
  end;

implementation

{ TWebSocketMessage }

function TWebSocketMessage.AsUTF8: UTF8String;
begin
  if fAsUTF8 = '' then
  begin
    SetString(fAsUTF8, nil, fBufferSize);
    Move(fBuffer^, Pointer(fAsUTF8)^, fBufferSize);
  end;

  Result := fAsUTF8;
end;

constructor TWebSocketMessage.Create(const aMessageType: TWebSocketMessageType);
begin
  inherited Create;

  fMessageType := aMessageType;
  fIsFragment := True;

  fBuffer := nil;
  fBufferSize := 0;
end;

destructor TWebSocketMessage.Destroy;
begin
  inherited;
end;

{ TWebSocket }

procedure TWebSocket.TriggerOnClose(const aWasClean: Boolean; const aCode: Word; const aReason: UTF8String);
begin
  if Assigned(fOnClose) then
    fOnClose(Self, aWasClean, aCode, aReason);
end;

procedure TWebSocket.TriggerOnError;
begin
  if Assigned(fOnError) then
    fOnError(Self);
end;

procedure TWebSocket.TriggerOnOpen;
begin
  if Assigned(fOnOpen) then
    fOnOpen(Self);
end;

function TWebSocket.BufferToUTF8(const aBuffer: Pointer; const aBufferSize: Cardinal): UTF8String;
begin
  SetString(Result, nil, aBufferSize);
  Move(aBuffer^, Pointer(Result)^, aBufferSize);
end;

end.

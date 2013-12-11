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

  *** BEGIN LICENSE BLOCK *****
  Version: MPL 1.1/GPL 2.0/LGPL 2.1

  The contents of this file are subject to the Mozilla Public License Version
  1.1 (the "License"); you may not use this file except in compliance with
  the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL
}
unit uOSWebSocketHandler;

interface

uses
  uOSTransport,
  uOSWebSocket,
  uOSWebSocketServer,
  dwsHTTPSysServer,
  dwsWebEnvironment,
  SRWLock,
  Generics.Collections,
  System.Classes;

const
  C_DEFAULT_FRAGMENT_BUFFER_SIZE = 4096 * 2;

type
  TWebSocketId = Int64;
  TWebSocketHandler = class;

  //Handler events
  TOnHandlerAcceptConnection = procedure (aRequest: TWebRequest; aResponse: TWebResponse; var aAccept: Boolean) of object;

  TWebSocketHandlerMessage = class (TWebSocketMessage)
  private
  protected
  public
    procedure SetBuffer(const aBuffer: Pointer; aSize: Cardinal); inline;
  end;

  TWebSocketHandler = class (TWebSocketContainer)
  private
    fFragmentBufferSize: Cardinal;

    fUTF8Message: TWebSocketHandlerMessage;
    fBinaryMessage: TWebSocketHandlerMessage;

    fOnAcceptConnection: TOnHandlerAcceptConnection;
  protected
    procedure TriggerOnMessage(const aWebSocket: TWebSocketServer; const aMessage: TWebSocketHandlerMessage); inline;

    procedure TriggerWebSocketReceiveUTF8Buffer(const aWebSocket: TWebSocketServer; const aBuffer: Pointer; const aBufferSize: Cardinal); override;
    procedure TriggerWebSocketReceiveUTF8BufferFragment(const aWebSocket: TWebSocketServer; const aBuffer: Pointer; const aBufferSize: Cardinal); override;
    procedure TriggerWebSocketReceiveBinaryBuffer(const aWebSocket: TWebSocketServer; const aBuffer: Pointer; const aBufferSize: Cardinal); override;
    procedure TriggerWebSocketReceiveBinaryBufferFragment(const aWebSocket: TWebSocketServer; const aBuffer: Pointer; const aBufferSize: Cardinal); override;
  public
    constructor Create(const aFragmentsBufferSize: Cardinal = C_DEFAULT_FRAGMENT_BUFFER_SIZE);
    destructor Destroy; override;

    procedure AcceptConnection(aRequest: TWebRequest; aResponse: TWebResponse; var aAccept: Boolean);

    property OnAcceptConnection: TOnHandlerAcceptConnection read fOnAcceptConnection write fOnAcceptConnection;
  end;

implementation

uses
  uOSWebSocketAPI,
  System.SysUtils,
  Winapi.Windows;

{ TWebSocketHandler }

procedure TWebSocketHandler.AcceptConnection(aRequest: TWebRequest; aResponse: TWebResponse; var aAccept: Boolean);
begin
  if Assigned(fOnAcceptConnection) then
    fOnAcceptConnection(aRequest, aResponse, aAccept)
  else
    aAccept := False;
end;

constructor TWebSocketHandler.Create(const aFragmentsBufferSize: Cardinal);
begin
  inherited Create;

  fFragmentBufferSize := C_DEFAULT_FRAGMENT_BUFFER_SIZE;

  fUTF8Message := TWebSocketHandlerMessage.Create(mtUTF8);
  fBinaryMessage := TWebSocketHandlerMessage.Create(mtBinary);
end;

destructor TWebSocketHandler.Destroy;
begin
  fBinaryMessage.Free;
  fUTF8Message.Free;

  inherited;
end;

procedure TWebSocketHandler.TriggerOnMessage(const aWebSocket: TWebSocketServer; const aMessage: TWebSocketHandlerMessage);
begin
  if Assigned(aWebSocket.OnMessage) then
    aWebSocket.OnMessage(aWebSocket, aMessage);
end;

procedure TWebSocketHandler.TriggerWebSocketReceiveBinaryBuffer(const aWebSocket: TWebSocketServer;
  const aBuffer: Pointer; const aBufferSize: Cardinal);
begin
  inherited;

  if aWebSocket.BinaryBuffer.Size > 0 then
  begin
    aWebSocket.BinaryBuffer.Write(aBuffer^, aBufferSize);
    fBinaryMessage.SetBuffer(aWebSocket.BinaryBuffer.Memory, aWebSocket.BinaryBuffer.Size);

    try
      TriggerOnMessage(aWebSocket, fBinaryMessage);
    finally
      aWebSocket.BinaryBuffer.Clear;
    end;
  end
  else
    begin
      fBinaryMessage.SetBuffer(aBuffer, aBufferSize);
      TriggerOnMessage(aWebSocket, fBinaryMessage);
    end;
end;

procedure TWebSocketHandler.TriggerWebSocketReceiveBinaryBufferFragment(const aWebSocket: TWebSocketServer;
  const aBuffer: Pointer; const aBufferSize: Cardinal);
begin
  inherited;

  //ToDo: check whenever buffer size is too high, request new buffer size or notify of message fragment
  aWebSocket.BinaryBuffer.Write(aBuffer^, aBufferSize);
end;

procedure TWebSocketHandler.TriggerWebSocketReceiveUTF8Buffer(const aWebSocket: TWebSocketServer;
  const aBuffer: Pointer; const aBufferSize: Cardinal);
begin
  inherited;

  fUTF8Message.fIsFragment := False;

  if aWebSocket.UTF8Buffer.Size > 0 then
  begin
    aWebSocket.UTF8Buffer.Write(aBuffer^, aBufferSize);
    fUTF8Message.SetBuffer(aWebSocket.UTF8Buffer.Memory, aWebSocket.UTF8Buffer.Size);

    try
      TriggerOnMessage(aWebSocket, fUTF8Message);
    finally
      aWebSocket.UTF8Buffer.Clear;
    end;
  end
  else
    begin
      fUTF8Message.SetBuffer(aBuffer, aBufferSize);
      TriggerOnMessage(aWebSocket, fUTF8Message);
    end;
end;

procedure TWebSocketHandler.TriggerWebSocketReceiveUTF8BufferFragment(const aWebSocket: TWebSocketServer;
  const aBuffer: Pointer; const aBufferSize: Cardinal);
begin
  inherited;

  //ToDo: check whenever buffer size is too high, request new buffer size or notify of message fragment
  aWebSocket.UTF8Buffer.Write(aBuffer^, aBufferSize);
end;

{ TWebSocketHandlerMessage }

procedure TWebSocketHandlerMessage.SetBuffer(const aBuffer: Pointer; aSize: Cardinal);
begin
  fAsUTF8 := '';
  fBuffer := aBuffer;
  fBufferSize := aSize;
end;

end.

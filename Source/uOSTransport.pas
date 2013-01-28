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
  Abstraction of transport and transport endpoint methods
  Currently only for needs of HttpSys2 transport endpoint

  *** BEGIN LICENSE BLOCK *****
  Version: MPL 1.1/GPL 2.0/LGPL 2.1

  The contents of this file are subject to the Mozilla Public License Version
  1.1 (the "License"); you may not use this file except in compliance with
  the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL
}
unit uOSTransport;

interface

type
  TTransportContext = Pointer;
  TTransportEndpointId = NativeUInt;
  TTransportEndpoint = class;

  TTrasportStatus = (tsDone, tsError, tsEOF, tsDisconnected);

  TOnTransportConnectDisconnectProc = procedure (const aStatus: TTrasportStatus; const aContext: TTransportContext) of object;
  TOnTransportCallbackProc = procedure (const aStatus: TTrasportStatus; const aBytesProcessed: Cardinal; const aContext: TTransportContext) of object;

  TOnTransportEndpointShutdownProc = procedure of object;

  TTransport = class abstract
  private
  protected
  public
    procedure Connect(const aEndpoint: TTransportEndpoint; const aContext: TTransportContext = nil); virtual; abstract;
    procedure Disconnect(const aEndpoint: TTransportEndpoint; const aContext: TTransportContext = nil); virtual; abstract;

    procedure Shutdown(const aEndpoint: TTransportEndpoint); virtual; abstract;

    procedure Write(const aEndpoint: TTransportEndpoint; const aBuffer: Pointer; const aBufferSize: Cardinal;
      const aContext: TTransportContext = nil); virtual; abstract;
    procedure Read(const aEndpoint: TTransportEndpoint; const aBuffer: Pointer; const aBufferSize: Cardinal;
      const aContext: TTransportContext = nil); virtual; abstract;
  end;

  TTransportEndpoint = class abstract
  private
    fId: TTransportEndpointId;
  protected
    fTransport: TTransport;

    fOnConnect: TOnTransportConnectDisconnectProc;
    fOnDisconnect: TOnTransportConnectDisconnectProc;
    fOnShutdown: TOnTransportEndpointShutdownProc;
    fOnWrite: TOnTransportCallbackProc;
    fOnRead: TOnTransportCallbackProc;
  public
    constructor Create(const aId: TTransportEndpointId; const aTransport: TTransport);
    destructor Destroy; override;

    procedure Connect(const aContext: TTransportContext = nil); virtual; abstract;
    procedure Disconnect(const aContext: TTransportContext = nil); virtual; abstract;

    procedure Shutdown; virtual; abstract;

    procedure Write(const aBuffer: Pointer; const aBufferSize: Cardinal; const aContext: TTransportContext = nil); virtual; abstract;
    procedure Read(const aBuffer: Pointer; const aBufferSize: Cardinal; const aContext: TTransportContext = nil); virtual; abstract;

    property OnConnect: TOnTransportConnectDisconnectProc read fOnConnect write fOnConnect;
    property OnDisconnect: TOnTransportConnectDisconnectProc read fOnDisconnect write fOnDisconnect;
    property OnShutdown: TOnTransportEndpointShutdownProc read fOnShutdown write fOnShutdown;
    property OnWrite: TOnTransportCallbackProc read fOnWrite write fOnWrite;
    property OnRead: TOnTransportCallbackProc read fOnRead write fOnRead;

    property Id: TTransportEndpointId read fId;
  end;

implementation

{ TTransportEndpoint }

constructor TTransportEndpoint.Create(const aId: TTransportEndpointId; const aTransport: TTransport);
begin
  fId := aId;
  fTransport := aTransport;
end;

destructor TTransportEndpoint.Destroy;
begin
  if Assigned(fOnShutdown) then
    fOnShutdown;

  inherited;
end;

end.

{
  HTTP.sys API definitions

  This file is based on Synopse framework and is an attempt
  at supporting HTTP.SYS 2.0

  Synopse framework. Copyright (C) 2012 Arnaud Bouchez
    Synopse Informatique - http://synopse.info

  *** BEGIN LICENSE BLOCK *****
  Version: MPL 1.1/GPL 2.0/LGPL 2.1

  The contents of this file are subject to the Mozilla Public License Version
  1.1 (the "License"); you may not use this file except in compliance with
  the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL
}
unit dwsHTTPSysAPI;

interface

uses
   Windows, SysUtils,
   SynWinSock;

{$MINENUMSIZE 4}
{$A+}

type
   ULONGLONG = Int64;
   HTTP_OPAQUE_ID = ULONGLONG;
   HTTP_URL_CONTEXT = HTTP_OPAQUE_ID;
   HTTP_REQUEST_ID = HTTP_OPAQUE_ID;
   HTTP_CONNECTION_ID = HTTP_OPAQUE_ID;
   HTTP_RAW_CONNECTION_ID = HTTP_OPAQUE_ID;

   HTTP_URL_GROUP_ID = HTTP_OPAQUE_ID;
   HTTP_SERVER_SESSION_ID = HTTP_OPAQUE_ID;

   // HTTP API version used
   HTTPAPI_VERSION = packed record
      MajorVersion : word;
      MinorVersion : word;
   end;

   // the req* values identify Request Headers, and resp* Response Headers
   THttpHeader = (
      reqCacheControl,
      reqConnection,
      reqDate,
      reqKeepAlive,
      reqPragma,
      reqTrailer,
      reqTransferEncoding,
      reqUpgrade,
      reqVia,
      reqWarning,
      reqAllow,
      reqContentLength,
      reqContentType,
      reqContentEncoding,
      reqContentLanguage,
      reqContentLocation,
      reqContentMd5,
      reqContentRange,
      reqExpires,
      reqLastModified,
      reqAccept,
      reqAcceptCharset,
      reqAcceptEncoding,
      reqAcceptLanguage,
      reqAuthorization,
      reqCookie,
      reqExpect,
      reqFrom,
      reqHost,
      reqIfMatch,
      reqIfModifiedSince,
      reqIfNoneMatch,
      reqIfRange,
      reqIfUnmodifiedSince,
      reqMaxForwards,
      reqProxyAuthorization,
      reqReferer,
      reqRange,
      reqTe,
      reqTranslate,
      reqUserAgent,
      respAcceptRanges = 20,
      respAge,
      respEtag,
      respLocation,
      respProxyAuthenticate,
      respRetryAfter,
      respServer,
      respSetCookie,
      respVary,
      respWwwAuthenticate
      );

   THttpVerb = (
      hvUnparsed,
      hvUnknown,
      hvInvalid,
      hvOPTIONS,
      hvGET,
      hvHEAD,
      hvPOST,
      hvPUT,
      hvDELETE,
      hvTRACE,
      hvCONNECT,
      hvTRACK,  // used by Microsoft Cluster Server for a non-logged trace
      hvMOVE,
      hvCOPY,
      hvPROPFIND,
      hvPROPPATCH,
      hvMKCOL,
      hvLOCK,
      hvUNLOCK,
      hvSEARCH,
      hvMaximum
      );

   THttpChunkType = (
      hctFromMemory,
      hctFromFileHandle,
      hctFromFragmentCache);

   THttpServiceConfigID = (
      hscIPListenList,
      hscSSLCertInfo,
      hscUrlAclInfo,
      hscMax
      );
   THttpServiceConfigQueryType = (
      hscQueryExact,
      hscQueryNext,
      hscQueryMax
      );

   // Pointers overlap and point into pFullUrl. nil if not present.
   HTTP_COOKED_URL = record
      FullUrlLength : word;     // in bytes not including the #0
      HostLength : word;        // in bytes not including the #0
      AbsPathLength : word;     // in bytes not including the #0
      QueryStringLength : word; // in bytes not including the #0
      pFullUrl : PWideChar;     // points to "http://hostname:port/abs/.../path?query"
      pHost : PWideChar;        // points to the first char in the hostname
      pAbsPath : PWideChar;     // Points to the 3rd '/' char
      pQueryString : PWideChar; // Points to the 1st '?' char or #0
   end;

   HTTP_TRANSPORT_ADDRESS = record
      pRemoteAddress : PSOCKADDR;
      pLocalAddress : PSOCKADDR;
   end;

   HTTP_UNKNOWN_HEADER = record
      NameLength : word;          // in bytes not including the #0
      RawValueLength : word;      // in bytes not including the n#0
      pName : PAnsiChar;          // The header name (minus the ':' character)
      pRawValue : PAnsiChar;      // The header value
   end;
   PHTTP_UNKNOWN_HEADER = ^HTTP_UNKNOWN_HEADER;

   HTTP_KNOWN_HEADER = record
      RawValueLength : word;     // in bytes not including the #0
      pRawValue : PAnsiChar;
   end;
   PHTTP_KNOWN_HEADER = ^HTTP_KNOWN_HEADER;

   HTTP_RESPONSE_HEADERS = record
      // number of entries in the unknown HTTP headers array
      UnknownHeaderCount : word;
      // array of unknown HTTP headers
      pUnknownHeaders : PHTTP_UNKNOWN_HEADER;
      // Reserved, must be 0
      TrailerCount : word;
      // Reserved, must be nil
      pTrailers : pointer;
      // Known headers
      KnownHeaders : array[low(THttpHeader)..respWwwAuthenticate] of HTTP_KNOWN_HEADER;
   end;

   HTTP_REQUEST_HEADERS = record
      // number of entries in the unknown HTTP headers array
      UnknownHeaderCount : word;
      // array of unknown HTTP headers
      pUnknownHeaders : PHTTP_UNKNOWN_HEADER;
      // Reserved, must be 0
      TrailerCount : word;
      // Reserved, must be nil
      pTrailers : pointer;
      // Known headers
      KnownHeaders : array[low(THttpHeader)..reqUserAgent] of HTTP_KNOWN_HEADER;
   end;

   HTTP_BYTE_RANGE = record
      StartingOffset : ULARGE_INTEGER;
      Length : ULARGE_INTEGER;
   end;

   // we use 3 distinct HTTP_DATA_CHUNK_* records since variable records
   // alignment is buggy/non compatible under Delphi XE3
   HTTP_DATA_CHUNK_INMEMORY = record
      DataChunkType : THttpChunkType; // always hctFromMemory
      Reserved1 : ULONG;
      pBuffer : pointer;
      BufferLength : ULONG;
      Reserved2 : ULONG;
      Reserved3 : ULONG;
   end;
   PHTTP_DATA_CHUNK_INMEMORY = ^HTTP_DATA_CHUNK_INMEMORY;

   HTTP_DATA_CHUNK_FILEHANDLE = record
      DataChunkType : THttpChunkType; // always hctFromFileHandle
      ByteRange : HTTP_BYTE_RANGE;
      FileHandle : THandle;
   end;

   HTTP_DATA_CHUNK_FRAGMENTCACHE = record
      DataChunkType : THttpChunkType; // always hctFromFragmentCache
      FragmentNameLength : word;      // in bytes not including the #0
      pFragmentName : PWideChar;
   end;

   HTTP_SSL_CLIENT_CERT_INFO = record
      CertFlags : ULONG;
      CertEncodedSize : ULONG;
      pCertEncoded : PUCHAR;
      Token : THandle;
      CertDeniedByMapper : boolean;
   end;
   PHTTP_SSL_CLIENT_CERT_INFO = ^HTTP_SSL_CLIENT_CERT_INFO;

   HTTP_SSL_INFO = record
      ServerCertKeySize : word;
      ConnectionKeySize : word;
      ServerCertIssuerSize : ULONG;
      ServerCertSubjectSize : ULONG;
      pServerCertIssuer : PAnsiChar;
      pServerCertSubject : PAnsiChar;
      pClientCertInfo : PHTTP_SSL_CLIENT_CERT_INFO;
      SslClientCertNegotiated : ULONG;
   end;
   PHTTP_SSL_INFO = ^HTTP_SSL_INFO;

   HTTP_SERVICE_CONFIG_URLACL_KEY = record
      pUrlPrefix : PWideChar;
   end;

   HTTP_SERVICE_CONFIG_URLACL_PARAM = record
      pStringSecurityDescriptor : PWideChar;
   end;

   HTTP_SERVICE_CONFIG_URLACL_SET = record
      KeyDesc : HTTP_SERVICE_CONFIG_URLACL_KEY;
      ParamDesc : HTTP_SERVICE_CONFIG_URLACL_PARAM;
   end;

   HTTP_SERVICE_CONFIG_URLACL_QUERY = record
      QueryDesc : THttpServiceConfigQueryType;
      KeyDesc : HTTP_SERVICE_CONFIG_URLACL_KEY;
      dwToken : DWORD;
   end;

   HTTP_REQUEST_INFO_TYPE = (
      HttpRequestInfoTypeAuth
      );

   HTTP_AUTH_STATUS = (
      HttpAuthStatusSuccess,
      HttpAuthStatusNotAuthenticated,
      HttpAuthStatusFailure
      );

   HTTP_REQUEST_AUTH_TYPE = (
      HttpRequestAuthTypeNone,
      HttpRequestAuthTypeBasic,
      HttpRequestAuthTypeDigest,
      HttpRequestAuthTypeNTLM,
      HttpRequestAuthTypeNegotiate,
      HttpRequestAuthTypeKerberos
      );

   SECURITY_STATUS = ULONG;

   HTTP_REQUEST_AUTH_INFO = record
      AuthStatus : HTTP_AUTH_STATUS;
      SecStatus : SECURITY_STATUS;
      Flags : ULONG;
      AuthType : HTTP_REQUEST_AUTH_TYPE;
      AccessToken : THandle;
      ContextAttributes : ULONG;
      PackedContextLength : ULONG;
      PackedContextType : ULONG;
      PackedContext : PVOID;
      MutualAuthDataLength : ULONG;
      pMutualAuthData : PCHAR;
   end;
   PHTTP_REQUEST_AUTH_INFO = ^HTTP_REQUEST_AUTH_INFO;

   HTTP_REQUEST_INFO = record
      InfoType : HTTP_REQUEST_INFO_TYPE;
      InfoLength : ULONG;
      pInfo : PVOID;
   end;
   PHTTP_REQUEST_INFO = ^HTTP_REQUEST_INFO;

   /// structure used to handle data associated with a specific request
   HTTP_REQUEST_V2 = record
      // either 0 (Only Header), either HTTP_RECEIVE_REQUEST_FLAG_COPY_BODY
      Flags : cardinal;
      // An identifier for the connection on which the request was received
      ConnectionId : HTTP_CONNECTION_ID;
      // A value used to identify the request when calling
      // HttpReceiveRequestEntityBody, HttpSendHttpResponse, and/or
      // HttpSendResponseEntityBody
      RequestId : HTTP_REQUEST_ID;
      // The context associated with the URL prefix
      UrlContext : HTTP_URL_CONTEXT;
      // The HTTP version number
      Version : HTTPAPI_VERSION;
      // An HTTP verb associated with this request
      Verb : THttpVerb;
      // The length of the verb string if the Verb field is hvUnknown
      // (in bytes not including the last #0)
      UnknownVerbLength : word;
      // The length of the raw (uncooked) URL (in bytes not including the last #0)
      RawUrlLength : word;
      // Pointer to the verb string if the Verb field is hvUnknown
      pUnknownVerb : PAnsiChar;
      // Pointer to the raw (uncooked) URL
      pRawUrl : PAnsiChar;
      // The canonicalized Unicode URL
      CookedUrl : HTTP_COOKED_URL;
      // Local and remote transport addresses for the connection
      Address : HTTP_TRANSPORT_ADDRESS;
      // The request headers.
      Headers : HTTP_REQUEST_HEADERS;
      // The total number of bytes received from network for this request
      BytesReceived : ULONGLONG;
      EntityChunkCount : word;
      pEntityChunks : pointer;
      RawConnectionId : HTTP_RAW_CONNECTION_ID;
      // SSL connection information
      pSslInfo : PHTTP_SSL_INFO;
      // V2 new fields
      RequestInfoCount : USHORT;
      pRequestInfo : PHTTP_REQUEST_INFO;
   end;
   PHTTP_REQUEST_V2 = ^HTTP_REQUEST_V2;

   HTTP_RESPONSE_INFO_TYPE = (
      HttpResponseInfoTypeMultipleKnownHeaders,
      HttpResponseInfoTypeAuthenticationProperty,
      HttpResponseInfoTypeQosProperty,
      HttpResponseInfoTypeChannelBind
      );

   HTTP_RESPONSE_INFO = record
      Typ : HTTP_RESPONSE_INFO_TYPE;
      Length : ULONG;
      pInfo : Pointer;
   end;
   PHTTP_RESPONSE_INFO = ^HTTP_RESPONSE_INFO;

   HTTP_RESPONSE_V2 = object
   public
      Flags : cardinal;
      // The raw HTTP protocol version number
      Version : HTTPAPI_VERSION;
      // The HTTP status code (e.g., 200)
      StatusCode : word;
      // in bytes not including the '\0'
      ReasonLength : word;
      // The HTTP reason (e.g., "OK"). This MUST not contain non-ASCII characters
      // (i.e., all chars must be in range 0x20-0x7E).
      pReason : PAnsiChar;
      // The response headers
      Headers : HTTP_RESPONSE_HEADERS;
      // number of elements in pEntityChunks[] array
      EntityChunkCount : word;
      // pEntityChunks points to an array of EntityChunkCount HTTP_DATA_CHUNK_*
      pEntityChunks : pointer;
      // V2 new fields
      ResponseInfoCount : USHORT;
      pResponseInfo : PHTTP_RESPONSE_INFO;

      // will set both StatusCode and Reason
      // - OutStatus is a temporary variable
      // - if DataChunkForErrorContent is set, it will be used to add a content
      // body in the response with the textual representation of the error code
      procedure SetStatus(code : integer; var OutStatus : RawByteString;
         DataChunkForErrorContent : PHTTP_DATA_CHUNK_INMEMORY = nil;
         const ErrorMsg : RawByteString = '');
      // will set the content of the reponse, and ContentType header
      procedure SetContent(var DataChunk : HTTP_DATA_CHUNK_INMEMORY;
         const Content : RawByteString; const ContentType : RawByteString = 'text/html');
      /// will set all header values from lines
      // - Content-Type/Content-Encoding/Location will be set in KnownHeaders[]
      // - all other headers will be set in temp UnknownHeaders[0..MaxUnknownHeader]
      procedure SetHeaders(P : PAnsiChar; UnknownHeaders : PHTTP_UNKNOWN_HEADER;
         MaxUnknownHeader : integer);
   end;
   PHTTP_RESPONSE_V2 = ^HTTP_RESPONSE_V2;

   HTTP_PROPERTY_FLAGS = ULONG;

   HTTP_ENABLED_STATE = (
      HttpEnabledStateActive,
      HttpEnabledStateInactive
      );
   PHTTP_ENABLED_STATE = ^HTTP_ENABLED_STATE;

   HTTP_STATE_INFO = record
      Flags : HTTP_PROPERTY_FLAGS;
      State : HTTP_ENABLED_STATE;
   end;
   PHTTP_STATE_INFO = ^HTTP_STATE_INFO;

   THTTP_503_RESPONSE_VERBOSITY = (
      Http503ResponseVerbosityBasic,
      Http503ResponseVerbosityLimited,
      Http503ResponseVerbosityFull
      );
   PHTTP_503_RESPONSE_VERBOSITY = ^ THTTP_503_RESPONSE_VERBOSITY;

   HTTP_QOS_SETTING_TYPE = (
      HttpQosSettingTypeBandwidth,
      HttpQosSettingTypeConnectionLimit,
      HttpQosSettingTypeFlowRate // Windows Server 2008 R2 and Windows 7 only.
      );
   PHTTP_QOS_SETTING_TYPE = ^HTTP_QOS_SETTING_TYPE;

   HTTP_QOS_SETTING_INFO = record
      QosType : HTTP_QOS_SETTING_TYPE;
      QosSetting : Pointer;
   end;
   PHTTP_QOS_SETTING_INFO = ^HTTP_QOS_SETTING_INFO;

   HTTP_CONNECTION_LIMIT_INFO = record
      Flags : HTTP_PROPERTY_FLAGS;
      MaxConnections : ULONG;
   end;
   PHTTP_CONNECTION_LIMIT_INFO = ^HTTP_CONNECTION_LIMIT_INFO;

   HTTP_BANDWIDTH_LIMIT_INFO = record
      Flags : HTTP_PROPERTY_FLAGS;
      MaxBandwidth : ULONG;
   end;
   PHTTP_BANDWIDTH_LIMIT_INFO = ^HTTP_BANDWIDTH_LIMIT_INFO;

const
   HTTP_MIN_ALLOWED_BANDWIDTH_THROTTLING_RATE {:ULONG} = 1024;
   HTTP_LIMIT_INFINITE {:ULONG} = ULONG(-1);

type
   HTTP_SERVICE_CONFIG_TIMEOUT_KEY = (
      IdleConnectionTimeout = 0,
      HeaderWaitTimeout
      );
   PHTTP_SERVICE_CONFIG_TIMEOUT_KEY = ^HTTP_SERVICE_CONFIG_TIMEOUT_KEY;

   HTTP_SERVICE_CONFIG_TIMEOUT_PARAM = USHORT;
   PHTTP_SERVICE_CONFIG_TIMEOUT_PARAM = ^HTTP_SERVICE_CONFIG_TIMEOUT_PARAM;

   HTTP_SERVICE_CONFIG_TIMEOUT_SET = record
      KeyDesc : HTTP_SERVICE_CONFIG_TIMEOUT_KEY;
      ParamDesc : HTTP_SERVICE_CONFIG_TIMEOUT_PARAM;
   end;
   PHTTP_SERVICE_CONFIG_TIMEOUT_SET = ^HTTP_SERVICE_CONFIG_TIMEOUT_SET;

   HTTP_TIMEOUT_LIMIT_INFO = record
      Flags : HTTP_PROPERTY_FLAGS;
      EntityBody : USHORT;
      DrainEntityBody : USHORT;
      RequestQueue : USHORT;
      IdleConnection : USHORT;
      HeaderWait : USHORT;
      MinSendRate : USHORT;
   end;
   PHTTP_TIMEOUT_LIMIT_INFO = ^HTTP_TIMEOUT_LIMIT_INFO;

   HTTP_SERVER_AUTHENTICATION_DIGEST_PARAMS = record
      DomainNameLength : USHORT;
      DomainName : PWideChar;
      RealmLength : USHORT;
      Realm : PWideChar;
   end;
   PHTTP_SERVER_AUTHENTICATION_DIGEST_PARAMS = ^HTTP_SERVER_AUTHENTICATION_DIGEST_PARAMS;

   HTTP_SERVER_AUTHENTICATION_BASIC_PARAMS = record
      RealmLength : USHORT;
      Realm : PWideChar;
   end;
   PHTTP_SERVER_AUTHENTICATION_BASIC_PARAMS = ^HTTP_SERVER_AUTHENTICATION_BASIC_PARAMS;

const
   HTTP_AUTH_ENABLE_BASIC = $00000001;
   HTTP_AUTH_ENABLE_DIGEST = $00000002;
   HTTP_AUTH_ENABLE_NTLM = $00000004;
   HTTP_AUTH_ENABLE_NEGOTIATE = $00000008;
   HTTP_AUTH_ENABLE_ALL = $0000000F;

type
   HTTP_SERVER_AUTHENTICATION_INFO = record
      Flags : HTTP_PROPERTY_FLAGS;
      AuthSchemes : ULONG;
      ReceiveMutualAuth : BOOL;
      ReceiveContextHandle : BOOL;
      DisableNTLMCredentialCaching : BOOL;
      DigestParams : HTTP_SERVER_AUTHENTICATION_DIGEST_PARAMS;
      BasicParams : HTTP_SERVER_AUTHENTICATION_BASIC_PARAMS;
   end;
   PHTTP_SERVER_AUTHENTICATION_INFO = ^HTTP_SERVER_AUTHENTICATION_INFO;

const
   // Logging option flags. When used in the logging configuration alters
   // some default logging behaviour.

   // HTTP_LOGGING_FLAG_LOCAL_TIME_ROLLOVER - This flag is used to change
   //      the log file rollover to happen by local time based. By default
   //      log file rollovers happen by GMT time.
   HTTP_LOGGING_FLAG_LOCAL_TIME_ROLLOVER = 1;

   // HTTP_LOGGING_FLAG_USE_UTF8_CONVERSION - When set the unicode fields
   //      will be converted to UTF8 multibytes when writting to the log
   //      files. When this flag is not present, the local code page
   //      conversion happens.
   HTTP_LOGGING_FLAG_USE_UTF8_CONVERSION = 2;

   // HTTP_LOGGING_FLAG_LOG_ERRORS_ONLY -
   // HTTP_LOGGING_FLAG_LOG_SUCCESS_ONLY - These two flags are used to
   //      to do selective logging. If neither of them are present both
   //      types of requests will be logged. Only one these flags can be
   //      set at a time. They are mutually exclusive.
   HTTP_LOGGING_FLAG_LOG_ERRORS_ONLY = 4;
   HTTP_LOGGING_FLAG_LOG_SUCCESS_ONLY = 8;

   //
   // The known log fields recognized/supported by HTTPAPI. Following fields
   // are used for W3C logging. Subset of them are also used for error
   // logging.
   //
   HTTP_LOG_FIELD_DATE = $00000001;
   HTTP_LOG_FIELD_TIME = $00000002;
   HTTP_LOG_FIELD_CLIENT_IP = $00000004;
   HTTP_LOG_FIELD_USER_NAME = $00000008;
   HTTP_LOG_FIELD_SITE_NAME = $00000010;
   HTTP_LOG_FIELD_COMPUTER_NAME = $00000020;
   HTTP_LOG_FIELD_SERVER_IP = $00000040;
   HTTP_LOG_FIELD_METHOD = $00000080;
   HTTP_LOG_FIELD_URI_STEM = $00000100;
   HTTP_LOG_FIELD_URI_QUERY = $00000200;
   HTTP_LOG_FIELD_STATUS = $00000400;
   HTTP_LOG_FIELD_WIN32_STATUS = $00000800;
   HTTP_LOG_FIELD_BYTES_SENT = $00001000;
   HTTP_LOG_FIELD_BYTES_RECV = $00002000;
   HTTP_LOG_FIELD_TIME_TAKEN = $00004000;
   HTTP_LOG_FIELD_SERVER_PORT = $00008000;
   HTTP_LOG_FIELD_USER_AGENT = $00010000;
   HTTP_LOG_FIELD_COOKIE = $00020000;
   HTTP_LOG_FIELD_REFERER = $00040000;
   HTTP_LOG_FIELD_VERSION = $00080000;
   HTTP_LOG_FIELD_HOST = $00100000;
   HTTP_LOG_FIELD_SUB_STATUS = $00200000;

   HTTP_ALL_NON_ERROR_LOG_FIELDS = HTTP_LOG_FIELD_SUB_STATUS*2-1;

   //
   // Fields that are used only for error logging.
   //
   HTTP_LOG_FIELD_CLIENT_PORT = $00400000;
   HTTP_LOG_FIELD_URI = $00800000;
   HTTP_LOG_FIELD_SITE_ID = $01000000;
   HTTP_LOG_FIELD_REASON = $02000000;
   HTTP_LOG_FIELD_QUEUE_NAME = $04000000;

type
   HTTP_LOGGING_TYPE = (
      HttpLoggingTypeW3C,
      HttpLoggingTypeIIS,
      HttpLoggingTypeNCSA,
      HttpLoggingTypeRaw
      );

   HTTP_LOGGING_ROLLOVER_TYPE = (
      HttpLoggingRolloverSize,
      HttpLoggingRolloverDaily,
      HttpLoggingRolloverWeekly,
      HttpLoggingRolloverMonthly,
      HttpLoggingRolloverHourly
      );

   HTTP_LOGGING_INFO = record
      Flags : HTTP_PROPERTY_FLAGS;
      LoggingFlags : ULONG;
      SoftwareName : PWideChar;
      SoftwareNameLength : USHORT;
      DirectoryNameLength : USHORT;
      DirectoryName : PWideChar;
      Format : HTTP_LOGGING_TYPE;
      Fields : ULONG;
      pExtFields : PVOID;
      NumOfExtFields : USHORT;
      MaxRecordSize : USHORT;
      RolloverType : HTTP_LOGGING_ROLLOVER_TYPE;
      RolloverSize : ULONG;
      pSecurityDescriptor : PSECURITY_DESCRIPTOR;
   end;
   PHTTP_LOGGING_INFO = ^HTTP_LOGGING_INFO;

   HTTP_LOG_DATA_TYPE = (
      HttpLogDataTypeFields
      );

   HTTP_LOG_DATA = record
      Typ : HTTP_LOG_DATA_TYPE
   end;
   PHTTP_LOG_DATA = ^HTTP_LOG_DATA;

   HTTP_LOG_FIELDS_DATA = record
      Base : HTTP_LOG_DATA;
      UserNameLength : USHORT;
      UriStemLength : USHORT;
      ClientIpLength : USHORT;
      ServerNameLength : USHORT;
      ServiceNameLength : USHORT;
      ServerIpLength : USHORT;
      MethodLength : USHORT;
      UriQueryLength : USHORT;
      HostLength : USHORT;
      UserAgentLength : USHORT;
      CookieLength : USHORT;
      ReferrerLength : USHORT;
      UserName : PWideChar;
      UriStem : PWideChar;
      ClientIp : PAnsiChar;
      ServerName : PAnsiChar;
      ServiceName : PAnsiChar;
      ServerIp : PAnsiChar;
      Method : PAnsiChar;
      UriQuery : PAnsiChar;
      Host : PAnsiChar;
      UserAgent : PAnsiChar;
      Cookie : PAnsiChar;
      Referrer : PAnsiChar;
      ServerPort : USHORT;
      ProtocolStatus : USHORT;
      Win32Status : ULONG;
      MethodNum : THttpVerb;
      SubStatus : USHORT;
   end;
   PHTTP_LOG_FIELDS_DATA = ^HTTP_LOG_FIELDS_DATA;

   HTTP_BINDING_INFO = record
      Flags : HTTP_PROPERTY_FLAGS;
      RequestQueueHandle : THandle;
   end;

const
   //   HTTP_VERSION_UNKNOWN : HTTPAPI_VERSION = (MajorVersion : 0; MinorVersion : 0);
   //   HTTP_VERSION_0_9 : HTTPAPI_VERSION = (MajorVersion : 0; MinorVersion : 9);
   //   HTTP_VERSION_1_0 : HTTPAPI_VERSION = (MajorVersion : 1; MinorVersion : 0);
   //   HTTP_VERSION_1_1 : HTTPAPI_VERSION = (MajorVersion : 1; MinorVersion : 1);
   //   HTTPAPI_VERSION_1 : HTTPAPI_VERSION = (MajorVersion : 1; MinorVersion : 0);
   HTTPAPI_VERSION_2 : HTTPAPI_VERSION = (MajorVersion : 2; MinorVersion : 0);

   // if set, available entity body is copied along with the request headers
   // into pEntityChunks
   HTTP_RECEIVE_REQUEST_FLAG_COPY_BODY = 1;
   // there is more entity body to be read for this request
   HTTP_REQUEST_FLAG_MORE_ENTITY_BODY_EXISTS = 1;
   // initialization for applications that use the HTTP Server API
   HTTP_INITIALIZE_SERVER = 1;
   // initialization for applications that use the HTTP configuration functions
   HTTP_INITIALIZE_CONFIG = 2;
   // see http://msdn.microsoft.com/en-us/library/windows/desktop/aa364496
   HTTP_RECEIVE_REQUEST_ENTITY_BODY_FLAG_FILL_BUFFER = 1;
   // see http://msdn.microsoft.com/en-us/library/windows/desktop/aa364499
   HTTP_SEND_RESPONSE_FLAG_PROCESS_RANGES = 1;

   HTTP_URL_FLAG_REMOVE_ALL = 1;

   /// used by THttpApiServer.Request for http.sys to send a static file
   // - the OutCustomHeader should contain the proper 'Content-type: ....'
   // corresponding to the file (e.g. by calling GetMimeContentType() function
   // from SynCommons supplyings the file name)
   HTTP_RESP_STATICFILE = '!STATICFILE';

type
   HTTP_SERVER_PROPERTY = (
      HttpServerAuthenticationProperty,
      HttpServerLoggingProperty,
      HttpServerQosProperty,
      HttpServerTimeoutsProperty,
      HttpServerQueueLengthProperty,
      HttpServerStateProperty,
      HttpServer503VerbosityProperty,
      HttpServerBindingProperty,
      HttpServerExtendedAuthenticationProperty,
      HttpServerListenEndpointProperty,
      HttpServerChannelBindProperty
      );

   THttpAPIs = (
      hInitialize, hTerminate, hCreateHttpHandle,
      hAddUrl, hRemoveUrl, hReceiveHttpRequest,
      hSendHttpResponse, hReceiveRequestEntityBody,
      hSetServiceConfiguration, hDeleteServiceConfiguration,

      hCancelHttpRequest,
      hCreateServerSession, hCloseServerSession,
      hCreateRequestQueue,
      hSetServerSessionProperty, hQueryServerSessionProperty,
      hCreateUrlGroup, hCloseUrlGroup,
      hAddUrlToUrlGroup, hRemoveUrlFromUrlGroup,
      hSetUrlGroupProperty, hQueryUrlGroupProperty);

const
   HttpNames : array[THttpAPIs] of PChar = (
      'HttpInitialize', 'HttpTerminate', 'HttpCreateHttpHandle',
      'HttpAddUrl', 'HttpRemoveUrl', 'HttpReceiveHttpRequest',
      'HttpSendHttpResponse', 'HttpReceiveRequestEntityBody',
      'HttpSetServiceConfiguration', 'HttpDeleteServiceConfiguration',

      'HttpCancelHttpRequest',
      'HttpCreateServerSession', 'HttpCloseServerSession',
      'HttpCreateRequestQueue',
      'HttpSetServerSessionProperty', 'HttpQueryServerSessionProperty',
      'HttpCreateUrlGroup', 'HttpCloseUrlGroup',
      'HttpAddUrlToUrlGroup', 'HttpRemoveUrlFromUrlGroup',
      'HttpSetUrlGroupProperty', 'HttpQueryUrlGroupProperty'
      );

type
   THttpAPI = packed record
      Module : THandle;
      {/ The HttpInitialize function initializes the HTTP Server API driver, starts it,
         if it has not already been started, and allocates data structures for the
         calling application to support response-queue creation and other operations.
         Call this function before calling any other functions in the HTTP Server API. }
      Initialize : function(Version : HTTPAPI_VERSION; Flags : cardinal;
            pReserved : pointer = nil) : HRESULT; stdcall;
      {/ The HttpTerminate function cleans up resources used by the HTTP Server API
         to process calls by an application. An application should call HttpTerminate
         once for every time it called HttpInitialize, with matching flag settings. }
      Terminate : function(Flags : cardinal;
            Reserved : integer = 0) : HRESULT; stdcall;
      {/ The HttpCreateHttpHandle function creates an HTTP request queue for the
         calling application and returns a handle to it. }
      CreateHttpHandle : function(var ReqQueueHandle : THandle;
            Reserved : integer = 0) : HRESULT; stdcall;
      {/ The HttpAddUrl function registers a given URL so that requests that match
         it are routed to a specified HTTP Server API request queue. An application
         can register multiple URLs to a single request queue using repeated calls to
         HttpAddUrl.
         - a typical url prefix is 'http://+:80/vroot/', 'https://+:80/vroot/' or
          'http://adatum.com:443/secure/database/' - here the '+' is called a
          Strong wildcard, i.e. will match every IP or server name }
      AddUrl : function(ReqQueueHandle : THandle; UrlPrefix : PWideChar;
            Reserved : integer = 0) : HRESULT; stdcall;
      {/ Unregisters a specified URL, so that requests for it are no longer
         routed to a specified queue. }
      RemoveUrl : function(ReqQueueHandle : THandle; UrlPrefix : PWideChar) : HRESULT; stdcall;
      {/ retrieves the next available HTTP request from the specified request queue }
      ReceiveHttpRequest : function(ReqQueueHandle : THandle; RequestId : HTTP_REQUEST_ID;
            Flags : cardinal; var pRequestBuffer : HTTP_REQUEST_V2; RequestBufferLength : ULONG;
            var pBytesReceived : ULONG; pOverlapped : pointer = nil) : HRESULT; stdcall;
      {/ sent the response to a specified HTTP request }
      SendHttpResponse : function(ReqQueueHandle : THandle; RequestId : HTTP_REQUEST_ID;
            Flags : integer; var pHttpResponse : HTTP_RESPONSE_V2; pReserved1 : pointer;
            var pBytesSent : cardinal; pReserved2 : pointer = nil; Reserved3 : ULONG = 0;
            pOverlapped : pointer = nil; pLogData : PHTTP_LOG_DATA = nil) : HRESULT; stdcall;
      {/ receives additional entity body data for a specified HTTP request }
      ReceiveRequestEntityBody : function(ReqQueueHandle : THandle; RequestId : HTTP_REQUEST_ID;
            Flags : ULONG; pBuffer : pointer; BufferLength : cardinal; var pBytesReceived : cardinal;
            pOverlapped : pointer = nil) : HRESULT; stdcall;
      {/ set specified data, such as IP addresses or SSL Certificates, from the
         HTTP Server API configuration store}
      SetServiceConfiguration : function(ServiceHandle : THandle;
            ConfigId : THttpServiceConfigID; pConfigInformation : pointer;
            ConfigInformationLength : ULONG; pOverlapped : pointer = nil) : HRESULT; stdcall;
      {/ deletes specified data, such as IP addresses or SSL Certificates, from the
         HTTP Server API configuration store}
      DeleteServiceConfiguration : function(ServiceHandle : THandle;
            ConfigId : THttpServiceConfigID; pConfigInformation : pointer;
            ConfigInformationLength : ULONG; pOverlapped : pointer = nil) : HRESULT; stdcall;

      CancelHttpRequest : function(ReqQueueHandle : THandle; RequestId : HTTP_REQUEST_ID;
            pOverlapped : pointer = nil) : HRESULT; stdcall;

      CreateServerSession : function(Version : HTTPAPI_VERSION;
            var ServerSessionId : HTTP_SERVER_SESSION_ID; Reserved : ULONG = 0) : HRESULT; stdcall;
      CloseServerSession : function(ServerSessionId : HTTP_SERVER_SESSION_ID) : HRESULT; stdcall;

      CreateRequestQueue : function(Version : HTTPAPI_VERSION;
            pName : PWideChar; pSecurityAttributes : Pointer;
            Flags : ULONG; var ReqQueueHandle : THandle) : HRESULT; stdcall;

      SetServerSessionProperty : function(ServerSessionId : HTTP_SERVER_SESSION_ID;
            aProperty : HTTP_SERVER_PROPERTY; pPropertyInformation : Pointer;
            PropertyInformationLength : ULONG) : HRESULT; stdcall;
      QueryServerSessionProperty : function(ServerSessionId : HTTP_SERVER_SESSION_ID;
            aProperty : HTTP_SERVER_PROPERTY; pPropertyInformation : Pointer;
            PropertyInformationLength : ULONG; pReturnLength : PULONG = nil) : HRESULT; stdcall;

      CreateUrlGroup : function(ServerSessionId : HTTP_SERVER_SESSION_ID;
            var UrlGroupId : HTTP_URL_GROUP_ID; Reserved : ULONG = 0) : HRESULT; stdcall;
      CloseUrlGroup : function(UrlGroupId : HTTP_URL_GROUP_ID) : HRESULT; stdcall;

      AddUrlToUrlGroup : function(UrlGroupId : HTTP_URL_GROUP_ID;
            pFullyQualifiedUrl : PWideChar; UrlContext : HTTP_URL_CONTEXT = 0;
            Reserved : ULONG = 0) : HRESULT; stdcall;
      RemoveUrlFromUrlGroup : function(UrlGroupId : HTTP_URL_GROUP_ID;
            pFullyQualifiedUrl : PWideChar; Flags : ULONG = HTTP_URL_FLAG_REMOVE_ALL) : HRESULT; stdcall;

      SetUrlGroupProperty : function(UrlGroupId : HTTP_URL_GROUP_ID;
            aProperty : HTTP_SERVER_PROPERTY; pPropertyInformation : Pointer;
            PropertyInformationLength : ULONG) : HRESULT; stdcall;
      QueryUrlGroupProperty : function(UrlGroupId : HTTP_URL_GROUP_ID;
            aProperty : HTTP_SERVER_PROPERTY; pPropertyInformation : Pointer;
            PropertyInformationLength : ULONG; pReturnLength : PULONG = nil) : HRESULT; stdcall;

      class procedure InitializeAPI; static;

      class procedure Check(error : HRESULT; api : THttpAPIs); static; inline;
   end;

   EHttpApiServer = class (Exception)
   public
      constructor Create(api : THttpAPIs; Error : integer);
   end;

var
   HttpAPI : THttpAPI;

/// retrieve the HTTP reason text from a code
// - e.g. StatusCodeToReason(200)='OK'
function StatusCodeToReason(Code : integer) : RawByteString;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

class procedure THttpAPI.InitializeAPI;
var
   api : THttpAPIs;
   P : PPointer;
begin
   if HttpAPI.Module<>0 then
      exit; // already loaded
   try
      if HttpAPI.Module = 0 then begin
         HttpAPI.Module := LoadLibrary('httpapi.dll');
         if HttpAPI.Module<=255 then
            raise Exception.Create('Unable to find httpapi.dll');
      {$ifdef FPC}
         P := @Http.Initialize;
      {$else}
         P := @@HttpAPI.Initialize;
      {$endif}
         for api := low(api) to high(api) do begin
            P^ := GetProcAddress(HttpAPI.Module, HttpNames[api]);
            if P^ = nil then
               raise Exception.CreateFmt('Unable to find %s in httpapi.dll', [HttpNames[api]]);
            inc(P);
         end;
      end;
   except
      on E : Exception do begin
         if HttpAPI.Module>255 then begin
            FreeLibrary(HttpAPI.Module);
            HttpAPI.Module := 0;
         end;
         raise E;
      end;
   end;
end;

class procedure THttpAPI.Check(error : HRESULT; api : THttpAPIs);
begin
   if error<>NO_ERROR then
      raise EHttpApiServer.Create(api, error);
end;

function StatusCodeToReason(Code : integer) : RawByteString;
begin
   case Code of
      100 :
         result := 'Continue';
      200 :
         result := 'OK';
      201 :
         result := 'Created';
      202 :
         result := 'Accepted';
      203 :
         result := 'Non-Authoritative Information';
      204 :
         result := 'No Content';
      300 :
         result := 'Multiple Choices';
      301 :
         result := 'Moved Permanently';
      302 :
         result := 'Found';
      303 :
         result := 'See Other';
      304 :
         result := 'Not Modified';
      307 :
         result := 'Temporary Redirect';
      400 :
         result := 'Bad Request';
      401 :
         result := 'Unauthorized';
      403 :
         result := 'Forbidden';
      404 :
         result := 'Not Found';
      405 :
         result := 'Method Not Allowed';
      406 :
         result := 'Not Acceptable';
      500 :
         result := 'Internal Server Error';
      503 :
         result := 'Service Unavailable';
   else
      str(Code, result);
   end;
end;

function IdemPChar(p, up : pAnsiChar) : boolean;
   // if the beginning of p^ is same as up^ (ignore case - up^ must be already Upper)
var
   c : AnsiChar;
begin
   result := false;
   if (p = nil) or (up = nil) then
      exit;
   while up^<>#0 do begin
      c := p^;
      if up^<>c then
         if c in ['a'..'z'] then begin
            dec(c, 32);
            if up^<>c then
               exit;
         end else
            exit;
      inc(up);
      inc(p);
   end;
   result := true;
end;

constructor EHttpApiServer.Create(api : THttpAPIs; Error : integer);
begin
   inherited CreateFmt('%s failed: %s (%d)',
      [HttpNames[api], SysErrorMessage(Error), Error]);
end;

{ HTTP_RESPONSE_V2 }

procedure HTTP_RESPONSE_V2.SetContent(var DataChunk : HTTP_DATA_CHUNK_INMEMORY;
   const Content, ContentType : RawByteString);
begin
   fillchar(DataChunk, sizeof(DataChunk), 0);
   if Content = '' then
      exit;
   DataChunk.DataChunkType := hctFromMemory;
   DataChunk.pBuffer := pointer(Content);
   DataChunk.BufferLength := length(Content);
   EntityChunkCount := 1;
   pEntityChunks := @DataChunk;
   Headers.KnownHeaders[reqContentType].RawValueLength := length(ContentType);
   Headers.KnownHeaders[reqContentType].pRawValue := pointer(ContentType);
end;

procedure HTTP_RESPONSE_V2.SetHeaders(P : PAnsiChar;
   UnknownHeaders : PHTTP_UNKNOWN_HEADER; MaxUnknownHeader : integer);
var
   Known : THttpHeader;
begin
   Headers.pUnknownHeaders := UnknownHeaders;
   Headers.UnknownHeaderCount := 0;
   inc(UnknownHeaders);
   if P<>nil then
      repeat
         while P^ in [#13, #10] do
            inc(P);
         if P^ = #0 then
            break;
         if IdemPChar(P, 'CONTENT-TYPE:') then
            Known := reqContentType
         else if IdemPChar(P, 'CONTENT-ENCODING:') then
            Known := reqContentEncoding
         else if IdemPChar(P, 'LOCATION:') then
            Known := respLocation
         else
            Known := reqCacheControl; // mark not found
         if Known<>reqCacheControl then
            with Headers.KnownHeaders[Known] do begin
               while P^<>':' do
                  inc(P);
               inc(P); // jump ':'
               while P^ = ' ' do
                  inc(P);
               pRawValue := P;
               while P^>=' ' do
                  inc(P);
               RawValueLength := P-pRawValue;
            end else begin
            UnknownHeaders^.pName := P;
            while (P^>=' ') and (P^<>':') do
               inc(P);
            if P^ = ':' then begin
               with UnknownHeaders^ do begin
                  NameLength := P-pName;
                  repeat
                     inc(P)
                  until P^<>' ';
                  pRawValue := P;
                  repeat
                     inc(P)
                  until P^<' ';
                  RawValueLength := P-pRawValue;
                  if Headers.UnknownHeaderCount<MaxUnknownHeader then begin
                     inc(UnknownHeaders);
                     inc(Headers.UnknownHeaderCount);
                  end;
               end;
            end else
               while P^>=' ' do
                  inc(P);
         end;
      until false;
end;

procedure HTTP_RESPONSE_V2.SetStatus(code : integer; var OutStatus : RawByteString;
   DataChunkForErrorContent : PHTTP_DATA_CHUNK_INMEMORY; const ErrorMsg : RawByteString);
begin
   StatusCode := code;
   OutStatus := StatusCodeToReason(code);
   ReasonLength := length(OutStatus);
   pReason := pointer(OutStatus);
   if DataChunkForErrorContent<>nil then
      SetContent(DataChunkForErrorContent^, '<h1>'+OutStatus+'</h1>'+ErrorMsg);
end;

end.
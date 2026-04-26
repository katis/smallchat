Class {
	#name : 'SmallChatLSPClient',
	#superclass : 'Object',
	#instVars : [
		'transport',
		'nextId',
		'pending',
		'notificationHandlers',
		'documentCache',
		'initialized',
		'serverCapabilities',
		'running',
		'readerProcess'
	],
	#classVars : [
		'ActiveClients'
	],
	#category : 'SmallChat-LSP',
	#package : 'SmallChat-LSP'
}

{ #category : 'lifecycle' }
SmallChatLSPClient class >> activeClients [
	"IdentitySet of clients that have marked themselves active. Lazily created."
	^ ActiveClients ifNil: [ ActiveClients := IdentitySet new ]
]

{ #category : 'lifecycle' }
SmallChatLSPClient class >> initializeParamsForRoot: aWorkspaceRoot [
	"Build the initialize params dict for a workspace rooted at aWorkspaceRoot.
	 Sets rootUri, leaves processId nil (Pharo has no useful pid to report), and
	 declares hierarchical DocumentSymbol support so servers (notably tsgo) emit
	 the nested DocumentSymbol shape the Famix importer parses, instead of the
	 deprecated flat SymbolInformation shape."
	^ Dictionary new
		at: 'processId' put: nil;
		at: 'rootUri' put: 'file://' , aWorkspaceRoot asFileReference pathString;
		at: 'capabilities' put: (Dictionary new
			at: 'textDocument' put: (Dictionary new
				at: 'documentSymbol' put: (Dictionary new
					at: 'hierarchicalDocumentSymbolSupport' put: true;
					yourself);
				yourself);
			yourself);
		yourself
]

{ #category : 'lifecycle' }
SmallChatLSPClient class >> launchTsgoForWorkspace: aWorkspaceRoot [
	"Spawn tsgo against aWorkspaceRoot per the workspace-local resolution rule
	 (SmallChatLSPStdioTransport class>>resolveTsgoCommandIn:), wire stdio,
	 fork the message reader, register the client as active so SessionManager
	 tears it down on image quit/save, and run the LSP initialize handshake.
	 Blocks up to 10s on the initialize response. Returns the live, initialized
	 client. On any failure, tears down the transport + reader before re-raising
	 so a half-initialised tsgo never leaks across the launcher boundary."
	| transport client |
	transport := SmallChatLSPStdioTransport new.
	transport launchTsgoAt: aWorkspaceRoot.
	client := self new transport: transport.
	[
		client startReader.
		client markActive.
		(client initializeAsync: (self initializeParamsForRoot: aWorkspaceRoot)) resultTimeout: 10000
	] on: Error do: [ :e |
		[ client shutdown ] on: Error do: [ :_ | nil ].
		[ transport shutdown ] on: Error do: [ :_ | nil ].
		e signal ].
	^ client
]

{ #category : 'lifecycle' }
SmallChatLSPClient class >> registerActive: aClient [
	self activeClients add: aClient
]

{ #category : 'system startup' }
SmallChatLSPClient class >> shutDown: isImageQuitting [
	"SessionManager hook. Terminate every active client so their child
	 processes do not leak across image quit/save."
	ActiveClients ifNil: [ ^ self ].
	ActiveClients copy do: [ :c |
		[ c shutdown ] on: Error do: [ :_ | nil ] ]
]

{ #category : 'lifecycle' }
SmallChatLSPClient class >> unregisterActive: aClient [
	ActiveClients ifNotNil: [ ActiveClients remove: aClient ifAbsent: [ nil ] ]
]

{ #category : 'safety' }
SmallChatLSPClient >> assertNotOnUIProcess [
	"Blocking LSP calls must never sit on the UI process -- tsgo references
	 over a big project can take seconds, which would freeze Morphic. Async
	 callers use #requestAsync: instead. This is a programming error, not a
	 runtime condition."
	Processor activeProcess == self uiProcess ifTrue: [
		SmallChatLSPUIProcessBlocked signal:
			'Blocking LSP request on the UI process -- use requestAsync: from UI code' ]
]

{ #category : 'requests' }
SmallChatLSPClient >> cancelPending: aPending [
	"Emit $/cancelRequest for aPending's id and resolve the pending with a
	 SmallChatLSPCancelledError. No-op if the pending has already resolved."
	| id |
	aPending isResolved ifTrue: [ ^ self ].
	id := aPending id.
	pending removeKey: id ifAbsent: [ nil ].
	transport writeMessage: (Dictionary new
		at: 'jsonrpc' put: '2.0';
		at: 'method' put: '$/cancelRequest';
		at: 'params' put: (Dictionary new at: 'id' put: id; yourself);
		yourself).
	aPending resolveWithError: (SmallChatLSPCancelledError new messageText: 'LSP request cancelled')
]

{ #category : 'document sync' }
SmallChatLSPClient >> changeDocumentUri: aUri text: aString [
	"Bump the cache's version and send textDocument/didChange with
	 whole-document contentChanges."
	| version |
	documentCache changeUri: aUri text: aString.
	version := documentCache versionOf: aUri.
	self sendNotification: 'textDocument/didChange' params: (Dictionary new
		at: 'textDocument' put: (Dictionary new
			at: 'uri' put: aUri;
			at: 'version' put: version;
			yourself);
		at: 'contentChanges' put: (Array with: (Dictionary new
			at: 'text' put: aString;
			yourself));
		yourself).
	^ self
]

{ #category : 'dispatch' }
SmallChatLSPClient >> dispatchMessage: msg [
	"Route a parsed message to the appropriate handler. Called from the
	 reader path as well as synchronous pumpOneMessage."
	| id method p err e handler |
	id := msg at: 'id' ifAbsent: [ nil ].
	method := msg at: 'method' ifAbsent: [ nil ].
	(id notNil and: [ method isNil ]) ifTrue: [
		p := pending removeKey: id ifAbsent: [ nil ].
		p ifNotNil: [
			(msg includesKey: 'result')
				ifTrue: [ p resolveWith: (msg at: 'result') ]
				ifFalse: [
					err := msg at: 'error' ifAbsent: [ nil ].
					err ifNotNil: [
						e := SmallChatLSPServerError new
							messageText: (err at: 'message' ifAbsent: [ '' ]);
							code: (err at: 'code' ifAbsent: [ 0 ]);
							yourself.
						p resolveWithError: e ] ] ].
		^ self ].
	(id isNil and: [ method notNil ]) ifTrue: [
		handler := notificationHandlers at: method ifAbsent: [ nil ].
		handler ifNotNil: [ handler value: (msg at: 'params' ifAbsent: [ nil ]) ].
		^ self ].
	(id notNil and: [ method notNil ]) ifTrue: [
		transport writeMessage: (Dictionary new
			at: 'jsonrpc' put: '2.0';
			at: 'id' put: id;
			at: 'result' put: Dictionary new;
			yourself).
		^ self ]
]

{ #category : 'accessing' }
SmallChatLSPClient >> documentCache [
	^ documentCache
]

{ #category : 'initialization' }
SmallChatLSPClient >> initialize [
	super initialize.
	nextId := 0.
	pending := Dictionary new.
	notificationHandlers := Dictionary new.
	documentCache := SmallChatLSPDocumentCache new.
	initialized := false
]

{ #category : 'initialize' }
SmallChatLSPClient >> initializeAsync: aParamsDictionary [
	"Send an LSP initialize request. Returns the pending; the caller pumps
	 until it resolves. On success, the client stores parsed capabilities and
	 flips #initialized. The LSP-spec `initialized` notification is then sent."
	| p |
	p := self requestAsync: (Dictionary new
		at: 'method' put: 'initialize';
		at: 'params' put: aParamsDictionary;
		yourself).
	p onResolve: [ :result |
		serverCapabilities := SmallChatLSPServerCapabilities fromInitializeResult: result.
		initialized := true.
		self sendNotification: 'initialized' params: Dictionary new ].
	^ p
]

{ #category : 'accessing' }
SmallChatLSPClient >> initialized [
	^ initialized == true
]

{ #category : 'lifecycle' }
SmallChatLSPClient >> markActive [
	"Register self so SessionManager>>shutDown: can tear us down on image exit."
	self class registerActive: self.
	^ self
]

{ #category : 'lifecycle' }
SmallChatLSPClient >> markInactive [
	self class unregisterActive: self.
	^ self
]

{ #category : 'dispatch' }
SmallChatLSPClient >> onNotification: aMethodName do: aBlock [
	"Register a handler for inbound notifications with the given method. The
	 handler receives the notification's params dict (or nil if absent)."
	notificationHandlers at: aMethodName put: aBlock.
	^ self
]

{ #category : 'document sync' }
SmallChatLSPClient >> openDocumentUri: aUri languageId: aLanguageId text: aString [
	"Cache the document at version 1 and send textDocument/didOpen to the server."
	documentCache openUri: aUri languageId: aLanguageId text: aString.
	self sendNotification: 'textDocument/didOpen' params: (Dictionary new
		at: 'textDocument' put: (Dictionary new
			at: 'uri' put: aUri;
			at: 'languageId' put: aLanguageId;
			at: 'version' put: 1;
			at: 'text' put: aString;
			yourself);
		yourself).
	^ self
]

{ #category : 'dispatch' }
SmallChatLSPClient >> pumpOneMessage [
	"Read one message from the transport and dispatch it. Returns the parsed
	 message (or nil on EOF) so callers (tests, the reader fork) can detect
	 end-of-stream."
	| msg |
	msg := transport readMessage.
	msg ifNotNil: [ self dispatchMessage: msg ].
	^ msg
]

{ #category : 'requests' }
SmallChatLSPClient >> request: aRequestDictionary [
	"Blocking sugar: requestAsync + result. Refuses to run on the UI process."
	self assertNotOnUIProcess.
	^ (self requestAsync: aRequestDictionary) result
]

{ #category : 'requests' }
SmallChatLSPClient >> request: aRequestDictionary onDocumentUri: aUri [
	"Blocking request with a pre-flight that refuses unknown URIs so
	 textDocument/* methods can't race ahead of the didOpen handshake."
	documentCache mustBeOpen: aUri.
	^ self request: aRequestDictionary
]

{ #category : 'requests' }
SmallChatLSPClient >> requestAsync: aRequestDictionary [
	"Assign a monotonic id, build a JSON-RPC 2.0 envelope, register the pending
	 keyed by id, write the envelope, and return the pending."
	| id envelope p |
	id := nextId := nextId + 1.
	envelope := Dictionary new
		at: 'jsonrpc' put: '2.0';
		at: 'id' put: id;
		yourself.
	aRequestDictionary keysAndValuesDo: [ :k :v | envelope at: k put: v ].
	p := SmallChatLSPPendingRequest new id: id; client: self; yourself.
	pending at: id put: p.
	transport writeMessage: envelope.
	^ p
]

{ #category : 'notifications' }
SmallChatLSPClient >> sendNotification: aMethodName params: aParamsDictionary [
	"Write a JSON-RPC notification (no id) to the transport."
	transport writeMessage: (Dictionary new
		at: 'jsonrpc' put: '2.0';
		at: 'method' put: aMethodName;
		at: 'params' put: aParamsDictionary;
		yourself).
	^ self
]

{ #category : 'accessing' }
SmallChatLSPClient >> serverCapabilities [
	^ serverCapabilities
]

{ #category : 'lifecycle' }
SmallChatLSPClient >> shutdown [
	"Stop the reader, shut down the transport (if it supports it), and drop
	 out of the active-clients set. Safe to call multiple times."
	[ self stopReader ] on: Error do: [ :_ | nil ].
	transport ifNotNil: [
		(transport respondsTo: #shutdown) ifTrue: [
			[ transport shutdown ] on: Error do: [ :_ | nil ] ] ].
	self markInactive.
	^ self
]

{ #category : 'lifecycle' }
SmallChatLSPClient >> startReader [
	"Fork a reader process at lowIOPriority that pumps messages until the
	 transport EOFs or #stopReader runs."
	running := true.
	readerProcess := [
		[ running == true ] whileTrue: [
			[ | msg |
				msg := transport readMessage.
				msg
					ifNil: [ running := false ]
					ifNotNil: [ self dispatchMessage: msg ] ]
				on: Error
				do: [ :e |
					SmallChatLSPStdioTransport logToFile:
						'reader error: ' , e class name , ' - ' , (e messageText ifNil: [ '' ]) ] ]
		] forkAt: Processor lowIOPriority
		  named: 'SmallChat LSP Reader'.
	^ self
]

{ #category : 'lifecycle' }
SmallChatLSPClient >> stopReader [
	"Signal the reader loop to exit and terminate the process if it's still parked."
	running := false.
	readerProcess ifNotNil: [ :p |
		[ p terminate ] on: Error do: [ :_ | ].
		readerProcess := nil ].
	^ self
]

{ #category : 'accessing' }
SmallChatLSPClient >> transport: aTransport [
	transport := aTransport.
	^ self
]

{ #category : 'safety' }
SmallChatLSPClient >> uiProcess [
	"Hook: which Pharo Process counts as the UI process. Tests override.
	 Production asks UIManager."
	^ UIManager default uiProcess
]

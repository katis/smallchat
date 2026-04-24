Class {
	#name : 'SmallChatLSPClient',
	#superclass : 'Object',
	#instVars : [
		'transport',
		'nextId',
		'pending',
		'notificationHandlers',
		'documentCache'
	],
	#category : 'SmallChat-LSP',
	#package : 'SmallChat-LSP'
}

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
	documentCache := SmallChatLSPDocumentCache new
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
	"Read one message from the transport and dispatch it.
	   - Response (id + result/error, no method): resolve the matching pending.
	   - Notification (method, no id): invoke registered handler if any.
	   - Server-to-client request (id + method): auto-reply with empty result so
	     the reader never stalls (e.g. tsgo's client/registerCapability burst)."
	| msg id method p err e handler |
	msg := transport readMessage.
	msg ifNil: [ ^ self ].
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

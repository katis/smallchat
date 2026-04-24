Class {
	#name : 'SmallChatLSPClient',
	#superclass : 'Object',
	#instVars : [
		'transport',
		'nextId',
		'pending'
	],
	#category : 'SmallChat-LSP',
	#package : 'SmallChat-LSP'
}

{ #category : 'initialization' }
SmallChatLSPClient >> initialize [
	super initialize.
	nextId := 0.
	pending := Dictionary new
]

{ #category : 'dispatch' }
SmallChatLSPClient >> pumpOneMessage [
	"Read one message from the transport and dispatch it.
	 Responses (id + result) resolve the matching pending; error responses route
	 through resolveWithError: so the caller's #result call raises."
	| msg id p err e |
	msg := transport readMessage.
	msg ifNil: [ ^ self ].
	id := msg at: 'id' ifAbsent: [ nil ].
	id ifNotNil: [
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
						p resolveWithError: e ] ] ] ]
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
	p := SmallChatLSPPendingRequest new id: id.
	pending at: id put: p.
	transport writeMessage: envelope.
	^ p
]

{ #category : 'accessing' }
SmallChatLSPClient >> transport: aTransport [
	transport := aTransport.
	^ self
]

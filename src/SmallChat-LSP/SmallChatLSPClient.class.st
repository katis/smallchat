Class {
	#name : 'SmallChatLSPClient',
	#superclass : 'Object',
	#instVars : [
		'transport',
		'nextId'
	],
	#category : 'SmallChat-LSP',
	#package : 'SmallChat-LSP'
}

{ #category : 'initialization' }
SmallChatLSPClient >> initialize [
	super initialize.
	nextId := 0
]

{ #category : 'requests' }
SmallChatLSPClient >> requestAsync: aRequestDictionary [
	"Assign a monotonic id, build a JSON-RPC 2.0 envelope around aRequestDictionary
	 (which carries method/params), write it to the transport, and return a
	 pending request the caller can block on or cancel."
	| id envelope pending |
	id := nextId := nextId + 1.
	envelope := Dictionary new
		at: 'jsonrpc' put: '2.0';
		at: 'id' put: id;
		yourself.
	aRequestDictionary keysAndValuesDo: [ :k :v | envelope at: k put: v ].
	transport writeMessage: envelope.
	pending := SmallChatLSPPendingRequest new id: id.
	^ pending
]

{ #category : 'accessing' }
SmallChatLSPClient >> transport: aTransport [
	transport := aTransport.
	^ self
]

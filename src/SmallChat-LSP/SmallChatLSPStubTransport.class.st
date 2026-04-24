Class {
	#name : 'SmallChatLSPStubTransport',
	#superclass : 'Object',
	#instVars : [
		'incoming',
		'sent'
	],
	#category : 'SmallChat-LSP',
	#package : 'SmallChat-LSP'
}

{ #category : 'test fixture' }
SmallChatLSPStubTransport >> enqueueServerMessage: aDictionary [
	"Append a raw JSON-RPC Dictionary to the queue readMessage draws from."
	incoming addLast: aDictionary.
	^ self
]

{ #category : 'initialization' }
SmallChatLSPStubTransport >> initialize [
	super initialize.
	incoming := OrderedCollection new.
	sent := OrderedCollection new
]

{ #category : 'reading' }
SmallChatLSPStubTransport >> readMessage [
	"Return the next enqueued server-to-client message, or nil when the queue
	 is empty. No framing -- stubs deal in parsed Dictionaries."
	incoming isEmpty ifTrue: [ ^ nil ].
	^ incoming removeFirst
]

{ #category : 'accessing' }
SmallChatLSPStubTransport >> sentMessages [
	"Every message writeMessage: has seen, in write order."
	^ sent
]

{ #category : 'writing' }
SmallChatLSPStubTransport >> writeMessage: aDictionary [
	sent addLast: aDictionary
]

Class {
	#name : 'SmallChatLSPStubTransportTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-LSP-Tests',
	#package : 'SmallChat-LSP-Tests'
}

{ #category : 'tests' }
SmallChatLSPStubTransportTest >> testEnqueueServerMessageAppearsOnRead [
	| stub msg |
	stub := SmallChatLSPStubTransport new.
	msg := Dictionary new at: 'method' put: 'x'; yourself.
	stub enqueueServerMessage: msg.
	self assert: stub readMessage equals: msg.
	self assert: stub readMessage isNil
]

{ #category : 'tests' }
SmallChatLSPStubTransportTest >> testWriteMessageAppendsToSentMessages [
	| stub msg |
	stub := SmallChatLSPStubTransport new.
	msg := Dictionary new at: 'id' put: 1; yourself.
	stub writeMessage: msg.
	self assert: stub sentMessages size equals: 1.
	self assert: stub sentMessages first equals: msg
]

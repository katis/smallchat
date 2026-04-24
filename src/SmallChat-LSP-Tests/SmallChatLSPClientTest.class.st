Class {
	#name : 'SmallChatLSPClientTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-LSP-Tests',
	#package : 'SmallChat-LSP-Tests'
}

{ #category : 'tests - correlation' }
SmallChatLSPClientTest >> testRequestAsyncWritesEnvelopeAndReturnsPending [
	"requestAsync: assigns a numeric id, wraps the caller payload in the JSON-RPC 2.0
	 envelope, writes it to the transport, and returns a SmallChatLSPPendingRequest
	 bound to that id."
	| stub client request pending sent |
	stub := SmallChatLSPStubTransport new.
	client := SmallChatLSPClient new transport: stub.
	request := Dictionary new
		at: 'method' put: 'initialize';
		at: 'params' put: Dictionary new;
		yourself.
	pending := client requestAsync: request.
	self assert: pending class equals: SmallChatLSPPendingRequest.
	self assert: pending id isInteger.
	sent := stub sentMessages.
	self assert: sent size equals: 1.
	self assert: (sent first at: 'jsonrpc') equals: '2.0'.
	self assert: (sent first at: 'id') equals: pending id.
	self assert: (sent first at: 'method') equals: 'initialize'.
	self assert: ((sent first at: 'params') = Dictionary new)
]

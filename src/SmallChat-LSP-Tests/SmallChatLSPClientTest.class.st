Class {
	#name : 'SmallChatLSPClientTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-LSP-Tests',
	#package : 'SmallChat-LSP-Tests'
}

{ #category : 'tests - correlation' }
SmallChatLSPClientTest >> testErrorResponseRaisesOnResult [
	"When the server responds with error instead of result, #result raises
	 SmallChatLSPServerError carrying the code and message."
	| stub client pending ex |
	stub := SmallChatLSPStubTransport new.
	client := SmallChatLSPClient new transport: stub.
	pending := client requestAsync: (Dictionary new at: 'method' put: 'x'; yourself).
	stub enqueueServerMessage: (Dictionary new
		at: 'jsonrpc' put: '2.0';
		at: 'id' put: pending id;
		at: 'error' put: (Dictionary new
			at: 'code' put: -32603;
			at: 'message' put: 'internal server error';
			yourself);
		yourself).
	client pumpOneMessage.
	ex := [ pending result. nil ]
		on: SmallChatLSPServerError
		do: [ :e | e ].
	self assert: ex notNil.
	self assert: ex code equals: -32603.
	self assert: ex messageText equals: 'internal server error'
]

{ #category : 'tests - correlation' }
SmallChatLSPClientTest >> testNotificationInvokesRegisteredHandler [
	"A server notification (method, no id) dispatches to the handler registered
	 via #onNotification:do: with the params dict. Pending requests are untouched."
	| stub client received |
	stub := SmallChatLSPStubTransport new.
	client := SmallChatLSPClient new transport: stub.
	received := nil.
	client onNotification: 'window/logMessage' do: [ :params | received := params ].
	stub enqueueServerMessage: (Dictionary new
		at: 'jsonrpc' put: '2.0';
		at: 'method' put: 'window/logMessage';
		at: 'params' put: (Dictionary new
			at: 'type' put: 3;
			at: 'message' put: 'hi';
			yourself);
		yourself).
	client pumpOneMessage.
	self assert: received notNil.
	self assert: (received at: 'message') equals: 'hi'
]

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

{ #category : 'tests - correlation' }
SmallChatLSPClientTest >> testResponseCompletesPending [
	"When pumpOneMessage reads a server response matching a pending id, that
	 pending becomes resolved and #result returns the response's result dict."
	| stub client pending expected |
	stub := SmallChatLSPStubTransport new.
	client := SmallChatLSPClient new transport: stub.
	pending := client requestAsync: (Dictionary new at: 'method' put: 'initialize'; yourself).
	expected := Dictionary new at: 'capabilities' put: Dictionary new; yourself.
	stub enqueueServerMessage: (Dictionary new
		at: 'jsonrpc' put: '2.0';
		at: 'id' put: pending id;
		at: 'result' put: expected;
		yourself).
	client pumpOneMessage.
	self assert: pending result equals: expected
]

{ #category : 'tests - correlation' }
SmallChatLSPClientTest >> testResultTimeoutRaisesTimeoutError [
	"Calling #resultTimeout: without any matching response raises a timeout.
	 50 ms is long enough to be non-flaky but short enough to keep the test fast."
	| stub client pending ex |
	stub := SmallChatLSPStubTransport new.
	client := SmallChatLSPClient new transport: stub.
	pending := client requestAsync: (Dictionary new at: 'method' put: 'x'; yourself).
	ex := [ pending resultTimeout: 50. nil ]
		on: SmallChatLSPTimeoutError
		do: [ :e | e ].
	self assert: ex notNil
]

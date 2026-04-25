Class {
	#name : 'SmallChatMCPCapabilityTransportTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatMCPCapabilityTransportTest >> testDispatchDebugSessionResultProducesDebugReply [
	"Mirrors today's SmallChatToolResult>>toMcpReplyDict for debugSession:
	 isError: true, content text is debug dict printString, debugSession key
	 carries {id, exceptionClass, messageText, topFrame, stackSummary, hint}."
	| stub err reply ds |
	err := [ Error signal: 'demo failure' ] on: Error do: [ :e | e ].
	stub := SmallChatDebugSessionStubForTests id: 'ds-stub-1' exception: err.
	SmallChatCapabilityDebugSessionForTests session: stub.
	reply := SmallChatMCPCapabilityTransport new dispatch: 'test.fake.debug-session' with: Dictionary new.
	self assert: (reply at: 'isError') equals: true.
	ds := reply at: 'debugSession'.
	self assert: (ds at: 'id') equals: 'ds-stub-1'.
	self assert: (ds at: 'exceptionClass') equals: 'Error'.
	self assert: (ds at: 'messageText') equals: 'demo failure'.
	self assert: ((ds at: 'hint') includesSubstring: 'Debugger captured').
	self assert: (ds at: 'stackSummary') equals: #()
]

{ #category : 'tests' }
SmallChatMCPCapabilityTransportTest >> testDispatchErrorResultProducesIsErrorReply [
	"Error results land under the standard MCP error envelope:
	 {content: [{type: 'text', text: msg}], isError: true}.
	 Matches SmallChatToolRegistry>>errorResult: byte-for-byte."
	| reply content |
	reply := SmallChatMCPCapabilityTransport new dispatch: 'test.fake.raising' with: Dictionary new.
	self assert: (reply at: 'isError') equals: true.
	content := reply at: 'content'.
	self assert: content size equals: 1.
	self assert: (content first at: 'type') equals: 'text'.
	self assert: ((content first at: 'text') includesSubstring: 'boom')
]

{ #category : 'tests' }
SmallChatMCPCapabilityTransportTest >> testDispatchImageResultBase64sBytes [
	"Image result becomes {content: [{type: 'image', mimeType, data: <b64>}]}.
	 Matches SmallChatToolResult>>toMcpContentDict for the image variant."
	| reply content |
	reply := SmallChatMCPCapabilityTransport new dispatch: 'test.fake.image' with: Dictionary new.
	content := reply at: 'content'.
	self assert: content size equals: 1.
	self assert: (content first at: 'type') equals: 'image'.
	self assert: (content first at: 'mimeType') equals: 'image/png'.
	self assert: (content first at: 'data') equals: 'iVBORw=='
]

{ #category : 'tests' }
SmallChatMCPCapabilityTransportTest >> testDispatchTextResultProducesContentDict [
	"A capability returning a #text result becomes the standard MCP
	 tools/call reply: {content: [{type: 'text', text: ...}]}."
	| reply content |
	reply := SmallChatMCPCapabilityTransport new dispatch: 'test.fake.status' with: Dictionary new.
	content := reply at: 'content'.
	self assert: content size equals: 1.
	self assert: (content first at: 'type') equals: 'text'.
	self assert: (content first at: 'text') equals: 'ok'.
	self deny: (reply includesKey: 'isError')
]

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
SmallChatMCPCapabilityTransportTest >> testDispatchFallsThroughToLegacyToolRegistry [
	"During migration, capability registry not finding the name must fall
	 through to the legacy SmallChatToolRegistry so unmigrated tools
	 (e.g. 'status') keep working until their capability lands."
	| reply |
	reply := SmallChatMCPCapabilityTransport new dispatch: 'status' with: Dictionary new.
	"#status currently returns its working-copy dict via SmallChatToolRegistry
	 -- assert the reply has the standard MCP content envelope."
	self assert: (reply includesKey: 'content').
	self assert: (reply at: 'content') notEmpty
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
SmallChatMCPCapabilityTransportTest >> testDispatchResolvesAliasToCapability [
	"Aliases let the transport accept a legacy bare name and route to its
	 prefixed capability successor. Each migrated tool earns one alias
	 entry; aliases live in the transport (MCP-only)."
	| transport reply |
	transport := SmallChatMCPCapabilityTransport new.
	transport aliasFor: 'legacy.fake.status' put: 'test.fake.status'.
	reply := transport dispatch: 'legacy.fake.status' with: Dictionary new.
	self assert: ((reply at: 'content') first at: 'text') equals: 'ok'
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

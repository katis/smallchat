Class {
	#name : 'SmallChatMCPCapabilityTransportTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

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

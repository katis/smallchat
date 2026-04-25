Class {
	#name : 'SmallChatMCPCapabilityTransportTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatMCPCapabilityTransportTest >> testDispatchDebugSessionResultProducesDebugReply [
	"Captured debug-session result becomes the standard MCP debug envelope:
	 isError + content text (printed dict) + debugSession key with {id,
	 exceptionClass, messageText, topFrame, stackSummary, hint}."
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
	 {content: [{type: 'text', text: msg}], isError: true}."
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
	"Image result becomes {content: [{type: 'image', mimeType, data: <b64>}]}."
	| reply content |
	reply := SmallChatMCPCapabilityTransport new dispatch: 'test.fake.image' with: Dictionary new.
	content := reply at: 'content'.
	self assert: content size equals: 1.
	self assert: (content first at: 'type') equals: 'image'.
	self assert: (content first at: 'mimeType') equals: 'image/png'.
	self assert: (content first at: 'data') equals: 'iVBORw=='
]

{ #category : 'tests' }
SmallChatMCPCapabilityTransportTest >> testDispatchOmitsStrayWarningWhenWatchReturnsEmpty [
	"Empty descriptors -> no warning prefix; the original text passes through."
	| transport reply text |
	transport := SmallChatMCPCapabilityTransport new.
	transport debuggerWatch: [ #() ].
	reply := transport dispatch: 'test.fake.status' with: Dictionary new.
	text := (reply at: 'content') first at: 'text'.
	self assert: text equals: 'ok'
]

{ #category : 'tests' }
SmallChatMCPCapabilityTransportTest >> testDispatchPrependsStrayDebuggerWarningWhenWatchReturnsDescriptors [
	"Non-empty descriptors -> single-line warning prepended to the first
	 content text item."
	| transport reply text |
	transport := SmallChatMCPCapabilityTransport new.
	transport debuggerWatch: [ { #stubA. #stubB } ].
	reply := transport dispatch: 'test.fake.status' with: Dictionary new.
	text := (reply at: 'content') first at: 'text'.
	self assert: (text beginsWith: '[smallchat: 2 stray Pharo UI debugger window(s) open').
	self assert: (text endsWith: 'ok')
]

{ #category : 'tests' }
SmallChatMCPCapabilityTransportTest >> testDispatchTextResultProducesContentDict [
	"#text result becomes the standard MCP content shape:
	 {content: [{type: 'text', text: ...}]}."
	| reply content |
	reply := SmallChatMCPCapabilityTransport new dispatch: 'test.fake.status' with: Dictionary new.
	content := reply at: 'content'.
	self assert: content size equals: 1.
	self assert: (content first at: 'type') equals: 'text'.
	self assert: (content first at: 'text') equals: 'ok'.
	self deny: (reply includesKey: 'isError')
]

{ #category : 'tests' }
SmallChatMCPCapabilityTransportTest >> testDispatchUnknownNameReturnsErrorReply [
	"After Phase 7 the legacy fall-through is gone; unknown names yield an
	 #error reply through the standard MCP envelope."
	| transport reply |
	transport := SmallChatMCPCapabilityTransport new.
	reply := transport dispatch: 'nonexistent.tool.zzz' with: Dictionary new.
	self assert: (reply at: 'isError') equals: true.
	self assert: ((reply at: 'content') first at: 'text') = 'Unknown capability: nonexistent.tool.zzz' description: 'should name the missing capability'
]

{ #category : 'tests' }
SmallChatMCPCapabilityTransportTest >> testProtocolHandleToolsCallRoutesThroughCapabilityTransport [
	"After the rewire, SmallChatMCPProtocol>>handleToolsCall: dispatches via
	 SmallChatMCPCapabilityTransport default, so a registered fake capability
	 is reachable through the JSON-RPC entry point."
	| reply |
	reply := SmallChatMCPProtocol new handleToolsCall: (Dictionary new
		at: 'name' put: 'test.fake.status';
		at: 'arguments' put: Dictionary new;
		yourself).
	self assert: ((reply at: 'content') first at: 'text') equals: 'ok'
]

{ #category : 'tests' }
SmallChatMCPCapabilityTransportTest >> testToolSpecsExcludesTestFixtures [
	"Test-only capability subclasses are tagged via #isTestFixture and must
	 never appear in tools/list -- they're internal scaffolding."
	| names |
	names := (SmallChatMCPCapabilityTransport new toolSpecs collect: [ :s | s at: 'name' ]) asArray.
	self assert: (names noneSatisfy: [ :n | n beginsWith: 'test.fake.' ])
]

{ #category : 'tests' }
SmallChatMCPCapabilityTransportTest >> testToolSpecsHasOneEntryPerProductionCapabilityNoAliases [
	"Each production capability emits exactly one tools/list entry. No
	 #mcpAliases bare-name mirrors, no `(alias for X)` description suffix."
	| specs prodCount |
	specs := SmallChatMCPCapabilityTransport new toolSpecs.
	prodCount := (SmallChatCapabilityRegistry default allCapabilities
		reject: [ :cap | cap isTestFixture ]) size.
	self assert: specs size equals: prodCount.
	self assert: (specs noneSatisfy: [ :s | (s at: 'description') includesSubstring: 'alias for' ])
]

{ #category : 'tests' }
SmallChatMCPCapabilityTransportTest >> testToolSpecsIncludesProductionCapabilities [
	"toolSpecs must surface every registered production capability so
	 tools/list advertises them to the MCP client."
	| names |
	names := (SmallChatMCPCapabilityTransport new toolSpecs collect: [ :s | s at: 'name' ]) asArray.
	self assert: (names includes: 'vcs.status').
	self assert: (names includes: 'eval.smalltalk')
]

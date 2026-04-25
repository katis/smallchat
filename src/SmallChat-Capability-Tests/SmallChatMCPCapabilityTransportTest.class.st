Class {
	#name : 'SmallChatMCPCapabilityTransportTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatMCPCapabilityTransportTest >> testCapabilityMcpAliasesAreResolvedByTransport [
	"Capability declares aliases via class-side #mcpAliases; transport
	 resolves them through the capability registry."
	| transport reply |
	transport := SmallChatMCPCapabilityTransport new.
	reply := transport dispatch: 'legacy.fake.alias.target' with: Dictionary new.
	self assert: ((reply at: 'content') first at: 'text') equals: 'ok'
]

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
	"When debuggerWatch returns non-empty descriptors, the transport prepends
	 a single-line warning to the first content text item -- byte-identical
	 to today's SmallChatToolRegistry>>decorateReply:withStray:."
	| transport reply text |
	transport := SmallChatMCPCapabilityTransport new.
	transport debuggerWatch: [ { #stubA. #stubB } ].
	reply := transport dispatch: 'test.fake.status' with: Dictionary new.
	text := (reply at: 'content') first at: 'text'.
	self assert: (text beginsWith: '[smallchat: 2 stray Pharo UI debugger window(s) open').
	self assert: (text endsWith: 'ok')
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
SmallChatMCPCapabilityTransportTest >> testToolSpecsEmitsAliasEntryAlongsidePrefixedName [
	"During the deprecation window, every capability alias produces its
	 own tools/list entry (same schema, name = bare alias) so existing
	 Claude Code prompts keep finding it. Description carries an
	 ' (alias for X)' suffix to nudge new agents toward the prefixed name."
	| specs vcs alias |
	specs := SmallChatMCPCapabilityTransport new toolSpecs.
	vcs := specs detect: [ :s | (s at: 'name') = 'vcs.status' ] ifNone: [ nil ].
	alias := specs detect: [ :s | (s at: 'name') = 'status' ] ifNone: [ nil ].
	self assert: vcs notNil description: 'vcs.status spec must be present'.
	self assert: alias notNil description: 'status alias spec must be present'.
	self assert: (alias at: 'inputSchema') equals: (vcs at: 'inputSchema').
	self assert: ((alias at: 'description') includesSubstring: 'alias for vcs.status')
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
SmallChatMCPCapabilityTransportTest >> testToolSpecsIncludesLegacyTools [
	"During migration, toolSpecs must include the not-yet-migrated legacy
	 SmallChatTool subclasses so tools/list still advertises them to MCP."
	| names |
	names := (SmallChatMCPCapabilityTransport new toolSpecs collect: [ :s | s at: 'name' ]) asArray.
	self assert: (names includes: 'status').
	self assert: (names includes: 'evaluate')
]

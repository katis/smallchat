Class {
	#name : 'SmallChatCapabilityRegistryTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatCapabilityRegistryTest >> testAllCapabilitiesExcludesAbstractBase [
	"Reflective discovery filters the abstract SmallChatCapability."
	self deny: (SmallChatCapabilityRegistry default allCapabilities includes: SmallChatCapability)
]

{ #category : 'tests' }
SmallChatCapabilityRegistryTest >> testAllCapabilitiesIncludesConcreteSubclass [
	"Concrete subclasses appear automatically."
	self assert: (SmallChatCapabilityRegistry default allCapabilities
		includes: SmallChatCapabilityFakeStatusForTests)
]

{ #category : 'tests' }
SmallChatCapabilityRegistryTest >> testCapabilityNamedReturnsMatching [
	"Lookup by capabilityName -- the agent-facing identifier."
	self assert: (SmallChatCapabilityRegistry default capabilityNamed: 'test.fake.status')
		== SmallChatCapabilityFakeStatusForTests
]

{ #category : 'tests' }
SmallChatCapabilityRegistryTest >> testCapabilityNamedReturnsNilForUnknown [
	self assert: (SmallChatCapabilityRegistry default capabilityNamed: 'nope.does-not-exist') isNil
]

{ #category : 'tests' }
SmallChatCapabilityRegistryTest >> testCurrentWorkspaceDefaultsToPharo [
	SmallChatCapabilityRegistry reset.
	self assert: SmallChatCapabilityRegistry default currentWorkspace == SmallChatPharoWorkspace default
]

{ #category : 'tests' }
SmallChatCapabilityRegistryTest >> testMountedWorkspacesContainsPharoByDefault [
	SmallChatCapabilityRegistry reset.
	self assert: SmallChatCapabilityRegistry default mountedWorkspaces size equals: 1.
	self assert: SmallChatCapabilityRegistry default mountedWorkspaces first == SmallChatPharoWorkspace default
]

{ #category : 'tests-wrap' }
SmallChatCapabilityRegistryTest >> testRunCapturesExceptionAsErrorResult [
	"Universal wrap: any uncaught exception becomes a #error result."
	| call result |
	call := SmallChatCapabilityCall name: 'test.fake.raising' argumentsJson: ''.
	result := SmallChatCapabilityRegistry default run: 'test.fake.raising' with: call.
	self assert: result kind equals: #error.
	self assert: (result text includesSubstring: 'boom')
]

{ #category : 'tests' }
SmallChatCapabilityRegistryTest >> testRunDispatchesToCapability [
	"#run:with: looks up the capability by name and forwards aCall to its
	 class-side #run:."
	| call result |
	call := SmallChatCapabilityCall name: 'test.fake.status' argumentsJson: ''.
	result := SmallChatCapabilityRegistry default run: 'test.fake.status' with: call.
	self assert: result kind equals: #text.
	self assert: result text equals: 'ok'
]

{ #category : 'tests-wrap' }
SmallChatCapabilityRegistryTest >> testRunRaisesWhenOnUiProcess [
	"Hard rule: capability dispatch must never run on Morphic. The wrap
	 asserts and fails loudly so accidental wiring is caught immediately
	 (the LM-side chat window relies on this -- a UI-process deadlock would
	 freeze MCP and the chat transcript at once)."
	| registry call |
	registry := SmallChatCapabilityRegistry new.
	registry uiProcessProvider: [ Processor activeProcess ].
	call := SmallChatCapabilityCall name: 'test.fake.status' argumentsJson: ''.
	self
		should: [ registry run: 'test.fake.status' with: call ]
		raise: Error
		description: 'wrap should refuse to dispatch from the UI process'
]

{ #category : 'tests-wrap' }
SmallChatCapabilityRegistryTest >> testRunResumesNotificationsBeforeOuterHandlerSees [
	"Wrap must intercept Notifications inside #run:with: so the default handler
	 (writes to Transcript / stdout) never runs and outer code never sees them."
	| reachedOuter call result |
	reachedOuter := false.
	call := SmallChatCapabilityCall name: 'test.fake.signalling' argumentsJson: ''.
	[ result := SmallChatCapabilityRegistry default run: 'test.fake.signalling' with: call ]
		on: Notification
		do: [ :n | reachedOuter := true. n resume ].
	self deny: reachedOuter description: 'wrap must resume Notifications before any outer handler'.
	self assert: result text equals: 'ok-after-notification'
]

{ #category : 'tests' }
SmallChatCapabilityRegistryTest >> testRunReturnsApplicabilityErrorWhenWorkspaceKindMismatches [
	"Dispatch a TS-only capability under the default Pharo current workspace.
	 The registry must short-circuit with a structured error -- not invoke the
	 capability."
	| call result text |
	SmallChatCapabilityRegistry reset.
	call := SmallChatCapabilityCall name: 'test.ts.only' argumentsJson: '{}'.
	result := SmallChatCapabilityRegistry default run: 'test.ts.only' with: call.
	self assert: result kind equals: #error.
	text := result text.
	self assert: (text includesSubstring: 'not applicable').
	self assert: (text includesSubstring: 'pharo').
	self assert: (text includesSubstring: 'ts').
	self assert: (text includesSubstring: 'workspace.attach-ts')
]

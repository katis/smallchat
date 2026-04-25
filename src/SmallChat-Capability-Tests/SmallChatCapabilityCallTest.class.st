Class {
	#name : 'SmallChatCapabilityCallTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatCapabilityCallTest >> testArgumentsHandlesEmptyJsonString [
	"Capabilities that take no args may be invoked with an empty string."
	| c |
	c := SmallChatCapabilityCall name: 'vcs.status' argumentsJson: ''.
	self assert: c arguments isEmpty
]

{ #category : 'tests' }
SmallChatCapabilityCallTest >> testArgumentsHandlesNilJson [
	| c |
	c := SmallChatCapabilityCall name: 'vcs.status' argumentsJson: nil.
	self assert: c arguments isEmpty
]

{ #category : 'tests' }
SmallChatCapabilityCallTest >> testArgumentsLazyParsesJson [
	| c args |
	c := SmallChatCapabilityCall name: 'eval.lint' argumentsJson: '{"packagePattern":"SmallChat.*"}'.
	args := c arguments.
	self assert: (args at: 'packagePattern') equals: 'SmallChat.*'
]

{ #category : 'tests' }
SmallChatCapabilityCallTest >> testNameAndArgumentsJsonRoundTrip [
	| c |
	c := SmallChatCapabilityCall name: 'vcs.status' argumentsJson: '{"x":1}'.
	self assert: c capabilityName equals: 'vcs.status'.
	self assert: c argumentsJson equals: '{"x":1}'
]

{ #category : 'tests' }
SmallChatCapabilityCallTest >> testSessionDefaultsToNilAndCanBeSet [
	"MCP calls have no session; LM calls carry the SmallChatLMSession so
	 capabilities that need conversation context can reach it."
	| c stub |
	c := SmallChatCapabilityCall name: 'vcs.status' argumentsJson: ''.
	self assert: c session isNil.
	stub := Object new.
	c session: stub.
	self assert: c session == stub
]

{ #category : 'tests' }
SmallChatCapabilityCallTest >> testWorkspaceIsNilByDefault [
	| call |
	call := SmallChatCapabilityCall name: 'dummy' argumentsJson: '{}'.
	self assert: call workspace isNil.
	call workspace: SmallChatPharoWorkspace default.
	self assert: call workspace == SmallChatPharoWorkspace default
]

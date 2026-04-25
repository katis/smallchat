Class {
	#name : 'SmallChatDebugSessionsCapabilityTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatDebugSessionsCapabilityTest >> testDebugSessionsAlias [
	| transport |
	transport := SmallChatMCPCapabilityTransport new.
	self assert: (transport resolveAlias: 'debug_sessions') equals: 'debug.sessions'
]

{ #category : 'tests' }
SmallChatDebugSessionsCapabilityTest >> testRunReturnsSessionsArray [
	| call result parsed |
	call := SmallChatCapabilityCall name: 'debug.sessions' argumentsJson: ''.
	result := SmallChatDebugSessionsCapability run: call.
	self assert: result kind equals: #text.
	parsed := STONJSON fromString: result text.
	self assert: (parsed at: 'sessions') isArray
]

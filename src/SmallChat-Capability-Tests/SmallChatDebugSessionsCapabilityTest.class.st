Class {
	#name : 'SmallChatDebugSessionsCapabilityTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatDebugSessionsCapabilityTest >> testRunReturnsSessionsArray [
	| call result parsed |
	call := SmallChatCapabilityCall name: 'debug.sessions' argumentsJson: ''.
	result := SmallChatDebugSessionsCapability run: call.
	self assert: result kind equals: #text.
	parsed := STONJSON fromString: result text.
	self assert: (parsed at: 'sessions') isArray
]

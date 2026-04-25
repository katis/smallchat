Class {
	#name : 'SmallChatCapabilityCallTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatCapabilityCallTest >> testNameAndArgumentsJsonRoundTrip [
	| c |
	c := SmallChatCapabilityCall name: 'vcs.status' argumentsJson: '{"x":1}'.
	self assert: c capabilityName equals: 'vcs.status'.
	self assert: c argumentsJson equals: '{"x":1}'
]

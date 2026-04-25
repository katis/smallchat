Class {
	#name : 'SmallChatCapabilityTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatCapabilityTest >> testIsAbstract [
	self assert: SmallChatCapability isAbstract
]

{ #category : 'tests' }
SmallChatCapabilityTest >> testSupportedWorkspacesDefaultsToPharo [
	self assert: SmallChatCapability supportedWorkspaces equals: #(#pharo)
]

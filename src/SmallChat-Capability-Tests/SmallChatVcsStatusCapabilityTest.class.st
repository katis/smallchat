Class {
	#name : 'SmallChatVcsStatusCapabilityTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatVcsStatusCapabilityTest >> testRunReturnsLegacyEquivalentJson [
	"Migrated capability must produce content byte-identical to the legacy
	 SmallChatStatusTool>>run: result -- callers cannot tell which one ran."
	| call capResult legacyResult |
	call := SmallChatCapabilityCall name: 'vcs.status' argumentsJson: ''.
	capResult := SmallChatVcsStatusCapability run: call.
	legacyResult := SmallChatStatusTool new run: Dictionary new.
	self assert: capResult kind equals: #text.
	self assert: capResult text equals: legacyResult
]

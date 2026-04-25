Class {
	#name : 'SmallChatVcsStatusCapabilityTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatVcsStatusCapabilityTest >> testBareStatusAliasReachesCapability [
	"Phase 5 plan: legacy bare names 'status' / 'evaluate' / ... continue
	 to work via aliases declared on the migrated capability. Both paths
	 return identical content."
	| transport viaAlias viaPrefix |
	transport := SmallChatMCPCapabilityTransport new.
	viaAlias := transport dispatch: 'status' with: Dictionary new.
	viaPrefix := transport dispatch: 'vcs.status' with: Dictionary new.
	self assert: viaAlias equals: viaPrefix
]

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

{ #category : 'tests' }
SmallChatVcsStatusCapabilityTest >> testStatusBareNameResolvesToVcsStatus [
	"Migrated capability declares 'status' as its MCP alias so existing
	 mcp__smallchat__status calls continue to land on vcs.status."
	| transport |
	transport := SmallChatMCPCapabilityTransport new.
	self assert: (transport resolveAlias: 'status') equals: 'vcs.status'
]

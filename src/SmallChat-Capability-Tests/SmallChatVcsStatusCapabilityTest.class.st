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
SmallChatVcsStatusCapabilityTest >> testRunReturnsExpectedJsonShape [
	"Migrated capability returns a #text result whose body parses back to a
	 dict with the canonical status keys (name / location / branch /
	 isModified / changes)."
	| call result parsed |
	call := SmallChatCapabilityCall name: 'vcs.status' argumentsJson: ''.
	result := SmallChatVcsStatusCapability run: call.
	self assert: result kind equals: #text.
	parsed := STONJSON fromString: result text.
	#('name' 'location' 'subdirectory' 'branch' 'isModified' 'changes') do: [ :k |
		self assert: (parsed includesKey: k) description: 'missing key ' , k ].
	self assert: (parsed at: 'name') equals: 'smallchat'
]

{ #category : 'tests' }
SmallChatVcsStatusCapabilityTest >> testStatusBareNameResolvesToVcsStatus [
	"Migrated capability declares 'status' as its MCP alias so existing
	 mcp__smallchat__status calls continue to land on vcs.status."
	| transport |
	transport := SmallChatMCPCapabilityTransport new.
	self assert: (transport resolveAlias: 'status') equals: 'vcs.status'
]

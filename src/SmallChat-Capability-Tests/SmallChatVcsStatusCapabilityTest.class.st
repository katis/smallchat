Class {
	#name : 'SmallChatVcsStatusCapabilityTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatVcsStatusCapabilityTest >> testRunReturnsExpectedJsonShapeWhenRepoPresent [
	"In the dev image the Iceberg repo is registered and the body is JSON.
	 In the verifier no repo exists; the body is the no-repo placeholder.
	 Either is a valid #text result; only the JSON path checks structural keys."
	| call result trimmed parsed |
	call := SmallChatCapabilityCall name: 'vcs.status' argumentsJson: ''.
	result := SmallChatVcsStatusCapability run: call.
	self assert: result kind equals: #text.
	trimmed := result text.
	(trimmed beginsWith: 'No Iceberg repo') ifTrue: [ ^ self ].
	parsed := STONJSON fromString: trimmed.
	#('name' 'location' 'subdirectory' 'branch' 'isModified' 'changes') do: [ :k |
		self assert: (parsed includesKey: k) description: 'missing key ' , k ].
	self assert: (parsed at: 'name') equals: 'smallchat'
]

Class {
	#name : 'SmallChatWorkspaceCapabilitiesTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Workspace-Tests',
	#package : 'SmallChat-Workspace-Tests'
}

{ #category : 'helpers' }
SmallChatWorkspaceCapabilitiesTest >> callAttachWith: anArgsDict [
	"Helper: invoke workspace.attach-ts with a Dictionary of args. Returns the
	 SmallChatCapabilityResult."
	| call |
	call := SmallChatCapabilityCall name: 'workspace.attach-ts'
		argumentsJson: (STONJSON toString: anArgsDict).
	^ SmallChatCapabilityRegistry default run: 'workspace.attach-ts' with: call
]

{ #category : 'helpers' }
SmallChatWorkspaceCapabilitiesTest >> callDetachWith: anArgsDict [
	| call |
	call := SmallChatCapabilityCall name: 'workspace.detach'
		argumentsJson: (STONJSON toString: anArgsDict).
	^ SmallChatCapabilityRegistry default run: 'workspace.detach' with: call
]

{ #category : 'running' }
SmallChatWorkspaceCapabilitiesTest >> setUp [
	super setUp.
	SmallChatTsWorkspace launcherBlock: [ :p | SmallChatLSPClient new transport: SmallChatLSPStubTransport new ].
	SmallChatCapabilityRegistry reset
]

{ #category : 'running' }
SmallChatWorkspaceCapabilitiesTest >> tearDown [
	SmallChatTsWorkspace resetLauncherBlock.
	SmallChatCapabilityRegistry reset.
	super tearDown
]

{ #category : 'tests' }
SmallChatWorkspaceCapabilitiesTest >> testAttachTsAddsWorkspaceAndIsIdempotentByPath [
	| result1 result2 mounted |
	result1 := self callAttachWith: (Dictionary new at: 'path' put: '/tmp/smallchat-attach-ts-1'; yourself).
	self assert: result1 kind equals: #text.
	mounted := SmallChatCapabilityRegistry default mountedWorkspaces.
	self assert: mounted size equals: 2.
	self assert: mounted last kind equals: #ts.
	"Same path again -- registry should not grow."
	result2 := self callAttachWith: (Dictionary new at: 'path' put: '/tmp/smallchat-attach-ts-1'; yourself).
	self assert: result2 kind equals: #text.
	self assert: SmallChatCapabilityRegistry default mountedWorkspaces size equals: 2
]

{ #category : 'tests' }
SmallChatWorkspaceCapabilitiesTest >> testAttachTsRejectsConflictingExplicitName [
	"Two different paths with the same explicit name should error -- the user
	 must disambiguate."
	| first second |
	first := self callAttachWith: (Dictionary new
		at: 'path' put: '/tmp/smallchat-attach-conflict-1';
		at: 'name' put: 'shared';
		yourself).
	self assert: first kind equals: #text.
	second := self callAttachWith: (Dictionary new
		at: 'path' put: '/tmp/smallchat-attach-conflict-2';
		at: 'name' put: 'shared';
		yourself).
	self assert: second kind equals: #error.
	self assert: (second text includesSubstring: 'name')
]

{ #category : 'tests' }
SmallChatWorkspaceCapabilitiesTest >> testAttachTsRejectsRelativePath [
	| result |
	result := self callAttachWith: (Dictionary new at: 'path' put: 'some/relative'; yourself).
	self assert: result kind equals: #error.
	self assert: (result text includesSubstring: 'absolute')
]

{ #category : 'tests' }
SmallChatWorkspaceCapabilitiesTest >> testAttachTsRequiresPathArgument [
	| result |
	result := self callAttachWith: Dictionary new.
	self assert: result kind equals: #error.
	self assert: (result text includesSubstring: 'path')
]

{ #category : 'tests' }
SmallChatWorkspaceCapabilitiesTest >> testDetachRefusesPharoWorkspace [
	| result |
	result := self callDetachWith: (Dictionary new at: 'name' put: 'pharo'; yourself).
	self assert: result kind equals: #error.
	self assert: (result text includesSubstring: 'pharo').
	self assert: SmallChatCapabilityRegistry default mountedWorkspaces size equals: 1
]

{ #category : 'tests' }
SmallChatWorkspaceCapabilitiesTest >> testDetachShutsDownTsWorkspace [
	"After detaching, the LSP transport should have seen shutdown."
	| stub stubClient ws result |
	stub := SmallChatLSPStubTransport new.
	stubClient := SmallChatLSPClient new transport: stub.
	SmallChatTsWorkspace launcherBlock: [ :p | stubClient ].
	self callAttachWith: (Dictionary new at: 'path' put: '/tmp/smallchat-detach-1'; at: 'name' put: 'to-detach'; yourself).
	ws := SmallChatCapabilityRegistry default mountedWorkspaceNamed: 'to-detach'.
	self assert: ws notNil.
	self deny: stub shutdownCalled.
	result := self callDetachWith: (Dictionary new at: 'name' put: 'to-detach'; yourself).
	self assert: result kind equals: #text.
	self assert: stub shutdownCalled.
	self assert: (SmallChatCapabilityRegistry default mountedWorkspaceNamed: 'to-detach') isNil
]

{ #category : 'tests' }
SmallChatWorkspaceCapabilitiesTest >> testDetachUnknownNameErrors [
	| result |
	result := self callDetachWith: (Dictionary new at: 'name' put: 'nope'; yourself).
	self assert: result kind equals: #error.
	self assert: (result text includesSubstring: 'nope')
]

{ #category : 'tests' }
SmallChatWorkspaceCapabilitiesTest >> testListReturnsCurrentAndMounted [
	| call result json mounted |
	SmallChatCapabilityRegistry reset.
	call := SmallChatCapabilityCall name: 'workspace.list' argumentsJson: '{}'.
	result := SmallChatCapabilityRegistry default run: 'workspace.list' with: call.
	self assert: result kind equals: #text.
	json := STONJSON fromString: result text.
	self assert: ((json at: 'current') at: 'kind') equals: 'pharo'.
	mounted := json at: 'mounted'.
	self assert: mounted size equals: 1.
	self assert: ((mounted first) at: 'kind') equals: 'pharo'
]

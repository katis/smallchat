Class {
	#name : 'SmallChatWorkspaceCapabilitiesTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Workspace-Tests',
	#package : 'SmallChat-Workspace-Tests'
}

{ #category : 'tests' }
SmallChatWorkspaceCapabilitiesTest >> testCurrentReturnsPharoDescribe [
	| call result json |
	SmallChatCapabilityRegistry reset.
	call := SmallChatCapabilityCall name: 'workspace.current' argumentsJson: '{}'.
	result := SmallChatCapabilityRegistry default run: 'workspace.current' with: call.
	self assert: result kind equals: #text.
	json := STONJSON fromString: result text.
	self assert: (json at: 'kind') equals: 'pharo'.
	self assert: (json at: 'name') equals: 'pharo'
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

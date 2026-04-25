Class {
	#name : 'SmallChatPharoWorkspaceTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Workspace-Tests',
	#package : 'SmallChat-Workspace-Tests'
}

{ #category : 'tests' }
SmallChatPharoWorkspaceTest >> testDefaultIsSingleton [
	self assert: SmallChatPharoWorkspace default == SmallChatPharoWorkspace default.
	self assert: SmallChatPharoWorkspace default name equals: 'pharo'
]

{ #category : 'tests' }
SmallChatPharoWorkspaceTest >> testKindIsPharo [
	self assert: SmallChatPharoWorkspace kind equals: #pharo
]

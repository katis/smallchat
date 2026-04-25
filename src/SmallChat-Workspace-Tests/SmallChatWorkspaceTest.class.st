Class {
	#name : 'SmallChatWorkspaceTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Workspace-Tests',
	#package : 'SmallChat-Workspace-Tests'
}

{ #category : 'tests' }
SmallChatWorkspaceTest >> testAbstractClassLivesInWorkspacePackage [
	self assert: SmallChatWorkspace package name equals: 'SmallChat-Workspace'
]

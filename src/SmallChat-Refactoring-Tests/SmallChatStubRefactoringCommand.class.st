Class {
	#name : 'SmallChatStubRefactoringCommand',
	#superclass : 'SmallChatRefactoringCommand',
	#instVars : [
		'applier',
		'workspaceEdit'
	],
	#category : 'SmallChat-Refactoring-Tests',
	#package : 'SmallChat-Refactoring-Tests'
}

{ #category : 'configuring' }
SmallChatStubRefactoringCommand >> applier: anApplier [
  applier := anApplier
]

{ #category : 'execution' }
SmallChatStubRefactoringCommand >> apply [
  ^ SmallChatRefactoringOutcome fromApplyResult: (applier applyWorkspaceEdit: workspaceEdit)
]

{ #category : 'rollback' }
SmallChatStubRefactoringCommand >> rollback: aToken [
  applier rollback: aToken
]

{ #category : 'configuring' }
SmallChatStubRefactoringCommand >> workspaceEdit: aWorkspaceEdit [
  workspaceEdit := aWorkspaceEdit
]

Class {
	#name : 'SmallChatWorkspaceEditApplier',
	#superclass : 'Object',
	#category : 'SmallChat-Refactoring',
	#package : 'SmallChat-Refactoring'
}

{ #category : 'execution' }
SmallChatWorkspaceEditApplier >> applyWorkspaceEdit: aWorkspaceEdit withSources: aSources [
  "Empty-changes path. Returns a success result echoing aSources."
  ^ SmallChatApplyResult successWithSources: aSources
]

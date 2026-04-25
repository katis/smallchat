Class {
	#name : 'SmallChatWorkspaceEditApplierWriteFailureStub',
	#superclass : 'SmallChatWorkspaceEditApplier',
	#instVars : [
		'failOnUri'
	],
	#category : 'SmallChat-Refactoring-Tests',
	#package : 'SmallChat-Refactoring-Tests'
}

{ #category : 'configuring' }
SmallChatWorkspaceEditApplierWriteFailureStub >> failOnUri: aUri [
  failOnUri := aUri
]

{ #category : 'execution' }
SmallChatWorkspaceEditApplierWriteFailureStub >> writeSource: aString to: aUri [
  aUri = failOnUri ifTrue: [ self error: 'simulated write failure' ].
  ^ super writeSource: aString to: aUri
]

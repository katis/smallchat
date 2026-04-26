Class {
	#name : 'SmallChatWorkspaceWindowTreeStub',
	#superclass : 'Object',
	#instVars : [
		'refreshCount',
		'roots'
	],
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'initialization' }
SmallChatWorkspaceWindowTreeStub >> initialize [
  super initialize.
  refreshCount := 0
]

{ #category : 'tree-protocol' }
SmallChatWorkspaceWindowTreeStub >> refresh [
  refreshCount := refreshCount + 1
]

{ #category : 'accessing' }
SmallChatWorkspaceWindowTreeStub >> refreshCount [ ^ refreshCount
]

{ #category : 'accessing' }
SmallChatWorkspaceWindowTreeStub >> roots [ ^ roots ifNil: [ #() ]
]

{ #category : 'tree-protocol' }
SmallChatWorkspaceWindowTreeStub >> roots: aCollection [
  roots := aCollection asArray
]

{ #category : 'tree-protocol' }
SmallChatWorkspaceWindowTreeStub >> selectItem: anObject [
  "no-op stub"
]

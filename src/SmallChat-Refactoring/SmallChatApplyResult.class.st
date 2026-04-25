Class {
	#name : 'SmallChatApplyResult',
	#superclass : 'Object',
	#instVars : [
		'sources'
	],
	#category : 'SmallChat-Refactoring',
	#package : 'SmallChat-Refactoring'
}

{ #category : 'instance creation' }
SmallChatApplyResult class >> successWithSources: aDict [
  ^ self new setSources: aDict; yourself
]

{ #category : 'testing' }
SmallChatApplyResult >> isSuccess [
  ^ true
]

{ #category : 'accessing' }
SmallChatApplyResult >> newSourceFor: aUri [
  ^ sources at: aUri
]

{ #category : 'private' }
SmallChatApplyResult >> setSources: aDict [
  sources := aDict
]

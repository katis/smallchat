Class {
	#name : 'SmallChatApplyResult',
	#superclass : 'Object',
	#instVars : [
		'sources',
		'errorReason'
	],
	#category : 'SmallChat-Refactoring',
	#package : 'SmallChat-Refactoring'
}

{ #category : 'instance creation' }
SmallChatApplyResult class >> errorReason: aString [
  ^ self new setErrorReason: aString; yourself
]

{ #category : 'instance creation' }
SmallChatApplyResult class >> successWithSources: aDict [
  ^ self new setSources: aDict; yourself
]

{ #category : 'accessing' }
SmallChatApplyResult >> errorReason [
  ^ errorReason
]

{ #category : 'testing' }
SmallChatApplyResult >> isSuccess [
  ^ errorReason isNil
]

{ #category : 'accessing' }
SmallChatApplyResult >> newSourceFor: aUri [
  ^ sources at: aUri
]

{ #category : 'private' }
SmallChatApplyResult >> setErrorReason: aString [
  errorReason := aString
]

{ #category : 'private' }
SmallChatApplyResult >> setSources: aDict [
  sources := aDict
]

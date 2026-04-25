Class {
	#name : 'SmallChatApplyResult',
	#superclass : 'Object',
	#instVars : [
		'sources',
		'errorReason',
		'rollbackToken'
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

{ #category : 'accessing' }
SmallChatApplyResult >> rollbackToken [
  ^ rollbackToken
]

{ #category : 'accessing' }
SmallChatApplyResult >> rollbackToken: aToken [
  rollbackToken := aToken
]

{ #category : 'private' }
SmallChatApplyResult >> setErrorReason: aString [
  errorReason := aString
]

{ #category : 'private' }
SmallChatApplyResult >> setSources: aDict [
  sources := aDict
]

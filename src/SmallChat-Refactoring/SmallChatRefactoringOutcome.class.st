Class {
	#name : 'SmallChatRefactoringOutcome',
	#superclass : 'Object',
	#instVars : [
		'applyResult'
	],
	#category : 'SmallChat-Refactoring',
	#package : 'SmallChat-Refactoring'
}

{ #category : 'instance creation' }
SmallChatRefactoringOutcome class >> fromApplyResult: aResult [
  ^ self new setApplyResult: aResult; yourself
]

{ #category : 'accessing' }
SmallChatRefactoringOutcome >> errorReason [
  ^ applyResult errorReason
]

{ #category : 'testing' }
SmallChatRefactoringOutcome >> isSuccess [
  ^ applyResult isSuccess
]

{ #category : 'accessing' }
SmallChatRefactoringOutcome >> rollbackToken [
  ^ applyResult rollbackToken
]

{ #category : 'private' }
SmallChatRefactoringOutcome >> setApplyResult: aResult [
  applyResult := aResult
]

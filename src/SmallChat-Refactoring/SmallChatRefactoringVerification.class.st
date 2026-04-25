Class {
	#name : 'SmallChatRefactoringVerification',
	#superclass : 'Object',
	#instVars : [
		'errorsBefore',
		'errorsAfter',
		'warningsBefore',
		'warningsAfter',
		'perUri'
	],
	#category : 'SmallChat-Refactoring',
	#package : 'SmallChat-Refactoring'
}

{ #category : 'instance creation' }
SmallChatRefactoringVerification class >> empty [
  ^ self new setErrorsBefore: 0 errorsAfter: 0 warningsBefore: 0 warningsAfter: 0 perUri: Dictionary new
]

{ #category : 'accessing' }
SmallChatRefactoringVerification >> errorsAfter [ ^ errorsAfter
]

{ #category : 'accessing' }
SmallChatRefactoringVerification >> errorsBefore [ ^ errorsBefore
]

{ #category : 'accessing' }
SmallChatRefactoringVerification >> perUri [ ^ perUri
]

{ #category : 'private' }
SmallChatRefactoringVerification >> setErrorsBefore: eb errorsAfter: ea warningsBefore: wb warningsAfter: wa perUri: anUriDict [
  errorsBefore := eb.
  errorsAfter := ea.
  warningsBefore := wb.
  warningsAfter := wa.
  perUri := anUriDict
]

{ #category : 'accessing' }
SmallChatRefactoringVerification >> warningsAfter [ ^ warningsAfter
]

{ #category : 'accessing' }
SmallChatRefactoringVerification >> warningsBefore [ ^ warningsBefore
]

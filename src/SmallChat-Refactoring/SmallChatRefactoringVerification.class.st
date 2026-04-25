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

{ #category : 'instance creation' }
SmallChatRefactoringVerification class >> fromBefore: aBeforeReport after: anAfterReport forUri: aUri [
  "Build a Verification from two textDocument/diagnostic responses (or
   nil for missing). Counts severity 1 (error) and 2 (warning)."
  | beforeItems afterItems errBefore errAfter warnBefore warnAfter perUri |
  beforeItems := aBeforeReport ifNil: [ #() ] ifNotNil: [ aBeforeReport at: 'items' ifAbsent: [ #() ] ].
  afterItems := anAfterReport ifNil: [ #() ] ifNotNil: [ anAfterReport at: 'items' ifAbsent: [ #() ] ].
  errBefore := (beforeItems select: [ :d | (d at: 'severity' ifAbsent: [ nil ]) = 1 ]) size.
  errAfter := (afterItems select: [ :d | (d at: 'severity' ifAbsent: [ nil ]) = 1 ]) size.
  warnBefore := (beforeItems select: [ :d | (d at: 'severity' ifAbsent: [ nil ]) = 2 ]) size.
  warnAfter := (afterItems select: [ :d | (d at: 'severity' ifAbsent: [ nil ]) = 2 ]) size.
  perUri := Dictionary new at: aUri put: (Dictionary new
    at: 'before' put: beforeItems asArray;
    at: 'after' put: afterItems asArray;
    yourself); yourself.
  ^ self new
    setErrorsBefore: errBefore
    errorsAfter: errAfter
    warningsBefore: warnBefore
    warningsAfter: warnAfter
    perUri: perUri
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

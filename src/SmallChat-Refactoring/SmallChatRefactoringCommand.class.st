Class {
	#name : 'SmallChatRefactoringCommand',
	#superclass : 'Object',
	#category : 'SmallChat-Refactoring',
	#package : 'SmallChat-Refactoring'
}

{ #category : 'testing' }
SmallChatRefactoringCommand class >> isAbstract [
  ^ self == SmallChatRefactoringCommand
]

{ #category : 'execution' }
SmallChatRefactoringCommand >> apply [
  "Run the refactoring. Concrete commands return a SmallChatRefactoringOutcome."
  ^ self subclassResponsibility
]

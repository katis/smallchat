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

{ #category : 'rollback' }
SmallChatRefactoringCommand >> rollback: aToken [
  "Restore filesystem state captured in aToken (an opaque rollback token
   from a prior #apply outcome). Concrete commands override; the default
   raises subclassResponsibility so every command spells out its rollback
   path explicitly."
  ^ self subclassResponsibility
]

{ #category : 'verification' }
SmallChatRefactoringCommand >> verify [
  "Default: no verification performed. LSP-backed commands override to
   compute a real diagnostics delta via SmallChatRefactoringVerification."
  ^ SmallChatRefactoringVerification empty
]

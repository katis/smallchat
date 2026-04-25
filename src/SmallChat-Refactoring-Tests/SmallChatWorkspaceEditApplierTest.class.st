Class {
	#name : 'SmallChatWorkspaceEditApplierTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Refactoring-Tests',
	#package : 'SmallChat-Refactoring-Tests'
}

{ #category : 'tests' }
SmallChatWorkspaceEditApplierTest >> testEmptyChangesLeaveSourceUnchanged [
  | applier edit sources result |
  applier := SmallChatWorkspaceEditApplier new.
  edit := Dictionary new
    at: 'changes' put: (Dictionary new
      at: 'file:///t/a.txt' put: #();
      yourself);
    yourself.
  sources := Dictionary new at: 'file:///t/a.txt' put: 'hello'; yourself.
  result := applier applyWorkspaceEdit: edit withSources: sources.
  self assert: result isSuccess.
  self assert: (result newSourceFor: 'file:///t/a.txt') equals: 'hello'
]

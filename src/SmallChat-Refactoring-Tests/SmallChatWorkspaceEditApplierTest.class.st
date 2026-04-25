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

{ #category : 'tests' }
SmallChatWorkspaceEditApplierTest >> testSingleTextEditReplacesRange [
  | applier edit sources result |
  applier := SmallChatWorkspaceEditApplier new.
  edit := Dictionary new
    at: 'changes' put: (Dictionary new
      at: 'file:///t/a.txt' put: (Array with: (Dictionary new
        at: 'range' put: (Dictionary new
          at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 7; yourself);
          at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 12; yourself);
          yourself);
        at: 'newText' put: 'there';
        yourself));
      yourself);
    yourself.
  sources := Dictionary new at: 'file:///t/a.txt' put: 'Hello, World!'; yourself.
  result := applier applyWorkspaceEdit: edit withSources: sources.
  self assert: result isSuccess.
  self assert: (result newSourceFor: 'file:///t/a.txt') equals: 'Hello, there!'
]

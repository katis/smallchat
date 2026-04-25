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
SmallChatWorkspaceEditApplierTest >> testMultipleEditsAppliedInReverseOrder [
  "Two non-overlapping edits at line 0 cols 7-12 and 14-19 in
   'Hello, World, Earth!' rewrite to 'Hello, there, friend!'. The applier
   must process the later edit first so the earlier edit's byte offsets
   remain valid; an in-order naive walk would shift the second range."
  | applier edit sources result |
  applier := SmallChatWorkspaceEditApplier new.
  edit := Dictionary new
    at: 'changes' put: (Dictionary new
      at: 'file:///t/a.txt' put: (Array
        with: (Dictionary new
          at: 'range' put: (Dictionary new
            at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 7; yourself);
            at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 12; yourself);
            yourself);
          at: 'newText' put: 'there';
          yourself)
        with: (Dictionary new
          at: 'range' put: (Dictionary new
            at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 14; yourself);
            at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 19; yourself);
            yourself);
          at: 'newText' put: 'friend';
          yourself));
      yourself);
    yourself.
  sources := Dictionary new at: 'file:///t/a.txt' put: 'Hello, World, Earth!'; yourself.
  result := applier applyWorkspaceEdit: edit withSources: sources.
  self assert: result isSuccess.
  self assert: (result newSourceFor: 'file:///t/a.txt') equals: 'Hello, there, friend!'
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

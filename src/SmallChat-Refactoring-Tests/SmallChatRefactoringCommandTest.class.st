Class {
	#name : 'SmallChatRefactoringCommandTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Refactoring-Tests',
	#package : 'SmallChat-Refactoring-Tests'
}

{ #category : 'tests' }
SmallChatRefactoringCommandTest >> testStubCommandApplyReturnsSuccessOutcomeWithRollbackToken [
  "A concrete command (test stub here) calls #apply, the applier rewrites
   bytes through the injected memory FS, and the returned
   SmallChatRefactoringOutcome reports success with a rollback token whose
   shape matches the snapshot dictionary the applier captured."
  | fs file uri applier edit cmd outcome |
  fs := FileSystem memory.
  file := fs / '/a.txt'.
  file writeStreamDo: [ :s | s nextPutAll: 'Hello, World!' ].
  uri := 'file://' , file fullName.
  applier := SmallChatWorkspaceEditApplier new fileSystem: fs; yourself.
  edit := Dictionary new
    at: 'changes' put: (Dictionary new
      at: uri put: (Array with: (Dictionary new
        at: 'range' put: (Dictionary new
          at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 7; yourself);
          at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 12; yourself);
          yourself);
        at: 'newText' put: 'there';
        yourself));
      yourself);
    yourself.
  cmd := SmallChatStubRefactoringCommand new
    applier: applier;
    workspaceEdit: edit;
    yourself.
  outcome := cmd apply.
  self assert: outcome isSuccess.
  self assert: outcome rollbackToken notNil.
  self assert: (file readStreamDo: [ :s | s upToEnd ]) equals: 'Hello, there!'
]

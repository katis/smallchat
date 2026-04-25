Class {
	#name : 'SmallChatSmalltalkRenameMethodCommand',
	#superclass : 'SmallChatRefactoringCommand',
	#instVars : [
		'targetClass',
		'oldSelector',
		'newSelector'
	],
	#category : 'SmallChat-Refactoring',
	#package : 'SmallChat-Refactoring'
}

{ #category : 'execution' }
SmallChatSmalltalkRenameMethodCommand >> apply [
  "Snapshot the target class's instance-side methods, run
   ReRenameMethodRefactoring, return SmallChatRefactoringOutcome whose
   rollbackToken is the snapshot. Manual snapshot is robust under
   TestExecutionEnvironment, which suppresses EpMonitor and would defeat
   Epicea-based inversion."
  | snapshot refactoring result |
  snapshot := self snapshotInstanceSide: targetClass.
  refactoring := ReRenameMethodRefactoring
    renameMethod: oldSelector
    in: targetClass
    to: newSelector
    permutation: Dictionary new.
  [ refactoring execute ]
    on: Error
    do: [ :e |
      self restoreInstanceSide: snapshot of: targetClass.
      ^ SmallChatRefactoringOutcome fromApplyResult:
        (SmallChatApplyResult errorReason: 'Smalltalk rename failed: ' , e messageText) ].
  result := SmallChatApplyResult successWithSources: Dictionary new.
  result rollbackToken: snapshot.
  ^ SmallChatRefactoringOutcome fromApplyResult: result
]

{ #category : 'configuring' }
SmallChatSmalltalkRenameMethodCommand >> newSelector: aSelector [
  newSelector := aSelector
]

{ #category : 'configuring' }
SmallChatSmalltalkRenameMethodCommand >> oldSelector: aSelector [
  oldSelector := aSelector
]

{ #category : 'private' }
SmallChatSmalltalkRenameMethodCommand >> restoreInstanceSide: aSnapshot of: aClass [
  "Recompile every selector in the snapshot to its captured source +
   protocol. Then remove any selector currently on the class that wasn't
   in the snapshot (those got added since apply -- typically the new
   selector from the rename)."
  aSnapshot keysAndValuesDo: [ :sel :info |
    aClass compile: (info at: 'source') classified: (info at: 'protocol') ].
  (aClass selectors copy) do: [ :sel |
    (aSnapshot includesKey: sel) ifFalse: [ aClass removeSelector: sel ] ]
]

{ #category : 'rollback' }
SmallChatSmalltalkRenameMethodCommand >> rollback: aSnapshot [
  self restoreInstanceSide: aSnapshot of: targetClass
]

{ #category : 'private' }
SmallChatSmalltalkRenameMethodCommand >> snapshotInstanceSide: aClass [
  "Capture { selector -> { source, protocol } } for every instance-side
   selector currently on aClass. Used as the basis for rollback."
  | snap |
  snap := Dictionary new.
  aClass selectors do: [ :sel | | meth |
    meth := aClass >> sel.
    snap at: sel put: (Dictionary new
      at: 'source' put: meth sourceCode;
      at: 'protocol' put: meth protocolName asString;
      yourself) ].
  ^ snap
]

{ #category : 'configuring' }
SmallChatSmalltalkRenameMethodCommand >> targetClass: aClass [
  targetClass := aClass
]

Class {
	#name : 'SmallChatSmalltalkRenameMethodTest',
	#superclass : 'TestCase',
	#instVars : [
		'scratchPackage',
		'scratchClass'
	],
	#category : 'SmallChat-Refactoring-Tests',
	#package : 'SmallChat-Refactoring-Tests'
}

{ #category : 'accessing' }
SmallChatSmalltalkRenameMethodTest >> scratchClass [ ^ scratchClass
]

{ #category : 'running' }
SmallChatSmalltalkRenameMethodTest >> setUp [
  super setUp.
  scratchPackage := PackageOrganizer default ensurePackage: 'SmallChat-RefactoringScratch'.
  scratchClass := Object subclass: #SmallChatRefactoringScratchTarget.
  scratchPackage addClass: scratchClass.
  scratchClass compile: 'smallchatScratchAlpha ^ 42' classified: 'tests'
]

{ #category : 'running' }
SmallChatSmalltalkRenameMethodTest >> tearDown [
  super tearDown.
  scratchClass ifNotNil: [ [ scratchClass removeFromSystem ] on: Error do: [ :_ | nil ] ].
  scratchPackage ifNotNil: [
    [ scratchPackage classes isEmpty
      ifTrue: [ PackageOrganizer default unregisterPackage: scratchPackage ] ]
      on: Error do: [ :_ | nil ] ]
]

{ #category : 'tests' }
SmallChatSmalltalkRenameMethodTest >> testRenameMethodSwapsSelectorThenRollbackRestoresIt [
  "Apply a method-rename refactoring on a scratch class, observe the new
   selector took, then call #rollback: to restore the original. Selector
   names live as String literals here -- if we used Symbol literals,
   ReRenameMethodRefactoring would treat the test source itself as a
   sender of the old selector and rewrite this method out from under us."
  | oldSel newSel cmd outcome |
  oldSel := 'smallchatScratchAlpha' asSymbol.
  newSel := 'smallchatScratchBeta' asSymbol.
  cmd := SmallChatSmalltalkRenameMethodCommand new
    targetClass: scratchClass;
    oldSelector: oldSel;
    newSelector: newSel;
    yourself.
  outcome := cmd apply.
  self assert: outcome isSuccess.
  self assert: (scratchClass selectors includes: newSel).
  self deny: (scratchClass selectors includes: oldSel).
  cmd rollback: outcome rollbackToken.
  self assert: (scratchClass selectors includes: oldSel).
  self deny: (scratchClass selectors includes: newSel)
]

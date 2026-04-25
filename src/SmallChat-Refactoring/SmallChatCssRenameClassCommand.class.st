Class {
	#name : 'SmallChatCssRenameClassCommand',
	#superclass : 'SmallChatRefactoringCommand',
	#instVars : [
		'applier',
		'cssFileUri',
		'oldClassName',
		'newClassName'
	],
	#category : 'SmallChat-Refactoring',
	#package : 'SmallChat-Refactoring'
}

{ #category : 'configuring' }
SmallChatCssRenameClassCommand >> applier: anApplier [
  applier := anApplier
]

{ #category : 'execution' }
SmallChatCssRenameClassCommand >> apply [
  "Read CSS source through the applier, build TextEdits via tree-sitter,
   and run the applier on a single-URI WorkspaceEdit. Returns
   SmallChatRefactoringOutcome."
  | text edits workspaceEdit result |
  text := applier readSourceFor: cssFileUri.
  edits := self editsForCssText: text.
  edits isEmpty ifTrue: [
    ^ SmallChatRefactoringOutcome fromApplyResult:
      (SmallChatApplyResult errorReason: 'No class_selector occurrences of "' , oldClassName , '" found in ' , cssFileUri) ].
  workspaceEdit := Dictionary new
    at: 'changes' put: (Dictionary new at: cssFileUri put: edits; yourself);
    yourself.
  result := applier applyWorkspaceEdit: workspaceEdit.
  ^ SmallChatRefactoringOutcome fromApplyResult: result
]

{ #category : 'configuring' }
SmallChatCssRenameClassCommand >> cssFileUri: aUri [
  cssFileUri := aUri
]

{ #category : 'private' }
SmallChatCssRenameClassCommand >> editsForCssText: aText [
  "Walk class_selector nodes via tree-sitter, build TextEdit dictionaries
   replacing each occurrence of oldClassName's identifier byte range with
   newClassName. Returns an Array of LSP-shaped TextEdit dicts."
  | parser walker tree edits |
  parser := SmallChatTSParser new.
  walker := SmallChatTSNodeWalker new.
  tree := parser parseCssString: aText.
  edits := OrderedCollection new.
  (walker classSelectors: tree rootNode) do: [ :sel | | classNameNode idNode idText |
    classNameNode := sel namedChildren detect: [ :c | c type = 'class_name'] ifNone: [ nil ].
    classNameNode ifNotNil: [
      idNode := classNameNode namedChildren first.
      idText := idNode textFromSourceText: aText.
      idText = oldClassName ifTrue: [
        edits add: (Dictionary new
          at: 'range' put: (SmallChatTSRange
            startByte: idNode startByte
            endByte: idNode endByte
            source: aText) asLSPPositionRange;
          at: 'newText' put: newClassName;
          yourself) ] ] ].
  ^ edits asArray
]

{ #category : 'configuring' }
SmallChatCssRenameClassCommand >> newClassName: aString [
  newClassName := aString
]

{ #category : 'configuring' }
SmallChatCssRenameClassCommand >> oldClassName: aString [
  oldClassName := aString
]

{ #category : 'rollback' }
SmallChatCssRenameClassCommand >> rollback: aToken [
  applier rollback: aToken
]

Class {
	#name : 'SmallChatCssRenameClassCommand',
	#superclass : 'SmallChatRefactoringCommand',
	#instVars : [
		'applier',
		'cssFileUri',
		'oldClassName',
		'newClassName',
		'model'
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
  "Read CSS source through the applier, build CSS edits via tree-sitter,
   and -- when a Famix model is provided -- TS-side edits for every
   member_expression styles.X reference. Combine into a single
   WorkspaceEdit and apply atomically."
  | text cssEdits tsEditsByUri changes workspaceEdit result |
  text := applier readSourceFor: cssFileUri.
  cssEdits := self editsForCssText: text.
  cssEdits isEmpty ifTrue: [
    ^ SmallChatRefactoringOutcome fromApplyResult:
      (SmallChatApplyResult errorReason: 'No class_selector occurrences of "' , oldClassName , '" found in ' , cssFileUri) ].
  tsEditsByUri := self tsEditsByUriFromModel.
  changes := Dictionary new.
  changes at: cssFileUri put: cssEdits.
  tsEditsByUri keysAndValuesDo: [ :uri :edits | changes at: uri put: edits ].
  workspaceEdit := Dictionary new at: 'changes' put: changes; yourself.
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
SmallChatCssRenameClassCommand >> model: aModel [
  model := aModel
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

{ #category : 'private' }
SmallChatCssRenameClassCommand >> tsEditsByUriFromModel [
  "Walk the model for CSSClassReference entities pointing at the renamed
   class, group by TS URI, and build property-identifier TextEdits.
   Each ref's sourceAnchor covers the whole member_expression
   (`styles.X`); the property identifier sits at the last `oldClassName
   size` bytes, so we don't need to re-parse to locate it."
  | cssClass refs editsByUri |
  model isNil ifTrue: [ ^ Dictionary new ].
  cssClass := (model allWithType: SmallChatFamixCSSClass)
    detect: [ :c | c name = oldClassName
      and: [ c file notNil
      and: [ c file sourceAnchor notNil
      and: [ c file sourceAnchor fileUri = cssFileUri ] ] ] ]
    ifNone: [ ^ Dictionary new ].
  refs := (model allWithType: SmallChatFamixCSSClassReference)
    select: [ :r | r referent == cssClass ].
  editsByUri := Dictionary new.
  refs do: [ :ref | | tsUri propEndByte propStartByte tsText |
    tsUri := ref sourceAnchor fileUri.
    propEndByte := ref sourceAnchor endByte.
    propStartByte := propEndByte - oldClassName size.
    tsText := applier readSourceFor: tsUri.
    (editsByUri at: tsUri ifAbsentPut: [ OrderedCollection new ])
      add: (Dictionary new
        at: 'range' put: (SmallChatTSRange
          startByte: propStartByte
          endByte: propEndByte
          source: tsText) asLSPPositionRange;
        at: 'newText' put: newClassName;
        yourself) ].
  ^ editsByUri collect: [ :coll | coll asArray ]
]

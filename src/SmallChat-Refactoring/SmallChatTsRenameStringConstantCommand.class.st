Class {
	#name : 'SmallChatTsRenameStringConstantCommand',
	#superclass : 'SmallChatRefactoringCommand',
	#instVars : [
		'applier',
		'rootUri',
		'fileNameFilter',
		'oldText',
		'newText'
	],
	#category : 'SmallChat-Refactoring',
	#package : 'SmallChat-Refactoring'
}

{ #category : 'configuring' }
SmallChatTsRenameStringConstantCommand >> applier: anApplier [
  applier := anApplier
]

{ #category : 'execution' }
SmallChatTsRenameStringConstantCommand >> apply [
  "Discover candidate URIs under rootUri, parse each, build per-file
   string-constant TextEdits, apply atomically through the applier.
   Empty change set surfaces as a failed outcome with errorReason."
  | uris changes workspaceEdit result |
  uris := self discoverFileUris.
  changes := Dictionary new.
  uris do: [ :uri | | text edits |
    text := applier readSourceFor: uri.
    edits := self editsForText: text.
    edits isEmpty ifFalse: [ changes at: uri put: edits ] ].
  changes isEmpty ifTrue: [
    ^ SmallChatRefactoringOutcome fromApplyResult:
      (SmallChatApplyResult errorReason: 'No string-constant occurrences of "' , oldText , '" under ' , rootUri) ].
  workspaceEdit := Dictionary new at: 'changes' put: changes; yourself.
  result := applier applyWorkspaceEdit: workspaceEdit.
  ^ SmallChatRefactoringOutcome fromApplyResult: result
]

{ #category : 'private' }
SmallChatTsRenameStringConstantCommand >> discoverFileUris [
  "Walk rootUri (directory or single file), keep .ts/.tsx/.js/.jsx,
   apply fileNameFilter regex (when set) against each URI. Returns
   the surviving URIs as an Array."
  | extensions root files matcher uris |
  extensions := #('ts' 'tsx' 'js' 'jsx').
  root := self resolveRoot.
  files := root isDirectory
    ifTrue: [ root allChildren select: [ :c | c isFile and: [ extensions includes: c extension ] ] ]
    ifFalse: [ { root } ].
  uris := files collect: [ :f | 'file://' , f fullName ].
  matcher := fileNameFilter ifNotNil: [ fileNameFilter asRegex ].
  ^ (matcher
    ifNil: [ uris ]
    ifNotNil: [ uris select: [ :uri | matcher search: uri ] ]) asArray
]

{ #category : 'private' }
SmallChatTsRenameStringConstantCommand >> editsForText: aText [
  "Parse aText as TSX, walk simple string + literal-template fragments,
   build LSP TextEdits for every fragment whose text equals oldText."
  | parser walker tree |
  parser := SmallChatTSParser new.
  walker := SmallChatTSNodeWalker new.
  tree := parser parseTsxString: aText.
  ^ ((walker stringFragmentsIn: tree rootNode source: aText)
    select: [ :frag | (frag at: 'text') = oldText ])
    collect: [ :frag |
      Dictionary new
        at: 'range' put: (SmallChatTSRange
          startByte: (frag at: 'startByte')
          endByte: (frag at: 'endByte')
          source: aText) asLSPPositionRange;
        at: 'newText' put: newText;
        yourself ]
]

{ #category : 'configuring' }
SmallChatTsRenameStringConstantCommand >> fileNameFilter: aRegexString [
  fileNameFilter := aRegexString
]

{ #category : 'configuring' }
SmallChatTsRenameStringConstantCommand >> newText: aString [
  newText := aString
]

{ #category : 'configuring' }
SmallChatTsRenameStringConstantCommand >> oldText: aString [
  oldText := aString
]

{ #category : 'private' }
SmallChatTsRenameStringConstantCommand >> resolveRoot [
  "Decode rootUri as file:// + path; resolve under the applier-injected
   FileSystem so memory FS in tests works the same as disk in production."
  | path |
  (rootUri beginsWith: 'file://') ifFalse: [ self error: 'Unsupported URI: ' , rootUri ].
  path := rootUri copyFrom: 'file://' size + 1 to: rootUri size.
  ^ applier fileSystem / path
]

{ #category : 'rollback' }
SmallChatTsRenameStringConstantCommand >> rollback: aToken [
  applier rollback: aToken
]

{ #category : 'configuring' }
SmallChatTsRenameStringConstantCommand >> rootUri: aUri [
  rootUri := aUri
]

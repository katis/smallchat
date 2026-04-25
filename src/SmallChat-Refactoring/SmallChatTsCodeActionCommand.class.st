Class {
	#name : 'SmallChatTsCodeActionCommand',
	#superclass : 'SmallChatRefactoringCommand',
	#instVars : [
		'client',
		'applier',
		'fileUri',
		'startLine',
		'startCharacter',
		'endLine',
		'endCharacter',
		'kind'
	],
	#category : 'SmallChat-Refactoring',
	#package : 'SmallChat-Refactoring'
}

{ #category : 'configuring' }
SmallChatTsCodeActionCommand >> applier: anApplier [
  applier := anApplier
]

{ #category : 'execution' }
SmallChatTsCodeActionCommand >> apply [
  "Open URI on the LSP client, send textDocument/codeAction restricted to
   the configured kind, pick the first action with an edit, and run the
   applier on it. tsgo can return an empty list (no action available);
   surface that as a failed outcome with errorReason."
  | text actions edit action |
  text := applier readSourceFor: fileUri.
  client
    openDocumentUri: fileUri
    languageId: (self languageIdForUri: fileUri)
    text: text.
  actions := client
    request: (Dictionary new
      at: 'method' put: 'textDocument/codeAction';
      at: 'params' put: (Dictionary new
        at: 'textDocument' put: (Dictionary new at: 'uri' put: fileUri; yourself);
        at: 'range' put: (Dictionary new
          at: 'start' put: (Dictionary new at: 'line' put: startLine; at: 'character' put: startCharacter; yourself);
          at: 'end' put: (Dictionary new at: 'line' put: endLine; at: 'character' put: endCharacter; yourself);
          yourself);
        at: 'context' put: (Dictionary new
          at: 'diagnostics' put: #();
          at: 'only' put: (Array with: kind);
          yourself);
        yourself);
      yourself)
    onDocumentUri: fileUri.
  (actions isNil or: [ actions isEmpty ]) ifTrue: [
    ^ SmallChatRefactoringOutcome fromApplyResult:
      (SmallChatApplyResult errorReason: 'No code action of kind ' , kind , ' available') ].
  action := actions first.
  edit := action at: 'edit' ifAbsent: [ nil ].
  edit isNil ifTrue: [
    ^ SmallChatRefactoringOutcome fromApplyResult:
      (SmallChatApplyResult errorReason: 'Code action returned no edit; codeAction/resolve fallback not yet implemented') ].
  ^ SmallChatRefactoringOutcome fromApplyResult: (applier applyWorkspaceEdit: edit)
]

{ #category : 'configuring' }
SmallChatTsCodeActionCommand >> client: aClient [
  client := aClient
]

{ #category : 'configuring' }
SmallChatTsCodeActionCommand >> endCharacter: anInteger [
  endCharacter := anInteger
]

{ #category : 'configuring' }
SmallChatTsCodeActionCommand >> endLine: anInteger [
  endLine := anInteger
]

{ #category : 'configuring' }
SmallChatTsCodeActionCommand >> fileUri: aUri [
  fileUri := aUri
]

{ #category : 'configuring' }
SmallChatTsCodeActionCommand >> kind: aString [
  kind := aString
]

{ #category : 'private' }
SmallChatTsCodeActionCommand >> languageIdForUri: aUri [
  (aUri endsWith: '.tsx') ifTrue: [ ^ 'typescriptreact' ].
  (aUri endsWith: '.ts') ifTrue: [ ^ 'typescript' ].
  (aUri endsWith: '.jsx') ifTrue: [ ^ 'javascriptreact' ].
  (aUri endsWith: '.js') ifTrue: [ ^ 'javascript' ].
  ^ 'typescript'
]

{ #category : 'rollback' }
SmallChatTsCodeActionCommand >> rollback: aToken [
  applier rollback: aToken
]

{ #category : 'configuring' }
SmallChatTsCodeActionCommand >> startCharacter: anInteger [
  startCharacter := anInteger
]

{ #category : 'configuring' }
SmallChatTsCodeActionCommand >> startLine: anInteger [
  startLine := anInteger
]

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
		'kind',
		'diagnosticsBefore',
		'diagnosticsAfter'
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
  "Open URI on the LSP client, capture pre-apply diagnostics, send
   textDocument/codeAction restricted to the configured kind, run the
   applier on the first action's edit, and capture post-apply
   diagnostics on success."
  | text actions edit action result |
  text := applier readSourceFor: fileUri.
  client
    openDocumentUri: fileUri
    languageId: (self languageIdForUri: fileUri)
    text: text.
  diagnosticsBefore := self fetchDiagnostics.
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
  result := applier applyWorkspaceEdit: edit.
  result isSuccess ifTrue: [ diagnosticsAfter := self fetchDiagnostics ].
  ^ SmallChatRefactoringOutcome fromApplyResult: result
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

{ #category : 'private' }
SmallChatTsCodeActionCommand >> fetchDiagnostics [
  ^ client
    request: (Dictionary new
      at: 'method' put: 'textDocument/diagnostic';
      at: 'params' put: (Dictionary new
        at: 'textDocument' put: (Dictionary new at: 'uri' put: fileUri; yourself);
        yourself);
      yourself)
    onDocumentUri: fileUri
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

{ #category : 'verification' }
SmallChatTsCodeActionCommand >> verify [
  ^ SmallChatRefactoringVerification
    fromBefore: diagnosticsBefore
    after: diagnosticsAfter
    forUri: fileUri
]

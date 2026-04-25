Class {
	#name : 'SmallChatTsRenameSymbolCommand',
	#superclass : 'SmallChatRefactoringCommand',
	#instVars : [
		'client',
		'applier',
		'fileUri',
		'line',
		'character',
		'newName'
	],
	#category : 'SmallChat-Refactoring',
	#package : 'SmallChat-Refactoring'
}

{ #category : 'configuring' }
SmallChatTsRenameSymbolCommand >> applier: anApplier [
  applier := anApplier
]

{ #category : 'execution' }
SmallChatTsRenameSymbolCommand >> apply [
  "Open the URI on the LSP client, send textDocument/rename, and run the
   applier on the returned WorkspaceEdit. tsgo can refuse a rename
   (response nil) -- surface as a failed outcome with errorReason."
  | text response result |
  text := applier readSourceFor: fileUri.
  client
    openDocumentUri: fileUri
    languageId: (self languageIdForUri: fileUri)
    text: text.
  response := client
    request: (Dictionary new
      at: 'method' put: 'textDocument/rename';
      at: 'params' put: (Dictionary new
        at: 'textDocument' put: (Dictionary new at: 'uri' put: fileUri; yourself);
        at: 'position' put: (Dictionary new
          at: 'line' put: line;
          at: 'character' put: character;
          yourself);
        at: 'newName' put: newName;
        yourself);
      yourself)
    onDocumentUri: fileUri.
  response isNil ifTrue: [
    ^ SmallChatRefactoringOutcome fromApplyResult:
      (SmallChatApplyResult errorReason: 'LSP rename returned no edit') ].
  result := applier applyWorkspaceEdit: response.
  ^ SmallChatRefactoringOutcome fromApplyResult: result
]

{ #category : 'configuring' }
SmallChatTsRenameSymbolCommand >> character: anInteger [
  character := anInteger
]

{ #category : 'configuring' }
SmallChatTsRenameSymbolCommand >> client: aClient [
  client := aClient
]

{ #category : 'configuring' }
SmallChatTsRenameSymbolCommand >> fileUri: aUri [
  fileUri := aUri
]

{ #category : 'private' }
SmallChatTsRenameSymbolCommand >> languageIdForUri: aUri [
  (aUri endsWith: '.tsx') ifTrue: [ ^ 'typescriptreact' ].
  (aUri endsWith: '.ts') ifTrue: [ ^ 'typescript' ].
  (aUri endsWith: '.jsx') ifTrue: [ ^ 'javascriptreact' ].
  (aUri endsWith: '.js') ifTrue: [ ^ 'javascript' ].
  ^ 'typescript'
]

{ #category : 'configuring' }
SmallChatTsRenameSymbolCommand >> line: anInteger [
  line := anInteger
]

{ #category : 'configuring' }
SmallChatTsRenameSymbolCommand >> newName: aString [
  newName := aString
]

{ #category : 'rollback' }
SmallChatTsRenameSymbolCommand >> rollback: aToken [
  applier rollback: aToken
]

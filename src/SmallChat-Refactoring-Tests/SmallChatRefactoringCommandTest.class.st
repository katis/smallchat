Class {
	#name : 'SmallChatRefactoringCommandTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Refactoring-Tests',
	#package : 'SmallChat-Refactoring-Tests'
}

{ #category : 'tests' }
SmallChatRefactoringCommandTest >> testRollbackThroughCommandRestoresFile [
  "After apply, cmd rollback: outcome rollbackToken delegates to the applier
   and restores file bytes. Agent path uses the outcome's token, never
   touches the applier directly."
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
  cmd rollback: outcome rollbackToken.
  self assert: (file readStreamDo: [ :s | s upToEnd ]) equals: 'Hello, World!'
]

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

{ #category : 'tests' }
SmallChatRefactoringCommandTest >> testTsCodeActionAppliesReturnedEdit [
  "End-to-end: stub LSP client returns a textDocument/codeAction list
   whose first action carries an edit; the command runs the applier on
   it. File content reflects the edit; outcome carries a rollback token."
  | fs file uri stubClient applier workspaceEdit codeActionList cmd outcome request |
  fs := FileSystem memory.
  file := fs / '/foo.ts'.
  file writeStreamDo: [ :s | s nextPutAll: 'const x = 1 + 2 + 3;' ].
  uri := 'file://' , file fullName.
  applier := SmallChatWorkspaceEditApplier new fileSystem: fs; yourself.
  workspaceEdit := Dictionary new
    at: 'changes' put: (Dictionary new
      at: uri put: (Array with: (Dictionary new
        at: 'range' put: (Dictionary new
          at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 10; yourself);
          at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 19; yourself);
          yourself);
        at: 'newText' put: 'sum()';
        yourself));
      yourself);
    yourself.
  codeActionList := Array with: (Dictionary new
    at: 'title' put: 'Extract to function';
    at: 'kind' put: 'refactor.extract.function';
    at: 'edit' put: workspaceEdit;
    yourself).
  stubClient := SmallChatStubLSPClient new
    cannedResponse: 'textDocument/codeAction' is: codeActionList;
    yourself.
  cmd := SmallChatTsCodeActionCommand new
    client: stubClient;
    applier: applier;
    fileUri: uri;
    startLine: 0;
    startCharacter: 10;
    endLine: 0;
    endCharacter: 19;
    kind: 'refactor.extract.function';
    yourself.
  outcome := cmd apply.
  self assert: outcome isSuccess.
  self assert: outcome rollbackToken notNil.
  self assert: (file readStreamDo: [ :s | s upToEnd ]) equals: 'const x = sum();'.
  request := stubClient requestLog detect: [ :r | (r at: 'method') = 'textDocument/codeAction' ].
  self assert: ((((request at: 'params') at: 'context') at: 'only') first) equals: 'refactor.extract.function'
]

{ #category : 'tests' }
SmallChatRefactoringCommandTest >> testTsCodeActionEmptyResponseFailsOutcome [
  "An empty action list (tsgo refuses the refactor at this position) -> failed outcome, file untouched."
  | fs file uri stubClient applier cmd outcome |
  fs := FileSystem memory.
  file := fs / '/foo.ts'.
  file writeStreamDo: [ :s | s nextPutAll: 'const x = 1;' ].
  uri := 'file://' , file fullName.
  applier := SmallChatWorkspaceEditApplier new fileSystem: fs; yourself.
  stubClient := SmallChatStubLSPClient new
    cannedResponse: 'textDocument/codeAction' is: #();
    yourself.
  cmd := SmallChatTsCodeActionCommand new
    client: stubClient; applier: applier;
    fileUri: uri;
    startLine: 0; startCharacter: 0; endLine: 0; endCharacter: 12;
    kind: 'refactor.extract.function';
    yourself.
  outcome := cmd apply.
  self deny: outcome isSuccess.
  self assert: outcome errorReason notNil.
  self assert: (file readStreamDo: [ :s | s upToEnd ]) equals: 'const x = 1;'
]

{ #category : 'tests' }
SmallChatRefactoringCommandTest >> testTsCodeActionMoveToFileMultiUriEditAtomic [
  "Move-to-file refactor returns a multi-URI WorkspaceEdit (text removed
   from old file, added to new file). Applier applies both atomically."
  | fs srcFile dstFile srcUri dstUri stubClient applier workspaceEdit cmd outcome |
  fs := FileSystem memory.
  srcFile := fs / '/from.ts'.
  dstFile := fs / '/to.ts'.
  srcFile writeStreamDo: [ :s | s nextPutAll: 'export function moveMe() { return 1; }' ].
  dstFile writeStreamDo: [ :s | s nextPutAll: '// existing content' ].
  srcUri := 'file://' , srcFile fullName.
  dstUri := 'file://' , dstFile fullName.
  applier := SmallChatWorkspaceEditApplier new fileSystem: fs; yourself.
  workspaceEdit := Dictionary new
    at: 'changes' put: (Dictionary new
      at: srcUri put: (Array with: (Dictionary new
        at: 'range' put: (Dictionary new
          at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 0; yourself);
          at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 38; yourself);
          yourself);
        at: 'newText' put: '';
        yourself));
      at: dstUri put: (Array with: (Dictionary new
        at: 'range' put: (Dictionary new
          at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 19; yourself);
          at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 19; yourself);
          yourself);
        at: 'newText' put: ' export function moveMe() { return 1; }';
        yourself));
      yourself);
    yourself.
  stubClient := SmallChatStubLSPClient new
    cannedResponse: 'textDocument/codeAction' is: (Array with: (Dictionary new
      at: 'title' put: 'Move to to.ts';
      at: 'kind' put: 'refactor.move.toFile';
      at: 'edit' put: workspaceEdit;
      yourself));
    yourself.
  cmd := SmallChatTsCodeActionCommand new
    client: stubClient; applier: applier;
    fileUri: srcUri;
    startLine: 0; startCharacter: 0; endLine: 0; endCharacter: 38;
    kind: 'refactor.move.toFile';
    yourself.
  outcome := cmd apply.
  self assert: outcome isSuccess.
  self assert: (srcFile readStreamDo: [ :s | s upToEnd ]) equals: ''.
  self assert: (dstFile readStreamDo: [ :s | s upToEnd ]) equals: '// existing content export function moveMe() { return 1; }'
]

{ #category : 'tests' }
SmallChatRefactoringCommandTest >> testTsRenameSymbolAppliesLspWorkspaceEditToDisk [
  "End-to-end: stub LSP client returns a canned WorkspaceEdit for
   textDocument/rename; the command opens the doc, sends rename, runs
   the applier on the response. The file content reflects the edit;
   the outcome carries a rollback token."
  | fs file uri stubClient applier workspaceEdit cmd outcome request |
  fs := FileSystem memory.
  file := fs / '/Button.ts'.
  file writeStreamDo: [ :s | s nextPutAll: 'const oldName = 1;' ].
  uri := 'file://' , file fullName.
  applier := SmallChatWorkspaceEditApplier new fileSystem: fs; yourself.
  workspaceEdit := Dictionary new
    at: 'changes' put: (Dictionary new
      at: uri put: (Array with: (Dictionary new
        at: 'range' put: (Dictionary new
          at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 6; yourself);
          at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 13; yourself);
          yourself);
        at: 'newText' put: 'newName';
        yourself));
      yourself);
    yourself.
  stubClient := SmallChatStubLSPClient new
    cannedResponse: 'textDocument/rename' is: workspaceEdit;
    yourself.
  cmd := SmallChatTsRenameSymbolCommand new
    client: stubClient;
    applier: applier;
    fileUri: uri;
    line: 0;
    character: 7;
    newName: 'newName';
    yourself.
  outcome := cmd apply.
  self assert: outcome isSuccess.
  self assert: outcome rollbackToken notNil.
  self assert: (file readStreamDo: [ :s | s upToEnd ]) equals: 'const newName = 1;'.
  self assert: stubClient openedUris size equals: 1.
  self assert: ((stubClient openedUris first) at: 'languageId') equals: 'typescript'.
  request := stubClient requestLog detect: [ :r | (r at: 'method') = 'textDocument/rename' ].
  self assert: ((request at: 'params') at: 'newName') equals: 'newName'.
  self assert: (((request at: 'params') at: 'position') at: 'line') equals: 0.
  self assert: (((request at: 'params') at: 'position') at: 'character') equals: 7
]

{ #category : 'tests' }
SmallChatRefactoringCommandTest >> testTsRenameSymbolFailsWhenServerReturnsNoEdit [
  "tsgo can refuse a rename (e.g. position not on a renameable identifier)
   by returning null. The command must surface that as a failed outcome
   and not touch the file."
  | fs file uri stubClient applier cmd outcome |
  fs := FileSystem memory.
  file := fs / '/Button.ts'.
  file writeStreamDo: [ :s | s nextPutAll: 'const x = 1;' ].
  uri := 'file://' , file fullName.
  applier := SmallChatWorkspaceEditApplier new fileSystem: fs; yourself.
  stubClient := SmallChatStubLSPClient new
    cannedResponse: 'textDocument/rename' is: nil;
    yourself.
  cmd := SmallChatTsRenameSymbolCommand new
    client: stubClient; applier: applier;
    fileUri: uri; line: 0; character: 6; newName: 'y';
    yourself.
  outcome := cmd apply.
  self deny: outcome isSuccess.
  self assert: outcome errorReason notNil.
  self assert: (file readStreamDo: [ :s | s upToEnd ]) equals: 'const x = 1;'
]

{ #category : 'tests' }
SmallChatRefactoringCommandTest >> testTsRenameSymbolRollbackRestoresOriginalText [
  "After a successful apply, cmd rollback: outcome rollbackToken restores
   the file to its pre-rename bytes through the same applier."
  | fs file uri stubClient applier workspaceEdit cmd outcome |
  fs := FileSystem memory.
  file := fs / '/Button.ts'.
  file writeStreamDo: [ :s | s nextPutAll: 'const oldName = 1;' ].
  uri := 'file://' , file fullName.
  applier := SmallChatWorkspaceEditApplier new fileSystem: fs; yourself.
  workspaceEdit := Dictionary new
    at: 'changes' put: (Dictionary new
      at: uri put: (Array with: (Dictionary new
        at: 'range' put: (Dictionary new
          at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 6; yourself);
          at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 13; yourself);
          yourself);
        at: 'newText' put: 'newName';
        yourself));
      yourself);
    yourself.
  stubClient := SmallChatStubLSPClient new
    cannedResponse: 'textDocument/rename' is: workspaceEdit;
    yourself.
  cmd := SmallChatTsRenameSymbolCommand new
    client: stubClient; applier: applier;
    fileUri: uri; line: 0; character: 7; newName: 'newName';
    yourself.
  outcome := cmd apply.
  self assert: outcome isSuccess.
  cmd rollback: outcome rollbackToken.
  self assert: (file readStreamDo: [ :s | s upToEnd ]) equals: 'const oldName = 1;'
]

{ #category : 'tests' }
SmallChatRefactoringCommandTest >> testVerificationEmptyHasZeroCounts [
  "SmallChatRefactoringVerification empty is the default for commands
   that didn't capture diagnostics. All counts are zero, perUri is
   empty -- callers can safely query without nil-checking."
  | v |
  v := SmallChatRefactoringVerification empty.
  self assert: v errorsBefore equals: 0.
  self assert: v errorsAfter equals: 0.
  self assert: v warningsBefore equals: 0.
  self assert: v warningsAfter equals: 0.
  self assert: v perUri isEmpty
]

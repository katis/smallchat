"
Tests for SmallChatTsNav, the discovery/edit facade chats use against a TS workspace. Memory FileSystem fixtures stand in for real disk projects; the LSP client is a SmallChatLSPStubTransport-backed SmallChatLSPClient where needed.
"
Class {
	#name : 'SmallChatTsNavTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-TsNav-Tests',
	#package : 'SmallChat-TsNav-Tests'
}

{ #category : 'running' }
SmallChatTsNavTest >> tearDown [
	"Each test sets currentWorkspace; reset to keep the class-side ivar clean
	 for the next test (the LM eval capability normally does this in
	 #ensure:, but tests bypass that path)."
	SmallChatTsNav currentWorkspace: nil.
	super tearDown
]

{ #category : 'tests' }
SmallChatTsNavTest >> testCodeActionsListAndApply [
	"codeActionsAt:line:character: issues textDocument/codeAction and renders
	 each action with [N] title (kind). The actions are remembered by
	 1-based index so applyCodeAction: can resolve them; apply runs the
	 WorkspaceEdit through SmallChatWorkspaceEditApplier and reports success."
	| fs root file uri stub ws actions listOut applied |
	fs := FileSystem memory.
	root := fs / 'project'.
	root ensureCreateDirectory.
	file := root / 'a.ts'.
	file writeStreamDo: [ :s | s nextPutAll: 'const x = 1;' ].
	uri := 'file://' , file fullName.
	actions := Array with: (Dictionary new
		at: 'title' put: 'Add comment';
		at: 'kind' put: 'quickfix';
		at: 'edit' put: (Dictionary new
			at: 'changes' put: (Dictionary new
				at: uri put: (Array with: (Dictionary new
					at: 'range' put: (Dictionary new
						at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 12; yourself);
						at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 12; yourself);
						yourself);
					at: 'newText' put: ' /* fix */';
					yourself));
				yourself);
			yourself);
		yourself).
	stub := SmallChatStubLSPClient new
		cannedResponse: 'textDocument/codeAction' is: actions;
		yourself.
	ws := SmallChatTsWorkspace new
		name: 'fixture';
		path: root;
		lspClient: stub;
		yourself.
	SmallChatTsNav currentWorkspace: ws.
	listOut := SmallChatTsNav codeActionsAt: 'a.ts' line: 0 character: 5.
	self assert: (listOut includesSubstring: 'Add comment').
	self assert: (listOut includesSubstring: '[1]').
	applied := SmallChatTsNav applyCodeAction: 1.
	self assert: (applied includesSubstring: 'success').
	self assert: (file readStreamDo: [ :s | s upToEnd ]) equals: 'const x = 1; /* fix */'
]

{ #category : 'tests' }
SmallChatTsNavTest >> testDiagnosticsForRendersLspItems [
	"diagnosticsFor: opens the workspace-relative file on the LSP client and
	 issues textDocument/diagnostic. The canned response yields one Diagnostic
	 per item and renders them as bulleted lines with severity + message."
	| fs root file uri stub ws response out |
	fs := FileSystem memory.
	root := fs / 'project'.
	root ensureCreateDirectory.
	file := root / 'a.ts'.
	file writeStreamDo: [ :s | s nextPutAll: 'const x = bad;' ].
	uri := 'file://' , file fullName.
	response := Dictionary new
		at: 'kind' put: 'full';
		at: 'items' put: (Array with: (Dictionary new
			at: 'range' put: (Dictionary new
				at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 10; yourself);
				at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 13; yourself);
				yourself);
			at: 'severity' put: 1;
			at: 'message' put: 'Cannot find name bad';
			yourself));
		yourself.
	stub := SmallChatStubLSPClient new
		cannedResponse: 'textDocument/diagnostic' is: response;
		yourself.
	ws := SmallChatTsWorkspace new
		name: 'fixture';
		path: root;
		lspClient: stub;
		yourself.
	SmallChatTsNav currentWorkspace: ws.
	out := SmallChatTsNav diagnosticsFor: 'a.ts'.
	self assert: (out includesSubstring: 'Cannot find name bad').
	self assert: (out includesSubstring: 'a.ts')
]

{ #category : 'tests' }
SmallChatTsNavTest >> testEvalSmalltalkBindsTsNavCurrentWorkspace [
	"During eval.smalltalk run:, SmallChatTsNav currentWorkspace must be the
	 call's workspace so SmallChatTsNav selectors invoked from the eval body
	 see the right workspace. The capability must restore the binding (to nil)
	 after the eval so a follow-up Pharo eval does not see a stale TS context."
	| ws call result before after |
	ws := SmallChatTsWorkspace new name: 'fixture'; yourself.
	call := SmallChatCapabilityCall name: 'eval.smalltalk' argumentsJson: '{"code":"SmallChatTsNav currentWorkspace name"}'.
	call workspace: ws.
	before := SmallChatTsNav currentWorkspace.
	result := SmallChatEvalSmalltalkCapability run: call.
	after := SmallChatTsNav currentWorkspace.
	self assert: result asTextForLM equals: '''fixture'''.
	self assert: before equals: nil.
	self assert: after equals: nil
]

{ #category : 'tests' }
SmallChatTsNavTest >> testFindFilesListsCssMatchedByGlob [
	"findFiles: returns workspace-relative paths whose tail matches the glob.
	 Reads from the lazy Famix model: CSSModuleFile entities get listed for
	 *.module.css; non-Famix files (README.md) never appear because the
	 importer skipped them."
	| fs root ws out |
	fs := FileSystem memory.
	root := fs / 'project'.
	root ensureCreateDirectory.
	(root / 'styles.module.css') writeStreamDo: [ :s | s nextPutAll: '.x { }' ].
	(root / 'README.md') writeStreamDo: [ :s | s nextPutAll: '# r' ].
	ws := SmallChatTsWorkspace new
		name: 'fixture';
		path: root;
		yourself.
	SmallChatTsNav currentWorkspace: ws.
	out := SmallChatTsNav findFiles: '*.module.css'.
	self assert: (out includesSubstring: 'styles.module.css').
	self deny: (out includesSubstring: 'README.md')
]

{ #category : 'tests' }
SmallChatTsNavTest >> testFindFilesWithoutWorkspaceReturnsGuard [
	"All discovery selectors must short-circuit with a friendly Markdown
	 guard when no TS workspace is bound -- otherwise an evaluate against
	 a Pharo-only session would NPE. Pin findFiles: as the canary."
	| out |
	SmallChatTsNav currentWorkspace: nil.
	out := SmallChatTsNav findFiles: '*.ts'.
	self assert: (out includesSubstring: 'no TS workspace bound')
]

{ #category : 'tests' }
SmallChatTsNavTest >> testFindReferencesOfListsFamixImports [
	"findReferencesOf: surfaces SmallChatFamixImport entities whose name
	 matches -- the Famix model's record of cross-module dependencies on a
	 symbol. Test injects an Import directly into the lazy-empty model so
	 the assertion does not depend on a real LSP-driven populate."
	| fs root ws model imp consumerUri out |
	fs := FileSystem memory.
	root := fs / 'project'.
	root ensureCreateDirectory.
	ws := SmallChatTsWorkspace new
		name: 'fixture';
		path: root;
		yourself.
	model := ws famixModel.
	consumerUri := 'file://' , (root / 'consumer.ts') fullName.
	imp := model newImport.
	imp name: 'isDocEmpty'.
	imp sourceAnchor: (SmallChatFamixSourceAnchor fileUri: consumerUri startByte: 0 endByte: 0).
	SmallChatTsNav currentWorkspace: ws.
	out := SmallChatTsNav findReferencesOf: 'isDocEmpty'.
	self assert: (out includesSubstring: 'consumer.ts')
]

{ #category : 'tests' }
SmallChatTsNavTest >> testFindSymbolMatchesByName [
	"findSymbol: walks Famix entity types (Class, Interface, Function, Method,
	 Field, TypeAlias, JSXComponent, CSSClass) whose name matches. Returns a
	 Markdown table of name | kind | path:line:character. The CSS path is
	 simplest to fixture without an LSP client; it exercises the same walk +
	 rendering as the TS path."
	| fs root ws out |
	fs := FileSystem memory.
	root := fs / 'project'.
	root ensureCreateDirectory.
	(root / 'a.module.css') writeStreamDo: [ :s | s nextPutAll: '.isDocEmpty { color: red; }' ].
	(root / 'b.module.css') writeStreamDo: [ :s | s nextPutAll: '.unrelated { }' ].
	ws := SmallChatTsWorkspace new
		name: 'fixture';
		path: root;
		yourself.
	SmallChatTsNav currentWorkspace: ws.
	out := SmallChatTsNav findSymbol: 'isDocEmpty'.
	self assert: (out includesSubstring: 'isDocEmpty').
	self assert: (out includesSubstring: 'a.module.css').
	self deny: (out includesSubstring: 'unrelated')
]

{ #category : 'tests' }
SmallChatTsNavTest >> testGrepFindsMatchingLines [
	"grep:in: regex-searches the Famix-known files matching the glob,
	 returning path:line:text rows. Files outside the glob are skipped;
	 lines that don't match are dropped."
	| fs root ws out |
	fs := FileSystem memory.
	root := fs / 'project'.
	root ensureCreateDirectory.
	(root / 'a.module.css') writeStreamDo: [ :s |
		s nextPutAll: '.alpha { }'; lf;
		  nextPutAll: '.beta { }'; lf;
		  nextPutAll: '.gamma { }'; lf ].
	(root / 'b.module.css') writeStreamDo: [ :s |
		s nextPutAll: '.beta { }'; lf ].
	ws := SmallChatTsWorkspace new
		name: 'fixture';
		path: root;
		yourself.
	SmallChatTsNav currentWorkspace: ws.
	out := SmallChatTsNav grep: 'beta' in: '*.module.css'.
	self assert: (out includesSubstring: 'a.module.css').
	self assert: (out includesSubstring: 'b.module.css').
	self deny: (out includesSubstring: 'gamma')
]

{ #category : 'tests' }
SmallChatTsNavTest >> testLspRequestPassesThroughToClient [
	"lspRequest:params: is the escape hatch the agent uses for LSP methods
	 that don't have a dedicated TsNav selector. The response is rendered
	 as printString so the LM can read it; richer rendering can come later."
	| stub ws out |
	stub := SmallChatStubLSPClient new
		cannedResponse: 'workspace/symbol' is: (Array with: (Dictionary new at: 'name' put: 'SymbolFoo'; yourself));
		yourself.
	ws := SmallChatTsWorkspace new
		name: 'fixture';
		lspClient: stub;
		yourself.
	SmallChatTsNav currentWorkspace: ws.
	out := SmallChatTsNav lspRequest: 'workspace/symbol' params: (Dictionary new at: 'query' put: 'Foo'; yourself).
	self assert: (out includesSubstring: 'SymbolFoo')
]

{ #category : 'tests' }
SmallChatTsNavTest >> testReadFileReturnsFencedContent [
	"readFile: resolves a workspace-relative path against the workspace path
	 and returns the content fenced with the matching code-fence language
	 hint so the LM can read syntax-highlighted output."
	| fs root ws out |
	fs := FileSystem memory.
	root := fs / 'project'.
	root ensureCreateDirectory.
	(root / 'a.ts') writeStreamDo: [ :s | s nextPutAll: 'export const x = 1;' ].
	ws := SmallChatTsWorkspace new
		name: 'fixture';
		path: root;
		yourself.
	SmallChatTsNav currentWorkspace: ws.
	out := SmallChatTsNav readFile: 'a.ts'.
	self assert: (out includesSubstring: 'export const x = 1;').
	self assert: (out includesSubstring: '```typescript')
]

{ #category : 'tests' }
SmallChatTsNavTest >> testRenameSymbolAtAppliesLspEdit [
	"renameSymbolAt:line:character:to: builds a SmallChatTsRenameSymbolCommand
	 against the workspace's LSP client + a freshly-constructed applier rooted
	 at the workspace path's FileSystem, runs it, and reports the outcome.
	 SmallChatStubLSPClient (vendored from SmallChat-Refactoring-Tests) returns
	 a canned WorkspaceEdit; success is reflected on disk."
	| fs root file uri stubClient ws workspaceEdit out |
	fs := FileSystem memory.
	root := fs / 'project'.
	root ensureCreateDirectory.
	file := root / 'Button.ts'.
	file writeStreamDo: [ :s | s nextPutAll: 'const oldName = 1;' ].
	uri := 'file://' , file fullName.
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
		cannedResponse: 'textDocument/diagnostic' is: nil;
		yourself.
	ws := SmallChatTsWorkspace new
		name: 'fixture';
		path: root;
		lspClient: stubClient;
		yourself.
	SmallChatTsNav currentWorkspace: ws.
	out := SmallChatTsNav renameSymbolAt: 'Button.ts' line: 0 character: 7 to: 'newName'.
	self assert: (out includesSubstring: 'success').
	self assert: (file readStreamDo: [ :s | s upToEnd ]) equals: 'const newName = 1;'
]

{ #category : 'tests' }
SmallChatTsNavTest >> testWriteFileWritesDiskAndReimportsFamix [
	"writeFile:contents: writes through the file's FileSystem (memory-FS in
	 tests), notifies the workspace LSP client when the doc is open, then
	 invokes workspace reimportUri:text: so the cached Famix model reflects
	 the new content for subsequent findSymbol: queries."
	| fs root ws css after |
	fs := FileSystem memory.
	root := fs / 'project'.
	root ensureCreateDirectory.
	css := root / 'styles.module.css'.
	css writeStreamDo: [ :s | s nextPutAll: '.old { }' ].
	ws := SmallChatTsWorkspace new
		name: 'fixture';
		path: root;
		yourself.
	SmallChatTsNav currentWorkspace: ws.
	ws famixModel.
	SmallChatTsNav writeFile: 'styles.module.css' contents: '.new { }'.
	after := ((ws famixModel allWithType: SmallChatFamixCSSClass) collect: [ :c | c name ]) asArray.
	self assert: after equals: #( 'new' ).
	self assert: (css readStreamDo: [ :s | s upToEnd ]) equals: '.new { }'
]

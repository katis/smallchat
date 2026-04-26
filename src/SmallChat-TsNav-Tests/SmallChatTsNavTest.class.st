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

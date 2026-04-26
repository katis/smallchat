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

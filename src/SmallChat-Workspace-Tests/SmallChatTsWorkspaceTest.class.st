Class {
	#name : 'SmallChatTsWorkspaceTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Workspace-Tests',
	#package : 'SmallChat-Workspace-Tests'
}

{ #category : 'tests' }
SmallChatTsWorkspaceTest >> testAttachRejectsRelativePath [
	"Relative paths are unsafe -- the agent's cwd is unreliable. Refuse with
	 an actionable error rather than guessing."
	self
		should: [ SmallChatTsWorkspace attachAt: 'some/relative/path' name: nil ]
		raise: Error
		withExceptionDo: [ :e |
			self assert: (e messageText includesSubstring: 'absolute') ]
]

{ #category : 'tests' }
SmallChatTsWorkspaceTest >> testAttachUsesLauncherBlockToBuildLspClient [
	"With a stub launcher installed, attach should produce a workspace whose
	 lspClient came back from the launcher block. The launcher receives the
	 canonical FileReference so the stub can verify."
	| launchedWith stubClient ws |
	[ launchedWith := nil.
	  stubClient := SmallChatLSPClient new transport: SmallChatLSPStubTransport new.
	  SmallChatTsWorkspace launcherBlock: [ :p | launchedWith := p. stubClient ].
	  ws := SmallChatTsWorkspace attachAt: '/tmp/smallchat-stub-ts' name: nil.
	  self assert: ws kind equals: #ts.
	  self assert: ws name equals: 'smallchat-stub-ts'.
	  self assert: ws lspClient == stubClient.
	  self assert: launchedWith fullName equals: '/tmp/smallchat-stub-ts'.
	  self assert: ws path = launchedWith ]
		ensure: [ SmallChatTsWorkspace resetLauncherBlock ]
]

{ #category : 'tests' }
SmallChatTsWorkspaceTest >> testDefaultSystemPromptMentionsTsNav [
	"The TS workspace owns its own system prompt; the LM session reads it
	 via the workspace, so it must teach the agent about the canonical
	 entry SmallChatTsNav, name the dead-end APIs to avoid (FileDirectory),
	 and surface the rename / discovery selectors the rename loop relies on."
	| prompt |
	prompt := SmallChatTsWorkspace defaultSystemPrompt.
	self assert: (prompt includesSubstring: 'TypeScript').
	self assert: (prompt includesSubstring: 'SmallChatTsNav').
	self assert: (prompt includesSubstring: 'evaluate').
	self assert: (prompt includesSubstring: 'findSymbol:').
	self assert: (prompt includesSubstring: 'renameSymbolInFile:').
	self assert: (prompt includesSubstring: 'FileDirectory')
]

{ #category : 'tests' }
SmallChatTsWorkspaceTest >> testFamixModelLazyBuildIsIdempotent [
	"famixModel is the lazy bridge SmallChatTsNav reads from. First call walks
	 the workspace path via SmallChatFamixImporter importAllUnder: and returns
	 the populated model; subsequent calls reuse the same instance so query
	 round-trips stay in-memory."
	| fs root ws m1 m2 |
	fs := FileSystem memory.
	root := fs / 'project'.
	root ensureCreateDirectory.
	(root / 'styles.module.css') writeStreamDo: [ :s | s nextPutAll: '.x { color: red; }' ].
	ws := SmallChatTsWorkspace new
		name: 'fixture';
		path: root;
		yourself.
	m1 := ws famixModel.
	self assert: m1 notNil.
	self assert: (m1 allWithType: SmallChatFamixCSSClass) size equals: 1.
	m2 := ws famixModel.
	self assert: m1 == m2
]

{ #category : 'tests' }
SmallChatTsWorkspaceTest >> testReimportUriRefreshesEntitiesAfterEdit [
	"reimportUri:text: drops + reimports one URI in the cached Famix model so
	 a TsNav writeFile: / rename / code-action-apply leaves the model in
	 sync with the new file content. Caller supplies text (already on hand)
	 to avoid a re-read."
	| fs root ws css uri before after |
	fs := FileSystem memory.
	root := fs / 'project'.
	root ensureCreateDirectory.
	css := root / 'styles.module.css'.
	css writeStreamDo: [ :s | s nextPutAll: '.old { }' ].
	ws := SmallChatTsWorkspace new
		name: 'fixture';
		path: root;
		yourself.
	ws famixModel.
	before := ((ws famixModel allWithType: SmallChatFamixCSSClass) collect: [ :c | c name ]) asArray.
	self assert: before equals: #('old').
	uri := 'file://' , css fullName.
	ws reimportUri: uri text: '.new { }'.
	after := ((ws famixModel allWithType: SmallChatFamixCSSClass) collect: [ :c | c name ]) asArray.
	self assert: after equals: #('new')
]

{ #category : 'tests' }
SmallChatTsWorkspaceTest >> testShutdownClearsFamixState [
	"shutdown drops the cached Famix model + importer alongside the LSP
	 client so re-attaching the same path gets a fresh model rather than
	 stale entities. Tests that exercise re-attach rely on this."
	| fs root ws m1 |
	fs := FileSystem memory.
	root := fs / 'project'.
	root ensureCreateDirectory.
	(root / 'styles.module.css') writeStreamDo: [ :s | s nextPutAll: '.x { }' ].
	ws := SmallChatTsWorkspace new
		name: 'fixture';
		path: root;
		yourself.
	m1 := ws famixModel.
	self assert: m1 notNil.
	ws shutdown.
	self assert: ws famixModel ~~ m1
]

{ #category : 'tests' }
SmallChatTsWorkspaceTest >> testShutdownTearsDownLspClient [
	"shutdown should propagate to the workspace's LSP client (and through it
	 to the transport). Verify via the stub transport's shutdownCalled flag."
	| stub stubClient ws |
	[ stub := SmallChatLSPStubTransport new.
	  stubClient := SmallChatLSPClient new transport: stub.
	  SmallChatTsWorkspace launcherBlock: [ :p | stubClient ].
	  ws := SmallChatTsWorkspace attachAt: '/tmp/smallchat-stub-ts-shutdown' name: nil.
	  self deny: stub shutdownCalled.
	  ws shutdown.
	  self assert: stub shutdownCalled ]
		ensure: [ SmallChatTsWorkspace resetLauncherBlock ]
]

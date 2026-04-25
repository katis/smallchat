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

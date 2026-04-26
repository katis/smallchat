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
SmallChatTsNavTest >> testFindFilesWithoutWorkspaceReturnsGuard [
	"All discovery selectors must short-circuit with a friendly Markdown
	 guard when no TS workspace is bound -- otherwise an evaluate against
	 a Pharo-only session would NPE. Pin findFiles: as the canary."
	| out |
	SmallChatTsNav currentWorkspace: nil.
	out := SmallChatTsNav findFiles: '*.ts'.
	self assert: (out includesSubstring: 'no TS workspace bound')
]

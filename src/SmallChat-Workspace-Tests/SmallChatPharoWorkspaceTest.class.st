Class {
	#name : 'SmallChatPharoWorkspaceTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Workspace-Tests',
	#package : 'SmallChat-Workspace-Tests'
}

{ #category : 'tests' }
SmallChatPharoWorkspaceTest >> testDefaultIsSingleton [
	self assert: SmallChatPharoWorkspace default == SmallChatPharoWorkspace default.
	self assert: SmallChatPharoWorkspace default name equals: 'pharo'
]

{ #category : 'tests' }
SmallChatPharoWorkspaceTest >> testDefaultSystemPromptMentionsPharoExpert [
	"The Pharo workspace owns its own system prompt; the LM session reads
	 it via the workspace, so it must mention Pharo and the canonical nav
	 entry SmallChatNav."
	| prompt |
	prompt := SmallChatPharoWorkspace defaultSystemPrompt.
	self assert: (prompt includesSubstring: 'Pharo').
	self assert: (prompt includesSubstring: 'SmallChatNav')
]

{ #category : 'tests' }
SmallChatPharoWorkspaceTest >> testKindIsPharo [
	self assert: SmallChatPharoWorkspace kind equals: #pharo
]

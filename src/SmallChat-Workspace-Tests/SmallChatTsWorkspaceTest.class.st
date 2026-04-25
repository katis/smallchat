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

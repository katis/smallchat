"
Unit tests for SmallChatWorkspaceWindow.
"
Class {
	#name : 'SmallChatWorkspaceWindowTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testInitializePresentersBuildsLabels [
	| ws window |
	ws := SmallChatTsWorkspace attachAt: '/tmp/smallchat-ws-fixture' name: 'fixture-ws'.
	window := SmallChatWorkspaceWindow new
		workspace: ws;
		yourself.
	self assert: (window headerLabel label includesSubstring: 'fixture-ws').
	self assert: (window pathLabel label includesSubstring: '/tmp/smallchat-ws-fixture').
	self assert: window chatPlaceholder notNil.
	self assert: (window chatPlaceholder isKindOf: SpPresenter).
	self assert: window statusLabel notNil.
	self assert: window detachButton notNil
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testWorkspaceAccessorRoundTrip [
	| ws window |
	ws := SmallChatTsWorkspace attachAt: '/tmp/smallchat-ws-fixture' name: 'fixture-ws'.
	window := SmallChatWorkspaceWindow new.
	window workspace: ws.
	self assert: window workspace == ws
]

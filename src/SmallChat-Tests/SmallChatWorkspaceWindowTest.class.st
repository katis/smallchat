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
SmallChatWorkspaceWindowTest >> testDefaultLayoutContainsAllPresenters [
	| ws window children |
	ws := SmallChatTsWorkspace attachAt: '/tmp/smallchat-ws-fixture' name: 'fixture-ws'.
	window := SmallChatWorkspaceWindow new workspace: ws; yourself.
	children := window defaultLayout children.
	self assert: (children includes: window headerLabel).
	self assert: (children includes: window pathLabel).
	self assert: (children includes: window statusLabel).
	self assert: (children includes: window detachButton).
	self assert: (children includes: window chatPlaceholder)
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testDetachAndCloseUnmountsAndShutsDownIdempotent [
	| registry ws window |
	registry := SmallChatCapabilityRegistry new.
	ws := SmallChatTsWorkspace attachAt: '/tmp/smallchat-ws-detach' name: 'detach-ws'.
	ws lspClient: 'sentinel'.
	registry mountWorkspace: ws.
	window := SmallChatWorkspaceWindow new
		registryProvider: [ registry ];
		workspace: ws;
		yourself.
	window detachAndClose.
	self assert: (registry mountedWorkspaces includes: ws) not.
	self assert: ws lspClient isNil.
	"Second call must not raise."
	[ window detachAndClose ] on: Error do: [ :e | self fail: 'detachAndClose should be idempotent: ' , e messageText ]
]

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

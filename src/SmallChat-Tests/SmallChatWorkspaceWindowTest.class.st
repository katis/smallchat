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
SmallChatWorkspaceWindowTest >> testWorkspaceAccessorRoundTrip [
	| window stub |
	stub := Object new.
	window := SmallChatWorkspaceWindow new.
	window workspace: stub.
	self assert: window workspace == stub
]

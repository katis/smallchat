Class {
	#name : 'SmallChatDebuggerWatchTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatDebuggerWatchTest >> testHeadlessWorldReturnsEmpty [
	"Nil world (headless, SMALLCHAT_NO_GUI=1) must yield no descriptors."
	self assert: (SmallChatDebuggerWatch openWindowsIn: nil) equals: #()
]

{ #category : 'tests' }
SmallChatDebuggerWatchTest >> testMatchesDebuggerWindows [
	"Fake SystemWindow with a real StDebugger model (bare basicNew, no UI) produces one descriptor."
	| fakeWindow result |
	fakeWindow := SystemWindow new
		model: StDebugger basicNew;
		yourself.
	result := SmallChatDebuggerWatch openWindowsFromMorphs: { fakeWindow }.
	self assert: result size equals: 1
]

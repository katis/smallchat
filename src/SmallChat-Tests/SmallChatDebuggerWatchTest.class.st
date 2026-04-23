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
SmallChatDebuggerWatchTest >> testIgnoresNonDebuggerWindows [
	"A SystemWindow whose model class name does not contain Debugger must be ignored."
	| plainWindow |
	plainWindow := SystemWindow new
		model: OrderedCollection new;
		yourself.
	self assert: (SmallChatDebuggerWatch openWindowsFromMorphs: { plainWindow }) equals: #()
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

{ #category : 'tests' }
SmallChatDebuggerWatchTest >> testTolerantOfErrors [
	"A morph-like object that raises on #model must be skipped rather than crash."
	| bare |
	bare := Object new.
	self assert: (SmallChatDebuggerWatch openWindowsFromMorphs: { bare }) equals: #()
]

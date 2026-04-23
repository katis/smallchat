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

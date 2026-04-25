Class {
	#name : 'SmallChatDebugReturnToolTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'running' }
SmallChatDebugReturnToolTest >> tearDown [
    SmallChatDebugSessionRegistry reset.
    super tearDown
]

{ #category : 'tests' }
SmallChatDebugReturnToolTest >> testReturnResumesAndCompletes [
	| result sid returnResult session |
	SmallChatDebugSessionRegistry reset.
	result := SmallChatMCPCapabilityTransport default
		dispatch: 'eval.smalltalk'
		with: (Dictionary new at: 'code' put: '1/0'; yourself).
	sid := (result at: 'debugSession') at: 'id'.
	session := SmallChatDebugSessionRegistry default at: sid.
	returnResult := SmallChatMCPCapabilityTransport default
		dispatch: 'debug.return'
		with: (Dictionary new
			at: 'sessionId' put: sid;
			at: 'expression' put: '42';
			yourself).
	self assert: ((returnResult at: 'content') first at: 'text') equals: '42'.
	self should: [ SmallChatDebugSessionRegistry default at: sid ] raise: Error.
	self assert: session process isTerminated
]

Class {
	#name : 'SmallChatDebugTerminateToolTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'running' }
SmallChatDebugTerminateToolTest >> tearDown [
    SmallChatDebugSessionRegistry reset.
    super tearDown
]

{ #category : 'tests' }
SmallChatDebugTerminateToolTest >> testTerminateKillsProcess [
    | evaluateResult sid session |
    SmallChatDebugSessionRegistry reset.
    evaluateResult := SmallChatMCPCapabilityTransport default dispatch: 'eval.smalltalk' with: (Dictionary new at: 'code' put: '1/0'; yourself).
    sid := (evaluateResult at: 'debugSession') at: 'id'.
    session := SmallChatDebugSessionRegistry default at: sid.
    SmallChatMCPCapabilityTransport default dispatch: 'debug.terminate' with: (Dictionary new at: 'sessionId' put: sid; yourself).
    self assert: session process isTerminated.
    self should: [ SmallChatDebugSessionRegistry default at: sid ] raise: Error
]

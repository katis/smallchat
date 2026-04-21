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
    evaluateResult := SmallChatToolRegistry default run: 'evaluate' with: (Dictionary new at: 'code' put: '1/0'; yourself).
    sid := (evaluateResult at: 'debugSession') at: 'id'.
    session := SmallChatDebugSessionRegistry default at: sid.
    SmallChatToolRegistry default run: 'debug_terminate' with: (Dictionary new at: 'sessionId' put: sid; yourself).
    self assert: session process isTerminated.
    self should: [ SmallChatDebugSessionRegistry default at: sid ] raise: Error
]

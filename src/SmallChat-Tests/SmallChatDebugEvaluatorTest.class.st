Class {
	#name : 'SmallChatDebugEvaluatorTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'running' }
SmallChatDebugEvaluatorTest >> tearDown [
    SmallChatDebugSessionRegistry reset.
    super tearDown
]

{ #category : 'tests' }
SmallChatDebugEvaluatorTest >> testErrorPathRegistersSession [
    | outcome session |
    SmallChatDebugSessionRegistry reset.
    outcome := SmallChatDebugEvaluator evaluate: '1/0'.
    self assert: outcome key equals: #debugSession.
    session := outcome value.
    self assert: (session isKindOf: SmallChatDebugSession).
    self assert: (session exception isKindOf: ZeroDivide).
    self assert: (SmallChatDebugSessionRegistry default at: session id) == session
]

{ #category : 'tests' }
SmallChatDebugEvaluatorTest >> testProcessParksNotDies [
    | outcome session |
    SmallChatDebugSessionRegistry reset.
    outcome := SmallChatDebugEvaluator evaluate: '1/0'.
    session := outcome value.
    self assert: session process isSuspended.
    self deny: session process isTerminated
]

{ #category : 'tests' }
SmallChatDebugEvaluatorTest >> testSuccessPathReturnsResult [
    | outcome |
    outcome := SmallChatDebugEvaluator evaluate: '3 + 4'.
    self assert: outcome key equals: #result.
    self assert: outcome value equals: '7'
]

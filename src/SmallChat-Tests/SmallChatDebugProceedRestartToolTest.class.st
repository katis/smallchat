Class {
	#name : 'SmallChatDebugProceedRestartToolTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'running' }
SmallChatDebugProceedRestartToolTest >> tearDown [
    SmallChatDebugSessionRegistry reset.
    Smalltalk globals removeKey: #TestRestartFlag ifAbsent: [].
    super tearDown
]

{ #category : 'tests' }
SmallChatDebugProceedRestartToolTest >> testProceedReturnsNilAsFinalResult [
    | evaluateResult sid proceedResult |
    SmallChatDebugSessionRegistry reset.
    evaluateResult := SmallChatToolRegistry default run: 'evaluate' with: (Dictionary new at: 'code' put: '1/0. 99'; yourself).
    sid := (evaluateResult at: 'debugSession') at: 'id'.
    proceedResult := SmallChatToolRegistry default run: 'debug_proceed' with: (Dictionary new at: 'sessionId' put: sid; yourself).
    "After proceed, 1/0 -> nil. Then `. 99` runs and yields 99."
    self assert: ((proceedResult at: 'content') first at: 'text') equals: '99'.
    self should: [ SmallChatDebugSessionRegistry default at: sid ] raise: Error
]

{ #category : 'tests' }
SmallChatDebugProceedRestartToolTest >> testRestartRetriesFrameAfterFix [
    | evalResult sid restartResult |
    SmallChatDebugSessionRegistry reset.
    Smalltalk globals at: #TestRestartFlag put: false.
    evalResult := SmallChatToolRegistry default run: 'evaluate' with: (Dictionary new
        at: 'code' put: '(Smalltalk globals at: #TestRestartFlag) ifTrue: [ 42 ] ifFalse: [ 1/0 ]';
        yourself).
    sid := (evalResult at: 'debugSession') at: 'id'.
    Smalltalk globals at: #TestRestartFlag put: true.
    restartResult := SmallChatToolRegistry default run: 'debug_restart' with: (Dictionary new
        at: 'sessionId' put: sid;
        at: 'index' put: 1;
        yourself).
    self assert: ((restartResult at: 'content') first at: 'text') equals: '42'.
    self should: [ SmallChatDebugSessionRegistry default at: sid ] raise: Error
]

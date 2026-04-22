Class {
	#name : 'SmallChatDebugStepToolsTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'running' }
SmallChatDebugStepToolsTest >> tearDown [
    SmallChatDebugSessionRegistry reset.
    super tearDown
]

{ #category : 'tests' }
SmallChatDebugStepToolsTest >> testSessionSteppedDefaultsToFalseAndRoundTrips [
    | s |
    s := SmallChatDebugSession new.
    self deny: s stepped.
    s stepped: true.
    self assert: s stepped.
    s stepped: false.
    self deny: s stepped
]

{ #category : 'tests' }
SmallChatDebugStepToolsTest >> testStepOverAdvancesIctxPastSignalAndMarksStepped [
    | evalResult sid session preIctx postIctx |
    SmallChatDebugSessionRegistry reset.
    evalResult := SmallChatToolRegistry default run: 'evaluate' with: (Dictionary new at: 'code' put: '1/0. 42'; yourself).
    sid := (evalResult at: 'debugSession') at: 'id'.
    session := SmallChatDebugSessionRegistry default at: sid.
    preIctx := session debugSession interruptedContext.
    self assert: preIctx receiver class equals: SmallInteger.
    self deny: session stepped.
    SmallChatToolRegistry default run: 'debug_step_over' with: (Dictionary new at: 'sessionId' put: sid; yourself).
    session := SmallChatDebugSessionRegistry default at: sid.
    self assert: session stepped.
    postIctx := session debugSession interruptedContext.
    self deny: postIctx == preIctx.
    self deny: (postIctx receiver class == SmallInteger and: [ postIctx selector == #/ ])
]

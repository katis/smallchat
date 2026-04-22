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
SmallChatDebugStepToolsTest >> testProceedOnSteppedSessionRecapturesNextRaise [
    | evalResult sid proceedResult payload newSid |
    SmallChatDebugSessionRegistry reset.
    evalResult := SmallChatToolRegistry default run: 'evaluate' with: (Dictionary new at: 'code' put: '1/0. 2/0. 42'; yourself).
    sid := (evalResult at: 'debugSession') at: 'id'.
    SmallChatToolRegistry default run: 'debug_step_over' with: (Dictionary new at: 'sessionId' put: sid; yourself).
    proceedResult := SmallChatToolRegistry default run: 'debug_proceed' with: (Dictionary new at: 'sessionId' put: sid; yourself).
    payload := proceedResult at: 'debugSession' ifAbsent: [ nil ].
    self assert: payload notNil description: 'debug_proceed after a step must recapture on the next raise'.
    self assert: (payload at: 'exceptionClass') equals: 'ZeroDivide'.
    newSid := payload at: 'id'.
    self deny: newSid = sid description: 'recaptured session should have a fresh id'
]

{ #category : 'tests' }
SmallChatDebugStepToolsTest >> testReturnRejectsSteppedSession [
    | evalResult sid returnResult content text |
    SmallChatDebugSessionRegistry reset.
    evalResult := SmallChatToolRegistry default run: 'evaluate' with: (Dictionary new at: 'code' put: '1/0. 42'; yourself).
    sid := (evalResult at: 'debugSession') at: 'id'.
    SmallChatToolRegistry default run: 'debug_step_over' with: (Dictionary new at: 'sessionId' put: sid; yourself).
    returnResult := SmallChatToolRegistry default run: 'debug_return' with: (Dictionary new
        at: 'sessionId' put: sid;
        at: 'expression' put: '99';
        yourself).
    self assert: (returnResult at: 'isError' ifAbsent: [ false ]) description: 'debug_return on a stepped session must report an error'.
    content := returnResult at: 'content'.
    text := content first at: 'text'.
    self assert: (text asLowercase includesSubstring: 'stepped') description: 'error message must mention stepped'.
    self assert: (text includesSubstring: 'debug_proceed') description: 'error message should suggest debug_proceed'
]

{ #category : 'tests' }
SmallChatDebugStepToolsTest >> testSecondStepOverSkipsRepopAndAdvancesFurther [
    | evalResult sid session afterFirstIctx afterSecondIctx |
    SmallChatDebugSessionRegistry reset.
    evalResult := SmallChatToolRegistry default run: 'evaluate' with: (Dictionary new at: 'code' put: '1/0. 2/0. 99'; yourself).
    sid := (evalResult at: 'debugSession') at: 'id'.
    SmallChatToolRegistry default run: 'debug_step_over' with: (Dictionary new at: 'sessionId' put: sid; yourself).
    session := SmallChatDebugSessionRegistry default at: sid.
    self assert: session stepped.
    afterFirstIctx := session debugSession interruptedContext.
    SmallChatToolRegistry default run: 'debug_step_over' with: (Dictionary new at: 'sessionId' put: sid; yourself).
    session := SmallChatDebugSessionRegistry default at: sid.
    self assert: session stepped.
    afterSecondIctx := session debugSession interruptedContext.
    self deny: afterSecondIctx == afterFirstIctx description: 'second step must advance ictx beyond first step'.
    self assert: session process isSuspended description: 'process remains parked between steps'
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
SmallChatDebugStepToolsTest >> testStepIntoEntersNextMethodCall [
    | evalResult sid session ictx |
    SmallChatDebugSessionRegistry reset.
    evalResult := SmallChatToolRegistry default run: 'evaluate' with: (Dictionary new at: 'code' put: '1/0. 5 factorial. 42'; yourself).
    sid := (evalResult at: 'debugSession') at: 'id'.
    "Two step_intos: first reaches the next send-site, second enters the method."
    SmallChatToolRegistry default run: 'debug_step_into' with: (Dictionary new at: 'sessionId' put: sid; yourself).
    SmallChatToolRegistry default run: 'debug_step_into' with: (Dictionary new at: 'sessionId' put: sid; yourself).
    session := SmallChatDebugSessionRegistry default at: sid.
    self assert: session stepped.
    ictx := session debugSession interruptedContext.
    self assert: ictx receiver equals: 5.
    self assert: ictx selector equals: #factorial
]

{ #category : 'tests' }
SmallChatDebugStepToolsTest >> testStepIntoOnUnknownSessionRaisesError [
    | result |
    SmallChatDebugSessionRegistry reset.
    result := SmallChatToolRegistry default run: 'debug_step_into' with: (Dictionary new at: 'sessionId' put: 'ds-nope'; yourself).
    self assert: (result at: 'isError' ifAbsent: [ false ]) description: 'unknown sessionId must yield an MCP error result'
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

{ #category : 'tests' }
SmallChatDebugStepToolsTest >> testStepOverOnUnknownSessionRaisesError [
    | result |
    SmallChatDebugSessionRegistry reset.
    result := SmallChatToolRegistry default run: 'debug_step_over' with: (Dictionary new at: 'sessionId' put: 'ds-nope'; yourself).
    self assert: (result at: 'isError' ifAbsent: [ false ]) description: 'unknown sessionId must yield an MCP error result'
]

{ #category : 'tests' }
SmallChatDebugStepToolsTest >> testStepOverResponseIsDebugSessionPayloadWithSameId [
    | evalResult sid stepResult stepSessionPayload |
    SmallChatDebugSessionRegistry reset.
    evalResult := SmallChatToolRegistry default run: 'evaluate' with: (Dictionary new at: 'code' put: '1/0. 42'; yourself).
    sid := (evalResult at: 'debugSession') at: 'id'.
    stepResult := SmallChatToolRegistry default run: 'debug_step_over' with: (Dictionary new at: 'sessionId' put: sid; yourself).
    stepSessionPayload := stepResult at: 'debugSession' ifAbsent: [ nil ].
    self assert: stepSessionPayload notNil description: 'response must carry a debugSession payload'.
    self assert: (stepSessionPayload at: 'id') equals: sid
]

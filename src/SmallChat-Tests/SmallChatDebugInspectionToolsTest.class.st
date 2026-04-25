Class {
	#name : 'SmallChatDebugInspectionToolsTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'helpers' }
SmallChatDebugInspectionToolsTest >> captureZeroDivide [
    | result |
    SmallChatDebugSessionRegistry reset.
    result := SmallChatMCPCapabilityTransport default dispatch: 'evaluate' with: (Dictionary new at: 'code' put: '1/0'; yourself).
    ^ (result at: 'debugSession') at: 'id'
]

{ #category : 'running' }
SmallChatDebugInspectionToolsTest >> tearDown [
    SmallChatDebugSessionRegistry reset.
    super tearDown
]

{ #category : 'tests' }
SmallChatDebugInspectionToolsTest >> testDebugEvaluateInFrameReturnsValue [
    | sid evalResult |
    sid := self captureZeroDivide.
    evalResult := SmallChatMCPCapabilityTransport default dispatch: 'debug_evaluate' with: (Dictionary new
        at: 'sessionId' put: sid;
        at: 'index' put: 0;
        at: 'expression' put: 'self + 5';
        yourself).
    self assert: ((evalResult at: 'content') first at: 'text') equals: '6'
]

{ #category : 'tests' }
SmallChatDebugInspectionToolsTest >> testDebugFrameReturnsFrameDetails [
    | sid frameResult dict |
    sid := self captureZeroDivide.
    frameResult := SmallChatMCPCapabilityTransport default dispatch: 'debug_frame' with: (Dictionary new
        at: 'sessionId' put: sid;
        at: 'index' put: 0;
        yourself).
    dict := STONJSON fromString: ((frameResult at: 'content') first at: 'text').
    self assert: (dict at: 'selector') equals: '/'.
    self assert: (dict at: 'receiver') equals: '1'
]

{ #category : 'tests' }
SmallChatDebugInspectionToolsTest >> testDebugSessionsListsActiveSessions [
	| sid listResult list |
	sid := self captureZeroDivide.
	listResult := SmallChatMCPCapabilityTransport default dispatch: 'debug.sessions' with: (Dictionary new).
	list := (STONJSON fromString: ((listResult at: 'content') first at: 'text')) at: 'sessions'.
	self assert: list size equals: 1.
	self assert: (list first at: 'id') equals: sid.
	self assert: (list first at: 'exceptionClass') equals: 'ZeroDivide'
]

{ #category : 'tests' }
SmallChatDebugInspectionToolsTest >> testDebugStackReturnsTopFrames [
    | sid stackResult frames |
    sid := self captureZeroDivide.
    stackResult := SmallChatMCPCapabilityTransport default dispatch: 'debug_stack' with: (Dictionary new at: 'sessionId' put: sid; yourself).
    frames := (STONJSON fromString: ((stackResult at: 'content') first at: 'text')) at: 'frames'.
    self assert: frames notEmpty.
    self assert: (frames first at: 'selector') equals: '/'
]

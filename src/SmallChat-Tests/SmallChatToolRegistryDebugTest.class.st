Class {
	#name : 'SmallChatToolRegistryDebugTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'running' }
SmallChatToolRegistryDebugTest >> tearDown [
    SmallChatDebugSessionRegistry reset.
    super tearDown
]

{ #category : 'tests' }
SmallChatToolRegistryDebugTest >> testEvaluateToolReturnsDebugShape [
    | result session |
    SmallChatDebugSessionRegistry reset.
    result := SmallChatToolRegistry default
        run: 'evaluate'
        with: (Dictionary new at: 'code' put: '1/0'; yourself).
    self assert: (result at: 'isError') equals: true.
    session := result at: 'debugSession'.
    self assert: (session at: 'id') isString.
    self assert: ((session at: 'id') beginsWith: 'ds-').
    self assert: (session at: 'exceptionClass') equals: 'ZeroDivide'.
    self assert: (SmallChatDebugSessionRegistry default at: (session at: 'id')) notNil
]

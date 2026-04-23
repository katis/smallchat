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

{ #category : 'tests' }
SmallChatToolRegistryDebugTest >> testNoWarningWhenNoStrayDebuggers [
	"When the debuggerWatch seam reports no stray debuggers, the reply text is untouched."
	| registry result text |
	registry := SmallChatToolRegistry new.
	registry debuggerWatch: [ #() ].
	result := registry
		run: 'evaluate'
		with: (Dictionary new at: 'code' put: '''hello''' ; yourself).
	text := ((result at: 'content') first) at: 'text'.
	self deny: (text beginsWith: '[smallchat:').
	self assert: text equals: '''hello'''
]

{ #category : 'tests' }
SmallChatToolRegistryDebugTest >> testPrependsWarningWhenStrayDebuggerPresent [
	"With the debuggerWatch seam returning a non-empty descriptor list, every tool reply
	 gets the [smallchat: ...] warning prefix."
	| registry result text |
	registry := SmallChatToolRegistry new.
	registry debuggerWatch: [ { Dictionary new at: 'modelClass' put: 'StDebugger'; yourself } ].
	result := registry
		run: 'evaluate'
		with: (Dictionary new at: 'code' put: 'nil'; yourself).
	text := ((result at: 'content') first) at: 'text'.
	self assert: (text beginsWith: '[smallchat:')
]

{ #category : 'tests' }
SmallChatToolRegistryDebugTest >> testWarningAttachedToDebugSessionReply [
	"A tool returning SmallChatToolResult debugSession: still picks up the warning prefix
	 on its content text item."
	| registry result text session |
	SmallChatDebugSessionRegistry reset.
	registry := SmallChatToolRegistry new.
	registry debuggerWatch: [ { Dictionary new at: 'modelClass' put: 'StDebugger'; yourself } ].
	result := registry
		run: 'evaluate'
		with: (Dictionary new at: 'code' put: '1/0'; yourself).
	self assert: (result at: 'isError') equals: true.
	session := result at: 'debugSession'.
	self assert: (session at: 'exceptionClass') equals: 'ZeroDivide'.
	text := ((result at: 'content') first) at: 'text'.
	self assert: (text beginsWith: '[smallchat:')
]

{ #category : 'tests' }
SmallChatToolRegistryDebugTest >> testWarningAttachedToErrorReply [
	"Even when the tool lookup fails (error reply), stray-debugger warning still lands."
	| registry result text |
	registry := SmallChatToolRegistry new.
	registry debuggerWatch: [ { Dictionary new at: 'modelClass' put: 'StDebugger'; yourself } ].
	result := registry run: 'nonexistent-tool-xyz' with: Dictionary new.
	self assert: (result at: 'isError') equals: true.
	text := ((result at: 'content') first) at: 'text'.
	self assert: (text beginsWith: '[smallchat:')
]

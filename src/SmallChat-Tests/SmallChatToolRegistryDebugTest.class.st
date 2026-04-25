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
	"eval.smalltalk capability under the MCP transport produces the
	 debugSession-shaped reply with id + exception class metadata."
	| result session |
	SmallChatDebugSessionRegistry reset.
	result := SmallChatMCPCapabilityTransport default
		dispatch: 'evaluate'
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
	| transport result text |
	transport := SmallChatMCPCapabilityTransport new.
	transport debuggerWatch: [ #() ].
	result := transport
		dispatch: 'evaluate'
		with: (Dictionary new at: 'code' put: '''hello''' ; yourself).
	text := ((result at: 'content') first) at: 'text'.
	self deny: (text beginsWith: '[smallchat:').
	self assert: text equals: '''hello'''
]

{ #category : 'tests' }
SmallChatToolRegistryDebugTest >> testPrependsWarningWhenStrayDebuggerPresent [
	"With the debuggerWatch seam returning a non-empty descriptor list, every reply
	 gets the [smallchat: ...] warning prefix."
	| transport result text |
	transport := SmallChatMCPCapabilityTransport new.
	transport debuggerWatch: [ { Dictionary new at: 'modelClass' put: 'StDebugger'; yourself } ].
	result := transport
		dispatch: 'evaluate'
		with: (Dictionary new at: 'code' put: 'nil'; yourself).
	text := ((result at: 'content') first) at: 'text'.
	self assert: (text beginsWith: '[smallchat:')
]

{ #category : 'tests' }
SmallChatToolRegistryDebugTest >> testWarningAttachedToDebugSessionReply [
	"A debugSession-shaped reply still picks up the warning prefix on its content text item."
	| transport result text session |
	SmallChatDebugSessionRegistry reset.
	transport := SmallChatMCPCapabilityTransport new.
	transport debuggerWatch: [ { Dictionary new at: 'modelClass' put: 'StDebugger'; yourself } ].
	result := transport
		dispatch: 'evaluate'
		with: (Dictionary new at: 'code' put: '1/0'; yourself).
	self assert: (result at: 'isError') equals: true.
	session := result at: 'debugSession'.
	self assert: (session at: 'exceptionClass') equals: 'ZeroDivide'.
	text := ((result at: 'content') first) at: 'text'.
	self assert: (text beginsWith: '[smallchat:')
]

{ #category : 'tests' }
SmallChatToolRegistryDebugTest >> testWarningAttachedToErrorReply [
	"Even when the dispatch fails (error reply), stray-debugger warning still lands."
	| transport result text |
	transport := SmallChatMCPCapabilityTransport new.
	transport debuggerWatch: [ { Dictionary new at: 'modelClass' put: 'StDebugger'; yourself } ].
	result := transport dispatch: 'nonexistent-tool-xyz' with: Dictionary new.
	self assert: (result at: 'isError') equals: true.
	text := ((result at: 'content') first) at: 'text'.
	self assert: (text beginsWith: '[smallchat:')
]

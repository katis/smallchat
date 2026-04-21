"
MCP tool: resume a captured debugger session without substituting a
value. Equivalent to `debug_return nil` -- the signalling expression
evaluates to nil and execution continues.
"
Class {
	#name : 'SmallChatDebugProceedTool',
	#superclass : 'SmallChatTool',
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing - metadata' }
SmallChatDebugProceedTool class >> description [
	^ 'Resume a captured debugger session without substituting a value. Equivalent to debug_return nil -- the signalling expression evaluates to nil, execution continues.'
]

{ #category : 'accessing - metadata' }
SmallChatDebugProceedTool class >> inputSchema [
	^ Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: (Dictionary new
			at: 'sessionId' put: (Dictionary new at: 'type' put: 'string'; yourself);
			yourself);
		at: 'required' put: #('sessionId');
		yourself
]

{ #category : 'accessing - metadata' }
SmallChatDebugProceedTool class >> toolName [
	^ 'debug_proceed'
]

{ #category : 'execution' }
SmallChatDebugProceedTool >> run: args [
	| sid session outcome |
	sid := args at: 'sessionId'.
	session := SmallChatDebugSessionRegistry default at: sid.
	outcome := SmallChatDebugEvaluator resume: session with: nil.
	outcome key = #result ifTrue: [ ^ outcome value ].
	outcome key = #debugSession ifTrue: [ ^ SmallChatToolResult debugSession: outcome value ].
	^ self error: 'Unexpected proceed outcome: ' , outcome printString
]

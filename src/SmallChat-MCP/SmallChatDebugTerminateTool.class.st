"
MCP tool: drop a captured debugger session and terminate its parked
Process. Use when the captured state isn't worth investigating further
or when cleanup is needed.
"
Class {
	#name : 'SmallChatDebugTerminateTool',
	#superclass : 'SmallChatTool',
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing - metadata' }
SmallChatDebugTerminateTool class >> description [
	^ 'Drop a captured debugger session and terminate its parked process. Use when the captured state isn''t worth investigating further or when cleanup is needed.'
]

{ #category : 'accessing - metadata' }
SmallChatDebugTerminateTool class >> inputSchema [
	^ Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: (Dictionary new
			at: 'sessionId' put: (Dictionary new
				at: 'type' put: 'string';
				at: 'description' put: 'Debug session id to terminate.';
				yourself);
			yourself);
		at: 'required' put: #('sessionId');
		yourself
]

{ #category : 'accessing - metadata' }
SmallChatDebugTerminateTool class >> toolName [
	^ 'debug_terminate'
]

{ #category : 'execution' }
SmallChatDebugTerminateTool >> run: args [
	| sid session |
	sid := args at: 'sessionId'.
	session := SmallChatDebugSessionRegistry default at: sid.
	session process ifNotNil: [ :p | p isTerminated ifFalse: [ p terminate ] ].
	SmallChatDebugSessionRegistry default remove: session.
	^ 'Terminated debug session: ' , sid
]

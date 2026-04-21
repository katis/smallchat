"
MCP tool: compact stack summary for a captured debugger session -- up
to `limit` frames (default 20), each with index, receiverClass,
selector.
"
Class {
	#name : 'SmallChatDebugStackTool',
	#superclass : 'SmallChatTool',
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing - metadata' }
SmallChatDebugStackTool class >> description [
	^ 'Return a compact stack summary for a captured debugger session: up to `limit` frames (default 20), each with index, receiverClass, selector.'
]

{ #category : 'accessing - metadata' }
SmallChatDebugStackTool class >> inputSchema [
	^ Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: (Dictionary new
			at: 'sessionId' put: (Dictionary new at: 'type' put: 'string'; yourself);
			at: 'limit' put: (Dictionary new at: 'type' put: 'integer'; yourself);
			yourself);
		at: 'required' put: #('sessionId');
		yourself
]

{ #category : 'accessing - metadata' }
SmallChatDebugStackTool class >> toolName [
	^ 'debug_stack'
]

{ #category : 'execution' }
SmallChatDebugStackTool >> run: args [
	| sid limit session stack frames |
	sid := args at: 'sessionId'.
	limit := args at: 'limit' ifAbsent: [ 20 ].
	session := SmallChatDebugSessionRegistry default at: sid.
	stack := [ session debugSession stack ] on: Error do: [ :_ | #() ].
	frames := ((stack first: (limit min: stack size)) withIndexCollect: [ :ctx :i |
		Dictionary new
			at: 'index' put: i - 1;
			at: 'receiverClass' put: ([ ctx receiver class name asString ] on: Error do: [ :_ | '<unprintable>' ]);
			at: 'selector' put: ([ ctx method selector asString ] on: Error do: [ :_ | '<unprintable>' ]);
			yourself ]) asArray.
	^ SmallChatToolResult text: (STONJSON toString: (Dictionary new
		at: 'frames' put: frames;
		yourself))
]

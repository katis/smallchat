"
MCP tool: list active captured debugger sessions
(id, exception class, message, top frame, createdAtMs).
"
Class {
	#name : 'SmallChatDebugSessionsTool',
	#superclass : 'SmallChatTool',
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing - metadata' }
SmallChatDebugSessionsTool class >> description [
	^ 'List active captured debugger sessions (id, exception class, message, top frame, age).'
]

{ #category : 'accessing - metadata' }
SmallChatDebugSessionsTool class >> inputSchema [
	^ Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: Dictionary new;
		at: 'required' put: #();
		yourself
]

{ #category : 'accessing - metadata' }
SmallChatDebugSessionsTool class >> toolName [
	^ 'debug_sessions'
]

{ #category : 'execution' }
SmallChatDebugSessionsTool >> run: args [
	| sessions items |
	sessions := SmallChatDebugSessionRegistry default sessionsSnapshot.
	items := sessions collect: [ :s |
		Dictionary new
			at: 'id' put: s id;
			at: 'exceptionClass' put: s exception class name asString;
			at: 'messageText' put: (s exception messageText ifNil: [ '' ]);
			at: 'topFrame' put: ([ s debugSession interruptedContext printString ]
				on: Error do: [ :_ | '<unprintable>' ]);
			at: 'createdAtMs' put: s createdAtMs;
			yourself ].
	^ SmallChatToolResult text: (STONJSON toString: (Dictionary new
		at: 'sessions' put: items asArray;
		yourself))
]

"
MCP tool: detailed view of one frame -- receiver, selector, args,
temps, source.
"
Class {
	#name : 'SmallChatDebugFrameTool',
	#superclass : 'SmallChatTool',
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing - metadata' }
SmallChatDebugFrameTool class >> description [
	^ 'Detailed view of one frame: receiver, selector, args, temps, source.'
]

{ #category : 'accessing - metadata' }
SmallChatDebugFrameTool class >> inputSchema [
	^ Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: (Dictionary new
			at: 'sessionId' put: (Dictionary new at: 'type' put: 'string'; yourself);
			at: 'index' put: (Dictionary new at: 'type' put: 'integer'; yourself);
			yourself);
		at: 'required' put: #('sessionId' 'index');
		yourself
]

{ #category : 'accessing - metadata' }
SmallChatDebugFrameTool class >> toolName [
	^ 'debug_frame'
]

{ #category : 'execution' }
SmallChatDebugFrameTool >> run: args [
	| sid idx session stack ctx safePrint dict |
	sid := args at: 'sessionId'.
	idx := args at: 'index'.
	session := SmallChatDebugSessionRegistry default at: sid.
	stack := [ session debugSession stack ] on: Error do: [ :_ | #() ].
	(idx < 0 or: [ idx >= stack size ]) ifTrue: [
		^ SmallChatToolResult text: (STONJSON toString: (Dictionary new
			at: 'error' put: 'frame index ' , idx asString , ' out of range';
			yourself)) ].
	ctx := stack at: idx + 1.
	safePrint := [ :obj | [ obj printString ] on: Error do: [ :_ | '<unprintable>' ] ].
	dict := Dictionary new
		at: 'index' put: idx;
		at: 'receiverClass' put: ([ ctx receiver class name asString ] on: Error do: [ :_ | '<unprintable>' ]);
		at: 'receiver' put: (safePrint value: ctx receiver);
		at: 'selector' put: ([ ctx method selector asString ] on: Error do: [ :_ | '<unprintable>' ]);
		at: 'args' put: ((ctx arguments collect: [ :a | safePrint value: a ]) asArray);
		at: 'temps' put: ([ | td |
			td := Dictionary new.
			ctx tempNames do: [ :n |
				td at: n put: (safePrint value: (ctx tempNamed: n)) ].
			td ] on: Error do: [ :_ | Dictionary new ]);
		at: 'source' put: ([ ctx method sourceCode ] on: Error do: [ :_ | '' ]);
		yourself.
	^ SmallChatToolResult text: (STONJSON toString: dict)
]

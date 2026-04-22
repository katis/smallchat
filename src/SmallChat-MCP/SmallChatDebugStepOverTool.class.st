Class {
	#name : 'SmallChatDebugStepOverTool',
	#superclass : 'SmallChatTool',
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing - metadata' }
SmallChatDebugStepOverTool class >> description [
    ^ 'Advance one message-send past the current ictx of a captured debugger session, pausing at the new location. First call pops the handler+suspend frames (nil-substituting the signalling expression); subsequent calls advance further. The session keeps the same id and is marked stepped; follow up with debug_step_over/into, debug_proceed, or debug_terminate. debug_return is rejected on stepped sessions.'
]

{ #category : 'accessing - metadata' }
SmallChatDebugStepOverTool class >> inputSchema [
    ^ Dictionary new
        at: 'type' put: 'object';
        at: 'properties' put: (Dictionary new
            at: 'sessionId' put: (Dictionary new at: 'type' put: 'string'; yourself);
            yourself);
        at: 'required' put: #('sessionId');
        yourself
]

{ #category : 'accessing - metadata' }
SmallChatDebugStepOverTool class >> toolName [
    ^ 'debug_step_over'
]

{ #category : 'execution' }
SmallChatDebugStepOverTool >> run: args [
    | sid session outcome |
    sid := args at: 'sessionId'.
    session := SmallChatDebugSessionRegistry default at: sid.
    outcome := SmallChatDebugEvaluator stepOver: session.
    outcome key = #result ifTrue: [ ^ outcome value ].
    outcome key = #debugSession ifTrue: [ ^ SmallChatToolResult debugSession: outcome value ].
    ^ self error: 'Unexpected step_over outcome: ', outcome printString
]

Class {
	#name : 'SmallChatDebugStepIntoTool',
	#superclass : 'SmallChatTool',
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing - metadata' }
SmallChatDebugStepIntoTool class >> description [
    ^ 'Step into the next message-send from the current ictx of a captured debugger session, pausing inside the called method. First call pops the handler+suspend frames (nil-substituting the signalling expression); subsequent calls advance further. The session keeps the same id and is marked stepped. Two calls are typically needed from a post-capture DoIt: the first reaches the next send-site, the second enters the callee.'
]

{ #category : 'accessing - metadata' }
SmallChatDebugStepIntoTool class >> inputSchema [
    ^ Dictionary new
        at: 'type' put: 'object';
        at: 'properties' put: (Dictionary new
            at: 'sessionId' put: (Dictionary new at: 'type' put: 'string'; yourself);
            yourself);
        at: 'required' put: #('sessionId');
        yourself
]

{ #category : 'accessing - metadata' }
SmallChatDebugStepIntoTool class >> toolName [
    ^ 'debug_step_into'
]

{ #category : 'execution' }
SmallChatDebugStepIntoTool >> run: args [
    | sid session outcome |
    sid := args at: 'sessionId'.
    session := SmallChatDebugSessionRegistry default at: sid.
    outcome := SmallChatDebugEvaluator stepInto: session.
    outcome key = #result ifTrue: [ ^ outcome value ].
    outcome key = #debugSession ifTrue: [ ^ SmallChatToolResult debugSession: outcome value ].
    ^ self error: 'Unexpected step_into outcome: ', outcome printString
]

Class {
	#name : 'SmallChatDebugRestartTool',
	#superclass : 'SmallChatTool',
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing - metadata' }
SmallChatDebugRestartTool class >> description [ ^ 'Restart a frame of a captured debugger session, re-executing from its method entry with the same receiver/args. Default index is 0 (signaller). After a fix, restart the caller frame to retry.'
]

{ #category : 'accessing - metadata' }
SmallChatDebugRestartTool class >> inputSchema [
    ^ Dictionary new
        at: 'type' put: 'object';
        at: 'properties' put: (Dictionary new
            at: 'sessionId' put: (Dictionary new at: 'type' put: 'string'; yourself);
            at: 'index' put: (Dictionary new at: 'type' put: 'integer'; at: 'description' put: 'Stack index to restart; defaults to 0 (signaller).'; yourself);
            yourself);
        at: 'required' put: #('sessionId');
        yourself
]

{ #category : 'accessing - metadata' }
SmallChatDebugRestartTool class >> toolName [ ^ 'debug_restart'
]

{ #category : 'execution' }
SmallChatDebugRestartTool >> run: args [
    | sid idx session outcome |
    sid := args at: 'sessionId'.
    idx := args at: 'index' ifAbsent: [ 0 ].
    session := SmallChatDebugSessionRegistry default at: sid.
    outcome := SmallChatDebugEvaluator restart: session index: idx.
    outcome key = #result ifTrue: [ ^ outcome value ].
    outcome key = #debugSession ifTrue: [ ^ SmallChatToolResult debugSession: outcome value ].
    ^ self error: 'Unexpected restart outcome: ' , outcome printString
]

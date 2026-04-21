Class {
	#name : 'SmallChatDebugEvaluateInFrameTool',
	#superclass : 'SmallChatTool',
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing - metadata' }
SmallChatDebugEvaluateInFrameTool class >> description [ ^ 'Evaluate a Smalltalk expression in the context of a captured frame. `self`, args, and temps of that frame are in scope -- ideal for probing state.'
]

{ #category : 'accessing - metadata' }
SmallChatDebugEvaluateInFrameTool class >> inputSchema [
    ^ Dictionary new
        at: 'type' put: 'object';
        at: 'properties' put: (Dictionary new
            at: 'sessionId' put: (Dictionary new at: 'type' put: 'string'; yourself);
            at: 'index' put: (Dictionary new at: 'type' put: 'integer'; yourself);
            at: 'expression' put: (Dictionary new at: 'type' put: 'string'; yourself);
            yourself);
        at: 'required' put: #('sessionId' 'index' 'expression');
        yourself
]

{ #category : 'accessing - metadata' }
SmallChatDebugEvaluateInFrameTool class >> toolName [ ^ 'debug_evaluate'
]

{ #category : 'execution' }
SmallChatDebugEvaluateInFrameTool >> run: args [
    | sid idx expr session stack ctx result |
    sid := args at: 'sessionId'.
    idx := args at: 'index'.
    expr := args at: 'expression'.
    session := SmallChatDebugSessionRegistry default at: sid.
    stack := session debugSession stack.
    (idx < 0 or: [ idx >= stack size ]) ifTrue: [ ^ 'frame index ' , idx asString , ' out of range' ].
    ctx := stack at: idx + 1.
    result := OpalCompiler new
        source: expr;
        context: ctx;
        receiver: ctx receiver;
        evaluate.
    ^ result printString
]

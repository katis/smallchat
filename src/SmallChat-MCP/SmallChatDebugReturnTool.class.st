"
MCP tool: resume a captured debug session, substituting the value of
`expression` for the signalling expression. If the resumed code then
completes, returns the final result; if it raises again, returns a
new debugSession handle.
"
Class {
	#name : 'SmallChatDebugReturnTool',
	#superclass : 'SmallChatTool',
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing - metadata' }
SmallChatDebugReturnTool class >> description [
	^ 'Resume a captured debugger session, substituting the value of `expression` for the signalling expression. If the resumed code completes, returns the final result. If it raises again, returns a new debugSession.'
]

{ #category : 'accessing - metadata' }
SmallChatDebugReturnTool class >> inputSchema [
	^ Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: (Dictionary new
			at: 'sessionId' put: (Dictionary new
				at: 'type' put: 'string';
				at: 'description' put: 'Debug session id returned by evaluate/run_tests.';
				yourself);
			at: 'expression' put: (Dictionary new
				at: 'type' put: 'string';
				at: 'description' put: 'Smalltalk expression. Its value substitutes for the signalling expression.';
				yourself);
			yourself);
		at: 'required' put: #('sessionId' 'expression');
		yourself
]

{ #category : 'accessing - metadata' }
SmallChatDebugReturnTool class >> toolName [
	^ 'debug_return'
]

{ #category : 'execution' }
SmallChatDebugReturnTool >> run: args [
    | sid expr session value outcome |
    sid := args at: 'sessionId'.
    expr := args at: 'expression'.
    session := SmallChatDebugSessionRegistry default at: sid.
    session stepped ifTrue: [
        ^ self error: 'debug_return is not valid on a stepped session (no live signalling expression to substitute). Use debug_proceed to continue, or debug_terminate to drop.' ].
    value := OpalCompiler new source: expr; evaluate.
    outcome := SmallChatDebugEvaluator resume: session with: value.
    outcome key = #result ifTrue: [ ^ outcome value ].
    outcome key = #debugSession ifTrue: [ ^ SmallChatToolResult debugSession: outcome value ].
    ^ self error: 'Unexpected resume outcome: ' , outcome printString
]

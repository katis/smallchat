"
Evaluate an arbitrary Smalltalk expression in the live image. Delegates
to SmallChatDebugEvaluator so that uncaught exceptions land in a
captured debug session (registered in SmallChatDebugSessionRegistry,
inspectable via the debug_* MCP tools) instead of flattening to a
string or opening the UI debugger.

Returns either:
  - String printString of the evaluated result, on success.
  - SmallChatToolResult debugSession: <session>, which the registry
    unwraps into the debug-session MCP reply shape.
"
Class {
	#name : #SmallChatEvaluateTool,
	#superclass : #SmallChatTool,
	#category : #'SmallChat-MCP'
}

{ #category : #'accessing - metadata' }
SmallChatEvaluateTool class >> description [
	^ 'Evaluate a Smalltalk expression in the running Pharo image and return its printString. Uncaught exceptions land in a captured debug session (see debug_* tools). Use for reading state, invoking methods, or running one-shot scripts.'
]

{ #category : #'accessing - metadata' }
SmallChatEvaluateTool class >> inputSchema [
	^ Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: (Dictionary new
			at: 'code' put: (Dictionary new
				at: 'type' put: 'string';
				at: 'description' put: 'Smalltalk expression to evaluate. Example: "Smalltalk globals size" or "3 + 4 factorial"';
				yourself);
			yourself);
		at: 'required' put: #('code');
		yourself
]

{ #category : #'accessing - metadata' }
SmallChatEvaluateTool class >> toolName [ ^ 'evaluate' ]

{ #category : #execution }
SmallChatEvaluateTool >> run: args [
	| code outcome |
	code := args at: 'code'.
	outcome := SmallChatDebugEvaluator evaluate: code.
	outcome key = #result ifTrue: [ ^ outcome value ].
	outcome key = #debugSession ifTrue: [
		^ SmallChatToolResult debugSession: outcome value ].
	^ self error: 'Unexpected evaluator outcome: ', outcome printString
]

"
Evaluate an arbitrary Smalltalk expression in the live image and
return the printString of the result.
"
Class {
	#name : #SmallChatEvaluateTool,
	#superclass : #SmallChatTool,
	#category : #'SmallChat-MCP'
}

{ #category : #'accessing - metadata' }
SmallChatEvaluateTool class >> description [
	^ 'Evaluate a Smalltalk expression in the running Pharo image and return its printString. Use for reading state, invoking methods, or running one-shot scripts.'
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
	| code result |
	code := args at: 'code'.
	result := OpalCompiler new
		source: code;
		evaluate.
	^ result printString
]

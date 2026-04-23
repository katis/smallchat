Class {
	#name : 'SmallChatLMEvaluateToolTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatLMEvaluateToolTest >> testRunReturnsPrintStringOfCompositeValues [
	| tool |
	tool := SmallChatLMEvaluateTool new.
	self assert: (tool runWithArgumentsJSON: '{"code":"#(1 2 3) reversed"}')
		equals: '#(3 2 1)'
]

{ #category : 'tests' }
SmallChatLMEvaluateToolTest >> testRunWithMalformedJsonReturnsErrorString [
	| tool result |
	tool := SmallChatLMEvaluateTool new.
	result := tool runWithArgumentsJSON: 'not-json'.
	self assert: (result beginsWith: 'Error: ')
]

{ #category : 'tests' }
SmallChatLMEvaluateToolTest >> testRunWithMissingCodeArgumentReturnsErrorString [
	| tool result |
	tool := SmallChatLMEvaluateTool new.
	result := tool runWithArgumentsJSON: '{}'.
	self assert: (result beginsWith: 'Error: '). 
	self assert: (result includesSubstring: 'code')
]

{ #category : 'tests' }
SmallChatLMEvaluateToolTest >> testRunWithSmalltalkErrorReturnsErrorString [
	| tool result |
	tool := SmallChatLMEvaluateTool new.
	result := tool runWithArgumentsJSON: '{"code":"1/0"}'.
	self assert: (result beginsWith: 'Error: '). 
	self assert: (result includesSubstring: 'ZeroDivide')
]

{ #category : 'tests' }
SmallChatLMEvaluateToolTest >> testRunWithValidJsonReturnsPrintStringOfResult [
	| tool |
	tool := SmallChatLMEvaluateTool new.
	self assert: (tool runWithArgumentsJSON: '{"code":"3 + 4"}') equals: '7'
]

{ #category : 'tests' }
SmallChatLMEvaluateToolTest >> testToolSchemaIsFunctionShapedWithCodeArg [
	| schema fn params props code required |
	schema := SmallChatLMEvaluateTool toolSchema.
	self assert: (schema at: 'type') equals: 'function'.
	fn := schema at: 'function'.
	self assert: (fn at: 'name') equals: 'evaluate'.
	self assert: (fn at: 'description') isString.
	params := fn at: 'parameters'.
	self assert: (params at: 'type') equals: 'object'.
	props := params at: 'properties'.
	code := props at: 'code'.
	self assert: (code at: 'type') equals: 'string'.
	required := params at: 'required'.
	self assert: (required includes: 'code')
]

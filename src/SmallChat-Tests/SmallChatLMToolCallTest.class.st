Class {
	#name : 'SmallChatLMToolCallTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatLMToolCallTest >> testConstructsWithIdNameAndArguments [
	| call |
	call := SmallChatLMToolCall id: 'call_1' name: 'evaluate' arguments: '{"code":"3+4"}'.
	self assert: call id equals: 'call_1'.
	self assert: call name equals: 'evaluate'.
	self assert: call arguments equals: '{"code":"3+4"}'
]

{ #category : 'tests' }
SmallChatLMToolCallTest >> testEqualityOnSameFields [
	| a b |
	a := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{}'.
	b := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{}'.
	self assert: a equals: b.
	self assert: a hash equals: b hash
]

{ #category : 'tests' }
SmallChatLMToolCallTest >> testInequalityOnDifferentArguments [
	| a b |
	a := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{"code":"1"}'.
	b := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{"code":"2"}'.
	self deny: a = b
]

{ #category : 'tests' }
SmallChatLMToolCallTest >> testInequalityOnDifferentId [
	| a b |
	a := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{}'.
	b := SmallChatLMToolCall id: 'c2' name: 'evaluate' arguments: '{}'.
	self deny: a = b
]

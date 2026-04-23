Class {
	#name : 'SmallChatLMMessageTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatLMMessageTest >> testConstructsAssistantMessageWithToolCalls [
	| call msg |
	call := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{}'.
	msg := SmallChatLMMessage role: #assistant content: '' toolCalls: { call }.
	self assert: msg role equals: #assistant.
	self assert: msg content equals: ''.
	self assert: msg toolCalls equals: { call }.
	self assert: msg toolCallId isNil
]

{ #category : 'tests' }
SmallChatLMMessageTest >> testConstructsToolMessageWithToolCallId [
	| msg |
	msg := SmallChatLMMessage role: #tool content: '42' toolCallId: 'call_1'.
	self assert: msg role equals: #tool.
	self assert: msg content equals: '42'.
	self assert: msg toolCallId equals: 'call_1'.
	self assert: msg toolCalls isNil
]

{ #category : 'tests' }
SmallChatLMMessageTest >> testConstructsWithRoleAndContent [
	| msg |
	msg := SmallChatLMMessage role: #user content: 'hello'.
	self assert: msg role equals: #user.
	self assert: msg content equals: 'hello'
]

{ #category : 'tests' }
SmallChatLMMessageTest >> testConstructsWithThinking [
	| msg |
	msg := SmallChatLMMessage role: #assistant content: 'hi' thinking: 'why'.
	self assert: msg role equals: #assistant.
	self assert: msg content equals: 'hi'.
	self assert: msg thinking equals: 'why'
]

{ #category : 'tests' }
SmallChatLMMessageTest >> testEqualityIncludesThinking [
	| a b c |
	a := SmallChatLMMessage role: #assistant content: 'hi' thinking: 'why'.
	b := SmallChatLMMessage role: #assistant content: 'hi' thinking: 'why'.
	c := SmallChatLMMessage role: #assistant content: 'hi' thinking: 'different'.
	self assert: a equals: b.
	self assert: a hash equals: b hash.
	self deny: a = c
]

{ #category : 'tests' }
SmallChatLMMessageTest >> testEqualityIncludesToolCallId [
	| a b c |
	a := SmallChatLMMessage role: #tool content: '42' toolCallId: 'c1'.
	b := SmallChatLMMessage role: #tool content: '42' toolCallId: 'c1'.
	c := SmallChatLMMessage role: #tool content: '42' toolCallId: 'c2'.
	self assert: a equals: b.
	self assert: a hash equals: b hash.
	self deny: a = c
]

{ #category : 'tests' }
SmallChatLMMessageTest >> testEqualityIncludesToolCalls [
	| callA callB a b c |
	callA := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{}'.
	callB := SmallChatLMToolCall id: 'c2' name: 'evaluate' arguments: '{}'.
	a := SmallChatLMMessage role: #assistant content: '' toolCalls: { callA }.
	b := SmallChatLMMessage role: #assistant content: '' toolCalls: { callA }.
	c := SmallChatLMMessage role: #assistant content: '' toolCalls: { callB }.
	self assert: a equals: b.
	self assert: a hash equals: b hash.
	self deny: a = c
]

{ #category : 'tests' }
SmallChatLMMessageTest >> testEqualityOnSameRoleAndContent [
	| a b |
	a := SmallChatLMMessage role: #user content: 'hi'.
	b := SmallChatLMMessage role: #user content: 'hi'.
	self assert: a equals: b.
	self assert: a hash equals: b hash
]

{ #category : 'tests' }
SmallChatLMMessageTest >> testInequalityOnDifferentContent [
	| a b |
	a := SmallChatLMMessage role: #user content: 'hi'.
	b := SmallChatLMMessage role: #user content: 'bye'.
	self deny: a = b
]

{ #category : 'tests' }
SmallChatLMMessageTest >> testThinkingDefaultsToNilForTwoArgConstructor [
	| msg |
	msg := SmallChatLMMessage role: #user content: 'hi'.
	self assert: msg thinking isNil
]

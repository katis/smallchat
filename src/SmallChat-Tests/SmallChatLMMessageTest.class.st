Class {
	#name : 'SmallChatLMMessageTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

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

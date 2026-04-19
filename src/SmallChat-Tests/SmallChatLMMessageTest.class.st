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

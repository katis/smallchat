Class {
	#name : 'SmallChatLMConversationTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatLMConversationTest >> testAddToolForCallIdAppendsToolMessage [
	| conv msg |
	conv := SmallChatLMConversation new.
	conv addTool: '42' forCallId: 'call_1'.
	self assert: conv messages size equals: 1.
	msg := conv messages first.
	self assert: msg role equals: #tool.
	self assert: msg content equals: '42'.
	self assert: msg toolCallId equals: 'call_1'
]

{ #category : 'tests' }
SmallChatLMConversationTest >> testAddsPreserveOrder [
	| conv roles contents |
	conv := SmallChatLMConversation new
		addSystem: 'you are helpful';
		addUser: 'hi';
		addAssistant: 'hello';
		yourself.
	roles := (conv messages collect: [ :m | m role ]) asArray.
	contents := (conv messages collect: [ :m | m content ]) asArray.
	self assert: roles equals: #(#system #user #assistant).
	self assert: contents equals: #('you are helpful' 'hi' 'hello')
]

{ #category : 'tests' }
SmallChatLMConversationTest >> testNewConversationIsEmpty [
	self assert: SmallChatLMConversation new messages isEmpty
]

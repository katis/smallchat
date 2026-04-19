Class {
	#name : 'SmallChatLMConversationTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

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

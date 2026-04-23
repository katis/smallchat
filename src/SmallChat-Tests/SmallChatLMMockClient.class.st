"
Test fake for SmallChatLMClient. queueReply: enqueues an
already-built SmallChatLMMessage; #complete: pops the next. Records
each inbound conversation (shallow-copied) in callLog so tests can
assert the session rebuilt the turn correctly after a tool round.
"
Class {
	#name : 'SmallChatLMMockClient',
	#superclass : 'Object',
	#instVars : [
		'replies',
		'callLog'
	],
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'accessing' }
SmallChatLMMockClient >> callCount [
	^ callLog size
]

{ #category : 'accessing' }
SmallChatLMMockClient >> callLog [
	^ callLog
]

{ #category : 'chat' }
SmallChatLMMockClient >> complete: aConversation [
	callLog add: aConversation messages copy.
	replies isEmpty ifTrue: [ ^ SmallChatLMMessage role: #assistant content: '(no more replies)' ].
	^ replies removeFirst
]

{ #category : 'initialization' }
SmallChatLMMockClient >> initialize [
	super initialize.
	replies := OrderedCollection new.
	callLog := OrderedCollection new
]

{ #category : 'configuration' }
SmallChatLMMockClient >> queueReply: aMessage [
	replies add: aMessage.
	^ self
]

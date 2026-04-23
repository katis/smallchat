"
One chat turn: a role symbol (#system | #user | #assistant) and a content
string. Deliberately lean -- tool-calling will later add toolCalls /
toolCallId slots or a subclass; keeping the shape small now means the
render/parse layers don't fight an over-specified message.
"
Class {
	#name : 'SmallChatLMMessage',
	#superclass : 'Object',
	#instVars : [
		'role',
		'content',
		'thinking',
		'rawStream',
		'toolCalls',
		'toolCallId'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'instance creation' }
SmallChatLMMessage class >> role: aSymbol content: aString [
	^ self new role: aSymbol; content: aString; yourself
]

{ #category : 'instance creation' }
SmallChatLMMessage class >> role: aSymbol content: aString thinking: aThinkingOrNil [
	^ self new role: aSymbol; content: aString; thinking: aThinkingOrNil; yourself
]

{ #category : 'instance creation' }
SmallChatLMMessage class >> role: aSymbol content: aString toolCallId: anId [
	^ self new role: aSymbol; content: aString; toolCallId: anId; yourself
]

{ #category : 'instance creation' }
SmallChatLMMessage class >> role: aSymbol content: aString toolCalls: anArrayOfToolCalls [
	^ self new role: aSymbol; content: aString; toolCalls: anArrayOfToolCalls; yourself
]

{ #category : 'comparing' }
SmallChatLMMessage >> = anObject [
	self == anObject ifTrue: [ ^ true ].
	self class = anObject class ifFalse: [ ^ false ].
	^ role = anObject role
		and: [ content = anObject content
		and: [ thinking = anObject thinking
		and: [ toolCalls = anObject toolCalls
		and: [ toolCallId = anObject toolCallId ] ] ] ]
]

{ #category : 'accessing' }
SmallChatLMMessage >> content [
	^ content
]

{ #category : 'accessing' }
SmallChatLMMessage >> content: aString [
	content := aString
]

{ #category : 'comparing' }
SmallChatLMMessage >> hash [
	^ ((role hash bitXor: content hash) bitXor: thinking hash)
		bitXor: (toolCalls hash bitXor: toolCallId hash)
]

{ #category : 'printing' }
SmallChatLMMessage >> printOn: aStream [
	aStream
		nextPutAll: self class name;
		nextPutAll: '(';
		print: role;
		nextPutAll: ': ';
		print: content;
		nextPutAll: ')'
]

{ #category : 'accessing' }
SmallChatLMMessage >> rawStream [
    ^ rawStream
]

{ #category : 'accessing' }
SmallChatLMMessage >> rawStream: aStringOrNil [
    rawStream := aStringOrNil
]

{ #category : 'accessing' }
SmallChatLMMessage >> role [
	^ role
]

{ #category : 'accessing' }
SmallChatLMMessage >> role: aSymbol [
	role := aSymbol
]

{ #category : 'accessing' }
SmallChatLMMessage >> thinking [
	^ thinking
]

{ #category : 'accessing' }
SmallChatLMMessage >> thinking: aStringOrNil [
	thinking := aStringOrNil
]

{ #category : 'accessing' }
SmallChatLMMessage >> toolCallId [
	^ toolCallId
]

{ #category : 'accessing' }
SmallChatLMMessage >> toolCallId: aStringOrNil [
	toolCallId := aStringOrNil
]

{ #category : 'accessing' }
SmallChatLMMessage >> toolCalls [
	^ toolCalls
]

{ #category : 'accessing' }
SmallChatLMMessage >> toolCalls: anArrayOrNil [
	toolCalls := anArrayOrNil
]

"
Value object for one tool call emitted by the LM:
  id         server-assigned identifier (matches a later tool_call_id)
  name       function name (e.g. 'evaluate')
  arguments  raw JSON string -- parsed lazily by the dispatcher
"
Class {
	#name : 'SmallChatLMToolCall',
	#superclass : 'Object',
	#instVars : [
		'id',
		'name',
		'arguments'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'instance creation' }
SmallChatLMToolCall class >> id: anId name: aName arguments: aJsonString [
	^ self new id: anId; name: aName; arguments: aJsonString; yourself
]

{ #category : 'comparing' }
SmallChatLMToolCall >> = anObject [
	self == anObject ifTrue: [ ^ true ].
	self class = anObject class ifFalse: [ ^ false ].
	^ id = anObject id
		and: [ name = anObject name
		and: [ arguments = anObject arguments ] ]
]

{ #category : 'accessing' }
SmallChatLMToolCall >> arguments [
	^ arguments
]

{ #category : 'accessing' }
SmallChatLMToolCall >> arguments: aString [
	arguments := aString
]

{ #category : 'comparing' }
SmallChatLMToolCall >> hash [
	^ (id hash bitXor: name hash) bitXor: arguments hash
]

{ #category : 'accessing' }
SmallChatLMToolCall >> id [
	^ id
]

{ #category : 'accessing' }
SmallChatLMToolCall >> id: aString [
	id := aString
]

{ #category : 'accessing' }
SmallChatLMToolCall >> name [
	^ name
]

{ #category : 'accessing' }
SmallChatLMToolCall >> name: aString [
	name := aString
]

{ #category : 'printing' }
SmallChatLMToolCall >> printOn: aStream [
	aStream
		nextPutAll: self class name;
		nextPutAll: '(#';
		nextPutAll: (name ifNil: [ '?' ]);
		nextPutAll: ' ';
		print: id;
		nextPutAll: ')'
]

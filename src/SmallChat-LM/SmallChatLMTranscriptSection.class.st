Class {
	#name : 'SmallChatLMTranscriptSection',
	#superclass : 'Object',
	#instVars : [
		'kind',
		'message',
		'toolCall',
		'toolResult'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'instance creation' }
SmallChatLMTranscriptSection class >> userOn: aMessage [
    ^ self new setKind: #user message: aMessage; yourself
]

{ #category : 'accessing' }
SmallChatLMTranscriptSection >> kind [
    ^ kind
]

{ #category : 'accessing' }
SmallChatLMTranscriptSection >> message [
    ^ message
]

{ #category : 'private' }
SmallChatLMTranscriptSection >> setKind: aSymbol message: aMessage [
    kind := aSymbol.
    message := aMessage
]

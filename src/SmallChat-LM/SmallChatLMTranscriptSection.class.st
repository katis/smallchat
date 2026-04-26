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
SmallChatLMTranscriptSection class >> assistantOn: aMessage [
    ^ self new setKind: #assistant message: aMessage; yourself
]

{ #category : 'instance creation' }
SmallChatLMTranscriptSection class >> thinkingOn: aMessage [
    ^ self new setKind: #thinking message: aMessage; yourself
]

{ #category : 'instance creation' }
SmallChatLMTranscriptSection class >> toolCallOn: aMessage call: aToolCall result: aStringOrNil [
    ^ self new
        setKind: #toolCall message: aMessage;
        toolCall: aToolCall;
        toolResult: aStringOrNil;
        yourself
]

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

{ #category : 'accessing' }
SmallChatLMTranscriptSection >> toolCall [
    ^ toolCall
]

{ #category : 'accessing' }
SmallChatLMTranscriptSection >> toolCall: aToolCallOrNil [
    toolCall := aToolCallOrNil
]

{ #category : 'accessing' }
SmallChatLMTranscriptSection >> toolResult [
    ^ toolResult
]

{ #category : 'accessing' }
SmallChatLMTranscriptSection >> toolResult: aStringOrNil [
    toolResult := aStringOrNil
]

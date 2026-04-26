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

{ #category : 'constants' }
SmallChatLMTranscriptSection class >> maxLabelLength [
    ^ 80
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

{ #category : 'displaying' }
SmallChatLMTranscriptSection >> content [
    kind = #user ifTrue: [ ^ message content ifNil: [ '' ] ].
    kind = #assistant ifTrue: [ ^ message content ifNil: [ '' ] ].
    kind = #thinking ifTrue: [ ^ message thinking ifNil: [ '' ] ].
    kind = #toolCall ifTrue: [
        ^ (toolCall name ifNil: [ '' ]) , '(' , (toolCall arguments ifNil: [ '' ]) , ')' ].
    ^ ''
]

{ #category : 'accessing' }
SmallChatLMTranscriptSection >> kind [
    ^ kind
]

{ #category : 'displaying' }
SmallChatLMTranscriptSection >> label [
    | tag prefix raw max |
    tag := self labelTag.
    prefix := self labelPrefix copyReplaceAll: String lf with: ' '.
    prefix := prefix copyReplaceAll: String cr with: ' '.
    raw := '[' , tag , '] ' , prefix.
    max := self class maxLabelLength.
    raw size > max ifTrue: [
        ^ (raw copyFrom: 1 to: max - 3) , '...' ].
    ^ raw
]

{ #category : 'displaying' }
SmallChatLMTranscriptSection >> labelPrefix [
    kind = #thinking ifTrue: [ ^ message thinking ifNil: [ '' ] ].
    kind = #toolCall ifTrue: [ ^ toolCall name ifNil: [ '' ] ].
    kind = #assistant ifTrue: [
        (message content isNil or: [ message content isEmpty ])
            ifTrue: [ ^ '(streaming...)' ] ].
    ^ message content ifNil: [ '' ]
]

{ #category : 'displaying' }
SmallChatLMTranscriptSection >> labelTag [
    kind = #user ifTrue: [ ^ 'user' ].
    kind = #assistant ifTrue: [ ^ 'asst' ].
    kind = #thinking ifTrue: [ ^ 'thnk' ].
    kind = #toolCall ifTrue: [ ^ 'tool' ].
    ^ '?'
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

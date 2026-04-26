Class {
	#name : 'SmallChatLMTranscriptSectionTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatLMTranscriptSectionTest >> testAssistantAndThinkingConstructors [
    | msg a t |
    msg := SmallChatLMMessage role: #assistant content: 'hi' thinking: 'reasoning'.
    a := SmallChatLMTranscriptSection assistantOn: msg.
    t := SmallChatLMTranscriptSection thinkingOn: msg.
    self assert: a kind equals: #assistant.
    self assert: t kind equals: #thinking.
    self assert: a message == msg.
    self assert: t message == msg
]

{ #category : 'tests' }
SmallChatLMTranscriptSectionTest >> testToolCallSectionStoresCallAndResult [
    | msg tc s |
    tc := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{}'.
    msg := SmallChatLMMessage role: #assistant content: '' toolCalls: { tc }.
    s := SmallChatLMTranscriptSection toolCallOn: msg call: tc result: '42'.
    self assert: s kind equals: #toolCall.
    self assert: s message == msg.
    self assert: s toolCall == tc.
    self assert: s toolResult equals: '42'
]

{ #category : 'tests' }
SmallChatLMTranscriptSectionTest >> testUserLabelHasTagAndContent [
    | msg s |
    msg := SmallChatLMMessage role: #user content: 'hello world'.
    s := SmallChatLMTranscriptSection userOn: msg.
    self assert: s label equals: '[user] hello world'
]

{ #category : 'tests' }
SmallChatLMTranscriptSectionTest >> testUserSectionStoresKindAndMessage [
    | msg s |
    msg := SmallChatLMMessage role: #user content: 'hi'.
    s := SmallChatLMTranscriptSection userOn: msg.
    self assert: s kind equals: #user.
    self assert: s message == msg
]

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
SmallChatLMTranscriptSectionTest >> testUserSectionStoresKindAndMessage [
    | msg s |
    msg := SmallChatLMMessage role: #user content: 'hi'.
    s := SmallChatLMTranscriptSection userOn: msg.
    self assert: s kind equals: #user.
    self assert: s message == msg
]

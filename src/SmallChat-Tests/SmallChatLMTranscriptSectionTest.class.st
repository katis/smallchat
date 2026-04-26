Class {
	#name : 'SmallChatLMTranscriptSectionTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatLMTranscriptSectionTest >> testUserSectionStoresKindAndMessage [
    | msg s |
    msg := SmallChatLMMessage role: #user content: 'hi'.
    s := SmallChatLMTranscriptSection userOn: msg.
    self assert: s kind equals: #user.
    self assert: s message == msg
]

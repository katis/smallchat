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
SmallChatLMTranscriptSectionTest >> testAssistantLabelUsesContent [
    | msg s |
    msg := SmallChatLMMessage role: #assistant content: 'The answer is 7.'.
    s := SmallChatLMTranscriptSection assistantOn: msg.
    self assert: s label equals: '[asst] The answer is 7.'
]

{ #category : 'tests' }
SmallChatLMTranscriptSectionTest >> testContentByKind [
    | userMsg asstMsg tc plumbingMsg |
    userMsg := SmallChatLMMessage role: #user content: 'hi'.
    asstMsg := SmallChatLMMessage role: #assistant content: 'final' thinking: 'reason'.
    tc := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{"code":"3+4"}'.
    plumbingMsg := SmallChatLMMessage role: #assistant content: '' toolCalls: { tc }.
    self assert: (SmallChatLMTranscriptSection userOn: userMsg) content equals: 'hi'.
    self assert: (SmallChatLMTranscriptSection assistantOn: asstMsg) content equals: 'final'.
    self assert: (SmallChatLMTranscriptSection thinkingOn: asstMsg) content equals: 'reason'.
    self assert: (SmallChatLMTranscriptSection toolCallOn: plumbingMsg call: tc result: nil) content equals: 'evaluate({"code":"3+4"})'
]

{ #category : 'tests' }
SmallChatLMTranscriptSectionTest >> testEqualityByKindMessageAndToolCall [
    | msg a b |
    msg := SmallChatLMMessage role: #user content: 'hi'.
    a := SmallChatLMTranscriptSection userOn: msg.
    b := SmallChatLMTranscriptSection userOn: msg.
    self assert: a equals: b.
    self assert: a hash equals: b hash
]

{ #category : 'tests' }
SmallChatLMTranscriptSectionTest >> testInequalityByKindOrMessageOrToolCall [
    | m1 m2 tc1 tc2 plumbing |
    m1 := SmallChatLMMessage role: #assistant content: 'x' thinking: 'y'.
    m2 := SmallChatLMMessage role: #assistant content: 'x' thinking: 'y'.
    self deny: (SmallChatLMTranscriptSection assistantOn: m1) = (SmallChatLMTranscriptSection thinkingOn: m1)
        description: 'different kind on same message must be unequal'.
    self deny: (SmallChatLMTranscriptSection assistantOn: m1) = (SmallChatLMTranscriptSection assistantOn: m2)
        description: 'same role/content but different message identity must be unequal'.
    tc1 := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{}'.
    tc2 := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{}'.
    plumbing := SmallChatLMMessage role: #assistant content: '' toolCalls: { tc1. tc2 }.
    self deny: (SmallChatLMTranscriptSection toolCallOn: plumbing call: tc1 result: nil)
              = (SmallChatLMTranscriptSection toolCallOn: plumbing call: tc2 result: nil)
        description: 'same message but different tool-call identity must be unequal'
]

{ #category : 'tests' }
SmallChatLMTranscriptSectionTest >> testLabelStripsLineFeeds [
    | msg s |
    msg := SmallChatLMMessage role: #user content: 'line one' , String lf , 'line two'.
    s := SmallChatLMTranscriptSection userOn: msg.
    self deny: (s label includesSubstring: String lf).
    self assert: s label equals: '[user] line one line two'
]

{ #category : 'tests' }
SmallChatLMTranscriptSectionTest >> testLabelTruncatesLongContent [
    | msg s |
    msg := SmallChatLMMessage role: #user content: (String new: 200 withAll: $a).
    s := SmallChatLMTranscriptSection userOn: msg.
    self assert: s label size equals: 80.
    self assert: (s label endsWith: '...')
]

{ #category : 'tests' }
SmallChatLMTranscriptSectionTest >> testOutputOnlyForToolCalls [
    | userMsg asstMsg tc plumbingMsg |
    userMsg := SmallChatLMMessage role: #user content: 'hi'.
    asstMsg := SmallChatLMMessage role: #assistant content: 'final' thinking: 'reason'.
    tc := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{}'.
    plumbingMsg := SmallChatLMMessage role: #assistant content: '' toolCalls: { tc }.
    self assert: (SmallChatLMTranscriptSection userOn: userMsg) output equals: ''.
    self assert: (SmallChatLMTranscriptSection assistantOn: asstMsg) output equals: ''.
    self assert: (SmallChatLMTranscriptSection thinkingOn: asstMsg) output equals: ''.
    self assert: (SmallChatLMTranscriptSection toolCallOn: plumbingMsg call: tc result: '42') output equals: '42'.
    self assert: (SmallChatLMTranscriptSection toolCallOn: plumbingMsg call: tc result: nil) output equals: ''
]

{ #category : 'tests' }
SmallChatLMTranscriptSectionTest >> testStreamingAssistantSectionLabelShowsPlaceholder [
    | msg s |
    msg := SmallChatLMMessage role: #assistant content: ''.
    msg rawStream: ''.
    s := SmallChatLMTranscriptSection assistantOn: msg.
    self assert: s label equals: '[asst] (streaming...)'
]

{ #category : 'tests' }
SmallChatLMTranscriptSectionTest >> testThinkingLabelUsesThinkingText [
    | msg s |
    msg := SmallChatLMMessage role: #assistant content: 'final' thinking: 'reasoning'.
    s := SmallChatLMTranscriptSection thinkingOn: msg.
    self assert: s label equals: '[thnk] reasoning'
]

{ #category : 'tests' }
SmallChatLMTranscriptSectionTest >> testToolCallLabelShowsCallName [
    | msg tc s |
    tc := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{"code":"3+4"}'.
    msg := SmallChatLMMessage role: #assistant content: '' toolCalls: { tc }.
    s := SmallChatLMTranscriptSection toolCallOn: msg call: tc result: nil.
    self assert: s label equals: '[tool] evaluate'
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

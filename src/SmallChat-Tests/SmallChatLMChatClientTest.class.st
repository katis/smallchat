Class {
	#name : 'SmallChatLMChatClientTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'helpers' }
SmallChatLMChatClientTest >> clientWithStub: aStub [
	^ SmallChatLMChatClient new
		baseUrl: 'http://localhost:1234';
		modelName: 'test-model';
		maxTokens: 512;
		temperature: 0.3;
		httpClient: aStub;
		yourself
]

{ #category : 'helpers' }
SmallChatLMChatClientTest >> deltaChunkWithContent: aString [
    "Helper: build a streaming-shaped frame whose delta carries aString as content."
    | delta choice |
    delta := Dictionary new at: 'content' put: aString; yourself.
    choice := Dictionary new at: 'delta' put: delta; yourself.
    ^ Dictionary new at: 'choices' put: { choice }; yourself
]

{ #category : 'helpers' }
SmallChatLMChatClientTest >> roleChunkWith: aRoleString [
    "Helper: build a streaming-shaped frame whose delta carries only a role key
     (mirrors the first chunk OpenAI/oMLX typically sends)."
    | delta choice |
    delta := Dictionary new at: 'role' put: aRoleString; yourself.
    choice := Dictionary new at: 'delta' put: delta; yourself.
    ^ Dictionary new at: 'choices' put: { choice }; yourself
]

{ #category : 'helpers' }
SmallChatLMChatClientTest >> stubRespondingWith: aString [
	^ SmallChatLMHttpStub new response: aString; yourself
]

{ #category : 'tests' }
SmallChatLMChatClientTest >> testCompleteOmitsAuthorizationHeaderWhenApiKeyIsNilOrEmpty [
	| stub client |
	stub := self stubRespondingWith: '{"choices":[{"message":{"role":"assistant","content":"ok"}}]}'.
	client := self clientWithStub: stub.
	client apiKey: nil.
	client complete: (SmallChatLMConversation new addUser: 'hi'; yourself).
	self deny: (stub lastHeaders includesKey: 'Authorization').
	client apiKey: ''.
	client complete: (SmallChatLMConversation new addUser: 'hi'; yourself).
	self deny: (stub lastHeaders includesKey: 'Authorization')
]

{ #category : 'tests-streaming' }
SmallChatLMChatClientTest >> testCompleteOnDeltaAssemblesStreamedToolCalls [
	"Streaming tool_calls: fragments arrive with index keys, arguments string
	 concatenated across chunks. Client must assemble them into a single
	 SmallChatLMToolCall on the returned message."
	| c1 c2 c3 stub client reply tc |
	c1 := self toolCallDeltaChunkAtIndex: 0 id: 'call_1' name: 'evaluate' argumentsFragment: '' finishReason: nil.
	c2 := self toolCallDeltaChunkAtIndex: 0 id: nil name: nil argumentsFragment: '{"co' finishReason: nil.
	c3 := self toolCallDeltaChunkAtIndex: 0 id: nil name: nil argumentsFragment: 'de":"3+4"}' finishReason: 'tool_calls'.
	stub := SmallChatLMHttpStub new.
	stub chunks: { c1 . c2 . c3 }.
	client := self clientWithStub: stub.
	reply := client complete: SmallChatLMConversation new onDelta: [ :_ | ].
	self assert: reply role equals: #assistant.
	self assert: reply toolCalls notNil.
	self assert: reply toolCalls size equals: 1.
	tc := reply toolCalls first.
	self assert: tc id equals: 'call_1'.
	self assert: tc name equals: 'evaluate'.
	self assert: tc arguments equals: '{"code":"3+4"}'
]

{ #category : 'tests-streaming' }
SmallChatLMChatClientTest >> testCompleteOnDeltaInvokesBlockPerDeltaInOrder [
    | client stub deltas reply chunkA chunkB chunkC |
    chunkA := self deltaChunkWithContent: 'a'.
    chunkB := self deltaChunkWithContent: 'b'.
    chunkC := self deltaChunkWithContent: 'c'.
    stub := SmallChatLMHttpStub new.
    stub chunks: { chunkA . chunkB . chunkC }.
    client := self clientWithStub: stub.
    deltas := OrderedCollection new.
    reply := client complete: SmallChatLMConversation new onDelta: [ :d | deltas add: d ].
    self assert: deltas asArray equals: #('a' 'b' 'c').
    self assert: reply content equals: 'abc'.
    self assert: reply role equals: #assistant
]

{ #category : 'tests-streaming' }
SmallChatLMChatClientTest >> testCompleteOnDeltaSendsStreamTrueInBody [
    | client stub parsed |
    stub := SmallChatLMHttpStub new.
    stub chunks: { self deltaChunkWithContent: 'hi' }.
    client := self clientWithStub: stub.
    client complete: SmallChatLMConversation new onDelta: [ :_ | ].
    parsed := STONJSON fromString: stub lastBody.
    self assert: (parsed at: 'stream') equals: true
]

{ #category : 'tests-streaming' }
SmallChatLMChatClientTest >> testCompleteOnDeltaSplitsThinkingFromAccumulated [
    "Chunks land mid-tag for both the opening and closing think markers; the
     final assembled message must have the reasoning stripped into thinking
     and the visible answer in content."
    | client stub deltas reply c1 c2 c3 |
    c1 := self deltaChunkWithContent: '<thi'.
    c2 := self deltaChunkWithContent: 'nk>r</thi'.
    c3 := self deltaChunkWithContent: 'nk>hi'.
    stub := SmallChatLMHttpStub new.
    stub chunks: { c1 . c2 . c3 }.
    client := self clientWithStub: stub.
    deltas := OrderedCollection new.
    reply := client complete: SmallChatLMConversation new onDelta: [ :d | deltas add: d ].
    self assert: reply thinking equals: 'r'.
    self assert: reply content equals: 'hi'
]

{ #category : 'tests-streaming' }
SmallChatLMChatClientTest >> testCompleteOnDeltaToleratesEmptyContentDelta [
    | client stub deltas reply emptyChunk realChunk |
    emptyChunk := self deltaChunkWithContent: ''.
    realChunk := self deltaChunkWithContent: 'hi'.
    stub := SmallChatLMHttpStub new.
    stub chunks: { emptyChunk . realChunk }.
    client := self clientWithStub: stub.
    deltas := OrderedCollection new.
    reply := client complete: SmallChatLMConversation new onDelta: [ :d | deltas add: d ].
    self assert: deltas asArray equals: #('hi').
    self assert: reply content equals: 'hi'
]

{ #category : 'tests-streaming' }
SmallChatLMChatClientTest >> testCompleteOnDeltaToleratesLeadingRoleOnlyDelta [
    | client stub deltas reply roleChunk contentChunk |
    roleChunk := self roleChunkWith: 'assistant'.
    contentChunk := self deltaChunkWithContent: 'hi'.
    stub := SmallChatLMHttpStub new.
    stub chunks: { roleChunk . contentChunk }.
    client := self clientWithStub: stub.
    deltas := OrderedCollection new.
    reply := client complete: SmallChatLMConversation new onDelta: [ :d | deltas add: d ].
    self assert: deltas asArray equals: #('hi').
    self assert: reply content equals: 'hi'
]

{ #category : 'tests' }
SmallChatLMChatClientTest >> testCompleteParsesToolCallsFromNonStreamingResponse [
	| stub client conv reply tc |
	stub := self stubRespondingWith: '{"choices":[{"message":{"role":"assistant","content":null,"tool_calls":[{"id":"call_1","type":"function","function":{"name":"evaluate","arguments":"{\"code\":\"3+4\"}"}}]},"finish_reason":"tool_calls"}]}'.
	client := self clientWithStub: stub.
	conv := SmallChatLMConversation new addUser: 'add them'; yourself.
	reply := client complete: conv.
	self assert: reply role equals: #assistant.
	self assert: reply toolCalls notNil.
	self assert: reply toolCalls size equals: 1.
	tc := reply toolCalls first.
	self assert: tc id equals: 'call_1'.
	self assert: tc name equals: 'evaluate'.
	self assert: tc arguments equals: '{"code":"3+4"}'.
	self assert: (reply content isNil or: [ reply content isEmpty ])
]

{ #category : 'tests' }
SmallChatLMChatClientTest >> testCompletePostsToChatCompletionsEndpoint [
	| stub client |
	stub := self stubRespondingWith: '{"choices":[{"message":{"role":"assistant","content":"ok"}}]}'.
	client := self clientWithStub: stub.
	client complete: (SmallChatLMConversation new addUser: 'hi'; yourself).
	self assert: stub lastUrl equals: 'http://localhost:1234/v1/chat/completions'
]

{ #category : 'tests' }
SmallChatLMChatClientTest >> testCompleteRequestBodyIncludesToolsArrayWithEvaluate [
	| stub client parsed tools first fn |
	stub := self stubRespondingWith: '{"choices":[{"message":{"role":"assistant","content":"ok"}}]}'.
	client := self clientWithStub: stub.
	client complete: (SmallChatLMConversation new addUser: 'hi'; yourself).
	parsed := STONJSON fromString: stub lastBody.
	tools := parsed at: 'tools'.
	self assert: tools isArray.
	self assert: tools size equals: 1.
	first := tools first.
	self assert: (first at: 'type') equals: 'function'.
	fn := first at: 'function'.
	self assert: (fn at: 'name') equals: 'evaluate'
]

{ #category : 'tests' }
SmallChatLMChatClientTest >> testCompleteRequestBodyIsOpenAIChatShaped [
	| stub client body messages |
	stub := self stubRespondingWith: '{"choices":[{"message":{"role":"assistant","content":"ok"}}]}'.
	client := self clientWithStub: stub.
	client complete: (SmallChatLMConversation new
		addSystem: 'sys';
		addUser: 'hi';
		yourself).
	body := STONJSON fromString: stub lastBody.
	self assert: (body at: 'model') equals: 'test-model'.
	self assert: (body at: 'max_tokens') equals: 512.
	self assert: (body at: 'temperature') equals: 0.3.
	self assert: (body at: 'stream') equals: false.
	messages := body at: 'messages'.
	self assert: messages size equals: 2.
	self assert: ((messages first) at: 'role') equals: 'system'.
	self assert: ((messages first) at: 'content') equals: 'sys'.
	self assert: ((messages second) at: 'role') equals: 'user'.
	self assert: ((messages second) at: 'content') equals: 'hi'
]

{ #category : 'tests' }
SmallChatLMChatClientTest >> testCompleteReturnsAssistantMessageFromChoicesMessageContent [
	| stub client result |
	stub := self stubRespondingWith: '{"choices":[{"message":{"role":"assistant","content":"hi there"}}]}'.
	client := self clientWithStub: stub.
	result := client complete: (SmallChatLMConversation new addUser: 'hi'; yourself).
	self assert: result role equals: #assistant.
	self assert: result content equals: 'hi there'.
	self assert: result thinking isNil
]

{ #category : 'tests' }
SmallChatLMChatClientTest >> testCompleteSendsAuthorizationBearerHeaderWhenApiKeySet [
	| stub client |
	stub := self stubRespondingWith: '{"choices":[{"message":{"role":"assistant","content":"ok"}}]}'.
	client := self clientWithStub: stub.
	client apiKey: 'sk-test-123'.
	client complete: (SmallChatLMConversation new addUser: 'hi'; yourself).
	self assert: (stub lastHeaders at: 'Authorization') equals: 'Bearer sk-test-123'
]

{ #category : 'tests' }
SmallChatLMChatClientTest >> testCompleteSeparatesThinkingFromContent [
	| stub client result |
	stub := self stubRespondingWith: '{"choices":[{"message":{"role":"assistant","content":"<think>reasoning</think>answer"}}]}'.
	client := self clientWithStub: stub.
	result := client complete: (SmallChatLMConversation new addUser: 'hi'; yourself).
	self assert: result role equals: #assistant.
	self assert: result thinking equals: 'reasoning'.
	self assert: result content equals: 'answer'
]

{ #category : 'tests' }
SmallChatLMChatClientTest >> testInitializePullsApiKeyFromConfig [
	| saved |
	saved := SmallChatConfig apiKey.
	[ SmallChatConfig apiKey: 'sk-from-config'.
	  self assert: SmallChatLMChatClient new apiKey equals: 'sk-from-config' ]
		ensure: [ SmallChatConfig apiKey: saved ]
]

{ #category : 'tests' }
SmallChatLMChatClientTest >> testInitializeUsesConfigDefaults [
	| client |
	client := SmallChatLMChatClient new.
	self assert: client baseUrl equals: SmallChatConfig baseUrl.
	self assert: client modelName equals: SmallChatConfig modelName.
	self assert: client maxTokens equals: SmallChatConfig maxTokens.
	self assert: client temperature equals: SmallChatConfig temperature.
	self assert: client httpClient class equals: SmallChatLMZnHttpClient
]

{ #category : 'tests' }
SmallChatLMChatClientTest >> testMessagesForAssistantWithToolCallsSerialisesOpenAIShape [
	| conv call msg client serialized dict calls first |
	call := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{"code":"3+4"}'.
	msg := SmallChatLMMessage role: #assistant content: '' toolCalls: { call }.
	conv := SmallChatLMConversation new.
	conv addMessage: msg.
	client := self clientWithStub: (self stubRespondingWith: '{}').
	serialized := client messagesFor: conv.
	dict := serialized first.
	self assert: (dict at: 'role') equals: 'assistant'.
	self assert: (dict at: 'content') equals: ''.
	calls := dict at: 'tool_calls'.
	self assert: calls size equals: 1.
	first := calls first.
	self assert: (first at: 'id') equals: 'c1'.
	self assert: (first at: 'type') equals: 'function'.
	self assert: ((first at: 'function') at: 'name') equals: 'evaluate'.
	self assert: ((first at: 'function') at: 'arguments') equals: '{"code":"3+4"}'
]

{ #category : 'tests' }
SmallChatLMChatClientTest >> testMessagesForPlainAssistantOmitsToolCallsKey [
	| conv client serialized dict |
	conv := SmallChatLMConversation new addAssistant: 'hi'; yourself.
	client := self clientWithStub: (self stubRespondingWith: '{}').
	serialized := client messagesFor: conv.
	dict := serialized first.
	self deny: (dict includesKey: 'tool_calls').
	self deny: (dict includesKey: 'tool_call_id')
]

{ #category : 'tests' }
SmallChatLMChatClientTest >> testMessagesForToolMessageSerialisesRoleAndToolCallId [
	| conv msg client serialized dict |
	msg := SmallChatLMMessage role: #tool content: '7' toolCallId: 'c1'.
	conv := SmallChatLMConversation new.
	conv addMessage: msg.
	client := self clientWithStub: (self stubRespondingWith: '{}').
	serialized := client messagesFor: conv.
	dict := serialized first.
	self assert: (dict at: 'role') equals: 'tool'.
	self assert: (dict at: 'content') equals: '7'.
	self assert: (dict at: 'tool_call_id') equals: 'c1'.
	self deny: (dict includesKey: 'tool_calls')
]

{ #category : 'helpers' }
SmallChatLMChatClientTest >> toolCallDeltaChunkAtIndex: anIndex id: anId name: aName argumentsFragment: anArgsFragment finishReason: aFinishOrNil [
	"Build one streaming chunk carrying a delta.tool_calls[anIndex] fragment.
	 Pass nil for any field to omit it (mirrors how OpenAI streams partial state)."
	| toolCall fn delta choice chunk |
	fn := Dictionary new.
	aName ifNotNil: [ :n | fn at: 'name' put: n ].
	anArgsFragment ifNotNil: [ :a | fn at: 'arguments' put: a ].
	toolCall := Dictionary new at: 'index' put: anIndex; yourself.
	anId ifNotNil: [ :i | toolCall at: 'id' put: i; at: 'type' put: 'function' ].
	fn isEmpty ifFalse: [ toolCall at: 'function' put: fn ].
	delta := Dictionary new at: 'tool_calls' put: { toolCall }; yourself.
	choice := Dictionary new at: 'delta' put: delta; yourself.
	aFinishOrNil ifNotNil: [ :f | choice at: 'finish_reason' put: f ].
	chunk := Dictionary new at: 'choices' put: { choice }; yourself.
	^ chunk
]

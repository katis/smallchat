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

{ #category : 'tests' }
SmallChatLMChatClientTest >> testCompletePostsToChatCompletionsEndpoint [
	| stub client |
	stub := self stubRespondingWith: '{"choices":[{"message":{"role":"assistant","content":"ok"}}]}'.
	client := self clientWithStub: stub.
	client complete: (SmallChatLMConversation new addUser: 'hi'; yourself).
	self assert: stub lastUrl equals: 'http://localhost:1234/v1/chat/completions'
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

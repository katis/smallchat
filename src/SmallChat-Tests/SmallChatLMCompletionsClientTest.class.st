Class {
	#name : 'SmallChatLMCompletionsClientTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'helpers' }
SmallChatLMCompletionsClientTest >> clientWithStub: aStub [
	^ SmallChatLMCompletionsClient new
		baseUrl: 'http://localhost:1234';
		modelName: 'test-model';
		maxTokens: 512;
		temperature: 0.3;
		httpClient: aStub;
		yourself
]

{ #category : 'helpers' }
SmallChatLMCompletionsClientTest >> stubRespondingWith: aString [
	^ SmallChatLMHttpStub new response: aString; yourself
]

{ #category : 'tests' }
SmallChatLMCompletionsClientTest >> testCompletePostsToCompletionsEndpoint [
	| stub client |
	stub := self stubRespondingWith: '{"choices":[{"text":"ok"}]}'.
	client := self clientWithStub: stub.
	client complete: (SmallChatLMConversation new addUser: 'hi'; yourself).
	self assert: stub lastUrl equals: 'http://localhost:1234/v1/completions'
]

{ #category : 'tests' }
SmallChatLMCompletionsClientTest >> testCompleteRequestBodyCarriesQwen3Prompt [
	| stub client body |
	stub := self stubRespondingWith: '{"choices":[{"text":"ok"}]}'.
	client := self clientWithStub: stub.
	client complete: (SmallChatLMConversation new addUser: 'hi'; yourself).
	body := STONJSON fromString: stub lastBody.
	self assert: (body at: 'model') equals: 'test-model'.
	self assert: (body at: 'max_tokens') equals: 512.
	self assert: (body at: 'temperature') equals: 0.3.
	self assert: (body at: 'stream') equals: false.
	self assert: (body at: 'stop') asArray equals: #('<|im_end|>').
	self assert: ((body at: 'prompt') includesSubstring: '<|im_start|>user').
	self assert: ((body at: 'prompt') includesSubstring: 'hi<|im_end|>')
]

{ #category : 'tests' }
SmallChatLMCompletionsClientTest >> testCompleteReturnsAssistantMessageStrippingStopToken [
	| stub client result |
	stub := self stubRespondingWith: '{"choices":[{"text":"hi there<|im_end|>"}]}'.
	client := self clientWithStub: stub.
	result := client complete: (SmallChatLMConversation new addUser: 'hi'; yourself).
	self assert: result role equals: #assistant.
	self assert: result content equals: 'hi there'
]

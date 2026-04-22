"
Talks to an OpenAI-compatible /v1/chat/completions endpoint (oMLX is the target today). Sends the conversation as a messages array and parses choices[0].message.content. Thinking extraction (<think>...</think> prefix) is handled in-image since oMLX-served Qwen-family models emit it inline.

Collaborators (all injectable):
  httpClient   anything understanding #post:to: (default: a ZnClient adapter)
  baseUrl, modelName, maxTokens, temperature  (defaults from SmallChatConfig)

Test strategy: inject a stub httpClient that records the outbound body and URL and returns canned JSON. No network in the suite.
"
Class {
	#name : 'SmallChatLMChatClient',
	#superclass : 'SmallChatLMClient',
	#instVars : [
		'baseUrl',
		'modelName',
		'maxTokens',
		'temperature',
		'httpClient',
		'apiKey'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'accessing' }
SmallChatLMChatClient >> apiKey [
	^ apiKey
]

{ #category : 'accessing' }
SmallChatLMChatClient >> apiKey: aStringOrNil [
	apiKey := aStringOrNil
]

{ #category : 'accessing' }
SmallChatLMChatClient >> baseUrl [
	^ baseUrl
]

{ #category : 'accessing' }
SmallChatLMChatClient >> baseUrl: aString [
	baseUrl := aString
]

{ #category : 'private' }
SmallChatLMChatClient >> chatCompletionsUrl [
	^ baseUrl , '/v1/chat/completions'
]

{ #category : 'chat' }
SmallChatLMChatClient >> complete: aConversation [
	| requestBody responseBody parsed content split |
	requestBody := STONJSON toString: (self requestBodyFor: aConversation).
	responseBody := httpClient
		post: requestBody
		to: self chatCompletionsUrl
		withHeaders: self requestHeaders.
	parsed := STONJSON fromString: responseBody.
	content := self extractAssistantContent: parsed.
	split := self splitThinkingAndContent: content.
	^ SmallChatLMMessage
		role: #assistant
		content: (split at: 2)
		thinking: (split at: 1)
]

{ #category : 'private' }
SmallChatLMChatClient >> extractAssistantContent: aResponseDictionary [
	^ (((aResponseDictionary at: 'choices') first) at: 'message') at: 'content'
]

{ #category : 'accessing' }
SmallChatLMChatClient >> httpClient [
	^ httpClient
]

{ #category : 'accessing' }
SmallChatLMChatClient >> httpClient: anObject [
	httpClient := anObject
]

{ #category : 'initialization' }
SmallChatLMChatClient >> initialize [
	super initialize.
	baseUrl := SmallChatConfig baseUrl.
	modelName := SmallChatConfig modelName.
	maxTokens := SmallChatConfig maxTokens.
	temperature := SmallChatConfig temperature.
	apiKey := SmallChatConfig apiKey.
	httpClient := SmallChatLMZnHttpClient new
]

{ #category : 'accessing' }
SmallChatLMChatClient >> maxTokens [
	^ maxTokens
]

{ #category : 'accessing' }
SmallChatLMChatClient >> maxTokens: anInteger [
	maxTokens := anInteger
]

{ #category : 'private' }
SmallChatLMChatClient >> messagesFor: aConversation [
	^ aConversation messages collect: [ :msg |
		Dictionary new
			at: 'role' put: msg role asString;
			at: 'content' put: msg content;
			yourself ]
]

{ #category : 'accessing' }
SmallChatLMChatClient >> modelName [
	^ modelName
]

{ #category : 'accessing' }
SmallChatLMChatClient >> modelName: aString [
	modelName := aString
]

{ #category : 'private' }
SmallChatLMChatClient >> requestBodyFor: aConversation [
	^ Dictionary new
		at: 'model' put: modelName;
		at: 'messages' put: (self messagesFor: aConversation) asArray;
		at: 'max_tokens' put: maxTokens;
		at: 'temperature' put: temperature;
		at: 'stream' put: false;
		yourself
]

{ #category : 'private' }
SmallChatLMChatClient >> requestHeaders [
	| headers |
	headers := Dictionary new.
	(apiKey isNil or: [ apiKey isEmpty ]) ifFalse: [
		headers at: 'Authorization' put: 'Bearer ' , apiKey ].
	^ headers
]

{ #category : 'private' }
SmallChatLMChatClient >> splitThinkingAndContent: aString [
	"Answer { thinkingOrNil. content } parsed from aString. Handles the
	 Qwen3 convention of a single <think>...</think> block prefixing the
	 visible answer. If the string does not start with <think> (ignoring
	 leading whitespace) or the closing tag is missing, answer
	 { nil. aString } so malformed output passes through intact."
	| trimmed openTag closeTag closeIndex thinking rest |
	openTag := '<think>'.
	closeTag := '</think>'.
	trimmed := aString trimLeft.
	(trimmed beginsWith: openTag) ifFalse: [ ^ { nil. aString } ].
	closeIndex := trimmed indexOfSubCollection: closeTag startingAt: openTag size + 1.
	closeIndex = 0 ifTrue: [ ^ { nil. aString } ].
	thinking := (trimmed copyFrom: openTag size + 1 to: closeIndex - 1) trim.
	rest := (trimmed copyFrom: closeIndex + closeTag size to: trimmed size) trimLeft.
	^ { thinking. rest }
]

{ #category : 'accessing' }
SmallChatLMChatClient >> temperature [
	^ temperature
]

{ #category : 'accessing' }
SmallChatLMChatClient >> temperature: aNumber [
	temperature := aNumber
]

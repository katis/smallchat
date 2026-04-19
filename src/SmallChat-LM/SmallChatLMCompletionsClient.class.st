"
Talks to an OpenAI-compatible /v1/completions endpoint (LM Studio is the
target today). Renders the conversation through an in-image prompt
template, POSTs a raw completion request, parses choices[0].text, and
strips the trailing stop token from the result.

Collaborators (all injectable):
  template     a SmallChatLMPromptTemplate (default: Qwen3)
  httpClient   anything understanding #post:to: (default: a ZnClient adapter)
  baseUrl, modelName, maxTokens, temperature  (defaults from SmallChatConfig)

Test strategy: inject a stub httpClient that records the outbound body
and URL and returns canned JSON. No network in the suite.
"
Class {
	#name : 'SmallChatLMCompletionsClient',
	#superclass : 'SmallChatLMClient',
	#instVars : [
		'baseUrl',
		'modelName',
		'template',
		'maxTokens',
		'temperature',
		'httpClient'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'accessing' }
SmallChatLMCompletionsClient >> baseUrl [
	^ baseUrl
]

{ #category : 'accessing' }
SmallChatLMCompletionsClient >> baseUrl: aString [
	baseUrl := aString
]

{ #category : 'chat' }
SmallChatLMCompletionsClient >> complete: aConversation [
	| requestBody responseBody parsed text stripped split |
	requestBody := STONJSON toString: (self requestBodyFor: aConversation).
	responseBody := httpClient post: requestBody to: self completionsUrl.
	parsed := STONJSON fromString: responseBody.
	text := self extractCompletionText: parsed.
	stripped := self stripTrailingStopToken: text.
	split := self splitThinkingAndContent: stripped.
	^ SmallChatLMMessage
		role: #assistant
		content: (split at: 2)
		thinking: (split at: 1)
]

{ #category : 'private' }
SmallChatLMCompletionsClient >> completionsUrl [
	^ baseUrl , '/v1/completions'
]

{ #category : 'private' }
SmallChatLMCompletionsClient >> extractCompletionText: aResponseDictionary [
	^ (aResponseDictionary at: 'choices') first at: 'text'
]

{ #category : 'accessing' }
SmallChatLMCompletionsClient >> httpClient [
	^ httpClient
]

{ #category : 'accessing' }
SmallChatLMCompletionsClient >> httpClient: anObject [
	httpClient := anObject
]

{ #category : 'initialization' }
SmallChatLMCompletionsClient >> initialize [
	super initialize.
	baseUrl := SmallChatConfig baseUrl.
	modelName := SmallChatConfig modelName.
	maxTokens := SmallChatConfig maxTokens.
	temperature := SmallChatConfig temperature.
	template := SmallChatLMQwen3PromptTemplate new.
	httpClient := SmallChatLMZnHttpClient new
]

{ #category : 'accessing' }
SmallChatLMCompletionsClient >> maxTokens [
	^ maxTokens
]

{ #category : 'accessing' }
SmallChatLMCompletionsClient >> maxTokens: anInteger [
	maxTokens := anInteger
]

{ #category : 'accessing' }
SmallChatLMCompletionsClient >> modelName [
	^ modelName
]

{ #category : 'accessing' }
SmallChatLMCompletionsClient >> modelName: aString [
	modelName := aString
]

{ #category : 'private' }
SmallChatLMCompletionsClient >> requestBodyFor: aConversation [
	^ Dictionary new
		at: 'model' put: modelName;
		at: 'prompt' put: (template render: aConversation);
		at: 'stop' put: template stopTokens asArray;
		at: 'max_tokens' put: maxTokens;
		at: 'temperature' put: temperature;
		at: 'stream' put: false;
		yourself
]

{ #category : 'private' }
SmallChatLMCompletionsClient >> splitThinkingAndContent: aString [
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

{ #category : 'private' }
SmallChatLMCompletionsClient >> stripTrailingStopToken: aString [
	| s |
	s := aString.
	template stopTokens do: [ :tok |
		(s endsWith: tok) ifTrue: [ s := s copyFrom: 1 to: s size - tok size ] ].
	^ s trimRight
]

{ #category : 'accessing' }
SmallChatLMCompletionsClient >> temperature [
	^ temperature
]

{ #category : 'accessing' }
SmallChatLMCompletionsClient >> temperature: aNumber [
	temperature := aNumber
]

{ #category : 'accessing' }
SmallChatLMCompletionsClient >> template [
	^ template
]

{ #category : 'accessing' }
SmallChatLMCompletionsClient >> template: aTemplate [
	template := aTemplate
]

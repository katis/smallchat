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

{ #category : 'private' }
SmallChatLMChatClient >> assistantMessageFromAccumulated: aString [
    "Apply the existing thinking/content split to the streamed accumulator and answer
     the assembled assistant message."
    | split |
    split := self splitThinkingAndContent: aString.
    ^ SmallChatLMMessage
        role: #assistant
        content: (split at: 2)
        thinking: (split at: 1)
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

{ #category : 'chat' }
SmallChatLMChatClient >> complete: aConversation onDelta: aOneArgBlock [
    "Streaming completion. Drives httpClient with the streaming POST seam, extracts
     choices[0].delta.content per chunk, forwards non-empty deltas to aOneArgBlock,
     accumulates the full content, and returns the assembled SmallChatLMMessage with
     thinking split from content."
    | requestBody accumulator |
    requestBody := STONJSON toString: (self requestBodyFor: aConversation streaming: true).
    accumulator := WriteStream on: String new.
    httpClient
        post: requestBody
        to: self chatCompletionsUrl
        withHeaders: self requestHeaders
        onChunk: [ :frame | | choices delta content |
            choices := frame at: 'choices' ifAbsent: [ #() ].
            choices isEmpty ifFalse: [
                delta := choices first at: 'delta' ifAbsent: [ nil ].
                delta isNil ifFalse: [
                    content := delta at: 'content' ifAbsent: [ nil ].
                    (content isNil or: [ content isEmpty ]) ifFalse: [
                        accumulator nextPutAll: content.
                        aOneArgBlock value: content ] ] ] ].
    ^ self assistantMessageFromAccumulated: accumulator contents
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
	^ aConversation messages collect: [ :msg | self serializedMessageFor: msg ]
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
    ^ self requestBodyFor: aConversation streaming: false
]

{ #category : 'private' }
SmallChatLMChatClient >> requestBodyFor: aConversation streaming: aBoolean [
    ^ Dictionary new
        at: 'model' put: modelName;
        at: 'messages' put: (self messagesFor: aConversation) asArray;
        at: 'max_tokens' put: maxTokens;
        at: 'temperature' put: temperature;
        at: 'stream' put: aBoolean;
        at: 'tools' put: { SmallChatLMEvaluateTool toolSchema };
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
SmallChatLMChatClient >> serializedMessageFor: aMessage [
	"Build the /v1/chat/completions wire dict for one message, handling the
	 tool-calling shapes: assistant messages with toolCalls carry a tool_calls
	 array; messages with role #tool carry tool_call_id."
	| dict |
	dict := Dictionary new
		at: 'role' put: aMessage role asString;
		at: 'content' put: aMessage content;
		yourself.
	(aMessage toolCalls notNil and: [ aMessage toolCalls notEmpty ])
		ifTrue: [
			dict at: 'tool_calls' put: (aMessage toolCalls collect: [ :tc |
				Dictionary new
					at: 'id' put: tc id;
					at: 'type' put: 'function';
					at: 'function' put: (Dictionary new
						at: 'name' put: tc name;
						at: 'arguments' put: tc arguments;
						yourself);
					yourself ]) asArray ].
	aMessage toolCallId ifNotNil: [ :id | dict at: 'tool_call_id' put: id ].
	^ dict
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

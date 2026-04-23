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

{ #category : 'private' }
SmallChatLMChatClient >> accumulateToolCallsDelta: aDelta into: accumulator [
	"Merge one streaming delta.tool_calls fragment into accumulator, keyed by
	 the fragment's #index. id/name arrive on the first fragment for an index;
	 arguments are concatenated across subsequent fragments."
	| frags |
	frags := aDelta at: 'tool_calls' ifAbsent: [ ^ self ].
	frags do: [ :frag | | idx entry fn |
		idx := frag at: 'index' ifAbsent: [ 0 ].
		entry := accumulator at: idx ifAbsentPut: [
			Dictionary new
				at: 'id' put: '';
				at: 'name' put: '';
				at: 'arguments' put: '';
				yourself ].
		(frag at: 'id' ifAbsent: [ nil ]) ifNotNil: [ :v | entry at: 'id' put: v ].
		fn := frag at: 'function' ifAbsent: [ nil ].
		fn ifNotNil: [
			(fn at: 'name' ifAbsent: [ nil ]) ifNotNil: [ :v | entry at: 'name' put: v ].
			(fn at: 'arguments' ifAbsent: [ nil ]) ifNotNil: [ :v |
				entry at: 'arguments' put: (entry at: 'arguments') , v ] ] ]
]

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
	| requestBody responseBody parsed message content toolCalls split |
	requestBody := STONJSON toString: (self requestBodyFor: aConversation).
	responseBody := httpClient
		post: requestBody
		to: self chatCompletionsUrl
		withHeaders: self requestHeaders.
	parsed := STONJSON fromString: responseBody.
	message := ((parsed at: 'choices') first) at: 'message'.
	content := message at: 'content' ifAbsent: [ nil ].
	content isNil ifTrue: [ content := '' ].
	toolCalls := self toolCallsFrom: (message at: 'tool_calls' ifAbsent: [ nil ]).
	split := self splitThinkingAndContent: content.
	^ toolCalls
		ifNil: [
			SmallChatLMMessage
				role: #assistant
				content: (split at: 2)
				thinking: (split at: 1) ]
		ifNotNil: [ | msg |
			msg := SmallChatLMMessage
				role: #assistant
				content: (split at: 2)
				toolCalls: toolCalls.
			msg thinking: (split at: 1).
			msg ]
]

{ #category : 'chat' }
SmallChatLMChatClient >> complete: aConversation onDelta: aOneArgBlock [
    "Streaming completion. Drives httpClient with the streaming POST seam. For
     each chunk, forwards content deltas to aOneArgBlock (unchanged from the
     pre-tool-calling behaviour) AND accumulates delta.tool_calls fragments by
     index. At stream end, the returned message carries the assembled content
     (with thinking split) and, when present, toolCalls populated from the
     accumulator."
    | requestBody accumulator toolAcc split |
    requestBody := STONJSON toString: (self requestBodyFor: aConversation streaming: true).
    accumulator := WriteStream on: String new.
    toolAcc := Dictionary new.
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
                        aOneArgBlock value: content ].
                    self accumulateToolCallsDelta: delta into: toolAcc ] ] ].
    split := self splitThinkingAndContent: accumulator contents.
    ^ (self toolCallsFromAccumulator: toolAcc)
        ifNil: [
            SmallChatLMMessage
                role: #assistant
                content: (split at: 2)
                thinking: (split at: 1) ]
        ifNotNil: [ :calls | | msg |
            msg := SmallChatLMMessage
                role: #assistant
                content: (split at: 2)
                toolCalls: calls.
            msg thinking: (split at: 1).
            msg ]
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

{ #category : 'private' }
SmallChatLMChatClient >> toolCallsFrom: aToolCallsArrayOrNil [
	"Map an OpenAI-shaped tool_calls array (non-streaming or assembled-streaming)
	 to SmallChatLMToolCall instances. nil or empty returns nil so the message can
	 keep its toolCalls slot unset."
	| calls |
	(aToolCallsArrayOrNil isNil or: [ aToolCallsArrayOrNil isEmpty ])
		ifTrue: [ ^ nil ].
	calls := aToolCallsArrayOrNil collect: [ :raw | | fn |
		fn := raw at: 'function' ifAbsent: [ Dictionary new ].
		SmallChatLMToolCall
			id: (raw at: 'id' ifAbsent: [ '' ])
			name: (fn at: 'name' ifAbsent: [ '' ])
			arguments: (fn at: 'arguments' ifAbsent: [ '' ]) ].
	^ calls asArray
]

{ #category : 'private' }
SmallChatLMChatClient >> toolCallsFromAccumulator: accumulator [
	"Materialise the index-keyed accumulator into an Array of SmallChatLMToolCall
	 sorted by index. nil if the accumulator is empty (no streamed tool calls)."
	| keys |
	accumulator isEmpty ifTrue: [ ^ nil ].
	keys := accumulator keys asSortedCollection asArray.
	^ (keys collect: [ :k | | e |
		e := accumulator at: k.
		SmallChatLMToolCall
			id: (e at: 'id')
			name: (e at: 'name')
			arguments: (e at: 'arguments') ]) asArray
]

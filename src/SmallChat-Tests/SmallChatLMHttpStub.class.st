"
Records the last #post:to: call and returns a canned response body.
Used by SmallChatLMChatClientTest to drive the client without hitting
the network.
"
Class {
	#name : 'SmallChatLMHttpStub',
	#superclass : 'Object',
	#instVars : [
		'response',
		'lastUrl',
		'lastBody',
		'lastHeaders',
		'gate',
		'errorToRaise',
		'chunks'
	],
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'gating' }
SmallChatLMHttpStub >> chunks: anArrayOfDicts [
    chunks := anArrayOfDicts
]

{ #category : 'accessing' }
SmallChatLMHttpStub >> gate [
    ^ gate
]

{ #category : 'gating' }
SmallChatLMHttpStub >> gateOn [
    gate := Semaphore new
]

{ #category : 'accessing' }
SmallChatLMHttpStub >> lastBody [
	^ lastBody
]

{ #category : 'accessing' }
SmallChatLMHttpStub >> lastHeaders [
	^ lastHeaders
]

{ #category : 'accessing' }
SmallChatLMHttpStub >> lastUrl [
	^ lastUrl
]

{ #category : 'api' }
SmallChatLMHttpStub >> post: aBody to: aUrl withHeaders: aHeadersDict [
    lastBody := aBody.
    lastUrl := aUrl.
    lastHeaders := aHeadersDict.
    gate ifNotNil: [ gate wait ].
    errorToRaise ifNotNil: [ Error signal: errorToRaise ].
    ^ response
]

{ #category : 'api' }
SmallChatLMHttpStub >> post: aBody to: aUrl withHeaders: aHeadersDict onChunk: aBlock [
    "Streaming variant. If errorToRaise is set, raise before emitting chunks --
     mirrors the legacy raiseOnPost: contract. Otherwise iterate canned chunks
     (from #chunks: or, when only #response: was set, a single synthetic chunk
     synthesised from the buffered response so existing buffered tests carry
     over) and forward each to aBlock; #gate is waited per chunk if set."
    | toEmit |
    lastBody := aBody.
    lastUrl := aUrl.
    lastHeaders := aHeadersDict.
    errorToRaise ifNotNil: [ Error signal: errorToRaise ].
    toEmit := chunks ifNil: [ self syntheticChunksFromResponse ].
    toEmit ifNil: [ ^ self ].
    toEmit do: [ :c |
        gate ifNotNil: [ gate wait ].
        aBlock value: c ]
]

{ #category : 'gating' }
SmallChatLMHttpStub >> raiseOnPost: aMessage [
    errorToRaise := aMessage
]

{ #category : 'gating' }
SmallChatLMHttpStub >> releaseGate [
    gate ifNotNil: [ gate signal ]
]

{ #category : 'accessing' }
SmallChatLMHttpStub >> response [
	^ response
]

{ #category : 'accessing' }
SmallChatLMHttpStub >> response: aString [
	response := aString
]

{ #category : 'private' }
SmallChatLMHttpStub >> syntheticChunksFromResponse [
    "Wrap the canned buffered response as a single streaming delta so streaming
     callers can be exercised by tests written for the buffered shape."
    | parsed content |
    response ifNil: [ ^ nil ].
    parsed := STONJSON fromString: response.
    content := (((parsed at: 'choices') first) at: 'message') at: 'content'.
    ^ { Dictionary new at: 'choices' put: { Dictionary new at: 'delta' put: (Dictionary new at: 'content' put: content; yourself); yourself }; yourself }
]

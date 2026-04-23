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
    "Streaming variant. If chunks is set, deliver each as a parsed dict to aBlock,
     honouring gate (one wait per chunk) and errorToRaise (raised after the current
     chunk is delivered, so partial-stream tests can verify mid-stream failure).
     If chunks is nil but response is set, synthesize a single chunk from the canned
     response so existing buffered tests keep working when callers switch to streaming."
    | toEmit |
    lastBody := aBody.
    lastUrl := aUrl.
    lastHeaders := aHeadersDict.
    toEmit := chunks ifNil: [ self syntheticChunksFromResponse ].
    toEmit ifNil: [ ^ self ].
    toEmit do: [ :c |
        gate ifNotNil: [ gate wait ].
        aBlock value: c.
        errorToRaise ifNotNil: [ Error signal: errorToRaise ] ]
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

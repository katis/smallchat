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
		'errorToRaise'
	],
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

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

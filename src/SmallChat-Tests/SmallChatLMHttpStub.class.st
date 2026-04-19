"
Records the last #post:to: call and returns a canned response body.
Used by SmallChatLMCompletionsClientTest to drive the client without
hitting the network.
"
Class {
	#name : 'SmallChatLMHttpStub',
	#superclass : 'Object',
	#instVars : [
		'response',
		'lastUrl',
		'lastBody'
	],
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'accessing' }
SmallChatLMHttpStub >> lastBody [
	^ lastBody
]

{ #category : 'accessing' }
SmallChatLMHttpStub >> lastUrl [
	^ lastUrl
]

{ #category : 'api' }
SmallChatLMHttpStub >> post: aBody to: aUrl [
	lastBody := aBody.
	lastUrl := aUrl.
	^ response
]

{ #category : 'accessing' }
SmallChatLMHttpStub >> response [
	^ response
]

{ #category : 'accessing' }
SmallChatLMHttpStub >> response: aString [
	response := aString
]

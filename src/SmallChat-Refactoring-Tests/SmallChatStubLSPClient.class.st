Class {
	#name : 'SmallChatStubLSPClient',
	#superclass : 'Object',
	#instVars : [
		'openedUris',
		'cannedResponses',
		'requestLog'
	],
	#category : 'SmallChat-Refactoring-Tests',
	#package : 'SmallChat-Refactoring-Tests'
}

{ #category : 'configuring' }
SmallChatStubLSPClient >> cannedResponse: aMethod is: aResponse [
  cannedResponses at: aMethod put: aResponse.
  ^ self
]

{ #category : 'initialization' }
SmallChatStubLSPClient >> initialize [
  super initialize.
  openedUris := OrderedCollection new.
  cannedResponses := Dictionary new.
  requestLog := OrderedCollection new
]

{ #category : 'document sync' }
SmallChatStubLSPClient >> openDocumentUri: aUri languageId: anId text: aText [
  openedUris add: (Dictionary new
    at: 'uri' put: aUri;
    at: 'languageId' put: anId;
    at: 'text' put: aText;
    yourself)
]

{ #category : 'accessing' }
SmallChatStubLSPClient >> openedUris [ ^ openedUris
]

{ #category : 'requests' }
SmallChatStubLSPClient >> request: aRequestDictionary onDocumentUri: aUri [
  | method |
  method := aRequestDictionary at: 'method'.
  requestLog add: (Dictionary new
    at: 'method' put: method;
    at: 'uri' put: aUri;
    at: 'params' put: (aRequestDictionary at: 'params' ifAbsent: [ nil ]);
    yourself).
  ^ cannedResponses at: method ifAbsent: [ nil ]
]

{ #category : 'accessing' }
SmallChatStubLSPClient >> requestLog [ ^ requestLog
]

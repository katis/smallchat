Class {
	#name : 'SmallChatStubLSPClient',
	#superclass : 'Object',
	#instVars : [
		'openedUris',
		'cannedResponses',
		'requestLog',
		'cannedSequences'
	],
	#category : 'SmallChat-Refactoring-Tests',
	#package : 'SmallChat-Refactoring-Tests'
}

{ #category : 'configuring' }
SmallChatStubLSPClient >> cannedResponse: aMethod is: aResponse [
  cannedResponses at: aMethod put: aResponse.
  ^ self
]

{ #category : 'configuring' }
SmallChatStubLSPClient >> cannedSequence: aMethod is: aSequence [
  cannedSequences at: aMethod put: aSequence asOrderedCollection.
  ^ self
]

{ #category : 'initialization' }
SmallChatStubLSPClient >> initialize [
  super initialize.
  openedUris := OrderedCollection new.
  cannedResponses := Dictionary new.
  cannedSequences := Dictionary new.
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
SmallChatStubLSPClient >> request: aRequestDictionary [
	"Workspace-level (no per-document URI) request. Logged + answered just
	 like request:onDocumentUri: but with a nil 'uri' field in the log."
	^ self request: aRequestDictionary onDocumentUri: nil
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
  (cannedSequences includesKey: method) ifTrue: [
    | queue |
    queue := cannedSequences at: method.
    queue isEmpty ifFalse: [ ^ queue removeFirst ] ].
  ^ cannedResponses at: method ifAbsent: [ nil ]
]

{ #category : 'accessing' }
SmallChatStubLSPClient >> requestLog [ ^ requestLog
]

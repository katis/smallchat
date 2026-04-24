Class {
	#name : 'SmallChatLSPPendingRequest',
	#superclass : 'Object',
	#instVars : [
		'id',
		'semaphore',
		'resolvedResult',
		'resolved',
		'resolvedError'
	],
	#category : 'SmallChat-LSP',
	#package : 'SmallChat-LSP'
}

{ #category : 'accessing' }
SmallChatLSPPendingRequest >> id [
	^ id
]

{ #category : 'accessing' }
SmallChatLSPPendingRequest >> id: anInteger [
	id := anInteger.
	^ self
]

{ #category : 'initialization' }
SmallChatLSPPendingRequest >> initialize [
	super initialize.
	semaphore := Semaphore new.
	resolved := false
]

{ #category : 'resolution' }
SmallChatLSPPendingRequest >> resolveWith: aResult [
	"Called by the client on the reader path when a matching response arrives.
	 Stores the response's result payload and unblocks any caller sitting on #result."
	resolvedResult := aResult.
	resolved := true.
	semaphore signal
]

{ #category : 'resolution' }
SmallChatLSPPendingRequest >> resolveWithError: aServerError [
	"Called by the client when a response contains error instead of result.
	 Stores the error; #result will raise it when the caller unblocks."
	resolvedError := aServerError.
	resolved := true.
	semaphore signal
]

{ #category : 'resolution' }
SmallChatLSPPendingRequest >> result [
	"Block until resolved, then return the stored result. If the server
	 responded with error, raise that error."
	resolved ifFalse: [ semaphore wait ].
	resolvedError ifNotNil: [ resolvedError signal ].
	^ resolvedResult
]

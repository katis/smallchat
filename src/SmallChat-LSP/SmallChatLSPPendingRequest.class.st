Class {
	#name : 'SmallChatLSPPendingRequest',
	#superclass : 'Object',
	#instVars : [
		'id'
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

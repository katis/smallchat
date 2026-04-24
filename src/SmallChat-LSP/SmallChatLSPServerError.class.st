Class {
	#name : 'SmallChatLSPServerError',
	#superclass : 'Error',
	#instVars : [
		'code'
	],
	#category : 'SmallChat-LSP',
	#package : 'SmallChat-LSP'
}

{ #category : 'accessing' }
SmallChatLSPServerError >> code [
	^ code
]

{ #category : 'accessing' }
SmallChatLSPServerError >> code: anInteger [
	code := anInteger.
	^ self
]

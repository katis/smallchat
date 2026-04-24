Class {
	#name : 'SmallChatLSPTestIntermittentStream',
	#superclass : 'Object',
	#instVars : [
		'bytes',
		'position',
		'nilStride',
		'untilNext'
	],
	#category : 'SmallChat-LSP-Tests',
	#package : 'SmallChat-LSP-Tests'
}

{ #category : 'streaming' }
SmallChatLSPTestIntermittentStream >> atEnd [
	^ position > bytes size
]

{ #category : 'accessing' }
SmallChatLSPTestIntermittentStream >> contents: aByteArray [
	bytes := aByteArray.
	position := 1.
	untilNext := nilStride ifNil: [ 0 ].
	^ self
]

{ #category : 'streaming' }
SmallChatLSPTestIntermittentStream >> next [
	"Return nil without advancing while untilNext > 0; otherwise hand out the
	 next byte. Unlike ReadStream, returning nil does NOT imply EOF -- check
	 atEnd to distinguish starvation from end-of-stream."
	| b |
	position > bytes size ifTrue: [ ^ nil ].
	untilNext > 0 ifTrue: [
		untilNext := untilNext - 1.
		^ nil ].
	untilNext := nilStride.
	b := bytes at: position.
	position := position + 1.
	^ b
]

{ #category : 'accessing' }
SmallChatLSPTestIntermittentStream >> nilStride: aCount [
	"Return nil from #next aCount times between each delivered byte."
	nilStride := aCount.
	untilNext := aCount.
	^ self
]

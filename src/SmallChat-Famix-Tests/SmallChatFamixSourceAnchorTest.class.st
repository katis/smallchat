Class {
	#name : 'SmallChatFamixSourceAnchorTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Famix-Tests',
	#package : 'SmallChat-Famix-Tests'
}

{ #category : 'tests' }
SmallChatFamixSourceAnchorTest >> testEqualityIsValueBased [
	| a b |
	a := SmallChatFamixSourceAnchor fileUri: 'f.ts' startByte: 0 endByte: 5.
	b := SmallChatFamixSourceAnchor fileUri: 'f.ts' startByte: 0 endByte: 5.
	self assert: a equals: b.
	self assert: a hash equals: b hash
]

{ #category : 'tests' }
SmallChatFamixSourceAnchorTest >> testRoundTripsAccessors [
	| anchor |
	anchor := SmallChatFamixSourceAnchor
		fileUri: 'file:///abs/Button.tsx'
		startByte: 12
		endByte: 24.
	self assert: anchor fileUri equals: 'file:///abs/Button.tsx'.
	self assert: anchor startByte equals: 12.
	self assert: anchor endByte equals: 24
]

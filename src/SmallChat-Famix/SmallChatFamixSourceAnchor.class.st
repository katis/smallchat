Class {
	#name : 'SmallChatFamixSourceAnchor',
	#superclass : 'Object',
	#instVars : [
		'fileUri',
		'startByte',
		'endByte'
	],
	#category : 'SmallChat-Famix',
	#package : 'SmallChat-Famix'
}

{ #category : 'instance creation' }
SmallChatFamixSourceAnchor class >> fileUri: aString startByte: aStart endByte: anEnd [
	^ self new
		fileUri: aString;
		startByte: aStart;
		endByte: anEnd;
		yourself
]

{ #category : 'comparing' }
SmallChatFamixSourceAnchor >> = other [
	^ self class == other class
		and: [ fileUri = other fileUri
		and: [ startByte = other startByte
		and: [ endByte = other endByte ] ] ]
]

{ #category : 'accessing' }
SmallChatFamixSourceAnchor >> endByte [
	^ endByte
]

{ #category : 'accessing' }
SmallChatFamixSourceAnchor >> endByte: anInteger [
	endByte := anInteger
]

{ #category : 'accessing' }
SmallChatFamixSourceAnchor >> fileUri [
	^ fileUri
]

{ #category : 'accessing' }
SmallChatFamixSourceAnchor >> fileUri: aString [
	fileUri := aString
]

{ #category : 'comparing' }
SmallChatFamixSourceAnchor >> hash [
	^ ((fileUri hash bitXor: startByte hash) bitXor: endByte hash)
]

{ #category : 'accessing' }
SmallChatFamixSourceAnchor >> startByte [
	^ startByte
]

{ #category : 'accessing' }
SmallChatFamixSourceAnchor >> startByte: anInteger [
	startByte := anInteger
]

Class {
	#name : 'SmallChatFamixProject',
	#superclass : 'SmallChatFamixEntity',
	#instVars : [
		'rootUri'
	],
	#category : 'SmallChat-Famix-Entities',
	#package : 'SmallChat-Famix',
	#tag : 'Entities'
}

{ #category : 'meta' }
SmallChatFamixProject class >> annotation [

	<FMClass: #Project super: #SmallChatFamixEntity>
	<package: #'SmallChat-Famix'>
	<generated>
	^ self
]

{ #category : 'accessing' }
SmallChatFamixProject >> rootUri [ ^ rootUri
]

{ #category : 'accessing' }
SmallChatFamixProject >> rootUri: anObject [ rootUri := anObject
]

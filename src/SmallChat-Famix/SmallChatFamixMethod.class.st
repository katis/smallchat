Class {
	#name : 'SmallChatFamixMethod',
	#superclass : 'SmallChatFamixEntity',
	#instVars : [
		'owningClass'
	],
	#category : 'SmallChat-Famix-Entities',
	#package : 'SmallChat-Famix',
	#tag : 'Entities'
}

{ #category : 'meta' }
SmallChatFamixMethod class >> annotation [

	<FMClass: #Method super: #SmallChatFamixEntity>
	<package: #'SmallChat-Famix'>
	<generated>
	^ self
]

{ #category : 'accessing' }
SmallChatFamixMethod >> owningClass [ ^ owningClass
]

{ #category : 'accessing' }
SmallChatFamixMethod >> owningClass: anObject [ owningClass := anObject
]

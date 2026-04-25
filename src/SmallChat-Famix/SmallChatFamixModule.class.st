Class {
	#name : 'SmallChatFamixModule',
	#superclass : 'SmallChatFamixEntity',
	#instVars : [
		'project'
	],
	#category : 'SmallChat-Famix-Entities',
	#package : 'SmallChat-Famix',
	#tag : 'Entities'
}

{ #category : 'meta' }
SmallChatFamixModule class >> annotation [

	<FMClass: #Module super: #SmallChatFamixEntity>
	<package: #'SmallChat-Famix'>
	<generated>
	^ self
]

{ #category : 'accessing' }
SmallChatFamixModule >> project [ ^ project
]

{ #category : 'accessing' }
SmallChatFamixModule >> project: anObject [ project := anObject
]

Class {
	#name : 'SmallChatFamixCSSClass',
	#superclass : 'SmallChatFamixEntity',
	#instVars : [
		'file'
	],
	#category : 'SmallChat-Famix-Entities',
	#package : 'SmallChat-Famix',
	#tag : 'Entities'
}

{ #category : 'meta' }
SmallChatFamixCSSClass class >> annotation [

	<FMClass: #CSSClass super: #SmallChatFamixEntity>
	<package: #'SmallChat-Famix'>
	<generated>
	^ self
]

{ #category : 'accessing' }
SmallChatFamixCSSClass >> file [ ^ file
]

{ #category : 'accessing' }
SmallChatFamixCSSClass >> file: anObject [ file := anObject
]

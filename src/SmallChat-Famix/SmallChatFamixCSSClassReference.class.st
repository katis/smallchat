Class {
	#name : 'SmallChatFamixCSSClassReference',
	#superclass : 'SmallChatFamixEntity',
	#instVars : [
		'referent',
		'unresolved'
	],
	#category : 'SmallChat-Famix-Entities',
	#package : 'SmallChat-Famix',
	#tag : 'Entities'
}

{ #category : 'meta' }
SmallChatFamixCSSClassReference class >> annotation [

	<FMClass: #CSSClassReference super: #SmallChatFamixEntity>
	<package: #'SmallChat-Famix'>
	<generated>
	^ self
]

{ #category : 'accessing' }
SmallChatFamixCSSClassReference >> referent [ ^ referent
]

{ #category : 'accessing' }
SmallChatFamixCSSClassReference >> referent: anObject [ referent := anObject
]

{ #category : 'accessing' }
SmallChatFamixCSSClassReference >> unresolved [ ^ unresolved
]

{ #category : 'accessing' }
SmallChatFamixCSSClassReference >> unresolved: anObject [ unresolved := anObject
]

Class {
	#name : 'SmallChatFamixEntity',
	#superclass : 'MooseEntity',
	#instVars : [
		'sourceAnchor'
	],
	#category : 'SmallChat-Famix-Entities',
	#package : 'SmallChat-Famix',
	#tag : 'Entities'
}

{ #category : 'meta' }
SmallChatFamixEntity class >> annotation [

	<FMClass: #Entity super: #MooseEntity>
	<package: #'SmallChat-Famix'>
	<generated>
	<abstract>
	^ self
]

{ #category : 'testing' }
SmallChatFamixEntity class >> isAbstract [

	<generated>
	^ self == SmallChatFamixEntity
]

{ #category : 'meta' }
SmallChatFamixEntity class >> metamodel [

	<generated>
	^ SmallChatFamixModel metamodel
]

{ #category : 'accessing' }
SmallChatFamixEntity >> sourceAnchor [
	^ sourceAnchor
]

{ #category : 'accessing' }
SmallChatFamixEntity >> sourceAnchor: anAnchor [
	sourceAnchor := anAnchor
]

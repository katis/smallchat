Class {
	#name : 'SmallChatFamixImport',
	#superclass : 'SmallChatFamixEntity',
	#instVars : [
		'resolvedUri',
		'classification'
	],
	#category : 'SmallChat-Famix-Entities',
	#package : 'SmallChat-Famix',
	#tag : 'Entities'
}

{ #category : 'meta' }
SmallChatFamixImport class >> annotation [

	<FMClass: #Import super: #SmallChatFamixEntity>
	<package: #'SmallChat-Famix'>
	<generated>
	^ self
]

{ #category : 'accessing' }
SmallChatFamixImport >> classification [ ^ classification
]

{ #category : 'accessing' }
SmallChatFamixImport >> classification: anObject [ classification := anObject
]

{ #category : 'accessing' }
SmallChatFamixImport >> resolvedUri [ ^ resolvedUri
]

{ #category : 'accessing' }
SmallChatFamixImport >> resolvedUri: anObject [ resolvedUri := anObject
]

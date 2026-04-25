Class {
	#name : 'SmallChatFamixImporter',
	#superclass : 'Object',
	#instVars : [
		'model',
		'client',
		'parser',
		'walker'
	],
	#category : 'SmallChat-Famix-Importer',
	#package : 'SmallChat-Famix-Importer'
}

{ #category : 'accessing' }
SmallChatFamixImporter >> client [ ^ client
]

{ #category : 'accessing' }
SmallChatFamixImporter >> model [ ^ model
]

{ #category : 'initialization' }
SmallChatFamixImporter >> model: aModel client: aClient parser: aParser walker: aWalker [
  model := aModel.
  client := aClient.
  parser := aParser.
  walker := aWalker.
  ^ self
]

{ #category : 'accessing' }
SmallChatFamixImporter >> parser [ ^ parser
]

{ #category : 'accessing' }
SmallChatFamixImporter >> walker [ ^ walker
]

Class {
	#name : 'SmallChatLSPServerCapabilities',
	#superclass : 'Object',
	#instVars : [
		'capabilities'
	],
	#category : 'SmallChat-LSP',
	#package : 'SmallChat-LSP'
}

{ #category : 'instance creation' }
SmallChatLSPServerCapabilities class >> fromInitializeResult: aResultDictionary [
	"Build a capabilities value object from the initialize response's result."
	^ self new capabilities: (aResultDictionary at: 'capabilities' ifAbsent: [ Dictionary new ])
]

{ #category : 'querying' }
SmallChatLSPServerCapabilities >> advertisedCodeActionKinds [
	"Return the list of kinds the codeAction provider advertises; empty if
	 codeAction is unsupported or didn't declare specific kinds."
	| provider |
	provider := capabilities at: 'codeActionProvider' ifAbsent: [ ^ #() ].
	provider == false ifTrue: [ ^ #() ].
	(provider isKindOf: Dictionary) ifFalse: [ ^ #() ].
	^ provider at: 'codeActionKinds' ifAbsent: [ #() ]
]

{ #category : 'accessing' }
SmallChatLSPServerCapabilities >> capabilities [
	^ capabilities
]

{ #category : 'accessing' }
SmallChatLSPServerCapabilities >> capabilities: aDictionary [
	capabilities := aDictionary.
	^ self
]

{ #category : 'querying' }
SmallChatLSPServerCapabilities >> isEnabled: aKey [
	"An LSP capability is enabled when present and not literally false. The
	 options-dict form counts as enabled (the dict carries the options)."
	| v |
	v := capabilities at: aKey ifAbsent: [ ^ false ].
	v == false ifTrue: [ ^ false ].
	^ v notNil
]

{ #category : 'querying' }
SmallChatLSPServerCapabilities >> supportsCodeActionKind: aKindString [
	"A server supports aKindString if any advertised kind is a dotted prefix
	 of it. 'refactor.extract.function' matches advertised 'refactor.extract'
	 because the server exposes the broader family."
	| kinds |
	kinds := self advertisedCodeActionKinds.
	^ kinds anySatisfy: [ :advertised |
		advertised = aKindString
			or: [ aKindString beginsWith: advertised , '.' ] ]
]

{ #category : 'querying' }
SmallChatLSPServerCapabilities >> supportsDefinition [
	^ self isEnabled: 'definitionProvider'
]

{ #category : 'querying' }
SmallChatLSPServerCapabilities >> supportsDocumentSymbol [
	^ self isEnabled: 'documentSymbolProvider'
]

{ #category : 'querying' }
SmallChatLSPServerCapabilities >> supportsHover [
	^ self isEnabled: 'hoverProvider'
]

{ #category : 'querying' }
SmallChatLSPServerCapabilities >> supportsReferences [
	^ self isEnabled: 'referencesProvider'
]

{ #category : 'querying' }
SmallChatLSPServerCapabilities >> supportsRename [
	^ self isEnabled: 'renameProvider'
]

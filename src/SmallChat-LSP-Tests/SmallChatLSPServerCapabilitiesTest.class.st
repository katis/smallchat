Class {
	#name : 'SmallChatLSPServerCapabilitiesTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-LSP-Tests',
	#package : 'SmallChat-LSP-Tests'
}

{ #category : 'tests' }
SmallChatLSPServerCapabilitiesTest >> testFromInitializeResultExtractsCoreCapabilities [
	"LSP server capabilities can be either a boolean true or an options-dict;
	 both count as enabled. The value object hides that distinction."
	| initResult caps |
	initResult := Dictionary new
		at: 'capabilities' put: (Dictionary new
			at: 'hoverProvider' put: true;
			at: 'definitionProvider' put: true;
			at: 'referencesProvider' put: true;
			at: 'renameProvider' put: (Dictionary new at: 'prepareProvider' put: true; yourself);
			at: 'documentSymbolProvider' put: true;
			yourself);
		yourself.
	caps := SmallChatLSPServerCapabilities fromInitializeResult: initResult.
	self assert: caps supportsHover.
	self assert: caps supportsDefinition.
	self assert: caps supportsReferences.
	self assert: caps supportsRename.
	self assert: caps supportsDocumentSymbol
]

{ #category : 'tests' }
SmallChatLSPServerCapabilitiesTest >> testMissingCapabilityIsUnsupported [
	"Absence or explicit false means unsupported."
	| caps |
	caps := SmallChatLSPServerCapabilities fromInitializeResult: (Dictionary new
		at: 'capabilities' put: (Dictionary new
			at: 'hoverProvider' put: false;
			yourself);
		yourself).
	self deny: caps supportsHover.
	self deny: caps supportsRename.
	self deny: caps supportsDefinition
]

{ #category : 'tests' }
SmallChatLSPServerCapabilitiesTest >> testSupportsCodeActionKindPrefixMatch [
	"LSP codeAction kinds form a dotted hierarchy. A server advertising
	 refactor.extract supports any more-specific kind below it."
	| caps |
	caps := SmallChatLSPServerCapabilities fromInitializeResult: (Dictionary new
		at: 'capabilities' put: (Dictionary new
			at: 'codeActionProvider' put: (Dictionary new
				at: 'codeActionKinds' put: #('quickfix' 'refactor.extract');
				yourself);
			yourself);
		yourself).
	self assert: (caps supportsCodeActionKind: 'refactor.extract').
	self assert: (caps supportsCodeActionKind: 'refactor.extract.function').
	self assert: (caps supportsCodeActionKind: 'quickfix').
	self deny: (caps supportsCodeActionKind: 'refactor.rewrite').
	self deny: (caps supportsCodeActionKind: 'source')
]

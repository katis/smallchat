Class {
	#name : 'SmallChatLMCapabilityCatalogTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatLMCapabilityCatalogTest >> testToolSchemasFilteredByWorkspaceKind [
	"A catalog parameterised with a TS workspace must only include capabilities
	 whose supportedWorkspaces lists #ts AND whose isLmFacing returns true.
	 The session is bound to one workspace at construction, so workspace.* tools
	 (list/attach-ts/detach) are dead weight in the LM catalog -- they are
	 transport-facing only (MCP) and filtered out for both Pharo and TS chats."
	| tsCatalog pharoCatalog tsNames pharoNames |
	tsCatalog := SmallChatLMCapabilityCatalog forWorkspace: SmallChatTsWorkspace new.
	pharoCatalog := SmallChatLMCapabilityCatalog forWorkspace: SmallChatPharoWorkspace default.
	tsNames := (tsCatalog toolSchemas collect: [ :s | (s at: 'function') at: 'name' ]) asArray.
	pharoNames := (pharoCatalog toolSchemas collect: [ :s | (s at: 'function') at: 'name' ]) asArray.
	self assert: (tsNames includes: 'eval.smalltalk').
	self deny: (tsNames includes: 'debug.sessions').
	self deny: (tsNames includes: 'vcs.status').
	self deny: (tsNames includes: 'workspace.list').
	self deny: (tsNames includes: 'workspace.attach-ts').
	self deny: (tsNames includes: 'workspace.detach').
	self assert: (pharoNames includes: 'eval.smalltalk').
	self assert: (pharoNames includes: 'debug.sessions').
	self assert: (pharoNames includes: 'vcs.status').
	self deny: (pharoNames includes: 'workspace.list').
	self deny: (pharoNames includes: 'workspace.attach-ts').
	self deny: (pharoNames includes: 'workspace.detach')
]

{ #category : 'tests' }
SmallChatLMCapabilityCatalogTest >> testToolSchemasIncludesEvalSmalltalk [
	"The catalog emits one OpenAI-function schema per non-fixture capability.
	 eval.smalltalk is the obvious smoke test -- it's the most-used capability."
	| schemas evalSchema fn |
	schemas := SmallChatLMCapabilityCatalog default toolSchemas.
	evalSchema := schemas detect: [ :s | ((s at: 'function') at: 'name') = 'eval.smalltalk' ].
	self assert: (evalSchema at: 'type') equals: 'function'.
	fn := evalSchema at: 'function'.
	self assert: (fn at: 'name') equals: 'eval.smalltalk'.
	self assert: (fn at: 'description') isString.
	self assert: ((fn at: 'parameters') at: 'type') equals: 'object'
]

{ #category : 'tests' }
SmallChatLMCapabilityCatalogTest >> testToolSchemasOmitsTestFixtures [
	"Test fixture capabilities (#isTestFixture true) must never reach the LM."
	| names |
	names := (SmallChatLMCapabilityCatalog default toolSchemas
		collect: [ :s | (s at: 'function') at: 'name' ]) asArray.
	self assert: (names noneSatisfy: [ :n | n beginsWith: 'test.fake.' ])
]

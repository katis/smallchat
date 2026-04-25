Class {
	#name : 'SmallChatLMCapabilityCatalogTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

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

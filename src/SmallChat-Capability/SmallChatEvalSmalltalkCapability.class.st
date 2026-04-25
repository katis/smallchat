Class {
	#name : 'SmallChatEvalSmalltalkCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatEvalSmalltalkCapability class >> capabilityName [ ^ 'eval.smalltalk'
]

{ #category : 'metadata' }
SmallChatEvalSmalltalkCapability class >> description [
	^ 'Evaluate a Smalltalk expression in the running Pharo image and return its printString. Uncaught exceptions land in a captured debug session (see debug_* tools). Use for reading state, invoking methods, or running one-shot scripts.'
]

{ #category : 'metadata' }
SmallChatEvalSmalltalkCapability class >> mcpAliases [ ^ #('evaluate')
]

{ #category : 'execution' }
SmallChatEvalSmalltalkCapability class >> run: aCapabilityCall [
	"Migrated from SmallChatEvaluateTool>>run:. Outcome key #result -> text;
	 #debugSession -> debugSession variant."
	| code outcome |
	code := aCapabilityCall arguments at: 'code'.
	outcome := SmallChatDebugEvaluator evaluate: code.
	outcome key = #result ifTrue: [ ^ SmallChatCapabilityResult text: outcome value ].
	outcome key = #debugSession ifTrue: [ ^ SmallChatCapabilityResult debugSession: outcome value ].
	self error: 'Unexpected evaluator outcome: ' , outcome printString
]

{ #category : 'metadata' }
SmallChatEvalSmalltalkCapability class >> schema [
	^ SmallChatCapabilitySchema empty
		string: 'code'
		required: true
		description: 'Smalltalk expression to evaluate. Example: "Smalltalk globals size" or "3 + 4 factorial"'
]

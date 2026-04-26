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
	^ 'Evaluate a Smalltalk expression in the running Pharo image and return its printString. The image is shared across all bound workspaces; use SmallChatNav (Pharo workspaces) or SmallChatTsNav (TS workspaces) for navigation -- the system prompt names the right helper. Uncaught exceptions land in a captured debug session (see debug_* tools, Pharo only). Use for reading state, invoking methods, or running one-shot scripts.'
]

{ #category : 'execution' }
SmallChatEvalSmalltalkCapability class >> run: aCapabilityCall [
	"Bind SmallChatTsNav currentWorkspace: to the call's workspace for the
	 duration of the eval so SmallChatTsNav selectors invoked from the eval
	 body resolve against the right workspace. Restored to nil in #ensure:.
	 SmallChatTsNav is looked up reflectively so SmallChat-Capability does
	 not grow a compile-time dependency on the TsNav package."
	| code outcome tsNav |
	code := aCapabilityCall arguments at: 'code'.
	tsNav := Smalltalk globals at: #SmallChatTsNav ifAbsent: [ nil ].
	tsNav ifNotNil: [ tsNav currentWorkspace: aCapabilityCall workspace ].
	outcome := [ SmallChatDebugEvaluator evaluate: code ]
		ensure: [ tsNav ifNotNil: [ tsNav currentWorkspace: nil ] ].
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

{ #category : 'metadata' }
SmallChatEvalSmalltalkCapability class >> supportedWorkspaces [
	"The image is shared across all bound workspaces; what differs is which
	 in-image nav helper the agent reaches for. Allow eval.smalltalk in any
	 workspace and let the workspace-specific system prompt steer the agent
	 towards SmallChatNav (Pharo) or SmallChatTsNav (TS)."
	^ #(#pharo #ts)
]

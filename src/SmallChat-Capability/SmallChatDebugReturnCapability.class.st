Class {
	#name : 'SmallChatDebugReturnCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatDebugReturnCapability class >> capabilityName [ ^ 'debug.return'
]

{ #category : 'metadata' }
SmallChatDebugReturnCapability class >> description [
	^ 'Resume a captured debugger session, substituting the value of `expression` for the signalling expression. If the resumed code completes, returns the final result. If it raises again, returns a new debugSession.'
]

{ #category : 'metadata' }
SmallChatDebugReturnCapability class >> mcpAliases [ ^ #('debug_return')
]

{ #category : 'execution' }
SmallChatDebugReturnCapability class >> run: aCapabilityCall [
	| args sid expr session value outcome |
	args := aCapabilityCall arguments.
	sid := args at: 'sessionId'.
	expr := args at: 'expression'.
	session := SmallChatDebugSessionRegistry default at: sid.
	session stepped ifTrue: [
		^ self error: 'debug_return is not valid on a stepped session (no live signalling expression to substitute). Use debug_proceed to continue, or debug_terminate to drop.' ].
	value := OpalCompiler new source: expr; evaluate.
	outcome := SmallChatDebugEvaluator resume: session with: value.
	outcome key = #result ifTrue: [ ^ SmallChatCapabilityResult text: outcome value ].
	outcome key = #debugSession ifTrue: [ ^ SmallChatCapabilityResult debugSession: outcome value ].
	self error: 'Unexpected resume outcome: ' , outcome printString
]

{ #category : 'metadata' }
SmallChatDebugReturnCapability class >> schema [
	^ SmallChatCapabilitySchema empty
		string: 'sessionId' required: true description: 'Debug session id returned by evaluate/run_tests.';
		string: 'expression' required: true description: 'Smalltalk expression. Its value substitutes for the signalling expression.'
]

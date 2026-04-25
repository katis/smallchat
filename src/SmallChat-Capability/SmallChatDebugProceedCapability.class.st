Class {
	#name : 'SmallChatDebugProceedCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatDebugProceedCapability class >> capabilityName [ ^ 'debug.proceed'
]

{ #category : 'metadata' }
SmallChatDebugProceedCapability class >> description [
	^ 'Resume a captured debugger session without substituting a value. Equivalent to debug_return nil -- the signalling expression evaluates to nil, execution continues.'
]

{ #category : 'metadata' }
SmallChatDebugProceedCapability class >> mcpAliases [ ^ #('debug_proceed')
]

{ #category : 'execution' }
SmallChatDebugProceedCapability class >> run: aCapabilityCall [
	| sid session outcome |
	sid := aCapabilityCall arguments at: 'sessionId'.
	session := SmallChatDebugSessionRegistry default at: sid.
	outcome := SmallChatDebugEvaluator resume: session with: nil.
	outcome key = #result ifTrue: [ ^ SmallChatCapabilityResult text: outcome value ].
	outcome key = #debugSession ifTrue: [ ^ SmallChatCapabilityResult debugSession: outcome value ].
	self error: 'Unexpected proceed outcome: ' , outcome printString
]

{ #category : 'metadata' }
SmallChatDebugProceedCapability class >> schema [
	^ SmallChatCapabilitySchema empty
		string: 'sessionId' required: true description: 'Captured session id.'
]

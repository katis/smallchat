Class {
	#name : 'SmallChatDebugStackCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatDebugStackCapability class >> capabilityName [ ^ 'debug.stack'
]

{ #category : 'metadata' }
SmallChatDebugStackCapability class >> description [
	^ 'Return a compact stack summary for a captured debugger session: up to `limit` frames (default 20), each with index, receiverClass, selector.'
]

{ #category : 'metadata' }
SmallChatDebugStackCapability class >> mcpAliases [ ^ #('debug_stack')
]

{ #category : 'execution' }
SmallChatDebugStackCapability class >> run: aCapabilityCall [
	| args sid limit session stack frames |
	args := aCapabilityCall arguments.
	sid := args at: 'sessionId'.
	limit := args at: 'limit' ifAbsent: [ 20 ].
	session := SmallChatDebugSessionRegistry default at: sid.
	stack := [ session debugSession stack ] on: Error do: [ :_ | #() ].
	frames := ((stack first: (limit min: stack size)) withIndexCollect: [ :ctx :i |
		Dictionary new
			at: 'index' put: i - 1;
			at: 'receiverClass' put: ([ ctx receiver class name asString ] on: Error do: [ :_ | '<unprintable>' ]);
			at: 'selector' put: ([ ctx method selector asString ] on: Error do: [ :_ | '<unprintable>' ]);
			yourself ]) asArray.
	^ SmallChatCapabilityResult text: (STONJSON toString: (Dictionary new
		at: 'frames' put: frames;
		yourself))
]

{ #category : 'metadata' }
SmallChatDebugStackCapability class >> schema [
	^ SmallChatCapabilitySchema empty
		string: 'sessionId' required: true description: 'Captured session id.';
		integer: 'limit' required: false description: 'Maximum frames to return. Default 20.'
]

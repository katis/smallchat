Class {
	#name : 'SmallChatDebugSessionsCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatDebugSessionsCapability class >> capabilityName [ ^ 'debug.sessions'
]

{ #category : 'metadata' }
SmallChatDebugSessionsCapability class >> description [ ^ 'List active captured debugger sessions (id, exception class, message, top frame, age).'
]

{ #category : 'metadata' }
SmallChatDebugSessionsCapability class >> mcpAliases [ ^ #('debug_sessions')
]

{ #category : 'execution' }
SmallChatDebugSessionsCapability class >> run: aCapabilityCall [
	| sessions items |
	sessions := SmallChatDebugSessionRegistry default sessionsSnapshot.
	items := sessions collect: [ :s |
		Dictionary new
			at: 'id' put: s id;
			at: 'exceptionClass' put: s exception class name asString;
			at: 'messageText' put: (s exception messageText ifNil: [ '' ]);
			at: 'topFrame' put: ([ s debugSession interruptedContext printString ]
				on: Error do: [ :_ | '<unprintable>' ]);
			at: 'createdAtMs' put: s createdAtMs;
			yourself ].
	^ SmallChatCapabilityResult text: (STONJSON toString: (Dictionary new
		at: 'sessions' put: items asArray;
		yourself))
]

{ #category : 'metadata' }
SmallChatDebugSessionsCapability class >> schema [ ^ SmallChatCapabilitySchema empty
]

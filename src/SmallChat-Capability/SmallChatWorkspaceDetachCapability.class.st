Class {
	#name : 'SmallChatWorkspaceDetachCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatWorkspaceDetachCapability class >> capabilityName [ ^ 'workspace.detach'
]

{ #category : 'metadata' }
SmallChatWorkspaceDetachCapability class >> description [ ^ 'Detach a TS workspace by name. Shuts down its LSP client and removes it from the mounted list. Refuses to detach the Pharo workspace.'
]

{ #category : 'private' }
SmallChatWorkspaceDetachCapability class >> errorResult: aString [ ^ SmallChatCapabilityResult error: aString
]

{ #category : 'execution' }
SmallChatWorkspaceDetachCapability class >> run: aCapabilityCall [
	| name registry ws |
	name := aCapabilityCall arguments at: 'name' ifAbsent: [ ^ self errorResult: 'name is required' ].
	(name isString and: [ name isEmpty not ])
		ifFalse: [ ^ self errorResult: 'name must be a non-empty string' ].
	registry := SmallChatCapabilityRegistry default.
	ws := registry mountedWorkspaceNamed: name.
	ws ifNil: [ ^ self errorResult: 'No workspace named ' , name printString , ' is mounted.' ].
	ws kind = #pharo ifTrue: [ ^ self errorResult: 'The pharo workspace cannot be detached.' ].
	[ ws shutdown ] on: Error do: [ :_ | nil ].
	registry unmountWorkspace: ws.
	^ SmallChatCapabilityResult text: (STONJSON toString: (Dictionary new
		at: 'detached' put: name;
		at: 'remaining' put: registry mountedWorkspaces size;
		yourself))
]

{ #category : 'metadata' }
SmallChatWorkspaceDetachCapability class >> schema [
	^ SmallChatCapabilitySchema empty
		string: 'name'
		required: true
		description: 'Name of the workspace to detach. Must match a mounted non-Pharo workspace.'
]

{ #category : 'metadata' }
SmallChatWorkspaceDetachCapability class >> supportedWorkspaces [ ^ #(#pharo #ts)
]

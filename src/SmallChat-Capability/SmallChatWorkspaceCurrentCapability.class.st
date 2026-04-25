Class {
	#name : 'SmallChatWorkspaceCurrentCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatWorkspaceCurrentCapability class >> capabilityName [ ^ 'workspace.current'
]

{ #category : 'metadata' }
SmallChatWorkspaceCurrentCapability class >> description [ ^ 'Describe the workspace this session is currently dispatching to. Returns its name, kind, and kind-specific metadata.'
]

{ #category : 'execution' }
SmallChatWorkspaceCurrentCapability class >> run: aCapabilityCall [
	| ws |
	ws := aCapabilityCall workspace.
	^ SmallChatCapabilityResult text: (STONJSON toString: ws describeAsDict)
]

{ #category : 'metadata' }
SmallChatWorkspaceCurrentCapability class >> schema [ ^ SmallChatCapabilitySchema empty
]

{ #category : 'metadata' }
SmallChatWorkspaceCurrentCapability class >> supportedWorkspaces [ ^ #(#pharo #ts)
]

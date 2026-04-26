Class {
	#name : 'SmallChatWorkspaceListCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatWorkspaceListCapability class >> capabilityName [ ^ 'workspace.list'
]

{ #category : 'metadata' }
SmallChatWorkspaceListCapability class >> description [ ^ 'List all workspaces mounted on this session. Returns {current, mounted[]}; current names the workspace dispatch defaults to.'
]

{ #category : 'metadata' }
SmallChatWorkspaceListCapability class >> isLmFacing [
	"Workspace mount/list/detach are transport-facing only -- the in-image
	 agent cannot change its bound workspace mid-session, so exposing these
	 to the LM only invites confused calls. MCP still sees them."
	^ false
]

{ #category : 'execution' }
SmallChatWorkspaceListCapability class >> run: aCapabilityCall [
	| registry mounted |
	registry := SmallChatCapabilityRegistry default.
	mounted := (registry mountedWorkspaces collect: [ :ws | ws describeAsDict ]) asArray.
	^ SmallChatCapabilityResult text: (STONJSON toString: (Dictionary new
		at: 'current' put: registry currentWorkspace describeAsDict;
		at: 'mounted' put: mounted;
		yourself))
]

{ #category : 'metadata' }
SmallChatWorkspaceListCapability class >> schema [ ^ SmallChatCapabilitySchema empty
]

{ #category : 'metadata' }
SmallChatWorkspaceListCapability class >> supportedWorkspaces [ ^ #(#pharo #ts)
]

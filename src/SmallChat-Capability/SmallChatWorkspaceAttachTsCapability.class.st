Class {
	#name : 'SmallChatWorkspaceAttachTsCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatWorkspaceAttachTsCapability class >> capabilityName [ ^ 'workspace.attach-ts'
]

{ #category : 'metadata' }
SmallChatWorkspaceAttachTsCapability class >> description [ ^ 'Attach a TypeScript / JavaScript / CSS Modules project as a workspace. Launches a tsgo LSP client rooted at path. Idempotent on canonical path -- a second attach of the same path returns the existing workspace describe.'
]

{ #category : 'private' }
SmallChatWorkspaceAttachTsCapability class >> errorResult: aString [
	^ SmallChatCapabilityResult error: aString
]

{ #category : 'metadata' }
SmallChatWorkspaceAttachTsCapability class >> isLmFacing [
	"Workspace mount/list/detach are transport-facing only -- the in-image
	 agent cannot change its bound workspace mid-session, so exposing these
	 to the LM only invites confused calls. MCP still sees them."
	^ false
]

{ #category : 'execution' }
SmallChatWorkspaceAttachTsCapability class >> run: aCapabilityCall [
	"Validate args, canonicalise path, refuse relative; idempotent on path;
	 unique on name; mount and return describe."
	| args path name registry ref existing ws |
	args := aCapabilityCall arguments.
	path := args at: 'path' ifAbsent: [ ^ self errorResult: 'path is required' ].
	(path isString and: [ path isEmpty not ]) ifFalse: [ ^ self errorResult: 'path must be a non-empty string' ].
	name := args at: 'name' ifAbsent: [ nil ].
	ref := [ SmallChatTsWorkspace canonicalise: path ] on: Error do: [ :e | ^ self errorResult: e messageText ].
	registry := SmallChatCapabilityRegistry default.
	existing := registry mountedWorkspaceForPath: ref.
	existing ifNotNil: [ ^ SmallChatCapabilityResult text: (STONJSON toString: existing describeAsDict) ].
	"Path is novel; verify name uniqueness."
	name := name ifNil: [ ref basename ].
	(registry mountedWorkspaceNamed: name) ifNotNil: [
		^ self errorResult: 'A workspace named ' , name printString , ' is already mounted. Pass an explicit name to disambiguate.' ].
	ws := [ SmallChatTsWorkspace attachAt: path name: name ]
		on: Error do: [ :e | ^ self errorResult: e messageText ].
	registry mountWorkspace: ws.
	^ SmallChatCapabilityResult text: (STONJSON toString: ws describeAsDict)
]

{ #category : 'metadata' }
SmallChatWorkspaceAttachTsCapability class >> schema [
	^ (SmallChatCapabilitySchema empty
		string: 'path'
		required: true
		description: 'Absolute path to the project root. Relative paths are refused.')
		string: 'name'
		required: false
		description: 'Workspace identifier. Defaults to the canonical path basename. Must be unique across mounted workspaces.'
]

{ #category : 'metadata' }
SmallChatWorkspaceAttachTsCapability class >> supportedWorkspaces [ ^ #(#pharo #ts)
]

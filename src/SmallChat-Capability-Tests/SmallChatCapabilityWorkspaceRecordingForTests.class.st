Class {
	#name : 'SmallChatCapabilityWorkspaceRecordingForTests',
	#superclass : 'SmallChatCapability',
	#classVars : [
		'LastSeenWorkspace'
	],
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'metadata' }
SmallChatCapabilityWorkspaceRecordingForTests class >> capabilityName [ ^ 'test.workspace.recording'
]

{ #category : 'metadata' }
SmallChatCapabilityWorkspaceRecordingForTests class >> description [ ^ 'Records the workspace seen on dispatch (test fixture).'
]

{ #category : 'metadata' }
SmallChatCapabilityWorkspaceRecordingForTests class >> isTestFixture [ ^ true
]

{ #category : 'metadata' }
SmallChatCapabilityWorkspaceRecordingForTests class >> lastSeenWorkspace [ ^ LastSeenWorkspace
]

{ #category : 'metadata' }
SmallChatCapabilityWorkspaceRecordingForTests class >> reset [ LastSeenWorkspace := nil
]

{ #category : 'execution' }
SmallChatCapabilityWorkspaceRecordingForTests class >> run: aCapabilityCall [
	LastSeenWorkspace := aCapabilityCall workspace.
	^ SmallChatCapabilityResult text: 'ok'
]

{ #category : 'metadata' }
SmallChatCapabilityWorkspaceRecordingForTests class >> schema [ ^ SmallChatCapabilitySchema empty
]

{ #category : 'metadata' }
SmallChatCapabilityWorkspaceRecordingForTests class >> supportedWorkspaces [ ^ #(#pharo #ts)
]

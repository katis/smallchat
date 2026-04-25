Class {
	#name : 'SmallChatVcsCommitCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatVcsCommitCapability class >> capabilityName [ ^ 'vcs.commit'
]

{ #category : 'private' }
SmallChatVcsCommitCapability class >> changeCount: aRepo [
	| count walker skip |
	count := 0.
	skip := #('IceNoModification' 'IceEmptyNode').
	walker := nil.
	walker := [ :node |
		(skip includes: node value class name) ifFalse: [ count := count + 1 ].
		([ node children ] on: Error do: [ :_ | #() ])
			do: [ :c | walker value: c ] ].
	[ walker value: aRepo workingCopyDiff tree ]
		on: Error do: [ :_ | ].
	^ count
]

{ #category : 'private' }
SmallChatVcsCommitCapability class >> commit: aRepo with: aMessage [
	| diff |
	diff := aRepo workingCopyDiff.
	^ aRepo workingCopy
		commitChanges: diff
		withMessage: aMessage
]

{ #category : 'metadata' }
SmallChatVcsCommitCapability class >> description [
	^ 'Commit the smallchat working copy via Iceberg. Refreshes Tonel from in-image state, then commits. Uses git config from ~/.gitconfig for author/email. NO green-guard -- caller is responsible for verifying tests pass (in-image AND from `just test`) before calling.'
]

{ #category : 'private' }
SmallChatVcsCommitCapability class >> errorResult: aString [
	"vcs.commit historically returns errors as text JSON (legacy contract)."
	^ SmallChatCapabilityResult text: (STONJSON toString: (Dictionary new
		at: 'error' put: aString;
		yourself))
]

{ #category : 'metadata' }
SmallChatVcsCommitCapability class >> mcpAliases [ ^ #('commit')
]

{ #category : 'private' }
SmallChatVcsCommitCapability class >> repository [
	| iceRepo |
	iceRepo := Smalltalk globals at: #IceRepository ifAbsent: [ ^ nil ].
	^ iceRepo registry
		detect: [ :r | ([ r name ] on: Error do: [ :_ | nil ]) = 'smallchat' ]
		ifNone: [ nil ]
]

{ #category : 'execution' }
SmallChatVcsCommitCapability class >> run: aCapabilityCall [
	"Migrated from SmallChatCommitTool>>run:."
	| message repo commit changeCount |
	message := aCapabilityCall arguments at: 'message' ifAbsent: [ ^ self errorResult: 'message is required' ].
	(message isString and: [ message isEmpty not ])
		ifFalse: [ ^ self errorResult: 'message must be a non-empty string' ].
	repo := self repository.
	repo ifNil: [ ^ self errorResult: 'No Iceberg repo "smallchat" registered' ].
	[ repo workingCopy refreshDirtyPackages ] on: Error do: [ :_ | ].
	changeCount := self changeCount: repo.
	changeCount = 0 ifTrue: [
		^ self errorResult: 'Nothing to commit. Compile something first.' ].
	commit := [ self commit: repo with: message ]
		on: Error do: [ :e |
			^ self errorResult: 'commit failed: ' , e class name , ' - ' , (e messageText ifNil: [ '' ]) ].
	^ SmallChatCapabilityResult text: (STONJSON toString: (Dictionary new
		at: 'commitId' put: ([ commit id ] on: Error do: [ :_ | '<unknown>' ]);
		at: 'message' put: message;
		at: 'branch' put: ([ repo branchName ] on: Error do: [ :_ | '<unknown>' ]);
		at: 'changesWritten' put: changeCount;
		yourself))
]

{ #category : 'metadata' }
SmallChatVcsCommitCapability class >> schema [
	^ SmallChatCapabilitySchema empty
		string: 'message'
		required: true
		description: 'Commit message. Required.'
]

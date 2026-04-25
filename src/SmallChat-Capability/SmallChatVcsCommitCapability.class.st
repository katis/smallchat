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
	^ 'Commit the current workspace. Pharo: refreshes Tonel from in-image state, then commits via Iceberg (uses ~/.gitconfig). TS: stages everything (git add -A) in the workspace root and commits with message. NO green-guard -- caller is responsible for verifying tests pass before calling. changesWritten counts MC nodes for Pharo, files for TS -- different units.'
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
	"Dispatch to the workspace-kind-appropriate commit path. Pharo uses
	 Iceberg; TS shells out to git via SmallChatVcsTsCommit."
	| message ws kind |
	message := aCapabilityCall arguments at: 'message' ifAbsent: [ ^ self errorResult: 'message is required' ].
	(message isString and: [ message isEmpty not ])
		ifFalse: [ ^ self errorResult: 'message must be a non-empty string' ].
	ws := aCapabilityCall workspace.
	ws ifNil: [ ^ self errorResult: 'No workspace bound to this call' ].
	kind := ws kind.
	kind = #pharo ifTrue: [ ^ self runPharoCommit: message in: ws ].
	kind = #ts ifTrue: [ ^ self runTsCommit: message in: ws ].
	^ self errorResult: 'vcs.commit is not implemented for workspace kind: ' , kind asString
]

{ #category : 'execution' }
SmallChatVcsCommitCapability class >> runPharoCommit: aMessage in: aPharoWorkspace [
	"Iceberg path: refresh, count, commit. Returns SmallChatCapabilityResult."
	| repo commit changeCount |
	repo := self repository.
	repo ifNil: [ ^ self errorResult: 'No Iceberg repo "smallchat" registered' ].
	[ repo workingCopy refreshDirtyPackages ] on: Error do: [ :_ | ].
	changeCount := self changeCount: repo.
	changeCount = 0 ifTrue: [
		^ self errorResult: 'Nothing to commit. Compile something first.' ].
	commit := [ self commit: repo with: aMessage ]
		on: Error do: [ :e |
			^ self errorResult: 'commit failed: ' , e class name , ' - ' , (e messageText ifNil: [ '' ]) ].
	^ SmallChatCapabilityResult text: (STONJSON toString: (Dictionary new
		at: 'commitId' put: ([ commit id ] on: Error do: [ :_ | '<unknown>' ]);
		at: 'message' put: aMessage;
		at: 'branch' put: ([ repo branchName ] on: Error do: [ :_ | '<unknown>' ]);
		at: 'changesWritten' put: changeCount;
		yourself))
]

{ #category : 'execution' }
SmallChatVcsCommitCapability class >> runTsCommit: aMessage in: aTsWorkspace [
	"TS path: shell git in the workspace root via SmallChatVcsTsCommit. The
	 helper returns the same {commitId, message, branch, changesWritten} dict
	 the Pharo path produces, so JSON shape is identical for parity. Note:
	 changesWritten counts files, not Iceberg MC nodes -- different units."
	| dict |
	dict := [ SmallChatVcsTsCommit run: aMessage in: aTsWorkspace path ]
		on: Error do: [ :e | ^ self errorResult: e messageText ].
	^ SmallChatCapabilityResult text: (STONJSON toString: dict)
]

{ #category : 'metadata' }
SmallChatVcsCommitCapability class >> schema [
	^ SmallChatCapabilitySchema empty
		string: 'message'
		required: true
		description: 'Commit message. Required.'
]

{ #category : 'metadata' }
SmallChatVcsCommitCapability class >> supportedWorkspaces [ ^ #(#pharo #ts)
]

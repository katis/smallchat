"
Commit the smallchat working copy via Iceberg.

Refreshes the working copy (so freshly-compiled methods are picked up),
verifies there is something to commit, and runs Iceberg's commit path.
The commit writes Tonel files to src/ on disk and creates a git commit
on the current branch using whatever git author/email is configured
in ~/.gitconfig.

NO automated green-guard. The Red-Green TDD discipline lives in
CLAUDE.md prose -- callers are expected to `run_tests` first AND
`just test` from a shell before invoking `commit`.

Returns JSON with {commitId, message, branch, changesWritten} on
success, or {error, message} on failure (e.g. nothing to commit).
"
Class {
	#name : #SmallChatCommitTool,
	#superclass : #SmallChatTool,
	#category : #'SmallChat-MCP'
}

{ #category : #'accessing - metadata' }
SmallChatCommitTool class >> description [
	^ 'Commit the smallchat working copy via Iceberg. Refreshes Tonel from in-image state, then commits. Uses git config from ~/.gitconfig for author/email. NO green-guard -- caller is responsible for verifying tests pass (in-image AND from `just test`) before calling.'
]

{ #category : #'accessing - metadata' }
SmallChatCommitTool class >> inputSchema [
	^ Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: (Dictionary new
			at: 'message' put: (Dictionary new
				at: 'type' put: 'string';
				at: 'description' put: 'Commit message. Required.';
				yourself);
			yourself);
		at: 'required' put: #('message');
		yourself
]

{ #category : #'accessing - metadata' }
SmallChatCommitTool class >> toolName [ ^ 'commit' ]

{ #category : #execution }
SmallChatCommitTool >> changeCount: aRepo [
	"Count real (non-placeholder) leaf changes in the working-copy diff."
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

{ #category : #execution }
SmallChatCommitTool >> commit: aRepo with: aMessage [
	"Iceberg commits via workingCopy. The diff to commit is everything
	 currently dirty; we don't allow partial staging."
	| diff |
	diff := aRepo workingCopyDiff.
	^ aRepo workingCopy
		commitChanges: diff
		withMessage: aMessage
]

{ #category : #execution }
SmallChatCommitTool >> errorResult: aString [
	^ STONJSON toString: (Dictionary new
		at: 'error' put: aString;
		yourself)
]

{ #category : #execution }
SmallChatCommitTool >> repository [
	| iceRepo |
	iceRepo := Smalltalk globals at: #IceRepository ifAbsent: [ ^ nil ].
	^ iceRepo registry
		detect: [ :r | ([ r name ] on: Error do: [ :_ | nil ]) = 'smallchat' ]
		ifNone: [ nil ]
]

{ #category : #execution }
SmallChatCommitTool >> run: args [
	| repo message commit changeCount |
	message := args at: 'message' ifAbsent: [ ^ self errorResult: 'message is required' ].
	(message isString and: [ message isEmpty not ])
		ifFalse: [ ^ self errorResult: 'message must be a non-empty string' ].

	repo := self repository.
	repo ifNil: [ ^ self errorResult: 'No Iceberg repo "smallchat" registered' ].

	"Refresh so freshly-compiled methods reach the working copy diff."
	[ repo workingCopy refreshDirtyPackages ] on: Error do: [ :_ | ].

	changeCount := self changeCount: repo.
	changeCount = 0 ifTrue: [
		^ self errorResult: 'Nothing to commit. Compile something first.' ].

	commit := [ self commit: repo with: message ]
		on: Error do: [ :e |
			^ self errorResult: 'commit failed: ', e class name, ' - ', (e messageText ifNil: [ '' ]) ].

	^ STONJSON toString: (Dictionary new
		at: 'commitId' put: ([ commit id ] on: Error do: [ :_ | '<unknown>' ]);
		at: 'message' put: message;
		at: 'branch' put: ([ repo branchName ] on: Error do: [ :_ | '<unknown>' ]);
		at: 'changesWritten' put: changeCount;
		yourself)
]

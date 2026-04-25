Class {
	#name : 'SmallChatVcsCommitFilesCapability',
	#superclass : 'SmallChatCapability',
	#classInstVars : [
		'gitRunnerOverride',
		'resyncerOverride'
	],
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatVcsCommitFilesCapability class >> capabilityName [ ^ 'vcs.commit-files'
]

{ #category : 'private' }
SmallChatVcsCommitFilesCapability class >> describeProcessResult: aDict [
	| parts stderr stdout |
	parts := OrderedCollection new.
	stderr := (aDict at: 'stderr' ifAbsent: [ '' ]) ifNil: [ '' ].
	stdout := (aDict at: 'stdout' ifAbsent: [ '' ]) ifNil: [ '' ].
	stderr isEmpty ifFalse: [ parts add: stderr trimBoth ].
	stdout isEmpty ifFalse: [ parts add: stdout trimBoth ].
	^ parts isEmpty
		ifTrue: [ 'exit=' , (aDict at: 'exitCode') printString ]
		ifFalse: [ String streamContents: [ :s | parts do: [ :p | s nextPutAll: p ] separatedBy: [ s << ' | ' ] ] ]
]

{ #category : 'metadata' }
SmallChatVcsCommitFilesCapability class >> description [
	^ 'Commit hand-edited files on disk (non-Iceberg-managed: CLAUDE.md, justfile, bin/*, lib/*.st, baselines, .mcp.json, etc.) via shell git, then re-anchor the in-image Iceberg working copy to the new HEAD. Without this, the next `commit` via Iceberg raises IceWorkingCopyDesyncronized because the in-image referenceCommit is stale. Do NOT use for Pharo source under src/SmallChat*; those go through `evaluate` + `commit`.'
]

{ #category : 'private' }
SmallChatVcsCommitFilesCapability class >> errorResult: aString [
	^ SmallChatCapabilityResult text: (STONJSON toString: (Dictionary new
		at: 'error' put: aString;
		yourself))
]

{ #category : 'private' }
SmallChatVcsCommitFilesCapability class >> gitRunner [
	^ gitRunnerOverride ifNil: [ [ :argv | self runGitProcess: argv ] ]
]

{ #category : 'test seam' }
SmallChatVcsCommitFilesCapability class >> gitRunner: aBlock [
	"Test seam: replace the git invocation with a deterministic block."
	gitRunnerOverride := aBlock
]

{ #category : 'private' }
SmallChatVcsCommitFilesCapability class >> reanchorIceberg [
	"Rebind the smallchat working copy to the on-disk HEAD."
	| repo wc head |
	repo := self repository
		ifNil: [ ^ self error: 'no smallchat Iceberg repo registered' ].
	wc := repo workingCopy.
	head := repo headCommit.
	wc referenceCommit: head.
	wc refreshDirtyPackages.
	^ [ head id ] on: Error do: [ :_ | '<unknown>' ]
]

{ #category : 'private' }
SmallChatVcsCommitFilesCapability class >> repository [
	| iceRepo |
	iceRepo := Smalltalk globals at: #IceRepository ifAbsent: [ ^ nil ].
	^ iceRepo registry
		detect: [ :r | ([ r name ] on: Error do: [ :_ | nil ]) = 'smallchat' ]
		ifNone: [ nil ]
]

{ #category : 'test seam' }
SmallChatVcsCommitFilesCapability class >> resetTestSeams [
	"Drop both injection points so subsequent runs use the live behaviour."
	gitRunnerOverride := nil.
	resyncerOverride := nil
]

{ #category : 'private' }
SmallChatVcsCommitFilesCapability class >> resyncer [
	^ resyncerOverride ifNil: [ [ self reanchorIceberg ] ]
]

{ #category : 'test seam' }
SmallChatVcsCommitFilesCapability class >> resyncer: aBlock [
	"Test seam: replace the Iceberg re-anchor with a deterministic block."
	resyncerOverride := aBlock
]

{ #category : 'execution' }
SmallChatVcsCommitFilesCapability class >> run: aCapabilityCall [
	"Migrated from SmallChatCommitFilesTool>>run:."
	| args paths message commitId addRes commitRes |
	args := aCapabilityCall arguments.
	paths := args at: 'paths' ifAbsent: [ ^ self errorResult: 'paths is required' ].
	message := args at: 'message' ifAbsent: [ ^ self errorResult: 'message is required' ].
	(paths isCollection and: [ paths isString not ]) ifFalse: [
		^ self errorResult: 'paths must be a non-empty array of strings' ].
	paths isEmpty ifTrue: [
		^ self errorResult: 'paths must be a non-empty array of strings' ].
	(paths allSatisfy: [ :p | p isString and: [ p isEmpty not ] ]) ifFalse: [
		^ self errorResult: 'paths must be a non-empty array of strings' ].
	(message isString and: [ message isEmpty not ]) ifFalse: [
		^ self errorResult: 'message must be a non-empty string' ].
	addRes := self gitRunner value: { 'add'. '--' } , paths asArray.
	(addRes at: 'exitCode') = 0 ifFalse: [
		^ self errorResult: 'git add failed: ' , (self describeProcessResult: addRes) ].
	commitRes := self gitRunner value: { 'commit'. '-m'. message }.
	(commitRes at: 'exitCode') = 0 ifFalse: [
		^ self errorResult: 'git commit failed: ' , (self describeProcessResult: commitRes) ].
	commitId := self resyncer value.
	^ SmallChatCapabilityResult text: (STONJSON toString: (Dictionary new
		at: 'commitId' put: commitId;
		at: 'message' put: message;
		yourself))
]

{ #category : 'private' }
SmallChatVcsCommitFilesCapability class >> runGitProcess: argv [
	| repo repoRoot outFile cmd systemRc stdout rc |
	repo := self repository.
	repo ifNil: [ ^ Dictionary new
		at: 'exitCode' put: -1;
		at: 'stdout' put: '';
		at: 'stderr' put: 'no smallchat Iceberg repo registered; cannot locate working tree';
		yourself ].
	repoRoot := repo location fullName.
	outFile := (FileLocator temp asFileReference / ('smallchat-git-' , UUID new asString , '.log')) fullName.
	cmd := String streamContents: [ :s |
		s << 'cd '. s nextPutAll: (self shellQuote: repoRoot). s << ' && git'.
		argv do: [ :a | s nextPut: Character space. s nextPutAll: (self shellQuote: a) ].
		s << ' > '. s nextPutAll: (self shellQuote: outFile). s << ' 2>&1' ].
	systemRc := LibC system: cmd.
	rc := systemRc = 0 ifTrue: [ 0 ] ifFalse: [ (systemRc bitShift: -8) max: 1 ].
	stdout := [ outFile asFileReference contents ] on: Error do: [ :_ | '' ].
	[ outFile asFileReference ensureDelete ] on: Error do: [ :_ | ].
	^ Dictionary new
		at: 'exitCode' put: rc;
		at: 'stdout' put: (stdout ifNil: [ '' ]);
		at: 'stderr' put: '';
		yourself
]

{ #category : 'metadata' }
SmallChatVcsCommitFilesCapability class >> schema [
	^ SmallChatCapabilitySchema empty
		array: 'paths'
			of: #string
			required: true
			description: 'Repo-relative file paths to stage. Passed to `git add -- <paths>` verbatim, so deletions/renames work if git sees them.';
		string: 'message'
			required: true
			description: 'Commit message. Required.'
]

{ #category : 'private' }
SmallChatVcsCommitFilesCapability class >> shellQuote: aString [
	"POSIX-safe: wrap in single quotes; replace each internal apostrophe."
	| apos bs |
	apos := Character value: 39.
	bs := Character value: 92.
	^ String streamContents: [ :s |
		s nextPut: apos.
		aString do: [ :c |
			c = apos
				ifTrue: [ s nextPut: apos. s nextPut: bs. s nextPut: apos. s nextPut: apos ]
				ifFalse: [ s nextPut: c ] ].
		s nextPut: apos ]
]

Class {
	#name : 'SmallChatCommitFilesToolTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'helpers' }
SmallChatCommitFilesToolTest >> callDispatchPaths: aPaths message: aMessage [
	"Helper -- builds a SmallChatCapabilityCall the capability will accept."
	| dict |
	dict := Dictionary new.
	aPaths ifNotNil: [ dict at: 'paths' put: aPaths ].
	aMessage ifNotNil: [ dict at: 'message' put: aMessage ].
	^ SmallChatCapabilityCall name: 'vcs.commit-files' argumentsJson: (STONJSON toString: dict)
]

{ #category : 'running' }
SmallChatCommitFilesToolTest >> tearDown [
	"Clear class-side test seams so other tests see the live behaviour."
	[ SmallChatVcsCommitFilesCapability resetTestSeams ]
		on: Error do: [ :_ | ].
	super tearDown
]

{ #category : 'tests' }
SmallChatCommitFilesToolTest >> testGitAddFailureAbortsBeforeCommitAndResync [
	| calls resyncCalled result json |
	calls := OrderedCollection new.
	resyncCalled := false.
	SmallChatVcsCommitFilesCapability
		gitRunner: [ :argv |
			calls add: argv asArray.
			Dictionary new
				at: 'exitCode' put: 1;
				at: 'stdout' put: '';
				at: 'stderr' put: 'fatal: pathspec did not match any files';
				yourself ];
		resyncer: [ resyncCalled := true. 'SHOULD-NOT-BE-CALLED' ].
	result := SmallChatVcsCommitFilesCapability
		run: (self callDispatchPaths: #('nope.txt') message: 'x').
	json := STONJSON fromString: result text.
	self assert: (json at: 'error') isString.
	self assert: ((json at: 'error') includesSubstring: 'git add').
	self assert: ((json at: 'error') includesSubstring: 'fatal: pathspec').
	self deny: resyncCalled.
	self assert: calls size equals: 1.
	self assert: calls first first equals: 'add'
]

{ #category : 'tests' }
SmallChatCommitFilesToolTest >> testGitCommitFailureSkipsResync [
	| calls resyncCalled result json |
	calls := OrderedCollection new.
	resyncCalled := false.
	SmallChatVcsCommitFilesCapability
		gitRunner: [ :argv |
			| res |
			calls add: argv asArray.
			res := Dictionary new at: 'stdout' put: ''; at: 'stderr' put: ''; yourself.
			argv first = 'add'
				ifTrue: [ res at: 'exitCode' put: 0 ]
				ifFalse: [ res at: 'exitCode' put: 1. res at: 'stderr' put: 'nothing to commit, working tree clean' ].
			res ];
		resyncer: [ resyncCalled := true. 'SHOULD-NOT-BE-CALLED' ].
	result := SmallChatVcsCommitFilesCapability
		run: (self callDispatchPaths: #('CLAUDE.md') message: 'msg').
	json := STONJSON fromString: result text.
	self assert: (json at: 'error') isString.
	self assert: ((json at: 'error') includesSubstring: 'git commit').
	self assert: ((json at: 'error') includesSubstring: 'nothing to commit').
	self deny: resyncCalled.
	self assert: calls size equals: 2
]

{ #category : 'tests' }
SmallChatCommitFilesToolTest >> testIsRegisteredAsCommitFiles [
	"Now lives on the new transport: tools/list emits commit_files alias plus
	 vcs.commit-files canonical entry."
	| specs spec |
	specs := SmallChatMCPCapabilityTransport new toolSpecs.
	spec := specs detect: [ :s | (s at: 'name') = 'commit_files' ] ifNone: [ nil ].
	self assert: spec notNil.
	self assert: (spec at: 'description') isString.
	self assert: (spec at: 'description') isEmpty not.
	self assert: ((spec at: 'inputSchema') at: 'required') asArray equals: #('paths' 'message')
]

{ #category : 'tests' }
SmallChatCommitFilesToolTest >> testMissingMessageReturnsError [
	| result json |
	SmallChatVcsCommitFilesCapability
		gitRunner: [ :argv | self fail: 'gitRunner must not be called when message missing' ];
		resyncer: [ self fail: 'resyncer must not be called when message missing' ].
	result := SmallChatVcsCommitFilesCapability run: (self callDispatchPaths: #('CLAUDE.md') message: nil).
	json := STONJSON fromString: result text.
	self assert: (json at: 'error') isString.
	self assert: ((json at: 'error') includesSubstring: 'message')
]

{ #category : 'tests' }
SmallChatCommitFilesToolTest >> testMissingPathsReturnsError [
	| result json |
	SmallChatVcsCommitFilesCapability
		gitRunner: [ :argv | self fail: 'gitRunner must not be called when paths missing' ];
		resyncer: [ self fail: 'resyncer must not be called when paths missing' ].
	result := SmallChatVcsCommitFilesCapability run: (self callDispatchPaths: nil message: 'hi').
	json := STONJSON fromString: result text.
	self assert: (json at: 'error') isString.
	self assert: ((json at: 'error') includesSubstring: 'paths')
]

{ #category : 'tests' }
SmallChatCommitFilesToolTest >> testRunsGitAddThenCommitThenResyncs [
	| calls resyncCalled result json |
	calls := OrderedCollection new.
	resyncCalled := false.
	SmallChatVcsCommitFilesCapability
		gitRunner: [ :argv |
			calls add: argv asArray.
			Dictionary new at: 'exitCode' put: 0; at: 'stdout' put: ''; at: 'stderr' put: ''; yourself ];
		resyncer: [ resyncCalled := true. 'deadbeef' ].
	result := SmallChatVcsCommitFilesCapability
		run: (self callDispatchPaths: #('CLAUDE.md' 'lib/foo.st') message: 'docs: tweak').
	json := STONJSON fromString: result text.
	self assert: (json at: 'commitId') equals: 'deadbeef'.
	self assert: resyncCalled.
	self assert: calls size equals: 2.
	self assert: calls first equals: #('add' '--' 'CLAUDE.md' 'lib/foo.st').
	self assert: calls second equals: #('commit' '-m' 'docs: tweak')
]

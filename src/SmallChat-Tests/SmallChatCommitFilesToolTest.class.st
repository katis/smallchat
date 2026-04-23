Class {
	#name : 'SmallChatCommitFilesToolTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatCommitFilesToolTest >> testIsRegisteredAsCommitFiles [
	| registry spec |
	registry := SmallChatToolRegistry default.
	self assert: (registry toolNamed: 'commit_files') class equals: SmallChatCommitFilesTool.
	spec := registry toolSpecs detect: [ :s | (s at: 'name') = 'commit_files' ] ifNone: [ nil ].
	self assert: spec notNil.
	self assert: (spec at: 'description') isString.
	self assert: (spec at: 'description') isEmpty not.
	self assert: ((spec at: 'inputSchema') at: 'required') asArray equals: #('paths' 'message')
]

{ #category : 'tests' }
SmallChatCommitFilesToolTest >> testRunsGitAddThenCommitThenResyncs [
	| tool calls resyncCalled result json |
	tool := SmallChatCommitFilesTool new.
	calls := OrderedCollection new.
	resyncCalled := false.
	tool gitRunner: [ :argv |
		calls add: argv asArray.
		Dictionary new at: 'exitCode' put: 0; at: 'stdout' put: ''; at: 'stderr' put: ''; yourself ].
	tool resyncer: [ resyncCalled := true. 'deadbeef' ].
	result := tool run: (Dictionary new
		at: 'paths' put: #('CLAUDE.md' 'lib/foo.st');
		at: 'message' put: 'docs: tweak';
		yourself).
	json := STONJSON fromString: result.
	self assert: (json at: 'commitId') equals: 'deadbeef'.
	self assert: resyncCalled.
	self assert: calls size equals: 2.
	self assert: calls first equals: #('add' '--' 'CLAUDE.md' 'lib/foo.st').
	self assert: calls second equals: #('commit' '-m' 'docs: tweak')
]

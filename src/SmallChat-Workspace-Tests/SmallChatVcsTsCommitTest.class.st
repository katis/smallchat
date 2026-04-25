Class {
	#name : 'SmallChatVcsTsCommitTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Workspace-Tests',
	#package : 'SmallChat-Workspace-Tests'
}

{ #category : 'running' }
SmallChatVcsTsCommitTest >> tearDown [
	SmallChatVcsTsCommit resetRunner.
	super tearDown
]

{ #category : 'tests' }
SmallChatVcsTsCommitTest >> testRunFailsWhenAddFails [
	SmallChatVcsTsCommit runner: [ :argv :cwd |
		argv first = 'add'
			ifTrue: [ Dictionary new at: 'exitCode' put: 1; at: 'stdout' put: ''; at: 'stderr' put: 'boom'; yourself ]
			ifFalse: [ Dictionary new at: 'exitCode' put: 0; at: 'stdout' put: ''; yourself ] ].
	self
		should: [ SmallChatVcsTsCommit run: 'msg' in: '/tmp/x' asFileReference ]
		raise: Error
		withExceptionDo: [ :e | self assert: (e messageText includesSubstring: 'git add') ]
]

{ #category : 'tests' }
SmallChatVcsTsCommitTest >> testRunFailsWhenNothingStaged [
	"git add -A succeeds, but diff --cached --name-only returns empty -- nothing
	 to commit. The helper should refuse without invoking git commit."
	| commitInvoked |
	commitInvoked := false.
	SmallChatVcsTsCommit runner: [ :argv :cwd |
		argv first = 'commit' ifTrue: [ commitInvoked := true ].
		argv = #('diff' '--cached' '--name-only')
			ifTrue: [ Dictionary new at: 'exitCode' put: 0; at: 'stdout' put: ''; yourself ]
			ifFalse: [ Dictionary new at: 'exitCode' put: 0; at: 'stdout' put: ''; yourself ] ].
	self
		should: [ SmallChatVcsTsCommit run: 'msg' in: '/tmp/x' asFileReference ]
		raise: Error
		withExceptionDo: [ :e | self assert: (e messageText includesSubstring: 'Nothing to commit') ].
	self deny: commitInvoked
]

{ #category : 'tests' }
SmallChatVcsTsCommitTest >> testRunInvokesGitAddAllThenCommitWithMessage [
	"Default branch produces zero staged files; the test seams the runner to
	 a deterministic block. Capture every invocation."
	| invocations result canned |
	invocations := OrderedCollection new.
	canned := Dictionary new.
	canned at: #('add' '-A') put: (Dictionary new at: 'exitCode' put: 0; at: 'stdout' put: ''; yourself).
	canned at: #('diff' '--cached' '--name-only') put:
		(Dictionary new at: 'exitCode' put: 0; at: 'stdout' put: 'a.ts',String lf,'b.ts',String lf; yourself).
	canned at: #('commit' '-m' 'my message') put:
		(Dictionary new at: 'exitCode' put: 0; at: 'stdout' put: ''; yourself).
	canned at: #('rev-parse' 'HEAD') put:
		(Dictionary new at: 'exitCode' put: 0; at: 'stdout' put: 'abc123def',String lf; yourself).
	canned at: #('rev-parse' '--abbrev-ref' 'HEAD') put:
		(Dictionary new at: 'exitCode' put: 0; at: 'stdout' put: 'main',String lf; yourself).
	SmallChatVcsTsCommit runner: [ :argv :cwd |
		invocations add: argv.
		canned at: argv asArray ifAbsent: [ Dictionary new
			at: 'exitCode' put: 0; at: 'stdout' put: ''; yourself ] ].
	result := SmallChatVcsTsCommit run: 'my message' in: '/tmp/fake-repo' asFileReference.
	"Verify shape."
	self assert: (result at: 'commitId') equals: 'abc123def'.
	self assert: (result at: 'branch') equals: 'main'.
	self assert: (result at: 'message') equals: 'my message'.
	self assert: (result at: 'changesWritten') equals: 2.
	"Verify invocation order."
	self assert: invocations first asArray equals: #('add' '-A').
	self assert: (invocations includes: #('commit' '-m' 'my message') asArray)
]

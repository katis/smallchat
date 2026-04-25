Class {
	#name : 'SmallChatVcsCommitDispatchTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Workspace-Tests',
	#package : 'SmallChat-Workspace-Tests'
}

{ #category : 'running' }
SmallChatVcsCommitDispatchTest >> setUp [
	super setUp.
	SmallChatTsWorkspace launcherBlock: [ :p | SmallChatLSPClient new transport: SmallChatLSPStubTransport new ].
	SmallChatCapabilityRegistry reset
]

{ #category : 'running' }
SmallChatVcsCommitDispatchTest >> tearDown [
	SmallChatVcsTsCommit resetRunner.
	SmallChatTsWorkspace resetLauncherBlock.
	SmallChatCapabilityRegistry reset.
	super tearDown
]

{ #category : 'tests' }
SmallChatVcsCommitDispatchTest >> testCommitOnPharoWorkspaceStillTakesIcebergPath [
	"vcs.commit on the Pharo workspace must NOT call the TS runner. We do
	 not actually commit -- just assert the runner was untouched and the
	 result came back from Iceberg path. The repo has no in-image changes
	 since the test fixture imports nothing, so we expect either a success
	 or the existing 'Nothing to commit' error -- either way the TS runner
	 stays untouched."
	| runnerInvoked call result |
	runnerInvoked := false.
	SmallChatVcsTsCommit runner: [ :argv :cwd |
		runnerInvoked := true.
		Dictionary new at: 'exitCode' put: 0; at: 'stdout' put: ''; yourself ].
	call := SmallChatCapabilityCall name: 'vcs.commit'
		argumentsJson: (STONJSON toString: (Dictionary new at: 'message' put: 'pharo-attempt'; yourself)).
	result := SmallChatCapabilityRegistry default run: 'vcs.commit' with: call.
	self assert: result notNil.
	self deny: runnerInvoked
]

{ #category : 'tests' }
SmallChatVcsCommitDispatchTest >> testCommitOnTsWorkspaceRoutesToHelper [
	"vcs.commit dispatched against a TS-workspace call should invoke
	 SmallChatVcsTsCommit, not Iceberg. Verify via the helper's runner seam."
	| ws call sawArgv result json |
	"Attach a TS workspace, then make it current."
	SmallChatTsWorkspace launcherBlock: [ :p | SmallChatLSPClient new transport: SmallChatLSPStubTransport new ].
	ws := SmallChatTsWorkspace attachAt: '/tmp/smallchat-vcs-commit-disp' name: 'ts-disp'.
	SmallChatCapabilityRegistry default mountWorkspace: ws.
	SmallChatCapabilityRegistry default currentWorkspace: ws.
	"Seam the runner: respond with canned values for each git invocation."
	sawArgv := OrderedCollection new.
	SmallChatVcsTsCommit runner: [ :argv :cwd |
		sawArgv add: argv asArray.
		argv asArray = #('diff' '--cached' '--name-only')
			ifTrue: [ Dictionary new at: 'exitCode' put: 0; at: 'stdout' put: 'x.ts',String lf; yourself ]
			ifFalse: [ argv asArray = #('rev-parse' 'HEAD')
				ifTrue: [ Dictionary new at: 'exitCode' put: 0; at: 'stdout' put: 'ts-sha',String lf; yourself ]
				ifFalse: [ argv asArray = #('rev-parse' '--abbrev-ref' 'HEAD')
					ifTrue: [ Dictionary new at: 'exitCode' put: 0; at: 'stdout' put: 'ts-branch',String lf; yourself ]
					ifFalse: [ Dictionary new at: 'exitCode' put: 0; at: 'stdout' put: ''; yourself ] ] ] ].
	call := SmallChatCapabilityCall name: 'vcs.commit'
		argumentsJson: (STONJSON toString: (Dictionary new at: 'message' put: 'ship it'; yourself)).
	result := SmallChatCapabilityRegistry default run: 'vcs.commit' with: call.
	self assert: result kind equals: #text.
	json := STONJSON fromString: result text.
	self assert: (json at: 'commitId') equals: 'ts-sha'.
	self assert: (json at: 'branch') equals: 'ts-branch'.
	self assert: (json at: 'message') equals: 'ship it'.
	self assert: (json at: 'changesWritten') equals: 1.
	"Confirm git commit was actually issued."
	self assert: (sawArgv anySatisfy: [ :a | a = #('commit' '-m' 'ship it') asArray ])
]

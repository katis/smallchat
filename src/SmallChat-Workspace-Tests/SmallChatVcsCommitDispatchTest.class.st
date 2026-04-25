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
	SmallChatVcsCommitCapability resetTestSeams.
	SmallChatVcsTsCommit resetRunner.
	SmallChatTsWorkspace resetLauncherBlock.
	SmallChatCapabilityRegistry reset.
	super tearDown
]

{ #category : 'tests' }
SmallChatVcsCommitDispatchTest >> testCommitOnPharoWorkspaceRoutesToPharoBranch [
	"vcs.commit on the Pharo workspace dispatches through runPharoCommit:in:.
	 Verify by intercepting the Pharo branch via #pharoCommitOverride: -- never
	 reaches Iceberg, never side-effects on the live working copy."
	| seenWs seenMsg call result tsRunnerInvoked |
	seenWs := nil. seenMsg := nil. tsRunnerInvoked := false.
	SmallChatVcsCommitCapability pharoCommitOverride: [ :ws :msg |
		seenWs := ws. seenMsg := msg.
		SmallChatCapabilityResult text: 'pharo-stub-ok' ].
	SmallChatVcsTsCommit runner: [ :argv :cwd |
		tsRunnerInvoked := true.
		Dictionary new at: 'exitCode' put: 0; at: 'stdout' put: ''; yourself ].
	call := SmallChatCapabilityCall name: 'vcs.commit'
		argumentsJson: (STONJSON toString: (Dictionary new at: 'message' put: 'pharo-msg'; yourself)).
	result := SmallChatCapabilityRegistry default run: 'vcs.commit' with: call.
	self assert: result kind equals: #text.
	self assert: result text equals: 'pharo-stub-ok'.
	self assert: seenWs == SmallChatPharoWorkspace default.
	self assert: seenMsg equals: 'pharo-msg'.
	self deny: tsRunnerInvoked
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

"
Pins the per-capability supportedWorkspaces matrix. Catalog filter tests assume this matrix; if a capability changes its workspace scope (or a new one is added), this test trips and forces an explicit decision.
"
Class {
	#name : 'SmallChatCapabilityWorkspaceScopeMatrixTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'fixtures' }
SmallChatCapabilityWorkspaceScopeMatrixTest >> expectedScopes [
	"Symbol -> Array of workspace-kind symbols. Sorted by capability name to
	 match the assertion failure output. Anyone changing supportedWorkspaces
	 must update this map in the same change."
	^ {
		'debug.evaluate' -> #(#pharo).
		'debug.frame' -> #(#pharo).
		'debug.proceed' -> #(#pharo).
		'debug.restart' -> #(#pharo).
		'debug.return' -> #(#pharo).
		'debug.sessions' -> #(#pharo).
		'debug.stack' -> #(#pharo).
		'debug.step-into' -> #(#pharo).
		'debug.step-over' -> #(#pharo).
		'debug.terminate' -> #(#pharo).
		'eval.lint' -> #(#pharo).
		'eval.run-tests' -> #(#pharo).
		'eval.smalltalk' -> #(#pharo #ts).
		'vcs.commit' -> #(#pharo #ts).
		'vcs.commit-files' -> #(#pharo).
		'vcs.status' -> #(#pharo).
		'workspace.attach-ts' -> #(#pharo #ts).
		'workspace.detach' -> #(#pharo #ts).
		'workspace.list' -> #(#pharo #ts) } asDictionary
]

{ #category : 'tests' }
SmallChatCapabilityWorkspaceScopeMatrixTest >> testWorkspaceScopeMatrix [
	| actual expected liveNames expectedNames |
	expected := self expectedScopes.
	actual := Dictionary new.
	(SmallChatCapability allSubclasses
		reject: [ :c | c isAbstract or: [ c isTestFixture ] ])
		do: [ :c | actual at: c capabilityName put: c supportedWorkspaces asArray ].
	liveNames := actual keys asSortedCollection asArray.
	expectedNames := expected keys asSortedCollection asArray.
	self
		assert: liveNames = expectedNames
		description: 'production capability set differs from the pinned matrix (#expectedScopes). expected: ' , expectedNames printString , ' actual: ' , liveNames printString.
	liveNames do: [ :n |
		self
			assert: (actual at: n) = (expected at: n)
			description: n , ' supportedWorkspaces drifted from the pinned matrix; expected ' , (expected at: n) printString , ' got ' , (actual at: n) printString ]
]

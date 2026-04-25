Class {
	#name : 'SmallChatEvalLintCapabilityTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatEvalLintCapabilityTest >> testRunReturnsJsonWithCritiquesArrayAndPackagesScanned [
	"Run with a no-match regex so the result is fast and predictable."
	| call result parsed |
	call := SmallChatCapabilityCall name: 'eval.lint' argumentsJson: '{"packagePattern":"NoSuchPackage.*"}'.
	result := SmallChatEvalLintCapability run: call.
	self assert: result kind equals: #text.
	parsed := STONJSON fromString: result text.
	self assert: (parsed at: 'packagesScanned') equals: #().
	self assert: (parsed at: 'critiqueCount') equals: 0.
	self assert: (parsed at: 'critiques') equals: #()
]

Class {
	#name : 'SmallChatEvalRunTestsCapabilityTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatEvalRunTestsCapabilityTest >> testRunWithNoMatchingPackagesReturnsZeroCounts [
	"Predictable degenerate case: a regex that matches nothing.
	 Easier to keep stable than running real tests inside a test."
	| call result parsed |
	call := SmallChatCapabilityCall name: 'eval.run-tests' argumentsJson: '{"packagePattern":"NoSuchPackage.*"}'.
	result := SmallChatEvalRunTestsCapability run: call.
	self assert: result kind equals: #text.
	parsed := STONJSON fromString: result text.
	self assert: (parsed at: 'passed') equals: 0.
	self assert: (parsed at: 'failed') equals: 0.
	self assert: (parsed at: 'errored') equals: 0.
	self assert: (parsed at: 'total') equals: 0
]

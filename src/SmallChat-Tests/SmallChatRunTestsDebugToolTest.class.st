Class {
	#name : 'SmallChatRunTestsDebugToolTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'running' }
SmallChatRunTestsDebugToolTest >> setUp [
    super setUp.
    SmallChatDebugSessionRegistry reset.
    self class classInstaller make: [ :b |
        b superclass: TestCase;
          name: #SmallChatDebugRunTestsFixture;
          package: 'SmallChat-Tests-DebugFixture' ].
    SmallChatDebugRunTestsFixture compile: 'testAlwaysFails
    1/0' classified: 'tests'
]

{ #category : 'running' }
SmallChatRunTestsDebugToolTest >> tearDown [
    SmallChatDebugSessionRegistry reset.
    (Smalltalk globals at: #SmallChatDebugRunTestsFixture ifAbsent: [ nil ])
        ifNotNil: [ :cls | cls removeFromSystem ].
    super tearDown
]

{ #category : 'tests' }
SmallChatRunTestsDebugToolTest >> testDebugFirstFailureCapturesSession [
    | result json |
    result := SmallChatToolRegistry default run: 'run_tests' with: (Dictionary new
        at: 'packagePattern' put: 'SmallChat-Tests-DebugFixture';
        at: 'debug_first_failure' put: true;
        yourself).
    json := STONJSON fromString: ((result at: 'content') first at: 'text').
    self assert: (json at: 'errored') equals: 1.
    self assert: (json includesKey: 'debugSessionId').
    self assert: (SmallChatDebugSessionRegistry default at: (json at: 'debugSessionId')) notNil
]

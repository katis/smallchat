Class {
	#name : 'SmallChatEvalRunTestsCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatEvalRunTestsCapability class >> capabilityName [ ^ 'eval.run-tests'
]

{ #category : 'private' }
SmallChatEvalRunTestsCapability class >> captureFirstFailure: aTestResult [
	| failing first outcome |
	failing := aTestResult failures asOrderedCollection , aTestResult errors asOrderedCollection.
	failing ifEmpty: [ ^ nil ].
	first := failing first.
	outcome := SmallChatDebugEvaluator evaluate:
		'(' , first class name , ' selector: ' , first selector asString printString , ') performTest'.
	^ outcome key = #debugSession ifTrue: [ outcome value id ] ifFalse: [ nil ]
]

{ #category : 'private' }
SmallChatEvalRunTestsCapability class >> describeError: aTestCase from: aResult [
	| failure |
	failure := [ aTestCase signaledException ] on: Error do: [ :_ | nil ].
	^ Dictionary new
		at: 'class' put: aTestCase class name;
		at: 'selector' put: aTestCase selector asString;
		at: 'message' put: (failure
			ifNil: [ '<no exception>' ]
			ifNotNil: [ failure messageText ifNil: [ failure class name ] ]);
		at: 'exceptionClass' put: (failure ifNil: [ '<n/a>' ] ifNotNil: [ failure class name ]);
		at: 'stack' put: (self stackOf: failure);
		yourself
]

{ #category : 'metadata' }
SmallChatEvalRunTestsCapability class >> description [
	^ 'Run SUnit tests in the live image. Discovers test classes by package-name regex (default ''SmallChat.*''); optional selector regex narrows further. Returns structured {passed, failed, errored, durationMs, failures, errors}. Reflects in-image state -- run `just test` from a shell before commit to verify a fresh rebuild also passes.'
]

{ #category : 'private' }
SmallChatEvalRunTestsCapability class >> matchingTestClasses: packagePattern [
	| matcher pkgs testClasses |
	matcher := RxMatcher forString: packagePattern.
	pkgs := PackageOrganizer default packages
		select: [ :p | matcher matches: p name ].
	testClasses := OrderedCollection new.
	pkgs do: [ :pkg |
		pkg definedClasses do: [ :c |
			(c isKindOf: Class)
				ifTrue: [ (c inheritsFrom: TestCase) ifTrue: [ testClasses add: c ] ] ] ].
	^ testClasses
]

{ #category : 'execution' }
SmallChatEvalRunTestsCapability class >> run: aCapabilityCall [
	"Migrated from SmallChatRunTestsTool>>run:."
	| args packagePattern testPattern testClasses suite result startMs duration json testMatcher debugFirst debugSid |
	args := aCapabilityCall arguments.
	packagePattern := args at: 'packagePattern' ifAbsent: [ 'SmallChat.*' ].
	testPattern := args at: 'testPattern' ifAbsent: [ nil ].
	debugFirst := args at: 'debug_first_failure' ifAbsent: [ false ].
	testClasses := self matchingTestClasses: packagePattern.
	suite := TestSuite new.
	testMatcher := testPattern ifNotNil: [ RxMatcher forString: testPattern ].
	testClasses do: [ :tc |
		tc allTestSelectors do: [ :sel |
			(testMatcher isNil or: [ testMatcher matches: tc name , '>>' , sel ])
				ifTrue: [ suite addTest: (tc selector: sel) ] ] ].
	startMs := Time millisecondClockValue.
	result := TestResult new.
	suite tests do: [ :t | t run: result ].
	duration := Time millisecondClockValue - startMs.
	debugSid := debugFirst ifTrue: [ self captureFirstFailure: result ] ifFalse: [ nil ].
	json := Dictionary new
		at: 'passed' put: result passedCount;
		at: 'failed' put: result failures size;
		at: 'errored' put: result errors size;
		at: 'total' put: suite tests size;
		at: 'durationMs' put: duration;
		at: 'packagePattern' put: packagePattern;
		at: 'failures' put: (result failures asArray collect: [ :t | self describeError: t from: result ]);
		at: 'errors' put: (result errors asArray collect: [ :t | self describeError: t from: result ]);
		yourself.
	testPattern ifNotNil: [ json at: 'testPattern' put: testPattern ].
	debugSid ifNotNil: [ json at: 'debugSessionId' put: debugSid ].
	^ SmallChatCapabilityResult text: (STONJSON toString: json)
]

{ #category : 'metadata' }
SmallChatEvalRunTestsCapability class >> schema [
	^ SmallChatCapabilitySchema empty
		string: 'packagePattern'
			required: false
			description: 'Regex (Pharo RxParser) over package names. Default: SmallChat.*';
		string: 'testPattern'
			required: false
			description: 'Optional regex over Class>>selector. Restricts which tests run.';
		boolean: 'debug_first_failure'
			required: false
			description: 'Opt-in: re-execute the first failing test via the debugger-driven evaluator so its exception lands in a captured debug session. Response gains a debugSessionId field.'
]

{ #category : 'private' }
SmallChatEvalRunTestsCapability class >> stackOf: anException [
	| frames |
	anException ifNil: [ ^ #() ].
	frames := [ anException signalerContext stack ]
		on: Error do: [ :_ | #() ].
	^ ((frames first: (frames size min: 20)) collect: [ :ctx |
		[ ctx printString ] on: Error do: [ :_ | '<unprintable frame>' ] ]) asArray
]

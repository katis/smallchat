"
Run SUnit tests in-image and return structured results. Discovers
test classes by package-name regex (default 'SmallChat.*') and
optionally filters by selector regex.

Returns JSON with {passed, failed, errored, durationMs, failures[],
errors[]}. Each failure/error entry includes the test class, selector,
message, and a trimmed stack trace -- saves the model from parsing
printString of TestResult.

Runs against the in-image state, NOT against a fresh rebuild from
src/. A green run here does NOT guarantee `just test` from a shell
will also pass; in-image state can drift from the on-disk Tonel.
Always `just test` before committing.
"
Class {
	#name : #SmallChatRunTestsTool,
	#superclass : #SmallChatTool,
	#category : #'SmallChat-MCP'
}

{ #category : #'accessing - metadata' }
SmallChatRunTestsTool class >> description [
	^ 'Run SUnit tests in the live image. Discovers test classes by package-name regex (default ''SmallChat.*''); optional selector regex narrows further. Returns structured {passed, failed, errored, durationMs, failures, errors}. Reflects in-image state -- run `just test` from a shell before commit to verify a fresh rebuild also passes.'
]

{ #category : #'accessing - metadata' }
SmallChatRunTestsTool class >> inputSchema [
	^ Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: (Dictionary new
			at: 'packagePattern' put: (Dictionary new
				at: 'type' put: 'string';
				at: 'description' put: 'Regex (Pharo RxParser) over package names. Default: SmallChat.*';
				yourself);
			at: 'testPattern' put: (Dictionary new
				at: 'type' put: 'string';
				at: 'description' put: 'Optional regex over Class>>selector. Restricts which tests run.';
				yourself);
			at: 'debug_first_failure' put: (Dictionary new
				at: 'type' put: 'boolean';
				at: 'description' put: 'Opt-in: re-execute the first failing test via the debugger-driven evaluator so its exception lands in a captured debug session. Response gains a debugSessionId field.';
				yourself);
			yourself);
		at: 'required' put: #();
		yourself
]

{ #category : #'accessing - metadata' }
SmallChatRunTestsTool class >> toolName [ ^ 'run_tests' ]

{ #category : #execution }
SmallChatRunTestsTool >> captureFirstFailure: aTestResult [
	"When debug_first_failure is on and a test failed/errored, re-execute the
	 first failing test through SmallChatDebugEvaluator so the exception
	 lands in our capture-and-suspend handler instead of SUnit's TestResult.
	 Returns the session id, or nil if nothing failed or the re-run happened
	 to succeed this time."
	| failing first outcome |
	failing := aTestResult failures asOrderedCollection , aTestResult errors asOrderedCollection.
	failing ifEmpty: [ ^ nil ].
	first := failing first.
	outcome := SmallChatDebugEvaluator evaluate:
		'(' , first class name , ' selector: ' , first selector asString printString , ') performTest'.
	^ outcome key = #debugSession ifTrue: [ outcome value id ] ifFalse: [ nil ]
]

{ #category : #execution }
SmallChatRunTestsTool >> describeError: aTestCase from: aResult [
	"Build a {test, class, message, stack} dictionary for a failure/error.
	 aTestCase is the actual test instance that failed; aResult tracks
	 the exception via #errors / #failures collections."
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

{ #category : #execution }
SmallChatRunTestsTool >> matchingTestClasses: packagePattern [
	"Return TestCase subclasses whose package name matches packagePattern."
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

{ #category : #execution }
SmallChatRunTestsTool >> run: args [
	| packagePattern testPattern testClasses suite result startMs duration json testMatcher debugFirst debugSid |
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
	suite tests do: [ :test | test run: result ].
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

	^ STONJSON toString: json
]

{ #category : #execution }
SmallChatRunTestsTool >> stackOf: anException [
	"Trimmed top-of-stack for an exception. Skip Kernel/SUnit frames so
	 the user-relevant context shows up first; cap at 20 frames."
	| frames |
	anException ifNil: [ ^ #() ].
	frames := [ anException signalerContext stack ]
		on: Error do: [ :_ | #() ].
	^ ((frames first: (frames size min: 20)) collect: [ :ctx |
		[ ctx printString ] on: Error do: [ :_ | '<unprintable frame>' ] ]) asArray
]

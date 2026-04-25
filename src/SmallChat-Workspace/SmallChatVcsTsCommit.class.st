Class {
	#name : 'SmallChatVcsTsCommit',
	#superclass : 'Object',
	#classVars : [
		'RunnerOverride'
	],
	#category : 'SmallChat-Workspace',
	#package : 'SmallChat-Workspace'
}

{ #category : 'private' }
SmallChatVcsTsCommit class >> describeProcessResult: aDict [
	| parts stderr stdout |
	parts := OrderedCollection new.
	stderr := (aDict at: 'stderr' ifAbsent: [ '' ]) ifNil: [ '' ].
	stdout := (aDict at: 'stdout' ifAbsent: [ '' ]) ifNil: [ '' ].
	stderr isEmpty ifFalse: [ parts add: stderr trimBoth ].
	stdout isEmpty ifFalse: [ parts add: stdout trimBoth ].
	^ parts isEmpty
		ifTrue: [ 'exit=' , (aDict at: 'exitCode') printString ]
		ifFalse: [ String streamContents: [ :s | parts do: [ :p | s nextPutAll: p ] separatedBy: [ s << ' | ' ] ] ]
]

{ #category : 'accessing' }
SmallChatVcsTsCommit class >> resetRunner [ RunnerOverride := nil
]

{ #category : 'execution' }
SmallChatVcsTsCommit class >> run: aMessage in: aFileReference [
	"Stage all changes in aFileReference, commit with aMessage, return a
	 Dictionary with #commitId, #message, #branch, #changesWritten. Raises
	 Error on git failure or if nothing was staged."
	| addRes diffRes stagedFiles commitRes headRes branchRes |
	(aMessage isString and: [ aMessage isEmpty not ])
		ifFalse: [ self error: 'message must be a non-empty string' ].
	addRes := self runner value: #('add' '-A') value: aFileReference.
	(addRes at: 'exitCode') = 0 ifFalse: [
		self error: 'git add failed: ' , (self describeProcessResult: addRes) ].
	diffRes := self runner value: #('diff' '--cached' '--name-only') value: aFileReference.
	(diffRes at: 'exitCode') = 0 ifFalse: [
		self error: 'git diff --cached --name-only failed: ' , (self describeProcessResult: diffRes) ].
	stagedFiles := ((diffRes at: 'stdout' ifAbsent: [ '' ]) lines reject: [ :l | l trimBoth isEmpty ]).
	stagedFiles isEmpty ifTrue: [ self error: 'Nothing to commit. No changes staged in ' , aFileReference fullName ].
	commitRes := self runner value: { 'commit'. '-m'. aMessage } value: aFileReference.
	(commitRes at: 'exitCode') = 0 ifFalse: [
		self error: 'git commit failed: ' , (self describeProcessResult: commitRes) ].
	headRes := self runner value: #('rev-parse' 'HEAD') value: aFileReference.
	branchRes := self runner value: #('rev-parse' '--abbrev-ref' 'HEAD') value: aFileReference.
	^ Dictionary new
		at: 'commitId' put: ((headRes at: 'stdout' ifAbsent: [ '' ]) trimBoth);
		at: 'message' put: aMessage;
		at: 'branch' put: ((branchRes at: 'stdout' ifAbsent: [ '' ]) trimBoth);
		at: 'changesWritten' put: stagedFiles size;
		yourself
]

{ #category : 'private' }
SmallChatVcsTsCommit class >> runGitProcess: argv in: aFileReference [
	"Default runner: shell-out git in aFileReference root via LibC. Returns
	 {exitCode, stdout, stderr} -- stderr empty (we 2>&1 into stdout)."
	| outFile cmd systemRc rc out |
	outFile := (FileLocator temp asFileReference / ('smallchat-ts-git-' , UUID new asString , '.log')) fullName.
	cmd := String streamContents: [ :s |
		s << 'cd '. s nextPutAll: (self shellQuote: aFileReference fullName). s << ' && git'.
		argv do: [ :a | s nextPut: Character space. s nextPutAll: (self shellQuote: a) ].
		s << ' > '. s nextPutAll: (self shellQuote: outFile). s << ' 2>&1' ].
	systemRc := LibC system: cmd.
	rc := systemRc = 0 ifTrue: [ 0 ] ifFalse: [ (systemRc bitShift: -8) max: 1 ].
	out := [ outFile asFileReference contents ] on: Error do: [ :_ | '' ].
	[ outFile asFileReference ensureDelete ] on: Error do: [ :_ | ].
	^ Dictionary new
		at: 'exitCode' put: rc;
		at: 'stdout' put: (out ifNil: [ '' ]);
		at: 'stderr' put: '';
		yourself
]

{ #category : 'accessing' }
SmallChatVcsTsCommit class >> runner [
	"Block (argv, cwdRef) -> processResultDict (#exitCode, #stdout, #stderr).
	 Defaults to a real LibC-driven git invocation; test seams override."
	^ RunnerOverride ifNil: [ [ :argv :cwd | self runGitProcess: argv in: cwd ] ]
]

{ #category : 'accessing' }
SmallChatVcsTsCommit class >> runner: aBlock [ RunnerOverride := aBlock
]

{ #category : 'private' }
SmallChatVcsTsCommit class >> shellQuote: aString [
	"POSIX-safe: wrap in single quotes; escape internal apostrophes."
	| apos bs |
	apos := Character value: 39.
	bs := Character value: 92.
	^ String streamContents: [ :s |
		s nextPut: apos.
		aString do: [ :c |
			c = apos
				ifTrue: [ s nextPut: apos. s nextPut: bs. s nextPut: apos. s nextPut: apos ]
				ifFalse: [ s nextPut: c ] ].
		s nextPut: apos ]
]

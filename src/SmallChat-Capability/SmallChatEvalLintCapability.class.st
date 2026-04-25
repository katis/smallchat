Class {
	#name : 'SmallChatEvalLintCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatEvalLintCapability class >> capabilityName [ ^ 'eval.lint'
]

{ #category : 'private' }
SmallChatEvalLintCapability class >> describeCritique: aCritique inPackage: aPackage [
	^ Dictionary new
		at: 'package' put: aPackage name;
		at: 'rule' put: ([ aCritique rule name ]
			on: Error do: [ :_ | nil ])
				ifNil: [ aCritique rule class name ];
		at: 'description' put: ([ aCritique description ] on: Error do: [ :_ | '<n/a>' ]);
		at: 'target' put: ([
			aCritique sourceAnchor entity printString ]
			on: Error do: [ :_ | '<n/a>' ]);
		yourself
]

{ #category : 'metadata' }
SmallChatEvalLintCapability class >> description [
	^ 'Run ReCriticEngine over packages matching the pattern (default ''SmallChat.*'') and return structured critiques. Mirrors `just lint`, in-image.'
]

{ #category : 'metadata' }
SmallChatEvalLintCapability class >> mcpAliases [ ^ #('lint')
]

{ #category : 'execution' }
SmallChatEvalLintCapability class >> run: aCapabilityCall [
	"Migrated from SmallChatLintTool>>run:."
	| packagePattern matcher pkgs out json |
	packagePattern := aCapabilityCall arguments at: 'packagePattern' ifAbsent: [ 'SmallChat.*' ].
	matcher := RxMatcher forString: packagePattern.
	pkgs := PackageOrganizer default packages
		select: [ :p | matcher matches: p name ].
	out := OrderedCollection new.
	pkgs do: [ :pkg |
		(ReCriticEngine critiquesOf: pkg) do: [ :c |
			out add: (self describeCritique: c inPackage: pkg) ] ].
	json := Dictionary new
		at: 'packagesScanned' put: (pkgs collect: [ :p | p name ]) asArray;
		at: 'critiqueCount' put: out size;
		at: 'critiques' put: out asArray;
		yourself.
	^ SmallChatCapabilityResult text: (STONJSON toString: json)
]

{ #category : 'metadata' }
SmallChatEvalLintCapability class >> schema [
	^ SmallChatCapabilitySchema empty
		string: 'packagePattern'
		required: false
		description: 'Regex over package names. Default: SmallChat.*'
]

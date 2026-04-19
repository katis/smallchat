"
Run Pharo's Critiques engine over packages matching a regex (default
'SmallChat.*') and return structured findings. Wraps the same
ReCriticEngine call that lib/lint.st uses for `just lint`, but
returns JSON instead of printing + exit-code.
"
Class {
	#name : #SmallChatLintTool,
	#superclass : #SmallChatTool,
	#category : #'SmallChat-MCP'
}

{ #category : #'accessing - metadata' }
SmallChatLintTool class >> description [
	^ 'Run ReCriticEngine over packages matching the pattern (default ''SmallChat.*'') and return structured critiques. Mirrors `just lint`, in-image.'
]

{ #category : #'accessing - metadata' }
SmallChatLintTool class >> inputSchema [
	^ Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: (Dictionary new
			at: 'packagePattern' put: (Dictionary new
				at: 'type' put: 'string';
				at: 'description' put: 'Regex over package names. Default: SmallChat.*';
				yourself);
			yourself);
		at: 'required' put: #();
		yourself
]

{ #category : #'accessing - metadata' }
SmallChatLintTool class >> toolName [ ^ 'lint' ]

{ #category : #execution }
SmallChatLintTool >> describeCritique: aCritique inPackage: aPackage [
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

{ #category : #execution }
SmallChatLintTool >> run: args [
	| packagePattern matcher pkgs out json |
	packagePattern := args at: 'packagePattern' ifAbsent: [ 'SmallChat.*' ].
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
	^ STONJSON toString: json
]

Class {
	#name : 'SmallChatNav',
	#superclass : 'Object',
	#category : 'SmallChat-Nav',
	#package : 'SmallChat-Nav'
}

{ #category : 'api' }
SmallChatNav class >> describeClass: classNameOrSymbol [
	| name cls |
	name := classNameOrSymbol asSymbol.
	cls := Smalltalk globals at: name ifAbsent: [ nil ].
	cls ifNil: [ ^ '_class not found: ', name asString, '_' ].
	^ String streamContents: [ :s |
		s nextPutAll: '## '; nextPutAll: cls name;
		  nextPutAll: ' (package: '; nextPutAll: cls package name;
		  nextPutAll: ', super: '; nextPutAll: cls superclass name;
		  nextPutAll: ')'; lf; lf.
		cls comment ifNotEmpty: [ :c |
			s nextPutAll: (self firstSentenceOf: c); lf; lf ].
		cls instVarNames ifNotEmpty: [ :vs |
			s nextPutAll: '**Instance vars:** ';
			  nextPutAll: (', ' join: vs); lf; lf ].
		self renderSelectorsByProtocolFor: cls heading: 'Instance-side selectors' on: s.
		self renderSelectorsByProtocolFor: cls class heading: 'Class-side selectors' on: s.
		s nextPutAll: '**Examples:** see `SmallChatNav examplesFor: #';
		  nextPutAll: cls name; nextPutAll: '`'; lf ]
]

{ #category : 'api' }
SmallChatNav class >> examplesFor: classNameOrSymbol [
	| name cls examples siblingName sibling |
	name := classNameOrSymbol asSymbol.
	cls := Smalltalk globals at: name ifAbsent: [ nil ].
	cls ifNil: [ ^ '_class not found: ', name asString, '_' ].
	examples := cls selectorsInProtocol: 'examples'.
	examples isEmpty ifFalse: [
		^ String streamContents: [ :s |
			examples asSortedCollection do: [ :sel |
				s nextPutAll: '### '; nextPutAll: cls name;
				  nextPutAll: '>>'; nextPutAll: sel asString; lf; lf;
				  nextPutAll: '```smalltalk'; lf;
				  nextPutAll: (cls >> sel) sourceCode; lf;
				  nextPutAll: '```'; lf; lf ] ] ].
	siblingName := (cls name asString , 'Test') asSymbol.
	sibling := Smalltalk globals at: siblingName ifAbsent: [ nil ].
	sibling ifNotNil: [
		^ '_No examples yet. Try: `SmallChatNav findMethods: ''test'' in: #', siblingName asString, '`_' ].
	^ '_No examples yet._'
]

{ #category : 'api' }
SmallChatNav class >> findClasses: pattern [
	| matcher matches limit shown |
	matcher := RxMatcher forString: pattern.
	matches := SystemNavigation default allClasses select: [ :c | matcher search: c name ].
	matches isEmpty ifTrue: [ ^ '_no matches_' ].
	limit := SmallChatNavBudget default size.
	shown := 0.
	^ String streamContents: [ :s |
		matches do: [ :c |
			s position < limit ifTrue: [
				s nextPutAll: '* `'; nextPutAll: c name; nextPutAll: '` ('.
				s nextPutAll: c package name; nextPutAll: ')'; lf.
				shown := shown + 1 ] ].
		shown < matches size ifTrue: [
			s nextPutAll: '_'; print: matches size;
			  nextPutAll: ' matches; showing first '; print: shown;
			  nextPutAll: '._'; lf ] ]
]

{ #category : 'api' }
SmallChatNav class >> findMethods: pattern in: classNameOrSymbol [
	"Bullet list of `Class>>selector` (instance) and `Class class>>selector`
	 (class-side) hits whose name matches pattern (RxMatcher substring
	 semantics). Searches both sides so class-side helpers like
	 SmallChatTsNav are findable in one call. Capped at 50."
	| name cls matcher hits sorted shown total cap |
	name := classNameOrSymbol asSymbol.
	cls := Smalltalk globals at: name ifAbsent: [ nil ].
	cls ifNil: [ ^ '_class not found: ', name asString, '_' ].
	matcher := RxMatcher forString: pattern.
	hits := OrderedCollection new.
	cls selectors do: [ :sel |
		(matcher search: sel asString) ifTrue: [
			hits add: { cls. sel. cls name asString , '>>' , sel asString } ] ].
	cls class selectors do: [ :sel |
		(matcher search: sel asString) ifTrue: [
			hits add: { cls class. sel. cls name asString , ' class>>' , sel asString } ] ].
	hits isEmpty ifTrue: [ ^ '_no matches_' ].
	cap := 50.
	sorted := hits asSortedCollection: [ :a :b | (a at: 3) < (b at: 3) ].
	total := sorted size.
	shown := total min: cap.
	^ String streamContents: [ :s |
		1 to: shown do: [ :i | | hit owner sel proto |
			hit := sorted asArray at: i.
			owner := hit at: 1.
			sel := hit at: 2.
			s nextPutAll: '* `'; nextPutAll: (hit at: 3); nextPutAll: '`'.
			proto := owner protocolNameOfSelector: sel.
			proto ifNotNil: [
				s nextPutAll: ' ('; nextPutAll: proto asString; nextPutAll: ')' ].
			s lf ].
		shown < total ifTrue: [
			s nextPutAll: '_'; print: total;
			  nextPutAll: ' matches; showing first '; print: shown;
			  nextPutAll: '._'; lf ] ]
]

{ #category : 'private' }
SmallChatNav class >> firstSentenceOf: aString [
	| dot |
	aString isEmpty ifTrue: [ ^ '' ].
	dot := aString indexOf: $..
	dot = 0 ifTrue: [ ^ aString copyFrom: 1 to: (aString size min: 200) ].
	^ aString copyFrom: 1 to: dot
]

{ #category : 'private' }
SmallChatNav class >> publicProtocolsOf: aClass [
	"Protocol objects in lex order, dropping anything whose name starts
	 with 'private'. Empty for either side when only private protocols exist."
	^ (aClass protocols
		reject: [ :p | p name asString beginsWith: 'private' ])
		asSortedCollection: [ :a :b | a name asString < b name asString ]
]

{ #category : 'private' }
SmallChatNav class >> renderSelectorsByProtocolFor: aClass heading: aHeading on: aStream [
	"Append a section listing aClass's public selectors grouped by their
	 (non-private) protocol. No-op when the side has no public protocols
	 -- avoids empty headings on instance-only or class-only classes."
	| protocols selectorsByProto perProtoCap |
	protocols := self publicProtocolsOf: aClass.
	selectorsByProto := OrderedCollection new.
	protocols do: [ :p | | sels |
		sels := (aClass selectorsInProtocol: p name) asSortedCollection asArray.
		sels isEmpty ifFalse: [
			selectorsByProto add: p name asString -> sels ] ].
	selectorsByProto isEmpty ifTrue: [ ^ self ].
	perProtoCap := 12.
	aStream nextPutAll: '**'; nextPutAll: aHeading;
		nextPutAll: '** (by protocol):'; lf.
	selectorsByProto do: [ :assoc | | shown total |
		total := assoc value size.
		shown := total min: perProtoCap.
		aStream nextPutAll: '* '; nextPutAll: assoc key; nextPutAll: ': '.
		1 to: shown do: [ :i |
			i > 1 ifTrue: [ aStream nextPutAll: ', ' ].
			aStream nextPutAll: (assoc value at: i) asString ].
		shown < total ifTrue: [
			aStream nextPutAll: ', ...(+'; print: total - shown; nextPutAll: ')' ].
		aStream lf ].
	aStream lf
]

{ #category : 'api' }
SmallChatNav class >> show: classNameOrSymbol method: selectorSymbol [
	"Method header, comment, and source for cls>>selectorSymbol. Falls
	 back to the class side when the instance side does not implement
	 the selector -- the header reads `Class class>>selector` so the
	 agent sees the call shape."
	| name cls owner header method protoName |
	name := classNameOrSymbol asSymbol.
	cls := Smalltalk globals at: name ifAbsent: [ nil ].
	cls ifNil: [ ^ '_class not found: ', name asString, '_' ].
	(cls includesSelector: selectorSymbol)
		ifTrue: [ owner := cls. header := cls name , '>>' , selectorSymbol asString ]
		ifFalse: [
			(cls class includesSelector: selectorSymbol)
				ifTrue: [ owner := cls class. header := cls name , ' class>>' , selectorSymbol asString ]
				ifFalse: [ ^ '_method not found: ', cls name, '>>', selectorSymbol asString, '_' ] ].
	method := owner >> selectorSymbol.
	protoName := owner protocolNameOfSelector: selectorSymbol.
	^ String streamContents: [ :s |
		s nextPutAll: '**'; nextPutAll: header; nextPutAll: '**'.
		protoName ifNotNil: [
			s nextPutAll: ' (protocol: '; nextPutAll: protoName asString; nextPutAll: ')' ].
		s lf; lf.
		(method comment ifNil: [ '' ]) ifNotEmpty: [ :c |
			s nextPutAll: c; lf; lf ].
		s nextPutAll: '```smalltalk'; lf;
		  nextPutAll: method sourceCode; lf;
		  nextPutAll: '```'; lf ]
]

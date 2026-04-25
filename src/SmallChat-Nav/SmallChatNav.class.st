Class {
	#name : 'SmallChatNav',
	#superclass : 'Object',
	#category : 'SmallChat-Nav',
	#package : 'SmallChat-Nav'
}

{ #category : 'api' }
SmallChatNav class >> describeClass: classNameOrSymbol [
	| name cls protocols keys |
	name := classNameOrSymbol asSymbol.
	cls := Smalltalk globals at: name ifAbsent: [ nil ].
	cls ifNil: [ ^ '_class not found: ', name asString, '_' ].
	protocols := self publicProtocolsOf: cls.
	keys := self keySelectorsOf: cls.
	^ String streamContents: [ :s |
		s nextPutAll: '## '; nextPutAll: cls name;
		  nextPutAll: ' (package: '; nextPutAll: cls package name;
		  nextPutAll: ', super: '; nextPutAll: cls superclass name;
		  nextPutAll: ')'; lf; lf.
		cls comment ifNotEmpty: [ :c |
			s nextPutAll: (self firstSentenceOf: c); lf; lf ].
		cls instVarNames ifNotEmpty: [ :vs |
			s nextPutAll: '**Instance vars:** ';
			  nextPutAll: (', ' join: vs); lf ].
		s nextPutAll: '**Public protocols:** ';
		  nextPutAll: (', ' join: protocols); lf.
		s nextPutAll: '**Key selectors:** ';
		  nextPutAll: (', ' join: (keys collect: [ :sel | sel asString ])); lf.
		s nextPutAll: '**Examples:** see `SmallChatNav examplesFor: #';
		  nextPutAll: cls name; nextPutAll: '`'; lf ]
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
	| name cls matcher matches sorted shown total cap |
	name := classNameOrSymbol asSymbol.
	cls := Smalltalk globals at: name ifAbsent: [ nil ].
	cls ifNil: [ ^ '_class not found: ', name asString, '_' ].
	matcher := RxMatcher forString: pattern.
	matches := cls selectors select: [ :sel | matcher search: sel asString ].
	matches isEmpty ifTrue: [ ^ '_no matches_' ].
	cap := 50.
	sorted := matches asSortedCollection asArray.
	total := sorted size.
	shown := total min: cap.
	^ String streamContents: [ :s |
		1 to: shown do: [ :i | | sel |
			sel := sorted at: i.
			s nextPutAll: '* `'; nextPutAll: cls name;
			  nextPutAll: '>>'; nextPutAll: sel asString; nextPutAll: '`'.
			(cls protocolNameOfSelector: sel) ifNotNil: [ :p |
				s nextPutAll: ' ('; nextPutAll: p asString; nextPutAll: ')' ].
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
SmallChatNav class >> keySelectorsOf: aClass [
	"Top ~8 lex selectors, excluding any whose protocol begins with private."
	| publicSels |
	publicSels := (aClass selectors
		reject: [ :sel | (aClass protocolNameOfSelector: sel) ifNil: [ false ] ifNotNil: [ :p | p asString beginsWith: 'private' ] ])
		asSortedCollection.
	^ (publicSels first: (publicSels size min: 8)) asArray
]

{ #category : 'private' }
SmallChatNav class >> publicProtocolsOf: aClass [
	^ (aClass protocols
		reject: [ :p | p name asString beginsWith: 'private' ])
		collect: [ :p | p name asString ]
]

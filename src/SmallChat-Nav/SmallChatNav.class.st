Class {
	#name : 'SmallChatNav',
	#superclass : 'Object',
	#category : 'SmallChat-Nav',
	#package : 'SmallChat-Nav'
}

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

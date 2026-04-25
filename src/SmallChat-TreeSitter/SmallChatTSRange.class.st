Class {
	#name : 'SmallChatTSRange',
	#superclass : 'Object',
	#instVars : [
		'startByte',
		'endByte',
		'source'
	],
	#category : 'SmallChat-TreeSitter',
	#package : 'SmallChat-TreeSitter'
}

{ #category : 'private - encoding' }
SmallChatTSRange class >> byteOffsetOfLine: aLine character: aCharacter inSource: aString [
	"Walk aString counting newlines until aLine, then UTF-16 units until
	 aCharacter, summing UTF-8 bytes consumed. Returns the byte offset."
	| line char byteIdx |
	line := 0.
	char := 0.
	byteIdx := 0.
	aString do: [ :ch |
		(line = aLine and: [ char >= aCharacter ]) ifTrue: [ ^ byteIdx ].
		ch codePoint = 10
			ifTrue: [
				line := line + 1.
				char := 0.
				byteIdx := byteIdx + 1 ]
			ifFalse: [
				line < aLine ifTrue: [
					byteIdx := byteIdx + (self utf8ByteSizeOfCodePoint: ch codePoint) ]
				ifFalse: [
					char := char + (self utf16UnitsOfCodePoint: ch codePoint).
					byteIdx := byteIdx + (self utf8ByteSizeOfCodePoint: ch codePoint) ] ] ].
	^ byteIdx
]

{ #category : 'instance creation - LSP' }
SmallChatTSRange class >> fromLSPPositionRange: aDictionary source: aString [
	"Inverse of asLSPPositionRange. Walks aString to convert UTF-16 (line,
	 character) pairs back into UTF-8 byte offsets."
	| start end |
	start := self
		byteOffsetOfLine: ((aDictionary at: 'start') at: 'line')
		character: ((aDictionary at: 'start') at: 'character')
		inSource: aString.
	end := self
		byteOffsetOfLine: ((aDictionary at: 'end') at: 'line')
		character: ((aDictionary at: 'end') at: 'character')
		inSource: aString.
	^ self startByte: start endByte: end source: aString
]

{ #category : 'instance creation' }
SmallChatTSRange class >> startByte: aStartByte endByte: anEndByte source: aString [
	"Build a range describing aStartByte..anEndByte (zero-indexed, end-exclusive)
	 in the UTF-8 encoding of aString. Holds the source so derived line/character
	 accessors can convert on demand."
	^ self new
		setStartByte: aStartByte
		endByte: anEndByte
		source: aString;
		yourself
]

{ #category : 'private - encoding' }
SmallChatTSRange class >> utf16UnitsOfCodePoint: aCodePoint [
	^ aCodePoint < 16r10000 ifTrue: [ 1 ] ifFalse: [ 2 ]
]

{ #category : 'private - encoding' }
SmallChatTSRange class >> utf8ByteSizeOfCodePoint: aCodePoint [
	aCodePoint < 16r80 ifTrue: [ ^ 1 ].
	aCodePoint < 16r800 ifTrue: [ ^ 2 ].
	aCodePoint < 16r10000 ifTrue: [ ^ 3 ].
	^ 4
]

{ #category : 'accessing - LSP' }
SmallChatTSRange >> asLSPPositionRange [
	"Encode the range as an LSP position-range dictionary:
	 { 'start' -> { 'line' -> N, 'character' -> M },
	   'end' -> { 'line' -> N, 'character' -> M } }.
	 Strings are LSP wire keys so the result can flow into JSON-RPC
	 payloads without further translation."
	| start end |
	start := self lineCharacterAtByte: startByte.
	end := self lineCharacterAtByte: endByte.
	^ Dictionary new
		at: 'start' put: (Dictionary new
			at: 'line' put: start x;
			at: 'character' put: start y;
			yourself);
		at: 'end' put: (Dictionary new
			at: 'line' put: end x;
			at: 'character' put: end y;
			yourself);
		yourself
]

{ #category : 'accessing' }
SmallChatTSRange >> endByte [
	^ endByte
]

{ #category : 'accessing - LSP' }
SmallChatTSRange >> endCharacter [
	^ (self lineCharacterAtByte: endByte) y
]

{ #category : 'accessing - LSP' }
SmallChatTSRange >> endLine [
	^ (self lineCharacterAtByte: endByte) x
]

{ #category : 'private - encoding' }
SmallChatTSRange >> lineCharacterAtByte: aByteOffset [
	"Map a UTF-8 byte offset into source to LSP {line, character} coords.
	 line is 0-based newline count, character is the UTF-16 code-unit
	 offset since the last newline. Walks source character-by-character;
	 O(n) per call -- fine for v1."
	| line char byteIdx |
	line := 0.
	char := 0.
	byteIdx := 0.
	source do: [ :ch |
		byteIdx >= aByteOffset ifTrue: [ ^ line @ char ].
		ch codePoint = 10
			ifTrue: [
				line := line + 1.
				char := 0.
				byteIdx := byteIdx + 1 ]
			ifFalse: [
				char := char + (self utf16UnitsOfCodePoint: ch codePoint).
				byteIdx := byteIdx + (self utf8ByteSizeOfCodePoint: ch codePoint) ] ].
	^ line @ char
]

{ #category : 'private' }
SmallChatTSRange >> setStartByte: aStartByte endByte: anEndByte source: aString [
	startByte := aStartByte.
	endByte := anEndByte.
	source := aString
]

{ #category : 'accessing' }
SmallChatTSRange >> source [
	^ source
]

{ #category : 'accessing' }
SmallChatTSRange >> startByte [
	^ startByte
]

{ #category : 'accessing - LSP' }
SmallChatTSRange >> startCharacter [
	^ (self lineCharacterAtByte: startByte) y
]

{ #category : 'accessing - LSP' }
SmallChatTSRange >> startLine [
	^ (self lineCharacterAtByte: startByte) x
]

{ #category : 'private - encoding' }
SmallChatTSRange >> utf16UnitsOfCodePoint: aCodePoint [
	"Code units the code point occupies in UTF-16. Astral chars need a
	 surrogate pair (2 units); BMP chars are one unit."
	^ aCodePoint < 16r10000 ifTrue: [ 1 ] ifFalse: [ 2 ]
]

{ #category : 'private - encoding' }
SmallChatTSRange >> utf8ByteSizeOfCodePoint: aCodePoint [
	"Bytes the code point occupies in UTF-8."
	aCodePoint < 16r80 ifTrue: [ ^ 1 ].
	aCodePoint < 16r800 ifTrue: [ ^ 2 ].
	aCodePoint < 16r10000 ifTrue: [ ^ 3 ].
	^ 4
]

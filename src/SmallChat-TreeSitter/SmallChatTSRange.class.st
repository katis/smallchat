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

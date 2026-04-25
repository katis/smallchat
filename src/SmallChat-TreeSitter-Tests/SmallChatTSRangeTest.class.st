Class {
	#name : 'SmallChatTSRangeTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-TreeSitter-Tests',
	#package : 'SmallChat-TreeSitter-Tests'
}

{ #category : 'tests' }
SmallChatTSRangeTest >> testAsLSPPositionRangeShape [
	| range dict source |
	source := 'abcde'.
	range := SmallChatTSRange startByte: 1 endByte: 4 source: source.
	dict := range asLSPPositionRange.
	self assert: ((dict at: 'start') at: 'line') equals: 0.
	self assert: ((dict at: 'start') at: 'character') equals: 1.
	self assert: ((dict at: 'end') at: 'line') equals: 0.
	self assert: ((dict at: 'end') at: 'character') equals: 4
]

{ #category : 'tests' }
SmallChatTSRangeTest >> testAsciiByteOffsetMapsToCharacterOffset [
	"const x = 1; -- equals at byte 8, character 8 (line 0)."
	| range source |
	source := 'const x = 1;'.
	range := SmallChatTSRange startByte: 8 endByte: 9 source: source.
	self assert: range startLine equals: 0.
	self assert: range startCharacter equals: 8.
	self assert: range endLine equals: 0.
	self assert: range endCharacter equals: 9
]

{ #category : 'tests' }
SmallChatTSRangeTest >> testAstralCharIsTwoUtf16CodeUnits [
	"const á½ 0 x = 1; -- the smiley is 4 UTF-8 bytes, surrogate pair (2 UTF-16 units).
	 The = sign sits at byte 12, character 10 (line 0)."
	| range source smiley |
	smiley := (Character codePoint: 16r1F600) asString.
	source := 'const ' , smiley , 'x = 1;'.
	range := SmallChatTSRange startByte: 12 endByte: 13 source: source.
	self assert: range startLine equals: 0.
	self assert: range startCharacter equals: 10.
	self assert: range endCharacter equals: 11
]

{ #category : 'tests' }
SmallChatTSRangeTest >> testBmpNonAsciiBytesAreFewerCodeUnits [
	"const \pi x = 1; -- pi takes 2 UTF-8 bytes but 1 UTF-16 code unit.
	 The = sign sits at byte 10, character 9 (line 0)."
	| range source pi |
	pi := (Character codePoint: 16r03C0) asString.
	source := 'const ' , pi , 'x = 1;'.
	range := SmallChatTSRange startByte: 10 endByte: 11 source: source.
	self assert: range startLine equals: 0.
	self assert: range startCharacter equals: 9.
	self assert: range endCharacter equals: 10
]

{ #category : 'tests' }
SmallChatTSRangeTest >> testNewlineAdvancesLine [
	"newline at byte 5 -- byte 6 is on line 1 column 0."
	| range source |
	source := String new , 'abcde' , (String with: Character lf) , 'xy'.
	range := SmallChatTSRange startByte: 6 endByte: 7 source: source.
	self assert: range startLine equals: 1.
	self assert: range startCharacter equals: 0
]

{ #category : 'tests' }
SmallChatTSRangeTest >> testRoundTripFromLSPPositionRange [
	"Build a range from a Pharo source containing astral chars, emit
	 LSP positions, and reconstruct -- byte offsets must match."
	| smiley source range positions reconstructed |
	smiley := (Character codePoint: 16r1F600) asString.
	source := 'const ' , smiley , 'x = 1;'.
	"Range covers the = sign at byte 12 / character 10."
	range := SmallChatTSRange startByte: 12 endByte: 13 source: source.
	positions := range asLSPPositionRange.
	reconstructed := SmallChatTSRange fromLSPPositionRange: positions source: source.
	self assert: reconstructed startByte equals: range startByte.
	self assert: reconstructed endByte equals: range endByte
]

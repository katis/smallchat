Class {
	#name : 'SmallChatLSPHealthTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-LSP-Tests',
	#package : 'SmallChat-LSP-Tests'
}

{ #category : 'tests' }
SmallChatLSPHealthTest >> testCheckAnswersOsSubprocessAndTsgoPresence [
	"check returns a Dictionary with #ossubprocess (Boolean) and #tsgoPath
	 (FileReference or nil). The exact values depend on the image, but the
	 keys and types are contractual."
	| result |
	result := SmallChatLSPHealth check.
	self assert: (result includesKey: #ossubprocess).
	self assert: ((result at: #ossubprocess) == true or: [ (result at: #ossubprocess) == false ]).
	self assert: (result includesKey: #tsgoPath).
	(result at: #tsgoPath) ifNotNil: [ :p |
		self assert: (p isKindOf: FileReference) ]
]

{ #category : 'tests' }
SmallChatLSPHealthTest >> testReportOnMentionsTsgo [
	"reportOn: writes a human summary that always mentions tsgo, whether or not
	 the binary is present."
	| stream |
	stream := WriteStream on: (String new: 128).
	SmallChatLSPHealth reportOn: stream.
	self assert: (stream contents includesSubstring: 'tsgo')
]

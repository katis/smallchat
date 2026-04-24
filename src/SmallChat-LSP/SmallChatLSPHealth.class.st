Class {
	#name : 'SmallChatLSPHealth',
	#superclass : 'Object',
	#category : 'SmallChat-LSP',
	#package : 'SmallChat-LSP'
}

{ #category : 'checking' }
SmallChatLSPHealth class >> check [
	"Probe dev-image LSP readiness:
	   #ossubprocess -> true if OSSubprocess is loaded (false on the verifier image)
	   #tsgoPath -> the FileReference of the first candidate workspace that has
	      native-preview-darwin-arm64/lib/tsgo installed, or nil
	   #candidates -> the OrderedCollection of FileReferences we probed, for diagnostics"
	| ossPresent candidates tsgoPath envRoot |
	ossPresent := Smalltalk globals includesKey: #OSSUnixSubprocess.
	candidates := OrderedCollection new.
	envRoot := OSEnvironment current at: 'SMALLCHAT_TSGO_WORKSPACE' ifAbsent: [ nil ].
	envRoot ifNotNil: [ candidates add: envRoot asFileReference ].
	candidates
		add: '/Users/katis/code/plan' asFileReference;
		add: '/Users/katis/code/juba' asFileReference.
	tsgoPath := candidates
		collect: [ :root | SmallChatLSPStdioTransport defaultTsgoPathFor: root ]
		thenSelect: [ :p | p exists ].
	^ Dictionary new
		at: #ossubprocess put: ossPresent;
		at: #tsgoPath put: (tsgoPath isEmpty ifTrue: [ nil ] ifFalse: [ tsgoPath first ]);
		at: #candidates put: candidates;
		yourself
]

{ #category : 'checking' }
SmallChatLSPHealth class >> reportCheck: aResult on: aStream [
	"Write a human-readable summary of aResult to aStream. Returns aResult so
	 callers can pipe."
	aStream << 'SmallChat LSP check: '.
	(aResult at: #ossubprocess)
		ifTrue: [ aStream << 'OSSubprocess loaded, ' ]
		ifFalse: [ aStream << 'OSSubprocess missing (verifier image?), ' ].
	(aResult at: #tsgoPath)
		ifNotNil: [ :p | aStream << 'tsgo at '; << p pathString ]
		ifNil: [
			aStream << 'tsgo NOT found.'; cr.
			aStream << 'WARNING: no workspace under the probed candidates has'; cr.
			aStream << '  @typescript/native-preview-darwin-arm64 installed. LSP will not'; cr.
			aStream << '  launch until one does. Set SMALLCHAT_TSGO_WORKSPACE or install'; cr.
			aStream << '  the package under one of:'.
			(aResult at: #candidates) do: [ :root |
				aStream cr; << '    - '; << root pathString ] ].
	aStream cr.
	^ aResult
]

{ #category : 'checking' }
SmallChatLSPHealth class >> reportOn: aStream [
	^ self reportCheck: self check on: aStream
]

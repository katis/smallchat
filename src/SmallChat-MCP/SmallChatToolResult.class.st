"
Value object returned by SmallChatTool subclasses that need to deliver
richer content than a plain String. The registry unwraps an instance
into the MCP tool-result content array via toMcpReplyDict, which for
the debugSession kind yields a full reply (isError + content +
debugSession) instead of the default content-only wrapping.

A tool's #run: may return either a String (treated as text) or a
SmallChatToolResult (text, image, or debugSession).
"
Class {
	#name : #SmallChatToolResult,
	#superclass : #Object,
	#instVars : [
		'kind',
		'mimeType',
		'bytes',
		'text',
		'debugSession'
	],
	#category : #'SmallChat-MCP'
}

{ #category : #'instance creation' }
SmallChatToolResult class >> debugSession: aSmallChatDebugSession [
	^ self new
		debugSession: aSmallChatDebugSession;
		yourself
]

{ #category : #'instance creation' }
SmallChatToolResult class >> image: aByteArray mimeType: aMimeType [
	^ self new
		kind: #image;
		bytes: aByteArray;
		mimeType: aMimeType;
		yourself
]

{ #category : #'instance creation' }
SmallChatToolResult class >> png: aByteArray [
	^ self image: aByteArray mimeType: 'image/png'
]

{ #category : #'instance creation' }
SmallChatToolResult class >> svg: aStringOrBytes [
	^ self image: aStringOrBytes asByteArray mimeType: 'image/svg+xml'
]

{ #category : #'instance creation' }
SmallChatToolResult class >> text: aString [
	^ self new
		kind: #text;
		text: aString;
		yourself
]

{ #category : #accessing }
SmallChatToolResult >> bytes [
	^ bytes
]

{ #category : #accessing }
SmallChatToolResult >> bytes: aByteArray [
	bytes := aByteArray
]

{ #category : #accessing }
SmallChatToolResult >> debugSession [
	^ debugSession
]

{ #category : #accessing }
SmallChatToolResult >> debugSession: aSmallChatDebugSession [
	debugSession := aSmallChatDebugSession.
	kind := #debugSession
]

{ #category : #accessing }
SmallChatToolResult >> kind [
	^ kind
]

{ #category : #accessing }
SmallChatToolResult >> kind: aSymbol [
	kind := aSymbol
]

{ #category : #accessing }
SmallChatToolResult >> mimeType [
	^ mimeType
]

{ #category : #accessing }
SmallChatToolResult >> mimeType: aString [
	mimeType := aString
]

{ #category : #private }
SmallChatToolResult >> stackSummaryFromSession [
	^ [ debugSession debugSession stack first: (10 min: debugSession debugSession stack size) ]
		on: Error
		do: [ :_ | #() ]
]

{ #category : #accessing }
SmallChatToolResult >> text [
	^ text
]

{ #category : #accessing }
SmallChatToolResult >> text: aString [
	text := aString
]

{ #category : #conversion }
SmallChatToolResult >> toMcpContentDict [
	"Return the single-item MCP content dictionary for this result."
	kind = #text ifTrue: [
		^ Dictionary new
			at: 'type' put: 'text';
			at: 'text' put: text asString;
			yourself ].
	kind = #image ifTrue: [
		^ Dictionary new
			at: 'type' put: 'image';
			at: 'mimeType' put: mimeType;
			at: 'data' put: bytes base64Encoded;
			yourself ].
	kind = #debugSession ifTrue: [
		^ Dictionary new
			at: 'type' put: 'text';
			at: 'text' put: '<debug session>';
			yourself ].
	^ self error: 'Unknown SmallChatToolResult kind: ', kind printString
]

{ #category : #conversion }
SmallChatToolResult >> toMcpReplyDict [
	"Return the full MCP reply Dictionary for this result. For the text/image
	 kinds this is a plain {content: [<contentDict>]}. For the debugSession
	 kind it adds isError: true and a debugSession payload the agent can
	 feed directly into the debug_* tools."
	| stack dict |
	kind = #debugSession ifFalse: [
		^ Dictionary new
			at: 'content' put: { self toMcpContentDict };
			yourself ].
	stack := self stackSummaryFromSession.
	dict := Dictionary new
		at: 'id' put: debugSession id;
		at: 'exceptionClass' put: debugSession exception class name asString;
		at: 'messageText' put: (debugSession exception messageText ifNil: [ '' ]);
		at: 'topFrame' put: ([ debugSession debugSession interruptedContext printString ]
			on: Error do: [ :_ | '<unprintable>' ]);
		at: 'stackSummary' put: ((stack collect: [ :ctx |
			[ ctx method methodClass name , '>>' , ctx method selector asString ]
				on: Error do: [ :_ | '<unprintable frame>' ] ]) asArray);
		at: 'hint' put: 'Debugger captured. Inspect with debug_stack / debug_frame / debug_evaluate. Resume with debug_return / debug_proceed / debug_restart. Drop with debug_terminate.';
		yourself.
	^ Dictionary new
		at: 'isError' put: true;
		at: 'content' put: { Dictionary new
			at: 'type' put: 'text';
			at: 'text' put: dict printString;
			yourself };
		at: 'debugSession' put: dict;
		yourself
]

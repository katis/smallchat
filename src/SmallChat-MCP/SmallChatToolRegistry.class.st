"
Registry of tools exposed over MCP. Discovers SmallChatTool subclasses
reflectively, so a new SmallChatTool subclass compiled at runtime via
`evaluate` appears on the next tools/list call automatically.
"
Class {
	#name : #SmallChatToolRegistry,
	#superclass : #Object,
	#instVars : [
		'cachedTools'
	],
	#classVars : [
		'Default'
	],
	#category : #'SmallChat-MCP'
}

{ #category : #accessing }
SmallChatToolRegistry class >> default [
	^ Default ifNil: [ Default := self new ]
]

{ #category : #accessing }
SmallChatToolRegistry class >> reset [
	Default := nil
]

{ #category : #accessing }
SmallChatToolRegistry >> allTools [
	"Reflectively collect a fresh instance of every concrete SmallChatTool subclass."
	^ (SmallChatTool allSubclasses reject: [ :c | c isAbstract ])
		collect: [ :c | c new ]
]

{ #category : #execution }
SmallChatToolRegistry >> errorResult: aString [
	^ Dictionary new
		at: 'isError' put: true;
		at: 'content' put: {
			Dictionary new
				at: 'type' put: 'text';
				at: 'text' put: aString;
				yourself };
		yourself
]

{ #category : #execution }
SmallChatToolRegistry >> run: toolNameString with: argsDictionary [
	"Look up the tool by its MCP name and execute it. Returns a Dictionary
	 shaped as an MCP tool result: {content: [<contentDict>], isError: bool}.
	 The tool's #run: may return a String (treated as text) or a
	 SmallChatToolResult (text or image)."
	| tool rawResult contentDict |
	tool := self toolNamed: toolNameString.
	tool ifNil: [ ^ self errorResult: 'Unknown tool: ', toolNameString ].
	[
		[ rawResult := tool run: (argsDictionary ifNil: [ Dictionary new ]) ]
			on: Notification
			do: [ :n |
				"Suppress unhandled Notifications (deprecation warnings, Metacello
				 progress, etc). Pharo's default notification handler writes to
				 stdout, which would corrupt MCP JSON-RPC framing." n resume ] ]
		on: Error
		do: [ :e | ^ self errorResult: (self safeErrorDescription: e) ].
	contentDict := (rawResult isKindOf: SmallChatToolResult)
		ifTrue: [ rawResult toMcpContentDict ]
		ifFalse: [ Dictionary new
			at: 'type' put: 'text';
			at: 'text' put: (self safeAsString: rawResult);
			yourself ].
	^ Dictionary new
		at: 'content' put: { contentDict };
		yourself
]

{ #category : #execution }
SmallChatToolRegistry >> safeAsString: anObject [
	"Like #asString but guaranteed to return a String. Tools usually return
	 simple strings, but a misbehaving #asString / #printOn: can throw, and
	 we must not let it kill the enclosing MCP response."
	^ [ anObject asString ]
		on: Error
		do: [ :e | '<asString failed: ', e class name, ' ', (e messageText ifNil: [ '' ]), '>' ]
]

{ #category : #execution }
SmallChatToolRegistry >> safeErrorDescription: anException [
	"Format an exception as text for an MCP error response. Guarded because
	 `signalerContext printString` can traverse a deep context graph and
	 recursively invoke user-defined printOn: methods, any of which may
	 raise. If that inner print fails we still must produce a valid reply,
	 otherwise the whole transport-level dispatch throws and the connection
	 is torn down -- taking every concurrent request with it."
	| header |
	header := anException class name, ': ', (anException messageText ifNil: [ '(no message)' ]).
	^ [ String streamContents: [ :s |
			s << header.
			anException signalerContext ifNotNil: [ :ctx |
				s cr; << ctx printString ] ] ]
		on: Error
		do: [ :e | header, ' (context printString failed: ', e class name, ')' ]
]

{ #category : #accessing }
SmallChatToolRegistry >> toolNamed: aString [
	^ self allTools detect: [ :t | t toolName = aString ] ifNone: [ nil ]
]

{ #category : #accessing }
SmallChatToolRegistry >> toolSpecs [
	"Return an Array of Dictionaries describing each tool for tools/list."
	^ self allTools collect: [ :t | t specDictionary ]
]

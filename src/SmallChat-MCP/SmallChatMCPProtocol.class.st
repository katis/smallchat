"
Dispatches MCP JSON-RPC messages to handlers and produces response
Dictionaries. Transport-agnostic: knows nothing about stdin/stdout.
"
Class {
	#name : 'SmallChatMCPProtocol',
	#superclass : 'Object',
	#instVars : [
		'serverInfo'
	],
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'instance creation' }
SmallChatMCPProtocol class >> default [
	^ self new
]

{ #category : 'dispatch' }
SmallChatMCPProtocol >> dispatchMessage: aDictionary [
	"Raw dispatch. Errors here escape to #handleMessage:'s guard."
	| method id params |
	method := aDictionary at: 'method' ifAbsent: [ nil ].
	id := aDictionary at: 'id' ifAbsent: [ nil ].
	params := aDictionary at: 'params' ifAbsent: [ Dictionary new ].

	method ifNil: [ ^ nil ].

	method = 'initialize' ifTrue: [ ^ self replyTo: id with: (self handleInitialize: params) ].
	method = 'notifications/initialized' ifTrue: [ ^ nil ].
	method = 'tools/list' ifTrue: [ ^ self replyTo: id with: (self handleToolsList: params) ].
	method = 'tools/call' ifTrue: [ ^ self replyTo: id with: (self handleToolsCall: params) ].
	method = 'ping' ifTrue: [ ^ self replyTo: id with: Dictionary new ].

	"Unknown method."
	id ifNil: [ ^ nil ].
	^ self errorReplyTo: id code: -32601 message: 'Method not found: ', method
]

{ #category : 'private' }
SmallChatMCPProtocol >> errorReplyTo: id code: code message: message [
	^ Dictionary new
		at: 'jsonrpc' put: '2.0';
		at: 'id' put: id;
		at: 'error' put: (Dictionary new
			at: 'code' put: code;
			at: 'message' put: message;
			yourself);
		yourself
]

{ #category : 'handlers' }
SmallChatMCPProtocol >> handleInitialize: params [
	| clientVersion |
	clientVersion := params at: 'protocolVersion' ifAbsent: [ '2024-11-05' ].
	^ Dictionary new
		at: 'protocolVersion' put: clientVersion;
		at: 'capabilities' put: (Dictionary new
			at: 'tools' put: Dictionary new;
			yourself);
		at: 'serverInfo' put: serverInfo;
		at: 'instructions' put: self instructions;
		yourself
]

{ #category : 'dispatch' }
SmallChatMCPProtocol >> handleMessage: aDictionary [
	"Dispatch one JSON-RPC message. Returns a response Dictionary, or nil
	 if the message was a notification (no reply).

	 Wrapped in an outer error handler so a throw from any handler (or from
	 a deep tool error whose report-rendering fails) can never escape to
	 the transport layer and close the connection -- dropping every other
	 concurrent request with it. On unexpected throw we log and reply with
	 a JSON-RPC internal-error code so the client can continue."
	| id |
	id := aDictionary at: 'id' ifAbsent: [ nil ].
	^ [ self dispatchMessage: aDictionary ]
		on: Error
		do: [ :e |
			SmallChatMCPServer logToFile: 'handleMessage error: ', e class name, ' - ', (e messageText ifNil: [ '' ]).
			id ifNil: [ nil ]
			  ifNotNil: [ self errorReplyTo: id code: -32603 message: 'Internal error: ', e class name ] ]
]

{ #category : 'tools' }
SmallChatMCPProtocol >> handleToolsCall: params [
	"Dispatch via SmallChatMCPCapabilityTransport: capability registry only;
	 unknown names return a typed #error reply."
	| name args |
	name := params at: 'name' ifAbsent: [
		^ Dictionary new
			at: 'isError' put: true;
			at: 'content' put: { Dictionary new
				at: 'type' put: 'text';
				at: 'text' put: 'Missing tool name';
				yourself };
			yourself ].
	args := params at: 'arguments' ifAbsent: [ Dictionary new ].
	^ SmallChatMCPCapabilityTransport default dispatch: name with: args
]

{ #category : 'tools' }
SmallChatMCPProtocol >> handleToolsList: params [
	"Returns one tool spec per registered SmallChatCapability via the
	 transport adapter."
	^ Dictionary new
		at: 'tools' put: SmallChatMCPCapabilityTransport default toolSpecs;
		yourself
]

{ #category : 'initialization' }
SmallChatMCPProtocol >> initialize [
	super initialize.
	serverInfo := Dictionary new
		at: 'name' put: 'smallchat';
		at: 'version' put: '0.1.0';
		yourself
]

{ #category : 'handlers' }
SmallChatMCPProtocol >> instructions [
	"Free-form guidance returned in the initialize response. Clients (e.g.
	 Claude Code) surface this to the model as system-level context, so it's
	 the right place to document capabilities that aren't obvious from the
	 per-tool schemas -- notably the live Smalltalk environment that
	 `evaluate` composes against."
	^ 'smallchat runs a live Pharo 13 Smalltalk image. The MCP surface is intentionally minimal: `evaluate` runs arbitrary Smalltalk with full reflective access. Everything else -- navigating classes, compiling methods, listing packages, snapshotting the image -- is composed on top of `evaluate` using the Pharo selectors documented below. State persists across calls: define classes, mutate globals, build up long-lived sessions.

== Smalltalk code navigation and manipulation ==

All reflection goes through `evaluate`. The image has full Pharo 13
facilities -- Smalltalk globals, SystemNavigation, PackageOrganizer,
Opal. The return value is the final expression''s `printString`.

PREFER ONE BIG SCRIPT OVER MANY SMALL CALLS. Each `evaluate` call is a
round trip; the image is live Smalltalk, so a single script can compose
queries, transform results, and assemble a tailored report in one shot.
Use `| var1 var2 |` locals, `String streamContents: [:s | ... ]` for
formatted output, `Dictionary`/`OrderedCollection` for structured
intermediate state, and normal conditionals/iteration. A 30-line script
that returns exactly the answer you want beats six lookups that each
dump a page of text.

Finding classes:
  Smalltalk globals at: #OrderedCollection ifAbsent: [ nil ]
  SystemNavigation default allClasses                    "every class"

Browsing a class:
  c := Smalltalk globals at: #SmallChatApp.
  c superclass name.  c package name.  c comment.
  c instVarNames.     c class instVarNames.               "class-side"
  c selectors.        c selectorsInProtocol: ''accessing''.

Method source:
  (SmallChatApp class >> #version) sourceCode

Compiling a method (returns the compiled selector as a Symbol):
  SmallChatApp class compile: ''version ^ ''''0.0.1'''''' classified: ''accessing''
  Foo compile: ''greet ^ ''''hi'''''' classified: ''as yet unclassified''

Removing a method:
  Foo removeSelector: #greet
  Foo class removeSelector: #version

Creating a class:
  Object subclass: #Widget
    instanceVariableNames: ''name size''
    classVariableNames: ''''
    package: ''SmallChat''

Listing packages:
  PackageOrganizer default packages collect: [ :p | p name ]
  (PackageOrganizer default packages select: [ :p |
    p name asLowercase includesSubstring: ''smallchat'' ]) collect: #name

Saving the image (does NOT quit -- never pass `andQuit: true`, it would
terminate this MCP server):
  Smalltalk snapshot: true andQuit: false.
  Smalltalk imageFile fullName                           "where it landed"

Example -- one script, not several calls. Find every class in a package
and list its selectors whose name contains ''version'':

  | pkg |
  pkg := PackageOrganizer default packageNamed: ''SmallChat''.
  String streamContents: [ :s |
    pkg definedClasses do: [ :c |
      | hits |
      hits := c selectors select: [ :sel | sel includesSubstring: ''version'' ].
      hits ifNotEmpty: [
        s << c name; << '': ''; print: hits asArray; cr ] ] ]'
]

{ #category : 'private' }
SmallChatMCPProtocol >> replyTo: id with: result [
	^ Dictionary new
		at: 'jsonrpc' put: '2.0';
		at: 'id' put: id;
		at: 'result' put: result;
		yourself
]

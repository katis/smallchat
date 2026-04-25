Class {
	#name : 'SmallChatMCPCapabilityTransport',
	#superclass : 'Object',
	#instVars : [
		'aliases'
	],
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'aliases' }
SmallChatMCPCapabilityTransport >> aliasFor: aLegacyName put: aCapabilityName [
	self aliases at: aLegacyName put: aCapabilityName.
	^ self
]

{ #category : 'aliases' }
SmallChatMCPCapabilityTransport >> aliases [
	"Lazily-initialised dict from legacy bare name -> prefixed capability name.
	 MCP-only -- the LM transport never inherits aliases."
	^ aliases ifNil: [ aliases := Dictionary new ]
]

{ #category : 'dispatching' }
SmallChatMCPCapabilityTransport >> dispatch: aName with: anArgsDict [
	"Look up aName (after alias resolution) in the capability registry,
	 run, and translate the result to the MCP tools/call reply shape.
	 Falls through to the legacy SmallChatToolRegistry while the 16 tools
	 migrate one at a time."
	| resolved call result |
	resolved := self resolveAlias: aName.
	call := SmallChatCapabilityCall
		name: resolved
		argumentsJson: (STONJSON toString: anArgsDict).
	result := SmallChatCapabilityRegistry default run: resolved with: call.
	result ifNotNil: [ ^ self mcpReplyFor: result ].
	^ SmallChatToolRegistry default run: aName with: anArgsDict
]

{ #category : 'private' }
SmallChatMCPCapabilityTransport >> mcpDebugReplyFor: aSmallChatDebugSession [
	"Build the MCP reply for a captured debug session: isError, a printable
	 content body, and the debugSession metadata the agent uses to drive
	 debug.* capabilities. Mirrors SmallChatToolResult>>toMcpReplyDict."
	| stack dict |
	stack := [ aSmallChatDebugSession debugSession stack
		first: (10 min: aSmallChatDebugSession debugSession stack size) ]
		on: Error do: [ :_ | #() ].
	dict := Dictionary new
		at: 'id' put: aSmallChatDebugSession id;
		at: 'exceptionClass' put: aSmallChatDebugSession exception class name asString;
		at: 'messageText' put: (aSmallChatDebugSession exception messageText ifNil: [ '' ]);
		at: 'topFrame' put: ([ aSmallChatDebugSession debugSession interruptedContext printString ]
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

{ #category : 'private' }
SmallChatMCPCapabilityTransport >> mcpReplyFor: aResult [
	"Translate a SmallChatCapabilityResult to the MCP tools/call reply dict.
	 Mirrors today's SmallChatToolResult shapes."
	| kind |
	kind := aResult kind.
	(kind = #text or: [ kind = #error ]) ifTrue: [
		| reply |
		reply := Dictionary new
			at: 'content' put: { Dictionary new
				at: 'type' put: 'text';
				at: 'text' put: aResult text;
				yourself };
			yourself.
		kind = #error ifTrue: [ reply at: 'isError' put: true ].
		^ reply ].
	kind = #image ifTrue: [
		^ Dictionary new
			at: 'content' put: { Dictionary new
				at: 'type' put: 'image';
				at: 'mimeType' put: aResult mimeType;
				at: 'data' put: (Base64MimeConverter mimeEncode: aResult bytes readStream) contents;
				yourself };
			yourself ].
	kind = #debugSession ifTrue: [ ^ self mcpDebugReplyFor: aResult debugSession ].
	self error: 'mcpReplyFor: not yet implemented for kind ' , kind printString
]

{ #category : 'aliases' }
SmallChatMCPCapabilityTransport >> resolveAlias: aName [
	"Map a name through the alias dict. Returns the original name if no
	 alias is registered."
	^ self aliases at: aName ifAbsent: [ aName ]
]

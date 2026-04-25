Class {
	#name : 'SmallChatMCPCapabilityTransport',
	#superclass : 'Object',
	#instVars : [
		'debuggerWatch'
	],
	#classInstVars : [
		'default'
	],
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing' }
SmallChatMCPCapabilityTransport class >> default [
	"Singleton instance. Reset via #reset for tests."
	^ default ifNil: [ default := self new ]
]

{ #category : 'accessing' }
SmallChatMCPCapabilityTransport class >> reset [
	"Test seam: drop the cached singleton."
	default := nil
]

{ #category : 'stray-debugger' }
SmallChatMCPCapabilityTransport >> debuggerWatch [
	"Block returning Array of stray-debugger descriptors. Defaults to the
	 live-world query; tests inject their own via #debuggerWatch:."
	^ debuggerWatch ifNil: [ debuggerWatch := [ SmallChatDebuggerWatch openWindows ] ]
]

{ #category : 'stray-debugger' }
SmallChatMCPCapabilityTransport >> debuggerWatch: aBlock [
	debuggerWatch := aBlock
]

{ #category : 'stray-debugger' }
SmallChatMCPCapabilityTransport >> decorateReply: aReplyDict withStray: descriptors [
	"Prepend a single-line warning about stray debugger windows to the first
	 content text item. No-op when descriptors is empty."
	| prefix content first text |
	descriptors isEmpty ifTrue: [ ^ aReplyDict ].
	prefix := '[smallchat: ' , descriptors size asString ,
		' stray Pharo UI debugger window(s) open -- these block the dev image''s UI process. ',
		'Dismiss via: SmallChatDebuggerWatch closeAll]' , String lf , String lf.
	content := aReplyDict at: 'content' ifAbsent: [ ^ aReplyDict ].
	content isEmpty ifTrue: [ ^ aReplyDict ].
	first := content first.
	(first at: 'type' ifAbsent: [ nil ]) = 'text' ifFalse: [ ^ aReplyDict ].
	text := first at: 'text' ifAbsent: [ '' ].
	first at: 'text' put: prefix , text.
	^ aReplyDict
]

{ #category : 'dispatching' }
SmallChatMCPCapabilityTransport >> dispatch: aName with: anArgsDict [
	"Dispatch via the capability registry, translate the result to MCP shape,
	 decorate with stray-debugger warning. Unknown names return an #error reply."
	| call result reply stray |
	stray := [ self debuggerWatch value ] on: Error do: [ :_ | #() ].
	call := SmallChatCapabilityCall
		name: aName
		argumentsJson: (STONJSON toString: anArgsDict).
	result := SmallChatCapabilityRegistry default run: aName with: call.
	result ifNil: [
		result := SmallChatCapabilityResult error: 'Unknown capability: ' , aName ].
	reply := self mcpReplyFor: result.
	^ self decorateReply: reply withStray: stray
]

{ #category : 'private' }
SmallChatMCPCapabilityTransport >> mcpDebugReplyFor: aSmallChatDebugSession [
	"Build the MCP reply for a captured debug session: isError, a printable
	 content body, and the debugSession metadata the agent uses to drive
	 debug.* capabilities."
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
		at: 'hint' put: 'Debugger captured. Inspect with debug.stack / debug.frame / debug.evaluate. Resume with debug.return / debug.proceed / debug.restart. Drop with debug.terminate.';
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
	"Translate a SmallChatCapabilityResult to the MCP tools/call reply dict."
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

{ #category : 'tools-list' }
SmallChatMCPCapabilityTransport >> specDictForCapability: aCapability [
	"One spec dict per capability: name + description + inputSchema."
	^ Dictionary new
		at: 'name' put: aCapability capabilityName;
		at: 'description' put: aCapability description;
		at: 'inputSchema' put: aCapability schema asJsonSchema;
		yourself
]

{ #category : 'tools-list' }
SmallChatMCPCapabilityTransport >> toolSpecs [
	"One spec per registered production capability. Test fixtures filter via
	 #isTestFixture."
	| specs |
	specs := OrderedCollection new.
	SmallChatCapabilityRegistry default allCapabilities do: [ :cap |
		cap isTestFixture ifFalse: [
			specs add: (self specDictForCapability: cap) ] ].
	^ specs asArray
]

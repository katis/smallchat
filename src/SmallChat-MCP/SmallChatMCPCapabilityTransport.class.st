Class {
	#name : 'SmallChatMCPCapabilityTransport',
	#superclass : 'Object',
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'dispatching' }
SmallChatMCPCapabilityTransport >> dispatch: aName with: anArgsDict [
	"Look up aName in the capability registry, run, and translate the result
	 to the MCP tools/call reply shape. Returns nil if no capability matches
	 -- transports decide whether to surface an error or fall through to a
	 legacy registry."
	| call result |
	call := SmallChatCapabilityCall
		name: aName
		argumentsJson: (STONJSON toString: anArgsDict).
	result := SmallChatCapabilityRegistry default run: aName with: call.
	result ifNil: [ ^ nil ].
	^ self mcpReplyFor: result
]

{ #category : 'private' }
SmallChatMCPCapabilityTransport >> mcpReplyFor: aResult [
	"Translate a SmallChatCapabilityResult to the MCP tools/call reply dict
	 ({content: [...], isError? }). Mirrors today's SmallChatToolResult
	 toMcpReplyDict / SmallChatToolRegistry errorResult: shapes."
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
	self error: 'mcpReplyFor: not yet implemented for kind ' , kind printString
]

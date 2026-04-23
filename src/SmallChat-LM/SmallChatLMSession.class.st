"
Controller for one chat session: holds the conversation + client and
exposes #sendUserInput: as the one-turn-at-a-time seam the UI drives.
Kept separate from the Spec2 window so the behaviour is testable without
Morphic / Spec2 / UI-process concerns.

Future tool-call loop will live here (#sendUserInput: would iterate while
the returned assistant message carries tool calls, dispatching them and
appending tool-result messages before the next #complete:).
"
Class {
	#name : 'SmallChatLMSession',
	#superclass : 'Object',
	#instVars : [
		'conversation',
		'client'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'accessing' }
SmallChatLMSession >> client [
	^ client
]

{ #category : 'accessing' }
SmallChatLMSession >> client: anLMClient [
	client := anLMClient
]

{ #category : 'accessing' }
SmallChatLMSession >> conversation [
	^ conversation
]

{ #category : 'tool dispatch' }
SmallChatLMSession >> dispatchToolCall: aToolCall [
	| tool |
	tool := self toolFor: aToolCall.
	tool ifNil: [ ^ 'Error: unknown tool ' , aToolCall name printString ].
	^ tool runWithArgumentsJSON: aToolCall arguments
]

{ #category : 'initialization' }
SmallChatLMSession >> initialize [
	| prompt |
	super initialize.
	conversation := SmallChatLMConversation new.
	prompt := SmallChatConfig systemPrompt.
	(prompt isNil or: [ prompt isEmpty ]) ifFalse: [ conversation addSystem: prompt ].
	client := SmallChatLMChatClient new
]

{ #category : 'tool dispatch' }
SmallChatLMSession >> maxToolIterations [
	"Per-turn budget on tool-call rounds before the loop gives up and inserts
	 a synthetic error message. Tight enough to stop runaway loops, loose
	 enough to support a handful of honest tool hops in one answer."
	^ 8
]

{ #category : 'chat' }
SmallChatLMSession >> sendUserInput: aString [
	"Append the user turn, call the client, then loop as long as the reply
	 carries tool_calls: dispatch each, append tool-result messages, call
	 again. Gives up after maxToolIterations rounds. Returns the final
	 assistant message (always a content-bearing one, modulo the synthetic
	 budget-exhausted stub)."
	| reply iterations |
	(aString isNil or: [ aString isEmpty ]) ifTrue: [ ^ nil ].
	conversation addUser: aString.
	reply := client complete: conversation.
	conversation addMessage: reply.
	iterations := 0.
	[ reply toolCalls notNil and: [ reply toolCalls notEmpty ] ] whileTrue: [
		iterations := iterations + 1.
		iterations > self maxToolIterations ifTrue: [
			| synthetic |
			synthetic := SmallChatLMMessage
				role: #assistant
				content: 'Error: tool-call budget (' , self maxToolIterations printString , ' rounds) exhausted.'.
			conversation addMessage: synthetic.
			^ synthetic ].
		reply toolCalls do: [ :tc |
			conversation addTool: (self dispatchToolCall: tc) forCallId: tc id ].
		reply := client complete: conversation.
		conversation addMessage: reply ].
	^ reply
]

{ #category : 'chat' }
SmallChatLMSession >> sendUserInput: aString onDelta: aOneArgBlock [
	"Streaming variant of sendUserInput:. Drives client complete:onDelta: in the
	 same tool-dispatch loop, forwarding content deltas to aOneArgBlock between
	 tool rounds. Returns the final assistant message."
	| reply iterations |
	(aString isNil or: [ aString isEmpty ]) ifTrue: [ ^ nil ].
	conversation addUser: aString.
	reply := client complete: conversation onDelta: aOneArgBlock.
	conversation addMessage: reply.
	iterations := 0.
	[ reply toolCalls notNil and: [ reply toolCalls notEmpty ] ] whileTrue: [
		iterations := iterations + 1.
		iterations > self maxToolIterations ifTrue: [
			| synthetic |
			synthetic := SmallChatLMMessage
				role: #assistant
				content: 'Error: tool-call budget (' , self maxToolIterations printString , ' rounds) exhausted.'.
			conversation addMessage: synthetic.
			^ synthetic ].
		reply toolCalls do: [ :tc |
			conversation addTool: (self dispatchToolCall: tc) forCallId: tc id ].
		reply := client complete: conversation onDelta: aOneArgBlock.
		conversation addMessage: reply ].
	^ reply
]

{ #category : 'tool dispatch' }
SmallChatLMSession >> toolFor: aToolCall [
	"Dispatch target lookup. Only #evaluate is wired today; anything else
	 surfaces as a descriptive error string on the tool-result message so
	 the model can course-correct instead of the session silently stalling."
	aToolCall name = 'evaluate' ifTrue: [ ^ SmallChatLMEvaluateTool new ].
	^ nil
]

{ #category : 'rendering' }
SmallChatLMSession >> transcriptText [
	^ String streamContents: [ :s |
		conversation messages do: [ :msg |
			s
				nextPutAll: msg role asString;
				nextPutAll: ': ';
				nextPutAll: msg content;
				nextPut: Character lf;
				nextPut: Character lf ] ]
]

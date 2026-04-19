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

{ #category : 'initialization' }
SmallChatLMSession >> initialize [
	super initialize.
	conversation := SmallChatLMConversation new.
	client := SmallChatLMCompletionsClient new
]

{ #category : 'chat' }
SmallChatLMSession >> sendUserInput: aString [
	"Append the user turn, ask the client for the next assistant turn,
	 append that too. Returns the assistant message (nil if aString is
	 empty -- an empty submission is a no-op rather than an error, since
	 the UI's send button may fire on blank input)."
	| reply |
	(aString isNil or: [ aString isEmpty ]) ifTrue: [ ^ nil ].
	conversation addUser: aString.
	reply := client complete: conversation.
	conversation addMessage: reply.
	^ reply
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

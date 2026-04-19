"
Qwen 3 / Qwen 2.5 chat template. Emits <|im_start|>ROLE\nCONTENT<|im_end|>
turns and ends with an <|im_start|>assistant\n generation cue. Stop token:
<|im_end|>.

Not implemented yet (deliberate -- future slices): qwen3 thinking-mode
(<think>...</think>) and tool-call schema injection into the system turn.
Both belong in this class when we reach them.
"
Class {
	#name : 'SmallChatLMQwen3PromptTemplate',
	#superclass : 'SmallChatLMPromptTemplate',
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'rendering' }
SmallChatLMQwen3PromptTemplate >> render: aConversation [
	^ String streamContents: [ :s |
		aConversation messages do: [ :msg |
			s
				nextPutAll: '<|im_start|>';
				nextPutAll: msg role asString;
				nextPut: Character lf;
				nextPutAll: msg content;
				nextPutAll: '<|im_end|>';
				nextPut: Character lf ].
		s
			nextPutAll: '<|im_start|>assistant';
			nextPut: Character lf ]
]

{ #category : 'accessing' }
SmallChatLMQwen3PromptTemplate >> stopTokens [
	^ #('<|im_end|>')
]

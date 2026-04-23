"
In-chat evaluate tool. Class-side exposes the OpenAI tool
schema the chat client sends to the model; instance-side dispatches
a parsed tool call by compiling+evaluating the supplied Smalltalk
source and returning its printString (or an error string on
exception). Never opens the Pharo UI debugger -- all exceptions are
caught and stringified, per the chat loop's no-debugger contract.
"
Class {
	#name : 'SmallChatLMEvaluateTool',
	#superclass : 'Object',
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'schema' }
SmallChatLMEvaluateTool class >> toolSchema [
	"OpenAI-compatible function schema for the chat client to pass in the
	 tools array. Single argument #code carries a Smalltalk expression that
	 will be compiled + evaluated in the live image."
	| codeProp props params fn |
	codeProp := Dictionary new
		at: 'type' put: 'string';
		at: 'description' put: 'Smalltalk expression to evaluate in the live Pharo image; the return value printString is the tool result.';
		yourself.
	props := Dictionary new at: 'code' put: codeProp; yourself.
	params := Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: props;
		at: 'required' put: #('code');
		yourself.
	fn := Dictionary new
		at: 'name' put: 'evaluate';
		at: 'description' put: 'Evaluate Smalltalk code in the live Pharo image. Returns the result printString, or an error string on exception.';
		at: 'parameters' put: params;
		yourself.
	^ Dictionary new
		at: 'type' put: 'function';
		at: 'function' put: fn;
		yourself
]

{ #category : 'dispatch' }
SmallChatLMEvaluateTool >> runWithArgumentsJSON: aJsonString [
	"Parse {code: ...} from aJsonString, compile + evaluate the Smalltalk
	 source, return the result printString. Any exception (parse, compile,
	 runtime) is caught and rendered as a short error string so the chat
	 loop never parks a process or opens the UI debugger."
	| parsed code result |
	^ [
		parsed := STONJSON fromString: aJsonString.
		code := parsed at: 'code' ifAbsent: [ ^ 'Error: missing "code" argument' ].
		result := OpalCompiler new source: code; evaluate.
		result printString ]
	on: Exception
	do: [ :ex | 'Error: ' , ex class name , ': ' , ex messageText asString ]
]

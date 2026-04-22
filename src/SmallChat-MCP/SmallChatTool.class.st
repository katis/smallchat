"
Abstract base for MCP tools exposed by the smallchat bridge.
Each subclass describes itself (name, description, JSON schema)
and implements #run: to execute the tool in the live image.

#run: may return either a String (treated by the registry as a text
result) or a SmallChatToolResult instance (text or image). No other
return types are supported; anything else goes through #asString.
"
Class {
	#name : 'SmallChatTool',
	#superclass : 'Object',
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing - metadata' }
SmallChatTool class >> description [
	^ self subclassResponsibility
]

{ #category : 'accessing - metadata' }
SmallChatTool class >> inputSchema [
	"A Dictionary that will be written as JSON Schema in tools/list."
	^ self subclassResponsibility
]

{ #category : 'testing' }
SmallChatTool class >> isAbstract [
	^ self == SmallChatTool
]

{ #category : 'accessing - metadata' }
SmallChatTool class >> toolName [
	^ self subclassResponsibility
]

{ #category : 'accessing - metadata' }
SmallChatTool >> description [
	^ self class description
]

{ #category : 'accessing - metadata' }
SmallChatTool >> inputSchema [
	^ self class inputSchema
]

{ #category : 'execution' }
SmallChatTool >> run: aDictionary [
	"Execute the tool with the given arguments. Subclasses must implement.
	 Return a String (treated as text) or a SmallChatToolResult."
	^ self subclassResponsibility
]

{ #category : 'accessing - metadata' }
SmallChatTool >> specDictionary [
	^ Dictionary new
		at: 'name' put: self toolName;
		at: 'description' put: self description;
		at: 'inputSchema' put: self inputSchema;
		yourself
]

{ #category : 'accessing - metadata' }
SmallChatTool >> toolName [
	^ self class toolName
]

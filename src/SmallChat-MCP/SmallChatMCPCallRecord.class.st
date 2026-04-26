"
Frozen record of one MCP tools/call invocation: the JSON-RPC id, the
tool name, the request arguments (JSON String), the rendered output
text, an error flag, and the dispatch duration. Built by the TCP
server after each tools/call dispatches; appended to the originating
SmallChatMCPConnection's calls log and broadcast via
SmallChatMCPToolCallRecorded.

Non-tools/call methods (initialize, tools/list, ping, notifications)
are filtered out by the class-side builder.
"
Class {
	#name : 'SmallChatMCPCallRecord',
	#superclass : 'Object',
	#instVars : [
		'requestId',
		'name',
		'argumentsJson',
		'resultText',
		'isError',
		'durationMs',
		'recordedAt'
	],
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'instance creation' }
SmallChatMCPCallRecord class >> from: aRequestDict response: aResponseDict durationMs: aMs [
    "Build a SmallChatMCPCallRecord from one parsed JSON-RPC tools/call
     request and its rendered response. Returns nil for any other method
     (initialize, tools/list, ping, notifications) so the recorder can
     skip them. Tool errors land via either the JSON-RPC error channel
     (transport-level failure) or result.isError = true (capability
     returned an error reply); both surface as isError."
    | method params result error toolText content first toolIsError |
    method := aRequestDict at: 'method' ifAbsent: [ nil ].
    method = 'tools/call' ifFalse: [ ^ nil ].
    params := aRequestDict at: 'params' ifAbsent: [ Dictionary new ].
    result := aResponseDict at: 'result' ifAbsent: [ nil ].
    error := aResponseDict at: 'error' ifAbsent: [ nil ].
    toolText := ''.
    toolIsError := false.
    error notNil ifTrue: [
        toolIsError := true.
        toolText := error at: 'message' ifAbsent: [ '' ] ].
    result notNil ifTrue: [
        toolIsError := (result at: 'isError' ifAbsent: [ false ]) == true.
        content := result at: 'content' ifAbsent: [ #() ].
        content isEmpty ifFalse: [
            first := content first.
            (first at: 'type' ifAbsent: [ nil ]) = 'text'
                ifTrue: [ toolText := first at: 'text' ifAbsent: [ '' ] ]
                ifFalse: [ toolText := first printString ] ] ].
    ^ self new
        setRequestId: (aRequestDict at: 'id' ifAbsent: [ nil ])
        name: (params at: 'name' ifAbsent: [ '' ])
        argumentsJson: (STONJSON toString: (params at: 'arguments' ifAbsent: [ Dictionary new ]))
        resultText: toolText
        isError: toolIsError
        durationMs: aMs
        recordedAt: DateAndTime now
]

{ #category : 'accessing' }
SmallChatMCPCallRecord >> argumentsJson [ ^ argumentsJson
]

{ #category : 'accessing' }
SmallChatMCPCallRecord >> durationMs [ ^ durationMs
]

{ #category : 'testing' }
SmallChatMCPCallRecord >> isError [ ^ isError == true
]

{ #category : 'accessing' }
SmallChatMCPCallRecord >> name [ ^ name
]

{ #category : 'accessing' }
SmallChatMCPCallRecord >> recordedAt [ ^ recordedAt
]

{ #category : 'accessing' }
SmallChatMCPCallRecord >> requestId [ ^ requestId
]

{ #category : 'accessing' }
SmallChatMCPCallRecord >> resultText [ ^ resultText
]

{ #category : 'private' }
SmallChatMCPCallRecord >> setRequestId: anIdOrNil name: aName argumentsJson: aJson resultText: aText isError: aBool durationMs: aMs recordedAt: aDateAndTime [
    requestId := anIdOrNil.
    name := aName.
    argumentsJson := aJson.
    resultText := aText.
    isError := aBool.
    durationMs := aMs.
    recordedAt := aDateAndTime
]

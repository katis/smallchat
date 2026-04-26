Class {
	#name : 'SmallChatMCPCallRecordTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatMCPCallRecordTest >> testIgnoresNonToolsCall [
    | req resp |
    req := Dictionary new
        at: 'method' put: 'ping';
        at: 'id' put: 7;
        yourself.
    resp := Dictionary new at: 'result' put: Dictionary new; yourself.
    self assert: (SmallChatMCPCallRecord from: req response: resp durationMs: 1) isNil
]

{ #category : 'tests' }
SmallChatMCPCallRecordTest >> testRecordsJsonRpcError [
    | req resp record |
    req := Dictionary new
        at: 'method' put: 'tools/call';
        at: 'id' put: 12;
        at: 'params' put: (Dictionary new
            at: 'name' put: 'broken';
            at: 'arguments' put: Dictionary new;
            yourself);
        yourself.
    resp := Dictionary new
        at: 'error' put: (Dictionary new
            at: 'code' put: -32603;
            at: 'message' put: 'Internal error: Foo';
            yourself);
        yourself.
    record := SmallChatMCPCallRecord from: req response: resp durationMs: 9.
    self assert: record isError.
    self assert: record resultText equals: 'Internal error: Foo'
]

{ #category : 'tests' }
SmallChatMCPCallRecordTest >> testRecordsSuccessfulToolsCall [
    | req resp record |
    req := Dictionary new
        at: 'method' put: 'tools/call';
        at: 'id' put: 11;
        at: 'params' put: (Dictionary new
            at: 'name' put: 'eval.smalltalk';
            at: 'arguments' put: (Dictionary new at: 'code' put: '42'; yourself);
            yourself);
        yourself.
    resp := Dictionary new
        at: 'result' put: (Dictionary new
            at: 'content' put: { Dictionary new
                at: 'type' put: 'text';
                at: 'text' put: '42';
                yourself };
            yourself);
        yourself.
    record := SmallChatMCPCallRecord from: req response: resp durationMs: 5.
    self assert: record requestId equals: 11.
    self assert: record name equals: 'eval.smalltalk'.
    self assert: (record argumentsJson includesSubstring: '42').
    self assert: record resultText equals: '42'.
    self deny: record isError.
    self assert: record durationMs equals: 5.
    self assert: record recordedAt isNotNil
]

{ #category : 'tests' }
SmallChatMCPCallRecordTest >> testRecordsToolErrorResult [
    "result.isError = true means the capability returned an error reply while still
     going through the success channel of JSON-RPC."
    | req resp record |
    req := Dictionary new
        at: 'method' put: 'tools/call';
        at: 'id' put: 13;
        at: 'params' put: (Dictionary new
            at: 'name' put: 'eval.smalltalk';
            at: 'arguments' put: Dictionary new;
            yourself);
        yourself.
    resp := Dictionary new
        at: 'result' put: (Dictionary new
            at: 'content' put: { Dictionary new
                at: 'type' put: 'text';
                at: 'text' put: 'Unknown capability: nope';
                yourself };
            at: 'isError' put: true;
            yourself);
        yourself.
    record := SmallChatMCPCallRecord from: req response: resp durationMs: 1.
    self assert: record isError.
    self assert: record resultText equals: 'Unknown capability: nope'
]

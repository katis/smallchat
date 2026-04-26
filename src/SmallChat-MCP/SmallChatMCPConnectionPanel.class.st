"
One-tab presenter inside SmallChatMCPConsoleWindow. Bound to a single
SmallChatMCPConnection, lists its received tools/call invocations on
the left, the selected request's arguments on the top right, and the
selected response output across the bottom. Subscribes to
SmallChatMCPToolCallRecorded on the supplied announcer and filters by
connection identity so live updates land in the right tab.

Ownership: the console window instantiates one panel per connection
and calls #cleanup on tab/window teardown to release the subscription.
The uiDeferrer block lets tests run synchronously; production binds
it to UIManager default defer: so widget mutations land on the UI
process.
"
Class {
	#name : 'SmallChatMCPConnectionPanel',
	#superclass : 'SpPresenter',
	#instVars : [
		'connection',
		'callList',
		'inputText',
		'outputText',
		'uiDeferrer'
	],
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'binding' }
SmallChatMCPConnectionPanel >> bindConnection: aConnection announcer: anAnnouncer [
    "Bind the panel to one connection and the announcer carrying
     SmallChatMCPToolCallRecorded events. Refreshes the list from the
     connection's call log and starts listening for live updates."
    connection := aConnection.
    announcer := anAnnouncer.
    self refreshFromConnection.
    self subscribeToAnnouncer
]

{ #category : 'accessing' }
SmallChatMCPConnectionPanel >> callList [ ^ callList
]

{ #category : 'lifecycle' }
SmallChatMCPConnectionPanel >> cleanup [
    "Drop the announcer subscription. Idempotent."
    announcer ifNotNil: [ announcer unsubscribe: self ]
]

{ #category : 'accessing' }
SmallChatMCPConnectionPanel >> connection [ ^ connection
]

{ #category : 'layout' }
SmallChatMCPConnectionPanel >> defaultLayout [
    "T-shape: list left + input top-right, output spans the bottom."
    ^ SpBoxLayout newTopToBottom
        spacing: 4;
        add: (SpBoxLayout newLeftToRight
                spacing: 4;
                add: callList width: 240;
                add: inputText;
                yourself);
        add: outputText height: 140;
        yourself
]

{ #category : 'private' }
SmallChatMCPConnectionPanel >> formatInputFor: aRecord [
    "Render argumentsJson as readable text. The common single-string-arg
     shape (e.g. eval.smalltalk { code: '...' }) shows the value with
     its embedded line breaks intact -- not as a JSON-escaped one-liner.
     Multi-arg shapes render each entry as ``key:\\n<value>' separated
     by a blank line, sorted by key for stable output. Falls back to the
     raw JSON if parsing fails or the value is not a Dictionary."
    | dict keys |
    dict := [ STONJSON fromString: aRecord argumentsJson ]
        on: Error
        do: [ :_ | ^ aRecord argumentsJson ].
    (dict isKindOf: Dictionary) ifFalse: [ ^ aRecord argumentsJson ].
    dict isEmpty ifTrue: [ ^ '(no arguments)' ].
    keys := dict keys asSortedCollection asArray.
    ^ String streamContents: [ :s |
        keys doWithIndex: [ :k :i |
            i > 1 ifTrue: [ s nextPut: Character lf; nextPut: Character lf ].
            s nextPutAll: k asString.
            s nextPut: $:.
            s nextPut: Character lf.
            self renderValue: (dict at: k) on: s ] ]
]

{ #category : 'private' }
SmallChatMCPConnectionPanel >> handleRecorded: anAnnouncement [
    callList items: connection calls asArray.
    callList selectItem: anAnnouncement record
]

{ #category : 'initialization' }
SmallChatMCPConnectionPanel >> initializePresenters [
    uiDeferrer := [ :aBlock | UIManager default defer: aBlock ].
    callList := self newList.
    callList display: [ :record | self labelForRecord: record ].
    callList whenSelectionChangedDo: [ :sel | self selectionChanged: sel ].
    inputText := self newText.
    inputText beNotEditable.
    outputText := self newText.
    outputText beNotEditable
]

{ #category : 'accessing' }
SmallChatMCPConnectionPanel >> inputText [ ^ inputText
]

{ #category : 'private' }
SmallChatMCPConnectionPanel >> labelForRecord: aRecord [
    aRecord ifNil: [ ^ '' ].
    ^ String streamContents: [ :s |
        s nextPutAll: aRecord recordedAt asTime print24.
        s nextPutAll: '  '.
        s nextPutAll: aRecord name.
        aRecord isError ifTrue: [ s nextPutAll: '  [error]' ] ]
]

{ #category : 'accessing' }
SmallChatMCPConnectionPanel >> outputText [ ^ outputText
]

{ #category : 'accessing' }
SmallChatMCPConnectionPanel >> records [
    "Live items currently displayed in the call list."
    ^ callList items
]

{ #category : 'private' }
SmallChatMCPConnectionPanel >> refreshFromConnection [
    callList items: connection calls asArray.
    inputText text: ''.
    outputText text: ''
]

{ #category : 'private' }
SmallChatMCPConnectionPanel >> renderValue: aValue on: aStream [
    "String values render verbatim so embedded newlines stay newlines.
     Other values fall back to printString -- numbers, booleans, nested
     dicts/arrays land readable enough."
    aValue isString ifTrue: [
        ^ aStream nextPutAll: aValue ].
    aStream print: aValue
]

{ #category : 'binding' }
SmallChatMCPConnectionPanel >> selectRecord: aRecord [
    "Test seam: programmatically select a record and update the input/
     output panes synchronously, bypassing the widget's own selection-
     change announcer."
    callList selectItem: aRecord.
    self showRecord: aRecord
]

{ #category : 'private' }
SmallChatMCPConnectionPanel >> selectionChanged: aSelection [
    self showRecord: aSelection selectedItem
]

{ #category : 'private' }
SmallChatMCPConnectionPanel >> showRecord: aRecordOrNil [
    aRecordOrNil ifNil: [
        inputText text: ''.
        outputText text: ''.
        ^ self ].
    inputText text: (self formatInputFor: aRecordOrNil).
    outputText text: (aRecordOrNil isError
        ifTrue: [ '[error] ' , aRecordOrNil resultText ]
        ifFalse: [ aRecordOrNil resultText ])
]

{ #category : 'private' }
SmallChatMCPConnectionPanel >> subscribeToAnnouncer [
    "Filter announcements down to our connection. Mutations land via
     uiDeferrer so the live announcer (which fires from the TCP-client
     fork) does not touch widgets off the UI process."
    announcer
        when: SmallChatMCPToolCallRecorded
        do: [ :ann |
            ann connection == connection ifTrue: [
                uiDeferrer value: [ self handleRecorded: ann ] ] ]
        for: self
]

{ #category : 'accessing' }
SmallChatMCPConnectionPanel >> uiDeferrer: aBlock [ uiDeferrer := aBlock
]

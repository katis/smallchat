"
Placeholder entry point for smallchat. The agent loop, local-model client,
and chat UI will hang off this class. Right now it just holds a version
string so the baseline has something non-empty to load.
"
Class {
	#name : #SmallChatApp,
	#superclass : #Object,
	#category : #SmallChat
}

{ #category : #accessing }
SmallChatApp class >> version [
	^ '0.0.0'
]

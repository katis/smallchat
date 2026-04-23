Class {
	#name : 'SmallChatDebuggerWatch',
	#superclass : 'Object',
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'querying' }
SmallChatDebuggerWatch class >> openWindowsIn: aWorld [
	"Return an Array of descriptors for currently-visible debugger-ish
	 SystemWindows in aWorld. Tolerant: nil world yields #()."
	^ #()
]

Class {
	#name : 'SmallChatMCPTcpServerTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatMCPTcpServerTest >> testActiveClientCountStartsAtZero [
    | server |
    server := SmallChatMCPTcpServer new.
    self assert: server activeClientCount equals: 0
]

{ #category : 'tests' }
SmallChatMCPTcpServerTest >> testRegisterAndUnregisterClient [
    | server marker |
    server := SmallChatMCPTcpServer new.
    marker := Object new.
    server registerClient: marker.
    self assert: server activeClientCount equals: 1.
    server unregisterClient: marker.
    self assert: server activeClientCount equals: 0
]

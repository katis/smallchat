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

Class {
	#name : 'SmallChatMCPTcpServerRaisingStub',
	#superclass : 'SmallChatMCPTcpServer',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'testing' }
SmallChatMCPTcpServerRaisingStub >> runClientSessionOn: clientSocket [
	"Simulate a JSON-RPC loop that raises midway."
	Error signal: 'simulated-session-failure'
]

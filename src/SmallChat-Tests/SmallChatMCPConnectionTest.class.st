Class {
	#name : 'SmallChatMCPConnectionTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatMCPConnectionTest >> testLifecycle [
    "A fresh connection has a monotonic id, a stamped openedAt, an empty
     calls log, and is not closed. markClosed stamps closedAt and flips
     isClosed."
    | a b sock |
    sock := Object new.
    a := SmallChatMCPConnection on: sock.
    b := SmallChatMCPConnection on: Object new.
    self assert: a id isInteger.
    self deny: a id = b id.
    self assert: a socket == sock.
    self assert: a openedAt isNotNil.
    self assert: a closedAt isNil.
    self deny: a isClosed.
    self assert: a calls isEmpty.
    a markClosed.
    self assert: a closedAt isNotNil.
    self assert: a isClosed
]

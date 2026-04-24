Class {
	#name : 'SmallChatLSPSmokeTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-LSP-Tests',
	#package : 'SmallChat-LSP-Tests'
}

{ #category : 'availability' }
SmallChatLSPSmokeTest class >> isAvailable [
	"OSSubprocess + a workspace with @typescript/native-preview installed are both required."
	^ (Smalltalk globals includesKey: #OSSUnixSubprocess)
		and: [ self workspaceRootForTsgo notNil ]
]

{ #category : 'availability' }
SmallChatLSPSmokeTest class >> workspaceRootForTsgo [
	"Pick the workspace root to point tsgo at:
	   1. SMALLCHAT_TSGO_WORKSPACE env var if set and valid,
	   2. a few known-good candidates on this machine,
	  returning the first whose native-preview-darwin-arm64 binary exists.
	 Returns nil when no candidate carries tsgo."
	| envVal candidates |
	envVal := OSEnvironment current at: 'SMALLCHAT_TSGO_WORKSPACE' ifAbsent: [ nil ].
	candidates := OrderedCollection new.
	envVal ifNotNil: [ candidates add: envVal asFileReference ].
	candidates
		add: '/Users/katis/code/plan' asFileReference;
		add: '/Users/katis/code/juba' asFileReference.
	^ candidates
		detect: [ :root | (SmallChatLSPStdioTransport defaultTsgoPathFor: root) exists ]
		ifNone: [ nil ]
]

{ #category : 'running' }
SmallChatLSPSmokeTest >> setUp [
	super setUp.
	self class isAvailable ifFalse: [
		self skip: 'SmallChatLSPSmokeTest requires OSSubprocess and a workspace with @typescript/native-preview installed' ]
]

{ #category : 'tests - live' }
SmallChatLSPSmokeTest >> testInitializeHandshakeRoundTripsAgainstTsgo [
	"Launch real tsgo, initialize, assert capabilities come back and the
	 client flips #initialized. Teardown closes stdin; tsgo exits cleanly per
	 Spike S1."
	| root transport client pending result |
	root := self class workspaceRootForTsgo.
	transport := SmallChatLSPStdioTransport new.
	client := nil.
	[
		transport launchTsgoAt: root.
		client := SmallChatLSPClient new transport: transport.
		client startReader.
		pending := client initializeAsync: (Dictionary new
			at: 'processId' put: nil;
			at: 'rootUri' put: 'file://' , root pathString;
			at: 'capabilities' put: Dictionary new;
			yourself).
		result := pending resultTimeout: 10000.
		self assert: (result includesKey: 'capabilities').
		self assert: client initialized.
		self assert: client serverCapabilities supportsHover
	] ensure: [
		client ifNotNil: [ client stopReader ].
		transport shutdown ]
]

{ #category : 'tests - live' }
SmallChatLSPSmokeTest >> testShutdownExitsTsgoCleanly [
	"After #shutdown, the spawned tsgo process must be gone -- stdin-close is
	 tsgo's clean-exit signal (Spike S1); if that failed, SIGTERM covers the
	 tail. Verified via the original OSSubprocess handle's isRunning flag."
	| root transport proc |
	root := self class workspaceRootForTsgo.
	transport := SmallChatLSPStdioTransport new launchTsgoAt: root.
	proc := transport instVarNamed: 'process'.
	self assert: proc isRunning.
	transport shutdown.
	self deny: proc isRunning.
	self assert: (transport instVarNamed: 'process') isNil
]

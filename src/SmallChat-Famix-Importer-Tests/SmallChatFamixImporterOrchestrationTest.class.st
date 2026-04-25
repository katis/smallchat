Class {
	#name : 'SmallChatFamixImporterOrchestrationTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Famix-Importer-Tests',
	#package : 'SmallChat-Famix-Importer-Tests'
}

{ #category : 'helpers' }
SmallChatFamixImporterOrchestrationTest >> lspRangeStartLine: sl character: sc endLine: el character: ec [
  ^ Dictionary new
    at: 'start' put: (Dictionary new
      at: 'line' put: sl;
      at: 'character' put: sc;
      yourself);
    at: 'end' put: (Dictionary new
      at: 'line' put: el;
      at: 'character' put: ec;
      yourself);
    yourself
]

{ #category : 'helpers' }
SmallChatFamixImporterOrchestrationTest >> newImporterOn: aModel client: aClient [
  ^ SmallChatFamixImporter new
    model: aModel
    client: aClient
    parser: SmallChatTSParser new
    walker: SmallChatTSNodeWalker new
]

{ #category : 'tests - orchestration' }
SmallChatFamixImporterOrchestrationTest >> testImportTsFileUriTextOpensDocAndPopulatesFromDocumentSymbol [
  "Importer drives the LSP client end-to-end on a fork: opens the
   document, issues textDocument/documentSymbol, awaits the response,
   and feeds the result through populateFromDocumentSymbols:intoUri:text:.
   Stub transport injects the canned response from the test process."
  | model transport client importer uri text fork done sentReq response |
  model := SmallChatFamixModel new.
  transport := SmallChatLSPStubTransport new.
  client := SmallChatLSPClient new transport: transport.
  importer := self newImporterOn: model client: client.
  uri := 'file:///t/Button.ts'.
  text := 'class Button {}'.
  done := Semaphore new.
  fork := [
    importer importTsFileUri: uri text: text.
    done signal ] forkAt: Processor activePriority - 1.
  "Wait until didOpen + documentSymbol have both landed on the wire."
  self assert: (self
    waitFor: [ transport sentMessages size >= 2 ]
    upTo: 1000).
  "Enqueue the documentSymbol response keyed to the request id."
  sentReq := transport sentMessages last.
  self assert: (sentReq at: 'method') equals: 'textDocument/documentSymbol'.
  response := Dictionary new
    at: 'jsonrpc' put: '2.0';
    at: 'id' put: (sentReq at: 'id');
    at: 'result' put: { Dictionary new
      at: 'name' put: 'Button';
      at: 'kind' put: 5;
      at: 'range' put: (self lspRangeStartLine: 0 character: 0 endLine: 0 character: 15);
      yourself };
    yourself.
  transport enqueueServerMessage: response.
  client pumpOneMessage.
  done wait.
  self assert: (model allWithType: SmallChatFamixClass) size equals: 1.
  self assert: (model allWithType: SmallChatFamixClass) first name equals: 'Button'.
  self assert: (model allWithType: SmallChatFamixClass) first sourceAnchor fileUri equals: uri
]

{ #category : 'helpers' }
SmallChatFamixImporterOrchestrationTest >> waitFor: aBlock upTo: ms [
  | deadline |
  deadline := Time millisecondClockValue + ms.
  [ aBlock value or: [ Time millisecondClockValue > deadline ] ]
    whileFalse: [ (Delay forMilliseconds: 5) wait ].
  ^ aBlock value
]

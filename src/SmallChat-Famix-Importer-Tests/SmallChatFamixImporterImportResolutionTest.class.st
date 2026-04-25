Class {
	#name : 'SmallChatFamixImporterImportResolutionTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Famix-Importer-Tests',
	#package : 'SmallChat-Famix-Importer-Tests'
}

{ #category : 'helpers' }
SmallChatFamixImporterImportResolutionTest >> lspLocationUri: aUri [
  "Build a single-Location LSP definition response wrapping aUri with a
   zero-length range (importer reads only uri)."
  ^ Dictionary new
    at: 'uri' put: aUri;
    at: 'range' put: (Dictionary new
      at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 0; yourself);
      at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 0; yourself);
      yourself);
    yourself
]

{ #category : 'helpers' }
SmallChatFamixImporterImportResolutionTest >> newImporterWithTransport: aTransport onModel: aModel [
  ^ SmallChatFamixImporter new
    model: aModel
    client: (SmallChatLSPClient new transport: aTransport)
    parser: SmallChatTSParser new
    walker: SmallChatTSNodeWalker new
]

{ #category : 'tests - classifier' }
SmallChatFamixImporterImportResolutionTest >> testClassifierBuckets [
  "Classifier maps a resolved URI plus the project root URI to one of four
   symbols: #unresolved (nil/empty), #nodeModules (node_modules anywhere on
   the path), #srcLocal (under the project root, not in node_modules),
   #virtualModule (resolved but neither under root nor in node_modules)."
  | classify root |
  classify := [ :resolved | SmallChatFamixImporter classifyResolvedUri: resolved againstRoot: root ].
  root := 'file:///proj'.
  self assert: (classify value: nil) equals: #unresolved.
  self assert: (classify value: '') equals: #unresolved.
  self assert: (classify value: 'file:///proj/node_modules/react/index.js')
    equals: #nodeModules.
  self assert: (classify value: 'file:///proj/src/Button.tsx')
    equals: #srcLocal.
  self assert: (classify value: 'file:///elsewhere/worker-configuration.d.ts')
    equals: #virtualModule
]

{ #category : 'tests - import slots' }
SmallChatFamixImporterImportResolutionTest >> testImportCarriesResolvedUriAndClassification [
  "SmallChatFamixImport carries resolvedUri (String or nil) and
   classification (Symbol or nil) -- both nil on a fresh entity, both
   round-trip via the accessors."
  | model imp |
  model := SmallChatFamixModel new.
  imp := model newImport.
  self assert: imp resolvedUri equals: nil.
  self assert: imp classification equals: nil.
  imp resolvedUri: 'file:///proj/src/X.ts'.
  imp classification: #srcLocal.
  self assert: imp resolvedUri equals: 'file:///proj/src/X.ts'.
  self assert: imp classification equals: #srcLocal
]

{ #category : 'tests - resolution' }
SmallChatFamixImporterImportResolutionTest >> testPopulateImportsResolvesEachImportAndClassifiesAsNodeModules [
  "populateImportsFromText:intoUri: walks tree-sitter for imports AND
   issues textDocument/definition for each one, populating resolvedUri /
   classification on the resulting Import entities. A node_modules
   resolution buckets as #nodeModules even when the resolved path lives
   under the project root. Source anchor covers the whole import_statement."
  | model importer transport text uri imp project done fork sentReq anchor |
  model := SmallChatFamixModel new.
  project := model newProject.
  project rootUri: 'file:///proj'.
  transport := SmallChatLSPStubTransport new.
  importer := self newImporterWithTransport: transport onModel: model.
  uri := 'file:///proj/src/Foo.ts'.
  text := 'import React from "react";'.
  importer client openDocumentUri: uri languageId: 'typescript' text: text.
  done := Semaphore new.
  fork := [
    importer populateImportsFromText: text intoUri: uri.
    done signal ] forkAt: Processor activePriority - 1.
  self assert: (self waitFor: [ transport sentMessages size >= 2 ] upTo: 1000).
  sentReq := transport sentMessages last.
  self assert: (sentReq at: 'method') equals: 'textDocument/definition'.
  transport enqueueServerMessage: (Dictionary new
    at: 'jsonrpc' put: '2.0';
    at: 'id' put: (sentReq at: 'id');
    at: 'result' put: { self lspLocationUri: 'file:///proj/node_modules/react/index.d.ts' };
    yourself).
  importer client pumpOneMessage.
  done wait.
  self assert: (model allWithType: SmallChatFamixImport) size equals: 1.
  imp := (model allWithType: SmallChatFamixImport) first.
  self assert: imp name equals: 'react'.
  anchor := imp sourceAnchor.
  self assert: anchor fileUri equals: uri.
  self assert: anchor startByte equals: 0.
  self assert: anchor endByte equals: text size.
  self assert: imp resolvedUri equals: 'file:///proj/node_modules/react/index.d.ts'.
  self assert: imp classification equals: #nodeModules
]

{ #category : 'tests - project slots' }
SmallChatFamixImporterImportResolutionTest >> testProjectCarriesRootUri [
  "SmallChatFamixProject carries a rootUri (workspace root URI) -- nil on a
   fresh entity, round-trips via the accessors. The classifier uses it as
   the prefix for #srcLocal classification."
  | model project |
  model := SmallChatFamixModel new.
  project := model newProject.
  self assert: project rootUri equals: nil.
  project rootUri: 'file:///proj'.
  self assert: project rootUri equals: 'file:///proj'
]

{ #category : 'tests - resolution' }
SmallChatFamixImporterImportResolutionTest >> testResolveImportSetsResolvedUriAndSrcLocalClassification [
  "resolveImport:atSpecifierStartByte:inSourceText:onUri: issues
   textDocument/definition for the given byte position, reads the
   first Location's uri off the response, and stores it on the
   import along with the bucket from classifyResolvedUri:againstRoot:.
   For a stub-resolved file under the project root, classification
   is #srcLocal."
  | model importer transport text uri imp project done fork sentReq |
  model := SmallChatFamixModel new.
  project := model newProject.
  project rootUri: 'file:///proj'.
  transport := SmallChatLSPStubTransport new.
  importer := self newImporterWithTransport: transport onModel: model.
  uri := 'file:///proj/src/Foo.ts'.
  text := 'import { x } from "./bar";'.
  importer client openDocumentUri: uri languageId: 'typescript' text: text.
  imp := model newImport.
  imp name: './bar'.
  done := Semaphore new.
  fork := [
    importer resolveImport: imp atSpecifierStartByte: 19 inSourceText: text onUri: uri.
    done signal ] forkAt: Processor activePriority - 1.
  self assert: (self waitFor: [ transport sentMessages size >= 2 ] upTo: 1000).
  sentReq := transport sentMessages last.
  self assert: (sentReq at: 'method') equals: 'textDocument/definition'.
  transport enqueueServerMessage: (Dictionary new
    at: 'jsonrpc' put: '2.0';
    at: 'id' put: (sentReq at: 'id');
    at: 'result' put: { self lspLocationUri: 'file:///proj/src/bar.ts' };
    yourself).
  importer client pumpOneMessage.
  done wait.
  self assert: imp resolvedUri equals: 'file:///proj/src/bar.ts'.
  self assert: imp classification equals: #srcLocal
]

{ #category : 'helpers' }
SmallChatFamixImporterImportResolutionTest >> waitFor: aBlock upTo: ms [
  | deadline |
  deadline := Time millisecondClockValue + ms.
  [ aBlock value or: [ Time millisecondClockValue > deadline ] ]
    whileFalse: [ (Delay forMilliseconds: 5) wait ].
  ^ aBlock value
]

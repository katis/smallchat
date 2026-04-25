Class {
	#name : 'SmallChatFamixImporterImportResolutionTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Famix-Importer-Tests',
	#package : 'SmallChat-Famix-Importer-Tests'
}

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

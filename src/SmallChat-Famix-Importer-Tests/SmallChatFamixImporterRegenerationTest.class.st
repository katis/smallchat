Class {
	#name : 'SmallChatFamixImporterRegenerationTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Famix-Importer-Tests',
	#package : 'SmallChat-Famix-Importer-Tests'
}

{ #category : 'helpers' }
SmallChatFamixImporterRegenerationTest >> newImporterOn: aModel [
  ^ SmallChatFamixImporter new
    model: aModel
    client: nil
    parser: SmallChatTSParser new
    walker: SmallChatTSNodeWalker new
]

{ #category : 'tests - drop' }
SmallChatFamixImporterRegenerationTest >> testDropEntitiesForUriRemovesAllAnchoredAtThatUri [
  "dropEntitiesForUri: removes every entity (Module, Class, Method, Field,
   Function, Interface, Import, JSXComponent, CSSModuleFile, CSSClass,
   CSSClassReference) whose sourceAnchor fileUri equals the dropped URI.
   Entities anchored at OTHER URIs are untouched. Project survives because
   the project itself has no sourceAnchor."
  | model importer cssA cssB |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  cssA := 'file:///t/A.module.css'.
  cssB := 'file:///t/B.module.css'.
  importer importCssFileUri: cssA text: '.x { } .y { }'.
  importer importCssFileUri: cssB text: '.z { }'.
  self assert: (model allWithType: SmallChatFamixCSSClass) size equals: 3.
  importer dropEntitiesForUri: cssA.
  self assert: (model allWithType: SmallChatFamixCSSModuleFile) size equals: 1.
  self assert: (model allWithType: SmallChatFamixCSSClass) size equals: 1.
  self assert: (model allWithType: SmallChatFamixCSSModuleFile) first sourceAnchor fileUri equals: cssB
]

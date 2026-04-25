Class {
	#name : 'SmallChatLMCapabilityCatalogStubForTests',
	#superclass : 'Object',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'stubbing' }
SmallChatLMCapabilityCatalogStubForTests >> toolSchemas [
	"Single-element fake catalog. Tests pin the request body shape to this
	 rather than the live registry contents."
	^ { Dictionary new
		at: 'type' put: 'function';
		at: 'function' put: (Dictionary new
			at: 'name' put: 'stub.fake.tool';
			at: 'description' put: 'Stub.';
			at: 'parameters' put: (Dictionary new
				at: 'type' put: 'object';
				at: 'properties' put: Dictionary new;
				at: 'required' put: #();
				yourself);
			yourself);
		yourself }
]

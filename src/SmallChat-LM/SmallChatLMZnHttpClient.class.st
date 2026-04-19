"
Thin adapter around ZnClient: POST a JSON string body to a URL, return
the response body string. Exists so SmallChatLMCompletionsClient can
depend on a small injectable seam (#post:to:) rather than the full
ZnClient surface -- tests inject a stub with the same two-method
protocol.
"
Class {
	#name : 'SmallChatLMZnHttpClient',
	#superclass : 'Object',
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'api' }
SmallChatLMZnHttpClient >> post: aJsonString to: aUrl [
	^ ZnClient new
		url: aUrl;
		entity: (ZnEntity with: aJsonString type: ZnMimeType applicationJson);
		post;
		contents
]

class_name StoryLibrary
extends RefCounted
## The tales on the start screen picker. Add a story: write its data class and add an entry here.
## The native equal of Inkfall's stories/manifest.js.


static func all() -> Array:
	return [
		{"name": "STORY 0", "tagline": "A HALLUCINATION OF SIN CITY", "story": HallucinationStory.get_story()},
		{"name": "STORY 1", "tagline": "THE LAST DEAL OF DANNY COLE", "story": DannyColeStory.get_story()},
	]

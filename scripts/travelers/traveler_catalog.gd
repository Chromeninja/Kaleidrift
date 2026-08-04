class_name TravelerCatalog
extends Resource

@export var travelers: Array = []


func find_definition(identifier: StringName) -> TravelerDefinition:
	for definition in travelers:
		var typed_definition := definition as TravelerDefinition
		if typed_definition != null and typed_definition.identifier == identifier and typed_definition.is_valid_definition():
			return typed_definition
	for definition in travelers:
		var typed_definition := definition as TravelerDefinition
		if typed_definition != null and typed_definition.is_valid_definition():
			return typed_definition
	return null

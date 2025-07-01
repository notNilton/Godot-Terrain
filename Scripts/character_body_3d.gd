@tool
extends CharacterBody3D

func _process(delta):
	if Engine.is_editor_hint():
		print("Hi")

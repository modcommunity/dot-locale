@tool
extends EditorPlugin

## Editor entry point for dot-locale. Registers nothing and installs no autoload.
##
## A translator is a plain object a game builds from [DotLocaleConfig] and hands to what
## needs it. An autoload would fix one language per process, and a server rendering
## messages for players in four languages needs four.


func _enter_tree() -> void:
	pass


func _exit_tree() -> void:
	pass

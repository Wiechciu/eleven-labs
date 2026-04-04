@tool
extends EditorPlugin


var dock: EditorDock


func _enter_tree():
	var dock_scene = preload("res://addons/eleven_labs/eleven_labs.tscn").instantiate()
	dock = EditorDock.new()
	dock.add_child(dock_scene)
	dock.icon_name = "Pause"
	dock.force_show_icon = true
	dock.title = "ElevenLabs"
	dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	dock.available_layouts = EditorDock.DOCK_LAYOUT_ALL
	add_dock(dock)
	
	var parent = dock.get_parent()
	if parent is TabContainer:
		parent.current_tab = parent.get_tab_idx_from_control(dock)


func _exit_tree():
	remove_dock(dock)
	dock.queue_free()

class_name ParleyDialogueTextPresenter
extends Node

signal finished

@export var characters_per_second: float = 40.0
@export var instant: bool = false
@export var allow_skip: bool = true
@export var label_path: NodePath

var _full_text := ""
var _visible_chars := 0
var _elapsed := 0.0
var _running := false

@onready var label: RichTextLabel = null

func _ready() -> void:
	# Walk the subtree owned by the dialogue container
	label = _find_dialogue_label()

	assert(
		label,
		"ParleyDialogueTextPresenter: DialogueTextLabel not found in dialogue container subtree"
	)


func _find_dialogue_label() -> RichTextLabel:
	var root := get_parent()
	if not root:
		return null

	for node in root.find_children("*", "RichTextLabel", true, false):
		if node.name == "DialogueTextLabel":
			return node

	return null


func play(text: String) -> void:
	_full_text = text
	_visible_chars = 0
	_elapsed = 0.0
	_running = true

	label.bbcode_enabled = true
	label.text = ""

	if instant:
		label.text = _full_text
		_finish()
	else:
		set_process(true)


func _process(delta: float) -> void:
	if not _running:
		return

	_elapsed += delta
	var target := int(_elapsed * characters_per_second)

	if target > _visible_chars:
		_visible_chars = min(target, _full_text.length())
		label.text = _full_text.substr(0, _visible_chars)

	if _visible_chars >= _full_text.length():
		_finish()


func skip() -> void:
	if allow_skip and _running:
		label.text = _full_text
		_finish()


func _finish() -> void:
	_running = false
	set_process(false)
	finished.emit()


func is_finished() -> bool:
	return not _running

@tool
class_name ParleyDialogueContainer
extends MarginContainer

signal finished_all_pages

@onready var dialogue_text_label: RichTextLabel = %DialogueTextLabel
@onready var presenter: ParleyDialogueTextPresenter = ParleyDialogueTextPresenter.new()

var is_text_finished: bool = true
var _pages: PackedStringArray = PackedStringArray()
var _page_index: int = 0
var _is_ready := false

## The current dialogue node AST.
var dialogue_node: ParleyDialogueNodeAst:
	set(value):
		dialogue_node = value
		if _is_ready:
			_prepare_pages()
			_render_current_page()


func _ready() -> void:
	_is_ready = true
	add_child(presenter)
	presenter.finished.connect(_on_page_finished)

	if dialogue_node:
		_prepare_pages()
		_render_current_page()


# ----------------------------------------------------
# Paging
# ----------------------------------------------------

func _prepare_pages() -> void:
	_pages.clear()
	_page_index = 0

	if not dialogue_node:
		return

	var raw_text := dialogue_node.text
	_pages = raw_text.split("\n", false)

	if _pages.is_empty():
		_pages.append(raw_text)


func _render_current_page() -> void:
	if not dialogue_node:
		return
	if _page_index >= _pages.size():
		return

	var character: ParleyCharacter = dialogue_node.resolve_character()
	var speaker_name := character.name if character.name != "" else "Unknown"

	var page_text := "[b]%s[/b] – %s" % [
		speaker_name,
		_pages[_page_index]
	]

	is_text_finished = false
	presenter.play(page_text)


# ----------------------------------------------------
# Input
# ----------------------------------------------------

func advance_page() -> bool:
	if not is_text_finished:
		presenter.skip()
		return true

	if _page_index < _pages.size() - 1:
		_page_index += 1
		_render_current_page()
		return true

	# ✅ LAST PAGE → allow AST advance
	return false



func _on_page_finished() -> void:
	is_text_finished = true

	if _page_index == _pages.size() - 1:
		finished_all_pages.emit()

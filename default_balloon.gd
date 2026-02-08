# Copyright 2024-2025 the Bisterix Studio authors.
# MIT license.

class_name ParleyDefaultBalloon
extends CanvasLayer

const dialogue_container: PackedScene = preload("./dialogue/dialogue_container.tscn")
const dialogue_options_container: PackedScene = preload("./dialogue_option/dialogue_options_container.tscn")
const next_dialogue_button: PackedScene = preload("./next_dialogue_button.tscn")

@export var advance_dialogue_action: StringName = &"ui_accept"

@onready var balloon: Control = %Balloon
@onready var balloon_container: VBoxContainer = %BalloonContainer

var _active_dialogue_container: ParleyDialogueContainer = null

var ctx: ParleyContext
var dialogue_sequence_ast: ParleyDialogueSequenceAst

var previous_node_ast: ParleyNodeAst = null
var _current_node_asts: Array[ParleyNodeAst] = []
var is_waiting_for_input: bool = false


var current_node_asts: Array[ParleyNodeAst]:
	get:
		return _current_node_asts
	set(value):
		_set_current_node_asts(value)


# -------------------------------------------------------------------
# Lifecycle
# -------------------------------------------------------------------

func _ready() -> void:
	balloon.hide()


func _exit_tree() -> void:
	if ctx and not ctx.is_queued_for_deletion():
		ctx.free()


# -------------------------------------------------------------------
# Dialogue control
# -------------------------------------------------------------------

func start(
	p_ctx: ParleyContext,
	p_dialogue_sequence_ast: ParleyDialogueSequenceAst,
	p_start_node: ParleyNodeAst = null
) -> void:
	balloon.show()
	is_waiting_for_input = false

	ctx = p_ctx
	dialogue_sequence_ast = p_dialogue_sequence_ast

	var run_result: ParleyRunResult

	if p_start_node:
		run_result = await ParleyDialogueSequenceAst.run(ctx, dialogue_sequence_ast, p_start_node)
	else:
		run_result = await ParleyDialogueSequenceAst.run(ctx, dialogue_sequence_ast)

	current_node_asts = run_result.node_asts
	dialogue_sequence_ast = run_result.dialogue_sequence
	run_result.free()


func next(current_node_ast: ParleyNodeAst) -> void:
	previous_node_ast = current_node_ast

	var run_result := await ParleyDialogueSequenceAst.run(
		ctx,
		dialogue_sequence_ast,
		current_node_ast
	)

	current_node_asts = run_result.node_asts
	dialogue_sequence_ast = run_result.dialogue_sequence
	run_result.free()


# -------------------------------------------------------------------
# Rendering
# -------------------------------------------------------------------

func _set_current_node_asts(p_nodes: Array[ParleyNodeAst]) -> void:
	_active_dialogue_container = null
	is_waiting_for_input = false

	if p_nodes.is_empty() or p_nodes.front() is ParleyEndNodeAst:
		queue_free()
		return

	if not is_node_ready():
		await ready

	_current_node_asts = p_nodes

	var current_children := balloon_container.get_children()
	var first_node := p_nodes.front()
	var next_children := await _build_next_children(first_node)

	_clear_children(current_children)
	_add_children(next_children)

	if not ParleyDialogueSequenceAst.is_dialogue_options(p_nodes):
		var next_button := next_children.back()
		ParleyUtils.signals.safe_connect(
			next_button.gui_input,
			_on_next_dialogue_button_gui_input.bind(next_button)
		)
		next_button.grab_focus()

	is_waiting_for_input = true


func _build_next_children(node_ast: ParleyNodeAst) -> Array[Node]:
	var children: Array[Node] = []

	if node_ast is ParleyDialogueNodeAst:
		var container: ParleyDialogueContainer = dialogue_container.instantiate()
		container.dialogue_node = node_ast
		container.set_meta("ast", node_ast)

		# ✅ CONNECT paging completion
		container.finished_all_pages.connect(
			_on_dialogue_container_finished_all_pages
		)

		_active_dialogue_container = container
		children.append(container)
		children.append(next_dialogue_button.instantiate())


	elif node_ast is ParleyDialogueOptionNodeAst:
		var options := dialogue_options_container.instantiate()
		options.dialogue_options = current_node_asts
		ParleyUtils.signals.safe_connect(
			options.dialogue_option_selected,
			_on_dialogue_options_container_dialogue_option_selected
		)
		children.append(options)

	return children



func _clear_children(children: Array[Node]) -> void:
	for child in children:
		child.queue_free()


func _add_children(children: Array[Node]) -> void:
	for child in children:
		balloon_container.add_child(child)


# -------------------------------------------------------------------
# Input
# -------------------------------------------------------------------

func _on_next_dialogue_button_gui_input(event: InputEvent, item: Control) -> void:
	if not is_waiting_for_input:
		return

	if not (
		(event is InputEventMouseButton and event.pressed)
		or
		(event is InputEventKey and event.is_action_pressed(advance_dialogue_action))
	):
		return

	# Paging phase
	if _active_dialogue_container:
		if _active_dialogue_container.advance_page():
			return


	# AST phase
	var current_node := current_node_asts.front()
	next(current_node)




func _on_dialogue_options_container_dialogue_option_selected(
	option: ParleyDialogueOptionNodeAst
) -> void:
	next(option)

func _on_dialogue_container_finished_all_pages() -> void:
	if not is_waiting_for_input:
		return

	var current_node := current_node_asts.front()
	next(current_node)
	
func _on_dialogue_container_finished() -> void:
	# Paging is done; user may now advance
	is_waiting_for_input = true

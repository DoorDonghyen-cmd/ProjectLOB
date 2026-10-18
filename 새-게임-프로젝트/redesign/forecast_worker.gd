extends Node
## One exact calculation at a time; edits replace the queued request.
## Only immutable snapshots cross the thread boundary. No scene nodes in the worker.
signal completed
const Forecast = preload("res://redesign/forecast.gd")
var thread: Thread
var wanted_key := ""
var running_key := ""
var ready_key := ""
var ready_result: Dictionary = {}
var queued_state: Dictionary = {}
var ticket: Ticket

class Ticket extends RefCounted:
	var mutex := Mutex.new()
	var cancelled := false
	func cancel() -> void:
		mutex.lock()
		cancelled = true
		mutex.unlock()
	func is_cancelled() -> bool:
		mutex.lock()
		var result := cancelled
		mutex.unlock()
		return result

func request(state: Dictionary) -> Dictionary:
	wanted_key = JSON.stringify(state)
	if ticket != null and running_key != wanted_key: ticket.cancel()
	if wanted_key == ready_key: return ready_result
	queued_state = state.duplicate(true)
	if thread == null: _start()
	return {}

func cancel_request() -> void:
	if ticket != null: ticket.cancel()
	wanted_key = ""
	queued_state = {}

func _start() -> void:
	running_key = wanted_key
	var snapshot := queued_state
	queued_state = {}
	thread = Thread.new()
	ticket = Ticket.new()
	var error := thread.start(Forecast.analyze.bind(snapshot, true, true, ticket.is_cancelled))
	if error != OK:
		thread = null
		ready_key = running_key
		ready_result = Forecast.analyze(snapshot, true, true)
		completed.emit.call_deferred()

func _process(_delta: float) -> void:
	if thread == null or thread.is_alive(): return
	ready_result = thread.wait_to_finish()
	thread = null
	ready_key = "" if ready_result.is_empty() else running_key
	if not ready_key.is_empty() and wanted_key == ready_key:
		queued_state = {}
		completed.emit()
	elif not queued_state.is_empty():
		_start()

func _exit_tree() -> void:
	if thread != null:
		ticket.cancel()
		thread.wait_to_finish()
		thread = null

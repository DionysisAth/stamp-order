extends Node
## Gameplay analytics: level_start, level_complete, hint_used, undo_count and
## quit_mid_level. Events are always appended to user://analytics.jsonl. When
## the project setting `stamp_order/analytics/endpoint` holds a URL, batches
## are also POSTed there as JSON arrays.

const LOG_PATH := "user://analytics.jsonl"
const MAX_LOG_BYTES := 512 * 1024
const FLUSH_SECONDS := 20.0

var session_id := ""
var endpoint := ""
var _queue: Array = []
var _http: HTTPRequest
var _sending := false
var _timer := 0.0


func _ready() -> void:
	session_id = "%d-%06d" % [Time.get_unix_time_from_system(), randi() % 1000000]
	endpoint = str(ProjectSettings.get_setting("stamp_order/analytics/endpoint", ""))
	if endpoint != "":
		_http = HTTPRequest.new()
		_http.timeout = 10.0
		add_child(_http)
		_http.request_completed.connect(_on_sent)


func event(event_name: String, params: Dictionary = {}) -> void:
	var record := {
		"event": event_name,
		"time": Time.get_unix_time_from_system(),
		"session": session_id,
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"platform": OS.get_name(),
		"params": params,
	}
	if OS.is_debug_build():
		print("[analytics] ", event_name, " ", params)
	_append(record)
	if endpoint != "":
		_queue.append(record)


func _append(record: Dictionary) -> void:
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE
	var f := FileAccess.open(LOG_PATH, mode)
	if f == null:
		return
	if f.get_length() > MAX_LOG_BYTES:
		f.close()
		DirAccess.rename_absolute(LOG_PATH, LOG_PATH + ".old")
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
		if f == null:
			return
	f.seek_end()
	f.store_line(JSON.stringify(record))
	f.close()


func _process(delta: float) -> void:
	if _http == null or _queue.is_empty() or _sending:
		return
	_timer += delta
	if _timer >= FLUSH_SECONDS:
		flush()


func flush() -> void:
	if _http == null or _queue.is_empty() or _sending:
		return
	_timer = 0.0
	_sending = true
	var batch := _queue.duplicate()
	var err := _http.request(endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(batch))
	if err == OK:
		_queue.clear()
	else:
		_sending = false


func _on_sent(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_sending = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush()

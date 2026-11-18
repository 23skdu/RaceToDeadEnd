extends Node
class_name OnlineLeaderboard
## Optional online leaderboard client for roadmap item 15.
##
## The game never depends on a server being reachable: every failure path
## (invalid endpoint, HTTP error, malformed JSON) falls back to the encrypted
## local `GameManager.leaderboard` and still emits `entries_received`.

signal entries_received(entries: Array)
signal submission_completed(success: bool)
signal request_failed(message: String)

const INVALID_ENDPOINT: String = "invalid://leaderboard.local/scores"

@export var endpoint_url: String = INVALID_ENDPOINT
@export var timeout_seconds: float = 3.0

var last_error: String = ""
var _http: HTTPRequest
var _pending_action: String = ""


func _ready() -> void:
	_ensure_http_client()


func configure(url: String, timeout: float = 3.0) -> void:
	endpoint_url = url.strip_edges()
	timeout_seconds = maxf(0.05, timeout)
	_ensure_http_client()
	if _http != null:
		_http.timeout = timeout_seconds


func fetch_scores(limit: int = 10) -> bool:
	_ensure_http_client()
	last_error = ""
	_pending_action = "fetch"
	if _http == null or endpoint_url.is_empty() or not endpoint_url.begins_with("http"):
		_fail("Online leaderboard unavailable; showing local scores")
		return false
	var headers := PackedStringArray(["Accept: application/json"])
	var err: Error = _http.request(endpoint_url + "?limit=" + str(maxi(1, limit)), headers, HTTPClient.METHOD_GET, "")
	if err != OK:
		_fail("Leaderboard request failed: " + str(err))
		return false
	return true


func submit_score(player_name: String, score: int, skin_id: String = "") -> bool:
	_ensure_http_client()
	last_error = ""
	_pending_action = "submit"
	if _http == null or endpoint_url.is_empty() or not endpoint_url.begins_with("http"):
		_fail("Online leaderboard unavailable; score saved locally")
		return false
	var payload := {
		"player": player_name.substr(0, 24),
		"score": maxi(0, score),
		"skin": skin_id,
		"tier": GameManager.difficulty_tier,
		"daily": GameManager.daily_run_active,
	}
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err: Error = _http.request(endpoint_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_fail("Leaderboard submission failed: " + str(err))
		return false
	return true


func local_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in GameManager.leaderboard:
		if entry is Dictionary:
			entries.append((entry as Dictionary).duplicate(true))
	entries.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	return entries


func _ensure_http_client() -> void:
	if _http != null and is_instance_valid(_http):
		return
	_http = HTTPRequest.new()
	_http.name = "LeaderboardHTTP"
	_http.timeout = timeout_seconds
	add_child(_http)
	if not _http.request_completed.is_connected(_on_request_completed):
		_http.request_completed.connect(_on_request_completed)


func _fail(message: String) -> void:
	last_error = message
	request_failed.emit(message)
	if _pending_action == "submit":
		submission_completed.emit(false)
	else:
		entries_received.emit(local_entries())
	_pending_action = ""


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_fail("Leaderboard server returned " + str(response_code))
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	var entries: Array[Dictionary] = _normalize_entries(parsed)
	if entries.is_empty() and parsed != null:
		_fail("Leaderboard response was malformed")
		return
	if _pending_action == "submit":
		submission_completed.emit(true)
		_pending_action = ""
		fetch_scores()
		return
	_pending_action = ""
	entries_received.emit(entries)


func _normalize_entries(parsed: Variant) -> Array[Dictionary]:
	var source: Array = []
	if parsed is Array:
		source = parsed as Array
	elif parsed is Dictionary and (parsed as Dictionary).has("entries"):
		var nested: Variant = (parsed as Dictionary).get("entries")
		if nested is Array:
			source = nested as Array
	var result: Array[Dictionary] = []
	for item in source:
		if not (item is Dictionary):
			continue
		var entry: Dictionary = (item as Dictionary).duplicate(true)
		entry["score"] = maxi(0, int(entry.get("score", 0)))
		result.append(entry)
	result.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	return result

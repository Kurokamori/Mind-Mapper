class_name MobileReconnectOrchestrator
extends Node

signal attempt_started(attempt: int, max_attempts: int)
signal reconnect_succeeded(scopes: Array)
signal reconnect_failed(scopes: Array, reason: String)
signal reconnect_skipped()

const SCOPE_MULTIPLAYER: String = "multiplayer"
const SCOPE_LAN_SYNC: String = "lan_sync"

const BACKOFF_DELAYS_MSEC: Array = [500, 1500, 3500, 7500]
const MULTIPLAYER_CONNECT_TIMEOUT_MSEC: int = 12000
const POLL_INTERVAL_MSEC: int = 200

var _lan_sync_client: LanSyncClient = null
var _in_progress: bool = false
var _cancel_requested: bool = false
var _current_attempt: int = 0


func bind_lan_sync_client(client: LanSyncClient) -> void:
	_lan_sync_client = client


func is_in_progress() -> bool:
	return _in_progress


func cancel() -> void:
	if not _in_progress:
		return
	_cancel_requested = true


func notify_suspended() -> void:
	if _lan_sync_client != null:
		_lan_sync_client.mark_interrupted_for_reconnect()


func has_anything_to_reconnect() -> bool:
	if MultiplayerService != null and MultiplayerService.has_resumable_session():
		return true
	if _lan_sync_client != null and _lan_sync_client.needs_reconnect():
		return true
	return false


func start_reconnect() -> void:
	if _in_progress:
		return
	if not has_anything_to_reconnect():
		emit_signal("reconnect_skipped")
		return
	_in_progress = true
	_cancel_requested = false
	_run_attempts()


func _run_attempts() -> void:
	var max_attempts: int = BACKOFF_DELAYS_MSEC.size()
	var last_reason: String = ""
	var attempted_scopes: Array = _collect_pending_scopes()
	for attempt: int in max_attempts:
		if _cancel_requested:
			_finish_failure(attempted_scopes, "cancelled")
			return
		_current_attempt = attempt + 1
		emit_signal("attempt_started", _current_attempt, max_attempts)
		await _delay(int(BACKOFF_DELAYS_MSEC[attempt]))
		if _cancel_requested:
			_finish_failure(attempted_scopes, "cancelled")
			return
		var result: Dictionary = await _attempt_once()
		if bool(result.get("success", false)):
			_finish_success(result.get("scopes", []) as Array)
			return
		last_reason = String(result.get("reason", "unknown"))
	_finish_failure(attempted_scopes, last_reason)


func _attempt_once() -> Dictionary:
	var scopes_resolved: Array = []
	var reasons: Array = []
	if MultiplayerService != null and MultiplayerService.has_resumable_session():
		var role: String = MultiplayerService.resumable_role()
		var mp_err: Error = MultiplayerService.reconnect_session()
		if mp_err != OK:
			reasons.append("mp_kickoff:%d" % mp_err)
		else:
			var live: bool = await _await_multiplayer_live(role)
			if live:
				scopes_resolved.append(SCOPE_MULTIPLAYER)
			else:
				reasons.append("mp_no_peer")
	if _lan_sync_client != null and _lan_sync_client.needs_reconnect():
		var lan_err: Error = _lan_sync_client.reconnect()
		if lan_err != OK:
			reasons.append("lan:%d" % lan_err)
		else:
			scopes_resolved.append(SCOPE_LAN_SYNC)
	var success: bool = reasons.is_empty()
	var reason_text: String = ""
	if not reasons.is_empty():
		reason_text = ", ".join(PackedStringArray(reasons))
	return {
		"success": success,
		"scopes": scopes_resolved,
		"reason": reason_text,
	}


func _await_multiplayer_live(role: String) -> bool:
	if MultiplayerService == null:
		return false
	var deadline_msec: int = Time.get_ticks_msec() + MULTIPLAYER_CONNECT_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline_msec:
		if _cancel_requested:
			return false
		var state: int = MultiplayerService.current_state()
		if state == MultiplayerService.STATE_ERROR:
			return false
		if role == "join":
			if state == MultiplayerService.STATE_CONNECTED:
				return _has_real_peer_link()
		else:
			if state == MultiplayerService.STATE_HOSTING:
				return true
		await _delay(POLL_INTERVAL_MSEC)
	return false


func _has_real_peer_link() -> bool:
	if MultiplayerService == null:
		return false
	return MultiplayerService.connected_remote_peer_count() >= 1


func _collect_pending_scopes() -> Array:
	var out: Array = []
	if MultiplayerService != null and MultiplayerService.has_resumable_session():
		out.append(SCOPE_MULTIPLAYER)
	if _lan_sync_client != null and _lan_sync_client.needs_reconnect():
		out.append(SCOPE_LAN_SYNC)
	return out


func _finish_success(scopes: Array) -> void:
	_in_progress = false
	_cancel_requested = false
	emit_signal("reconnect_succeeded", scopes)


func _finish_failure(scopes: Array, reason: String) -> void:
	_in_progress = false
	_cancel_requested = false
	if MultiplayerService != null and MultiplayerService.has_resumable_session():
		MultiplayerService.leave_session()
	emit_signal("reconnect_failed", scopes, reason)


func _delay(msec: int) -> void:
	if msec <= 0:
		return
	var timer: SceneTreeTimer = get_tree().create_timer(float(msec) / 1000.0)
	await timer.timeout

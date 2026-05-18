class_name MobileLanIdentity
extends RefCounted

const PREF_PANEL_ID: String = "lan_sync_client"
const PREF_DISPLAY_NAME_KEY: String = "client_display_name"
const FALLBACK_NAME: String = "Mobile"


static func resolve_display_name() -> String:
	var stored: String = stored_display_name()
	if stored != "":
		return stored
	var device: String = device_default_name()
	if device != "":
		return device
	return FALLBACK_NAME


static func stored_display_name() -> String:
	if UserPrefs == null:
		return ""
	var entry: Dictionary = UserPrefs.get_panel_layout(PREF_PANEL_ID)
	return String(entry.get(PREF_DISPLAY_NAME_KEY, "")).strip_edges()


static func set_display_name(value: String) -> void:
	if UserPrefs == null:
		return
	var clean: String = value.strip_edges()
	UserPrefs.set_panel_layout(PREF_PANEL_ID, {PREF_DISPLAY_NAME_KEY: clean})


static func device_default_name() -> String:
	var model: String = OS.get_model_name()
	if model != "" and model != "GenericDevice":
		return model.strip_edges()
	var env_computer: String = OS.get_environment("COMPUTERNAME")
	if env_computer != "":
		return env_computer.strip_edges()
	var env_host: String = OS.get_environment("HOSTNAME")
	if env_host != "":
		return env_host.strip_edges()
	var platform: String = OS.get_name()
	if platform != "":
		return "%s device" % platform
	return ""

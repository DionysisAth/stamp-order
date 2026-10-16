extends Node
## Short vibration pulses on phones. A no-op on desktop or when disabled.


func tap(duration_ms: int = 20) -> void:
	if not bool(Save.get_setting("haptics")):
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)


func success() -> void:
	tap(35)

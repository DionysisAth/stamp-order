class_name TestCase
extends RefCounted
## Minimal assertions for the headless test runner (no plugin needed).

var failures: PackedStringArray = []
var tree: SceneTree


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func check_eq(a: Variant, b: Variant, msg: String) -> void:
	if a != b:
		failures.append("%s (got %s, expected %s)" % [msg, str(a), str(b)])

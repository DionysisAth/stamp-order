extends TestCase
## Save file round trip, using a throwaway path.

const SaveScript := preload("res://core/autoload/save.gd")


func test_round_trip_and_unlocks() -> void:
	var path := "user://test_save_%d.json" % randi()
	var s: Node = SaveScript.new()
	s.path = path
	s.load_data()
	check(s.is_unlocked(0), "first level starts unlocked")
	check(not s.is_unlocked(1), "second level starts locked")
	s.record_win("w1_01", 0, 2)
	s.record_win("w1_01", 0, 1)
	check_eq(s.stars_for("w1_01"), 2, "best stars are kept")
	check(s.is_unlocked(1), "winning unlocks the next level")
	s.data["settings"]["sound"] = false
	s.write()
	var s2: Node = SaveScript.new()
	s2.path = path
	s2.load_data()
	check_eq(s2.stars_for("w1_01"), 2, "stars survive a reload")
	check_eq(s2.unlocked_count(), 2, "unlocks survive a reload")
	check_eq(s2.get_setting("sound"), false, "settings survive a reload")
	check_eq(s2.get_setting("haptics"), true, "missing settings get defaults")
	s2.reset_progress()
	check_eq(s2.stars_for("w1_01"), 0, "reset clears stars")
	check_eq(s2.get_setting("sound"), false, "reset keeps settings")
	s.free()
	s2.free()
	DirAccess.remove_absolute(path)

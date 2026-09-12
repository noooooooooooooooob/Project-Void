class_name TestCase
extends RefCounted

var _results: Array[Dictionary] = []


func check(name: String, condition: bool, message: String = "") -> void:
	_results.append({
		"name": name,
		"ok": condition,
		"message": message,
	})


func check_eq(name: String, actual: Variant, expected: Variant) -> void:
	_results.append({
		"name": name,
		"ok": actual == expected,
		"message": "expected %s, got %s" % [expected, actual],
	})


func results() -> Array[Dictionary]:
	return _results

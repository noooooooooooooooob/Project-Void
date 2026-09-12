extends TestCase


func run() -> Array[Dictionary]:
	check("harness reports a pass", true)
	check_eq("check_eq compares values", 1 + 1, 2)
	return results()

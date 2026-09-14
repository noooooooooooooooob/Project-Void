## 모든 테스트 스크립트의 부모 클래스. 검사 결과를 모아 두는 간단한 도구.
## 각 테스트는 run() 에서 check / check_eq 를 부르고 마지막에 results() 를 돌려준다.
class_name TestCase
# RefCounted: 노드가 아닌 가벼운 객체.
extends RefCounted

## 지금까지 모은 검사 결과. 항목마다 {"name", "ok", "message"}.
var _results: Array[Dictionary] = []


## condition 이 true 면 통과로 기록한다. message 는 실패했을 때 보여 줄 설명.
func check(name: String, condition: bool, message: String = "") -> void:
	# 이름·통과 여부·설명을 결과에 추가한다.
	_results.append({
		"name": name,
		"ok": condition,
		"message": message,
	})


## actual 과 expected 가 같으면 통과로 기록한다. 실패하면 두 값을 설명에 넣는다.
func check_eq(name: String, actual: Variant, expected: Variant) -> void:
	# 비교 결과와 "expected X, got Y" 설명을 결과에 추가한다.
	_results.append({
		"name": name,
		"ok": actual == expected,
		"message": "expected %s, got %s" % [expected, actual],
	})


## 모은 결과를 돌려준다 (run() 의 마지막에 부른다).
func results() -> Array[Dictionary]:
	# 결과 배열을 돌려준다.
	return _results

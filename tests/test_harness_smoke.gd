# 테스트 도구(TestCase) 자체가 동작하는지 확인하는 가장 단순한 테스트.
extends TestCase


# 실행기가 부르는 진입점. 검사 결과 배열을 돌려준다.
func run() -> Array[Dictionary]:
	# 항상 참인 조건이 통과로 기록되는지.
	check("harness reports a pass", true)
	# 같은 값 비교가 통과로 기록되는지.
	check_eq("check_eq compares values", 1 + 1, 2)
	# 결과를 돌려준다.
	return results()

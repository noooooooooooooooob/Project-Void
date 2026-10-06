# UnitMotion(유닛 자세 곡선) 테스트: 각 곡선의 끝점·키 값·주기.
extends TestCase


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 숨쉬기.
	_test_idle()
	# 공격 자세와 돌진.
	_test_attack()
	# 깡충.
	_test_hop()
	# 피격과 넉백.
	_test_hit_and_knockback()
	# 쓰러짐.
	_test_death()
	# 결과를 돌려준다.
	return results()


# 숨쉬기는 1.6초 주기 사인이고 최대 0.03 늘어나며 기울지 않는지.
func _test_idle() -> void:
	# 0초는 0.
	check("idle starts flat", is_equal_approx(UnitMotion.idle(0.0, 0.0).stretch, 0.0))
	# 주기의 1/4 (0.4초) 에서 최대.
	check("idle peaks at a quarter period", is_equal_approx(UnitMotion.idle(0.4, 0.0).stretch, 0.03))
	# 한 주기 뒤 같은 값.
	check("idle repeats every period", is_equal_approx(UnitMotion.idle(0.3, 1.0).stretch, UnitMotion.idle(1.9, 1.0).stretch))
	# 기울기 없음.
	check("idle does not lean", is_equal_approx(UnitMotion.idle(0.4, 0.0).lean, 0.0))


# 공격: 0.3 에서 웅크림(−0.12, 뒤로 8°), 0.5 에서 뻗음(0.12, 앞으로 −10°), 끝은 0. 돌진은 0.3 까지 0, 0.5 에서 1, 끝 0.
func _test_attack() -> void:
	# 예비동작.
	check("attack winds up", is_equal_approx(UnitMotion.attack(0.3).stretch, -0.12))
	# 예비동작 기울기.
	check("attack leans back on windup", is_equal_approx(UnitMotion.attack(0.3).lean, 8.0))
	# 타격.
	check("attack stretches on strike", is_equal_approx(UnitMotion.attack(0.5).stretch, 0.12))
	# 타격 기울기.
	check("attack leans forward on strike", is_equal_approx(UnitMotion.attack(0.5).lean, -10.0))
	# 끝.
	check("attack settles", is_equal_approx(UnitMotion.attack(1.0).stretch, 0.0))
	# 예비동작 동안 제자리.
	check("lunge holds during windup", is_equal_approx(UnitMotion.lunge_reach(0.3), 0.0))
	# 타격 순간 끝까지.
	check("lunge reaches at strike", is_equal_approx(UnitMotion.lunge_reach(UnitMotion.ATTACK_STRIKE), 1.0))
	# 끝은 제자리.
	check("lunge returns home", is_equal_approx(UnitMotion.lunge_reach(1.0), 0.0))
	# 범위 밖 t 는 잘린다.
	check("lunge clamps t", is_equal_approx(UnitMotion.lunge_reach(2.0), 0.0))


# 깡충: 0.2 에서 웅크림 −0.15, 0.9 에서 착지 눌림 −0.12, 높이는 0.55 에서 0.25.
func _test_hop() -> void:
	# 웅크림.
	check("hop crouches", is_equal_approx(UnitMotion.hop(0.2).stretch, -0.15))
	# 착지.
	check("hop squashes on landing", is_equal_approx(UnitMotion.hop(0.9).stretch, -0.12))
	# 최고점.
	check("hop peaks", is_equal_approx(UnitMotion.hop_height(0.55), 0.25))
	# 웅크리는 동안 바닥.
	check("hop stays grounded while crouching", is_equal_approx(UnitMotion.hop_height(0.2), 0.0))


# 피격: 0.15 에서 눌림 −0.1·뒤로 12°. 넉백은 0.15 에서 1, 0.6 부터 0.
func _test_hit_and_knockback() -> void:
	# 눌림.
	check("hit squashes", is_equal_approx(UnitMotion.hit(0.15).stretch, -0.1))
	# 젖힘.
	check("hit leans back", is_equal_approx(UnitMotion.hit(0.15).lean, 12.0))
	# 끝.
	check("hit settles", is_equal_approx(UnitMotion.hit(1.0).lean, 0.0))
	# 넉백 최대.
	check("knockback peaks", is_equal_approx(UnitMotion.knockback_reach(UnitMotion.KNOCKBACK_PEAK), 1.0))
	# 복귀.
	check("knockback returns", is_equal_approx(UnitMotion.knockback_reach(0.6), 0.0))
	# 시작.
	check("knockback starts home", is_equal_approx(UnitMotion.knockback_reach(0.0), 0.0))


# 쓰러짐: t² 로 85° 까지.
func _test_death() -> void:
	# 시작은 0.
	check("death starts upright", is_equal_approx(UnitMotion.death(0.0).lean, 0.0))
	# 절반이면 1/4.
	check("death accelerates", is_equal_approx(UnitMotion.death(0.5).lean, 85.0 * 0.25))
	# 끝.
	check("death topples", is_equal_approx(UnitMotion.death(1.0).lean, 85.0))

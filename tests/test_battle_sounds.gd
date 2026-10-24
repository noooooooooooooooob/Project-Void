# BattleSounds(효과음 고르기)와 BattleAudio(재생기) 테스트.
extends TestCase

# 효과음 묶음 스크립트.
const SoundsScript := preload("res://Scripts/view/battle_sounds.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	_test_attack_clips()
	_test_impact_clips()
	_test_audio_counts_real_plays()
	_test_sounds_resource()
	return results()


# 서로 구분되는 클립 6개를 채운 묶음.
func _sounds() -> BattleSounds:
	var sounds: BattleSounds = SoundsScript.new()
	sounds.melee_swing = AudioStreamWAV.new()
	sounds.melee_hit = AudioStreamWAV.new()
	sounds.ranged_shot = AudioStreamWAV.new()
	sounds.ranged_hit = AudioStreamWAV.new()
	sounds.blocked = AudioStreamWAV.new()
	sounds.kill = AudioStreamWAV.new()
	return sounds


# 근접은 휘두르기, 원거리는 발사.
func _test_attack_clips() -> void:
	var sounds: BattleSounds = _sounds()
	check("melee attack swings", sounds.for_attack(CardData.AttackType.MELEE) == sounds.melee_swing)
	check("ranged attack shoots", sounds.for_attack(CardData.AttackType.RANGED) == sounds.ranged_shot)


# 처치 → 피해 0 → 공격 종류 순으로 고른다.
func _test_impact_clips() -> void:
	var sounds: BattleSounds = _sounds()
	check("kill wins", sounds.for_impact(CardData.AttackType.RANGED, 0, true) == sounds.kill)
	check("blocked hit picks the blocked clip", sounds.for_impact(CardData.AttackType.MELEE, 0, false) == sounds.blocked)
	check("melee hit", sounds.for_impact(CardData.AttackType.MELEE, 5, false) == sounds.melee_hit)
	check("ranged hit", sounds.for_impact(CardData.AttackType.RANGED, 5, false) == sounds.ranged_hit)
	# 비어 있는 칸은 null.
	var empty: BattleSounds = SoundsScript.new()
	# null.
	check("missing clip is null", empty.for_impact(CardData.AttackType.MELEE, 5, false) == null)


# null 은 세지 않고, 스트림은 트리 밖에서도 오류 없이 센다.
func _test_audio_counts_real_plays() -> void:
	var audio := BattleAudio.new()
	audio.play(null)
	check_eq("null clip is not played", audio.play_count, 0)
	audio.play(AudioStreamWAV.new())
	check_eq("clip counted", audio.play_count, 1)
	audio.free()


# 저장된 효과음 리소스가 6칸 모두 채워져 있다.
func _test_sounds_resource() -> void:
	var sounds: BattleSounds = load("res://Resources/audio/battle_sounds.tres")
	check("battle_sounds.tres loads", sounds != null)
	check("all six clips set", sounds.melee_swing != null and sounds.melee_hit != null and sounds.ranged_shot != null and sounds.ranged_hit != null and sounds.blocked != null and sounds.kill != null)

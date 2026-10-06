## 전투 효과음 재생기. 한 플레이어에서 여러 소리를 겹쳐 내고, 같은 소리가 반복돼도 덜 기계적이게 음높이를 조금씩 흔든다.
class_name BattleAudio
# Node: 씬 트리에 붙어야 소리가 난다.
extends Node

## 음높이를 흔드는 폭 (±8%).
const PITCH_JITTER: float = 0.08
## 동시에 겹쳐 낼 수 있는 소리 수.
const MAX_VOICES: int = 8

## 고를 클립 묶음 (BattlePlayback 이 여기서 고른다).
var sounds: BattleSounds
## 실제로 재생한 횟수 (테스트용).
var play_count: int = 0

# 여러 소리를 겹쳐 내는 플레이어 (처음 재생할 때 만든다).
var _player: AudioStreamPlayer


## 클립 하나를 낸다. null 이면 아무것도 안 한다. 트리 밖(테스트)에서는 세기만 한다.
func play(stream: AudioStream) -> void:
	# 빈 클립.
	if stream == null:
		return
	# 셌다.
	play_count += 1
	# 트리 밖이면 소리를 낼 수 없다.
	if not is_inside_tree():
		return
	# 처음이면 겹쳐 내기 플레이어를 만든다.
	if _player == null:
		_player = AudioStreamPlayer.new()
		var polyphonic := AudioStreamPolyphonic.new()
		polyphonic.polyphony = MAX_VOICES
		_player.stream = polyphonic
		add_child(_player)
		_player.play()
	# 겹쳐 내기 재생기에 음높이를 흔들어 넣는다.
	var playback := _player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	playback.play_stream(stream, 0.0, 0.0, 1.0 + randf_range(-PITCH_JITTER, PITCH_JITTER))

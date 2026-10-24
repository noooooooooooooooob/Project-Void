## 의뢰(원정) 정의 표. 층 수, 층마다 나오는 적 무리, 정예·보스, 사건, 보상 카드 풀.
## 적 이름은 Resources/content/units/<id>.tres, 사건은 Resources/story/<id>.txt.
class_name ChapterData
extends RefCounted

## 1장 본 의뢰.
const CHAPTER1: Dictionary = {
	"id": "ch1",
	"title": "1장 · 잠든 하수도",
	"client": "하수도 감독관",
	"summary": "구시가 하수도에서 검은 기름이 올라와 아랫동네 사람들이 깨어나지 않는다. 공허의 핵을 회수해 정화하라.",
	"story": true,
	## 이야기 의뢰에서 흐름 곳곳에 끼어드는 대본 (Resources/story/<id>.txt). 없는 항목은 건너뛴다.
	"scripts": {
		"briefing": "ch1_briefing",
		"void_choice": "ch1_void_choice",
		## 구역마다 처음 들어설 때. 황혼층이면 deep_floor_intros 쪽이 있으면 그것을 쓴다.
		"floor_intros": ["ch1_floor1", "ch1_floor2", "ch1_floor3", "ch1_floor4"],
		"deep_floor_intros": ["", "", "", "ch1_floor4_deep"],
		"boss": "ch1_boss",
		"purify": "ch1_purify",
		"epilogue": "ch1_epilogue",
	},
	## 끝까지 마치면 GameState.chapter 를 이 값으로 올린다.
	"unlocks_chapter": 2,
	"floors": 5,
	"floor_names": ["하수도 입구", "배수 터널", "침전조", "깊은 수로", "핵의 방"],
	"room": "sewer",
	"deep_room": "twilight",
	"boss_room": "core",
	## 출구 앞 지도 열 수 (열마다 3줄).
	"columns": 4,
	## 층마다 일반 전투 적 무리 후보.
	"pools": [
		[["rat", "rat"], ["rat", "leech"], ["hound"], ["rat", "rat", "rat"]],
		[["hound", "rat"], ["leech", "leech"], ["husk"], ["hound", "rat", "rat"]],
		[["husk", "rat"], ["husk", "leech"], ["hound", "hound"], ["husk", "rat", "rat"]],
		[["husk", "hound"], ["hound", "hound", "rat"], ["husk", "husk"], ["leech", "husk", "rat"]],
		[["husk", "hound", "rat"], ["husk", "husk", "leech"], ["hound", "hound", "leech"]],
	],
	"elites": [["brute"], ["brute", "rat"]],
	"boss": ["crown", "rat", "rat"],
	## 층 출구의 종류.
	"exits": ["battle", "battle", "elite", "battle", "boss"],
	## 이 층(0부터)을 마친 뒤 공허 속의 공허를 발견한다. -1 이면 없음.
	"void_in_void_after": 2,
	"events": ["ev_miner", "ev_puddle", "ev_supply", "ev_whisper", "ev_gear", "ev_fox"],
}

## 반복 의뢰 (1장 완료 후). 두 층짜리 파밍.
const REPEAT1: Dictionary = {
	"id": "rep1",
	"title": "반복 의뢰 · 하수도 잔재 청소",
	"client": "하수도 감독관",
	"summary": "정화된 하수도 곳곳에 남은 작은 공허를 치운다. 보상은 적지만 위험도 적다.",
	"story": false,
	"floors": 2,
	"floor_names": ["잔재 구역 A", "잔재 구역 B"],
	"room": "sewer",
	"deep_room": "twilight",
	"boss_room": "sewer",
	"columns": 3,
	"pools": [
		[["rat", "rat"], ["hound", "rat"], ["leech", "leech"], ["husk"]],
		[["husk", "rat"], ["hound", "hound"], ["husk", "leech"], ["brute"]],
	],
	"elites": [["brute"]],
	"boss": ["brute", "rat"],
	"exits": ["battle", "elite"],
	"void_in_void_after": -1,
	"events": ["ev_miner", "ev_puddle", "ev_supply", "ev_gear"],
}

## 보상으로 나오는 카드 (파티원 id → 카드 id).
const REWARD_CARDS: Dictionary = {
	"hangyeol": ["slash", "guard", "rift_thrust", "quick_shot", "heavy_cut", "sweep", "void_step", "rift_burst", "second_wind", "cover"],
	"hongyeon": ["blood_claw", "blood_veil", "bloodletting", "fox_fang", "frenzy", "crimson_feast", "red_fox", "blood_lance", "drowsy_guard", "blood_burst"],
}

## 노드 종류.
const BATTLE: String = "battle"
const ELITE: String = "elite"
const BOSS: String = "boss"
const EVENT: String = "event"
const REST: String = "rest"
const SUPPLY: String = "supply"
const SHOP: String = "shop"

## 노드 종류의 화면 이름과 설명.
const NODE_INFO: Dictionary = {
	"battle": {"name": "전투", "desc": "공허의 괴물과 싸운다."},
	"elite": {"name": "정예", "desc": "강한 괴물. 이기면 장비를 얻는다."},
	"boss": {"name": "핵의 수호자", "desc": "공허의 핵을 지키는 존재."},
	"event": {"name": "사건", "desc": "무슨 일이 일어날지 모른다."},
	"rest": {"name": "휴식", "desc": "숨을 고르고 상처를 돌본다."},
	"supply": {"name": "보급", "desc": "쓸 만한 장비를 하나 고른다."},
	"shop": {"name": "상점", "desc": "공허 상인. 자금으로 장비·카드·치료를 산다."},
}


static func get_request(request_id: String) -> Dictionary:
	match request_id:
		"ch1":
			return CHAPTER1
		"rep1":
			return REPEAT1
	return {}

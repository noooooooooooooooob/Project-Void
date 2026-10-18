# 카드 에디터: 영어 이름·설명 + JSON 내보내기

## 왜

카드 에디터(claude.ai 아티팩트)에서 만든 카드를 새로 만들 Godot 게임이 데이터로 읽어,
카드 템플릿에 이름·SP·그림 등을 자동으로 채우게 하려 한다. 지금 게임은 프로토타입이라 다시 만들 예정이므로
**게임 쪽 코드는 이번 범위가 아니다.** 이번에는 에디터가 게임이 읽기 쉬운 파일을 내보내는 데까지만 한다.
게임은 한국어·영어를 모두 쓸 예정이라 에디터에 영어 칸이 필요하다.

## 목표

1. 카드(기본 면과 강화 면 각각)·키워드·덱에 영어 이름과 영어 설명을 입력할 수 있다.
2. 상단 **내보내기** 버튼으로 `project-void-cards.zip`을 받는다. 안에는 `cards.json`과 일러스트 파일이 들어 있다.

## 하지 않는 것

- Godot 쪽 가져오기 코드, `.tres` 변환
- CSV 내보내기, 가져오기(JSON → 에디터)
- 카드 그림(목록·미리보기)에 영어 표시. 카드 그림은 지금처럼 한국어만 보여 준다 *(내 판단)*
- 사람이 정하는 게임 id(`strike` 같은 이름) — 에디터 문서 id를 그대로 쓴다 *(내 판단)*

## 실패로 보는 경우

- 내보낸 파일에 사용자가 만들지 않은 것(자동으로 생긴 강화 등)이 들어 있음. 강화를 추가하지 않은 카드는 `"upgrades": []`
- 다시 내보낼 때 같은 카드의 id가 바뀜
- 영어 칸을 추가하면서 기존 저장(덱 이름, 키워드 저장)이 영어 값을 지움

## 에디터 변경

### 저장 형식 (db)

기존 문서에 평평한 필드로 추가한다. 없는 예전 문서는 빈 문자열로 읽는다 *(내 판단: 기존 필드 스타일과 맞춤)*.

| 컬렉션 | 추가 필드 |
|---|---|
| `cards` (기본 면과 `upgrades[]` 각 면) | `nameEn`, `descriptionEn` |
| `keywords` | `nameEn`, `descriptionEn` |
| `decks` | `nameEn` |

- 영어 칸은 비어 있어도 저장할 수 있다 (검증하지 않음). 이름 앞뒤 공백은 잘라 낸다(한국어 이름과 같음). 설명은 그대로 둔다.
- `saveDeck`/`saveKeyword`는 문서를 통째로 `set` 하므로 영어 필드도 함께 써야 한다.
- 영어 설명은 한국어 설명과 같은 최대 길이(20000자)를 둔다.

### 화면

- 카드 편집 창: 이름 줄 아래에 **영어 이름**, 설명 아래에 **영어 설명** 칸. 보고 있는 면(기본/강화 n)을 고친다. 읽기 전용이면 readonly.
- 강화 추가(`newUpgrade`): 한국어·영어 이름 모두 빈 칸으로 시작한다 (지금의 `베기+` 자동 이름 제거 — 사용자 요청). 이름은 사용자가 직접 짓고, 한국어 이름이 비어 있으면 지금처럼 저장 시 "강화 n: 이름을 입력하세요" 오류가 난다. 나머지 항목(영어 설명 포함)은 지금처럼 앞 단계 값을 복사한다.
- 복제: 한국어 이름에만 " 사본"을 붙이고 영어 이름은 그대로 복사한다 *(내 판단)*.
- 키워드 탭: 각 키워드 행에 영어 이름 입력과 영어 설명 칸을 추가한다.
- 덱 탭: 덱 이름 입력 옆(또는 아래)에 영어 덱 이름 입력을 추가한다.

### 내보내기 버튼

- 상단 바(`새 카드` 버튼 옆)에 **내보내기**. 모든 탭에서 보이고 읽기 전용 사용자도 쓸 수 있다.
- `downloads` 능력(capability)이 없으면(`claude.use("downloads")`가 `null`) 버튼을 숨긴다.
- 누르면 버튼을 잠그고 그림을 모은 뒤 zip을 만들어 `downloads.save({ filename: "project-void-cards.zip", data })`를 부른다.
  - `declined`: 아무 메시지도 띄우지 않는다.
  - `rate_limited`: "잠시 후 다시 눌러 주세요".
  - 그 밖의 오류: "내보내지 못했어요".
- 그림을 못 가져온 것이 있으면 그 면의 `art`를 `null`로 두고 계속 진행한다. 저장 후 "그림 n개를 넣지 못했어요" 토스트를 띄운다.
- 카드가 0장이어도 내보낼 수 있다 (빈 목록).

## `cards.json`

```json
{
  "keywords": [
    { "id": "kw1", "name": { "ko": "화상", "en": "Burn" }, "description": { "ko": "…", "en": "…" } }
  ],
  "decks": [
    { "id": "d1", "name": { "ko": "포수", "en": "Gunner" } }
  ],
  "cards": [
    {
      "id": "c1",
      "deck": null,
      "name": { "ko": "베기", "en": "Slash" },
      "description": { "ko": "…", "en": "" },
      "sp": 1,
      "cost": 2,
      "category": "attack",
      "attackType": "melee",
      "area": [[0, 0], [1, 0]],
      "keywords": ["kw1"],
      "art": "art/3f9a….png",
      "upgrades": [
        { "name": { "ko": "베기+", "en": "Slash+" }, "description": { "ko": "…", "en": "…" },
          "sp": 1, "cost": 2, "category": "attack", "attackType": "melee",
          "area": [[0, 0]], "keywords": [], "art": null }
      ]
    }
  ]
}
```

- 최상위에는 `keywords`, `decks`, `cards`만 둔다 (version·내보낸 시각 없음 — 사용자 요청).
- 텍스트는 `{ "ko", "en" }`로 묶는다. 나중에 언어를 늘리기 쉽게 하려는 것이다 *(내 판단)*. 빈 값은 `""`.
- `category`: `attack | skill | special`, `attackType`: `melee | ranged | ally | self`
- `area`: 에디터 좌표 그대로 (x = 열, +가 뒤쪽 / y = 행, +가 아래, -2..2). 빈 배열이면 단일(기준 칸 하나). 정규화된 순서(y, x 오름차순)로 넣는다.
- `deck`: 덱 id, 공용 카드는 `null`.
- `keywords`: 키워드 id 배열, 카드에 붙인 순서. 지워진 키워드 id는 뺀다.
- `art`: zip 안 상대 경로 또는 `null`.
- 순서
  - `decks`: 덱 탭 순서
  - `cards`: 공용 카드(직접 정렬 순서, `cardsInDeck(cards, null)`)를 먼저 넣고, 그다음 덱 탭 순서대로 각 덱의 카드(`cardsInDeck`)를 넣는다.
  - `keywords`: 키워드 탭 순서 (만든 순서)
- 지워진 덱을 가리키는 카드(화면 어디에도 안 보이는 카드)는 넣지 않는다 *(내 판단)*.
- `createdAt`, `order` 같은 에디터 내부 값은 넣지 않는다.
- JSON은 2칸 들여쓰기, UTF-8.

## zip

```
project-void-cards.zip
├─ cards.json
└─ art/
   └─ {그림 id}.{png|jpg|webp|gif}
```

- 그림 바이트는 `fetch("/_blob/" + id)`로 가져온다. 확장자는 응답 `Content-Type`으로 정하고, 모르는 타입이면 `bin`으로 한다.
- 같은 그림을 여러 면이 쓰면 파일은 하나만 넣는다.
- zip은 압축 없는 store 방식으로 직접 만든다. 그림은 이미 압축돼 있고, 외부 라이브러리 없이 Node 테스트로 검증할 수 있기 때문이다 *(내 판단)*. 파일 이름은 UTF-8 플래그를 켠다.

## 코드 구조

- `card_model.js` (순수, Node 테스트)
  - `normalizeFace`, `normalizeKeyword`, `normalizeDeck`에 영어 필드를 추가한다. `newUpgrade`는 `name`, `nameEn`을 `""`로 둔다.
  - `buildExport({ cards, decks, keywords }, artPath)` → `cards.json` 객체. `artPath(assetId)`는 zip 안 경로를 돌려준다. 그림을 못 가져온 경우는 `null`을 돌려주게 해서 실패를 처리한다.
  - `exportAssets(cards, decks)` → 내보낼 카드들이 쓰는 그림 id 목록 (중복 없음).
  - `makeZip([{ name, bytes }])` → `Uint8Array` (store, CRC32).
- `index.src.html`: 영어 입력 칸, 키워드·덱 영어 칸, 저장 시 영어 필드, 내보내기 버튼과 흐름, `downloads` 사용.
- 게시할 때 capabilities에 `downloads: true`를 추가한다. 기존 `assets`, `db`, `user`는 유지한다.
- `README.md`에 내보내기와 JSON 형식을 설명한다.

## 남은 위험

- 아티팩트 프레임 안에서 `fetch("/_blob/…")`가 되는지는 게시 후 확인해야 한다. 안 되면 그림 없이 JSON만 내보내도록 대체 동작이 이미 정해져 있다.

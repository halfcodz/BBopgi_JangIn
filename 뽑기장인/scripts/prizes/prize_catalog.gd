class_name PrizeCatalog
extends RefCounted
## 뽑기방 상품 목록.
## model: assets/prizes/<model>.glb/.json, scale: 모델 배율, mass: 총 무게(kg), cost: 사장님 원가(원)
## size_class: "big" 큰 기계용 / "small" 작은 기계용
## colorways: [주 원단, 포인트 원단, 세번째 원단] 색 조합 목록

const ITEMS := {
	"bear": {
		"name": "곰돌이 인형", "model": "bear", "size_class": "big",
		"scale": 1.0, "mass": 0.30, "cost": 4500, "friction": 0.95,
		"colorways": [
			[Color(0.55, 0.36, 0.22), Color(0.92, 0.82, 0.66), Color(0.96, 0.70, 0.74)],
			[Color(0.93, 0.90, 0.84), Color(0.98, 0.80, 0.84), Color(0.98, 0.70, 0.75)],
			[Color(0.82, 0.62, 0.42), Color(0.98, 0.93, 0.85), Color(0.96, 0.70, 0.74)],
			[Color(0.97, 0.78, 0.84), Color(1.0, 0.95, 0.96), Color(0.96, 0.62, 0.70)],
		],
	},
	"bunny": {
		"name": "토끼 인형", "model": "bunny", "size_class": "big", "fabric": "velboa",
		"scale": 1.0, "mass": 0.26, "cost": 4000, "friction": 0.95,
		"colorways": [
			[Color(0.97, 0.95, 0.94), Color(0.97, 0.95, 0.94), Color(0.98, 0.70, 0.76)],
			[Color(0.80, 0.78, 0.80), Color(0.95, 0.93, 0.93), Color(0.98, 0.72, 0.78)],
			[Color(0.90, 0.80, 0.66), Color(0.98, 0.95, 0.90), Color(0.97, 0.68, 0.70)],
			[Color(0.99, 0.82, 0.88), Color(1.0, 0.96, 0.97), Color(0.95, 0.55, 0.66)],
		],
	},
	"penguin": {
		"name": "펭귄 인형", "model": "penguin", "size_class": "big",
		"scale": 1.0, "mass": 0.27, "cost": 4200, "friction": 0.9,
		"colorways": [
			[Color(0.13, 0.15, 0.24), Color(0.97, 0.97, 0.96), Color(0.98, 0.62, 0.20)],
			[Color(0.42, 0.62, 0.86), Color(0.97, 0.97, 0.96), Color(0.98, 0.78, 0.25)],
			[Color(0.30, 0.30, 0.33), Color(0.97, 0.97, 0.96), Color(0.98, 0.62, 0.20)],
		],
	},
	"dino": {
		"name": "공룡 인형", "model": "dino", "size_class": "big",
		"scale": 1.0, "mass": 0.32, "cost": 4800, "friction": 0.93,
		"colorways": [
			[Color(0.48, 0.76, 0.42), Color(0.97, 0.94, 0.78), Color(0.98, 0.80, 0.30)],
			[Color(0.52, 0.70, 0.95), Color(0.95, 0.96, 0.98), Color(0.98, 0.62, 0.72)],
			[Color(0.98, 0.66, 0.74), Color(1.0, 0.94, 0.94), Color(0.72, 0.56, 0.92)],
			[Color(0.70, 0.56, 0.90), Color(0.96, 0.94, 0.98), Color(0.55, 0.85, 0.65)],
		],
	},
	"cat": {
		"name": "고양이 모찌 쿠션", "model": "cat", "size_class": "big",
		"scale": 1.0, "mass": 0.30, "cost": 5000, "friction": 0.97,
		"colorways": [
			[Color(0.98, 0.96, 0.92), Color(0.98, 0.96, 0.92), Color(0.97, 0.70, 0.74)],
			[Color(0.99, 0.80, 0.52), Color(0.90, 0.56, 0.24), Color(0.97, 0.66, 0.66)],
			[Color(0.62, 0.62, 0.66), Color(0.40, 0.40, 0.44), Color(0.97, 0.70, 0.74)],
			[Color(0.30, 0.28, 0.30), Color(0.22, 0.20, 0.22), Color(0.95, 0.62, 0.70)],
		],
	},
	"chick": {
		"name": "삐약이 병아리", "model": "chick", "size_class": "small",
		"scale": 1.0, "mass": 0.035, "cost": 900, "friction": 0.95,
		"colorways": [
			[Color(1.0, 0.88, 0.32), Color(0.98, 0.58, 0.18), Color(0.98, 0.62, 0.62)],
			[Color(0.98, 0.96, 0.88), Color(0.98, 0.58, 0.18), Color(0.98, 0.62, 0.62)],
		],
	},
	"duck": {
		"name": "꽥꽥 오리", "model": "duck", "size_class": "small",
		"scale": 1.0, "mass": 0.035, "cost": 900, "friction": 0.95,
		"colorways": [
			[Color(1.0, 0.92, 0.45), Color(0.98, 0.55, 0.15), Color(0.98, 0.62, 0.62)],
			[Color(0.97, 0.97, 0.96), Color(0.98, 0.62, 0.18), Color(0.98, 0.62, 0.62)],
		],
	},
	"mochi": {
		"name": "말랑 모찌볼", "model": "mochi", "size_class": "small",
		"scale": 1.0, "mass": 0.028, "cost": 700, "friction": 0.9,
		"colorways": [
			[Color(0.78, 0.90, 1.0), Color(0.78, 0.90, 1.0), Color(0.98, 0.62, 0.70)],
			[Color(1.0, 0.86, 0.90), Color(1.0, 0.86, 0.90), Color(0.98, 0.55, 0.66)],
			[Color(0.86, 0.98, 0.84), Color(0.86, 0.98, 0.84), Color(0.98, 0.62, 0.70)],
			[Color(1.0, 0.96, 0.78), Color(1.0, 0.96, 0.78), Color(0.98, 0.62, 0.66)],
			[Color(0.88, 0.84, 1.0), Color(0.88, 0.84, 1.0), Color(0.98, 0.62, 0.72)],
		],
	},
	"mini_bear": {
		"name": "미니 곰 키링", "model": "bear", "size_class": "small",
		"scale": 0.42, "mass": 0.04, "cost": 1100, "friction": 0.95, "keyring": true,
		"colorways": [
			[Color(0.55, 0.36, 0.22), Color(0.92, 0.82, 0.66), Color(0.96, 0.70, 0.74)],
			[Color(0.93, 0.90, 0.84), Color(0.98, 0.80, 0.84), Color(0.98, 0.70, 0.75)],
			[Color(0.97, 0.78, 0.84), Color(1.0, 0.95, 0.96), Color(0.96, 0.62, 0.70)],
		],
	},
	"mini_bunny": {
		"name": "미니 토끼 키링", "model": "bunny", "size_class": "small", "fabric": "velboa",
		"scale": 0.4, "mass": 0.035, "cost": 1100, "friction": 0.95, "keyring": true,
		"colorways": [
			[Color(0.97, 0.95, 0.94), Color(0.97, 0.95, 0.94), Color(0.98, 0.70, 0.76)],
			[Color(0.99, 0.82, 0.88), Color(1.0, 0.96, 0.97), Color(0.95, 0.55, 0.66)],
		],
	},
	"figure_box": {
		"name": "럭키 피규어 박스", "model": "figure_box", "size_class": "big",
		"scale": 1.0, "mass": 0.2, "cost": 6500, "friction": 0.42, "angular_damp": 0.4,
		"texture": "res://assets/textures/prizes/figure_box.png",
		"colorways": [[Color(1, 1, 1)]],
	},
	"snack": {
		"name": "바삭 콘칩", "model": "snack_bag", "size_class": "small",
		"scale": 0.75, "mass": 0.045, "cost": 800, "friction": 0.5, "angular_damp": 0.6,
		"texture": "res://assets/textures/prizes/snack_bag.png",
		"colorways": [[Color(1, 1, 1)]],
	},
	"capsule": {
		"name": "랜덤 캡슐 토이", "model": "capsule", "size_class": "small",
		"scale": 1.0, "mass": 0.03, "cost": 600, "friction": 0.3, "bounce": 0.25, "angular_damp": 0.3,
		"colorways": [
			[Color(0.95, 0.35, 0.42), Color(1.0, 0.85, 0.3)],
			[Color(0.30, 0.62, 0.96), Color(1.0, 0.6, 0.75)],
			[Color(0.98, 0.84, 0.28), Color(0.4, 0.8, 0.5)],
			[Color(0.52, 0.84, 0.50), Color(0.7, 0.5, 0.95)],
			[Color(0.72, 0.52, 0.95), Color(1.0, 0.95, 0.9)],
		],
	},
	"panda": {
		"name": "판다 인형", "model": "panda", "size_class": "big",
		"scale": 1.0, "mass": 0.30, "cost": 4800, "friction": 0.95,
		"colorways": [
			[Color(0.97, 0.97, 0.95), Color(0.12, 0.12, 0.13), Color(0.96, 0.70, 0.74)],
			[Color(0.99, 0.90, 0.92), Color(0.35, 0.22, 0.24), Color(0.96, 0.62, 0.70)],
		],
	},
	"shiba": {
		"name": "시바견 인형", "model": "shiba", "size_class": "big",
		"scale": 1.0, "mass": 0.30, "cost": 4600, "friction": 0.95,
		"colorways": [
			[Color(0.88, 0.55, 0.28), Color(0.99, 0.95, 0.88), Color(0.96, 0.70, 0.74)],
			[Color(0.22, 0.2, 0.2), Color(0.96, 0.9, 0.82), Color(0.96, 0.70, 0.74)],
			[Color(0.96, 0.92, 0.84), Color(1.0, 0.98, 0.95), Color(0.96, 0.70, 0.74)],
		],
	},
	"shark": {
		"name": "아기 상어 인형", "model": "shark", "size_class": "big",
		"scale": 1.0, "mass": 0.26, "cost": 4400, "friction": 0.9,
		"colorways": [
			[Color(0.45, 0.55, 0.68), Color(0.97, 0.97, 0.96), Color(0.92, 0.4, 0.45)],
			[Color(0.55, 0.75, 0.95), Color(0.97, 0.97, 0.96), Color(0.92, 0.4, 0.45)],
			[Color(0.98, 0.70, 0.78), Color(1.0, 0.95, 0.96), Color(0.85, 0.3, 0.4)],
		],
	},
	"frog": {
		"name": "개굴 개구리", "model": "frog", "size_class": "big",
		"scale": 1.0, "mass": 0.22, "cost": 3800, "friction": 0.95,
		"colorways": [
			[Color(0.55, 0.8, 0.35), Color(0.97, 0.96, 0.8), Color(0.98, 0.6, 0.65)],
			[Color(0.4, 0.75, 0.7), Color(0.95, 0.98, 0.9), Color(0.98, 0.6, 0.65)],
		],
	},
	"mini_frog": {
		"name": "미니 개구리", "model": "frog", "size_class": "small",
		"scale": 0.5, "mass": 0.035, "cost": 900, "friction": 0.95,
		"colorways": [[Color(0.55, 0.8, 0.35), Color(0.97, 0.96, 0.8), Color(0.98, 0.6, 0.65)]],
	},
	"hamster": {
		"name": "볼빵빵 햄스터", "model": "hamster", "size_class": "small",
		"scale": 1.0, "mass": 0.035, "cost": 900, "friction": 0.95,
		"colorways": [
			[Color(0.9, 0.65, 0.38), Color(0.99, 0.96, 0.9), Color(0.96, 0.66, 0.7)],
			[Color(0.72, 0.72, 0.74), Color(0.99, 0.98, 0.96), Color(0.96, 0.66, 0.7)],
			[Color(0.98, 0.9, 0.78), Color(1.0, 0.98, 0.96), Color(0.96, 0.66, 0.7)],
		],
	},
	"whale": {
		"name": "통통 고래", "model": "whale", "size_class": "small",
		"scale": 1.0, "mass": 0.035, "cost": 900, "friction": 0.9,
		"colorways": [
			[Color(0.35, 0.55, 0.9), Color(0.95, 0.97, 1.0), Color(0.96, 0.62, 0.7)],
			[Color(0.55, 0.85, 0.95), Color(0.97, 0.99, 1.0), Color(0.96, 0.62, 0.7)],
		],
	},
	"jp_figure_a": {
		"name": "마법소녀 프라이즈 피규어", "model": "figure_jp", "size_class": "bridge",
		"scale": 1.0, "mass": 0.8, "cost": 9000, "friction": 0.55, "angular_damp": 0.5,
		"texture": "res://assets/textures/prizes/jp_figure_a.png",
		"colorways": [[Color(1, 1, 1)]],
	},
	"jp_figure_b": {
		"name": "로봇 프라이즈 피규어", "model": "figure_jp", "size_class": "bridge",
		"scale": 1.0, "mass": 0.85, "cost": 9000, "friction": 0.55, "angular_damp": 0.5,
		"texture": "res://assets/textures/prizes/jp_figure_b.png",
		"colorways": [[Color(1, 1, 1)]],
	},
	"jp_figure_c": {
		"name": "냥냥 마법사 프라이즈 피규어", "model": "figure_jp", "size_class": "bridge",
		"scale": 1.0, "mass": 0.8, "cost": 9500, "friction": 0.55, "angular_damp": 0.5,
		"texture": "res://assets/textures/prizes/jp_figure_c.png",
		"colorways": [[Color(1, 1, 1)]],
	},
	"jp_figure_d": {
		"name": "아기용 루루 프라이즈 피규어", "model": "figure_jp", "size_class": "bridge",
		"scale": 1.0, "mass": 0.8, "cost": 9500, "friction": 0.55, "angular_damp": 0.5,
		"texture": "res://assets/textures/prizes/jp_figure_d.png",
		"colorways": [[Color(1, 1, 1)]],
	},
	# ---------------------------------------------------------------- 말랑이(스퀴시)
	"squishy_bread": {
		"name": "말랑 식빵", "model": "squishy_bread", "size_class": "small",
		"scale": 1.0, "mass": 0.025, "cost": 1200, "friction": 0.95, "bounce": 0.08, "angular_damp": 1.5,
		"colorways": [
			[Color(1.0, 0.95, 0.82), Color(0.84, 0.56, 0.28), Color(1.0, 0.6, 0.66)],
			[Color(0.82, 0.62, 0.44), Color(0.45, 0.28, 0.16), Color(1.0, 0.62, 0.66)],
			[Color(0.75, 0.9, 0.62), Color(0.45, 0.62, 0.3), Color(1.0, 0.62, 0.66)],
		],
	},
	"squishy_peach": {
		"name": "말랑 복숭아", "model": "squishy_peach", "size_class": "small",
		"scale": 1.0, "mass": 0.025, "cost": 1200, "friction": 0.95, "bounce": 0.08, "angular_damp": 1.5,
		"colorways": [
			[Color(1.0, 0.86, 0.76), Color(1.0, 0.56, 0.64), Color(1.0, 0.45, 0.55)],
			[Color(1.0, 0.92, 0.65), Color(1.0, 0.7, 0.35), Color(1.0, 0.5, 0.5)],
		],
	},
	"squishy_paw": {
		"name": "냥발 말랑이", "model": "squishy_paw", "size_class": "small",
		"scale": 1.0, "mass": 0.022, "cost": 1300, "friction": 0.95, "bounce": 0.08, "angular_damp": 1.5,
		"colorways": [
			[Color(0.98, 0.96, 0.93), Color(1.0, 0.62, 0.72)],
			[Color(0.62, 0.62, 0.66), Color(1.0, 0.65, 0.74)],
			[Color(0.24, 0.22, 0.24), Color(1.0, 0.62, 0.72)],
			[Color(1.0, 0.78, 0.45), Color(1.0, 0.6, 0.66)],
		],
	},
	# ---------------------------------------------------------------- 키캡 키링
	"keycap_heart": {
		"name": "하트 키캡 키링", "model": "keycap_heart", "size_class": "small", "keyring": true,
		"scale": 1.0, "mass": 0.014, "cost": 1500, "friction": 0.45, "bounce": 0.15, "angular_damp": 0.8,
		"colorways": [
			[Color(1.0, 0.72, 0.8), Color(1.0, 0.55, 0.68), Color(1, 1, 1)],
			[Color(0.62, 0.8, 1.0), Color(0.42, 0.6, 0.95), Color(1, 1, 1)],
			[Color(0.96, 0.96, 0.95), Color(0.8, 0.8, 0.84), Color(1.0, 0.35, 0.5)],
			[Color(0.24, 0.24, 0.28), Color(0.14, 0.14, 0.16), Color(1.0, 0.85, 0.3)],
			[Color(0.72, 0.94, 0.72), Color(0.5, 0.8, 0.55), Color(1, 1, 1)],
			[Color(1.0, 0.9, 0.5), Color(1.0, 0.72, 0.3), Color(1.0, 0.42, 0.4)],
			[Color(0.8, 0.68, 1.0), Color(0.6, 0.48, 0.92), Color(1, 1, 1)],
		],
	},
	"keycap_cat": {
		"name": "냥이 키캡 키링", "model": "keycap_cat", "size_class": "small", "keyring": true,
		"scale": 1.0, "mass": 0.015, "cost": 1600, "friction": 0.45, "bounce": 0.15, "angular_damp": 0.8,
		"colorways": [
			[Color(0.98, 0.97, 0.95), Color(0.85, 0.85, 0.88), Color(1.0, 0.6, 0.7)],
			[Color(1.0, 0.75, 0.45), Color(0.9, 0.55, 0.25), Color(1.0, 0.6, 0.7)],
			[Color(0.3, 0.3, 0.34), Color(0.18, 0.18, 0.2), Color(1.0, 0.6, 0.7)],
			[Color(0.7, 0.85, 1.0), Color(0.5, 0.65, 0.95), Color(1.0, 0.62, 0.72)],
		],
	},
	# ---------------------------------------------------------------- 피젯 토이 / 슬라임
	"popit": {
		"name": "무지개 팝잇", "model": "popit", "size_class": "small",
		"scale": 1.0, "mass": 0.028, "cost": 1000, "friction": 0.85, "bounce": 0.1, "angular_damp": 1.0,
		"colorways": [
			[Color(1.0, 0.5, 0.62), Color(1.0, 0.85, 0.4), Color(0.5, 0.76, 1.0)],
			[Color(0.6, 0.9, 0.62), Color(0.72, 0.6, 1.0), Color(1.0, 0.7, 0.4)],
			[Color(0.76, 0.6, 1.0), Color(1.0, 0.66, 0.85), Color(0.55, 0.86, 1.0)],
		],
	},
	"slime_cup": {
		"name": "말랑 슬라임 컵", "model": "slime_cup", "size_class": "small",
		"scale": 1.0, "mass": 0.07, "cost": 1100, "friction": 0.5, "bounce": 0.05, "angular_damp": 0.8,
		"colorways": [
			[Color(0.62, 0.9, 1.0), Color(1, 1, 1), Color(1.0, 0.6, 0.75)],
			[Color(1.0, 0.75, 0.86), Color(1, 1, 1), Color(0.6, 0.8, 1.0)],
			[Color(0.8, 1.0, 0.6), Color(1, 1, 1), Color(1.0, 0.85, 0.4)],
			[Color(0.86, 0.72, 1.0), Color(1, 1, 1), Color(0.6, 1.0, 0.85)],
		],
	},
	# ---------------------------------------------------------------- 전자기기 경품(인쇄 상자)
	"gift_earbuds": {
		"name": "무선 이어폰", "model": "gift_earbuds", "size_class": "big",
		"scale": 1.0, "mass": 0.16, "cost": 12000, "friction": 0.45, "angular_damp": 0.5,
		"texture": "res://assets/textures/prizes/gift_earbuds.png",
		"colorways": [[Color(1, 1, 1)]],
	},
	"gift_powerbank": {
		"name": "보조배터리 10000mAh", "model": "gift_powerbank", "size_class": "big",
		"scale": 1.0, "mass": 0.24, "cost": 9000, "friction": 0.45, "angular_damp": 0.5,
		"texture": "res://assets/textures/prizes/gift_powerbank.png",
		"colorways": [[Color(1, 1, 1)]],
	},
	"gift_fan": {
		"name": "휴대용 미니 선풍기", "model": "gift_fan", "size_class": "big",
		"scale": 1.0, "mass": 0.18, "cost": 6000, "friction": 0.45, "angular_damp": 0.5,
		"texture": "res://assets/textures/prizes/gift_fan.png",
		"colorways": [[Color(1, 1, 1)]],
	},
	"gift_speaker": {
		"name": "블루투스 스피커", "model": "gift_speaker", "size_class": "big",
		"scale": 1.0, "mass": 0.32, "cost": 15000, "friction": 0.45, "angular_damp": 0.5,
		"texture": "res://assets/textures/prizes/gift_speaker.png",
		"colorways": [[Color(1, 1, 1)]],
	},
	"gift_lamp": {
		"name": "LED 달 무드등", "model": "gift_lamp", "size_class": "big",
		"scale": 1.0, "mass": 0.22, "cost": 8000, "friction": 0.45, "angular_damp": 0.5,
		"texture": "res://assets/textures/prizes/gift_lamp.png",
		"colorways": [[Color(1, 1, 1)]],
	},
	# ---------------------------------------------------------------- 큰 머리 마스코트 인형
	"chibi_cat": {
		"name": "몽글 냥이 마스코트", "model": "chibi_cat", "size_class": "big",
		"scale": 1.0, "mass": 0.22, "cost": 5500, "friction": 0.95,
		"colorways": [
			[Color(0.8, 0.7, 1.0), Color(1.0, 0.96, 0.92), Color(1.0, 0.62, 0.78)],
			[Color(1.0, 0.78, 0.88), Color(1.0, 0.97, 0.96), Color(1.0, 0.5, 0.7)],
			[Color(0.97, 0.97, 0.98), Color(1.0, 0.92, 0.86), Color(1.0, 0.62, 0.74)],
			[Color(0.7, 0.92, 0.86), Color(1.0, 0.97, 0.92), Color(1.0, 0.62, 0.74)],
		],
	},
	"chibi_bunny": {
		"name": "몽글 토끼 마스코트", "model": "chibi_bunny", "size_class": "big", "fabric": "velboa",
		"scale": 1.0, "mass": 0.22, "cost": 5500, "friction": 0.95,
		"colorways": [
			[Color(0.98, 0.97, 0.98), Color(1.0, 0.92, 0.94), Color(1.0, 0.6, 0.75)],
			[Color(1.0, 0.76, 0.88), Color(1.0, 0.96, 0.97), Color(0.95, 0.45, 0.65)],
			[Color(0.76, 0.66, 0.98), Color(0.98, 0.95, 1.0), Color(1.0, 0.62, 0.8)],
			[Color(0.68, 0.84, 1.0), Color(0.97, 0.98, 1.0), Color(1.0, 0.62, 0.75)],
		],
	},
}


static func ids() -> Array:
	return ITEMS.keys()


static func ids_for(size_class: String) -> Array:
	var out := []
	for id in ITEMS:
		var c: String = ITEMS[id]["size_class"]
		if c == size_class or c == "any":
			out.append(id)
	return out


static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func display_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)


static func cost(id: String) -> int:
	return int(ITEMS.get(id, {}).get("cost", 0))

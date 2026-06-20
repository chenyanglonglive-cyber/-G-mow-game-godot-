class_name TDConfig
extends RefCounted

const LEVEL := {
	"width": 450,
	"height": 560,
	"cols": 11,
	"rows": 14,
	"grid_size": 40,
	"start_gold": 2000,
	"start_lives": 20,
	"build_slots": [
		Vector2i(3, 1), Vector2i(7, 1),
		Vector2i(1, 3), Vector2i(3, 3), Vector2i(5, 3), Vector2i(7, 3), Vector2i(9, 3),
		Vector2i(1, 7), Vector2i(3, 7), Vector2i(7, 7), Vector2i(9, 7),
		Vector2i(3, 10), Vector2i(7, 10),
		Vector2i(2, 11), Vector2i(5, 11), Vector2i(8, 11)
	],
	"path1": [
		Vector2(5.125, -1.0), Vector2(5.125, 2.33), Vector2(2.37, 2.33),
		Vector2(2.37, 10.4), Vector2(3.83, 12.0), Vector2(3.83, 14.0)
	],
	"path2": [
		Vector2(5.125, -1.0), Vector2(5.125, 2.33), Vector2(8.03, 2.33),
		Vector2(8.03, 10.4), Vector2(6.42, 12.0), Vector2(6.42, 14.0)
	]
}

const TOWERS := {
	"piercing": {
		"name": "雷霆穿甲机",
		"names": ["雷霆穿甲机 1级", "雷霆穿甲机 2级", "【雷霆·超载轨道炮】", "宙斯·天罚战神"],
		"color": Color("#00d2ff"),
		"bullet_color": Color("#00f6ff"),
		"costs": [200, 300, 450, 0],
		"ranges": [120, 150, 180, 240],
		"fire_rates": [0.80, 0.65, 0.50, 0.20],
		"damage": [25, 45, 75, 300],
		"bullet_speed": 900.0,
		"texture_prefix": "piercing"
	},
	"blade": {
		"name": "斩空刀锋机",
		"names": ["斩空刀锋机 1级", "斩空刀锋机 2级", "【斩空·引力磁爆盘】", "修罗·狂怒战神"],
		"color": Color("#ff0055"),
		"bullet_color": Color("#ff5577"),
		"costs": [250, 350, 500, 0],
		"ranges": [65, 80, 95, 130],
		"fire_rates": [0.20, 0.18, 0.15, 0.08],
		"damage": [8, 15, 25, 120],
		"texture_prefix": "blade"
	},
	"frost": {
		"name": "霜冻控场机",
		"names": ["霜冻控场机 1级", "霜冻控场机 2级", "【霜冻·绝对零度角】", "极寒·凋零战神"],
		"color": Color("#00ffcc"),
		"bullet_color": Color("#aaffff"),
		"costs": [180, 250, 400, 0],
		"ranges": [110, 135, 160, 200],
		"fire_rates": [1.20, 1.00, 0.80, 0.40],
		"damage": [15, 30, 50, 180],
		"bullet_speed": 600.0,
		"slow": [0.30, 0.40, 0.50, 0.75],
		"slow_duration": 2.0,
		"texture_prefix": "frost"
	},
	"flame": {
		"name": "炽核熔炎机",
		"names": ["炽核熔炎机 1级", "炽核熔炎机 2级", "【炽核·聚变喷射流】", "曜星·熔炉战神"],
		"color": Color("#ffaa00"),
		"bullet_color": Color("#ff3300"),
		"costs": [220, 320, 480, 0],
		"ranges": [100, 125, 150, 190],
		"fire_rates": [1.00, 0.90, 0.10, 0.50],
		"damage": [20, 40, 12, 250],
		"bullet_speed": 500.0,
		"burn_damage": [5, 10, 20, 80],
		"burn_duration": 3.0,
		"texture_prefix": "flame"
	}
}

const ENEMIES := {
	"scout": {
		"name": "Scout",
		"hp": 150.0,
		"speed": 120.0,
		"reward": 25,
		"radius": 18.0,
		"color": Color("#99ff33"),
		"texture": "res://assets/enemies/enemy_scout.png"
	},
	"predator": {
		"name": "Predator",
		"hp": 450.0,
		"speed": 80.0,
		"reward": 45,
		"radius": 24.0,
		"color": Color("#cc33ff"),
		"texture": "res://assets/enemies/enemy_predator.png"
	},
	"heavy": {
		"name": "Heavy",
		"hp": 1800.0,
		"speed": 45.0,
		"reward": 120,
		"radius": 34.0,
		"color": Color("#ff3333"),
		"texture": "res://assets/enemies/enemy_heavy/boss-16-02idle_sheet.png"
	}
}

const WAVES := [
	{"spawn_delay": 1.0, "count": 10, "type": "scout", "interval": 1.0},
	{"spawn_delay": 2.0, "count": 15, "type": "scout", "interval": 0.8},
	{"spawn_delay": 3.0, "count": 8, "type": "predator", "interval": 1.2},
	{"spawn_delay": 4.0, "count": 12, "type": "predator", "interval": 0.9},
	{"spawn_delay": 5.0, "count": 4, "type": "heavy", "interval": 2.0},
	{"spawn_delay": 6.0, "count": 30, "type": "mixed", "interval": 0.6, "is_boss_wave": true}
]
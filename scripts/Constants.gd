extends Node

# ── Grid Settings ──
const GRID_WIDTH: int = 20
const GRID_HEIGHT: int = 14
const TILE_WIDTH: int = 64   # isometric tile width in pixels
const TILE_HEIGHT: int = 32  # isometric tile height in pixels

# ── Grid origin offset (screen position of tile 0,0) ──
const GRID_ORIGIN := Vector2(640, 80)

# ── Game Balance ──
const STARTING_GOLD: int = 300
const GOLD_PER_SECOND: float = 5.0
const PLAN_PHASE_DURATION: float = 30.0
const EARLY_START_BONUS_PER_SECOND: float = 10.0
const BASE_MAX_HP: int = 20
const REFUND_RATIO: float = 0.5
const FINAL_WAVE: int = 10

# ── Build Items ──
enum BuildItem { NONE, WALL, ROCK, ARCHER_TOWER, GROUND_ARCHER, REMOVE, UPGRADE }

const BUILD_DATA := {
	BuildItem.WALL: {
		"name": "Wall",
		"cost": 10,
		"blocking": true,
		"color": Color(0.55, 0.45, 0.35),
		"description": "Stone wall - blocks enemy paths"
	},
	BuildItem.ROCK: {
		"name": "Rock",
		"cost": 20,
		"blocking": true,
		"color": Color(0.5, 0.5, 0.5),
		"description": "Large boulder - sturdy blockade"
	},
	BuildItem.ARCHER_TOWER: {
		"name": "Archer Tower",
		"cost": 80,
		"blocking": true,
		"color": Color(0.2, 0.5, 0.8),
		"description": "Tower with archer - long range"
	},
	BuildItem.GROUND_ARCHER: {
		"name": "Ground Archer",
		"cost": 40,
		"blocking": false,
		"color": Color(0.2, 0.7, 0.3),
		"description": "Archer on foot - medium range"
	},
}

# ── Tower / Archer Stats ──
const ARCHER_TOWER_STATS := {
	"range": 200.0,
	"fire_rate": 1.0,       # shots per second
	"damage": 15,
	"projectile_speed": 300.0,
}

const GROUND_ARCHER_STATS := {
	"range": 140.0,
	"fire_rate": 1.5,
	"damage": 8,
	"projectile_speed": 250.0,
}

# ── Upgrade System ──
const MAX_UPGRADE_LEVEL := 3
const UPGRADE_COST_RATIO := [0.0, 0.6, 1.0]  # ratio of base cost to upgrade TO level 2, 3
const UPGRADE_DAMAGE_MULT := [1.0, 1.35, 1.8]
const UPGRADE_RANGE_MULT := [1.0, 1.15, 1.3]
const UPGRADE_RATE_MULT := [1.0, 1.15, 1.3]

static func get_upgrade_cost(item_type: int, current_level: int) -> int:
	if current_level >= MAX_UPGRADE_LEVEL:
		return 0
	if not BUILD_DATA.has(item_type):
		return 0
	return int(BUILD_DATA[item_type]["cost"] * UPGRADE_COST_RATIO[current_level])

# ── Hero Stats ──
const HERO_SPEED: float = 150.0
const HERO_ATTACK_DAMAGE: int = 25
const HERO_ATTACK_COOLDOWN: float = 0.4
const HERO_ATTACK_RANGE: float = 40.0

# ── Hero Magic ──
const HERO_MAX_MANA: int = 100
const HERO_MANA_REGEN: float = 5.0  # mana per second

enum Spell { FIREBALL, ICE_BLAST }

const SPELL_DATA := {
	Spell.FIREBALL: {
		"name": "Fireball",
		"cost": 30,
		"damage": 40,
		"aoe_radius": 50.0,
		"cooldown": 2.0,
		"max_range": 300.0,
		"speed": 250.0,
	},
	Spell.ICE_BLAST: {
		"name": "Ice Blast",
		"cost": 25,
		"damage": 15,
		"aoe_radius": 70.0,
		"cooldown": 3.0,
		"slow_factor": 0.4,
		"slow_duration": 3.0,
	},
}

# ── Enemy Types ──
const ENEMY_TYPES := {
	"goblin": {"hp_mult": 1.0, "speed_mult": 1.0, "damage": 1, "gold_mult": 1.0, "sprite": "res://assets/enemy.png"},
	"orc":    {"hp_mult": 2.5, "speed_mult": 0.65, "damage": 2, "gold_mult": 1.5, "sprite": "res://assets/enemy_orc.png"},
	"swift":  {"hp_mult": 0.5, "speed_mult": 1.8, "damage": 1, "gold_mult": 1.2, "sprite": "res://assets/enemy_swift.png"},
	"demon":  {"hp_mult": 5.0, "speed_mult": 0.5, "damage": 3, "gold_mult": 3.0, "sprite": "res://assets/enemy_demon.png"},
}

# ── Enemy Stats (base, scaled per wave) ──
const ENEMY_BASE_HP: int = 40
const ENEMY_BASE_SPEED: float = 60.0
const ENEMY_HP_SCALE_PER_WAVE: float = 0.3   # +30% HP per wave
const ENEMY_SPEED_SCALE_PER_WAVE: float = 0.05
const ENEMY_SPAWN_INTERVAL: float = 0.7

# ── Wave Config ──
const WAVE_CONFIGS := [
	{"count": 10, "types": ["goblin"]},
	{"count": 12, "types": ["goblin", "goblin", "swift"]},
	{"count": 15, "types": ["goblin", "swift", "orc"]},
	{"count": 18, "types": ["goblin", "swift", "orc", "orc"]},
	{"count": 20, "types": ["swift", "orc", "orc"]},
	{"count": 22, "types": ["goblin", "swift", "orc", "demon"]},
	{"count": 25, "types": ["swift", "orc", "demon"]},
	{"count": 28, "types": ["orc", "orc", "demon", "demon"]},
	{"count": 32, "types": ["swift", "swift", "orc", "demon"]},
	{"count": 35, "types": ["orc", "demon", "demon", "demon"]},
]

static func get_wave_config(wave: int) -> Dictionary:
	if wave <= WAVE_CONFIGS.size():
		return WAVE_CONFIGS[wave - 1]
	# Scale infinitely beyond defined waves
	var base_count: int = WAVE_CONFIGS[-1]["count"]
	return {
		"count": base_count + (wave - WAVE_CONFIGS.size()) * 5,
		"types": ["orc", "swift", "demon", "demon"],
	}

# ── Coordinate Conversion ──
static func grid_to_world(gx: int, gy: int) -> Vector2:
	var wx: float = (gx - gy) * (TILE_WIDTH * 0.5)
	var wy: float = (gx + gy) * (TILE_HEIGHT * 0.5)
	return GRID_ORIGIN + Vector2(wx, wy)

static func world_to_grid(world_pos: Vector2) -> Vector2i:
	var rel := world_pos - GRID_ORIGIN
	var gx_f: float = (rel.x / (TILE_WIDTH * 0.5) + rel.y / (TILE_HEIGHT * 0.5)) * 0.5
	var gy_f: float = (rel.y / (TILE_HEIGHT * 0.5) - rel.x / (TILE_WIDTH * 0.5)) * 0.5
	return Vector2i(roundi(gx_f), roundi(gy_f))

static func is_in_grid(gx: int, gy: int) -> bool:
	return gx >= 0 and gx < GRID_WIDTH and gy >= 0 and gy < GRID_HEIGHT

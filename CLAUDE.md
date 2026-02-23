# KOREAN FANTASY TD (kingdomDefense)
AMARIS Development Specification

Engine: Godot 4.6  
Platform: PC  
Renderer: GL Compatibility  
Genre: Kingdom Builder / Tower Defense (Isometric)  
Studio: AMARIS  
Controller Required: Yes (Xbox + Keyboard)  
Viewport: 1280×720 (stretch: canvas_items)

---

# AMARIS Studio Rules (Non-Negotiable)

- `project_status.json` is the single source of truth for dashboard metrics.
- CLAUDE.md defines architecture + structured checkpoints only.
- Do NOT duplicate completion % here.
- Controller-first design is mandatory.
- Major systems must remain testable (headless + runtime).
- Debug flags must default to false in production.
- If an item doesn’t apply, mark **N/A** (never delete).

Launcher / Dashboard Contract:
- `game.config.json` must remain valid.
- `tests/run-tests.bat` (or equivalent) must run with no manual intervention.
- Timestamps must be ISO8601 minute precision.

---

# Godot Execution Contract (MANDATORY)

Godot installed at:

Z:/godot

Claude MUST use:

Z:/godot/godot.exe

Never assume PATH.
Never use Downloads paths.
Never reinstall engine.

Headless boot:
Z:/godot/godot.exe --path . --headless --quit-after 1

Recommended test runs:
- Headless: Z:/godot/godot.exe --path . --headless --script res://tests/test_build.gd
- Runtime tests scene: Z:/godot/godot.exe --path . --headless --scene res://tests/TestRuntime.tscn

If new scripts are added:
- Keep constraints: no class_name declarations (per project rule)
- Keep tuning centralized in Constants.gd

---

# Project Overview

Isometric tower defense with Korean fantasy theming.

Core twist:
- No fixed enemy path.
- Player shapes paths using walls/rocks but can never fully block spawn→goal.

Core Loop:
PLANNING (30s) → WAVE → BREAK → repeat  
Victory after wave 10. Defeat if base HP reaches 0.

Pillars:
1) Path shaping  
2) Active hero combat  
3) Data-driven tuning (Constants.gd)  
4) Self-contained assets (procedural audio + Python-generated sprites)

---

# Architecture Summary

Autoloads:
- Constants — res://scripts/Constants.gd (all tuning + helper funcs + enums)
- AudioManager — res://scripts/AudioManager.gd (procedural audio, no external files)

Core Managers:
- GameManager.gd — phase state machine
- GridManager.gd — iso grid + AStar2D + occupancy
- BuildManager.gd — place/remove/upgrade + path-block validation
- EnemyManager.gd — spawning + tracking
- UIManager.gd — HUD + panels (CanvasLayer)

Entities:
- Hero.gd — WASD + sword + spells (Fireball, Ice Blast)
- Enemy.gd — 4 types (Goblin/Orc/Swift/Demon)
- ArcherTower.gd — tower (3 levels)
- GroundArcher.gd — unit (3 levels)
- Projectile.gd — arrows
- Fireball.gd — AoE projectile

Scenes:
- Main.tscn (root)
- Enemy.tscn
- Projectile.tscn
- ArcherTower.tscn
- GroundArcher.tscn
- Fireball.tscn

Key Constraints:
- All tuning lives in Constants.gd
- No class_name declarations
- Drawing via _draw() + queue_redraw()
- 1280×720 base, canvas_items stretch

---

# Structured Development Checklist
AMARIS STANDARD — 90 Checkpoints

## Macro Phase 1 — Foundation & Compliance (1–12)

- [x] 1. Repo standardized
- [x] 2. Main scene boots clean
- [x] 3. GL Compatibility configured
- [x] 4. Viewport 1280×720 enforced
- [x] 5. Constants autoload exists
- [x] 6. AudioManager autoload exists
- [x] 7. Controller support validated
- [x] 8. Keyboard controls validated
- [x] 9. Version/build visible in UI
- [x] 10. Logging/diagnostics pattern standardized
- [ ] 11. project_status.json update discipline enforced
- [ ] 12. Launcher compliance check script (optional)

---

## Macro Phase 2 — Core Loop State Machine (13–22)

- [x] 13. PLANNING phase countdown
- [x] 14. WAVE phase spawn flow
- [x] 15. BREAK phase summary flow
- [x] 16. GAME_OVER condition
- [x] 17. VICTORY condition (wave 10)
- [x] 18. Gold income / economy loop
- [x] 19. Wave timer & pacing stable
- [ ] 20. Difficulty curve audit (waves 1–10)
- [ ] 21. Endless scaling rules documented
- [ ] 22. Phase transition VFX polish (future)

---

## Macro Phase 3 — Grid & Pathfinding (23–34)

- [x] 23. Isometric grid conversion
- [x] 24. Occupancy tracking
- [x] 25. AStar2D path rebuild on changes
- [x] 26. Multi-spawn points configured
- [x] 27. Goal location configured
- [x] 28. Path-blocking validation prevents full block
- [x] 29. would_block_all_paths guard tested
- [ ] 30. Path visualization debug overlay
- [ ] 31. Path smoothing (optional)
- [ ] 32. Edge-case: spawn congestion handling
- [ ] 33. Edge-case: rebuild performance audit
- [ ] 34. Multiple map layouts support (Phase 3+)

---

## Macro Phase 4 — Build / Upgrade / Economy (35–46)

- [x] 35. Place Wall
- [x] 36. Place Rock
- [x] 37. Place Archer Tower
- [x] 38. Place Ground Archer
- [x] 39. Upgrade system (3 levels)
- [x] 40. Upgrade costs (0.6 / 1.0)
- [x] 41. Removal refund (50%)
- [x] 42. Placement validation
- [ ] 43. Build UX polish (snapping, ghost preview)
- [ ] 44. Upgrade feedback polish (sparkles, sound, text)
- [ ] 45. Economy balance audit (gold rates vs costs)
- [ ] 46. Additional build items pipeline (Phase 2)

---

## Macro Phase 5 — Combat Systems (Hero + Towers) (47–60)

- [x] 47. Hero movement stable
- [x] 48. Sword attack + cooldown
- [x] 49. Fireball spell
- [x] 50. Ice blast spell + slow
- [x] 51. Mana regen system
- [x] 52. Tower auto-targeting
- [x] 53. Projectile logic stable
- [x] 54. AoE damage stable
- [ ] 55. Spell/tower VFX pass (Phase 2)
- [ ] 56. Hero survivability tuning
- [ ] 57. Hero progression system (Phase 2)
- [ ] 58. Tower variety expansion (magic/splash/etc.)
- [ ] 59. Status effect framework (future)
- [ ] 60. Combat telemetry counters (kills, dmg, etc.)

---

## Macro Phase 6 — Enemies & Waves (61–72)

- [x] 61. Goblin implemented
- [x] 62. Orc implemented
- [x] 63. Swift implemented
- [x] 64. Demon implemented
- [x] 65. Wave scaling (+30% HP, +5% speed)
- [x] 66. 10 configured waves
- [x] 67. Endless scaling beyond wave 10
- [ ] 68. Wave variety pass (compositions)
- [ ] 69. New enemy types (Phase 2)
- [ ] 70. Boss mechanics (Phase 3)
- [ ] 71. Elite enemies / modifiers (future)
- [ ] 72. Spawn pacing / clumping polish

---

## Macro Phase 7 — UI/UX & Menus (73–80)

- [x] 73. HUD exists
- [x] 74. Build panel exists
- [x] 75. Phase panels exist
- [x] 76. Controller UI flows usable
- [ ] 77. Main menu screen
- [ ] 78. Settings screen
- [ ] 79. Gamepad-first menu navigation polish
- [ ] 80. Accessibility / readability pass

---

## Macro Phase 8 — Audio / VFX / Art (81–86)

- [x] 81. Procedural audio system complete
- [ ] 82. Music / ambience system (Phase 2)
- [ ] 83. Particle effects pass
- [ ] 84. Real art swap (optional)
- [ ] 85. Screenshake / juice pass
- [ ] 86. Visual readability audit (busy scenes)

---

## Macro Phase 9 — Achievements & Studio Tracking (87–90)

Current status:
- Achievements system is missing (per project_status.json)

- [ ] 87. Add achievements.json (append-only rules)
- [ ] 88. Add AchievementManager / hooks
- [ ] 89. Achievement toast + queue
- [ ] 90. Status.html displays achievements (if used)

---

# Debug Flags (Required)

Must exist (or be added) and default false:

- DEBUG_PHASES
- DEBUG_PATH
- DEBUG_BUILD
- DEBUG_COMBAT
- DEBUG_SPAWNS
- DEBUG_UI
- DEBUG_AUDIO

---

# Test Contract

Test command (launcher):
tests/run-tests.bat

Primary tests:
- tests/test_build.gd (headless validation)
- tests/test_runtime.gd + TestRuntime.tscn (runtime checks)

After gameplay changes:
- Update tests alongside balance logic changes (Constants.gd).
- Ensure tests remain deterministic.

---

# Automation Contract

After major updates:

1) Update project_status.json:
- macroPhase
- subphaseIndex
- completionPercent
- timestamps
- testStatus

2) Run tests:
- Z:/godot/godot.exe --path . --headless --script res://tests/test_build.gd
- Z:/godot/godot.exe --path . --headless --scene res://tests/TestRuntime.tscn

3) Commit
4) Push

AMARIS dashboard depends on this contract.

---

# Current Focus

Current Goal: Phase 1 cleanup — close foundation debt
Current Task: Debug flags, version UI, logging, compliance
Work Mode: Infrastructure
Next Milestone: Phase 1 complete (items 11–12)

---

# Known Gaps (from roadmap + status)

- Achievements system missing
- Save/load missing
- Settings menu missing
- Music/ambient missing
- More towers/enemies needed for content variety
- VFX/juice pass missing

---

# Long-Term Vision

Korean Fantasy TD should evolve into:

- Multiple maps + terrain features
- Boss waves + unique mechanics
- Hero progression + build synergies
- Challenge modes (endless, speed run)
- Achievements + meta progression
- Full studio-grade launcher tracking

---

END OF FILE
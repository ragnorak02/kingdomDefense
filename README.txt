KOREAN FANTASY ISOMETRIC TOWER DEFENSE - Prototype
===================================================

HOW TO RUN
----------
1. Open Godot 4.4 (or latest 4.x stable)
2. Import this project folder
3. Press F5 or click Play

CONTROLS - Keyboard + Mouse
----------------------------
  WASD        - Move hero
  Space       - Hero sword attack
  Tab         - Toggle build menu
  Left Click  - Place selected structure on highlighted tile
  Right Click - Cancel current selection
  Enter       - Start wave early (bonus gold for remaining time!)
  Escape      - Pause (reserved)

CONTROLS - Xbox / Controller
-----------------------------
  Left Stick  - Move hero
  Right Stick - Move build cursor
  A           - Place / Confirm
  B           - Cancel
  X           - Hero attack
  Y           - Toggle build menu
  Start       - Start wave early

GAMEPLAY
--------
1. PLAN PHASE: You have 30 seconds to place walls, rocks, towers,
   and archers. Gold trickles in over time. Press Enter to start
   the wave early for bonus gold!

2. WAVE PHASE: Enemies spawn from red tiles on the left and
   pathfind toward the yellow goal tile on the right. Your towers
   and archers shoot automatically. Move your hero with WASD and
   attack with Space to help defend!

3. BREAK: After clearing a wave, you get bonus gold and can
   continue to the next planning phase.

4. GAME OVER: If enemies reach the goal, your base loses HP.
   At 0 HP, the game is over.

KEY TWIST: There is no pre-built path! You shape the enemy path
by placing walls and rocks. But you cannot fully block all paths
from spawn to goal.

TWEAKING CONSTANTS
------------------
All balance values are in: scripts/Constants.gd

  Grid:      GRID_WIDTH, GRID_HEIGHT, TILE_WIDTH, TILE_HEIGHT
  Economy:   STARTING_GOLD, GOLD_PER_SECOND, BUILD_DATA costs
  Timing:    PLAN_PHASE_DURATION, ENEMY_SPAWN_INTERVAL
  Combat:    HERO_*, ARCHER_TOWER_STATS, GROUND_ARCHER_STATS
  Enemies:   ENEMY_BASE_HP, ENEMY_BASE_SPEED, scaling per wave
  Waves:     WAVE_CONFIGS array (add more entries for more waves)
  Map:       Spawn/goal points in GridManager._ready()

FILE STRUCTURE
--------------
  project.godot           - Godot project config + input mappings
  scenes/Main.tscn        - Main game scene (all managers + UI)
  scenes/Enemy.tscn       - Enemy instance scene
  scenes/Projectile.tscn  - Arrow/projectile scene
  scenes/ArcherTower.tscn - Tower defense unit
  scenes/GroundArcher.tscn- Ground archer unit
  scripts/Constants.gd    - All game constants (autoloaded)
  scripts/GameManager.gd  - Phase state machine
  scripts/GridManager.gd  - Isometric grid, pathfinding, occupancy
  scripts/BuildManager.gd - Build placement + validation
  scripts/EnemyManager.gd - Wave spawning + enemy tracking
  scripts/UIManager.gd    - All UI/HUD management
  scripts/Hero.gd         - Player hero movement + attack
  scripts/Enemy.gd        - Enemy pathfinding + HP
  scripts/Projectile.gd   - Arrow projectile behavior
  scripts/ArcherTower.gd  - Tower targeting + shooting
  scripts/GroundArcher.gd - Ground archer targeting + shooting

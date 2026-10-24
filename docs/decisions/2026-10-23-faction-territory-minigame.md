# Faction Territory minigame — decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | Throwaway slice: one map, one fixed enemy AI, no saving | Jam, rules not yet proven | a second map or difficulty is wanted |
| Dimension / language / authority | 3D, GDScript, single-player | Existing project | — |
| Camera | Fixed, almost top-down | User choice | — |
| Integration | Lobby portal and `ProgressionService` (world `faction_territory`) | User choice | the minigame is kept |
| Map | 5 sites on a line, no neutral site | User choice | the map becomes a graph |
| Start | Player owns 1 site, enemy owns 4 | Comeback arc | balance tuning |
| Player input | UI buttons, one per unit type (2–3 types) | User choice | — |
| Spawn point | Player: the rearmost (first) site he owns. Enemy: the most-forward site it owns (`UnitSpawner.spawn_at_rearmost_site` is set on the player spawner only) | User choice | — |
| Targeting | None: units march along the line toward the enemy | Spawn rule above, no target picking | a branching map |
| Roster | 3 unit types, using `assets/characters/Rogue_Hooded.glb`, `Ranger.glb` and `Mage.glb` | Models provided by the user | more models are added |
| Unit cost | Cooldown only, no currency. Cheap = short cooldown but weak, expensive = long cooldown but strong | User choice | — |
| Cooldown model | One cooldown per button | Real choice between types | — |
| After a flip | Units keep marching, they do not stay as defenders. Exception: every player unit waits once at each site it reaches, owned or not, for the site's `capture_wait_time` (set per site, default 3s) to slow the game down. It still fights while waiting. Enemy units never wait (reverses the first version: only the capturing unit waited, on both sides) | User choice | the game feels too slow |
| Capture | Killing the defenders flips the site at once | User choice | — |
| Defenses | Only units fight, no turrets | Smallest version | towers are wanted |
| Losing all sites | The player can still spawn units | Never stuck at 0 | — |
| Enemy AI | Fixed timer pattern, random unit type each time, same roster and cooldowns | Predictable, easy to tune | the AI should react to the board |
| Candies | Score only, never spent | User choice | candies get a use |
| Payout | Every 20s, 5 candies per owned site (the starting site counts), shown as a "+N" popup on the HUD | User choice | tuning |
| Win/lose | None: the goal is to maximize candies | User choice | — |

## Open / deferred
- Duration — **assumed** 3 minutes (9 payouts), kept in one place.
- End of the timer — **assumed** a result overlay with the candy total and "Continue" to `scenes/levels/main.tscn` through `SceneTransition`.
- Spawn when a side owns no site — **assumed** a permanent home spawn behind its end of the line, not capturable.
- "Defenders" — **assumed** the enemy units standing in or fighting at the site. A marching unit that reaches a site with no enemy unit present flips it.
- Site wait — **assumed** player-only, since the request says "the player's mob". The property is still named `capture_wait_time` to keep the values already set per site in `FactionTerritory.tscn`.
- Enemy candies — **assumed** none, the AI earns no score.
- Role per model — **assumed** Rogue = cheap/weak, Ranger = medium, Mage = expensive/strong.
- Enemy look — **assumed** the same three models, tinted to tell the factions apart.
- Unit stats and cooldown values — first guesses (see `units/*.tres`), to be tuned in play. Enemy spawn interval is 4s (`EnemyAI.spawn_interval`).
- Units are `Node3D` with distance checks on the x axis, not physics bodies — units only move along one line.
- Attack animation — none: the Knight clips only have idle and run, so a hit is a small scale punch.
- Lobby: a `FactionTerritoryPortal` (`LevelPortal`) sits at the church door in `main.tscn`. "Continue" sets the `faction_territory_return_to_door` meta so the player reappears at the portal. When the round timer ends, `ProgressionService.complete_world(&"faction_territory", candies)` flags the world as finished and adds the candies to the total (once, like the other minigames). The portal has `world_id = &"faction_territory"`, so it then shows "MONDE TERMINÉ".
- Texts hardcoded in English, not yet in the localization files.

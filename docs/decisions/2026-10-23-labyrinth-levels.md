# Labyrinth levels — decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | One reusable level scene, several hand-built easy labyrinths, each with its own candy count | User wants multiple levels; the rules are generic | a level editor or random generation is wanted |
| Dimension / language / authority | 3D, GDScript, single-player | Existing project | — |
| Labyrinth source | Hand-built in the editor | Full control of pacing and candy placement | levels become too many to build by hand |
| Candy count | Counted from the `candy` group when the level loads | No per-level number to keep in sync with the layout | candies need weights or types |
| Collecting | Walking into the candy (`Area3D`) | Keeps the pace up in a maze | a collect button is wanted |
| Exit | One door, same place as the start, behind the player at spawn. It opens when the player presses a button while in front of it with all candies | Single door, like a house | — |
| Door prompt | A "Press <button>" prompt is shown only when the player is in front of the door | The player knows when the door can be used | — |
| Locked door | Pressing the button without all the candies shows an "x candies missing" message | The player sees that the door works | — |
| Timer scope | **One run-wide timer** for the whole sequence of labyrinths (reverses the one-timer-per-labyrinth decision) | User wants a limit to finish several labyrinths, not each one | levels need their own limit again |
| Timer duration | 10 minutes for the whole run, kept in one place | User choice | more levels are added and the pace is tuned |
| Timer behavior | Starts on the player's first move. Pauses on the win overlay. Resumes on the first move in the next labyrinth | The player is not punished for reading the overlay | levels need a different start rule |
| Timer display | HUD shows the remaining time as numbers, like "2:35" | User choice | the clock feels too stressful for children |
| Timer home | A new autoload (`LabyrinthService`) | The clock and the totals must survive scene changes | the run needs saving |
| Time-out | `LabyrinthService` emits `time_up`. The labyrinth pauses the game and shows the result overlay with "Time's up!" and "Continue". "Continue" resets the run and goes to `scenes/levels/main.tscn` through `SceneTransition` (reverses the "no overlay" choice) | User wants the same kind of overlay as a win | a retry is wanted |
| Run reset | Pressing "Start" in the main menu starts a new run: full time, bonus candies back to 0 | Each run begins fresh | the run should be resumable |
| Extra candies | Each labyrinth has `@export extra_candies`. Winning it adds them to a run total kept in `LabyrinthService` | User wants a reward at the end of a labyrinth, set per level | candies get a use, or the total must be saved |
| Extra candies display | The win overlay shows "+N candies!". The HUD shows the run total | User choice | — |
| Threats | The run timer is the only danger, no enemies or traps | Levels are easy, the knight has no combat | a threat is added |
| End of round | A win shows an overlay with "Continue" to the next level. A time-out shows the same overlay ("Time's up!") with "Continue" back to the lobby. No Retry and no Main menu button | Keeps the end of a round consistent | a pause menu or a retry is added |
| Level flow | Fixed order through `@export var next_level: PackedScene` on each level (empty = last). No level select, no saving (`ProgressionService` is not touched) | Keeps it simple for a jam, no global list to maintain | players should resume from a later level |
| Last level | Winning it stops the clock, then "Continue" goes back to `scenes/levels/main.tscn` through `SceneTransition` (replaces the logged message) | The player returns to the lobby, more levels will be chained later with `next_level` | an ending flow (credits) is designed |
| Progression | Winning the last labyrinth calls `ProgressionService.complete_world(&"labyrinth", collected_candies + bonus_candies)` (both from `LabyrinthService`): the world is flagged finished (the lobby portal then shows "MONDE TERMINÉ") and the candies collected in all the labyrinths of the run, plus the extra candies, go to `total_candy`. A time-out resets `LabyrinthService`, so nothing is saved | Same rule as the Candy Bucket minigame | each labyrinth should be saved on its own |
| Camera | Existing third-person camera (`objects/third_person_camera.gd`) | Already working | the camera clips in tight corridors |

## Building rules
- Corridors must be wide enough to keep the third-person camera from clipping into walls.
- The player spawns facing away from the door.

## Open / deferred
- Win overlay for a level other than the last: only "Continue" — **assumed**.
- Pause while the overlay is shown — **assumed** the game tree is paused (`UiAudio` set to always process so button sounds still play).
- The HUD total counts only extra candies won, not the candies collected in the level — **assumed**. The per-level "Candies: x / y" counter stays.
- Door button — reuses the existing `action_activate` input (E).
- HUD and overlay texts are hardcoded English, not yet in the localization files.
- The main menu "Start" loads `Level01.tscn` instead of `main.tscn`.
- The first version of the game had one timer per labyrinth. It was built, then reversed here, and has to be removed from `Labyrinth.gd`, the HUD and the result overlay.

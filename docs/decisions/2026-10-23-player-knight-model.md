# Player Knight model — decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | One-shot swap: `Knight.glb` hardcoded in the player | Jam pace; Mage/Ranger/Rogue stay unused assets | a character-select screen is wanted |
| Animations covered | Idle, run, jump (static and forward) | User scope; no walk tier since `SPEED` is a single constant | variable move speed is added |
| Animation source | Mixamo FBX clips in `assets/animations/` (`Breathing Idle`, `Running`, `JumpingStatic`, `JumpingForward`) | `Knight.glb` ships no clips | clips are replaced or extended |
| Rig mismatch | Godot import retargeting: `BoneMap` (humanoid profile) on `Knight.glb` and on each FBX, clips extracted to `assets/animations/clips/*.res` | Keeps the original Knight GLB; no re-export from Mixamo | the Knight rig changes or more characters share the clips |
| Facing | Model rotates toward movement direction, smoothed with `lerp_angle` (`TURN_SPEED`) | Humanoid run cycle makes camera-locked facing look like moonwalking when strafing | a lock-on / strafe combat mode is added |
| Jump shape | **One clip per jump, no landing phase** (reverses the earlier three-phase decision): `jump_forward` when moving at takeoff, `jump_static` otherwise, held until landing | Only two jump clips exist, each already contains takeoff and landing | separate takeoff / air / land clips are added |
| Weapons | **None** (reverses "visible"): the GLB has no sword or shield | Asset has no weapon meshes; user chose to skip | a weapon asset is added (use the `handslot.l` / `handslot.r` bones) |
| Model scene | `objects/knight.tscn`: scene inherited from `Knight.glb` + `AnimationPlayer`, instanced in `player.tscn` as `%Player` | Retargeted track paths use `%GeneralSkeleton`, which must resolve inside the same scene | the model becomes swappable |
| Animation logic home | `Knight.animate(on_floor, horizontal_speed)` in `objects/knight.gd`, called by `player.gd` | Single Responsibility; `player.gd` stays movement-only | an `AnimationTree` is needed for blending or layering |
| Collider | Unchanged `CapsuleShape3D` (radius 0.5, height 2); model offset to `y = -1` so feet touch the capsule bottom | Fits the Knight's torso width and height | the Knight's silhouette stops matching a capsule |

## Open / deferred
- The Knight has no neck, shoulder or upper-chest bones; the matching Mixamo rotations are dropped by the retarget.
- Landing detection relies on an `is_on_floor()` rising edge; no coyote time or landing-impact tuning this pass.
- Jump clips are not time-fitted to the physics air time (about 0.9 s). `JumpingStatic` lasts 2.4 s, so its end is cut off. A clip that ends mid-fall holds its last frame.
- Walking off a ledge plays `jump_static` (no separate fall clip).
- Pre-existing oddity in `player.gd`: `transform.basis * camera.basis` double-applies rotation for direction. Out of scope, not fixed.
- `player.gd` lives in `objects/` while `ARCHITECTURE.md` reserves `actors/` for characters. Not touched.

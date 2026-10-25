# Touch controls (tablet browser) — decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Target | Web export played in a tablet browser, landscape | Web is the only export besides Windows | a native Android/iOS export is wanted |
| Where | `components/touch_controls/TouchControls.tscn`, instanced once in each scene with player movement (lobby, Labyrinth, Chaseween, SecretGallery, CandyBucket) | Reusable component, no change in `player.gd` or `CandyBucketPlayer.gd` | a scene is added |
| Visibility | Shown only if `DisplayServer.is_touchscreen_available()`, else the node frees itself. `force_visible` for tests | Desktop players see nothing new | touch laptops are a problem (they will show the controls) |
| How inputs are sent | `Input.parse_input_event(InputEventAction)` on the existing actions (`move_*`, `move_jump`, `action_activate`) | Existing code reads those actions; `parse_input_event` also reaches `_unhandled_input` handlers, `Input.action_press` does not | |
| Multi-touch | Each control tracks its own finger index in `_input` and marks its events handled | Godot emulates **one** mouse from touches, so `Button` cannot be used (no jump while moving) | |
| Joystick | Floating, left half of the screen; a faint ring shows where to start | User choice | players miss the ring |
| Camera | `CameraPivot` also handles `InputEventScreenDrag` (`touch_sensitivity`) from any finger not used by a control; it ignores emulated mouse motion | The joystick finger would otherwise rotate the camera | |
| Attack (Chaseween) | Dedicated "A" button, not a tap on the screen | Attacks hit a cone in front of the player (no aiming); a tap would conflict with camera drag | an aimed tool is added |
| New actions | `action_attack` (left click), `action_switch_tool` (Q), `action_journal` (J) | Chaseween read raw mouse/key events, so buttons could not trigger them | |
| Emulated click | In Chaseween the attack ignores mouse events with `device == InputEvent.DEVICE_ID_EMULATION` | Any touch emulates a left click: every camera drag would attack | |
| Pause | Controls hide while the tree is paused and release every held action when hidden or removed | Labyrinth pauses the tree on its result overlay; a held finger must not leave an action stuck | |
| Labels | "E", "Q", "J", "A" and a drawn chevron for jump; not translated | The default Godot font has no arrow glyphs and translations come from the `.xlsx` | icons are drawn |

## Open / deferred
- The Chaseween prompt still says "E" and the journal text "J : close"; they are not adapted to touch.
- The interact button is always visible, not only near an interactable.
- No pause / exit button: `exit` is still Esc only.
- Not tested on a real tablet; positions assume the 1920x1080 viewport.
- Web export must allow landscape and fullscreen (browser side).

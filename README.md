# Little Clean Crew

**Made with Codex, use at your own risk**

A first playable, child-friendly garbage-truck route built with Godot and Blender.

## Build stages

1. **Project foundation and static neighborhood blockout** — complete
2. **Arcade driving and follow camera** — complete
3. **Can detection and animated side-loader pickup** — complete
4. **Loose trash, sound, feedback, and toddler-friendly polish** — complete

Play the project:

```sh
just run
```

Use `just editor` to open the project in the Godot editor instead. Run
`just --list` to see all available commands.

Driving controls:

- `W` / `Up Arrow` — drive forward
- `S` / `Down Arrow` — reverse
- `A D` / `Left Right` — steer
- `Space` — stop
- Gamepad left stick — drive and steer
- Gamepad A / B / X — forward, reverse, and stop
- `E`, `Enter`, or gamepad Y — start pickup immediately when aligned
- `F` or gamepad right shoulder — dump the hopper while stopped
- `R` or gamepad Start — restart the route

Pickup begins automatically after the truck is stopped beside a glowing can.
The arm grabs, lifts, tips, empties, and returns the can without requiring any
precision controls. Empty cans stay at the curb rather than disappearing. Each
pickup sends ten pieces through the open hopper and settles them on its recessed
floor, below the roof rim. The same pieces stay inside while driving; the hopper
holds all sixty pieces from a complete route. Stop and press the dump control to
open the rear tailgate and spill the accumulated load.

Automated checks:

```sh
just test
```

Run an individual check with `just test-driving`, `just test-pickup`,
`just test-route`, or `just test-dump`. Use `just build` to import and validate
the Godot resources, or `just check` to build and then run all four checks.

## Generate the first model set

The Blender source, Godot-ready GLB, and preview renders are generated from one
Python script:

```sh
just models
```

Generated files:

- `source_assets/little_clean_crew.blend` — editable Blender source, ignored by Godot
- `assets/models/little_clean_crew.glb` — game-ready scene export
- `renders/side_loader_front.png` — front three-quarter preview
- `renders/side_loader_side.png` — loader-side preview
- `renders/side_loader_rear.png` — rear three-quarter preview

The truck's side loader is built as a hierarchy of named pivot empties so the
pickup sequence can be authored and tuned in the game engine. The trash can has
a separate root and lid pivot for the same reason.

Run `just assets` to regenerate the Blender assets and original sound effects,
then import the results into Godot.

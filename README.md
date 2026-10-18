# Little Clean Crew

**Made with Codex, use at your own risk**

A child-friendly garbage-truck game built with Godot and Blender.

## License

Copyright (c) 2026 Little Clean Crew contributors.

Little Clean Crew's source code, documentation, and original assets are licensed
under the GNU Affero General Public License, version 3 or (at your option) any
later version (`AGPL-3.0-or-later`). See [LICENSE.txt](LICENSE.txt) for the full
license text. The project is provided without warranty.

This game uses Godot Engine, which is licensed separately under the MIT license.
See [Godot's license and third-party notices](https://godotengine.org/license/).
When distributing an exported game, include `LICENSE.txt`, this license notice,
and the corresponding project source, along with the applicable Godot and
third-party notices described in
[Godot's license compliance guide](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html).

## Game

The opening screen lets players choose between two routes using the mouse,
keyboard arrows and Enter, or gamepad D-pad and A:

- **Side loader — Neighborhood:** collect six blue residential cans with the side arm.
- **Front loader — Market Lane:** collect three green dumpsters outside the shops.
  Drive straight toward a dumpster and stop with it between the front forks.
  The forks align, lift the dumpster over the cab, tip it into the hopper, and
  return it to its parking pad.

## Build stages

1. **Project foundation and static neighborhood blockout** — complete
2. **Arcade driving and follow camera** — complete
3. **Can detection and animated side-loader pickup** — complete
4. **Loose trash, sound, feedback, and toddler-friendly polish** — complete
5. **Level selection and front-loader dumpster route** — complete

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
- `R` or gamepad Start — restart the current route
- `Esc`, gamepad Back / Select, or the **Choose level** button — return to level selection

Both trucks can drive forward or reverse off either end of the road and fall
into the surrounding blue. The camera stays at road level. Once the whole truck
falls out of view, it returns to its starting position, stopped and facing down
the road. Collected trash and route progress are preserved.

Pickup begins automatically after the truck is stopped beside a glowing can
or aligned in front of a dumpster.
The arm grabs, lifts, tips, empties, and returns the can without requiring any
precision controls. Empty cans stay at the curb rather than disappearing. Each
pickup sends ten pieces through the open hopper and settles them on its recessed
floor, below the roof rim. The same pieces stay inside while driving; the hopper
holds all sixty pieces from the neighborhood or thirty from Market Lane. Stop and press the dump control to
open the rear tailgate and spill the accumulated load.

Automated checks:

```sh
just test
```

Run an individual check with `just test-driving`, `just test-pickup`,
`just test-road-exit`, `just test-route`, `just test-dump`, `just test-front-route`, or `just test-menu`.
Use `just build` to import and validate
the Godot resources, or `just check` to build and then run all seven checks.

Use `just capture-menu` and `just capture-front` to save previews of the level
chooser and overhead dumpster pickup. The front forks, dumpsters, and market
scenery are built in Godot; regenerating the Blender model is not required.

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

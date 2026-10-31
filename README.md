# Apex Grand Prix

An independent, private-development open-wheel racing simulator prototype. The goal is a deep, authentic Grand Prix experience with scalable visuals and a serious driving model.

## Current playable foundation
- F1-inspired front-end with home, race-weekend, garage and settings navigation.\n- 2026 grid selection in the garage: all 11 teams, their 2026 chassis labels, power-unit suppliers and 22 race drivers. Selected team/driver is reflected in the garage and race HUD.
- Dark neutral motorsport UI with restrained red accents, layered panels and dedicated garage configuration screen.
- Godot 4 project using the Compatibility renderer.
- Procedural closed test circuit with asphalt, collision, barriers, start/finish line, grid boxes and alternating red/white kerbs.
- Vehicle controller with speed-sensitive steering, automatic 8-speed gearbox, aerodynamic drag/downforce grip, DRS, ERS deployment/recharge, tyre temperature and tyre wear.
- Five-red-light start sequence and race HUD with speed, lap-session clock and vehicle telemetry.

This is still an early prototype. It does not yet contain production-quality F1 car models, real-world circuit recreations, race AI, pit stops, full damage simulation, career mode, licensed audio, or a Windows release.

## Requirements
- Godot 4.3 or newer (Godot 4.x recommended).
- Keyboard controls:
  - W / Up: throttle
  - S / Down: brake / reverse
  - A / D or Left / Right: steering
  - E: deploy ERS
  - F: DRS (prototype toggle; no detection-zone rules yet)
  - Space: handbrake
  - R: reset car

## Run
1. Install Godot 4.
2. Clone or download this repository.
3. Open the repository folder in Godot.
4. Run `scenes/main.tscn` (F6) or the project (F5).

## Performance direction
The project starts on Godot's Compatibility renderer to support a wider range of integrated GPUs. The goal is to optimise the game without imposing an integrated-graphics-only visual ceiling. The settings page now offers Low, Medium, High and Ultra graphics presets, 3D render scale, fullscreen mode and VSync. These controls are implemented but have not yet been validated in-engine.

The garage currently provides the interface shell and selectable configuration categories. The detailed 3D car presentation and functional aerodynamic/tyre setup controls are still in development; the UI does not pretend those systems are finished.

## Structure
- `project.godot` — engine and renderer configuration
- `scenes/main.tscn` — game entry scene
- `scripts/main.gd` — environment, camera, HUD and start sequence
- `scripts/f1_car.gd` — vehicle dynamics and energy/tyre systems
- `scripts/oval_circuit.gd` — procedural test circuit

## Project status
See [ROADMAP.md](docs/ROADMAP.md) for planned systems and current priorities.

## Legal
Independent fan-made prototype; not affiliated with Formula One, the FIA, or any racing team. Trademarks, likenesses, circuit designs, and proprietary assets require appropriate authorization. Use original or properly licensed models, textures, sounds, and data.


## Latest prototype pass
The current prototype now includes a procedural asphalt shader with fine surface variation, painted edge lines, filmic tonemapping, restrained glow, improved directional shadow coverage, a corrected grid/start-line layout, a locked five-light grid countdown, and a first start/finish crossing gate with lap and best-lap display. These systems are early implementations and still require in-engine validation.

The project does **not** yet contain a finished high-detail open-wheel vehicle, real-world circuit recreations, AI field, pit stops, wet-weather simulation, damage, or a complete race-weekend flow. Those remain active development targets; no claim of AAA graphics or a verified 4 GB performance result is being made.
\n\nThe 2026 team and driver roster follows Formula 1's published 2026 grid. Team names, driver names and numbers are factual references; this independent project is not affiliated with Formula 1 or the teams. The current car selection is roster/chassis metadata only—the game still needs original, high-detail 3D car models and team liveries.\n

## Graphics options
The Settings page includes four quality presets, adjustable 3D render scale (50%, 75%, 100%, 125%), fullscreen and VSync. Options are applied immediately and persisted locally. Further controls for textures, anti-aliasing, reflections and effects can be added as the rendering pipeline grows.


## Storage and startup targets
The complete installed game must stay **under 10 GB**. This is a storage ceiling, not a graphics-quality target: do not strip detailed cars, circuit environments, textures or effects just to make the game smaller. Prefer efficient asset formats, sensible texture compression, shared materials, removal of duplicate/unused files and optional downloads for genuinely large extras. Track the installed footprint as content is added.

The game should also reach the main menu quickly without sacrificing visual quality. Keep startup work lean: load only menu-critical resources first, move nonessential work off the critical startup path, avoid blocking network checks or content downloads, and stream heavier track/race assets when needed. Profile cold and warm startup times and optimise measured bottlenecks rather than lowering graphics settings by default.

## Collision and crash prototype
The test track now has dedicated overlapping road collision strips beneath the rendered asphalt, plus solid barrier colliders. Significant impacts reduce speed, can deflect the car, accumulate crash damage and trigger a DNF when damage reaches the critical threshold. This is an early gameplay prototype; the car still uses a simple box collision body, and detailed deformable bodywork, wheel detachment, suspension damage, debris, recovery and full car-to-car testing are not complete.


## Gravel runoff and tyre pickup
The prototype circuit includes gravel runoff bands. Driving through gravel at speed progressively adds a gravel-coloured layer to the four visible prototype tyre meshes; driving back on asphalt gradually clears it. The HUD shows a gravel contamination percentage. This is an early visual/gameplay effect, not yet per-wheel physical stone simulation, and it has not yet been validated in Godot.

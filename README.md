# Apex Grand Prix

An independent, private-development open-wheel racing simulator prototype. The goal is a deep, authentic Grand Prix experience with scalable visuals and a serious driving model.

## Current playable foundation
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
The project starts on Godot's Compatibility renderer to support a wider range of integrated GPUs. Future quality settings should scale shadows, reflections, crowd density, trackside detail and render resolution independently. The 4 GB RAM / integrated graphics target remains a performance goal, not a verified benchmark yet.

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

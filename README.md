# Apex Grand Prix

A private-development racing simulator targeting a high-fidelity Formula racing experience.

## Current foundation
- Godot 4 project using the Compatibility renderer for a broad range of integrated GPUs.
- Custom vehicle dynamics prototype with throttle, brake, steering, drag, grip and speed-sensitive steering.
- Procedural test circuit with a closed road surface, track edge barriers and start/finish markings.
- Race-start sequence with five red lights, lights out, a basic race clock and a compact HUD.

This is an early playable foundation, not a finished F1 recreation. High-quality licensed/commissioned car and circuit assets, detailed environments, audio, AI, pit systems and full race-weekend features are still required.

## Requirements
- Godot 4.3 or newer (4.x recommended).
- Keyboard: W/Up throttle, S/Down brake, A/D or Left/Right steering, Space handbrake, R reset.

## Run
1. Open this folder in Godot 4.
2. Open `scenes/main.tscn`.
3. Press F6/F5 to run.

## Performance direction
The initial project uses Godot's Compatibility renderer. Visual quality settings will be scalable; the project should not assume a dedicated GPU or large memory budget.

## Project structure
- `scenes/main.tscn` — entry scene
- `scripts/main.gd` — world, camera and race HUD orchestration
- `scripts/f1_car.gd` — first-pass vehicle controller
- `scripts/oval_circuit.gd` — procedural test circuit

## Important
This project is an independent fan-made simulator prototype. It is not affiliated with Formula One, the FIA, or any racing team. Names, logos, likenesses, and proprietary game assets must only be added where their use is authorized.

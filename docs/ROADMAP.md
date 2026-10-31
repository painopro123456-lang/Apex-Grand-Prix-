# Development Roadmap

This roadmap separates what exists from what is planned. A feature is not considered complete until it is implemented, run in-engine, and tested.

## Implemented in the current prototype
- [x] Godot 4 project and Compatibility renderer setup
- [x] Procedural oval test track with collision and barriers
- [x] Grid/start line and alternating kerbs
- [x] Basic player vehicle controller
- [x] Automatic gearbox and speed-sensitive steering
- [x] Prototype aero drag/downforce grip model
- [x] Prototype DRS and ERS controls
- [x] Tyre temperature and wear variables
- [x] Five-red-light race start and basic telemetry HUD

## Next: core driving experience
- [ ] Replace the placeholder collision body with a detailed, properly rigged open-wheel car model
- [ ] Four-wheel suspension, wheel contact, tyre slip curves and brake temperature
- [x] Stable road collision strips and solid barrier collision bodies (prototype; needs in-engine impact testing)\n- [x] Basic impact response, accumulating crash damage and damage-triggered DNF (prototype; needs tuning/testing)\n- [ ] Detailed deformable bodywork, wheel detachment, suspension breakage and recovery system
- [ ] Track limits, off-track grip, kerbs, runoff and gravel-trap behaviour
- [x] Start/finish crossing detection, lap counter and best-lap timing (prototype gate)
- [ ] Sector timing, invalid-lap detection and session results
- [ ] AI opponents with racing line, overtaking and defending
- [ ] Race control: yellow flags, safety car, penalties and pit lane

## Next: authentic Grand Prix weekend
- [ ] Garage and car/driver selection screens
- [ ] Practice, qualifying, sprint and Grand Prix sessions
- [ ] Starting grid formation and race-start control
- [ ] Pit stops, tyre compounds, strategy and pit crew
- [ ] Weather transitions, wet tyres, spray and drying line
- [ ] Full timing tower, minimap, radio and race engineer messages
- [ ] Championship standings and team/driver progression

## Visual and audio quality
- [ ] High-detail original or properly licensed car assets
- [ ] Detailed circuit assets and trackside environments
- [x] Procedural asphalt shader with surface grain, painted track-edge markings, filmic tonemapping and glow
- [ ] Full PBR asset set, reflections, volumetrics and high-end shadow tuning
- [ ] Cockpit camera, TV cameras, replay and photo mode
- [ ] Engine, tyre, wind, crowd and pit audio
- [x] Graphics presets (Low / Medium / High / Ultra), 3D render scale, fullscreen and VSync controls with local settings persistence
- [ ] Performance profiling and optimisation passes across different hardware

## Release engineering
- [ ] Godot headless import and project validation
- [ ] Automated smoke test for project startup
- [ ] Windows export preset and repeatable build workflow
- [ ] Verify installer/executable on a clean Windows machine

## Quality gate
No feature is marked done based only on code being committed. It must be opened in Godot, tested in motion, and checked for regressions. The current prototype has not yet been validated in-engine. The project should be optimised generally, without limiting visual quality to integrated-GPU hardware.


## Current implementation note
The latest pass adds a procedural asphalt surface shader, continuous track-edge paint, improved lighting/post-processing, corrected start-line orientation and a first start/finish lap gate with best-lap display. These are still prototype systems: the lap gate needs validation through a complete lap in Godot, and the project still needs a purpose-built high-detail car asset, suspension, AI and real circuit content.


## Graphics settings pass
The settings page now exposes Low, Medium, High and Ultra presets, 3D render scale, fullscreen mode and VSync. Changes apply immediately and are saved to the local user settings file. These controls are implemented in code but still need in-engine validation on supported renderers and hardware.


## Storage and launch performance targets
- [ ] Keep the complete installed game footprint below **10 GB**, including shipped core assets. Measure the actual exported build as content grows.
- [ ] Use efficient texture/audio/model formats, shared assets and compression; remove duplicate or unused content instead of reducing visual detail indiscriminately.
- [ ] Make optional high-volume content downloadable separately only where that meaningfully protects the core install size.
- [ ] Make the main menu appear quickly: load menu-critical resources first and defer or stream track, garage and race-only assets.
- [ ] Keep network checks, update checks and content downloads from blocking the initial launch; show their status asynchronously.
- [ ] Profile cold-start and repeat-start times, then optimise real bottlenecks, shader compilation and resource loading without imposing a graphics-quality ceiling.
- [ ] Verify both installed size and startup time from a clean exported build; do not mark either target complete until measured.


## Crash and collision prototype
The test circuit now uses overlapping oriented collision strips under the visible asphalt instead of relying on a thin triangle-mesh road collider. The car records significant horizontal impacts against solid collision bodies, loses speed, can yaw away from the impact, accumulates damage, and retires with a DNF at critical damage. This is a first collision pass—not yet a complete crash simulation. Car-to-car impact testing, wheel/suspension damage, recovery, debris and deformable bodywork remain unfinished. Validate the road seams, barrier response and impact thresholds in Godot before treating this as production-ready.

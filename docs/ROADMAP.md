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
- [ ] Better collision response, damage and recovery
- [ ] Track boundaries, off-track grip, kerbs and runoff penalties
- [ ] Lap detection, sector timing, best lap and session results
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
- [ ] PBR materials, improved lighting, reflections and shadows
- [ ] Cockpit camera, TV cameras, replay and photo mode
- [ ] Engine, tyre, wind, crowd and pit audio
- [ ] Scalable graphics presets and performance profiling on target hardware

## Release engineering
- [ ] Godot headless import and project validation
- [ ] Automated smoke test for project startup
- [ ] Windows export preset and repeatable build workflow
- [ ] Verify installer/executable on a clean Windows machine

## Quality gate
No feature is marked done based only on code being committed. It must be opened in Godot, tested in motion, and checked for regressions. The current prototype has not yet been validated in-engine or benchmarked on the 4 GB RAM / integrated-GPU target.

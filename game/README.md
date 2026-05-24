# Game client

This directory holds the Godot 4 project. Open it by launching Godot and selecting the `project.godot` file.

Source layout:

- `scenes/` Godot scene files
- `scripts/` GDScript sources
- `assets/` textures, audio, fonts (CC0 or original)
- `tests/` GUT test scenes
- `addons/` vendored addons (do not edit)

Build and export configuration is managed through the editor and reflected in `export_presets.cfg`. CI uses headless Godot for validation and the release pipeline performs platform exports.

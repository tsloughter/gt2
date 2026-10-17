set shell := ["bash", "-cu"]

project_dir := justfile_directory()

# List the available project commands.
default:
    @just --list

# Run the game.
run:
    flatpak run org.godotengine.Godot --path "{{project_dir}}"

# Open the project in the Godot editor.
editor:
    flatpak run org.godotengine.Godot --editor --path "{{project_dir}}"

# Import and validate the project resources headlessly.
build:
    flatpak run org.godotengine.Godot --headless --import --path "{{project_dir}}"

# Regenerate the original sound effects.
audio:
    python3 "{{project_dir}}/tools/generate_audio.py"

# Regenerate the Blender source, exported models, and model previews.
models:
    flatpak run org.blender.Blender --background --python "{{project_dir}}/tools/generate_first_asset_set.py"

# Regenerate all source assets, then import them into Godot.
assets:
    just audio
    just models
    just build

# Check basic truck driving in headless mode.
test-driving:
    flatpak run org.godotengine.Godot --headless --path "{{project_dir}}" -- --smoke-driving

# Check both trucks leaving either road end and respawning only out of view.
test-road-exit:
    flatpak run org.godotengine.Godot --headless --path "{{project_dir}}" --script res://scripts/test_road_exit.gd

# Check one complete side-loader pickup cycle.
test-pickup:
    flatpak run org.godotengine.Godot --headless --path "{{project_dir}}" -- --smoke-pickup

# Check the complete six-can route.
test-route:
    flatpak run org.godotengine.Godot --headless --path "{{project_dir}}" -- --smoke-full-route

# Check hopper tracking and a complete rear-dump cycle.
test-dump:
    flatpak run org.godotengine.Godot --headless --path "{{project_dir}}" -- --smoke-dump

# Check the full front-loader route, fork alignment, and rear unloading.
test-front-route:
    flatpak run org.godotengine.Godot --headless --path "{{project_dir}}" -- --smoke-front-route

# Check both menu choices, route restart, and returning to level selection.
test-menu:
    flatpak run org.godotengine.Godot --headless --path "{{project_dir}}" -- --smoke-menu

# Capture the opening level chooser.
capture-menu:
    flatpak run org.godotengine.Godot --path "{{project_dir}}" -- --capture-menu

# Capture the front loader tipping a dumpster over the cab.
capture-front:
    flatpak run org.godotengine.Godot --path "{{project_dir}}" -- --capture-front

# Run all automated smoke tests.
test:
    just test-driving
    just test-road-exit
    just test-pickup
    just test-route
    just test-dump
    just test-front-route
    just test-menu

# Build the project and run all automated smoke tests.
check:
    just build
    just test

# Capture the starting-street preview image.
capture-start:
    flatpak run org.godotengine.Godot --path "{{project_dir}}" -- --capture-start

# Capture the completed side-loader preview image.
capture-pickup:
    flatpak run org.godotengine.Godot --path "{{project_dir}}" -- --capture-first-version

# Capture the open tailgate and spilling cargo.
capture-dump:
    flatpak run org.godotengine.Godot --path "{{project_dir}}" -- --capture-rear-dump

# Collect the full route and capture the retained load inside the hopper.
capture-hopper:
    flatpak run org.godotengine.Godot --path "{{project_dir}}" -- --capture-hopper

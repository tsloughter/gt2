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

# Check one complete side-loader pickup cycle.
test-pickup:
    flatpak run org.godotengine.Godot --headless --path "{{project_dir}}" -- --smoke-pickup

# Check the complete six-can route.
test-route:
    flatpak run org.godotengine.Godot --headless --path "{{project_dir}}" -- --smoke-full-route

# Check hopper tracking and a complete rear-dump cycle.
test-dump:
    flatpak run org.godotengine.Godot --headless --path "{{project_dir}}" -- --smoke-dump

# Run all automated smoke tests.
test:
    just test-driving
    just test-pickup
    just test-route
    just test-dump

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

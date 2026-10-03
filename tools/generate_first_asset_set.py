"""Generate the first Little Clean Crew low-poly asset set in Blender.

The script intentionally uses only Blender's bundled Python API. It produces a
side-loader garbage truck, an articulated loader hierarchy, and a residential
trash can, then saves a .blend file, exports a .glb, and renders three previews.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODEL_DIR = PROJECT_ROOT / "assets" / "models"
SOURCE_MODEL_DIR = PROJECT_ROOT / "source_assets"
RENDER_DIR = PROJECT_ROOT / "renders"
BLEND_PATH = SOURCE_MODEL_DIR / "little_clean_crew.blend"
GLB_PATH = MODEL_DIR / "little_clean_crew.glb"


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def make_material(
    name: str,
    color: tuple[float, float, float, float],
    *,
    metallic: float = 0.0,
    roughness: float = 0.5,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    if emission_strength:
        shader.inputs["Emission Color"].default_value = color
        shader.inputs["Emission Strength"].default_value = emission_strength
    return material


def apply_bevel(obj: bpy.types.Object, width: float, segments: int = 2) -> None:
    if width <= 0:
        return
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    modifier = obj.modifiers.new(name="Friendly soft edges", type="BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def cube(
    name: str,
    location: tuple[float, float, float],
    dimensions: tuple[float, float, float],
    material: bpy.types.Material,
    *,
    bevel: float = 0.06,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    parent: bpy.types.Object | None = None,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=(0.0, 0.0, 0.0))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    apply_bevel(obj, bevel)
    obj.location = location
    obj.rotation_euler = rotation
    obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    return obj


def cylinder(
    name: str,
    location: tuple[float, float, float],
    radius: float,
    depth: float,
    material: bpy.types.Material,
    *,
    vertices: int = 16,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bevel: float = 0.03,
    parent: bpy.types.Object | None = None,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=(0.0, 0.0, 0.0),
    )
    obj = bpy.context.object
    obj.name = name
    apply_bevel(obj, bevel)
    obj.location = location
    obj.rotation_euler = rotation
    obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    return obj


def sphere(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    *,
    parent: bpy.types.Object | None = None,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=16,
        ring_count=8,
        location=(0.0, 0.0, 0.0),
    )
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.location = location
    obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    return obj


def empty(
    name: str,
    location: tuple[float, float, float],
    *,
    parent: bpy.types.Object | None = None,
    display_size: float = 0.18,
) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.empty_display_type = "SPHERE"
    obj.empty_display_size = display_size
    obj.location = location
    if parent:
        obj.parent = parent
    return obj


def beam_between(
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    thickness: float,
    material: bpy.types.Material,
    *,
    parent: bpy.types.Object,
    bevel: float = 0.04,
) -> bpy.types.Object:
    start_v = Vector(start)
    end_v = Vector(end)
    vector = end_v - start_v
    midpoint = (start_v + end_v) * 0.5
    obj = cube(
        name,
        tuple(midpoint),
        (thickness, vector.length, thickness),
        material,
        bevel=bevel,
        parent=parent,
    )
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0.0, 1.0, 0.0)).rotation_difference(vector)
    return obj


def tapered_bin_body(
    name: str,
    material: bpy.types.Material,
    *,
    parent: bpy.types.Object,
) -> bpy.types.Object:
    bottom_x, bottom_y = 0.62, 0.54
    top_x, top_y = 0.86, 0.72
    bottom_z, top_z = 0.18, 1.26
    vertices = [
        (-bottom_x / 2, -bottom_y / 2, bottom_z),
        (bottom_x / 2, -bottom_y / 2, bottom_z),
        (bottom_x / 2, bottom_y / 2, bottom_z),
        (-bottom_x / 2, bottom_y / 2, bottom_z),
        (-top_x / 2, -top_y / 2, top_z),
        (top_x / 2, -top_y / 2, top_z),
        (top_x / 2, top_y / 2, top_z),
        (-top_x / 2, top_y / 2, top_z),
    ]
    faces = [
        (0, 3, 2, 1),
        (4, 5, 6, 7),
        (0, 1, 5, 4),
        (1, 2, 6, 5),
        (2, 3, 7, 6),
        (3, 0, 4, 7),
    ]
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    obj.parent = parent
    apply_bevel(obj, 0.055, 2)
    return obj


def add_label(
    body: str,
    name: str,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    *,
    size: float,
    parent: bpy.types.Object,
) -> bpy.types.Object:
    curve = bpy.data.curves.new(type="FONT", name=f"{name}_Curve")
    curve.body = body
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.size = size
    curve.extrude = 0.012
    curve.bevel_depth = 0.006
    text_obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(text_obj)
    text_obj.location = location
    text_obj.rotation_euler = (math.radians(90), 0.0, 0.0)
    text_obj.data.materials.append(material)
    text_obj.parent = parent
    bpy.context.view_layer.objects.active = text_obj
    text_obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    text_obj.select_set(False)
    return text_obj


def build_truck(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root = empty("GarbageTruck_Root", (0.0, 0.0, 0.0), display_size=0.35)

    cube("Chassis", (0.15, 0.0, 0.72), (7.65, 2.18, 0.34), materials["dark"], bevel=0.08, parent=root)
    cube("Cab", (-2.83, 0.0, 2.02), (2.22, 2.46, 2.62), materials["green"], bevel=0.24, parent=root)
    cube("Cab_Roof", (-2.83, 0.0, 3.39), (2.10, 2.35, 0.18), materials["light_green"], bevel=0.09, parent=root)
    cube("Front_Bumper", (-3.99, 0.0, 0.92), (0.22, 2.50, 0.28), materials["yellow"], bevel=0.07, parent=root)
    cube("Front_Grille", (-4.02, 0.0, 1.63), (0.07, 1.34, 0.58), materials["charcoal"], bevel=0.04, parent=root)
    for y in (-0.75, 0.75):
        cube(f"Headlight_{'R' if y < 0 else 'L'}", (-4.065, y, 1.33), (0.08, 0.42, 0.30), materials["headlight"], bevel=0.08, parent=root)

    cube("Windshield", (-3.955, 0.0, 2.65), (0.055, 1.89, 0.83), materials["glass"], bevel=0.10, rotation=(0.0, math.radians(-4), 0.0), parent=root)
    for y, suffix in ((-1.244, "Passenger"), (1.244, "Driver")):
        cube(f"Side_Window_{suffix}", (-2.78, y, 2.65), (1.18, 0.055, 0.78), materials["glass"], bevel=0.10, parent=root)
        cube(f"Door_Handle_{suffix}", (-2.42, y * 1.015, 2.03), (0.28, 0.05, 0.07), materials["dark"], bevel=0.025, parent=root)

    # Build a hollow upper body: a solid box and a black roof decal cannot
    # contain visible cargo. Coordinates here are Blender Z-up; Godot uses Y-up.
    cube("Collection_Body", (1.10, 0.0, 1.5575), (5.18, 2.58, 1.485), materials["green"], bevel=0.12, parent=root)
    for y, side in ((-1.18, "Passenger"), (1.18, "Driver")):
        cube(f"Collection_Wall_{side}", (1.10, y, 2.77), (5.18, 0.22, 1.15), materials["green"], bevel=0.06, parent=root)
    for x, end in ((-1.38, "Front"), (3.58, "Rear")):
        cube(f"Collection_Wall_{end}", (x, 0.0, 2.77), (0.22, 2.36, 1.15), materials["green"], bevel=0.06, parent=root)
    # Four roof panels surround the clear 2.85 x 1.82 opening. The floor is
    # 1.15 m below its rim, with space for the complete six-can route inside.
    cube("Hopper_Rim_Front", (-0.8175, 0.0, 3.425), (1.345, 2.58, 0.25), materials["light_green"], bevel=0.04, parent=root)
    cube("Hopper_Rim_Rear", (3.1975, 0.0, 3.425), (0.985, 2.58, 0.25), materials["light_green"], bevel=0.04, parent=root)
    for y, side in ((-1.10, "Passenger"), (1.10, "Driver")):
        cube(f"Hopper_Rim_{side}", (1.28, y, 3.425), (2.85, 0.38, 0.25), materials["light_green"], bevel=0.04, parent=root)
    cube("Hopper_Floor", (1.10, 0.0, 2.35), (4.74, 2.14, 0.10), materials["charcoal"], bevel=0.01, parent=root)
    cube("Rear_Tailgate", (3.74, 0.0, 2.08), (0.32, 2.44, 2.27), materials["light_green"], bevel=0.13, parent=root)
    cube("Safety_Stripe_Passenger", (0.98, -1.306, 1.54), (4.75, 0.055, 0.24), materials["yellow"], bevel=0.025, parent=root)
    cube("Safety_Stripe_Driver", (0.98, 1.306, 1.54), (4.75, 0.055, 0.24), materials["yellow"], bevel=0.025, parent=root)
    empty("Hopper_Opening", (1.28, 0.0, 3.55), parent=root)

    add_label("CLEAN CREW", "Passenger_Side_Label", (1.15, -1.335, 2.60), materials["cream"], size=0.38, parent=root)

    for index, x in enumerate((-2.72, 1.55, 2.78), start=1):
        for y, side in ((-1.31, "Passenger"), (1.31, "Driver")):
            cylinder(
                f"Wheel_{index}_{side}",
                (x, y, 0.69),
                0.64,
                0.38,
                materials["tire"],
                rotation=(math.radians(90), 0.0, 0.0),
                bevel=0.045,
                parent=root,
            )
            cylinder(
                f"Hub_{index}_{side}",
                (x, y * 1.025, 0.69),
                0.27,
                0.405,
                materials["metal"],
                vertices=16,
                rotation=(math.radians(90), 0.0, 0.0),
                bevel=0.03,
                parent=root,
            )

    for y, side in ((-0.72, "Passenger"), (0.72, "Driver")):
        cylinder(f"Roof_Beacon_{side}", (-3.15, y, 3.58), 0.12, 0.20, materials["orange_light"], bevel=0.025, parent=root)
    cube("Rear_Bumper", (3.98, 0.0, 0.83), (0.22, 2.46, 0.28), materials["yellow"], bevel=0.07, parent=root)
    for y in (-0.88, 0.88):
        sphere(f"Rear_Light_{y:+.0f}", (3.93, y, 1.40), (0.07, 0.16, 0.16), materials["red_light"], parent=root)

    build_side_loader(root, materials)
    return root


def build_side_loader(root: bpy.types.Object, materials: dict[str, bpy.types.Material]) -> None:
    base = empty("SideLoader_BasePivot", (0.10, -1.42, 1.68), parent=root, display_size=0.23)
    cube("SideLoader_BaseMount", (0.0, 0.0, 0.0), (0.88, 0.34, 0.76), materials["orange"], bevel=0.12, parent=base)
    cylinder("SideLoader_BasePin", (0.0, -0.19, 0.0), 0.18, 0.48, materials["metal"], rotation=(math.radians(90), 0.0, 0.0), parent=base)

    lift = empty("SideLoader_LiftPivot", (0.0, -0.12, 0.0), parent=base, display_size=0.20)
    for x, suffix in ((-0.25, "Front"), (0.25, "Rear")):
        beam_between(f"Loader_LowerArm_{suffix}", (x, -0.02, 0.05), (x, -1.24, -0.26), 0.16, materials["orange"], parent=lift)
    beam_between("Loader_Hydraulic_Cylinder", (0.0, -0.02, 0.31), (0.0, -1.05, -0.05), 0.10, materials["metal"], parent=lift, bevel=0.025)

    extension = empty("SideLoader_ExtensionPivot", (0.0, -1.24, -0.26), parent=lift, display_size=0.18)
    for x, suffix in ((-0.25, "Front"), (0.25, "Rear")):
        beam_between(f"Loader_UpperArm_{suffix}", (x, 0.0, 0.0), (x, -0.64, -0.16), 0.15, materials["orange"], parent=extension)
    cube("Loader_CrossBrace", (0.0, -0.33, -0.08), (0.68, 0.14, 0.14), materials["yellow"], bevel=0.035, parent=extension)

    grabber = empty("SideLoader_GrabberPivot", (0.0, -0.78, -0.20), parent=extension, display_size=0.18)
    cube("Loader_GrabberBar", (0.0, 0.0, 0.0), (1.46, 0.22, 0.25), materials["orange"], bevel=0.07, parent=grabber)
    cylinder("Loader_GrabberPin", (0.0, -0.13, 0.0), 0.14, 0.30, materials["metal"], rotation=(math.radians(90), 0.0, 0.0), parent=grabber)

    left = empty("SideLoader_LeftClawPivot", (-0.66, 0.0, 0.0), parent=grabber, display_size=0.12)
    right = empty("SideLoader_RightClawPivot", (0.66, 0.0, 0.0), parent=grabber, display_size=0.12)
    for pivot, suffix, direction in ((left, "Left", 1.0), (right, "Right", -1.0)):
        cube(f"Loader_{suffix}Claw_Stem", (0.0, -0.24, 0.0), (0.14, 0.55, 0.18), materials["orange"], bevel=0.05, parent=pivot)
        cube(f"Loader_{suffix}Claw_Pad", (0.15 * direction, -0.49, 0.0), (0.39, 0.14, 0.34), materials["rubber"], bevel=0.07, parent=pivot)


def build_trash_can(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root = empty("ResidentialCan_Root", (0.10, -3.62, 0.0), display_size=0.25)
    tapered_bin_body("ResidentialCan_Body", materials["blue"], parent=root)
    cube("ResidentialCan_Rim", (0.0, 0.0, 1.23), (0.94, 0.80, 0.16), materials["dark_blue"], bevel=0.07, parent=root)

    lid_pivot = empty("ResidentialCan_LidPivot", (0.0, 0.35, 1.31), parent=root, display_size=0.10)
    cube("ResidentialCan_Lid", (0.0, -0.35, 0.04), (0.98, 0.82, 0.15), materials["dark_blue"], bevel=0.08, parent=lid_pivot)
    cube("ResidentialCan_Handle", (0.0, 0.09, 0.05), (0.46, 0.12, 0.13), materials["charcoal"], bevel=0.05, parent=lid_pivot)

    for x, suffix in ((-0.32, "Left"), (0.32, "Right")):
        cylinder(
            f"ResidentialCan_Wheel_{suffix}",
            (x, 0.29, 0.19),
            0.18,
            0.13,
            materials["tire"],
            vertices=12,
            rotation=(0.0, math.radians(90), 0.0),
            bevel=0.025,
            parent=root,
        )
    cube("ResidentialCan_Axle", (0.0, 0.29, 0.19), (0.76, 0.08, 0.08), materials["metal"], bevel=0.02, parent=root)
    return root


def look_at(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def add_preview_stage(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    cube("Preview_Ground", (0.0, 0.0, -0.11), (22.0, 16.0, 0.20), materials["ground"], bevel=0.05)
    cube("Preview_Curb", (0.0, -4.60, 0.16), (15.0, 0.55, 0.42), materials["curb"], bevel=0.08)
    for x in (-5.0, 0.0, 5.0):
        cube(f"Preview_RoadStripe_{x:+.0f}", (x, 2.55, 0.015), (2.4, 0.16, 0.025), materials["road_stripe"], bevel=0.015)

    bpy.ops.object.light_add(type="AREA", location=(-3.0, -6.0, 10.0))
    key = bpy.context.object
    key.name = "Preview_KeyLight"
    key.data.energy = 1150
    key.data.shape = "DISK"
    key.data.size = 6.0
    look_at(key, (0.0, 0.0, 1.4))

    bpy.ops.object.light_add(type="AREA", location=(7.0, 4.0, 6.0))
    fill = bpy.context.object
    fill.name = "Preview_FillLight"
    fill.data.energy = 850
    fill.data.size = 5.0
    look_at(fill, (0.0, 0.0, 1.6))

    bpy.ops.object.light_add(type="SUN", location=(0.0, 0.0, 8.0))
    sun = bpy.context.object
    sun.name = "Preview_Sun"
    sun.rotation_euler = (math.radians(25), math.radians(-20), math.radians(-25))
    sun.data.energy = 1.4
    sun.data.angle = math.radians(18)

    camera_data = bpy.data.cameras.new("Preview_Camera")
    camera = bpy.data.objects.new("Preview_Camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 10.5
    bpy.context.scene.camera = camera
    return camera


def configure_render() -> None:
    scene = bpy.context.scene
    # Blender 5.2 renamed the Eevee enum back to BLENDER_EEVEE.
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.055, 0.075, 0.11)
    scene.render.image_settings.color_mode = "RGBA"
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass


def render_previews(camera: bpy.types.Object) -> None:
    views = {
        "side_loader_front.png": ((-10.5, -12.5, 7.3), (0.0, -0.3, 1.45), 10.7),
        "side_loader_side.png": ((0.0, -15.5, 5.2), (0.0, -0.35, 1.45), 10.0),
        "side_loader_rear.png": ((10.5, -12.5, 7.0), (0.15, -0.25, 1.45), 10.7),
    }
    for filename, (location, target, ortho_scale) in views.items():
        camera.location = location
        camera.data.ortho_scale = ortho_scale
        look_at(camera, target)
        bpy.context.scene.render.filepath = str(RENDER_DIR / filename)
        bpy.ops.render.render(write_still=True)


def export_assets() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_cameras=False,
        export_lights=False,
    )
    bpy.ops.object.select_all(action="DESELECT")


def main() -> None:
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    SOURCE_MODEL_DIR.mkdir(parents=True, exist_ok=True)
    RENDER_DIR.mkdir(parents=True, exist_ok=True)
    reset_scene()

    materials = {
        "green": make_material("Truck green", (0.055, 0.56, 0.25, 1.0), roughness=0.42),
        "light_green": make_material("Truck highlight green", (0.12, 0.75, 0.34, 1.0), roughness=0.40),
        "orange": make_material("Loader orange", (1.0, 0.35, 0.035, 1.0), metallic=0.05, roughness=0.34),
        "yellow": make_material("Safety yellow", (1.0, 0.72, 0.035, 1.0), roughness=0.38),
        "dark": make_material("Dark chassis", (0.045, 0.065, 0.075, 1.0), metallic=0.35, roughness=0.42),
        "charcoal": make_material("Charcoal", (0.025, 0.035, 0.045, 1.0), roughness=0.48),
        "tire": make_material("Tire rubber", (0.012, 0.016, 0.020, 1.0), roughness=0.76),
        "rubber": make_material("Grabber rubber", (0.035, 0.045, 0.050, 1.0), roughness=0.72),
        "metal": make_material("Friendly metal", (0.42, 0.50, 0.54, 1.0), metallic=0.72, roughness=0.30),
        "glass": make_material("Blue glass", (0.035, 0.20, 0.30, 1.0), metallic=0.12, roughness=0.20),
        "headlight": make_material("Warm headlights", (1.0, 0.90, 0.48, 1.0), roughness=0.24, emission_strength=1.7),
        "orange_light": make_material("Orange beacons", (1.0, 0.22, 0.02, 1.0), roughness=0.22, emission_strength=1.2),
        "red_light": make_material("Red rear lights", (0.85, 0.018, 0.012, 1.0), roughness=0.24, emission_strength=0.8),
        "cream": make_material("Warm cream", (1.0, 0.93, 0.74, 1.0), roughness=0.48),
        "blue": make_material("Bin blue", (0.035, 0.32, 0.80, 1.0), roughness=0.52),
        "dark_blue": make_material("Bin dark blue", (0.025, 0.14, 0.40, 1.0), roughness=0.52),
        "ground": make_material("Road", (0.12, 0.15, 0.17, 1.0), roughness=0.92),
        "curb": make_material("Curb", (0.42, 0.45, 0.46, 1.0), roughness=0.86),
        "road_stripe": make_material("Road stripe", (0.94, 0.79, 0.18, 1.0), roughness=0.76),
    }

    build_truck(materials)
    build_trash_can(materials)
    export_assets()
    if "--skip-previews" not in sys.argv:
        camera = add_preview_stage(materials)
        configure_render()
        render_previews(camera)
        print(f"Rendered previews: {RENDER_DIR}")
    print(f"Saved Blender source: {BLEND_PATH}")
    print(f"Exported GLB: {GLB_PATH}")


if __name__ == "__main__":
    main()

"""Renderiza en Blender (Cycles) una escena exportada por tools/lune/export-scene.luau.

Las piezas de Roblox se convierten en mallas (bloque, cilindro, bola, cuña, elipsoide) con materiales
parecidos a los de Roblox, para revisar el diseño y producir el icono y las miniaturas del juego.

    python render.py --scene map.json --out thumb.png --camera -10,40,10 --target -45,4,-60 \
        --res 1920x1080 --samples 64 --style night
"""

import argparse
import json
import math
import sys

import bpy
from mathutils import Matrix, Vector


def parse_vec(text):
    return [float(v) for v in text.split(",")]


def roblox_to_blender_vec(v):
    # Roblox: Y arriba, -Z adelante. Blender: Z arriba.
    return Vector((v[0], -v[2], v[1]))


M = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_meshes():
    meshes = {}
    # bloque unidad
    bpy.ops.mesh.primitive_cube_add(size=1)
    cube = bpy.context.active_object
    meshes["Block"] = cube.data
    bpy.data.objects.remove(cube)
    # cilindro unidad a lo largo de X (como en Roblox)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.5, depth=1, rotation=(0, math.pi / 2, 0))
    cyl = bpy.context.active_object
    bpy.ops.object.transform_apply(rotation=True)
    for poly in cyl.data.polygons:
        poly.use_smooth = len(poly.vertices) == 4
    meshes["Cylinder"] = cyl.data
    bpy.data.objects.remove(cyl)
    # esfera
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=0.5)
    sph = bpy.context.active_object
    for poly in sph.data.polygons:
        poly.use_smooth = True
    meshes["Ball"] = sph.data
    meshes["Ellipsoid"] = sph.data
    bpy.data.objects.remove(sph)
    # cuña de Roblox (en coordenadas locales de Roblox; la matriz M la gira después)
    wedge = bpy.data.meshes.new("Wedge")
    verts = []
    for x in (-0.5, 0.5):
        verts += [(x, -0.5, -0.5), (x, -0.5, 0.5), (x, 0.5, 0.5)]
    faces = [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    wedge.from_pydata(verts, [], faces)
    wedge.update()
    meshes["Wedge"] = wedge
    # en las mallas de bloque/cilindro/esfera los ejes ya coinciden con Roblox local
    placeholder = bpy.data.materials.new("Placeholder")
    for mesh in set(meshes.values()):
        mesh.materials.append(placeholder)
    return meshes


def node_material(name, setup):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    info = nt.nodes.new("ShaderNodeObjectInfo")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(info.outputs["Color"], bsdf.inputs["Base Color"])
    shader_out = setup(nt, info, bsdf)
    transparent = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(info.outputs["Alpha"], mix.inputs["Fac"])
    nt.links.new(transparent.outputs[0], mix.inputs[1])
    nt.links.new(shader_out, mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return mat


def noise_bump(nt, bsdf, scale, strength):
    tex = nt.nodes.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = scale
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = strength
    nt.links.new(tex.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])


def make_materials():
    mats = {}

    def plastic(nt, info, bsdf):
        bsdf.inputs["Roughness"].default_value = 0.35
        return bsdf.outputs[0]

    def rough(nt, info, bsdf):
        bsdf.inputs["Roughness"].default_value = 0.85
        noise_bump(nt, bsdf, 8, 0.15)
        return bsdf.outputs[0]

    def wood(nt, info, bsdf):
        bsdf.inputs["Roughness"].default_value = 0.7
        wave = nt.nodes.new("ShaderNodeTexWave")
        wave.inputs["Scale"].default_value = 3
        wave.inputs["Distortion"].default_value = 4
        mixc = nt.nodes.new("ShaderNodeMix")
        mixc.data_type = "RGBA"
        mixc.inputs["Factor"].default_value = 0.25
        nt.links.new(info.outputs["Color"], mixc.inputs[6])
        dark = nt.nodes.new("ShaderNodeMix")
        dark.data_type = "RGBA"
        dark.inputs["Factor"].default_value = 0.4
        nt.links.new(info.outputs["Color"], dark.inputs[6])
        dark.inputs[7].default_value = (0, 0, 0, 1)
        nt.links.new(wave.outputs["Fac"], mixc.inputs["Factor"])
        nt.links.new(dark.outputs[2], mixc.inputs[7])
        nt.links.new(mixc.outputs[2], bsdf.inputs["Base Color"])
        return bsdf.outputs[0]

    def snow(nt, info, bsdf):
        bsdf.inputs["Roughness"].default_value = 0.9
        bsdf.inputs["Subsurface Weight"].default_value = 0.15
        noise_bump(nt, bsdf, 3, 0.25)
        return bsdf.outputs[0]

    def metal(nt, info, bsdf):
        bsdf.inputs["Metallic"].default_value = 1.0
        bsdf.inputs["Roughness"].default_value = 0.28
        return bsdf.outputs[0]

    def glass(nt, info, bsdf):
        bsdf.inputs["Roughness"].default_value = 0.04
        bsdf.inputs["Transmission Weight"].default_value = 1.0
        bsdf.inputs["IOR"].default_value = 1.45
        return bsdf.outputs[0]

    def ice(nt, info, bsdf):
        bsdf.inputs["Roughness"].default_value = 0.12
        bsdf.inputs["Transmission Weight"].default_value = 0.6
        bsdf.inputs["IOR"].default_value = 1.31
        noise_bump(nt, bsdf, 12, 0.2)
        return bsdf.outputs[0]

    def neon(nt, info, bsdf):
        emission = nt.nodes.new("ShaderNodeEmission")
        emission.inputs["Strength"].default_value = 6.0
        nt.links.new(info.outputs["Color"], emission.inputs["Color"])
        return emission.outputs[0]

    def foil(nt, info, bsdf):
        bsdf.inputs["Metallic"].default_value = 1.0
        bsdf.inputs["Roughness"].default_value = 0.18
        noise_bump(nt, bsdf, 20, 0.35)
        return bsdf.outputs[0]

    def forcefield(nt, info, bsdf):
        emission = nt.nodes.new("ShaderNodeEmission")
        emission.inputs["Strength"].default_value = 1.5
        nt.links.new(info.outputs["Color"], emission.inputs["Color"])
        return emission.outputs[0]

    table = {
        "Plastic": plastic,
        "SmoothPlastic": plastic,
        "Neon": neon,
        "Glass": glass,
        "Ice": ice,
        "Glacier": ice,
        "Snow": snow,
        "Metal": metal,
        "DiamondPlate": metal,
        "Foil": foil,
        "Wood": wood,
        "WoodPlanks": wood,
        "Fabric": rough,
        "Grass": rough,
        "Brick": rough,
        "Cobblestone": rough,
        "Slate": rough,
        "Marble": plastic,
        "ForceField": forcefield,
    }
    for name, setup in table.items():
        mats[name] = node_material(name, setup)
    mats["_default"] = mats["Plastic"]
    return mats


def build_scene(scene_path, meshes, mats, emission_scale):
    with open(scene_path) as f:
        data = json.load(f)
    collection = bpy.context.scene.collection
    for p in data["parts"]:
        shape = p["s"]
        mesh = meshes.get(shape, meshes["Block"])
        obj = bpy.data.objects.new("P", mesh)
        sx, sy, sz = p["z"]
        if shape == "Ball":
            d = min(sx, sy, sz)
            sx = sy = sz = d
        elif shape == "Cylinder":
            d = min(sy, sz)
            sy = sz = d
        c = p["c"]
        rot = Matrix(((c[3], c[4], c[5], c[0]), (c[6], c[7], c[8], c[1]), (c[9], c[10], c[11], c[2]), (0, 0, 0, 1)))
        scale = Matrix.Diagonal((sx, sy, sz, 1))
        obj.matrix_world = M @ rot @ scale
        r, g, b = p["k"]
        obj.color = (r ** 2.2, g ** 2.2, b ** 2.2, 1 - p["t"])
        material = mats.get(p["m"], mats["_default"])
        collection.objects.link(obj)
        slot = obj.material_slots[0]
        slot.link = "OBJECT"
        slot.material = material
    for l in data.get("lights", []):
        light = bpy.data.lights.new("L", "POINT")
        r, g, b = l["k"]
        light.color = (r, g, b)
        light.energy = l["b"] * l["r"] * l["r"] * emission_scale
        light.shadow_soft_size = 0.6
        obj = bpy.data.objects.new("L", light)
        obj.location = roblox_to_blender_vec(l["p"])
        collection.objects.link(obj)
    return data


def setup_world(style):
    world = bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes["Background"]
    if style == "night":
        sky = nt.nodes.new("ShaderNodeTexGradient")
        mapping = nt.nodes.new("ShaderNodeMapping")
        coord = nt.nodes.new("ShaderNodeTexCoord")
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (0.05, 0.07, 0.2, 1)
        ramp.color_ramp.elements[1].color = (0.003, 0.004, 0.02, 1)
        mapping.inputs["Rotation"].default_value = (0, math.pi / 2, 0)
        nt.links.new(coord.outputs["Generated"], mapping.inputs["Vector"])
        nt.links.new(mapping.outputs["Vector"], sky.inputs["Vector"])
        nt.links.new(sky.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
        bg.inputs["Strength"].default_value = 1.6
        moon = bpy.data.lights.new("Moon", "SUN")
        moon.color = (0.62, 0.72, 1.0)
        moon.energy = 0.9
        moon.angle = 0.06
        moon_obj = bpy.data.objects.new("Moon", moon)
        moon_obj.rotation_euler = (math.radians(52), math.radians(-18), math.radians(35))
        bpy.context.scene.collection.objects.link(moon_obj)
        fill = bpy.data.lights.new("Fill", "SUN")
        fill.color = (0.5, 0.55, 0.85)
        fill.energy = 0.35
        fill_obj = bpy.data.objects.new("Fill", fill)
        fill_obj.rotation_euler = (math.radians(70), math.radians(20), math.radians(-140))
        bpy.context.scene.collection.objects.link(fill_obj)
    else:
        bg.inputs["Color"].default_value = (0.03, 0.05, 0.14, 1)
        bg.inputs["Strength"].default_value = 1.0
        for i, (rot, energy, color) in enumerate(
            [
                ((50, 0, 30), 3.2, (1, 0.95, 0.88)),
                ((60, 0, -120), 1.4, (0.6, 0.7, 1.0)),
                ((20, 0, 170), 1.0, (1.0, 0.8, 0.6)),
            ]
        ):
            sun = bpy.data.lights.new(f"Key{i}", "SUN")
            sun.energy = energy
            sun.color = color
            sun.angle = 0.2
            o = bpy.data.objects.new(f"Key{i}", sun)
            o.rotation_euler = tuple(math.radians(a) for a in rot)
            bpy.context.scene.collection.objects.link(o)


def setup_camera(cam_pos, target, fov, ortho=None):
    cam = bpy.data.cameras.new("Cam")
    cam.angle = math.radians(fov)
    cam.clip_end = 3000
    if ortho:
        cam.type = "ORTHO"
        cam.ortho_scale = ortho
    obj = bpy.data.objects.new("Cam", cam)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = roblox_to_blender_vec(cam_pos)
    direction = roblox_to_blender_vec(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = obj


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--scene", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--camera", default="0,40,60")
    parser.add_argument("--target", default="0,0,0")
    parser.add_argument("--res", default="1280x720")
    parser.add_argument("--samples", type=int, default=48)
    parser.add_argument("--style", default="night")
    parser.add_argument("--fov", type=float, default=50)
    parser.add_argument("--ortho", type=float, default=0)
    parser.add_argument("--lights", type=float, default=0.6)
    parser.add_argument("--exposure", type=float, default=0.0)
    parser.add_argument("--transparent", action="store_true")
    args = parser.parse_args(argv)

    clear_scene()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = args.samples
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 6
    scene.cycles.transparent_max_bounces = 12
    scene.cycles.light_sampling_threshold = 0.01
    w, h = (int(v) for v in args.res.split("x"))
    scene.render.resolution_x = w
    scene.render.resolution_y = h
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = args.exposure
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = args.transparent
    scene.render.image_settings.color_mode = "RGBA" if args.transparent else "RGB"

    meshes = make_meshes()
    mats = make_materials()
    data = build_scene(args.scene, meshes, mats, args.lights)
    setup_world(args.style)
    setup_camera(parse_vec(args.camera), parse_vec(args.target), args.fov, args.ortho or None)
    scene.render.filepath = args.out
    print(f"Renderizando {len(data['parts'])} piezas -> {args.out}")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()

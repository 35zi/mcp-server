"""Offline Blender validation: closed meshes, material-free geometry, and FBX round trips."""
import argparse
import json
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

FAMILIES = {
    'block_animals': ('mouse_hedgehog_duckling_frog.blend', {'Mouse': ('mouse', 28, 400), 'Hedgehog': ('hedgehog', 48, 400), 'Duckling': ('duckling', 19, 260), 'Frog': ('frog', 32, 384)}),
    'revolver': ('revolver.blend', {'Revolver': ('revolver', 28, 1828)}),
    'three_weapons': ('shotgun_bolt_sniper_automatic_rifle.blend', {'Shotgun': ('shotgun', 24, 516), 'BoltSniper': ('bolt_action_sniper', 33, 1256), 'AutomaticRifle': ('automatic_rifle', 36, 776)}),
    'desert_animals': ('scorpion_spider_camel_vulture.blend', {'Scorpion': ('scorpion', 53, 656), 'Spider': ('spider', 37, 452), 'Camel': ('camel', 33, 428), 'Vulture': ('vulture', 32, 472)}),
}

def measure(meshes):
    return {'parts': len(meshes), 'triangles': sum(sum(len(p.vertices)-2 for p in obj.data.polygons) for obj in meshes), 'material_slots': sum(len(obj.data.materials) for obj in meshes)}

def main():
    if not bpy.app.background:
        raise RuntimeError('Run this validator in background Blender; it opens source files and imports FBXs.')
    argv = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument('--asset-root', type=Path, default=Path(__file__).resolve().parents[1]/'assets')
    parser.add_argument('--manifest', type=Path, help='Write measured model metadata as JSON.')
    options = parser.parse_args(argv)
    manifest = {'format': 'FBX', 'source_up_axis': 'Z', 'source_front_axis_animals': '-Y', 'source_front_axis_weapons': '+X', 'models': []}
    for family, (source, definitions) in FAMILIES.items():
        bpy.ops.wm.open_mainfile(filepath=str(options.asset_root/family/source))
        for species, (filename, count, triangles) in definitions.items():
            root = bpy.data.objects[species+'_Root']
            meshes = [obj for obj in bpy.data.collections[species].objects if obj.type == 'MESH']
            expected = {'parts': count, 'triangles': triangles, 'material_slots': 0}
            assert measure(meshes) == expected, (species, measure(meshes))
            inverse = root.matrix_world.inverted()
            corners = [inverse @ obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
            dimensions = [round(max(p[i] for p in corners)-min(p[i] for p in corners), 3) for i in range(3)]
            for obj in meshes:
                bm = bmesh.new()
                bm.from_mesh(obj.data)
                assert all(edge.is_manifold for edge in bm.edges), obj.name
                assert all(len(face.verts) >= 3 and face.calc_area() > 0 for face in bm.faces), obj.name
                bm.free()
            original_scene = bpy.context.scene
            temp = bpy.data.scenes.new('FBX Verification')
            bpy.context.window.scene = temp
            try:
                bpy.ops.import_scene.fbx(filepath=str(options.asset_root/family/(filename+'.fbx')))
                imported = [obj for obj in temp.objects if obj.type == 'MESH']
                assert measure(imported) == expected, (species, measure(imported))
            finally:
                bpy.context.window.scene = original_scene
                for obj in list(temp.objects):
                    data = obj.data
                    bpy.data.objects.remove(obj, do_unlink=True)
                    if data and data.users == 0 and isinstance(data, bpy.types.Mesh):
                        bpy.data.meshes.remove(data)
                bpy.data.scenes.remove(temp)
            manifest['models'].append({'name': species, 'family': family, 'file': family+'/'+filename+'.fbx', 'source': family+'/'+source, **expected, 'dimensions_blender_units_xyz': dimensions, 'fbx_round_trip_verified': True})
            print('Verified:', species, expected, dimensions)
    if options.manifest:
        options.manifest.write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    print('Validated', len(manifest['models']), 'models.')

if __name__ == '__main__':
    main()

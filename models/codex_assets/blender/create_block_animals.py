from pathlib import Path
import bpy
import math
import os
from mathutils import Vector

OUTPUT = str(Path(os.environ.get('CODEX_ASSET_OUTPUT', Path(__file__).resolve().parents[1] / 'assets')) / 'block_animals')
os.makedirs(OUTPUT, exist_ok=True)
scene = bpy.data.scenes.new('Block Animals - Geometry Only')
bpy.context.window.scene = scene
family = bpy.data.collections.new('Block Animals')
scene.collection.children.link(family)
stage = bpy.data.collections.new('Preview Staging')
scene.collection.children.link(stage)
roots = {}
current_collection = None
current_root = None

def mesh(name, vertices, faces, location=(0, 0, 0), collection=None, parent=True):
    data = bpy.data.meshes.new(name + '_Mesh')
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    (collection or current_collection).objects.link(obj)
    if parent:
        obj.parent = current_root
    obj.location = location
    return obj

def box(name, location, size, rotation=None):
    x, y, z = [d / 2 for d in size]
    obj = mesh(name, [(-x,-y,-z), (x,-y,-z), (x,y,-z), (-x,y,-z),
                      (-x,-y,z), (x,-y,z), (x,y,z), (-x,y,z)],
               [(0,3,2,1), (4,5,6,7), (0,1,5,4), (1,2,6,5), (2,3,7,6), (3,0,4,7)], location)
    if rotation:
        obj.rotation_euler = rotation
    return obj

def panel(name, points, depth, location):
    # Extruded polygon in XZ, facing -Y.
    count = len(points)
    verts = [(x, -depth/2, z) for x,z in points] + [(x, depth/2, z) for x,z in points]
    faces = [tuple(range(count)), tuple(range(2*count-1, count-1, -1))]
    faces += [(i, (i+1)%count, (i+1)%count+count, i+count) for i in range(count)]
    return mesh(name, verts, faces, location)

def rod(name, start, end, width, depth=None):
    a, b = Vector(start), Vector(end)
    obj = box(name, (a+b)/2, (width, depth or width, (b-a).length + width*0.15))
    obj.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
    return obj

def begin(species, x):
    global current_collection, current_root
    current_collection = bpy.data.collections.new(species)
    family.children.link(current_collection)
    current_root = bpy.data.objects.new(species + '_Root', None)
    current_collection.objects.link(current_root)
    current_root.location = (x, 0, 0)
    current_root.rotation_euler.z = math.radians(-8)
    current_root['species'] = species
    current_root['front_axis'] = '-Y'
    current_root['finish'] = 'Geometry only - assign colors in Roblox Studio'
    roots[species] = current_root

def feet4(prefix, x=.57, ys=(-.66,.68), width=.36, depth=.47, height=.32):
    for i, y in enumerate(ys):
        for side in (-1,1):
            box(f'{prefix}_Foot_{i}_{side}', (side*x,y,height/2), (width,depth,height))

begin('Mouse', -5.4)
box('Mouse_Body', (0,.25,.89), (1.62,1.85,1.14))
box('Mouse_Head', (0,-.77,1.39), (1.52,1.04,1.25))
feet4('Mouse', .55, (-.66,.82), .35,.46,.35)
ear = [(-.39,-.28),(-.39,.24),(-.22,.43),(.22,.43),(.39,.24),(.39,-.28),(.22,-.43),(-.22,-.43)]
for side in (-1,1):
    e = panel(f'Mouse_Ear_{side}', ear, .20, (side*.63,-.58,2.16))
    e.rotation_euler.y = side*math.radians(12)
box('Mouse_Muzzle', (0,-1.355,1.13), (.74,.23,.43))
tail = [(0,1.12,.72),(0,1.59,.63),(.30,1.99,.52),(.81,2.15,.46),(1.25,1.94,.46),(1.33,1.56,.53)]
for i,(a,b) in enumerate(zip(tail,tail[1:])):
    rod(f'Mouse_Tail_{i+1:02}',a,b,.13)

begin('Hedgehog', -1.8)
box('Hedgehog_Body', (0,.27,.87), (1.73,1.84,1.15))
box('Hedgehog_Head', (0,-.80,1.08), (1.43,.87,1.11))
feet4('Hedgehog',.58,(-.71,.85),.37,.46,.30)
box('Hedgehog_Muzzle_Base', (0,-1.29,.93), (.79,.26,.40))
box('Hedgehog_Muzzle_Tip', (0,-1.46,.95), (.40,.21,.29))
for side in (-1,1):
    panel(f'Hedgehog_Ear_{side}', [(-.18,-.17),(-.18,.13),(-.09,.22),(.12,.22),(.19,.12),(.19,-.17)], .17,(side*.55,-.69,1.69))
for row,y in enumerate((-.40,.04,.48,.92)):
    for col,x in enumerate((-.63,-.21,.21,.63)):
        h = .30 if col in (0,3) else .39
        verts=[(-.19,-.19,0),(.19,-.19,0),(.19,.19,0),(-.19,.19,0),(0,.17,h)]
        mesh(f'Hedgehog_Quill_Top_{row}_{col}',verts,[(0,3,2,1),(0,1,4),(1,2,4),(2,3,4),(3,0,4)],(x,y,1.43))
for side in (-1,1):
    for row,y in enumerate((-.28,.20,.68,1.04)):
        for level,z in enumerate((.74,1.15)):
            verts=[(0,-.18,-.18),(0,.18,-.18),(0,.18,.18),(0,-.18,.18),(side*.29,.15,.05)]
            fs=[(0,1,2,3),(0,4,1),(1,4,2),(2,4,3),(3,4,0)]
            if side == 1:
                fs=[tuple(reversed(f)) for f in fs]
            mesh(f'Hedgehog_Quill_Side_{side}_{row}_{level}',verts,fs,(side*.85,y,z))

begin('Duckling', 1.8)
box('Duckling_Body',(0,.23,.92),(1.57,1.66,1.19))
box('Duckling_Head',(0,-.62,1.63),(1.49,1.07,1.22))
box('Duckling_Bill_Upper',(0,-1.355,1.35),(.99,.48,.20))
box('Duckling_Bill_Lower',(0,-1.33,1.20),(.88,.42,.10))
for side in (-1,1):
    verts=[(-.30,-.43,-.11),(.30,-.43,-.11),(.24,.22,-.11),(-.23,.22,-.11),
           (-.30,-.43,.11),(.30,-.43,.11),(.24,.22,.11),(-.23,.22,.11)]
    mesh(f'Duckling_Webbed_Foot_{side}',verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],(side*.45,-.34,.11))
    box(f'Duckling_Leg_{side}',(side*.45,-.15,.32),(.22,.25,.28))
    wing = panel(f'Duckling_Wing_{side}',[(-.54,-.26),(-.54,.19),(-.30,.33),(.29,.33),(.53,.11),(.53,-.08),(.28,-.08),(.28,-.26)],.17,(side*.84,.26,1.02))
    wing.rotation_euler.z = math.pi/2
box('Duckling_Tail_Base',(0,1.12,1.16),(.65,.37,.40))
box('Duckling_Tail_Tip',(0,1.33,1.33),(.46,.25,.27))
box('Duckling_Crown_Step',(0,-.48,2.285),(.49,.38,.17))

begin('Frog',5.4)
box('Frog_Body',(0,.15,.79),(1.81,1.65,1.02))
box('Frog_Head',(0,-.61,1.15),(1.91,.85,.86))
for side in (-1,1):
    box(f'Frog_Eye_Bump_{side}',(side*.60,-.68,1.71),(.60,.66,.61))
    box(f'Frog_Hind_Thigh_{side}',(side*1.04,.64,.49),(.62,.85,.62))
    box(f'Frog_Hind_Shin_{side}',(side*1.12,.07,.24),(.37,.86,.35))
    box(f'Frog_Front_Leg_{side}',(side*.64,-.66,.40),(.31,.38,.62))
    for toe in (-1,0,1):
        box(f'Frog_Front_Toe_{side}_{toe}',(side*.66+toe*.16,-1.0,.10),(.15,.44,.20))
        box(f'Frog_Back_Toe_{side}_{toe}',(side*1.10+toe*.18,-.39,.10),(.17,.42,.20))

cam_data = bpy.data.cameras.new('Animals_Preview_Camera')
cam = bpy.data.objects.new('Animals_Preview_Camera',cam_data)
stage.objects.link(cam)
cam.location=(6.5,-20,11.5)
target=Vector((0,.2,1.15))
cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
cam_data.type='ORTHO'
cam_data.ortho_scale=15.1
scene.camera=cam
scene.render.engine='BLENDER_WORKBENCH'
scene.render.resolution_x=2000
scene.render.resolution_y=900
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=True
scene.display.shading.light='STUDIO'
scene.display.shading.show_shadows=True
scene.display.shading.show_cavity=True
scene.display.shading.cavity_type='BOTH'
scene.display.shading.curvature_ridge_factor=1.3
scene.display.shading.curvature_valley_factor=1.2
scene.display.shading.cavity_ridge_factor=1.2
scene.display.shading.cavity_valley_factor=1.2
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.shading.type='SOLID'
            area.spaces.active.shading.show_cavity=True
            area.spaces.active.shading.cavity_type='BOTH'
            area.spaces.active.region_3d.view_perspective='CAMERA'
print('Created four geometry-only blockouts. Materials:',sum(len(o.data.materials) for o in family.all_objects if o.type=='MESH'))

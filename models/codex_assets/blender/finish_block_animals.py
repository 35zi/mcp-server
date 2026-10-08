from pathlib import Path
import bpy, bmesh, math, os
from mathutils import Vector
OUTPUT = str(Path(os.environ.get('CODEX_ASSET_OUTPUT', Path(__file__).resolve().parents[1] / 'assets')) / 'block_animals')
scene = bpy.context.scene
family = bpy.data.collections['Block Animals']
roots = {s:bpy.data.objects[s+'_Root'] for s in ('Mouse','Hedgehog','Duckling','Frog')}
current_collection = None
current_root = None
source = open(str(Path(__file__).with_name('create_block_animals.py')),encoding='utf-8').read()
exec(source[source.index('def mesh('):source.index("begin('Mouse', -5.4)")])
ear = [(-.39,-.28),(-.39,.24),(-.22,.43),(.22,.43),(.39,.24),(.39,-.28),(.22,-.43),(-.22,-.43)]

def choose(species):
    global current_collection, current_root
    current_collection=bpy.data.collections[species]
    current_root=roots[species]

def eyes(species, x, y, z, width=.22, height=.33):
    for side in (-1,1):
        box(f'{species}_Eye_{side}',(side*x,y,z),(width,.055,height))

choose('Mouse')
eyes('Mouse',.43,-1.313,1.51,.22,.33)
for side in (-1,1):
    inner=panel(f'Mouse_Inner_Ear_{side}',[(x*.68,z*.68) for x,z in ear],.035,(0,0,0))
    outer=bpy.data.objects[f'Mouse_Ear_{side}']
    inner.rotation_euler=outer.rotation_euler
    inner.location=outer.location + outer.rotation_euler.to_matrix() @ Vector((0,-.116,0))
    box(f'Mouse_Cheek_{side}',(side*.56,-1.31,1.23),(.20,.048,.115))
    for level in (-1,1):
        rod(f'Mouse_Whisker_{side}_{level}',(side*.34,-1.49,1.16+level*.04),(side*.77,-1.39,1.16+level*.12),.035)
    box(f'Mouse_Tooth_{side}',(side*.081,-1.411,.869),(.135,.075,.15))
box('Mouse_Nose',(0,-1.51,1.225),(.23,.085,.19))
box('Mouse_Mouth',(0,-1.493,1.073),(.065,.055,.14))

choose('Hedgehog')
eyes('Hedgehog',.425,-1.251,1.19,.21,.29)
box('Hedgehog_Nose',(0,-1.594,1.02),(.24,.065,.205))
box('Hedgehog_Mouth',(0,-1.578,.859),(.058,.03,.10))
for side in (-1,1):
    box(f'Hedgehog_Inner_Ear_{side}',(side*.55,-.79,1.73),(.18,.035,.21))

choose('Duckling')
eyes('Duckling',.43,-1.185,1.75,.22,.34)
for side in (-1,1):
    box(f'Duckling_Bill_Nostril_{side}',(side*.205,-1.485,1.458),(.075,.105,.026))
    box(f'Duckling_Wing_Feather_{side}',(side*.944,.40,.945),(.046,.37,.065))

choose('Frog')
for side in (-1,1):
    box(f'Frog_Eye_Panel_{side}',(side*.60,-1.038,1.737),(.46,.054,.43))
    box(f'Frog_Pupil_{side}',(side*.60,-1.085,1.753),(.185,.04,.30))
    box(f'Frog_Nostril_{side}',(side*.195,-1.057,1.378),(.055,.035,.055))
    box(f'Frog_Smile_Corner_{side}',(side*.48,-1.07,1.128),(.055,.045,.12))
box('Frog_Smile',(0,-1.07,1.075),(.95,.045,.055))
box('Frog_Belly_Panel',(0,-.713,.58),(1.01,.049,.38))

for obj in family.all_objects:
    if obj.type=='MESH':
        bm=bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
        obj['color_in_studio']=True

scene.camera.location=(5,-21,9.0)
scene.camera.rotation_euler=(Vector((0,.2,1.13))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera.data.ortho_scale=15.0
scene.render.filepath=os.path.join(OUTPUT,'animals_geometry_preview.png')
for species,root in roots.items():
    old_location=root.location.copy()
    old_rotation=root.rotation_euler.copy()
    try:
        root.location=(0,0,0)
        root.rotation_euler=(0,0,0)
        bpy.context.view_layer.update()
        bpy.ops.object.select_all(action='DESELECT')
        for obj in bpy.data.collections[species].objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active=root
        bpy.ops.export_scene.fbx(filepath=os.path.join(OUTPUT,species.lower()+'.fbx'),use_selection=True,object_types={'EMPTY','MESH'},axis_forward='-Z',axis_up='Y',bake_anim=False,add_leaf_bones=False)
    finally:
        root.location=old_location
        root.rotation_euler=old_rotation
        bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for root in roots.values():
    root.select_set(True)
bpy.context.view_layer.objects.active=roots['Mouse']
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUTPUT,'mouse_hedgehog_duckling_frog.blend'))
if os.environ.get('CODEX_ASSET_SKIP_RENDER') != '1':
    bpy.ops.render.render(write_still=True)
print('Saved source. Geometry objects:',sum(o.type=='MESH' for o in family.all_objects))
print('Material slots:',sum(len(o.data.materials) for o in family.all_objects if o.type=='MESH'))

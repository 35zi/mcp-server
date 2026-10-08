from pathlib import Path
import bpy,bmesh,math,os,json
from mathutils import Vector
OUTPUT = str(Path(os.environ.get('CODEX_ASSET_OUTPUT', Path(__file__).resolve().parents[1] / 'assets')) / 'desert_animals')
scene=bpy.context.scene
family=bpy.data.collections['Desert Animals']
roots={s:bpy.data.objects[s+'_Root'] for s in ('Scorpion','Spider','Camel','Vulture')}
source=open(str(Path(__file__).with_name('create_desert_animals.py')),encoding='utf-8').read()
helpers=source[source.index('source=open('):source.index("begin('Scorpion',-6.25)")]
exec(helpers)

def choose(species):
    global current_collection,current_root
    current_collection=bpy.data.collections[species]
    current_root=roots[species]

choose('Scorpion')
for side in (-1,1):
    box(f'Scorpion_Eye_{side}',(side*0.29,-1.057,0.76),(0.17,0.05,0.21))
    box(f'Scorpion_Mandible_{side}',(side*0.15,-1.078,0.54),(0.17,0.16,0.15))
    box(f'Scorpion_Eye_Small_{side}',(side*0.47,-1.055,0.79),(0.075,0.043,0.095))

choose('Spider')
for side in (-1,1):
    box(f'Spider_Eye_Main_{side}',(side*0.27,-1.17,1.05),(0.24,0.055,0.28))
    box(f'Spider_Eye_Outer_{side}',(side*0.56,-1.166,0.96),(0.12,0.046,0.17))
    box(f'Spider_Eye_Top_{side}',(side*0.16,-1.169,1.245),(0.10,0.046,0.11))
    box(f'Spider_Fang_Base_{side}',(side*0.19,-1.19,0.67),(0.16,0.17,0.22))
    panel(f'Spider_Fang_Tip_{side}',[(-0.08,0.10),(0.08,0.10),(0.05,-0.12),(-0.03,-0.18),(-0.08,-0.04)],0.13,(side*0.19,-1.19,0.52))
box('Spider_Abdomen_Panel',(0,0.39,1.607),(0.94,1.04,0.055))

choose('Camel')
for side in (-1,1):
    box(f'Camel_Eye_{side}',(side*0.335,-1.955,2.565),(0.17,0.045,0.23))
    box(f'Camel_Nostril_{side}',(side*0.225,-2.196,2.36),(0.095,0.045,0.11))
    ear=bpy.data.objects[f'Camel_Ear_{side}']
    inner=panel(f'Camel_Inner_Ear_{side}',[(-0.064,-0.10),(-0.08,0.09),(-0.025,0.16),(0.054,0.14),(0.072,-0.04),(0.048,-0.11)],0.025,(0,0,0))
    inner.rotation_euler=ear.rotation_euler
    inner.location=ear.location + ear.rotation_euler.to_matrix() @ Vector((0,-0.099,0))
    for row,y in enumerate((-0.70,0.82)):
        for toe in (-1,1):
            box(f'Camel_Toe_{row}_{side}_{toe}',(side*0.55+toe*0.11,y-0.355,0.115),(0.18,0.04,0.16))
box('Camel_Lower_Lip',(0,-2.185,2.13),(0.64,0.055,0.08))

choose('Vulture')
for name in ('Vulture_Head','Vulture_Beak_Base','Vulture_Beak_Hook'):
    bpy.data.objects[name].location.z+=0.25
neck=bpy.data.objects['Vulture_Neck']
neck.location.z=1.93
for v in neck.data.vertices:v.co.z*=1.10/0.95
neck.data.update()
for side in (-1,1):
    box(f'Vulture_Eye_{side}',(side*0.285,-1.285,2.54),(0.19,0.045,0.245))
    brow=box(f'Vulture_Brow_{side}',(side*0.285,-1.289,2.685),(0.24,0.055,0.065))
    brow.rotation_euler.y=side*0.14
    box(f'Vulture_Collar_Tuft_Front_{side}',(side*0.29,-0.904,1.64),(0.21,0.13,0.25))
    box(f'Vulture_Collar_Tuft_Side_{side}',(side*0.54,-0.47,1.64),(0.17,0.27,0.22))
    for i in range(3):
        z=1.38-i*0.16
        side_panel(f'Vulture_Wing_Feather_{side}_{i}',[(-0.21,z),(0.63,z-0.20),(0.70,z-0.28),(0.61,z-0.31),(-0.21,z-0.065)],0.028,(side*0.928,0,0))

report={}
for species,root in roots.items():
    objects=[o for o in bpy.data.collections[species].objects if o.type=='MESH']
    info={'parts':len(objects),'triangles':0,'materials':0,'non_manifold':[]}
    for obj in objects:
        obj.data.materials.clear()
        obj['color_in_studio']=True
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bad=sum(not e.is_manifold for e in bm.edges)
        if bad:info['non_manifold'].append((obj.name,bad))
        bm.to_mesh(obj.data);bm.free()
        obj.data.update()
        info['triangles']+=sum(len(p.vertices)-2 for p in obj.data.polygons)
        info['materials']+=len(obj.data.materials)
    assert not info['non_manifold'],info
    original_location=root.location.copy()
    original_rotation=root.rotation_euler.copy()
    try:
        root.location=(0,0,0);root.rotation_euler=(0,0,0)
        bpy.context.view_layer.update()
        corners=[obj.matrix_world@Vector(v) for obj in objects for v in obj.bound_box]
        info['dimensions_blender_units']=[round(max(p[i] for p in corners)-min(p[i] for p in corners),3) for i in range(3)]
        bpy.ops.object.select_all(action='DESELECT')
        root.select_set(True)
        for obj in objects:obj.select_set(True)
        bpy.context.view_layer.objects.active=root
        filename=species.lower()+'.fbx'
        bpy.ops.export_scene.fbx(filepath=os.path.join(OUTPUT,filename),use_selection=True,object_types={'EMPTY','MESH'},axis_forward='-Z',axis_up='Y',bake_anim=False,add_leaf_bones=False)
        info['file']=filename
    finally:
        root.location=original_location;root.rotation_euler=original_rotation
        bpy.context.view_layer.update()
    report[species]=info
with open(os.path.join(OUTPUT,'mesh_details.json'),'w',encoding='utf-8') as f:json.dump(report,f,indent=2)
bpy.ops.object.select_all(action='DESELECT')
for root in roots.values():root.select_set(True)
bpy.context.view_layer.objects.active=roots['Scorpion']
scene.render.filepath=os.path.join(OUTPUT,'desert_animals_geometry_preview.png')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUTPUT,'scorpion_spider_camel_vulture.blend'))
if os.environ.get('CODEX_ASSET_SKIP_RENDER') != '1':
    bpy.ops.render.render(write_still=True)
print(json.dumps(report))

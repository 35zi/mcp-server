from pathlib import Path
import bpy,bmesh,math,os,json
from mathutils import Vector
OUTPUT = str(Path(os.environ.get('CODEX_ASSET_OUTPUT', Path(__file__).resolve().parents[1] / 'assets')) / 'three_weapons')
scene=bpy.context.scene
family=bpy.data.collections['Three Weapons']
roots={s:bpy.data.objects[s+'_Root'] for s in ('Shotgun','BoltSniper','AutomaticRifle')}
source=open(str(Path(__file__).with_name('create_three_weapons.py')),encoding='utf-8').read()
exec(source[source.index('def mesh('):source.index("begin('Shotgun',8.0)")])

def choose(s):
    global current,root
    current=bpy.data.collections[s]
    root=roots[s]

choose('Shotgun')
for side in (-1,1):
    profile(f'Stock_Panel_{side}',[(-1.34,0.91),(-1.68,0.87),(-2.70,1.18),(-2.70,0.23),(-1.70,0.46),(-1.31,0.49)],0.032,(0,side*0.262,0))
box('Ejection_Port_Inset',(.52,-.333,1.04),(.61,.042,.22))
box('Loading_Port_Inset',(.38,0,.553),(.54,.35,.035))
box('Safety_Switch',(-.18,-.354,.84),(.14,.08,.10))

choose('BoltSniper')
for side in (-1,1):
    profile(f'Stock_Panel_{side}',[(-1.48,1.04),(-2.75,1.03),(-2.75,0.30),(-1.70,0.50),(-1.40,0.63)],0.032,(0,side*0.282,0))
box('Receiver_Side_Plate',(.15,-.313,1.02),(.75,.038,.23))
box('Bolt_Ejection_Window',(0.62,-0.316,1.18),(0.40,0.04,0.14))
box('Magazine_Floorplate',(.66,0,.36),(.55,.46,.075))

choose('AutomaticRifle')
for side in (-1,1):
    profile(f'Stock_Panel_{side}',[(-1.45,.99),(-2.64,1.00),(-2.64,.43),(-1.46,.73)],.032,(0,side*.258,0))
    for i in range(3):
        offset=i*.13
        profile(f'Magazine_Rib_{side}_{i}',[(0.27+offset,0.56),(0.315+offset,0.56),(0.40+offset,-0.07),(0.64+offset,-0.61),(0.59+offset,-0.63),(0.35+offset,-0.08)],0.028,(0,side*0.227,0))
box('Ejection_Port_Inset',(0.45,-0.308,1.19),(0.60,0.04,0.18))
profile('Selector_Switch',[(-.25,1.23),(-.23,1.27),(.15,1.06),(.12,1.00)],.07,(0,-.33,0))
box('Magazine_Floorplate',(0.92,0,-0.72),(0.53,0.49,0.09)).rotation_euler.y=math.radians(-25)

report={}
for species,root in roots.items():
    objects=[o for o in bpy.data.collections[species].objects if o.type=='MESH']
    info={'parts':len(objects),'triangles':0,'materials':0,'non_manifold':[]}
    for obj in objects:
        obj.data.materials.clear()
        obj['color_in_studio']=True
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        n=sum(not e.is_manifold for e in bm.edges)
        if n:info['non_manifold'].append((obj.name,n))
        bm.to_mesh(obj.data);bm.free()
        info['triangles']+=sum(len(p.vertices)-2 for p in obj.data.polygons)
        info['materials']+=len(obj.data.materials)
    assert not info['non_manifold'],info
    original_location=root.location.copy()
    try:
        root.location=(0,0,0)
        bpy.context.view_layer.update()
        bpy.ops.object.select_all(action='DESELECT')
        root.select_set(True)
        for obj in objects:obj.select_set(True)
        bpy.context.view_layer.objects.active=root
        path=os.path.join(OUTPUT,{'Shotgun':'shotgun','BoltSniper':'bolt_action_sniper','AutomaticRifle':'automatic_rifle'}[species]+'.fbx')
        bpy.ops.export_scene.fbx(filepath=path,use_selection=True,object_types={'EMPTY','MESH'},axis_forward='-Z',axis_up='Y',bake_anim=False,add_leaf_bones=False)
        info['file']=path
    finally:
        root.location=original_location
        bpy.context.view_layer.update()
    report[species]=info
bpy.ops.object.select_all(action='DESELECT')
for root in roots.values():root.select_set(True)
bpy.context.view_layer.objects.active=roots['Shotgun']
scene.render.filepath=os.path.join(OUTPUT,'three_weapons_geometry_preview.png')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUTPUT,'shotgun_bolt_sniper_automatic_rifle.blend'))
if os.environ.get('CODEX_ASSET_SKIP_RENDER') != '1':
    bpy.ops.render.render(write_still=True)
print(json.dumps(report))

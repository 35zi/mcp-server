from pathlib import Path
import bpy,bmesh,math,os,json
from mathutils import Vector
OUTPUT = str(Path(os.environ.get('CODEX_ASSET_OUTPUT', Path(__file__).resolve().parents[1] / 'assets')) / 'revolver')
scene=bpy.context.scene
parts=bpy.data.collections['Revolver']
root=bpy.data.objects['Revolver_Root']
source=open(str(Path(__file__).with_name('create_block_revolver.py')),encoding='utf-8').read()
exec(source[source.index('def mesh('):source.index('grip=[')])

panel=[(-1.07,1.12),(-.77,1.02),(-.89,.77),(-1.15,.33),(-1.17,.19),(-1.49,.19),(-1.54,.30),(-1.38,.99),(-1.36,1.12)]
for side in (-1,1):
    profile(f'Revolver_Grip_Panel_{side}',panel,.040,(0,side*.255,0))
    for i,(x,z) in enumerate(((-1.14,.89),(-1.31,.34))):
        screw=cylinder(f'Revolver_Grip_Screw_{side}_{i}',-.018,.018,.055,8)
        screw.rotation_euler.z=math.pi/2
        screw.location=(x,side*.293,z)

box('Revolver_Front_Sight',(2.40,0,2.205),(.25,.115,.165))
box('Revolver_Rear_Sight_Base',(-.58,0,2.275),(.23,.40,.08))
for side in (-1,1):
    box(f'Revolver_Rear_Sight_Notch_{side}',(-.58,side*.148,2.335),(.23,.105,.09))
    box(f'Revolver_Cylinder_Release_{side}',(-.78,side*.367,1.72),(.185,.07,.135))
    profile(f'Revolver_Frame_Side_Plate_{side}',[(-.94,1.43),(-.73,1.43),(-.64,1.30),(-.66,1.15),(-1.01,1.15),(-1.06,1.29)],.035,(0,side*.305,0))
cylinder('Revolver_Ejector_Rod',.73,2.24,.055,8,(-.216,1.62))
cylinder('Revolver_Ejector_End',2.14,2.26,.078,8,(-.216,1.62))

drum=bpy.data.objects['Revolver_Cylinder']
for i in range(6):
    a=math.pi/2 + math.tau*i/6
    cutter=cylinder(f'_Chamber_Cutter_{i}',-.65,.65,.088,12,(.295*math.cos(a),1.63+.295*math.sin(a)))
    mod=drum.modifiers.new('Chamber Opening','BOOLEAN')
    mod.operation='DIFFERENCE'
    mod.solver='EXACT'
    mod.object=cutter
    bpy.context.view_layer.objects.active=drum
    bpy.ops.object.modifier_apply(modifier=mod.name)
    data=cutter.data
    bpy.data.objects.remove(cutter,do_unlink=True)
    bpy.data.meshes.remove(data)

report={'parts':0,'triangles':0,'material_slots':0,'non_manifold':[]}
for obj in parts.all_objects:
    if obj.type!='MESH':continue
    obj.data.materials.clear()
    obj['color_in_studio']=True
    report['parts']+=1
    report['material_slots']+=len(obj.data.materials)
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    non_manifold=sum(not e.is_manifold for e in bm.edges)
    if non_manifold:report['non_manifold'].append((obj.name,non_manifold))
    bm.to_mesh(obj.data);bm.free()
    report['triangles']+=sum(len(p.vertices)-2 for p in obj.data.polygons)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts.all_objects:obj.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.fbx(filepath=os.path.join(OUTPUT,'revolver.fbx'),use_selection=True,object_types={'EMPTY','MESH'},axis_forward='-Z',axis_up='Y',bake_anim=False,add_leaf_bones=False)
bpy.ops.object.select_all(action='DESELECT')
root.select_set(True)
bpy.context.view_layer.objects.active=root
scene.render.filepath=os.path.join(OUTPUT,'revolver_geometry_preview.png')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUTPUT,'revolver.blend'))
print(json.dumps(report))

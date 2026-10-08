from pathlib import Path
import bpy, bmesh, math, os, json
from mathutils import Vector

OUTPUT = str(Path(os.environ.get('CODEX_ASSET_OUTPUT', Path(__file__).resolve().parents[1] / 'assets')) / 'three_weapons')
os.makedirs(OUTPUT,exist_ok=True)
scene=bpy.data.scenes.new('Shotgun Sniper Automatic - Geometry Only')
bpy.context.window.scene=scene
family=bpy.data.collections.new('Three Weapons')
scene.collection.children.link(family)
stage=bpy.data.collections.new('Three Weapons Preview')
scene.collection.children.link(stage)
roots={}
current=None
root=None

def begin(species,z):
    global current,root
    current=bpy.data.collections.new(species)
    family.children.link(current)
    root=bpy.data.objects.new(species+'_Root',None)
    current.objects.link(root)
    root.location=(0,0,z)
    root['barrel_direction']='+X'
    root['finish']='Geometry only. Color named pieces in Roblox Studio.'
    roots[species]=root

def mesh(name,verts,faces,location=(0,0,0)):
    data=bpy.data.meshes.new(name+'_Mesh')
    data.from_pydata(verts,[],faces)
    data.update()
    bm=bmesh.new();bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(data);bm.free()
    obj=bpy.data.objects.new(root.name.replace('_Root','')+'_'+name,data)
    current.objects.link(obj)
    obj.parent=root
    obj.location=location
    return obj

def box(name,location,size):
    x,y,z=[v/2 for v in size]
    return mesh(name,[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)],
                [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],location)

def profile(name,points,thickness,location=(0,0,0)):
    n=len(points)
    verts=[(x,-thickness/2,z) for x,z in points]+[(x,thickness/2,z) for x,z in points]
    faces=[tuple(range(n)),tuple(range(2*n-1,n-1,-1))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    return mesh(name,verts,faces,location)

def cylinder(name,start,end,radius,sides=12,center=(0,0)):
    cy,cz=center
    verts=[(x,cy+radius*math.cos(math.tau*i/sides),cz+radius*math.sin(math.tau*i/sides)) for x in (start,end) for i in range(sides)]
    faces=[tuple(range(sides-1,-1,-1)),tuple(range(sides,2*sides))]
    faces.extend((i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides))
    return mesh(name,verts,faces)

def tube(name,start,end,radius,inner,sides=12,center=(0,0),end_radius=None):
    cy,cz=center
    rings=[(start,radius),(end,end_radius or radius),(start,inner),(end,inner)]
    verts=[(x,cy+r*math.cos(math.tau*i/sides),cz+r*math.sin(math.tau*i/sides)) for x,r in rings for i in range(sides)]
    faces=[]
    for i in range(sides):
        j=(i+1)%sides
        faces.extend([(i,j,sides+j,sides+i),(2*sides+i,3*sides+i,3*sides+j,2*sides+j),
                      (i,2*sides+i,2*sides+j,j),(sides+i,sides+j,3*sides+j,3*sides+i)])
    return mesh(name,verts,faces)

def link(name,start,end,radius,sides=8):
    a,b=Vector(start),Vector(end)
    obj=cylinder(name,-(b-a).length/2,(b-a).length/2,radius,sides)
    obj.location=(a+b)/2
    obj.rotation_euler=(b-a).to_track_quat('X','Z').to_euler()
    return obj

def frame(name,outer,inner,width):
    n=len(outer)
    verts=[(x,y,z) for y in (-width/2,width/2) for contour in (outer,inner) for x,z in contour]
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces.extend([(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),(i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)])
    return mesh(name,verts,faces)

def guard_and_trigger():
    frame('Trigger_Guard',[(-.45,.58),(.43,.58),(.53,.46),(.53,.04),(.41,-.08),(-.38,-.08),(-.52,.08),(-.52,.43)],
          [(-.34,.44),(.33,.44),(.38,.36),(.38,.12),(.31,.065),(-.30,.065),(-.375,.16),(-.375,.36)],.18)
    profile('Trigger',[(-.12,.59),(.01,.59),(-.01,.36),(-.15,.20),(-.10,.12),(-.22,.14),(-.27,.27),(-.14,.40)],.11)

begin('Shotgun',8.0)
stock=[(-.48,1.09),(-1.19,1.09),(-1.64,.99),(-2.69,1.34),(-2.91,1.29),(-2.91,.09),(-2.70,.02),(-1.65,.35),(-1.06,.40),(-.79,.68),(-.48,.75)]
profile('Stock_Core',stock,.49)
box('Receiver',(.30,0,.92),(1.61,.63,.69))
box('Receiver_Top',(.27,0,1.28),(1.50,.56,.08))
tube('Barrel',1.03,4.50,.175,.105,12,(0,1.10))
cylinder('Magazine_Tube',.93,4.07,.125,12,(0,.70))
box('Pump_Core',(2.10,0,.70),(1.35,.52,.44))
box('Pump_Upper',(2.10,0,.94),(1.21,.46,.12))
for i in range(7):
    box(f'Pump_Rib_{i:02}',(1.57+i*.177,0,.70),(.062,.575,.477))
box('Barrel_Band',(3.86,0,.90),(.17,.37,.47))
box('Front_Sight',(4.30,0,1.335),(.18,.11,.17))
box('Butt_Pad',(-2.965,0,.69),(.13,.57,1.20))
guard_and_trigger()

begin('BoltSniper',4.0)
stock=[(-.47,1.10),(-1.10,1.11),(-1.47,1.19),(-2.72,1.17),(-2.97,1.08),(-2.97,.22),(-2.73,.17),(-1.68,.39),(-1.25,.51),(-.78,.66),(-.47,.72)]
profile('Stock_Core',stock,.53)
profile('Pistol_Grip',[(-.50,.69),(-.16,.61),(-.26,.36),(-.46,-.36),(-.83,-.29),(-.62,.35)],.42)
box('Butt_Pad',(-3.02,0,.645),(.13,.60,.92))
box('Cheek_Rest',(-2.06,0,1.245),(1.18,.55,.18))
box('Receiver',(.25,0,.98),(1.42,.59,.49))
cylinder('Bolt_Housing',-.48,1.03,.235,12,(0,1.11))
box('Forestock',(1.13,0,.80),(1.40,.49,.25))
tube('Heavy_Barrel',.95,5.16,.145,.081,12,(0,1.11))
tube('Muzzle_Brake',4.85,5.28,.225,.10,8,(0,1.11))
box('Scope_Rail',(.38,0,1.395),(1.90,.36,.10))
for i,x in enumerate((-.15,.88)):
    box(f'Scope_Mount_Base_{i}',(x,0,1.51),(.20,.43,.18))
    tube(f'Scope_Mount_Ring_{i}',x-.105,x+.105,.228,.177,12,(0,1.73))
cylinder('Scope_Main_Tube',-.62,1.44,.177,12,(0,1.73))
tube('Scope_Eyepiece',-.99,-.60,.24,.17,12,(0,1.73))
cylinder('Scope_Rear_Lens',-.981,-.96,.168,12,(0,1.73))
tube('Scope_Objective_Bell',1.35,1.90,.18,.148,12,(0,1.73),.315)
tube('Scope_Objective_Rim',1.89,2.05,.325,.265,12,(0,1.73))
cylinder('Scope_Front_Lens',2.02,2.035,.263,12,(0,1.73))
link('Scope_Top_Turret',(.36,0,1.78),(.36,0,2.08),.13,8)
link('Scope_Side_Turret',(.36,-.16,1.73),(.36,-.31,1.73),.12,8)
link('Bolt_Handle_Stem',(.72,-.16,1.13),(.72,-.52,.97),.078,8)
link('Bolt_Handle_Drop',(.72,-.52,.97),(.72,-.61,.69),.080,8)
box('Bolt_Handle_Knob',(.72,-.62,.64),(.25,.24,.24))
box('Magazine',(.66,0,.52),(.49,.40,.28))
guard_and_trigger()

begin('AutomaticRifle',0.0)
profile('Stock_Core',[(-.64,1.27),(-1.09,1.27),(-1.34,1.11),(-2.65,1.13),(-2.80,1.03),(-2.80,.30),(-2.65,.26),(-1.35,.64),(-.93,.82),(-.64,.88)],.48)
box('Butt_Pad',(-2.86,0,.66),(.14,.55,.79))
box('Receiver',(.23,0,1.08),(1.70,.58,.63))
profile('Receiver_Cover',[(-.61,1.38),(-.54,1.53),(.86,1.53),(1.08,1.40),(1.08,1.38)],.50)
profile('Pistol_Grip',[(-.48,.80),(-.12,.76),(-.22,.43),(-.46,-.28),(-.82,-.18),(-.61,.43)],.39)
profile('Curved_Magazine',[(.18,.81),(.73,.81),(.77,.21),(.91,-.18),(1.14,-.61),(.67,-.82),(.46,-.43),(.30,-.06)],.43)
box('Magazine_Lip',(.45,0,.79),(.62,.50,.13))
box('Handguard_Core',(1.65,0,1.02),(1.28,.55,.47))
box('Handguard_Upper',(1.62,0,1.32),(1.14,.42,.15))
for i in range(4):
    box(f'Handguard_Rib_{i}',(1.27+i*.23,0,1.02),(.04,.60,.50))
tube('Barrel',2.02,4.23,.125,.072,12,(0,1.14))
cylinder('Gas_Tube',1.0,3.16,.088,8,(0,1.43))
box('Gas_Block',(3.06,0,1.30),(.25,.28,.50))
tube('Muzzle_Brake',3.98,4.35,.19,.083,8,(0,1.14))
profile('Front_Sight_Base',[(2.88,1.24),(3.18,1.24),(3.13,1.80),(3.01,1.85),(2.94,1.80)],.16)
frame('Front_Sight_Hood',[(2.91,1.71),(3.16,1.71),(3.16,1.98),(2.91,1.98)],[(2.97,1.77),(3.10,1.77),(3.10,1.92),(2.97,1.92)],.28)
box('Rear_Sight_Base',(.25,0,1.62),(.40,.32,.12))
for side in (-1,1):box(f'Rear_Sight_Notch_{side}',(.25,side*.13,1.72),(.23,.06,.17))
box('Charging_Handle',(.51,-.43,1.34),(.40,.31,.10))
guard_and_trigger()

cam_data=bpy.data.cameras.new('ThreeWeapons_Camera')
cam=bpy.data.objects.new('ThreeWeapons_Camera',cam_data)
stage.objects.link(cam)
cam.location=(8,-25,12)
cam.rotation_euler=(Vector((.7,0,4.60))-cam.location).to_track_quat('-Z','Y').to_euler()
cam_data.type='ORTHO'
cam_data.ortho_scale=12.5
scene.camera=cam
scene.render.engine='BLENDER_WORKBENCH'
scene.render.resolution_x=1500
scene.render.resolution_y=1500
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=True
scene.display.shading.light='STUDIO'
scene.display.shading.show_shadows=True
scene.display.shading.show_cavity=True
scene.display.shading.cavity_type='BOTH'
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='SOLID'
            area.spaces.active.shading.show_cavity=True
            area.spaces.active.shading.cavity_type='BOTH'
            area.spaces.active.region_3d.view_perspective='CAMERA'
print('Created three weapon blockouts, geometry only.')

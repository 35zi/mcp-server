from pathlib import Path
import bpy,bmesh,math,os,json
from mathutils import Vector

OUTPUT = str(Path(os.environ.get('CODEX_ASSET_OUTPUT', Path(__file__).resolve().parents[1] / 'assets')) / 'desert_animals')
os.makedirs(OUTPUT,exist_ok=True)
scene=bpy.data.scenes.new('Scorpion Spider Camel Vulture - Geometry Only')
bpy.context.window.scene=scene
family=bpy.data.collections.new('Desert Animals')
scene.collection.children.link(family)
stage=bpy.data.collections.new('Desert Animal Preview')
scene.collection.children.link(stage)
roots={}
current_collection=None
current_root=None
source=open(str(Path(__file__).with_name('create_block_animals.py')),encoding='utf-8').read()
exec(source[source.index('def mesh('):source.index("begin('Mouse', -5.4)")])

def horizontal(name,points,height,location):
    n=len(points)
    verts=[(x,y,z) for z in (-height/2,height/2) for x,y in points]
    faces=[tuple(range(n)),tuple(range(2*n-1,n-1,-1))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    return mesh(name,verts,faces,location)

def side_panel(name,points,width,location):
    n=len(points)
    verts=[(x,y,z) for x in (-width/2,width/2) for y,z in points]
    faces=[tuple(range(n)),tuple(range(2*n-1,n-1,-1))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    return mesh(name,verts,faces,location)

begin('Scorpion',-6.25)
box('Scorpion_Body',(0,0.20,0.61),(1.38,1.70,0.58))
box('Scorpion_Head',(0,-0.69,0.65),(1.16,0.68,0.54))
for row,y in enumerate((-0.44,-0.06,0.32,0.70)):
    for side in (-1,1):
        delta=(-0.44,-0.17,0.18,0.47)[row]
        a=(side*0.62,y,0.58)
        b=(side*1.02,y+delta*0.45,0.61)
        c=(side*1.40,y+delta,0.14)
        rod(f'Scorpion_Leg_{side}_{row}_Upper',a,b,0.16)
        rod(f'Scorpion_Leg_{side}_{row}_Lower',b,c,0.13)
        box(f'Scorpion_Foot_{side}_{row}',(c[0],c[1]-0.04,0.075),(0.23,0.27,0.15))
    box(f'Scorpion_Back_Plate_{row}',(0,y,0.925),(1.15,0.27,0.10))
for side in (-1,1):
    rod(f'Scorpion_Claw_Arm_{side}',(side*0.54,-0.69,0.62),(side*0.98,-1.10,0.64),0.25)
    rod(f'Scorpion_Claw_Wrist_{side}',(side*0.98,-1.10,0.64),(side*1.12,-1.48,0.69),0.27)
    claw=horizontal(f'Scorpion_Claw_Palm_{side}',[(-0.28,0.23),(0.28,0.23),(0.33,-0.16),(0.24,-0.31),(-0.23,-0.31),(-0.33,-0.14)],0.31,(side*1.12,-1.58,0.70))
    for finger in (-1,1):
        base=(side*1.12+finger*0.21,-1.76,0.70)
        tip=(side*1.12+finger*0.10,-2.21,0.74)
        rod(f'Scorpion_Pincer_{side}_{finger}',base,tip,0.17)
tail=[(0,0.91,0.64),(0,1.24,0.88),(0,1.44,1.24),(0,1.43,1.66),(0,1.18,2.00),(0,0.80,2.19),(0,0.43,2.12)]
for i,(a,b) in enumerate(zip(tail,tail[1:])):
    rod(f'Scorpion_Tail_{i:02}',a,b,0.30-i*0.018)
stinger=side_panel('Scorpion_Stinger',[(0.08,0.12),(-0.14,0.05),(-0.32,-0.31),(-0.10,-0.22),(0.15,-0.08)],0.20,(0,0.39,2.05))

begin('Spider',-1.75)
box('Spider_Abdomen',(0,0.37,0.98),(1.68,1.82,1.20))
box('Spider_Head',(0,-0.73,0.94),(1.42,0.82,0.82))
for row,y in enumerate((-0.60,-0.12,0.43,0.95)):
    for side in (-1,1):
        delta=(-0.69,-0.26,0.27,0.68)[row]
        a=(side*0.67,y,0.95)
        b=(side*1.46,y+delta*0.55,1.16)
        c=(side*1.98,y+delta,0.12)
        rod(f'Spider_Leg_{side}_{row}_Upper',a,b,0.21)
        rod(f'Spider_Leg_{side}_{row}_Lower',b,c,0.18)
        box(f'Spider_Foot_{side}_{row}',(c[0],c[1],0.08),(0.24,0.24,0.16))

begin('Camel',2.40)
box('Camel_Body',(0,0.08,1.30),(1.62,2.16,1.18))
for row,y in enumerate((-0.70,0.82)):
    for side in (-1,1):
        box(f'Camel_Leg_{row}_{side}',(side*0.55,y,0.45),(0.34,0.42,0.90))
        box(f'Camel_Foot_{row}_{side}',(side*0.55,y-0.06,0.11),(0.45,0.56,0.22))
hump=[(-0.53,-0.40,1.84),(0.53,-0.40,1.84),(0.53,0.76,1.84),(-0.53,0.76,1.84),(-0.25,-0.23,2.54),(0.25,-0.23,2.54),(0.25,0.57,2.54),(-0.25,0.57,2.54)]
mesh('Camel_Hump',hump,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
rod('Camel_Neck',(0,-0.79,1.44),(0,-1.18,2.29),0.62,0.65)
box('Camel_Head',(0,-1.44,2.46),(1.07,0.98,0.75))
box('Camel_Muzzle',(0,-1.99,2.30),(0.82,0.36,0.44))
for side in (-1,1):
    ear=panel(f'Camel_Ear_{side}',[(-0.12,-0.21),(-0.15,0.13),(-0.06,0.25),(0.10,0.23),(0.15,-0.04),(0.10,-0.21)],0.17,(side*0.56,-1.24,2.71))
    ear.rotation_euler.y=side*0.22
rod('Camel_Tail_Base',(0,1.10,1.45),(0,1.35,1.10),0.12)
rod('Camel_Tail_End',(0,1.35,1.10),(0,1.48,0.67),0.11)
box('Camel_Tail_Tuft',(0,1.49,0.60),(0.20,0.22,0.27))

begin('Vulture',5.55)
box('Vulture_Body',(0,0.13,1.02),(1.55,1.57,1.30))
box('Vulture_Neck',(0,-0.52,1.82),(0.47,0.46,0.95))
box('Vulture_Collar',(0,-0.49,1.65),(0.98,0.78,0.25))
box('Vulture_Head',(0,-0.84,2.22),(1.04,0.84,0.75))
box('Vulture_Beak_Base',(0,-1.44,2.12),(0.51,0.43,0.27))
side_panel('Vulture_Beak_Hook',[(0.12,0.10),(-0.17,0.08),(-0.23,-0.29),(-0.12,-0.34),(0.04,-0.11),(0.14,-0.02)],0.35,(0,-1.65,2.06))
for side in (-1,1):
    wing=[(-0.57,1.50),(-0.26,1.69),(0.66,1.55),(0.97,1.11),(0.97,0.84),(0.74,0.84),(0.74,0.67),(0.43,0.67),(0.43,0.53),(-0.45,0.66),(-0.65,0.98)]
    side_panel(f'Vulture_Wing_{side}',wing,0.18,(side*0.82,0,0))
    box(f'Vulture_Leg_{side}',(side*0.43,-0.17,0.38),(0.22,0.24,0.42))
    for toe in (-1,0,1):
        box(f'Vulture_Toe_{side}_{toe}',(side*0.43+toe*0.13,-0.35,0.10),(0.12,0.50,0.20))
box('Vulture_Tail_Base',(0,1.01,0.81),(0.76,0.49,0.30))
box('Vulture_Tail_Tip',(0,1.30,0.67),(0.60,0.30,0.23))

cam_data=bpy.data.cameras.new('DesertAnimals_Camera')
cam=bpy.data.objects.new('DesertAnimals_Camera',cam_data)
stage.objects.link(cam)
cam.location=(7.0,-24.0,13.0)
cam.rotation_euler=(Vector((-0.4,-0.1,1.3))-cam.location).to_track_quat('-Z','Y').to_euler()
cam_data.type='ORTHO'
cam_data.ortho_scale=17.4
scene.camera=cam
scene.render.engine='BLENDER_WORKBENCH'
scene.render.resolution_x=2200
scene.render.resolution_y=1050
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
print('Four desert animal blockouts built with zero materials.')

from pathlib import Path
import bpy, bmesh, math, os
from mathutils import Vector

OUTPUT = str(Path(os.environ.get('CODEX_ASSET_OUTPUT', Path(__file__).resolve().parents[1] / 'assets')) / 'revolver')
os.makedirs(OUTPUT,exist_ok=True)
scene=bpy.data.scenes.new('Revolver - Geometry Only')
bpy.context.window.scene=scene
parts=bpy.data.collections.new('Revolver')
scene.collection.children.link(parts)
stage=bpy.data.collections.new('Revolver Preview')
scene.collection.children.link(stage)
root=bpy.data.objects.new('Revolver_Root',None)
parts.objects.link(root)
root['finish']='No materials or colors; finish in Roblox Studio'
root['barrel_direction']='+X'

def mesh(name,verts,faces,location=(0,0,0)):
    data=bpy.data.meshes.new(name+'_Mesh')
    data.from_pydata(verts,[],faces)
    data.update()
    obj=bpy.data.objects.new(name,data)
    parts.objects.link(obj)
    obj.parent=root
    obj.location=location
    bm=bmesh.new();bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(data);bm.free()
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

def tube(name,start,end,outer,inner,sides,center=(0,0),flutes=False):
    cy,cz=center
    verts=[]
    for x,radius in ((start,outer),(end,outer),(start,inner),(end,inner)):
        for i in range(sides):
            a=2*math.pi*i/sides
            r=radius
            if flutes and radius==outer:
                r-=.028*(.5+.5*math.cos(6*(a-math.pi/2)))**6
            verts.append((x,cy+r*math.cos(a),cz+r*math.sin(a)))
    faces=[]
    for i in range(sides):
        j=(i+1)%sides
        faces.extend([(i,j,j+sides,i+sides),(2*sides+i,3*sides+i,3*sides+j,2*sides+j),
                      (i,2*sides+i,2*sides+j,j),(sides+i,sides+j,3*sides+j,3*sides+i)])
    return mesh(name,verts,faces)

def cylinder(name,start,end,radius,sides,center=(0,0)):
    cy,cz=center
    verts=[(x,cy+radius*math.cos(2*math.pi*i/sides),cz+radius*math.sin(2*math.pi*i/sides)) for x in (start,end) for i in range(sides)]
    faces=[tuple(range(sides-1,-1,-1)),tuple(range(sides,2*sides))]
    faces.extend((i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides))
    return mesh(name,verts,faces)

def ring_profile(name,outer,inner,thickness):
    n=len(outer)
    verts=[(x,y,z) for y in (-thickness/2,thickness/2) for contour in (outer,inner) for x,z in contour]
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces.extend([(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),
                      (i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)])
    return mesh(name,verts,faces)

grip=[(-.99,1.30),(-.61,1.09),(-.67,.89),(-.99,.38),(-1.02,.07),(-1.61,.07),(-1.69,.24),(-1.50,.96),(-1.48,1.34)]
profile('Revolver_Grip_Core',grip,.48)
box('Revolver_Rear_Frame',(-.75,0,1.65),(.29,.68,1.00))
box('Revolver_Top_Strap',(.0,0,2.155),(1.52,.47,.16))
box('Revolver_Lower_Frame',(.02,0,1.12),(1.45,.50,.20))
box('Revolver_Front_Frame',(.69,0,1.665),(.24,.56,.93))
tube('Revolver_Cylinder',-.585,.565,.49,.068,72,(0,1.63),True)
tube('Revolver_Barrel',.71,2.62,.185,.10,8,(0,1.93))
box('Revolver_Barrel_Rib',(1.70,0,2.10),(1.88,.18,.075))
box('Revolver_Underlug',(1.55,0,1.69),(1.72,.30,.25))
outer=[(-.69,1.16),(.42,1.16),(.58,1.01),(.58,.65),(.44,.48),(-.48,.48),(-.70,.65),(-.76,.96)]
inner=[(-.54,1.015),(.32,1.015),(.425,.925),(.425,.725),(.34,.625),(-.405,.625),(-.55,.73),(-.61,.93)]
ring_profile('Revolver_Trigger_Guard',outer,inner,.19)
profile('Revolver_Trigger',[(-.27,1.17),(-.11,1.17),(-.15,1.04),(-.28,.83),(-.25,.74),(-.35,.76),(-.39,.87),(-.28,1.05)],.13)
profile('Revolver_Hammer',[(-.99,1.99),(-.82,1.99),(-.87,2.21),(-1.13,2.43),(-1.37,2.43),(-1.37,2.32),(-1.16,2.30),(-1.00,2.14)],.24)

camera_data=bpy.data.cameras.new('Revolver_Camera')
camera=bpy.data.objects.new('Revolver_Camera',camera_data)
stage.objects.link(camera)
camera.location=(5.4,-9.5,4.9)
camera.rotation_euler=(Vector((.42,0,1.24))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO'
camera_data.ortho_scale=5.35
scene.camera=camera
scene.render.engine='BLENDER_WORKBENCH'
scene.render.resolution_x=1500
scene.render.resolution_y=950
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
print('Revolver blockout created; zero material slots.')

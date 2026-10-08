-- BuildStarterGameUI: run in Studio Edit mode after importing GameUI.
-- Extends the supplied cyan image frame; all menus remain editable in StarterGui.
local gui=game.StarterGui:WaitForChild("GameUI")
gui.ResetOnSpawn=false
gui.DisplayOrder=10
gui:SetAttribute("Open",false)
local frames=gui:WaitForChild("Frames")
local index=frames:WaitForChild("Index")
local function make(class,props,parent)
 local x=Instance.new(class) for k,v in props do x[k]=v end x.Parent=parent return x
end
local dark=Color3.fromRGB(8,20,28)
local cyan=Color3.fromRGB(24,198,235)
local blue=Color3.fromRGB(10,148,222)
local green=Color3.fromRGB(77,238,41)
local function outline(x,thickness,color)
 make("UIStroke",{Thickness=thickness or 2,Color=color or dark,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},x)
end
local function text(name,parent,value,position,size)
 local x=make("TextLabel",{Name=name,Text=value,Position=position,Size=size,BackgroundTransparency=1,Font=Enum.Font.GothamBlack,TextColor3=Color3.new(1,1,1),TextSize=20,TextScaled=true,TextWrapped=true,ZIndex=12},parent)
 make("UIStroke",{Thickness=1.8,Color=dark},x)
 make("UITextSizeConstraint",{MinTextSize=9,MaxTextSize=24},x)
 return x
end
local function button(name,parent,value,position,size,color)
 local x=make("TextButton",{Name=name,Text=value,Position=position,Size=size,BackgroundColor3=color or blue,BorderSizePixel=0,Font=Enum.Font.GothamBlack,TextColor3=Color3.new(1,1,1),TextScaled=true,AutoButtonColor=true,ZIndex=13},parent)
 outline(x,2)
 make("UIStroke",{Thickness=1.5,Color=dark},x)
 make("UITextSizeConstraint",{MinTextSize=9,MaxTextSize=20},x)
 return x
end
local function clearGenerated(parent,name)
 local x=parent:FindFirstChild(name) if x then x:Destroy() end
end
clearGenerated(index,"Content")
index.Visible=false index.ZIndex=10 index.Active=true
index.CloseButton.ZIndex=20
local body=make("Frame",{Name="Content",Position=UDim2.fromScale(.035,.247),Size=UDim2.fromScale(.93,.71),BackgroundTransparency=1,ZIndex=11},index)
local tabs=make("ScrollingFrame",{Name="WorldTabs",Position=UDim2.fromScale(0,0),Size=UDim2.fromScale(.66,.13),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,ScrollingDirection=Enum.ScrollingDirection.X,AutomaticCanvasSize=Enum.AutomaticSize.X,CanvasSize=UDim2.new(),ZIndex=12},body)
make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},tabs)
text("Total",body,"0 / 9 FOUND",UDim2.fromScale(.68,0),UDim2.fromScale(.32,.13))
local track=make("Frame",{Name="Progress",Position=UDim2.fromScale(0,.17),Size=UDim2.fromScale(1,.065),BackgroundColor3=Color3.fromRGB(8,92,138),BorderSizePixel=0,ZIndex=12},body)
outline(track,2)
make("Frame",{Name="Fill",Size=UDim2.fromScale(0,1),BackgroundColor3=green,BorderSizePixel=0,ZIndex=13},track)
local pt=text("Label",track,"FOREST  0 / 4",UDim2.new(),UDim2.fromScale(1,1)) pt.ZIndex=14
local cards=make("ScrollingFrame",{Name="Cards",Position=UDim2.fromScale(0,.27),Size=UDim2.fromScale(1,.73),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,ScrollBarImageColor3=dark,ScrollingDirection=Enum.ScrollingDirection.Y,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ZIndex=12},body)
make("UIGridLayout",{CellSize=UDim2.fromOffset(122,170),CellPadding=UDim2.fromOffset(8,8),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center},cards)
make("UIPadding",{PaddingTop=UDim.new(0,3),PaddingBottom=UDim.new(0,6),PaddingLeft=UDim.new(0,3),PaddingRight=UDim.new(0,9)},cards)

clearGenerated(frames,"Pets")
local pets=index:Clone() pets.Name="Pets" pets.Content:Destroy() pets.Parent=frames pets.Visible=false
local header=make("Frame",{Name="PetsHeader",Position=UDim2.fromScale(.008,.01),Size=UDim2.fromScale(.845,.193),BackgroundColor3=cyan,BorderSizePixel=0,ZIndex=12},pets)
make("UIGradient",{Color=ColorSequence.new(cyan,blue),Rotation=90},header)
local paw=gui:FindFirstChild("Pets",true)
if paw then make("ImageLabel",{Name="Paw",Image=paw.Image,BackgroundTransparency=1,Position=UDim2.fromScale(.018,.1),Size=UDim2.fromScale(.13,.8),ScaleType=Enum.ScaleType.Fit,ZIndex=13},header) end
local title=text("Title",header,"PETS",UDim2.fromScale(.16,0),UDim2.fromScale(.80,1))
title.TextXAlignment=Enum.TextXAlignment.Left title.UITextSizeConstraint.MaxTextSize=54
local pb=make("Frame",{Name="Content",Position=UDim2.fromScale(.035,.247),Size=UDim2.fromScale(.93,.71),BackgroundTransparency=1,ZIndex=11},pets)
button("EquippedTab",pb,"EQUIPPED",UDim2.fromScale(0,0),UDim2.fromScale(.28,.13),green)
button("AllTab",pb,"ALL PETS",UDim2.fromScale(.30,0),UDim2.fromScale(.28,.13),blue)
text("Income",pb,"$0 / SECOND",UDim2.fromScale(.60,0),UDim2.fromScale(.40,.13)).TextColor3=green
local count=text("Count",pb,"0 / 24 EQUIPPED",UDim2.fromScale(0,.155),UDim2.fromScale(.54,.08))
count.TextXAlignment=Enum.TextXAlignment.Left count.UITextSizeConstraint.MaxTextSize=16
button("EquipBest",pb,"EQUIP BEST",UDim2.fromScale(.61,.155),UDim2.fromScale(.39,.11),green)
local pc=cards:Clone() pc.Name="Cards" pc.Position=UDim2.fromScale(0,.29) pc.Size=UDim2.fromScale(1,.59) pc.Parent=pb
text("Empty",pb,"NO PETS EQUIPPED\nCatch animals, then tap EQUIP BEST!",UDim2.fromScale(.03,.35),UDim2.fromScale(.92,.42)).Visible=false
local status=text("Status",pb,"Equipped pets earn money on your plot.",UDim2.fromScale(0,.90),UDim2.fromScale(1,.10))
status.UITextSizeConstraint.MaxTextSize=15
clearGenerated(gui,"HUD")
local hud=make("Frame",{Name="HUD",AnchorPoint=Vector2.new(0,1),Position=UDim2.new(.016,0,.975,0),Size=UDim2.fromOffset(280,104),BackgroundTransparency=1,ZIndex=2},gui)
local money=text("Cash",hud,"$0",UDim2.fromScale(0,0),UDim2.fromScale(1,.43)) money.TextColor3=green money.TextXAlignment=Enum.TextXAlignment.Left money.UITextSizeConstraint.MaxTextSize=40 money.ZIndex=3
local income=text("Income",hud,"+$0 / SECOND",UDim2.fromScale(0,.45),UDim2.fromScale(1,.24)) income.TextColor3=green income.TextXAlignment=Enum.TextXAlignment.Left income.UITextSizeConstraint.MaxTextSize=20 income.ZIndex=3
local wave=text("Wave",hud,"NEW ANIMALS IN 5:00",UDim2.fromScale(0,.72),UDim2.fromScale(1,.26)) wave.TextXAlignment=Enum.TextXAlignment.Left wave.UITextSizeConstraint.MaxTextSize=17 wave.ZIndex=3
clearGenerated(gui,"CarryBanner")
local carry=make("Frame",{Name="CarryBanner",AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,.16),Size=UDim2.fromOffset(650,44),BackgroundColor3=cyan,BorderSizePixel=0,Visible=false,ZIndex=30},gui)
outline(carry,3)
local ct=text("Label",carry,"",UDim2.fromScale(.02,0),UDim2.fromScale(.75,1)) ct.UITextSizeConstraint.MaxTextSize=19 ct.ZIndex=31
button("Drop",carry,"DROP (G)",UDim2.fromScale(.79,.11),UDim2.fromScale(.19,.78),Color3.fromRGB(245,55,55)).ZIndex=32
for _,d in gui:GetDescendants() do
 if d:IsA("GuiButton") then d.Active=true d.Interactable=true end
 if d:IsA("ImageButton") then d.BackgroundTransparency=1 end
end
return gui


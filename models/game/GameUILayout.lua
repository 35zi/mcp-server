-- Restore the supplied right-side Pets panel's controls without replacing its artwork.
local Layout={}
local dark=Color3.fromRGB(8,20,28)
local green=Color3.fromRGB(77,238,41)
local blue=Color3.fromRGB(10,148,222)
local function node(parent,name,class)
 local existing=parent:FindFirstChild(name)
 if existing then return existing end
 local x=Instance.new(class) x.Name=name x.Parent=parent return x
end
local function text(parent,name,value,position,size,isButton)
 local x=node(parent,name,isButton and "TextButton" or "TextLabel")
 x.AnchorPoint=Vector2.zero x.Position=position x.Size=size
 x.Text=value x.Font=Enum.Font.GothamBlack x.TextScaled=true x.TextWrapped=true
 x.TextColor3=Color3.new(1,1,1) x.BorderSizePixel=0 x.ZIndex=17
 x.BackgroundTransparency=isButton and 0 or 1
 if isButton then x.BackgroundColor3=blue x.AutoButtonColor=false x.Active=true x.Interactable=true end
 local line=node(x,"TextOutline","UIStroke") line.Thickness=1.3 line.Color=dark
 local limit=node(x,"TextLimit","UITextSizeConstraint") limit.MinTextSize=9 limit.MaxTextSize=isButton and 14 or 16
 return x
end
function Layout.Apply(gui)
 local pets=gui.Frames.Pets
 pets.AnchorPoint=Vector2.new(.5,.5) pets.ZIndex=10 pets.Active=true
 local ratio=pets:FindFirstChildOfClass("UIAspectRatioConstraint")
 if ratio then ratio.AspectRatio=.6268991232 end
 local body=node(pets,"Content","Frame")
 body.Position=UDim2.fromScale(.07,.18) body.Size=UDim2.fromScale(.86,.77)
 body.BackgroundTransparency=1 body.ZIndex=11
 local artwork=pets:FindFirstChild("Pets")
 local best=node(pets,"EquipBestArtwork","ImageButton")
 best.Image=artwork and artwork.Image or best.Image
 best.BackgroundTransparency=1 best.AnchorPoint=Vector2.new(.5,.5)
 best.Position=UDim2.fromScale(.337,.0775) best.Size=UDim2.fromScale(.674,.155)
 best.ZIndex=20 best.Active=true best.Interactable=true
 if artwork then artwork:Destroy() end
 text(body,"Count","0 / 24 EQUIPPED",UDim2.fromScale(0,0),UDim2.fromScale(1,.07))
 local equippedTab=body:FindFirstChild("EquippedTab") if equippedTab then equippedTab:Destroy() end
 local allTab=body:FindFirstChild("AllTab") if allTab then allTab:Destroy() end
 local legacyBest=body:FindFirstChild("EquipBest") if legacyBest then legacyBest:Destroy() end
 text(body,"Income","$0 / SECOND",UDim2.fromScale(0,.90),UDim2.fromScale(1,.08)).TextColor3=green
 local status=body:FindFirstChild("Status") if status then status:Destroy() end
 local cards=node(body,"Cards","ScrollingFrame")
 cards.Position=UDim2.fromScale(0,.10) cards.Size=UDim2.fromScale(1,.76)
 cards.BackgroundTransparency=1 cards.BorderSizePixel=0 cards.ZIndex=12
 cards.AutomaticCanvasSize=Enum.AutomaticSize.Y cards.CanvasSize=UDim2.new()
 cards.ScrollingDirection=Enum.ScrollingDirection.Y cards.ScrollBarThickness=4
 local grid=node(cards,"UIGridLayout","UIGridLayout")
 grid.CellPadding=UDim2.fromOffset(0,8) grid.SortOrder=Enum.SortOrder.LayoutOrder
 grid.HorizontalAlignment=Enum.HorizontalAlignment.Center
 text(body,"Empty","NO PETS EQUIPPED\nCatch animals, then tap EQUIP BEST!",UDim2.fromScale(.04,.36),UDim2.fromScale(.92,.42)).Visible=false
 local close=pets.CloseButton
 close.AnchorPoint=Vector2.new(.5,.5) close.Position=UDim2.new(1,-20,0,20)
 close.Size=UDim2.fromOffset(44,48) close.ZIndex=25
 gui:SetAttribute("PetsLayoutVersion",2)
end
function Layout.ResizePets(gui,viewport)
 local width=math.max(140,math.min(240,viewport.X-32,(viewport.Y-80)*.6268991232))
 local pets=gui.Frames.Pets
 pets.Size=UDim2.fromOffset(width,width/.6268991232)
 pets.Position=UDim2.new(1,-16-width/2,.5,0)
end
return Layout

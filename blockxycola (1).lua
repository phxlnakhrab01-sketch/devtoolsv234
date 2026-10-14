--[[
 blockxycola.lua | Safe Roblox Studio Developer Toolkit
 ติดตั้ง: วางเป็น LocalScript ใน StarterPlayer > StarterPlayerScripts ของเกมที่คุณเป็นผู้พัฒนา
 หมายเหตุ: ไม่ใช่สคริปต์ Executor และไม่มี aimbot/aim assist/ESP สำหรับโกงผู้เล่นอื่น
 ร้านค้า: สแกนวัตถุที่มี ProximityPrompt หรือ Attribute ShopItem=true / ShopItemName
 การซื้อจริงต้องเชื่อมกับระบบร้านค้าฝั่งเซิร์ฟเวอร์ของเกมเอง (ตรวจเงิน/ระยะ/ไอเท็มบนเซิร์ฟเวอร์)
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer
if not player then return end

local CONFIG = {
    ToggleKey = Enum.KeyCode.RightShift,
    SpeedKey = Enum.KeyCode.V,
    HealKey = Enum.KeyCode.H,
    DefaultSpeed = 24,
    DefaultHealAmount = 25,
    StudioOnlyLocalHeal = true,
    ScanInterval = 5,
}
local alive, menuOpen = true, true
local connections = {}
local speedEnabled, speedValue = false, CONFIG.DefaultSpeed
local healAmount = CONFIG.DefaultHealAmount
local graphicsBackup, graphicsActive = nil, false
local shopResults, selectedShopItem = {}, nil
local function bind(signal, fn)
    local c = signal:Connect(fn); table.insert(connections, c); return c
end
local function make(class, props, parent)
    local o = Instance.new(class)
    for k,v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end
local function corner(o, r) make("UICorner", {CornerRadius=UDim.new(0,r or 9)}, o) end
local function stroke(o, color) make("UIStroke", {Color=color or Color3.fromRGB(54,58,76), Thickness=1}, o) end
local C = {
    bg=Color3.fromRGB(16,17,24), panel=Color3.fromRGB(25,27,37), card=Color3.fromRGB(31,34,46),
    line=Color3.fromRGB(54,58,76), text=Color3.fromRGB(242,243,250), muted=Color3.fromRGB(157,161,181),
    accent=Color3.fromRGB(124,98,255), green=Color3.fromRGB(90,220,145), red=Color3.fromRGB(235,85,100)
}
local pg = player:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("BlockxycolaToolkit"); if old then old:Destroy() end
local gui = make("ScreenGui", {Name="BlockxycolaToolkit", ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling}, pg)
local main = make("Frame", {Name="Main", AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale(.5,.5), Size=UDim2.fromOffset(660,490), BackgroundColor3=C.bg, BorderSizePixel=0}, gui); corner(main,16); stroke(main,C.line)
local header = make("Frame", {Size=UDim2.new(1,0,0,68), BackgroundColor3=C.panel, BorderSizePixel=0}, main); corner(header,16)
make("Frame", {Position=UDim2.new(0,0,1,-12), Size=UDim2.new(1,0,0,12), BackgroundColor3=C.panel, BorderSizePixel=0}, header)
make("TextLabel", {BackgroundTransparency=1, Position=UDim2.fromOffset(20,10), Size=UDim2.new(1,-100,0,27), Font=Enum.Font.GothamBold, Text="BLOCKXYCOLA  /  DEV TOOLKIT", TextSize=18, TextColor3=C.text, TextXAlignment=Enum.TextXAlignment.Left}, header)
make("TextLabel", {BackgroundTransparency=1, Position=UDim2.fromOffset(21,38), Size=UDim2.new(1,-100,0,18), Font=Enum.Font.Gotham, Text="Studio developer utilities • RightShift: toggle • End: unload", TextSize=11, TextColor3=C.muted, TextXAlignment=Enum.TextXAlignment.Left}, header)
local close = make("TextButton", {AnchorPoint=Vector2.new(1,.5), Position=UDim2.new(1,-16,.5,0), Size=UDim2.fromOffset(34,34), BackgroundColor3=C.card, Text="×", TextSize=22, Font=Enum.Font.GothamBold, TextColor3=C.text}, header); corner(close,9)
local nav = make("Frame", {Position=UDim2.fromOffset(14,82), Size=UDim2.new(0,145,1,-96), BackgroundTransparency=1}, main)
local content = make("Frame", {Position=UDim2.fromOffset(170,82), Size=UDim2.new(1,-184,1,-96), BackgroundTransparency=1}, main)
local status = make("TextLabel", {Position=UDim2.new(0,0,1,-23), Size=UDim2.new(1,0,0,20), BackgroundTransparency=1, Font=Enum.Font.Gotham, Text="พร้อมทำงาน", TextSize=12, TextColor3=C.green, TextXAlignment=Enum.TextXAlignment.Left}, content)
local pages, navButtons = {}, {}
local function button(parent, text, pos, size, color)
    local b=make("TextButton", {Position=pos, Size=size, BackgroundColor3=color or C.accent, Text=text, TextSize=12, Font=Enum.Font.GothamBold, TextColor3=C.text, AutoButtonColor=true}, parent); corner(b,8); return b
end
local function label(parent, text, pos, size, fontSize, color)
    return make("TextLabel", {Position=pos, Size=size, BackgroundTransparency=1, Font=Enum.Font.Gotham, Text=text, TextSize=fontSize or 12, TextColor3=color or C.text, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Center, TextWrapped=true}, parent)
end
local function textbox(parent, text, pos, size)
    local t=make("TextBox", {Position=pos, Size=size, BackgroundColor3=C.bg, Text=text, PlaceholderText="ใส่ตัวเลข", ClearTextOnFocus=false, Font=Enum.Font.Gotham, TextSize=13, TextColor3=C.text, PlaceholderColor3=C.muted}, parent); corner(t,7); stroke(t); return t
end
local function newPage(name)
    local p=make("ScrollingFrame", {Name=name, Size=UDim2.fromScale(1,1), BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, Visible=false}, content)
    make("UIListLayout", {Padding=UDim.new(0,9), SortOrder=Enum.SortOrder.LayoutOrder}, p)
    make("UIPadding", {PaddingRight=UDim.new(0,5), PaddingBottom=UDim.new(0,30)}, p)
    pages[name]=p
    local b=button(nav,name,UDim2.new(0,0,0,(#navButtons)*42),UDim2.new(1,0,0,34),C.card); table.insert(navButtons,b)
    bind(b.MouseButton1Click,function() for n,page in pairs(pages) do page.Visible=(n==name) end; for i,nb in ipairs(navButtons) do nb.BackgroundColor3=(nb==b and C.accent or C.card) end end)
    if #navButtons==1 then p.Visible=true; b.BackgroundColor3=C.accent end
    return p
end
local function card(parent, height)
    local f=make("Frame", {Size=UDim2.new(1,-3,0,height), BackgroundColor3=C.panel, BorderSizePixel=0}, parent); corner(f,10); stroke(f); return f
end

-- OVERVIEW
local overview=newPage("ภาพรวม")
local pc=card(overview,82)
label(pc,"ผู้เล่นในเซิร์ฟเวอร์",UDim2.fromOffset(14,8),UDim2.new(1,-28,0,20),12,C.muted)
local countLabel=label(pc,"กำลังโหลด…",UDim2.fromOffset(14,30),UDim2.new(1,-28,0,35),24,C.text)
local info=card(overview,112)
label(info,"คีย์ลัด",UDim2.fromOffset(14,8),UDim2.new(1,-28,0,20),14,C.text)
label(info,"RightShift  เปิด/ปิดเมนู\nV  เปิด/ปิดความเร็ว\nH  ฟื้นเลือดเฉพาะการทดสอบใน Studio",UDim2.fromOffset(14,32),UDim2.new(1,-28,0,65),12,C.muted)
local gfxCard=card(overview,70)
label(gfxCard,"ลดกราฟิกชั่วคราว / คืนค่าเดิม",UDim2.fromOffset(14,8),UDim2.new(1,-160,0,48),12,C.text)
local gfxBtn=button(gfxCard,"ลดกราฟิก",UDim2.new(1,-132,0,19),UDim2.fromOffset(116,32),C.accent)
local function updateCount() countLabel.Text=string.format("%d / %d",#Players:GetPlayers(),Players.MaxPlayers) end
updateCount(); bind(Players.PlayerAdded,updateCount); bind(Players.PlayerRemoving,function() task.defer(updateCount) end)

-- MOVEMENT / HEAL
local movement=newPage("ความเร็ว / ฟื้นเลือด")
local speedCard=card(movement,140)
label(speedCard,"ความเร็วเดิน (WalkSpeed)",UDim2.fromOffset(14,8),UDim2.new(1,-28,0,22),14,C.text)
label(speedCard,"ค่าเริ่มต้น 24 • ปุ่ม V เปิด/ปิด • ใช้ในเกมที่คุณพัฒนาเท่านั้น",UDim2.fromOffset(14,31),UDim2.new(1,-28,0,25),11,C.muted)
local speedBox=textbox(speedCard,tostring(CONFIG.DefaultSpeed),UDim2.fromOffset(14,67),UDim2.fromOffset(105,32))
local speedBtn=button(speedCard,"เปิดความเร็ว",UDim2.fromOffset(130,67),UDim2.fromOffset(145,32),C.accent)
local healCard=card(movement,145)
label(healCard,"ฟื้นเลือดสำหรับทดสอบ",UDim2.fromOffset(14,8),UDim2.new(1,-28,0,22),14,C.text)
label(healCard,"Local heal ใช้ได้เฉพาะ Studio; เกมจริงต้องให้เซิร์ฟเวอร์ตรวจสิทธิ์",UDim2.fromOffset(14,31),UDim2.new(1,-28,0,27),11,C.muted)
local healBox=textbox(healCard,tostring(CONFIG.DefaultHealAmount),UDim2.fromOffset(14,69),UDim2.fromOffset(105,32))
local healBtn=button(healCard,"ฟื้นเลือด +",UDim2.fromOffset(130,69),UDim2.fromOffset(145,32),C.green)
local function humanoid() local ch=player.Character; return ch and ch:FindFirstChildOfClass("Humanoid") end
local function applySpeed()
    local h=humanoid(); if h then h.WalkSpeed=speedEnabled and speedValue or 16 end
end
local function toggleSpeed()
    speedEnabled=not speedEnabled; applySpeed(); speedBtn.Text=speedEnabled and "ปิดความเร็ว" or "เปิดความเร็ว"; status.Text=speedEnabled and ("เปิดความเร็ว: "..speedValue) or "คืนความเร็วเป็น 16"
end
bind(speedBtn.MouseButton1Click,toggleSpeed)
bind(healBtn.MouseButton1Click,function()
    if CONFIG.StudioOnlyLocalHeal and not RunService:IsStudio() then status.Text="ฟื้นเลือดถูกปิดนอก Studio"; status.TextColor3=C.red; return end
    local n=tonumber(healBox.Text); local h=humanoid()
    if not n or n<1 or n>1000 or not h then status.Text="จำนวนเลือดไม่ถูกต้องหรือยังไม่มีตัวละคร"; status.TextColor3=C.red; return end
    h.Health=math.min(h.MaxHealth,h.Health+n); status.Text="ฟื้นเลือดสำหรับทดสอบแล้ว"; status.TextColor3=C.green
end)
bind(speedBox.FocusLost,function() local n=tonumber(speedBox.Text); if n and n>=0 and n<=100 then speedValue=n else speedBox.Text=tostring(speedValue) end end)
bind(healBox.FocusLost,function() local n=tonumber(healBox.Text); if n and n>=1 and n<=1000 then healAmount=math.floor(n); healBox.Text=tostring(healAmount) else healBox.Text=tostring(healAmount) end end)

-- SHOP SCANNER: discovery only; no exploit purchase / no guessed remote calls.
local shop=newPage("Shop Scanner")
local scanCard=card(shop,92)
label(scanCard,"สแกนวัตถุร้านค้าใน Workspace",UDim2.fromOffset(14,8),UDim2.new(1,-28,0,22),14,C.text)
label(scanCard,"ค้นหา ProximityPrompt, Tag 'ShopItem' หรือ Attribute ShopItem=true / ShopItemName",UDim2.fromOffset(14,31),UDim2.new(1,-28,0,30),11,C.muted)
local scanBtn=button(scanCard,"สแกนตอนนี้",UDim2.fromOffset(14,62),UDim2.fromOffset(130,24),C.accent)
local resultCard=card(shop,225)
local resultsLabel=label(resultCard,"ยังไม่ได้สแกน",UDim2.fromOffset(14,10),UDim2.new(1,-28,1,-20),12,C.text)
resultsLabel.TextYAlignment=Enum.TextYAlignment.Top
local function isShopCandidate(obj)
    if not obj or not obj.Parent then return false end
    if obj:GetAttribute("ShopItem")==true or obj:GetAttribute("ShopItemName")~=nil or CollectionService:HasTag(obj,"ShopItem") then return true end
    if obj:IsA("ProximityPrompt") then return true end
    return false
end
local function scanShops()
    local found, seen = {}, {}
    for _,obj in ipairs(workspace:GetDescendants()) do
        if isShopCandidate(obj) then
            local target=obj
            if obj:IsA("ProximityPrompt") then target=obj:FindFirstAncestorOfClass("Model") or obj.Parent end
            if target and not seen[target] then
                seen[target]=true
                local prompt=target:FindFirstChildWhichIsA("ProximityPrompt",true)
                local itemName=target:GetAttribute("ShopItemName") or (prompt and prompt.ObjectText~="" and prompt.ObjectText) or target.Name
                local price=target:GetAttribute("Price") or target:GetAttribute("Cost")
                table.insert(found,{instance=target,name=tostring(itemName),price=price,prompt=prompt,path=target:GetFullName()})
            end
        end
    end
    table.sort(found,function(a,b) return a.name:lower()<b.name:lower() end)
    shopResults=found
    if #found==0 then resultsLabel.Text="ไม่พบร้านค้าที่ระบุได้\n\nในเกมของคุณให้ติด Tag 'ShopItem' หรือกำหนด Attribute ShopItem=true / ShopItemName บนโมเดลร้านค้า หรือเพิ่ม ProximityPrompt"; selectedShopItem=nil
    else
        local lines={"พบวัตถุที่อาจเป็นร้านค้า: "..#found,""}
        for i,item in ipairs(found) do
            local priceText=item.price~=nil and (" | ราคา: "..tostring(item.price)) or " | ไม่พบ Attribute ราคา"
            table.insert(lines,string.format("%02d. %s%s\n    %s",i,item.name,priceText,item.path))
            if i>=35 then table.insert(lines,"… แสดงสูงสุด 35 รายการ"); break end
        end
        table.insert(lines,"\nการสแกนนี้เป็นการค้นพบวัตถุเท่านั้น ไม่สามารถยืนยันว่าซื้อได้")
        resultsLabel.Text=table.concat(lines,"\n")
        selectedShopItem=found[1]
    end
    status.Text="สแกนร้านค้าเสร็จ: "..#found.." รายการ"; status.TextColor3=C.green
end
bind(scanBtn.MouseButton1Click,scanShops)

-- PERFORMANCE / CLEANUP
local performance=newPage("Performance")
local perfCard=card(performance,100)
label(perfCard,"ประสิทธิภาพและความปลอดภัย",UDim2.fromOffset(14,8),UDim2.new(1,-28,0,22),14,C.text)
label(perfCard,"• ลดกราฟิกชั่วคราวและคืนค่าเดิม\n• อัปเดตจำนวนผู้เล่นเฉพาะเมื่อเข้า/ออก\n• เก็บและตัดการเชื่อมต่อ event เมื่อปิดสคริปต์\n• ไม่สร้างลูปตรวจทุกเฟรมโดยไม่จำเป็น",UDim2.fromOffset(14,32),UDim2.new(1,-28,0,62),11,C.muted)
local cleanupCard=card(performance,68)
label(cleanupCard,"ปิดเครื่องมือและคืนค่าที่เปลี่ยน",UDim2.fromOffset(14,8),UDim2.new(1,-150,0,48),12,C.text)
local unloadBtn=button(cleanupCard,"Unload",UDim2.new(1,-112,0,18),UDim2.fromOffset(96,32),C.red)

local function reduceGraphics()
    if graphicsActive then
        Lighting.GlobalShadows=graphicsBackup.shadows; Lighting.Brightness=graphicsBackup.brightness; Lighting.FogEnd=graphicsBackup.fogEnd
        for _,r in ipairs(graphicsBackup.effects) do if r.obj and r.obj.Parent then pcall(function() r.obj.Enabled=r.enabled end) end end
        graphicsBackup=nil; graphicsActive=false; gfxBtn.Text="ลดกราฟิก"; status.Text="คืนค่ากราฟิกเดิมแล้ว"
    else
        graphicsBackup={shadows=Lighting.GlobalShadows,brightness=Lighting.Brightness,fogEnd=Lighting.FogEnd,effects={}}
        for _,obj in ipairs(Lighting:GetChildren()) do if obj:IsA("PostEffect") then table.insert(graphicsBackup.effects,{obj=obj,enabled=obj.Enabled}); obj.Enabled=false end end
        Lighting.GlobalShadows=false; Lighting.FogEnd=100000; graphicsActive=true; gfxBtn.Text="คืนค่ากราฟิก"; status.Text="ลดกราฟิกแล้ว"
    end
end
bind(gfxBtn.MouseButton1Click,reduceGraphics)
local function setOpen(v) menuOpen=v; main.Visible=v end
bind(close.MouseButton1Click,function() setOpen(false) end)
local floating=button(gui,"☰",UDim2.new(0,14,.5,-22),UDim2.fromOffset(44,44),C.panel); floating.TextSize=20; stroke(floating,C.accent)
bind(floating.MouseButton1Click,function() setOpen(not menuOpen) end)
bind(UserInputService.InputBegan,function(input,processed)
    if processed then return end
    if input.KeyCode==CONFIG.ToggleKey then setOpen(not menuOpen)
    elseif input.KeyCode==CONFIG.SpeedKey then toggleSpeed()
    elseif input.KeyCode==CONFIG.HealKey then
        if RunService:IsStudio() then local h=humanoid(); if h then h.Health=math.min(h.MaxHealth,h.Health+healAmount) end end
    elseif input.KeyCode==Enum.KeyCode.End then
        -- handled below after cleanup is defined
        task.defer(function() if alive then
            alive=false
            if graphicsActive then reduceGraphics() end
            if speedEnabled then speedEnabled=false; applySpeed() end
            for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
            gui:Destroy()
        end end)
    end
end)
bind(player.CharacterAdded,function() task.wait(.25); if speedEnabled then applySpeed() end end)
local function cleanup()
    if not alive then return end; alive=false
    if graphicsActive then reduceGraphics() end
    if speedEnabled then speedEnabled=false; applySpeed() end
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    if gui then gui:Destroy() end
end
bind(unloadBtn.MouseButton1Click,cleanup)
print("[blockxycola] Safe Studio developer toolkit loaded. RightShift toggles UI; V speed; H Studio test-heal; End unloads.")

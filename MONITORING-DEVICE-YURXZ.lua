--[[
    MONITORING DEVICE YURXZ v8.0
    Compact Edition — GUI Kecil
]]

local CONFIG = {
    WEBHOOK_URL = "https://discord.com/api/webhooks/GANTI_INI",
    DISCORD_ID  = "GANTI_USER_ID_DISCORD",
    AVATAR_URL  = "https://files.catbox.moe/wz24ac.png",
    INTERVAL    = 60,
}

local Players      = game:GetService("Players")
local Stats        = game:GetService("Stats")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local player       = Players.LocalPlayer
local playerGui    = player:WaitForChild("PlayerGui")

local _genv = {}
pcall(function() _genv = getgenv() end)
local function gset(k,v) pcall(function() _genv[k]=v end) end
local function gget(k) local ok,v=pcall(function() return _genv[k] end); return ok and v or nil end

if playerGui:FindFirstChild("YURXZ_v8") then playerGui:FindFirstChild("YURXZ_v8"):Destroy() end
local oldStop = gget("MD_Stop")
if oldStop then pcall(oldStop) end
gset("YURXZ_RUNNING", false)
task.wait(0.1)
gset("YURXZ_RUNNING", true)

local savedWebhook = gget("YURXZ_SAVED_WEBHOOK")
if savedWebhook and savedWebhook ~= "" then CONFIG.WEBHOOK_URL = savedWebhook end
local savedID = gget("YURXZ_SAVED_DISCORDID")
if savedID and savedID ~= "" then CONFIG.DISCORD_ID = savedID end

local running=false; local INTERVAL=CONFIG.INTERVAL; local startTime=os.time()
local reportCount=0; local notifGui=nil; local disconnectSent=false
local coinCurrent=0; local coinStart=0; local coinEarned=0; local coinLabel="Coins"
local levelCurrent=0; local lastPos=Vector3.new(0,0,0); local lastMoveTime=os.time()
local IS_AFK=false

local function tryConnectLS(ls)
    local coinNames={"Coins","coins","Money","money","Cash","cash","Gold","gold","Bucks","bucks","Currency","Fishcoins","FishCoins","C$","Shells"}
    local found=false
    for _,name in ipairs(coinNames) do
        local v=ls:FindFirstChild(name)
        if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
            coinLabel=v.Name; coinCurrent=math.floor(v.Value); coinStart=coinCurrent
            v.Changed:Connect(function(val) coinCurrent=math.floor(val); coinEarned=math.max(0,coinCurrent-coinStart) end)
            found=true; break
        end
    end
    if not found then
        for _,v in ipairs(ls:GetChildren()) do
            if (v:IsA("IntValue") or v:IsA("NumberValue")) and v.Value>0 then
                coinLabel=v.Name; coinCurrent=math.floor(v.Value); coinStart=coinCurrent
                v.Changed:Connect(function(val) coinCurrent=math.floor(val); coinEarned=math.max(0,coinCurrent-coinStart) end)
                found=true; break
            end
        end
    end
    for _,name in ipairs({"Level","level","Rank","rank","XP","xp"}) do
        local v=ls:FindFirstChild(name)
        if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
            levelCurrent=math.floor(v.Value)
            v.Changed:Connect(function(val) levelCurrent=math.floor(val) end)
            break
        end
    end
end

task.spawn(function()
    local ls=player:FindFirstChild("leaderstats")
    if ls then task.wait(0.5); tryConnectLS(ls)
    else player.ChildAdded:Connect(function(c) if c.Name=="leaderstats" then task.wait(1); tryConnectLS(c) end end) end
end)

task.spawn(function()
    while true do
        task.wait(10)
        local char=player.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local dist=(hrp.Position-lastPos).Magnitude
            if dist>3 then lastMoveTime=os.time(); IS_AFK=false
            else IS_AFK=(os.time()-lastMoveTime)>60 end
            lastPos=hrp.Position
        end
    end
end)

local function getHttp()
    local ok,fn
    ok,fn=pcall(function() return syn and syn.request end); if ok and fn then return fn end
    ok,fn=pcall(function() return http and http.request end); if ok and fn then return fn end
    ok,fn=pcall(function() return http_request end); if ok and fn then return fn end
    ok,fn=pcall(function() return request end); if ok and fn then return fn end
    return nil
end

local function getExecutor()
    if syn then return "Synapse X" end
    local ok=pcall(function() return KRNL_LOADED end); if ok and KRNL_LOADED then return "KRNL" end
    if gget("is_fluxus") then return "Fluxus" end
    if gget("DELTA_LOADED") or gget("delta_loaded") then return "Delta" end
    if gget("ARCEUS_X") then return "Arceus X" end
    if gget("hydrogen") then return "Hydrogen" end
    if gget("trigon") then return "Trigon" end
    return "Unknown"
end
local function execIcon(n)
    if n:find("Synapse") then return "🔵" elseif n:find("KRNL") then return "🟣"
    elseif n:find("Fluxus") then return "🟠" elseif n:find("Arceus") then return "🟤"
    elseif n:find("Delta") then return "🔷" else return "⚙️" end
end
local EXEC_NAME=getExecutor(); local EXEC_ICON=execIcon(EXEC_NAME)

local function getMemMB()
    local ok,v=pcall(function() return Stats:GetTotalMemoryUsageMb() end)
    if ok and v and v>0 then return math.floor(v*10)/10 end
    ok,v=pcall(function() return Stats.HeapSize end)
    if ok and v and v>0 then return math.floor((v/1024)*10)/10 end
    return 0
end
local function memStr(mb)
    if mb<=0 then return "N/A" end
    return mb>=1024 and string.format("%.2f GB",mb/1024) or string.format("%.1f MB",mb)
end
local MEM_WARN=2500; local MEM_CRIT=4000

local fpsVal=60; local fpsClock,fpsCount=0,0
RunService.RenderStepped:Connect(function(dt)
    fpsCount=fpsCount+1; fpsClock=fpsClock+dt
    if fpsClock>=1 then fpsVal=fpsCount; fpsCount=0; fpsClock=0 end
end)
local cpuVal=0; local cpuSamples={}
RunService.Heartbeat:Connect(function(dt)
    local load=math.clamp((dt-(1/60))/(1/60)*100,0,100)
    table.insert(cpuSamples,load)
    if #cpuSamples>60 then table.remove(cpuSamples,1) end
    local sum=0; for _,v in ipairs(cpuSamples) do sum=sum+v end
    cpuVal=math.floor(sum/#cpuSamples)
end)

local function getPingRaw()
    local ok,v=pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    if ok and v and v>0 and v<9999 then return math.floor(v) end
    ok,v=pcall(function() return player:GetNetworkPing()*1000 end)
    if ok and v and v>0 then return math.floor(v) end
    return 0
end

local function getCharStats()
    local char=player.Character; if not char then return "N/A","N/A",100,100 end
    local hum=char:FindFirstChildOfClass("Humanoid"); local hrp=char:FindFirstChild("HumanoidRootPart")
    local hp=hum and string.format("%.0f / %.0f",hum.Health,hum.MaxHealth) or "N/A"
    local hpN=hum and hum.Health or 100; local hpM=hum and hum.MaxHealth or 100
    local pos=hrp and string.format("%.0f, %.0f, %.0f",hrp.Position.X,hrp.Position.Y,hrp.Position.Z) or "N/A"
    return hp,pos,hpN,hpM
end

local function getFischStatus()
    local char=player.Character; if not char then return "Belum Spawn" end
    local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return "Unknown" end
    if hum:GetState()==Enum.HumanoidStateType.Dead then return "Mati" end
    local tool=char:FindFirstChildOfClass("Tool"); local tn=tool and tool.Name:lower() or ""
    if tn:find("rod") or tn:find("fish") then
        local anim=hum:FindFirstChild("Animator")
        if anim then
            for _,t in ipairs(anim:GetPlayingAnimationTracks()) do
                local n=t.Name:lower()
                if n:find("cast") then return "Casting..." end
                if n:find("reel") or n:find("pull") then return "Reeling!" end
                if n:find("wait") or n:find("idle") then return "Menunggu..." end
            end
        end
        return "Fishing"
    end
    if IS_AFK then return "AFK" end
    local s=hum:GetState()
    if s==Enum.HumanoidStateType.Running then return "Jalan" end
    if s==Enum.HumanoidStateType.Seated then return "Duduk" end
    if s==Enum.HumanoidStateType.Swimming then return "Renang" end
    return "Main"
end

local function uptimeFmt(s)
    local h=math.floor(s/3600); local m=math.floor((s%3600)/60); local sc=s%60
    if h>0 then return h.."j "..m.."m "..sc.."s" elseif m>0 then return m.."m "..sc.."s" else return sc.."s" end
end
local function getCoinRate()
    local el=math.max(1,os.time()-startTime); return math.floor((coinEarned/el)*3600)
end
local function dot(val,good,warn,inv)
    local isGood=inv and val>=good or val<=good; local isBad=inv and val<warn or val>warn
    if isGood then return "🟢" elseif isBad then return "🔴" else return "🟡" end
end

local function showNotif(text,isOk)
    if notifGui then pcall(function() notifGui:Destroy() end) end
    local ng=Instance.new("ScreenGui",playerGui); ng.Name="YURXZ_Notif"; ng.ResetOnSpawn=false; ng.IgnoreGuiInset=true
    notifGui=ng
    local fr=Instance.new("Frame",ng)
    fr.Size=UDim2.new(0,220,0,36); fr.Position=UDim2.new(1,10,1,-60)
    fr.BackgroundColor3=isOk and Color3.fromRGB(5,14,44) or Color3.fromRGB(44,5,5); fr.BorderSizePixel=0
    Instance.new("UICorner",fr).CornerRadius=UDim.new(0,8)
    local st=Instance.new("UIStroke",fr)
    st.Color=isOk and Color3.fromRGB(60,150,255) or Color3.fromRGB(255,65,65); st.Thickness=1.2
    local lbl=Instance.new("TextLabel",fr)
    lbl.Size=UDim2.new(1,-10,1,0); lbl.Position=UDim2.new(0,8,0,0); lbl.BackgroundTransparency=1
    lbl.Text=text; lbl.TextColor3=isOk and Color3.fromRGB(160,225,255) or Color3.fromRGB(255,145,145)
    lbl.TextSize=9; lbl.Font=Enum.Font.GothamBold; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.TextWrapped=true
    TweenService:Create(fr,TweenInfo.new(0.3,Enum.EasingStyle.Back),{Position=UDim2.new(1,-230,1,-60)}):Play()
    task.delay(3,function()
        if fr and fr.Parent then
            TweenService:Create(fr,TweenInfo.new(0.2),{Position=UDim2.new(1,10,1,-60)}):Play()
            task.delay(0.3,function() pcall(function() ng:Destroy() end) end)
        end
    end)
end

local function enc(v)
    if type(v)=="string" then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"' end
    return tostring(v)
end
local function encF(f) return '{"name":'..enc(f.name)..',"value":'..enc(f.value)..',"inline":'..tostring(f.inline)..'}' end
local function sendWebhook(body)
    local h=getHttp(); if not h then return false,"No HTTP" end
    local ok,err=pcall(function() h({Url=CONFIG.WEBHOOK_URL,Method="POST",Headers={["Content-Type"]="application/json"},Body=body}) end)
    return ok,err
end

local function sendReport()
    reportCount=reportCount+1
    local pingN=getPingRaw(); local memMB=getMemMB(); local fps=math.min(fpsVal,60); local cpu=math.min(cpuVal,100)
    local hp,pos,hpN,hpM=getCharStats(); local fischSt=getFischStatus(); local hpPct=hpM>0 and hpN/hpM or 1
    local coinRate=getCoinRate(); local pCount=#Players:GetPlayers()
    local uptime=uptimeFmt(os.time()-startTime); local waktu=os.date("%d/%m/%Y  %H:%M:%S")
    local color
    if hpPct<=0 then color=15158332
    elseif hpPct<0.25 then color=15105570 elseif pingN>300 then color=15105570
    elseif memMB>MEM_CRIT then color=15105570 elseif cpu>85 then color=15105570
    elseif pingN>150 then color=16776960 elseif memMB>MEM_WARN then color=16776960
    elseif cpu>60 then color=16776960 elseif IS_AFK then color=9807270 else color=3447003 end
    local overallStatus,statusEmoji
    if hpPct<=0 then overallStatus="Karakter Mati"; statusEmoji="💀"
    elseif hpPct<0.3 then overallStatus="HP Kritis"; statusEmoji="🔴"
    elseif pingN>300 then overallStatus="Lag Parah"; statusEmoji="🔴"
    elseif memMB>MEM_CRIT then overallStatus="Memory Penuh"; statusEmoji="🔴"
    elseif cpu>85 then overallStatus="CPU Tinggi"; statusEmoji="🔴"
    elseif pingN>150 then overallStatus="Lag Ringan"; statusEmoji="🟡"
    elseif memMB>MEM_WARN then overallStatus="Memory Tinggi"; statusEmoji="🟡"
    elseif cpu>60 then overallStatus="CPU Sedang"; statusEmoji="🟡"
    elseif IS_AFK then overallStatus="AFK"; statusEmoji="😴"
    else overallStatus="Normal"; statusEmoji="🟢" end
    local SEP={name="\u{200b}",value="\u{200b}",inline=false}
    local fields={
        {name="🎣  Status",value="```"..fischSt.."```",inline=true},
        {name="👤  Akun",value="||"..player.Name.."||",inline=true},
        {name="📊  Kondisi",value="```"..statusEmoji.." "..overallStatus.."```",inline=true},
        SEP,
        {name="📶  Ping",value=dot(pingN,80,200).."  **"..pingN.." ms**",inline=true},
        {name="🧠  RAM",value=dot(memMB,MEM_WARN,MEM_CRIT).."  **"..memStr(memMB).."**",inline=true},
        {name="🖥️  FPS",value=dot(fps,50,30,true).."  **"..fps.."**",inline=true},
        {name="💻  CPU",value=dot(cpu,60,85).."  **"..cpu.."%**",inline=true},
        {name="\u{200b}",value="\u{200b}",inline=true},
        {name="\u{200b}",value="\u{200b}",inline=true},
        SEP,
        {name="👥  Player",value="`"..pCount.." / "..Players.MaxPlayers.."`",inline=true},
        {name="📍  Posisi",value="`"..pos.."`",inline=true},
        {name="⭐  Level",value="`"..levelCurrent.."`",inline=true},
        SEP,
        {name="💰  "..coinLabel,value="`"..coinCurrent.."`",inline=true},
        {name="📈  +Sesi",value="`+"..coinEarned.."`",inline=true},
        {name="⚡  /Jam",value="`~"..coinRate.."`",inline=true},
        SEP,
        {name="📋  Laporan",value="`#"..reportCount.."`",inline=true},
        {name="⏭️  Interval",value="`"..INTERVAL.."s`",inline=true},
        {name="🕐  Waktu",value="`"..waktu.."`",inline=true},
    }
    local fa={}; for _,f in ipairs(fields) do table.insert(fa,encF(f)) end
    local desc="||"..player.Name.."||  "..EXEC_ICON.."  "..EXEC_NAME.."\nStatus: "..(IS_AFK and "**AFK**" or "**Online**").."  •  Uptime: **"..uptime.."**".."\n\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}"
    local thumbnail=""
    pcall(function()
        local res=game:HttpGet("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds="..player.UserId.."&size=150x150&format=Png&isCircular=false")
        local url=res:match('"imageUrl":"(https://[^"]+)"')
        if url then thumbnail=url end
    end)
    local footerText="MONITORING DEVICE YURXZ v8.0  •  "..player.Name.."  •  "..waktu
    local body='{"username":'..enc("MONITORING DEVICE YURXZ")..',"avatar_url":'..enc(CONFIG.AVATAR_URL)..',"embeds":[{"title":'..enc("📡  YURXZ MONITOR  —  Laporan  #"..reportCount)..',"description":'..enc(desc)..',"color":'..color..',"fields":['..table.concat(fa,",")..'],"thumbnail":{"url":'..enc(thumbnail)..'},"footer":{"text":'..enc(footerText)..',"icon_url":'..enc(CONFIG.AVATAR_URL)..'}' ..'}]}'
    local ok,_=sendWebhook(body)
    if ok then disconnectSent=false; showNotif("✅ #"..reportCount.." | +"..coinEarned.." coin | "..fischSt,true)
    else showNotif("❌ Gagal kirim #"..reportCount,false) end
end

local function sendDisconnectAlert(reason)
    if disconnectSent then return end; disconnectSent=true
    local mention=CONFIG.DISCORD_ID~="GANTI_USER_ID_DISCORD" and "<@"..CONFIG.DISCORD_ID..">" or ""
    local waktu=os.date("%d/%m/%Y  %H:%M:%S")
    local fields={
        {name="⚠️  Alasan",value="```"..reason.."```",inline=true},
        {name="⏱️  Uptime",value="```"..uptimeFmt(os.time()-startTime).."```",inline=true},
        {name="\u{200b}",value="\u{200b}",inline=true},
        {name="\u{200b}",value="\u{200b}",inline=false},
        {name="💰  +Coin",value="`+"..coinEarned.."`",inline=true},
        {name="📋  Laporan",value="`#"..reportCount.."`",inline=true},
        {name="🕐  Waktu",value="`"..waktu.."`",inline=true},
    }
    local fa={}; for _,f in ipairs(fields) do table.insert(fa,encF(f)) end
    local content=(mention~="" and (mention.."\n") or "").."⚠️ **DISCONNECT TERDETEKSI!**"
    local body='{"content":'..enc(content)..',"username":'..enc("MONITORING DEVICE YURXZ")..',"avatar_url":'..enc(CONFIG.AVATAR_URL)..',"embeds":[{"title":'..enc("🔴  DISCONNECT  —  "..player.Name)..',"description":'..enc("```diff\n- Koneksi terputus! Segera cek game.\n```")..',"color":15158332,"fields":['..table.concat(fa,",")..'],"footer":{"text":'..enc("YURXZ v8.0  •  "..waktu)..',"icon_url":'..enc(CONFIG.AVATAR_URL)..'}' ..'}]}'
    local ok,_=sendWebhook(body)
    if ok then showNotif("🔴 DISCONNECT! Alert terkirim!",false) end
end

local function startDisconnectWatch()
    task.spawn(function()
        local badPing=0
        while running do
            task.wait(5); if not running then break end
            local p=getPingRaw()
            if p>0 and p<9000 then badPing=0; disconnectSent=false
            else badPing=badPing+1 end
            if badPing>=6 and not disconnectSent then sendDisconnectAlert("Ping timeout 30 detik"); badPing=0 end
            local gok,loaded=pcall(function() return game:IsLoaded() end)
            if gok and not loaded and not disconnectSent then sendDisconnectAlert("Game tidak loaded") end
        end
    end)
end

-- ══════════════════════════════════════════
--  GUI COMPACT
-- ══════════════════════════════════════════
task.wait(0.3)
if not playerGui or not playerGui.Parent then warn("[YURXZ] playerGui tidak tersedia"); return end

local C={
    bg=Color3.fromRGB(10,16,45), surface=Color3.fromRGB(18,28,72),
    card=Color3.fromRGB(26,42,100), accent=Color3.fromRGB(60,130,255),
    accent2=Color3.fromRGB(110,180,255), green=Color3.fromRGB(60,235,145),
    red=Color3.fromRGB(255,85,85), yellow=Color3.fromRGB(255,215,55),
    text=Color3.fromRGB(228,242,255), muted=Color3.fromRGB(115,155,225),
    border=Color3.fromRGB(55,95,205),
}

local Gui=Instance.new("ScreenGui",playerGui)
Gui.Name="YURXZ_v8"; Gui.ResetOnSpawn=false; Gui.IgnoreGuiInset=true; Gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling

-- Panel utama — lebih kecil: lebar 260 (vs 340 sebelumnya)
local Main=Instance.new("Frame",Gui)
Main.Size=UDim2.new(0,260,0,0); Main.Position=UDim2.new(0.5,-130,0.5,-150)
Main.BackgroundColor3=C.bg; Main.BorderSizePixel=0; Main.AutomaticSize=Enum.AutomaticSize.Y
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,12)
local mainStroke=Instance.new("UIStroke",Main)
mainStroke.Color=C.accent; mainStroke.Thickness=1.2; mainStroke.Transparency=0.15

-- Glow line atas
local tLine=Instance.new("Frame",Main)
tLine.Size=UDim2.new(0.5,0,0,2); tLine.Position=UDim2.new(0.25,0,0,0)
tLine.BackgroundColor3=C.accent2; tLine.BorderSizePixel=0
Instance.new("UICorner",tLine).CornerRadius=UDim.new(0,2)
Instance.new("UIGradient",tLine).Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.new(0,0,0)),
    ColorSequenceKeypoint.new(0.5,Color3.new(1,1,1)),
    ColorSequenceKeypoint.new(1,Color3.new(0,0,0)),
})

local Content=Instance.new("Frame",Main)
Content.Size=UDim2.new(1,-16,0,0); Content.Position=UDim2.new(0,8,0,8)
Content.BackgroundTransparency=1; Content.BorderSizePixel=0; Content.AutomaticSize=Enum.AutomaticSize.Y
local uiL=Instance.new("UIListLayout",Content)
uiL.Padding=UDim.new(0,4); uiL.SortOrder=Enum.SortOrder.LayoutOrder

-- Header
local hdrRow=Instance.new("Frame",Content)
hdrRow.Size=UDim2.new(1,0,0,22); hdrRow.BackgroundTransparency=1; hdrRow.BorderSizePixel=0; hdrRow.LayoutOrder=1

local gdot=Instance.new("Frame",hdrRow)
gdot.Size=UDim2.new(0,7,0,7); gdot.Position=UDim2.new(0,0,0.5,-3.5)
gdot.BackgroundColor3=C.accent; gdot.BorderSizePixel=0
Instance.new("UICorner",gdot).CornerRadius=UDim.new(1,0)
task.spawn(function()
    while Gui.Parent do
        TweenService:Create(gdot,TweenInfo.new(1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundColor3=C.accent2}):Play(); task.wait(1)
        TweenService:Create(gdot,TweenInfo.new(1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundColor3=C.accent}):Play(); task.wait(1)
    end
end)

local tl=Instance.new("TextLabel",hdrRow)
tl.Size=UDim2.new(1,-12,1,0); tl.Position=UDim2.new(0,12,0,0); tl.BackgroundTransparency=1
tl.Text="YURXZ  •  "..EXEC_ICON.." "..EXEC_NAME
tl.TextColor3=C.text; tl.TextSize=10; tl.Font=Enum.Font.GothamBold; tl.TextXAlignment=Enum.TextXAlignment.Left

local div=Instance.new("Frame",Content)
div.Size=UDim2.new(1,0,0,1); div.BackgroundColor3=C.border; div.BorderSizePixel=0; div.LayoutOrder=2

-- Webhook input (compact, 1 baris)
local function mkInput(parent, placeholder, default, order)
    local card=Instance.new("Frame",parent)
    card.Size=UDim2.new(1,0,0,0); card.BackgroundColor3=C.surface
    card.BorderSizePixel=0; card.LayoutOrder=order; card.AutomaticSize=Enum.AutomaticSize.Y
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,8)
    Instance.new("UIStroke",card).Color=C.border
    local pad=Instance.new("UIPadding",card)
    pad.PaddingLeft=UDim.new(0,6); pad.PaddingRight=UDim.new(0,6)
    pad.PaddingTop=UDim.new(0,4); pad.PaddingBottom=UDim.new(0,4)
    local inner=Instance.new("Frame",card)
    inner.Size=UDim2.new(1,0,0,0); inner.BackgroundTransparency=1
    inner.BorderSizePixel=0; inner.AutomaticSize=Enum.AutomaticSize.Y
    Instance.new("UIListLayout",inner).Padding=UDim.new(0,2)

    -- Row: box + save + clear
    local row=Instance.new("Frame",inner)
    row.Size=UDim2.new(1,0,0,24); row.BackgroundTransparency=1; row.BorderSizePixel=0
    local rl=Instance.new("UIListLayout",row); rl.FillDirection=Enum.FillDirection.Horizontal; rl.Padding=UDim.new(0,3)

    local box=Instance.new("TextBox",row)
    box.Size=UDim2.new(1,-58,1,0); box.BackgroundColor3=C.card; box.BorderSizePixel=0
    box.PlaceholderText=placeholder; box.PlaceholderColor3=Color3.fromRGB(65,95,170)
    box.Text=(default and not default:find("GANTI")) and default or ""
    box.TextColor3=C.text; box.TextSize=9; box.Font=Enum.Font.Gotham
    box.ClearTextOnFocus=false; box.TextTruncate=Enum.TextTruncate.AtEnd
    box.TextXAlignment=Enum.TextXAlignment.Left
    Instance.new("UICorner",box).CornerRadius=UDim.new(0,6)
    Instance.new("UIPadding",box).PaddingLeft=UDim.new(0,6)
    local st=Instance.new("UIStroke",box); st.Color=C.border; st.Thickness=1
    box.Focused:Connect(function() TweenService:Create(st,TweenInfo.new(0.15),{Color=C.accent,Thickness=1.5}):Play() end)
    box.FocusLost:Connect(function() TweenService:Create(st,TweenInfo.new(0.15),{Color=C.border,Thickness=1}):Play() end)

    local saveBtn=Instance.new("TextButton",row)
    saveBtn.Size=UDim2.new(0,24,1,0); saveBtn.BackgroundColor3=C.green
    saveBtn.TextColor3=Color3.fromRGB(5,30,20); saveBtn.Text="💾"; saveBtn.TextSize=11
    saveBtn.Font=Enum.Font.GothamBold; saveBtn.AutoButtonColor=false; saveBtn.BorderSizePixel=0
    Instance.new("UICorner",saveBtn).CornerRadius=UDim.new(0,5)

    local clearBtn=Instance.new("TextButton",row)
    clearBtn.Size=UDim2.new(0,24,1,0); clearBtn.BackgroundColor3=Color3.fromRGB(80,20,20)
    clearBtn.TextColor3=Color3.fromRGB(255,100,100); clearBtn.Text="✕"; clearBtn.TextSize=11
    clearBtn.Font=Enum.Font.GothamBold; clearBtn.AutoButtonColor=false; clearBtn.BorderSizePixel=0
    Instance.new("UICorner",clearBtn).CornerRadius=UDim.new(0,5)

    local saveLbl=Instance.new("TextLabel",inner)
    saveLbl.Size=UDim2.new(1,0,0,8); saveLbl.BackgroundTransparency=1
    saveLbl.Text=""; saveLbl.TextColor3=C.green; saveLbl.TextSize=7
    saveLbl.Font=Enum.Font.Gotham; saveLbl.TextXAlignment=Enum.TextXAlignment.Left

    return box,saveBtn,clearBtn,saveLbl
end

-- Label kecil webhook
local wLbl=Instance.new("TextLabel",Content)
wLbl.Size=UDim2.new(1,0,0,9); wLbl.BackgroundTransparency=1; wLbl.LayoutOrder=3
wLbl.Text="🔗  WEBHOOK URL"; wLbl.TextColor3=C.accent2; wLbl.TextSize=8
wLbl.Font=Enum.Font.Gotham; wLbl.TextXAlignment=Enum.TextXAlignment.Left

local InputBox,SaveWebhookBtn,ClearWebhookBtn,WebhookSaveLbl=mkInput(Content,"https://discord.com/api/webhooks/...",CONFIG.WEBHOOK_URL,4)

local dLbl=Instance.new("TextLabel",Content)
dLbl.Size=UDim2.new(1,0,0,9); dLbl.BackgroundTransparency=1; dLbl.LayoutOrder=5
dLbl.Text="🏷️  DISCORD ID  (opsional, untuk ping)"; dLbl.TextColor3=C.accent2; dLbl.TextSize=8
dLbl.Font=Enum.Font.Gotham; dLbl.TextXAlignment=Enum.TextXAlignment.Left

local DiscordIDBox,SaveIDBtn,ClearIDBtn,IDSaveLbl=mkInput(Content,"Contoh: 123456789012345678",CONFIG.DISCORD_ID,6)

-- Isi dari saved data
if gget("YURXZ_SAVED_WEBHOOK") and gget("YURXZ_SAVED_WEBHOOK")~="" then
    InputBox.Text=gget("YURXZ_SAVED_WEBHOOK"); WebhookSaveLbl.Text="✅ Tersimpan"
end
if gget("YURXZ_SAVED_DISCORDID") and gget("YURXZ_SAVED_DISCORDID")~="" then
    DiscordIDBox.Text=gget("YURXZ_SAVED_DISCORDID"); IDSaveLbl.Text="✅ Tersimpan"
end

SaveWebhookBtn.MouseButton1Click:Connect(function()
    local val=InputBox.Text:gsub("%s+","")
    if val~="" and val:find("discord%.com/api/webhooks") then
        gset("YURXZ_SAVED_WEBHOOK",val); WebhookSaveLbl.Text="✅ Tersimpan!"; WebhookSaveLbl.TextColor3=C.green
    else WebhookSaveLbl.Text="❌ Tidak valid!"; WebhookSaveLbl.TextColor3=C.red end
end)
ClearWebhookBtn.MouseButton1Click:Connect(function()
    gset("YURXZ_SAVED_WEBHOOK",""); InputBox.Text=""; WebhookSaveLbl.Text="🗑️ Dihapus"; WebhookSaveLbl.TextColor3=C.muted
end)
SaveIDBtn.MouseButton1Click:Connect(function()
    local val=DiscordIDBox.Text:gsub("%s+","")
    if val~="" then gset("YURXZ_SAVED_DISCORDID",val); IDSaveLbl.Text="✅ Tersimpan!"; IDSaveLbl.TextColor3=C.green
    else IDSaveLbl.Text="❌ Kosong!"; IDSaveLbl.TextColor3=C.red end
end)
ClearIDBtn.MouseButton1Click:Connect(function()
    gset("YURXZ_SAVED_DISCORDID",""); DiscordIDBox.Text=""; IDSaveLbl.Text="🗑️ Dihapus"; IDSaveLbl.TextColor3=C.muted
end)

-- Interval (compact, tombol kecil)
local intLbl=Instance.new("TextLabel",Content)
intLbl.Size=UDim2.new(1,0,0,9); intLbl.BackgroundTransparency=1; intLbl.LayoutOrder=7
intLbl.Text="⏱️  INTERVAL"; intLbl.TextColor3=C.accent2; intLbl.TextSize=8
intLbl.Font=Enum.Font.Gotham; intLbl.TextXAlignment=Enum.TextXAlignment.Left

local intRow=Instance.new("Frame",Content)
intRow.Size=UDim2.new(1,0,0,22); intRow.BackgroundTransparency=1; intRow.BorderSizePixel=0; intRow.LayoutOrder=8
local il=Instance.new("UIListLayout",intRow); il.FillDirection=Enum.FillDirection.Horizontal; il.Padding=UDim.new(0,3)

local intervals={30,60,120,300}; local intNames={"30s","1m","2m","5m"}
local selectedInt=2; INTERVAL=intervals[selectedInt]; local intBtns={}

for i=1,#intervals do
    local b=Instance.new("TextButton",intRow)
    b.Size=UDim2.new(0.25,-3,1,0)
    b.BackgroundColor3=i==selectedInt and C.accent or C.card
    b.TextColor3=i==selectedInt and Color3.fromRGB(255,255,255) or C.muted
    b.Text=intNames[i]; b.TextSize=9; b.Font=Enum.Font.GothamBold; b.AutoButtonColor=false
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6); intBtns[i]=b
    b.MouseButton1Click:Connect(function()
        selectedInt=i; INTERVAL=intervals[i]
        for j,btn in ipairs(intBtns) do
            TweenService:Create(btn,TweenInfo.new(0.15),{
                BackgroundColor3=j==selectedInt and C.accent or C.card,
                TextColor3=j==selectedInt and Color3.fromRGB(255,255,255) or C.muted,
            }):Play()
        end
    end)
end

-- Status label
local StatusLbl=Instance.new("TextLabel",Content)
StatusLbl.Size=UDim2.new(1,0,0,10); StatusLbl.BackgroundTransparency=1; StatusLbl.LayoutOrder=9
StatusLbl.Text=""; StatusLbl.TextColor3=C.muted; StatusLbl.TextSize=8
StatusLbl.Font=Enum.Font.Gotham; StatusLbl.TextXAlignment=Enum.TextXAlignment.Center

-- Tombol START/STOP (lebih tipis)
local ActionBtn=Instance.new("TextButton",Content)
ActionBtn.Size=UDim2.new(1,0,0,30); ActionBtn.LayoutOrder=10
ActionBtn.BackgroundColor3=C.accent; ActionBtn.AutoButtonColor=false
ActionBtn.TextColor3=Color3.fromRGB(255,255,255)
ActionBtn.Text="▶  START"; ActionBtn.TextSize=11; ActionBtn.Font=Enum.Font.GothamBold
Instance.new("UICorner",ActionBtn).CornerRadius=UDim.new(0,8)
local btnGrad=Instance.new("UIGradient",ActionBtn)
btnGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(60,130,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(25,80,230))})
btnGrad.Rotation=135

local botPad=Instance.new("Frame",Content)
botPad.Size=UDim2.new(1,0,0,4); botPad.BackgroundTransparency=1; botPad.BorderSizePixel=0; botPad.LayoutOrder=11

ActionBtn.MouseEnter:Connect(function() if not running then TweenService:Create(ActionBtn,TweenInfo.new(0.12),{BackgroundColor3=C.accent2}):Play() end end)
ActionBtn.MouseLeave:Connect(function() if not running then TweenService:Create(ActionBtn,TweenInfo.new(0.12),{BackgroundColor3=C.accent}):Play() end end)

-- Drag
local dragging,dragStart,startPos
Main.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
        dragging=true; dragStart=inp.Position; startPos=Main.Position end
end)
Main.InputEnded:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)
UIS.InputChanged:Connect(function(inp)
    if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then
        local d=inp.Position-dragStart
        Main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)

-- START / STOP logic
local function stopMonitor()
    running=false; ActionBtn.Text="▶  START"
    btnGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(60,130,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(25,80,230))})
    TweenService:Create(ActionBtn,TweenInfo.new(0.2),{BackgroundColor3=C.accent}):Play()
    TweenService:Create(mainStroke,TweenInfo.new(0.3),{Color=C.accent}):Play()
    StatusLbl.Text="⏹️  Stop  •  #"..reportCount.."  •  +"..coinEarned.." coin"; StatusLbl.TextColor3=C.yellow
    showNotif("⏹️ Stop | #"..reportCount.." | +"..coinEarned.." coin",false)
end

ActionBtn.MouseButton1Click:Connect(function()
    if running then stopMonitor() return end
    local url=InputBox.Text:gsub("%s+",""); local did=DiscordIDBox.Text:gsub("%s+","")
    if url=="" or not url:find("discord%.com/api/webhooks") then
        StatusLbl.Text="❌  Webhook tidak valid!"; StatusLbl.TextColor3=C.red
        local orig=Main.Position
        task.spawn(function()
            for _=1,4 do
                TweenService:Create(Main,TweenInfo.new(0.04),{Position=orig+UDim2.new(0,5,0,0)}):Play(); task.wait(0.04)
                TweenService:Create(Main,TweenInfo.new(0.04),{Position=orig-UDim2.new(0,5,0,0)}):Play(); task.wait(0.04)
            end
            TweenService:Create(Main,TweenInfo.new(0.04),{Position=orig}):Play()
        end); return
    end
    CONFIG.WEBHOOK_URL=url; if did~="" then CONFIG.DISCORD_ID=did end
    INTERVAL=intervals[selectedInt]; running=true; reportCount=0; startTime=os.time()
    disconnectSent=false; coinStart=coinCurrent; coinEarned=0; lastMoveTime=os.time(); IS_AFK=false
    ActionBtn.Text="⏹  STOP"
    btnGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(210,35,35)),ColorSequenceKeypoint.new(1,Color3.fromRGB(150,12,12))})
    TweenService:Create(ActionBtn,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(180,22,22)}):Play()
    TweenService:Create(mainStroke,TweenInfo.new(0.3),{Color=C.green}):Play()
    StatusLbl.Text="🟢  AKTIF  •  Tiap "..INTERVAL.."s"..(did~="" and "  •  🏷️" or "")
    StatusLbl.TextColor3=C.green; showNotif("🚀 Aktif! Tiap "..INTERVAL.."s",true)
    -- GUI fade out otomatis
    task.delay(1.5,function()
        if Gui and Gui.Parent then
            TweenService:Create(Main,TweenInfo.new(0.5,Enum.EasingStyle.Quad),{BackgroundTransparency=1,Position=Main.Position-UDim2.new(0,0,0,15)}):Play()
            for _,obj in ipairs(Main:GetDescendants()) do
                if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then TweenService:Create(obj,TweenInfo.new(0.4),{TextTransparency=1}):Play() end
                if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextBox") or obj:IsA("TextLabel") then TweenService:Create(obj,TweenInfo.new(0.4),{BackgroundTransparency=1}):Play() end
            end
            task.delay(0.6,function() if Gui then Gui:Destroy() end end)
        end
    end)
    task.spawn(sendReport)
    task.spawn(function()
        while running do task.wait(INTERVAL); if running then sendReport() end end
    end)
    startDisconnectWatch()
end)

-- Open animation
Main.BackgroundTransparency=1
TweenService:Create(Main,TweenInfo.new(0.4,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{BackgroundTransparency=0}):Play()

gset("MD_Stop",function() running=false; gset("YURXZ_RUNNING",false); stopMonitor() end)
print("[YURXZ v8.0] ✅ "..EXEC_ICON.." "..EXEC_NAME)
print("[YURXZ v8.0] Isi webhook + Discord ID → klik START")

local E, L, V, P, G = unpack(ElvUI)
local LSM = E.Libs.LSM
local WUI = E:GetModule('WishFlex')
local mod = WUI:GetModule('AuraGlow', true) or WUI:NewModule('AuraGlow', 'AceHook-3.0', 'AceEvent-3.0')

local LCG = E.Libs and E.Libs.CustomGlow
if not LCG then LCG = LibStub and LibStub("LibCustomGlow-1.0", true) end

-- =========================================
-- [内存泄漏克星]：双引擎预分配静态池
-- =========================================
local activeSkillFrames = {}
local activeBuffFrames = {}
local targetAuraCache = {}
local playerAuraCache = {}
local BaseSpellCache = {}
mod.fastTrackedBuffs = {}

local MonitorAnchor
local ActiveBars = {}
local BarPool = {}

local IconAnchor
local ActiveIcons = {}
local IconPool = {}

-- =========================================
-- 1. 初始化数据库
-- =========================================
P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.auraGlow = true
P["WishFlex"].auraGlow = {
    enable = true,
    
    glowType = "pixel", glowUseCustomColor = true, glowColor = {r = 1, g = 0.82, b = 0, a = 1},
    glowPixelLines = 8, glowPixelFrequency = 0.25, glowPixelLength = 10, glowPixelThickness = 2, glowPixelXOffset = 0, glowPixelYOffset = 0,
    glowAutocastParticles = 4, glowAutocastFrequency = 0.2, glowAutocastScale = 1, glowAutocastXOffset = 0, glowAutocastYOffset = 0,
    glowButtonFrequency = 0, glowProcDuration = 1, glowProcXOffset = 0, glowProcYOffset = 0,
    
    text = { font = "Expressway", fontSize = 20, fontOutline = "OUTLINE", color = {r = 1, g = 0.82, b = 0}, offsetX = 0, offsetY = 0 },

    monitor = {
        enable = true, alignWithClassResource = true, width = 250, height = 14, spacing = 1, growth = "UP",
        barTexture = "ElvUI Norm", barBgColor = {r = 0.2, g = 0.2, b = 0.2, a = 0.8}, onlyCombat = false,
        anchorOffsetX = 0, anchorOffsetY = 1,
        textFont = "Expressway", textFontSize = 20, textFontOutline = "OUTLINE", textColor = {r = 1, g = 1, b = 1, a = 1},
        textPosition = "RIGHT", textOffsetX = 0, textOffsetY = 0
    },

    icon = {
        enable = true, size = 36, spacing = 4, growth = "RIGHT", onlyCombat = false,
        anchorOffsetX = 0, anchorOffsetY = 20,
        textFont = "Expressway", textFontSize = 20, textFontOutline = "OUTLINE", textColor = {r = 1, g = 1, b = 1, a = 1},
        textOffsetX = 0, textOffsetY = 0,
        stackFontSize = 14, stackColor = {r = 1, g = 1, b = 1, a = 1}
    },

    spells = {}
}

local OverlayFrames = {}
local ActiveGlows = {}
mod.trackedAuras = {} 
mod.manualTrackers = {} 

-- =========================================
-- 2. 核心防爆引擎
-- =========================================
local function IsSafeValue(val)
    if val == nil then return false end
    if type(issecretvalue) == "function" and issecretvalue(val) then return false end
    return true
end

local function GetBaseSpellFast(spellID)
    if not IsSafeValue(spellID) then return nil end
    if BaseSpellCache[spellID] == nil then
        local base = spellID
        pcall(function()
            if C_Spell and C_Spell.GetBaseSpell then base = C_Spell.GetBaseSpell(spellID) or spellID end
        end)
        BaseSpellCache[spellID] = base
    end
    return BaseSpellCache[spellID]
end

local function MatchesSpellID(info, targetID)
    if not info then return false end
    if IsSafeValue(info.spellID) and (info.spellID == targetID or info.overrideSpellID == targetID) then return true end
    if info.linkedSpellIDs then
        for i = 1, #info.linkedSpellIDs do
            if IsSafeValue(info.linkedSpellIDs[i]) and info.linkedSpellIDs[i] == targetID then return true end
        end
    end
    return GetBaseSpellFast(info.spellID) == targetID
end

local function VerifyAuraAlive(checkID, checkUnit)
    if not IsSafeValue(checkID) then return false end
    local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(checkUnit, checkID)
    return auraData ~= nil
end

local function IsValidActiveAura(aura)
    if type(aura) ~= "table" then return false end
    local isValid = false
    pcall(function()
        if aura.auraInstanceID then
            isValid = true
            if IsSafeValue(aura.duration) and type(aura.duration) == "number" and aura.duration <= 0 then
                isValid = false
            end
        end
    end)
    return isValid
end

function mod:BuildFastCache()
    wipe(mod.fastTrackedBuffs)
    if E.db.WishFlex and E.db.WishFlex.auraGlow and E.db.WishFlex.auraGlow.spells then
        for k, v in pairs(E.db.WishFlex.auraGlow.spells) do
            local sid = tonumber(k)
            local bid = (type(v) == "table" and v.buffID) or sid
            if sid then mod.fastTrackedBuffs[sid] = true end
            if bid then mod.fastTrackedBuffs[bid] = true end
        end
    end
end

local function ShouldHideFrame(info)
    if not info then return false end
    if IsSafeValue(info.spellID) then
        if mod.fastTrackedBuffs[info.spellID] or mod.fastTrackedBuffs[info.overrideSpellID] then return true end
        local baseID = GetBaseSpellFast(info.spellID)
        if baseID and mod.fastTrackedBuffs[baseID] then return true end
    end
    if info.linkedSpellIDs then
        for i = 1, #info.linkedSpellIDs do
            local lid = info.linkedSpellIDs[i]
            if IsSafeValue(lid) and mod.fastTrackedBuffs[lid] then return true end
        end
    end
    return false
end

-- =========================================
-- 3. 渲染引擎 - 极简纯净排版监控 (进度条+图标)
-- =========================================
local function GetMonitorDimensions()
    local db = E.db.WishFlex.auraGlow.monitor
    local w, h = db.width, db.height
    if db.alignWithClassResource and _G.WishFlex_ClassResourceAnchor then
        local crW = _G.WishFlex_ClassResourceAnchor:GetWidth()
        if crW and crW > 10 then w = crW end
        if E.db.WishFlex.classResource and E.db.WishFlex.classResource.power then
            local crH = E.db.WishFlex.classResource.power.height
            if crH and crH > 0 then h = crH end
        end
    end
    return w, h
end

local function UpdateSegments(bar, maxStacks)
    bar.segments = bar.segments or {}
    for _, seg in ipairs(bar.segments) do seg:Hide() end
    if not maxStacks or maxStacks <= 1 then return end
    
    local w = bar.statusBar:GetWidth()
    if w == 0 then w, _ = GetMonitorDimensions() end
    
    local step = w / maxStacks
    for i = 1, maxStacks - 1 do
        local seg = bar.segments[i]
        if not seg then
            seg = bar.gridFrame:CreateTexture(nil, "OVERLAY", nil, 7)
            seg:SetColorTexture(0, 0, 0, 1) 
            seg:SetWidth(E.mult) 
            bar.segments[i] = seg
        end
        local _, targetHeight = GetMonitorDimensions()
        seg:SetHeight(targetHeight)
        seg:ClearAllPoints()
        seg:SetPoint("TOPLEFT", bar.statusBar, "TOPLEFT", step * i, 0)
        seg:SetPoint("BOTTOMLEFT", bar.statusBar, "BOTTOMLEFT", step * i, 0)
        seg:Show()
    end
end

local function ApplySingleBarVisuals(bar)
    local db = E.db.WishFlex.auraGlow.monitor
    local tex = LSM:Fetch("statusbar", db.barTexture)
    local w, h = GetMonitorDimensions()
    bar:SetSize(w, h)
    bar.statusBar:SetInside(bar)
    bar.statusBar:SetStatusBarTexture(tex)
    bar.statusBar.bg:SetTexture(tex)
    if bar.segments then for _, seg in ipairs(bar.segments) do seg:SetHeight(h) end end
end

local function SyncBarTextVisuals(bar)
    local cfg = E.db.WishFlex.auraGlow.monitor
    local fontPath = LSM:Fetch('font', cfg.textFont)
    if bar.lastFont ~= fontPath or bar.lastSize ~= cfg.textFontSize or bar.lastOutline ~= cfg.textFontOutline then
        bar.durationText:SetFont(fontPath, cfg.textFontSize, cfg.textFontOutline)
        bar.lastFont, bar.lastSize, bar.lastOutline = fontPath, cfg.textFontSize, cfg.textFontOutline
    end
    local tc = cfg.textColor or {r=1, g=1, b=1, a=1}
    if bar.lastR ~= tc.r or bar.lastG ~= tc.g or bar.lastB ~= tc.b or bar.lastA ~= tc.a then
        bar.durationText:SetTextColor(tc.r, tc.g, tc.b, tc.a)
        bar.lastR, bar.lastG, bar.lastB, bar.lastA = tc.r, tc.g, tc.b, tc.a
    end
    if bar.lastPos ~= cfg.textPosition or bar.lastOffsetX ~= cfg.textOffsetX or bar.lastOffsetY ~= cfg.textOffsetY then
        bar.durationText:ClearAllPoints()
        if cfg.textPosition == "LEFT" then
            bar.durationText:SetPoint("LEFT", bar, "LEFT", 4 + cfg.textOffsetX, cfg.textOffsetY)
        elseif cfg.textPosition == "CENTER" then
            bar.durationText:SetPoint("CENTER", bar, "CENTER", cfg.textOffsetX, cfg.textOffsetY)
        else
            bar.durationText:SetPoint("RIGHT", bar, "RIGHT", -4 + cfg.textOffsetX, cfg.textOffsetY)
        end
        bar.lastPos, bar.lastOffsetX, bar.lastOffsetY = cfg.textPosition, cfg.textOffsetX, cfg.textOffsetY
    end
end

local function GetOrCreateBar(index)
    if not BarPool[index] then
        local bar = CreateFrame("Frame", "WishFlexAuraMonitorBar"..index, MonitorAnchor)
        bar:SetTemplate("Transparent")
        
        local statusBar = CreateFrame("StatusBar", nil, bar)
        statusBar:SetFrameLevel(bar:GetFrameLevel() + 1)
        bar.statusBar = statusBar
        
        local bg = statusBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bar.statusBar.bg = bg
        
        local gridFrame = CreateFrame("Frame", nil, bar)
        gridFrame:SetAllPoints(bar)
        gridFrame:SetFrameLevel(bar:GetFrameLevel() + 10)
        bar.gridFrame = gridFrame
        
        local cd = CreateFrame("Cooldown", nil, statusBar, "CooldownFrameTemplate")
        cd:SetAllPoints()
        cd:SetDrawSwipe(false)
        cd:SetDrawEdge(false)
        cd:SetDrawBling(false)
        cd:SetHideCountdownNumbers(false)
        cd.noCooldownOverride = true
        cd.noOCC = true
        cd.skipElvUICooldown = true
        bar.cd = cd
        
        for _, region in pairs({cd:GetRegions()}) do
            if region:IsObjectType("FontString") then
                bar.durationText = region
                break
            end
        end
        if not bar.durationText then bar.durationText = cd:CreateFontString(nil, "OVERLAY") end
        
        BarPool[index] = bar
        ApplySingleBarVisuals(bar)
        SyncBarTextVisuals(bar)
    end
    return BarPool[index]
end

local function SyncIconTextVisuals(iconF)
    local cfg = E.db.WishFlex.auraGlow.icon
    local fontPath = LSM:Fetch('font', cfg.textFont)
    
    if iconF.lastFont ~= fontPath or iconF.lastSize ~= cfg.textFontSize or iconF.lastOutline ~= cfg.textFontOutline then
        iconF.durationText:SetFont(fontPath, cfg.textFontSize, cfg.textFontOutline)
        iconF.lastFont, iconF.lastSize, iconF.lastOutline = fontPath, cfg.textFontSize, cfg.textFontOutline
    end
    local tc = cfg.textColor or {r=1, g=1, b=1, a=1}
    if iconF.lastR ~= tc.r or iconF.lastG ~= tc.g or iconF.lastB ~= tc.b or iconF.lastA ~= tc.a then
        iconF.durationText:SetTextColor(tc.r, tc.g, tc.b, tc.a)
        iconF.lastR, iconF.lastG, iconF.lastB, iconF.lastA = tc.r, tc.g, tc.b, tc.a
    end
    if iconF.lastOffsetX ~= cfg.textOffsetX or iconF.lastOffsetY ~= cfg.textOffsetY then
        iconF.durationText:ClearAllPoints()
        iconF.durationText:SetPoint("CENTER", iconF, "CENTER", cfg.textOffsetX, cfg.textOffsetY)
        iconF.lastOffsetX, iconF.lastOffsetY = cfg.textOffsetX, cfg.textOffsetY
    end
    
    local sc = cfg.stackColor or {r=1, g=1, b=1, a=1}
    iconF.countText:SetFont(fontPath, cfg.stackFontSize, cfg.textFontOutline)
    iconF.countText:SetTextColor(sc.r, sc.g, sc.b, sc.a)
end

local function GetOrCreateIcon(index)
    if not IconPool[index] then
        local iconF = CreateFrame("Frame", "WishFlexAuraIcon"..index, IconAnchor)
        iconF:SetTemplate("Transparent")
        
        local tex = iconF:CreateTexture(nil, "ARTWORK")
        tex:SetInside(iconF)
        tex:SetTexCoord(unpack(E.TexCoords))
        iconF.tex = tex
        
        local cd = CreateFrame("Cooldown", nil, iconF, "CooldownFrameTemplate")
        cd:SetInside(iconF)
        cd:SetDrawEdge(false); cd:SetHideCountdownNumbers(false)
        cd.noCooldownOverride = true; cd.noOCC = true; cd.skipElvUICooldown = true
        iconF.cd = cd
        
        for _, region in pairs({cd:GetRegions()}) do if region:IsObjectType("FontString") then iconF.durationText = region; break end end
        if not iconF.durationText then iconF.durationText = cd:CreateFontString(nil, "OVERLAY") end
        
        local count = cd:CreateFontString(nil, "OVERLAY")
        count:SetPoint("BOTTOMRIGHT", iconF, "BOTTOMRIGHT", -2, 2)
        iconF.countText = count
        
        IconPool[index] = iconF
        SyncIconTextVisuals(iconF)
    end
    return IconPool[index]
end

local function UpdateBarVisuals()
    for _, bar in ipairs(BarPool) do ApplySingleBarVisuals(bar) end
    if MonitorAnchor then
        local w, h = GetMonitorDimensions()
        MonitorAnchor:SetSize(w, h)
        if MonitorAnchor.mover then MonitorAnchor.mover:SetSize(w, h) end
        
        local dbM = E.db.WishFlex.auraGlow.monitor
        MonitorAnchor:ClearAllPoints()
        MonitorAnchor:SetPoint("BOTTOM", _G.WishFlex_ClassResourceAnchor, "TOP", dbM.anchorOffsetX or 0, dbM.anchorOffsetY or 1)
    end
    if IconAnchor then
        local iCfg = E.db.WishFlex.auraGlow.icon
        IconAnchor:SetSize(iCfg.size, iCfg.size)
        if IconAnchor.mover then IconAnchor.mover:SetSize(iCfg.size, iCfg.size) end
    end
end

local function BarOnUpdate(self)
    pcall(function()
        if self.expTime then
            local remain = self.expTime - GetTime()
            if remain > 0 then 
                if not self.usingNativeTimer then self.statusBar:SetValue(remain) end
            else 
                if not self.usingNativeTimer then self.statusBar:SetValue(0) end
            end
        end
        SyncBarTextVisuals(self)
    end)
end

-- =========================================
-- 4. 渲染引擎 - 冷却图标高亮
-- =========================================
local function GetCropCoords(w, h)
    local l, r, t, b = unpack(E.TexCoords)
    if not w or not h or h == 0 or w == 0 then return l, r, t, b end
    local ratio = w / h
    if math.abs(ratio - 1) < 0.05 then return l, r, t, b end
    if ratio > 1 then
        local crop = (1 - (1/ratio)) / 2; return l, r, t + (b - t) * crop, b - (b - t) * crop
    else
        local crop = (1 - ratio) / 2; return l + (r - l) * crop, r - (r - l) * crop, t, b
    end
end

local function GetHardcodedSize(parentFrame)
    local cfg = E.db.WishFlex.cdManager
    if not cfg then return 45, 45 end
    local parent = parentFrame:GetParent()
    local parentName = parent and parent:GetName() or ""
    
    if parentName:find("Utility") or (parent and parent.itemFramePool and parent == _G.UtilityCooldownViewer) then return cfg.Utility.width or 45, cfg.Utility.height or 30 end
    if parentName:find("Essential") or parentName == "WishFlex_CooldownRow2_Anchor" or (parent and parent.itemFramePool and parent == _G.EssentialCooldownViewer) then
        if parentName == "WishFlex_CooldownRow2_Anchor" or (parentFrame.layoutIndex and cfg.Essential.maxPerRow and parentFrame.layoutIndex > cfg.Essential.maxPerRow) then return cfg.Essential.row2Width or 40, cfg.Essential.row2Height or 40 end
        return cfg.Essential.row1Width or 45, cfg.Essential.row1Height or 45
    end
    
    local ok, w = pcall(function() return parentFrame:GetWidth() end)
    local ok2, h = pcall(function() return parentFrame:GetHeight() end)
    if ok and ok2 and type(w) == "number" and type(h) == "number" and w > 0 then return w, h end
    return 45, 45
end

local function SnapOverlayToFrame(overlay, sourceFrame)
    if sourceFrame and sourceFrame:IsVisible() then
        if sourceFrame.GetCenter then
            local ok, cx, cy = pcall(function() return sourceFrame:GetCenter() end)
            if ok and cx and cy then
                local scale = sourceFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
                overlay:SetScale(scale)
                local rawW, rawH = GetHardcodedSize(sourceFrame)
                overlay:SetSize(rawW, rawH)
                overlay.iconTex:SetTexCoord(GetCropCoords(rawW, rawH))
                overlay:ClearAllPoints()
                overlay:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
                return true
            end
        end
    end
    return false
end

local function SyncOverlayTextAndVisuals(overlay)
    local cfg = E.db.WishFlex.auraGlow.text
    local fontPath = LSM:Fetch('font', cfg.font)
    if overlay.lastFont ~= fontPath or overlay.lastSize ~= cfg.fontSize or overlay.lastOutline ~= cfg.fontOutline then
        overlay.durationText:SetFont(fontPath, cfg.fontSize, cfg.fontOutline)
        overlay.lastFont, overlay.lastSize, overlay.lastOutline = fontPath, cfg.fontSize, cfg.fontOutline
    end
    if overlay.lastR ~= cfg.color.r or overlay.lastG ~= cfg.color.g or overlay.lastB ~= cfg.color.b then
        overlay.durationText:SetTextColor(cfg.color.r, cfg.color.g, cfg.color.b)
        overlay.lastR, overlay.lastG, overlay.lastB = cfg.color.r, cfg.color.g, cfg.color.b
    end
    if overlay.lastOffsetX ~= cfg.offsetX or overlay.lastOffsetY ~= cfg.offsetY then
        overlay.durationText:ClearAllPoints()
        overlay.durationText:SetPoint("CENTER", overlay, "CENTER", cfg.offsetX, cfg.offsetY)
        overlay.lastOffsetX, overlay.lastOffsetY = cfg.offsetX, cfg.offsetY
    end
end

local function GetOrCreateOverlay(parentFrame, spellID)
    if not OverlayFrames[spellID] then
        local overlay = CreateFrame("Frame", nil, UIParent)
        overlay:SetFrameStrata("HIGH") 
        local iconTex = overlay:CreateTexture(nil, "ARTWORK")
        iconTex:SetPoint("TOPLEFT", overlay, "TOPLEFT", E.mult, -E.mult)
        iconTex:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -E.mult, E.mult)
        pcall(function()
            local spellInfo = C_Spell.GetSpellInfo(spellID)
            if spellInfo and spellInfo.iconID then iconTex:SetTexture(spellInfo.iconID) end
        end)
        overlay.iconTex = iconTex
        
        local cd = CreateFrame("Cooldown", nil, overlay, "CooldownFrameTemplate")
        cd:SetAllPoints(); cd:SetDrawSwipe(false); cd:SetDrawEdge(false); cd:SetDrawBling(false); cd:SetHideCountdownNumbers(false)
        cd.noCooldownOverride, cd.noOCC, cd.skipElvUICooldown = true, true, true
        overlay.cd = cd
        
        for _, region in pairs({cd:GetRegions()}) do if region:IsObjectType("FontString") then overlay.durationText = region; break end end
        if not overlay.durationText then overlay.durationText = cd:CreateFontString(nil, "OVERLAY") end
        
        overlay:SetScript("OnUpdate", function(self) if not SnapOverlayToFrame(self, self.sourceFrame) then self:Hide() return end SyncOverlayTextAndVisuals(self) end)
        OverlayFrames[spellID] = overlay
    end
    return OverlayFrames[spellID]
end

local function ApplyIndependentGlow(ov)
    local cfg = E.db.WishFlex.auraGlow
    LCG.PixelGlow_Stop(ov, "WishAuraDurationGlow")
    LCG.AutoCastGlow_Stop(ov, "WishAuraDurationGlow")
    LCG.ButtonGlow_Stop(ov)
    LCG.ProcGlow_Stop(ov, "WishAuraDurationGlow")
    
    local c = cfg.glowColor or {r = 1, g = 0.82, b = 0, a = 1}
    local colorArr = cfg.glowUseCustomColor and {c.r, c.g, c.b, c.a} or nil
    local t = cfg.glowType or "pixel"
    
    if t == "pixel" then
        local len = cfg.glowPixelLength; if len == 0 then len = nil end
        LCG.PixelGlow_Start(ov, colorArr, cfg.glowPixelLines, cfg.glowPixelFrequency, len, cfg.glowPixelThickness, cfg.glowPixelXOffset, cfg.glowPixelYOffset, false, "WishAuraDurationGlow")
    elseif t == "autocast" then LCG.AutoCastGlow_Start(ov, colorArr, cfg.glowAutocastParticles, cfg.glowAutocastFrequency, cfg.glowAutocastScale, cfg.glowAutocastXOffset, cfg.glowAutocastYOffset, "WishAuraDurationGlow")
    elseif t == "button" then local freq = cfg.glowButtonFrequency; if freq == 0 then freq = nil end LCG.ButtonGlow_Start(ov, colorArr, freq)
    elseif t == "proc" then LCG.ProcGlow_Start(ov, {color = colorArr, duration = cfg.glowProcDuration, xOffset = cfg.glowProcXOffset, yOffset = cfg.glowProcYOffset, key = "WishAuraDurationGlow"}) end
end

local function ClearIndependentGlow(spellID)
    if OverlayFrames[spellID] then
        LCG.PixelGlow_Stop(OverlayFrames[spellID], "WishAuraDurationGlow")
        LCG.AutoCastGlow_Stop(OverlayFrames[spellID], "WishAuraDurationGlow")
        LCG.ButtonGlow_Stop(OverlayFrames[spellID])
        LCG.ProcGlow_Stop(OverlayFrames[spellID], "WishAuraDurationGlow")
        if OverlayFrames[spellID].cd then OverlayFrames[spellID].cd:Clear() end
        OverlayFrames[spellID]:Hide()
    end
end

-- =========================================
-- 5. ★ 核心同步引擎 
-- =========================================
function mod:UpdateGlows(forceUpdate)
    if not E.db.WishFlex.auraGlow.enable then return end
    if mod.isTestingMonitor then return end 
    
    mod.trackedAuras = mod.trackedAuras or {}
    mod.manualTrackers = mod.manualTrackers or {}

    wipe(activeSkillFrames)
    wipe(activeBuffFrames)
    wipe(targetAuraCache)
    wipe(playerAuraCache)

    for _, viewer in ipairs({_G.EssentialCooldownViewer, _G.UtilityCooldownViewer}) do
        if viewer and viewer.itemFramePool then
            for f in viewer.itemFramePool:EnumerateActive() do
                if f:IsVisible() and f.cooldownInfo then activeSkillFrames[#activeSkillFrames+1] = f end
            end
        end
    end
    for _, viewer in ipairs({_G.BuffIconCooldownViewer, _G.BuffBarCooldownViewer}) do
        if viewer and viewer.itemFramePool then
            for f in viewer.itemFramePool:EnumerateActive() do
                if f.cooldownInfo then activeBuffFrames[#activeBuffFrames+1] = f end
            end
        end
    end

    local targetScanned = false
    local playerScanned = false
    
    local barValidCombat = true
    if E.db.WishFlex.auraGlow.monitor.onlyCombat then barValidCombat = InCombatLockdown() or (UnitExists("target") and UnitCanAttack("player", "target")) end
    
    local iconValidCombat = true
    if E.db.WishFlex.auraGlow.icon.onlyCombat then iconValidCombat = InCombatLockdown() or (UnitExists("target") and UnitCanAttack("player", "target")) end
    
    local glowValidCombat = InCombatLockdown() or (UnitExists("target") and UnitCanAttack("player", "target"))

    wipe(ActiveBars)
    wipe(ActiveIcons)
    local activeMonitorCount = 0
    local activeIconCount = 0
    local dynamicW, dynamicH = GetMonitorDimensions()
    local iCfg = E.db.WishFlex.auraGlow.icon

    for spellIDStr, spellData in pairs(E.db.WishFlex.auraGlow.spells) do
        if not spellData.class or spellData.class == E.myclass then
            local spellID = tonumber(spellIDStr)
            local buffID = type(spellData) == "table" and spellData.buffID or tonumber(spellData)
            local customDuration = type(spellData) == "table" and spellData.duration or 0
            local doGlow = type(spellData) == "table" and (spellData.glowEnable ~= false) or true
            local doMonitor = type(spellData) == "table" and (spellData.monitorEnable == true) or false
            local doIcon = type(spellData) == "table" and (spellData.iconEnable == true) or false
            local alwaysShow = type(spellData) == "table" and (spellData.alwaysShow == true) or false
            
            if buffID then
                local auraActive, auraInstanceID, unit = false, nil, "player"
                local isFakeBuff = false
                local fStart, fDur = 0, 0
                local auraData = nil

                if customDuration > 0 then
                    local tracker = mod.manualTrackers[buffID]
                    if tracker and GetTime() < (tracker.start + tracker.dur) then
                        auraActive = true; fStart, fDur = tracker.start, tracker.dur; isFakeBuff = true
                    else mod.manualTrackers[buffID] = nil end
                else
                    local buffFrame = nil
                    for i = 1, #activeBuffFrames do
                        if MatchesSpellID(activeBuffFrames[i].cooldownInfo, buffID) then buffFrame = activeBuffFrames[i]; break end
                    end

                    if buffFrame then
                        local tempID = buffFrame.auraInstanceID
                        local tempUnit = buffFrame.auraDataUnit or "player"
                        if IsSafeValue(tempID) then
                            pcall(function() auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(tempUnit, tempID) end)
                            if auraData and IsValidActiveAura(auraData) then
                                auraActive = true; auraInstanceID = tempID; unit = tempUnit
                                mod.trackedAuras[buffID] = mod.trackedAuras[buffID] or {}; mod.trackedAuras[buffID].id = auraInstanceID; mod.trackedAuras[buffID].unit = unit
                            end
                        end
                    end
                    
                    if not auraActive and mod.trackedAuras[buffID] then
                        local t = mod.trackedAuras[buffID]
                        if VerifyAuraAlive(t.id, t.unit) then
                            pcall(function() auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(t.unit, t.id) end)
                            if auraData and IsValidActiveAura(auraData) then
                                auraActive = true; auraInstanceID = t.id; unit = t.unit
                            else mod.trackedAuras[buffID] = nil end
                        else mod.trackedAuras[buffID] = nil end
                    end
                    
                    if not auraActive then
                        pcall(function() auraData = C_UnitAuras.GetPlayerAuraBySpellID(buffID) end)
                        if auraData and IsValidActiveAura(auraData) then
                            auraActive = true; auraInstanceID = auraData.auraInstanceID; unit = "player"
                            mod.trackedAuras[buffID] = mod.trackedAuras[buffID] or {}; mod.trackedAuras[buffID].id = auraInstanceID; mod.trackedAuras[buffID].unit = unit
                        else
                            if not playerScanned then
                                playerScanned = true
                                for _, filter in ipairs({"HELPFUL", "HARMFUL"}) do
                                    for i = 1, 40 do
                                        local aura; pcall(function() aura = C_UnitAuras.GetAuraDataByIndex("player", i, filter) end)
                                        if aura then
                                            if IsSafeValue(aura.spellId) then
                                                playerAuraCache[aura.spellId] = aura
                                                local baseID = GetBaseSpellFast(aura.spellId)
                                                if baseID and baseID ~= aura.spellId then playerAuraCache[baseID] = aura end
                                            end
                                        else break end
                                    end
                                end
                            end
                            
                            local cachedAura = playerAuraCache[buffID]
                            if cachedAura and IsValidActiveAura(cachedAura) then
                                auraData = cachedAura; auraActive = true; auraInstanceID = cachedAura.auraInstanceID; unit = "player"
                                mod.trackedAuras[buffID] = mod.trackedAuras[buffID] or {}; mod.trackedAuras[buffID].id = auraInstanceID; mod.trackedAuras[buffID].unit = unit
                            elseif UnitExists("target") then
                                if not targetScanned then
                                    targetScanned = true
                                    for _, filter in ipairs({"HELPFUL", "HARMFUL"}) do
                                        for i = 1, 40 do
                                            local aura; pcall(function() aura = C_UnitAuras.GetAuraDataByIndex("target", i, filter) end)
                                            if aura then
                                                if IsSafeValue(aura.spellId) then
                                                    targetAuraCache[aura.spellId] = aura
                                                    local baseID = GetBaseSpellFast(aura.spellId)
                                                    if baseID and baseID ~= aura.spellId then targetAuraCache[baseID] = aura end
                                                end
                                            else break end
                                        end
                                    end
                                end
                                local tCached = targetAuraCache[buffID]
                                if tCached and IsValidActiveAura(tCached) then
                                    auraData = tCached; auraActive = true; auraInstanceID = tCached.auraInstanceID; unit = "target"
                                    mod.trackedAuras[buffID] = mod.trackedAuras[buffID] or {}; mod.trackedAuras[buffID].id = auraInstanceID; mod.trackedAuras[buffID].unit = unit
                                end
                            end
                        end
                    end
                end

                -- ====================== Pipeline 1: Glow ======================
                if doGlow then
                    local skillFrame = nil
                    for i = 1, #activeSkillFrames do
                        if MatchesSpellID(activeSkillFrames[i].cooldownInfo, spellID) then skillFrame = activeSkillFrames[i]; break end
                    end
                    if skillFrame and skillFrame:IsVisible() then
                        if auraActive and glowValidCombat then
                            local overlay = GetOrCreateOverlay(skillFrame, spellID)
                            overlay.sourceFrame = skillFrame
                            
                            if isFakeBuff then pcall(function() overlay.cd:SetCooldown(fStart, fDur) end)
                            elseif auraInstanceID then
                                local durObj; pcall(function() durObj = C_UnitAuras.GetAuraDuration(unit, auraInstanceID) end)
                                if durObj then pcall(function() overlay.cd:SetCooldownFromDurationObject(durObj) end) end
                            end
                            
                            SnapOverlayToFrame(overlay, skillFrame); overlay:Show()
                            if forceUpdate or not ActiveGlows[spellID] then ActiveGlows[spellID] = true; ApplyIndependentGlow(overlay) end
                        else ActiveGlows[spellID] = false; ClearIndependentGlow(spellID) end
                    else ActiveGlows[spellID] = false; ClearIndependentGlow(spellID) end
                else ActiveGlows[spellID] = false; ClearIndependentGlow(spellID) end

                -- ====================== Pipeline 2: Monitor Bar ======================
                if doMonitor and E.db.WishFlex.auraGlow.monitor.enable then
                    if barValidCombat and (auraActive or alwaysShow) then
                        activeMonitorCount = activeMonitorCount + 1
                        local bar = GetOrCreateBar(activeMonitorCount)
                        
                        bar:SetSize(dynamicW, dynamicH)
                        if bar.segments then for _, seg in ipairs(bar.segments) do seg:SetHeight(dynamicH) end end
                        
                        local mode = spellData.monitorMode or "time"
                        
                        if auraActive then
                            bar:SetAlpha(1)
                            local c = spellData.barColor or {r=0, g=0.8, b=1, a=1}
                            bar.statusBar:SetStatusBarColor(c.r, c.g, c.b, c.a)
                            local bgC = spellData.barBgColor or {r=0.2, g=0.2, b=0.2, a=0.8}
                            bar.statusBar.bg:SetVertexColor(bgC.r, bgC.g, bgC.b, bgC.a)
                            
                            if mode == "stack_build" or mode == "stack_spend" or mode == "stack" then
                                local maxS = spellData.maxStacks or 8
                                pcall(function() bar.statusBar:SetMinMaxValues(0, maxS) end)
                                
                                -- 【完美防爆】：拦截任何形式的层数读取污染
                                pcall(function()
                                    local st = (auraData and auraData.applications) or 1
                                    bar.statusBar:SetValue(st)
                                end)
                                
                                pcall(function() UpdateSegments(bar, maxS) end)
                                pcall(function() bar.cd:Clear() end)
                                bar.durationText:SetText("")
                                bar:SetScript("OnUpdate", nil) 
                            else
                                pcall(function() UpdateSegments(bar, 0) end)
                                bar.usingNativeTimer = false
                                local durObj = auraInstanceID and C_UnitAuras.GetAuraDuration(unit, auraInstanceID)
                                
                                if durObj then
                                    if bar.statusBar.SetTimerDuration then
                                        pcall(function()
                                            local interp = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Linear or 0
                                            local dir = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.TimeRemaining or 1
                                            bar.statusBar:SetTimerDuration(durObj, interp, dir)
                                        end)
                                        bar.usingNativeTimer = true
                                    end
                                    pcall(function() bar.cd:SetCooldownFromDurationObject(durObj) end)
                                    bar:SetScript("OnUpdate", BarOnUpdate)
                                elseif isFakeBuff then
                                    if not bar.usingNativeTimer then pcall(function() bar.statusBar:SetMinMaxValues(0, fDur) end) end
                                    bar.expTime = fStart + fDur
                                    pcall(function() bar.cd:SetCooldown(fStart, fDur) end)
                                    bar:SetScript("OnUpdate", BarOnUpdate)
                                else
                                    pcall(function() bar.cd:Clear() end)
                                    bar.durationText:SetText("")
                                    bar:SetScript("OnUpdate", nil)
                                end
                            end
                        else
                            bar:SetAlpha(0.4)
                            local c = spellData.barColor or {r=0, g=0.8, b=1, a=1}
                            bar.statusBar:SetStatusBarColor(c.r * 0.5, c.g * 0.5, c.b * 0.5, c.a)
                            local bgC = spellData.barBgColor or {r=0.2, g=0.2, b=0.2, a=0.8}
                            bar.statusBar.bg:SetVertexColor(bgC.r, bgC.g, bgC.b, bgC.a)
                            
                            if mode == "stack_build" or mode == "stack_spend" or mode == "stack" then
                                local maxS = spellData.maxStacks or 8
                                pcall(function() bar.statusBar:SetMinMaxValues(0, maxS) end)
                                pcall(function() UpdateSegments(bar, maxS) end)
                            else
                                pcall(function() bar.statusBar:SetMinMaxValues(0, 1) end)
                                pcall(function() UpdateSegments(bar, 0) end)
                            end
                            bar.statusBar:SetValue(0)
                            pcall(function() bar.cd:Clear() end)
                            bar.durationText:SetText("")
                            bar:SetScript("OnUpdate", nil) 
                        end
                        bar:Show()
                        ActiveBars[activeMonitorCount] = bar
                    end
                end

                -- ====================== Pipeline 3: Icon ======================
                if doIcon and iCfg.enable then
                    if iconValidCombat and (auraActive or alwaysShow) then
                        activeIconCount = activeIconCount + 1
                        local iconF = GetOrCreateIcon(activeIconCount)
                        
                        iconF:SetSize(iCfg.size, iCfg.size)
                        
                        local sInfo = C_Spell.GetSpellInfo(spellID)
                        if sInfo and sInfo.iconID then
                            iconF.tex:SetTexture(sInfo.iconID)
                        end
                        
                        if auraActive then
                            iconF:SetAlpha(1)
                            iconF.tex:SetDesaturated(false)
                            
                            -- 【完美防爆】：拦截机密层数比较污染
                            local stacksSuccess = pcall(function()
                                local st = (auraData and auraData.applications) or 0
                                if type(st) == "number" and st > 1 then
                                    iconF.countText:SetText(st)
                                else
                                    iconF.countText:SetText("")
                                end
                            end)
                            if not stacksSuccess then iconF.countText:SetText("") end
                            
                            local durObj = auraInstanceID and C_UnitAuras.GetAuraDuration(unit, auraInstanceID)
                            if durObj then
                                pcall(function() iconF.cd:SetCooldownFromDurationObject(durObj) end)
                            elseif isFakeBuff then
                                pcall(function() iconF.cd:SetCooldown(fStart, fDur) end)
                            else
                                pcall(function() iconF.cd:Clear() end)
                                iconF.durationText:SetText("")
                            end
                            iconF:SetScript("OnUpdate", function(self) SyncIconTextVisuals(self) end)
                        else
                            iconF:SetAlpha(0.4)
                            iconF.tex:SetDesaturated(true)
                            iconF.countText:SetText("")
                            pcall(function() iconF.cd:Clear() end)
                            iconF.durationText:SetText("")
                            iconF:SetScript("OnUpdate", function(self) SyncIconTextVisuals(self) end)
                        end
                        
                        iconF:Show()
                        ActiveIcons[activeIconCount] = iconF
                    end
                end
            end
        end
    end
    
    if E.db.WishFlex.auraGlow.monitor.enable then
        for i = activeMonitorCount + 1, #BarPool do
            BarPool[i]:Hide()
            BarPool[i]:SetScript("OnUpdate", nil)
            pcall(function() BarPool[i].cd:Clear() end)
        end
        local mdb = E.db.WishFlex.auraGlow.monitor
        for i = 1, activeMonitorCount do
            local bar = ActiveBars[i]
            bar:ClearAllPoints()
            if i == 1 then bar:SetPoint("CENTER", MonitorAnchor, "CENTER", 0, 0)
            else
                local prev = ActiveBars[i-1]
                if mdb.growth == "UP" then bar:SetPoint("BOTTOM", prev, "TOP", 0, mdb.spacing)
                else bar:SetPoint("TOP", prev, "BOTTOM", 0, -mdb.spacing) end
            end
        end
    end

    if iCfg.enable then
        for i = activeIconCount + 1, #IconPool do
            IconPool[i]:Hide()
            IconPool[i]:SetScript("OnUpdate", nil)
            pcall(function() IconPool[i].cd:Clear() end)
        end
        for i = 1, activeIconCount do
            local iconF = ActiveIcons[i]
            iconF:ClearAllPoints()
            if i == 1 then
                iconF:SetPoint("CENTER", IconAnchor, "CENTER", 0, 0)
            else
                local prev = ActiveIcons[i-1]
                if iCfg.growth == "RIGHT" then iconF:SetPoint("LEFT", prev, "RIGHT", iCfg.spacing, 0)
                elseif iCfg.growth == "LEFT" then iconF:SetPoint("RIGHT", prev, "LEFT", -iCfg.spacing, 0)
                elseif iCfg.growth == "UP" then iconF:SetPoint("BOTTOM", prev, "TOP", 0, iCfg.spacing)
                else iconF:SetPoint("TOP", prev, "BOTTOM", 0, -iCfg.spacing) end
            end
        end
    end
    
    if E.db.WishFlex.auraGlow.enable then
        for _, viewer in ipairs({_G.BuffIconCooldownViewer, _G.BuffBarCooldownViewer}) do
            if viewer and viewer.itemFramePool then
                for f in viewer.itemFramePool:EnumerateActive() do
                    if f.cooldownInfo then
                        if ShouldHideFrame(f.cooldownInfo) then
                            if f:GetWidth() >= 1 and not f.wishFlexOrigWidth then f.wishFlexOrigWidth = f:GetWidth() end
                            f:SetAlpha(0); if f.Icon then f.Icon:SetAlpha(0) end; f:SetWidth(0.001); f:EnableMouse(false)
                        else
                            if f:GetWidth() < 1 then f:SetWidth(f.wishFlexOrigWidth or 45) end
                            f:SetAlpha(1); if f.Icon then f.Icon:SetAlpha(1) end; f:EnableMouse(true)
                        end
                    end
                end
            end
        end
    end
end

-- =========================================
-- 6. 施法事件截获器
-- =========================================
function mod:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellID)
    if unit ~= "player" then return end
    if not E.db.WishFlex.auraGlow.enable then return end
    
    local triggered = false
    for sIDStr, spellData in pairs(E.db.WishFlex.auraGlow.spells) do
        local sID = tonumber(sIDStr)
        local bID = type(spellData) == "table" and spellData.buffID or tonumber(spellData)
        local dur = type(spellData) == "table" and spellData.duration or 0
        if dur > 0 and (spellID == sID or spellID == bID) then
            mod.manualTrackers = mod.manualTrackers or {}
            mod.manualTrackers[bID] = { start = GetTime(), dur = dur }
            triggered = true
        end
    end
    if triggered then mod:UpdateGlows() end
end

-- =========================================
-- 7. 设置界面生成
-- =========================================
local function ResolveSpellID(info)
    if not info then return nil end
    local base = info.spellID or 0
    local linked = info.linkedSpellIDs and info.linkedSpellIDs[1]
    return linked or info.overrideSpellID or (base > 0 and base) or nil
end

function mod:TestMonitor()
    if not E.db.WishFlex.auraGlow.monitor.enable and not E.db.WishFlex.auraGlow.icon.enable then return end
    mod.isTestingMonitor = true
    
    if E.db.WishFlex.auraGlow.monitor.enable then
        for _, b in ipairs(BarPool) do b:Hide() end
        local dynamicW, dynamicH = GetMonitorDimensions()
        local bar1 = GetOrCreateBar(1)
        bar1:SetSize(dynamicW, dynamicH)
        bar1.statusBar:SetStatusBarColor(0.6, 0, 1, 1); bar1.statusBar.bg:SetVertexColor(0.2, 0.2, 0.2, 0.8)
        bar1.statusBar:SetMinMaxValues(0, 8); bar1.statusBar:SetValue(5)
        UpdateSegments(bar1, 8); bar1.cd:Clear(); bar1:SetScript("OnUpdate", nil)
        bar1:ClearAllPoints(); bar1:SetPoint("CENTER", MonitorAnchor, "CENTER", 0, 0); bar1:Show()
        
        local bar2 = GetOrCreateBar(2)
        bar2:SetSize(dynamicW, dynamicH)
        bar2.statusBar:SetStatusBarColor(0, 0.8, 1, 1); bar2.statusBar.bg:SetVertexColor(0.2, 0.2, 0.2, 0.8)
        bar2.statusBar:SetMinMaxValues(0, 20); bar2.expTime = GetTime() + 20; bar2.usingNativeTimer = false
        UpdateSegments(bar2, 0); bar2.cd:SetCooldown(GetTime(), 20); bar2:SetScript("OnUpdate", BarOnUpdate)
        bar2:ClearAllPoints()
        local sp = E.db.WishFlex.auraGlow.monitor.spacing or 1
        if E.db.WishFlex.auraGlow.monitor.growth == "UP" then bar2:SetPoint("BOTTOM", bar1, "TOP", 0, sp) else bar2:SetPoint("TOP", bar1, "BOTTOM", 0, -sp) end
        bar2:Show()
    end
    
    if E.db.WishFlex.auraGlow.icon.enable then
        for _, f in ipairs(IconPool) do f:Hide() end
        local icfg = E.db.WishFlex.auraGlow.icon
        
        local icon1 = GetOrCreateIcon(1)
        icon1:SetSize(icfg.size, icfg.size)
        icon1.tex:SetTexture(132225) 
        icon1.tex:SetDesaturated(false)
        icon1:SetAlpha(1)
        icon1.countText:SetText("5")
        icon1.cd:Clear()
        icon1:SetScript("OnUpdate", function(self) SyncIconTextVisuals(self) end)
        icon1:ClearAllPoints(); icon1:SetPoint("CENTER", IconAnchor, "CENTER", 0, 0); icon1:Show()
        
        local icon2 = GetOrCreateIcon(2)
        icon2:SetSize(icfg.size, icfg.size)
        icon2.tex:SetTexture(132223)
        icon2.tex:SetDesaturated(false)
        icon2:SetAlpha(1)
        icon2.countText:SetText("")
        icon2.cd:SetCooldown(GetTime(), 20)
        icon2:SetScript("OnUpdate", function(self) SyncIconTextVisuals(self) end)
        icon2:ClearAllPoints()
        local is = icfg.spacing or 4
        if icfg.growth == "RIGHT" then icon2:SetPoint("LEFT", icon1, "RIGHT", is, 0)
        elseif icfg.growth == "LEFT" then icon2:SetPoint("RIGHT", icon1, "LEFT", -is, 0)
        elseif icfg.growth == "UP" then icon2:SetPoint("BOTTOM", icon1, "TOP", 0, is)
        else icon2:SetPoint("TOP", icon1, "BOTTOM", 0, -is) end
        icon2:Show()
    end
    
    C_Timer.After(5, function()
        mod.isTestingMonitor = false
        if not InCombatLockdown() then mod:UpdateGlows(true) end
    end)
end

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.cdmanager = WUI.OptionsArgs.cdmanager or { order = 20, type = "group", name = "|cff00e5cc冷却管理器|r", childGroups = "tab", args = {} }
    
    local scannedSpellToBuff = {}
    
    local args = WUI.OptionsArgs.cdmanager.args
    args.auraglow = {
        order = 7, type = "group", name = "高亮与进度条监控", childGroups = "tab",
        args = {
            spellTab = {
                order = 1, type = "group", name = "法术管理核心",
                args = {
                    enable = { order = 1, type = "toggle", name = "全局启用模块", get = function() return E.db.WishFlex.auraGlow.enable end, set = function(_,v) E.db.WishFlex.auraGlow.enable=v; mod:UpdateGlows(true) end },
                    desc = { order = 3, type = "description", name = "|cff00ffcc纯净原生引擎：|r\n直接继承高亮发光的底层安全逻辑，0报错纯净排版。\n所有配置已自动过滤，仅显示当前角色的增益效果！\n" },
                    spellManagement = {
                        order = 4, type = "group", name = "当前角色技能管理", guiInline = true,
                        args = {
                            addFromList = { 
                                order = 1, type = "select", name = "1. 从冷却列表快速添加", 
                                desc = "自动将面板中的技能提取为发光ID，并自动绑定真实的BUFF ID（例如地狱火自动绑定11685）！",
                                values = function()
                                    local vals = {}
                                    local found = false
                                    wipe(scannedSpellToBuff)
                                    
                                    local function ProcessInfo(info)
                                        if not info then return end
                                        local sID = info.spellID
                                        local bID = info.overrideSpellID or (info.linkedSpellIDs and info.linkedSpellIDs[1])
                                        if not sID or sID == 0 then sID = bID end
                                        
                                        if sID and sID > 0 then
                                            local name = C_Spell.GetSpellName(sID) or "未知技能"
                                            local text = name .. " (技能:" .. sID .. ")"
                                            if bID and bID ~= sID then
                                                text = name .. " (技能:" .. sID .. " ➔ Buff:" .. bID .. ")"
                                            end
                                            
                                            vals[tostring(sID)] = text
                                            scannedSpellToBuff[sID] = bID or sID
                                            found = true
                                        end
                                    end

                                    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet then
                                        local ids = C_CooldownViewer.GetCooldownViewerCategorySet(3, false)
                                        if ids then
                                            for _, cdID in ipairs(ids) do
                                                local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                                                ProcessInfo(info)
                                            end
                                        end
                                    end
                                    
                                    local viewers = { "BuffIconCooldownViewer", "BuffBarCooldownViewer" }
                                    for _, vName in ipairs(viewers) do
                                        local viewer = _G[vName]
                                        if viewer then
                                            if viewer.itemFramePool then
                                                for frame in viewer.itemFramePool:EnumerateActive() do
                                                    if frame.cooldownInfo then ProcessInfo(frame.cooldownInfo) end
                                                end
                                            else
                                                for _, child in ipairs({ viewer:GetChildren() }) do
                                                    if child.cooldownInfo then ProcessInfo(child.cooldownInfo) end
                                                end
                                            end
                                        end
                                    end
                                    
                                    if not found then vals[""] = "暂无追踪数据，请用下方手动添加" end
                                    return vals
                                end,
                                get = function() return "" end, 
                                set = function(_, v) 
                                    local id = tonumber(v) 
                                    if id and not E.db.WishFlex.auraGlow.spells[tostring(id)] then 
                                        local bID = scannedSpellToBuff[id] or id
                                        E.db.WishFlex.auraGlow.spells[tostring(id)] = { buffID = bID, duration = 0, glowEnable = true, monitorEnable = false, iconEnable = false, alwaysShow = false, monitorMode = "time", maxStacks = 5, barColor = {r=0,g=0.8,b=1,a=1}, barBgColor = {r=0.2,g=0.2,b=0.2,a=0.8}, class = E.myclass }
                                        mod.selectedSpell = tostring(id)
                                        mod:BuildFastCache()
                                        mod:UpdateGlows(true) 
                                    end 
                                end 
                            },
                            
                            addManual = { 
                                order = 1.5, type = "input", name = "手动添加技能ID (备用)", 
                                get = function() return "" end, 
                                set = function(_, v) 
                                    local id = tonumber(v) 
                                    if id and not E.db.WishFlex.auraGlow.spells[tostring(id)] then 
                                        E.db.WishFlex.auraGlow.spells[tostring(id)] = { buffID = id, duration = 0, glowEnable = true, monitorEnable = false, iconEnable = false, alwaysShow = false, monitorMode = "time", maxStacks = 5, barColor = {r=0,g=0.8,b=1,a=1}, barBgColor = {r=0.2,g=0.2,b=0.2,a=0.8}, class = E.myclass }
                                        mod.selectedSpell = tostring(id)
                                        mod:BuildFastCache()
                                        mod:UpdateGlows(true) 
                                    end 
                                end 
                            },
                            
                            selectSpell = { 
                                order = 2, type = "select", name = "2. 管理已添加的法术", 
                                values = function() 
                                    local vals = {} 
                                    for k, v in pairs(E.db.WishFlex.auraGlow.spells) do 
                                        if not v.class or v.class == E.myclass then
                                            local id = tonumber(k)
                                            local name = C_Spell.GetSpellName(id) or "未知技能"
                                            vals[k] = name .. " (" .. k .. ")"
                                        end
                                    end 
                                    return vals 
                                end, 
                                get = function() return mod.selectedSpell end, 
                                set = function(_, v) mod.selectedSpell = v end 
                            },
                            editBuff = { order = 3, type = "input", name = "真实绑定的Buff ID", get = function() local d = mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; return d and tostring(type(d) == "table" and d.buffID or d) or "" end, set = function(_, v) local id = tonumber(v); if mod.selectedSpell and id then if type(E.db.WishFlex.auraGlow.spells[mod.selectedSpell]) ~= "table" then E.db.WishFlex.auraGlow.spells[mod.selectedSpell] = { buffID = id, duration = 0, class = E.myclass } else E.db.WishFlex.auraGlow.spells[mod.selectedSpell].buffID = id end; mod:BuildFastCache(); mod:UpdateGlows(true) end end, disabled = function() return not mod.selectedSpell end },
                            
                            separator1 = { order = 4, type = "header", name = "【冷却图标发光】选项" },
                            glowEnable = { order = 5, type = "toggle", name = "允许图标发光", get = function() local d = mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; return type(d)=="table" and (d.glowEnable ~= false) or true end, set = function(_,v) if mod.selectedSpell then E.db.WishFlex.auraGlow.spells[mod.selectedSpell].glowEnable=v; mod:UpdateGlows(true) end end, disabled = function() return not mod.selectedSpell end },
                            
                            separator2 = { order = 6, type = "header", name = "【专属监控】选项 (进度条/图标)" },
                            monitorEnable = { order = 7, type = "toggle", name = "生成进度条", get = function() local d = mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; return type(d)=="table" and (d.monitorEnable == true) or false end, set = function(_,v) if mod.selectedSpell then E.db.WishFlex.auraGlow.spells[mod.selectedSpell].monitorEnable=v; mod:UpdateGlows(true) end end, disabled = function() return not mod.selectedSpell end },
                            iconEnable = { order = 7.5, type = "toggle", name = "生成独立图标", get = function() local d = mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; return type(d)=="table" and (d.iconEnable == true) or false end, set = function(_,v) if mod.selectedSpell then E.db.WishFlex.auraGlow.spells[mod.selectedSpell].iconEnable=v; mod:UpdateGlows(true) end end, disabled = function() return not mod.selectedSpell end },
                            
                            alwaysShow = { order = 7.6, type = "toggle", name = "常驻显示(无Buff时半透明占位)", desc = "开启后，即使你身上没有这个Buff，监控条和图标也会以半透明的去色状态固定显示在屏幕上。", get = function() local d = mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; return type(d)=="table" and (d.alwaysShow == true) or false end, set = function(_,v) if mod.selectedSpell then E.db.WishFlex.auraGlow.spells[mod.selectedSpell].alwaysShow=v; mod:UpdateGlows(true) end end, disabled = function() local d = mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; return not d or not (d.monitorEnable or d.iconEnable) end },
                            
                            monitorMode = { 
                                order = 8, type = "select", name = "监控逻辑模式", 
                                values = { 
                                    time = "持续时间 (如: 爆燃、天神下凡)", 
                                    stack_build = "层数获取: 从0到满 (如: 冰刺)",
                                    stack_spend = "层数消耗: 从满到0 (如: 粉碎混沌)"
                                }, 
                                get = function() 
                                    local d = mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]
                                    return d and d.monitorMode or "time"
                                end, 
                                set = function(_,v) 
                                    if mod.selectedSpell then 
                                        E.db.WishFlex.auraGlow.spells[mod.selectedSpell].monitorMode = v
                                        mod:UpdateGlows(true) 
                                    end 
                                end, 
                                disabled = function() 
                                    local d = mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]
                                    return not d or not (d.monitorEnable or d.iconEnable) 
                                end 
                            },
                            maxStacks = { order = 9, type = "range", name = "网格切分数", desc = "填写最大层数将生成完美的背景分割黑线网格。", min = 2, max = 20, step = 1, get = function() local d = mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; return d and d.maxStacks or 8 end, set = function(_,v) if mod.selectedSpell then E.db.WishFlex.auraGlow.spells[mod.selectedSpell].maxStacks=v; mod:UpdateGlows(true) end end, disabled = function() local d=mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; return not d or not (d.monitorEnable or d.iconEnable) or (d.monitorMode=="time" and d.monitorMode~="stack_build" and d.monitorMode~="stack_spend" and d.monitorMode~="stack") end },
                            barColor = { order = 10, type = "color", name = "进度条前景色", hasAlpha = true, get = function() local d = mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; local c = d and d.barColor or {r=0,g=0.8,b=1,a=1}; return c.r,c.g,c.b,c.a end, set = function(_,r,g,b,a) if mod.selectedSpell then E.db.WishFlex.auraGlow.spells[mod.selectedSpell].barColor={r=r,g=g,b=b,a=a}; mod:UpdateGlows(true) end end, disabled = function() local d=mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; return not d or not d.monitorEnable end },
                            barBgColor = { order = 10.1, type = "color", name = "进度条背景色", hasAlpha = true, get = function() local d = mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; local c = d and d.barBgColor or {r=0.2,g=0.2,b=0.2,a=0.8}; return c.r,c.g,c.b,c.a end, set = function(_,r,g,b,a) if mod.selectedSpell then E.db.WishFlex.auraGlow.spells[mod.selectedSpell].barBgColor={r=r,g=g,b=b,a=a}; mod:UpdateGlows(true) end end, disabled = function() local d=mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; return not d or not d.monitorEnable end },
                            
                            separator3 = { order = 11, type = "header", name = "【特殊实体(如黑眼)手动倒数】选项" },
                            editDuration = { 
                                order = 12, type = "input", name = "强制设定秒数(填0为自动)", 
                                get = function() local d = mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; return d and tostring(type(d) == "table" and d.duration or 0) or "0" end, 
                                set = function(_, v) local val = tonumber(v); if mod.selectedSpell and val then if type(E.db.WishFlex.auraGlow.spells[mod.selectedSpell]) ~= "table" then E.db.WishFlex.auraGlow.spells[mod.selectedSpell] = { buffID = tonumber(mod.selectedSpell), duration = val, class = E.myclass } else E.db.WishFlex.auraGlow.spells[mod.selectedSpell].duration = val end; mod:BuildFastCache(); mod:UpdateGlows(true) end end, 
                                disabled = function() return not mod.selectedSpell end 
                            },
                            deleteSpell = { order = 13, type = "execute", name = "删除选中", func = function() if mod.selectedSpell then local id = tonumber(mod.selectedSpell); E.db.WishFlex.auraGlow.spells[mod.selectedSpell] = nil; mod.selectedSpell = nil; if ActiveGlows[id] then ActiveGlows[id] = false; ClearIndependentGlow(id) end; local CC = WUI:GetModule('CooldownCustom', true); if CC and CC.TriggerLayout then CC:TriggerLayout() end; mod:BuildFastCache(); mod:UpdateGlows(true) end end, disabled = function() return not mod.selectedSpell end }
                        }
                    }
                }
            },
            glowTab = {
                order = 2, type = "group", name = "发光全局样式",
                get = function(info) return E.db.WishFlex.auraGlow[info[#info]] end,
                set = function(info, v) E.db.WishFlex.auraGlow[info[#info]] = v; mod:UpdateGlows(true) end,
                args = {
                    glowType = { order = 1, type = "select", name = "发光类型", values = { pixel = "像素发光", autocast = "自动施法发光", button = "按钮发光", proc = "触发发光" } },
                    glowUseCustomColor = { order = 2, type = "toggle", name = "使用自定义颜色" },
                    glowColor = { order = 3, type = "color", name = "发光颜色", hasAlpha = true, get = function() local c = E.db.WishFlex.auraGlow.glowColor; return c.r, c.g, c.b, c.a end, set = function(_, r, g, b, a) E.db.WishFlex.auraGlow.glowColor = {r=r, g=g, b=b, a=a}; mod:UpdateGlows(true) end, disabled = function() return not E.db.WishFlex.auraGlow.glowUseCustomColor end },
                    glowPixelLines = { order = 10, type = "range", name = "线条数", min = 1, max = 20, step = 1, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "pixel" end },
                    glowPixelFrequency = { order = 11, type = "range", name = "频率", min = -2, max = 2, step = 0.05, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "pixel" end },
                    glowPixelLength = { order = 12, type = "range", name = "长度(0为自动)", min = 0, max = 50, step = 1, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "pixel" end },
                    glowPixelThickness = { order = 13, type = "range", name = "粗细", min = 1, max = 10, step = 1, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "pixel" end },
                    glowPixelXOffset = { order = 14, type = "range", name = "X轴偏移", min = -20, max = 20, step = 1, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "pixel" end },
                    glowPixelYOffset = { order = 15, type = "range", name = "Y轴偏移", min = -20, max = 20, step = 1, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "pixel" end },
                }
            },
            monitorTab = {
                order = 3, type = "group", name = "能量条全局排版",
                get = function(info) return E.db.WishFlex.auraGlow.monitor[info[#info]] end,
                set = function(info, v) E.db.WishFlex.auraGlow.monitor[info[#info]] = v; UpdateBarVisuals(); mod:UpdateGlows(true) end,
                args = {
                    enable = { order = 1, type = "toggle", name = "全局启用能量条" },
                    alignWithClassResource = { order = 1.5, type = "toggle", name = "尺寸对齐职业资源条", desc = "开启后自动读取 ClassResource 的动态宽度和高度，完全融为一体！" },
                    onlyCombat = { order = 2, type = "toggle", name = "仅战斗/有目标时显示" },
                    testMode = { order = 3, type = "execute", name = "测试排版(5秒)", desc = "点击强行显示演示条，用 /ec 移动【WishFlex: 增益监控条】", func = function() mod:TestMonitor() end },
                    spacer = { order = 4, type = "description", name = " " },
                    
                    layoutGroup = {
                        order = 5, type = "group", name = "排版与材质", guiInline = true,
                        args = {
                            width = { order = 1, type = "range", name = "独立宽度", min = 50, max = 500, step = 1, disabled = function() return E.db.WishFlex.auraGlow.monitor.alignWithClassResource end },
                            height = { order = 2, type = "range", name = "独立高度", min = 10, max = 100, step = 1, disabled = function() return E.db.WishFlex.auraGlow.monitor.alignWithClassResource end },
                            spacing = { order = 3, type = "range", name = "条与条间距", min = 0, max = 50, step = 1 },
                            growth = { order = 4, type = "select", name = "增长方向", values = { UP = "向上", DOWN = "向下" } },
                            barTexture = { order = 5, type = "select", dialogControl = 'LSM30_Statusbar', name = "进度条材质", values = LSM:HashTable("statusbar") },
                            anchorOffsetX = { order = 6, type = "range", name = "整体 X 轴偏移", min = -500, max = 500, step = 1 },
                            anchorOffsetY = { order = 7, type = "range", name = "整体 Y 轴偏移", min = -500, max = 500, step = 1 },
                        }
                    },
                    
                    textGroup = {
                        order = 6, type = "group", name = "倒数文本设置", guiInline = true,
                        args = {
                            textFont = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "文本字体", values = LSM:HashTable("font") },
                            textFontSize = { order = 2, type = "range", name = "字体大小", min = 8, max = 64, step = 1 },
                            textFontOutline = { order = 3, type = "select", name = "字体描边", values = { NONE = "无", OUTLINE = "细描边", MONOCHROMEOUTLINE = "单色描边", THICKOUTLINE = "粗描边" } },
                            textColor = { order = 4, type = "color", name = "文本颜色", hasAlpha = true, get = function() local c = E.db.WishFlex.auraGlow.monitor.textColor; return c.r, c.g, c.b, c.a end, set = function(_, r, g, b, a) E.db.WishFlex.auraGlow.monitor.textColor = {r=r, g=g, b=b, a=a}; mod:UpdateGlows(true) end },
                            textPosition = { order = 5, type = "select", name = "文本位置", values = { LEFT = "左侧", CENTER = "居中", RIGHT = "右侧" } },
                            textOffsetX = { order = 6, type = "range", name = "X 轴偏移", min = -50, max = 50, step = 1 },
                            textOffsetY = { order = 7, type = "range", name = "Y 轴偏移", min = -50, max = 50, step = 1 },
                        }
                    }
                }
            },
            iconTab = {
                order = 4, type = "group", name = "独立图标全局排版",
                get = function(info) return E.db.WishFlex.auraGlow.icon[info[#info]] end,
                set = function(info, v) E.db.WishFlex.auraGlow.icon[info[#info]] = v; UpdateBarVisuals(); mod:UpdateGlows(true) end,
                args = {
                    enable = { order = 1, type = "toggle", name = "全局启用独立图标" },
                    onlyCombat = { order = 2, type = "toggle", name = "仅战斗/有目标时显示" },
                    spacer = { order = 3, type = "description", name = " " },
                    
                    layoutGroup = {
                        order = 4, type = "group", name = "排版与尺寸", guiInline = true,
                        args = {
                            size = { order = 1, type = "range", name = "图标大小", min = 10, max = 100, step = 1 },
                            spacing = { order = 2, type = "range", name = "图标间距", min = 0, max = 50, step = 1 },
                            growth = { order = 3, type = "select", name = "增长方向", values = { UP = "向上", DOWN = "向下", LEFT = "向左", RIGHT = "向右" } },
                            anchorOffsetX = { order = 4, type = "range", name = "整体 X 轴偏移", min = -500, max = 500, step = 1 },
                            anchorOffsetY = { order = 5, type = "range", name = "整体 Y 轴偏移", min = -500, max = 500, step = 1 },
                        }
                    },
                    
                    textGroup = {
                        order = 5, type = "group", name = "倒数与层数文本设置", guiInline = true,
                        args = {
                            textFont = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "全局字体", values = LSM:HashTable("font") },
                            textFontOutline = { order = 2, type = "select", name = "全局字体描边", values = { NONE = "无", OUTLINE = "细描边", MONOCHROMEOUTLINE = "单色描边", THICKOUTLINE = "粗描边" } },
                            separator = { order = 3, type = "header", name = "倒数时间(固定居中)" },
                            textFontSize = { order = 4, type = "range", name = "时间字体大小", min = 8, max = 64, step = 1 },
                            textColor = { order = 5, type = "color", name = "时间颜色", hasAlpha = true, get = function() local c = E.db.WishFlex.auraGlow.icon.textColor; return c.r, c.g, c.b, c.a end, set = function(_, r, g, b, a) E.db.WishFlex.auraGlow.icon.textColor = {r=r, g=g, b=b, a=a}; mod:UpdateGlows(true) end },
                            textOffsetX = { order = 6, type = "range", name = "时间 X 轴偏移", min = -50, max = 50, step = 1 },
                            textOffsetY = { order = 7, type = "range", name = "时间 Y 轴偏移", min = -50, max = 50, step = 1 },
                            separator2 = { order = 8, type = "header", name = "层数设置(固定右下)" },
                            stackFontSize = { order = 9, type = "range", name = "层数字体大小", min = 8, max = 64, step = 1 },
                            stackColor = { order = 10, type = "color", name = "层数颜色", hasAlpha = true, get = function() local c = E.db.WishFlex.auraGlow.icon.stackColor; return c.r, c.g, c.b, c.a end, set = function(_, r, g, b, a) E.db.WishFlex.auraGlow.icon.stackColor = {r=r, g=g, b=b, a=a}; mod:UpdateGlows(true) end },
                        }
                    }
                }
            }
        }
    }
end

-- =========================================
-- 8. 静默钩子与节流防抖
-- =========================================
local function HookBuffHide()
    local function HideIt(frame)
        if not E.db.WishFlex.auraGlow.enable or not frame.cooldownInfo then return end
        if frame:GetWidth() >= 1 and not frame.wishFlexOrigWidth then frame.wishFlexOrigWidth = frame:GetWidth() end
        
        local shouldHide = ShouldHideFrame(frame.cooldownInfo)
        if shouldHide then
            frame:SetAlpha(0); if frame.Icon then frame.Icon:SetAlpha(0) end; frame:SetWidth(0.001); frame:EnableMouse(false)
        else
            if frame:GetWidth() < 1 then frame:SetWidth(frame.wishFlexOrigWidth or 45) end
            frame:SetAlpha(1); if frame.Icon then frame.Icon:SetAlpha(1) end; frame:EnableMouse(true)
        end
    end
    if _G.CooldownViewerBuffIconItemMixin then hooksecurefunc(_G.CooldownViewerBuffIconItemMixin, "OnCooldownIDSet", HideIt); hooksecurefunc(_G.CooldownViewerBuffIconItemMixin, "OnActiveStateChanged", HideIt) end
    if _G.CooldownViewerBuffBarItemMixin then hooksecurefunc(_G.CooldownViewerBuffBarItemMixin, "OnCooldownIDSet", HideIt); hooksecurefunc(_G.CooldownViewerBuffBarItemMixin, "OnActiveStateChanged", HideIt) end
end

local updatePending = false
local function RequestUpdateGlows()
    if updatePending then return end
    updatePending = true
    C_Timer.After(InCombatLockdown() and 0.08 or 0.3, function() updatePending = false; mod:UpdateGlows() end)
end
local function SafeHook(object, funcName, callback) if object and object[funcName] and type(object[funcName]) == "function" then hooksecurefunc(object, funcName, callback) end end

function mod:UNIT_AURA(event, unit) if not InCombatLockdown() and unit ~= "player" then return end; if unit == "player" or unit == "target" then RequestUpdateGlows() end end
function mod:OnCombatEvent() RequestUpdateGlows() end

-- =========================================
-- 9. 初始化与数据清洗
-- =========================================
function mod:Initialize()
    if E.db.WishFlex and E.db.WishFlex.auraGlow and E.db.WishFlex.auraGlow.spells then
        local cleanSpells = {}
        for k, v in pairs(E.db.WishFlex.auraGlow.spells) do
            if type(v) == "number" then
                cleanSpells[k] = { buffID = v, duration = 0, glowEnable = true, monitorEnable = false, iconEnable = false, alwaysShow = false, class = E.myclass }
            else
                cleanSpells[k] = {
                    buffID = v.buffID or tonumber(k), duration = v.duration or 0,
                    glowEnable = v.glowEnable ~= false, monitorEnable = v.monitorEnable or false,
                    iconEnable = v.iconEnable or false, alwaysShow = v.alwaysShow or false,
                    monitorMode = v.monitorMode or "time", maxStacks = v.maxStacks or 5, barColor = v.barColor or {r=0,g=0.8,b=1,a=1},
                    barBgColor = v.barBgColor or {r=0.2,g=0.2,b=0.2,a=0.8}, class = v.class
                }
            end
        end
        E.db.WishFlex.auraGlow.spells = cleanSpells
    end
    
    self:BuildFastCache()
    InjectOptions()
    if not E.db.WishFlex.modules.auraGlow then return end

    if not _G.WishFlex_ClassResourceAnchor then
        local dummy = CreateFrame("Frame", "WishFlex_ClassResourceAnchor", E.UIParent)
        dummy:SetSize(250, 14); dummy:SetPoint("CENTER", E.UIParent, "CENTER", 0, -180)
    end
    
    MonitorAnchor = CreateFrame("Frame", "WishFlexAuraMonitorAnchor", E.UIParent)
    local mw, mh = GetMonitorDimensions()
    MonitorAnchor:SetSize(mw, mh)
    MonitorAnchor:ClearAllPoints()
    local dbM = E.db.WishFlex.auraGlow.monitor
    MonitorAnchor:SetPoint("BOTTOM", _G.WishFlex_ClassResourceAnchor, "TOP", dbM.anchorOffsetX or 0, dbM.anchorOffsetY or 1)
    E:CreateMover(MonitorAnchor, "WishFlexAuraMonitorMover", "WishFlex: 增益监控条", nil, nil, nil, "ALL,WISHFLEX")
    
    IconAnchor = CreateFrame("Frame", "WishFlexAuraIconAnchor", E.UIParent)
    local icfg = E.db.WishFlex.auraGlow.icon
    IconAnchor:SetSize(icfg.size, icfg.size)
    IconAnchor:ClearAllPoints()
    IconAnchor:SetPoint("BOTTOM", MonitorAnchor, "TOP", icfg.anchorOffsetX or 0, icfg.anchorOffsetY or 20)
    E:CreateMover(IconAnchor, "WishFlexAuraIconMover", "WishFlex: 增益监控图标", nil, nil, nil, "ALL,WISHFLEX")
    
    UpdateBarVisuals()

    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnCombatEvent")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatEvent")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEvent")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    
    HookBuffHide()
    local viewers = { _G.BuffIconCooldownViewer, _G.EssentialCooldownViewer, _G.UtilityCooldownViewer, _G.BuffBarCooldownViewer }
    for _, viewer in ipairs(viewers) do
        if viewer then
            SafeHook(viewer, "RefreshData", RequestUpdateGlows); SafeHook(viewer, "UpdateLayout", RequestUpdateGlows); SafeHook(viewer, "Layout", RequestUpdateGlows)
            if viewer.itemFramePool then SafeHook(viewer.itemFramePool, "Acquire", RequestUpdateGlows); SafeHook(viewer.itemFramePool, "Release", RequestUpdateGlows) end
        end
    end
end
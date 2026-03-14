local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WF = E:GetModule('WishFlex')
local CR = WF:NewModule('ClassResource', 'AceEvent-3.0')
local LSM = E.Libs.LSM
local AceGUI = LibStub("AceGUI-3.0")
local UF = E:GetModule('UnitFrames')
local playerClass = select(2, UnitClass("player"))
local hasHealerSpec = (playerClass == "PALADIN" or playerClass == "PRIEST" or playerClass == "SHAMAN" or playerClass == "MONK" or playerClass == "DRUID" or playerClass == "EVOKER")

P["WishFlex"] = P["WishFlex"] or { modules = {} }
G["WishFlex"] = G["WishFlex"] or { spellDB = {} }
P["WishFlex"].modules.classResource = true

-- =========================================
-- [PRO重构]：分离的各模块默认值，用于专精隔离克隆
-- =========================================
local barDefaults = {
    power = { independent = false, barXOffset = 0, barYOffset = 0, height = 14, textEnable = true, textFormat = "AUTO", textAnchor = "CENTER", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = true, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1}, useCustomTexture = false, texture = "WishFlex-g1", useCustomBgTexture = false, bgTexture = "WishFlex-g1", bgColor = {r=0, g=0, b=0, a=0.5} },
    class = { independent = false, barXOffset = 0, barYOffset = 0, height = 12, textEnable = true, textFormat = "AUTO", textAnchor = "CENTER", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = true, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=1, g=0.96, b=0.41}, useCustomColors = {}, customColors = {}, useCustomTexture = false, texture = "WishFlex-g1", useCustomBgTexture = false, bgTexture = "WishFlex-g1", bgColor = {r=0, g=0, b=0, a=0.5} },
    mana = { independent = false, barXOffset = 0, barYOffset = 0, height = 10, textEnable = true, textFormat = "AUTO", textAnchor = "CENTER", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = true, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1}, useCustomTexture = false, texture = "WishFlex-g1", useCustomBgTexture = false, bgTexture = "WishFlex-g1", bgColor = {r=0, g=0, b=0, a=0.5} },
    auraBar = { independent = false, barXOffset = 0, barYOffset = 0, height = 14, spacing = 1, growth = "UP", texture = "WishFlex-g1", bgColor = {r=0.2, g=0.2, b=0.2, a=0.8}, font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, textPosition = "RIGHT", xOffset = -4, yOffset = 0, stackFont = "Expressway", stackFontSize = 14, stackOutline = "OUTLINE", stackColor = {r=1, g=1, b=1}, stackPosition = "LEFT", stackXOffset = 4, stackYOffset = 0 }
}

local defaults = {
    enable = true, alignWithCD = false, alignYOffset = 1, hideElvUIBars = true, widthOffset = 2, texture = "WishFlex-g1", specConfigs = {},
}

P["WishFlex"].classResource = defaults

local DEFAULT_COLOR = {r=1, g=1, b=1}
local POWER_COLORS = { [0]={r=0,g=0.5,b=1}, [1]={r=1,g=0,b=0}, [2]={r=1,g=0.5,b=0.25}, [3]={r=1,g=1,b=0}, [4]={r=1,g=0.96,b=0.41}, [5]={r=0.8,g=0.1,b=0.2}, [7]={r=0.5,g=0.32,b=0.55}, [8]={r=0.3,g=0.52,b=0.9}, [9]={r=0.95,g=0.9,b=0.6}, [11]={r=0,g=0.5,b=1}, [12]={r=0.71,g=1,b=0.92}, [13]={r=0.4,g=0,b=0.8}, [16]={r=0.1,g=0.1,b=0.98}, [17]={r=0.79,g=0.26,b=0.99}, [18]={r=1,g=0.61,b=0}, [19]={r=0.4,g=0.8,b=1} }

local PLAYER_CLASS_COLOR = DEFAULT_COLOR
local cc_cache = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass]
if cc_cache then PLAYER_CLASS_COLOR = {r=cc_cache.r, g=cc_cache.g, b=cc_cache.b} end

local RequestUpdateAuraBars
CR.AuraBarPool = {}
CR.ActiveAuraBars = {}
CR.chargeDurCache = {}
CR.spellMaxChargeCache = {} 
local activeBuffFrames = {}
local targetAuraCache = {}
local playerAuraCache = {}
local BaseSpellCache = {}
CR.fastTrackedAuras = {}
CR.manualAuraTrackers = {}

local function GetSpellDB()
    if not E.global.WishFlex then E.global.WishFlex = {} end
    if type(E.global.WishFlex.spellDB) ~= "table" then E.global.WishFlex.spellDB = {} end
    return E.global.WishFlex.spellDB
end

local function SafeHook(object, funcName, callback) 
    if object and object[funcName] and type(object[funcName]) == "function" then hooksecurefunc(object, funcName, callback) end 
end

local function IsSecret(v) return type(v) == "number" and issecretvalue and issecretvalue(v) end
local function IsSafeValue(val) if val == nil then return false end if type(issecretvalue) == "function" and issecretvalue(val) then return false end return true end

local function SafeFormatNum(v)
    local num = tonumber(v) or 0
    if num >= 1e6 then 
        local str = string.format("%.1fm", num / 1e6)
        return (str:gsub("%.0m", "m"))
    elseif num >= 1e3 then 
        local str = string.format("%.1fk", num / 1e3)
        return (str:gsub("%.0k", "k"))
    else 
        return string.format("%.0f", num) 
    end
end

local function SetStackTextSafe(fs, count, isCharge)
    if not fs then return end
    pcall(function()
        if IsSecret(count) then fs:SetFormattedText("%d", count)
        else
            local c = tonumber(count) or 0
            if isCharge then fs:SetText(tostring(c)) else fs:SetText(c > 0 and tostring(c) or "") end
        end
    end)
end

local function UpdateCustomAuraText(bar, buffID, fallbackStacks, isCharge)
    if playerClass == "MONK" and (buffID == 124275 or buffID == 124274 or buffID == 124273 or buffID == 115308) then
        local staggerVal = UnitStagger("player") or 0
        if staggerVal > 0 then
            if IsSecret(staggerVal) then bar.stackText:SetFormattedText("%d", staggerVal)
            else bar.stackText:SetText(SafeFormatNum(staggerVal)) end
        else bar.stackText:SetText("") end
        return true
    end
    SetStackTextSafe(bar.stackText, fallbackStacks, isCharge)
    return false
end

local function GetBaseSpellFast(spellID)
    if not IsSafeValue(spellID) then return nil end
    if BaseSpellCache[spellID] == nil then
        local base = spellID
        pcall(function() if C_Spell and C_Spell.GetBaseSpell then base = C_Spell.GetBaseSpell(spellID) or spellID end end)
        BaseSpellCache[spellID] = base
    end
    return BaseSpellCache[spellID]
end

local function MatchesSpellID(info, targetID)
    if not info then return false end
    if IsSafeValue(info.spellID) and (info.spellID == targetID or info.overrideSpellID == targetID) then return true end
    if info.linkedSpellIDs then for i=1, #info.linkedSpellIDs do if IsSafeValue(info.linkedSpellIDs[i]) and info.linkedSpellIDs[i] == targetID then return true end end end
    return GetBaseSpellFast(info.spellID) == targetID
end

local function IsValidActiveAura(aura)
    if type(aura) ~= "table" then return false end
    return aura.auraInstanceID ~= nil
end

local function DeepMerge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            DeepMerge(target[k], v)
        else
            if target[k] == nil then target[k] = v end
        end
    end
end

local function GetDB()
    if not E.db.WishFlex then E.db.WishFlex = {} end
    if type(E.db.WishFlex.modules) ~= "table" then E.db.WishFlex.modules = {} end
    if E.db.WishFlex.modules.classResource == nil then E.db.WishFlex.modules.classResource = true end
    if type(E.db.WishFlex.classResource) ~= "table" then E.db.WishFlex.classResource = {} end
    local db = E.db.WishFlex.classResource
    DeepMerge(db, defaults)
    return db
end

function CR:BuildAuraCache()
    wipe(CR.fastTrackedAuras)
    local dbSpells = GetSpellDB()
    local currentSpecID = 0
    pcall(function() currentSpecID = GetSpecializationInfo(GetSpecialization()) or 0 end)
    
    for k, spellData in pairs(dbSpells) do
        local v = spellData.auraBar
        if v and type(v) == "table" and (not spellData.class or spellData.class == "ALL" or spellData.class == playerClass) and v.enable ~= false then
            local sSpec = spellData.spec or 0
            if sSpec == 0 or sSpec == currentSpecID then
                local sid = tonumber(k); local bid = spellData.buffID or sid
                if sid then CR.fastTrackedAuras[sid] = true end
                if bid then CR.fastTrackedAuras[bid] = true end
            end
        end
    end
end

local function GetCurrentContextID()
    if playerClass == "DRUID" then
        local formID = GetShapeshiftFormID()
        if formID == 1 then return 1001 elseif formID == 5 then return 1002 elseif formID == 31 then return 1003 elseif formID == 3 or formID == 4 or formID == 27 then return 1004 else return 1000 end
    else
        local specIndex = GetSpecialization()
        return specIndex and GetSpecializationInfo(specIndex) or 0
    end
end

-- =========================================
-- [PRO重构修复]：核心配置提取器（防脏数据污染机制）
-- =========================================
local function GetCurrentSpecConfig(ctxId)
    local db = GetDB()
    ctxId = ctxId or GetCurrentContextID()
    if not db.specConfigs then db.specConfigs = {} end

    if type(db.specConfigs[ctxId]) ~= "table" then db.specConfigs[ctxId] = {} end
    local cfg = db.specConfigs[ctxId]
    
    if cfg.width == nil then cfg.width = db.width or 250 end
    if cfg.yOffset == nil then cfg.yOffset = db.yOffset or 1 end
    if cfg.showPower == nil then cfg.showPower = true end
    if cfg.showClass == nil then cfg.showClass = true end
    if cfg.showMana == nil then cfg.showMana = false end
    if cfg.showAuraBar == nil then cfg.showAuraBar = true end
    if cfg.textPower == nil then cfg.textPower = true end
    if cfg.textClass == nil then cfg.textClass = true end
    if cfg.textMana == nil then cfg.textMana = true end
    if cfg.textAuraTimer == nil then cfg.textAuraTimer = true end
    if cfg.textAuraStack == nil then cfg.textAuraStack = true end

    -- 绝对防御：无论旧表多么残缺，直接拿着默认表去把它所有的坑填满
    if type(cfg.power) ~= "table" then cfg.power = {} end
    DeepMerge(cfg.power, barDefaults.power)
    
    if type(cfg.class) ~= "table" then cfg.class = {} end
    DeepMerge(cfg.class, barDefaults.class)
    
    if type(cfg.mana) ~= "table" then cfg.mana = {} end
    DeepMerge(cfg.mana, barDefaults.mana)
    
    if type(cfg.auraBar) ~= "table" then cfg.auraBar = {} end
    DeepMerge(cfg.auraBar, barDefaults.auraBar)

    return cfg
end

local function GetTargetWidth(cfg)
    local db = GetDB()
    if db.alignWithCD and E.db.WishFlex.cdManager and E.db.WishFlex.cdManager.Essential then
        local cdDB = E.db.WishFlex.cdManager.Essential
        local maxPerRow = tonumber(cdDB.maxPerRow) or 7
        local w = tonumber(cdDB.row1Width) or tonumber(cdDB.width) or 45
        local gap = tonumber(cdDB.iconGap) or 2
        return (maxPerRow * w) + ((maxPerRow - 1) * gap) + (tonumber(db.widthOffset) or 2)
    end
    return tonumber(cfg.width) or 250
end

local function GetSafeColor(cfg, defColor, isClassBar)
    if cfg then
        if isClassBar then
            if type(cfg.useCustomColors) == "table" and cfg.useCustomColors[playerClass] then
                local cc = type(cfg.customColors) == "table" and cfg.customColors[playerClass]
                if cc and type(cc.r) == "number" then return cc end
            end
        elseif cfg.useCustomColor and type(cfg.customColor) == "table" and type(cfg.customColor.r) == "number" then
            return cfg.customColor
        end
    end
    if type(defColor) == "table" and type(defColor.r) == "number" then return defColor end
    return DEFAULT_COLOR
end

local function GetPowerColor(pType) return POWER_COLORS[pType] or DEFAULT_COLOR end

-- ======================================================================
-- 核心平滑预估引擎：全面增加 pcall 安全保护
-- ======================================================================
local function GetClassResourceData()
    local spec = GetSpecializationInfo(GetSpecialization() or 1)
    local pType = UnitPowerType("player")
    local classColor = PLAYER_CLASS_COLOR
    
    if playerClass == "ROGUE" then return UnitPower("player", 4), UnitPowerMax("player", 4), classColor, true
    elseif playerClass == "PALADIN" then return UnitPower("player", 9), 5, classColor, true
    elseif playerClass == "WARLOCK" then 
        local maxTrue = 50; local currTrue = 0; local maxShards = 5; local curr = 0
        pcall(function()
            maxTrue = UnitPowerMax("player", 7, true); currTrue = UnitPower("player", 7, true); maxShards = UnitPowerMax("player", 7); curr = UnitPower("player", 7)
            if maxTrue and maxTrue > 0 and currTrue and maxShards then curr = (currTrue / maxTrue) * maxShards end
        end)
        return curr, maxShards, classColor, true
    elseif playerClass == "EVOKER" then 
        local maxEssence = 6; local curr = 0
        pcall(function()
            maxEssence = UnitPowerMax("player", 19) or 6; if type(maxEssence) ~= "number" or IsSecret(maxEssence) then maxEssence = 6 end
            curr = UnitPower("player", 19) or 0; if type(curr) ~= "number" or IsSecret(curr) then curr = 0 end
        end)
        
        if not CR.evokerEssence then CR.evokerEssence = { count = curr, partial = 0, lastTick = GetTime() } end
        local now = GetTime(); local elapsed = now - CR.evokerEssence.lastTick; CR.evokerEssence.lastTick = now
        if curr > CR.evokerEssence.count then CR.evokerEssence.partial = 0 end
        CR.evokerEssence.count = curr
        
        if curr < maxEssence then
            local activeRegen = 0.2 
            pcall(function() if GetPowerRegenForPowerType then local _, active = GetPowerRegenForPowerType(19); if type(active) == "number" and active > 0 then activeRegen = active end end end)
            CR.evokerEssence.partial = CR.evokerEssence.partial + (activeRegen * elapsed)
            if CR.evokerEssence.partial >= 1 then CR.evokerEssence.partial = 0.99 end
        else CR.evokerEssence.partial = 0 end
        
        return curr + CR.evokerEssence.partial, maxEssence, classColor, true
    elseif playerClass == "DEATHKNIGHT" then 
        local readyRunes = 0; local highestPartial = 0; local maxRunes = 6
        pcall(function()
            maxRunes = UnitPowerMax("player", 5) or 6; if type(maxRunes) ~= "number" or IsSecret(maxRunes) then maxRunes = 6 end
            for i = 1, maxRunes do
                local start, duration, runeReady = GetRuneCooldown(i)
                if runeReady then readyRunes = readyRunes + 1
                else if start and duration and duration > 0 then local partial = math.max(0, math.min(0.99, (GetTime() - start) / duration)); if partial > highestPartial then highestPartial = partial end end end
            end
        end)
        return readyRunes + highestPartial, maxRunes, classColor, true
    elseif playerClass == "MAGE" and spec == 62 then return UnitPower("player", 16), 4, classColor, true
    elseif playerClass == "MONK" and spec == 269 then return UnitPower("player", 12), UnitPowerMax("player", 12), classColor, true
    elseif playerClass == "DRUID" and pType == 3 then return UnitPower("player", 4), 5, classColor, true
    elseif playerClass == "SHAMAN" and spec == 263 then
        local apps = 0
        if C_UnitAuras.GetPlayerAuraBySpellID then local aura = C_UnitAuras.GetPlayerAuraBySpellID(344179); if aura then apps = aura.applications or 1 end end
        return apps, 10, classColor, true
    elseif playerClass == "HUNTER" and spec == 255 then
        local apps = 0
        if C_UnitAuras.GetPlayerAuraBySpellID then local aura = C_UnitAuras.GetPlayerAuraBySpellID(260286); if aura then apps = aura.applications or 1 end end
        return apps, 3, classColor, true
    elseif playerClass == "WARRIOR" and spec == 72 then
        local apps = 0
        if C_UnitAuras.GetPlayerAuraBySpellID then local aura = C_UnitAuras.GetPlayerAuraBySpellID(85739) or C_UnitAuras.GetPlayerAuraBySpellID(322166); if aura then apps = aura.applications or 1 end end
        return apps, 4, classColor, true
    end
    return 0, 0, DEFAULT_COLOR, false
end

local function GetChargeData(spellID, maxFallback, color)
    local chargeInfo = C_Spell.GetSpellCharges(spellID)
    if not chargeInfo then return 0, maxFallback, color, false, maxFallback, true, 0, nil end
    local rawCur = chargeInfo.currentCharges or 0
    local maxC = chargeInfo.maxCharges
    if IsSecret(maxC) or type(maxC) ~= "number" then maxC = maxFallback end
    
    local exactCur = 0
    if IsSecret(rawCur) then
        if not CR.sharedArcDecoder then
            CR.sharedArcDecoder = CreateFrame("Frame", "WishFlex_ArcDecoder", UIParent)
            CR.sharedArcDecoder:SetSize(1, 1)
            CR.sharedArcDecoder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -5000, -5000)
            CR.sharedArcDecoder:Show()
            CR.arcDetectors = {}
        end
        if not CR.arcDetectors[spellID] then CR.arcDetectors[spellID] = {} end
        local dets = CR.arcDetectors[spellID]
        
        for i = 1, maxC do
            if not dets[i] then
                local det = CreateFrame("StatusBar", nil, CR.sharedArcDecoder)
                det:SetSize(1, 1); det:SetPoint("BOTTOMLEFT", CR.sharedArcDecoder, "BOTTOMLEFT", 0, 0); det:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
                dets[i] = det
            end
            dets[i]:SetMinMaxValues(i - 1, i)
            pcall(function() dets[i]:SetValue(rawCur) end)
        end
        local count = 0
        for i = 1, maxC do local tex = dets[i] and dets[i]:GetStatusBarTexture(); if tex and tex:IsShown() then count = i end end
        exactCur = count
    else exactCur = rawCur end
    
    local durObj = nil
    if exactCur < maxC then durObj = C_Spell.GetSpellChargeDuration(spellID) end
    return exactCur, maxC, color, false, maxC, true, exactCur, durObj
end

function CR:UpdateDividers(bar, maxVal)
    bar.dividers = bar.dividers or {}
    local numMax = (IsSecret(maxVal) and 1) or (tonumber(maxVal) or 1)
    if numMax <= 0 then numMax = 1 end; if numMax > 20 then numMax = 20 end 
    local width = bar:GetWidth() or 250
    if bar._lastDividerMax == numMax and bar._lastDividerWidth == width then return end
    bar._lastDividerMax = numMax; bar._lastDividerWidth = width
    local numDividers = numMax > 1 and (numMax - 1) or 0
    local segWidth = width / numMax
    local targetFrame = bar.gridFrame or bar.textFrame or bar
    
    for i = 1, numDividers do
        if not bar.dividers[i] then
            local tex = targetFrame:CreateTexture(nil, "OVERLAY", nil, 7)
            tex:SetColorTexture(0, 0, 0, 1); tex:SetWidth(1); bar.dividers[i] = tex
        end
        bar.dividers[i]:ClearAllPoints()
        bar.dividers[i]:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", segWidth * i, 0)
        bar.dividers[i]:SetPoint("BOTTOMLEFT", targetFrame, "BOTTOMLEFT", segWidth * i, 0)
        bar.dividers[i]:Show()
    end
    for i = numDividers + 1, #bar.dividers do if bar.dividers[i] then bar.dividers[i]:Hide() end end
end

local function SafeSetDurationText(fontString, remaining)
    if not fontString then return end
    if not remaining then fontString:SetText(""); return end
    local ok, result = pcall(function()
        local num = tonumber(remaining)
        if num then
            if num >= 60 then return string.format("%dm", math.floor(num / 60))
            elseif num >= 10 then return string.format("%d", math.floor(num))
            else return string.format("%.1f", num) end
        end
        return remaining 
    end)
    if ok and result then fontString:SetText(result) else pcall(function() fontString:SetText(remaining) end) end
end

local function FormatSafeText(bar, textCfg, current, maxVal, isTime, pType, showText, durObj)
    if not bar.text or not bar.timerText then return end
    local fontPath = LSM:Fetch("font", textCfg.font) or E.media.normFont
    local fontSize = tonumber(textCfg.fontSize) or 12
    local fontOutline = textCfg.outline or "OUTLINE"
    if bar._lastFont ~= fontPath or bar._lastSize ~= fontSize or bar._lastOutline ~= fontOutline then
        bar.text:FontTemplate(fontPath, fontSize, fontOutline)
        bar.timerText:FontTemplate(fontPath, fontSize, fontOutline)
        bar._lastFont = fontPath; bar._lastSize = fontSize; bar._lastOutline = fontOutline
    end
    local c = textCfg.color or DEFAULT_COLOR
    if bar._lastColorR ~= c.r or bar._lastColorG ~= c.g or bar._lastColorB ~= c.b then
        bar.text:SetTextColor(c.r, c.g, c.b)
        bar.timerText:SetTextColor(c.r, c.g, c.b)
        bar._lastColorR = c.r; bar._lastColorG = c.g; bar._lastColorB = c.b
    end
    local mainAnchor = textCfg.textAnchor or "CENTER"
    local timerAnchor = textCfg.timerAnchor or "CENTER"
    local showMain = (textCfg.textEnable ~= false) and (textCfg.textFormat ~= "NONE") and showText
    local showTimer = (textCfg.timerEnable ~= false) and showText

    bar.text:ClearAllPoints(); bar.text:SetPoint(mainAnchor, bar.textFrame, mainAnchor, tonumber(textCfg.xOffset) or 0, tonumber(textCfg.yOffset) or 0); bar.text:SetJustifyH(mainAnchor)
    bar.timerText:ClearAllPoints(); bar.timerText:SetPoint(timerAnchor, bar.textFrame, timerAnchor, tonumber(textCfg.timerXOffset) or 0, tonumber(textCfg.timerYOffset) or 0); bar.timerText:SetJustifyH(timerAnchor)

    if durObj and type(current) == "number" then
        local remain = nil
        if type(durObj.GetRemainingDuration) == "function" then remain = durObj:GetRemainingDuration()
        elseif durObj.expirationTime then remain = durObj.expirationTime - GetTime() end
        if remain then
            if showMain then bar.text:SetFormattedText("%d", current); bar.text:Show() else bar.text:Hide() end
            if showTimer then SafeSetDurationText(bar.timerText, remain); bar.timerText:Show() else bar.timerText:Hide() end
            return
        end
    end

    bar.timerText:Hide()
    if not showMain then bar.text:Hide() return end
    bar.text:Show()

    local formatMode = textCfg.textFormat
    if formatMode == "AUTO" then if pType == 0 then formatMode = "PERCENT" else formatMode = "ABSOLUTE" end end

    if isTime then SafeSetDurationText(bar.text, current)
    elseif pType == 0 and formatMode == "PERCENT" then
        local scale = (_G.CurveConstants and _G.CurveConstants.ScaleTo100) or 100
        local perc = UnitPowerPercent("player", pType, false, scale)
        if IsSecret(perc) then bar.text:SetFormattedText("%d", perc) else bar.text:SetFormattedText("%d", tonumber(perc) or 0) end
    elseif formatMode == "PERCENT" then
        if pType then
            local perc = UnitPowerPercent("player", pType, false)
            if IsSecret(perc) then bar.text:SetFormattedText("%d", perc) else bar.text:SetFormattedText("%d", tonumber(perc) or 0) end
        else
            if IsSecret(current) or IsSecret(maxVal) then bar.text:SetFormattedText("%d", current)
            else
                local cVal = tonumber(current) or 0; local mVal = tonumber(maxVal) or 1; if mVal <= 0 then mVal = 1 end
                bar.text:SetFormattedText("%d", math.floor((cVal / mVal) * 100 + 0.5))
            end
        end
    elseif formatMode == "BOTH" then
        if IsSecret(current) or IsSecret(maxVal) then bar.text:SetFormattedText("%d / %d", current, maxVal)
        else bar.text:SetText(SafeFormatNum(current) .. " / " .. SafeFormatNum(maxVal)) end
    else
        if IsSecret(current) then bar.text:SetFormattedText("%d", current) else bar.text:SetText(SafeFormatNum(current)) end
    end
end

local function UpdateBarValueSafe(sb, rawCurr, rawMax)
    if IsSecret(rawMax) or IsSecret(rawCurr) then
        sb:SetMinMaxValues(0, rawMax); sb:SetValue(rawCurr); sb._targetValue = nil; sb._currentValue = nil
        return
    end
    local currentMax = select(2, sb:GetMinMaxValues())
    if IsSecret(currentMax) or type(currentMax) ~= "number" or currentMax ~= rawMax then
        sb:SetMinMaxValues(0, rawMax); sb._currentValue = rawCurr; sb._targetValue = rawCurr; sb:SetValue(rawCurr)
    else sb._targetValue = rawCurr end
end

local function SyncAuraBarVisuals(bar, auraCfg)
    if not auraCfg then return end
    if not bar.durationText then
        if bar.cd.timer and bar.cd.timer.text then bar.durationText = bar.cd.timer.text
        else for _, region in pairs({bar.cd:GetRegions()}) do if region:IsObjectType("FontString") then bar.durationText = region; break end end end
    end
    if bar.durationText then
        local fontPath = LSM:Fetch('font', auraCfg.font)
        if bar.lastFont ~= fontPath or bar.lastSize ~= auraCfg.fontSize or bar.lastOutline ~= auraCfg.outline then
            if bar.durationText.FontTemplate then bar.durationText:FontTemplate(fontPath, auraCfg.fontSize, auraCfg.outline) else bar.durationText:SetFont(fontPath, auraCfg.fontSize, auraCfg.outline) end
            bar.lastFont, bar.lastSize, bar.lastOutline = fontPath, auraCfg.fontSize, auraCfg.outline
        end
        local tc = auraCfg.color or {r=1, g=1, b=1, a=1}
        bar.durationText:SetTextColor(tc.r, tc.g, tc.b, tc.a)
        local pos = auraCfg.textPosition or "RIGHT"; local x, y = auraCfg.xOffset or -4, auraCfg.yOffset or 0
        if bar._lastDurPos ~= pos or bar._lastDurX ~= x or bar._lastDurY ~= y then
            bar.durationText:ClearAllPoints(); bar.durationText:SetPoint(pos, bar, pos, x, y); bar.durationText:SetJustifyH(pos)
            bar._lastDurPos, bar._lastDurX, bar._lastDurY = pos, x, y
        end
    end
    local sFontPath = LSM:Fetch('font', auraCfg.stackFont or "Expressway"); local sSize = auraCfg.stackFontSize or 14; local sOutline = auraCfg.stackOutline or "OUTLINE"
    if bar.sLastFont ~= sFontPath or bar.sLastSize ~= sSize or bar.sLastOutline ~= sOutline then
        if bar.stackText.FontTemplate then bar.stackText:FontTemplate(sFontPath, sSize, sOutline) else bar.stackText:SetFont(sFontPath, sSize, sOutline) end
        bar.sLastFont, bar.sLastSize, bar.sLastOutline = sFontPath, sSize, sOutline
    end
    local sc = auraCfg.stackColor or {r=1, g=1, b=1, a=1}
    bar.stackText:SetTextColor(sc.r, sc.g, sc.b, sc.a)
    local sPos = auraCfg.stackPosition or "LEFT"; local sx, sy = auraCfg.stackXOffset or 4, auraCfg.stackYOffset or 0
    if bar._lastStackPos ~= sPos or bar._lastStackX ~= sx or bar._lastStackY ~= sy then
        bar.stackText:ClearAllPoints(); bar.stackText:SetPoint(sPos, bar, sPos, sx, sy); bar.stackText:SetJustifyH(sPos)
        bar._lastStackPos, bar._lastStackX, bar._lastStackY = sPos, sx, sy
    end
end

function CR:GetOrCreateAuraBar(index, specCfg)
    if not CR.AuraBarPool[index] then
        local bar = CreateFrame("Frame", "WishFlexAuraBar"..index, self.auraAnchor)
        bar:SetTemplate("Transparent")
        local statusBar = CreateFrame("StatusBar", nil, bar); statusBar:SetFrameLevel(bar:GetFrameLevel() + 1); bar.statusBar = statusBar
        local bg = statusBar:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bar.statusBar.bg = bg
        local gridFrame = CreateFrame("Frame", nil, bar); gridFrame:SetAllPoints(bar); gridFrame:SetFrameLevel(bar:GetFrameLevel() + 10); bar.gridFrame = gridFrame
        local cd = CreateFrame("Cooldown", nil, statusBar, "CooldownFrameTemplate")
        cd:SetAllPoints(); cd:SetDrawSwipe(false); cd:SetDrawEdge(false); cd:SetDrawBling(false); cd:SetHideCountdownNumbers(false)
        cd.noCooldownOverride = true; cd.noOCC = true; cd.skipElvUICooldown = true; cd:SetFrameLevel(bar:GetFrameLevel() + 20); bar.cd = cd
        local textFrame = CreateFrame("Frame", nil, bar); textFrame:SetAllPoints(bar); textFrame:SetFrameLevel(bar:GetFrameLevel() + 30); bar.auraTextFrame = textFrame
        if not bar.stackText then bar.stackText = textFrame:CreateFontString(nil, "OVERLAY") end
        bar.lastAuraId = nil; bar._lastDurObj = nil
        CR.AuraBarPool[index] = bar
    end
    local bar = CR.AuraBarPool[index]
    
    if specCfg and specCfg.auraBar then
        bar:SetSize(GetTargetWidth(specCfg), specCfg.auraBar.height or 14)
        bar.statusBar:SetInside(bar)
        local texName = specCfg.auraBar.texture or GetDB().texture or "WishFlex-g1"
        local tex = LSM:Fetch("statusbar", texName) or LSM:Fetch("statusbar", "WishFlex-g1")
        bar.statusBar:SetStatusBarTexture(tex)
        bar.statusBar.bg:SetTexture(tex)
        SyncAuraBarVisuals(bar, specCfg.auraBar)
    end
    return bar
end

local auraUpdatePending = false
RequestUpdateAuraBars = function()
    if auraUpdatePending then return end
    auraUpdatePending = true
    C_Timer.After(InCombatLockdown() and 0.05 or 0.2, function() 
        auraUpdatePending = false
        CR:UpdateAuraBars() 
    end)
end

function CR:UpdateAuraBars()
    local db = GetDB()
    local specCfg = self.cachedSpecCfg or GetCurrentSpecConfig(GetCurrentContextID())
    local auraCfg = specCfg.auraBar
    if not auraCfg or not specCfg.showAuraBar then 
        for _, bar in ipairs(CR.AuraBarPool) do bar:Hide() end
        return 
    end
    
    local showAuraTimer = specCfg.textAuraTimer
    local showAuraStack = specCfg.textAuraStack
    
    wipe(activeBuffFrames); wipe(targetAuraCache); wipe(playerAuraCache)

    for _, viewer in ipairs({_G.BuffIconCooldownViewer, _G.BuffBarCooldownViewer}) do
        if viewer and viewer.itemFramePool then
            for f in viewer.itemFramePool:EnumerateActive() do if f.cooldownInfo then activeBuffFrames[#activeBuffFrames+1] = f end end
        end
    end

    local targetScanned = false; local playerScanned = false
    wipe(CR.ActiveAuraBars); wipe(CR.chargeDurCache)
    local activeCount = 0
    
    local currentSpecID = 0
    pcall(function() currentSpecID = GetSpecializationInfo(GetSpecialization()) or 0 end)

    for spellIDStr, spellData in pairs(GetSpellDB()) do
        local v = spellData.auraBar
        if v and (not spellData.class or spellData.class == "ALL" or spellData.class == playerClass) then
            local sSpec = spellData.spec or 0
            if sSpec == 0 or sSpec == currentSpecID then
                local spellID = tonumber(spellIDStr)
                local buffID = spellData.buffID or tonumber(spellID)
                local vis = v.visibility or (v.alwaysShow and 2 or 1)
                local forceShow = (vis == 2) or (vis == 3 and InCombatLockdown())
                local auraActive, auraInstanceID, unit = false, nil, "player"
                local isFakeBuff, fStart, fDur = false, 0, 0
                local auraData = nil; local currentDurObj = nil
                
                local trackType = v.trackType or "aura"
                local mode = v.mode or "time"
                
                local isCharge = (trackType == "charge")
                local isConsume = (trackType == "consume")
                if isCharge then mode = "stack" end 
                
                if isCharge then
                    local cInfo = C_Spell.GetSpellCharges(buffID)
                    if cInfo and type(cInfo.maxCharges) == "number" and not IsSecret(cInfo.maxCharges) then CR.spellMaxChargeCache[buffID] = cInfo.maxCharges end
                    local autoMax = CR.spellMaxChargeCache[buffID] or 2
                    if v.overrideMax then autoMax = v.maxStacks or 2 end
                    local exactCur, maxC, _, _, _, _, _, durObj = GetChargeData(buffID, autoMax, v.color)
                    
                    if exactCur > 0 or durObj or forceShow then
                        auraActive = true
                        auraData = { applications = exactCur, maxCharges = maxC }
                        if durObj then auraInstanceID = tostring(buffID) .. "_charge"; currentDurObj = durObj end
                    end
                else
                    if (v.duration or 0) > 0 then
                        local tracker = CR.manualAuraTrackers[buffID]
                        if tracker and GetTime() < (tracker.start + tracker.dur) then auraActive = true; fStart, fDur = tracker.start, tracker.dur; isFakeBuff = true
                        else CR.manualAuraTrackers[buffID] = nil end
                    else
                        local buffFrame = nil
                        for i = 1, #activeBuffFrames do if MatchesSpellID(activeBuffFrames[i].cooldownInfo, buffID) then buffFrame = activeBuffFrames[i]; break end end
                        if buffFrame then
                            local tempID = buffFrame.auraInstanceID; local tempUnit = buffFrame.auraDataUnit or "player"
                            if IsSafeValue(tempID) then
                                pcall(function() auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(tempUnit, tempID) end)
                                if auraData and IsValidActiveAura(auraData) then auraActive = true; auraInstanceID = tempID; unit = tempUnit end
                            end
                        end
                        if not auraActive then
                            pcall(function() auraData = C_UnitAuras.GetPlayerAuraBySpellID(buffID) end)
                            if auraData and IsValidActiveAura(auraData) then auraActive = true; auraInstanceID = auraData.auraInstanceID; unit = "player"
                            else
                                if not playerScanned then
                                    playerScanned = true
                                    for _, filter in ipairs({"HELPFUL", "HARMFUL"}) do
                                        for i = 1, 40 do
                                            local aura; pcall(function() aura = C_UnitAuras.GetAuraDataByIndex("player", i, filter) end)
                                            if aura then
                                                if IsSafeValue(aura.spellId) then playerAuraCache[aura.spellId] = aura; local baseID = GetBaseSpellFast(aura.spellId); if baseID and baseID ~= aura.spellId then playerAuraCache[baseID] = aura end end
                                            else break end
                                        end
                                    end
                                end
                                local cachedAura = playerAuraCache[buffID]
                                if cachedAura and IsValidActiveAura(cachedAura) then auraData = cachedAura; auraActive = true; auraInstanceID = cachedAura.auraInstanceID; unit = "player"
                                elseif UnitExists("target") then
                                    if not targetScanned then
                                        targetScanned = true
                                        for _, filter in ipairs({"HELPFUL", "HARMFUL"}) do
                                            for i = 1, 40 do
                                                local aura; pcall(function() aura = C_UnitAuras.GetAuraDataByIndex("target", i, filter) end)
                                                if aura then
                                                    if IsSafeValue(aura.spellId) then targetAuraCache[aura.spellId] = aura; local baseID = GetBaseSpellFast(aura.spellId); if baseID and baseID ~= aura.spellId then targetAuraCache[baseID] = aura end end
                                                else break end
                                            end
                                        end
                                    end
                                    local tCached = targetAuraCache[buffID]
                                    if tCached and IsValidActiveAura(tCached) then auraData = tCached; auraActive = true; auraInstanceID = tCached.auraInstanceID; unit = "target" end
                                end
                            end
                        end
                    end
                end

                if auraActive or forceShow then
                    activeCount = activeCount + 1
                    local bar = CR:GetOrCreateAuraBar(activeCount, specCfg)
                    bar.mode = mode
                    bar.buffID = buffID 
                    
                    if showAuraTimer then
                        bar.cd:SetHideCountdownNumbers(false)
                        if bar.durationText then bar.durationText:SetAlpha(1) end
                    else
                        bar.cd:SetHideCountdownNumbers(true)
                        if bar.durationText then bar.durationText:SetAlpha(0) end
                    end
                    if showAuraStack then bar.stackText:SetAlpha(1) else bar.stackText:SetAlpha(0) end
                    
                    if auraActive then bar:SetAlpha(1) else bar:SetAlpha(v.inactiveAlpha or 1) end
                    
                    local useThreshold = v.useThresholdColor
                    local thresholdStacks = v.thresholdStacks or 3
                    local thresholdColor = v.thresholdColor or {r=1,g=0,b=0,a=1}
                    
                    local st = (auraData and auraData.applications) or 0
                    if isCharge then st = (auraData and auraData.applications) or exactCur or 0 end
                    
                    local c = v.color or {r=0, g=0.8, b=1, a=1}
                    if useThreshold and st >= thresholdStacks then c = thresholdColor end
                    
                    bar.statusBar:SetStatusBarColor(c.r, c.g, c.b, c.a)
                    local bgC = v.bgColor or auraCfg.bgColor or {r=0.2, g=0.2, b=0.2, a=0.8}
                    bar.statusBar.bg:SetVertexColor(bgC.r, bgC.g, bgC.b, bgC.a)
                    
                    if not auraActive then
                        if isCharge then
                            local maxS = CR.spellMaxChargeCache[buffID] or (auraData and auraData.maxCharges) or 2
                            if v.overrideMax then maxS = v.maxStacks or 2 end
                            if maxS <= 0 then maxS = 1 end
                            UpdateBarValueSafe(bar.statusBar, 0, maxS)
                            CR:UpdateDividers(bar, maxS)
                        elseif isConsume then
                            local maxS = v.maxStacks or 8
                            if maxS <= 0 then maxS = 1 end
                            UpdateBarValueSafe(bar.statusBar, 0, maxS)
                            CR:UpdateDividers(bar, mode == "stack" and maxS or 0)
                        elseif mode == "stack" then
                            local maxS = v.maxStacks or 8
                            if maxS <= 0 then maxS = 1 end
                            UpdateBarValueSafe(bar.statusBar, 0, maxS)
                            CR:UpdateDividers(bar, maxS)
                        else
                            UpdateBarValueSafe(bar.statusBar, 0, 1)
                            CR:UpdateDividers(bar, 0)
                        end
                        
                        pcall(function() 
                            bar.cd:Clear() 
                            if bar.statusBar.ClearTimerDuration then bar.statusBar:ClearTimerDuration() end
                            if bar.durationText then bar.durationText:SetText("") end
                        end)
                        bar.lastAuraId = nil; bar._lastDurObj = nil; bar._lastRechargingSlot = nil
                        
                        if bar.rechargeOverlay then 
                            bar.rechargeOverlay:Hide() 
                            pcall(function() if bar.rechargeOverlay.ClearTimerDuration then bar.rechargeOverlay:ClearTimerDuration() end end)
                        end
                        UpdateCustomAuraText(bar, buffID, 0, isCharge)
                    else
                        if isCharge then
                            local maxS = CR.spellMaxChargeCache[buffID] or (auraData and auraData.maxCharges) or 2
                            if v.overrideMax then maxS = v.maxStacks or 2 end
                            if maxS <= 0 then maxS = 1 end
                            
                            UpdateBarValueSafe(bar.statusBar, st, maxS)
                            CR:UpdateDividers(bar, maxS)
                            
                            local durObj = currentDurObj
                            if not durObj and auraInstanceID and not isCharge then durObj = C_UnitAuras.GetAuraDuration(unit, auraInstanceID) end
                            
                            if st < maxS then
                                if not bar.rechargeOverlay then
                                    bar.rechargeOverlay = CreateFrame("StatusBar", nil, bar.statusBar)
                                    bar.rechargeOverlay:SetFrameLevel(bar.statusBar:GetFrameLevel() + 1)
                                end
                                bar.rechargeOverlay:SetStatusBarTexture(bar.statusBar:GetStatusBarTexture():GetTexture())
                                bar.rechargeOverlay:SetStatusBarColor(c.r, c.g, c.b, c.a or 0.8)
                                local totalWidth = bar:GetWidth() or 250; local segWidth = totalWidth / maxS
                                bar.rechargeOverlay:ClearAllPoints(); bar.rechargeOverlay:SetPoint("TOPLEFT", bar.statusBar, "TOPLEFT", st * segWidth, 0); bar.rechargeOverlay:SetPoint("BOTTOMLEFT", bar.statusBar, "BOTTOMLEFT", st * segWidth, 0); bar.rechargeOverlay:SetWidth(segWidth)
                                
                                local rechargingSlot = st + 1; local needApplyTimer = false
                                if bar._lastRechargingSlot ~= rechargingSlot then needApplyTimer = true; bar._lastRechargingSlot = rechargingSlot end
                                if durObj and not bar._lastDurObj then needApplyTimer = true end
                                bar._lastDurObj = durObj
                                if needApplyTimer and durObj then
                                    pcall(function()
                                        bar.rechargeOverlay:SetMinMaxValues(0, 1)
                                        bar.rechargeOverlay:SetTimerDuration(durObj, Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Linear or 0, Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime or 0)
                                        if bar.rechargeOverlay.SetToTargetValue then bar.rechargeOverlay:SetToTargetValue() end
                                        bar.cd:SetCooldownFromDurationObject(durObj)
                                    end)
                                end
                                bar.rechargeOverlay:Show()
                            else
                                if bar.rechargeOverlay then bar.rechargeOverlay:Hide() end
                                if bar._lastDurObj ~= nil then 
                                    pcall(function() 
                                        bar.cd:Clear() 
                                        if bar.statusBar.ClearTimerDuration then bar.statusBar:ClearTimerDuration() end
                                        if bar.durationText then bar.durationText:SetText("") end
                                    end)
                                    bar._lastDurObj = nil; bar._lastRechargingSlot = nil 
                                end
                            end
                            UpdateCustomAuraText(bar, buffID, st, true)
                            
                        elseif isConsume then
                            local maxS = v.maxStacks or 8
                            if maxS <= 0 then maxS = 1 end
                            
                            UpdateBarValueSafe(bar.statusBar, st, maxS)
                            CR:UpdateDividers(bar, mode == "stack" and maxS or 0)
                            
                            if bar.rechargeOverlay then bar.rechargeOverlay:Hide() end
                            local durObj = currentDurObj
                            if not durObj and auraInstanceID then durObj = C_UnitAuras.GetAuraDuration(unit, auraInstanceID) end
                            
                            pcall(function() if bar.statusBar.ClearTimerDuration then bar.statusBar:ClearTimerDuration() end end)
                            
                            if durObj then
                                bar.lastAuraId = auraInstanceID
                                if bar._lastDurObj ~= durObj then
                                    bar._lastDurObj = durObj
                                    pcall(function() bar.cd:SetCooldownFromDurationObject(durObj) end)
                                end
                            elseif isFakeBuff then
                                pcall(function() bar.cd:SetCooldown(fStart, fDur) end)
                            else
                                if bar.lastAuraId ~= nil or bar._lastDurObj ~= nil then 
                                    pcall(function() bar.cd:Clear(); if bar.durationText then bar.durationText:SetText("") end end)
                                    bar.lastAuraId = nil; bar._lastDurObj = nil 
                                end
                            end
                            UpdateCustomAuraText(bar, buffID, st, false)
                            
                        elseif mode == "stack" then
                            local maxS = v.maxStacks or 8
                            if maxS <= 0 then maxS = 1 end
                            UpdateBarValueSafe(bar.statusBar, st, maxS)
                            CR:UpdateDividers(bar, maxS)
                            if bar.rechargeOverlay then bar.rechargeOverlay:Hide() end
                            local durObj = currentDurObj
                            if not durObj and auraInstanceID then durObj = C_UnitAuras.GetAuraDuration(unit, auraInstanceID) end
                            if durObj then
                                bar.lastAuraId = auraInstanceID
                                if bar._lastDurObj ~= durObj then
                                    bar._lastDurObj = durObj
                                    pcall(function()
                                        bar.statusBar:SetTimerDuration(durObj, 0, 1)
                                        if bar.statusBar.SetToTargetValue then bar.statusBar:SetToTargetValue() end
                                        bar.cd:SetCooldownFromDurationObject(durObj)
                                    end)
                                end
                            elseif isFakeBuff then
                                pcall(function() bar.cd:SetCooldown(fStart, fDur) end)
                            else
                                if bar.lastAuraId ~= nil or bar._lastDurObj ~= nil then 
                                    pcall(function() 
                                        bar.cd:Clear() 
                                        if bar.statusBar.ClearTimerDuration then bar.statusBar:ClearTimerDuration() end
                                        if bar.durationText then bar.durationText:SetText("") end
                                    end)
                                    bar.lastAuraId = nil; bar._lastDurObj = nil; bar._lastRechargingSlot = nil 
                                end
                            end
                            UpdateCustomAuraText(bar, buffID, st, false)
                        else
                            CR:UpdateDividers(bar, 0)
                            if bar.rechargeOverlay then bar.rechargeOverlay:Hide() end
                            local durObj = currentDurObj
                            if not durObj and auraInstanceID then durObj = C_UnitAuras.GetAuraDuration(unit, auraInstanceID) end
                            
                            if durObj then
                                bar.lastAuraId = auraInstanceID
                                if bar._lastDurObj ~= durObj then
                                    bar._lastDurObj = durObj
                                    pcall(function()
                                        bar.statusBar:SetTimerDuration(durObj, 0, 1)
                                        if bar.statusBar.SetToTargetValue then bar.statusBar:SetToTargetValue() end
                                        bar.cd:SetCooldownFromDurationObject(durObj)
                                    end)
                                end
                            elseif isFakeBuff then
                                pcall(function() bar.cd:SetCooldown(fStart, fDur) end)
                            else
                                if bar.lastAuraId ~= nil or bar._lastDurObj ~= nil then 
                                    pcall(function() 
                                        bar.cd:Clear() 
                                        if bar.statusBar.ClearTimerDuration then bar.statusBar:ClearTimerDuration() end
                                        if bar.durationText then bar.durationText:SetText("") end
                                    end)
                                    bar.lastAuraId = nil; bar._lastDurObj = nil; bar._lastRechargingSlot = nil 
                                end
                                UpdateBarValueSafe(bar.statusBar, 1, 1)
                            end
                            UpdateCustomAuraText(bar, buffID, st, false)
                        end
                    end
                    bar:Show()
                    CR.ActiveAuraBars[activeCount] = bar
                end
            end
        end
    end
    
    for i = activeCount + 1, #CR.AuraBarPool do
        local b = CR.AuraBarPool[i]
        b:Hide()
        pcall(function() 
            b.cd:Clear() 
            if b.statusBar.ClearTimerDuration then b.statusBar:ClearTimerDuration() end
            if b.durationText then b.durationText:SetText("") end
            if b.rechargeOverlay and b.rechargeOverlay.ClearTimerDuration then b.rechargeOverlay:ClearTimerDuration() end
        end)
        b.lastAuraId = nil; b._lastDurObj = nil; b._lastRechargingSlot = nil
    end
    
    for i = 1, activeCount do
        local bar = CR.ActiveAuraBars[i]
        bar:ClearAllPoints()
        if i == 1 then bar:SetPoint("BOTTOM", self.auraAnchor, "BOTTOM", 0, 0)
        else
            local prev = CR.ActiveAuraBars[i-1]
            if auraCfg.growth == "UP" then bar:SetPoint("BOTTOM", prev, "TOP", 0, auraCfg.spacing or 1)
            else bar:SetPoint("TOP", prev, "BOTTOM", 0, -(auraCfg.spacing or 1)) end
        end
    end
end

function CR:GetSpellCatalog()
    local cooldowns, auras = {}, {}
    local seen = {}

    local function processInfo(info, isAura)
        if not info then return end
        local base = info.spellID or 0
        local linked = info.linkedSpellIDs and info.linkedSpellIDs[1]
        local spellID = linked or info.overrideSpellID or (base > 0 and base) or nil
        if spellID and spellID > 0 and not seen[spellID] then
            local name = nil; local icon = nil
            pcall(function() local sInfo = C_Spell.GetSpellInfo(spellID); if sInfo then name = sInfo.name; icon = sInfo.iconID end end)
            if not name then pcall(function() name = C_Spell.GetSpellName(spellID) end) end
            if not icon then pcall(function() icon = C_Spell.GetSpellTexture(spellID) end) end
            if name then seen[spellID] = true; local entry = { spellID = spellID, name = name, icon = icon or 134400 }; if isAura then auras[#auras + 1] = entry else cooldowns[#cooldowns + 1] = entry end end
        end
    end

    local viewers = { {name = "BuffIconCooldownViewer", isAura = true}, {name = "BuffBarCooldownViewer", isAura = true}, {name = "EssentialCooldownViewer", isAura = false}, {name = "UtilityCooldownViewer", isAura = false} }
    for _, vData in ipairs(viewers) do
        local viewer = _G[vData.name]
        if viewer then
            pcall(function()
                if viewer.itemFramePool then for frame in viewer.itemFramePool:EnumerateActive() do local cdID = frame.cooldownID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID); if cdID then processInfo(C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID), vData.isAura) end end
                else for _, child in ipairs({ viewer:GetChildren() }) do local cdID = child.cooldownID or (child.cooldownInfo and child.cooldownInfo.cooldownID); if cdID then processInfo(C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID), vData.isAura) end end end
            end)
        end
    end

    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet then
        pcall(function()
            local aIDsF = C_CooldownViewer.GetCooldownViewerCategorySet(3, false); if aIDsF then for _, cdID in ipairs(aIDsF) do processInfo(C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID), true) end end
            local aIDsT = C_CooldownViewer.GetCooldownViewerCategorySet(3, true); if aIDsT then for _, cdID in ipairs(aIDsT) do processInfo(C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID), true) end end
            local cIDsF = C_CooldownViewer.GetCooldownViewerCategorySet(2, false); if cIDsF then for _, cdID in ipairs(cIDsF) do processInfo(C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID), false) end end
            local cIDsT = C_CooldownViewer.GetCooldownViewerCategorySet(2, true); if cIDsT then for _, cdID in ipairs(cIDsT) do processInfo(C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID), false) end end
        end)
    end
    table.sort(cooldowns, function(a, b) return a.name < b.name end); table.sort(auras, function(a, b) return a.name < b.name end)
    return cooldowns, auras
end

function CR:ShowSpellSelectionWindow()
    local cooldowns, auras = self:GetSpellCatalog()
    local frame = AceGUI:Create("Frame"); frame:SetTitle("WishFlex: 技能与增益扫描器"); frame:SetLayout("Fill"); frame:SetWidth(450); frame:SetHeight(500); frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    local tabGroup = AceGUI:Create("TabGroup"); tabGroup:SetLayout("Fill"); tabGroup:SetTabs({{text = "增益状态 (Buff)", value = "auras"}, {text = "冷却技能 (Cooldown)", value = "cooldowns"}})

    local function CreateEntry(scroll, item, isAura)
        local row = AceGUI:Create("InteractiveLabel"); row:SetText(" " .. item.name .. "  |cff888888(ID: " .. item.spellID .. ")|r"); row:SetImage(item.icon); row:SetImageSize(28, 28); row:SetFontObject(GameFontHighlight); row:SetFullWidth(true)
        row:SetCallback("OnClick", function()
            local idStr = tostring(item.spellID)
            local sDB = GetSpellDB()
            if not sDB[idStr] then
                local currentSpecID = 0; pcall(function() currentSpecID = GetSpecializationInfo(GetSpecialization()) or 0 end)
                sDB[idStr] = { buffID = item.spellID, class = playerClass, spec = currentSpecID, hideOriginal = true }
            end
            local d = sDB[idStr]
            
            d.class = playerClass 
            
            if not d.auraBar then
                local tType = isAura and "aura" or "charge"
                local initMode = isAura and "time" or "stack"
                d.auraBar = { enable = true, visibility = 1, inactiveAlpha = 1, mode = initMode, trackType = tType, overrideMax = false, maxStacks = 5, color = {r=0,g=0.8,b=1,a=1}, useThresholdColor = false, thresholdStacks = 3, thresholdColor = {r=1,g=0,b=0,a=1} }
            end
            CR.selectedAuraBarSpell = idStr
            CR:BuildAuraCache(); RequestUpdateAuraBars()
            local CC = WF:GetModule('CooldownCustom', true); if CC and CC.TriggerLayout then CC:TriggerLayout() end
            
            if E.Libs.AceConfigRegistry then E.Libs.AceConfigRegistry:NotifyChange("ElvUI") end
            if E.Libs.AceConfigDialog then E.Libs.AceConfigDialog:SelectGroup("ElvUI", "WishFlex", "classResource", "auraBarTab", "spellManagement") end
            frame:Hide()
        end)
        row:SetCallback("OnEnter", function(widget) GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPRIGHT"); GameTooltip:SetSpellByID(item.spellID); GameTooltip:Show() end)
        row:SetCallback("OnLeave", function() GameTooltip:Hide() end)
        scroll:AddChild(row)
    end

    tabGroup:SetCallback("OnGroupSelected", function(container, event, group)
        container:ReleaseChildren()
        local scroll = AceGUI:Create("ScrollFrame"); scroll:SetLayout("Flow"); container:AddChild(scroll)
        local label = AceGUI:Create("Label"); label:SetText("使用说明：点击下方的条目即可快速添加到进度条监控中。\n提示：请在战斗中或拥有BUFF/技能冷却时打开此界面以获取最新缓存。\n\n"); label:SetFullWidth(true); label:SetFontObject(GameFontNormal); scroll:AddChild(label)
        local list = (group == "auras") and auras or cooldowns; local isAura = (group == "auras")
        if #list == 0 then
            local emptyLabel = AceGUI:Create("Label"); emptyLabel:SetText("当前目录为空。\n请尝试施放带有 BUFF 的技能，或打开一次游戏自带的右上角增益栏面板刷新缓存。"); emptyLabel:SetFullWidth(true); scroll:AddChild(emptyLabel)
        else for _, item in ipairs(list) do CreateEntry(scroll, item, isAura) end end
    end)
    frame:AddChild(tabGroup); tabGroup:SelectTab("auras")
end

local function GetSelectedSpec() return CR.selectedSpecForConfig or GetCurrentContextID() end

-- =========================================
-- [PRO重构]：AceConfig 配置表完全指向各专精独立环境
-- =========================================
local function InjectOptions()
    local function GetOptionsList()
        local opts = {}
        if playerClass == "DRUID" then opts[1000] = "人形态 / 无形态"; opts[1001] = "猎豹形态"; opts[1002] = "熊形态"; opts[1003] = "枭兽形态"; opts[1004] = "旅行形态"
        else local classID = select(3, UnitClass("player")); for i = 1, GetNumSpecializationsForClassID(classID) do local id, name = GetSpecializationInfoForClassID(classID, i); if id and name then opts[id] = name end end; opts[0] = "无专精 / 通用" end
        return opts
    end

    if not CR.selectedSpecForConfig then CR.selectedSpecForConfig = GetCurrentContextID() end

    -- 核心：动态获取当前在下拉菜单选中的专精配置！
    local function GetC() return GetCurrentSpecConfig(CR.selectedSpecForConfig) end

    WF.OptionsArgs = WF.OptionsArgs or {}
    WF.OptionsArgs.classResource = {
        order = 15, type = "group", name = "|cff00ffcc职业资源条|r", childGroups = "tab",
        args = {
            specSelector = {
                order = 0, type = "group", name = "1. 选择要配置的专精环境", guiInline = true,
                args = {
                    selectSpec = { order = 1, type = "select", name = "当前正在设置的专精/形态", values = GetOptionsList, get = function() return CR.selectedSpecForConfig end, set = function(_, v) CR.selectedSpecForConfig = v; CR:UpdateLayout() end },
                    desc = { order = 2, type = "description", name = "\n|cff00ff00核心提示：|r下面所有的【宽度、高度、排版、颜色】都是专精独立的！\n(你在此处修改只影响当前选中的专精，切天赋时会自动替换配置。)" }
                }
            },
            general = {
                order = 1, type = "group", name = "全局锚点设置(所有专精通用)",
                get = function(i) return GetDB()[i[#i]] end,
                set = function(i, v) GetDB()[i[#i]] = v; CR:UpdateLayout() end,
                args = {
                    enable = { order = 2, type = "toggle", name = "启用模块", get = function() return E.db.WishFlex.modules.classResource end, set = function(_, v) E.db.WishFlex.modules.classResource = v; E:StaticPopup_Show("CONFIG_RL") end },
                    alignWithCD = { order = 4, type = "toggle", name = "底层对齐冷却管理器" },
                    alignYOffset = { order = 4.1, type = "range", name = "对齐Y轴间距", min = -50, max = 50, step = 1, disabled = function() return not GetDB().alignWithCD end },
                    widthOffset = { order = 5, type = "range", name = "边框补偿", min = -10, max = 10, step = 1, disabled = function() return not GetDB().alignWithCD end },
                    hideElvUIBars = { 
                        order = 4.5, type = "toggle", name = "自动隐藏 ElvUI 原生能量条",
                        get = function() return GetDB().hideElvUIBars end,
                        set = function(_, v) 
                            if InCombatLockdown() then
                                print("|cffff0000[WishFlex]|r 保护机制：请在脱离战斗后操作此选项！")
                                return
                            end
                            GetDB().hideElvUIBars = v; 
                            if v then 
                                E.db.unitframe.units.player.power.enable = false; 
                                E.db.unitframe.units.player.classbar.enable = false; 
                                if UF then UF:CreateAndUpdateUF('player') end 
                            end; 
                            CR:UpdateLayout() 
                        end
                    },
                    texture = { order = 8, type = "select", dialogControl = 'LSM30_Statusbar', name = "全局后备材质", values = LSM:HashTable("statusbar") },
                }
            },
            layoutTab = {
                order = 2, type = "group", name = "|cff00ff00专精独立：显示与长宽|r",
                get = function(i) return GetC()[i[#i]] end,
                set = function(i, v) GetC()[i[#i]] = v; CR:UpdateLayout() end,
                args = {
                    showPower = { order = 1, type = "toggle", name = "显示能量条" },
                    textPower = { order = 2, type = "toggle", name = "开启能量条文本" },
                    showClass = { order = 3, type = "toggle", name = "显示主资源" },
                    textClass = { order = 4, type = "toggle", name = "开启主资源文本" },
                    showMana = { order = 5, type = "toggle", name = "显示额外法力条", hidden = function() return not hasHealerSpec end },
                    textMana = { order = 6, type = "toggle", name = "开启额外法力文本", hidden = function() return not hasHealerSpec end },
                    showAuraBar = { order = 7, type = "toggle", name = "显示增益条(AuraBar)" },
                    textAuraTimer = { order = 8, type = "toggle", name = "开启Aura倒计时文本" },
                    textAuraStack = { order = 9, type = "toggle", name = "开启Aura层数文本" },
                    spacer = { order = 20, type = "description", name = " \n" },
                    width = { order = 21, type = "range", name = "自定义统一宽度", desc="取消对齐冷却管理器后生效", min = 50, max = 600, step = 1, disabled = function() return GetDB().alignWithCD end },
                    yOffset = { order = 22, type = "range", name = "自动堆叠的垂直间距", min = 0, max = 50, step = 1 },
                }
            },
            powerTab = {
                order = 3, type = "group", name = "专精独立：能量条", get = function(i) return GetC().power[i[#i]] end, set = function(i, v) GetC().power[i[#i]] = v; CR:UpdateLayout() end,
                args = {
                    barGroup = {
                        order = 1, type = "group", name = "框架控制与位置", guiInline = true,
                        args = {
                            independent = { order = 1.1, type = "toggle", name = "独立解锁移动", desc = "开启后脱离自动堆叠序列，可通过ElvUI移动工具随意放置。" },
                            barXOffset = { order = 1.2, type = "range", name = "框架 X轴 偏移", min = -500, max = 500, step = 1 },
                            barYOffset = { order = 1.3, type = "range", name = "框架 Y轴 偏移", min = -500, max = 500, step = 1 },
                            height = { order = 2, type = "range", name = "高度", min = 2, max = 50, step = 1 },
                            useCustomColor = { order = 3, type = "toggle", name = "自定义前景色" },
                            customColor = { order = 4, type = "color", name = "前景色", disabled = function() return not GetC().power.useCustomColor end, get = function() local t = GetC().power.customColor or {r=0,g=0.5,b=1} return t.r, t.g, t.b end, set = function(_, r, g, b) GetC().power.customColor = {r=r,g=g,b=b}; CR:UpdateLayout() end },
                            useCustomTexture = { order = 5, type = "toggle", name = "独立前景材质" },
                            texture = { order = 6, type = "select", dialogControl = 'LSM30_Statusbar', name = "前景材质", disabled = function() return not GetC().power.useCustomTexture end, values = LSM:HashTable("statusbar") },
                            useCustomBgTexture = { order = 7, type = "toggle", name = "独立背景材质" },
                            bgTexture = { order = 8, type = "select", dialogControl = 'LSM30_Statusbar', name = "背景材质", disabled = function() return not GetC().power.useCustomBgTexture end, values = LSM:HashTable("statusbar") },
                            bgColor = { order = 9, type = "color", name = "背景颜色", hasAlpha = true, get = function() local t = GetC().power.bgColor or {r=0,g=0,b=0,a=0.5} return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) GetC().power.bgColor = {r=r,g=g,b=b,a=a}; CR:UpdateLayout() end },
                        }
                    },
                    fontGroup = { order = 2, type = "group", name = "字体样式", guiInline = true, args = { font = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") }, fontSize = { order = 2, type = "range", name = "大小", min = 8, max = 40, step = 1 }, outline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } }, color = { order = 4, type = "color", name = "颜色", get = function() local t = GetC().power.color or {r=1,g=1,b=1} return t.r, t.g, t.b end, set = function(_, r, g, b) GetC().power.color = {r=r,g=g,b=b}; CR:UpdateLayout() end }, } },
                    layoutGroup = { order = 3, type = "group", name = "文本排版", guiInline = true, args = { textFormat = { order = 2, type = "select", name = "文本格式", values = { ["AUTO"] = "自动", ["PERCENT"] = "百分比", ["ABSOLUTE"] = "具体数值", ["BOTH"] = "数值 / 最大值", ["NONE"] = "隐藏" } }, textAnchor = { order = 3, type = "select", name = "对齐方向", values = { ["LEFT"] = "左对齐", ["CENTER"] = "居中对齐", ["RIGHT"] = "右对齐" } }, xOffset = { order = 4, type = "range", name = "文本 X 偏移", min = -200, max = 200, step = 1 }, yOffset = { order = 5, type = "range", name = "文本 Y 偏移", min = -100, max = 100, step = 1 }, } }
                }
            },
            classTab = {
                order = 4, type = "group", name = "专精独立：主资源条", get = function(i) return GetC().class[i[#i]] end, set = function(i, v) GetC().class[i[#i]] = v; CR:UpdateLayout() end,
                args = {
                    barGroup = {
                        order = 1, type = "group", name = "框架控制与位置", guiInline = true,
                        args = {
                            independent = { order = 1.1, type = "toggle", name = "独立解锁移动" },
                            barXOffset = { order = 1.2, type = "range", name = "框架 X轴 偏移", min = -500, max = 500, step = 1 },
                            barYOffset = { order = 1.3, type = "range", name = "框架 Y轴 偏移", min = -500, max = 500, step = 1 },
                            height = { order = 2, type = "range", name = "高度", min = 2, max = 50, step = 1 },
                            useCustomColor = { order = 3, type = "toggle", name = "自定义颜色", get = function() local db = GetC().class if type(db.useCustomColors) ~= "table" then db.useCustomColors = {} end return db.useCustomColors[playerClass] or false end, set = function(_, v) local db = GetC().class if type(db.useCustomColors) ~= "table" then db.useCustomColors = {} end db.useCustomColors[playerClass] = v CR:UpdateLayout() end },
                            customColor = { order = 4, type = "color", name = "前景色", disabled = function() local db = GetC().class return not (type(db.useCustomColors) == "table" and db.useCustomColors[playerClass]) end, get = function() local db = GetC().class if type(db.customColors) ~= "table" then db.customColors = {} end local t = db.customColors[playerClass] if not t then local cc = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass] t = cc and {r=cc.r, g=cc.g, b=cc.b} or {r=1, g=1, b=1} end return t.r, t.g, t.b end, set = function(_, r, g, b) local db = GetC().class if type(db.customColors) ~= "table" then db.customColors = {} end db.customColors[playerClass] = {r=r,g=g,b=b} CR:UpdateLayout() end },
                            useCustomTexture = { order = 5, type = "toggle", name = "独立前景材质" },
                            texture = { order = 6, type = "select", dialogControl = 'LSM30_Statusbar', name = "前景材质", disabled = function() return not GetC().class.useCustomTexture end, values = LSM:HashTable("statusbar") },
                            useCustomBgTexture = { order = 7, type = "toggle", name = "独立背景材质" },
                            bgTexture = { order = 8, type = "select", dialogControl = 'LSM30_Statusbar', name = "背景材质", disabled = function() return not GetC().class.useCustomBgTexture end, values = LSM:HashTable("statusbar") },
                            bgColor = { order = 9, type = "color", name = "背景颜色", hasAlpha = true, get = function() local t = GetC().class.bgColor or {r=0,g=0,b=0,a=0.5} return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) GetC().class.bgColor = {r=r,g=g,b=b,a=a}; CR:UpdateLayout() end },
                        }
                    },
                    fontGroup = { order = 2, type = "group", name = "字体样式", guiInline = true, args = { font = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") }, fontSize = { order = 2, type = "range", name = "大小", min = 8, max = 40, step = 1 }, outline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } }, color = { order = 4, type = "color", name = "颜色", get = function() local t = GetC().class.color or {r=1,g=1,b=1} return t.r, t.g, t.b end, set = function(_, r, g, b) GetC().class.color = {r=r,g=g,b=b}; CR:UpdateLayout() end }, } },
                    layoutGroup = { order = 3, type = "group", name = "文本排版", guiInline = true, args = { textFormat = { order = 2, type = "select", name = "文本格式", values = { ["AUTO"] = "自动", ["PERCENT"] = "百分比", ["ABSOLUTE"] = "具体数值", ["BOTH"] = "数值 / 最大值", ["NONE"] = "隐藏" } }, textAnchor = { order = 3, type = "select", name = "对齐方向", values = { ["LEFT"] = "左对齐", ["CENTER"] = "居中对齐", ["RIGHT"] = "右对齐" } }, xOffset = { order = 4, type = "range", name = "文本 X 偏移", min = -200, max = 200, step = 1 }, yOffset = { order = 5, type = "range", name = "文本 Y 偏移", min = -100, max = 100, step = 1 }, } }
                }
            },
            manaTab = {
                order = 5, type = "group", name = "专精独立：专属法力条", hidden = function() return not hasHealerSpec end, get = function(i) return GetC().mana[i[#i]] end, set = function(i, v) GetC().mana[i[#i]] = v; CR:UpdateLayout() end,
                args = {
                    barGroup = {
                        order = 1, type = "group", name = "框架控制与位置", guiInline = true,
                        args = {
                            independent = { order = 2.1, type = "toggle", name = "独立解锁移动" },
                            barXOffset = { order = 4, type = "range", name = "框架 X轴 偏移", min = -500, max = 500, step = 1 },
                            barYOffset = { order = 5, type = "range", name = "框架 Y轴 偏移", min = -500, max = 500, step = 1 },
                            height = { order = 3, type = "range", name = "高度", min = 2, max = 50, step = 1 },
                            useCustomColor = { order = 6, type = "toggle", name = "自定义前景色" },
                            customColor = { order = 7, type = "color", name = "前景色", disabled = function() return not GetC().mana.useCustomColor end, get = function() local t = GetC().mana.customColor or {r=0,g=0.5,b=1} return t.r, t.g, t.b end, set = function(_, r, g, b) GetC().mana.customColor = {r=r,g=g,b=b}; CR:UpdateLayout() end },
                            useCustomTexture = { order = 8, type = "toggle", name = "独立前景材质" },
                            texture = { order = 9, type = "select", dialogControl = 'LSM30_Statusbar', name = "前景材质", disabled = function() return not GetC().mana.useCustomTexture end, values = LSM:HashTable("statusbar") },
                            useCustomBgTexture = { order = 10, type = "toggle", name = "独立背景材质" },
                            bgTexture = { order = 11, type = "select", dialogControl = 'LSM30_Statusbar', name = "背景材质", disabled = function() return not GetC().mana.useCustomBgTexture end, values = LSM:HashTable("statusbar") },
                            bgColor = { order = 12, type = "color", name = "背景颜色", hasAlpha = true, get = function() local t = GetC().mana.bgColor or {r=0,g=0,b=0,a=0.5} return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) GetC().mana.bgColor = {r=r,g=g,b=b,a=a}; CR:UpdateLayout() end },
                        }
                    },
                    fontGroup = { order = 2, type = "group", name = "字体样式", guiInline = true, args = { font = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") }, fontSize = { order = 2, type = "range", name = "大小", min = 8, max = 40, step = 1 }, outline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } }, color = { order = 4, type = "color", name = "颜色", get = function() local t = GetC().mana.color or {r=1,g=1,b=1} return t.r, t.g, t.b end, set = function(_, r, g, b) GetC().mana.color = {r=r,g=g,b=b}; CR:UpdateLayout() end }, } },
                    layoutGroup = { order = 3, type = "group", name = "文本排版", guiInline = true, args = { textFormat = { order = 2, type = "select", name = "文本格式", values = { ["AUTO"] = "自动", ["PERCENT"] = "百分比", ["ABSOLUTE"] = "具体数值", ["BOTH"] = "数值 / 最大值", ["NONE"] = "隐藏" } }, textAnchor = { order = 3, type = "select", name = "对齐方向", values = { ["LEFT"] = "左对齐", ["CENTER"] = "居中对齐", ["RIGHT"] = "右对齐" } }, xOffset = { order = 4, type = "range", name = "文本 X 偏移", min = -200, max = 200, step = 1 }, yOffset = { order = 5, type = "range", name = "文本 Y 偏移", min = -100, max = 100, step = 1 }, } }
                }
            },
            auraBarTab = {
                order = 7, type = "group", name = "专精独立：增益条(AuraBar)",
                get = function(info) return GetC().auraBar[info[#info]] end,
                set = function(info, v) GetC().auraBar[info[#info]] = v; CR:UpdateLayout() end,
                args = {
                    spellManagement = {
                        order = 3, type = "group", name = "全局：技能与BUFF监控管理", guiInline = true,
                        args = {
                            openScanner = {
                                order = 1, type = "execute", name = "1. 打开 技能/BUFF 扫描器", desc = "打开可视化扫描窗口快速添加你想要监控的技能或BUFF。",
                                func = function() CR:ShowSpellSelectionWindow() end
                            },
                            addManual = { 
                                order = 1.5, type = "input", name = "手动添加技能/BUFF ID", get = function() return "" end, 
                                set = function(_, val) 
                                    local id = tonumber(val) 
                                    if id then 
                                        local sDB = GetSpellDB()
                                        if not sDB[tostring(id)] then sDB[tostring(id)] = {} end
                                        local d = sDB[tostring(id)]
                                        d.buffID = id; d.class = playerClass; d.spec = GetSpecializationInfo(GetSpecialization()) or 0; d.hideOriginal = true
                                        d.auraBar = { enable = true, visibility = 1, inactiveAlpha = 1, mode = "time", trackType = "aura", overrideMax = false, maxStacks = 5, color = {r=0,g=0.8,b=1,a=1}, useThresholdColor = false, thresholdStacks = 3, thresholdColor = {r=1,g=0,b=0,a=1} }
                                        CR.selectedAuraBarSpell = tostring(id)
                                        CR:BuildAuraCache(); RequestUpdateAuraBars() 
                                    end 
                                end 
                            },
                            selectSpell = { 
                                order = 2, type = "select", name = "2. 管理已添加的监控", 
                                values = function() 
                                    local vals = {} 
                                    local currentSpecID = 0
                                    pcall(function() currentSpecID = GetSpecializationInfo(GetSpecialization()) or 0 end)
                                    for k, v in pairs(GetSpellDB()) do 
                                        if (not v.class or v.class == "ALL" or v.class == playerClass) and v.auraBar then
                                            local sSpec = v.spec or 0
                                            if sSpec == 0 or sSpec == currentSpecID then
                                                local id = tonumber(k); local name = "未知技能"
                                                pcall(function() name = C_Spell.GetSpellName(id) or "未知技能" end)
                                                vals[k] = name .. " (" .. k .. ")"
                                            end
                                        end
                                    end 
                                    return vals 
                                end,
                                get = function() return CR.selectedAuraBarSpell end, 
                                set = function(_, v) CR.selectedAuraBarSpell = v end 
                            },
                            enableSpell = { order = 3, type = "toggle", name = "启用该监控", get = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; return d and d.auraBar and d.auraBar.enable or false end, set = function(_,v) if CR.selectedAuraBarSpell then GetSpellDB()[CR.selectedAuraBarSpell].auraBar.enable = v; CR:BuildAuraCache(); RequestUpdateAuraBars() end end, disabled = function() return not CR.selectedAuraBarSpell end },
                            spec = { 
                                order = 3.2, type = "select", name = "所属专精", desc = "切换不在设定范围内的专精时，此条将自动隐藏。",
                                values = function() local vals = { [0] = "通用 (所有专精)" }; for i = 1, 4 do local id, name = GetSpecializationInfo(i); if id and name then vals[id] = name end end; return vals end,
                                get = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; return d and d.spec or 0 end, 
                                set = function(_,v) if CR.selectedAuraBarSpell then GetSpellDB()[CR.selectedAuraBarSpell].spec = v; CR:BuildAuraCache(); RequestUpdateAuraBars() end end, 
                                disabled = function() return not CR.selectedAuraBarSpell end 
                            },
                            trackType = {
                                order = 3.3, type = "select", name = "|cff00ffcc监控机制(极重要)|r", desc = "【常规增益】: 进度条随持续时间减少\n【消耗型层数】: 进度条随BUFF层数减少 (例如粉碎混沌)\n【技能充能】: 进度条随充能恢复从0开始增长",
                                values = { aura = "常规增益 (随时间递减)", consume = "消耗型层数 (从满层往下掉)", charge = "技能充能 (从0层开始填充)" },
                                get = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; return d and d.auraBar and d.auraBar.trackType or "aura" end,
                                set = function(_,v) if CR.selectedAuraBarSpell then GetSpellDB()[CR.selectedAuraBarSpell].auraBar.trackType = v; RequestUpdateAuraBars() end end,
                                disabled = function() return not CR.selectedAuraBarSpell end
                            },
                            hideOriginal = { 
                                order = 3.5, type = "toggle", name = "隐藏右上角原 BUFF", desc = "开启后交由系统无污染接管隐藏。",
                                get = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; return d and d.hideOriginal ~= false end, 
                                set = function(_,v) if CR.selectedAuraBarSpell then GetSpellDB()[CR.selectedAuraBarSpell].hideOriginal = v; CR:BuildAuraCache(); RequestUpdateAuraBars(); local CC = WF:GetModule('CooldownCustom', true); if CC and CC.TriggerLayout then CC:TriggerLayout() end end end, 
                                disabled = function() return not CR.selectedAuraBarSpell end 
                            },
                            visibility = { 
                                order = 4, type = "select", name = "显示条件", desc = "设置何时显示此监控条", 
                                values = { [1] = "仅在拥有该状态时显示", [2] = "常驻显示 (没有时也显示空槽)", [3] = "仅战斗中常驻 (脱战隐藏空槽)" }, 
                                get = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; if not d or not d.auraBar then return 1 end; return d.auraBar.visibility or (d.auraBar.alwaysShow and 2 or 1) end, 
                                set = function(_,v) if CR.selectedAuraBarSpell then local d = GetSpellDB()[CR.selectedAuraBarSpell].auraBar; d.visibility = v; d.alwaysShow = (v == 2); RequestUpdateAuraBars() end end, 
                                disabled = function() return not CR.selectedAuraBarSpell end 
                            },
                            inactiveAlpha = { 
                                order = 4.1, type = "range", name = "空槽透明度", min = 0, max = 1, step = 0.05, 
                                get = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; return d and d.auraBar and d.auraBar.inactiveAlpha or 1 end, 
                                set = function(_,v) if CR.selectedAuraBarSpell then GetSpellDB()[CR.selectedAuraBarSpell].auraBar.inactiveAlpha = v; RequestUpdateAuraBars() end end, 
                                disabled = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; return not d or not d.auraBar or (d.auraBar.visibility or (d.auraBar.alwaysShow and 2 or 1)) == 1 end 
                            },
                            mode = { 
                                order = 5, type = "select", name = "是否显示网格线", desc = "将进度条分段显示", 
                                values = { time = "平滑过渡(无网格)", stack = "显示网格线(分段)" }, 
                                get = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; return d and d.auraBar and d.auraBar.mode or "time" end, 
                                set = function(_,v) if CR.selectedAuraBarSpell then GetSpellDB()[CR.selectedAuraBarSpell].auraBar.mode = v; RequestUpdateAuraBars() end end, 
                                hidden = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; return d and d.auraBar and d.auraBar.trackType == "charge" end,
                                disabled = function() return not CR.selectedAuraBarSpell end 
                            },
                            overrideMax = {
                                order = 5.5, type = "toggle", name = "手动覆盖最大层数", desc = "如果不勾选，插件会自动读取最高充能层数。\n如果暴雪加密了层数，可勾选此项强制设置。",
                                get = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; return d and d.auraBar and d.auraBar.overrideMax or false end,
                                set = function(_,v) if CR.selectedAuraBarSpell then GetSpellDB()[CR.selectedAuraBarSpell].auraBar.overrideMax = v; RequestUpdateAuraBars() end end,
                                hidden = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; return not d or not d.auraBar or d.auraBar.trackType ~= "charge" end,
                                disabled = function() return not CR.selectedAuraBarSpell end
                            },
                            maxStacks = { 
                                order = 6, type = "range", name = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; if d and d.auraBar and d.auraBar.trackType == "charge" then return "强制指定充能数" elseif d and d.auraBar and d.auraBar.trackType == "consume" then return "该BUFF的满层层数" else return "网格切分数(满层数)" end end, 
                                desc = "设定此BUFF/技能的满层状态，用于计算进度条比例。", min = 1, max = 20, step = 1, 
                                get = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; return d and d.auraBar and d.auraBar.maxStacks or 8 end, 
                                set = function(_,v) if CR.selectedAuraBarSpell then GetSpellDB()[CR.selectedAuraBarSpell].auraBar.maxStacks = v; RequestUpdateAuraBars() end end, 
                                hidden = function() local d=CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; if not d or not d.auraBar then return true end; if d.auraBar.trackType == "charge" and not d.auraBar.overrideMax then return true end; if d.auraBar.trackType == "aura" and d.auraBar.mode ~= "stack" then return true end; return false end,
                            },
                            color = { order = 7, type = "color", name = "专属前景色", hasAlpha = true, get = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; local c = d and d.auraBar and d.auraBar.color or {r=0,g=0.8,b=1,a=1}; return c.r,c.g,c.b,c.a end, set = function(_,r,g,b,a) if CR.selectedAuraBarSpell then GetSpellDB()[CR.selectedAuraBarSpell].auraBar.color={r=r,g=g,b=b,a=a}; RequestUpdateAuraBars() end end, disabled = function() return not CR.selectedAuraBarSpell end },
                            useThresholdColor = { order = 7.1, type = "toggle", name = "启用高层变色", desc="例如灵魂碎片>=4个时进度条变红", get = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; return d and d.auraBar and d.auraBar.useThresholdColor or false end, set = function(_,v) if CR.selectedAuraBarSpell then GetSpellDB()[CR.selectedAuraBarSpell].auraBar.useThresholdColor = v; RequestUpdateAuraBars() end end, disabled = function() return not CR.selectedAuraBarSpell end },
                            thresholdStacks = { order = 7.2, type = "range", name = "触发层数(>=)", min = 1, max = 20, step = 1, get = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; return d and d.auraBar and d.auraBar.thresholdStacks or 3 end, set = function(_,v) if CR.selectedAuraBarSpell then GetSpellDB()[CR.selectedAuraBarSpell].auraBar.thresholdStacks = v; RequestUpdateAuraBars() end end, disabled = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; return not d or not d.auraBar or not d.auraBar.useThresholdColor end },
                            thresholdColor = { order = 7.3, type = "color", name = "专属高层颜色", hasAlpha = true, get = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; local c = d and d.auraBar and d.auraBar.thresholdColor or {r=1,g=0,b=0,a=1}; return c.r,c.g,c.b,c.a end, set = function(_,r,g,b,a) if CR.selectedAuraBarSpell then GetSpellDB()[CR.selectedAuraBarSpell].auraBar.thresholdColor={r=r,g=g,b=b,a=a}; RequestUpdateAuraBars() end end, disabled = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; return not d or not d.auraBar or not d.auraBar.useThresholdColor end },
                            
                            bgColor = { order = 8, type = "color", name = "专属背景色", hasAlpha = true, get = function() local d = CR.selectedAuraBarSpell and GetSpellDB()[CR.selectedAuraBarSpell]; local c = d and d.auraBar and d.auraBar.bgColor or {r=0,g=0,b=0,a=0.8}; return c.r,c.g,c.b,c.a end, set = function(_,r,g,b,a) if CR.selectedAuraBarSpell then GetSpellDB()[CR.selectedAuraBarSpell].auraBar.bgColor={r=r,g=g,b=b,a=a}; RequestUpdateAuraBars() end end, disabled = function() return not CR.selectedAuraBarSpell end },
                            deleteSpell = { order = 9, type = "execute", name = "删除选中监控", func = function() if CR.selectedAuraBarSpell then GetSpellDB()[CR.selectedAuraBarSpell].auraBar = nil; if not GetSpellDB()[CR.selectedAuraBarSpell].auraGlow then GetSpellDB()[CR.selectedAuraBarSpell] = nil end; CR.selectedAuraBarSpell = nil; CR:BuildAuraCache(); RequestUpdateAuraBars() end end, disabled = function() return not CR.selectedAuraBarSpell end }
                        }
                    },
                    layoutGroup = {
                        order = 5, type = "group", name = "专精独立：整体框架控制与材质", guiInline = true,
                        args = {
                            independent = { order = 0.1, type = "toggle", name = "独立解锁移动", desc = "开启后脱离底部自动堆叠序列，可通过ElvUI自由移动整组增益条。" },
                            barXOffset = { order = 0.2, type = "range", name = "整组 X轴 偏移", min = -500, max = 500, step = 1 },
                            barYOffset = { order = 0.3, type = "range", name = "整组 Y轴 偏移", min = -500, max = 500, step = 1 },
                            height = { order = 1, type = "range", name = "每根条高度", min = 2, max = 50, step = 1 },
                            spacing = { order = 2, type = "range", name = "条与条内层间距", min = 0, max = 50, step = 1 },
                            growth = { order = 3, type = "select", name = "多BUFF增长方向", values = { UP = "向上", DOWN = "向下" } },
                            texture = { order = 4, type = "select", dialogControl = 'LSM30_Statusbar', name = "默认材质", values = LSM:HashTable("statusbar") },
                            bgColor = { order = 5, type = "color", name = "默认背景色", hasAlpha = true, get = function() local c = GetC().auraBar.bgColor or {r=0.2,g=0.2,b=0.2,a=0.8}; return c.r, c.g, c.b, c.a end, set = function(_, r, g, b, a) GetC().auraBar.bgColor = {r=r, g=g, b=b, a=a}; RequestUpdateAuraBars() end },
                        }
                    },
                    textGroup = {
                        order = 6, type = "group", name = "专精独立：倒数时间文本", guiInline = true,
                        args = {
                            font = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") },
                            fontSize = { order = 2, type = "range", name = "大小", min = 8, max = 40, step = 1 },
                            outline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } },
                            color = { order = 4, type = "color", name = "颜色", hasAlpha = true, get = function() local c = GetC().auraBar.color or {r=1,g=1,b=1,a=1}; return c.r, c.g, c.b, c.a end, set = function(_, r, g, b, a) GetC().auraBar.color = {r=r, g=g, b=b, a=a}; RequestUpdateAuraBars() end },
                            textPosition = { order = 5, type = "select", name = "对齐", values = { LEFT = "左侧", CENTER = "居中", RIGHT = "右侧" } },
                            xOffset = { order = 6, type = "range", name = "文本 X 偏移", min = -50, max = 50, step = 1 },
                            yOffset = { order = 7, type = "range", name = "文本 Y 偏移", min = -50, max = 50, step = 1 },
                        }
                    },
                    stackTextGroup = {
                        order = 7, type = "group", name = "专精独立：层数文本", guiInline = true,
                        args = {
                            stackFont = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") },
                            stackFontSize = { order = 2, type = "range", name = "大小", min = 8, max = 40, step = 1 },
                            stackOutline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } },
                            stackColor = { order = 4, type = "color", name = "颜色", hasAlpha = true, get = function() local c = GetC().auraBar.stackColor or {r=1,g=1,b=1,a=1}; return c.r, c.g, c.b, c.a end, set = function(_, r, g, b, a) GetC().auraBar.stackColor = {r=r, g=g, b=b, a=a}; RequestUpdateAuraBars() end },
                            stackPosition = { order = 5, type = "select", name = "对齐", values = { LEFT = "左侧", CENTER = "居中", RIGHT = "右侧" } },
                            stackXOffset = { order = 6, type = "range", name = "文本 X 偏移", min = -50, max = 50, step = 1 },
                            stackYOffset = { order = 7, type = "range", name = "文本 Y 偏移", min = -50, max = 50, step = 1 },
                        }
                    }
                }
            }
        }
    }
end

-- =========================================
-- [UI 核心渲染引擎 - 全部参数化指向专精表]
-- =========================================
function CR:UpdateLayout()
    self:WakeUp()
    if not self.baseAnchor then return end
    
    local db = GetDB()
    -- 【强制获取当前角色的实际专精配置用于渲染屏幕上的条】
    local currentContextID = GetCurrentContextID()
    local specCfg = GetCurrentSpecConfig(currentContextID)
    self.cachedSpecCfg = specCfg

    self:BuildAuraCache()

    local targetWidth = GetTargetWidth(specCfg)
    self.baseAnchor:SetSize(targetWidth, 14)

    -- 渲染每一个条的样式
    local function ApplyBarGraphics(bar, barCfg)
        if not bar or not bar.statusBar or not barCfg then return end
        local texName = (barCfg.useCustomTexture and barCfg.texture and barCfg.texture ~= "") and barCfg.texture or db.texture
        local tex = LSM:Fetch("statusbar", texName) or LSM:Fetch("statusbar", "WishFlex-g1")
        bar.statusBar:SetStatusBarTexture(tex)
        if bar.statusBar.bg then
            local bgTexName = (barCfg.useCustomBgTexture and barCfg.bgTexture and barCfg.bgTexture ~= "") and barCfg.bgTexture or db.texture
            local bgTex = LSM:Fetch("statusbar", bgTexName) or LSM:Fetch("statusbar", "WishFlex-g1")
            bar.statusBar.bg:SetTexture(bgTex)
            local bgc = barCfg.bgColor or {r=0, g=0, b=0, a=0.5}
            bar.statusBar.bg:SetVertexColor(bgc.r, bgc.g, bgc.b, bgc.a)
        end
    end

    ApplyBarGraphics(self.powerBar, specCfg.power)
    ApplyBarGraphics(self.classBar, specCfg.class)
    ApplyBarGraphics(self.manaBar, specCfg.mana)

    local pType = UnitPowerType("player")
    local pMax = UnitPowerMax("player", pType)
    local validMax = IsSecret(pMax) or ((tonumber(pMax) or 0) > 0)
    self.showPower = specCfg.power and validMax and specCfg.showPower
    
    local _, _, _, hasClassDef = GetClassResourceData()
    self.showClass = specCfg.class and hasClassDef and specCfg.showClass
    
    local manaMax = UnitPowerMax("player", 0)
    local validManaMax = IsSecret(manaMax) or ((tonumber(manaMax) or 0) > 0)
    self.showMana = hasHealerSpec and specCfg.mana and validManaMax and specCfg.showMana

    local stackOrder = {
        { bar = self.manaBar,     show = self.showMana,                  cfg = specCfg.mana,    anchor = self.manaAnchor },
        { bar = self.powerBar,    show = self.showPower,                 cfg = specCfg.power,   anchor = self.powerAnchor },
        { bar = self.classBar,    show = self.showClass,                 cfg = specCfg.class,   anchor = self.classAnchor },
        { bar = self.auraAnchor,  show = specCfg.showAuraBar,            cfg = specCfg.auraBar, anchor = self.auraAnchor, isAura = true }
    }

    local lastStackedFrame = nil
    for _, item in ipairs(stackOrder) do
        local f = item.bar
        if item.show and item.cfg then
            f.isForceHidden = false; f:Show()
            if not item.isAura then f:SetSize(targetWidth, tonumber(item.cfg.height) or 14) else f:SetSize(targetWidth, 1) end
            f:ClearAllPoints()
            if item.cfg.independent then
                f:SetPoint("CENTER", item.anchor.mover or item.anchor, "CENTER", tonumber(item.cfg.barXOffset) or 0, tonumber(item.cfg.barYOffset) or 0)
            else
                if not lastStackedFrame then
                    if db.alignWithCD and _G.EssentialCooldownViewer then
                        f:SetPoint("BOTTOM", _G.EssentialCooldownViewer, "TOP", tonumber(item.cfg.barXOffset) or 0, (tonumber(db.alignYOffset) or 1) + (tonumber(item.cfg.barYOffset) or 0))
                    else
                        f:SetPoint("CENTER", self.baseAnchor.mover or self.baseAnchor, "CENTER", tonumber(item.cfg.barXOffset) or 0, tonumber(item.cfg.barYOffset) or 0)
                    end
                else
                    f:SetPoint("BOTTOM", lastStackedFrame, "TOP", tonumber(item.cfg.barXOffset) or 0, (tonumber(specCfg.yOffset) or 1) + (tonumber(item.cfg.barYOffset) or 0))
                end
                lastStackedFrame = f
            end
        else
            if not item.isAura then f.isForceHidden = true; f:Hide() end
        end
    end
    self:DynamicTick()
    CR:UpdateAuraBars()
end

function CR:DynamicTick()
    if not self.baseAnchor then return end
    local specCfg = self.cachedSpecCfg or GetCurrentSpecConfig(GetCurrentContextID())
    if not specCfg then return end
    self.hasActiveTimer = false

    if self.showPower and specCfg.power then
        local pType = UnitPowerType("player")
        local rawMax = UnitPowerMax("player", pType)
        local rawCurr = UnitPower("player", pType)
        if not IsSecret(rawMax) then if type(rawMax) ~= "number" or rawMax <= 0 then rawMax = 1 end end
        if type(rawCurr) ~= "number" then rawCurr = 0 end
        
        pcall(function() if rawCurr < rawMax then self.hasActiveTimer = true end end)
        
        local pColor = GetSafeColor(specCfg.power, GetPowerColor(pType), false)
        UpdateBarValueSafe(self.powerBar.statusBar, rawCurr, rawMax)
        self.powerBar.statusBar:SetStatusBarColor(pColor.r, pColor.g, pColor.b)
        self:UpdateDividers(self.powerBar, 1)
        
        local textCurr = rawCurr
        pcall(function() textCurr = math.floor(rawCurr) end)
        FormatSafeText(self.powerBar, specCfg.power, textCurr, rawMax, false, pType, specCfg.textPower)
    end

    if self.showClass and specCfg.class then
        local rawCurr, rawMax, cDefColor = GetClassResourceData()
        if not IsSecret(rawMax) then if type(rawMax) ~= "number" or rawMax <= 0 then rawMax = 1 end end
        if type(rawCurr) ~= "number" then rawCurr = 0 end
        
        pcall(function() if rawCurr < rawMax then self.hasActiveTimer = true end end)
        
        local cColor = GetSafeColor(specCfg.class, cDefColor, true)
        UpdateBarValueSafe(self.classBar.statusBar, rawCurr, rawMax)
        self.classBar.statusBar:SetStatusBarColor(cColor.r, cColor.g, cColor.b)
        self:UpdateDividers(self.classBar, rawMax)
        
        local textCurr = rawCurr
        pcall(function() textCurr = math.floor(rawCurr) end)
        FormatSafeText(self.classBar, specCfg.class, textCurr, rawMax, false, nil, specCfg.textClass)
    end
    
    if self.showMana and specCfg.mana then
        local rawMax = UnitPowerMax("player", 0)
        local rawCurr = UnitPower("player", 0)
        if not IsSecret(rawMax) then if type(rawMax) ~= "number" or rawMax <= 0 then rawMax = 1 end end
        if type(rawCurr) ~= "number" then rawCurr = 0 end
        
        pcall(function() if rawCurr < rawMax then self.hasActiveTimer = true end end)
        
        local mColor = GetSafeColor(specCfg.mana, POWER_COLORS[0], false)
        UpdateBarValueSafe(self.manaBar.statusBar, rawCurr, rawMax)
        self.manaBar.statusBar:SetStatusBarColor(mColor.r, mColor.g, mColor.b)
        self:UpdateDividers(self.manaBar, 1)
        
        local textCurr = rawCurr
        pcall(function() textCurr = math.floor(rawCurr) end)
        FormatSafeText(self.manaBar, specCfg.mana, textCurr, rawMax, false, 0, specCfg.textMana)
    end
    
    if playerClass == "MONK" then
        for i = 1, #CR.ActiveAuraBars do
            local bar = CR.ActiveAuraBars[i]
            if bar.buffID and (bar.buffID == 124275 or bar.buffID == 124274 or bar.buffID == 124273 or bar.buffID == 115308) then
                UpdateCustomAuraText(bar, bar.buffID, 0, false)
            end
        end
    end
end

function CR:CreateBarContainer(name, parent)
    local bar = CreateFrame("Frame", name, parent, "BackdropTemplate")
    bar:SetTemplate("Transparent")
    local sb = CreateFrame("StatusBar", nil, bar)
    sb:SetInside(bar)
    bar.statusBar = sb
    local bg = sb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    sb.bg = bg
    local textFrame = CreateFrame("Frame", nil, bar)
    textFrame:SetAllPoints(bar)
    textFrame:SetFrameLevel(bar:GetFrameLevel() + 10)
    bar.textFrame = textFrame
    bar.text = textFrame:CreateFontString(nil, "OVERLAY") 
    bar.timerText = textFrame:CreateFontString(nil, "OVERLAY") 
    return bar
end

function CR:WakeUp(event, unit)
    if (event == "UNIT_AURA" or event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT") and unit ~= "player" then return end
    self.idleTimer = 0
    self.sleepMode = false
end

function CR:OnContextChanged()
    self.selectedSpecForConfig = GetCurrentContextID()
    self.cachedSpecCfg = GetCurrentSpecConfig(self.selectedSpecForConfig)
    self:UpdateLayout()
end

function CR:Initialize()
    GetDB() 
    
    local spellDB = GetSpellDB()
    local db = GetDB()
    if E.db.WishFlex and E.db.WishFlex.spellDB then
        for k, v in pairs(E.db.WishFlex.spellDB) do
            if not spellDB[k] then spellDB[k] = v end
        end
        E.db.WishFlex.spellDB = nil 
    end

    if db.auraBar and db.auraBar.spells then
        for k, v in pairs(db.auraBar.spells) do
            local sid = tostring(k)
            if not spellDB[sid] then spellDB[sid] = {} end
            spellDB[sid].buffID = v.buffID or tonumber(k)
            spellDB[sid].class = v.class or playerClass
            spellDB[sid].spec = v.spec or 0
            if v.hideOriginal ~= nil then spellDB[sid].hideOriginal = v.hideOriginal end
            spellDB[sid].auraBar = v
        end
        db.auraBar.spells = nil 
    end

    InjectOptions()
    
    if not E.db.WishFlex.modules.classResource then return end

    -- 安全脱战重绘
    if GetDB().hideElvUIBars then
        E.db.unitframe.units.player.power.enable = false
        E.db.unitframe.units.player.classbar.enable = false
        E:Delay(1, function() 
            if UF then 
                if not InCombatLockdown() then
                    pcall(function() UF:CreateAndUpdateUF('player') end)
                else
                    local f = CreateFrame("Frame")
                    f:RegisterEvent("PLAYER_REGEN_ENABLED")
                    f:SetScript("OnEvent", function(self)
                        pcall(function() UF:CreateAndUpdateUF('player') end)
                        self:UnregisterAllEvents()
                    end)
                end
            end 
        end)
    end
    
    self.baseAnchor = CreateFrame("Frame", "WishFlex_BaseAnchor", E.UIParent)
    self.baseAnchor:SetPoint("CENTER", E.UIParent, "CENTER", 0, -180)
    self.baseAnchor:SetSize(250, 14)
    E:CreateMover(self.baseAnchor, "WishFlexBaseAnchorMover", "WishFlex: 全局排版起点(底层)", nil, nil, nil, "ALL,WISHFLEX")

    self.manaAnchor = CreateFrame("Frame", "WishFlex_ManaAnchor", E.UIParent)
    self.manaAnchor:SetPoint("CENTER", E.UIParent, "CENTER", 0, -220)
    self.manaAnchor:SetSize(250, 10)
    E:CreateMover(self.manaAnchor, "WishFlexManaMover", "WishFlex: [独立移动] 专属法力条", nil, nil, nil, "ALL,WISHFLEX")

    self.powerAnchor = CreateFrame("Frame", "WishFlex_PowerAnchor", E.UIParent)
    self.powerAnchor:SetPoint("CENTER", E.UIParent, "CENTER", 0, -160)
    self.powerAnchor:SetSize(250, 14)
    E:CreateMover(self.powerAnchor, "WishFlexPowerMover", "WishFlex: [独立移动] 能量条", nil, nil, nil, "ALL,WISHFLEX")

    self.classAnchor = CreateFrame("Frame", "WishFlex_ClassAnchor", E.UIParent)
    self.classAnchor:SetPoint("CENTER", E.UIParent, "CENTER", 0, -140)
    self.classAnchor:SetSize(250, 14)
    E:CreateMover(self.classAnchor, "WishFlexClassMover", "WishFlex: [独立移动] 主资源条", nil, nil, nil, "ALL,WISHFLEX")

    self.auraAnchor = CreateFrame("Frame", "WishFlex_AuraAnchor", E.UIParent)
    self.auraAnchor:SetPoint("CENTER", E.UIParent, "CENTER", 0, -100)
    self.auraAnchor:SetSize(250, 14)
    E:CreateMover(self.auraAnchor, "WishFlexAuraMover", "WishFlex: [独立移动] 增益组(Aura)", nil, nil, nil, "ALL,WISHFLEX")

    self.powerBar = self:CreateBarContainer("WishFlex_PowerBar", E.UIParent)
    self.classBar = self:CreateBarContainer("WishFlex_ClassBar", E.UIParent)
    self.manaBar = self:CreateBarContainer("WishFlex_ManaBar", E.UIParent)
    
    CR.AllBars = {self.powerBar, self.classBar, self.manaBar}
    self.showPower, self.showClass, self.showMana = false, false, false
    self.idleTimer = 0; self.sleepMode = false; self.hasActiveTimer = false
    
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateLayout")
    self:RegisterEvent("UNIT_DISPLAYPOWER", "UpdateLayout")
    self:RegisterEvent("UNIT_MAXPOWER", "UpdateLayout")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnContextChanged")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "OnContextChanged")
    self:RegisterEvent("UNIT_POWER_UPDATE", "WakeUp")
    self:RegisterEvent("UNIT_POWER_FREQUENT", "WakeUp")
    
    self:RegisterEvent("UNIT_AURA", function(e, u) if u == "player" or u == "target" then RequestUpdateAuraBars() end CR:WakeUp(e,u) end)
    self:RegisterEvent("PLAYER_TARGET_CHANGED", function() RequestUpdateAuraBars(); CR:WakeUp() end)
    
    self:RegisterEvent("PLAYER_REGEN_DISABLED", function() RequestUpdateAuraBars(); CR:WakeUp() end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function() RequestUpdateAuraBars(); CR:WakeUp() end)
    self:RegisterEvent("SPELL_UPDATE_CHARGES", function() CR:UpdateAuraBars(); CR:DynamicTick(); CR:WakeUp() end)
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", function() CR:DynamicTick(); RequestUpdateAuraBars(); CR:WakeUp() end)

    E:Delay(0.5, function()
        local CDMod = WF:GetModule('CooldownCustom', true)
        if CDMod and CDMod.TriggerLayout then
            hooksecurefunc(CDMod, "TriggerLayout", function() if GetDB().alignWithCD then CR:UpdateLayout() end end)
        end
    end)
    
    hooksecurefunc(E, "UpdateAll", function()
        local spellDB = GetSpellDB()
        if E.db.WishFlex and E.db.WishFlex.spellDB then
            for k, v in pairs(E.db.WishFlex.spellDB) do if not spellDB[k] then spellDB[k] = v end end
            E.db.WishFlex.spellDB = nil 
        end
        CR:UpdateLayout()
    end)
    
    CR:OnContextChanged()
    
    local ticker = 0
    CR.frameTick = 0
    self.baseAnchor:SetScript("OnUpdate", function(_, elapsed)
        if CR.sleepMode then return end
        CR.frameTick = CR.frameTick + 1
        
        local SMOOTH_SPEED = 15
        local function SmoothBar(bar)
            if bar and bar.statusBar and not bar.isForceHidden then
                local sb = bar.statusBar
                if sb._targetValue and not IsSecret(sb._targetValue) then
                    sb._currentValue = sb._currentValue or sb:GetValue() or 0
                    if not IsSecret(sb._currentValue) then
                        pcall(function()
                            if sb._currentValue ~= sb._targetValue then
                                local diff = sb._targetValue - sb._currentValue
                                if math.abs(diff) < 0.01 then 
                                    sb._currentValue = sb._targetValue
                                else 
                                    sb._currentValue = sb._currentValue + diff * SMOOTH_SPEED * elapsed 
                                end
                                sb:SetValue(sb._currentValue)
                            end
                        end)
                    end
                end
            end
        end

        for i = 1, #CR.AllBars do SmoothBar(CR.AllBars[i]) end
        for i = 1, #CR.ActiveAuraBars do SmoothBar(CR.ActiveAuraBars[i]) end
        
        ticker = ticker + elapsed
        local interval = InCombatLockdown() and 0.05 or 0.2
        if ticker >= interval then
            ticker = 0
            CR:DynamicTick()
            if not InCombatLockdown() then
                CR.idleTimer = (CR.idleTimer or 0) + interval
                if CR.idleTimer >= 2 and not CR.hasActiveTimer then CR.sleepMode = true end
            else CR.idleTimer = 0 end
        end
    end)
end
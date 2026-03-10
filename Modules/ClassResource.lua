local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WF = E:GetModule('WishFlex')
local CR = WF:NewModule('ClassResource', 'AceEvent-3.0')
local LSM = E.Libs.LSM
local UF = E:GetModule('UnitFrames')
local playerClass = select(2, UnitClass("player"))
local hasHealerSpec = (playerClass == "PALADIN" or playerClass == "PRIEST" or playerClass == "SHAMAN" or playerClass == "MONK" or playerClass == "DRUID" or playerClass == "EVOKER")

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.classResource = true

local defaults = {
    enable = true, alignWithCD = false, alignYOffset = 1, hideElvUIBars = true, widthOffset = 2, width = 250, yOffset = 1, texture = "WishFlex-g1", specConfigs = {},
    power = { enable = true, height = 14, textEnable = true, textFormat = "AUTO", textAnchor = "CENTER", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = true, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1}, useCustomTexture = false, texture = "WishFlex-g1", useCustomBgTexture = false, bgTexture = "WishFlex-g1", bgColor = {r=0, g=0, b=0, a=0.5} },
    class = { enable = true, height = 12, textEnable = true, textFormat = "AUTO", textAnchor = "CENTER", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = true, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=1, g=0.96, b=0.41}, useCustomColors = {}, customColors = {}, useCustomTexture = false, texture = "WishFlex-g1", useCustomBgTexture = false, bgTexture = "WishFlex-g1", bgColor = {r=0, g=0, b=0, a=0.5} },
    tertiary = { enable = true, height = 10, textEnable = true, textFormat = "AUTO", textAnchor = "CENTER", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = true, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=0.4, g=0.8, b=1}, useCustomTexture = false, texture = "WishFlex-g1", useCustomBgTexture = false, bgTexture = "WishFlex-g1", bgColor = {r=0, g=0, b=0, a=0.5}, useCustomRechargeColor = false, rechargeColor = {r=1, g=1, b=1, a=0.75} },
    mana = { enable = true, height = 10, textEnable = true, textFormat = "AUTO", textAnchor = "CENTER", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = true, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1}, barXOffset = 0, barYOffset = 0, useCustomTexture = false, texture = "WishFlex-g1", useCustomBgTexture = false, bgTexture = "WishFlex-g1", bgColor = {r=0, g=0, b=0, a=0.5} },
}
P["WishFlex"].classResource = defaults

local DEFAULT_COLOR = {r=1, g=1, b=1}
local POWER_COLORS = { [0]={r=0,g=0.5,b=1}, [1]={r=1,g=0,b=0}, [2]={r=1,g=0.5,b=0.25}, [3]={r=1,g=1,b=0}, [4]={r=1,g=0.96,b=0.41}, [5]={r=0.8,g=0.1,b=0.2}, [7]={r=0.5,g=0.32,b=0.55}, [8]={r=0.3,g=0.52,b=0.9}, [9]={r=0.95,g=0.9,b=0.6}, [11]={r=0,g=0.5,b=1}, [12]={r=0.71,g=1,b=0.92}, [13]={r=0.4,g=0,b=0.8}, [16]={r=0.1,g=0.1,b=0.98}, [17]={r=0.79,g=0.26,b=0.99}, [18]={r=1,g=0.61,b=0}, [19]={r=0.4,g=0.8,b=1} }
local TERTIARY_COLORS = { shaman_apps={r=0,g=0.5,b=1}, hunter_apps={r=0.6,g=0.8,b=0.2}, warrior_apps={r=0.8,g=0.1,b=0.1}, stagger_green={r=0,g=1,b=0.5}, stagger_yellow={r=1,g=1,b=0}, stagger_red={r=1,g=0,b=0}, evoker_dur={r=0.8,g=0.6,b=0.1}, dh_vengeance={r=0.6,g=0.2,b=0.8}, mage_icicles={r=0.4,g=0.8,b=1}, mage_charges={r=1,g=0.5,b=0} }
local PLAYER_CLASS_COLOR = DEFAULT_COLOR
local cc_cache = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass]
if cc_cache then PLAYER_CLASS_COLOR = {r=cc_cache.r, g=cc_cache.g, b=cc_cache.b} end

local function IsSecret(v)
    return type(v) == "number" and issecretvalue and issecretvalue(v)
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
    if not db.power or not db.class or not db.tertiary or not db.mana then
        DeepMerge(db, defaults)
    end
    
    return db
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

local function GetCurrentSpecConfig(ctxId)
    local db = GetDB()
    ctxId = ctxId or GetCurrentContextID()
    if not db.specConfigs then db.specConfigs = {} end
    if type(db.specConfigs[ctxId]) ~= "table" then db.specConfigs[ctxId] = {} end
    local cfg = db.specConfigs[ctxId]
    if cfg.showPower == nil then cfg.showPower = true end
    if cfg.showClass == nil then cfg.showClass = true end
    if cfg.showTertiary == nil then cfg.showTertiary = true end
    if cfg.showMana == nil then cfg.showMana = false end
    if cfg.textPower == nil then cfg.textPower = true end
    if cfg.textClass == nil then cfg.textClass = true end
    if cfg.textTertiary == nil then cfg.textTertiary = true end
    if cfg.textMana == nil then cfg.textMana = true end
    return cfg
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

local function GetTargetWidth()
    local db = GetDB()
    if db.alignWithCD and E.db.WishFlex.cdManager and E.db.WishFlex.cdManager.Essential then
        local cdDB = E.db.WishFlex.cdManager.Essential
        local maxPerRow = tonumber(cdDB.maxPerRow) or 7
        local w = tonumber(cdDB.row1Width) or tonumber(cdDB.width) or 45
        local gap = tonumber(cdDB.iconGap) or 2
        return (maxPerRow * w) + ((maxPerRow - 1) * gap) + (tonumber(db.widthOffset) or 2)
    end
    return tonumber(db.width) or 250
end

local function GetPowerColor(pType) return POWER_COLORS[pType] or DEFAULT_COLOR end

local function GetClassResourceData()
    local spec = GetSpecializationInfo(GetSpecialization() or 1)
    local pType = UnitPowerType("player")
    local classColor = PLAYER_CLASS_COLOR
    
    if playerClass == "ROGUE" then return UnitPower("player", 4), UnitPowerMax("player", 4), classColor, true
    elseif playerClass == "PALADIN" then return UnitPower("player", 9), 5, classColor, true
    elseif playerClass == "WARLOCK" then return UnitPower("player", 7), 5, classColor, true
    elseif playerClass == "MAGE" and spec == 62 then return UnitPower("player", 16), 4, classColor, true
    elseif playerClass == "MONK" and spec == 269 then return UnitPower("player", 12), UnitPowerMax("player", 12), classColor, true
    elseif playerClass == "EVOKER" then return UnitPower("player", 19), 6, classColor, true
    elseif playerClass == "DEATHKNIGHT" then return UnitPower("player", 5), 6, classColor, true
    elseif playerClass == "DRUID" and pType == 3 then return UnitPower("player", 4), 5, classColor, true
    elseif playerClass == "SHAMAN" and spec == 263 then
        local apps = 0
        if C_UnitAuras.GetPlayerAuraBySpellID then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(344179)
            if aura then apps = aura.applications or 1 end
        end
        return apps, 10, classColor, true
    elseif playerClass == "HUNTER" and spec == 255 then
        local apps = 0
        if C_UnitAuras.GetPlayerAuraBySpellID then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(260286)
            if aura then apps = aura.applications or 1 end
        end
        return apps, 3, classColor, true
    elseif playerClass == "WARRIOR" and spec == 72 then
        local apps = 0
        if C_UnitAuras.GetPlayerAuraBySpellID then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(85739) or C_UnitAuras.GetPlayerAuraBySpellID(322166)
            if aura then apps = aura.applications or 1 end
        end
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
    
    local exactCur = rawCur
    local resolved = true
    
    if IsSecret(rawCur) then
        if not CR.sharedArcDecoder then
            CR.sharedArcDecoder = CreateFrame("Frame", "WishFlex_ArcDecoder", UIParent)
            CR.sharedArcDecoder:SetSize(1, 1)
            CR.sharedArcDecoder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
            CR.sharedArcDecoder:SetAlpha(0)
            CR.sharedArcDecoder:Show()
            CR.arcDetectors = {}
        end
        
        local lastFeed = CR.arcFeedFrame or 0
        if lastFeed == CR.frameTick then
            exactCur = CR.arcResolved or 0
        elseif lastFeed > 0 then
            local count = 0
            for i = 1, maxC do
                if CR.arcDetectors[i] and CR.arcDetectors[i]:GetStatusBarTexture():IsShown() then
                    count = i
                end
            end
            exactCur = count
        else
            resolved = false
            exactCur = 0
        end
        
        for i = 1, maxC do
            if not CR.arcDetectors[i] then
                local det = CreateFrame("StatusBar", nil, CR.sharedArcDecoder)
                det:SetSize(1, 1)
                det:SetPoint("BOTTOMLEFT", CR.sharedArcDecoder, "BOTTOMLEFT", 0, 0)
                det:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
                CR.arcDetectors[i] = det
            end
            CR.arcDetectors[i]:SetMinMaxValues(i - 1, i)
            CR.arcDetectors[i]:SetValue(rawCur)
        end
        
        CR.arcFeedFrame = CR.frameTick
        if resolved then CR.arcResolved = exactCur end
    end
    
    if not resolved then
        return rawCur, maxC, color, false, maxC, true, rawCur, nil
    end
    
    local durObj = nil
    if exactCur < maxC then
        durObj = C_Spell.GetSpellChargeDuration(spellID)
    end
    
    return exactCur, maxC, color, false, maxC, true, exactCur, durObj
end

local function GetTertiaryResourceData()
    local spec = GetSpecializationInfo(GetSpecialization() or 1)
    
    if playerClass == "MONK" and spec == 268 then
        local stagger = UnitStagger("player") or 0
        local maxHealth = UnitHealthMax("player") or 1
        
        local show = false
        local color = TERTIARY_COLORS.stagger_green
        
        if IsSecret(stagger) or IsSecret(maxHealth) then
            show = true
        else
            if stagger > 0 and maxHealth > 0 then
                show = true
                local p = stagger / maxHealth
                if p > 0.6 then color = TERTIARY_COLORS.stagger_red
                elseif p > 0.3 then color = TERTIARY_COLORS.stagger_yellow end
            end
        end
        return stagger, maxHealth, color, false, 1, show
        
    elseif playerClass == "EVOKER" and spec == 1473 then
        local remain, dur, show = 0, 10, false
        if C_UnitAuras.GetPlayerAuraBySpellID then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(395296)
            if aura and aura.expirationTime then
                if IsSecret(aura.expirationTime) then
                    show = true
                    remain = aura.expirationTime
                    dur = aura.duration or 10
                else
                    remain = aura.expirationTime - GetTime()
                    if remain > 0 then
                        show = true
                        dur = (aura.duration and aura.duration > 0) and aura.duration or 10
                    else
                        remain = 0
                    end
                end
            end
        end
        return remain, dur, TERTIARY_COLORS.evoker_dur, true, 1, show
        
    elseif playerClass == "SHAMAN" and spec == 262 then
        local mana = UnitPower("player", 0)
        local maxMana = UnitPowerMax("player", 0)
        local show = IsSecret(maxMana) or (maxMana > 0)
        return mana, maxMana, GetPowerColor(0), false, 1, show
        
    elseif playerClass == "DEMONHUNTER" then
        if spec == 581 then 
            local count = C_Spell.GetSpellCastCount(228477) or 0
            return count, 6, TERTIARY_COLORS.dh_vengeance, false, 6, true
        end
        
    elseif playerClass == "MAGE" then
        if spec == 64 then 
            local icicles = 0
            if C_UnitAuras.GetPlayerAuraBySpellID then
                local aura = C_UnitAuras.GetPlayerAuraBySpellID(205473) or C_UnitAuras.GetPlayerAuraBySpellID(112214)
                if aura then icicles = aura.applications or 1 end
            end
            return icicles, 5, TERTIARY_COLORS.mage_icicles, false, 5, true
        elseif spec == 63 then
            return GetChargeData(108853, 3, TERTIARY_COLORS.mage_charges)
        end
    end
    return 0, 0, DEFAULT_COLOR, false, 1, false
end

local function GetSelectedSpec()
    return CR.selectedSpecForConfig or GetCurrentContextID()
end

local function InjectOptions()
    local function GetOptionsList()
        local opts = {}
        if playerClass == "DRUID" then
            opts[1000] = "人形态 / 无形态"
            opts[1001] = "猎豹形态"
            opts[1002] = "熊形态"
            opts[1003] = "枭兽形态"
            opts[1004] = "旅行形态"
        else
            local classID = select(3, UnitClass("player"))
            for i = 1, GetNumSpecializationsForClassID(classID) do
                local id, name = GetSpecializationInfoForClassID(classID, i)
                if id and name then opts[id] = name end
            end
            opts[0] = "无专精 / 通用"
        end
        return opts
    end

    if not CR.selectedSpecForConfig then CR.selectedSpecForConfig = GetCurrentContextID() end

    WF.OptionsArgs = WF.OptionsArgs or {}
    WF.OptionsArgs.classResource = {
        order = 15, type = "group", name = "|cff00ffcc职业资源条|r", childGroups = "tab",
        get = function(i) return GetDB()[i[#i]] end,
        set = function(i, v) GetDB()[i[#i]] = v; CR:UpdateLayout() end,
        args = {
            general = {
                order = 1, type = "group", name = "全局排版",
                args = {
                    desc = { order = 1, type = "description", name = "全自动识别当前专精与形态，自动切换法力、连击点、符文、火冲、冰刺等！\n" },
                    enable = { order = 2, type = "toggle", name = "启用模块", get = function() return E.db.WishFlex.modules.classResource end, set = function(_, v) E.db.WishFlex.modules.classResource = v; E:StaticPopup_Show("CONFIG_RL") end },
                    spacer = { order = 3, type = "description", name = " " },
                    alignWithCD = { order = 4, type = "toggle", name = "实时对齐冷却管理器", desc = "开启后，资源条会与冷却管理器第一行实时绑定，宽度随之变化。" },
                    alignYOffset = { order = 4.1, type = "range", name = "对齐Y轴间距", min = -50, max = 50, step = 1, disabled = function() return not GetDB().alignWithCD end },
                    hideElvUIBars = { 
                        order = 4.5, type = "toggle", name = "隐藏原生能量/资源条", 
                        desc = "在此处勾选，将一次性帮你关闭 ElvUI 玩家框体的原生能量条与资源条，以防止重复显示。如果想恢复，关闭此选项后，去 ElvUI 玩家框体设置里重新开启即可。",
                        get = function() return GetDB().hideElvUIBars end,
                        set = function(_, v)
                            GetDB().hideElvUIBars = v
                            if v then
                                E.db.unitframe.units.player.power.enable = false
                                E.db.unitframe.units.player.classbar.enable = false
                                if UF then UF:CreateAndUpdateUF('player') end
                            end
                            CR:UpdateLayout()
                        end
                    },
                    widthOffset = { order = 5, type = "range", name = "边框补偿", min = -10, max = 10, step = 1, disabled = function() return not GetDB().alignWithCD end },
                    width = { order = 6, type = "range", name = "自定义宽度", min = 50, max = 600, step = 1, disabled = function() return GetDB().alignWithCD end },
                    yOffset = { order = 7, type = "range", name = "条与条间距", min = 0, max = 50, step = 1 },
                    texture = { order = 8, type = "select", dialogControl = 'LSM30_Statusbar', name = "全局材质", values = LSM:HashTable("statusbar") },
                }
            },
            specVisibilityTab = {
                order = 2, type = "group", name = "|cff00ff00" .. (playerClass == "DRUID" and "各形态显隐" or "各专精显隐") .. "|r",
                args = {
                    selectSpec = {
                        order = 2, type = "select", name = "当前配置环境",
                        values = GetOptionsList,
                        get = function() return CR.selectedSpecForConfig end,
                        set = function(_, val) CR.selectedSpecForConfig = val; CR:UpdateLayout() end,
                    },
                    spacer = { order = 3, type = "description", name = " \n" },
                    
                    powerHeader = { order = 4, type = "header", name = "能量条 [法力/怒气/能量]" },
                    showPower = { order = 5, type = "toggle", name = "显示进度条", get = function() return GetCurrentSpecConfig(GetSelectedSpec()).showPower end, set = function(_, val) GetCurrentSpecConfig(GetSelectedSpec()).showPower = val; CR:UpdateLayout() end },
                    textPower = { order = 6, type = "toggle", name = "显示条内文本", get = function() return GetCurrentSpecConfig(GetSelectedSpec()).textPower end, set = function(_, val) GetCurrentSpecConfig(GetSelectedSpec()).textPower = val; CR:UpdateLayout() end },
                    
                    classHeader = { order = 7, type = "header", name = "主资源条 [连击点/圣能/符文]" },
                    showClass = { order = 8, type = "toggle", name = "显示进度条", get = function() return GetCurrentSpecConfig(GetSelectedSpec()).showClass end, set = function(_, val) GetCurrentSpecConfig(GetSelectedSpec()).showClass = val; CR:UpdateLayout() end },
                    textClass = { order = 9, type = "toggle", name = "显示条内文本", get = function() return GetCurrentSpecConfig(GetSelectedSpec()).textClass end, set = function(_, val) GetCurrentSpecConfig(GetSelectedSpec()).textClass = val; CR:UpdateLayout() end },
                    
                    tertiaryHeader = { order = 10, type = "header", name = "副资源条 [火冲/冰刺/酒池]" },
                    showTertiary = { order = 11, type = "toggle", name = "显示进度条", get = function() return GetCurrentSpecConfig(GetSelectedSpec()).showTertiary end, set = function(_, val) GetCurrentSpecConfig(GetSelectedSpec()).showTertiary = val; CR:UpdateLayout() end },
                    textTertiary = { order = 12, type = "toggle", name = "显示条内文本", get = function() return GetCurrentSpecConfig(GetSelectedSpec()).textTertiary end, set = function(_, val) GetCurrentSpecConfig(GetSelectedSpec()).textTertiary = val; CR:UpdateLayout() end },
                    
                    manaHeader = { order = 13, type = "header", name = "混合职业专属：额外法力值条", hidden = function() return not hasHealerSpec end },
                    showMana = { order = 14, type = "toggle", name = "显示额外法力条", hidden = function() return not hasHealerSpec end, get = function() return GetCurrentSpecConfig(GetSelectedSpec()).showMana end, set = function(_, val) GetCurrentSpecConfig(GetSelectedSpec()).showMana = val; CR:UpdateLayout() end },
                    textMana = { order = 15, type = "toggle", name = "显示条内文本", hidden = function() return not hasHealerSpec end, get = function() return GetCurrentSpecConfig(GetSelectedSpec()).textMana end, set = function(_, val) GetCurrentSpecConfig(GetSelectedSpec()).textMana = val; CR:UpdateLayout() end },
                }
            },
            powerTab = {
                order = 3, type = "group", 
                name = function() return GetCurrentSpecConfig(GetSelectedSpec()).showPower and "能量条" or "|cff888888能量条(已停用)|r" end,
                disabled = function() return not GetCurrentSpecConfig(GetSelectedSpec()).showPower end,
                get = function(i) return GetDB().power[i[#i]] end,
                set = function(i, v) GetDB().power[i[#i]] = v; CR:UpdateLayout() end,
                args = {
                    barGroup = {
                        order = 1, type = "group", name = "基础设置", guiInline = true,
                        args = {
                            enable = { order = 1, type = "toggle", name = "启用" },
                            height = { order = 2, type = "range", name = "高度", min = 2, max = 50, step = 1 },
                            useCustomColor = { order = 3, type = "toggle", name = "自定义前景色" },
                            customColor = { order = 4, type = "color", name = "前景色", disabled = function() return not GetDB().power.useCustomColor end, get = function() local t = GetDB().power.customColor return t.r, t.g, t.b end, set = function(_, r, g, b) GetDB().power.customColor = {r=r,g=g,b=b}; CR:UpdateLayout() end },
                            useCustomTexture = { order = 5, type = "toggle", name = "独立前景材质" },
                            texture = { order = 6, type = "select", dialogControl = 'LSM30_Statusbar', name = "前景材质", disabled = function() return not GetDB().power.useCustomTexture end, values = LSM:HashTable("statusbar") },
                            useCustomBgTexture = { order = 7, type = "toggle", name = "独立背景材质" },
                            bgTexture = { order = 8, type = "select", dialogControl = 'LSM30_Statusbar', name = "背景材质", disabled = function() return not GetDB().power.useCustomBgTexture end, values = LSM:HashTable("statusbar") },
                            bgColor = { order = 9, type = "color", name = "背景颜色", hasAlpha = true, get = function() local t = GetDB().power.bgColor or {r=0,g=0,b=0,a=0.5} return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) GetDB().power.bgColor = {r=r,g=g,b=b,a=a}; CR:UpdateLayout() end },
                        }
                    },
                    fontGroup = {
                        order = 2, type = "group", name = "字体样式 (全局影响)", guiInline = true,
                        args = {
                            font = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") },
                            fontSize = { order = 2, type = "range", name = "大小", min = 8, max = 40, step = 1 },
                            outline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } },
                            color = { order = 4, type = "color", name = "颜色", get = function() local t = GetDB().power.color return t.r, t.g, t.b end, set = function(_, r, g, b) GetDB().power.color = {r=r,g=g,b=b}; CR:UpdateLayout() end },
                        }
                    },
                    layoutGroup = {
                        order = 3, type = "group", name = "主文本排版", guiInline = true,
                        args = {
                            textEnable = { order = 1, type = "toggle", name = "显示主文本" },
                            textFormat = { order = 2, type = "select", name = "文本格式", values = { ["AUTO"] = "自动(法力% / 其他数值)", ["PERCENT"] = "百分比", ["ABSOLUTE"] = "具体数值", ["BOTH"] = "数值 / 最大值", ["NONE"] = "隐藏" } },
                            textAnchor = { order = 3, type = "select", name = "对齐方向", values = { ["LEFT"] = "左对齐", ["CENTER"] = "居中对齐", ["RIGHT"] = "右对齐" } },
                            xOffset = { order = 4, type = "range", name = "X 偏移", min = -200, max = 200, step = 1 },
                            yOffset = { order = 5, type = "range", name = "Y 偏移", min = -100, max = 100, step = 1 },
                        }
                    },
                    timerGroup = {
                        order = 4, type = "group", name = "倒计时排版 (如适用)", guiInline = true,
                        args = {
                            timerEnable = { order = 1, type = "toggle", name = "显示倒计时" },
                            timerAnchor = { order = 2, type = "select", name = "对齐方向", values = { ["LEFT"] = "左对齐", ["CENTER"] = "居中对齐", ["RIGHT"] = "右对齐" } },
                            timerXOffset = { order = 3, type = "range", name = "X 偏移", min = -200, max = 200, step = 1 },
                            timerYOffset = { order = 4, type = "range", name = "Y 偏移", min = -100, max = 100, step = 1 },
                        }
                    }
                }
            },
            classTab = {
                order = 4, type = "group", 
                name = function() return GetCurrentSpecConfig(GetSelectedSpec()).showClass and "主资源条" or "|cff888888主资源条(已停用)|r" end,
                disabled = function() return not GetCurrentSpecConfig(GetSelectedSpec()).showClass end,
                get = function(i) return GetDB().class[i[#i]] end,
                set = function(i, v) GetDB().class[i[#i]] = v; CR:UpdateLayout() end,
                args = {
                    barGroup = {
                        order = 1, type = "group", name = "基础设置", guiInline = true,
                        args = {
                            enable = { order = 1, type = "toggle", name = "启用" },
                            height = { order = 2, type = "range", name = "高度", min = 2, max = 50, step = 1 },
                            useCustomColor = { 
                                order = 3, type = "toggle", name = "独立自定义颜色", 
                                desc = "开启后，主资源条的自定义颜色将仅对【当前登录的职业】生效，切换其他职业时互不干扰。",
                                get = function() 
                                    local db = GetDB().class
                                    if type(db.useCustomColors) ~= "table" then db.useCustomColors = {} end
                                    return db.useCustomColors[playerClass] or false 
                                end, 
                                set = function(_, v) 
                                    local db = GetDB().class
                                    if type(db.useCustomColors) ~= "table" then db.useCustomColors = {} end
                                    db.useCustomColors[playerClass] = v
                                    CR:UpdateLayout() 
                                end 
                            },
                            customColor = { 
                                order = 4, type = "color", name = "前景色", 
                                disabled = function() 
                                    local db = GetDB().class
                                    return not (type(db.useCustomColors) == "table" and db.useCustomColors[playerClass]) 
                                end, 
                                get = function() 
                                    local db = GetDB().class
                                    if type(db.customColors) ~= "table" then db.customColors = {} end
                                    local t = db.customColors[playerClass]
                                    if not t then 
                                        local cc = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass]
                                        t = cc and {r=cc.r, g=cc.g, b=cc.b} or {r=1, g=1, b=1}
                                    end
                                    return t.r, t.g, t.b 
                                end, 
                                set = function(_, r, g, b) 
                                    local db = GetDB().class
                                    if type(db.customColors) ~= "table" then db.customColors = {} end
                                    db.customColors[playerClass] = {r=r,g=g,b=b}
                                    CR:UpdateLayout() 
                                end 
                            },
                            useCustomTexture = { order = 5, type = "toggle", name = "独立前景材质" },
                            texture = { order = 6, type = "select", dialogControl = 'LSM30_Statusbar', name = "前景材质", disabled = function() return not GetDB().class.useCustomTexture end, values = LSM:HashTable("statusbar") },
                            useCustomBgTexture = { order = 7, type = "toggle", name = "独立背景材质" },
                            bgTexture = { order = 8, type = "select", dialogControl = 'LSM30_Statusbar', name = "背景材质", disabled = function() return not GetDB().class.useCustomBgTexture end, values = LSM:HashTable("statusbar") },
                            bgColor = { order = 9, type = "color", name = "背景颜色", hasAlpha = true, get = function() local t = GetDB().class.bgColor or {r=0,g=0,b=0,a=0.5} return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) GetDB().class.bgColor = {r=r,g=g,b=b,a=a}; CR:UpdateLayout() end },
                        }
                    },
                    fontGroup = {
                        order = 2, type = "group", name = "字体样式 (全局影响)", guiInline = true,
                        args = {
                            font = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") },
                            fontSize = { order = 2, type = "range", name = "大小", min = 8, max = 40, step = 1 },
                            outline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } },
                            color = { order = 4, type = "color", name = "颜色", get = function() local t = GetDB().class.color return t.r, t.g, t.b end, set = function(_, r, g, b) GetDB().class.color = {r=r,g=g,b=b}; CR:UpdateLayout() end },
                        }
                    },
                    layoutGroup = {
                        order = 3, type = "group", name = "主文本排版", guiInline = true,
                        args = {
                            textEnable = { order = 1, type = "toggle", name = "显示主文本" },
                            textFormat = { order = 2, type = "select", name = "文本格式", values = { ["AUTO"] = "自动(法力% / 其他数值)", ["PERCENT"] = "百分比", ["ABSOLUTE"] = "具体数值", ["BOTH"] = "数值 / 最大值", ["NONE"] = "隐藏" } },
                            textAnchor = { order = 3, type = "select", name = "对齐方向", values = { ["LEFT"] = "左对齐", ["CENTER"] = "居中对齐", ["RIGHT"] = "右对齐" } },
                            xOffset = { order = 4, type = "range", name = "X 偏移", min = -200, max = 200, step = 1 },
                            yOffset = { order = 5, type = "range", name = "Y 偏移", min = -100, max = 100, step = 1 },
                        }
                    },
                    timerGroup = {
                        order = 4, type = "group", name = "倒计时排版 (如适用)", guiInline = true,
                        args = {
                            timerEnable = { order = 1, type = "toggle", name = "显示倒计时" },
                            timerAnchor = { order = 2, type = "select", name = "对齐方向", values = { ["LEFT"] = "左对齐", ["CENTER"] = "居中对齐", ["RIGHT"] = "右对齐" } },
                            timerXOffset = { order = 3, type = "range", name = "X 偏移", min = -200, max = 200, step = 1 },
                            timerYOffset = { order = 4, type = "range", name = "Y 偏移", min = -100, max = 100, step = 1 },
                        }
                    }
                }
            },
            tertiaryTab = {
                order = 5, type = "group", 
                name = function() return GetCurrentSpecConfig(GetSelectedSpec()).showTertiary and "副资源条" or "|cff888888副资源条(已停用)|r" end,
                disabled = function() return not GetCurrentSpecConfig(GetSelectedSpec()).showTertiary end,
                get = function(i) return GetDB().tertiary[i[#i]] end,
                set = function(i, v) GetDB().tertiary[i[#i]] = v; CR:UpdateLayout() end,
                args = {
                    barGroup = {
                        order = 1, type = "group", name = "基础设置", guiInline = true,
                        args = {
                            enable = { order = 1, type = "toggle", name = "启用" },
                            height = { order = 2, type = "range", name = "高度", min = 2, max = 50, step = 1 },
                            useCustomColor = { order = 3, type = "toggle", name = "自定义前景色" },
                            customColor = { order = 4, type = "color", name = "前景色", disabled = function() return not GetDB().tertiary.useCustomColor end, get = function() local t = GetDB().tertiary.customColor return t.r, t.g, t.b end, set = function(_, r, g, b) GetDB().tertiary.customColor = {r=r,g=g,b=b}; CR:UpdateLayout() end },
                            useCustomTexture = { order = 5, type = "toggle", name = "独立前景材质" },
                            texture = { order = 6, type = "select", dialogControl = 'LSM30_Statusbar', name = "前景材质", disabled = function() return not GetDB().tertiary.useCustomTexture end, values = LSM:HashTable("statusbar") },
                            useCustomBgTexture = { order = 7, type = "toggle", name = "独立背景材质" },
                            bgTexture = { order = 8, type = "select", dialogControl = 'LSM30_Statusbar', name = "背景材质", disabled = function() return not GetDB().tertiary.useCustomBgTexture end, values = LSM:HashTable("statusbar") },
                            bgColor = { order = 9, type = "color", name = "背景颜色", hasAlpha = true, get = function() local t = GetDB().tertiary.bgColor or {r=0,g=0,b=0,a=0.5} return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) GetDB().tertiary.bgColor = {r=r,g=g,b=b,a=a}; CR:UpdateLayout() end },
                            useCustomRechargeColor = { order = 10, type = "toggle", name = "自定义充能动画颜色", desc = "如：法师火冲缓慢上涨的充能层数颜色" },
                            rechargeColor = { order = 11, type = "color", name = "充能动画颜色", hasAlpha = true, disabled = function() return not GetDB().tertiary.useCustomRechargeColor end, get = function() local t = GetDB().tertiary.rechargeColor or {r=1,g=1,b=1,a=0.75} return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) GetDB().tertiary.rechargeColor = {r=r,g=g,b=b,a=a}; CR:UpdateLayout() end },
                        }
                    },
                    fontGroup = {
                        order = 2, type = "group", name = "字体样式 (全局影响)", guiInline = true,
                        args = {
                            font = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") },
                            fontSize = { order = 2, type = "range", name = "大小", min = 8, max = 40, step = 1 },
                            outline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } },
                            color = { order = 4, type = "color", name = "颜色", get = function() local t = GetDB().tertiary.color return t.r, t.g, t.b end, set = function(_, r, g, b) GetDB().tertiary.color = {r=r,g=g,b=b}; CR:UpdateLayout() end },
                        }
                    },
                    layoutGroup = {
                        order = 3, type = "group", name = "主文本排版 (如:层数)", guiInline = true,
                        args = {
                            textEnable = { order = 1, type = "toggle", name = "显示主文本" },
                            textFormat = { order = 2, type = "select", name = "文本格式", values = { ["AUTO"] = "自动(法力% / 其他数值)", ["PERCENT"] = "百分比", ["ABSOLUTE"] = "具体数值", ["BOTH"] = "数值 / 最大值", ["NONE"] = "隐藏" } },
                            textAnchor = { order = 3, type = "select", name = "对齐方向", values = { ["LEFT"] = "左对齐", ["CENTER"] = "居中对齐", ["RIGHT"] = "右对齐" } },
                            xOffset = { order = 4, type = "range", name = "X 偏移", min = -200, max = 200, step = 1 },
                            yOffset = { order = 5, type = "range", name = "Y 偏移", min = -100, max = 100, step = 1 },
                        }
                    },
                    timerGroup = {
                        order = 4, type = "group", name = "充能倒计时排版", guiInline = true,
                        args = {
                            timerEnable = { order = 1, type = "toggle", name = "显示倒计时" },
                            timerAnchor = { order = 2, type = "select", name = "对齐方向", values = { ["LEFT"] = "左对齐", ["CENTER"] = "居中对齐", ["RIGHT"] = "右对齐" } },
                            timerXOffset = { order = 3, type = "range", name = "X 偏移", min = -200, max = 200, step = 1 },
                            timerYOffset = { order = 4, type = "range", name = "Y 偏移", min = -100, max = 100, step = 1 },
                        }
                    }
                }
            },
            manaTab = {
                order = 6, type = "group", 
                name = function() return GetCurrentSpecConfig(GetSelectedSpec()).showMana and "专属法力条" or "|cff888888专属法力条(已停用)|r" end,
                hidden = function() return not hasHealerSpec end,
                disabled = function() return not GetCurrentSpecConfig(GetSelectedSpec()).showMana end,
                get = function(i) return GetDB().mana[i[#i]] end,
                set = function(i, v) GetDB().mana[i[#i]] = v; CR:UpdateLayout() end,
                args = {
                    barGroup = {
                        order = 1, type = "group", name = "基础设置", guiInline = true,
                        args = {
                            desc = { order = 1, type = "description", name = "注意：法力值将强制使用百分比显示。\n|cff00ff00此条拥有独立的锚点，可单独解锁移动！|r\n" },
                            enable = { order = 2, type = "toggle", name = "全局启用开关" },
                            height = { order = 3, type = "range", name = "高度", min = 2, max = 50, step = 1 },
                            barXOffset = { order = 4, type = "range", name = "独立 X 偏移", min = -500, max = 500, step = 1 },
                            barYOffset = { order = 5, type = "range", name = "独立 Y 偏移", min = -500, max = 500, step = 1 },
                            useCustomColor = { order = 6, type = "toggle", name = "自定义前景色" },
                            customColor = { order = 7, type = "color", name = "前景色", disabled = function() return not GetDB().mana.useCustomColor end, get = function() local t = GetDB().mana.customColor return t.r, t.g, t.b end, set = function(_, r, g, b) GetDB().mana.customColor = {r=r,g=g,b=b}; CR:UpdateLayout() end },
                            useCustomTexture = { order = 8, type = "toggle", name = "独立前景材质" },
                            texture = { order = 9, type = "select", dialogControl = 'LSM30_Statusbar', name = "前景材质", disabled = function() return not GetDB().mana.useCustomTexture end, values = LSM:HashTable("statusbar") },
                            useCustomBgTexture = { order = 10, type = "toggle", name = "独立背景材质" },
                            bgTexture = { order = 11, type = "select", dialogControl = 'LSM30_Statusbar', name = "背景材质", disabled = function() return not GetDB().mana.useCustomBgTexture end, values = LSM:HashTable("statusbar") },
                            bgColor = { order = 12, type = "color", name = "背景颜色", hasAlpha = true, get = function() local t = GetDB().mana.bgColor or {r=0,g=0,b=0,a=0.5} return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) GetDB().mana.bgColor = {r=r,g=g,b=b,a=a}; CR:UpdateLayout() end },
                        }
                    },
                    fontGroup = {
                        order = 2, type = "group", name = "字体样式 (全局影响)", guiInline = true,
                        args = {
                            font = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") },
                            fontSize = { order = 2, type = "range", name = "大小", min = 8, max = 40, step = 1 },
                            outline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } },
                            color = { order = 4, type = "color", name = "颜色", get = function() local t = GetDB().mana.color return t.r, t.g, t.b end, set = function(_, r, g, b) GetDB().mana.color = {r=r,g=g,b=b}; CR:UpdateLayout() end },
                        }
                    },
                    layoutGroup = {
                        order = 3, type = "group", name = "主文本排版", guiInline = true,
                        args = {
                            textEnable = { order = 1, type = "toggle", name = "显示主文本" },
                            textFormat = { order = 2, type = "select", name = "文本格式", values = { ["AUTO"] = "自动(法力% / 其他数值)", ["PERCENT"] = "百分比", ["ABSOLUTE"] = "具体数值", ["BOTH"] = "数值 / 最大值", ["NONE"] = "隐藏" } },
                            textAnchor = { order = 3, type = "select", name = "对齐方向", values = { ["LEFT"] = "左对齐", ["CENTER"] = "居中对齐", ["RIGHT"] = "右对齐" } },
                            xOffset = { order = 4, type = "range", name = "X 偏移", min = -200, max = 200, step = 1 },
                            yOffset = { order = 5, type = "range", name = "Y 偏移", min = -100, max = 100, step = 1 },
                        }
                    },
                    timerGroup = {
                        order = 4, type = "group", name = "倒计时排版 (如适用)", guiInline = true,
                        args = {
                            timerEnable = { order = 1, type = "toggle", name = "显示倒计时" },
                            timerAnchor = { order = 2, type = "select", name = "对齐方向", values = { ["LEFT"] = "左对齐", ["CENTER"] = "居中对齐", ["RIGHT"] = "右对齐" } },
                            timerXOffset = { order = 3, type = "range", name = "X 偏移", min = -200, max = 200, step = 1 },
                            timerYOffset = { order = 4, type = "range", name = "Y 偏移", min = -100, max = 100, step = 1 },
                        }
                    }
                }
            }
        }
    }
end

function CR:UpdateDividers(bar, maxVal)
    bar.dividers = bar.dividers or {}
    
    local numMax
    if IsSecret(maxVal) then
        numMax = 1
    else
        numMax = tonumber(maxVal) or 1
        if numMax <= 0 then numMax = 1 end
        if numMax > 20 then numMax = 20 end 
    end

    local width = bar:GetWidth() or 250
    if bar._lastDividerMax == numMax and bar._lastDividerWidth == width then return end
    bar._lastDividerMax = numMax
    bar._lastDividerWidth = width

    local numDividers = numMax > 1 and (numMax - 1) or 0
    local segWidth = width / numMax

    for i = 1, numDividers do
        if not bar.dividers[i] then
            local tex = bar.textFrame:CreateTexture(nil, "OVERLAY", nil, 7)
            tex:SetColorTexture(0, 0, 0, 1) 
            tex:SetWidth(1)                 
            bar.dividers[i] = tex
        end
        bar.dividers[i]:ClearAllPoints()
        bar.dividers[i]:SetPoint("TOPLEFT", bar.textFrame, "TOPLEFT", segWidth * i, 0)
        bar.dividers[i]:SetPoint("BOTTOMLEFT", bar.textFrame, "BOTTOMLEFT", segWidth * i, 0)
        bar.dividers[i]:Show()
    end
    for i = numDividers + 1, #bar.dividers do if bar.dividers[i] then bar.dividers[i]:Hide() end end
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

    bar.text:ClearAllPoints()
    bar.text:SetPoint(mainAnchor, bar.textFrame, mainAnchor, tonumber(textCfg.xOffset) or 0, tonumber(textCfg.yOffset) or 0)
    bar.text:SetJustifyH(mainAnchor)
    
    bar.timerText:ClearAllPoints()
    bar.timerText:SetPoint(timerAnchor, bar.textFrame, timerAnchor, tonumber(textCfg.timerXOffset) or 0, tonumber(textCfg.timerYOffset) or 0)
    bar.timerText:SetJustifyH(timerAnchor)

    if durObj and type(current) == "number" then
        local remain = durObj:GetRemainingDuration()
        if remain then
            if showMain then
                bar.text:SetFormattedText("%d", current)
                bar.text:Show()
            else
                bar.text:Hide()
            end
            
            if showTimer then
                bar.timerText:SetFormattedText("%.1f", remain)
                bar.timerText:Show()
            else
                bar.timerText:Hide()
            end
            return
        end
    end

    bar.timerText:Hide()
    
    if not showMain then 
        bar.text:Hide()
        return 
    end
    bar.text:Show()

    local function SafeFormatNum(v)
        local num = tonumber(v) or 0
        if num >= 1e6 then return string.format("%.1fm", num / 1e6)
        elseif num >= 1e4 then return string.format("%.1fk", num / 1e3)
        else return string.format("%.0f", num) end
    end

    local formatMode = textCfg.textFormat
    if formatMode == "AUTO" then
        if pType == 0 then formatMode = "PERCENT" else formatMode = "ABSOLUTE" end
    end

    if isTime then
        if IsSecret(current) then bar.text:SetFormattedText("%.1f", current)
        else bar.text:SetFormattedText("%.1f", tonumber(current) or 0) end
    elseif pType == 0 and formatMode == "PERCENT" then
        local scale = (_G.CurveConstants and _G.CurveConstants.ScaleTo100) or 100
        local perc = UnitPowerPercent("player", pType, false, scale)
        if IsSecret(perc) then bar.text:SetFormattedText("%d", perc)
        else bar.text:SetFormattedText("%d", tonumber(perc) or 0) end
    elseif formatMode == "PERCENT" then
        if pType then
            local perc = UnitPowerPercent("player", pType, false)
            if IsSecret(perc) then bar.text:SetFormattedText("%d", perc)
            else bar.text:SetFormattedText("%d", tonumber(perc) or 0) end
        else
            if IsSecret(current) or IsSecret(maxVal) then
                bar.text:SetFormattedText("%d", current)
            else
                local cVal = tonumber(current) or 0
                local mVal = tonumber(maxVal) or 1
                if mVal <= 0 then mVal = 1 end
                local pct = math.floor((cVal / mVal) * 100 + 0.5)
                bar.text:SetFormattedText("%d", pct)
            end
        end
    elseif formatMode == "BOTH" then
        if IsSecret(current) or IsSecret(maxVal) then
            bar.text:SetFormattedText("%d / %d", current, maxVal)
        else
            bar.text:SetText(SafeFormatNum(current) .. " / " .. SafeFormatNum(maxVal))
        end
    else
        if IsSecret(current) then bar.text:SetFormattedText("%d", current)
        else bar.text:SetText(SafeFormatNum(current)) end
    end
end

function CR:UpdateLayout()
    self:WakeUp()
    if not self.anchor then return end
    local db = GetDB()
    local currentContextID = GetCurrentContextID()
    local specCfg = GetCurrentSpecConfig(currentContextID)
    self.cachedSpecCfg = specCfg

    local globalTexName = db.texture
    local defaultGlobalTex = LSM:Fetch("statusbar", globalTexName) or E.media.normTex or [[Interface\TargetingFrame\UI-StatusBar]]

    local function ApplyBarGraphics(bar, cfg)
        if not bar or not bar.statusBar then return end
        
        local texName = (cfg.useCustomTexture and cfg.texture and cfg.texture ~= "") and cfg.texture or globalTexName
        local tex = LSM:Fetch("statusbar", texName) or defaultGlobalTex
        bar.statusBar:SetStatusBarTexture(tex)
        
        if bar.statusBar.bg then
            local bgTexName = (cfg.useCustomBgTexture and cfg.bgTexture and cfg.bgTexture ~= "") and cfg.bgTexture or globalTexName
            local bgTex = LSM:Fetch("statusbar", bgTexName) or defaultGlobalTex
            bar.statusBar.bg:SetTexture(bgTex)
            
            local bgc = cfg.bgColor or {r=0, g=0, b=0, a=0.5}
            bar.statusBar.bg:SetVertexColor(bgc.r, bgc.g, bgc.b, bgc.a)
        end
    end

    ApplyBarGraphics(self.powerBar, db.power)
    ApplyBarGraphics(self.classBar, db.class)
    ApplyBarGraphics(self.tertiaryBar, db.tertiary)
    if self.manaAnchor then ApplyBarGraphics(self.manaBar, db.mana) end

    local targetWidth = GetTargetWidth()
    local totalHeight = 0
    local lastBar = nil
    
    local function AnchorBar(bar, height, isShown)
        bar:ClearAllPoints()
        if isShown then
            bar.isForceHidden = false 
            bar:SetSize(targetWidth, tonumber(height) or 14)
            if not lastBar then bar:SetPoint("BOTTOM", self.anchor, "BOTTOM", 0, 0)
            else bar:SetPoint("BOTTOM", lastBar, "TOP", 0, tonumber(db.yOffset) or 1); totalHeight = totalHeight + (tonumber(db.yOffset) or 1) end
            
            bar:Show()
            totalHeight = totalHeight + (tonumber(height) or 14)
            lastBar = bar
        else
            bar.isForceHidden = true 
            bar:Hide()
        end
    end

    local pType = UnitPowerType("player")
    local pMax = UnitPowerMax("player", pType)
    local validMax = IsSecret(pMax) or ((tonumber(pMax) or 0) > 0)
    self.showPower = db.power.enable and validMax and specCfg.showPower
    
    local _, _, _, hasClassDef = GetClassResourceData()
    self.showClass = db.class.enable and hasClassDef and specCfg.showClass
    
    local _, _, _, _, _, tShouldShow = GetTertiaryResourceData()
    self.showTertiary = db.tertiary.enable and tShouldShow and specCfg.showTertiary
    
    local manaMax = UnitPowerMax("player", 0)
    local validManaMax = IsSecret(manaMax) or ((tonumber(manaMax) or 0) > 0)
    self.showMana = hasHealerSpec and db.mana.enable and validManaMax and specCfg.showMana

    AnchorBar(self.powerBar, db.power.height, self.showPower)
    AnchorBar(self.classBar, db.class.height, self.showClass)
    AnchorBar(self.tertiaryBar, db.tertiary.height, self.showTertiary)
    self.anchor:SetSize(targetWidth, math.max(10, totalHeight))

    if db.alignWithCD and _G.EssentialCooldownViewer then
        self.anchor:ClearAllPoints()
        local alignY = tonumber(db.alignYOffset) or 1
        self.anchor:SetPoint("BOTTOM", _G.EssentialCooldownViewer, "TOP", 0, alignY)
    else
        if self.anchor.mover then
            self.anchor:ClearAllPoints()
            self.anchor:SetPoint("CENTER", self.anchor.mover, "CENTER", 0, 0)
        end
    end

    if self.showMana and self.manaAnchor then
        self.manaBar.isForceHidden = false
        self.manaBar:SetSize(targetWidth, tonumber(db.mana.height) or 10)
        self.manaBar:ClearAllPoints()
        local bx, by = tonumber(db.mana.barXOffset) or 0, tonumber(db.mana.barYOffset) or 0
        self.manaBar:SetPoint("CENTER", self.manaAnchor, "CENTER", bx, by)
        self.manaBar:Show()
        self.manaAnchor:SetSize(targetWidth, tonumber(db.mana.height) or 10)
    elseif self.manaBar then
        self.manaBar.isForceHidden = true
        self.manaBar:Hide()
    end
    
    self:DynamicTick()
end

local function UpdateBarValueSafe(sb, rawCurr, rawMax)
    if IsSecret(rawMax) or IsSecret(rawCurr) then
        sb:SetMinMaxValues(0, rawMax)
        sb:SetValue(rawCurr)
        sb._targetValue = nil 
        sb._currentValue = nil
        return
    end
    
    local currentMax = select(2, sb:GetMinMaxValues())
    if IsSecret(currentMax) or type(currentMax) ~= "number" or currentMax ~= rawMax then
        sb:SetMinMaxValues(0, rawMax)
        sb._currentValue = rawCurr
        sb._targetValue = rawCurr
        sb:SetValue(rawCurr)
    else
        sb._targetValue = rawCurr
    end
end

function CR:DynamicTick()
    if not self.anchor then return end
    local db = GetDB()
    local specCfg = self.cachedSpecCfg or GetCurrentSpecConfig(GetCurrentContextID())
    self.hasActiveTimer = false

    if self.showPower then
        local pType = UnitPowerType("player")
        local rawMax = UnitPowerMax("player", pType)
        local rawCurr = UnitPower("player", pType)
        
        if not IsSecret(rawMax) then
            if type(rawMax) ~= "number" or rawMax <= 0 then rawMax = 1 end
        end
        if type(rawCurr) ~= "number" then rawCurr = 0 end
        
        local pColor = GetSafeColor(db.power, GetPowerColor(pType), false)
        UpdateBarValueSafe(self.powerBar.statusBar, rawCurr, rawMax)
        self.powerBar.statusBar:SetStatusBarColor(pColor.r, pColor.g, pColor.b)
        self:UpdateDividers(self.powerBar, 1)
        FormatSafeText(self.powerBar, db.power, rawCurr, rawMax, false, pType, specCfg.textPower)
    end

    if self.showClass then
        local rawCurr, rawMax, cDefColor = GetClassResourceData()
        
        if not IsSecret(rawMax) then
            if type(rawMax) ~= "number" or rawMax <= 0 then rawMax = 1 end
        end
        if type(rawCurr) ~= "number" then rawCurr = 0 end
        
        local cColor = GetSafeColor(db.class, cDefColor, true)
        UpdateBarValueSafe(self.classBar.statusBar, rawCurr, rawMax)
        self.classBar.statusBar:SetStatusBarColor(cColor.r, cColor.g, cColor.b)
        self:UpdateDividers(self.classBar, rawMax)
        FormatSafeText(self.classBar, db.class, rawCurr, rawMax, false, nil, specCfg.textClass)
    end
    
    local rawTCurr, rawTMax, tDefColor, tIsTime, tSegments, tShouldShow, rawTextValue, durObj = GetTertiaryResourceData()
    local newShowTertiary = db.tertiary.enable and tShouldShow and specCfg.showTertiary
    if self.showTertiary ~= newShowTertiary then 
        self.showTertiary = newShowTertiary
        self:UpdateLayout() 
        return
    end
    
    if self.showTertiary then
        if not IsSecret(rawTMax) then
            if type(rawTMax) ~= "number" or rawTMax <= 0 then rawTMax = 1 end
        end
        if type(rawTCurr) ~= "number" then rawTCurr = 0 end
        
        if tIsTime and tShouldShow then self.hasActiveTimer = true end
        local tColor = GetSafeColor(db.tertiary, tDefColor, false)
        
        UpdateBarValueSafe(self.tertiaryBar.statusBar, rawTCurr, rawTMax)
        self.tertiaryBar.statusBar:SetStatusBarColor(tColor.r, tColor.g, tColor.b)
        self:UpdateDividers(self.tertiaryBar, tSegments)
        local isEleMana = (playerClass == "SHAMAN" and GetSpecializationInfo(GetSpecialization() or 1) == 262)
        
        local displayValue = rawTextValue ~= nil and rawTextValue or rawTCurr
        FormatSafeText(self.tertiaryBar, db.tertiary, displayValue, rawTMax, tIsTime, isEleMana and 0 or nil, specCfg.textTertiary, durObj)
        
        local tBar = self.tertiaryBar
        if not tBar.rechargeOverlay then
            tBar.rechargeOverlay = CreateFrame("StatusBar", nil, tBar.statusBar)
            tBar.rechargeOverlay:SetFrameLevel(tBar.statusBar:GetFrameLevel() + 1)
        end

        if durObj and type(displayValue) == "number" and displayValue < rawTMax and tBar.rechargeOverlay.SetTimerDuration then
            tBar.rechargeOverlay:SetStatusBarTexture(tBar.statusBar:GetStatusBarTexture():GetTexture())
            
            if db.tertiary.useCustomRechargeColor and db.tertiary.rechargeColor then
                local rc = db.tertiary.rechargeColor
                tBar.rechargeOverlay:SetStatusBarColor(rc.r, rc.g, rc.b, rc.a)
            else
                tBar.rechargeOverlay:SetStatusBarColor(tColor.r, tColor.g, tColor.b, 0.75)
            end
            
            local totalWidth = tBar.statusBar:GetWidth() or 250
            local numMax = tonumber(rawTMax) or 1
            if numMax <= 0 then numMax = 1 end
            local segWidth = totalWidth / numMax
            
            tBar.rechargeOverlay:ClearAllPoints()
            tBar.rechargeOverlay:SetPoint("TOPLEFT", tBar.statusBar, "TOPLEFT", displayValue * segWidth, 0)
            tBar.rechargeOverlay:SetPoint("BOTTOMLEFT", tBar.statusBar, "BOTTOMLEFT", displayValue * segWidth, 0)
            tBar.rechargeOverlay:SetWidth(segWidth)
            tBar.rechargeOverlay:SetMinMaxValues(0, 1)
            
            local interpolation = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Linear or 0
            local direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime or 0
            tBar.rechargeOverlay:SetTimerDuration(durObj, interpolation, direction)
            tBar.rechargeOverlay:Show()
        else
            tBar.rechargeOverlay:Hide()
        end
    end
    
    if self.showMana then
        local rawMax = UnitPowerMax("player", 0)
        local rawCurr = UnitPower("player", 0)
        
        if not IsSecret(rawMax) then
            if type(rawMax) ~= "number" or rawMax <= 0 then rawMax = 1 end
        end
        if type(rawCurr) ~= "number" then rawCurr = 0 end
        
        local mColor = GetSafeColor(db.mana, POWER_COLORS[0], false)
        UpdateBarValueSafe(self.manaBar.statusBar, rawCurr, rawMax)
        self.manaBar.statusBar:SetStatusBarColor(mColor.r, mColor.g, mColor.b)
        self:UpdateDividers(self.manaBar, 1)
        FormatSafeText(self.manaBar, db.mana, rawCurr, rawMax, false, 0, specCfg.textMana)
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
    InjectOptions()
    
    if not E.db.WishFlex.modules.classResource then return end

    if GetDB().hideElvUIBars then
        E.db.unitframe.units.player.power.enable = false
        E.db.unitframe.units.player.classbar.enable = false
        E:Delay(1, function()
            if UF then UF:CreateAndUpdateUF('player') end
        end)
    end
    
    self.anchor = CreateFrame("Frame", "WishFlex_ClassResourceAnchor", E.UIParent)
    self.anchor:SetPoint("CENTER", E.UIParent, "CENTER", 0, -180)
    E:CreateMover(self.anchor, "WishFlexClassResourceMover", "WishFlex: 职业资源条", nil, nil, nil, "ALL,WISHFLEX")

    self.manaAnchor = CreateFrame("Frame", "WishFlex_ManaBarAnchor", E.UIParent)
    self.manaAnchor:SetPoint("CENTER", E.UIParent, "CENTER", 0, -220)
    E:CreateMover(self.manaAnchor, "WishFlexManaBarMover", "WishFlex: 专属法力条", nil, nil, nil, "ALL,WISHFLEX")

    self.powerBar = self:CreateBarContainer("WishFlex_PowerBar", self.anchor)
    self.classBar = self:CreateBarContainer("WishFlex_ClassBar", self.anchor)
    self.tertiaryBar = self:CreateBarContainer("WishFlex_TertiaryBar", self.anchor)
    self.manaBar = self:CreateBarContainer("WishFlex_ManaBar", self.manaAnchor)
    
    -- 【性能核心修复2/3】：将四个进度条放进全局静态数组中，供 OnUpdate 无损轮询
    CR.AllBars = {self.powerBar, self.classBar, self.tertiaryBar, self.manaBar}
    
    self.showPower, self.showClass, self.showTertiary, self.showMana = false, false, false, false
    
    self.idleTimer = 0
    self.sleepMode = false
    self.hasActiveTimer = false
    
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateLayout")
    self:RegisterEvent("UNIT_DISPLAYPOWER", "UpdateLayout")
    self:RegisterEvent("UNIT_MAXPOWER", "UpdateLayout")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnContextChanged")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "OnContextChanged")
    
    self:RegisterEvent("UNIT_POWER_UPDATE", "WakeUp")
    self:RegisterEvent("UNIT_POWER_FREQUENT", "WakeUp")
    self:RegisterEvent("UNIT_AURA", "WakeUp")
    self:RegisterEvent("SPELL_UPDATE_CHARGES", "WakeUp")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "WakeUp")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "WakeUp")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "WakeUp")

    E:Delay(0.5, function()
        local CDMod = WF:GetModule('CooldownCustom', true)
        if CDMod and CDMod.TriggerLayout then
            hooksecurefunc(CDMod, "TriggerLayout", function()
                if GetDB().alignWithCD then
                    CR:UpdateLayout()
                end
            end)
        end
    end)
    
    CR:OnContextChanged()
    
    local ticker = 0
    CR.frameTick = 0
    self.anchor:SetScript("OnUpdate", function(_, elapsed)
        if CR.sleepMode then return end
        
        CR.frameTick = CR.frameTick + 1
        
        local SMOOTH_SPEED = 15
        for i = 1, 4 do
            local bar = CR.AllBars[i]
            if bar and bar.statusBar and not bar.isForceHidden then
                local sb = bar.statusBar
                if sb._targetValue and not IsSecret(sb._targetValue) then
                    sb._currentValue = sb._currentValue or sb:GetValue() or 0
                    if not IsSecret(sb._currentValue) and sb._currentValue ~= sb._targetValue then
                        local diff = sb._targetValue - sb._currentValue
                        if diff < 0 then
                            sb._currentValue = sb._targetValue
                        elseif diff < 0.01 then
                            sb._currentValue = sb._targetValue
                        else
                            sb._currentValue = sb._currentValue + diff * SMOOTH_SPEED * elapsed
                        end
                        sb:SetValue(sb._currentValue)
                    end
                end
            end
        end
        
        ticker = ticker + elapsed
        local interval = InCombatLockdown() and 0.05 or 0.2
        if ticker >= interval then
            ticker = 0
            CR:DynamicTick()
            
            if not InCombatLockdown() then
                CR.idleTimer = (CR.idleTimer or 0) + interval
                if CR.idleTimer >= 2 and not CR.hasActiveTimer then
                    CR.sleepMode = true
                end
            else
                CR.idleTimer = 0
            end
        end
    end)
end
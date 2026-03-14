local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WF = E:GetModule('WishFlex')
local SH = WF:NewModule('SmartHide', 'AceEvent-3.0', 'AceTimer-3.0', 'AceHook-3.0')
local UF = E:GetModule('UnitFrames')

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.smarthide = true
P["WishFlex"].smarthide = {
    enable = true, forceShow = false,
    filters = { unitframe = true, buffs = true, cooldowns = true, actionbar = true, minimap = true, friendly = false, actionTimer = true, classResource = true, damageMeter = true },
    -- 【新增】：飞行/驭空术强制隐藏的默认配置（默认全不选）
    dragonriding = { unitframe = false, buffs = false, cooldowns = false, actionbar = false, minimap = false, classResource = false, damageMeter = false, actionTimer = false },
}

local function InjectOptions()
    WF.OptionsArgs = WF.OptionsArgs or {}
    WF.OptionsArgs.smarthide = WF.OptionsArgs.smarthide or { order = 10, type = "group", name = "|cff00ffcc智能隐藏|r", childGroups = "tab", args = {} }
    
    local args = WF.OptionsArgs.smarthide.args
    args.general = {
        order = 1, type = "group", name = "基础设置",
        args = {
            enable = { order = 1, type = "toggle", name = "启用", get = function() return E.db.WishFlex.modules.smarthide end, set = function(_, v) E.db.WishFlex.modules.smarthide = v; E:StaticPopup_Show("CONFIG_RL") end },
            force = { order = 2, type = "toggle", name = "强制显示全部", get = function() return E.db.WishFlex.smarthide.forceShow end, set = function(_, v) E.db.WishFlex.smarthide.forceShow = v; SH:UpdateVisibility() end },
            -- 【新增】：飞行/驭空术多选菜单
            dragonriding = {
                order = 3, type = "multiselect", name = "飞行/驭空术时强制隐藏",
                desc = "选中后，只要你处于飞行或驭空术状态，无论是否进战，都会强制隐藏该模块以提供沉浸式体验。",
                values = {
                    unitframe = "单位框体 (玩家/宠物/目标)",
                    buffs = "增益减益 (玩家光环)",
                    cooldowns = "冷却管理器",
                    actionTimer = "动作计时条",
                    minimap = "小地图",
                    classResource = "职业资源与能量条",
                    actionbar = "特定动作条 (宠物条)",
                    damageMeter = "伤害统计窗口",
                },
                get = function(info, key) return E.db.WishFlex.smarthide.dragonriding[key] end,
                set = function(info, key, value) E.db.WishFlex.smarthide.dragonriding[key] = value; SH:UpdateVisibility() end,
            }
        }
    }
    args.filters = {
        order = 2, type = "group", name = "隐藏模块 (脱战无目标时隐藏)",
        args = {
            group = {
                order = 1, type = "group", name = "应用范围", guiInline = true,
                get = function(i) return E.db.WishFlex.smarthide.filters[i[#i]] end,
                set = function(i, v) E.db.WishFlex.smarthide.filters[i[#i]] = v; SH:UpdateVisibility() end,
                args = {
                    unitframe = {order=1, type="toggle", name="单位框体 (玩家/宠物/目标)"}, 
                    buffs = {order=2, type="toggle", name="增益减益 (玩家光环)"}, 
                    cooldowns = {order=3, type="toggle", name="冷却管理器"}, 
                    actionTimer = {order=4, type="toggle", name="动作计时条"}, 
                    minimap = {order=5, type="toggle", name="小地图"},
                    classResource = {order=6, type="toggle", name="职业资源与能量条"},
                    actionbar = {order=7, type="toggle", name="特定动作条 (宠物条)"},
                    friendly = {order=8, type="toggle", name="友方NPC时隐藏", desc = "即使有目标，如果目标是友方NPC，依然保持隐藏状态。"},
                    damageMeter = {order=9, type="toggle", name="伤害统计窗口"},
                }
            }
        }
    }
end

-- 全局宿主容器
local WishBuffHost = CreateFrame("Frame", "WishBuffHost", UIParent); WishBuffHost:SetAllPoints(UIParent); WishBuffHost:Show()
local WishDebuffHost = CreateFrame("Frame", "WishDebuffHost", UIParent); WishDebuffHost:SetAllPoints(UIParent); WishDebuffHost:Show()
local WishBarPetHost = CreateFrame("Frame", "WishBarPetHost", UIParent); WishBarPetHost:SetAllPoints(UIParent); WishBarPetHost:Show()
local WishClassResourceHost = CreateFrame("Frame", "WishClassResourceHost", UIParent); WishClassResourceHost:SetAllPoints(UIParent); WishClassResourceHost:Show()
local WishCooldownHost = CreateFrame("Frame", "WishCooldownHost", UIParent); WishCooldownHost:SetAllPoints(UIParent); WishCooldownHost:Show()
local WishActionTimerHost = CreateFrame("Frame", "WishActionTimerHost", UIParent); WishActionTimerHost:SetAllPoints(UIParent); WishActionTimerHost:Show()
local WishDamageMeterHost = CreateFrame("Frame", "WishDamageMeterHost", UIParent); WishDamageMeterHost:SetAllPoints(UIParent); WishDamageMeterHost:Show()

local FRAME_CATEGORIES = {
    ["ElvUF_Player"] = { cat = "unitframe", type = "player" },
    ["ElvUF_Pet"] = { cat = "unitframe", type = "alpha", isPlayerOnly = true, requirePet = true }, 
    ["ElvUF_Target"] = { cat = "unitframe", type = "alpha", isPlayerOnly = false },

    ["ElvUIPlayerBuffs"] = { cat = "buffs", type = "host", host = "WishBuffHost" },
    ["ElvUIPlayerDebuffs"] = { cat = "buffs", type = "host", host = "WishDebuffHost" },
    ["ElvUI_BarPet"] = { cat = "actionbar", type = "host", host = "WishBarPetHost" },
    
    ["WishFlex_ClassBar"] = { cat = "classResource", type = "host", host = "WishClassResourceHost" },
    ["WishFlex_PowerBar"] = { cat = "classResource", type = "host", host = "WishClassResourceHost" },
    ["WishFlex_TertiaryBar"] = { cat = "classResource", type = "host", host = "WishClassResourceHost" },
    ["WishFlex_ManaBar"] = { cat = "classResource", type = "host", host = "WishClassResourceHost" },
    ["WishFlex_AuraAnchor"] = { cat = "classResource", type = "host", host = "WishClassResourceHost" },
    
    ["EssentialCooldownViewer"] = { cat = "cooldowns", type = "host", host = "WishCooldownHost" },
    ["UtilityCooldownViewer"] = { cat = "cooldowns", type = "host", host = "WishCooldownHost" },
    ["WishFlex_CooldownRow2_Anchor"] = { cat = "cooldowns", type = "host", host = "WishCooldownHost" },
    ["WishFlex_ActionTimer_Anchor"] = { cat = "actionTimer", type = "host", host = "WishActionTimerHost" },
    ["BuffIconCooldownViewer"] = { cat = "cooldowns", type = "host", host = "WishCooldownHost" },
    ["BuffBarCooldownViewer"] = { cat = "cooldowns", type = "host", host = "WishCooldownHost" },

    ["DamageMeterSessionWindow1"] = { cat = "damageMeter", type = "host", host = "WishDamageMeterHost" },
    ["DamageMeterSessionWindow2"] = { cat = "damageMeter", type = "host", host = "WishDamageMeterHost" },
    ["DamageMeterSessionWindow3"] = { cat = "damageMeter", type = "host", host = "WishDamageMeterHost" },
    ["DamageMeter"] = { cat = "damageMeter", type = "host", host = "WishDamageMeterHost" },

    ["MMHolder"] = { cat = "minimap", type = "secure" },
    ["MinimapCluster"] = { cat = "minimap", type = "secure" }
}

local PLAYER_UF_ELEMENTS = {
    "Health", "Power", "Portrait", "InfoPanel", "AuraBars", 
    "Buffs", "Debuffs", "ThreatIndicator", "ResurrectIndicator",
    "CombatIndicator", "RestingIndicator", "backdrop", "bg",
    "RaisedElementParent" 
}

local FrameCache = {}
local function GetCachedFrame(name)
    if FrameCache[name] then return FrameCache[name] end
    local f = _G[name]
    if not f and name:find("%.") then
        local parts = {strsplit(".", name)}
        f = _G[parts[1]]
        if f then 
            for i = 2, #parts do 
                f = f[parts[i]] 
                if not f then break end
            end 
        end
    end
    if f then FrameCache[name] = f end
    return f
end

local HookedFrames = {}

local function SecureAlphaHook(frame, alpha)
    if frame.SmartHideTargetAlpha == 0 and alpha ~= 0 then frame:SetAlpha(0) end
end

local function SetFrameAlphaImmediate(frame, targetAlpha)
    if type(frame) ~= "table" or not frame.SetAlpha then return end
    if frame.isForceHidden then
        if frame:GetAlpha() ~= 0 then frame:SetAlpha(0) end
        return
    end
    local isUnitFrame = frame.GetName and frame:GetName() and frame:GetName():find("ElvUF_")
    if frame.SmartHideTargetAlpha == targetAlpha then return end
    frame.SmartHideTargetAlpha = targetAlpha

    if not HookedFrames[frame] then
        hooksecurefunc(frame, "SetAlpha", SecureAlphaHook)
        HookedFrames[frame] = true
    end

    if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(frame) end 
    frame:SetAlpha(targetAlpha)
    if isUnitFrame then
        if not InCombatLockdown() and frame.EnableMouse then frame:EnableMouse(targetAlpha == 1) end
    end
end

local function IsPlayerFlying() return type(IsFlying) == "function" and IsFlying() end

-- 【更新】：生成小地图专用的底层驱动宏，融入飞行判断
local function GetSecureMacro(db, cat)
    if db.forceShow then return "show" end
    
    local macro = "[petbattle] hide; "
    if cat ~= "minimap" then
        macro = macro .. "[vehicleui] hide; "
    end
    
    -- 1. 飞行/驭空术隐藏逻辑（优先级最高）
    if db.dragonriding and db.dragonriding[cat] then
        macro = macro .. "[flying] hide; "
    elseif cat == "minimap" then
        -- 默认情况下飞行时显示小地图
        macro = macro .. "[flying] show; "
    end
    
    -- 2. 如果未勾选常规智能隐藏，则保持显示
    if not db.filters[cat] then
        macro = macro .. "show"
        return macro
    end
    
    -- 3. 常规的脱战智能隐藏
    if db.filters.friendly then
        macro = macro .. "[combat] show; [harm] show; hide"
    else
        macro = macro .. "[combat] show; [exists] show; hide"
    end
    return macro
end

function SH:UpdateVisibility()
    local db = E.db.WishFlex.smarthide
    if not db or not db.enable then 
        for name, info in pairs(FRAME_CATEGORIES) do
            if info.type == "secure" then
                local f = GetCachedFrame(name)
                if f and f._wishSecureMacro then
                    UnregisterStateDriver(f, "visibility")
                    f:Show()
                    f._wishSecureMacro = nil
                end
            end
        end
        return 
    end

    local inCombat = InCombatLockdown()
    local hasTarget = false
    if UnitExists("target") then
        if db.filters.friendly then hasTarget = UnitCanAttack("player", "target") or UnitIsPlayer("target") else hasTarget = true end
    end
    
    local isFlying = IsPlayerFlying() 
    local inPetBattle = C_PetBattles and C_PetBattles.IsInBattle()
    local inVehicle = UnitInVehicle("player") or UnitHasVehicleUI("player")

    local shouldShowPlayerOnly = (inCombat or hasTarget) and not inPetBattle
    local shouldShowOthers = (inCombat or hasTarget) and not inPetBattle
    if inVehicle then shouldShowOthers = false end
    if db.forceShow then shouldShowPlayerOnly = true; shouldShowOthers = true end

    local minimapMacro = GetSecureMacro(db, "minimap")

    for name, info in pairs(FRAME_CATEGORIES) do
        local f = GetCachedFrame(name)
        if f then
            if info.type == "secure" then
                if f._wishSecureMacro ~= minimapMacro then
                    RegisterStateDriver(f, "visibility", minimapMacro)
                    f._wishSecureMacro = minimapMacro
                end
            
            elseif info.type == "host" then
                local targetAlpha = shouldShowOthers and 1 or 0
                if info.cat == "buffs" or info.cat == "actionbar" then targetAlpha = shouldShowPlayerOnly and 1 or 0 end
                if not db.filters[info.cat] then targetAlpha = 1 end
                
                -- 【飞行拦截】：如果勾选了飞行隐藏，强制设为 0
                if isFlying and db.dragonriding and db.dragonriding[info.cat] then targetAlpha = 0 end

                local hostFrame = _G[info.host]
                if hostFrame then
                    if f:GetParent() ~= hostFrame and not InCombatLockdown() then
                        f:SetParent(hostFrame)
                        if info.cat == "damageMeter" and name == "DamageMeterSessionWindow1" then
                            if not f:IsShown() then pcall(function() f:Show() end) end
                        end
                    end
                    local finalAlpha = targetAlpha
                    if info.host == "WishBarPetHost" and not UnitExists("pet") then finalAlpha = 0 end
                    hostFrame:SetAlpha(finalAlpha)
                end
                
            elseif info.type == "player" then
                local targetAlpha = shouldShowPlayerOnly and 1 or 0
                if not db.filters[info.cat] then targetAlpha = 1 end
                
                -- 【飞行拦截】：如果勾选了飞行隐藏，强制设为 0
                if isFlying and db.dragonriding and db.dragonriding[info.cat] then targetAlpha = 0 end

                if f:GetAlpha() ~= 1 then f.SmartHideTargetAlpha = 1; f:SetAlpha(1) end
                for i = 1, #PLAYER_UF_ELEMENTS do
                    local el = f[PLAYER_UF_ELEMENTS[i]]
                    if el and type(el) == "table" and el.SetAlpha then 
                        el.SmartHideTargetAlpha = targetAlpha
                        if not HookedFrames[el] then hooksecurefunc(el, "SetAlpha", SecureAlphaHook); HookedFrames[el] = true end
                        if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(el) end
                        el:SetAlpha(targetAlpha)
                    end
                end
                
            elseif info.type == "alpha" then
                local targetAlpha = info.isPlayerOnly and shouldShowPlayerOnly or shouldShowOthers
                targetAlpha = targetAlpha and 1 or 0
                if info.requirePet and not UnitExists("pet") then targetAlpha = 0 end
                if not db.filters[info.cat] then targetAlpha = 1 end
                
                -- 【飞行拦截】：如果勾选了飞行隐藏，强制设为 0
                if isFlying and db.dragonriding and db.dragonriding[info.cat] then targetAlpha = 0 end

                SetFrameAlphaImmediate(f, targetAlpha)
            end
        end
    end

    local playerFrame = _G["ElvUF_Player"]
    if playerFrame and playerFrame.customTexts then
        local textAlpha = 1
        if db.filters.unitframe and not shouldShowPlayerOnly then textAlpha = 0 end
        
        -- 【飞行拦截】：文字也一起隐藏
        if isFlying and db.dragonriding and db.dragonriding.unitframe then textAlpha = 0 end
        
        if db.forceShow then textAlpha = 1 end
        for _, textFrame in pairs(playerFrame.customTexts) do 
            if textFrame and type(textFrame) == "table" and textFrame.SetAlpha then 
                textFrame.SmartHideTargetAlpha = textAlpha
                if not HookedFrames[textFrame] then hooksecurefunc(textFrame, "SetAlpha", SecureAlphaHook); HookedFrames[textFrame] = true end
                if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(textFrame) end
                textFrame:SetAlpha(textAlpha)
            end 
        end
    end
end

function SH:OnEnable()
    InjectOptions()
    if not E.db.WishFlex.modules.smarthide then return end
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateVisibility")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "UpdateVisibility")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function() 
        self:UpdateVisibility() 
        C_Timer.After(5, function() collectgarbage("collect") end)
    end)
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "UpdateVisibility")
    self:RegisterEvent("UNIT_PET", "UpdateVisibility") 
    self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR", "UpdateVisibility")
    self:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR", "UpdateVisibility")
    self:RegisterEvent("UNIT_ENTERED_VEHICLE", "UpdateVisibility")
    self:RegisterEvent("UNIT_EXITED_VEHICLE", "UpdateVisibility")
    
    self:UpdateVisibility()
    
    E:Delay(2, function()
        if UF and UF.PostUpdateVisibility then self:SecureHook(UF, "PostUpdateVisibility", "UpdateVisibility") end
        local centers = {"EssentialCooldownViewer", "UtilityCooldownViewer", "WishFlex_ActionTimer_Anchor", "WishFlex_CooldownRow2_Anchor"}
        for _, n in ipairs(centers) do
            local f = _G[n]
            if f then
                f:HookScript("OnDragStart", function(s) s.isMoving = true end)
                f:HookScript("OnDragStop", function(s) s.isMoving = false end)
            end
        end
    end)
    
    local tickerFrame = CreateFrame("Frame")
    local tickElapsed = 0
    tickerFrame:SetScript("OnUpdate", function(_, delta)
        tickElapsed = tickElapsed + delta
        local interval = InCombatLockdown() and 0.5 or 1.0 
        if tickElapsed >= interval then
            tickElapsed = 0
            SH:UpdateVisibility()
        end
    end)
end

SLASH_CMC_CVS1 = "/cds"; SlashCmdList["CMC_CVS"] = function()
    if not InCombatLockdown() and CooldownViewerSettings then CooldownViewerSettings:ShowUIPanel(false) end
end
SLASH_QUICKEDITMODE1 = "/em"; SlashCmdList["QUICKEDITMODE"] = function()
    if InCombatLockdown() then return end
    if EditModeManagerFrame:IsShown() then HideUIPanel(EditModeManagerFrame) else ShowUIPanel(EditModeManagerFrame) end
end
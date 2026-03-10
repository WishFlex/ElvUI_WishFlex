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
}

local function InjectOptions()
    WF.OptionsArgs = WF.OptionsArgs or {}
    WF.OptionsArgs.smarthide = WF.OptionsArgs.smarthide or { order = 10, type = "group", name = "|cff00ffcc智能隐藏|r", childGroups = "tab", args = {} }
    
    local args = WF.OptionsArgs.smarthide.args
    args.general = {
        order = 1, type = "group", name = "基础设置",
        args = {
            enable = { order = 1, type = "toggle", name = "启用", get = function() return E.db.WishFlex.modules.smarthide end, set = function(_, v) E.db.WishFlex.modules.smarthide = v; E:StaticPopup_Show("CONFIG_RL") end },
            force = { order = 2, type = "toggle", name = "强制显示全部", get = function() return E.db.WishFlex.smarthide.forceShow end, set = function(_, v) E.db.WishFlex.smarthide.forceShow = v; SH:UpdateVisibility() end }
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
local WishBuffHost = CreateFrame("Frame", "WishBuffHost", UIParent)
local WishDebuffHost = CreateFrame("Frame", "WishDebuffHost", UIParent)
local WishBarPetHost = CreateFrame("Frame", "WishBarPetHost", UIParent)
local WishClassResourceHost = CreateFrame("Frame", "WishClassResourceHost", UIParent)
local WishCooldownHost = CreateFrame("Frame", "WishCooldownHost", UIParent)
local WishActionTimerHost = CreateFrame("Frame", "WishActionTimerHost", UIParent)

WishBuffHost:Show(); WishDebuffHost:Show(); WishBarPetHost:Show(); WishClassResourceHost:Show()
WishCooldownHost:Show(); WishActionTimerHost:Show()

local HiddenFrame = CreateFrame("Frame")
HiddenFrame:Hide()

local FRAME_CATEGORIES = {
    ["ElvUF_Player"] = { cat = "unitframe", isPlayerOnly = true },
    ["ElvUF_Pet"] = { cat = "unitframe", isPlayerOnly = true, requirePet = true }, 
    ["ElvUF_Target"] = { cat = "unitframe", isPlayerOnly = false },

    -- 保护框体组：使用宿主容器避免报错
    ["ElvUIPlayerBuffs"] = { cat = "buffs", isSpecialHost = "WishBuffHost" },
    ["ElvUIPlayerDebuffs"] = { cat = "buffs", isSpecialHost = "WishDebuffHost" },
    ["ElvUI_BarPet"] = { cat = "actionbar", isSpecialHost = "WishBarPetHost" },
    
    -- 资源条与冷却管理器：移入宿主容器，利用透明度屏蔽闪现
    ["WishFlex_ClassBar"] = { cat = "classResource", isSpecialHost = "WishClassResourceHost" },
    ["WishFlex_PowerBar"] = { cat = "classResource", isSpecialHost = "WishClassResourceHost" },
    ["WishFlex_TertiaryBar"] = { cat = "classResource", isSpecialHost = "WishClassResourceHost" },
    ["WishFlex_ManaBar"] = { cat = "classResource", isSpecialHost = "WishClassResourceHost" },
    
    ["EssentialCooldownViewer"] = { cat = "cooldowns", isSpecialHost = "WishCooldownHost" },
    ["UtilityCooldownViewer"] = { cat = "cooldowns", isSpecialHost = "WishCooldownHost" },
    ["WishFlex_CooldownRow2_Anchor"] = { cat = "cooldowns", isSpecialHost = "WishCooldownHost" },
    ["WishFlex_ActionTimer_Anchor"] = { cat = "actionTimer", isSpecialHost = "WishActionTimerHost" },

    -- 【关键修复】：将增益图标与增益条也列装宿主容器
    ["BuffIconCooldownViewer"] = { cat = "cooldowns", isSpecialHost = "WishCooldownHost" },
    ["BuffBarCooldownViewer"] = { cat = "cooldowns", isSpecialHost = "WishCooldownHost" },

    -- 非保护框体组：直接安全使用 Show/Hide
    ["DamageMeterSessionWindow1"] = { cat = "damageMeter", isPlayerOnly = false, isUnprotected = true },
    ["DamageMeterSessionWindow2"] = { cat = "damageMeter", isPlayerOnly = false, isUnprotected = true },
    ["DamageMeterSessionWindow3"] = { cat = "damageMeter", isPlayerOnly = false, isUnprotected = true },
    ["DamageMeter"] = { cat = "damageMeter", isPlayerOnly = false, isUnprotected = true }
}

-- 【性能核心修复1/2】：提取高频轮询所需的小地图框架与玩家框体组件为全局静态数组
local MINIMAP_FRAMES = { "MinimapCluster", "Minimap", "MinimapBackdrop", "MinimapPanel", "MMHolder" }
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
    if frame.SmartHideTargetAlpha == 0 and alpha ~= 0 then
        frame:SetAlpha(0)
    end
end

local function SetFrameAlphaImmediate(frame, targetAlpha)
    if type(frame) ~= "table" or not frame.SetAlpha then return end
    
    if frame.isForceHidden then
        if frame.Hide and frame:IsShown() then frame:Hide() end
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
        if not InCombatLockdown() and frame.EnableMouse then
            frame:EnableMouse(targetAlpha == 1)
        end
        return 
    end

    if InCombatLockdown() then return end

    if targetAlpha == 0 then 
        if frame.Hide and frame:IsShown() then frame:Hide() end 
    else 
        if frame.Show and not frame:IsShown() then frame:Show() end 
    end
end

local function IsPlayerFlying() return type(IsFlying) == "function" and IsFlying() end

function SH:UpdateMinimap(show)
    local targetAlpha = show and 1 or 0
    
    -- 【性能核心修复1/2应用】：不再动态创建表，直接遍历静态名称数组
    for i = 1, #MINIMAP_FRAMES do
        local f = _G[MINIMAP_FRAMES[i]]
        if f then
            if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(f) end
            if f:GetAlpha() ~= targetAlpha then f:SetAlpha(targetAlpha) end
            
            if show then
                if not f:IsShown() then f:Show() end
            else
                if f:IsShown() then f:Hide() end
            end
        end
    end
end

function SH:UpdateVisibility()
    local db = E.db.WishFlex.smarthide
    if not db or not db.enable then return end

    local inCombat = InCombatLockdown()
    local hasTarget = false
    
    if UnitExists("target") then
        if db.filters.friendly then hasTarget = UnitCanAttack("player", "target") or UnitIsPlayer("target") 
        else hasTarget = true end
    end
    
    local isFlying = IsPlayerFlying() 
    local inPetBattle = C_PetBattles and C_PetBattles.IsInBattle()
    local inVehicle = UnitInVehicle("player") or UnitHasVehicleUI("player")

    local shouldShowMinimap = (inCombat or hasTarget or isFlying) and not inPetBattle
    local shouldShowPlayerOnly = (inCombat or hasTarget) and not inPetBattle
    local shouldShowOthers = (inCombat or hasTarget) and not inPetBattle
    
    if inVehicle then 
        shouldShowOthers = false 
    end

    if db.forceShow then 
        shouldShowMinimap = true; 
        shouldShowPlayerOnly = true; 
        shouldShowOthers = true 
    end

    local finalMinimapShow = true
    if db.filters.minimap then finalMinimapShow = shouldShowMinimap end
    self:UpdateMinimap(finalMinimapShow)

    for name, info in pairs(FRAME_CATEGORIES) do
        local f = GetCachedFrame(name)
        if f then
            local targetAlpha
            if info.isPlayerOnly then
                targetAlpha = shouldShowPlayerOnly and 1 or 0
            else
                targetAlpha = shouldShowOthers and 1 or 0
            end

            if info.requirePet and not UnitExists("pet") then targetAlpha = 0 end

            local isControlled = db.filters[info.cat]
            if not isControlled then targetAlpha = 1 end

            if info.isSpecialHost then
                local hostFrame = _G[info.isSpecialHost]
                if hostFrame then
                    if f:GetParent() ~= hostFrame and not InCombatLockdown() then
                        f:SetParent(hostFrame)
                    end
                    
                    local finalAlpha = targetAlpha
                    if info.isSpecialHost == "WishBarPetHost" and not UnitExists("pet") then
                        finalAlpha = 0
                    end
                    
                    hostFrame:SetAlpha(finalAlpha)
                end
            
            elseif info.isUnprotected then
                if targetAlpha == 1 then
                    if not f:IsShown() then f:Show() end
                else
                    if f:IsShown() then f:Hide() end
                end

            elseif name == "ElvUF_Player" then
                if f:GetAlpha() ~= 1 then 
                    f.SmartHideTargetAlpha = 1
                    f:SetAlpha(1) 
                end
                
                -- 【性能核心修复2/2应用】：不再每次循环新建表，直接读取静态表 PLAYER_UF_ELEMENTS
                for i = 1, #PLAYER_UF_ELEMENTS do
                    local el = f[PLAYER_UF_ELEMENTS[i]]
                    if el and type(el) == "table" and el.SetAlpha then 
                        el.SmartHideTargetAlpha = targetAlpha
                        if not HookedFrames[el] then
                            hooksecurefunc(el, "SetAlpha", SecureAlphaHook)
                            HookedFrames[el] = true
                        end
                        if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(el) end
                        el:SetAlpha(targetAlpha)
                    end
                end
            else
                SetFrameAlphaImmediate(f, targetAlpha)
            end
        end
    end

    local playerFrame = _G["ElvUF_Player"]
    if playerFrame and playerFrame.customTexts then
        local textAlpha = 1
        if db.filters.unitframe and not shouldShowPlayerOnly then textAlpha = 0 end
        if db.forceShow then textAlpha = 1 end
        for _, textFrame in pairs(playerFrame.customTexts) do 
            if textFrame and type(textFrame) == "table" and textFrame.SetAlpha then 
                textFrame.SmartHideTargetAlpha = textAlpha
                if not HookedFrames[textFrame] then
                    hooksecurefunc(textFrame, "SetAlpha", SecureAlphaHook)
                    HookedFrames[textFrame] = true
                end
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
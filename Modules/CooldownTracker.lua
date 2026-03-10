local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local Tracker = WUI:NewModule('CooldownTracker', 'AceEvent-3.0', 'AceTimer-3.0', 'AceHook-3.0')

-- =====================================================================
-- 1. 基础配置
-- =====================================================================
local HiddenFrame = CreateFrame("Frame")
HiddenFrame:Hide()

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.cooldownTracker = true

P["WishFlex"].cdTracker = P["WishFlex"].cdTracker or {
    isFirstInit = true, 
    enableDesat = true,
    desatSpells = {}, 
    enableResource = true,
    resourceSpells = {},
}
Tracker.desatSpellSet = {}
Tracker.resourceSpellSet = {}

local Wish_FrameData = setmetatable({}, { __mode = "k" })
local function GetFrameData(frame)
    local data = Wish_FrameData[frame]
    if not data then data = {}; Wish_FrameData[frame] = data end
    return data
end

-- =====================================================================
-- 2. 图标勾选框面板
-- =====================================================================
local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.cdmanager = WUI.OptionsArgs.cdmanager or { order = 20, type = "group", name = "|cff00e5cc冷却管理器|r", childGroups = "tab", args = {} }
    
    local args = WUI.OptionsArgs.cdmanager.args
    args.tracker = {
        order = 3, type = "group", name = "褪色图标", childGroups = "tab",
        args = {
            desatGrp = {
                order = 1, type = "group", name = "目标无DoT时变灰", guiInline = true,
                args = {
                    enableDesat = { order = 1, type = "toggle", name = "启用", get = function() return E.db.WishFlex.cdTracker.enableDesat end, set = function(_, v) E.db.WishFlex.cdTracker.enableDesat = v; Tracker:RefreshAll() end },
                    addDesat = { order = 2, type = "input", name = "添加法术ID", set = function(_, value) local id = tonumber(value); if id and C_Spell.GetSpellName(id) then E.db.WishFlex.cdTracker.desatSpells[id] = true; Tracker.desatSpellSet[id] = true; Tracker:UpdateOptionsList(); Tracker:RefreshAll() end end },
                    list = { order = 3, type = "group", name = "已监控的DoT", guiInline = true, args = {} }
                }
            },
            resGrp = {
                order = 2, type = "group", name = "资源不足时变灰", guiInline = true,
                args = {
                    enableResource = { order = 1, type = "toggle", name = "启用", get = function() return E.db.WishFlex.cdTracker.enableResource end, set = function(_, v) E.db.WishFlex.cdTracker.enableResource = v; Tracker:RefreshAll() end },
                    addRes = { order = 2, type = "input", name = "添加法术ID", set = function(_, value) local id = tonumber(value); if id and C_Spell.GetSpellName(id) then E.db.WishFlex.cdTracker.resourceSpells[id] = true; Tracker.resourceSpellSet[id] = true; Tracker:UpdateOptionsList(); Tracker:RefreshAll() end end },
                    list = { order = 3, type = "group", name = "已监控的资源法术", guiInline = true, args = {} }
                }
            }
        }
    }
end

function Tracker:UpdateOptionsList()
    if not WUI.OptionsArgs.cdmanager.args.tracker then return end
    
    local desatArgs = WUI.OptionsArgs.cdmanager.args.tracker.args.desatGrp.args.list.args
    wipe(desatArgs)
    local idx = 1
    for id in pairs(E.db.WishFlex.cdTracker.desatSpells) do
        local numID = tonumber(id)
        local spellInfo = numID and C_Spell.GetSpellInfo(numID)
        local name = (spellInfo and spellInfo.name) or (numID and C_Spell.GetSpellName(numID)) or tostring(id)
        local icon = (spellInfo and spellInfo.iconID) or (numID and C_Spell.GetSpellTexture(numID)) or 136243
        desatArgs[tostring(id)] = {
            order = idx, type = "toggle", name = name, image = icon, imageCoords = E.TexCoords,
            get = function() return E.db.WishFlex.cdTracker.desatSpells[id] end,
            set = function(_, v) 
                if not v then E.db.WishFlex.cdTracker.desatSpells[id] = nil; Tracker.desatSpellSet[id] = nil; E:StaticPopup_Show("PRIVATE_RL")
                else E.db.WishFlex.cdTracker.desatSpells[id] = true; Tracker.desatSpellSet[id] = true end
                Tracker:UpdateOptionsList(); Tracker:RefreshAll() 
            end
        }
        idx = idx + 1
    end

    local resArgs = WUI.OptionsArgs.cdmanager.args.tracker.args.resGrp.args.list.args
    wipe(resArgs)
    local idx2 = 1
    for id in pairs(E.db.WishFlex.cdTracker.resourceSpells) do
        local numID = tonumber(id)
        local spellInfo = numID and C_Spell.GetSpellInfo(numID)
        local name = (spellInfo and spellInfo.name) or (numID and C_Spell.GetSpellName(numID)) or tostring(id)
        local icon = (spellInfo and spellInfo.iconID) or (numID and C_Spell.GetSpellTexture(numID)) or 136243
        resArgs[tostring(id)] = {
            order = idx2, type = "toggle", name = name, image = icon, imageCoords = E.TexCoords,
            get = function() return E.db.WishFlex.cdTracker.resourceSpells[id] end,
            set = function(_, v) 
                if not v then E.db.WishFlex.cdTracker.resourceSpells[id] = nil; Tracker.resourceSpellSet[id] = nil; E:StaticPopup_Show("PRIVATE_RL")
                else E.db.WishFlex.cdTracker.resourceSpells[id] = true; Tracker.resourceSpellSet[id] = true end
                Tracker:UpdateOptionsList(); Tracker:RefreshAll() 
            end
        }
        idx2 = idx2 + 1
    end
end

-- =====================================================================
-- 3. 消灭原生红框引擎
-- =====================================================================
local function SafeKillRedBorder(frame)
    local function killTex(tex)
        if tex and not tex._wishKilled then
            tex._wishKilled = true
            hooksecurefunc(tex, "SetAlpha", function(s, a) if a > 0 and not s._wLock then s._wLock=true; s:SetAlpha(0); s._wLock=false end end)
            hooksecurefunc(tex, "Show", function(s) if not s._wLock then s._wLock=true; s:Hide(); s._wLock=false end end)
            tex:SetAlpha(0)
            tex:Hide()
        end
    end
    killTex(frame.PandemicIcon)
    killTex(frame.CooldownFlash)
    killTex(frame.OutOfRange)
end

-- =====================================================================
-- 4. 回退至原版的安全变灰引擎
-- =====================================================================
local function ApplyWishVisuals(frame)
    if not frame or not frame.Icon then return end

    local data = GetFrameData(frame)
    if data.isUpdating then return end 

    SafeKillRedBorder(frame)

    local info = frame.cooldownInfo or (frame.GetCooldownInfo and frame:GetCooldownInfo())
    local spellID = info and (info.overrideSpellID or info.spellID)
    if not spellID then return end

    local inDesat = Tracker.desatSpellSet[spellID] and E.db.WishFlex.cdTracker.enableDesat
    local inRes = Tracker.resourceSpellSet[spellID] and E.db.WishFlex.cdTracker.enableResource

    if not inDesat and not inRes then
        -- 安全恢复状态防污染
        if data.wishModified then
            data.isUpdating = true
            if frame.Cooldown then frame.Cooldown:SetDrawSwipe(true) end
            if frame.Icon.SetDesaturation then frame.Icon:SetDesaturation(0) else frame.Icon:SetDesaturated(false) end
            frame.Icon:SetVertexColor(1, 1, 1)
            data.wishModified = false
            data.isUpdating = false
        end
        return 
    end

    data.wishModified = true
    local isActive = true
    
    -- 完全使用你原版的逻辑读取原生框架的颜色判定，杜绝 Taint
    if inDesat then
        local swipe = frame.cooldownSwipeColor
        if swipe and type(swipe) == "table" and swipe.GetRGBA then
            local ok, r = pcall(swipe.GetRGBA, swipe)
            if ok and r and not issecretvalue(r) then 
                isActive = (r ~= 0) 
            else 
                -- 修正：原版这里是 false，导致缺少颜色数据的法术（幽冥收割）一灰到底，现改为默认 true 放行
                isActive = true 
            end
        else
            -- 修正：同上，找不到 swipe 属性时默认不褪色
            isActive = true
        end
    end

    if isActive and inRes then
        local _, notEnoughPower = C_Spell.IsSpellUsable(spellID)
        if notEnoughPower then isActive = false end
    end

    data.isUpdating = true 
    if not isActive then
        -- 修正：用 SetDrawSwipe(false) 取代 SetAlpha(0)，保留倒计时文字
        if frame.Cooldown then frame.Cooldown:SetDrawSwipe(false) end
        if frame.Icon.SetDesaturation then frame.Icon:SetDesaturation(1) else frame.Icon:SetDesaturated(true) end
        frame.Icon:SetVertexColor(0.6, 0.6, 0.6)
    else
        if frame.Cooldown then frame.Cooldown:SetDrawSwipe(true) end
        if frame.Icon.SetDesaturation then frame.Icon:SetDesaturation(0) else frame.Icon:SetDesaturated(false) end
        frame.Icon:SetVertexColor(1, 1, 1)
    end
    data.isUpdating = false 
end

local function HookFrame(frame)
    local data = GetFrameData(frame)
    if not frame or data.wishHooked then return end
    data.wishHooked = true

    local function triggerUpdate() ApplyWishVisuals(frame) end
    if frame.Cooldown then
        hooksecurefunc(frame.Cooldown, "SetCooldown", triggerUpdate)
        hooksecurefunc(frame.Cooldown, "Clear", triggerUpdate)
        if frame.Cooldown.SetSwipeColor then hooksecurefunc(frame.Cooldown, "SetSwipeColor", triggerUpdate) end
    end
    if frame.Icon then
        if frame.Icon.SetDesaturated then hooksecurefunc(frame.Icon, "SetDesaturated", triggerUpdate) end
        if frame.Icon.SetDesaturation then hooksecurefunc(frame.Icon, "SetDesaturation", triggerUpdate) end
        if frame.Icon.SetVertexColor then hooksecurefunc(frame.Icon, "SetVertexColor", triggerUpdate) end
    end
    triggerUpdate()
end

-- =====================================================================
-- 5. 驱动引擎
-- =====================================================================
function Tracker:RefreshAll()
    local viewers = { _G.EssentialCooldownViewer, _G.UtilityCooldownViewer }
    for _, viewer in ipairs(viewers) do
        if viewer and viewer.itemFramePool then
            for frame in viewer.itemFramePool:EnumerateActive() do
                HookFrame(frame)
                ApplyWishVisuals(frame)
            end
        end
    end
end

function Tracker:Initialize()
    E:Delay(1, function()
        local db = E.db.WishFlex.cdTracker
        if db.isFirstInit then
            db.desatSpells[980] = true
            db.desatSpells[589] = true
            db.resourceSpells[124467] = true
            db.isFirstInit = false
        end

        InjectOptions()
        
        wipe(Tracker.desatSpellSet)
        wipe(Tracker.resourceSpellSet)
        if db.desatSpells then for id in pairs(db.desatSpells) do Tracker.desatSpellSet[id] = true end end
        if db.resourceSpells then for id in pairs(db.resourceSpells) do Tracker.resourceSpellSet[id] = true end end
        self:UpdateOptionsList()

        -- 恢复你最初安全的事件注册，删掉我乱加的 UNIT_AURA
        self:RegisterEvent("PLAYER_TARGET_CHANGED", "RefreshAll")
        
        local powerUpdatePending = false
        self:RegisterEvent("UNIT_POWER_UPDATE", function(_, unit)
            if unit == "player" and not powerUpdatePending then
                powerUpdatePending = true
                C_Timer.After(0.1, function() powerUpdatePending = false; Tracker:RefreshAll() end)
            end
        end)


        self:RefreshAll()
    end)
end

function Tracker:OnEnable()
end
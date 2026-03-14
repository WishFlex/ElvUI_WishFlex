local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule('Skins')
local LSM = E.Libs.LSM
local WUI = E:GetModule('WishFlex')
local mod = WUI:GetModule('CooldownCustom', true) or WUI:NewModule('CooldownCustom', 'AceHook-3.0', 'AceEvent-3.0')

local LCG = E.Libs and E.Libs.CustomGlow
if not LCG then LCG = LibStub and LibStub("LibCustomGlow-1.0", true) end

local DEFAULT_SWIPE_COLOR = {r = 0, g = 0, b = 0, a = 0.8}
local DEFAULT_ACTIVE_AURA_COLOR = {r = 1, g = 0.95, b = 0.57, a = 0.69}
local DEFAULT_CD_COLOR = {r = 1, g = 0.82, b = 0}
local DEFAULT_STACK_COLOR = {r = 1, g = 1, b = 1}

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.cooldownCustom = true
P["WishFlex"].cdManager = {
    swipeColor = DEFAULT_SWIPE_COLOR, activeAuraColor = DEFAULT_ACTIVE_AURA_COLOR, reverseSwipe = true,
    
    glowEnable = true, glowType = "pixel", glowUseCustomColor = false, glowColor = {r = 1, g = 1, b = 1, a = 1},
    glowPixelLines = 8, glowPixelFrequency = 0.25, glowPixelLength = 0, glowPixelThickness = 2, glowPixelXOffset = 0, glowPixelYOffset = 0,
    glowAutocastParticles = 4, glowAutocastFrequency = 0.2, glowAutocastScale = 1, glowAutocastXOffset = 0, glowAutocastYOffset = 0,
    glowButtonFrequency = 0, glowProcDuration = 1, glowProcXOffset = 0, glowProcYOffset = 0,

    Utility = { attachToPlayer = true, attachX = 0, attachY = 1, width = 45, height = 30, iconGap = 2, growth = "CENTER_HORIZONTAL", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0 },
    BuffBar = { width = 120, height = 30, iconGap = 2, growth = "DOWN", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0 },
    BuffIcon = { width = 45, height = 45, iconGap = 2, growth = "CENTER_HORIZONTAL", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0 }, 
    Essential = { enableCustomLayout = true, maxPerRow = 7, iconGap = 2, 
        row1Width = 45, row1Height = 45, row1CdFontSize = 18, row1CdFontColor = DEFAULT_CD_COLOR, row1CdPosition = "CENTER", row1CdXOffset = 0, row1CdYOffset = 0, row1StackFontSize = 14, row1StackFontColor = DEFAULT_STACK_COLOR, row1StackPosition = "BOTTOMRIGHT", row1StackXOffset = 0, row1StackYOffset = 0, 
        row2Width = 40, row2Height = 40, row2IconGap = 2, row2CdFontSize = 18, row2CdFontColor = DEFAULT_CD_COLOR, row2CdPosition = "CENTER", row2CdXOffset = 0, row2CdYOffset = 0, row2StackFontSize = 14, row2StackFontColor = DEFAULT_STACK_COLOR, row2StackPosition = "BOTTOMRIGHT", row2StackXOffset = 0, row2StackYOffset = 0 },
    countFont = "Expressway", countFontOutline = "OUTLINE", countFontColor = DEFAULT_STACK_COLOR,
}

-- =========================================
-- [排版引擎与节流控制] (核心改进：CDFlow引擎 + Diff状态快照)
-- =========================================
local BURST_THROTTLE      = 0.033
local WATCHDOG_THROTTLE   = 0.25
local BURST_TICKS         = 5
local IDLE_DISABLE_SEC    = 2.0

local layoutEngine        = CreateFrame("Frame")
local engineEnabled       = false
local layoutDirty         = true
local burstTicksRemaining = 0
local lastActivityTime    = 0
local nextUpdateTime      = 0
local lastLayoutHash      = ""

-- 安全的物理隐藏：直接扔到屏幕外，彻底脱离排版流
local function PhysicalHideFrame(frame)
    if not frame then return end
    frame:SetAlpha(0)
    if frame.Icon then frame.Icon:SetAlpha(0) end
    frame:EnableMouse(false)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", -5000, 0)
    frame._wishFlexHidden = true
end

-- 生成轻量级排版状态快照指纹 (用于阻断无效重绘)
local function GetLayoutStateHash()
    local hash = ""
    local viewers = {
        _G.UtilityCooldownViewer,
        _G.EssentialCooldownViewer,
        _G.BuffIconCooldownViewer,
        _G.BuffBarCooldownViewer
    }
    for _, viewer in ipairs(viewers) do
        if viewer and viewer.itemFramePool then
            local c = 0
            for f in viewer.itemFramePool:EnumerateActive() do
                if f:IsShown() then
                    local sid = (f.cooldownInfo and f.cooldownInfo.spellID) or 0
                    local idx = f.layoutIndex or 0
                    local hidden = f._wishFlexHidden and 1 or 0
                    -- 拼接格式: spellID:排序号:是否隐藏
                    hash = hash .. sid .. ":" .. idx .. ":" .. hidden .. "|"
                    c = c + 1
                end
            end
            hash = hash .. "C:" .. c .. "|"
        end
    end
    return hash
end

function mod:MarkLayoutDirty()
    layoutDirty = true
    burstTicksRemaining = BURST_TICKS
    lastActivityTime = GetTime()
    nextUpdateTime = 0
    if not engineEnabled then
        layoutEngine:SetScript("OnUpdate", mod.OnUpdateEngine)
        engineEnabled = true
    end
end

-- 兼容旧版调用的别名
function mod:TriggerLayout()
    self:MarkLayoutDirty()
end

function mod.OnUpdateEngine()
    local now = GetTime()
    local throttle = (layoutDirty or burstTicksRemaining > 0) and BURST_THROTTLE or WATCHDOG_THROTTLE
    if now < nextUpdateTime then return end
    nextUpdateTime = now + throttle

    if layoutDirty or burstTicksRemaining > 0 then
        mod:BuildHiddenCache()
        
        local currentHash = GetLayoutStateHash()
        
        -- 【性能分水岭】只有当布局被标记强制更新，或屏幕上的真实法术发生了改变，才执行重绘
        if currentHash ~= lastLayoutHash or layoutDirty then
            lastLayoutHash = currentHash
            mod:UpdateAllLayouts()
            mod:ForceBuffsLayout()
        end

        if burstTicksRemaining > 0 then
            burstTicksRemaining = burstTicksRemaining - 1
        elseif (now - lastActivityTime) >= IDLE_DISABLE_SEC then
            layoutEngine:SetScript("OnUpdate", nil)
            engineEnabled = false
        end
        layoutDirty = false
        lastActivityTime = now
    end
end

-- =========================================
-- [全局监控缓存系统]：精准拦截自定义法术
-- =========================================
mod.hiddenAuras = {}
local BaseSpellCache = {}

local function IsSafeValue(val) return val ~= nil and (type(issecretvalue) ~= "function" or not issecretvalue(val)) end

local function GetBaseSpellFast(spellID)
    if not IsSafeValue(spellID) then return nil end
    if BaseSpellCache[spellID] == nil then
        local base = spellID
        pcall(function() if C_Spell and C_Spell.GetBaseSpell then base = C_Spell.GetBaseSpell(spellID) or spellID end end)
        BaseSpellCache[spellID] = base
    end
    return BaseSpellCache[spellID]
end

function mod:BuildHiddenCache()
    wipe(self.hiddenAuras)
    local playerClass = select(2, UnitClass("player"))
    
    -- 【核心修复】：统一读取全局账号法术库 (E.global)
    local spellDB = E.global.WishFlex and E.global.WishFlex.spellDB
    if spellDB then
        for k, v in pairs(spellDB) do
            -- 检查 hideOriginal 标志 (默认为隐藏，除非明确设为 false)
            if type(v) == "table" and v.hideOriginal ~= false then
                -- 职业匹配：如果没有class字段、配置为ALL，或匹配当前职业
                if not v.class or v.class == "ALL" or v.class == playerClass then
                    local sid = tonumber(k)
                    local bid = v.buffID or sid
                    
                    if sid then self.hiddenAuras[sid] = true end
                    if bid then self.hiddenAuras[bid] = true end
                end
            end
        end
    end
end

local function ShouldHideFrame(info)
    if not info then return false end
    if IsSafeValue(info.spellID) then
        if mod.hiddenAuras[info.spellID] or mod.hiddenAuras[info.overrideSpellID] then return true end
        local baseID = GetBaseSpellFast(info.spellID)
        if baseID and mod.hiddenAuras[baseID] then return true end
    end
    if info.linkedSpellIDs then
        for i = 1, #info.linkedSpellIDs do
            local lid = info.linkedSpellIDs[i]
            if IsSafeValue(lid) and mod.hiddenAuras[lid] then return true end
        end
    end
    return false
end

-- =========================================
-- [排版与渲染核心]
-- =========================================
local function GetKeyFromFrame(frame)
    local parent = frame:GetParent()
    while parent do
        local name = parent:GetName() or ""
        if name:find("UtilityCooldownViewer") then return "Utility" end
        if name:find("BuffBarCooldownViewer") then return "BuffBar" end
        if name:find("BuffIconCooldownViewer") then return "BuffIcon" end
        if name:find("EssentialCooldownViewer") then return "Essential" end
        parent = parent:GetParent()
    end
    return nil
end

function mod.ApplyTexCoord(texture, width, height)
    if not texture or not texture.SetTexCoord then return end
    local ratio = width / height
    local offset = 0.08
    local left, right, top, bottom = offset, 1-offset, offset, 1-offset
    if ratio > 1 then
        local vH = (1 - 2*offset) / ratio; top, bottom = 0.5 - (vH/2), 0.5 + (vH/2)
    elseif ratio < 1 then
        local vW = (1 - 2*offset) * ratio; left, right = 0.5 - (vW/2), 0.5 + (vW/2)
    end
    texture:SetTexCoord(left, right, top, bottom)
end

local function SafeEquals(v, expected)
    return (type(v) ~= "number" or not (issecretvalue and issecretvalue(v))) and v == expected
end

local function SafeHide(self)
    if self:IsShown() then
        self:Hide()
        self:SetAlpha(0)
    end
end

local function SuppressDebuffBorder(f)
    if not f then return end
    if f._wishBorderSuppressed then return end
    f._wishBorderSuppressed = true
    
    local borders = { f.DebuffBorder, f.Border, f.IconBorder, f.IconOverlay, f.overlay, f.ExpireBorder, f.Icon and f.Icon.Border, f.Icon and f.Icon.IconBorder, f.Icon and f.Icon.DebuffBorder }
    for i = 1, #borders do
        local border = borders[i]
        if border then border:Hide(); border:SetAlpha(0); hooksecurefunc(border, "Show", SafeHide) end
    end

    if f.DebuffBorder and f.DebuffBorder.UpdateFromAuraData then hooksecurefunc(f.DebuffBorder, "UpdateFromAuraData", SafeHide) end

    for i = 1, select("#", f:GetRegions()) do
        local region = select(i, f:GetRegions())
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            if SafeEquals(region:GetAtlas(), "UI-HUD-CoolDownManager-IconOverlay") or SafeEquals(region:GetTexture(), 6707800) then
                region:SetAlpha(0); region:Hide(); hooksecurefunc(region, "Show", SafeHide)
            end
        end
    end

    if f.PandemicIcon then f.PandemicIcon:SetAlpha(0); f.PandemicIcon:Hide(); hooksecurefunc(f.PandemicIcon, "Show", SafeHide) end
    if type(f.ShowPandemicStateFrame) == "function" then hooksecurefunc(f, "ShowPandemicStateFrame", function(self) if self.PandemicIcon then self.PandemicIcon:Hide(); self.PandemicIcon:SetAlpha(0) end end) end
    
    if f.CooldownFlash then
        f.CooldownFlash:SetAlpha(0); f.CooldownFlash:Hide()
        hooksecurefunc(f.CooldownFlash, "Show", SafeHide)
        if f.CooldownFlash.FlashAnim and f.CooldownFlash.FlashAnim.Play then hooksecurefunc(f.CooldownFlash.FlashAnim, "Play", function(self) self:Stop(); f.CooldownFlash:Hide() end) end
    end
    if f.SpellActivationAlert then f.SpellActivationAlert:SetAlpha(0); f.SpellActivationAlert:Hide(); hooksecurefunc(f.SpellActivationAlert, "Show", SafeHide) end

    local bg = f.backdrop or f
    if bg and type(bg.SetBackdropBorderColor) == "function" then
        hooksecurefunc(bg, "SetBackdropBorderColor", function(self)
            if self._wishColorLock then return end
            local dr, dg, db = 0, 0, 0
            if E.media and E.media.bordercolor then dr, dg, db = unpack(E.media.bordercolor) end
            self._wishColorLock = true; self:SetBackdropBorderColor(dr, dg, db, 1); self._wishColorLock = false
        end)
        bg._wishColorLock = true
        local dr, dg, db = 0, 0, 0
        if E.media and E.media.bordercolor then dr, dg, db = unpack(E.media.bordercolor) end
        bg:SetBackdropBorderColor(dr, dg, db, 1)
        bg._wishColorLock = false
    end
end

local function WeldToMover(frame)
    if frame and frame.mover then
        if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return end
        frame:ClearAllPoints(); frame:SetPoint("CENTER", frame.mover, "CENTER")
    end
end

local function SafeMover(frame, moverName, title, defaultPoint)
    if not frame then return end
    if not frame:GetNumPoints() or frame:GetNumPoints() == 0 then frame:SetPoint(unpack(defaultPoint)) end
    if not frame.mover then E:CreateMover(frame, moverName, title, nil, nil, nil, "ALL,WishFlex") end
end

local textPositionValues = { ["TOP"] = "上", ["BOTTOM"] = "底", ["LEFT"] = "左", ["RIGHT"] = "右", ["CENTER"] = "居中", ["TOPLEFT"] = "左上", ["TOPRIGHT"] = "右上", ["BOTTOMLEFT"] = "左下", ["BOTTOMRIGHT"] = "右下" }

local function GetEssentialGroup(dbKey, tabName, order)
    return {
        order = order, type = "group", name = tabName,
        get = function(i) return E.db.WishFlex.cdManager[dbKey][i[#i]] end,
        set = function(i, v) E.db.WishFlex.cdManager[dbKey][i[#i]] = v; mod:TriggerLayout() end,
        args = {
            layoutStatus = { order = 1, type = "group", name = "第一行", guiInline = true, args = { enableCustomLayout = { order = 1, type = "toggle", name = "启用双行" }, maxPerRow = { order = 2, type = "range", name = "最大数", min = 1, max = 20, step = 1 }, iconGap = { order = 3, type = "range", name = "间距", min = 0, max = 20, step = 1 } } },
            row1Size = { order = 2, type = "group", name = "第一行尺寸", guiInline = true, args = { row1Width = { order=1, type="range", name="宽度", min=10, max=100, step=1 }, row1Height = { order=2, type="range", name="高度", min=10, max=100, step=1 } } },
            row1CdText = { order = 3, type = "group", name = "第一行 冷却倒计时", guiInline = true, args = { row1CdFontSize = {order=1,type="range",name="大小",min=4,max=40,step=1}, row1CdFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager.Essential.row1CdFontColor; return t and t.r or 1, t and t.g or 0.82, t and t.b or 0 end, set=function(_,r,g,b) E.db.WishFlex.cdManager.Essential.row1CdFontColor={r=r,g=g,b=b} end}, row1CdPosition = {order=3,type="select",name="基准位置",values=textPositionValues}, row1CdXOffset = {order=4,type="range",name="X微调",min=-50,max=50,step=1}, row1CdYOffset = {order=5,type="range",name="Y微调",min=-50,max=50,step=1} } },
            row1StackText = { order = 4, type = "group", name = "第一行 层数文本", guiInline = true, args = { row1StackFontSize = {order=1,type="range",name="大小",min=4,max=40,step=1}, row1StackFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager.Essential.row1StackFontColor; return t and t.r or 1, t and t.g or 1, t and t.b or 1 end, set=function(_,r,g,b) E.db.WishFlex.cdManager.Essential.row1StackFontColor={r=r,g=g,b=b} end}, row1StackPosition = {order=3,type="select",name="基准位置",values=textPositionValues}, row1StackXOffset = {order=4,type="range",name="X微调",min=-50,max=50,step=1}, row1StackYOffset = {order=5,type="range",name="Y微调",min=-50,max=50,step=1} } },
            row2Size = { order = 5, type = "group", name = "第二行尺寸", guiInline = true, args = { row2Width = { order=1, type="range", name="宽度", min=10, max=100, step=1 }, row2Height = { order=2, type="range", name="高度", min=10, max=100, step=1 }, row2IconGap = { order=3, type="range", name="间距", min=0, max=20, step = 1 } } },
            row2CdText = { order = 6, type = "group", name = "第二行 冷却倒计时", guiInline = true, args = { row2CdFontSize = {order=1,type="range",name="大小",min=4,max=40,step=1}, row2CdFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager.Essential.row2CdFontColor; return t and t.r or 1, t and t.g or 0.82, t and t.b or 0 end, set=function(_,r,g,b) E.db.WishFlex.cdManager.Essential.row2CdFontColor={r=r,g=g,b=b} end}, row2CdPosition = {order=3,type="select",name="基准位置",values=textPositionValues}, row2CdXOffset = {order=4,type="range",name="X微调",min=-50,max=50,step=1}, row2CdYOffset = {order=5,type="range",name="Y微调",min=-50,max=50,step=1} } },
            row2StackText = { order = 7, type = "group", name = "第二行 层数文本", guiInline = true, args = { row2StackFontSize = {order=1,type="range",name="大小",min=4,max=40,step=1}, row2StackFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager.Essential.row2StackFontColor; return t and t.r or 1, t and t.g or 1, t and t.b or 1 end, set=function(_,r,g,b) E.db.WishFlex.cdManager.Essential.row2StackFontColor={r=r,g=g,b=b} end}, row2StackPosition = {order=3,type="select",name="基准位置",values=textPositionValues}, row2StackXOffset = {order=4,type="range",name="X微调",min=-50,max=50,step=1}, row2StackYOffset = {order=5,type="range",name="Y微调",min=-50,max=50,step=1} } }
        }
    }
end

local function GetCDSubGroup(dbKey, tabName, order, isVertical)
    local growthValues = isVertical and { ["UP"] = "向上", ["DOWN"] = "向下" } or { ["LEFT"] = "向左", ["CENTER_HORIZONTAL"] = "水平居中展开", ["RIGHT"] = "向右" }
    return {
        order = order, type = "group", name = tabName, 
        get = function(i) return E.db.WishFlex.cdManager[dbKey][i[#i]] end,
        set = function(i, v) E.db.WishFlex.cdManager[dbKey][i[#i]] = v; mod:TriggerLayout() end,
        args = {
            layout = { order = 1, type = "group", name = "排版", guiInline = true, args = { growth = { order = 1, type = "select", name = "增长方向", values = growthValues }, iconGap = { order = 2, type = "range", name = "间距", min = 0, max = 20, step = 1 } } },
            sizeSet = { order = 2, type = "group", name = "图标宽高", guiInline = true, args = { width = {order=1,type="range",name="宽度",min=10,max=400,step=1}, height = {order=2,type="range",name="高度",min=10,max=100,step=1} } },
            cdText = { order = 3, type = "group", name = "冷却倒计时", guiInline = true, args = { cdFontSize = {order=1,type="range",name="大小",min=4,max=40,step=1}, cdFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager[dbKey].cdFontColor; return t and t.r or 1, t and t.g or 0.82, t and t.b or 0 end, set=function(_,r,g,b) E.db.WishFlex.cdManager[dbKey].cdFontColor={r=r,g=g,b=b} end}, cdPosition = {order=3,type="select",name="基准位置",values=textPositionValues}, cdXOffset = {order=4,type="range",name="X微调",min=-50,max=50,step=1}, cdYOffset = {order=5,type="range",name="Y微调",min=-50,max=50,step=1} } },
            stackText = { order = 4, type = "group", name = "层数文本", guiInline = true, args = { stackFontSize = {order=1,type="range",name="大小",min=4,max=40,step=1}, stackFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager[dbKey].stackFontColor; return t and t.r or 1, t and t.g or 1, t and t.b or 1 end, set=function(_,r,g,b) E.db.WishFlex.cdManager[dbKey].stackFontColor={r=r,g=g,b=b} end}, stackPosition = {order=3,type="select",name="基准位置",values=textPositionValues}, stackXOffset = {order=4,type="range",name="X微调",min=-50,max=50,step=1}, stackYOffset = {order=5,type="range",name="Y微调",min=-50,max=50,step=1} } },
        }
    }
end

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.cdmanager = WUI.OptionsArgs.cdmanager or { order = 20, type = "group", name = "|cff00e5cc冷却管理器|r", childGroups = "tab", args = {} }
    WUI.OptionsArgs.cdmanager.args = WUI.OptionsArgs.cdmanager.args or {}
    local args = WUI.OptionsArgs.cdmanager.args
    
    args.base = { 
        order = 1, type = "group", name = "全局与外观", 
        args = { 
            enable = { order = 1, type = "toggle", name = "启用", get = function() return E.db.WishFlex.modules.cooldownCustom end, set = function(_, v) E.db.WishFlex.modules.cooldownCustom = v; E:StaticPopup_Show("CONFIG_RL") end }, 
            countFont = { order = 2, type = "select", dialogControl = 'LSM30_Font', name = "全局字体", values = LSM:HashTable("font"), get = function() return E.db.WishFlex.cdManager.countFont end, set = function(_, v) E.db.WishFlex.cdManager.countFont = v; mod:TriggerLayout() end }, 
            countFontOutline = { order = 3, type = "select", name = "字体描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" }, get = function() return E.db.WishFlex.cdManager.countFontOutline end, set = function(_, v) E.db.WishFlex.cdManager.countFontOutline = v; mod:TriggerLayout() end }, 
            swipeColor = { order = 5, type = "color", name = "全局冷却遮罩颜色", hasAlpha = true, get = function() local t = E.db.WishFlex.cdManager.swipeColor or DEFAULT_SWIPE_COLOR return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) E.db.WishFlex.cdManager.swipeColor = {r=r,g=g,b=b,a=a}; mod:TriggerLayout() end },
            activeAuraColor = { order = 6, type = "color", name = "BUFF激活遮罩颜色", hasAlpha = true, get = function() local t = E.db.WishFlex.cdManager.activeAuraColor or DEFAULT_ACTIVE_AURA_COLOR return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) E.db.WishFlex.cdManager.activeAuraColor = {r=r,g=g,b=b,a=a}; mod:TriggerLayout() end },
            reverseSwipe = { order = 7, type = "toggle", name = "反向遮罩(亮变黑)", get = function() return E.db.WishFlex.cdManager.reverseSwipe end, set = function(_, v) E.db.WishFlex.cdManager.reverseSwipe = v; mod:TriggerLayout() end },
            
            glowGroup = {
                order = 10, type = "group", name = "重要技能高亮发光设置", guiInline = true,
                get = function(info) return E.db.WishFlex.cdManager[info[#info]] end,
                set = function(info, v) E.db.WishFlex.cdManager[info[#info]] = v; mod:TriggerLayout() end,
                args = {
                    glowEnable = { order = 1, type = "toggle", name = "启用高亮发光" },
                    glowType = { order = 2, type = "select", name = "发光类型", values = { pixel = "像素发光", autocast = "自动施法发光", button = "按钮发光", proc = "触发发光" } },
                    glowUseCustomColor = { order = 3, type = "toggle", name = "使用自定义颜色" },
                    glowColor = { order = 4, type = "color", name = "发光颜色", hasAlpha = true, 
                        get = function() local t = E.db.WishFlex.cdManager.glowColor; return t and t.r or 1, t and t.g or 1, t and t.b or 1, t and t.a or 1 end, 
                        set = function(_, r, g, b, a) E.db.WishFlex.cdManager.glowColor = {r=r,g=g,b=b,a=a}; mod:TriggerLayout() end,
                        disabled = function() return not E.db.WishFlex.cdManager.glowUseCustomColor end 
                    },
                    glowPixelLines = { order = 10, type = "range", name = "线条数", min = 1, max = 20, step = 1, hidden = function() return E.db.WishFlex.cdManager.glowType ~= "pixel" end },
                    glowPixelFrequency = { order = 11, type = "range", name = "频率", min = -2, max = 2, step = 0.05, hidden = function() return E.db.WishFlex.cdManager.glowType ~= "pixel" end },
                    glowPixelLength = { order = 12, type = "range", name = "长度(0为自动)", min = 0, max = 20, step = 1, hidden = function() return E.db.WishFlex.cdManager.glowType ~= "pixel" end },
                    glowPixelThickness = { order = 13, type = "range", name = "粗细", min = 1, max = 10, step = 1, hidden = function() return E.db.WishFlex.cdManager.glowType ~= "pixel" end },
                    glowPixelXOffset = { order = 14, type = "range", name = "X轴偏移", min = -20, max = 20, step = 1, hidden = function() return E.db.WishFlex.cdManager.glowType ~= "pixel" end },
                    glowPixelYOffset = { order = 15, type = "range", name = "Y轴偏移", min = -20, max = 20, step = 1, hidden = function() return E.db.WishFlex.cdManager.glowType ~= "pixel" end },
                    glowAutocastParticles = { order = 20, type = "range", name = "粒子数", min = 1, max = 16, step = 1, hidden = function() return E.db.WishFlex.cdManager.glowType ~= "autocast" end },
                    glowAutocastFrequency = { order = 21, type = "range", name = "频率", min = -2, max = 2, step = 0.05, hidden = function() return E.db.WishFlex.cdManager.glowType ~= "autocast" end },
                    glowAutocastScale = { order = 22, type = "range", name = "缩放", min = 0.5, max = 3, step = 0.05, hidden = function() return E.db.WishFlex.cdManager.glowType ~= "autocast" end },
                    glowAutocastXOffset = { order = 23, type = "range", name = "X轴偏移", min = -20, max = 20, step = 1, hidden = function() return E.db.WishFlex.cdManager.glowType ~= "autocast" end },
                    glowAutocastYOffset = { order = 24, type = "range", name = "Y轴偏移", min = -20, max = 20, step = 1, hidden = function() return E.db.WishFlex.cdManager.glowType ~= "autocast" end },
                    glowButtonFrequency = { order = 30, type = "range", name = "频率(0为默认)", min = 0, max = 2, step = 0.05, hidden = function() return E.db.WishFlex.cdManager.glowType ~= "button" end },
                    glowProcDuration = { order = 40, type = "range", name = "持续时间", min = 0.1, max = 5, step = 0.1, hidden = function() return E.db.WishFlex.cdManager.glowType ~= "proc" end },
                    glowProcXOffset = { order = 41, type = "range", name = "X轴偏移", min = -20, max = 20, step = 1, hidden = function() return E.db.WishFlex.cdManager.glowType ~= "proc" end },
                    glowProcYOffset = { order = 42, type = "range", name = "Y轴偏移", min = -20, max = 20, step = 1, hidden = function() return E.db.WishFlex.cdManager.glowType ~= "proc" end },
                }
            }
        } 
    }
    args.essential = GetEssentialGroup("Essential", "重要技能", 2)
    
    args.utility = GetCDSubGroup("Utility", "效能技能", 3, false)
    args.utility.args.layout.args.attachToPlayer = {
        order = 3, type = "toggle", name = "吸附玩家头像(右上)", desc = "勾选后将完美对齐到玩家框体的外部边界，消灭缝隙。",
        get = function() return E.db.WishFlex.cdManager.Utility.attachToPlayer end,
        set = function(_, v) E.db.WishFlex.cdManager.Utility.attachToPlayer = v; mod:TriggerLayout() end
    }
    args.utility.args.layout.args.attachX = {
        order = 4, type = "range", name = "吸附X偏移(像素)", min = -30, max = 30, step = 1, desc = "左右微调，目前使用了最精确的视觉边缘对齐，设为 0 即可齐平。",
        get = function() return E.db.WishFlex.cdManager.Utility.attachX or 0 end,
        set = function(_, v) E.db.WishFlex.cdManager.Utility.attachX = v; mod:TriggerLayout() end,
        disabled = function() return not E.db.WishFlex.cdManager.Utility.attachToPlayer end
    }
    args.utility.args.layout.args.attachY = {
        order = 5, type = "range", name = "吸附Y偏移(像素)", min = -30, max = 30, step = 1, desc = "上下微调间距。",
        get = function() return E.db.WishFlex.cdManager.Utility.attachY or 1 end,
        set = function(_, v) E.db.WishFlex.cdManager.Utility.attachY = v; mod:TriggerLayout() end,
        disabled = function() return not E.db.WishFlex.cdManager.Utility.attachToPlayer end
    }

    args.bufficon = GetCDSubGroup("BuffIcon", "增益图标", 4, false) 
    args.buffbar = GetCDSubGroup("BuffBar", "增益条", 5, true) 
end

local function SortByLayoutIndex(a, b) return (a.layoutIndex or 999) < (b.layoutIndex or 999) end

local function StaticUpdateSwipeColor(self)
    local b = self:GetParent()
    local cddb = E.db.WishFlex.cdManager
    if b and b.wasSetFromAura then
        local ac = cddb.activeAuraColor or DEFAULT_ACTIVE_AURA_COLOR
        self:SetSwipeColor(ac.r, ac.g, ac.b, ac.a)
    else
        local sc = cddb.swipeColor or DEFAULT_SWIPE_COLOR
        self:SetSwipeColor(sc.r, sc.g, sc.b, sc.a)
    end
end

function mod:ApplySwipeSettings(frame)
    if not frame or not frame.Cooldown then return end
    local db = E.db.WishFlex.cdManager
    local rev = db.reverseSwipe
    if rev == nil then rev = true end
    frame.Cooldown:SetReverse(rev)

    if not frame.Cooldown._wishSwipeHooked then
        hooksecurefunc(frame.Cooldown, "SetCooldown", StaticUpdateSwipeColor)
        if frame.Cooldown.SetCooldownFromDurationObject then hooksecurefunc(frame.Cooldown, "SetCooldownFromDurationObject", StaticUpdateSwipeColor) end
        frame.Cooldown._wishSwipeHooked = true
    end

    if frame.wasSetFromAura then
        local ac = db.activeAuraColor or DEFAULT_ACTIVE_AURA_COLOR
        frame.Cooldown:SetSwipeColor(ac.r, ac.g, ac.b, ac.a)
    else
        local sc = db.swipeColor or DEFAULT_SWIPE_COLOR
        frame.Cooldown:SetSwipeColor(sc.r, sc.g, sc.b, sc.a)
    end
end

local function FormatText(t, isStack, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, frame)
    if not t or type(t) ~= "table" or not t.SetFont then return end
    local size = isStack and stackSize or cdSize
    local color = isStack and stackColor or cdColor
    local pos = isStack and stackPos or cdPos or "CENTER"
    local ox = isStack and stackX or cdX or 0
    local oy = isStack and stackY or cdY or 0
    
    if t.FontTemplate then t:FontTemplate(fontPath, size, outline) else t:SetFont(fontPath, size, outline) end
    t:SetTextColor(color.r, color.g, color.b); t:ClearAllPoints()
    t:SetPoint(pos, frame.Icon or frame, pos, ox, oy); t:SetDrawLayer("OVERLAY", 7)
end

function mod:ApplyText(frame, category, rowIndex)
    local db = E.db.WishFlex.cdManager
    local cfg = db[category]
    if not cfg then return end
    local fontPath = LSM:Fetch('font', db.countFont or "Expressway")
    local outline = db.countFontOutline or "OUTLINE"
    local cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY

    if category == "Essential" then
        if rowIndex == 2 then 
            cdSize, cdColor, cdPos, cdX, cdY = cfg.row2CdFontSize, cfg.row2CdFontColor, cfg.row2CdPosition or "CENTER", cfg.row2CdXOffset or 0, cfg.row2CdYOffset or 0
            stackSize, stackColor, stackPos, stackX, stackY = cfg.row2StackFontSize, cfg.row2StackFontColor, cfg.row2StackPosition or "BOTTOMRIGHT", cfg.row2StackXOffset or 0, cfg.row2StackYOffset or 0
        else 
            cdSize, cdColor, cdPos, cdX, cdY = cfg.row1CdFontSize, cfg.row1CdFontColor, cfg.row1CdPosition or "CENTER", cfg.row1CdXOffset or 0, cfg.row1CdYOffset or 0
            stackSize, stackColor, stackPos, stackX, stackY = cfg.row1StackFontSize, cfg.row1StackFontColor, cfg.row1StackPosition or "BOTTOMRIGHT", cfg.row1StackXOffset or 0, cfg.row1StackYOffset or 0
        end
    else
        cdSize, cdColor, cdPos, cdX, cdY = cfg.cdFontSize, cfg.cdFontColor, cfg.cdPosition or "CENTER", cfg.cdXOffset or 0, cfg.cdYOffset or 0
        stackSize, stackColor, stackPos, stackX, stackY = cfg.stackFontSize, cfg.stackFontColor, cfg.stackPosition or "BOTTOMRIGHT", cfg.stackXOffset or 0, cfg.stackYOffset or 0
    end

    local stackText = (frame.Applications and frame.Applications.Applications) or (frame.ChargeCount and frame.ChargeCount.Current) or frame.Count
    if frame.Cooldown then
        if frame.Cooldown.timer and frame.Cooldown.timer.text then FormatText(frame.Cooldown.timer.text, false, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, frame) end
        for k = 1, select("#", frame.Cooldown:GetRegions()) do 
            local region = select(k, frame.Cooldown:GetRegions())
            if region and region.IsObjectType and region:IsObjectType("FontString") then 
                FormatText(region, false, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, frame) 
            end 
        end
    end
    FormatText(stackText, true, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, frame)
end

function mod:ImmediateStyleFrame(frame, category)
    if not frame then return end
    
    if (category == "BuffIcon" or category == "BuffBar") and ShouldHideFrame(frame.cooldownInfo) then
        PhysicalHideFrame(frame)
        return 
    end

    if frame._wishFlexHidden then
        frame._wishFlexHidden = false
        frame:SetAlpha(1)
        if frame.Icon then frame.Icon:SetAlpha(1) end
        frame:EnableMouse(true)
    end

    SuppressDebuffBorder(frame)
    self:ApplyText(frame, category, 1)
    self:ApplySwipeSettings(frame)

    local db = E.db.WishFlex.cdManager
    local cfg = db[category]
    if cfg then
        local w = cfg.width or cfg.row1Width or 45
        local h = cfg.height or cfg.row1Height or 45

        frame:SetSize(w, h)
        if frame.Icon then
            local iconObj = frame.Icon.Icon or frame.Icon
            mod.ApplyTexCoord(iconObj, w, h)
            if frame.Bar then
                frame.Icon:SetSize(h, h)
                local gap = cfg.iconGap or 2
                frame.Bar:SetSize(w - h - gap, h)
                frame.Bar:ClearAllPoints()
                frame.Bar:SetPoint("LEFT", frame.Icon, "RIGHT", gap, 0)
            end
        end
    end
end

local cachedIcons = {}
local cachedFrames = {}
local cachedR1 = {}
local cachedR2 = {}

local function DoLayoutBuffs(viewerName, key, isVertical)
    local db = E.db.WishFlex.cdManager
    local container = _G[viewerName]
    if not container or not container:IsShown() then return end
    
    WeldToMover(container)
    table.wipe(cachedIcons)
    local count = 0
    
    if container.itemFramePool then 
        for f in container.itemFramePool:EnumerateActive() do 
            if f:IsShown() then 
                if ShouldHideFrame(f.cooldownInfo) then
                    PhysicalHideFrame(f)
                else
                    if f._wishFlexHidden then
                        f._wishFlexHidden = false
                        f:SetAlpha(1)
                        if f.Icon then f.Icon:SetAlpha(1) end
                        f:EnableMouse(true)
                    end
                    
                    count = count + 1
                    cachedIcons[count] = f
                    SuppressDebuffBorder(f); mod:ApplyText(f, key); mod:ApplySwipeSettings(f)
                end
            end 
        end 
    end 
    if count == 0 then return end
    
    table.sort(cachedIcons, SortByLayoutIndex)
    
    local cfg = db[key]
    local w, h, gap = cfg.width or 45, cfg.height or 45, cfg.iconGap or 2
    local growth = cfg.growth or (isVertical and "DOWN" or "CENTER_HORIZONTAL")

    local totalW = (count * w) + math.max(0, (count - 1) * gap)
    local totalH = (count * h) + math.max(0, (count - 1) * gap)
    
    container:SetSize(math.max(1, isVertical and w or totalW), math.max(1, isVertical and totalH or h))
    if container.mover then container.mover:SetSize(container:GetSize()) end

    if isVertical then
        local startY = (totalH / 2) - (h / 2)
        for i = 1, count do
            local f = cachedIcons[i]
            f:ClearAllPoints()
            f:SetSize(w, h)
            
            if growth == "UP" then
                f:SetPoint("CENTER", container, "CENTER", 0, -startY + (i - 1) * (h + gap))
            else
                f:SetPoint("CENTER", container, "CENTER", 0, startY - (i - 1) * (h + gap))
            end

            if f.Icon then
                local iconObj = f.Icon.Icon or f.Icon
                if not f.Bar then
                    f.Icon:SetSize(w, h); mod.ApplyTexCoord(iconObj, w, h)
                else
                    f.Icon:SetSize(h, h); f.Bar:SetSize(w - h - gap, h)
                    f.Bar:ClearAllPoints(); f.Bar:SetPoint("LEFT", f.Icon, "RIGHT", gap, 0)
                    if iconObj then mod.ApplyTexCoord(iconObj, h, h) end
                end
            end
        end
    else
        local startX = -(totalW / 2) + (w / 2)
        for i = 1, count do
            local f = cachedIcons[i]
            f:ClearAllPoints()
            f:SetSize(w, h)
            
            if growth == "LEFT" then
                f:SetPoint("CENTER", container, "CENTER", -startX - (i - 1) * (w + gap), 0)
            elseif growth == "RIGHT" then
                f:SetPoint("CENTER", container, "CENTER", startX + (i - 1) * (w + gap), 0)
            else
                f:SetPoint("CENTER", container, "CENTER", startX + (i - 1) * (w + gap), 0)
            end

            if f.Icon then
                local iconObj = f.Icon.Icon or f.Icon
                if not f.Bar then
                    f.Icon:SetSize(w, h); mod.ApplyTexCoord(iconObj, w, h)
                else
                    f.Icon:SetSize(h, h); f.Bar:SetSize(w - h - gap, h)
                    f.Bar:ClearAllPoints(); f.Bar:SetPoint("LEFT", f.Icon, "RIGHT", gap, 0)
                    if iconObj then mod.ApplyTexCoord(iconObj, h, h) end
                end
            end
        end
    end
end

function mod:ForceBuffsLayout()
    DoLayoutBuffs("BuffIconCooldownViewer", "BuffIcon", false)
    DoLayoutBuffs("BuffBarCooldownViewer", "BuffBar", true)
end

function mod:UpdateAllLayouts()
    local db = E.db.WishFlex.cdManager
    local function LayoutViewer(viewer, cfg, cat)
        if not viewer or not viewer.itemFramePool then return end
        
        local attachToPlayer = (cat == "Utility" and cfg.attachToPlayer)
        if not attachToPlayer then WeldToMover(viewer) end
        
        table.wipe(cachedFrames)
        local count = 0
        for f in viewer.itemFramePool:EnumerateActive() do 
            if f:IsShown() then 
                if f._wishFlexHidden then
                    f._wishFlexHidden = false
                    f:SetAlpha(1)
                    if f.Icon then f.Icon:SetAlpha(1) end
                    f:EnableMouse(true)
                end
                
                count = count + 1
                cachedFrames[count] = f 
                SuppressDebuffBorder(f); self:ApplyText(f, cat); self:ApplySwipeSettings(f)
            end 
        end
        if count == 0 then return end
        
        table.sort(cachedFrames, SortByLayoutIndex)
        local w, h, gap = cfg.width or 45, cfg.height or 30, cfg.iconGap or 2
        local growth = attachToPlayer and "LEFT" or (cfg.growth or "CENTER_HORIZONTAL") 
        local totalW = (count * w) + math.max(0, (count - 1) * gap)

        viewer:SetSize(math.max(1, totalW), math.max(1, h))
        if viewer.mover then viewer.mover:SetSize(viewer:GetSize()) end

        if attachToPlayer and _G.ElvUF_Player then
            viewer:ClearAllPoints()
            local ax = cfg.attachX or 0
            local ay = cfg.attachY or 1
            local anchorFrame = _G.ElvUF_Player.backdrop or _G.ElvUF_Player
            viewer:Point("BOTTOMRIGHT", anchorFrame, "TOPRIGHT", ax, ay)
            
            for i = 1, count do
                local f = cachedFrames[i]
                f:ClearAllPoints()
                f:SetSize(w, h)
                f:SetPoint("RIGHT", viewer, "RIGHT", -((i - 1) * (w + gap)), 0)
                if f.Icon then mod.ApplyTexCoord(f.Icon.Icon or f.Icon, w, h) end
            end
        else
            local startX = -(totalW / 2) + (w / 2)
            for i = 1, count do
                local f = cachedFrames[i]
                f:ClearAllPoints()
                f:SetSize(w, h)
                if growth == "LEFT" then
                    f:SetPoint("CENTER", viewer, "CENTER", -startX - (i - 1) * (w + gap), 0)
                elseif growth == "RIGHT" then
                    f:SetPoint("CENTER", viewer, "CENTER", startX + (i - 1) * (w + gap), 0)
                else
                    f:SetPoint("CENTER", viewer, "CENTER", startX + (i - 1) * (w + gap), 0)
                end
                if f.Icon then mod.ApplyTexCoord(f.Icon.Icon or f.Icon, w, h) end
            end
        end
    end
    
    LayoutViewer(_G.UtilityCooldownViewer, db.Utility, "Utility")

    local eViewer = _G.EssentialCooldownViewer
    if eViewer and eViewer.itemFramePool then
        WeldToMover(eViewer)
        table.wipe(cachedFrames)
        local count = 0
        for f in eViewer.itemFramePool:EnumerateActive() do 
            if f:IsShown() then 
                if f._wishFlexHidden then
                    f._wishFlexHidden = false
                    f:SetAlpha(1)
                    if f.Icon then f.Icon:SetAlpha(1) end
                    f:EnableMouse(true)
                end
                count = count + 1; cachedFrames[count] = f 
            end 
        end
        
        if count > 0 then
            table.sort(cachedFrames, SortByLayoutIndex)
            local cfgE = db.Essential
            if cfgE.enableCustomLayout then
                table.wipe(cachedR1); table.wipe(cachedR2)
                local r1c, r2c = 0, 0
                for i = 1, count do 
                    local f = cachedFrames[i]
                    if i <= cfgE.maxPerRow then r1c = r1c + 1; cachedR1[r1c] = f else r2c = r2c + 1; cachedR2[r2c] = f end 
                end

                local w1, h1, gap = cfgE.row1Width, cfgE.row1Height, cfgE.iconGap
                local totalW1 = (r1c * w1) + math.max(0, (r1c - 1) * gap)
                local startX1 = -(totalW1 / 2) + (w1 / 2)
                
                eViewer:SetSize(math.max(1, totalW1), math.max(1, h1))
                if eViewer.mover then eViewer.mover:SetSize(eViewer:GetSize()) end

                for i = 1, r1c do
                    local f = cachedR1[i]
                    f:ClearAllPoints()
                    f:SetPoint("CENTER", eViewer, "CENTER", startX1 + (i - 1) * (w1 + gap), 0)
                    f:SetSize(w1, h1)
                    if f.Icon then mod.ApplyTexCoord(f.Icon.Icon or f.Icon, w1, h1) end
                    SuppressDebuffBorder(f); self:ApplyText(f, "Essential", 1); self:ApplySwipeSettings(f)
                end

                if not _G.WishFlex_CooldownRow2_Anchor then _G.WishFlex_CooldownRow2_Anchor = CreateFrame("Frame", "WishFlex_CooldownRow2_Anchor", E.UIParent) end
                WeldToMover(_G.WishFlex_CooldownRow2_Anchor)
                
                local w2, h2, gap2 = cfgE.row2Width, cfgE.row2Height, cfgE.row2IconGap or 2
                local totalW2 = (r2c * w2) + math.max(0, (r2c - 1) * gap2)
                local startX2 = -(totalW2 / 2) + (w2 / 2)
                
                _G.WishFlex_CooldownRow2_Anchor:SetSize(math.max(1, totalW2), math.max(1, h2))
                if _G.WishFlex_CooldownRow2_Anchor.mover then _G.WishFlex_CooldownRow2_Anchor.mover:SetSize(_G.WishFlex_CooldownRow2_Anchor:GetSize()) end

                for i = 1, r2c do
                    local f = cachedR2[i]
                    f:ClearAllPoints()
                    f:SetPoint("CENTER", _G.WishFlex_CooldownRow2_Anchor, "CENTER", startX2 + (i - 1) * (w2 + gap2), 0)
                    f:SetSize(w2, h2)
                    if f.Icon then mod.ApplyTexCoord(f.Icon.Icon or f.Icon, w2, h2) end
                    
                    SuppressDebuffBorder(f); self:ApplyText(f, "Essential", 2); self:ApplySwipeSettings(f)
                end
            end
        end
    end
end

function mod:Initialize()
    InjectOptions(); if not E.db.WishFlex.modules.cooldownCustom then return end
    
    if not _G.WishFlex_CooldownRow2_Anchor then _G.WishFlex_CooldownRow2_Anchor = CreateFrame("Frame", "WishFlex_CooldownRow2_Anchor", E.UIParent) end
    
    SafeMover(_G.UtilityCooldownViewer, "WishFlexUtilityMover", "WishFlex: 效能技能", {"CENTER", E.UIParent, "CENTER", 0, -100})
    SafeMover(_G.EssentialCooldownViewer, "WishFlexEssentialMover", "WishFlex: 重要技能(第一行)", {"CENTER", E.UIParent, "CENTER", 0, 50})
    SafeMover(_G.WishFlex_CooldownRow2_Anchor, "WishFlexEssentialRow2Mover", "WishFlex: 重要技能(第二行)", {"TOP", _G.EssentialCooldownViewer, "BOTTOM", 0, -2})
    SafeMover(_G.BuffIconCooldownViewer, "WishFlexBuffIconMover", "WishFlex: 增益图标", {"BOTTOM", _G.EssentialCooldownViewer, "TOP", 0, 30})
    SafeMover(_G.BuffBarCooldownViewer, "WishFlexBuffBarMover", "WishFlex: 增益条", {"CENTER", E.UIParent, "CENTER", 0, 100})

    local isHookingGlow = false
    if LCG then
        local function ApplyCustomGlow(frame, drawLayer)
            local cfg = E.db.WishFlex.cdManager
            if not cfg.glowEnable then return end
            
            local c = cfg.glowColor or {r=1, g=1, b=1, a=1}
            local colorArr = cfg.glowUseCustomColor and {c.r, c.g, c.b, c.a} or nil
            local t = cfg.glowType or "pixel"
            
            if t == "pixel" then
                local len = cfg.glowPixelLength; if len == 0 then len = nil end
                LCG.PixelGlow_Start(frame, colorArr, cfg.glowPixelLines, cfg.glowPixelFrequency, len, cfg.glowPixelThickness, cfg.glowPixelXOffset, cfg.glowPixelYOffset, false, "WishEssentialGlow", drawLayer)
            elseif t == "autocast" then
                LCG.AutoCastGlow_Start(frame, colorArr, cfg.glowAutocastParticles, cfg.glowAutocastFrequency, cfg.glowAutocastScale, cfg.glowAutocastXOffset, cfg.glowAutocastYOffset, "WishEssentialGlow", drawLayer)
            elseif t == "button" then
                local freq = cfg.glowButtonFrequency; if freq == 0 then freq = nil end
                LCG.ButtonGlow_Start(frame, colorArr, freq)
            elseif t == "proc" then
                LCG.ProcGlow_Start(frame, {color = colorArr, duration = cfg.glowProcDuration, xOffset = cfg.glowProcXOffset, yOffset = cfg.glowProcYOffset, key = "WishEssentialGlow", frameLevel = drawLayer})
            end
        end

        hooksecurefunc(LCG, "PixelGlow_Start", function(frame, color, lines, frequency, length, thickness, xOffset, yOffset, drawLayer, key)
            if isHookingGlow or not frame or key == "WishEssentialGlow" then return end
            if GetKeyFromFrame(frame) == "Essential" then
                isHookingGlow = true
                LCG.PixelGlow_Stop(frame, key)
                ApplyCustomGlow(frame, drawLayer)
                isHookingGlow = false
            end
        end)

        hooksecurefunc(LCG, "PixelGlow_Stop", function(frame, key)
            if isHookingGlow or key == "WishEssentialGlow" or not frame then return end
            if GetKeyFromFrame(frame) == "Essential" then
                isHookingGlow = true
                LCG.PixelGlow_Stop(frame, "WishEssentialGlow")
                LCG.AutoCastGlow_Stop(frame, "WishEssentialGlow")
                LCG.ButtonGlow_Stop(frame)
                LCG.ProcGlow_Stop(frame, "WishEssentialGlow")
                isHookingGlow = false
            end
        end)
    end

    local function EventTrigger() mod:MarkLayoutDirty() end

    local mixins = {
        {"BuffIcon", _G.CooldownViewerBuffIconItemMixin},
        {"Essential", _G.CooldownViewerEssentialItemMixin},
        {"Utility", _G.CooldownViewerUtilityItemMixin},
        {"BuffBar", _G.CooldownViewerBuffBarItemMixin}
    }
    
    for _, data in ipairs(mixins) do
        local cat, mixin = data[1], data[2]
        if mixin then
            if mixin.OnCooldownIDSet then hooksecurefunc(mixin, "OnCooldownIDSet", function(frame) mod:ImmediateStyleFrame(frame, cat); EventTrigger() end) end
            if mixin.OnActiveStateChanged then hooksecurefunc(mixin, "OnActiveStateChanged", function(frame) mod:ImmediateStyleFrame(frame, cat); EventTrigger() end) end
        end
    end

    local viewers = {
        EssentialCooldownViewer = "Essential",
        UtilityCooldownViewer = "Utility",
        BuffIconCooldownViewer = "BuffIcon",
        BuffBarCooldownViewer = "BuffBar"
    }
    for vName, cat in pairs(viewers) do
        local v = _G[vName]
        if v then
            if v.OnAcquireItemFrame then hooksecurefunc(v, "OnAcquireItemFrame", function(_, frame) mod:ImmediateStyleFrame(frame, cat); EventTrigger() end) end
            if v.Layout then hooksecurefunc(v, "Layout", EventTrigger) end
            if v.UpdateLayout then hooksecurefunc(v, "UpdateLayout", EventTrigger) end
        end
    end

    -- 【新增】挂钩 ElvUI 配置切换事件，保证排版配置和隐藏列表随时刷新
    hooksecurefunc(E, "UpdateAll", function()
        mod:TriggerLayout()
    end)

    self:TriggerLayout()
end
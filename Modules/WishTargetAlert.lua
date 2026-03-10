local E, L, V, P, G = unpack(ElvUI)
local LSM = E.Libs.LSM
local WUI = E:GetModule('WishFlex')
local mod = WUI:NewModule('WishTargetAlert')

-- ==========================================
-- 1. 默认设置与数据库补全
-- ==========================================
P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.targetAlert = true

local ALERT_DEFAULTS = {
    enable = false, sizeW = 60, sizeH = 60,
    font = "Expressway", fontSize = 24, fontOutline = "OUTLINE",
    fontColor = { r = 1, g = 1, b = 1 }, offsetX = 0, offsetY = 0,
    useGlow = true, glowColor = { r = 1, g = 0, b = 0, a = 1 },
    glowLines = 8, glowFreq = 0.25, glowThick = 2,
    growDirection = "CENTER", iconGap = 4, 
}

local function GetDB()
    if not E.private.WishFlex then E.private.WishFlex = {} end
    if type(E.private.WishFlex.targetAlert) ~= "table" then E.private.WishFlex.targetAlert = {} end
    local db = E.private.WishFlex.targetAlert
    
    db.sound = nil
    db.customSound = nil
    
    for k, v in pairs(ALERT_DEFAULTS) do if db[k] == nil then db[k] = v end end
    return db
end

-- ==========================================
-- 2. 视觉防变形裁切与字体安全获取
-- ==========================================
local function ApplyTexCoord(texture, width, height)
    if not texture then return end
    local ratio = (width or 60) / (height or 60)
    local offset = 0.08
    local left, right, top, bottom = offset, 1-offset, offset, 1-offset
    if ratio > 1 then 
        local vH = (1 - 2*offset) / ratio; top, bottom = 0.5 - (vH/2), 0.5 + (vH/2)
    elseif ratio < 1 then 
        local vW = (1 - 2*offset) * ratio; left, right = 0.5 - (vW/2), 0.5 + (vW/2) 
    end
    texture:SetTexCoord(left, right, top, bottom)
end

local function GetSafeFont()
    local db = GetDB()
    local fontPath = db.font and LSM:Fetch("font", db.font)
    if not fontPath or fontPath == "" then
        fontPath = (E.media and E.media.normFont) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    end
    return fontPath
end

-- ==========================================
-- 3. 设置菜单注入 
-- ==========================================
function mod:InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.widgets = WUI.OptionsArgs.widgets or { order = 21, type = "group", name = "|cff00e5cc小工具|r", childGroups = "tab", args = {} }
    
    WUI.OptionsArgs.widgets.args.targetAlert = {
        order = 35, type = "group", name = "点名提醒",
        get = function(info) return GetDB()[info[#info]] end,
        set = function(info, v) GetDB()[info[#info]] = v; if mod.anchor then mod:UpdateLayout() end end,
        args = {
            enable = { order = 1, type = "toggle", name = "|cff00ff00当前角色启用|r", set = function(_, v) GetDB().enable = v; E:StaticPopup_Show("CONFIG_RL") end },
            sizeGroup = { order = 5, type = "group", name = "图标规格", guiInline = true, args = { sizeW = { order = 1, type = "range", name = "宽度", min = 20, max = 300, step = 1 }, sizeH = { order = 2, type = "range", name = "高度", min = 20, max = 300, step = 1 } } },
            
            growGroup = { order = 6, type = "group", name = "图标排列展开 (多目标同时施法时)", guiInline = true, args = { 
                growDirection = { order = 1, type = "select", name = "展开方向", values = { ["LEFT"] = "向左排列", ["CENTER"] = "居中横向", ["RIGHT"] = "向右排列", ["UP"] = "向上堆叠", ["DOWN"] = "向下堆叠" } },
                iconGap = { order = 2, type = "range", name = "图标间距", min = 0, max = 50, step = 1 }
            } },
            
            glowGroup = { order = 8, type = "group", name = "走马灯特效", guiInline = true, args = { 
                useGlow = { order = 1, type = "toggle", name = "启用" }, 
                glowColor = { order = 2, type = "color", hasAlpha = true, name = "边框颜色", get = function() local t = GetDB().glowColor return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) GetDB().glowColor = {r=r,g=g,b=b,a=a}; mod:UpdateLayout() end }, 
                glowLines = { order = 3, type = "range", name = "线条数", min = 1, max = 20, step = 1 }, 
                glowFreq = { order = 4, type = "range", name = "速度", min = 0.05, max = 2, step = 0.05 } 
            } },
            
            fontGroup = { order = 10, type = "group", name = "文字排版", guiInline = true, args = { font = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") }, fontSize = { order = 2, type = "range", name = "大小", min = 8, max = 120, step = 1 }, fontOutline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } }, fontColor = { order = 4, type = "color", name = "颜色", get = function() local t = GetDB().fontColor return t.r, t.g, t.b end, set = function(_, r, g, b) GetDB().fontColor = {r=r,g=g,b=b}; mod:UpdateLayout() end }, offsetX = { order = 5, type = "range", name = "X偏移", min = -150, max = 150, step = 1 }, offsetY = { order = 6, type = "range", name = "Y偏移", min = -150, max = 150, step = 1 } } },
            preview = { order = 20, type = "execute", name = "测试多目标动画", func = function() if WishFlexTargetAlertEngine then WishFlexTargetAlertEngine:Preview() end end }
        }
    }
end

-- ==========================================
-- 4. 事件引擎挂载
-- ==========================================
WishFlexTargetAlertEngine = CreateFrame("Frame", "WishFlexTargetAlertEngine", UIParent)
local Engine = WishFlexTargetAlertEngine
Engine.pool = {}

Engine:RegisterEvent("UNIT_SPELLCAST_START")
Engine:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
Engine:RegisterEvent("UNIT_SPELLCAST_STOP")
Engine:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
Engine:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
Engine:RegisterEvent("UNIT_SPELLCAST_FAILED")
Engine:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
Engine:RegisterEvent("NAME_PLATE_UNIT_ADDED")
Engine:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

-- ==========================================
-- 5. 锚点与池化框架管理
-- ==========================================
function mod:UpdateLayout()
    if not self.anchor then return end
    local db = GetDB()
    self.anchor:SetSize(db.sizeW, db.sizeH)
    
    for unit, f in pairs(Engine.pool) do
        f:SetSize(db.sizeW, db.sizeH)
        ApplyTexCoord(f.Icon, db.sizeW, db.sizeH)
        
        local fontPath = GetSafeFont()
        f.Time:SetFont(fontPath, db.fontSize, db.fontOutline)
        f.Time:SetTextColor(db.fontColor.r, db.fontColor.g, db.fontColor.b)
        f.Time:ClearAllPoints()
        f.Time:SetPoint("CENTER", f, "CENTER", db.offsetX, db.offsetY)
        
        local LCG = E.Libs.CustomGlow
        if LCG and not f.isFailed then
            LCG.PixelGlow_Stop(f)
            if db.useGlow then 
                local c = db.glowColor
                LCG.PixelGlow_Start(f, {c.r, c.g, c.b, c.a}, db.glowLines, db.glowFreq, 8, db.glowThick, 0, 0, false, "WishTargetAlertGlow_"..unit)
            end
        end
    end
    Engine:UpdatePositions()
end

function mod:CreateAlertAnchor()
    if self.anchor then return end
    self.anchor = CreateFrame("Frame", "WishTargetAlertAnchor", E.UIParent)
    self.anchor:SetPoint("CENTER", E.UIParent, "CENTER", 0, 250)
    self.anchor:SetSize(GetDB().sizeW, GetDB().sizeH)
    E:CreateMover(self.anchor, "WishTargetAlertMover", "WishFlex: 点名提醒阵列", nil, nil, nil, "ALL,WishFlex", nil, "WishFlex,targetalert")
end

local function GetAlertFrame(unit)
    if not mod.anchor then mod:CreateAlertAnchor() end
    if not Engine.pool[unit] then
        local f = CreateFrame("Frame", "WishTargetAlert_"..unit, mod.anchor)
        f:SetFrameStrata("HIGH")
        
        f.Icon = f:CreateTexture(nil, "ARTWORK")
        f.Icon:SetAllPoints()
        
        f.Time = f:CreateFontString(nil, "OVERLAY", nil, 7)
        
        local baseFont = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        f.Time:SetFont(baseFont, 24, "OUTLINE")
        
        Engine.pool[unit] = f
        mod:UpdateLayout()
    end
    return Engine.pool[unit]
end

-- ==========================================
-- 6. 核心逻辑：安全执行与防干扰
-- ==========================================
function Engine:UpdatePositions()
    local active = {}
    for unit, f in pairs(self.pool) do
        if f:IsShown() then table.insert(active, f) end
    end
    if #active == 0 then return end

    table.sort(active, function(a, b) return (a.creationTime or 0) < (b.creationTime or 0) end)

    local db = GetDB()
    local w, h = db.sizeW or 60, db.sizeH or 60
    local gap = db.iconGap or 4
    local dir = db.growDirection or "CENTER"
    local totalW = (#active * w) + (#active - 1) * gap
    
    for i, f in ipairs(active) do
        f:ClearAllPoints()
        local xOffset, yOffset = 0, 0
        if dir == "CENTER" then xOffset = -totalW / 2 + w / 2 + (i - 1) * (w + gap)
        elseif dir == "RIGHT" then xOffset = (i - 1) * (w + gap)
        elseif dir == "LEFT" then xOffset = -(i - 1) * (w + gap)
        elseif dir == "UP" then yOffset = (i - 1) * (h + gap)
        elseif dir == "DOWN" then yOffset = -(i - 1) * (h + gap)
        end
        f:SetPoint("CENTER", mod.anchor, "CENTER", xOffset, yOffset)
    end
end

local function StopUI(unit)
    if unit == "ALL" then
        for u, f in pairs(Engine.pool) do 
            f:Hide()
            f.isFailed = false
            if f.Icon.SetDesaturated then f.Icon:SetDesaturated(false) end
            f.Icon:SetVertexColor(1, 1, 1)
            if E.Libs.CustomGlow then E.Libs.CustomGlow.PixelGlow_Stop(f) end
        end
    elseif Engine.pool[unit] then
        local f = Engine.pool[unit]
        f:Hide()
        f.isFailed = false
        if f.Icon.SetDesaturated then f.Icon:SetDesaturated(false) end
        f.Icon:SetVertexColor(1, 1, 1)
        if E.Libs.CustomGlow then E.Libs.CustomGlow.PixelGlow_Stop(f) end
    end
    Engine:UpdatePositions()
end

local function MarkAsFailed(unit)
    local f = Engine.pool[unit]
    if f and f:IsShown() and not f.isFailed then
        f.isFailed = true
        
        -- 褪色变灰
        if f.Icon.SetDesaturated then f.Icon:SetDesaturated(true) end
        f.Icon:SetVertexColor(0.5, 0.5, 0.5) 
        
        if f.Time:GetFont() then f.Time:SetText("") end 
        
        -- 打断绿色边框
        if E.Libs.CustomGlow then 
            E.Libs.CustomGlow.PixelGlow_Stop(f) 
            E.Libs.CustomGlow.PixelGlow_Start(f, {0, 1, 0, 1}, 8, 0.25, 8, 2, 0, 0, false, "WishTargetAlertGlow_"..unit)
        end
        
        f.doNotHideBefore = GetTime() + 1.5
        C_Timer.After(1.5, function()
            if f.isFailed and f:IsShown() and GetTime() >= (f.doNotHideBefore - 0.1) then
                StopUI(unit)
            end
        end)
    end
end

local function StartUI(unit, texture, durationObj)
    local f = GetAlertFrame(unit)
    
    f.isFailed = false
    if f.Icon.SetDesaturated then f.Icon:SetDesaturated(false) end
    f.Icon:SetVertexColor(1, 1, 1)
    
    f.Icon:SetTexture(texture)
    f.durationObj = durationObj
    f.startTime = GetTime()
    
    if not f:IsShown() then f.creationTime = GetTime() end

    f:Show()

    if f.SetAlphaFromBoolean then
        if PlayerIsSpellTarget then
            f:SetAlphaFromBoolean(PlayerIsSpellTarget(unit, "player"))
        else
            f:SetAlphaFromBoolean(UnitIsUnit(unit.."target", "player"))
        end
    end

    local db = GetDB()
    if E.Libs.CustomGlow then
        E.Libs.CustomGlow.PixelGlow_Stop(f)
        if db.useGlow then 
            local c = db.glowColor
            E.Libs.CustomGlow.PixelGlow_Start(f, {c.r, c.g, c.b, c.a}, db.glowLines, db.glowFreq, 8, db.glowThick, 0, 0, false, "WishTargetAlertGlow_"..unit)
        end
    end

    Engine:UpdatePositions()
end

local function DoCheck(unit)
    if not GetDB().enable then return end
    
    local isEnemy = true
    pcall(function() if UnitExists(unit) and not UnitCanAttack("player", unit) then isEnemy = false end end)
    if not isEnemy then return end

    local name, _, texture = UnitCastingInfo(unit)
    local isChannel = false
    if not name then 
        name, _, texture = UnitChannelInfo(unit)
        isChannel = true 
    end
    
    if name then
        local durationObj = isChannel and UnitChannelDuration(unit) or UnitCastingDuration(unit)
        StartUI(unit, texture, durationObj)
        return
    end
    
    StopUI(unit)
end

function Engine:Preview()
    local isPreviewing = false
    for i = 1, 3 do
        local f = self.pool["TEST"..i]
        if f and f:IsShown() then
            isPreviewing = true
            break
        end
    end

    if isPreviewing then
        for i = 1, 3 do StopUI("TEST"..i) end
    else
        local t = GetTime()
        for i = 1, 3 do
            local unit = "TEST"..i
            local f = GetAlertFrame(unit)
            f.durationObj = 3 + i
            f.startTime = t
            f.creationTime = t + i
            f.Icon:SetTexture(136012)
            
            f.isFailed = false
            if f.Icon.SetDesaturated then f.Icon:SetDesaturated(false) end
            f.Icon:SetVertexColor(1, 1, 1)
            
            if f.SetAlphaFromBoolean then f:SetAlphaFromBoolean(true) end
            
            f:Show()
            
            local db = GetDB()
            if E.Libs.CustomGlow then
                E.Libs.CustomGlow.PixelGlow_Stop(f)
                if db.useGlow then 
                    local c = db.glowColor
                    E.Libs.CustomGlow.PixelGlow_Start(f, {c.r, c.g, c.b, c.a}, db.glowLines, db.glowFreq, 8, db.glowThick, 0, 0, false, "WishTargetAlertGlow_"..unit)
                end
            end
        end
        Engine:UpdatePositions()
    end
end

-- ==========================================
-- 7. 事件派发与倒计时渲染
-- ==========================================
Engine:SetScript("OnEvent", function(self, event, unit)
    if not unit or unit == "player" then return end
    if not (string.find(unit, "^nameplate") or string.find(unit, "^boss")) then return end

    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        C_Timer.After(0.2, function() DoCheck(unit) end)
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET" then
        MarkAsFailed(unit)
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local f = self.pool[unit]
        if not (f and f.isFailed) then
            StopUI(unit)
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        StopUI(unit)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        DoCheck(unit)
    end
end)

Engine:SetScript("OnUpdate", function(self, elapsed)
    self.updateTimer = (self.updateTimer or 0) + elapsed
    if self.updateTimer < 0.1 then return end
    self.updateTimer = 0

    local now = GetTime()
    for unit, f in pairs(self.pool) do
        if f:IsShown() and not f.isFailed then
            if type(f.durationObj) == "number" and f.startTime then
                local remain = f.startTime + f.durationObj - now
                if remain > 0 then
                    if f.Time:GetFont() then f.Time:SetFormattedText("%.1f", remain) end
                else
                    if f.Time:GetFont() then f.Time:SetText("") end
                    -- 修复：测试模式在倒计时结束后自动调用 StopUI 消失
                    if string.sub(unit, 1, 4) == "TEST" then
                        StopUI(unit)
                    end
                end
            elseif f.durationObj then
                -- 【修复内存泄漏】：摒弃匿名函数，将方法指针直接交给 pcall
                local ok, remain = pcall(f.durationObj.GetRemainingDuration, f.durationObj)
                if ok and remain and f.Time:GetFont() then
                    f.Time:SetFormattedText("%.1f", remain)
                end
            end
        end
    end
end)

-- ==========================================
-- 8. ElvUI 模块装载
-- ==========================================
function mod:Initialize()
    if self.Initialized then return end
    self.Initialized = true
    self:InjectOptions()
    if GetDB().enable then mod:CreateAlertAnchor() end
end

E:RegisterModule(mod:GetName())
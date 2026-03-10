local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local CA = WUI:NewModule('CombatAlert', 'AceEvent-3.0')
local LSM = E.Libs.LSM

-- =====================================================================
-- 1. 默认数据库
-- =====================================================================
P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.combatAlert = true
P["WishFlex"].combatAlert = {
    font = "Expressway", fontSize = 42, fontOutline = "OUTLINE",
    enterColor = { r = 1, g = 0.1, b = 0.1 },
    leaveColor = { r = 0.1, g = 1, b = 0.1 },
    enterText = "进入战斗",
    leaveText = "脱离战斗"
}

-- =====================================================================
-- 2. 设置面板注入
-- =====================================================================
local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.widgets = WUI.OptionsArgs.widgets or { order = 21, type = "group", name = "|cff00e5cc小工具|r", childGroups = "tab", args = {} }
    
    WUI.OptionsArgs.widgets.args.combatAlert = {
        order = 4, type = "group", name = "战斗状态动画提示",
        get = function(i) return E.db.WishFlex.combatAlert[i[#i]] end,
        set = function(i, v) E.db.WishFlex.combatAlert[i[#i]] = v; CA:UpdateFont() end,
        args = {
            topGrp = {
                order = 1, type = "group", name = "", guiInline = true,
                args = {
                    enable = { order = 1, type = "toggle", name = "启用", get = function() return E.db.WishFlex.modules.combatAlert end, set = function(_, v) E.db.WishFlex.modules.combatAlert = v; E:StaticPopup_Show("CONFIG_RL") end },
                    previewEnter = { order = 2, type = "execute", name = "预览：进入战斗", func = function() CA:PlayAlert(true) end },
                    previewLeave = { order = 3, type = "execute", name = "预览：脱离战斗", func = function() CA:PlayAlert(false) end },
                }
            },
            fontGrp = {
                order = 2, type = "group", name = "字体与特效", guiInline = true,
                args = {
                    font = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") },
                    fontSize = { order = 2, type = "range", name = "字号", min = 10, max = 150, step = 1 },
                    fontOutline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } },
                }
            },
            textGrp = {
                order = 3, type = "group", name = "文字与颜色配置", guiInline = true,
                args = {
                    enterText = { order = 1, type = "input", name = "进战提示文字" },
                    enterColor = { order = 2, type = "color", name = "进战颜色", get = function() local t = E.db.WishFlex.combatAlert.enterColor; return t.r, t.g, t.b end, set = function(_, r, g, b) E.db.WishFlex.combatAlert.enterColor = {r=r,g=g,b=b} end },
                    blank = { order = 3, type = "description", name = " " },
                    leaveText = { order = 4, type = "input", name = "退战提示文字" },
                    leaveColor = { order = 5, type = "color", name = "退战颜色", get = function() local t = E.db.WishFlex.combatAlert.leaveColor; return t.r, t.g, t.b end, set = function(_, r, g, b) E.db.WishFlex.combatAlert.leaveColor = {r=r,g=g,b=b} end },
                }
            }
        }
    }
end

-- =====================================================================
-- 3. 核心酷炫动画引擎 (上滑淡出式)
-- =====================================================================
function CA:CreateFrame()
    if self.frame then return end
    self.frame = CreateFrame("Frame", "WishFlex_CombatAlertFrame", E.UIParent)
    self.frame:SetSize(400, 80)
    self.frame:SetPoint("TOP", E.UIParent, "TOP", 0, -250)
    E:CreateMover(self.frame, "WishFlex_CombatAlertMover", "WishFlex: 进退战提示", nil, nil, nil, "ALL,WishFlex")

    self.text = self.frame:CreateFontString(nil, "OVERLAY")
    self.text:SetPoint("CENTER", self.frame, "CENTER")

    -- 挂载魔兽官方自带的 AnimationGroup 系统
    self.animGroup = self.text:CreateAnimationGroup()

    -- 阶段 1：快速淡入
    local fadeIn = self.animGroup:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0); fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.3); fadeIn:SetOrder(1)

    -- 阶段 2：屏幕中央停留
    local hold = self.animGroup:CreateAnimation("Alpha")
    hold:SetFromAlpha(1); hold:SetToAlpha(1)
    hold:SetDuration(1.0); hold:SetOrder(2)

    -- 阶段 3：往上滑动的同时渐渐淡出
    local fadeOut = self.animGroup:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1); fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.5); fadeOut:SetOrder(3)

    local slideUp = self.animGroup:CreateAnimation("Translation")
    slideUp:SetOffset(0, 40) -- 向上滑动 40 像素
    slideUp:SetDuration(0.5); slideUp:SetOrder(3)
    slideUp:SetSmoothing("OUT") -- 缓动曲线，让滑动更平滑

    self.animGroup:SetScript("OnFinished", function() self.text:SetAlpha(0) end)
    self.text:SetAlpha(0)
    
    self:UpdateFont()
end

function CA:UpdateFont()
    if not self.text then return end
    local db = E.db.WishFlex.combatAlert
    local fontPath = LSM:Fetch("font", db.font or "Expressway")
    self.text:FontTemplate(fontPath, db.fontSize or 42, db.fontOutline or "OUTLINE")
end

function CA:PlayAlert(isEnter)
    if not E.db.WishFlex.modules.combatAlert then return end
    self:UpdateFont()
    local db = E.db.WishFlex.combatAlert
    
    self.animGroup:Stop()

    if isEnter then
        self.text:SetText(db.enterText or "进入战斗")
        self.text:SetTextColor(db.enterColor.r, db.enterColor.g, db.enterColor.b)
    else
        self.text:SetText(db.leaveText or "脱离战斗")
        self.text:SetTextColor(db.leaveColor.r, db.leaveColor.g, db.leaveColor.b)
    end

    self.animGroup:Play()
end

hooksecurefunc(WUI, "Initialize", function() if not CA.Initialized then CA:Initialize() end end)

function CA:Initialize()
    if self.Initialized then return end
    self.Initialized = true
    
    InjectOptions()
    if not E.db.WishFlex.modules.combatAlert then return end

    self:CreateFrame()
    self:RegisterEvent("PLAYER_REGEN_DISABLED", function() self:PlayAlert(true) end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function() self:PlayAlert(false) end)
end
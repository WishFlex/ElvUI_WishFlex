local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local WM = WUI:NewModule('WorldMarker', 'AceEvent-3.0')

-- =====================================================================
-- 1. 默认数据库
-- =====================================================================
P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.worldMarker = true
P["WishFlex"].worldMarker = {
    placeKey = "",
    clearKey = "",
    markers = { 5, 6, 3, 4, 1, 2, 7, 8 } -- 默认顺序：星星, 大饼, 紫菱, 红叉, 方块, 三角, 月亮, 骷髅
}

local markerIcons = {
    [0] = "无 (跳过)",
    [1] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14|t 方块 (蓝)",
    [2] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:14|t 三角 (绿)",
    [3] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:14|t 紫菱 (紫)",
    [4] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:14|t 红叉 (红)",
    [5] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:14|t 星星 (黄)",
    [6] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:14|t 大饼 (橙)",
    [7] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:14|t 月亮 (银)",
    [8] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:14|t 骷髅 (白)",
}

-- =====================================================================
-- 2. 核心功能：原生 type1/type2 双轨架构 + 暴力 8 连发清除
-- =====================================================================
function WM:UpdateBindings()
    local db = E.db.WishFlex.worldMarker
    if not db then return end

    -- 创建唯一的终极安全按钮，挂靠在 UIParent 保证始终活跃
    if not self.btn then
        self.btn = CreateFrame("Button", "WishFlex_WorldMarkerBtn", UIParent, "SecureActionButtonTemplate")
        self.btn:SetSize(1, 1)
        self.btn:SetAlpha(0)
        self.btn:RegisterForClicks("AnyUp", "AnyDown")
        
        -- 开启左键 (type1) 和 右键 (type2) 的独立宏通道
        self.btn:SetAttribute("type1", "macro")
        self.btn:SetAttribute("type2", "macro")
        
        -- 【核心修复】：暴雪原生没有 /cwm all，必须用暴力 8 连发清除 1-8 号光柱！
        local clearMacroText = "/cwm 1\n/cwm 2\n/cwm 3\n/cwm 4\n/cwm 5\n/cwm 6\n/cwm 7\n/cwm 8"
        self.btn:SetAttribute("macrotext2", clearMacroText)
    end

    -- 提取玩家设置的循环顺序
    local body = "i = 0; order = newtable();\n"
    for i = 1, 8 do
        local val = db.markers[i]
        if val and val > 0 then
            body = body .. string.format("tinsert(order, %d);\n", val)
        end
    end

    -- 注入逻辑：判断当前是左键点击(放置)还是右键点击(清除)
    SecureHandlerExecute(self.btn, body)
    SecureHandlerUnwrapScript(self.btn, "PreClick")
    SecureHandlerWrapScript(self.btn, "PreClick", self.btn, [[
        if not down then return end
        
        if button == "RightButton" then
            -- 如果按下的是清除键 (对应右键)，仅重置计数器
            -- 按钮本身会自动执行 macrotext2 (8连发清除)
            i = 0
        else
            -- 如果按下的是放置键 (对应左键)，执行循环并赋予新宏
            if next(order) then
                i = i % #order + 1
                self:SetAttribute("macrotext1", "/wm [@cursor]" .. order[i])
            else
                self:SetAttribute("macrotext1", "")
            end
        end
    ]])

    -- 绑定玩家设置的快捷键：放置键模拟左击，清除键模拟右击
    ClearOverrideBindings(self.btn)
    if db.placeKey and db.placeKey ~= "" then
        SetOverrideBindingClick(self.btn, true, db.placeKey, "WishFlex_WorldMarkerBtn", "LeftButton")
    end
    if db.clearKey and db.clearKey ~= "" then
        SetOverrideBindingClick(self.btn, true, db.clearKey, "WishFlex_WorldMarkerBtn", "RightButton")
    end
end

-- =====================================================================
-- 3. 设置面板
-- =====================================================================
local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    
    -- 完整定义“小工具”父菜单（带有颜色和排序 21）
    WUI.OptionsArgs.widgets = WUI.OptionsArgs.widgets or { 
        order = 21, 
        type = "group", 
        name = "|cff00e5cc小工具|r", 
        childGroups = "tab", 
        args = {} 
    }
    WUI.OptionsArgs.widgets.args = WUI.OptionsArgs.widgets.args or {}

    -- 将光柱标记挂载为小工具的子菜单
    WUI.OptionsArgs.widgets.args.worldMarker = {
        order = 25, type = "group", name = "光柱标记",
        args = {
            base = {
                order = 1, type = "group", name = "基础设置", guiInline = true,
                args = {
                    enable = { order = 1, type = "toggle", name = "启用光柱标记", get = function() return E.db.WishFlex.modules.worldMarker end, set = function(_, v) E.db.WishFlex.modules.worldMarker = v; E:StaticPopup_Show("CONFIG_RL") end },
                    placeKey = { order = 2, type = "keybinding", name = "放置光柱快捷键", get = function() return E.db.WishFlex.worldMarker.placeKey end, set = function(_, v) E.db.WishFlex.worldMarker.placeKey = v; WM:UpdateBindings() end },
                    clearKey = { order = 3, type = "keybinding", name = "一键清除快捷键", get = function() return E.db.WishFlex.worldMarker.clearKey end, set = function(_, v) E.db.WishFlex.worldMarker.clearKey = v; WM:UpdateBindings() end },
                }
            },
            sequence = {
                order = 2, type = "group", name = "光柱循环顺序 (按快捷键依次放置)", guiInline = true,
                get = function(i) return E.db.WishFlex.worldMarker.markers[tonumber(i[#i]:match("%d+"))] end,
                set = function(i, v) E.db.WishFlex.worldMarker.markers[tonumber(i[#i]:match("%d+"))] = v; WM:UpdateBindings() end,
                args = {}
            }
        }
    }

    for i = 1, 8 do
        WUI.OptionsArgs.widgets.args.worldMarker.args.sequence.args["marker"..i] = {
            order = i, type = "select", name = "第 " .. i .. " 个", values = markerIcons
        }
    end
end

hooksecurefunc(WUI, "Initialize", function() if not WM.Initialized then WM:Initialize() end end)

function WM:Initialize()
    if self.Initialized then return end
    self.Initialized = true
    InjectOptions()
    if not E.db.WishFlex.modules.worldMarker then return end
    self:UpdateBindings()
end
local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local RCM = WUI:NewModule('RightClick', 'AceEvent-3.0')

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.RightClick = true

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.widgets = WUI.OptionsArgs.widgets or { order = 21, type = "group", name = "|cff00e5cc小工具|r", childGroups = "tab", args = {} }
    
    -- 创建“基础美化”子分组
    WUI.OptionsArgs.widgets.args.general = WUI.OptionsArgs.widgets.args.general or { order = 1, type = "group", name = "基础美化", args = {} }
    
    WUI.OptionsArgs.widgets.args.general.args.RightClick = { order = 2, type = "toggle", name = "防误触(双击右键)", get = function() return E.db.WishFlex.modules.RightClick end, set = function(_, v) E.db.WishFlex.modules.RightClick = v; E:StaticPopup_Show("CONFIG_RL") end }
end

local lastUpTime = 0
local doubleClickThreshold = 0.25 

local function StopNativeClick()
    MouselookStart()
    MouselookStop()
end

function RCM:OnEnable()
    InjectOptions()
    if not E.db.WishFlex or not E.db.WishFlex.modules["RightClick"] then return end

    WorldFrame:HookScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            local now = GetTime()
            local diff = now - lastUpTime
            if diff < doubleClickThreshold then
                lastUpTime = 0 
            else
                StopNativeClick()
                lastUpTime = now
            end
        end
    end)
end

function RCM:OnDisable() end
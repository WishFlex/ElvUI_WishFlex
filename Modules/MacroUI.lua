local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local MR = WUI:NewModule('macroui', 'AceEvent-3.0', 'AceHook-3.0')

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.macroui = true

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.widgets = WUI.OptionsArgs.widgets or { order = 21, type = "group", name = "|cff00e5cc小工具|r", childGroups = "tab", args = {} }
    
    WUI.OptionsArgs.widgets.args.general = WUI.OptionsArgs.widgets.args.general or { order = 1, type = "group", name = "基础美化", args = {} }
    
    WUI.OptionsArgs.widgets.args.general.args.macroui = { order = 1, type = "toggle", name = "宏界面放大", get = function() return E.db.WishFlex.modules.macroui end, set = function(_, v) E.db.WishFlex.modules.macroui = v; E:StaticPopup_Show("CONFIG_RL") end }
end

local addonName = "MacroFrameEnhancer"
local addon = CreateFrame("Frame")
addon.DB = {}
local defaults = { widthMultiplier = 2.0, heightMultiplier = 2.3, macroSelectorHeight = 684, textBackgroundHeight = 600, scrollFrameHeight = 591 }

local function IsMacroUILoaded()
    if MacroFrame or MacroFrameTextBackground or MacroFrameScrollFrame then return true end
    for i = 1, GetNumAddOns() do
        local name, _, _, enabled, loadable = GetAddOnInfo(i)
        if name == "Blizzard_MacroUI" and enabled and loadable then return true end
    end
    return false
end

function addon:InitializeUI()
    if self.initialized then return end
    self.initialized = true
    local db = self.DB

    if MacroFrame then MacroFrame:SetHeight(338 * db.heightMultiplier); MacroFrame:SetWidth(338 * db.widthMultiplier) end
    if MacroFrame and MacroFrame.MacroSelector then MacroFrame.MacroSelector:SetHeight(db.macroSelectorHeight) end
    if MacroFrameSelectedMacroBackground then MacroFrameSelectedMacroBackground:ClearAllPoints(); MacroFrameSelectedMacroBackground:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", 338, -60) end
    if MacroFrameTextBackground then MacroFrameTextBackground:ClearAllPoints(); MacroFrameTextBackground:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", 338, -132); MacroFrameTextBackground:SetHeight(db.textBackgroundHeight) end
    if MacroFrameScrollFrame then MacroFrameScrollFrame:SetHeight(db.scrollFrameHeight) end
    if MacroFrameCharLimitText then MacroFrameCharLimitText:ClearAllPoints(); MacroFrameCharLimitText:SetPoint("TOP", MacroFrameTextBackground, "BOTTOM", 0, 0) end
    if MacroHorizontalBarLeft then MacroHorizontalBarLeft:ClearAllPoints(); MacroHorizontalBarLeft:SetPoint("BOTTOMLEFT", MacroFrame, "BOTTOMLEFT", 4, 4) end
    self:HookScrollPosition()
end

function addon:HookScrollPosition()
    if not MacroFrame or not MacroFrame.MacroSelector then return end
    local scrollData = {}
    local isRestoring = false
    hooksecurefunc(MacroFrame, "SelectMacro", function(self, index)
        if not isRestoring and scrollData.scrollPercentage then
            isRestoring = true
            C_Timer.After(0.01, function()
                if MacroFrame and MacroFrame.MacroSelector and MacroFrame.MacroSelector.ScrollBox then MacroFrame.MacroSelector.ScrollBox:SetScrollPercentage(scrollData.scrollPercentage) end
                isRestoring = false
            end)
        end
    end)
    self:RegisterEvent("UPDATE_MACROS")
    self:SetScript("OnEvent", function(self, event, ...)
        if event == "UPDATE_MACROS" then
            if MacroFrame and MacroFrame.MacroSelector and MacroFrame.MacroSelector.ScrollBox then scrollData.scrollPercentage = MacroFrame.MacroSelector.ScrollBox:GetScrollPercentage() end
        elseif event == "ADDON_LOADED" then
            local loadedName = ...
            if loadedName == "Blizzard_MacroUI" then self:InitializeUI(); self:UnregisterEvent("ADDON_LOADED") end
        end
    end)
    MacroFrame:HookScript("OnShow", function()
        if scrollData.scrollPercentage then
            C_Timer.After(0.05, function() if MacroFrame and MacroFrame.MacroSelector and MacroFrame.MacroSelector.ScrollBox then MacroFrame.MacroSelector.ScrollBox:SetScrollPercentage(scrollData.scrollPercentage) end end)
        end
    end)
end

function addon:OnLoad()
    MacroFrameEnhancerDB = MacroFrameEnhancerDB or {}
    self.DB = setmetatable(MacroFrameEnhancerDB, {__index = defaults})
    if MacroFrame then self:InitializeUI() else
        self:RegisterEvent("ADDON_LOADED")
        self:SetScript("OnEvent", function(self, event, loadedName)
            if event == "ADDON_LOADED" and loadedName == "Blizzard_MacroUI" then self:InitializeUI(); self:UnregisterEvent("ADDON_LOADED") end
        end)
    end
end

function MR:OnEnable()
    InjectOptions()
    if not E.db.WishFlex.modules.macroui then return end
    addon:OnLoad()
end
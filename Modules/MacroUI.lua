local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local MR = WUI:NewModule('macroui', 'AceEvent-3.0', 'AceHook-3.0')
local S = E:GetModule('Skins')
local LCG = E.Libs.CustomGlow

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.macroui = true
P["WishFlex"].macroui_width = 680
P["WishFlex"].macroui_height = 750
P["WishFlex"].macroui_glow = "pixel" 

local addonName = "MacroFrameEnhancer"
local addon = CreateFrame("Frame")
addon.knownMacros = {}
addon.newMacros = {}

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.widgets = WUI.OptionsArgs.widgets or { order = 21, type = "group", name = "|cff00e5cc小工具|r", childGroups = "tab", args = {} }
    
    WUI.OptionsArgs.widgets.args.general = WUI.OptionsArgs.widgets.args.general or { order = 1, type = "group", name = "宏界面", args = {} }
    WUI.OptionsArgs.widgets.args.general.args.macroGroup = {
        order = 2,
        type = "group",
        name = "宏命令设置",
        guiInline = true,
        disabled = function() return not E.db.WishFlex.modules.macroui end,
        args = {
            macroui_toggle = {
                order = 1, 
                type = "toggle", 
                name = "开启增强", 
                disabled = false,
                get = function() return E.db.WishFlex.modules.macroui end, 
                set = function(_, v) E.db.WishFlex.modules.macroui = v; E:StaticPopup_Show("CONFIG_RL") end 
            },
            macroui_width = {
                order = 2,
                type = "range",
                name = "界面宽度",
                min = 600, max = 1200, step = 10, 
                get = function() return E.db.WishFlex.macroui_width end,
                set = function(_, v) E.db.WishFlex.macroui_width = v; addon:UpdateLayout() end
            },
            macroui_height = {
                order = 3,
                type = "range",
                name = "界面高度",
                min = 500, max = 1200, step = 10, 
                get = function() return E.db.WishFlex.macroui_height end,
                set = function(_, v) E.db.WishFlex.macroui_height = v; addon:UpdateLayout() end
            },
            macroui_glow = {
                order = 4,
                type = "select",
                name = "新建宏高亮",
                values = {
                    ["pixel"] = "像素发光",
                    ["autocast"] = "闪烁发光 (AutoCast)",
                    ["button"] = "按钮发光 (Button)"
                },
                get = function() return E.db.WishFlex.macroui_glow end,
                set = function(_, v) 
                    E.db.WishFlex.macroui_glow = v
                    addon:UpdateMacroVisuals() 
                end
            }
        }
    }
end

function addon:UpdateKnownMacros(checkNew)
    local global, char = GetNumMacros()
    local currentList = {}
    
    for i = 1, global do
        local name = GetMacroInfo(i)
        if name then currentList[name] = true end
    end
    
    for i = 121, 120 + char do
        local name = GetMacroInfo(i)
        if name then currentList[name] = true end
    end

    if checkNew then
        for name in pairs(currentList) do
            if not self.knownMacros[name] then
                self.newMacros[name] = true
            end
        end
    end
    
    self.knownMacros = currentList
end

function addon:UpdateMacroVisuals()
    if not MacroFrame or not MacroFrame.MacroSelector or not MacroFrame.MacroSelector.ScrollBox then return end
    if not MacroFrame.MacroSelector.ScrollBox:GetView() then return end
    
    local searchText = self.SearchBox and self.SearchBox:GetText():lower() or ""
    local glowType = E.db.WishFlex.macroui_glow
    
    MacroFrame.MacroSelector.ScrollBox:ForEachFrame(function(button)
        local elementData = button:GetElementData()
        if not elementData then return end
        
        local macroIndex = type(elementData) == "table" and (elementData.macroIndex or elementData.id) or elementData
        local name, _, _ = GetMacroInfo(macroIndex)
        
        if not name then return end

        if searchText ~= "" and not name:lower():find(searchText, 1, true) then
            button:SetAlpha(0.2)
        else
            button:SetAlpha(1.0)
        end

        if LCG then
            LCG.PixelGlow_Stop(button)
            LCG.AutoCastGlow_Stop(button)
            LCG.ButtonGlow_Stop(button)
            
            if addon.newMacros[name] then
                if glowType == "pixel" then
                    LCG.PixelGlow_Start(button)
                elseif glowType == "autocast" then
                    LCG.AutoCastGlow_Start(button)
                elseif glowType == "button" then
                    LCG.ButtonGlow_Start(button)
                end
            end
        end
    end)
end

function addon:CreateSearchBox()
    if self.SearchBox then return end

    local searchBox = CreateFrame("EditBox", "MacroFrameEnhancerSearchBox", MacroFrame, "SearchBoxTemplate")
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)
    
    if S then S:HandleEditBox(searchBox) end
    
    searchBox:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        addon:UpdateMacroVisuals()
    end)

    self.SearchBox = searchBox
end

function addon:UpdateLayout()
    if not MacroFrame then return end
    local db = E.db.WishFlex
    local safeWidth = math.max(600, db.macroui_width)
    local safeHeight = math.max(500, db.macroui_height)

    MacroFrame:SetWidth(safeWidth)
    MacroFrame:SetHeight(safeHeight)

    local insetX = 20
    local visualFixX = 4 

    if self.SearchBox then
        self.SearchBox:ClearAllPoints()
        self.SearchBox:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", insetX + visualFixX, -35)
        self.SearchBox:SetPoint("TOPRIGHT", MacroFrame, "TOPRIGHT", -(insetX + visualFixX), -35)
        self.SearchBox:SetHeight(25)
    end
    if MacroFrameTab1 and MacroFrameTab2 then
        MacroFrameTab1:ClearAllPoints()
        MacroFrameTab1:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", insetX, -70)
    end
    if MacroFrame.MacroSelector then
        MacroFrame.MacroSelector:ClearAllPoints()
        MacroFrame.MacroSelector:SetPoint("TOPLEFT", MacroFrameTab1, "BOTTOMLEFT", 0, -5)
        MacroFrame.MacroSelector:SetPoint("RIGHT", MacroFrame, "RIGHT", -insetX, 0)
        MacroFrame.MacroSelector:SetHeight(280)
        if MacroFrame.MacroSelector.ScrollBox then
            local view = MacroFrame.MacroSelector.ScrollBox:GetView()
            if view and view.SetStride then
                local availableWidth = safeWidth - (insetX * 2)
                local columns = math.max(6, math.floor(availableWidth / 44))
                view:SetStride(columns)
                if MacroFrame:IsShown() then
                    MacroFrame.MacroSelector.ScrollBox:FullUpdate(true)
                end
            end
        end
    end

    if MacroFrameSelectedMacroButton then
        MacroFrameSelectedMacroButton:ClearAllPoints()
        MacroFrameSelectedMacroButton:SetPoint("TOPLEFT", MacroFrame.MacroSelector, "BOTTOMLEFT", 0, -15)
    end

    if MacroFrameSelectedMacroName then
        MacroFrameSelectedMacroName:ClearAllPoints()
        MacroFrameSelectedMacroName:SetPoint("LEFT", MacroFrameSelectedMacroButton, "RIGHT", 10, 0)
        MacroFrameSelectedMacroName:SetWidth(120)
        MacroFrameSelectedMacroName:SetJustifyH("LEFT")
    end

    if MacroEditButton and MacroFrameSelectedMacroName then
        MacroEditButton:ClearAllPoints()
        MacroEditButton:SetPoint("LEFT", MacroFrameSelectedMacroName, "RIGHT", 10, 0)
    end

    if MacroSaveButton and MacroEditButton then
        MacroSaveButton:ClearAllPoints()
        MacroSaveButton:SetPoint("LEFT", MacroEditButton, "RIGHT", 10, 0)
    end

    if MacroCancelButton and MacroSaveButton then
        MacroCancelButton:ClearAllPoints()
        MacroCancelButton:SetPoint("LEFT", MacroSaveButton, "RIGHT", 10, 0)
    end

    if MacroFrameTextBackground then
        MacroFrameTextBackground:ClearAllPoints()
        MacroFrameTextBackground:SetPoint("TOPLEFT", MacroFrameSelectedMacroButton, "BOTTOMLEFT", 0, -15)
        MacroFrameTextBackground:SetPoint("BOTTOMRIGHT", MacroFrame, "BOTTOMRIGHT", -insetX, 45) 
    end
    
    if MacroFrameSelectedMacroBackground then
        MacroFrameSelectedMacroBackground:SetAlpha(0)
    end
    if MacroFrameEnterMacroText then
        MacroFrameEnterMacroText:SetText("")
        MacroFrameEnterMacroText:SetAlpha(0)
    end
    
    if MacroFrameScrollFrame then
        MacroFrameScrollFrame:ClearAllPoints()
        MacroFrameScrollFrame:SetPoint("TOPLEFT", MacroFrameTextBackground, "TOPLEFT", 10, -10)
        MacroFrameScrollFrame:SetPoint("BOTTOMRIGHT", MacroFrameTextBackground, "BOTTOMRIGHT", -30, 10)
    end

    if MacroFrameCharLimitText then
        MacroFrameCharLimitText:ClearAllPoints()
        MacroFrameCharLimitText:SetPoint("BOTTOM", MacroFrameTextBackground, "BOTTOM", 0, -15)
    end
    if MacroDeleteButton then
        MacroDeleteButton:ClearAllPoints()
        MacroDeleteButton:SetPoint("BOTTOMLEFT", MacroFrame, "BOTTOMLEFT", insetX, 15)
    end

    if MacroExitButton then
        MacroExitButton:ClearAllPoints()
        MacroExitButton:SetPoint("BOTTOMRIGHT", MacroFrame, "BOTTOMRIGHT", -insetX, 15)
    end

    if MacroNewButton and MacroExitButton then
        MacroNewButton:ClearAllPoints()
        MacroNewButton:SetPoint("RIGHT", MacroExitButton, "LEFT", -10, 0)
    end
end

function addon:InitializeUI()
    if self.initialized then return end
    self.initialized = true

    self:CreateSearchBox()
    self:UpdateLayout()
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
                if MacroFrame and MacroFrame.MacroSelector and MacroFrame.MacroSelector.ScrollBox and MacroFrame.MacroSelector.ScrollBox:GetView() then 
                    MacroFrame.MacroSelector.ScrollBox:SetScrollPercentage(scrollData.scrollPercentage) 
                end
                isRestoring = false
            end)
        end
    end)

    if MacroFrame.MacroSelector.ScrollBox then
        hooksecurefunc(MacroFrame.MacroSelector.ScrollBox, "Update", function()
            addon:UpdateMacroVisuals()
        end)
    end

    self:RegisterEvent("UPDATE_MACROS")
    self:SetScript("OnEvent", function(self, event, ...)
        if event == "UPDATE_MACROS" then
            if MacroFrame and MacroFrame.MacroSelector and MacroFrame.MacroSelector.ScrollBox and MacroFrame.MacroSelector.ScrollBox:GetView() then 
                scrollData.scrollPercentage = MacroFrame.MacroSelector.ScrollBox:GetScrollPercentage() 
            end
            
            addon:UpdateKnownMacros(true)
            addon:UpdateMacroVisuals()

        elseif event == "ADDON_LOADED" then
            local loadedName = ...
            if loadedName == "Blizzard_MacroUI" then 
                self:InitializeUI()
                self:UnregisterEvent("ADDON_LOADED") 
            end
        end
    end)

    MacroFrame:HookScript("OnShow", function()
        addon:UpdateLayout()
        addon:UpdateKnownMacros(false)
        addon.newMacros = {}
        if addon.SearchBox then addon.SearchBox:SetText("") end
        
        if scrollData.scrollPercentage then
            C_Timer.After(0.05, function() 
                if MacroFrame and MacroFrame.MacroSelector and MacroFrame.MacroSelector.ScrollBox and MacroFrame.MacroSelector.ScrollBox:GetView() then 
                    MacroFrame.MacroSelector.ScrollBox:SetScrollPercentage(scrollData.scrollPercentage) 
                end 
            end)
        end
    end)
    
    MacroFrame:HookScript("OnHide", function()
        addon.newMacros = {}
        if MacroFrame and MacroFrame.MacroSelector and MacroFrame.MacroSelector.ScrollBox and MacroFrame.MacroSelector.ScrollBox:GetView() then
            MacroFrame.MacroSelector.ScrollBox:ForEachFrame(function(button)
                if LCG then 
                    LCG.PixelGlow_Stop(button)
                    LCG.AutoCastGlow_Stop(button)
                    LCG.ButtonGlow_Stop(button)
                end
            end)
        end
    end)
end

function addon:OnLoad()
    if MacroFrame then 
        self:InitializeUI() 
    else
        self:RegisterEvent("ADDON_LOADED")
        self:SetScript("OnEvent", function(self, event, loadedName)
            if event == "ADDON_LOADED" and loadedName == "Blizzard_MacroUI" then 
                self:InitializeUI()
                self:UnregisterEvent("ADDON_LOADED") 
            end
        end)
    end
end

function MR:OnEnable()
    InjectOptions()
    if not E.db.WishFlex.modules.macroui then return end
    addon:OnLoad()
end
local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local VB = WUI:NewModule('VehicleBar', 'AceEvent-3.0')

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.vehiclebar = true
P["WishFlex"].vehiclebar = { width = 40, height = 40, spacing = 6, fontSize = 12 }

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.widgets = WUI.OptionsArgs.widgets or { order = 21, type = "group", name = "|cff00e5cc小工具|r", childGroups = "tab", args = {} }
    
    WUI.OptionsArgs.widgets.args.vehiclebar = {
        order = 2, type = "group", name = "特殊载具条",
        args = {
            enable = { order = 1, type = "toggle", name = "启用", get = function() return E.db.WishFlex.modules.vehiclebar end, set = function(_, v) E.db.WishFlex.modules.vehiclebar = v; E:StaticPopup_Show("CONFIG_RL") end },
            width = { order = 2, type = "range", name = "宽度", min = 20, max = 100, step = 1, get = function() return E.db.WishFlex.vehiclebar.width end, set = function(_, v) E.db.WishFlex.vehiclebar.width = v; VB:UpdateLayout() end },
            height = { order = 3, type = "range", name = "高度", min = 20, max = 100, step = 1, get = function() return E.db.WishFlex.vehiclebar.height end, set = function(_, v) E.db.WishFlex.vehiclebar.height = v; VB:UpdateLayout() end },
            spacing = { order = 4, type = "range", name = "间距", min = 0, max = 20, step = 1, get = function() return E.db.WishFlex.vehiclebar.spacing end, set = function(_, v) E.db.WishFlex.vehiclebar.spacing = v; VB:UpdateLayout() end },
            fontSize = { order = 5, type = "range", name = "字体大小", min = 8, max = 32, step = 1, get = function() return E.db.WishFlex.vehiclebar.fontSize end, set = function(_, v) E.db.WishFlex.vehiclebar.fontSize = v; VB:UpdateLayout() end },
        }
    }
end


function VB:UpdateLayout()
    if not self.barFrame then return end
    if InCombatLockdown() then self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateLayout"); return end
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")

    local db = E.db.WishFlex.vehiclebar
    local lastBtn, activeCount = nil, 0

    for i = 1, 10 do
        local btn = self.buttons[i]
        btn:SetSize(db.width, db.height)
        btn.hotkey:FontTemplate(nil, db.fontSize or 12, "OUTLINE")
        btn.hotkey:ClearAllPoints()
        btn.hotkey:SetPoint(db.hotkeyAnchor or "TOPRIGHT", btn, db.hotkeyAnchor or "TOPRIGHT", db.xOffset or -2, db.yOffset or -2)
        btn.icon:SetInside(btn, 2, 2) 
        btn:ClearAllPoints()
        
        if btn:GetAlpha() > 0 then
            activeCount = activeCount + 1
            if not lastBtn then btn:SetPoint("LEFT", self.barFrame, "LEFT", 0, 0) else btn:SetPoint("LEFT", lastBtn, "RIGHT", db.spacing, 0) end
            lastBtn = btn
        end
    end
    if activeCount > 0 then self.barFrame:SetSize(activeCount * db.width + (activeCount - 1) * db.spacing, db.height) end
end

function VB:UpdateVehicleInfo()
    local barIndex = 0
    if HasOverrideActionBar() then barIndex = GetOverrideBarIndex() elseif HasVehicleActionBar() then barIndex = GetVehicleBarIndex() elseif HasTempShapeshiftActionBar() then barIndex = GetTempShapeshiftBarIndex() end
    local isSkyriding = GetBonusBarOffset() == 5
    
    if not barIndex or barIndex <= 1 or isSkyriding then 
        for i = 1, 10 do self.buttons[i]:SetAlpha(0) end
        self:UpdateLayout(); return 
    end

    for i = 1, 10 do
        local btn = self.buttons[i]
        local actionID = (barIndex - 1) * 12 + i
        local texture = GetActionTexture(actionID)
        if texture then
            btn.icon:SetTexture(texture)
            if not InCombatLockdown() then btn:SetAttribute("type", "action"); btn:SetAttribute("action", actionID) end
            local hotkey = GetBindingKey("ACTIONBUTTON"..i) or ""
            hotkey = hotkey:gsub("a%-", "A"):gsub("c%-", "C"):gsub("s%-", "S")
            btn.hotkey:SetText(hotkey)
            btn:SetAlpha(1)
        else
            btn:SetAlpha(0)
        end
    end
    self:UpdateLayout()
end

function VB:OnEnable()
    InjectOptions()
    if not E.db.WishFlex.modules.vehiclebar then return end
    if not self.barFrame then
        self.barFrame = CreateFrame("Frame", "WishVehicleBar", E.UIParent, "SecureHandlerStateTemplate, BackdropTemplate")
        self.barFrame:SetPoint("BOTTOM", E.UIParent, "BOTTOM", 0, 150)
        self.buttons = {}
        for i = 1, 10 do
            local btn = CreateFrame("CheckButton", "WishVehicleBtn"..i, self.barFrame, "SecureActionButtonTemplate, BackdropTemplate")
            btn:SetTemplate("Default")
            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetTexCoord(unpack(E.TexCoords))
            btn.hotkey = btn:CreateFontString(nil, "OVERLAY")
            btn.hotkey:FontTemplate(nil, 12, "OUTLINE")
            btn:SetScript("OnEnter", function(self)
                local action = self:GetAttribute("action")
                if action then
                    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT", 0, 5)
                    GameTooltip:SetAction(action)
                    GameTooltip:Show()
                end
            end)
            btn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
            
            self.buttons[i] = btn
        end
        RegisterStateDriver(self.barFrame, "visibility", "[petbattle]hide;[bonusbar:5]hide;[overridebar][possessbar][vehicleui]show;hide")
        E:CreateMover(self.barFrame, "WishVehicleBarMover", "WishFlex载具条", nil, nil, nil, "ALL,WishFlex")
    end

    self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR", "UpdateVehicleInfo")
    self:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR", "UpdateVehicleInfo")
    self:RegisterEvent("ACTIONBAR_UPDATE_STATE", "UpdateVehicleInfo")
    self:RegisterEvent("UNIT_ENTERED_VEHICLE", "UpdateVehicleInfo")
    self:RegisterEvent("UNIT_EXITED_VEHICLE", "UpdateVehicleInfo")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateVehicleInfo")
    self:UpdateVehicleInfo()
end

function VB:OnDisable()
    if self.barFrame then UnregisterStateDriver(self.barFrame, "visibility"); self.barFrame:Hide() end
    self:UnregisterAllEvents()
end
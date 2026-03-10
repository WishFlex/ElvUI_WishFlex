local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local AddonName, addonTable = ...
local LSM = E.Libs.LSM
if LSM then
    LSM:Register("statusbar", "WishMouseover", [[Interface\AddOns\ElvUI_WishFlex\Media\Textures\WishMouseover.tga]])
    LSM:Register("statusbar", "WishTarget", [[Interface\AddOns\ElvUI_WishFlex\Media\Textures\WishTarget.tga]])
    LSM:Register("statusbar", "Wishq1", [[Interface\AddOns\ElvUI_WishFlex\Media\Textures\Wishq1.tga]])
    LSM:Register("statusbar", "WishFlex-clean", [[Interface\AddOns\ElvUI_WishFlex\Media\Textures\WishUI-clean.tga]])
    LSM:Register("statusbar", "Wish2", [[Interface\AddOns\ElvUI_WishFlex\Media\Textures\Wish2.tga]])
    LSM:Register("statusbar", "Wish3", [[Interface\AddOns\ElvUI_WishFlex\Media\Textures\Wish3.tga]])
    LSM:Register("font", "Wish-AvantGarde", [[Interface\AddOns\ElvUI_WishFlex\Media\Fonts\avantgarde.ttf]], 255)
    LSM:Register("font", "Wish-Pannetje", [[Interface\AddOns\ElvUI_WishFlex\Media\Fonts\pannetje.ttf]], 255)
    LSM:Register("font", "Wish-SG09", [[Interface\AddOns\ElvUI_WishFlex\Media\Fonts\SG09.ttf]], 255)
end
local WF = E:NewModule('WishFlex', 'AceEvent-3.0', 'AceHook-3.0')
WF.Title = "|cff00ffccWishFlex|r"

function WF:Initialize()
    self.db = E.db.WishFlex
    local moduleMapping = {
        ["chatSetup"] = "WishFlex_ChatSetup",  
        ["keybinder"] = "WishFlex_KeyBinder",
        ["worldMarker"] = "WorldMarker", 
        ["cooldownCustom"] = "CooldownCustom", 
        ["spellAlpha"] = "WishFlex_SpellAlpha", 
        ["narrative"] = "WishFlex_Narrative",
        ["lustMonitor"] = "LustMonitor", 
        ["rareAlert"]   = "RareAlert", 
        ["smarthide"] = "SmartHide",
        ["cooldownTracker"] = "CooldownTracker",
        ["vehiclebar"] = "VehicleBar",
        ["glow"] = "Glow",
        ["wishtargetAlert"] = "WishTargetAlert",
        ["macroui"] = "macroui",
        ["RightClick"] = "RightClick",
        ["auraGlow"] = "AuraGlow",
        ["stripeSkin"] = "WishFlex_StripeSkin",
        ["classResource"] = "ClassResource" 
    }

    for configKey, moduleName in pairs(moduleMapping) do
        local mod = WF:GetModule(moduleName, true)
        if mod and type(mod.Initialize) == "function" then
            mod:Initialize()
        end
    end
end

function WF:OnEnable()
    -- 预留位
end

E:RegisterModule(WF:GetName())
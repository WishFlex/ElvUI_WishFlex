local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule('Skins')
local WUI = E:GetModule('WishFlex')
local MOD = WUI:NewModule('WishFlex_StripeSkin', 'AceEvent-3.0')

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.stripeSkin = true

local STRIPE_TEX = [[Interface\AddOns\ElvUI_WishFlex\Media\stripes.blp]]

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.widgets = WUI.OptionsArgs.widgets or { 
        order = 21, 
        type = "group", 
        name = "|cff00e5cc小工具|r", 
        childGroups = "tab", 
        args = {} 
    }
    WUI.OptionsArgs.widgets.args.stripeSkin = {
        order = 5, type = "group", name = "斜纹背景",
        args = {
            enable = { 
                order = 1, type = "toggle", name = "全局斜纹背景纹理", 
                get = function() return E.db.WishFlex.modules.stripeSkin end, 
                set = function(_, v) E.db.WishFlex.modules.stripeSkin = v; E:StaticPopup_Show("CONFIG_RL") end 
            }
        }
    }
end

local function ApplyWishStyle(f)
    if not f or not E.db.WishFlex.modules.stripeSkin then return end
    if type(f) ~= "table" or f:IsForbidden() then return end

    local name = f:GetName()
    
    if name and name:find("SharedScrollBox") then return end
    if name and name:find("DamageMeter") and not name:find("DamageMeterSessionWindow") then return end
    if f:GetParent() then
        local pName = f:GetParent():GetName()
        if pName and pName:find("DamageMeter") and not pName:find("DamageMeterSessionWindow") then return end
    end

    local target = f.backdrop or f
    if not target or not target.CreateTexture or target.WishStripe then return end
    
    local stripe = target:CreateTexture(nil, "OVERLAY", nil, 7)
    stripe:SetAllPoints(target)
    stripe:SetTexture(STRIPE_TEX, "REPEAT", "REPEAT")
    stripe:SetHorizTile(true); stripe:SetVertTile(true)
    stripe:SetAlpha(1); stripe:SetBlendMode("ADD") 
    stripe:SetVertexColor(1, 1, 1, 1)
    stripe:SetTexCoord(0, 6, 0, 6) 
    target.WishStripe = stripe
end

local function SkinUnitFrames()
    if not E.db.WishFlex.modules.stripeSkin then return end
    
    local units = {"Player", "Target", "TargetTarget", "Focus", "FocusTarget", "Pet", "PetTarget"}
    for _, unit in ipairs(units) do
        local uf = _G["ElvUF_" .. unit]
        if uf then
            if uf.Health then ApplyWishStyle(uf.Health) end
            if uf.Power then ApplyWishStyle(uf.Power) end
            if uf.Castbar then ApplyWishStyle(uf.Castbar) end 
            if uf.Portrait and uf.Portrait.backdrop then ApplyWishStyle(uf.Portrait.backdrop) end
            if uf.InfoPanel then ApplyWishStyle(uf.InfoPanel) end
        end
    end
    
    for i = 1, 5 do
        local boss = _G["ElvUF_Boss" .. i]
        if boss then
            if boss.Health then ApplyWishStyle(boss.Health) end
            if boss.Power then ApplyWishStyle(boss.Power) end
            if boss.Castbar then ApplyWishStyle(boss.Castbar) end
        end
        local arena = _G["ElvUF_Arena" .. i]
        if arena then
            if arena.Health then ApplyWishStyle(arena.Health) end
            if arena.Power then ApplyWishStyle(arena.Power) end
            if arena.Castbar then ApplyWishStyle(arena.Castbar) end
        end
    end
end

local bagFrames = {
    "Baganator_CategoryViewBackpackViewFrame",
    "Baganator_CategoryViewBankViewFrame",
    "Baganator_ItemViewBackpackViewFrame",
    "Baganator_ItemViewBankViewFrame",
    "Baganator_GuildViewFrame"
}

local function ScanUnnamedBackdrops(...)
    for i = 1, select("#", ...) do
        local child = select(i, ...)
        if child and child:IsObjectType("Frame") and not child:GetName() then
            if (child.Center or child.NineSlice or child.template) and not child.WishStripe then
                ApplyWishStyle(child)
            end
        end
    end
end

local function TrySkinDynamicFrames()
    if not E.db.WishFlex.modules.stripeSkin then return end
    
    for _, name in ipairs(bagFrames) do
        local elvuiBg = _G[name .. "elvui"]
        if elvuiBg and not elvuiBg.WishStripe then ApplyWishStyle(elvuiBg) end
        
        local win = _G[name]
        if win and win.backdrop and not win.backdrop.WishStripe then ApplyWishStyle(win.backdrop) end
    end
    
    local al = _G.AddonList
    if al then
        if al.backdrop and not al.backdrop.WishStripe then
            ApplyWishStyle(al.backdrop)
        elseif not al.WishStripe then
            ApplyWishStyle(al)
        end
    end
    
    for i = 1, 5 do
        local dmFrame = _G["DamageMeterSessionWindow" .. i]
        if dmFrame then
            if dmFrame.backdrop and not dmFrame.backdrop.WishStripe then
                ApplyWishStyle(dmFrame.backdrop)
            end
            ScanUnnamedBackdrops(dmFrame:GetChildren())
        end
    end
end

function MOD:ADDON_LOADED(_, addonName)
    if not E.db.WishFlex.modules.stripeSkin then return end
    
    E:Delay(0.1, function()
        if addonName == "Blizzard_WeeklyRewards" and _G.WeeklyRewardsFrame then
            ApplyWishStyle(_G.WeeklyRewardsFrame)
        elseif addonName == "Blizzard_EncounterJournal" and _G.EncounterJournal then
            ApplyWishStyle(_G.EncounterJournal)
        elseif addonName == "Blizzard_Collections" and _G.CollectionsJournal then
            ApplyWishStyle(_G.CollectionsJournal)
        elseif addonName == "Blizzard_AchievementUI" and _G.AchievementFrame then
            ApplyWishStyle(_G.AchievementFrame)
        end
    end)
end

function MOD:Initialize()
    InjectOptions()
    if not E.db.WishFlex.modules.stripeSkin then return end

    local mt = getmetatable(CreateFrame("Frame")).__index
    if mt.SetTemplate then
        hooksecurefunc(mt, "SetTemplate", function(f) ApplyWishStyle(f) end)
    end
    if mt.CreateBackdrop then
        hooksecurefunc(mt, "CreateBackdrop", function(f) ApplyWishStyle(f) end)
    end
    
    local skinFunctions = {"HandleFrame", "HandleButton", "HandlePanel", "HandlePortraitFrame"}
    for _, func in pairs(skinFunctions) do
        if S[func] then 
            hooksecurefunc(S, func, function(_, frame) ApplyWishStyle(frame) end) 
        end
    end

    E:Delay(0.5, function()
        local earlyFrames = {
            _G.PVEFrame,
            _G.CharacterFrame,
            _G.QuestLogPopupDetailFrame,
            _G.WorldMapFrame,
            _G.LeftChatPanel,
            _G.RightChatPanel,
            _G.ElvUI_CopyChatFrame,
            _G.WishFlex_RareAlertFrame,
            _G.WishFlexNarrativeFrame, 
            _G.GameMenuFrame,
            _G.ElvLootFrame, 
            _G.LootFrame,
            _G.AddonList     
        }
        for _, f in ipairs(earlyFrames) do
            if f then ApplyWishStyle(f) end
        end
        
        if _G.WishFlex_RareAlertFrame and _G.WishFlex_RareAlertFrame.statusBar then
            ApplyWishStyle(_G.WishFlex_RareAlertFrame.statusBar)
        end
        if _G.WishFlexNarrativeFrame then
            if _G.WishFlexNarrativeFrame.AcceptButton then ApplyWishStyle(_G.WishFlexNarrativeFrame.AcceptButton) end
            if _G.WishFlexNarrativeFrame.DeclineButton then ApplyWishStyle(_G.WishFlexNarrativeFrame.DeclineButton) end
        end
        
        SkinUnitFrames()
    end)

    self:RegisterEvent("ADDON_LOADED")
    
    C_Timer.NewTicker(0.5, TrySkinDynamicFrames)
    
    if C_AddOns.IsAddOnLoaded("Blizzard_WeeklyRewards") and _G.WeeklyRewardsFrame then 
        E:Delay(0.1, function() ApplyWishStyle(_G.WeeklyRewardsFrame) end)
    end
end
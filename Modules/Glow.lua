local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local Glow = WUI:NewModule('Glow', 'AceHook-3.0')
local LCG = LibStub("LibCustomGlow-1.0", true)

local GLOW_KEY = "WishFlex_PIXEL_GLOW"

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.glow = true
P["WishFlex"].glow = P["WishFlex"].glow or { enabled = true, lines = 8, frequency = 0.2, thickness = 2, color = { r = 0, g = 1, b = 0.5, a = 1 } }

function Glow:Show(button)
    if not LCG or not button then return end
    if not E.db.WishFlex.modules.glow then return end
    local db = E.db.WishFlex.glow
    if not db then return end

    if button.SpellActivationAlert then button.SpellActivationAlert:Hide() end
    local color = { db.color.r, db.color.g, db.color.b, db.color.a }
    LCG.PixelGlow_Start(button, color, db.lines or 8, db.frequency or 0.2, nil, db.thickness or 2, 0, 0, false, GLOW_KEY)
end

function Glow:Hide(button)
    if not LCG or not button then return end
    LCG.PixelGlow_Stop(button, GLOW_KEY)
end

function Glow:OnEnable()
    if not LCG then print("|cff00ffccWishFlex|r: [错误] 未找到 LibCustomGlow 库。"); return end
    if not E.db.WishFlex.modules.glow then return end

    if ActionButtonSpellAlertManager then
        self:SecureHook(ActionButtonSpellAlertManager, "ShowAlert", function(_, frame) if frame then self:Show(frame) end end)
        self:SecureHook(ActionButtonSpellAlertManager, "HideAlert", function(_, frame) if frame then self:Hide(frame) end end)
    end
end

function Glow:OnDisable()
    self:UnhookAll()
end
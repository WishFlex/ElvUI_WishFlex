local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local MOD = E:NewModule('WishFlex_SpellAlpha', 'AceEvent-3.0')
local WUI = E:GetModule('WishFlex')

-- =====================================================================
-- 1. 默认数据库注入
-- =====================================================================
P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.spellAlpha = true
P["WishFlex"].spellAlpha = { enable = true, globalAlpha = 0.3, specs = {} }

-- =====================================================================
-- 2. 设置面板注入 (挂载到 SmartHide 的组内)
-- =====================================================================
local function GetSpellAlphaSpecOptions()
    local specArgs = {
        global = { 
            order = 1, type = "group", name = "透明度控制", guiInline = true, 
            args = { 
                enable = { order = 1, type = "toggle", name = "开启", get = function() return E.db.WishFlex.spellAlpha.enable end, set = function(_, v) E.db.WishFlex.spellAlpha.enable = v; MOD:Update() end }, 
                globalAlpha = { order = 2, type = "range", name = "法术高亮透明度", min = 0, max = 1, step = 0.05, isPercent = true, get = function() return E.db.WishFlex.spellAlpha.globalAlpha end, set = function(_, v) E.db.WishFlex.spellAlpha.globalAlpha = v; MOD:Update() end } 
            } 
        }
    }
    for i = 1, GetNumClasses() do
        local className, classTag, classID = GetClassInfo(i)
        if classTag then
            local color = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classTag]) or RAID_CLASS_COLORS[classTag]
            local hexColor = string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
            specArgs[classTag] = { type = "group", name = string.format("%s|TInterface\\ICONS\\ClassIcon_%s:14:14:0:0|t %s|r", hexColor, classTag, className), args = {} }
            
            for specIndex = 1, GetNumSpecializationsForClassID(classID) do
                local specID, specName, _, icon = GetSpecializationInfoForClassID(classID, specIndex)
                if specID then
                    specArgs[classTag].args[tostring(specID)] = { 
                        type = "toggle", name = string.format("|T%s:14:14:0:0|t %s", icon, specName), 
                        get = function() return E.db.WishFlex.spellAlpha.specs[specID] end, 
                        set = function(_, v) E.db.WishFlex.spellAlpha.specs[specID] = v; E:StaticPopup_Show("CONFIG_RL") end 
                    }
                end
            end
        end
    end
    return specArgs
end

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    -- 统一父节点名称
    WUI.OptionsArgs.smarthide = WUI.OptionsArgs.smarthide or { order = 10, type = "group", name = "|cff00ffcc智能隐藏|r", childGroups = "tab", args = {} }
    WUI.OptionsArgs.smarthide.args.spellAlpha = { order = 4, type = "group", name = "法术透明度", args = GetSpellAlphaSpecOptions() }
end

-- =====================================================================
-- 3. 核心功能逻辑
-- =====================================================================
function MOD:Update()
    if not E.db.WishFlex.spellAlpha.enable then 
        SpellActivationOverlayFrame:SetAlpha(1)
        return 
    end
    
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)
    
    local targetAlpha = 1
    if specID and E.db.WishFlex.spellAlpha.specs[specID] then
        targetAlpha = 1
    else
        targetAlpha = E.db.WishFlex.spellAlpha.globalAlpha or 0
    end

    if SpellActivationOverlayFrame then SpellActivationOverlayFrame:SetAlpha(targetAlpha) end
    SetCVar("spellClutter", targetAlpha * 100)
end

function MOD:Initialize()
    InjectOptions()
    if not E.db.WishFlex.modules.spellAlpha then return end
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "Update")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
    self:Update()
end

E:RegisterModule(MOD:GetName())
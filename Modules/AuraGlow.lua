local E, L, V, P, G = unpack(ElvUI)
local LSM = E.Libs.LSM
local AceGUI = LibStub("AceGUI-3.0")
local WUI = E:GetModule('WishFlex')
local mod = WUI:GetModule('AuraGlow', true) or WUI:NewModule('AuraGlow', 'AceHook-3.0', 'AceEvent-3.0')

local LCG = E.Libs and E.Libs.CustomGlow
if not LCG then LCG = LibStub and LibStub("LibCustomGlow-1.0", true) end

local activeSkillFrames = {}
local activeBuffFrames = {}
local targetAuraCache = {}
local BaseSpellCache = {}
local playerClass = select(2, UnitClass("player"))

P["WishFlex"] = P["WishFlex"] or { modules = {} }
G["WishFlex"] = G["WishFlex"] or { spellDB = {} } 
P["WishFlex"].modules.auraGlow = true
P["WishFlex"].auraGlow = {
    enable = true,
    independent = {
        size = 45, gap = 2, growth = "LEFT",
    },
    text = { font = "Expressway", fontSize = 20, fontOutline = "OUTLINE", color = {r = 1, g = 0.82, b = 0}, textAnchor = "CENTER", offsetX = 0, offsetY = 0 },
    independentText = { enable = false, font = "Expressway", fontSize = 20, fontOutline = "OUTLINE", color = {r = 1, g = 0.82, b = 0}, textAnchor = "CENTER", offsetX = 0, offsetY = 0 },
    
    glowEnable = true, glowType = "pixel", glowUseCustomColor = false, glowColor = {r = 1, g = 0.82, b = 0, a = 1},
    glowPixelLines = 8, glowPixelFrequency = 0.25, glowPixelLength = 0, glowPixelThickness = 2, glowPixelXOffset = 0, glowPixelYOffset = 0,
    glowAutocastParticles = 4, glowAutocastFrequency = 0.2, glowAutocastScale = 1, glowAutocastXOffset = 0, glowAutocastYOffset = 0,
    glowButtonFrequency = 0, glowProcDuration = 1, glowProcXOffset = 0, glowProcYOffset = 0,
}

local OverlayFrames = {}       
local IndependentFrames = {}   
mod.trackedAuras = {} 
mod.manualTrackers = {} 

local function GetSpellDB()
    if not E.global.WishFlex then E.global.WishFlex = {} end
    if type(E.global.WishFlex.spellDB) ~= "table" then E.global.WishFlex.spellDB = {} end
    return E.global.WishFlex.spellDB
end


local function IsSafeValue(val) return val ~= nil and (type(issecretvalue) ~= "function" or not issecretvalue(val)) end

local function GetBaseSpellFast(spellID)
    if not IsSafeValue(spellID) then return nil end
    if BaseSpellCache[spellID] == nil then
        local base = spellID
        pcall(function() if C_Spell and C_Spell.GetBaseSpell then base = C_Spell.GetBaseSpell(spellID) or spellID end end)
        BaseSpellCache[spellID] = base
    end
    return BaseSpellCache[spellID]
end

local function MatchesSpellID(info, targetID)
    if not info then return false end
    if IsSafeValue(info.spellID) and (info.spellID == targetID or info.overrideSpellID == targetID) then return true end
    if info.linkedSpellIDs then for i = 1, #info.linkedSpellIDs do if IsSafeValue(info.linkedSpellIDs[i]) and info.linkedSpellIDs[i] == targetID then return true end end end
    return GetBaseSpellFast(info.spellID) == targetID
end

local function VerifyAuraAlive(checkID, checkUnit)
    if not IsSafeValue(checkID) then return false end
    local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(checkUnit, checkID)
    return auraData ~= nil
end

function mod:GetSpellCatalog()
    local cooldowns, auras = {}, {}
    local seen = {}
    local function processInfo(info, isAura)
        if not info then return end
        local base = info.spellID or 0
        local linked = info.linkedSpellIDs and info.linkedSpellIDs[1]
        local spellID = linked or info.overrideSpellID or (base > 0 and base) or nil
        if spellID and spellID > 0 and not seen[spellID] then
            local name = nil; local icon = nil
            pcall(function() local sInfo = C_Spell.GetSpellInfo(spellID); if sInfo then name = sInfo.name; icon = sInfo.iconID end end)
            if not name then pcall(function() name = C_Spell.GetSpellName(spellID) end) end
            if not icon then pcall(function() icon = C_Spell.GetSpellTexture(spellID) end) end
            if name then seen[spellID] = true; local entry = { spellID = spellID, name = name, icon = icon or 134400 }; if isAura then auras[#auras + 1] = entry else cooldowns[#cooldowns + 1] = entry end end
        end
    end

    local viewers = { {name = "BuffIconCooldownViewer", isAura = true}, {name = "BuffBarCooldownViewer", isAura = true}, {name = "EssentialCooldownViewer", isAura = false}, {name = "UtilityCooldownViewer", isAura = false} }
    for _, vData in ipairs(viewers) do
        local viewer = _G[vData.name]
        if viewer then
            pcall(function()
                if viewer.itemFramePool then for frame in viewer.itemFramePool:EnumerateActive() do local cdID = frame.cooldownID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID); if cdID then processInfo(C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID), vData.isAura) end end
                else for _, child in ipairs({ viewer:GetChildren() }) do local cdID = child.cooldownID or (child.cooldownInfo and child.cooldownInfo.cooldownID); if cdID then processInfo(C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID), vData.isAura) end end end
            end)
        end
    end
    table.sort(cooldowns, function(a, b) return a.name < b.name end); table.sort(auras, function(a, b) return a.name < b.name end)
    return cooldowns, auras
end

function mod:ShowSpellSelectionWindow()
    local cooldowns, auras = self:GetSpellCatalog()
    local frame = AceGUI:Create("Frame"); frame:SetTitle("WishFlex: AuraGlow 扫描器"); frame:SetLayout("Fill"); frame:SetWidth(450); frame:SetHeight(500); frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    local tabGroup = AceGUI:Create("TabGroup"); tabGroup:SetLayout("Fill"); tabGroup:SetTabs({{text = "增益状态 (Buff)", value = "auras"}, {text = "冷却技能 (Cooldown)", value = "cooldowns"}})

    local function CreateEntry(scroll, item, isAura)
        local row = AceGUI:Create("InteractiveLabel"); row:SetText(" " .. item.name .. "  |cff888888(ID: " .. item.spellID .. ")|r"); row:SetImage(item.icon); row:SetImageSize(28, 28); row:SetFontObject(GameFontHighlight); row:SetFullWidth(true)
        row:SetCallback("OnClick", function()
            local idStr = tostring(item.spellID)
            local sDB = GetSpellDB()
            if not sDB[idStr] then
                local currentSpecID = 0; pcall(function() currentSpecID = GetSpecializationInfo(GetSpecialization()) or 0 end)
                sDB[idStr] = { buffID = item.spellID, class = playerClass, spec = currentSpecID, hideOriginal = true }
            end
            local d = sDB[idStr]
            
            d.class = playerClass 
            
            if not d.auraGlow then d.auraGlow = { glowEnable = true, iconEnable = false, iconGlowEnable = true, duration = 0 } end
            mod.selectedSpell = idStr
            mod:UpdateGlows(true)
            local CC = WUI:GetModule('CooldownCustom', true); if CC and CC.TriggerLayout then CC:TriggerLayout() end
            
            if E.Libs.AceConfigRegistry then E.Libs.AceConfigRegistry:NotifyChange("ElvUI") end
            if E.Libs.AceConfigDialog then E.Libs.AceConfigDialog:SelectGroup("ElvUI", "WishFlex", "cdmanager", "auraglow", "spellManagement") end
            frame:Hide()
        end)
        row:SetCallback("OnEnter", function(widget) GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPRIGHT"); GameTooltip:SetSpellByID(item.spellID); GameTooltip:Show() end)
        row:SetCallback("OnLeave", function() GameTooltip:Hide() end)
        scroll:AddChild(row)
    end

    tabGroup:SetCallback("OnGroupSelected", function(container, event, group)
        container:ReleaseChildren()
        local scroll = AceGUI:Create("ScrollFrame"); scroll:SetLayout("Flow"); container:AddChild(scroll)
        local label = AceGUI:Create("Label"); label:SetText("点击条目添加到监控。\n提示：请在战斗中或拥有BUFF/技能冷却时打开此界面。\n\n"); label:SetFullWidth(true); label:SetFontObject(GameFontNormal); scroll:AddChild(label)
        local list = (group == "auras") and auras or cooldowns; local isAura = (group == "auras")
        if #list == 0 then
            local emptyLabel = AceGUI:Create("Label"); emptyLabel:SetText("当前目录为空。"); emptyLabel:SetFullWidth(true); scroll:AddChild(emptyLabel)
        else for _, item in ipairs(list) do CreateEntry(scroll, item, isAura) end end
    end)
    frame:AddChild(tabGroup); tabGroup:SelectTab("auras")
end

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.cdmanager = WUI.OptionsArgs.cdmanager or { order = 20, type = "group", name = "|cff00e5cc冷却管理器|r", childGroups = "tab", args = {} }
    
    local args = WUI.OptionsArgs.cdmanager.args
    args.auraglow = {
        order = 7, type = "group", name = "|cff00ff00高亮与独立图标(AuraGlow)|r",
        get = function(info) return E.db.WishFlex.auraGlow[info[#info]] end,
        set = function(info, v) E.db.WishFlex.auraGlow[info[#info]] = v; mod:UpdateGlows(true) end,
        args = {
            enable = { order = 1, type = "toggle", name = "启用" },
            desc = { order = 3, type = "description", name = "|cff00ffcc触发机制提示：|r\n【技能槽发光覆盖】和【独立图标】是三个完全独立的开关系统，你可以任意组合。\n" },
            spellManagement = {
                order = 4, type = "group", name = "技能与BUFF", guiInline = true,
                args = {
                    openScanner = { order = 1, type = "execute", name = "1. 快捷添加", desc = "可视化快速添加监控。", func = function() mod:ShowSpellSelectionWindow() end },
                    addSpell = { order = 1.5, type = "input", name = "手动添加技能ID", get = function() return "" end, set = function(_, v) local id = tonumber(v) if id then local sDB = GetSpellDB() if not sDB[tostring(id)] then sDB[tostring(id)] = { buffID = id, class = playerClass, hideOriginal = true } end if not sDB[tostring(id)].auraGlow then sDB[tostring(id)].auraGlow = { glowEnable = true, iconEnable = false, iconGlowEnable = true, duration = 0 } end mod.selectedSpell = tostring(id); mod:UpdateGlows(true) end end },
                    selectSpell = { 
                        order = 2, type = "select", name = "2. 管理已添加的监控", 
                        -- (这里的 values, get, set 逻辑保持不变)
                        values = function() 
                            local vals = {} 
                            local currentSpecID = 0
                            pcall(function() currentSpecID = GetSpecializationInfo(GetSpecialization()) or 0 end)
                            for k, v in pairs(GetSpellDB()) do 
                                if v.auraGlow and (not v.class or v.class == "ALL" or v.class == playerClass) then
                                    local sSpec = v.spec or 0
                                    if sSpec == 0 or sSpec == currentSpecID then
                                        local id = tonumber(k)
                                        vals[k] = (C_Spell.GetSpellName(id) or "未知技能") .. " (" .. k .. ")" 
                                    end
                                end
                            end 
                            return vals 
                        end,
                        get = function() return mod.selectedSpell end, 
                        set = function(_, v) mod.selectedSpell = v end 
                    },
                    
                    glowEnable = { order = 3.1, type = "toggle", name = "覆盖原生技能发光", desc = "生成一个高亮的图标直接覆盖在褪色的原技能上方，阻挡多余倒数文本并产生发光。（如果没有找到对应的技能框，则自动隐藏）", get = function() local d = mod.selectedSpell and GetSpellDB()[mod.selectedSpell]; return d and d.auraGlow and d.auraGlow.glowEnable or false end, set = function(_, v) if mod.selectedSpell then GetSpellDB()[mod.selectedSpell].auraGlow.glowEnable = v; mod:UpdateGlows(true) end end, disabled = function() return not mod.selectedSpell end },
                    iconEnable = { order = 3.2, type = "toggle", name = "独立实体图标", desc = "单独生成一个带有边框的真实图标在右侧锚点组。", get = function() local d = mod.selectedSpell and GetSpellDB()[mod.selectedSpell]; return d and d.auraGlow and d.auraGlow.iconEnable or false end, set = function(_, v) if mod.selectedSpell then GetSpellDB()[mod.selectedSpell].auraGlow.iconEnable = v; mod:UpdateGlows(true) end end, disabled = function() return not mod.selectedSpell end },
                    iconGlowEnable = { order = 3.3, type = "toggle", name = "独立图标是否发光", desc = "如果启用了上面的生成独立图标，此选项控制该独立图标自身是否带有光效。", get = function() local d = mod.selectedSpell and GetSpellDB()[mod.selectedSpell]; return d and d.auraGlow and d.auraGlow.iconGlowEnable ~= false end, set = function(_, v) if mod.selectedSpell then GetSpellDB()[mod.selectedSpell].auraGlow.iconGlowEnable = v; mod:UpdateGlows(true) end end, disabled = function() local d = mod.selectedSpell and GetSpellDB()[mod.selectedSpell]; return not d or not d.auraGlow or not d.auraGlow.iconEnable end },
                    
                    spec = { 
                        order = 3.4, type = "select", name = "所属专精", desc = "切换不在设定范围内的专精时，此监控将自动隐藏。",
                        values = function() local vals = { [0] = "通用 (所有专精)" }; for i = 1, 4 do local id, name = GetSpecializationInfo(i); if id and name then vals[id] = name end end; return vals end,
                        get = function() local d = mod.selectedSpell and GetSpellDB()[mod.selectedSpell]; return d and d.spec or 0 end, 
                        set = function(_,v) if mod.selectedSpell then GetSpellDB()[mod.selectedSpell].spec = v; mod:UpdateGlows(true) end end, 
                        disabled = function() return not mod.selectedSpell end 
                    },

                    hideOriginal = { order = 3.5, type = "toggle", name = "隐藏增益", desc = "开启后交由系统无污染接管隐藏。", get = function() local d = mod.selectedSpell and GetSpellDB()[mod.selectedSpell]; return d and d.hideOriginal ~= false end, set = function(_,v) if mod.selectedSpell then GetSpellDB()[mod.selectedSpell].hideOriginal = v; local CC = WUI:GetModule('CooldownCustom', true); if CC and CC.TriggerLayout then CC:TriggerLayout() end end end, disabled = function() return not mod.selectedSpell end },
                    editBuff = { order = 4, type = "input", name = "对应的触发BuffID", get = function() local d = mod.selectedSpell and GetSpellDB()[mod.selectedSpell]; return d and tostring(d.buffID or mod.selectedSpell) or "" end, set = function(_, v) local id = tonumber(v); if mod.selectedSpell and id then GetSpellDB()[mod.selectedSpell].buffID = id; mod:UpdateGlows(true) end end, disabled = function() return not mod.selectedSpell end },
                    trackMode = { order = 5, type = "select", name = "持续追踪模式", values = { ["auto"] = "可追踪增益", ["manual"] = "自定义倒数" }, get = function() local d = mod.selectedSpell and GetSpellDB()[mod.selectedSpell]; return (d and d.auraGlow and d.auraGlow.duration and d.auraGlow.duration > 0) and "manual" or "auto" end, set = function(_, v) if mod.selectedSpell then local d = GetSpellDB()[mod.selectedSpell].auraGlow; if v == "auto" then d.duration = 0 else d.duration = 20 end mod:UpdateGlows(true) end end, disabled = function() return not mod.selectedSpell end },
                    editDuration = { order = 6, type = "input", name = "手动持续时间", get = function() local d = mod.selectedSpell and GetSpellDB()[mod.selectedSpell]; return d and tostring(d.auraGlow and d.auraGlow.duration or 0) or "0" end, set = function(_, v) local val = tonumber(v); if mod.selectedSpell and val then GetSpellDB()[mod.selectedSpell].auraGlow.duration = val; mod:UpdateGlows(true) end end, disabled = function() local d = mod.selectedSpell and GetSpellDB()[mod.selectedSpell]; return not (d and d.auraGlow and d.auraGlow.duration and d.auraGlow.duration > 0) end },
                    deleteSpell = { order = 7, type = "execute", name = "删除选中监控", func = function() if mod.selectedSpell then local id = tonumber(mod.selectedSpell); GetSpellDB()[mod.selectedSpell].auraGlow = nil; if not GetSpellDB()[mod.selectedSpell].auraBar then GetSpellDB()[mod.selectedSpell] = nil end mod.selectedSpell = nil; if OverlayFrames[id] then LCG.PixelGlow_Stop(OverlayFrames[id], "WishAuraOverlayGlow"); OverlayFrames[id]:Hide() end if IndependentFrames[id] then LCG.PixelGlow_Stop(IndependentFrames[id], "WishAuraIndGlow"); IndependentFrames[id]:Hide() end; local CC = WUI:GetModule('CooldownCustom', true); if CC and CC.TriggerLayout then CC:TriggerLayout() end; mod:UpdateGlows(true) end end, disabled = function() return not mod.selectedSpell end }
                }
            },
            independentGroup = {
                order = 4.5, type = "group", name = "独立图标设置", guiInline = true,
                get = function(info) return E.db.WishFlex.auraGlow.independent[info[#info]] end,
                set = function(info, v) E.db.WishFlex.auraGlow.independent[info[#info]] = v; mod:UpdateGlows(true) end,
                args = {
                    size = { order = 1, type = "range", name = "尺寸", min = 10, max = 100, step = 1 }, -- 统一为尺寸
                    gap = { order = 2, type = "range", name = "间距", min = 0, max = 30, step = 1 }, -- 统一为间距
                    growth = { order = 3, type = "select", name = "增长方向", values = { ["LEFT"] = "左", ["RIGHT"] = "右", ["UP"] = "上", ["DOWN"] = "下", ["CENTER_HORIZONTAL"] = "居中" } },
                }
            },
            glowGroup = {
                order = 5, type = "group", name = "全局发光样式", guiInline = true,
                args = {
                    glowEnable = { order = 1, type = "toggle", name = "启用", desc = "控制发光材质的全局总开关。若关闭，则只有图标和时间，不会有任何边框发光特效。" },
                    glowType = { order = 2, type = "select", name = "发光类型", values = { pixel = "像素发光", autocast = "自动施法发光", button = "按钮发光", proc = "触发发光" } },
                    glowUseCustomColor = { order = 3, type = "toggle", name = "使用自定义颜色" },
                    glowColor = { order = 4, type = "color", name = "颜色", hasAlpha = true, get = function() local t = E.db.WishFlex.auraGlow.glowColor; return t and t.r or 1, t and t.g or 1, t and t.b or 1, t and t.a or 1 end, set = function(_, r, g, b, a) E.db.WishFlex.auraGlow.glowColor = {r=r,g=g,b=b,a=a}; mod:UpdateGlows(true) end, disabled = function() return not E.db.WishFlex.auraGlow.glowUseCustomColor end },
                    glowPixelLines = { order = 10, type = "range", name = "线条数", min = 1, max = 20, step = 1, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "pixel" end },
                    glowPixelFrequency = { order = 11, type = "range", name = "频率", min = -2, max = 2, step = 0.05, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "pixel" end },
                    glowPixelLength = { order = 12, type = "range", name = "长度(0为自动)", min = 0, max = 20, step = 1, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "pixel" end },
                    glowPixelThickness = { order = 13, type = "range", name = "粗细", min = 1, max = 10, step = 1, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "pixel" end },
                    glowPixelXOffset = { order = 14, type = "range", name = "X偏移", min = -20, max = 20, step = 1, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "pixel" end }, -- 统一为 X偏移
                    glowPixelYOffset = { order = 15, type = "range", name = "Y偏移", min = -20, max = 20, step = 1, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "pixel" end }, -- 统一为 Y偏移
                    glowAutocastParticles = { order = 20, type = "range", name = "粒子数", min = 1, max = 16, step = 1, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "autocast" end },
                    glowAutocastFrequency = { order = 21, type = "range", name = "频率", min = -2, max = 2, step = 0.05, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "autocast" end },
                    glowAutocastScale = { order = 22, type = "range", name = "缩放", min = 0.5, max = 3, step = 0.05, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "autocast" end },
                    glowAutocastXOffset = { order = 23, type = "range", name = "X偏移", min = -20, max = 20, step = 1, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "autocast" end }, -- 统一为 X偏移
                    glowAutocastYOffset = { order = 24, type = "range", name = "Y偏移", min = -20, max = 20, step = 1, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "autocast" end }, -- 统一为 Y偏移
                    glowButtonFrequency = { order = 30, type = "range", name = "频率(0为默认)", min = 0, max = 2, step = 0.05, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "button" end },
                    glowProcDuration = { order = 40, type = "range", name = "持续时间", min = 0.1, max = 5, step = 0.1, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "proc" end },
                    glowProcXOffset = { order = 41, type = "range", name = "X偏移", min = -20, max = 20, step = 1, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "proc" end }, -- 统一为 X偏移
                    glowProcYOffset = { order = 42, type = "range", name = "Y偏移", min = -20, max = 20, step = 1, hidden = function() return E.db.WishFlex.auraGlow.glowType ~= "proc" end }, -- 统一为 Y偏移
                }
            },
            textGroup = {
                order = 6, type = "group", name = "倒数时间文本", guiInline = true,
                get = function(info) return E.db.WishFlex.auraGlow.text[info[#info]] end,
                set = function(info, v) E.db.WishFlex.auraGlow.text[info[#info]] = v; mod:UpdateGlows(true) end,
                args = {
                    font = { order = 1, type = "select", name = "字体", dialogControl = 'LSM30_Font', values = LSM:HashTable("font") },
                    fontSize = { order = 2, type = "range", name = "字体大小", min = 8, max = 60, step = 1 }, -- 统一为字体大小
                    fontOutline = { order = 3, type = "select", name = "字体描边", values = { ["NONE"] = "无", ["OUTLINE"] = "OUTLINE", ["MONOCHROMEOUTLINE"] = "MONOCROMEOUTLINE", ["THICKOUTLINE"] = "THICKOUTLINE" } }, -- 统一为字体描边
                    color = { order = 4, type = "color", name = "颜色", get = function() local c = E.db.WishFlex.auraGlow.text.color; return c.r, c.g, c.b end, set = function(_, r, g, b) E.db.WishFlex.auraGlow.text.color = {r=r, g=g, b=b}; mod:UpdateGlows(true) end },
                    textAnchor = { order = 4.5, type = "select", name = "锚点", values = { ["TOPLEFT"] = "左上", ["TOP"] = "正上", ["TOPRIGHT"] = "右上", ["LEFT"] = "正左", ["CENTER"] = "居中", ["RIGHT"] = "正右", ["BOTTOMLEFT"] = "左下", ["BOTTOM"] = "正下", ["BOTTOMRIGHT"] = "右下" } }, -- 统一为锚点
                    offsetX = { order = 5, type = "range", name = "X偏移", min = -50, max = 50, step = 1 }, -- 统一为 X偏移
                    offsetY = { order = 6, type = "range", name = "Y偏移", min = -50, max = 50, step = 1 }, -- 统一为 Y偏移
                }
            },
            independentTextGroup = {
                order = 7, type = "group", name = "独立图标文本", guiInline = true,
                get = function(info) return E.db.WishFlex.auraGlow.independentText[info[#info]] end,
                set = function(info, v) E.db.WishFlex.auraGlow.independentText[info[#info]] = v; mod:UpdateGlows(true) end,
                args = {
                    enable = { order = 1, type = "toggle", name = "启用", desc = "开启后，独立图标将使用此处的文本设置，不再与覆盖层共用。" },
                    font = { order = 2, type = "select", name = "字体", dialogControl = 'LSM30_Font', values = LSM:HashTable("font"), disabled = function() return not E.db.WishFlex.auraGlow.independentText.enable end },
                    fontSize = { order = 3, type = "range", name = "字体大小", min = 8, max = 60, step = 1, disabled = function() return not E.db.WishFlex.auraGlow.independentText.enable end }, -- 统一
                    fontOutline = { order = 4, type = "select", name = "字体描边", values = { ["NONE"] = "无", ["OUTLINE"] = "OUTLINE", ["MONOCHROMEOUTLINE"] = "MONOCROMEOUTLINE", ["THICKOUTLINE"] = "THICKOUTLINE" }, disabled = function() return not E.db.WishFlex.auraGlow.independentText.enable end }, -- 统一
                    color = { order = 5, type = "color", name = "颜色", get = function() local c = E.db.WishFlex.auraGlow.independentText.color; return c.r, c.g, c.b end, set = function(_, r, g, b) E.db.WishFlex.auraGlow.independentText.color = {r=r, g=g, b=b}; mod:UpdateGlows(true) end, disabled = function() return not E.db.WishFlex.auraGlow.independentText.enable end },
                    textAnchor = { order = 5.5, type = "select", name = "锚点", values = { ["TOPLEFT"] = "左上", ["TOP"] = "正上", ["TOPRIGHT"] = "右上", ["LEFT"] = "正左", ["CENTER"] = "居中", ["RIGHT"] = "正右", ["BOTTOMLEFT"] = "左下", ["BOTTOM"] = "正下", ["BOTTOMRIGHT"] = "右下" }, disabled = function() return not E.db.WishFlex.auraGlow.independentText.enable end }, -- 统一
                    offsetX = { order = 6, type = "range", name = "X偏移", min = -50, max = 50, step = 1, disabled = function() return not E.db.WishFlex.auraGlow.independentText.enable end }, -- 统一
                    offsetY = { order = 7, type = "range", name = "Y偏移", min = -50, max = 50, step = 1, disabled = function() return not E.db.WishFlex.auraGlow.independentText.enable end }, -- 统一
                }
            }
        }
    }
end


local function GetCropCoords(w, h)
    local l, r, t, b = unpack(E.TexCoords)
    if not w or not h or h == 0 or w == 0 then return l, r, t, b end
    local ratio = w / h
    if math.abs(ratio - 1) < 0.05 then return l, r, t, b end
    if ratio > 1 then
        local crop = (1 - (1/ratio)) / 2; return l, r, t + (b - t) * crop, b - (b - t) * crop
    else
        local crop = (1 - ratio) / 2; return l + (r - l) * crop, r - (r - l) * crop, t, b
    end
end

local function SnapOverlayToFrame(overlay, sourceFrame)
    if sourceFrame and sourceFrame:IsVisible() then
        if sourceFrame.GetCenter then
            local cx, cy = sourceFrame:GetCenter()
            if cx and cy then
                local scale = sourceFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
                overlay:SetScale(scale)
                local rawW, rawH = 45, 45
                pcall(function() rawW = sourceFrame:GetWidth(); rawH = sourceFrame:GetHeight() end)
                if rawW < 1 or rawH < 1 then rawW, rawH = 45, 45 end
                overlay:SetSize(rawW, rawH)
                if overlay.iconTex then overlay.iconTex:SetTexCoord(GetCropCoords(rawW, rawH)) end
                overlay:ClearAllPoints()
                overlay:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
                
                overlay:SetFrameStrata("HIGH")
                overlay:SetFrameLevel(sourceFrame:GetFrameLevel() + 20)
                if overlay.cd then overlay.cd:SetFrameLevel(overlay:GetFrameLevel() + 1) end
                
                return true
            end
        end
    end
    return false
end


local function SyncTextAndVisuals(frame)
    local globalCfg = E.db.WishFlex.auraGlow.text
    local indCfg = E.db.WishFlex.auraGlow.independentText
    local cfg = (frame.isIndependent and indCfg.enable) and indCfg or globalCfg

    local fontPath = LSM:Fetch('font', cfg.font)
    if frame.lastFont ~= fontPath or frame.lastSize ~= cfg.fontSize or frame.lastOutline ~= cfg.fontOutline then
        frame.durationText:SetFont(fontPath, cfg.fontSize, cfg.fontOutline)
        frame.lastFont, frame.lastSize, frame.lastOutline = fontPath, cfg.fontSize, cfg.fontOutline
    end
    if frame.lastR ~= cfg.color.r or frame.lastG ~= cfg.color.g or frame.lastB ~= cfg.color.b then
        frame.durationText:SetTextColor(cfg.color.r, cfg.color.g, cfg.color.b)
        frame.lastR, frame.lastG, frame.lastB = cfg.color.r, cfg.color.g, cfg.color.b
    end
    
    local anchor = cfg.textAnchor or "CENTER"
    if frame.lastOffsetX ~= cfg.offsetX or frame.lastOffsetY ~= cfg.offsetY or frame.lastAnchor ~= anchor then
        frame.durationText:ClearAllPoints()
        frame.durationText:SetPoint(anchor, frame, anchor, cfg.offsetX, cfg.offsetY)
        frame.lastOffsetX, frame.lastOffsetY = cfg.offsetX, cfg.offsetY
        frame.lastAnchor = anchor
    end
end

local function ApplyCustomGlowToFrame(frame, glowKey)
    local cfg = E.db.WishFlex.auraGlow
    LCG.PixelGlow_Stop(frame, glowKey)
    LCG.AutoCastGlow_Stop(frame, glowKey)
    LCG.ButtonGlow_Stop(frame)
    LCG.ProcGlow_Stop(frame, glowKey)

    if not cfg.glowEnable then return end
    
    local c = cfg.glowColor or {r=1, g=1, b=1, a=1}
    local colorArr = cfg.glowUseCustomColor and {c.r, c.g, c.b, c.a} or nil
    local t = cfg.glowType or "pixel"
    
    if t == "pixel" then
        local len = cfg.glowPixelLength; if len == 0 then len = nil end
        LCG.PixelGlow_Start(frame, colorArr, cfg.glowPixelLines, cfg.glowPixelFrequency, len, cfg.glowPixelThickness, cfg.glowPixelXOffset, cfg.glowPixelYOffset, false, glowKey)
    elseif t == "autocast" then
        LCG.AutoCastGlow_Start(frame, colorArr, cfg.glowAutocastParticles, cfg.glowAutocastFrequency, cfg.glowAutocastScale, cfg.glowAutocastXOffset, cfg.glowAutocastYOffset, glowKey)
    elseif t == "button" then
        local freq = cfg.glowButtonFrequency; if freq == 0 then freq = nil end
        LCG.ButtonGlow_Start(frame, colorArr, freq)
    elseif t == "proc" then
        LCG.ProcGlow_Start(frame, {color = colorArr, duration = cfg.glowProcDuration, xOffset = cfg.glowProcXOffset, yOffset = cfg.glowProcYOffset, key = glowKey})
    end
end

local function ToggleGlow(frame, glowKey, shouldGlow, forceRefresh)
    if not frame then return end
    if shouldGlow then
        if not frame._isGlowing or forceRefresh then
            frame._isGlowing = true
            ApplyCustomGlowToFrame(frame, glowKey)
        end
    else
        if frame._isGlowing or forceRefresh then
            frame._isGlowing = false
            LCG.PixelGlow_Stop(frame, glowKey)
            LCG.AutoCastGlow_Stop(frame, glowKey)
            LCG.ButtonGlow_Stop(frame)
            LCG.ProcGlow_Stop(frame, glowKey)
        end
    end
end

local function CreateBaseFrame(spellID, isIndependent)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("HIGH") 
    
    if isIndependent then frame:SetTemplate("Default") end
    
    local iconTex = frame:CreateTexture(nil, "ARTWORK")
    iconTex:SetInside(frame)
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if spellInfo and spellInfo.iconID then iconTex:SetTexture(spellInfo.iconID) end
    frame.iconTex = iconTex
    
    local cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cd:SetAllPoints()
    cd:SetDrawSwipe(true)  
    cd:SetReverse(true)
    cd:SetDrawEdge(false); cd:SetDrawBling(false); cd:SetHideCountdownNumbers(false)
    cd.noCooldownOverride = true; cd.noOCC = true; cd.skipElvUICooldown = true
    frame.cd = cd
    
    for _, region in pairs({cd:GetRegions()}) do
        if region:IsObjectType("FontString") then frame.durationText = region break end
    end
    if not frame.durationText then frame.durationText = cd:CreateFontString(nil, "OVERLAY") end
    
    return frame
end

local function GetOverlay(spellID)
    if not OverlayFrames[spellID] then
        OverlayFrames[spellID] = CreateBaseFrame(spellID, false)
        OverlayFrames[spellID]:SetScript("OnUpdate", function(self)
            if self.sourceFrame and SnapOverlayToFrame(self, self.sourceFrame) then
                SyncTextAndVisuals(self)
            else
                self:Hide()
            end
        end)
    end
    return OverlayFrames[spellID]
end

local function GetIndependentIcon(spellID)
    if not IndependentFrames[spellID] then
        IndependentFrames[spellID] = CreateBaseFrame(spellID, true)
        IndependentFrames[spellID]:SetScript("OnUpdate", function(self) SyncTextAndVisuals(self) end)
    end
    return IndependentFrames[spellID]
end

function mod:UpdateGlows(forceUpdate)
    if not E.db.WishFlex.auraGlow.enable then 
        for _, f in pairs(OverlayFrames) do ToggleGlow(f, "WishAuraOverlayGlow", false, true); f:Hide() end
        for _, f in pairs(IndependentFrames) do ToggleGlow(f, "WishAuraIndGlow", false, true); f:Hide() end
        return 
    end
    
    mod.trackedAuras = mod.trackedAuras or {}
    mod.manualTrackers = mod.manualTrackers or {}

    wipe(activeSkillFrames)
    wipe(activeBuffFrames)
    wipe(targetAuraCache)

    for _, viewer in ipairs({_G.EssentialCooldownViewer, _G.UtilityCooldownViewer}) do
        if viewer and viewer.itemFramePool then
            for f in viewer.itemFramePool:EnumerateActive() do
                if f:IsVisible() and f.cooldownInfo then activeSkillFrames[#activeSkillFrames+1] = f end
            end
        end
    end

    for _, viewer in ipairs({_G.BuffIconCooldownViewer, _G.BuffBarCooldownViewer}) do
        if viewer and viewer.itemFramePool then
            for f in viewer.itemFramePool:EnumerateActive() do
                if f.cooldownInfo then activeBuffFrames[#activeBuffFrames+1] = f end
            end
        end
    end

    local targetScanned = false
    local validCombatState = InCombatLockdown() or (UnitExists("target") and UnitCanAttack("player", "target"))
    local activeIndependentIcons = {}

    local currentSpecID = 0
    pcall(function() currentSpecID = GetSpecializationInfo(GetSpecialization()) or 0 end)

    for spellIDStr, spellData in pairs(GetSpellDB()) do
        local spellID = tonumber(spellIDStr)
        if spellData.auraGlow and (not spellData.class or spellData.class == "ALL" or spellData.class == playerClass) then
            local sSpec = spellData.spec or 0
            if sSpec == 0 or sSpec == currentSpecID then
                local wantGlow = spellData.auraGlow.glowEnable
                local wantIcon = spellData.auraGlow.iconEnable
                local wantIconGlow = spellData.auraGlow.iconGlowEnable ~= false 

                if wantGlow or wantIcon then
                    local buffID = spellData.buffID or spellID
                    local customDuration = spellData.auraGlow.duration or 0
                    
                    local skillFrame = nil
                    if wantGlow then
                        for i = 1, #activeSkillFrames do
                            if MatchesSpellID(activeSkillFrames[i].cooldownInfo, spellID) then skillFrame = activeSkillFrames[i]; break end
                        end
                    end

                    if wantIcon or (wantGlow and skillFrame and skillFrame:IsVisible()) then
                        local auraActive = false
                        local auraInstanceID = nil
                        local unit = "player"
                        
                        if customDuration > 0 then
                            local tracker = mod.manualTrackers[buffID]
                            if tracker and GetTime() < (tracker.start + tracker.dur) then auraActive = true else mod.manualTrackers[buffID] = nil end
                        else
                            local buffFrame = nil
                            for i = 1, #activeBuffFrames do
                                if MatchesSpellID(activeBuffFrames[i].cooldownInfo, buffID) then buffFrame = activeBuffFrames[i]; break end
                            end
                            if buffFrame then
                                local tempID = buffFrame.auraInstanceID; local tempUnit = buffFrame.auraDataUnit or "player"
                                if IsSafeValue(tempID) and VerifyAuraAlive(tempID, tempUnit) then
                                    auraInstanceID, unit, auraActive = tempID, tempUnit, true
                                    mod.trackedAuras[buffID] = mod.trackedAuras[buffID] or {}; mod.trackedAuras[buffID].id = auraInstanceID; mod.trackedAuras[buffID].unit = unit
                                end
                            end
                            if not auraActive and mod.trackedAuras[buffID] then
                                local t = mod.trackedAuras[buffID]
                                if VerifyAuraAlive(t.id, t.unit) then auraActive, auraInstanceID, unit = true, t.id, t.unit else mod.trackedAuras[buffID] = nil end
                            end
                            if not auraActive then
                                local auraData = C_UnitAuras.GetPlayerAuraBySpellID(buffID)
                                if auraData and IsSafeValue(auraData.auraInstanceID) then
                                    auraActive, auraInstanceID, unit = true, auraData.auraInstanceID, "player"
                                    mod.trackedAuras[buffID] = mod.trackedAuras[buffID] or {}; mod.trackedAuras[buffID].id = auraInstanceID; mod.trackedAuras[buffID].unit = unit
                                elseif UnitExists("target") then
                                    if not targetScanned then
                                        targetScanned = true
                                        for _, filter in ipairs({"HELPFUL", "HARMFUL"}) do
                                            for i = 1, 40 do
                                                local aura = C_UnitAuras.GetAuraDataByIndex("target", i, filter)
                                                if not aura then break end
                                                if IsSafeValue(aura.spellId) and IsSafeValue(aura.auraInstanceID) then targetAuraCache[aura.spellId] = aura.auraInstanceID end
                                            end
                                        end
                                    end
                                    if targetAuraCache[buffID] then
                                        auraActive, auraInstanceID, unit = true, targetAuraCache[buffID], "target"
                                        mod.trackedAuras[buffID] = mod.trackedAuras[buffID] or {}; mod.trackedAuras[buffID].id = auraInstanceID; mod.trackedAuras[buffID].unit = unit
                                    end
                                end
                            end
                        end
                        
                        if auraActive and validCombatState then
                            local durObj = nil
                            if customDuration > 0 then
                                local tracker = mod.manualTrackers[buffID]
                                if tracker then durObj = { start = tracker.start, dur = tracker.dur } end
                            elseif auraInstanceID then
                                durObj = C_UnitAuras.GetAuraDuration(unit, auraInstanceID)
                            end

                            if wantIcon then
                                local indIcon = GetIndependentIcon(spellID)
                                indIcon:Show()
                                if durObj and durObj.dur then pcall(function() indIcon.cd:SetCooldown(durObj.start, durObj.dur) end)
                                elseif durObj then pcall(function() indIcon.cd:SetCooldownFromDurationObject(durObj) end) end
                                
                                ToggleGlow(indIcon, "WishAuraIndGlow", wantIconGlow, forceUpdate)
                                activeIndependentIcons[#activeIndependentIcons+1] = indIcon
                            else
                                if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); IndependentFrames[spellID]:Hide() end
                            end

                            if wantGlow and skillFrame and skillFrame:IsVisible() then
                                local overlay = GetOverlay(spellID)
                                overlay.sourceFrame = skillFrame
                                if SnapOverlayToFrame(overlay, skillFrame) then
                                    overlay:Show()
                                    if durObj and durObj.dur then pcall(function() overlay.cd:SetCooldown(durObj.start, durObj.dur) end)
                                    elseif durObj then pcall(function() overlay.cd:SetCooldownFromDurationObject(durObj) end) end
                                    ToggleGlow(overlay, "WishAuraOverlayGlow", true, forceUpdate)
                                else
                                    if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end
                                end
                            else
                                if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end
                            end
                            
                        else
                            if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); if OverlayFrames[spellID].cd then OverlayFrames[spellID].cd:Clear() end; OverlayFrames[spellID]:Hide() end
                            if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); if IndependentFrames[spellID].cd then IndependentFrames[spellID].cd:Clear() end; IndependentFrames[spellID]:Hide() end
                        end
                    else
                        if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end
                        if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); IndependentFrames[spellID]:Hide() end
                    end
                else
                    if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end
                    if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); IndependentFrames[spellID]:Hide() end
                end
            else
                if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end
                if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); IndependentFrames[spellID]:Hide() end
            end
        else
            if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end
            if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); IndependentFrames[spellID]:Hide() end
        end
    end

    if mod.AuraGlowAnchor then
        local cfg = E.db.WishFlex.auraGlow.independent
        local s = cfg.size or 45; local gap = cfg.gap or 2; local growth = cfg.growth or "LEFT"
        local numIcons = #activeIndependentIcons
        
        local startX = 0
        if growth == "CENTER_HORIZONTAL" and numIcons > 0 then
            local totalWidth = (numIcons * s) + ((numIcons - 1) * gap)
            startX = - (totalWidth / 2) + (s / 2)
        end
        
        for i, icon in ipairs(activeIndependentIcons) do
            icon:ClearAllPoints()
            icon:SetScale(1)
            icon:SetSize(s, s)
            icon.iconTex:SetTexCoord(GetCropCoords(s, s))
            
            if growth == "CENTER_HORIZONTAL" then
                local currentOffsetX = startX + (i - 1) * (s + gap)
                icon:SetPoint("CENTER", mod.AuraGlowAnchor, "CENTER", currentOffsetX, 0)
            else
                if i == 1 then
                    icon:SetPoint("CENTER", mod.AuraGlowAnchor, "CENTER", 0, 0)
                else
                    local prev = activeIndependentIcons[i-1]
                    if growth == "LEFT" then icon:SetPoint("RIGHT", prev, "LEFT", -gap, 0)
                    elseif growth == "RIGHT" then icon:SetPoint("LEFT", prev, "RIGHT", gap, 0)
                    elseif growth == "UP" then icon:SetPoint("BOTTOM", prev, "TOP", 0, gap)
                    elseif growth == "DOWN" then icon:SetPoint("TOP", prev, "BOTTOM", 0, -gap) end
                end
            end
        end
    end
end

function mod:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellID)
    if unit ~= "player" or not E.db.WishFlex.auraGlow.enable then return end
    
    local currentSpecID = 0
    pcall(function() currentSpecID = GetSpecializationInfo(GetSpecialization()) or 0 end)

    local triggered = false
    for sIDStr, spellData in pairs(GetSpellDB()) do
        if spellData.auraGlow and (spellData.auraGlow.glowEnable or spellData.auraGlow.iconEnable) and (not spellData.class or spellData.class == "ALL" or spellData.class == playerClass) then
            local sSpec = spellData.spec or 0
            if sSpec == 0 or sSpec == currentSpecID then
                local sID = tonumber(sIDStr)
                local bID = spellData.buffID or sID
                local dur = spellData.auraGlow.duration or 0
                
                if dur > 0 and (spellID == sID or spellID == bID) then
                    mod.manualTrackers = mod.manualTrackers or {}
                    mod.manualTrackers[bID] = { start = GetTime(), dur = dur }
                    triggered = true
                end
            end
        end
    end
    if triggered then mod:UpdateGlows() end
end

local updatePending = false
local function RequestUpdateGlows()
    if updatePending then return end
    updatePending = true
    local delay = InCombatLockdown() and 0.08 or 0.3
    C_Timer.After(delay, function() updatePending = false; mod:UpdateGlows() end)
end

local function SafeHook(object, funcName, callback)
    if object and object[funcName] and type(object[funcName]) == "function" then hooksecurefunc(object, funcName, callback) end
end

function mod:UNIT_AURA(event, unit)
    if not InCombatLockdown() and unit ~= "player" then return end
    if unit == "player" or unit == "target" then RequestUpdateGlows() end
end

function mod:OnCombatEvent() RequestUpdateGlows() end

function mod:MigrateData()
    local spellDB = GetSpellDB()
    if E.db.WishFlex and E.db.WishFlex.spellDB then
        for k, v in pairs(E.db.WishFlex.spellDB) do
            if not spellDB[k] then spellDB[k] = v end
        end
        E.db.WishFlex.spellDB = nil 
    end

    if E.db.WishFlex.auraGlow and E.db.WishFlex.auraGlow.spells then
        for k, v in pairs(E.db.WishFlex.auraGlow.spells) do
            local sid = tostring(k)
            if not spellDB[sid] then spellDB[sid] = { buffID = tonumber(k), class = "ALL", hideOriginal = true } end
            local oldDur = type(v) == "table" and v.duration or 0
            local oldBuffID = type(v) == "table" and v.buffID or tonumber(k)
            spellDB[sid].buffID = oldBuffID
            
            local gEn = true
            local iEn = false
            local igEn = true
            if type(v) == "table" then
                if v.attachMode == "independent" then gEn = false; iEn = true end
                if v.glowEnable ~= nil then gEn = v.glowEnable end
                if v.iconEnable ~= nil then iEn = v.iconEnable end
                if v.iconGlowEnable ~= nil then igEn = v.iconGlowEnable end
            end
            
            if not spellDB[sid].auraGlow then spellDB[sid].auraGlow = { glowEnable = gEn, iconEnable = iEn, iconGlowEnable = igEn, duration = oldDur } end
        end
        E.db.WishFlex.auraGlow.spells = nil 
    end
end

function mod:Initialize()
    self:MigrateData()
    InjectOptions()
    
    mod.AuraGlowAnchor = CreateFrame("Frame", "WishFlex_AuraGlowIconAnchor", E.UIParent)
    mod.AuraGlowAnchor:SetPoint("CENTER", E.UIParent, "CENTER", 180, 0)
    mod.AuraGlowAnchor:SetSize(45, 45)
    E:CreateMover(mod.AuraGlowAnchor, "WishFlexAuraGlowIconMover", "WishFlex: 独立图标实体组", nil, nil, nil, "ALL,WISHFLEX")
    
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnCombatEvent")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatEvent")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEvent")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnCombatEvent")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    
    local viewers = { _G.BuffIconCooldownViewer, _G.EssentialCooldownViewer, _G.UtilityCooldownViewer, _G.BuffBarCooldownViewer }
    for _, viewer in ipairs(viewers) do
        if viewer then
            SafeHook(viewer, "RefreshData", RequestUpdateGlows)
            SafeHook(viewer, "UpdateLayout", RequestUpdateGlows)
            SafeHook(viewer, "Layout", RequestUpdateGlows)
            if viewer.itemFramePool then
                SafeHook(viewer.itemFramePool, "Acquire", RequestUpdateGlows)
                SafeHook(viewer.itemFramePool, "Release", RequestUpdateGlows)
            end
        end
    end

    hooksecurefunc(E, "UpdateAll", function()
        mod:MigrateData()
        mod:UpdateGlows(true)
    end)
end
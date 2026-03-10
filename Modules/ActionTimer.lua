local E, L, V, P, G = unpack(ElvUI)
local LSM = E.Libs.LSM
local WUI = E:GetModule('WishFlex')
local mod = WUI:GetModule('AuraGlow', true) or WUI:NewModule('AuraGlow', 'AceHook-3.0', 'AceEvent-3.0')

local LCG = E.Libs and E.Libs.CustomGlow
if not LCG then LCG = LibStub and LibStub("LibCustomGlow-1.0", true) end

-- =========================================
-- [内存泄漏克星]：预分配静态池
-- =========================================
local activeSkillFrames = {}
local activeBuffFrames = {}
local targetAuraCache = {}
local BaseSpellCache = {}
mod.fastTrackedBuffs = {}

-- =========================================
-- 1. 初始化数据库
-- =========================================
P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.auraGlow = true
P["WishFlex"].auraGlow = {
    enable = true,
    showOnlyKnown = true, 
    spells = {
        ["107574"] = { buffID = 107574, duration = 0 }, ["1719"]   = { buffID = 1719,   duration = 0 }, 
        ["871"]    = { buffID = 871,    duration = 0 }, ["12975"]  = { buffID = 12975,  duration = 0 }, 
        ["118038"] = { buffID = 118038, duration = 0 }, ["23920"]  = { buffID = 23920,  duration = 0 }, 
        ["184364"] = { buffID = 184364, duration = 0 }, ["32736"]  = { buffID = 32736,  duration = 0 }, 
        ["31884"]  = { buffID = 31884,  duration = 0 }, ["231895"] = { buffID = 231895, duration = 0 }, 
        ["642"]    = { buffID = 642,    duration = 0 }, ["31850"]  = { buffID = 31850,  duration = 0 }, 
        ["86659"]  = { buffID = 86659,  duration = 0 }, ["498"]    = { buffID = 498,    duration = 0 }, 
        ["6940"]   = { buffID = 6940,   duration = 0 }, 
        ["19574"]  = { buffID = 19574,  duration = 0 }, ["288613"] = { buffID = 288613, duration = 0 }, 
        ["360952"] = { buffID = 360952, duration = 0 }, ["186265"] = { buffID = 186265, duration = 0 }, 
        ["264735"] = { buffID = 264735, duration = 0 }, 
        ["13750"]  = { buffID = 13750,  duration = 0 }, ["121471"] = { buffID = 121471, duration = 0 }, 
        ["185313"] = { buffID = 185313, duration = 0 }, ["31224"]  = { buffID = 31224,  duration = 0 }, 
        ["5277"]   = { buffID = 5277,   duration = 0 }, ["1966"]   = { buffID = 1966,   duration = 0 }, 
        ["10060"]  = { buffID = 10060,  duration = 0 }, ["33206"]  = { buffID = 33206,  duration = 0 }, 
        ["47536"]  = { buffID = 47536,  duration = 0 }, ["47788"]  = { buffID = 47788,  duration = 0 }, 
        ["47585"]  = { buffID = 47585,  duration = 0 }, ["19236"]  = { buffID = 19236,  duration = 0 }, 
        ["51271"]  = { buffID = 51271,  duration = 0 }, ["49028"]  = { buffID = 49028,  duration = 0 }, 
        ["48792"]  = { buffID = 48792,  duration = 0 }, ["48707"]  = { buffID = 48707,  duration = 0 }, 
        ["55233"]  = { buffID = 55233,  duration = 0 }, 
        ["114050"] = { buffID = 114050, duration = 0 }, ["114051"] = { buffID = 114051, duration = 0 }, 
        ["114052"] = { buffID = 114052, duration = 0 }, ["108271"] = { buffID = 108271, duration = 0 }, 
        ["79206"]  = { buffID = 79206,  duration = 0 }, 
        ["190319"] = { buffID = 190319, duration = 0 }, ["12472"]  = { buffID = 12472,  duration = 0 }, 
        ["365362"] = { buffID = 365362, duration = 0 }, ["45438"]  = { buffID = 45438,  duration = 0 }, 
        ["110959"] = { buffID = 110959, duration = 0 }, ["108978"] = { buffID = 108978, duration = 0 }, 
        ["104773"] = { buffID = 104773, duration = 0 }, ["108416"] = { buffID = 108416, duration = 0 }, 
        ["205180"] = { buffID = 205180, duration = 20}, ["265187"] = { buffID = 265187, duration = 15}, 
        ["137639"] = { buffID = 137639, duration = 0 }, ["115288"] = { buffID = 115288, duration = 0 }, 
        ["122278"] = { buffID = 122278, duration = 0 }, ["115203"] = { buffID = 115203, duration = 0 }, 
        ["122783"] = { buffID = 122783, duration = 0 }, ["122470"] = { buffID = 122470, duration = 0 }, 
        ["390414"] = { buffID = 390414, duration = 0 }, ["33891"]  = { buffID = 33891,  duration = 0 }, 
        ["102558"] = { buffID = 102558, duration = 0 }, ["319454"] = { buffID = 319454, duration = 0 }, 
        ["22812"]  = { buffID = 22812,  duration = 0 }, ["61336"]  = { buffID = 61336,  duration = 0 }, 
        ["191427"] = { buffID = 191427, duration = 0 }, ["187827"] = { buffID = 187827, duration = 0 }, 
        ["198589"] = { buffID = 198589, duration = 0 }, ["204021"] = { buffID = 204021, duration = 0 }, 
        ["375087"] = { buffID = 375087, duration = 0 }, ["363916"] = { buffID = 363916, duration = 0 }, 
        ["374348"] = { buffID = 374348, duration = 0 }, 
    },
    text = { font = "Expressway", fontSize = 20, fontOutline = "OUTLINE", color = {r = 1, g = 0.82, b = 0}, offsetX = 0, offsetY = 0 },
    glowType = "pixel", glowColor = {r = 1, g = 0.82, b = 0, a = 1},
    glowPixelLines = 8, glowPixelFrequency = 0.25, glowPixelLength = 10,
    glowPixelThickness = 2, glowPixelXOffset = 0, glowPixelYOffset = 0,
}

local OverlayFrames = {}
local ActiveGlows = {}
mod.trackedAuras = {} 
mod.manualTrackers = {} 

-- =========================================
-- 2. 核心轻量化防爆引擎 
-- =========================================
local function IsSafeValue(val)
    if val == nil then return false end
    if type(issecretvalue) == "function" and issecretvalue(val) then return false end
    return true
end

-- 【修复：彻底摒弃 pcall 闭包，不再泄露内存】
local function GetBaseSpellFast(spellID)
    if not IsSafeValue(spellID) then return nil end
    if BaseSpellCache[spellID] == nil then
        local base = spellID
        if type(C_Spell) == "table" and type(C_Spell.GetBaseSpell) == "function" then
            base = C_Spell.GetBaseSpell(spellID) or spellID
        end
        BaseSpellCache[spellID] = base
    end
    return BaseSpellCache[spellID]
end

local function MatchesSpellID(info, targetID)
    if not info then return false end
    if IsSafeValue(info.spellID) and (info.spellID == targetID or info.overrideSpellID == targetID) then return true end
    if info.linkedSpellIDs then
        for i = 1, #info.linkedSpellIDs do
            if IsSafeValue(info.linkedSpellIDs[i]) and info.linkedSpellIDs[i] == targetID then return true end
        end
    end
    return GetBaseSpellFast(info.spellID) == targetID
end

local function VerifyAuraAlive(checkID, checkUnit)
    if not IsSafeValue(checkID) then return false end
    local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(checkUnit, checkID)
    return auraData ~= nil
end

-- 【修复：彻底摒弃 pcall 闭包】
local function IsValidActiveAura(aura)
    if type(aura) ~= "table" then return false end
    local isValid = false
    if aura.auraInstanceID then
        isValid = true
        if IsSafeValue(aura.duration) and type(aura.duration) == "number" and aura.duration <= 0 then
            isValid = false
        end
    end
    return isValid
end

function mod:BuildFastCache()
    wipe(mod.fastTrackedBuffs)
    if E.db.WishFlex and E.db.WishFlex.auraGlow and E.db.WishFlex.auraGlow.spells then
        for k, v in pairs(E.db.WishFlex.auraGlow.spells) do
            local sid = tonumber(k)
            local bid = (type(v) == "table" and v.buffID) or sid
            if sid then mod.fastTrackedBuffs[sid] = true end
            if bid then mod.fastTrackedBuffs[bid] = true end
        end
    end
end

local function ShouldHideFrame(info)
    if not info then return false end
    if IsSafeValue(info.spellID) then
        if mod.fastTrackedBuffs[info.spellID] or mod.fastTrackedBuffs[info.overrideSpellID] then return true end
        local baseID = GetBaseSpellFast(info.spellID)
        if baseID and mod.fastTrackedBuffs[baseID] then return true end
    end
    if info.linkedSpellIDs then
        for i = 1, #info.linkedSpellIDs do
            local lid = info.linkedSpellIDs[i]
            if IsSafeValue(lid) and mod.fastTrackedBuffs[lid] then return true end
        end
    end
    return false
end

-- =========================================
-- 3. 设置界面
-- =========================================
local function IsSpellLearned(spellID)
    if not IsSafeValue(spellID) then return false end
    if IsPlayerSpell(spellID) then return true end
    if C_Spell and C_Spell.IsSpellKnownOrOverridesKnown and C_Spell.IsSpellKnownOrOverridesKnown(spellID) then return true end
    return false
end

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.cdmanager = WUI.OptionsArgs.cdmanager or { order = 20, type = "group", name = "|cff00e5cc冷却管理器|r", childGroups = "tab", args = {} }
    
    local args = WUI.OptionsArgs.cdmanager.args
    args.auraglow = {
        order = 7, type = "group", name = "高亮提醒",
        get = function(info) return E.db.WishFlex.auraGlow[info[#info]] end,
        set = function(info, v) E.db.WishFlex.auraGlow[info[#info]] = v; mod:UpdateGlows(true) end,
        args = {
            enable = { order = 1, type = "toggle", name = "启用高亮提醒" },
            showOnlyKnown = { order = 2, type = "toggle", name = "仅显示已学技能" },
            desc = { order = 3, type = "description", name = "|cff00ffcc状态提示：|r\n已激活双重核验，仅在【战斗中】或有【可攻击目标】时才会显示高亮。\n" },
            spellManagement = {
                order = 4, type = "group", name = "法术管理", guiInline = true,
                args = {
                    addSpell = { order = 1, type = "input", name = "添加技能ID", get = function() return "" end, set = function(_, v) local id = tonumber(v) if id then E.db.WishFlex.auraGlow.spells[tostring(id)] = { buffID = id, duration = 0 }; mod.selectedSpell = tostring(id); mod:BuildFastCache(); mod:UpdateGlows(true) end end },
                    selectSpell = { 
                        order = 2, type = "select", name = "管理已添加技能", 
                        values = function() 
                            local vals = {} 
                            for k, v in pairs(E.db.WishFlex.auraGlow.spells) do 
                                local id = tonumber(k)
                                local shouldShow = true
                                if E.db.WishFlex.auraGlow.showOnlyKnown then shouldShow = IsSpellLearned(id) end
                                if shouldShow then vals[k] = (C_Spell.GetSpellName(id) or "未知技能") .. " (" .. k .. ")" end
                            end 
                            return vals 
                        end, 
                        get = function() return mod.selectedSpell end, 
                        set = function(_, v) mod.selectedSpell = v end 
                    },
                    editBuff = { order = 3, type = "input", name = "触发发光的Buff ID", get = function() local d = mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; return d and tostring(type(d) == "table" and d.buffID or d) or "" end, set = function(_, v) local id = tonumber(v); if mod.selectedSpell and id then if type(E.db.WishFlex.auraGlow.spells[mod.selectedSpell]) ~= "table" then E.db.WishFlex.auraGlow.spells[mod.selectedSpell] = { buffID = id, duration = 0 } else E.db.WishFlex.auraGlow.spells[mod.selectedSpell].buffID = id end; mod:BuildFastCache(); mod:UpdateGlows(true) end end, disabled = function() return not mod.selectedSpell end },
                    trackMode = {
                        order = 4, type = "select", name = "追踪模式",
                        values = { ["auto"] = "自动追踪 (推荐：常规增益)", ["manual"] = "手动倒数 (专用：实体仆从)" },
                        get = function() local d = mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; if type(d) == "table" then return (d.duration and d.duration > 0) and "manual" or "auto" end return "auto" end,
                        set = function(_, v) if mod.selectedSpell and type(E.db.WishFlex.auraGlow.spells[mod.selectedSpell]) == "table" then if v == "auto" then E.db.WishFlex.auraGlow.spells[mod.selectedSpell].duration = 0 else E.db.WishFlex.auraGlow.spells[mod.selectedSpell].duration = 20 end mod:BuildFastCache(); mod:UpdateGlows(true) end end,
                        disabled = function() return not mod.selectedSpell end
                    },
                    editDuration = { 
                        order = 5, type = "input", name = "手动持续时间(秒)", 
                        get = function() local d = mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; return d and tostring(type(d) == "table" and d.duration or 0) or "0" end, 
                        set = function(_, v) local val = tonumber(v); if mod.selectedSpell and val then if type(E.db.WishFlex.auraGlow.spells[mod.selectedSpell]) ~= "table" then E.db.WishFlex.auraGlow.spells[mod.selectedSpell] = { buffID = tonumber(mod.selectedSpell), duration = val } else E.db.WishFlex.auraGlow.spells[mod.selectedSpell].duration = val end; mod:BuildFastCache(); mod:UpdateGlows(true) end end, 
                        disabled = function() local d = mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; return not (type(d) == "table" and d.duration and d.duration > 0) end 
                    },
                    deleteSpell = { order = 6, type = "execute", name = "删除选中", func = function() if mod.selectedSpell then local id = tonumber(mod.selectedSpell); E.db.WishFlex.auraGlow.spells[mod.selectedSpell] = nil; mod.selectedSpell = nil; if ActiveGlows[id] then ActiveGlows[id] = false; if OverlayFrames[id] then LCG.PixelGlow_Stop(OverlayFrames[id], "WishAuraDurationGlow"); OverlayFrames[id]:Hide() end end; local CC = WUI:GetModule('CooldownCustom', true); if CC and CC.TriggerLayout then CC:TriggerLayout() end; mod:BuildFastCache(); mod:UpdateGlows(true) end end, disabled = function() return not mod.selectedSpell end }
                }
            },
            glowGroup = {
                order = 5, type = "group", name = "发光设置", guiInline = true,
                args = {
                    glowColor = { order = 1, type = "color", name = "颜色", hasAlpha = true, get = function() local c = E.db.WishFlex.auraGlow.glowColor; return c.r, c.g, c.b, c.a end, set = function(_, r, g, b, a) E.db.WishFlex.auraGlow.glowColor = {r=r, g=g, b=b, a=a}; mod:UpdateGlows(true) end },
                    glowPixelLines = { order = 2, type = "range", name = "线条数", min = 1, max = 20, step = 1 },
                    glowPixelFrequency = { order = 3, type = "range", name = "频率", min = -2, max = 2, step = 0.05 },
                    glowPixelLength = { order = 4, type = "range", name = "长度", min = 1, max = 50, step = 1 },
                    glowPixelThickness = { order = 5, type = "range", name = "粗细", min = 1, max = 10, step = 1 },
                    glowPixelXOffset = { order = 6, type = "range", name = "X轴偏移", min = -20, max = 20, step = 1 },
                    glowPixelYOffset = { order = 7, type = "range", name = "Y轴偏移", min = -20, max = 20, step = 1 },
                }
            },
            textGroup = {
                order = 6, type = "group", name = "倒计时文本设置", guiInline = true,
                get = function(info) return E.db.WishFlex.auraGlow.text[info[#info]] end,
                set = function(info, v) E.db.WishFlex.auraGlow.text[info[#info]] = v; mod:UpdateGlows(true) end,
                args = {
                    font = { order = 1, type = "select", name = "字体", dialogControl = 'LSM30_Font', values = LSM:HashTable("font") },
                    fontSize = { order = 2, type = "range", name = "大小", min = 8, max = 60, step = 1 },
                    fontOutline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "OUTLINE", ["MONOCHROMEOUTLINE"] = "MONOCROMEOUTLINE", ["THICKOUTLINE"] = "THICKOUTLINE" } },
                    color = { order = 4, type = "color", name = "颜色", get = function() local c = E.db.WishFlex.auraGlow.text.color; return c.r, c.g, c.b end, set = function(_, r, g, b) E.db.WishFlex.auraGlow.text.color = {r=r, g=g, b=b}; mod:UpdateGlows(true) end },
                    offsetX = { order = 5, type = "range", name = "X轴偏移", min = -50, max = 50, step = 1 },
                    offsetY = { order = 6, type = "range", name = "Y轴偏移", min = -50, max = 50, step = 1 },
                }
            }
        }
    }
end

-- =========================================
-- 4. 动态裁切算法 & 极速贴合
-- =========================================
local function GetCropCoords(w, h)
    local l, r, t, b = unpack(E.TexCoords)
    if not w or not h or h == 0 or w == 0 then return l, r, t, b end
    local ratio = w / h
    if math.abs(ratio - 1) < 0.05 then return l, r, t, b end
    if ratio > 1 then
        local crop = (1 - (1/ratio)) / 2
        return l, r, t + (b - t) * crop, b - (b - t) * crop
    else
        local crop = (1 - ratio) / 2
        return l + (r - l) * crop, r - (r - l) * crop, t, b
    end
end

-- 【核弹级修复】：移除了这里的 pcall(function() ...) 匿名闭包，斩断了每秒上百次的内存垃圾生成！
local function GetHardcodedSize(parentFrame)
    local cfg = E.db.WishFlex.cdManager
    if not cfg then return 45, 45 end
    local parent = parentFrame:GetParent()
    local parentName = parent and parent:GetName() or ""
    
    if parentName:find("Utility") or (parent and parent.itemFramePool and parent == _G.UtilityCooldownViewer) then
        return cfg.Utility.width or 45, cfg.Utility.height or 30
    elseif parentName:find("Essential") or parentName == "WishFlex_CooldownRow2_Anchor" or (parent and parent.itemFramePool and parent == _G.EssentialCooldownViewer) then
        if parentName == "WishFlex_CooldownRow2_Anchor" or (parentFrame.layoutIndex and cfg.Essential.maxPerRow and parentFrame.layoutIndex > cfg.Essential.maxPerRow) then
            return cfg.Essential.row2Width or 40, cfg.Essential.row2Height or 40
        end
        return cfg.Essential.row1Width or 45, cfg.Essential.row1Height or 45
    end
    
    -- 0 损耗获取尺寸，绝不在 OnUpdate 中制造垃圾
    local w = type(parentFrame.GetWidth) == "function" and parentFrame:GetWidth() or 45
    local h = type(parentFrame.GetHeight) == "function" and parentFrame:GetHeight() or 45
    if type(w) == "number" and type(h) == "number" and w > 0 then return w, h end
    
    return 45, 45
end

local function SnapOverlayToFrame(overlay, sourceFrame)
    if sourceFrame and sourceFrame:IsVisible() then
        if sourceFrame.GetCenter then
            local cx, cy = sourceFrame:GetCenter()
            if cx and cy then
                local scale = sourceFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
                local rawW, rawH = GetHardcodedSize(sourceFrame)
                
                if overlay.lastCX ~= cx or overlay.lastCY ~= cy or overlay.lastScale ~= scale or overlay.lastW ~= rawW or overlay.lastH ~= rawH then
                    overlay:SetScale(scale)
                    overlay:SetSize(rawW, rawH)
                    overlay.iconTex:SetTexCoord(GetCropCoords(rawW, rawH))
                    overlay:ClearAllPoints()
                    overlay:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
                    
                    overlay.lastCX, overlay.lastCY = cx, cy
                    overlay.lastScale = scale
                    overlay.lastW = rawW
                    overlay.lastH = rawH
                end
                return true
            end
        end
    end
    return false
end

-- =========================================
-- 5. 召唤暴雪原生渲染引擎 
-- =========================================
local function SyncOverlayTextAndVisuals(overlay)
    local cfg = E.db.WishFlex.auraGlow.text
    local fontPath = LSM:Fetch('font', cfg.font)
    
    if overlay.lastFont ~= fontPath or overlay.lastSize ~= cfg.fontSize or overlay.lastOutline ~= cfg.fontOutline then
        overlay.durationText:SetFont(fontPath, cfg.fontSize, cfg.fontOutline)
        overlay.lastFont, overlay.lastSize, overlay.lastOutline = fontPath, cfg.fontSize, cfg.fontOutline
    end
    
    if overlay.lastR ~= cfg.color.r or overlay.lastG ~= cfg.color.g or overlay.lastB ~= cfg.color.b then
        overlay.durationText:SetTextColor(cfg.color.r, cfg.color.g, cfg.color.b)
        overlay.lastR, overlay.lastG, overlay.lastB = cfg.color.r, cfg.color.g, cfg.color.b
    end

    if overlay.lastOffsetX ~= cfg.offsetX or overlay.lastOffsetY ~= cfg.offsetY then
        overlay.durationText:ClearAllPoints()
        overlay.durationText:SetPoint("CENTER", overlay, "CENTER", cfg.offsetX, cfg.offsetY)
        overlay.lastOffsetX, overlay.lastOffsetY = cfg.offsetX, cfg.offsetY
    end
end

local function GetOrCreateOverlay(parentFrame, spellID)
    if not OverlayFrames[spellID] then
        local overlay = CreateFrame("Frame", nil, UIParent)
        overlay:SetFrameStrata("HIGH") 
        
        local iconTex = overlay:CreateTexture(nil, "ARTWORK")
        iconTex:SetPoint("TOPLEFT", overlay, "TOPLEFT", E.mult, -E.mult)
        iconTex:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -E.mult, E.mult)
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        if spellInfo and spellInfo.iconID then iconTex:SetTexture(spellInfo.iconID) end
        overlay.iconTex = iconTex
        
        local cd = CreateFrame("Cooldown", nil, overlay, "CooldownFrameTemplate")
        cd:SetAllPoints()
        cd:SetDrawSwipe(false) 
        cd:SetDrawEdge(false)  
        cd:SetDrawBling(false) 
        cd:SetHideCountdownNumbers(false)
        
        cd.noCooldownOverride = true
        cd.noOCC = true
        cd.skipElvUICooldown = true
        overlay.cd = cd
        
        for _, region in pairs({cd:GetRegions()}) do
            if region:IsObjectType("FontString") then
                overlay.durationText = region
                break
            end
        end
        if not overlay.durationText then overlay.durationText = cd:CreateFontString(nil, "OVERLAY") end
        
        overlay:SetScript("OnUpdate", function(self)
            if not SnapOverlayToFrame(self, self.sourceFrame) then
                self:Hide()
                return
            end
            SyncOverlayTextAndVisuals(self)
        end)
        OverlayFrames[spellID] = overlay
    end
    return OverlayFrames[spellID]
end

local function ApplyIndependentGlow(ov)
    local cfg = E.db.WishFlex.auraGlow
    LCG.PixelGlow_Stop(ov, "WishAuraDurationGlow")
    if cfg.glowType == "pixel" then
        LCG.PixelGlow_Start(ov, {cfg.glowColor.r, cfg.glowColor.g, cfg.glowColor.b, cfg.glowColor.a}, cfg.glowPixelLines, cfg.glowPixelFrequency, cfg.glowPixelLength, cfg.glowPixelThickness, cfg.glowPixelXOffset, cfg.glowPixelYOffset, false, "WishAuraDurationGlow")
    end
end

-- =========================================
-- 7. 动态引擎：无懈可击的最强核心
-- =========================================
function mod:UpdateGlows(forceUpdate)
    if not E.db.WishFlex.auraGlow.enable then return end
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

    for spellIDStr, spellData in pairs(E.db.WishFlex.auraGlow.spells) do
        local spellID = tonumber(spellIDStr)
        local buffID = type(spellData) == "table" and spellData.buffID or tonumber(spellData)
        local customDuration = type(spellData) == "table" and spellData.duration or 0
        
        if buffID then
            local skillFrame = nil
            for i = 1, #activeSkillFrames do
                if MatchesSpellID(activeSkillFrames[i].cooldownInfo, spellID) then skillFrame = activeSkillFrames[i]; break end
            end
            
            if skillFrame and skillFrame:IsVisible() then
                local auraActive = false
                local auraInstanceID = nil
                local unit = "player"
                
                if customDuration > 0 then
                    local tracker = mod.manualTrackers[buffID]
                    if tracker and GetTime() < (tracker.start + tracker.dur) then
                        auraActive = true
                    else
                        mod.manualTrackers[buffID] = nil 
                    end
                else
                    local buffFrame = nil
                    for i = 1, #activeBuffFrames do
                        if MatchesSpellID(activeBuffFrames[i].cooldownInfo, buffID) then buffFrame = activeBuffFrames[i]; break end
                    end
                    
                    if buffFrame then
                        local tempID = buffFrame.auraInstanceID
                        local tempUnit = buffFrame.auraDataUnit or "player"
                        if IsSafeValue(tempID) and VerifyAuraAlive(tempID, tempUnit) then
                            auraInstanceID, unit, auraActive = tempID, tempUnit, true
                            mod.trackedAuras[buffID] = mod.trackedAuras[buffID] or {}
                            mod.trackedAuras[buffID].id = auraInstanceID
                            mod.trackedAuras[buffID].unit = unit
                        end
                    end
                    
                    if not auraActive and mod.trackedAuras[buffID] then
                        local t = mod.trackedAuras[buffID]
                        if VerifyAuraAlive(t.id, t.unit) then
                            auraActive, auraInstanceID, unit = true, t.id, t.unit
                        else
                            mod.trackedAuras[buffID] = nil 
                        end
                    end
                    
                    if not auraActive then
                        local auraData = C_UnitAuras.GetPlayerAuraBySpellID(buffID)
                        if auraData and IsSafeValue(auraData.auraInstanceID) then
                            auraActive, auraInstanceID, unit = true, auraData.auraInstanceID, "player"
                            mod.trackedAuras[buffID] = mod.trackedAuras[buffID] or {}
                            mod.trackedAuras[buffID].id = auraInstanceID
                            mod.trackedAuras[buffID].unit = unit
                        elseif UnitExists("target") then
                            if not targetScanned then
                                targetScanned = true
                                for _, filter in ipairs({"HELPFUL", "HARMFUL"}) do
                                    for i = 1, 40 do
                                        local aura = C_UnitAuras.GetAuraDataByIndex("target", i, filter)
                                        if not aura then break end
                                        if IsSafeValue(aura.spellId) and IsSafeValue(aura.auraInstanceID) then
                                            targetAuraCache[aura.spellId] = aura.auraInstanceID
                                        end
                                    end
                                end
                            end
                            if targetAuraCache[buffID] then
                                auraActive, auraInstanceID, unit = true, targetAuraCache[buffID], "target"
                                mod.trackedAuras[buffID] = mod.trackedAuras[buffID] or {}
                                mod.trackedAuras[buffID].id = auraInstanceID
                                mod.trackedAuras[buffID].unit = unit
                            end
                        end
                    end
                end
                
                if auraActive and validCombatState then
                    local overlay = GetOrCreateOverlay(skillFrame, spellID)
                    overlay.sourceFrame = skillFrame
                    
                    if customDuration > 0 then
                        local tracker = mod.manualTrackers[buffID]
                        if tracker and type(overlay.cd.SetCooldown) == "function" then
                            local ok, err = pcall(overlay.cd.SetCooldown, overlay.cd, tracker.start, tracker.dur)
                        end
                    elseif auraInstanceID then
                        local durObj = C_UnitAuras.GetAuraDuration(unit, auraInstanceID)
                        if durObj and type(overlay.cd.SetCooldownFromDurationObject) == "function" then 
                            local ok, err = pcall(overlay.cd.SetCooldownFromDurationObject, overlay.cd, durObj) 
                        end
                    end
                    
                    SnapOverlayToFrame(overlay, skillFrame)
                    
                    overlay:Show()
                    if forceUpdate or not ActiveGlows[spellID] then
                        ActiveGlows[spellID] = true
                        ApplyIndependentGlow(overlay)
                    end
                else
                    ActiveGlows[spellID] = false
                    if OverlayFrames[spellID] then 
                        LCG.PixelGlow_Stop(OverlayFrames[spellID], "WishAuraDurationGlow")
                        if OverlayFrames[spellID].cd then OverlayFrames[spellID].cd:Clear() end
                        OverlayFrames[spellID]:Hide() 
                    end
                end
            else
                ActiveGlows[spellID] = false
                if OverlayFrames[spellID] then 
                    LCG.PixelGlow_Stop(OverlayFrames[spellID], "WishAuraDurationGlow")
                    if OverlayFrames[spellID].cd then OverlayFrames[spellID].cd:Clear() end
                    OverlayFrames[spellID]:Hide() 
                end
            end
        end
    end
    
    if E.db.WishFlex.auraGlow.enable then
        for _, viewer in ipairs({_G.BuffIconCooldownViewer, _G.BuffBarCooldownViewer}) do
            if viewer and viewer.itemFramePool then
                for f in viewer.itemFramePool:EnumerateActive() do
                    if f.cooldownInfo then
                        local shouldHide = ShouldHideFrame(f.cooldownInfo)
                        
                        if shouldHide then
                            if f:GetWidth() >= 1 and not f.wishFlexOrigWidth then f.wishFlexOrigWidth = f:GetWidth() end
                            f:SetAlpha(0)
                            if f.Icon then f.Icon:SetAlpha(0) end
                            f:SetWidth(0.001)
                            f:EnableMouse(false)
                        else
                            if f:GetWidth() < 1 then f:SetWidth(f.wishFlexOrigWidth or 45) end
                            f:SetAlpha(1)
                            if f.Icon then f.Icon:SetAlpha(1) end
                            f:EnableMouse(true)
                        end
                    end
                end
            end
        end
    end
end

-- =========================================
-- 8. 核心事件截获器
-- =========================================
function mod:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellID)
    if unit ~= "player" then return end
    if not E.db.WishFlex.auraGlow.enable then return end
    
    local triggered = false
    for sIDStr, spellData in pairs(E.db.WishFlex.auraGlow.spells) do
        local sID = tonumber(sIDStr)
        local bID = type(spellData) == "table" and spellData.buffID or tonumber(spellData)
        local dur = type(spellData) == "table" and spellData.duration or 0
        
        if dur > 0 and (spellID == sID or spellID == bID) then
            mod.manualTrackers = mod.manualTrackers or {}
            mod.manualTrackers[bID] = { start = GetTime(), dur = dur }
            triggered = true
        end
    end
    if triggered then mod:UpdateGlows() end
end

-- =========================================
-- 9. 增益静默隐藏钩子 
-- =========================================
local function HookBuffHide()
    local function HideIt(frame)
        if not E.db.WishFlex.auraGlow.enable or not frame.cooldownInfo then return end
        if frame:GetWidth() >= 1 and not frame.wishFlexOrigWidth then frame.wishFlexOrigWidth = frame:GetWidth() end
        
        local shouldHide = ShouldHideFrame(frame.cooldownInfo)
        
        if shouldHide then
            frame:SetAlpha(0)
            if frame.Icon then frame.Icon:SetAlpha(0) end
            frame:SetWidth(0.001)
            frame:EnableMouse(false)
        else
            if frame:GetWidth() < 1 then frame:SetWidth(frame.wishFlexOrigWidth or 45) end
            frame:SetAlpha(1)
            if frame.Icon then frame.Icon:SetAlpha(1) end
            frame:EnableMouse(true)
        end
    end

    if _G.CooldownViewerBuffIconItemMixin then
        hooksecurefunc(_G.CooldownViewerBuffIconItemMixin, "OnCooldownIDSet", HideIt)
        hooksecurefunc(_G.CooldownViewerBuffIconItemMixin, "OnActiveStateChanged", HideIt)
    end
    if _G.CooldownViewerBuffBarItemMixin then
        hooksecurefunc(_G.CooldownViewerBuffBarItemMixin, "OnCooldownIDSet", HideIt)
        hooksecurefunc(_G.CooldownViewerBuffBarItemMixin, "OnActiveStateChanged", HideIt)
    end
end

-- =========================================
-- 10. 事件防抖合并引擎
-- =========================================
local updatePending = false
local function RequestUpdateGlows()
    if updatePending then return end
    updatePending = true
    local delay = InCombatLockdown() and 0.08 or 0.3
    C_Timer.After(delay, function() 
        updatePending = false
        mod:UpdateGlows() 
    end)
end

local function SafeHook(object, funcName, callback)
    if object and object[funcName] and type(object[funcName]) == "function" then
        hooksecurefunc(object, funcName, callback)
    end
end

function mod:UNIT_AURA(event, unit)
    if not InCombatLockdown() and unit ~= "player" then return end
    if unit == "player" or unit == "target" then RequestUpdateGlows() end
end

function mod:OnCombatEvent()
    RequestUpdateGlows()
end

function mod:Initialize()
    if E.db.WishFlex and E.db.WishFlex.auraGlow and E.db.WishFlex.auraGlow.spells then
        local cleanSpells = {}
        for k, v in pairs(E.db.WishFlex.auraGlow.spells) do
            if type(v) == "number" then
                cleanSpells[k] = { buffID = v, duration = 0 }
            else
                cleanSpells[k] = { buffID = v.buffID or tonumber(k), duration = v.duration or 0 }
            end
        end
        E.db.WishFlex.auraGlow.spells = cleanSpells
    end
    
    self:BuildFastCache()
    InjectOptions()
    if not E.db.WishFlex.modules.auraGlow then return end
    
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnCombatEvent")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatEvent")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEvent")
    
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    
    HookBuffHide()
    
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
end
local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local LSM = E.Libs.LSM
local WUI = E:GetModule('WishFlex')
local DEF = WUI:NewModule('DefensiveCooldowns', 'AceHook-3.0', 'AceEvent-3.0')

local LCG = E.Libs and E.Libs.CustomGlow
if not LCG then LCG = LibStub and LibStub("LibCustomGlow-1.0", true) end

local DEFAULT_BUFF_COLOR = {r = 0, g = 1, b = 0}
local DEFAULT_CD_COLOR = {r = 1, g = 0.82, b = 0}
local DEFAULT_STACK_COLOR = {r = 1, g = 1, b = 1}
local DEFAULT_GLOW_COLOR = {r = 0, g = 1, b = 0.5, a = 1}

local GetSpellName = C_Spell and C_Spell.GetSpellName or GetSpellInfo

-- =======================================================
-- 【本地内部数据库】: 我们用自己的 charges 绕过暴雪的加密判定
-- =======================================================
local SpellDB = {
    WARRIOR = { [118038]={dur=8,charges=1}, [97462]={dur=10,charges=1}, [184364]={dur=8,charges=1}, [871]={dur=8,charges=1}, [12975]={dur=15,charges=1}, [23920]={dur=5,charges=1}, [386029]={dur=2,charges=1} },
    PALADIN = { [642]={dur=8,charges=1}, [498]={dur=8,charges=1}, [31850]={dur=10,charges=1}, [86659]={dur=8,charges=1}, [184662]={dur=15,charges=1}, [205191]={dur=10,charges=1} },
    HUNTER = { [186265]={dur=8,charges=1}, [109304]={dur=10,charges=1}, [264735]={dur=6,charges=1}, [281195]={dur=10,charges=1} },
    ROGUE = { [5277]={dur=10,charges=1}, [31224]={dur=5,charges=1}, [1966]={dur=10,charges=1}, [199754]={dur=10,charges=1} },
    PRIEST = { [19236]={dur=8,charges=1}, [33206]={dur=8,charges=1}, [47536]={dur=10,charges=1}, [47588]={dur=10,charges=1}, [64843]={dur=8,charges=1}, [65081]={dur=4,charges=1} },
    DEATHKNIGHT = { [48707]={dur=5,charges=1}, [48792]={dur=8,charges=1}, [49039]={dur=10,charges=1}, [55233]={dur=10,charges=1}, [48743]={dur=10,charges=1} },
    SHAMAN = { [108271]={dur=12,charges=1}, [210643]={dur=60,charges=1}, [114052]={dur=15,charges=1} },
    MAGE = { 
        [45438]={dur=10,charges=1}, 
        [110909]={dur=10,charges=3}, 
        [198065]={dur=15,charges=1}, 
        [235313]={dur=10,charges=1}, 
        [108978]={dur=10,charges=1, isToggle=true, linkedSpells="342245,342246"},
        [342245]={dur=10,charges=1, isToggle=true, linkedSpells="108978,342246"}, 
        [414658]={dur=12,charges=1} 
    },
    WARLOCK = { [104773]={dur=8,charges=1}, [108416]={dur=8,charges=1}, [389831]={dur=10,charges=1} },
    MONK = { [115203]={dur=15,charges=1}, [122278]={dur=10,charges=1}, [122470]={dur=10,charges=1}, [115176]={dur=6,charges=1}, [115310]={dur=10,charges=1}, [322507]={dur=10,charges=1} },
    DRUID = { [22812]={dur=12,charges=1}, [61336]={dur=6,charges=2}, [102342]={dur=12,charges=1}, [108238]={dur=10,charges=2} },
    DEMONHUNTER = { [196718]={dur=8,charges=1}, [198589]={dur=10,charges=1}, [204021]={dur=8,charges=1} },
    EVOKER = { [363916]={dur=12,charges=2}, [374348]={dur=8,charges=1}, [374227]={dur=5,charges=1}, [357170]={dur=8,charges=1} },
}

DEF.activeDefensives = {}
DEF.defensiveIcons = {}
DEF.tracker = {}
DEF.selectedSpellForEdit = nil 

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.defensiveCDs = true
P["WishFlex"].defensives = {
    enable = true, attachToPlayer = true, customSpells = "",
    width = 45, height = 45, iconGap = 2, growth = "LEFT", desaturate = true,
    countFont = "Expressway", countFontOutline = "OUTLINE",
    buffFontSize = 18, buffFontColor = DEFAULT_BUFF_COLOR, buffXOffset = 0, buffYOffset = 0,
    cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdXOffset = 0, cdYOffset = 0,
    stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackXOffset = 12, stackYOffset = -12,
    glowEnable = true, glowColor = DEFAULT_GLOW_COLOR, glowLines = 8, glowFreq = 0.25, glowThick = 2,
    spellOverrides = {} 
}

local function InjectOptions()
    local function GetSpellList()
        local list = {}
        for _, spellID in ipairs(DEF.activeDefensives) do
            local name = GetSpellName(spellID) or ("未知技能")
            list[spellID] = name .. " (" .. spellID .. ")"
        end
        return list
    end

    local function GetSelectedSpellOverride()
        local id = DEF.selectedSpellForEdit
        if not id then return nil end
        local db = E.db.WishFlex.defensives.spellOverrides
        if type(db) ~= "table" then E.db.WishFlex.defensives.spellOverrides = {} db = E.db.WishFlex.defensives.spellOverrides end
        
        if not db[id] then
            local pClass = select(2, UnitClass("player"))
            local def = (SpellDB[pClass] and SpellDB[pClass][id]) or {dur=10, charges=1, isToggle=false, linkedSpells=""}
            db[id] = { dur = def.dur, charges = def.charges, order = 50, isToggle = def.isToggle, linkedSpells = def.linkedSpells }
        end
        return db[id]
    end

    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.defensives = {
        order = 22, type = "group", name = "|cff00e5cc独立防御技能|r", childGroups = "tab",
        get = function(i) return E.db.WishFlex.defensives[i[#i]] end,
        set = function(i, v) E.db.WishFlex.defensives[i[#i]] = v; DEF:UpdateLayout() end,
        args = {
            general = {
                order = 1, type = "group", name = "基础与排版", guiInline = true,
                args = {
                    enable = { order = 1, type = "toggle", name = "启用模块", get = function() return E.db.WishFlex.modules.defensiveCDs end, set = function(_, v) E.db.WishFlex.modules.defensiveCDs = v; E:StaticPopup_Show("CONFIG_RL") end },
                    attachToPlayer = { order = 2, type = "toggle", name = "吸附至玩家头像框" },
                    customSpells = { order = 3, type = "input", name = "自定义追踪技能ID (逗号分隔)", width = "full", desc = "添加后请前往 [法术管理] 标签中配置它的持续时间。", set = function(_, v) E.db.WishFlex.defensives.customSpells = v; DEF:UpdateKnownDefensives() end },
                    growth = { order = 4, type = "select", name = "增长方向", disabled = function() return E.db.WishFlex.defensives.attachToPlayer end, values = { ["LEFT"] = "向左", ["CENTER"] = "居中", ["RIGHT"] = "向右" } },
                    iconGap = { order = 5, type = "range", name = "间距", min = 0, max = 20, step = 1 },
                    width = { order = 6, type = "range", name = "图标宽度", min = 10, max = 100, step = 1 },
                    height = { order = 7, type = "range", name = "图标高度", min = 10, max = 100, step = 1 },
                    desaturate = { order = 8, type = "toggle", name = "不可用时变灰(包含冷却)" },
                }
            },
            spellManager = {
                order = 2, type = "group", name = "|cff00ff00法术管理|r", guiInline = true,
                args = {
                    selectSpell = {
                        order = 1, type = "select", name = "选择技能进行编辑", width = "double",
                        desc = "由于暴雪强力加密，本模块冷却倒数彻底交由底层渲染。请仅设置Buff持续时间和最大层数标识！",
                        values = GetSpellList,
                        get = function() return DEF.selectedSpellForEdit end,
                        set = function(_, v) DEF.selectedSpellForEdit = v end
                    },
                    spacer = { order = 2, type = "description", name = " \n" },
                    dur = {
                        order = 3, type = "range", name = "Buff持续时间(秒)", min = 1, max = 300, step = 1,
                        hidden = function() return not DEF.selectedSpellForEdit end,
                        get = function() local t = GetSelectedSpellOverride(); return t and t.dur or 10 end,
                        set = function(_, v) local t = GetSelectedSpellOverride(); if t then t.dur = v; DEF:UpdateKnownDefensives() end end
                    },
                    charges = {
                        order = 4, type = "range", name = "标识最大层数", min = 1, max = 5, step = 1,
                        desc = "必须填对法术的最大层数（如2层），插件才能判断是否要在右下角显示剩余层数！",
                        hidden = function() return not DEF.selectedSpellForEdit end,
                        get = function() local t = GetSelectedSpellOverride(); return t and t.charges or 1 end,
                        set = function(_, v) local t = GetSelectedSpellOverride(); if t then t.charges = v; DEF:UpdateKnownDefensives() end end
                    },
                    isToggle = {
                        order = 5, type = "toggle", name = "二段 / 可提前取消",
                        desc = "开启后，在Buff倒数期间再次按下该技能，将立即结束Buff并转为冷却。\n完美适配法师的【操纵时间】等技能。",
                        hidden = function() return not DEF.selectedSpellForEdit end,
                        get = function() local t = GetSelectedSpellOverride(); return t and t.isToggle or false end,
                        set = function(_, v) local t = GetSelectedSpellOverride(); if t then t.isToggle = v; DEF:UpdateKnownDefensives() end end
                    },
                    linkedSpells = {
                        order = 6, type = "input", name = "二段关联法术ID (逗号分隔)", width = "double",
                        desc = "如果该技能按第二下时会变成一个新技能ID（如操纵时间回归），请在此填入子技能ID，以确保能精准取消Buff。",
                        hidden = function() return not DEF.selectedSpellForEdit end,
                        get = function() local t = GetSelectedSpellOverride(); return t and t.linkedSpells or "" end,
                        set = function(_, v) local t = GetSelectedSpellOverride(); if t then t.linkedSpells = v; DEF:UpdateKnownDefensives() end end
                    },
                    order = {
                        order = 7, type = "range", name = "显示顺序", min = 1, max = 100, step = 1,
                        desc = "数字越小，越靠近锚点起点（默认靠左）。\n若数字相同则按法术ID自动排序。",
                        hidden = function() return not DEF.selectedSpellForEdit end,
                        get = function() local t = GetSelectedSpellOverride(); return t and t.order or 50 end,
                        set = function(_, v) local t = GetSelectedSpellOverride(); if t then t.order = v; DEF:UpdateKnownDefensives() end end
                    },
                    reset = {
                        order = 8, type = "execute", name = "恢复此法术默认值",
                        hidden = function() return not DEF.selectedSpellForEdit end,
                        func = function()
                            local id = DEF.selectedSpellForEdit
                            if id and E.db.WishFlex.defensives.spellOverrides[id] then
                                E.db.WishFlex.defensives.spellOverrides[id] = nil
                                DEF:UpdateKnownDefensives()
                            end
                        end
                    }
                }
            },
            font = {
                order = 3, type = "group", name = "字体设置", guiInline = true,
                args = {
                    countFont = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "全局字体", values = LSM:HashTable("font") },
                    countFontOutline = { order = 2, type = "select", name = "字体描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } },
                    buffFontSize = {order=3,type="range",name="持续时间大小",min=4,max=40,step=1}, 
                    buffFontColor = {order=4,type="color",name="持续时间颜色",get=function() local t=E.db.WishFlex.defensives.buffFontColor or DEFAULT_BUFF_COLOR return t.r,t.g,t.b end, set=function(_,r,g,b) E.db.WishFlex.defensives.buffFontColor={r=r,g=g,b=b} end}, 
                    buffXOffset = {order=5,type="range",name="持续时间X偏移",min=-50,max=50,step=1}, 
                    buffYOffset = {order=6,type="range",name="持续时间Y偏移",min=-50,max=50,step=1},
                    
                    cdFontSize = {order=7,type="range",name="冷却时间大小",min=4,max=40,step=1}, 
                    cdFontColor = {order=8,type="color",name="冷却时间颜色",get=function() local t=E.db.WishFlex.defensives.cdFontColor or DEFAULT_CD_COLOR return t.r,t.g,t.b end, set=function(_,r,g,b) E.db.WishFlex.defensives.cdFontColor={r=r,g=g,b=b} end}, 
                    cdXOffset = {order=9,type="range",name="冷却时间X偏移",min=-50,max=50,step=1}, 
                    cdYOffset = {order=10,type="range",name="冷却时间Y偏移",min=-50,max=50,step=1},
                    
                    stackFontSize = {order=11,type="range",name="层数大小",min=4,max=40,step=1}, 
                    stackFontColor = {order=12,type="color",name="层数颜色",get=function() local t=E.db.WishFlex.defensives.stackFontColor or DEFAULT_STACK_COLOR return t.r,t.g,t.b end, set=function(_,r,g,b) E.db.WishFlex.defensives.stackFontColor={r=r,g=g,b=b} end}, 
                    stackXOffset = {order=13,type="range",name="层数X偏移",min=-50,max=50,step=1}, 
                    stackYOffset = {order=14,type="range",name="层数Y偏移",min=-50,max=50,step=1},
                }
            },
            glow = {
                order = 4, type = "group", name = "高亮效果", guiInline = true,
                args = {
                    glowEnable = { order = 1, type = "toggle", name = "启用像素发光" },
                    glowColor = { order = 2, type = "color", name = "线条颜色", hasAlpha = true, get = function() local t = E.db.WishFlex.defensives.glowColor or DEFAULT_GLOW_COLOR return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) E.db.WishFlex.defensives.glowColor = {r=r,g=g,b=b,a=a}; end },
                    glowLines = { order = 3, type = "range", name = "线条数量", min = 1, max = 20, step = 1 },
                    glowFreq = { order = 4, type = "range", name = "动画速度", min = 0.05, max = 2, step = 0.05 },
                    glowThick = { order = 5, type = "range", name = "线条粗细", min = 1, max = 10, step = 1 },
                }
            }
        }
    }
end

local function ApplyTexCoord(texture, width, height)
    if not texture or not texture.SetTexCoord then return end
    local ratio = width / height
    local offset = 0.08
    local left, right, top, bottom = offset, 1-offset, offset, 1-offset
    if ratio > 1 then local vH = (1 - 2*offset) / ratio; top, bottom = 0.5 - (vH/2), 0.5 + (vH/2)
    elseif ratio < 1 then local vW = (1 - 2*offset) * ratio; left, right = 0.5 - (vW/2), 0.5 + (vW/2) end
    texture:SetTexCoord(left, right, top, bottom)
end

function DEF:GetIconFrame(index)
    if not self.defensiveIcons[index] then
        local f = CreateFrame("Frame", "WishFlex_DefensiveIcon"..index, _G.WishFlex_DefensiveViewer)
        f:SetTemplate("Transparent")
        f.Icon = f:CreateTexture(nil, "ARTWORK"); f.Icon:SetInside()
        f.Cooldown = CreateFrame("Cooldown", "$parentCooldown", f, "CooldownFrameTemplate")
        f.Cooldown:SetInside(); f.Cooldown:SetDrawEdge(false); 
        
        -- 开启暴雪自带冷却文本，完全防污染
        f.Cooldown:SetHideCountdownNumbers(false) 
        if E.RegisterCooldown then E:RegisterCooldown(f.Cooldown) end 
        
        f.OverlayFrame = CreateFrame("Frame", nil, f)
        f.OverlayFrame:SetAllPoints(); f.OverlayFrame:SetFrameLevel(f.Cooldown:GetFrameLevel() + 5)

        f.BuffText = f.OverlayFrame:CreateFontString(nil, "OVERLAY")
        f.BuffText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE") 
        
        f.StackText = f.OverlayFrame:CreateFontString(nil, "OVERLAY")
        f.StackText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE") 
        
        self.defensiveIcons[index] = f
    end
    return self.defensiveIcons[index]
end

-- 精确识别：彻底解决天赋遗忘后依然显示的问题
local function IsDefensiveSpellKnown(spellID)
    if IsSpellKnownOrOverridesKnown(spellID) then return true end
    return false
end

function DEF:UpdateKnownDefensives()
    if InCombatLockdown() then return end
    
    table.wipe(self.activeDefensives)
    table.wipe(self.tracker) 
    
    local _, pClass = UnitClass("player")
    local db = SpellDB[pClass] or {}
    local seen = {}
    
    if type(E.db.WishFlex.defensives.spellOverrides) ~= "table" then 
        E.db.WishFlex.defensives.spellOverrides = {} 
    end
    local overrides = E.db.WishFlex.defensives.spellOverrides
    local sortedList = {}

    local function AddSpellToTracker(spellID, dur, charges, isToggle, defaultLinked)
        if not seen[spellID] then
            seen[spellID] = true
            
            local ov = overrides[spellID] or {}
            local finalDur = ov.dur or dur
            local finalCharges = ov.charges or charges
            local finalOrder = ov.order or 50
            local finalToggle = (ov.isToggle ~= nil) and ov.isToggle or isToggle
            
            local finalLinkedStr = ov.linkedSpells or defaultLinked or ""
            local parsedLinked = {}
            if type(finalLinkedStr) == "string" then
                for idStr in string.gmatch(finalLinkedStr, "[%d]+") do
                    local lID = tonumber(idStr)
                    if lID then table.insert(parsedLinked, lID) end
                end
            end

            table.insert(sortedList, { id = spellID, order = finalOrder })

            self.tracker[spellID] = {
                info = {dur = finalDur, charges = finalCharges, isToggle = finalToggle, linkedSpells = parsedLinked},
                buffEndTime = 0
            }
        end
    end

    for spellID, data in pairs(db) do
        if IsDefensiveSpellKnown(spellID) then 
            AddSpellToTracker(spellID, data.dur, data.charges, data.isToggle, data.linkedSpells) 
        end
    end

    local customStr = E.db.WishFlex.defensives.customSpells or ""
    for idStr in string.gmatch(customStr, "[%d]+") do
        local spellID = tonumber(idStr)
        if spellID and IsDefensiveSpellKnown(spellID) then
            local data = db[spellID] or {dur=10, charges=1, isToggle=false, linkedSpells=""}
            AddSpellToTracker(spellID, data.dur, data.charges, data.isToggle, data.linkedSpells)
        end
    end

    table.sort(sortedList, function(a, b)
        if a.order == b.order then return a.id < b.id end
        return a.order < b.order
    end)

    for i, spellData in ipairs(sortedList) do
        self.activeDefensives[i] = spellData.id
    end

    self:UpdateLayout()
end

function DEF:UpdateLayout()
    local db = E.db.WishFlex.defensives
    local container = _G.WishFlex_DefensiveViewer
    if not db.enable or #self.activeDefensives == 0 then if container then container:Hide() end; return end
    
    container:Show()
    local w, h, gap, growth = db.width, db.height, db.iconGap, db.growth
    if db.attachToPlayer then growth = "LEFT" end
    
    local totalW = (#self.activeDefensives * w) + math.max(0, (#self.activeDefensives - 1) * gap)
    container:SetSize(math.max(w, totalW), h)

    if db.attachToPlayer and _G.ElvUF_Player then
        container:ClearAllPoints(); container:SetPoint("BOTTOMRIGHT", _G.ElvUF_Player, "TOPRIGHT", 0, 1)
        if container.mover then container.mover:SetAlpha(0) end 
    else
        if container.mover then 
            container.mover:SetSize(math.max(w, totalW), h); container.mover:SetAlpha(1)
            container:ClearAllPoints(); container:SetPoint("CENTER", container.mover, "CENTER")
        end
    end

    local fPath = LSM:Fetch('font', db.countFont or "Expressway")
    if not fPath or fPath == "" then fPath = STANDARD_TEXT_FONT end
    local outline = db.countFontOutline or "OUTLINE"

    for i = #self.activeDefensives + 1, #self.defensiveIcons do self.defensiveIcons[i]:Hide() end
    for i, spellID in ipairs(self.activeDefensives) do
        local f = self:GetIconFrame(i)
        f:ClearAllPoints(); f:Show()
        local x = 0
        if growth == "CENTER" then x = -(totalW / 2) + (w / 2) + (i - 1) * (w + gap); f:SetPoint("CENTER", container, "CENTER", x, 0)
        elseif growth == "LEFT" then x = -(i - 1) * (w + gap); f:SetPoint("RIGHT", container, "RIGHT", x, 0)
        elseif growth == "RIGHT" then x = (i - 1) * (w + gap); f:SetPoint("LEFT", container, "LEFT", x, 0) end

        f:SetSize(w, h)
        local effectiveID = (C_Spell and C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(spellID)) or spellID
        local iconTex = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(effectiveID)) or GetSpellTexture(effectiveID) or 136243
        f.Icon:SetTexture(iconTex); ApplyTexCoord(f.Icon, w, h)
        f.Cooldown:SetReverse(true); f.Cooldown:SetSwipeColor(0, 0, 0, 0.8)

        if f.BuffText.FontTemplate then f.BuffText:FontTemplate(fPath, db.buffFontSize or 18, outline) else f.BuffText:SetFont(fPath, db.buffFontSize or 18, outline) end
        if f.StackText.FontTemplate then f.StackText:FontTemplate(fPath, db.stackFontSize or 14, outline) else f.StackText:SetFont(fPath, db.stackFontSize or 14, outline) end

        f.BuffText:ClearAllPoints(); f.BuffText:SetPoint("CENTER", f.Icon, "CENTER", db.buffXOffset or 0, db.buffYOffset or 0)
        f.StackText:ClearAllPoints(); f.StackText:SetPoint("CENTER", f.Icon, "CENTER", db.stackXOffset or 0, db.stackYOffset or 0)
    end
end

local function FormatTime(time)
    if time >= 60 then return string.format("%dm", math.floor(time / 60))
    elseif time > 5 then return tostring(math.ceil(time)) 
    else return string.format("%.1f", time) end
end

-- =======================================================
-- 【底层核心重塑】：安全脱色 + 彻底杜绝数值比对污染
-- =======================================================
function DEF:UNIT_SPELLCAST_SUCCEEDED(_, unit, _, spellID)
    if unit ~= "player" then return end
    local now = GetTime()

    for _, trackID in ipairs(self.activeDefensives) do 
        local tData = self.tracker[trackID]
        if tData then
            -- 精确验证施法 ID，彻底避免无关技能导致闪烁
            local isBaseMatch = (spellID == trackID)
            local isLinkedMatch = false

            if tData.info.linkedSpells then
                for _, lID in ipairs(tData.info.linkedSpells) do
                    if spellID == lID then isLinkedMatch = true; break end
                end
            end

            if isBaseMatch or isLinkedMatch then
                if tData.buffEndTime > now and (tData.info.isToggle or isLinkedMatch) then
                    local elapsed = tData.info.dur - (tData.buffEndTime - now)
                    if elapsed > 0.5 then 
                        tData.buffEndTime = 0 
                    end
                elseif isBaseMatch then
                    tData.buffEndTime = now + tData.info.dur
                end
                break
            end 
        end
    end
end

function DEF:Heartbeat()
    local db = E.db.WishFlex.defensives
    if not db.enable then return end
    local now = GetTime()
    
    local fPath = LSM:Fetch('font', db.countFont or "Expressway")
    if not fPath or fPath == "" then fPath = STANDARD_TEXT_FONT end
    local outline = db.countFontOutline or "OUTLINE"

    for i, spellID in ipairs(self.activeDefensives) do
        local f = self.defensiveIcons[i]
        local tData = self.tracker[spellID]

        if f and f:IsShown() and tData then
            local effectiveID = (C_Spell and C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(spellID)) or spellID
            local isBuffing = tData.buffEndTime > now
            
            -- 图标动态切换 (无缝适配诸如操纵时间回归的变体)
            local iconTex = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(effectiveID)) or GetSpellTexture(effectiveID) or 136243
            if f._lastTex ~= iconTex then
                f.Icon:SetTexture(iconTex)
                f._lastTex = iconTex
            end

            if isBuffing then
                f.Icon:SetDesaturated(false); f.Icon:SetVertexColor(1, 1, 1)
                f.Cooldown:Hide(); f.Cooldown:Clear()
                
                local bfc = db.buffFontColor or DEFAULT_BUFF_COLOR
                f.BuffText:SetTextColor(bfc.r, bfc.g, bfc.b)
                f.BuffText:SetText(FormatTime(tData.buffEndTime - now))
                f.BuffText:Show()
                
                if db.glowEnable and not f.isGlowActive and LCG then 
                    local gc = db.glowColor or DEFAULT_GLOW_COLOR
                    LCG.PixelGlow_Start(f, {gc.r, gc.g, gc.b, gc.a}, db.glowLines, db.glowFreq, 10, db.glowThick, 0, 0, false, "DefensiveGlow")
                    f.isGlowActive = true 
                end
            else
                if f.isGlowActive and LCG then LCG.PixelGlow_Stop(f, "DefensiveGlow"); f.isGlowActive = false end
                f.BuffText:Hide()
                f.Cooldown:Show()
                
                -- 【纯净安全查询】：0 逻辑运算，全盘由 C 组件渲染
                local CCD = C_Spell and C_Spell.GetSpellChargeDuration and C_Spell.GetSpellChargeDuration(effectiveID)
                local SCD = C_Spell and C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(effectiveID)
                
                if CCD then
                    f.Cooldown:SetCooldownFromDurationObject(CCD)
                elseif SCD then
                    f.Cooldown:SetCooldownFromDurationObject(SCD)
                else
                    f.Cooldown:Clear()
                end

                -- 【绝对安全的脱色判定】：用暴雪官方判断按键是否可用的接口，不碰任何加密数值！
                if db.desaturate then
                    local isUsable, notEnoughPower = C_Spell.IsSpellUsable(effectiveID)
                    if not isUsable and not notEnoughPower then
                        f.Icon:SetDesaturated(true); f.Icon:SetVertexColor(0.5, 0.5, 0.5)
                    else
                        f.Icon:SetDesaturated(false); f.Icon:SetVertexColor(1, 1, 1)
                    end
                else
                    f.Icon:SetDesaturated(false); f.Icon:SetVertexColor(1, 1, 1)
                end
                
                -- 为 ElvUI 自动生成的冷却文字套用玩家设置
                if f.Cooldown.timer and f.Cooldown.timer.text then
                    local t = f.Cooldown.timer.text
                    local cfc = db.cdFontColor or DEFAULT_CD_COLOR
                    if f._lastCDStyle ~= (db.cdFontSize .. outline) then
                        if t.FontTemplate then t:FontTemplate(fPath, db.cdFontSize or 18, outline) else t:SetFont(fPath, db.cdFontSize or 18, outline) end
                        t:ClearAllPoints(); t:SetPoint("CENTER", f.Icon, "CENTER", db.cdXOffset or 0, db.cdYOffset or 0)
                        f._lastCDStyle = db.cdFontSize .. outline
                    end
                    t:SetTextColor(cfc.r, cfc.g, cfc.b)
                end
            end

            -- 【完美突破层数污染】：只使用我们自己在 DB 中预设的 charges 绕过加密比较
            if tData.info.charges > 1 then
                local chargeInfo = C_Spell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(effectiveID)
                if chargeInfo and chargeInfo.currentCharges then
                    local sfc = db.stackFontColor or DEFAULT_STACK_COLOR
                    f.StackText:SetTextColor(sfc.r, sfc.g, sfc.b)
                    
                    -- 黑科技：把机密数字送给 C 底层函数翻译成安全文本
                    if C_StringUtil and C_StringUtil.TruncateWhenZero then
                        f.StackText:SetText(C_StringUtil.TruncateWhenZero(chargeInfo.currentCharges))
                    else
                        f.StackText:SetText(tostring(chargeInfo.currentCharges))
                    end
                    f.StackText:Show()
                else 
                    f.StackText:Hide() 
                end
            else
                f.StackText:Hide()
            end
        end
    end
end

function DEF:Initialize()
    InjectOptions()

    if not E.db.WishFlex.modules.defensiveCDs then return end
    local container = CreateFrame("Frame", "WishFlex_DefensiveViewer", E.UIParent)
    container:SetSize(45, 45); container:SetPoint("CENTER", E.UIParent, "CENTER", 0, -150)
    E:CreateMover(container, "WishFlexDefensiveMover", "WishFlex: 独立防御技能", nil, nil, nil, "ALL,WishFlex")
    self:UpdateKnownDefensives(); self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED"); self:RegisterEvent("PLAYER_TALENT_UPDATE", "UpdateKnownDefensives"); self:RegisterEvent("SPELLS_CHANGED", "UpdateKnownDefensives")
    local ticker = 0; container:SetScript("OnUpdate", function(_, elapsed) ticker = ticker + elapsed; local interval = InCombatLockdown() and 0.1 or 0.5; if ticker >= interval then ticker = 0; DEF:Heartbeat() end end)
end
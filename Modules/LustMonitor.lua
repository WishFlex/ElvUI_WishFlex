local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local mod = WUI:NewModule('LustMonitor', 'AceEvent-3.0', 'AceTimer-3.0')
local LSM = E.Libs.LSM

-- ==========================================
-- 1. 默认数据库
-- ==========================================
P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.lustMonitor = true
P["WishFlex"].lustMonitor = {
    enable = true, playSound = true, font = "Expressway", fontSize = 40, 
    fontOutline = "OUTLINE", fontColor = { r = 1, g = 1, b = 1 }, offsetX = 0, offsetY = -80,
}

-- ==========================================
-- 2. 嗜血法术 ID 数据库 (综合法术释放与光环监控)
-- ==========================================
local LUST_IDS = {
    -- 施法技能 ID
    [2825]   = true, -- 萨满：嗜血
    [32182]  = true, -- 萨满：英勇
    [80353]  = true, -- 法师：时间扭曲
    [390386] = true, -- 唤魔师：守护巨龙之怒
    
    -- 【猎人专属修复】
    [264667] = true, -- 猎人宠物：原始狂怒 (宝宝施法)
    [272678] = true, -- 猎人本人：命令宠物 (这才是猎人玩家真正按下的那个技能ID！)
    
    [381301] = true, -- 物品：狂野皮革战鼓 (巨龙时代)
    [256740] = true, -- 物品：漩涡战鼓
    [178207] = true, [230935] = true, [264689] = true, [390435] = true, [80354] = true,
    
    -- 负面状态 ID (心满意足/竭力) 用于兜底扫描
    [57723]  = true, [57724]  = true
}

local TGA_PATH = [[Interface\AddOns\ElvUI_WishFlex\Media\Textures\LustAnimation.tga]]
local SOUND_PATH = [[Interface\AddOns\ElvUI_WishFlex\Media\Sounds\LustSound.ogg]]
local isLustActive, timeLeft = false, 0
local activeSoundHandle = nil
local lustStartTime = 0

-- ==========================================
-- 3. 设置菜单
-- ==========================================
local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.widgets = WUI.OptionsArgs.widgets or { order = 30, type = "group", name = "|cff00cccc小工具|r", childGroups = "tab", args = {} }
    WUI.OptionsArgs.widgets.args.lustMonitor = {
        order = 2, type = "group", name = "嗜血动画",
        get = function(info) return E.db.WishFlex.lustMonitor[info[#info]] end,
        set = function(info, value) E.db.WishFlex.lustMonitor[info[#info]] = value; if mod.UpdateTimerSettings then mod:UpdateTimerSettings() end end, 
        args = {
            topGrp = { 
                order = 1, type = "group", name = "", guiInline = true, 
                args = { 
                    enable = { order = 1, type = "toggle", name = "启用", get = function() return E.db.WishFlex.modules.lustMonitor end, set = function(_, v) E.db.WishFlex.modules.lustMonitor = v; E:StaticPopup_Show("CONFIG_RL") end }, 
                    preview = { order = 2, type = "execute", name = "预览动画", func = function() mod:PlayLustAnimation() end } 
                } 
            },
            configGrp = { 
                order = 10, type = "group", name = "文本设置", guiInline = true, 
                args = { 
                    font = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") }, 
                    fontSize = { order = 2, type = "range", name = "大小", min = 10, max = 200, step = 1 }, 
                    fontColor = { order = 3, type = "color", name = "颜色", get = function() local t = E.db.WishFlex.lustMonitor.fontColor or {r=1,g=0,b=0} return t.r, t.g, t.b end, set = function(_, r, g, b) E.db.WishFlex.lustMonitor.fontColor = {r=r,g=g,b=b}; mod:UpdateTimerSettings() end }, 
                    offsetX = { order = 4, type = "range", name = "X偏移", min = -800, max = 800, step = 1 }, 
                    offsetY = { order = 5, type = "range", name = "Y偏移", min = -800, max = 800, step = 1 } 
                } 
            }
        }
    }
end

function mod:UpdateTimerSettings()
    if not self.mainFrame or not self.timerText then return end
    local db = E.db.WishFlex.lustMonitor
    local fontPath = LSM:Fetch("font", db.font)
    self.timerText:FontTemplate(fontPath, db.fontSize, db.fontOutline or "OUTLINE")
    self.timerText:SetTextColor(db.fontColor.r, db.fontColor.g, db.fontColor.b)
    self.timerText:ClearAllPoints()
    self.timerText:SetPoint("CENTER", self.mainFrame, "CENTER", db.offsetX, db.offsetY)
end

function mod:StopLustSound()
    if activeSoundHandle then StopSound(activeSoundHandle); activeSoundHandle = nil end
end

-- ==========================================
-- 4. 视觉与动画引擎
-- ==========================================
function mod:CreateUI()
    if self.mainFrame then return end
    self.mainFrame = CreateFrame("Frame", "WishFlex_LustMainFrame", E.UIParent)
    self.mainFrame:SetSize(150, 150)
    self.mainFrame:SetPoint("CENTER", E.UIParent, "CENTER", 0, 150)
    self.mainFrame:SetFrameStrata("HIGH")
    E:CreateMover(self.mainFrame, "WishFlex_LustMonitorMover", "嗜血监测动画", nil, nil, nil, "ALL,WishFlex")

    self.bg = self.mainFrame:CreateTexture(nil, "BACKGROUND")
    self.bg:SetPoint("CENTER", self.mainFrame, "CENTER", 0, 0)
    self.bg:SetSize(150, 150) 
    self.bg:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]]) 
    self.bg:SetVertexColor(0, 0, 0, 1)

    self.tex = self.mainFrame:CreateTexture(nil, "ARTWORK")
    self.tex:SetAllPoints()
    self.tex:SetTexture(TGA_PATH)
    self.tex:SetBlendMode("ADD")

    self.timerText = self.mainFrame:CreateFontString(nil, "OVERLAY")
    self:UpdateTimerSettings() 

    local currentFrame, animElapsed, COLS, ROWS, TOTAL = 0, 0, 8, 16, 121
    self.mainFrame:SetScript("OnUpdate", function(s, delta)
        -- 播放序列帧
        animElapsed = animElapsed + delta
        if animElapsed > 0.04 then
            animElapsed = 0; currentFrame = (currentFrame + 1) % TOTAL
            local row, col = math.floor(currentFrame / COLS), currentFrame % COLS
            self.tex:SetTexCoord(col/COLS, (col+1)/COLS, row/ROWS, (row+1)/ROWS)
        end
        
        -- 更新倒计时数字
        if isLustActive or self.IsPreviewing then
            if self.IsPreviewing then
                timeLeft = timeLeft - delta
                if timeLeft <= 0 then timeLeft = 40 end
            else
                -- 核心计时逻辑：根据触发时间计算剩余 40 秒
                if lustStartTime > 0 then
                    timeLeft = 40 - (GetTime() - lustStartTime)
                    if timeLeft <= 0 then mod:EndLustVisuals() end
                end
            end
            
            if timeLeft > 0 then
                self.timerText:SetFormattedText("%d", math.ceil(timeLeft))
            end
        end
    end)
    self.mainFrame:Hide()
end

function mod:PlayLustAnimation()
    if not self.mainFrame then self:CreateUI() end
    if self.IsPreviewing then
        -- 修复：取消预览时绝对不碰触战斗状态变量 isLustActive
        self.IsPreviewing = false
        if not isLustActive then
            self.mainFrame:Hide()
            self:StopLustSound()
        end
        E:Print("|cff00ffccWishFlex:|r 嗜血预览已关闭")
    else
        self.IsPreviewing = true
        self.mainFrame:Show()
        self:UpdateTimerSettings() 
        timeLeft = 40
        if E.db.WishFlex.lustMonitor.playSound then
            self:StopLustSound()
            local _, handle = PlaySoundFile(SOUND_PATH, "Master")
            activeSoundHandle = handle
        end
        E:Print("|cff00ffccWishFlex:|r 嗜血预览已开启")
    end
end

-- ==========================================
-- 5. 核心：双重触发机制 (施法监听 + 光环兜底)
-- ==========================================
function mod:TriggerLustVisuals(startTime)
    if self.IsPreviewing then return end
    lustStartTime = startTime or GetTime()
    isLustActive = true
    if not self.mainFrame then self:CreateUI() end
    self.mainFrame:Show()
    if E.db.WishFlex.lustMonitor.playSound then 
        self:StopLustSound()
        local _, handle = PlaySoundFile(SOUND_PATH, "Master")
        activeSoundHandle = handle
    end
end

function mod:EndLustVisuals()
    isLustActive = false
    timeLeft = 0
    lustStartTime = 0
    if self.mainFrame and not self.IsPreviewing then self.mainFrame:Hide() end
    self:StopLustSound()
end

-- 兜底方法：扫描心满意足等 Debuff，防重载断线
function mod:SyncLustAura()
    if self.IsPreviewing or InCombatLockdown() then return end
    
    local found = false
    for i = 1, 40 do
        local success, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HARMFUL")
        if success and aura then
            local isSafe, isTarget = pcall(function() return LUST_IDS[aura.spellId] end)
            if isSafe and isTarget then
                lustStartTime = aura.expirationTime - 600
                found = true
                break
            end
        end
    end
    
    if found then
        local remain = 40 - (GetTime() - lustStartTime)
        if remain > 0 and not isLustActive then
            self:TriggerLustVisuals(lustStartTime)
        elseif remain <= 0 and isLustActive then
            self:EndLustVisuals()
        end
    end
end

-- ==========================================
-- 6. 初始化与事件挂载
-- ==========================================
function mod:Initialize()
    InjectOptions()
    if not E.db.WishFlex.modules.lustMonitor then return end 
    self:CreateUI()
    
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
        if self.IsPreviewing then return end
        
        pcall(function()
            if spellID and LUST_IDS[spellID] then
                mod:TriggerLustVisuals(GetTime())
            end
        end)
    end)
    
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function() mod:SyncLustAura() end)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function() mod:SyncLustAura() end)
    C_Timer.NewTicker(2.0, function() mod:SyncLustAura() end)
end
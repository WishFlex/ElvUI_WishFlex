local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local MOD = WUI:NewModule('RareAlert', 'AceEvent-3.0', 'AceTimer-3.0')
local S = E:GetModule('Skins')
local LSM = E.Libs.LSM

-- ==========================================
-- 1. 默认数据库注入
-- ==========================================
P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.rareAlert = true 
P["WishFlex"].rareAlert = {
    sound = "Warning", 
    soundID = 11466,
    duration = 30, 
}

-- ==========================================
-- 2. 设置菜单注入
-- ==========================================
local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.widgets = WUI.OptionsArgs.widgets or { order = 30, type = "group", name = "|cff00cccc小工具|r", childGroups = "tab", args = {} }
    WUI.OptionsArgs.widgets.args.rareAlert = {
        order = 4, type = "group", name = "稀有报警",
        hidden = function() return not C_AddOns.IsAddOnLoaded("RareScanner") end,
        args = {
            enable = { order = 1, type = "toggle", name = "接管 RareScanner", desc = "将原版弹窗幽灵化并流放到屏幕外，彻底替换为 WishFlex 的极简提示条。\n\n|cff00ffcc提示：请在 RareScanner 原版设置中关闭声音，由下方选项统一接管。|r", get = function() return E.db.WishFlex.modules.rareAlert end, set = function(_, v) E.db.WishFlex.modules.rareAlert = v; E:StaticPopup_Show("CONFIG_RL") end },
            duration = { order = 2, type = "range", name = "显示时长 (秒)", desc = "设置为 0 时将永久显示，直到手动关闭。", min = 0, max = 120, step = 1, get = function() return E.db.WishFlex.rareAlert.duration end, set = function(_, v) E.db.WishFlex.rareAlert.duration = v end },
            sound = { order = 3, type = "select", dialogControl = 'LSM30_Sound', name = "警报声音", values = LSM:HashTable("sound"), get = function() return E.db.WishFlex.rareAlert.sound end, set = function(_, v) E.db.WishFlex.rareAlert.sound = v end },
            test = { order = 4, type = "execute", name = "测试报警", func = function() MOD:TestAlert() end },
        }
    }
end

-- ==========================================
-- 3. WishFlex 核心极简弹窗
-- ==========================================
local WISH3_TEX = [[Interface\AddOns\ElvUI_WishFlex\Media\Textures\Wish3.tga]]
local lastAlertName = ""

function MOD:CreateAlertFrame()
    if self.frame then return end
    local holder = CreateFrame("Frame", "WishFlex_RareAlertHolder", E.UIParent)
    holder:SetSize(280, 60)
    holder:SetPoint("TOP", E.UIParent, "TOP", 0, -180)
    self.holder = holder

    local f = CreateFrame("Button", "WishFlex_RareAlertFrame", holder, "SecureActionButtonTemplate, BackdropTemplate")
    f:SetSize(280, 60)
    f:SetPoint("CENTER", holder, "CENTER")
    f:SetTemplate("Transparent") -- StripeSkin 会自动拦截这一步并铺上斜纹！
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:RegisterForClicks("LeftButtonDown", "RightButtonDown")
    f:Hide()

    local portraitBack = CreateFrame("Frame", nil, f, "BackdropTemplate")
    portraitBack:SetSize(48, 48)
    portraitBack:SetPoint("LEFT", f, "LEFT", 8, 0)
    portraitBack:SetTemplate("Default")
    portraitBack:SetFrameLevel(f:GetFrameLevel() + 2)
    f.portraitBack = portraitBack

    local portrait = CreateFrame("PlayerModel", nil, portraitBack)
    portrait:SetInside(portraitBack)
    f.portrait = portrait
    
    local text = f:CreateFontString(nil, "OVERLAY")
    text:FontTemplate(nil, 16, "OUTLINE")
    text:SetPoint("LEFT", portraitBack, "RIGHT", 15, 0) 
    text:SetJustifyH("LEFT")
    f.text = text

    local statusBar = CreateFrame("StatusBar", nil, f)
    statusBar:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 1, -3)
    statusBar:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -1, -3)
    statusBar:SetHeight(6) 
    statusBar:SetStatusBarTexture(WISH3_TEX) 
    
    local classColor = E:ClassColor(E.myclass, true)
    statusBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
    
    statusBar:CreateBackdrop("Transparent") -- StripeSkin 同样会自动拦截进度条背景！
    f.statusBar = statusBar

    local close = CreateFrame("Button", nil, f)
    close:SetSize(16, 16) 
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    close:SetFrameLevel(f:GetFrameLevel() + 50) 
    close:EnableMouse(true)
    
    if S then S:HandleCloseButton(close) end
    
    close:SetScript("OnClick", function(self) 
        f:SetScript("OnUpdate", nil) 
        f:Hide() 
    end)
    f.close = close

    self.frame = f
    E:CreateMover(holder, "WishFlex_RareAlertMover", "稀有精英报警", nil, nil, nil, "ALL,WishFlex")
end

function MOD:TriggerAlert(name, unit, npcID, displayID, isChestFallback)
    if not name or name == "" then return end
    if lastAlertName == name and name ~= "测试稀有精英" then return end
    
    lastAlertName = name
    E:Delay(10, function() lastAlertName = "" end)

    self:CreateAlertFrame()
    
    self.frame.portraitBack:Hide()
    self.frame.portrait:Hide()
    self.frame.portrait:ClearModel()
    
    -- 🔥 渲染逻辑
    if name == "测试稀有精英" then
        self.frame.portraitBack:Show()
        self.frame.portrait:Show()
        self.frame.portrait:SetUnit("player")
        self.frame.portrait:SetCamera(0)
        self.frame.text:ClearAllPoints()
        self.frame.text:SetPoint("LEFT", self.frame.portraitBack, "RIGHT", 15, 0) 
        
    elseif not isChestFallback and (npcID or displayID) then
        self.frame.portraitBack:Show()
        self.frame.portrait:Show()
        
        if npcID and npcID > 0 then
            self.frame.portrait:SetCreature(npcID)
        elseif displayID and displayID > 0 then
            self.frame.portrait:SetDisplayInfo(displayID)
        end
        
        self.frame.portrait:SetCamera(0)
        self.frame.text:ClearAllPoints()
        self.frame.text:SetPoint("LEFT", self.frame.portraitBack, "RIGHT", 15, 0) 
    else
        self.frame.text:ClearAllPoints()
        self.frame.text:SetPoint("LEFT", self.frame, "LEFT", 20, 0)
    end

    self.frame.text:SetText("|cff00ffcc发现稀有!|r\n" .. name)
    self.frame:Show()

    if not InCombatLockdown() then
        self.frame:SetAttribute("type", "macro")
        self.frame:SetAttribute("macrotext", "/target " .. name .. "\n/tm 8")
    end

    local db = E.db.WishFlex.rareAlert
    local soundPath = db and db.sound and LSM:Fetch("sound", db.sound)
    if soundPath then 
        PlaySoundFile(soundPath, "Master") 
    else 
        PlaySound(11466, "Master") 
    end

    local duration = db.duration or 30
    self.frame:SetScript("OnUpdate", nil) 

    if duration > 0 then
        self.frame.statusBar:Show()
        if self.frame.statusBar.backdrop then self.frame.statusBar.backdrop:Show() end
        self.frame.statusBar:SetMinMaxValues(0, duration)
        self.frame.statusBar:SetValue(duration)
        
        local startTime = GetTime()
        self.frame:SetScript("OnUpdate", function(self, elapsed)
            local remain = duration - (GetTime() - startTime)
            if remain <= 0 then
                self:SetScript("OnUpdate", nil)
                self:Hide()
            else
                self.statusBar:SetValue(remain)
            end
        end)
    else
        self.frame.statusBar:Hide()
        if self.frame.statusBar.backdrop then self.frame.statusBar.backdrop:Hide() end
    end
end

function MOD:TestAlert()
    if self.frame then 
        self.frame:SetScript("OnUpdate", nil)
        self.frame:Hide() 
    end
    self:TriggerAlert("测试稀有精英", "player")
end

-- ==========================================
-- 4. 终极截胡：模型与文本双重认证
-- ==========================================
local rsHooked = false

function MOD:StealFromRareScanner()
    if rsHooked then return end
    
    local rsButton = _G.RARESCANNER_BUTTON
    
    if rsButton then
        rsHooked = true
        
        rsButton:SetAlpha(0)
        rsButton:EnableMouse(false)
        rsButton:SetScale(0.0001)
        rsButton:ClearAllPoints()
        rsButton:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10000, 10000)

        hooksecurefunc(rsButton, "SetPoint", function(self, point, relTo, relPoint, x, y)
            if E.db.WishFlex.modules.rareAlert and (x ~= -10000) then
                self:ClearAllPoints()
                self:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10000, 10000)
            end
        end)
        
        local captureTimer = nil
        local function CaptureRareData()
            if not E.db.WishFlex.modules.rareAlert then return end
            
            if captureTimer then E:CancelTimer(captureTimer) end
            captureTimer = E:Delay(0.1, function()
                captureTimer = nil
                
                local rareName = "未知稀有"
                if rsButton.Title and rsButton.Title:GetText() and rsButton.Title:GetText() ~= "" then
                    rareName = rsButton.Title:GetText()
                elseif rsButton.Description_text and rsButton.Description_text:GetText() and rsButton.Description_text:GetText() ~= "" then
                    rareName = rsButton.Description_text:GetText()
                end
                
                local npcID = tonumber(rsButton.npcId) or tonumber(rsButton.entityID)
                local displayID = nil
                
                if rsButton.ModelView and type(rsButton.ModelView.GetDisplayInfo) == "function" then
                    displayID = tonumber(rsButton.ModelView:GetDisplayInfo())
                end
                
                local isChestFallback = false
                if rsButton.isContainer or rsButton.isEvent then
                    isChestFallback = true
                end
                if rareName and (string.find(rareName, "事件") or string.find(rareName, "宝箱") or string.find(rareName, "箱")) then
                    isChestFallback = true
                end
                
                MOD:TriggerAlert(rareName, nil, npcID, displayID, isChestFallback)
            end)
        end
        
        rsButton:HookScript("OnShow", CaptureRareData)
        if rsButton.Title then
            hooksecurefunc(rsButton.Title, "SetText", CaptureRareData)
        end
        if rsButton.Description_text then
            hooksecurefunc(rsButton.Description_text, "SetText", CaptureRareData)
        end
        
    else
        E:Delay(2, function() MOD:StealFromRareScanner() end)
    end
end

function MOD:Initialize()
    if not C_AddOns.IsAddOnLoaded("RareScanner") then return end
    InjectOptions()
    if not E.db.WishFlex.modules.rareAlert then return end
    
    self:CreateAlertFrame()
    self:StealFromRareScanner()
end
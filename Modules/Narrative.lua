local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex') 
local WFN = WUI:NewModule('WishFlex_Narrative', 'AceEvent-3.0', 'AceHook-3.0')

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.narrative = true
P["WishFlex"].narrative = {
    width = 800,
    height = 650,
    markHighestSellPrice = true, 
    disabledByConflict = false,
    autoSelectNPCs = "", -- 【新增】用于存储 NPC 自动选择配置
}

local classColor = E:ClassColor(E.myclass, true)
local CR, CG, CB = 0, 1, 0.8 
local CHEX = "|cff00ffcc"
if classColor then
    CR, CG, CB = classColor.r, classColor.g, classColor.b
    CHEX = E:RGBToHex(CR, CG, CB)
end

E.PopupDialogs["WISHFLEX_CONFLICT_DIALOGUEUI"] = {
    text = CHEX.."WishFlex 冲突警告！|r\n\n检测到您同时启用了 [Dialogue UI] 插件。\n这两个插件都在尝试接管任务界面，会导致面板闪退或无法交互。\n\n请选择您要保留哪一个？(选择后将自动重载界面)",
    button1 = "保留 WishFlex",
    button2 = "保留 Dialogue UI",
    button3 = "稍后再说",
    OnAccept = function()
        C_AddOns.DisableAddOn("DialogueUI")
        ReloadUI()
    end,
    OnCancel = function(self, data, reason)
        if reason == "clicked" then
            E.db.WishFlex.modules.narrative = false
            E.db.WishFlex.narrative.disabledByConflict = true 
            ReloadUI()
        end
    end,
    OnAlt = function()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = false,
}

local function SafeText(str) return str and tostring(str) or "" end

local function SafeGetNumCurrencies(questID)
    local c = C_QuestInfoSystem.GetQuestRewardCurrencies(questID)
    return c and #c or 0
end

local function SafeGetCurrencyInfo(type, i)
    local info
    if type == "reward" or type == "choice" then
        info = C_QuestOffer.GetQuestRewardCurrencyInfo(type, i)
    elseif type == "required" then
        info = C_QuestOffer.GetQuestRequiredCurrencyInfo(i)
    end
    if info then
        return info.name, info.texture, info.totalRewardAmount or info.requiredAmount or 1, info.quality or 1
    end
end

local function SafeGetRepRewards()
    return C_QuestOffer.GetQuestOfferMajorFactionReputationRewards() or {}
end

local function CreateActionButton(parent, text, point, relativeFrame, relativePoint, x, y)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(160, 40) 
    btn:SetPoint(point, relativeFrame, relativePoint, x, y)
    btn:SetTemplate("Transparent")
    
    btn.Text = btn:CreateFontString(nil, "OVERLAY")
    btn.Text:FontTemplate(nil, 15, "NONE")
    btn.Text:SetPoint("CENTER", 0, 0)
    btn.Text:SetText(text)
    
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(CR, CG, CB) 
        self.Text:SetTextColor(CR, CG, CB)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetTemplate("Transparent")
        self.Text:SetTextColor(1, 1, 1)
    end)
    return btn
end

local function CreateOptionButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetTemplate("Transparent")

    btn.Text = btn:CreateFontString(nil, "OVERLAY")
    btn.Text:FontTemplate(nil, 18, "NONE") 
    btn.Text:SetPoint("LEFT", btn, "LEFT", 20, 0)
    btn.Text:SetJustifyH("LEFT")
    btn.Text:SetWordWrap(false)
    
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(CR, CG, CB) 
        self.Text:SetTextColor(CR, CG, CB)
        self:SetBackdropColor(CR, CG, CB, 0.15) 
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetTemplate("Transparent")
        self.Text:SetTextColor(1, 1, 1)
    end)
    return btn
end

local function CreateItemButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetTemplate("Transparent")
    btn:SetFrameLevel(parent:GetFrameLevel() + 5)
    
    btn.Icon = btn:CreateTexture(nil, "ARTWORK", nil, 2)
    btn.Icon:SetSize(36, 36)
    btn.Icon:SetPoint("LEFT", 4, 0)
    btn.Icon:SetTexCoord(unpack(E.TexCoords)) 
    
    btn.IconBorder = CreateFrame("Frame", nil, btn)
    btn.IconBorder:SetTemplate("Default")
    btn.IconBorder:SetOutside(btn.Icon)
    btn.IconBorder:SetFrameLevel(btn:GetFrameLevel() - 1)
    
    btn.Count = btn:CreateFontString(nil, "OVERLAY")
    btn.Count:FontTemplate(nil, 12, "OUTLINE")
    btn.Count:SetPoint("BOTTOMRIGHT", btn.Icon, "BOTTOMRIGHT", 2, -2)
    
    btn.Name = btn:CreateFontString(nil, "OVERLAY")
    btn.Name:FontTemplate(nil, 13, "NONE")
    btn.Name:SetPoint("LEFT", btn.Icon, "RIGHT", 10, 0)
    btn.Name:SetPoint("RIGHT", -5, 0)
    btn.Name:SetJustifyH("LEFT")
    btn.Name:SetWordWrap(false)
    
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(CR, CG, CB)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.itemType == "choice" or self.itemType == "reward" or self.itemType == "required" then
            if self.isCurrency then
                GameTooltip:SetQuestCurrency(self.itemType, self.index)
            else
                GameTooltip:SetQuestItem(self.itemType, self.index)
            end
            GameTooltip:Show()
        elseif self.itemType == "currency" then
            GameTooltip:SetQuestCurrency(self.currType, self.index)
            GameTooltip:Show()
        elseif self.itemType == "spell" then
            GameTooltip:SetQuestRewardSpell(self.index)
            GameTooltip:Show()
        end
    end)
    
    btn:SetScript("OnLeave", function(self)
        if WFN.SelectedChoice ~= self.index or self.itemType ~= "choice" then
            self:SetTemplate("Transparent")
        end
        GameTooltip:Hide()
    end)
    
    btn:SetScript("OnClick", function(self)
        if self.itemType == "choice" then
            WFN:SelectRewardChoice(self.index)
        end
    end)
    
    return btn
end

function WFN:CreateUI()
    local cfg = E.db.WishFlex.narrative
    local frame = CreateFrame("Frame", "WishFlexNarrativeFrame", UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    frame:SetTemplate("Transparent")
    frame.EntranceAnim = frame:CreateAnimationGroup()
    
    local alpha = frame.EntranceAnim:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0.2)
    alpha:SetSmoothing("OUT")
    
    local scale = frame.EntranceAnim:CreateAnimation("Scale")
    scale:SetScaleFrom(0.9, 0.9)
    scale:SetScaleTo(1, 1)
    scale:SetDuration(0.2)
    scale:SetSmoothing("OUT")
    scale:SetOrigin("CENTER", 0, 0)

    frame:SetScript("OnShow", function(self)
        self.EntranceAnim:Play()
    end)
    
    tinsert(UISpecialFrames, "WishFlexNarrativeFrame")

    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        E.db.WishFlex = E.db.WishFlex or {}
        E.db.WishFlex.NarrativePos = {point, relativePoint, xOfs, yOfs}
    end)

    if E.db.WishFlex.NarrativePos then
        local pos = E.db.WishFlex.NarrativePos
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    end

    frame.Title = frame:CreateFontString(nil, "OVERLAY")
    frame.Title:FontTemplate(nil, 24, "OUTLINE") 
    frame.Title:SetPoint("TOP", frame, "TOP", 0, -40)
    frame.Title:SetTextColor(CR, CG, CB) 

    local scrollFrame = CreateFrame("ScrollFrame", "WishFlexNarrativeScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 70, -90)
    
    local S = E:GetModule('Skins')
    if S and S.HandleScrollBar and _G["WishFlexNarrativeScrollFrameScrollBar"] then
        S:HandleScrollBar(_G["WishFlexNarrativeScrollFrameScrollBar"])
    end

    local scrollChild = CreateFrame("Frame", "WishFlexNarrativeScrollChild", scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)

    frame.Text = scrollChild:CreateFontString(nil, "OVERLAY")
    frame.Text:FontTemplate(nil, 15, "NONE")
    frame.Text:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
    frame.Text:SetJustifyH("LEFT")
    frame.Text:SetJustifyV("TOP")
    frame.Text:SetSpacing(8) 

    frame.RewardTitle = frame:CreateFontString(nil, "OVERLAY")
    frame.RewardTitle:FontTemplate(nil, 14, "OUTLINE")
    frame.RewardTitle:Hide()

    frame.AcceptButton = CreateActionButton(frame, "接取 (Space)", "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -70, 30)
    frame.AcceptButton:SetScript("OnClick", function() WFN:HandleSpacebar() end)
    
    frame.DeclineButton = CreateActionButton(frame, "拒绝 (Esc)", "BOTTOMLEFT", frame, "BOTTOMLEFT", 70, 30)
    frame.DeclineButton:SetScript("OnClick", function() frame:Hide() end)

    self.Frame = frame
    self.ScrollFrame = scrollFrame
    self.ScrollChild = scrollChild
    self.OptionButtons = {} 
    self.ItemButtons = {}
    self.CurrentKeyCallbacks = {} 
    self.CurrentMode = ""
    self.SelectedChoice = nil

    frame:SetScript("OnHide", function()
        C_GossipInfo.CloseGossip() 
        CloseQuest()
    end)

    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "SPACE" then
            self:SetPropagateKeyboardInput(false)
            WFN:HandleSpacebar()
        elseif tonumber(key) and tonumber(key) >= 1 and tonumber(key) <= 9 then
            self:SetPropagateKeyboardInput(false)
            WFN:HandleNumberKey(tonumber(key))
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    self:UpdateSize()
end

function WFN:UpdateSize()
    if not self.Frame then return end
    local cfg = E.db.WishFlex.narrative
    local w = cfg.width or 800
    local h = cfg.height or 650
    self.Frame:SetSize(w, h)
    
    local contentWidth = w - 140
    self.ScrollChild:SetWidth(contentWidth)
    self.Frame.Text:SetWidth(contentWidth)

    if self.CurrentMode == "QUEST_DETAIL" or self.CurrentMode == "QUEST_COMPLETE" or self.CurrentMode == "QUEST_PROGRESS" then
        self:UpdateQuestItems()
    elseif self.CurrentMode == "GOSSIP" or self.CurrentMode == "QUEST_GREETING" then
        self:UpdateGossipOptions()
    end
end

function WFN:SetContentText(text)
    self.Frame.Text:SetText(text)
    self.ScrollFrame:SetVerticalScroll(0)
    self:UpdateScrollState()
end

function WFN:UpdateScrollState()
    C_Timer.After(0.01, function()
        if not self.ScrollFrame or not self.Frame:IsShown() then return end
        
        local contentHeight = self.Frame.Text:GetStringHeight()
        
        if self.CurrentMode == "GOSSIP" or self.CurrentMode == "QUEST_GREETING" then
            local activeOptions = 0
            for _, btn in ipairs(self.OptionButtons) do
                if btn and btn:IsShown() then
                    activeOptions = activeOptions + 1
                end
            end
            if activeOptions > 0 then
                contentHeight = contentHeight + 25 + (activeOptions * 50) + ((activeOptions - 1) * 12)
            end
        end

        self.ScrollChild:SetHeight(contentHeight + 20)
        
        local frameHeight = self.ScrollFrame:GetHeight()
        local scrollBar = _G["WishFlexNarrativeScrollFrameScrollBar"]
        
        if scrollBar then
            if contentHeight > frameHeight then
                scrollBar:Show()
            else
                scrollBar:Hide()
                self.ScrollFrame:SetVerticalScroll(0)
            end
        end
    end)
end

function WFN:RegisterGameEvents()
    if CustomGossipFrameManager then CustomGossipFrameManager:UnregisterAllEvents() end
    if _G.GossipFrame then _G.GossipFrame:UnregisterAllEvents() end
    if _G.QuestFrame then _G.QuestFrame:UnregisterAllEvents() end

    local events = {
        "GOSSIP_SHOW", "GOSSIP_CLOSED",
        "QUEST_GREETING", "QUEST_DETAIL",
        "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED",
        "QUEST_ITEM_UPDATE"
    }
    for _, event in ipairs(events) do
        self:RegisterEvent(event)
    end
end

function WFN:UpdateGossipOptions()
    for _, btn in ipairs(self.OptionButtons) do btn:Hide() end
    wipe(self.CurrentKeyCallbacks)
    
    local contentWidth = (E.db.WishFlex.narrative.width or 800) - 140
    local buttonIndex = 1
    local function AddOption(displayText, callback)
        if buttonIndex > 9 then return end 
        local btn = self.OptionButtons[buttonIndex]
        if not btn then
            btn = CreateOptionButton(self.ScrollChild)
            self.OptionButtons[buttonIndex] = btn
        end
        
        btn:SetParent(self.ScrollChild)
        btn:SetSize(contentWidth, 50) 
        btn:ClearAllPoints()
        
        if buttonIndex == 1 then
            btn:SetPoint("TOPLEFT", self.Frame.Text, "BOTTOMLEFT", 0, -25)
        else
            btn:SetPoint("TOPLEFT", self.OptionButtons[buttonIndex - 1], "BOTTOMLEFT", 0, -12)
        end
        
        btn.Text:SetText(string.format("%s[ %d ]|r %s", CHEX, buttonIndex, displayText))
        btn:SetScript("OnClick", callback)
        btn:Show()
        self.CurrentKeyCallbacks[buttonIndex] = callback
        buttonIndex = buttonIndex + 1
    end

    if self.CurrentMode == "GOSSIP" then
        local avail = C_GossipInfo.GetAvailableQuests()
        if avail then for _, q in ipairs(avail) do AddOption(CHEX .. "[任务]|r " .. SafeText(q.title), function() C_GossipInfo.SelectAvailableQuest(q.questID) end) end end

        local active = C_GossipInfo.GetActiveQuests()
        if active then for _, q in ipairs(active) do AddOption((q.isComplete and CHEX .. "[可交]|r " or "|cff888888[进行中]|r ") .. SafeText(q.title), function() C_GossipInfo.SelectActiveQuest(q.questID) end) end end

        local opts = C_GossipInfo.GetOptions()
        if opts then for _, o in ipairs(opts) do AddOption(SafeText(o.name), function() C_GossipInfo.SelectOption(o.gossipOptionID) end) end end
        
    elseif self.CurrentMode == "QUEST_GREETING" then
        local numAvail = GetNumAvailableQuests() or 0
        for i = 1, numAvail do
            AddOption(CHEX .. "[任务]|r " .. SafeText(GetAvailableTitle(i)), function() SelectAvailableQuest(i) end)
        end
        
        local numActive = GetNumActiveQuests() or 0
        for i = 1, numActive do
            local title = GetActiveTitle(i)
            local isComplete = false
            if IsActiveQuestComplete then isComplete = IsActiveQuestComplete(i) end
            
            AddOption((isComplete and CHEX .. "[可交]|r " or "|cff888888[进行中]|r ") .. SafeText(title), function() SelectActiveQuest(i) end)
        end
    end

    self.ScrollFrame:SetPoint("BOTTOMRIGHT", self.Frame, "BOTTOMRIGHT", -70, 90)
    self:UpdateScrollState()
end

function WFN:SelectRewardChoice(index)
    self.SelectedChoice = index
    for _, btn in ipairs(self.ItemButtons) do
        if btn.itemType == "choice" then
            if btn.index == index then
                btn:SetBackdropBorderColor(CR, CG, CB)
                PlaySound(856) 
            else
                btn:SetTemplate("Transparent") 
            end
        end
    end
end

function WFN:UpdateQuestItems()
    for _, btn in ipairs(self.ItemButtons) do btn:Hide() end
    self.SelectedChoice = nil
    
    local rewards = {}
    local questID = GetQuestID() or 0
    
    if self.CurrentMode == "QUEST_PROGRESS" then
        local numReqItems = GetNumQuestItems() or 0
        for i = 1, numReqItems do
            local name, tex, count, qual = GetQuestItemInfo("required", i)
            tinsert(rewards, {type="required", index=i, name=name, tex=tex, count=count, qual=qual})
        end
        local numReqCurs = SafeGetNumCurrencies(questID)
        for i = 1, numReqCurs do
            local name, tex, count, qual = SafeGetCurrencyInfo("required", i)
            tinsert(rewards, {type="currency", currType="required", index=i, name=name, tex=tex, count=count, qual=qual})
        end
        local reqMoney = GetQuestMoneyToGet() or 0
        if reqMoney > 0 then
            local g, s, c = math.floor(reqMoney/10000), math.floor((reqMoney%10000)/100), reqMoney%100
            local mText = (g>0 and g.."金 " or "")..(s>0 and s.."银 " or "")..(c>0 and c.."铜" or "")
            tinsert(rewards, {type="money", name=mText, tex=133784, count=1, qual=1, isMoney=true})
        end
    else
        local numChoices = GetNumQuestChoices() or 0
        local getLootType = GetQuestItemInfoLootType or function() return 0 end
        local highestPrice, highestIdx = 0, nil
        
        for i = 1, numChoices do
            local isCurrency = (getLootType("choice", i) == 1)
            local name, tex, count, qual
            if isCurrency then
                name, tex, count, qual = SafeGetCurrencyInfo("choice", i)
            else
                name, tex, count, qual = GetQuestItemInfo("choice", i)
                if E.db.WishFlex.narrative.markHighestSellPrice then
                    local link = GetQuestItemLink("choice", i)
                    if link then
                        local _, _, _, _, _, _, _, _, _, _, itemSellPrice = C_Item.GetItemInfo(link)
                        local totalValue = (itemSellPrice or 0) * (count > 0 and count or 1)
                        if totalValue > highestPrice then
                            highestPrice = totalValue
                            highestIdx = i
                        end
                    end
                end
            end
            tinsert(rewards, {type="choice", index=i, name=name, tex=tex, count=count, qual=qual, isCurrency=isCurrency, hotkey=i})
        end
        
        if highestIdx then
            for _, r in ipairs(rewards) do
                if r.type == "choice" and r.index == highestIdx then r.isHighestValue = true end
            end
        end
        
        local numRewards = GetNumQuestRewards() or 0
        for i = 1, numRewards do
            local name, tex, count, qual = GetQuestItemInfo("reward", i)
            tinsert(rewards, {type="reward", index=i, name=name, tex=tex, count=count, qual=qual})
        end
        
        local numCurrencies = SafeGetNumCurrencies(questID)
        for i = 1, numCurrencies do
            local name, tex, count, qual = SafeGetCurrencyInfo("reward", i)
            tinsert(rewards, {type="currency", currType="reward", index=i, name=name, tex=tex, count=count, qual=qual})
        end
        
        local repRewards = SafeGetRepRewards()
        for i, rep in ipairs(repRewards) do
            local name = rep.factionName or "声望"
            tinsert(rewards, {type="rep", index=i, name=name.." +"..(rep.rewardAmount or 0), tex=133711, count=1, qual=3})
        end
        
        local spellRewards = C_QuestInfoSystem.GetQuestRewardSpells(questID) or {}
        for _, spellID in ipairs(spellRewards) do
            if spellID > 0 then
                local spellInfo = C_QuestInfoSystem.GetQuestRewardSpellInfo(questID, spellID)
                if spellInfo and spellInfo.name then
                    tinsert(rewards, {type="spell", index=spellID, name=spellInfo.name, tex=spellInfo.texture, count=1, qual=1})
                end
            end
        end
        
        if GetRewardSkillPoints then
            local skillName, skillIcon, skillPoints = GetRewardSkillPoints()
            if skillPoints then
                tinsert(rewards, {type="skill", name=skillName, tex=skillIcon, count=skillPoints, qual=1})
            end
        end
        
        local xp = GetRewardXP() or 0
        if xp > 0 then 
            local xpText = xp
            if xp >= 10000 then
                xpText = string.format("%.1fw", xp / 10000)
            end
            tinsert(rewards, {type="xp", name=xpText, tex=[[Interface\AddOns\ElvUI_WishFlex\Media\Textures\XP_Icon.tga]], count=1, qual=1}) 
        end
        
        local money = GetRewardMoney() or 0
        if money > 0 then
            local g, s, c = math.floor(money/10000), math.floor((money%10000)/100), money%100
            local mText = (g>0 and g.."金 " or "")..(s>0 and s.."银 " or "")..(c>0 and c.."铜" or "")
            tinsert(rewards, {type="money", name=mText, tex=133784, count=1, qual=1, isMoney=true})
        end
    end

    local totalRewards = #rewards
    if totalRewards == 0 then
        self.Frame.RewardTitle:Hide()
        self.ScrollFrame:SetPoint("BOTTOMRIGHT", self.Frame, "BOTTOMRIGHT", -70, 90)
        self:UpdateScrollState()
        return
    end

    self.Frame.RewardTitle:Show()
    if self.CurrentMode == "QUEST_PROGRESS" then
        self.Frame.RewardTitle:SetText(CHEX .. "需要提供：|r")
    elseif GetNumQuestChoices() > 0 then
        self.Frame.RewardTitle:SetText(CHEX .. "奖励 (请通过按键或点击选择)：|r")
    else
        self.Frame.RewardTitle:SetText(CHEX .. "任务奖励：|r")
    end

    local contentWidth = (E.db.WishFlex.narrative.width or 800) - 140
    local spacing = 8
    local cols = math.max(2, math.floor((contentWidth + spacing) / (210 + spacing)))
    local itemWidth = (contentWidth - (cols - 1) * spacing) / cols

    local rows = math.ceil(totalRewards / cols)
    local rewardAreaHeight = 58 + (rows * 50)
    self.ScrollFrame:SetPoint("BOTTOMRIGHT", self.Frame, "BOTTOMRIGHT", -70, 70 + rewardAreaHeight)
    self.Frame.RewardTitle:SetPoint("TOPLEFT", self.ScrollFrame, "BOTTOMLEFT", 0, -15)

    for i, reward in ipairs(rewards) do
        local btn = self.ItemButtons[i]
        if not btn then
            btn = CreateItemButton(self.Frame)
            self.ItemButtons[i] = btn
        end
        
        btn.itemType = reward.type
        btn.currType = reward.currType
        btn.index = reward.index
        btn.isCurrency = reward.isCurrency
        
        local displayName = SafeText(reward.name) ~= "" and reward.name or "读取中..."
        if reward.hotkey then
            local prefix = CHEX .. "[ " .. reward.hotkey .. " ]|r "
            if reward.isHighestValue then prefix = prefix .. "|cffffd100[最贵 💰]|r " end
            displayName = prefix .. displayName
        end
        
        btn.Icon:Show()
        btn.IconBorder:Show()
        btn.Name:ClearAllPoints()
        btn.Name:SetPoint("LEFT", btn.Icon, "RIGHT", 10, 0)
        btn.Name:SetPoint("RIGHT", -5, 0)
        btn.Name:SetJustifyH("LEFT")
        
        btn.Name:SetText(displayName) 
        btn.Icon:SetTexture(reward.tex or 134400) 
        
        local cntText = ""
        if reward.count and reward.count > 1 then
            if reward.count >= 10000 then cntText = string.format("%.1fw", reward.count / 10000) else cntText = reward.count end
        end
        btn.Count:SetText(cntText)
        
        if reward.type == "xp" then
            btn.Name:SetTextColor(CR, CG, CB)
            btn.IconBorder:SetBackdropBorderColor(CR, CG, CB)
        elseif reward.isMoney then
            btn.Name:SetTextColor(1, 0.8, 0)
            btn.IconBorder:SetBackdropBorderColor(1, 0.8, 0)
        elseif reward.qual and reward.qual > 1 then
            local r, g, b = C_Item.GetItemQualityColor(reward.qual)
            if r then
                btn.Name:SetTextColor(r, g, b)
                btn.IconBorder:SetBackdropBorderColor(r, g, b)
            end
        else
            btn.Name:SetTextColor(1, 1, 1)
            btn.IconBorder:SetBackdropBorderColor(0, 0, 0)
        end
        
        btn:ClearAllPoints()
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        
        btn:SetSize(itemWidth, 44)
        btn:SetPoint("TOPLEFT", self.Frame.RewardTitle, "BOTTOMLEFT", col * (itemWidth + spacing), -(row * 50) - 15)
        
        btn:SetTemplate("Transparent")
        btn:Show()
    end

    self:UpdateScrollState()
end

function WFN:CheckConflictAndBlock()
    local isLoaded = C_AddOns.IsAddOnLoaded("DialogueUI")
    
    if isLoaded and E.db.WishFlex.modules.narrative then
        E:StaticPopup_Show("WISHFLEX_CONFLICT_DIALOGUEUI")
        C_GossipInfo.CloseGossip() 
        CloseQuest()
        return true
    end
    return false
end

-- 【新增】解析配置并自动选择 NPC 选项引擎
function WFN:ProcessAutoSelect()
    local guid = UnitGUID("npc")
    local npcID = guid and select(6, strsplit("-", guid))
    local autoSelectStr = E.db.WishFlex.narrative.autoSelectNPCs or ""
    
    if npcID and autoSelectStr ~= "" then
        for line in string.gmatch(autoSelectStr, "[^\r\n]+") do
            local id, idx = string.match(line, "^%s*(%d+)%s*:%s*(%d+)%s*$")
            if id == npcID then
                local targetIndex = tonumber(idx)
                if self.CurrentKeyCallbacks and self.CurrentKeyCallbacks[targetIndex] then
                    self.CurrentKeyCallbacks[targetIndex]() -- 瞬间选中该选项
                    return true
                end
            end
        end
    end
    return false
end

function WFN:PrepareUI(mode)
    self.CurrentMode = mode
    self.Frame.RewardTitle:Hide()
    for _, btn in ipairs(self.OptionButtons) do btn:Hide() end
    for _, btn in ipairs(self.ItemButtons) do btn:Hide() end
    wipe(self.CurrentKeyCallbacks)
end

function WFN:GOSSIP_SHOW()
    if self:CheckConflictAndBlock() then return end
    
    self:PrepareUI("GOSSIP")
    self.Frame.Title:SetText(SafeText(UnitName("npc")) ~= "" and SafeText(UnitName("npc")) or "未知目标")
    self:SetContentText(SafeText(C_GossipInfo.GetText()) ~= "" and SafeText(C_GossipInfo.GetText()) or "有什么我可以效劳的吗？")
    self.Frame.AcceptButton:Hide()
    self.Frame.DeclineButton:Hide()
    self:UpdateGossipOptions()
    
    -- 【新增】如果在列表里匹配到当前 NPC 的自动选取规则，则阻止面板显示
    if self:ProcessAutoSelect() then return end
    
    self.Frame:Show()
end

function WFN:QUEST_GREETING()
    if self:CheckConflictAndBlock() then return end
    
    self:PrepareUI("QUEST_GREETING")
    self.Frame.Title:SetText(SafeText(UnitName("npc")) ~= "" and SafeText(UnitName("npc")) or "未知目标")
    
    local greeting = SafeText(GetGreetingText())
    if greeting == "" then greeting = "请选择一个任务：" end
    self:SetContentText(greeting)
    
    self.Frame.AcceptButton:Hide()
    self.Frame.DeclineButton:Hide()
    self:UpdateGossipOptions()
    
    -- 【新增】自动选取规则同样适用于多任务问候界面
    if self:ProcessAutoSelect() then return end
    
    self.Frame:Show()
end

function WFN:QUEST_DETAIL()
    if self:CheckConflictAndBlock() then return end
    
    self:PrepareUI("QUEST_DETAIL")
    self.Frame.Title:SetText(SafeText(GetTitleText()))
    
    local qText = SafeText(GetQuestText())
    local qObj = SafeText(GetObjectiveText())
    local content = ""
    if qText ~= "" then content = content .. qText end
    if qObj ~= "" then content = content .. "\n\n" .. CHEX .. "[ 任务目标 ]|r\n" .. qObj end
    
    self:SetContentText(content)
    
    self.Frame.AcceptButton:Show()
    self.Frame.AcceptButton.Text:SetText("接取 (Space)")
    self.Frame.DeclineButton:Show()
    self.Frame.DeclineButton.Text:SetText("拒绝 (Esc)")
    self:UpdateQuestItems()
    self.Frame:Show()
end

function WFN:QUEST_COMPLETE()
    if self:CheckConflictAndBlock() then return end
    
    self:PrepareUI("QUEST_COMPLETE")
    self.Frame.Title:SetText(SafeText(GetTitleText()))
    self:SetContentText(SafeText(GetRewardText()) ~= "" and SafeText(GetRewardText()) or "你准备好完成任务了吗？")
    
    self.Frame.AcceptButton:Show()
    self.Frame.AcceptButton.Text:SetText("完成任务 (Space)")
    self.Frame.DeclineButton:Show()
    self.Frame.DeclineButton.Text:SetText("稍后 (Esc)")
    self:UpdateQuestItems()
    self.Frame:Show()
end

function WFN:QUEST_PROGRESS() 
    if self:CheckConflictAndBlock() then return end
    
    self:PrepareUI("QUEST_PROGRESS")
    self.Frame.Title:SetText(SafeText(GetTitleText()))
    self:SetContentText(SafeText(GetProgressText()) ~= "" and SafeText(GetProgressText()) or "任务进展得如何？")
    
    self.Frame.AcceptButton:Show()
    self.Frame.AcceptButton.Text:SetText("继续 (Space)")
    self.Frame.DeclineButton:Show()
    self.Frame.DeclineButton.Text:SetText("离开 (Esc)")
    self:UpdateQuestItems() 
    self.Frame:Show()
end

function WFN:QUEST_ITEM_UPDATE()
    if self.CurrentMode == "QUEST_DETAIL" or self.CurrentMode == "QUEST_COMPLETE" or self.CurrentMode == "QUEST_PROGRESS" then
        self:UpdateQuestItems()
    end
end

function WFN:GOSSIP_CLOSED() self.Frame:Hide() end
function WFN:QUEST_FINISHED() self.Frame:Hide() end

function WFN:HandleSpacebar()
    if self.CurrentMode == "QUEST_DETAIL" then
        AcceptQuest()
        self.Frame:Hide()
    elseif self.CurrentMode == "QUEST_COMPLETE" then
        if GetNumQuestChoices() > 0 then
            if not self.SelectedChoice then
                print(CHEX .. "WishFlex:|r 任务有多件自选奖励，请按 1、2 等按键或用鼠标选择！")
                return
            end
            GetQuestReward(self.SelectedChoice)
        else
            GetQuestReward() 
        end
        self.Frame:Hide()
    elseif self.CurrentMode == "QUEST_PROGRESS" then
        CompleteQuest()
    elseif self.CurrentMode == "GOSSIP" or self.CurrentMode == "QUEST_GREETING" then
        if self.CurrentKeyCallbacks[1] and not self.CurrentKeyCallbacks[2] then
            self.CurrentKeyCallbacks[1]()
        end
    end
end

function WFN:HandleNumberKey(num)
    if (self.CurrentMode == "GOSSIP" or self.CurrentMode == "QUEST_GREETING") and self.CurrentKeyCallbacks[num] then
        self.CurrentKeyCallbacks[num]()
    elseif self.CurrentMode == "QUEST_COMPLETE" then
        local numChoices = GetNumQuestChoices() or 0
        if numChoices > 0 and num >= 1 and num <= numChoices then
            self:SelectRewardChoice(num)
        end
    end
end

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.widgets = WUI.OptionsArgs.widgets or { 
        order = 21, 
        type = "group", 
        name = "|cff00e5cc小工具|r", 
        childGroups = "tab", 
        args = {} 
    }
    WUI.OptionsArgs.widgets.args = WUI.OptionsArgs.widgets.args or {}
    WUI.OptionsArgs.widgets.args.narrative = {
        order = 22, type = "group", name = "沉浸任务",
        args = {
            enable = { 
                order = 1, type = "toggle", name = "启用模块", 
                get = function() return E.db.WishFlex.modules.narrative end, 
                set = function(_, v) 
                    E.db.WishFlex.modules.narrative = v
                    E.db.WishFlex.narrative.disabledByConflict = false 
                    E:StaticPopup_Show("CONFIG_RL") 
                end 
            }, 
            width = { 
                order = 2, type = "range", name = "界面宽度", min = 600, max = 1200, step = 10, 
                get = function() return E.db.WishFlex.narrative.width end, 
                set = function(_, v) E.db.WishFlex.narrative.width = v; if WFN.Frame then WFN:UpdateSize() end end 
            },
            height = { 
                order = 3, type = "range", name = "界面高度", min = 500, max = 1200, step = 10, 
                get = function() return E.db.WishFlex.narrative.height end, 
                set = function(_, v) E.db.WishFlex.narrative.height = v; if WFN.Frame then WFN:UpdateSize() end end 
            },
            markHighestSellPrice = { 
                order = 4, type = "toggle", name = "高亮最贵装备", desc = "自动计算多选一装备的售出价格，并在最贵的装备前打上标记。",
                get = function() return E.db.WishFlex.narrative.markHighestSellPrice end, 
                set = function(_, v) E.db.WishFlex.narrative.markHighestSellPrice = v; end 
            },
            -- 【新增】自定义自动选取输入选项
            autoSelectNPCs = {
                order = 5,
                type = "input",
                multiline = true,
                name = "自动选择 NPC 选项",
                desc = "输入 NPC 的 ID 和需要自动选择的选项序号，用英文冒号隔开，每行一条。\n\n获取 NPC ID：把鼠标放在 NPC 身上，查看 ElvUI 的信息提示框（通常在底部或右下角）。\n\n例如，想让 ID 为 12345 的 NPC 自动选择第 1 项：\n12345:1\n67890:2",
                get = function() return E.db.WishFlex.narrative.autoSelectNPCs end,
                set = function(_, v) E.db.WishFlex.narrative.autoSelectNPCs = v end,
                width = "full",
            },
        }
    }
end

hooksecurefunc(WUI, "Initialize", function() 
    if not WFN.Initialized then WFN:Initialize() end 
end)

function WFN:Initialize()
    if self.Initialized then return end
    self.Initialized = true
    InjectOptions() 
    
    if E.db.WishFlex.narrative.disabledByConflict and not C_AddOns.IsAddOnLoaded("DialogueUI") then
        E.db.WishFlex.modules.narrative = true
        E.db.WishFlex.narrative.disabledByConflict = false
        print(CHEX.."WishFlex:|r 检测到 Dialogue UI 已停用，已自动为您唤醒 [沉浸任务] 模块！")
    end

    if not E.db.WishFlex.modules.narrative then return end
    self:CreateUI()
    self:RegisterGameEvents()
end
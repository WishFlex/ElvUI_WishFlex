local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local CS = WUI:NewModule('WishFlex_ChatSetup', 'AceEvent-3.0')

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.chatSetup = true

_G.WishFlexGlobalDB = _G.WishFlexGlobalDB or {}

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.system = WUI.OptionsArgs.system or { order = 50, type = "group", name = "|cff0099cc系统设置|r", childGroups = "tab", args = {} }
    WUI.OptionsArgs.system.args.chat = {
        order = 2, type = "group", name = "聊天框同步",
        args = { 
            save = { order = 1, type = "execute", name = "记录当前聊天窗口", func = function() CS:SaveChatToTemplate() end },
            run = { order = 2, type = "execute", name = "应用聊天窗口模板", confirm = true, func = function() CS:SetupChat() end },
            desc = { order = 3, type = "description", name = "聊天框数据将保存在 WishFlex 独立数据库中，跨角色通用。" }
        }
    }
end

function CS:SaveChatToTemplate()
    _G.WishFlexGlobalDB.ChatTemplate = {}
    local template = _G.WishFlexGlobalDB.ChatTemplate
    local count = 0

    for i = 1, NUM_CHAT_WINDOWS do
        -- 获取第 7 和 9 个返回值，分别代表 shown(显示) 和 docked(已停靠)
        local name, fontSize, _, _, _, _, shown, _, docked = GetChatWindowInfo(i)
        
        -- 核心修复：只记录正在使用（显示或停靠）的窗口，彻底过滤掉暴雪隐藏的“僵尸窗口”
        if name and name ~= "" and (shown or docked or i == 1 or i == 2) then
            template[i] = {
                name = name,
                fontSize = fontSize,
                channels = { GetChatWindowChannels(i) }, 
                messages = { GetChatWindowMessages(i) }  
            }
            count = count + 1
        end
    end
    E:Print(string.format("|cff00ffccWishFlex:|r |cff00ff00聊天窗口配置记录成功！共抓取 %d 个有效窗口。|r", count))
end

function CS:SetupChat()
    local template = _G.WishFlexGlobalDB.ChatTemplate
    if type(template) ~= "table" or not next(template) then
        E:Print("|cff00ffccWishFlex:|r |cffff0000数据库为空！请先去原角色记录。|r") return
    end

    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame"..i]
        local data = template[i]

        if data then
            FCF_SetWindowName(frame, data.name)
            ChatFrame_RemoveAllMessageGroups(frame)
            ChatFrame_RemoveAllChannels(frame)
            
            for _, msgType in ipairs(data.messages) do 
                ChatFrame_AddMessageGroup(frame, msgType) 
            end
            
            if i == 1 then
                ChatFrame_ReceiveAllPrivateMessages(frame)
            end
            
            if i > 2 then
                frame:Show()
                FCF_DockFrame(frame) 
                local tab = _G["ChatFrame"..i.."Tab"]
                if tab then tab:Show() end
            end
            FCF_SetChatWindowFontSize(nil, frame, data.fontSize or 12)
        else
            -- 如果模板里没有这个窗口（比如语音聊天），强行关闭、取消停靠、隐藏标签！
            if i > 2 then
                FCF_SetWindowName(frame, "")
                ChatFrame_RemoveAllMessageGroups(frame)
                ChatFrame_RemoveAllChannels(frame)
                FCF_Close(frame)
                FCF_UnDockFrame(frame)
                local tab = _G["ChatFrame"..i.."Tab"]
                if tab then tab:Hide() end
            end
        end
    end

    E:Delay(2, function()
        for i = 1, NUM_CHAT_WINDOWS do
            local data = template[i]
            local frame = _G["ChatFrame"..i]
            if data and frame and data.channels and i ~= 2 then
                for c = 1, #data.channels, 2 do
                    local chanName = data.channels[c]
                    if chanName then
                        JoinChannelByName(chanName)
                        ChatFrame_AddChannel(frame, chanName)
                    end
                end
            end
        end
        
        local CH = E:GetModule('Chat')
        if CH then
            if CH.UpdateChatTabs then CH:UpdateChatTabs() end
            if CH.PositionChat then CH:PositionChat(true) end
        end
        E:Print("|cff00ffccWishFlex:|r 聊天窗口已按模板绝对镜像还原！")
    end)
end

function CS:Initialize()
    InjectOptions()
end
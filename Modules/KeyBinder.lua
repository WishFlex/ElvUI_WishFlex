local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local KB = WUI:NewModule('WishFlex_KeyBinder', 'AceEvent-3.0')

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.keybinder = true

_G.WishFlexGlobalDB = _G.WishFlexGlobalDB or {}

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.system = WUI.OptionsArgs.system or { order = 50, type = "group", name = "|cff0099cc系统设置|r", childGroups = "tab", args = {} }
    WUI.OptionsArgs.system.args.keybind = {
        order = 1, type = "group", name = "快捷键同步",
        args = {
            syncGrp = {
                order = 1, type = "group", name = "动作条与系统快捷键同步", guiInline = true,
                args = {
                    save = { order = 1, type = "execute", name = "记录当前按键", func = function() KB:SaveBindingsToTemplate() end },
                    run = { order = 2, type = "execute", name = "应用按键模板", confirm = true, confirmText = "确定应用？这将覆盖当前角色的按键。", func = function() KB:ApplyBindings() end },
                    desc = { order = 3, type = "description", name = "按键数据将保存在 WishFlex 独立数据库中，跨角色通用。" }
                }
            },
            hotkeyGrp = {
                order = 2, type = "group", name = "动作条隐藏/显示", guiInline = true,
                args = {
                    key = {
                        order = 1, type = "keybinding", name = "显示/隐藏",
                        get = function() return GetBindingKey("CLICK WishFlex_ToggleBarsButton:LeftButton") end,
                        set = function(_, key)
                            local old = GetBindingKey("CLICK WishFlex_ToggleBarsButton:LeftButton")
                            if old then SetBinding(old, nil) end
                            if key ~= "" then SetBinding(key, "CLICK WishFlex_ToggleBarsButton:LeftButton") end
                            SaveBindings(GetCurrentBindingSet())
                        end
                    }
                }
            }
        }
    }
end

local toggleBtn = CreateFrame("Button", "WishFlex_ToggleBarsButton", UIParent)
toggleBtn:SetScript("OnClick", function()
    local AB = E:GetModule('ActionBars')
    local currentState = E.db.actionbar["bar1"].visibility
    local nextState = (currentState ~= "hide") and "hide" or ""
    for n = 1, 6 do
        local barName = "bar"..n
        E.db.actionbar[barName].visibility = nextState
        if AB and AB.PositionAndSizeBar then AB:PositionAndSizeBar(barName) end
    end
    UIErrorsFrame:AddMessage("|cff00ffccWishFlex:|r 动作条 1-6 " .. ((nextState == "hide") and "|cffff0000已隐藏|r" or "|cff00ff00已显示|r"), 1, 1, 1, 1)
end)

_G["BINDING_HEADER_WishFlex"] = "|cff00ffccWishFlex|r"
_G["BINDING_NAME_CLICK WishFlex_ToggleBarsButton:LeftButton"] = "显示/隐藏动作条 1-6"

local function GetAllCommands()
    local commands = {}
    for i = 1, GetNumBindings() do
        local cmd = GetBinding(i)
        if cmd then commands[cmd] = true end
    end
    
    local AB = E:GetModule('ActionBars')
    if AB and AB.handledbuttons then
        for buttonFrame, _ in pairs(AB.handledbuttons) do
            if type(buttonFrame) == "table" and buttonFrame.GetName then
                local btnName = buttonFrame:GetName()
                if btnName then commands["CLICK "..btnName..":LeftButton"] = true end
            end
        end
    end
    return commands
end

function KB:SaveBindingsToTemplate()
    _G.WishFlexGlobalDB.KeybindTemplate = {}
    local template = _G.WishFlexGlobalDB.KeybindTemplate
    local count = 0

    local allCommands = GetAllCommands()
    for command in pairs(allCommands) do
        if command ~= "CLICK WishFlex_ToggleBarsButton:LeftButton" then
            local keys = { GetBindingKey(command) }
            if #keys > 0 then
                template[command] = keys
                count = count + #keys
            end
        end
    end
    
    E:Print(string.format("|cff00ffccWishFlex:|r 按键存入独立数据库成功！共捕获 |cff00ff00%d|r 个键位。", count))
end

function KB:ApplyBindings()
    local template = _G.WishFlexGlobalDB.KeybindTemplate
    if type(template) ~= "table" or not next(template) then
        E:Print("|cff00ffccWishFlex:|r |cffff0000数据库为空！请先去原角色记录。|r") return
    end

    -- 移除废弃的 SetCurrentBindingSet，保留正确的读取/写入 API
    if LoadBindings then LoadBindings(2) end

    local currentCustomKey = GetBindingKey("CLICK WishFlex_ToggleBarsButton:LeftButton")
    local allCommands = GetAllCommands()

    -- 1. 解绑旧按键
    for command in pairs(allCommands) do
        local keys = { GetBindingKey(command) }
        for _, key in ipairs(keys) do SetBinding(key, nil) end
    end

    -- 2. 应用新按键
    for command, keys in pairs(template) do
        for _, key in ipairs(keys) do SetBinding(key, command) end
    end
    
    if currentCustomKey then SetBinding(currentCustomKey, "CLICK WishFlex_ToggleBarsButton:LeftButton") end
    
    -- 保存为角色专用按键
    SaveBindings(2)

    -- 3. 强制刷新 ElvUI
    local AB = E:GetModule('ActionBars')
    if AB and AB.UpdateButtonBindings and AB.handledbuttons then
        for buttonFrame, _ in pairs(AB.handledbuttons) do
            if type(buttonFrame) == "table" then AB:UpdateButtonBindings(buttonFrame) end
        end
    end

    E:Print("|cff00ffccWishFlex:|r |cffffffff按键已完美同步，界面已刷新！|r")
end

function KB:Initialize()
    InjectOptions()
end
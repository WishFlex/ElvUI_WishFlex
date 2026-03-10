local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WF = E:GetModule('WishFlex')

-- 确保总收集器存在
WF.OptionsArgs = WF.OptionsArgs or {}

-- 载入顶层纯文本艺术排版 (高奢极简/大字距科技感设计)
WF.OptionsArgs.logoHeader = {
    order = 1, type = "group", name = " ", guiInline = true,
    args = {
        title = {
            order = 1, type = "description", fontSize = "large",
            -- 通过极宽的字母间距营造出极其大气、宽广的视觉张力，配合独家渐变色
            name = "\n\n" ..
                   "                                      |cff00ffccW|r    |cff00f8ccI|r    |cff00f1ccS|r    |cff00ebccH|r         |cff00e4ccF|r    |cff00ddaaL|r    |cff00d6aaE|r    |cff00cfaaX|r\n"
        },
        subtitle = {
            order = 2, type = "description", fontSize = "medium",
            -- 下方使用灰暗色的科技感斜杠修饰，形成强烈的“大与小、明与暗”的高级对比感
            name = "                                                  |cff333333//|r   |cff777777E L V U I   E N H A N C E M E N T|r   |cff333333//|r\n\n"
        }
    }
}

-- 【安全挂载】：通过 ElvUI 标准接口插入，保证不丢失
local function SetupWishFlexOptions()
    E.Options.args.WishFlex = {
        type = "group",
        -- 这里保留了左侧菜单树的小 LOGO 图标
        name = "|TInterface\\AddOns\\ElvUI_WishFlex\\Media\\Textures\\Logo.tga:16:16:0:0:64:64:0:64:0:64|t |cff00ffccWishFlex|r",
        order = 6,
        childGroups = "tree", 
        args = WF.OptionsArgs 
    }
end

-- 无论 ElvUI 界面处于何种加载阶段，确保菜单能安全打入
tinsert(E.ConfigModeLayouts, #(E.ConfigModeLayouts) + 1, "WishFlex")
if E.Initialized then
    SetupWishFlexOptions()
else
    hooksecurefunc(E, "Initialize", SetupWishFlexOptions)
end
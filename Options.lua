local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WF = E:GetModule('WishFlex')
WF.OptionsArgs = WF.OptionsArgs or {}
WF.OptionsArgs.logoHeader = {
    order = 1, type = "group", name = " ", guiInline = true,
    args = {
        title = {
            order = 1, type = "description", fontSize = "large",
            name = "\n\n" ..
                   "                                      |cff00ffccW|r    |cff00f8ccI|r    |cff00f1ccS|r    |cff00ebccH|r         |cff00e4ccF|r    |cff00ddaaL|r    |cff00d6aaE|r    |cff00cfaaX|r\n"
        },
        subtitle = {
            order = 2, type = "description", fontSize = "medium",
            name = "                                                  |cff333333//|r   |cff777777E L V U I   E N H A N C E M E N T|r   |cff333333//|r\n\n"
        }
    }
}
local function SetupWishFlexOptions()
    E.Options.args.WishFlex = {
        type = "group",
        name = "|TInterface\\AddOns\\ElvUI_WishFlex\\Media\\Textures\\Logo.tga:16:16:0:0:64:64:0:64:0:64|t |cff00ffccWishFlex|r",
        order = 6,
        childGroups = "tree", 
        args = WF.OptionsArgs 
    }
end
tinsert(E.ConfigModeLayouts, #(E.ConfigModeLayouts) + 1, "WishFlex")
if E.Initialized then
    SetupWishFlexOptions()
else
    hooksecurefunc(E, "Initialize", SetupWishFlexOptions)
end
-- GrippitzPoison: Poison Duration Display for Rogues (TBC Classic)
local addonName = "GrippitzPoison"
local GP = CreateFrame("Frame", "GrippitzPoisonFrame", UIParent)

-- ========== LOCALIZATION ==========

local L = {}
local locale = GetLocale()

if locale == "deDE" then
    L = {
        ADDON_LOADED = "|cFF00FF00GrippitzPoison|r geladen. Tippe |cFFFFFF00/gp|r für Optionen.",
        OPTIONS_TITLE = "GrippitzPoison Optionen",
        DISPLAY_MODE = "Modus:",
        ICON_MODE = "Icon",
        TEXT_MODE = "Text",
        SHOW_MAINHAND = "Haupthand",
        SHOW_OFFHAND = "Nebenhand",
        LOCK_POSITION = "Sperren",
        SHOW_BACKGROUND = "Hintergrund",
        ICON_SIZE = "Icon-Größe",
        FONT_SIZE = "Schriftgröße",
        WARNING_AT = "Warnung bei",
        MIN = "Min",
        RESET_POSITION = "Position Reset",
        RESET_ALL = "Alles Reset",
        POSITION_RESET = "Position zurückgesetzt.",
        ALL_RESET = "Alle Einstellungen zurückgesetzt.",
        LOCKED = "Gesperrt",
        UNLOCKED = "Entsperrt",
        TEST_MODE = "Vorschau aktiv.",
        MH = "HH",
        OH = "NH",
        NO_POISON_MH = "HH: KEIN GIFT!",
        NO_POISON_OH = "NH: KEIN GIFT!",
        ENABLE_WARNING = "Warnung",
        ENABLE_SOUND = "Sound",
        WEAPONS = "Waffen:",
        OPTIONS = "Optionen:",
        WARNINGS = "Warnungen:",
        SIZES = "Größen:",
    }
else
    L = {
        ADDON_LOADED = "|cFF00FF00GrippitzPoison|r loaded. Type |cFFFFFF00/gp|r for options.",
        OPTIONS_TITLE = "GrippitzPoison Options",
        DISPLAY_MODE = "Mode:",
        ICON_MODE = "Icon",
        TEXT_MODE = "Text",
        SHOW_MAINHAND = "MainHand",
        SHOW_OFFHAND = "OffHand",
        LOCK_POSITION = "Lock",
        SHOW_BACKGROUND = "Background",
        ICON_SIZE = "Icon Size",
        FONT_SIZE = "Font Size",
        WARNING_AT = "Warn at",
        MIN = "min",
        RESET_POSITION = "Reset Position",
        RESET_ALL = "Reset All",
        POSITION_RESET = "Position reset.",
        ALL_RESET = "All settings reset.",
        LOCKED = "Locked",
        UNLOCKED = "Unlocked",
        TEST_MODE = "Preview active.",
        MH = "MH",
        OH = "OH",
        NO_POISON_MH = "MH: NO POISON!",
        NO_POISON_OH = "OH: NO POISON!",
        ENABLE_WARNING = "Warning",
        ENABLE_SOUND = "Sound",
        WEAPONS = "Weapons:",
        OPTIONS = "Options:",
        WARNINGS = "Warnings:",
        SIZES = "Sizes:",
    }
end

-- ========== POISON DATA ==========

local POISON_TEXTURES = {
    [8679]  = "Interface\\Icons\\Ability_Poisons",
    [8686]  = "Interface\\Icons\\Ability_Poisons",
    [8688]  = "Interface\\Icons\\Ability_Poisons",
    [11338] = "Interface\\Icons\\Ability_Poisons",
    [11339] = "Interface\\Icons\\Ability_Poisons",
    [11340] = "Interface\\Icons\\Ability_Poisons",
    [26890] = "Interface\\Icons\\Ability_Poisons",
    [2823]  = "Interface\\Icons\\Ability_Rogue_DualWeild",
    [2824]  = "Interface\\Icons\\Ability_Rogue_DualWeild",
    [11355] = "Interface\\Icons\\Ability_Rogue_DualWeild",
    [11356] = "Interface\\Icons\\Ability_Rogue_DualWeild",
    [25351] = "Interface\\Icons\\Ability_Rogue_DualWeild",
    [26967] = "Interface\\Icons\\Ability_Rogue_DualWeild",
    [26968] = "Interface\\Icons\\Ability_Rogue_DualWeild",
    [3408]  = "Interface\\Icons\\Ability_PoisonSting",
    [11202] = "Interface\\Icons\\Ability_PoisonSting",
    [5761]  = "Interface\\Icons\\Spell_Nature_NullifyDisease",
    [8692]  = "Interface\\Icons\\Spell_Nature_NullifyDisease",
    [11398] = "Interface\\Icons\\Spell_Nature_NullifyDisease",
    [13219] = "Interface\\Icons\\INV_Misc_Herb_16",
    [13225] = "Interface\\Icons\\INV_Misc_Herb_16",
    [13226] = "Interface\\Icons\\INV_Misc_Herb_16",
    [13227] = "Interface\\Icons\\INV_Misc_Herb_16",
    [27188] = "Interface\\Icons\\INV_Misc_Herb_16",
    [26785] = "Interface\\Icons\\INV_Potion_53",
}

local DEFAULT_POISON_ICON = "Interface\\Icons\\Trade_BrewPoison"

-- ========== DEFAULTS ==========

local defaults = {
    displayMode = "icon",
    iconSize = 40,
    fontSize = 14,
    posX = 0,
    posY = -200,
    showMainHand = true,
    showOffHand = true,
    locked = false,
    showBackground = true,
    warningThreshold = 300,
    enableWarning = true,
    enableSound = true,
    soundInterval = 10,
}

-- ========== INITIALIZATION ==========

GrippitzPoisonDB = GrippitzPoisonDB or CopyTable(defaults)

for k, v in pairs(defaults) do
    if GrippitzPoisonDB[k] == nil then
        GrippitzPoisonDB[k] = v
    end
end

local lastSoundTime = 0
local previewMode = false

-- ========== HELPER FUNCTIONS ==========

local function IsRogue()
    local _, class = UnitClass("player")
    return class == "ROGUE"
end

local function HasMainHandWeapon()
    return GetInventoryItemID("player", 16) ~= nil
end

local function HasOffHandWeapon()
    local itemID = GetInventoryItemID("player", 17)
    if not itemID then return false end
    local _, _, _, _, _, itemType = GetItemInfo(itemID)
    return itemType == "Weapon" or itemType == "Waffe"
end

local function GetPoisonIcon(enchantID)
    return POISON_TEXTURES[enchantID] or DEFAULT_POISON_ICON
end

local function FormatTime(seconds)
    if seconds <= 0 then
        return "0:00"
    elseif seconds < 60 then
        return string.format("0:%02d", seconds)
    elseif seconds < 3600 then
        return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
    else
        return string.format("%d:%02d:%02d", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60), seconds % 60)
    end
end

local function GetTimeColor(seconds)
    if seconds <= GrippitzPoisonDB.warningThreshold then
        return 1, 0.2, 0.2
    elseif seconds <= GrippitzPoisonDB.warningThreshold * 2 then
        return 1, 1, 0.2
    else
        return 0.2, 1, 0.2
    end
end

local function PlayWarningSound()
    if GrippitzPoisonDB.enableSound then
        local now = GetTime()
        if now - lastSoundTime >= GrippitzPoisonDB.soundInterval then
            PlaySound(8959, "Master")
            lastSoundTime = now
        end
    end
end

-- ========== DISPLAY FRAMES ==========

GP:SetSize(200, 60)
GP:SetPoint("CENTER", UIParent, "CENTER", GrippitzPoisonDB.posX, GrippitzPoisonDB.posY)
GP:SetMovable(true)
GP:EnableMouse(true)
GP:RegisterForDrag("LeftButton")
GP:SetClampedToScreen(true)

GP.bg = GP:CreateTexture(nil, "BACKGROUND")
GP.bg:SetAllPoints()
GP.bg:SetColorTexture(0, 0, 0, 0.5)

-- MainHand Frame
GP.mainHand = CreateFrame("Frame", nil, GP)
GP.mainHand:SetSize(GrippitzPoisonDB.iconSize, GrippitzPoisonDB.iconSize)
GP.mainHand:SetPoint("LEFT", GP, "LEFT", 5, 0)

GP.mainHand.icon = GP.mainHand:CreateTexture(nil, "ARTWORK")
GP.mainHand.icon:SetAllPoints()
GP.mainHand.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

GP.mainHand.timer = GP.mainHand:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
GP.mainHand.timer:SetPoint("CENTER", GP.mainHand, "CENTER", 0, 0)
GP.mainHand.timer:SetFont("Fonts\\FRIZQT__.TTF", GrippitzPoisonDB.fontSize, "OUTLINE")

GP.mainHand.label = GP.mainHand:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
GP.mainHand.label:SetPoint("TOP", GP.mainHand, "BOTTOM", 0, -2)
GP.mainHand.label:SetText(L.MH)
GP.mainHand.label:SetTextColor(0.7, 0.7, 0.7)

-- OffHand Frame
GP.offHand = CreateFrame("Frame", nil, GP)
GP.offHand:SetSize(GrippitzPoisonDB.iconSize, GrippitzPoisonDB.iconSize)
GP.offHand:SetPoint("LEFT", GP.mainHand, "RIGHT", 10, 0)

GP.offHand.icon = GP.offHand:CreateTexture(nil, "ARTWORK")
GP.offHand.icon:SetAllPoints()
GP.offHand.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

GP.offHand.timer = GP.offHand:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
GP.offHand.timer:SetPoint("CENTER", GP.offHand, "CENTER", 0, 0)
GP.offHand.timer:SetFont("Fonts\\FRIZQT__.TTF", GrippitzPoisonDB.fontSize, "OUTLINE")

GP.offHand.label = GP.offHand:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
GP.offHand.label:SetPoint("TOP", GP.offHand, "BOTTOM", 0, -2)
GP.offHand.label:SetText(L.OH)
GP.offHand.label:SetTextColor(0.7, 0.7, 0.7)

-- Text mode display
GP.textDisplay = GP:CreateFontString(nil, "OVERLAY", "GameFontNormal")
GP.textDisplay:SetPoint("CENTER", GP, "CENTER", 0, 0)
GP.textDisplay:SetFont("Fonts\\FRIZQT__.TTF", GrippitzPoisonDB.fontSize, "OUTLINE")

-- Warning Frame
GP.warningFrame = CreateFrame("Frame", nil, GP)
GP.warningFrame:SetSize(200, 30)
GP.warningFrame:SetPoint("TOP", GP, "BOTTOM", 0, -5)

GP.warningText = GP.warningFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
GP.warningText:SetPoint("CENTER", GP.warningFrame, "CENTER", 0, 0)
GP.warningText:SetFont("Fonts\\FRIZQT__.TTF", GrippitzPoisonDB.fontSize, "OUTLINE")
GP.warningText:SetTextColor(1, 0, 0)

GP.warningFrame.flashTime = 0
GP.warningFrame.flashState = true

-- Dragging
GP:SetScript("OnDragStart", function(self)
    if not GrippitzPoisonDB.locked then
        self:StartMoving()
    end
end)

GP:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    GrippitzPoisonDB.posX = x
    GrippitzPoisonDB.posY = y
end)

-- ========== UPDATE LOGIC ==========

local function ShowPreview()
    GP:Show()
    GP.bg:Show()
    GP.warningFrame:Hide()
    
    if GrippitzPoisonDB.displayMode == "icon" then
        GP.textDisplay:Hide()
        GP.mainHand:Show()
        GP.mainHand.icon:SetTexture(DEFAULT_POISON_ICON)
        GP.mainHand.timer:SetText("25:00")
        GP.mainHand.timer:SetTextColor(0.2, 1, 0.2)
        GP.offHand:Show()
        GP.offHand:SetPoint("LEFT", GP.mainHand, "RIGHT", 10, 0)
        GP.offHand.icon:SetTexture("Interface\\Icons\\Ability_Poisons")
        GP.offHand.timer:SetText("3:45")
        GP.offHand.timer:SetTextColor(1, 0.2, 0.2)
    else
        GP.mainHand:Hide()
        GP.offHand:Hide()
        GP.textDisplay:Show()
        GP.textDisplay:SetText(L.MH .. ": |cFF33FF3325:00|r  " .. L.OH .. ": |cFFFF33333:45|r")
    end
end

local function UpdateDisplay()
    if not IsRogue() then
        GP:Hide()
        return
    end
    
    if previewMode then
        ShowPreview()
        return
    end
    
    local hasMainHandEnchant, mainHandExpiration, _, mainHandEnchantID,
          hasOffHandEnchant, offHandExpiration, _, offHandEnchantID = GetWeaponEnchantInfo()
    
    local mhTime = hasMainHandEnchant and math.floor(mainHandExpiration / 1000) or 0
    local ohTime = hasOffHandEnchant and math.floor(offHandExpiration / 1000) or 0
    
    local showMH = GrippitzPoisonDB.showMainHand and hasMainHandEnchant
    local showOH = GrippitzPoisonDB.showOffHand and hasOffHandEnchant
    
    local hasMHWeapon = HasMainHandWeapon()
    local hasOHWeapon = HasOffHandWeapon()
    local needsMHWarning = GrippitzPoisonDB.enableWarning and GrippitzPoisonDB.showMainHand and hasMHWeapon and not hasMainHandEnchant
    local needsOHWarning = GrippitzPoisonDB.enableWarning and GrippitzPoisonDB.showOffHand and hasOHWeapon and not hasOffHandEnchant
    
    local warningText = ""
    if needsMHWarning and needsOHWarning then
        warningText = L.NO_POISON_MH .. " | " .. L.NO_POISON_OH
    elseif needsMHWarning then
        warningText = L.NO_POISON_MH
    elseif needsOHWarning then
        warningText = L.NO_POISON_OH
    end
    
    if warningText ~= "" then
        GP.warningFrame:Show()
        GP.warningText:SetText(warningText)
        PlayWarningSound()
    else
        GP.warningFrame:Hide()
    end
    
    if not showMH and not showOH then
        if warningText == "" then
            GP:Hide()
            return
        else
            GP:Show()
            GP.mainHand:Hide()
            GP.offHand:Hide()
            GP.textDisplay:Hide()
            GP.bg:SetShown(GrippitzPoisonDB.showBackground and not GrippitzPoisonDB.locked)
            return
        end
    end
    
    GP:Show()
    GP.bg:SetShown(GrippitzPoisonDB.showBackground and not GrippitzPoisonDB.locked)
    
    if GrippitzPoisonDB.displayMode == "icon" then
        GP.textDisplay:Hide()
        
        if showMH then
            GP.mainHand:Show()
            GP.mainHand.icon:SetTexture(GetPoisonIcon(mainHandEnchantID))
            GP.mainHand.timer:SetText(FormatTime(mhTime))
            local r, g, b = GetTimeColor(mhTime)
            GP.mainHand.timer:SetTextColor(r, g, b)
        else
            GP.mainHand:Hide()
        end
        
        if showOH then
            GP.offHand:Show()
            GP.offHand.icon:SetTexture(GetPoisonIcon(offHandEnchantID))
            GP.offHand.timer:SetText(FormatTime(ohTime))
            local r, g, b = GetTimeColor(ohTime)
            GP.offHand.timer:SetTextColor(r, g, b)
            
            if not showMH then
                GP.offHand:SetPoint("LEFT", GP, "LEFT", 5, 0)
            else
                GP.offHand:SetPoint("LEFT", GP.mainHand, "RIGHT", 10, 0)
            end
        else
            GP.offHand:Hide()
        end
    else
        GP.mainHand:Hide()
        GP.offHand:Hide()
        GP.textDisplay:Show()
        
        local text = ""
        if showMH then
            local r, g, b = GetTimeColor(mhTime)
            local colorCode = string.format("|cFF%02X%02X%02X", r*255, g*255, b*255)
            text = L.MH .. ": " .. colorCode .. FormatTime(mhTime) .. "|r"
        end
        if showOH then
            local r, g, b = GetTimeColor(ohTime)
            local colorCode = string.format("|cFF%02X%02X%02X", r*255, g*255, b*255)
            if text ~= "" then text = text .. "  " end
            text = text .. L.OH .. ": " .. colorCode .. FormatTime(ohTime) .. "|r"
        end
        GP.textDisplay:SetText(text)
    end
end

local function ApplySettings()
    GP.mainHand:SetSize(GrippitzPoisonDB.iconSize, GrippitzPoisonDB.iconSize)
    GP.offHand:SetSize(GrippitzPoisonDB.iconSize, GrippitzPoisonDB.iconSize)
    
    GP.mainHand.timer:SetFont("Fonts\\FRIZQT__.TTF", GrippitzPoisonDB.fontSize, "OUTLINE")
    GP.offHand.timer:SetFont("Fonts\\FRIZQT__.TTF", GrippitzPoisonDB.fontSize, "OUTLINE")
    GP.textDisplay:SetFont("Fonts\\FRIZQT__.TTF", GrippitzPoisonDB.fontSize, "OUTLINE")
    GP.warningText:SetFont("Fonts\\FRIZQT__.TTF", GrippitzPoisonDB.fontSize, "OUTLINE")
    
    if GrippitzPoisonDB.displayMode == "icon" then
        local width = GrippitzPoisonDB.iconSize * 2 + 20
        GP:SetSize(width, GrippitzPoisonDB.iconSize + 20)
    else
        GP:SetSize(200, 30)
    end
    
    GP:ClearAllPoints()
    GP:SetPoint("CENTER", UIParent, "CENTER", GrippitzPoisonDB.posX, GrippitzPoisonDB.posY)
    
    UpdateDisplay()
end

-- Update timer
local updateInterval = 0.1
local timeSinceLastUpdate = 0

GP:SetScript("OnUpdate", function(self, elapsed)
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    if timeSinceLastUpdate >= updateInterval then
        UpdateDisplay()
        timeSinceLastUpdate = 0
    end
    
    if GP.warningFrame:IsShown() then
        GP.warningFrame.flashTime = GP.warningFrame.flashTime + elapsed
        if GP.warningFrame.flashTime >= 0.5 then
            GP.warningFrame.flashTime = 0
            GP.warningFrame.flashState = not GP.warningFrame.flashState
            GP.warningText:SetTextColor(GP.warningFrame.flashState and 1 or 1, GP.warningFrame.flashState and 0 or 0.5, 0)
        end
    end
end)

-- ========== CUSTOM SLIDER CREATION ==========

local function CreateCustomSlider(parent, name, minVal, maxVal, step)
    local slider = CreateFrame("Slider", name, parent, "BackdropTemplate")
    slider:SetSize(200, 20)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    
    -- Slider background (dark green track)
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 }
    })
    slider:SetBackdropColor(0.15, 0.15, 0.15, 1)
    
    -- Green track overlay
    slider.track = slider:CreateTexture(nil, "ARTWORK")
    slider.track:SetPoint("LEFT", slider, "LEFT", 3, 0)
    slider.track:SetPoint("RIGHT", slider, "RIGHT", -3, 0)
    slider.track:SetHeight(8)
    slider.track:SetColorTexture(0.2, 0.6, 0.2, 0.8)
    
    -- Thumb texture
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = slider:GetThumbTexture()
    thumb:SetSize(24, 24)
    
    -- Value text
    slider.valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slider.valueText:SetPoint("TOP", slider, "BOTTOM", 0, -2)
    
    slider:EnableMouse(true)
    
    return slider
end

-- ========== OPTIONS FRAME ==========

local optionsFrame = nil

local function CreateOptionsFrame()
    if optionsFrame then return optionsFrame end
    
    -- === LAYOUT CONSTANTS ===
    local PADDING = 15
    local ROW_HEIGHT = 28
    local SLIDER_HEIGHT = 55  -- Label + Slider + Value text
    local BUTTON_HEIGHT = 28
    local FRAME_WIDTH = 300
    
    -- Calculate total height
    local totalHeight = PADDING                    -- Top padding
                      + 25                         -- Title
                      + 10                         -- Space after title
                      + ROW_HEIGHT                 -- Mode row
                      + ROW_HEIGHT                 -- Weapons row
                      + ROW_HEIGHT                 -- Options row
                      + ROW_HEIGHT                 -- Warnings row
                      + 15                         -- Section gap
                      + SLIDER_HEIGHT              -- Icon size slider
                      + SLIDER_HEIGHT              -- Font size slider
                      + SLIDER_HEIGHT              -- Warning slider
                      + 20                         -- Gap before buttons
                      + BUTTON_HEIGHT              -- Buttons
                      + PADDING                    -- Bottom padding
    
    -- Main Frame
    optionsFrame = CreateFrame("Frame", "GrippitzPoisonOptionsFrame", UIParent, "BackdropTemplate")
    optionsFrame:SetSize(FRAME_WIDTH, totalHeight)
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    optionsFrame:SetBackdropColor(0.1, 0.1, 0.12, 1)
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:Hide()
    
    optionsFrame:SetScript("OnShow", function()
        previewMode = true
        UpdateDisplay()
    end)
    
    optionsFrame:SetScript("OnHide", function()
        previewMode = false
        UpdateDisplay()
    end)
    
    -- Close Button
    local closeBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    
    local y = -PADDING
    
    -- Title
    local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, y)
    title:SetText("|cFF00FF00" .. L.OPTIONS_TITLE .. "|r")
    y = y - 35
    
    -- === ROW 1: Display Mode ===
    local modeLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeLabel:SetPoint("TOPLEFT", PADDING, y)
    modeLabel:SetText(L.DISPLAY_MODE)
    modeLabel:SetTextColor(1, 0.82, 0)
    
    local iconModeBtn = CreateFrame("CheckButton", "GPIconModeBtn", optionsFrame, "UICheckButtonTemplate")
    iconModeBtn:SetPoint("TOPLEFT", 80, y + 4)
    _G[iconModeBtn:GetName().."Text"]:SetText(L.ICON_MODE)
    iconModeBtn:SetChecked(GrippitzPoisonDB.displayMode == "icon")
    
    local textModeBtn = CreateFrame("CheckButton", "GPTextModeBtn", optionsFrame, "UICheckButtonTemplate")
    textModeBtn:SetPoint("TOPLEFT", 170, y + 4)
    _G[textModeBtn:GetName().."Text"]:SetText(L.TEXT_MODE)
    textModeBtn:SetChecked(GrippitzPoisonDB.displayMode == "text")
    
    iconModeBtn:SetScript("OnClick", function()
        GrippitzPoisonDB.displayMode = "icon"
        iconModeBtn:SetChecked(true)
        textModeBtn:SetChecked(false)
        ApplySettings()
    end)
    
    textModeBtn:SetScript("OnClick", function()
        GrippitzPoisonDB.displayMode = "text"
        iconModeBtn:SetChecked(false)
        textModeBtn:SetChecked(true)
        ApplySettings()
    end)
    
    y = y - ROW_HEIGHT
    
    -- === ROW 2: Weapons ===
    local weaponsLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    weaponsLabel:SetPoint("TOPLEFT", PADDING, y)
    weaponsLabel:SetText(L.WEAPONS)
    weaponsLabel:SetTextColor(1, 0.82, 0)
    
    local mhCheckbox = CreateFrame("CheckButton", "GPShowMHCheckbox", optionsFrame, "UICheckButtonTemplate")
    mhCheckbox:SetPoint("TOPLEFT", 80, y + 4)
    _G[mhCheckbox:GetName().."Text"]:SetText(L.SHOW_MAINHAND)
    mhCheckbox:SetChecked(GrippitzPoisonDB.showMainHand)
    mhCheckbox:SetScript("OnClick", function(self)
        GrippitzPoisonDB.showMainHand = self:GetChecked()
        UpdateDisplay()
    end)
    
    local ohCheckbox = CreateFrame("CheckButton", "GPShowOHCheckbox", optionsFrame, "UICheckButtonTemplate")
    ohCheckbox:SetPoint("TOPLEFT", 170, y + 4)
    _G[ohCheckbox:GetName().."Text"]:SetText(L.SHOW_OFFHAND)
    ohCheckbox:SetChecked(GrippitzPoisonDB.showOffHand)
    ohCheckbox:SetScript("OnClick", function(self)
        GrippitzPoisonDB.showOffHand = self:GetChecked()
        UpdateDisplay()
    end)
    
    y = y - ROW_HEIGHT
    
    -- === ROW 3: Options ===
    local optLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    optLabel:SetPoint("TOPLEFT", PADDING, y)
    optLabel:SetText(L.OPTIONS)
    optLabel:SetTextColor(1, 0.82, 0)
    
    local lockCheckbox = CreateFrame("CheckButton", "GPLockCheckbox", optionsFrame, "UICheckButtonTemplate")
    lockCheckbox:SetPoint("TOPLEFT", 80, y + 4)
    _G[lockCheckbox:GetName().."Text"]:SetText(L.LOCK_POSITION)
    lockCheckbox:SetChecked(GrippitzPoisonDB.locked)
    lockCheckbox:SetScript("OnClick", function(self)
        GrippitzPoisonDB.locked = self:GetChecked()
        UpdateDisplay()
    end)
    
    local bgCheckbox = CreateFrame("CheckButton", "GPBGCheckbox", optionsFrame, "UICheckButtonTemplate")
    bgCheckbox:SetPoint("TOPLEFT", 170, y + 4)
    _G[bgCheckbox:GetName().."Text"]:SetText(L.SHOW_BACKGROUND)
    bgCheckbox:SetChecked(GrippitzPoisonDB.showBackground)
    bgCheckbox:SetScript("OnClick", function(self)
        GrippitzPoisonDB.showBackground = self:GetChecked()
        UpdateDisplay()
    end)
    
    y = y - ROW_HEIGHT
    
    -- === ROW 4: Warnings ===
    local warnLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    warnLabel:SetPoint("TOPLEFT", PADDING, y)
    warnLabel:SetText(L.WARNINGS)
    warnLabel:SetTextColor(1, 0.82, 0)
    
    local enableWarnCheckbox = CreateFrame("CheckButton", "GPEnableWarnCheckbox", optionsFrame, "UICheckButtonTemplate")
    enableWarnCheckbox:SetPoint("TOPLEFT", 80, y + 4)
    _G[enableWarnCheckbox:GetName().."Text"]:SetText(L.ENABLE_WARNING)
    enableWarnCheckbox:SetChecked(GrippitzPoisonDB.enableWarning)
    enableWarnCheckbox:SetScript("OnClick", function(self)
        GrippitzPoisonDB.enableWarning = self:GetChecked()
        UpdateDisplay()
    end)
    
    local enableSoundCheckbox = CreateFrame("CheckButton", "GPEnableSoundCheckbox", optionsFrame, "UICheckButtonTemplate")
    enableSoundCheckbox:SetPoint("TOPLEFT", 170, y + 4)
    _G[enableSoundCheckbox:GetName().."Text"]:SetText(L.ENABLE_SOUND)
    enableSoundCheckbox:SetChecked(GrippitzPoisonDB.enableSound)
    enableSoundCheckbox:SetScript("OnClick", function(self)
        GrippitzPoisonDB.enableSound = self:GetChecked()
    end)
    
    y = y - ROW_HEIGHT - 15  -- Extra gap before sliders
    
    -- === SLIDER SECTION ===
    local sizesLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizesLabel:SetPoint("TOPLEFT", PADDING, y)
    sizesLabel:SetText(L.SIZES)
    sizesLabel:SetTextColor(1, 0.82, 0)
    
    y = y - 20
    
    -- === SLIDER 1: Icon Size ===
    local iconSizeLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    iconSizeLabel:SetPoint("TOPLEFT", PADDING, y)
    iconSizeLabel:SetText(L.ICON_SIZE .. ":")
    
    local iconSizeValue = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    iconSizeValue:SetPoint("TOPRIGHT", -PADDING, y)
    iconSizeValue:SetText(GrippitzPoisonDB.iconSize)
    iconSizeValue:SetTextColor(0.4, 1, 0.4)
    
    y = y - 18
    
    local iconSizeSlider = CreateCustomSlider(optionsFrame, "GPIconSizeSlider", 20, 80, 2)
    iconSizeSlider:SetPoint("TOPLEFT", PADDING, y)
    iconSizeSlider:SetPoint("TOPRIGHT", -PADDING, y)
    iconSizeSlider:SetValue(GrippitzPoisonDB.iconSize)
    iconSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        GrippitzPoisonDB.iconSize = value
        iconSizeValue:SetText(value)
        ApplySettings()
    end)
    
    y = y - 35
    
    -- === SLIDER 2: Font Size ===
    local fontSizeLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fontSizeLabel:SetPoint("TOPLEFT", PADDING, y)
    fontSizeLabel:SetText(L.FONT_SIZE .. ":")
    
    local fontSizeValue = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fontSizeValue:SetPoint("TOPRIGHT", -PADDING, y)
    fontSizeValue:SetText(GrippitzPoisonDB.fontSize)
    fontSizeValue:SetTextColor(0.4, 1, 0.4)
    
    y = y - 18
    
    local fontSizeSlider = CreateCustomSlider(optionsFrame, "GPFontSizeSlider", 8, 28, 1)
    fontSizeSlider:SetPoint("TOPLEFT", PADDING, y)
    fontSizeSlider:SetPoint("TOPRIGHT", -PADDING, y)
    fontSizeSlider:SetValue(GrippitzPoisonDB.fontSize)
    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        GrippitzPoisonDB.fontSize = value
        fontSizeValue:SetText(value)
        ApplySettings()
    end)
    
    y = y - 35
    
    -- === SLIDER 3: Warning Threshold ===
    local warnThreshLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    warnThreshLabel:SetPoint("TOPLEFT", PADDING, y)
    warnThreshLabel:SetText(L.WARNING_AT .. ":")
    
    local warnThreshValue = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    warnThreshValue:SetPoint("TOPRIGHT", -PADDING, y)
    warnThreshValue:SetText(math.floor(GrippitzPoisonDB.warningThreshold / 60) .. " " .. L.MIN)
    warnThreshValue:SetTextColor(0.4, 1, 0.4)
    
    y = y - 18
    
    local warnSlider = CreateCustomSlider(optionsFrame, "GPWarnSlider", 60, 600, 30)
    warnSlider:SetPoint("TOPLEFT", PADDING, y)
    warnSlider:SetPoint("TOPRIGHT", -PADDING, y)
    warnSlider:SetValue(GrippitzPoisonDB.warningThreshold)
    warnSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        GrippitzPoisonDB.warningThreshold = value
        warnThreshValue:SetText(math.floor(value / 60) .. " " .. L.MIN)
    end)
    
    -- === BUTTONS ===
    local resetBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, BUTTON_HEIGHT)
    resetBtn:SetPoint("BOTTOMLEFT", PADDING, PADDING)
    resetBtn:SetText(L.RESET_POSITION)
    resetBtn:SetScript("OnClick", function()
        GrippitzPoisonDB.posX = defaults.posX
        GrippitzPoisonDB.posY = defaults.posY
        ApplySettings()
        print("|cFF00FF00GrippitzPoison:|r " .. L.POSITION_RESET)
    end)
    
    local resetAllBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    resetAllBtn:SetSize(120, BUTTON_HEIGHT)
    resetAllBtn:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)
    resetAllBtn:SetText(L.RESET_ALL)
    resetAllBtn:SetScript("OnClick", function()
        GrippitzPoisonDB = CopyTable(defaults)
        iconModeBtn:SetChecked(true)
        textModeBtn:SetChecked(false)
        mhCheckbox:SetChecked(true)
        ohCheckbox:SetChecked(true)
        lockCheckbox:SetChecked(false)
        bgCheckbox:SetChecked(true)
        enableWarnCheckbox:SetChecked(true)
        enableSoundCheckbox:SetChecked(true)
        iconSizeSlider:SetValue(defaults.iconSize)
        fontSizeSlider:SetValue(defaults.fontSize)
        warnSlider:SetValue(defaults.warningThreshold)
        iconSizeValue:SetText(defaults.iconSize)
        fontSizeValue:SetText(defaults.fontSize)
        warnThreshValue:SetText(math.floor(defaults.warningThreshold / 60) .. " " .. L.MIN)
        ApplySettings()
        print("|cFF00FF00GrippitzPoison:|r " .. L.ALL_RESET)
    end)
    
    return optionsFrame
end

-- ========== SLASH COMMANDS ==========

SLASH_GRIPPITZPOISON1 = "/grippitzpoison"
SLASH_GRIPPITZPOISON2 = "/gp"
SlashCmdList["GRIPPITZPOISON"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "lock" then
        GrippitzPoisonDB.locked = not GrippitzPoisonDB.locked
        print("|cFF00FF00GrippitzPoison:|r " .. (GrippitzPoisonDB.locked and L.LOCKED or L.UNLOCKED))
        UpdateDisplay()
    elseif msg == "reset" then
        GrippitzPoisonDB.posX = defaults.posX
        GrippitzPoisonDB.posY = defaults.posY
        ApplySettings()
        print("|cFF00FF00GrippitzPoison:|r " .. L.POSITION_RESET)
    elseif msg == "test" then
        previewMode = true
        ApplySettings()
        print("|cFF00FF00GrippitzPoison:|r " .. L.TEST_MODE)
    else
        local options = CreateOptionsFrame()
        if options:IsShown() then
            options:Hide()
        else
            options:Show()
        end
    end
end

-- ========== INITIALIZATION ==========

GP:RegisterEvent("PLAYER_ENTERING_WORLD")
GP:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if IsRogue() then
            ApplySettings()
            print(L.ADDON_LOADED)
        else
            GP:Hide()
        end
    end
end)

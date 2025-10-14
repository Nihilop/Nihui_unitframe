-- ui/text.lua - UI Components for Text Elements (Names, Levels, Values)
local _, ns = ...

-- UI Components namespace
ns.UI = ns.UI or {}
ns.UI.Text = {}

-- ===========================
-- TEXT FORMATTING UTILITIES
-- ===========================

-- Format health/power values according to style
local function FormatValue(value, maxValue, style)
    if not value or not maxValue then
        return ""
    end

    if maxValue == 0 then
        return "0"
    end

    local percent = math.floor((value / maxValue) * 100)

    if style == "full" then
        return string.format("%d / %d", value, maxValue)
    elseif style == "k_version" then
        return string.format("%s / %s", ns.FormatNumber(value), ns.FormatNumber(maxValue))
    elseif style == "percentage" or style == "percent" then
        return string.format("%d%%", percent)
    elseif style == "current_only" or style == "current" then
        return tostring(value)
    elseif style == "current_k" then
        return ns.FormatNumber(value)
    elseif style == "current_percent" then
        return string.format("%s (%d%%)", ns.FormatNumber(value), percent)
    else
        -- Default: k_version
        return string.format("%s / %s", ns.FormatNumber(value), ns.FormatNumber(maxValue))
    end
end

-- Number formatting function (1k, 1.5m)
function ns.FormatNumber(num)
    if not num then return "0" end

    if num >= 1000000 then
        return string.format("%.1fm", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.0fk", num / 1000)
    else
        return tostring(num)
    end
end

-- Power type colors
function ns.UI.Text.GetPowerTextColor(powerType)
    local colors = {
        [0] = {0.2, 0.6, 1.0},    -- Mana - Blue
        [1] = {1.0, 0.0, 0.0},    -- Rage - Red
        [2] = {1.0, 0.5, 0.25},   -- Focus - Orange
        [3] = {1.0, 1.0, 0.0},    -- Energy - Yellow
        [6] = {0.8, 0.4, 0.8},    -- Runic Power - Purple
    }

    local color = colors[powerType] or {1, 1, 1} -- Default white
    return color[1], color[2], color[3]
end

-- ===========================
-- TEXT ELEMENT CREATION
-- ===========================

-- Create text element with proper positioning and z-index
function ns.UI.Text.CreateTextElement(parent, config)
    -- Create a separate frame for text to control frame level properly
    local textFrame = CreateFrame("Frame", nil, parent)
    textFrame:SetAllPoints(parent)
    textFrame:SetFrameLevel(parent:GetFrameLevel() + 10) -- Ensure it's on top

    -- Create text on the dedicated frame
    local text = textFrame:CreateFontString(nil, "OVERLAY")

    -- Font validation with fallback
    local actualFont = config.font or "Fonts\\FRIZQT__.TTF"
    if LibStub and LibStub:GetLibrary("LibSharedMedia-3.0", true) then
        local LSM = LibStub("LibSharedMedia-3.0")
        local fontPath = LSM:Fetch("font", config.font)
        if fontPath then
            actualFont = fontPath
        else
            actualFont = "Fonts\\FRIZQT__.TTF"
        end
    end

    -- Set font with error handling
    local success, err = pcall(text.SetFont, text, actualFont, config.size or 12, config.outline or "OUTLINE")
    if not success then
        text:SetFont("Fonts\\FRIZQT__.TTF", config.size or 12, config.outline or "OUTLINE")
    end

    -- Set color
    if config.color then
        text:SetTextColor(config.color[1], config.color[2], config.color[3], config.color[4] or 1)
    else
        text:SetTextColor(1, 1, 1, 1) -- Default white
    end

    -- Position text (HARDCODED - always CENTER)
    text:ClearAllPoints()
    text:SetPoint("CENTER", textFrame, "CENTER", config.x or 0, config.y or 0)  -- HARDCODED

    return text, textFrame
end

-- ===========================
-- SPECIALIZED TEXT COMPONENTS
-- ===========================

-- Create health value text
function ns.UI.Text.CreateHealthText(parent, config)
    local text, textFrame = ns.UI.Text.CreateTextElement(parent, config)

    -- Store config reference for real-time updates
    text.config = config

    -- Add update function
    text.UpdateValue = function(self, current, max)
        local style = self.config and self.config.style or "k_version"
        local displayText = FormatValue(current, max, style)
        self:SetText(displayText)
    end

    return text, textFrame
end

-- Create power value text
function ns.UI.Text.CreatePowerText(parent, config)
    -- IMPORTANT: Remove color from config to prevent initial color being set
    -- Power text color is HARDCODED and managed dynamically by UpdateValue
    local configCopy = {}
    for k, v in pairs(config) do
        if k ~= "color" and k ~= "colorByPowerType" then
            configCopy[k] = v
        end
    end

    local text, textFrame = ns.UI.Text.CreateTextElement(parent, configCopy)

    -- Store original config reference for real-time updates (for style, font, etc.)
    text.config = config

    -- Add update function with automatic power bar color
    text.UpdateValue = function(self, current, max, powerType)
        local style = self.config and self.config.style or "k_version"
        local displayText = FormatValue(current, max, style)
        self:SetText(displayText)

        -- HARDCODED: Always use same color as power bar (not configurable)
        -- Use GetPowerColor from systems/power.lua for consistency
        if ns.Systems and ns.Systems.Power and ns.Systems.Power.GetPowerColor then
            local color = ns.Systems.Power.GetPowerColor(powerType)
            self:SetTextColor(color[1], color[2], color[3], 1)
        else
            -- Fallback to white if power system not loaded yet
            self:SetTextColor(1, 1, 1, 1)
        end
    end

    return text, textFrame
end

-- Create name text (unit name)
function ns.UI.Text.CreateNameText(parent, config)
    local text, textFrame = ns.UI.Text.CreateTextElement(parent, config)

    -- Add update function
    text.UpdateValue = function(self, unitToken)
        local name = UnitName(unitToken) or ""
        self:SetText(name)

        -- Apply intelligent coloring (class for players, reaction for NPCs)
        if config.colorByClass then
            local color = ns.GetUnitColor and ns.GetUnitColor(unitToken)
            if color then
                self:SetTextColor(unpack(color))
            end
        end
    end

    return text, textFrame
end

-- Create level text
function ns.UI.Text.CreateLevelText(parent, config)
    local text, textFrame = ns.UI.Text.CreateTextElement(parent, config)

    -- Add update function
    text.UpdateValue = function(self, unitToken)
        local level = UnitLevel(unitToken)
        if level == -1 then
            self:SetText("??")
        else
            self:SetText(tostring(level))
        end
    end

    return text, textFrame
end

-- ===========================
-- TEXT SET CREATION
-- ===========================

-- Create complete text set for a unit frame
function ns.UI.Text.CreateTextSet(parent, healthFrame, powerFrame, config)
    local textSet = {}

    -- Health text
    if config.health and config.health.enabled then
        textSet.health, textSet.healthFrame = ns.UI.Text.CreateHealthText(healthFrame, config.health)
    end

    -- Power text
    if config.power and config.power.enabled then
        textSet.power, textSet.powerFrame = ns.UI.Text.CreatePowerText(powerFrame, config.power)
    end

    -- Create name & level container (backup logic)
    local needsNameLevelContainer = config.nameLevel and config.nameLevel.enabled and
                                   ((config.name and config.name.enabled) or (config.level and config.level.enabled))
    if needsNameLevelContainer then
        -- Create container frame above health bar (same width as health bar)
        local nameLevelContainer = CreateFrame("Frame", nil, parent)
        nameLevelContainer:SetSize(healthFrame:GetWidth(), 20) -- BACKUP: Container width = health bar width

        -- Use unified container offset (backup logic)
        local containerOffset = config.nameLevel.containerOffset or {x = 0, y = 5}
        nameLevelContainer:SetPoint("BOTTOMLEFT", healthFrame, "TOPLEFT",
            containerOffset.x, containerOffset.y)
        nameLevelContainer:SetFrameLevel(healthFrame:GetFrameLevel() + 15)

        textSet.nameLevelContainer = nameLevelContainer

        -- Set initial visibility based on backup logic
        local nameVisible = config.name and config.name.enabled and config.name.show
        local levelVisible = config.level and config.level.enabled and config.level.show

        if not (nameVisible or levelVisible) then
            nameLevelContainer:Hide()
        end

        -- Level text (positioned left in container)
        if config.level and config.level.enabled then
            textSet.level = nameLevelContainer:CreateFontString(nil, "OVERLAY")

            -- Font setup for level
            local levelFont = config.level.font or "Fonts\\FRIZQT__.TTF"
            if LibStub and LibStub:GetLibrary("LibSharedMedia-3.0", true) then
                local LSM = LibStub("LibSharedMedia-3.0")
                local fontPath = LSM:Fetch("font", levelFont)
                if fontPath then
                    levelFont = fontPath
                end
            end

            local success = textSet.level:SetFont(levelFont, config.level.size or 11, config.level.outline or "OUTLINE")
            if not success then
                textSet.level:SetFont("Fonts\\FRIZQT__.TTF", config.level.size or 11, config.level.outline or "OUTLINE")
            end

            -- UI ONLY: Set appearance, positioning handled by systems/text.lua
            textSet.level:SetTextColor(1, 1, 0, 1) -- Yellow for level
            textSet.level:SetShadowOffset(1, -1)
            textSet.level:SetShadowColor(0, 0, 0, 0.8)

            -- Add update function
            textSet.level.UpdateValue = function(self, unitToken)
                local level = UnitLevel(unitToken)
                if level == -1 then
                    self:SetText("??")
                else
                    self:SetText(tostring(level))
                end
            end

            -- Set initial visibility based on show flag (backup logic)
            if not config.level.show then
                textSet.level:Hide()
            end
        end

        -- Name text (positioned right of level in container)
        if config.name and config.name.enabled then
            textSet.name = nameLevelContainer:CreateFontString(nil, "OVERLAY")

            -- Font setup for name
            local nameFont = config.name.font or "Fonts\\FRIZQT__.TTF"
            if LibStub and LibStub:GetLibrary("LibSharedMedia-3.0", true) then
                local LSM = LibStub("LibSharedMedia-3.0")
                local fontPath = LSM:Fetch("font", nameFont)
                if fontPath then
                    nameFont = fontPath
                end
            end

            local success = textSet.name:SetFont(nameFont, config.name.size or 11, config.name.outline or "OUTLINE")
            if not success then
                textSet.name:SetFont("Fonts\\FRIZQT__.TTF", config.name.size or 11, config.name.outline or "OUTLINE")
            end

            -- UI ONLY: Set appearance, positioning handled by systems/text.lua
            textSet.name:SetTextColor(1, 1, 1, 1) -- Default white
            textSet.name:SetShadowOffset(1, -1)
            textSet.name:SetShadowColor(0, 0, 0, 0.8)

            -- Add update function (minimal, real logic is in systems/text.lua)
            textSet.name.UpdateValue = function(self, unitToken)
                local name = UnitName(unitToken) or ""
                self:SetText(name)

                -- Apply intelligent coloring (class for players, reaction for NPCs)
                if config.name.colorByClass then
                    local color = ns.GetUnitColor and ns.GetUnitColor(unitToken)
                    if color then
                        self:SetTextColor(unpack(color))
                    end
                end
            end

            -- Set initial visibility based on show flag (backup logic)
            if not config.name.show then
                textSet.name:Hide()
            end
        end
    end

    return textSet
end


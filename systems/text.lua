-- systems/text.lua - Text System Logic (API Pure)
local _, ns = ...

-- Systems namespace
ns.Systems = ns.Systems or {}
ns.Systems.Text = {}

-- ===========================
-- TEXT SYSTEM CORE
-- ===========================

-- Create text system for managing multiple text elements
function ns.Systems.Text.Create(textElements, unitToken, config)
    local textSystem = {}

    -- Store references
    textSystem.elements = textElements or {}
    textSystem.unit = unitToken
    textSystem.config = config or {}

    -- ===========================
    -- UPDATE METHODS
    -- ===========================

    -- Update name text
    function textSystem:UpdateName()
        local nameElement = self.elements.name
        if not nameElement or not nameElement.UpdateValue then
            return
        end

        if UnitExists(self.unit) then
            nameElement:UpdateValue(self.unit)
        else
            nameElement:SetText("")
        end
    end

    -- Update level text
    function textSystem:UpdateLevel()
        local levelElement = self.elements.level
        if not levelElement or not levelElement.UpdateValue then
            return
        end

        if UnitExists(self.unit) then
            levelElement:UpdateValue(self.unit)
        else
            levelElement:SetText("")
        end
    end

    -- Update health text (handled by health system attachment)
    function textSystem:UpdateHealth(current, max)
        local healthElement = self.elements.health
        if healthElement and healthElement.UpdateValue then
            healthElement:UpdateValue(current, max)
        end
    end

    -- Update power text (handled by power system attachment)
    function textSystem:UpdatePower(current, max, powerType)
        local powerElement = self.elements.power
        if powerElement and powerElement.UpdateValue then
            powerElement:UpdateValue(current, max, powerType)
        end
    end

    -- Update all text elements
    function textSystem:UpdateAll()
        -- Use intelligent placement for name and level
        if self.elements.name or self.elements.level then
            self:UpdateNameLevelIntelligent()
        else
            -- Fallback to individual updates
            self:UpdateName()
            self:UpdateLevel()
        end
        -- Note: Health and power are updated by their respective systems
    end

    -- Update all text configurations (font, size, position, etc.) for runtime changes
    function textSystem:UpdateAllTexts()
        -- Update configurations for all text elements
        for elementType, element in pairs(self.elements) do
            if element and self.config[elementType] then
                local config = self.config[elementType]

                -- Update font properties if element has SetFont
                if element.SetFont and config.font and config.size and config.outline then
                    element:SetFont(config.font, config.size, config.outline)
                end

                -- Update position if element has positioning config
                if element.ClearAllPoints and element.SetPoint then
                    if config.x and config.y then
                        element:ClearAllPoints()
                        local point = "CENTER"  -- HARDCODED
                        local relativePoint = "CENTER"  -- HARDCODED
                        local parent = element:GetParent()
                        if parent then
                            element:SetPoint(point, parent, relativePoint, config.x, config.y)
                        end
                    end
                end

                -- Update visibility
                if config.enabled and element.Show then
                    element:Show()
                elseif not config.enabled and element.Hide then
                    element:Hide()
                end
            end
        end

        -- Update values after configuration changes
        self:UpdateAll()
    end

    -- ===========================
    -- VISIBILITY METHODS
    -- ===========================

    -- Update text visibility based on unit existence
    function textSystem:UpdateVisibility()
        local unitExists = UnitExists(self.unit)

        -- Hide text for optional units that don't exist
        if not unitExists and (self.unit == "target" or self.unit == "focus") then
            self:HideAll()
        elseif unitExists then
            self:ShowEnabled()
        end

        return unitExists
    end

    -- Show all enabled text elements
    function textSystem:ShowEnabled()
        for elementType, element in pairs(self.elements) do
            local elementConfig = self.config[elementType]
            if elementConfig and elementConfig.enabled and element then
                if element.Show then
                    element:Show()
                elseif element.GetParent then
                    local parent = element:GetParent()
                    if parent and parent.Show then
                        parent:Show()
                    end
                end
            end
        end
    end

    -- Hide all text elements
    function textSystem:HideAll()
        for _, element in pairs(self.elements) do
            if element then
                if element.Hide then
                    element:Hide()
                elseif element.GetParent then
                    local parent = element:GetParent()
                    if parent and parent.Hide then
                        parent:Hide()
                    end
                end
            end
        end
    end

    -- ===========================
    -- CONFIGURATION METHODS
    -- ===========================

    -- Set text element visibility
    function textSystem:SetElementEnabled(elementType, enabled)
        if not self.config[elementType] then
            self.config[elementType] = {}
        end

        self.config[elementType].enabled = enabled

        local element = self.elements[elementType]
        if element then
            if enabled then
                if element.Show then
                    element:Show()
                elseif element.GetParent then
                    local parent = element:GetParent()
                    if parent and parent.Show then
                        parent:Show()
                    end
                end
            else
                if element.Hide then
                    element:Hide()
                elseif element.GetParent then
                    local parent = element:GetParent()
                    if parent and parent.Hide then
                        parent:Hide()
                    end
                end
            end
        end
    end

    -- Update text formatting style
    function textSystem:SetTextStyle(elementType, style)
        if not self.config[elementType] then
            self.config[elementType] = {}
        end

        self.config[elementType].style = style

        -- Force update the specific element
        if elementType == "health" then
            -- Health text will be updated by health system
        elseif elementType == "power" then
            -- Power text will be updated by power system
        elseif elementType == "name" then
            self:UpdateName()
        elseif elementType == "level" then
            self:UpdateLevel()
        end
    end

    -- Set text color
    function textSystem:SetTextColor(elementType, r, g, b, a)
        local element = self.elements[elementType]
        if element and element.SetTextColor then
            element:SetTextColor(r, g, b, a or 1)

            -- Update config
            if not self.config[elementType] then
                self.config[elementType] = {}
            end
            self.config[elementType].color = {r, g, b, a or 1}
        end
    end

    -- Set text font
    function textSystem:SetTextFont(elementType, font, size, outline)
        local element = self.elements[elementType]
        if element and element.SetFont then
            element:SetFont(font, size or 12, outline or "OUTLINE")

            -- Update config
            if not self.config[elementType] then
                self.config[elementType] = {}
            end
            self.config[elementType].font = font
            self.config[elementType].size = size
            self.config[elementType].outline = outline
        end
    end

    -- ===========================
    -- ELEMENT MANAGEMENT
    -- ===========================

    -- Add text element to system
    function textSystem:AddElement(elementType, textElement)
        self.elements[elementType] = textElement

        -- Apply configuration if available
        local elementConfig = self.config[elementType]
        if elementConfig then
            if elementConfig.enabled == false then
                if textElement.Hide then
                    textElement:Hide()
                end
            end
        end
    end

    -- Remove text element from system
    function textSystem:RemoveElement(elementType)
        local element = self.elements[elementType]
        if element then
            if element.Hide then
                element:Hide()
            end
            self.elements[elementType] = nil
        end
    end

    -- Get text element
    function textSystem:GetElement(elementType)
        return self.elements[elementType]
    end

    -- ===========================
    -- INTELLIGENT TEXT PLACEMENT & TRUNCATION
    -- ===========================

    -- Intelligent text truncation function with binary search (from backup)
    local function TruncateText(text, maxWidth, fontString)
        if not text or not fontString then return "" end

        fontString:SetText(text)
        local currentWidth = fontString:GetStringWidth()

        if currentWidth <= maxWidth then
            return text
        end

        -- Need to truncate with "..."
        local suffix = "..."

        -- Binary search for optimal length
        local left, right = 1, #text
        local bestLength = 1

        while left <= right do
            local mid = math.floor((left + right) / 2)
            local testText = string.sub(text, 1, mid) .. suffix

            fontString:SetText(testText)
            local testWidth = fontString:GetStringWidth()

            if testWidth <= maxWidth then
                bestLength = mid
                left = mid + 1
            else
                right = mid - 1
            end
        end

        return string.sub(text, 1, bestLength) .. suffix
    end

    -- Get unit level with proper formatting (from backup)
    local function GetUnitLevel(unit)
        local level = UnitLevel(unit)
        if level > 0 then
            return tostring(level)
        else
            return "??" -- For skull level enemies
        end
    end

    -- Get unit name
    local function GetUnitName(unit)
        return UnitName(unit) or "Unknown"
    end

    -- Get unit color based on class (players) or reaction (NPCs) - from backup
    local function GetUnitColor(unit)
        if UnitIsPlayer(unit) then
            local _, class = UnitClass(unit)
            if class then
                local color = RAID_CLASS_COLORS[class]
                if color then
                    return {color.r, color.g, color.b, 1}
                end
            end
        else
            local reaction = UnitReaction(unit, "player")
            if reaction then
                local color = FACTION_BAR_COLORS[reaction]
                if color then
                    return {color.r, color.g, color.b, 1}
                end
            end
        end
        return {1, 1, 1, 1} -- White fallback
    end

    -- UNIFIED POSITIONING: Handle ALL name/level positioning and updates
    function textSystem:UpdateNameLevelIntelligent()
        if not self.elements.name and not self.elements.level then
            return
        end

        local unit = self.unit
        if not UnitExists(unit) then
            -- Hide elements when unit doesn't exist
            if self.nameLevelContainer then
                self.nameLevelContainer:Hide()
            end
            if self.elements.name then
                self.elements.name:SetText("")
            end
            if self.elements.level then
                self.elements.level:SetText("")
            end
            return
        end

        -- Get configurations first
        local levelElement = self.elements.level
        local nameElement = self.elements.name
        local levelConfig = self.config.level or {}
        local nameConfig = self.config.name or {}

        -- Show/hide container based on nameLevel system and visibility
        if self.nameLevelContainer then
            local nameLevelConfig = self.config.nameLevel or {}
            local systemEnabled = nameLevelConfig.enabled
            local nameVisible = nameConfig.enabled and nameConfig.show
            local levelVisible = levelConfig.enabled and levelConfig.show

            if systemEnabled and (nameVisible or levelVisible) then
                self.nameLevelContainer:Show()
            else
                self.nameLevelContainer:Hide()
                return -- No need to position if hidden
            end
        end

        -- STEP 1: Position and update level (always at left edge)
        local calculatedLevelWidth = 0
        if levelElement and levelConfig.enabled and levelConfig.show then
            local levelStr = GetUnitLevel(unit)
            levelElement:SetText(levelStr)

            -- POSITION LEVEL AT LEFT EDGE
            levelElement:ClearAllPoints()
            levelElement:SetPoint("LEFT", self.nameLevelContainer, "LEFT", 0, 0)

            calculatedLevelWidth = levelElement:GetStringWidth() or 0
            levelElement:Show()
        elseif levelElement then
            levelElement:Hide()
            calculatedLevelWidth = 0
        end

        -- STEP 2: Position and update name (after level + spacing)
        if nameElement and nameConfig.enabled and nameConfig.show then
            local unitName = GetUnitName(unit)

            if self.nameLevelContainer then
                -- Calculate available space for name (container width - level width - spacing)
                local containerWidth = self.nameLevelContainer:GetWidth()
                local spacing = calculatedLevelWidth > 0 and 5 or 0 -- Only spacing if level exists
                local availableWidth = containerWidth - calculatedLevelWidth - spacing

                -- POSITION NAME AFTER LEVEL + SPACING
                nameElement:ClearAllPoints()
                nameElement:SetPoint("LEFT", self.nameLevelContainer, "LEFT", calculatedLevelWidth + spacing, 0)

                -- Intelligent truncation
                if availableWidth > 20 then -- Minimum 20px for name to be visible
                    local displayName = TruncateText(unitName, availableWidth, nameElement)
                    nameElement:SetText(displayName)
                else
                    nameElement:SetText("") -- Hide if no space
                end

                -- Apply intelligent coloring
                if nameConfig.colorByClass then
                    local color = GetUnitColor(unit)
                    if color then
                        nameElement:SetTextColor(unpack(color))
                    end
                end

                nameElement:Show()
            end
        elseif nameElement then
            nameElement:Hide()
        end
    end

    -- Create intelligent name & level container system (based on backup)
    function textSystem:CreateNameLevelContainer(parentFrame, healthBar)
        if not parentFrame or not healthBar then
            return nil
        end

        -- Create container frame above health bar
        local containerFrame = CreateFrame("Frame", nil, parentFrame)
        containerFrame:SetSize(healthBar:GetWidth(), 20) -- Same width as health bar

        -- Use unified nameLevel containerOffset system
        local nameLevel = self.config.nameLevel or {}
        local containerOffset = nameLevel.containerOffset or {x = 0, y = 5}
        containerFrame:SetPoint("BOTTOMLEFT", healthBar, "TOPLEFT",
            containerOffset.x or 0, containerOffset.y or 5)
        containerFrame:SetFrameLevel(healthBar:GetFrameLevel() + 15)

        self.nameLevelContainer = containerFrame
        return containerFrame
    end

    -- Store health bar reference for container positioning
    function textSystem:SetHealthBarReference(healthBar)
        self.healthBar = healthBar
    end

    -- Update container position (for real-time updates)
    function textSystem:UpdateContainerPosition()
        if not self.nameLevelContainer or not self.healthBar then
            return
        end

        local nameLevel = self.config.nameLevel or {}
        local containerOffset = nameLevel.containerOffset or {x = 0, y = 5}

        self.nameLevelContainer:ClearAllPoints()
        self.nameLevelContainer:SetPoint("BOTTOMLEFT", self.healthBar, "TOPLEFT",
            containerOffset.x or 0, containerOffset.y or 5)
    end

    -- ===========================
    -- SPECIAL FORMATTING
    -- ===========================

    -- Apply intelligent coloring to name text (class for players, reaction for NPCs)
    function textSystem:ApplyClassColoring()
        local nameElement = self.elements.name
        if not nameElement or not UnitExists(self.unit) then
            return
        end

        local color = GetUnitColor(self.unit)
        if color and nameElement.SetTextColor then
            nameElement:SetTextColor(unpack(color))
        end
    end

    -- Apply level-based coloring to level text
    function textSystem:ApplyLevelColoring()
        local levelElement = self.elements.level
        if not levelElement or not UnitExists(self.unit) then
            return
        end

        local unitLevel = UnitLevel(self.unit)
        local playerLevel = UnitLevel("player")

        if unitLevel > 0 and playerLevel > 0 and levelElement.SetTextColor then
            local levelDiff = unitLevel - playerLevel

            if levelDiff >= 5 then
                -- Red for high level
                levelElement:SetTextColor(1.0, 0.1, 0.1, 1)
            elseif levelDiff >= 3 then
                -- Orange for slightly high level
                levelElement:SetTextColor(1.0, 0.5, 0.0, 1)
            elseif levelDiff <= -5 then
                -- Gray for low level
                levelElement:SetTextColor(0.5, 0.5, 0.5, 1)
            else
                -- White/yellow for appropriate level
                levelElement:SetTextColor(1.0, 1.0, 0.0, 1)
            end
        end
    end

    -- ===========================
    -- EVENT HANDLING
    -- ===========================

    -- Register for text update events
    function textSystem:RegisterEvents()
        local frame = CreateFrame("Frame")

        -- Name and level change events
        frame:RegisterEvent("PLAYER_TARGET_CHANGED")
        frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
        frame:RegisterEvent("UNIT_PET")
        frame:RegisterEvent("UNIT_NAME_UPDATE")
        frame:RegisterEvent("UNIT_LEVEL")

        frame:SetScript("OnEvent", function(_, event, eventUnit)
            if event == "PLAYER_TARGET_CHANGED" and self.unit == "target" then
                C_Timer.After(0.1, function()
                    self:UpdateVisibility()
                    self:UpdateAll()
                    if self.config.applyClassColoring then
                        self:ApplyClassColoring()
                    end
                    if self.config.applyLevelColoring then
                        self:ApplyLevelColoring()
                    end
                end)
            elseif event == "PLAYER_FOCUS_CHANGED" and self.unit == "focus" then
                C_Timer.After(0.1, function()
                    self:UpdateVisibility()
                    self:UpdateAll()
                    if self.config.applyClassColoring then
                        self:ApplyClassColoring()
                    end
                    if self.config.applyLevelColoring then
                        self:ApplyLevelColoring()
                    end
                end)
            elseif event == "UNIT_PET" and self.unit == "pet" then
                C_Timer.After(0.1, function()
                    self:UpdateVisibility()
                    self:UpdateAll()
                end)
            elseif event == "UNIT_NAME_UPDATE" and eventUnit == self.unit then
                self:UpdateName()
                if self.config.applyClassColoring then
                    self:ApplyClassColoring()
                end
            elseif event == "UNIT_LEVEL" and eventUnit == self.unit then
                self:UpdateLevel()
                if self.config.applyLevelColoring then
                    self:ApplyLevelColoring()
                end
            end
        end)

        self.eventFrame = frame
    end

    -- Unregister events
    function textSystem:UnregisterEvents()
        if self.eventFrame then
            self.eventFrame:UnregisterAllEvents()
            self.eventFrame:SetScript("OnEvent", nil)
            self.eventFrame = nil
        end
    end

    -- ===========================
    -- LIFECYCLE
    -- ===========================

    -- Initialize the text system
    function textSystem:Initialize()
        self:RegisterEvents()
        self:UpdateVisibility()
        self:UpdateAll()

        -- Apply initial formatting
        if self.config.applyClassColoring then
            self:ApplyClassColoring()
        end
        if self.config.applyLevelColoring then
            self:ApplyLevelColoring()
        end
    end

    -- Destroy the text system
    function textSystem:Destroy()
        self:UnregisterEvents()
        self.elements = {}
    end

    -- Update configuration in real-time
    function textSystem:UpdateConfig(newTextConfig)
        if not newTextConfig then return end

        self.config = newTextConfig

        -- Update all text elements with new configuration (position, font, size, etc.)
        self:UpdateAllTexts()

        -- Update container position if exists
        if self.nameLevelContainer and newTextConfig.nameLevel then
            self:UpdateContainerPosition()
        end

        -- Force update all values with new configuration
        self:UpdateAll()

        -- CRITICAL: Update style configuration for health/power text elements
        if self.elements.health and newTextConfig.health and newTextConfig.health.style then
            if self.elements.health.config then
                self.elements.health.config.style = newTextConfig.health.style
            end
        end
        if self.elements.power and newTextConfig.power and newTextConfig.power.style then
            if self.elements.power.config then
                self.elements.power.config.style = newTextConfig.power.style
            end
        end

        -- FORCE UPDATE: Re-trigger health and power updates with current values to apply new style
        if self.elements.health and self.elements.health.UpdateValue and UnitExists(self.unit) then
            local current = UnitHealth(self.unit)
            local max = UnitHealthMax(self.unit)
            self.elements.health:UpdateValue(current, max)
        end
        if self.elements.power and self.elements.power.UpdateValue and UnitExists(self.unit) then
            local current = UnitPower(self.unit)
            local max = UnitPowerMax(self.unit)
            local powerType = UnitPowerType(self.unit)
            self.elements.power:UpdateValue(current, max, powerType)
        end
    end

    return textSystem
end

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================

-- Quick setup function for simple cases
function ns.Systems.Text.Setup(textElements, unitToken, config)
    local system = ns.Systems.Text.Create(textElements, unitToken, config)
    system:Initialize()
    return system
end

-- Create text system from text set (from UI.Text.CreateTextSet)
function ns.Systems.Text.FromTextSet(textSet, unitToken, config)
    local textElements = {}

    -- Extract text elements from text set
    if textSet.health then
        textElements.health = textSet.health
    end
    if textSet.power then
        textElements.power = textSet.power
    end
    if textSet.name then
        textElements.name = textSet.name
    end
    if textSet.level then
        textElements.level = textSet.level
    end

    local textSystem = ns.Systems.Text.Create(textElements, unitToken, config)

    -- Transfer nameLevelContainer reference if exists
    if textSet.nameLevelContainer then
        textSystem.nameLevelContainer = textSet.nameLevelContainer
    end

    return textSystem
end

-- Get default text system configuration
function ns.Systems.Text.GetDefaultConfig()
    return {
        name = {
            enabled = true,
            applyClassColoring = true
        },
        level = {
            enabled = true,
            applyLevelColoring = true
        },
        health = {
            enabled = true
        },
        power = {
            enabled = true
        },
        applyClassColoring = true,
        applyLevelColoring = true
    }
end

-- ===========================
-- GLOBAL UTILITY FUNCTIONS
-- ===========================

-- Export GetUnitColor function for use by other modules (from backup)
function ns.GetUnitColor(unit)
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        if class then
            local color = RAID_CLASS_COLORS[class]
            if color then
                return {color.r, color.g, color.b, 1}
            end
        end
    else
        local reaction = UnitReaction(unit, "player")
        if reaction then
            local color = FACTION_BAR_COLORS[reaction]
            if color then
                return {color.r, color.g, color.b, 1}
            end
        end
    end
    return {1, 1, 1, 1} -- White fallback
end
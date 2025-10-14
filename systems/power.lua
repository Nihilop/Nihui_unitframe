-- systems/power.lua - Power System Logic (utilise API bar générique)
local _, ns = ...

-- Systems namespace
ns.Systems = ns.Systems or {}
ns.Systems.Power = {}

-- ===========================
-- POWER BAR CONFIGURATION (rnxmUI)
-- ===========================

-- Get power bar configuration for unit type from DB
function ns.Systems.Power.GetBarConfig(unitType, customConfig)
    -- Extract base unit type (party1 -> party, target -> target, etc.)
    local baseUnitType = unitType:match("^(%a+)%d*$") or unitType

    -- Get unit config from database
    local unitConfig = ns.DB.GetUnitConfig(baseUnitType:lower())
    if not unitConfig or not unitConfig.power then
        return nil
    end

    local powerConfig = unitConfig.power

    -- Check if power is enabled
    if powerConfig.enabled == false then
        return nil  -- No power bar creation if disabled
    end

    -- Convert DB config to bar API format
    local config = {
        main = {
            width = powerConfig.width or 100,
            height = powerConfig.height or 6,
            texture = powerConfig.texture or "Interface\\TargetingFrame\\UI-StatusBar",
            frameLevel = 2
        },
        background = {
            texture = powerConfig.texture or "Interface\\TargetingFrame\\UI-StatusBar",
            color = {0.1, 0.1, 0.1, 0.8}
        }
    }

    -- Add glass effect if enabled (hardcoded values for consistency)
    if powerConfig.glassEnabled then
        config.glass = {
            enabled = true,
            texture = "Interface\\AddOns\\Nihui_uf\\textures\\HPglassADD.tga",  -- HARDCODED
            alpha = powerConfig.glassAlpha or 0.2,  -- CONFIGURABLE
            blendMode = "ADD"  -- HARDCODED
        }
    end

    -- Add border (always enabled, hardcoded values)
    config.border = {
        enabled = true,
        edgeFile = "Interface\\AddOns\\Nihui_uf\\textures\\MirroredFrameSingleUF.tga",  -- HARDCODED
        edgeSize = 16,  -- HARDCODED
        color = {0.5, 0.5, 0.5, 1},  -- HARDCODED
        insets = {left = -12, top = 12, right = 12, bottom = -12}  -- HARDCODED
    }

    -- Merge custom config if provided (for runtime overrides)
    if customConfig then
        for section, sectionConfig in pairs(customConfig) do
            if type(sectionConfig) == "table" and config[section] then
                -- Deep merge pour les sections
                for key, value in pairs(sectionConfig) do
                    if type(value) == "table" and type(config[section][key]) == "table" then
                        -- Merge les sous-sections (comme main.width)
                        for subKey, subValue in pairs(value) do
                            config[section][key][subKey] = subValue
                        end
                    else
                        config[section][key] = value
                    end
                end
            else
                config[section] = sectionConfig
            end
        end
    end

    return config
end

-- ===========================
-- POWER COLOR FUNCTIONS
-- ===========================

function ns.Systems.Power.GetPowerColor(powerType)
    local colors = {
        [Enum.PowerType.Mana] = {0.00, 0.44, 0.87, 1},        -- Blue
        [Enum.PowerType.Rage] = {0.69, 0.31, 0.31, 1},        -- Red
        [Enum.PowerType.Focus] = {0.71, 0.43, 0.27, 1},       -- Orange
        [Enum.PowerType.Energy] = {0.65, 0.63, 0.35, 1},      -- Yellow
        [Enum.PowerType.ComboPoints] = {0.69, 0.31, 0.31, 1}, -- Red
        [Enum.PowerType.RunicPower] = {0.00, 0.82, 1.00, 1},  -- Cyan
        [Enum.PowerType.SoulShards] = {0.50, 0.32, 0.55, 1},  -- Purple
        [Enum.PowerType.LunarPower] = {0.30, 0.52, 0.90, 1},  -- Blue
        [Enum.PowerType.HolyPower] = {0.95, 0.90, 0.60, 1},   -- Golden
        [Enum.PowerType.Maelstrom] = {0.00, 0.50, 1.00, 1},   -- Electric Blue
        [Enum.PowerType.Chi] = {0.71, 1.00, 0.92, 1},         -- Light Blue
        [Enum.PowerType.Insanity] = {0.40, 0.00, 0.80, 1},    -- Purple
        [Enum.PowerType.ArcaneCharges] = {0.41, 0.8, 0.94, 1}, -- Arcane Blue
        [Enum.PowerType.Fury] = {0.788, 0.259, 0.992, 1},     -- Purple
        [Enum.PowerType.Pain] = {255/255, 156/255, 0, 1},     -- Orange
    }

    return colors[powerType] or {0.5, 0.5, 0.5, 1} -- Gray fallback
end

-- ===========================
-- POWER SYSTEM CREATION
-- ===========================

-- Create complete power system using generic bar API
function ns.Systems.Power.Create(parent, unitToken, config)
    local powerSystem = {}

    -- Store references
    powerSystem.unit = unitToken
    powerSystem.config = config or {}

    -- Initialize default color settings if not provided
    if powerSystem.config.colorByPowerType == nil then
        powerSystem.config.colorByPowerType = true -- Default to true per defaults.lua
    end

    -- ===========================
    -- BUILD POWER BAR WITH API
    -- ===========================

    -- Get bar configuration for unit type
    local barConfig = ns.Systems.Power.GetBarConfig(unitToken, config.barConfig)

    -- If power is disabled, create empty system
    if not barConfig then
        powerSystem.barSet = nil
        powerSystem.bar = nil
        powerSystem.enabled = false
    else
        -- Create complete power bar using generic API
        powerSystem.barSet = ns.UI.Bar.CreateCompleteBar(parent, barConfig)
        powerSystem.bar = powerSystem.barSet.main -- Main bar for compatibility
        powerSystem.enabled = true
    end

    -- ===========================
    -- UPDATE METHODS
    -- ===========================

    -- Update power values and appearance
    function powerSystem:UpdatePower()
        -- Skip if power system is disabled
        if not self.enabled or not self.bar then
            return false
        end

        if not UnitExists(self.unit) then
            ns.UI.Bar.SetValue(self.bar, 0)
            self.bar:Hide()
            return false
        end

        -- Get power values
        local current = UnitPower(self.unit)
        local max = UnitPowerMax(self.unit)
        local powerType = UnitPowerType(self.unit)

        -- Handle hide when empty option
        if self.config.hideWhenEmpty and max == 0 then
            self.bar:Hide()
            return true
        else
            self.bar:Show()
        end

        -- Update bar values using API
        ns.UI.Bar.SetValue(self.bar, current, max)

        -- Update color by power type
        if self.config.colorByPowerType ~= false then -- Default to true
            local color = ns.Systems.Power.GetPowerColor(powerType)
            ns.UI.Bar.SetColor(self.bar, color[1], color[2], color[3], color[4])
        elseif self.config.customColor then
            local color = self.config.customColor
            ns.UI.Bar.SetColor(self.bar, color[1], color[2], color[3], color[4] or 1)
        else
            -- Fallback color when colorByPowerType is disabled (default WoW mana blue)
            ns.UI.Bar.SetColor(self.bar, 0, 0, 1, 1) -- Blue
        end

        -- Update text if attached
        if self.textElement then
            self.textElement:UpdateValue(current, max, powerType)
        end

        return true
    end

    -- Update visibility based on unit existence
    function powerSystem:UpdateVisibility()
        if not self.bar then
            return false
        end

        local unitExists = UnitExists(self.unit)

        if not unitExists then
            self.bar:Hide()
        else
            -- Visibility depends on power amount if hideWhenEmpty is enabled
            self:UpdatePower() -- This will handle hide/show based on config
        end

        return unitExists
    end

    -- Attach text element
    function powerSystem:AttachText(textElement)
        self.textElement = textElement
    end

    -- Set color scheme
    function powerSystem:SetColorScheme(colorByPowerType, customColor)
        self.config.colorByPowerType = colorByPowerType
        self.config.customColor = customColor

        -- Update color immediately
        self:UpdatePower()
    end

    -- Set hide when empty option
    function powerSystem:SetHideWhenEmpty(hideWhenEmpty)
        self.config.hideWhenEmpty = hideWhenEmpty
        self:UpdatePower()
    end

    -- ===========================
    -- EVENT HANDLING
    -- ===========================

    -- Register for power events
    function powerSystem:RegisterEvents()
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("UNIT_POWER_UPDATE")
        frame:RegisterEvent("UNIT_MAXPOWER")
        frame:RegisterEvent("UNIT_DISPLAYPOWER")
        frame:RegisterEvent("PLAYER_TARGET_CHANGED")
        frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
        frame:RegisterEvent("UNIT_PET")

        frame:SetScript("OnEvent", function(_, event, eventUnit, powerToken)
            if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
                if eventUnit == self.unit then
                    self:UpdatePower()
                end
            elseif event == "PLAYER_TARGET_CHANGED" and self.unit == "target" then
                self:UpdateVisibility()
            elseif event == "PLAYER_FOCUS_CHANGED" and self.unit == "focus" then
                self:UpdateVisibility()
            elseif event == "UNIT_PET" and self.unit == "pet" then
                C_Timer.After(0.1, function()
                    self:UpdateVisibility()
                end)
            elseif event == "PLAYER_TARGET_CHANGED" and self.unit == "targettarget" then
                C_Timer.After(0.1, function()
                    self:UpdateVisibility()
                    self:UpdatePower()
                end)
            end
        end)

        self.eventFrame = frame
    end

    -- Unregister events
    function powerSystem:UnregisterEvents()
        if self.eventFrame then
            self.eventFrame:UnregisterAllEvents()
            self.eventFrame:SetScript("OnEvent", nil)
            self.eventFrame = nil
        end
    end

    -- ===========================
    -- LIFECYCLE
    -- ===========================

    -- Initialize the system
    function powerSystem:Initialize()
        self:RegisterEvents()
        self:UpdateVisibility()
    end

    -- Destroy the system
    function powerSystem:Destroy()
        self:UnregisterEvents()
        self.textElement = nil
    end

    -- Set anchor frame reference for positioning updates
    function powerSystem:SetAnchorFrame(anchorFrame)
        self.anchorFrame = anchorFrame
    end

    -- Update configuration in real-time
    function powerSystem:UpdateConfig(newPowerConfig)
        if not newPowerConfig or type(newPowerConfig) ~= "table" then
            return
        end

        -- Handle enable/disable toggle
        if self.bar then
            if newPowerConfig.enabled == false then
                self.bar:Hide()
                if self.textElement then
                    self.textElement:Hide()
                end
                return
            else
                self.bar:Show()
                if self.textElement then
                    self.textElement:Show()
                end
            end
        end

        -- Update bar size
        if self.bar and newPowerConfig.width and newPowerConfig.height then
            self.bar:SetSize(newPowerConfig.width, newPowerConfig.height)
        end

        -- Update bar texture
        if self.bar and newPowerConfig.texture then
            self.bar:SetStatusBarTexture(newPowerConfig.texture)
        end

        -- Update bar position/offsets
        if self.bar and self.anchorFrame and (newPowerConfig.xOffset or newPowerConfig.yOffset) then
            self.bar:ClearAllPoints()
            local xOffset = newPowerConfig.xOffset or 0
            local yOffset = newPowerConfig.yOffset or -10
            self.bar:SetPoint("TOP", self.anchorFrame, "BOTTOM", xOffset, yOffset)
        end

        -- Update glass effect if bar supports it
        if self.bar and self.barSet and self.barSet.glass then
            local glassTexture = self.barSet.glass
            if newPowerConfig.glassEnabled then
                -- Hardcoded glass texture (HPglass from LSM registration)
                glassTexture:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\HPglass.tga")
                if newPowerConfig.glassAlpha then
                    glassTexture:SetAlpha(newPowerConfig.glassAlpha)
                end
                if newPowerConfig.glassBlendMode then
                    glassTexture:SetBlendMode(newPowerConfig.glassBlendMode)
                end
                glassTexture:Show()
            else
                glassTexture:Hide()
            end
        end

        -- Update hide when empty
        if newPowerConfig.hideWhenEmpty ~= nil then
            self.config.hideWhenEmpty = newPowerConfig.hideWhenEmpty
        end

        -- Update color by power type
        if newPowerConfig.colorByPowerType ~= nil then
            self.config.colorByPowerType = newPowerConfig.colorByPowerType
        end

        -- Force immediate update
        self:UpdatePower()
    end

    return powerSystem
end

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================

-- Quick setup function for simple cases
function ns.Systems.Power.Setup(parent, unitToken, config)
    local system = ns.Systems.Power.Create(parent, unitToken, config)
    system:Initialize()
    return system
end


-- cores/builder.lua - Unit Frame Construction API
local _, ns = ...

-- Core namespace
ns.Core = ns.Core or {}
ns.Core.Builder = {}

-- ===========================
-- BUILDER CONFIGURATION
-- ===========================

-- Default configurations for different unit types
local DEFAULT_CONFIGS = {
    PLAYER = {
        health = {
            width = 100,
            height = 20,
            texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
            colorByClass = true
        },
        power = {
            width = 100,
            height = 8,
            texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
            yOffset = -2,
            colorByPowerType = true,
            hideWhenEmpty = false
        },
        text = {
            health = {
                enabled = true,
                style = "k_version",
                font = "Fonts\\FRIZQT__.TTF",
                size = 12,
                outline = "OUTLINE",
                color = {1, 1, 1, 1},
                point = "CENTER",
                x = 0,
                y = 0
            },
            power = {
                enabled = true,
                style = "k_version",
                font = "Fonts\\FRIZQT__.TTF",
                size = 10,
                outline = "OUTLINE",
                color = {1, 1, 1, 1},
                point = "CENTER",
                x = 0,
                y = 0,
                colorByPowerType = false
            },
            name = {
                enabled = true,
                font = "Fonts\\FRIZQT__.TTF",
                size = 12,
                outline = "OUTLINE",
                color = {1, 1, 1, 1},
                point = "BOTTOM",
                relativePoint = "TOP",
                x = 0,
                y = 2,
                colorByClass = true
            },
            level = {
                enabled = false,
                font = "Fonts\\FRIZQT__.TTF",
                size = 10,
                outline = "OUTLINE",
                color = {1, 1, 1, 1},
                point = "TOPRIGHT",
                x = -2,
                y = -2
            }
        }
    },
    TARGET = {
        health = {
            width = 100,
            height = 20,
            texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
            colorByClass = true
        },
        power = {
            width = 100,
            height = 8,
            texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
            yOffset = -2,
            colorByPowerType = true,
            hideWhenEmpty = true
        },
        text = {
            health = {
                enabled = true,
                style = "k_version",
                font = "Fonts\\FRIZQT__.TTF",
                size = 12,
                outline = "OUTLINE",
                color = {1, 1, 1, 1},
                point = "CENTER",
                x = 0,
                y = 0
            },
            power = {
                enabled = true,
                style = "k_version",
                font = "Fonts\\FRIZQT__.TTF",
                size = 10,
                outline = "OUTLINE",
                color = {1, 1, 1, 1},
                point = "CENTER",
                x = 0,
                y = 0,
                colorByPowerType = false
            },
            name = {
                enabled = true,
                font = "Fonts\\FRIZQT__.TTF",
                size = 12,
                outline = "OUTLINE",
                color = {1, 1, 1, 1},
                point = "BOTTOM",
                relativePoint = "TOP",
                x = 0,
                y = 2,
                colorByClass = true
            },
            level = {
                enabled = true,
                font = "Fonts\\FRIZQT__.TTF",
                size = 10,
                outline = "OUTLINE",
                color = {1, 1, 1, 1},
                point = "TOPRIGHT",
                x = -2,
                y = -2
            }
        }
    },
    FOCUS = {
        health = {
            width = 80,
            height = 16,
            texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
            colorByClass = true
        },
        power = {
            width = 80,
            height = 6,
            texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
            yOffset = -2,
            colorByPowerType = true,
            hideWhenEmpty = true
        },
        text = {
            health = {
                enabled = true,
                style = "k_version",
                font = "Fonts\\FRIZQT__.TTF",
                size = 10,
                outline = "OUTLINE",
                color = {1, 1, 1, 1},
                point = "CENTER",
                x = 0,
                y = 0
            },
            power = {
                enabled = false,
                style = "k_version",
                font = "Fonts\\FRIZQT__.TTF",
                size = 8,
                outline = "OUTLINE",
                color = {1, 1, 1, 1},
                point = "CENTER",
                x = 0,
                y = 0
            },
            name = {
                enabled = true,
                font = "Fonts\\FRIZQT__.TTF",
                size = 10,
                outline = "OUTLINE",
                color = {1, 1, 1, 1},
                point = "BOTTOM",
                relativePoint = "TOP",
                x = 0,
                y = 2,
                colorByClass = true
            },
            level = {
                enabled = false
            }
        }
    }
}

-- ===========================
-- CONFIGURATION UTILITIES
-- ===========================

-- Deep merge two tables
local function DeepMerge(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" and type(target[key]) == "table" then
            DeepMerge(target[key], value)
        else
            target[key] = value
        end
    end
    return target
end

-- Get configuration for unit type
local function GetUnitConfig(unitType, customConfig)
    local defaultConfig = DEFAULT_CONFIGS[unitType:upper()]
    if not defaultConfig then
        error("No default configuration for unit type: " .. unitType)
    end

    -- Create a deep copy of the default config
    local config = {}
    DeepMerge(config, defaultConfig)

    -- Apply custom configuration if provided
    if customConfig then
        DeepMerge(config, customConfig)
    end

    return config
end

-- ===========================
-- FRAME CONSTRUCTION
-- ===========================

-- Build a complete unit frame
function ns.Core.Builder.BuildUnitFrame(parentFrame, unitToken, unitType, customConfig)
    local config = GetUnitConfig(unitType, customConfig)
    local unitFrame = {}

    -- ===========================
    -- CREATE UI COMPONENTS
    -- ===========================

    -- Create bar set (health + power)
    local barSet = ns.UI.Bar.CreateBarSet(parentFrame, config.health, config.power)
    unitFrame.bars = barSet

    -- Create text elements
    local textSet = ns.UI.Text.CreateTextSet(parentFrame, barSet.health, barSet.power, config.text)
    unitFrame.texts = textSet

    -- ===========================
    -- CREATE SYSTEMS
    -- ===========================

    -- Create health system
    local healthSystem = ns.Systems.Health.Create(barSet.health, unitToken, config.health)
    unitFrame.healthSystem = healthSystem

    -- Create power system
    local powerSystem = ns.Systems.Power.Create(barSet.power, unitToken, config.power)
    unitFrame.powerSystem = powerSystem

    -- ===========================
    -- ATTACH TEXT TO SYSTEMS
    -- ===========================

    -- Attach health text to health system
    if textSet.health then
        healthSystem:AttachText(textSet.health)
    end

    -- Attach power text to power system
    if textSet.power then
        powerSystem:AttachText(textSet.power)
    end

    -- ===========================
    -- INITIALIZE SYSTEMS
    -- ===========================

    healthSystem:Initialize()
    powerSystem:Initialize()

    -- ===========================
    -- SETUP TEXT UPDATES
    -- ===========================

    -- Setup name text updates
    if textSet.name then
        local function UpdateNameText()
            if UnitExists(unitToken) then
                textSet.name:UpdateValue(unitToken)
            end
        end

        -- Initial update
        UpdateNameText()

        -- Register for updates
        local nameFrame = CreateFrame("Frame")
        if unitToken == "target" then
            nameFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        elseif unitToken == "focus" then
            nameFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
        elseif unitToken == "pet" then
            nameFrame:RegisterEvent("UNIT_PET")
        end

        nameFrame:SetScript("OnEvent", function()
            C_Timer.After(0.1, UpdateNameText)
        end)

        unitFrame.nameUpdateFrame = nameFrame
    end

    -- Setup level text updates
    if textSet.level then
        local function UpdateLevelText()
            if UnitExists(unitToken) then
                textSet.level:UpdateValue(unitToken)
            end
        end

        -- Initial update
        UpdateLevelText()

        -- Register for updates (same events as name)
        if unitFrame.nameUpdateFrame then
            unitFrame.nameUpdateFrame:HookScript("OnEvent", function()
                C_Timer.After(0.1, UpdateLevelText)
            end)
        end
    end

    -- ===========================
    -- FRAME LIFECYCLE
    -- ===========================

    -- Destroy function
    function unitFrame:Destroy()
        if self.healthSystem then
            self.healthSystem:Destroy()
        end
        if self.powerSystem then
            self.powerSystem:Destroy()
        end
        if self.nameUpdateFrame then
            self.nameUpdateFrame:UnregisterAllEvents()
            self.nameUpdateFrame:SetScript("OnEvent", nil)
        end

        -- Clear references
        self.bars = nil
        self.texts = nil
        self.healthSystem = nil
        self.powerSystem = nil
        self.nameUpdateFrame = nil
    end

    -- Store configuration and metadata
    unitFrame.config = config
    unitFrame.unitToken = unitToken
    unitFrame.unitType = unitType
    unitFrame.parentFrame = parentFrame

    return unitFrame
end

-- ===========================
-- SPECIALIZED BUILDERS
-- ===========================

-- Build player frame
function ns.Core.Builder.BuildPlayerFrame(parentFrame, customConfig)
    return ns.Core.Builder.BuildUnitFrame(parentFrame, "player", "PLAYER", customConfig)
end

-- Build target frame
function ns.Core.Builder.BuildTargetFrame(parentFrame, customConfig)
    return ns.Core.Builder.BuildUnitFrame(parentFrame, "target", "TARGET", customConfig)
end

-- Build focus frame
function ns.Core.Builder.BuildFocusFrame(parentFrame, customConfig)
    return ns.Core.Builder.BuildUnitFrame(parentFrame, "focus", "FOCUS", customConfig)
end

-- Build pet frame
function ns.Core.Builder.BuildPetFrame(parentFrame, customConfig)
    return ns.Core.Builder.BuildUnitFrame(parentFrame, "pet", "PET", customConfig)
end

-- ===========================
-- BATCH OPERATIONS
-- ===========================

-- Build multiple unit frames
function ns.Core.Builder.BuildFrameSet(frameConfigs)
    local frameSet = {}

    for unitType, frameConfig in pairs(frameConfigs) do
        local parentFrame = frameConfig.parentFrame
        local customConfig = frameConfig.config

        if parentFrame then
            local unitToken = unitType:lower()
            frameSet[unitToken] = ns.Core.Builder.BuildUnitFrame(parentFrame, unitToken, unitType, customConfig)
        end
    end

    -- Destroy all function
    function frameSet:DestroyAll()
        for _, frame in pairs(self) do
            if frame and frame.Destroy then
                frame:Destroy()
            end
        end
    end

    return frameSet
end

-- ===========================
-- CONFIGURATION MANAGEMENT
-- ===========================

-- Get default configuration for unit type
function ns.Core.Builder.GetDefaultConfig(unitType)
    local defaultConfig = DEFAULT_CONFIGS[unitType:upper()]
    if not defaultConfig then
        return nil
    end

    -- Return a deep copy
    local config = {}
    DeepMerge(config, defaultConfig)
    return config
end

-- Update default configuration
function ns.Core.Builder.SetDefaultConfig(unitType, config)
    unitType = unitType:upper()
    if not DEFAULT_CONFIGS[unitType] then
        DEFAULT_CONFIGS[unitType] = {}
    end

    DeepMerge(DEFAULT_CONFIGS[unitType], config)
end

-- Validate configuration
function ns.Core.Builder.ValidateConfig(config)
    if type(config) ~= "table" then
        return false, "Configuration must be a table"
    end

    -- Validate health config
    if config.health then
        if type(config.health) ~= "table" then
            return false, "health config must be a table"
        end
        if config.health.width and type(config.health.width) ~= "number" then
            return false, "health.width must be a number"
        end
        if config.health.height and type(config.health.height) ~= "number" then
            return false, "health.height must be a number"
        end
    end

    -- Validate power config
    if config.power then
        if type(config.power) ~= "table" then
            return false, "power config must be a table"
        end
        if config.power.width and type(config.power.width) ~= "number" then
            return false, "power.width must be a number"
        end
        if config.power.height and type(config.power.height) ~= "number" then
            return false, "power.height must be a number"
        end
    end

    -- Validate text config
    if config.text then
        if type(config.text) ~= "table" then
            return false, "text config must be a table"
        end

        for textType, textConfig in pairs(config.text) do
            if type(textConfig) ~= "table" then
                return false, textType .. " text config must be a table"
            end
            if textConfig.size and type(textConfig.size) ~= "number" then
                return false, textType .. ".size must be a number"
            end
        end
    end

    return true
end
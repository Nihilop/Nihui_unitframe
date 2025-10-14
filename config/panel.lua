-- config/panel.lua - Ace3 Configuration with Modern Sidebar
local _, ns = ...

-- Panel namespace
ns.Config = ns.Config or {}
ns.Config.Panel = {}

-- Ace3 libraries
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- ===========================
-- HELPER FUNCTIONS
-- ===========================

-- Helper to set value and refresh only affected unit
local function SetValueAndRefresh(unit, ...)
    local args = {...}
    local value = args[#args] -- Last argument is the value
    local settingPath = {}
    for i = 1, #args - 1 do
        settingPath[i] = args[i]
    end


    -- Set the value in database
    -- Build complete argument list for SetUnitSetting
    local dbArgs = {unit}
    for i = 1, #settingPath do
        dbArgs[#dbArgs + 1] = settingPath[i]
    end
    dbArgs[#dbArgs + 1] = value

    local success = ns.DB.SetUnitSetting(unpack(dbArgs))

    -- Real-time refresh using API system
    if ns.API and ns.API.UnitFrame and ns.API.UnitFrame.RefreshUnit then
        ns.API.UnitFrame.RefreshUnit(unit)
    end
end

-- ===========================
-- UNITFRAME CONFIG BUILDER
-- ===========================

-- Create a standardized unitframe configuration matching defaults.lua exactly
local function CreateUnitFrameConfig(unitType, displayName, order, specialConfigs)
    specialConfigs = specialConfigs or {}

    local unitLabel = unitType
    if unitType == "targettarget" then unitLabel = "target of target"
    elseif unitType == "focustarget" then unitLabel = "focus target"
    end

    local config = {
        name = displayName,
        type = "group",
        order = order,
        args = {
            header = {
                name = displayName .. " Unit Frame Configuration",
                type = "header",
                order = 0,
            },
            health = {
                name = "Health Bar",
                type = "group",
                inline = true,
                order = 10,
                args = {
                    -- Based on defaults.lua health section EXACTLY
                    width = {
                        name = "Width",
                        desc = "Health bar width in pixels",
                        type = "range",
                        order = 1,
                        min = 50, max = 400, step = 1,
                        get = function() return ns.DB.GetUnitSetting(unitType, "health", "width") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "health", "width", value)
                        end,
                    },
                    height = {
                        name = "Height",
                        desc = "Health bar height in pixels",
                        type = "range",
                        order = 2,
                        min = 5, max = 60, step = 1,
                        get = function() return ns.DB.GetUnitSetting(unitType, "health", "height") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "health", "height", value)
                        end,
                    },
                    texture = {
                        name = "Health Texture",
                        desc = "Status bar texture",
                        type = "select",
                        order = 3,
                        dialogControl = "LSM30_Statusbar",
                        values = LibStub and LibStub("LibSharedMedia-3.0", true) and LibStub("LibSharedMedia-3.0"):HashTable("statusbar") or {},
                        get = function()
                            local texturePath = ns.DB.GetUnitSetting(unitType, "health", "texture")
                            if texturePath then
                                local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
                                if LSM then
                                    -- Convert path back to name for dropdown
                                    for name, path in pairs(LSM:HashTable("statusbar")) do
                                        if path == texturePath then
                                            return name
                                        end
                                    end
                                end
                            end
                            return "g1" -- fallback
                        end,
                        set = function(_, value)
                            local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
                            if LSM then
                                local texturePath = LSM:Fetch("statusbar", value)
                                SetValueAndRefresh(unitType, "health", "texture", texturePath)
                            else
                                SetValueAndRefresh(unitType, "health", "texture", value)
                            end
                        end,
                    },
                    colorByClass = {
                        name = "Color by Class",
                        desc = "Use class color for health bar",
                        type = "toggle",
                        order = 4,
                        get = function() return ns.DB.GetUnitSetting(unitType, "health", "colorByClass") ~= false end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "health", "colorByClass", value)
                        end,
                    },
                    glassEnabled = {
                        name = "Enable Glass Effect",
                        desc = "Enable glass overlay effect",
                        type = "toggle",
                        order = 5,
                        get = function() return ns.DB.GetUnitSetting(unitType, "health", "glassEnabled") ~= false end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "health", "glassEnabled", value)
                        end,
                    },
                    glassAlpha = {
                        name = "Glass Opacity",
                        desc = "Glass effect transparency",
                        type = "range",
                        order = 7,
                        min = 0, max = 1, step = 0.05,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "health", "glassEnabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "health", "glassAlpha") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "health", "glassAlpha", value)
                        end,
                    },
                    animatedLossEnabled = {
                        name = "Animated Loss",
                        desc = "Show animated health loss effect",
                        type = "toggle",
                        order = 8,
                        get = function() return ns.DB.GetUnitSetting(unitType, "health", "animatedLossEnabled") ~= false end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "health", "animatedLossEnabled", value)
                        end,
                    },
                    absorbEnabled = {
                        name = "Absorb Shields",
                        desc = "Show absorb shield effects",
                        type = "toggle",
                        order = 9,
                        get = function() return ns.DB.GetUnitSetting(unitType, "health", "absorbEnabled") ~= false end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "health", "absorbEnabled", value)
                        end,
                    },
                    healPredictionEnabled = {
                        name = "Heal Prediction",
                        desc = "Show incoming heal prediction",
                        type = "toggle",
                        order = 10,
                        get = function() return ns.DB.GetUnitSetting(unitType, "health", "healPredictionEnabled") ~= false end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "health", "healPredictionEnabled", value)
                        end,
                    },
                    -- HEALTH TEXT INSIDE HEALTH BAR (from defaults.lua text.health)
                    healthTextHeader = {
                        name = "Health Text",
                        type = "header",
                        order = 20,
                    },
                    healthTextEnabled = {
                        name = "Enable Health Text",
                        desc = "Show/hide health value text",
                        type = "toggle",
                        order = 21,
                        get = function() return ns.DB.GetUnitSetting(unitType, "text", "health", "enabled") ~= false end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "text", "health", "enabled", value)
                        end,
                    },
                    healthTextStyle = {
                        name = "Style",
                        desc = "Text format style",
                        type = "select",
                        order = 22,
                        values = {
                            ["current"] = "Current only",
                            ["current_k"] = "Current (k format)",
                            ["current_percent"] = "Current + %",
                            ["k_version"] = "Current / Max (k format)",
                            ["percent"] = "Percentage only"
                        },
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "text", "health", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "text", "health", "style") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "text", "health", "style", value)
                        end,
                    },
                    healthTextSize = {
                        name = "Font Size",
                        desc = "Health text font size",
                        type = "range",
                        order = 23,
                        min = 8, max = 24, step = 1,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "text", "health", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "text", "health", "size") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "text", "health", "size", value)
                        end,
                    },
                    healthTextX = {
                        name = "X Offset",
                        desc = "Horizontal position offset",
                        type = "range",
                        order = 24,
                        min = -100, max = 100, step = 1,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "text", "health", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "text", "health", "x") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "text", "health", "x", value)
                        end,
                    },
                    healthTextY = {
                        name = "Y Offset",
                        desc = "Vertical position offset",
                        type = "range",
                        order = 25,
                        min = -50, max = 50, step = 1,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "text", "health", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "text", "health", "y") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "text", "health", "y", value)
                        end,
                    },
                }
            },
            power = {
                name = "Power Bar",
                type = "group",
                inline = true,
                order = 20,
                args = {
                    enabled = {
                        name = "Enable Power Bar",
                        desc = "Show/hide power bar",
                        type = "toggle",
                        order = 1,
                        get = function() return ns.DB.GetUnitSetting(unitType, "power", "enabled") ~= false end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "power", "enabled", value)
                        end,
                    },
                    width = {
                        name = "Width",
                        desc = "Power bar width",
                        type = "range",
                        order = 2,
                        min = 20, max = 400, step = 1,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "power", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "power", "width") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "power", "width", value)
                        end,
                    },
                    height = {
                        name = "Height",
                        desc = "Power bar height",
                        type = "range",
                        order = 3,
                        min = 3, max = 50, step = 1,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "power", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "power", "height") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "power", "height", value)
                        end,
                    },
                    texture = {
                        name = "Texture",
                        desc = "Power bar texture",
                        type = "select",
                        order = 4,
                        dialogControl = "LSM30_Statusbar",
                        values = LibStub and LibStub("LibSharedMedia-3.0", true) and LibStub("LibSharedMedia-3.0"):HashTable("statusbar") or {},
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "power", "enabled") end,
                        get = function()
                            local texturePath = ns.DB.GetUnitSetting(unitType, "power", "texture")
                            if texturePath then
                                local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
                                if LSM then
                                    -- Convert path back to name for dropdown
                                    for name, path in pairs(LSM:HashTable("statusbar")) do
                                        if path == texturePath then
                                            return name
                                        end
                                    end
                                end
                            end
                            return "g1" -- fallback
                        end,
                        set = function(_, value)
                            local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
                            if LSM then
                                local texturePath = LSM:Fetch("statusbar", value)
                                SetValueAndRefresh(unitType, "power", "texture", texturePath)
                            else
                                SetValueAndRefresh(unitType, "power", "texture", value)
                            end
                        end,
                    },
                    xOffset = {
                        name = "X Offset",
                        desc = "Horizontal position offset",
                        type = "range",
                        order = 5,
                        min = -100, max = 100, step = 1,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "power", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "power", "xOffset") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "power", "xOffset", value)
                        end,
                    },
                    yOffset = {
                        name = "Y Offset",
                        desc = "Vertical position offset",
                        type = "range",
                        order = 6,
                        min = -50, max = 50, step = 1,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "power", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "power", "yOffset") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "power", "yOffset", value)
                        end,
                    },
                    colorByPowerType = {
                        name = "Color by Power Type",
                        desc = "Use power type-specific colors",
                        type = "toggle",
                        order = 7,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "power", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "power", "colorByPowerType") ~= false end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "power", "colorByPowerType", value)
                        end,
                    },
                    hideWhenEmpty = {
                        name = "Hide When Empty",
                        desc = "Hide power bar when power is 0",
                        type = "toggle",
                        order = 8,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "power", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "power", "hideWhenEmpty") == true end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "power", "hideWhenEmpty", value)
                        end,
                    },
                    glassEnabled = {
                        name = "Enable Glass Effect",
                        desc = "Enable glass overlay effect",
                        type = "toggle",
                        order = 6,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "power", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "power", "glassEnabled") ~= false end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "power", "glassEnabled", value)
                        end,
                    },
                    glassAlpha = {
                        name = "Glass Opacity",
                        desc = "Glass effect transparency",
                        type = "range",
                        order = 10,
                        min = 0, max = 1, step = 0.05,
                        disabled = function()
                            return not ns.DB.GetUnitSetting(unitType, "power", "enabled") or
                                   not ns.DB.GetUnitSetting(unitType, "power", "glassEnabled")
                        end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "power", "glassAlpha") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "power", "glassAlpha", value)
                        end,
                    },
                    powerTextHeader = {
                        name = "Power Text",
                        type = "header",
                        order = 15
                    },
                    powerTextEnabled = {
                        name = "Enable Power Text",
                        desc = "Show/hide power value text",
                        type = "toggle",
                        order = 16,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "power", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "text", "power", "enabled") ~= false end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "text", "power", "enabled", value)
                        end,
                    },
                    powerTextStyle = {
                        name = "Power Text Style",
                        desc = "Text format style",
                        type = "select",
                        order = 17,
                        values = {
                            ["current"] = "Current only",
                            ["current_k"] = "Current (k format)",
                            ["current_percent"] = "Current + %",
                            ["k_version"] = "Current / Max (k format)",
                            ["percent"] = "Percentage only"
                        },
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "power", "enabled") or not ns.DB.GetUnitSetting(unitType, "text", "power", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "text", "power", "style") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "text", "power", "style", value)
                        end,
                    },
                    powerTextSize = {
                        name = "Power Text Size",
                        desc = "Text font size",
                        type = "range",
                        order = 18,
                        min = 6, max = 24, step = 1,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "power", "enabled") or not ns.DB.GetUnitSetting(unitType, "text", "power", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "text", "power", "size") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "text", "power", "size", value)
                        end,
                    },
                    powerTextX = {
                        name = "Power Text X Offset",
                        desc = "Horizontal position offset",
                        type = "range",
                        order = 19,
                        min = -200, max = 200, step = 1,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "power", "enabled") or not ns.DB.GetUnitSetting(unitType, "text", "power", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "text", "power", "x") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "text", "power", "x", value)
                        end,
                    },
                    powerTextY = {
                        name = "Power Text Y Offset",
                        desc = "Vertical position offset",
                        type = "range",
                        order = 20,
                        min = -200, max = 200, step = 1,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "power", "enabled") or not ns.DB.GetUnitSetting(unitType, "text", "power", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "text", "power", "y") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "text", "power", "y", value)
                        end,
                    },
                }
            },
            nameLevel = {
                name = "Name & Level",
                type = "group",
                inline = true,
                order = 25,
                args = {
                    enabled = {
                        name = "Enable Name & Level",
                        desc = "Show/hide name and level text",
                        type = "toggle",
                        order = 1,
                        get = function() return ns.DB.GetUnitSetting(unitType, "text", "nameLevel", "enabled") ~= false end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "text", "nameLevel", "enabled", value)
                        end,
                    },
                    containerOffsetX = {
                        name = "Container X Offset",
                        desc = "Horizontal offset of name/level container",
                        type = "range",
                        order = 2,
                        min = -200, max = 200, step = 1,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "text", "nameLevel", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "text", "nameLevel", "containerOffset", "x") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "text", "nameLevel", "containerOffset", "x", value)
                        end,
                    },
                    containerOffsetY = {
                        name = "Container Y Offset",
                        desc = "Vertical offset of name/level container",
                        type = "range",
                        order = 3,
                        min = -50, max = 50, step = 1,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "text", "nameLevel", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "text", "nameLevel", "containerOffset", "y") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "text", "nameLevel", "containerOffset", "y", value)
                        end,
                    },
                    nameEnabled = {
                        name = "Show Name",
                        desc = "Show " .. unitLabel .. " name",
                        type = "toggle",
                        order = 4,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "text", "nameLevel", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "text", "name", "show") ~= false end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "text", "name", "show", value)
                        end,
                    },
                    levelEnabled = {
                        name = "Show Level",
                        desc = "Show " .. unitLabel .. " level",
                        type = "toggle",
                        order = 5,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "text", "nameLevel", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "text", "level", "show") ~= false end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "text", "level", "show", value)
                        end,
                    },
                    nameColorByClass = {
                        name = "Name Class Color",
                        desc = "Use class color for name",
                        type = "toggle",
                        order = 6,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "text", "nameLevel", "enabled") or not ns.DB.GetUnitSetting(unitType, "text", "name", "show") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "text", "name", "colorByClass") ~= false end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "text", "name", "colorByClass", value)
                        end,
                    },
                    nameTruncate = {
                        name = "Truncate Name",
                        desc = "Enable intelligent name truncation",
                        type = "toggle",
                        order = 7,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "text", "nameLevel", "enabled") or not ns.DB.GetUnitSetting(unitType, "text", "name", "show") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "text", "name", "truncate") ~= false end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "text", "name", "truncate", value)
                        end,
                    },
                }
            },
            portrait = {
                name = "Portrait",
                type = "group",
                inline = true,
                order = 30,
                args = {
                    enabled = {
                        name = "Enable Portrait",
                        desc = "Show/hide the 3D portrait (also hides Blizzard portrait)",
                        type = "toggle",
                        order = 1,
                        get = function() return ns.DB.GetUnitSetting(unitType, "portrait", "enabled") == true end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "portrait", "enabled", value)
                        end,
                    },
                    scale = {
                        name = "Scale",
                        desc = "Portrait size scale",
                        type = "range",
                        order = 2,
                        min = 0.5, max = 2.0, step = 0.05,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "portrait", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "portrait", "scale") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "portrait", "scale", value)
                        end,
                    },
                    offsetX = {
                        name = "X Offset",
                        desc = "Horizontal position offset",
                        type = "range",
                        order = 3,
                        min = -200, max = 200, step = 1,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "portrait", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "portrait", "offsetX") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "portrait", "offsetX", value)
                        end,
                    },
                    offsetY = {
                        name = "Y Offset",
                        desc = "Vertical position offset",
                        type = "range",
                        order = 4,
                        min = -100, max = 100, step = 1,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "portrait", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "portrait", "offsetY") end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "portrait", "offsetY", value)
                        end,
                    },
                    flip = {
                        name = "Flip Portrait",
                        desc = "Mirror the portrait horizontally",
                        type = "toggle",
                        order = 5,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "portrait", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "portrait", "flip") == true end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "portrait", "flip", value)
                        end,
                    },
                    classification = {
                        name = "Show Classification",
                        desc = "Show elite/rare/boss classification icons",
                        type = "toggle",
                        order = 6,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "portrait", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "portrait", "classification") == true end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "portrait", "classification", value)
                        end,
                    },
                    useClassIcon = {
                        name = "Use Class Icon",
                        desc = "Show class icon instead of portrait for players",
                        type = "toggle",
                        order = 7,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "portrait", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "portrait", "useClassIcon") == true end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "portrait", "useClassIcon", value)
                        end,
                    },
                    states = {
                        name = "Status States",
                        desc = "Show visual states (sleeping, dead, etc.)",
                        type = "toggle",
                        order = 8,
                        disabled = function() return not ns.DB.GetUnitSetting(unitType, "portrait", "enabled") end,
                        get = function() return ns.DB.GetUnitSetting(unitType, "portrait", "states") == true end,
                        set = function(_, value)
                            SetValueAndRefresh(unitType, "portrait", "states", value)
                        end,
                    },
                }
            },
        }
    }

    -- Add special configurations
    if specialConfigs then
        for key, specialConfig in pairs(specialConfigs) do
            config.args[key] = specialConfig
        end
    end

    -- Add unitframe-level enabled toggle for targettarget and focustarget (order 1 - before everything)
    if unitType == "targettarget" or unitType == "focustarget" then
        config.args.unitFrameEnabled = {
            name = "Show " .. displayName,
            type = "group",
            inline = true,
            order = 1,
            args = {
                enabled = {
                    name = "Enable " .. displayName,
                    desc = "Show/hide entire " .. unitLabel .. " frame (some users don't want this frame visible)",
                    type = "toggle",
                    order = 1,
                    get = function() return ns.DB.GetUnitSetting(unitType, "enabled") ~= false end,
                    set = function(_, value)
                        SetValueAndRefresh(unitType, "enabled", value)
                    end,
                },
            }
        }
    end

    -- Add position section for targettarget and focustarget (order 5 - after unitFrameEnabled, before health at 10)
    if unitType == "targettarget" or unitType == "focustarget" then
        local parentFrameName = (unitType == "targettarget") and "TargetFrame" or "FocusFrame"
        config.args.position = {
            name = "Position",
            type = "group",
            inline = true,
            order = 5,
            args = {
                description = {
                    name = "Position the entire " .. unitLabel .. " frame relative to " .. parentFrameName,
                    type = "description",
                    order = 0,
                },
                offsetX = {
                    name = "X Offset",
                    desc = "Horizontal position offset (positive = right, negative = left)",
                    type = "range",
                    order = 1,
                    min = -500, max = 500, step = 1,
                    get = function() return ns.DB.GetUnitSetting(unitType, "position", "offsetX") end,
                    set = function(_, value)
                        SetValueAndRefresh(unitType, "position", "offsetX", value)
                    end,
                },
                offsetY = {
                    name = "Y Offset",
                    desc = "Vertical position offset (positive = up, negative = down)",
                    type = "range",
                    order = 2,
                    min = -500, max = 500, step = 1,
                    get = function() return ns.DB.GetUnitSetting(unitType, "position", "offsetY") end,
                    set = function(_, value)
                        SetValueAndRefresh(unitType, "position", "offsetY", value)
                    end,
                },
                anchor = {
                    name = "Anchor Point",
                    desc = "Which point of the " .. unitLabel .. " frame to anchor",
                    type = "select",
                    order = 3,
                    values = {
                        ["TOPLEFT"] = "Top Left",
                        ["TOP"] = "Top",
                        ["TOPRIGHT"] = "Top Right",
                        ["LEFT"] = "Left",
                        ["CENTER"] = "Center",
                        ["RIGHT"] = "Right",
                        ["BOTTOMLEFT"] = "Bottom Left",
                        ["BOTTOM"] = "Bottom",
                        ["BOTTOMRIGHT"] = "Bottom Right"
                    },
                    get = function() return ns.DB.GetUnitSetting(unitType, "position", "anchor") end,
                    set = function(_, value)
                        SetValueAndRefresh(unitType, "position", "anchor", value)
                    end,
                },
                relativePoint = {
                    name = "Relative Point",
                    desc = "Which point of " .. parentFrameName .. " to attach to",
                    type = "select",
                    order = 4,
                    values = {
                        ["TOPLEFT"] = "Top Left",
                        ["TOP"] = "Top",
                        ["TOPRIGHT"] = "Top Right",
                        ["LEFT"] = "Left",
                        ["CENTER"] = "Center",
                        ["RIGHT"] = "Right",
                        ["BOTTOMLEFT"] = "Bottom Left",
                        ["BOTTOM"] = "Bottom",
                        ["BOTTOMRIGHT"] = "Bottom Right"
                    },
                    get = function() return ns.DB.GetUnitSetting(unitType, "position", "relativePoint") end,
                    set = function(_, value)
                        SetValueAndRefresh(unitType, "position", "relativePoint", value)
                    end,
                },
            }
        }
    end

    return config
end

-- ===========================
-- GENERAL TAB FUNCTIONS
-- ===========================

-- Reset database to defaults
local function ResetDatabase()
    -- Show confirmation popup for reset
    StaticPopup_Show("NIHUIUF_RESET_CONFIRM")
end

-- Export current configuration
local function ExportConfiguration()
    if not ns.DB or not ns.DB.GetAll then
        print("Nihui UF: Export not available")
        return
    end

    local config = ns.DB.GetAll()
    local exportString = "-- Nihui UF Configuration Export\n"
    exportString = exportString .. "-- Generated: " .. date("%Y-%m-%d %H:%M:%S") .. "\n\n"
    exportString = exportString .. "local exportedConfig = " .. ns.Utils.TableToString(config) .. "\n\n"
    exportString = exportString .. "return exportedConfig"

    -- Create simple copy frame
    local frame = CreateFrame("Frame", "NihuiUFExportFrame", UIParent, "BasicFrameTemplate")
    frame:SetSize(500, 400)
    frame:SetPoint("CENTER")
    frame.TitleText:SetText("Nihui UF - Export Configuration")

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(scrollFrame:GetWidth())
    editBox:SetText(exportString)
    editBox:SetCursorPosition(0)
    editBox:HighlightText()
    editBox:SetFocus()

    scrollFrame:SetScrollChild(editBox)
    frame:Show()

    print("Nihui UF: Configuration exported. Copy from the window that opened.")
end

-- Import configuration
local function ImportConfiguration(importString)
    if not importString or importString == "" then
        print("Nihui UF: No configuration data to import")
        return
    end

    local func, err = loadstring(importString)
    if not func then
        print("Nihui UF: Invalid configuration format - " .. (err or "unknown error"))
        return
    end

    local success, config = pcall(func)
    if not success then
        print("Nihui UF: Failed to load configuration - " .. (config or "unknown error"))
        return
    end

    if type(config) ~= "table" then
        print("Nihui UF: Invalid configuration data")
        return
    end

    -- Import the configuration
    if ns.DB and ns.DB.SetAll then
        ns.DB.SetAll(config)
        -- Use smart update (tries live update first, falls back to reload if needed)
        if ns.SmartUpdate then
            ns.SmartUpdate()
        elseif ns.ReloadNewSystem then
            ns.ReloadNewSystem()
        end
        print("Nihui UF: Configuration imported successfully")
    else
        print("Nihui UF: Import function not available")
    end
end

-- Profile management
local function CreateProfile(profileName)
    if not profileName or profileName == "" then
        print("Nihui UF: Profile name cannot be empty")
        return
    end

    if ns.DB and ns.DB.CreateProfile then
        local success = ns.DB.CreateProfile(profileName)
        if success then
            print("Nihui UF: Profile '" .. profileName .. "' created")
        else
            print("Nihui UF: Failed to create profile '" .. profileName .. "'")
        end
    end
end

local function DeleteProfile(profileName)
    if not profileName or profileName == "" then
        print("Nihui UF: Profile name cannot be empty")
        return
    end

    if ns.DB and ns.DB.DeleteProfile then
        local success = ns.DB.DeleteProfile(profileName)
        if success then
            print("Nihui UF: Profile '" .. profileName .. "' deleted")
            -- Force interface refresh after profile deletion
            if AceConfigRegistry then
                AceConfigRegistry:NotifyChange("Nihui_uf")
            end
        else
            print("Nihui UF: Failed to delete profile '" .. profileName .. "'")
        end
    end
end

local function SwitchProfile(profileName)
    if not profileName or profileName == "" then
        print("Nihui UF: Profile name cannot be empty")
        return
    end

    if ns.DB and ns.DB.SetProfile then
        local success = ns.DB.SetProfile(profileName)
        if success then
            -- Use smart update (tries live update first, falls back to reload if needed)
            if ns.SmartUpdate then
                ns.SmartUpdate()
            elseif ns.ReloadNewSystem then
                ns.ReloadNewSystem()
            end
            print("Nihui UF: Switched to profile '" .. profileName .. "'")
        else
            print("Nihui UF: Failed to switch to profile '" .. profileName .. "'")
        end
    end
end

-- ===========================
-- CONFIGURATION OPTIONS TABLE
-- ===========================

local function GetOptions()
    return {
        name = "Nihui UF Configuration",
        type = "group",
        childGroups = "tree",
        args = {
            -- General tab first
            general = {
                name = "|cffFFFFFFGeneral|r",
                type = "group",
                order = 0,
                args = {
                    databaseHeader = {
                        name = "Database Management",
                        type = "header",
                        order = 1
                    },
                    resetDB = {
                        name = "Reset to Defaults",
                        desc = "Reset all settings to default values (Warning: This will delete all your configurations!)",
                        type = "execute",
                        order = 2,
                        func = function()
                            StaticPopup_Show("NIHUIUF_RESET_CONFIRM")
                        end
                    },
                    profileHeader = {
                        name = "Profile Management",
                        type = "header",
                        order = 10
                    },
                    currentProfile = {
                        name = "Current Profile",
                        desc = "Currently active profile",
                        type = "description",
                        order = 11,
                        fontSize = "medium",
                        get = function()
                            if ns.DB and ns.DB.GetCurrentProfile then
                                return "Active: " .. (ns.DB.GetCurrentProfile() or "Default")
                            end
                            return "Active: Default"
                        end
                    },
                    createProfile = {
                        name = "Create New Profile",
                        desc = "Enter profile name and press Enter or click the + button to create",
                        type = "input",
                        order = 12,
                        width = "full",
                        get = function(info) return "" end,
                        set = function(info, value)
                            if value and value ~= "" then
                                CreateProfile(value)
                                -- Force interface refresh after profile creation
                                if AceConfigRegistry then
                                    AceConfigRegistry:NotifyChange("Nihui_uf")
                                end
                            else
                                print("Nihui UF: Profile name cannot be empty")
                            end
                        end
                    },
                    profileList = {
                        name = "Switch Profile",
                        desc = "Select profile to switch to",
                        type = "select",
                        order = 14,
                        values = function()
                            if ns.DB and ns.DB.GetProfiles then
                                return ns.DB.GetProfiles()
                            end
                            return {}
                        end,
                        get = function()
                            if ns.DB and ns.DB.GetCurrentProfile then
                                return ns.DB.GetCurrentProfile()
                            end
                            return nil
                        end,
                        set = function(_, value)
                            SwitchProfile(value)
                            -- Force interface refresh after profile switch
                            if AceConfigRegistry then
                                AceConfigRegistry:NotifyChange("Nihui_uf")
                            end
                        end
                    },
                    deleteProfile = {
                        name = "Delete Current Profile",
                        desc = "Delete the currently selected profile (Warning: Cannot be undone!)",
                        type = "execute",
                        order = 15,
                        func = function(info)
                            local options = info.options.args.general.args
                            local currentProfile = options.profileList:get(info)
                            if currentProfile and currentProfile ~= "Default" then
                                StaticPopup_Show("NIHUIUF_DELETE_PROFILE_CONFIRM", currentProfile)
                            else
                                print("Nihui UF: Cannot delete Default profile")
                            end
                        end
                    },
                    importExportHeader = {
                        name = "Import / Export",
                        type = "header",
                        order = 20
                    },
                    exportConfig = {
                        name = "Export Configuration",
                        desc = "Export current configuration to clipboard",
                        type = "execute",
                        order = 21,
                        func = ExportConfiguration
                    },
                    importString = {
                        name = "Import Configuration",
                        desc = "Paste configuration string here",
                        type = "input",
                        order = 22,
                        multiline = true,
                        width = "full",
                        get = function() return "" end,
                        set = function() end
                    },
                    importConfig = {
                        name = "Import",
                        desc = "Import the configuration from the text above",
                        type = "execute",
                        order = 23,
                        func = function(info)
                            local options = info.options.args.general.args
                            local importString = options.importString:get(info)
                            ImportConfiguration(importString)
                        end
                    }
                }
            },
            -- Use builder with special ClassPower config for player
            player = CreateUnitFrameConfig("player", "|cff20cc20Player|r", 1, {
                classpower = {
                    name = "Class Power",
                    type = "group",
                    inline = true,
                    order = 40,
                    args = {
                        enabled = {
                            name = "Enable Class Power",
                            desc = "Show class-specific power (combo points, holy power, etc.)",
                            type = "toggle",
                            order = 1,
                            get = function() return ns.DB.GetUnitSetting("player", "classpower", "enabled") ~= false end,
                            set = function(_, value)
                                SetValueAndRefresh("player", "classpower", "enabled", value)
                            end,
                        },
                        scale = {
                            name = "Scale",
                            desc = "Class power size scale",
                            type = "range",
                            order = 2,
                            min = 0.5, max = 2.0, step = 0.05,
                            disabled = function() return not ns.DB.GetUnitSetting("player", "classpower", "enabled") end,
                            get = function() return ns.DB.GetUnitSetting("player", "classpower", "scale") end,
                            set = function(_, value)
                                SetValueAndRefresh("player", "classpower", "scale", value)
                            end,
                        },
                        offsetX = {
                            name = "X Offset",
                            desc = "Horizontal position offset",
                            type = "range",
                            order = 3,
                            min = -300, max = 300, step = 1,
                            disabled = function() return not ns.DB.GetUnitSetting("player", "classpower", "enabled") end,
                            get = function() return ns.DB.GetUnitSetting("player", "classpower", "offsetX") end,
                            set = function(_, value)
                                SetValueAndRefresh("player", "classpower", "offsetX", value)
                            end,
                        },
                        offsetY = {
                            name = "Y Offset",
                            desc = "Vertical position offset",
                            type = "range",
                            order = 4,
                            min = -250, max = 250, step = 1,
                            disabled = function() return not ns.DB.GetUnitSetting("player", "classpower", "enabled") end,
                            get = function() return ns.DB.GetUnitSetting("player", "classpower", "offsetY") end,
                            set = function(_, value)
                                SetValueAndRefresh("player", "classpower", "offsetY", value)
                            end,
                        },
                    }
                }
            }),
            -- TARGET with nested tabs (Target + Target of Target)
            target = {
                type = "group",
                name = "|cffcc2020Target|r",
                order = 2,
                childGroups = "tab",
                args = {
                    target_main = CreateUnitFrameConfig("target", "Target", 1, {
                        auras = {
                            name = "Auras (Buffs & Debuffs)",
                            type = "group",
                            inline = true,
                            order = 6,
                            args = {
                                enabled = {
                                    name = "Enable Auras",
                                    desc = "Show custom buff and debuff icons",
                                    type = "toggle",
                                    order = 1,
                                    get = function() return ns.DB.GetUnitSetting("target", "auras", "enabled") == true end,
                                    set = function(_, value)
                                        SetValueAndRefresh("target", "auras", "enabled", value)
                                    end,
                                },
                                scale = {
                                    name = "Scale",
                                    desc = "Size of aura icons",
                                    type = "range",
                                    order = 2,
                                    min = 0.5, max = 2, step = 0.05,
                                    disabled = function() return not ns.DB.GetUnitSetting("target", "auras", "enabled") end,
                                    get = function() return ns.DB.GetUnitSetting("target", "auras", "scale") end,
                                    set = function(_, value)
                                        SetValueAndRefresh("target", "auras", "scale", value)
                                    end,
                                },
                                perRow = {
                                    name = "Per Row",
                                    desc = "Number of auras per row",
                                    type = "range",
                                    order = 3,
                                    min = 4, max = 16, step = 1,
                                    disabled = function() return not ns.DB.GetUnitSetting("target", "auras", "enabled") end,
                                    get = function() return ns.DB.GetUnitSetting("target", "auras", "perRow") end,
                                    set = function(_, value)
                                        SetValueAndRefresh("target", "auras", "perRow", value)
                                    end,
                                },
                                direction = {
                                    name = "Direction",
                                    desc = "Direction for aura growth",
                                    type = "select",
                                    order = 4,
                                    values = {
                                        ["RIGHT"] = "Right",
                                        ["LEFT"] = "Left",
                                        ["UP"] = "Up",
                                        ["DOWN"] = "Down"
                                    },
                                    disabled = function() return not ns.DB.GetUnitSetting("target", "auras", "enabled") end,
                                    get = function() return ns.DB.GetUnitSetting("target", "auras", "direction") end,
                                    set = function(_, value)
                                        SetValueAndRefresh("target", "auras", "direction", value)
                                    end,
                                },
                                showTimer = {
                                    name = "Show Timer",
                                    desc = "Show duration timer below icons",
                                    type = "toggle",
                                    order = 5,
                                    disabled = function() return not ns.DB.GetUnitSetting("target", "auras", "enabled") end,
                                    get = function() return ns.DB.GetUnitSetting("target", "auras", "showTimer") ~= false end,
                                    set = function(_, value)
                                        SetValueAndRefresh("target", "auras", "showTimer", value)
                                    end,
                                },
                                spacing = {
                                    name = "Spacing",
                                    desc = "Space between aura icons",
                                    type = "range",
                                    order = 6,
                                    min = 0, max = 10, step = 1,
                                    disabled = function() return not ns.DB.GetUnitSetting("target", "auras", "enabled") end,
                                    get = function() return ns.DB.GetUnitSetting("target", "auras", "spacing") end,
                                    set = function(_, value)
                                        SetValueAndRefresh("target", "auras", "spacing", value)
                                    end,
                                },
                                offsetX = {
                                    name = "X Offset",
                                    desc = "Horizontal position offset",
                                    type = "range",
                                    order = 7,
                                    min = -200, max = 200, step = 1,
                                    disabled = function() return not ns.DB.GetUnitSetting("target", "auras", "enabled") end,
                                    get = function() return ns.DB.GetUnitSetting("target", "auras", "offsetX") end,
                                    set = function(_, value)
                                        SetValueAndRefresh("target", "auras", "offsetX", value)
                                    end,
                                },
                                offsetY = {
                                    name = "Y Offset",
                                    desc = "Vertical position offset",
                                    type = "range",
                                    order = 8,
                                    min = -100, max = 100, step = 1,
                                    disabled = function() return not ns.DB.GetUnitSetting("target", "auras", "enabled") end,
                                    get = function() return ns.DB.GetUnitSetting("target", "auras", "offsetY") end,
                                    set = function(_, value)
                                        SetValueAndRefresh("target", "auras", "offsetY", value)
                                    end,
                                }
                            }
                        }
                    }),
                    target_tot = CreateUnitFrameConfig("targettarget", "Target of Target", 2)
                }
            },
            -- FOCUS with nested tabs (Focus + Focus Target)
            focus = {
                type = "group",
                name = "|cffccaa20Focus|r",
                order = 3,
                childGroups = "tab",
                args = {
                    focus_main = CreateUnitFrameConfig("focus", "Focus", 1, {
                        auras = {
                            name = "Auras (Buffs & Debuffs)",
                            type = "group",
                            inline = true,
                            order = 6,
                            args = {
                                enabled = {
                                    name = "Enable Auras",
                                    desc = "Show custom buff and debuff icons",
                                    type = "toggle",
                                    order = 1,
                                    get = function() return ns.DB.GetUnitSetting("focus", "auras", "enabled") == true end,
                                    set = function(_, value)
                                        SetValueAndRefresh("focus", "auras", "enabled", value)
                                    end,
                                },
                                scale = {
                                    name = "Scale",
                                    desc = "Size of aura icons",
                                    type = "range",
                                    order = 2,
                                    min = 0.5, max = 2, step = 0.05,
                                    disabled = function() return not ns.DB.GetUnitSetting("focus", "auras", "enabled") end,
                                    get = function() return ns.DB.GetUnitSetting("focus", "auras", "scale") end,
                                    set = function(_, value)
                                        SetValueAndRefresh("focus", "auras", "scale", value)
                                    end,
                                },
                                perRow = {
                                    name = "Per Row",
                                    desc = "Number of auras per row",
                                    type = "range",
                                    order = 3,
                                    min = 4, max = 16, step = 1,
                                    disabled = function() return not ns.DB.GetUnitSetting("focus", "auras", "enabled") end,
                                    get = function() return ns.DB.GetUnitSetting("focus", "auras", "perRow") end,
                                    set = function(_, value)
                                        SetValueAndRefresh("focus", "auras", "perRow", value)
                                    end,
                                },
                                direction = {
                                    name = "Direction",
                                    desc = "Direction for aura growth",
                                    type = "select",
                                    order = 4,
                                    values = {
                                        ["RIGHT"] = "Right",
                                        ["LEFT"] = "Left",
                                        ["UP"] = "Up",
                                        ["DOWN"] = "Down"
                                    },
                                    disabled = function() return not ns.DB.GetUnitSetting("focus", "auras", "enabled") end,
                                    get = function() return ns.DB.GetUnitSetting("focus", "auras", "direction") end,
                                    set = function(_, value)
                                        SetValueAndRefresh("focus", "auras", "direction", value)
                                    end,
                                },
                                showTimer = {
                                    name = "Show Timer",
                                    desc = "Show duration timer below icons",
                                    type = "toggle",
                                    order = 5,
                                    disabled = function() return not ns.DB.GetUnitSetting("focus", "auras", "enabled") end,
                                    get = function() return ns.DB.GetUnitSetting("focus", "auras", "showTimer") ~= false end,
                                    set = function(_, value)
                                        SetValueAndRefresh("focus", "auras", "showTimer", value)
                                    end,
                                },
                                spacing = {
                                    name = "Spacing",
                                    desc = "Space between aura icons",
                                    type = "range",
                                    order = 6,
                                    min = 0, max = 10, step = 1,
                                    disabled = function() return not ns.DB.GetUnitSetting("focus", "auras", "enabled") end,
                                    get = function() return ns.DB.GetUnitSetting("focus", "auras", "spacing") end,
                                    set = function(_, value)
                                        SetValueAndRefresh("focus", "auras", "spacing", value)
                                    end,
                                },
                                offsetX = {
                                    name = "X Offset",
                                    desc = "Horizontal position offset",
                                    type = "range",
                                    order = 7,
                                    min = -200, max = 200, step = 1,
                                    disabled = function() return not ns.DB.GetUnitSetting("focus", "auras", "enabled") end,
                                    get = function() return ns.DB.GetUnitSetting("focus", "auras", "offsetX") end,
                                    set = function(_, value)
                                        SetValueAndRefresh("focus", "auras", "offsetX", value)
                                    end,
                                },
                                offsetY = {
                                    name = "Y Offset",
                                    desc = "Vertical position offset",
                                    type = "range",
                                    order = 8,
                                    min = -100, max = 100, step = 1,
                                    disabled = function() return not ns.DB.GetUnitSetting("focus", "auras", "enabled") end,
                                    get = function() return ns.DB.GetUnitSetting("focus", "auras", "offsetY") end,
                                    set = function(_, value)
                                        SetValueAndRefresh("focus", "auras", "offsetY", value)
                                    end,
                                }
                            }
                        }
                    }),
                    focus_fot = CreateUnitFrameConfig("focustarget", "Focus Target", 2)
                }
            },
            pet = CreateUnitFrameConfig("pet", "|cffaa60cc Pet|r", 4),
            party = CreateUnitFrameConfig("party", "|cff20aacc Party|r", 5, {
                partySpacing = {
                    name = "Party Spacing",
                    type = "group",
                    inline = true,
                    order = 5,  -- Before health (order 10)
                    args = {
                        gap = {
                            name = "Member Gap",
                            desc = "Vertical spacing between party members (in pixels)",
                            type = "range",
                            order = 1,
                            min = 0, max = 150, step = 1,
                            get = function() return ns.DB.GetUnitSetting("party", "gap") end,
                            set = function(_, value)
                                SetValueAndRefresh("party", "gap", value)
                                -- Also trigger repositioning of party members
                                if ns.Modules and ns.Modules.Party and ns.Modules.Party.ApplyGap then
                                    ns.Modules.Party.ApplyGap()
                                end
                            end,
                        },
                    }
                }
            }),
            raid = {
                name = "|cff20cc20Raid|r",
                type = "group",
                order = 6,
                args = {
                    header = {
                        name = "|cff20cc20Raid|r Unit Frame Configuration",
                        type = "header",
                        order = 0,
                    },
                    description = {
                        name = "Raid frames use Blizzard's CompactRaidFrames. Size and position are controlled by Blizzard's Edit Mode.\n\nYou can customize health bar appearance, text, and role indicators below.",
                        type = "description",
                        order = 1,
                        fontSize = "medium",
                    },
                    health = {
                        name = "Health Bar",
                        type = "group",
                        inline = true,
                        order = 10,
                        args = {
                            infoText = {
                                name = "Health bar automatically fills the raid frame with 95% size (5% padding for borders).",
                                type = "description",
                                order = 0,
                            },
                            texture = {
                                name = "Health Texture",
                                desc = "Status bar texture",
                                type = "select",
                                order = 1,
                                dialogControl = "LSM30_Statusbar",
                                values = LibStub and LibStub("LibSharedMedia-3.0", true) and LibStub("LibSharedMedia-3.0"):HashTable("statusbar") or {},
                                get = function()
                                    local texturePath = ns.DB.GetUnitSetting("raid", "health", "texture")
                                    if texturePath then
                                        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
                                        if LSM then
                                            for name, path in pairs(LSM:HashTable("statusbar")) do
                                                if path == texturePath then
                                                    return name
                                                end
                                            end
                                        end
                                    end
                                    return "g1"
                                end,
                                set = function(_, value)
                                    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
                                    if LSM then
                                        local texturePath = LSM:Fetch("statusbar", value)
                                        SetValueAndRefresh("raid", "health", "texture", texturePath)
                                    end
                                end,
                            },
                            colorByClass = {
                                name = "Color by Class",
                                desc = "Use class color for health bar",
                                type = "toggle",
                                order = 2,
                                get = function() return ns.DB.GetUnitSetting("raid", "health", "colorByClass") ~= false end,
                                set = function(_, value)
                                    SetValueAndRefresh("raid", "health", "colorByClass", value)
                                end,
                            },
                            glassEnabled = {
                                name = "Enable Glass Effect",
                                desc = "Enable glass overlay effect",
                                type = "toggle",
                                order = 3,
                                get = function() return ns.DB.GetUnitSetting("raid", "health", "glassEnabled") ~= false end,
                                set = function(_, value)
                                    SetValueAndRefresh("raid", "health", "glassEnabled", value)
                                end,
                            },
                            glassAlpha = {
                                name = "Glass Opacity",
                                desc = "Glass effect transparency",
                                type = "range",
                                order = 4,
                                min = 0, max = 1, step = 0.05,
                                disabled = function() return not ns.DB.GetUnitSetting("raid", "health", "glassEnabled") end,
                                get = function() return ns.DB.GetUnitSetting("raid", "health", "glassAlpha") end,
                                set = function(_, value)
                                    SetValueAndRefresh("raid", "health", "glassAlpha", value)
                                end,
                            },
                            -- Health text (value on the bar)
                            healthTextHeader = {
                                name = "Health Text",
                                type = "header",
                                order = 10,
                            },
                            healthTextEnabled = {
                                name = "Enable Health Text",
                                desc = "Show health value on the bar",
                                type = "toggle",
                                order = 11,
                                get = function() return ns.DB.GetUnitSetting("raid", "text", "health", "enabled") ~= false end,
                                set = function(_, value)
                                    SetValueAndRefresh("raid", "text", "health", "enabled", value)
                                end,
                            },
                            healthTextStyle = {
                                name = "Health Text Style",
                                desc = "Text format style",
                                type = "select",
                                order = 12,
                                values = {
                                    ["current"] = "Current only",
                                    ["current_k"] = "Current (k format)",
                                    ["k_version"] = "Current / Max (k format)",
                                    ["percent"] = "Percentage only"
                                },
                                disabled = function() return not ns.DB.GetUnitSetting("raid", "text", "health", "enabled") end,
                                get = function() return ns.DB.GetUnitSetting("raid", "text", "health", "style") end,
                                set = function(_, value)
                                    SetValueAndRefresh("raid", "text", "health", "style", value)
                                end,
                            },
                            healthTextSize = {
                                name = "Health Text Size",
                                desc = "Font size for health value",
                                type = "range",
                                order = 13,
                                min = 6, max = 16, step = 1,
                                disabled = function() return not ns.DB.GetUnitSetting("raid", "text", "health", "enabled") end,
                                get = function() return ns.DB.GetUnitSetting("raid", "text", "health", "size") end,
                                set = function(_, value)
                                    SetValueAndRefresh("raid", "text", "health", "size", value)
                                end,
                            },
                            healthTextX = {
                                name = "Health Text X Offset",
                                desc = "Horizontal position offset",
                                type = "range",
                                order = 14,
                                min = -100, max = 100, step = 1,
                                disabled = function() return not ns.DB.GetUnitSetting("raid", "text", "health", "enabled") end,
                                get = function() return ns.DB.GetUnitSetting("raid", "text", "health", "x") end,
                                set = function(_, value)
                                    SetValueAndRefresh("raid", "text", "health", "x", value)
                                end,
                            },
                            healthTextY = {
                                name = "Health Text Y Offset",
                                desc = "Vertical position offset",
                                type = "range",
                                order = 15,
                                min = -50, max = 50, step = 1,
                                disabled = function() return not ns.DB.GetUnitSetting("raid", "text", "health", "enabled") end,
                                get = function() return ns.DB.GetUnitSetting("raid", "text", "health", "y") end,
                                set = function(_, value)
                                    SetValueAndRefresh("raid", "text", "health", "y", value)
                                end,
                            },
                        }
                    },
                    nameLevel = {
                        name = "Name & Level",
                        type = "group",
                        inline = true,
                        order = 20,
                        args = {
                            nameEnabled = {
                                name = "Show Name",
                                desc = "Show member name above health bar",
                                type = "toggle",
                                order = 1,
                                get = function() return ns.DB.GetUnitSetting("raid", "text", "name", "show") ~= false end,
                                set = function(_, value)
                                    SetValueAndRefresh("raid", "text", "name", "show", value)
                                end,
                            },
                            nameColorByClass = {
                                name = "Name Class Color",
                                desc = "Use class color for name",
                                type = "toggle",
                                order = 2,
                                disabled = function() return not ns.DB.GetUnitSetting("raid", "text", "name", "show") end,
                                get = function() return ns.DB.GetUnitSetting("raid", "text", "name", "colorByClass") ~= false end,
                                set = function(_, value)
                                    SetValueAndRefresh("raid", "text", "name", "colorByClass", value)
                                end,
                            },
                            nameTruncate = {
                                name = "Truncate Name",
                                desc = "Truncate long names automatically",
                                type = "toggle",
                                order = 3,
                                disabled = function() return not ns.DB.GetUnitSetting("raid", "text", "name", "show") end,
                                get = function() return ns.DB.GetUnitSetting("raid", "text", "name", "truncate") ~= false end,
                                set = function(_, value)
                                    SetValueAndRefresh("raid", "text", "name", "truncate", value)
                                end,
                            },
                            nameSize = {
                                name = "Name Size",
                                desc = "Font size for name",
                                type = "range",
                                order = 4,
                                min = 6, max = 14, step = 1,
                                disabled = function() return not ns.DB.GetUnitSetting("raid", "text", "name", "show") end,
                                get = function() return ns.DB.GetUnitSetting("raid", "text", "name", "size") end,
                                set = function(_, value)
                                    SetValueAndRefresh("raid", "text", "name", "size", value)
                                end,
                            },
                            nameX = {
                                name = "Name X Offset",
                                desc = "Horizontal position offset",
                                type = "range",
                                order = 5,
                                min = -100, max = 100, step = 1,
                                disabled = function() return not ns.DB.GetUnitSetting("raid", "text", "name", "show") end,
                                get = function() return ns.DB.GetUnitSetting("raid", "text", "nameLevel", "containerOffset", "x") end,
                                set = function(_, value)
                                    SetValueAndRefresh("raid", "text", "nameLevel", "containerOffset", "x", value)
                                end,
                            },
                            nameY = {
                                name = "Name Y Offset",
                                desc = "Vertical position offset",
                                type = "range",
                                order = 6,
                                min = -50, max = 50, step = 1,
                                disabled = function() return not ns.DB.GetUnitSetting("raid", "text", "name", "show") end,
                                get = function() return ns.DB.GetUnitSetting("raid", "text", "nameLevel", "containerOffset", "y") end,
                                set = function(_, value)
                                    SetValueAndRefresh("raid", "text", "nameLevel", "containerOffset", "y", value)
                                end,
                            },
                        }
                    },
                }
            },
            boss = CreateUnitFrameConfig("boss", "|cffffff00Boss|r", 7),
            arena = CreateUnitFrameConfig("arena", "|cffff6600Arena|r", 8),
            -- XP/Reputation Bars
            xp = {
                name = "|cffa335eeXP & Reputation|r",
                type = "group",
                order = 9,
                childGroups = "tab",
                args = {
                    xp_main = {
                        name = "Experience Bar",
                        type = "group",
                        order = 1,
                        args = {
                            header = {
                                name = "Experience Bar Configuration",
                                type = "header",
                                order = 0
                            },
                            enabled = {
                                name = "Enable XP Bar",
                                desc = "Show/hide the experience bar",
                                type = "toggle",
                                order = 1,
                                get = function() return ns.DB.Get("xp.enabled") ~= false end,
                                set = function(_, value)
                                    ns.DB.Set("xp.enabled", value)
                                    -- Refresh XP bar
                                    if ns.Modules and ns.Modules.XP then
                                        if value then
                                            ns.Modules.XP.Show()
                                        else
                                            ns.Modules.XP.Hide()
                                        end
                                    end
                                end
                            },
                            editModeInfo = {
                                type = "description",
                                name = "XP bar size and position are controlled by Blizzard's Edit Mode.\n\nPress ESC > Edit Mode, then move the 'Status Bar 1' container.",
                                order = 10,
                                fontSize = "medium"
                            },
                            appearanceHeader = {
                                name = "Appearance",
                                type = "header",
                                order = 20
                            },
                            glassEnabled = {
                                name = "Enable Glass Effect",
                                desc = "Enable glass overlay effect",
                                type = "toggle",
                                order = 21,
                                get = function() return ns.DB.Get("xp.glass.enabled") ~= false end,
                                set = function(_, value)
                                    ns.DB.Set("xp.glass.enabled", value)
                                    if ns.Modules and ns.Modules.XP and ns.Modules.XP.UpdateConfig then
                                        ns.Modules.XP.UpdateConfig()
                                    end
                                end
                            },
                            glassAlpha = {
                                name = "Glass Opacity",
                                desc = "Glass effect transparency",
                                type = "range",
                                order = 22,
                                min = 0, max = 1, step = 0.05,
                                disabled = function() return not ns.DB.Get("xp.glass.enabled") end,
                                get = function() return ns.DB.Get("xp.glass.alpha") end,
                                set = function(_, value)
                                    ns.DB.Set("xp.glass.alpha", value)
                                    if ns.Modules and ns.Modules.XP and ns.Modules.XP.UpdateConfig then
                                        ns.Modules.XP.UpdateConfig()
                                    end
                                end
                            },
                            borderEnabled = {
                                name = "Enable Border",
                                desc = "Enable border effect",
                                type = "toggle",
                                order = 23,
                                get = function() return ns.DB.Get("xp.border.enabled") ~= false end,
                                set = function(_, value)
                                    ns.DB.Set("xp.border.enabled", value)
                                    if ns.Modules and ns.Modules.XP and ns.Modules.XP.UpdateConfig then
                                        ns.Modules.XP.UpdateConfig()
                                    end
                                end
                            },
                            textHeader = {
                                name = "Text Display",
                                type = "header",
                                order = 30
                            },
                            textEnabled = {
                                name = "Enable Text",
                                desc = "Show XP percentage text",
                                type = "toggle",
                                order = 31,
                                get = function() return ns.DB.Get("xp.text.enabled") ~= false end,
                                set = function(_, value)
                                    ns.DB.Set("xp.text.enabled", value)
                                    if ns.Modules and ns.Modules.XP and ns.Modules.XP.UpdateConfig then
                                        ns.Modules.XP.UpdateConfig()
                                    end
                                end
                            },
                            textPosition = {
                                name = "Text Position",
                                desc = "Where to display the XP text",
                                type = "select",
                                order = 32,
                                values = {
                                    ["left"] = "Left",
                                    ["center"] = "Center",
                                    ["right"] = "Right",
                                    ["none"] = "None (Hidden)"
                                },
                                disabled = function() return not ns.DB.Get("xp.text.enabled") end,
                                get = function() return ns.DB.Get("xp.text.position") end,
                                set = function(_, value)
                                    ns.DB.Set("xp.text.position", value)
                                    if ns.Modules and ns.Modules.XP and ns.Modules.XP.UpdateConfig then
                                        ns.Modules.XP.UpdateConfig()
                                    end
                                end
                            },
                            textSize = {
                                name = "Text Size",
                                desc = "Font size for XP text",
                                type = "range",
                                order = 33,
                                min = 6, max = 20, step = 1,
                                disabled = function() return not ns.DB.Get("xp.text.enabled") end,
                                get = function() return ns.DB.Get("xp.text.size") end,
                                set = function(_, value)
                                    ns.DB.Set("xp.text.size", value)
                                    if ns.Modules and ns.Modules.XP and ns.Modules.XP.UpdateConfig then
                                        ns.Modules.XP.UpdateConfig()
                                    end
                                end
                            },
                            restedHeader = {
                                name = "Rested XP",
                                type = "header",
                                order = 40
                            },
                            restedEnabled = {
                                name = "Show Rested XP",
                                desc = "Show lighter overlay for rested XP range",
                                type = "toggle",
                                order = 41,
                                get = function() return ns.DB.Get("xp.rested.enabled") ~= false end,
                                set = function(_, value)
                                    ns.DB.Set("xp.rested.enabled", value)
                                    if ns.Modules and ns.Modules.XP and ns.Modules.XP.UpdateConfig then
                                        ns.Modules.XP.UpdateConfig()
                                    end
                                end
                            },
                            animationHeader = {
                                name = "Animations",
                                type = "header",
                                order = 50
                            },
                            animationEnabled = {
                                name = "Enable XP Gain Animation",
                                desc = "Show preview bar before main bar fills when gaining XP",
                                type = "toggle",
                                order = 51,
                                get = function() return ns.DB.Get("xp.animation.enabled") ~= false end,
                                set = function(_, value)
                                    ns.DB.Set("xp.animation.enabled", value)
                                end
                            },
                            previewDuration = {
                                name = "Preview Duration",
                                desc = "How long the preview bar takes to appear (seconds)",
                                type = "range",
                                order = 52,
                                min = 0.1, max = 2.0, step = 0.1,
                                disabled = function() return not ns.DB.Get("xp.animation.enabled") end,
                                get = function() return ns.DB.Get("xp.animation.previewDuration") end,
                                set = function(_, value)
                                    ns.DB.Set("xp.animation.previewDuration", value)
                                end
                            },
                            fillDelay = {
                                name = "Fill Delay",
                                desc = "Delay before main bar starts filling after preview appears (seconds)",
                                type = "range",
                                order = 53,
                                min = 0, max = 2.0, step = 0.1,
                                disabled = function() return not ns.DB.Get("xp.animation.enabled") end,
                                get = function() return ns.DB.Get("xp.animation.fillDelay") end,
                                set = function(_, value)
                                    ns.DB.Set("xp.animation.fillDelay", value)
                                end
                            },
                            fillDuration = {
                                name = "Fill Duration",
                                desc = "How long the main bar takes to fill (seconds)",
                                type = "range",
                                order = 54,
                                min = 0.1, max = 2.0, step = 0.1,
                                disabled = function() return not ns.DB.Get("xp.animation.enabled") end,
                                get = function() return ns.DB.Get("xp.animation.fillDuration") end,
                                set = function(_, value)
                                    ns.DB.Set("xp.animation.fillDuration", value)
                                end
                            }
                        }
                    },
                    reputation_main = {
                        name = "Reputation Bar",
                        type = "group",
                        order = 2,
                        args = {
                            header = {
                                name = "Reputation Bar Configuration",
                                type = "header",
                                order = 0
                            },
                            description = {
                                name = "Reputation bar is displayed above the XP bar when you are tracking a faction. It is automatically hidden when no faction is being watched.",
                                type = "description",
                                order = 1,
                                fontSize = "medium"
                            },
                            enabled = {
                                name = "Enable Reputation Bar",
                                desc = "Show/hide the reputation bar when watching a faction",
                                type = "toggle",
                                order = 2,
                                get = function() return ns.DB.Get("reputation.enabled") ~= false end,
                                set = function(_, value)
                                    ns.DB.Set("reputation.enabled", value)
                                    if ns.Modules and ns.Modules.XP and ns.Modules.XP.UpdateConfig then
                                        ns.Modules.XP.UpdateConfig()
                                    end
                                end
                            },
                            editModeInfo = {
                                type = "description",
                                name = "Reputation bar size and position are controlled by Blizzard's Edit Mode.\n\nPress ESC > Edit Mode, then move the 'Status Bar 2' container.",
                                order = 10,
                                fontSize = "medium"
                            },
                            appearanceHeader = {
                                name = "Appearance",
                                type = "header",
                                order = 20
                            },
                            glassEnabled = {
                                name = "Enable Glass Effect",
                                desc = "Enable glass overlay effect",
                                type = "toggle",
                                order = 21,
                                get = function() return ns.DB.Get("reputation.glass.enabled") ~= false end,
                                set = function(_, value)
                                    ns.DB.Set("reputation.glass.enabled", value)
                                    if ns.Modules and ns.Modules.XP and ns.Modules.XP.UpdateConfig then
                                        ns.Modules.XP.UpdateConfig()
                                    end
                                end
                            },
                            glassAlpha = {
                                name = "Glass Opacity",
                                desc = "Glass effect transparency",
                                type = "range",
                                order = 22,
                                min = 0, max = 1, step = 0.05,
                                disabled = function() return not ns.DB.Get("reputation.glass.enabled") end,
                                get = function() return ns.DB.Get("reputation.glass.alpha") end,
                                set = function(_, value)
                                    ns.DB.Set("reputation.glass.alpha", value)
                                    if ns.Modules and ns.Modules.XP and ns.Modules.XP.UpdateConfig then
                                        ns.Modules.XP.UpdateConfig()
                                    end
                                end
                            },
                            borderEnabled = {
                                name = "Enable Border",
                                desc = "Enable border effect",
                                type = "toggle",
                                order = 23,
                                get = function() return ns.DB.Get("reputation.border.enabled") ~= false end,
                                set = function(_, value)
                                    ns.DB.Set("reputation.border.enabled", value)
                                    if ns.Modules and ns.Modules.XP and ns.Modules.XP.UpdateConfig then
                                        ns.Modules.XP.UpdateConfig()
                                    end
                                end
                            },
                            textHeader = {
                                name = "Text Display",
                                type = "header",
                                order = 30
                            },
                            textEnabled = {
                                name = "Enable Text",
                                desc = "Show faction name and standing",
                                type = "toggle",
                                order = 31,
                                get = function() return ns.DB.Get("reputation.text.enabled") ~= false end,
                                set = function(_, value)
                                    ns.DB.Set("reputation.text.enabled", value)
                                    if ns.Modules and ns.Modules.XP and ns.Modules.XP.UpdateConfig then
                                        ns.Modules.XP.UpdateConfig()
                                    end
                                end
                            },
                            textPosition = {
                                name = "Text Position",
                                desc = "Where to display the reputation text",
                                type = "select",
                                order = 32,
                                values = {
                                    ["left"] = "Left",
                                    ["center"] = "Center",
                                    ["right"] = "Right",
                                    ["none"] = "None (Hidden)"
                                },
                                disabled = function() return not ns.DB.Get("reputation.text.enabled") end,
                                get = function() return ns.DB.Get("reputation.text.position") end,
                                set = function(_, value)
                                    ns.DB.Set("reputation.text.position", value)
                                    if ns.Modules and ns.Modules.XP and ns.Modules.XP.UpdateConfig then
                                        ns.Modules.XP.UpdateConfig()
                                    end
                                end
                            },
                            textSize = {
                                name = "Text Size",
                                desc = "Font size for reputation text",
                                type = "range",
                                order = 33,
                                min = 6, max = 16, step = 1,
                                disabled = function() return not ns.DB.Get("reputation.text.enabled") end,
                                get = function() return ns.DB.Get("reputation.text.size") end,
                                set = function(_, value)
                                    ns.DB.Set("reputation.text.size", value)
                                    if ns.Modules and ns.Modules.XP and ns.Modules.XP.UpdateConfig then
                                        ns.Modules.XP.UpdateConfig()
                                    end
                                end
                            }
                        }
                    }
                }
            }
        }
    }
end

-- ===========================
-- STATIC POPUPS
-- ===========================

-- Reset confirmation popup
StaticPopupDialogs["NIHUIUF_RESET_CONFIRM"] = {
    text = "Are you sure you want to reset Nihui UF to default settings?\n\nThis will delete ALL your configurations and cannot be undone!\n\nAll frames will be updated automatically.",
    button1 = "Reset & Update",
    button2 = "Cancel",
    OnAccept = function()
        if ns.DB and ns.DB.ResetToDefaults then
            ns.DB.ResetToDefaults()
            print("Nihui UF: Database reset to defaults. Updating systems...")
            -- Use smart update (tries live update first, falls back to reload if needed)
            C_Timer.After(0.5, function()
                if ns.SmartUpdate then
                    ns.SmartUpdate()
                elseif ns.ReloadNewSystem then
                    ns.ReloadNewSystem()
                end
            end)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Delete profile confirmation popup
StaticPopupDialogs["NIHUIUF_DELETE_PROFILE_CONFIRM"] = {
    text = "Are you sure you want to delete the profile '%s'?\n\nThis cannot be undone!",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, profileName)
        DeleteProfile(profileName)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}


-- ===========================
-- PANEL MANAGEMENT
-- ===========================

-- Initialize configuration panel
function ns.Config.Panel.Initialize()
    -- Prevent double registration
    if ns.Config.Panel._initialized then
        return
    end

    -- Register options table (use consistent name with addon)
    AceConfig:RegisterOptionsTable("Nihui_uf", GetOptions)

    -- Create dialog with tree groups (sidebar style)
    AceConfigDialog:AddToBlizOptions("Nihui_uf", "Nihui UF")

    ns.Config.Panel._initialized = true
end

-- Show configuration panel (standalone window)
function ns.Config.Panel.Show()
    -- Ensure panel is initialized
    if not ns.Config.Panel._initialized then
        ns.Config.Panel.Initialize()
    end

    -- Open standalone window and select player section
    AceConfigDialog:Open("Nihui_uf", nil)
    AceConfigDialog:SelectGroup("Nihui_uf", "player")
end

-- Show configuration panel in Blizzard settings
function ns.Config.Panel.OpenBlizzardOptions()
    -- Open Blizzard Interface Options to our panel
    InterfaceOptionsFrame_OpenToCategory("Nihui UF")
    InterfaceOptionsFrame_OpenToCategory("Nihui UF") -- Call twice for proper focus
end


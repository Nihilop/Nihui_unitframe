-- config/database.lua - Unified Database API System
local _, ns = ...

-- Database namespace
ns.DB = {}

-- ===========================
-- DATABASE INITIALIZATION
-- ===========================

-- Initialize database with defaults
function ns.DB.Initialize()
    -- Create SavedVariables structure if not exists
    if not NihuiUFDB then
        NihuiUFDB = {}
    end

    -- Initialize profile database
    if not NihuiUFDB.profile then
        NihuiUFDB.profile = {}
    end

    -- Initialize unitframes in profile if not exists
    if not NihuiUFDB.profile.unitframes then
        NihuiUFDB.profile.unitframes = {}
    end

    -- Ensure all units exist with default values
    for unitType, defaultConfig in pairs(ns.Config.Defaults.unitframes) do
        if not NihuiUFDB.profile.unitframes[unitType] then
            NihuiUFDB.profile.unitframes[unitType] = ns.Utils.DeepCopy(defaultConfig)
        else
            -- Merge any missing default values for addon updates (MUST CAPTURE RETURN VALUE!)
            NihuiUFDB.profile.unitframes[unitType] = ns.Utils.MergeTables(NihuiUFDB.profile.unitframes[unitType], defaultConfig)
        end
    end

    -- Initialize XP bar configuration
    if not NihuiUFDB.profile.xp and ns.Config.Defaults.xp then
        NihuiUFDB.profile.xp = ns.Utils.DeepCopy(ns.Config.Defaults.xp)
    elseif ns.Config.Defaults.xp then
        NihuiUFDB.profile.xp = ns.Utils.MergeTables(NihuiUFDB.profile.xp, ns.Config.Defaults.xp)
    end

    -- Initialize Reputation bar configuration
    if not NihuiUFDB.profile.reputation and ns.Config.Defaults.reputation then
        NihuiUFDB.profile.reputation = ns.Utils.DeepCopy(ns.Config.Defaults.reputation)
    elseif ns.Config.Defaults.reputation then
        NihuiUFDB.profile.reputation = ns.Utils.MergeTables(NihuiUFDB.profile.reputation, ns.Config.Defaults.reputation)
    end

    -- ===========================
    -- MIGRATION: Raid fitParent system (v4.1+)
    -- ===========================
    if NihuiUFDB.profile.unitframes.raid then
        local raidConfig = NihuiUFDB.profile.unitframes.raid

        -- If old config has width/height but no fitParent, migrate to fitParent mode
        if raidConfig.health and raidConfig.health.width and not raidConfig.health.fitParent then
            print("Nihui_uf: Migrating raid config to fitParent mode...")

            -- Remove old width/height
            raidConfig.health.width = nil
            raidConfig.health.height = nil

            -- Add new fitParent properties
            raidConfig.health.fitParent = true
            raidConfig.health.fillPercent = 0.95

            -- Remove old layout section (gaps are now handled by Blizzard Edit Mode)
            if raidConfig.layout then
                raidConfig.layout = nil
            end

            print("Nihui_uf: Raid migration complete - fitParent enabled!")
        end
    end

end

-- ===========================
-- CORE API FUNCTIONS
-- ===========================

-- Get value from database using path notation
-- Examples: ns.DB.Get("unitframes.player.health.width") → 200
--          ns.DB.Get("unitframes.target.portrait.enabled") → true
function ns.DB.Get(path)
    if not path or path == "" then
        return nil
    end

    local keys = {strsplit(".", path)}
    local value = NihuiUFDB.profile

    for _, key in ipairs(keys) do
        if value and type(value) == "table" then
            value = value[key]
        else
            -- Value not found in DB, get from defaults
            return ns.Config.GetDefault(path)
        end
    end

    return value
end

-- Set value in database using path notation
-- Examples: ns.DB.Set("unitframes.player.health.width", 250)
--          ns.DB.Set("unitframes.target.portrait.enabled", false)
function ns.DB.Set(path, newValue)
    if not path or path == "" then
        return false
    end

    -- Ensure database is initialized
    if not NihuiUFDB or not NihuiUFDB.profile then
        ns.DB.Initialize()
    end

    local keys = {strsplit(".", path)}
    local current = NihuiUFDB.profile

    -- Navigate to parent container
    for i = 1, #keys - 1 do
        local key = keys[i]
        if not current[key] then
            current[key] = {}
        end
        current = current[key]
    end

    -- Set the final value
    local finalKey = keys[#keys]
    local oldValue = current[finalKey]
    current[finalKey] = newValue

    -- Trigger change notification
    ns.DB.NotifyChange(path, oldValue, newValue)

    return true
end

-- Get value with guaranteed fallback to defaults
function ns.DB.GetWithFallback(path)
    local value = ns.DB.Get(path)
    if value ~= nil then
        return value
    end

    -- Fallback to defaults
    return ns.Config.GetDefault(path)
end

-- ===========================
-- UNIT-SPECIFIC SHORTCUTS
-- ===========================

-- Get entire unit configuration
-- Example: ns.DB.GetUnitConfig("player") → { health = {...}, power = {...}, ... }
function ns.DB.GetUnitConfig(unit)
    return ns.DB.Get("unitframes." .. unit)
end

-- Set unit configuration
function ns.DB.SetUnitConfig(unit, config)
    return ns.DB.Set("unitframes." .. unit, config)
end

-- Get specific unit setting
-- Example: ns.DB.GetUnitSetting("player", "health", "width") → 200
function ns.DB.GetUnitSetting(unit, ...)
    local path = "unitframes." .. unit
    local args = {...}

    for _, key in ipairs(args) do
        path = path .. "." .. key
    end

    return ns.DB.Get(path)
end

-- Set specific unit setting
-- Example: ns.DB.SetUnitSetting("player", "health", "width", 250)
function ns.DB.SetUnitSetting(unit, ...)
    local args = {...}
    local value = args[#args] -- Last argument is the value
    local path = "unitframes." .. unit

    -- Build path from arguments (excluding the last one which is the value)
    for i = 1, #args - 1 do
        path = path .. "." .. args[i]
    end

    return ns.DB.Set(path, value)
end

-- ===========================
-- CHANGE NOTIFICATION SYSTEM
-- ===========================

local changeCallbacks = {}

-- Register callback for configuration changes
function ns.DB.RegisterChangeCallback(path, callback)
    if not changeCallbacks[path] then
        changeCallbacks[path] = {}
    end
    table.insert(changeCallbacks[path], callback)
end

-- Notify systems of configuration changes
function ns.DB.NotifyChange(path, oldValue, newValue)
    -- Debug disabled to prevent spam

    -- Exact path callbacks
    if changeCallbacks[path] then
        for _, callback in ipairs(changeCallbacks[path]) do
            pcall(callback, path, oldValue, newValue)
        end
    end

    -- Wildcard callbacks (e.g., "unitframes.player.*")
    for callbackPath, callbacks in pairs(changeCallbacks) do
        if callbackPath:find("*") and path:match("^" .. callbackPath:gsub("%*", ".*") .. "$") then
            for _, callback in ipairs(callbacks) do
                pcall(callback, path, oldValue, newValue)
            end
        end
    end

    -- Trigger refresh if it's a unit configuration change
    local unitMatch = path:match("^unitframes%.([^%.]+)")
    if unitMatch then
        ns.DB.RefreshUnit(unitMatch, path)
    end
end

-- ===========================
-- UNIT REFRESH SYSTEM
-- ===========================

-- Refresh unit when configuration changes
function ns.DB.RefreshUnit(unit, changedPath)

    -- Try new API system first (force call to global ns.GetActiveModuleNew)
    if ns.GetActiveModuleNew then
        local module = ns.GetActiveModuleNew(unit)
        if module then
            if module.RefreshFrames then
                module:RefreshFrames()
                return
            elseif module.UpdateConfig then
                module:UpdateConfig()
                return
            end
        end
    end

    -- Fallback to old system
    local activeModules = ns.activeModules
    if not activeModules or not activeModules[unit] then
        return
    end

    local module = activeModules[unit]
    local newConfig = ns.DB.GetUnitConfig(unit)

    -- Update module's config reference
    module.config = newConfig


    -- Determine what type of refresh is needed based on the changed path
    -- Check text first (more specific paths like "text.health.size")
    if changedPath:match("%.text%.") then
        -- DEBUG: Show what changed

        -- Text-related change
        if module.textSystem then
            -- Update text system config first
            module.textSystem.config = newConfig.text

            -- Apply font/size changes directly to FontString elements
            local needsRepositioning = false
            if module.textSystem.elements then
                for elementType, element in pairs(module.textSystem.elements) do
                    local elementConfig = newConfig.text[elementType]
                    if element and elementConfig then
                        -- Update font properties
                        if element.SetFont and elementConfig.font and elementConfig.size and elementConfig.outline then
                            local fontPath = elementConfig.font or "Fonts\\FRIZQT__.TTF"
                            local fontSize = elementConfig.size or 12
                            local outline = elementConfig.outline or "OUTLINE"

                            element:SetFont(fontPath, fontSize, outline)

                            -- Font/size changes for name/level require repositioning
                            if elementType == "name" or elementType == "level" then
                                needsRepositioning = true
                            end
                        end

                        -- Update color
                        if element.SetTextColor and elementConfig.color then
                            local r, g, b, a = unpack(elementConfig.color)
                            element:SetTextColor(r or 1, g or 1, b or 1, a or 1)
                        end

                        -- Update visibility (will be handled by UpdateNameLevelIntelligent)
                        -- Note: No direct show/hide here - let the intelligent system handle it
                    end
                end
            end

            -- ALWAYS trigger repositioning for name/level changes OR if font/size changed
            if module.textSystem.nameLevelContainer and (needsRepositioning or changedPath:match("%.nameLevel%.") or changedPath:match("%.name%.") or changedPath:match("%.level%.")) then
                -- Update container position for offset changes
                if changedPath:match("%.containerOffset%.") and module.textSystem.UpdateContainerPosition then
                    module.textSystem:UpdateContainerPosition()
                end

                -- Update container width when health bar width changes
                if module.healthSystem and module.healthSystem.bar then
                    module.textSystem.nameLevelContainer:SetWidth(module.healthSystem.bar:GetWidth())
                end

                -- ALWAYS call intelligent positioning to handle font/size changes
                if module.textSystem.UpdateNameLevelIntelligent then
                    module.textSystem:UpdateNameLevelIntelligent()
                end
            end

            -- NOTE: UpdateAllTexts removed - using intelligent system only
        end

    elseif changedPath:match("%.health%.") then
        -- Health BAR change (not text)
        if module.healthSystem and module.healthSystem.bar then

            -- Update bar size immediately
            if changedPath:match("%.width$") then
                module.healthSystem.bar:SetWidth(newConfig.health.width)
            elseif changedPath:match("%.height$") then
                module.healthSystem.bar:SetHeight(newConfig.health.height)
            end

            -- Update glass effect
            if changedPath:match("%.glassEnabled$") or changedPath:match("%.glassAlpha$") then
                if module.healthSystem.barSet and module.healthSystem.barSet.glass then
                    if newConfig.health.glassEnabled then
                        module.healthSystem.barSet.glass:Show()
                        module.healthSystem.barSet.glass:SetAlpha(newConfig.health.glassAlpha or 0.2)
                    else
                        module.healthSystem.barSet.glass:Hide()
                    end
                end
            end

            -- Force health update to apply new settings
            if module.healthSystem.UpdateHealth then
                module.healthSystem:UpdateHealth()
            end
        end

    elseif changedPath:match("%.power%.") then
        -- Power-related change
        if module.powerSystem and module.powerSystem.bar then

            -- Update bar size immediately
            if changedPath:match("%.width$") then
                module.powerSystem.bar:SetWidth(newConfig.power.width)
            elseif changedPath:match("%.height$") then
                module.powerSystem.bar:SetHeight(newConfig.power.height)
            end

            -- Update position
            if changedPath:match("%.xOffset$") or changedPath:match("%.yOffset$") then
                module.powerSystem.bar:ClearAllPoints()
                module.powerSystem.bar:SetPoint("TOP", module.healthSystem.bar, "BOTTOM",
                    newConfig.power.xOffset or 0, newConfig.power.yOffset or -10)
            end

            -- Force power update
            if module.powerSystem.UpdatePower then
                module.powerSystem:UpdatePower()
            end
        end

    elseif changedPath:match("%.portrait%.") then
        -- Portrait-related change (includes states, classification, etc.)
        if module.portraitSystem then
            -- UpdateConfig already calls UpdatePortrait internally
            if module.portraitSystem.UpdateConfig then
                module.portraitSystem:UpdateConfig(newConfig.portrait)
            elseif module.portraitSystem.UpdatePortrait then
                module.portraitSystem:UpdatePortrait()
            end
        end

    elseif changedPath:match("%.classpower%.") then
        -- Class power change (player only)
        if module.classPowerSystem then
            -- Update class power system with new config
            if module.classPowerSystem.UpdateConfig then
                module.classPowerSystem:UpdateConfig(newConfig.classpower)
            end
        end
    else
        -- Full refresh for unknown changes
    end
end

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================

-- Deep copy function for tables
function ns.DB.DeepCopy(original)
    if type(original) ~= "table" then
        return original
    end

    local copy = {}
    for key, value in pairs(original) do
        copy[key] = ns.DB.DeepCopy(value)
    end

    return copy
end

-- Merge default values into existing configuration (for addon updates)
function ns.DB.MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if not target[key] or type(target[key]) ~= "table" then
                target[key] = {}
            end
            ns.DB.MergeDefaults(target[key], value)
        else
            if target[key] == nil then
                target[key] = value
            end
        end
    end
end

-- Get list of available units
function ns.DB.GetAvailableUnits()
    local units = {}
    if NihuiUFDB and NihuiUFDB.profile and NihuiUFDB.profile.unitframes then
        for unit, _ in pairs(NihuiUFDB.profile.unitframes) do
            table.insert(units, unit)
        end
    end
    return table.concat(units, ", ")
end

-- Reset unit to defaults
function ns.DB.ResetUnit(unit)
    if not ns.Config.Defaults.unitframes[unit] then
        return false
    end

    -- Replace with fresh copy of defaults
    NihuiUFDB.profile.unitframes[unit] = ns.DB.DeepCopy(ns.Config.Defaults.unitframes[unit])

    -- Trigger full refresh
    ns.DB.RefreshUnit(unit, "unitframes." .. unit)

    return true
end

-- Export unit configuration as string
function ns.DB.ExportUnit(unit)
    local config = ns.DB.GetUnitConfig(unit)
    if not config then
        return nil
    end

    -- Simple serialization (could be enhanced with compression)
    return ns.DB.SerializeTable(config)
end

-- Simple table serialization
function ns.DB.SerializeTable(t, indent)
    indent = indent or 0
    local result = "{\n"

    for k, v in pairs(t) do
        local spacing = string.rep("  ", indent + 1)

        if type(k) == "string" then
            result = result .. spacing .. k .. " = "
        else
            result = result .. spacing .. "[" .. tostring(k) .. "] = "
        end

        if type(v) == "table" then
            result = result .. ns.DB.SerializeTable(v, indent + 1)
        elseif type(v) == "string" then
            result = result .. '"' .. v .. '"'
        else
            result = result .. tostring(v)
        end

        result = result .. ",\n"
    end

    result = result .. string.rep("  ", indent) .. "}"
    return result
end

-- ===========================
-- VALIDATION SYSTEM
-- ===========================

-- Validate that a value matches expected type from defaults
function ns.DB.ValidateValue(path, value)
    local defaultValue = ns.Config.GetDefault(path)
    if defaultValue == nil then
        return false, "Path not found in defaults: " .. path
    end

    local expectedType = type(defaultValue)
    local actualType = type(value)

    if expectedType ~= actualType then
        return false, string.format("Type mismatch for %s: expected %s, got %s", path, expectedType, actualType)
    end

    return true
end

-- Safe set with validation
function ns.DB.SafeSet(path, value)
    local valid, error = ns.DB.ValidateValue(path, value)
    if not valid then
        return false
    end

    return ns.DB.Set(path, value)
end

-- ===========================
-- GLOBAL REFRESH SYSTEM
-- ===========================

-- Force refresh all unitframes (useful when defaults change)
function ns.DB.RefreshAll()

    local availableUnits = {"player", "target", "focus", "pet", "targettarget", "focustarget", "party"}

    for _, unit in ipairs(availableUnits) do
        ns.DB.RefreshUnit(unit, "full_refresh")
    end

    -- Also refresh portrait system globally
    if ns.Systems and ns.Systems.Portrait and ns.Systems.Portrait.RefreshAllPortraits then
        ns.Systems.Portrait.RefreshAllPortraits()
    end

end

-- ===========================
-- SLASH COMMANDS FOR TESTING
-- ===========================

-- Slash command for refreshing all frames
SLASH_REFRESHFRAMES1 = "/refreshframes"
SLASH_REFRESHFRAMES2 = "/rf"

SlashCmdList["REFRESHFRAMES"] = function()
    ns.DB.RefreshAll()
end

-- ===========================
-- PROFILE MANAGEMENT
-- ===========================

local currentProfile = "Default"
local profiles = {}

-- Get all available profiles
function ns.DB.GetProfiles()
    if not NihuiUFDB.profiles then
        NihuiUFDB.profiles = {}
    end

    local profileList = {}
    profileList["Default"] = "Default"

    for profileName, _ in pairs(NihuiUFDB.profiles) do
        profileList[profileName] = profileName
    end

    return profileList
end

-- Get current profile name
function ns.DB.GetCurrentProfile()
    return currentProfile
end

-- Create new profile with current settings
function ns.DB.CreateProfile(profileName)
    if not profileName or profileName == "" or profileName == "Default" then
        return false
    end

    if not NihuiUFDB.profiles then
        NihuiUFDB.profiles = {}
    end

    -- Copy current settings
    NihuiUFDB.profiles[profileName] = ns.Utils.DeepCopy(NihuiUFDB.profile)

    return true
end

-- Switch to a different profile
function ns.DB.SetProfile(profileName)
    if not profileName then
        return false
    end

    if profileName == "Default" then
        -- Switch to default profile
        currentProfile = "Default"
        ns.DB.Initialize() -- Reload defaults
        return true
    end

    if not NihuiUFDB.profiles or not NihuiUFDB.profiles[profileName] then
        return false
    end

    -- Save current profile if it's not default
    if currentProfile ~= "Default" then
        if not NihuiUFDB.profiles then
            NihuiUFDB.profiles = {}
        end
        NihuiUFDB.profiles[currentProfile] = ns.Utils.DeepCopy(NihuiUFDB.profile)
    end

    -- Load new profile
    NihuiUFDB.profile = ns.Utils.DeepCopy(NihuiUFDB.profiles[profileName])
    currentProfile = profileName

    return true
end

-- Delete a profile
function ns.DB.DeleteProfile(profileName)
    if not profileName or profileName == "" or profileName == "Default" then
        return false
    end

    if not NihuiUFDB.profiles or not NihuiUFDB.profiles[profileName] then
        return false
    end

    NihuiUFDB.profiles[profileName] = nil

    -- If we're deleting the current profile, switch to default
    if currentProfile == profileName then
        currentProfile = "Default"
        ns.DB.Initialize()
    end

    return true
end

-- ===========================
-- IMPORT/EXPORT FUNCTIONS
-- ===========================

-- Get all configuration data
function ns.DB.GetAll()
    return ns.Utils.DeepCopy(NihuiUFDB.profile)
end

-- Set all configuration data
function ns.DB.SetAll(config)
    if type(config) ~= "table" then
        return false
    end

    NihuiUFDB.profile = ns.Utils.DeepCopy(config)
    return true
end

-- Reset database to defaults
function ns.DB.ResetToDefaults()
    -- Clear current profile
    NihuiUFDB.profile = {}

    -- Reinitialize with defaults
    ns.DB.Initialize()

    return true
end


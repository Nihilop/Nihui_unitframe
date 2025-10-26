-- init.lua - Nihui_uf Modular Architecture System
local _, ns = ...

-- Temporary error handler to catch interface action errors
local originalErrorHandler = GetCVar("scriptErrors")
local function CustomErrorHandler(msg)
    if msg and msg:find("interface") and msg:find("action") then
        print("|cffff0000Nihui_uf Error:|r", msg)
    end
end

-- Hook into error system temporarily
if not ns._errorHandlerInstalled then
    seterrorhandler(CustomErrorHandler)
    ns._errorHandlerInstalled = true
end

-- ===========================
-- ADDON INITIALIZATION
-- ===========================

local NihuiUF = CreateFrame("Frame")
NihuiUF:RegisterEvent("ADDON_LOADED")
NihuiUF:RegisterEvent("PLAYER_LOGIN")

-- Store active modules
local activeModules = {}
ns.activeModules = activeModules

-- Function to get active module (used by config system)
-- GetActiveModuleNew defined later with better unitType handling

-- Initialization state
local initState = {
    coreLoaded = false,
    playerReady = false,
    targetReady = false,
    focusReady = false,
    systemsInitialized = false
}

-- ===========================
-- CORE SYSTEM INITIALIZATION
-- ===========================

-- Initialize core systems (stripping, lifecycle)
local function InitializeCoreSystems()
    if initState.coreLoaded then
        return true
    end

    -- Initializing core systems...

    -- Initialize global stripping system (CRITICAL FIRST)
    if ns.Core and ns.Core.Stripping then
        local strippedCount = ns.Core.Stripping.Initialize()
    else
    end

    -- Register core components with lifecycle
    if ns.Core.Lifecycle then
    end

    initState.coreLoaded = true
    return true
end

-- ===========================
-- MODULE SETUP
-- ===========================

-- Setup all available modules dynamically
local function SetupModules()
    -- Define modules to initialize with their availability checks
    local modulesToSetup = {
        {
            name = "player",
            module = ns.Modules.Player,
            available = function()
                return PlayerFrame ~= nil -- Remove API dependency since it loads after
            end,
            priority = 1
        },
        {
            name = "target",
            module = ns.Modules.Target,
            available = function()
                return TargetFrame ~= nil
            end,
            priority = 2
        },
        {
            name = "focus",
            module = ns.Modules.Focus,
            available = function()
                return FocusFrame ~= nil
            end,
            priority = 3
        },
        {
            name = "pet",
            module = ns.Modules.Pet,
            available = function()
                -- Always available - frames created on-demand if needed
                return true
            end,
            priority = 4
        },
        {
            name = "targettarget",
            module = ns.Modules.TargetTarget,
            available = function()
                -- Always available - frames created on-demand if needed
                return true
            end,
            priority = 5
        },
        {
            name = "focustarget",
            module = ns.Modules.FocusTarget,
            available = function()
                -- Always available - frames created on-demand if needed
                return true
            end,
            priority = 6
        },
        {
            name = "party",
            module = ns.Modules.Party,
            available = function()
                return true -- Party handles its own visibility and frame creation
            end,
            priority = 7
        },
        {
            name = "boss",
            module = ns.Modules.Boss,
            available = function()
                return true -- Boss handles its own visibility and frame creation
            end,
            priority = 9
        },
        {
            name = "arena",
            module = ns.Modules.Arena,
            available = function()
                return true -- Arena handles its own visibility and frame creation
            end,
            priority = 10
        }
    }

    -- Sort by priority (optional, but good practice)
    table.sort(modulesToSetup, function(a, b) return a.priority < b.priority end)

    local setupCount = 0
    local availableModules = {}

    -- Setup each module
    for _, moduleInfo in ipairs(modulesToSetup) do
        local moduleName = moduleInfo.name
        local moduleClass = moduleInfo.module

        -- Check if module class exists
        if not moduleClass or not moduleClass.Setup then
        else
            -- Check if the corresponding frame is available
            if moduleInfo.available() then
                -- Setup module
                local moduleInstance = moduleClass.Setup()

                if moduleInstance then
                    -- Initialize the module with error handling
                    local success, err = pcall(function()
                        moduleInstance:Initialize()
                    end)

                    if not success then
                        print("Nihui_uf: Failed to initialize", moduleName, "-", err)
                    else
                        -- Store reference
                        activeModules[moduleName] = moduleInstance
                        table.insert(availableModules, moduleName)
                        setupCount = setupCount + 1
                    end
                end
            end
        end
    end

    return setupCount > 0
end


-- ===========================
-- API INTEGRATION HOOK
-- ===========================

-- Setup GetActiveModuleNew hook for API integration
local function SetupAPIHook()

    -- Create the function if it doesn't exist
    if not ns.GetActiveModuleNew then
        ns.GetActiveModuleNew = function() return nil end
    end

    local originalGetActiveModuleNew = ns.GetActiveModuleNew
    ns.GetActiveModuleNew = function(unitType)

        -- Always try to get the actual module first if available
        -- Try the lowercase unitType directly (matches how modules are stored in activeModules)
        local moduleKey = unitType:lower()

        if activeModules[moduleKey] then
            return activeModules[moduleKey]
        end

        -- Check if API is available for fallback
        if not (ns.API and ns.API.UnitFrame) then
            return nil
        end

        -- Try API refresh system as fallback
        if ns.API.UnitFrame.RefreshUnit then
            local success = ns.API.UnitFrame.RefreshUnit(unitType)
            if success then
                return {
                    RefreshFrames = function()
                        ns.API.UnitFrame.RefreshUnit(unitType)
                    end
                }
            end
        end

        return nil
    end
end

-- ===========================
-- MAIN INITIALIZATION
-- ===========================

-- Main initialization function
local function InitializeAddon()
    if initState.systemsInitialized then
        return
    end


    -- Step 0: Setup API hook BEFORE database/config systems
    SetupAPIHook()

    -- Step 1: Initialize database system FIRST
    if ns.DB and ns.DB.Initialize then
        ns.DB.Initialize()
    else
        return
    end

    -- Step 1.5: Register custom textures with LibSharedMedia
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        LSM:Register("statusbar", "g1", "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga")
        LSM:Register("statusbar", "HPglass", "Interface\\AddOns\\Nihui_uf\\textures\\HPglass.tga")
        LSM:Register("statusbar", "HPglassADD", "Interface\\AddOns\\Nihui_uf\\textures\\HPglassADD.tga")
        LSM:Register("statusbar", "HPDHD", "Interface\\AddOns\\Nihui_uf\\textures\\HPDHD.tga")
    end

    -- Step 2: Initialize core systems
    if not InitializeCoreSystems() then
        return
    end

    -- Step 2.5: Initialize XP/Rep bars (separate from unit modules)
    if ns.Modules and ns.Modules.XP and ns.Modules.XP.Initialize then
        local success, err = pcall(ns.Modules.XP.Initialize)
        if not success then
            print("|cffff0000Nihui_uf XP/Rep Error:|r " .. tostring(err))
        end
    end

    -- Step 3: Setup modules (now they can access ns.DB)
    if not SetupModules() then
        return
    end

    -- Step 4: Re-sync config with loaded modules
    if ns.Config and ns.Config.ResyncWithModules then
        ns.Config.ResyncWithModules()
    end

    -- Step 5: Initialize configuration panel
    if ns.Config and ns.Config.Panel and ns.Config.Panel.Initialize then
        ns.Config.Panel.Initialize()
    end

    initState.systemsInitialized = true

    -- Show status (dynamic based on actual loaded modules)
    local loadedModules = {}
    for moduleName, _ in pairs(activeModules) do
        table.insert(loadedModules, moduleName)
    end

    -- Debug info
    if ns.Core and ns.Core.Lifecycle then
        local stats = ns.Core.Lifecycle.GetStats()
    end
end

-- ===========================
-- EVENT HANDLING
-- ===========================

NihuiUF:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "Nihui_uf" then

        -- Give a small delay to ensure all files are loaded
        C_Timer.After(1.0, function()
            InitializeAddon()
        end)

    elseif event == "PLAYER_LOGIN" then
        initState.playerReady = true

        -- Try initialization if not done yet
        C_Timer.After(1.5, function()
            InitializeAddon()
        end)
    end
end)

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================

-- Get active module
function ns.GetActiveModuleNew(unitType)
    return activeModules[unitType:lower()]
end

-- Update all systems without reload (preferred method)
function ns.UpdateAllSystems()
    local updateFailures = 0
    local totalModules = 0

    -- Update XP/Rep bars first (separate from unit modules)
    if ns.Modules and ns.Modules.XP and ns.Modules.XP.UpdateConfig then
        local success, err = pcall(ns.Modules.XP.UpdateConfig)
        if not success then
            updateFailures = updateFailures + 1
            print("Nihui UF: Failed to update XP/Rep bars - " .. (err or "unknown error"))
        end
        totalModules = totalModules + 1
    end

    -- Update all active modules using their UpdateConfig methods
    for unitType, module in pairs(activeModules) do
        totalModules = totalModules + 1
        if module then
            -- Try UpdateConfig first (live update)
            if module.UpdateConfig then
                local success, err = pcall(module.UpdateConfig, module)
                if not success then
                    updateFailures = updateFailures + 1
                    print("Nihui UF: Failed to update " .. unitType .. " - " .. (err or "unknown error"))
                end
            -- Fallback to Update if available
            elseif module.Update then
                local success, err = pcall(module.Update, module)
                if not success then
                    updateFailures = updateFailures + 1
                    print("Nihui UF: Failed to update " .. unitType .. " - " .. (err or "unknown error"))
                end
            else
                -- Module has no update method, consider it a failure
                updateFailures = updateFailures + 1
            end
        end
    end

    if updateFailures > 0 then
        print("Nihui UF: Updated " .. (totalModules - updateFailures) .. "/" .. totalModules .. " systems. Some modules may need a reload.")
        return false -- Indicate partial failure
    else
        print("Nihui UF: All systems updated successfully")
        return true
    end
end

-- Smart update: tries UpdateAllSystems first, falls back to reload if needed
function ns.SmartUpdate()
    local success = ns.UpdateAllSystems()
    if not success then
        print("Nihui UF: Live update failed, performing full reload...")
        C_Timer.After(0.5, function()
            ns.ReloadNewSystem()
        end)
    end
end

-- Reload addon (for testing or when UpdateAllSystems fails)
function ns.ReloadNewSystem()

    -- Destroy XP/Rep bars first (separate from unit modules)
    if ns.Modules and ns.Modules.XP and ns.Modules.XP.Destroy then
        local success, err = pcall(ns.Modules.XP.Destroy)
        if not success then
            print("Nihui UF: Failed to destroy XP/Rep bars - " .. (err or "unknown error"))
        end
    end

    -- Destroy all active modules
    for unitType, module in pairs(activeModules) do
        if module and module.Destroy then
            local success, err = pcall(module.Destroy, module)
            if success then
            else
            end
        end
    end

    -- Clear state
    activeModules = {}
    initState.systemsInitialized = false

    -- Reinitialize
    C_Timer.After(0.5, function()
        InitializeAddon()
    end)
end

-- Get initialization status
function ns.GetNewInitStatus()
    return {
        coreLoaded = initState.coreLoaded,
        playerReady = initState.playerReady,
        targetReady = initState.targetReady,
        focusReady = initState.focusReady,
        systemsInitialized = initState.systemsInitialized,
        activeModules = activeModules
    }
end

-- ===========================
-- SLASH COMMANDS (for testing)
-- ===========================

SLASH_NIHUIUF1 = "/nuf"
SLASH_NIHUIUF2 = "/nihuiuf"

SlashCmdList["NIHUIUF"] = function(msg)
    local args = {strsplit(" ", msg)}
    local cmd = args[1] and args[1]:lower() or ""

    if cmd == "init" then
        InitializeAddon()

    elseif cmd == "reload" then
        ns.ReloadNewSystem()

    elseif cmd == "status" then
        local status = ns.GetNewInitStatus()

        local moduleCount = 0
        for _ in pairs(status.activeModules) do
            moduleCount = moduleCount + 1
        end

        -- Check namespace

    elseif cmd == "debug" then

        -- Check what party frames exist
        for i = 1, 5 do
            local frame = _G["CompactPartyFrameMember" .. i]
            if frame then

                -- Check if our module is applied to this frame
                local partyModule = ns.GetActiveModuleNew("party")
                if partyModule and partyModule.partyFrames and partyModule.partyFrames[i] then
                    local memberFrame = partyModule.partyFrames[i]

                    if memberFrame.healthSystem and memberFrame.healthSystem.bar then
                        local hbar = memberFrame.healthSystem.bar
                    end

                    if memberFrame.powerSystem and memberFrame.powerSystem.bar then
                        local pbar = memberFrame.powerSystem.bar
                    end
                else
                end
            end
        end

        -- Check CompactPartyFrame
        local compactParty = _G["CompactPartyFrame"]
        if compactParty then
            if compactParty.member then
                for i = 1, 5 do
                    local member = compactParty.member[i]
                end
            end
        end

    elseif cmd == "test" then

        -- Test database
        if ns.DB then
            local playerConfig = ns.DB.GetUnitConfig("player")
            if playerConfig then
            end
        else
        end

        -- Test stripping (via Core)
        if ns.Core and ns.Core.Stripping then
            if PlayerFrame then
                local stripped = ns.Core.Stripping.StripPlayer()
            end
        else
        end

        -- Test player module
        local playerModule = ns.GetActiveModuleNew("player")
        if playerModule then
        else
        end

    elseif cmd == "config" and (not args[2] or args[2] == "") then
        -- Open AceConfig standalone window
        if ns.Config and ns.Config.Panel and ns.Config.Panel.Show then
            ns.Config.Panel.Show()
        else
            print("Config panel not available")
        end

    elseif cmd == "config" then
        local unit = args[2] or "player"
        local setting = args[3]
        local value = args[4]

        if setting and value then
            -- Set configuration
            local path = "unitframes." .. unit .. "." .. setting
            local success = ns.DB.Set(path, tonumber(value) or value)
        elseif setting then
            -- Get configuration
            local path = "unitframes." .. unit .. "." .. setting
            local value = ns.DB.Get(path)
        else
            -- Show unit config
            local config = ns.DB.GetUnitConfig(unit)
            if config then
            else
            end
        end

    elseif cmd == "texttest" then
        -- Test text system directly
        local playerModule = ns.GetActiveModuleNew("player")
        if playerModule and playerModule.textSystem then

            if playerModule.textSystem.elements then
                for name, element in pairs(playerModule.textSystem.elements) do
                    if element and element.SetFont then
                    end
                end
            end

            if playerModule.textSystem.config then
                if playerModule.textSystem.config.health then
                end
            end

            -- Try manual update
            if playerModule.textSystem.UpdateAllTexts then
                playerModule.textSystem:UpdateAllTexts()
            else
            end
        else
        end

    elseif cmd == "clearcache" or cmd == "cc" then
        -- Force refresh power text colors without full reload
        print("Nihui UF: Refreshing power text colors...")
        local updated = 0

        for unitType, module in pairs(activeModules) do
            if module and module.powerSystem and module.powerSystem.text then
                -- Force update power text by calling UpdateValue if it exists
                local powerText = module.powerSystem.text
                if powerText.UpdateValue then
                    -- Trigger a manual update to apply new color logic
                    local unit = module.unit or unitType
                    local powerType = UnitPowerType(unit)
                    local current = UnitPower(unit)
                    local max = UnitPowerMax(unit)
                    powerText:UpdateValue(current, max, powerType)
                    updated = updated + 1
                end
            end
        end

        print("Nihui UF: Updated " .. updated .. " power text elements")

    else
    end
end

-- New modular system loaded, waiting for events...
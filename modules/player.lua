-- modules/player_new.lua - Player Module using Unified API (POC)
local _, ns = ...

-- Module namespace
ns.Modules = ns.Modules or {}
ns.Modules.Player = {}

-- ===========================
-- PLAYER MODULE (NEW API)
-- ===========================

local playerModule = {
    unitFrame = nil,
    initialized = false
}

-- Initialize player module
function playerModule:Initialize()
    if self.initialized then
        return
    end


    -- Wait for API if not available yet
    if not (ns.API and ns.API.UnitFrame and ns.API.UnitFrame.Create) then
        -- Retry after a short delay
        C_Timer.After(0.1, function()
            self:Initialize()
        end)
        return
    end

    -- Create complete player unitframe in ONE LINE using API
    self.unitFrame = ns.API.UnitFrame.Create(PlayerFrame, "player")


    if not self.unitFrame then
        return
    end

    -- API already handles initialization - no need to call Initialize

    -- Create class power system if enabled and applicable (player-specific)
    local config = ns.DB.GetUnitConfig("player")
    if config and config.classpower and config.classpower.enabled and ns.Systems.ClassPower and ns.Systems.ClassPower.IsDiscreteClass and ns.Systems.ClassPower.IsDiscreteClass() then
        self.classPowerSystem = ns.Systems.ClassPower.Create(self.unitFrame.powerSystem.bar, config.classpower)
        if self.classPowerSystem then
            self.classPowerSystem:Initialize()
        end
    end


    self.initialized = true
end

-- Dragging functionality removed - using Blizzard Edit Mode instead

-- Update player frame
function playerModule:Update()
    if not self.initialized or not self.unitFrame then return end

    -- Update all systems individually
    if self.unitFrame.healthSystem then
        self.unitFrame.healthSystem:UpdateHealth()
    end
    if self.unitFrame.powerSystem then
        self.unitFrame.powerSystem:UpdatePower()
    end
    if self.unitFrame.textSystem then
        self.unitFrame.textSystem:UpdateAll()
    end
    if self.unitFrame.portraitSystem then
        self.unitFrame.portraitSystem:UpdatePortrait()
    end
    if self.classPowerSystem then
        -- Get current config and call UpdateConfig like other systems
        local unitConfig = ns.DB.GetUnitConfig("player")
        if unitConfig and unitConfig.classpower then
            self.classPowerSystem:UpdateConfig(unitConfig.classpower)
        end
    end
end

-- Show/hide player frame
function playerModule:SetVisible(visible)
    if not self.unitFrame or not self.unitFrame.frame then return end

    if visible then
        self.unitFrame.frame:Show()
    else
        self.unitFrame.frame:Hide()
    end
end

-- Cleanup
function playerModule:Destroy()
    if self.classPowerSystem then
        self.classPowerSystem:Destroy()
        self.classPowerSystem = nil
    end
    if self.unitFrame then
        self.unitFrame:Destroy()
        self.unitFrame = nil
    end
    self.initialized = false
end

-- Get current unitframe
function playerModule:GetUnitFrame()
    return self.unitFrame
end

-- Update configuration (called by global update system)
function playerModule:UpdateConfig()
    if not self.initialized or not self.unitFrame then
        return
    end

    -- Use the UpdateConfig method for real-time updates
    if self.unitFrame.UpdateConfig then
        self.unitFrame:UpdateConfig()
    else
        -- Fallback to Update if UpdateConfig not available
        self:Update()
    end
end

-- Refresh frames (called by config system) - alias for UpdateConfig
function playerModule:RefreshFrames()
    self:UpdateConfig()
end

-- ===========================
-- MODULE INTERFACE
-- ===========================

-- Setup method for lifecycle compatibility
-- Player has special setup for ClassPower
ns.Modules.Player.Setup = ns.CreateModuleSetup(playerModule, function(customConfig)
    -- Any player-specific setup logic could go here
end)

-- Public API
ns.Modules.Player.Initialize = function()
    return playerModule:Initialize()
end

ns.Modules.Player.Update = function()
    return playerModule:Update()
end

ns.Modules.Player.SetVisible = function(visible)
    return playerModule:SetVisible(visible)
end

ns.Modules.Player.Destroy = function()
    return playerModule:Destroy()
end

ns.Modules.Player.GetUnitFrame = function()
    return playerModule:GetUnitFrame()
end

-- EnableDragging removed - using Blizzard Edit Mode

ns.Modules.Player.RefreshFrames = function()
    return playerModule:RefreshFrames()
end

-- ===========================
-- CONFIGURATION HOOKS
-- ===========================

-- Handle configuration changes
local function OnConfigChanged(configPath, oldValue, newValue)

    if not playerModule.initialized or not playerModule.unitFrame then
        return
    end

    if configPath:find("player") then
        -- Use new UpdateConfig method for real-time updates
        if playerModule.unitFrame.UpdateConfig then
            playerModule.unitFrame:UpdateConfig()
        else
            playerModule:Update()
        end
    end
end

-- Config changes handled by config panel refresh system instead of callbacks
-- to avoid double refresh and flooding
-- if ns.DB and ns.DB.RegisterChangeCallback then
--     ns.DB.RegisterChangeCallback("unitframes.player.*", OnConfigChanged)
-- end

-- ===========================
-- EVENT HANDLING
-- ===========================

-- Event frame for module-level events
local eventFrame = CreateFrame("Frame")

-- Handle player-specific events only (ADDON_LOADED/PLAYER_LOGIN managed by init.lua)
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Auto-update on world enter
        C_Timer.After(1, function()
            if playerModule.initialized then
                playerModule:Update()
            end
        end)
    end
end)


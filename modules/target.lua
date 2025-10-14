-- modules/target_new.lua - Target Module using Unified API
local _, ns = ...

-- Module namespace
ns.Modules = ns.Modules or {}
ns.Modules.Target = {}

-- ===========================
-- TARGET MODULE (NEW API)
-- ===========================

local targetModule = {
    unitFrame = nil,
    initialized = false
}

-- Initialize target module
function targetModule:Initialize()
    if self.initialized then
        return
    end


    -- Wait for API if not available yet
    if not (ns.API and ns.API.UnitFrame and ns.API.UnitFrame.Create) then
        C_Timer.After(0.1, function()
            self:Initialize()
        end)
        return
    end

    -- Create complete target unitframe in ONE LINE using API
    self.unitFrame = ns.API.UnitFrame.Create(TargetFrame, "target")

    if not self.unitFrame then
        return
    end

    local config = ns.DB.GetUnitConfig("target")

    self.initialized = true
end
-- Update target frame
function targetModule:Update()
    if not self.initialized or not self.unitFrame then return end

    if self.unitFrame.healthSystem then
        self.unitFrame.healthSystem:UpdateHealth()
    end
    if self.unitFrame.powerSystem then
        self.unitFrame.powerSystem:UpdatePower()
    end
    if self.unitFrame.portraitSystem then
        self.unitFrame.portraitSystem:UpdatePortrait()
    end
end

-- Show/hide target frame
function targetModule:SetVisible(visible)
    if not self.unitFrame or not self.unitFrame.parentFrame then return end

    if visible then
        self.unitFrame.parentFrame:Show()
    else
        self.unitFrame.parentFrame:Hide()
    end
end

-- Cleanup
function targetModule:Destroy()
    if self.unitFrame then
        self.unitFrame:Destroy()
        self.unitFrame = nil
    end
    self.initialized = false
end

-- Get current unitframe
function targetModule:GetUnitFrame()
    return self.unitFrame
end

-- ===========================
-- MODULE INTERFACE
-- ===========================

-- Setup method for lifecycle compatibility
ns.Modules.Target.Setup = ns.CreateModuleSetup(targetModule)

-- Public API
ns.Modules.Target.Initialize = function()
    return targetModule:Initialize()
end

ns.Modules.Target.Update = function()
    return targetModule:Update()
end

ns.Modules.Target.SetVisible = function(visible)
    return targetModule:SetVisible(visible)
end

ns.Modules.Target.Destroy = function()
    return targetModule:Destroy()
end

ns.Modules.Target.GetUnitFrame = function()
    return targetModule:GetUnitFrame()
end
-- ===========================
-- EVENT HANDLING
-- ===========================

-- Event frame for target-specific events
local eventFrame = CreateFrame("Frame")

-- Handle target-specific events only (ADDON_LOADED managed by init.lua)
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "PLAYER_TARGET_CHANGED" then
        -- Auto-update when target changes
        if targetModule.initialized then
            targetModule:Update()
        end
    end
end)


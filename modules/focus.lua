-- modules/focus_new.lua - Focus Module using Unified API
local _, ns = ...

-- Module namespace
ns.Modules = ns.Modules or {}
ns.Modules.Focus = {}

-- ===========================
-- FOCUS MODULE (NEW API)
-- ===========================

local focusModule = {
    unitFrame = nil,
    initialized = false
}

-- Initialize focus module
function focusModule:Initialize()
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

    -- Create complete focus unitframe in ONE LINE using API
    self.unitFrame = ns.API.UnitFrame.Create(FocusFrame, "focus")

    if not self.unitFrame then
        return
    end

    local config = ns.DB.GetUnitConfig("focus")

    self.initialized = true

    -- Update visibility based on focus existence
    self:UpdateVisibility()
end
-- Update focus frame
function focusModule:Update()
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

-- Show/hide focus frame
function focusModule:SetVisible(visible)
    if not self.unitFrame or not self.unitFrame.parentFrame then return end

    if visible then
        self.unitFrame.parentFrame:Show()
    else
        self.unitFrame.parentFrame:Hide()
    end
end

-- Update visibility based on focus existence
function focusModule:UpdateVisibility()
    local hasFocus = UnitExists("focus")
    self:SetVisible(hasFocus)
end

-- Cleanup
function focusModule:Destroy()
    if self.unitFrame then
        self.unitFrame:Destroy()
        self.unitFrame = nil
    end
    self.initialized = false
end

-- Get current unitframe
function focusModule:GetUnitFrame()
    return self.unitFrame
end

-- ===========================
-- MODULE INTERFACE
-- ===========================

-- Setup method for lifecycle compatibility
ns.Modules.Focus.Setup = ns.CreateModuleSetup(focusModule)

-- Public API
ns.Modules.Focus.Initialize = function()
    return focusModule:Initialize()
end

ns.Modules.Focus.Update = function()
    return focusModule:Update()
end

ns.Modules.Focus.SetVisible = function(visible)
    return focusModule:SetVisible(visible)
end

ns.Modules.Focus.Destroy = function()
    return focusModule:Destroy()
end

ns.Modules.Focus.GetUnitFrame = function()
    return focusModule:GetUnitFrame()
end

ns.Modules.Focus.UpdateVisibility = function()
    return focusModule:UpdateVisibility()
end

-- ===========================
-- EVENT HANDLING
-- ===========================

-- Event frame for focus-specific events
local eventFrame = CreateFrame("Frame")

-- Handle focus-specific events only (ADDON_LOADED managed by init.lua)
eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "PLAYER_FOCUS_CHANGED" then
        -- Auto-update when focus changes
        if focusModule.initialized then
            focusModule:UpdateVisibility()
            focusModule:Update()
        end
    end
end)


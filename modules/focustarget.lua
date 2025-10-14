-- modules/focustarget.lua - Focus Target Module using Unified API
local _, ns = ...

-- Module namespace
ns.Modules = ns.Modules or {}
ns.Modules.FocusTarget = {}

-- ===========================
-- FOCUS TARGET MODULE (NEW API)
-- ===========================

local focusTargetModule = {
    unitFrame = nil,
    initialized = false
}

-- Initialize focustarget module
function focusTargetModule:Initialize()
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

    -- Wait for Blizzard frame to be available
    if not FocusFrameToT then
        C_Timer.After(0.5, function()
            self:Initialize()
        end)
        return
    end

    -- Create complete focustarget unitframe in ONE LINE using API
    self.unitFrame = ns.API.UnitFrame.Create(FocusFrameToT, "focustarget")

    if not self.unitFrame then
        return
    end

    local config = ns.DB.GetUnitConfig("focustarget")

    -- Apply custom position
    self:ApplyPosition()

    -- Apply enabled state (hide if disabled)
    self:ApplyEnabledState()

    self.initialized = true

    -- Reapply position after a short delay to override Blizzard's repositioning
    C_Timer.After(0.1, function()
        self:ApplyPosition()
    end)
end
-- Update focustarget frame
function focusTargetModule:Update()
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

-- Show/hide focustarget frame
function focusTargetModule:SetVisible(visible)
    if not self.unitFrame or not self.unitFrame.parentFrame then return end

    if visible then
        self.unitFrame.parentFrame:Show()
    else
        self.unitFrame.parentFrame:Hide()
    end
end

-- Update visibility based on focus target existence
function focusTargetModule:UpdateVisibility()
    -- Check if frame is enabled in config
    local config = ns.DB.GetUnitConfig("focustarget")
    if config and config.enabled == false then
        -- If disabled in config, force hide
        self:SetVisible(false)
        return
    end

    -- Otherwise, show based on unit existence
    local hasFocusTarget = UnitExists("focustarget")
    self:SetVisible(hasFocusTarget)
end

-- Cleanup
function focusTargetModule:Destroy()
    if self.unitFrame then
        self.unitFrame:Destroy()
        self.unitFrame = nil
    end
    self.initialized = false
end

-- Get current unitframe
function focusTargetModule:GetUnitFrame()
    return self.unitFrame
end

-- Apply position from config (reposition entire unitframe)
function focusTargetModule:ApplyPosition()
    if not self.initialized or not self.unitFrame or not self.unitFrame.parentFrame then
        return
    end

    -- Get position config
    local config = ns.DB.GetUnitConfig("focustarget")
    if not config or not config.position then
        return
    end

    local pos = config.position
    local parentFrame = self.unitFrame.parentFrame  -- FocusFrameToT
    local anchorTo = FocusFrame  -- Always anchor to FocusFrame

    -- Apply position using WoW API
    parentFrame:ClearAllPoints()
    parentFrame:SetPoint(
        pos.anchor or "TOPLEFT",
        anchorTo,
        pos.relativePoint or "BOTTOMLEFT",
        pos.offsetX or 0,
        pos.offsetY or 0
    )
end

-- Apply enabled state from config (show/hide entire unitframe)
function focusTargetModule:ApplyEnabledState()
    if not self.unitFrame or not self.unitFrame.parentFrame then
        return
    end

    -- Get config
    local config = ns.DB.GetUnitConfig("focustarget")
    if not config then
        return
    end

    -- Check enabled state (default to true if not set)
    local enabled = config.enabled
    if enabled == nil then
        enabled = true
    end

    -- Show or hide the entire frame based on enabled state
    if enabled then
        -- Only show if unit exists (preserve visibility logic)
        if UnitExists("focustarget") then
            self.unitFrame.parentFrame:Show()
        end
    else
        -- Force hide if disabled
        self.unitFrame.parentFrame:Hide()
    end
end

-- ===========================
-- MODULE INTERFACE
-- ===========================

-- Setup method for lifecycle compatibility
ns.Modules.FocusTarget.Setup = ns.CreateModuleSetup(focusTargetModule)

-- Public API
ns.Modules.FocusTarget.Initialize = function()
    return focusTargetModule:Initialize()
end

ns.Modules.FocusTarget.Update = function()
    return focusTargetModule:Update()
end

ns.Modules.FocusTarget.SetVisible = function(visible)
    return focusTargetModule:SetVisible(visible)
end

ns.Modules.FocusTarget.Destroy = function()
    return focusTargetModule:Destroy()
end

ns.Modules.FocusTarget.GetUnitFrame = function()
    return focusTargetModule:GetUnitFrame()
end
ns.Modules.FocusTarget.UpdateVisibility = function()
    return focusTargetModule:UpdateVisibility()
end

ns.Modules.FocusTarget.ApplyPosition = function()
    return focusTargetModule:ApplyPosition()
end

ns.Modules.FocusTarget.ApplyEnabledState = function()
    return focusTargetModule:ApplyEnabledState()
end

-- ===========================
-- EVENT HANDLING
-- ===========================

-- Event frame for focustarget-specific events
local eventFrame = CreateFrame("Frame")

-- Handle focustarget-specific events only (ADDON_LOADED managed by init.lua)
eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
eventFrame:RegisterEvent("UNIT_TARGET")

eventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_FOCUS_CHANGED" then
        -- Auto-update when focus changes (affects focus target)
        if focusTargetModule.initialized then
            focusTargetModule:UpdateVisibility()
            focusTargetModule:Update()
        end
    elseif event == "UNIT_TARGET" and unit == "focus" then
        -- Auto-update when focus's target changes
        if focusTargetModule.initialized then
            focusTargetModule:UpdateVisibility()
            focusTargetModule:Update()
        end
    end
end)


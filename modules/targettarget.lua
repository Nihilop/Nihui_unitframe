-- modules/targettarget_new.lua - Target of Target Module using Unified API
local _, ns = ...

-- Module namespace
ns.Modules = ns.Modules or {}
ns.Modules.TargetTarget = {}

-- ===========================
-- TARGET OF TARGET MODULE (NEW API)
-- ===========================

local targetTargetModule = {
    unitFrame = nil,
    initialized = false
}

-- Initialize targettarget module
function targetTargetModule:Initialize()
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
    if not TargetFrameToT then
        C_Timer.After(0.5, function()
            self:Initialize()
        end)
        return
    end

    -- Create complete targettarget unitframe in ONE LINE using API
    self.unitFrame = ns.API.UnitFrame.Create(TargetFrameToT, "targettarget")

    if not self.unitFrame then
        return
    end

    local config = ns.DB.GetUnitConfig("targettarget")

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
-- Update targettarget frame
function targetTargetModule:Update()
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

-- Show/hide targettarget frame
function targetTargetModule:SetVisible(visible)
    if not self.unitFrame or not self.unitFrame.parentFrame then return end

    if visible then
        self.unitFrame.parentFrame:Show()
    else
        self.unitFrame.parentFrame:Hide()
    end
end

-- Update visibility based on target of target existence
function targetTargetModule:UpdateVisibility()
    -- Check if frame is enabled in config
    local config = ns.DB.GetUnitConfig("targettarget")
    if config and config.enabled == false then
        -- If disabled in config, force hide
        self:SetVisible(false)
        return
    end

    -- Otherwise, show based on unit existence
    local hasTargetTarget = UnitExists("targettarget")
    self:SetVisible(hasTargetTarget)
end

-- Cleanup
function targetTargetModule:Destroy()
    if self.unitFrame then
        self.unitFrame:Destroy()
        self.unitFrame = nil
    end
    self.initialized = false
end

-- Get current unitframe
function targetTargetModule:GetUnitFrame()
    return self.unitFrame
end

-- Apply position from config (reposition entire unitframe)
function targetTargetModule:ApplyPosition()
    if not self.initialized or not self.unitFrame or not self.unitFrame.parentFrame then
        return
    end

    -- Get position config
    local config = ns.DB.GetUnitConfig("targettarget")
    if not config or not config.position then
        return
    end

    local pos = config.position
    local parentFrame = self.unitFrame.parentFrame  -- TargetFrameToT
    local anchorTo = TargetFrame  -- Always anchor to TargetFrame

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
function targetTargetModule:ApplyEnabledState()
    if not self.unitFrame or not self.unitFrame.parentFrame then
        return
    end

    -- Get config
    local config = ns.DB.GetUnitConfig("targettarget")
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
        if UnitExists("targettarget") then
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
ns.Modules.TargetTarget.Setup = ns.CreateModuleSetup(targetTargetModule)

-- Public API
ns.Modules.TargetTarget.Initialize = function()
    return targetTargetModule:Initialize()
end

ns.Modules.TargetTarget.Update = function()
    return targetTargetModule:Update()
end

ns.Modules.TargetTarget.SetVisible = function(visible)
    return targetTargetModule:SetVisible(visible)
end

ns.Modules.TargetTarget.Destroy = function()
    return targetTargetModule:Destroy()
end

ns.Modules.TargetTarget.GetUnitFrame = function()
    return targetTargetModule:GetUnitFrame()
end
ns.Modules.TargetTarget.UpdateVisibility = function()
    return targetTargetModule:UpdateVisibility()
end

ns.Modules.TargetTarget.ApplyPosition = function()
    return targetTargetModule:ApplyPosition()
end

ns.Modules.TargetTarget.ApplyEnabledState = function()
    return targetTargetModule:ApplyEnabledState()
end

-- ===========================
-- EVENT HANDLING
-- ===========================

-- Event frame for targettarget-specific events
local eventFrame = CreateFrame("Frame")

-- Handle targettarget-specific events only (ADDON_LOADED managed by init.lua)
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UNIT_TARGET")

eventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        -- Auto-update when target changes (affects target of target)
        if targetTargetModule.initialized then
            targetTargetModule:UpdateVisibility()
            targetTargetModule:Update()
        end
    elseif event == "UNIT_TARGET" and unit == "target" then
        -- Auto-update when target's target changes
        if targetTargetModule.initialized then
            targetTargetModule:UpdateVisibility()
            targetTargetModule:Update()
        end
    end
end)


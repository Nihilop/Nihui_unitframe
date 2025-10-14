-- modules/pet_new.lua - Pet Module using Unified API
local _, ns = ...

-- Module namespace
ns.Modules = ns.Modules or {}
ns.Modules.Pet = {}

-- ===========================
-- PET MODULE (NEW API)
-- ===========================

local petModule = {
    unitFrame = nil,
    initialized = false
}

-- Initialize pet module
function petModule:Initialize()
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
    if not PetFrame then
        C_Timer.After(0.5, function()
            self:Initialize()
        end)
        return
    end

    -- Create complete pet unitframe in ONE LINE using API
    self.unitFrame = ns.API.UnitFrame.Create(PetFrame, "pet")

    if not self.unitFrame then
        return
    end

    local config = ns.DB.GetUnitConfig("pet")

    self.initialized = true

    -- Update visibility based on pet existence
    self:UpdateVisibility()
end
-- Update pet frame
function petModule:Update()
    if not self.initialized or not self.unitFrame then return end

    if self.unitFrame.healthSystem then
        self.unitFrame.healthSystem:UpdateHealth()
    end
    if self.unitFrame.powerSystem then
        self.unitFrame.powerSystem:UpdatePower()
    end
end

-- Show/hide pet frame (pet-specific logic for existence)
function petModule:SetVisible(visible)
    if not self.unitFrame or not self.unitFrame.parentFrame then return end

    -- Pet visibility depends on pet existence
    local hasPet = UnitExists("pet")
    if visible and hasPet then
        self.unitFrame.parentFrame:Show()
    else
        self.unitFrame.parentFrame:Hide()
    end
end

-- Update pet visibility based on pet existence
function petModule:UpdateVisibility()
    local hasPet = UnitExists("pet")
    self:SetVisible(hasPet)
end

-- Cleanup
function petModule:Destroy()
    if self.unitFrame then
        self.unitFrame:Destroy()
        self.unitFrame = nil
    end
    self.initialized = false
end

-- Get current unitframe
function petModule:GetUnitFrame()
    return self.unitFrame
end

-- ===========================
-- MODULE INTERFACE
-- ===========================

-- Setup method for lifecycle compatibility
ns.Modules.Pet.Setup = ns.CreateModuleSetup(petModule)

-- Public API
ns.Modules.Pet.Initialize = function()
    return petModule:Initialize()
end

ns.Modules.Pet.Update = function()
    return petModule:Update()
end

ns.Modules.Pet.SetVisible = function(visible)
    return petModule:SetVisible(visible)
end

ns.Modules.Pet.Destroy = function()
    return petModule:Destroy()
end

ns.Modules.Pet.GetUnitFrame = function()
    return petModule:GetUnitFrame()
end
ns.Modules.Pet.UpdateVisibility = function()
    return petModule:UpdateVisibility()
end

-- ===========================
-- EVENT HANDLING
-- ===========================

-- Event frame for pet-specific events
local eventFrame = CreateFrame("Frame")

-- Handle pet-specific events only (ADDON_LOADED managed by init.lua)
eventFrame:RegisterEvent("UNIT_PET")
eventFrame:RegisterEvent("PET_BATTLE_OPENING_START")
eventFrame:RegisterEvent("PET_BATTLE_CLOSE")

eventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_PET" and unit == "player" then
        -- Auto-update when pet changes
        if petModule.initialized then
            petModule:UpdateVisibility()
            petModule:Update()
        end
    elseif event == "PET_BATTLE_OPENING_START" then
        if petModule.initialized then
            petModule:SetVisible(false)
        end
    elseif event == "PET_BATTLE_CLOSE" then
        if petModule.initialized then
            petModule:UpdateVisibility()
        end
    end
end)


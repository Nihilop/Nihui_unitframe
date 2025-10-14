-- systems/portrait/states.lua - Portrait State System (Flash, Combat, Threat) - API Pure
local _, ns = ...

-- Systems namespace
ns.Systems = ns.Systems or {}
ns.Systems.Portrait = ns.Systems.Portrait or {}
ns.Systems.Portrait.States = {}

-- ===========================
-- PORTRAIT STATES SYSTEM
-- ===========================

-- Create portrait states system (flash, combat, threat)
function ns.Systems.Portrait.States.Create(parentFrame, unitToken, config)
    local statesSystem = {}

    -- Store references
    statesSystem.parent = parentFrame
    statesSystem.unit = unitToken
    statesSystem.config = config or {}
    statesSystem.effects = {}
    statesSystem.currentStates = {}

    -- ===========================
    -- EFFECT CREATION
    -- ===========================

    -- Create flash effect
    function statesSystem:CreateFlashEffect()
        if self.effects.flash then
            return self.effects.flash
        end

        local flashConfig = self.config.flash
        if not flashConfig or not flashConfig.enabled then
            return nil
        end

        -- Create flash using UI.Effects
        local flash = ns.UI.Effects.CreateFlash(self.parent, flashConfig)
        self.effects.flash = flash

        return flash
    end

    -- Create threat glow effect
    function statesSystem:CreateThreatGlow()
        if self.effects.threatGlow then
            return self.effects.threatGlow
        end

        local glowConfig = self.config.threatGlow
        if not glowConfig or not glowConfig.enabled then
            return nil
        end

        -- Create threat glow using UI.Effects
        local glow = ns.UI.Effects.CreateThreatGlow(self.parent, glowConfig)
        self.effects.threatGlow = glow

        return glow
    end

    -- Create status indicator
    function statesSystem:CreateStatusIndicator()
        if self.effects.statusIndicator then
            return self.effects.statusIndicator
        end

        local statusConfig = self.config.statusIndicator
        if not statusConfig or not statusConfig.enabled then
            return nil
        end

        -- Create status indicator using UI.Effects
        local status = ns.UI.Effects.CreateStatusIndicator(self.parent, statusConfig)
        self.effects.statusIndicator = status

        return status
    end

    -- ===========================
    -- STATE DETECTION
    -- ===========================

    -- Check combat state
    function statesSystem:GetCombatState()
        if not UnitExists(self.unit) then
            return false
        end

        if self.unit == "player" then
            -- Multiple combat checks for player
            return UnitAffectingCombat("player") or
                   InCombatLockdown() or
                   (UnitExists("target") and UnitCanAttack("player", "target") and UnitAffectingCombat("target"))
        else
            -- For other units, check if they're in combat
            return UnitAffectingCombat(self.unit)
        end
    end

    -- Check threat state
    function statesSystem:GetThreatState()
        if not UnitExists(self.unit) or self.unit == "player" then
            return 0
        end

        local isTanking, status, threatpct = UnitDetailedThreatSituation("player", self.unit)
        local targetIsHostile = UnitCanAttack("player", self.unit)

        if targetIsHostile and status and status >= 1 then
            return status
        end

        return 0
    end

    -- Check death/status state
    function statesSystem:GetStatusState()
        if not UnitExists(self.unit) then
            return "missing"
        end

        if UnitIsDead(self.unit) then
            return "dead"
        elseif UnitIsGhost(self.unit) then
            return "ghost"
        elseif not UnitIsConnected(self.unit) then
            return "offline"
        end

        return "alive"
    end

    -- ===========================
    -- STATE UPDATES
    -- ===========================

    -- Update flash state
    function statesSystem:UpdateFlashState()
        local flash = self.effects.flash
        if not flash then
            return
        end

        local shouldFlash = false

        -- Check flash conditions based on config
        if self.config.flash.showInCombat and self:GetCombatState() then
            shouldFlash = true
        end

        if self.config.flash.showOnThreat and self:GetThreatState() > 0 then
            shouldFlash = true
        end

        -- Apply flash flip to match portrait orientation
        if shouldFlash and self.config.flash.matchPortraitFlip then
            self:ApplyFlashFlip(flash)
        end

        -- Update flash visibility
        if shouldFlash then
            flash:Show()
            self.currentStates.flash = true
        else
            flash:Hide()
            self.currentStates.flash = false
        end
    end

    -- Update threat glow
    function statesSystem:UpdateThreatGlow()
        local glow = self.effects.threatGlow
        if not glow then
            return
        end

        local threatStatus = self:GetThreatState()

        if threatStatus > 0 then
            glow:SetThreatColor(threatStatus)
            glow:Show()
            self.currentStates.threat = threatStatus
        else
            glow:Hide()
            self.currentStates.threat = 0
        end
    end

    -- Update status indicator
    function statesSystem:UpdateStatusIndicator()
        local status = self.effects.statusIndicator
        if not status then
            return
        end

        local statusState = self:GetStatusState()

        if statusState == "dead" then
            status:ShowStatus("dead", "DEAD")
            self.currentStates.status = "dead"
        elseif statusState == "ghost" then
            status:ShowStatus("ghost", "GHOST")
            self.currentStates.status = "ghost"
        elseif statusState == "offline" then
            status:ShowStatus("offline", "OFFLINE")
            self.currentStates.status = "offline"
        else
            status:Hide()
            self.currentStates.status = "alive"
        end
    end

    -- Update all states
    function statesSystem:UpdateAllStates()
        self:UpdateFlashState()
        self:UpdateThreatGlow()
        self:UpdateStatusIndicator()
    end

    -- ===========================
    -- PORTRAIT FLIP INTEGRATION
    -- ===========================

    -- Apply flash flip to match portrait
    function statesSystem:ApplyFlashFlip(flash)
        if not flash or not self.config.flash.matchPortraitFlip then
            return
        end

        local shouldFlip = false

        -- Detect Blizzard portrait flip state
        if self.unit == "player" and PlayerFrame and PlayerFrame.PlayerFrameContainer and PlayerFrame.PlayerFrameContainer.PlayerPortrait then
            local portrait = PlayerFrame.PlayerFrameContainer.PlayerPortrait
            local left, right, top, bottom = portrait:GetTexCoord()
            shouldFlip = left > right
        elseif self.unit == "target" and TargetFrame and TargetFrame.TargetFrameContainer and TargetFrame.TargetFrameContainer.Portrait then
            local portrait = TargetFrame.TargetFrameContainer.Portrait
            local left, right, top, bottom = portrait:GetTexCoord()
            shouldFlip = left > right
        end

        -- Apply opposite flip to flash (so flash matches portrait orientation)
        if shouldFlip then
            flash:SetFlip(false, false) -- Portrait flipped = flash normal
        else
            flash:SetFlip(true, false)  -- Portrait normal = flash flipped
        end
    end

    -- ===========================
    -- CONFIGURATION METHODS
    -- ===========================

    -- Enable/disable flash
    function statesSystem:SetFlashEnabled(enabled)
        if not self.config.flash then
            self.config.flash = {}
        end

        self.config.flash.enabled = enabled

        if enabled then
            self:CreateFlashEffect()
        elseif self.effects.flash then
            self.effects.flash:Hide()
        end

        self:UpdateFlashState()
    end

    -- Enable/disable threat glow
    function statesSystem:SetThreatGlowEnabled(enabled)
        if not self.config.threatGlow then
            self.config.threatGlow = {}
        end

        self.config.threatGlow.enabled = enabled

        if enabled then
            self:CreateThreatGlow()
        elseif self.effects.threatGlow then
            self.effects.threatGlow:Hide()
        end

        self:UpdateThreatGlow()
    end

    -- Set flash conditions
    function statesSystem:SetFlashConditions(showInCombat, showOnThreat)
        if not self.config.flash then
            self.config.flash = {}
        end

        self.config.flash.showInCombat = showInCombat
        self.config.flash.showOnThreat = showOnThreat

        self:UpdateFlashState()
    end

    -- ===========================
    -- EVENT HANDLING
    -- ===========================

    -- Register for state change events
    function statesSystem:RegisterEvents()
        local frame = CreateFrame("Frame")

        -- Combat events
        frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        frame:RegisterEvent("UNIT_COMBAT")

        -- Threat events
        frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")

        -- Target/Focus change events
        frame:RegisterEvent("PLAYER_TARGET_CHANGED")
        frame:RegisterEvent("PLAYER_FOCUS_CHANGED")

        -- Death/Status events
        frame:RegisterEvent("UNIT_HEALTH")
        frame:RegisterEvent("UNIT_CONNECTION")

        frame:SetScript("OnEvent", function(_, event, eventUnit)
            if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
                self:UpdateAllStates()
            elseif event == "UNIT_COMBAT" and eventUnit == self.unit then
                self:UpdateFlashState()
            elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
                self:UpdateThreatGlow()
            elseif event == "PLAYER_TARGET_CHANGED" and self.unit == "target" then
                C_Timer.After(0.1, function()
                    self:UpdateAllStates()
                end)
            elseif event == "PLAYER_FOCUS_CHANGED" and self.unit == "focus" then
                C_Timer.After(0.1, function()
                    self:UpdateAllStates()
                end)
            elseif event == "UNIT_HEALTH" and eventUnit == self.unit then
                self:UpdateStatusIndicator()
            elseif event == "UNIT_CONNECTION" and eventUnit == self.unit then
                self:UpdateStatusIndicator()
            end
        end)

        self.eventFrame = frame
    end

    -- Unregister events
    function statesSystem:UnregisterEvents()
        if self.eventFrame then
            self.eventFrame:UnregisterAllEvents()
            self.eventFrame:SetScript("OnEvent", nil)
            self.eventFrame = nil
        end
    end

    -- ===========================
    -- LIFECYCLE
    -- ===========================

    -- Initialize the states system
    function statesSystem:Initialize()
        -- Create effects based on config
        if self.config.flash and self.config.flash.enabled then
            self:CreateFlashEffect()
        end

        if self.config.threatGlow and self.config.threatGlow.enabled then
            self:CreateThreatGlow()
        end

        if self.config.statusIndicator and self.config.statusIndicator.enabled then
            self:CreateStatusIndicator()
        end

        self:RegisterEvents()
        self:UpdateAllStates()
    end

    -- Destroy the states system
    function statesSystem:Destroy()
        self:UnregisterEvents()

        -- Hide and clean up all effects
        for _, effect in pairs(self.effects) do
            if effect.Hide then
                effect:Hide()
            end
            if effect.frame then
                effect.frame:SetParent(nil)
            end
        end

        self.effects = {}
        self.currentStates = {}
        self.parent = nil
    end

    return statesSystem
end

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================

-- Quick setup function for simple cases
function ns.Systems.Portrait.States.Setup(parentFrame, unitToken, config)
    local system = ns.Systems.Portrait.States.Create(parentFrame, unitToken, config)
    system:Initialize()
    return system
end

-- Get default states configuration
function ns.Systems.Portrait.States.GetDefaultConfig()
    return {
        flash = {
            enabled = true,
            showInCombat = true,
            showOnThreat = true,
            matchPortraitFlip = true,
            atlas = "Ping_UnitMarker_BG_Threat",
            color = {1, 0.3, 0.3, 0.8},
            rotation = -45,
            blendMode = "ADD",
            fromAlpha = 0.6,
            toAlpha = 1.0,
            duration = 0.8
        },
        threatGlow = {
            enabled = true,
            padding = 4,
            blendMode = "ADD"
        },
        statusIndicator = {
            enabled = true,
            fontSize = 16
        }
    }
end

-- Check if unit supports state effects
function ns.Systems.Portrait.States.SupportsStates(unitToken)
    local supportedUnits = {
        player = true,
        target = true,
        focus = true,
        pet = true
    }

    return supportedUnits[unitToken] or false
end
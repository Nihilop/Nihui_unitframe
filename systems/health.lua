-- systems/health.lua - Health System Logic (utilise API bar générique)
local _, ns = ...

-- Systems namespace
ns.Systems = ns.Systems or {}
ns.Systems.Health = {}

-- ===========================
-- HEALTH BAR CONFIGURATION (rnxmUI)
-- ===========================

-- Get health bar configuration for unit type from DB
function ns.Systems.Health.GetBarConfig(unitType, customConfig)
    -- Extract base unit type (party1 -> party, target -> target, etc.)
    local baseUnitType = unitType:match("^(%a+)%d*$") or unitType

    -- Get unit config from database
    local unitConfig = ns.DB.GetUnitConfig(baseUnitType:lower())
    if not unitConfig or not unitConfig.health then
        return nil
    end

    local healthConfig = unitConfig.health

    -- Convert DB config to bar API format
    local config = {
        main = {
            width = healthConfig.width or 100,
            height = healthConfig.height or 20,
            texture = healthConfig.texture or "Interface\\TargetingFrame\\UI-StatusBar",
            frameLevel = 1
        },
        background = {
            texture = healthConfig.texture or "Interface\\TargetingFrame\\UI-StatusBar",
            color = {0.1, 0.1, 0.1, 0.8}
        }
    }

    -- Add glass effect if enabled (hardcoded values for consistency)
    if healthConfig.glassEnabled then
        config.glass = {
            enabled = true,
            texture = "Interface\\AddOns\\Nihui_uf\\textures\\HPglass.tga",  -- HARDCODED
            alpha = healthConfig.glassAlpha or 0.2,  -- CONFIGURABLE
            blendMode = "ADD"  -- HARDCODED
        }
    end

    -- Add border (always enabled, hardcoded values)
    config.border = {
        enabled = true,
        edgeFile = "Interface\\AddOns\\Nihui_uf\\textures\\MirroredFrameSingleUF.tga",  -- HARDCODED
        edgeSize = 16,  -- HARDCODED
        color = {0.5, 0.5, 0.5, 1},  -- HARDCODED
        insets = {left = -12, top = 12, right = 12, bottom = -12}  -- HARDCODED
    }

    -- Add animated loss overlay if enabled
    if healthConfig.animatedLossEnabled then
        config.overlays = config.overlays or {}
        config.overlays.animatedLoss = {
            enabled = true,
            texture = healthConfig.texture or "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
            color = healthConfig.animatedLossColor or {1, 0, 0, 1},
            frameLevelOffset = -1,
            value = 100
        }
    end

    -- Add absorb overlay if enabled
    if healthConfig.absorbEnabled then
        config.overlays = config.overlays or {}
        config.overlays.absorb = {
            enabled = true,
            texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",  -- Base solid texture (works!)
            color = {0.6, 0.8, 1, 1},  -- Brighter blue
            frameLevelOffset = 1,
            value = 0,
            overlayTexture = "Interface\\AddOns\\Nihui_uf\\textures\\Shield-Overlay.tga",  -- Shield pattern
            overlayBlendMode = "ADD"
        }
    end

    -- Add heal prediction overlay if enabled
    if healthConfig.healPredictionEnabled then
        config.overlays = config.overlays or {}
        config.overlays.healPrediction = {
            enabled = true,
            texture = healthConfig.healPredictionTexture or "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
            color = healthConfig.healPredictionColor or {0, 1, 0, 0.4},
            frameLevelOffset = 0,
            value = 0
        }
    end

    -- Merge custom config if provided (for runtime overrides)
    if customConfig then
        for section, sectionConfig in pairs(customConfig) do
            if type(sectionConfig) == "table" and config[section] then
                -- Deep merge pour les sections
                for key, value in pairs(sectionConfig) do
                    if type(value) == "table" and type(config[section][key]) == "table" then
                        -- Merge les sous-sections (comme main.width)
                        for subKey, subValue in pairs(value) do
                            config[section][key][subKey] = subValue
                        end
                    else
                        config[section][key] = value
                    end
                end
            else
                config[section] = sectionConfig
            end
        end
    end

    return config
end

-- ===========================
-- COLOR FUNCTIONS
-- ===========================

function ns.Systems.Health.GetUnitColor(unit)
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        if class then
            local color = RAID_CLASS_COLORS[class]
            if color then
                return {color.r, color.g, color.b, 1}
            end
        end
    else
        local reaction = UnitReaction(unit, "player")
        if reaction then
            local color = FACTION_BAR_COLORS[reaction]
            if color then
                return {color.r, color.g, color.b, 1}
            end
        end
    end
    return {1, 1, 1, 1} -- White fallback
end

-- ===========================
-- HEALTH SYSTEM CREATION
-- ===========================

-- Create complete health system using generic bar API
function ns.Systems.Health.Create(parent, unitToken, config)
    local healthSystem = {}

    -- Store references
    healthSystem.unit = unitToken
    healthSystem.config = config or {}

    -- Initialize default color settings if not provided
    if healthSystem.config.colorByClass == nil then
        healthSystem.config.colorByClass = true -- Default to true per defaults.lua
    end

    -- ===========================
    -- BUILD HEALTH BAR WITH API
    -- ===========================

    -- Get bar configuration for unit type
    local barConfig = ns.Systems.Health.GetBarConfig(unitToken, config.barConfig)

    -- Create complete health bar using generic API
    healthSystem.barSet = ns.UI.Bar.CreateCompleteBar(parent, barConfig)
    healthSystem.bar = healthSystem.barSet.main -- Main bar for compatibility

    -- Set glass texture reference for real-time updates
    if healthSystem.barSet.glass then
        healthSystem.glassTexture = healthSystem.barSet.glass
    end

    -- ===========================
    -- LOW HEALTH WARNING OVERLAY
    -- ===========================
    -- Create low health warning overlay (powerHL1 texture from Nihui_cb)
    -- Inspired by castbar positioning for proper alignment
    if healthSystem.barSet.border then
        local borderFrame = healthSystem.barSet.border

        -- Create warning overlay texture
        healthSystem.lowHealthWarning = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        healthSystem.lowHealthWarning:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\powerHL1.tga")
        healthSystem.lowHealthWarning:SetBlendMode("ADD") -- Additive blending for glow effect
        healthSystem.lowHealthWarning:SetVertexColor(1, 0, 0, 0.7) -- Red tint

        -- Proportional sizing like Nihui_cb castbar (width * 1.1, height * 2)
        -- IMPORTANT: Size will be updated dynamically in UpdateLowHealthWarningSize()
        healthSystem.lowHealthWarning:SetPoint("CENTER", healthSystem.bar, "CENTER")

        -- Apply texture flip based on portrait flip setting
        local unitConfig = ns.DB.GetUnitConfig(unitToken:match("^(%a+)%d*$") or unitToken)
        if unitConfig and unitConfig.portrait and unitConfig.portrait.flip then
            -- Flip texture horizontally (swap left/right coordinates)
            healthSystem.lowHealthWarning:SetTexCoord(1, 0, 1, 1, 0, 0, 0, 1)
        else
            -- Normal texture coordinates
            healthSystem.lowHealthWarning:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
        end

        -- Hide by default
        healthSystem.lowHealthWarning:Hide()
        healthSystem.lowHealthWarningActive = false
    end

    -- ===========================
    -- UPDATE METHODS
    -- ===========================

    -- Update health values and appearance
    function healthSystem:UpdateHealth()
        if not UnitExists(self.unit) then
            ns.UI.Bar.SetValue(self.bar, 0)
            return false
        end

        -- Get health values
        local current = UnitHealth(self.unit)
        local max = UnitHealthMax(self.unit)

        -- Update main bar
        ns.UI.Bar.SetValue(self.bar, current, max)

        -- Update color if enabled
        if self.config.colorByClass then
            local color = ns.Systems.Health.GetUnitColor(self.unit)
            ns.UI.Bar.SetColor(self.bar, color[1], color[2], color[3], color[4])
        else
            -- Fallback color when colorByClass is disabled (default WoW health green)
            ns.UI.Bar.SetColor(self.bar, 0, 1, 0, 1) -- Green
        end

        -- Update animated loss bar
        if self.barSet.overlays and self.barSet.overlays.animatedLoss then
            self:UpdateAnimatedLoss(current, max)
        end

        -- Update heal prediction bar (only if configured)
        if self.barSet.overlays and self.barSet.overlays.healPrediction then
            self:UpdateHealPrediction()
        end

        -- Update absorb bar
        if self.barSet.overlays and self.barSet.overlays.absorb then
            self:UpdateAbsorb()
        end

        -- Update text if attached
        if self.textElement then
            self.textElement:UpdateValue(current, max)
        end

        -- Update low health warning (30% threshold)
        if self.lowHealthWarning then
            self:UpdateLowHealthWarning(current, max)
        end

        return true
    end

    -- Update low health warning overlay (triggered at 30% health)
    function healthSystem:UpdateLowHealthWarning(currentHealth, maxHealth)
        if not self.lowHealthWarning then return end

        -- Calculate health percentage
        local healthPct = (maxHealth > 0) and (currentHealth / maxHealth) or 1

        -- Trigger at 30% or below, but NOT at 0% (dead)
        if healthPct <= 0.30 and currentHealth > 0 then
            if not self.lowHealthWarningActive then
                self.lowHealthWarning:Show()
                self.lowHealthWarningActive = true

                -- Start breathing animation
                self:StartLowHealthBreathingAnimation()
            end
        else
            if self.lowHealthWarningActive then
                self.lowHealthWarning:Hide()
                self.lowHealthWarningActive = false

                -- Stop breathing animation
                if self.lowHealthBreathingAnimation then
                    self.lowHealthBreathingAnimation:Cancel()
                    self.lowHealthBreathingAnimation = nil
                end
            end
        end
    end

    -- Breathing animation for low health warning (alpha pulsing)
    function healthSystem:StartLowHealthBreathingAnimation()
        if not self.lowHealthWarning then return end

        -- Stop any existing animation
        if self.lowHealthBreathingAnimation then
            self.lowHealthBreathingAnimation:Cancel()
        end

        local startTime = GetTime()
        self.lowHealthBreathingAnimation = C_Timer.NewTicker(0.05, function()
            -- Check if warning is still active
            if not self.lowHealthWarning or not self.lowHealthWarningActive then
                if self.lowHealthBreathingAnimation then
                    self.lowHealthBreathingAnimation:Cancel()
                    self.lowHealthBreathingAnimation = nil
                end
                return true
            end

            -- Breathing effect: alpha pulse from 0.3 to 1.0
            local elapsed = GetTime() - startTime
            local pulsePhase = math.sin(elapsed * 2) -- 2 = breathing speed (slower than sparks)

            -- Alpha from 0.3 (dark) to 1.0 (bright) with smooth IN_OUT
            local alpha = 0.65 + (pulsePhase * 0.35)
            self.lowHealthWarning:SetAlpha(alpha)
        end)
    end

    -- Destroy low health warning overlay
    function healthSystem:DestroyLowHealthWarning()
        -- Stop animation
        if self.lowHealthBreathingAnimation then
            self.lowHealthBreathingAnimation:Cancel()
            self.lowHealthBreathingAnimation = nil
        end

        -- Destroy texture
        if self.lowHealthWarning then
            self.lowHealthWarning:Hide()
            self.lowHealthWarning:SetTexture(nil)
            self.lowHealthWarning = nil
        end

        self.lowHealthWarningActive = false
    end

    -- Update low health warning texture flip based on portrait flip setting
    function healthSystem:UpdateLowHealthWarningFlip(portraitFlip)
        if not self.lowHealthWarning then return end

        if portraitFlip then
            -- Flip texture horizontally (swap left/right coordinates)
            self.lowHealthWarning:SetTexCoord(1, 0, 1, 1, 0, 0, 0, 1)
        else
            -- Normal texture coordinates
            self.lowHealthWarning:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
        end
    end

    -- Update low health warning size based on current health bar dimensions
    -- CRITICAL: This ensures the warning indicator scales with the health bar
    -- regardless of unitframe size (player, raid, party, etc.)
    function healthSystem:UpdateLowHealthWarningSize()
        if not self.lowHealthWarning or not self.bar then return end

        -- Get current health bar dimensions
        local barWidth, barHeight = self.bar:GetSize()

        -- Apply proportional sizing (same formula as creation: width * 1.1, height * 2)
        self.lowHealthWarning:SetSize(barWidth * 1.1, barHeight * 2)
    end

    -- Update animated loss bar (clean single-animation system)
    function healthSystem:UpdateAnimatedLoss(currentHealth, maxHealth)
        local lossBar = self.barSet.overlays.animatedLoss.bar
        if not lossBar then return end

        -- Initialize previous health tracking
        if not self.previousHealth then
            self.previousHealth = currentHealth
            ns.UI.Bar.SetValue(lossBar, currentHealth, maxHealth)
            return
        end

        -- If health decreased, start/restart the delay timer
        if currentHealth < self.previousHealth then
            -- IMMEDIATELY set loss bar to the OLD health level (before damage)
            ns.UI.Bar.SetValue(lossBar, self.previousHealth, maxHealth)

            -- Cancel any existing timer
            if self.lossDelayTimer then
                self.lossDelayTimer:Cancel()
            end

            -- Store the target value for when timer expires
            self.targetLossValue = currentHealth

            -- Start delay timer (1 second without new damage)
            self.lossDelayTimer = C_Timer.NewTimer(1.0, function()
                -- Timer expired - animate loss bar down to current health
                self:AnimateLossBarDown()
                self.lossDelayTimer = nil
            end)

        elseif currentHealth > self.previousHealth then
            -- Health increased - loss bar follows immediately
            ns.UI.Bar.SetValue(lossBar, currentHealth, maxHealth)

            -- Cancel any pending animation
            if self.lossDelayTimer then
                self.lossDelayTimer:Cancel()
                self.lossDelayTimer = nil
            end
            if self.animationTicker then
                self.animationTicker:Cancel()
                self.animationTicker = nil
            end
        end
        -- If health stayed same, do nothing (keep current loss bar state)

        self.previousHealth = currentHealth
    end

    -- Animate loss bar down to target value (called after delay)
    function healthSystem:AnimateLossBarDown()
        local lossBar = self.barSet.overlays.animatedLoss.bar
        if not lossBar or not self.targetLossValue then return end

        local maxHealth = UnitHealthMax(self.unit)
        local startValue = self.previousHealth  -- Where loss bar currently is
        local endValue = self.targetLossValue   -- Where it should go
        local animationDuration = 0.3           -- Fast animation

        -- Cancel any existing animation
        if self.animationTicker then
            self.animationTicker:Cancel()
        end

        -- Start animation
        local startTime = GetTime()
        self.animationTicker = C_Timer.NewTicker(0.02, function()
            local elapsed = GetTime() - startTime
            local progress = elapsed / animationDuration

            if progress >= 1 then
                -- Animation complete
                ns.UI.Bar.SetValue(lossBar, endValue, maxHealth)
                self.animationTicker = nil
                self.targetLossValue = nil
                return true -- Stop ticker
            else
                -- Interpolate
                local currentValue = startValue - (startValue - endValue) * progress
                ns.UI.Bar.SetValue(lossBar, currentValue, maxHealth)
            end
        end)
    end

    -- Update heal prediction bar
    function healthSystem:UpdateHealPrediction()
        if not self.barSet.overlays or not self.barSet.overlays.healPrediction then
            return -- Heal prediction not configured for this unit
        end

        local healBar = self.barSet.overlays.healPrediction.bar
        if not healBar then return end

        local incoming = UnitGetIncomingHeals(self.unit) or 0
        local currentHealth = UnitHealth(self.unit)
        local maxHealth = UnitHealthMax(self.unit)

        -- If no incoming heals, hide and destroy spark
        if incoming <= 0 then
            healBar:Hide()
            self:UpdateHealSpark(healBar, 0)
            return
        end

        if maxHealth <= 0 then
            healBar:Hide()
            self:UpdateHealSpark(healBar, 0)
            return
        end

        -- Calculate heal prediction width
        local healthPct = currentHealth / maxHealth
        local healPct = incoming / maxHealth
        local healthBarWidth = self.bar:GetWidth()

        -- Clamp heal prediction to not exceed max health
        local maxPct = math.min(1.0, healthPct + healPct)
        local clampedHealPct = maxPct - healthPct
        local healWidth = clampedHealPct * healthBarWidth

        -- Position heal prediction immediately after health bar
        if healWidth > 0 then
            healBar:ClearAllPoints()
            healBar:SetPoint("LEFT", self.bar:GetStatusBarTexture(), "RIGHT", 0, 0)
            healBar:SetSize(healWidth, self.bar:GetHeight())
            healBar:Show()

            -- Set bar value to 100% since we control size manually
            ns.UI.Bar.SetValue(healBar, 100, 100)
        else
            healBar:Hide()
        end

        -- Always call UpdateHealSpark - it will handle show/hide based on heal bar state
        self:UpdateHealSpark(healBar, healWidth)
    end

    -- Create/destroy heal spark based on heal prediction bar visibility
    function healthSystem:UpdateHealSpark(healBar, healWidth)
        if not healBar then
            self:DestroyHealSpark()
            return
        end

        -- Simple logic: spark visibility = heal bar visibility
        if healBar:IsShown() then
            -- Create spark if it doesn't exist
            if not self.healSparkCreated then
                local parent = healBar:GetParent()

                -- Outer glow
                self.healSparkGlowOuter = parent:CreateTexture(nil, "OVERLAY", nil, 1)
                self.healSparkGlowOuter:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\AbsorbSpark.tga")
                self.healSparkGlowOuter:SetSize(32, healBar:GetHeight() + 12)
                self.healSparkGlowOuter:SetVertexColor(0, 1, 0, 0.2)
                self.healSparkGlowOuter:SetBlendMode("ADD")

                -- Inner glow
                self.healSparkGlow = parent:CreateTexture(nil, "OVERLAY", nil, 2)
                self.healSparkGlow:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\AbsorbSpark.tga")
                self.healSparkGlow:SetSize(24, healBar:GetHeight() + 8)
                self.healSparkGlow:SetVertexColor(0, 1, 0, 0.4)
                self.healSparkGlow:SetBlendMode("ADD")

                -- Main spark
                self.healSpark = parent:CreateTexture(nil, "OVERLAY", nil, 3)
                self.healSpark:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\AbsorbSpark.tga")
                self.healSpark:SetSize(16, healBar:GetHeight() + 4)
                self.healSpark:SetVertexColor(0, 1, 0, 1.0)
                self.healSpark:SetBlendMode("ADD")

                self.healSparkCreated = true
            end

            -- Position sparks at RIGHT edge of heal prediction bar
            self.healSpark:ClearAllPoints()
            self.healSpark:SetPoint("LEFT", healBar, "RIGHT", -8, 0)
            self.healSpark:Show()

            self.healSparkGlow:ClearAllPoints()
            self.healSparkGlow:SetPoint("LEFT", healBar, "RIGHT", -12, 0)
            self.healSparkGlow:Show()

            self.healSparkGlowOuter:ClearAllPoints()
            self.healSparkGlowOuter:SetPoint("LEFT", healBar, "RIGHT", -16, 0)
            self.healSparkGlowOuter:Show()

            -- Start pulse animation
            if not self.sparkPulseAnimation then
                self:StartSparkPulseAnimation()
            end
        else
            -- Heal bar is hidden - destroy spark immediately
            self:DestroyHealSpark()
        end
    end

    -- Completely destroy heal spark
    function healthSystem:DestroyHealSpark()
        -- Stop animation
        if self.sparkPulseAnimation then
            self.sparkPulseAnimation:Cancel()
            self.sparkPulseAnimation = nil
        end

        -- Destroy textures completely
        if self.healSpark then
            self.healSpark:Hide()
            self.healSpark:SetTexture(nil)
            self.healSpark = nil
        end
        if self.healSparkGlow then
            self.healSparkGlow:Hide()
            self.healSparkGlow:SetTexture(nil)
            self.healSparkGlow = nil
        end
        if self.healSparkGlowOuter then
            self.healSparkGlowOuter:Hide()
            self.healSparkGlowOuter:SetTexture(nil)
            self.healSparkGlowOuter = nil
        end

        self.healSparkCreated = false
    end

    -- Intense pulse animation for the heal spark with multiple glow layers
    function healthSystem:StartSparkPulseAnimation()
        if not self.healSpark or not self.healSparkGlow or not self.healSparkGlowOuter then return end

        local startTime = GetTime()
        self.sparkPulseAnimation = C_Timer.NewTicker(0.05, function()
            -- Only check if textures still exist (not their visibility)
            if not self.healSpark or not self.healSparkGlow or not self.healSparkGlowOuter then
                if self.sparkPulseAnimation then
                    self.sparkPulseAnimation:Cancel()
                    self.sparkPulseAnimation = nil
                end
                return true
            end

            -- Pulse effect for all layers with different intensities
            local elapsed = GetTime() - startTime
            local pulsePhase = math.sin(elapsed * 4) -- 4 = faster pulse speed

            -- Main spark pulse (opacity from 0.8 to 1.0)
            local mainAlpha = 0.9 + (pulsePhase * 0.1)
            self.healSpark:SetAlpha(mainAlpha)

            -- Inner glow pulse (more dramatic, opacity from 0.3 to 0.6)
            local glowAlpha = 0.45 + (pulsePhase * 0.15)
            self.healSparkGlow:SetAlpha(glowAlpha)

            -- Outer glow pulse (most dramatic, opacity from 0.1 to 0.4)
            local outerGlowAlpha = 0.25 + (pulsePhase * 0.15)
            self.healSparkGlowOuter:SetAlpha(outerGlowAlpha)
        end)
    end

    -- Update absorb bar (EXACT rnxmUI logic from backup/absorbs.lua)
    function healthSystem:UpdateAbsorb()
        -- Check if absorb overlay exists (not available for all units)
        if not self.barSet.overlays or not self.barSet.overlays.absorb then return end

        local absorbBar = self.barSet.overlays.absorb.bar
        if not absorbBar then return end

        local unitToken = self.unit
        local totalAbsorb = UnitGetTotalAbsorbs(unitToken) or 0
        local currentHealth = UnitHealth(unitToken)
        local maxHealth = UnitHealthMax(unitToken)
        local incoming = UnitGetIncomingHeals(unitToken) or 0

        -- If no absorb is present, don't even process the function (EXACT rnxmUI)
        if totalAbsorb <= 0 then
            absorbBar:Hide()
            self:DestroyAbsorbSpark()
            return
        end

        if maxHealth <= 0 then
            absorbBar:Hide()
            self:DestroyAbsorbSpark()
            return
        end

        -- Regular absorb logic (EXACT rnxmUI)
        local missing = maxHealth - currentHealth
        local normalAbsorb = math.min(totalAbsorb, missing)
        local hasOvershield = totalAbsorb > missing
        local absorbWidth = 0  -- Declare outside for spark positioning

        if normalAbsorb > 0 then
            -- Determine the anchor texture based on whether heal prediction is shown (EXACT rnxmUI)
            local anchorTexture = self.bar:GetStatusBarTexture()

            -- If heal prediction is shown, anchor absorb after heal prediction
            if self.barSet.overlays and self.barSet.overlays.healPrediction then
                local healBar = self.barSet.overlays.healPrediction.bar
                if healBar and healBar:IsShown() then
                    anchorTexture = healBar
                end
            end

            -- Calculate absorb width and clamp it to available space (EXACT rnxmUI)
            local healthBarWidth = self.bar:GetWidth()
            local healthPct = currentHealth / maxHealth
            local absorbPct = normalAbsorb / maxHealth

            -- Ensure we don't go beyond the health bar width (EXACT rnxmUI)
            local maxPct = math.min(1.0, healthPct + absorbPct)
            local clampedAbsorbPct = maxPct - healthPct
            absorbWidth = clampedAbsorbPct * healthBarWidth

            -- Position absorb fill immediately after anchor texture (EXACT rnxmUI)
            if absorbWidth > 0 then
                absorbBar:ClearAllPoints()
                absorbBar:SetPoint("LEFT", anchorTexture, "RIGHT", 0, 0)
                absorbBar:SetSize(absorbWidth, self.bar:GetHeight())
                absorbBar:Show()

                -- Set bar value to 100% since we control size manually
                ns.UI.Bar.SetValue(absorbBar, 100, 100)
            else
                absorbBar:Hide()
                absorbWidth = 0
            end
        else
            absorbBar:Hide()
            absorbWidth = 0
        end

        -- Determine absorb mode (normal vs overshield)
        local isOvershield = (currentHealth >= maxHealth and totalAbsorb > 0)

        -- Update overshield visuals for absorbs (EXACT rnxmUI)
        if totalAbsorb > 0 then
            self:UpdateOvershieldVisuals()
            -- Recalculate absorbWidth for overshield case
            if absorbBar:IsShown() then
                absorbWidth = absorbBar:GetWidth()
            end
        end

        -- Update absorb spark (after all positioning is done)
        self:UpdateAbsorbSpark(absorbBar, absorbWidth, isOvershield)
    end

    -- Overshield update method (EXACT rnxmUI from backup/absorbs.lua)
    function healthSystem:UpdateOvershieldVisuals()
        local absorbBar = self.barSet.overlays.absorb.bar
        if not self.unit or not absorbBar then return end

        local health = UnitHealth(self.unit)
        local maxHealth = UnitHealthMax(self.unit)
        local absorb = UnitGetTotalAbsorbs(self.unit) or 0

        if maxHealth <= 0 or absorb <= 0 then
            -- No special overshield visuals needed
            return
        end

        -- Calculate health percentage and position (EXACT rnxmUI)
        local healthPct = health / maxHealth
        local healthWidth = self.bar:GetWidth()
        local healthPixelWidth = healthPct * healthWidth

        -- Calculate absorb percentage
        local absorbPct = absorb / maxHealth

        -- Determine if there's overabsorb OR health is full (EXACT rnxmUI)
        local total = health + absorb
        local overAbsorb = total > maxHealth or (health >= maxHealth and absorb > 0)

        -- Position overlay and clamp width (EXACT rnxmUI)
        if overAbsorb then
            if health >= maxHealth then
                -- Health is 100% - show absorb overlay from RIGHT to LEFT (EXACT rnxmUI)
                local absorbWidth = math.min(absorbPct * healthWidth, healthWidth)

                absorbBar:ClearAllPoints()
                absorbBar:SetPoint("TOPRIGHT", self.bar, "TOPRIGHT", 0, 0)
                absorbBar:SetPoint("BOTTOMRIGHT", self.bar, "BOTTOMRIGHT", 0, 0)
                absorbBar:SetWidth(absorbWidth)
                absorbBar:Show()

                -- Set bar value to 100% since we control size manually
                ns.UI.Bar.SetValue(absorbBar, 100, 100)
            else
                -- True overabsorb - fill remaining space (EXACT rnxmUI)
                local remainingWidth = healthWidth - healthPixelWidth

                absorbBar:ClearAllPoints()
                absorbBar:SetPoint("TOPLEFT", self.bar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
                absorbBar:SetPoint("BOTTOMLEFT", self.bar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
                absorbBar:SetWidth(remainingWidth)
                absorbBar:Show()

                -- Set bar value to 100% since we control size manually
                ns.UI.Bar.SetValue(absorbBar, 100, 100)
            end
        end
    end

    -- Create/update absorb spark based on absorb bar visibility
    function healthSystem:UpdateAbsorbSpark(absorbBar, absorbWidth, isOvershield)
        if not absorbBar then
            self:DestroyAbsorbSpark()
            return
        end

        -- Simple logic: spark visibility = absorb bar visibility
        if absorbBar:IsShown() and absorbWidth and absorbWidth > 0 then
            -- Create spark if it doesn't exist
            if not self.absorbSparkCreated then
                local parent = absorbBar:GetParent()

                -- Outer glow (blue tint)
                self.absorbSparkGlowOuter = parent:CreateTexture(nil, "OVERLAY", nil, 1)
                self.absorbSparkGlowOuter:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\AbsorbSpark.tga")
                self.absorbSparkGlowOuter:SetSize(32, absorbBar:GetHeight() + 12)
                self.absorbSparkGlowOuter:SetVertexColor(0.5, 0.7, 1, 0.2)  -- Blue glow
                self.absorbSparkGlowOuter:SetBlendMode("ADD")

                -- Inner glow (brighter blue)
                self.absorbSparkGlow = parent:CreateTexture(nil, "OVERLAY", nil, 2)
                self.absorbSparkGlow:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\AbsorbSpark.tga")
                self.absorbSparkGlow:SetSize(24, absorbBar:GetHeight() + 8)
                self.absorbSparkGlow:SetVertexColor(0.6, 0.8, 1, 0.4)  -- Brighter blue
                self.absorbSparkGlow:SetBlendMode("ADD")

                -- Main spark (white-blue)
                self.absorbSpark = parent:CreateTexture(nil, "OVERLAY", nil, 3)
                self.absorbSpark:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\AbsorbSpark.tga")
                self.absorbSpark:SetSize(16, absorbBar:GetHeight() + 4)
                self.absorbSpark:SetVertexColor(0.8, 0.9, 1, 1.0)  -- White-blue
                self.absorbSpark:SetBlendMode("ADD")

                self.absorbSparkCreated = true
            end

            -- Position sparks based on absorb mode
            if isOvershield then
                -- OVERSHIELD MODE: Absorb goes RIGHT to LEFT, spark on LEFT edge
                self.absorbSpark:ClearAllPoints()
                self.absorbSpark:SetPoint("RIGHT", absorbBar, "LEFT", 8, 0)
                self.absorbSpark:Show()

                self.absorbSparkGlow:ClearAllPoints()
                self.absorbSparkGlow:SetPoint("RIGHT", absorbBar, "LEFT", 12, 0)
                self.absorbSparkGlow:Show()

                self.absorbSparkGlowOuter:ClearAllPoints()
                self.absorbSparkGlowOuter:SetPoint("RIGHT", absorbBar, "LEFT", 16, 0)
                self.absorbSparkGlowOuter:Show()
            else
                -- NORMAL MODE: Absorb goes LEFT to RIGHT, spark on RIGHT edge
                self.absorbSpark:ClearAllPoints()
                self.absorbSpark:SetPoint("LEFT", absorbBar, "RIGHT", -8, 0)
                self.absorbSpark:Show()

                self.absorbSparkGlow:ClearAllPoints()
                self.absorbSparkGlow:SetPoint("LEFT", absorbBar, "RIGHT", -12, 0)
                self.absorbSparkGlow:Show()

                self.absorbSparkGlowOuter:ClearAllPoints()
                self.absorbSparkGlowOuter:SetPoint("LEFT", absorbBar, "RIGHT", -16, 0)
                self.absorbSparkGlowOuter:Show()
            end

            -- Start pulse animation
            if not self.absorbSparkPulseAnimation then
                self:StartAbsorbSparkPulseAnimation()
            end
        else
            -- Absorb bar is hidden - destroy spark immediately
            self:DestroyAbsorbSpark()
        end
    end

    -- Completely destroy absorb spark
    function healthSystem:DestroyAbsorbSpark()
        -- Stop animation
        if self.absorbSparkPulseAnimation then
            self.absorbSparkPulseAnimation:Cancel()
            self.absorbSparkPulseAnimation = nil
        end

        -- Destroy textures completely
        if self.absorbSpark then
            self.absorbSpark:Hide()
            self.absorbSpark:SetTexture(nil)
            self.absorbSpark = nil
        end
        if self.absorbSparkGlow then
            self.absorbSparkGlow:Hide()
            self.absorbSparkGlow:SetTexture(nil)
            self.absorbSparkGlow = nil
        end
        if self.absorbSparkGlowOuter then
            self.absorbSparkGlowOuter:Hide()
            self.absorbSparkGlowOuter:SetTexture(nil)
            self.absorbSparkGlowOuter = nil
        end

        self.absorbSparkCreated = false
    end

    -- Intense pulse animation for the absorb spark with multiple glow layers
    function healthSystem:StartAbsorbSparkPulseAnimation()
        if not self.absorbSpark or not self.absorbSparkGlow or not self.absorbSparkGlowOuter then return end

        local startTime = GetTime()
        self.absorbSparkPulseAnimation = C_Timer.NewTicker(0.05, function()
            -- Only check if textures still exist (not their visibility)
            if not self.absorbSpark or not self.absorbSparkGlow or not self.absorbSparkGlowOuter then
                if self.absorbSparkPulseAnimation then
                    self.absorbSparkPulseAnimation:Cancel()
                    self.absorbSparkPulseAnimation = nil
                end
                return true
            end

            -- Pulse effect for all layers with different intensities
            local elapsed = GetTime() - startTime
            local pulsePhase = math.sin(elapsed * 4) -- 4 = faster pulse speed

            -- Main spark pulse (opacity from 0.8 to 1.0)
            local mainAlpha = 0.9 + (pulsePhase * 0.1)
            self.absorbSpark:SetAlpha(mainAlpha)

            -- Inner glow pulse (more dramatic, opacity from 0.3 to 0.6)
            local glowAlpha = 0.45 + (pulsePhase * 0.15)
            self.absorbSparkGlow:SetAlpha(glowAlpha)

            -- Outer glow pulse (most dramatic, opacity from 0.1 to 0.4)
            local outerGlowAlpha = 0.25 + (pulsePhase * 0.15)
            self.absorbSparkGlowOuter:SetAlpha(outerGlowAlpha)
        end)
    end

    -- Update visibility based on unit existence
    function healthSystem:UpdateVisibility()
        local parentFrame = self.bar:GetParent()
        local unitExists = UnitExists(self.unit)

        -- Hide frame for optional units that don't exist
        if not unitExists and (self.unit == "target" or self.unit == "focus" or self.unit == "targettarget") then
            if parentFrame then
                parentFrame:Hide()
            end
        elseif unitExists then
            if parentFrame then
                parentFrame:Show()
            end
        end

        return unitExists
    end

    -- Attach text element
    function healthSystem:AttachText(textElement)
        self.textElement = textElement
    end

    -- Set color scheme
    function healthSystem:SetColorScheme(colorByClass, customColor)
        self.config.colorByClass = colorByClass
        self.config.customColor = customColor

        if not colorByClass and customColor then
            ns.UI.Bar.SetColor(self.bar, customColor[1], customColor[2], customColor[3], customColor[4] or 1)
        end

    end

    -- ===========================
    -- EVENT HANDLING
    -- ===========================

    -- Register for health events
    function healthSystem:RegisterEvents()
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("UNIT_HEALTH")
        frame:RegisterEvent("UNIT_MAXHEALTH")
        frame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
        frame:RegisterEvent("UNIT_HEAL_PREDICTION")
        frame:RegisterEvent("PLAYER_TARGET_CHANGED")
        frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
        frame:RegisterEvent("UNIT_PET")

        -- IMPORTANT: WoW doesn't fire UNIT_HEALTH reliably for targettarget/focustarget
        -- We need OnUpdate polling for real-time health updates on these units
        if self.unit == "targettarget" or self.unit == "focustarget" then
            local timeSinceLastUpdate = 0
            local UPDATE_INTERVAL = 0.1  -- Update every 0.1 seconds (10 FPS)

            frame:SetScript("OnUpdate", function(_, elapsed)
                timeSinceLastUpdate = timeSinceLastUpdate + elapsed

                if timeSinceLastUpdate >= UPDATE_INTERVAL then
                    timeSinceLastUpdate = 0

                    if UnitExists(self.unit) then
                        self:UpdateHealth()
                    end
                end
            end)
        end

        frame:SetScript("OnEvent", function(_, event, eventUnit)
            if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
                if eventUnit == self.unit then
                    self:UpdateHealth()
                end
            elseif event == "UNIT_ABSORB_AMOUNT_CHANGED" then
                if eventUnit == self.unit then
                    self:UpdateAbsorb()
                end
            elseif event == "UNIT_HEAL_PREDICTION" then
                if eventUnit == self.unit and self.barSet.overlays and self.barSet.overlays.healPrediction then
                    self:UpdateHealPrediction()
                end
            elseif event == "PLAYER_TARGET_CHANGED" and self.unit == "target" then
                self:UpdateVisibility()
                self:UpdateHealth()
            elseif event == "PLAYER_FOCUS_CHANGED" and self.unit == "focus" then
                self:UpdateVisibility()
                self:UpdateHealth()
            elseif event == "UNIT_PET" and self.unit == "pet" then
                C_Timer.After(0.1, function()
                    self:UpdateVisibility()
                    self:UpdateHealth()
                end)
            elseif event == "PLAYER_TARGET_CHANGED" and self.unit == "targettarget" then
                C_Timer.After(0.1, function()
                    self:UpdateVisibility()
                    self:UpdateHealth()
                end)
            end
        end)

        self.eventFrame = frame
    end

    -- Unregister events
    function healthSystem:UnregisterEvents()
        if self.eventFrame then
            self.eventFrame:UnregisterAllEvents()
            self.eventFrame:SetScript("OnEvent", nil)
            self.eventFrame = nil
        end
    end

    -- Update configuration in real-time
    function healthSystem:UpdateConfig(newHealthConfig)
        if not newHealthConfig or type(newHealthConfig) ~= "table" then
            return
        end

        -- Update bar size
        if self.bar and newHealthConfig.width and newHealthConfig.height then
            self.bar:SetSize(newHealthConfig.width, newHealthConfig.height)
            -- CRITICAL: Update low health warning size to match new bar dimensions
            self:UpdateLowHealthWarningSize()
        end

        -- Update bar texture
        if self.bar and newHealthConfig.texture then
            self.bar:SetStatusBarTexture(newHealthConfig.texture)
        end

        -- Update glass effect
        if self.glassTexture and newHealthConfig.glassEnabled ~= nil then
            if newHealthConfig.glassEnabled then
                self.glassTexture:Show()
                -- Hardcoded glass texture (HPglass from LSM registration)
                self.glassTexture:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\HPglass.tga")
                if newHealthConfig.glassAlpha then
                    self.glassTexture:SetAlpha(newHealthConfig.glassAlpha)
                end
                if newHealthConfig.glassBlendMode then
                    self.glassTexture:SetBlendMode(newHealthConfig.glassBlendMode)
                end
            else
                self.glassTexture:Hide()
            end
        end

        -- Update color by class
        if newHealthConfig.colorByClass ~= nil then
            self.config.colorByClass = newHealthConfig.colorByClass
        end

        -- Force immediate update
        self:UpdateHealth()
    end

    -- ===========================
    -- LIFECYCLE
    -- ===========================

    -- Initialize the system
    function healthSystem:Initialize()
        -- Initialize loss bar to current health to prevent red background at start
        if self.barSet.overlays and self.barSet.overlays.animatedLoss then
            if UnitExists(self.unit) then
                local currentHealth = UnitHealth(self.unit)
                local maxHealth = UnitHealthMax(self.unit)
                self.previousHealth = currentHealth
                ns.UI.Bar.SetValue(self.barSet.overlays.animatedLoss.bar, currentHealth, maxHealth)
            end
        end

        -- Initialize low health warning size to match current bar dimensions
        self:UpdateLowHealthWarningSize()

        self:RegisterEvents()
        self:UpdateVisibility()
        self:UpdateHealth()
    end

    -- Destroy the system
    function healthSystem:Destroy()
        self:UnregisterEvents()

        -- Stop any existing animation ticker
        if self.animationTicker then
            self.animationTicker:Cancel()
            self.animationTicker = nil
        end

        -- Stop any existing delay timer
        if self.lossDelayTimer then
            self.lossDelayTimer:Cancel()
            self.lossDelayTimer = nil
        end

        -- Destroy heal spark completely
        self:DestroyHealSpark()

        -- Destroy absorb spark completely
        self:DestroyAbsorbSpark()

        -- Destroy low health warning overlay
        self:DestroyLowHealthWarning()

        self.textElement = nil
    end

    return healthSystem
end

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================

-- Quick setup function for simple cases
function ns.Systems.Health.Setup(parent, unitToken, config)
    local system = ns.Systems.Health.Create(parent, unitToken, config)
    system:Initialize()
    return system
end


-- api/unitframe.lua - Simple Unified UnitFrame API
local _, ns = ...

-- API namespace
ns.API = ns.API or {}
ns.API.UnitFrame = {}

-- Debug function (can be enabled/disabled)
local ENABLE_DEBUG = true  -- Set to false to disable logs

-- ===========================
-- SIMPLE UNIFIED API - COPY OF WORKING PLAYER.LUA LOGIC
-- ===========================

-- Create complete unitframe - EXACT copy of modules/player.lua logic but generic
function ns.API.UnitFrame.Create(parentFrame, unitToken, customConfig)

    -- Extract base unit type (party1 -> party, target -> target)
    local baseUnitType = unitToken:match("^(%a+)%d*$") or unitToken

    -- Get configuration from unified database system (EXACT copy from player.lua)
    local config = ns.DB.GetUnitConfig(baseUnitType:lower())
    if not config then
        error("Unit configuration not found for " .. baseUnitType .. " - ensure ns.DB.Initialize() was called")
    end

    -- Merge custom config if provided (EXACT copy from player.lua)
    if customConfig then
        for section, sectionConfig in pairs(customConfig) do
            if type(sectionConfig) == "table" and config[section] then
                for key, value in pairs(sectionConfig) do
                    if type(value) == "table" and type(config[section][key]) == "table" then
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

    local unitFrame = {}

    -- ===========================
    -- STRIPPING (depends on unit type)
    -- ===========================

    -- Party frames need individual stripping, others are handled globally
    if baseUnitType == "party" then
        if ns.Core and ns.Core.Stripping and ns.Core.Stripping.StripParty then
            ns.Core.Stripping.StripParty()
        end
    else
    end

    -- ===========================
    -- CREATE SYSTEMS (EXACT copy from player.lua)
    -- ===========================

    -- Create health system with fitParent support for raid
    local healthBarConfig = {
        colorByClass = config.health.colorByClass,
        barConfig = {
            main = {
                texture = config.health.texture,
                frameLevel = 1
            },
            background = {
                texture = config.health.texture,
                color = {0.1, 0.1, 0.1, 0.8}
            },
            mask = {
                maskTexture = config.health.maskTexture
            },
            glass = {
                enabled = config.health.glassEnabled,
                texture = config.health.glassTexture or "Interface\\AddOns\\Nihui_uf\\textures\\glass.tga",
                alpha = config.health.glassAlpha,
                blendMode = "ADD"  -- Hardcoded blend mode
            },
            border = {
                enabled = config.health.borderEnabled,
                edgeFile = "Interface\\AddOns\\Nihui_uf\\textures\\MirroredFrameSingleUF.tga",
                edgeSize = 16,
                color = {0.5, 0.5, 0.5, 1},
                insets = {left = -12, top = 12, right = 12, bottom = -12}  -- Hardcoded insets
            }
        }
    }

    -- FitParent mode for raid: health bar fills parent with percentage
    if config.health.fitParent then
        healthBarConfig.barConfig.main.fitParent = true
        healthBarConfig.barConfig.main.fillPercent = config.health.fillPercent or 0.95
    else
        -- Standard mode: use explicit width/height
        healthBarConfig.barConfig.main.width = config.health.width
        healthBarConfig.barConfig.main.height = config.health.height
    end

    local healthSystem = ns.Systems.Health.Create(parentFrame, unitToken, healthBarConfig)

    -- Position health bar (CENTER for standard, ALL for fitParent)
    if healthSystem and healthSystem.bar then
        healthSystem.bar:ClearAllPoints()
        if config.health.fitParent then
            -- FitParent mode: use SetAllPoints with scale
            local fillPercent = config.health.fillPercent or 0.95
            healthSystem.bar:SetPoint("CENTER", parentFrame, "CENTER", 0, 0)
            -- Size will be set by OnSizeChanged handler in Health system
            healthSystem.bar.fitParent = true
            healthSystem.bar.fillPercent = fillPercent
            healthSystem.bar.parentFrame = parentFrame

            -- Set initial size based on parent
            local parentWidth, parentHeight = parentFrame:GetSize()
            if parentWidth and parentHeight and parentWidth > 0 and parentHeight > 0 then
                healthSystem.bar:SetSize(parentWidth * fillPercent, parentHeight * fillPercent)
            end

            -- Hook parent size changes to update health bar size
            parentFrame:HookScript("OnSizeChanged", function(self, width, height)
                if healthSystem.bar and healthSystem.bar.fitParent then
                    healthSystem.bar:SetSize(width * healthSystem.bar.fillPercent, height * healthSystem.bar.fillPercent)
                end
            end)
        else
            -- Standard mode: CENTER positioning
            healthSystem.bar:SetPoint("CENTER", parentFrame, "CENTER", 0, 0)
        end
    end

    -- Create power system (skip for raid frames entirely)
    local powerSystem = nil
    if baseUnitType ~= "raid" then
        powerSystem = ns.Systems.Power.Create(parentFrame, unitToken, {
            colorByPowerType = config.power.colorByPowerType,
            hideWhenEmpty = config.power.hideWhenEmpty,
            barConfig = {
                main = {
                    width = config.power.width,
                    height = config.power.height,
                    texture = config.power.texture,
                    frameLevel = 2
                },
                background = {
                    texture = config.power.texture,
                    color = {0.1, 0.1, 0.1, 0.8}
                },
                glass = {
                    enabled = config.power.glassEnabled,
                    texture = config.power.glassTexture,
                    alpha = config.power.glassAlpha,
                    blendMode = config.power.glassBlendMode
                },
                border = {
                    enabled = config.power.borderEnabled,
                    edgeFile = "Interface\\AddOns\\Nihui_uf\\textures\\MirroredFrameSingleUF.tga",
                    edgeSize = 16,
                    color = {0.5, 0.5, 0.5, 1},
                    insets = config.power.borderInsets or {left = -12, top = 12, right = 12, bottom = -12}
                }
            }
        })

        -- Position power bar relative to health bar (EXACT copy)
        if healthSystem and healthSystem.bar and powerSystem and powerSystem.bar then
            powerSystem.bar:ClearAllPoints()
            powerSystem.bar:SetPoint("TOP", healthSystem.bar, "BOTTOM", config.power.xOffset or 0, config.power.yOffset or -10)
            -- Set anchor frame reference for real-time updates
            powerSystem:SetAnchorFrame(healthSystem.bar)
        end
    end

    -- Store references
    unitFrame.healthSystem = healthSystem
    unitFrame.powerSystem = powerSystem
    unitFrame.parentFrame = parentFrame
    unitFrame.config = config

    -- Create text system (handle nil powerSystem for raid)
    local powerBar = powerSystem and powerSystem.bar or nil
    local textSet = ns.UI.Text.CreateTextSet(parentFrame, healthSystem.bar, powerBar, config.text)
    unitFrame.texts = textSet
    if textSet then
    end

    local textSystem = ns.Systems.Text.FromTextSet(textSet, unitToken, config.text)

    if textSystem.SetHealthBarReference then
        textSystem:SetHealthBarReference(healthSystem.bar)
    end

    -- CRITICAL: Attach text elements to health/power systems for updates
    if textSet.health and healthSystem.AttachText then
        healthSystem:AttachText(textSet.health)
    end
    if textSet.power and powerSystem and powerSystem.AttachText then
        powerSystem:AttachText(textSet.power)
    end

    unitFrame.textSystem = textSystem
    unitFrame.unitToken = unitToken
    unitFrame.baseUnitType = baseUnitType

    -- Create ClassPower system for player only (like other systems)
    if baseUnitType == "player" and ns.Systems.ClassPower.IsDiscreteClass() then
        local classPowerSystem = ns.Systems.ClassPower.Create(powerSystem.bar, config.classpower)
        if classPowerSystem then
            classPowerSystem:Initialize()
            unitFrame.classPowerSystem = classPowerSystem
        end
    end

    -- Create portrait system if enabled, or hide Blizzard portrait if disabled
    -- Skip portrait creation entirely for raid frames
    if config.portrait and type(config.portrait) == "table" and baseUnitType ~= "raid" then
        if config.portrait.enabled then
            -- Validate portrait config values
            local validatedConfig = {
                offsetX = tonumber(config.portrait.offsetX) or 0,
                offsetY = tonumber(config.portrait.offsetY) or 0,
                scale = tonumber(config.portrait.scale) or 1,
                flip = (config.portrait.flip == true),
                useClassIcon = (config.portrait.useClassIcon == true),
                enabled = true,
                classification = config.portrait.classification,
                states = config.portrait.states
            }

            -- Clamp scale to reasonable values
            validatedConfig.scale = math.max(0.1, math.min(5.0, validatedConfig.scale))

            -- Build complete portrait config with main frame dimensions
            local portraitConfig = {
                main = {
                    width = 70,  -- Base portrait size (will be scaled by portrait.scale)
                    height = 70,
                    frameLevel = 3
                },
                mask = {
                    maskTexture = "Interface\\AddOns\\Nihui_uf\\textures\\circle_mask.tga"
                }
                -- NOTE: overlay is created separately by UpdateOverlay() in portrait system
            }

            -- First create the portrait UI frame (our custom portrait independent of Blizzard)
            local portraitFrame = ns.UI.Portrait.CreateCompletePortrait(parentFrame, portraitConfig)

            if portraitFrame then
                -- Map unitToken to portrait system naming convention
                local unitTokenForPortrait = unitToken:gsub("^%l", string.upper)
                if baseUnitType == "targettarget" then
                    unitTokenForPortrait = "TargetToT"
                elseif baseUnitType == "focustarget" then
                    unitTokenForPortrait = "FocusToT"
                end

                -- Position portrait frame using validated config
                -- If flipped, anchor to TOPRIGHT for more positioning flexibility
                -- If not flipped, anchor to TOPLEFT
                portraitFrame.frame:ClearAllPoints()
                if validatedConfig.flip then
                    portraitFrame.frame:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT",
                        validatedConfig.offsetX,
                        validatedConfig.offsetY)
                else
                    portraitFrame.frame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT",
                        validatedConfig.offsetX,
                        validatedConfig.offsetY)
                end

                -- CRITICAL: Store our custom portrait frame for the portrait system to use
                -- This makes portraits always available (no dependency on Blizzard's dynamic creation)
                ns.Systems.Portrait.StorePortraitFrame(unitTokenForPortrait, portraitFrame)

                -- Create portrait system with the frame (use validated config)
                local portraitSystem = ns.Systems.Portrait.Create(portraitFrame, unitTokenForPortrait, validatedConfig)

                if portraitSystem then
                    portraitSystem:Initialize()
                    unitFrame.portraitSystem = portraitSystem
                end
            end
        else
            -- Portrait disabled - hide Blizzard portrait
            ns.Core.Stripping.HideBlizzardPortrait(parentFrame)
        end
    end

    -- Create aura system if enabled (only for target and focus)
    if config.auras and config.auras.enabled and (baseUnitType == "target" or baseUnitType == "focus") then
        local auraSystem = ns.Systems.Auras.Create(parentFrame, unitToken, config.auras)
        if auraSystem then
            -- Connect auras to power bar for relative positioning
            if powerSystem and powerSystem.bar then
                auraSystem:SetPowerBarReference(powerSystem.bar)
            end
            auraSystem:Initialize()
            unitFrame.auraSystem = auraSystem
        end
    end

    -- ClassPower is handled specifically in player module
    -- (removed from API to avoid duplication)

    -- Add update method for real-time config changes
    function unitFrame:UpdateConfig()
        local newConfig = ns.DB.GetUnitConfig(self.baseUnitType:lower())
        if not newConfig or type(newConfig) ~= "table" then
            return
        end

        self.config = newConfig

        -- Update health system
        if self.healthSystem and self.healthSystem.UpdateConfig and newConfig.health and type(newConfig.health) == "table" then
            self.healthSystem:UpdateConfig(newConfig.health)
        end

        -- Update power system
        if self.powerSystem and self.powerSystem.UpdateConfig and newConfig.power and type(newConfig.power) == "table" then
            self.powerSystem:UpdateConfig(newConfig.power)

            -- Update aura positioning when power bar changes
            if self.auraSystem and self.auraSystem.UpdateContainerPositions then
                self.auraSystem:UpdateContainerPositions()
            end
        end

        -- Update text system
        if self.textSystem and self.textSystem.UpdateConfig and newConfig.text and type(newConfig.text) == "table" then
            self.textSystem:UpdateConfig(newConfig.text)
        end

        -- Update portrait system
        if self.portraitSystem and self.portraitSystem.UpdateConfig and newConfig.portrait and type(newConfig.portrait) == "table" then
            self.portraitSystem:UpdateConfig(newConfig.portrait)
        end

        -- Update ClassPower system (like other systems)
        if self.classPowerSystem and self.classPowerSystem.UpdateConfig and newConfig.classpower and type(newConfig.classpower) == "table" then
            self.classPowerSystem:UpdateConfig(newConfig.classpower)
        end

        -- Update aura system
        if self.auraSystem and self.auraSystem.UpdateConfig and newConfig.auras and type(newConfig.auras) == "table" then
            self.auraSystem:UpdateConfig(newConfig.auras)
        end

    end

    -- Initialize systems (EXACT copy)
    if healthSystem then
        healthSystem:Initialize()
        if healthSystem.bar then
            local w, h = healthSystem.bar:GetSize()
            local x, y = healthSystem.bar:GetLeft() or 0, healthSystem.bar:GetTop() or 0
        end
    end
    if powerSystem then
        powerSystem:Initialize()
        if powerSystem.bar then
            local w, h = powerSystem.bar:GetSize()
            local x, y = powerSystem.bar:GetLeft() or 0, powerSystem.bar:GetTop() or 0
        end
    end
    if textSystem then
        textSystem:Initialize()
    end
    if unitFrame.portraitSystem then
        unitFrame.portraitSystem:Initialize()
    end
    -- ClassPower initialization handled in player module

    -- Register for config refresh system (skip raid/party members - they use module-level refresh)
    if baseUnitType ~= "raid" and baseUnitType ~= "party" then
        ns.API.UnitFrame.RegisterForRefresh(unitToken, unitFrame)
    end

    return unitFrame
end

-- ===========================
-- GLOBAL API REFRESH SYSTEM
-- ===========================

-- Registry of active API-based units for config panel integration
local apiUnitFrames = {}

-- Register API unitframe for config refresh
function ns.API.UnitFrame.RegisterForRefresh(unitToken, unitFrameInstance)
    local baseUnitType = unitToken:match("^(%a+)%d*$") or unitToken
    local key = baseUnitType:lower()
    apiUnitFrames[key] = unitFrameInstance

    -- Debug: print all registered units
    for k, v in pairs(apiUnitFrames) do
    end
end

-- Refresh API unitframe from config panel (used by config/* files)
function ns.API.UnitFrame.RefreshUnit(unitType)
    local unitFrame = apiUnitFrames[unitType:lower()]

    if unitFrame then
        if unitFrame.UpdateConfig then
            unitFrame:UpdateConfig()

            -- Update position and enabled state for targettarget and focustarget
            if unitType == "targettarget" and ns.Modules and ns.Modules.TargetTarget then
                if ns.Modules.TargetTarget.ApplyPosition then
                    ns.Modules.TargetTarget.ApplyPosition()
                end
                if ns.Modules.TargetTarget.ApplyEnabledState then
                    ns.Modules.TargetTarget.ApplyEnabledState()
                end
            elseif unitType == "focustarget" and ns.Modules and ns.Modules.FocusTarget then
                if ns.Modules.FocusTarget.ApplyPosition then
                    ns.Modules.FocusTarget.ApplyPosition()
                end
                if ns.Modules.FocusTarget.ApplyEnabledState then
                    ns.Modules.FocusTarget.ApplyEnabledState()
                end
            end

            return true
        end
    end

    -- Special handling for party module (doesn't use API unitframe registration)
    if unitType == "party" and ns.Modules and ns.Modules.Party then
        if ns.Modules.Party.ApplyGap then
            ns.Modules.Party.ApplyGap()
        end
        return true
    end

    -- Special handling for raid module (refresh ALL raid members)
    if unitType == "raid" and ns.Modules and ns.Modules.Raid then
        if ns.Modules.Raid.RefreshAllMembers then
            ns.Modules.Raid.RefreshAllMembers()
        end
        return true
    end

    return false
end

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================

-- Drag functionality removed - using Blizzard Edit Mode instead

-- Global integration will be done in init.lua to ensure proper timing


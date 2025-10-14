-- ui/effects.lua - UI Components for Visual Effects (Flash, Overlays, Animations)
local _, ns = ...

-- UI Components namespace
ns.UI = ns.UI or {}
ns.UI.Effects = {}

-- ===========================
-- FLASH EFFECT CREATION
-- ===========================

-- Create flash texture with animation
function ns.UI.Effects.CreateFlash(parent, config)
    local flashFrame = CreateFrame("Frame", nil, parent)
    flashFrame:SetAllPoints(parent)
    flashFrame:SetFrameStrata("MEDIUM")
    flashFrame:SetFrameLevel(999) -- Very high to be on top

    -- Create flash texture
    local texture = flashFrame:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints(flashFrame)
    texture:SetDrawLayer("OVERLAY", 7)

    -- Apply configuration
    if config.atlas then
        texture:SetAtlas(config.atlas)
    elseif config.texture then
        texture:SetTexture(config.texture)
    end

    if config.blendMode then
        texture:SetBlendMode(config.blendMode)
    end

    if config.color then
        texture:SetVertexColor(config.color[1], config.color[2], config.color[3], config.color[4] or 1)
    end

    if config.rotation then
        texture:SetRotation(math.rad(config.rotation))
    end

    if config.desaturated then
        texture:SetDesaturated(true)
    end

    -- Create animation group
    local animationGroup = texture:CreateAnimationGroup()
    animationGroup:SetLooping("BOUNCE")

    local alpha = animationGroup:CreateAnimation("Alpha")
    alpha:SetFromAlpha(config.fromAlpha or 0.6)
    alpha:SetToAlpha(config.toAlpha or 1.0)
    alpha:SetDuration(config.duration or 0.8)

    -- Initially hidden
    texture:Hide()

    local flashEffect = {
        frame = flashFrame,
        texture = texture,
        animation = animationGroup,
        config = config
    }

    -- Flash control functions
    function flashEffect:Show()
        self.texture:Show()
        self.animation:Play()
    end

    function flashEffect:Hide()
        self.texture:Hide()
        self.animation:Stop()
    end

    function flashEffect:SetColor(r, g, b, a)
        self.texture:SetVertexColor(r, g, b, a or 1)
    end

    function flashEffect:SetFlip(flipHorizontal, flipVertical)
        local left, right, top, bottom = 0, 1, 0, 1

        if flipHorizontal then
            left, right = right, left
        end

        if flipVertical then
            top, bottom = bottom, top
        end

        self.texture:SetTexCoord(left, right, top, bottom)
    end

    return flashEffect
end

-- ===========================
-- OVERLAY EFFECTS
-- ===========================

-- Create classification overlay (elite, rare, boss)
function ns.UI.Effects.CreateClassificationOverlay(parent, config)
    local overlayFrame = CreateFrame("Frame", nil, parent)
    overlayFrame:SetAllPoints(parent)
    -- Very high frameLevel to be above portrait overlay (border)
    overlayFrame:SetFrameLevel(parent:GetFrameLevel() + 10)

    -- Use highest OVERLAY sublayer (7) to be on top
    local texture = overlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    texture:SetAllPoints(overlayFrame)

    if config.atlas then
        texture:SetAtlas(config.atlas)
    elseif config.texture then
        texture:SetTexture(config.texture)
    end

    if config.color then
        texture:SetVertexColor(config.color[1], config.color[2], config.color[3], config.color[4] or 1)
    end

    if config.blendMode then
        texture:SetBlendMode(config.blendMode)
    end

    -- Initially hidden
    texture:Hide()

    local overlay = {
        frame = overlayFrame,
        texture = texture,
        config = config
    }

    function overlay:Show()
        self.texture:Show()
    end

    function overlay:Hide()
        self.texture:Hide()
    end

    function overlay:SetTexture(textureOrAtlas, isAtlas)
        if isAtlas then
            self.texture:SetAtlas(textureOrAtlas)
        else
            self.texture:SetTexture(textureOrAtlas)
        end
    end

    function overlay:SetColor(r, g, b, a)
        self.texture:SetVertexColor(r, g, b, a or 1)
    end

    return overlay
end

-- ===========================
-- THREAT INDICATORS
-- ===========================

-- Create threat glow effect
function ns.UI.Effects.CreateThreatGlow(parent, config)
    local glowFrame = CreateFrame("Frame", nil, parent)

    -- Position around the parent with padding
    local padding = config.padding or 4
    glowFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", -padding, padding)
    glowFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", padding, -padding)
    glowFrame:SetFrameLevel(parent:GetFrameLevel() + 3)

    local texture = glowFrame:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(glowFrame)

    if config.atlas then
        texture:SetAtlas(config.atlas)
    elseif config.texture then
        texture:SetTexture(config.texture)
    else
        -- Default glow texture
        texture:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    end

    if config.blendMode then
        texture:SetBlendMode(config.blendMode)
    else
        texture:SetBlendMode("ADD")
    end

    -- Initially hidden
    texture:Hide()

    -- Animation for pulsing
    local animationGroup = texture:CreateAnimationGroup()
    animationGroup:SetLooping("BOUNCE")

    local alpha = animationGroup:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0.3)
    alpha:SetToAlpha(0.8)
    alpha:SetDuration(1.0)

    local threatGlow = {
        frame = glowFrame,
        texture = texture,
        animation = animationGroup,
        config = config
    }

    function threatGlow:Show()
        self.texture:Show()
        self.animation:Play()
    end

    function threatGlow:Hide()
        self.texture:Hide()
        self.animation:Stop()
    end

    function threatGlow:SetThreatColor(threatStatus)
        local colors = {
            [0] = {0.69, 0.69, 0.69, 0.8}, -- No threat - gray
            [1] = {1.0, 1.0, 0.47, 0.8},   -- Low threat - yellow
            [2] = {1.0, 0.6, 0.0, 0.8},    -- Medium threat - orange
            [3] = {1.0, 0.0, 0.0, 0.8}     -- High threat - red
        }

        local color = colors[threatStatus] or colors[0]
        self.texture:SetVertexColor(color[1], color[2], color[3], color[4])
    end

    return threatGlow
end

-- ===========================
-- STATUS EFFECTS
-- ===========================

-- Create status indicator (dead, offline, etc.)
function ns.UI.Effects.CreateStatusIndicator(parent, config)
    local statusFrame = CreateFrame("Frame", nil, parent)
    statusFrame:SetAllPoints(parent)
    statusFrame:SetFrameLevel(parent:GetFrameLevel() + 6)

    -- Status texture
    local texture = statusFrame:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints(statusFrame)

    -- Status text
    local text = statusFrame:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", config.fontSize or 16, "OUTLINE")
    text:SetPoint("CENTER", statusFrame, "CENTER")
    text:SetTextColor(1, 1, 1, 1)

    -- Initially hidden
    texture:Hide()
    text:Hide()

    local statusIndicator = {
        frame = statusFrame,
        texture = texture,
        text = text,
        config = config
    }

    function statusIndicator:ShowStatus(statusType, statusText)
        -- Configure based on status type
        if statusType == "dead" then
            self.texture:SetColorTexture(0, 0, 0, 0.8)
            self.text:SetText(statusText or "DEAD")
            self.text:SetTextColor(1, 0, 0, 1)
        elseif statusType == "offline" then
            self.texture:SetColorTexture(0.5, 0.5, 0.5, 0.8)
            self.text:SetText(statusText or "OFFLINE")
            self.text:SetTextColor(0.7, 0.7, 0.7, 1)
        elseif statusType == "ghost" then
            self.texture:SetColorTexture(0.2, 0.2, 0.8, 0.6)
            self.text:SetText(statusText or "GHOST")
            self.text:SetTextColor(0.8, 0.8, 1, 1)
        end

        self.texture:Show()
        self.text:Show()
    end

    function statusIndicator:Hide()
        self.texture:Hide()
        self.text:Hide()
    end

    return statusIndicator
end

-- ===========================
-- ANIMATION UTILITIES
-- ===========================

-- Create fade in/out animation
function ns.UI.Effects.CreateFadeAnimation(frame, fadeIn, duration)
    local animationGroup = frame:CreateAnimationGroup()

    local alpha = animationGroup:CreateAnimation("Alpha")
    if fadeIn then
        alpha:SetFromAlpha(0)
        alpha:SetToAlpha(1)
    else
        alpha:SetFromAlpha(1)
        alpha:SetToAlpha(0)
    end
    alpha:SetDuration(duration or 0.3)

    return animationGroup
end

-- Create scale animation (grow/shrink)
function ns.UI.Effects.CreateScaleAnimation(frame, fromScale, toScale, duration)
    local animationGroup = frame:CreateAnimationGroup()

    local scale = animationGroup:CreateAnimation("Scale")
    scale:SetScaleFrom(fromScale or 0.8, fromScale or 0.8)
    scale:SetScaleTo(toScale or 1.0, toScale or 1.0)
    scale:SetDuration(duration or 0.2)

    return animationGroup
end

-- ===========================
-- EFFECT PRESETS
-- ===========================

-- Get default flash configuration for unit type
function ns.UI.Effects.GetDefaultFlashConfig(unitType)
    local configs = {
        PLAYER = {
            atlas = "Ping_UnitMarker_BG_Threat",
            color = {1, 0.3, 0.3, 0.8},
            rotation = -45,
            blendMode = "ADD",
            fromAlpha = 0.6,
            toAlpha = 1.0,
            duration = 0.8
        },
        TARGET = {
            atlas = "Ping_UnitMarker_BG_Threat",
            color = {1, 0, 0, 1},
            rotation = -45,
            blendMode = "ADD",
            fromAlpha = 0.6,
            toAlpha = 1.0,
            duration = 0.8
        },
        FOCUS = {
            atlas = "glues-characterSelect-card-glow-FX",
            color = {1.0, 0.2, 0.2, 0.7},
            desaturated = true,
            rotation = 0,
            blendMode = "ADD",
            fromAlpha = 0.6,
            toAlpha = 1.0,
            duration = 0.8
        }
    }

    return configs[unitType:upper()] or configs.TARGET
end

-- Get default classification overlay configuration
function ns.UI.Effects.GetDefaultClassificationConfig(classificationType)
    local configs = {
        elite = {
            atlas = "nameplates-icon-elite-gold",
            color = {1, 0.8, 0, 1},
            blendMode = "BLEND"
        },
        rare = {
            atlas = "nameplates-icon-elite-silver",
            color = {0.8, 0.8, 1, 1},
            blendMode = "BLEND"
        },
        rareelite = {
            atlas = "nameplates-icon-elite-silver",
            color = {1, 0.4, 1, 1},
            blendMode = "BLEND"
        },
        worldboss = {
            atlas = "nameplates-icon-elite-gold",
            color = {1, 0, 0, 1},
            blendMode = "BLEND"
        }
    }

    return configs[classificationType] or configs.elite
end
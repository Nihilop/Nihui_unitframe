-- ui/portrait.lua - Generic Portrait UI Components (API générique)
local _, ns = ...

-- UI Components namespace
ns.UI = ns.UI or {}
ns.UI.Portrait = {}

-- ===========================
-- CORE PORTRAIT CREATION (API GÉNÉRIQUE)
-- ===========================

-- Create basic portrait frame
function ns.UI.Portrait.CreateFrame(parent, config)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(config.width or 70, config.height or 70)
    frame:SetFrameLevel(parent:GetFrameLevel() + (config.frameLevel or 1))

    return frame
end

-- Create portrait texture (works with Blizzard portrait or custom)
function ns.UI.Portrait.CreateTexture(portraitFrame, config)
    local texture = portraitFrame:CreateTexture(nil, "ARTWORK")
    -- Inset by 6 pixels on each side to leave room for the overlay border
    texture:SetPoint("TOPLEFT", portraitFrame, "TOPLEFT", 6, -6)
    texture:SetPoint("BOTTOMRIGHT", portraitFrame, "BOTTOMRIGHT", -6, 6)
    texture:SetDrawLayer("ARTWORK", 1)

    return texture
end

-- Create portrait background
function ns.UI.Portrait.CreateBackground(portraitFrame, config)
    if not config.enabled then
        return nil
    end

    local bg = portraitFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(portraitFrame)

    if config.texture then
        bg:SetTexture(config.texture)
    else
        bg:SetColorTexture(config.color and config.color[1] or 0,
                          config.color and config.color[2] or 0,
                          config.color and config.color[3] or 0,
                          config.color and config.color[4] or 0.8)
    end

    if config.color and config.texture then
        bg:SetVertexColor(config.color[1], config.color[2], config.color[3], config.color[4] or 1)
    end

    return bg
end

-- Create portrait mask
function ns.UI.Portrait.CreateMask(portraitFrame, portraitTexture, config)
    if not config.maskTexture or config.maskTexture == "" then
        return nil
    end

    local mask = portraitFrame:CreateMaskTexture()
    mask:SetAllPoints(portraitFrame)
    -- Use CLAMPTOWHITE for proper alpha masking (white = visible, black = hidden)
    mask:SetTexture(config.maskTexture, "CLAMPTOWHITE", "CLAMPTOWHITE")
    portraitTexture:AddMaskTexture(mask)

    return mask
end

-- Create portrait overlay (border/frame around portrait)
function ns.UI.Portrait.CreateOverlay(portraitFrame, config)
    if not config.enabled then
        return nil
    end

    local overlay = portraitFrame:CreateTexture(nil, "OVERLAY")
    overlay:SetAllPoints(portraitFrame)
    overlay:SetTexture(config.texture)
    overlay:SetDrawLayer("OVERLAY", config.layer or 2)

    if config.color then
        overlay:SetVertexColor(config.color[1], config.color[2], config.color[3], config.color[4] or 1)
    end

    return overlay
end

-- Create classification overlay (elite/rare indicators)
function ns.UI.Portrait.CreateClassification(parentFrame, config)
    if not config.enabled then
        return nil
    end

    local classFrame = CreateFrame("Frame", nil, parentFrame)
    classFrame:SetSize(config.width or 70, config.height or 70)
    -- High frameLevel - will be set by caller for proper layering
    classFrame:SetFrameLevel(parentFrame:GetFrameLevel() + 10)
    -- Set highest strata to ensure it's on top
    classFrame:SetFrameStrata("HIGH")

    -- Don't set position here - caller will position it

    -- Base texture
    local baseTex = classFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    baseTex:SetAllPoints(classFrame)

    -- Effect texture (highest sublayer to be on top)
    local effectTex = classFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    effectTex:SetAllPoints(classFrame)

    local classSet = {
        frame = classFrame,
        baseTexture = baseTex,
        effectTexture = effectTex,
        config = config
    }

    return classSet
end

-- ===========================
-- COMPOSITE PORTRAIT CREATION
-- ===========================

-- Create complete portrait with all components
function ns.UI.Portrait.CreateCompletePortrait(parent, config)
    local portraitSet = {}

    -- Main frame
    portraitSet.frame = ns.UI.Portrait.CreateFrame(parent, config.main or {})

    -- Background
    if config.background then
        portraitSet.background = ns.UI.Portrait.CreateBackground(portraitSet.frame, config.background)
    end

    -- Portrait texture
    portraitSet.texture = ns.UI.Portrait.CreateTexture(portraitSet.frame, config.texture or {})

    -- Mask
    if config.mask then
        portraitSet.mask = ns.UI.Portrait.CreateMask(portraitSet.frame, portraitSet.texture, config.mask)
    end

    -- Overlay (border/frame)
    if config.overlay then
        portraitSet.overlay = ns.UI.Portrait.CreateOverlay(portraitSet.frame, config.overlay)
    end

    -- Classification - create on PARENT, not on portraitFrame, for proper layering
    if config.classification then
        -- Handle boolean config (true = { enabled = true })
        local classificationConfig = config.classification
        if type(classificationConfig) == "boolean" and classificationConfig then
            classificationConfig = { enabled = true }
        end
        -- Create on parent, but position relative to portraitSet.frame
        portraitSet.classification = ns.UI.Portrait.CreateClassification(parent, classificationConfig)
        -- Position it on the portrait frame
        if portraitSet.classification and portraitSet.classification.frame then
            portraitSet.classification.frame:ClearAllPoints()
            portraitSet.classification.frame:SetPoint("CENTER", portraitSet.frame, "CENTER", 0, 0)
            -- Set very high frameLevel
            portraitSet.classification.frame:SetFrameLevel(portraitSet.frame:GetFrameLevel() + 20)
        end
    end

    -- Store configuration
    portraitSet.config = config

    return portraitSet
end

-- ===========================
-- PORTRAIT MANIPULATION
-- ===========================

-- Position portrait
function ns.UI.Portrait.SetPosition(portraitFrame, anchor, anchorTo, relativePoint, x, y)
    portraitFrame:ClearAllPoints()
    portraitFrame:SetPoint(anchor, anchorTo, relativePoint, x or 0, y or 0)
end

-- Scale portrait
function ns.UI.Portrait.SetScale(portraitFrame, scale)
    portraitFrame:SetScale(scale or 1)
end

-- Update portrait texture for unit
function ns.UI.Portrait.UpdateTexture(portraitTexture, unit, useClassIcon)
    -- Validate inputs
    if not portraitTexture or not unit then
        return false
    end

    -- Wrap texture updates in pcall for error safety
    local success, result = pcall(function()
        if useClassIcon and UnitExists(unit) and UnitIsPlayer(unit) then
            local _, class = UnitClass(unit)
            if class then
                portraitTexture:SetAtlas("UI-HUD-UnitFrame-Player-Portrait-ClassIcon-" .. class)
                return true
            end
        end

        -- Use standard portrait
        if UnitExists(unit) then
            SetPortraitTexture(portraitTexture, unit, true)
            return true
        else
            portraitTexture:SetTexture(nil)
            return false
        end
    end)

    if not success then
        -- Silently fail and clear texture on error
        pcall(function() portraitTexture:SetTexture(nil) end)
        return false
    end

    return result or false
end

-- Apply portrait flip
function ns.UI.Portrait.SetFlip(portraitTexture, flip)
    if not portraitTexture or not portraitTexture.SetTexCoord then
        return false
    end

    if flip then
        portraitTexture:SetTexCoord(1, 0, 0, 1) -- Flipped
    else
        portraitTexture:SetTexCoord(0, 1, 0, 1) -- Normal
    end

    return true
end

-- Update classification overlay
function ns.UI.Portrait.UpdateClassification(classSet, unit, classificationData)
    if not classSet or not classSet.frame or not unit then
        return false
    end

    if not UnitExists(unit) then
        classSet.frame:Hide()
        return false
    end

    local classification = UnitClassification(unit)
    local level = UnitLevel(unit)

    -- Determine classification type
    local classType = "normal"
    if classification == "elite" then
        classType = "elite"
    elseif classification == "rareelite" then
        classType = "rareelite"
    elseif classification == "rare" then
        classType = "rare"
    elseif classification == "worldboss" or (classification == "normal" and level == -1) then
        classType = "worldboss"
    end

    if classType == "normal" then
        classSet.frame:Hide()
        return false
    end

    -- Get classification settings
    local texture = classificationData.textures and classificationData.textures[classType]
    local color = classificationData.colors and classificationData.colors[classType]
    local blendMode = classificationData.blendModes and classificationData.blendModes[classType]

    if texture then
        classSet.baseTexture:SetTexture(texture)
        classSet.effectTexture:SetTexture(texture)

        if color then
            classSet.baseTexture:SetVertexColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, 1)
            classSet.effectTexture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
        end

        if blendMode then
            classSet.effectTexture:SetBlendMode(blendMode)
        end

        classSet.frame:Show()
        return true
    end

    classSet.frame:Hide()
    return false
end

-- Apply portrait desaturation
function ns.UI.Portrait.SetDesaturated(portraitTexture, desaturated)
    if portraitTexture and portraitTexture.SetDesaturated then
        portraitTexture:SetDesaturated(desaturated)
        return true
    end
    return false
end

-- Apply portrait color tint
function ns.UI.Portrait.SetVertexColor(portraitTexture, r, g, b, a)
    if portraitTexture and portraitTexture.SetVertexColor then
        portraitTexture:SetVertexColor(r, g, b, a or 1)
        return true
    end
    return false
end


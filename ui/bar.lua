-- ui/bar.lua - Generic Bar UI Components (API générique)
local _, ns = ...


-- UI Components namespace
ns.UI = ns.UI or {}
ns.UI.Bar = {}

-- Disable border debug prints
    -- Border debug disabled for clean logs

-- ===========================
-- CORE BAR CREATION (API GÉNÉRIQUE)
-- ===========================

-- Create basic StatusBar frame
function ns.UI.Bar.CreateBar(parent, config)
    local frame = CreateFrame("StatusBar", nil, parent)
    frame:SetSize(config.width or 100, config.height or 20)
    frame:SetStatusBarTexture(config.texture or "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga")
    frame:SetMinMaxValues(0, 100)
    frame:SetValue(100)
    frame:SetFrameLevel(parent:GetFrameLevel() + (config.frameLevel or 1))

    return frame
end

-- Create bar background
function ns.UI.Bar.CreateBackground(barFrame, config)
    local bg = barFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(config.texture or "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga")
    bg:SetAllPoints(barFrame)
    bg:SetVertexColor(config.color and config.color[1] or 0.1,
                      config.color and config.color[2] or 0.1,
                      config.color and config.color[3] or 0.1,
                      config.color and config.color[4] or 0.8)

    return bg
end

-- Create bar mask
function ns.UI.Bar.CreateMask(barFrame, config)
    if not config.maskTexture then
        return nil
    end

    local mask = barFrame:CreateMaskTexture()
    mask:SetAllPoints(barFrame)
    mask:SetTexture(config.maskTexture, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    barFrame:GetStatusBarTexture():AddMaskTexture(mask)

    return mask
end

-- Create glass overlay (EXACT rnxmUI with texture slicing)
function ns.UI.Bar.CreateGlass(barFrame, config)
    if not config.enabled then
        return nil
    end

    local glass = barFrame:CreateTexture(nil, "ARTWORK", nil, 7)

    -- Get texture path (HARDCODED - no longer configurable)
    local texturePath = "Interface\\AddOns\\Nihui_uf\\textures\\HPglass.tga"  -- HARDCODED

    glass:SetTexture(texturePath)
    glass:SetPoint("TOPLEFT", barFrame, "TOPLEFT", 0, 0)
    glass:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", 0, 0)

    -- CRITICAL: Texture slicing (EXACT rnxmUI)
    glass:SetTextureSliceMargins(16, 16, 16, 16)
    glass:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)

    glass:SetAlpha(config.alpha or 0.2)  -- Alpha still configurable
    glass:SetBlendMode("ADD")  -- HARDCODED

    return glass
end

-- Create border with backdrop (EXACT rnxmUI)
function ns.UI.Bar.CreateBorder(barFrame, config)
    if not config.enabled then
        return nil
    end

    local border = CreateFrame("Frame", nil, barFrame, "BackdropTemplate")
    -- Border insets (HARDCODED - no longer configurable)
    local leftInset = -12   -- HARDCODED
    local topInset = 12     -- HARDCODED
    local rightInset = 12   -- HARDCODED
    local bottomInset = -12 -- HARDCODED

    border:SetPoint("TOPLEFT", barFrame, "TOPLEFT", leftInset, topInset)
    border:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", rightInset, bottomInset)

    -- Border backdrop (HARDCODED - no longer configurable)
    border:SetBackdrop({
        edgeFile = "Interface\\AddOns\\Nihui_uf\\textures\\MirroredFrameSingleUF.tga",  -- HARDCODED
        edgeSize = 16,  -- HARDCODED
        insets = {left = 1, right = 1, top = 1, bottom = 1}  -- HARDCODED
    })

    -- Border color (HARDCODED - no longer configurable)
    border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)  -- HARDCODED
    border:SetFrameLevel(barFrame:GetFrameLevel() + 2)

    -- Force show
    border:Show()


    -- Create border highlight if configured
    local highlight = nil
    if config.highlight and config.highlight.enabled then
        highlight = border:CreateTexture(nil, "OVERLAY", nil, 7)
        highlight:SetTexture(config.highlight.texture or "Interface\\AddOns\\Nihui_uf\\textures\\borderHL.tga")
        highlight:SetPoint("TOPLEFT", border, "TOPLEFT",
                          config.highlight.insets and config.highlight.insets.left or 25,
                          config.highlight.insets and config.highlight.insets.top or -12)
        highlight:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT",
                          config.highlight.insets and config.highlight.insets.right or -25,
                          config.highlight.insets and config.highlight.insets.bottom or 12)
        highlight:SetVertexColor(config.highlight.color and config.highlight.color[1] or 0.8,
                               config.highlight.color and config.highlight.color[2] or 0.8,
                               config.highlight.color and config.highlight.color[3] or 0.8,
                               config.highlight.color and config.highlight.color[4] or 1)
        highlight:SetAlpha(config.highlight.alpha or 0.75)
        highlight:SetBlendMode(config.highlight.blendMode or "ADD")
    end

    return border, highlight
end

-- Create overlay bar (for absorb, loss, etc.)
function ns.UI.Bar.CreateOverlayBar(mainBar, config)
    if not config.enabled then
        return nil
    end

    local overlayFrame = CreateFrame("StatusBar", nil, mainBar)
    overlayFrame:SetAllPoints(mainBar)
    overlayFrame:SetStatusBarTexture(config.texture or "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga")
    overlayFrame:SetFrameLevel(mainBar:GetFrameLevel() + (config.frameLevelOffset or 0))
    overlayFrame:SetMinMaxValues(0, 100)
    overlayFrame:SetValue(config.value or 0)

    -- IMPORTANT: Create a transparent background to remove WoW's default black background
    local bg = overlayFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(overlayFrame)
    bg:SetColorTexture(0, 0, 0, 0)  -- Fully transparent

    -- Set color
    if config.color then
        overlayFrame:SetStatusBarColor(config.color[1], config.color[2], config.color[3], config.color[4] or 1)
    end

    -- Make the statusbar texture brighter with blend mode
    local statusBarTexture = overlayFrame:GetStatusBarTexture()
    if statusBarTexture then
        statusBarTexture:SetBlendMode("BLEND")
    end

    -- Create overlay texture if configured (follows the filled part of the bar)
    local overlay = nil
    if config.overlayTexture and statusBarTexture then
        overlay = overlayFrame:CreateTexture(nil, "OVERLAY")
        overlay:SetAllPoints(statusBarTexture)  -- Attach to StatusBarTexture, not the frame
        overlay:SetTexture(config.overlayTexture)
        overlay:SetBlendMode(config.overlayBlendMode or "BLEND")

        -- Make sure the overlay is visible with vertex color
        overlay:SetVertexColor(1, 1, 1, 1)  -- White tint, fully opaque

        -- Apply texture slicing like glass effect (in case it needs it)
        if overlay.SetTextureSliceMargins then
            overlay:SetTextureSliceMargins(8, 8, 8, 8)
            overlay:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        end
    end

    return overlayFrame, overlay
end

-- ===========================
-- COMPOSITE BAR CREATION
-- ===========================

-- Create complete bar with all components
function ns.UI.Bar.CreateCompleteBar(parent, config)
    local barSet = {}

    -- Main bar
    barSet.main = ns.UI.Bar.CreateBar(parent, config.main or {})

    -- Background
    if config.background then
        barSet.background = ns.UI.Bar.CreateBackground(barSet.main, config.background)
    end

    -- Mask
    if config.mask then
        barSet.mask = ns.UI.Bar.CreateMask(barSet.main, config.mask)
    end

    -- Glass overlay
    if config.glass then
        barSet.glass = ns.UI.Bar.CreateGlass(barSet.main, config.glass)
    end

    -- Border
    if config.border then
        barSet.border, barSet.borderHighlight = ns.UI.Bar.CreateBorder(barSet.main, config.border)
    end

    -- Overlay bars (absorb, loss, etc.)
    barSet.overlays = {}
    if config.overlays then
        for name, overlayConfig in pairs(config.overlays) do
            barSet.overlays[name] = {}
            barSet.overlays[name].bar, barSet.overlays[name].texture = ns.UI.Bar.CreateOverlayBar(barSet.main, overlayConfig)
        end
    end

    return barSet
end

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================

-- Position bar
function ns.UI.Bar.SetPosition(frame, anchor, anchorTo, relativePoint, x, y)
    frame:ClearAllPoints()
    frame:SetPoint(anchor, anchorTo, relativePoint, x or 0, y or 0)
end

-- Scale bar
function ns.UI.Bar.SetScale(frame, scale)
    frame:SetScale(scale or 1)
end

-- Set bar value
function ns.UI.Bar.SetValue(barFrame, value, maxValue)
    if barFrame and barFrame.SetMinMaxValues and barFrame.SetValue then
        if maxValue then
            barFrame:SetMinMaxValues(0, maxValue)
        end
        barFrame:SetValue(value or 0)
    end
end

-- Set bar color
function ns.UI.Bar.SetColor(barFrame, r, g, b, a)
    if barFrame and barFrame.SetStatusBarColor then
        barFrame:SetStatusBarColor(r, g, b, a or 1)
    end
end

-- Animate bar value from old to new (smooth transition)
function ns.UI.Bar.AnimateValue(barFrame, oldValue, newValue, maxValue, duration)
    if not barFrame then return end

    -- Cancel any existing animation ticker to prevent multiple animations
    if barFrame.animationTicker then
        barFrame.animationTicker:Cancel()
        barFrame.animationTicker = nil
    end

    duration = duration or 0.5
    local startTime = GetTime()
    local range = newValue - oldValue

    -- Set max value
    if maxValue then
        barFrame:SetMinMaxValues(0, maxValue)
    end

    -- Create ticker for smooth animation and store reference
    -- OPTIMIZED: 0.033s (~30 FPS) instead of 0.01s (100 FPS) - still very smooth
    barFrame.animationTicker = C_Timer.NewTicker(0.033, function()
        local elapsed = GetTime() - startTime
        local progress = math.min(elapsed / duration, 1)

        -- Ease out cubic for smooth deceleration
        local eased = 1 - math.pow(1 - progress, 3)
        local currentValue = oldValue + (range * eased)

        barFrame:SetValue(currentValue)

        -- Stop when complete
        if progress >= 1 then
            barFrame:SetValue(newValue)
            barFrame.animationTicker = nil -- Cleanup
            return true -- Cancel ticker
        end
    end)
end



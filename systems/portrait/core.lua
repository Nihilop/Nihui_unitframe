-- systems/portrait/core.lua - Portrait System Logic (rnxmUI style refactored)
local _, ns = ...

-- Systems namespace
ns.Systems = ns.Systems or {}
ns.Systems.Portrait = {}

-- Storage for overlay frames (rnxmUI style)
local overlayFrames = {}
local activeOverlays = {}

-- Classification data (exact rnxmUI style)
local CLASSIFICATION_TEXTURES = {
    elite = "Interface\\AddOns\\Nihui_uf\\textures\\elite_class1.tga",
    rareelite = "Interface\\AddOns\\Nihui_uf\\textures\\elite_class1.tga",
    rare = "Interface\\AddOns\\Nihui_uf\\textures\\elite_class1.tga",
    worldboss = "Interface\\AddOns\\Nihui_uf\\textures\\elite_class1.tga",
}

local CLASSIFICATION_BLEND_MODES = {
    elite = "ADD",
    rareelite = "ADD",
    rare = "BLEND",
    worldboss = "ADD",
    normal = "BLEND",
}

local CLASSIFICATION_COLORS = {
    elite = {1, 0.7, 0.3, 1},
    rareelite = {0.5, 0.3, 1, 1},
    rare = {0.5, 0.5, 1, 1},
    worldboss = {1, 0.2, 0.2, 1},
    normal = {1, 1, 1, 0.8},
}

-- ===========================
-- HELPER FUNCTIONS (rnxmUI style)
-- ===========================

-- Get unit string for API calls
local function GetUnitString(unit)
    if unit == "TargetToT" then return "targettarget"
    elseif unit == "FocusToT" then return "focustarget"
    else return unit:lower() end
end

-- Set portrait or class icon (exact rnxmUI)
local function SetPortraitOrClassIcon(portrait, unitString, settings)
    if settings.useClassIcon and UnitExists(unitString) and UnitIsPlayer(unitString) then
        local _, class = UnitClass(unitString)
        if class then
            portrait:SetAtlas("UI-HUD-UnitFrame-Player-Portrait-ClassIcon-" .. class)
            return
        end
    end
    SetPortraitTexture(portrait, unitString, true)
end

-- Get unit classification (exact rnxmUI)
local function GetUnitClassification(unit)
    if not UnitExists(unit) then return "normal" end

    local classification = UnitClassification(unit)
    local level = UnitLevel(unit)

    if classification == "elite" then return "elite"
    elseif classification == "rareelite" then return "rareelite"
    elseif classification == "rare" then return "rare"
    elseif classification == "worldboss" then return "worldboss"
    elseif classification == "normal" and level == -1 then return "worldboss"
    else return "normal" end
end

-- Create or get overlay frame (exact rnxmUI)
local function CreateOrGetOverlayFrame(unit, overlayType, parent, layer)
    if not overlayFrames[unit] then
        overlayFrames[unit] = {}
    end

    if not overlayFrames[unit][overlayType] then
        local frameName = "Nihui" .. unit .. overlayType:gsub("^%l", string.upper) .. "Overlay"
        local frame = CreateFrame("Frame", frameName, parent)

        local layerOffsets = {
            background = -2,
            overlay = 1,
            classification = 10,  -- Très haut pour être visible au-dessus de tout
            flash = 15  -- Combat state toujours au-dessus de tout
        }

        local layerOffset = layerOffsets[overlayType] or (layer or 1)
        local parentLevel = parent:GetFrameLevel()
        local targetLevel = math.max(0, math.min(65535, parentLevel + layerOffset))

        frame:SetFrameLevel(targetLevel)

        overlayFrames[unit][overlayType] = {
            frame = frame,
            textures = {}
        }

        _G[frameName] = frame
    end

    return overlayFrames[unit][overlayType]
end

-- Clean up portrait textures (exact rnxmUI)
local function CleanupPortraitTextures(unit, portrait)
    if portrait and portrait.nihuiMask then
        portrait:RemoveMaskTexture(portrait.nihuiMask)
        portrait.nihuiMask:Hide()
        portrait.nihuiMask:SetTexture(nil)
        portrait.nihuiMask = nil
    end

    if overlayFrames[unit] then
        for overlayType, overlayData in pairs(overlayFrames[unit]) do
            if overlayData.frame then
                overlayData.frame:Hide()
            end
        end
    end
end

-- Get portrait frame reference (rnxmUI style)
local function GetPortraitFrame(unit)
    if unit == "Player" and PlayerFrame and PlayerFrame.PlayerFrameContainer then
        return PlayerFrame.PlayerFrameContainer.PlayerPortrait
    elseif unit == "Target" and TargetFrame and TargetFrame.TargetFrameContainer then
        return TargetFrame.TargetFrameContainer.Portrait
    elseif unit == "Focus" and FocusFrame and FocusFrame.TargetFrameContainer then
        return FocusFrame.TargetFrameContainer.Portrait
    elseif unit == "TargetToT" and TargetFrameToT then
        return TargetFrameToT.Portrait
    elseif unit == "FocusToT" and FocusFrameToT then
        return FocusFrameToT.Portrait
    elseif unit == "Pet" and PetFrame then
        return PetFrame.portrait
    elseif unit:match("^Party%d$") and _G["PartyFrame"] then
        -- Party1 -> MemberFrame1, Party2 -> MemberFrame2, etc.
        local memberIndex = unit:match("^Party(%d)$")
        if memberIndex and _G["PartyFrame"]["MemberFrame" .. memberIndex] then
            return _G["PartyFrame"]["MemberFrame" .. memberIndex].Portrait
        end
    end
    return nil
end

-- Get portrait container (rnxmUI style)
local function GetPortraitContainer(unit)
    if unit == "Player" and PlayerFrame and PlayerFrame.PlayerFrameContainer then
        return PlayerFrame.PlayerFrameContainer
    elseif unit == "Target" and TargetFrame and TargetFrame.TargetFrameContainer then
        return TargetFrame.TargetFrameContainer
    elseif unit == "Focus" and FocusFrame and FocusFrame.TargetFrameContainer then
        return FocusFrame.TargetFrameContainer
    elseif unit == "TargetToT" and TargetFrameToT then
        return TargetFrameToT
    elseif unit == "FocusToT" and FocusFrameToT then
        return FocusFrameToT
    elseif unit == "Pet" and PetFrame then
        return PetFrame
    elseif unit:match("^Party%d$") and _G["PartyFrame"] then
        -- Party1 -> MemberFrame1, Party2 -> MemberFrame2, etc.
        local memberIndex = unit:match("^Party(%d)$")
        if memberIndex and _G["PartyFrame"]["MemberFrame" .. memberIndex] then
            return _G["PartyFrame"]["MemberFrame" .. memberIndex]
        end
    end
    return nil
end

-- Relocate HitIndicator (damage/heal numbers) to custom portrait
local function RelocateHitIndicator(unit, customPortraitFrame)
    if not customPortraitFrame then return end

    -- Find the Blizzard HitIndicator (try multiple locations)
    local hitIndicator = nil
    local searchPaths = {}

    if unit == "Player" and PlayerFrame then
        searchPaths = {
            PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HitIndicator,
            PlayerFrame.HitIndicator,
            _G["PlayerFrameHitIndicator"]
        }
    elseif unit == "Target" and TargetFrame then
        searchPaths = {
            TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain and TargetFrame.TargetFrameContent.TargetFrameContentMain.HitIndicator,
            TargetFrame.TargetFrameContainer and TargetFrame.TargetFrameContainer.HitIndicator,
            TargetFrame.HitIndicator,
            _G["TargetFrameHitIndicator"]
        }
    elseif unit == "Focus" and FocusFrame then
        searchPaths = {
            FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentMain and FocusFrame.TargetFrameContent.TargetFrameContentMain.HitIndicator,
            FocusFrame.TargetFrameContainer and FocusFrame.TargetFrameContainer.HitIndicator,
            FocusFrame.HitIndicator,
            _G["FocusFrameHitIndicator"]
        }
    elseif unit == "Pet" and PetFrame then
        searchPaths = {
            PetFrame.HitIndicator,
            _G["PetFrameHitIndicator"]
        }
    end

    -- Find first valid HitIndicator
    for _, indicator in ipairs(searchPaths) do
        if indicator and indicator.SetParent then
            hitIndicator = indicator
            break
        end
    end

    -- Relocate HitIndicator to custom portrait if found
    if hitIndicator and hitIndicator.SetParent then
        pcall(function()
            hitIndicator:SetParent(customPortraitFrame)
            hitIndicator:ClearAllPoints()
            hitIndicator:SetPoint("CENTER", customPortraitFrame, "CENTER", 0, 0)
            hitIndicator:SetFrameLevel(customPortraitFrame:GetFrameLevel() + 20)  -- High level to be on top

            -- Force visibility settings
            hitIndicator:Show()
            hitIndicator:SetAlpha(1)

            -- Ensure all child textures/fontstrings are visible
            if hitIndicator.text then
                hitIndicator.text:Show()
                hitIndicator.text:SetAlpha(1)
            end

        end)
    else
        -- Debug: Print if not found
    end
end

-- ===========================
-- PORTRAIT SYSTEM CORE (rnxmUI style)
-- ===========================

-- Apply portrait settings (NEW: Uses our custom portrait frames instead of Blizzard's)
function ns.Systems.Portrait.ApplyPortraitSettings(unit, customConfig)
    -- Validate input
    if not unit or type(unit) ~= "string" or unit == "" then
        return
    end

    -- Wrap entire function in pcall for error safety
    local success, err = pcall(function()
        -- Get settings from existing config system or use custom config
        local rawSettings = customConfig
        if not rawSettings then
            -- Try to get from active module config (if module is running)
            if ns.GetActiveModuleNew then
                local module = ns.GetActiveModuleNew(unit:lower())
                if module and module.config and module.config.portrait then
                    rawSettings = module.config.portrait
                end
            end

            -- Fallback to default values
            if not rawSettings then
                local defaults = {
                    Player = { offsetX = -65, offsetY = -15, scale = 1, flip = false, useClassIcon = false },
                    Target = { offsetX = 65, offsetY = -15, scale = 1, flip = true, useClassIcon = false },
                    Focus = { offsetX = 65, offsetY = -15, scale = 1, flip = true, useClassIcon = false },
                    Pet = { offsetX = 65, offsetY = 0, scale = 0.8, flip = false, useClassIcon = false },
                    TargetToT = { offsetX = 65, offsetY = -15, scale = 0.7, flip = true, useClassIcon = false },
                    FocusToT = { offsetX = 65, offsetY = -15, scale = 0.7, flip = true, useClassIcon = false }
                }
                rawSettings = defaults[unit] or defaults.Target
            end
        end

    -- Check if portrait is enabled - EARLY EXIT if disabled
    if rawSettings and rawSettings.enabled == false then
        -- Hide our custom portrait if it exists
        if overlayFrames[unit] and overlayFrames[unit].portraitFrame then
            overlayFrames[unit].portraitFrame.frame:Hide()
        end

        -- Hide overlay frames and states when disabled
        if overlayFrames[unit] then
            if overlayFrames[unit].overlay then
                overlayFrames[unit].overlay.frame:Hide()
            end
            if overlayFrames[unit].classification then
                overlayFrames[unit].classification.frame:Hide()
            end
            if overlayFrames[unit].flash then
                overlayFrames[unit].flash.frame:Hide()
            end
        end

        return -- Exit early when disabled
    end

    -- NEW: Get OUR custom portrait frame (created by API, always exists)
    local portraitFrame = overlayFrames[unit] and overlayFrames[unit].portraitFrame
    if not portraitFrame or not portraitFrame.texture then
        return  -- Portrait frame not created by API yet
    end

    local portraitTexture = portraitFrame.texture
    local unitString = GetUnitString(unit)

    -- Convert Nihui_uf config format to settings
    local settings = {
        x = rawSettings.offsetX or 0,
        y = rawSettings.offsetY or 0,
        scale = rawSettings.scale or 1,
        flip = (rawSettings.flip == true),
        useClassIcon = rawSettings.useClassIcon or false,
        baseWidth = 70,
        baseHeight = 70,
        offsetX = 0,  -- Overlay offset
        offsetY = -2,
        overlayTexture = "Interface\\AddOns\\Nihui_uf\\textures\\portraits\\Portrait.tga",
        showOverlay = true,
        showClassification = (rawSettings.classification == true),
        showStates = (rawSettings.states == true),
        states = {
            flash = {
                enabled = true,
                showInCombat = true,
                showOnThreat = false,
                matchPortraitFlip = true,
                atlas = "Ping_GroundMarker_Stroke_Warning",
                color = {1, 0.3, 0.3, 0.8},
                rotation = -160,  -- Auto-inverted to -45 if portrait is flipped
                scale = 1,  -- Scale relative to portrait size (1.0 = same size as portrait)
                offsetX = -2,  -- Horizontal offset relative to portrait center
                offsetY = 5,  -- Vertical offset relative to portrait center
                blendMode = "ADD",
                fromAlpha = 0.6,
                toAlpha = 1.0,
                duration = 0.8
            }
        },
        flashEnabled = true
    }

    -- NEW: Update OUR portrait texture using Blizzard API (2D portrait)
    if not UnitExists(unitString) then
        portraitTexture:SetTexture(nil)
    else
        ns.UI.Portrait.UpdateTexture(portraitTexture, unitString, settings.useClassIcon)
    end

    -- Position and scale OUR portrait frame
    -- If flipped, anchor to TOPRIGHT for more positioning flexibility
    -- If not flipped, anchor to TOPLEFT
    portraitFrame.frame:ClearAllPoints()
    if settings.flip then
        portraitFrame.frame:SetPoint("TOPRIGHT", portraitFrame.frame:GetParent(), "TOPRIGHT", settings.x, settings.y)
    else
        portraitFrame.frame:SetPoint("TOPLEFT", portraitFrame.frame:GetParent(), "TOPLEFT", settings.x, settings.y)
    end
    portraitFrame.frame:SetScale(settings.scale)
    portraitFrame.frame:Show()

    -- Apply flip using SetTexCoord on OUR texture
    ns.UI.Portrait.SetFlip(portraitTexture, settings.flip)

    -- Re-parent HitIndicator (damage/heal numbers) to our custom portrait
    RelocateHitIndicator(unit, portraitFrame.frame)

    -- Update overlay (border around portrait)
    if settings.showOverlay ~= false then
        UpdateOverlay(unit, portraitFrame.frame:GetParent(), portraitFrame.frame, settings)
    else
        if overlayFrames[unit] and overlayFrames[unit].overlay then
            overlayFrames[unit].overlay.frame:Hide()
        end
    end

    -- Update classification for non-player units
    if unit == "Target" or unit == "Focus" or unit == "TargetToT" or unit == "FocusToT" or unit == "Pet" then
        UpdateClassificationOverlay(unit, portraitFrame.frame:GetParent(), portraitFrame.frame, settings)
    end

    -- Background texture for certain units
    if unit == "Target" or unit == "Focus" or unit == "Pet" then
        CreateBackgroundTexture(unit, portraitFrame.frame:GetParent(), portraitFrame.frame, settings)
    end

    -- States system (combat flash, etc.)
    if settings.showStates == true then
        UpdateStatesSystem(unit, portraitFrame.frame:GetParent(), portraitFrame.frame, settings)
    else
        if overlayFrames[unit] and overlayFrames[unit].flash then
            overlayFrames[unit].flash.frame:Hide()
        end
    end
    end) -- end pcall

    -- Log errors if they occur
    if not success and err then
        print("|cFFFF0000[Nihui_uf Portrait Error]|r Failed to apply portrait settings for " .. (unit or "unknown") .. ": " .. tostring(err))
    end
end

-- Update overlay with caching (rnxmUI style)
function UpdateOverlay(unit, container, portrait, settings)
    if not container or not portrait or not settings then return end

    local key = unit .. "_overlay"
    local currentKey = tostring(settings.baseWidth or 100) .. "_" .. tostring(settings.scale or 1) .. "_" .. tostring(settings.flip or false) .. "_" .. tostring(settings.overlayTexture or "")

    -- Only recreate if settings actually changed
    if activeOverlays[key] == currentKey and overlayFrames[unit] and overlayFrames[unit].overlay then
        overlayFrames[unit].overlay.frame:Show()
        return
    end

    CreateOverlayFrame(unit, container, portrait, settings)
    activeOverlays[key] = currentKey
end

-- Create overlay frame (rnxmUI style)
function CreateOverlayFrame(unit, parent, anchor, settings)
    if not parent or not anchor then return end

    -- CRITICAL: Create overlay as CHILD of portrait frame (anchor), not parent
    local overlayData = CreateOrGetOverlayFrame(unit, "overlay", anchor)  -- Use default layer from layerOffsets
    local overlayFrame = overlayData.frame

    if not overlayData.textures.main then
        overlayData.textures.main = overlayFrame:CreateTexture(nil, "OVERLAY", nil, 1)  -- Base sublayer for overlay
    end

    local tex = overlayData.textures.main

    -- Always update texture
    local texture = settings.overlayTexture or "Interface\\AddOns\\Nihui_uf\\textures\\Portrait.tga"
    tex:SetTexture(texture)
    tex:SetAllPoints(overlayFrame)

    local w = (settings.baseWidth or 100) * (settings.scale or 1)
    local h = (settings.baseHeight or 70) * (settings.scale or 1)

    overlayFrame:SetSize(w, h)
    overlayFrame:ClearAllPoints()
    -- CRITICAL: Anchor overlay to completely cover the portrait frame
    overlayFrame:SetAllPoints(anchor)

    if settings.flip then
        tex:SetTexCoord(1, 0, 0, 1)
    else
        tex:SetTexCoord(0, 1, 0, 1)
    end

    overlayFrame:Show()
end

-- Update classification with caching (rnxmUI style)
function UpdateClassificationOverlay(unit, container, portrait, settings)
    if not container or not portrait or not settings then return end

    local key = unit .. "_classification"
    local unitName = GetUnitString(unit)
    local classification = GetUnitClassification(unitName)
    -- Include position, rotation, and flip in cache key to detect changes
    local currentKey = classification .. "_" ..
                      tostring(settings.classificationScale or 1.25) .. "_" ..
                      tostring(settings.classificationOffsetY or 8) .. "_" ..
                      tostring(settings.flip or false)

    if activeOverlays[key] == currentKey and overlayFrames[unit] and overlayFrames[unit].classification then
        if classification ~= "normal" and settings.showClassification ~= false then
            overlayFrames[unit].classification.frame:Show()
        else
            overlayFrames[unit].classification.frame:Hide()
        end
        return
    end

    -- Cache changed - destroy and recreate classification frame completely
    if overlayFrames[unit] and overlayFrames[unit].classification then
        local classFrame = overlayFrames[unit].classification
        if classFrame.frame then
            classFrame.frame:Hide()
            classFrame.frame:SetParent(nil)
            classFrame.frame:ClearAllPoints()
        end
        if classFrame.textures then
            for _, tex in pairs(classFrame.textures) do
                if tex.SetTexture then
                    tex:SetTexture(nil)
                end
            end
        end
        overlayFrames[unit].classification = nil
    end

    CreateClassificationOverlay(unit, container, portrait, settings)
    activeOverlays[key] = currentKey
end

-- Create classification overlay (rnxmUI style)
function CreateClassificationOverlay(unit, parent, anchor, settings)
    if not parent or not anchor or not settings then return end
    if settings.showClassification == false then return end

    local unitName = GetUnitString(unit)
    local classification = GetUnitClassification(unitName)
    if classification == "normal" then return end

    local texturePath = CLASSIFICATION_TEXTURES[classification]
    if not texturePath then return end

    local overlayData = CreateOrGetOverlayFrame(unit, "classification", parent, 3)
    local classFrame = overlayData.frame

    if not overlayData.textures.base then
        overlayData.textures.base = classFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    end
    if not overlayData.textures.effect then
        overlayData.textures.effect = classFrame:CreateTexture(nil, "OVERLAY", nil, 2)
    end

    local baseTex = overlayData.textures.base
    local effectTex = overlayData.textures.effect

    baseTex:SetTexture(texturePath)
    baseTex:SetAllPoints(classFrame)

    effectTex:SetTexture(texturePath)
    effectTex:SetAllPoints(classFrame)

    local blendMode = settings.classificationBlendMode or CLASSIFICATION_BLEND_MODES[classification] or "BLEND"
    effectTex:SetBlendMode(blendMode)

    local color = CLASSIFICATION_COLORS[classification]
    baseTex:SetVertexColor(color[1] * 0.9, color[2] * 0.9, color[3] * 0.9, 1)
    effectTex:SetVertexColor(color[1], color[2], color[3], color[4] * 1)

    local scale = (settings.scale or 1) * (settings.classificationScale or 1.25)
    local baseW = (settings.baseWidth or 100) * scale
    local baseH = (settings.baseHeight or 70) * scale

    classFrame:SetSize(baseW, baseH)
    classFrame:ClearAllPoints()
    classFrame:SetPoint("CENTER", anchor, "CENTER",
        (settings.offsetX or 0) + (settings.classificationOffsetX or 0),
        (settings.offsetY or -2) + (settings.classificationOffsetY or 2))

    -- Apply rotation based on portrait flip setting
    -- Rotation 180° pour que l'angle pointe en bas
    local coords
    if settings.flip then
        -- Portrait flippé (Target, Focus, etc.) : rotation 180° + flip
        coords = {0, 1, 1, 0}  -- 180° rotation avec flip horizontal
    else
        -- Portrait normal (Player, Pet) : rotation 180°
        coords = {1, 0, 1, 0}  -- 180° rotation
    end

    baseTex:SetTexCoord(unpack(coords))
    effectTex:SetTexCoord(unpack(coords))

    classFrame:Show()
end

-- Create background texture (rnxmUI style)
function CreateBackgroundTexture(unit, parent, anchor, settings)
    if not parent or not anchor or not settings then return end

    local overlayData = CreateOrGetOverlayFrame(unit, "background", parent, -1)

    if not overlayData.textures.main then
        overlayData.textures.main = overlayData.frame:CreateTexture(nil, "BACKGROUND", nil, -1)
        overlayData.textures.main:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\TPortrait.tga")
        overlayData.textures.main:SetDesaturated(true)
    end

    local bg = overlayData.textures.main
    bg:SetVertexColor(1, 1, 1, 0)

    local scale = settings.scale or 1
    local baseW = settings.baseWidth or 70
    local baseH = settings.baseHeight or 70

    local scaleFactor = 0.85
    local w = baseW * scale * scaleFactor
    local h = baseH * scale * scaleFactor

    overlayData.frame:SetSize(w, h)
    overlayData.frame:ClearAllPoints()
    overlayData.frame:SetPoint("CENTER", anchor, "CENTER", settings.offsetX or 0, settings.offsetY or -2)

    if settings.flip then
        bg:SetTexCoord(0, 1, 0, 1)
    else
        bg:SetTexCoord(1, 0, 0, 1)
    end

    overlayData.frame:Show()
end

-- ===========================
-- STATES SYSTEM (Combat flash, threat, etc.)
-- ===========================

-- Update states system (combat flash)
function UpdateStatesSystem(unit, parent, portrait, settings)
    if not parent or not portrait or not settings then return end

    -- Create combat flash if enabled
    if settings.flashEnabled or (settings.states and settings.states.flash and settings.states.flash.enabled) then
        UpdateCombatFlash(unit, parent, portrait, settings)
    else
        -- Hide existing flash
        if overlayFrames[unit] and overlayFrames[unit].flash then
            overlayFrames[unit].flash.frame:Hide()
        end
    end
end

-- Create/update combat flash overlay
function UpdateCombatFlash(unit, parent, portrait, settings)
    local flashConfig = settings.states and settings.states.flash or {}

    local overlayData = CreateOrGetOverlayFrame(unit, "flash", parent, 4)
    local flashFrame = overlayData.frame

    if not overlayData.textures.flash then
        overlayData.textures.flash = flashFrame:CreateTexture(nil, "OVERLAY", nil, 4)
    end

    local flashTexture = overlayData.textures.flash

    -- Configure flash texture
    local atlas = flashConfig.atlas or "Ping_UnitMarker_BG_Threat"
    local color = flashConfig.color or {1, 0.3, 0.3, 0.8}

    flashTexture:SetAtlas(atlas)
    flashTexture:SetAllPoints(flashFrame)
    flashTexture:SetVertexColor(color[1], color[2], color[3], color[4] or 0.8)
    flashTexture:SetBlendMode(flashConfig.blendMode or "ADD")

    -- Size and position flash relative to portrait
    local flashScale = flashConfig.scale or 1.2
    local scale = (settings.scale or 1) * flashScale
    local w = (settings.baseWidth or 70) * scale
    local h = (settings.baseHeight or 70) * scale

    flashFrame:SetSize(w, h)
    flashFrame:ClearAllPoints()

    -- Apply position offset relative to portrait center
    local offsetX = flashConfig.offsetX or 0
    local offsetY = flashConfig.offsetY or 0
    flashFrame:SetPoint("CENTER", portrait, "CENTER", offsetX, offsetY)

    -- Apply rotation with auto-inversion for flipped portraits
    if flashConfig.rotation then
        local rotation = flashConfig.rotation
        -- Invert rotation if portrait is flipped
        if settings.flip then
            rotation = -rotation
        end
        -- Convert degrees to radians for SetRotation
        local rotationRadians = math.rad(rotation)
        flashTexture:SetRotation(rotationRadians)
    else
        -- No rotation configured
        flashTexture:SetRotation(0)
    end

    -- Keep normal texture coordinates (no flip)
    flashTexture:SetTexCoord(0, 1, 0, 1)

    -- Store flash reference for state updates
    if not overlayFrames[unit].flashData then
        overlayFrames[unit].flashData = {
            texture = flashTexture,
            frame = flashFrame,
            config = flashConfig,
            unit = unit
        }
    end

    -- Update flash state based on combat
    UpdateFlashState(unit)
end

-- Update flash visibility based on combat state
function UpdateFlashState(unit)
    if not overlayFrames[unit] or not overlayFrames[unit].flashData then
        return
    end

    local flashData = overlayFrames[unit].flashData
    local config = flashData.config
    local shouldShow = false

    -- Check combat state
    local unitString = GetUnitString(unit)
    if UnitExists(unitString) then
        if config.showInCombat and UnitAffectingCombat(unitString) then
            shouldShow = true
        end

        -- For player, also check global combat state
        if unit == "Player" and config.showInCombat and InCombatLockdown() then
            shouldShow = true
        end
    end

    -- Show/hide flash with animation
    if shouldShow then
        flashData.frame:Show()
        StartFlashAnimation(flashData)
    else
        flashData.frame:Hide()
        StopFlashAnimation(flashData)
    end
end

-- Start flash animation
function StartFlashAnimation(flashData)
    if flashData.animation then
        return  -- Already animating
    end

    local config = flashData.config
    local fromAlpha = config.fromAlpha or 0.6
    local toAlpha = config.toAlpha or 1.0
    local duration = config.duration or 0.8

    -- Simple fade in/out animation
    local startTime = GetTime()
    flashData.animation = C_Timer.NewTicker(0.05, function()
        local elapsed = GetTime() - startTime
        local progress = (elapsed % duration) / duration

        -- Sine wave for smooth pulsing
        local alpha = fromAlpha + (toAlpha - fromAlpha) * (0.5 + 0.5 * math.sin(progress * math.pi * 2))
        flashData.texture:SetAlpha(alpha)
    end)
end

-- Stop flash animation
function StopFlashAnimation(flashData)
    if flashData.animation then
        flashData.animation:Cancel()
        flashData.animation = nil
    end
    flashData.texture:SetAlpha(0)
end

-- ===========================
-- MODULE INTERFACE
-- ===========================

-- Store custom portrait frame for a unit (used by API to store our custom portraits)
function ns.Systems.Portrait.StorePortraitFrame(unit, portraitFrame)
    if not overlayFrames[unit] then
        overlayFrames[unit] = {}
    end
    overlayFrames[unit].portraitFrame = portraitFrame
end

-- Remove stored portrait frame for a unit (forces recreation)
function ns.Systems.Portrait.RemovePortraitFrame(unit)
    if not unit then return end

    -- Clean up ALL overlay frames for this unit (overlay, classification, flash, etc.)
    if overlayFrames[unit] then
        for overlayType, overlayData in pairs(overlayFrames[unit]) do
            if overlayData.frame then
                overlayData.frame:Hide()
                -- Clean up textures
                if overlayData.textures then
                    for _, tex in pairs(overlayData.textures) do
                        if tex.SetTexture then
                            tex:SetTexture(nil)
                        end
                        if tex.Hide then
                            tex:Hide()
                        end
                    end
                end
            end
        end
        -- Clear entire overlayFrames entry for this unit
        overlayFrames[unit] = nil
    end

    -- Clear active overlays cache
    for key, _ in pairs(activeOverlays) do
        if key:match("^" .. unit .. "_") then
            activeOverlays[key] = nil
        end
    end
end

-- Create portrait system for a unit (simplified, delegates to ApplyPortraitSettings)
function ns.Systems.Portrait.Create(portraitFrame, unitToken, config)
    local portraitSystem = {}
    portraitSystem.unit = unitToken
    portraitSystem.config = config or {}

    -- Apply settings immediately
    function portraitSystem:Initialize()
        ns.Systems.Portrait.ApplyPortraitSettings(self.unit, self.config)
        self:RegisterEvents()
    end

    function portraitSystem:UpdatePortrait()
        ns.Systems.Portrait.ApplyPortraitSettings(self.unit, self.config)
    end

    -- Update configuration and refresh portrait
    function portraitSystem:UpdateConfig(newConfig)
        self.config = newConfig or self.config
        self:UpdatePortrait()
    end

    function portraitSystem:RegisterEvents()
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
        frame:RegisterEvent("PLAYER_TARGET_CHANGED")
        frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
        frame:RegisterEvent("UNIT_PET")
        frame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Entering combat
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Leaving combat
        frame:RegisterEvent("UNIT_COMBAT")

        frame:SetScript("OnEvent", function(_, event, eventUnit)
            if event == "UNIT_PORTRAIT_UPDATE" and eventUnit == GetUnitString(self.unit) then
                self:UpdatePortrait()
            elseif event == "PLAYER_TARGET_CHANGED" and self.unit == "Target" then
                activeOverlays["Target_classification"] = nil
                activeOverlays["Target_overlay"] = nil
                self:UpdatePortrait()
            elseif event == "PLAYER_FOCUS_CHANGED" and self.unit == "Focus" then
                activeOverlays["Focus_classification"] = nil
                activeOverlays["Focus_overlay"] = nil
                self:UpdatePortrait()
            elseif event == "UNIT_PET" and self.unit == "Pet" then
                C_Timer.After(0.1, function()
                    activeOverlays["Pet_classification"] = nil
                    activeOverlays["Pet_overlay"] = nil
                    self:UpdatePortrait()
                end)
            elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "UNIT_COMBAT" then
                -- Update combat states for flash effects
                UpdateFlashState(self.unit)
            end
        end)

        self.eventFrame = frame
    end

    function portraitSystem:UnregisterEvents()
        if self.eventFrame then
            self.eventFrame:UnregisterAllEvents()
            self.eventFrame:SetScript("OnEvent", nil)
            self.eventFrame = nil
        end
    end

    function portraitSystem:Destroy()
        self:UnregisterEvents()

        -- Clean up our custom portrait frame
        if overlayFrames[self.unit] and overlayFrames[self.unit].portraitFrame then
            local portraitFrame = overlayFrames[self.unit].portraitFrame
            if portraitFrame.frame then
                portraitFrame.frame:Hide()
                portraitFrame.frame:SetParent(nil)
            end
            overlayFrames[self.unit].portraitFrame = nil
        end

        -- Clean up all overlay frames
        if overlayFrames[self.unit] then
            for overlayType, overlayData in pairs(overlayFrames[self.unit]) do
                if overlayData.frame then
                    overlayData.frame:Hide()
                end
            end
        end
    end

    return portraitSystem
end

-- Hook portrait mask updates (rnxmUI style)
function ns.Systems.Portrait.HookPortraitMaskUpdates()
    hooksecurefunc("UnitFramePortrait_Update", function(self)
        if not self or not self.unit or not self.portrait then return end

        local unit = self.unit
        local tag = unit == "targettarget" and "TargetToT"
                  or unit == "focustarget" and "FocusToT"
                  or unit == "pet" and "Pet"
                  or unit:sub(1,1):upper() .. unit:sub(2)

        -- Clean up old mask
        if self.portrait.nihuiMask then
            self.portrait:RemoveMaskTexture(self.portrait.nihuiMask)
            self.portrait.nihuiMask:Hide()
            self.portrait.nihuiMask:SetTexture(nil)
            self.portrait.nihuiMask = nil
        end

        -- Update portrait settings (let it use default behavior to find config)
        ns.Systems.Portrait.ApplyPortraitSettings(tag, nil)
    end)
end

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================

-- Quick setup function
function ns.Systems.Portrait.Setup(portraitFrame, unitToken, config)
    local system = ns.Systems.Portrait.Create(portraitFrame, unitToken, config)
    system:Initialize()
    return system
end

-- Get portrait frame for unit
function ns.Systems.Portrait.GetPortraitFrame(unit)
    return GetPortraitFrame(unit)
end

-- Check if unit supports portraits
function ns.Systems.Portrait.SupportsPortrait(unitToken)
    local supportedUnits = {
        Player = true,
        Target = true,
        Focus = true,
        Pet = true,
        TargetToT = true,
        FocusToT = true
    }
    return supportedUnits[unitToken] or false
end

-- Clear portrait cache for specific unit (forces fresh portrait on next update)
function ns.Systems.Portrait.ClearPortraitCache(unit)
    if not unit then return end

    -- Clear all active overlay caches for this unit
    for key, _ in pairs(activeOverlays) do
        if key:match("^" .. unit .. "_") then
            activeOverlays[key] = nil
        end
    end

    -- Clear overlay frames for this unit
    if overlayFrames[unit] then
        for overlayType, overlayData in pairs(overlayFrames[unit]) do
            -- Keep portraitFrame (our custom frame), but clear everything else
            if overlayType ~= "portraitFrame" and overlayData.frame then
                overlayData.frame:Hide()
                if overlayData.textures then
                    for _, tex in pairs(overlayData.textures) do
                        if tex.SetTexture then
                            tex:SetTexture(nil)
                        end
                    end
                end
            end
        end
    end
end

-- Force refresh all portraits (useful when settings change)
function ns.Systems.Portrait.RefreshAllPortraits()
    -- Clear all overlay caches to force recreation
    activeOverlays = {}

    -- Apply settings for all supported units
    local units = {"Player", "Target", "Focus", "Pet", "TargetToT", "FocusToT"}
    for _, unit in ipairs(units) do
        ns.Systems.Portrait.ApplyPortraitSettings(unit, nil)
    end

end

-- Slash command for testing
SLASH_REFRESHPORTRAITS1 = "/refreshportraits"
SLASH_REFRESHPORTRAITS2 = "/rp"

SlashCmdList["REFRESHPORTRAITS"] = function()
    ns.Systems.Portrait.RefreshAllPortraits()
end
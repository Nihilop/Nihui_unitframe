-- modules/xp.lua - XP/Reputation Bar Module
local _, ns = ...

-- Module namespace
ns.Modules = ns.Modules or {}
ns.Modules.XP = {}

local xpBar = nil
local repBar = nil

-- ===========================
-- INITIALIZATION
-- ===========================

function ns.Modules.XP.Initialize()
    -- Strip Blizzard XP/Rep bars (hide their content but keep containers for Edit Mode)
    if ns.Core and ns.Core.StrippingXP then
        ns.Core.StrippingXP.StripAll()
    end

    -- Get configuration
    local xpConfig = ns.DB.Get("xp") or ns.Config.GetDefault("xp")
    local repConfig = ns.DB.Get("reputation") or ns.Config.GetDefault("reputation")

    -- Check if XP bar is enabled
    if not xpConfig or xpConfig.enabled == false then
        return
    end

    -- Create XP bar system inside Blizzard's native container
    if ns.Systems and ns.Systems.XP and MainStatusTrackingBarContainer then
        xpBar = ns.Systems.XP.Create(MainStatusTrackingBarContainer, xpConfig)

        if xpBar then
            -- Create text element if enabled
            if xpConfig.text and xpConfig.text.enabled ~= false then
                local textElement = ns.Modules.XP.CreateTextElement(xpBar.bar, xpConfig.text)
                xpBar:AttachText(textElement)
            end

            -- Initialize the XP bar
            xpBar:Initialize()
        end
    end

    -- Create Reputation bar system (if enabled)
    if repConfig and repConfig.enabled ~= false then
        if ns.Systems and ns.Systems.XP and ns.Systems.XP.CreateReputation and SecondaryStatusTrackingBarContainer then
            repBar = ns.Systems.XP.CreateReputation(SecondaryStatusTrackingBarContainer, repConfig)

            if repBar then
                -- Create text element if enabled
                if repConfig.text and repConfig.text.enabled ~= false then
                    local textElement = ns.Modules.XP.CreateTextElement(repBar.bar, repConfig.text)
                    repBar:AttachText(textElement)
                end

                -- Initialize the reputation bar
                repBar:Initialize()
            end
        end
    end
end

-- ===========================
-- TEXT ELEMENT CREATION
-- ===========================

function ns.Modules.XP.CreateTextElement(barFrame, textConfig)
    if not barFrame or not textConfig then return nil end

    -- Create a dedicated frame for text with high frame level (above rested/preview bars)
    -- This ensures text is always visible on top
    local textFrame = CreateFrame("Frame", nil, barFrame)
    textFrame:SetAllPoints(barFrame)
    textFrame:SetFrameLevel(barFrame:GetFrameLevel() + 10) -- Higher than rested (+1) and preview (+2) bars

    -- Create text element on the dedicated frame
    local textElement = textFrame:CreateFontString(nil, "OVERLAY")
    textElement:SetFont(textConfig.font or "Fonts\\FRIZQT__.TTF", textConfig.size or 10, textConfig.outline or "OUTLINE")
    textElement:SetTextColor(
        textConfig.color and textConfig.color[1] or 1,
        textConfig.color and textConfig.color[2] or 1,
        textConfig.color and textConfig.color[3] or 1,
        textConfig.color and textConfig.color[4] or 1
    )

    -- Position based on text position setting
    local position = textConfig.position or "center"
    textElement:ClearAllPoints()

    if position == "left" then
        textElement:SetPoint("LEFT", textFrame, "LEFT", 5, 0)
        textElement:SetJustifyH("LEFT")
    elseif position == "right" then
        textElement:SetPoint("RIGHT", textFrame, "RIGHT", -5, 0)
        textElement:SetJustifyH("RIGHT")
    elseif position == "center" then
        textElement:SetPoint("CENTER", textFrame, "CENTER", 0, 0)
        textElement:SetJustifyH("CENTER")
    elseif position == "none" then
        textFrame:Hide()
    end

    return textElement
end

-- ===========================
-- PUBLIC METHODS
-- ===========================

function ns.Modules.XP.Show()
    if xpBar and xpBar.bar then
        xpBar.bar:Show()
    end
    if repBar and repBar.bar then
        -- Reputation bar visibility is controlled by faction tracking
        -- Just make sure it's allowed to show
        repBar:UpdateReputation()
    end
end

function ns.Modules.XP.Hide()
    if xpBar and xpBar.bar then
        xpBar.bar:Hide()
    end
    if repBar and repBar.bar then
        repBar.bar:Hide()
    end
end

function ns.Modules.XP.UpdateConfig()
    -- Get updated configuration
    local xpConfig = ns.DB.Get("xp") or ns.Config.GetDefault("xp")
    local repConfig = ns.DB.Get("reputation") or ns.Config.GetDefault("reputation")

    -- Update XP bar configuration
    if xpBar then
        xpBar:UpdateConfig(xpConfig)

        -- Update text element
        if xpConfig.text and xpConfig.text.enabled ~= false then
            if xpBar.textElement then
                -- Update existing text element
                ns.Modules.XP.UpdateTextElement(xpBar.textElement, xpConfig.text, xpBar.bar)
            else
                -- Create new text element
                local textElement = ns.Modules.XP.CreateTextElement(xpBar.bar, xpConfig.text)
                xpBar:AttachText(textElement)
            end
        else
            -- Hide text element
            if xpBar.textElement then
                xpBar.textElement:Hide()
            end
        end
    end

    -- Update Reputation bar configuration
    if repBar then
        repBar:UpdateConfig(repConfig)

        -- Update text element
        if repConfig.text and repConfig.text.enabled ~= false then
            if repBar.textElement then
                -- Update existing text element
                ns.Modules.XP.UpdateTextElement(repBar.textElement, repConfig.text, repBar.bar)
            else
                -- Create new text element
                local textElement = ns.Modules.XP.CreateTextElement(repBar.bar, repConfig.text)
                repBar:AttachText(textElement)
            end
        else
            -- Hide text element
            if repBar.textElement then
                repBar.textElement:Hide()
            end
        end
    end
end

function ns.Modules.XP.UpdateTextElement(textElement, textConfig, barFrame)
    if not textElement or not textConfig then return end

    -- Get text frame (parent of textElement)
    local textFrame = textElement:GetParent()

    -- Update font
    textElement:SetFont(textConfig.font or "Fonts\\FRIZQT__.TTF", textConfig.size or 10, textConfig.outline or "OUTLINE")
    textElement:SetTextColor(
        textConfig.color and textConfig.color[1] or 1,
        textConfig.color and textConfig.color[2] or 1,
        textConfig.color and textConfig.color[3] or 1,
        textConfig.color and textConfig.color[4] or 1
    )

    -- Update position
    local position = textConfig.position or "center"
    textElement:ClearAllPoints()

    if position == "left" then
        textElement:SetPoint("LEFT", textFrame, "LEFT", 5, 0)
        textElement:SetJustifyH("LEFT")
        textElement:Show()
        if textFrame then textFrame:Show() end
    elseif position == "right" then
        textElement:SetPoint("RIGHT", textFrame, "RIGHT", -5, 0)
        textElement:SetJustifyH("RIGHT")
        textElement:Show()
        if textFrame then textFrame:Show() end
    elseif position == "center" then
        textElement:SetPoint("CENTER", textFrame, "CENTER", 0, 0)
        textElement:SetJustifyH("CENTER")
        textElement:Show()
        if textFrame then textFrame:Show() end
    elseif position == "none" then
        textElement:Hide()
        if textFrame then textFrame:Hide() end
    end
end

function ns.Modules.XP.Destroy()
    -- Destroy XP bar
    if xpBar then
        xpBar:Destroy()
        xpBar = nil
    end

    -- Destroy Reputation bar
    if repBar then
        repBar:Destroy()
        repBar = nil
    end

    -- Restore Blizzard XP/Rep bars
    if ns.Core and ns.Core.StrippingXP then
        ns.Core.StrippingXP.RestoreAll()
    end
end

-- ===========================
-- DEBUG / TESTING
-- ===========================

-- Slash command for testing
SLASH_XPBAR1 = "/xpbar"
SlashCmdList["XPBAR"] = function(msg)
    if msg == "show" then
        ns.Modules.XP.Show()
        print("|cff00ff00Nihui_uf:|r XP/Rep bars shown")
    elseif msg == "hide" then
        ns.Modules.XP.Hide()
        print("|cff00ff00Nihui_uf:|r XP/Rep bars hidden")
    elseif msg == "reload" then
        ns.Modules.XP.Destroy()
        C_Timer.After(0.5, function()
            ns.Modules.XP.Initialize()
        end)
        print("|cff00ff00Nihui_uf:|r XP/Rep bars reloading...")
    elseif msg == "config" then
        ns.Modules.XP.UpdateConfig()
        print("|cff00ff00Nihui_uf:|r XP/Rep bars config updated")
    else
        print("|cff00ff00Nihui_uf XP Bar Commands:|r")
        print("  /xpbar show - Show XP/Rep bars")
        print("  /xpbar hide - Hide XP/Rep bars")
        print("  /xpbar reload - Reload XP/Rep bars")
        print("  /xpbar config - Update configuration")
    end
end


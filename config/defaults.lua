-- config/defaults.lua - Unified Default Configuration System
local _, ns = ...

-- Config namespace
ns.Config = ns.Config or {}

-- ===========================
-- UNIFIED DEFAULT CONFIGURATION
-- ===========================

-- Single source of truth for all default values
ns.Config.Defaults = {
    unitframes = {
        -- ===========================
        -- PLAYER CONFIGURATION
        -- ===========================
        player = {
            health = {
                width = 200,
                height = 30,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                colorByClass = true,
                glassEnabled = true,
                glassAlpha = 0.5,
                animatedLossEnabled = true,
                absorbEnabled = true,
                healPredictionEnabled = true
            },
            power = {
                enabled = true,
                width = 80,
                height = 13,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                xOffset = -59,
                yOffset = -10,
                colorByPowerType = true,
                hideWhenEmpty = false,
                glassEnabled = true,
                glassAlpha = 1
            },
            text = {
                health = {
                    enabled = true,
                    style = "percent",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 12,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 0,
                    y = -1
                },
                power = {
                    enabled = true,
                    style = "percent",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 7,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 0,
                    y = -1,
                    colorByPowerType = false
                },
                -- NAME & LEVEL SYSTEM (backup logic)
                nameLevel = {
                    enabled = true,      -- Enable/disable entire name & level system
                    containerOffset = {
                        x = 0,           -- Container X offset from health bar
                        y = 0            -- Container Y offset from health bar
                    }
                },
                level = {
                    enabled = true,      -- Enable level element
                    show = true,         -- Show level visibility toggle
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 12,
                    outline = "OUTLINE",
                    color = {1, 1, 0, 1}, -- Yellow for level
                    colorByClass = false -- Level never uses class color
                },
                name = {
                    enabled = true,      -- Enable name element
                    show = true,         -- Show name visibility toggle
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 12,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    colorByClass = true, -- Name can use class color
                    truncate = true      -- Enable intelligent truncation
                }
            },
            portrait = {
                enabled = true,
                scale = 1,
                offsetX = -65,
                offsetY = 0,
                flip = false,
                classification = false,
                useClassIcon = false,
                states = true
            },
            classpower = {
                enabled = true,
                scale = 0.7,
                offsetX = 143,
                offsetY = 20
            }
        },

        -- ===========================
        -- TARGET CONFIGURATION
        -- ===========================
        target = {
            health = {
                width = 200,
                height = 30,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                colorByClass = true,
                glassEnabled = true,
                glassAlpha = 0.5,
                animatedLossEnabled = true,
                absorbEnabled = true,
                healPredictionEnabled = true
            },
            power = {
                enabled = true,
                width = 80,
                height = 13,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                xOffset = 60,
                yOffset = -10,
                colorByPowerType = true,
                hideWhenEmpty = true,
                glassEnabled = true,
                glassAlpha = 0.2
            },
            text = {
                health = {
                    enabled = true,
                    style = "k_version",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 12,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = -8,
                    y = -1
                },
                power = {
                    enabled = false,
                    style = "current_k",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 11,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 5,
                    y = 1,
                    colorByPowerType = false
                },
                nameLevel = {
                    enabled = true,
                    containerOffset = {
                        x = 0,
                        y = 0
                    }
                },
                level = {
                    enabled = true,
                    show = true,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 12,
                    outline = "OUTLINE",
                    color = {1, 1, 0, 1},
                    colorByClass = false
                },
                name = {
                    enabled = true,
                    show = true,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 12,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    colorByClass = true,
                    truncate = true
                }
            },
            portrait = {
                enabled = true,
                scale = 1,
                offsetX = 65,
                offsetY = 0,
                flip = true,
                classification = true,
                useClassIcon = false,
                states = true
            },
            auras = {
                enabled = true,
                scale = 0.65,
                perRow = 4,
                maxRows = 5,  -- Limit to 5 rows max
                direction = "DOWN",
                showTimer = false,
                spacing = 2,
                offsetX = -119,
                offsetY = 15,
                showOnlyPlayerDebuffs = false,  -- Filter to show only player's debuffs
                stackSimilarAuras = false  -- Group identical auras and show count
            }
        },

        -- ===========================
        -- FOCUS CONFIGURATION
        -- ===========================
        focus = {
            health = {
                width = 154,
                height = 39,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                colorByClass = true,
                glassEnabled = true,
                glassAlpha = 0.5,
                animatedLossEnabled = false,
                absorbEnabled = false,
                healPredictionEnabled = false
            },
            power = {
                enabled = false,
                width = 50,
                height = 8,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                xOffset = 0,
                yOffset = -5,
                colorByPowerType = true,
                hideWhenEmpty = false,
                glassEnabled = true,
                glassAlpha = 0.2
            },
            text = {
                health = {
                    enabled = true,
                    style = "k_version",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 12,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 0,
                    y = 0
                },
                power = {
                    enabled = false,
                    style = "current_k",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 10,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 0,
                    y = 0,
                    colorByPowerType = false
                },
                nameLevel = {
                    enabled = true,
                    containerOffset = {
                        x = 0,
                        y = 5
                    }
                },
                level = {
                    enabled = true,
                    show = true,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 10,
                    outline = "OUTLINE",
                    color = {1, 1, 0, 1},
                    colorByClass = false
                },
                name = {
                    enabled = true,
                    show = true,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 10,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    colorByClass = true,
                    truncate = true
                }
            },
            portrait = {
                enabled = true,
                scale = 1,
                offsetX = 31,
                offsetY = -9,
                flip = true,
                classification = true,
                useClassIcon = false,
                states = true
            },
            auras = {
                enabled = false,  -- Enabled by default for focus
                scale = 1,
                perRow = 8,
                direction = "RIGHT",
                showTimer = true,
                spacing = 2,
                offsetX = 0,
                offsetY = -5
            }
        },

        -- ===========================
        -- PET CONFIGURATION
        -- ===========================
        pet = {
            health = {
                width = 111,
                height = 22,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                colorByClass = true,
                glassEnabled = true,
                glassAlpha = 0.2,
                animatedLossEnabled = false,
                absorbEnabled = false,
                healPredictionEnabled = false
            },
            power = {
                enabled = true,
                width = 46,
                height = 9,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                xOffset = -32,
                yOffset = -5,
                colorByPowerType = true,
                hideWhenEmpty = true,
                glassEnabled = true,
                glassAlpha = 0.2
            },
            text = {
                health = {
                    enabled = true,
                    style = "k_version",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 10,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 0,
                    y = 0
                },
                power = {
                    enabled = false,
                    style = "current_k",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 8,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 0,
                    y = 0,
                    colorByPowerType = false
                },
                nameLevel = {
                    enabled = true,
                    containerOffset = {
                        x = 0,
                        y = 0
                    }
                },
                level = {
                    enabled = false,
                    show = false,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 10,
                    outline = "OUTLINE",
                    color = {1, 1, 0, 1},
                    colorByClass = false
                },
                name = {
                    enabled = true,
                    show = true,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 10,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    colorByClass = true,
                    truncate = true
                }
            },
            portrait = {
                enabled = true,
                scale = 0.6,
                offsetX = 60,
                offsetY = 0,
                flip = true,
                classification = true,
                useClassIcon = false,
                states = false
            }
        },

        -- ===========================
        -- TARGET OF TARGET CONFIGURATION
        -- ===========================
        targettarget = {
            enabled = true,  -- Show/hide entire unitframe (some users don't want ToT visible)
            position = {
                offsetX = 142,
                offsetY = -70,
                anchor = "BOTTOMLEFT",
                relativePoint = "CENTER"  -- Attached to TargetFrame bottom-left
            },
            health = {
                width = 70,
                height = 16,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                colorByClass = true,
                glassEnabled = true,
                glassAlpha = 0.5,
                animatedLossEnabled = true,
                absorbEnabled = false,
                healPredictionEnabled = false
            },
            power = {
                enabled = false,
                width = 30,
                height = 4,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                xOffset = 0,
                yOffset = -2,
                colorByPowerType = true,
                hideWhenEmpty = true,
                glassEnabled = true,
                glassAlpha = 0.2
            },
            text = {
                health = {
                    enabled = false,
                    style = "k_version",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 8,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 0,
                    y = 0
                },
                power = {
                    enabled = false,
                    style = "current_k",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 6,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 0,
                    y = 0,
                    colorByPowerType = false
                },
                nameLevel = {
                    enabled = true,
                    containerOffset = {
                        x = 0,
                        y = -3
                    }
                },
                level = {
                    enabled = false,
                    show = false,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 8,
                    outline = "OUTLINE",
                    color = {1, 1, 0, 1},
                    colorByClass = false
                },
                name = {
                    enabled = true,
                    show = true,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 8,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    colorByClass = true,
                    truncate = true
                }
            },
            portrait = {
                enabled = false,
                scale = 0.5,
                offsetX = -28,
                offsetY = -4,
                flip = false,
                classification = false,
                useClassIcon = false,
                states = true
            }
        },

        -- ===========================
        -- FOCUS TARGET CONFIGURATION
        -- ===========================
        focustarget = {
            enabled = true,  -- Show/hide entire unitframe (some users don't want FoT visible)
            position = {
                offsetX = 251,
                offsetY = -56,
                anchor = "RIGHT",
                relativePoint = "LEFT"  -- Attached to FocusFrame bottom-left
            },
            health = {
                width = 83,
                height = 21,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                colorByClass = true,
                glassEnabled = true,
                glassAlpha = 0.5,
                animatedLossEnabled = false,
                absorbEnabled = false,
                healPredictionEnabled = false
            },
            power = {
                enabled = true,
                width = 30,
                height = 4,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                xOffset = 0,
                yOffset = -2,
                colorByPowerType = true,
                hideWhenEmpty = true,
                glassEnabled = true,
                glassAlpha = 0.2
            },
            text = {
                health = {
                    enabled = true,
                    style = "k_version",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 8,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 0,
                    y = 0
                },
                power = {
                    enabled = false,
                    style = "current_k",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 6,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 0,
                    y = 0,
                    colorByPowerType = false
                },
                nameLevel = {
                    enabled = true,
                    containerOffset = {
                        x = 0,
                        y = 2
                    }
                },
                level = {
                    enabled = false,
                    show = false,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 8,
                    outline = "OUTLINE",
                    color = {1, 1, 0, 1},
                    colorByClass = false
                },
                name = {
                    enabled = true,
                    show = true,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 8,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    colorByClass = true,
                    truncate = true
                }
            },
            portrait = {
                enabled = false,
                scale = 0.5,
                offsetX = 35,
                offsetY = 5,
                flip = true,
                classification = false,
                useClassIcon = false,
                states = false
            }
        },

        -- ===========================
        -- PARTY CONFIGURATION
        -- ===========================
        party = {
            gap = 13,  -- Vertical spacing between party members (in pixels)
            health = {
                width = 127,
                height = 24,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                colorByClass = true,
                glassEnabled = true,
                glassAlpha = 0.2,
                animatedLossEnabled = true,
                absorbEnabled = true,
                healPredictionEnabled = true
            },
            power = {
                enabled = false,
                width = 48,
                height = 11,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                xOffset = -39,
                yOffset = -6,
                colorByPowerType = true,
                hideWhenEmpty = true,
                glassEnabled = true,
                glassAlpha = 0.2
            },
            text = {
                health = {
                    enabled = true,
                    style = "percentage",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 11,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 0,
                    y = 0
                },
                power = {
                    enabled = false,
                    style = "current_k",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 9,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 0,
                    y = 0,
                    colorByPowerType = false
                },
                nameLevel = {
                    enabled = true,
                    containerOffset = {
                        x = 0,
                        y = 4
                    }
                },
                level = {
                    enabled = true,
                    show = true,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 10,
                    outline = "OUTLINE",
                    color = {1, 1, 0, 1},
                    colorByClass = false
                },
                name = {
                    enabled = true,
                    show = true,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 11,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    colorByClass = true,
                    truncate = true
                }
            },
            portrait = {
                enabled = true,
                scale = 0.7,
                offsetX = -80,
                offsetY = 0,
                flip = false,
                classification = true,
                useClassIcon = false,
                states = false
            }
        },

        -- ===========================
        -- RAID CONFIGURATION
        -- ===========================
        -- Raid frames use Blizzard's CompactRaidFrames as parent frames
        -- Size/position controlled by Blizzard Edit Mode
        -- Health bar automatically fills parent frame with 95% size (5% padding for borders)
        raid = {
            health = {
                -- No width/height - automatically fits parent frame at 95% (padding for borders)
                fitParent = true,              -- Health bar fills parent with padding
                fillPercent = 0.95,            -- 95% of parent size (5% padding for borders)
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                colorByClass = true,
                glassEnabled = true,
                glassTexture = "Interface\\AddOns\\Nihui_uf\\textures\\glass.tga",
                glassAlpha = 0.15,
                borderEnabled = true,
                animatedLossEnabled = true,
                absorbEnabled = true,
                healPredictionEnabled = true
            },

            -- Power bar disabled for raid (health only)
            power = {
                enabled = false
            },

            text = {
                -- Health text (value on the bar)
                health = {
                    enabled = true,
                    style = "percent",       -- Show health value
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 10,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 0,
                    y = 0
                },
                -- Power text disabled
                power = {
                    enabled = false
                },
                -- Name + Level (above the health bar)
                nameLevel = {
                    enabled = true,
                    containerOffset = {
                        x = 2,
                        y = -16
                    }
                },
                level = {
                    enabled = false,           -- Level hidden for raid (too cluttered)
                    show = false,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 8,
                    outline = "OUTLINE",
                    color = {1, 1, 0, 1},
                    colorByClass = false
                },
                name = {
                    enabled = true,
                    show = true,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 9,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    colorByClass = true,
                    truncate = true            -- Auto-truncate long names
                }
            },

            -- Portrait disabled for raid frames
            portrait = {
                enabled = false
            }
        },

        -- ===========================
        -- BOSS CONFIGURATION
        -- ===========================
        boss = {
            health = {
                width = 150,
                height = 28,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                colorByClass = true,
                glassEnabled = true,
                glassAlpha = 0.2,
                animatedLossEnabled = true,
                absorbEnabled = true,
                healPredictionEnabled = false
            },
            power = {
                enabled = true,
                width = 60,
                height = 8,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                xOffset = 0,
                yOffset = -5,
                colorByPowerType = true,
                hideWhenEmpty = false,
                glassEnabled = true,
                glassAlpha = 0.2
            },
            text = {
                health = {
                    enabled = true,
                    style = "k_version",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 11,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 0,
                    y = 0
                },
                power = {
                    enabled = true,
                    style = "current_k",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 9,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 0,
                    y = 0,
                    colorByPowerType = false
                },
                nameLevel = {
                    enabled = true,
                    containerOffset = {
                        x = 0,
                        y = 4
                    }
                },
                level = {
                    enabled = true,
                    show = true,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 10,
                    outline = "OUTLINE",
                    color = {1, 1, 0, 1},
                    colorByClass = false
                },
                name = {
                    enabled = true,
                    show = true,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 11,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    colorByClass = true,
                    truncate = true
                }
            },
            portrait = {
                enabled = true,
                scale = 0.9,
                offsetX = 85,
                offsetY = -10,
                flip = true,
                classification = true,
                useClassIcon = false,
                states = false
            }
        },

        -- ===========================
        -- ARENA CONFIGURATION
        -- ===========================
        arena = {
            health = {
                width = 150,
                height = 28,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                colorByClass = true,
                glassEnabled = true,
                glassAlpha = 0.2,
                animatedLossEnabled = true,
                absorbEnabled = true,
                healPredictionEnabled = false
            },
            power = {
                enabled = true,
                width = 60,
                height = 8,
                texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
                xOffset = 0,
                yOffset = -5,
                colorByPowerType = true,
                hideWhenEmpty = false,
                glassEnabled = true,
                glassAlpha = 0.2
            },
            text = {
                health = {
                    enabled = true,
                    style = "k_version",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 11,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 0,
                    y = 0
                },
                power = {
                    enabled = true,
                    style = "current_k",
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 9,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    x = 0,
                    y = 0,
                    colorByPowerType = false
                },
                nameLevel = {
                    enabled = true,
                    containerOffset = {
                        x = 0,
                        y = 4
                    }
                },
                level = {
                    enabled = true,
                    show = true,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 10,
                    outline = "OUTLINE",
                    color = {1, 1, 0, 1},
                    colorByClass = false
                },
                name = {
                    enabled = true,
                    show = true,
                    font = "Fonts\\FRIZQT__.TTF",
                    size = 11,
                    outline = "OUTLINE",
                    color = {1, 1, 1, 1},
                    colorByClass = true,
                    truncate = true
                }
            },
            portrait = {
                enabled = true,
                scale = 0.9,
                offsetX = 85,
                offsetY = -10,
                flip = true,
                classification = true,
                useClassIcon = false,
                states = false
            }
        }
    },

    -- ===========================
    -- XP/REPUTATION BARS
    -- ===========================
    -- NOTE: Size and position controlled by Blizzard Edit Mode
    -- (MainStatusTrackingBarContainer and SecondaryStatusTrackingBarContainer)
    xp = {
        enabled = true,
        position = {
            x = 425,
            y = -26
        },
        main = {
            height = 13,
            width = 3000,
            texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga"
        },
        background = {
            texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
            color = {0.1, 0.1, 0.1, 0.8}
        },
        glass = {
            enabled = true,
            alpha = 1
        },
        border = {
            enabled = true
        },
        text = {
            enabled = true,
            position = "center",  -- "left", "center", "right", "none"
            font = "Fonts\\FRIZQT__.TTF",
            size = 9,
            outline = "OUTLINE",
            color = {1, 1, 1, 1}
        },
        rested = {
            enabled = true,
            color = {0.3, 0.5, 1, 0.5}
        },
        animation = {
            enabled = true,
            previewDuration = 0.5,    -- Preview bar fade-in duration
            fillDelay = 0.3,          -- Delay before main bar fills
            fillDuration = 0.5        -- Main bar fill animation duration
        }
    },

    reputation = {
        enabled = true,  -- Show reputation bar when watching a faction
        position = {
            x = 0,
            y = 12
        },
        main = {
            height = 8,
            width = 300,
            texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga"
        },
        background = {
            texture = "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
            color = {0.1, 0.1, 0.1, 0.8}
        },
        glass = {
            enabled = true,
            alpha = 1
        },
        border = {
            enabled = true
        },
        text = {
            enabled = true,
            position = "center",  -- "left", "center", "right", "none"
            font = "Fonts\\FRIZQT__.TTF",
            size = 9,
            outline = "OUTLINE",
            color = {1, 1, 1, 1}
        }
    }
}

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================

-- Get default configuration for a specific unit
function ns.Config.GetUnitDefaults(unit)
    return ns.Config.Defaults.unitframes[unit]
end

-- Get default configuration for a specific path (e.g., "player.health.width")
function ns.Config.GetDefault(path)
    local keys = {strsplit(".", path)}
    local value = ns.Config.Defaults

    for _, key in ipairs(keys) do
        if value and type(value) == "table" then
            value = value[key]
        else
            return nil
        end
    end

    return value
end

-- Check if a path exists in defaults
function ns.Config.HasDefault(path)
    return ns.Config.GetDefault(path) ~= nil
end

-- Get all available unit types
function ns.Config.GetAvailableUnits()
    local units = {}
    for unit, _ in pairs(ns.Config.Defaults.unitframes) do
        table.insert(units, unit)
    end
    return units
end


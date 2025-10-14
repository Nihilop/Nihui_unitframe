# Guide d'Ajout d'Effets et Animations sur les Barres

Ce document explique comment ajouter des effets de spells, animations et autres effets visuels sur les barres de Nihui_uf, inspiré de WeakAuras.

## Table des Matières
1. [Types d'Effets Disponibles](#types-deffets-disponibles)
2. [AnimationGroup API](#animationgroup-api)
3. [Effets de Particules et Spells](#effets-de-particules-et-spells)
4. [Textures Animées](#textures-animées)
5. [Intégration dans Nihui_uf](#intégration-dans-nihui_uf)
6. [Exemples Concrets](#exemples-concrets)
7. [Éviter les Régressions](#éviter-les-régressions)

---

## Types d'Effets Disponibles

### 1. AnimationGroup (Natif WoW)
- **Fade In/Out** - Changement d'opacité
- **Translation** - Déplacement de frame
- **Rotation** - Rotation 3D
- **Scale** - Agrandissement/rétrécissement
- **Alpha** - Changement d'alpha progressif

### 2. Model Frames (Effets 3D)
- Affichage de modèles de spells 3D
- Effets de particules
- Effets de glow/lueur
- Nécessite les FileDataIDs des spells

### 3. Textures Animées (Filmstrip)
- Séquences d'images (sprite sheets)
- Effets de feu, électricité, etc.
- Contrôle frame par frame

### 4. Effets Procéduraux
- Pulse (via C_Timer)
- Shimmer/wave effects
- Color cycling

---

## AnimationGroup API

### Création d'une Animation

```lua
-- Créer un AnimationGroup sur une texture
local texture = frame:CreateTexture(nil, "OVERLAY")
texture:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\effect.tga")

-- Créer le groupe d'animations
local animGroup = texture:CreateAnimationGroup()

-- Ajouter une animation de pulse (scale)
local scaleAnim = animGroup:CreateAnimation("Scale")
scaleAnim:SetDuration(0.5)
scaleAnim:SetOrder(1)
scaleAnim:SetScale(1.2, 1.2)  -- Scale to 120%

-- Retour à la normale
local scaleBack = animGroup:CreateAnimation("Scale")
scaleBack:SetDuration(0.5)
scaleBack:SetOrder(2)
scaleBack:SetScale(0.833, 0.833)  -- Back to 100% (1/1.2)

-- Loop l'animation
animGroup:SetLooping("REPEAT")

-- Démarrer
animGroup:Play()
```

### Fade Effect (Apparition/Disparition)

```lua
local animGroup = texture:CreateAnimationGroup()

-- Fade in
local fadeIn = animGroup:CreateAnimation("Alpha")
fadeIn:SetDuration(0.3)
fadeIn:SetFromAlpha(0)
fadeIn:SetToAlpha(1)
fadeIn:SetOrder(1)

-- Fade out
local fadeOut = animGroup:CreateAnimation("Alpha")
fadeOut:SetDuration(0.3)
fadeOut:SetFromAlpha(1)
fadeOut:SetToAlpha(0)
fadeOut:SetOrder(2)
fadeOut:SetStartDelay(2)  -- Wait 2 seconds

animGroup:Play()
```

### Translation (Mouvement)

```lua
local animGroup = texture:CreateAnimationGroup()

local translate = animGroup:CreateAnimation("Translation")
translate:SetDuration(1.0)
translate:SetOffset(50, 0)  -- Move 50 pixels to the right
translate:SetSmoothing("IN_OUT")  -- Smooth acceleration/deceleration

animGroup:SetLooping("BOUNCE")  -- Bounce back and forth
animGroup:Play()
```

---

## Effets de Particules et Spells

### Utiliser les Spell Effects de WoW

```lua
-- Créer un Model frame pour afficher un spell effect
local spellEffect = CreateFrame("PlayerModel", nil, frame)
spellEffect:SetSize(100, 100)
spellEffect:SetPoint("CENTER", frame, "CENTER", 0, 0)
spellEffect:SetFrameLevel(frame:GetFrameLevel() + 10)

-- Exemples de FileDataIDs de spells populaires
local SPELL_EFFECTS = {
    HOLY_GLOW = 166357,      -- Holy priest glow
    SHADOW_PULSE = 166719,   -- Shadow pulse
    ARCANE_SPIRAL = 166795,  -- Arcane spiral
    FIRE_SWIRL = 166659,     -- Fire effect
    LIGHTNING = 166681,      -- Lightning
    HEAL_SPARKLE = 166360,   -- Heal sparkles
    SHIELD_GLOW = 237538,    -- Shield glow
}

-- Appliquer un effet
spellEffect:SetDisplayInfo(SPELL_EFFECTS.HOLY_GLOW)
spellEffect:SetAlpha(0.8)

-- Animer la rotation
spellEffect:SetScript("OnUpdate", function(self, elapsed)
    self.rotation = (self.rotation or 0) + (elapsed * 45)  -- 45 degrees per second
    self:SetRotation(math.rad(self.rotation))
end)
```

### Glow Effect Simple (Sans Model)

```lua
-- Créer un glow simple avec des textures
local glow = frame:CreateTexture(nil, "OVERLAY")
glow:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\glow.tga")
glow:SetBlendMode("ADD")
glow:SetPoint("CENTER", frame, "CENTER", 0, 0)
glow:SetSize(frame:GetWidth() + 20, frame:GetHeight() + 20)

-- Pulse animation
local glowAnim = glow:CreateAnimationGroup()
local pulse = glowAnim:CreateAnimation("Alpha")
pulse:SetDuration(1.0)
pulse:SetFromAlpha(0.3)
pulse:SetToAlpha(1.0)
pulse:SetSmoothing("IN_OUT")

glowAnim:SetLooping("BOUNCE")
glowAnim:Play()
```

---

## Textures Animées

### Filmstrip/Sprite Sheet Animation

```lua
-- Créer une texture animée (filmstrip)
local animTexture = frame:CreateTexture(nil, "OVERLAY")
animTexture:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\fire_animation.tga")
animTexture:SetSize(64, 64)
animTexture:SetPoint("CENTER")

-- Configuration du filmstrip (8 frames en horizontal)
local FRAME_COUNT = 8
local FRAME_WIDTH = 1 / FRAME_COUNT  -- 0.125 per frame
local currentFrame = 0

-- Animation via OnUpdate
local elapsed = 0
local FRAME_DELAY = 0.05  -- 20 FPS

animTexture:SetScript("OnUpdate", function(self, delta)
    elapsed = elapsed + delta
    if elapsed >= FRAME_DELAY then
        currentFrame = (currentFrame + 1) % FRAME_COUNT
        local left = currentFrame * FRAME_WIDTH
        local right = left + FRAME_WIDTH
        self:SetTexCoord(left, right, 0, 1)
        elapsed = 0
    end
end)
```

---

## Intégration dans Nihui_uf

### Architecture Recommandée

Créer un nouveau module `ui/effects.lua` pour gérer les effets :

```lua
-- ui/effects.lua
local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Effects = {}

-- Create a pulsing glow effect on a frame
function ns.UI.Effects.CreatePulseGlow(parent, config)
    local effect = {}

    config = config or {}
    local size = config.size or {parent:GetWidth() + 20, parent:GetHeight() + 20}
    local color = config.color or {1, 1, 1}
    local speed = config.speed or 1.0
    local intensity = config.intensity or {0.3, 1.0}

    -- Create glow texture
    effect.texture = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    effect.texture:SetTexture(config.texture or "Interface\\AddOns\\Nihui_uf\\textures\\glow.tga")
    effect.texture:SetBlendMode("ADD")
    effect.texture:SetSize(unpack(size))
    effect.texture:SetPoint("CENTER", parent, "CENTER", 0, 0)
    effect.texture:SetVertexColor(unpack(color))

    -- Create pulse animation
    effect.animGroup = effect.texture:CreateAnimationGroup()
    local pulse = effect.animGroup:CreateAnimation("Alpha")
    pulse:SetDuration(speed)
    pulse:SetFromAlpha(intensity[1])
    pulse:SetToAlpha(intensity[2])
    pulse:SetSmoothing("IN_OUT")

    effect.animGroup:SetLooping("BOUNCE")

    -- Control functions
    function effect:Play()
        self.animGroup:Play()
    end

    function effect:Stop()
        self.animGroup:Stop()
    end

    function effect:Destroy()
        self.animGroup:Stop()
        if self.texture then
            self.texture:Hide()
            self.texture = nil
        end
    end

    return effect
end

-- Create a spell effect (using Model frame)
function ns.UI.Effects.CreateSpellEffect(parent, fileDataID, config)
    local effect = {}

    config = config or {}
    local size = config.size or {100, 100}

    -- Create model frame
    effect.model = CreateFrame("PlayerModel", nil, parent)
    effect.model:SetSize(unpack(size))
    effect.model:SetPoint("CENTER", parent, "CENTER", 0, 0)
    effect.model:SetFrameLevel(parent:GetFrameLevel() + 10)
    effect.model:SetAlpha(config.alpha or 0.8)

    -- Set spell effect
    effect.model:SetDisplayInfo(fileDataID)

    -- Rotation animation (optional)
    if config.rotate then
        effect.rotation = 0
        effect.model:SetScript("OnUpdate", function(self, elapsed)
            effect.rotation = effect.rotation + (elapsed * (config.rotationSpeed or 45))
            self:SetRotation(math.rad(effect.rotation))
        end)
    end

    -- Control functions
    function effect:Show()
        self.model:Show()
    end

    function effect:Hide()
        self.model:Hide()
    end

    function effect:Destroy()
        if self.model then
            self.model:SetScript("OnUpdate", nil)
            self.model:Hide()
            self.model = nil
        end
    end

    return effect
end

-- Create shimmer/wave effect (procedural)
function ns.UI.Effects.CreateShimmer(parent, config)
    local effect = {}

    config = config or {}

    -- Create shimmer texture
    effect.texture = parent:CreateTexture(nil, "OVERLAY", nil, 5)
    effect.texture:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\shimmer.tga")
    effect.texture:SetBlendMode("ADD")
    effect.texture:SetAllPoints(parent)
    effect.texture:SetVertexColor(unpack(config.color or {1, 1, 1}))
    effect.texture:SetAlpha(0)

    -- Wave animation via OnUpdate
    effect.time = 0
    effect.speed = config.speed or 2.0
    effect.intensity = config.intensity or 0.5

    effect.ticker = C_Timer.NewTicker(0.03, function()
        effect.time = effect.time + 0.03
        local alpha = (math.sin(effect.time * effect.speed) + 1) * 0.5 * effect.intensity
        effect.texture:SetAlpha(alpha)
    end)

    -- Control functions
    function effect:Stop()
        if self.ticker then
            self.ticker:Cancel()
            self.ticker = nil
        end
    end

    function effect:Destroy()
        self:Stop()
        if self.texture then
            self.texture:Hide()
            self.texture = nil
        end
    end

    return effect
end
```

### Utilisation dans systems/health.lua

```lua
-- Dans systems/health.lua, après création de la barre

-- Optionnel : Ajouter un effet de glow sur absorb
if healthConfig.absorbEnabled and healthConfig.absorbGlowEffect then
    healthSystem.absorbGlow = ns.UI.Effects.CreatePulseGlow(
        healthSystem.barSet.overlays.absorb.bar,
        {
            size = {healthSystem.bar:GetWidth() + 10, healthSystem.bar:GetHeight() + 10},
            color = {0.6, 0.8, 1},
            speed = 1.5,
            intensity = {0.2, 0.8}
        }
    )

    -- Activer le glow seulement quand absorb > 0
    healthSystem.absorbGlow:Stop()  -- Start hidden
end

-- Dans UpdateAbsorb(), activer/désactiver le glow
function healthSystem:UpdateAbsorb()
    -- ... code existant ...

    if totalAbsorb > 0 then
        if self.absorbGlow then
            self.absorbGlow:Play()
        end
    else
        if self.absorbGlow then
            self.absorbGlow:Stop()
        end
    end
end

-- Dans Destroy(), nettoyer les effets
function healthSystem:Destroy()
    -- ... code existant ...

    if self.absorbGlow then
        self.absorbGlow:Destroy()
        self.absorbGlow = nil
    end
end
```

---

## Exemples Concrets

### Exemple 1 : Glow Pulsant sur Low Health

```lua
-- Créer un glow rouge qui pulse quand HP < 30%
local lowHealthGlow = ns.UI.Effects.CreatePulseGlow(healthBar, {
    color = {1, 0, 0},  -- Rouge
    speed = 0.5,  -- Pulse rapide
    intensity = {0.5, 1.0}
})

-- Contrôler dans UpdateHealth()
function healthSystem:UpdateHealth()
    local current = UnitHealth(self.unit)
    local max = UnitHealthMax(self.unit)
    local percent = (current / max) * 100

    if percent < 30 then
        if not self.lowHealthGlow.isPlaying then
            self.lowHealthGlow:Play()
            self.lowHealthGlow.isPlaying = true
        end
    else
        if self.lowHealthGlow.isPlaying then
            self.lowHealthGlow:Stop()
            self.lowHealthGlow.isPlaying = false
        end
    end
end
```

### Exemple 2 : Spell Effect sur Heal Prediction

```lua
-- Ajouter un effet de heal sparkle quand incoming heals > 0
local healEffect = ns.UI.Effects.CreateSpellEffect(
    healPredictionBar,
    166360,  -- Heal sparkles FileDataID
    {
        size = {50, 50},
        alpha = 0.6,
        rotate = true,
        rotationSpeed = 30
    }
)

-- Contrôler dans UpdateHealPrediction()
if incoming > 0 then
    healEffect:Show()
else
    healEffect:Hide()
end
```

### Exemple 3 : Shield Effect sur Absorb

```lua
-- Créer un modèle de bouclier qui tourne
local shieldModel = ns.UI.Effects.CreateSpellEffect(
    absorbBar,
    237538,  -- Shield glow FileDataID
    {
        size = {healthBar:GetWidth() + 40, healthBar:GetHeight() + 40},
        alpha = 0.7,
        rotate = true,
        rotationSpeed = 20
    }
)

-- Afficher seulement quand absorb actif
if totalAbsorb > 0 then
    shieldModel:Show()
else
    shieldModel:Hide()
end
```

---

## Éviter les Régressions

### ✅ Bonnes Pratiques

1. **Isolation des Effets**
   - Créer tous les effets dans `ui/effects.lua`
   - Ne jamais modifier directement les barres existantes
   - Utiliser des layers OVERLAY pour les effets (ne pas interférer avec la barre)

2. **Lifecycle Management**
   - Toujours créer une méthode `Destroy()` pour nettoyer les effets
   - Arrêter les timers/animations dans `Destroy()`
   - Libérer les textures/models

3. **Configuration Optionnelle**
   ```lua
   -- Ajouter dans defaults.lua
   player = {
       health = {
           effects = {
               lowHealthGlow = true,  -- Enable/disable
               absorbShield = true,
               healSparkles = false
           }
       }
   }
   ```

4. **Conditional Loading**
   ```lua
   -- Ne créer les effets que si configurés
   if healthConfig.effects and healthConfig.effects.lowHealthGlow then
       healthSystem.lowHealthGlow = ns.UI.Effects.CreatePulseGlow(...)
   end
   ```

5. **Frame Level Management**
   - Effets visuels : `frameLevel + 5`
   - Sparks : `frameLevel + 10`
   - Text : `frameLevel + 15`
   - S'assurer que les effets ne cachent pas les éléments importants

6. **Performance**
   ```lua
   -- Limiter les OnUpdate
   if config.useOnUpdate then
       -- Use OnUpdate for smooth animation
   else
       -- Use AnimationGroup (better performance)
   end

   -- Désactiver les effets quand frame est caché
   if not parent:IsVisible() then
       effect:Stop()
   end
   ```

### ❌ À Éviter

- ❌ Modifier les barres existantes directement
- ❌ Créer des effets sans méthode Destroy()
- ❌ Oublier d'arrêter les timers/animations
- ❌ Utiliser trop d'OnUpdate (préférer AnimationGroup)
- ❌ Créer des effets sur tous les frames (impacte les performances)
- ❌ Oublier la configuration pour enable/disable

---

## Ressources Utiles

### FileDataIDs de Spells Populaires

```lua
local SPELL_VISUAL_KITS = {
    -- Holy/Heal effects
    HOLY_NOVA = 166357,
    HEAL_SPARKLE = 166360,
    DIVINE_SHIELD = 165738,

    -- Shadow/Dark effects
    SHADOW_PULSE = 166719,
    VOID_TENDRILS = 538688,

    -- Arcane effects
    ARCANE_SPIRAL = 166795,
    ARCANE_MISSILES = 166300,

    -- Fire effects
    FIRE_SWIRL = 166659,
    FLAME_STRIKE = 166674,

    -- Nature effects
    REJUVENATION = 166292,
    WILD_GROWTH = 237113,

    -- Frost effects
    FROST_NOVA = 166313,
    ICE_BARRIER = 166321,

    -- Protection effects
    SHIELD_GLOW = 237538,
    BARRIER = 166738,

    -- Lightning/Energy
    LIGHTNING_BOLT = 166681,
    CHAIN_LIGHTNING = 166687,
}
```

### Textures Utiles

```
Interface\AddOns\Nihui_uf\textures\
  - glow.tga           (Soft glow effect)
  - shimmer.tga        (Shimmer effect)
  - sparkle.tga        (Sparkle particles)
  - AbsorbSpark.tga    (Spark effect - déjà utilisé)
```

### APIs WoW Pertinentes

- `Frame:CreateAnimationGroup()` - Créer animations
- `AnimationGroup:CreateAnimation(type)` - Types: "Alpha", "Scale", "Translation", "Rotation"
- `CreateFrame("PlayerModel")` - Créer model frames pour spell effects
- `Model:SetDisplayInfo(fileDataID)` - Afficher un spell effect
- `Texture:SetTexCoord(left, right, top, bottom)` - Pour filmstrip animations
- `Texture:SetBlendMode(mode)` - Modes: "BLEND", "ADD", "MOD", "ALPHAKEY"

---

## Conclusion

L'ajout d'effets et animations sur les barres est parfaitement possible et peut grandement améliorer l'esthétique de Nihui_uf. L'approche modulaire recommandée (via `ui/effects.lua`) permet d'ajouter ces effets sans régression sur le code existant.

**Prochaines Étapes Suggérées:**

1. Créer `ui/effects.lua` avec les fonctions de base
2. Ajouter des options dans `config/defaults.lua` pour enable/disable
3. Implémenter 1-2 effets simples (ex: glow sur absorb)
4. Tester les performances avec plusieurs unit frames actifs
5. Étendre progressivement avec plus d'effets

**Note**: Pour des effets complexes type WeakAuras, il est recommandé d'utiliser des models (FileDataIDs) plutôt que des textures animées, car ils sont optimisés par Blizzard et ont un meilleur rendu.

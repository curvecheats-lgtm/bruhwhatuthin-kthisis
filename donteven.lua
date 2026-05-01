local CURVE_LOADER_ENDPOINT = "https://curve-keys.govsheild.workers.dev/verify"
local DISCORD_INVITE        = "https://discord.gg/gaTekWMzDS"

_G._elocate_discord = DISCORD_INVITE

local CoreGui
do
    local ok, h = pcall(function()
        if typeof(gethui) == "function" then return gethui() end
        return game:GetService("CoreGui")
    end)
    CoreGui = ok and h or game:GetService("CoreGui")
end

-- wipe any old loader / hub copies
for _, child in ipairs(CoreGui:GetChildren()) do
    if tostring(child.Name):sub(1, 9) == "_elocate" then
        pcall(function() child:Destroy() end)
    end
end

-- =========================  PALETTE (matches main UI) ========
local ACCENT       = Color3.fromRGB(147, 112, 219)   -- Library.Accent
local ACCENT_DEEP  = Color3.fromRGB(100,  70, 150)
local ACCENT_DARK  = Color3.fromRGB(60,   40,  80)
local INLINE       = Color3.fromRGB(22,   16,  32)   -- Library Inline panel
local DEEP         = Color3.fromRGB(15,   12,  25)   -- bottom of body grad
local PANEL        = Color3.fromRGB(20,   16,  30)
local PANEL_HI     = Color3.fromRGB(34,   26,  52)
local STROKE_OUT   = Color3.fromRGB(80,   60, 110)   -- main outer line
local STROKE_IN    = Color3.fromRGB(60,   45,  85)   -- inner divider
local STROKE_HI    = Color3.fromRGB(110,  80, 160)
local TEXT         = Color3.fromRGB(220, 215, 230)
local DIM          = Color3.fromRGB(120, 110, 140)
local OK_COLOR     = Color3.fromRGB(140, 235, 160)
local BAD_COLOR    = Color3.fromRGB(255, 110, 110)

local TweenService = game:GetService("TweenService")
local UserInput    = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")
local Players      = game:GetService("Players")

local UI_FONT      = Enum.Font.SourceSans
local UI_FONT_BOLD = Enum.Font.SourceSansBold
local UI_FONT_MONO = Enum.Font.Code
local UI_TEXT_SIZE = 16

-- =========================  HELPERS  =========================
local function tw(obj, time, props, style, dir)
    local info = TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke", parent)
    s.Color = color or STROKE_OUT
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end

local function pad(parent, top, right, bottom, left)
    local p = Instance.new("UIPadding", parent)
    p.PaddingTop    = UDim.new(0, top or 0)
    p.PaddingRight  = UDim.new(0, right or top or 0)
    p.PaddingBottom = UDim.new(0, bottom or top or 0)
    p.PaddingLeft   = UDim.new(0, left or right or top or 0)
    return p
end

-- =========================  ROOT GUI  ========================
local screen = Instance.new("ScreenGui")
screen.Name = "_elocate_loader"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 50000
screen.Parent = CoreGui

local dim = Instance.new("Frame", screen)
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.ZIndex = 1

-- ===== shared window factory (matches Sense / library look) =======
-- structure: outerBorder (1px black) > outline (1px stroke_out) >
--            inline (1px stroke_in) > main (BG) > top (header w/ gradient) + body
local function makeWindow(width, height, titleText)
    local card = Instance.new("Frame", screen)
    card.Name = "Card"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(width, height)
    card.BackgroundColor3 = Color3.new(0, 0, 0)
    card.BorderSizePixel = 0
    card.BackgroundTransparency = 1
    card.ZIndex = 10
    card.ClipsDescendants = false

    -- outer 1px black hairline
    local outer = Instance.new("Frame", card)
    outer.Name = "Outer"
    outer.Size = UDim2.new(1, 0, 1, 0)
    outer.BackgroundColor3 = Color3.new(0, 0, 0)
    outer.BorderSizePixel = 0
    outer.BackgroundTransparency = 1
    outer.ZIndex = 10

    -- accent outline frame (1px purple)
    local outline = Instance.new("Frame", outer)
    outline.Name = "Outline"
    outline.Position = UDim2.fromOffset(1, 1)
    outline.Size = UDim2.new(1, -2, 1, -2)
    outline.BackgroundColor3 = STROKE_OUT
    outline.BorderSizePixel = 0
    outline.BackgroundTransparency = 1
    outline.ZIndex = 11

    -- inner darker outline
    local inline = Instance.new("Frame", outline)
    inline.Name = "Inline"
    inline.Position = UDim2.fromOffset(1, 1)
    inline.Size = UDim2.new(1, -2, 1, -2)
    inline.BackgroundColor3 = STROKE_IN
    inline.BorderSizePixel = 0
    inline.BackgroundTransparency = 1
    inline.ZIndex = 12

    -- main content panel
    local main = Instance.new("Frame", inline)
    main.Name = "Main"
    main.Position = UDim2.fromOffset(1, 1)
    main.Size = UDim2.new(1, -2, 1, -2)
    main.BackgroundColor3 = INLINE
    main.BorderSizePixel = 0
    main.BackgroundTransparency = 1
    main.ZIndex = 13

    local mainGrad = Instance.new("UIGradient", main)
    mainGrad.Rotation = 90
    mainGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(28, 22, 42)),
        ColorSequenceKeypoint.new(0.5, INLINE),
        ColorSequenceKeypoint.new(1,   DEEP),
    }

    -- top header strip (matches Library Top w/ gradient overlay)
    local top = Instance.new("Frame", main)
    top.Name = "Top"
    top.Size = UDim2.new(1, 0, 0, 22)
    top.BackgroundColor3 = INLINE
    top.BorderSizePixel = 0
    top.BackgroundTransparency = 1
    top.ZIndex = 14
    -- accent overlay gradient
    local topOverlay = Instance.new("Frame", top)
    topOverlay.Size = UDim2.new(1, 0, 1, 0)
    topOverlay.BackgroundColor3 = Color3.new(1, 1, 1)
    topOverlay.BorderSizePixel = 0
    topOverlay.ZIndex = 14
    topOverlay.BackgroundTransparency = 1
    local topUiGrad = Instance.new("UIGradient", topOverlay)
    topUiGrad.Rotation = 90
    topUiGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(40, 40, 45)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 25, 30)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(11, 12, 15)),
    }
    topUiGrad.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.6),
        NumberSequenceKeypoint.new(1, 1),
    }

    -- title
    local title = Instance.new("TextLabel", top)
    title.Name = "Title"
    title.Position = UDim2.new(0, 6, 0, 0)
    title.Size = UDim2.new(1, -12, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = titleText or "<b>elocate.lol</b>"
    title.RichText = true
    title.TextColor3 = ACCENT
    title.TextTransparency = 1
    title.Font = UI_FONT
    title.TextSize = UI_TEXT_SIZE
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 15

    -- top thin accent line
    local topLine = Instance.new("Frame", top)
    topLine.Position = UDim2.new(0, -1, 1, -1)
    topLine.Size = UDim2.new(1, 2, 0, 1)
    topLine.BackgroundColor3 = STROKE_HI
    topLine.BorderSizePixel = 0
    topLine.BackgroundTransparency = 1
    topLine.ZIndex = 16
    -- highlight gradient strip on the line (mimics Library.Gradient)
    local accentGrad = Instance.new("Frame", top)
    accentGrad.Position = UDim2.new(0.25, 0, 1, -1)
    accentGrad.Size = UDim2.new(0.5, 0, 0, 1)
    accentGrad.BackgroundColor3 = Color3.new(1, 1, 1)
    accentGrad.BorderSizePixel = 0
    accentGrad.BackgroundTransparency = 1
    accentGrad.ZIndex = 17
    local lineGrad = Instance.new("UIGradient", accentGrad)
    lineGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0,   STROKE_HI),
        ColorSequenceKeypoint.new(0.5, ACCENT),
        ColorSequenceKeypoint.new(1,   STROKE_HI),
    }

    -- body region
    local body = Instance.new("Frame", main)
    body.Name = "Body"
    body.Position = UDim2.new(0, 0, 0, 22)
    body.Size = UDim2.new(1, 0, 1, -22)
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    body.ZIndex = 13

    return {
        card    = card,
        outer   = outer,
        outline = outline,
        inline  = inline,
        main    = main,
        top     = top,
        topOverlay = topOverlay,
        topLine = topLine,
        accentGrad = accentGrad,
        title   = title,
        body    = body,
    }
end

-- ===== fade helpers ===============================================
local function fadeIn(w, time)
    local t = time or 0.32
    tw(w.outer,      t, { BackgroundTransparency = 0 })
    tw(w.outline,    t, { BackgroundTransparency = 0 })
    tw(w.inline,     t, { BackgroundTransparency = 0 })
    tw(w.main,       t, { BackgroundTransparency = 0 })
    tw(w.top,        t, { BackgroundTransparency = 0 })
    tw(w.topOverlay, t, { BackgroundTransparency = 0 })
    tw(w.topLine,    t, { BackgroundTransparency = 0 })
    tw(w.accentGrad, t, { BackgroundTransparency = 0 })
    tw(w.title,      t, { TextTransparency = 0 })
end

local function fadeOutAndDestroy(w, time)
    local t = time or 0.22
    tw(w.outer,      t, { BackgroundTransparency = 1 })
    tw(w.outline,    t, { BackgroundTransparency = 1 })
    tw(w.inline,     t, { BackgroundTransparency = 1 })
    tw(w.main,       t, { BackgroundTransparency = 1 })
    tw(w.top,        t, { BackgroundTransparency = 1 })
    tw(w.topOverlay, t, { BackgroundTransparency = 1 })
    tw(w.topLine,    t, { BackgroundTransparency = 1 })
    tw(w.accentGrad, t, { BackgroundTransparency = 1 })
    tw(w.title,      t, { TextTransparency = 1 })
    for _, d in ipairs(w.card:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            tw(d, t, { TextTransparency = 1 })
            if d:IsA("TextButton") or d:IsA("TextBox") then
                tw(d, t, { BackgroundTransparency = 1 })
            end
        elseif d:IsA("Frame") then
            tw(d, t, { BackgroundTransparency = 1 })
        elseif d:IsA("UIStroke") then
            tw(d, t, { Transparency = 1 })
        elseif d:IsA("ScrollingFrame") then
            tw(d, t, { BackgroundTransparency = 1, ScrollBarImageTransparency = 1 })
        elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
            tw(d, t, { ImageTransparency = 1, BackgroundTransparency = 1 })
        end
    end
    task.delay(t + 0.05, function()
        if w.card then w.card:Destroy() end
    end)
end

local gamesList = {
    { id = "phantom_forces", name = "phantom forces", tag = "pf",   placeIds = {292439477} },
    { id = "arsenal",        name = "arsenal",        tag = "al",   placeIds = {286090429, 1532002752} },
    { id = "dahood",         name = "da hood",        tag = "dh",   placeIds = {2788229376, 12233110030} },
    { id = "hood_modded",    name = "hood modded",    tag = "dh",   placeIds = {} },
    { id = "hood_customs",   name = "hood customs",   tag = "dh",   placeIds = {9825515356} },
    { id = "hood_aim",       name = "hood copies",       tag = "hc",   placeIds = {} },
    { id = "da_track",       name = "da track",       tag = "dh",  placeIds = {} },
    { id = "universal",      name = "universal",      tag = "any",   placeIds = {} },
}

-- per-game feature profile (consumed by the rest of the script)
local profiles = {
    phantom_forces = {
        id          = "phantom_forces",
        displayName = "Phantom Forces",
        tag         = "fps",
        engine      = "fe-fps",
        teamCheck   = true,        -- has friendly teams
        bodyParts   = {"Head", "Torso", "HumanoidRootPart"},
        aimables    = {"Head", "Torso"},
        features    = { silentAim=true, silentDahood=false, esp=true, fov=true, removeRecoil=true, hitParts=true },
    },
    arsenal = {
        id          = "arsenal",
        displayName = "Arsenal",
        tag         = "fps",
        engine      = "fe-fps",
        teamCheck   = false,       -- ffa lobby usually
        bodyParts   = {"Head","HumanoidRootPart"},
        aimables    = {"Head"},
        features    = { silentAim=true, silentDahood=false, esp=true, fov=true, removeRecoil=true, hitParts=true },
    },
    dahood = {
        id          = "dahood",
        displayName = "Da Hood",
        tag         = "fps",
        engine      = "dahood-melee",
        teamCheck   = false,
        bodyParts   = {"HumanoidRootPart","Head","Torso"},
        aimables    = {"HumanoidRootPart"},
        features    = { silentAim=true, silentDahood=true, esp=true, fov=true, removeRecoil=false, hitParts=false, blockAura=true, autoBlock=true },
    },
    hood_modded = {
        id          = "hood_modded",
        displayName = "Hood Modded",
        tag         = "fps",
        engine      = "dahood-melee",
        teamCheck   = false,
        bodyParts   = {"HumanoidRootPart","Head","Torso"},
        aimables    = {"HumanoidRootPart"},
        features    = { silentAim=true, silentDahood=true, esp=true, fov=true, blockAura=true, autoBlock=true },
    },
    hood_customs = {
        id          = "hood_customs",
        displayName = "Hood Customs",
        tag         = "fps",
        engine      = "dahood-melee",
        teamCheck   = false,
        bodyParts   = {"HumanoidRootPart","Head","Torso"},
        aimables    = {"HumanoidRootPart"},
        features    = { silentAim=true, silentDahood=true, esp=true, fov=true, blockAura=true, autoBlock=true },
    },
    hood_aim = {
        id          = "hood_aim",
        displayName = "Hood Aim",
        tag         = "aim",
        engine      = "dahood-melee",
        teamCheck   = false,
        bodyParts   = {"HumanoidRootPart","Head"},
        aimables    = {"HumanoidRootPart"},
        features    = { silentAim=true, silentDahood=true, fov=true },
    },
    da_track = {
        id          = "da_track",
        displayName = "Da Track",
        tag         = "race",
        engine      = "race",
        teamCheck   = false,
        bodyParts   = {"HumanoidRootPart"},
        aimables    = {"HumanoidRootPart"},
        features    = { esp=true, telemetry=true },
    },
    universal = {
        id          = "universal",
        displayName = "Universal",
        tag         = "any",
        engine      = "universal",
        teamCheck   = true,
        bodyParts   = {"Head","HumanoidRootPart","Torso"},
        aimables    = {"Head","HumanoidRootPart"},
        features    = { silentAim=true, esp=true, fov=true },
    },
}

-- expose helpers globally so the rest of the file can branch
_G._elocate_gameMode    = nil
_G._elocate_gameProfile = nil

function _G._elocate_isGame(...)
    local m = _G._elocate_gameMode
    if not m then return false end
    for i = 1, select("#", ...) do
        if select(i, ...) == m then return true end
    end
    return false
end

function _G._elocate_supports(featureName)
    local p = _G._elocate_gameProfile
    return p and p.features and p.features[featureName] == true or false
end

function _G._elocate_aimables()
    local p = _G._elocate_gameProfile
    return (p and p.aimables) or {"Head","HumanoidRootPart"}
end

function _G._elocate_isFriendly(targetPlayer)
    local p = _G._elocate_gameProfile
    if not (p and p.teamCheck) then return false end
    local lp = game:GetService("Players").LocalPlayer
    if not lp or not targetPlayer or targetPlayer == lp then return true end
    if lp.Neutral or targetPlayer.Neutral then return false end
    return lp.Team and targetPlayer.Team and lp.Team == targetPlayer.Team
end

function _G._elocate_setGame(modeId)
    _G._elocate_gameMode    = modeId
    _G._elocate_gameProfile = profiles[modeId] or profiles.universal
end

-- ============================================================
--  STEP 1  GAME PICKER
-- ============================================================
local pickerW = 340
local pickerH = 348
local gameWindow = makeWindow(pickerW, pickerH, "<b>elocate.lol</b> | game select")

-- header right-side hint
local headerHint = Instance.new("TextLabel", gameWindow.top)
headerHint.AnchorPoint = Vector2.new(1, 0)
headerHint.Position = UDim2.new(1, -6, 0, 0)
headerHint.Size = UDim2.new(0, 80, 1, 0)
headerHint.BackgroundTransparency = 1
headerHint.Text = "step 1 / 2"
headerHint.TextColor3 = DIM
headerHint.TextTransparency = 1
headerHint.Font = UI_FONT_MONO
headerHint.TextSize = 12
headerHint.TextXAlignment = Enum.TextXAlignment.Right
headerHint.ZIndex = 15

-- subtitle
local subtitle = Instance.new("TextLabel", gameWindow.body)
subtitle.Name = "Subtitle"
subtitle.Position = UDim2.fromOffset(10, 8)
subtitle.Size = UDim2.new(1, -20, 0, 14)
subtitle.BackgroundTransparency = 1
subtitle.Text = "select a game profile to load"
subtitle.TextColor3 = DIM
subtitle.TextTransparency = 1
subtitle.Font = UI_FONT
subtitle.TextSize = UI_TEXT_SIZE
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 14

-- search box
local searchHolder = Instance.new("Frame", gameWindow.body)
searchHolder.Name = "SearchHolder"
searchHolder.Position = UDim2.fromOffset(10, 26)
searchHolder.Size = UDim2.new(1, -20, 0, 22)
searchHolder.BackgroundColor3 = PANEL
searchHolder.BorderSizePixel = 0
searchHolder.BackgroundTransparency = 1
searchHolder.ZIndex = 14
local searchBorder = Instance.new("Frame", searchHolder)
searchBorder.Position = UDim2.fromOffset(0, 0)
searchBorder.Size = UDim2.new(1, 0, 1, 0)
searchBorder.BackgroundColor3 = STROKE_IN
searchBorder.BorderSizePixel = 0
searchBorder.BackgroundTransparency = 1
searchBorder.ZIndex = 14
local searchInner = Instance.new("Frame", searchBorder)
searchInner.Position = UDim2.fromOffset(1, 1)
searchInner.Size = UDim2.new(1, -2, 1, -2)
searchInner.BackgroundColor3 = PANEL
searchInner.BorderSizePixel = 0
searchInner.BackgroundTransparency = 1
searchInner.ZIndex = 15
local searchBox = Instance.new("TextBox", searchInner)
searchBox.Position = UDim2.fromOffset(8, 0)
searchBox.Size = UDim2.new(1, -16, 1, 0)
searchBox.BackgroundTransparency = 1
searchBox.Text = ""
searchBox.PlaceholderText = "search..."
searchBox.PlaceholderColor3 = DIM
searchBox.TextColor3 = TEXT
searchBox.TextTransparency = 1
searchBox.PlaceholderColor3 = DIM
searchBox.Font = UI_FONT
searchBox.TextSize = UI_TEXT_SIZE
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false
searchBox.ZIndex = 16

-- list container
local listOuter = Instance.new("Frame", gameWindow.body)
listOuter.Name = "ListOuter"
listOuter.Position = UDim2.fromOffset(10, 54)
listOuter.Size = UDim2.new(1, -20, 1, -54 - 32)
listOuter.BackgroundColor3 = STROKE_IN
listOuter.BorderSizePixel = 0
listOuter.BackgroundTransparency = 1
listOuter.ZIndex = 14
local listInner = Instance.new("Frame", listOuter)
listInner.Position = UDim2.fromOffset(1, 1)
listInner.Size = UDim2.new(1, -2, 1, -2)
listInner.BackgroundColor3 = PANEL
listInner.BorderSizePixel = 0
listInner.BackgroundTransparency = 1
listInner.ZIndex = 14

local list = Instance.new("ScrollingFrame", listInner)
list.Name = "List"
list.Size = UDim2.new(1, 0, 1, 0)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 3
list.ScrollBarImageColor3 = ACCENT
list.ScrollBarImageTransparency = 1
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ZIndex = 15
local listLayout = Instance.new("UIListLayout", list)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 4)
local listPad = pad(list, 6, 6, 6, 6)

-- footer (discord)
local footer = Instance.new("TextButton", gameWindow.body)
footer.Name = "Footer"
footer.Position = UDim2.new(0, 10, 1, -28)
footer.Size = UDim2.new(1, -20, 0, 22)
footer.BackgroundColor3 = PANEL
footer.BorderSizePixel = 0
footer.BackgroundTransparency = 1
footer.AutoButtonColor = false
footer.Text = ""
footer.ZIndex = 14
local footerOutline = Instance.new("Frame", footer)
footerOutline.Size = UDim2.new(1, 0, 1, 0)
footerOutline.BackgroundColor3 = STROKE_IN
footerOutline.BorderSizePixel = 0
footerOutline.BackgroundTransparency = 1
footerOutline.ZIndex = 14
local footerInner = Instance.new("Frame", footerOutline)
footerInner.Position = UDim2.fromOffset(1, 1)
footerInner.Size = UDim2.new(1, -2, 1, -2)
footerInner.BackgroundColor3 = PANEL
footerInner.BorderSizePixel = 0
footerInner.BackgroundTransparency = 1
footerInner.ZIndex = 15
local footerLbl = Instance.new("TextLabel", footerInner)
footerLbl.Size = UDim2.new(1, 0, 1, 0)
footerLbl.BackgroundTransparency = 1
footerLbl.Text = "no key? click to copy discord invite"
footerLbl.TextColor3 = DIM
footerLbl.TextTransparency = 1
footerLbl.Font = UI_FONT
footerLbl.TextSize = UI_TEXT_SIZE
footerLbl.ZIndex = 16

footer.MouseEnter:Connect(function()
    tw(footerLbl, 0.12, { TextColor3 = ACCENT })
end)
footer.MouseLeave:Connect(function()
    tw(footerLbl, 0.12, { TextColor3 = DIM })
end)
footer.MouseButton1Click:Connect(function()
    pcall(function() if setclipboard then setclipboard(DISCORD_INVITE) end end)
    footerLbl.Text = "copied: " .. DISCORD_INVITE
    footerLbl.TextColor3 = OK_COLOR
    task.delay(1.6, function()
        if footerLbl.Parent then
            footerLbl.Text = "no key? click to copy discord invite"
            footerLbl.TextColor3 = DIM
        end
    end)
end)

-- =============== game rows ====================================
local rows         = {}
local selectedId   = nil
local gameSelected = false

local function buildRow(g, idx)
    local row = Instance.new("TextButton", list)
    row.Name = g.id
    row.Size = UDim2.new(1, 0, 0, 26)
    row.BackgroundColor3 = INLINE
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.AutoButtonColor = false
    row.Text = ""
    row.LayoutOrder = idx
    row.ZIndex = 16

    local outlineRow = Instance.new("Frame", row)
    outlineRow.Size = UDim2.new(1, 0, 1, 0)
    outlineRow.BackgroundColor3 = STROKE_IN
    outlineRow.BorderSizePixel = 0
    outlineRow.BackgroundTransparency = 1
    outlineRow.ZIndex = 16
    local innerRow = Instance.new("Frame", outlineRow)
    innerRow.Position = UDim2.fromOffset(1, 1)
    innerRow.Size = UDim2.new(1, -2, 1, -2)
    innerRow.BackgroundColor3 = INLINE
    innerRow.BackgroundTransparency = 1
    innerRow.BorderSizePixel = 0
    innerRow.ZIndex = 17

    local accentBar = Instance.new("Frame", innerRow)
    accentBar.Position = UDim2.fromOffset(0, 0)
    accentBar.Size = UDim2.new(0, 2, 1, 0)
    accentBar.BackgroundColor3 = ACCENT
    accentBar.BorderSizePixel = 0
    accentBar.BackgroundTransparency = 1
    accentBar.ZIndex = 18

    local label = Instance.new("TextLabel", innerRow)
    label.Position = UDim2.fromOffset(8, 0)
    label.Size = UDim2.new(1, -70, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = g.name
    label.TextColor3 = DIM
    label.TextTransparency = 1
    label.Font = UI_FONT
    label.TextSize = UI_TEXT_SIZE
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.ZIndex = 18

    local tag = Instance.new("TextLabel", innerRow)
    tag.AnchorPoint = Vector2.new(1, 0.5)
    tag.Position = UDim2.new(1, -22, 0.5, 0)
    tag.Size = UDim2.fromOffset(40, 14)
    tag.BackgroundColor3 = ACCENT_DARK
    tag.BackgroundTransparency = 1
    tag.BorderSizePixel = 0
    tag.Text = g.tag
    tag.TextColor3 = ACCENT
    tag.TextTransparency = 1
    tag.Font = UI_FONT_MONO
    tag.TextSize = 11
    tag.ZIndex = 18

    local arrow = Instance.new("TextLabel", innerRow)
    arrow.AnchorPoint = Vector2.new(1, 0.5)
    arrow.Position = UDim2.new(1, -6, 0.5, 0)
    arrow.Size = UDim2.fromOffset(12, 14)
    arrow.BackgroundTransparency = 1
    arrow.Text = ">"
    arrow.TextColor3 = DIM
    arrow.TextTransparency = 1
    arrow.Font = UI_FONT_BOLD
    arrow.TextSize = 14
    arrow.ZIndex = 18

    local function setHover(hover)
        if selectedId == g.id then return end
        if hover then
            tw(innerRow, 0.1, { BackgroundColor3 = PANEL_HI })
            tw(label,    0.1, { TextColor3 = TEXT })
            tw(arrow,    0.1, { TextColor3 = ACCENT })
            tw(accentBar,0.1, { BackgroundTransparency = 0.3 })
        else
            tw(innerRow, 0.1, { BackgroundColor3 = INLINE })
            tw(label,    0.1, { TextColor3 = DIM })
            tw(arrow,    0.1, { TextColor3 = DIM })
            tw(accentBar,0.1, { BackgroundTransparency = 1 })
        end
    end
    local function setSelected(sel)
        if sel then
            tw(innerRow,   0.12, { BackgroundColor3 = PANEL_HI })
            tw(outlineRow, 0.12, { BackgroundColor3 = STROKE_HI })
            tw(label,      0.12, { TextColor3 = TEXT })
            tw(arrow,      0.12, { TextColor3 = ACCENT })
            tw(accentBar,  0.12, { BackgroundTransparency = 0 })
        else
            tw(innerRow,   0.12, { BackgroundColor3 = INLINE })
            tw(outlineRow, 0.12, { BackgroundColor3 = STROKE_IN })
            tw(label,      0.12, { TextColor3 = DIM })
            tw(arrow,      0.12, { TextColor3 = DIM })
            tw(accentBar,  0.12, { BackgroundTransparency = 1 })
        end
    end

    row.MouseEnter:Connect(function() setHover(true) end)
    row.MouseLeave:Connect(function() setHover(false) end)
    row.MouseButton1Click:Connect(function()
        if selectedId and rows[selectedId] then rows[selectedId].setSelected(false) end
        selectedId = g.id
        setSelected(true)
        _G._elocate_setGame(g.id)
        gameSelected = true
    end)

    rows[g.id] = {
        row = row, outline = outlineRow, inner = innerRow,
        label = label, tag = tag, arrow = arrow, accentBar = accentBar,
        setSelected = setSelected, game = g,
    }
end

for i, g in ipairs(gamesList) do buildRow(g, i) end

-- search filter
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local q = searchBox.Text:lower():gsub("%s+", "")
    for _, info in pairs(rows) do
        local name = info.game.name:gsub("%s+", ""):lower()
        local id   = info.game.id:lower()
        local match = q == "" or name:find(q, 1, true) or id:find(q, 1, true)
        info.row.Visible = match
    end
end)

-- auto-detect on placeId & game name
task.spawn(function()
    task.wait(0.5)
    if gameSelected then return end
    local pid = tonumber(game.PlaceId) or 0
    local detected
    for _, g in ipairs(gamesList) do
        for _, p in ipairs(g.placeIds or {}) do
            if p == pid then detected = g; break end
        end
        if detected then break end
    end
    if not detected then
        local ok, info = pcall(function()
            return game:GetService("MarketplaceService"):GetProductInfo(pid)
        end)
        if ok and info and info.Name then
            local nm = tostring(info.Name):lower()
            for _, g in ipairs(gamesList) do
                local s = g.name:gsub(" ", ""):lower()
                if nm:find(s, 1, true) or nm:find(g.id:lower(), 1, true) then
                    detected = g; break
                end
            end
        end
    end
    if detected and rows[detected.id] then
        local hint = Instance.new("TextLabel", rows[detected.id].inner)
        hint.AnchorPoint = Vector2.new(1, 0.5)
        hint.Position = UDim2.new(1, -68, 0.5, 0)
        hint.Size = UDim2.fromOffset(48, 14)
        hint.BackgroundColor3 = ACCENT_DARK
        hint.BackgroundTransparency = 0.2
        hint.BorderSizePixel = 0
        hint.Text = "detected"
        hint.TextColor3 = ACCENT
        hint.Font = UI_FONT_MONO
        hint.TextSize = 10
        hint.ZIndex = 19
    end
end)

-- ===== entry animation =======================================
tw(dim, 0.3, { BackgroundTransparency = 0.45 })
fadeIn(gameWindow, 0.3)
tw(headerHint, 0.3, { TextTransparency = 0 })
tw(subtitle,   0.3, { TextTransparency = 0 })
tw(searchBorder, 0.3, { BackgroundTransparency = 0 })
tw(searchInner,  0.3, { BackgroundTransparency = 0 })
tw(searchBox,    0.3, { TextTransparency = 0 })
tw(listOuter,  0.3, { BackgroundTransparency = 0 })
tw(listInner,  0.3, { BackgroundTransparency = 0 })
tw(list,       0.3, { ScrollBarImageTransparency = 0 })
tw(footer,     0.3, { BackgroundTransparency = 0 })
tw(footerOutline, 0.3, { BackgroundTransparency = 0 })
tw(footerInner,   0.3, { BackgroundTransparency = 0 })
tw(footerLbl,     0.3, { TextTransparency = 0 })
for _, info in pairs(rows) do
    tw(info.outline, 0.3, { BackgroundTransparency = 0 })
    tw(info.inner,   0.3, { BackgroundTransparency = 0 })
    tw(info.label,   0.3, { TextTransparency = 0 })
    tw(info.tag,     0.3, { TextTransparency = 0, BackgroundTransparency = 0.2 })
    tw(info.arrow,   0.3, { TextTransparency = 0 })
end

-- card pop-in
gameWindow.card.Size = UDim2.fromOffset(pickerW - 10, pickerH - 10)
tw(gameWindow.card, 0.28, { Size = UDim2.fromOffset(pickerW, pickerH) }, Enum.EasingStyle.Back)

-- wait for selection
repeat task.wait(0.05) until gameSelected
task.wait(0.16)
fadeOutAndDestroy(gameWindow, 0.22)
task.wait(0.22)

-- ============================================================
--  STEP 2  KEY ENTRY
-- ============================================================
local keyW, keyH = 360, 232
local keyWindow = makeWindow(keyW, keyH, "<b>elocate.lol</b> | authorize")

local stepHint = Instance.new("TextLabel", keyWindow.top)
stepHint.AnchorPoint = Vector2.new(1, 0)
stepHint.Position = UDim2.new(1, -6, 0, 0)
stepHint.Size = UDim2.new(0, 80, 1, 0)
stepHint.BackgroundTransparency = 1
stepHint.Text = "step 2 / 2"
stepHint.TextColor3 = DIM
stepHint.TextTransparency = 1
stepHint.Font = UI_FONT_MONO
stepHint.TextSize = 12
stepHint.TextXAlignment = Enum.TextXAlignment.Right
stepHint.ZIndex = 15

-- selected game chip
local chip = Instance.new("Frame", keyWindow.body)
chip.Name = "Chip"
chip.Position = UDim2.fromOffset(10, 8)
chip.Size = UDim2.new(1, -20, 0, 22)
chip.BackgroundColor3 = STROKE_IN
chip.BorderSizePixel = 0
chip.BackgroundTransparency = 1
chip.ZIndex = 14
local chipInner = Instance.new("Frame", chip)
chipInner.Position = UDim2.fromOffset(1, 1)
chipInner.Size = UDim2.new(1, -2, 1, -2)
chipInner.BackgroundColor3 = PANEL
chipInner.BorderSizePixel = 0
chipInner.BackgroundTransparency = 1
chipInner.ZIndex = 15
local chipBar = Instance.new("Frame", chipInner)
chipBar.Size = UDim2.new(0, 2, 1, 0)
chipBar.BackgroundColor3 = ACCENT
chipBar.BorderSizePixel = 0
chipBar.BackgroundTransparency = 1
chipBar.ZIndex = 16
local chipLbl = Instance.new("TextLabel", chipInner)
chipLbl.Position = UDim2.fromOffset(8, 0)
chipLbl.Size = UDim2.new(1, -16, 1, 0)
chipLbl.BackgroundTransparency = 1
chipLbl.RichText = true
local profile = profiles[_G._elocate_gameMode] or profiles.universal
chipLbl.Text = string.format(
    '<font color="#7c7c8c">profile</font>  <font color="#%s">%s</font>',
    string.format("%02x%02x%02x",
        math.floor(ACCENT.R * 255),
        math.floor(ACCENT.G * 255),
        math.floor(ACCENT.B * 255)),
    profile.displayName
)
chipLbl.TextColor3 = TEXT
chipLbl.TextTransparency = 1
chipLbl.Font = UI_FONT
chipLbl.TextSize = UI_TEXT_SIZE
chipLbl.TextXAlignment = Enum.TextXAlignment.Left
chipLbl.ZIndex = 16

-- key field label
local keyLbl = Instance.new("TextLabel", keyWindow.body)
keyLbl.Position = UDim2.fromOffset(10, 38)
keyLbl.Size = UDim2.new(1, -20, 0, 14)
keyLbl.BackgroundTransparency = 1
keyLbl.Text = "license key"
keyLbl.TextColor3 = DIM
keyLbl.TextTransparency = 1
keyLbl.Font = UI_FONT
keyLbl.TextSize = UI_TEXT_SIZE
keyLbl.TextXAlignment = Enum.TextXAlignment.Left
keyLbl.ZIndex = 14

-- field
local fieldOuter = Instance.new("Frame", keyWindow.body)
fieldOuter.Position = UDim2.fromOffset(10, 56)
fieldOuter.Size = UDim2.new(1, -20, 0, 26)
fieldOuter.BackgroundColor3 = STROKE_IN
fieldOuter.BorderSizePixel = 0
fieldOuter.BackgroundTransparency = 1
fieldOuter.ZIndex = 14
local fieldInner = Instance.new("Frame", fieldOuter)
fieldInner.Position = UDim2.fromOffset(1, 1)
fieldInner.Size = UDim2.new(1, -2, 1, -2)
fieldInner.BackgroundColor3 = PANEL
fieldInner.BorderSizePixel = 0
fieldInner.BackgroundTransparency = 1
fieldInner.ZIndex = 15
local fieldBar = Instance.new("Frame", fieldInner)
fieldBar.Size = UDim2.new(0, 2, 1, 0)
fieldBar.BackgroundColor3 = ACCENT
fieldBar.BorderSizePixel = 0
fieldBar.BackgroundTransparency = 1
fieldBar.ZIndex = 16
local field = Instance.new("TextBox", fieldInner)
field.Position = UDim2.fromOffset(10, 0)
field.Size = UDim2.new(1, -20, 1, 0)
field.BackgroundTransparency = 1
field.Text = ""
field.PlaceholderText = "paste key  (or  key:userid)"
field.PlaceholderColor3 = DIM
field.TextColor3 = TEXT
field.TextTransparency = 1
field.Font = UI_FONT_MONO
field.TextSize = 13
field.TextXAlignment = Enum.TextXAlignment.Left
field.ClearTextOnFocus = false
field.ClipsDescendants = true
field.ZIndex = 17

-- verify button
local btnOuter = Instance.new("Frame", keyWindow.body)
btnOuter.Position = UDim2.fromOffset(10, 92)
btnOuter.Size = UDim2.new(1, -20, 0, 26)
btnOuter.BackgroundColor3 = STROKE_HI
btnOuter.BorderSizePixel = 0
btnOuter.BackgroundTransparency = 1
btnOuter.ZIndex = 14
local btnInner = Instance.new("Frame", btnOuter)
btnInner.Position = UDim2.fromOffset(1, 1)
btnInner.Size = UDim2.new(1, -2, 1, -2)
btnInner.BackgroundColor3 = ACCENT_DARK
btnInner.BorderSizePixel = 0
btnInner.BackgroundTransparency = 1
btnInner.ZIndex = 15
local btnGrad = Instance.new("UIGradient", btnInner)
btnGrad.Rotation = 90
btnGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, ACCENT_DEEP),
    ColorSequenceKeypoint.new(1, ACCENT_DARK),
}
local verifyBtn = Instance.new("TextButton", btnInner)
verifyBtn.Size = UDim2.new(1, 0, 1, 0)
verifyBtn.BackgroundTransparency = 1
verifyBtn.AutoButtonColor = false
verifyBtn.Text = "authorize"
verifyBtn.TextColor3 = TEXT
verifyBtn.TextTransparency = 1
verifyBtn.Font = UI_FONT_BOLD
verifyBtn.TextSize = UI_TEXT_SIZE
verifyBtn.ZIndex = 17

-- discord helper
local discordHelp = Instance.new("TextButton", keyWindow.body)
discordHelp.Position = UDim2.fromOffset(10, 124)
discordHelp.Size = UDim2.new(1, -20, 0, 14)
discordHelp.BackgroundTransparency = 1
discordHelp.AutoButtonColor = false
discordHelp.Text = "no key? click to copy discord invite"
discordHelp.TextColor3 = DIM
discordHelp.TextTransparency = 1
discordHelp.Font = UI_FONT
discordHelp.TextSize = UI_TEXT_SIZE
discordHelp.ZIndex = 14
discordHelp.MouseEnter:Connect(function() tw(discordHelp, 0.1, { TextColor3 = ACCENT }) end)
discordHelp.MouseLeave:Connect(function() tw(discordHelp, 0.1, { TextColor3 = DIM }) end)
discordHelp.MouseButton1Click:Connect(function()
    pcall(function() if setclipboard then setclipboard(DISCORD_INVITE) end end)
    discordHelp.Text = "copied: " .. DISCORD_INVITE
    discordHelp.TextColor3 = OK_COLOR
    task.delay(1.4, function()
        if discordHelp.Parent then
            discordHelp.Text = "no key? click to copy discord invite"
            discordHelp.TextColor3 = DIM
        end
    end)
end)

-- progress bar
local prog = Instance.new("Frame", keyWindow.body)
prog.Position = UDim2.fromOffset(10, 148)
prog.Size = UDim2.new(1, -20, 0, 4)
prog.BackgroundColor3 = STROKE_IN
prog.BorderSizePixel = 0
prog.BackgroundTransparency = 1
prog.ZIndex = 14
local progFill = Instance.new("Frame", prog)
progFill.Size = UDim2.new(0, 0, 1, 0)
progFill.BackgroundColor3 = ACCENT
progFill.BorderSizePixel = 0
progFill.BackgroundTransparency = 1
progFill.ZIndex = 15
local progGrad = Instance.new("UIGradient", progFill)
progGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, ACCENT_DEEP),
    ColorSequenceKeypoint.new(1, ACCENT),
}

-- status
local status = Instance.new("TextLabel", keyWindow.body)
status.Position = UDim2.fromOffset(10, 158)
status.Size = UDim2.new(1, -20, 0, 22)
status.BackgroundTransparency = 1
status.Text = "waiting for key..."
status.TextColor3 = DIM
status.TextTransparency = 1
status.Font = UI_FONT
status.TextSize = UI_TEXT_SIZE
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextWrapped = true
status.ClipsDescendants = true
status.ZIndex = 14

-- back button
local backBtn = Instance.new("TextButton", keyWindow.body)
backBtn.Position = UDim2.fromOffset(10, 184)
backBtn.Size = UDim2.fromOffset(60, 16)
backBtn.BackgroundTransparency = 1
backBtn.AutoButtonColor = false
backBtn.Text = "< back"
backBtn.TextColor3 = DIM
backBtn.TextTransparency = 1
backBtn.Font = UI_FONT
backBtn.TextSize = UI_TEXT_SIZE
backBtn.TextXAlignment = Enum.TextXAlignment.Left
backBtn.ZIndex = 14
backBtn.MouseEnter:Connect(function() tw(backBtn, 0.1, { TextColor3 = ACCENT }) end)
backBtn.MouseLeave:Connect(function() tw(backBtn, 0.1, { TextColor3 = DIM }) end)

-- field focus stroke
field.Focused:Connect(function()
    tw(fieldOuter, 0.1, { BackgroundColor3 = ACCENT })
    tw(fieldBar,   0.1, { BackgroundColor3 = ACCENT })
end)
field.FocusLost:Connect(function()
    tw(fieldOuter, 0.1, { BackgroundColor3 = STROKE_IN })
end)

-- entry animation
fadeIn(keyWindow, 0.3)
tw(stepHint,    0.3, { TextTransparency = 0 })
tw(chip,        0.3, { BackgroundTransparency = 0 })
tw(chipInner,   0.3, { BackgroundTransparency = 0 })
tw(chipBar,     0.3, { BackgroundTransparency = 0 })
tw(chipLbl,     0.3, { TextTransparency = 0 })
tw(keyLbl,      0.3, { TextTransparency = 0 })
tw(fieldOuter,  0.3, { BackgroundTransparency = 0 })
tw(fieldInner,  0.3, { BackgroundTransparency = 0 })
tw(fieldBar,    0.3, { BackgroundTransparency = 0 })
tw(field,       0.3, { TextTransparency = 0 })
tw(btnOuter,    0.3, { BackgroundTransparency = 0 })
tw(btnInner,    0.3, { BackgroundTransparency = 0 })
tw(verifyBtn,   0.3, { TextTransparency = 0 })
tw(discordHelp, 0.3, { TextTransparency = 0 })
tw(prog,        0.3, { BackgroundTransparency = 0 })
tw(progFill,    0.3, { BackgroundTransparency = 0 })
tw(status,      0.3, { TextTransparency = 0 })
tw(backBtn,     0.3, { TextTransparency = 0 })

keyWindow.card.Size = UDim2.fromOffset(keyW - 10, keyH - 10)
tw(keyWindow.card, 0.28, { Size = UDim2.fromOffset(keyW, keyH) }, Enum.EasingStyle.Back)

-- back returns to step 1 (relaunch the loader by destroying + restarting)
backBtn.MouseButton1Click:Connect(function()
    tw(dim, 0.2, { BackgroundTransparency = 1 })
    fadeOutAndDestroy(keyWindow, 0.2)
    task.wait(0.22)
    if screen and screen.Parent then screen:Destroy() end
    -- silently restart loader via loadstring is not possible here, so just exit; user can re-execute
    _G._elocate_gameMode = nil
    _G._elocate_gameProfile = nil
    error("[elocate.lol] re-execute the script to pick a different game", 0)
end)

-- ===== verification logic ====================================
local _verified = false
local _denied   = false
local _busy     = false

local function setStatus(text, color)
    status.Text = text
    status.TextColor3 = color or DIM
end

-- ============================================================
-- elocate.lol auth (v2) - Roblox UserId binding
-- Replaced unstable HWID system. UserId is permanent per Roblox account
-- so the same player always reuses their slot, no more "1/1 used" bug.
-- ============================================================
local function getUserId()
    local lp = Players.LocalPlayer
    if not lp then
        local t0 = os.clock()
        while not Players.LocalPlayer and os.clock() - t0 < 5 do task.wait(0.05) end
        lp = Players.LocalPlayer
    end
    if lp and lp.UserId and lp.UserId > 0 then return tostring(lp.UserId) end
    return nil
end

local function animProgress(seconds)
    progFill.Size = UDim2.new(0, 0, 1, 0)
    tw(progFill, seconds, { Size = UDim2.new(1, 0, 1, 0) })
end

local function flashError(msg)
    setStatus(msg, BAD_COLOR)
    tw(fieldOuter, 0.1, { BackgroundColor3 = BAD_COLOR })
    task.delay(0.55, function()
        tw(fieldOuter, 0.2, { BackgroundColor3 = STROKE_IN })
    end)
end

local function doVerify()
    if _busy or _verified then return end
    local raw = field.Text:gsub("%s+", "")
    if #raw < 4 then flashError("invalid key") return end

    -- support manual userid override: "key:userid" or "key|userid"
    local k, manualId = raw, nil
    local sep = raw:find("[:|]")
    if sep then
        k = raw:sub(1, sep - 1)
        local tail = raw:sub(sep + 1):gsub("[^%d]", "")
        if #tail > 0 then manualId = tail end
    end

    local userid = manualId or getUserId()
    if not userid then
        flashError("no userid — type  key:yourUserId  to log in manually")
        return
    end

    _busy = true
    setStatus("verifying...", DIM)
    animProgress(0.9)
    _G._elocate_userid = userid

    local payload = HttpService:JSONEncode({
        key     = k,
        userid  = userid,
        placeId = tostring(game.PlaceId),
        game    = _G._elocate_gameMode or "universal",
    })

    local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    local headers = { ["Content-Type"] = "application/json" }

    if not req then
        _busy = false
        flashError("no http function (unsupported executor)")
        return
    end

    local ok, res = pcall(function()
        return req({ Url = CURVE_LOADER_ENDPOINT, Method = "POST", Headers = headers, Body = payload })
    end)

    if not ok or not res then
        _busy = false
        flashError("network error")
        return
    end

    local body = res.Body or ""
    local data
    pcall(function() data = HttpService:JSONDecode(body) end)

    local code = res.StatusCode or res.Status or 0
    if (code == 200 or code == 201) and data and data.ok then
        _G._elocate_key        = k
        _G._elocate_key_user   = data.user or "user"
        _G._elocate_key_until  = data.expires or 0
        _G._elocate_users_used = data.users_used or 0
        _G._elocate_max_users  = data.max_users or 1
        setStatus(("authorized as %s  (%d/%d slots)"):format(
            tostring(_G._elocate_key_user),
            _G._elocate_users_used, _G._elocate_max_users), OK_COLOR)
        _verified = true
    else
        _busy = false
        local reason = (data and (data.reason or data.message)) or ("denied (http " .. tostring(code) .. ")")
        flashError(tostring(reason))
        local terminal = {
            ["invalid key"] = true,
            ["key revoked"] = true,
            ["key expired"] = true,
            ["userid not whitelisted for this key"] = true,
        }
        if terminal[reason] then _denied = true end
    end
end

verifyBtn.MouseEnter:Connect(function() tw(btnInner, 0.1, { BackgroundColor3 = ACCENT_DEEP }) end)
verifyBtn.MouseLeave:Connect(function() tw(btnInner, 0.1, { BackgroundColor3 = ACCENT_DARK }) end)
verifyBtn.MouseButton1Click:Connect(doVerify)
field.FocusLost:Connect(function(enter) if enter then doVerify() end end)

-- esc cancels
local escConn
escConn = UserInput.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.Escape then _denied = true end
end)

while not _verified and not _denied do task.wait(0.05) end
escConn:Disconnect()

-- exit animation
tw(dim, 0.25, { BackgroundTransparency = 1 })
fadeOutAndDestroy(keyWindow, 0.25)
task.wait(0.3)
screen:Destroy()

if _denied and not _verified then return end


_G._elocateRawWarn  = _G._elocateRawWarn  or warn
_G._elocateRawPrint = _G._elocateRawPrint or print
local _rawWarn  = _G._elocateRawWarn
local _rawPrint = _G._elocateRawPrint
local function warn(...)
    local args = table.pack(...)
    task.defer(function() pcall(_rawWarn, table.unpack(args, 1, args.n)) end)
end
local function print(...)
    local args = table.pack(...)
    task.defer(function() pcall(_rawPrint, table.unpack(args, 1, args.n)) end)
end
do
    local ok, h = pcall(function()
        if typeof(gethui) == "function" then return gethui() end
        return game:GetService("CoreGui")
    end)
    if ok and h then
        for _, child in ipairs(h:GetChildren()) do
            if child.Name:sub(1, 9) == "_elocate" then
                pcall(function() child:Destroy() end)
            end
        end
    end
end
local Library = {};
do
        Library = {
                Open = true;
                Folders = {};
                Accent = Color3.fromRGB(100, 100, 100);
                Pages = {};
                Sections = {};
                Flags = {};
                UnNamedFlags = 0;
                ThemeObjects = {};
                Instances = {};
                Holder = nil;
                PageHolder = nil;
                Gradient = nil;
                UIGradient = nil;
                Keys = {
                        [Enum.KeyCode.LeftShift] = "LS",
                        [Enum.KeyCode.RightShift] = "RS",
                        [Enum.KeyCode.LeftControl] = "LC",
                        [Enum.KeyCode.RightControl] = "RC",
                        [Enum.KeyCode.LeftAlt] = "LA",
                        [Enum.KeyCode.RightAlt] = "RA",
                        [Enum.KeyCode.CapsLock] = "CAPS",
                        [Enum.KeyCode.One] = "1",
                        [Enum.KeyCode.Two] = "2",
                        [Enum.KeyCode.Three] = "3",
                        [Enum.KeyCode.Four] = "4",
                        [Enum.KeyCode.Five] = "5",
                        [Enum.KeyCode.Six] = "6",
                        [Enum.KeyCode.Seven] = "7",
                        [Enum.KeyCode.Eight] = "8",
                        [Enum.KeyCode.Nine] = "9",
                        [Enum.KeyCode.Zero] = "0",
                        [Enum.KeyCode.KeypadOne] = "Num1",
                        [Enum.KeyCode.KeypadTwo] = "Num2",
                        [Enum.KeyCode.KeypadThree] = "Num3",
                        [Enum.KeyCode.KeypadFour] = "Num4",
                        [Enum.KeyCode.KeypadFive] = "Num5",
                        [Enum.KeyCode.KeypadSix] = "Num6",
                        [Enum.KeyCode.KeypadSeven] = "Num7",
                        [Enum.KeyCode.KeypadEight] = "Num8",
                        [Enum.KeyCode.KeypadNine] = "Num9",
                        [Enum.KeyCode.KeypadZero] = "Num0",
                        [Enum.KeyCode.Minus] = "-",
                        [Enum.KeyCode.Equals] = "=",
                        [Enum.KeyCode.Tilde] = "~",
                        [Enum.KeyCode.LeftBracket] = "[",
                        [Enum.KeyCode.RightBracket] = "]",
                        [Enum.KeyCode.RightParenthesis] = ")",
                        [Enum.KeyCode.LeftParenthesis] = "(",
                        [Enum.KeyCode.Semicolon] = ",",
                        [Enum.KeyCode.Quote] = "'",
                        [Enum.KeyCode.BackSlash] = "\\\\",
                        [Enum.KeyCode.Comma] = ",",
                        [Enum.KeyCode.Period] = ".",
                        [Enum.KeyCode.Slash] = "/",
                        [Enum.KeyCode.Asterisk] = "*",
                        [Enum.KeyCode.Plus] = "+",
                        [Enum.KeyCode.Backquote] = "`",
                        [Enum.UserInputType.MouseButton1] = "MB1",
                        [Enum.UserInputType.MouseButton2] = "MB2",
                        [Enum.UserInputType.MouseButton3] = "MB3"
                };
                Connections = {};
                UIFont = Font.fromEnum(Enum.Font.SourceSans);
                FontSize = 16;
        }
        local Flags = {};
        local Dropdowns = {};
        local Pickers = {};
        local VisValues = {};
        Library.__index = Library
        Library.Pages.__index = Library.Pages
        Library.Sections.__index = Library.Sections
        local LocalPlayer = game:GetService('Players').LocalPlayer;
        local _UIS_MOUSE = game:GetService("UserInputService")
        local Mouse = setmetatable({}, { __index = function(_, k)
                if k == "X" then
                        local ok, v = pcall(function() return _UIS_MOUSE:GetMouseLocation().X end)
                        return ok and v or 0
                elseif k == "Y" then
                        local ok, v = pcall(function() return _UIS_MOUSE:GetMouseLocation().Y end)
                        return ok and v or 0
                end
                return nil
        end })
        do
                function Library:Connection(Signal, Callback)
                        local Con = Signal:Connect(function(...)
                                local ok, err = pcall(Callback, ...)
                                if not ok then
                                        task.defer(function() pcall(rawget(_G, "_elocateRawWarn") or warn, "[elocate.lol] callback error: "..tostring(err)) end)
                                end
                        end)
                        return Con
                end
                function Library:Disconnect(Connection)
                        Connection:Disconnect()
                end
                function Library:Round(Number, Float)
                        return Float * math.floor(Number / Float)
                end
                function Library.NextFlag()
                        Library.UnNamedFlags = Library.UnNamedFlags + 1
                        return string.format("%.14g", Library.UnNamedFlags)
                end
                function Library:RGBA(r, g, b, alpha)
                        return Color3.fromRGB(r, g, b)
                end
                function Library:MakeDraggable(Instance, Button, Cutoff)
                        Instance.Active = true;
                        Button.InputBegan:Connect(function(Input)
                                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                                        local ObjPos = Vector2.new(
                                                Mouse.X - Instance.AbsolutePosition.X,
                                                Mouse.Y - Instance.AbsolutePosition.Y
                                        );
                                        if ObjPos.Y > (Cutoff or 40) then
                                                return;
                                        end;
                                        while game:GetService("UserInputService"):IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                                                Instance.Position = UDim2.new(
                                                        0,
                                                        Mouse.X - ObjPos.X + (Instance.Size.X.Offset * Instance.AnchorPoint.X),
                                                        0,
                                                        Mouse.Y - ObjPos.Y + (Instance.Size.Y.Offset * Instance.AnchorPoint.Y)
                                                );
                                                game:GetService("RunService").RenderStepped:Wait();
                                        end;
                                end;
                        end);
                end;
                function Library:GetConfig()
                        local Config = ""
                        for Index, Value in pairs(self.Flags) do
                                if
                                        Index ~= "ConfigConfig_List"
                                        and Index ~= "ConfigConfig_Load"
                                        and Index ~= "ConfigConfig_Save"
                                then
                                        local Value2 = Value
                                        local Final = ""
                                        if typeof(Value2) == "Color3" then
                                                local hue, sat, val = Value2:ToHSV()
                                                Final = ("rgb(%s,%s,%s,%s)"):format(hue, sat, val, 1)
                                        elseif typeof(Value2) == "table" and Value2.Color and Value2.Transparency then
                                                local hue, sat, val = Value2.Color:ToHSV()
                                                Final = ("rgb(%s,%s,%s,%s)"):format(hue, sat, val, Value2.Transparency)
                                        elseif typeof(Value2) == "table" and Value.Mode then
                                                local Values = Value.current
                                                Final = ("key(%s,%s,%s)"):format(Values[1] or "nil", Values[2] or "nil", Value.Mode)
                                        elseif Value2 ~= nil then
                                                if typeof(Value2) == "boolean" then
                                                        Value2 = ("bool(%s)"):format(tostring(Value2))
                                                elseif typeof(Value2) == "table" then
                                                        local New = "table("
                                                        for Index2, Value3 in pairs(Value2) do
                                                                New = New .. Value3 .. ","
                                                        end
                                                        if New:sub(#New) == "," then
                                                                New = New:sub(0, #New - 1)
                                                        end
                                                        Value2 = New .. ")"
                                                elseif typeof(Value2) == "string" then
                                                        Value2 = ("string(%s)"):format(Value2)
                                                elseif typeof(Value2) == "number" then
                                                        Value2 = ("number(%s)"):format(Value2)
                                                end
                                                Final = Value2
                                        end
                                        Config = Config .. Index .. ": " .. tostring(Final) .. "\\n"
                                end
                        end
                        return Config
                end
                function Library:LoadConfig(Config)
                        local Table = string.split(Config, "\\n")
                        local Table2 = {}
                        for Index, Value in pairs(Table) do
                                local Table3 = string.split(Value, ":")
                                if Table3[1] ~= "ConfigConfig_List" and #Table3 >= 2 then
                                        local Value = Table3[2]:sub(2, #Table3[2])
                                        if Value:sub(1, 3) == "rgb" then
                                                local Table4 = string.split(Value:sub(5, #Value - 1), ",")
                                                Value = Table4
                                        elseif Value:sub(1, 3) == "key" then
                                                local Table4 = string.split(Value:sub(5, #Value - 1), ",")
                                                if Table4[1] == "nil" and Table4[2] == "nil" then
                                                        Table4[1] = nil
                                                        Table4[2] = nil
                                                end
                                                Value = Table4
                                        elseif Value:sub(1, 4) == "bool" then
                                                local Bool = Value:sub(6, #Value - 1)
                                                Value = Bool == "true"
                                        elseif Value:sub(1, 5) == "table" then
                                                local Table4 = string.split(Value:sub(7, #Value - 1), ",")
                                                Value = Table4
                                        elseif Value:sub(1, 6) == "string" then
                                                local String = Value:sub(8, #Value - 1)
                                                Value = String
                                        elseif Value:sub(1, 6) == "number" then
                                                local Number = tonumber(Value:sub(8, #Value - 1))
                                                Value = Number
                                        end
                                        Table2[Table3[1]] = Value
                                end
                        end
                        for i, v in pairs(Table2) do
                                if Flags[i] then
                                        if typeof(Flags[i]) == "table" then
                                                Flags[i]:Set(v)
                                        else
                                                Flags[i](v)
                                        end
                                end
                        end
                end
                Library.IO = {}
                do
                        local function _hasFn(n)
                                local g = getgenv and getgenv() or _G
                                return type(g[n]) == "function"
                        end
                        local function _call(n, ...)
                                local g = getgenv and getgenv() or _G
                                local fn = g[n]
                                if type(fn) ~= "function" then return false end
                                local ok, r = pcall(fn, ...)
                                if not ok then return false end
                                return true, r
                        end
                        function Library.IO.writefile(p, d)  local ok = _call("writefile",  p, d); return ok end
                        function Library.IO.readfile(p)       local ok, r = _call("readfile",  p); return ok and r or nil end
                        function Library.IO.isfile(p)         local ok, r = _call("isfile",    p); return ok and r or false end
                        function Library.IO.delfile(p)        local ok = _call("delfile",      p); return ok end
                        function Library.IO.listfiles(p)      local ok, r = _call("listfiles", p); return ok and r or {} end
                        function Library.IO.makefolder(p)     local ok = _call("makefolder",   p); return ok end
                        function Library.IO.isfolder(p)       local ok, r = _call("isfolder",  p); return ok and r or false end
                        Library.IO.HasIO = _hasFn("writefile") and _hasFn("readfile")
                end
                Library.Games = {
                        DaHood        = { PlaceIds = {2788229376} },
                        Arsenal       = { PlaceIds = {286090429} },
                        PhantomForces = { PlaceIds = {292439477} },
                        HoodCustoms   = { PlaceIds = {} },
                        DaTrack       = { PlaceIds = {} },
                        HoodCopies    = { PlaceIds = {} },
                        Universal     = { PlaceIds = {} },
                }
                function Library:GetCurrentGame()
                        local pid = game.PlaceId
                        for name, info in pairs(self.Games) do
                                for _, p in ipairs(info.PlaceIds or {}) do
                                        if p == pid then return name end
                                end
                        end
                        return "Universal"
                end
                function Library:RegisterGame(name, placeIds)
                        if not name or name == "" then return end
                        self.Games[name] = self.Games[name] or {PlaceIds = {}}
                        if type(placeIds) == "number" then placeIds = {placeIds} end
                        for _, p in ipairs(placeIds or {}) do
                                table.insert(self.Games[name].PlaceIds, p)
                        end
                end
                Library.ConfigFolder = "curve_configs"
                local function _gameFolder()
                        local g = Library:GetCurrentGame()
                        local root = Library.ConfigFolder
                        Library.IO.makefolder(root)
                        Library.IO.makefolder(root .. "/" .. g)
                        return root .. "/" .. g
                end
                local function _path(name)
                        return _gameFolder() .. "/" .. tostring(name) .. ".cfg"
                end
                function Library:SaveConfig(name)
                        if not name or name == "" then return false end
                        if not Library.IO.HasIO then return false end
                        local data = self:GetConfig() or ""
                        local p = _path(name)
                        Library.IO.writefile(p, data)
                        return Library.IO.isfile(p)
                end
                function Library:LoadSavedConfig(name)
                        if not name or name == "" then return false end
                        if not Library.IO.HasIO then return false end
                        local p = _path(name)
                        if not Library.IO.isfile(p) then return false end
                        local data = Library.IO.readfile(p)
                        if not data then return false end
                        self:LoadConfig(data)
                        return true
                end
                function Library:DeleteConfig(name)
                        if not name or name == "" then return false end
                        local p = _path(name)
                        Library.IO.delfile(p)
                        return not Library.IO.isfile(p)
                end
                function Library:GetConfigs()
                        local out = {}
                        if not Library.IO.HasIO then return out end
                        local files = Library.IO.listfiles(_gameFolder())
                        if type(files) ~= "table" then return out end
                        for _, fp in ipairs(files) do
                                local fn = tostring(fp)
                                local n = fn:match("([^/\\]+)%.cfg$")
                                if n then table.insert(out, n) end
                        end
                        table.sort(out)
                        return out
                end
                function Library:SetOpen(bool)
                        if typeof(bool) == 'boolean' then
                                Library.Open = bool;
                                if bool then
                                        Library.Holder.Visible = true
                                end
                                for _,v in next, Library.Instances do
                                        if v:IsA("Frame") or v:IsA("TextButton") then
                                                if v.BackgroundTransparency ~= 1 then
                                                        task.spawn(function()
                                                                local t = game:GetService("TweenService"):Create(v, TweenInfo.new(0.25, Enum.EasingStyle.Linear, bool and Enum.EasingDirection.Out or Enum.EasingDirection.In), {BackgroundTransparency = bool and 0 or 0.95})
                                                                t.Completed:Connect(function()
                                                                        if bool == false then
                                                                                Library.Holder.Visible = false
                                                                        end
                                                                end)
                                                                t:Play()
                                                        end)
                                                end
                                        elseif v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then
                                                if v.TextTransparency ~= 1 and v.BackgroundTransparency == 1 then
                                                        task.spawn(function()
                                                                game:GetService("TweenService"):Create(v, TweenInfo.new(0.25, Enum.EasingStyle.Linear, bool and Enum.EasingDirection.Out or Enum.EasingDirection.In), {TextTransparency = bool and 0 or 0.95}):Play()
                                                        end)
                                                end
                                        elseif v:IsA("UIStroke") then
                                                task.spawn(function()
                                                        game:GetService("TweenService"):Create(v, TweenInfo.new(0.25, Enum.EasingStyle.Linear, bool and Enum.EasingDirection.Out or Enum.EasingDirection.In), {Transparency = bool and 0 or 0.95}):Play()
                                                end)
                                        elseif v:IsA("ImageButton") then
                                                task.spawn(function()
                                                        game:GetService("TweenService"):Create(v, TweenInfo.new(0.25, Enum.EasingStyle.Linear, bool and Enum.EasingDirection.Out or Enum.EasingDirection.In), {ImageTransparency = bool and 0 or 0.95, BackgroundTransparency = bool and 0 or 0.95}):Play()
                                                end)
                                        end
                                end
                                task.spawn(function()
                                        game:GetService("TweenService"):Create(Library.PageHolder, TweenInfo.new(0.25, Enum.EasingStyle.Quad, bool and Enum.EasingDirection.Out or Enum.EasingDirection.In), {Position = bool and UDim2.new(0,0,0,0) or UDim2.new(0,60,0,0)}):Play()
                                        if bool then
                                                task.wait(0.05)
                                        end
                                        game:GetService("TweenService"):Create(Library.Gradient, TweenInfo.new(0.25, Enum.EasingStyle.Quad, bool and Enum.EasingDirection.Out or Enum.EasingDirection.In), {Position = bool and UDim2.new(0.5,0,0,2) or UDim2.new(1,0,0,2)}):Play()
                                        game:GetService("TweenService"):Create(Library.Gradient, TweenInfo.new(0.25, Enum.EasingStyle.Quad, bool and Enum.EasingDirection.Out or Enum.EasingDirection.In), {Size = bool and UDim2.new(0.5,0,0,1) or UDim2.new(0,0,0,1)}):Play()
                                end)
                        end
                end;
                function Library:ChangeAccent(Color)
                        Library.Accent = Color
                        for obj, theme in next, Library.ThemeObjects do
                                if theme:IsA("Frame") or theme:IsA("TextButton") then
                                        theme.BackgroundColor3 = Color
                                elseif theme:IsA("TextLabel") then
                                        theme.TextColor3 = Color
                                end
                        end
                        if Library.TabGlows then
                                for _, glow in ipairs(Library.TabGlows) do
                                        pcall(function() glow.BackgroundColor3 = Color end)
                                end
                        end
                        if Library.TabBgGrads then
                                for _, grad in ipairs(Library.TabBgGrads) do
                                        pcall(function()
                                                grad.Color = ColorSequence.new{
                                                        ColorSequenceKeypoint.new(0, Color),
                                                        ColorSequenceKeypoint.new(1, Color3.new(0.043, 0.043, 0.043))
                                                }
                                        end)
                                end
                        end
                        if Library.UIGradient then
                                Library.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color  ),ColorSequenceKeypoint.new(1,Color3.new(0.04313725605607033, 0.04313725605607033, 0.04313725605607033) )}
                        end
                end
                function Library:IsMouseOverFrame(Frame)
                        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;
                        if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
                                and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then
                                return true;
                        end;
                end;
        end
        do
                function Library:NewPicker(default, defaultalpha, parent, count, flag, callback)
                        local Icon = Instance.new('TextButton', parent)
                        local Gradient = Instance.new('UIGradient', Icon)
                        local Window = Instance.new('Frame', Icon)
                        local Sat = Instance.new('ImageButton', Window)
                        local Hue = Instance.new('ImageButton', Window)
                        do
                                table.insert(Library.Instances, Icon)
                                table.insert(Library.Instances, Window)
                                table.insert(Library.Instances, Sat)
                                table.insert(Library.Instances, Hue)
                                table.insert(Pickers, Window)
                        end
                        Icon.Name = "Icon"
                        Icon.Position = UDim2.new(1, -30 - (count * 15) - (count * 6),0,4)
                        Icon.Size = UDim2.new(0,15,0,6)
                        Icon.BackgroundColor3 = default
                        Icon.BorderColor3 = Color3.new(0,0,0)
                        Icon.AutoButtonColor = false
                        Icon.Text = ""
                        Gradient.Name = "Gradient"
                        Gradient.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(
                                        0,
                                        Color3.new(0.7803921699523926, 0.7490196228027344, 0.800000011920929)
                                ),
                                ColorSequenceKeypoint.new(
                                        1,
                                        Color3.new(1, 1, 1)
                                )
                        }
                        Gradient.Rotation = -90
                        Window.Name = "Window"
                        Window.Position = UDim2.new(0,-120,0,10)
                        Window.Size = UDim2.new(0,150,0,133)
                        Window.BackgroundColor3 = Color3.new(0.0431,0.0431,0.0431)
                        Window.BorderColor3 = Color3.new(0.1098,0.1098,0.1098)
                        Window.ZIndex = 1220
                        Window.Visible = false
                        Sat.Name = "Sat"
                        Sat.Position = UDim2.new(0,5,0,5)
                        Sat.Size = UDim2.new(0,123,0,123)
                        Sat.BackgroundColor3 = default
                        Sat.BorderColor3 = Color3.new(0.1098,0.1098,0.1098)
                        Sat.Image = "http://www.roblox.com/asset/?id=13882904626"
                        Sat.AutoButtonColor = false
                        Sat.ZIndex = 1220
                        Hue.Name = "Hue"
                        Hue.Position = UDim2.new(1,-15,0,5)
                        Hue.Size = UDim2.new(0,10,0,123)
                        Hue.BackgroundColor3 = Color3.new(1,1,1)
                        Hue.BorderColor3 = Color3.new(0.1098,0.1098,0.1098)
                        Hue.Image = "http://www.roblox.com/asset/?id=13882976736"
                        Hue.ZIndex = 1220
                        Hue.AutoButtonColor = false
                        local mouseover = false
                        local hue, sat, val = default:ToHSV()
                        local hsv = default:ToHSV()
                        local alpha = defaultalpha
                        local oldcolor = hsv
                        local function set(color, a, nopos, setcolor)
                                if type(color) == "table" then
                                        a = color[4]
                                        color = Color3.fromHSV(color[1], color[2], color[3])
                                end
                                if type(color) == "string" then
                                        color = Color3.fromHex(color)
                                end
                                local oldcolor = hsv
                                local oldalpha = alpha
                                hue, sat, val = color:ToHSV()
                                alpha = a or 1
                                hsv = Color3.fromHSV(hue, sat, val)
                                if hsv ~= oldcolor or alpha ~= oldalpha then
                                        Icon.BackgroundColor3 = hsv
                                        if not nopos then
                                                if setcolor then
                                                        Sat.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
                                                end
                                        end
                                        if flag then
                                                Library.Flags[flag] = Library:RGBA(hsv.r * 255, hsv.g * 255, hsv.b * 255, alpha)
                                        end
                                        callback(Library:RGBA(hsv.r * 255, hsv.g * 255, hsv.b * 255, alpha))
                                end
                        end
                        Flags[flag] = set
                        set(default, defaultalpha)
                        local defhue, _, _ = default:ToHSV()
                        local curhuesizey = defhue
                        local function updatesatval(input, set_callback)
                                local sizeX = math.clamp((input.Position.X - Sat.AbsolutePosition.X) / Sat.AbsoluteSize.X,0,1)
                                local sizeY = 1- math.clamp((((input.Position.Y - 30) - Sat.AbsolutePosition.Y) + 36) / Sat.AbsoluteSize.Y,0,1)
                                if set_callback then
                                        set(Color3.fromHSV(curhuesizey or hue, sizeX, sizeY), alpha or defaultalpha, true, false)
                                end
                        end
                        local slidingsaturation = false
                        Sat.InputBegan:Connect(function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                        slidingsaturation = true
                                        updatesatval(input)
                                end
                        end)
                        Sat.InputEnded:Connect(function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                        slidingsaturation = false
                                        updatesatval(input, true)
                                end
                        end)
                        local slidinghue = false
                        local function updatehue(input, set_callback)
                                local sizeY = 1- math.clamp((((input.Position.Y - 30) - Hue.AbsolutePosition.Y) + 36) / Hue.AbsoluteSize.Y,0,1)
                                Sat.BackgroundColor3 = Color3.fromHSV(sizeY, 1, 1)
                                curhuesizey = sizeY
                                if set_callback then
                                        set(Color3.fromHSV(sizeY, sat, val), alpha or defaultalpha, true, true)
                                end
                        end
                        Hue.InputBegan:Connect(function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                        slidinghue = true
                                        updatehue(input)
                                end
                        end)
                        Hue.InputEnded:Connect(function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                        slidinghue = false
                                        updatehue(input, true)
                                end
                        end)
                        local slidingalpha = false
                        Library:Connection(game:GetService("UserInputService").InputChanged, function(input)
                                if input.UserInputType == Enum.UserInputType.MouseMovement then
                                        if slidinghue then
                                                updatehue(input, true)
                                        end
                                        if slidingsaturation then
                                                updatesatval(input, true)
                                        end
                                end
                        end)
                        Icon.MouseButton1Click:Connect(function()
                                Window.Visible = not Window.Visible
                                if slidinghue then
                                        slidinghue = false
                                end
                                if slidingsaturation then
                                        slidingsaturation = false
                                end
                        end)
                        local colorpickertypes = {}
                        function colorpickertypes:Set(color, alpha)
                                set(color)
                        end
                        Library:Connection(game:GetService("UserInputService").InputBegan, function(Input)
                                if Window.Visible and Input.UserInputType == Enum.UserInputType.MouseButton1 then
                                        if not Library:IsMouseOverFrame(Window) and not Library:IsMouseOverFrame(Icon) then
                                                Window.Visible = false
                                        end
                                end
                        end)
                        return colorpickertypes, Window
                end
        end
        do
                local Pages = Library.Pages;
                local Sections = Library.Sections;
                function Library:Window(Options)
                        local Base = {
                                Pages = {};
                                Sections = {};
                                Elements = {};
                                Dragging = { false, UDim2.new(0, 0, 0, 0) };
                                Title = Options.Name or Options.Name or Options.Name or "new ui";
                        };
                        local _ScreenParent
                        local ok1, h = pcall(function() if typeof(gethui)=="function" then return gethui() end end)
                        if ok1 and h then _ScreenParent = h end
                        if not _ScreenParent then
                                local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
                                if ok2 and cg then
                                        local ok3 = pcall(function() local probe = Instance.new("Folder"); probe.Parent = cg; probe:Destroy() end)
                                        if ok3 then _ScreenParent = cg end
                                end
                        end
                        if not _ScreenParent then
                                _ScreenParent = LocalPlayer:WaitForChild("PlayerGui", 10)
                        end
                        local ScreenGui = Instance.new('ScreenGui', _ScreenParent)
                        pcall(function() ScreenGui.ResetOnSpawn = false end)
                        pcall(function() ScreenGui.Name = "_elocate_"..tostring(math.random(100000,999999)) end)
                        local Main = Instance.new('Frame', ScreenGui)
                        local Inline = Instance.new('Frame', Main)
                        local Middle = Instance.new('Frame', Inline)
                        local Line = Instance.new('Frame', Middle)
                        local Line2 = Instance.new('Frame', Middle)
                        local Gradient = Instance.new('Frame', Middle)
                        local UIGradient = Instance.new('UIGradient', Gradient)
                        local Top = Instance.new('TextButton', Inline)
                        local Title = Instance.new('TextLabel', Top)
                        local Bottom = Instance.new('Frame', Inline)
                        local Sections = Instance.new('Frame', Middle)
                        local Pages = Instance.new('Frame', Top)
                        local UIListLayout = Instance.new('UIListLayout', Pages)
                        local version = Instance.new('TextLabel', Bottom)
                        local corner1 = Instance.new('UICorner', Main)
                        local corner2 = Instance.new('UICorner', Inline)
                        local stroke1 = Instance.new('UIStroke', Main)
                        local stroke2 = Instance.new('UIStroke', Inline)
                        do
                                table.insert(Library.Instances, Main)
                                table.insert(Library.Instances, Inline)
                                table.insert(Library.Instances, Middle)
                                table.insert(Library.Instances, Line)
                                table.insert(Library.Instances, Line2)
                                table.insert(Library.Instances, Gradient)
                                table.insert(Library.Instances, Title)
                                table.insert(Library.Instances, Sections)
                                table.insert(Library.Instances, version)
                                table.insert(Library.ThemeObjects, Title)
                                table.insert(Library.ThemeObjects, version)
                        end
                        ScreenGui.DisplayOrder = 2
                        Main.Name = "Main"
                        Main.Position = UDim2.new(0.5,0,0.5,0)
                        Main.Size = UDim2.new(0,600,0,720)
                        Main.BackgroundColor3 = Color3.fromRGB(35, 25, 50)
                        Main.BorderColor3 = Color3.new(0,0,0)
                        Main.AnchorPoint = Vector2.new(0.5,0.5)
                        Library.Holder = Main
                        
                        
                        
                        
                        
                        function Library._GetPopupGui()
                                if Library._PopupGui and Library._PopupGui.Parent then return Library._PopupGui end
                                local pg = Instance.new("ScreenGui")
                                pcall(function() pg.Name = "_elocate_popups_"..tostring(math.random(100000,999999)) end)
                                pcall(function() pg.ResetOnSpawn = false end)
                                
                                
                                
                                
                                pcall(function() pg.IgnoreGuiInset = true end)
                                pcall(function() pg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling end)
                                pcall(function() pg.DisplayOrder = 1000000 end)
                                pcall(function() pg.Parent = _ScreenParent end)
                                Library._PopupGui = pg
                                return pg
                        end
                        Inline.Name = "Inline"
                        Inline.Position = UDim2.new(0,2,0,2)
                        Inline.Size = UDim2.new(1,-4,1,-4)
                        Inline.BackgroundColor3 = Color3.fromRGB(25, 18, 38)
                        Inline.BorderColor3 = Color3.new(0,0,0)
                        Middle.Name = "Middle"
                        Middle.Position = UDim2.new(0,-1,0,22)
                        Middle.Size = UDim2.new(1,2,1,-44)
                        Middle.BackgroundColor3 = Color3.fromRGB(30, 22, 42)
                        Middle.BorderColor3 = Color3.new(0,0,0)
                        Middle.BorderMode = Enum.BorderMode.Inset
                        Line.Name = "Line"
                        Line.Position = UDim2.new(0,-1,0,0)
                        Line.Size = UDim2.new(1,2,0,1)
                        Line.BackgroundColor3 = Color3.fromRGB(80, 60, 110)
                        Line.BorderSizePixel = 0
                        Line.BorderColor3 = Color3.new(0,0,0)
                        Line2.Name = "Line2"
                        Line2.Position = UDim2.new(0,-1,1,-1)
                        Line2.Size = UDim2.new(1,2,0,1)
                        Line2.BackgroundColor3 = Color3.fromRGB(80, 60, 110)
                        Line2.BorderSizePixel = 0
                        Line2.BorderColor3 = Color3.new(0,0,0)
                        Gradient.Name = "Gradient"
                        Gradient.Position = UDim2.new(0.5,0,0,2)
                        Gradient.Size = UDim2.new(0.5,0,0,1)
                        Gradient.BackgroundColor3 = Color3.new(1,1,1)
                        Gradient.BorderSizePixel = 0
                        Gradient.BorderColor3 = Color3.new(0,0,0)
                        Library.Gradient = Gradient
                        UIGradient.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(0, Library.Accent),
                                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 70, 150)),
                                ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 22, 42))
                        }
                        UIGradient.Rotation = 180
                        Library.UIGradient = UIGradient
                        Top.Name = "Top"
                        Top.Size = UDim2.new(1,0,0,22)
                        Top.BackgroundColor3 = Color3.new(1,1,1)
                        Top.BackgroundTransparency = 1
                        Top.BorderSizePixel = 0
                        Top.BorderColor3 = Color3.new(0,0,0)
                        Top.AutoButtonColor = false
                        Top.Text = ""
                        Title.Name = "Title"
                        Title.Position = UDim2.new(0,4,0,0)
                        Title.Size = UDim2.new(1,-4,1,0)
                        Title.BackgroundColor3 = Color3.new(1,1,1)
                        Title.BackgroundTransparency = 1
                        Title.BorderSizePixel = 0
                        Title.BorderColor3 = Color3.new(0,0,0)
                        Title.Text = Base.Title
                        Title.TextColor3 = Library.Accent
                        Title.FontFace = Library.UIFont
                        Title.TextSize = Library.FontSize
                        Title.TextXAlignment = Enum.TextXAlignment.Left
                        Title.RichText = true
                        Bottom.Name = "Bottom"
                        Bottom.Position = UDim2.new(0,0,1,-22)
                        Bottom.Size = UDim2.new(1,0,0,22)
                        Bottom.BackgroundColor3 = Color3.new(1,1,1)
                        Bottom.BackgroundTransparency = 1
                        Bottom.BorderSizePixel = 0
                        Bottom.BorderColor3 = Color3.new(0,0,0)
                        Sections.Name = "Sections"
                        Sections.Position = UDim2.new(0,10,0,13)
                        Sections.Size = UDim2.new(0,160,1,-26)
                        Sections.BackgroundColor3 = Color3.fromRGB(22, 16, 32)
                        Sections.BorderColor3 = Color3.fromRGB(60, 45, 85)
                        Pages.Name = "Pages"
                        Pages.Position = UDim2.new(0,0,0,0)
                        Pages.Size = UDim2.new(1,-6,1,0)
                        Pages.BackgroundColor3 = Color3.new(1,1,1)
                        Pages.BackgroundTransparency = 1
                        Pages.BorderSizePixel = 0
                        Pages.BorderColor3 = Color3.new(0,0,0)
                        Pages.ZIndex = 52
                        Library.PageHolder = Pages
                        UIListLayout.FillDirection = Enum.FillDirection.Horizontal
                        UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
                        UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
                        UIListLayout.Padding = UDim.new(0,6)
                        version.Name = "version"
                        version.Position = UDim2.new(0,4,0,0)
                        version.Size = UDim2.new(1,-4,1,0)
                        version.BackgroundColor3 = Color3.new(1,1,1)
                        version.BackgroundTransparency = 1
                        version.BorderSizePixel = 0
                        version.BorderColor3 = Color3.new(0,0,0)
                        local uid = _G._elocate_userid or "unknown"
                        version.Text = "<font color=\"#4e4e4e\">version:</font> live    <font color=\"#4e4e4e\">|</font>    <font color=\"#4e4e4e\">user id:</font> " .. uid
                        version.RichText = true
                        version.TextColor3 = Library.Accent
                        version.FontFace = Library.UIFont
                        version.TextSize = Library.FontSize
                        version.TextXAlignment = Enum.TextXAlignment.Left
                        version.RichText = true
                        corner1.CornerRadius = UDim.new(0,0)
                        corner2.CornerRadius = UDim.new(0,0)
                        do
                                local InlineGradient = Instance.new('UIGradient', Inline)
                                InlineGradient.Rotation = 90
                                InlineGradient.Color = ColorSequence.new{
                                        ColorSequenceKeypoint.new(0, Color3.fromRGB(60,40,80)),
                                        ColorSequenceKeypoint.new(0.3, Color3.fromRGB(40,30,60)),
                                        ColorSequenceKeypoint.new(0.7, Color3.fromRGB(25,20,40)),
                                        ColorSequenceKeypoint.new(1, Color3.fromRGB(15,12,25))
                                }
                                local TopGradient = Instance.new('Frame', Top)
                                TopGradient.Name = "TopGrad"
                                TopGradient.Size = UDim2.new(1,0,1,0)
                                TopGradient.BackgroundColor3 = Color3.new(1,1,1)
                                TopGradient.BorderSizePixel = 0
                                TopGradient.ZIndex = Top.ZIndex
                                local TopUiGrad = Instance.new('UIGradient', TopGradient)
                                TopUiGrad.Rotation = 90
                                TopUiGrad.Color = ColorSequence.new{
                                        ColorSequenceKeypoint.new(0, Library.Accent),
                                        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 50, 120)),
                                        ColorSequenceKeypoint.new(1, Color3.fromRGB(11,12,15))
                                }
                                TopUiGrad.Transparency = NumberSequence.new{
                                        NumberSequenceKeypoint.new(0, 0.6),
                                        NumberSequenceKeypoint.new(1, 1)
                                }
                                Library.TopBgGrad = TopUiGrad
                                table.insert(Library.Instances, TopGradient)
                        end
                        Library:Connection(Top.MouseButton1Down, function()
                                local Location = game:GetService("UserInputService"):GetMouseLocation()
                                Base.Dragging[1] = true
                                Base.Dragging[2] =
                                        UDim2.new(0, Location.X - Main.AbsolutePosition.X, 0, Location.Y - Main.AbsolutePosition.Y)
                        end)
                        Library:Connection(Top.MouseButton1Up, function()
                                Base.Dragging[1] = false
                                Base.Dragging[2] = UDim2.new(0, 0, 0, 0)
                        end)
                        Library:Connection(game:GetService("UserInputService").InputChanged, function(Input)
                                local Location = game:GetService("UserInputService"):GetMouseLocation()
                                local ActualLocation = nil
                                if Base.Dragging[1] then
                                        Main.Position = UDim2.new(
                                                0,
                                                Location.X - Base.Dragging[2].X.Offset + (Main.Size.X.Offset * Main.AnchorPoint.X),
                                                0,
                                                Location.Y - Base.Dragging[2].Y.Offset + (Main.Size.Y.Offset * Main.AnchorPoint.Y)
                                        )
                                end
                        end)
                        Base.Elements = {Main = Main, Title = Title, Middle = Middle, PageHolder = Pages, SectionHolder = Sections};
                        return setmetatable(Base, Library);
                end
                function Library:Page(Options)
                        local Page = {
                                Window = self;
                                Open = false;
                                Sections = {};
                                Elements = {};
                                Title = Options.Name or Options.Name or Options.Name or "legit"
                        };
                        local Holder = Instance.new('TextButton', Page.Window.Elements.PageHolder)
                        local Button = Instance.new('Frame', Holder)
                        local TopLine = Instance.new('Frame', Button)
                        local Line = Instance.new('Frame', Button)
                        local Left = Instance.new('Frame', Button)
                        local RIght = Instance.new('Frame', Button)
                        local Black = Instance.new('Frame', Button)
                        local Black2 = Instance.new('Frame', Button)
                        local Title = Instance.new('TextLabel', Holder)
                        local PageSections = Instance.new('Frame', Page.Window.Elements.SectionHolder)
                        local UIListLayout = Instance.new('UIListLayout', PageSections)
                        local SectionHolder = Instance.new('Frame', Page.Window.Elements.Middle)
                        do
                                table.insert(Library.Instances, Button)
                                table.insert(Library.Instances, TopLine)
                                table.insert(Library.Instances, Line)
                                table.insert(Library.Instances, Title)
                                table.insert(Library.Instances, Left)
                                table.insert(Library.Instances, RIght)
                                table.insert(Library.Instances, Black)
                                table.insert(Library.Instances, Black2)
                                table.insert(Library.ThemeObjects, TopLine)
                                table.insert(Library.ThemeObjects, Left)
                                table.insert(Library.ThemeObjects, RIght)
                        end
                        Holder.Name = "Page"
                        Holder.Size = UDim2.new(0,70,1,0)
                        Holder.BackgroundColor3 = Color3.new(1,1,1)
                        Holder.BackgroundTransparency = 1
                        Holder.BorderSizePixel = 0
                        Holder.BorderColor3 = Color3.new(0,0,0)
                        Holder.Text = ""
                        Holder.TextColor3 = Color3.new(0,0,0)
                        Holder.AutoButtonColor = false
                        Holder.Font = Enum.Font.SourceSans
                        Holder.TextSize = 14
                        Holder.ZIndex = 53
                        Button.Name = "Button"
                        Button.Position = UDim2.new(0,0,0,3)
                        Button.Size = UDim2.new(1,0,1,-2)
                        Button.BackgroundColor3 = Color3.fromRGB(35, 26, 50)
                        Button.BorderColor3 = Color3.fromRGB(80, 60, 110)
                        Button.ZIndex = 53
                        Button.Visible = false
                        TopLine.Name = "TopLine"
                        TopLine.Position = UDim2.new(0,3,0,0)
                        TopLine.Size = UDim2.new(1,-5,0,1)
                        TopLine.BackgroundColor3 = Library.Accent
                        TopLine.BorderSizePixel = 0
                        TopLine.BorderColor3 = Color3.new(0,0,0)
                        TopLine.ZIndex = 53
                        Line.Name = "Line"
                        Line.Position = UDim2.new(0,0,1,0)
                        Line.Size = UDim2.new(1,0,0,1)
                        Line.BackgroundColor3 = Color3.new(0.0431,0.0431,0.0431)
                        Line.BorderSizePixel = 0
                        Line.BorderColor3 = Color3.new(0,0,0)
                        Line.ZIndex = 53
                        Left.Name = "Left"
                        Left.Position = UDim2.new(0,-1,0,2)
                        Left.Size = UDim2.new(0,5,0,1)
                        Left.BackgroundColor3 = Library.Accent
                        Left.BorderSizePixel = 0
                        Left.BorderColor3 = Color3.new(0,0,0)
                        Left.Rotation = -45
                        Left.ZIndex = 53
                        RIght.Name = "RIght"
                        RIght.Position = UDim2.new(1,-4,0,2)
                        RIght.Size = UDim2.new(0,5,0,1)
                        RIght.BackgroundColor3 = Library.Accent
                        RIght.BorderSizePixel = 0
                        RIght.BorderColor3 = Color3.new(0,0,0)
                        RIght.Rotation = 45
                        RIght.ZIndex = 53
                        Black.Name = "Black"
                        Black.Position = UDim2.new(0,-5,0,-2)
                        Black.Size = UDim2.new(0,7,0,6)
                        Black.BackgroundColor3 = Color3.new(0.0314,0.0314,0.0314)
                        Black.BorderSizePixel = 0
                        Black.BorderColor3 = Color3.new(0,0,0)
                        Black.Rotation = -45
                        Black.ZIndex = 55
                        Black2.Name = "Black2"
                        Black2.Position = UDim2.new(1,-2,0,-2)
                        Black2.Size = UDim2.new(0,7,0,6)
                        Black2.BackgroundColor3 = Color3.new(0.0314,0.0314,0.0314)
                        Black2.BorderSizePixel = 0
                        Black2.BorderColor3 = Color3.new(0,0,0)
                        Black2.Rotation = 45
                        Black2.ZIndex = 55
                        
                        Black.Visible = false
                        Black2.Visible = false
                        Left.Visible = false
                        RIght.Visible = false
                        Title.Name = "Title"
                        Title.Position = UDim2.new(0,0,0,2)
                        Title.Size = UDim2.new(1,0,1,-2)
                        Title.BackgroundColor3 = Color3.new(1,1,1)
                        Title.BackgroundTransparency = 1
                        Title.BorderSizePixel = 0
                        Title.BorderColor3 = Color3.new(0,0,0)
                        Title.Text = Page.Title
                        Title.TextColor3 = Color3.fromRGB(78, 78, 78)
                        Title.FontFace = Library.UIFont
                        Title.TextSize = Library.FontSize
                        Title.ZIndex = 53
                        Title.RichText = true
                        PageSections.Name = "PageSections"
                        PageSections.Position = UDim2.new(0,8,0,10)
                        PageSections.Size = UDim2.new(1,-16,1,-20)
                        PageSections.BackgroundColor3 = Color3.new(1,1,1)
                        PageSections.BackgroundTransparency = 1
                        PageSections.BorderSizePixel = 0
                        PageSections.BorderColor3 = Color3.new(0,0,0)
                        PageSections.Visible = false
                        UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
                        UIListLayout.Padding = UDim.new(0,3)
                        SectionHolder.Name = "SectionHolder"
                        SectionHolder.Position = UDim2.new(0,183,0,13)
                        SectionHolder.Size = UDim2.new(1,-194,1,-26)
                        SectionHolder.BackgroundColor3 = Color3.new(1,1,1)
                        SectionHolder.BackgroundTransparency = 1
                        SectionHolder.BorderSizePixel = 0
                        SectionHolder.BorderColor3 = Color3.new(0,0,0)
                        SectionHolder.ZIndex = 53
                        SectionHolder.Visible = false
                        local TabGlow = Instance.new('Frame', Holder)
                        TabGlow.Name = "TabGlow"
                        TabGlow.AnchorPoint = Vector2.new(0.5, 1)
                        TabGlow.Position = UDim2.new(0.5, 0, 1, -1)
                        TabGlow.Size = UDim2.new(1, -6, 0, 2)
                        TabGlow.BackgroundColor3 = Library.Accent
                        TabGlow.BorderSizePixel = 0
                        TabGlow.ZIndex = 56
                        TabGlow.Visible = false
                        local TabGlowGrad = Instance.new('UIGradient', TabGlow)
                        TabGlowGrad.Color = ColorSequence.new{
                            ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
                            ColorSequenceKeypoint.new(0.5, Library.Accent),
                            ColorSequenceKeypoint.new(1, Color3.new(1,1,1))
                        }
                        TabGlowGrad.Transparency = NumberSequence.new{
                            NumberSequenceKeypoint.new(0, 1),
                            NumberSequenceKeypoint.new(0.5, 0),
                            NumberSequenceKeypoint.new(1, 1)
                        }
                        local TabBg = Instance.new('Frame', Holder)
                        TabBg.Name = "TabBg"
                        TabBg.Position = UDim2.new(0, 0, 0, 2)
                        TabBg.Size = UDim2.new(1, 0, 1, -3)
                        TabBg.BorderSizePixel = 0
                        TabBg.BackgroundColor3 = Color3.new(0.043, 0.043, 0.043)
                        TabBg.ZIndex = 52
                        TabBg.Visible = false
                        local TabBgGrad = Instance.new('UIGradient', TabBg)
                        TabBgGrad.Rotation = 90
                        TabBgGrad.Color = ColorSequence.new{
                            ColorSequenceKeypoint.new(0, Library.Accent),
                            ColorSequenceKeypoint.new(1, Color3.new(0.043, 0.043, 0.043))
                        }
                        TabBgGrad.Transparency = NumberSequence.new{
                            NumberSequenceKeypoint.new(0, 0.55),
                            NumberSequenceKeypoint.new(1, 1)
                        }
                        Library.TabGlows = Library.TabGlows or {}
                        Library.TabBgGrads = Library.TabBgGrads or {}
                        table.insert(Library.TabGlows, TabGlow)
                        table.insert(Library.TabBgGrads, TabBgGrad)
                        function Page:Turn(bool)
                                Page.Open = bool
                                PageSections.Visible = Page.Open
                                Button.Visible = Page.Open
                                TabGlow.Visible = Page.Open
                                TabBg.Visible = Page.Open
                                if Page.Open then
                                        -- Only insert once
                                        if not table.find(Library.ThemeObjects, Title) then
                                                table.insert(Library.ThemeObjects, Title)
                                        end
                                        Title.TextColor3 = Library.Accent
                                        TabGlow.BackgroundColor3 = Library.Accent
                                else
                                        local idx = table.find(Library.ThemeObjects, Title)
                                        if idx then table.remove(Library.ThemeObjects, idx) end
                                        Title.TextColor3 = Color3.fromRGB(78,78,78)
                                end
                                SectionHolder.Visible = Page.Open
                        end;
                        Holder.MouseButton1Click:Connect(function()
                                if not Page.Open then
                                        -- Close all other pages FIRST to prevent double-open state
                                        for index, other_page in pairs(Page.Window.Pages) do
                                                if other_page.Open and other_page ~= Page then
                                                        other_page:Turn(false)
                                                end
                                        end
                                        Page:Turn(true)
                                end
                        end)
                        if #Page.Window.Pages == 0 then
                                Page:Turn(true);
                        end;
                        local function refresh()
                                wait(0.001)
                                Holder.Size = UDim2.new(0,Title.TextBounds.X + 16, 1, 0)
                        end
                        refresh()
                        Page.Elements = {ButtonHolder = PageSections, RealHold = SectionHolder}
                        Page.Window.Pages[#Page.Window.Pages + 1] = Page;
                        return setmetatable(Page, Library.Pages);
                end
                function Pages:Section(Options)
                        local Section = {
                                Window = self.Window,
                                Page = self,
                                Open = false,
                                Elements = {};
                                Title = Options.Name or Options.Name or Options.Name or "aimbot";
                                LeftName = Options.LeftTitle or Options.lefttitle or "general";
                                RightName = Options.RightTitle or Options.righttitle or "general";
                        };
                        local Button = Instance.new('TextButton', Section.Page.Elements.ButtonHolder)
                        local Accent = Instance.new('Frame', Button)
                        local Frame = Instance.new('Frame', Button)
                        local UIGradient = Instance.new('UIGradient', Frame)
                        local Title = Instance.new('TextLabel', Frame)
                        local NewSection = Instance.new('Frame', Section.Page.Elements.RealHold)
                        local Left = Instance.new('Frame', NewSection)
                        local Bar = Instance.new('Frame', Left)
                        local Gradient = Instance.new('UIGradient', Bar)
                        local GradientLine = Instance.new('Frame', Bar)
                        local UIGradient3 = Instance.new('UIGradient', GradientLine)
                        local LeftTitle = Instance.new('TextLabel', Bar)
                        local Right = Instance.new('Frame', NewSection)
                        local Bar2 = Instance.new('Frame', Right)
                        local Gradient2 = Instance.new('UIGradient', Bar2)
                        local GradientLine2 = Instance.new('Frame', Bar2)
                        local UIGradient2 = Instance.new('UIGradient', GradientLine2)
                        local RightTitle = Instance.new('TextLabel', Bar2)
                        local LeftContent = Instance.new('Frame', Left)
                        local LeftUIListLayout = Instance.new('UIListLayout', LeftContent)
                        local RightConnect = Instance.new('Frame', Right)
                        local RightUIListLayout = Instance.new('UIListLayout', RightConnect)
                        do
                                table.insert(Library.Instances, Accent)
                                table.insert(Library.Instances, Frame)
                                table.insert(Library.Instances, Title)
                                table.insert(Library.Instances, Left)
                                table.insert(Library.Instances, Bar)
                                table.insert(Library.Instances, GradientLine)
                                table.insert(Library.Instances, LeftTitle)
                                table.insert(Library.Instances, Right)
                                table.insert(Library.Instances, Bar2)
                                table.insert(Library.Instances, GradientLine2)
                                table.insert(Library.Instances, RightTitle)
                                table.insert(Library.ThemeObjects, Accent)
                        end
                        Button.Name = "Button"
                        Button.Size = UDim2.new(1,0,0,22)
                        Button.BackgroundColor3 = Color3.new(1,1,1)
                        Button.BackgroundTransparency = 1
                        Button.BorderSizePixel = 0
                        Button.ZIndex = 54
                        Button.AutoButtonColor = false
                        Button.Text = ""
                        Accent.Name = "Accent"
                        Accent.Size = UDim2.new(0,1,1,0)
                        Accent.BackgroundColor3 = Library.Accent
                        Accent.BorderSizePixel = 0
                        Accent.ZIndex = 54
                        Accent.BackgroundTransparency = 0.5
                        Frame.Position = UDim2.new(0,1,0,0)
                        Frame.Size = UDim2.new(1,-2,1,0)
                        Frame.BackgroundColor3 = Color3.new(0.149,0.149,0.149)
                        Frame.BorderSizePixel = 0
                        Frame.ZIndex = 54
                        UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.new(0.7411764860153198, 0.7411764860153198, 0.7411764860153198) ),ColorSequenceKeypoint.new(1,Color3.new(0.20392157137393951, 0.20392157137393951, 0.20392157137393951) )}
                        UIGradient.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0,0.5,0),NumberSequenceKeypoint.new(1,0.5,0)}
                        UIGradient.Enabled = true
                        Title.Name = "Title"
                        Title.Position = UDim2.new(0,4,0,0)
                        Title.Size = UDim2.new(1,-4,0,20)
                        Title.BackgroundColor3 = Color3.new(0.298,0.6353,0.9882)
                        Title.BackgroundTransparency = 1
                        Title.Text = Options.Name
                        Title.TextColor3 = Color3.fromRGB(78,78,78)
                        Title.FontFace = Library.UIFont
                        Title.TextSize = Library.FontSize
                        Title.ZIndex = 54
                        Title.TextXAlignment = Enum.TextXAlignment.Left
                        NewSection.Name = "NewSection"
                        NewSection.Size = UDim2.new(1,0,1,0)
                        NewSection.BackgroundColor3 = Color3.new(1,1,1)
                        NewSection.BackgroundTransparency = 1
                        NewSection.BorderSizePixel = 0
                        NewSection.BorderColor3 = Color3.new(0,0,0)
                        NewSection.Visible = false
                        Left.Name = "Left"
                        Left.Position = UDim2.new(0,2,0,0)
                        Left.Size = UDim2.new(0.5,-10,1,0)
                        Left.BackgroundColor3 = Color3.new(0.0314,0.0314,0.0314)
                        Left.BorderColor3 = Color3.new(0.1098,0.1098,0.1098)
                        Bar.Name = "Bar"
                        Bar.Size = UDim2.new(1,0,0,20)
                        Bar.BackgroundColor3 = Color3.new(0.0431,0.0431,0.0431)
                        Bar.BorderColor3 = Color3.new(0.1098,0.1098,0.1098)
                        Gradient.Name = "Gradient"
                        Gradient.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(
                                        0,
                                        Color3.new(0.7803921699523926, 0.7490196228027344, 0.800000011920929)
                                ),
                                ColorSequenceKeypoint.new(
                                        1,
                                        Color3.new(1, 1, 1)
                                )
                        }
                        Gradient.Rotation = -90
                        GradientLine.Name = "GradientLine"
                        GradientLine.Position = UDim2.new(0,0,1,0)
                        GradientLine.Size = UDim2.new(1,0,0,1)
                        GradientLine.BackgroundColor3 = Color3.new(1,1,1)
                        GradientLine.BorderSizePixel = 0
                        GradientLine.BorderColor3 = Color3.new(0,0,0)
                        UIGradient3.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(
                                        0,
                                        Color3.new(0.10980392247438431, 0.10980392247438431, 0.10980392247438431)
                                ),
                                ColorSequenceKeypoint.new(
                                        0.4826989769935608,
                                        Color3.new(0.04313725605607033, 0.04313725605607033, 0.04313725605607033)
                                ),
                                ColorSequenceKeypoint.new(
                                        1,
                                        Color3.new(0.10980392247438431, 0.10980392247438431, 0.10980392247438431)
                                )
                        }
                        LeftTitle.Name = "LeftTitle"
                        LeftTitle.Position = UDim2.new(0,4,0,0)
                        LeftTitle.Size = UDim2.new(1,-4,1,0)
                        LeftTitle.BackgroundColor3 = Color3.new(1,1,1)
                        LeftTitle.BackgroundTransparency = 1
                        LeftTitle.BorderSizePixel = 0
                        LeftTitle.BorderColor3 = Color3.new(0,0,0)
                        LeftTitle.Text = Section.LeftName
                        LeftTitle.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        LeftTitle.FontFace = Library.UIFont
                        LeftTitle.TextSize = Library.FontSize
                        LeftTitle.TextXAlignment = Enum.TextXAlignment.Left
                        Right.Name = "Right"
                        Right.Position = UDim2.new(0.5,8,0,0)
                        Right.Size = UDim2.new(0.5,-10,1,0)
                        Right.BackgroundColor3 = Color3.new(0.0314,0.0314,0.0314)
                        Right.BorderColor3 = Color3.new(0.1098,0.1098,0.1098)
                        Bar2.Name = "Bar2"
                        Bar2.Size = UDim2.new(1,0,0,20)
                        Bar2.BackgroundColor3 = Color3.new(0.0431,0.0431,0.0431)
                        Bar2.BorderColor3 = Color3.new(0.1098,0.1098,0.1098)
                        Gradient2.Name = "Gradient2"
                        Gradient2.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(
                                        0,
                                        Color3.new(0.7803921699523926, 0.7490196228027344, 0.800000011920929)
                                ),
                                ColorSequenceKeypoint.new(
                                        1,
                                        Color3.new(1, 1, 1)
                                )
                        }
                        Gradient2.Rotation = -90
                        GradientLine2.Name = "GradientLine2"
                        GradientLine2.Position = UDim2.new(0,0,1,0)
                        GradientLine2.Size = UDim2.new(1,0,0,1)
                        GradientLine2.BackgroundColor3 = Color3.new(1,1,1)
                        GradientLine2.BorderSizePixel = 0
                        GradientLine2.BorderColor3 = Color3.new(0,0,0)
                        UIGradient2.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(
                                        0,
                                        Color3.new(0.10980392247438431, 0.10980392247438431, 0.10980392247438431)
                                ),
                                ColorSequenceKeypoint.new(
                                        0.4826989769935608,
                                        Color3.new(0.04313725605607033, 0.04313725605607033, 0.04313725605607033)
                                ),
                                ColorSequenceKeypoint.new(
                                        1,
                                        Color3.new(0.10980392247438431, 0.10980392247438431, 0.10980392247438431)
                                )
                        }
                        RightTitle.Name = "RightTitle"
                        RightTitle.Position = UDim2.new(0,4,0,0)
                        RightTitle.Size = UDim2.new(1,-4,1,0)
                        RightTitle.BackgroundColor3 = Color3.new(1,1,1)
                        RightTitle.BackgroundTransparency = 1
                        RightTitle.BorderSizePixel = 0
                        RightTitle.BorderColor3 = Color3.new(0,0,0)
                        RightTitle.Text = Section.RightName
                        RightTitle.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        RightTitle.FontFace = Library.UIFont
                        RightTitle.TextSize = Library.FontSize
                        RightTitle.TextXAlignment = Enum.TextXAlignment.Left
                        LeftContent.Name = "LeftContent"
                        LeftContent.Position = UDim2.new(0,10,0,30)
                        LeftContent.Size = UDim2.new(1,-20,1,-40)
                        LeftContent.BackgroundColor3 = Color3.new(1,1,1)
                        LeftContent.BackgroundTransparency = 1
                        LeftContent.BorderSizePixel = 0
                        LeftContent.BorderColor3 = Color3.new(0,0,0)
                        LeftUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
                        LeftUIListLayout.Padding = UDim.new(0,4)
                        RightConnect.Name = "RightConnect"
                        RightConnect.Position = UDim2.new(0,10,0,30)
                        RightConnect.Size = UDim2.new(1,-20,1,-40)
                        RightConnect.BackgroundColor3 = Color3.new(1,1,1)
                        RightConnect.BackgroundTransparency = 1
                        RightConnect.BorderSizePixel = 0
                        RightConnect.BorderColor3 = Color3.new(0,0,0)
                        RightUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
                        RightUIListLayout.Padding = UDim.new(0,4)
                        function Section:Turn(bool)
                                Section.Open = bool
                                NewSection.Visible = Section.Open
                                if Section.Open then
                                        table.insert(Library.ThemeObjects, Title)
                                        Title.TextColor3 = Library.Accent
                                else
                                        table.remove(Library.ThemeObjects, table.find(Library.ThemeObjects, Title))
                                        Title.TextColor3 = Color3.fromRGB(78,78,78)
                                end
                                Accent.BackgroundTransparency = Section.Open and 0 or 0.5
                        end;
                        Button.MouseButton1Click:Connect(function()
                                if not Section.Open then
                                        Section:Turn(true)
                                        for index, other_page in pairs(Section.Page.Sections) do
                                                if other_page.Open and other_page ~= Section then
                                                        other_page:Turn(false)
                                                end
                                        end
                                end
                        end)
                        if #Section.Page.Sections == 0 then
                                Section:Turn(true);
                        end;
                        Section.Elements = {Left = LeftContent, Right = RightConnect};
                        Section.Page.Sections[#Section.Page.Sections + 1] = Section;
                        return setmetatable(Section, Library.Sections)
                end
                function Sections:Toggle(Options)
                        local Properties = Options or {}
                        local Toggle = {
                                Window = self.Window,
                                Page = self.Page,
                                Section = self,
                                State = (Properties.state or Properties.State or Properties.def or Properties.Def or Properties.default or Properties.Default or false),
                                Callback = (Properties.callback or Properties.Callback or Properties.callBack or Properties.CallBack or function() end),
                                Flag = (Properties.flag or Properties.Flag or Properties.pointer or Properties.Pointer or Library.NextFlag()),
                                Toggled = false;
                                Colorpickers = 0;
                        };
                        local Holder = Instance.new('TextButton', Options.Side == "Left" and Toggle.Section.Elements.Left or Options.Side == "Right" and Toggle.Section.Elements.Right or Toggle.Section.Elements.Left)
                        local Frame = Instance.new('Frame', Holder)
                        local Accent = Instance.new('Frame', Frame)
                        local Gradient = Instance.new('UIGradient', Accent)
                        local TextLabel = Instance.new('TextLabel', Holder)
                        do
                                table.insert(Library.Instances, Frame)
                                table.insert(Library.Instances, Accent)
                                table.insert(Library.Instances, TextLabel)
                                table.insert(Library.ThemeObjects, Accent)
                        end
                        Holder.Name = "Toggle"
                        Holder.Size = UDim2.new(1,0,0,10)
                        Holder.BackgroundColor3 = Color3.new(1,1,1)
                        Holder.BackgroundTransparency = 1
                        Holder.Text = ""
                        Holder.TextColor3 = Color3.new(0,0,0)
                        Holder.AutoButtonColor = false
                        Holder.Font = Enum.Font.SourceSans
                        Holder.TextSize = 14
                        Frame.Position = UDim2.new(0,0,0,3)
                        Frame.Size = UDim2.new(0,6,0,6)
                        Frame.BackgroundColor3 = Color3.new(0.0784,0.0784,0.0784)
                        Frame.BorderColor3 = Color3.new(0,0,0)
                        Accent.Name = "Accent"
                        Accent.Size = UDim2.new(1,0,1,0)
                        Accent.BackgroundColor3 = Library.Accent
                        Accent.BorderSizePixel = 0
                        Accent.Visible = false
                        Gradient.Name = "Gradient"
                        Gradient.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(
                                        0,
                                        Color3.new(0.7803921699523926, 0.7490196228027344, 0.800000011920929)
                                ),
                                ColorSequenceKeypoint.new(
                                        1,
                                        Color3.new(1, 1, 1)
                                )
                        }
                        Gradient.Rotation = -90
                        TextLabel.Position = UDim2.new(0,15,0,0)
                        TextLabel.Size = UDim2.new(1,0,1,0)
                        TextLabel.BackgroundColor3 = Color3.new(1,1,1)
                        TextLabel.BackgroundTransparency = 1
                        TextLabel.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        TextLabel.FontFace = Library.UIFont
                        TextLabel.TextSize = Library.FontSize
                        TextLabel.ZIndex = 105
                        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
                        TextLabel.Text = Options.Name or Options.Name or "toggle"
                        local function SetState()
                                Toggle.Toggled = not Toggle.Toggled
                                if Toggle.Toggled then
                                        Accent.Visible = true
                                        TextLabel.TextColor3 = Color3.fromRGB(255,255,255)
                                else
                                        Accent.Visible = false
                                        TextLabel.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                                end
                                Library.Flags[Toggle.Flag] = Toggle.Toggled
                                Toggle.Callback(Toggle.Toggled)
                        end
                        function Toggle:Keybind(Options)
                                local Properties = Options or {};
                                local Keybind = {
                                        State = (
                                                Properties.state
                                                        or Properties.State
                                                        or Properties.def
                                                        or Properties.Def
                                                        or Properties.default
                                                        or Properties.Default
                                                        or nil
                                        ),
                                        Mode = (Properties.mode or Properties.Mode or "Toggle"),
                                        Callback = (
                                                Properties.callback
                                                        or Properties.Callback
                                                        or Properties.callBack
                                                        or Properties.CallBack
                                                        or function() end
                                        ),
                                        Flag = (
                                                Properties.flag
                                                        or Properties.Flag
                                                        or Properties.pointer
                                                        or Properties.Pointer
                                                        or Library.NextFlag()
                                        ),
                                        Binding = nil,
                                        Connection = nil,
                                }
                                local Key
                                local State = false
                                local modeValue
                                local _ddItems = {}
                                local _popupConn = nil
                                local _refreshValueText
                                local KeyHolder = Instance.new('TextButton', Holder)
                                local Value = Instance.new('TextLabel', Holder)
                                do
                                        table.insert(Library.Instances, Value)
                                end
                                KeyHolder.Name = "Holder"
                                KeyHolder.Size = UDim2.new(0,40,0,10)
                                KeyHolder.BackgroundColor3 = Color3.new(1,1,1)
                                KeyHolder.BackgroundTransparency = 1
                                KeyHolder.Text = ""
                                KeyHolder.TextColor3 = Color3.new(0,0,0)
                                KeyHolder.AutoButtonColor = false
                                KeyHolder.Font = Enum.Font.SourceSans
                                KeyHolder.TextSize = 14
                                KeyHolder.Position = UDim2.new(1,-45,0,0)
                                Value.Name = "Value"
                                Value.Position = UDim2.new(0,15,0,0)
                                Value.Size = UDim2.new(1,-30,1,0)
                                Value.BackgroundColor3 = Color3.new(1,1,1)
                                Value.BackgroundTransparency = 1
                                Value.Text = "[-]"
                                Value.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                                Value.FontFace = Library.UIFont
                                Value.TextSize = Library.FontSize
                                Value.ZIndex = 105
                                Value.TextXAlignment = Enum.TextXAlignment.Right
                                local function set(newkey)
                                        if string.find(tostring(newkey), "Enum") then
                                                if Keybind.Connection then
                                                        Keybind.Connection:Disconnect()
                                                        if Keybind.Flag then
                                                                Library.Flags[Keybind.Flag] = false
                                                        end
                                                        Keybind.Callback(false)
                                                end
                                                if tostring(newkey):find("Enum.KeyCode.") then
                                                        newkey = Enum.KeyCode[tostring(newkey):gsub("Enum.KeyCode.", "")]
                                                elseif tostring(newkey):find("Enum.UserInputType.") then
                                                        newkey = Enum.UserInputType[tostring(newkey):gsub("Enum.UserInputType.", "")]
                                                end
                                                if newkey == Enum.KeyCode.Backspace then
                                                        Key = nil
                                                        Value.Text = "[-]"
                                                elseif newkey ~= nil then
                                                        Key = newkey
                                                        local text = (Library.Keys[newkey] or tostring(newkey):gsub("Enum.KeyCode.", ""))
                                                        Value.Text = "[" .. text .. "]"
                                                end
                                                if _refreshValueText then _refreshValueText() end
                                                Library.Flags[Keybind.Flag .. "_KEY"] = newkey
                                        elseif table.find({ "Always", "Toggle", "Hold" }, newkey) then
                                                Library.Flags[Keybind.Flag .. "_KEY STATE"] = newkey
                                                Keybind.Mode = newkey
                                                -- Reflect mode change on the dropdown UI if it already exists.
                                                if modeValue then
                                                        modeValue.Text = newkey
                                                end
                                                if _ddItems then
                                                        for _, item in ipairs(_ddItems) do
                                                                if item and item.text then
                                                                        item.text.TextColor3 = (item.name == newkey)
                                                                                and Library.Accent
                                                                                or Color3.new(0.3059,0.3059,0.3059)
                                                                end
                                                        end
                                                end
                                                if Keybind.Mode == "Always" then
                                                        if Toggle.Toggled then
                                                                State = true
                                                                if Keybind.Flag then
                                                                        Library.Flags[Keybind.Flag] = State
                                                                end
                                                                Keybind.Callback(true)
                                                        end
                                                end
                                        else
                                                State = newkey
                                                if Keybind.Flag then
                                                        Library.Flags[Keybind.Flag] = newkey
                                                end
                                                Keybind.Callback(newkey)
                                        end
                                end
                                set(Keybind.State)
                                set(Keybind.Mode)
                                KeyHolder.MouseButton1Click:Connect(function()
                                        if not Keybind.Binding then
                                                Value.Text = "[-]"
                                                if _refreshValueText then _refreshValueText() end
                                                Keybind.Binding = Library:Connection(
                                                        game:GetService("UserInputService").InputBegan,
                                                        function(input, gpe)
                                                                set(
                                                                        input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode
                                                                                or input.UserInputType
                                                                )
                                                                Library:Disconnect(Keybind.Binding)
                                                                task.wait()
                                                Keybind.Binding = nil
                                                        end
                                                )
                                        end
                                end)
                                Library:Connection(game:GetService("UserInputService").InputBegan, function(inp, gpe)
                                        if gpe then return end
                                        if Key == nil then return end
                                        if not Toggle.Toggled then return end
                                        if (inp.KeyCode == Key or inp.UserInputType == Key) and not Keybind.Binding then
                                                if Keybind.Mode == "Hold" then
                                                        State = true
                                                        if Keybind.Flag then
                                                                Library.Flags[Keybind.Flag] = true
                                                        end
                                                        Keybind.Callback(true)
                                                elseif Keybind.Mode == "Toggle" then
                                                        State = not State
                                                        if Keybind.Flag then
                                                                Library.Flags[Keybind.Flag] = State
                                                        end
                                                        Keybind.Callback(State)
                                                elseif Keybind.Mode == "Always" then
                                                        State = true
                                                        if Keybind.Flag then
                                                                Library.Flags[Keybind.Flag] = true
                                                        end
                                                        Keybind.Callback(true)
                                                end
                                        end
                                end)
                                
                                -- Handle "Always" mode via SetState updates instead of broken GPCS
                                local function updateAlwaysMode()
                                        if Keybind.Mode == "Always" then
                                                State = Toggle.Toggled
                                                if Keybind.Flag then
                                                        Library.Flags[Keybind.Flag] = State
                                                end
                                                Keybind.Callback(State)
                                        end
                                end
                                -- Wiring into the toggle's logic
                                local oldSetState = SetState
                                SetState = function()
                                        oldSetState()
                                        updateAlwaysMode()
                                end
                                Library:Connection(game:GetService("UserInputService").InputEnded, function(inp, gpe)
                                        if gpe then return end
                                        if Key == nil then return end
                                        if Keybind.Mode == "Hold" then
                                                if (inp.KeyCode == Key or inp.UserInputType == Key) then
                                                        State = false
                                                        if Keybind.Flag then
                                                                Library.Flags[Keybind.Flag] = false
                                                        end
                                                        Keybind.Callback(false)
                                                end
                                        end
                                end)
                                
                                local _modeHint = { Toggle = "T", Hold = "H", Always = "A" }
                                _refreshValueText = function()
                                        local txt = Value.Text or ""
                                        txt = txt:gsub("%·[HTA]%]$", "]")
                                        if txt:sub(-1) == "]" and #txt >= 2 then
                                                local hint = _modeHint[Keybind.Mode] or ""
                                                if hint ~= "" then
                                                        Value.Text = txt:sub(1, -2) .. "·" .. hint .. "]"
                                                else
                                                        Value.Text = txt
                                                end
                                        end
                                end
                                local _modeOrder = { "Toggle", "Hold", "Always" }
                                local function _cycleMode()
                                        local idx = 1
                                        for i, m in ipairs(_modeOrder) do
                                                if m == Keybind.Mode then idx = i; break end
                                        end
                                        local nm = _modeOrder[(idx % #_modeOrder) + 1]
                                        Keybind.Mode = nm
                                        Library.Flags[Keybind.Flag .. "_KEY STATE"] = nm
                                        if _refreshValueText then _refreshValueText() end
                                        if nm == "Always" then
                                                if Toggle.Toggled then
                                                        State = true
                                                        if Keybind.Flag then
                                                                Library.Flags[Keybind.Flag] = true
                                                        end
                                                        if Keybind.Callback then Keybind.Callback(true) end
                                                end
                                        end
                                end
                                if _refreshValueText then _refreshValueText() end

                                Library.Flags[Keybind.Flag .. "_KEY"] = Keybind.State
                                Library.Flags[Keybind.Flag .. "_KEY STATE"] = Keybind.Mode
                                Flags[Keybind.Flag] = set
                                Flags[Keybind.Flag .. "_KEY"] = set
                                Flags[Keybind.Flag .. "_KEY STATE"] = set
                                function Keybind:Set(key)
                                        set(key)
                                end
                                return Keybind
                        end
                        function Toggle:Colorpicker(Properties)
                                local Properties = Properties or {}
                                local Colorpicker = {
                                        State = (
                                                Properties.state
                                                        or Properties.State
                                                        or Properties.def
                                                        or Properties.Def
                                                        or Properties.default
                                                        or Properties.Default
                                                        or Color3.fromRGB(255, 0, 0)
                                        ),
                                        Alpha = (
                                                Properties.alpha
                                                        or Properties.Alpha
                                                        or Properties.transparency
                                                        or Properties.Transparency
                                                        or 1
                                        ),
                                        Callback = (
                                                Properties.callback
                                                        or Properties.Callback
                                                        or Properties.callBack
                                                        or Properties.CallBack
                                                        or function() end
                                        ),
                                        Flag = (
                                                Properties.flag
                                                        or Properties.Flag
                                                        or Properties.pointer
                                                        or Properties.Pointer
                                                        or Library.NextFlag()
                                        ),
                                }
                                Toggle.Colorpickers = Toggle.Colorpickers + 1
                                local colorpickertypes = Library:NewPicker(
                                        Colorpicker.State,
                                        Colorpicker.Alpha,
                                        Holder,
                                        Toggle.Colorpickers - 1,
                                        Colorpicker.Flag,
                                        Colorpicker.Callback
                                )
                                function Colorpicker:Set(color)
                                        colorpickertypes:Set(color, false, true)
                                end
                                return Colorpicker
                        end
                        function Toggle.Set(bool)
                                bool = type(bool) == "boolean" and bool or false
                                if Toggle.Toggled ~= bool then
                                        SetState()
                                end
                        end
                        Toggle.Set(Toggle.State)
                        Library.Flags[Toggle.Flag] = Toggle.State
                        Flags[Toggle.Flag] = Toggle.Set
                        Library:Connection(Holder.MouseButton1Click, SetState)
                        return Toggle
                end
                function Sections:Slider(Options)
                        local Properties = Options or {};
                        local Slider = {
                                Window = self.Window,
                                Page = self.Page,
                                Section = self,
                                Name = Properties.Title or Properties.Name or Properties.title or nil,
                                Min = (Properties.min or Properties.Min or Properties.minimum or Properties.Minimum or 0),
                                State = (
                                        Properties.state
                                                or Properties.State
                                                or Properties.def
                                                or Properties.Def
                                                or Properties.default
                                                or Properties.Default
                                                or 10
                                ),
                                Max = (Properties.max or Properties.Max or Properties.maximum or Properties.Maximum or 100),
                                Sub = (
                                        Properties.suffix
                                                or Properties.Suffix
                                                or Properties.ending
                                                or Properties.Ending
                                                or Properties.prefix
                                                or Properties.Prefix
                                                or Properties.measurement
                                                or Properties.Measurement
                                                or ""
                                ),
                                Decimals = (Properties.decimals or Properties.Decimals or 1),
                                Callback = (
                                        Properties.callback
                                                or Properties.Callback
                                                or Properties.callBack
                                                or Properties.CallBack
                                                or function() end
                                ),
                                Flag = (
                                        Properties.flag
                                                or Properties.Flag
                                                or Properties.pointer
                                                or Properties.Pointer
                                                or Library.NextFlag()
                                ),
                        }
                        local TextValue = ("[value]" .. Slider.Sub)
                        local Holder = Instance.new('Frame', Options.Side == "Left" and Slider.Section.Elements.Left or Options.Side == "Right" and Slider.Section.Elements.Right or Slider.Section.Elements.Left)
                        local Frame = Instance.new('TextButton', Holder)
                        local Accent = Instance.new('TextButton', Frame)
                        local Gradient2 = Instance.new('UIGradient', Accent)
                        local Gradient = Instance.new('UIGradient', Frame)
                        local Title = Instance.new('TextLabel', Holder)
                        local plus = Instance.new('TextButton', Holder)
                        local minus = Instance.new('TextButton', Holder)
                        local Value = Instance.new('TextLabel', Slider.Name and Holder or Frame)
                        Title.Visible = false
                        do
                                table.insert(Library.Instances, Frame)
                                table.insert(Library.Instances, Accent)
                                table.insert(Library.Instances, Title)
                                table.insert(Library.Instances, plus)
                                table.insert(Library.Instances, minus)
                                table.insert(Library.Instances, Value)
                                table.insert(Library.ThemeObjects, Accent)
                        end
                        Holder.Name = "Slider"
                        Holder.Size = Slider.Name and UDim2.new(1,0,0,25) or UDim2.new(1,0,0,10)
                        Holder.BackgroundColor3 = Color3.new(1,1,1)
                        Holder.BackgroundTransparency = 1
                        Frame.Position = Slider.Name and UDim2.new(0,15,0,16) or UDim2.new(0,15,0,3)
                        Frame.Size = UDim2.new(1,-30,0,6)
                        Frame.BackgroundColor3 = Color3.new(0.0784,0.0784,0.0784)
                        Frame.BorderColor3 = Color3.new(0,0,0)
                        Frame.AutoButtonColor = false
                        Frame.Text = ""
                        Accent.Name = "Accent"
                        Accent.Size = UDim2.new(0,0,1,0)
                        Accent.BackgroundColor3 = Library.Accent
                        Accent.BorderSizePixel = 0
                        Accent.AutoButtonColor = false
                        Accent.Text = ""
                        Gradient2.Name = "Gradient2"
                        Gradient2.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(
                                        0,
                                        Color3.new(0.7803921699523926, 0.7490196228027344, 0.800000011920929)
                                ),
                                ColorSequenceKeypoint.new(
                                        1,
                                        Color3.new(1, 1, 1)
                                )
                        }
                        Gradient2.Rotation = -90
                        Gradient.Name = "Gradient"
                        Gradient.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(
                                        0,
                                        Color3.new(0.7803921699523926, 0.7490196228027344, 0.800000011920929)
                                ),
                                ColorSequenceKeypoint.new(
                                        1,
                                        Color3.new(1, 1, 1)
                                )
                        }
                        Gradient.Rotation = -90
                        if Slider.Name then
                                Title.Visible = true
                                Title.Name = "Title"
                                Title.Position = UDim2.new(0,15,0,0)
                                Title.Size = UDim2.new(1,0,0,10)
                                Title.BackgroundColor3 = Color3.new(1,1,1)
                                Title.BackgroundTransparency = 1
                                Title.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                                Title.FontFace = Library.UIFont
                                Title.TextSize = Library.FontSize
                                Title.ZIndex = 105
                                Title.TextXAlignment = Enum.TextXAlignment.Left
                                Title.Text = Slider.Name
                        end
                        plus.Name = "plus"
                        plus.Position = Slider.Name and UDim2.new(1,-7,0,13) or UDim2.new(1,-7,0,0)
                        plus.Size = UDim2.new(0,8,0,8)
                        plus.BackgroundColor3 = Color3.new(1,1,1)
                        plus.BackgroundTransparency = 1
                        plus.BorderSizePixel = 0
                        plus.BorderColor3 = Color3.new(0,0,0)
                        plus.Text = "+"
                        plus.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        plus.FontFace = Library.UIFont
                        plus.TextSize = Library.FontSize
                        minus.Name = "minus"
                        minus.Position = Slider.Name and UDim2.new(0,-1,0,13) or UDim2.new(0,-1,0,0)
                        minus.Size = UDim2.new(0,8,0,8)
                        minus.BackgroundColor3 = Color3.new(1,1,1)
                        minus.BackgroundTransparency = 1
                        minus.BorderSizePixel = 0
                        minus.BorderColor3 = Color3.new(0,0,0)
                        minus.Text = "-"
                        minus.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        minus.FontFace = Library.UIFont
                        minus.TextSize = Library.FontSize
                        Value.Name = "Value"
                        Value.Position = Slider.Name and UDim2.new(0,15,0,0) or UDim2.new(0,0,0,-1)
                        Value.Size = Slider.Name and UDim2.new(1,-30,0,10) or UDim2.new(1,0,1,0)
                        Value.BackgroundColor3 = Color3.new(1,1,1)
                        Value.BackgroundTransparency = 1
                        Value.Text = "50%"
                        Value.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        Value.FontFace = Library.UIFont
                        Value.TextSize = Library.FontSize
                        Value.ZIndex = 105
                        Value.TextXAlignment = Slider.Name and Enum.TextXAlignment.Right or Enum.TextXAlignment.Center
                        local Sliding = false
                        local Val = Slider.State;
                        local function Set(value)
                                value = math.clamp(Library:Round(value, Slider.Decimals), Slider.Min, Slider.Max)
                                if value == Slider.Min then
                                        Value.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                                        if Slider.Name then
                                                Title.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                                        end
                                else
                                        Value.TextColor3 = Color3.fromRGB(255,255,255)
                                        if Slider.Name then
                                                Title.TextColor3 = Color3.fromRGB(255,255,255)
                                        end
                                end
                                Value.Text = TextValue:gsub("%[value%]", string.format("%.14g", value))
                                Val = value
                                local sizeX = ((value - Slider.Min) / (Slider.Max - Slider.Min))
                                Accent.Size = UDim2.new(sizeX, 0, 1, 0)
                                Library.Flags[Slider.Flag] = value
                                Slider.Callback(value)
                        end
                        Set(Slider.State)
                        local function Slide(input)
                                local sizeX = (input.Position.X - Frame.AbsolutePosition.X) / Frame.AbsoluteSize.X
                                local value = ((Slider.Max - Slider.Min) * sizeX) + Slider.Min
                                Set(value)
                        end
                        Library:Connection(Frame.InputBegan, function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                        Sliding = true
                                        Slide(input)
                                end
                        end)
                        Library:Connection(Frame.InputEnded, function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                        Sliding = false
                                end
                        end)
                        Library:Connection(Accent.InputBegan, function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                        Sliding = true
                                        Slide(input)
                                end
                        end)
                        Library:Connection(Accent.InputEnded, function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                        Sliding = false
                                end
                        end)
                        Library:Connection(game:GetService("UserInputService").InputChanged, function(input)
                                if input.UserInputType == Enum.UserInputType.MouseMovement then
                                        if Sliding then
                                                Slide(input)
                                        end
                                end
                        end)
                        Library:Connection(plus.MouseButton1Click, function()
                                Set(Val + 1)
                        end)
                        Library:Connection(minus.MouseButton1Click, function()
                                Set(Val - 1)
                        end)
                        function Slider:Set(Value)
                                Set(Value)
                        end
                        Flags[Slider.Flag] = Set
                        return Slider
                end
                function Sections:List(Options)
                        local Properties = Options or {};
                        local Dropdown = {
                                Window = self.Window,
                                Page = self.Page,
                                Section = self,
                                Open = false,
                                Name = Properties.Title or Properties.Name or Properties.title or nil,
                                Options = (Properties.options or Properties.Options or Properties.values or Properties.Values or {
                                        "1",
                                        "2",
                                        "3",
                                }),
                                State = (
                                        Properties.state
                                                or Properties.State
                                                or Properties.def
                                                or Properties.Def
                                                or Properties.default
                                                or Properties.Default
                                                or nil
                                ),
                                Callback = (
                                        Properties.callback
                                                or Properties.Callback
                                                or Properties.callBack
                                                or Properties.CallBack
                                                or function() end
                                ),
                                Flag = (
                                        Properties.flag
                                                or Properties.Flag
                                                or Properties.pointer
                                                or Properties.Pointer
                                                or Library.NextFlag()
                                ),
                                OptionInsts = {},
                        }
                        local Holder = Instance.new('Frame', Options.Side == "Left" and Dropdown.Section.Elements.Left or Options.Side == "Right" and Dropdown.Section.Elements.Right or Dropdown.Section.Elements.Left)
                        local Frame = Instance.new('TextButton', Holder)
                        local Gradient = Instance.new('UIGradient', Frame)
                        local Value = Instance.new('TextLabel', Frame)
                        local Icon = Instance.new('TextLabel', Frame)
                        local Content = Instance.new('Frame', Frame)
                        local Gradient2 = Instance.new('UIGradient', Content)
                        local UIListLayout = Instance.new('UIListLayout', Content)
                        local Title = Instance.new('TextLabel', Holder)
                        do
                                table.insert(Library.Instances, Frame)
                                table.insert(Library.Instances, Value)
                                table.insert(Library.Instances, Icon)
                                table.insert(Library.Instances, Content)
                                table.insert(Library.Instances, Title)
                                table.insert(Dropdowns, Content)
                        end
                        Holder.Name = "Holder"
                        Holder.Size = UDim2.new(1,0,0,34)
                        Holder.BackgroundColor3 = Color3.new(1,1,1)
                        Holder.BackgroundTransparency = 1
                        Frame.Position = UDim2.new(0,15,0,16)
                        Frame.Size = UDim2.new(1,-30,0,15)
                        Frame.BackgroundColor3 = Color3.new(0.0784,0.0784,0.0784)
                        Frame.BorderColor3 = Color3.new(0,0,0)
                        Frame.Text = ""
                        Frame.AutoButtonColor = false
                        Gradient.Name = "Gradient"
                        Gradient.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(
                                        0,
                                        Color3.new(0.7803921699523926, 0.7490196228027344, 0.800000011920929)
                                ),
                                ColorSequenceKeypoint.new(
                                        1,
                                        Color3.new(1, 1, 1)
                                )
                        }
                        Gradient.Rotation = -90
                        Value.Name = "Value"
                        Value.Position = UDim2.new(0,2,0,0)
                        Value.Size = UDim2.new(1,-10,1,0)
                        Value.BackgroundColor3 = Color3.new(1,1,1)
                        Value.BackgroundTransparency = 1
                        Value.Text = ""
                        Value.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        Value.FontFace = Library.UIFont
                        Value.TextSize = Library.FontSize
                        Value.ZIndex = 105
                        Value.TextXAlignment = Enum.TextXAlignment.Left
                        Value.ClipsDescendants = true
                        Icon.Name = "Icon"
                        Icon.Position = UDim2.new(0,-4,0,0)
                        Icon.Size = UDim2.new(1,0,1,0)
                        Icon.BackgroundColor3 = Color3.new(1,1,1)
                        Icon.BackgroundTransparency = 1
                        Icon.BorderSizePixel = 0
                        Icon.Text = "-"
                        Icon.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        Icon.FontFace = Library.UIFont
                        Icon.TextSize = Library.FontSize
                        Icon.ZIndex = 105
                        Icon.TextXAlignment = Enum.TextXAlignment.Right
                        Content.Name = "Content"
                        Content.Position = UDim2.new(0,0,0,18)
                        Content.Size = UDim2.new(1,0,0,0)
                        Content.BackgroundColor3 = Color3.new(0.0784,0.0784,0.0784)
                        Content.BorderColor3 = Color3.new(0,0,0)
                        Content.Visible = false
                        Content.ZIndex = 200
                        Content.AutomaticSize = Enum.AutomaticSize.Y
                        Content.ClipsDescendants = false
                        Gradient2.Name = "Gradient2"
                        Gradient2.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(
                                        0,
                                        Color3.new(0.7803921699523926, 0.7490196228027344, 0.800000011920929)
                                ),
                                ColorSequenceKeypoint.new(
                                        1,
                                        Color3.new(1, 1, 1)
                                )
                        }
                        Gradient2.Rotation = -90
                        UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
                        Title.Name = "Title"
                        Title.Position = UDim2.new(0,15,0,0)
                        Title.Size = UDim2.new(1,0,0,10)
                        Title.BackgroundColor3 = Color3.new(1,1,1)
                        Title.BackgroundTransparency = 1
                        Title.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        Title.FontFace = Library.UIFont
                        Title.TextSize = Library.FontSize
                        Title.ZIndex = 105
                        Title.TextXAlignment = Enum.TextXAlignment.Left
                        Title.Text = Dropdown.Name
                        
                        
                        
                        
                        local _popupRoot = (Library._GetPopupGui and Library:_GetPopupGui()) or (Library.Holder and Library.Holder.Parent) or Content.Parent
                        Content.Parent = _popupRoot
                        Content.AnchorPoint = Vector2.new(0, 0)
                        Content.Position = UDim2.fromOffset(0, 0)
                        Content.Size = UDim2.new(0, 0, 0, 0)
                        Content.AutomaticSize = Enum.AutomaticSize.Y
                        Content.ClipsDescendants = false
                        pcall(function() Content.ZIndex = 5000 end)
                        local _popupConn = nil
                        local function showPopup(v) end -- forward declare
                        local function syncPopup()
                                if not Frame or not Frame.Parent then showPopup(false) return end
                                local fs = Frame.AbsoluteSize
                                -- If section is hidden (e.g., tab switch), AbsoluteSize.X becomes 0
                                if fs.X <= 0 then showPopup(false) return end
                                local fp = Frame.AbsolutePosition
                                Content.Size = UDim2.fromOffset(fs.X, 0)
                                Content.Position = UDim2.fromOffset(fp.X, fp.Y + fs.Y)
                        end
                        showPopup = function(v)
                                if v then
                                        syncPopup()
                                        -- Don't show if section is hidden
                                        if Frame.AbsoluteSize.X <= 0 then return end
                                        Content.Visible = true
                                        if not _popupConn then
                                                _popupConn = game:GetService("RunService").RenderStepped:Connect(syncPopup)
                                        end
                                else
                                        Content.Visible = false
                                        if _popupConn then
                                                _popupConn:Disconnect()
                                                _popupConn = nil
                                        end
                                end
                        end
                        Library:Connection(Frame.MouseButton1Click, function()
                                showPopup(not Content.Visible)
                        end)
                        local Chosen = nil
                        local Count = 0
                        local _optionJustClicked = false
                        local function handleoptionclick(option, button, text)
                                button.MouseButton1Click:Connect(function()
                                        _optionJustClicked = true
                                        for opt, tbl in next, Dropdown.OptionInsts do
                                                if opt ~= option then
                                                        tbl.text.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                                                end
                                        end
                                        Chosen = option
                                        Value.Text = option
                                        text.TextColor3 = Color3.fromRGB(255,255,255)
                                        Library.Flags[Dropdown.Flag] = option
                                        Dropdown.Callback(option)
                                        
                                        showPopup(false)
                                        task.delay(0.05, function() _optionJustClicked = false end)
                                end)
                        end
                        local function createoptions(tbl)
                                for _, option in next, tbl do
                                        Dropdown.OptionInsts[option] = {}
                                        local Option = Instance.new('TextButton', Content)
                                        local OptionName = Instance.new('TextLabel', Option)
                                        Option.Name = "Option"
                                        Option.Size = UDim2.new(1,0,0,15)
                                        Option.BackgroundColor3 = Color3.new(1,1,1)
                                        Option.BackgroundTransparency = 1
                                        Option.BorderSizePixel = 0
                                        Option.BorderColor3 = Color3.new(0,0,0)
                                        Option.Text = ""
                                        Option.TextColor3 = Color3.new(0,0,0)
                                        Option.AutoButtonColor = false
                                        Option.Font = Enum.Font.SourceSans
                                        Option.TextSize = 14
                                        Dropdown.OptionInsts[option].button = Option
                                        Option.ZIndex = 5002
                                        OptionName.Name = "OptionName"
                                        OptionName.Position = UDim2.new(0,2,0,0)
                                        OptionName.Size = UDim2.new(1,0,1,0)
                                        OptionName.BackgroundColor3 = Color3.new(1,1,1)
                                        OptionName.BackgroundTransparency = 1
                                        OptionName.BorderSizePixel = 0
                                        OptionName.BorderColor3 = Color3.new(0,0,0)
                                        OptionName.Text = option
                                        OptionName.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                                        OptionName.FontFace = Library.UIFont
                                        OptionName.TextSize = Library.FontSize
                                        OptionName.TextXAlignment = Enum.TextXAlignment.Left
                                        
                                        OptionName.Active = false
                                        Dropdown.OptionInsts[option].text = OptionName
                                        OptionName.ZIndex = 5001
                                        handleoptionclick(option, Option, OptionName)
                                end
                        end
                        createoptions(Dropdown.Options)
                        function Dropdown:Set(option)
                                for opt, tbl in next, Dropdown.OptionInsts do
                                        if opt ~= option then
                                                tbl.text.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                                        end
                                end
                                if table.find(Dropdown.Options, option) then
                                        Chosen = option
                                        Value.Text = option
                                        Dropdown.OptionInsts[option].text.TextColor3 = Color3.fromRGB(255,255,255)
                                        Library.Flags[Dropdown.Flag] = Chosen
                                        Dropdown.Callback(Chosen)
                                else
                                        Chosen = nil
                                        Value.Text = ""
                                        Library.Flags[Dropdown.Flag] = Chosen
                                        Dropdown.Callback(Chosen)
                                end
                        end
                        function Dropdown:Refresh(tbl)
                                Dropdown.Options = tbl
                                for _, opt in next, Dropdown.OptionInsts do
                                        coroutine.wrap(function()
                                                opt.button:Destroy()
                                        end)()
                                end
                                table.clear(Dropdown.OptionInsts)
                                createoptions(tbl)
                                Chosen = nil
                                Library.Flags[Dropdown.Flag] = Chosen
                                Dropdown.Callback(Chosen)
                        end
                        Flags[Dropdown.Flag] = Dropdown
                        Dropdown:Set(Dropdown.State)
                        return Dropdown
                end
                function Sections:Multibox(Options)
                        local Properties = Options or {};
                        local Dropdown = {
                                Window = self.Window,
                                Page = self.Page,
                                Section = self,
                                Open = false,
                                Name = Properties.Title or Properties.Name or Properties.title or nil,
                                Options = (Properties.options or Properties.Options or Properties.values or Properties.Values or {
                                        "1",
                                        "2",
                                        "3",
                                }),
                                State = (
                                        Properties.state
                                                or Properties.State
                                                or Properties.def
                                                or Properties.Def
                                                or Properties.default
                                                or Properties.Default
                                                or nil
                                ),
                                Max = (Properties.max or Properties.Max or Properties.maximum or Properties.Maximum or 1),
                                Callback = (
                                        Properties.callback
                                                or Properties.Callback
                                                or Properties.callBack
                                                or Properties.CallBack
                                                or function() end
                                ),
                                Flag = (
                                        Properties.flag
                                                or Properties.Flag
                                                or Properties.pointer
                                                or Properties.Pointer
                                                or Library.NextFlag()
                                ),
                                OptionInsts = {},
                        }
                        local Holder = Instance.new('Frame', Options.Side == "Left" and Dropdown.Section.Elements.Left or Options.Side == "Right" and Dropdown.Section.Elements.Right or Dropdown.Section.Elements.Left)
                        local Frame = Instance.new('TextButton', Holder)
                        local Gradient = Instance.new('UIGradient', Frame)
                        local Value = Instance.new('TextLabel', Frame)
                        local Icon = Instance.new('TextLabel', Frame)
                        local Content = Instance.new('Frame', Frame)
                        local Gradient2 = Instance.new('UIGradient', Content)
                        local UIListLayout = Instance.new('UIListLayout', Content)
                        local Title = Instance.new('TextLabel', Holder)
                        do
                                table.insert(Library.Instances, Frame)
                                table.insert(Library.Instances, Value)
                                table.insert(Library.Instances, Icon)
                                table.insert(Library.Instances, Content)
                                table.insert(Library.Instances, Title)
                                table.insert(Dropdowns, Content)
                        end
                        Holder.Name = "Holder"
                        Holder.Size = UDim2.new(1,0,0,34)
                        Holder.BackgroundColor3 = Color3.new(1,1,1)
                        Holder.BackgroundTransparency = 1
                        Frame.Position = UDim2.new(0,15,0,16)
                        Frame.Size = UDim2.new(1,-30,0,15)
                        Frame.BackgroundColor3 = Color3.new(0.0784,0.0784,0.0784)
                        Frame.BorderColor3 = Color3.new(0,0,0)
                        Frame.Text = ""
                        Frame.AutoButtonColor = false
                        Gradient.Name = "Gradient"
                        Gradient.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(
                                        0,
                                        Color3.new(0.7803921699523926, 0.7490196228027344, 0.800000011920929)
                                ),
                                ColorSequenceKeypoint.new(
                                        1,
                                        Color3.new(1, 1, 1)
                                )
                        }
                        Gradient.Rotation = -90
                        Value.Name = "Value"
                        Value.Position = UDim2.new(0,2,0,0)
                        Value.Size = UDim2.new(1,-10,1,0)
                        Value.BackgroundColor3 = Color3.new(1,1,1)
                        Value.BackgroundTransparency = 1
                        Value.Text = ""
                        Value.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        Value.FontFace = Library.UIFont
                        Value.TextTruncate = Enum.TextTruncate.SplitWord
                        Value.TextSize = Library.FontSize
                        Value.ZIndex = 105
                        Value.TextXAlignment = Enum.TextXAlignment.Left
                        Value.ClipsDescendants = true
                        Icon.Name = "Icon"
                        Icon.Position = UDim2.new(0,-4,0,0)
                        Icon.Size = UDim2.new(1,0,1,0)
                        Icon.BackgroundColor3 = Color3.new(1,1,1)
                        Icon.BackgroundTransparency = 1
                        Icon.BorderSizePixel = 0
                        Icon.Text = "-"
                        Icon.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        Icon.FontFace = Library.UIFont
                        Icon.TextSize = Library.FontSize
                        Icon.ZIndex = 105
                        Icon.TextXAlignment = Enum.TextXAlignment.Right
                        Content.Name = "Content"
                        Content.Position = UDim2.new(0,0,0,18)
                        Content.Size = UDim2.new(1,0,0,0)
                        Content.BackgroundColor3 = Color3.new(0.0784,0.0784,0.0784)
                        Content.BorderColor3 = Color3.new(0,0,0)
                        Content.Visible = false
                        Content.ZIndex = 200
                        Content.AutomaticSize = Enum.AutomaticSize.Y
                        Content.ClipsDescendants = false
                        Gradient2.Name = "Gradient2"
                        Gradient2.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(
                                        0,
                                        Color3.new(0.7803921699523926, 0.7490196228027344, 0.800000011920929)
                                ),
                                ColorSequenceKeypoint.new(
                                        1,
                                        Color3.new(1, 1, 1)
                                )
                        }
                        Gradient2.Rotation = -90
                        UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
                        Title.Name = "Title"
                        Title.Position = UDim2.new(0,15,0,0)
                        Title.Size = UDim2.new(1,0,0,10)
                        Title.BackgroundColor3 = Color3.new(1,1,1)
                        Title.BackgroundTransparency = 1
                        Title.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        Title.FontFace = Library.UIFont
                        Title.TextSize = Library.FontSize
                        Title.ZIndex = 105
                        Title.TextXAlignment = Enum.TextXAlignment.Left
                        Title.Text = Dropdown.Name
                        
                        
                        
                        
                        local _popupRoot = (Library._GetPopupGui and Library:_GetPopupGui()) or (Library.Holder and Library.Holder.Parent) or Content.Parent
                        Content.Parent = _popupRoot
                        Content.AnchorPoint = Vector2.new(0, 0)
                        Content.Position = UDim2.fromOffset(0, 0)
                        Content.Size = UDim2.new(0, 0, 0, 0)
                        Content.AutomaticSize = Enum.AutomaticSize.Y
                        Content.ClipsDescendants = false
                        pcall(function() Content.ZIndex = 5000 end)
                        local _popupConn = nil
                        local function showPopup(v) end -- forward declare
                        local function syncPopup()
                                if not Frame or not Frame.Parent then showPopup(false) return end
                                local fs = Frame.AbsoluteSize
                                -- If section is hidden (e.g., tab switch), AbsoluteSize.X becomes 0
                                if fs.X <= 0 then showPopup(false) return end
                                local fp = Frame.AbsolutePosition
                                Content.Size = UDim2.fromOffset(fs.X, 0)
                                Content.Position = UDim2.fromOffset(fp.X, fp.Y + fs.Y)
                        end
                        showPopup = function(v)
                                if v then
                                        syncPopup()
                                        -- Don't show if section is hidden
                                        if Frame.AbsoluteSize.X <= 0 then return end
                                        Content.Visible = true
                                        if not _popupConn then
                                                _popupConn = game:GetService("RunService").RenderStepped:Connect(syncPopup)
                                        end
                                else
                                        Content.Visible = false
                                        if _popupConn then
                                                _popupConn:Disconnect()
                                                _popupConn = nil
                                        end
                                end
                        end
                        Library:Connection(Frame.MouseButton1Click, function()
                                showPopup(not Content.Visible)
                        end)
                        
                        local _multiboxClickConn = nil
                        Library:Connection(Content:GetPropertyChangedSignal("Visible"), function()
                                if Content.Visible then
                                        if _multiboxClickConn then _multiboxClickConn:Disconnect() end
                                        _multiboxClickConn = game:GetService("UserInputService").InputBegan:Connect(function(input, gpe)
                                                if gpe then return end
                                                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                                        if not Library:IsMouseOverFrame(Content) and not Library:IsMouseOverFrame(Holder) then
                                                                showPopup(false)
                                                                if _multiboxClickConn then _multiboxClickConn:Disconnect() _multiboxClickConn = nil end
                                                        end
                                                end
                                        end)
                                else
                                        if _multiboxClickConn then _multiboxClickConn:Disconnect() _multiboxClickConn = nil end
                                end
                        end)
                        local chosen = Dropdown.Max and {} or nil
                        local optioninstances = {}
                        local Count = 0
                        local _optionJustClicked = false
                        local function handleoptionclick(option, button, text)
                                button.MouseButton1Click:Connect(function()
                                        _optionJustClicked = true
                                        if Dropdown.Max then
                                                if table.find(chosen, option) then
                                                        table.remove(chosen, table.find(chosen, option))
                                                        local textchosen = {}
                                                        local cutobject = false
                                                        for _, opt in next, chosen do
                                                                table.insert(textchosen, opt)
                                                        end
                                                        Value.Text = #chosen == 0 and "" or table.concat(textchosen, ", ") .. (cutobject and ", ..." or "")
                                                        text.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                                                        Library.Flags[Dropdown.Flag] = chosen
                                                        Dropdown.Callback(chosen)
                                                else
                                                        if #chosen == Dropdown.Max then
                                                                Dropdown.OptionInsts[chosen[1]].text.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                                                                table.remove(chosen, 1)
                                                        end
                                                        table.insert(chosen, option)
                                                        local textchosen = {}
                                                        local cutobject = false
                                                        for _, opt in next, chosen do
                                                                table.insert(textchosen, opt)
                                                        end
                                                        Value.Text = #chosen == 0 and "" or table.concat(textchosen, ", ") .. (cutobject and ", ..." or "")
                                                        text.TextColor3 = Color3.fromRGB(255,255,255)
                                                        Library.Flags[Dropdown.Flag] = chosen
                                                        Dropdown.Callback(chosen)
                                                end
                                        end
                                end)
                        end
                        local function createoptions(tbl)
                                for _, option in next, tbl do
                                        Dropdown.OptionInsts[option] = {}
                                        local Option = Instance.new('TextButton', Content)
                                        local OptionName = Instance.new('TextLabel', Option)
                                        Option.Name = "Option"
                                        Option.Size = UDim2.new(1,0,0,15)
                                        Option.BackgroundColor3 = Color3.new(1,1,1)
                                        Option.BackgroundTransparency = 1
                                        Option.BorderSizePixel = 0
                                        Option.BorderColor3 = Color3.new(0,0,0)
                                        Option.Text = ""
                                        Option.TextColor3 = Color3.new(0,0,0)
                                        Option.AutoButtonColor = false
                                        Option.Font = Enum.Font.SourceSans
                                        Option.TextSize = 14
                                        Dropdown.OptionInsts[option].button = Option
                                        Option.ZIndex = 5002
                                        OptionName.Name = "OptionName"
                                        OptionName.Position = UDim2.new(0,2,0,0)
                                        OptionName.Size = UDim2.new(1,0,1,0)
                                        OptionName.BackgroundColor3 = Color3.new(1,1,1)
                                        OptionName.BackgroundTransparency = 1
                                        OptionName.BorderSizePixel = 0
                                        OptionName.BorderColor3 = Color3.new(0,0,0)
                                        OptionName.Text = option
                                        OptionName.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                                        OptionName.FontFace = Library.UIFont
                                        OptionName.TextSize = Library.FontSize
                                        OptionName.TextXAlignment = Enum.TextXAlignment.Left
                                        OptionName.Active = false
                                        Dropdown.OptionInsts[option].text = OptionName
                                        OptionName.ZIndex = 5001
                                        handleoptionclick(option, Option, OptionName)
                                end
                        end
                        createoptions(Dropdown.Options)
                        local set
                        set = function(option)
                                if Dropdown.Max then
                                        table.clear(chosen)
                                        option = type(option) == "table" and option or {}
                                        for opt, tbl in next, Dropdown.OptionInsts do
                                                if not table.find(option, opt) then
                                                        tbl.text.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                                                end
                                        end
                                        for i, opt in next, option do
                                                if table.find(Dropdown.Options, opt) and #chosen < Dropdown.Max then
                                                        table.insert(chosen, opt)
                                                        Dropdown.OptionInsts[opt].text.TextColor3 = Color3.fromRGB(255,255,255)
                                                end
                                        end
                                        local textchosen = {}
                                        local cutobject = false
                                        for _, opt in next, chosen do
                                                table.insert(textchosen, opt)
                                        end
                                        Value.Text = #chosen == 0 and "" or table.concat(textchosen, ", ") .. (cutobject and ", ..." or "")
                                        Library.Flags[Dropdown.Flag] = chosen
                                        Dropdown.Callback(chosen)
                                end
                        end
                        function Dropdown:Set(option)
                                set(option)
                        end
                        function Dropdown:Refresh(tbl)
                                content = table.clone(tbl)
                                for _, opt in next, Dropdown.OptionInsts do
                                        coroutine.wrap(function()
                                                opt.button:Destroy()
                                        end)()
                                end
                                table.clear(Dropdown.OptionInsts)
                                createoptions(tbl)
                                if Dropdown.Max then
                                        table.clear(chosen)
                                else
                                        chosen = nil
                                end
                                Library.Flags[Dropdown.Flag] = chosen
                                Dropdown.Callback(chosen)
                        end
                        Flags[Dropdown.Flag] = set
                        Dropdown:Set(Dropdown.State)
                        return Dropdown
                end
                function Sections:Keybind(Options)
                        local Properties = Options or {};
                        local Keybind = {
                                Section = self,
                                Name = Properties.Title or Properties.Name or Properties.title or "Keybind",
                                State = (
                                        Properties.state
                                                or Properties.State
                                                or Properties.def
                                                or Properties.Def
                                                or Properties.default
                                                or Properties.Default
                                                or nil
                                ),
                                Mode = (Properties.mode or Properties.Mode or "Toggle"),
                                Callback = (
                                        Properties.callback
                                                or Properties.Callback
                                                or Properties.callBack
                                                or Properties.CallBack
                                                or function() end
                                ),
                                Flag = (
                                        Properties.flag
                                                or Properties.Flag
                                                or Properties.pointer
                                                or Properties.Pointer
                                                or Library.NextFlag()
                                ),
                                Binding = nil,
                                Connection = nil,
                        }
                        local Key
                        local State = false
                        local _refreshValueText
                        local Holder = Instance.new('TextButton', Options.Side == "Left" and Keybind.Section.Elements.Left or Options.Side == "Right" and Keybind.Section.Elements.Right or Keybind.Section.Elements.Left)
                        local Title = Instance.new('TextLabel', Holder)
                        local Value = Instance.new('TextLabel', Holder)
                        do
                                table.insert(Library.Instances, Title)
                                table.insert(Library.Instances, Value)
                        end
                        Holder.Name = "Holder"
                        Holder.Size = UDim2.new(1,0,0,28)
                        Holder.BackgroundColor3 = Color3.new(1,1,1)
                        Holder.BackgroundTransparency = 1
                        Holder.Text = ""
                        Holder.TextColor3 = Color3.new(0,0,0)
                        Holder.AutoButtonColor = false
                        Holder.Font = Enum.Font.SourceSans
                        Holder.TextSize = 14
                        Title.Name = "Title"
                        Title.Position = UDim2.new(0,15,0,-1)
                        Title.Size = UDim2.new(1,-30,1,0)
                        Title.BackgroundColor3 = Color3.new(1,1,1)
                        Title.BackgroundTransparency = 1
                        Title.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        Title.FontFace = Library.UIFont
                        Title.TextSize = Library.FontSize
                        Title.ZIndex = 105
                        Title.TextXAlignment = Enum.TextXAlignment.Left
                        Title.Text = Keybind.Name
                        Value.Name = "Value"
                        Value.Position = UDim2.new(0,15,0,-1)
                        Value.Size = UDim2.new(1,-30,1,0)
                        Value.BackgroundColor3 = Color3.new(1,1,1)
                        Value.BackgroundTransparency = 1
                        Value.Text = "[-]"
                        Value.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        Value.FontFace = Library.UIFont
                        Value.TextSize = Library.FontSize
                        Value.ZIndex = 105
                        Value.TextXAlignment = Enum.TextXAlignment.Right
                        local function set(newkey)
                                if string.find(tostring(newkey), "Enum") then
                                        if Keybind.Connection then
                                                Keybind.Connection:Disconnect()
                                                if Keybind.Flag then
                                                        Library.Flags[Keybind.Flag] = false
                                                end
                                                Keybind.Callback(false)
                                        end
                                        if tostring(newkey):find("Enum.KeyCode.") then
                                                newkey = Enum.KeyCode[tostring(newkey):gsub("Enum.KeyCode.", "")]
                                        elseif tostring(newkey):find("Enum.UserInputType.") then
                                                newkey = Enum.UserInputType[tostring(newkey):gsub("Enum.UserInputType.", "")]
                                        end
                                        if newkey == Enum.KeyCode.Backspace then
                                                Key = nil
                                                Value.Text = "[-]"
                                        elseif newkey ~= nil then
                                                Key = newkey
                                                local text = (Library.Keys[newkey] or tostring(newkey):gsub("Enum.KeyCode.", ""))
                                                Value.Text = "[" .. text .. "]"
                                        end
                                        if _refreshValueText then _refreshValueText() end
                                        Library.Flags[Keybind.Flag .. "_KEY"] = newkey
                                elseif table.find({ "Always", "Toggle", "Hold" }, newkey) then
                                        Library.Flags[Keybind.Flag .. "_KEY STATE"] = newkey
                                        Keybind.Mode = newkey
                                        if _refreshValueText then _refreshValueText() end
                                        if Keybind.Mode == "Always" then
                                                State = true
                                                if Keybind.Flag then
                                                        Library.Flags[Keybind.Flag] = State
                                                end
                                                Keybind.Callback(true)
                                        end
                                else
                                        State = newkey
                                        if Keybind.Flag then
                                                Library.Flags[Keybind.Flag] = newkey
                                        end
                                        Keybind.Callback(newkey)
                                end
                        end
                        set(Keybind.State)
                        set(Keybind.Mode)
                        Holder.MouseButton1Click:Connect(function()
                                if not Keybind.Binding then
                                        Value.Text = "[-]"
                                        if _refreshValueText then _refreshValueText() end
                                        Keybind.Binding = Library:Connection(
                                                game:GetService("UserInputService").InputBegan,
                                                function(input, gpe)
                                                        set(
                                                                input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode
                                                                        or input.UserInputType
                                                        )
                                                        Library:Disconnect(Keybind.Binding)
                                                        task.wait()
                                                        Keybind.Binding = nil
                                                end
                                        )
                                end
                        end)
                        Library:Connection(game:GetService("UserInputService").InputBegan, function(inp, gpe)
                                if gpe and Keybind.Flag ~= "ui_menu_key" then return end
                                if Key == nil then return end
                                if (inp.KeyCode == Key or inp.UserInputType == Key) and not Keybind.Binding then
                                        if Keybind.Mode == "Hold" then
                                                State = true
                                                if Keybind.Flag then
                                                        Library.Flags[Keybind.Flag] = true
                                                end
                                                if Keybind.Callback then
                                                        Keybind.Callback(true)
                                                end
                                        elseif Keybind.Mode == "Toggle" then
                                                State = not State
                                                if Keybind.Flag then
                                                        Library.Flags[Keybind.Flag] = State
                                                end
                                                if Keybind.Callback then
                                                        Keybind.Callback(State)
                                                end
                                        elseif Keybind.Mode == "Always" then
                                                State = true
                                                if Keybind.Flag then
                                                        Library.Flags[Keybind.Flag] = true
                                                end
                                                if Keybind.Callback then
                                                        Keybind.Callback(true)
                                                end
                                        end
                                end
                        end)
                        Library:Connection(game:GetService("UserInputService").InputEnded, function(inp, gpe)
                                if gpe then return end
                                if Key == nil then return end
                                if Keybind.Mode == "Hold" then
                                        if inp.KeyCode == Key or inp.UserInputType == Key then
                                                State = false
                                                if Keybind.Flag then
                                                        Library.Flags[Keybind.Flag] = false
                                                end
                                                if Keybind.Callback then
                                                        Keybind.Callback(false)
                                                end
                                        end
                                end
                        end)
                        
                        do
                                -- Plain display: just [key], no mode suffix
                                _refreshValueText = function() end
                                -- Set a specific mode programmatically
                                local function _setMode(nm)
                                        Keybind.Mode = nm
                                        Library.Flags[Keybind.Flag .. "_KEY STATE"] = nm
                                        if nm == "Always" then
                                                State = true
                                                if Keybind.Flag then Library.Flags[Keybind.Flag] = true end
                                                if Keybind.Callback then Keybind.Callback(true) end
                                        end
                                end
                                -- Shift + RightClick on the keybind row opens mode picker
                                local _modeMenu = nil
                                local _modeMenuConn = nil
                                Holder.MouseButton2Click:Connect(function()
                                        local UIS2 = game:GetService("UserInputService")
                                        if not (UIS2:IsKeyDown(Enum.KeyCode.LeftShift) or UIS2:IsKeyDown(Enum.KeyCode.RightShift)) then return end
                                        if not _modeMenu then
                                                local pg = Library:_GetPopupGui()
                                                local menu = Instance.new("Frame", pg)
                                                menu.Name = "KeybindModeMenu"
                                                menu.Size = UDim2.fromOffset(88, 51)
                                                menu.BackgroundColor3 = Color3.fromRGB(25, 18, 38)
                                                menu.BorderColor3 = Color3.fromRGB(80, 60, 110)
                                                menu.ZIndex = 6000
                                                menu.Visible = false
                                                local uil = Instance.new("UIListLayout", menu)
                                                uil.SortOrder = Enum.SortOrder.LayoutOrder
                                                for i, modeName in ipairs({"Toggle", "Hold", "Always"}) do
                                                        local btn = Instance.new("TextButton", menu)
                                                        btn.Size = UDim2.new(1, 0, 0, 17)
                                                        btn.BackgroundColor3 = Color3.fromRGB(35, 25, 50)
                                                        btn.BackgroundTransparency = 0
                                                        btn.BorderSizePixel = 0
                                                        btn.Text = modeName
                                                        btn.TextColor3 = Color3.fromRGB(180, 160, 210)
                                                        btn.FontFace = Library.UIFont
                                                        btn.TextSize = Library.FontSize
                                                        btn.ZIndex = 6001
                                                        btn.LayoutOrder = i
                                                        btn.AutoButtonColor = false
                                                        btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(60, 45, 80) end)
                                                        btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(35, 25, 50) end)
                                                        btn.MouseButton1Click:Connect(function()
                                                                _setMode(modeName)
                                                                menu.Visible = false
                                                                if _modeMenuConn then _modeMenuConn:Disconnect(); _modeMenuConn = nil end
                                                        end)
                                                end
                                                _modeMenu = menu
                                        end
                                        local abs = Holder.AbsolutePosition
                                        local sz  = Holder.AbsoluteSize
                                        _modeMenu.Position = UDim2.fromOffset(abs.X, abs.Y + sz.Y)
                                        _modeMenu.Visible = true
                                        if _modeMenuConn then _modeMenuConn:Disconnect() end
                                        _modeMenuConn = game:GetService("UserInputService").InputBegan:Connect(function(inp)
                                                if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.MouseButton2 then
                                                        if not Library:IsMouseOverFrame(_modeMenu) then
                                                                _modeMenu.Visible = false
                                                                if _modeMenuConn then _modeMenuConn:Disconnect(); _modeMenuConn = nil end
                                                        end
                                                end
                                        end)
                                end)
                        end
                        Library.Flags[Keybind.Flag .. "_KEY"] = Keybind.State
                        Library.Flags[Keybind.Flag .. "_KEY STATE"] = Keybind.Mode
                        Flags[Keybind.Flag] = set
                        Flags[Keybind.Flag .. "_KEY"] = set
                        Flags[Keybind.Flag .. "_KEY STATE"] = set
                        function Keybind:Set(key)
                                set(key)
                        end
                        return Keybind
                end
                function Sections:Textbox(Options)
                        local Properties = Options or {}
                        local Textbox = {
                                Window = self.Window,
                                Page = self.Page,
                                Section = self,
                                Placeholder = (
                                        Properties.placeholder
                                                or Properties.Placeholder
                                                or Properties.holder
                                                or Properties.Holder
                                                or ""
                                ),
                                State = (
                                        Properties.state
                                                or Properties.State
                                                or Properties.def
                                                or Properties.Def
                                                or Properties.default
                                                or Properties.Default
                                                or ""
                                ),
                                Callback = (
                                        Properties.callback
                                                or Properties.Callback
                                                or Properties.callBack
                                                or Properties.CallBack
                                                or function() end
                                ),
                                Flag = (
                                        Properties.flag
                                                or Properties.Flag
                                                or Properties.pointer
                                                or Properties.Pointer
                                                or Library.NextFlag()
                                ),
                        }
                        local Holder = Instance.new('Frame', Options.Side == "Left" and Textbox.Section.Elements.Left or Options.Side == "Right" and Textbox.Section.Elements.Right or Textbox.Section.Elements.Left)
                        local TextFrame = Instance.new('Frame', Holder)
                        local Gradient = Instance.new('UIGradient', TextFrame)
                        local TextBox = Instance.new('TextBox', TextFrame)
                        do
                                table.insert(Library.Instances, TextFrame)
                                table.insert(Library.Instances, TextBox)
                        end
                        Holder.Name = "Holder"
                        Holder.Size = UDim2.new(1,0,0,15)
                        Holder.BackgroundColor3 = Color3.new(1,1,1)
                        Holder.BackgroundTransparency = 1
                        Holder.BorderSizePixel = 0
                        Holder.BorderColor3 = Color3.new(0,0,0)
                        TextFrame.Name = "TextFrame"
                        TextFrame.Position = UDim2.new(0,15,0,0)
                        TextFrame.Size = UDim2.new(1,-30,1,0)
                        TextFrame.BackgroundColor3 = Color3.new(0.0784,0.0784,0.0784)
                        TextFrame.BorderColor3 = Color3.new(0,0,0)
                        Gradient.Name = "Gradient"
                        Gradient.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(
                                        0,
                                        Color3.new(0.7803921699523926, 0.7490196228027344, 0.800000011920929)
                                ),
                                ColorSequenceKeypoint.new(
                                        1,
                                        Color3.new(1, 1, 1)
                                )
                        }
                        Gradient.Rotation = -90
                        TextBox.Size = UDim2.new(1,0,1,0)
                        TextBox.BackgroundColor3 = Color3.new(1,1,1)
                        TextBox.BackgroundTransparency = 1
                        TextBox.BorderSizePixel = 0
                        TextBox.BorderColor3 = Color3.new(0,0,0)
                        TextBox.Text = Textbox.State
                        TextBox.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        TextBox.FontFace = Library.UIFont
                        TextBox.TextSize = Library.FontSize
                        TextBox.PlaceholderText = Textbox.Placeholder
                        TextBox.PlaceholderColor3 = Color3.new(0.3059,0.3059,0.3059)
                        TextBox.ClearTextOnFocus = false
                        TextBox.TextWrapped = true
                        TextBox.FocusLost:Connect(function()
                                Textbox.Callback(TextBox.Text)
                                Library.Flags[Textbox.Flag] = TextBox.Text
                        end)
                        local function set(str)
                                TextBox.Text = str
                                Library.Flags[Textbox.Flag] = str
                                Textbox.Callback(str)
                        end
                        Flags[Textbox.Flag] = set
                        return Textbox
                end
                function Sections:Button(Options)
                        local Properties = Options or {}
                        local Button = {
                                Window = self.Window,
                                Page = self.Page,
                                Section = self,
                                Name = Properties.Title or Properties.Name or Properties.title or "button",
                                Callback = (
                                        Properties.callback
                                                or Properties.Callback
                                                or Properties.callBack
                                                or Properties.CallBack
                                                or function() end
                                ),
                        }
                        local Holder = Instance.new('Frame', Options.Side == "Left" and Button.Section.Elements.Left or Options.Side == "Right" and Button.Section.Elements.Right or Button.Section.Elements.Left)
                        local TextFrame = Instance.new('Frame', Holder)
                        local Gradient = Instance.new('UIGradient', TextFrame)
                        local Textbutton = Instance.new('TextButton', TextFrame)
                        do
                                table.insert(Library.Instances, TextFrame)
                                table.insert(Library.Instances, Textbutton)
                        end
                        Holder.Name = "Holder"
                        Holder.Size = UDim2.new(1,0,0,15)
                        Holder.BackgroundColor3 = Color3.new(1,1,1)
                        Holder.BackgroundTransparency = 1
                        Holder.BorderSizePixel = 0
                        Holder.BorderColor3 = Color3.new(0,0,0)
                        TextFrame.Name = "TextFrame"
                        TextFrame.Position = UDim2.new(0,15,0,0)
                        TextFrame.Size = UDim2.new(1,-30,1,0)
                        TextFrame.BackgroundColor3 = Color3.new(0.0784,0.0784,0.0784)
                        TextFrame.BorderColor3 = Color3.new(0,0,0)
                        Gradient.Name = "Gradient"
                        Gradient.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(
                                        0,
                                        Color3.new(0.7803921699523926, 0.7490196228027344, 0.800000011920929)
                                ),
                                ColorSequenceKeypoint.new(
                                        1,
                                        Color3.new(1, 1, 1)
                                )
                        }
                        Gradient.Rotation = -90
                        Textbutton.Name = "textbutton"
                        Textbutton.Size = UDim2.new(1,0,1,0)
                        Textbutton.BackgroundColor3 = Color3.new(1,1,1)
                        Textbutton.BackgroundTransparency = 1
                        Textbutton.BorderSizePixel = 0
                        Textbutton.BorderColor3 = Color3.new(0,0,0)
                        Textbutton.Text = Button.Name
                        Textbutton.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        Textbutton.FontFace = Library.UIFont
                        Textbutton.TextSize = Library.FontSize
                        Textbutton.MouseButton1Click:Connect(function()
                                Button.Callback()
                        end)
                        Textbutton.MouseButton1Down:Connect(function()
                                Textbutton.TextColor3 = Color3.fromRGB(255,255,255)
                        end)
                        Textbutton.MouseButton1Up:Connect(function()
                                Textbutton.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        end)
                        return Button
                end
                -- ===================== custom widgets =====================
                function Sections:Label(Options)
                        local Properties = Options or {}
                        local Label = {
                                Section = self,
                                Text = (Properties.text or Properties.Text or Properties.Name or "label"),
                                Color = Properties.color or Properties.Color or Color3.fromRGB(180, 180, 195),
                                Center = Properties.center or Properties.Center or false,
                        }
                        local parent = Options.Side == "Right" and self.Elements.Right or self.Elements.Left
                        local Holder = Instance.new('Frame', parent)
                        Holder.Name = "LabelHolder"
                        Holder.Size = UDim2.new(1, 0, 0, 14)
                        Holder.BackgroundTransparency = 1
                        Holder.BorderSizePixel = 0
                        local Text = Instance.new('TextLabel', Holder)
                        Text.Name = "Text"
                        Text.Position = UDim2.new(0, 15, 0, 0)
                        Text.Size = UDim2.new(1, -30, 1, 0)
                        Text.BackgroundTransparency = 1
                        Text.Text = Label.Text
                        Text.TextColor3 = Label.Color
                        Text.FontFace = Library.UIFont
                        Text.TextSize = Library.FontSize
                        Text.ZIndex = 105
                        Text.RichText = Properties.rich or Properties.Rich or false
                        Text.TextXAlignment = Label.Center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
                        Text.TextWrapped = false
                        table.insert(Library.Instances, Text)
                        function Label:Set(t) Text.Text = tostring(t) end
                        function Label:SetColor(c) Text.TextColor3 = c end
                        return Label
                end
                function Sections:Divider(Options)
                        local Properties = Options or {}
                        local parent = Properties.Side == "Right" and self.Elements.Right or self.Elements.Left
                        local Holder = Instance.new('Frame', parent)
                        Holder.Name = "DividerHolder"
                        Holder.Size = UDim2.new(1, 0, 0, 6)
                        Holder.BackgroundTransparency = 1
                        Holder.BorderSizePixel = 0
                        local Line = Instance.new('Frame', Holder)
                        Line.Name = "Line"
                        Line.Position = UDim2.new(0, 12, 0.5, 0)
                        Line.AnchorPoint = Vector2.new(0, 0.5)
                        Line.Size = UDim2.new(1, -24, 0, 1)
                        Line.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
                        Line.BorderSizePixel = 0
                        Line.ZIndex = 105
                        local Grad = Instance.new("UIGradient", Line)
                        Grad.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(0,   Color3.fromRGB(20, 20, 26)),
                                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 60, 100)),
                                ColorSequenceKeypoint.new(1,   Color3.fromRGB(20, 20, 26)),
                        }
                        return { Line = Line }
                end
                function Sections:Separator(Options)
                        local Properties = Options or {}
                        local title = Properties.title or Properties.Title or Properties.Name or "section"
                        local parent = Properties.Side == "Right" and self.Elements.Right or self.Elements.Left
                        local Holder = Instance.new('Frame', parent)
                        Holder.Name = "SeparatorHolder"
                        Holder.Size = UDim2.new(1, 0, 0, 16)
                        Holder.BackgroundTransparency = 1
                        Holder.BorderSizePixel = 0
                        local LeftLine = Instance.new('Frame', Holder)
                        LeftLine.Position = UDim2.new(0, 12, 0.5, 0)
                        LeftLine.AnchorPoint = Vector2.new(0, 0.5)
                        LeftLine.Size = UDim2.new(0, 16, 0, 1)
                        LeftLine.BackgroundColor3 = Color3.fromRGB(60, 50, 90)
                        LeftLine.BorderSizePixel = 0
                        LeftLine.ZIndex = 105
                        local Title = Instance.new('TextLabel', Holder)
                        Title.Position = UDim2.new(0, 32, 0, 0)
                        Title.Size = UDim2.new(0, 0, 1, 0)
                        Title.AutomaticSize = Enum.AutomaticSize.X
                        Title.BackgroundTransparency = 1
                        Title.Text = string.upper(tostring(title))
                        Title.TextColor3 = Library.Accent
                        Title.FontFace = Library.UIFont
                        Title.TextSize = Library.FontSize - 1
                        Title.TextXAlignment = Enum.TextXAlignment.Left
                        Title.ZIndex = 105
                        local RightLine = Instance.new('Frame', Holder)
                        RightLine.AnchorPoint = Vector2.new(1, 0.5)
                        RightLine.Position = UDim2.new(1, -12, 0.5, 0)
                        RightLine.Size = UDim2.new(1, -(32 + 16 + (#tostring(title) * 7) + 8), 0, 1)
                        RightLine.BackgroundColor3 = Color3.fromRGB(60, 50, 90)
                        RightLine.BorderSizePixel = 0
                        RightLine.ZIndex = 105
                        table.insert(Library.Instances, Title)
                        return { Title = Title }
                end
                function Sections:Image(Options)
                        local Properties = Options or {}
                        local parent = Properties.Side == "Right" and self.Elements.Right or self.Elements.Left
                        local height = tonumber(Properties.height or Properties.Height) or 60
                        local Holder = Instance.new('Frame', parent)
                        Holder.Name = "ImageHolder"
                        Holder.Size = UDim2.new(1, 0, 0, height + 4)
                        Holder.BackgroundTransparency = 1
                        Holder.BorderSizePixel = 0
                        local Img = Instance.new('ImageLabel', Holder)
                        Img.Position = UDim2.new(0, 12, 0, 2)
                        Img.Size = UDim2.new(1, -24, 0, height)
                        Img.BackgroundColor3 = Color3.fromRGB(22, 16, 32)
                        Img.BorderSizePixel = 0
                        Img.Image = tostring(Properties.image or Properties.Image or "")
                        Img.ScaleType = Properties.scaleType or Enum.ScaleType.Fit
                        Img.ZIndex = 105
                        local C = Instance.new("UICorner", Img)
                        C.CornerRadius = UDim.new(0, 4)
                        local S = Instance.new("UIStroke", Img)
                        S.Color = Color3.fromRGB(60, 45, 85); S.Thickness = 1
                        local Image = { Instance = Img }
                        function Image:Set(id) Img.Image = tostring(id) end
                        return Image
                end
                function Sections:ProgressBar(Options)
                        local Properties = Options or {}
                        local parent = Properties.Side == "Right" and self.Elements.Right or self.Elements.Left
                        local Bar = {
                                Name  = Properties.title or Properties.Title or Properties.Name or "progress",
                                Value = tonumber(Properties.value or Properties.Value or 0) or 0,
                                Max   = tonumber(Properties.max   or Properties.Max   or 100) or 100,
                                Flag  = (Properties.flag or Properties.Flag or Library.NextFlag()),
                        }
                        local Holder = Instance.new('Frame', parent)
                        Holder.Name = "ProgressHolder"
                        Holder.Size = UDim2.new(1, 0, 0, 22)
                        Holder.BackgroundTransparency = 1
                        Holder.BorderSizePixel = 0
                        local Title = Instance.new('TextLabel', Holder)
                        Title.Position = UDim2.new(0, 15, 0, 0)
                        Title.Size = UDim2.new(1, -30, 0, 12)
                        Title.BackgroundTransparency = 1
                        Title.Text = Bar.Name
                        Title.TextColor3 = Color3.new(0.3059, 0.3059, 0.3059)
                        Title.FontFace = Library.UIFont
                        Title.TextSize = Library.FontSize
                        Title.TextXAlignment = Enum.TextXAlignment.Left
                        Title.ZIndex = 105
                        local PctLbl = Instance.new('TextLabel', Holder)
                        PctLbl.Position = UDim2.new(1, -40, 0, 0)
                        PctLbl.Size = UDim2.new(0, 25, 0, 12)
                        PctLbl.BackgroundTransparency = 1
                        PctLbl.Text = "0%"
                        PctLbl.TextColor3 = Library.Accent
                        PctLbl.FontFace = Library.UIFont
                        PctLbl.TextSize = Library.FontSize
                        PctLbl.TextXAlignment = Enum.TextXAlignment.Right
                        PctLbl.ZIndex = 105
                        local Track = Instance.new('Frame', Holder)
                        Track.Position = UDim2.new(0, 15, 0, 14)
                        Track.Size = UDim2.new(1, -30, 0, 4)
                        Track.BackgroundColor3 = Color3.fromRGB(22, 16, 32)
                        Track.BorderSizePixel = 0
                        Track.ZIndex = 105
                        local TC = Instance.new("UICorner", Track); TC.CornerRadius = UDim.new(0, 2)
                        local TS = Instance.new("UIStroke", Track); TS.Color = Color3.fromRGB(60, 45, 85); TS.Thickness = 1
                        local Fill = Instance.new('Frame', Track)
                        Fill.Size = UDim2.new(0, 0, 1, 0)
                        Fill.BackgroundColor3 = Library.Accent
                        Fill.BorderSizePixel = 0
                        Fill.ZIndex = 106
                        local FC = Instance.new("UICorner", Fill); FC.CornerRadius = UDim.new(0, 2)
                        local Grad = Instance.new("UIGradient", Fill)
                        Grad.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(0, Color3.fromRGB(108, 78, 180)),
                                ColorSequenceKeypoint.new(1, Color3.fromRGB(186, 152, 255)),
                        }
                        table.insert(Library.Instances, Title)
                        table.insert(Library.ThemeObjects, Fill)
                        table.insert(Library.ThemeObjects, PctLbl)
                        local function paint()
                                local pct = math.clamp(Bar.Value / math.max(Bar.Max, 1), 0, 1)
                                Fill:TweenSize(UDim2.new(pct, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
                                PctLbl.Text = math.floor(pct * 100) .. "%"
                                Library.Flags[Bar.Flag] = Bar.Value
                        end
                        function Bar:Set(v)
                                Bar.Value = math.clamp(tonumber(v) or 0, 0, Bar.Max)
                                paint()
                        end
                        function Bar:SetMax(m)
                                Bar.Max = math.max(tonumber(m) or 100, 1)
                                paint()
                        end
                        function Bar:SetTitle(t) Title.Text = tostring(t) end
                        paint()
                        return Bar
                end
                -- ==========================================================
                function Sections:Colorpicker(Options)
                        local Properties = Options or {}
                        local Colorpicker = {
                                Window = self.Window,
                                Page = self.Page,
                                Section = self,
                                Name = (Properties.title or Properties.Title or Properties.Name or "Colorpicker"),
                                State = (
                                        Properties.state
                                                or Properties.State
                                                or Properties.def
                                                or Properties.Def
                                                or Properties.default
                                                or Properties.Default
                                                or Color3.fromRGB(255, 0, 0)
                                ),
                                Alpha = (
                                        Properties.alpha
                                                or Properties.Alpha
                                                or Properties.transparency
                                                or Properties.Transparency
                                                or 1
                                ),
                                Callback = (
                                        Properties.callback
                                                or Properties.Callback
                                                or Properties.callBack
                                                or Properties.CallBack
                                                or function() end
                                ),
                                Flag = (
                                        Properties.flag
                                                or Properties.Flag
                                                or Properties.pointer
                                                or Properties.Pointer
                                                or Library.NextFlag()
                                ),
                                Colorpickers = 0,
                        }
                        local Color = Instance.new('TextButton', Options.Side == "Left" and Colorpicker.Section.Elements.Left or Options.Side == "Right" and Colorpicker.Section.Elements.Right or Colorpicker.Section.Elements.Left)
                        local TextLabel = Instance.new('TextLabel', Color)
                        table.insert(Library.Instances, TextLabel)
                        Color.Name = "Color"
                        Color.Size = UDim2.new(1,0,0,10)
                        Color.BackgroundColor3 = Color3.new(1,1,1)
                        Color.BackgroundTransparency = 1
                        Color.Text = ""
                        Color.TextColor3 = Color3.new(0,0,0)
                        Color.AutoButtonColor = false
                        Color.Font = Enum.Font.SourceSans
                        Color.TextSize = 14
                        TextLabel.Position = UDim2.new(0,15,0,0)
                        TextLabel.Size = UDim2.new(1,0,1,0)
                        TextLabel.BackgroundColor3 = Color3.new(1,1,1)
                        TextLabel.BackgroundTransparency = 1
                        TextLabel.TextColor3 = Color3.new(0.3059,0.3059,0.3059)
                        TextLabel.FontFace = Library.UIFont
                        TextLabel.TextSize = Library.FontSize
                        TextLabel.ZIndex = 105
                        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
                        TextLabel.Text = Colorpicker.Name
                        Colorpicker.Colorpickers = Colorpicker.Colorpickers + 1
                        local colorpickertypes = Library:NewPicker(
                                Colorpicker.State,
                                Colorpicker.Alpha,
                                Color,
                                Colorpicker.Colorpickers - 1,
                                Colorpicker.Flag,
                                Colorpicker.Callback
                        )
                        function Colorpicker:Set(color)
                                colorpickertypes:set(color, false, true)
                        end
                        return Colorpicker
                end
        end
end
local ok, err = pcall(function()
local Window = Library:Window({ Name = "elocate.lol" })
pcall(function() Library:ChangeAccent(Color3.fromRGB(76, 162, 252)) end)
  local _AccentColor = Color3.fromRGB(76, 162, 252)
  
  local function makeScrollable(frame)
      if not frame or not frame.Parent then return frame end
      if frame:IsA("ScrollingFrame") then return frame end
      local parent = frame.Parent
      local sf = Instance.new("ScrollingFrame")
      sf.Name = frame.Name .. "_Scroll"
      sf.Parent = parent
      sf.Position = frame.Position
      sf.Size = frame.Size
      sf.BackgroundTransparency = 1
      sf.BorderSizePixel = 0
      sf.ZIndex = frame.ZIndex
      sf.ScrollBarThickness = 3
      sf.ScrollBarImageTransparency = 0
      sf.ScrollBarImageColor3 = _AccentColor
      sf.ScrollingDirection = Enum.ScrollingDirection.Y
      sf.CanvasSize = UDim2.new(0, 0, 0, 0)
      pcall(function() sf.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
      sf.ClipsDescendants = true
      sf.Active = true
      for _, child in ipairs(frame:GetChildren()) do
          child.Parent = sf
      end
      frame:Destroy()
      return sf
  end
  local function applyScroll(page)
      if not page or not page.Sections then return end
      for _, section in ipairs(page.Sections) do
          if section.Elements then
              section.Elements.Left  = makeScrollable(section.Elements.Left)
              section.Elements.Right = makeScrollable(section.Elements.Right)
          end
      end
  end
  local function pinTabLeft(window, page, leftOffset)
      pcall(function()
          local pageHolder = window.Elements.PageHolder
          if not pageHolder then return end
          local top = pageHolder.Parent
          if not top then return end
          local holders = pageHolder:GetChildren()
          local target = holders[#holders]
          if not target then return end
          target.Parent = top
          target.AnchorPoint = Vector2.new(0, 0)
          target.Position = UDim2.new(0, leftOffset or 70, 0, 0)
          target.Size = UDim2.new(0, 60, 1, 0)
      end)
  end
local _hitparts = {"Closest Part","Head","Neck","UpperTorso","LowerTorso","HumanoidRootPart","LeftArm","RightArm","LeftLeg","RightLeg","Random"}
local _easings  = {"Linear","Sine","Quad","Cubic","Quart","Quint","Expo","Circ","Back","Bounce","Elastic"}
local _easeOut  = {"In","Out","InOut"}
local _locktype = {"Camera"}
local _boxtype  = {"Corner","Full","3D"}
local _namepos  = {"Top","Bottom","Left","Right","Center"}
local _materials= {"Plastic","Wood","Slate","Concrete","CorrodedMetal","DiamondPlate","Foil","Grass","Ice","Marble","Granite","Brick","Pebble","Sand","Fabric","SmoothPlastic","Metal","WoodPlanks","Cobblestone","Rock","Glacier","Snow","Sandstone","Mud","Basalt","Ground","CrackedLava","Neon","Glass","Asphalt","LeafyGrass","Salt","Limestone","Pavement"}
local PageCombat = Window:Page({ Name = "combat" })
do
    local sAim = PageCombat:Section({ Name = "aimbot", LeftTitle = "main", RightTitle = "settings" })
    sAim:Toggle({ Name = "enabled",           Side = "Left", flag = "aim_enabled", default = false, callback = function(v)
        if _G._elocate_notify then _G._elocate_notify("aimbot " .. (v and "on" or "off"), 1.5, "good") end
        if not v then _G._aimTarget = nil; _G._lastAimTarget = nil end
    end })
    sAim:Toggle({ Name = "mouse aim mode",     Side = "Left", flag = "aim_mouse_mode", default = false, callback = function(v)
        if _G._elocate_notify then _G._elocate_notify("mouse aim " .. (v and "on" or "off"), 1, "good") end
    end })
    sAim:Keybind({ Name = "toggle key", Side = "Left", flag = "kb_aim_toggle", mode = "Toggle", callback = function(v)
        if v then
            Library.Flags["aim_enabled"] = not (Library.Flags["aim_enabled"] == true)
            if _G._elocate_notify then _G._elocate_notify("aimbot " .. (Library.Flags["aim_enabled"] and "on" or "off"), 1.5, "good") end
            if not Library.Flags["aim_enabled"] then _G._aimTarget = nil; _G._lastAimTarget = nil end
        end
    end })
    sAim:Toggle({ Name = "sticky aim",        Side = "Left", flag = "aim_sticky", default = false, callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify("sticky aim " .. (v and "on" or "off"), 1, "good") end
    end })
    sAim:Toggle({ Name = "auto stop on death", Side = "Left", flag = "aim_autostop",   default = true,  callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify("auto stop " .. (v and "on" or "off"), 1, "good") end
    end })
    sAim:Slider({ Name = "max distance",      Side = "Left", min = 50, max = 5000, default = 1000, suffix = "m", flag = "aim_max_dist", callback = function(v) end })
    sAim:Toggle({ Name = "use smoothness",   Side = "Left", flag = "aim_use_smooth", default = false,  callback = function(v) end })
    sAim:Toggle({ Name = "use prediction",   Side = "Left", flag = "aim_use_pred",   default = false,  callback = function(v) end })
    sAim:List({   Name = "default hit part", Side = "Left", options = _hitparts, default = "Head", flag = "aim_hp_default", callback = function(v) end })
    sAim:List({   Name = "fall hit part",    Side = "Left", options = _hitparts, default = "UpperTorso", flag = "aim_hp_fall", callback = function(v) end })
    sAim:List({   Name = "jump hit part",    Side = "Left", options = _hitparts, default = "HumanoidRootPart", flag = "aim_hp_jump", callback = function(v) end })
    
    sAim:Toggle({ Name = "use fov",          Side = "Right", flag = "aim_use_fov",  default = false, callback = function(v) end })
    sAim:Toggle({ Name = "show fov",         Side = "Right", flag = "aim_show_fov", default = true,  callback = function(v) end })
    sAim:Colorpicker({ Name = "fov color",   Side = "Right", default = Color3.fromRGB(147,112,219), alpha = 1, flag = "aim_fov_col", callback = function(v) end })
    sAim:Slider({ Name = "fov size",         Side = "Right", min = 10,  max = 800, default = 120, suffix = "px", flag = "aim_fov_size", callback = function(v) end })
    sAim:Slider({ Name = "smoothness X",     Side = "Right", min = 1, max = 50, default = 5, decimals = 0.1, suffix = "x", flag = "aim_smooth_x", callback = function(v) end })
    sAim:Slider({ Name = "smoothness Y",     Side = "Right", min = 1, max = 50, default = 5, decimals = 0.1, suffix = "x", flag = "aim_smooth_y", callback = function(v) end })
    sAim:Slider({ Name = "prediction X",     Side = "Right", min = 0, max = 100, default = 15, decimals = 0.1, suffix = "%", flag = "aim_pred_x", callback = function(v) end })
    sAim:Slider({ Name = "prediction Y",     Side = "Right", min = 0, max = 100, default = 15, decimals = 0.1, suffix = "%", flag = "aim_pred_y", callback = function(v) end })
    sAim:Multibox({ Name = "checks", Side = "Right", flag = "aim_checks", Max = 10, options = {"team check","friend check","visible check","wall check"}, default = {}, callback = function(v) end })
    local sAimAdv = PageCombat:Section({ Name = "advanced", LeftTitle = "fine tuning", RightTitle = "extra visuals" })
    sAimAdv:Toggle({ Name = "enable adv prediction", Side = "Left", flag = "aim_adv_en", default = false, callback = function(v)
        if _G._elocate_notify then _G._elocate_notify("advanced pred " .. (v and "on" or "off"), 1, "good") end
    end })
    sAimAdv:Slider({ Name = "pred left",    Side = "Left", min = -2, max = 2, default = 0, decimals = 0.01, suffix = "", flag = "aim_pred_l", callback = function(v) end })
    sAimAdv:Slider({ Name = "pred right",   Side = "Left", min = -2, max = 2, default = 0, decimals = 0.01, suffix = "", flag = "aim_pred_r", callback = function(v) end })
    sAimAdv:Slider({ Name = "pred up",      Side = "Left", min = -2, max = 2, default = 0, decimals = 0.01, suffix = "", flag = "aim_pred_u", callback = function(v) end })
    sAimAdv:Slider({ Name = "pred down",    Side = "Left", min = -2, max = 2, default = 0, decimals = 0.01, suffix = "", flag = "aim_pred_d", callback = function(v) end })
    sAimAdv:Toggle({ Name = "directional smooth", Side = "Left", flag = "aim_smooth_dir_en", default = false, callback = function(v) end })
    sAimAdv:Slider({ Name = "smooth left",  Side = "Left", min = 0, max = 100, default = 50, suffix = "%", flag = "aim_smooth_l", callback = function(v) end })
    sAimAdv:Slider({ Name = "smooth right", Side = "Left", min = 0, max = 100, default = 50, suffix = "%", flag = "aim_smooth_r", callback = function(v) end })
    sAimAdv:Slider({ Name = "smooth up",    Side = "Left", min = 0, max = 100, default = 50, suffix = "%", flag = "aim_smooth_u", callback = function(v) end })
    sAimAdv:Slider({ Name = "smooth down",  Side = "Left", min = 0, max = 100, default = 50, suffix = "%", flag = "aim_smooth_d", callback = function(v) end })
    sAimAdv:Toggle({ Name = "aim offset", Side = "Left", flag = "aim_offset_en", default = false, callback = function(v) end })
    sAimAdv:Slider({ Name = "jump offset", Side = "Left", min = -50, max = 50, default = 0, suffix = "px", flag = "aim_off_jump", callback = function(v) end })
    sAimAdv:Slider({ Name = "fall offset", Side = "Left", min = -50, max = 50, default = 0, suffix = "px", flag = "aim_off_fall", callback = function(v) end })
    sAimAdv:Slider({ Name = "x offset", Side = "Left", min = -100, max = 100, default = 0, suffix = "px", flag = "aim_off_x", callback = function(v) end })
    sAimAdv:Slider({ Name = "y offset", Side = "Left", min = -100, max = 100, default = 0, suffix = "px", flag = "aim_off_y", callback = function(v) end })
    sAimAdv:List({ Name = "lock method", Side = "Right", options = {"Camera", "Mousemove"}, default = "Camera", flag = "aim_lock_method", callback = function(v) end })
    sAimAdv:Toggle({ Name = "target notifications", Side = "Right", flag = "aim_notify_tgt", default = false, callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify("target notifications " .. (v and "on" or "off"), 1, "good") end
    end })
    sAimAdv:Slider({ Name = "fov transparency", Side = "Right", min = 0, max = 100, default = 70, suffix = "%", flag = "aim_fov_trans", callback = function(v) end })
    sAimAdv:Toggle({ Name = "use easing",       Side = "Right", flag = "aim_use_ease",   default = false, callback = function(v) end })
    sAimAdv:List({   Name = "easing type",      Side = "Right", options = _easings, default = "Sine", flag = "aim_ease_type", callback = function(v) end })
    sAimAdv:List({   Name = "easing direction", Side = "Right", options = _easeOut, default = "Out",  flag = "aim_ease_dir",  callback = function(v) end })
    sAimAdv:Slider({ Name = "shake factor",     Side = "Right", min = 0, max = 100, default = 0, suffix = "%", flag = "aim_shake", callback = function(v) end })
    sAimAdv:Slider({ Name = "jitter amount",    Side = "Right", min = 0, max = 50, default = 0, suffix = "px", flag = "aim_jitter", callback = function(v) end })
    local sSilent = PageCombat:Section({ Name = "silent aim", LeftTitle = "main", RightTitle = "settings" })
    sSilent:Toggle({ Name = "enabled",           Side = "Left", flag = "sa_enabled", default = false, callback = function(v) if _G._elocate_notify then _G._elocate_notify(v and "silent aim on" or "silent aim off", 1, "good") end end })
    sSilent:Keybind({ Name = "trigger key",   Side = "Left", flag = "sa_key", mode = "Hold", callback = function(v) _G._elocate_sa_keyheld = v end })
    sSilent:Toggle({ Name = "use prediction",    Side = "Left", flag = "sa_use_pred", default = false, callback = function(v) end })
    sSilent:Toggle({ Name = "use resolver",      Side = "Left", flag = "sa_use_res",  default = false, callback = function(v) end })
    sSilent:Toggle({ Name = "da hood mode",     Side = "Left", flag = "sa_dahood_mode", default = false, callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify(v and "da hood mode on" or "da hood mode off", 1, "good") end 
    end })
    sSilent:Multibox({ Name = "checks", Side = "Left", flag = "sa_checks", Max = 10, options = {"team check","friend check","visible check","wall check"}, default = {}, callback = function(v) end })
    sSilent:List({   Name = "default hit part",  Side = "Left", options = _hitparts, default = "Head", flag = "sa_hp_default", callback = function(v) end })
    sSilent:Slider({ Name = "hit chance",        Side = "Left", min = 0, max = 100, default = 100, suffix = "%", flag = "sa_hitchance", callback = function(v) end })
    sSilent:Toggle({ Name = "use fov",           Side = "Right", flag = "sa_use_fov",  default = false,  callback = function(v) end })
    sSilent:Colorpicker({ Name = "fov color",    Side = "Right", default = Color3.fromRGB(255,80,80), alpha = 1, flag = "sa_fov_col", callback = function(v) end })
    sSilent:Slider({ Name = "fov size",          Side = "Right", min = 10,  max = 800, default = 80, suffix = "px", flag = "sa_fov_size", callback = function(v) end })
    sSilent:Slider({ Name = "prediction",        Side = "Right", min = 0, max = 100, default = 15, decimals = 0.1, suffix = "%", flag = "sa_pred", callback = function(v) end })
    sSilent:List({   Name = "resolver mode",     Side = "Right", options = {"Off","Stand","Slow","Air","All"}, default = "Off", flag = "sa_resolver", callback = function(v) end })
    
    -- NEW: Advanced Combat Features
    local sAdvCombat = PageCombat:Section({ Name = "advanced combat", LeftTitle = "desync & void", RightTitle = "bullet fx" })
    
    -- Desync System
    sAdvCombat:Toggle({ Name = "enable desync",      Side = "Left", flag = "desync_en", default = false, callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify("desync " .. (v and "on" or "off"), 1.5, "good") end
    end })
    sAdvCombat:Keybind({ Name = "desync key",        Side = "Left", flag = "kb_desync", mode = "Toggle", callback = function(v)
        if v then
            Library.Flags["desync_en"] = not (Library.Flags["desync_en"] == true)
            if _G._elocate_notify then _G._elocate_notify("desync " .. (Library.Flags["desync_en"] and "on" or "off"), 1.5, "good") end
        end
    end })
    sAdvCombat:Slider({ Name = "desync X",            Side = "Left", min = -10000, max = 10000, default = 0, flag = "desync_x", callback = function(v) end })
    sAdvCombat:Slider({ Name = "desync Y",            Side = "Left", min = -10000, max = 10000, default = 1000, flag = "desync_y", callback = function(v) end })
    sAdvCombat:Slider({ Name = "desync Z",            Side = "Left", min = -10000, max = 10000, default = 0, flag = "desync_z", callback = function(v) end })
    sAdvCombat:List({   Name = "desync mode",         Side = "Left", options = {"Custom","God Mode","Random","Spin"}, default = "Custom", flag = "desync_mode", callback = function(v) end })
    sAdvCombat:Toggle({ Name = "auto desync on aim",  Side = "Left", flag = "desync_auto", default = false, callback = function(v) end })
    
    -- Void Hide / Anti-Kick
    sAdvCombat:Toggle({ Name = "void hide",          Side = "Left", flag = "voidhide_en", default = false, callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify("void hide " .. (v and "on" or "off"), 1.5, "good") end
    end })
    sAdvCombat:Keybind({ Name = "void hide key",     Side = "Left", flag = "kb_voidhide", mode = "Toggle", callback = function(v)
        if v then
            Library.Flags["voidhide_en"] = not (Library.Flags["voidhide_en"] == true)
            if _G._elocate_notify then _G._elocate_notify("void hide " .. (Library.Flags["voidhide_en"] and "on" or "off"), 1.5, "good") end
        end
    end })
    sAdvCombat:Slider({ Name = "hide height",        Side = "Left", min = -5000, max = 0, default = -500, suffix = "m", flag = "voidhide_h", callback = function(v) end })
    sAdvCombat:Toggle({ Name = "auto hide on low hp", Side = "Left", flag = "voidhide_auto", default = false, callback = function(v) end })
    sAdvCombat:Slider({ Name = "auto hide hp %",     Side = "Left", min = 1, max = 50, default = 15, suffix = "%", flag = "voidhide_hp", callback = function(v) end })
    
    -- Hit Sounds & Target Visuals
    sAdvCombat:Toggle({ Name = "hit sounds",         Side = "Right", flag = "hit_sound", default = false, callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify("hit sounds " .. (v and "on" or "off"), 1.5, "good") end
    end })
    sAdvCombat:Slider({ Name = "sound volume",       Side = "Right", min = 1, max = 10, default = 5, suffix = "x", flag = "hit_vol", callback = function(v) end })
    sAdvCombat:List({   Name = "sound preset",        Side = "Right", options = {"Bameware","Bell","Bubble","Pick","Pop","Rust","Sans","Fart","Big","Vine","Bruh","Skeet","Neverlose","Fatality","Bonk","Minecraft"}, default = "Bell", flag = "hit_sound_type", callback = function(v) end })
    sAdvCombat:Textbox({ Name = "custom sound id",   Side = "Right", default = "", flag = "hit_sound_id", callback = function(v) end })
    
    -- God Mode Position
    sAdvCombat:Toggle({ Name = "god mode pos",       Side = "Left", flag = "godmode_en", default = false, callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify("god mode " .. (v and "on" or "off"), 1.5, "good") end
    end })
    sAdvCombat:Keybind({ Name = "god mode key",      Side = "Left", flag = "kb_godmode", mode = "Toggle", callback = function(v)
        if v then
            Library.Flags["godmode_en"] = not (Library.Flags["godmode_en"] == true)
            if _G._elocate_notify then _G._elocate_notify("god mode " .. (Library.Flags["godmode_en"] and "on" or "off"), 1.5, "good") end
        end
    end })
    sAdvCombat:Toggle({ Name = "server sided pos",    Side = "Left", flag = "godmode_server", default = false, callback = function(v) end })
    
    -- NEW: Da Hood Skin Changer Section
    local sSkins = PageCombat:Section({ Name = "hood customs", LeftTitle = "skins", RightTitle = "bullet beams" })
    
    -- Skin Changer Toggles
    sSkins:Toggle({ Name = "enable skin changer", Side = "Left", flag = "skin_changer_en", default = false, callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify("skin changer " .. (v and "on" or "off"), 1.5, "good") end
        if v then applySkinChanger() end
    end })
    
    sSkins:List({ Name = "gun skin", Side = "Left", options = {"Ascension","Void Dragon","Hell Hound","Snow Dragon","Lovestruck","Adurite","Hallows","Candy Cane","Heartbringer","Arctic","Lightbringer","Deathbringer","Hell Dragon","Kitty","Kirumi","Shiryus Breath","Poseidon","Amethyst","Arsenic","Volcanic Ashes","Floral","Binary","Voxel","Hello Kitty","Radiation","Void","Hexagram","Strawberry Shortcake","Black Ice","Crimson Fangs","Green Tint","Ember"}, default = "Ascension", flag = "gun_skin", callback = function(v) end })
    
    sSkins:List({ Name = "knife skin", Side = "Left", options = {"Beta","Fishbone"}, default = "Beta", flag = "knife_skin", callback = function(v) end })
    
    -- Bullet Beam Toggles
    sSkins:Toggle({ Name = "enable bullet skins", Side = "Right", flag = "bullet_skin_en", default = false, callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify("bullet skins " .. (v and "on" or "off"), 1.5, "good") end
        if v then applyBulletSkins() end
    end })
    
    sSkins:List({ Name = "bullet beam", Side = "Right", options = {"Rainbow","Lightning","Beta","Hallows","Kitty","Kirumi","Red","Blue","Green","Orange"}, default = "Rainbow", flag = "bullet_beam_skin", callback = function(v) end })
    
    sSkins:Toggle({ Name = "spoof subscription", Side = "Right", flag = "sub_spoof", default = false, callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify("sub spoof " .. (v and "on" or "off"), 1.5, "good") end
        if v then spoofSubscription() end
    end })
end
applyScroll(PageCombat)
local PageESP = Window:Page({ Name = "esp" })
do
    local s = PageESP:Section({ Name = "esp", LeftTitle = "boxes & names", RightTitle = "info & misc" })
    s:Toggle({ Name = "enable esp",            Side = "Left", flag = "esp_enabled", default = false, callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify("esp " .. (v and "on" or "off"), 1.5, "good") end
        
        if not v then
            for plr, _ in pairs(_espDraws or {}) do hideDraw(plr) end
        end
    end })
    s:Keybind({ Name = "toggle esp key",       Side = "Left", flag = "kb_esp_toggle", mode = "Toggle", callback = function(v)
        if v then
            Library.Flags["esp_enabled"] = not (Library.Flags["esp_enabled"] == true)
            if _G._elocate_notify then _G._elocate_notify("esp " .. (Library.Flags["esp_enabled"] and "on" or "off"), 1.5, "good") end
        end
    end })
    s:Slider({ Name = "max distance",          Side = "Left", min = 0, max = 5000, default = 0, suffix = "m", flag = "esp_max_dist", callback = function(v) end })
    s:Toggle({ Name = "team check",            Side = "Left", flag = "esp_teamcheck",  default = false, callback = function(v) end })
    s:Toggle({ Name = "friend check",          Side = "Left", flag = "esp_friendcheck",default = false, callback = function(v) end })
    s:Toggle({ Name = "box esp",               Side = "Left", flag = "esp_box", default = true, callback = function(v) end })
    s:Colorpicker({ Name = "box color",        Side = "Left", default = Color3.fromRGB(147,112,219), flag = "esp_box_col", callback = function(v) end })
    s:List({   Name = "box type",              Side = "Left", options = _boxtype, default = "Corner", flag = "esp_box_type", callback = function(v) end })
    s:Toggle({ Name = "box outline",           Side = "Left", flag = "esp_box_out", default = false, callback = function(v) end })
    s:Colorpicker({ Name = "box outline color",Side = "Left", default = Color3.fromRGB(0,0,0), flag = "esp_box_outcol", callback = function(v) end })
    s:Toggle({ Name = "name esp",              Side = "Left", flag = "esp_name", default = false, callback = function(v) end })
    s:Colorpicker({ Name = "name color",       Side = "Left", default = Color3.fromRGB(147,112,219), flag = "esp_name_col", callback = function(v) end })
    s:List({   Name = "name position",         Side = "Left", options = _namepos, default = "Top", flag = "esp_name_pos", callback = function(v) end })
    s:Toggle({ Name = "name outline",          Side = "Left", flag = "esp_name_out", default = false, callback = function(v) end })
    s:Colorpicker({ Name = "name outline col", Side = "Left", default = Color3.fromRGB(0,0,0), flag = "esp_name_outcol", callback = function(v) end })
    s:Toggle({ Name = "distance esp",          Side = "Right", flag = "esp_dist", default = false, callback = function(v) end })
    s:Colorpicker({ Name = "distance color",   Side = "Right", default = Color3.fromRGB(147,112,219), flag = "esp_dist_col", callback = function(v) end })
    s:List({   Name = "distance position",     Side = "Right", options = _namepos, default = "Bottom", flag = "esp_dist_pos", callback = function(v) end })
    s:Toggle({ Name = "distance outline",      Side = "Right", flag = "esp_dist_out", default = false, callback = function(v) end })
    s:Colorpicker({ Name = "dist outline col", Side = "Right", default = Color3.fromRGB(0,0,0), flag = "esp_dist_outcol", callback = function(v) end })
    s:Toggle({ Name = "tool esp",              Side = "Right", flag = "esp_tool", default = false, callback = function(v) end })
    s:Colorpicker({ Name = "tool color",       Side = "Right", default = Color3.fromRGB(147,112,219), flag = "esp_tool_col", callback = function(v) end })
    s:List({   Name = "tool position",         Side = "Right", options = _namepos, default = "Bottom", flag = "esp_tool_pos", callback = function(v) end })
    s:Toggle({ Name = "tool outline",          Side = "Right", flag = "esp_tool_out", default = false, callback = function(v) end })
    s:Colorpicker({ Name = "tool outline col", Side = "Right", default = Color3.fromRGB(0,0,0), flag = "esp_tool_outcol", callback = function(v) end })
    s:Toggle({ Name = "health bar",            Side = "Right", flag = "esp_hp", default = false, callback = function(v) end })
    s:List({   Name = "health bar position",   Side = "Right", options = {"Left","Right","Top","Bottom"}, default = "Left", flag = "esp_hp_pos", callback = function(v) end })
    s:Slider({ Name = "health bar width",      Side = "Right", min = 1, max = 10, default = 2, suffix = "px", flag = "esp_hp_w", callback = function(v) end })
    s:Toggle({ Name = "health bar outline",    Side = "Right", flag = "esp_hp_out", default = false, callback = function(v) end })
    s:Colorpicker({ Name = "hp outline color", Side = "Right", default = Color3.fromRGB(0,0,0), flag = "esp_hp_outcol", callback = function(v) end })
    s:Toggle({ Name = "health text",           Side = "Right", flag = "esp_hp_text", default = false, callback = function(v) end })
    s:Toggle({ Name = "hit numbers",           Side = "Right", flag = "esp_hitnum", default = false, callback = function(v) end })
    s:Colorpicker({ Name = "hit number color", Side = "Right", default = Color3.fromRGB(255,50,50), flag = "esp_hitnum_col", callback = function(v) end })
    s:Toggle({ Name = "tracers",               Side = "Right", flag = "esp_tr", default = false, callback = function(v) end })
    s:Colorpicker({ Name = "tracer color",     Side = "Right", default = Color3.fromRGB(147,112,219), flag = "esp_tr_col", callback = function(v) end })
    s:List({   Name = "tracer origin",         Side = "Right", options = {"Top","Bottom","Center","Mouse"}, default = "Bottom", flag = "esp_tr_origin", callback = function(v) end })
    s:Slider({ Name = "tracer thickness",      Side = "Right", min = 1, max = 5, default = 1, suffix = "px", flag = "esp_tr_thick", callback = function(v) end })
    s:Toggle({ Name = "tracer outline",        Side = "Right", flag = "esp_tr_out", default = false, callback = function(v) end })
    s:Colorpicker({ Name = "tracer out color", Side = "Right", default = Color3.fromRGB(0,0,0), flag = "esp_tr_outcol", callback = function(v) end })
    s:Toggle({ Name = "show on local",         Side = "Left", flag = "esp_local", default = false, callback = function(v) end })
    s:Toggle({ Name = "visible check",         Side = "Left", flag = "esp_vischeck", default = false, callback = function(v) end })
    s:Slider({ Name = "min distance",          Side = "Left", min = 0, max = 500, default = 0, suffix = "m", flag = "esp_min_dist", callback = function(v) end })
    s:Slider({ Name = "text size",             Side = "Left", min = 8, max = 20, default = 13, suffix = "px", flag = "esp_txt_size", callback = function(v) end })
end
applyScroll(PageESP)
local PageOthers = Window:Page({ Name = "others" })
do
    local s = PageOthers:Section({ Name = "player / tool", LeftTitle = "player chams", RightTitle = "tool chams" })
    s:Toggle({ Name = "player chams",          Side = "Left", flag = "ch_p_en", default = false, callback = function(v) end })
    s:Keybind({ Name = "toggle chams key",     Side = "Left", flag = "kb_chams_toggle", mode = "Toggle", callback = function(v)
        if v then
            Library.Flags["ch_p_en"] = not (Library.Flags["ch_p_en"] == true)
            if _G._elocate_notify then _G._elocate_notify("chams " .. (Library.Flags["ch_p_en"] and "on" or "off"), 1.5, "good") end
        end
    end })
    s:Colorpicker({ Name = "fill color",       Side = "Left", default = Color3.fromRGB(147,112,219), flag = "ch_p_fill", callback = function(v) end })
    s:Slider({ Name = "fill transparency",     Side = "Left", min = 0, max = 100, default = 50, suffix = "%", flag = "ch_p_fill_t", callback = function(v) end })
    s:Colorpicker({ Name = "outline color",    Side = "Left", default = Color3.fromRGB(0,0,0), flag = "ch_p_out", callback = function(v) end })
    s:Slider({ Name = "outline transparency",  Side = "Left", min = 0, max = 100, default = 0, suffix = "%", flag = "ch_p_out_t", callback = function(v) end })
    s:Toggle({ Name = "fill rgb mode",         Side = "Left", flag = "ch_p_rgb", default = false, callback = function(v) end })
    s:Slider({ Name = "fill rgb speed",        Side = "Left", min = 1, max = 50, default = 5, suffix = "x", flag = "ch_p_rgb_speed", callback = function(v) end })
    s:Toggle({ Name = "outline rgb mode",      Side = "Left", flag = "ch_p_out_rgb", default = false, callback = function(v) end })
    s:Slider({ Name = "outline rgb speed",     Side = "Left", min = 1, max = 50, default = 5, suffix = "x", flag = "ch_p_out_rgb_speed", callback = function(v) end })
    s:Toggle({ Name = "include self",          Side = "Left", flag = "ch_p_self", default = false, callback = function(v) end })
    s:Toggle({ Name = "team check",            Side = "Left", flag = "ch_p_team", default = false, callback = function(v) end })
    s:Toggle({ Name = "use team color",        Side = "Left", flag = "ch_p_teamcol", default = false, callback = function(v) end })
    s:Toggle({ Name = "distance check",        Side = "Left", flag = "ch_p_dist_en", default = false, callback = function(v) end })
    s:Slider({ Name = "max distance",          Side = "Left", min = 50, max = 5000, default = 1000, suffix = "m", flag = "ch_p_dist_max", callback = function(v) end })
    s:Toggle({ Name = "tool chams",            Side = "Right", flag = "ch_t_en", default = false, callback = function(v) end })
    s:Colorpicker({ Name = "fill color",       Side = "Right", default = Color3.fromRGB(147,112,219), flag = "ch_t_fill", callback = function(v) end })
    s:Slider({ Name = "fill transparency",     Side = "Right", min = 0, max = 100, default = 50, suffix = "%", flag = "ch_t_fill_t", callback = function(v) end })
    s:Colorpicker({ Name = "outline color",    Side = "Right", default = Color3.fromRGB(0,0,0), flag = "ch_t_out", callback = function(v) end })
    s:Slider({ Name = "outline transparency",  Side = "Right", min = 0, max = 100, default = 0, suffix = "%", flag = "ch_t_out_t", callback = function(v) end })
    s:Toggle({ Name = "fill rgb mode",         Side = "Right", flag = "ch_t_rgb", default = false, callback = function(v) end })
    s:Slider({ Name = "fill rgb speed",        Side = "Right", min = 1, max = 50, default = 5, suffix = "x", flag = "ch_t_rgb_speed", callback = function(v) end })
    s:Toggle({ Name = "outline rgb mode",      Side = "Right", flag = "ch_t_out_rgb", default = false, callback = function(v) end })
    s:Slider({ Name = "outline rgb speed",     Side = "Right", min = 1, max = 50, default = 5, suffix = "x", flag = "ch_t_out_rgb_speed", callback = function(v) end })
    s:Toggle({ Name = "include self",          Side = "Right", flag = "ch_t_self", default = true, callback = function(v) end })
    s:Toggle({ Name = "include others",        Side = "Right", flag = "ch_t_others", default = false, callback = function(v) end })
    s:Toggle({ Name = "include backpack",      Side = "Right", flag = "ch_t_backpack", default = true, callback = function(v) end })
    s:Toggle({ Name = "distance check",        Side = "Right", flag = "ch_t_dist_en", default = false, callback = function(v) end })
    s:Slider({ Name = "max distance",          Side = "Right", min = 50, max = 5000, default = 1000, suffix = "m", flag = "ch_t_dist_max", callback = function(v) end })
    s:List({   Name = "chams material",        Side = "Right", options = {"ForceField","Neon","Glass","Ice","Metal","Wood","Plastic"}, default = "ForceField", flag = "ch_t_mat", callback = function(v) end })
    s:Colorpicker({ Name = "chams color",      Side = "Right", default = Color3.fromRGB(147,112,219), flag = "ch_t_fill", callback = function(v) end })
    s:Toggle({ Name = "force field",           Side = "Right", flag = "tool_forcefield_en", default = false, callback = function(v) end })
    s:Colorpicker({ Name = "ff color",         Side = "Right", default = Color3.fromRGB(147,112,219), flag = "tool_forcefield_col", callback = function(v) end })
    s:Toggle({ Name = "ff rgb",                Side = "Right", flag = "tool_forcefield_rgb", default = false, callback = function(v) end })
    s:Toggle({ Name = "tool trail",            Side = "Right", flag = "tool_trail_en", default = false, callback = function(v) end })
    s:Slider({ Name = "trail life",            Side = "Right", min = 0.1, max = 5, default = 1, decimals = 0.1, suffix = "s", flag = "tool_trail_life", callback = function(v) end })
    s:Slider({ Name = "trail width",           Side = "Right", min = 0.1, max = 5, default = 1, decimals = 0.1, suffix = "x", flag = "tool_trail_width", callback = function(v) end })
    s:Colorpicker({ Name = "trail color",      Side = "Right", default = Color3.fromRGB(147,112,219), flag = "tool_trail_col", callback = function(v) end })
    s:Toggle({ Name = "trail rgb",             Side = "Right", flag = "tool_trail_rgb", default = false, callback = function(v) end })
    s:Slider({ Name = "rgb speed",             Side = "Right", min = 1, max = 50, default = 5, suffix = "x", flag = "tool_trail_rgb_speed", callback = function(v) end })
    local sWorld = PageOthers:Section({ Name = "world", LeftTitle = "fog & sky", RightTitle = "lighting & effects" })
    sWorld:Toggle({ Name = "actual rain",          Side = "Right", flag = "w_rain_en", default = false, callback = function(v) end })
    sWorld:Slider({ Name = "rain density",         Side = "Right", min = 10, max = 500, default = 100, flag = "w_rain_amt", callback = function(v) end })
    sWorld:Toggle({ Name = "remove fog",           Side = "Left", flag = "w_fog_off", default = false, callback = function(v) end })
    sWorld:Slider({ Name = "fog start",            Side = "Left", min = 0, max = 5000,  default = 0,    suffix = "m", flag = "w_fog_start", callback = function(v) end })
    sWorld:Slider({ Name = "fog end",              Side = "Left", min = 0, max = 10000, default = 1000, suffix = "m", flag = "w_fog_end",   callback = function(v) end })
    sWorld:Colorpicker({ Name = "fog color",       Side = "Left", default = Color3.fromRGB(180,200,220), flag = "w_fog_col", callback = function(v) end })
    sWorld:Toggle({ Name = "enable custom skybox", Side = "Left", flag = "w_sky_en", default = false, callback = function(v) end })
    sWorld:List({   Name = "sky preset",           Side = "Left", options = {"Piss","Peach","Saku","Purple","Retro","Space","Sea","Night V2","Dark","Anime","Beach","Space V2","Pink","Rainbow","Forest","Night","Lava","Rainy","Green","Volcanic","Minecraft","Lucid","Nebulous","Custom"}, default = "Piss", flag = "w_sky_preset", callback = function(v) end })
    sWorld:Textbox({ Name = "custom texture id",    Side = "Left", default = "", flag = "w_sky_id", callback = function(v) end })
    sWorld:Toggle({ Name = "skybox spin",          Side = "Left", flag = "w_sky_spin", default = false, callback = function(v) end })
    sWorld:Slider({ Name = "spin speed",           Side = "Left", min = 1, max = 100, default = 30, suffix = "x", flag = "w_sky_spin_speed", callback = function(v) end })
    sWorld:Toggle({ Name = "custom lighting",      Side = "Right", flag = "w_light_en", default = false, callback = function(v) end })
    sWorld:Slider({ Name = "brightness",           Side = "Right", min = 0, max = 10, default = 2, decimals = 0.1, flag = "w_light_bright", callback = function(v) end })
    sWorld:Slider({ Name = "time of day",          Side = "Right", min = 0, max = 24, default = 14, decimals = 0.1, suffix = "h", flag = "w_light_time", callback = function(v) end })
    sWorld:Colorpicker({ Name = "ambient",         Side = "Right", default = Color3.fromRGB(128,128,128), flag = "w_light_ambient", callback = function(v) end })
    sWorld:Colorpicker({ Name = "outdoor ambient", Side = "Right", default = Color3.fromRGB(128,128,128), flag = "w_light_outdoor", callback = function(v) end })
    sWorld:Toggle({ Name = "material changer",     Side = "Left", flag = "w_mat_en",  default = false, callback = function(v) end })
    sWorld:List({   Name = "material",             Side = "Left", options = _materials, default = "Plastic", flag = "w_mat", callback = function(v) end })
    sWorld:Toggle({ Name = "use material color",   Side = "Left", flag = "w_mat_usecol", default = false, callback = function(v) end })
    sWorld:Colorpicker({ Name = "material color",  Side = "Left", default = Color3.fromRGB(255,255,255), flag = "w_mat_col", callback = function(v) end })
    
    sWorld:Toggle({ Name = "color correction",     Side = "Left", flag = "w_cc_en", default = false, callback = function(v) end })
    sWorld:Slider({ Name = "saturation",           Side = "Left", min = -20, max = 20, default = 5, decimals = 0.1, flag = "w_cc_sat", callback = function(v) end })
    sWorld:Slider({ Name = "contrast",             Side = "Left", min = -20, max = 20, default = 2, decimals = 0.1, flag = "w_cc_con", callback = function(v) end })
    sWorld:Slider({ Name = "brightness",           Side = "Left", min = -10, max = 10, default = 0, decimals = 0.1, flag = "w_cc_bri", callback = function(v) end })
    sWorld:Toggle({ Name = "bloom effect",         Side = "Right", flag = "w_bloom_en", default = false, callback = function(v) end })
    sWorld:Slider({ Name = "bloom intensity",      Side = "Right", min = 0, max = 10, default = 1, decimals = 0.1, flag = "w_bloom_int", callback = function(v) end })
    sWorld:Slider({ Name = "bloom size",           Side = "Right", min = 0, max = 56, default = 24, flag = "w_bloom_sz", callback = function(v) end })
    sWorld:Slider({ Name = "bloom threshold",      Side = "Right", min = 0, max = 10, default = 2, decimals = 0.1, flag = "w_bloom_thr", callback = function(v) end })
    end
applyScroll(PageOthers)
local PageMovement = Window:Page({ Name = "misc" })
do
    local s = PageMovement:Section({ Name = "misc", LeftTitle = "movement & character", RightTitle = "camera & effects" })
    s:Toggle({ Name = "walk speed",          Side = "Left", flag = "mv_ws_en",  default = false, callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify("walk speed " .. (v and "on" or "off"), 1, "good") end
        
        if not v and _LP and _LP.Character and _LP.Character:FindFirstChildOfClass("Humanoid") then
            _LP.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = 16
        end
    end })
    s:Slider({ Name = "speed",               Side = "Left", min = 16, max = 500, default = 50, suffix = "s", flag = "mv_ws_v", callback = function(v) end })
    s:Keybind({ Name = "toggle speed key",   Side = "Left", flag = "kb_ws_toggle", mode = "Toggle", callback = function(v)
        if v then
            Library.Flags["mv_ws_en"] = not (Library.Flags["mv_ws_en"] == true)
            if _G._elocate_notify then _G._elocate_notify("speed " .. (Library.Flags["mv_ws_en"] and "on" or "off"), 1.5, "good") end
        end
    end })
    s:Toggle({ Name = "speed macro",         Side = "Left", flag = "mv_macro_en", default = false, callback = function(v)
        if _G._elocate_notify then _G._elocate_notify("speed macro " .. (v and "on" or "off"), 1, "good") end
    end })
    s:Slider({ Name = "macro speed",         Side = "Left", min = 50, max = 500, default = 120, suffix = "s", flag = "mv_macro_v", callback = function(v) end })
    s:Keybind({ Name = "macro key",          Side = "Left", flag = "kb_macro", mode = "Hold", callback = function(v)
        if _G._elocate_notify then _G._elocate_notify("macro " .. (v and "on" or "off"), 1, "good") end
    end })
    s:Toggle({ Name = "jump power",          Side = "Left", flag = "mv_jp_en",  default = false, callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify("jump power " .. (v and "on" or "off"), 1, "good") end
        
        if not v and _LP and _LP.Character and _LP.Character:FindFirstChildOfClass("Humanoid") then
            _LP.Character:FindFirstChildOfClass("Humanoid").JumpPower = 50
        end
    end })
    s:Slider({ Name = "jump",                Side = "Left", min = 50, max = 500, default = 75, flag = "mv_jp_v", callback = function(v) end })
    s:Toggle({ Name = "low gravity",         Side = "Left", flag = "mv_grav_en", default = false, callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify("low gravity " .. (v and "on" or "off"), 1, "good") end
        
        if not v then Workspace.Gravity = 196.2 end
    end })
    s:Slider({ Name = "gravity",             Side = "Left", min = 0, max = 196, default = 60, flag = "mv_grav_v", callback = function(v) end })
    s:Toggle({ Name = "infinite jump",       Side = "Left", flag = "mv_infjump", default = false, callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify("infinite jump " .. (v and "on" or "off"), 1, "good") end
    end })
    s:Keybind({ Name = "toggle infjump key", Side = "Left", flag = "kb_infj_toggle", mode = "Toggle", callback = function(v)
        if v then
            Library.Flags["mv_infjump"] = not (Library.Flags["mv_infjump"] == true)
            if _G._elocate_notify then _G._elocate_notify("inf jump " .. (Library.Flags["mv_infjump"] and "on" or "off"), 1.5, "good") end
        end
    end })
    s:Toggle({ Name = "fly",                 Side = "Right", flag = "mv_fly_en", default = false, callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify("fly " .. (v and "on" or "off"), 1, "good") end
    end })
    s:Slider({ Name = "fly speed",           Side = "Right", min = 10, max = 400, default = 80, flag = "mv_fly_v", callback = function(v) end })
    s:Keybind({ Name = "toggle fly key",     Side = "Right", flag = "kb_fly_toggle", mode = "Toggle", callback = function(v)
        if v then
            Library.Flags["mv_fly_en"] = not (Library.Flags["mv_fly_en"] == true)
            if _G._elocate_notify then _G._elocate_notify("fly " .. (Library.Flags["mv_fly_en"] and "on" or "off"), 1.5, "good") end
        end
    end })
    s:Toggle({ Name = "noclip",              Side = "Right", flag = "mv_noclip", default = false, callback = function(v) 
        if _G._elocate_notify then _G._elocate_notify("noclip " .. (v and "on" or "off"), 1, "good") end
    end })
    s:Keybind({ Name = "toggle noclip key",  Side = "Right", flag = "kb_nocl_toggle", mode = "Toggle", callback = function(v)
        if v then
            Library.Flags["mv_noclip"] = not (Library.Flags["mv_noclip"] == true)
            if _G._elocate_notify then _G._elocate_notify("noclip " .. (Library.Flags["mv_noclip"] and "on" or "off"), 1.5, "good") end
        end
    end })
    s:Toggle({ Name = "custom fov",         Side = "Left", flag = "cam_fov_en", default = false, callback = function(v) end })
    s:Slider({ Name = "fov",                Side = "Left", min = 30, max = 120, default = 90, flag = "cam_fov_v", callback = function(v) end })
    
    s:Toggle({ Name = "animation changer",    Side = "Left", flag = "anim_en", default = false, callback = function(v) end })
    local packs = {"Default","Mage","Zombie","Ninja","Superhero","Vampire","Werewolf","Pirate","Astronaut","Robot","Sneaky"}
    s:List({   Name = "idle anim",            Side = "Left", options = packs, default = "Mage", flag = "anim_idle", callback = function(v) end })
    s:List({   Name = "walk anim",            Side = "Left", options = packs, default = "Mage", flag = "anim_walk", callback = function(v) end })
    s:List({   Name = "run anim",             Side = "Left", options = packs, default = "Mage", flag = "anim_run", callback = function(v) end })
    s:List({   Name = "jump anim",            Side = "Left", options = packs, default = "Mage", flag = "anim_jump", callback = function(v) end })
    s:List({   Name = "fall anim",            Side = "Left", options = packs, default = "Mage", flag = "anim_fall", callback = function(v) end })
    s:Toggle({ Name = "ghost trail",          Side = "Right", flag = "ghost_en", default = false, callback = function(v) end })
    s:Colorpicker({ Name = "ghost color",     Side = "Right", default = Color3.fromRGB(147,112,219), flag = "ghost_col", callback = function(v) end })
    s:Slider({ Name = "ghost delay",          Side = "Right", min = 1, max = 20, default = 5, suffix = " frames", flag = "ghost_delay", callback = function(v) end })
    s:Slider({ Name = "ghost duration",       Side = "Right", min = 0.1, max = 5, default = 1, decimals = 0.1, suffix = "s", flag = "ghost_dur", callback = function(v) end })
end
applyScroll(PageMovement)
  local Players       = game:GetService("Players")
  local RunService    = game:GetService("RunService")
  local Stats         = game:GetService("Stats")
  local UIS_RUNTIME   = game:GetService("UserInputService")
  local TweenService  = game:GetService("TweenService")
  local _LP = Players.LocalPlayer
  local _WidgetGui = Instance.new("ScreenGui")
  pcall(function() _WidgetGui.ResetOnSpawn = false end)
  pcall(function() _WidgetGui.IgnoreGuiInset = true end)
  _WidgetGui.Name = "_elocate_widgets_" .. tostring(math.random(100000,999999))
  _WidgetGui.DisplayOrder = 50
  _WidgetGui.Parent = (Library.Holder and Library.Holder.Parent) or game:GetService("CoreGui")
  
  -- Show main UI now that game is selected
  pcall(function() Library:SetOpen(true) end)
  if _G._elocate_notify and _G._elocate_gameMode then
      local _prof = _G._elocate_gameProfile or {}
      _G._elocate_notify("loaded: " .. (_prof.displayName or _G._elocate_gameMode), 2, "good")
      -- =================  per-game flag profile  =================
      -- apply game-specific defaults so features that need it just work
      Library.Flags = Library.Flags or {}
      local _F = Library.Flags
      local function _setIfNil(k, v) if _F[k] == nil then _F[k] = v end end
      if _prof.features then
          if _prof.features.silentDahood then _F.sa_dahood_mode = true end
          if _prof.engine == "fe-fps" then
              _setIfNil("sa_hp_default", "Head")
              _setIfNil("sa_use_pred", true)
          elseif _prof.engine == "dahood-melee" then
              _setIfNil("sa_hp_default", "HumanoidRootPart")
              _F.sa_dahood_mode = true
          end
      end
      _setIfNil("sa_aimables", _prof.aimables or { "Head","HumanoidRootPart" })
  end
  
  local function flag(name, default)
      local v = Library.Flags and Library.Flags[name]
      if v == nil then return default end
      return v
  end
  local function posPreset(name, padding)
      padding = padding or 12
      if name == "Top Left"     then return Vector2.new(0,0), UDim2.new(0,padding,0,padding) end
      if name == "Top Right"    then return Vector2.new(1,0), UDim2.new(1,-padding,0,padding) end
      if name == "Bottom Left"  then return Vector2.new(0,1), UDim2.new(0,padding,1,-padding) end
      if name == "Bottom Right" then return Vector2.new(1,1), UDim2.new(1,-padding,1,-padding) end
      if name == "Center"       then return Vector2.new(0.5,0.5), UDim2.new(0.5,0,0.5,0) end
      return Vector2.new(0,0), UDim2.new(0,padding,0,padding)
  end
  local NotifContainer = Instance.new("Frame", _WidgetGui)
  NotifContainer.Name = "Notifs"
  NotifContainer.AnchorPoint = Vector2.new(1, 0)
  NotifContainer.Position = UDim2.new(1, -12, 0, 60)
  NotifContainer.Size = UDim2.new(0, 240, 1, -80)
  NotifContainer.BackgroundTransparency = 1
  NotifContainer.BorderSizePixel = 0
  local NotifLayout = Instance.new("UIListLayout", NotifContainer)
  NotifLayout.SortOrder = Enum.SortOrder.LayoutOrder
  NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
  NotifLayout.Padding = UDim.new(0, 6)
  local _notifOrder = 0
  local _activeNotifs = {}
  
  
  local function _applyNotifPos()
      local pos = tostring(flag("notif_pos", "bottom-right"))
      
      local map = {
          ["top-right"]    = {1,0,1,-12,0, 60, "Right",  "Top",    "Down"},
          ["top-left"]     = {0,0,0, 12,0, 60, "Left",   "Top",    "Down"},
          ["top-center"]   = {0.5,0,0.5,0,0, 60, "Center","Top",    "Down"},
          ["bottom-right"] = {1,1,1,-12,1,-12, "Right",  "Bottom", "Up"},
          ["bottom-left"]  = {0,1,0, 12,1,-12, "Left",   "Bottom", "Up"},
          ["bottom-center"]= {0.5,1,0.5,0,1,-12,"Center","Bottom", "Up"},
          ["middle"]       = {0.5,0.5,0.5,0,0.5,0,"Center","Center","Down"},
      }
      local m = map[pos] or map["bottom-right"]
      pcall(function()
          NotifContainer.AnchorPoint = Vector2.new(m[1], m[2])
          NotifContainer.Position    = UDim2.new(m[3], m[4], m[5], m[6])
          NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment[m[7]]
          NotifLayout.VerticalAlignment   = Enum.VerticalAlignment[m[8]]
          
          if m[9] == "Up" then
              NotifLayout.SortOrder = Enum.SortOrder.LayoutOrder
              NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
          end
      end)
  end
  local function notify(msg, duration, ntype)
      if not flag("sys_notif", true) then return end
      
      
      if ntype == "good" and not flag("notif_features", true) then return end
      duration = duration or flag("notif_dur", 3)
      _applyNotifPos()
      _notifOrder = _notifOrder + 1
      
      
      
      local themeCol = flag("notif_col", Library.Accent or _AccentColor)
      local accent = (ntype == "error") and Color3.fromRGB(252, 76, 76)
          or (ntype == "warn")  and Color3.fromRGB(252, 200, 76)
          or themeCol
      
      local showIcon = flag("notif_show_icon", true)
      local layout   = tostring(flag("notif_layout", "full"))
      local textOnly = (layout == "text only")
      local anim     = tostring(flag("notif_anim", "slide-right"))
      
      local icon =
            (ntype == "error") and "!"
         or (ntype == "warn")  and "!"
         or (ntype == "good")  and "+"
         or "*"
      
      local maxN = math.max(1, math.floor(flag("notif_max", 5)))
      while #_activeNotifs >= maxN do
          local victim = table.remove(_activeNotifs, 1)
          if victim and victim.Parent then pcall(function() victim:Destroy() end) end
      end
      
      local frame = Instance.new("Frame", NotifContainer)
      table.insert(_activeNotifs, frame)
      frame.LayoutOrder = _notifOrder
      frame.Size = UDim2.new(1, 0, 0, textOnly and 22 or 32)
      frame.BackgroundTransparency = 1
      frame.BorderSizePixel = 0
      frame.ClipsDescendants = true
      
      
      local content = Instance.new("Frame", frame)
      content.Size = UDim2.new(1, 0, 1, 0)
      content.BackgroundColor3 = Color3.fromRGB(25, 18, 38)
      content.BorderColor3 = Color3.fromRGB(60, 45, 85)
      content.BackgroundTransparency = 1
      content.BorderSizePixel = 0
      local stroke = Instance.new("UIStroke", content)
      stroke.Color = Color3.fromRGB(80, 60, 110)
      stroke.Thickness = 1
      stroke.Transparency = 1
      local accentBar = Instance.new("Frame", content)
      accentBar.Size = UDim2.new(0, 2, 1, 0)
      accentBar.BackgroundColor3 = accent
      accentBar.BorderSizePixel = 0
      accentBar.BackgroundTransparency = 1
      
      local iconLbl = Instance.new("TextLabel", content)
      iconLbl.Position = UDim2.new(0, 6, 0, 2)
      iconLbl.Size = UDim2.new(0, 16, 0, 14)
      iconLbl.BackgroundTransparency = 1
      iconLbl.Text = icon
      iconLbl.TextColor3 = accent
      iconLbl.FontFace = Library.UIFont
      iconLbl.TextSize = Library.FontSize + 1
      iconLbl.TextXAlignment = Enum.TextXAlignment.Center
      iconLbl.TextTransparency = 1
      iconLbl.Visible = (showIcon and not textOnly)
      
      local label = Instance.new("TextLabel", content)
      local labelLeft = (iconLbl.Visible) and 22 or 8
      label.Position = UDim2.new(0, labelLeft, 0, 2)
      label.Size = UDim2.new(1, -labelLeft - 4, 0, textOnly and 18 or 16)
      label.BackgroundTransparency = 1
      label.Text = tostring(msg)
      label.TextColor3 = Color3.fromRGB(220,224,230)
      label.FontFace = Library.UIFont
      label.TextSize = Library.FontSize
      label.TextXAlignment = Enum.TextXAlignment.Left
      label.TextTransparency = 1
      
      local progBg, progFill
      if not textOnly then
          progBg = Instance.new("Frame", content)
          progBg.Position = UDim2.new(0, 2, 1, -4)
          progBg.Size = UDim2.new(1, -4, 0, 2)
          progBg.BackgroundColor3 = Color3.fromRGB(22,25,32)
          progBg.BorderSizePixel = 0
          progBg.BackgroundTransparency = 1
          progFill = Instance.new("Frame", progBg)
          progFill.Size = UDim2.new(1, 0, 1, 0)
          progFill.BackgroundColor3 = accent
          progFill.BorderSizePixel = 0
      end
      
      
      
      local ti = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
      local startOff
      if anim == "slide-right"      then startOff = UDim2.new(0,  240, 0, 0)
      elseif anim == "slide-left"   then startOff = UDim2.new(0, -240, 0, 0)
      elseif anim == "slide-up"     then startOff = UDim2.new(0, 0, 0,  20)
      elseif anim == "slide-down"   then startOff = UDim2.new(0, 0, 0, -20)
      end
      if startOff then
          content.Position = startOff
          TweenService:Create(content, ti, {Position = UDim2.new(0,0,0,0), BackgroundTransparency = 0.05}):Play()
      else
          TweenService:Create(content, ti, {BackgroundTransparency = 0.05}):Play()
      end
      TweenService:Create(stroke,   ti, {Transparency = 0}):Play()
      TweenService:Create(accentBar,ti, {BackgroundTransparency = 0}):Play()
      TweenService:Create(label,    ti, {TextTransparency = 0}):Play()
      if iconLbl.Visible then TweenService:Create(iconLbl, ti, {TextTransparency = 0}):Play() end
      if progBg then TweenService:Create(progBg, ti, {BackgroundTransparency = 0}):Play() end
      task.spawn(function()
          task.wait(0.2)
          if progFill then
              TweenService:Create(progFill, TweenInfo.new(duration - 0.2, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 1, 0)}):Play()
          end
          task.wait(duration)
          local out = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
          if startOff then
              TweenService:Create(content, out, {Position = startOff, BackgroundTransparency = 1}):Play()
          else
              TweenService:Create(content, out, {BackgroundTransparency = 1}):Play()
          end
          TweenService:Create(stroke,   out, {Transparency = 1}):Play()
          TweenService:Create(accentBar,out, {BackgroundTransparency = 1}):Play()
          TweenService:Create(label,    out, {TextTransparency = 1}):Play()
          if iconLbl.Visible then TweenService:Create(iconLbl, out, {TextTransparency = 1}):Play() end
          if progBg then TweenService:Create(progBg, out, {BackgroundTransparency = 1}):Play() end
          task.wait(0.3)
          for i, n in ipairs(_activeNotifs) do
              if n == frame then table.remove(_activeNotifs, i); break end
          end
          if frame and frame.Parent then frame:Destroy() end
      end)
  end
  local Wm = Instance.new("Frame", _WidgetGui)
  Wm.Name = "Watermark"
  Wm.Size = UDim2.new(0, 240, 0, 20)
  Wm.BackgroundColor3 = Color3.fromRGB(22, 16, 32)   -- INLINE, matches loader / game-chooser body
  Wm.BorderColor3 = Color3.fromRGB(0,0,0)
  Wm.BorderSizePixel = 0
  local WmGrad = Instance.new("UIGradient", Wm)
  WmGrad.Rotation = 90
  WmGrad.Color = ColorSequence.new{
      ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 30, 60)),
      ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 16, 32))
  }
  local WmStroke = Instance.new("UIStroke", Wm)
  WmStroke.Color = Color3.fromRGB(80, 60, 110)       -- STROKE_OUT, matches loader purple outline
  WmStroke.Thickness = 1
  WmStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
  local WmAccent = Instance.new("Frame", Wm)
  WmAccent.Name = "AccentLine"
  WmAccent.Size = UDim2.new(1, 0, 0, 1)
  WmAccent.Position = UDim2.new(0, 0, 0, 0)
  WmAccent.BackgroundColor3 = Color3.fromRGB(147,112,219)
  WmAccent.BorderSizePixel = 0
  local WmAccentGrad = Instance.new("UIGradient", WmAccent)
  WmAccentGrad.Color = ColorSequence.new{
      ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
      ColorSequenceKeypoint.new(0.5, Color3.fromRGB(147,112,219)),
      ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255))
  }
  WmAccentGrad.Transparency = NumberSequence.new{
      NumberSequenceKeypoint.new(0, 1),
      NumberSequenceKeypoint.new(0.5, 0),
      NumberSequenceKeypoint.new(1, 1)
  }
  local WmText = Instance.new("TextLabel", Wm)
  WmText.Position = UDim2.new(0, 6, 0, 0)
  WmText.Size = UDim2.new(1, -12, 1, 0)
  WmText.BackgroundTransparency = 1
  WmText.Text = ""
  WmText.TextColor3 = Color3.fromRGB(220,224,230)
  WmText.FontFace = Library.UIFont
  WmText.TextSize = Library.FontSize
  WmText.TextXAlignment = Enum.TextXAlignment.Left
  local _wmFps, _wmFrames, _wmAccum = 60, 0, 0
  local _wmLastEnabled = false
  local _wmConn = nil
  
  local function startFpsCounter()
      if _wmConn then return end
      _wmConn = RunService.Heartbeat:Connect(function(dt)
          if not flag("wm_en", true) then return end
          _wmFrames = _wmFrames + 1
          _wmAccum = _wmAccum + dt
          if _wmAccum >= 0.5 then
              _wmFps = math.floor(_wmFrames / _wmAccum + 0.5)
              _wmFrames, _wmAccum = 0, 0
          end
      end)
  end
  
  local function getPing()
      local ok, p = pcall(function() return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
      return ok and p or 0
  end
  local function fmtTime()
      local t = os.date("*t")
      return string.format("%02d:%02d:%02d", t.hour, t.min, t.sec)
  end
  local function applyWatermark()
      local enabled = flag("wm_en", true)
      if enabled and not _wmLastEnabled then
          startFpsCounter()
      end
      _wmLastEnabled = enabled
      Wm.Visible = enabled
      if not enabled then return end
      local fps = _wmFps or "--"
      local ping = getPing() or "--"
      
      WmText.RichText = true
      local ver = "live"
      local uid = _G._elocate_userid or "unknown"
      WmText.Text = string.format('<font color="#7c5cff">elocate.lol</font> | <font color="#7a7f8a">fps:</font> %s <font color="#7a7f8a">|</font> <font color="#7a7f8a">ping:</font> %s', fps, ping)
      WmText.TextColor3 = flag("wm_col", Color3.fromRGB(220,224,230))
      local scale = flag("wm_scale", 100) / 100
      WmText.TextSize = math.floor(Library.FontSize * scale)
      local h = math.floor(22 * scale)
      local needed = WmText.TextBounds.X
      if needed <= 0 then needed = 240 * scale end
      local w = math.max(140, math.floor(needed + 16))
      Wm.Size = UDim2.new(0, w, 0, h)
      WmAccent.BackgroundColor3 = Library.Accent or _AccentColor
      WmStroke.Enabled = flag("wm_out", true)
  end
  local Kb = Instance.new("Frame", _WidgetGui)
  Kb.Name = "KeybindList"
  Kb.Size = UDim2.new(0, 170, 0, 22)
  Kb.BackgroundColor3 = Color3.fromRGB(22, 16, 32)
  Kb.BorderColor3 = Color3.fromRGB(60, 45, 85)
  Kb.BorderSizePixel = 0
  local KbGrad = Instance.new("UIGradient", Kb)
  KbGrad.Rotation = 90
  KbGrad.Color = ColorSequence.new{
      ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 30, 60)),
      ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 16, 32))
  }
  local KbStroke = Instance.new("UIStroke", Kb); KbStroke.Color = Color3.fromRGB(80, 60, 110); KbStroke.Thickness = 1
  local KbAccent = Instance.new("Frame", Kb); KbAccent.Size = UDim2.new(1, 0, 0, 1); KbAccent.BackgroundColor3 = Color3.fromRGB(147,112,219); KbAccent.BorderSizePixel = 0
  local KbAccentGrad = Instance.new("UIGradient", KbAccent)
  KbAccentGrad.Color = ColorSequence.new{
      ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
      ColorSequenceKeypoint.new(0.5, Color3.fromRGB(147,112,219)),
      ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255))
  }
  KbAccentGrad.Transparency = NumberSequence.new{
      NumberSequenceKeypoint.new(0, 1),
      NumberSequenceKeypoint.new(0.5, 0),
      NumberSequenceKeypoint.new(1, 1)
  }
  local KbHeader = Instance.new("TextLabel", Kb)
  KbHeader.Position = UDim2.new(0, 6, 0, 2); KbHeader.Size = UDim2.new(1, -12, 0, 14); KbHeader.BackgroundTransparency = 1
  KbHeader.Text = "keybinds"; KbHeader.TextColor3 = Color3.fromRGB(147,112,219); KbHeader.FontFace = Library.UIFont; KbHeader.TextSize = Library.FontSize; KbHeader.TextXAlignment = Enum.TextXAlignment.Left
  local KbBody = Instance.new("Frame", Kb)
  KbBody.Position = UDim2.new(0, 6, 0, 18); KbBody.Size = UDim2.new(1, -12, 1, -22); KbBody.BackgroundTransparency = 1
  local KbLayout = Instance.new("UIListLayout", KbBody); KbLayout.SortOrder = Enum.SortOrder.LayoutOrder; KbLayout.Padding = UDim.new(0, 1)
  local _trackedBinds = {
      { "aimbot toggle", "kb_aim_toggle" },
      { "silent aim",    "sa_key"        },
      { "menu",          "ui_menukey"    },
      { "panic",         "ui_panickey"   },
  }
  local _measureLabel = Instance.new("TextLabel")
  _measureLabel.Name = "_kb_measure"
  _measureLabel.Visible = false
  _measureLabel.RichText = false
  _measureLabel.FontFace = Library.UIFont
  _measureLabel.TextSize = Library.FontSize
  _measureLabel.Parent = _WidgetGui
  local function _measureText(plain)
      _measureLabel.Text = plain
      return _measureLabel.TextBounds.X
  end
  local function applyKeybindList()
      local enabled = flag("kb_en", true)
      Kb.Visible = enabled
      if not enabled then return end
      for _, c in ipairs(KbBody:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
      KbAccent.BackgroundColor3 = Library.Accent or _AccentColor
      KbHeader.TextColor3 = flag("kb_col", Library.Accent or _AccentColor)
      local accent = Library.Accent or _AccentColor
      local hex = string.format("%02x%02x%02x", math.floor(accent.R*255), math.floor(accent.G*255), math.floor(accent.B*255))
      local count = 0
      local maxW = _measureText("keybinds")
      for i, b in ipairs(_trackedBinds) do
          local key  = flag(b[2] .. "_KEY", nil)
          local mode = flag(b[2] .. "_KEY STATE", "Hold")
          local keyName = (typeof(key) == "EnumItem") and key.Name or tostring(key or "")
          if keyName ~= "" and keyName ~= "Unknown" and keyName ~= "nil" then
              count = count + 1
              local plain = string.format("%s   [%s]   [%s]", b[1], tostring(mode):lower(), keyName)
              local w = _measureText(plain)
              if w > maxW then maxW = w end
              local row = Instance.new("TextLabel", KbBody)
              row.LayoutOrder = i
              row.Size = UDim2.new(1, 0, 0, 12)
              row.BackgroundTransparency = 1
              row.RichText = true
              row.Text = string.format("<font color=\"#dcdce6\">%s</font>   <font color=\"#7a7f8a\">[%s]</font>   <font color=\"#%s\">[%s]</font>", b[1], tostring(mode):lower(), hex, keyName)
              row.TextColor3 = Color3.fromRGB(220,224,230)
              row.FontFace = Library.UIFont
              row.TextSize = Library.FontSize
              row.TextXAlignment = Enum.TextXAlignment.Left
              row.TextTransparency = (Library.Open == false) and 0.95 or 0
          end
      end
      local desiredW = math.max(140, math.floor(maxW + 22))
      Kb.Size = UDim2.new(0, desiredW, 0, 22 + math.max(0, count) * 13)
  end
  local Pl = Instance.new("Frame", _WidgetGui)
  Pl.Name = "PlayerList"
  Pl.Size = UDim2.new(0, 220, 0, 24)
  Pl.BackgroundColor3 = Color3.fromRGB(22, 16, 32)
  Pl.BorderColor3 = Color3.fromRGB(60, 45, 85)
  Pl.BorderSizePixel = 0
  local PlGrad = Instance.new("UIGradient", Pl)
  PlGrad.Rotation = 90
  PlGrad.Color = ColorSequence.new{
      ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 30, 60)),
      ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 16, 32))
  }
  local PlStroke = Instance.new("UIStroke", Pl); PlStroke.Color = Color3.fromRGB(80, 60, 110); PlStroke.Thickness = 1
  local PlAccent = Instance.new("Frame", Pl); PlAccent.Size = UDim2.new(1, 0, 0, 1); PlAccent.BackgroundColor3 = Color3.fromRGB(147,112,219); PlAccent.BorderSizePixel = 0
  local PlAccentGrad = Instance.new("UIGradient", PlAccent)
  PlAccentGrad.Color = ColorSequence.new{
      ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
      ColorSequenceKeypoint.new(0.5, Color3.fromRGB(147,112,219)),
      ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255))
  }
  PlAccentGrad.Transparency = NumberSequence.new{
      NumberSequenceKeypoint.new(0, 1),
      NumberSequenceKeypoint.new(0.5, 0),
      NumberSequenceKeypoint.new(1, 1)
  }
  local PlHeader = Instance.new("TextLabel", Pl)
  PlHeader.Position = UDim2.new(0, 6, 0, 2); PlHeader.Size = UDim2.new(1, -12, 0, 14); PlHeader.BackgroundTransparency = 1
  PlHeader.Text = "players"; PlHeader.TextColor3 = Color3.fromRGB(147,112,219); PlHeader.FontFace = Library.UIFont; PlHeader.TextSize = Library.FontSize; PlHeader.TextXAlignment = Enum.TextXAlignment.Left
  local PlBody = Instance.new("ScrollingFrame", Pl)
  PlBody.Position = UDim2.new(0, 4, 0, 20); PlBody.Size = UDim2.new(1, -8, 1, -24); PlBody.BackgroundTransparency = 1; PlBody.BorderSizePixel = 0
  PlBody.ScrollBarThickness = 2; PlBody.ScrollBarImageColor3 = Color3.fromRGB(147,112,219); PlBody.CanvasSize = UDim2.new(0, 0, 0, 0)
  pcall(function() PlBody.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
  local PlLayout = Instance.new("UIListLayout", PlBody); PlLayout.SortOrder = Enum.SortOrder.LayoutOrder; PlLayout.Padding = UDim.new(0, 2)
  local _playerMenu
  local _avatarCache = {}
  local function getAvatar(userId)
      if _avatarCache[userId] then return _avatarCache[userId] end
      local ok, content = pcall(function()
          return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
      end)
      if ok then _avatarCache[userId] = content end
      return _avatarCache[userId]
  end
  local function teamColor(plr)
      if plr.Team and plr.TeamColor then return plr.TeamColor.Color end
      return Color3.fromRGB(158,163,173)
  end
  local _expandedUserId = nil
  local _rowByUserId = {}
  local function getHealthInfo(plr)
      local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
      if hum then
          return math.floor(hum.Health + 0.5), math.floor(hum.MaxHealth + 0.5), true
      end
      return 0, 100, false
  end
  local function buildRow(plr, index, parent)
      local row = Instance.new("TextButton", parent)
      row.Name = "PlayerRow_" .. plr.UserId
      row.LayoutOrder = index * 2
      row.Size = UDim2.new(1, 0, 0, 32)
      row.BackgroundColor3 = Color3.fromRGB(30, 22, 42)
      row.BackgroundTransparency = 1 
      row.BorderSizePixel = 0
      row.Text = ""
      row.AutoButtonColor = false
      local _rowHover = false
      row.MouseEnter:Connect(function() _rowHover = true; TweenService:Create(row, TweenInfo.new(0.12), {BackgroundTransparency = 0.05}):Play() end)
      row.MouseLeave:Connect(function() _rowHover = false; TweenService:Create(row, TweenInfo.new(0.12), {BackgroundTransparency = 0.4}):Play() end)
      row.MouseButton1Click:Connect(function()
          if _G._elocate_toggle_player_menu then
              _G._elocate_toggle_player_menu(plr)
          end
      end)
      _rowByUserId[plr.UserId] = row
      
      local stripe = Instance.new("Frame", row)
      stripe.Size = UDim2.new(0, 2, 1, 0); stripe.BorderSizePixel = 0
      stripe.BackgroundColor3 = (plr.Team and plr.TeamColor and plr.TeamColor.Color) or (Library.Accent or _AccentColor)
      stripe.BackgroundTransparency = 1
      
      local AVATAR_SIZE = 24
      local avFrame = Instance.new("Frame", row)
      avFrame.Position = UDim2.new(0, 6, 0.5, -AVATAR_SIZE/2)
      avFrame.Size = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE)
      avFrame.BackgroundColor3 = Color3.fromRGB(35, 26, 50)
      avFrame.BackgroundTransparency = 1
      avFrame.BorderSizePixel = 0
      local avImg = Instance.new("ImageLabel", avFrame)
      avImg.Size = UDim2.fromScale(1, 1)
      avImg.BackgroundTransparency = 1
      avImg.ImageTransparency = 1
      avImg.ScaleType = Enum.ScaleType.Crop
      task.spawn(function()
          local ok, content = pcall(function()
              return game:GetService("Players"):GetUserThumbnailAsync(
                  plr.UserId,
                  Enum.ThumbnailType.HeadShot,
                  Enum.ThumbnailSize.Size48x48
              )
          end)
          if ok and content and avImg.Parent then
              avImg.Image = content
              TweenService:Create(avImg, TweenInfo.new(0.25), {ImageTransparency = 0}):Play()
          end
      end)
      local avStroke = Instance.new("UIStroke", avFrame)
      avStroke.Color = (plr.Team and plr.TeamColor and plr.TeamColor.Color) or (Library.Accent or _AccentColor)
      avStroke.Thickness = 1
      avStroke.Transparency = 1
      
      local NUM_X = 6 + AVATAR_SIZE + 6
      local numLbl = Instance.new("TextLabel", row)
      numLbl.Position = UDim2.new(0, NUM_X, 0, 0); numLbl.Size = UDim2.new(0, 22, 1, 0)
      numLbl.BackgroundTransparency = 1
      numLbl.Text = string.format("%02d", index)
      numLbl.TextColor3 = Color3.fromRGB(122,127,138)
      numLbl.TextTransparency = 1
      numLbl.FontFace = Library.UIFont; numLbl.TextSize = Library.FontSize
      numLbl.TextXAlignment = Enum.TextXAlignment.Left
      
      local NAME_X = NUM_X + 22
      local name = Instance.new("TextLabel", row)
      name.Position = UDim2.new(0, NAME_X, 0, 3); name.Size = UDim2.new(1, -NAME_X - 70, 0, 13)
      name.BackgroundTransparency = 1
      name.Text = plr.DisplayName ~= plr.Name
          and (plr.DisplayName .. "  @" .. plr.Name) or plr.Name
      name.TextColor3 = (plr == game:GetService("Players").LocalPlayer)
          and (Library.Accent or _AccentColor) or Color3.fromRGB(220,224,230)
      name.TextTransparency = 1
      name.FontFace = Library.UIFont; name.TextSize = Library.FontSize
      name.TextXAlignment = Enum.TextXAlignment.Left
      name.TextTruncate = Enum.TextTruncate.AtEnd
      
      local hpLbl = Instance.new("TextLabel", row)
      hpLbl.Position = UDim2.new(0, NAME_X, 0, 17); hpLbl.Size = UDim2.new(1, -NAME_X - 70, 0, 11)
      hpLbl.BackgroundTransparency = 1
      hpLbl.TextColor3 = Color3.fromRGB(122,127,138)
      hpLbl.TextTransparency = 1
      hpLbl.FontFace = Library.UIFont; hpLbl.TextSize = Library.FontSize
      hpLbl.TextXAlignment = Enum.TextXAlignment.Left
      
      local barBg = Instance.new("Frame", row)
      barBg.AnchorPoint = Vector2.new(1, 0.5)
      barBg.Position = UDim2.new(1, -6, 0.5, 0)
      barBg.Size = UDim2.new(0, 60, 0, 6)
      barBg.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
      barBg.BackgroundTransparency = 1
      barBg.BorderSizePixel = 0
      local barFill = Instance.new("Frame", barBg)
      barFill.Size = UDim2.new(1, 0, 1, 0)
      barFill.BackgroundColor3 = Color3.fromRGB(120, 220, 120)
      barFill.BackgroundTransparency = 1
      barFill.BorderSizePixel = 0
      local barGrad = Instance.new("UIGradient", barFill)
      barGrad.Rotation = 0
      barGrad.Color = ColorSequence.new{
          ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
          ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 80)),
          ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 220, 120))
      }
      local barStroke = Instance.new("UIStroke", barBg)
      barStroke.Color = Color3.fromRGB(0,0,0); barStroke.Thickness = 1; barStroke.Transparency = 1
      local function refresh()
          local hp, mhp, alive = getHealthInfo(plr)
          if alive then
              hpLbl.Text = string.format("hp %d / %d", hp, mhp)
              local frac = math.clamp(mhp > 0 and hp / mhp or 0, 0, 1)
              
              TweenService:Create(barFill, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {Size = UDim2.new(frac, 0, 1, 0)}):Play()
          else
              hpLbl.Text = "dead"
              TweenService:Create(barFill, TweenInfo.new(0.18), {Size = UDim2.new(0, 0, 1, 0)}):Play()
          end
      end
      refresh()
      local hbConn, frameCount = nil, 0
      hbConn = RunService.Heartbeat:Connect(function()
          if not row.Parent then hbConn:Disconnect(); return end
          frameCount = frameCount + 1
          if frameCount % 10 == 0 then refresh() end -- Only update every 10th frame
      end)
      
      task.delay(math.min(index, 12) * 0.025, function()
          if not row.Parent then return end
          local ti = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
          TweenService:Create(row,       ti, {BackgroundTransparency = 0.4}):Play()
          TweenService:Create(stripe,    ti, {BackgroundTransparency = 0}):Play()
          TweenService:Create(avFrame,   ti, {BackgroundTransparency = 0}):Play()
          TweenService:Create(avStroke,  ti, {Transparency = 0.3}):Play()
          TweenService:Create(numLbl,    ti, {TextTransparency = 0}):Play()
          TweenService:Create(name,      ti, {TextTransparency = 0}):Play()
          TweenService:Create(hpLbl,     ti, {TextTransparency = 0}):Play()
          TweenService:Create(barBg,     ti, {BackgroundTransparency = 0}):Play()
          TweenService:Create(barFill,   ti, {BackgroundTransparency = 0}):Play()
          TweenService:Create(barStroke, ti, {Transparency = 0.4}):Play()
      end)
      return row
  end
  local function destroyExpansion()
      for _, c in ipairs(PlBody:GetChildren()) do
          if c:IsA("GuiObject") and tostring(c.Name):sub(1, 9) == "Expansion" then c:Destroy() end
      end
  end
  local function buildExpansion(plr, index)
      destroyExpansion()
      local exp = Instance.new("Frame", PlBody)
      exp.Name = "Expansion_" .. plr.UserId
      exp.LayoutOrder = index * 2 + 1
      exp.Size = UDim2.new(1, 0, 0, 96)
      exp.BackgroundColor3 = Color3.fromRGB(8, 10, 14)
      exp.BackgroundTransparency = 0.05
      exp.BorderSizePixel = 0
      local stroke = Instance.new("UIStroke", exp)
      stroke.Color = Color3.fromRGB(28,32,40); stroke.Thickness = 1
      local accentBar = Instance.new("Frame", exp)
      accentBar.Size = UDim2.new(1, 0, 0, 1); accentBar.BorderSizePixel = 0
      accentBar.BackgroundColor3 = Library.Accent or _AccentColor
      local av = Instance.new("ImageLabel", exp)
      av.Position = UDim2.new(0, 6, 0, 6)
      av.Size = UDim2.new(0, 38, 0, 38)
      av.BackgroundColor3 = Color3.fromRGB(28,32,40)
      av.BorderSizePixel = 0
      av.ScaleType = Enum.ScaleType.Crop
      av.ImageTransparency = 1
      task.spawn(function()
          local ok, content = pcall(function()
              return Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
          end)
          if ok and content and av.Parent then
              av.Image = content
              TweenService:Create(av, TweenInfo.new(0.3), {ImageTransparency = 0}):Play()
          end
      end)
      local function lbl(text, x, y, w, col, big)
          local l = Instance.new("TextLabel", exp)
          l.BackgroundTransparency = 1
          l.Position = UDim2.new(0, x, 0, y)
          l.Size = UDim2.new(0, w, 0, big and 14 or 12)
          l.Text = text
          l.TextColor3 = col or Color3.fromRGB(220,224,230)
          l.FontFace = Library.UIFont
          l.TextSize = big and (Library.FontSize + 1) or Library.FontSize
          l.TextXAlignment = Enum.TextXAlignment.Left
          l.RichText = true
          return l
      end
      local infoX = 50
      local infoW = math.max(120, Pl.AbsoluteSize.X - infoX - 16)
      lbl("<b>" .. (plr.DisplayName or plr.Name) .. "</b>", infoX, 6, infoW, Color3.fromRGB(220,224,230), true)
      lbl("@" .. plr.Name, infoX, 20, infoW, Color3.fromRGB(122,127,138))
      lbl("id " .. plr.UserId .. "   age " .. tostring(plr.AccountAge or 0) .. "d   " .. (plr.Team and ("team: " .. plr.Team.Name) or "no team"),
          infoX, 32, infoW, Color3.fromRGB(122,127,138))
      local function btn(text, x, y, w, callback)
          local b = Instance.new("TextButton", exp)
          b.Position = UDim2.new(0, x, 0, y)
          b.Size = UDim2.new(0, w, 0, 18)
          b.BackgroundColor3 = Color3.fromRGB(22, 25, 32)
          b.BorderSizePixel = 0
          b.Text = text
          b.TextColor3 = Color3.fromRGB(220,224,230)
          b.FontFace = Library.UIFont
          b.TextSize = Library.FontSize
          b.AutoButtonColor = false
          local bs = Instance.new("UIStroke", b)
          bs.Color = Color3.fromRGB(28,32,40); bs.Thickness = 1
          b.MouseEnter:Connect(function() b.BackgroundColor3 = Color3.fromRGB(30, 34, 44) end)
          b.MouseLeave:Connect(function() b.BackgroundColor3 = Color3.fromRGB(22, 25, 32) end)
          b.MouseButton1Click:Connect(function() pcall(callback) end)
          return b
      end
      local btnY = 50
      local cw = math.floor((Pl.AbsoluteSize.X - 8 - 8 - 6) / 2)
      if cw < 60 then cw = 100 end
      btn("teleport", 8, btnY, cw, function()
          local lc = _LP and _LP.Character
          local pc = plr and plr.Character
          local lhrp = lc and lc:FindFirstChild("HumanoidRootPart")
          local phrp = pc and pc:FindFirstChild("HumanoidRootPart")
          if lhrp and phrp then
              lhrp.CFrame = phrp.CFrame * CFrame.new(0, 0, -3)
              notify("teleported to " .. plr.Name, 1.5, "good")
          else
              notify("no character found", 1.5, "warn")
          end
      end)
      btn("spectate", 8 + cw + 6, btnY, cw, function()
          local cam = workspace.CurrentCamera
          if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then
              cam.CameraSubject = plr.Character:FindFirstChildOfClass("Humanoid")
              notify("spectating " .. plr.Name, 1.5, "good")
          else
              notify("no humanoid", 1.5, "warn")
          end
      end)
      btn("copy name", 8, btnY + 22, cw, function()
          if typeof(setclipboard) == "function" then
              setclipboard(plr.Name); notify("copied @" .. plr.Name, 1.5, "good")
          else notify("clipboard unavailable", 1.5, "warn") end
      end)
      btn("copy id", 8 + cw + 6, btnY + 22, cw, function()
          if typeof(setclipboard) == "function" then
              setclipboard(tostring(plr.UserId)); notify("copied id " .. plr.UserId, 1.5, "good")
          else notify("clipboard unavailable", 1.5, "warn") end
      end)
      return exp
  end
  local function applyPlayerList()
      
      
      local uiOpen = (Library.Holder and Library.Holder.Visible) and true or false
      local plEnabled = flag("pl_en", true) and uiOpen
      Pl.Visible = plEnabled
      destroyExpansion()
      for _, c in ipairs(PlBody:GetChildren()) do
          if c:IsA("GuiObject") then c:Destroy() end
      end
      table.clear(_rowByUserId)
      PlAccent.BackgroundColor3 = Library.Accent or _AccentColor
      local count = 0
      local plrs = Players:GetPlayers()
      table.sort(plrs, function(a, b) return tostring(a.Name):lower() < tostring(b.Name):lower() end)
      local foundExpanded = false
      for i, plr in ipairs(plrs) do
          count = count + 1
          buildRow(plr, i, PlBody)
          if _expandedUserId == plr.UserId then
              buildExpansion(plr, i)
              foundExpanded = true
          end
      end
      if not foundExpanded then _expandedUserId = nil end
      local desiredW = 280
      local rowsH = math.min(10, count) * 32
      local extraH = foundExpanded and 100 or 0
      local desiredH = 24 + rowsH + extraH + 4
      Pl.Size = UDim2.new(0, desiredW, 0, desiredH)
  end
  Players.PlayerAdded:Connect(function() task.wait(0.1); pcall(applyPlayerList);
end)
  Players.PlayerRemoving:Connect(function() task.wait(0.1); pcall(applyPlayerList);
end)
  local THEME_PRESETS = {
      ["Default"] = {
          accent   = Color3.fromRGB(76, 162, 252),
          mainBg   = Color3.fromRGB(11, 12, 15),
          mainText = Color3.fromRGB(220, 224, 230),
          wmCol    = Color3.fromRGB(220, 224, 230),
          kbCol    = Color3.fromRGB(76, 162, 252),
          plCol    = Color3.fromRGB(76, 162, 252),
          notifCol = Color3.fromRGB(76, 162, 252),
      },
      ["Ocean"] = {
          accent   = Color3.fromRGB(64, 220, 240),
          mainBg   = Color3.fromRGB( 8, 14, 22),
          mainText = Color3.fromRGB(210, 230, 240),
          wmCol    = Color3.fromRGB(210, 230, 240),
          kbCol    = Color3.fromRGB(64, 220, 240),
          plCol    = Color3.fromRGB(64, 220, 240),
          notifCol = Color3.fromRGB(64, 220, 240),
      },
      ["Blood"] = {
          accent   = Color3.fromRGB(220, 40, 60),
          mainBg   = Color3.fromRGB(18,  6,  8),
          mainText = Color3.fromRGB(240, 220, 220),
          wmCol    = Color3.fromRGB(240, 220, 220),
          kbCol    = Color3.fromRGB(220, 40, 60),
          plCol    = Color3.fromRGB(220, 40, 60),
          notifCol = Color3.fromRGB(220, 40, 60),
      },
      ["Midnight"] = {
          accent   = Color3.fromRGB(140, 110, 255),
          mainBg   = Color3.fromRGB(10, 10, 16),
          mainText = Color3.fromRGB(220, 220, 235),
          wmCol    = Color3.fromRGB(220, 220, 235),
          kbCol    = Color3.fromRGB(140, 110, 255),
          plCol    = Color3.fromRGB(140, 110, 255),
          notifCol = Color3.fromRGB(140, 110, 255),
      },
      ["Sunset"] = {
          accent   = Color3.fromRGB(255, 140, 60),
          mainBg   = Color3.fromRGB(20, 12, 10),
          mainText = Color3.fromRGB(245, 230, 220),
          wmCol    = Color3.fromRGB(245, 230, 220),
          kbCol    = Color3.fromRGB(255, 140, 60),
          plCol    = Color3.fromRGB(255, 140, 60),
          notifCol = Color3.fromRGB(255, 140, 60),
      },
      ["Emerald"] = {
          accent   = Color3.fromRGB(60, 220, 130),
          mainBg   = Color3.fromRGB(8, 16, 12),
          mainText = Color3.fromRGB(220, 240, 225),
          wmCol    = Color3.fromRGB(220, 240, 225),
          kbCol    = Color3.fromRGB(60, 220, 130),
          plCol    = Color3.fromRGB(60, 220, 130),
          notifCol = Color3.fromRGB(60, 220, 130),
      },
      ["Aurora"] = {
          accent   = Color3.fromRGB(120, 200, 255),
          mainBg   = Color3.fromRGB(10, 14, 22),
          mainText = Color3.fromRGB(220, 235, 250),
          wmCol    = Color3.fromRGB(220, 235, 250),
          kbCol    = Color3.fromRGB(120, 200, 255),
          plCol    = Color3.fromRGB(170, 130, 255),
          notifCol = Color3.fromRGB(120, 200, 255),
      },
      ["Crimson"] = {
          accent   = Color3.fromRGB(255, 70, 90),
          mainBg   = Color3.fromRGB(15, 8, 10),
          mainText = Color3.fromRGB(245, 225, 225),
          wmCol    = Color3.fromRGB(245, 225, 225),
          kbCol    = Color3.fromRGB(255, 70, 90),
          plCol    = Color3.fromRGB(255, 70, 90),
          notifCol = Color3.fromRGB(255, 70, 90),
      },
      ["Abyss"] = {
          accent   = Color3.fromRGB(80, 90, 200),
          mainBg   = Color3.fromRGB(4, 5, 10),
          mainText = Color3.fromRGB(200, 210, 230),
          wmCol    = Color3.fromRGB(200, 210, 230),
          kbCol    = Color3.fromRGB(80, 90, 200),
          plCol    = Color3.fromRGB(80, 90, 200),
          notifCol = Color3.fromRGB(80, 90, 200),
      },
  }
  local _lastThemePreset = nil
  local _rgbT = 0
  local function setFlag(name, value)
      local f = Library.Flags and Library.Flags[name]
      if typeof(f) == "table" and f.Set then
          pcall(function() f:Set(value) end)
      else
          if Library.Flags then Library.Flags[name] = value end
      end
  end
  local function applyMainBgAndText()
      if not Library.Holder then return end
      local bg     = flag("ui_bg",   Color3.fromRGB(11,12,15))
      local txt    = flag("ui_text", Color3.fromRGB(220,224,230))
      local bgDeep = Color3.new(math.max(0, bg.R - 0.015), math.max(0, bg.G - 0.015), math.max(0, bg.B - 0.015))
      local bgLite = Color3.new(math.min(1, bg.R + 0.012), math.min(1, bg.G + 0.012), math.min(1, bg.B + 0.012))
      Library.Holder.BackgroundColor3 = bg
      for _, d in ipairs(Library.Holder:GetDescendants()) do
          if d:IsA("Frame") then
              if d.Name == "Main" or d.Name == "Inline" or d.Name == "Outline" then
                  d.BackgroundColor3 = bg
              elseif d.Name == "Middle" or d.Name == "Bottom" or d.Name == "Top" then
                  d.BackgroundColor3 = bgDeep
              elseif d.Name == "Sections" or d.Name == "Bar" or d.Name == "Bar2" or d.Name == "Button" then
                  d.BackgroundColor3 = bgLite
              end
          elseif d:IsA("TextLabel") then
              local skip = d.Name == "Title" or d.Name == "LeftTitle" or d.Name == "RightTitle" or d.Name == "Value" or d.Name == "Mode" or d.Name == "version"
              if (not skip) and d.TextColor3 ~= Library.Accent then
                  d.TextColor3 = txt
              end
          end
      end
  end
  local function applyThemeAndRgb(dt)
      if flag("ui_accent_rgb", false) then
          local speed = flag("ui_accent_rgb_speed", 5)
          _rgbT = (_rgbT + dt * speed * 0.05) % 1
          local c = Color3.fromHSV(_rgbT, 0.85, 1)
          _AccentColor = c
          pcall(function() Library:ChangeAccent(c) end)
      else
          local preset = flag("ui_theme", "Default")
          if preset ~= _lastThemePreset and THEME_PRESETS[preset] then
              _lastThemePreset = preset
              local p = THEME_PRESETS[preset]
              _AccentColor = p.accent
              pcall(function() Library:ChangeAccent(p.accent) end)
              setFlag("ui_accent", p.accent)
              setFlag("ui_bg",     p.mainBg)
              setFlag("ui_text",   p.mainText)
              setFlag("wm_col",    p.wmCol)
              setFlag("kb_col",    p.kbCol)
              setFlag("pl_col",    p.plCol)
              setFlag("notif_col", p.notifCol)
              notify("theme: " .. preset, 1.5, "good")
          end
      end
      pcall(applyMainBgAndText)
      pcall(function()
          local bg = flag("ui_bg", Color3.fromRGB(11,12,15))
          local accent = Library.Accent or _AccentColor
          if Wm then Wm.BackgroundColor3 = bg end
          if Kb then Kb.BackgroundColor3 = bg end
          if Pl then Pl.BackgroundColor3 = bg end
          if WmAccent then WmAccent.BackgroundColor3 = accent end
          if KbAccent then KbAccent.BackgroundColor3 = accent end
          if PlAccent then PlAccent.BackgroundColor3 = accent end
          if PlBody and PlBody:IsA("ScrollingFrame") then PlBody.ScrollBarImageColor3 = accent end
          
          if Library.TopBgGrad then
              Library.TopBgGrad.Color = ColorSequence.new{
                  ColorSequenceKeypoint.new(0, accent),
                  ColorSequenceKeypoint.new(1, bg),
              }
          end
          
          if Library.TabGlows then
              for _, glow in ipairs(Library.TabGlows) do
                  if glow and glow.Visible then glow.BackgroundColor3 = accent end
              end
          end
          if Library.TabBgGrads then
              for _, g in ipairs(Library.TabBgGrads) do
                  if g then
                      g.Color = ColorSequence.new{
                          ColorSequenceKeypoint.new(0, accent),
                          ColorSequenceKeypoint.new(1, bg),
                      }
                  end
              end
          end
          
          
          
          if WmAccentGrad then
              WmAccentGrad.Color = ColorSequence.new{
                  ColorSequenceKeypoint.new(0,    Color3.fromRGB(255,255,255)),
                  ColorSequenceKeypoint.new(0.5,  accent),
                  ColorSequenceKeypoint.new(1,    Color3.fromRGB(255,255,255))
              }
          end
          if KbAccentGrad then
              KbAccentGrad.Color = ColorSequence.new{
                  ColorSequenceKeypoint.new(0,    Color3.fromRGB(255,255,255)),
                  ColorSequenceKeypoint.new(0.5,  accent),
                  ColorSequenceKeypoint.new(1,    Color3.fromRGB(255,255,255))
              }
          end
          if PlAccentGrad then
              PlAccentGrad.Color = ColorSequence.new{
                  ColorSequenceKeypoint.new(0,    Color3.fromRGB(255,255,255)),
                  ColorSequenceKeypoint.new(0.5,  accent),
                  ColorSequenceKeypoint.new(1,    Color3.fromRGB(255,255,255))
              }
          end
          
          
          local bgTop = Color3.new(math.min(1, bg.R + 0.07), math.min(1, bg.G + 0.07), math.min(1, bg.B + 0.07))
          local function syncBodyGrad(grad)
              if grad then
                  grad.Color = ColorSequence.new{
                      ColorSequenceKeypoint.new(0, bgTop),
                      ColorSequenceKeypoint.new(1, bg),
                  }
              end
          end
          syncBodyGrad(WmGrad)
          syncBodyGrad(KbGrad)
          syncBodyGrad(PlGrad)
      end)
  end
  
  -- Simple String-Based Config System (Copy/Paste)
  local HttpService = game:GetService("HttpService")
  
  -- Serialize all flags to a compact string
  local function serializeConfig()
      local data = {}
      for k, v in pairs(Library.Flags) do
          local t = type(v)
          if t == "string" then
              data[k] = "S:" .. v
          elseif t == "number" then
              data[k] = "N:" .. tostring(v)
          elseif t == "boolean" then
              data[k] = "B:" .. (v and "1" or "0")
          elseif t == "userdata" and typeof(v) == "Color3" then
              data[k] = string.format("C:%.4f,%.4f,%.4f", v.R, v.G, v.B)
          elseif t == "table" then
              -- Simple table as JSON
              local ok, json = pcall(HttpService.JSONEncode, HttpService, v)
              if ok then
                  data[k] = "T:" .. json
              end
          end
      end
      
      -- Convert to JSON and base64 encode
      local ok, json = pcall(HttpService.JSONEncode, HttpService, data)
      if not ok then return "" end
      
      -- Simple base64 encode
      local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
      local function base64encode(data)
          return ((data:gsub('.', function(x) 
              local r, b = '', x:byte()
              for i = 8, 1, -1 do r = r .. (b % 2^i - b % 2^(i-1) > 0 and '1' or '0') end
              return r
          end) .. '0000'):gsub('%d%d%d%d%d%d', function(x)
              if (#x < 6) then return '' end
              local c = 0
              for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2^(6-i) or 0) end
              return b64chars:sub(c + 1, c + 1)
          end) .. ({ '', '==', '=' })[#data % 3 + 1])
      end
      
      return base64encode(json)
  end
  
  -- Deserialize config from string
  local function deserializeConfig(str)
      if not str or str == "" then return false end
      
      -- Simple base64 decode
      local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
      local function base64decode(data)
          data = string.gsub(data, '[^' .. b64chars .. '=]', '')
          return (data:gsub('.', function(x)
              if x == '=' then return '' end
              local r, f = '', (b64chars:find(x) - 1)
              for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end
              return r
          end):gsub('%d%d%d%d%d%d%d%d', function(x)
              local c = 0
              for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2^(8-i) or 0) end
              return string.char(c)
          end))
      end
      
      local ok, json = pcall(base64decode, str)
      if not ok then return false end
      
      local ok2, data = pcall(HttpService.JSONDecode, HttpService, json)
      if not ok2 or not data then return false end
      
      -- Apply to flags
      for k, v in pairs(data) do
          if Library.Flags[k] ~= nil then
              local prefix = v:sub(1, 2)
              local val = v:sub(3)
              
              if prefix == "S:" then
                  Library.Flags[k] = val
              elseif prefix == "N:" then
                  Library.Flags[k] = tonumber(val)
              elseif prefix == "B:" then
                  Library.Flags[k] = (val == "1")
              elseif prefix == "C:" then
                  local r, g, b = val:match("([%d%.]+),([%d%.]+),([%d%.]+)")
                  if r and g and b then
                      Library.Flags[k] = Color3.new(tonumber(r), tonumber(g), tonumber(b))
                  end
              elseif prefix == "T:" then
                  local ok3, tbl = pcall(HttpService.JSONDecode, HttpService, val)
                  if ok3 then Library.Flags[k] = tbl end
              end
          end
      end
      
      return true
  end
  
  -- Get current config string for UI
  local function getConfigString()
      return serializeConfig()
  end
  
  -- Export to clipboard
  local function exportConfig()
      local str = serializeConfig()
      if str == "" then
          notify("failed to serialize config", 3, "error")
          return
      end
      
      if typeof(setclipboard) == "function" then
          pcall(setclipboard, str)
          notify("config copied to clipboard!", 3, "good")
      elseif typeof(toclipboard) == "function" then
          pcall(toclipboard, str)
          notify("config copied to clipboard!", 3, "good")
      else
          notify("clipboard not available - check _G._elocate_export_string", 5, "warn")
          _G._elocate_export_string = str
      end
  end
  
  -- Import from string
  local function importConfig(str)
      if not str or str == "" then
          notify("empty config string", 3, "error")
          return false
      end
      
      if deserializeConfig(str) then
          notify("config loaded!", 3, "good")
          return true
      else
          notify("invalid config string", 3, "error")
          return false
      end
  end
  
  -- Reset to defaults
  local function resetConfig()
      for k, v in pairs(Library.DefaultFlags or {}) do
          Library.Flags[k] = v
      end
      notify("reset to defaults", 3, "warn")
  end
  
  do
      if _LP then
          _LP.Idled:Connect(function()
              if flag("sys_afk", false) then
                  local VirtualUser = game:GetService("VirtualUser")
                  pcall(function()
                      VirtualUser:CaptureController()
                      VirtualUser:ClickButton2(Vector2.new())
                  end)
              end
          end)
      end
  end
  
  
  local _fpsTimer = 0
  local function applyFpsUnlock(dt)
      _fpsTimer = (_fpsTimer or 0) + (dt or 0)
      if _fpsTimer < 2 then return end
      _fpsTimer = 0
      pcall(function() if typeof(setfpscap) == "function" then setfpscap(99999) end end)
      pcall(function()
          local s = settings():GetService("RenderSettings")
          if s and s.Framerate ~= nil then s.Framerate = 240 end
      end)
  end
  pcall(function() if typeof(setfpscap) == "function" then setfpscap(99999) end end)
  local Lighting = game:GetService("Lighting")
  local _blur = Instance.new("BlurEffect")
  _blur.Size = 0
  _blur.Name = "_elocate_blur"
  _blur.Enabled = false
  _blur.Parent = Lighting
  
  
  
  
  
  local Workspace = game:GetService("Workspace")
  local Camera    = Workspace.CurrentCamera
  
  local function getChar()
      local c = _LP and _LP.Character
      if not c then return nil end
      return c, c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildOfClass("Humanoid")
  end
  
  local _origWS, _origJP = nil, nil
  local _dhDetected = false  
  local _macroActive = false
  local _macroLastTick = 0
  
  local _lastSpeed, _lastJump, _lastGrav
  local function applyMovement(dt)
      local _, hrp, hum = getChar()
      if hum then
          local macroEnabled = flag("mv_macro_en", false)
          local macroKey = Library.Flags["kb_macro_KEY"]
          local isMacroKeyDown = macroKey and (macroKey ~= Enum.KeyCode.Unknown) and game:GetService("UserInputService"):IsKeyDown(macroKey) or false
          
          if macroEnabled and isMacroKeyDown then
              local tick = os.clock()
              if tick - _macroLastTick > 0.05 then
                  _macroActive = not _macroActive
                  _macroLastTick = tick
              end
              local macroSpeed = flag("mv_macro_v", 120)
              hum.WalkSpeed = _macroActive and macroSpeed or 16
              _lastSpeed = hum.WalkSpeed
          elseif flag("mv_ws_en", false) then
              local targetSpeed = flag("mv_ws_v", 50)
              hum.WalkSpeed = targetSpeed
              _lastSpeed = targetSpeed
          elseif _origWS then
              hum.WalkSpeed = _origWS
              _lastSpeed = _origWS
          end
          if flag("mv_jp_en", false) then
              hum.UseJumpPower = true
              hum.JumpPower = flag("mv_jp_v", 50)
              _lastJump = flag("mv_jp_v", 50)
          elseif _origJP then
              hum.JumpPower = _origJP
              _lastJump = _origJP
          end
      end
      local grav = flag("mv_grav_en", false) and flag("mv_grav_v", 60) or 196.2
      if _lastGrav ~= grav then
          Workspace.Gravity = grav
          _lastGrav = grav
      end
      
      if flag("mv_noclip", false) then
          local c = _LP and _LP.Character
          if c then
              for _, p in ipairs(c:GetDescendants()) do
                  if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
              end
          end
      end
  end
  if _LP then
      _LP.CharacterAdded:Connect(function(c)
          local h = c:WaitForChild("Humanoid", 5)
          if h then _origWS = h.WalkSpeed; _origJP = h.JumpPower end
      end)
      if _LP.Character then
          local h = _LP.Character:FindFirstChildOfClass("Humanoid")
          if h then _origWS = h.WalkSpeed; _origJP = h.JumpPower end
      end
  end
  
  UIS_RUNTIME.JumpRequest:Connect(function()
      if not flag("mv_infjump", false) then return end
      local _, _, hum = getChar()
      if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
  end)
  
  local _flyBV, _flyBG = nil, nil
  local _flyKeys = { W = false, A = false, S = false, D = false, Space = false, LCtrl = false }
  UIS_RUNTIME.InputBegan:Connect(function(input, gpe)
      if gpe then return end
      local k = input.KeyCode
      if     k == Enum.KeyCode.W           then _flyKeys.W = true
      elseif k == Enum.KeyCode.A           then _flyKeys.A = true
      elseif k == Enum.KeyCode.S           then _flyKeys.S = true
      elseif k == Enum.KeyCode.D           then _flyKeys.D = true
      elseif k == Enum.KeyCode.Space       then _flyKeys.Space = true
      elseif k == Enum.KeyCode.LeftControl then _flyKeys.LCtrl = true
      end
  end)
  UIS_RUNTIME.InputEnded:Connect(function(input)
      local k = input.KeyCode
      if     k == Enum.KeyCode.W           then _flyKeys.W = false
      elseif k == Enum.KeyCode.A           then _flyKeys.A = false
      elseif k == Enum.KeyCode.S           then _flyKeys.S = false
      elseif k == Enum.KeyCode.D           then _flyKeys.D = false
      elseif k == Enum.KeyCode.Space       then _flyKeys.Space = false
      elseif k == Enum.KeyCode.LeftControl then _flyKeys.LCtrl = false
      end
  end)
  local function applyFly(dt)
      local _, hrp = getChar()
      if not hrp then
          if _flyBV then _flyBV:Destroy(); _flyBV = nil end
          if _flyBG then _flyBG:Destroy(); _flyBG = nil end
          return
      end
      if not flag("mv_fly_en", false) then
          if _flyBV then _flyBV:Destroy(); _flyBV = nil end
          if _flyBG then _flyBG:Destroy(); _flyBG = nil end
          return
      end
      if not _flyBV or _flyBV.Parent ~= hrp then
          if _flyBV then _flyBV:Destroy() end
          _flyBV = Instance.new("BodyVelocity", hrp)
          _flyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
          _flyBV.Velocity = Vector3.new()
      end
      if not _flyBG or _flyBG.Parent ~= hrp then
          if _flyBG then _flyBG:Destroy() end
          _flyBG = Instance.new("BodyGyro", hrp)
          _flyBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
          _flyBG.P = 9000
      end
      local cam = Workspace.CurrentCamera
      local move = Vector3.new()
      if _flyKeys.W     then move = move + cam.CFrame.LookVector end
      if _flyKeys.S     then move = move - cam.CFrame.LookVector end
      if _flyKeys.A     then move = move - cam.CFrame.RightVector end
      if _flyKeys.D     then move = move + cam.CFrame.RightVector end
      if _flyKeys.Space then move = move + Vector3.new(0, 1, 0) end
      if _flyKeys.LCtrl then move = move - Vector3.new(0, 1, 0) end
      if move.Magnitude > 0 then move = move.Unit end
      _flyBV.Velocity = move * (flag("mv_fly_v", 80))
      _flyBG.CFrame = cam.CFrame
  end
  
  local function applyCamera(dt)
      local cam = Workspace.CurrentCamera
      if not cam then return end
      if flag("cam_fov_en", false) then
          local target = flag("cam_fov_v", 90)
          cam.FieldOfView = cam.FieldOfView + (target - cam.FieldOfView) * math.clamp(dt * 8, 0, 1)
      end
  end
  
  local _origFogStart, _origFogEnd, _origFogColor, _origAmbient, _origBrightness, _origClock
  pcall(function()
      _origFogStart  = Lighting.FogStart
      _origFogEnd    = Lighting.FogEnd
      _origFogColor  = Lighting.FogColor
      _origAmbient   = Lighting.Ambient
      _origBrightness = Lighting.Brightness
      _origClock     = Lighting.ClockTime
  end)
  local _fogRgbT = 0
  local _L = {} -- lighting cache table (avoids local register limit)
  
  local _matOrig    = setmetatable({}, { __mode = "k" })
  local _matApplied = false
  local _matLast    = nil
  local function _enumMat(name)
      local ok, m = pcall(function() return Enum.Material[name] end)
      if ok and m then return m end
      return Enum.Material.Plastic
  end
  local _matColorOrig = setmetatable({}, { __mode = "k" })
  local _matColorOn   = false
  local _matColorLast = nil
  
  
  
  local function _isCharacterPart(inst)
      local m = inst:FindFirstAncestorOfClass("Model")
      while m do
          if m:FindFirstChildOfClass("Humanoid") then return true end
          m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model") or nil
      end
      return false
  end
  local function applyMaterialOverride(name, useColor, color)
      local mat = _enumMat(name)
      for _, inst in ipairs(Workspace:GetDescendants()) do
          if inst:IsA("BasePart") and not _isCharacterPart(inst) then
              if _matOrig[inst] == nil then _matOrig[inst] = inst.Material end
              pcall(function() inst.Material = mat end)
              if useColor then
                  if _matColorOrig[inst] == nil then _matColorOrig[inst] = inst.Color end
                  pcall(function() inst.Color = color end)
              end
          end
      end
      _matApplied = true
      _matLast    = name
      _matColorOn = useColor and true or false
      _matColorLast = color
  end
  local function restoreMaterials()
      for inst, mat in pairs(_matOrig) do
          if inst and inst.Parent then pcall(function() inst.Material = mat end) end
      end
      for inst, col in pairs(_matColorOrig) do
          if inst and inst.Parent then pcall(function() inst.Color = col end) end
      end
      _matOrig      = setmetatable({}, { __mode = "k" })
      _matColorOrig = setmetatable({}, { __mode = "k" })
      _matApplied   = false
      _matColorOn   = false
      _matLast      = nil
      _matColorLast = nil
  end
  
  local _lightOrig, _lightOrigProps
  pcall(function()
      _lightOrig = {
          ClockTime        = Lighting.ClockTime,
          Brightness       = Lighting.Brightness,
          Ambient          = Lighting.Ambient,
          OutdoorAmbient   = Lighting.OutdoorAmbient,
          ColorShift_Top   = Lighting.ColorShift_Top,
          ColorShift_Bottom= Lighting.ColorShift_Bottom,
          FogColor         = Lighting.FogColor,
          FogStart         = Lighting.FogStart,
          FogEnd           = Lighting.FogEnd,
      }
  end)
  local _lightLast = nil
  local LIGHT_PRESETS = {
      ["Default"] = nil, 
      ["Red Forest"]      = { Clock=16, Bright=1.5, Amb=Color3.fromRGB(180,50,30),   Out=Color3.fromRGB(200,70,50),   Top=Color3.fromRGB(255,100,50),   Bot=Color3.fromRGB(150,30,20),   Fog=Color3.fromRGB(180,50,30), FogS=100, FogE=500 },
      ["Purple Night"]    = { Clock=2,  Bright=0.8, Amb=Color3.fromRGB(80,40,120),  Out=Color3.fromRGB(100,60,140),  Top=Color3.fromRGB(120,60,180),   Bot=Color3.fromRGB(60,30,90),    Fog=Color3.fromRGB(80,40,120),  FogS=50,  FogE=300 },
      ["Blue Horror"]     = { Clock=0,  Bright=0.5, Amb=Color3.fromRGB(20,50,100),  Out=Color3.fromRGB(40,70,120),   Top=Color3.fromRGB(10,30,80),     Bot=Color3.fromRGB(30,60,110),   Fog=Color3.fromRGB(20,50,100),  FogS=0,   FogE=200 },
      ["Green Mist"]      = { Clock=12, Bright=1.2, Amb=Color3.fromRGB(50,150,80),  Out=Color3.fromRGB(70,170,100),  Top=Color3.fromRGB(30,120,60),     Bot=Color3.fromRGB(80,180,110),   Fog=Color3.fromRGB(50,150,80),  FogS=80,  FogE=400 },
      ["Orange Sunset"]   = { Clock=18, Bright=2,   Amb=Color3.fromRGB(255,150,50), Out=Color3.fromRGB(255,170,70),  Top=Color3.fromRGB(255,130,30),   Bot=Color3.fromRGB(255,180,80),  Fog=Color3.fromRGB(255,150,50), FogS=0,   FogE=600 },
      ["Pink Dawn"]       = { Clock=5,  Bright=1.8, Amb=Color3.fromRGB(255,180,200), Out=Color3.fromRGB(255,200,220), Top=Color3.fromRGB(255,150,180),  Bot=Color3.fromRGB(255,210,230), Fog=Color3.fromRGB(255,180,200), FogS=100, FogE=700 },
      ["Yellow Desert"]   = { Clock=14, Bright=3,   Amb=Color3.fromRGB(255,230,150), Out=Color3.fromRGB(255,240,170), Top=Color3.fromRGB(255,220,120),  Bot=Color3.fromRGB(255,235,160), Fog=Color3.fromRGB(255,230,150), FogS=200, FogE=1000 },
      ["Cyan Ice"]        = { Clock=10, Bright=2.5, Amb=Color3.fromRGB(150,220,255), Out=Color3.fromRGB(170,240,255), Top=Color3.fromRGB(120,200,255),  Bot=Color3.fromRGB(180,230,255), Fog=Color3.fromRGB(150,220,255), FogS=0,   FogE=800 },
      ["Dark Void"]       = { Clock=0,  Bright=0.2, Amb=Color3.fromRGB(10,10,20),   Out=Color3.fromRGB(15,15,25),    Top=Color3.fromRGB(5,5,15),       Bot=Color3.fromRGB(20,20,30),    Fog=Color3.fromRGB(10,10,20),   FogS=0,   FogE=100 },
      ["Blood Moon"]      = { Clock=22, Bright=1,   Amb=Color3.fromRGB(200,30,30),  Out=Color3.fromRGB(220,50,50),   Top=Color3.fromRGB(180,20,20),    Bot=Color3.fromRGB(230,60,60),   Fog=Color3.fromRGB(200,30,30),  FogS=0,   FogE=400 },
      ["Neon City"]       = { Clock=20, Bright=2.2, Amb=Color3.fromRGB(255,50,255), Out=Color3.fromRGB(255,70,255),  Top=Color3.fromRGB(255,30,255),   Bot=Color3.fromRGB(255,80,255),  Fog=Color3.fromRGB(255,50,255), FogS=50,  FogE=500 },
      ["Toxic Waste"]     = { Clock=14, Bright=1.5, Amb=Color3.fromRGB(150,255,50), Out=Color3.fromRGB(170,255,70),  Top=Color3.fromRGB(120,255,30),   Bot=Color3.fromRGB(180,255,80),  Fog=Color3.fromRGB(150,255,50), FogS=100, FogE=600 },
      ["Golden Hour"]     = { Clock=17, Bright=2.8, Amb=Color3.fromRGB(255,200,100), Out=Color3.fromRGB(255,210,120), Top=Color3.fromRGB(255,180,80),   Bot=Color3.fromRGB(255,220,140), Fog=Color3.fromRGB(255,200,100), FogS=0,   FogE=800 },
      ["Midnight Blue"]   = { Clock=0,  Bright=0.6, Amb=Color3.fromRGB(20,40,80),   Out=Color3.fromRGB(30,50,90),    Top=Color3.fromRGB(10,30,70),     Bot=Color3.fromRGB(40,60,100),   Fog=Color3.fromRGB(20,40,80),   FogS=0,   FogE=250 },
      ["Forest Green"]    = { Clock=12, Bright=1.8, Amb=Color3.fromRGB(50,120,50),  Out=Color3.fromRGB(70,140,70),   Top=Color3.fromRGB(30,90,30),     Bot=Color3.fromRGB(80,150,80),   Fog=Color3.fromRGB(50,120,50),  FogS=150, FogE=700 },
      ["Volcano"]         = { Clock=14, Bright=2.5, Amb=Color3.fromRGB(255,100,30), Out=Color3.fromRGB(255,120,50),  Top=Color3.fromRGB(255,80,20),     Bot=Color3.fromRGB(255,130,60),  Fog=Color3.fromRGB(255,100,30), FogS=0,   FogE=600 },
      ["Arctic"]          = { Clock=8,  Bright=2.2, Amb=Color3.fromRGB(200,230,255), Out=Color3.fromRGB(220,240,255), Top=Color3.fromRGB(180,220,250),  Bot=Color3.fromRGB(230,245,255), Fog=Color3.fromRGB(200,230,255), FogS=0,   FogE=900 },
      ["Swamp"]           = { Clock=16, Bright=1.2, Amb=Color3.fromRGB(80,120,60),  Out=Color3.fromRGB(100,140,80),  Top=Color3.fromRGB(60,100,40),    Bot=Color3.fromRGB(120,150,90),  Fog=Color3.fromRGB(80,120,60),  FogS=200, FogE=500 },
      ["Candy Land"]      = { Clock=14, Bright=3,   Amb=Color3.fromRGB(255,200,255), Out=Color3.fromRGB(255,220,255), Top=Color3.fromRGB(255,180,255),  Bot=Color3.fromRGB(255,230,255), Fog=Color3.fromRGB(255,200,255), FogS=0,   FogE=1000 },
  }
  local function applyLightingPreset(name)
      pcall(function()
          local p = LIGHT_PRESETS[name]
          if not p then return end
          Lighting.ClockTime         = p.Clock
          Lighting.Brightness        = p.Bright
          Lighting.Ambient           = p.Amb
          Lighting.OutdoorAmbient    = p.Out
          Lighting.ColorShift_Top    = p.Top
          Lighting.ColorShift_Bottom = p.Bot
          Lighting.FogColor          = p.Fog
          Lighting.FogStart          = p.FogS
          Lighting.FogEnd            = p.FogE
      end)
      _lightLast = name
  end
  local function restoreLighting()
      pcall(function()
          if _lightOrig then
              Lighting.ClockTime         = _lightOrig.ClockTime
              Lighting.Brightness        = _lightOrig.Brightness
              Lighting.Ambient           = _lightOrig.Ambient
              Lighting.OutdoorAmbient    = _lightOrig.OutdoorAmbient
              Lighting.ColorShift_Top    = _lightOrig.ColorShift_Top
              Lighting.ColorShift_Bottom = _lightOrig.ColorShift_Bottom
              Lighting.FogColor          = _lightOrig.FogColor
              Lighting.FogStart          = _lightOrig.FogStart
              Lighting.FogEnd            = _lightOrig.FogEnd
          end
      end)
      _lightLast = nil
  end
  
  pcall(function()
      Workspace.DescendantAdded:Connect(function(inst)
          if _matApplied and inst:IsA("BasePart") and not _isCharacterPart(inst) then
              if _matOrig[inst] == nil then _matOrig[inst] = inst.Material end
              local mat = _enumMat(_matLast or "Plastic")
              pcall(function() inst.Material = mat end)
              if _matColorOn and _matColorLast then
                  if _matColorOrig[inst] == nil then _matColorOrig[inst] = inst.Color end
                  pcall(function() inst.Color = _matColorLast end)
              end
          end
      end)
  end)
  local function applyWorld(dt)
      pcall(function()
          if flag("w_fog_off", false) then
              if _L.fs ~= 0 then Lighting.FogStart = 0; _L.fs = 0 end
              if _L.fe ~= 1e6 then Lighting.FogEnd = 1e6; _L.fe = 1e6 end
          else
              local fs = flag("w_fog_start", _origFogStart or 0)
              local fe = flag("w_fog_end",   _origFogEnd   or 1000)
              local col = flag("w_fog_col", _origFogColor or Color3.fromRGB(180,200,220))
              if flag("w_fog_rgb", false) then
                  _fogRgbT = (_fogRgbT + dt * (flag("w_fog_rgb_speed", 5) * 0.05)) % 1
                  col = Color3.fromHSV(_fogRgbT, 0.7, 1)
              end
              if _L.fs ~= fs then Lighting.FogStart = fs; _L.fs = fs end
              if _L.fe ~= fe then Lighting.FogEnd = fe; _L.fe = fe end
              if _L.fc ~= col then Lighting.FogColor = col; _L.fc = col end
          end
          if flag("w_amb_en", false) then
              local amb = flag("w_amb_col",    _origAmbient   or Color3.fromRGB(128,128,128))
              local bri = flag("w_amb_bright", _origBrightness or 2)
              local clk = flag("w_amb_time",   _origClock     or 14)
              if _L.ab ~= amb then Lighting.Ambient = amb; _L.ab = amb end
              if _L.br ~= bri then Lighting.Brightness = bri; _L.br = bri end
              if _L.cl ~= clk then Lighting.ClockTime = clk; _L.cl = clk end
          else
              if _origBrightness and _L.br ~= _origBrightness then Lighting.Brightness = _origBrightness; _L.br = _origBrightness end
              if _origClock and _L.cl ~= _origClock then Lighting.ClockTime = _origClock; _L.cl = _origClock end
          end
          local atm = Lighting:FindFirstChildOfClass("Atmosphere")
          if atm and flag("w_amb_en", false) then
              local dens = flag("w_atm_dens", 30) / 100
              local col = flag("w_atm_col", Color3.fromRGB(180,200,255))
              if _L.ad ~= dens then atm.Density = dens; _L.ad = dens end
              if _L.ac ~= col then atm.Color = col; _L.ac = col end
          end
          
          if flag("w_mat_en", false) then
              local sel    = flag("w_mat", "Plastic")
              local useCol = flag("w_mat_usecol", false) and true or false
              local col    = flag("w_mat_col", Color3.fromRGB(255,255,255))
              if (not _matApplied) or _matLast ~= sel or _matColorOn ~= useCol or _matColorLast ~= col then
                  applyMaterialOverride(sel, useCol, col)
              end
          elseif _matApplied then
              restoreMaterials()
          end
          
          if flag("w_light_preset_en", false) then
              local sel = flag("w_light_preset", "Default")
              if sel == "Default" then
                  if _lightLast ~= sel then restoreLighting(); _lightLast = sel end
              elseif _lightLast ~= sel then
                  applyLightingPreset(sel)
              end
          elseif _lightLast then
              restoreLighting()
          end
      end)
  end
  
  local _highlights = _G._elocate_chams_list or {}        
  _G._elocate_chams_list = _highlights
  local _toolHls    = _G._elocate_tool_hls_list or {}        
  _G._elocate_tool_hls_list = _toolHls
  local function clearHighlights()
      for plr, hl in pairs(_highlights) do
          if hl and hl.Parent then hl:Destroy() end
          _highlights[plr] = nil
      end
  end
  local function clearToolHls()
      for tool, hl in pairs(_toolHls) do
          if hl and hl.Parent then hl:Destroy() end
          _toolHls[tool] = nil
      end
  end
  local _chRgbT, _chTRgbT, _chOutRgbT, _chTOutRgbT = 0, 0, 0, 0
  
  local function _distToChar(other)
      local lpc = _LP and _LP.Character
      local lhrp = lpc and lpc:FindFirstChild("HumanoidRootPart")
      local ohrp = other and other:FindFirstChild("HumanoidRootPart")
      if not (lhrp and ohrp) then return math.huge end
      return (lhrp.Position - ohrp.Position).Magnitude
  end
  local function applyChams(dt)
      
      if not flag("ch_p_en", false) then
          clearHighlights()
      else
          local fill = flag("ch_p_fill", Color3.fromRGB(147,112,219))
          local out  = flag("ch_p_out",  Color3.fromRGB(0,0,0))
          if flag("ch_p_rgb", false) then
              _chRgbT = (_chRgbT + (dt or 0) * (flag("ch_p_rgb_speed", 5) * 0.05)) % 1
              fill = Color3.fromHSV(_chRgbT, 0.85, 1)
          end
          if flag("ch_p_out_rgb", false) then
              _chOutRgbT = (_chOutRgbT + (dt or 0) * (flag("ch_p_out_rgb_speed", 5) * 0.05)) % 1
              out = Color3.fromHSV(_chOutRgbT, 0.85, 1)
          end
          local includeSelf = flag("ch_p_self", false)
          local teamCheck   = flag("ch_p_team", false)
          local useTeamCol  = flag("ch_p_teamcol", false)
          local distEn      = flag("ch_p_dist_en", false)
          local distMax     = flag("ch_p_dist_max", 1000)
          for _, plr in ipairs(Players:GetPlayers()) do
              local skip = false
              if plr == _LP and not includeSelf then skip = true end
              if (not skip) and teamCheck and _LP and plr.Team and _LP.Team and plr.Team == _LP.Team then skip = true end
              if (not skip) and distEn and plr ~= _LP and _distToChar(plr.Character) > distMax then skip = true end
              if (not skip) and plr.Character then
                  local hl = _highlights[plr]
                  if not hl or not hl.Parent then
                      hl = Instance.new("Highlight")
                      hl.Name = "_elocate_hl"
                      hl.Adornee = plr.Character
                      hl.Parent = plr.Character
                      _highlights[plr] = hl
                  end
                  if hl.Adornee ~= plr.Character then hl.Adornee = plr.Character end
                  hl.FillColor = (useTeamCol and plr.Team and plr.TeamColor) and plr.TeamColor.Color or fill
                  hl.OutlineColor = out
                  hl.FillTransparency   = (flag("ch_p_fill_t", 50) / 100)
                  hl.OutlineTransparency= (flag("ch_p_out_t",  0)  / 100)
              elseif _highlights[plr] then
                  
                  _highlights[plr]:Destroy()
                  _highlights[plr] = nil
              end
          end
          for plr, hl in pairs(_highlights) do
              if (not plr.Parent) or (not plr.Character) then
                  if hl then hl:Destroy() end
                  _highlights[plr] = nil
              end
          end
      end
      
      if not flag("ch_t_en", false) then
          clearToolHls()
          return
      end
      local tfill = flag("ch_t_fill", Color3.fromRGB(147,112,219))
      local tout  = flag("ch_t_out",  Color3.fromRGB(0,0,0))
      if flag("ch_t_rgb", false) then
          _chTRgbT = (_chTRgbT + (dt or 0) * (flag("ch_t_rgb_speed", 5) * 0.05)) % 1
          tfill = Color3.fromHSV(_chTRgbT, 0.85, 1)
      end
      if flag("ch_t_out_rgb", false) then
          _chTOutRgbT = (_chTOutRgbT + (dt or 0) * (flag("ch_t_out_rgb_speed", 5) * 0.05)) % 1
          tout = Color3.fromHSV(_chTOutRgbT, 0.85, 1)
      end
      local tIncSelf   = flag("ch_t_self", true)
      local tIncOthers = flag("ch_t_others", false)
      local tIncBp     = flag("ch_t_backpack", true)
      local tDistEn    = flag("ch_t_dist_en", false)
      local tDistMax   = flag("ch_t_dist_max", 1000)
      local seen = {}
      local function _adornTool(tool)
          if not tool or not tool:IsA("Tool") then return end
          seen[tool] = true
          local hl = _toolHls[tool]
          if not hl or not hl.Parent then
              hl = Instance.new("Highlight")
              hl.Name = "_elocate_thl"
              hl.Adornee = tool
              hl.Parent  = tool
              _toolHls[tool] = hl
          end
          if hl.Adornee ~= tool then hl.Adornee = tool end
          hl.FillColor          = tfill
          hl.OutlineColor       = tout
          hl.FillTransparency   = (flag("ch_t_fill_t", 50) / 100)
          hl.OutlineTransparency= (flag("ch_t_out_t",  0)  / 100)
      end
      for _, plr in ipairs(Players:GetPlayers()) do
          if plr == _LP and not tIncSelf then
              
          elseif plr ~= _LP and not tIncOthers then
              
          elseif tDistEn and plr ~= _LP and _distToChar(plr.Character) > tDistMax then
              
          else
              local char = plr.Character
              if char then
                  -- Search recursively for tools in character (some games nest them deep)
                  local function scanForTools(parent)
                      for _, t in ipairs(parent:GetChildren()) do
                          if t:IsA("Tool") then 
                              _adornTool(t)
                          elseif t:IsA("Model") or t:IsA("Folder") or t:IsA("BasePart") then
                              scanForTools(t)
                          end
                      end
                  end
                  scanForTools(char)
              end
              if tIncBp then
                  local bp = plr:FindFirstChildOfClass("Backpack")
                  if bp then
                      for _, t in ipairs(bp:GetChildren()) do
                          if t:IsA("Tool") then _adornTool(t) end
                      end
                  end
              end
          end
      end
      for tool, hl in pairs(_toolHls) do
          if not seen[tool] or not tool.Parent then
              if hl then hl:Destroy() end
              _toolHls[tool] = nil
          end
      end
  end
  
  local _fovCircle, _fovCircleOK
  if typeof(Drawing) == "table" or typeof(Drawing) == "userdata" then
      local ok, c = pcall(function() return Drawing.new("Circle") end)
      if ok and c then
          _fovCircle = c
          _fovCircle.Visible = false
          _fovCircle.Thickness = 1
          _fovCircle.Filled = false
          _fovCircle.NumSides = 64
          _fovCircleOK = true
      end
  end
  
  local _lastGlobalNpc = false
  local _crossLines = {}
  local _crossLinesOut = {}
  local _crossDot = nil
  local _crossDotOut = nil
  if typeof(Drawing) == "table" or typeof(Drawing) == "userdata" then
      for i = 1, 4 do
          local ok, l = pcall(function() return Drawing.new("Line") end)
          if ok and l then
              l.Visible = false
              l.Thickness = 1
              l.Color = Color3.fromRGB(255,255,255)
              _crossLines[i] = l
          end
      end
      
      for i = 1, 4 do
          local ok, l = pcall(function() return Drawing.new("Line") end)
          if ok and l then
              l.Visible = false
              l.Thickness = 3
              l.Color = Color3.fromRGB(0,0,0)
              _crossLinesOut[i] = l
          end
      end
      
      local okDot, dot = pcall(function() return Drawing.new("Square") end)
      if okDot and dot then
          dot.Visible = false
          dot.Filled = true
          dot.Thickness = 0
          dot.Color = Color3.fromRGB(255,255,255)
          _crossDot = dot
      end
      
      local okDotOut, dotOut = pcall(function() return Drawing.new("Square") end)
      if okDotOut and dotOut then
          dotOut.Visible = false
          dotOut.Filled = true
          dotOut.Thickness = 0
          dotOut.Color = Color3.fromRGB(0,0,0)
          _crossDotOut = dotOut
      end
  end
  local function applyCrosshair()
      if #_crossLines < 4 then return end
      local on = flag("aim_crosshair", false)
      
      for i = 1, 4 do
          _crossLines[i].Visible = false
          if _crossLinesOut[i] then _crossLinesOut[i].Visible = false end
      end
      if _crossDot then _crossDot.Visible = false end
      if _crossDotOut then _crossDotOut.Visible = false end
      if not on then return end
      local vp = Camera.ViewportSize
      local cx, cy = vp.X / 2, vp.Y / 2
      local size = flag("aim_cross_size", 12)
      local gap  = flag("aim_cross_gap", 6)
      local col  = flag("aim_cross_col", Color3.fromRGB(255,255,255))
      local outCol = flag("aim_cross_out_col", Color3.fromRGB(0,0,0))
      local thick = flag("aim_cross_thick", 1)
      local useOut = flag("aim_cross_out", true)
      
      local segs = {
          { Vector2.new(cx, cy - gap - size), Vector2.new(cx, cy - gap) },
          { Vector2.new(cx, cy + gap),        Vector2.new(cx, cy + gap + size) },
          { Vector2.new(cx - gap - size, cy), Vector2.new(cx - gap, cy) },
          { Vector2.new(cx + gap, cy),        Vector2.new(cx + gap + size, cy) },
      }
      for i = 1, 4 do
          local l = _crossLines[i]
          l.From = segs[i][1]; l.To = segs[i][2]
          l.Color = col; l.Thickness = thick; l.Visible = true
          if useOut and _crossLinesOut[i] then
              local lo = _crossLinesOut[i]
              lo.From = segs[i][1]; lo.To = segs[i][2]
              lo.Color = outCol; lo.Thickness = thick + 2; lo.Visible = true
          end
      end
      
      if flag("aim_cross_dot", true) and _crossDot then
          local dotSize = flag("aim_cross_dot_size", 3)
          _crossDot.Size = Vector2.new(dotSize, dotSize)
          _crossDot.Position = Vector2.new(cx - dotSize/2, cy - dotSize/2)
          _crossDot.Color = col
          _crossDot.Visible = true
          if useOut and _crossDotOut then
              _crossDotOut.Size = Vector2.new(dotSize + 2, dotSize + 2)
              _crossDotOut.Position = Vector2.new(cx - (dotSize+2)/2, cy - (dotSize+2)/2)
              _crossDotOut.Color = outCol
              _crossDotOut.Visible = true
          end
      end
  end
  
  local _targetHud = {}
  local _targetHudEnabled = false
  if typeof(Drawing) == "table" or typeof(Drawing) == "userdata" then
      local ok1, bg  = pcall(function() return Drawing.new("Square") end)
      local ok2, nm  = pcall(function() return Drawing.new("Text") end)
      local ok3, hp  = pcall(function() return Drawing.new("Text") end)
      local ok4, bar = pcall(function() return Drawing.new("Square") end)
      local ok5, barFg = pcall(function() return Drawing.new("Square") end)
      if ok1 and bg then
          bg.Visible = false; bg.Filled = true; bg.Color = Color3.fromRGB(11,12,15); bg.Transparency = 0.25; bg.ZIndex = 10
          _targetHud.bg = bg
      end
      if ok2 and nm then
          nm.Visible = false; nm.Size = 14; nm.Center = false; nm.Outline = true; nm.Color = Color3.fromRGB(220,224,230); nm.ZIndex = 11
          _targetHud.name = nm
      end
      if ok3 and hp then
          hp.Visible = false; hp.Size = 12; hp.Center = false; hp.Outline = true; hp.Color = Color3.fromRGB(120,220,120); hp.ZIndex = 11
          _targetHud.hp = hp
      end
      if ok4 and bar then
          bar.Visible = false; bar.Filled = true; bar.Color = Color3.fromRGB(30,33,40); bar.ZIndex = 11
          _targetHud.bar = bar
      end
      if ok5 and barFg then
          barFg.Visible = false; barFg.Filled = true; barFg.Color = Color3.fromRGB(76,200,120); barFg.ZIndex = 12
          _targetHud.barFg = barFg
      end
      
      _targetHudEnabled = (_targetHud.bg ~= nil and _targetHud.name ~= nil)
  end
  local function applyTargetHud()
      if not _targetHudEnabled then return end
      
      local hudTarget = _G._aimTarget or _G._lastAimTarget
      local showHud = flag("aim_target_hud", false) and hudTarget ~= nil and hudTarget.Parent
      if not showHud then
          pcall(function() if _targetHud.bg  then _targetHud.bg.Visible  = false end end)
          pcall(function() if _targetHud.name then _targetHud.name.Visible = false end end)
          pcall(function() if _targetHud.hp  then _targetHud.hp.Visible  = false end end)
          pcall(function() if _targetHud.bar then _targetHud.bar.Visible = false end end)
          pcall(function() if _targetHud.barFg then _targetHud.barFg.Visible = false end end)
          return
      end
      
      local model = hudTarget.Parent
      local hum   = model and model:FindFirstChildOfClass("Humanoid")
      if not hum or hum.Health <= 0 then return end
      local displayName = model.Name
      local isNpc = true
      for _, plr in ipairs(Players:GetPlayers()) do
          if plr.Character == model then displayName = plr.Name; isNpc = false; break end
      end
      
      if isNpc then
          displayName = "[NPC] " .. displayName
      end
      local hp = math.floor(hum.Health)
      local mhp = math.max(1, math.floor(hum.MaxHealth))
      local frac = math.clamp(hp / mhp, 0, 1)
      local vp = Camera.ViewportSize
      local W, H = 160, 44
      local X = (vp.X - W) / 2
      local Y = vp.Y - H - 60
      if _targetHud.bg  then _targetHud.bg.Visible = true;  _targetHud.bg.Position = Vector2.new(X, Y);     _targetHud.bg.Size = Vector2.new(W, H) end
      if _targetHud.name then _targetHud.name.Visible = true; _targetHud.name.Text = displayName;            _targetHud.name.Position = Vector2.new(X + 8, Y + 5) end
      if _targetHud.hp  then _targetHud.hp.Visible = true;   _targetHud.hp.Text = "hp: " .. hp .. "/" .. mhp; _targetHud.hp.Position = Vector2.new(X + 8, Y + 20) end
      if _targetHud.bar then _targetHud.bar.Visible = true; _targetHud.bar.Position = Vector2.new(X + 8, Y + 33); _targetHud.bar.Size = Vector2.new(W - 16, 6) end
      if _targetHud.barFg then
          _targetHud.barFg.Visible = true
          _targetHud.barFg.Color = Color3.fromHSV(0.33 * frac, 1, 1)
          _targetHud.barFg.Position = Vector2.new(X + 8, Y + 33)
          _targetHud.barFg.Size = Vector2.new(math.max(2, (W - 16) * frac), 6)
      end
  end
  local function aimablePart(charOrModel)
      local c = charOrModel
      if not c then return nil end
      return c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso")
  end
  local function distToCenter(pos)
      local mp = UIS_RUNTIME:GetMouseLocation()
      return (Vector2.new(pos.X, pos.Y) - mp).Magnitude
  end
  
  
  
  
  local _npcCache = {}
  local _lastNpcScan = 0
  local _npcScanInterval = 0.5 
  local function _collectNpcModels()
      local now = tick()
      if now - _lastNpcScan < _npcScanInterval then
          
          local valid = {}
          for _, npc in ipairs(_npcCache) do
              if npc and npc.Parent then
                  local hum = npc:FindFirstChildOfClass("Humanoid")
                  if hum and hum.Health > 0 then
                      table.insert(valid, npc)
                  end
              end
          end
          _npcCache = valid
          return valid
      end
      _lastNpcScan = now
      local out = {}
      local owned = {}
      for _, p in ipairs(Players:GetPlayers()) do
          if p.Character then owned[p.Character] = true end
      end
      
      local containers = {Workspace}
      
      for _, name in ipairs({"NPCs", "Bots", "Enemies", "Mobs", "Dummies", "Targets", "AI"}) do
          local folder = Workspace:FindFirstChild(name)
          if folder then table.insert(containers, folder) end
      end
      for _, container in ipairs(containers) do
          for _, inst in ipairs(container:GetChildren()) do
              if inst:IsA("Model") and not owned[inst] then
                  local hum = inst:FindFirstChildOfClass("Humanoid")
                  if hum and hum.Health > 0 then
                      local root = aimablePart(inst)
                      if root then table.insert(out, inst) end
                  end
              end
          end
      end
      _npcCache = out
      return out
  end
  local function findAimTarget(maxFov, checksFlag)
      local best, bestDist = nil, maxFov
      local checks = type(checksFlag) == "table" and checksFlag or {}
      local doTeamCheck    = table.find(checks, "team check")    ~= nil
      local doFriendCheck  = table.find(checks, "friend check")  ~= nil
      local doVisCheck     = table.find(checks, "visible check") ~= nil
      local doWallCheck    = table.find(checks, "wall check")    ~= nil
      local doNpcCheck     = flag("global_npc", false)
      local function tryPart(part, ownerChar)
          if not part then return end
          local sp, on = Camera:WorldToViewportPoint(part.Position)
          if not on then return end
          local passWall = true
          if (doWallCheck or doVisCheck) and _LP and _LP.Character then
              local camPos = Camera.CFrame.Position
              local dir = part.Position - camPos
              local params = RaycastParams.new()
              params.FilterDescendantsInstances = {_LP.Character, ownerChar}
              params.FilterType = Enum.RaycastFilterType.Exclude
              local result = workspace:Raycast(camPos, dir, params)
              if result then passWall = false end
          end
          if passWall then
              local d = distToCenter(sp)
              if d < bestDist then best, bestDist = part, d end
          end
      end
      -- per-game profile may force team safety (e.g. phantom_forces)
      local profileTeamSafe = _G._elocate_isFriendly and _G._elocate_gameProfile
                              and _G._elocate_gameProfile.teamCheck == true
      for _, plr in ipairs(Players:GetPlayers()) do
          if plr ~= _LP then
              local skip = false
              if doTeamCheck and _LP and plr.Team and _LP.Team and plr.Team == _LP.Team then skip = true end
              if not skip and profileTeamSafe and _G._elocate_isFriendly(plr) then skip = true end
              if not skip and doFriendCheck and _LP then
                  local ok, isFriend = pcall(function() return _LP:IsFriendsWith(plr.UserId) end)
                  if ok and isFriend then skip = true end
              end
              if not skip then tryPart(aimablePart(plr.Character), plr.Character) end
          end
      end
      if doNpcCheck then
          for _, npc in ipairs(_collectNpcModels()) do
              tryPart(aimablePart(npc), npc)
          end
      end
      return best
  end
  
  
  local function findAimTargetMouse(checksFlag)
      local best, bestDist = nil, math.huge
      local checks = type(checksFlag) == "table" and checksFlag or {}
      local doTeamCheck    = table.find(checks, "team check")    ~= nil
      local doFriendCheck  = table.find(checks, "friend check")  ~= nil
      local doVisCheck     = table.find(checks, "visible check") ~= nil
      local doWallCheck    = table.find(checks, "wall check")    ~= nil
      local doNpcCheck     = flag("global_npc", false)
      
      local mouse = _LP and _LP:GetMouse()
      if not mouse then return nil end
      local mousePos = mouse.Hit.p
      
      local function tryPart(part, ownerChar)
          if not part then return end
          local passWall = true
          if (doWallCheck or doVisCheck) and _LP and _LP.Character then
              local camPos = Camera.CFrame.Position
              local dir = part.Position - camPos
              local params = RaycastParams.new()
              params.FilterDescendantsInstances = {_LP.Character, ownerChar}
              params.FilterType = Enum.RaycastFilterType.Exclude
              local result = workspace:Raycast(camPos, dir, params)
              if result then passWall = false end
          end
          if passWall then
              local d = (part.Position - mousePos).Magnitude
              if d < bestDist then best, bestDist = part, d end
          end
      end
      
      local profileTeamSafe = _G._elocate_isFriendly and _G._elocate_gameProfile
                              and _G._elocate_gameProfile.teamCheck == true
      for _, plr in ipairs(Players:GetPlayers()) do
          if plr ~= _LP then
              local skip = false
              if doTeamCheck and _LP and plr.Team and _LP.Team and plr.Team == _LP.Team then skip = true end
              if not skip and profileTeamSafe and _G._elocate_isFriendly(plr) then skip = true end
              if not skip and doFriendCheck and _LP then
                  local ok, isFriend = pcall(function() return _LP:IsFriendsWith(plr.UserId) end)
                  if ok and isFriend then skip = true end
              end
              if not skip then tryPart(aimablePart(plr.Character), plr.Character) end
          end
      end
      if doNpcCheck then
          for _, npc in ipairs(_collectNpcModels()) do
              tryPart(aimablePart(npc), npc)
          end
      end
      return best
  end
  
  
  local function aimKeyHeld()
      local aimKey = Library.Flags["kb_aim_toggle_KEY"]
      local aimMode = Library.Flags["kb_aim_toggle_KEY STATE"] or "Toggle"
      
      if aimMode == "Always" then
          return true
      elseif aimMode == "Hold" then
          if aimKey and aimKey ~= Enum.KeyCode.Unknown then
              return UIS_RUNTIME:IsKeyDown(aimKey)
          end
          return false
      else -- Toggle mode - use the keybind's toggle state
          local toggleState = Library.Flags["kb_aim_toggle"] or false
          return toggleState
      end
  end
  _G._aimTarget = nil
  _G._lastAimTarget = nil  
  local function validateAimTarget(part, maxFov, skipFov, isSticky)
      if not part or not part.Parent then return false end
      local sp, on = Camera:WorldToViewportPoint(part.Position)
      -- For sticky aim, be more lenient - allow targets not on screen or behind camera
      if not isSticky then
          if not on or (sp.Z and sp.Z <= 0) then return false end
      end
      -- Still check FOV unless skipFov is true
      if not skipFov and maxFov < 9999 and distToCenter(sp) > maxFov then return false end
      
      local hum = part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")
      if not hum or hum.Health <= 0 then return false end
      return true
  end
  local function applyAimbot(dt)
      
      if _fovCircleOK and _fovCircle then
          local show = flag("aim_enabled", false) and flag("aim_use_fov", true) and flag("aim_show_fov", true)
          _fovCircle.Visible = show
          if show then
              local mp = UIS_RUNTIME:GetMouseLocation()
              _fovCircle.Position = Vector2.new(mp.X, mp.Y)
              _fovCircle.Radius   = flag("aim_fov_size", 120)
              _fovCircle.Color    = flag("aim_fov_col", Color3.fromRGB(147,112,219))
              _fovCircle.Transparency = 1 - (flag("aim_fov_trans", 70) / 100)
          end
      end
      if not flag("aim_enabled", false) then return end
      if not aimKeyHeld() then return end
      
      local _, lpHrp, lpHum = getChar()
      if not lpHum or lpHum.Health <= 0 then
          _G._aimTarget = nil
          _G._lastAimTarget = nil
          return
      end
      local fov = flag("aim_use_fov", true) and flag("aim_fov_size", 120) or 9999
      
      
      
      local sticky = flag("aim_sticky", false)
      if (not sticky) or (not validateAimTarget(_G._aimTarget, fov, sticky, sticky)) then
          if flag("aim_mouse_mode", false) then
              _G._aimTarget = findAimTargetMouse(flag("aim_checks", {}))
          else
              _G._aimTarget = findAimTarget(fov, flag("aim_checks", {}))
          end
      end
      local target = _G._aimTarget
      
      if target then _G._lastAimTarget = target end
      if not target and _G._lastAimTarget then
          
          local lastModel = _G._lastAimTarget.Parent
          local lastHum = lastModel and lastModel:FindFirstChildOfClass("Humanoid")
          if not lastHum or lastHum.Health < 1 then _G._lastAimTarget = nil end
      end
      if not target then return end
      
      local maxD = flag("aim_max_dist", 1000)
      if maxD < 5000 then
          local lp = _LP and _LP.Character
          local lhrp = lp and lp:FindFirstChild("HumanoidRootPart")
          if lhrp and (lhrp.Position - target.Position).Magnitude > maxD then
              _G._aimTarget = nil
              return
          end
      end
      
      if flag("aim_autostop", true) then
          local myChar = _LP and _LP.Character
          local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
          if myHum and myHum.Health <= 0 then
              _G._aimTarget = nil
              return
          end
          
          local targetChar = target.Parent
          local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
          if not targetHum or targetHum.Health < 1 then
              _G._aimTarget = nil
              return
          end
      end
      
      if flag("aim_notify_tgt", false) then
          local tplr = target.Parent and Players:GetPlayerFromCharacter(target.Parent)
          local key  = tplr and tplr.Name or (target.Parent and target.Parent.Name) or "?"
          if _G._elocate_last_aim_target ~= key then
              _G._elocate_last_aim_target = key
              if _G._elocate_notify then _G._elocate_notify("locked: "..key, 1.5, "good") end
          end
      end
      
      local char = target.Parent
      local targetHum = char and char:FindFirstChildOfClass("Humanoid")
      local hitPartName = flag("aim_hp_default", "Head")
      if targetHum then
          local state = targetHum:GetState()
          if state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.PlatformStanding then
              hitPartName = flag("aim_hp_fall", "UpperTorso")
          elseif state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
              hitPartName = flag("aim_hp_jump", "HumanoidRootPart")
          end
      end
      local hitPart = char and char:FindFirstChild(hitPartName)
      local aimPos = hitPart and hitPart.Position or target.Position
      
      if flag("aim_use_pred", false) and targetHum then
          local vel = targetHum.RootPart and targetHum.RootPart.AssemblyLinearVelocity or Vector3.zero
          local jumpVel = flag("aim_jump_vel", 50)
          local fallVel = flag("aim_fall_vel", 50)
          local state = targetHum:GetState()
          if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
              vel = Vector3.new(vel.X, vel.Y + jumpVel, vel.Z)
          elseif state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.PlatformStanding then
              vel = Vector3.new(vel.X, vel.Y - fallVel, vel.Z)
          end
          local predX = flag("aim_pred_x", 15) / 100
          local predY = flag("aim_pred_y", 15) / 100
          aimPos = aimPos + Vector3.new(vel.X * predX, vel.Y * predY, vel.Z * ((predX + predY) / 2))
      end
      
      if flag("aim_adv_en", false) and targetHum then
          local vel = targetHum.RootPart and targetHum.RootPart.AssemblyLinearVelocity or Vector3.zero
          local predL = flag("aim_pred_l", 0)
          local predR = flag("aim_pred_r", 0)
          local predU = flag("aim_pred_u", 0)
          local predD = flag("aim_pred_d", 0)
          
          local offsetX = (vel.X >= 0 and predR or predL) * math.abs(vel.X)
          local offsetY = (vel.Y >= 0 and predU or predD) * math.abs(vel.Y)
          aimPos = aimPos + Vector3.new(offsetX, offsetY, 0)
      end
      
      local cam = Workspace.CurrentCamera
      if not cam then return end
      local pos = cam.CFrame.Position
      cam.CFrame = CFrame.new(pos, aimPos)
  end
  
  
  
  
  
  local _espDraws = {}
  local function _mk(class) local ok, x = pcall(function() return Drawing.new(class) end); if ok then return x end end
  local function getDraw(plr)
      local d = _espDraws[plr]
      if d then return d end
      if typeof(Drawing) ~= "table" and typeof(Drawing) ~= "userdata" then return nil end
      d = {
          
          box     = _mk("Square"),
          boxO    = _mk("Square"),
          
          cnr = {}, cnrO = {},
          
          edge = {}, edgeO = {},
          
          name    = _mk("Text"),
          dist    = _mk("Text"),
          tool    = _mk("Text"),
          
          hp      = _mk("Line"),
          hpBg    = _mk("Line"),
          hpText  = _mk("Text"),
          
          tracer  = _mk("Line"),
          tracerO = _mk("Line"),
      }
      for i = 1, 8 do d.cnr[i]  = _mk("Line") end
      for i = 1, 8 do d.cnrO[i] = _mk("Line") end
      for i = 1, 12 do d.edge[i]  = _mk("Line") end
      for i = 1, 12 do d.edgeO[i] = _mk("Line") end
      if d.box   then d.box.Thickness = 1;  d.box.Filled = false; d.box.ZIndex = 2 end
      if d.boxO  then d.boxO.Thickness = 3; d.boxO.Filled = false; d.boxO.Color = Color3.new(0,0,0); d.boxO.ZIndex = 1 end
      for _, l in ipairs(d.cnr)  do if l then l.Thickness = 1; l.ZIndex = 2 end end
      for _, l in ipairs(d.cnrO) do if l then l.Thickness = 3; l.Color = Color3.new(0,0,0); l.ZIndex = 1 end end
      if d.name   then d.name.Center = true;  d.name.Size = flag('esp_txt_size', 13); d.name.Outline = true; d.name.ZIndex = 3; d.name.Visible = false end
      if d.dist   then d.dist.Center = true;  d.dist.Size = 12; d.dist.Outline = true; d.dist.ZIndex = 3; d.dist.Visible = false end
      if d.tool   then d.tool.Center = true;  d.tool.Size = 12; d.tool.Outline = true; d.tool.ZIndex = 3; d.tool.Visible = false end
      if d.hp     then d.hp.Thickness = 2;     d.hp.ZIndex = 2; d.hp.Visible = false end
      if d.hpBg   then d.hpBg.Thickness = 4;   d.hpBg.Color = Color3.new(0,0,0); d.hpBg.ZIndex = 1; d.hpBg.Visible = false end
      if d.hpText then d.hpText.Center = true; d.hpText.Size = 11; d.hpText.Outline = true; d.hpText.ZIndex = 3; d.hpText.Visible = false end
      if d.tracer  then d.tracer.Thickness = 1; d.tracer.ZIndex = 2; d.tracer.Visible = false end
      if d.tracerO then d.tracerO.Thickness = 3; d.tracerO.Color = Color3.new(0,0,0); d.tracerO.ZIndex = 1; d.tracerO.Visible = false end
      
      if d.cnr  then for _, l in ipairs(d.cnr)  do if l then l.Thickness = 1; l.ZIndex = 2; l.Visible = false end end end
      if d.cnrO then for _, l in ipairs(d.cnrO) do if l then l.Thickness = 3; l.Color = Color3.new(0,0,0); l.ZIndex = 1; l.Visible = false end end end
      
      if d.edge  then for _, l in ipairs(d.edge)  do if l then l.Thickness = 1; l.ZIndex = 2; l.Visible = false end end end
      if d.edgeO then for _, l in ipairs(d.edgeO) do if l then l.Thickness = 3; l.Color = Color3.new(0,0,0); l.ZIndex = 1; l.Visible = false end end end
      _espDraws[plr] = d
      return d
  end
  
  local function _setvis(x, v) if x then pcall(function() x.Visible = v end) end end
  local function hideDraw(plr)
      local d = _espDraws[plr]; if not d then return end
      _setvis(d.box, false);  _setvis(d.boxO, false)
      _setvis(d.name, false); _setvis(d.dist, false); _setvis(d.tool, false)
      _setvis(d.hp, false);   _setvis(d.hpBg, false); _setvis(d.hpText, false)
      _setvis(d.tracer, false); _setvis(d.tracerO, false)
      if d.cnr  then for _, l in ipairs(d.cnr)  do _setvis(l, false) end end
      if d.cnrO then for _, l in ipairs(d.cnrO) do _setvis(l, false) end end
      if d.edge  then for _, l in ipairs(d.edge)  do _setvis(l, false) end end
      if d.edgeO then for _, l in ipairs(d.edgeO) do _setvis(l, false) end end
  end
  local function killDraw(plr)
      local d = _espDraws[plr]; if not d then return end
      local function rm(x) if x and x.Remove then pcall(function() x:Remove() end) end end
      rm(d.box);  rm(d.boxO);  rm(d.name); rm(d.dist); rm(d.tool)
      rm(d.hp);   rm(d.hpBg);  rm(d.hpText)
      rm(d.tracer); rm(d.tracerO)
      if d.cnr  then for _, l in ipairs(d.cnr)  do rm(l) end end
      if d.cnrO then for _, l in ipairs(d.cnrO) do rm(l) end end
      if d.edge  then for _, l in ipairs(d.edge)  do rm(l) end end
      if d.edgeO then for _, l in ipairs(d.edgeO) do rm(l) end end
      _espDraws[plr] = nil
  end
  local function _labelPos(side, x, y, sizeX, sizeY, lh)
      if     side == "Top"    then return Vector2.new(x + sizeX/2, y - lh - 2),                      Enum.TextXAlignment.Center, true
      elseif side == "Bottom" then return Vector2.new(x + sizeX/2, y + sizeY + 2),                   Enum.TextXAlignment.Center, true
      elseif side == "Left"   then return Vector2.new(x - 4,       y + sizeY/2 - lh/2),              Enum.TextXAlignment.Right, false
      elseif side == "Right"  then return Vector2.new(x + sizeX + 4, y + sizeY/2 - lh/2),            Enum.TextXAlignment.Left, false
      elseif side == "Center" then return Vector2.new(x + sizeX/2, y - lh - 2),                      Enum.TextXAlignment.Center, true  
      else                         return Vector2.new(x + sizeX/2, y - lh - 2),                      Enum.TextXAlignment.Center, true
      end
  end
  
  
  
  local function _equippedTool(plr)
      local names = {}
      local seen  = {}
      local c = plr.Character
      if c then
          for _, ch in ipairs(c:GetChildren()) do
              if ch:IsA("Tool") and not seen[ch.Name] then
                  seen[ch.Name] = true
                  table.insert(names, ch.Name)
              end
          end
      end
      local bp = plr:FindFirstChildOfClass("Backpack")
      if bp then
          for _, ch in ipairs(bp:GetChildren()) do
              if ch:IsA("Tool") and not seen[ch.Name] then
                  seen[ch.Name] = true
                  table.insert(names, ch.Name)
              end
          end
      end
      if #names == 0 then return nil end
      return table.concat(names, ", ")
  end
  local _CUBE_OFFSETS = {
      Vector3.new(-1,-1,-1), Vector3.new( 1,-1,-1), Vector3.new( 1,-1, 1), Vector3.new(-1,-1, 1),
      Vector3.new(-1, 1,-1), Vector3.new( 1, 1,-1), Vector3.new( 1, 1, 1), Vector3.new(-1, 1, 1),
  }
  local _CUBE_EDGES = { {1,2},{2,3},{3,4},{4,1}, {5,6},{6,7},{7,8},{8,5}, {1,5},{2,6},{3,7},{4,8} }
  local function applyEsp(dt)
      if not flag("esp_enabled", false) then
          for plr, _ in pairs(_espDraws) do hideDraw(plr) end
          return
      end
      local viewport = Camera.ViewportSize
      local boxType  = flag("esp_box_type", "Corner")
      
      do
          local active = {}
          for _, p in ipairs(Players:GetPlayers()) do active[p] = true end
          for plr, _ in pairs(_espDraws) do
              if not active[plr] then
                  killDraw(plr)
              elseif not (plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")) then
                  hideDraw(plr)
              end
          end
      end
      for _, plr in ipairs(Players:GetPlayers()) do
          if (plr ~= _LP) or flag("esp_local", false) then
              local c   = plr.Character
              local hrp = c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso"))
              local hum = c and c:FindFirstChildOfClass("Humanoid")
              local d   = getDraw(plr)
              if d and hrp and hum and hum.Health > 0 then
                  local pos, on = Camera:WorldToViewportPoint(hrp.Position)
                  
                  
                  local inFront = pos.Z and pos.Z > 0
                  local inRect  = pos.X >= -50 and pos.Y >= -50
                                  and pos.X <= viewport.X + 50
                                  and pos.Y <= viewport.Y + 50
                  
                          local myHrp = _LP and _LP.Character and _LP.Character:FindFirstChild("HumanoidRootPart")
                          local dist = myHrp and (myHrp.Position - hrp.Position).Magnitude or 0
                          local minDist = flag("esp_min_dist", 0)
                          
                          local visCheckOn = flag("esp_vischeck", false)
                          local isVisible = true
                          if visCheckOn and myHrp then
                              local params = RaycastParams.new()
                              params.FilterDescendantsInstances = {_LP.Character, plr.Character}
                              params.FilterType = Enum.RaycastFilterType.Exclude
                              local dir = hrp.Position - myHrp.Position
                              local result = workspace:Raycast(myHrp.Position, dir, params)
                              isVisible = result == nil
                          end
                          if on and inFront and inRect and dist >= minDist and isVisible then
                      
                      local head = c:FindFirstChild("Head")
                      local root = c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("LowerTorso") or c:FindFirstChild("Torso")
                      local topY, botY
                      if head then
                          topY = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)).Y
                      else
                          topY = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 2.5, 0)).Y
                      end
                      if root then
                          botY = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.5, 0)).Y
                      else
                          botY = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 2.5, 0)).Y
                      end
                      local sizeY = math.abs(botY - topY) + 4
                      local sizeX = sizeY * 0.55
                      local x, y = math.floor(pos.X - sizeX/2), math.floor(topY)
                      local boxOn      = flag("esp_box", false)
                      local boxColor   = flag("esp_box_col",     Color3.fromRGB(147,112,219))
                      local boxOutOn   = boxOn and flag("esp_box_out", true)
                      local boxOutCol  = flag("esp_box_outcol",  Color3.fromRGB(0,0,0))
                      
                      if d.box  then d.box.Visible = false end
                      if d.boxO then d.boxO.Visible = false end
                      for _, l in ipairs(d.cnr)  do l.Visible = false end
                      for _, l in ipairs(d.cnrO) do l.Visible = false end
                      for _, l in ipairs(d.edge)  do l.Visible = false end
                      for _, l in ipairs(d.edgeO) do l.Visible = false end
                      if boxType == "Full" then
                          if d.boxO then
                              d.boxO.Visible  = boxOutOn
                              d.boxO.Position = Vector2.new(x, y)
                              d.boxO.Size     = Vector2.new(sizeX, sizeY)
                              d.boxO.Color    = boxOutCol
                          end
                          if d.box then
                              d.box.Visible  = boxOn
                              d.box.Position = Vector2.new(x, y)
                              d.box.Size     = Vector2.new(sizeX, sizeY)
                              d.box.Color    = boxColor
                          end
                      elseif boxType == "3D" then
                          local pts, allOn = {}, true
                          local size3 = (hrp.Size and hrp.Size * 0.55) or Vector3.new(2,3,1.2)
                          for i, off in ipairs(_CUBE_OFFSETS) do
                              local p, vis = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(off.X*size3.X, off.Y*size3.Y*2, off.Z*size3.Z))
                              pts[i] = Vector2.new(p.X, p.Y)
                              if not vis then allOn = false end
                          end
                          if allOn then
                              
                              for i, e in ipairs(_CUBE_EDGES) do
                                  local lo = d.edgeO[i]
                                  local li = d.edge[i]
                                  if lo then
                                      lo.Visible = boxOutOn
                                      lo.From    = pts[e[1]]
                                      lo.To      = pts[e[2]]
                                      lo.Color   = boxOutCol
                                  end
                                  if li then
                                      li.Visible = boxOn
                                      li.From    = pts[e[1]]
                                      li.To      = pts[e[2]]
                                      li.Color   = boxColor
                                  end
                              end
                          end
                      else
                          
                          local cl = math.max(4, math.floor(math.min(sizeX, sizeY) * 0.25))
                          local segs = {
                              
                              { Vector2.new(x,         y), Vector2.new(x + cl,    y) },
                              { Vector2.new(x,         y), Vector2.new(x,         y + cl) },
                              
                              { Vector2.new(x + sizeX, y), Vector2.new(x + sizeX - cl, y) },
                              { Vector2.new(x + sizeX, y), Vector2.new(x + sizeX, y + cl) },
                              
                              { Vector2.new(x,         y + sizeY), Vector2.new(x + cl,    y + sizeY) },
                              { Vector2.new(x,         y + sizeY), Vector2.new(x,         y + sizeY - cl) },
                              
                              { Vector2.new(x + sizeX, y + sizeY), Vector2.new(x + sizeX - cl, y + sizeY) },
                              { Vector2.new(x + sizeX, y + sizeY), Vector2.new(x + sizeX, y + sizeY - cl) },
                          }
                          for i, s in ipairs(segs) do
                              local lo, li = d.cnrO[i], d.cnr[i]
                              if lo then lo.Visible = boxOutOn; lo.From = s[1]; lo.To = s[2]; lo.Color = boxOutCol end
                              if li then li.Visible = boxOn;    li.From = s[1]; li.To = s[2]; li.Color = boxColor end
                          end
                      end
                      
                      if d.name then
                          d.name.Visible = flag("esp_name", false)
                          if d.name.Visible then
                              local p, _, _ = _labelPos(flag("esp_name_pos", "Top"), x, y, sizeX, sizeY, 13)
                              d.name.Text     = plr.Name
                              d.name.Position = p
                              d.name.Color    = flag("esp_name_col", Color3.fromRGB(255,255,255))
                              d.name.Outline  = flag("esp_name_out", true)
                              d.name.OutlineColor = flag("esp_name_outcol", Color3.fromRGB(0,0,0))
                          end
                      end
                      
                      if d.dist then
                          local distOn = flag("esp_dist", false) and (_LP and _LP.Character and _LP.Character:FindFirstChild("HumanoidRootPart"))
                          d.dist.Visible = distOn
                          if distOn then
                              local meters = math.floor((_LP.Character.HumanoidRootPart.Position - hrp.Position).Magnitude)
                              local p, _, _ = _labelPos(flag("esp_dist_pos", "Bottom"), x, y, sizeX, sizeY, 12)
                              d.dist.Text     = meters .. "m"
                              d.dist.Position = p
                              d.dist.Color    = flag("esp_dist_col", Color3.fromRGB(200, 200, 200))
                              d.dist.Outline  = flag("esp_dist_out", true)
                              d.dist.OutlineColor = flag("esp_dist_outcol", Color3.fromRGB(0,0,0))
                          end
                      end
                      
                      if d.tool then
                          local toolOn = flag("esp_tool", false)
                          local tname  = toolOn and _equippedTool(plr) or nil
                          d.tool.Visible = toolOn and tname ~= nil
                          if d.tool.Visible then
                              local p, _, _ = _labelPos(flag("esp_tool_pos", "Bottom"), x, y, sizeX, sizeY, 12)
                              
                              if flag("esp_dist", true) and flag("esp_dist_pos","Bottom") == flag("esp_tool_pos","Bottom") then
                                  p = Vector2.new(p.X, p.Y + 14)
                              end
                              d.tool.Text     = tname
                              d.tool.Position = p
                              d.tool.Color    = flag("esp_tool_col", Color3.fromRGB(255,255,255))
                              d.tool.Outline  = flag("esp_tool_out", true)
                              d.tool.OutlineColor = flag("esp_tool_outcol", Color3.fromRGB(0,0,0))
                          end
                      end
                      
                      if d.hp and d.hpBg then
                          local hpOn = flag("esp_hp", true)
                          d.hp.Visible   = hpOn
                          d.hpBg.Visible = hpOn and flag("esp_hp_out", true)
                          if hpOn then
                              local frac = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
                              local w    = math.max(1, math.floor(flag("esp_hp_w", 2)))
                              local pos2 = flag("esp_hp_pos", "Left")
                              d.hp.Thickness   = w
                              d.hpBg.Thickness = w + 2
                              local hpColor = Color3.fromHSV(0.33 * frac, 1, 1)
                              d.hp.Color    = hpColor
                              d.hpBg.Color  = flag("esp_hp_outcol", Color3.fromRGB(0,0,0))
                              if pos2 == "Right" then
                                  local lx = x + sizeX + 4
                                  d.hpBg.From = Vector2.new(lx, y);   d.hpBg.To = Vector2.new(lx, y + sizeY)
                                  d.hp.From   = Vector2.new(lx, y + sizeY * (1 - frac)); d.hp.To = Vector2.new(lx, y + sizeY)
                              elseif pos2 == "Top" then
                                  local ly = y - 4
                                  d.hpBg.From = Vector2.new(x, ly);   d.hpBg.To = Vector2.new(x + sizeX, ly)
                                  d.hp.From   = Vector2.new(x, ly);   d.hp.To   = Vector2.new(x + sizeX * frac, ly)
                              elseif pos2 == "Bottom" then
                                  local ly = y + sizeY + 4
                                  d.hpBg.From = Vector2.new(x, ly);   d.hpBg.To = Vector2.new(x + sizeX, ly)
                                  d.hp.From   = Vector2.new(x, ly);   d.hp.To   = Vector2.new(x + sizeX * frac, ly)
                              else
                                  local lx = x - 4
                                  d.hpBg.From = Vector2.new(lx, y);   d.hpBg.To = Vector2.new(lx, y + sizeY)
                                  d.hp.From   = Vector2.new(lx, y + sizeY * (1 - frac)); d.hp.To = Vector2.new(lx, y + sizeY)
                              end
                              if d.hpText then
                                  d.hpText.Visible = flag("esp_hp_text", false)
                                  if d.hpText.Visible then
                                      d.hpText.Text     = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
                                      d.hpText.Color    = hpColor
                                      d.hpText.Position = Vector2.new(x - 4, y + sizeY * (1 - frac) - 6)
                                  end
                              end
                          else
                              if d.hpText then d.hpText.Visible = false end
                          end
                      end
                      
                      if d.tracer then
                          local trOn = flag("esp_tr", false)
                          d.tracer.Visible  = trOn
                          if d.tracerO then d.tracerO.Visible = trOn and flag("esp_tr_out", true) end
                          if trOn then
                              local origin
                              local org = flag("esp_tr_origin", "Bottom")
                              if     org == "Top"    then origin = Vector2.new(viewport.X/2, 0)
                              elseif org == "Center" then origin = Vector2.new(viewport.X/2, viewport.Y/2)
                              elseif org == "Mouse"  then local mp = UIS_RUNTIME:GetMouseLocation(); origin = Vector2.new(mp.X, mp.Y)
                              else                        origin = Vector2.new(viewport.X/2, viewport.Y) end
                              local toV = Vector2.new(pos.X, pos.Y + sizeY/2)
                              d.tracer.From      = origin
                              d.tracer.To        = toV
                              d.tracer.Color     = flag("esp_tr_col", Color3.fromRGB(147,112,219))
                              d.tracer.Thickness = math.max(1, flag("esp_tr_thick", 1))
                              if d.tracerO then
                                  d.tracerO.From      = origin
                                  d.tracerO.To        = toV
                                  d.tracerO.Color     = flag("esp_tr_outcol", Color3.fromRGB(0,0,0))
                                  d.tracerO.Thickness = d.tracer.Thickness + 2
                              end
                          end
                      end
                  else
                      hideDraw(plr)
                  end
              else
                  hideDraw(plr)
              end
          else
              hideDraw(plr)
          end
      end
      
      if flag("global_npc", false) then
          for _, npc in ipairs(_collectNpcModels()) do
              local hrp = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head") or npc:FindFirstChild("Torso") or npc:FindFirstChild("UpperTorso")
              local hum = npc:FindFirstChildOfClass("Humanoid")
              if hrp and hum and hum.Health > 0 then
                  local d = getDraw(npc)
                  if d then
                      local pos, on = Camera:WorldToViewportPoint(hrp.Position)
                      local inFront = pos.Z and pos.Z > 0
                      local inRect  = pos.X >= -50 and pos.Y >= -50 and pos.X <= viewport.X + 50 and pos.Y <= viewport.Y + 50
                      if on and inFront and inRect then
                          
                          local head = npc:FindFirstChild("Head")
                          local root = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("LowerTorso") or npc:FindFirstChild("Torso")
                          local topY, botY
                          if head then
                              topY = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)).Y
                          else
                              topY = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 2.5, 0)).Y
                          end
                          if root then
                              botY = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.5, 0)).Y
                          else
                              botY = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 2.5, 0)).Y
                          end
                          local sizeY = math.abs(botY - topY) + 4
                          local sizeX = sizeY * 0.55
                          local x, y = math.floor(pos.X - sizeX/2), math.floor(topY)
                          
                          
                          local maxDist = flag("esp_max_dist", 0)
                          local skipDraw = false
                          if maxDist > 0 then
                              local myHrp = _LP and _LP.Character and _LP.Character:FindFirstChild("HumanoidRootPart")
                              if myHrp then
                                  local dist = (myHrp.Position - hrp.Position).Magnitude
                                  if dist > maxDist then hideDraw(npc); skipDraw = true end
                              end
                          end
                          
                          
                          if not skipDraw and d.box then
                              d.box.Visible = flag("esp_box", false)
                              d.box.Position = Vector2.new(x, y)
                              d.box.Size = Vector2.new(sizeX, sizeY)
                              d.box.Color = flag("esp_box_col", Library.Accent or _AccentColor)
                          end
                          if d.boxO then
                              d.boxO.Visible = flag("esp_box_out", false)
                              d.boxO.Position = Vector2.new(x, y)
                              d.boxO.Size = Vector2.new(sizeX, sizeY)
                          end
                          
                          
                          if d.hp then
                              d.hp.Visible = flag("esp_hp", false)
                              d.hp.Position = Vector2.new(x - 6, y)
                              d.hp.Size = Vector2.new(4, sizeY)
                              d.hp.Color = Color3.fromRGB(255, 0, 0)
                              if d.hpF then
                                  d.hpF.Visible = flag("esp_hp", false)
                                  d.hpF.Position = Vector2.new(x - 6, y)
                                  local healthPct = hum and math.max(0, hum.Health / (hum.MaxHealth or 100)) or 0
                                  d.hpF.Size = Vector2.new(4, math.floor(sizeY * healthPct))
                                  d.hpF.Color = healthPct > 0.5 and Color3.fromRGB(0, 255, 0) or healthPct > 0.25 and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(255, 0, 0)
                              end
                          end
                          
                          
                          if d.name then
                              d.name.Visible = flag("esp_name", false)
                              d.name.Text = npc.Name
                              d.name.Position = Vector2.new(pos.X, y - 14)
                              d.name.Color = flag("esp_name_col", Library.Accent or _AccentColor)
                          end
                          
                          
                          if d.dist then
                              local myHrp = _LP and _LP.Character and _LP.Character:FindFirstChild("HumanoidRootPart")
                              local dist = myHrp and math.floor((myHrp.Position - hrp.Position).Magnitude) or 0
                              d.dist.Visible = flag("esp_dist", false)
                              d.dist.Text = tostring(dist) .. "m"
                              d.dist.Position = Vector2.new(pos.X, y + sizeY + 2)
                              d.dist.Color = flag("esp_dist_col", Library.Accent or _AccentColor)
                          end
                          
                          
                          if d.hptext then
                              d.hptext.Visible = flag("esp_hp", false)
                              d.hptext.Text = hum and math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth or 100) or "???"
                              d.hptext.Position = Vector2.new(pos.X, y + sizeY + 16)
                              d.hptext.Color = flag("esp_hp_col", Library.Accent or _AccentColor)
                          end
                          
                          
                          if d.weapon then
                              d.weapon.Visible = flag("esp_weapon", false)
                              local toolName = "None"
                              for _, child in ipairs(npc:GetChildren()) do
                                  if child:IsA("Tool") or child:IsA("Accoutrement") then
                                      toolName = child.Name
                                      break
                                  end
                              end
                              d.weapon.Text = toolName
                              d.weapon.Position = Vector2.new(pos.X, y + sizeY + 30)
                              d.weapon.Color = flag("esp_weapon_col", Library.Accent or _AccentColor)
                          end
                          
                          
                          if d.team then
                              d.team.Visible = flag("esp_team", false)
                              local teamName = npc.Parent and npc.Parent.Name or "Unknown"
                              d.team.Text = "[" .. teamName .. "]"
                              d.team.Position = Vector2.new(pos.X + 1, y - 14)
                              d.team.Color = flag("esp_team_col", Library.Accent or _AccentColor)
                          end
                          
                          
                          if d.look and head then
                              d.look.Visible = flag("esp_look", false)
                              local lookDir = head.CFrame.LookVector
                              local lookEnd = head.Position + lookDir * 5
                              local lookScreen = Camera:WorldToViewportPoint(lookEnd)
                              if lookScreen.Z > 0 then
                                  d.look.From = Vector2.new(pos.X, pos.Y)
                                  d.look.To = Vector2.new(lookScreen.X, lookScreen.Y)
                                  d.look.Color = flag("esp_look_col", Library.Accent or _AccentColor)
                              end
                          end
                          
                          
                          if not skipDraw then
                              if flag("esp_chams", false) then
                                  for _, part in ipairs(npc:GetChildren()) do
                                      if part:IsA("BasePart") then
                                          local existing = part:FindFirstChild("_elocate_cham")
                                          if not existing then
                                              local cham = Instance.new("BoxHandleAdornment")
                                              cham.Name = "_elocate_cham"
                                              cham.Adornee = part
                                              cham.Size = part.Size
                                              cham.Transparency = 0.7
                                              cham.Color = flag("esp_chams_col", Library.Accent or _AccentColor)
                                              cham.ZIndex = 10
                                              cham.Parent = part
                                          end
                                      end
                                  end
                              else
                                  for _, part in ipairs(npc:GetChildren()) do
                                      if part:IsA("BasePart") then
                                          local cham = part:FindFirstChild("_elocate_cham")
                                          if cham then cham:Destroy() end
                                      end
                                  end
                              end
                          end
                      else
                          hideDraw(npc)
                      end
                  end
              end
          end
      end
  end
  Players.PlayerRemoving:Connect(function(plr) killDraw(plr) end)
  local _saTarget = nil
  local _saLastScan = 0
  local _saLastTargetName = nil
  local function getSilentAimTarget()
      if not flag("sa_enabled", false) then return nil end
      if not (_G._elocate_sa_keyheld == true) then _saTarget = nil; return nil end
      local now = tick()
      if now - _saLastScan < 0.03 then return _saTarget end 
      _saLastScan = now
      local maxFov = flag("sa_use_fov", false) and flag("sa_fov_size", 80) or 9999
      local checks = flag("sa_checks", {})
      local hitPart = flag("sa_hp_default", "Head")
      local hitchance = flag("sa_hitchance", 100)
      
      
      if hitchance < 100 then
          local roll = math.random() * 100
          if roll > hitchance then
              _saTarget = nil
              return nil
          end
      end
      
      
      if flag("sa_dahood_mode", false) then
          maxFov = maxFov + math.random(-5, 5) 
      end
      local target = findAimTarget(maxFov, checks)
      if target then
          local char = target.Parent
          if char then
              local part = char:FindFirstChild(hitPart) or target
              _saTarget = part
              
              local targetName = char.Name
              if targetName ~= _saLastTargetName and flag("aim_notify_tgt", false) then
                  _saLastTargetName = targetName
                  if _G._elocate_notify then _G._elocate_notify("silent: "..targetName, 1, "good") end
              end
              return part
          end
      end
      _saTarget = nil
      _saLastTargetName = nil
      return nil
  end
  local function getPredictedPosition(target)
      if not target then return nil end
      local pos = target.Position
      
      local resolverMode = flag("sa_resolver", "Off")
      local useResolver = flag("sa_use_res", false) and resolverMode ~= "Off"
      
      if flag("sa_use_pred", false) or useResolver then
          local vel = target.AssemblyLinearVelocity
          local px = flag("sa_pred_x", 0.133)
          local py = flag("sa_pred_y", 0.133)
          local pz = flag("sa_pred_z", 0.133)
          
          if useResolver then
              local targetChar = target.Parent
              local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
              local state = targetHum and targetHum:GetState() or nil
              local speed = vel.Magnitude
              
              if resolverMode == "Stand" then
                  if speed < 1 then
                      vel = Vector3.zero
                  end
              elseif resolverMode == "Slow" then
                  if speed < 16 then
                      vel = vel * 0.5
                  end
              elseif resolverMode == "Air" then
                  if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
                      vel = Vector3.new(vel.X * 1.5, vel.Y, vel.Z * 1.5)
                  end
              elseif resolverMode == "All" then
                  local resolvedVel = Vector3.new(vel.X, vel.Y, vel.Z)
                  if speed < 1 then
                      resolvedVel = Vector3.zero
                  elseif speed < 16 then
                      resolvedVel = resolvedVel * 0.7
                  end
                  if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
                      resolvedVel = Vector3.new(resolvedVel.X * 1.3, resolvedVel.Y, resolvedVel.Z * 1.3)
                  end
                  vel = resolvedVel
              end
          end
          
          pos = pos + Vector3.new(vel.X * px, vel.Y * py, vel.Z * pz)
      end
      
      if flag("aim_offset_en", false) then
          local targetHum = target.Parent and target.Parent:FindFirstChildOfClass("Humanoid")
          if targetHum then
              local state = targetHum:GetState()
              if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
                  if target.AssemblyLinearVelocity.Y > 0 then
                      pos = pos + Vector3.new(0, flag("aim_off_jump", 0)/10, 0)
                  else
                      pos = pos + Vector3.new(0, flag("aim_off_fall", 0)/10, 0)
                  end
              end
          end
          local rightVector = target.CFrame.RightVector
          local upVector = target.CFrame.UpVector
          pos = pos + (rightVector * (flag("aim_off_x", 0)/10)) + (upVector * (flag("aim_off_y", 0)/10))
      end
      
      return pos
  end
  
  local _viewportOffset = Vector2.new(0, 0)
  local _saMethod = "Mouse.Hit"
  pcall(function()
      local _mouse = _LP and _LP:GetMouse()
      if not _mouse then return end
      local grm = getrawmetatable(game)
      local oldindex = grm.__index
      setreadonly(grm, false)
      grm.__index = function(self, key)
          
      local isScriptCaller = checkcaller()
      local isMouseObject = self == _mouse or (typeof(self) == "Instance" and self:IsA("Mouse"))
      local isCamera = typeof(self) == "Instance" and self:IsA("Camera")
      
      if (not isScriptCaller) and isCamera and flag("sa_enabled", false) and flag("sa_method", "Mouse.Hit") == "Viewport" then
          if key == "ViewportSize" or key == "viewportSize" then
              local saTarget = getSilentAimTarget()
              if saTarget then
                  local pos = getPredictedPosition(saTarget)
                  if pos then
                      local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
                      if onScreen then
                          local vp = oldindex(self, key)
                          
                          local offsetX = 2 * (vp.X - screenPos.X)
                          local offsetY = 2 * (vp.Y - screenPos.Y)
                          _viewportOffset = Vector2.new(offsetX, offsetY)
                          return Vector2.new(vp.X + offsetX, vp.Y + offsetY)
                      end
                  end
              end
          end
      end
      if (not isScriptCaller) and isMouseObject and flag("sa_enabled", false) then
          if key == "Hit" or key == "hit" then
              local saTarget = getSilentAimTarget()
              if saTarget then
                  local pos = getPredictedPosition(saTarget)
                  if pos then 
                      
                      if flag("sa_dahood_mode", false) then
                          local randomOffset = Vector3.new(
                              math.random(-0.1, 0.1),
                              math.random(-0.1, 0.1),
                              math.random(-0.1, 0.1)
                          )
                          pos = pos + randomOffset
                      end
                      return CFrame.new(pos) 
                  end
              end
          elseif key == "Target" or key == "target" then
              local saTarget = getSilentAimTarget()
              if saTarget then return saTarget end
          elseif key == "Origin" or key == "origin" then
              
              local saTarget = getSilentAimTarget()
              if saTarget and flag("sa_dahood_mode", false) then
                  local camPos = Camera.CFrame.Position
                  local targetPos = getPredictedPosition(saTarget)
                  if targetPos then
                      return camPos
                  end
              end
          end
      end
          return oldindex(self, key)
      end
      setreadonly(grm, true)
  end)
  local _wasOpen = false
  local _mainFrameCount = 0
  local _mainHeartbeat = RunService.Heartbeat:Connect(function(dt)
      _G._elocate_main_loop = _mainHeartbeat
      _mainFrameCount = _mainFrameCount + 1
      
      -- Critical functions - always call so they can clean up when disabled
      pcall(applyMovement, dt)
      pcall(applyFly, dt)
      if flag("cam_fov_en", false) then pcall(applyCamera, dt) end
      if flag("aim_enabled", false) then pcall(applyAimbot, dt) end
      
      -- Non-critical functions run every 2nd frame - check flags first
      if _mainFrameCount % 2 == 0 then
          if flag("fps_unlock", false) then pcall(applyFpsUnlock, dt) end
          if flag("wm_en", true) then pcall(applyWatermark) end
          if flag("kb_en", true) then pcall(applyKeybindList) end
          pcall(applyWorld, dt)
          -- Target HUD is now handled by ScreenGui system at end of file
      end
      
      -- Heavy visual functions run every 5th frame - always call for cleanup
      if _mainFrameCount % 5 == 0 then
          pcall(applyChams, dt)  -- Always call so cleanup happens when disabled
          pcall(applyEsp, dt)    -- Always call so cleanup happens when disabled
      end
      local isOpen = (Library.Holder and Library.Holder.Visible) and true or false
      if isOpen ~= _wasOpen then
          _wasOpen = isOpen
          if (not isOpen) and _G._elocate_close_player_menu then _G._elocate_close_player_menu() end
          
          
          pcall(applyPlayerList)
      end
      local target = isOpen and 12 or 0
      if _blur then _blur.Size = _blur.Size + (target - _blur.Size) * math.clamp(dt * 8, 0, 1) end
  end)
  
  
  task.defer(function() pcall(applyPlayerList) end)
  
  task.spawn(function()
      while task.wait(0.5) do
          pcall(function()
              if Pl and PlAccent then
                  PlAccent.BackgroundColor3 = Library.Accent or _AccentColor
              end
          end)
      end
  end)
    local function makeDraggable(frame)
        local dragging, dragStart, startPos = false, nil, nil
        frame.Active = true
        frame.InputBegan:Connect(function(input)
            if not (Library.Holder and Library.Holder.Visible) then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        UIS_RUNTIME.InputChanged:Connect(function(input)
            if dragging
                and (input.UserInputType == Enum.UserInputType.MouseMovement
                     or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end
    Wm.AnchorPoint = Vector2.new(0, 0); Wm.Position = UDim2.new(0, 12, 0, 12)
    Kb.AnchorPoint = Vector2.new(0, 1); Kb.Position = UDim2.new(0, 12, 1, -12)
    Pl.AnchorPoint = Vector2.new(1, 1); Pl.Position = UDim2.new(1, -12, 1, -12)
    makeDraggable(Wm)
    makeDraggable(Kb)
    makeDraggable(Pl)
    local function closePlayerMenu()
        _expandedUserId = nil
        destroyExpansion()
    end
    local function togglePlayerMenu(plr)
        if _expandedUserId == plr.UserId then
            _expandedUserId = nil
        else
            _expandedUserId = plr.UserId
        end
        pcall(applyPlayerList)
    end
    _G._elocate_toggle_player_menu = togglePlayerMenu
    _G._elocate_close_player_menu = closePlayerMenu
    
    local TweenService = game:GetService("TweenService")
    local function _collectFadeTargets(root)
        local out = { root }
        for _, d in ipairs(root:GetDescendants()) do table.insert(out, d) end
        return out
    end
    local function fadeWidget(root, bool, baseFlagFn)
        if not root then return end
        local stillEnabled = baseFlagFn == nil or baseFlagFn() ~= false
        if bool and stillEnabled then root.Visible = true end
        local goalBg = bool and 0 or 0.95
        local goalTx = bool and 0 or 0.95
        local goalSk = bool and 0 or 0.95
        for _, v in ipairs(_collectFadeTargets(root)) do
            if v:IsA("Frame") or v:IsA("TextButton") or v:IsA("ScrollingFrame") then
                if v.BackgroundTransparency ~= 1 then
                    pcall(function()
                        TweenService:Create(v, TweenInfo.new(0.25, Enum.EasingStyle.Linear, bool and Enum.EasingDirection.Out or Enum.EasingDirection.In), {BackgroundTransparency = goalBg}):Play()
                    end)
                end
            end
            if v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then
                pcall(function()
                    TweenService:Create(v, TweenInfo.new(0.25, Enum.EasingStyle.Linear, bool and Enum.EasingDirection.Out or Enum.EasingDirection.In), {TextTransparency = goalTx}):Play()
                end)
            end
            if v:IsA("UIStroke") then
                pcall(function()
                    TweenService:Create(v, TweenInfo.new(0.25, Enum.EasingStyle.Linear, bool and Enum.EasingDirection.Out or Enum.EasingDirection.In), {Transparency = goalSk}):Play()
                end)
            end
            if v:IsA("ImageLabel") or v:IsA("ImageButton") then
                pcall(function()
                    TweenService:Create(v, TweenInfo.new(0.25, Enum.EasingStyle.Linear, bool and Enum.EasingDirection.Out or Enum.EasingDirection.In), {ImageTransparency = goalTx, BackgroundTransparency = goalBg}):Play()
                end)
            end
        end
        if not bool then
            task.delay(0.3, function()
                pcall(function() root.Visible = stillEnabled end)
            end)
        end
    end
    Library._widgetsShown = true
    local _origSetOpen = Library.SetOpen
    function Library:SetOpen(bool)
        if typeof(bool) ~= "boolean" then return end
        _origSetOpen(self, bool)
        
        
        if not bool then 
            closePlayerMenu()
            
            pcall(function()
                if Library._PopupGui then
                    for _, child in ipairs(Library._PopupGui:GetChildren()) do
                        if child:IsA("Frame") then child.Visible = false end
                    end
                end
            end)
        end
    end
  
  -- String-based config system exports
  _G._elocate_export = exportConfig
  _G._elocate_import = importConfig
  _G._elocate_reset = resetConfig
  _G._elocate_get_config_string = getConfigString
  _G._elocate_rejoin = function()
      pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, _LP) end)
  end
  _G._elocate_hop = function()
      notify("server hop not implemented in this build", 2, "warn")
  end
  _G._elocate_panic = function()
      notify("unloading...", 1, "error")
      task.wait(0.6)
      pcall(function()
          local hParent = Library.Holder and Library.Holder.Parent
          if hParent then
              for _, h in next, hParent:GetChildren() do
                  if tostring(h.Name):sub(1,9) == "_elocate" then pcall(function() h:Destroy() end) end
              end
          end
      end)
      pcall(function() _WidgetGui:Destroy() end)
      pcall(function() if Library._PopupGui then Library._PopupGui:Destroy() end end)
      for _, c in next, (Library.Connections or {}) do pcall(function() c:Disconnect() end) end
  end
  _G._elocate_notify = notify
  task.delay(0.3, function() notify("elocate.lol loaded", 2.5, "good") end)
    
    local PageSettings = Window:Page({ Name = "settings" })
    pinTabLeft(Window, PageSettings, 72)
    do
        local s = PageSettings:Section({ Name = "theme", LeftTitle = "preset & accent", RightTitle = "element colors" })
        s:List({   Name = "themes",           Side = "Left", options = {"Royal", "Onyx", "Ruby", "Emerald", "Sapphire", "Amethyst"}, default = "Royal", flag = "ui_theme", callback = function(v) pcall(function() Library:SetTheme(v) end) end })
        s:Toggle({ Name = "show watermark",   Side = "Left", flag = "wm_en",         default = true,  callback = function(v) pcall(applyWatermark) end })
        s:Toggle({ Name = "show keybind list", Side = "Left", flag = "kb_en",         default = true,  callback = function(v) pcall(applyKeybindList) end })
        s:Toggle({ Name = "show player list",  Side = "Left", flag = "pl_en",         default = true,  callback = function(v) pcall(applyPlayerList) end })
        s:Toggle({ Name = "notifications",     Side = "Left", flag = "sys_notif",     default = true,  callback = function(v) end })
        s:Colorpicker({ Name = "accent",      Side = "Left", default = Color3.fromRGB(147,112,219),  flag = "ui_accent", callback = function(c) _AccentColor = c; pcall(function() Library:ChangeAccent(c) end) end })
        s:Toggle({ Name = "target npcs globally", Side = "Left", flag = "global_npc", default = false, callback = function(v) if _G._elocate_notify then _G._elocate_notify(v and "npc targeting on" or "npc targeting off", 1, "good") end end })
        s:Colorpicker({ Name = "main bg",     Side = "Right", default = Color3.fromRGB(11,12,15),   flag = "ui_bg",    callback = function(v) end })
        s:Colorpicker({ Name = "main text",   Side = "Right", default = Color3.fromRGB(220,224,230),flag = "ui_text",  callback = function(v) end })
        s:Colorpicker({ Name = "watermark",   Side = "Right", default = Color3.fromRGB(220,224,230),flag = "wm_col",   callback = function(v) end })
        s:Colorpicker({ Name = "keybind list",Side = "Right", default = Color3.fromRGB(147,112,219), flag = "kb_col",   callback = function(v) end })
        s:Colorpicker({ Name = "player list", Side = "Right", default = Color3.fromRGB(147,112,219), flag = "pl_col",   callback = function(v) end })
        s:Colorpicker({ Name = "notification",Side = "Right", default = Color3.fromRGB(147,112,219), flag = "notif_col",callback = function(v) end })
        s:Keybind({ Name = "menu key", Side = "Right", flag = "ui_menu_key", mode = "Toggle", default = Enum.KeyCode.LeftShift, callback = function(v) 
            Library:SetOpen(v)
        end })
        local s2 = PageSettings:Section({ Name = "system", LeftTitle = "config string", RightTitle = "actions" })
        
        -- Config string textbox (read-only, updates automatically)
        local configBox = s2:Textbox({ Name = "config string (auto-updates)", Side = "Left", default = "", flag = "cfg_string", callback = function(v) end })
        
        -- Update config string whenever settings change
        local lastConfigStr = ""
        local function updateConfigBox()
            if not configBox then return end
            local str = getConfigString()
            if str ~= lastConfigStr then
                lastConfigStr = str
                -- Update the textbox (this would need your UI library to support setting value)
                _G._elocate_config_string = str
            end
        end
        
        s2:Button({ Name = "copy config to clipboard", Side = "Left", callback = function()
            if _G._elocate_export then _G._elocate_export() end
        end })
        s2:Button({ Name = "paste config from clipboard", Side = "Left", callback = function()
            if typeof(getclipboard) == "function" then
                local ok, data = pcall(getclipboard)
                if ok and data and _G._elocate_import then
                    _G._elocate_import(data)
                else
                    notify("clipboard empty or invalid", 3, "error")
                end
            else
                notify("getclipboard not available", 3, "error")
            end
        end })
        s2:Button({ Name = "load from textbox", Side = "Left", callback = function()
            local str = flag("cfg_string", "")
            if str and str ~= "" and _G._elocate_import then
                _G._elocate_import(str)
            else
                notify("textbox is empty", 3, "warn")
            end
        end })
        s2:Button({ Name = "reset to defaults", Side = "Right", callback = function() if _G._elocate_reset then _G._elocate_reset() end end })
        
        
        s2:Toggle({ Name = "headless (server)", Side = "Right", flag = "headless_server", default = false, callback = function(v)
            local function applyHeadlessServer(char)
                if not char then return end
                local head = char:FindFirstChild("Head")
                if head then
                    if v then
                        
                        head.Parent = nil
                    else
                        
                        if not head.Parent then
                            
                            local humanoid = char:FindFirstChildOfClass("Humanoid")
                            if humanoid then
                                local newHead = Instance.new("Part")
                                newHead.Name = "Head"
                                newHead.Size = Vector3.new(2, 1, 1)
                                newHead.BrickColor = BrickColor.new("Light orange")
                                newHead.TopSurface = Enum.SurfaceType.Smooth
                                newHead.BottomSurface = Enum.SurfaceType.Smooth
                                newHead.Parent = char
                                
                                
                                local face = Instance.new("Decal")
                                face.Name = "face"
                                face.Parent = newHead
                                face.Texture = "rbxasset://textures/face.png"
                                face.Face = Enum.NormalId.Front
                                
                                
                                local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
                                if torso then
                                    local weld = Instance.new("Weld")
                                    weld.Part0 = torso
                                    weld.Part1 = newHead
                                    weld.C0 = CFrame.new(0, 1.5, 0)
                                    weld.Parent = torso
                                end
                            end
                        end
                    end
                end
            end
            
            
            pcall(function()
                applyHeadlessServer(_LP and _LP.Character)
                
                
                if _LP and _LP.CharacterAdded then
                    local connection
                    connection = _LP.CharacterAdded:Connect(function(char)
                        if flag("headless_server", false) then
                            char:WaitForChild("Head", 2)
                            applyHeadlessServer(char)
                        end
                        if connection then connection:Disconnect() end
                    end)
                end
                
                if _G._elocate_notify then _G._elocate_notify(v and "server headless enabled" or "server headless disabled", 1, v and "good" or "info") end
            end)
        end })
        s2:Toggle({ Name = "headless (client)", Side = "Right", flag = "headless_client", default = false, callback = function(v)
            local function applyHeadlessClient(char)
                if not char then return end
                local head = char:FindFirstChild("Head")
                if head then
                    
                    local faceNames = {"face", "Face", "HeadFace", "Mesh"}
                    for _, faceName in ipairs(faceNames) do
                        local face = head:FindFirstChild(faceName)
                        if face then
                            face.Transparency = v and 1 or 0
                        end
                    end
                    
                    for _, child in ipairs(head:GetChildren()) do
                        if child:IsA("Decal") or child:IsA("Texture") or child:IsA("SpecialMesh") then
                            child.Transparency = v and 1 or 0
                        end
                    end
                    
                    if v then
                        head.Transparency = 1
                    else
                        head.Transparency = 0
                    end
                end
            end
            
            
            pcall(function()
                applyHeadlessClient(_LP and _LP.Character)
                
                
                if _LP and _LP.CharacterAdded then
                    local connection
                    connection = _LP.CharacterAdded:Connect(function(char)
                        if flag("headless_client", false) then
                            char:WaitForChild("Head", 2)
                            applyHeadlessClient(char)
                        end
                        if connection then connection:Disconnect() end
                    end)
                end
                
                if _G._elocate_notify then _G._elocate_notify(v and "client headless enabled" or "client headless disabled", 1, v and "good" or "info") end
            end)
        end })
                s2:Button({ Name = "rejoin server", Side = "Right", callback = function() if _G._elocate_rejoin then _G._elocate_rejoin() end end })
        s2:Button({ Name = "unload script",      Side = "Right", callback = function() if _G._elocate_panic  then _G._elocate_panic()  end end })
        applyScroll(PageSettings)
        local s3 = PageSettings:Section({ Name = "community", LeftTitle = "links", RightTitle = "credits" })
        
        
        s3:Button({ Name = "join discord (copy link)", Side = "Left", callback = function()
            local url = _G._elocate_discord or "https://discord.gg/curvecc"
            if typeof(setclipboard) == "function" then
                pcall(setclipboard, url)
                if _G._elocate_notify then _G._elocate_notify("copied discord link", 2.5, "good") end
            elseif typeof(toclipboard) == "function" then
                pcall(toclipboard, url)
                if _G._elocate_notify then _G._elocate_notify("copied discord link", 2.5, "good") end
            else
                if _G._elocate_notify then _G._elocate_notify("clipboard unavailable: " .. url, 4, "warn") end
            end
        end })
        s3:Button({ Name = "copy username",     Side = "Left", callback = function()
            if typeof(setclipboard) == "function" and game:GetService("Players").LocalPlayer then
                pcall(setclipboard, game:GetService("Players").LocalPlayer.Name)
                if _G._elocate_notify then _G._elocate_notify("copied your name", 2, "good") end
            end
        end })
        s3:Button({ Name = "copy place id",     Side = "Right", callback = function()
            if typeof(setclipboard) == "function" then
                pcall(setclipboard, tostring(game.PlaceId))
                if _G._elocate_notify then _G._elocate_notify("copied place id", 2, "good") end
            end
        end })
        s3:Button({ Name = "copy job id",       Side = "Right", callback = function()
            if typeof(setclipboard) == "function" then
                pcall(setclipboard, tostring(game.JobId))
                if _G._elocate_notify then _G._elocate_notify("copied job id", 2, "good") end
            end
        end })
    end
    applyScroll(PageSettings)
end)

-- ============================================
-- FEATURE LOGIC IMPLEMENTATIONS (Outside main scope)
-- ============================================

do
    local RS = game:GetService("RunService")
    local PL = game:GetService("Players")
    local LI = game:GetService("Lighting")
    local LP = PL.LocalPlayer
    
    -- Disconnect any existing connections to prevent duplicates
    if _G._elocate_connections then
        for _, conn in ipairs(_G._elocate_connections) do
            pcall(function() conn:Disconnect() end)
        end
    end
    _G._elocate_connections = {}
    
    _G._elocate_toolEffects = {}
    _G._elocate_playerEffects = {}
    _G._elocate_skyObject = nil
    _G._elocate_originalSky = nil
    _G._elocate_origLighting = {}
    _G._elocate_lastSkyPreset = nil
    _G._elocate_lastToolMat = nil
    _G._elocate_colorCorrection = nil
    _G._elocate_clouds = nil
    _G._elocate_lastLightState = nil
    
    local flag = function(n, d) return Library.Flags[n] or d end
    local getRGB = function(s, o) return Color3.fromHSV((tick() * (s or 5) / 10 + (o or 0)) % 1, 1, 1) end
    
    -- Helper to track connections
    local function trackConn(conn)
        table.insert(_G._elocate_connections, conn)
        return conn
    end
    
    local skyPresets = {
        ["Piss"] = {
            SkyboxUp = "rbxassetid://2651437350",
            SkyboxRt = "rbxassetid://2651436979",
            SkyboxLf = "rbxassetid://2651436494",
            SkyboxFt = "rbxassetid://2651435990",
            SkyboxBk = "rbxassetid://2651432901",
            SkyboxDn = "rbxassetid://2651434974"
        },
        ["Peach"] = {
            SkyboxUp = "rbxassetid://566616187",
            SkyboxRt = "rbxassetid://566616082",
            SkyboxLf = "rbxassetid://566616044",
            SkyboxFt = "rbxassetid://566616141",
            SkyboxBk = "rbxassetid://566616113",
            SkyboxDn = "rbxassetid://566616232"
        },
        ["Saku"] = {
            SkyboxUp = "http://www.roblox.com/asset/?id=271077958",
            SkyboxRt = "http://www.roblox.com/asset/?id=271042467",
            SkyboxLf = "http://www.roblox.com/asset/?id=271042310",
            SkyboxFt = "http://www.roblox.com/asset/?id=271042556",
            SkyboxBk = "http://www.roblox.com/asset/?id=271042516",
            SkyboxDn = "http://www.roblox.com/asset/?id=271077243"
        },
        ["Purple"] = {
            SkyboxUp = "http://www.roblox.com/asset/?id=570557727",
            SkyboxRt = "http://www.roblox.com/asset/?id=570557672",
            SkyboxLf = "http://www.roblox.com/asset/?id=570557620",
            SkyboxFt = "http://www.roblox.com/asset/?id=570557559",
            SkyboxBk = "http://www.roblox.com/asset/?id=570557514",
            SkyboxDn = "http://www.roblox.com/asset/?id=570557775"
        },
        ["Retro"] = {
            SkyboxUp = "rbxassetid://18164890128",
            SkyboxRt = "rbxassetid://18164873920",
            SkyboxLf = "rbxassetid://18164877945",
            SkyboxFt = "rbxassetid://18164870251",
            SkyboxBk = "rbxassetid://18164881924",
            SkyboxDn = "rbxassetid://18166113875"
        },
        ["Space"] = {
            SkyboxUp = "rbxassetid://15983964246",
            SkyboxRt = "rbxassetid://15983966246",
            SkyboxLf = "rbxassetid://15983967420",
            SkyboxFt = "rbxassetid://15983965025",
            SkyboxBk = "rbxassetid://15983968922",
            SkyboxDn = "rbxassetid://15983966825"
        },
        ["Sea"] = {
            SkyboxUp = "http://www.roblox.com/asset/?id=321846070",
            SkyboxRt = "http://www.roblox.com/asset/?id=321846207",
            SkyboxLf = "http://www.roblox.com/asset/?id=321846162",
            SkyboxFt = "http://www.roblox.com/asset/?id=321845951",
            SkyboxBk = "http://www.roblox.com/asset/?id=321846018",
            SkyboxDn = "http://www.roblox.com/asset/?id=321846104"
        },
        ["Night V2"] = {
            SkyboxUp = "http://www.roblox.com/Asset/?ID=12064131",
            SkyboxRt = "http://www.roblox.com/Asset/?ID=12064115",
            SkyboxLf = "http://www.roblox.com/Asset/?ID=12063984",
            SkyboxFt = "http://www.roblox.com/Asset/?ID=12064121",
            SkyboxBk = "http://www.roblox.com/Asset/?ID=12064107",
            SkyboxDn = "http://www.roblox.com/Asset/?ID=12064152"
        },
        ["Dark"] = {
            SkyboxUp = "rbxassetid://15470160563",
            SkyboxRt = "rbxassetid://15470158022",
            SkyboxLf = "rbxassetid://15470155938",
            SkyboxFt = "rbxassetid://15470153860",
            SkyboxBk = "rbxassetid://15470149279",
            SkyboxDn = "rbxassetid://15470151245"
        },
        ["Anime"] = {
            SkyboxUp = "http://www.roblox.com/asset/?id=104038404823203",
            SkyboxRt = "http://www.roblox.com/asset/?id=99961685452126",
            SkyboxLf = "http://www.roblox.com/asset/?id=84924000207295",
            SkyboxFt = "http://www.roblox.com/asset/?id=95687237979398",
            SkyboxBk = "http://www.roblox.com/asset/?id=81858382098344",
            SkyboxDn = "http://www.roblox.com/asset/?id=138472117789684"
        },
        ["Beach"] = {
            SkyboxUp = "http://www.roblox.com/asset/?id=151165227",
            SkyboxRt = "http://www.roblox.com/asset/?id=151165206",
            SkyboxLf = "http://www.roblox.com/asset/?id=151165191",
            SkyboxFt = "http://www.roblox.com/asset/?id=151165224",
            SkyboxBk = "http://www.roblox.com/asset/?id=151165214",
            SkyboxDn = "http://www.roblox.com/asset/?id=151165197"
        },
        ["Space V2"] = {
            SkyboxUp = "http://www.roblox.com/asset/?id=16262366016",
            SkyboxRt = "http://www.roblox.com/asset/?id=16262363873",
            SkyboxLf = "http://www.roblox.com/asset/?id=16262362003",
            SkyboxFt = "http://www.roblox.com/asset/?id=16262360469",
            SkyboxBk = "http://www.roblox.com/asset/?id=16262356578",
            SkyboxDn = "http://www.roblox.com/asset/?id=16262358026"
        },
        ["Pink"] = {
            SkyboxUp = "rbxassetid://12635316856",
            SkyboxRt = "rbxassetid://12635315817",
            SkyboxLf = "rbxassetid://12635313718",
            SkyboxFt = "rbxassetid://12635312870",
            SkyboxBk = "rbxassetid://12635309703",
            SkyboxDn = "rbxassetid://12635311686"
        },
        ["Rainbow"] = {
            SkyboxUp = "rbxassetid://12877083856",
            SkyboxRt = "rbxassetid://12877085497",
            SkyboxLf = "rbxassetid://12877085497",
            SkyboxFt = "rbxassetid://12877085497",
            SkyboxBk = "rbxassetid://12877085497",
            SkyboxDn = "rbxassetid://12877086914"
        },
        ["Forest"] = {
            SkyboxUp = "http://www.roblox.com/asset/?id=237593929",
            SkyboxRt = "http://www.roblox.com/asset/?id=237593835",
            SkyboxLf = "http://www.roblox.com/asset/?id=237593861",
            SkyboxFt = "http://www.roblox.com/asset/?id=237593922",
            SkyboxBk = "http://www.roblox.com/asset/?id=237593887",
            SkyboxDn = "http://www.roblox.com/asset/?id=237593849"
        },
        ["Night"] = {
            SkyboxUp = "http://www.roblox.com/asset/?id=154185031",
            SkyboxRt = "http://www.roblox.com/asset/?id=154184972",
            SkyboxLf = "http://www.roblox.com/asset/?id=154184943",
            SkyboxFt = "http://www.roblox.com/asset/?id=154185021",
            SkyboxBk = "http://www.roblox.com/asset/?id=154185004",
            SkyboxDn = "http://www.roblox.com/asset/?id=154184960"
        },
        ["Lava"] = {
            SkyboxUp = "http://www.roblox.com/asset/?id=4776130793",
            SkyboxRt = "http://www.roblox.com/asset/?id=4776133150",
            SkyboxLf = "http://www.roblox.com/asset/?id=4776128425",
            SkyboxFt = "http://www.roblox.com/asset/?id=4776131365",
            SkyboxBk = "http://www.roblox.com/asset/?id=4776124334",
            SkyboxDn = "http://www.roblox.com/asset/?id=4776125375"
        },
        ["Rainy"] = {
            SkyboxUp = "http://www.roblox.com/asset/?id=4495867486",
            SkyboxRt = "http://www.roblox.com/asset/?id=4495866584",
            SkyboxLf = "http://www.roblox.com/asset/?id=4495866035",
            SkyboxFt = "http://www.roblox.com/asset/?id=4495865458",
            SkyboxBk = "http://www.roblox.com/asset/?id=4495864450",
            SkyboxDn = "http://www.roblox.com/asset/?id=4495864887"
        },
        ["Green"] = {
            SkyboxUp = "rbxassetid://566611218",
            SkyboxRt = "rbxassetid://566611300",
            SkyboxLf = "rbxassetid://566611266",
            SkyboxFt = "rbxassetid://566611142",
            SkyboxBk = "rbxassetid://566611187",
            SkyboxDn = "rbxassetid://566613198"
        },
        ["Volcanic"] = {
            SkyboxUp = "http://www.roblox.com/asset/?id=150281471",
            SkyboxRt = "http://www.roblox.com/asset/?id=150281426",
            SkyboxLf = "http://www.roblox.com/asset/?id=150281400",
            SkyboxFt = "http://www.roblox.com/asset/?id=150281461",
            SkyboxBk = "http://www.roblox.com/asset/?id=150281446",
            SkyboxDn = "http://www.roblox.com/asset/?id=150281418"
        },
        ["Minecraft"] = {
            SkyboxUp = "http://www.roblox.com/asset/?id=8735166729",
            SkyboxRt = "http://www.roblox.com/asset/?id=8735166751",
            SkyboxLf = "http://www.roblox.com/asset/?id=8735166755",
            SkyboxFt = "http://www.roblox.com/asset/?id=8735231668",
            SkyboxBk = "rbxassetid://8735166756",
            SkyboxDn = "http://www.roblox.com/asset/?id=8735166707"
        },
        ["Lucid"] = {
            SkyboxUp = "rbxassetid://8508112781",
            SkyboxRt = "rbxassetid://8508111092",
            SkyboxLf = "rbxassetid://8508107681",
            SkyboxFt = "rbxassetid://8508104949",
            SkyboxBk = "rbxassetid://8508098796",
            SkyboxDn = "rbxassetid://8508103588"
        },
        ["Nebulous"] = {
            SkyboxUp = "rbxassetid://131036626982613",
            SkyboxRt = "rbxassetid://103716549795832",
            SkyboxLf = "rbxassetid://126542804346203",
            SkyboxFt = "rbxassetid://107665368823185",
            SkyboxBk = "rbxassetid://95020137072033",
            SkyboxDn = "rbxassetid://92862258103959"
        },
        ["Custom"] = nil
    }
    
    -- Skybox Logic with presets
    local skyFrameCount = 0
    trackConn(RS.RenderStepped:Connect(function()
        skyFrameCount = skyFrameCount + 1
        if skyFrameCount % 10 ~= 0 then return end

        local skyEn = flag("w_sky_en", false)
        if not skyEn then
            if _G._elocate_skyObject then
                pcall(function() _G._elocate_skyObject:Destroy() end)
                _G._elocate_skyObject = nil
            end
            if _G._elocate_originalSky then
                pcall(function() _G._elocate_originalSky.Parent = LI end)
                _G._elocate_originalSky = nil
            end
            _G._elocate_lastSkyId = nil
            _G._elocate_lastSkyPreset = nil
            return
        end

        -- Get preset or custom ID
        local preset = flag("w_sky_preset", "Piss")
        local textureId
        
        if preset == "Custom" then
            textureId = flag("w_sky_id", "")
        else
            textureId = skyPresets[preset]
        end
        
        if not textureId or textureId == "" then return end
        
        -- Only update when preset/id changes (use preset name as key for table presets)
        local currentKey = preset == "Custom" and ("Custom_" .. tostring(textureId)) or preset
        if currentKey == _G._elocate_lastSkyPreset and _G._elocate_skyObject then return end
        _G._elocate_lastSkyPreset = currentKey

        -- Create sky object if needed
        if not _G._elocate_skyObject then
            for _, v in pairs(LI:GetChildren()) do
                if v:IsA("Sky") then
                    _G._elocate_originalSky = v
                    v.Parent = nil
                    break
                end
            end
            _G._elocate_skyObject = Instance.new("Sky")
            _G._elocate_skyObject.Parent = LI
        end

        -- Apply texture ID(s) to all sides
        if type(textureId) == "table" then
            _G._elocate_skyObject.SkyboxBk = textureId.SkyboxBk
            _G._elocate_skyObject.SkyboxDn = textureId.SkyboxDn
            _G._elocate_skyObject.SkyboxFt = textureId.SkyboxFt
            _G._elocate_skyObject.SkyboxLf = textureId.SkyboxLf
            _G._elocate_skyObject.SkyboxRt = textureId.SkyboxRt
            _G._elocate_skyObject.SkyboxUp = textureId.SkyboxUp
        else
            local assetUrl = (tonumber(textureId) and "rbxassetid://" .. textureId) or textureId
            _G._elocate_skyObject.SkyboxBk = assetUrl
            _G._elocate_skyObject.SkyboxDn = assetUrl
            _G._elocate_skyObject.SkyboxFt = assetUrl
            _G._elocate_skyObject.SkyboxLf = assetUrl
            _G._elocate_skyObject.SkyboxRt = assetUrl
            _G._elocate_skyObject.SkyboxUp = assetUrl
        end
        
        -- Fix flickering: Set sun to 0 so skybox doesn't fight with lighting
        _G._elocate_skyObject.SunAngularSize = 0
        _G._elocate_skyObject.MoonAngularSize = 0
        
        if _G._elocate_notify then _G._elocate_notify("skybox: " .. preset .. " applied", 2, "good") end
    end))

    -- Skybox Spin using PreRender for smooth per-frame rotation
    trackConn(RS.PreRender:Connect(function(delta)
        if not flag("w_sky_spin", false) then return end
        local sky = _G._elocate_skyObject
        if not sky or not sky.Parent then return end
        local speed = flag("w_sky_spin_speed", 30)
        pcall(function()
            sky.SkyboxOrientation = sky.SkyboxOrientation + Vector3.new(0, speed * delta, 0)
        end)
    end))
    
    -- Tool Material & Trail - optimized to run every 5th frame
    local toolFrameCount = 0
    local lastMatEn, lastTrailEn, lastChamsEn, lastMatColor, lastMatType
    trackConn(RS.RenderStepped:Connect(function()
        toolFrameCount = toolFrameCount + 1
        if toolFrameCount % 5 ~= 0 then return end
        
        local char = LP.Character
        if not char then return end
        
        -- Cache flag values
        local matEn = flag("tool_mat_en", false)
        local trailEn = flag("tool_trail_en", false)
        local chamsEn = flag("ch_t_en", false)
        local matColor = flag("tool_mat_col", Color3.fromRGB(147,112,219))
        if flag("tool_mat_rgb", false) then matColor = getRGB(flag("tool_mat_rgb_speed", 5)) end
        local matType = flag("tool_mat_type", "Neon")
        
        local ffEn    = flag("tool_forcefield_en",  false)
        local ffColor = flag("tool_forcefield_col",  Color3.fromRGB(147,112,219))
        if flag("tool_forcefield_rgb", false) then ffColor = getRGB(flag("tool_forcefield_rgb_speed", 5) or 5) end

        -- Cleanup when all disabled
        if not matEn and not trailEn and not chamsEn and not ffEn then
            for key, data in pairs(_G._elocate_toolEffects) do
                if data.trail then pcall(function() data.trail:Destroy(); data.at0:Destroy(); data.at1:Destroy() end) end
                if data.type == "part" and data.part and data.part.Parent then 
                    pcall(function() data.part.Material = data.origMat end) 
                    pcall(function() data.part.Color = data.origColor end)
                    pcall(function() if data.part:IsA("MeshPart") then data.part.TextureID = data.origTex end end)
                elseif data.type == "mesh" and data.obj and data.obj.Parent then
                    pcall(function() data.obj.TextureId = data.origTex end)
                elseif data.type == "decal" and data.obj and data.obj.Parent then
                    pcall(function() data.obj.Transparency = data.origTrans end)
                end
                _G._elocate_toolEffects[key] = nil
            end
            return
        end
        
        for _, tool in pairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                -- Apply to ALL descendants in the tool (handle, meshes, textures, etc)
                for _, obj in pairs(tool:GetDescendants()) do
                    local key = tool.Name .. "_" .. obj.Name .. "_" .. tostring(obj)
                    if obj:IsA("BasePart") then
                        if not _G._elocate_toolEffects[key] then
                            local origTex = ""
                            if obj:IsA("MeshPart") then origTex = obj.TextureID end
                            _G._elocate_toolEffects[key] = {type="part", origMat = obj.Material, origColor = obj.Color, origTex = origTex, part = obj}
                        end
                        local data = _G._elocate_toolEffects[key]
                        local stripTex = false
                        
                        if matEn then
                            local newMat = Enum.Material[matType] or Enum.Material.Neon
                            pcall(function()
                                if data.part.Material ~= newMat then data.part.Material = newMat end
                                data.part.Color = matColor
                            end)
                            if newMat == Enum.Material.ForceField or newMat == Enum.Material.Neon then stripTex = true end
                        elseif ffEn then
                            pcall(function()
                                if data.part.Material ~= Enum.Material.ForceField then data.part.Material = Enum.Material.ForceField end
                                data.part.Color = ffColor
                            end)
                            stripTex = true
                        elseif not chamsEn then
                            pcall(function()
                                if data.part.Material ~= data.origMat then data.part.Material = data.origMat end
                                if data.part.Color ~= data.origColor then data.part.Color = data.origColor end
                            end)
                        end
                        
                        if obj:IsA("MeshPart") then
                            pcall(function()
                                if stripTex then
                                    if obj.TextureID ~= "" then obj.TextureID = "" end
                                elseif not chamsEn then
                                    if obj.TextureID ~= data.origTex then obj.TextureID = data.origTex end
                                end
                            end)
                        end
                    elseif obj:IsA("SpecialMesh") then
                        if not _G._elocate_toolEffects[key] then
                            _G._elocate_toolEffects[key] = {type="mesh", origTex = obj.TextureId, obj = obj}
                        end
                        local data = _G._elocate_toolEffects[key]
                        local stripTex = (matEn and (matType == "ForceField" or matType == "Neon")) or ffEn
                        pcall(function()
                            if stripTex then
                                if obj.TextureId ~= "" then obj.TextureId = "" end
                            elseif not chamsEn then
                                if obj.TextureId ~= data.origTex then obj.TextureId = data.origTex end
                            end
                        end)
                    elseif obj:IsA("Texture") or obj:IsA("Decal") then
                        if not _G._elocate_toolEffects[key] then
                            _G._elocate_toolEffects[key] = {type="decal", origTrans = obj.Transparency, obj = obj}
                        end
                        local data = _G._elocate_toolEffects[key]
                        local stripTex = (matEn and (matType == "ForceField" or matType == "Neon")) or ffEn
                        pcall(function()
                            if stripTex then
                                if obj.Transparency ~= 1 then obj.Transparency = 1 end
                            elseif not chamsEn then
                                if obj.Transparency ~= data.origTrans then obj.Transparency = data.origTrans end
                            end
                        end)
                    end
                end
                
                -- Trail on handle only
                local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
                if handle and handle:IsA("BasePart") then
                    local key = tool.Name .. "_handle_trail"
                    if not _G._elocate_toolEffects[key] then
                        _G._elocate_toolEffects[key] = {}
                    end
                    local data = _G._elocate_toolEffects[key]
                    
                    if trailEn then
                        if not data.trail or data.trail.Parent == nil then
                            pcall(function()
                                if data.trail then data.trail:Destroy(); data.at0:Destroy(); data.at1:Destroy() end
                            end)
                            local at0 = Instance.new("Attachment", handle)
                            local at1 = Instance.new("Attachment", handle)
                            at0.Position = Vector3.new(0, 0.2, 0)
                            at1.Position = Vector3.new(0, -0.2, 0)
                            local trail = Instance.new("Trail", handle)
                            trail.Attachment0 = at0
                            trail.Attachment1 = at1
                            trail.FaceCamera = true
                            trail.LightEmission = 1
                            data.trail = trail
                            data.at0 = at0
                            data.at1 = at1
                        end
                        if data.trail then
                            data.trail.Lifetime = flag("tool_trail_life", 1)
                            local tcol = flag("tool_trail_col", Color3.fromRGB(147,112,219))
                            if flag("tool_trail_rgb", false) then tcol = getRGB(flag("tool_trail_rgb_speed", 5) or 5) end
                            data.trail.Color = ColorSequence.new(tcol)
                            data.trail.WidthScale = NumberSequence.new(flag("tool_trail_width", 1) or 1)
                        end
                    elseif data.trail then
                        pcall(function() data.trail:Destroy(); data.at0:Destroy(); data.at1:Destroy() end)
                        data.trail = nil
                    end
                end
            end
        end
    end))
    
    -- Lighting & Fog - optimized to run every 5th frame
    local lightFogFrameCount = 0
    trackConn(RS.RenderStepped:Connect(function()
        lightFogFrameCount = lightFogFrameCount + 1
        if lightFogFrameCount % 5 ~= 0 then return end
        
        local lightEn = flag("w_light_en", false)
        
        if not lightEn then
            if _G._elocate_lastLightState ~= "off" then
                _G._elocate_lastLightState = "off"
                LI.Ambient = _G._elocate_origLighting.Ambient or LI.Ambient
                LI.OutdoorAmbient = _G._elocate_origLighting.OutdoorAmbient or LI.OutdoorAmbient
                LI.Brightness = _G._elocate_origLighting.Brightness or LI.Brightness
                LI.ClockTime = _G._elocate_origLighting.ClockTime or LI.ClockTime
            end
        else
            if not _G._elocate_origLighting.Brightness then
                _G._elocate_origLighting = {
                    Ambient = LI.Ambient,
                    OutdoorAmbient = LI.OutdoorAmbient,
                    Brightness = LI.Brightness,
                    ClockTime = LI.ClockTime
                }
            end
            
            local newAmbient = flag("w_light_ambient", Color3.fromRGB(128,128,128))
            local newOutdoor = flag("w_light_outdoor", Color3.fromRGB(128,128,128))
            local newBright = flag("w_light_bright", 2)
            local newTime = flag("w_light_time", 14)
            
            if _G._elocate_lastLightState ~= "on" or 
               LI.Ambient ~= newAmbient or 
               LI.OutdoorAmbient ~= newOutdoor or 
               LI.Brightness ~= newBright or 
               LI.ClockTime ~= newTime then
                
                _G._elocate_lastLightState = "on"
                LI.Ambient = newAmbient
                LI.OutdoorAmbient = newOutdoor
                LI.Brightness = newBright
                LI.ClockTime = newTime
            end
        end
        
        local fogOff = flag("w_fog_off", false)
        if fogOff then
            if LI.FogEnd ~= 100000 then
                LI.FogStart = 0
                LI.FogEnd = 100000
            end
        else
            local newFogEnd = flag("w_fog_end", 1000)
            local newFogCol = flag("w_fog_col", Color3.fromRGB(180,200,220))
            if LI.FogEnd ~= newFogEnd or LI.FogColor ~= newFogCol then
                LI.FogStart = 0
                LI.FogEnd = newFogEnd
                LI.FogColor = newFogCol
            end
        end
    end))
    
    -- ============================================
    -- ADVANCED COMBAT FEATURES (Fixed Desync, Optimized Tracers, Hit Sounds, Target Tracers)
    -- ============================================
    
    -- Initialize globals
    _G._elocate_desyncEnabled = false
    _G._elocate_voidHideEnabled = false
    _G._elocate_godmodeEnabled = false
    _G._elocate_processedTracers = {}
    _G._elocate_lastHitTime = 0
    _G._elocate_targetHUD = nil
    _G._elocate_targetTracer = nil
    _G._elocate_saTarget = nil
    _G._elocate_lastSaTarget = nil
    
    -- REAL DESYNC - Position Spoofing
    -- This makes server see you at different position than client
    local desyncCFrame = nil
    local realCFrame = nil
    
    local desyncFrameCount = 0
    trackConn(RS.Heartbeat:Connect(function()
        desyncFrameCount = desyncFrameCount + 1
        if desyncFrameCount % 2 ~= 0 then return end
        
        local desyncEn = flag("desync_en", false)
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then 
            desyncCFrame = nil
            realCFrame = nil
            return 
        end
        
        -- Auto desync on aim
        local autoDesync = flag("desync_auto", false)
        if autoDesync and (_G._aimTarget or _G._lastAimTarget) then
            desyncEn = true
        end
        
        if not desyncEn then
            desyncCFrame = nil
            realCFrame = nil
            return
        end
        
        local mode = flag("desync_mode", "Custom")
        local customX = flag("desync_x", 0)
        local customY = flag("desync_y", 1000)
        local customZ = flag("desync_z", 0)
        
        -- Calculate desync position
        local currentPos = hrp.Position
        local desyncPos = currentPos
        
        if mode == "Custom" then
            desyncPos = currentPos + Vector3.new(customX, customY, customZ)
        elseif mode == "God Mode" then
            -- Teleport up high to break hit registration
            desyncPos = currentPos + Vector3.new(0, 10000, 0)
        elseif mode == "Random" then
            desyncPos = currentPos + Vector3.new(
                math.random(-50, 50),
                math.random(-20, 20),
                math.random(-50, 50)
            )
        elseif mode == "Spin" then
            -- Rapid rotation breaks aim assist
            hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(180), 0)
            desyncPos = hrp.Position + Vector3.new(0, 5, 0)
        end
        
        -- Store real position
        realCFrame = hrp.CFrame
        desyncCFrame = CFrame.new(desyncPos) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
        
        -- Apply desync by setting CFrame rapidly (server sees this)
        -- We fire multiple times to ensure server gets the spoofed position
        for i = 1, 3 do
            hrp.CFrame = desyncCFrame
        end
        
        -- Immediately restore real position for client
        task.delay(0.01, function()
            if hrp and hrp.Parent and realCFrame then
                hrp.CFrame = realCFrame
            end
        end)
    end))
    
    -- Void Hide / Anti-Stomp System
    local voidFrameCount = 0
    trackConn(RS.Heartbeat:Connect(function()
        voidFrameCount = voidFrameCount + 1
        if voidFrameCount % 3 ~= 0 then return end
        
        local voidEn = flag("voidhide_en", false)
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        -- Auto hide on low HP
        local autoHide = flag("voidhide_auto", false)
        local hideHp = flag("voidhide_hp", 15)
        if autoHide and hum and hum.Health > 0 and hum.Health < (hum.MaxHealth * (hideHp / 100)) then
            voidEn = true
        end
        
        if not voidEn or not hrp then return end
        
        local hideHeight = flag("voidhide_h", -500)
        local currentPos = hrp.Position
        
        -- Store and teleport to void
        local voidPos = Vector3.new(currentPos.X, hideHeight, currentPos.Z)
        local savedCF = hrp.CFrame
        
        -- Multiple teleports to ensure server registers
        for i = 1, 5 do
            hrp.CFrame = CFrame.new(voidPos)
        end
        
        -- Restore quickly
        task.delay(0.03, function()
            if hrp and hrp.Parent then
                hrp.CFrame = savedCF
            end
        end)
    end))
    
    -- God Mode Position (Server-Sided Position Desync)
    local godmodeFrameCount = 0
    trackConn(RS.Heartbeat:Connect(function()
        godmodeFrameCount = godmodeFrameCount + 1
        if godmodeFrameCount % 2 ~= 0 then return end
        
        local godmodeEn = flag("godmode_en", false)
        if not godmodeEn then return end
        
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        local serverSided = flag("godmode_server", false)
        local currentPos = hrp.Position
        
        if serverSided then
            -- Rapid teleport to break hit registration
            hrp.CFrame = CFrame.new(currentPos + Vector3.new(0, 500, 0))
            task.wait(0.005)
            if hrp and hrp.Parent then
                hrp.CFrame = CFrame.new(currentPos)
            end
        end
    end))
    
    -- Optimized Bullet Tracers - Only process NEW bullets
    local tracerFrameCount = 0
    trackConn(RS.RenderStepped:Connect(function()
        tracerFrameCount = tracerFrameCount + 1
        if tracerFrameCount % 6 ~= 0 then return end -- Reduced frequency (every 6th frame)
        
        local tracersEn = flag("bullet_tracers", false)
        if not tracersEn then
            _G._elocate_processedTracers = {}
            return
        end
        
        local char = LP.Character
        local tool = char and char:FindFirstChildWhichIsA("Tool")
        if not tool then 
            _G._elocate_processedTracers = {}
            return 
        end
        
        -- Look for bullet rays in workspace/Ignored
        local ignored = workspace:FindFirstChild("Ignored") or workspace
        local descendants = ignored:GetDescendants()
        
        -- Limit processing to avoid lag
        local processedCount = 0
        local maxProcess = 20 -- Only process 20 bullets per frame
        
        for _, v in pairs(descendants) do
            if processedCount >= maxProcess then break end
            
            if v.Name == "BULLET_RAYS" or v.Name:find("BULLET") or v.Name:find("Ray") then
                -- Skip if already processed
                if _G._elocate_processedTracers[v] then continue end
                _G._elocate_processedTracers[v] = true
                processedCount = processedCount + 1
                
                local beam = v:FindFirstChild("GunBeam") or v:FindFirstChild("Beam")
                if beam and beam:IsA("Beam") then
                    local tracerColor = flag("tracer_col", Color3.fromRGB(255, 215, 0))
                    local tracerWidth = flag("tracer_w", 1)
                    local fadeEn = flag("tracer_fade", true)
                    
                    beam.Color = ColorSequence.new(tracerColor)
                    beam.Width0 = tracerWidth
                    beam.Width1 = tracerWidth * 0.5
                    
                    if fadeEn then
                        beam.Transparency = NumberSequence.new(0, 1)
                    else
                        beam.Transparency = NumberSequence.new(0.3, 0.3)
                    end
                end
            end
        end
        
        -- Cleanup old processed entries periodically
        if tracerFrameCount % 60 == 0 then
            local newProcessed = {}
            for obj, _ in pairs(_G._elocate_processedTracers) do
                if obj and obj.Parent then
                    newProcessed[obj] = true
                end
            end
            _G._elocate_processedTracers = newProcessed
        end
    end))
    
    -- Hit Sounds System - YOUR SOUND IDs
    local soundPresets = {
        ["Bameware"] = "rbxassetid://3124331820",
        ["Bell"] = "rbxassetid://6534947240",
        ["Bubble"] = "rbxassetid://6534947588",
        ["Pick"] = "rbxassetid://1347140027",
        ["Pop"] = "rbxassetid://198598793",
        ["Rust"] = "rbxassetid://1255040462",
        ["Sans"] = "rbxassetid://3188795283",
        ["Fart"] = "rbxassetid://130833677",
        ["Big"] = "rbxassetid://5332005053",
        ["Vine"] = "rbxassetid://5332680810",
        ["Bruh"] = "rbxassetid://4578740568",
        ["Skeet"] = "rbxassetid://5633695679",
        ["Neverlose"] = "rbxassetid://6534948092",
        ["Fatality"] = "rbxassetid://6534947869",
        ["Bonk"] = "rbxassetid://5766898159",
        ["Minecraft"] = "rbxassetid://4018616850"
    }
    
    local function playHitSound()
        local soundEn = flag("hit_sound", false)
        if not soundEn then return end
        
        -- Rate limiting
        if tick() - _G._elocate_lastHitTime < 0.05 then return end
        _G._elocate_lastHitTime = tick()
        
        local preset = flag("hit_sound_type", "Bell")
        local volume = flag("hit_vol", 5)
        local customId = flag("hit_sound_id", "")
        
        local soundId = (customId and customId ~= "") and ("rbxassetid://" .. customId) or soundPresets[preset]
        if not soundId then return end
        
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = math.clamp(volume / 10, 0.1, 10)
        sound.TimePosition = 0
        sound.Parent = workspace
        sound:Play()
        
        task.delay(2, function()
            pcall(function() sound:Destroy() end)
        end)
    end
    
    local targetHealthCache = {}
    local _lastShotTime = 0
    local _hasGunEquipped = false
    
    trackConn(UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local char = LP.Character
            if char and char:FindFirstChildOfClass("Tool") then
                _lastShotTime = tick()
                _hasGunEquipped = true
            end
        end
    end))
    
    trackConn(RS.Heartbeat:Connect(function()
        if not flag("hit_sound", false) then return end
        
        local char = LP.Character
        if not char or not char:FindFirstChildOfClass("Tool") then
            _hasGunEquipped = false
            return
        end
        
        if tick() - _lastShotTime > 0.25 then return end
        
        for _, player in pairs(PL:GetPlayers()) do
            if player ~= LP then
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local currentHealth = hum.Health
                    local cachedHealth = targetHealthCache[player] or currentHealth
                    
                    if currentHealth < cachedHealth - 0.01 then
                        playHitSound()
                    end
                    
                    targetHealthCache[player] = currentHealth
                end
            end
        end
    end))
    
    local _targetTracerLine = nil
    local _targetTracerHead = nil
    local function updateTargetTracer(target, isSilentAim)
        local tracerEn = flag("aim_target_tracer", false) or flag("sa_target_tracer", false)
        if not tracerEn or not target or not target.Parent then
            pcall(function() if _targetTracerLine then _targetTracerLine.Visible = false end end)
            pcall(function() if _targetTracerHead then _targetTracerHead.Visible = false end end)
            return
        end
        
        local lpChar = LP.Character
        local lpHrp = lpChar and lpChar:FindFirstChild("HumanoidRootPart")
        if not lpHrp then return end
        
        local targetPos = target.Position
        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPos)
        local lpScreenPos = Camera:WorldToViewportPoint(lpHrp.Position)
        
        if not _targetTracerLine then
            local ok1, line = pcall(Drawing.New, "Line")
            if ok1 then
                line.Thickness = 2
                line.Transparency = 0.8
                _targetTracerLine = line
            end
        end
        if not _targetTracerHead then
            local ok2, circle = pcall(Drawing.New, "Circle")
            if ok2 then
                circle.Radius = 5
                circle.Filled = true
                circle.Thickness = 1
                _targetTracerHead = circle
            end
        end
        
        local tracerCol
        if isSilentAim then
            tracerCol = flag("sa_tracer_col", Color3.fromRGB(255, 80, 80))
        else
            tracerCol = flag("aim_tracer_col", Color3.fromRGB(147, 112, 219))
        end
        
        if _targetTracerLine then
            _targetTracerLine.Visible = onScreen
            _targetTracerLine.Color = tracerCol
            _targetTracerLine.From = Vector2.new(lpScreenPos.X, lpScreenPos.Y)
            _targetTracerLine.To = Vector2.new(screenPos.X, screenPos.Y)
        end
        
        if _targetTracerHead then
            _targetTracerHead.Visible = onScreen
            _targetTracerHead.Color = tracerCol
            _targetTracerHead.Position = Vector2.new(screenPos.X, screenPos.Y)
        end
    end
    
    local function createTargetHUD()
        if _G._elocate_targetHUD then
            pcall(function() _G._elocate_targetHUD:Destroy() end)
        end
        
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "_elocate_target_hud"
        screenGui.ResetOnSpawn = false
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screenGui.DisplayOrder = 1000
        screenGui.Parent = game:GetService("CoreGui")
        _G._elocate_targetHUD = screenGui
        
        local frame = Instance.new("Frame")
        frame.Name = "TargetFrame"
        frame.Size = UDim2.new(0, 280, 0, 120)
        frame.Position = UDim2.new(0.5, -140, 0.85, 0)
        frame.BackgroundColor3 = Color3.fromRGB(22, 16, 32)
        frame.BorderSizePixel = 0
        frame.Visible = false
        frame.Parent = screenGui
        
        local frameGrad = Instance.new("UIGradient", frame)
        frameGrad.Rotation = 90
        frameGrad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 30, 60)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 16, 32))
        }
        
        local stroke = Instance.new("UIStroke", frame)
        stroke.Color = Color3.fromRGB(100, 80, 140)
        stroke.Thickness = 1
        
        local accentBar = Instance.new("Frame", frame)
        accentBar.Name = "AccentBar"
        accentBar.Size = UDim2.new(1, 0, 0, 2)
        accentBar.BackgroundColor3 = Color3.fromRGB(147, 112, 219)
        accentBar.BorderSizePixel = 0
        
        local glow = Instance.new("ImageLabel", frame)
        glow.Name = "Glow"
        glow.Size = UDim2.new(1, 20, 1, 20)
        glow.Position = UDim2.new(0, -10, 0, -10)
        glow.BackgroundTransparency = 1
        glow.Image = "rbxassetid://7336307204"
        glow.ImageColor3 = Color3.fromRGB(147, 112, 219)
        glow.ImageTransparency = 0.85
        glow.ScaleType = Enum.ScaleType.Slice
        glow.SliceCenter = Rect.new(10, 10, 10, 10)
        
        local titleBar = Instance.new("Frame", frame)
        titleBar.Name = "TitleBar"
        titleBar.Size = UDim2.new(1, 0, 0, 24)
        titleBar.BackgroundTransparency = 1
        titleBar.Position = UDim2.new(0, 0, 0, 2)
        
        local title = Instance.new("TextLabel", titleBar)
        title.Name = "Title"
        title.Position = UDim2.new(0, 12, 0, 4)
        title.Size = UDim2.new(1, -24, 0, 16)
        title.BackgroundTransparency = 1
        title.Text = "TARGET"
        title.TextColor3 = Color3.fromRGB(200, 200, 210)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 13
        title.TextXAlignment = Enum.TextXAlignment.Left
        
        local typeLabel = Instance.new("TextLabel", titleBar)
        typeLabel.Name = "TypeLabel"
        typeLabel.Position = UDim2.new(1, -70, 0, 4)
        typeLabel.Size = UDim2.new(0, 60, 0, 16)
        typeLabel.BackgroundTransparency = 1
        typeLabel.Text = "AIMBOT"
        typeLabel.TextColor3 = Color3.fromRGB(147, 112, 219)
        typeLabel.Font = Enum.Font.Gotham
        typeLabel.TextSize = 11
        typeLabel.TextXAlignment = Enum.TextXAlignment.Right
        
        local contentFrame = Instance.new("Frame", frame)
        contentFrame.Name = "Content"
        contentFrame.Position = UDim2.new(0, 12, 0, 28)
        contentFrame.Size = UDim2.new(1, -24, 1, -36)
        contentFrame.BackgroundTransparency = 1
        
        local avatarFrame = Instance.new("Frame", contentFrame)
        avatarFrame.Name = "AvatarFrame"
        avatarFrame.Position = UDim2.new(0, 0, 0, 0)
        avatarFrame.Size = UDim2.new(0, 50, 0, 50)
        avatarFrame.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
        avatarFrame.BorderSizePixel = 0
        
        local avatarImage = Instance.new("ImageLabel", avatarFrame)
        avatarImage.Name = "AvatarImage"
        avatarImage.Size = UDim2.new(1, -4, 1, -4)
        avatarImage.Position = UDim2.new(0, 2, 0, 2)
        avatarImage.BackgroundTransparency = 1
        avatarImage.Image = "rbxasset://textures/ui/PlayerBackgroundDefault.png"
        
        local infoFrame = Instance.new("Frame", contentFrame)
        infoFrame.Name = "InfoFrame"
        infoFrame.Position = UDim2.new(0, 58, 0, 0)
        infoFrame.Size = UDim2.new(1, -58, 1, 0)
        infoFrame.BackgroundTransparency = 1
        
        local displayNameLabel = Instance.new("TextLabel", infoFrame)
        displayNameLabel.Name = "DisplayName"
        displayNameLabel.Size = UDim2.new(1, 0, 0, 18)
        displayNameLabel.BackgroundTransparency = 1
        displayNameLabel.Text = "Player"
        displayNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        displayNameLabel.Font = Enum.Font.GothamBold
        displayNameLabel.TextSize = 14
        displayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local usernameLabel = Instance.new("TextLabel", infoFrame)
        usernameLabel.Name = "Username"
        usernameLabel.Position = UDim2.new(0, 0, 0, 18)
        usernameLabel.Size = UDim2.new(1, 0, 0, 14)
        usernameLabel.BackgroundTransparency = 1
        usernameLabel.Text = "@username"
        usernameLabel.TextColor3 = Color3.fromRGB(160, 160, 170)
        usernameLabel.Font = Enum.Font.Gotham
        usernameLabel.TextSize = 10
        usernameLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        -- Distance
        local distLabel = Instance.new("TextLabel", infoFrame)
        distLabel.Name = "Distance"
        distLabel.Position = UDim2.new(0, 0, 0, 26)
        distLabel.Size = UDim2.new(1, 0, 0, 12)
        distLabel.BackgroundTransparency = 1
        distLabel.Text = "0m"
        distLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
        distLabel.Font = Enum.Font.Gotham
        distLabel.TextSize = 10
        distLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        -- Health bar background
        local healthBg = Instance.new("Frame", infoFrame)
        healthBg.Name = "HealthBg"
        healthBg.Position = UDim2.new(0, 0, 0, 42)
        healthBg.Size = UDim2.new(1, 0, 0, 6)
        healthBg.BackgroundColor3 = Color3.fromRGB(40, 35, 50)
        healthBg.BorderSizePixel = 0
        
        -- Health bar fill
        local healthFill = Instance.new("Frame", healthBg)
        healthFill.Name = "HealthFill"
        healthFill.Size = UDim2.new(1, 0, 1, 0)
        healthFill.BackgroundColor3 = Color3.fromRGB(76, 200, 120)
        healthFill.BorderSizePixel = 0
        
        -- Health text
        local healthText = Instance.new("TextLabel", healthBg)
        healthText.Name = "HealthText"
        healthText.Size = UDim2.new(1, 0, 1, 0)
        healthText.BackgroundTransparency = 1
        healthText.Text = "100/100"
        healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
        healthText.Font = Enum.Font.GothamBold
        healthText.TextSize = 8
        
        -- Hit part indicator
        local hitPartLabel = Instance.new("TextLabel", infoFrame)
        hitPartLabel.Name = "HitPart"
        hitPartLabel.Position = UDim2.new(0, 0, 0, 52)
        hitPartLabel.Size = UDim2.new(1, 0, 0, 12)
        hitPartLabel.BackgroundTransparency = 1
        hitPartLabel.Text = "head"
        hitPartLabel.TextColor3 = Color3.fromRGB(147, 112, 219)
        hitPartLabel.Font = Enum.Font.Gotham
        hitPartLabel.TextSize = 10
        hitPartLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        return screenGui
    end
    
    -- Create the HUD
    createTargetHUD()
    
    -- Update Target HUD
    local hudFrameCount = 0
    trackConn(RS.RenderStepped:Connect(function()
        hudFrameCount = hudFrameCount + 1
        if hudFrameCount % 3 ~= 0 then return end
        
        local hudEn = flag("aim_target_hud", false) or flag("sa_target_hud", false)
        local screenGui = _G._elocate_targetHUD
        if not screenGui then return end
        
        local frame = screenGui:FindFirstChild("TargetFrame")
        if not frame then return end
        
        -- Get current aim target (check both aimbot and silent aim)
        local aimTarget = _G._aimTarget or _G._lastAimTarget
        local saTarget = _G._saTarget
        local target = aimTarget or saTarget
        local isSilentAim = saTarget and not aimTarget
        
        local aimEnabled = flag("aim_enabled", false)
        local saEnabled = flag("sa_enabled", false)
        
        -- Update tracer
        updateTargetTracer(target, isSilentAim)
        
        if not hudEn or (not aimEnabled and not saEnabled) or not target or not target.Parent then
            frame.Visible = false
            return
        end
        
        local targetChar = target.Parent
        local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
        local targetPlayer = PL:GetPlayerFromCharacter(targetChar)
        
        if not targetHum or targetHum.Health <= 0 then
            frame.Visible = false
            return
        end
        
        -- Show HUD
        frame.Visible = true
        
        -- Update type label
        local titleBar = frame:FindFirstChild("TitleBar")
        local typeLabel = titleBar and titleBar:FindFirstChild("TypeLabel")
        if typeLabel then
            typeLabel.Text = isSilentAim and "silent" or "aimbot"
            typeLabel.TextColor3 = isSilentAim and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(147, 112, 219)
        end
        
        -- Update avatar
        local contentFrame = frame:FindFirstChild("Content")
        local avatarFrame = contentFrame and contentFrame:FindFirstChild("AvatarFrame")
        local avatarImage = avatarFrame and avatarFrame:FindFirstChild("AvatarImage")
        if avatarImage and targetPlayer then
            local userId = targetPlayer.UserId
            avatarImage.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..userId.."&width=150&height=150&format=png"
        end
        
        -- Update info
        local infoFrame = contentFrame and contentFrame:FindFirstChild("InfoFrame")
        local displayNameLabel = infoFrame and infoFrame:FindFirstChild("DisplayName")
        local usernameLabel = infoFrame and infoFrame:FindFirstChild("Username")
        local distLabel = infoFrame and infoFrame:FindFirstChild("Distance")
        local healthBg = infoFrame and infoFrame:FindFirstChild("HealthBg")
        local hitPartLabel = infoFrame and infoFrame:FindFirstChild("HitPart")
        
        if displayNameLabel then
            local displayName = targetPlayer and targetPlayer.DisplayName or targetChar.Name
            displayNameLabel.Text = displayName
        end
        
        if usernameLabel then
            local username = targetPlayer and ("@" .. targetPlayer.Name) or "@npc"
            usernameLabel.Text = username
        end
        
        if distLabel then
            local lpChar = LP.Character
            local lpHrp = lpChar and lpChar:FindFirstChild("HumanoidRootPart")
            if lpHrp then
                local dist = (lpHrp.Position - target.Position).Magnitude
                distLabel.Text = string.format("%.0fm", dist)
            end
        end
        
        if healthBg then
            local healthFill = healthBg:FindFirstChild("HealthFill")
            local healthText = healthBg:FindFirstChild("HealthText")
            local maxHealth = targetHum.MaxHealth
            local health = math.max(0, targetHum.Health)
            local healthPercent = health / maxHealth
            
            if healthFill then
                healthFill.Size = UDim2.new(healthPercent, 0, 1, 0)
                if healthPercent > 0.6 then
                    healthFill.BackgroundColor3 = Color3.fromRGB(76, 200, 120)
                elseif healthPercent > 0.3 then
                    healthFill.BackgroundColor3 = Color3.fromRGB(255, 200, 80)
                else
                    healthFill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
                end
            end
            
            if healthText then
                healthText.Text = string.format("%.0f/%.0f", health, maxHealth)
            end
        end
        
        if hitPartLabel then
            local hitPart = isSilentAim and flag("sa_hitpart", "Head") or flag("aim_hp_default", "Head")
            hitPartLabel.Text = hitPart:lower()
        end
    end))
    
    -- ============================================
    -- DA HOOD SKIN CHANGER FUNCTIONS
    -- ============================================
    
    -- Bullet beam codes lookup
    local bulletBeamCodes = {
        ["DoubleBarrel"] = "109d1326878cc594bc1bb42d126250810999782f",
        ["Revolver"] = "539db315b53f77390c0aa74773158e25bedcdd6e",
        ["Shotgun"] = "b415a7273aa86cbc2adc445fde5435eb5afababa",
        ["SMG"] = "005af87725b42ac4ca8103d11af6bf0c7d55f7b3",
        ["TacticalShotgun"] = "109d1326878cc594bc1bb42d126250810999782f"
    }
    
    -- Apply bullet beams to equipped weapons
    _G.applyBulletSkins = function()
        local bulletSkin = flag("bullet_beam_skin", "Rainbow")
        local dataFolder = LP:FindFirstChild("DataFolder")
        if not dataFolder then return end
        
        local bulletBeams = dataFolder:FindFirstChild("BulletBeams")
        local equippedBulletBeams = dataFolder:FindFirstChild("EquippedBulletBeams")
        
        if bulletBeams and bulletBeams:IsA("StringValue") then
            local bulletBeamData = {}
            for weapon, code in pairs(bulletBeamCodes) do
                bulletBeamData[code] = { Name = bulletSkin }
            end
            local ok, json = pcall(game.HttpService.JSONEncode, game.HttpService, bulletBeamData)
            if ok then bulletBeams.Value = json end
        end
        
        if equippedBulletBeams and equippedBulletBeams:IsA("StringValue") then
            local equippedData = {}
            equippedData["[DoubleBarrel]"] = bulletBeamCodes["DoubleBarrel"]
            equippedData["[Revolver]"] = bulletBeamCodes["Revolver"]
            equippedData["[TacticalShotgun]"] = bulletBeamCodes["TacticalShotgun"]
            equippedData["[SMG]"] = bulletBeamCodes["SMG"]
            equippedData["[Shotgun]"] = bulletBeamCodes["Shotgun"]
            local ok, json = pcall(game.HttpService.JSONEncode, game.HttpService, equippedData)
            if ok then equippedBulletBeams.Value = json end
        end
    end
    
    -- Spoof subscription for premium unlocks
    _G.spoofSubscription = function()
        local dataFolder = LP:FindFirstChild("DataFolder")
        if not dataFolder then return end
        
        local subFolder = dataFolder:FindFirstChild("Subscription")
        if subFolder then
            local hasSub = subFolder:FindFirstChild("HasSubscription")
            local subData = subFolder:FindFirstChild("SubscriptionData")
            local subStreak = subFolder:FindFirstChild("SubscriptionStreak")
            
            if hasSub and hasSub:IsA("BoolValue") then hasSub.Value = true end
            if subData and subData:IsA("NumberValue") then subData.Value = 16 end
            if subStreak and subStreak:IsA("NumberValue") then subStreak.Value = 53 end
        end
    end
    
    -- Weld skin model to weapon handle
    local function weldSkin(originalWeapon, newModel)
        local handle = originalWeapon:FindFirstChild("Handle")
        if not handle then return end
        
        local clone = newModel:Clone()
        if not clone.PrimaryPart then return end
        
        for _, part in ipairs(clone:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                part.Anchored = false
                part.Massless = true
                part.Transparency = 0
            end
        end
        
        clone.Parent = originalWeapon
        
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = handle
        weld.Part1 = clone.PrimaryPart
        weld.Parent = handle
        
        clone:SetPrimaryPartCFrame(handle.CFrame)
        handle.Transparency = 1
    end
    
    -- Apply gun and knife skins
    _G.applySkinChanger = function()
        local BP = LP:FindFirstChild("Backpack")
        if not BP then return end
        
        local gunSkin = flag("gun_skin", "Ascension")
        local knifeSkin = flag("knife_skin", "Beta")
        local RS = game:GetService("ReplicatedStorage")
        local wraps = RS:FindFirstChild("Wraps")
        local knives = RS:FindFirstChild("Knives")
        
        -- Apply gun skins
        local gunList = {"DoubleBarrel","Revolver","TacticalShotgun","SMG","Shotgun"}
        for _, gunName in ipairs(gunList) do
            local weapon = BP:FindFirstChild("["..gunName.."]")
            if weapon and wraps then
                local skinFolder = wraps:FindFirstChild("["..gunName.."]")
                if skinFolder then
                    local skinModel = skinFolder:FindFirstChild(gunSkin)
                    if skinModel then
                        weldSkin(weapon, skinModel)
                    end
                end
            end
        end
        
        -- Apply knife skin
        local knife = BP:FindFirstChild("[Knife]")
        if knife and knives then
            local skinModel = knives:FindFirstChild(knifeSkin)
            if skinModel then
                weldSkin(knife, skinModel)
            end
        end
    end
    
    -- Auto apply on character spawn
    trackConn(LP.CharacterAdded:Connect(function()
        task.wait(1)
        if flag("skin_changer_en", false) then
            pcall(_G.applySkinChanger)
        end
        if flag("bullet_skin_en", false) then
            pcall(_G.applyBulletSkins)
        end
    end))
end

-- Special Visual Effects
do
    local RS = game:GetService("RunService")
    local LP = game:GetService("Players").LocalPlayer
    local flag = function(n, d) return Library.Flags[n] or d end
    local function trackConn(conn) table.insert(_G._elocate_connections, conn); return conn end
    
    -- Rain Effect
    local rainPart, rainEmit
    trackConn(RS.RenderStepped:Connect(function()
        local rainEn = flag("w_rain_en", false)
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if rainEn and hrp then
            if not rainPart or not rainPart.Parent then
                rainPart = Instance.new("Part")
                rainPart.Name = "_elocate_rain"
                rainPart.Transparency = 1
                rainPart.CanCollide = false
                rainPart.Anchored = true
                rainPart.Size = Vector3.new(60, 2, 60)
                rainEmit = Instance.new("ParticleEmitter")
                rainEmit.Texture = "rbxassetid://152431631"
                rainEmit.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255))
                rainEmit.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.2)})
                rainEmit.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.8)})
                rainEmit.Speed = NumberRange.new(80, 100)
                rainEmit.EmissionDirection = Enum.NormalId.Bottom
                rainEmit.Lifetime = NumberRange.new(1.5)
                rainEmit.Rate = 0
                rainEmit.Parent = rainPart
                rainPart.Parent = Workspace
                table.insert(_G._elocate_connections, {Disconnect = function() pcall(function() rainPart:Destroy() end) end})
            end
            rainPart.CFrame = hrp.CFrame + Vector3.new(0, 50, 0)
            rainEmit.Rate = flag("w_rain_amt", 100) * 2
        else
            if rainPart then pcall(function() rainPart:Destroy() end); rainPart = nil; rainEmit = nil end
        end
    end))
    
    -- Post Processing
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "_elocate_cc"
    local bloom = Instance.new("BloomEffect")
    bloom.Name = "_elocate_bloom"
    table.insert(_G._elocate_connections, {Disconnect = function() pcall(function() cc:Destroy(); bloom:Destroy() end) end})
    trackConn(RS.RenderStepped:Connect(function()
        local lighting = game:GetService("Lighting")
        if flag("w_cc_en", false) then
            if cc.Parent ~= lighting then cc.Parent = lighting end
            cc.Saturation = flag("w_cc_sat", 5) / 10
            cc.Contrast = flag("w_cc_con", 2) / 10
            cc.Brightness = flag("w_cc_bri", 0) / 10
        else
            if cc.Parent then cc.Parent = nil end
        end
        if flag("w_bloom_en", false) then
            if bloom.Parent ~= lighting then bloom.Parent = lighting end
            bloom.Intensity = flag("w_bloom_int", 1)
            bloom.Size = flag("w_bloom_sz", 24)
            bloom.Threshold = flag("w_bloom_thr", 2) / 10
        else
            if bloom.Parent then bloom.Parent = nil end
        end
    end))
    
    -- Hit Numbers
    local lastHp = {}
    local rng = Random.new()
    trackConn(RS.Heartbeat:Connect(function()
        if not flag("esp_hitnum", false) then return end
        for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
            if plr ~= LP then
                local char = plr.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hum and hrp then
                    local chp = hum.Health
                    local oldhp = lastHp[plr] or hum.MaxHealth
                    if chp < oldhp and chp > 0 then
                        local dmg = math.floor(oldhp - chp)
                        if dmg > 0 then
                            local bg = Instance.new("BillboardGui")
                            bg.Name = "_elocate_dmg"
                            bg.Size = UDim2.new(0, 50, 0, 50)
                            bg.StudsOffset = Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(1, 3), rng:NextNumber(-2, 2))
                            bg.Adornee = hrp
                            bg.AlwaysOnTop = true
                            local txt = Instance.new("TextLabel", bg)
                            txt.Size = UDim2.new(1, 0, 1, 0)
                            txt.BackgroundTransparency = 1
                            txt.Text = "-" .. tostring(dmg)
                            txt.TextColor3 = flag("esp_hitnum_col", Color3.fromRGB(255,50,50))
                            txt.TextStrokeTransparency = 0
                            txt.TextScaled = true
                            txt.Font = Enum.Font.GothamBold
                            bg.Parent = Workspace
                            game:GetService("TweenService"):Create(bg, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {StudsOffset = bg.StudsOffset + Vector3.new(0, 3, 0)}):Play()
                            game:GetService("TweenService"):Create(txt, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
                            game:GetService("Debris"):AddItem(bg, 1.5)
                        end
                    end
                    lastHp[plr] = chp
                else
                    lastHp[plr] = nil
                end
            else
                lastHp[plr] = nil
            end
        end
    end))
    
    -- Ghost Trail
    local ghostFrameCount = 0
    trackConn(RS.Heartbeat:Connect(function()
        ghostFrameCount = ghostFrameCount + 1
        if ghostFrameCount % math.max(1, flag("ghost_delay", 5)) ~= 0 then return end
        if not flag("ghost_en", false) then return end
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or hrp.AssemblyLinearVelocity.Magnitude < 2 then return end
        char.Archivable = true
        local clone = char:Clone()
        char.Archivable = false
        if not clone then return end
        for _, v in ipairs(clone:GetDescendants()) do
            if v:IsA("Script") or v:IsA("LocalScript") then v:Destroy() end
            if v:IsA("BasePart") then
                v.Anchored = true
                v.CanCollide = false
                v.Material = Enum.Material.ForceField
                v.Color = flag("ghost_col", Color3.fromRGB(147,112,219))
            end
            if v:IsA("Decal") or v:IsA("Texture") then v:Destroy() end
        end
        clone.Parent = Workspace
        local dur = flag("ghost_dur", 1)
        for _, v in ipairs(clone:GetDescendants()) do
            if v:IsA("BasePart") then
                game:GetService("TweenService"):Create(v, TweenInfo.new(dur, Enum.EasingStyle.Linear), {Transparency = 1}):Play()
            end
        end
        game:GetService("Debris"):AddItem(clone, dur)
    end))

    -- Animation Changer
    local anims = {
        ["Mage"] = {Idle = "rbxassetid://616006778", Walk = "rbxassetid://616013216", Run = "rbxassetid://616013216", Jump = "rbxassetid://616008936", Fall = "rbxassetid://616005863"},
        ["Zombie"] = {Idle = "rbxassetid://616158929", Walk = "rbxassetid://616168032", Run = "rbxassetid://616163682", Jump = "rbxassetid://616161124", Fall = "rbxassetid://616157476"},
        ["Ninja"] = {Idle = "rbxassetid://656117400", Walk = "rbxassetid://656121766", Run = "rbxassetid://656118852", Jump = "rbxassetid://656117878", Fall = "rbxassetid://656115606"},
        ["Superhero"] = {Idle = "rbxassetid://782841498", Walk = "rbxassetid://782843345", Run = "rbxassetid://782842708", Jump = "rbxassetid://782847020", Fall = "rbxassetid://782846423"},
        ["Vampire"] = {Idle = "rbxassetid://1083445855", Walk = "rbxassetid://1083473930", Run = "rbxassetid://1083462077", Jump = "rbxassetid://1083455352", Fall = "rbxassetid://1083448110"},
        ["Werewolf"] = {Idle = "rbxassetid://1083195517", Walk = "rbxassetid://1083214717", Run = "rbxassetid://1083216690", Jump = "rbxassetid://1083218792", Fall = "rbxassetid://1083214005"},
        ["Pirate"] = {Idle = "rbxassetid://750781874", Walk = "rbxassetid://750785693", Run = "rbxassetid://750784481", Jump = "rbxassetid://750782230", Fall = "rbxassetid://750780242"},
        ["Astronaut"] = {Idle = "rbxassetid://891621366", Walk = "rbxassetid://891636393", Run = "rbxassetid://891633237", Jump = "rbxassetid://891626283", Fall = "rbxassetid://891624390"},
        ["Robot"] = {Idle = "rbxassetid://616088211", Walk = "rbxassetid://616095330", Run = "rbxassetid://616091570", Jump = "rbxassetid://616090535", Fall = "rbxassetid://616087442"},
        ["Sneaky"] = {Idle = "rbxassetid://1132473842", Walk = "rbxassetid://1132510127", Run = "rbxassetid://1132490053", Jump = "rbxassetid://1132481180", Fall = "rbxassetid://1132469004"}
    }
    local oldAnims = {}
    trackConn(RS.Heartbeat:Connect(function()
        local char = LP.Character
        local animate = char and char:FindFirstChild("Animate")
        if animate then
            if flag("anim_en", false) then
                local selected = {
                    Idle = anims[flag("anim_idle", "Mage")] and anims[flag("anim_idle", "Mage")].Idle,
                    Walk = anims[flag("anim_walk", "Mage")] and anims[flag("anim_walk", "Mage")].Walk,
                    Run  = anims[flag("anim_run", "Mage")]  and anims[flag("anim_run", "Mage")].Run,
                    Jump = anims[flag("anim_jump", "Mage")] and anims[flag("anim_jump", "Mage")].Jump,
                    Fall = anims[flag("anim_fall", "Mage")] and anims[flag("anim_fall", "Mage")].Fall,
                }
                for state, id in pairs(selected) do
                    local st = animate:FindFirstChild(string.lower(state))
                    if st then
                        for _, animObj in ipairs(st:GetChildren()) do
                            if animObj:IsA("Animation") then
                                if not oldAnims[animObj] then oldAnims[animObj] = animObj.AnimationId end
                                if id then
                                    if animObj.AnimationId ~= id then animObj.AnimationId = id end
                                else
                                    if animObj.AnimationId ~= oldAnims[animObj] then animObj.AnimationId = oldAnims[animObj] end
                                end
                            end
                        end
                    end
                end
            else
                for animObj, origId in pairs(oldAnims) do
                    if animObj and animObj.Parent then
                        if animObj.AnimationId ~= origId then animObj.AnimationId = origId end
                    end
                end
            end
        end
    end))
end

-- Input handling
do
    local UIS = game:GetService("UserInputService")
    UIS.InputBegan:Connect(function(input, gpe)
        pcall(function()
            if input.KeyCode == Enum.KeyCode.Insert then
                local currentOpen = Library.Open or false
                Library:SetOpen(not currentOpen)
            elseif not gpe and input.KeyCode == Enum.KeyCode.End then
                -- Deep destroy all UI elements
                pcall(function() if Library.ScreenGui then Library.ScreenGui:Destroy() end end)
                pcall(function() if _WidgetGui then _WidgetGui:Destroy() end end)
                pcall(function() if Library._PopupGui then Library._PopupGui:Destroy() end end)
                
                -- Cleanup core coregui leftovers
                local coreGui = game:GetService("CoreGui")
                for _, h in next, coreGui:GetChildren() do
                    if tostring(h.Name):sub(1,9) == "_elocate" then pcall(function() h:Destroy() end) end
                end
                
                -- Disconnect all runtime loops
                for _, c in next, (Library.Connections or {}) do pcall(function() c:Disconnect() end) end
                for _, c in ipairs(_G._elocate_connections or {}) do pcall(function() c:Disconnect() end) end
                if _G._elocate_main_loop then pcall(function() _G._elocate_main_loop:Disconnect() end) end
                
                -- Restore tool materials and meshes
                if _G._elocate_toolEffects then
                    for key, data in pairs(_G._elocate_toolEffects) do
                        if data.trail then pcall(function() data.trail:Destroy(); data.at0:Destroy(); data.at1:Destroy() end) end
                        if data.type == "part" and data.part and data.part.Parent then 
                            pcall(function() data.part.Material = data.origMat end) 
                            pcall(function() data.part.Color = data.origColor end)
                            pcall(function() if data.part:IsA("MeshPart") then data.part.TextureID = data.origTex end end)
                        elseif data.type == "mesh" and data.obj and data.obj.Parent then
                            pcall(function() data.obj.TextureId = data.origTex end)
                        elseif data.type == "decal" and data.obj and data.obj.Parent then
                            pcall(function() data.obj.Transparency = data.origTrans end)
                        end
                        _G._elocate_toolEffects[key] = nil
                    end
                end
                
                -- Destroy player and tool highlights
                if _G._elocate_chams_list then
                    for plr, hl in pairs(_G._elocate_chams_list) do
                        if hl then pcall(function() hl:Destroy() end) end
                    end
                end
                if _G._elocate_tool_hls_list then
                    for tool, hl in pairs(_G._elocate_tool_hls_list) do
                        if hl then pcall(function() hl:Destroy() end) end
                    end
                end
            end
        end)
    end)
end
if not ok then
    warn("[elocate.lol] load error: "..tostring(err))
end

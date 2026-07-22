sub Init()
    try
        InitReal()
    catch e
        ShowFatalError(e)
    end try
end sub

' Renders a runtime Init error full-screen so failures are visible WITHOUT a device
' console. Removed once the startup issue is resolved.
sub ShowFatalError(e as Object)
    bg = m.top.CreateChild("Rectangle")
    bg.color = "0x140F0AFF"
    bg.width = 1920
    bg.height = 1080

    title = m.top.CreateChild("Label")
    title.translation = [120, 120]
    title.width = 1680
    title.color = "0xF3D389FF"
    title.text = "Startup error (diagnostic build)"

    body = m.top.CreateChild("Label")
    body.translation = [120, 220]
    body.width = 1680
    body.height = 760
    body.wrap = true
    body.color = "0xFFFFFFFF"
    msg = "message: "
    if e <> invalid and e.message <> invalid then msg = msg + e.message
    if e <> invalid and e.number <> invalid then msg = msg + Chr(10) + "number: " + Str(e.number)
    bt = ""
    if e <> invalid and e.backtrace <> invalid
        for each fr in e.backtrace
            fn = ""
            ln = ""
            if fr.function <> invalid then fn = fr.function
            if fr.line_number <> invalid then ln = Str(fr.line_number)
            bt = bt + Chr(10) + "  " + fn + " : line " + ln
        end for
    end if
    body.text = msg + Chr(10) + Chr(10) + "backtrace:" + bt

    m.top.SetFocus(true)
end sub

sub InitReal()
    Rnd(0)
    m.splashActive = false
    m.theme = Theme()
    m.humidor = HumidorTheme()
    m.cfg = ApiConfig()

    m.bg = m.top.CreateChild("Rectangle")
    m.bg.color = m.humidor.char
    m.bg.width = 1920
    m.bg.height = 1080

    ' Full-screen background image, swapped per screen (Home / VOD / per-series).
    m.bgImage = m.top.CreateChild("Poster")
    m.bgImage.translation = [0, 0]
    m.bgImage.width = 1920
    m.bgImage.height = 1080
    m.bgImage.loadDisplayMode = "scaleToFill"

    BuildChooserScreen()
    BuildVodGridScreen()
    BuildEpisodeGuideScreen()
    BuildPlayerScreen()

    m.epgTask = m.top.CreateChild("ApiTask")

    m.screen = "chooser"
    m.chooserIndex = 0
    m.focusZone = "chooser"
    m.epgNowTitle = ""
    m.epgNowEpisode = ""
    m.epgNextTitle = ""
    m.epgNextEpisode = ""

    m.seriesMap = {}
    LoadCatalog()
    LoadEpg()

    ' Launch straight into the home chooser. The splash overlay sits on top, holds 3s,
    ' then fades. (Registration screen removed for now - to be revisited later.)
    GoToChooser()
    BuildSplashOverlay()

    m.top.SetFocus(true)
end sub

sub BuildSplashOverlay()
    m.splashGroup = m.top.CreateChild("Group")

    ' Opaque backing in the splash's own background color, created BEFORE the poster.
    ' This makes the overlay fully solid from the very first frame, so the home screen
    ' can't peek through during the brief window before the JPEG finishes loading.
    m.splashBack = m.splashGroup.CreateChild("Rectangle")
    m.splashBack.color = "0xEEEEE6FF"
    m.splashBack.translation = [0, 0]
    m.splashBack.width = 1920
    m.splashBack.height = 1080

    m.splashOverlay = m.splashGroup.CreateChild("Poster")
    m.splashOverlay.uri = "pkg:/images/splash_full.jpg"
    m.splashOverlay.translation = [0, 0]
    m.splashOverlay.width = 1920
    m.splashOverlay.height = 1080
    m.splashOverlay.loadDisplayMode = "scaleToFill"
    m.splashOverlay.opacity = 1.0
    m.splashOpacity = 1.0
    m.splashActive = true

    ' Hold timer: fires once after 3s, then the fade timer takes over.
    m.splashHold = m.splashGroup.CreateChild("Timer")
    m.splashHold.duration = 3.0
    m.splashHold.repeat = false
    m.splashHold.ObserveField("fire", "OnSplashFadeStart")

    m.splashFade = m.splashGroup.CreateChild("Timer")
    m.splashFade.duration = 0.04
    m.splashFade.repeat = true
    m.splashFade.ObserveField("fire", "OnSplashFadeTick")

    m.splashHold.control = "start"
end sub

sub OnSplashFadeStart()
    m.splashFade.control = "start"
end sub

sub OnSplashFadeTick()
    m.splashOpacity = m.splashOpacity - 0.05
    if m.splashOpacity <= 0.0
        m.splashOpacity = 0.0
        m.splashFade.control = "stop"
        m.splashGroup.visible = false
        m.splashActive = false
        
        ' FIRE BEACON: The natural fade has finished and the UI is fully visible.
        FireAppLaunchComplete()
    end if
    m.splashGroup.opacity = m.splashOpacity
end sub

' Instant dismiss (any key press). Works because the scene is already interactive.
sub DismissSplash()
    if m.splashHold <> invalid then m.splashHold.control = "stop"
    if m.splashFade <> invalid then m.splashFade.control = "stop"
    if m.splashGroup <> invalid
        m.splashGroup.opacity = 0.0
        m.splashGroup.visible = false
    end if
    m.splashActive = false
    
    ' FIRE BEACON: The user interrupted the splash, so the UI is now fully visible.
    FireAppLaunchComplete()
end sub

' ============================================================
' CHOOSER / HOME SCREEN
' Logo left (slow pulse), two stacked panels right: Live (with
' now/next) on top, Browse Our Shows below.
' ============================================================
' ============================================================
' REGISTRATION / ACTIVATION SCREEN
' Shown on first launch until the device is linked. Code-based on-device activation:
' the viewer enters the shown code at a URL on their phone; the app polls a backend
' until it reports the device linked, then persists that and proceeds to the app.
' Keyboard-free (Roku cert-friendly) and dismissible for a "skip for now" path.
' ============================================================
sub BuildChooserScreen()
    m.chooserGroup = m.top.CreateChild("Group")

    ' Smoke wisps drift up behind the logo. Placed before the logo so they sit behind it.
    BuildSmoke()

    ' Pulsing logo, centered in the left region (between screen edge and panels at x=960)
    m.chooserLogo = m.chooserGroup.CreateChild("Poster")
    m.chooserLogo.uri = "pkg:/images/logo.png"
    m.chooserLogo.translation = [255, 330]
    m.chooserLogo.width = 450
    m.chooserLogo.height = 371
    m.chooserLogo.loadDisplayMode = "scaleToFit"
    SetupLogoPulse()

    m.chooserTagline = m.chooserGroup.CreateChild("Label")
    m.chooserTagline.text = "HEAD TO CIGARTV.COM FOR MORE"
    m.chooserTagline.translation = [255, 1000]
    m.chooserTagline.width = 450
    m.chooserTagline.horizAlign = "center"
    m.chooserTagline.color = m.humidor.ember
    m.chooserTagline.font = PoppinsFont("semibold", 22)

    panelX = 960
    panelW = 760

    ' --- LIVE panel ---
    ' --- LIVE panel ---
    ' Highlight fill: ember at 25% (0x40 alpha), shown only when this panel is focused.
    m.liveHighlight = m.chooserGroup.CreateChild("Rectangle")
    m.liveHighlight.color = "0xF3D38940"
    m.liveHighlight.translation = [panelX, 180]
    m.liveHighlight.width = panelW
    m.liveHighlight.height = 240
    m.liveHighlight.visible = false

    m.livePanelBorder = m.chooserGroup.CreateChild("Rectangle")
    m.livePanelBorder.color = m.humidor.ember
    m.livePanelBorder.translation = [panelX, 180]
    m.livePanelBorder.width = panelW
    m.livePanelBorder.height = 240
    m.liveEdges = MakeOutline(m.livePanelBorder)

    m.liveWatch = m.chooserGroup.CreateChild("Label")
    m.liveWatch.text = "Watch"
    m.liveWatch.translation = [panelX, 230]
    m.liveWatch.width = panelW
    m.liveWatch.horizAlign = "center"
    m.liveWatch.color = m.humidor.paper
    m.liveWatch.font = PoppinsFont("extrabold", 64)

    m.liveTitle = m.chooserGroup.CreateChild("Label")
    m.liveTitle.text = "CigarTV Live"
    m.liveTitle.translation = [panelX, 300]
    m.liveTitle.width = panelW
    m.liveTitle.horizAlign = "center"
    m.liveTitle.color = m.humidor.ember
    m.liveTitle.font = PoppinsFont("semibold", 60)

    m.liveNow = m.chooserGroup.CreateChild("Label")
    m.liveNow.translation = [panelX, 440]
    m.liveNow.width = panelW
    m.liveNow.horizAlign = "center"
    m.liveNow.color = m.humidor.paper
    m.liveNow.font = PoppinsFont("bold", 26)
    m.liveNow.text = "NOW: --"

    m.liveNext = m.chooserGroup.CreateChild("Label")
    m.liveNext.translation = [panelX, 478]
    m.liveNext.width = panelW
    m.liveNext.horizAlign = "center"
    m.liveNext.color = m.humidor.paper
    m.liveNext.font = PoppinsFont("bold", 26)
    m.liveNext.text = "NEXT: --"

    ' --- BROWSE panel ---
    m.vodHighlight = m.chooserGroup.CreateChild("Rectangle")
    m.vodHighlight.color = "0xF3D38940"
    m.vodHighlight.translation = [panelX, 560]
    m.vodHighlight.width = panelW
    m.vodHighlight.height = 240
    m.vodHighlight.visible = false

    m.vodPanelBorder = m.chooserGroup.CreateChild("Rectangle")
    m.vodPanelBorder.color = m.humidor.ember
    m.vodPanelBorder.translation = [panelX, 560]
    m.vodPanelBorder.width = panelW
    m.vodPanelBorder.height = 240
    m.vodEdges = MakeOutline(m.vodPanelBorder)

    m.vodBrowse = m.chooserGroup.CreateChild("Label")
    m.vodBrowse.text = "Browse"
    m.vodBrowse.translation = [panelX, 610]
    m.vodBrowse.width = panelW
    m.vodBrowse.horizAlign = "center"
    m.vodBrowse.color = m.humidor.paper
    m.vodBrowse.font = PoppinsFont("extrabold", 64)

    m.vodSubtitle = m.chooserGroup.CreateChild("Label")
    m.vodSubtitle.text = "Our Shows"
    m.vodSubtitle.translation = [panelX, 680]
    m.vodSubtitle.width = panelW
    m.vodSubtitle.horizAlign = "center"
    m.vodSubtitle.color = m.humidor.ember
    m.vodSubtitle.font = PoppinsFont("semibold", 60)

    m.vodFootnote = m.chooserGroup.CreateChild("Label")
    m.vodFootnote.text = "New Episodes Each Week !"
    m.vodFootnote.translation = [panelX, 820]
    m.vodFootnote.width = panelW
    m.vodFootnote.horizAlign = "center"
    m.vodFootnote.color = m.humidor.paper
    m.vodFootnote.font = PoppinsFont("bold", 24)

    UpdateChooserHighlight()
end sub

' Three smoke wisps rise slowly behind the logo on independent, staggered cycles.
' Each drifts upward and fades out, then resets to the bottom - a continuous plume
' effect driven manually by one timer (Animation-node targeting is unreliable here).
sub BuildSmoke()
    m.smokeWisps = []
    m.smokeClock = 5.0
    baseX = 300
    startY = 620

    for i = 0 to 2
        wisp = m.chooserGroup.CreateChild("Poster")
        wisp.uri = "pkg:/images/smoke/wisp" + i.ToStr() + ".png"
        wisp.width = 360
        wisp.height = 500
        wisp.loadDisplayMode = "scaleToFit"
        wisp.translation = [baseX + (i * 20) - 20, startY]
        wisp.opacity = 0.0
        m.smokeWisps.Push({
            node: wisp
            phase: i * 0.34
            baseX: baseX + (i * 20) - 20
        })
    end for

    m.smokeStartY = startY
    m.smokeRise = 340
    m.smokeTimer = m.chooserGroup.CreateChild("Timer")
    if m.smokeTimer = invalid then return
    m.smokeTimer.duration = 0.06
    m.smokeTimer.repeat = true
    m.smokeTimer.ObserveField("fire", "OnSmokeTick")
    m.smokeTimer.control = "start"
end sub

sub OnSmokeTick()
    if m.smokeWisps = invalid then return
    m.smokeClock = m.smokeClock + 0.006
    if m.smokeClock > 1.0 then m.smokeClock = m.smokeClock - 1.0

    for each w in m.smokeWisps
        p = m.smokeClock + w.phase
        if p > 1.0 then p = p - 1.0

        y = m.smokeStartY - (p * m.smokeRise)
        sway = Sin(p * 6.283) * 18
        w.node.translation = [w.baseX + sway, y]

        op = 0.0
        if p < 0.25
            op = (p / 0.25) * 0.5
        else if p > 0.65
            op = (1.0 - (p - 0.65) / 0.35) * 0.5
        else
            op = 0.5
        end if
        if op < 0 then op = 0
        w.node.opacity = op
    end for
end sub

' Draws a true hollow outline using four thin edge rects, so the background image
' shows through the middle. Hides the source rect's own fill and returns the edge
' rects so the caller can recolor them on focus.
function MakeOutline(borderRect as Object) as Object
    parent = borderRect.GetParent()
    color = borderRect.color
    x = borderRect.translation[0]
    y = borderRect.translation[1]
    w = borderRect.width
    h = borderRect.height
    t = 3

    borderRect.visible = false

    top = parent.CreateChild("Rectangle")
    top.color = color
    top.translation = [x, y]
    top.width = w
    top.height = t

    bottom = parent.CreateChild("Rectangle")
    bottom.color = color
    bottom.translation = [x, y + h - t]
    bottom.width = w
    bottom.height = t

    left = parent.CreateChild("Rectangle")
    left.color = color
    left.translation = [x, y]
    left.width = t
    left.height = h

    right = parent.CreateChild("Rectangle")
    right.color = color
    right.translation = [x + w - t, y]
    right.width = t
    right.height = h

    return [top, bottom, left, right]
end function

sub SetupLogoPulse()
    ' Animating via string-id interpolator targeting silently failed (id lookups are
    ' unreliable in this environment). Drive a smooth fade manually: a fast timer steps
    ' opacity up and down between 0.78 and 1.0, reversing direction at each end.
    m.logoOpacity = 0.78
    m.logoStep = 0.022
    m.chooserLogo.opacity = m.logoOpacity

    m.logoTimer = m.chooserGroup.CreateChild("Timer")
    if m.logoTimer = invalid then return
    m.logoTimer.duration = 0.05
    m.logoTimer.repeat = true
    m.logoTimer.ObserveField("fire", "OnLogoPulseTick")
    m.logoTimer.control = "start"
end sub

sub OnLogoPulseTick()
    m.logoOpacity = m.logoOpacity + m.logoStep
    if m.logoOpacity >= 1.0
        m.logoOpacity = 1.0
        m.logoStep = -m.logoStep
    else if m.logoOpacity <= 0.78
        m.logoOpacity = 0.78
        m.logoStep = -m.logoStep
    end if
    m.chooserLogo.opacity = m.logoOpacity
end sub

sub UpdateChooserHighlight()
    if m.liveHighlight = invalid then return
    m.liveHighlight.visible = (m.chooserIndex = 0)
    m.vodHighlight.visible = (m.chooserIndex = 1)
end sub

sub GoToChooser()
    m.screen = "chooser"
    m.focusZone = "chooser"
    m.bgImage.uri = "pkg:/images/backgrounds/home.jpg"
    m.chooserGroup.visible = true
    m.vodGridGroup.visible = false
    m.guideGroup.visible = false
    m.playerGroup.visible = false
    m.playerVideo.control = "stop"
    m.top.SetFocus(true)
    UpdateChooserHighlight()
    UpdateChooserEpgText()
end sub

' ============================================================
' VOD GRID ("Originals") - 4-column grid, pill header, back btn
' ============================================================
' ============================================================
' VOD BROWSE (Netflix-style): a hero banner reflecting the focused series, over a
' horizontal scrolling row of series cards. Starts at series level.
' ============================================================
sub BuildVodGridScreen()
    m.vodGridGroup = m.top.CreateChild("Group")

    ' --- Hero banner: full-frame art so scaleToFill crops to a natural 16:9 rather
    ' than squishing into a short band. Gradients keep the lower/left legible. ---
    m.heroArt = m.vodGridGroup.CreateChild("Poster")
    m.heroArt.translation = [0, 0]
    m.heroArt.width = 1920
    m.heroArt.height = 1080
    m.heroArt.loadDisplayMode = "scaleToFill"

    ' Left-to-right dark gradient scrim so title/description are legible over art.
    m.heroScrimL = m.vodGridGroup.CreateChild("Poster")
    m.heroScrimL.uri = "pkg:/images/hero_scrim_left.png"
    m.heroScrimL.translation = [0, 0]
    m.heroScrimL.width = 1400
    m.heroScrimL.height = 760
    ' Bottom fade so the hero blends into the row area below.
    m.heroScrimB = m.vodGridGroup.CreateChild("Poster")
    m.heroScrimB.uri = "pkg:/images/hero_scrim_bottom.png"
    m.heroScrimB.translation = [0, 560]
    m.heroScrimB.width = 1920
    m.heroScrimB.height = 400

    ' Back button (top-left, over hero)
    m.vodBackGlow = m.vodGridGroup.CreateChild("Poster")
    m.vodBackGlow.uri = "pkg:/images/focusframe.png"
    m.vodBackGlow.translation = [48, 44]
    m.vodBackGlow.width = 76
    m.vodBackGlow.height = 76
    m.vodBackGlow.visible = false
    m.vodBackBtn = m.vodGridGroup.CreateChild("Poster")
    m.vodBackBtn.uri = "pkg:/images/back.png"
    m.vodBackBtn.translation = [54, 50]
    m.vodBackBtn.width = 64
    m.vodBackBtn.height = 64

    ' Hero text block
    m.heroTitle = m.vodGridGroup.CreateChild("Label")
    m.heroTitle.translation = [90, 300]
    m.heroTitle.width = 1050
    m.heroTitle.height = 180
    m.heroTitle.color = m.humidor.paper
    m.heroTitle.font = ModestoFont(96)
    m.heroTitle.maxLines = 2
    m.heroTitle.wrap = true
    m.heroTitle.vertAlign = "bottom"

    m.heroMeta = m.vodGridGroup.CreateChild("Label")
    m.heroMeta.translation = [92, 494]
    m.heroMeta.width = 900
    m.heroMeta.color = m.humidor.ember
    m.heroMeta.font = PoppinsFont("semibold", 20)

    m.heroDesc = m.vodGridGroup.CreateChild("Label")
    m.heroDesc.translation = [92, 536]
    m.heroDesc.width = 820
    m.heroDesc.color = m.humidor.smoke100
    m.heroDesc.font = PoppinsFont("regular", 22)
    m.heroDesc.maxLines = 2
    m.heroDesc.wrap = true
    m.heroDesc.lineSpacing = 6

    ' --- Horizontal card strip (no row label) ---
    ' Clipping group for the horizontal strip; inner group slides left/right.
    m.stripClip = m.vodGridGroup.CreateChild("Group")
    m.stripClip.translation = [90, 772]
    m.showRows = m.stripClip.CreateChild("Group")
    m.showRows.translation = [0, 0]

    m.vodGridGroup.visible = false
end sub

sub GoToVodGrid()
    m.screen = "vodGrid"
    m.focusZone = "vodGrid"
    ' Netflix-style browse paints its own hero art, so no tiled background needed.
    m.bgImage.uri = "pkg:/images/backgrounds/vod.jpg"

    m.chooserGroup.visible = false
    m.guideGroup.visible = false
    m.playerGroup.visible = false
    m.vodGridGroup.visible = true
    m.playerVideo.control = "stop"
    m.vodBackFocused = false
    if m.vodBackGlow <> invalid then m.vodBackGlow.visible = false

    if m.cards <> invalid and m.cards.Count() > 0
        m.focusIndex = 0
        for each c in m.cards
            c.isFocused = false
        end for
        m.cards[0].isFocused = true
        m.showRows.translation = [0, 0]
        UpdateHero()
    end if
end sub

' Updates the hero banner to reflect the currently focused series.
sub UpdateHero()
    if m.cards = invalid or m.cards.Count() = 0 then return
    key = m.cardSeriesKeys[m.focusIndex]
    series = m.seriesMap[key]
    if series = invalid then return

    ' Hero background = a random EPISODE thumbnail (clean footage, no baked-in title
    ' text), not the branded series art. Chosen once per series and cached so it
    ' doesn't reshuffle every time focus returns.
    art = ""
    if series.heroArt <> invalid and series.heroArt <> ""
        art = series.heroArt
    else if series.episodes.Count() > 0
        idx = Int(Rnd(0) * series.episodes.Count())
        if idx < 0 then idx = 0
        if idx >= series.episodes.Count() then idx = series.episodes.Count() - 1
        art = series.episodes[idx].thumbUrl
        series.heroArt = art
    end if
    m.heroArt.uri = art

    m.heroTitle.text = series.displayName
    m.heroDesc.text = series.description

    epCount = series.episodes.Count()
    seasonCount = series.seasons.Count()
    if seasonCount > 1
        m.heroMeta.text = seasonCount.ToStr() + " Seasons   /   " + epCount.ToStr() + " Episodes"
    else
        m.heroMeta.text = epCount.ToStr() + " Episodes"
    end if
end sub

' ============================================================
' EPISODE GUIDE - compact header (logo + description), a season
' dropdown, and a lean vertical episode list.
' ============================================================
sub BuildEpisodeGuideScreen()
    m.guideGroup = m.top.CreateChild("Group")

    ' --- Episode list FIRST so everything else draws above it. The list scrolls;
    ' rows that move up slide underneath the opaque header band below. ---
    m.guideListClip = m.guideGroup.CreateChild("Group")
    m.guideListClip.translation = [150, 330]

    m.guideList = m.guideListClip.CreateChild("Group")
    m.guideList.translation = [0, 0]

    ' --- Pinned header band (opaque) - logo, description, hairline accent ---
    m.guideHeaderBand = m.guideGroup.CreateChild("Rectangle")
    m.guideHeaderBand.color = "0x12100EF8"
    m.guideHeaderBand.translation = [0, 0]
    m.guideHeaderBand.width = 1920
    m.guideHeaderBand.height = 322

    m.guideHairline = m.guideGroup.CreateChild("Rectangle")
    m.guideHairline.color = "0xF3D38966"
    m.guideHairline.translation = [0, 219]
    m.guideHairline.width = 1920
    m.guideHairline.height = 2

    m.guideBackGlow = m.guideGroup.CreateChild("Poster")
    m.guideBackGlow.uri = "pkg:/images/focusframe.png"
    m.guideBackGlow.translation = [40, 66]
    m.guideBackGlow.width = 88
    m.guideBackGlow.height = 88
    m.guideBackGlow.visible = false

    m.guideBackBtn = m.guideGroup.CreateChild("Poster")
    m.guideBackBtn.uri = "pkg:/images/back.png"
    m.guideBackBtn.translation = [48, 74]
    m.guideBackBtn.width = 72
    m.guideBackBtn.height = 72

    m.guideLogo = m.guideGroup.CreateChild("Poster")
    m.guideLogo.translation = [160, 20]
    m.guideLogo.width = 380
    m.guideLogo.height = 180
    m.guideLogo.loadDisplayMode = "scaleToFit"

    m.guideDescription = m.guideGroup.CreateChild("Label")
    m.guideDescription.translation = [600, 60]
    m.guideDescription.width = 1240
    m.guideDescription.color = m.humidor.smoke100
    m.guideDescription.font = PoppinsFont("regular", 20)
    m.guideDescription.wrap = true
    m.guideDescription.maxLines = 3
    m.guideDescription.lineSpacing = 6

    ' --- Season dropdown pill (below the header band) ---
    m.seasonDropX = 150
    m.seasonDropY = 246
    m.seasonDropW = 280
    m.seasonDropH = 56

    m.seasonPill = m.guideGroup.CreateChild("Rectangle")
    m.seasonPill.color = "0x1A1712E6"
    m.seasonPill.translation = [m.seasonDropX, m.seasonDropY]
    m.seasonPill.width = m.seasonDropW
    m.seasonPill.height = m.seasonDropH
    m.seasonPillEdges = MakeOutline(m.seasonPill)
    m.seasonPill.visible = true ' MakeOutline hides the fill; we want the dark fill + outline
    m.seasonPill.color = "0x1A1712E6"

    m.seasonLabel = m.guideGroup.CreateChild("Label")
    m.seasonLabel.translation = [m.seasonDropX + 26, m.seasonDropY + 12]
    m.seasonLabel.color = m.humidor.ember
    m.seasonLabel.font = PoppinsFont("semibold", 25)
    m.seasonLabel.text = "Season 1"

    m.seasonChevron = m.guideGroup.CreateChild("Label")
    m.seasonChevron.translation = [m.seasonDropX + m.seasonDropW - 46, m.seasonDropY + 10]
    m.seasonChevron.color = m.humidor.ember
    m.seasonChevron.font = PoppinsFont("bold", 26)
    m.seasonChevron.text = "v"

    ' --- Expanded dropdown menu LAST so it z-orders above the episode list ---
    m.seasonMenu = m.guideGroup.CreateChild("Group")
    m.seasonMenu.translation = [m.seasonDropX, m.seasonDropY + m.seasonDropH + 4]
    m.seasonMenu.visible = false
    m.seasonMenuOpen = false

    m.guideGroup.visible = false
end sub

' Rebuilds the expanded dropdown menu items for the current series' seasons.
sub BuildSeasonMenu()
    m.seasonMenu.RemoveChildrenIndex(m.seasonMenu.GetChildCount(), 0)
    m.seasonMenuRows = []

    itemH = 54
    menuBg = m.seasonMenu.CreateChild("Rectangle")
    menuBg.color = "0x14110EFA"
    menuBg.width = m.seasonDropW
    menuBg.height = itemH * m.currentSeasons.Count()

    ' thin gold edge down the left for a modern accent
    edge = m.seasonMenu.CreateChild("Rectangle")
    edge.color = m.humidor.ember
    edge.width = 3
    edge.height = itemH * m.currentSeasons.Count()

    for i = 0 to m.currentSeasons.Count() - 1
        y = i * itemH

        hl = m.seasonMenu.CreateChild("Rectangle")
        hl.color = "0xF3D38933"
        hl.translation = [0, y]
        hl.width = m.seasonDropW
        hl.height = itemH
        hl.visible = (i = m.currentSeasonIndex)

        lbl = m.seasonMenu.CreateChild("Label")
        lbl.translation = [26, y + 12]
        lbl.color = m.humidor.paper
        lbl.font = PoppinsFont("medium", 23)
        lbl.text = "Season " + m.currentSeasons[i]

        m.seasonMenuRows.Push(hl)
    end for
end sub

sub OpenSeasonMenu()
    m.seasonMenuOpen = true
    m.seasonMenuIndex = m.currentSeasonIndex
    BuildSeasonMenu()
    m.seasonMenu.visible = true
    m.seasonChevron.text = "^"
    m.focusZone = "seasonMenu"
end sub

sub CloseSeasonMenu()
    m.seasonMenuOpen = false
    m.seasonMenu.visible = false
    m.seasonChevron.text = "v"
    m.focusZone = "guide"
end sub

sub GoToEpisodeGuide(seriesKey as String)
    m.screen = "guide"
    m.currentSeriesKey = seriesKey
    series = m.seriesMap[seriesKey]
    if series = invalid then return

    assets = SeriesAssets(seriesKey)
    m.bgImage.uri = assets.background
    if assets.logo <> ""
        m.guideLogo.uri = assets.logo
        m.guideLogo.visible = true
    else
        m.guideLogo.visible = false
    end if

    m.chooserGroup.visible = false
    m.vodGridGroup.visible = false
    m.playerGroup.visible = false
    m.guideGroup.visible = true
    m.playerVideo.control = "stop"

    sortedSeasons = SortSeasonStrings(series.seasons)
    m.currentSeasons = sortedSeasons
    m.currentSeasonIndex = 0

    ' description: use first episode's description as the show-level blurb
    ' Series-level description from the catalog (natural case reads cleaner than caps)
    desc = ""
    if series.description <> invalid then desc = series.description
    if desc = "" and series.episodes.Count() > 0 then desc = series.episodes[0].description
    m.guideDescription.text = desc

    LoadSeasonIntoGuide()
    m.focusZone = "guide"
    m.guideFocusIndex = 0
    m.guideBackFocused = false
    if m.guideBackGlow <> invalid then m.guideBackGlow.visible = false
end sub

sub LoadSeasonIntoGuide()
    series = m.seriesMap[m.currentSeriesKey]
    seasonNum = m.currentSeasons[m.currentSeasonIndex]
    episodes = EpisodesForSeason(series, seasonNum)
    m.currentEpisodes = episodes
    m.seasonLabel.text = "Season " + seasonNum

    ' clear existing rows
    m.guideList.RemoveChildrenIndex(m.guideList.GetChildCount(), 0)
    m.guideRows = []

    rowH = 172
    thumbW = 256
    thumbH = 144

    for i = 0 to episodes.Count() - 1
        ep = episodes[i]
        y = i * rowH

        rowGroup = m.guideList.CreateChild("Group")
        rowGroup.translation = [0, y]

        ' Subtle highlight panel behind the focused row (Netflix-style). Sits behind the
        ' thumbnail + text; only the focused row shows it.
        rowHi = rowGroup.CreateChild("Rectangle")
        rowHi.color = "0xFFFFFF14"
        rowHi.width = 1180
        rowHi.height = thumbH + 24
        rowHi.translation = [-20, -12]
        rowHi.visible = (i = 0)

        focusBar = rowGroup.CreateChild("Rectangle")
        focusBar.color = m.humidor.ember
        focusBar.width = 5
        focusBar.height = thumbH
        focusBar.translation = [-20, 0]
        focusBar.visible = (i = 0)

        thumb = rowGroup.CreateChild("Poster")
        thumb.uri = ep.thumbUrl
        thumb.width = thumbW
        thumb.height = thumbH
        thumb.translation = [0, 0]
        thumb.loadDisplayMode = "scaleToFill"

        ' Locked (not-yet-released) episodes: dim the thumbnail + show a lock badge.
        isLocked = (ep.locked = true)
        if isLocked
            thumb.opacity = 0.4
            lockBadge = rowGroup.CreateChild("Poster")
            lockBadge.uri = "pkg:/images/lock.png"
            lockBadge.width = 48
            lockBadge.height = 48
            lockBadge.translation = [(thumbW / 2) - 24, (thumbH / 2) - 24]
        end if

        textX = thumbW + 34

        epNum = rowGroup.CreateChild("Label")
        meta = "E" + ep.episode
        if ep.durationMinutes <> invalid and ep.durationMinutes > 0
            meta = meta + "   " + Str(ep.durationMinutes).Trim() + " min"
        end if
        if ep.rating <> invalid and ep.rating <> ""
            meta = meta + "   " + ep.rating
        end if
        if isLocked then meta = meta + "   COMING SOON"
        epNum.text = UCase(meta)
        epNum.translation = [textX, 10]
        epNum.color = m.humidor.smoke300
        epNum.font = PoppinsFont("semibold", 15)

        epTitle = rowGroup.CreateChild("Label")
        epTitle.text = ep.title
        epTitle.translation = [textX, 34]
        epTitle.width = 760
        epTitle.color = m.humidor.paper
        epTitle.font = PoppinsFont("bold", 26)
        epTitle.wrap = false
        epTitle.maxLines = 1
        epTitle.ellipsisText = "..."

        epDesc = rowGroup.CreateChild("Label")
        epDesc.text = ep.description
        epDesc.translation = [textX, 74]
        epDesc.width = 760
        epDesc.color = m.humidor.smoke100
        epDesc.font = PoppinsFont("regular", 16)
        epDesc.wrap = true
        epDesc.maxLines = 2
        epDesc.lineSpacing = 4

        m.guideRows.Push({ hi: rowHi, bar: focusBar })
    end for

    m.guideFocusIndex = 0
    m.guideList.translation = [0, 0]
end sub

' Shows/hides the highlight panel + focus bar for a guide row by index.
sub SetGuideRowFocus(index as Integer, focused as Boolean)
    if m.guideRows = invalid or index < 0 or index >= m.guideRows.Count() then return
    row = m.guideRows[index]
    row.hi.visible = focused
    row.bar.visible = focused
end sub

' ============================================================
' PLAYER SCREEN - fullscreen video + optional bottom EPG overlay
' ============================================================
sub BuildPlayerScreen()
    m.playerGroup = m.top.CreateChild("Group")
    m.playerVideo = m.playerGroup.CreateChild("Video")
    m.playerVideo.translation = [0, 0]
    m.playerVideo.width = 1920
    m.playerVideo.height = 1080

    ' --- EPG overlay (live only): compact bottom strip, auto-hides after 5s ---
    ' Uses a gradient (not a solid blanket) and sits low so it never fully covers a
    ' broadcast ticker at the bottom of the live feed.
    m.epgOverlay = m.playerGroup.CreateChild("Group")
    m.epgOverlay.translation = [0, 916]

    m.epgOverlayBg = m.epgOverlay.CreateChild("Poster")
    m.epgOverlayBg.uri = "pkg:/images/hero_scrim_bottom.png"
    m.epgOverlayBg.translation = [0, -36]
    m.epgOverlayBg.width = 1920
    m.epgOverlayBg.height = 200

    m.epgOverlayAccent = m.epgOverlay.CreateChild("Rectangle")
    m.epgOverlayAccent.color = m.humidor.ember
    m.epgOverlayAccent.width = 1920
    m.epgOverlayAccent.height = 3

    m.epgOverlayHeader = m.epgOverlay.CreateChild("Label")
    m.epgOverlayHeader.text = "UP NEXT ON CIGARTV LIVE"
    m.epgOverlayHeader.translation = [60, 14]
    m.epgOverlayHeader.color = m.humidor.ember
    m.epgOverlayHeader.font = PoppinsFont("bold", 22)

    m.epgOverlayRow = m.epgOverlay.CreateChild("Group")
    m.epgOverlayRow.translation = [60, 46]

    m.epgOverlay.visible = false

    m.epgHideTimer = m.playerGroup.CreateChild("Timer")
    m.epgHideTimer.duration = 5.0
    m.epgHideTimer.repeat = false
    m.epgHideTimer.ObserveField("fire", "OnEpgOverlayHide")

    m.playerGroup.visible = false
end sub

' Populates and shows the EPG overlay with programmes airing in the next hour, then
' arms the 5-second auto-hide timer. Live playback only.
sub ShowEpgOverlay()
    if m.epgProgrammes = invalid then return

    m.epgOverlayRow.RemoveChildrenIndex(m.epgOverlayRow.GetChildCount(), 0)

    nowSeconds = CreateObject("roDateTime").AsSeconds()
    windowEnd = nowSeconds + 3600 ' next 1 hour

    colX = 0
    colW = 560
    shown = 0

    for each p in m.epgProgrammes
        ' include anything currently airing or starting within the next hour
        airingNow = (nowSeconds >= p.start and nowSeconds < p.stop)
        startsSoon = (p.start >= nowSeconds and p.start < windowEnd)
        if (airingNow or startsSoon) and shown < 3
            cell = m.epgOverlayRow.CreateChild("Group")
            cell.translation = [colX, 0]

            timeLabel = cell.CreateChild("Label")
            timeLabel.text = FormatClock(p.start) + IIfNow(airingNow)
            timeLabel.color = m.humidor.ember
            timeLabel.font = PoppinsFont("semibold", 24)
            timeLabel.translation = [0, 0]

            titleLabel = cell.CreateChild("Label")
            titleLabel.text = UCase(p.title)
            titleLabel.color = m.humidor.paper
            titleLabel.font = PoppinsFont("bold", 28)
            titleLabel.translation = [0, 34]
            titleLabel.width = colW - 30
            titleLabel.maxLines = 1
            titleLabel.ellipsisText = "..."

            if p.episode <> ""
                epLabel = cell.CreateChild("Label")
                epLabel.text = p.episode
                epLabel.color = m.humidor.smoke300
                epLabel.font = PoppinsFont("medium", 22)
                epLabel.translation = [0, 74]
                epLabel.width = colW - 30
                epLabel.maxLines = 1
                epLabel.ellipsisText = "..."
            end if

            colX = colX + colW
            shown = shown + 1
        end if
    end for

    m.epgOverlay.visible = true
    m.epgHideTimer.control = "stop"
    m.epgHideTimer.control = "start"
end sub

sub OnEpgOverlayHide()
    m.epgOverlay.visible = false
end sub

function FormatClock(epochSec as Integer) as String
    dt = CreateObject("roDateTime")
    dt.FromSeconds(epochSec)
    dt.ToLocalTime()
    hr = dt.GetHours()
    mn = dt.GetMinutes()
    ampm = "AM"
    if hr >= 12 then ampm = "PM"
    h12 = hr mod 12
    if h12 = 0 then h12 = 12
    return h12.ToStr() + ":" + Right("0" + mn.ToStr(), 2) + " " + ampm
end function

function IIfNow(isNow as Boolean) as String
    if isNow then return "  (NOW)"
    return ""
end function

' Brief centered notice when a locked episode is selected; auto-hides.
sub ShowLockNotice()
    if m.lockNotice = invalid
        m.lockNotice = m.guideGroup.CreateChild("Label")
        m.lockNotice.translation = [560, 620]
        m.lockNotice.width = 800
        m.lockNotice.horizAlign = "center"
        m.lockNotice.color = m.humidor.ember
        m.lockNotice.font = PoppinsFont("bold", 30)
        m.lockNotice.text = "COMING SOON - not yet released"
        m.lockNoticeTimer = m.guideGroup.CreateChild("Timer")
        m.lockNoticeTimer.duration = 2.2
        m.lockNoticeTimer.repeat = false
        m.lockNoticeTimer.ObserveField("fire", "OnLockNoticeHide")
    end if
    m.lockNotice.visible = true
    m.lockNoticeTimer.control = "stop"
    m.lockNoticeTimer.control = "start"
end sub

sub OnLockNoticeHide()
    if m.lockNotice <> invalid then m.lockNotice.visible = false
end sub

sub PlayEpisodeAtIndex(index as Integer)
    if m.currentEpisodes = invalid or index < 0 or index >= m.currentEpisodes.Count() then return
    ep = m.currentEpisodes[index]

    ' Locked (not-yet-released) episodes can't be played - flash a brief notice and
    ' stay on the guide.
    if ep.locked = true
        ShowLockNotice()
        return
    end if

    m.screen = "player"
    m.playerMode = "vod"
    m.playerEpisodeIndex = index

    m.chooserGroup.visible = false
    m.vodGridGroup.visible = false
    m.guideGroup.visible = false
    m.playerGroup.visible = true
    m.epgOverlay.visible = false

    ' Bundled-catalog episodes carry a direct MP4 url; API episodes carry a stream
    ' slug resolved via the freecast /streams endpoint.
    if ep.videoUrl <> invalid and ep.videoUrl <> ""
        videoContent = CreateObject("roSGNode", "ContentNode")
        videoContent.url = ep.videoUrl
        videoContent.streamFormat = "mp4"
        videoContent.live = false
        videoContent.title = ep.title
        m.playerVideo.content = videoContent
        m.playerVideo.control = "play"
        m.playerVideo.SetFocus(true)
        m.focusZone = "player"
        return
    end if

    ' Resolve the stream from the freecast streams endpoint using the episode's
    ' real stream slug (from the catalog), then play in OnFreecastStreamsLoaded.
    m.pendingPlayTitle = ep.title
    m.streamTask = m.top.CreateChild("ApiTask")
    m.streamTask.responseType = "json"
    m.streamTask.authToken = FreecastConfig().apiKey
    m.streamTask.requestUrl = BuildStreamsUrl(ep.streamSlug)
    m.streamTask.ObserveField("responseData", "OnFreecastStreamsLoaded")
    m.streamTask.ObserveField("failed", "OnFreecastStreamsFailed")
    m.streamTask.control = "RUN"
end sub

sub OnFreecastStreamsLoaded()
    streams = m.streamTask.responseData
    best = PickBestStream(streams)
    if best = invalid
        OnFreecastStreamsFailed()
        return
    end if
    content = BuildContentFromStream(best, m.pendingPlayTitle)
    m.playerVideo.content = content
    m.playerVideo.control = "play"
    m.playerVideo.SetFocus(true)
    m.focusZone = "player"
end sub

sub OnFreecastStreamsFailed()
    ' No playable stream resolved. Return to the guide rather than sit on a black
    ' screen; a real failure here means the streams endpoint/slug/token needs a look.
    GoToEpisodeGuide(m.currentSeriesKey)
end sub

sub PlayLiveStream()
    m.screen = "player"
    m.playerMode = "live"

    m.chooserGroup.visible = false
    m.vodGridGroup.visible = false
    m.guideGroup.visible = false
    m.playerGroup.visible = true

    url = BuildLiveStreamUrl()
    videoContent = CreateObject("roSGNode", "ContentNode")
    videoContent.url = url
    videoContent.streamFormat = "hls"
    videoContent.live = true
    m.playerVideo.content = videoContent
    m.playerVideo.control = "play"
    ' Keep focus at the scene (not the Video node) during live so OK reaches our
    ' handler to re-show the EPG overlay. Live has no transport bar to interact with.
    m.top.SetFocus(true)
    m.focusZone = "player"

    ' Show the 1hr EPG for 5 seconds on entry, then auto-hide.
    ShowEpgOverlay()
end sub

' ============================================================
' VOD GRID BUILDER - 4-column "Originals" grid
' ============================================================
sub BuildRowFromSeries(seriesMap as Object)
    ' clear any previous cards (catalog can reload)
    m.showRows.RemoveChildrenIndex(m.showRows.GetChildCount(), 0)
    m.cards = []
    m.cardSeriesKeys = []
    m.cardW = 384
    m.cardH = 216
    m.cardGap = 26
    i = 0

    ' iterate in configured catalog order when available (assoc arrays don't
    ' preserve insertion order)
    keys = m.catalogOrder
    if keys = invalid or keys.Count() = 0
        keys = []
        for each k in seriesMap
            keys.Push(k)
        end for
    end if

    for each seriesKey in keys
        series = seriesMap[seriesKey]
        if series <> invalid and series.episodes.Count() > 0
            ' Prefer the branded series key art; fall back to first episode thumb.
            art = ""
            if series.thumbnailUrl <> invalid then art = series.thumbnailUrl
            if art = "" then art = series.episodes[0].thumbUrl

            card = m.showRows.CreateChild("ShowCard")
            card.cardWidth = m.cardW
            card.cardHeight = m.cardH
            card.cardTitle = series.displayName
            card.cardSubtitle = ""
            card.cardCategory = series.category
            card.cardTime = ""
            card.cardThumbUrl = art
            ' Strip cards are always art-only: the branded key art already carries the
            ' show name, so no text/category overlay (removes the stray "EPISODE" label).
            card.artOnly = true
            card.cardProgress = 0.0
            card.translation = [i * (m.cardW + m.cardGap), 0]
            m.cards.Push(card)
            m.cardSeriesKeys.Push(seriesKey)
            i = i + 1
        end if
    end for

    m.focusIndex = 0
    if m.cards.Count() > 0
        m.cards[0].isFocused = true
        m.showRows.translation = [0, 0]
        UpdateHero()
    end if
end sub

' ============================================================
' INPUT
' ============================================================
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    ' Any key dismisses the splash immediately - guaranteed escape hatch.
    if m.splashActive = true
        DismissSplash()
        return true
    end if

    if key = "back" then return HandleBack()

    if m.focusZone = "chooser" then return HandleChooserKey(key)
    if m.focusZone = "vodGrid" then return HandleVodGridKey(key)
    if m.focusZone = "guide" then return HandleGuideKey(key)
    if m.focusZone = "seasonMenu" then return HandleSeasonMenuKey(key)
    if m.focusZone = "player" then return HandlePlayerKey(key)

    return false
end function

function HandleBack() as Boolean
    if m.focusZone = "seasonMenu"
        CloseSeasonMenu()
        return true
    end if
    if m.screen = "vodGrid"
        GoToChooser()
        return true
    else if m.screen = "guide"
        GoToVodGrid()
        return true
    else if m.screen = "player"
        if m.playerMode = "live"
            m.playerMode = ""
            GoToChooser()
        else
            GoToEpisodeGuide(m.currentSeriesKey)
        end if
        return true
    end if
    return false
end function

function HandleChooserKey(key as String) as Boolean
    if key = "down" and m.chooserIndex = 0
        m.chooserIndex = 1
        UpdateChooserHighlight()
        return true
    else if key = "up" and m.chooserIndex = 1
        m.chooserIndex = 0
        UpdateChooserHighlight()
        return true
    else if key = "OK"
        if m.chooserIndex = 0
            PlayLiveStream()
        else
            GoToVodGrid()
        end if
        return true
    end if
    return false
end function

function HandleVodGridKey(key as String) as Boolean
    if m.cards = invalid or m.cards.Count() = 0 then return false

    ' Back-button focus mode: reached by pressing Up from the row.
    if m.vodBackFocused
        if key = "OK"
            m.vodBackFocused = false
            m.vodBackGlow.visible = false
            GoToChooser()
            return true
        else if key = "down"
            m.vodBackFocused = false
            m.vodBackGlow.visible = false
            m.cards[m.focusIndex].isFocused = true
            return true
        end if
        return true ' swallow left/right while on the back button
    end if

    count = m.cards.Count()
    newIndex = m.focusIndex

    if key = "right" and m.focusIndex + 1 < count
        newIndex = m.focusIndex + 1
    else if key = "left" and m.focusIndex > 0
        newIndex = m.focusIndex - 1
    else if key = "up"
        ' Up from the row -> focus the on-screen back button.
        m.cards[m.focusIndex].isFocused = false
        m.vodBackFocused = true
        m.vodBackGlow.visible = true
        return true
    else if key = "OK"
        GoToEpisodeGuide(m.cardSeriesKeys[m.focusIndex])
        return true
    else
        return false
    end if

    if newIndex <> m.focusIndex
        m.cards[m.focusIndex].isFocused = false
        m.focusIndex = newIndex
        m.cards[m.focusIndex].isFocused = true
        ScrollStrip()
        UpdateHero()
    end if
    return true
end function

' Slides the horizontal strip so the focused card stays comfortably in view. Keeps
' a couple of cards of lead-in on the left once you scroll past the start.
sub ScrollStrip()
    lead = 1
    idx = m.focusIndex - lead
    if idx < 0 then idx = 0
    offset = -(idx * (m.cardW + m.cardGap))
    m.showRows.translation = [offset, 0]
end sub

function HandleGuideKey(key as String) as Boolean
    if m.guideRows = invalid or m.guideRows.Count() = 0 then return false

    ' Back-button focus mode: reached via Left from the list.
    if m.guideBackFocused
        if key = "OK"
            m.guideBackFocused = false
            m.guideBackGlow.visible = false
            GoToVodGrid()
            return true
        else if key = "right" or key = "down"
            m.guideBackFocused = false
            m.guideBackGlow.visible = false
            return true
        end if
        return true
    end if

    if key = "left"
        m.guideBackFocused = true
        m.guideBackGlow.visible = true
        return true
    else if key = "down" and m.guideFocusIndex < m.guideRows.Count() - 1
        SetGuideRowFocus(m.guideFocusIndex, false)
        m.guideFocusIndex = m.guideFocusIndex + 1
        SetGuideRowFocus(m.guideFocusIndex, true)
        ScrollGuideList()
        return true
    else if key = "up"
        if m.guideFocusIndex > 0
            SetGuideRowFocus(m.guideFocusIndex, false)
            m.guideFocusIndex = m.guideFocusIndex - 1
            SetGuideRowFocus(m.guideFocusIndex, true)
            ScrollGuideList()
        else
            ' at the top of the list; Up opens the season dropdown
            OpenSeasonMenu()
        end if
        return true
    else if key = "OK"
        PlayEpisodeAtIndex(m.guideFocusIndex)
        return true
    end if
    return false
end function

' Season dropdown navigation: Up/Down move the highlight, OK selects and loads that
' season, Back/Up-past-top closes without changing.
function HandleSeasonMenuKey(key as String) as Boolean
    if m.seasonMenuRows = invalid then return false
    count = m.currentSeasons.Count()

    if key = "down" and m.seasonMenuIndex < count - 1
        m.seasonMenuRows[m.seasonMenuIndex].visible = false
        m.seasonMenuIndex = m.seasonMenuIndex + 1
        m.seasonMenuRows[m.seasonMenuIndex].visible = true
        return true
    else if key = "up" and m.seasonMenuIndex > 0
        m.seasonMenuRows[m.seasonMenuIndex].visible = false
        m.seasonMenuIndex = m.seasonMenuIndex - 1
        m.seasonMenuRows[m.seasonMenuIndex].visible = true
        return true
    else if key = "OK"
        m.currentSeasonIndex = m.seasonMenuIndex
        CloseSeasonMenu()
        LoadSeasonIntoGuide()
        if m.guideRows.Count() > 0 then SetGuideRowFocus(0, true)
        return true
    end if
    return false
end function

' Keeps the focused episode row visible by scrolling the list group up as the
' selection moves past the visible area (clip starts at y=270, rows are 168px).
sub ScrollGuideList()
    rowH = 168
    visibleRows = 3
    if m.guideFocusIndex > visibleRows
        offset = -(m.guideFocusIndex - visibleRows) * rowH
        m.guideList.translation = [0, offset]
    else
        m.guideList.translation = [0, 0]
    end if
end sub

function HandlePlayerKey(key as String) as Boolean
    ' Live: OK re-shows the 1hr EPG overlay (which re-arms its 5s auto-hide).
    ' VOD: fullscreen playback with no overlay; let transport controls pass through.
    if m.playerMode = "live" and key = "OK"
        ShowEpgOverlay()
        return true
    end if
    return false
end function
function SortSeasonStrings(seasons as Object) as Object
    arr = seasons
    for i = 1 to arr.Count() - 1
        key = arr[i]
        j = i - 1
        while j >= 0 and Val(arr[j]) > Val(key)
            arr[j + 1] = arr[j]
            j = j - 1
        end while
        arr[j + 1] = key
    end for
    return arr
end function

' ============================================================
' CATALOG LOADING (freecast API: shows -> seasons -> episodes)
' ============================================================
' Iterates the configured show slugs, fetching each show then its episodes per
' season, assembling the same m.seriesMap the UI already consumes. Requires
' FreecastConfig().enabled + apiKey; otherwise renders an empty catalog with a
' visible notice (nothing to test against until the key/shapes are in).
sub LoadCatalog()
    fc = FreecastConfig()
    m.seriesMap = {}
    m.catalogOrder = []      ' preserves configured show order for the grid
    m.showQueue = []         ' shows still to fetch
    m.seasonQueue = []       ' pending {slug, seriesKey, seasonId, seasonNumber} fetches

    cfg = ApiConfig()

    ' Preferred source: a hosted JSON catalog (see ApiConfig().catalogJsonUrl). Same
    ' schema as data/catalog.json. Fetched async; parsed into m.seriesMap; any failure
    ' falls through to the MRSS feed, then the bundled catalog.
    if cfg.catalogJsonUrl <> invalid and cfg.catalogJsonUrl <> ""
        m.jsonTask = m.top.CreateChild("ApiTask")
        m.jsonTask.responseType = "json"
        m.jsonTask.requestUrl = cfg.catalogJsonUrl
        m.jsonTask.ObserveField("responseData", "OnJsonCatalogLoaded")
        m.jsonTask.ObserveField("failed", "OnJsonCatalogFailed")
        m.jsonTask.control = "RUN"
        return
    end if

    ' Next source: a hosted MRSS feed (see ApiConfig().feedUrl). Fetched async;
    ' on success it's parsed into m.seriesMap, on any failure we fall back to bundled.
    if cfg.feedUrl <> invalid and cfg.feedUrl <> ""
        m.feedTask = m.top.CreateChild("ApiTask")
        m.feedTask.responseType = "xml"
        m.feedTask.requestUrl = cfg.feedUrl
        m.feedTask.ObserveField("responseRaw", "OnFeedLoaded")
        m.feedTask.ObserveField("failed", "OnFeedFailed")
        m.feedTask.control = "RUN"
        return
    end if

    if not fc.enabled or fc.apiKey = ""
        ' Test mode: load the bundled catalog (data/catalog.json, generated from the
        ' production episode CSV). Full VOD is testable offline; the freecast path
        ' takes over automatically once enabled + keyed.
        LoadBundledCatalog()
        return
    end if

    ' seed the show queue
    for each sh in fc.shows
        m.showQueue.Push(sh)
    end for

    m.catalogTask = m.top.CreateChild("ApiTask")
    m.catalogTask.responseType = "json"
    m.catalogTask.authToken = fc.apiKey
    m.catalogTask.ObserveField("responseData", "OnShowLoaded")
    m.catalogTask.ObserveField("failed", "OnShowFailed")

    FetchNextShow()
end sub

' ============================================================
' MRSS FEED CATALOG (hosted feed.xml)
' ============================================================
' Parses the CigarTV MRSS schema into the same m.seriesMap the UI consumes. Groups
' items by <roku:seriesId>, pulling series-level metadata (name, thumbnail,
' description) from the first item seen for each series. Any failure falls back to
' the bundled catalog so the app is never left empty.
sub OnFeedLoaded()
    raw = m.feedTask.responseRaw
    if raw = invalid or raw = ""
        OnFeedFailed()
        return
    end if
    xml = CreateObject("roXMLElement")
    if not xml.Parse(raw)
        OnFeedFailed()
        return
    end if

    ' Navigate to <channel> then its <item> children.
    channel = invalid
    for each c in xml.GetChildElements()
        if LCase(c.GetName()) = "channel" then channel = c
    end for
    if channel = invalid
        OnFeedFailed()
        return
    end if

    m.seriesMap = {}
    m.catalogOrder = []
    m.nowEpoch = CreateObject("roDateTime").AsSeconds()

    for each item in channel.GetChildElements()
        if LCase(item.GetName()) = "item"
            seriesId = FeedChildText(item, "seriesid")
            if seriesId = "" then seriesId = FeedChildText(item, "seriesname")
            if seriesId <> ""
                if not m.seriesMap.DoesExist(seriesId)
                    m.seriesMap[seriesId] = {
                        displayName: FeedChildText(item, "seriesname")
                        description: FeedChildText(item, "seriesdescription")
                        rating: FeedChildText(item, "rating")
                        thumbnailUrl: FeedChildText(item, "seriesthumbnail")
                        category: CategoryForSeries(seriesId)
                        episodes: []
                        seasons: []
                    }
                    m.catalogOrder.Push(seriesId)
                end if
                entry = m.seriesMap[seriesId]

                ' episode video + thumbnail live on <media:content> / nested <media:thumbnail>
                videoUrl = ""
                thumbUrl = ""
                content = FeedChild(item, "content")
                if content <> invalid
                    videoUrl = content.GetAttributes()["url"]
                    thumb = FeedChild(content, "thumbnail")
                    if thumb <> invalid then thumbUrl = thumb.GetAttributes()["url"]
                end if

                season = FeedChildText(item, "season")
                episode = FeedChildText(item, "episode")
                if season = "" then season = "1"

                ' Release-date lock: episodes whose release date is in the future are
                ' locked (playback blocked, lock icon shown). Fails OPEN - if no date
                ' is found or it can't be parsed, the episode stays unlocked.
                releaseText = FeedReleaseDateText(item)
                releaseEpoch = ParseFeedDate(releaseText)
                locked = false
                if releaseEpoch <> invalid and releaseEpoch > m.nowEpoch
                    locked = true
                end if

                entry.episodes.Push({
                    title: FeedChildText(item, "title")
                    description: FeedChildText(item, "description")
                    longDescription: FeedMediaDescription(item)
                    rating: FeedChildText(item, "rating")
                    durationMinutes: FeedDurationMinutes(content)
                    thumbUrl: thumbUrl
                    videoUrl: videoUrl
                    streamSlug: ""
                    season: season
                    episode: episode
                    locked: locked
                })
                if Instr(1, "|" + JoinSeasons(entry.seasons) + "|", "|" + season + "|") = 0
                    entry.seasons.Push(season)
                end if
            end if
        end if
    end for

    if m.seriesMap.Count() = 0
        OnFeedFailed()
        return
    end if

    BuildRowFromSeries(m.seriesMap)
    HideCatalogNotice()
end sub

sub OnFeedFailed()
    ' Feed unreachable or unparseable - fall back to the bundled catalog.
    LoadBundledCatalog()
end sub

' Returns the text of the first child whose name ends with the given suffix
' (namespace-agnostic: matches "season", "roku:season", etc.).
function FeedChildText(parent as Object, suffix as String) as String
    node = FeedChild(parent, suffix)
    if node = invalid then return ""
    t = node.GetText()
    if t = invalid then return ""
    return t
end function

function FeedChild(parent as Object, suffix as String) as Object
    kids = parent.GetChildElements()
    if kids = invalid then return invalid
    for each c in kids
        if InStr(1, LCase(c.GetName()), LCase(suffix)) > 0 then return c
    end for
    return invalid
end function

' media:content duration attribute is in seconds; convert to whole minutes.
function FeedDurationMinutes(content as Object) as Integer
    if content = invalid then return 0
    secs = content.GetAttributes()["duration"]
    if secs = invalid or secs = "" then return 0
    n = Val(secs)
    return Int(n / 60 + 0.5)
end function

' Looks for a release/air date on the item across the likely element names, in
' priority order. Returns the raw text (parsed by ParseFeedDate) or "".
function FeedReleaseDateText(item as Object) as String
    ' explicit release-date style fields first
    for each suffix in ["releasedate", "release_date", "airdate", "air_date", "dcdate", "date"]
        n = FeedChild(item, suffix)
        if n <> invalid
            t = n.GetText()
            if t <> invalid and t <> "" then return t
        end if
    end for
    ' fall back to the standard RSS pubDate
    n = FeedChild(item, "pubdate")
    if n <> invalid
        t = n.GetText()
        if t <> invalid then return t
    end if
    return ""
end function

' Flexible date parser -> epoch seconds, or invalid if unparseable. Handles the
' common feed formats: ISO 8601 (YYYY-MM-DD[...]), RFC 822 pubDate
' (e.g. "Wed, 02 Mar 2026 00:00:00 GMT"), and US MM/DD/YYYY. Anything else returns
' invalid so the caller fails open (episode stays unlocked).
function ParseFeedDate(text as String) as Dynamic
    if text = invalid or text = "" then return invalid
    t = text.Trim()
    dt = CreateObject("roDateTime")

    ' ISO 8601 first
    if InStr(1, t, "-") > 0 and (InStr(1, t, "T") > 0 or Len(t) = 10)
        iso = t
        if Len(t) = 10 then iso = t + "T00:00:00Z"
        dt.FromISO8601String(iso)
        s = dt.AsSeconds()
        if s > 0 then return s
    end if

    ' RFC 822: "Wed, 02 Mar 2026 00:00:00 GMT"  ->  build ISO and parse
    if InStr(1, t, ",") > 0 or InStr(1, t, " ") > 0
        parts = SplitBySpace(t)
        ' Expected token layout with weekday: [Wdy,] DD Mon YYYY [HH:MM:SS] ...
        idx = 0
        if parts.Count() >= 4
            ' detect if first token is a weekday (ends with comma)
            startI = 0
            if InStr(1, parts[0], ",") > 0 then startI = 1
            if parts.Count() > startI + 2
                dd = parts[startI]
                mon = MonthNumber(parts[startI + 1])
                yyyy = parts[startI + 2]
                if mon <> "" and Len(yyyy) = 4
                    iso = yyyy + "-" + mon + "-" + Right("0" + dd, 2) + "T00:00:00Z"
                    dt.FromISO8601String(iso)
                    s = dt.AsSeconds()
                    if s > 0 then return s
                end if
            end if
        end if
    end if

    ' US MM/DD/YYYY
    if InStr(1, t, "/") > 0
        seg = []
        cur = ""
        for i = 1 to Len(t)
            ch = Mid(t, i, 1)
            if ch = "/"
                seg.Push(cur) : cur = ""
            else
                cur = cur + ch
            end if
        end for
        seg.Push(cur)
        if seg.Count() >= 3
            mm = Right("0" + seg[0].Trim(), 2)
            dd = Right("0" + seg[1].Trim(), 2)
            yyyy = seg[2].Trim()
            if Len(yyyy) = 4
                iso = yyyy + "-" + mm + "-" + dd + "T00:00:00Z"
                dt.FromISO8601String(iso)
                s = dt.AsSeconds()
                if s > 0 then return s
            end if
        end if
    end if

    return invalid
end function

function SplitBySpace(s as String) as Object
    out = []
    cur = ""
    for i = 1 to Len(s)
        ch = Mid(s, i, 1)
        if ch = " "
            if cur <> "" then out.Push(cur)
            cur = ""
        else
            cur = cur + ch
        end if
    end for
    if cur <> "" then out.Push(cur)
    return out
end function

function MonthNumber(mon as String) as String
    m3 = LCase(Left(mon, 3))
    map = { jan:"01", feb:"02", mar:"03", apr:"04", may:"05", jun:"06", jul:"07", aug:"08", sep:"09", oct:"10", nov:"11", dec:"12" }
    if map.DoesExist(m3) then return map[m3]
    return ""
end function

' Prefer the richer <media:description> when present, else the plain <description>.
function FeedMediaDescription(item as Object) as String
    kids = item.GetChildElements()
    if kids = invalid then return ""
    for each c in kids
        nm = LCase(c.GetName())
        if InStr(1, nm, "media") > 0 and InStr(1, nm, "description") > 0
            t = c.GetText()
            if t <> invalid then return t
        end if
    end for
    return FeedChildText(item, "description")
end function

' Loads the bundled test catalog from pkg:/data/catalog.json (generated from the
' production episode CSV). Local file read - no network, no threading constraints.
sub LoadBundledCatalog()
    raw = ReadAsciiFile("pkg:/data/catalog.json")
    if raw = invalid or raw = ""
        ShowCatalogNotice("Bundled catalog missing (data/catalog.json)")
        BuildRowFromSeries({})
        return
    end if

    parsed = ParseJson(raw)
    if parsed = invalid or parsed.series = invalid
        ShowCatalogNotice("Bundled catalog failed to parse")
        BuildRowFromSeries({})
        return
    end if

    BuildCatalogFromJson(parsed)
    HideCatalogNotice()
end sub

' Hosted JSON catalog loaded (ApiConfig().catalogJsonUrl).
sub OnJsonCatalogLoaded()
    parsed = m.jsonTask.responseData
    if parsed = invalid or parsed.series = invalid
        OnJsonCatalogFailed()
        return
    end if
    BuildCatalogFromJson(parsed)
    HideCatalogNotice()
end sub

sub OnJsonCatalogFailed()
    ' JSON unreachable/unparseable -> try the MRSS feed, else bundled.
    cfg = ApiConfig()
    if cfg.feedUrl <> invalid and cfg.feedUrl <> ""
        m.feedTask = m.top.CreateChild("ApiTask")
        m.feedTask.responseType = "xml"
        m.feedTask.requestUrl = cfg.feedUrl
        m.feedTask.ObserveField("responseRaw", "OnFeedLoaded")
        m.feedTask.ObserveField("failed", "OnFeedFailed")
        m.feedTask.control = "RUN"
    else
        LoadBundledCatalog()
    end if
end sub

' Builds m.seriesMap from a parsed catalog.json object (series -> episodes). Shared by
' the hosted-JSON path and the bundled fallback so series art + release-date locking
' behave identically. Locks episodes whose releaseDate is in the future.
sub BuildCatalogFromJson(parsed as Object)
    m.seriesMap = {}
    m.catalogOrder = []
    m.nowEpoch = CreateObject("roDateTime").AsSeconds()

    for each s in parsed.series
        key = s.seriesKey
        entry = {
            displayName: s.title
            description: s.description
            rating: s.rating
            thumbnailUrl: s.thumbnailUrl
            category: CategoryForSeries(key)
            episodes: []
            seasons: []
        }
        for each e in s.episodes
            releaseEpoch = ParseFeedDate(e.releaseDate)
            locked = false
            if releaseEpoch <> invalid and releaseEpoch > m.nowEpoch then locked = true

            entry.episodes.Push({
                title: e.title
                description: e.description
                longDescription: e.longDescription
                rating: e.rating
                durationMinutes: e.durationMinutes
                thumbUrl: e.thumbnailUrl
                videoUrl: e.videoUrl
                streamSlug: ""
                season: e.season
                episode: e.episode
                locked: locked
            })
            if Instr(1, "|" + JoinSeasons(entry.seasons) + "|", "|" + e.season + "|") = 0
                entry.seasons.Push(e.season)
            end if
        end for
        m.seriesMap[key] = entry
        m.catalogOrder.Push(key)
    end for

    BuildRowFromSeries(m.seriesMap)
end sub

sub FetchNextShow()
    if m.showQueue.Count() = 0
        ' all shows fetched; now drain season/episode queue
        FetchNextSeason()
        return
    end if
    m.currentShow = m.showQueue.Shift()

    ' ensure the series entry exists up front (preserves order even if it has 0 eps)
    if not m.seriesMap.DoesExist(m.currentShow.seriesKey)
        m.seriesMap[m.currentShow.seriesKey] = {
            displayName: m.currentShow.name
            category: CategoryForSeries(m.currentShow.seriesKey)
            episodes: []
            seasons: []
        }
        m.catalogOrder.Push(m.currentShow.seriesKey)
    end if

    m.catalogTask.requestUrl = BuildShowUrl(m.currentShow.slug)
    m.catalogTask.control = "stop"
    m.catalogTask.control = "RUN"
end sub

sub OnShowLoaded()
    seasons = ParseShowSeasons(m.catalogTask.responseData)
    for each s in seasons
        m.seasonQueue.Push({
            slug: m.currentShow.slug
            seriesKey: m.currentShow.seriesKey
            seasonId: s.id
            seasonNumber: s.number
        })
    end for
    FetchNextShow()
end sub

sub OnShowFailed()
    ' skip this show, continue
    FetchNextShow()
end sub

sub FetchNextSeason()
    if m.seasonQueue.Count() = 0
        ' catalog complete
        BuildRowFromSeries(m.seriesMap)
        if m.seriesMap.Count() = 0
            ShowCatalogNotice("No catalog data returned from the API")
        else
            HideCatalogNotice()
        end if
        return
    end if
    m.currentSeason = m.seasonQueue.Shift()

    m.episodesTask = m.top.CreateChild("ApiTask")
    m.episodesTask.responseType = "json"
    m.episodesTask.authToken = FreecastConfig().apiKey
    m.episodesTask.ObserveField("responseData", "OnEpisodesLoaded")
    m.episodesTask.ObserveField("failed", "OnEpisodesFailed")
    m.episodesTask.requestUrl = BuildEpisodesUrl(m.currentSeason.slug, m.currentSeason.seasonId)
    m.episodesTask.control = "RUN"
end sub

sub OnEpisodesLoaded()
    eps = ParseEpisodes(m.episodesTask.responseData, m.currentSeason.seasonNumber)
    series = m.seriesMap[m.currentSeason.seriesKey]
    if series <> invalid
        for each ep in eps
            series.episodes.Push(ep)
        end for
        sn = m.currentSeason.seasonNumber
        if Instr(1, "|" + JoinSeasons(series.seasons) + "|", "|" + sn + "|") = 0
            series.seasons.Push(sn)
        end if
    end if
    FetchNextSeason()
end sub

sub OnEpisodesFailed()
    FetchNextSeason()
end sub

function JoinSeasons(arr as Object) as String
    s = ""
    for each v in arr
        s = s + v + "|"
    end for
    return s
end function

' Simple on-screen notice used while the catalog is empty (no key / no data),
' shown on the VOD grid so it's clear why nothing's there.
sub ShowCatalogNotice(msg as String)
    if m.catalogNotice = invalid
        m.catalogNotice = m.vodGridGroup.CreateChild("Label")
        m.catalogNotice.translation = [60, 400]
        m.catalogNotice.width = 1800
        m.catalogNotice.color = m.humidor.smoke300
        m.catalogNotice.font = PoppinsFont("medium", 28)
    end if
    m.catalogNotice.text = msg
    m.catalogNotice.visible = true
end sub

sub HideCatalogNotice()
    if m.catalogNotice <> invalid then m.catalogNotice.visible = false
end sub

' EPG schema is unconfirmed (the feed domain isn't reachable for me to inspect
' directly) - this assumes standard XMLTV: <programme start="YYYYMMDDHHMMSS +0000"
' stop="..." channel="..."><title>...</title></programme>. If the real feed uses
' different element/attribute names, this will silently fall back to the generic
' "Watch the live linear channel" subtitle rather than crash - send a sample chunk
' of the actual XML if the now/next text doesn't show up correctly on device.
sub LoadEpg()
    m.epgTask.responseType = "xml"
    m.epgTask.requestUrl = m.cfg.epgUrl
    m.epgTask.ObserveField("responseRaw", "OnEpgLoaded")
    m.epgTask.ObserveField("failed", "OnEpgFailed")
    m.epgTask.control = "RUN"
end sub

sub OnEpgLoaded()
    raw = m.epgTask.responseRaw
    if raw = invalid or raw = "" then return

    xml = CreateObject("roXMLElement")
    ok = xml.Parse(raw)
    if not ok then return

    ' Build a normalized, time-sorted programme list we can reuse for both the
    ' home-screen now/next and the in-player 1hr EPG overlay.
    progs = []
    children = xml.GetChildElements()
    if children <> invalid
        for each c in children
            if LCase(c.GetName()) = "programme"
                attrs = c.GetAttributes()
                if attrs <> invalid
                    startSec = ParseXmltvTime(attrs["start"])
                    stopSec = ParseXmltvTime(attrs["stop"])
                    if startSec <> invalid and stopSec <> invalid
                        progs.Push({
                            start: startSec
                            stop: stopSec
                            title: GetChildTextBySuffix(c, "title")
                            episode: GetEpgSubTitle(c)
                        })
                    end if
                end if
            end if
        end for
    end if
    if progs.Count() = 0 then return

    ' sort by start time (insertion sort; EPG lists are modest)
    for i = 1 to progs.Count() - 1
        key = progs[i]
        j = i - 1
        while j >= 0 and progs[j].start > key.start
            progs[j + 1] = progs[j]
            j = j - 1
        end while
        progs[j + 1] = key
    end for
    m.epgProgrammes = progs

    ComputeNowNext()
    UpdateChooserEpgText()
end sub

sub ComputeNowNext()
    if m.epgProgrammes = invalid then return
    nowSeconds = CreateObject("roDateTime").AsSeconds()

    m.epgNowTitle = ""
    m.epgNowEpisode = ""
    m.epgNextTitle = ""
    m.epgNextEpisode = ""

    for i = 0 to m.epgProgrammes.Count() - 1
        p = m.epgProgrammes[i]
        if nowSeconds >= p.start and nowSeconds < p.stop
            m.epgNowTitle = UCase(p.title)
            m.epgNowEpisode = p.episode
            if i + 1 < m.epgProgrammes.Count()
                m.epgNextTitle = UCase(m.epgProgrammes[i + 1].title)
                m.epgNextEpisode = m.epgProgrammes[i + 1].episode
            end if
            return
        end if
    end for
end sub

' XMLTV episode name lives in <sub-title>; not all feeds populate it. Returns "" when
' absent so the UI can fall back to just the show title.
function GetEpgSubTitle(prog as Object) as String
    children = prog.GetChildElements()
    if children = invalid then return ""
    for each c in children
        nm = LCase(c.GetName())
        if InStr(1, nm, "sub-title") > 0 or InStr(1, nm, "subtitle") > 0
            return c.GetText()
        end if
    end for
    return ""
end function

sub OnEpgFailed()
    ' leave the generic chooser subtitle in place
end sub

' Parses "YYYYMMDDHHMMSS +0000" (XMLTV standard) into epoch seconds. Returns invalid
' on anything unexpected rather than guessing.
function ParseXmltvTime(raw as String) as Object
    if raw = invalid or Len(raw) < 14 then return invalid
    dt = CreateObject("roDateTime")
    year = Val(Mid(raw, 1, 4))
    month = Val(Mid(raw, 5, 2))
    day = Val(Mid(raw, 7, 2))
    hour = Val(Mid(raw, 9, 2))
    minute = Val(Mid(raw, 11, 2))
    second = Val(Mid(raw, 13, 2))
    dt.FromISO8601String(Str(year).Trim() + "-" + Right("0" + Str(month).Trim(), 2) + "-" + Right("0" + Str(day).Trim(), 2) + "T" + Right("0" + Str(hour).Trim(), 2) + ":" + Right("0" + Str(minute).Trim(), 2) + ":" + Right("0" + Str(second).Trim(), 2) + "Z")
    return dt.AsSeconds()
end function

sub UpdateChooserEpgText()
    if m.liveNow = invalid then return
    ' Home screen shows the sub-title (episode name) only. Falls back to the show
    ' title when a given programme has no sub-title.
    if m.epgNowTitle <> invalid and (m.epgNowTitle <> "" or m.epgNowEpisode <> "")
        m.liveNow.text = "NOW: " + EpgHomeLine(m.epgNowTitle, m.epgNowEpisode)
    end if
    if m.epgNextTitle <> invalid and (m.epgNextTitle <> "" or m.epgNextEpisode <> "")
        m.liveNext.text = "NEXT: " + EpgHomeLine(m.epgNextTitle, m.epgNextEpisode)
    end if
end sub

' Prefers the episode sub-title; only falls back to the show title if no sub-title.
function EpgHomeLine(title as String, episode as String) as String
    if episode <> invalid and episode <> "" then return UCase(episode)
    return title
end function

' Combines show title and episode name as "TITLE - Episode Name" when an episode
' name exists, otherwise just the title. (Used by the in-player overlay.)
function EpgLine(title as String, episode as String) as String
    if episode <> invalid and episode <> ""
        return title + " - " + episode
    end if
    return title
end function
' Returns all episodes for a given series + season, sorted by episode number.
function EpisodesForSeason(series as Object, seasonNum as String) as Object
    matches = []
    for each ep in series.episodes
        if ep.season = seasonNum then matches.Push(ep)
    end for

    for i = 1 to matches.Count() - 1
        key = matches[i]
        j = i - 1
        while j >= 0 and Val(matches[j].episode) > Val(key.episode)
            matches[j + 1] = matches[j]
            j = j - 1
        end while
        matches[j + 1] = key
    end for

    return matches
end function

function GetChildTextBySuffix(parent as Object, suffix as String) as String
    children = parent.GetChildElements()
    if children = invalid then return ""
    for each c in children
        if InStr(1, LCase(c.GetName()), LCase(suffix)) > 0
            return c.GetText()
        end if
    end for
    return ""
end function

sub FireAppLaunchComplete()
    if m.appLaunchBeaconFired = invalid or m.appLaunchBeaconFired = false
        m.top.signalBeacon("AppLaunchComplete")
        m.appLaunchBeaconFired = true
    end if
end sub


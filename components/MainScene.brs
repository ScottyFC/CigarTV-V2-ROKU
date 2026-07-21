sub Init()
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
    GoToChooser()

    m.top.SetFocus(true)

    ' In-app splash overlay: created LAST so it sits above everything, held 3s, then
    ' faded out. The scene is already fully built + focused, so it stays interactive
    ' underneath and any key press dismisses the splash instantly (guaranteed escape).
    BuildSplashOverlay()
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
end sub

' ============================================================
' CHOOSER / HOME SCREEN
' Logo left (slow pulse), two stacked panels right: Live (with
' now/next) on top, Browse Our Shows below.
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
    m.smokeClock = 0.0
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
    UpdateChooserHighlight()
    UpdateChooserEpgText()
end sub

' ============================================================
' VOD GRID ("Originals") - 4-column grid, pill header, back btn
' ============================================================
sub BuildVodGridScreen()
    m.vodGridGroup = m.top.CreateChild("Group")

    m.vodBackGlow = m.vodGridGroup.CreateChild("Poster")
    m.vodBackGlow.uri = "pkg:/images/focusframe.png"
    m.vodBackGlow.translation = [48, 56]
    m.vodBackGlow.width = 88
    m.vodBackGlow.height = 88
    m.vodBackGlow.visible = false

    m.vodBackBtn = m.vodGridGroup.CreateChild("Poster")
    m.vodBackBtn.uri = "pkg:/images/back.png"
    m.vodBackBtn.translation = [56, 64]
    m.vodBackBtn.width = 72
    m.vodBackBtn.height = 72

    m.vodHeaderLogo = m.vodGridGroup.CreateChild("Poster")
    m.vodHeaderLogo.uri = "pkg:/images/logo.png"
    m.vodHeaderLogo.translation = [160, 60]
    m.vodHeaderLogo.width = 80
    m.vodHeaderLogo.height = 66
    m.vodHeaderLogo.loadDisplayMode = "scaleToFit"

    m.vodHeaderLabel = m.vodGridGroup.CreateChild("Label")
    m.vodHeaderLabel.text = "Originals"
    m.vodHeaderLabel.translation = [256, 76]
    m.vodHeaderLabel.color = m.humidor.paper
    m.vodHeaderLabel.font = PoppinsFont("bold", 40)

    m.showRows = m.vodGridGroup.CreateChild("Group")
    m.showRows.translation = [90, 200]
    m.vodGridGroup.visible = false
end sub

sub GoToVodGrid()
    m.screen = "vodGrid"
    m.focusZone = "vodGrid"
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

    rowH = 168
    thumbW = 240
    thumbH = 135

    for i = 0 to episodes.Count() - 1
        ep = episodes[i]
        y = i * rowH

        rowGroup = m.guideList.CreateChild("Group")
        rowGroup.translation = [0, y]

        focusBar = rowGroup.CreateChild("Rectangle")
        focusBar.color = m.humidor.ember
        focusBar.width = 6
        focusBar.height = thumbH
        focusBar.translation = [-26, 0]
        focusBar.visible = (i = 0)

        thumb = rowGroup.CreateChild("Poster")
        thumb.uri = ep.thumbUrl
        thumb.width = thumbW
        thumb.height = thumbH
        thumb.translation = [0, 0]
        thumb.loadDisplayMode = "scaleToFill"

        textX = thumbW + 30

        epNum = rowGroup.CreateChild("Label")
        meta = "EPISODE " + ep.episode
        if ep.durationMinutes <> invalid and ep.durationMinutes > 0
            meta = meta + "  -  " + Str(ep.durationMinutes).Trim() + " MIN"
        end if
        if ep.rating <> invalid and ep.rating <> ""
            meta = meta + "  -  " + ep.rating
        end if
        epNum.text = meta
        epNum.translation = [textX, 4]
        epNum.color = m.humidor.smoke300
        epNum.font = PoppinsFont("semibold", 17)

        epTitle = rowGroup.CreateChild("Label")
        epTitle.text = ep.title
        epTitle.translation = [textX, 26]
        epTitle.width = 1360
        epTitle.color = m.humidor.ember
        epTitle.font = PoppinsFont("bold", 24)
        epTitle.wrap = false
        epTitle.maxLines = 1
        epTitle.ellipsisText = "..."

        epDesc = rowGroup.CreateChild("Label")
        epDesc.text = ep.description
        epDesc.translation = [textX, 62]
        epDesc.width = 1360
        epDesc.color = m.humidor.smoke100
        epDesc.font = PoppinsFont("regular", 16)
        epDesc.wrap = true
        epDesc.maxLines = 3

        m.guideRows.Push(focusBar)
    end for

    m.guideFocusIndex = 0
    m.guideList.translation = [0, 0]
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

    ' --- EPG overlay (live only): bottom strip, auto-hides after 5s ---
    m.epgOverlay = m.playerGroup.CreateChild("Group")
    m.epgOverlay.translation = [0, 840]

    m.epgOverlayBg = m.epgOverlay.CreateChild("Rectangle")
    m.epgOverlayBg.color = "0x0D0C0BE6"
    m.epgOverlayBg.width = 1920
    m.epgOverlayBg.height = 240

    m.epgOverlayAccent = m.epgOverlay.CreateChild("Rectangle")
    m.epgOverlayAccent.color = m.humidor.ember
    m.epgOverlayAccent.width = 1920
    m.epgOverlayAccent.height = 4

    m.epgOverlayHeader = m.epgOverlay.CreateChild("Label")
    m.epgOverlayHeader.text = "UP NEXT ON CIGARTV LIVE"
    m.epgOverlayHeader.translation = [60, 24]
    m.epgOverlayHeader.color = m.humidor.ember
    m.epgOverlayHeader.font = PoppinsFont("bold", 28)

    m.epgOverlayRow = m.epgOverlay.CreateChild("Group")
    m.epgOverlayRow.translation = [60, 80]

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

sub PlayEpisodeAtIndex(index as Integer)
    if m.currentEpisodes = invalid or index < 0 or index >= m.currentEpisodes.Count() then return
    m.screen = "player"
    m.playerMode = "vod"
    m.playerEpisodeIndex = index
    ep = m.currentEpisodes[index]

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
    m.gridCols = 3
    cardW = 560
    cardH = 315
    gapX = 30
    gapY = 36
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
            row = i \ m.gridCols
            col = i mod m.gridCols

            ' Prefer the branded series key art; fall back to first episode thumb.
            art = ""
            if series.thumbnailUrl <> invalid then art = series.thumbnailUrl
            if art = "" then art = series.episodes[0].thumbUrl

            card = m.showRows.CreateChild("ShowCard")
            card.cardWidth = cardW
            card.cardHeight = cardH
            card.cardTitle = series.displayName
            card.cardSubtitle = ""
            card.cardCategory = series.category
            card.cardTime = ""
            card.cardThumbUrl = art
            card.artOnly = (series.thumbnailUrl <> invalid and series.thumbnailUrl <> "")
            card.cardProgress = 0.0
            card.translation = [col * (cardW + gapX), row * (cardH + gapY)]
            m.cards.Push(card)
            m.cardSeriesKeys.Push(seriesKey)
            i = i + 1
        end if
    end for

    m.focusIndex = 0
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

    ' Back-button focus mode: reached by pressing Up from the top row.
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

    cols = m.gridCols
    count = m.cards.Count()
    row = m.focusIndex \ cols
    col = m.focusIndex mod cols
    newIndex = m.focusIndex

    if key = "right" and col < cols - 1 and m.focusIndex + 1 < count
        newIndex = m.focusIndex + 1
    else if key = "left" and col > 0
        newIndex = m.focusIndex - 1
    else if key = "down" and m.focusIndex + cols < count
        newIndex = m.focusIndex + cols
    else if key = "up"
        if row > 0
            newIndex = m.focusIndex - cols
        else
            ' top row + Up -> focus the on-screen back button
            m.cards[m.focusIndex].isFocused = false
            m.vodBackFocused = true
            m.vodBackGlow.visible = true
            return true
        end if
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
    end if
    return true
end function

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
        m.guideRows[m.guideFocusIndex].visible = false
        m.guideFocusIndex = m.guideFocusIndex + 1
        m.guideRows[m.guideFocusIndex].visible = true
        ScrollGuideList()
        return true
    else if key = "up"
        if m.guideFocusIndex > 0
            m.guideRows[m.guideFocusIndex].visible = false
            m.guideFocusIndex = m.guideFocusIndex - 1
            m.guideRows[m.guideFocusIndex].visible = true
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
        if m.guideRows.Count() > 0 then m.guideRows[0].visible = true
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

    ' Preferred source: a hosted MRSS feed (see ApiConfig().feedUrl). Fetched async;
    ' on success it's parsed into m.seriesMap, on any failure we fall back to bundled.
    cfg = ApiConfig()
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

    m.seriesMap = {}
    m.catalogOrder = []

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
            })
            if Instr(1, "|" + JoinSeasons(entry.seasons) + "|", "|" + e.season + "|") = 0
                entry.seasons.Push(e.season)
            end if
        end for
        m.seriesMap[key] = entry
        m.catalogOrder.Push(key)
    end for

    BuildRowFromSeries(m.seriesMap)
    HideCatalogNotice()
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


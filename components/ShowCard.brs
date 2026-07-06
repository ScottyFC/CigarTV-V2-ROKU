sub Init()
    h = HumidorTheme()
    w = m.top.cardWidth
    height = m.top.cardHeight
    pad = 24

    m.cardW = w
    m.cardH = height

    ' Poster fills the card
    m.thumbPoster = m.top.CreateChild("Poster")
    m.thumbPoster.width = w
    m.thumbPoster.height = height
    m.thumbPoster.loadDisplayMode = "scaleToFill"

    ' Gradient scrim (transparent -> dark) stretched over the lower portion, for
    ' smooth text legibility instead of a hard-edged rectangle.
    scrimH = height * 0.62
    m.scrim = m.top.CreateChild("Poster")
    m.scrim.uri = "pkg:/images/scrim.png"
    m.scrim.translation = [0, height - scrimH]
    m.scrim.width = w
    m.scrim.height = scrimH

    ' Ember glow frame, shown on focus (soft, premium highlight)
    m.glow = m.top.CreateChild("Poster")
    m.glow.uri = "pkg:/images/focusframe.png"
    m.glow.translation = [-6, -6]
    m.glow.width = w + 12
    m.glow.height = height + 12
    m.glow.visible = false

    m.titleLabel = m.top.CreateChild("Label")
    m.titleLabel.color = h.paper
    m.titleLabel.translation = [pad, height - 78]
    m.titleLabel.width = w - (pad * 2)
    m.titleLabel.font = PoppinsFont("extrabold", 34)
    m.titleLabel.wrap = false
    m.titleLabel.maxLines = 1
    m.titleLabel.ellipsisText = "..."

    m.categoryBadge = m.top.CreateChild("Label")
    m.categoryBadge.color = h.ember
    m.categoryBadge.translation = [pad, height - 38]
    m.categoryBadge.width = w - (pad * 2)
    m.categoryBadge.font = PoppinsFont("semibold", 20)

    ' Focus scale state (smooth grow/shrink driven by a short timer)
    m.scale = 1.0
    m.scaleTarget = 1.0
    m.top.scaleRotateCenter = [w / 2, height / 2]

    m.scaleTimer = m.top.CreateChild("Timer")
    m.scaleTimer.duration = 0.02
    m.scaleTimer.repeat = true
    m.scaleTimer.ObserveField("fire", "OnScaleTick")
end sub

sub OnScaleTick()
    if Abs(m.scale - m.scaleTarget) < 0.004
        m.scale = m.scaleTarget
        m.top.scale = [m.scale, m.scale]
        m.scaleTimer.control = "stop"
        return
    end if
    ' ease toward target
    m.scale = m.scale + (m.scaleTarget - m.scale) * 0.35
    m.top.scale = [m.scale, m.scale]
end sub

sub onDataChange()
    if m.titleLabel = invalid then return
    m.titleLabel.text = m.top.cardTitle
    m.categoryBadge.text = UCase(m.top.cardCategory)
    if m.top.cardThumbUrl <> ""
        m.thumbPoster.uri = m.top.cardThumbUrl
    end if
end sub

sub onFocusChange()
    if m.glow = invalid then return
    if m.top.isFocused
        m.glow.visible = true
        m.scaleTarget = 1.06
    else
        m.glow.visible = false
        m.scaleTarget = 1.0
    end if
    m.scaleTimer.control = "start"
end sub

sub onGridFocusChange()
    m.top.isFocused = m.top.rowListItemFocused
end sub

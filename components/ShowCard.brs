sub Init()
    h = HumidorTheme()

    m.thumbPoster = m.top.CreateChild("Poster")
    m.thumbPoster.loadDisplayMode = "scaleToFill"

    m.scrim = m.top.CreateChild("Poster")
    m.scrim.uri = "pkg:/images/scrim.png"

    m.glow = m.top.CreateChild("Poster")
    m.glow.uri = "pkg:/images/focusframe.png"
    m.glow.visible = false

    m.titleLabel = m.top.CreateChild("Label")
    m.titleLabel.color = h.paper
    m.titleLabel.font = PoppinsFont("extrabold", 34)
    m.titleLabel.wrap = false
    m.titleLabel.maxLines = 1
    m.titleLabel.ellipsisText = "..."

    m.categoryBadge = m.top.CreateChild("Label")
    m.categoryBadge.color = h.ember
    m.categoryBadge.font = PoppinsFont("semibold", 20)

    m.scale = 1.0
    m.scaleTarget = 1.0

    m.scaleTimer = m.top.CreateChild("Timer")
    m.scaleTimer.duration = 0.02
    m.scaleTimer.repeat = true
    m.scaleTimer.ObserveField("fire", "OnScaleTick")

    Layout()
end sub

' Sizes/positions every child from the CURRENT cardWidth/cardHeight. Runs at Init
' and again whenever the dimensions change (they're set after CreateChild returns,
' so Init alone would lay out at the default size - that was the grid-spacing bug).
sub Layout()
    if m.thumbPoster = invalid then return
    w = m.top.cardWidth
    height = m.top.cardHeight
    pad = 24
    scrimH = height * 0.62

    m.thumbPoster.width = w
    m.thumbPoster.height = height

    m.scrim.translation = [0, height - scrimH]
    m.scrim.width = w
    m.scrim.height = scrimH

    m.glow.translation = [-6, -6]
    m.glow.width = w + 12
    m.glow.height = height + 12

    m.titleLabel.translation = [pad, height - 78]
    m.titleLabel.width = w - (pad * 2)

    m.categoryBadge.translation = [pad, height - 38]
    m.categoryBadge.width = w - (pad * 2)

    m.top.scaleRotateCenter = [w / 2, height / 2]
end sub

sub onSizeChange()
    Layout()
end sub

sub OnScaleTick()
    if Abs(m.scale - m.scaleTarget) < 0.004
        m.scale = m.scaleTarget
        m.top.scale = [m.scale, m.scale]
        m.scaleTimer.control = "stop"
        return
    end if
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
    showText = not m.top.artOnly
    m.scrim.visible = showText
    m.titleLabel.visible = showText
    m.categoryBadge.visible = showText
end sub

sub onFocusChange()
    if m.glow = invalid then return
    if m.top.isFocused
        m.glow.visible = true
        m.scaleTarget = 1.05
    else
        m.glow.visible = false
        m.scaleTarget = 1.0
    end if
    m.scaleTimer.control = "start"
end sub

sub onGridFocusChange()
    m.top.isFocused = m.top.rowListItemFocused
end sub

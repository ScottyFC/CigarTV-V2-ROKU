function Theme() as Object
    return {
        bgPrimary: "0x0A0A0AFF"
        bgCard: "0x1E1E22FF"
        bgCardActive: "0x262629FF"
        bgTicker: "0x1A2438FF"
        accentGold: "0xF0C355FF"
        accentBlue: "0x4A90D9FF"
        textWhite: "0xFFFFFFFF"
        textGray: "0xA0A0A5FF"
        badgeBg: "0x000000CC"
        cardWidth: 360
        cardHeight: 150
        cardSpacing: 24
        font: "font:MediumBoldSystemFont"
        fontTitle: "font:LargeBoldSystemFont"
    }
end function

' Palette translated from humidorstyle.ts Tailwind tokens, with the exact brand
' accent (#f3d389) provided by the user. Other tokens remain best-guess until the
' real CSS variable values are shared.
function HumidorTheme() as Object
    return {
        emberLight: "0xF8E2A8FF"
        ember: "0xF3D389FF"      ' exact brand yellow / highlight color
        emberDeep: "0xD9690FFF"
        leather: "0x6B4226FF"
        leatherDark: "0x4A2D18FF"
        leatherDeep: "0x2E1B0FFF"
        smoke100: "0xE6E4E1FF"
        smoke300: "0xADA8A1FF"
        smoke500: "0x6B655FFF"
        smoke700: "0x3A3633FF"
        smoke800: "0x252220FF"
        char: "0x0D0C0BFF"
        ink: "0x070706FF"
        paper: "0xFFFFFFFF"
    }
end function

' Poppins font registry (registered in the manifest). Helper returns a usable font node.
function PoppinsFont(weight as String, size as Integer) as Object
    f = CreateObject("roSGNode", "Font")
    uri = "pkg:/fonts/Poppins-Regular.ttf"
    if weight = "bold" then uri = "pkg:/fonts/Poppins-Bold.ttf"
    if weight = "semibold" then uri = "pkg:/fonts/Poppins-SemiBold.ttf"
    if weight = "medium" then uri = "pkg:/fonts/Poppins-Medium.ttf"
    if weight = "extrabold" then uri = "pkg:/fonts/Poppins-ExtraBold.ttf"
    f.uri = uri
    f.size = size
    return f
end function

' Modesto display font - used for show/series titles (hero + episode-guide header).
function ModestoFont(size as Integer) as Object
    f = CreateObject("roSGNode", "Font")
    f.uri = "pkg:/fonts/Modesto-Regular.otf"
    f.size = size
    return f
end function

' Maps a series key to its background image and show logo. Backgrounds fall back to
' fallback.png when no specific one is assigned; show logos return "" when none exists.
function SeriesAssets(seriesKey as String) as Object
    bgMap = {
        BEHINDBLEND: "behindblend.jpg"
        UNROLLED: "unrolled.jpg"
        LOUNGELIFE: "loungelife.jpg"
        CIGARDOC: "cigardoc.jpg"
    }
    logoMap = {
        BEHINDBLEND: "behindblend.png"
        BURNRATE: "burnrate.png"
        CIGARESSENTIAL: "cigaressential.png"
        CIGARDOC: "cigardoc.png"
        LOUNGELIFE: "loungelife.png"
        UNROLLED: "unrolled.png"
    }
    key = UCase(seriesKey)
    bg = "pkg:/images/backgrounds/fallback.jpg"
    if bgMap.DoesExist(key) then bg = "pkg:/images/backgrounds/" + bgMap[key]
    logo = ""
    if logoMap.DoesExist(key) then logo = "pkg:/images/showlogos/" + logoMap[key]
    return { background: bg, logo: logo }
end function

' Maps known series keys to a category label for the badge; falls back to "Episode".
function CategoryForSeries(seriesId as String) as String
    map = {
        BEHINDBLEND: "Talk Show"
        LOUNGELIFE: "Documentary"
        BURNRATE: "Reviews"
        CREEKSIDE: "Reviews"
        UNROLLED: "Talk Show"
        CIGARESSENTIAL: "Reviews"
        CIGARDOC: "Documentary"
        CIGARGUYS: "Talk Show"
    }
    key = UCase(seriesId)
    if map.DoesExist(key) then return map[key]
    return "Episode"
end function

function ApiConfig() as Object
    return {
        liveStreamUrl: "https://amg30862-amg30862c1-amgplt0065.playout.now3.amagi.tv/ts-us-e2-n2/playlist/amg30862-amg30862c1-amgplt0065/playlist.m3u8"
        epgUrl: "https://d31l2nn7dlh4li.cloudfront.net/amg30862/epg_deliveries/amgplt0065/amg30862c1/amg30862c1.xml"

        ' ---- VOD catalog source ----
        ' Priority order: catalogJsonUrl (hosted JSON, same schema as data/catalog.json)
        ' -> feedUrl (hosted MRSS) -> bundled data/catalog.json. Both hosted paths read
        ' releaseDate for locking and series thumbnailUrl for the VOD art. Use HTTPS.
        catalogJsonUrl: "https://d3h1d86sioogzh.cloudfront.net/00_CHANNEL_ASSETS/MRSS_FEEDS/catalog.json"
        feedUrl: "https://d3h1d86sioogzh.cloudfront.net/00_CHANNEL_ASSETS/MRSS_FEEDS/RokuV2Feed.xml"

        ' ---- Device activation (registration screen) ----
        ' Registration/activation removed for now; config retained (empty) for when it
        ' is revisited so nothing else needs to change.
        activationUrl: ""
        registrationVideoUrl: ""
    }
end function

' ============================================================
' FREECAST API (full catalog + streaming architecture)
' ============================================================
' The app is fully API-driven: the catalog (shows -> seasons -> episodes) and
' playback (streams) all come from freecast. Integration is a two-value change:
' set apiKey and flip enabled. Everything else is wired.
'
' Catalog flow (per the freecast VOD API):
'   1. For each show slug in `shows`, GET {baseUrl}/shows/{slug}
'        -> show metadata + list of season ids
'   2. For each season id, GET {baseUrl}/shows/{slug}/episodes/?season_id={id}
'        -> episode list (title, description, thumbnail, episode stream slug)
'   3. On play, GET {baseUrl}/episodes/{episodeSlug}/streams?stream_format=all
'        -> array of stream options (resolved in Freecast.brs)
function FreecastConfig() as Object
    return {
        ' Base of the freecast VOD API.
        baseUrl: "https://api-services.freecast.com/guide/api/v5/watch-freecast-com/web/vod"

        ' TODO(plug-in-at-test): auth token / API key. Sent as a Bearer header on
        ' every catalog + stream request. App shows an empty state until this is set.
        apiKey: ""

        ' The set of shows to load, in display order. slug is the freecast show id;
        ' seriesKey maps to our local assets (logos/backgrounds/category).
        shows: [
            { slug: "mcs-BEHINDBLEND-cigar", seriesKey: "BEHINDBLEND", name: "Behind The Blend" }
            { slug: "mcs-BURNRATE-cigar", seriesKey: "BURNRATE", name: "Burn Rate" }
            { slug: "mcs-CIGARESSENTIALS-cigar", seriesKey: "CIGARESSENTIAL", name: "Cigar Essentials" }
            { slug: "mcs-CIGARDOCS-cigar", seriesKey: "CIGARDOC", name: "Cigar TV Original Documentaries" }
            { slug: "mcs-LOUNGELIFE-cigar", seriesKey: "LOUNGELIFE", name: "Lounge Life" }
            { slug: "mcs-UNROLLED-cigar", seriesKey: "UNROLLED", name: "Unrolled" }
        ]

        ' Roku plays HLS natively and supports Widevine DRM. Resolver preference order:
        ' HLS-clear first, then DASH+Widevine for DRM. The example's FairPlay HLS entry
        ' is Apple-only and intentionally never selected for Roku.
        preferredOrder: [
            { stream_format: "hls", is_drm: false }
            { stream_format: "dash", is_drm: true, drm_type: "widevine" }
            { stream_format: "dash", is_drm: false }
        ]

        enabled: false  ' master switch; flip to true once apiKey is set
    }
end function

' ============================================================
' FREECAST CATALOG (shows -> seasons -> episodes)
' ============================================================
function BuildShowUrl(slug as String) as String
    fc = FreecastConfig()
    return fc.baseUrl + "/shows/" + slug
end function

function BuildEpisodesUrl(slug as String, seasonId as String) as String
    fc = FreecastConfig()
    return fc.baseUrl + "/shows/" + slug + "/episodes/?season_id=" + seasonId
end function

' --- ASSUMED JSON SHAPES ---------------------------------------------------
' These two parsers are written against a best-guess of the show and episodes
' responses (only the /streams response shape is confirmed). They are defensive
' and isolated so correcting them against a real sample is a single-function
' change each. Assumed:
'   SHOW:     { seasons: [ { id, number } ] }
'   EPISODES: { episodes: [ { title, description, thumbnail_url, stream_slug,
'               season, episode, rating } ] }
' If the live responses differ, adjust ParseShowSeasons / ParseEpisodes only.
function ParseShowSeasons(showData as Object) as Object
    seasons = []
    if showData = invalid then return seasons
    root = showData
    if root.data <> invalid then root = root.data
    if root.result <> invalid then root = root.result
    arr = root.seasons
    if arr = invalid then return seasons
    for each s in arr
        id = ""
        num = ""
        if s.id <> invalid then id = BoxToStr(s.id)
        if s.season_id <> invalid then id = BoxToStr(s.season_id)
        if s.number <> invalid then num = BoxToStr(s.number)
        if s.season_number <> invalid then num = BoxToStr(s.season_number)
        if id <> "" then seasons.Push({ id: id, number: num })
    end for
    return seasons
end function

function ParseEpisodes(epData as Object, seasonNumber as String) as Object
    episodes = []
    if epData = invalid then return episodes
    root = epData
    if root.data <> invalid then root = root.data
    if root.result <> invalid then root = root.result
    arr = root.episodes
    if arr = invalid then arr = root.items
    if arr = invalid then return episodes
    for each e in arr
        ep = {
            title: PickStr(e, ["title", "name"])
            description: PickStr(e, ["description", "summary", "synopsis"])
            rating: PickStr(e, ["rating", "content_rating"])
            thumbUrl: PickStr(e, ["thumbnail_url", "thumbnail", "image", "poster"])
            streamSlug: PickStr(e, ["stream_slug", "slug", "id", "episode_slug"])
            season: seasonNumber
            episode: PickStr(e, ["episode", "episode_number", "number"])
        }
        episodes.Push(ep)
    end for
    return episodes
end function

function PickStr(obj as Object, keys as Object) as String
    if obj = invalid then return ""
    for each k in keys
        if obj[k] <> invalid
            v = BoxToStr(obj[k])
            if v <> "" then return v
        end if
    end for
    return ""
end function

function BoxToStr(v as Dynamic) as String
    if v = invalid then return ""
    if Type(v) = "roString" or Type(v) = "String" then return v
    if Type(v) = "roInt" or Type(v) = "Integer" then return v.ToStr()
    if Type(v) = "roFloat" or Type(v) = "Float" then return Str(v).Trim()
    return ""
end function

' ============================================================
' FREECAST STREAM RESOLVER
' ============================================================
' Turns the streams-API JSON array (see apicall.ts) into a play-ready Roku
' ContentNode. Nothing here needs changing at integration time - only the two
' values in FreecastConfig() (apiKey) and flipping `enabled`.
'
' Flow once enabled:
'   1. BuildStreamsUrl(streamId)  -> full streams endpoint URL
'   2. ApiTask fetches it (with Bearer apiKey) -> JSON array
'   3. PickBestStream(array)      -> the one Roku-playable entry we prefer
'   4. BuildContentFromStream(..) -> ContentNode (sets url, streamFormat, DRM)
'

' Composes the streams endpoint URL for a given episode stream slug (from the
' episodes response). The slug is now real catalog data, not a guess.
function BuildStreamsUrl(streamSlug as String) as String
    fc = FreecastConfig()
    return fc.baseUrl + "/episodes/" + streamSlug + "/streams?stream_format=all"
end function

' Selects the best stream entry from the parsed API array according to
' FreecastConfig().preferredOrder. Returns the matching assoc-array entry, or
' invalid if none of the preferred formats are present.
function PickBestStream(streams as Object) as Object
    if streams = invalid or GetInterface(streams, "ifArray") = invalid then return invalid
    fc = FreecastConfig()

    for each pref in fc.preferredOrder
        for each s in streams
            if s.stream_format = pref.stream_format and s.is_drm = pref.is_drm
                ' if the preference names a drm_type, require it to match
                if pref.drm_type = invalid or pref.drm_type = ""
                    return s
                else
                    dt = ""
                    if s.data <> invalid and s.data.drm_type <> invalid then dt = s.data.drm_type
                    if dt = pref.drm_type then return s
                end if
            end if
        end for
    end for

    return invalid
end function

' Builds a play-ready ContentNode from a chosen stream entry. Handles clear HLS/DASH
' and Widevine-protected DASH (the DRM scheme Roku supports; the example's FairPlay
' HLS entry is intentionally never selected for Roku).
function BuildContentFromStream(stream as Object, title as String) as Object
    content = CreateObject("roSGNode", "ContentNode")
    if stream = invalid or stream.data = invalid then return content

    content.url = stream.data.media_url
    content.title = title
    content.live = false

    if stream.stream_format = "hls"
        content.streamFormat = "hls"
    else if stream.stream_format = "dash"
        content.streamFormat = "dash"
    end if

    ' Widevine DRM wiring for DASH. Roku expects the license server on the content
    ' node's DRM params. cert_url is optional for Widevine.
    if stream.is_drm = true and stream.data.drm_type = "widevine"
        licenseServer = ""
        if stream.data.drm_details <> invalid and stream.data.drm_details.server_url <> invalid
            licenseServer = stream.data.drm_details.server_url
        end if
        if licenseServer <> ""
            drm = {
                keySystem: "Widevine"
                licenseServerURL: licenseServer
            }
            content.drmParams = drm
        end if
    end if

    return content
end function



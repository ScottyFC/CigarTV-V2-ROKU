' Builds the live stream URL with ad macros populated from Roku device info.
' Some macros (schain, pod_ad_slots, prodq, inv_partner_domain, content_dist_id, custom_7)
' are supply-chain / SSAI specific and left blank pending confirmation from Amagi/ad-ops
' on required values - passing blank is safer than guessing wrong values that silently
' hurt fill rate.
function BuildLiveStreamUrl() as String
    cfg = ApiConfig()
    di = CreateObject("roDeviceInfo")

    rida = di.GetChannelClientId()       ' device/ad ID
    isLat = "0"                          ' limit-ad-tracking; Roku doesn't expose a direct LAT flag,
                                          ' default to 0 (not limited) unless device privacy settings say otherwise
    appName = "CigarTV"
    appBundle = "com.cigartv.roku"
    ua = "Roku/" + di.GetOSVersion().major + "." + di.GetOSVersion().minor
    cb = CreateObject("roDateTime").AsSeconds().ToStr() ' cache buster

    params = {
        gdpr_consent: ""
        ic: ""
        prodq: ""
        schain: ""
        us_privacy: ""
        app_name: appName
        app_store_url: "https://channelstore.roku.com/details/cigartv"
        did: rida
        dnt: "0"
        gdpr: "0"
        is_lat: isLat
        pod_ad_slots: ""
        url: "https://cigartv.com"
        app_bundle: appBundle
        channel_name: appName
        idtype: "rida"
        ifa_type: "rida"
        inv_partner_domain: ""
        network_name: "CigarTV"
        ua: ua
        cb: cb
        content_dist_id: ""
        content_livestream: "true"
        coppa: "0"
        custom_7: ""
        ip: ""
        iu: ""
        lmt: isLat
    }

    query = ""
    for each key in params
        if query <> "" then query = query + "&"
        query = query + key + "=" + UrlEncode(params[key])
    end for

    return cfg.liveStreamUrl + "?" + query
end function

' roUrlTransfer can only be created on the Main thread or inside a Task - it's not
' available in a Scene's render-thread script, so this hand-rolls percent-encoding
' instead of relying on roUrlTransfer.Escape().
function UrlEncode(s as String) as String
    if s = invalid then return ""
    unreserved = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"
    result = ""
    for i = 0 to Len(s) - 1
        ch = Mid(s, i + 1, 1)
        if InStr(1, unreserved, ch) > 0
            result = result + ch
        else
            code = Asc(ch)
            hex = StrToHex(code)
            result = result + "%" + hex
        end if
    end for
    return result
end function

function StrToHex(n as Integer) as String
    digits = "0123456789ABCDEF"
    hi = Mid(digits, (n \ 16) + 1, 1)
    lo = Mid(digits, (n mod 16) + 1, 1)
    return hi + lo
end function

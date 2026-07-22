' PostHog analytics helper for CigarTV Roku.
' roUrlTransfer is not available on the SceneGraph render thread, so events are
' dispatched through PostHogTask (an async Task node). Callers must pass the
' scene node so the task can be created as a child.

' Returns a persistent, per-channel device identifier suitable for analytics.
' GetChannelClientId() is the Roku-recommended analytics ID and resets if the user
' opts out of ad tracking, which is the correct privacy-respecting behavior.
function PhDistinctId() as String
    di = CreateObject("roDeviceInfo")
    id = di.GetChannelClientId()
    if id = invalid or id = "" then id = "unknown"
    return "roku-" + id
end function

' Returns a base set of device/app properties attached to every event.
function PhDeviceProps() as Object
    di = CreateObject("roDeviceInfo")
    osVer = di.GetOSVersion()
    osVerStr = ""
    if osVer <> invalid
        if osVer.major <> invalid then osVerStr = Str(osVer.major).Trim()
        if osVer.minor <> invalid then osVerStr = osVerStr + "." + Str(osVer.minor).Trim()
    end if
    return {
        "$lib": "posthog-roku"
        platform: "Roku"
        app_name: "CigarTV"
        device_model: di.GetModelDisplayName()
        firmware_version: osVerStr
    }
end function

' Fires a PostHog event asynchronously. scene must be the top-level Scene node
' (m.top in MainScene) so the Task child can be created on the render thread.
' props is an optional AssocArray of additional event properties (no PII).
sub PhCapture(scene as Object, eventName as String, props as Object)
    cfg = ApiConfig()

    baseProps = PhDeviceProps()
    if props <> invalid
        for each k in props
            baseProps[k] = props[k]
        end for
    end if

    payload = {
        api_key: cfg.posthogToken
        event: eventName
        distinct_id: PhDistinctId()
        properties: baseProps
    }

    json = FormatJson(payload)
    if json = invalid or json = "" then return

    task = scene.CreateChild("PostHogTask")
    if task = invalid then return
    task.payload = json
    task.control = "RUN"
end sub

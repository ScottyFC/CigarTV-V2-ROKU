sub Init()
    m.top.functionName = "SendEvent"
end sub

' POSTs a pre-serialised JSON payload to the PostHog capture endpoint.
' Fire-and-forget: callers do not observe the result.
sub SendEvent()
    payload = m.top.payload
    if payload = "" or payload = invalid then return

    cfg = ApiConfig()
    url = cfg.posthogHost + "/capture/"

    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.InitClientCertificates()
    ut.AddHeader("Content-Type", "application/json")
    ut.AddHeader("User-Agent", "CigarTV-Roku/1.0")
    ut.PostToString(payload)
end sub

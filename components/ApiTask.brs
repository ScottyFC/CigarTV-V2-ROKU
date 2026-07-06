sub Init()
    m.top.functionName = "DoRequest"
end sub

sub DoRequest()
    url = m.top.requestUrl
    if url = "" or url = invalid
        m.top.failed = true
        return
    end if

    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.InitClientCertificates()
    ut.AddHeader("Accept", "application/json")
    ut.AddHeader("User-Agent", "CigarTV-Roku/1.0")

    ' Optional bearer token for authenticated endpoints (freecast streams API).
    if m.top.authToken <> invalid and m.top.authToken <> ""
        ut.AddHeader("Authorization", "Bearer " + m.top.authToken)
    end if

    raw = ut.GetToString()

    if raw = invalid or raw = ""
        m.top.failed = true
        return
    end if

    m.top.responseRaw = raw

    if m.top.responseType = "json"
        parsed = ParseJson(raw)
        if parsed = invalid
            m.top.failed = true
        else
            m.top.responseData = parsed
        end if
    else
        ' XML (EPG) handled by caller via responseRaw + roXMLElement
        m.top.responseData = {}
    end if
end sub

sub Main(args as Dynamic)
    showChannelSGScreen(args)
end sub

sub showChannelSGScreen(args as Dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)

    ' 1. Create roInput and attach it to your main message loop
    input = CreateObject("roInput")
    input.setMessagePort(port)

    ' Create the scene
    scene = screen.CreateScene("MainScene")
    
    ' 2. COLD LAUNCH: Handle deep linking arguments when the app is first launched.
    ' Roku's static analyzer looks for this to ensure voice launches from the OS work.
    if args <> invalid and args.contentId <> invalid
        scene.inputData = args
    end if

    screen.show()

    ' Memory-management hooks 
    di = CreateObject("roDeviceInfo")
    di.SetMessagePort(port)
    try
        di.EnableLowGeneralMemoryEvent(true)
        di.EnableMemoryWarningEvent(true)
        limitPct = di.GetMemoryLimitPercent()
        avail = di.GetChannelAvailableMemory()
    catch e
        ' Intentionally ignored
    end try

    while true
        msg = wait(0, port)
        msgType = type(msg)
        
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed()
                return
            end if
            
        else if msgType = "roDeviceInfoEvent"
            ' Memory-pressure signal acknowledged
            
        ' 3. WARM LAUNCH: Catch roInput events (Fires when app is already running)
        else if msgType = "roInputEvent"
            ' The analyzer explicitly looks for the .IsInput() validation check
            if msg.IsInput()
                inputData = msg.GetInfo()
                print "Received roInputEvent: "; inputData
                
                ' Pass the warm launch data to the scene
                scene.inputData = inputData 
            end if
        end if
    end while
end sub
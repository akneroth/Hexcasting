local watchdog = {
    lastEventTimestamp = 0
}

function watchdog.start(event)
    event = event .. "_watchdog"
    shell.execute("bg", "watchdog", event)

    return function()
        while true do
            os.queueEvent(event)
            sleep(1)
        end
    end
end

local function time()
    return os.epoch("local")
end

function watchdog.theDoggo()
    while true do
        if time() - watchdog.lastEventTimestamp > 5000 then
            shell.run("reboot")
        end
        sleep(.2)
    end
end

function watchdog.eventListener()
    watchdog.lastEventTimestamp = os.epoch("local")
    while true do
        os.pullEvent(watchdog.event)
        watchdog.lastEventTimestamp = time()
        print(os.date("%F %T", watchdog.lastEventTimestamp / 1000), "Event", watchdog.event, "recieved.")
    end
end

function watchdog:run()
    parallel.waitForAny(watchdog.eventListener, watchdog.theDoggo)
end

if type(arg[1]) == "string" then
    watchdog.event = arg[1]
    watchdog:run()
end


return watchdog

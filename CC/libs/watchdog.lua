local watchdog = {
    lastEventTimestamp = 0
}

if type(arg[1]) == "string" then
    watchdog.event = arg[1]
    watchdog:run()
end

function watchdog.start(watchdog_path, event)
    event = event.."_watchdog"
    shell.execute("bg", watchdog_path, event)

    return function ()
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
    end
end

function watchdog.eventListener()
    watchdog.lastEventTimestamp = os.epoch("local")
    while true do
        os.pullEvent(watchdog.event)
        watchdog.lastEventTimestamp = time()
    end
end

function watchdog:run()
    parallel.waitForAny(watchdog.eventListener, watchdog.theDoggo)
end




return watchdog
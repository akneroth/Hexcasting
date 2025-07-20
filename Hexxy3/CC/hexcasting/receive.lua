local monitor = peripheral.find("monitor")
local modem = peripheral.find("modem")
if modem then
    rednet.open(peripheral.getName(modem))
end
if monitor then
    monitor.setTextScale(.5)
    term.redirect(monitor)
end
while true do
    if rednet.isOpen() and monitor then
        local id, text = rednet.receive("akashachatcastinglist")
        monitor.clear()
        print("AKASHA CHAT CASTING AND CAD BY Viz AND JustASnowflake")
        print("KEEP IN MIND, ALL OF THESE CHAT CASTING HEXES ARE SUBJECT TO CHANGE WITHOUT MUCH NOTICE")
        print(text)
    else 
        sleep(5)
    end
end

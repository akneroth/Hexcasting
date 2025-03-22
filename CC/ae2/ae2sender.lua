local terminal = peripheral.find("fulleng:crafting_terminal")
local modem = peripheral.find("modem")
local protocol


local programName = fs.getName(shell.getRunningProgram())
if #arg < 1 then
    print("Usage: " .. programName .. " <protocol_family>")
    return
else
    protocol = arg[1].."_items"
end





-- INIT

rednet.open(peripheral.getName(modem))

if not rednet.isOpen() then
    print("Rednet connection is not open. Please check if wireless modem is attached to the computer")
    print("Terminating...")
    return
else
    print("Rednet connection is open")
    print("-- Sending to protocol:"..protocol)
end

if terminal == nil then
    print("No AE2 terminal attached. Please attach AE2 Fullblock Crafting terminal.")
    return
else
    print("Terminal attached...")
end


local function getDataAsLines()
    local out = {}
    for key, value in pairs(terminal.items()) do
        table.insert(out, value.displayName .. ": " .. value.count )
    end
    return out
end

while true do
    local lines = getDataAsLines()
    local data ={
        header = "AE2 Items",
        headerSize = 2,
        lines = lines
    }
    data = textutils.serialiseJSON(data)
    local computers = {rednet.lookup(protocol)}
    for _, id in pairs(computers) do
        rednet.send(id, data, protocol)
    end
    print("Data sent to", #computers, "computers, data:", lines)
end
local add, remove = false, false
local gateName

local port = peripheral.find("focal_port")

if #arg == 0 then
    print("Usage: gateManager add/remove <gate name>")
end

if arg[1] ~= nil then
    if arg[1] == "add" then add = true end
    if arg[1] == "remove" then remove = true end
end

if type(arg[2]) == "string" then
    gateName = arg[2]
end




local path = fs.getDir(shell.getRunningProgram())
local file = path .. "gates.txt"
if not fs.exists(file) then
    local f = fs.open(file, "w")
    f.close()
end


local function addGate(name, id)
    local f = fs.open(file, "a")
    f.writeLine(name .. ";" .. id)
    f.close()
end

local function removeGate(name)
    print("TBD")
end

local gateId = port.readIota()
if gateId ~= nil then
    gateId = gateId.gate
    if add then
        addGate(gateName, gateId)
    else
        if remove then
            removeGate(gateName)
        end
    end
end

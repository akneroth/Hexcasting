local add, remove, overwrite = false, false, false
local gateName

local port = peripheral.find("focal_port")

if #arg == 0 then
    print("Usage: gateManager add/remove <gate name> [overwrite]")
end

if type(arg[1]) == "string" then
    if arg[1] == "add" then add = true end
    if arg[1] == "remove" then remove = true end
end

if type(arg[2]) == "string" then
    gateName = arg[2]
end

if type(arg[3]) == "string" then
    local vals = {
        ["true"] = true,
        ["false"] = false,
    }
    overwrite = vals[arg[3]]
end

local path = fs.getDir(shell.getRunningProgram())
local file = path .. "/gates.json"
local gates = {}

if not fs.exists(file) then
    local f = fs.open(file, "w")
    f.close()
else
    local f = fs.open(file, "r")
    gates = textutils.unserialiseJSON(f.readAll())
    f.close()
end

local gateId = port.readIota()

if gateId ~= nil then
    gateId = gateId.gate
    if overwrite and add then
        for key, value in pairs(gates) do
            if value.name == gateName then
                gates[key] = {
                    name = gateName,
                    id = gateId
                }
            end
        end
    else
        table.insert(gates, {name = gateName, id = gateId})
    end

    if remove then
        for key, value in pairs(gates) do
            if value.name == gateName then
                gates[key] = nil
            end
        end
    end

    local f = fs.open(file, "w")
    f.write(textutils.serialiseJSON(gates))
    f.close()
end

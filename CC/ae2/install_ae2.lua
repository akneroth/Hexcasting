local args = {...}
local branch
if not args[1] then
    branch = "master"
elseif args[1] == "master" or args[1] == "dev" then
    branch = args[1]
elseif args[1] == "reinstall" then
    fs.delete("/install_ae2.lua")
    shell.run("wget https://raw.githubusercontent.com/akneroth/Hexcasting/refs/heads/master/CC/ae2/install_ae2.lua /install_ae2.lua")
    shell.run("/install_ae2.lua")
    shell.exit()
else
    print("Usage: install_hexlator [main|dev|reinstall] [install path] [install symbols path]")
    shell.exit()
end
local raw_url = "https://raw.githubusercontent.com/akneroth/HexLator/"..branch.."/"

local install_path
if not args[2] then
    install_path = "/programfiles/ae2/"
else
    install_path = args[2].."/ae2/"
end

local install_path_symbol
if not args[3] or args[3] == false then
    install_path_symbol = install_path
else
    install_path_symbol = "/programfiles/ae2/"
end

shell.execute("delete", install_path)
shell.execute("delete", install_path_symbol)

shell.execute("wget", raw_url.."hexlator.lua", install_path.."hexlator.lua")
shell.execute("wget", raw_url.."hexget.lua", install_path.."hexget.lua")
shell.execute("wget", raw_url.."symbol-registry.json", install_path_symbol.."symbol-registry.json")
shell.execute("wget", raw_url.."hexxyedit.lua", install_path.."hexxyedit.lua")
shell.execute("wget", raw_url.."github.lua", install_path.."github.lua")
shell.execute("wget", raw_url.."base64.lua", install_path.."base64.lua")
shell.execute("wget", raw_url.."json.lua", install_path.."json.lua")
shell.execute("wget", raw_url.."hexicon.json", install_path.."hexicon.json")

local function updateValues(new_table, old_table)
    for k, v in pairs(old_table) do
        if type(v) == "table" then
            new_table[k] = updateValues(new_table[k], v)
        else
            new_table[k] = v
        end
    end
    return new_table
end

if not fs.exists("/.config/hexlator.json") then
    shell.execute("wget", raw_url.."config.json", "/.config/hexlator.json")
else
    local file = fs.open("/.config/hexlator.json", "r")
    local old_config = textutils.unserialiseJSON(file.readAll())
    file.close()

    fs.delete("/.config/hexlator.json")
    shell.execute("wget", raw_url.."config.json", "/.config/hexlator.json")

    local new_file = fs.open("/.config/hexlator.json", "r")
    local new_config = textutils.unserialiseJSON(new_file.readAll())
    new_file.close()

    local final_config = updateValues(new_config, old_config)

    local final_file = fs.open("/.config/hexlator.json", "w")
    final_file.write(textutils.serialiseJSON(final_config))
    final_file.close()
end

local startup = fs.open("startup.lua", "w")
startup.write([[
local folder = ".startup"
if not fs.exists(folder) then
    fs.makeDir(folder)
else
    local files = fs.list(folder)
    for _, file in ipairs(files) do
        if string.sub(file, -4) == ".lua" then
            shell.run(folder .. "/" .. file)
        end
    end
end
]])
startup.close()

local file = fs.open("/.startup/hexlator.lua","w")
file.write(string.format('shell.setAlias("hexget", "%shexget.lua") shell.setAlias("hexxyedit", "%shexxyedit.lua") shell.setAlias("github", "%sgithub.lua")',install_path, install_path, install_path))
file.close()
os.reboot()

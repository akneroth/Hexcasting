local expect = require "cc.expect"
local args = {...}

local ts = 1234455

local function getGitPath(branch)
    expect(1, branch, "string", "nil")
    if not branch or branch == "master" then branch = "master" end
    if branch == "dev" then branch = "dev" end
    return "https://raw.githubusercontent.com/akneroth/Hexcasting/"..branch.."/CC/"
end

local branch, reinstall = nil, false
for _, value in ipairs(args) do
    if value == "master" or value == "dev" then branch = value end
    if value == "reinstall" then reinstall = true end
    if value == "help" or value == "?" then
        -- print("Usage: install_ae2 [main|dev|reinstall] [install path] [install symbols path]")
        print("Usage: install_ae2 [main|dev] [reinstall]")
        shell.exit()
    end
end

if reinstall then
    fs.delete("/install_ae2.lua")
    shell.execute("wget", getGitPath(branch).."ae2/install_ae2.lua", "/install_ae2.lua")
    shell.run("/install_ae2.lua")
    shell.exit()
end

local raw_url = getGitPath(branch)
local install_path = "/programfiles/ae2/"
local lib_path = install_path.."libs/"

shell.execute("delete", install_path)

shell.execute("wget", "https://raw.githubusercontent.com/Vizoee/HexLator/main/github.lua", lib_path.."ae2crafting.lua")
shell.execute("wget", "https://raw.githubusercontent.com/Vizoee/HexLator/main/base64.lua", lib_path.."ae2crafting.lua")


shell.execute("wget", raw_url.."ae2/ae2manager.lua", install_path.."ae2manager.lua")
shell.execute("wget", raw_url.."ae2/ae2crafting.lua", lib_path.."ae2crafting.lua")
shell.execute("wget", raw_url.."ae2/ae2items.lua", lib_path.."ae2items.lua")
shell.execute("wget", raw_url.."libs/ae2base.lua", lib_path.."ae2base.lua")
shell.execute("wget", raw_url.."libs/base.lua", lib_path.."base.lua")
shell.execute("wget", raw_url.."libs/basalt.lua", lib_path.."basalt.lua")

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

local file = fs.open("/.startup/ae2.lua","w")
file.write(string.format('shell.setAlias("ae2manager", "%sae2manager.lua") shell.run("ae2manager")', install_path))
file.close()
if not fs.exists(".config") then fs.makeDir(".config") end
file = fs.open("/.config/ae2.json","w")
file.write(string.format([[
{
    "install_path": "%s",
    "lib_path": "%s"
}
]], install_path, lib_path))
file.close()
os.reboot()
local expect = require "cc.expect"
local downloader = {
    author = nil,
    repository = nil,
    commitSha = nil,
    branch = nil,
    files = {},
    baseApiUrl = "https://api.github.com/repos",
    baseRawUrl = "https://raw.githubusercontent.com",
}

local function httpGet(url)
    local response, errorMessage, errorResponse = http.get(url)
    if response then
        return textutils.unserializeJSON(response.readAll())
    else
        printError(errorMessage)
        if errorResponse then
            return nil, textutils.unserializeJSON(errorResponse.readAll())
        end
        return nil
    end
end

local function buildApiUrl(...)
    local urlParts = { downloader.baseApiUrl, downloader.author, downloader.repository }
    for index, value in ipairs(table.pack(...)) do table.insert(urlParts, value) end
    return table.concat(urlParts, "/")
end

local function buildRawUrl(...)
    local urlParts = { downloader.baseRawUrl, downloader.author, downloader.repository, downloader.commitSha }
    for index, value in ipairs(table.pack(...)) do table.insert(urlParts, value) end
    return table.concat(urlParts, "/")
end

local function getDefaultBranch()
    local response = httpGet(buildApiUrl())
    downloader.branch = response.default_branch
end

local function getLatestCommitSha()
    local response, errorResponse = httpGet(downloader:buildApiUrl("branches"))
    if response then
        for key, value in pairs(response) do
            if value.name == downloader.branch then
                return value.commit.sha
            end
        end
        printError("No branch with provided name")
        return nil
    end
    return nil, errorResponse
end

local function download(file, name)
    shell.execute("wget", buildRawUrl(file), name)
end

local function isValid()
    if not downloader.author then
        printError("No author provided")
        return false
    end
    if not downloader.repository then
        printError("No repository provided")
        return false
    end
    return true
end





--==================================================================================
--===============================      Downloader    ===============================
--==================================================================================

function downloader.workingDir() return shell.dir() end

function downloader.programDir() return fs.getDir(shell.getRunningProgram()) end

function downloader:download(author, repository, branch, files, env)
    self.author = type(author) == "string" and author or nil
    self.repository = type(repository) == "string" and repository or nil
    self.branch = type(branch) == "string" and branch or nil

    if not isValid() then
        printError("Author or repository is not valid")
        return
    end
    if not self.branch then self.branch = getDefaultBranch() end
    local commitSha = getLatestCommitSha()
    if commitSha then self.commitSha = commitSha else return end

    for dest, repoPath in pairs(files) do
        download(repoPath, dest)
        if fs.exists(dest) then
            local f = fs.open(dest, "w+")
            local content = f.readAll()
            for envvar, value in pairs(env) do
                string.gsub(content, "%[%["..envvar.."%]%]", value)
            end
            f.write(content)
            f.close()
        end
    end
end


return downloader
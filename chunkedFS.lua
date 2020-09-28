local cbor = require "cbor"

local config = {
    filePath = "chunked.fs";
    chunkSize = 1000
}

local fileSystemFile = fs.open(config.filePath, "rb")


local function cleanPath(path)
    return fs.combine(path, "")
end

local function getDirectoryInfo(path)
    path = cleanPath(path)
    local chunk
    if path == "" then
        chunk = 0
    else
        local pathDir, pathName = fs.getDir(path), fs.getName(path)
        local parentDirectoryInfo = getDirectoryInfo(pathDir)
        if not parentDirectoryInfo[pathName] then
            return nil
        end
        chunk = parentDirectoryInfo[pathName].chunk
    end
    local chunk = fileSystemFile.seek("set", config.chunkSize * chunk)

end










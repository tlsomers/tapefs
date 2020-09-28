
local chunk_size = 1024

function tapeReader(tape, pos, bufferSize)

    local inChunkIndex = 1
    local chunkIndex = 0
    local chunkString
    
    local r = {}

    function loadChunk()
        tape.seek(pos + chunkIndex * bufferSize - tape.getPosition())
        chunkString = tape.read(bufferSize)
    end

    
    function r.nextByte()
        if inChunkIndex <= bufferSize then
            local res = string.byte(chunkString, inChunkIndex)
            inChunkIndex = inChunkIndex + 1
            return res
        else
            chunkIndex = chunkIndex + 1
            inChunkIndex = 1
            loadChunk()
            return string.byte(chunkString)
        end
    end

    function r.uint8()
        return r.nextByte()
    end

    function r.uint16()
        local a = r.nextByte()
        local b = r.nextByte()
        return a * 2^8 + b
    end

    function r.uint32()
        local a = r.nextByte()
        local b = r.nextByte()
        local c = r.nextByte()
        local d = r.nextByte()
        return a * 2 ^ 24 + b * 2 ^ 16 + c * 2 ^ 8 + d
    end

    loadChunk()
    return r
end

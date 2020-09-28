
function wrap(tape)
    if tape.wrapped then return tape end

    local t = {wrapped = true}

    function t.getPosition()
        return tape.getPosition()
    end

    function t.getSize()
        return tape.getSize()
    end

    function t.write(str)
        if type(str) == "number" then
            return tape.write(str)
        else
            local written = tape.write(str)
            if written < #str then
                written = written + 1
                tape.write(string.byte(str, written))
            end
            return written
        end
    end

    function t.read(count)
        if count ~= nil and count > 256 then
            return t.read(256) .. t.read(count - 256)
        end
        if tape.getPosition() == tape.getSize() then
            return ""
        elseif count == nil then
            return tape.read()
        else
            local s = tape.read(math.min(count, tape.getSize() - 1 - tape.getPosition()))
            if #s < count and tape.getPosition() < tape.getSize() then
                s = s .. string.char(tape.read())
            end
            return s
        end
    end

    t.seek = tape.seek

    return t
end

function combine(...)
    local tapes = {...}
    local current = 1

    for i=1, #tapes do
        local tape = wrap(tapes[i])
        tapes[i] = tape
        tape.seek(-tape.getPosition())
    end

    local t = {}

    function t.seek(n)
        if n > 0 then
            local n2 = tapes[current].seek(n)
            if n == n2 or current == #tapes then
                return n2
            else
                current = current + 1
                return n2 + 1 + t.seek(n - n2 - 1)
            end
        elseif n < 0 then
            local n2 = tapes[current].seek(n)
            if n == n2 or current == 1 then
                return n2
            else
                current = current - 1
                local seekVal = n - n2 + 1
                if tapes[current].getPosition() == tapes[current].getSize() then
                    seekVal = seekVal - 1
                end
                return n2 - 1 + t.seek(seekVal)
            end
        else
            return 0
        end
    end

    function t.getSize()
        local cum = 0
        for _, tape in pairs(tapes) do
            cum = cum + tape.getSize()
        end
        return cum
    end

    function t.getPosition()
        local cum = 0
        for i, tape in pairs(tapes) do
            if i == current then
                return cum + tape.getPosition()
            end
            cum = cum + tape.getSize()
        end
    end

    function t.write(str)
        if type(str) == "number" then
            return t.write(string.char(str))
        end

        local n = tapes[current].write(str)
        if n == #str or current == #tapes then
            return n
        else
            current = current + 1
            return n + t.write(str:sub(n+1))
        end
    end

    function t.read(n)
        if n == nil then
            local cur = tapes[current].read()
            if cur == "" and current == #tapes then
                return nil
            elseif cur == "" then
                current = current + 1
                return tapes[current].read()
            else
                return cur
            end
        else
            local n1 = math.min(n, tapes[current].getSize() - tapes[current].getPosition())

            local s1 = tapes[current].read(n1)
            if n1 == n or current == #tapes then
                return s1
            else
                current = current + 1
                return s1 .. t.read(n - n1)
            end
        end
    end

    return t
end

local function tuple(a, b)
    return function(n, v)
        if n == 1 then
            if v ~= nil then
                a = v
            else
                return a
            end
        else
            if v ~= nil then
                b = v
            else
                return b
            end
        end
    end
end

-- Create a tape that can read/write to the given encrypted tape
-- Chunk size chunks are encrypted and decrypted (enc and dec must map from chunk_size to chunk_size)
function encrypted(tape, encrypter)
    tape = wrap(tape)
    local chunk_size, enc, dec = encrypter.chunk_size, enc, dec

    local chunkCount = math.floor(tape.getSize() / chunk_size)
    local chunkList = {}

    local pos = tape.getPosition()

    function getChunkAndPos(n)
        return math.floor(n / chunk_size), n % chunk_size
    end

    function getChunk(chunkId)
        local tup
        local i = 1
        while i <= #chunkList and tup == nil do
            local v = chunkList[i]
            if v(1) == chunkId then tup = v end
            i = i + 1
        end
        if tup == nil then
            tape.seek(chunkId * chunk_size - tape.getPosition())
            local encText = tape.read(chunk_size)
            tup = tuple(chunkId, dec(encText))
            chunkList[#chunkList+1] = tup
        end
        return tup(2)
    end

    function setChunk(chunkId, str)
        local tup
        local i = 1
        while i <= #chunkList and tup == nil do
            local v = chunkList[i]
            if v(1) == chunkId then tup = v end
            i = i + 1
        end
        if tup == nil then
            tup = tuple(chunkId, false)
            chunkList[#chunkList+1] = tup
        elseif tup(2) ~= str then
            tup(2, str)
            tape.seek(chunkId * chunk_size - tape.getPosition())
            tape.write(enc(str))
        end
    end

    local t = {}
    function t.getSize()
        return chunkCount * chunk_size
    end

    function t.getPosition()
        return pos
    end

    function t.seek(n)
        local old = pos
        pos = math.min(math.max(0, pos + n), chunkCount * chunk_size)
        return pos - old
    end

    function t.write(str)
        if type(str) == "number" then
            return t.write(string.char(str))
        else

        end
    end

    function t.read(n)
        if n == nil then
            local str = t.read(1)
            if str == "" then
                return nil
            else
                return string.byte(str)
            end
        else
            local chunk, chunkpos = getChunkAndPos(pos)
            if chunk >= chunkCount then
                return ""
            else
                local n2 = math.min(n, chunk_size - chunkpos + 1)
                local left = getChunk(chunk):sub(chunkpos + 1, chunkpos + n2)
                pos = pos + n2
                if n2 == n then
                    return left
                else
                    local right = t.read(n - n2)
                    return left .. right
                end
            end
        end
    end

    function t.write(str)
        if type(str) == "number" then
            return t.write(string.char(str))
        end

        local chunkId, chunkpos = getChunkAndPos(pos)
        if chunkId >= chunkCount then
            return 0
        end

        local n = #str
        local n2 = math.min(n, chunk_size - chunkpos + 1)
        local chunk = getChunk(chunkId)

        setChunk(chunkId, chunk:sub(1, chunkpos) .. str:sub(1, n2) .. chunk:sub(chunkpos + n2 + 1))
        pos = pos + n2
        if n == n2 then
            return n
        else
            local rightNum = t.write(str:sub(n2+1))
            return n2 + rightNum
        end
    end

    return t
end


local encrypter = {}
function encrypter.aes(aes, key, chunk_size)

    function enc(data)
        return aes.encrypt(key, data, nil, nil, nil, true)
    end

    function dec(data)
        return aes.decrypt(key, data, nil, nil, nil, true)
    end
    return {enc = enc; dec = dec; chunk_size = chunk_size or 128}
end

function serializeUtils(tape)

    tape = wrap(tape)

    function tape.uint8()
        return tape.read()
    end

    function tape.uint16()
        local a = tape.read()
        local b = tape.read()
        return a * 2^8 + b
    end

    function tape.uint32()
        local a = tape.read()
        local b = tape.read()
        local c = tape.read()
        local d = tape.read()
        return a*2^24 + b*2^16 + c*2^8 + d
    end

    function tape.string8()
        local len = tape.uint8()
        return tape.read(len)
    end

    function tape.writeUint8(n)
        n = n % 256
        return tape.write(n)
    end

    function tape.writeUint16(n)
        local a,b
        b, n = n % 256, math.floor(n / 256)
        a = n % 256
        tape.write(a)
        tape.write(b)
    end

    function tape.writeUint32(n)
        local a,b,c,d
        d, n = n % 256, math.floor(n / 256)
        c, n = n % 256, math.floor(n / 256)
        b, n = n % 256, math.floor(n / 256)
        a = n % 256
        tape.write(a)
        tape.write(b)
        tape.write(c)
        tape.write(d)
    end

    function tape.writeString8(str)
        tape.writeUint8(#str)
        tape.write(str)
    end

    function tape.setPosition(p)
        return tape.seek(p - tape.getPosition())
    end

    function tape.clear(tape)
        tape.seek(-math.huge)
        local rem = tape.getSize()
        local str = ("\000"):rep(256)
        while rem > 0 do
            tape.write(str)
            rem = rem - 256
        end
        tape.seek(-math.huge)
    end

    return tape
end

return {
    combine = combine;
    wrap = wrap;
    encrypted = encrypted;
    encrypter = encrypter;
    serializeUtils = serializeUtils;
}

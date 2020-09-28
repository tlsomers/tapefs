
function getBit(arr, bitIndex)
    local char = 1 + math.floor((bitIndex - 1) / 8)
    local ind = 1 + (bitIndex - 1) % 8
    local num = string.byte(arr, char)
    return (num / (2^(ind - 1))) % 2 == 1
end

function setBit(arr, bitIndex, val)
    local char = 1 + math.floor((bitIndex - 1) / 8)
    local ind = 1 + (bitIndex - 1) % 8
    local num = string.byte(arr, char)

    if val then
        num = bit.bor(bit.blshift(1,ind - 1), num)
    else
        num = bit.band(bit.bnot(bit.blshift(1, ind - 1), num))
    end

    return arr:sub(1, char-1) .. string.char(num)..arr:sub(char + 1)
end


function find1(arr)
    local s = arr:find("[^\000]")
    if s then
        local num = string.byte(arr, s)
        local i = 1
        while num % 2 == 0 do
            i = i + 1
            num = num / 2
        end
        return 8*(s-1) + i
    end
    return nil
end

function find0(arr)
    local s = arr:find("[^\255]")
    if s then
        local num = string.byte(arr, s)
        local i = 1
        while num % 2 == 1 do
            i = i + 1
            num = (num - 1) / 2
        end
        return 8*(s-1) + i
    end
    return nil
end

function findBit(arr, val)
    if val then
        return find1(arr)
    else
        return find0(arr)
    end
end

local meta = {}
function meta:getBit(i)
    return getBit(self.value, i)
end
function meta:setBit(i, v)
    self.value = setBit(self.value, i, v)
    return self
end
function meta:findBit(v)
    return findBit(self.value, v)
end


function ofString(val)
    return setmetatable({value = val}, {__index = meta})
end

function toString(arr)
    return arr.value
end

function create(size)
    return ofString(("\000"):rep(math.ceil(size / 8)))
end

return {
    getBit = getBit;
    setBit = setBit;
    findBit = findBit;
    create = create;
    ofString = ofString;
    toString = toString;
}

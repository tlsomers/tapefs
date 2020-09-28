
-- Just a tuple :)
local function tup(a, b)
  return function(i)
    if i == 1 then return a else return b end
  end
end

local function fst(tup)
  return tup(1)
end

local function snd(tup)
  return tup(2)
end

-- Actual stuff

local function ofRW(read, write)
  return tup(read, write)
end

local function field(name, rw)
  return tup(name, rw)
end

local function read(tape, structure)
  if type(structure) == "table" then
    local res = {}
    for i=1, #structure do
      s2 = structure[i]
      res[fst(s2)] = read(tape, snd(s2))
    end
    return res
  else
    return fst(structure)(tape)
  end
end

local function write(tape, structure, value)
  if type(structure) == "table" then
    for i=1, #structure do
      s2 = structure[i]
      write(tape, snd(s2), value[fst(s2)])
    end
  else
    snd(structure)(tape, value)
  end
end

local bserial = {
  read = read;
  write = write;
  ofRW = ofRW;
  field = field;
}

bserial.uint8 = ofRW(function(tape) return tape.uint8() end, function(tape, value) return tape.writeUint8(value) end)
bserial.uint16 = ofRW(function(tape) return tape.uint16() end, function(tape, value) return tape.writeUint16(value) end)
bserial.uint32 = ofRW(function(tape) return tape.uint32() end, function(tape, value) return tape.writeUint32(value) end)

bserial.string8 = ofRW(function(tape) return tape.string8() end, function(tape, value) return tape.writeString8(value) end)
function bserial.byteN(n)
  return ofRW(
    function(tape)
      return tape.read(n)
    end,
    function(tape, value)
      local v2 = value:sub(1, n) .. string.rep("\000", math.max(n - #value, 0))
      tape.write(v2)
    end)
end

function bserial.map(inner, mapr, mapw)
  return bserial.ofRW(function(tape)
    return mapr(read(tape, inner))
  end,
  function(tape, value)
    return write(tape, inner, mapw(value))
  end)
end

function bserial.rep(inner, n)
  return bserial.ofRW(function(tape)
    local v = {}
    for i=1, n do
      v[i] = read(tape, inner)
    end
    return v
  end,
  function(tape, value)
    for i=1, n do
      write(tape, inner, value[i])
    end
  end)
end

return bserial

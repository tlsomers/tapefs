
local DEFAULT_BLOCK_SIZE = 1024
local INODE_SIZE = 64

local bitarray = require "bitarray"
local tu = require "tapeutils"
local bs = require "bserial"

local superBlockStructure = {
  bs.field("magic", bs.uint16),
  bs.field("blockSize", bs.uint32),
  bs.field("inodes", bs.uint32),
  bs.field("blocks", bs.uint32),
  bs.field("freeInodes", bs.uint32),
  bs.field("freeBlocks", bs.uint32)
}

local inodeStructure = {
  bs.field("mode", bs.uint16),
  bs.field("owner", bs.uint16),
  bs.field("size", bs.uint32),
  bs.field("direct", bs.rep(bs.uint32, (INODE_SIZE / 4) - 5)),
  bs.field("indirect", bs.uint32),
  bs.field("indirect2", bs.uint32)
}

local bitmapStructure = bs.map(bs.byteN(DEFAULT_BLOCK_SIZE), bitarray.ofString, bitarray.toString)

function readSuperBlock(tape)
    tape.setPosition(0)

    local superBlock = bs.read(tape, superBlockStructure)

    if superBlock.magic ~= 0xEF54 then
        error("Tape has incorrect magic")
    end

    return superBlock
end

function writeSuperBlock(tape, superBlock)
    tape.setPosition(0)

    bs.write(tape, superBlockStructure, superBlock)
end

function readINode(tape, superBlock, index)
    local start = superBlock.blockSize * 4 + (index - 1) * INODE_SIZE
    tape.setPosition(start)

    return bs.read(tape, inodeStructure)
end

function writeINode(tape, superBlock, inode)
    local start = superBlock.blockSize * 4 + (inode.index - 1) * INODE_SIZE
    tape.setPosition(start)

    return bs.write(tape, inodeStructure, inode)
end

function readBitMap(tape, superBlock, block)
  tape.setPosition(superBlock.blockSize * (block - 1))
  return bs.read(tape, bitmapStructure)
end

function writeBitMap(tape, superBlock, block, bitmap)
  tape.setPosition(superBlock.blockSize * (block - 1))
  return bs.write(tape, bitmapStructure, bitmap)
end

function reserveBlock(tape, superBlock)
  if superBlock.freeBlocks <= 0 then
    error("No more free blocks")
  end

  local freeBlock
  for i=1, 2 do
    local bm = readBitMap(tape, superBlock, i+2)
    local n = bm.findBit(false)
    if n then
      freeBlock = superBlock.blockSize * 8 * (i-1) + n
      bm.setBit(n, true)
      writeBitMap(tape, superBlock, i+2, bm)
    end
  end
  if not freeBlock or freeBlock > superBlock.blocks then
    error("No free block")
  end
  superBlock.freeInodes = superBlock.freeInodes - 1
  return freeBlock
end

function freeBlock(tape, superBlock, index)
  local bitBlock = 1
  while index > superBlock.blockSize * 8 do
    bitBlock = bitBlock + 1
    index = index - superBlock.blockSize * 8
  end
  local bm = readBitMap(tape, superBlock, bitBlock+2)
  if not bm.getBit(index) then
    error("Cannot free free block")
  end

  bm.setBit(index, false)
  writeBitMap(tape, superBlock, bitBlock + 2, bm)

  superBlock.freeBlocks = superBlock.freeBlocks - 1
end



function createINode(tape, superBlock, owner, mode)
    if superBlock.freeInodes <= 0 then
      error("No more space")
    end

    local inodeMap = readBitMap(tape, superBlock, 2)
    local freeBit = inodeMap.findBit(false)
    writeBitMap(tape, superBlock, 2, inodeMap.setBit(freeBit, true))

    superBlock.freeInodes = superBlock.freeInodes - 1
    return {
        index = freeBit;
        mode = mode;
        owner = owner;
        size = 0;
        direct = {};
        indirect = 0;
        indirect2 = 0;
    }
end

function freeINode(tape, superBlock, inode)
    tape.seek(superBlock.blockSize - tape.getPosition())
    local inodeMap = tape.read(superBlock.blockSize)
    tape.seek(superBlock.blockSize - tape.getPosition())
    tape.write(bitarray.setBit(inodeMap, inode.index, false))
    superBlock.freeInodes = superBlock.freeInodes + 1
end


function createSuperBlock(tape, blockSize)
    blockSize = blockSize or DEFAULT_BLOCK_SIZE
    local blockCount = math.floor(tape.getSize() / blockSize) - 4
    local inodeBlocks = math.floor(blockCount / (3 * (blockSize / INODE_SIZE)))

    local superBlock = {magic = 0xEF54}
    superBlock.blockSize = blockSize
    superBlock.inodes = inodeBlocks * (blockSize / INODE_SIZE)
    superBlock.blocks = blockCount - inodeBlocks
    superBlock.freeInodes = superBlock.inodes
    superBlock.freeBlocks = superBlock.blocks

    return superBlock
end

function createTapeFs(tape, blockSize)
  local sb = createSuperBlock(tape, blockSize)
  tape.clear()
  writeSuperBlock(tape, sb)
  emptyBitMap = bitarray.ofString(("\000"):rep(sb.blockSize))
  writeBitMap(tape, sb, 2, emptyBitMap)
  writeBitMap(tape, sb, 3, emptyBitMap)
  writeBitMap(tape, sb, 4, emptyBitMap)

  return sb
end

function findTape()
    return tu.serializeUtils(peripheral.find("tape_drive"))
end

return {
    createSuperBlock = createSuperBlock;
    readSuperBlock = readSuperBlock;
    writeSuperBlock = writeSuperBlock;
    readINode = readINode;
    writeINode = writeINode;
    createINode = makeINode;
    clearINode = clearINode;
    tape = findTape;
    reserveBlock = reserveBlock;
    clearBlock = clearBlock;
    createTapeFs = createTapeFs;
}

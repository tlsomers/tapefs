function make(tape)

    -- Reset to 0 pos
    tape.seek(-tape.getSize())
    local io = {pos = 0}

    function io.seek(n)
        local shift = tape.seek(n)
        io.pos = io.pos + shift
        return shift
    end

    function io.pos(newPos)
        io.seek(newPos - io.pos)
        return io.pos
    end

    function io.read(n)
        if n == nil then
            io.pos = io.pos + 1
            return tape.read()
        end
        if n > 256 then
            local left = io.read(256)
            local right = io.read(n - 256)
            return left .. right
        else
            local text = tape.read(n)
            io.pos = io.pos + n
            return text
        end
    end

    


end


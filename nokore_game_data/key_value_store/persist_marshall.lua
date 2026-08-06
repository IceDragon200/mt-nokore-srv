local path_dirname = assert(foundation.com.path_dirname)
local Buffer = assert(foundation.com.BinaryBuffer or foundation.com.StringBuffer,
                      "expected some kind of buffer")

local BB_LE
if foundation.com.ByteBuf then
  BB_LE = assert(foundation.com.ByteBuf.LE)
end

local MarshallValueV1
if foundation.com.binary_types then
  MarshallValueV1 = foundation.com.binary_types.MarshallValue.V1
end

local MarshallValueV2
if foundation.com.binary_types then
  MarshallValueV2 = foundation.com.binary_types.MarshallValue.V2
end

local KVStore = nokore_game_data.KVStore
do
  local ic = KVStore.instance_class

  if BB_LE and MarshallValueV1 or MarshallValueV2 then
    local marshall_v1 = MarshallValueV1:new()
    local marshall_v2 = MarshallValueV2:new()

    function ic:marshall_dump(stream)
      local bytes_written = 0
      local bw, err

      -- Write the magic bytes
      bw, err = BB_LE:write(stream, "NKKV") -- NoKoreKeyValue
      bytes_written = bytes_written + bw
      if err then
        return bytes_written, err
      end

      -- Write the format code
      bw, err = BB_LE:write(stream, "MRSH") -- MRSH - Marshall, ASCI - ASCII Pack
      bytes_written = bytes_written + bw
      if err then
        return bytes_written, err
      end

      -- Write the endian code
      bw, err = BB_LE:write(stream, "LITE") -- LITE - little endian, BIGE - big endian
      bytes_written = bytes_written + bw
      if err then
        return bytes_written, err
      end

      bw, err = BB_LE:w_i32(stream, 2) -- Version 1
      bytes_written = bytes_written + bw
      if err then
        return bytes_written, err
      end

      bw, err = marshall_v2:write(BB_LE, stream, self.data) -- marshall dump the data
      bytes_written = bytes_written + bw
      if err then
        return bytes_written, err
      end

      bw, err = BB_LE:write(stream, "NKEE") -- NoKoreEndEnd
      bytes_written = bytes_written + bw
      if err then
        return bytes_written, err
      end

      return bytes_written, err
    end

    function ic:marshall_load(stream)
      local bytes_read = 0
      local br

      local magic
      magic, br = BB_LE:read(stream, 4)
      bytes_read = bytes_read + br

      if magic ~= "NKKV" then
        error("Cannot reload table, magic bytes do not match (expected:NKKV, got:" .. magic .. ")")
      end

      local format
      format, br = BB_LE:read(stream, 4)
      bytes_read = bytes_read + br

      if format ~= "MRSH" then
        error("Incorrect format (expected:MRSH, got:".. format .. ")")
      end

      local byte_order
      byte_order, br = BB_LE:read(stream, 4)
      bytes_read = bytes_read + br

      if byte_order ~= "LITE" then
        error("Unsupported byte order (expected:LITE, got:".. byte_order .. ")")
      end

      -- little endian encoding
      local ver
      ver, br = BB_LE:r_i32(stream)
      bytes_read = bytes_read + br

      local data
      if ver == 1 then
        data, br = marshall_v1:read(BB_LE, stream)
        bytes_read = bytes_read + br
      elseif ver == 2 then
        data, br = marshall_v2:read(BB_LE, stream)
        bytes_read = bytes_read + br
      else
        error("Unsupported version (expected 1 or 2, got ".. ver .. ")")
      end

      local tail
      tail, br = BB_LE:read(stream, 4)
      bytes_read = bytes_read + br

      assert(tail == "NKEE", "expected NKKV stream to end with NKEE")

      self.data = data
      return self, bytes_read
    end

    function ic:marshall_dump_file(filename, trace)
      --print("marshall_dump_file", filename)
      local span
      if trace then
        span = trace:span_start("mkdir")
      end
      core.mkdir(path_dirname(filename))
      if span then
        span:span_end()
      end

      local buffer = Buffer:new('', 'w')
      if trace then
        span = trace:span_start("marshall_dump")
      end
      self:marshall_dump(buffer)
      if span then
        span:span_end()
      end
      buffer:close()

      if trace then
        span = trace:span_start("safe_file_write")
      end
      core.safe_file_write(filename, buffer:blob())
      if span then
        span:span_end()
      end
      return true
    end

    function ic:marshall_load_file(filename)
      --print("marshall_load_file", filename)
      local f = io.open(filename, 'r')
      if f then
        self:marshall_load(f)
        f:close()
        return true
      end
      return false
    end
  else
    core.log("warning", "marshall functions are not available for key-value store")
  end
end

local pairs = pairs
local unpack = unpack
local math = math
local setmetatable = setmetatable
local tostring = tostring
local tonumber = tonumber
local print = print
local string = string
local bit = require("bit")
local debug = debug

module (...)

function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

function logd(...)
   -- print(...)
end

function bit_mask(msb, lsb)	
   if msb <= lsb then return end

   local t = 0xffffffff
   if msb < 31 then
      t = bit.lshift(0xffffffff, msb + 1) 
      t = bit.bnot(t)			  
   end

   local s = bit.lshift(0xffffffff, lsb) 
   return bit.band(t, s)	
end

name = "MEM"			-- example cache of 8KB
word_size = 4			-- word size in bytes
blk_size = 64			-- block size in bytes, 2^6
n_blks = 128			-- n_blks, 2^7
assoc = 4			-- assoc
-- write_back = true		-- write_back
next_level = nil

read_miss = 0
read_hit = 0
write_miss = 0
write_hit = 0
write_back_cnt = 0

read_hit_delay = 1
write_hit_delay = 1
-- read_miss_delay = 5
-- write_miss_delay = 5
coherent_delay = 1


-- name, 
-- word_size, 
-- blk_size, 
-- n_blks, 
-- assoc, 
-- hit_time, 
-- write_time, 
-- write_back, 
-- next_level
function _M:new (obj)
   logd('new')

   obj = obj or {}
   setmetatable(obj, self)
   self.__index = self

   obj._sets = {}
   obj._tags = {}
   obj._clk = 0

   obj.n_sets = obj.n_blks / obj.assoc

   offset_lsb = math.log (obj.word_size) / math.log (2)
   offset_msb = obj.offset_lsb + math.log (obj.blk_size) / math.log (2) - 1
   -- logd(' '..obj.name .. ' offset:', offset_msb, offset_lsb)

   obj.offset_mask = bit_mask(offset_msb, offset_lsb)

   index_lsb = offset_msb + 1
   index_msb = index_lsb + math.log (obj.n_sets) / math.log (2) - 1
   -- logd(' '..obj.name .. ' index:', index_msb, index_lsb)
   obj.index_mask = bit_mask(index_msb, index_lsb)

   tag_lsb = index_msb + 1
   tag_msb = obj.word_size * 8 - 1   
   -- logd(' '..obj.name .. ' tag:', tag_msb, tag_lsb)
   obj.tag_mask = bit_mask(tag_msb, tag_lsb)

   logd(string.format('  %s tag:%x index:%x offset:%x', 
   		      obj.name, obj.tag_mask, obj.index_mask, obj.offset_mask))

   return obj
end

function _M:tag(addr)
   return bit.band(addr, self.tag_mask)
end

function _M:index(addr)
   return bit.band(addr, self.index_mask)
end

function _M:offset(addr)
   return bit.band(addr, self.offset_mask)
end

function _M:set_peers(peers)
   self.peers = peers
end

function _M:write_block(blk, offset, tag, val, need_wb)
   blk.tag = tag
   blk.atime = self._clk

   -- TODO to read this block from next level of cache; and before
   -- that, if need_wb is set, should write back dirty data
   blk.dirty = true
   blk[offset] = val
end

function _M:read_block(blk, offset, tag, val, need_wb)
   -- if need_wb is set, should write back dirty data
   blk.atime = self._clk
end

-- TODO: optimize by reduce {} number
function _M:search_block(tag, index)
   -- logd(self.name..' S', tag, index)

   local block = nil

   local sets = self._sets

   local set = sets[index]
   if set then
      local i = 0
      for _, blk in pairs(set) do
	 i = i + 1
	 if blk.tag == tag then	-- a hit
	    block = blk
	    break
	 end
      end

      if not block then		-- a miss
	 if i < self.assoc then -- set not full yet
	    for j = 0, self.assoc - 1 do
	       if not set[j] then 
		  set[j] = {}
		  block = set[j]		  
		  block.status = 'I'
		  break
	       end
	    end
	    
	 else			-- set is full, need to find a victim
	    local access_time = self._clk
	    local vict = 0
	    -- to find the vict with smallest access time, i.e. least
	    -- recently used
	    for j = 0, self.assoc - 1 do
	       if access_time > set[j].atime then
		  access_time = set[j].atime 
		  vict = j
	       end
	    end
	    
	    block = set[vict]

	    -- write_back_addr = bit.bor(block.tag, index)
	    -- self.write_back_cnt = self.write_back_cnt + 1
	 end			-- if i < self.assoc

      end      			-- if not block

   else				-- this set is never accessed before
      sets[index] = {}		-- new set
      sets[index][0] = {}	-- new block
      block = sets[index][0]
      block.status = 'I'	-- invalid
   end				-- if set

   block.atime = self._clk
   return block
end

function _M:read(addr)
   local tag, index, offset = self:tag(addr), self:index(addr), self:offset(addr)
   logd(string.format("%s R: %x %x %x", 
		      self.name, tag, index, offset))

   local delay = self.read_hit_delay
   local blk = self:search_block(tag, index)

   if not blk.tag or blk.tag ~= tag then -- a miss
      self.read_miss = self.read_miss + 1
      if blk.status and  blk.status == 'M' then	-- dirty block, need to write back to next level cache
	 if self.next_level then
	    local write_back_addr = bit.bor(blk.tag, index)
	    delay = delay + self.next_level:write(write_back_addr)
	 end
      end

      if self.peers then
	 local peer_response = false
	 for _, c in pairs(self.peers) do
	    local b, d = c:msi_read_response(tag, index)
	    if b then		-- a peer cache response with a valid block
	       delay = delay + d
	       peer_response = true
	       break
	    end
	 end			-- for 
	 if not peer_response then	-- no peer cache responses, resort to next level cache
	    if self.next_level then
	       delay = delay + self.next_level:read(addr)
	    end
	 end
      end -- if self.peers
      blk.tag = tag
      blk.status = 'S'

   else				-- a hit
      self.read_hit = self.read_hit + 1
   end

   logd(string.format("%s 0x%08x status: %s", self.name, blk.tag + index, blk.status))

   self._clk = self._clk + delay
   return delay
end

function _M:write(addr, val)
   local tag, index, offset = self:tag(addr), self:index(addr), self:offset(addr)
   logd(string.format("%s W: %x %x %x", 
		      self.name, tag, index, offset))

   local blk = self:search_block(tag, index)
   local delay = self.write_hit_delay

   if not blk.tag or blk.tag ~= tag then -- a miss
      self.write_miss = self.write_miss + 1
      
      if blk.status and  blk.status == 'M' then	-- dirty block, need to write back to next level cache
	 if self.next_level then
	    local write_back_addr = bit.bor(blk.tag, index)
	    delay = delay + self.next_level:write(write_back_addr)
	 end
      end

      -- for blk.status == 'S' or 'I', just evict without writing back

      if self.peers then
	 local peer_response = false
	 for _, c in pairs(self.peers) do
	    local b, d = c:msi_write_response(tag, index)
	    if b then		-- a peer cache response with a valid block
	       peer_response = true
	    end
	 end -- for each peer cache
	 if not peer_response then	-- no peer cache responses, resort to next level cache
	    if self.next_level then
	       delay = delay + self.next_level:read(addr)
	    end
	 else
	    delay = delay + self.coherent_delay
	 end
      end -- if self.peers

      blk.tag = tag

   else -- a hit
      self.write_hit = self.write_hit + 1

      if self.peers and blk.status ~= 'M' then -- blk.status == 'S', need to invalidate peer blocks
	 for _, c in pairs(self.peers) do
	    local b, d = c:msi_write_response(tag, index)
	 end -- for each peer cache
      end      
   end -- not blk.tag or blk.tag ~= tag

   blk.status = 'M'
   logd(string.format("%s 0x%08x status: %s", self.name, blk.tag + index, blk.status))

   self._clk = self._clk + delay
   return delay
end

function _M:msi_read_response(tag, index)
   local delay = self.coherent_delay

   local blk = nil
   local set = self._sets[index]
   if set then
      for _, b in pairs(set) do
	 if b.tag == tag then
	    if b.status == 'M' then
	       local write_back_addr = bit.bor(tag, index)
	       delay = delay + self.next_level:write(write_back_addr)
	       b.status = 'S'
	       blk = b
	    elseif b.status == 'S' then
	       blk = b
	    -- elseif b.status == 'I' then -- do nothing
	    end -- b.status	    
	    break
	 end -- b.tag == tag
      end -- for
   end -- set

   logd(string.format("%s msi_read_response 0x%08x status=%s",
		      self.name, 
		      blk and blk.tag or 0, 
		      blk and blk.status or 'I'))
   return blk, delay
end

function _M:msi_write_response(tag, index)
   local delay = self.coherent_delay

   local blk = nil
   local set = self._sets[index]
   if set then
      for _, b in pairs(set) do
	 if b.tag == tag then
	    if b.status == 'M' then
	       local write_back_addr = bit.bor(tag, index)
	       delay = delay + self.next_level:write(write_back_addr)
	       b.status = 'I'
	       blk = b
	    elseif b.status == 'S' then
	       b.status = 'I'
	       blk = b
	    -- elseif b.status == 'I' then -- do nothing
	    end -- b.status	    

	    break
	 end -- b.tag == tag
      end -- for each block of set
   end -- set

   if blk then
      logd(string.format("%s msi_write_response 0x%08x status=%s",
			 self.name, blk.tag, blk.status))
   end

   return blk, delay   
end

#!/usr/bin/env lua

-- TODO: implement a "shared write buffer (SWB)" on parallel with L1
-- cache, so the read/write to L1 is on parallel with access to the
-- SWB.

-- Usage: 

-- require "pepperfish"
function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

function logd(...)
   -- print(...)
end

local cache = require "cache"

-- setup the L1 caches according to the config file
-- local l1_cache_list = {L1a, L1b, L1c, L1d}
local l1_cache_list = dofile("cache/config_b64n64a4_b64n1024a4.lua")


-- the shared write buffer. TODO the read and write functions should
-- override: read will not go to next-level (L1), write will go to
-- next-level on eviction. Neither read nor write will read from L1.
local SWB = cache:new {
   name = "SWB",
   blk_size = 64,		-- a block contains only a word
   n_blks = 64,			-- size = 64 * 64 = 2^12 = 4K
   assoc = 4,			-- 
   miss_delay = 0,		-- 
}

-- which core (meet a miss and) load this block of data 1st.
local accessed = {}

SWB.read = 
function (self, addr, cid)
   local tag, index, offset = self:tag(addr), self:index(addr), self:offset(addr)
   logd(string.format("%s R: %x %x %x", 
		      self.name, tag, index, offset))

   local hit = false
   local delay = 0
   local blk = self:search_block(tag, index)

   if not blk.tag or blk.tag ~= tag then -- a miss, do nothing else here. will resort to L1
      accessed[bit.bor(tag, index)] = {cid = true}
      self.read_miss = self.read_miss + 1
   else				-- a hit
      hit = true
      -- a constructive interference hit
      local access_cores = accessed[bit.bor(tag, index)]
      if access_cores and not access_cores[cid] then
	 self.read_hit_const = self.read_hit_const + 1
	 access_cores[cid] = true
      end
      delay = delay + self.read_hit_delay
      self.read_hit = self.read_hit + 1
   end

   logd(string.format("%s 0x%08x status: %s", self.name, (blk.tag or 0) + index, blk.status))

   self._clk = self._clk + delay
   return delay, hit
end

SWB.write = 
function (self, addr, val, cid)
   -- local t, idx, off = self:tag(addr), self:index(addr), self:offset(addr)
   local t = self:tag(addr)
   local idx = self:index(addr)
   local off = self:offset(addr)

   local hit = false
   local blk = self:search_block(tag, idx)
   local delay = 0

   if not blk.tag or blk.tag ~= t then -- a miss
      accessed[bit.bor(t, idx)] = {cid = true}
      self.write_miss = self.write_miss + 1      

      blk.tag = t

   else -- a hit
      hit = true
      -- a constructive interference hit
      local access_cores = accessed[bit.bor(t, idx)]
      if access_cores and not access_cores[cid] then
	 self.write_hit_const = self.write_hit_const + 1
	 access_cores[cid] = true
      end
      
      delay = delay + self.write_hit_delay
      self.write_hit = self.write_hit + 1

      -- FIXME we shall also account this delay
      if self.peers and blk.status ~= 'M' then -- blk.status == 'S', need to invalidate peer blocks
	 for _, c in pairs(self.peers) do
	    local b, d = c:msi_write_response(t, idx, cid)
	 end -- for each peer cache
      end      
   end -- not blk.tag or blk.tag ~= t

   blk.status = 'M'
   logd(string.format("%s 0x%08x status: %s", self.name, (blk.tag or 0) + idx, blk.status))

   self._clk = self._clk + delay
   return delay, hit
end


function issue(iss)
   local max_b_sz = 0
   for _, b in ipairs(iss) do
      if max_b_sz < #b then max_b_sz = #b end
   end
   
   for i = 1, max_b_sz do
      -- round robin with the cores, to simulate the parallel execution
      for _, b in ipairs(iss) do
	 line = b[i]
	 if line then	 	-- if not nil
	    local rw, addr, cid = string.match(line, "(%a) 0x(%x+) (%d)")
	    logd (line, rw, addr, cid)
	    local delay = 0
	    local L1 = l1_cache_list[tonumber(cid)]
	    if rw == 'W' then
	       logd("---W----")
	       local _, hit = SWB:write(tonumber(addr, 16), 0, tonumber(cid))
	       -- TODO regarding speculative writing, the L1:write should be called on commit
	       delay = L1:write(tonumber(addr, 16), 0, tonumber(cid))
	       logd("---W----")
	    elseif rw == 'R' then
	       logd("---R----")
	       local _, hit = SWB:read(tonumber(addr, 16), tonumber(cid)) 
	       if not hit then
		  delay = L1:read(tonumber(addr, 16), tonumber(cid))		  
	       end
	       logd("---R----")
	    end
	    logd('delay', delay)
	 end
      end
   end
end

local BUFSIZE = 2^15		-- 32K
local f = io.input(arg[1])	-- open input file

while true do
   local lines, rest = f:read(BUFSIZE, "*line")
   if not lines then break end
   if rest then lines = lines .. rest .. "\n" end

   assert(loadstring(lines))()
end

local read_hit_total, read_miss_total, write_hit_total, write_miss_total, clk_total = 0,0,0,0,0

function summarize(cache_list)
   for _, c in pairs(cache_list) do
      c:print_summary()

      read_hit_total = read_hit_total + c.read_hit
      read_miss_total = read_miss_total + c.read_miss
      write_hit_total = write_hit_total + c.write_hit
      write_miss_total = write_miss_total + c.write_miss
      clk_total = clk_total + c._clk
   end
end

clist = {}
for k, v in pairs(l1_cache_list) do
   clist[#clist + 1] = v
end
clist[#clist + 1] = SWB
-- clist[#clist + 1] = L2

summarize(clist)

print("Total read hit/miss:", read_hit_total, read_miss_total, "miss rate:", read_miss_total / (read_hit_total + read_miss_total))
print("Total write hit/miss:", write_hit_total, write_miss_total, "miss rate:", write_miss_total / (write_hit_total + write_miss_total))
print("Total clk/access:", clk_total, read_hit_total + write_hit_total, clk_total/(read_hit_total + write_hit_total))

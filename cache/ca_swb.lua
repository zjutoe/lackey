#!/usr/bin/env lua

-- to support speculative read/write:

-- to compare with blocking mode: block when encountering RAW dependences. 

-- 1. core id tag: each datum is associated with a core id tag,
-- indicating its source. when 2 cores writes to the same mem addr,
-- both datum will be kept in the same set. But we do not divide the
-- whole cache into 4 regions corresponding to the cores, as that
-- would waste lots of space.

-- 2. read preference: a core will read a datum according to logical
-- sequence, from newer to older: a. the datum written by itself;
-- b. the datum written by its immediate predecessor; c. the datum
-- written by ealier predecessors, ordered by sequence. So a later
-- thread will not overwrite the input data of an earlier thread.

-- 3. a duplication buffer (rename buffer) to hold the output from
-- "later" cores, so they will not overwrite that of the
-- non-speculative core, and could be merged to the normal cache line
-- later. Or not merge, but just keep them in the dup buffer, and
-- accessed via some directory based renaming mechanism.

-- 1. write:
--   a. normal thread: write to block, without setting spec tag 
--   b. spec thread: write to block, set spec tag
--   c. location renaming: late threads should not overwrite
-- 2. read:
--   a. normal 

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
local l1_cache_list = require("config/b64n64a4_b64n1024a4")


-- the shared write buffer. TODO the read and write functions should
-- override: read will not go to next-level (L1), write will go to
-- next-level on eviction. Neither read nor write will read from L1.
local SWB = cache:new {
   name = "SWB",
   blk_size = 64,		-- 
   n_blks = 16,			-- size = 64 * 16 = 2^10 = 1K
   assoc = 8,			-- 
   miss_delay = 0,		--

   inter_core_share = 0,    -- statistic data: inter core shared data 
   inter_core_share_captured = 0, -- statistic data: captured inter core shared data
   line_dup = 0,
}


SWB.read = 
function (self, addr, cid)
   local tag, index, offset = self:tag(addr), self:index(addr), self:offset(addr)
   logd(string.format("%s R: %x %x %x", 
		      self.name, tag, index, offset))

   local hit = false
   local delay = 0
   local blk = self:search_block(tag, index)

   if not blk.tag or blk.tag ~= tag then -- a miss, do nothing else here. will resort to L1
      self.read_miss = self.read_miss + 1
   else				-- a hit
      hit = true
      self.read_hit = self.read_hit + 1
   end

   delay = delay + self.read_hit_delay
   if blk.from and blk.from ~= cid then
      self.inter_core_share = self.inter_core_share + 1
      if hit then self.inter_core_share_captured = self.inter_core_share_captured + 1 end
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
      self.write_miss = self.write_miss + 1

      local L1 = l1_cache_list[cid] -- FIXME we shall write to where this dirty data was intended to
      
      if blk.status and  blk.status == 'M' then	-- dirty block, need to write back to next level cache
	 local write_back_addr = bit.bor(blk.tag, idx)
	 delay = delay + L1:write(write_back_addr, 0, cid)
      end
      delay = delay + L1:read(addr, cid)

      blk.tag = t      

   else -- a hit
      hit = true      
      self.write_hit = self.write_hit + 1

   end -- not blk.tag or blk.tag ~= t

   if blk.from and blk.from ~= cid then
      self.inter_core_share = self.inter_core_share + 1
      if hit then
	 self.inter_core_share_captured = self.inter_core_share_captured + 1
	 self.line_dup = self.line_dup + 1
      end
   end

   delay = delay + self.write_hit_delay

   blk.status = 'M'
   blk.from = cid
   logd(string.format("%s 0x%08x", self.name, (blk.tag or 0) + idx))

   self._clk = self._clk + delay
   return delay, hit
end

local delay_cnt, access_cnt = 0,0

function issue(iss)
   local max_b_sz = 0
   for _, b in ipairs(iss) do
      if max_b_sz < #b then max_b_sz = #b end
   end
   
   for i = 1, max_b_sz do
      local delay, hit
      -- round robin with the cores, to simulate the parallel execution
      for _, b in ipairs(iss) do
	 line = b[i]
	 if line then	 	-- if not nil
	    local rw, addr, cid = string.match(line, "(%a) 0x(%x+) (%d)")
	    logd (line, rw, addr, cid)
	    delay = 0
	    local L1 = l1_cache_list[tonumber(cid)]
	    if rw == 'W' then
	       logd("---W----")
	       delay, hit = SWB:write(tonumber(addr, 16), 0, tonumber(cid))
	       logd("---W----")
	    elseif rw == 'R' then
	       logd("---R----")
	       delay, hit = SWB:read(tonumber(addr, 16), tonumber(cid)) 
	       if not hit then
		  delay = L1:read(tonumber(addr, 16), tonumber(cid))	  
	       end
	       -- issue a read to L1 anyway, but do not count in the delay
	       L1:read(tonumber(addr, 16), tonumber(cid))
	       logd("---R----")
	    end
	    
	    logd('delay', delay)
	    if rw == 'W' or rw == 'R' then
	       delay_cnt = delay_cnt + delay
	       access_cnt = access_cnt + 1
	    end
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

print("Total read hit/miss:", read_hit_total, read_miss_total, "hit rate:", read_hit_total / (read_hit_total + read_miss_total))
print("Total write hit/miss:", write_hit_total, write_miss_total, "hit rate:", write_hit_total / (write_hit_total + write_miss_total))
print("Total clk/access:", clk_total, read_hit_total + write_hit_total, clk_total/(read_hit_total + write_hit_total))
print("Delay/Access:", delay_cnt, access_cnt, delay_cnt/access_cnt)
print("Inter Core Share/Access:", SWB.inter_core_share, SWB.inter_core_share_captured,
      SWB.inter_core_share / access_cnt,
      SWB.inter_core_share_captured / access_cnt)
print("Line Duplicate/Access:", SWB.line_dup, access_cnt, SWB.line_dup / access_cnt)

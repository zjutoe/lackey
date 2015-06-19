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
   print(...)
end

local cache = require "cache"

-- setup the L1 caches according to the config file
-- local l1_cache_list = {L1a, L1b, L1c, L1d}
l1_cache_list = require("config/b64n64a4_b64n1024a4")


-- the shared write buffer. TODO the read and write functions should
-- override: read will not go to next-level (L1), write will go to
-- next-level on eviction. Neither read nor write will read from L1.
_M = cache:new {
   name = "SWB",
   blk_size = 64,		-- 
   n_blks = 16,			-- size = 64 * 16 = 2^10 = 1K
   assoc = 8,			-- 
   miss_delay = 0,		--

   inter_core_share = 0,    -- statistic data: inter core shared data 
   inter_core_share_captured = 0, -- statistic data: captured inter core shared data
   line_dup = 0,

   rename_buffer = {}
}


function _M:new (obj)
   obj = obj or {}
   setmetatable(obj, self)
   self.__index = self

   return cache:new (self)
end

_M.read = 
function (self, addr, cid, spec)
   local tag, index, offset = self:tag(addr), self:index(addr), self:offset(addr)
   logd(string.format("%s Read: 0x%08x core %d", self.name, addr, cid))

   local hit = false
   local delay = 0

   local rnb_hit = self.rename_buffer[addr]
   if rnb_hit then
      for pred = cid, 1, -1 do
	 if rnb_hit[pred] then
	    hit = true
	    self.read_hit = self.read_hit + 1
	    logd("SWB read RNB hit")
	    return self.read_hit_delay, hit
	 end
      end
   end

   local blk = self:search_block(tag, index)

   if not blk.tag or blk.tag ~= tag then -- a miss, do nothing else here. will resort to L1
      logd("SWB read miss")
      self.read_miss = self.read_miss + 1
   else				-- a hit
      logd("SWB read hit")
      hit = true
      self.read_hit = self.read_hit + 1
   end

   delay = delay + self.read_hit_delay
   if blk.from and blk.from ~= cid then
      self.inter_core_share = self.inter_core_share + 1
      if hit then self.inter_core_share_captured = self.inter_core_share_captured + 1 end
   end
   -- logd(string.format("%s 0x%08x status: %s", self.name, (blk.tag or 0) + index, blk.status))

   self._clk = self._clk + delay
   return delay, hit
end

-- TODO mark the spec field when writing
_M.write = 
function (self, addr, val, cid, spec)
   logd(string.format("%s Write: 0x%08x core %d", self.name, addr, cid))
   -- local t, idx, off = self:tag(addr), self:index(addr), self:offset(addr)
   local t = self:tag(addr)
   local idx = self:index(addr)
   local off = self:offset(addr)

   local hit = false
   local delay = 0

   local rnb_hit = self.rename_buffer[addr]
   if rnb_hit then
      logd("SWB write RNB hit")
      hit = true
      self.write_hit = self.write_hit + 1
      rnb_hit[cid] = val
      return self.write_hit_delay, hit	 
   end

   local blk = self:search_block(tag, idx)

   if not blk.tag or blk.tag ~= t then -- a miss
      logd("SWB write miss")
      self.write_miss = self.write_miss + 1

      local L1 = l1_cache_list[blk.from or cid]
      -- dirty block, need to write back to next level cache
      if blk.status and  blk.status == 'M' and not blk.spec then
	 local write_back_addr = bit.bor(blk.tag, idx)
	 delay = delay + L1:write(write_back_addr, 0, blk.from or cid)
      end
      delay = delay + L1:read(addr, cid)

      blk.tag = t      

   else -- a hit
      logd("SWB write hit")
      hit = true      
      self.write_hit = self.write_hit + 1

   end -- not blk.tag or blk.tag ~= t

   if blk.from and blk.from ~= cid then
      self.inter_core_share = self.inter_core_share + 1
      if hit then
	 logd("SWB write to rename buffer")
	 self.inter_core_share_captured = self.inter_core_share_captured + 1
	 self.line_dup = self.line_dup + 1

	 -- TODO support multiple copies of the same address - FIXME
	 -- forgot what this means...
	 if not self.rename_buffer[addr] then self.rename_buffer[addr] = {} end
	 self.rename_buffer[addr][cid] = val
      end
   end

   delay = delay + self.write_hit_delay

   blk.status = 'M'
   blk.from = cid
   blk.spec = spec
   blk.valid = true
   -- logd(string.format("%s 0x%08x", self.name, (blk.tag or 0) + idx))

   self._clk = self._clk + delay
   return delay, hit
end

function _M:commit(cid)
   logd("SWB committing output from core", cid)
   for _, set in pairs (self._sets) do
      for _, blk in pairs(set) do
	 if blk.from == cid then
	    blk.spec = false
	 end
      end
   end
end

function _M:discard(cid)
   logd('SWB discarding output of core', cid)
   for _, set in pairs (self._sets) do
      for _, blk in pairs(set) do
	 if blk.from == cid then
	    blk.spec = false
	    blk.valid = false
	 end
      end
   end
end

function _M:clear_rename_buffer()
   self.rename_buffer = {}
end

_M.l1_cache_list = l1_cache_list

SWB = _M

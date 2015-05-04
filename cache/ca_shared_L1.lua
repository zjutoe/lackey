#!/usr/bin/env lua

-- Usage: 

-- require "pepperfish"
function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

function logd(...)
   -- print(...)
end

local cache = require "cache"

local L2 = cache:new{
   name = "L2",			-- L2 of 512KB
   -- word_size = 4,		-- word size in bytes
   -- blk_size = 64,		-- block size in bytes, 2^6
   n_blks = 4096,		-- n_blks, 2^12
   -- assoc = 8,			-- assoc
   read_hit_delay = 10,		-- read delay
   write_hit_delay = 10,	-- write delay
   miss_delay = 40,		-- L3 hit delay
   -- coherent_delay = 8,		-- coherent delay
   write_back = true,		-- write back
   next_level = nil}		-- next level

local L1 = cache:new{
   name = "L1",			-- L1 of 16KB*4
   -- word_size = 4,		-- word size in bytes
   -- blk_size = 64,		-- block size in bytes, 2^6
   n_blks = 1024,		-- n_blks, 2^10
   -- assoc = 8,			-- assoc
   -- read_hit_delay = 4,		-- read_delay
   -- write_hit_delay = 4,		-- write_delay
   -- coherent_delay = 8,		-- coherent delay
   write_back = true,		-- write_back
   next_level = L2}		-- next_level

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
	    logd(rw, addr, cid)
	    if rw == 'W' then
	       logd("---W----")
	       delay = L1:write(tonumber(addr, 16), 0, cid) -- we don't care about the written val 
	       logd("---W----")
	    elseif rw == 'R' then
	       logd("---R----")
	       delay = L1:read(tonumber(addr, 16), cid)
	       logd("---R----")
	    end
	    logd('delay', delay)
	 end
      end
   end
   -- for _, b in ipairs(iss) do
   --    for i, line in ipairs(b) do
   --    end
   -- end
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

summarize({L1})

print("Total read hit/miss:", read_hit_total, read_miss_total, "miss rate:", read_miss_total / (read_hit_total + read_miss_total))
print("Total write hit/miss:", write_hit_total, write_miss_total, "miss rate:", write_miss_total / (write_hit_total + write_miss_total))
print("Total clk/access:", clk_total, read_hit_total + write_hit_total, clk_total/(read_hit_total + write_hit_total))


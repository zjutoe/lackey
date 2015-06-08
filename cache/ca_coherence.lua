#!/usr/bin/env lua

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
local l1_cache_list = require "config/b64n64a4_b64n1024a4"

local delay_cnt, access_cnt = 0,0

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
	    -- print(rw, addr, cid)
	    local L1 = l1_cache_list[tonumber(cid)]
	    if rw == 'W' then
	       logd("---W----")
	       delay = L1:write(tonumber(addr, 16), 0, tonumber(cid))
	       logd("---W----")
	    elseif rw == 'R' then
	       logd("---R----")
	       delay = L1:read(tonumber(addr, 16), tonumber(cid))
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

#!/usr/bin/env lua

-- Usage: 

local dref_cnt = 0

function split_mem_ref(rob_exe_log, mref)

   local addr, current_core = 0, 1
   local dref_cnt = {}

   for i=1, #mref do
      dref_cnt[i] = 0
   end

   for line in rob_exe_log:lines() do
      if line:sub(1,2) ~= "#" then	 
	 if line:sub(1,2) == "SB" then
	    addr, current_core, _icount = string.match(line:sub(4), "(%x+) (%d+) (%d+)")

	 elseif line:sub(1,3) == "MEM" then
	    local type, addr = string.match(line:sub(5), "(%d) (%x+)")
	    local cid = tonumber(current_core)
	    local din = mref[cid]
	    -- TODO 4 => real size
	    din:write(string.format("%s %s 4 d%d\n", type, addr, dref_cnt[cid]))
	    dref_cnt[cid] = dref_cnt[cid] + 1
	 end
      end      
   end				-- for exe in rob_exe_log.lines()

end



function open_files(iofiles)
   local _infile
   
   local _outfile = {} 
   for i, v in ipairs(iofiles) do
      if i == 1 then
	 _infile = assert(io.open(v, "r")) 
      else
	 _outfile[#_outfile + 1] = assert(io.open(v, "w"))
      end
   end

   return _infile, _outfile
end

split_mem_ref(open_files(arg))


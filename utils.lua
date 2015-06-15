function exec_big_file()   
   local BUFSIZE = 2^15		-- 32K
   local f = io.input(arg[1])	-- open input file
   local cc, lc, wc = 0, 0, 0	-- char, line, and word counts
   while true do
      local lines, rest = f:read(BUFSIZE, "*line")
      if not lines then break end
      if rest then lines = lines .. rest .. "\n" end

      assert(loadstring(lines))()
   end
end

#!/usr/bin/env lua

--local Prof = require "profiler"

-- TODO: different instances of the same sb shall be treated as different sb's
-- TODO: do we really support memory writing w/ renaming?
-- TODO: super block merging coelessing
--       the sb's that only depends on a single predecessor, can be merged into the predecessor

local List = require "list"

function logd(...)
   -- print(...)
end

local reg_rename_tab = {}

-- Core
-- to manage all the cores in the processor
Core = {num=0, clocks=0, regsync_push=0, regsync_pull=0}
function Core.new()
   local core_id = Core.num + 1
   local core = {id=core_id, inst_total=0, inst_pend=0, sb_cnt=0}

   Core[core_id] = core
   Core.num = Core.num + 1

   return core
end

-- return the least busy core
function Core.get_free_core()
   local core = Core[1]
   for i=1, Core.num do
      if core.inst_pend > Core[i].inst_pend then
	 core = Core[i]
      end
   end
   return core
end

-- TODO we shall do the work in Core.run() directly
function Core.tick(clocks)

   local core

   for i=1, Core.num do
      core = Core[i]
      if core.inst_pend >= clocks then
	 core.inst_total = core.inst_total + clocks
	 core.inst_pend = core.inst_pend - clocks
      else
	 core.inst_total = core.inst_total + core.inst_pend
	 core.inst_pend = 0
      end
   end   

   Core.clocks = Core.clocks + clocks
   -- TODO add a switch verbose or terse
   -- logd(i_sum, ' in ', clocks, 'clocks')
end

-- drain all the cores
function Core.run()
   local clocks = 0
   local isum = 0
   for i=1, Core.num do
      local c = Core[i]
      if clocks < c.inst_pend then clocks = c.inst_pend end
      isum = isum + c.inst_pend
      c.inst_total = c.inst_total + c.inst_pend
      c.inst_pend = 0
   end

   Core.clocks = Core.clocks + clocks

   -- the following code is used for policy to run until at least one
   -- core is free (finishes its pending instructions)

   -- -- collect the cores with pending sb's to run
   -- local busy_cores = {}
   -- for i=1, Core.num do
   --    if Core[i].inst_pend ~= 0 then
   -- 	 busy_cores[#busy_cores + 1] = Core[i]
   --    end
   -- end

   -- if #busy_cores > 0 then
   --    -- find the least busy core
   --    local pend = busy_cores[1].inst_pend
   --    for i=2, #busy_cores do
   -- 	 if pend > busy_cores[i].inst_pend then pend = busy_cores[i].inst_pend end
   --    end
   --    -- tick as many clocks as needed to free the least busy core
   --    Core.tick(pend)
   -- end

end


-- to record which SB writes to a specific register
local reg_writer = {}

-- data input of the current SB
local reg_input = {}
local reg_output = {}


local sb_addr = 0
-- the SB on which the current sb depends
local deps = {}
local sb_weight = 0

-- collection of all the buffered sb's, key is the addr, val is the sb
local sbs = {}

-- re-order buffer that contains the super blocks awaiting for issuing
local rob = {}

function init_rob(rob, MAX, WIDTH)
   -- the rob.buf is a list of list, as each level of the rob shall
   -- contain several sb's that with the same depth
   -- E.g. with MAX=3 and WIDTH=2, it looks like
   -- {{l00,l01},{l10,l11},{l20,l21}}
   rob.buf = List.new()
   rob.MAX = MAX
   rob.WIDTH = WIDTH
end

-- we are entering a new superblock
function start_sb(addr)
   logd("SB "..addr)
   sb_addr = addr
end

-- place the superblock in the rob
function place_sb(rob, sb)

   -- the sb should be placed after all of its depending sb's
   local buf = rob.buf
   -- d is the depth, i.e. in which level/line of the rob the sb should be put
   local d = buf.first
   local i = 0
   for k, v in pairs(deps) do
      i = i + 1
      if d <= v.d then d = v.d end
   end

   -- look for a non-full line which can hold the sb
   found_slot = false
   local l
   for i=d+1, buf.last do
      l = buf[i]
      if #l < rob.WIDTH then 
	 found_slot = true 
	 d = i
	 break
      end
   end

   if not found_slot then
      List.pushright(buf, {})
      d = buf.last
      l = buf[d]
   end

   -- place the sb in the proper level of the rob
   sb['d'] = d 
   l[#l + 1] = sb

end				-- function place_sb(rob, sb)


-- issue a line of sb's from the rob when necessary
function issue_sb(rob)
   local buf = rob.buf
   if List.size(buf) > rob.MAX then
      local l = List.popleft(buf)
      local w_sum = 0
      local w_max = 0
      local width = 0

      -- to make room for more sb's
      Core.run()

      -- TODO add a switch verbose or terse
      logd('issue:')
      local reg_sync_push_line, reg_sync_pull_line = 0, 0

      for k, v in pairs(l) do
	 width = width + 1
	 -- TODO add a switch verbose or terse
	 logd('     ', v.addr, v.w)
	 w_sum = w_sum + v.w
	 if w_max < 0 + v.w then
	    w_max = 0 + v.w
	 end

	 -- dispatch the sb to a free core
	 local core = Core.get_free_core()
	 core.inst_pend = core.inst_pend + v.w
	 core.sb_cnt = core.sb_cnt + 1

	 -- it's garanteed there's no register write conflict in a
	 -- line of SB
	 local reg_output = {}
	 for _, r in ipairs(v.reg_output) do
	    reg_rename_tab[r] = core.id
	    reg_output[r] = 1
	 end

	 local reg_input = {}
	 for _, r in ipairs(v.reg_input) do
	    reg_input[r] = 1
	 end

	 local reg_sync_push, reg_sync_pull = 0, 0
	 for r, _ in pairs(reg_output) do
	    reg_sync_push = reg_sync_push + 1
	 end
	 for r, _ in pairs(reg_input) do
	    if reg_rename_tab[r] ~= core.id then
	       reg_sync_pull = reg_sync_pull + 1
	    end
	 end

	 logd("SB "..v.addr.." issued to core "..core.id.." reg_sync_push= "..reg_sync_push.."/"..#v.reg_output.." reg_sync_pull= "..reg_sync_pull.."/"..#v.reg_input)
	 reg_sync_push_line = reg_sync_push_line + reg_sync_push
	 reg_sync_pull_line = reg_sync_pull_line + reg_sync_pull
	 
	 sbs[v.addr] = nil
      end      

      print(Core.clocks, w_sum, width, reg_sync_push_line, reg_sync_push_line/(width*w_max), reg_sync_pull_line, reg_sync_pull_line/(width*w_max))
      Core.regsync_push = Core.regsync_push + reg_sync_push_line
      Core.regsync_pull = Core.regsync_pull + reg_sync_pull_line
      -- TODO add a switch verbose or terse
      logd(Core.clocks, w_sum, w_max, width, w_sum/w_max)
      logd("reg_rename_tab")
      for k, v in pairs(reg_rename_tab) do
	 logd(k, v)
      end
   end
end

-- the current superblock ends, we'll analyze it here
function end_sb()
   -- build the superblock
   local sb = {}
   sb['addr'] = sb_addr
   sb['w'] = sb_weight
   sb['deps'] = deps
   sb.reg_input = reg_input
   sb.reg_output = reg_output

   sbs[sb_addr] = sb
   -- io.write(sb_addr.."<=")
   -- for k, v in pairs(deps) do
   --    io.write(k.." ")
   -- end
   -- logd(' R:'..#reg_input)
   place_sb(rob, sb)
   issue_sb(rob)

   deps = {}
   reg_input = {}
   reg_output = {}
end				-- function end_sb()

-- the table deps is a set, we use addr as key, so searching it is
-- efficient
function add_depended(addr)
   deps[addr] = sbs[addr]
   logd('add_depended:', addr)
end

function set_sb_weight(w)
   sb_weight = w
end

function parse_lackey_log(sb_size)
   local i = 0
   local weight_accu = 0
   for line in io.lines() do
      if line:sub(1,2) ~= '==' then
	 i = i + 1
	 local k = line:sub(1,2)
	 if k == 'SB' then
	    if weight_accu >= sb_size then
	       set_sb_weight(weight_accu)
	       end_sb()
	       start_sb(line:sub(4))	       
	       weight_accu = 0
	    end
	 elseif k == ' P' then
	    local reg_no = tonumber(line:sub(4))
	    reg_writer[reg_no] = sb_addr
	    reg_output[#reg_output + 1] = reg_no
	    
	 elseif k == ' G' then
	    local reg_no = tonumber(line:sub(4))
	    local dep = reg_writer[reg_no]
	    if dep and dep ~= sb_addr then 
	       -- io.write("G "..reg_no.." ")
	       add_depended(dep) 
	       reg_input[#reg_input + 1] = reg_no
	    end
	 elseif k == ' W' then
	    weight_accu = weight_accu + tonumber(line:sub(4))
	 end
      end
   end
   -- TODO add a switch verbose or terse
   -- logd(i)
end				--  function parse_lackey_log()

-- the parameters that affects the parallelism 
local core_num = 16
local rob_d = 8
local sb_size = 50

for i, v in ipairs(arg) do
   --print(type(v))
   if (v:sub(1,2) == "-c") then
      --print("core number:")
      core_num = tonumber(v:sub(3))
   elseif (v:sub(1,2) == "-d") then
      --print("ROB depth:")
      rob_d = tonumber(v:sub(3))
   elseif (v:sub(1,2) == "-s") then
      --print("minimum superblock size:")
      sb_size = tonumber(v:sub(3))
   end
end

--Prof.start("mrb.prof.data")

for i=1, core_num do
   Core.new()
end

init_rob(rob, rob_d, core_num)

print("## clock  insts  width, reg_sync, sync/core")

parse_lackey_log(sb_size)

-- summarize
print("## summary")
local inst_total_sum = 0
for i=1, Core.num do
   print("##", Core[i].inst_total, Core[i].sb_cnt)
   inst_total_sum = inst_total_sum + Core[i].inst_total
end

print ("## c/s/d=" .. core_num .. "/" .. sb_size .. "/" .. rob_d .. ":", "execute " .. inst_total_sum .. " insts in " .. Core.clocks .. " clks: ", "speedup: "..inst_total_sum/Core.clocks)
print("## average regsync_push: "..Core.regsync_push/inst_total_sum, " average regsync_pull: "..Core.regsync_pull/inst_total_sum)

--Prof.stop()

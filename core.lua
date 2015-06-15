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
local type = type

module (...)

function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

function logd(...)
   -- print(...)
end

id = 0				-- init with invalid core id


function _M:new (obj)
   logd('new')

   obj = obj or {}
   setmetatable(obj, self)
   self.__index = self

   return obj
end

--[[

function _M:issue_code_block(blk)
   self.exe = blk
   self.exe_idx = 1	      -- set to the 1st instruction in the blk
   self.active = true	      -- not finish executing yet
   self.spec = true	      -- assume speculative execution
   
   local rw, addr, cid, pc = string.match(blk[1], "(%a) 0x(%x+) (%d) (%d)")
   self.pc = pc	     -- Program Conter, a.k.a IP (Instruction Pointer)
end


--]]

function _M:exe_inst()
   mic = self.icache[self.iidx]

   if mic then
      if mic.op == 'W' then
      elseif 
   end

   self.iidx = self.iidx + 1

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

--[[

-- to execute the next intruction, and proceed exe_idx & pc. Actually
-- on speculation failure the core may rewind the exe_idx and pc to
-- beginning.
function _M:proceed()
   -- rewind/re-init the block on speculation failure
   if self.spec_fail then
      self:issue_code_block(self.exe)
      return self.pc
   end

   -- execute the current instruction
   -- TODO
   self:execute_inst()
   
   -- proceed to next instruction
   self.exe_idx = self.exe_idx + 1
   if self.exe_idx > #self.exe then
      self.active = false
   end
   return self.pc
end

--]]

function _M:exe_inst()
   local inst = self.icache[self.iidx]
   
   
end

function _M:commit()
   self.spec = true
end


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
local assert = assert

module (...)

function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

function logd(...)
   print(...)
end

id = 0				-- init with invalid core id

function _M:new (obj)
   logd('new core')

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

function _M:add_inst(inst)
   local icache = self.icache
   icache[#icache + 1] = inst

   if inst.op == 'S' then
      self.s_cnt = self.s_cnt and self.s_cnt + 1 or 0
   elseif inst.op == 'L' then
      self.l_cnt = self.l_cnt and self.l_cnt + 1 or 0
   end
end

function _M:exe_inst(spec)
   if spec == nil then spec = false end -- speculative execution

   assert(self.active)

   -- mic is garanteed not nil
   local mic = self.icache[self.iidx]
   local delay = 0

   assert(mic)
   
   delay = 0

   if mic.op == 'S' then	-- store
      local addr = tonumber(mic.o, 16)
      logd("core", self.id, "Store")
      self.s_exe = self.s_exe and self.s_exe + 1 or 0
      delay, hit = self.swb:write(addr, 0, self.id)
      if self.srr.read[addr] then
	 for c, _ in pairs(self.srr.read[addr]) do
	    if c ~= self.id then
	       -- invalidate the core c
	       logd('invalid core', c)
	       self.srr.kill[c] = true
	    end
	 end
      end
   elseif mic.op == 'L' then	-- load
      local addr = tonumber(mic.i, 16)
      self.l_exe = self.l_exe and self.l_exe + 1 or 0
      delay, hit = self.swb:read(addr, self.id)
      -- issue a read to L1 anyway, but do not count in the delay if SWB hits
      local delay2 = self.L1_cache:read(addr, self.id)
      if hit then delay = delay2 end

      if spec then
	 -- update the Speculative Read Record (SRR)
	 -- FIXME: optimize this by avoiding {}, but use bitfields
	 if self.srr.read[addr] == nil then self.srr.read[addr] = {} end
	 self.srr.read[addr][self.id] = true
      end
   end

   -- if mic.op == 'S' or mic.op == 'L' then
   -- 	 delay_cnt = delay_cnt + delay
   -- 	 access_cnt = access_cnt + 1
   -- end

   self.iidx = self.iidx + 1
   -- end

   if not self.icache[self.iidx] then
      -- no inst remains in i-cache
      self.active = false
   end

   return delay
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

-- FIXME should remove this?
function _M:commit()
   self.spec = true
end


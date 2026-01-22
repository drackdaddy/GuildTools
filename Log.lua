local GT = GuildTools
GT.Log = GT.Log or {}
local L = GT.Log

local function ensure()
  GT.db = GT.db or {}
  if GT.SelectGuildDB then GT:SelectGuildDB() end
  GT.gdb = GT.gdb or {}
  GT.gdb.logs = GT.gdb.logs or {}
end

L.listeners = L.listeners or {}

function L:Add(level, category, message)
  ensure()
  local entry = { ts=time(), level=level or 'INFO', cat=category or 'GEN', msg=tostring(message or '') }
  table.insert(GT.gdb.logs, entry)
  if #GT.gdb.logs > 2000 then for i=1,#GT.gdb.logs-2000 do table.remove(GT.gdb.logs,1) end end
  for _,cb in ipairs(self.listeners) do pcall(cb, entry) end
end
function L:Debug(cat, message)
  if GT.db and GT.db.debug then self:Add('DEBUG', cat or 'DEBUG', message) end
end
function L:Register(cb) table.insert(self.listeners, cb) end
function L:GetAll(filter)
  ensure()
  local src = GT.gdb.logs
  if not filter then return src end
  local out = {}
  for _,e in ipairs(src) do
    if (not filter.level or e.level==filter.level) and (not filter.cat or e.cat==filter.cat) then table.insert(out, e) end
  end
  return out
end

local GT = GuildTools
GT.Log = GT.Log or {}
local L = GT.Log

local function ensure()
  GT.db = GT.db or {}
  GT.db.logs = GT.db.logs or {}
end

L.listeners = L.listeners or {}

-- WHY: Central logging with lightweight listeners; capped buffer for memory hygiene.
function L:Add(level, category, message)
  ensure()
  local entry = { ts=time(), level=level or 'INFO', cat=category or 'GEN', msg=tostring(message or '') }
  table.insert(GT.db.logs, entry)
  if #GT.db.logs > 2000 then for i=1,#GT.db.logs-2000 do table.remove(GT.db.logs,1) end end
  for _,cb in ipairs(self.listeners) do pcall(cb, entry) end
end

function L:Debug(cat, message)
  if GT.db and GT.db.debug then self:Add('DEBUG', cat or 'DEBUG', message) end
end

function L:Register(cb) table.insert(self.listeners, cb) end

function L:GetAll(filter)
  ensure()
  if not filter then return GT.db.logs end
  local out = {}
  for _,e in ipairs(GT.db.logs) do
    if (not filter.level or e.level==filter.level) and (not filter.cat or e.cat==filter.cat) then table.insert(out, e) end
  end
  return out
end
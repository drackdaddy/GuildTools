local GT = GuildTools
GT.Debug = GT.Debug or {}
local D = GT.Debug

-- WHY: Wrap public functions to print call traces when debug is enabled; avoid taint by not replacing protected functions.
local function color(msg) return '|cff00ffff[GuildTools]|r '..tostring(msg) end

local function wrap(tableName, tbl)
  for k,v in pairs(tbl) do
    if type(v) == 'function' and not tostring(k):match('^__') then
      local orig = v
      tbl[k] = function(...)
        if GT.db and GT.db.debug then
          local args = {...}
          for i=1,#args do
            local t=type(args[i])
            if t=='table' or t=='function' or t=='userdata' then args[i]=t else args[i]=tostring(args[i]) end
          end
          DEFAULT_CHAT_FRAME:AddMessage(color('DEBUG: '..tableName..'.'..k..'('..table.concat(args, ',')..')'))
        end
        return orig(...)
      end
    elseif type(v) == 'table' and v ~= GT then
      wrap(tableName..'.'..tostring(k), v)
    end
  end
end

function D:Instrument()
  if not GT.db or not GT.db.debug then return end
  local targets = { 'UI','Comm','Calendar','Raids','Bank','Admin','Minimap','Logs','Log','Utils' }
  for _,name in ipairs(targets) do
    local t = GT[name]
    if type(t)=='table' then wrap(name, t) end
  end
end
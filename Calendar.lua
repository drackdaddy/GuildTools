local GT = GuildTools
local U = GT.Utils

GT.Calendar = GT.Calendar or {}
local Cal = GT.Calendar

local current = { year = tonumber(date('%Y')), month = tonumber(date('%m')) }

local function firstDayOfMonth(y, m) local t=time({year=y, month=m, day=1, hour=0}) return tonumber(date('%w', t)) end
local function daysInMonth(y, m) local t1=time({year=y, month=m+1, day=1}) - 24*3600 return tonumber(date('%d', t1)) end

function Cal:BuildUI(parent)
  local p = CreateFrame('Frame', nil, parent) p:SetAllPoints(true) parent.container = p
  local title = p:CreateFontString(nil,'OVERLAY','GameFontNormalLarge') title:SetPoint('TOPLEFT',20,-20) title:SetText('Calendar')
  local prev = CreateFrame('Button', nil, p, 'UIPanelButtonTemplate') prev:SetSize(24,24) prev:SetPoint('TOPLEFT', 20, -50) prev:SetText('<')
  local next = CreateFrame('Button', nil, p, 'UIPanelButtonTemplate') next:SetSize(24,24) next:SetPoint('LEFT', prev, 'RIGHT', 4, 0) next:SetText('>')
  local monthText = p:CreateFontString(nil,'OVERLAY','GameFontHighlightLarge') monthText:SetPoint('LEFT', next, 'RIGHT', 10, 0)
  local grid = CreateFrame('Frame', nil, p, 'InsetFrameTemplate3') grid:SetPoint('TOPLEFT', 20, -80) grid:SetPoint('BOTTOMRIGHT', -20, 20)
  p.cells = {}
  for r=1,6 do for c=1,7 do local idx=(r-1)*7+c local cell=CreateFrame('Button', nil, grid, 'UIPanelButtonTemplate') cell:SetSize(110,60) local x=10+(c-1)*115 local y=-10-(r-1)*65 cell:SetPoint('TOPLEFT', x, y) cell.text=cell:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall') cell.text:SetPoint('TOPLEFT',6,-6) cell.events=cell:CreateFontString(nil,'OVERLAY','GameFontDisableSmall') cell.events:SetPoint('BOTTOMLEFT',6,6) p.cells[idx]=cell end end
  p.prev=prev p.next=next p.monthText=monthText Cal.parent=p
  prev:SetScript('OnClick', function() current.month=current.month-1 if current.month==0 then current.month=12 current.year=current.year-1 end Cal:Refresh() end)
  next:SetScript('OnClick', function() current.month=current.month+1 if current.month==13 then current.month=1 current.year=current.year+1 end Cal:Refresh() end)
  Cal:Refresh()
end

local function eventsOnDay(y,m,d) local out={} for _,e in pairs(GT.db.events) do local ey=tonumber(date('%Y', e.ts)) local em=tonumber(date('%m', e.ts)) local ed=tonumber(date('%d', e.ts)) if ey==y and em==m and ed==d then table.insert(out,e) end end table.sort(out,function(a,b) return a.ts<b.ts end) return out end

function Cal:Refresh()
  if not Cal.parent then return end local p=Cal.parent
  p.monthText:SetText(date('%B %Y', time({year=current.year, month=current.month, day=1})))
  local fd=firstDayOfMonth(current.year,current.month) local dim=daysInMonth(current.year,current.month) local n=1
  for i=1,42 do local cell=p.cells[i] if i<=fd or n>dim then cell:SetText('') cell.text:SetText('') cell.events:SetText('') cell:Disable() else cell:Enable() cell.text:SetText(tostring(n)) local ev=eventsOnDay(current.year,current.month,n) if #ev>0 then local lines={} for _,e in ipairs(ev) do lines[#lines+1]=string.format('%s %s', date('%H:%M', e.ts), e.title) end cell.events:SetText(table.concat(lines, '\n')) cell:SetScript('OnClick', function() if GT.UI and GT.UI.SelectTab and GT.UI.TAB_INDEX then GT.UI:SelectTab(GT.UI.TAB_INDEX.Raids) end end) else cell.events:SetText('') cell:SetScript('OnClick', nil) end n=n+1 end end
end
 
local GT = GuildTools 
GT.Calendar = GT.Calendar or { } 
local Cal = GT.Calendar 
local current = { year = tonumber(date('%Y')), month = tonumber(date('%m')) } 
local function firstDayOfMonth(y, m) 
 local t = time({year=y, month=m, day=1, hour=0}) 
 return tonumber(date('%w', t)) -- 0=Sun .. 6=Sat 
end 
local function daysInMonth(y, m) 
 local nm, ny = m + 1, y 
 if nm == 13 then nm, ny = 1, y + 1 end 
 local last = time({year=ny, month=nm, day=1}) - 24*3600 
 return tonumber(date('%d', last)) 
end 
local function eventsOnDay(y, m, d) 
 local out = { } 
 for _,e in pairs(GT.gdb.events or { }) do 
 local ey = tonumber(date('%Y', e.ts)); local em = tonumber(date('%m', e.ts)); local ed = tonumber(date('%d', e.ts)) 
 if ey==y and em==m and ed==d then table.insert(out, e) end 
 end 
 table.sort(out, function(a,b) return a.ts < b.ts end) 
 return out 
end 

-- Added: solid color textures helper for buttons
local function SetButtonColorTextures(btn, normalRGB, highlightRGB, pushedRGB, disabledRGB)
  -- Normal
  btn:SetNormalTexture("")
  if not btn:GetNormalTexture() then btn:SetNormalTexture(1,1,1,1) end
  btn:GetNormalTexture():SetColorTexture(normalRGB[1], normalRGB[2], normalRGB[3], 1)
  -- Highlight (slight overlay)
  btn:SetHighlightTexture("")
  if not btn:GetHighlightTexture() then btn:SetHighlightTexture(1,1,1,0.25) end
  btn:GetHighlightTexture():SetColorTexture(highlightRGB[1], highlightRGB[2], highlightRGB[3], 0.35)
  -- Pushed
  btn:SetPushedTexture("")
  if not btn:GetPushedTexture() then btn:SetPushedTexture(1,1,1,1) end
  btn:GetPushedTexture():SetColorTexture(pushedRGB[1], pushedRGB[2], pushedRGB[3], 1)
  -- Disabled
  btn:SetDisabledTexture("")
  if not btn:GetDisabledTexture() then btn:SetDisabledTexture(1,1,1,1) end
  btn:GetDisabledTexture():SetColorTexture(disabledRGB[1], disabledRGB[2], disabledRGB[3], 0.9)
end

local function layout(p) 
 if not p or not p.grid then return end 
 local gridW = p.grid:GetWidth() or 800 
 local gridH = p.grid:GetHeight() or 420 
 local headerH = 18 
 local pad = 6 -- inner padding 
 local colW = math.floor((gridW - pad*2) / 7) 
 local rowH = math.floor((gridH - pad*2 - headerH) / 6) 
 -- Position headers 
 for c=1,7 do 
 local x = pad + (c-1)*colW 
 local hdr = p.headers[c] 
 hdr:ClearAllPoints() 
 hdr:SetPoint('TOPLEFT', p.grid, 'TOPLEFT', x + 4, -pad) 
 hdr:SetWidth(colW - 8) 
 end 
 -- Position cells 
 for i=1,42 do 
 local r = math.floor((i-1)/7) 
 local c = (i-1)%7 
 local x = pad + c*colW 
 local y = pad + headerH + r*rowH 
 local cell = p.cells[i] 
 cell:ClearAllPoints() 
 cell:SetPoint('TOPLEFT', p.grid, 'TOPLEFT', x + 2, -(y + 2)) 
 cell:SetSize(colW - 4, rowH - 4) 
 end 
end 
function Cal:BuildUI(parent) 
 local p = CreateFrame('Frame', nil, parent) 
 p:SetAllPoints(true) 
 parent.container = p 
 local title = p:CreateFontString(nil,'OVERLAY','GameFontNormalLarge') 
 title:SetPoint('TOPLEFT',20,-20) 
 title:SetText('Calendar') 
 local prev = CreateFrame('Button', nil, p, 'UIPanelButtonTemplate') 
 prev:SetSize(24,24) prev:SetPoint('TOPLEFT', 20, -50) prev:SetText('<') 
 local today = CreateFrame('Button', nil, p, 'UIPanelButtonTemplate') 
 today:SetSize(60,24) today:SetPoint('LEFT', prev, 'RIGHT', 6, 0) today:SetText('Today') 
 local next = CreateFrame('Button', nil, p, 'UIPanelButtonTemplate') 
 next:SetSize(24,24) next:SetPoint('LEFT', today, 'RIGHT', 6, 0) next:SetText('>') 
 local monthText = p:CreateFontString(nil,'OVERLAY','GameFontHighlightLarge') 
 monthText:SetPoint('LEFT', next, 'RIGHT', 10, 0) 
 -- Create Raid Event button at top of Calendar 
 local create = CreateFrame('Button', nil, p, 'UIPanelButtonTemplate') 
 create:SetSize(160, 24) 
 create:SetPoint('TOPRIGHT', -20, -50) 
 create:SetText('Create Raid Event') 
 create:SetScript('OnClick', function() 
 if GT.Raids and GT.Raids.OpenCreateDialog then 
 GT.Raids:OpenCreateDialog() 
 else 
 UIErrorsFrame:AddMessage('Raids module not loaded', 1, 0, 0) 
 end 
 end) 
 p.createBtn = create 
 local grid = CreateFrame('Frame', nil, p, 'InsetFrameTemplate3') 
 grid:SetPoint('TOPLEFT', 20, -80) 
 grid:SetPoint('BOTTOMRIGHT', -20, 20) 
 local weekdayNames = { 'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday' } 
 p.headers = { } 
 for c=1,7 do 
 local hdr = grid:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall') 
 hdr:SetText(weekdayNames[c]) 
 hdr:SetJustifyH('LEFT') 
 p.headers[c] = hdr 
 end 
 p.cells = { } 
 for i=1,42 do 
 local cell = CreateFrame('Button', nil, grid, 'UIPanelButtonTemplate') 
 -- Apply light tan textures to each cell
 SetButtonColorTextures(
   cell,
   {0.92, 0.86, 0.76}, -- normal (light tan)
   {0.87, 0.80, 0.68}, -- highlight (hover)
   {0.83, 0.74, 0.59}, -- pushed
   {0.95, 0.92, 0.87}  -- disabled
 )
 local num = cell:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall') 
 num:SetPoint('TOPLEFT', 6, -4) 
 num:SetJustifyH('LEFT') 
 -- Improve contrast on tan
 num:SetTextColor(0.20, 0.16, 0.10)
 cell.num = num 
 local badge = cell:CreateFontString(nil,'OVERLAY','GameFontDisableSmall') 
 badge:SetPoint('TOPRIGHT', -6, -4) 
 badge:SetJustifyH('RIGHT') 
 badge:SetTextColor(0.25, 0.20, 0.12)
 cell.badge = badge 
 local ev1 = cell:CreateFontString(nil,'OVERLAY','GameFontDisableSmall') 
 ev1:SetPoint('BOTTOMLEFT', 6, 18) 
 ev1:SetJustifyH('LEFT'); ev1:SetWordWrap(false) 
 ev1:SetTextColor(0.25, 0.20, 0.12)
 cell.ev1 = ev1 
 local ev2 = cell:CreateFontString(nil,'OVERLAY','GameFontDisableSmall') 
 ev2:SetPoint('BOTTOMLEFT', 6, 4) 
 ev2:SetJustifyH('LEFT'); ev2:SetWordWrap(false) 
 ev2:SetTextColor(0.25, 0.20, 0.12)
 cell.ev2 = ev2 
 p.cells[i] = cell 
 end 
 p.grid = grid; p.monthText = monthText 
 p.prev = prev; p.next = next; p.todayBtn = today 
 Cal.parent = p 
 prev:SetScript('OnClick', function() current.month = current.month - 1 if current.month==0 then current.month=12; current.year=current.year-1 end Cal:Refresh() end) 
 next:SetScript('OnClick', function() current.month = current.month + 1 if current.month==13 then current.month=1; current.year=current.year+1 end Cal:Refresh() end) 
 today:SetScript('OnClick', function() current.year=tonumber(date('%Y')); current.month=tonumber(date('%m')); Cal:Refresh() end) 
 grid:SetScript('OnSizeChanged', function() layout(p); Cal:Refresh() end) 
 layout(p) 
 Cal:Refresh() 
end 
function Cal:Refresh() 
 if not Cal.parent then return end 
 local p = Cal.parent 
 p.monthText:SetText(date('%B %Y', time({year=current.year, month=current.month, day=1}))) 
 local fd = firstDayOfMonth(current.year, current.month) -- 0=Sun..6=Sat 
 local dim = daysInMonth(current.year, current.month) 
 local ty, tm, td = tonumber(date('%Y')), tonumber(date('%m')), tonumber(date('%d')) 
 local n = 1 
 for i=1,42 do 
 local cell = p.cells[i] 
 cell:SetScript('OnClick', nil) 
 local inMonth = (i > fd) and (n <= dim) 
 if inMonth then 
 local day = n; n = n + 1 
 cell:Enable() 
 cell.num:SetText(tostring(day)) 
 -- Use dark text on tan
 cell.num:SetTextColor(0.20, 0.16, 0.10) 
 local ev = eventsOnDay(current.year, current.month, day) 
 cell.badge:SetText((#ev > 0) and tostring(#ev) or '') 
 local function trunc(s) if not s then return '' end if s:len() > 18 then return s:sub(1,18)..'…' else return s end end 
 cell.ev1:SetText(#ev >= 1 and trunc(date('%H:%M', ev[1].ts)..' '..(ev[1].title or 'Event')) or '') 
 cell.ev2:SetText(#ev >= 2 and trunc(date('%H:%M', ev[2].ts)..' '..(ev[2].title or 'Event')) or '') 
 if (current.year==ty and current.month==tm and day==td) then 
 cell:SetAlpha(1) 
 else 
 cell:SetAlpha(1) 
 end 
 cell:SetScript('OnClick', function() 
 if #ev > 0 and GT.UI and GT.UI.SelectTab and GT.UI.TAB_INDEX then 
 GT.UI:SelectTab(GT.UI.TAB_INDEX.Raids) 
 end 
 end) 
 else 
 -- Outside current month: leave the cell blank and disabled 
 cell:Disable() 
 cell.num:SetText('') 
 cell.badge:SetText('') 
 cell.ev1:SetText('') 
 cell.ev2:SetText('') 
 cell:SetAlpha(0.6) 
 end 
 end 
end 

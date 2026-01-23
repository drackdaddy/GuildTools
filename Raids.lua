local GT = GuildTools
local U = GT.Utils
local Log = GT.Log
GT.Raids = GT.Raids or {}
local R = GT.Raids

-- Static catalog of raids by version
local RAID_CATALOG = {
  Classic = {
    "Molten Core",
    "Onyxia's Lair",
    "Blackwing Lair",
    "Zul'Gurub",
    "Ruins of Ahn'Qiraj",
    "Temple of Ahn'Qiraj",
    "Naxxramas",
  },
  ["Burning Crusade"] = {
    "Karazhan",
    "Gruul's Lair",
    "Magtheridon's Lair",
    "Serpentshrine Cavern",
    "Tempest Keep: The Eye",
    "Battle for Mount Hyjal",
    "Black Temple",
    "Zul'Aman",
    "Sunwell Plateau",
  },
}

local function firstDayOfMonth(y, m)
  local t = time({year=y, month=m, day=1, hour=0, min=0, sec=0})
  return tonumber(date('%w', t)) -- 0=Sun .. 6=Sat
end
local function daysInMonth(y, m)
  local nm, ny = m + 1, y
  if nm == 13 then nm, ny = 1, y + 1 end
  local last = time({year=ny, month=nm, day=1, hour=0, min=0, sec=0}) - 24*3600
  return tonumber(date('%d', last))
end

-- create event in guild bucket and broadcast
local function createEvent(title, ts, instance)
  local id = U:NewId('evt')
  local e = { id = id, title = title or 'Raid', ts = ts or time(), instance = instance or 'Other', roles = {}, signups = {}, comp = {} }
  GT.gdb.events[id] = e
  GT.gdb.dataVersion = (GT.gdb.dataVersion or 1) + 1
  if GT.Comm then GT.Comm:Send('EVENT_UPDATE', U:Serialize(e)) end
  if Log then Log:Add('INFO','EVENT','Created raid '..e.title..' ('..e.instance..')') end
  return e
end

function R:BuildUI(parent)
  local p = CreateFrame('Frame', nil, parent)
  p:SetAllPoints(true)
  parent.container = p
  local y = -20
  local header = p:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
  header:SetPoint('TOPLEFT',20,y)
  header:SetText('Create Raid Event')
  local createBtn = CreateFrame('Button', nil, p, 'UIPanelButtonTemplate')
  createBtn:SetSize(120,24)
  createBtn:SetPoint('TOPLEFT', 20, y - 26)
  createBtn:SetText('Create')

  -- Date selector (same UI as before, omitted for brevity) --> keeping from your file
  -- Rebuild minimal working selector for completeness
  y = y - 60
  local dateBtn = CreateFrame('Button', nil, p, 'UIPanelButtonTemplate')
  dateBtn:SetSize(180,24)
  dateBtn:SetPoint('TOPLEFT', 20, y)
  local now = time()
  local tomorrow = now + 24*3600
  local sel = { year=tonumber(date('%Y', tomorrow)), month=tonumber(date('%m', tomorrow)), day=tonumber(date('%d', tomorrow)), hour=20, min=0 }
  local function to12h(h24) local ap = (h24 < 12) and 'AM' or 'PM'; local h12 = h24 % 12; if h12==0 then h12=12 end; return h12, ap end
  local function to24h(h12, ap) if ap=='PM' then if h12<12 then return h12+12 end; return 12 else if h12==12 then return 0 end; return h12 end end
  local function fmtBtn() local h12, ap = to12h(sel.hour); return string.format('%02d/%02d/%04d %02d:%02d %s', sel.month, sel.day, sel.year, h12, sel.min, ap) end
  dateBtn:SetText(fmtBtn())
  local fly = CreateFrame('Frame', nil, p, 'InsetFrameTemplate3')
  fly:SetSize(520, 336); fly:SetPoint('TOPLEFT', dateBtn, 'BOTTOMLEFT', 0, -2); fly:SetClampedToScreen(true); fly:SetToplevel(true); fly:SetFrameStrata('TOOLTIP'); fly:SetFrameLevel((p:GetFrameLevel() or 0)+200); fly:Hide(); fly:SetScript('OnShow', function(self) self:Raise() end)
  fly.monthText = fly:CreateFontString(nil,'OVERLAY','GameFontHighlightLarge'); fly.monthText:SetPoint('TOPLEFT', 12, -10)
  local prevBtn = CreateFrame('Button', nil, fly, 'UIPanelButtonTemplate'); prevBtn:SetSize(24,22); prevBtn:SetPoint('TOPRIGHT', -80, -10); prevBtn:SetText('<')
  local nextBtn = CreateFrame('Button', nil, fly, 'UIPanelButtonTemplate'); nextBtn:SetSize(24,22); nextBtn:SetPoint('LEFT', prevBtn, 'RIGHT', 6, 0); nextBtn:SetText('>')
  local current = { year = sel.year, month = sel.month }
  local weekdayNames = { 'Sun','Mon','Tue','Wed','Thu','Fri','Sat' }
  for i=1,7 do local lbl = fly:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); lbl:SetPoint('TOPLEFT', 12 + (i-1)*70, -40); lbl:SetText(weekdayNames[i]) end
  fly.cells = {}
  local function makeCell(idx)
    local r = math.floor((idx-1)/7); local c = (idx-1)%7
    local btn = CreateFrame('Button', nil, fly, 'UIPanelButtonTemplate')
    btn:SetSize(64, 28); btn:SetPoint('TOPLEFT', 10 + c*70, -60 - r*32)
    btn.text = btn:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); btn.text:SetPoint('CENTER')
    btn.day = nil; btn.index = idx
    local selTex = btn:CreateTexture(nil, 'ARTWORK'); selTex:SetAllPoints(btn); selTex:SetColorTexture(0, 1, 0, 0.25); selTex:Hide(); btn.selTex = selTex
    fly.cells[idx] = btn; return btn
  end
  for i=1,42 do makeCell(i) end
  fly.selectedIndex = nil
  local function setSelectedByIndex(idx)
    if fly.selectedIndex and fly.cells[fly.selectedIndex] then fly.cells[fly.selectedIndex].selTex:Hide() end
    fly.selectedIndex = idx; if fly.cells[idx] then fly.cells[idx].selTex:Show() end
  end
  local function refreshCalendar()
    fly.monthText:SetText(date('%B %Y', time({year=current.year, month=current.month, day=1})))
    local fd = firstDayOfMonth(current.year, current.month); local dim = daysInMonth(current.year, current.month)
    for i=1,42 do local b = fly.cells[i]; b.day=nil; b.text:SetText(''); b:Disable(); b.selTex:Hide() end
    local n = 1
    for i=(fd+1),(fd+dim) do local b = fly.cells[i]; b.day = n; b.text:SetText(tostring(n)); b:Enable(); if current.year==sel.year and current.month==sel.month and n==sel.day then setSelectedByIndex(i) end; n=n+1 end
  end
  for i=1,42 do local b=fly.cells[i]; b:SetScript('OnClick', function(self) if not self.day then return end; sel.year, sel.month, sel.day = current.year, current.month, self.day; setSelectedByIndex(self.index) end) end
  prevBtn:SetScript('OnClick', function() current.month = current.month - 1; if current.month==0 then current.month=12; current.year=current.year-1 end; refreshCalendar() end)
  nextBtn:SetScript('OnClick', function() current.month = current.month + 1; if current.month==13 then current.month=1; current.year=current.year+1 end; refreshCalendar() end)
  local timeRow = CreateFrame('Frame', nil, fly); timeRow:SetPoint('TOPLEFT', 0, -260); timeRow:SetSize(520, 24)
  local timeLbl = timeRow:CreateFontString(nil,'OVERLAY','GameFontHighlight'); timeLbl:SetPoint('LEFT', 12, 0); timeLbl:SetText('Time:')
  local hourEdit = CreateFrame('EditBox', nil, timeRow, 'InputBoxTemplate'); hourEdit:SetSize(36,22); hourEdit:SetPoint('LEFT', timeLbl, 'RIGHT', 8, 0); hourEdit:SetAutoFocus(false); hourEdit:SetNumeric(true); hourEdit:SetMaxLetters(2)
  local colon = timeRow:CreateFontString(nil,'OVERLAY','GameFontHighlight'); colon:SetPoint('LEFT', hourEdit, 'RIGHT', 4, 0); colon:SetText(':')
  local minEdit = CreateFrame('EditBox', nil, timeRow, 'InputBoxTemplate'); minEdit:SetSize(36,22); minEdit:SetPoint('LEFT', colon, 'RIGHT', 4, 0); minEdit:SetAutoFocus(false); minEdit:SetNumeric(true); minEdit:SetMaxLetters(2)
  local ampmDrop = CreateFrame('Frame', nil, timeRow, 'UIDropDownMenuTemplate'); ampmDrop:SetPoint('LEFT', minEdit, 'RIGHT', -16, 0); UIDropDownMenu_SetWidth(ampmDrop, 70)
  local ampmValue = 'PM'
  local function initAmpm()
    UIDropDownMenu_Initialize(ampmDrop, function(self, level)
      for _,val in ipairs({'AM','PM'}) do local info = UIDropDownMenu_CreateInfo(); info.text = val; info.func = function() ampmValue = val; UIDropDownMenu_SetText(ampmDrop, val) end; UIDropDownMenu_AddButton(info) end
    end)
  end
  local applyBtn = CreateFrame('Button', nil, fly, 'UIPanelButtonTemplate'); applyBtn:SetSize(80,22); applyBtn:SetPoint('BOTTOMRIGHT', -10, 8); applyBtn:SetText('Apply')
  local cancelBtn = CreateFrame('Button', nil, fly, 'UIPanelButtonTemplate'); cancelBtn:SetSize(80,22); cancelBtn:SetPoint('RIGHT', applyBtn, 'LEFT', -8, 0); cancelBtn:SetText('Cancel')
  dateBtn:SetScript('OnClick', function() if fly:IsShown() then fly:Hide() else current.year,current.month = sel.year, sel.month; refreshCalendar(); local h12, ap = to12h(sel.hour or 20); hourEdit:SetText(string.format('%02d', h12)); minEdit:SetText(string.format('%02d', sel.min or 0)); ampmValue = ap; initAmpm(); UIDropDownMenu_SetText(ampmDrop, ampmValue); fly:Show(); fly:Raise() end end)
  cancelBtn:SetScript('OnClick', function() fly:Hide() end)
  applyBtn:SetScript('OnClick', function() local h12 = tonumber(hourEdit:GetText()) or 12; local mm = tonumber(minEdit:GetText()) or 0; if h12<1 then h12=1 elseif h12>12 then h12=12 end; if mm<0 then mm=0 elseif mm>59 then mm=59 end; sel.hour, sel.min = to24h(h12, ampmValue or 'AM'), mm; dateBtn:SetText(fmtBtn()); fly:Hide() end)
  refreshCalendar(); local initH12, initAP = to12h(sel.hour); hourEdit:SetText(string.format('%02d', initH12)); minEdit:SetText(string.format('%02d', sel.min)); ampmValue = initAP; initAmpm(); UIDropDownMenu_SetText(ampmDrop, ampmValue)

  -- Version and instance dropdowns (same behavior as your original)
  local versionDrop = CreateFrame('Frame', nil, p, 'UIDropDownMenuTemplate'); versionDrop:SetPoint('LEFT', dateBtn, 'RIGHT', 10, 0); UIDropDownMenu_SetWidth(versionDrop, 120)
  local selectedVersion = 'Classic'
  local instanceDrop = CreateFrame('Frame', nil, p, 'UIDropDownMenuTemplate'); instanceDrop:SetPoint('LEFT', versionDrop, 'RIGHT', -10, 0); UIDropDownMenu_SetWidth(instanceDrop, 180)
  local selectedRaid = nil
  local function PopulateInstanceDrop(versionName) end
  UIDropDownMenu_Initialize(versionDrop, function(self, level)
    for _, ver in ipairs({ 'Classic', 'Burning Crusade' }) do
      local info = UIDropDownMenu_CreateInfo(); info.text = ver; info.func = function() selectedVersion = ver; UIDropDownMenu_SetText(versionDrop, ver); PopulateInstanceDrop(selectedVersion) end; UIDropDownMenu_AddButton(info)
    end
  end)
  UIDropDownMenu_SetText(versionDrop, selectedVersion)
  PopulateInstanceDrop = function(versionName)
    local list = RAID_CATALOG[versionName] or {}
    selectedRaid = list[1] or 'Other'
    UIDropDownMenu_SetText(instanceDrop, selectedRaid)
    UIDropDownMenu_Initialize(instanceDrop, function(self, level)
      for _, raidName in ipairs(list) do local info = UIDropDownMenu_CreateInfo(); info.text = raidName; info.func = function() selectedRaid = raidName; UIDropDownMenu_SetText(instanceDrop, raidName) end; UIDropDownMenu_AddButton(info) end
    end)
  end
  PopulateInstanceDrop(selectedVersion)

  createBtn:SetScript('OnClick', function()
    if not U:HasPermission(GT.gdb.permissions.raidsMinRank) then UIErrorsFrame:AddMessage('Insufficient rank to create raids',1,0,0); return end
    if not (sel.year and sel.month and sel.day) then UIErrorsFrame:AddMessage('Please select a date.',1,0,0); return end
    local ts = time({ year = sel.year, month = sel.month, day = sel.day, hour = sel.hour or 20, min = sel.min or 0, sec = 0 })
    local instName = selectedRaid or UIDropDownMenu_GetText(instanceDrop) or 'Other'
    local title = instName
    createEvent(title, ts, instName)
    R:Refresh()
  end)

  local list = CreateFrame('Frame', nil, p, 'InsetFrameTemplate3')
  list:SetPoint('TOPLEFT', 20, -140)
  list:SetPoint('BOTTOMRIGHT', -20, 20)
  local scroll = CreateFrame('ScrollFrame', 'GTR_Scroll', list, 'UIPanelScrollFrameTemplate')
  scroll:SetPoint('TOPLEFT', 10, -10)
  scroll:SetPoint('BOTTOMRIGHT', -30, 10)
  local content = CreateFrame('Frame', nil, scroll)
  content:SetSize(1,1)
  scroll:SetScrollChild(content)
  p.content = content
  R.parent = p
  R:Refresh()
end

local function getSortedEvents()
  local arr = {}
  for _,e in pairs(GT.gdb.events or {}) do table.insert(arr, e) end
  table.sort(arr, function(a,b) return a.ts < b.ts end)
  return arr
end

-- Composition editor (unchanged logic, but writes to GT.gdb via event reference)
R.Comp = R.Comp or {}
local Comp = R.Comp
function Comp:Open(event)
  if not Comp.frame then
    local f = CreateFrame('Frame', 'GuildToolsCompFrame', UIParent, 'BasicFrameTemplateWithInset')
    f:SetSize(700,420); f:SetPoint('CENTER'); f:SetFrameStrata('DIALOG'); f:SetToplevel(true); f:SetClampedToScreen(true)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag('LeftButton'); f:SetScript('OnDragStart', f.StartMoving); f:SetScript('OnDragStop', f.StopMovingOrSizing); f:SetScript('OnShow', function(self) self:Raise() end); f:Hide()
    f.title = f:CreateFontString(nil,'OVERLAY','GameFontHighlight'); f.title:SetPoint('LEFT', f.TitleBg, 'LEFT', 6, 0)
    local list = CreateFrame('Frame', nil, f, 'InsetFrameTemplate3'); list:SetPoint('TOPLEFT',12,-60); list:SetPoint('BOTTOMLEFT',12,12); list:SetWidth(320)
    local scroll = CreateFrame('ScrollFrame', 'GTR_COMP_SCROLL', list, 'UIPanelScrollFrameTemplate'); scroll:SetPoint('TOPLEFT',8,-8); scroll:SetPoint('BOTTOMRIGHT', -28, 8)
    local content = CreateFrame('Frame', nil, scroll); content:SetSize(1,1); scroll:SetScrollChild(content)
    f.signupContent = content
    local right = CreateFrame('Frame', nil, f, 'InsetFrameTemplate3'); right:SetPoint('TOPRIGHT', -12, -60); right:SetPoint('BOTTOMRIGHT', -12, 12); right:SetWidth(320)
    f.right = right
    local save = CreateFrame('Button', nil, f, 'UIPanelButtonTemplate'); save:SetSize(140,24); save:SetPoint('TOPLEFT',12,-28); save:SetText('Save & Broadcast')
    save:SetScript('OnClick', function()
      if Comp.event then
        GT.gdb.events[Comp.event.id] = Comp.event
        GT.gdb.dataVersion = (GT.gdb.dataVersion or 1) + 1
        if GT.Comm then GT.Comm:Send('EVENT_UPDATE', U:Serialize(Comp.event)) end
      end
      f:Hide()
    end)
    Comp.frame = f
  end
  Comp.event = event
  Comp.frame.title:SetText('Raid Composition — '..(event.title or 'Event'))
  Comp:Refresh()
  Comp.frame:Show(); Comp.frame:Raise()
end

local function classColor(class) local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]; if c then return c.r,c.g,c.b end; return 1,1,1 end

function Comp:Refresh()
  local f = Comp.frame; if not f or not Comp.event then return end
  local e = Comp.event
  e.comp = e.comp or {}
  for _,child in ipairs({f.signupContent:GetChildren()}) do child:Hide(); child:SetParent(nil) end
  local y = -4
  for name,s in pairs(e.signups or {}) do
    local row = CreateFrame('Frame', nil, f.signupContent) row:SetSize(280,22) row:SetPoint('TOPLEFT',4,y)
    local r,g,b = classColor(s.class)
    local txt = row:CreateFontString(nil,'OVERLAY','GameFontHighlight') txt:SetPoint('LEFT',4,0)
    txt:SetText(string.format('|cff%02x%02x%02x%s|r (%s)', r*255,g*255,b*255,name,s.role))
    local dd = CreateFrame('Frame', nil, row, 'UIDropDownMenuTemplate') dd:SetPoint('LEFT', txt, 'RIGHT', 8, 0)
    UIDropDownMenu_SetWidth(dd,100)
    UIDropDownMenu_SetText(dd, e.comp[name] and ('Group '..e.comp[name]) or 'Unassigned')
    UIDropDownMenu_Initialize(dd, function(self, level)
      local function add(label, val) local info=UIDropDownMenu_CreateInfo(); info.text=label; info.func=function() e.comp[name]=val; UIDropDownMenu_SetText(dd, val and ('Group '..val) or 'Unassigned'); Comp:RefreshRight() end; UIDropDownMenu_AddButton(info) end
      add('Unassigned', nil); for g=1,5 do add('Group '..g, g) end
    end)
    y = y - 24
  end
  f.signupContent:SetHeight(-y+10)
  Comp:RefreshRight()
end

function Comp:RefreshRight()
  local right = Comp.frame.right
  local e = Comp.event
  for _,c in ipairs({right:GetChildren()}) do c:Hide(); c:SetParent(nil) end
  local y = -8
  for g=1,5 do
    local header = right:CreateFontString(nil,'OVERLAY','GameFontNormal'); header:SetPoint('TOPLEFT', 8, y); header:SetText('Group '..g)
    y = y - 18
    for name,grp in pairs(e.comp or {}) do
      if grp == g then
        local s = e.signups[name]
        local r,gg,b = 1,1,1; if s and s.class then r,gg,b = classColor(s.class) end
        local line = right:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); line:SetPoint('TOPLEFT', 16, y)
        line:SetText(string.format('|cff%02x%02x%02x%s|r', r*255,gg*255,b*255,name))
        y = y - 14
      end
    end
    y = y - 6
  end
end

function R:Refresh()
  if not R.parent then return end
  local content = R.parent.content
  for _,c in ipairs({content:GetChildren()}) do c:Hide(); c:SetParent(nil) end
  local y = -5
  for _,e in ipairs(getSortedEvents()) do
    local box = CreateFrame('Frame', nil, content, 'InsetFrameTemplate3')
    box:SetSize(800,140); box:SetPoint('TOPLEFT',5,y)
    local title = box:CreateFontString(nil,'OVERLAY','GameFontNormal')
    title:SetPoint('TOPLEFT',10,-8)
    title:SetText(string.format('%s \n %s', e.title, date('%b %d %I:%M %p', e.ts)))
    local counts = {tanks=0,heals=0,dps=0}
    for _,s in pairs(e.signups) do counts[s.role] = (counts[s.role] or 0) + 1 end
    local status = box:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    status:SetPoint('TOPRIGHT',-10,-10)
    status:SetText(string.format('T:%d H:%d D:%d', counts.tanks or 0, counts.heals or 0, counts.dps or 0))
    local detailsBtn = CreateFrame('Button', nil, box, 'UIPanelButtonTemplate')
    detailsBtn:SetSize(70,20); detailsBtn:SetPoint('TOPLEFT',10,-28); detailsBtn:SetText('Details')
    box.detailsShown=false
    detailsBtn:SetScript('OnClick', function()
      box.detailsShown = not box.detailsShown
      if box.detailsShown then detailsBtn:SetText('Hide') else detailsBtn:SetText('Details') end
      if box.detailFrame then box.detailFrame:SetShown(box.detailsShown) end
    end)
    local df = CreateFrame('Frame', nil, box)
    df:SetPoint('TOPLEFT',10,-50); df:SetPoint('TOPRIGHT', -10, -50); df:SetHeight(44); df:Hide(); box.detailFrame = df
    local function addRole(label,key,x)
      local hdr = df:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); hdr:SetPoint('TOPLEFT',x,0); hdr:SetText(label..':')
      local line = df:CreateFontString(nil,'OVERLAY','GameFontDisableSmall'); line:SetPoint('TOPLEFT',x,-14)
      local names = {}; for name,s in pairs(e.signups) do if s.role==key then table.insert(names, name) end end
      table.sort(names); line:SetText(table.concat(names, ', '))
    end
    addRole('Tanks','tanks',0); addRole('Heals','heals',220); addRole('DPS','dps',440)

    local roles={'tanks','heals','dps'}
    for i,role in ipairs(roles) do
      local b = CreateFrame('Button', nil, box, 'UIPanelButtonTemplate')
      b:SetSize(100,22); b:SetPoint('BOTTOMLEFT',10+(i-1)*110,38); b:SetText('Sign '..string.upper(role:sub(1,1)))
      b:SetScript('OnClick', function()
        local name = UnitName('player'); local _,class = UnitClass('player')
        e.signups[name] = { player=name, class=class, role=role }
        GT.gdb.dataVersion = (GT.gdb.dataVersion or 1) + 1
        if GT.Comm then GT.Comm:Send('EVENT_UPDATE', U:Serialize(e)) end
        if Log then Log:Add('INFO','EVENT','Signup '..name..' as '..role) end
        R:Refresh()
      end)
    end

    if U:HasPermission(GT.gdb.permissions.raidsMinRank) then
      local build=CreateFrame('Button', nil, box, 'UIPanelButtonTemplate')
      build:SetSize(140,22); build:SetPoint('BOTTOMRIGHT', -10, 10); build:SetText('Build Raid Comp')
      build:SetScript('OnClick', function() R.Comp:Open(e) end)
      local edit=CreateFrame('Button', nil, box, 'UIPanelButtonTemplate')
      edit:SetSize(80,22); edit:SetPoint('BOTTOMRIGHT', -160, 10); edit:SetText('Edit')
      edit:SetScript('OnClick', function()
        StaticPopupDialogs['GTR_EDIT_TITLE']={ text='Set new title:', button1='Save', button2='Cancel', hasEditBox=true, timeout=0, whileDead=true, hideOnEscape=true,
          OnAccept=function(d)
            e.title = d.editBox:GetText() or e.title
            if GT.Comm then GT.Comm:Send('EVENT_UPDATE', U:Serialize(e)) end
            if Log then Log:Add('INFO','EVENT','Renamed event '..e.id..' to '..e.title) end
            R:Refresh()
          end }
        local dlg=StaticPopup_Show('GTR_EDIT_TITLE'); if dlg and dlg.editBox then dlg.editBox:SetText(e.title or '') end
      end)
      local del=CreateFrame('Button', nil, box, 'UIPanelButtonTemplate')
      del:SetSize(80,22); del:SetPoint('BOTTOMRIGHT', -260, 10); del:SetText('Delete')
      del:SetScript('OnClick', function()
        StaticPopupDialogs['GTR_DEL_EVT']={ text='Delete this event?', button1='Yes', button2='No', timeout=0, whileDead=true, hideOnEscape=true,
          OnAccept=function()
            GT.gdb.events[e.id] = nil
            if GT.Comm then GT.Comm:Send('EVENT_DELETE', U:Serialize({id=e.id})) end
            if Log then Log:Add('INFO','EVENT','Deleted event '..e.id) end
            R:Refresh()
          end }
        StaticPopup_Show('GTR_DEL_EVT')
      end)
    end
    y = y - 150
  end
  content:SetHeight(-y+20)
end
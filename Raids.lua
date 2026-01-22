local GT  = GuildTools
local U   = GT.Utils
local Log = GT.Log

GT.Raids = GT.Raids or {}
local R = GT.Raids

local INSTANCES = {
  'Karazhan','Gruul\'s Lair','Magtheridon\'s Lair','Serpentshrine Cavern','Tempest Keep: The Eye','Hyjal Summit','Black Temple','Zul\'Aman','Sunwell Plateau',
  'Molten Core','Blackwing Lair','Ahn\'Qiraj 40','Ruins of Ahn\'Qiraj','Naxxramas'
}

-- WHY: Compute days in a month (handles leap years)
local function daysInMonth(year, month)
  local nm, ny = month + 1, year
  if nm == 13 then nm, ny = 1, year + 1 end
  local last = time({year=ny, month=nm, day=1, hour=0, min=0, sec=0}) - 24*3600
  return tonumber(date('%d', last))
end

-- WHY: Create a new raid event; role caps removed (unlimited signups)
local function createEvent(title, ts, instance, size)
  local id = U:NewId('evt')
  local e = {
    id=id,
    title=title or 'Raid',
    ts=ts or time(),
    instance=instance or 'Karazhan',
    size=size or 10,
    -- roles caps removed: keep empty table for future metadata if needed
    roles={},                 -- NOTE: no caps; purely informational now
    signups={},               -- name -> { player, class, role }
    comp={}                   -- optional group assignments
  }
  GT.db.events[id] = e
  GT.db.dataVersion = (GT.db.dataVersion or 1) + 1
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

  y = y - 30
  -- Title
  local nameEdit = CreateFrame('EditBox', nil, p, 'InputBoxTemplate')
  nameEdit:SetSize(260,24)
  nameEdit:SetPoint('TOPLEFT',20,y)
  nameEdit:SetAutoFocus(false)
  nameEdit:SetText('Raid Title')

  -- ================================
  -- DATE SELECTORS (STACKED: Year, Month, Day)
  -- ================================
  local now = time()
  local curYear  = tonumber(date('%Y', now))
  local curMonth = tonumber(date('%m', now))
  local curDay   = tonumber(date('%d', now))
  local sel = { year=curYear, month=curMonth, day=curDay }

  -- Year (stack 1)
  y = y - 36
  local yearLbl = p:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
  yearLbl:SetPoint('TOPLEFT',20,y)
  yearLbl:SetText('Year:')

  local yearDrop = CreateFrame('Frame', nil, p, 'UIDropDownMenuTemplate')
  yearDrop:SetPoint('TOPLEFT', yearLbl, 'BOTTOMLEFT', -12, -2) -- dropdowns have left padding; offset -12 aligns text
  UIDropDownMenu_SetWidth(yearDrop, 100)
  UIDropDownMenu_SetText(yearDrop, tostring(curYear))
  UIDropDownMenu_Initialize(yearDrop, function(self, level)
    for yv = curYear-2, curYear+2 do
      local info = UIDropDownMenu_CreateInfo()
      info.text  = tostring(yv)
      info.func  = function()
        sel.year = yv
        UIDropDownMenu_SetText(yearDrop, info.text)
        -- day may need clamp on leap year changes
        local maxd = daysInMonth(sel.year, sel.month)
        if sel.day > maxd then sel.day = maxd end
        UIDropDownMenu_SetText(dayDrop, tostring(sel.day))
      end
      UIDropDownMenu_AddButton(info)
    end
  end)

  -- Month (stack 2)
  local monthLbl = p:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
  monthLbl:SetPoint('TOPLEFT', yearDrop, 'BOTTOMLEFT', 12, -10)
  monthLbl:SetText('Month:')

  local monthDrop = CreateFrame('Frame', nil, p, 'UIDropDownMenuTemplate')
  monthDrop:SetPoint('TOPLEFT', monthLbl, 'BOTTOMLEFT', -12, -2)
  UIDropDownMenu_SetWidth(monthDrop, 140)
  UIDropDownMenu_SetText(monthDrop, date('%B', time({year=sel.year, month=sel.month, day=1})))
  UIDropDownMenu_Initialize(monthDrop, function(self, level)
    for m=1,12 do
      local info = UIDropDownMenu_CreateInfo()
      info.text  = date('%B', time({year=sel.year, month=m, day=1}))
      info.func  = function()
        sel.month = m
        UIDropDownMenu_SetText(monthDrop, info.text)
        local maxd = daysInMonth(sel.year, sel.month)
        if sel.day > maxd then sel.day = maxd end
        UIDropDownMenu_SetText(dayDrop, tostring(sel.day))
      end
      UIDropDownMenu_AddButton(info)
    end
  end)

  -- Day (stack 3)
  local dayLbl = p:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
  dayLbl:SetPoint('TOPLEFT', monthDrop, 'BOTTOMLEFT', 12, -10)
  dayLbl:SetText('Day:')

  local function initDayDrop()
    UIDropDownMenu_Initialize(dayDrop, function(self, level)
      local maxd = daysInMonth(sel.year, sel.month)
      for d=1,maxd do
        local info = UIDropDownMenu_CreateInfo()
        info.text  = tostring(d)
        info.func  = function()
          sel.day = d
          UIDropDownMenu_SetText(dayDrop, tostring(sel.day))
        end
        UIDropDownMenu_AddButton(info)
      end
    end)
  end

  local dayDrop = CreateFrame('Frame', nil, p, 'UIDropDownMenuTemplate')
  dayDrop:SetPoint('TOPLEFT', dayLbl, 'BOTTOMLEFT', -12, -2)
  UIDropDownMenu_SetWidth(dayDrop, 90)
  UIDropDownMenu_SetText(dayDrop, tostring(curDay))
  initDayDrop()

  -- Time (HH:MM)
  local timeLbl = p:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
  timeLbl:SetPoint('TOPLEFT', dayDrop, 'BOTTOMLEFT', 12, -10)
  timeLbl:SetText('Time (24h):')

  local timeEdit = CreateFrame('EditBox', nil, p, 'InputBoxTemplate')
  timeEdit:SetSize(90,24)
  timeEdit:SetPoint('TOPLEFT', timeLbl, 'BOTTOMLEFT', 0, -2)
  timeEdit:SetAutoFocus(false)
  timeEdit:SetText('20:00')

  -- Instance
  local instLbl = p:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
  instLbl:SetPoint('TOPLEFT', timeEdit, 'BOTTOMLEFT', 0, -10)
  instLbl:SetText('Instance:')

  local instanceDrop = CreateFrame('Frame', 'GTR_InstanceDrop', p, 'UIDropDownMenuTemplate')
  instanceDrop:SetPoint('TOPLEFT', instLbl, 'BOTTOMLEFT', -12, -2)
  UIDropDownMenu_SetWidth(instanceDrop, 220)
  UIDropDownMenu_SetText(instanceDrop, 'Karazhan')
  UIDropDownMenu_Initialize(instanceDrop, function(self, level)
    for _,inst in ipairs(INSTANCES) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = inst
      info.func = function() UIDropDownMenu_SetText(instanceDrop, inst) end
      UIDropDownMenu_AddButton(info)
    end
  end)

  -- Size (kept, but no longer enforces caps during signup)
  local sizeLbl = p:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
  sizeLbl:SetPoint('TOPLEFT', instanceDrop, 'BOTTOMLEFT', 12, -10)
  sizeLbl:SetText('Raid Size (label only):')

  local sizeDrop = CreateFrame('Frame', 'GTR_SizeDrop', p, 'UIDropDownMenuTemplate')
  sizeDrop:SetPoint('TOPLEFT', sizeLbl, 'BOTTOMLEFT', -12, -2)
  UIDropDownMenu_SetWidth(sizeDrop, 120)
  UIDropDownMenu_SetText(sizeDrop, '10')
  UIDropDownMenu_Initialize(sizeDrop, function(self, level)
    for _,sz in ipairs({10,25,40}) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = tostring(sz)
      info.func = function() UIDropDownMenu_SetText(sizeDrop, tostring(sz)) end
      UIDropDownMenu_AddButton(info)
    end
  end)

  -- Create button
  local createBtn = CreateFrame('Button', nil, p, 'UIPanelButtonTemplate')
  createBtn:SetSize(140,24)
  createBtn:SetPoint('TOPLEFT', sizeDrop, 'BOTTOMLEFT', 12, -14)
  createBtn:SetText('Create')
  createBtn:SetScript('OnClick', function()
    if not U:HasPermission(GT.db.permissions.raidsMinRank) then
      UIErrorsFrame:AddMessage('Insufficient rank to create raids',1,0,0)
      return
    end
    -- Re-init day dropdown to match current month/year before reading it
    initDayDrop()

    local hh,mm = timeEdit:GetText():match('^(%d+):(%d+)$')
    hh, mm = tonumber(hh or '20'), tonumber(mm or '00')
    if not hh or not mm or hh > 23 or mm > 59 then
      UIErrorsFrame:AddMessage('Invalid time. Use HH:MM (24h).',1,0,0)
      return
    end

    local ts = time({year=sel.year, month=sel.month, day=sel.day, hour=hh, min=mm, sec=0})
    createEvent(nameEdit:GetText(), ts, UIDropDownMenu_GetText(instanceDrop), tonumber(UIDropDownMenu_GetText(sizeDrop)))
    R:Refresh()
  end)

  -- Listing area
  local list = CreateFrame('Frame', nil, p, 'InsetFrameTemplate3')
  list:SetPoint('TOPLEFT', 20, -360)        -- pushed lower to fit stacked selectors
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
  for _,e in pairs(GT.db.events) do table.insert(arr, e) end
  table.sort(arr, function(a,b) return a.ts < b.ts end)
  return arr
end

-- === Raid Composition Editor ===
R.Comp = R.Comp or {}
local Comp = R.Comp

function Comp:Open(event)
  if not Comp.frame then
    local f = CreateFrame('Frame', 'GuildToolsCompFrame', UIParent, 'BasicFrameTemplateWithInset')
    f:SetSize(700, 420)
    f:SetPoint('CENTER')
    f:SetFrameStrata('DIALOG')
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag('LeftButton')
    f:SetScript('OnDragStart', f.StartMoving)
    f:SetScript('OnDragStop', f.StopMovingOrSizing)
    f:SetScript('OnShow', function(self) self:Raise() end)
    f:Hide()

    f.title = f:CreateFontString(nil,'OVERLAY','GameFontHighlight')
    f.title:SetPoint('LEFT', f.TitleBg, 'LEFT', 6, 0)

    local list = CreateFrame('Frame', nil, f, 'InsetFrameTemplate3')
    list:SetPoint('TOPLEFT', 12, -60)
    list:SetPoint('BOTTOMLEFT', 12, 12)
    list:SetWidth(320)
    local scroll = CreateFrame('ScrollFrame', 'GTR_COMP_SCROLL', list, 'UIPanelScrollFrameTemplate')
    scroll:SetPoint('TOPLEFT', 8, -8)
    scroll:SetPoint('BOTTOMRIGHT', -28, 8)
    local content = CreateFrame('Frame', nil, scroll)
    content:SetSize(1,1)
    scroll:SetScrollChild(content)
    f.signupContent = content

    local right = CreateFrame('Frame', nil, f, 'InsetFrameTemplate3')
    right:SetPoint('TOPRIGHT', -12, -60)
    right:SetPoint('BOTTOMRIGHT', -12, 12)
    right:SetWidth(320)
    f.right = right

    local save = CreateFrame('Button', nil, f, 'UIPanelButtonTemplate')
    save:SetSize(140,24)
    save:SetPoint('TOPLEFT', 12, -28)
    save:SetText('Save & Broadcast')
    save:SetScript('OnClick', function()
      if Comp.event then
        GT.db.events[Comp.event.id] = Comp.event
        GT.db.dataVersion = (GT.db.dataVersion or 1) + 1
        if GT.Comm then GT.Comm:Send('EVENT_UPDATE', U:Serialize(Comp.event)) end
      end
      f:Hide()
    end)

    Comp.frame = f
  end
  Comp.event = event
  Comp.frame.title:SetText('Raid Composition — '..(event.title or 'Event'))
  Comp:Refresh()
  Comp.frame:Show()
  Comp.frame:Raise()
end

local function classColor(class)
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return 1,1,1
end

function Comp:Refresh()
  local f = Comp.frame; if not f or not Comp.event then return end
  local e = Comp.event
  e.comp = e.comp or {}

  for _,child in ipairs({f.signupContent:GetChildren()}) do child:Hide(); child:SetParent(nil) end
  local y = -4
  for name, s in pairs(e.signups or {}) do
    local row = CreateFrame('Frame', nil, f.signupContent)
    row:SetSize(280, 22)
    row:SetPoint('TOPLEFT', 4, y)
    local r,g,b = classColor(s.class)
    local txt = row:CreateFontString(nil,'OVERLAY','GameFontHighlight')
    txt:SetPoint('LEFT', 4, 0)
    txt:SetText(string.format('|cff%02x%02x%02x%s|r (%s)', r*255, g*255, b*255, name, s.role))

    local dd = CreateFrame('Frame', nil, row, 'UIDropDownMenuTemplate')
    dd:SetPoint('LEFT', txt, 'RIGHT', 8, 0)
    UIDropDownMenu_SetWidth(dd, 100)
    UIDropDownMenu_SetText(dd, e.comp[name] and ('Group '..e.comp[name]) or 'Unassigned')
    UIDropDownMenu_Initialize(dd, function(self, level)
      local function add(label, value)
        local info = UIDropDownMenu_CreateInfo()
        info.text=label
        info.func=function()
          e.comp[name] = value
          UIDropDownMenu_SetText(dd, value and ('Group '..value) or 'Unassigned')
          Comp:RefreshRight()
        end
        UIDropDownMenu_AddButton(info)
      end
      add('Unassigned', nil)
      local maxGroups = (e.size and e.size>=25) and 8 or 5
      for g=1,maxGroups do add('Group '..g, g) end
    end)
    y = y - 24
  end
  f.signupContent:SetHeight(-y + 10)
  Comp:RefreshRight()
end

function Comp:RefreshRight()
  local right = Comp.frame.right; local e = Comp.event
  for _,child in ipairs({right:GetChildren()}) do child:Hide(); child:SetParent(nil) end
  local maxGroups = (e.size and e.size>=25) and 8 or 5
  local y = -8
  for g=1,maxGroups do
    local header = right:CreateFontString(nil,'OVERLAY','GameFontNormal')
    header:SetPoint('TOPLEFT', 8, y)
    header:SetText('Group '..g)
    y = y - 18
    for name, grp in pairs(e.comp or {}) do
      if grp == g then
        local s = e.signups[name]
        local r,gc,b = 1,1,1
        if s and s.class then r,gc,b = classColor(s.class) end
        local line = right:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
        line:SetPoint('TOPLEFT', 16, y)
        line:SetText(string.format('|cff%02x%02x%02x%s|r', r*255, gc*255, b*255, name))
        y = y - 14
      end
    end
    y = y - 6
  end
end

function R:Refresh()
  if not R.parent then return end
  local content = R.parent.content
  for _,child in ipairs({content:GetChildren()}) do child:Hide(); child:SetParent(nil) end

  local y = -5
  for _,e in ipairs(getSortedEvents()) do
    local box = CreateFrame('Frame', nil, content, 'InsetFrameTemplate3')
    box:SetSize(800, 140)
    box:SetPoint('TOPLEFT', 5, y)

    local title = box:CreateFontString(nil,'OVERLAY','GameFontNormal')
    title:SetPoint('TOPLEFT', 10, -8)
    title:SetText(string.format('%s  |  %s  |  %s  |  %d-man', e.title, e.instance, date('%b %d %H:%M', e.ts), e.size))

    -- Unlimited signup view: show current counts only (no caps)
    local counts = {tanks=0, heals=0, dps=0}
    for _,s in pairs(e.signups) do counts[s.role] = (counts[s.role] or 0)+1 end
    local status = box:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    status:SetPoint('TOPRIGHT', -10, -10)
    status:SetText(string.format('T:%d  H:%d  D:%d', counts.tanks or 0, counts.heals or 0, counts.dps or 0))

    local detailsBtn = CreateFrame('Button', nil, box, 'UIPanelButtonTemplate')
    detailsBtn:SetSize(70,20)
    detailsBtn:SetPoint('TOPLEFT', 10, -28)
    detailsBtn:SetText('Details')
    box.detailsShown = false
    detailsBtn:SetScript('OnClick', function()
      box.detailsShown = not box.detailsShown
      detailsBtn:SetText(box.detailsShown and 'Hide' or 'Details')
      if box.detailFrame then box.detailFrame:SetShown(box.detailsShown) end
    end)

    local df = CreateFrame('Frame', nil, box)
    df:SetPoint('TOPLEFT', 10, -50)
    df:SetPoint('TOPRIGHT', -10, -50)
    df:SetHeight(44)
    df:Hide()
    box.detailFrame = df

    local function addRole(label, key, xOfs)
      local hdr = df:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
      hdr:SetPoint('TOPLEFT', xOfs, 0)
      hdr:SetText(label..':')
      local line = df:CreateFontString(nil,'OVERLAY','GameFontDisableSmall')
      line:SetPoint('TOPLEFT', xOfs, -14)
      local names = {}
      for name,s in pairs(e.signups) do if s.role==key then table.insert(names, name) end end
      table.sort(names)
      line:SetText(table.concat(names, ', '))
    end
    addRole('Tanks','tanks', 0)
    addRole('Heals','heals', 220)
    addRole('DPS','dps', 440)

    -- Role sign buttons (unlimited)
    local roles = {'tanks','heals','dps'}
    for i,role in ipairs(roles) do
      local b = CreateFrame('Button', nil, box, 'UIPanelButtonTemplate')
      b:SetSize(100,22)
      b:SetPoint('BOTTOMLEFT', 10+(i-1)*110, 38)
      b:SetText('Sign '..string.upper(role:sub(1,1)))
      b:SetScript('OnClick', function()
        local name = UnitName('player')
        local _, class = UnitClass('player')
        e.signups[name] = { player=name, class=class, role=role }
        GT.db.dataVersion = (GT.db.dataVersion or 1) + 1
        if GT.Comm then GT.Comm:Send('EVENT_UPDATE', U:Serialize(e)) end
        if Log then Log:Add('INFO','EVENT','Signup '..name..' as '..role) end
        R:Refresh()
      end)
    end

    if U:HasPermission(GT.db.permissions.raidsMinRank) then
      local build = CreateFrame('Button', nil, box, 'UIPanelButtonTemplate')
      build:SetSize(140,22)
      build:SetPoint('BOTTOMRIGHT', -10, 10)
      build:SetText('Build Raid Comp')
      build:SetScript('OnClick', function() Comp:Open(e) end)

      local edit = CreateFrame('Button', nil, box, 'UIPanelButtonTemplate')
      edit:SetSize(80,22)
      edit:SetPoint('BOTTOMRIGHT', -160, 10)
      edit:SetText('Edit')
      edit:SetScript('OnClick', function()
        StaticPopupDialogs['GTR_EDIT_TITLE'] = {
          text='Set new title:', button1='Save', button2='Cancel', hasEditBox=true, timeout=0, whileDead=true, hideOnEscape=true,
          OnAccept=function(d)
            e.title = d.editBox:GetText() or e.title
            if GT.Comm then GT.Comm:Send('EVENT_UPDATE', U:Serialize(e)) end
            if Log then Log:Add('INFO','EVENT','Renamed event '..e.id..' to '..e.title) end
            R:Refresh()
          end
        }
        local dlg = StaticPopup_Show('GTR_EDIT_TITLE')
        if dlg and dlg.editBox then dlg.editBox:SetText(e.title or '') end
      end)

      local del = CreateFrame('Button', nil, box, 'UIPanelButtonTemplate')
      del:SetSize(80,22)
      del:SetPoint('BOTTOMRIGHT', -260, 10)
      del:SetText('Delete')
      del:SetScript('OnClick', function()
        StaticPopupDialogs['GTR_DEL_EVT'] = {
          text='Delete this event?', button1='Yes', button2='No', timeout=0, whileDead=true, hideOnEscape=true,
          OnAccept=function()
            GT.db.events[e.id] = nil
            if GT.Comm then GT.Comm:Send('EVENT_DELETE', U:Serialize({id=e.id})) end
            if Log then Log:Add('INFO','EVENT','Deleted event '..e.id) end
            R:Refresh()
          end
        }
        StaticPopup_Show('GTR_DEL_EVT')
      end)
    end

    y = y - 150
  end
  content:SetHeight(-y + 20)

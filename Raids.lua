local GT  = GuildTools
local U   = GT.Utils
local Log = GT.Log

GT.Raids = GT.Raids or {}
local R = GT.Raids

-- Fallback list used only if Encounter Journal APIs are unavailable
local FALLBACK_RAIDS = {
  'Karazhan','Gruul\'s Lair','Magtheridon\'s Lair','Serpentshrine Cavern','Tempest Keep: The Eye','Hyjal Summit','Black Temple','Zul\'Aman','Sunwell Plateau',
  'Molten Core','Blackwing Lair','Ahn\'Qiraj 40','Ruins of Ahn\'Qiraj','Naxxramas'
}

-- Dynamically enumerate raid instances using Encounter Journal.
-- This works on modern clients that expose EJ_* APIs. If unavailable,
-- we return the fallback list above.
local function GetAvailableRaids()
  local result = {}

  -- Some clients require the EJ add-on to be loaded before EJ_* calls return data.
  if not _G.EJ_GetInstanceByIndex then
    -- Encounter Journal API not present: Classic-era or older client
    for _,name in ipairs(FALLBACK_RAIDS) do
      table.insert(result, { name = name, id = 0 })
    end
    return result
  end

  if not IsAddOnLoaded("Blizzard_EncounterJournal") and C_AddOns and C_AddOns.LoadAddOn then
    C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
  elseif not IsAddOnLoaded("Blizzard_EncounterJournal") and LoadAddOn then
    pcall(LoadAddOn, "Blizzard_EncounterJournal")
  end

  -- Enumerate all raid instances (isRaid=true)
  local i = 1
  while true do
    local name, _, id = EJ_GetInstanceByIndex(i, true)  -- true => raid instances
    if not name then break end
    table.insert(result, { name = name, id = id })
    i = i + 1
  end

  -- Fallback if nothing was returned (edge cases)
  if #result == 0 then
    for _,name in ipairs(FALLBACK_RAIDS) do
      table.insert(result, { name = name, id = 0 })
    end
  end

  return result
end

-- CHANGED previously: no size, no role caps — unlimited signups
local function createEvent(title, ts, instance)
  local id = U:NewId('evt')
  local e = {
    id       = id,
    title    = title or 'Raid',
    ts       = ts or time(),
    instance = instance or 'Karazhan',
    roles    = {},     -- informational only; no caps
    signups  = {},
    comp     = {},
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
  local title = p:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
  title:SetPoint('TOPLEFT',20,y)
  title:SetText('Create Raid Event')

  y = y - 30
  local nameEdit = CreateFrame('EditBox', nil, p, 'InputBoxTemplate')
  nameEdit:SetSize(220,24)
  nameEdit:SetPoint('TOPLEFT',20,y)
  nameEdit:SetAutoFocus(false)
  nameEdit:SetText('Raid Title')

  local dateEdit = CreateFrame('EditBox', nil, p, 'InputBoxTemplate')
  dateEdit:SetSize(140,24)
  dateEdit:SetPoint('LEFT', nameEdit, 'RIGHT', 10, 0)
  dateEdit:SetAutoFocus(false)
  dateEdit:SetText(date('%Y-%m-%d', time()+24*3600))

  local timeEdit = CreateFrame('EditBox', nil, p, 'InputBoxTemplate')
  timeEdit:SetSize(90,24)
  timeEdit:SetPoint('LEFT', dateEdit, 'RIGHT', 10, 0)
  timeEdit:SetAutoFocus(false)
  timeEdit:SetText('20:00')

  -- Instance dropdown (NOW DYNAMIC)
  local instanceDrop = CreateFrame('Frame', 'GTR_InstanceDrop', p, 'UIDropDownMenuTemplate')
  instanceDrop:SetPoint('LEFT', timeEdit, 'RIGHT', 10, 0)
  UIDropDownMenu_SetWidth(instanceDrop, 220)

  -- Build the dynamic instance list once per UI build
  local raidList = GetAvailableRaids()
  local defaultInstance = (raidList[1] and raidList[1].name) or 'Karazhan'
  UIDropDownMenu_SetText(instanceDrop, defaultInstance)

  UIDropDownMenu_Initialize(instanceDrop, function(self, level)
    for _,entry in ipairs(raidList) do
      local info = UIDropDownMenu_CreateInfo()
      info.text  = entry.name
      info.func  = function()
        UIDropDownMenu_SetText(instanceDrop, entry.name)
      end
      UIDropDownMenu_AddButton(info)
    end
  end)

  -- (Removed size and role-cap inputs earlier)

  local createBtn = CreateFrame('Button', nil, p, 'UIPanelButtonTemplate')
  createBtn:SetSize(120,24)
  createBtn:SetPoint('LEFT', instanceDrop, 'RIGHT', 10, 0)
  createBtn:SetText('Create')
  createBtn:SetScript('OnClick', function()
    if not U:HasPermission(GT.db.permissions.raidsMinRank) then
      UIErrorsFrame:AddMessage('Insufficient rank to create raids',1,0,0)
      return
    end
    local dateStr, timeStr = dateEdit:GetText(), timeEdit:GetText()
    local Y,M,D = dateStr:match('^(%d+)%-(%d+)%-(%d+)$')
    local hh,mm = timeStr:match('^(%d+):(%d+)$')
    local ts = time({
      year  = tonumber(Y),
      month = tonumber(M),
      day   = tonumber(D),
      hour  = tonumber(hh),
      min   = tonumber(mm),
      sec   = 0
    })
    local instName = UIDropDownMenu_GetText(instanceDrop)
    createEvent(nameEdit:GetText(), ts, instName)
    R:Refresh()
  end)

  -- Listing area
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
    f:SetSize(700,420)
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
    list:SetPoint('TOPLEFT',12,-60)
    list:SetPoint('BOTTOMLEFT',12,12)
    list:SetWidth(320)

    local scroll = CreateFrame('ScrollFrame', 'GTR_COMP_SCROLL', list, 'UIPanelScrollFrameTemplate')
    scroll:SetPoint('TOPLEFT',8,-8)
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
    save:SetPoint('TOPLEFT',12,-28)
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
  local f = Comp.frame
  if not f or not Comp.event then return end
  local e = Comp.event
  e.comp = e.comp or {}

  for _,child in ipairs({f.signupContent:GetChildren()}) do child:Hide(); child:SetParent(nil) end

  local y = -4
  for name,s in pairs(e.signups or {}) do
    local row = CreateFrame('Frame', nil, f.signupContent)
    row:SetSize(280,22)
    row:SetPoint('TOPLEFT',4,y)

    local r,g,b = classColor(s.class)
    local txt = row:CreateFontString(nil,'OVERLAY','GameFontHighlight')
    txt:SetPoint('LEFT',4,0)
    txt:SetText(string.format('|cff%02x%02x%02x%s|r (%s)', r*255,g*255,b*255,name,s.role))

    local dd = CreateFrame('Frame', nil, row, 'UIDropDownMenuTemplate')
    dd:SetPoint('LEFT', txt, 'RIGHT', 8, 0)
    UIDropDownMenu_SetWidth(dd,100)
    UIDropDownMenu_SetText(dd, e.comp[name] and ('Group '..e.comp[name]) or 'Unassigned')

    -- With size removed, default to 5 groups for composition
    UIDropDownMenu_Initialize(dd, function(self, level)
      local function add(label, val)
        local info = UIDropDownMenu_CreateInfo()
        info.text = label
        info.func = function()
          e.comp[name] = val
          UIDropDownMenu_SetText(dd, val and ('Group '..val) or 'Unassigned')
          Comp:RefreshRight()
        end
        UIDropDownMenu_AddButton(info)
      end
      add('Unassigned', nil)
      for g=1,5 do add('Group '..g, g) end
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
    local header = right:CreateFontString(nil,'OVERLAY','GameFontNormal')
    header:SetPoint('TOPLEFT', 8, y)
    header:SetText('Group '..g)
    y = y - 18

    for name,grp in pairs(e.comp or {}) do
      if grp == g then
        local s = e.signups[name]
        local r,gg,b = 1,1,1
        if s and s.class then r,gg,b = classColor(s.class) end
        local line = right:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
        line:SetPoint('TOPLEFT', 16, y)
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
    box:SetSize(800,140)
    box:SetPoint('TOPLEFT',5,y)

    local title = box:CreateFontString(nil,'OVERLAY','GameFontNormal')
    title:SetPoint('TOPLEFT',10,-8)
    title:SetText(string.format('%s  |  %s  |  %s', e.title, e.instance, date('%b %d %H:%M', e.ts)))

    local counts = {tanks=0,heals=0,dps=0}
    for _,s in pairs(e.signups) do counts[s.role] = (counts[s.role] or 0) + 1 end

    local status = box:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    status:SetPoint('TOPRIGHT',-10,-10)
    status:SetText(string.format('T:%d  H:%d  D:%d', counts.tanks or 0, counts.heals or 0, counts.dps or 0))

    local detailsBtn = CreateFrame('Button', nil, box, 'UIPanelButtonTemplate')
    detailsBtn:SetSize(70,20)
    detailsBtn:SetPoint('TOPLEFT',10,-28)
    detailsBtn:SetText('Details')
    box.detailsShown=false
    detailsBtn:SetScript('OnClick', function()
      box.detailsShown = not box.detailsShown
      if box.detailsShown then detailsBtn:SetText('Hide') else detailsBtn:SetText('Details') end
      if box.detailFrame then box.detailFrame:SetShown(box.detailsShown) end
    end)

    local df = CreateFrame('Frame', nil, box)
    df:SetPoint('TOPLEFT',10,-50)
    df:SetPoint('TOPRIGHT', -10, -50)
    df:SetHeight(44)
    df:Hide()
    box.detailFrame = df

    local function addRole(label,key,x)
      local hdr = df:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
      hdr:SetPoint('TOPLEFT',x,0)
      hdr:SetText(label..':')
      local line = df:CreateFontString(nil,'OVERLAY','GameFontDisableSmall')
      line:SetPoint('TOPLEFT',x,-14)
      local names = {}
      for name,s in pairs(e.signups) do if s.role==key then table.insert(names,name) end end
      table.sort(names)
      line:SetText(table.concat(names, ', '))
    end
    addRole('Tanks','tanks',0)
    addRole('Heals','heals',220)
    addRole('DPS','dps',440)

    local roles={'tanks','heals','dps'}
    for i,role in ipairs(roles) do
      local b = CreateFrame('Button', nil, box, 'UIPanelButtonTemplate')
      b:SetSize(100,22)
      b:SetPoint('BOTTOMLEFT',10+(i-1)*110,38)
      b:SetText('Sign '..string.upper(role:sub(1,1)))
      b:SetScript('OnClick', function()
        local name = UnitName('player')
        local _,class = UnitClass('player')
        e.signups[name] = { player=name, class=class, role=role }
        GT.db.dataVersion = (GT.db.dataVersion or 1) + 1
        if GT.Comm then GT.Comm:Send('EVENT_UPDATE', U:Serialize(e)) end
        if Log then Log:Add('INFO','EVENT','Signup '..name..' as '..role) end
        R:Refresh()
      end)
    end

    if U:HasPermission(GT.db.permissions.raidsMinRank) then
      local build=CreateFrame('Button', nil, box, 'UIPanelButtonTemplate')
      build:SetSize(140,22)
      build:SetPoint('BOTTOMRIGHT', -10, 10)
      build:SetText('Build Raid Comp')
      build:SetScript('OnClick', function() Comp:Open(e) end)

      local edit=CreateFrame('Button', nil, box, 'UIPanelButtonTemplate')
      edit:SetSize(80,22)
      edit:SetPoint('BOTTOMRIGHT', -160, 10)
      edit:SetText('Edit')
      edit:SetScript('OnClick', function()
        StaticPopupDialogs['GTR_EDIT_TITLE']={
          text='Set new title:', button1='Save', button2='Cancel', hasEditBox=true, timeout=0, whileDead=true, hideOnEscape=true,
          OnAccept=function(d)
            e.title = d.editBox:GetText() or e.title
            if GT.Comm then GT.Comm:Send('EVENT_UPDATE', U:Serialize(e)) end
            if Log then Log:Add('INFO','EVENT','Renamed event '..e.id..' to '..e.title) end
            R:Refresh()
          end
        }
        local dlg=StaticPopup_Show('GTR_EDIT_TITLE')
        if dlg and dlg.editBox then dlg.editBox:SetText(e.title or '') end
      end)

      local del=CreateFrame('Button', nil, box, 'UIPanelButtonTemplate')
      del:SetSize(80,22)
      del:SetPoint('BOTTOMRIGHT', -260, 10)
      del:SetText('Delete')
      del:SetScript('OnClick', function()
        StaticPopupDialogs['GTR_DEL_EVT']={
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

  content:SetHeight(-y+20)
end

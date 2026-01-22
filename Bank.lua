local GT = GuildTools
local U = GT.Utils
local Log = GT.Log
GT.Bank = GT.Bank or {}
local B = GT.Bank

function B:BuildUI(parent)
  local p = CreateFrame('Frame', nil, parent) p:SetAllPoints(true) B.parent=p
  local title = p:CreateFontString(nil,'OVERLAY','GameFontNormalLarge') title:SetPoint('TOPLEFT',20,-20) title:SetText('Guild Bank Requests')
  local item = CreateFrame('EditBox', nil, p, 'InputBoxTemplate') item:SetSize(260,24) item:SetPoint('TOPLEFT',20,-60) item:SetAutoFocus(false) item:SetText('Item link or name')
  local qty = CreateFrame('EditBox', nil, p, 'InputBoxTemplate') qty:SetSize(60,24) qty:SetPoint('LEFT', item, 'RIGHT', 10, 0) qty:SetNumeric(true) qty:SetNumber(1)
  local note = CreateFrame('EditBox', nil, p, 'InputBoxTemplate') note:SetSize(220,24) note:SetPoint('LEFT', qty, 'RIGHT', 10, 0) note:SetAutoFocus(false) note:SetText('Reason / Note')
  local send = CreateFrame('Button', nil, p, 'UIPanelButtonTemplate') send:SetSize(120,24) send:SetPoint('LEFT', note, 'RIGHT', 10, 0) send:SetText('Request')
  send:SetScript('OnClick', function()
    local id = U:NewId('req') local req = { id=id, player=UnitName('player'), itemLink=item:GetText(), qty=qty:GetNumber(), note=note:GetText(), status='PENDING' }
    GT.db.bankRequests[id] = req GT.db.dataVersion = (GT.db.dataVersion or 1) + 1 if GT.Comm then GT.Comm:Send('BANK_UPDATE', U:Serialize(req)) end if Log then Log:Add('INFO','BANK','Created request '..(item:GetText() or 'Item')..' x'..qty:GetNumber()) end B:Refresh()
  end)
  local list = CreateFrame('Frame', nil, p, 'InsetFrameTemplate3') list:SetPoint('TOPLEFT', 20, -100) list:SetPoint('BOTTOMRIGHT', -20, 20)
  local scroll = CreateFrame('ScrollFrame', 'GTB_Scroll', list, 'UIPanelScrollFrameTemplate') scroll:SetPoint('TOPLEFT',10,-10) scroll:SetPoint('BOTTOMRIGHT', -30, 10)
  local content = CreateFrame('Frame', nil, scroll) content:SetSize(1,1) scroll:SetScrollChild(content) p.content=content B:Refresh()
end

local function sorted() local a={} for _,r in pairs(GT.db.bankRequests) do a[#a+1]=r end table.sort(a,function(x,y) return x.id<y.id end) return a end

function B:Refresh()
  if not B.parent then return end local content=B.parent.content for _,c in ipairs({content:GetChildren()}) do c:Hide(); c:SetParent(nil) end
  local y=-5
  for _,r in ipairs(sorted()) do
    local box=CreateFrame('Frame', nil, content, 'InsetFrameTemplate3') box:SetSize(800,64) box:SetPoint('TOPLEFT',5,y)
    local line=box:CreateFontString(nil,'OVERLAY','GameFontHighlight') line:SetPoint('TOPLEFT',10,-8) line:SetText(string.format('%s x%d — %s (%s) [%s]', r.itemLink or 'Item', r.qty or 1, r.player or '?', r.note or '', r.status))
    if U:HasPermission(GT.db.permissions.bankMinRank) then
      local approve=CreateFrame('Button', nil, box, 'UIPanelButtonTemplate') approve:SetSize(80,22) approve:SetPoint('BOTTOMRIGHT', -90, 8) approve:SetText('Approve') approve:SetScript('OnClick', function() r.status='APPROVED'; GT.db.dataVersion=(GT.db.dataVersion or 1)+1; if GT.Comm then GT.Comm:Send('BANK_UPDATE', U:Serialize(r)) end; if Log then Log:Add('INFO','BANK','Approved '..(r.itemLink or 'item')) end; B:Refresh() end)
      local deny=CreateFrame('Button', nil, box, 'UIPanelButtonTemplate') deny:SetSize(80,22) deny:SetPoint('BOTTOMRIGHT', -5, 8) deny:SetText('Deny') deny:SetScript('OnClick', function() r.status='DENIED'; GT.db.dataVersion=(GT.db.dataVersion or 1)+1; if GT.Comm then GT.Comm:Send('BANK_UPDATE', U:Serialize(r)) end; if Log then Log:Add('INFO','BANK','Denied '..(r.itemLink or 'item')) end; B:Refresh() end)
    end
    y=y-74
  end
  content:SetHeight(-y+20)
end
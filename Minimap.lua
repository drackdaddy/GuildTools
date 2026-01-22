local GT = GuildTools
GT.Minimap = GT.Minimap or {}
local M = GT.Minimap
local Log = GT.Log

local function setPos(btn, angle)
  if not btn or not btn:GetParent() then return end
  local parent = btn:GetParent()
  local w = parent:GetWidth() or 140
  local h = parent:GetHeight() or 140
  local rx, ry = (w/2), (h/2)
  local pad = 8
  local rad = math.rad(angle or 200)
  local x = (rx + pad) * math.cos(rad)
  local y = (ry + pad) * math.sin(rad)
  btn:ClearAllPoints()
  btn:SetPoint('CENTER', parent, 'CENTER', x, y)
end

function M:Create()
  if M.button and M.button.GetParent then
    if GT.db and GT.db.minimap and not GT.db.minimap.hide then setPos(M.button, GT.db.minimap.angle or 200) M.button:Show() else M.button:Hide() end
    return
  end
  local parent = Minimap or _G.Minimap or UIParent if not parent then return end
  local btn = CreateFrame('Button', 'GuildTools_MinimapButton', parent) btn:SetSize(32,32) btn:SetFrameStrata('HIGH') btn:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')
  local icon = btn:CreateTexture(nil, 'ARTWORK') icon:SetTexture('Interface\\AddOns\\GuildTools\\Media\\gticon.png') icon:SetSize(22,22) icon:SetPoint('CENTER', 0, 0) btn.icon = icon
  btn:RegisterForDrag('LeftButton') btn:SetScript('OnDragStart', function(self) self:LockHighlight() self:SetScript('OnUpdate', function(self) local p=self:GetParent() local px,py=p:GetCenter() local cx,cy=GetCursorPosition() local scale=UIParent:GetScale()/(p.GetEffectiveScale and p:GetEffectiveScale() or UIParent:GetEffectiveScale()) cx,cy=cx/scale,cy/scale local ang=math.deg(math.atan2(cy-py,cx-px)) GT.db=GT.db or { minimap = {} } GT.db.minimap=GT.db.minimap or {} GT.db.minimap.angle=ang setPos(self, ang) end) end)
  btn:SetScript('OnDragStop', function(self) self:UnlockHighlight() self:SetScript('OnUpdate', nil) end)
  btn:SetScript('OnClick', function() if Log then Log:Add('INFO','UI','Minimap toggle') end if GT.UI and GT.UI.Toggle then GT.UI:Toggle() end end)
  btn:SetScript('OnEnter', function(self) GameTooltip:SetOwner(self, 'ANCHOR_LEFT') GameTooltip:AddLine('GuildTools') GameTooltip:AddLine('Left-Drag: Move',1,1,1) GameTooltip:AddLine('Left-Click: Toggle',1,1,1) GameTooltip:Show() end)
  btn:SetScript('OnLeave', function() GameTooltip:Hide() end)
  M.button = btn
  local angle = (GT.db and GT.db.minimap and GT.db.minimap.angle) or 200 setPos(btn, angle)
  if GT.db and GT.db.minimap and GT.db.minimap.hide then btn:Hide() else btn:Show() end
end
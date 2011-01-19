
local timers = {}
local timersFocus = {}
local timersPlayer = {}
local MAX_TIMERS = 15
local ICON_SIZE = 20
local BAR_ADJUST = 25
local BAR_TEXT = "llllllllllllllllllllllllllllllllllllllll"
local band = bit.band

local targetGUID = 0
local focusGUID = 0
local playerGUID = 0
local UnitAura = UnitAura
local UnitIsUnit = UnitIsUnit
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitIsEnemy = UnitIsEnemy
local UnitIsFriend = UnitIsFriend

local pointT = {
	["target"] = "XAT_Anchor",
	["focus"] = "XAT_FocusAnchor",
	["player"] = "XAT_PlayerAnchor",
}

local f = CreateFrame("frame","xanAuraTimers",UIParent)
f:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)

----------------------
--      Enable      --
----------------------
	
function f:PLAYER_LOGIN()

	--load up the database
	if not XAT_DB then XAT_DB = {} end
	if XAT_DB.scale == nil then XAT_DB.scale = 1 end
	if XAT_DB.grow == nil then XAT_DB.grow = false end
	if XAT_DB.sort == nil then XAT_DB.sort = false end
	if XAT_DB.auras == nil then XAT_DB.auras = false end
	if XAT_DB.filterBuff == nil then XAT_DB.filterBuff = false end
	if XAT_DB.filterDebuff == nil then XAT_DB.filterDebuff = false end
	if XAT_DB.debuffs == nil then XAT_DB.debuffs = {} end
	if XAT_DB.buffs == nil then XAT_DB.buffs = {} end
	
	--get player GUID
	playerGUID = UnitGUID("player")
	
	--create our anchors
	f:CreateAnchor("XAT_Anchor", UIParent, "xanAuraTimers: Target Anchor")
	f:CreateAnchor("XAT_FocusAnchor", UIParent, "xanAuraTimers: Focus Anchor")
	f:CreateAnchor("XAT_PlayerAnchor", UIParent, "xanAuraTimers: Player Anchor")
	
	f:UnregisterEvent("PLAYER_LOGIN")
	f.PLAYER_LOGIN = nil
	
	f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	f:RegisterEvent("PLAYER_TARGET_CHANGED")
	f:RegisterEvent("PLAYER_FOCUS_CHANGED")

	SLASH_XANBUFFTIMERS1 = "/xanauratimers"
	SLASH_XANBUFFTIMERS2 = "/xat"
	SlashCmdList["XANBUFFTIMERS"] = function(msg)
	
		local a,b,c=strfind(msg, "(%S+)"); --contiguous string of non-space characters
		
		if a then
			if c and c:lower() == "anchor" then
				if XAT_Anchor:IsVisible() then
					XAT_Anchor:Hide()
					XAT_FocusAnchor:Hide()
					XAT_PlayerAnchor:Hide()
				else
					XAT_Anchor:Show()
					XAT_FocusAnchor:Show()
					XAT_PlayerAnchor:Show()
				end
				return true
			elseif c and c:lower() == "scale" then
				if b then
					local scalenum = strsub(msg, b+2)
					if scalenum and scalenum ~= "" and tonumber(scalenum) then
						XAT_DB.scale = tonumber(scalenum)
						for i=1, MAX_TIMERS do
							if timers[i] then
								timers[i]:SetScale(tonumber(scalenum))
							end
							if timersFocus[i] then
								timersFocus[i]:SetScale(tonumber(scalenum))
							end
						end
						for i=1, #timersPlayer do
							timersPlayer[i]:SetScale(tonumber(scalenum))
						end
						DEFAULT_CHAT_FRAME:AddMessage("xanAuraTimers: Scale has been set to ["..tonumber(scalenum).."]")
						return true
					end
				end
			elseif c and c:lower() == "grow" then
				if XAT_DB.grow then
					XAT_DB.grow = false
					DEFAULT_CHAT_FRAME:AddMessage("xanAuraTimers: Bars will now grow [|cFF99CC33UP|r]")
				else
					XAT_DB.grow = true
					DEFAULT_CHAT_FRAME:AddMessage("xanAuraTimers: Bars will now grow [|cFF99CC33DOWN|r]")
				end
				return true
			elseif c and c:lower() == "sort" then
				if XAT_DB.sort then
					XAT_DB.sort = false
					DEFAULT_CHAT_FRAME:AddMessage("xanAuraTimers: Bars sort [|cFF99CC33DESCENDING|r]")
				else
					XAT_DB.sort = true
					DEFAULT_CHAT_FRAME:AddMessage("xanAuraTimers: Bars sort [|cFF99CC33ASCENDING|r]")
				end
				return true
			elseif c and c:lower() == "auras" then
				if XAT_DB.auras then
					XAT_DB.auras = false
					DEFAULT_CHAT_FRAME:AddMessage("xanAuraTimers: Buff Auras [|cFF99CC33OFF|r]")
				else
					XAT_DB.auras = true
					DEFAULT_CHAT_FRAME:AddMessage("xanAuraTimers: Buff Auras [|cFF99CC33ON|r]")
				end
				--update the buff display
				if UnitName("target") and UnitGUID("target") then
					targetGUID = UnitGUID("target")
					f:ProcessAuras("target", timers)
				end
				if UnitName("focus") and UnitGUID("focus") then
					focusGUID = UnitGUID("focus")
					f:ProcessAuras("focus", timersFocus)
				end
				return true
			end
		end

		DEFAULT_CHAT_FRAME:AddMessage("xanAuraTimers")
		DEFAULT_CHAT_FRAME:AddMessage("/xat anchor - toggles a movable anchor")
		DEFAULT_CHAT_FRAME:AddMessage("/xat scale # - sets the scale size of the bars")
		DEFAULT_CHAT_FRAME:AddMessage("/xat grow - changes the direction in which the bars grow (UP/DOWN)")
		DEFAULT_CHAT_FRAME:AddMessage("/xat sort - changes the sorting of the bars. (ASCENDING/DESCENDING)")
		DEFAULT_CHAT_FRAME:AddMessage("/xat auras - toggles the display of permenate/non-cancel auras (ON/OFF)")
	end
	
	local ver = tonumber(GetAddOnMetadata("xanAuraTimers","Version")) or 'Unknown'
	DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33xanAuraTimers|r [v|cFFDF2B2B"..ver.."|r] loaded: /xat")
end
	
function f:PLAYER_TARGET_CHANGED()
	if UnitName("target") and UnitGUID("target") then
		targetGUID = UnitGUID("target")
		f:ProcessAuras("target", timers)
	else
		f:ClearAuras(timers)
		targetGUID = 0
	end
end

function f:PLAYER_FOCUS_CHANGED()
	if UnitName("focus") and UnitGUID("focus") then
		focusGUID = UnitGUID("focus")
		f:ProcessAuras("focus", timersFocus)
	else
		f:ClearAuras(timersFocus)
		focusGUID = 0
	end
end

local eventSwitch = {
	["SPELL_AURA_APPLIED"] = true,
	["SPELL_AURA_REMOVED"] = true,
	["SPELL_AURA_REFRESH"] = true,
	["SPELL_AURA_APPLIED_DOSE"] = true,
	["SPELL_AURA_APPLIED_REMOVED_DOSE"] = true,
}

function f:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellID, spellName, spellSchool, auraType, amount)

    if eventType == "UNIT_DIED" or eventType == "UNIT_DESTROYED" then
		--clear the buffs if the unit died
		--NOTE the reason an elseif isn't used is because some dorks may have
		--their current target as their focus as well
		if dstGUID == targetGUID then
			f:ClearAuras(timers)
			targetGUID = 0
		end
		if dstGUID == focusGUID then
			f:ClearAuras(timersFocus)
			focusGUID = 0
		end
		if dstGUID == playerGUID then
			f:ClearAuras(timersPlayer)
		end
	elseif eventSwitch[eventType] and band(srcFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0 then
		--process the spells based on GUID
		if dstGUID == targetGUID then
			f:ProcessAuras("target", timers)
		end
		if dstGUID == focusGUID then
			f:ProcessAuras("focus", timersFocus)
		end
    end
end

----------------------
--  Frame Creation  --
----------------------

function f:CreateAnchor(name, parent, desc)

	--create the anchor
	local frameAnchor = CreateFrame("Frame", name, parent)
	
	frameAnchor:SetWidth(25)
	frameAnchor:SetHeight(25)
	frameAnchor:SetMovable(true)
	frameAnchor:SetClampedToScreen(true)
	frameAnchor:EnableMouse(true)

	frameAnchor:ClearAllPoints()
	frameAnchor:SetPoint("CENTER", parent, "CENTER", 0, 0)
	frameAnchor:SetFrameStrata("DIALOG")
	
	frameAnchor:SetBackdrop({
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 16,
			insets = { left = 5, right = 5, top = 5, bottom = 5 }
	})
	frameAnchor:SetBackdropColor(0,1,0,1)
	frameAnchor:SetBackdropBorderColor(0,1,0,1)

	frameAnchor:SetScript("OnLeave",function(self)
		GameTooltip:Hide()
	end)

	frameAnchor:SetScript("OnEnter",function(self)
	
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:SetPoint(self:SetTip(self))
		GameTooltip:ClearLines()
		
		GameTooltip:AddLine(name)
		if desc then
			GameTooltip:AddLine(desc)
		end
		GameTooltip:Show()
	end)

	frameAnchor:SetScript("OnMouseDown", function(frame, button)
		if frame:IsMovable() then
			frame.isMoving = true
			frame:StartMoving()
		end
	end)

	frameAnchor:SetScript("OnMouseUp", function(frame, button) 
		if( frame.isMoving ) then
			frame.isMoving = nil
			frame:StopMovingOrSizing()
			f:SaveLayout(frame:GetName())
		end
	end)
	
	function frameAnchor:SetTip(frame)
		local x,y = frame:GetCenter()
		if not x or not y then return "TOPLEFT", "BOTTOMLEFT" end
		local hhalf = (x > UIParent:GetWidth()*2/3) and "RIGHT" or (x < UIParent:GetWidth()/3) and "LEFT" or ""
		local vhalf = (y > UIParent:GetHeight()/2) and "TOP" or "BOTTOM"
		return vhalf..hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP")..hhalf
	end

	frameAnchor:Hide() -- hide it by default
	
	f:RestoreLayout(name)
end

local TimerOnUpdate = function(self, time)

	if self.active then
		self.OnUpdateCounter = (self.OnUpdateCounter or 0) + time
		if self.OnUpdateCounter < 0.05 then return end
		self.OnUpdateCounter = 0

		--we need to check for noncanceling auras if on
		local beforeEnd
		local barLength
		
		if XAT_DB.auras and self.durationTime <= 0 then
			beforeEnd = 0
			barLength = string.len(BAR_TEXT)
		else
			beforeEnd = self.endTime - GetTime()
			barLength = ceil( string.len(BAR_TEXT) * (beforeEnd / self.durationTime) )
		end
		
		--check the string length JUST in case for errors
		if barLength > string.len(BAR_TEXT) then barLength = string.len(BAR_TEXT) end

		if barLength <= 0 then
			self.active = false
			self:Hide()
			f:ArrangeAuras(true, self.id)
			return               
		end
		
		self.tmpBL = barLength
		self.Bar:SetText( string.sub(BAR_TEXT, 1, barLength) )
		self.Bar:SetTextColor(f:getBarColor(self.durationTime, beforeEnd))
		if self.stacks > 0 then
			self.stacktext:SetText(self.stacks)
		else
			self.stacktext:SetText(nil)
		end
		self.timetext:SetText(f:GetTimeText(ceil(beforeEnd)))
		f:ArrangeAuras(true, self.id)
	end
	
end

function f:CreateAuraTimers()
	
    local Frm = CreateFrame("Frame", nil, UIParent)
	
    Frm.active = false
    Frm:SetWidth(ICON_SIZE)
    Frm:SetHeight(ICON_SIZE)
	Frm:SetFrameStrata("LOW")
	Frm:SetScale(XAT_DB.scale)
	
    Frm.icon = Frm:CreateTexture(nil, "BACKGROUND")
    Frm.icon:SetTexCoord(.07, .93, .07, .93)
    Frm.icon:SetWidth(ICON_SIZE)
    Frm.icon:SetHeight(ICON_SIZE)
	Frm.icon:SetTexture("Interface\\Icons\\Spell_Shadow_Shadowbolt")
    Frm.icon:SetAllPoints(true)
    
    Frm.stacktext = Frm:CreateFontString(nil, "OVERLAY");
    Frm.stacktext:SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE")
    Frm.stacktext:SetWidth(Frm.icon:GetWidth())
    Frm.stacktext:SetHeight(Frm.icon:GetHeight())
    Frm.stacktext:SetJustifyH("RIGHT")
    Frm.stacktext:SetVertexColor(1,1,1)
    Frm.stacktext:SetPoint("RIGHT", Frm.icon, "RIGHT",1,-5)
    
    Frm.timetext = Frm:CreateFontString(nil, "OVERLAY");
    Frm.timetext:SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE")
    Frm.timetext:SetJustifyH("RIGHT")
    Frm.timetext:SetPoint("RIGHT", Frm.icon, "LEFT" , -5, 0)

	Frm.Bar = Frm:CreateFontString(nil, "GameFontNormal")
	Frm.Bar:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE, MONOCHROME")
	Frm.Bar:SetText(BAR_TEXT)
	Frm.Bar:SetPoint("LEFT", Frm.icon, "RIGHT", 1, 0)
		
    Frm:SetScript("OnUpdate", TimerOnUpdate)

	Frm:Hide()
    
	return Frm
	
end

----------------------
-- Aura Functions --
----------------------

function f:ProcessAuras(sT, sdTimer)
	--only process for as many timers as we are using
	local slotNum = 0
	local filter = ''
	
	--if not UnitExists(sT) then return end
	
	if UnitIsEnemy("player", sT) or not UnitIsFriend("player", sT) then
		filter = 'HARMFUL|PLAYER'
	else
		filter = 'HELPFUL|PLAYER'
	end

	for i=1, MAX_TIMERS do
		local name, _, icon, count, _, duration, expTime, unitCaster, _, _, spellId = UnitAura(sT, i, filter)
		if not name then break end 

		local passChk = false
		--only allow non-cancel auras if the user allowed it
		if XAT_DB.auras then
			--auras are on so basically were allowing everything
			passChk = true
		elseif not XAT_DB.auras and duration and duration > 0 then 
			--auras are not on but the duration is greater then zero, so allow
			passChk = true
		end
		
		--UnitIsUnit is used JUST IN CASE (you never know lol)
		if passChk and name and unitCaster and UnitIsUnit(unitCaster, "player") then
			--get the next timer slot we can use
			slotNum = slotNum + 1
			if not sdTimer[slotNum] then sdTimer[slotNum] = f:CreateAuraTimers() end --create the timer if it doesn't exist
			if not duration or duration <= 0 then expTime = 0 end --just in case for non-cancel auras
			sdTimer[slotNum].id = sT
			sdTimer[slotNum].spellName = name
			sdTimer[slotNum].spellId = spellId
			sdTimer[slotNum].iconTex = icon
			sdTimer[slotNum].icon:SetTexture(icon)
			sdTimer[slotNum].startTime = (expTime - duration) or 0
			sdTimer[slotNum].durationTime = duration or 0
			sdTimer[slotNum].endTime = expTime or 0
			sdTimer[slotNum].stacks = count or 0
				--this has to check for duration=0 because we cannot divide by zero
				local tmpBL
				if duration > 0 then
					tmpBL = ceil( string.len(BAR_TEXT) * ( (expTime - GetTime()) / duration ) )
				elseif duration <= 0 then
					tmpBL = string.len(BAR_TEXT)
				end
				if tmpBL > string.len(BAR_TEXT) then tmpBL = string.len(BAR_TEXT) end
			sdTimer[slotNum].tmpBL = tmpBL
			sdTimer[slotNum].active = true
			if not sdTimer[slotNum]:IsVisible() then sdTimer[slotNum]:Show() end
		end
	end
	--clear everything else
	for i=(slotNum+1), #sdTimer do
		if sdTimer[i] then
			sdTimer[i].active = false
			if sdTimer[i]:IsVisible() then sdTimer[i]:Hide() end
		end
	end
	if slotNum > 0 then
		f:ArrangeAuras(false, sT)
	end
end

function f:ClearAuras(sdTimer)
	local adj = 0

	for i=1, #sdTimer do
		if sdTimer[i].active then
			sdTimer[i].active = false
		end
		--reset the order
		if XAT_DB.grow then
			sdTimer[i]:ClearAllPoints()
			sdTimer[i]:SetPoint("TOPLEFT", pointT[sdTimer[i].id], "BOTTOMRIGHT", 0, adj)
		else
			sdTimer[i]:ClearAllPoints()
			sdTimer[i]:SetPoint("BOTTOMLEFT",  pointT[sdTimer[i].id], "TOPRIGHT", 0, (adj * -1))
		end
		adj = adj - BAR_ADJUST

		if sdTimer[i]:IsVisible() then sdTimer[i]:Hide() end
	end
	
end

function f:ArrangeAuras(throttle, id)
	--to prevent spam and reduce CPU use
	if throttle then
		if not f.ADT then f.ADT = GetTime() end
		if (GetTime() - f.ADT) < 0.1 then
			return
		end
		f.ADT = GetTime()
	end

	local adj = 0
	local sdTimer
	
	if id == "target" then
		sdTimer = timers
	elseif id == "focus" then
		sdTimer = timersFocus
	elseif id == "player" then
		sdTimer = timersPlayer
	else
		return
	end
	
	if XAT_DB.grow then
		--bars will grow down
		if XAT_DB.sort then
			--sort from shortest to longest
			table.sort(sdTimer, function(a,b)
				if a.active == true and b.active == false then
					return true;
				elseif a.active and b.active then
					return (a.tmpBL < b.tmpBL);
				end
				return false;
			end)
		else
			--sort from longest to shortest
			table.sort(sdTimer, function(a,b)
				if a.active == true and b.active == false then
					return true;
				elseif a.active and b.active then
					return (a.tmpBL > b.tmpBL);
				end
				return false;
			end)
		end
	else
		--bars will grow up
		if XAT_DB.sort then
			--sort from shortest to longest
			table.sort(sdTimer, function(a,b)
				if a.active == true and b.active == false then
					return true;
				elseif a.active and b.active then
					return (a.tmpBL > b.tmpBL);
				end
				return false;
			end)
		else
			--sort from longest to shortest
			table.sort(sdTimer, function(a,b)
				if a.active == true and b.active == false then
					return true;
				elseif a.active and b.active then
					return (a.tmpBL < b.tmpBL);
				end
				return false;
			end)
		end
	end

	--rearrange order
	for i=1, #sdTimer do
		if XAT_DB.grow then
			sdTimer[i]:ClearAllPoints()
			sdTimer[i]:SetPoint("TOPLEFT", pointT[sdTimer[i].id], "BOTTOMRIGHT", 0, adj)
		else
			sdTimer[i]:ClearAllPoints()
			sdTimer[i]:SetPoint("BOTTOMLEFT", pointT[sdTimer[i].id], "TOPRIGHT", 0, (adj * -1))
		end
		adj = adj - BAR_ADJUST
    end
	
end

----------------------
-- Local Functions  --
----------------------
	
function f:SaveLayout(frame)

	if not XAT_DB then XAT_DB = {} end

	local opt = XAT_DB[frame] or nil;

	if opt == nil then
		XAT_DB[frame] = {
			["point"] = "CENTER",
			["relativePoint"] = "CENTER",
			["PosX"] = 0,
			["PosY"] = 0,
		}
		opt = XAT_DB[frame];
	end

	local f = getglobal(frame);
	local scale = f:GetEffectiveScale();
	opt.PosX = f:GetLeft() * scale;
	opt.PosY = f:GetTop() * scale;
	
end

function f:RestoreLayout(frame)

	if not XAT_DB then XAT_DB = {} end
	
	local f = getglobal(frame);
	local opt = XAT_DB[frame] or nil;

	if opt == nil then
		XAT_DB[frame] = {
			["point"] = "CENTER",
			["relativePoint"] = "CENTER",
			["PosX"] = 0,
			["PosY"] = 0,
			["firsttime"] = true,
		}
		opt = XAT_DB[frame]
	end

	local x = opt.PosX;
	local y = opt.PosY;
	local s = f:GetEffectiveScale()

	if not x or not y or opt.firsttime then
		f:ClearAllPoints()
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		if opt.firsttime then opt.firsttime = nil end
		return 
	end

	--calculate the scale
	x,y = x/s, y/s

	--set the location
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)

end

function f:getBarColor(dur, expR, auraType)
	if dur <= 0 then
		--this will make the bar green
		dur = 1
		expR = 1
	end
	local r
	local g = 1
	local cur = 2 * expR/dur
	if cur > 1 then
		return 2 - cur, 1, 0
	else
		return 1, cur, 0
	end
end

function f:GetTimeText(timeLeft)
	if timeLeft <= 0 then return nil end
	
	local hours, minutes, seconds = 0, 0, 0
	if( timeLeft >= 3600 ) then
		hours = floor(timeLeft / 3600)
		timeLeft = mod(timeLeft, 3600)
	end

	if( timeLeft >= 60 ) then
		minutes = floor(timeLeft / 60)
		timeLeft = mod(timeLeft, 60)
	end

	seconds = timeLeft > 0 and timeLeft or 0

	if hours > 0 then
		return string.format("%dh",hours)
	elseif minutes > 0 then
		return string.format("%dm",minutes)
	elseif seconds > 0 then
		return string.format("%ds",seconds)
	else
		return nil
	end
end
		
if IsLoggedIn() then f:PLAYER_LOGIN() else f:RegisterEvent("PLAYER_LOGIN") end

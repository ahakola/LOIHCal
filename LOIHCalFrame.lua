--[[----------------------------------------------------------------------------
	LOIHCal

	UIFactory
------------------------------------------------------------------------------]]
local ADDON_NAME, ns = ...
local L = ns.L

local isWrathClassic = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_WRATH_CLASSIC)
local isCataClassic = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_CATACLYSM_CLASSIC)
local difficultyOffset = 0
if (isWrathClassic or isCataClassic) then -- WrathClassic
	difficultyOffset = 2 -- List items 1-4, Difficulty items 3-6
else -- Retail
	difficultyOffset = 13 -- List items 1-3, Difficulty items 14-16
end

local UIFrame = CreateFrame("Frame", "LOIHCalFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
ns.Frame = UIFrame

UIFrame:SetWidth(320)
UIFrame:SetHeight(580)
UIFrame:SetToplevel(true)
UIFrame:EnableMouse(true)

local TabsFrame
if (isWrathClassic or isCataClassic) then
	TabsFrame = CreateFrame("Frame", "LOIHCalTabsFrame", UIParent)
else -- 10.0 DF
	TabsFrame = CreateFrame("Frame", "LOIHCalTabsFrame", UIParent, "TabSystemTemplate")
	TabsFrame:SetTabSelectedCallback(ns.functions.tabOnClick)
end
ns.Tabs = TabsFrame

TabsFrame:SetWidth(320)
TabsFrame:SetHeight(1)
TabsFrame:SetToplevel(true)
TabsFrame:EnableMouse(true)
TabsFrame:SetPoint("TOP", UIFrame, "BOTTOM")

--------------------------------------------------------------------------------
--	Factory functions
--------------------------------------------------------------------------------
	-- Background for frames
	local bg = {
		bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
		edgeFile = 'Interface\\ChatFrame\\ChatFrameBackground',
		tile = true, tileSize = 32, edgeSize = 1,
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	}

	-- Round function, copied from http://lua-users.org/wiki/SimpleRound
	local function _round(num, idp)
		local mult = 10^(idp or 0)
		return math.floor(num * mult + 0.5) / mult
	end

	-- Frames without Backdrop
	local invisFrames = {
		[ADDON_NAME.."_Container"] = true,
		[ADDON_NAME.."_InvBars"] = true,
		[ADDON_NAME.."_Roles"] = true,
		[ADDON_NAME.."_Shield"] = true,
		[ADDON_NAME.."_Tabs"] = true,
		[ADDON_NAME.."_Think"] = true,
	}

	--  Frame Factory  ---------------------------------------------------------
	local function _frameFactory(type, name, parent, width, height, template)
		local f = CreateFrame(type, name, parent, template)
		if width and height then
			f:SetSize(width, height)
		end
		if type == "Frame" and not invisFrames[name] then
			f:SetBackdrop(bg)
			f:SetBackdropBorderColor(unpack(ns.colors.bordercolor))
		end

		return f
	end

	--  Title Factory  ---------------------------------------------------------
	local function _titleFactory(parent, offset, text)
		local f = CreateFrame("Button", "$parentTitle", parent)
		f:SetSize(152, 15)
		f:SetPoint("TOP", 0, offset)

		local s = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		s:SetPoint("CENTER")
		s:SetText(text)
		f.s = s
		if text ~= " " then -- Don't create texture for Bottombar
			local t = f:CreateTexture()
			t:SetParent(f)
			t:SetAllPoints(f)
			t:SetColorTexture(unpack(ns.colors.deselect))
			f.t = t
		end

		f:SetScript("OnClick", ns.functions.titleOnClick)

		return f
	end

	--  Icon Factory  ----------------------------------------------------------
	local function _iconFactory(parent, role)
		local f = CreateFrame("Button", "$parentIcon", parent)
		f:SetSize(16, 16)
		f:EnableMouse(false) -- Click-through
		if role == "TITLE" then
			f:SetScale(8) -- 128x128
			f:SetFrameLevel(parent:GetParent():GetFrameLevel()) -- Push Logo behind other frames
			f:SetPoint("CENTER")
		elseif role == "DIFFICULTY" or role == "LOOT" or role == "INVITE" then
			f:SetPoint("RIGHT", parent.s, "LEFT", -2, 0)
		else
			f:SetPoint("RIGHT", parent.s, "LEFT", 0, 1)
		end

		local t = f:CreateTexture()
		t:SetParent(f)
		t:SetAllPoints(f)
		if role == "TITLE" then -- Lion Head -icon for main window title
			if _G.UnitFactionGroup("Player") == "Horde" then
				t:SetTexture("Interface\\Timer\\Horde-Logo")
			else
				t:SetTexture("Interface\\Timer\\Alliance-Logo")
			end
		elseif role == "TANK" then
			t:SetTexture("Interface\\LFGFrame\\LFGRole")
			t:SetTexCoord(0.5, 0.75, 0, 1)
		elseif role == "HEALER" then
			t:SetTexture("Interface\\LFGFrame\\LFGRole")
			t:SetTexCoord(0.75, 1, 0, 1)
		elseif role == "DPS" then
			t:SetTexture("Interface\\LFGFrame\\LFGRole")
			t:SetTexCoord(0.25, 0.5, 0, 1)
		elseif role == "SIGNUP" then
			t:SetTexture("Interface\\Minimap\\ObjectIcons")
			if (isWrathClassic or isCataClassic) then
				t:SetTexCoord(4/8, 5/8, 1/2, 1)
			else -- Retail
				t:SetTexCoord(0.5, 0.625, 0.125, 0.25)
			end
		elseif role == "STANDBY" then
			t:SetTexture("Interface\\Minimap\\ObjectIcons")
			if (isWrathClassic or isCataClassic) then
				t:SetTexCoord(1/8, 2/8, 1/2, 1)
			else -- Retail
				t:SetTexCoord(0.625, 0.75, 0.5, 0.625)
			end
		elseif role == "DIFFICULTY" then
			t:SetTexture("Interface\\Minimap\\ObjectIcons")
			if (isWrathClassic or isCataClassic) then
				t:SetTexCoord(6/8, 7/8, 0, 1/2)
			else -- Retail
				--t:SetTexCoord(0.625, 0.75, 0.375, 0.5)
				t:SetTexCoord(7/8, 1, 3/4, 7/8)
			end
		elseif role == "INVITE" then
			t:SetTexture("Interface\\Buttons\\UI-GuildButton-MOTD-Up")
			t:SetTexCoord(0, 1, 0, 1)
		end
		f.t = t

		return f
	end

	--  Slot Factory  ----------------------------------------------------------
	local function _slotFactory(number, parent)
		local f = CreateFrame("Button", "$parentRow"..number, parent)
		f:SetSize(150, 15)
		f:SetNormalFontObject(GameFontNormal)
		f:RegisterForClicks("AnyUp")
		if number == 1 then
			f:SetPoint("TOP", parent, "TOP", 0, -1) -- 1px Marginal on top of the parent
		else
			f:SetPoint("TOP", parent.rows[number-1], "BOTTOM")
		end

		local sn = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLeft")
		sn:SetPoint("CENTER")
		f.fname = sn

		local ss = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLeft")
		ss:SetPoint("LEFT")
		f.fstatus = ss

		if parent:GetName() ~= "AutoRoles" then
			local sl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLeft")
			sl:SetPoint("RIGHT")
			f.flevel = sl
		end

		local t = f:CreateTexture()
		t:SetParent(f)
		t:SetAllPoints(f)
		t:SetColorTexture(1, 1, 1, 0.25)
		f.t = t

		if parent:GetName() == "AutoRoles" then
			f:SetWidth(258)
			f.fname:ClearAllPoints()
			f.fname:SetPoint("CENTER", -258/5, 0)
			f.fstatus:ClearAllPoints()
			f.fstatus:SetPoint("CENTER", 258/5, 0)
			f:SetScript("OnClick", ns.functions.rolesSlotOnClick)
		else
			f:SetScript("OnClick", ns.functions.slotOnClick)
		end

		return f
	end

	--  Faux Scroller / ScrollBar Factory  -------------------------------------
	local function _scrollBarFactory(parent, tbl)
		local f = CreateFrame("ScrollFrame", "$parentScrollBar", parent, "ScrollFrameTemplate")
		f:SetPoint("TOPLEFT", -7, -1)
		f:SetPoint("BOTTOMRIGHT", -23, 1)

		if parent:GetName() == "AutoRoles" then
			f:SetScript("OnVerticalScroll", function(self, offset)
				--self:SetValue(offset)
				self.offset = floor(offset / 15 + 0.5)
				ns.functions.updateRolesScrollBar(parent)
			end)

			f:SetScript("OnShow", function()
				ns.functions.updateRolesScrollBar(parent)
			end)
		else
			f:SetScript("OnVerticalScroll", function(self, offset)
				--self:SetValue(offset)
				self.offset = floor(offset / 15 + 0.5)
				ns.functions.updateScrollBar(parent, tbl)
			end)

			f:SetScript("OnShow", function()
				ns.functions.updateScrollBar(parent, tbl)
			end)
		end

		-- 10.1 Replacing FauxScroller with ScrollFrame
		local scrollChild = CreateFrame("Frame") --, parent:GetName().."ScrollChild")
		f:SetScrollChild(scrollChild)
		f.scrollChild = scrollChild

		return f
	end

	--  Tab Factory  -----------------------------------------------------------
	local function _tabFactory(parent, number, text)
		if (isWrathClassic or isCataClassic) then
			local f = CreateFrame("Button", "$parentTab"..number, parent, "CharacterFrameTabButtonTemplate")
			f:SetID(number)
			f:SetText(text)

			if number == 1 then
				f:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, 2)
			elseif number == 2 then
				f:SetPoint("LEFT", parent.tab1, "RIGHT")
			elseif number == 3 then
				f:SetPoint("LEFT", parent.tab2, "RIGHT")
			end

			f:SetScript("OnClick", ns.functions.tabOnClick)

			return f
		else -- 10.0 DF
			local id = parent:AddTab(text)
			return parent:GetTabButton(id)
		end
	end

	--  Meta Factory  ----------------------------------------------------------
	local function _metaFactory(parent)
		local t = setmetatable({}, { __index = function(t, i)
			local row = _slotFactory(i, parent)

			rawset(t, i, row)
			return row
		end })

		return t
	end

--------------------------------------------------------------------------------
--	Parent frames
--------------------------------------------------------------------------------
	--  Main frame  ------------------------------------------------------------
	UIFrame:SetBackdrop(bg)
	UIFrame:SetBackdropBorderColor(unpack(ns.colors.bordercolor))

	UIFrame.title = _titleFactory(UIFrame, -5, ADDON_NAME)
	UIFrame.title:SetSize(260, 15)
	UIFrame.title:Disable()

	UIFrame.role = _iconFactory(UIFrame.title, "TITLE")

	UIFrame.close = _frameFactory("Button", "$parent_Close", UIFrame, false, false, "UIPanelCloseButton")
	UIFrame.close:SetPoint("TOPRIGHT", 4, 4)
	UIFrame.close:SetScript("OnClick", function(self) -- Hack for 7.0 click through bug
		if CalendarViewEventFrame:IsShown() then
			CalendarViewEventFrame:Hide()
			PlaySound(854)
		elseif CalendarCreateEventFrame:IsShown() then
			CalendarCreateEventFrame:Hide()
			PlaySound(854)
		end
	end)
	-- Hack for OnClick-scripts not working in 8.0
	UIFrame.close:SetFrameLevel(UIFrame.title:GetFrameLevel() + 2)


	--  Shield frame  ----------------------------------------------------------
	--[[	Shield frames task is to prevent clicking on the class icons on
	right side of the Default view. When those are clicked, the Default view
	jumps on top and pushes LOIHCal behind the Default view.				]]--
	UIFrame.shield = _frameFactory("Frame", ADDON_NAME.."_Shield", UIFrame, 24, 580)
	UIFrame.shield:SetPoint("LEFT", UIFrame, "RIGHT")
	UIFrame.shield:SetFrameStrata("HIGH")
	UIFrame.shield:SetFrameLevel(UIFrame.shield:GetFrameLevel()+4)
	UIFrame.shield:EnableMouse(true)

	--  Tabs frame  ------------------------------------------------------------
	TabsFrame.tab1 = _tabFactory(TabsFrame, 1, L.Default)
	TabsFrame.tab2 = _tabFactory(TabsFrame, 2, ADDON_NAME)
	TabsFrame.tab3 = _tabFactory(TabsFrame, 3, L.Roles)

	TabsFrame:SetScript("OnShow", function(self)
		ns.functions.renameTabs()
		TabsFrame:SetScript("OnShow", nil)
	end)

	--  Event view frame  ------------------------------------------------------
	UIFrame.Container = _frameFactory("Frame", ADDON_NAME.."_Container", UIFrame, 320, 580)
	UIFrame.Container:SetPoint("TOPLEFT")

	UIFrame.Container:SetScript("OnShow", function(self) -- Update title
		UIFrame.title.s:SetFormattedText("%s - %s", ADDON_NAME, ns.openEvent and ns.openEvent.title or "Loading...")
	end)

	UIFrame.Container.bottom = _titleFactory(UIFrame.Container, 0, " ")
	UIFrame.Container.bottom:SetSize(318, 15)
	UIFrame.Container.bottom:Disable()
	UIFrame.Container.bottom:SetPoint("BOTTOM", 0, 5)
	UIFrame.Container.bottom.s:SetPoint("BOTTOM")

	--  Roles frame  -----------------------------------------------------------
	UIFrame.Roles = _frameFactory("Frame", ADDON_NAME.."_Roles", UIFrame, 320, 580)
	UIFrame.Roles:SetPoint("TOPLEFT")

	UIFrame.Roles:SetScript("OnShow", function(self) -- Update title
		UIFrame.title.s:SetFormattedText("%s - %s", ADDON_NAME, L.Roles)
	end)

	--  Think frame  -----------------------------------------------------------
	UIFrame.Think = _frameFactory("Frame", ADDON_NAME.."_Think", UIFrame, 320, 580)
	UIFrame.Think:SetPoint("TOPLEFT")
	UIFrame.Think.s = UIFrame.Think:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	UIFrame.Think.s:SetPoint("CENTER")
	UIFrame.Think.s:SetText(L.ServerWait)
	UIFrame.Think:SetScript("OnShow", ns.functions.getState)
	UIFrame.Think:SetScript("OnHide", ns.functions.setState)

	--  Invite bars frame  -----------------------------------------------------
	UIFrame.InvBars = _frameFactory("Frame", ADDON_NAME.."_InvBars", UIFrame, 320, 580)
	UIFrame.InvBars:SetPoint("TOPLEFT")
	UIFrame.InvBars:SetScript("OnShow", ns.functions.getState)
	UIFrame.InvBars:SetScript("OnHide", ns.functions.setState)

--------------------------------------------------------------------------------
--	Event view frames
--------------------------------------------------------------------------------
	--  Tanks frame  -----------------------------------------------------------
	UIFrame.Container.Tanks = _frameFactory("Frame", "Tanks", UIFrame.Container, 152, 92, BackdropTemplateMixin and "BackdropTemplate")
	UIFrame.Container.Tanks:SetPoint("TOPLEFT", 5, -45)

	UIFrame.Container.Tanks.title = _titleFactory(UIFrame.Container.Tanks, 15, L.Tanks)

	UIFrame.Container.Tanks.role = _iconFactory(UIFrame.Container.Tanks.title, "TANK")

	UIFrame.Container.Tanks.scrollBar = _scrollBarFactory(UIFrame.Container.Tanks, ns.role["Tanks"]) -- Faux
	UIFrame.Container.Tanks.rows = _metaFactory(UIFrame.Container.Tanks)

	--  Healers frame  ---------------------------------------------------------
	UIFrame.Container.Healers = _frameFactory("Frame", "Healers", UIFrame.Container, 152, 92, BackdropTemplateMixin and "BackdropTemplate")
	UIFrame.Container.Healers:SetPoint("LEFT", UIFrame.Container.Tanks, "RIGHT", 6, 0)

	UIFrame.Container.Healers.title = _titleFactory(UIFrame.Container.Healers, 15, L.Healers)

	UIFrame.Container.Healers.role = _iconFactory(UIFrame.Container.Healers.title, "HEALER")

	UIFrame.Container.Healers.scrollBar = _scrollBarFactory(UIFrame.Container.Healers, ns.role["Healers"]) -- Faux
	UIFrame.Container.Healers.rows = _metaFactory(UIFrame.Container.Healers)

	--  Melee frame  -----------------------------------------------------------
	UIFrame.Container.Melee = _frameFactory("Frame", "Melee", UIFrame.Container, 152, 152, BackdropTemplateMixin and "BackdropTemplate")
	UIFrame.Container.Melee:SetPoint("TOP", UIFrame.Container.Tanks, "BOTTOM", 0, -26)

	UIFrame.Container.Melee.title = _titleFactory(UIFrame.Container.Melee, 15, L.Melee)

	UIFrame.Container.Melee.role = _iconFactory(UIFrame.Container.Melee.title, "DPS")

	UIFrame.Container.Melee.scrollBar = _scrollBarFactory(UIFrame.Container.Melee, ns.role["Melee"]) -- Faux
	UIFrame.Container.Melee.rows = _metaFactory(UIFrame.Container.Melee)

	--  Ranged frame  ----------------------------------------------------------
	UIFrame.Container.Ranged = _frameFactory("Frame", "Ranged", UIFrame.Container, 152, 152, BackdropTemplateMixin and "BackdropTemplate")
	UIFrame.Container.Ranged:SetPoint("LEFT", UIFrame.Container.Melee, "RIGHT", 6, 0)

	UIFrame.Container.Ranged.title = _titleFactory(UIFrame.Container.Ranged, 15, L.Ranged)

	UIFrame.Container.Ranged.role = _iconFactory(UIFrame.Container.Ranged.title, "DPS")

	UIFrame.Container.Ranged.scrollBar = _scrollBarFactory(UIFrame.Container.Ranged, ns.role["Ranged"]) -- Faux
	UIFrame.Container.Ranged.rows = _metaFactory(UIFrame.Container.Ranged)

	--  Signup frame  ----------------------------------------------------------
	UIFrame.Container.Signup = _frameFactory("Frame", "Signup", UIFrame.Container, 152, 152, BackdropTemplateMixin and "BackdropTemplate")
	UIFrame.Container.Signup:SetPoint("TOP", UIFrame.Container.Melee, "BOTTOM", 0, -26)

	UIFrame.Container.Signup.title = _titleFactory(UIFrame.Container.Signup, 15, L.Signups)

	UIFrame.Container.Signup.role = _iconFactory(UIFrame.Container.Signup.title, "SIGNUP")

	UIFrame.Container.Signup.scrollBar = _scrollBarFactory(UIFrame.Container.Signup, ns.role["Signup"]) -- Faux
	UIFrame.Container.Signup.rows = _metaFactory(UIFrame.Container.Signup)

	UIFrame.Container.Signup.desc = _titleFactory(UIFrame.Container.Signup, 0, " ")
	UIFrame.Container.Signup.desc:SetSize(152, 15)
	UIFrame.Container.Signup.desc:Disable()
	UIFrame.Container.Signup.desc:SetPoint("TOP", UIFrame.Container.Signup, "BOTTOM", 0, -5)
	UIFrame.Container.Signup.desc.s:SetPoint("TOP")
	UIFrame.Container.Signup.desc.s:SetFormattedText(L.SignupDesc, HIGHLIGHT_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE, HIGHLIGHT_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE, RED_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE..HIGHLIGHT_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE..RED_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE)
	UIFrame.Container.Signup.desc.s:SetTextScale(UIParent:GetEffectiveScale()) -- Scale text size down with UIParent scale

	--  Standby frame  ---------------------------------------------------------
	UIFrame.Container.Standby = _frameFactory("Frame", "Standby", UIFrame.Container, 152, 92, BackdropTemplateMixin and "BackdropTemplate")
	UIFrame.Container.Standby:SetPoint("TOPLEFT", UIFrame.Container.Signup, "TOPRIGHT", 6, 0)

	UIFrame.Container.Standby.title = _titleFactory(UIFrame.Container.Standby, 15, L.Standbys)

	UIFrame.Container.Standby.role = _iconFactory(UIFrame.Container.Standby.title, "STANDBY")

	UIFrame.Container.Standby.scrollBar = _scrollBarFactory(UIFrame.Container.Standby, ns.role["Standby"]) -- Faux
	UIFrame.Container.Standby.rows = _metaFactory(UIFrame.Container.Standby)

	--  Event settings  --------------------------------------------------------
	UIFrame.Container.ED = _frameFactory("Button", ADDON_NAME.."_ED", UIFrame.Container, false, false, "UIDropDownMenuTemplate")
	UIDropDownMenu_Initialize(UIFrame.Container.ED, ns.functions.EDInitialize)
	UIDropDownMenu_SetWidth(UIFrame.Container.ED, 105)
	UIDropDownMenu_JustifyText(UIFrame.Container.ED, "CENTER")
	UIFrame.Container.ED:SetPoint("TOP", UIFrame.Container.Standby, "BOTTOM", 0, -26)

	UIFrame.Container.ED.title = _titleFactory(UIFrame.Container.ED, 15, L.RaidDifficulty)
	UIFrame.Container.ED.title:SetSize(120, 15)
	UIFrame.Container.ED.title:Disable()

	UIFrame.Container.ED.role = _iconFactory(UIFrame.Container.ED.title, "DIFFICULTY")

	-- Quick and dirty taint fix
	function UIFrame.Container.ED:SetSelectedID(id)
		self.selected = id + difficultyOffset
		UIDropDownMenu_SetText(UIFrame.Container.ED, ns.difficulties[id]["name"])
	end

	function UIFrame.Container.ED:GetSelectedID()
		return self.selected
	end

	--  Mass Invite  -----------------------------------------------------------
	UIFrame.Container.MIB = _frameFactory("Button", ADDON_NAME.."_MIB", UIFrame.Container, 125, 28, "UIPanelButtonTemplate")
	UIFrame.Container.MIB:SetScript("OnClick", ns.functions.MIBClick)
	UIFrame.Container.MIB:SetPoint("TOP", UIFrame.Container.ED, "BOTTOM", 0, -16) -- -26?
	UIFrame.Container.MIB:SetText(L.MassInvite)
	-- Hack for OnClick-scripts not working in 8.0
	UIFrame.Container.MIB:SetFrameLevel(UIFrame.title:GetFrameLevel() + 2)

	UIFrame.Container.MIB.tooltipText = L.MassInviteDesc

	UIFrame.Container.MIB.title = _titleFactory(UIFrame.Container.MIB, 15, L.MassInvite)
	UIFrame.Container.MIB.title:SetSize(120, 15)
	UIFrame.Container.MIB.title:Disable()

	UIFrame.Container.MIB.role = _iconFactory(UIFrame.Container.MIB.title, "INVITE")

--------------------------------------------------------------------------------
--	Roles frames
--------------------------------------------------------------------------------
	--  Roles scroller  --------------------------------------------------------
	UIFrame.Roles.AutoRoles = _frameFactory("Frame", "AutoRoles", UIFrame.Roles, 260, 302, BackdropTemplateMixin and "BackdropTemplate")
	UIFrame.Roles.AutoRoles:SetPoint("TOP", 0, -45)

	UIFrame.Roles.AutoRoles.scrollBar = _scrollBarFactory(UIFrame.Roles.AutoRoles) -- Faux
	UIFrame.Roles.AutoRoles.rows = _metaFactory(UIFrame.Roles.AutoRoles)

	--  Player info texts  -----------------------------------------------------
	UIFrame.Roles.AutoRoles.nameText = UIFrame.Roles.AutoRoles:CreateFontString(nil, "OVERLAY", "SubZoneTextFont")
	UIFrame.Roles.AutoRoles.nameText:SetPoint("TOPLEFT", UIFrame.Roles.AutoRoles, "BOTTOMLEFT", 0, -28)

	UIFrame.Roles.AutoRoles.roleText = UIFrame.Roles.AutoRoles:CreateFontString(nil, "OVERLAY", "GameFontNormalLargeLeft")
	UIFrame.Roles.AutoRoles.roleText:SetPoint("TOPLEFT", UIFrame.Roles.AutoRoles.nameText, "BOTTOMLEFT", 0, -14)

	UIFrame.Roles.AutoRoles.lastText = UIFrame.Roles.AutoRoles:CreateFontString(nil, "OVERLAY", "GameFontNormalLargeLeft")
	UIFrame.Roles.AutoRoles.lastText:SetPoint("TOPLEFT", UIFrame.Roles.AutoRoles.roleText, "BOTTOMLEFT", 0, -14)

	--  Role buttons  ----------------------------------------------------------
	UIFrame.Roles.TB = _frameFactory("Button", ADDON_NAME.."_TB", UIFrame.Roles, 60, 28, "UIPanelButtonTemplate")
	UIFrame.Roles.TB:SetScript("OnClick", ns.functions.TBClick)
	UIFrame.Roles.TB:SetPoint("TOPLEFT", UIFrame.Roles.AutoRoles.lastText, "BOTTOMLEFT", 4, -28)
	UIFrame.Roles.TB:SetText(L.Tanks)

	UIFrame.Roles.TB.tooltipText = string.format(L.RoleDesc, L.Tanks)

	UIFrame.Roles.HB = _frameFactory("Button", ADDON_NAME.."_HB", UIFrame.Roles, 60, 28, "UIPanelButtonTemplate")
	UIFrame.Roles.HB:SetScript("OnClick", ns.functions.HBClick)
	UIFrame.Roles.HB:SetPoint("LEFT", UIFrame.Roles.TB, "RIGHT", 4, 0)
	UIFrame.Roles.HB:SetText(L.Healers)

	UIFrame.Roles.HB.tooltipText = string.format(L.RoleDesc, L.Healers)

	UIFrame.Roles.MB = _frameFactory("Button", ADDON_NAME.."_MB", UIFrame.Roles, 60, 28, "UIPanelButtonTemplate")
	UIFrame.Roles.MB:SetScript("OnClick", ns.functions.MBClick)
	UIFrame.Roles.MB:SetPoint("LEFT", UIFrame.Roles.HB, "RIGHT", 4, 0)
	UIFrame.Roles.MB:SetText(L.Melee)

	UIFrame.Roles.MB.tooltipText = string.format(L.RoleDesc, L.Melee)

	UIFrame.Roles.RB = _frameFactory("Button", ADDON_NAME.."_RB", UIFrame.Roles, 60, 28, "UIPanelButtonTemplate")
	UIFrame.Roles.RB:SetScript("OnClick", ns.functions.RBClick)
	UIFrame.Roles.RB:SetPoint("LEFT", UIFrame.Roles.MB, "RIGHT", 4, 0)
	UIFrame.Roles.RB:SetText(L.Ranged)

	UIFrame.Roles.RB.tooltipText = string.format(L.RoleDesc, L.Ranged)

	--  Remove button  ---------------------------------------------------------
	UIFrame.Roles.REM = _frameFactory("Button", ADDON_NAME.."_REM", UIFrame.Roles, 124, 28, "UIPanelButtonTemplate")
	UIFrame.Roles.REM:SetScript("OnClick", ns.functions.REMClick)
	UIFrame.Roles.REM:SetPoint("TOPLEFT", UIFrame.Roles.HB, "BOTTOMLEFT", 0, -14)
	UIFrame.Roles.REM:SetText(L.Remove)

	UIFrame.Roles.REM.tooltipText = string.format(L.RemoveDesc, GREEN_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE)

--------------------------------------------------------------------------------
--	Invite bars frame bars
--------------------------------------------------------------------------------
	--  Bars border frame  -----------------------------------------------------
	UIFrame.InvBars.B = _frameFactory("Frame", "InvBarsEdge", UIFrame.InvBars, 240, 20, BackdropTemplateMixin and "BackdropTemplate")
	UIFrame.InvBars.B:SetPoint("CENTER")
	UIFrame.InvBars.B.s = UIFrame.InvBars.B:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	UIFrame.InvBars.B.s:SetPoint("CENTER")

	--  In raid -bar  ----------------------------------------------------------
	UIFrame.InvBars.R = UIFrame.InvBars.B:CreateTexture()
	UIFrame.InvBars.R:SetColorTexture(BATTLENET_FONT_COLOR.r, BATTLENET_FONT_COLOR.g, BATTLENET_FONT_COLOR.b, 0.35)
	UIFrame.InvBars.R:SetSize(80, 20)
	UIFrame.InvBars.R:SetPoint("LEFT")

	--  Invited-bar  -----------------------------------------------------------
	UIFrame.InvBars.I = UIFrame.InvBars.B:CreateTexture()
	UIFrame.InvBars.I:SetColorTexture(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b, 0.35)
	UIFrame.InvBars.I:SetSize(80, 20)
	UIFrame.InvBars.I:SetPoint("LEFT", UIFrame.InvBars.R, "RIGHT")

	--  Title text  ------------------------------------------------------------
	UIFrame.InvBars.s = UIFrame.InvBars:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	UIFrame.InvBars.s:SetPoint("BOTTOM", UIFrame.InvBars.B, "TOP", 0, 10)
	UIFrame.InvBars.s:SetText(L.SendingInvites)

	--  Last invited name text  ------------------------------------------------
	UIFrame.InvBars.t = UIFrame.InvBars:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	UIFrame.InvBars.t:SetPoint("TOP", UIFrame.InvBars.B, "BOTTOM", 0, -10)

	--  Cancel button  ---------------------------------------------------------
	UIFrame.InvBars.Cancel = _frameFactory("Button", "InvBarsCancel", UIFrame.InvBars, 125, 28, "UIPanelButtonTemplate")
	UIFrame.InvBars.Cancel:SetScript("OnClick", ns.functions.InvCancel)
	UIFrame.InvBars.Cancel:SetPoint("TOP", UIFrame.InvBars.B, "BOTTOM", 0, -26)
	UIFrame.InvBars.Cancel:SetText(L.Cancel)

--------------------------------------------------------------------------------
--	Done
--------------------------------------------------------------------------------
	TabsFrame:Hide()
	UIFrame.Container:Hide()
	UIFrame.Think:Hide()
	UIFrame.InvBars:Hide()
	UIFrame.Roles:Hide()
	UIFrame:Hide()

	ns.OnLoad(UIFrame)

--------------------------------------------------------------------------------
--	EOF

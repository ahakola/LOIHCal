--[[----------------------------------------------------------------------------
	LOIHCal

	2014-2023
	Sanex @ EU-Arathor / ahak @ Curseforge

	http://wow.curseforge.com/addons/loihcal/
----------------------------------------------------------------------------]]--
local ADDON_NAME, ns = ...
local L = ns.L
local _G = _G
local DEFAULT_CHAT_FRAME, DEBUG_CHAT_FRAME = _G.DEFAULT_CHAT_FRAME, _G.DEBUG_CHAT_FRAME
local FONT_COLOR_CODE_CLOSE, GRAY_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE = _G.FONT_COLOR_CODE_CLOSE, _G.GRAY_FONT_COLOR_CODE, _G.GREEN_FONT_COLOR_CODE
local HIGHLIGHT_FONT_COLOR_CODE, INTERACTIVE_SERVER_LABEL, ITEM_QUALITY_COLORS = _G.HIGHLIGHT_FONT_COLOR_CODE, _G.INTERACTIVE_SERVER_LABEL, _G.ITEM_QUALITY_COLORS
local NORMAL_FONT_COLOR_CODE, ORANGE_FONT_COLOR_CODE, RAID_CLASS_COLORS = _G.NORMAL_FONT_COLOR_CODE, _G.ORANGE_FONT_COLOR_CODE, _G.RAID_CLASS_COLORS
local RED_FONT_COLOR_CODE = _G.RED_FONT_COLOR_CODE
local db, UIFrame, TabsFrame, EventFrame, Options
local ERR_INVITE_PLAYER_S = string.gsub(_G.ERR_INVITE_PLAYER_S, "%%s", "(.+)")
--local ERR_INVITE_PLAYER_S = string.gsub(_G.ERR_CHAT_PLAYER_NOT_FOUND_S, "%%s", "(.+)") -- Debug

local isWrathClassic = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_WRATH_CLASSIC)

ns.difficulties, ns.role, ns.functions = {}, {}, {}, {}
ns.openEvent, ns.inviteTable = {}, {}
ns.numSignup, ns.notReplied, ns.selected, ns.selectedPlayer = 0, 0, false, false
ns.version = GetAddOnMetadata(ADDON_NAME, "Version")

--[[----------------------------------------------------------------------------
	Pre-WoD:
	1	"Normal"			2	"Heroic"				3	"10 Player"
	4	"25 Player"			5	"10 Player (Heroic)"	6	"25 Player (Heroic)"
	7	"Looking For Raid"	8	"Challenge Mode"		9	"40 Player"
	10	nil					11	"Heroic Scenario"		12	"Normal Scenario"
	13	nil					14	"Flexible"
	WoD:
	14	"Normal Raid"		15	"Heroic Raid"			16	"Mythic Raid"
	Legion:
	18	"Event" (raid)		19	"Event" (party)			20	"Event Scenario"
	21	nil					22	nil						23	"Mythic" (party)
	24	"Timewalking"		25	"PvP Scenario"			26	nil
----------------------------------------------------------------------------]]--
local difficultyOffset = 0
if isWrathClassic then -- WratchClassic (10N, 10HC, 25N and 25HC)
	for i = 3, 6 do
		table.insert(ns.difficulties, {name = GetDifficultyInfo(i), id = i})
	end
	difficultyOffset = 2 -- List items 1-4, Difficulty items 3-6
else -- Retail (Normal, Heroic and Mythic)
	for i = 14, 16 do
		table.insert(ns.difficulties, {name = GetDifficultyInfo(i), id = i})
	end
	difficultyOffset = 13 -- List items 1-3, Difficulty items 14-16
end

ns.DBdefaults = {
	events = {},
	roles = {},
	config = {
		debug = false,
		nameDebug = false,
		elvSkin = false,
		overlay = false,
		defaultView = true,
		autoConfirm = true,
		autoRole = true,
		autoRoleCount = 3,
		autoRoleDecay = true,
		autoRoleDecayTime = 2, -- Months
		defaultDifficulty = ns.difficulties[1].id,
		sendWhisper = true,
		InvWhisper = L.DefaultInvWhisper,
		quickMode = false,
	},
}

ns.rolesList = { "Tanks", "Healers", "Melee", "Ranged", "Signup", "Standby" }
for _, v in ipairs(ns.rolesList) do
	ns.role[v] = {}
end

ns.colors = {
	["select"] = {1, 0, 0, 0.5}, -- Color when Selected
	["deselect"] = {0.3, 0.3, 0.3, 0.75}, -- Color when Deselected
	["disabled"] = {0.25, 0.25, 0.25, 0.25}, -- Color when Disabled, Gray was too light (0.5, 0.5, 0.5)
	["bordercolor"] = {0.65, 0.65, 0.65, 1}, -- Backdrop border color
}

--[[
CalendarStatus
=	Name
0	Invited
1	Available
2	Declined
3	Confirmed
4	Out
5	Standby
6	Signedup
7	NotSignedup
8	Tentative

CALENDAR_INVITESTATUS_INVITED		= 1;
CALENDAR_INVITESTATUS_ACCEPTED		= 2;
CALENDAR_INVITESTATUS_DECLINED		= 3;
CALENDAR_INVITESTATUS_CONFIRMED		= 4;
CALENDAR_INVITESTATUS_OUT			= 5;
CALENDAR_INVITESTATUS_STANDBY		= 6;
CALENDAR_INVITESTATUS_SIGNEDUP		= 7;
CALENDAR_INVITESTATUS_NOT_SIGNEDUP	= 8;
CALENDAR_INVITESTATUS_TENTATIVE		= 9;
]]

--------------------------------------------------------------------------------
-- Debug and Print
--------------------------------------------------------------------------------
	local function Debug(text, ...)
		if not db or not db.config.debug then return end

		if text then
			if text:match("%%[dfqsx%d%.]") then
				(DEBUG_CHAT_FRAME or (ChatFrame3:IsShown() and ChatFrame3 or (ChatFrame4:IsShown() and ChatFrame4 or DEFAULT_CHAT_FRAME))):AddMessage("|cffff9999"..ADDON_NAME..":|r " .. format(text, ...))
			else
				(DEBUG_CHAT_FRAME or (ChatFrame3:IsShown() and ChatFrame3 or (ChatFrame4:IsShown() and ChatFrame4 or DEFAULT_CHAT_FRAME))):AddMessage("|cffff9999"..ADDON_NAME..":|r " .. strjoin(" ", text, tostringall(...)))
			end
		end
	end

	local function Print(text, ...)
		if text then
			if text:match("%%[dfqs%d%.]") then
				DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00".. ADDON_NAME ..":|r " .. format(text, ...))
			else
				DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00".. ADDON_NAME ..":|r " .. strjoin(" ", text, tostringall(...)))
			end
		end
	end

--------------------------------------------------------------------------------
--	Local functions
--------------------------------------------------------------------------------
	--  DB  --------------------------------------------------------------------
	local function _initDB(db, defaults)
		if type(db) ~= "table" then db = {} end
		if type(defaults) ~= "table" then return db end
		for k, v in pairs(defaults) do
			if type(v) == "table" then
				db[k] = _initDB(db[k], v)
			elseif type(v) ~= type(db[k]) then
				db[k] = v
			end
		end
		return db
	end

	local function _cleanDB(db, defaults)
		if type(db) ~= "table" then return {} end
		if type(defaults) ~= "table" then return db end
		for k, v in pairs(db) do
			if type(v) == "table" then
				if not next(_cleanDB(v, defaults[k])) then
					-- Remove empty subtables
					db[k] = nil
				end
			elseif v == defaults[k] then
				-- Remove default values
				db[k] = nil
			end
		end
		return db
	end

	local function _removeOldEvents()
		if type(db.events) ~= "table" then return end
		local timeData = C_DateAndTime.GetCurrentCalendarTime() -- C_Calendar.GetDate()
		local month, year = timeData.month, timeData.year
		if db.events and year and month then -- Got DB and current date info
			for k, v in pairs(db.events) do
				if k < year then
					db.events[k] = nil
				else
					for i, _ in pairs(v) do
						if i < month then
							db.events[k][i] = nil
						end
					end
				end
			end
		end
	end

	local function _dbRoleSort(a, b)
		--[[	Sort ascending by timestamps. We always remove the first key
		when we hit the maximum of saved roles. We are using inner tables
		timetable values for sorting. Please send me feedback if you can come up
		with better way to do this.											]]--

		if a.timetable.day and a.timetable.month and a.timetable.year and
		b.timetable.day and b.timetable.month and b.timetable.year then
			return time(a.timetable) < time(b.timetable)
		else -- Failsafe
			return a.role < b.role
		end
	end

	local function _removeOldPlayers()
		if not db.config.autoRoleDecay then return end

		if type(db.roles) ~= "table" then return end
		local timeData = C_DateAndTime.GetCurrentCalendarTime() -- C_Calendar.GetDate()
		local month, day, year = timeData.month, timeData.monthDay, timeData.year
		month = month - db.config.autoRoleDecayTime
		if month <= 0 then
			month = month + 12
			year = year - 1
		end
		local timestamp = time({ ["day"] = day, ["month"] = month, ["year"] = year })
		if db.roles and timestamp then -- Got DB and timestamp
			for k, v in pairs(db.roles) do
				sort(db.roles[k], _dbRoleSort)
				for i in ipairs(v) do -- Remove old roles
					if time(db.roles[k][i].timetable) < timestamp then
						Debug("Old:", tostring(k), time(db.roles[k][i].timetable), "<", timestamp)
						tremove(db.roles[k], i)
					end
				end
				if db.roles[k].class and #db.roles[k] == 0 then -- Remove empty player tables, the actual "Remove old players"
					Debug("Empty:", tostring(k), db.roles[k].class)
					db.roles[k] = nil
				end
			end
		end
	end

	--  openEvent  -------------------------------------------------------------
	local function _getIndex(indexName)
		for i = 1, C_Calendar.GetNumInvites() do
			local inviteData = C_Calendar.EventGetInvite(i)
			local name = inviteData.name
			if name == indexName then
				return i
			end
		end
		return false
	end

	local roleTemp = {}
	local function _getRole(player)
		if not db.config.autoRole then return "" end

		if not db.roles[player] then return "" end

		wipe(roleTemp)
		for i = 1, #db.roles[player] do
			if not roleTemp[db.roles[player][i].role] then
				roleTemp[db.roles[player][i].role] = 1
			else
				roleTemp[db.roles[player][i].role] = roleTemp[db.roles[player][i].role] + 1
			end
		end

		local highestRole, highestCount = false, 0
		for k, v in pairs(roleTemp) do
			if v > highestCount then
				highestRole = tostring(k)
				highestCount = v
			end
		end

		return highestRole or ""
	end

	local function _updateRole(player, role, class, timetable)
		if not db.config.autoRole then return end

		if not player then return end

		if not db.roles[player] then
			db.roles[player] = {}
			db.roles[player].class = class
		end

		local found
		for _, v in ipairs(db.roles[player]) do
			if v.timetable and v.timetable.year == timetable.year and v.timetable.month == timetable.month and
				v.timetable.day == timetable.day and v.timetable.hour == timetable.hour and v.timetable.minute == timetable.minute then
				v.role = role
				found = true
				break
			end
		end

		if not found then
			db.roles[player][#db.roles[player]+1] = { ["timetable"] = timetable, ["role"] = role, }
		end

		sort(db.roles[player], _dbRoleSort)
		while #db.roles[player] > db.config.autoRoleCount do
			table.remove(db.roles[player], 1)
		end
	end

	local function _countSignups()
		local function _bottomText()
			Debug("_bottomText")

			-- Count players in different roles
			local numTanks, numHealers, numMelee, numRanged, numStandby = #ns.role["Tanks"], #ns.role["Healers"], #ns.role["Melee"], #ns.role["Ranged"], #ns.role["Standby"]

			local signupsString = L.Signups
			if ns.openEvent.difficulty == 16 and ns.numSignup == 20 then -- Mythic and 20 players
				signupsString = signupsString .. " " .. GREEN_FONT_COLOR_CODE .. ns.numSignup .. FONT_COLOR_CODE_CLOSE
			elseif ns.openEvent.difficulty == 16 then -- Mythic and not 20 players
				signupsString = signupsString .. " " .. RED_FONT_COLOR_CODE .. ns.numSignup .. FONT_COLOR_CODE_CLOSE
			elseif ns.numSignup >= 10 and ns.numSignup <= 30 then -- Between 10 and 30 players
				signupsString = signupsString .. " " .. GREEN_FONT_COLOR_CODE .. ns.numSignup .. FONT_COLOR_CODE_CLOSE
			else -- Not between 10 and 30 players
				signupsString = signupsString .. " " .. RED_FONT_COLOR_CODE .. ns.numSignup .. FONT_COLOR_CODE_CLOSE
			end

			local space = 1
			UIFrame.Container.bottom.s:SetText(signupsString..string.rep(" ", space).." "..L.NotReplied.." "..HIGHLIGHT_FONT_COLOR_CODE..ns.notReplied..FONT_COLOR_CODE_CLOSE..string.rep(" ", space).." "..L.Standbys.." "..HIGHLIGHT_FONT_COLOR_CODE..numStandby..FONT_COLOR_CODE_CLOSE.."\n"..L.Tanks.." "..HIGHLIGHT_FONT_COLOR_CODE..numTanks..FONT_COLOR_CODE_CLOSE..string.rep(" ", space).." "..L.Healers.." "..HIGHLIGHT_FONT_COLOR_CODE..numHealers..FONT_COLOR_CODE_CLOSE..string.rep(" ", space).." "..L.DPS.." "..HIGHLIGHT_FONT_COLOR_CODE..numMelee + numRanged..FONT_COLOR_CODE_CLOSE.." ("..HIGHLIGHT_FONT_COLOR_CODE..numMelee..FONT_COLOR_CODE_CLOSE.." + "..HIGHLIGHT_FONT_COLOR_CODE..numRanged..FONT_COLOR_CODE_CLOSE..")")

			while UIFrame.Container.bottom.s:GetStringWidth() < 309 and space < 11 do -- Expand the line by maxing out the space between text, and make it one step too long (Max width 318, but we want 5px marginal per side)
				space = space + 1
				UIFrame.Container.bottom.s:SetText(signupsString..string.rep(" ", space).." "..L.NotReplied.." "..HIGHLIGHT_FONT_COLOR_CODE..ns.notReplied..FONT_COLOR_CODE_CLOSE..string.rep(" ", space).." "..L.Standbys.." "..HIGHLIGHT_FONT_COLOR_CODE..numStandby..FONT_COLOR_CODE_CLOSE.."\n"..L.Tanks.." "..HIGHLIGHT_FONT_COLOR_CODE..numTanks..FONT_COLOR_CODE_CLOSE..string.rep(" ", space).." "..L.Healers.." "..HIGHLIGHT_FONT_COLOR_CODE..numHealers..FONT_COLOR_CODE_CLOSE..string.rep(" ", space).." "..L.DPS.." "..HIGHLIGHT_FONT_COLOR_CODE..numMelee + numRanged..FONT_COLOR_CODE_CLOSE.." ("..HIGHLIGHT_FONT_COLOR_CODE..numMelee..FONT_COLOR_CODE_CLOSE.." + "..HIGHLIGHT_FONT_COLOR_CODE..numRanged..FONT_COLOR_CODE_CLOSE..")")
			end

			if space > 0 then -- Now the line is too long, so reduce space by 1, but don't make smaller than 0
				space = space - 1
			end

			UIFrame.Container.bottom.s:SetText(signupsString..string.rep(" ", space).." "..L.NotReplied.." "..HIGHLIGHT_FONT_COLOR_CODE..ns.notReplied..FONT_COLOR_CODE_CLOSE..string.rep(" ", space).." "..L.Standbys.." "..HIGHLIGHT_FONT_COLOR_CODE..numStandby..FONT_COLOR_CODE_CLOSE.."\n"..L.Tanks.." "..HIGHLIGHT_FONT_COLOR_CODE..numTanks..FONT_COLOR_CODE_CLOSE..string.rep(" ", space).." "..L.Healers.." "..HIGHLIGHT_FONT_COLOR_CODE..numHealers..FONT_COLOR_CODE_CLOSE..string.rep(" ", space).." "..L.DPS.." "..HIGHLIGHT_FONT_COLOR_CODE..numMelee + numRanged..FONT_COLOR_CODE_CLOSE.." ("..HIGHLIGHT_FONT_COLOR_CODE..numMelee..FONT_COLOR_CODE_CLOSE.." + "..HIGHLIGHT_FONT_COLOR_CODE..numRanged..FONT_COLOR_CODE_CLOSE..")")
		end

		Debug("_countSignups")

		ns.numSignup = 0
		ns.notReplied = 0
		-- Throw them into role slots
		for k, _ in pairs(ns.openEvent["Players"]) do
			if ns.openEvent["Players"][k]["role"] == "" or ns.openEvent["Players"][k]["role"] == nil or ns.openEvent["Players"][k]["status"] == Enum.CalendarStatus.Invited then -- No role or Invited
				ns.openEvent["Players"][k]["role"] = "Signup"
				ns.notReplied = ns.notReplied + 1
			end
			if ns.openEvent["Players"][k]["status"] == Enum.CalendarStatus.Declined or ns.openEvent["Players"][k]["status"] == Enum.CalendarStatus.Out or ns.openEvent["Players"][k]["status"] == Enum.CalendarStatus.Tentative then -- Red or Tentative
				ns.openEvent["Players"][k]["role"] = "Signup"
			elseif ns.openEvent["Players"][k]["status"] == Enum.CalendarStatus.Standby then -- Standby
				ns.openEvent["Players"][k]["role"] = "Standby"
			end

			local found
			if ns.role[ns.openEvent["Players"][k]["role"]] then
				for i = #ns.role[ns.openEvent["Players"][k]["role"]], 1, -1 do
					found = false
					if ns.openEvent["Players"][k]["name"] == ns.role[ns.openEvent["Players"][k]["role"]][i]["name"] then
						found = true
						break
					end
				end
			end

			if not found and ns.role[ns.openEvent["Players"][k]["role"]] then
				table.insert(ns.role[ns.openEvent["Players"][k]["role"]], ns.openEvent["Players"][k])
			elseif not found then -- Fix case where player has unknown role
				table.insert(ns.role["Signup"], ns.openEvent["Players"][k])
				--ns.openEvent["Players"][k]["role"] = "Signup"
			end

			-- Count signups (Accepted, Confirmed and Signed Ups)
			if ns.openEvent["Players"][k]["status"] == Enum.CalendarStatus.Available or ns.openEvent["Players"][k]["status"] == Enum.CalendarStatus.Confirmed or ns.openEvent["Players"][k]["status"] == Enum.CalendarStatus.Signedup then
				if ns.openEvent["Players"][k]["role"] ~= "Signup" then
					_updateRole(ns.openEvent["Players"][k]["name"], ns.openEvent["Players"][k]["role"], ns.openEvent["Players"][k]["class"], ns.openEvent.timetable)
				end
				ns.numSignup = ns.numSignup + 1
			end
		end

		for _, v in ipairs(ns.rolesList) do -- Update roles
			sort(ns.role[v], ns.calStatusSort)
			ns.functions.updateScrollBar(_G[v], ns.role[v])
		end

		_bottomText()
	end

	local function _updateEventInfo(eventType)
		Debug("_updateEventInfo:", tostring(eventType))

		local eventData = C_Calendar.GetEventInfo()

		if not eventData or type(eventData) ~= "table" then
			Debug(">>>FEEL EMPTY INSIDE!")
			return
		end -- For some reason we didn't get the eventData

		if not eventType then -- eventType is 'nil' if function is called from anywhere other than CALENDAR_OPEN_EVENT
			Debug(">> BACKUP eventType:", eventType, "->", eventData.calendarType)
			eventType = eventData.calendarType
		end

		local title, creator, textureIndex = eventData.title, eventData.creator, tostring(eventData.textureIndex)
		local month, day, year, hour, minute = eventData.time.month, eventData.time.monthDay, eventData.time.year, eventData.time.hour, eventData.time.minute
		local hourminute = string.format("%02d%02d", hour, minute)

		if year and year < 2010 then
			Debug(">>>DIED HERE!")
			return
		end -- Don't create new event in DB everytime you start creating new event before actually creating the event.

		Debug(">>> 1: %s, 2: %s, 3: %s, 4: %d, 5: %d, 6: %d, 7: %d, 8: %d", title, creator, textureIndex, month, day, year, hour, minute)

		if title and creator and textureIndex and month and day and year and hour and minute then
			for _, v in ipairs(ns.rolesList) do -- Wipe Roles
				wipe(ns.role[v])
			end

			Debug("- %i %i %i %i%i %i-%s", year, month, day, hour, minute, textureIndex, creator)

			db.events[year] = db.events[year] or {}
			db.events[year][month] = db.events[year][month] or {}
			db.events[year][month][day] = db.events[year][month][day] or {}
			db.events[year][month][day][hourminute] = db.events[year][month][day][hourminute] or {}
			db.events[year][month][day][hourminute][textureIndex.."-"..creator] = db.events[year][month][day][hourminute][textureIndex.."-"..creator] or {}
			db.events[year][month][day][hourminute][textureIndex.."-"..creator]["Players"] = db.events[year][month][day][hourminute][textureIndex.."-"..creator]["Players"] or {}

			ns.openEvent = db.events[year][month][day][hourminute][textureIndex.."-"..creator]

			if not next(ns.openEvent["Players"]) then -- New event, create one
				Debug("- Created new DB entry %i-%s", textureIndex, creator)

				ns.openEvent.title = title -- Title for event
				UIFrame.title.s:SetFormattedText("%s - %s", ADDON_NAME, ns.openEvent.title)
				ns.openEvent.type = eventType
				ns.openEvent.timetable = { ["hour"] = hour, ["min"] = minute, ["day"] = day, ["month"] = month, ["year"] = year }
				ns.openEvent.difficulty = db.config.defaultDifficulty -- Default
				UIFrame.Container.ED:SetSelectedID(ns.openEvent.difficulty - difficultyOffset)

				for i = 1, C_Calendar.GetNumInvites() do -- Insert names into table
					local inviteData = C_Calendar.EventGetInvite(i)
					local name, level, classFilename, inviteStatus, modStatus = inviteData.name, inviteData.level, inviteData.classFilename, inviteData.inviteStatus, inviteData.modStatus
					if db.config.nameDebug then
						Debug(">>> %s, %d, %s, %d, %s", tostring(name), tonumber(level), tostring(classFilename), tonumber(inviteStatus), tostring(modStatus))
					end

					if name and name ~= "" then
						if inviteStatus == Enum.CalendarStatus.Available or inviteStatus == Enum.CalendarStatus.Confirmed or inviteStatus == Enum.CalendarStatus.Signedup then
							if inviteStatus ~= Enum.CalendarStatus.Confirmed and db.config.autoConfirm and C_Calendar.EventCanEdit() then -- Confirm
								local index = _getIndex(name)
								if index then
									C_Calendar.EventSetInviteStatus(index, Enum.CalendarStatus.Confirmed) -- The real stuff
									inviteStatus = Enum.CalendarStatus.Confirmed
								end
							end

							ns.openEvent["Players"][name] = { name = name, class = classFilename, level = level, status = inviteStatus, role = _getRole(name), moderator = modStatus }
						else
							ns.openEvent["Players"][name] = { name = name, class = classFilename, level = level, status = inviteStatus, role = "", moderator = modStatus }
						end
					else
						Debug("No name for", i)
					end
				end

				-- Now we have player info, let's see if we can enable the MIB
				--[[
				if ns.openEvent and ns.openEvent["Players"] ~= nil and ns.openEvent["Players"] ~= "" and C_Calendar.EventCanEdit() then
					Debug("MIB Enabled")
					UIFrame.Container.MIB:Enable()
				else
					Debug("MIB Disabled")
					UIFrame.Container.MIB:Disable()
				end
				]]
			else -- Old event, update it
				Debug("- Found DB entry %i-%s, updating", textureIndex, creator)

				ns.openEvent.title = title -- Update title
				ns.openEvent.timetable = ns.openEvent.timetable or { ["hour"] = hour, ["min"] = minute, ["day"] = day, ["month"] = month, ["year"] = year }
				UIFrame.title.s:SetFormattedText("%s - %s", ADDON_NAME, ns.openEvent.title)
				UIFrame.Container.ED:SetSelectedID(ns.openEvent.difficulty - difficultyOffset)

				for k, _ in pairs(ns.openEvent["Players"]) do -- Delete removed names (maybe someone ragequit or changed guild)
					local found = false
					for i = 1, C_Calendar.GetNumInvites() do
						found = false
						local inviteData = C_Calendar.EventGetInvite(i)
						local name = inviteData.name
						if name and name ~= "" and ns.openEvent["Players"][k]["name"] == name then
							found = true -- Mr "name" didn't ragequit
							break
						end
					end
					if not found then -- Aha! The usual suspect, remove old name
						--table.remove(ns.openEvent["Players"][k])
						if ns.openEvent["Players"][k]["name"] == ns.playerName then -- If you remove yourself from event
							Debug("- I removed myself from event %i-%s", textureIndex, creator)

							ns.openEvent = nil -- Remove the whole event
							return
						end

						Debug("- Removed \"%s\" from event %i-%s", tostring(ns.openEvent["Players"][k]["name"]), tonumber(textureIndex), tostring(creator))

						Print(L.RemovedFromEvent, RAID_CLASS_COLORS[ns.openEvent["Players"][k]["class"]].colorStr or "ffffffff", ns.openEvent["Players"][k]["name"], ns.openEvent.title, ns.openEvent.timetable.day or 0, ns.openEvent.timetable.month or 0, ns.openEvent.timetable.year or 0, ns.openEvent.timetable.hour or 0, ns.openEvent.timetable.min or 0)

						ns.openEvent["Players"][k] = nil
					end
				end

				for i = 1, C_Calendar.GetNumInvites() do -- Check for new friends
					local inviteData = C_Calendar.EventGetInvite(i)
					local name, level, classFilename, inviteStatus, modStatus = inviteData.name, inviteData.level, inviteData.classFilename, inviteData.inviteStatus, inviteData.modStatus
					if db.config.nameDebug then
						Debug(">>> %s, %d, %s, %d, %s", tostring(name), tonumber(level), tostring(classFilename), tonumber(inviteStatus), tostring(modStatus))
					end

					if name and name ~= "" and not ns.openEvent["Players"][name] then -- Insert new name if found
						if inviteStatus == Enum.CalendarStatus.Available or inviteStatus == Enum.CalendarStatus.Confirmed or inviteStatus == Enum.CalendarStatus.Signedup then
							if inviteStatus ~= Enum.CalendarStatus.Confirmed and db.config.autoConfirm and C_Calendar.EventCanEdit() then -- Confirm
								local index = _getIndex(name)
								if index then
									C_Calendar.EventSetInviteStatus(index, Enum.CalendarStatus.Confirmed) -- The real stuff
									inviteStatus = Enum.CalendarStatus.Confirmed
								end
							end

							ns.openEvent["Players"][name] = {name = name, class = classFilename, level = level, status = inviteStatus, role = _getRole(name), moderator = modStatus}
						else
							ns.openEvent["Players"][name] = {name = name, class = classFilename, level = level, status = inviteStatus, role = "", moderator = modStatus}
						end
					elseif name and name ~= "" and ns.openEvent["Players"][name] then -- Found old friend instead, let's update his/her level, inviteStatus and modStatus
						ns.openEvent["Players"][name]["level"] = level -- Level ups?
						ns.openEvent["Players"][name]["status"] = inviteStatus -- Did you accept the invitation or were you confirmed since we last saw?
						ns.openEvent["Players"][name]["moderator"] = modStatus -- Ranked up to MODERATOR of event?
						if (inviteStatus == Enum.CalendarStatus.Available or inviteStatus == Enum.CalendarStatus.Confirmed or inviteStatus == Enum.CalendarStatus.Signedup) then
							if inviteStatus ~= Enum.CalendarStatus.Confirmed and db.config.autoConfirm and C_Calendar.EventCanEdit() then -- Confirm
								ns.openEvent["Players"][name]["status"] = Enum.CalendarStatus.Confirmed
								local index = _getIndex(name)
								if index then
									C_Calendar.EventSetInviteStatus(index, Enum.CalendarStatus.Confirmed) -- The real stuff
									inviteStatus = Enum.CalendarStatus.Confirmed
								end
							end

							if ns.openEvent["Players"][name]["role"] == "" or ns.openEvent["Players"][name]["role"] == nil or
							ns.openEvent["Players"][name]["role"] == "Signup" or ns.openEvent["Players"][name]["role"] == "Standby" then -- Auto-Roles
								ns.openEvent["Players"][name]["role"] = _getRole(name) -- Update Role
							end
						end
					else -- This shouldn't happen
						Debug("- ??? Found unnamed character \"%s\" from event %i-%s", tostring(name), tonumber(textureIndex), tostring(creator))
					end
				end
				-- List is now up to date

				-- Now we have the updated player info, let's see if we can enable the Mass Invite Button
				--[[
				if C_Calendar.EventCanEdit() then
					Debug("MIB Enabled")
					UIFrame.Container.MIB:Enable()
				else
					Debug("MIB Disabled")
					UIFrame.Container.MIB:Disable()
				end
				]]
			end

			_countSignups()
			if not db.config.nameDebug then
				Debug(">>> NumInvites: %d, numSignup: %d, notReplied: %d", C_Calendar.GetNumInvites(), ns.numSignup, ns.notReplied)
			end

			-- Let's see if we can enable the Mass Invite Button
			if C_Calendar.EventCanEdit() then
				Debug("MIB Enabled")
				UIFrame.Container.MIB:Enable()
			else
				Debug("MIB Disabled")
				UIFrame.Container.MIB:Disable()
			end
		else
			Debug(">>> ??? Bad data")
		end
	end

	local function _transaction(sparent, source, value, tparent, target)
		-- Transaction players between role-tables
		Debug("_transaction %s (%s) - %i - %s (%s)", source, tostring(sparent:GetName()), value, target, tostring(tparent:GetName()))

		--[[
			enumeration Enum.CalendarStatus
			Num Values: 9
			Min Value: 0
			Max Value: 8
			Values
				0 Invited
				1 Available
				2 Declined
				3 Confirmed
				4 Out
				5 Standby
				6 Signedup
				7 NotSignedup
				8 Tentative
		]]

		ns.role[source][value]["role"] = target
		ns.openEvent["Players"][ns.role[source][value]["name"]]["role"] = target
		local index = _getIndex(ns.role[source][value]["name"])
		if target == "Standby" then -- Change status to Standby if moved to the group
			if index and C_Calendar.EventCanEdit() then -- Put player on Standby, but only if you have the rights
				ns.role[source][value]["status"] = Enum.CalendarStatus.Standby
				ns.openEvent["Players"][ns.role[source][value]["name"]]["status"] = Enum.CalendarStatus.Standby

				C_Calendar.EventSetInviteStatus(index, Enum.CalendarStatus.Standby) -- The real stuff
			elseif ns.role[source][value]["name"] == ns.playerName and index and not C_Calendar.EventCanEdit() then -- Set Tentative instead if you can't put yourself to Standby
				ns.role[source][value]["status"] = Enum.CalendarStatus.Tentative
				ns.openEvent["Players"][ns.role[source][value]["name"]]["status"] = Enum.CalendarStatus.Tentative

				C_Calendar.EventTentative()
			end
		elseif target ~= "Signup" then -- Change status to Confirmed if moved to other than Signup group
			if index and ns.role[source][value]["name"] == ns.playerName then -- Self
				if db.config.autoConfirm and C_Calendar.EventCanEdit() then -- Confirm
					ns.role[source][value]["status"] = Enum.CalendarStatus.Confirmed
					ns.openEvent["Players"][ns.role[source][value]["name"]]["status"] = Enum.CalendarStatus.Confirmed

					C_Calendar.EventSetInviteStatus(index, Enum.CalendarStatus.Confirmed) -- The real stuff
				elseif ns.role[source][value]["status"] ~= Enum.CalendarStatus.Confirmed and ns.openEvent.type and ns.openEvent.type == "GUILD_EVENT" then -- Sign up
					ns.role[source][value]["status"] = Enum.CalendarStatus.Signedup
					ns.openEvent["Players"][ns.role[source][value]["name"]]["status"] = Enum.CalendarStatus.Signedup

					if C_Calendar.EventCanEdit() then
						C_Calendar.EventSetInviteStatus(index, Enum.CalendarStatus.Signedup) -- The real stuff
					else
						C_Calendar.EventAvailable()
					end
				elseif ns.role[source][value]["status"] ~= Enum.CalendarStatus.Confirmed then -- Accept
					ns.role[source][value]["status"] = Enum.CalendarStatus.Available
					ns.openEvent["Players"][ns.role[source][value]["name"]]["status"] = Enum.CalendarStatus.Available

					if C_Calendar.EventCanEdit() then
						C_Calendar.EventSetInviteStatus(index, Enum.CalendarStatus.Available) -- The real stuff
					else
						C_Calendar.EventAvailable()
					end
				end
			elseif db.config.autoConfirm and index and C_Calendar.EventCanEdit() then -- Confirm player, but only if you have the rights
				ns.role[source][value]["status"] = Enum.CalendarStatus.Confirmed
				ns.openEvent["Players"][ns.role[source][value]["name"]]["status"] = Enum.CalendarStatus.Confirmed

				C_Calendar.EventSetInviteStatus(index, Enum.CalendarStatus.Confirmed) -- The real stuff
			elseif
				not db.config.autoConfirm and index and C_Calendar.EventCanEdit() and
				(
					ns.openEvent["Players"][ns.role[source][value]["name"]]["status"] ~= Enum.CalendarStatus.Available and
					ns.openEvent["Players"][ns.role[source][value]["name"]]["status"] ~= Enum.CalendarStatus.Confirmed and
					ns.openEvent["Players"][ns.role[source][value]["name"]]["status"] ~= Enum.CalendarStatus.Signedup
				) then -- Not Confirming, but no accepted status yet, set to Accepted.

				-- GUILD_EVENT -> Signedup
				-- PLAYER -> Accepted
				-- COMMUNITY_EVENT -> Signedup (https://www.curseforge.com/wow/addons/loihcal/issues/7)
				if ns.openEvent.type and (ns.openEvent.type == "GUILD_EVENT" or ns.openEvent.type == "COMMUNITY_EVENT") then
					ns.role[source][value]["status"] = Enum.CalendarStatus.Signedup
					ns.openEvent["Players"][ns.role[source][value]["name"]]["status"] = Enum.CalendarStatus.Signedup

					C_Calendar.EventSetInviteStatus(index, Enum.CalendarStatus.Signedup) -- The real stuff
				else
					ns.role[source][value]["status"] = Enum.CalendarStatus.Available
					ns.openEvent["Players"][ns.role[source][value]["name"]]["status"] = Enum.CalendarStatus.Available

					C_Calendar.EventSetInviteStatus(index, Enum.CalendarStatus.Available) -- The real stuff
				end
			end
		elseif target == "Signup" and ns.role[source][value]["name"] == ns.playerName then
			ns.role[source][value]["status"] = Enum.CalendarStatus.Declined
			ns.openEvent["Players"][ns.role[source][value]["name"]]["status"] = Enum.CalendarStatus.Declined

			C_Calendar.EventDecline()
		end

		Debug("- Transaction Role %s / %s", ns.role[source][value]["role"], ns.openEvent["Players"][ns.role[source][value]["name"]]["role"])

		table.insert(ns.role[target], ns.role[source][value])
		table.remove(ns.role[source], value)

		ns.functions.updateScrollBar(tparent, ns.role[target])
		ns.functions.updateScrollBar(sparent, ns.role[source])

		_countSignups()
	end

	--  Mass Invite  -----------------------------------------------------------
	local function _massInvite()
		local function _filterMsg(self, event, msg, ...)
			Debug("- _filterMsg, %s, %s", event, msg == ns.whisperLine and "true" or "false")

			if event == "CHAT_MSG_WHISPER_INFORM" and msg == ns.whisperLine then
				return true
			elseif event == "CHAT_MSG_WHISPER" and msg == ns.whisperLine then
				return true
			elseif string.match(msg, ERR_INVITE_PLAYER_S) then
				return true
			else
				return false, msg, ...
			end
		end

		local function _removeMsgFilter()
			Debug("- _removeMsgFilter")

			ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", _filterMsg)
			ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER_INFORM", _filterMsg)
			ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER", _filterMsg)
		end

		Debug("_massInvite")

		if #ns.inviteTable == 0 then return end

		ns.whisperLine = ADDON_NAME..": "..string.format(db.config.InvWhisper, ns.openEvent.title)
		if db.config.sendWhisper then
			Debug("--Whisper: %s", ns.whisperLine)
		else
			Debug("--NO WHISPER!")
		end

		--EventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
		--ns.massInviteNeedRaidSetup = true

		local timer, interval = 0, 0.25
		local inRaid = math.max(GetNumGroupMembers(LE_PARTY_CATEGORY_HOME), 1) -- returns 0 if you aren't in a group but we want to include yourself
		local invited, total = 0, #ns.inviteTable + 1 -- You are alway "already in the group" and inviteTable doesn't include you
		local lastInvited = ""

		UIFrame.Container.MIB:Disable() -- Just to be safe
		UIFrame.InvBars:Show()

		--sort(inviteTable) -- Invite in alphabetical order

		ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", _filterMsg)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", _filterMsg)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", _filterMsg)

		--[[local i, maxInvites = 1, (total - inRaid)
		while invited < maxInvites and i <= C_Calendar.GetNumInvites() do
			local inviteInfo = C_Calendar.EventGetInvite(i)
			if
				inviteInfo.name ~= ns.playerName and (not UnitInParty(inviteInfo.name)) and (not UnitInRaid(inviteInfo.name)) and
				(inviteInfo.inviteStatus == CALENDAR_INVITESTATUS_ACCEPTED or inviteInfo.inviteStatus == CALENDAR_INVITESTATUS_CONFIRMED or
				inviteInfo.inviteStatus == CALENDAR_INVITESTATUS_SIGNEDUP) -- or inviteInfo.inviteStatus == CALENDAR_INVITESTATUS_TENTATIVE)
			then
				if db.config.sendWhisper then
					SendChatMessage(ns.whisperLine, "WHISPER", nil, inviteInfo.name)
				end
				C_PartyInfo.InviteUnit(inviteInfo.name)
				lastInvited = inviteInfo.name
				invited = invited + 1

				for k = 1, #ns.inviteTable do
					if inviteInfo.name == ns.inviteTable[k] then
						table.remove(ns.inviteTable, k)
					end
				end

				UIFrame.InvBars.B.s:SetFormattedText("%d/%d %s", invited, maxInvites, lastInvited)
			end
			Print("Invites:", i, invited, maxInvites, inRaid, total)
			i = i + 1
		end]]

		local lastInviteCount, lastInRaid = 0, 0
		local inviteTimer = 0
		UIFrame:SetScript("OnUpdate", function(self, elapsed)
			timer = timer + elapsed
			inviteTimer = inviteTimer + elapsed
			while timer >= interval do -- Give this enough time to do the changes
				if #ns.inviteTable == 0 then
					Debug("- InviteTable empty")

					UIFrame.Container.MIB:Enable()
					UIFrame.InvBars:Hide()
					UIFrame:SetScript("OnUpdate", nil)
					--EventFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
					ns.massInviteNeedRaidSetup = false
					--C_Timer.After(2, _removeMsgFilter)
					C_Timer.After(60, _removeMsgFilter)

					break -- To prevent InviteUnit(nil)
				end

				inRaid = math.max(GetNumGroupMembers(LE_PARTY_CATEGORY_HOME), 1) -- returns 0 if you aren't in a group but we want to include yourself
				--table.remove(ns.inviteTable, 1) -- Debug
				--Print("OnUpdate", inviteTimer, #ns.inviteTable, #ns.inviteTable * inviteTimer) -- Debug

				if lastInRaid ~= inRaid then
					for i = 1, GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) do
						local name = GetRaidRosterInfo(i)
						for k = 1, #ns.inviteTable do
							if name == ns.inviteTable[k] then -- Already in group
								table.remove(ns.inviteTable, k) -- Not going to invite you again
								--inRaid = inRaid + 1
							end
						end
					end

					lastInRaid = inRaid
				end

				if #ns.inviteTable > 0 then -- Still someone in the table
					Debug("- Inviting \"%s\"", tostring(ns.inviteTable[1]))

					if db.config.sendWhisper then
						SendChatMessage(ns.whisperLine, "WHISPER", nil, ns.inviteTable[1]) -- 1. Whisper
					end
					--InviteUnit(ns.inviteTable[1]) -- 2. Invite
					C_PartyInfo.InviteUnit(ns.inviteTable[1]) -- 2. Invite
					local lastInvited = table.remove(ns.inviteTable, 1) -- 3. Remove from queue

					invited = invited + 1
					UIFrame.InvBars.B.s:SetFormattedText("%d/%d %s", invited, total - inRaid, lastInvited)
				end
				timer = timer - interval

				if inRaid + invited > total then
					UIFrame.InvBars.R:SetWidth(240 * inRaid/(inRaid + invited))
					UIFrame.InvBars.I:SetWidth(240 * invited/(inRaid + invited))
				else
					UIFrame.InvBars.R:SetWidth(240 * inRaid/total)
					UIFrame.InvBars.I:SetWidth(240 * invited/total)
				end

				--UIFrame.InvBars.t:SetFormattedText(L.TimeEstimate, #ns.inviteTable * interval)
				if lastInviteCount ~= invited then
					UIFrame.InvBars.t:SetFormattedText(L.TimeEstimate, #ns.inviteTable * inviteTimer)
					lastInviteCount = invited
					inviteTimer = 0
				end
			end
		end)
	end

	--  Skinning  --------------------------------------------------------------
	local function _skinFrames()
		local function _elvSkin(frame, type)
			if not ns.Elv or not frame or not type then return end

			local E, L, V, P, G = unpack(ElvUI)
			local S = E:GetModule('Skins')

			if type == "frame" then
				frame:StripTextures()
				--frame:SetTemplate("Default", true)
				frame:SetTemplate("Transparent", true)
			elseif type == "button" then
				S:HandleButton(frame, true)
			elseif type == "scrollbar" then
				S:HandleScrollBar(frame)
			elseif type == "tab" then
				S:HandleTab(frame)
			elseif type == "ddm" then
				S:HandleDropDownBox(frame, frame:GetWidth())
			elseif type == "checkbox" then
				S:HandleCheckBox(frame)
			elseif type == "close" then
				S:HandleCloseButton(frame)
			elseif type == "editbox" then
				S:HandleEditBox(frame)
			end
		end

		if not ns.Elv or not db.config.elvSkin then return end

		_elvSkin(UIFrame, "frame")
		_elvSkin(UIFrame.close, "close")

		_elvSkin(UIFrame.Container.Tanks, "frame")
		_elvSkin(UIFrame.Container.Healers, "frame")
		_elvSkin(UIFrame.Container.Melee, "frame")
		_elvSkin(UIFrame.Container.Ranged, "frame")
		_elvSkin(UIFrame.Container.Signup, "frame")
		_elvSkin(UIFrame.Container.Standby, "frame")
		_elvSkin(TanksScrollBarScrollBar, "scrollbar")
		_elvSkin(HealersScrollBarScrollBar, "scrollbar")
		_elvSkin(MeleeScrollBarScrollBar, "scrollbar")
		_elvSkin(RangedScrollBarScrollBar, "scrollbar")
		_elvSkin(SignupScrollBarScrollBar, "scrollbar")
		_elvSkin(StandbyScrollBarScrollBar, "scrollbar")
		_elvSkin(UIFrame.Container.ED, "ddm")
		_elvSkin(UIFrame.Container.MIB, "button")
		_elvSkin(UIFrame.InvBars.Cancel, "button")

		_elvSkin(UIFrame.Roles.AutoRoles, "frame")
		_elvSkin(AutoRolesScrollBarScrollBar, "scrollbar")
		_elvSkin(UIFrame.Roles.TB, "button")
		_elvSkin(UIFrame.Roles.HB, "button")
		_elvSkin(UIFrame.Roles.MB, "button")
		_elvSkin(UIFrame.Roles.RB, "button")
		_elvSkin(UIFrame.Roles.REM, "button")

		_elvSkin(TabsFrame.tab1, "tab")
		_elvSkin(TabsFrame.tab2, "tab")
		_elvSkin(TabsFrame.tab3, "tab")

		ns.skinned = true
	end

--------------------------------------------------------------------------------
--	Frame functions
--------------------------------------------------------------------------------
	--  Sort roles  ------------------------------------------------------------
	function ns.calStatusSort(a, b)
		-- Make sure the "Green" invite statuses pop on top of the list
		local x, y = a["status"], b["status"]

		if x == 2 or x == 4 or x == 7 then
			x = x + 8
		end
		if y == 2 or y == 4 or y == 7 then
			y = y + 8
		end
		-- If "Signup"-role, put Player to first position
		if (a["role"] == "Signup" or a["role"] == "") and (a["name"] == ns.playerName or b["name"] == ns.playerName) then
			if a["name"] == ns.playerName then
				x = x + 20
			else
				y = y + 20
			end
		end

		if x == y then -- If same status, then return alphabetical order
			return a["name"] < b["name"]
		else
			return x > y -- Status order (with Green statuses on top of the list)
		end
	end

	--  Event roles scrollbars  ------------------------------------------------
	local function _colorMe(input)
		-- Return class-color table or colorstring
		if type(input) == "string" then -- Class
			return RAID_CLASS_COLORS[input] or RAID_CLASS_COLORS["PRIEST"]
		else -- Numeric
			--[[
			if input == 3 or input == 5 then -- Red
				return RED_FONT_COLOR_CODE
			elseif input == 6 or input == 9 then -- Orange
				return ORANGE_FONT_COLOR_CODE
			elseif input == 2 or input == 4 or input == 7 then -- Green
				return GREEN_FONT_COLOR_CODE
			else -- (1, 8) Normal text
				return NORMAL_FONT_COLOR_CODE
			end
			]]
			local hexGen = CALENDAR_INVITESTATUS_INFO[input] and CALENDAR_INVITESTATUS_INFO[input].color or CALENDAR_INVITESTATUS_INFO["UNKNOWN"].color
			return hexGen:GenerateHexColor()
		end
	end

	function ns.functions.titleOnClick(self, button)
		Debug(">titleOnClick \"%s\"", self:GetName())

		-- Quick Mode
		if db.config.quickMode then return end

		if not ns.selected then -- Nothing selected, selecting pressed group
			ns.selected = self
			self.t:SetColorTexture(unpack(ns.colors.select))
		elseif ns.selected ~= self then -- Deselect previous group and select pressed group
			ns.selected.t:SetColorTexture(unpack(ns.colors.deselect))
			ns.selected = self
			self.t:SetColorTexture(unpack(ns.colors.select))
		else -- Deselcting already selected group
			ns.selected = false
			self.t:SetColorTexture(unpack(ns.colors.deselect))
		end
	end

	function ns.functions.slotOnClick(self, button)
		Debug(">slotOnClick \"%s\" %i (%i), %s", self:GetName(), self.inviteIndex, self.value, button)

		if IsAltKeyDown() then
			if button == "RightButton" then
				Debug("--Toggle CalendarContextMenu")

				if C_Calendar.EventCanEdit() then
					-- This is all new to me and I really hope this doesn't cause any taints...
					CalendarContextMenu_Toggle(self, CalendarCreateEventInviteContextMenu_Initialize, "cursor", 3, -3, self)
				else
					CalendarContextMenu_Toggle(self, CalendarViewEventInviteContextMenu_Initialize, "cursor", 3, -3, self)
				end

				-- Fix the ContextMenu going behind LOIHCalFrame
				CalendarContextMenu:SetParent(self)
				CalendarContextMenu:SetFrameStrata("FULLSCREEN")
				CalendarContextMenu:SetScript("OnHide", function(self)
					CalendarContextMenu:SetParent(CalendarFrame)
					CalendarContextMenu:SetFrameStrata("FULLSCREEN")
					CalendarContextMenu:SetScript("OnHide", nil)
				end)

				--[[	How could I make this tick? CalendarContextMenu is used on
				different things in Blizzard Calendar and I need to Init it for
				EventInvites somehow?											]]--
				--ToggleDropDownMenu(1, nil, CalendarContextMenu, "cursor", 0, 0)
			else
				Debug("--Tentative/Decline")

				local rolePointer = ns.role[self:GetParent():GetName()][self.value]
				if rolePointer["name"] == ns.playerName then
					if rolePointer["status"] ~= Enum.CalendarStatus.Tentative then -- Tentative
						rolePointer["status"] = Enum.CalendarStatus.Tentative
						ns.openEvent["Players"][rolePointer["name"]]["status"] = Enum.CalendarStatus.Tentative
						C_Calendar.EventTentative()
					else -- Declined
						rolePointer["status"] = Enum.CalendarStatus.Declined
						ns.openEvent["Players"][rolePointer["name"]]["status"] = Enum.CalendarStatus.Declined
						C_Calendar.EventDecline()
					end
				end
			end
		end

		--[[	If button is "disabled", don't allow any other actions below
		this point. Can't use real Disable() anymore because it prevents
		catching the Toggle ContextMenu clicks.								]]--
		if not self.enabled then return end

		-- Quick Mode
		if db.config.quickMode and not IsAltKeyDown() then
			Debug("--QuickMode:", button, "Shift:", tostring(IsShiftKeyDown()), "Ctrl:", tostring(IsControlKeyDown()))

			if IsShiftKeyDown() and not IsControlKeyDown() then
				if button == "LeftButton" then
					ns.selected = UIFrame.Container.Tanks.title
				elseif button == "RightButton" then
					ns.selected = UIFrame.Container.Healers.title
				end
			elseif not IsShiftKeyDown() and IsControlKeyDown() then
				if button == "LeftButton" then
					ns.selected = UIFrame.Container.Signup.title
				elseif button == "RightButton" then
					ns.selected = UIFrame.Container.Standby.title
				end
			else
				if button == "LeftButton" then
					ns.selected = UIFrame.Container.Melee.title
				elseif button == "RightButton" then
					ns.selected = UIFrame.Container.Ranged.title
				end
			end
		end

		--if ns.selected and ns.selected:GetParent() ~= self:GetParent() and not IsAltKeyDown() then
		if ns.selected and not IsAltKeyDown() then
			local source = self:GetParent()
			source.name = self:GetParent():GetName()
			local target = ns.selected:GetParent()
			target.name = ns.selected:GetParent():GetName()
			local value = self.value

			_transaction(source, source.name, value, target, target.name) -- Pointer, Name, Row#, Pointer, Name
		end
	end

	-- Faux Scroller
	function ns.functions.updateScrollBar(self, tbl) -- Update Slot Buttons
		local calStatus = { -- Invite statuses
			--[[
			[CALENDAR_INVITESTATUS_INVITED] = L.Inv, --CALENDAR_INVITESTATUS_INVITED (1)
			[CALENDAR_INVITESTATUS_ACCEPTED] = L.Acc, --CALENDAR_INVITESTATUS_ACCEPTED (2)
			[CALENDAR_INVITESTATUS_DECLINED] = L.Dec, --CALENDAR_INVITESTATUS_DECLINED (3)
			[CALENDAR_INVITESTATUS_CONFIRMED] = L.Con, --CALENDAR_INVITESTATUS_CONFIRMED (4)
			[CALENDAR_INVITESTATUS_OUT] = L.Out, --CALENDAR_INVITESTATUS_OUT (5)
			[CALENDAR_INVITESTATUS_STANDBY] = L.Sta, --CALENDAR_INVITESTATUS_STANDBY (6)
			[CALENDAR_INVITESTATUS_SIGNEDUP] = L.Sig, --CALENDAR_INVITESTATUS_SIGNEDUP (7)
			[CALENDAR_INVITESTATUS_NOT_SIGNEDUP] = L.Not, --CALENDAR_INVITESTATUS_NOT_SIGNEDUP (8)
			[CALENDAR_INVITESTATUS_TENTATIVE] = L.Ten --CALENDAR_INVITESTATUS_TENTATIVE (9)
			]]

			--[[
				enumeration Enum.CalendarStatus
				Num Values: 9
				Min Value: 0
				Max Value: 8
				Values
					0 Invited
					1 Available
					2 Declined
					3 Confirmed
					4 Out
					5 Standby
					6 Signedup
					7 NotSignedup
					8 Tentative
			]]
			[Enum.CalendarStatus.Invited] = L.Inv,
			[Enum.CalendarStatus.Available] = L.Acc,
			[Enum.CalendarStatus.Declined] = L.Dec,
			[Enum.CalendarStatus.Confirmed] = L.Con,
			[Enum.CalendarStatus.Out] = L.Out,
			[Enum.CalendarStatus.Standby] = L.Sta,
			[Enum.CalendarStatus.Signedup] = L.Sig,
			[Enum.CalendarStatus.NotSignedup] = L.Not,
			[Enum.CalendarStatus.Tentative] = L.Ten
		}
		local maxValue = #tbl
		local slots = 10
		if self.name == "Tanks" or self.name == "Healers" or self.name == "Standby" then
			slots = 6
		elseif self.name == nil then -- If we update from updatePlayers()
			if self:GetName() == "Tanks" or self:GetName() == "Healers" or self:GetName() == "Standby" then
				slots = 6
			end
		end

		FauxScrollFrame_Update(self.scrollBar, maxValue, slots, 15) -- Scrollbar, max items on scrollbar, max visible items on scrollbar and height of item on scrollbar
		local offset = FauxScrollFrame_GetOffset(self.scrollBar)
		for i = 1, slots do
			local value = i + offset
			if value <= maxValue then
				local row = self.rows[i]

				if db.config.nameDebug then
					Debug("<<< %s, %s, %s", tostring(value), _getIndex(tbl[value].name) or "false", tbl[value].name)
					Debug("<<< %s, %s, %s, %s", tostring(tbl[value].level), tostring(tbl[value].status), tostring(tbl[value].class), tostring(tbl[value].moderator))
				end

				-- Draw the player buttons
				row.value = value
				row.inviteIndex = _getIndex(tbl[value]["name"]) or -1 -- CalendarContextMenu needs this
				row.name = tbl[value]["name"]
				if row.name:match("^([^%-]+)%-(.*)$") then -- Player is from another realm
					row.name = select(1, row.name:match("^([^%-]+)%-(.*)$"))..INTERACTIVE_SERVER_LABEL -- Shorten realm name into (#)
				end
				--gsub("%-.+", "*")
				row.level = tbl[value]["level"]
				row.status = tbl[value]["status"]
				row.class = tbl[value]["class"]
				row.moderator = tbl[value]["moderator"]

				row.cc = _colorMe(row.class) or {r = 1, g = 1, b = 1, colorStr = "ffffffff"}
				row.sc = "|c" .. _colorMe(row.status) or "|cffffffff"


				row.fstatus:SetText(" "..row.sc..calStatus[row.status].."|r")
				local modStatus = ""
				if row.moderator == "CREATOR" then
					--row.fname:SetText("+|c"..row.cc.colorStr..row.name.."|r    ")
					--modStatus = "+"
					modStatus = "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:0|t"
				elseif row.moderator == "MODERATOR" then
					--row.fname:SetText("^|c"..row.cc.colorStr..row.name.."|r    ")
					--modStatus = "^"
					modStatus = "|TInterface\\GroupFrame\\UI-Group-AssistantIcon:0|t"
				else
					--row.fname:SetText("|c"..row.cc.colorStr..row.name.."|r   ")
					modStatus = ""
				end

				local autoRoleStatus = ""
				if db.config.autoRoleDecay and (not db.roles[tbl[value]["name"]] or #db.roles[tbl[value]["name"]] == 0) then -- No autorole or role decayed
					autoRoleStatus = RED_FONT_COLOR_CODE.."@"..FONT_COLOR_CODE_CLOSE
				end

				if ns.groupSize > 0 then
					if UnitInRaid(tbl[value]["name"]) then
						row.fname:SetText("["..modStatus..autoRoleStatus.."|c"..row.cc.colorStr..row.name.."|r"..autoRoleStatus.."]   ")
					else
						row.fname:SetText(modStatus..autoRoleStatus.."|c"..row.cc.colorStr..row.name.."|r"..autoRoleStatus.."   ")
					end
				else
					row.fname:SetText(modStatus..autoRoleStatus.."|c"..row.cc.colorStr..row.name.."|r"..autoRoleStatus.."   ")
				end

				row.flevel:SetText(row.level.."      ")

				row.t:SetColorTexture(row.cc.r, row.cc.g, row.cc.b, 0.35)
				row:Show()

				-- Live Version
				if row.status == Enum.CalendarStatus.Available or row.status == Enum.CalendarStatus.Confirmed or row.status == Enum.CalendarStatus.Signedup or row.status == Enum.CalendarStatus.Standby or row.name == ns.playerName then -- Green people + Standby + Player
					--row:Enable()
					row.enabled = true
				else -- If you really want to sign these people, change their status in calendar <-- Not true anymore, we have ContextMenu
					--row:Disable()
					row.enabled = false
					row.t:SetColorTexture(unpack(ns.colors.disabled))
				end
			else
				self.rows[i]:Hide()
			end
		end

		if not db.config.nameDebug and maxValue > 0 then
			Debug("<<< %s: %d", self:GetName(), maxValue)
		end
	end

	--  Dropdown Menus  --------------------------------------------------------
	function ns.functions.EDOnSelect(self, arg1, arg2, checked)
		Debug(">EDOnSelect ID %i, Val %i, Checked \"%s\"", self:GetID(), self.value, tostring(checked))

		if not checked then
			UIFrame.Container.ED:SetSelectedID(self:GetID())
			ns.openEvent.difficulty = self.value or db.config.defaultDifficulty -- To the DBase or default (3)

			_countSignups() -- Update bottom text for Signup coloring
		end
	end

	local info = {} -- Create only once
	function ns.functions.EDInitialize()
		Debug(">EDInitialize")

		--local info = UIDropDownMenu_CreateInfo() -- Source of possible taints?
		wipe(info)
		info.func = ns.functions.EDOnSelect
		info.justifyH = "CENTER"

		for i = 1, #ns.difficulties do
			local name = ns.difficulties[i]["name"]
			local id = ns.difficulties[i]["id"]
			info.text = name
			info.value = id

			if not ns.openEvent then
				info.checked = id == UIFrame.Container.ED.selected
			else
				info.checked = id == ns.openEvent.difficulty
			end

			UIDropDownMenu_AddButton(info)
		end
	end

	--  Mass Invite Button -----------------------------------------------------
	function ns.functions.MIBClick()
		Debug(">MIBClick")

		--PlaySound("igMainMenuOptionCheckBoxOn")
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)

		-- _updateEventInfo() checks this, but let's check again if the button is accidently still enabled
		if C_Calendar.EventCanEdit() then
			wipe(ns.inviteTable)
			for k, _ in pairs(ns.openEvent["Players"]) do
				if (ns.openEvent["Players"][k]["status"] == Enum.CalendarStatus.Confirmed or ns.openEvent["Players"][k]["status"] == Enum.CalendarStatus.Available or ns.openEvent["Players"][k]["status"] == Enum.CalendarStatus.Signedup) and ns.openEvent["Players"][k]["role"] ~= "Signup" then -- Add only signed up people with role assigned to them
					if ns.openEvent["Players"][k]["name"] ~= ns.playerName then -- Don't add me, I'm already here
						table.insert(ns.inviteTable, ns.openEvent["Players"][k]["name"])
					end
				end
			end

			for i = 1, GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) do -- returns 0 if you aren't in a group
				local name = GetRaidRosterInfo(i)
				for k = 1, #ns.inviteTable do
					if name == ns.inviteTable[k] then
						table.remove(ns.inviteTable, k) -- Remove people who are already in the group from invites list
					end
				end
			end

			if not IsInRaid(LE_PARTY_CATEGORY_HOME) then
				--if GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) + #ns.inviteTable > MAX_PARTY_MEMBERS + 1 then
					ns.massInviteNeedRaidSetup = true
					if GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) > 0 then
						C_PartyInfo.ConvertToRaid()
					end
				--end
			end

			Debug("#inviteTable:", #ns.inviteTable)
			_massInvite() -- Send info to invite function
		end
	end

	--  Roles frame scrollbar  -------------------------------------------------
	local scrollTemp = {}
	function ns.functions.rolesSlotOnClick(self, button)
		local function _lastSeen(player)
			local year, month, day = 0, 0, 0
			for i = 1, #db.roles[player] do
				if db.roles[player][i].timetable.year and db.roles[player][i].timetable.month and db.roles[player][i].timetable.day and
				db.roles[player][i].timetable.year > year and db.roles[player][i].timetable.month > month and db.roles[player][i].timetable.day > day then
					year = db.roles[player][i].timetable.year
					month = db.roles[player][i].timetable.month
					day = db.roles[player][i].timetable.day
				end
			end

			return string.format("%d.%d.%d", day, month, year)
		end

		Debug(">rolesSlotOnClick \"%s\" %s", self.value, button)

		if ns.selectedPlayer == self.value then -- Double clicking the same name
			ns.selectedPlayer = false

			UIFrame.Roles.AutoRoles.nameText:SetText(" ")
			UIFrame.Roles.AutoRoles.roleText:SetText(GRAY_FONT_COLOR_CODE..string.format(L.Role, "")..FONT_COLOR_CODE_CLOSE)
			UIFrame.Roles.AutoRoles.lastText:SetText(GRAY_FONT_COLOR_CODE..string.format(L.LastSeen, "")..FONT_COLOR_CODE_CLOSE)

			UIFrame.Roles.TB:Disable()
			UIFrame.Roles.HB:Disable()
			UIFrame.Roles.MB:Disable()
			UIFrame.Roles.RB:Disable()
			UIFrame.Roles.REM:Disable()
		else
			ns.selectedPlayer = self.value

			UIFrame.Roles.AutoRoles.nameText:SetText("|c"..self.cc.colorStr..self.name.."|r")
			UIFrame.Roles.AutoRoles.roleText:SetFormattedText(L.Role, self.role)
			UIFrame.Roles.AutoRoles.lastText:SetFormattedText(L.LastSeen, _lastSeen(self.value))

			UIFrame.Roles.TB:Enable()
			UIFrame.Roles.HB:Enable()
			UIFrame.Roles.MB:Enable()
			UIFrame.Roles.RB:Enable()
			UIFrame.Roles.REM:Enable()
		end
	end

	function ns.functions.updateRolesScrollBar(self) -- Update Roles Scroll Buttons
		local nameCount = 0
		for _ in pairs(db.roles) do
			nameCount = nameCount + 1
		end

		Debug("Scroller:", #scrollTemp, nameCount)
		if #scrollTemp ~= nameCount then
			Debug("+++Update scrollTemp")
			wipe(scrollTemp)
			for k in pairs(db.roles) do
				scrollTemp[#scrollTemp+1] = k
			end
			sort(scrollTemp)
		end
		local maxValue = #scrollTemp
		local slots = 20

		FauxScrollFrame_Update(self.scrollBar, maxValue, slots, 15) -- Scrollbar, max items on scrollbar, max visible items on scrollbar and height of item on scrollbar
		local offset = FauxScrollFrame_GetOffset(self.scrollBar)
		for i = 1, slots do
			local value = i + offset
			if value <= maxValue then
				self.rows[i]:Show()

				local row = self.rows[i]
				row.value = scrollTemp[value]
				row.name = scrollTemp[value]
				if row.name:match("^([^%-]+)%-(.*)$") then -- Player is from another realm
					row.name = select(1, row.name:match("^([^%-]+)%-(.*)$"))..INTERACTIVE_SERVER_LABEL -- Shorten realm name into (#)
				end
				row.role = _getRole(row.value)
				row.cc = _colorMe(db.roles[row.value]["class"]) or {r = 1, g = 1, b = 1, colorStr = "ffffffff"}
				row.t:SetColorTexture(row.cc.r, row.cc.g, row.cc.b, 0.35)

				row.fname:SetText("|c"..row.cc.colorStr..row.name.."|r")
				row.fstatus:SetText(row.role)

			else
				self.rows[i]:Hide()
			end
		end
	end

	--  Roles frame buttons  ---------------------------------------------------
	local function _changeRole(player, role)
		Debug("_changeRole", player, role)

		while #db.roles[player] > 0 do
			Debug("Remove old role:", #db.roles[player])
			tremove(db.roles[player], 1)
		end

		local timetable = date("*t")
		for i = 1, db.config.autoRoleCount do
			Debug("Iterate new role:", #db.roles[player]+1, "/", db.config.autoRoleCount)
			--db.roles[player][i] = { ["timetable"] = timetable, ["role"] = role, }
			table.insert(db.roles[player], { ["timetable"] = timetable, ["role"] = role, })
		end
	end

	function ns.functions.TBClick()
		Debug(">TBClick")

		if not ns.selectedPlayer then return end

		--PlaySound("igMainMenuOptionCheckBoxOn")
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		UIFrame.Roles.AutoRoles.roleText:SetFormattedText(L.Role, L.Tanks)
		_changeRole(ns.selectedPlayer, "Tanks")--L.Tanks)
		ns.functions.updateRolesScrollBar(UIFrame.Roles.AutoRoles)
	end

	function ns.functions.HBClick()
		Debug(">HBClick")

		if not ns.selectedPlayer then return end

		--PlaySound("igMainMenuOptionCheckBoxOn")
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		UIFrame.Roles.AutoRoles.roleText:SetFormattedText(L.Role, L.Healers)
		_changeRole(ns.selectedPlayer, "Healers")--L.Healers)
		ns.functions.updateRolesScrollBar(UIFrame.Roles.AutoRoles)
	end

	function ns.functions.MBClick()
		Debug(">MBClick")

		if not ns.selectedPlayer then return end

		--PlaySound("igMainMenuOptionCheckBoxOn")
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		UIFrame.Roles.AutoRoles.roleText:SetFormattedText(L.Role, L.Melee)
		_changeRole(ns.selectedPlayer, "Melee")--L.Melee)
		ns.functions.updateRolesScrollBar(UIFrame.Roles.AutoRoles)
	end

	function ns.functions.RBClick()
		Debug(">RBClick")

		if not ns.selectedPlayer then return end

		--PlaySound("igMainMenuOptionCheckBoxOn")
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		UIFrame.Roles.AutoRoles.roleText:SetFormattedText(L.Role, L.Ranged)
		_changeRole(ns.selectedPlayer, "Ranged")--L.Ranged)
		ns.functions.updateRolesScrollBar(UIFrame.Roles.AutoRoles)
	end

	function ns.functions.REMClick()
		Debug(">REMClick")

		if not ns.selectedPlayer then return end

		--PlaySound("igMainMenuOptionCheckBoxOn")
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)

		if IsShiftKeyDown() then
			db.roles[ns.selectedPlayer] = nil
			UIFrame.Roles.AutoRoles.nameText:SetText(" ")
			UIFrame.Roles.AutoRoles.roleText:SetText(GRAY_FONT_COLOR_CODE..string.format(L.Role, "")..FONT_COLOR_CODE_CLOSE)
			UIFrame.Roles.AutoRoles.lastText:SetText(GRAY_FONT_COLOR_CODE..string.format(L.LastSeen, "")..FONT_COLOR_CODE_CLOSE)
			UIFrame.Roles.TB:Disable()
			UIFrame.Roles.HB:Disable()
			UIFrame.Roles.MB:Disable()
			UIFrame.Roles.RB:Disable()
			UIFrame.Roles.REM:Disable()
			ns.selectedPlayer = false
			ns.functions.updateRolesScrollBar(UIFrame.Roles.AutoRoles)
		end
	end

	--  Blocker frames  --------------------------------------------------------
	local isEventVisible
	function ns.functions.getState()
		Debug(">getState")

		isEventVisible = UIFrame.Container:IsShown()
		UIFrame.Container:Hide()
	end

	function ns.functions.setState()
		Debug(">setState")

		if isEventVisible then
			UIFrame.Container:Show()
		end
	end

	function ns.functions.InvCancel()
		Debug(">InvCancel")

		--PlaySound("igMainMenuOptionCheckBoxOn")
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		wipe(ns.inviteTable)
	end

	--  Tabs frame  ------------------------------------------------------------
	function ns.functions.tabOnClick(self, button)
		Debug(">tabOnClick \"%s\" (%i)", isWrathClassic and self:GetName() or "Mixin", isWrathClassic and self:GetID() or tonumber(self))

		local id
	
		if isWrathClassic then
			id = self:GetID()
			PanelTemplates_SetTab(TabsFrame, id)
		else -- 10.0 DF
			id = self
			TabsFrame:SetTabVisuallySelected(id)
		end
		--PlaySound("igMainMenuOptionCheckBoxOn")
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)

		if db.config.overlay then
			if id == 1 then
				if CalendarViewEventFrame:IsShown() then
					CalendarViewEventFrame:SetAlpha(1)
				else
					CalendarCreateEventFrame:SetAlpha(1)
				end

				UIFrame:Hide()
				UIFrame.Container:Hide()
				UIFrame.Roles:Hide()
				if CalendarViewEventFrame:IsShown() then
					if ns.Elv then
						TabsFrame:SetPoint("TOP", CalendarViewEventFrame, "BOTTOM")
					else
						if isWrathClassic then
							TabsFrame:SetPoint("TOP", CalendarViewEventFrame, "BOTTOM", 0, 4)
						else -- 10.0 DF
							TabsFrame:SetPoint("TOP", CalendarViewEventFrame, "BOTTOM", 0, 6)
						end
					end
				else
					if ns.Elv then
						TabsFrame:SetPoint("TOP", CalendarCreateEventFrame, "BOTTOM")
					else
						if isWrathClassic then
							TabsFrame:SetPoint("TOP", CalendarCreateEventFrame, "BOTTOM", 0, 4)
						else -- 10.0 DF
							TabsFrame:SetPoint("TOP", CalendarCreateEventFrame, "BOTTOM", 0, 6)
						end
					end
				end
			elseif id == 2 then
				if CalendarViewEventFrame:IsShown() then
					CalendarViewEventFrame:SetAlpha(0)
				else
					CalendarCreateEventFrame:SetAlpha(0)
				end

				if not UIFrame:IsShown() then
					UIFrame:Show()
					TabsFrame:SetPoint("TOP", UIFrame, "BOTTOM")
				end
				UIFrame.Container:Show()
				UIFrame.Roles:Hide()

				_updateEventInfo()
			else
				if CalendarViewEventFrame:IsShown() then
					CalendarViewEventFrame:SetAlpha(0)
				else
					CalendarCreateEventFrame:SetAlpha(0)
				end

				if not UIFrame:IsShown() then
					UIFrame:Show()
					TabsFrame:SetPoint("TOP", UIFrame, "BOTTOM")
				end
				UIFrame.Container:Hide()
				UIFrame.Roles:Show()

				ns.functions.updateRolesScrollBar(UIFrame.Roles.AutoRoles)
				UIFrame.Roles.AutoRoles.nameText:SetText(" ")
				UIFrame.Roles.AutoRoles.roleText:SetText(GRAY_FONT_COLOR_CODE..string.format(L.Role, "")..FONT_COLOR_CODE_CLOSE)
				UIFrame.Roles.AutoRoles.lastText:SetText(GRAY_FONT_COLOR_CODE..string.format(L.LastSeen, "")..FONT_COLOR_CODE_CLOSE)
				UIFrame.Roles.TB:Disable()
				UIFrame.Roles.HB:Disable()
				UIFrame.Roles.MB:Disable()
				UIFrame.Roles.RB:Disable()
				UIFrame.Roles.REM:Disable()
				ns.selectedPlayer = false
			end
		else
			if CalendarViewEventFrame:IsShown() then
				CalendarViewEventFrame:SetAlpha(1)
			else
				CalendarCreateEventFrame:SetAlpha(1)
			end

			if id == 1 then
				UIFrame.Container:Show()
				UIFrame.Roles:Hide()

				_updateEventInfo()
			else
				UIFrame.Container:Hide()
				UIFrame.Roles:Show()

				ns.functions.updateRolesScrollBar(UIFrame.Roles.AutoRoles)
				UIFrame.Roles.AutoRoles.nameText:SetText(" ")
				UIFrame.Roles.AutoRoles.roleText:SetText(GRAY_FONT_COLOR_CODE..string.format(L.Role, "")..FONT_COLOR_CODE_CLOSE)
				UIFrame.Roles.AutoRoles.lastText:SetText(GRAY_FONT_COLOR_CODE..string.format(L.LastSeen, "")..FONT_COLOR_CODE_CLOSE)
				UIFrame.Roles.TB:Disable()
				UIFrame.Roles.HB:Disable()
				UIFrame.Roles.MB:Disable()
				UIFrame.Roles.RB:Disable()
				UIFrame.Roles.REM:Disable()
				ns.selectedPlayer = false
			end
		end
	end

	-- Rename tabs and Show/Hide 3rd tab
	function ns.functions.renameTabs()
		if db.config.overlay then
			if isWrathClassic then
				TabsFrame.tab3:Show()
				TabsFrame.tab1:SetText(L.Default)
				TabsFrame.tab2:SetText(ADDON_NAME)
				TabsFrame.tab3:SetText(L.Roles)

				PanelTemplates_SetNumTabs(TabsFrame, 3)
			else -- 10.0 DF
				TabsFrame.tab1.tabText = L.Default
				TabsFrame.tab2.tabText = ADDON_NAME
				TabsFrame.tab3.tabText = L.Roles

				-- So much bubble gum here, I hope Wrath moves into this same system so I can simplify this whole thing by a metric ton
				-- Update texts
				TabsFrame.tab1:SetTabEnabled(true)
				TabsFrame.tab2:SetTabEnabled(true)
				TabsFrame:SetTabShown(3, true)
			end
		else
			if isWrathClassic then
				TabsFrame.tab3:Hide()
				TabsFrame.tab1:SetText(ADDON_NAME)
				TabsFrame.tab2:SetText(L.Roles)

				PanelTemplates_SetNumTabs(TabsFrame, 2)
			else -- 10.0 DF
				TabsFrame.tab1.tabText = ADDON_NAME
				TabsFrame.tab2.tabText = L.Roles

				TabsFrame.tab1:SetTabEnabled(true)
				TabsFrame.tab2:SetTabEnabled(true)
				TabsFrame:SetTabShown(3, false)
			end
		end
	end

--------------------------------------------------------------------------------
--	OnEvent handler
--------------------------------------------------------------------------------
	EventFrame = CreateFrame("Frame")
	EventFrame:RegisterEvent("ADDON_LOADED")
	EventFrame:SetScript("OnEvent", function(self, event, ...)
		return self[event] and self[event](self, event, ...)
	end)

--------------------------------------------------------------------------------
--	OnLoad function
--------------------------------------------------------------------------------
	function ns.OnLoad(self)
		-- Record our frame pointer for later
		UIFrame = self
		TabsFrame = ns.Tabs

		-- Register for player events
		EventFrame:RegisterEvent("ADDON_LOADED")
		EventFrame:RegisterEvent("PLAYER_LOGIN")
	end

--------------------------------------------------------------------------------
--	Event functions
--------------------------------------------------------------------------------
	function EventFrame:ADDON_LOADED(event, addon)
		if addon ~= ADDON_NAME then return end

		LOIHCalDB = _initDB(LOIHCalDB, ns.DBdefaults)
		db = LOIHCalDB

		Debug("- Settings:")
		if db.config.debug then
			for k, v in pairs(db.config) do
				Debug("-", k, tostring(v))
			end
		end

		_removeOldPlayers() -- Remove old players on login to get up to date data for the new no-autorole indicator.

		self:RegisterEvent("PLAYER_LOGOUT")
		self:UnregisterEvent(event)
		self.ADDON_LOADED = nil
	end

	function EventFrame:PLAYER_LOGIN(event)
		--self:RegisterEvent("CALENDAR_EVENT_ALARM")
		self:RegisterEvent("CALENDAR_OPEN_EVENT")
		self:RegisterEvent("CALENDAR_CLOSE_EVENT")
		self:RegisterEvent("CALENDAR_UPDATE_EVENT")
		self:RegisterEvent("CALENDAR_UPDATE_INVITE_LIST")
		--self:RegisterEvent("QUEST_LOG_UPDATE")
		self:RegisterEvent("GROUP_ROSTER_UPDATE")

		ns.Elv = IsAddOnLoaded("ElvUI")
		ns.playerName = UnitName("player")
		ns.skinned = false
		ns.massInviteNeedRaidSetup = false
		ns.groupSize = GetNumGroupMembers()

		-- ViewEventFrame OnHide Hook
		CalendarViewEventFrame:HookScript("OnHide", function(self)
			CalendarViewEventFrame:SetAlpha(1)
			UIFrame:Hide()
			TabsFrame:Hide()
			Debug("View OnHide")
		end)
		-- CreateEventFrame OnHide Hook
		CalendarCreateEventFrame:HookScript("OnHide", function(self)
			CalendarCreateEventFrame:SetAlpha(1)
			UIFrame:Hide()
			TabsFrame:Hide()
			Debug("Create OnHide")
		end)

		_skinFrames()

		self:UnregisterEvent(event)
		self.PLAYER_LOGIN = nil
	end

	function EventFrame:PLAYER_LOGOUT(event)
		_removeOldEvents()
		_removeOldPlayers()
		db = _cleanDB(db, ns.DBdefaults)
	end

	--[[
	function EventFrame:QUEST_LOG_UPDATE(event)
		-- This fires after reload ui or on normal login
		Debug(event)

		local timeData = C_DateAndTime.GetCurrentCalendarTime() -- C_Calendar.GetDate()
		local month, day, year = timeData.month, timeData.monthDay, timeData.year
		C_Calendar.SetAbsMonth(month, year)
		C_Calendar.OpenCalendar()
		-- Requests calendar information from the server. Does not open the
		-- calendar frame. Triggers CALENDAR_UPDATE_EVENT_LIST when your query
		-- has finished processing on the server and new calendar information is
		-- available.

		self:UnregisterEvent(event)
		self.QUEST_LOG_UPDATE = nil
	end

	function EventFrame:CALENDAR_EVENT_ALARM(event, ...)
		-- 15mins to event, work on this after everything works
		local title, hour, minute = ...
		Debug(event, tostring(title), tostring(hour), tostring(minute))
	end
	]]

	function EventFrame:CALENDAR_OPEN_EVENT(event, eventType)
		Debug("%s \"%s\"", event, tostring(eventType or "!..."))

		if eventType ~= "PLAYER" and eventType ~= "GUILD_EVENT" and eventType ~= "COMMUNITY_EVENT" then return end
		if not C_Calendar.IsEventOpen() then
 			Debug("- We ended up in a limbo... Trying to recover...")
			self:CALENDAR_CLOSE_EVENT("Panik! Escaping limbo...")
			return -- Forgot this on the first try :P
		end

		UIFrame:Hide() -- Hack for 7.0 click through bug

		if C_Calendar.IsEventOpen() and CalendarViewEventFrame:IsShown() then
			Debug("- CalendarViewEventFrame")
			UIFrame:SetFrameStrata(CalendarViewEventFrame:GetFrameStrata())
			--UIFrame:SetFrameLevel(CalendarViewEventFrame:GetFrameLevel()+7)
			UIFrame:Raise()

			ns.functions.renameTabs()
			UIFrame:Show()
			TabsFrame:Show()
			UIFrame.Roles:Hide()
			ns.groupSize = GetNumGroupMembers()

			if db.config.overlay then
				UIFrame:SetPoint("TOPLEFT", CalendarViewEventFrame, "TOPLEFT")
				if db.config.defaultView then
					CalendarViewEventFrame:SetAlpha(0)

					if isWrathClassic then
						PanelTemplates_SetTab(TabsFrame, 2)
					else -- 10.0 DF
						TabsFrame:SetTab(2)
					end
					UIFrame.Container:Show()
					TabsFrame:SetPoint("TOP", UIFrame, "BOTTOM")
				else
					CalendarViewEventFrame:SetAlpha(1)

					if isWrathClassic then
						PanelTemplates_SetTab(TabsFrame, 1)
					else -- 10.0 DF
						TabsFrame:SetTab(1)
					end
					UIFrame:Hide()
					UIFrame.Container:Hide()
					if ns.Elv then
						TabsFrame:SetPoint("TOP", CalendarViewEventFrame, "BOTTOM")
					else
						TabsFrame:SetPoint("TOP", CalendarViewEventFrame, "BOTTOM", 0, 4)
					end
				end
			else
				CalendarViewEventFrame:SetAlpha(1)

				UIFrame:SetPoint("TOPLEFT", CalendarViewEventFrame, "TOPRIGHT", 26, 0)
				if isWrathClassic then
					PanelTemplates_SetTab(TabsFrame, 1)
				else -- 10.0 DF
					TabsFrame:SetTab(1)
				end
				UIFrame.Container:Show()
				TabsFrame:SetPoint("TOP", UIFrame, "BOTTOM")
			end
		elseif C_Calendar.IsEventOpen() and CalendarCreateEventFrame:IsShown() then
			Debug("- CalendarCreateEventFrame")
			UIFrame:SetFrameStrata(CalendarCreateEventFrame:GetFrameStrata())
			--UIFrame:SetFrameLevel(CalendarCreateEventFrame:GetFrameLevel()+7)
			UIFrame:Raise()

			ns.functions.renameTabs()
			UIFrame:Show()
			TabsFrame:Show()
			UIFrame.Roles:Hide()
			ns.groupSize = GetNumGroupMembers()

			if db.config.overlay then
				UIFrame:SetPoint("TOPLEFT", CalendarCreateEventFrame, "TOPLEFT")
				if db.config.defaultView then
					CalendarCreateEventFrame:SetAlpha(0)

					if isWrathClassic then
						PanelTemplates_SetTab(TabsFrame, 2)
					else -- 10.0 DF
						TabsFrame:SetTab(2)
					end
					UIFrame.Container:Show()
					TabsFrame:SetPoint("TOP", UIFrame, "BOTTOM")
				else
					CalendarCreateEventFrame:SetAlpha(1)

					if isWrathClassic then
						PanelTemplates_SetTab(TabsFrame, 1)
					else -- 10.0 DF
						TabsFrame:SetTab(1)
					end
					UIFrame:Hide()
					UIFrame.Container:Hide()
					if ns.Elv then
						TabsFrame:SetPoint("TOP", CalendarCreateEventFrame, "BOTTOM")
					else
						TabsFrame:SetPoint("TOP", CalendarCreateEventFrame, "BOTTOM", 0, 4)
					end
				end
			else
				CalendarCreateEventFrame:SetAlpha(1)

				UIFrame:SetPoint("TOPLEFT", CalendarCreateEventFrame, "TOPRIGHT", 26, 0)
				if isWrathClassic then
					PanelTemplates_SetTab(TabsFrame, 1)
				else -- 10.0 DF
					TabsFrame:SetTab(1)
				end
				UIFrame.Container:Show()
				TabsFrame:SetPoint("TOP", UIFrame, "BOTTOM")
			end
		end

		if ns.selected then
			ns.selected.t:SetColorTexture(unpack(ns.colors.deselect))
			ns.selected = false
		end

		-- Calendar might be busy waiting server for event info, let's wait...
		if C_Calendar.IsActionPending() then
			Debug("- Action Pending...")
			UIFrame.Think:Show()
			local timer, ttimer = 0, 0
			self:SetScript("OnUpdate", function(self, elapsed)
				timer = timer + elapsed
				ttimer = ttimer + elapsed
				-- Prevent updatePlayers running before getting all the names from server
				--local _, namesReady = C_Calendar.GetNumInvites()
				while timer >= 1 / 6 do --0.25 do
					if not C_Calendar.IsActionPending() then --and namesReady then
						self:SetScript("OnUpdate", nil)
						Debug("- Pending Action completed in %dms.", ttimer * 1000)
						UIFrame.Think:Hide()
						if C_Calendar.IsEventOpen() and CalendarFrame:IsShown() then -- Make sure we didn't close the event while waiting!
							_updateEventInfo(eventType)
						else
							self:CALENDAR_CLOSE_EVENT("CalendarFrame closed before Pending Action was completed")
						end
					end
					timer = timer - 1 / 6 --0.25
				end
			end)
		else
			Debug("- NO Action Pending! Ready to move on.")
			_updateEventInfo(eventType)
		end
	end

	function EventFrame:GROUP_ROSTER_UPDATE(event)
		Debug(event, ns.groupSize, tostring(UIFrame:IsShown()))

		if ns.massInviteNeedRaidSetup then
			--if GetNumGroupMembers() > 0 and not IsInRaid() then
			if IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid(LE_PARTY_CATEGORY_HOME) then
				C_PartyInfo.ConvertToRaid() -- ConvertToRaid()

				-- Set up raid difficulty
				--SetRaidDifficultyID(ns.openEvent.difficulty)
				--ns.massInviteNeedRaidSetup = false
			else
				--self:UnregisterEvent(event)
				--ns.massInviteNeedRaidSetup = false
			end

			if IsInRaid(LE_PARTY_CATEGORY_HOME) and GetRaidDifficultyID() ~= ns.openEvent.difficulty then
				-- Set up raid difficulty
				SetRaidDifficultyID(ns.openEvent.difficulty)
			end
		end

		if UIFrame:IsShown() then
			ns.groupSize = GetNumGroupMembers()

			for _, v in ipairs(ns.rolesList) do -- Update who is in raid
				sort(ns.role[v], ns.calStatusSort)
				ns.functions.updateScrollBar(_G[v], ns.role[v])
			end
		end
	end

	function EventFrame:CALENDAR_CLOSE_EVENT(event)
		Debug(event)

		if CalendarViewEventFrame:GetAlpha() < 1 then
			CalendarViewEventFrame:SetAlpha(1)
		end
		if CalendarCreateEventFrame:GetAlpha() < 1 then
			CalendarCreateEventFrame:SetAlpha(1)
		end

		UIFrame:Hide()
		TabsFrame:Hide()
	end

	function EventFrame:CALENDAR_UPDATE_EVENT(event)
		Debug(event, CalendarViewEventFrame:IsShown(), CalendarCreateEventFrame:IsShown())

		--if CalendarViewEventFrame:IsShown() or CalendarCreateEventFrame:IsShown() then
		if C_Calendar.IsEventOpen() then
			_updateEventInfo()
		end
	end

	function EventFrame:CALENDAR_UPDATE_INVITE_LIST(event, hasCompleteList)
		Debug(event, hasCompleteList, CalendarViewEventFrame:IsShown(), CalendarCreateEventFrame:IsShown(), C_Calendar.IsEventOpen())

		--if CalendarViewEventFrame:IsShown() or CalendarCreateEventFrame:IsShown() then
		if hasCompleteList and C_Calendar.IsEventOpen() then
			Debug("- Regular")
			_updateEventInfo()
		elseif UIFrame.Container:IsShown() and (CalendarViewEventFrame:IsShown() or CalendarCreateEventFrame:IsShown()) then -- This fixes Github issue #4
			Debug("- Detour!!!")
			_updateEventInfo()
		end
	end

-------------------------------------------------------------------------------
--  Slash handler
-------------------------------------------------------------------------------
	SLASH_LOIHCAL1 = "/loihcal"
	SLASH_LOIHCAL2 = L.SLASH_COMMAND

	local SlashHandlers = {
		["config"] = function()
			InterfaceOptionsFrame_OpenToCategory(ADDON_NAME)
		end,
		["reset"] = function()
			wipe(db)
			ReloadUI()
		end,
		["hide"] = function()
			EventFrame:CALENDAR_CLOSE_EVENT("Hiding UI with /slash")
		end,
		["debug"] = function()
			db.config.debug = not db.config.debug
			Print("Debugging: %s%s%s", db.config.debug and GREEN_FONT_COLOR_CODE or RED_FONT_COLOR_CODE, tostring(db.config.debug), FONT_COLOR_CODE_CLOSE)
		end,
		["names"] = function()
			db.config.nameDebug = not db.config.nameDebug
			Print("Names: %s%s%s", db.config.nameDebug and GREEN_FONT_COLOR_CODE or RED_FONT_COLOR_CODE, tostring(db.config.nameDebug), FONT_COLOR_CODE_CLOSE)
		end,
	}

	SlashCmdList["LOIHCAL"] = function(text)
		local command, params = strsplit(" ", text, 2)
		if SlashHandlers[command] then
			SlashHandlers[command](params)
		else
			Print(ADDON_NAME.." "..ns.version)
			Print(L.CMD_LIST, L.CMD_CONFIG, L.CMD_RESET)
		end
	end

-------------------------------------------------------------------------------
--  Config
-------------------------------------------------------------------------------
	Options = CreateFrame("Frame", "LOIHCalOptions", InterfaceOptionsFramePanelContainer)
	Options:Hide()
	Options.name = ADDON_NAME
	Options.scrolling = true
	InterfaceOptions_AddCategory(Options)

	Options:SetScript("OnShow", function()
		local ScrollChild

		--  Config Factory  ----------------------------------------------------

		local function CreatePanel(name, labelText)
			local panelBackdrop = {
				bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tile = true, tileSize = 16,
				edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 16,
				insets = { left = 5, right = 5, top = 5, bottom = 5 }
			}

			local frame = CreateFrame("Frame", name, ScrollChild, BackdropTemplateMixin and "BackdropTemplate")
			frame:SetBackdrop(panelBackdrop)
			frame:SetBackdropColor(0.06, 0.06, 0.06, 0.4)
			frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

			local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			label:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 4, 0)
			label:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -4, 0)
			label:SetJustifyH("LEFT")
			label:SetText(labelText)
			frame.labelText = label

			frame:SetSize(floor(ScrollChild:GetWidth()), 50)

			return frame
		end

		local function MakeButton(name, tooltipText)
			local button = CreateFrame("Button", nil, ScrollChild, "UIPanelButtonTemplate")
			--button:GetFontString():SetPoint("CENTER", -1, 0)
			button:GetFontString():SetPoint("CENTER", 0, -1)
			button:SetMotionScriptsWhileDisabled(true)
			button:RegisterForClicks("AnyUp")
			button:SetText(name)
			button:SetWidth(button:GetFontString():GetStringWidth() + 30)
			button.tooltipText = tooltipText

			return button
		end

		local function MakeCheckBox(name, tooltipText, tooltipRequirement)
			--local checkbox = CreateFrame("CheckButton", name, ScrollChild, "InterfaceOptionsCheckButtonTemplate")
			--_G[checkbox:GetName().."Text"]:SetText(name)
			local checkbox = CreateFrame("CheckButton", nil, ScrollChild, "InterfaceOptionsCheckButtonTemplate")
			checkbox.Text:SetText(name)
			checkbox.tooltipText = tooltipText
			checkbox.tooltipRequirement = tooltipRequirement

			return checkbox
		end

		--  10.0 Hacks  --------------------------------------------------------
		local optionsCanvas
		if isWrathClassic then
			optionsCanvas = InterfaceOptionsFramePanelContainer
		else
			optionsCanvas = SettingsPanel.Container.SettingsCanvas
		end

		--  Title  -------------------------------------------------------------

		local Title = Options:CreateFontString("$parentTitle", "ARTWORK", "GameFontNormalLarge")
		Title:SetPoint("TOPLEFT", 16, -16)
		Title:SetText(ADDON_NAME.." "..ns.version)

		local SubText = Options:CreateFontString("$parentSubText", "ARTWORK", "GameFontHighlightSmall")
		SubText:SetPoint("TOPLEFT", Title, "BOTTOMLEFT", 0, -8)
		SubText:SetJustifyH("LEFT")
		SubText:SetJustifyV("TOP")
		SubText:SetText(GetAddOnMetadata(ADDON_NAME, "Notes"))

		--  Scroller  ----------------------------------------------------------

		local Scroller = CreateFrame("ScrollFrame", "$parentScoller", Options, "UIPanelScrollFrameTemplate")
		Scroller:SetWidth(floor(optionsCanvas:GetWidth()) - 40)
		Scroller:SetHeight(floor(optionsCanvas:GetHeight() - 16 - Title:GetHeight() - 8 - SubText:GetHeight() - 15))
		Scroller:SetPoint("BOTTOM", optionsCanvas, "BOTTOM", -5, 0)

		ScrollChild = CreateFrame("Frame", nil, Scroller)
		ScrollChild:SetHeight(Scroller:GetHeight())
		ScrollChild:SetWidth(Scroller:GetWidth())
		ScrollChild:SetPoint("TOPLEFT", Scroller, "TOPLEFT")
		Scroller:SetScrollChild(ScrollChild)

		--  General  -----------------------------------------------------------

		local General = CreatePanel("$parentGeneral", L.GeneralSettingsTitle)
		General:SetPoint("TOP", ScrollChild, "TOP", 0, -24)

		local overlay, defaultview, quickmode

		overlay = MakeCheckBox(L.AttachMode, L.AttachMode, string.format(L.AttachModeDesc, ADDON_NAME))
		overlay:SetPoint("TOPLEFT", General, "TOPLEFT", 10, -10)
		overlay:SetScript("OnClick", function(this)
			Debug("+overlay \"%s\"", tostring(this:GetChecked()))

			local checked = not not this:GetChecked()
			--PlaySound(checked and "igMainMenuOptionCheckBoxOn" or "igMainmenuOptionCheckBoxOff")
			PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			db.config.overlay = checked
			ns.functions.renameTabs()

			if db.config.overlay then
				defaultview:Enable()
				defaultview.Text:SetFormattedText(L.DefaultView, ADDON_NAME)
				UIFrame:SetPoint("TOPLEFT", CalendarViewEventFrame, "TOPLEFT")
				ns.functions.renameTabs()
			else
				defaultview:Disable()
				defaultview.Text:SetText(GRAY_FONT_COLOR_CODE..string.format(L.DefaultView, ADDON_NAME)..FONT_COLOR_CODE_CLOSE)
				UIFrame:SetPoint("TOPLEFT", CalendarViewEventFrame, "TOPRIGHT", 26, 0)
				ns.functions.renameTabs()
			end
		end)

		defaultview = MakeCheckBox(string.format(L.DefaultView, ADDON_NAME), string.format(L.DefaultView, ADDON_NAME), string.format(L.DefaultViewDesc, ADDON_NAME))
		defaultview:SetPoint("TOPLEFT", General, "TOP", 10, -10)
		defaultview:SetScript("OnClick", function(this)
			Debug("+defaultview \"%s\"", tostring(this:GetChecked()))

			local checked = not not this:GetChecked()
			--PlaySound(checked and "igMainMenuOptionCheckBoxOn" or "igMainmenuOptionCheckBoxOff")
			PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			db.config.defaultView = checked
		end)

		quickmode = MakeCheckBox(L.QuickMode, L.QuickMode, L.QuickModeDesc)
		quickmode:SetPoint("TOPLEFT", overlay, "BOTTOMLEFT", 0, -10)
		quickmode:SetScript("OnClick", function(this)
			Debug("+quickmode \"%s\"", tostring(this:GetChecked()))

			local checked = not not this:GetChecked()
			--PlaySound(checked and "igMainMenuOptionCheckBoxOn" or "igMainmenuOptionCheckBoxOff")
			PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			db.config.quickMode = checked

			--[[if checked then
			else
			end]]
		end)

		General:SetHeight(floor(overlay:GetHeight() + quickmode:GetHeight() + 29 + 0.5))

		--  Automation  --------------------------------------------------------

		local Automation = CreatePanel("$parentAutomation", L.AutomationSettingsTitle)
		Automation:SetPoint("TOP", General, "BOTTOM", 0, -28)

		local autorole, autodecay, autoconfirm

		autorole = MakeCheckBox(L.AutoRoles, L.AutoRoles, L.AutoRolesDesc)
		autorole:SetPoint("TOPLEFT", Automation, "TOPLEFT", 10, -10)
		autorole:SetScript("OnClick", function(this)
			Debug("+autorole \"%s\"", tostring(this:GetChecked()))

			local checked = not not this:GetChecked()
			--PlaySound(checked and "igMainMenuOptionCheckBoxOn" or "igMainmenuOptionCheckBoxOff")
			PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			db.config.autoRole = checked

			if db.config.autoRole then
				autodecay:Enable()
				autodecay.Text:SetText(L.AutoRoleDecay)
			else
				autodecay:Disable()
				autodecay.Text:SetText(GRAY_FONT_COLOR_CODE..L.AutoRoleDecay..FONT_COLOR_CODE_CLOSE)
			end
		end)

		autodecay = MakeCheckBox(L.AutoRoleDecay, L.AutoRoleDecay, string.format(L.AutoRoleDecayDesc, db.config.autoRoleDecayTime))
		autodecay:SetPoint("TOPLEFT", Automation, "TOP", 10, -10)
		autodecay:SetScript("OnClick", function(this)
			Debug("+autodecay \"%s\"", tostring(this:GetChecked()))

			local checked = not not this:GetChecked()
			--PlaySound(checked and "igMainMenuOptionCheckBoxOn" or "igMainmenuOptionCheckBoxOff")
			PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			db.config.autoRoleDecay = checked
		end)

		autoconfirm = MakeCheckBox(L.AutoConfirm, L.AutoConfirm, L.AutoConfirmDesc)
		autoconfirm:SetPoint("TOPLEFT", autorole, "BOTTOMLEFT", 0, -10)
		autoconfirm:SetScript("OnClick", function(this)
			Debug("+autoconfirm \"%s\"", tostring(this:GetChecked()))

			local checked = not not this:GetChecked()
			--PlaySound(checked and "igMainMenuOptionCheckBoxOn" or "igMainmenuOptionCheckBoxOff")
			PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			db.config.autoConfirm = checked
		end)

		Automation:SetHeight(floor(autoconfirm:GetHeight() + autorole:GetHeight() + 29 + 0.5))

		--  Raid  --------------------------------------------------------------

		local Raid = CreatePanel("$parentRaid", L.DefaultSettingsTitle)
		Raid:SetPoint("TOP", Automation, "BOTTOM", 0, -28)

		local info = {}
		local DD

		local function _DDOnSelect(self, arg1, arg2, checked)
			Debug("+DDOnSelect ID %i, Val %i, Checked \"%s\"", self:GetID(), self.value, tostring(checked))

			if not checked then
				DD:SetSelectedID(self:GetID())
				db.config.defaultDifficulty = self.value -- Drop (to) the (D)Base
			end
		end

		local function _DDInitialize()
			Debug("+DDInitialize")

			--local info = UIDropDownMenu_CreateInfo() -- Source of possible taints?
			wipe(info)
			info.func = _DDOnSelect
			info.justifyH = "CENTER"

			for i = 1, #ns.difficulties do
				local name = ns.difficulties[i]["name"]
				local id = ns.difficulties[i]["id"]
				info.text = name
				info.value = id
				info.checked = id == DD.selected

				UIDropDownMenu_AddButton(info)
			end
		end

		DD = CreateFrame("Button", "$parentDD", ScrollChild, "UIDropDownMenuTemplate")
		DD.selected = db.config.defaultDifficulty
		UIDropDownMenu_Initialize(DD, _DDInitialize)
		UIDropDownMenu_JustifyText(DD, "CENTER")
		DD:SetPoint("TOPLEFT", Raid, "TOPLEFT", 10, -12)

		-- Quick and dirty taint fix
		function DD:SetSelectedID(id)
			self.selected = id + difficultyOffset
			UIDropDownMenu_SetText(DD, ns.difficulties[id]["name"])
		end

		function DD:GetSelectedID()
			return self.selected
		end

		Raid:SetHeight(floor(DD:GetHeight() + 32 + 0.5))

		--  Whisper  -----------------------------------------------------------

		local Whisper = CreatePanel("$parentWhisper", L.WhisperSettingsTitle)
		Whisper:SetPoint("TOP", Raid, "BOTTOM", 0, -28)

		local enablewhisper, editbox, whisperlabel, saveeditbox, reseteditbox

		enablewhisper = MakeCheckBox(L.SendWhispers, L.SendWhispers, L.SendWhispersDesc)
		enablewhisper:SetPoint("TOPLEFT", Whisper, "TOPLEFT", 10, -10)
		enablewhisper:SetScript("OnClick", function(this)
			Debug("+enablewhisper \"%s\"", tostring(this:GetChecked()))

			local checked = not not this:GetChecked()
			--PlaySound(checked and "igMainMenuOptionCheckBoxOn" or "igMainmenuOptionCheckBoxOff")
			PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			db.config.sendWhisper = checked
		end)

		editbox = CreateFrame("EditBox", nil, ScrollChild, "InputBoxTemplate")
		editbox:SetSize(Whisper:GetWidth() - 31, 22)
		editbox:SetAutoFocus(false)
		editbox:SetPoint("TOPLEFT", enablewhisper, "BOTTOMLEFT", 8, -13)
		editbox:SetScript("OnEnterPressed", function()
			Debug("+editbox OnEnterPressed")

			if editbox:GetText() ~= "" then
				db.config.InvWhisper = editbox:GetText()
			end
			editbox:SetText(db.config.InvWhisper)
			editbox:ClearFocus()
			saveeditbox:Disable()
		end)
		editbox:SetScript("OnEscapePressed", function()
			Debug("+editbox OnEscapePressed")

			editbox:SetText(db.config.InvWhisper)
			editbox:ClearFocus()
		end)
		editbox:SetScript("OnTextChanged", function(self, isUserInput)
			Debug("+editbox OnTextChanged: %s", tostring(isUserInput))

			if isUserInput and editbox:GetText() ~= "" then -- Enable Save-button if user changes text
				saveeditbox:Enable()
			else
				saveeditbox:Disable()
			end
		end)

		whisperlabel = Whisper:CreateFontString("$parentSubText", "ARTWORK", "GameFontHighlightSmall")
		whisperlabel:SetPoint("TOPRIGHT", editbox, "BOTTOMRIGHT")
		whisperlabel:SetJustifyH("LEFT")
		whisperlabel:SetJustifyV("TOP")
		whisperlabel:SetText(L.Placeholder)

		saveeditbox = MakeButton(L.Save, L.SaveDesc)
		saveeditbox:Disable()
		saveeditbox:SetPoint("TOPLEFT", enablewhisper, "BOTTOMLEFT", 2, -52)
		saveeditbox:SetScript("OnClick", function(self, button)
			Debug("+saveeditbox: %s", tostring(button))

			--PlaySound("igMainMenuOptionCheckBoxOn")
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			db.config.InvWhisper = editbox:GetText()
			editbox:SetText(db.config.InvWhisper)
			editbox:ClearFocus()
			saveeditbox:Disable()
		end)

		reseteditbox = MakeButton(L.ResetWhisper, L.ResetWhisperDesc)
		reseteditbox:SetPoint("LEFT", saveeditbox, "RIGHT", 10, 0)
		reseteditbox:SetScript("OnClick", function(self, button)
			Debug("+reseteditbox: %s", tostring(button))

			--PlaySound("igMainmenuOptionCheckBoxOff")
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			db.config.InvWhisper = L.DefaultInvWhisper
			editbox:SetText(db.config.InvWhisper)
			editbox:ClearFocus()
		end)

		Whisper:SetHeight(floor(enablewhisper:GetHeight() + editbox:GetHeight() + saveeditbox:GetHeight() + 54 + 0.5))

		--  Skinning  ----------------------------------------------------------

		local Skinning = CreatePanel("$parentSkinning", L.SkinningTitle)
		Skinning:SetPoint("TOP", Whisper, "BOTTOM", 0, -28)

		local enableskinning, applyskinning

		enableskinning = MakeCheckBox(string.format(L.SkinWith, "ElvUI"), string.format(L.SkinWith, "ElvUI"), string.format(L.SkinWithDesc, ADDON_NAME, "ElvUI"))
		enableskinning:SetPoint("TOPLEFT", Skinning, "TOPLEFT", 10, -10)
		enableskinning:SetScript("OnClick", function(this)
			Debug("+enableskinning \"%s\"", tostring(this:GetChecked()))

			local checked = not not this:GetChecked()
			--PlaySound(checked and "igMainMenuOptionCheckBoxOn" or "igMainmenuOptionCheckBoxOff")
			PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			db.config.elvSkin = checked

			if ns.skinned and not checked then
				applyskinning:Enable()
			elseif not ns.skinned and checked then
				_skinFrames()
				applyskinning:Disable()
			elseif ns.skinned and checked then
				applyskinning:Disable()
			else
				applyskinning:Disable()
			end
		end)

		applyskinning = MakeButton(L.SkinReload, L.SkinReloadDesc)
		applyskinning:Disable()
		applyskinning:SetPoint("TOPLEFT", enableskinning, "BOTTOMLEFT", 2, -10)
		applyskinning:SetScript("OnClick", function(self, button)
			Debug("+applyskinning: %s", tostring(button))

			--PlaySound("igMainMenuOptionCheckBoxOn")
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			ReloadUI()
		end)

		Skinning:SetHeight(floor(enableskinning:GetHeight() + applyskinning:GetHeight() + 34 + 0.5))

		--  Reset DB  ----------------------------------------------------------

		local Reset = CreatePanel("$parentResetDB", L.ResetDB)
		Reset:SetPoint("TOP", Skinning, "BOTTOM", 0, -28)

		local nuke = MakeButton(L.ResetDB, string.format(L.ResetDBDesc, GREEN_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE))
		nuke:SetPoint("TOPLEFT", Reset, "TOPLEFT", 12, -13)
		nuke:SetScript("OnClick", function(self, button)
			Debug("+nuke: %s", tostring(button))

			--PlaySound("igMainMenuOptionCheckBoxOn")
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			if IsShiftKeyDown() then
				wipe(db)
				ReloadUI()
			elseif button == "Button8" then
				if db.config.debug then
					Debug("*** Debug OFF")
				end
				db.config.debug = not db.config.debug
				if db.config.debug then
					Debug("*** Debug ON")
				end
			end
		end)

		local resetlabel = Reset:CreateFontString("$parentSubText", "ARTWORK", "GameFontHighlightSmall")
		resetlabel:SetPoint("TOPLEFT", nuke, "BOTTOMLEFT", 0, -8)
		resetlabel:SetJustifyH("LEFT")
		resetlabel:SetJustifyV("TOP")
		resetlabel:SetFormattedText(L.ReloadWarning, RED_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE)

		Reset:SetHeight(floor(nuke:GetHeight() + resetlabel:GetHeight() + 35 + 0.5))

		--  End space  ---------------------------------------------------------

		-- Little bit of free space under Reset section, just for the looks.
		local End = CreateFrame("Frame", nil, ScrollChild)
		End:SetPoint("TOP", Reset, "BOTTOM", 0, -8)
		End:SetSize(floor(ScrollChild:GetWidth()), 20)

		------------------------------------------------------------------------

		function Options:Refresh()
			overlay:SetChecked(db.config.overlay)
			defaultview:SetChecked(db.config.defaultView)
			quickmode:SetChecked(db.config.quickMode)

			if db.config.overlay then
				defaultview:Enable()
				defaultview.Text:SetFormattedText(L.DefaultView, ADDON_NAME)
			else
				defaultview:Disable()
				defaultview.Text:SetText(GRAY_FONT_COLOR_CODE..string.format(L.DefaultView, ADDON_NAME)..FONT_COLOR_CODE_CLOSE)
			end

			autorole:SetChecked(db.config.autoRole)
			autodecay:SetChecked(db.config.autoRoleDecay)
			autoconfirm:SetChecked(db.config.autoConfirm)

			if db.config.autoRole then
				autodecay:Enable()
				autodecay.Text:SetText(L.AutoRoleDecay)
			else
				autodecay:Disable()
				autodecay.Text:SetText(GRAY_FONT_COLOR_CODE..L.AutoRoleDecay..FONT_COLOR_CODE_CLOSE)
			end

			--[[	Won't show text on DDM without these until you change the value
			DDMs ain't initialized until you open the DDM part					]]--
			DD:SetSelectedID(db.config.defaultDifficulty - difficultyOffset)

			enablewhisper:SetChecked(db.config.sendWhisper)
			editbox:SetText(db.config.InvWhisper)

			enableskinning:SetChecked(db.config.elvSkin)
		end

		Options:Refresh()
		Options:SetScript("OnShow", nil)
	end)

--------------------------------------------------------------------------------
--	EOF
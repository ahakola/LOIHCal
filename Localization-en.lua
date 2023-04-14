--[[----------------------------------------------------------------------------
	LOIHCal

	English Localization
------------------------------------------------------------------------------]]

local ADDON_NAME, ns = ...

local L = {}
ns.L = L

--  Defaults  ------------------------------------------------------------------
L.DefaultInvWhisper = "Raid event \"%s\" is about to start, please accept this invite."
L.RemovedFromEvent = "|cffff0000Removed|r character \"|c%1$s%2$s|r\" from event \"%3$s\" (%4$02d.%5$02d.%6$04d %7$02d:%8$02d)"

--  Roles  ---------------------------------------------------------------------
L.Tanks = "Tanks"
L.Healers = "Healers"
L.Melee = "Melee"
L.Ranged = "Ranged"
L.Signups = "Signups"
L.Standbys = "Standbys"
L.DPS = "DPS"
L.NotReplied = "Not replied"
L.SignupDesc = "^%sName%s / +%sName%s\nEvent moderator\n%s@%sName%s@%s\nNo role data for auto-roles"

--  Invite bars / Think frame  -------------------------------------------------
L.TimeEstimate = "Estimated time left: ~%ds"
L.SendingInvites = "Sending invites..."
L.Cancel = "Cancel"
L.ServerWait = "Waiting for server-side data..."

--  Event view  ----------------------------------------------------------------
L.RaidDifficulty = "Raid Difficulty"
L.MassInvite = "Mass Invite"
L.MassInviteDesc = "Start Mass Invite"

--  Invite statuses  -----------------------------------------------------------
L.Inv = "Inv" --CALENDAR_INVITESTATUS_INVITED
L.Acc = "Acc" --CALENDAR_INVITESTATUS_ACCEPTED
L.Dec = "Dec" --CALENDAR_INVITESTATUS_DECLINED
L.Con = "Con" --CALENDAR_INVITESTATUS_CONFIRMED
L.Out = "Out" --CALENDAR_INVITESTATUS_OUT
L.Sta = "Sta" --CALENDAR_INVITESTATUS_STANDBY
L.Sig = "Sig" --CALENDAR_INVITESTATUS_SIGNEDUP
L.Not = "Not" --CALENDAR_INVITESTATUS_NOT_SIGNEDUP
L.Ten = "Ten" --CALENDAR_INVITESTATUS_TENTATIVE

--  Roles  ---------------------------------------------------------------------
L.Role = "Role: %s"
L.LastSeen = "Last signup: %s"
L.RoleDesc = "Change player role to %s"
L.Remove = "Remove"
L.RemoveDesc = "%sShift+Click%s to remove player from Auto-Role-list.\nPlayer will be re-listed if you open any events where the player has been given a role."

--  Tabs  ----------------------------------------------------------------------
L.Default = "Default"
L.Roles = "Roles"

--  Slash commands  ------------------------------------------------------------
--L.SLASH_COMMAND = "/loihcal"
L.CMD_LIST = "/loihcal ( %s | %s )"
L.CMD_CONFIG = "config"
L.CMD_RESET = "reset"

--  Config  --------------------------------------------------------------------
L.GeneralSettingsTitle = "General settings"
L.AttachMode = "Attach on top of the Default view"
L.AttachModeDesc = "Do you want to attach your %s frame on top or on side of the Default view?"
L.DefaultView = "Open %s view as Default"
L.DefaultViewDesc = "Open straight to %s view instead of Default view when opening event"
L.QuickMode = "Quick mode"
L.QuickModeDesc = "In quick mode, instead of selecting groups by clicking the group title, you use your mouse LeftButton/RightButton with modifiers None/Shift/Ctrl to determine where clicked player is sent.\n\nShift:\nLeft = Tanks - Right = Healers\nNone:\nLeft = Melee - Right = Ranged\nCtrl:\nLeft = Signups - Right = Standbys"

L.AutomationSettingsTitle = "Automation settings"
L.AutoRoles = "Auto-Roles"
L.AutoRolesDesc = "Automaticly give accepted/confirmed players roles. Given roles are based on previous roles."
L.AutoRoleDecay = "Auto-Roles decay"
L.AutoRoleDecayDesc = "Automaticly remove players from Roles-list if they haven't signed up for %i months or more."
L.AutoConfirm = "Auto-Confirm"
L.AutoConfirmDesc = "Automaticly Confirm players with role. Confirmed players cannot change their sign up status later while accepted players can."
L.AutoStandBy = "Auto-Stand By"
L.AutoStandByDesc = "Automaticly move signed up players to Stand By when the selected raid size has been filled."

L.DefaultSettingsTitle = "Default settings for new raid events"

L.WhisperSettingsTitle = "Whisper settings"
L.SendWhispers = "Send Whispers"
L.SendWhispersDesc = "Do you want to inform players with whisper on Mass Invite?"
L.Placeholder =  "Use %s in the whisper for event name placeholder."
L.Save = "Save"
L.SaveDesc = "Save whisper message."
L.ResetWhisper = "Reset to Default"
L.ResetWhisperDesc = "Reset whisper message back to Default."

L.SkinningTitle = "Skinning settings"
L.SkinWith = "Skin with %s"
L.SkinWithDesc = "Do you want to skin %s with %s?"
L.SkinReload = "Reload UI"
L.SkinReloadDesc = "You have to reload your UI to remove ElvUI skinning.\nPressing this button will reload your UI."

L.ResetDB = "Reset DB"
L.ResetDBDesc = "%sShift+Click%s to Reset DB"
L.ReloadWarning = "%sWarning:%s Pressing this button will reload your UI, delete all event- and role-data and restore Default settings."

--------------------------------------------------------------------------------
--	EOF

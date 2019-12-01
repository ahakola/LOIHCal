--[[----------------------------------------------------------------------------
	LOIHCal

	Simplified Chinese and Traditional Chinese Localization
------------------------------------------------------------------------------]]

if GetLocale() ~= "zhCN" or GetLocale() ~= "zhTW" then return end
local ADDON_NAME, private = ...

local L = private.L

if GetLocale() == "zhCN" then
--@localization(locale="zhCN", format="lua_additive_table", handle-unlocalized="comment", handle-subnamespaces="concat")@
return end

if GetLocale() == "zhTW" then
--@localization(locale="zhTW", format="lua_additive_table", handle-unlocalized="comment", handle-subnamespaces="concat")@
return end

--------------------------------------------------------------------------------
--	EOF
[![Build Status](https://travis-ci.com/ahakola/LOIHCal.svg?branch=master)](https://travis-ci.com/ahakola/LOIHCal)

# LOIHCal

LOIHCal is in game raid event signup role management addon created for guild &lt;Lords of Ironhearts&gt; of Arathor EU, but can be used by anyone. Addon was designed to be easy and fast to use with every button and action being (almost) self-explanatory.

### What it does?

* Works for all Player or Guild Event type raid events you can make calendar event for.
* Helps you visualize the raid setup by role view and by numbers at the bottom of the Frame.
  * Counter on the bottom of the Frame shows the total number of players with role, per role, combined number of DPS as well separated melee and ranged DPS and `Standby`.
  * Total counter is colored either `RED` or `GREEN` depending on your total `Accepted`/`Signed up`/`Confirmed` players and selected raid difficulty.
    * Mythic: `Green` when you have 20 players with role and `RED` when you have more or less than 20 players with role.
    * Other difficulties: `Green` when you have between 10 and 30 players with role and `RED` when you have more than 30 or less than 10 players with role.

* Opens and closes automatically when you view or close Player or Guild Event type event and can be set to attach on top of the Default Calendar event view.
* Can be set to automatically change players sign up status to `Confirmed` when you give them role or to `Standby` if you put them to the `Standby` group.
* Mass Invite tries to invite everyone with a role to a raid and set it up with your event settings.
* Skins nicely with ElvUI.
* Everything is saved per event so you can manage different type and size events without messing the settings.
  * 20man Mythic main raid and 10man Normal or 30man Heroic alt raid? No problem!
  * Guild raid and non-guild raid with friends? No problem!

### What is new?

This is only short memo on changes, and doesn't include all changes and fixes.

* NEW 7.2.4: Mark players without role or decayed autorole with red '@'-signs (`@Playername@`) when viewing event in LOIHCal and autoroledecay is turned on.
* NEW 70100-1.1: Mark players in current raid group with corner brackets ([Playername]) when viewing event in LOIHCal.
* NEW 60200-1.2: Almost full refactoring and multiple new features including: Config moved into Interface menu, slash handler, Auto-Roles, Quick Mode, ContextMenu, you can always sign yourself in LOIHCal now, even if you haven't `Signed up` yet...
* NEW 60200-1.1: Whisper settings in the Config.
* NEW 60100-1.2: Option to disable Auto-Confirm for players with role.
* NEW 60000-1.9: `Accepted`, `Signed up` and `Confirmed` are on top of the list, added Mass Invite progress bar and every loot method is onw available as an option for events.
* NEW 60000-1.8: Try to filter some of the invite spam.
* NEW 60000-1.3: Config, Attach on top of the Default Blizzard view, default settings for new events, skinning...
* NEW 60000-1.0: Updated pre-WoD raid difficulties into WoD difficulties.

### How to use it?

This describes the usage of the LOIHCals own view on raid events.

#### Old style

In the old style you pre-select the role for players and then start moving them into that rolelist until you change the role to different one.

1. Open raid event in Calendar.
2. Select the role you want to give to players by clicking the **title** of the rolelist.
3. Now the title bar should change color and you can start moving players into that role by clicking their name on any list you see (You cannot move `Declined`, `Tentative` or invited players unless it is yourself, use the ContextMenu instead).
4. Select new role by clicking other **title** or deselect your current selection by clicking the selected **title**.

#### Quick Mode

In Quick Mode you don't pre-select the role by clicking the titles of the rolelists, but you select them on the fly by using your keyboard and mouse.

Modifier | LeftButton | RightButton
-------- | ---------- | -----------
Shift | Tanks | Healers
None | Melee | Ranged
Ctrl | Signups | Standby

1. Open raid event in Calendar.
2. Select the role using **Shift**/**None**/**Ctrl** keys while clicking the names with **LeftButton**/**RightButton** according to table above.

#### Event settings

You can change the default settings for new events from the Config

* Use dropdown menus to select raid difficulty, loot method and threshold.

#### Misc.

* You can open the **EventInviteContextMenu** by clicking with **Alt+RightButton** on name in any rolelist (works also for `Declined`, `Tentative` and invited players) for all that goodness you previously needed to go to the Default Blizzard view.
  * You need to be either **creator** or **moderator** in the event for the ContextMenu to pop out.

* You can set your own signup status to `Tentative`/`Declined` with **Alt+LeftButton** on your own name on any rolelist (The click combination alternates between `Tentative` and `Declined`).
* **+** next to player name indicates event **creator** and **^** indicates event **moderator**.
* Mass Invite button will invite everyone `Accepted`/`Signed up`/`Confirmed` with role to the raid and set up the raid the way you wanted.
  * Players without a role (in Signups group) **won't be invited** even if they are `Accepted`/`Signed up`/`Confirmed` by Mass Invite. If you want them to your raid, give them role.
  * You need to be either **creator** or **moderator** in the event for the button to be enabled.
  * Players already in your raid group are marked with corner brackets for you to easily tell who is still missing from your raid group ([Playerinraid] vs Playernotinraid).

### Roles

Under roles tab you can check and alter the Auto-Roles LOIHCal has recorded.

* Scrollbar section lists all the players in the database and their most used role.
* Clicking the name opens you option to change their default role and shows latest event where they have `Signed up`.
* When player is selected buttons for different roles are enabled and by pressing them you can set players default role.
  * Changing players default role won't change their role in events where the player has been already given a role and this change can be over written automaticly by opening too many newer events (after the date and time of manual change) where the player has different role.

* When player is selected you can also remove all role data related to that player from database.
  * Player will be added back to database if you open up any events where the player has been given any roles.

### Slash commands

Use `/loihcal` or your own translated slashcommand to list available parameters like `config` to open LOIHCal config or `reset` to reset database and **reload UI**.

### Config

You can find config under `Interface -&gt; Addons -&gt; LOIHCal`

* General settings
  * LOIHCals attach point, either on the side or on the top of the Default Blizzard view.
  * Default view to be opened when shown, either LOIHCal or Default Blizzard view (enabled only when attached on top)
  * Enable Quick Mode (See "How to use it?" for explanation on Quick Mode).

* Automation settings
  * Auto-Roles, LOIHCal can keep track and set up previously used roles for players on raids if they are `Accepted`/`Signed up`/`Confirmed`.
  * Auto-Roles decay, automaticly remove any player who haven't `Signed up` for any of the raids in past 2 months to reduce the size of saved data (enabled only when Auto-Roles is enabled).
  * Auto-Confirm, confirms automaticly any player with role. `Confirmed` players can't change their sign up status later (they can remove the event), while `Accepted`/`Signed up` players can.


* Default settings for new raid events
  * Set up default difficulty, loot method and threshold for newly created events. You can still change them by event basis without messing anything, but with this you can set up the settings to match your guilds default way of doing things and save time when creating new events.


* Whispers Settings
  * LOIHCal can send whispers to players informing them why you are inviting them to raid on Mass Invite.
  * When editing the whisper remember:
    * Press **Enter** or **Save**-button to save it.
    * Press **Esc** to cancel any unsaved changes.
    * If you want to go back to default, just press the "**Reset to Default**"-button.
    * Use **%s** as a placeholder for event title on the whisper.
    * Line can't be empty, disable Send Whispers instead if you don't want to bother others.

* Skinning settings
  * LOIHCal can skin itself with ElvUI (ElvUI required)
  * Skinning will be applied as soon as you tick the box.
  * To remove skinning you have to press the Reload UI for the changes to take effect.

* Reset DB
  * If for any reason you want to remove all settigs and saved data you can **Shift+Click** the button to reset everything and **Reload UI**

### Now what?

* Download and use it
* Send me feedback and suggestions
* If you run into bugs, errors or any other weird situations, you can make a ticket or PM me at Curseforge.com (your Curse account should work there as well)
  * Try to give as much info about the error as possible and if you send ticket, **please check the ticket later in case I have asked you some extra information** about the error.
  * LOIHCal's Curseforge page: https://www.curseforge.com/wow/addons/loihcal
  * LUA error reports and/or screenshots are the hot stuff when fixing bugs
  * You can PM me also at Curse.com, but I don't check my PM:s in Curse.com as often as I do on Curseforge.com

* **If you are using any other language client than English, please consider translating this addon**
  * Drop your localizations at https://www.curseforge.com/wow/addons/loihcal/localization

* If you know LUA, take a look at the source and send me feedback how to make things work and look better!

### Translations

Language | Translator
-------- | ----------
German (deDE) | SpeedsharkX, pas06, Bommel2k9
Russian (ruRU) | mednik
Traditional Chinese (zhTW) | BNSSNB
Korean (koKR) | yuk6196

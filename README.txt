Cursive Forever 1.13.0 — 01.11.2026
Optional menu artwork: Jaina requires Cursive Character Pack 1.0.0 or newer. Extract CursiveCharacterPack beside CursiveForever into Interface/AddOns, enable both addons and fully restart WoW after first installation. Grimoire and Minimal do not require the pack.

Standard keeps up to eight main icons on one line. Already displayed, still-selected targets remain visible as combat begins.

Cursive Forever 1.13.0
=====================

For World of Warcraft: Forever.
Current client reference: 1.60.1 (70450), Release x64, build date Oct 15 2026.
Reported on Oct 17 2026. Earlier evidence retains its original client reference.
Created by Leandarh Valinor · Try Again Forever.
Deutsch: LIESMICH.txt
Release history: CHANGELOG.txt / VERSIONSHISTORIE.txt

Previous release 1.9.1: UTILITY CURSES AS MAIN EFFECTS

Curse of Weakness, Tongues, Recklessness, Exhaustion and the Elements can now be selected as Main under Spells & alerts in all four views. Thanks to thermanshs for the suggestion.

Selected curses use the normal main-effect order and count toward the eight main slots. They no longer also appear in the small curse or extra-effect display.

With fixed positions and Click to cast enabled, learned main curses can be cast on focus or target like other main spells. They stay visible when extra icons are disabled.

Existing selections are preserved. The Raid Curse Watcher remains independently configured.

Open /cf dots, enable Show for the desired context and check Main beside the curse. Use the arrows to place it in your order. Reload the UI after installation.

RELEASE 1.9.0: CLICK CASTING ON FOCUS AND TARGET

Left-click a learned main spell to cast it on your focus or current target. Works with fixed positions in Standard, Matrix, DoT bars and Health bars, including empty slots. Thanks to Myia for the suggestion.

Focus stays at the top: Standard and Health bars show Focus below the portrait; Matrix and DoT bars use a larger F beside it. The current target follows with the familiar target highlight. Other tracked enemies remain display-only.

When focus and target are the same enemy, both role rows stay visible, just like the normal target and focus frames. Suggestions count that enemy once.

Click casting is enabled by default for fixed layouts and can be disabled under Spells & alerts. Expiring first retains the ordinary display.

While click casting is active, change layout, size, position and window visibility outside combat. The window still follows its saved out-of-combat visibility setting.

Focus casts use the identified recipient in suggestions and fight records. Ambiguous recipients remain unconfirmed; a completed cast is still not proof of a hit.

Open /cf options > Display and choose Fixed order for Standard or Health bars.
Matrix and DoT bars already use fixed positions. In Spells & alerts, choose your
main effects and leave Click to cast enabled. Left-click a main effect in the
marked Focus or Current target row. Other enemy rows do not cast or select targets.
Change your target yourself (for example with Tab); the Target row follows it.
Normal range, line-of-sight, movement and cooldown rules still apply.
Use /cfclick off outside combat to return to the ordinary tracker.
After installing, reload the UI. The separate experimental click-test window
is replaced by the integrated rows.

RELEASE 1.8.0: CLEARER SETTINGS AND ONE SHARED SPELL LIST

Options now has four clearly named pages: Display, Spells & alerts, Review, and General & help. Both the grimoire and minimal design use this organization.

Display brings together view selection, sorting, size, transparency, header, frames, extra icons and out-of-combat visibility.

Spells & alerts combines spell filters, main slots and priority in one list. Solo, dungeon and raid filters stay separate. /cf dots and /cf filters open this page directly.

Execute has four direct choices: Automatic, Below 35%, Below 20% and Off. Suggestions, raid-marker priority and the Curse Watcher are grouped alongside it.

Existing settings are retained. Unavailable choices are dimmed with explanations, and longer pages can be scrolled.

Curse of the Elements can now be enabled in the spell list, uses the shared utility-curse place and can be assigned in the Curse Watcher.

Demonic Brand and Shadow Vulnerability (Improved Shadow Bolt) can now be chosen as main effects or extra icons. Thanks to thermanshs for these spell requests.

Open /cf options. Sorting and tracker appearance are on Display; /cf dots opens Spells & alerts for filters, main slots and priority. Language, minimap and options design are on General & help. Reload the UI after installation.

EARLIER RELEASE NOTES (menu names refer to their original versions)

RELEASE 1.7.8: COMPACT STANDARD ROWS AND DISPLAY OPTIONS

Standard with Expiring first no longer reserves an empty second large icon row when extra icons are enabled. Up to four selected main effects fit in one row; five to eight retain their second row.

Main effects keep their expiration order. Up to four additional effects use the compact two-by-two area, matching the fixed-order view.

Switching between fixed and expiration order waits when necessary to preserve running timers on enemies outside your view.

Adjust Duration sweep opacity from 0–100% in DoT layout (default: 58%). Apply the change outside combat with Apply and reload UI. Thanks to Myia for the suggestion.

Add Hide window out of combat under Combat display, off by default. The tracker returns when combat starts unless manually hidden; Options remain accessible.

Reload the UI after installation.

RELEASE 1.7.6: FRAMELESS TRACKING AND CLEARER TARGET SELECTION

The visible window header stays fully opaque when tracker transparency is increased.

Enable extra icons and Hide frame are available in all four views. Hiding extra effects and the separate utility curse makes the tracker narrower; main DoTs, raid markers and Execute indicators remain visible.

Hide frame removes the background, outer frame and row borders with less outer padding. A green bracket on the left marks your selected enemy in every frameless view.

In Health bars, the row-height slider now changes the visible health bar height as well as row spacing. Text and icons keep their size; minimum dimensions preserve readability. At 100%, the familiar layout is retained.

Extra icons start enabled and frames remain visible by default. The header can still be switched independently.

Open Combat display for frame and extra-icon settings; adjust row height under General. Reload after installation.

PREVIOUS RELEASE

RELEASE 1.7.5: MORE FLEXIBLE TRACKER SIZING

The main tracker's overall scale now ranges from 40–130% in 5% steps, allowing
a smaller display than before. Your existing scale is retained; 100% remains
the default.

Width and row height can also be adjusted independently for each of the four
views: Standard, Matrix, DoT bars and Health bars. These controls change the
layout dimensions while keeping icons and text in proportion. The space
needed for the contents sets the minimum width and row height.
Each view saves its own dimensions; reset them to 100% to return to that
view's normal proportions. The overall scale applies to the main tracker.
Reload after installation.

PREVIOUS RELEASE

RELEASE 1.7.4: CLEARER SORTING CONTROLS

Open DoT layout with /cf dots. Under Order, choose Fixed order or Expiring
first directly. The selected option stays marked, and tooltips explain how
each choice arranges effects in Standard and Health bars: your configured
effect positions, or the effects with the shortest remaining duration first.
Health bars now follows this same sorting choice. Matrix and DoT bars keep
your configured fixed effect order. Your saved sorting preference is retained.
Reload after installation.

PREVIOUS RELEASE

RELEASE 1.7.3: HEALTH BARS VIEW

In Combat display, select Health bars. Each enemy has a portrait and raid
marker on the left, a large health bar with name, current/maximum HP and
percentage in the middle, and effect icons with their countdowns on the right.
Main effects follow your selected priority; four extra effects occupy two
rows of two. Your utility curse and Execute swords remain available.
Select at least one main slot in DoT layout for this view.

The four direct choices are Standard / Matrix / DoT bars / Health bars.
DoT bars is the existing Bars view under a clearer name. Your saved view
is retained until you select another. Requested by thermanshs.

Longer enemy names have more room inside the existing health bar, without
increasing window width or row height. Reload after installation.

The supplied beta1 screenshot and three-enemy combat video, together with the
user confirmation, show health and countdown updates, target changes and
removal at the three shown deaths on client 70450. The final name-width
adjustment is new in this release; view switches and offscreen deaths were
not separately demonstrated in that recording.

PREVIOUS RELEASE

RELEASE 1.7.2: BARS AND TRACKER TRANSPARENCY

The shorter tracker title retains the author and existing window dimensions.

In Combat display, select Standard / Matrix / Bars directly. Bars groups the
selected main effects under each enemy in the priority order from DoT layout.
Show spell names is available only for Bars; disabling it reduces the width.
The four extra-effect icons sit at the portrait, with the personal curse nearby.
Bars always puts HP% inside a health bar: left at 70% or above, right below
70%. Standard and Matrix keep their own saved health display choice. Under
General, Transparency changes only the main tracker. Other windows stay opaque.

The release includes the beta2 health-bar correction. Please reload after installation.
Each DoT bar indicates the remaining proportion of its own duration; numeric
countdowns give seconds. Bars view requested by BenTheMan.
The supplied beta2 screenshots confirm the shown health bars and percentage
positions, including two enemies with and without action suggestions on 70450.
This release preserves beta3 behavior and layout; not every class or native
rendering path is independently verified by these screenshots.

PREVIOUS RELEASE

RELEASE 1.7.1: CLIENT MAINTENANCE

Update the client and release metadata for WoW Forever 1.60.1 (70450).
The screenshot confirms Release x64 and build date Oct 15 2026. The user
reports that all functions they observed in game were working. This report
does not represent a separate check of every class, talent or optional path.
Runtime behavior is unchanged from the exact delivered 1.7.0 release. Layouts,
tracking, Curse Watcher, suggestions, settings and archives are preserved.

FEATURES INTRODUCED IN 1.7.0

RELEASE 1.7.0: COMPACT VIEWS AND CURSE WATCHER CORRECTION

Cursive remains a multi-target DoT and debuff tracker. This release adds the
compact Matrix alongside Standard, narrows the Standard display and arranges
up to four additional effects in two rows of two in both views. Matrix rows
keep portraits, health, raid symbols, a separate utility curse and native times.
Partial aura updates retain the selected layout, and the complete curse/time
area stays clear of the highlighted target frame.

The Curse Watcher now handles a change to another utility curse, including
Recklessness, without continuing the old assigned-curse estimate. It keeps its
three assignment choices. Cast completion still does not prove a hit; a
readable matching aura can confirm that the assigned curse remains present.

This release promotes the exact delivered beta6. Optional action suggestions
remain EXPERIMENTAL and off on a fresh installation. Existing settings, filters,
recordings and the protected offscreen-retention behavior are preserved.

STANDARD, MATRIX, DOT BARS AND HEALTH BARS

Cursive remains a multi-target DoT/debuff tracker. Under Combat display > View,
choose Standard, Matrix, DoT bars or Health bars; Standard is the default and the choice
is saved. FULL/minimal independently selects the options-window design.

Matrix shows the selected main-effect symbols once above each column of up to
20 enemies. Each enemy has its own remaining-time cells below. Choose and order
up to eight effect families with /cf dots. Matrix always uses these fixed
columns; the shared Expiring first/Fixed order preference for Standard and
Health bars stays saved. With no selected main effect, Standard is used. The shared effect headings remain
visible when the optional window title is hidden.

The five Warlock families Corruption, Agony, Immolate, Wrack (Zermürben) and
Siphon Life fit the Matrix, as do selections from all nine class catalogues.
Wrack is now also selectable in the display/filter catalogue, using the existing
1316697 family already used by the Performance Monitor. This does not extend
the experimental three-DoT action preview. Eight main families remain the limit.

Times remain owned by the native aura slots. A small gold presence mark belongs
to an active slot, including permanent effects without a countdown. Matrix
keeps up to four extra effects in two rows of two: 14-unit icons with separate
8-unit time text beside each icon in a 96-by-30 area. Standard also uses two
rows of two, with its existing times below, in a 40-by-50 area. Matrix row
steps are 38 units without suggestions and 70 with them.
The shared symbol heading is 22 units high. Standard keeps 60/110 for one/two
main lines without suggestions and 70/120 with them.
The main time columns use a 28-unit pitch.

Standard moves the portrait towards the left frame and gives the curse column,
gold divider and first main effect equal smaller visible gaps. Main icon sizes,
fonts and the 70-unit health column stay unchanged. The smaller four-extra
area also reduces the reserved width. The curse's separate native time retains
its own 28-unit width.

A view change that would interrupt retained offscreen effects is queued.
The current display stays intact until the switch is safe or combat ends;
click the view action again to cancel. This protects view changes without clearing retained countdown objects.
The new geometry reads no aura contents, native times or native visibility,
and calculates no replacement countdowns.

Historical 1.7.0 validation: 344 local checks passed (207 behavior and 137
maintenance cases); its nine runtime files compiled. TrackerTrace, DeathEvents, ExecuteIndicator, ExperimentalPlanner
and ExperimentalPreview remain byte-identical to 1.6.2. The supplied beta6
video confirms two Weakness → Recklessness → Weakness cycles on one enemy:
the warning hides for the assigned curse and returns for the competing curse.
The evidence and remaining limits are described below.

PREVIOUS RELEASE NOTES (historical)

RELEASE 1.6.2: REDESIGNED, MORE COMPACT COMBAT DISPLAY

The portrait-based Standard view now uses compact, evenly spaced enemy rows.
Main effects align with the extra-effect area. Eight extra symbols fit in two
rows of four, including their native remaining times; the fifth symbol starts
the lower row. One utility curse sits beside the portrait. The unnecessary
side stripe is gone; the portrait ring, row border and raid markers identify
your targets. Both small rows and their times were confirmed readable in game
at the user's tested scale on 1.60.1/70374.

There is currently one tracker view, used automatically. The redundant Standard
radio button is removed from both options designs. FULL/minimal still chooses
the appearance of the options window. The optional header, creator credit,
Execute hint, health choice, spell filters and saved preferences are retained.
The Contact & feedback foreground fix is included.

This release uses beta5's normal four-across order, with the same sizes and
spacing. The temporary column-first test layout is removed. The optional
action preview remains EXPERIMENTAL and off on a fresh installation.
315 local cases pass: 192 behavior and 123 maintenance cases.

FEATURES AT A GLANCE

- Track your own DoTs and debuffs on up to 40 enemies.
- Choose Standard or Matrix; compare up to eight shared main-effect columns.
- Choose health bars or percentages and preserve your saved preference.
- Use an Execute hint with four modes; Automatic is the default.
- Hide the window header, including its creator credit, to reclaim its height.
- Use compact evenly spaced rows, shared suggestion priority and death notifications.
- Choose up to eight main families for either view; Standard also offers expiration sorting.
- Put a utility curse by the portrait in either view.
- Use the animated FULL grimoire or the simple minimal options design.
- Keep existing filters, positions and Raven Archive recordings when updating.
- Optional Warlock action suggestions remain EXPERIMENTAL and off on a fresh
  installation. They estimate renewals and do not confirm hits.

INCLUDED SINCE 1.6.1: EXECUTE HINT AND OPTIONAL WINDOW HEADER

Combat display now offers four Execute modes: Automatic (default), Below 35%,
Below 20%, and Off. Standard shows crossed swords and a steady gold Execute!
beneath the health display; Matrix shows the swords at the portrait. Neither
needs a separate extra row. Automatic checks learned class abilities and
talents; fixed thresholds work for any class.

Automatic profiles: Warlock with Decimation and Rogue with Quietus below 35%;
Warrior with Execute and Paladin with Hammer of Wrath at or below 20%; Priest
with Early Demise and a learned Shadow Word: Death at or below 20%. Other
classes receive no automatic hint. The two manual thresholds are strictly
below the chosen value. The hint identifies a health range, not an active proc
or spell readiness. An unavailable enemy retains only a dimmed last observation;
changing the setting clears an old hint until a matching live unit is available.

General > Show window header is on by default. Turn it off to remove the title
bar and its height, including from the empty window. Drag the unlocked window
by its empty background when the header is hidden. A disabled-enemy-nameplates
warning temporarily keeps the header visible. Author information and a copyable
CurseForge comments link are under Help & info. The visible header also carries
"created by Leandarh Valinor". Thanks to AbelBeja for suggesting the hideable
version header!

Update the CursiveForever folder while WoW is closed; keep SavedVariables.
The experimental preview stays off on a fresh installation and retains an
existing choice. Its planner still assumes unlimited enemy life. Tracker,
death-event handling, aura layout, preview and planner modules are preserved.
Beta4 client session 95 confirmed matching PARTY_KILL and UNIT_DIED events
clearing their rows at the same timestamps. This does not establish complete
event delivery with no available unit. The separate Death Probe is not needed.
The user confirmed both manual Execute thresholds in
game on 1.60.1/70374: hidden before the threshold, visible below it, with 20%
appearing later than 35%. The screenshot shows the indicator beneath the health
bar and the hidden header. Automatic talent recognition remains unverified in game.

ESTIMATED FIRST APPLICATIONS

When the addon observes the new combat start after a known out-of-combat state,
the preview can plan an enabled DoT that has no own application recorded on
that enemy. Example: Agony and Corruption are still running; Immolate can fit
before the next renewal, so Immolate is suggested now. Due priorities across
enemies and cast/GCD timing still apply. Enemy life remains unlimited.

This is an estimated first application, marked ~ with an explanation in its
tooltip. It does not establish aura absence or create a confirmed application.
Mid-fight reload/reset or uncertain cast association disables this assumption.
A previously incomplete enemy history stays incomplete; newly tracked enemies
in a later fully observed fight can qualify. Preview on/off keeps the history.
Enable only learned, wanted effects. Automatic miss detection remains unavailable.

Initial-application assumptions remain separate from the native display.
Automatic hit/miss detection is still unavailable.

INSTALLATION / UPDATE

Close the client and place the CursiveForever folder in Interface/AddOns.
CursiveForever.toc must sit directly inside that folder. Replace the previous
addon files and keep SavedVariables so settings and recorded fights carry over.
Enable Cursive Forever in the character selection screen's addon list.
This is the complete release package. Install one CursiveForever folder,
not nested copies or parallel versions. Do not delete SavedVariables.

EXPERIMENTAL ACTION SUGGESTIONS

This release includes a separately marked experimental Warlock preview for Bane of
Agony, Corruption and Immolate. It is off on a new installation; your saved
choice survives updates. Use /cfexp on, or Suggestions beside DoT layout in
Combat display. Right-click that switch or use /cfexp for enabled effects,
durations, cast times and global cooldown (GCD), plus a link to the common
DoT order. These preferences and the shared order are saved per character.

Each usable enemy row shows up to two planned actions. Green 1 means the first
action is due now; gold 1 means it is planned for later. Blue 2 marks the
following global action. Apply labels a first application, Casting an open
attempt, and in ...s an upcoming renewal. The ~ symbol marks an estimate. An unknown timer without a complete combat history does not enter the plan:
? is not an instruction to cast. First applications in a fully tracked fight
use the separate estimate described above. Known timers retain their normal
renewal schedule.

The priority follows your saved DoT order. Priority wins among due actions;
otherwise the earliest upcoming action wins. The second action
simulates the first application and its cast/GCD time. Other row previews
continue after those two global actions. A cast may start before expiry so its
estimated completion coincides with expiry. High priority alone does not
justify an early refresh.

Example: Immolate is overdue on A; Agony is due on B and C. The global plan is
Agony on B, then Agony on C. Agony becoming due during the first action can
also take the second slot. Priorities are your chosen rules, not measured
damage per cast. The model assumes unlimited enemy life; decide yourself
whether another DoT will have time to do useful damage.

The preview uses a separate ESTIMATED timer model. A completed cast does not
confirm a hit. Misses, resists, dispels and replacements cannot be detected
reliably. Freely readable own-aura values may correct estimates; nil or
protected values never establish absence. The native DoT display is the visual
reference and is not read back to calculate suggestions. Estimated timers are
not submitted as confirmed applications to Raven statistics or the Curse
Watcher.

Above the action icons, "Attempt: ..." identifies a pending attempt. A spell
name followed by ? identifies the last completed, unconfirmed attempt on that
row. If you see it miss or resist, RIGHT-CLICK THAT LABEL to mark that exact
effect on that enemy due again. This works even when that spell is no longer in
either suggestion slot and your selected target has changed. It is a manual
correction, not automatic miss recognition. The right-click does not cast a
spell.

Alternatively, select the affected enemy and use /cfexp miss immolate, agony or
corruption. The German aliases feuerbrand, omen and verderbnis also work. Alt +
right-click a suggestion icon marks that icon's row/effect due again. Normal
casting on the selected target is required: its identity is recorded when the
cast is sent. Mouseover/focus macros and different enemies with identical names
cannot be resolved reliably. Disable unlearned effects in /cfexp.

The session model now records eligible own casts even while the preview is
hidden. Switching it on or off preserves the model, including in-flight casts.
/cfexp reset and reload/world entry still clear the model. During combat,
unknown timers stay unknown; a subsequent fully tracked fight can qualify
new enemies for estimated first applications. Actual cast ranks are learned from your attempts. Durations use
readable observations or rank/base values, with configurable overrides for
talents and server differences; 0 restores automatic values.

Turning the camera away keeps the remembered row and its last health number/bar,
without an Out of view overlay. Native countdowns are retained while their
binding remains safe. Before clearing a reused binding, the tracker tries a
readable matching target, focus, mouseover, pet target or target's target.
Their aura changes can update the native display. Without a usable matching
unit, the grid can still become empty; continuous offscreen countdowns are not
guaranteed. This applies with suggestions on or off.

Known estimated timers remain in the global plan and carry ~ while offscreen.
Last displayed health and retained native visuals are not fresh measurements
or proof of life, continued aura presence or a hit. They never supply unobserved
performance ticks.

A readable confirmed death with matching identity removes the row and estimates,
including on nameplate removal if the evidence is still available. Returning
enemies reconnect by identity; combat end clears remembered rows. Filter/order
changes and layout/binding failures can invalidate native objects; remembered
identities and estimates remain. Standalone readable death events now also
remove the matching row without a unit token. If no usable death evidence arrives,
cleanup cannot be immediate; a missing nameplate or 1 HP is not proof of death.

OPTIONS AT A GLANCE

/cf options opens the saved options design. FULL is the default, including
when upgrading without a previous design choice. It displays Gul’dan holding
an open grimoire. Choose minimal for the familiar simple window. Both designs
use the same settings, real controls and automatically fitted window size.
FULL/minimal is stored in the addon's shared settings and survives /reload.
This options choice is separate from the live tracker's Standard row layout.

The four chapters, in order, are General, Combat display, Review and Help & info.
Clicking a chapter further down turns forward; clicking one above turns back.
Skipping chapters uses one short turn. Clicking the current chapter does not
animate. Fast clicks retain the last requested chapter; closing the window or
changing design settles the selection and stops the animation.

FULL has horizontal working sliders. Help & info carries the lower-right
signature: created by Leandarh Valinor. This inscription belongs to the right
page and follows that Help page during turns. Both leaf faces remain opaque,
with normally readable titles and inscription.
FULL/minimal is selected on an ornamental clasp
below the bookmarks; minimal retains the simple selector on General.
The parchment is darkened and the addon title is split across both pages.
Use /cf grimoire (or /cf full) and /cf minimal to choose and open a design.

/cf options provides these four chapters:
- General: language, minimap, tracker lock, header, size and position.
- Combat display: Standard/Matrix view, health display, DoT order, suggestions, out-of-combat target,
  class filters, priority marker, Execute hint and Curse Watcher.
- Review: monitor, card selection, recording and Raven window size/position.
- Help & info: controls, commands, version history and the compact status.

Controls use two aligned columns. DoT layout and Suggestions share one row. Changes apply
immediately. The shorter window fits the available screen automatically.
The last tab stays selected when reopening during the same session.

QUICK START AND LIVE TRACKER

Enable hostile nameplates for reliable enemy discovery. The title bar warns
when they are disabled and shows the client's assigned toggle key.
Use /cf options to choose language, health display, spell filters and size.
The movable minimap button opens Options on left-click and toggles the live
tracker on right-click.

Up to 40 enemies appear in two columns of 20, with health and your own harmful
effects. Standard is the default, initially sorted by remaining duration.
Standard and Health bars share the Fixed order/Expiring first choice.
Matrix uses the selected fixed columns; DoT bars follows that order vertically.
The current target is highlighted.
Standard shows portraits, health and effects without enemy names. Choose
Combat display > View to switch to Matrix with shared symbols above the times.
Outside combat, only the selected hostile
target is shown. Solo and group combat uses player/pet involvement; raids
include visible hostile nameplates. Tracked combat enemies can remain when
their nameplates leave view. Dead enemies disappear. Rows do not target enemies.

Choose Health display in the Combat display options: Bar is the default;
click to select Percent. The bar replaces the percentage line, with the health
number above it in Standard and inside it in Matrix. Matrix keeps both
absolute health and percentage when Percent is selected. Green, yellow and red
follow the current health level.
The choice is saved. Existing saved
preferences, including Percent, are retained when updating.

DOT ORDER AND PORTRAIT CURSES

Open /cf dots (also /cf anordnung), or Options > Combat display > Configure
DoT layout. Under Order, choose Fixed order or Expiring first directly.
The selected option stays marked, with a tooltip explaining each choice.
This sorting choice applies to Standard and Health bars; Expiring first is
the default. Fixed order keeps the selected effect at the same position on
every enemy, even when no matching aura is displayed. Expiring first shows
the effects with the shortest remaining duration first. Matrix and DoT bars
keep your configured fixed effect order.

Select up to eight effect families and move them with Up/Down. Warlocks start
with Corruption, Agony and Immolate; you can add Wrack and Siphon Life or adjust
this list freely. In Standard four slots fit on a line; a fifth starts a second.
Matrix puts all selected main families into one shared set of columns. The order
is saved per character. Other enabled effects, including unknown/new effects,
use up to four extra places on the right, in two rows of two in both views.
Times sit below Standard symbols and beside Matrix symbols. Existing spell filters still
apply; a filtered family keeps its space empty rather than shifting columns.
An empty slot is not a cast recommendation or proof of a missing aura.

For Warlocks, Utility curses by the portrait is enabled initially. Both views
show your Weakness, Tongues, Recklessness or Exhaustion in one small slot
beside the portrait, with its native time below.
Raid target symbols remain overlaid on the portrait and inside the row. Disable the option to return
these curses to the normal effect strip.
This display option is independent of the personal Raid Curse Watcher.

SPELL FILTERS

/cf filters opens your current class's filters. All nine classes have a
catalogue of effect families with separate Solo, Dungeon/Group and Raid
checkboxes. Show All / Hide All applies to that class's listed families.
Effects outside the catalogue stay visible. Existing Warlock and Druid
preferences are preserved; /cf owl still opens the Druid matrix.

Ranks are supplemented from the client spellbook outside combat, on login and
spellbook changes. Triggered rank candidates for traps, poisons and judgements
are accepted only when their client-language names match the relevant family.
New Forever variants may still need catalogue updates and in-game checks.
Filters are shared by characters of the same class.

A preferred raid marker moves matching rows to the top; Skull is the default.
Client restrictions can limit markers during combat.

PERFORMANCE MONITOR AND ARCHIVE

Open with /cf performance or Options > Review. The monitor
opens only on request. Up to five class-specific cards show:
- Damage and share: values from the client's native DamageMeter.
- Casts: completed attempts, including unconfirmed or unsuccessful attempts.
- Uptime and refreshes: reconstructed from confirmed player applications.

The summary includes total damage, alive time and deaths. Click a card for
target filters, coverage, gaps and the cast/refresh timeline. The Raven Archive
keeps up to 30 eligible fights per character, including wipes. Recording can
be disabled. Minimum duration: 15–60 seconds in 5-second steps, default 45.
Individual fights or the character's whole archive can be deleted in the UI.

CHOOSING CARDS

/cf cards (or Options > Review > Choose cards) selects up to five supported effects.
Check/uncheck a row and use Up / Down to set the order from left to right.
Slot 3 is the large central card. Selection and order are saved per character;
an empty selection is allowed. Restore defaults returns to the recorded order.
The optional unused-card filter hides values and click areas for effects with
neither damage nor casts, when damage data is available. The fixed raven
artwork, including its decorative card frames, remains in place.

All supported effects continue to be recorded regardless of card visibility.
Changing the display does not rewrite history. A selected effect absent from
an old fight shows Not recorded and no numerical values. Details follow the
selected effect even when the cards are rearranged.

Paladins now have a Consecration damage card. Hunter traps have spell-family
IDs and one combined damage card. These area effects show damage and share;
cast counts, target coverage and refresh/tick metrics are unavailable.
Other class profiles retain their supported effect families. Spell damage
can include direct and periodic components; it is not labelled as tick-only.

The archive arrow toggles the list. Compact view hides large cards and archive.
The monitor has its own 50–120% scale in 5% steps. Options > Review >
Size & position also provides centering and a 100% reset. Drag the
window to move it. Scale, position, archive and compact state are per character.

READING INCOMPLETE DATA

The client can block aura access. Empty or protected results do not prove a
miss. Completed casts or measured damage do not prove aura timing. Affected
cards/details show Client restriction or Unconfirmed; unavailable uptime,
refresh and tick values remain —. Readable name lookups can still confirm
applications after the index lookup has been blocked.

Uptime uses confirmed applications and durations across relevant target time.
Three targets present for 100 seconds each give 300 target-seconds; covering
one throughout is about 33.3%. Early removals after confirmation are not
monitored continuously. Partial recording means some target time could not be
assigned; detail coverage can differ from the overview. Old fights retain
their stored values and available overview/details.

For Agony, Immolate and Corruption, tick estimates model a renewal that restarts
the tick timer. Base intervals: Agony 2 seconds, Immolate/Corruption 3 seconds,
without haste. The comparison starts with the first confirmed application and
assumes continuous renewal after expiry. Gaps can contribute to the difference;
a delayed tick can catch up before fight end. Dead or unavailable targets accrue
no further modeled loss. Discarded tick progress and lost ticks must not be
added together. Immolate's direct hit is not a periodic tick. These figures
are estimates, not measured lost damage. The calculation help explains more.
Each effect keeps up to 128 targets and its newest 256 cast events; shortened
records are labelled.

PERSONAL RAID CURSE WATCHER

Choose Weakness, Tongues or Exhaustion under /cf curse. The warning uses your
completed casts as a reminder, not proof of the curse on the target. Without readable confirmation it shows CURSE UNCONFIRMED; an elapsed personal
timer shows REMINDER EXPIRED. Near expiry it prompts renewal; the threshold is
3–10 seconds. Empty aura queries do not prove absence.
A completed different utility curse, including Recklessness, clears the old
reminder only for its associated enemy. The requested curse must match by
readable spell-family identity. A missing or ambiguous cast target cannot
create a new reminder, and a completed cast is not proof of application.
The test button or /cf cursetest previews it on a hostile target outside a
raid. The same control ends the preview.

LANGUAGE AND APPEARANCE

Auto uses German on deDE clients, English otherwise. Deutsch or English can
be selected without changing spell recognition. Options also offer Subtle,
Raven and Full themes, tracker scale and position controls.

COMMANDS

/cf                 Toggle live tracker
/cf show / hide     Explicitly show / hide tracker
/cf options         Options (aliases: option, opt)
/cf performance     Performance Monitor (alias: perf)
/cf filters         Current class spell filters (aliases: filter, spells)
/cf cards           Choose and order Raven cards (German alias: karten)
/cf owl             Druid filters (aliases: owlcorner, banther)
/cf curse           Curse Watcher settings (alias: fluch)
/cf cursetest       Toggle curse preview (alias: curse test)
/cf history         Recent release notes (alias: changelog)
/cf reset           Reset live tracker position
/cf diagnose        Compact, copyable status report

The status opens only on request. It shows client/addon version and confirmation
counts for the current, last completed or newest archived fight. The last
completed fight is available until reload even below the archive minimum.
Select text and Ctrl+C copy the report; ESC closes it. Earlier diagnostic
commands open this same report. Debug and manual scan commands are retired;
detailed error collections are no longer saved.

RELEASE STATUS AND KNOWN LIMITS

Current client reference: WoW Forever 1.60.1 (70450), Release x64, build date
Oct 15 2026. The user reports all observed functions working on this client.
The new beta2 screenshots on 70450 confirm the shown Bars health bars,
percentage positions and two-enemy display with and without suggestions.
The following earlier screenshots and beta6 video were recorded on 70425;
they are retained as evidence for that client. Supplied screenshots show
Standard and Matrix in game and confirm
the corrected Matrix border clearance at the shown scale. The supplied beta6
video confirms two Weakness → Recklessness → Weakness cycles on one enemy:
the warning hides for Weakness, returns for Recklessness, and hides again for
Weakness. The enemy row clears at the shown death. This confirms that sequence,
not all ranks, multiple-target associations or unavailable-unit paths.
Earlier gameplay evidence belongs to 1.60.1 (70374): small timers, manual
35%/20% Execute behavior and matching death cleanup. Automatic talent recognition
and the foreground contact dialog have no separate new client confirmation.

TrackerTrace, DeathEvents, ExecuteIndicator, ExperimentalPlanner and
ExperimentalPreview are byte-identical to 1.6.2. Display geometry and the view
choice remain separate. Retained native aura widgets are preserved; an
incompatible switch waits instead of clearing an offscreen display.
This does not prove complete death-event delivery without any available unit.
Unknown death state is not guessed. Without a matching readable unit the native
aura grid can still become empty; this remains a separate limitation.
Cast completion is not hit confirmation; observed misses remain manually
correctable. Wrack and Siphon Life are selectable in the display catalogue;
the experimental preview still covers only Agony, Corruption and Immolate.

The beta2 basis passed 365 local cases: 219 behavior, 137 maintenance and
9 tracker-transparency cases. Its eleven runtime modules and test coverage
are retained, apart from the shorter title and release metadata. Tests/ is not
loaded in WoW. These checks do not reproduce the full native renderer,
duration-object lifetime or protection system.

TRACKER REPORTS

Recording is enabled by default unless previously disabled. /cftrace on enables
it and leaves an already running recording intact. /cftrace off stops recording
and saves the current report. /cftrace clear deliberately removes saved reports
and clears both buffers; if recording was active, a new partial recording starts.

/cftrace shows the active recording, or the latest completed one outside a
recording. /cftrace 1 through /cftrace 5 selects the five most recent completed
reports, newest first. Each new report has a persistent session number, local
start time when available, and duration. Starting mid-fight is marked
RECORDING_START_MID_COMBAT; deliberate clearing is marked
RECORDING_RESTARTED_AFTER_CLEAR. These are partial recordings, not full fights.
The prior version's single saved report is retained when history is first saved.
Completed reports survive normal reload/logout; unfinished recordings remain
session-only. Keep SavedVariables when updating. History commands have local
test coverage; the supplied client recording shows the new report header.

Two independent rings retain at most 256 tracker transitions and 256 cast
decisions per recording; new cast traffic cannot evict camera transitions.
D1/D2 identify enemies anonymously; C1/C2 identify attempts anonymously. Selected
is the target snapshot at SENT, not proof of the recipient. Assigned is the
model association. ESTIMATE is a completed attempt used for a timer, not a hit
confirmation. No names, raw GUIDs, health, aura contents or hit/miss outcomes
are collected. No aura queries, native widget reads or polling are added.

Tests/ remains outside the TOC. Preserve its camera, death, layout, priority
and maintenance expectations. Retained visuals never add unseen measurements.

NEXT STEPS

Continue targeted testing of the experimental action preview and open display cases. A reliable aura-driven
planner remains dependent on accessible client data. Lifetime extrapolation
and a Curse Watcher redesign are deferred. ROADMAP.txt retains those plans.

UPDATE AND SUPPORT

Close the client before replacing the addon folder. Keep SavedVariables so
settings and archived fights carry over. Old unmatched damage is not invented
or retroactively assigned. FULL/minimal, artwork and page turns are unchanged.
For an unexpected result, /cf diagnose shows the latest recording's status.
After exiting normally, the saved data is located at:
  _classic_beta_/WTF/Account/<account>/SavedVariables/CursiveForever.lua

Full history: CHANGELOG.txt. 
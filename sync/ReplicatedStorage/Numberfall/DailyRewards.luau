-- DAILY LOGIN REWARDS: a 7-day calendar. Claim once per UTC day (Main menu > DAILY REWARD, or the card that pops up
-- when there's one waiting). Claiming on consecutive days walks you along the week and day 7 pays the most; miss a
-- day and you start again from day 1. After day 7 the week starts over (the streak keeps counting).
-- Used by ServerScriptService.ProfileService (ClaimDaily) and StarterPlayerScripts.DailyRewards (the card).
local D = {}
D.Marks = {100, 150, 200, 300, 400, 500, 900}
-- which day of the week a streak of `streak` claims lands on (1..7)
function D.DayFor(streak) return ((math.max(1, streak) - 1) % #D.Marks) + 1 end
return D

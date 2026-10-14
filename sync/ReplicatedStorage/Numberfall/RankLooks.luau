-- RANK LOOKS: the visor and the dash / slide trail a player wears, picked in Loadout > VISOR / TRAIL. They aren't bought:
-- ranks unlock them -- OWNER has all four, MOD has MOD + VIP, VIP has VIP; everyone has Standard.
-- Player attributes VisorStyle / TrailStyle hold the choice (saved in the profile, ServerScriptService.ProfileService);
-- unset, or no longer owned (VIP lapsed), falls back to the best one you have -- so by default ranked players wear theirs.
--   RankLooks.Visor(player) / RankLooks.Trail(player) -> "Standard" | "VIP" | "MOD" | "OWNER"
--   RankLooks.Owns(player, id), RankLooks.Best(player), RankLooks.LockText(id), RankLooks.Name(list, id)
-- The TRAIL can also be a bought trail colour (Numberfall.TrailColors, owned once: OwnHair_<id>): RankLooks.ValidTrail.
local TrailColors = require(script.Parent:WaitForChild("TrailColors"))
local M = {}
M.Visors = {
	{Id = "Standard", Name = "Standard"},
	{Id = "VIP", Name = "VIP Visor"},
	{Id = "MOD", Name = "Mod Visor"},
	{Id = "OWNER", Name = "Owner Visor"},
}
M.Trails = {
	{Id = "Standard", Name = "Red"},
	{Id = "VIP", Name = "Amethyst"},
	{Id = "MOD", Name = "Steel"},
	{Id = "OWNER", Name = "Crimson & Gold"},
}
local VALID = {Standard = true, VIP = true, MOD = true, OWNER = true}
function M.Valid(id) return VALID[id] == true end
function M.ValidTrail(id) return VALID[id] == true or TrailColors.ById[id or ""] ~= nil end
function M.RankOf(player)
	if not player then return nil end
	local role = player:GetAttribute("ChatRole")
	if role == "OWNER" or role == "MOD" then return role end
	if player:GetAttribute("VIP") == true then return "VIP" end
	return nil
end
function M.Owns(player, id)
	if id == "Standard" then return true end
	if TrailColors.ById[id or ""] then return player ~= nil and player:GetAttribute("OwnHair_" .. id) == true end
	local r = M.RankOf(player)
	if r == "OWNER" then return VALID[id] == true end
	if r == "MOD" then return id == "MOD" or id == "VIP" end
	if r == "VIP" then return id == "VIP" end
	return false
end
function M.Best(player) return M.RankOf(player) or "Standard" end
local function pick(player, attr, valid)
	local v = player and player:GetAttribute(attr)
	if v and valid(v) and M.Owns(player, v) then return v end
	return M.Best(player)
end
function M.Visor(player) return pick(player, "VisorStyle", M.Valid) end
function M.Trail(player) return pick(player, "TrailStyle", M.ValidTrail) end
function M.LockText(id) return tostring(id) .. " ONLY" end
function M.Name(list, id)
	for _, x in ipairs(list) do if x.Id == id then return x.Name end end
	local tc = TrailColors.ById[id or ""]
	if tc then return tc.Name end
	return "Standard"
end
return M

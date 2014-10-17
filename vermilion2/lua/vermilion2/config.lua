--[[
 Copyright 2014 Ned Hyett

 Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
 in compliance with the License. You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under the License
 is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
 or implied. See the License for the specific language governing permissions and limitations under
 the License.
 
 The right to upload this project to the Steam Workshop (which is operated by Valve Corporation) 
 is reserved by the original copyright holder, regardless of any modifications made to the code,
 resources or related content. The original copyright holder is not affiliated with Valve Corporation
 in any way, nor claims to be so. 
]]


Vermilion.AllPermissions = {}

Vermilion.Data = {}

Vermilion.Data.Global = {}
Vermilion.Data.Module = {}
Vermilion.Data.Ranks = {} -- temp
Vermilion.Data.Users = {}
Vermilion.Data.Bans = {}





--[[

	//		Networking		\\

]]--

util.AddNetworkString("Vermilion_SendRank")
util.AddNetworkString("VBroadcastRankData")
util.AddNetworkString("VBroadcastPermissions")
util.AddNetworkString("VUpdatePlayerLists")





--[[

	//		Ranks		\\
	
]]--

function Vermilion:GetDefaultRank()
	return self:GetData("default_rank", "player")
end

function Vermilion:AddRank(name, permissions, protected, colour, icon)
	local obj = self:CreateRankObj(name, permissions, protected, colour, icon)
	table.insert(self.Data.Ranks, obj)
	Vermilion:BroadcastRankData(VToolkit.GetValidPlayers())
end

function Vermilion:CreateRankObj(name, permissions, protected, colour, icon)
	local rnk = {}
	
	rnk.Name = name
	rnk.Permissions = permissions or {}
	rnk.Protected = protected or false
	if(colour == nil) then rnk.Colour = { 255, 255, 255 } else
		rnk.Colour = { colour.r, colour.g, colour.b }
	end
	rnk.Icon = icon
	
	rnk.Metadata = {}
	
	self:AttachRankFunctions(rnk)
	
	return rnk
end

function Vermilion:AttachRankFunctions(rankObj)
	
	if(Vermilion.RankMetaTable == nil) then
		local meta = {}
		function meta:GetName()
			return self.Name
		end
		
		function meta:IsImmuneToRank(rank)
			return self:GetImmunity() < rank:GetImmunity()
		end
		
		function meta:GetImmunity()
			return table.KeyFromValue(Vermilion.Data.Ranks, self)
		end
		
		function meta:MoveUp()
			if(self:GetImmunity() <= 2) then
				Vermilion.Log("Cannot move rank up. Would interfere with owner rank.")
				return false
			end
			if(self.Protected) then
				Vermilion.Log("Cannot move protected rank!")
				return false
			end
			local immunity = self:GetImmunity()
			table.insert(Vermilion.Data.Ranks, immunity - 1, self)
			table.remove(Vermilion.Data.Ranks, immunity + 1)
			Vermilion:BroadcastRankData(VToolkit.GetValidPlayers())
			return true
		end
		
		function meta:MoveDown()
			if(self:GetImmunity() == table.Count(Vermilion.Data.Ranks)) then
				Vermilion.Log("Cannot move rank; already at bottom!")
				return false
			end
			if(self.Protected) then
				Vermilion.Log("Cannot move protected rank!")
				return false
			end
			local immunity = self:GetImmunity()
			table.insert(Vermilion.Data.Ranks, immunity + 2, self)
			table.remove(Vermilion.Data.Ranks, immunity)
			Vermilion:BroadcastRankData(VToolkit.GetValidPlayers())
			return true
		end
		
		function meta:GetUsers()
			local users = {}
			for i,k in pairs(Vermilion.Data.Users) do
				if(k:GetRankName() == self.Name) then
					table.insert(users, k)
				end
			end
			return users
		end
		
		function meta:Rename(newName)
			if(self.Protected) then
				Vermilion.Log("Cannot rename protected rank!")
				return false
			end
			for i,k in pairs(self:GetUsers()) do
				k:SetRank(newName)
			end
			Vermilion.Log("Renamed rank " .. self.Name .. " to " .. newName)
			self.Name = newName
			Vermilion:BroadcastRankData()
			return true
		end
		
		function meta:Delete()
			if(self.Protected) then
				Vermilion.Log("Cannot delete protected rank!")
				return false
			end
			for i,k in pairs(self:GetUsers()) do
				k:SetRank(Vermilion:GetDefaultRank())
			end
			table.RemoveByValue(Vermilion.Data.Ranks, self)
			Vermilion:BroadcastRankData()
			Vermilion.Log("Removed rank " .. self.Name)
			return true
		end
		
		function meta:AddPermission(permission)
			if(self.Protected) then return end
			if(not istable(permission)) then permission = { permission } end
			for i,perm in pairs(permission) do
				if(not self:HasPermission(perm)) then
					local has = false
					for i,k in pairs(Vermilion.AllPermissions) do
						if(k.Permission == perm) then has = true break end
					end
					if(has) then
						table.insert(self.Permissions, perm)
					end
				end
			end
			for i,k in pairs(self:GetUsers()) do
				Vermilion:SyncClientRank(k)
			end
		end
		
		function meta:RevokePermission(permission)
			if(self.Protected) then return end
			if(not istable(permission)) then permission = { permission } end
			for i,perm in pairs(permission) do
				if(self:HasPermission(perm)) then
					local has = false
					for i,k in pairs(Vermilion.AllPermissions) do
						if(k.Permission == perm) then has = true break end
					end
					if(has) then
						table.RemoveByValue(self.Permissions, perm)
					end
				end
			end
			for i,k in pairs(self:GetUsers()) do
				Vermilion:SyncClientRank(k)
			end
		end
		
		function meta:HasPermission(permission)
			if(permission != "*") then
				local has = false
				for i,k in pairs(Vermilion.AllPermissions) do
					if(k.Permission == permission) then has = true break end
				end
				if(not has) then
					Vermilion.Log("Looking for unknown permission (" .. permission .. ")!")
				end
			end
			return table.HasValue(self.Permissions, permission) or table.HasValue(self.Permissions, "*")
		end
		
		function meta:SetColour(colour)
			if(IsColor(colour)) then
				self.Colour = { colour.r, colour.g, colour.b }
				Vermilion:BroadcastRankData()
			elseif(istable(colour)) then
				self.Colour = colour
				Vermilion:BroadcastRankData()
			else
				Vermilion.Log("Warning: cannot set colour. Invalid type " .. type(colour) .. "!")
			end
		end
		
		function meta:GetColour()
			return Color(self.Colour[1], self.Colour[2], self.Colour[3])
		end
		
		function meta:GetIcon()
			return self.Icon
		end
		
		function meta:SetIcon(icon)
			self.Icon = icon
			Vermilion:BroadcastRankData(VToolkit.GetValidPlayers())
		end
		Vermilion.RankMetaTable = meta
	end
	setmetatable(rankObj, { __index = Vermilion.RankMetaTable }) // <-- The metatable creates phantom functions.
end

function Vermilion:SyncClientRank(client)
	local userData = self:GetUser(client)
	if(userData != nil) then
		local rankData = userData:GetRank()
		if(rankData != nil) then
			net.Start("Vermilion_SendRank")
			net.WriteTable(VToolkit.NetSanitiseTable(rankData))
			net.Send(client)
		end
	end
end

function Vermilion:BroadcastRankData(target)
	target = target or VToolkit:GetValidPlayers()
	local normalData = {}
	for i,k in pairs(self.Data.Ranks) do
		table.insert(normalData, { Name = k.Name, Colour = k:GetColour(), IsDefault = k.Name == Vermilion:GetDefaultRank(), Protected = k.Protected, Icon = k.Icon })
	end
	net.Start("VBroadcastRankData")
	net.WriteTable(normalData)
	net.Send(target)
end

function Vermilion:GetRank(name)
	for i,k in pairs(self.Data.Ranks) do
		if(k.Name == name) then return k end
	end
end

function Vermilion:HasRank(name)
	return self:GetRank(name) != nil
end





--[[
	
	//		Users		\\
	
]]--

function Vermilion:CreateUserObj(name, steamid, rank, permissions)
	local usr = {}
	
	usr.Name = name
	usr.SteamID = steamid
	usr.Rank = rank
	usr.Permissions = permissions
	
	usr.Metadata = {}
	
	self:AttachUserFunctions(usr)
	
	return usr
end

function Vermilion:AttachUserFunctions(usrObject)
	if(Vermilion.PlayerMetaTable == nil) then
		local meta = {}
		function meta:GetRank()
			return Vermilion:GetRank(self.Rank)
		end
		
		function meta:GetRankName()
			return self.Rank
		end
		
		function meta:GetEntity()
			for i,k in pairs(VToolkit.GetValidPlayers()) do
				if(k:SteamID() == self.SteamID) then return k end
			end
		end
		
		function meta:SetRank(rank)
			if(Vermilion:HasRank(rank)) then
				self.Rank = rank
				local ply = VToolkit.LookupPlayerBySteamID(self.SteamID)
				if(IsValid(ply)) then
					-- Notify the player here
				end
				-- Notify the client of the change
				local ent = self:GetEntity()
				if(IsValid(ent)) then 
					ent:SetNWString("Vermilion_Rank", self.Rank)
					Vermilion:SyncClientRank(ent)
				end
			end
		end
		
		function meta:HasPermission(permission)
			if(permission != "*") then
				local has = false
				for i,k in pairs(Vermilion.AllPermissions) do
					if(k.Permission == permission) then has = true break end
				end
				if(not has) then
					Vermilion.Log("Looking for unknown permission (" .. permission .. ")!")
				end
			end
			if(table.HasValue(self.Permissions, permission) or table.HasValue(self.Permissions, "*")) then return true end
			return self:GetRank():HasPermission(permission)
		end
		
		function meta:GetColour()
			return self:GetRank():GetColour()
		end
		Vermilion.PlayerMetaTable = meta
	end
	
	setmetatable(usrObject, { __index = Vermilion.PlayerMetaTable }) // <-- The metatable creates phantom functions.
end

function Vermilion:StoreNewUserdata(vplayer)
	if(IsValid(vplayer)) then
		local usr = self:CreateUserObj(vplayer:GetName(), vplayer:SteamID(), self:GetDefaultRank(), {})
		table.insert(self.Data.Users, usr)
	end
end

function Vermilion:GetUser(vplayer)
	return Vermilion:GetUserBySteamID(vplayer:SteamID())
end

function Vermilion:GetUserByName(name)
	for index,userData in pairs(self.Data.Users) do
		if(userData.Name == name) then return userData end
	end
end

function Vermilion:GetUserBySteamID(steamid)
	for index,userData in pairs(self.Data.Users) do
		if(userData.SteamID == steamid) then return userData end
	end
end

function Vermilion:HasUser(vplayer)
	return Vermilion:GetUser(vplayer) != nil
end

function Vermilion:HasPermission(vplayer, permission)
	if(permission != "*") then
		local has = false
		for i,k in pairs(self.AllPermissions) do
			if(k.Permission == permission) then has = true break end
		end
		if(not has) then
			Vermilion.Log("Looking for unknown permission (" .. permission .. ")!")
		end
	end
	if(not IsValid(vplayer)) then
		Vermilion.Log("Invalid user during permissions check; assuming console.")
		return true
	end
	local usr = self:GetUser(vplayer)
	if(usr != nil) then
		return usr:HasPermission(permission)
	end
end





--[[

	//		Data Storage		\\

]]--

function Vermilion:GetData(name, default)
	if(self.Data.Global[name] == nil) then return default end
	return self.Data.Global[name]
end

function Vermilion:SetData(name, value)
	self.Data.Global[name] = value
end

function Vermilion:GetModuleData(mod, name, def)
	if(self.Data.Module[mod] == nil) then self.Data.Module[mod] = {} end
	if(self.Data.Module[mod][name] == nil) then return def end
	return self.Data.Module[mod][name]
end

function Vermilion:SetModuleData(mod, name, val)
	if(self.Data.Module[mod] == nil) then self.Data.Module[mod] = {} end
	self.Data.Module[mod][name] = val
	self:TriggerDataChangeHooks(mod, name)
end

function Vermilion:TriggerDataChangeHooks(mod, name)
	local modStruct = Vermilion:GetModule(mod)
	if(modStruct != nil) then
		if(modStruct.DataChangeHooks != nil) then
			if(modStruct.DataChangeHooks[name] != nil) then
				for index,DCHook in pairs(modStruct.DataChangeHooks[name]) do
					DCHook(self.Data.Module[mod][name])
				end
			end
		end
	end
end

function Vermilion:NetworkModuleConfig(vplayer, mod)
	if(self.Data.Module[mod] != nil) then
		
	end
end





--[[

	//		Loading/saving		\\

]]--

function Vermilion:LoadConfiguration()
	if(not file.Exists(self.GetFileName("settings"), "DATA")) then
		Vermilion.Data.Ranks = {
			Vermilion:CreateRankObj("owner", { "*" }, true, Color(255, 0, 0), "key"),
			Vermilion:CreateRankObj("admin", nil, false, Color(0, 255, 0), "shield"),
			Vermilion:CreateRankObj("player", nil, false, Color(0, 0, 255), "user"),
			Vermilion:CreateRankObj("guest", nil, false, Color(0, 0, 0), "user_orange")
		}
	else
		local data = util.JSONToTable(util.Decompress(file.Read(self.GetFileName("settings"), "DATA")))
		for i,rank in pairs(data.Ranks) do
			self:AttachRankFunctions(rank)
		end
		for i,usr in pairs(data.Users) do
			self:AttachUserFunctions(usr)
		end
		Vermilion.Data = data
		self.Log("Loaded data...")
	end
end

Vermilion:LoadConfiguration()

function Vermilion:SaveConfiguration(verbose)
	if(verbose == nil) then verbose = true end
	if(verbose) then Vermilion.Log("Saving Data...") end
	local safeTable = VToolkit.NetSanitiseTable(Vermilion.Data)
	file.Write(self.GetFileName("settings"), util.Compress(util.TableToJSON(safeTable)))
end

Vermilion:AddHook("ShutDown", "SaveConfiguration", true, function()
	Vermilion:SaveConfiguration()
end)

timer.Create("Vermilion:SaveConfiguration", 2, 0, function()
	Vermilion:SaveConfiguration(false)
end)






--[[
	
	//		Player Registration		\\
	
]]--

Vermilion:AddHook("PlayerInitialSpawn", "RegisterPlayer", true, function(vplayer)
	if(not Vermilion:HasUser(vplayer)) then
		Vermilion:StoreNewUserdata(vplayer)
	end
	if(table.Count(Vermilion:GetRank("owner"):GetUsers()) == 0 and (game.SinglePlayer() or vplayer:IsListenServerHost())) then
		Vermilion:GetUser(vplayer):SetRank("owner")
	end
	vplayer:SetNWString("Vermilion_Rank", Vermilion:GetUser(vplayer):GetRankName())
	Vermilion:SyncClientRank(vplayer)
	Vermilion:BroadcastRankData(vplayer)
	net.Start("VBroadcastPermissions")
	net.WriteTable(Vermilion.AllPermissions)
	net.Send(vplayer)
	
	net.Start("VUpdatePlayerLists")
	local tab = {}
	for i,k in pairs(VToolkit.GetValidPlayers()) do
		table.insert(tab, { Name = k:GetName(), Rank = Vermilion:GetUser(k):GetRankName(), EntityID = k:EntIndex() })
	end
	net.WriteTable(tab)
	net.Broadcast()
end)





--[[

	//		Gui Updating	\\

]]--
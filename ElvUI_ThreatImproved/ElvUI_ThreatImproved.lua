local E, L, V, P, G = unpack(ElvUI); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local AddOnName, Engine = ...
local EP = LibStub("LibElvUIPlugin-1.0")

local THREAT = E:GetModule("Threat")
local DT = E:GetModule("DataTexts")
local NP = E:GetModule("NamePlates")
local pairs, select = pairs, select
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit -- https://github.com/FrostAtom/awesome_wotlk
local GetNumPartyMembers, GetNumRaidMembers = GetNumPartyMembers, GetNumRaidMembers
local HasPetUI = HasPetUI
local UnitName = UnitName
local UnitExists = UnitExists
local UnitCanAttack = UnitCanAttack
local GetUnitRole = Engine.Compat.GetUnitRole
-- UnitDetailedThreatSituation:
-- 1: boolean - isTanking
-- 2: integer - status (0: not tanking, low threat; 1: not tanking, more threat than tank; 2: tanking, not highest threat; 3: tanking, highest threat)
-- 3: number - threatpct
-- 4: number - rawthreatpct (if isTanking, 255 [-1?])
-- 5: number - threatvalue
local UnitDetailedThreatSituation = UnitDetailedThreatSituation

local partyUnits, raidUnits = {}, {}
for i = 1, 4 do partyUnits[i] = "party"..i end
for i = 1, 40 do raidUnits[i] = "raid"..i end

local THREAT_SITUATIONS_TABLE = Engine.THREAT_SITUATIONS_TABLE
local THREAT_SITUATIONS = Engine.THREAT_SITUATIONS

P["ThreatImproved"] = {
	SAFE_PCT = 						70,
	NOTANK_LOW = 					{ color = { r = .29, g = .69, b = .30 }, scale = 1.0 },	-- Green
	NOTANK_HIGH = 					{ color = { r = .86, g = .77, b = .36 }, scale = 1.0 },	-- Yellow
	NOTANK_OVER = 					{ color = { r = .92, g = .50, b = .16 }, scale = 1.0 },	-- Orange
	NOTANK_TANKING = 				{ color = { r = .78, g = .25, b = .25 }, scale = 1.0 },	-- Red
	TANK_LOW_TANK_TANKING = 		{ color = { r = .25, g = .25, b = .92 }, scale = 1.0 },	-- Indigo
	TANK_LOW_NOTANK_TANKING = 		{ color = { r = .78, g = .25, b = .25 }, scale = 1.0 },	-- Red
	TANK_HIGH_TANK_TANKING = 		{ color = { r = .12, g = .50, b = .92 }, scale = 1.0 },	-- Clear blue
	TANK_HIGH_NOTANK_TANKING = 		{ color = { r = .92, g = .50, b = .16 }, scale = 1.0 },	-- Orange
	TANK_LOWTANKING_2ND_TANK = 		{ color = { r = .12, g = .92, b = .64 }, scale = 1.0 },	-- Aquamarine
	TANK_LOWTANKING_2ND_NOTANK = 	{ color = { r = .86, g = .77, b = .36 }, scale = 1.0 },	-- Yellow
	TANK_HIGHTANKING = 				{ color = { r = .29, g = .69, b = .30 }, scale = 1.0 },	-- Green
}

local NPThreatDetails = {}

local GetHighestThreatExceptMe = function(unitID)
	local largestThreat = 0
	local largestUnit = nil
	local largestThreatDetails = nil
	if HasPetUI() then
		local petThreat = { UnitDetailedThreatSituation("pet", unitID) }
		if petThreat and petThreat[3] ~= nil and petThreat[3] > largestThreat then
			largestThreat = petThreat[3]
			largestThreatDetails = petThreat
			largestUnit = "pet"
		end
	end
	if GetNumRaidMembers() > 0 then
		for i = 1, 40 do
			if UnitExists(raidUnits[i]) and not UnitIsUnit(raidUnits[i], "player") then
				local threat = { UnitDetailedThreatSituation(raidUnits[i], unitID) }
				if threat and threat[3] ~= nil and threat[3] > largestThreat then
					largestThreat = threat[3]
					largestThreatDetails = threat
					largestUnit = raidUnits[i]
				end
			end
		end
	elseif GetNumPartyMembers() > 0 then
		for i = 1, 4 do
			if UnitExists(partyUnits[i]) then
				local threat = { UnitDetailedThreatSituation(partyUnits[i], unitID) }
				if threat and threat[3] ~= nil and threat[3] > largestThreat then
					largestThreat = threat[3]
					largestThreatDetails = threat
					largestUnit = partyUnits[i]
				end
			end
		end
	end
	return largestUnit, largestThreatDetails
end

local GetHighestThreatShouldBeTank = function(unitID)
	-- Check if the target's target is tanking
	local targetthreat = { UnitDetailedThreatSituation(unitID .. "-target", unitID) }
	if targetthreat[1] then
		return unitID .. "-target", targetthreat
	end
	-- The target's target is not tanking... maybe the unit targetted somebody else
	return GetHighestThreatExceptMe(unitID)
end

local safePct = E.db.ThreatImproved and E.db.ThreatImproved.SAFE_PCT or P.ThreatImproved.SAFE_PCT

local function GetThreatDetails(unitID)
	local myThreatTanking, myThreatStatus, myThreatPct = UnitDetailedThreatSituation("player", unitID)

	if not myThreatPct then
		myThreatTanking = nil
		myThreatStatus = 0
		myThreatPct = 0
	end

	local threatSituation = nil
	local otherUnit = nil
	local otehrThreatDetails = nil
	local otherThreatPct = nil

	local myRole = GetUnitRole("player")
	if myRole ~= "TANK" then
		-- My role is not a tank.
		if myThreatStatus == 0 and myThreatPct <= safePct then
			-- Low on threat
			threatSituation = THREAT_SITUATIONS.NOTANK_LOW
		elseif myThreatStatus == 0 and myThreatPct > safePct then
			-- High on threat
			threatSituation = THREAT_SITUATIONS.NOTANK_HIGH
		elseif myThreatStatus == 1 then
			-- Overaggroing
			threatSituation = THREAT_SITUATIONS.NOTANK_OVER
		else -- myThreatStatus == 2 or myThreatStatus == 3
			-- Tanking
			threatSituation = THREAT_SITUATIONS.NOTANK_TANKING
		end
	else
		-- My role is a tank.
		if myThreatStatus == 0 and myThreatPct <= safePct then
			-- Low on threat
			-- Get the unit that has the highest threat (tanking)
			otherUnit, _ = GetHighestThreatShouldBeTank(unitID)
			if not otherUnit then
				return
			end
			if GetUnitRole(otherUnit) == "TANK" then
				-- Another tank is tanking
				threatSituation = THREAT_SITUATIONS.TANK_LOW_TANK_TANKING
			else
				-- Another non-tank is tanking
				threatSituation = THREAT_SITUATIONS.TANK_LOW_NOTANK_TANKING
			end
		elseif (myThreatStatus == 0 and myThreatPct > safePct) or myThreatStatus == 1 then
			-- High on threat / overaggroing
			-- Get the unit that has the highest threat (tanking)
			otherUnit, _ = GetHighestThreatShouldBeTank(unitID)
			if GetUnitRole(otherUnit) == "TANK" then
				-- Another tank is tanking
				threatSituation = THREAT_SITUATIONS.TANK_HIGH_TANK_TANKING
			else
				-- Another non-tank is tanking
				threatSituation = THREAT_SITUATIONS.TANK_HIGH_NOTANK_TANKING
			end
		else
			-- Tanking
			-- Get the unit that has the 2nd highest threat (challenging)
			otherUnit, otherThreatDetails = GetHighestThreatExceptMe(unitID)
			if otherUnit then
				otherThreatPct = otherThreatDetails[3]
				if otherThreatPct > safePct then
					-- Tanking, low on threat
					if GetUnitRole(otherUnit) == "TANK" then
						-- 2nd on aggro: tank
						threatSituation = THREAT_SITUATIONS.TANK_LOWTANKING_2ND_TANK
					else
						-- 2nd on aggro: non-tank
						threatSituation = THREAT_SITUATIONS.TANK_LOWTANKING_2ND_NOTANK
					end
				else
					-- Tanking, high on threat
					threatSituation = THREAT_SITUATIONS.TANK_HIGHTANKING
				end
			else
				-- Tanking, alone
				threatSituation = THREAT_SITUATIONS.TANK_HIGHTANKING
			end
		end
	end
	return threatSituation, myThreatPct, otherUnit, otherThreatPct
end

local HOOK_THREAT_Update = function(self, arg1, arg2)
	-- Override ElvUI's THREAT Update
	if not UnitExists("target") or (DT and DT.ShowingBGStats) or not UnitCanAttack("player", "target") then
		if THREAT.bar:IsShown() then
			THREAT.bar:Hide()
		end

		return
	end

	if (GetNumPartyMembers() == 0 or petExists == 0) then
		THREAT.bar:Hide()
		return
	end

	local threatSituation, myThreatPct, otherUnit, otherThreatPct = GetThreatDetails("target")
	if not threatSituation then
		THREAT.bar:Hide()
		return
	end

	local name = UnitName("target")
	THREAT.bar:Show()

	local color = E.db.ThreatImproved[THREAT_SITUATIONS_TABLE[threatSituation]].color
	THREAT.bar:SetStatusBarColor(color.r, color.g, color.b)
	if otherUnit and otherThreatPct then
		local leadPercent = myThreatPct - otherThreatPct
		THREAT.bar:SetValue(leadPercent)
		local r, g, b = THREAT:GetColor(otherUnit)
		THREAT.bar.text:SetFormattedText(L["ABOVE_THREAT_FORMAT"], name, myThreatPct, leadPercent, r, g, b, UnitName(otherUnit) or UNKNOWN)
	else
		THREAT.bar:SetValue(myThreatPct)
		THREAT.bar.text:SetFormattedText("%s: %.0f%%", name, myThreatPct)
	end
end

local function UpdateNPThreat(unitID)
	local plateFrame = GetNamePlateForUnit(unitID)
	if not plateFrame then return end
	local elvuiPlate = plateFrame.UnitFrame
	if not elvuiPlate then -- Compatibility with VirtualPlates
		elvuiPlate = plateFrame:GetChildren().UnitFrame
	end
	if not elvuiPlate then return end -- elvuiPlate is nil, it is sometimes created a bit later
	local threatSituation, myThreatPct, otherUnit, otherThreatPct = GetThreatDetails(unitID)
	if not threatSituation then return end
	if elvuiPlate.ThreatStatus ~= threatSituation then
		elvuiPlate.ThreatStatus = threatSituation
		NP:Update_HealthColor(elvuiPlate)
	end
	if elvuiPlate.ThreatPct ~= myThreatPct then
		elvuiPlate.ThreatPct = myThreatPct
		-- do something with ThreatPct
	end
end

local HOOK_NP_UnitDetailedThreatSituation = function(self, frame)
	-- Override ElvUI's NP UnitDetailedThreatSituation
	return frame.ThreatStatus
end

local HOOK_NP_Update_HealthColor = function(self, frame)
	-- Mostly default ElvUI's NP Update_HealthColor
	if not frame.Health:IsShown() then return end

	local r, g, b
	local scale = 1

	local class = frame.UnitClass
	local classColor = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class] or RAID_CLASS_COLORS[class]
	local useClassColor = NP.db.units[frame.UnitType].health.useClassColor
	if classColor and ((frame.UnitType == "FRIENDLY_PLAYER" and useClassColor) or (frame.UnitType == "ENEMY_PLAYER" and useClassColor)) then
		r, g, b = classColor.r, classColor.g, classColor.b
	else
		-- BEGIN CUSTOM
		local db = NP.db.colors
		local status = frame.ThreatStatus
		if status then
			local color = E.db.ThreatImproved[THREAT_SITUATIONS_TABLE[status]].color
			scale = E.db.ThreatImproved[THREAT_SITUATIONS_TABLE[status]].scale
			r, g, b = color.r, color.g, color.b
		end
		-- END CUSTOM

		if (not status) or (status and not NP.db.threat.useThreatColor) then
			local reactionType = frame.UnitReaction
			if reactionType == 4 then
				r, g, b = db.reactions.neutral.r, db.reactions.neutral.g, db.reactions.neutral.b
			elseif reactionType and reactionType > 4 then
				if frame.UnitType == "FRIENDLY_PLAYER" then
					r, g, b = db.reactions.friendlyPlayer.r, db.reactions.friendlyPlayer.g, db.reactions.friendlyPlayer.b
				else
					r, g, b = db.reactions.good.r, db.reactions.good.g, db.reactions.good.b
				end
			else
				r, g, b = db.reactions.bad.r, db.reactions.bad.g, db.reactions.bad.b
			end
		end
	end

	if r ~= frame.Health.r or g ~= frame.Health.g or b ~= frame.Health.b then
		if not frame.HealthColorChanged then
			frame.Health:SetStatusBarColor(r, g, b)

			if frame.HealthColorChangeCallbacks then
				for _, cb in ipairs(frame.HealthColorChangeCallbacks) do
					cb(NP, frame, r, g, b)
				end
			end
		end
		frame.Health.r, frame.Health.g, frame.Health.b = r, g, b
	end

	if frame.ThreatScale ~= scale then
		frame.ThreatScale = scale
		if frame.isTarget and NP.db.useTargetScale then
			scale = scale * NP.db.targetScale
		end
		NP:SetFrameScale(frame, scale * (frame.ActionScale or 1))
	end
end

local ThreatImproved = E:NewModule("ThreatImproved", "AceEvent-3.0", "AceHook-3.0")
E:RegisterModule(ThreatImproved:GetName(), function()
	ThreatImproved:RegisterEvent("UNIT_THREAT_LIST_UPDATE", "Update")
	ThreatImproved:RegisterEvent("NAME_PLATE_UNIT_ADDED", "Update")
	ThreatImproved:RawHook(THREAT, "Update", HOOK_THREAT_Update)
	ThreatImproved:RawHook(NP, "UnitDetailedThreatSituation", HOOK_NP_UnitDetailedThreatSituation)
	ThreatImproved:RawHook(NP, "Update_HealthColor", HOOK_NP_Update_HealthColor)
end)

local lastUpdated = {}
function ThreatImproved:Update(event, arg1, ...)
	if event == "UNIT_THREAT_LIST_UPDATE" then
		if arg1 ~= nil then
			local last = lastUpdated[arg1] or 0
			if GetTime() - last >= 0.1 then
				lastUpdated[arg1] = GetTime()
				UpdateNPThreat(arg1)
			end
		end
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		if arg1 ~= nil then
			-- Delay needed since ElvUI plate (plate.UnitFrame) is created a few frames after this event 
			E:Delay(0.05, UpdateNPThreat, arg1)
		end
	end
end

-- Options
local function InsertOptions()
	local table = {
		type = "group",
		name = L["Name"],
		args = {
			description = {
				order = 0,
				type = "description",
				name = L["Description"],
			},
			safePct = {
				order = 1,
				type = "range",
				name = L["Safe Threat Percentage"],
				desc = L["Safe Threat Percentage Desc"],
				min = 0,
				max = 100,
				step = 1,
				get = function(info)
					return E.db.ThreatImproved.SAFE_PCT
				end,
				set = function(info, value)
					E.db.ThreatImproved.SAFE_PCT = value
					safePct = value
				end,
			}
		}
	}
	local n = 2
	for i,v in ipairs(Engine.THREAT_SITUATIONS_TABLE) do
		--[[table.args[v .. "_color"] = {
			order = n,
			type = "color",
			name = L["Name" .. v],
			desc = L["Description" .. v],
			width = 3.0,
			get = function(info)
				local t = E.db.ThreatImproved[v]
				local d = P.ThreatImproved[v]
				return t.color.r, t.color.g, t.color.b, 1.0, d.color.r, d.color.g, d.color.b, 1.0
			end,
			set = function(info, r, g, b)
				local t = E.db.ThreatImproved[v]
				t.color.r, t.color.g, t.color.b = r, g, b
			end,
		}
		n = n + 1
		table.args[v .. "_scale"] = {
			order = n,
			type = "range",
			name = L["Scale"],
			desc = L["Description" .. v],
			min = 0.3,
			max = 2.0,
			step = 0.1,
			get = function(info)
				local t = E.db.ThreatImproved[v]
				local d = P.ThreatImproved[v]
				return t.scale, d.scale
			end,
			set = function(info, value)
				local t = E.db.ThreatImproved[v]
				t.scale = value
			end,
		}
		n = n + 1]]--
		table.args[v] = {
			order = n,
			type = "group",
			name = L["Name" .. v],
			guiInline = true,
			desc = L["Description" .. v],
			args = {
				color = {
					order = 1,
					type = "color",
					name = "Color",
					desc = L["Description" .. v],
					get = function(info)
						local t = E.db.ThreatImproved[v]
						local d = P.ThreatImproved[v]
						return t.color.r, t.color.g, t.color.b, 1.0, d.color.r, d.color.g, d.color.b, 1.0
					end,
					set = function(info, r, g, b)
						local t = E.db.ThreatImproved[v]
						t.color.r, t.color.g, t.color.b = r, g, b
					end,
				},
				scale = {
					order = 2,
					type = "range",
					name = "Scale",
					desc = L["Description" .. v],
					min = 0.3,
					max = 2.0,
					step = 0.1,
					get = function(info)
						local t = E.db.ThreatImproved[v]
						local d = P.ThreatImproved[v]
						return t.scale, d.scale
					end,
					set = function(info, value)
						local t = E.db.ThreatImproved[v]
						t.scale = value
					end,
				}
			}
		}
		n = n + 1
	end
	E.Options.args.plugins.args.ThreatImproved = table
end

EP:RegisterPlugin(AddOnName, InsertOptions)
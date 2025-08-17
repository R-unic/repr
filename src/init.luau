--!strict
--!native
--!optimize 2
--- repr - Version 1.2
-- Ozzypig - ozzypig.com - http://twitter.com/Ozzypig
-- Check out this thread for more info:
-- https://devforum.roblox.com/t/repr-function-for-printing-tables/276575
--[[

local repr = require(3148021300)

local myTable = {
	hello = "world",
	score = 5,
	isCool = true
}
print(repr(myTable)) --> {hello = "world", isCool = true, score = 5}

]]

local len = buffer.len
local readu8 = buffer.readu8

local defaultSettings = {
	pretty = false,
	robloxFullName = false,
	robloxProperFullName = true,
	robloxClassName = true,
	tabs = false,
	semicolons = false,
	spaces = 3,
	sortKeys = true,
}

-- lua keywords
local keywords = {
	["and"] = true,
	["break"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["until"] = true,
	["while"] = true,
}

local function isLuaIdentifier(str: unknown): boolean
	if type(str) ~= "string" then
		return false
	end
	-- must be nonempty
	if str:len() == 0 then
		return false
	end
	-- can only contain a-z, A-Z, 0-9 and underscore
	if str:find("[^%d%a_]") then
		return false
	end
	-- cannot begin with digit
	if tonumber(str:sub(1, 1)) then
		return false
	end
	-- cannot be keyword
	if keywords[str] then
		return false
	end
	return true
end

-- works like Instance:GetFullName(), but invalid Lua identifiers are fixed (e.g. workspace["The Dude"].Humanoid)
local function properFullName(object: Instance?): string
	if object == nil or object == game :: Instance then
		return ""
	end

	local s = object.Name
	local usePeriod = true
	if not isLuaIdentifier(s) then
		s = ("[%q]"):format(s)
		usePeriod = false
	end

	if not object.Parent or object.Parent == game :: Instance then
		return s
	else
		return properFullName(object.Parent) .. (usePeriod and "." or "") .. s
	end
end

export type ReprOptions = {
	read spaces: number?,
	read tabs: boolean?,
	read pretty: boolean?,
	read semicolons: boolean?,
	read sortKeys: boolean?,
	read robloxFullName: boolean?,
	read robloxProperFullName: boolean?,
	read robloxClassName: boolean?,
}

local depth = 0
local shown: { [unknown]: boolean }
local INDENT: string
local function repr(value: unknown, reprSettings: ReprOptions): string
	reprSettings = reprSettings or defaultSettings
	INDENT = (" "):rep(reprSettings.spaces or defaultSettings.spaces)
	if reprSettings.tabs then
		INDENT = "\t"
	end

	local v = value --args[1]
	local tabs = INDENT:rep(depth)

	if depth == 0 then
		shown = {}
	end
	if type(v) == "string" then
		return ("%q"):format(v)
	elseif type(v) == "number" then
		if v == math.huge then
			return "math.huge"
		end
		if v == -math.huge then
			return "-math.huge"
		end
		return tostring(tonumber(v))
	elseif type(v) == "boolean" then
		return tostring(v)
	elseif type(v) == "nil" then
		return "nil"
	elseif type(v) == "table" and type(v.__tostring) == "function" then
		local valueToString = v.__tostring :: (unknown) -> string
		return tostring(valueToString(v))
	elseif
		type(v) == "table"
		and getmetatable(v) ~= nil
		and type((getmetatable(v) :: any).__tostring) == "function"
	then
		local valueToString = (getmetatable(v) :: any).__tostring :: (unknown) -> string
		return tostring(valueToString(v))
	elseif type(v) == "table" then
		if shown[v] then
			return "{CYCLIC}"
		end
		shown[v] = true
		local str = "{" .. (reprSettings.pretty and ("\n" .. INDENT .. tabs) or "")
		local isArray = true
		for k, v in pairs(v :: { [unknown]: unknown }) do
			if type(k) == "number" then
				continue
			end
			isArray = false
			break
		end
		if isArray then
			local arr = v :: { unknown }
			for i = 1, #arr do
				if i ~= 1 then
					str = str
						.. (reprSettings.semicolons and ";" or ",")
						.. (reprSettings.pretty and ("\n" .. INDENT .. tabs) or " ")
				end
				depth += 1
				str = str .. repr(arr[i], reprSettings)
				depth -= 1
			end
		else
			local map = v :: { [unknown]: unknown }
			local keyOrder = {}
			local keyValueStrings = {}
			for key, value in pairs(map) do
				depth += 1
				local kStr = isLuaIdentifier(key) and key or ("[" .. repr(key, reprSettings) .. "]")
				local vStr = repr(value, reprSettings)
				--[[str = str .. ("%s = %s"):format(
					isLuaIdentifier(k) and k or ("[" .. repr(k, reprSettings) .. "]"),
					repr(v, reprSettings)
				)]]
				table.insert(keyOrder, kStr)
				keyValueStrings[kStr] = vStr
				depth -= 1
			end
			if reprSettings.sortKeys then
				table.sort(keyOrder)
			end
			local first = true
			for _, kStr in pairs(keyOrder) do
				if not first then
					str = str
						.. (reprSettings.semicolons and ";" or ",")
						.. (reprSettings.pretty and ("\n" .. INDENT .. tabs) or " ")
				end
				str = str .. ("%s = %s"):format(kStr, keyValueStrings[kStr])
				first = false
			end
		end
		shown[v] = false
		if reprSettings.pretty then
			str = str .. "\n" .. tabs
		end
		str = str .. "}"
		return str
	elseif typeof then
		-- Check Roblox types
		local robloxV = v :: unknown
		if typeof(robloxV) == "Instance" then
			return (
				reprSettings.robloxFullName
					and (reprSettings.robloxProperFullName and properFullName(robloxV :: Instance) or robloxV:GetFullName())
				or robloxV.Name
			) .. (reprSettings.robloxClassName and ((" (%s)"):format(robloxV.ClassName)) or "")
		elseif typeof(robloxV) == "Axes" then
			local s = {}
			if robloxV.X then
				table.insert(s, repr(Enum.Axis.X, reprSettings))
			end
			if robloxV.Y then
				table.insert(s, repr(Enum.Axis.Y, reprSettings))
			end
			if robloxV.Z then
				table.insert(s, repr(Enum.Axis.Z, reprSettings))
			end
			return ("Axes.new(%s)"):format(table.concat(s, ", "))
		elseif typeof(robloxV) == "BrickColor" then
			return ("BrickColor.new(%q)"):format(robloxV.Name)
		elseif typeof(robloxV) == "CFrame" then
			return ("CFrame.new(%s)"):format(table.concat({ robloxV:GetComponents() }, ", "))
		elseif typeof(robloxV) == "Color3" then
			return ("Color3.new(%d, %d, %d)"):format(robloxV.R, robloxV.G, robloxV.B)
		elseif typeof(robloxV) == "ColorSequence" then
			if #robloxV.Keypoints > 2 then
				return ("ColorSequence.new(%s)"):format(repr(robloxV.Keypoints, reprSettings))
			else
				if robloxV.Keypoints[1].Value == robloxV.Keypoints[2].Value then
					return ("ColorSequence.new(%s)"):format(repr(robloxV.Keypoints[1].Value, reprSettings))
				else
					return ("ColorSequence.new(%s, %s)"):format(
						repr(robloxV.Keypoints[1].Value, reprSettings),
						repr(robloxV.Keypoints[2].Value, reprSettings)
					)
				end
			end
		elseif typeof(robloxV) == "ColorSequenceKeypoint" then
			return ("ColorSequenceKeypoint.new(%d, %s)"):format(robloxV.Time, repr(robloxV.Value, reprSettings))
		elseif typeof(robloxV) == "DockWidgetPluginGuiInfo" then
			return ("DockWidgetPluginGuiInfo.new(%s, %s, %s, %s, %s, %s)"):format(
				repr(robloxV.InitialEnabled, reprSettings),
				repr(robloxV.InitialEnabledShouldOverrideRestore, reprSettings),
				repr(robloxV.FloatingXSize, reprSettings),
				repr(robloxV.FloatingYSize, reprSettings),
				repr(robloxV.MinWidth, reprSettings),
				repr(robloxV.MinHeight, reprSettings)
			)
		elseif typeof(robloxV) == "Enums" then
			return "Enums"
		elseif typeof(robloxV) == "Enum" then
			return ("Enum.%s"):format(tostring(robloxV))
		elseif typeof(robloxV) == "EnumItem" then
			return ("Enum.%s.%s"):format(tostring(robloxV.EnumType), robloxV.Name)
		elseif typeof(robloxV) == "Faces" then
			local s: { string } = {}
			for _, enumItem in Enum.NormalId:GetEnumItems() do
				if not (robloxV :: any)[enumItem.Name] then
					continue
				end
				table.insert(s, repr(enumItem, reprSettings))
			end
			return ("Faces.new(%s)"):format(table.concat(s, ", "))
		elseif typeof(robloxV) == "NumberRange" then
			if robloxV.Min == robloxV.Max then
				return ("NumberRange.new(%d)"):format(robloxV.Min)
			else
				return ("NumberRange.new(%d, %d)"):format(robloxV.Min, robloxV.Max)
			end
		elseif typeof(robloxV) == "NumberSequence" then
			if #robloxV.Keypoints > 2 then
				return ("NumberSequence.new(%s)"):format(repr(robloxV.Keypoints, reprSettings))
			else
				if robloxV.Keypoints[1].Value == robloxV.Keypoints[2].Value then
					return ("NumberSequence.new(%d)"):format(robloxV.Keypoints[1].Value)
				else
					return ("NumberSequence.new(%d, %d)"):format(robloxV.Keypoints[1].Value, robloxV.Keypoints[2].Value)
				end
			end
		elseif typeof(robloxV) == "NumberSequenceKeypoint" then
			if robloxV.Envelope ~= 0 then
				return ("NumberSequenceKeypoint.new(%d, %d, %d)"):format(robloxV.Time, robloxV.Value, robloxV.Envelope)
			else
				return ("NumberSequenceKeypoint.new(%d, %d)"):format(robloxV.Time, robloxV.Value)
			end
		elseif typeof(robloxV) == "PathWaypoint" then
			return ("PathWaypoint.new(%s, %s)"):format(
				repr(robloxV.Position, reprSettings),
				repr(robloxV.Action, reprSettings)
			)
		elseif typeof(robloxV) == "PhysicalProperties" then
			return ("PhysicalProperties.new(%d, %d, %d, %d, %d)"):format(
				robloxV.Density,
				robloxV.Friction,
				robloxV.Elasticity,
				robloxV.FrictionWeight,
				robloxV.ElasticityWeight
			)
		elseif typeof(robloxV) == "Random" then
			return "<Random>"
		elseif typeof(robloxV) == "Ray" then
			return ("Ray.new(%s, %s)"):format(repr(robloxV.Origin, reprSettings), repr(robloxV.Direction, reprSettings))
		elseif typeof(robloxV) == "RBXScriptConnection" then
			return "<RBXScriptConnection>"
		elseif typeof(robloxV) == "RBXScriptSignal" then
			return "<RBXScriptSignal>"
		elseif typeof(robloxV) == "Rect" then
			return ("Rect.new(%d, %d, %d, %d)"):format(robloxV.Min.X, robloxV.Min.Y, robloxV.Max.X, robloxV.Max.Y)
		elseif typeof(robloxV) == "Region3" then
			local min = robloxV.CFrame.Position + robloxV.Size * -0.5
			local max = robloxV.CFrame.Position + robloxV.Size * 0.5
			return ("Region3.new(%s, %s)"):format(repr(min, reprSettings), repr(max, reprSettings))
		elseif typeof(robloxV) == "Region3int16" then
			return ("Region3int16.new(%s, %s)"):format(repr(robloxV.Min, reprSettings), repr(robloxV.Max, reprSettings))
		elseif typeof(robloxV) == "TweenInfo" then
			return ("TweenInfo.new(%d, %s, %s, %d, %s, %d)"):format(
				robloxV.Time,
				repr(robloxV.EasingStyle, reprSettings),
				repr(robloxV.EasingDirection, reprSettings),
				robloxV.RepeatCount,
				repr(robloxV.Reverses, reprSettings),
				robloxV.DelayTime
			)
		elseif typeof(robloxV) == "UDim" then
			return ("UDim.new(%d, %d)"):format(robloxV.Scale, robloxV.Offset)
		elseif typeof(robloxV) == "UDim2" then
			return ("UDim2.new(%d, %d, %d, %d)"):format(
				robloxV.X.Scale,
				robloxV.X.Offset,
				robloxV.Y.Scale,
				robloxV.Y.Offset
			)
		elseif typeof(robloxV) == "Vector2" then
			return ("Vector2.new(%d, %d)"):format(robloxV.X, robloxV.Y)
		elseif typeof(robloxV) == "Vector2int16" then
			return ("Vector2int16.new(%d, %d)"):format(robloxV.X, robloxV.Y)
		elseif typeof(robloxV) == "Vector3" then
			return ("Vector3.new(%d, %d, %d)"):format(robloxV.X, robloxV.Y, robloxV.Z)
		elseif typeof(robloxV) == "Vector3int16" then
			return ("Vector3int16.new(%d, %d, %d)"):format(robloxV.X, robloxV.Y, robloxV.Z)
		elseif typeof(robloxV) == "DateTime" then
			return ("DateTime.fromIsoDate(%q)"):format((robloxV :: DateTime):toIsoDate())
		elseif typeof(robloxV) == "buffer" then
			local buf = robloxV
			local parts: { string } = { "buffer { " }
			local lastOffset = len(buf) - 1
			for offset = 0, lastOffset do
				table.insert(parts, tostring(readu8(buf, offset)))
				table.insert(parts, if offset == lastOffset then " " else ", ")
			end
			table.insert(parts, "}")

			return table.concat(parts)
		else
			return "<Roblox:" .. typeof(robloxV) .. ">"
		end
	else
		return "<" .. type(v) .. ">"
	end
end

return repr

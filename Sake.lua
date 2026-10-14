do
	if getgenv then
		local previous = getgenv().SakeRuntime
		if previous and type(previous.Unload) == "function" then
			pcall(previous.Unload)
		end
	end
end

local pl = game:GetService("Players")
local rs = game:GetService("RunService")
local cg = game:GetService("CoreGui")
local lt = game:GetService("Lighting")
local ts = game:GetService("TweenService")
local rf = game:GetService("ReplicatedFirst")
local ui = game:GetService("UserInputService")
local ws = workspace
local cm = ws.CurrentCamera or ws:WaitForChild("Camera")
local lp = pl.LocalPlayer
local gup = (debug :: any).getupvalue or (rawget(getfenv(), "getupvalue") :: any)
local sup = (debug :: any).setupvalue or (rawget(getfenv(), "setupvalue") :: any)

local S = {
    HitboxEnabled = false,
    HitboxSize = 5,
    HitboxTrans = 0.8,
	HitNotifyEnabled = false,
    AimbotEnabled = false,
    AimbotHoldKey = Enum.UserInputType.MouseButton2,
    AimbotSmoothing = 0.5,
    AimbotTargetType = "Closest To Mouse",
    AimbotTargetHitbox = "Head",
    AimbotDistanceCheck = false,
    AimbotMaxDistance = 1500,
    SilentEnabled = false,
    SilentHitChance = 100,
    SilentMaxDistance = 2000,
    SilentTargetType = "Closest To Mouse",
    SilentTargetHitbox = "Head",   
    SilentVisibilityCheck = false,
	SilentPrediction = true,
	SilentPredictionStrength = 1,
	SilentNoSpread = true,
	BulletManipulation = false,
	WallbangEnabled = false,
    BulletManipRadius = 10,
    MaxForward = 3,
    MaxWalls = 2,
    WindowAware = true,
    ObstructionFallback = true,
    NoRecoilEnabled = false,
    RecoilScale = 0.1,  
    SnapLine = false,
    SnapLineColor = Color3.fromRGB(255,255,255),
    SnapLineThickness = 2,
    SnapLineOutline = false,
    SnapLineOutlineTransparency = 0.9,
    FOVEnabled = false,
    FOVColor = Color3.fromRGB(0,255,0),
    FOVRadius = 150,
    FOVThickness = 2,
    FOVFill = false,
    FOVDynamic = false,
    FOVOutline = false,
    lastSilentOrigin = nil,
    lastSilentDir = nil,
    walkingSpeed = 16,
    runningSpeed = 20,
    walkEnabled = false,
    runEnabled = false,
    isRunning = false,
    doubleJumpEnabled = false,
	AthleticGearEnabled = false,
	ClimbingGearEnabled = false,
	AimIgnoreFriends = false,
	AimIgnoreSquad = true,
	AimVisibleOnly = false,
	RandomEventAlerts = false,
    zCE = false,
    zCD = 10,
    zCS = 5,
    iFE = false,
    aSE = false,
    instantReloadEnabled = false,
    autoReloadEnabled = false,
	PerformanceMode = false,
    IncognitoEnabled = false,
    iIE = false,
    cPE = false,
    ab_en = false,
    ab_c = Color3.fromRGB(127, 127, 127),
    ob_c = Color3.fromRGB(127, 127, 127),
    o_c = false,
    o_d = false
}

S.Runtime = {
	Connections = setmetatable({}, { __mode = "k" }),
	Workers = {},
	Cleanups = {},
	Instances = setmetatable({}, { __mode = "k" }),
	Unloaded = false,
	UnloadRequested = false,
	Lighting = {
		FogStart = lt.FogStart,
		FogEnd = lt.FogEnd,
		FogColor = lt.FogColor,
		GlobalShadows = lt.GlobalShadows,
		Ambient = lt.Ambient,
		OutdoorAmbient = lt.OutdoorAmbient,
		ClockTime = lt.ClockTime,
		Technology = (function()
			local ok, value = pcall(function() return lt.Technology end)
			return ok and value or nil
		end)(),
	},
	Skies = {},
	Effects = {},
	ZombieStates = {},
	HitboxCharacters = setmetatable({}, { __mode = "k" }),
	PendingShots = {},
	PendingShotsByKey = {},
	HitNotificationQueue = {},
	EventAlertQueue = {},
	SquadMembers = {},
	FriendCache = {},
	VelocitySamples = setmetatable({}, { __mode = "k" }),
	ZombieCircleModels = {},
	ZombieCFrames = {},
	WalkSpeeds = {},
	SelfChams = {},
	IncognitoOriginals = setmetatable({}, { __mode = "k" }),
	IncognitoHumanoids = setmetatable({}, { __mode = "k" }),
	IncognitoConnections = {},
	AthleticGearHooks = setmetatable({}, { __mode = "k" }),
	ErrorTimes = {},
	MethodHooks = setmetatable({}, { __mode = "k" }),
	MethodHookKeys = {},
}

function S.Runtime.Connect(signal, callback)
	local connection = signal:Connect(callback)
	if S.Runtime.Unloaded then
		connection:Disconnect()
	else
		S.Runtime.Connections[connection] = true
	end
	return connection
end

function S.Runtime.Disconnect(connection)
	if not connection then return nil end
	S.Runtime.Connections[connection] = nil
	pcall(function() connection:Disconnect() end)
	return nil
end

function S.Runtime.SetWorker(key, signal, callback, enabled)
	local current = S.Runtime.Workers[key]
	if enabled then
		if not current or not current.Connected then
			if current then S.Runtime.Connections[current] = nil end
			S.Runtime.Workers[key] = S.Runtime.Connect(signal, callback)
		end
	elseif current then
		S.Runtime.Disconnect(current)
		S.Runtime.Workers[key] = nil
	end
end

function S.Runtime.AddCleanup(callback)
	if S.Runtime.Unloaded then
		pcall(callback)
	else
		table.insert(S.Runtime.Cleanups, callback)
	end
end

function S.Runtime.TrackInstance(instance)
	if instance then
		if S.Runtime.Unloaded then
			pcall(function() instance:Destroy() end)
		else
			S.Runtime.Instances[instance] = true
		end
	end
	return instance
end

function S.Runtime.ReportError(key, message)
	local now = os.clock()
	local last = S.Runtime.ErrorTimes[key]
	if last and now - last < 8 then return end
	S.Runtime.ErrorTimes[key] = now
	warn(("[Sake.lua] %s: %s"):format(key, tostring(message)))
end

function S.Runtime.DestroyTracked(instance)
	if not instance then return end
	S.Runtime.Instances[instance] = nil
	pcall(function() instance:Destroy() end)
end

function S.Runtime.Try(key, callback, ...)
	local result = table.pack(pcall(callback, ...))
	if not result[1] then
		S.Runtime.ReportError(key, result[2])
		return false
	end
	return true, table.unpack(result, 2, result.n)
end

function S.Runtime.WrapMethodHook(handler, nextMethod)
	return function(...)
		return handler(nextMethod, ...)
	end
end

function S.Runtime.RebuildMethodHook(record)
	local dispatch = record.Original
	for index = #record.Order, 1, -1 do
		local handler = record.Handlers[record.Order[index]]
		if handler then
			dispatch = S.Runtime.WrapMethodHook(handler, dispatch)
		end
	end
	record.Dispatch = dispatch
end

function S.Runtime.AddMethodHook(owner, methodName, key, handler)
	if type(owner) ~= "table" or type(owner[methodName]) ~= "function" or type(handler) ~= "function" then
		S.Runtime.ReportError("Hook." .. key, "invalid hook target")
		return false
	end
	if S.Runtime.MethodHookKeys[key] then return true end

	local methods = S.Runtime.MethodHooks[owner]
	if not methods then
		methods = {}
		S.Runtime.MethodHooks[owner] = methods
	end

	local record = methods[methodName]
	if not record then
		record = {
			Owner = owner,
			MethodName = methodName,
			Original = owner[methodName],
			Handlers = {},
			Order = {},
		}
		record.Dispatch = record.Original
		record.Wrapper = function(...)
			return record.Dispatch(...)
		end
		methods[methodName] = record
		if not S.Runtime.Try("Hook." .. key, function() owner[methodName] = record.Wrapper end)
			or owner[methodName] ~= record.Wrapper then
			methods[methodName] = nil
			return false
		end
	elseif owner[methodName] ~= record.Wrapper then
		S.Runtime.ReportError("Hook." .. key, methodName .. " was replaced by another script")
		return false
	end

	record.Handlers[key] = handler
	table.insert(record.Order, key)
	S.Runtime.MethodHookKeys[key] = record
	S.Runtime.RebuildMethodHook(record)
	return true
end

function S.Runtime.RestoreMethodHooks()
	for owner, methods in pairs(S.Runtime.MethodHooks) do
		for methodName, record in pairs(methods) do
			if owner[methodName] == record.Wrapper then
				S.Runtime.Try("Hook.Restore." .. methodName, function() owner[methodName] = record.Original end)
			end
		end
	end
	table.clear(S.Runtime.MethodHooks)
	table.clear(S.Runtime.MethodHookKeys)
end

S.Runtime.AddCleanup(S.Runtime.RestoreMethodHooks)

for _, child in ipairs(lt:GetChildren()) do
	if child:IsA("Sky") then
		local clone = child:Clone()
		clone.Parent = nil
		table.insert(S.Runtime.Skies, clone)
	elseif child:IsA("SunRaysEffect") or child:IsA("ColorCorrectionEffect") or child:IsA("BloomEffect") then
		S.Runtime.Effects[child] = {
			Enabled = child.Enabled,
			Saturation = child:IsA("ColorCorrectionEffect") and child.Saturation or nil,
			Contrast = child:IsA("ColorCorrectionEffect") and child.Contrast or nil,
			Brightness = child:IsA("ColorCorrectionEffect") and child.Brightness or nil,
			Intensity = child:IsA("BloomEffect") and child.Intensity or nil,
			Size = child:IsA("BloomEffect") and child.Size or nil,
			Threshold = child:IsA("BloomEffect") and child.Threshold or nil,
		}
	end
end

if lt:FindFirstChildOfClass("Atmosphere") then
	local atmosphere = lt:FindFirstChildOfClass("Atmosphere")
	S.Runtime.Atmosphere = {
		Instance = atmosphere,
		Density = atmosphere.Density,
		Haze = atmosphere.Haze,
		Glare = atmosphere.Glare,
		Offset = atmosphere.Offset,
		Color = atmosphere.Color,
		Decay = atmosphere.Decay,
	}
end

local ec = {
	Enabled = false, Box = false, Name = false, Distance = false, WeaponName = false,
	HPBar = false, HPText = false, Skeleton = false, FillBox = false, Tracer = false,
	Metric = "Studs", UseDisplayName = true, MaxDistance = 5000,
}
local eo = {
	BoxOuter = Color3.new(0, 0, 0), BoxMain = Color3.new(1, 1, 1), BoxInner = Color3.new(0, 0, 0),
	FillBox = Color3.new(1, 1, 1), FillBoxTransparency = 0.3, Name = Color3.new(1, 1, 1),
	Distance = Color3.new(1, 1, 1), WeaponName = Color3.new(1, 1, 1), HealthText = Color3.new(1, 1, 1),
	HealthGradientStart = Color3.new(1, 1, 1), HealthGradientMid = Color3.new(1, 1, 1), HealthGradientEnd = Color3.new(1, 1, 1),
	HealthMask = Color3.new(0, 0, 0), HealthMaskTransparency = 0.3, Skeleton = Color3.new(1, 1, 1),
	SkeletonTransparency = 0, Tracer = Color3.new(1, 1, 1)
}
local ea = {}
local en = { LootObservedRoot = nil, LootRootConnection = nil }
en.Players = {}

for _, player in ipairs(pl:GetPlayers()) do
	if player ~= lp then
		en.Players[player] = true
	end
end

local eg = Instance.new("ScreenGui")
eg.DisplayOrder = 9e9
eg.ResetOnSpawn = false
eg.Parent = gethui and gethui() or cg
eg.Enabled = false
S.Runtime.TrackInstance(eg)

local ch = {
	Enabled = false,
	FillColor = Color3.fromRGB(255, 255, 255), OutlineColor = Color3.fromRGB(255, 255, 255),
	FillTransparency = 10, OutlineTransparency = 10
}
local ch_c = {}

local h_s = Instance.new("Folder")
h_s.Name = "Highlight_Storage"
h_s.Parent = cg
S.Runtime.TrackInstance(h_s)

local cs = {
	enabled = false, showNames = false, showDistance = false, maxDistance = 10000,
	highlightColor = Color3.fromRGB(255, 0, 0), nameColor = Color3.fromRGB(255, 150, 0),
	distanceColor = Color3.fromRGB(255, 255, 255)
}

local vs = {
	enabled = false, showNames = false, showDistance = false, maxDistance = 10000,
	nameColor = Color3.fromRGB(0, 91, 255), distanceColor = Color3.fromRGB(255, 255, 255)
}
local ev = {}

local zs = {
	enabled = false, showNames = false, showDistance = false, maxDistance = 10000,
	details = false, showHealth = true, showType = true, bossesOnly = false,
	nameColor = Color3.fromRGB(135, 90, 90), distanceColor = Color3.fromRGB(255, 255, 255)
}
local ez = {}

local ls = {
	enabled = false, showNames = false, showDistance = false, maxDistance = 1000,
	filterType = "All", search = "",
	nameColor = Color3.fromRGB(255, 200, 50), distanceColor = Color3.fromRGB(200, 200, 200)
}
local el = {}

local tr_set = {
	Enabled = false, Color = Color3.fromRGB(255, 255, 255), Lifetime = 2, Thickness = 1, GlowIntensity = 0.4
}

local sc_set = { enabled = false, color = Color3.fromRGB(255, 255, 255), material = Enum.Material.ForceField }

local gc_set = { enabled = false, color = Color3.fromRGB(250, 250, 250), material = Enum.Material.Plastic }
local gc_orig = setmetatable({}, { __mode = "k" })

local cr_set = {
	enabled = false, color = Color3.fromRGB(255,255,255), thickness = 2, gap = 6, outline = false, spinning = false, spin_s = 120, centerDot = true, dot_s = 3, line_s = 12,
	lines = { top = {enabled = true, size = 12}, bottom = {enabled = true, size = 12}, left = {enabled = true, size = 12}, right = {enabled = true, size = 12} }
}

do
	local guiRoots = { (gethui and gethui()) or cg, lp:FindFirstChildOfClass("PlayerGui") }
	local visited = {}
	for _, guiRoot in ipairs(guiRoots) do
		if guiRoot and not visited[guiRoot] then
			visited[guiRoot] = true
			for _, candidate in ipairs(guiRoot:GetChildren()) do
			if candidate:IsA("ScreenGui") then
				local isSakeGui = candidate.Name == "Sake.lua.GUI"
				if not isSakeGui then
					local hasTitle = false
					local hasCategory = false
					for _, descendant in ipairs(candidate:GetDescendants()) do
						if descendant:IsA("TextLabel") then
							hasTitle = hasTitle or descendant.Text == "Sake.lua"
							hasCategory = hasCategory or descendant.Text == "Combat" or descendant.Text == "Cosmetics"
							if hasTitle and hasCategory then break end
						end
					end
					isSakeGui = hasTitle and hasCategory
				end
				if isSakeGui then
					local blurTag = candidate.Name
					candidate:Destroy()
					for _, container in ipairs({ lt, ws.CurrentCamera }) do
						if container then
							for _, item in ipairs(container:GetDescendants()) do
								if item:GetAttribute("NeverLoseBlur") == blurTag then item:Destroy() end
							end
						end
					end
				end
			end
			end
		end
	end
end

local LibraryUrl = "https://raw.githubusercontent.com/zzvsvv/skrypciory/refs/heads/main/x.lua"
local NL = loadstring(game:HttpGet(LibraryUrl .. "?cache=" .. tostring(os.time())))()
NL.UnloadEnabled = true
NL:SetAccentColor(Color3.fromRGB(242, 157, 198))
NL.ScreenGui.Name = "Sake.lua.GUI"
NL.ScreenGui.Parent = lp:WaitForChild("PlayerGui")
getgenv().SakeGui = NL.ScreenGui

local Notif = NL:CreateNotification()
local win = NL:CreateWindow({
	Name = "Sake.lua",
	Content = "AR2 | Version: 1.0",
	Size = NL.Scales.Default,
	ConfigFolder = "Sake.luaConfigs",
	ShowConfigHeader = false,
	Enable3DRenderer = false,
	Keybind = "End"
})

local WM = win:Watermark()
WM:SetName("Sake.lua")
WM:SetRender(true)

if WM.Root then
	WM.Root.Active = true
	NL:AddSignal(WM.Root.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			win:ToggleInterface()
		end
	end))
end

local cf_ = ws:WaitForChild("Corpses", 5)
local vh_ = ws:WaitForChild("Vehicles", 5)
local zo_ = ws:WaitForChild("Zombies", 5)
local mp_ = ws:FindFirstChild("Map") and (ws.Map:FindFirstChild("Elements") or ws.Map:WaitForChild("Elements", 5)) or nil
local cl = ws:FindFirstChildOfClass("Clouds") or (ws.Terrain and ws.Terrain:FindFirstChildOfClass("Clouds"))

if cl then
	S.Runtime.Clouds = {
		Instance = cl,
		Enabled = cl.Enabled,
		Color = cl.Color,
		Cover = cl.Cover,
		Density = cl.Density,
	}
end

local oIdx
local oNIdx
do
local INCOGNITO_NAME = "scriptzroblox.eu"

local function isIncognitoNameCharacter(character)
	return character ~= "" and character:match("[%w_]") ~= nil
end

local function replaceIncognitoName(text, name)
	if name == "" or name == INCOGNITO_NAME then return text end
	local cursor = 1
	while true do
		local first, last = text:find(name, cursor, true)
		if not first then break end
		local before = first > 1 and text:sub(first - 1, first - 1) or ""
		local after = last < #text and text:sub(last + 1, last + 1) or ""
		if not isIncognitoNameCharacter(before) and not isIncognitoNameCharacter(after) then
			text = text:sub(1, first - 1) .. INCOGNITO_NAME .. text:sub(last + 1)
			cursor = first + #INCOGNITO_NAME
		else
			cursor = last + 1
		end
	end
	return text
end

local function rebuildIncognitoNames()
	local names = {}
	local seen = {}
	for _, player in ipairs(pl:GetPlayers()) do
		local displayName = player.DisplayName
		if oIdx then
			pcall(function() displayName = oIdx(player, "DisplayName") end)
		end
		for _, name in ipairs({ player.Name, displayName }) do
			if type(name) == "string" and name ~= "" and name ~= INCOGNITO_NAME and not seen[name] then
				seen[name] = true
				table.insert(names, name)
			end
		end
	end
	table.sort(names, function(a, b) return #a > #b end)
	S.Runtime.IncognitoNames = names
end

local function spoofIncognitoText(text)
	if type(text) ~= "string" then return text end
	for _, name in ipairs(S.Runtime.IncognitoNames or {}) do
		text = replaceIncognitoName(text, name)
	end
	return text
end

local function isIncognitoTextObject(object)
	return typeof(object) == "Instance"
		and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox"))
end

local function applyIncognitoText(object)
	if not S.IncognitoEnabled or not isIncognitoTextObject(object) then return end
	pcall(function()
		local original = S.Runtime.IncognitoOriginals[object] or object.Text
		local spoofed = spoofIncognitoText(original)
		if spoofed ~= original then
			S.Runtime.IncognitoOriginals[object] = original
			object.Text = spoofed
		end
	end)
end

local function scanIncognitoRoot(root)
	if not root then return end
	pcall(function()
		applyIncognitoText(root)
		for _, object in ipairs(root:GetDescendants()) do applyIncognitoText(object) end
	end)
end

local function applyIncognitoCharacter(character)
	if not S.IncognitoEnabled or not character then return end
	task.spawn(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
		if not S.IncognitoEnabled or not humanoid then return end
		if S.Runtime.IncognitoHumanoids[humanoid] == nil then
			S.Runtime.IncognitoHumanoids[humanoid] = humanoid.DisplayName
		end
		humanoid.DisplayName = INCOGNITO_NAME
	end)
end

local function disconnectIncognitoConnections()
	for _, connection in ipairs(S.Runtime.IncognitoConnections) do
		pcall(function() connection:Disconnect() end)
	end
	table.clear(S.Runtime.IncognitoConnections)
	S.Runtime.IncognitoRoots = nil
end

local function setIncognitoMode(enabled)
	disconnectIncognitoConnections()

	if not enabled then
		S.IncognitoEnabled = false
		for object, original in pairs(S.Runtime.IncognitoOriginals) do
			pcall(function()
				if object.Parent then object.Text = original end
			end)
		end
		table.clear(S.Runtime.IncognitoOriginals)

		for humanoid, original in pairs(S.Runtime.IncognitoHumanoids) do
			pcall(function()
				if humanoid.Parent then humanoid.DisplayName = original end
			end)
		end
		table.clear(S.Runtime.IncognitoHumanoids)
		return
	end

	S.IncognitoEnabled = false
	rebuildIncognitoNames()
	S.IncognitoEnabled = true
	S.Runtime.IncognitoRoots = {}

	local function addConnection(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(S.Runtime.IncognitoConnections, connection)
		return connection
	end

	local function watchRoot(root)
		if not root or S.Runtime.IncognitoRoots[root] then return end
		S.Runtime.IncognitoRoots[root] = true
		scanIncognitoRoot(root)
		addConnection(root.DescendantAdded, function(object)
			task.defer(applyIncognitoText, object)
		end)
	end

	watchRoot(lp:FindFirstChildOfClass("PlayerGui"))
	watchRoot(cg)
	if gethui then pcall(function() watchRoot(gethui()) end) end

	local function watchPlayer(player)
		if player.Character then applyIncognitoCharacter(player.Character) end
		addConnection(player.CharacterAdded, applyIncognitoCharacter)
	end
	for _, player in ipairs(pl:GetPlayers()) do watchPlayer(player) end

	addConnection(pl.PlayerAdded, function(player)
		watchPlayer(player)
		task.defer(function()
			rebuildIncognitoNames()
			for root in pairs(S.Runtime.IncognitoRoots or {}) do scanIncognitoRoot(root) end
		end)
	end)
	addConnection(pl.PlayerRemoving, function()
		task.defer(rebuildIncognitoNames)
	end)
	addConnection(lp.ChildAdded, function(child)
		if child:IsA("PlayerGui") then watchRoot(child) end
	end)
end

S.Runtime.IncognitoName = INCOGNITO_NAME
S.Runtime.IsIncognitoTextObject = isIncognitoTextObject
S.Runtime.SpoofIncognitoText = spoofIncognitoText
S.Runtime.SetIncognitoMode = setIncognitoMode
end

local oHP = setmetatable({}, { __mode = "k" })
oIdx = hookmetamethod(game, "__index", function(self, k)
	if S.IncognitoEnabled and k == "DisplayName" and typeof(self) == "Instance" and self:IsA("Player") then
		return S.Runtime.IncognitoName
	end
    if not checkcaller() and k == "Size" and oHP[self] then
        return oHP[self].Size
    end
    return oIdx(self, k)
end)

oNIdx = hookmetamethod(game, "__newindex", function(self, k, v)
	if S.IncognitoEnabled and not checkcaller() and k == "Text" and type(v) == "string" and S.Runtime.IsIncognitoTextObject(self) then
		local spoofed = S.Runtime.SpoofIncognitoText(v)
		if spoofed ~= v then
			S.Runtime.IncognitoOriginals[self] = v
			v = spoofed
		else
			S.Runtime.IncognitoOriginals[self] = nil
		end
	end
    if not checkcaller() and k == "Size" and oHP[self] then
        oHP[self].Size = v
        return
    end
    return oNIdx(self, k, v)
end)

S.Runtime.AddCleanup(function()
	pcall(function() hookmetamethod(game, "__index", oIdx) end)
	pcall(function() hookmetamethod(game, "__newindex", oNIdx) end)
end)

function S.Runtime.RestoreHitboxHead(head)
	local original = oHP[head]
	if not original then return end
	oHP[head] = nil
	if head and head.Parent then
		S.Runtime.Try("Combat.RestoreHitbox", function()
			head.Size = original.Size
			head.Transparency = original.Transparency
			head.CanCollide = original.CanCollide
			head.Massless = original.Massless
		end)
	end
end

function S.Runtime.RemoveHitboxCharacter(character)
	local record = S.Runtime.HitboxCharacters[character]
	if not record then return end
	S.Runtime.HitboxCharacters[character] = nil
	for _, connection in ipairs(record.Connections) do connection:Disconnect() end
	S.Runtime.RestoreHitboxHead(record.Head)
end

function S.Runtime.ApplyHitboxCharacter(character)
	if not S.HitboxEnabled or not character:IsA("Model") or character == lp.Character or character.Name == lp.Name then return end
	local owner = pl:GetPlayerFromCharacter(character)
	if owner == lp then return end
	local record = S.Runtime.HitboxCharacters[character]
	if not record then
		record = { Connections = {} }
		S.Runtime.HitboxCharacters[character] = record
		table.insert(record.Connections, character.AncestryChanged:Connect(function(_, parent)
			if not parent then S.Runtime.RemoveHitboxCharacter(character) end
		end))
		table.insert(record.Connections, character.ChildAdded:Connect(function(child)
			if child.Name == "Head" or child:IsA("Humanoid") then task.defer(S.Runtime.ApplyHitboxCharacter, character) end
		end))
		table.insert(record.Connections, character.ChildRemoved:Connect(function(child)
			local current = S.Runtime.HitboxCharacters[character]
			if not current then return end
			if child == current.Head then
				S.Runtime.RestoreHitboxHead(child)
				current.Head = nil
			elseif child == current.Humanoid then
				S.Runtime.RemoveHitboxCharacter(character)
			end
		end))
	end
	local head = character:FindFirstChild("Head")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if record.Head and record.Head ~= head then S.Runtime.RestoreHitboxHead(record.Head) end
	record.Head = head
	if not head or not head:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return end
	if record.Humanoid ~= humanoid then
		record.Humanoid = humanoid
		table.insert(record.Connections, humanoid.Died:Connect(function() S.Runtime.RemoveHitboxCharacter(character) end))
	end

	if not oHP[head] then
		oHP[head] = {
			Size = head.Size,
			Transparency = head.Transparency,
			CanCollide = head.CanCollide,
			Massless = head.Massless,
		}
	end
	head.Size = Vector3.new(S.HitboxSize, S.HitboxSize, S.HitboxSize)
	head.Transparency = S.HitboxTrans
	head.CanCollide = false
	head.Massless = true
end

function S.Runtime.RefreshHitboxes()
	if not S.HitboxEnabled then return end
	for character in pairs(S.Runtime.HitboxCharacters) do S.Runtime.ApplyHitboxCharacter(character) end
end

function S.Runtime.SetHitboxEnabled(enabled)
	S.HitboxEnabled = enabled
	if enabled then
		local folder = ws:FindFirstChild("Characters")
		if folder then
			for _, character in ipairs(folder:GetChildren()) do task.defer(S.Runtime.ApplyHitboxCharacter, character) end
		end
	else
		for character in pairs(S.Runtime.HitboxCharacters) do S.Runtime.RemoveHitboxCharacter(character) end
		for head in pairs(oHP) do S.Runtime.RestoreHitboxHead(head) end
	end
end

S.Runtime.Connect(ws.ChildAdded, function(child)
	if child.Name == "Characters" then
		S.Runtime.CharactersFolder = child
		S.Runtime.Connect(child.ChildAdded, function(character) task.defer(S.Runtime.ApplyHitboxCharacter, character) end)
		S.Runtime.Connect(child.ChildRemoved, S.Runtime.RemoveHitboxCharacter)
		for _, character in ipairs(child:GetChildren()) do task.defer(S.Runtime.ApplyHitboxCharacter, character) end
	end
end)
S.Runtime.CharactersFolder = ws:FindFirstChild("Characters")
if S.Runtime.CharactersFolder then
	S.Runtime.Connect(S.Runtime.CharactersFolder.ChildAdded, function(character) task.defer(S.Runtime.ApplyHitboxCharacter, character) end)
	S.Runtime.Connect(S.Runtime.CharactersFolder.ChildRemoved, S.Runtime.RemoveHitboxCharacter)
end

local function ds(lf, f, t, th)
	if not f or not t then 
		lf.Visible = false 
		return 
	end
	local ctr = (f + t) / 2
	local dst = (t - f).Magnitude
	local ang = math.atan2(t.Y - f.Y, t.X - f.X)
	lf.Position = UDim2.fromOffset(ctr.X - dst/2, ctr.Y - th/2)
	lf.Size = UDim2.fromOffset(dst, th)
	lf.Rotation = math.deg(ang)
	lf.Visible = true
end

local function cln(plr)
	if ea[plr] then
		for _, obj in pairs(ea[plr]) do
			if typeof(obj) == "Instance" then 
				obj:Destroy()
			elseif typeof(obj) == "table" and obj.Lines then
				for _, ln in ipairs(obj.Lines) do 
					if ln.Remove then ln:Remove() end
				end
			elseif typeof(obj) == "userdata" and obj.Remove then
				obj:Remove()
			end
		end
		ea[plr] = nil
	end
end

en.PlayerAdded = S.Runtime.Connect(pl.PlayerAdded, function(player)
	if player ~= lp then
		en.Players[player] = true
	end
end)

en.PlayerRemoving = S.Runtime.Connect(pl.PlayerRemoving, function(player)
	en.Players[player] = nil
	cln(player)
end)

local function cr_b()
	local b = {}
	local n = {"Outer", "Main", "Inner"}
	for i = 1, 3 do
		local f = Instance.new("Frame")
		f.Name = n[i]
		f.BackgroundTransparency = 1
		f.Parent = eg
		local s = Instance.new("UIStroke")
		s.Thickness = 1
		s.Parent = f
		b[n[i]] = f
		b[n[i] .. "Stroke"] = s
	end
	b.OuterStroke.Color = eo.BoxOuter
	b.MainStroke.Color = eo.BoxMain
	b.InnerStroke.Color = eo.BoxInner

	local fb = Instance.new("Frame")
	fb.Name = "FillBox"
	fb.BackgroundColor3 = eo.FillBox
	fb.BackgroundTransparency = 1 - eo.FillBoxTransparency
	fb.BorderSizePixel = 0
	fb.Visible = false
	fb.Parent = eg
	b.FillBox = fb

	local hb = Instance.new("Frame")
	hb.Name = "HealthBg"
	hb.BackgroundTransparency = 0
	hb.BorderSizePixel = 0
	hb.Parent = eg
	local gr = Instance.new("UIGradient")
	gr.Rotation = 90
	gr.Parent = hb

	local function up_g()
		gr.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, eo.HealthGradientStart),
			ColorSequenceKeypoint.new(0.5, eo.HealthGradientMid),
			ColorSequenceKeypoint.new(1, eo.HealthGradientEnd)
		})
	end
	up_g()
	b.UpdateGradient = up_g

	local hm = Instance.new("Frame")
	hm.Name = "HealthMask"
	hm.BackgroundColor3 = eo.HealthMask
	hm.BackgroundTransparency = eo.HealthMaskTransparency
	hm.BorderSizePixel = 0
	hm.Parent = hb
	hm.ZIndex = hb.ZIndex + 1

	local hbs = Instance.new("UIStroke")
	hbs.Color = Color3.new(0,0,0)
	hbs.Thickness = 1
	hbs.Parent = hb

	local nl = Instance.new("TextLabel")
	nl.Name = "NameLabel"
	nl.BackgroundTransparency = 1
	nl.Text = ""
	nl.TextSize = 12
	nl.FontFace = Font.fromEnum(Enum.Font.SourceSans)
	nl.TextStrokeTransparency = 0
	nl.TextStrokeColor3 = Color3.new(0,0,0)
	nl.Parent = eg
	nl.TextColor3 = eo.Name

	local ht = Instance.new("TextLabel")
	ht.Name = "HealthText"
	ht.BackgroundTransparency = 1
	ht.Text = ""
	ht.TextSize = 10
	ht.FontFace = Font.fromEnum(Enum.Font.SourceSans)
	ht.TextStrokeTransparency = 0
	ht.TextStrokeColor3 = Color3.new(0,0,0)
	ht.TextXAlignment = Enum.TextXAlignment.Right
	ht.Parent = eg
	ht.TextColor3 = eo.HealthText

	local dl = Instance.new("TextLabel")
	dl.Name = "DistanceLabel"
	dl.BackgroundTransparency = 1
	dl.Text = ""
	dl.TextSize = 12
	dl.FontFace = Font.fromEnum(Enum.Font.SourceSans)
	dl.TextStrokeTransparency = 0
	dl.TextStrokeColor3 = Color3.new(0,0,0)
	dl.TextXAlignment = Enum.TextXAlignment.Center
	dl.Parent = eg
	dl.TextColor3 = eo.Distance

	local tl = Instance.new("TextLabel")
	tl.Name = "ToolLabel"
	tl.BackgroundTransparency = 1
	tl.Text = ""
	tl.TextSize = 12 
	tl.FontFace = Font.fromEnum(Enum.Font.SourceSans) 
	tl.TextStrokeTransparency = 0 
	tl.TextStrokeColor3 = Color3.new(0,0,0)
	tl.TextColor3 = eo.WeaponName
	tl.TextXAlignment = Enum.TextXAlignment.Center
	tl.Parent = eg

	local tc = Instance.new("Frame")
	tc.Name = "TracerContainer"
	tc.BackgroundTransparency = 1
	tc.Size = UDim2.new(1, 0, 1, 0)
	tc.Parent = eg
	
	b.TracerLine = Instance.new("Frame")
	b.TracerLine.Name = "TracerLine"
	b.TracerLine.BackgroundColor3 = eo.Tracer
	b.TracerLine.BorderSizePixel = 0
	b.TracerLine.Visible = false
	b.TracerLine.Parent = tc
	b.TracerContainer = tc

	b.HealthBg = hb
	b.HealthMask = hm
	b.NameLabel = nl
	b.HealthText = ht
	b.DistanceLabel = dl
	b.ToolLabel = tl
	b.LastTool = nil
	b.VisualHealth = nil

	return b
end

en.EnsureSkeleton = function(esp)
	if esp.SkeletonLines then
		return esp.SkeletonLines
	end

	local container = Instance.new("Frame")
	container.Name = "SkeletonContainer"
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 1, 0)
	container.Parent = eg

	local lines = {}
	for i = 1, 20 do
		local line = Instance.new("Frame")
		line.Name = "SkeletonLine" .. i
		line.BackgroundColor3 = eo.Skeleton
		line.BackgroundTransparency = eo.SkeletonTransparency
		line.BorderSizePixel = 0
		line.Visible = false
		line.Parent = container
		lines[i] = line
	end

	esp.SkeletonContainer = container
	esp.SkeletonLines = lines
	return lines
end

local function s_v(esp, vis)
	if not esp then return end
	esp.Outer.Visible = vis
	esp.Main.Visible = vis
	esp.Inner.Visible = vis
	esp.FillBox.Visible = vis and ec.FillBox
	
	if esp.SkeletonLines then
		for _, ln in pairs(esp.SkeletonLines) do 
			ln.Visible = vis and ec.Skeleton 
		end
	end
	
	if esp.TracerLine then
		esp.TracerLine.Visible = vis and ec.Tracer
	end
end

en.HidePlayerEsp = function(esp)
	if not esp then return end
	s_v(esp, false)
	esp.DistanceLabel.Visible = false
	esp.NameLabel.Visible = false
	esp.HealthText.Visible = false
	esp.HealthBg.Visible = false
	esp.ToolLabel.Visible = false
end

en.PlayerEspElapsed = 0
en.PlayerEspWasEnabled = false
function S.Runtime.PlayerEspStep(deltaTime)
	en.PlayerEspElapsed += deltaTime
	if en.PlayerEspElapsed < (S.PerformanceMode and (1 / 15) or (1 / 30)) then return end
	en.PlayerEspElapsed = 0

		if not en.PlayerEspWasEnabled then
			eg.Enabled = true
			en.PlayerEspWasEnabled = true
		end
		local lpc = lp.Character
		local lpr = lpc and lpc:FindFirstChild("HumanoidRootPart")
		local v_sz = cm.ViewportSize
		local s_ctr = Vector2.new(v_sz.X / 2, v_sz.Y)

		for plr in pairs(en.Players) do
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")

			if not char or not root or not hum or hum.Health <= 0 then
				if ea[plr] then cln(plr) end
				continue
			end

			local playerDistance
			if lpr then
				local distanceOffset = lpr.Position - root.Position
				if distanceOffset:Dot(distanceOffset) > (ec.MaxDistance * ec.MaxDistance) then
					en.HidePlayerEsp(ea[plr])
					continue
				end
				if ec.Distance then
					playerDistance = distanceOffset.Magnitude
				end
			end

			local esp = ea[plr]
			local rootViewport = cm:WorldToViewportPoint(root.Position)
			if rootViewport.Z <= 0 then
				en.HidePlayerEsp(esp)
				continue
			end
			local cf, sz = char:GetBoundingBox()
			if not cf then
				if esp then cln(plr) end
				continue
			end

			local hs = sz / 2
			local crn = {
				cf * Vector3.new(hs.X, hs.Y, hs.Z),
				cf * Vector3.new(hs.X, hs.Y, -hs.Z),
				cf * Vector3.new(hs.X, -hs.Y, hs.Z),
				cf * Vector3.new(hs.X, -hs.Y, -hs.Z),
				cf * Vector3.new(-hs.X, hs.Y, hs.Z),
				cf * Vector3.new(-hs.X, hs.Y, -hs.Z),
				cf * Vector3.new(-hs.X, -hs.Y, hs.Z),
				cf * Vector3.new(-hs.X, -hs.Y, -hs.Z)
			}

			local l_, t = math.huge, math.huge
			local rg, b = -math.huge, -math.huge
			local o_scr = false

			for i = 1, 8 do
				local s_pos, is_v = cm:WorldToScreenPoint(crn[i])
				if is_v then
					o_scr = true
					l_ = math.min(l_, s_pos.X)
					t = math.min(t, s_pos.Y)
					rg = math.max(rg, s_pos.X)
					b = math.max(b, s_pos.Y)
				end
			end

			if o_scr then
				if not esp then 
					esp = cr_b() 
					ea[plr] = esp 
				end

				s_v(esp, true)
				l_ = math.floor(l_)
				t = math.floor(t)
				rg = math.ceil(rg)
				b = math.ceil(b)

				local ins = (b - t) * 0.04
				l_ = l_ + ins
				t = t + ins
				rg = rg - ins
				b = b - ins

				local w_d, h_g = rg - l_, b - t
				local b_t_y = t - 1
				local t_b_h = h_g + 2

				esp.Outer.Position = UDim2.fromOffset(l_ - 1, b_t_y)
				esp.Outer.Size = UDim2.fromOffset(w_d + 2, t_b_h)
				esp.Main.Position = UDim2.fromOffset(l_, t)
				esp.Main.Size = UDim2.fromOffset(w_d, h_g)
				esp.Inner.Position = UDim2.fromOffset(l_ + 1, t + 1)
				esp.Inner.Size = UDim2.fromOffset(w_d - 2, h_g - 2)

				esp.FillBox.Position = UDim2.fromOffset(l_, t)
				esp.FillBox.Size = UDim2.fromOffset(w_d, h_g)
				esp.FillBox.Visible = ec.FillBox and ec.Box

				local y_o = t - 18
				if ec.Name then
					local dn = ec.UseDisplayName and plr.DisplayName or plr.Name
					if esp.LastName ~= dn then
						esp.NameLabel.Text = dn
						esp.LastName = dn
					end
					esp.NameLabel.Position = UDim2.fromOffset(l_ - 1, y_o)
					esp.NameLabel.Size = UDim2.fromOffset(w_d + 2, 12)
					esp.NameLabel.Visible = true
					y_o = y_o - 14
				else
					esp.NameLabel.Visible = false
				end

				local b_y_o = b + 2
				if ec.WeaponName then
					local toolName = "Hands"
					local equipped = char:FindFirstChild("Equipped")
					local item = equipped and equipped:FindFirstChildOfClass("Model")
					if item then toolName = item.Name end

					if toolName ~= esp.LastTool then
						esp.ToolLabel.Text = toolName
						esp.LastTool = toolName
					end

					esp.ToolLabel.Visible = true
					esp.ToolLabel.Position = UDim2.fromOffset(l_ - 1, b_y_o)
					esp.ToolLabel.Size = UDim2.fromOffset(w_d + 2, 12)
					b_y_o = b_y_o + 14
				else
					esp.ToolLabel.Visible = false
				end

				if ec.Distance and playerDistance then
					local d_v = ec.Metric == "Meters" and math.floor(playerDistance * 0.28) or math.floor(playerDistance)
					local u_ = ec.Metric == "Meters" and "м" or "s"
					local distanceText = d_v .. u_
					if esp.LastDistance ~= distanceText then
						esp.DistanceLabel.Text = distanceText
						esp.LastDistance = distanceText
					end
					esp.DistanceLabel.Position = UDim2.fromOffset(l_ - 1, b_y_o)
					esp.DistanceLabel.Size = UDim2.fromOffset(w_d + 2, 12)
					esp.DistanceLabel.Visible = true
					b_y_o = b_y_o + 14
				else
					esp.DistanceLabel.Visible = false
				end

				if ec.HPBar or ec.HPText then
					local h_p = hum.Health / hum.MaxHealth
					local h_v = math.floor(hum.Health)

					if esp.VisualHealth == nil then esp.VisualHealth = h_p end
					esp.VisualHealth = esp.VisualHealth + (h_p - esp.VisualHealth) * 0.1

					esp.HealthText.Text = tostring(h_v)
					local hb_w = 2
					local m_h = t_b_h * (1 - esp.VisualHealth)
					local ht_y = b_t_y + m_h + 3 - (esp.HealthText.Size.Y.Offset / 2)

					esp.HealthText.Position = UDim2.fromOffset(l_ - hb_w - 30, ht_y)
					esp.HealthText.Size = UDim2.fromOffset(18, 10)
					esp.HealthText.Visible = ec.HPText

					esp.HealthBg.Position = UDim2.fromOffset(l_ - hb_w - 6, b_t_y)
					esp.HealthBg.Size = UDim2.fromOffset(hb_w, t_b_h)
					esp.HealthMask.Position = UDim2.fromOffset(0, 0)
					esp.HealthMask.Size = UDim2.fromOffset(hb_w, m_h)
					esp.HealthBg.Visible = ec.HPBar
				else
					esp.HealthBg.Visible = false
					esp.HealthText.Visible = false
				end

				if ec.Skeleton then
					en.EnsureSkeleton(esp)
					local pts = {
						Head = char:FindFirstChild("Head"),
						UpperTorso = char:FindFirstChild("UpperTorso"),
						LowerTorso = char:FindFirstChild("LowerTorso"),
						LeftUpperArm = char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm"),
						LeftLowerArm = char:FindFirstChild("LeftLowerArm"),
						LeftHand = char:FindFirstChild("LeftHand"),
						RightUpperArm = char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm"),
						RightLowerArm = char:FindFirstChild("RightLowerArm"),
						RightHand = char:FindFirstChild("RightHand"),
						LeftUpperLeg = char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("Left Leg"),
						LeftLowerLeg = char:FindFirstChild("LeftLowerLeg"),
						LeftFoot = char:FindFirstChild("LeftFoot"),
						RightUpperLeg = char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg"),
						RightLowerLeg = char:FindFirstChild("RightLowerLeg"),
						RightFoot = char:FindFirstChild("RightFoot"),
					}

					local pos = {}
					for name, part in pairs(pts) do
						if part then
							local p_s, v_s = cm:WorldToViewportPoint(part.Position)
							pos[name] = v_s and Vector2.new(p_s.X, p_s.Y) or nil
						end
					end

					local l_i = 1
					local function d_l(f_p, t_p)
						if f_p and t_p and esp.SkeletonLines[l_i] then
							ds(esp.SkeletonLines[l_i], f_p, t_p, 1)
							esp.SkeletonLines[l_i].BackgroundColor3 = eo.Skeleton
							esp.SkeletonLines[l_i].BackgroundTransparency = eo.SkeletonTransparency
							l_i = l_i + 1
						end
					end

					d_l(pos.Head, pos.UpperTorso)
					d_l(pos.UpperTorso, pos.LowerTorso)
					d_l(pos.UpperTorso, pos.LeftUpperArm)
					if pos.LeftLowerArm then d_l(pos.LeftUpperArm, pos.LeftLowerArm) end
					if pos.LeftHand then d_l(pos.LeftLowerArm or pos.LeftUpperArm, pos.LeftHand) end
					d_l(pos.UpperTorso, pos.RightUpperArm)
					if pos.RightLowerArm then d_l(pos.RightUpperArm, pos.RightLowerArm) end
					if pos.RightHand then d_l(pos.RightLowerArm or pos.RightUpperArm, pos.RightHand) end
					d_l(pos.LowerTorso, pos.LeftUpperLeg)
					if pos.LeftLowerLeg then d_l(pos.LeftUpperLeg, pos.LeftLowerLeg) end
					if pos.LeftFoot then d_l(pos.LeftLowerLeg or pos.LeftUpperLeg, pos.LeftFoot) end
					d_l(pos.LowerTorso, pos.RightUpperLeg)
					if pos.RightLowerLeg then d_l(pos.RightUpperLeg, pos.RightLowerLeg) end
					if pos.RightFoot then d_l(pos.RightLowerLeg or pos.RightUpperLeg, pos.RightFoot) end

					for i = l_i, #esp.SkeletonLines do 
						esp.SkeletonLines[i].Visible = false 
					end
				else
					if esp and esp.SkeletonLines then
						for _, ln in pairs(esp.SkeletonLines) do ln.Visible = false end
					end
				end

				if ec.Tracer and esp.TracerLine and root then
					local s_p, o_s = cm:WorldToViewportPoint(root.Position)
					if o_s then
						ds(esp.TracerLine, s_ctr, Vector2.new(s_p.X, s_p.Y), 1)
						esp.TracerLine.BackgroundColor3 = eo.Tracer
						esp.TracerLine.Visible = true
					else
						esp.TracerLine.Visible = false
					end
				else
					if esp and esp.TracerLine then esp.TracerLine.Visible = false end
				end

				esp.Outer.Visible = ec.Box
				esp.Main.Visible = ec.Box
				esp.Inner.Visible = ec.Box
			else
				en.HidePlayerEsp(esp)
			end
		end
end

function S.Runtime.UpdatePlayerEspWorker()
	if not ec.Enabled then
		eg.Enabled = false
		en.PlayerEspWasEnabled = false
		for _, esp in pairs(ea) do en.HidePlayerEsp(esp) end
	end
	S.Runtime.SetWorker("PlayerESP", rs.RenderStepped, S.Runtime.PlayerEspStep, ec.Enabled)
end

local function t_tr(v) return math.clamp(v / 20, 0, 1) end

local function u_hl(h)
	h.FillColor = ch.FillColor
	h.OutlineColor = ch.OutlineColor
	h.FillTransparency = t_tr(ch.FillTransparency)
	h.OutlineTransparency = t_tr(ch.OutlineTransparency)
end

local function hl_p(plr)
	if plr == lp then return end
	if h_s:FindFirstChild(plr.Name) then h_s[plr.Name]:Destroy() end

	local h = Instance.new("Highlight")
	h.Name = plr.Name
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Enabled = ch.Enabled
	h.Parent = h_s

	local function a_ch(char)
		h.Adornee = char
		u_hl(h)
	end
	if plr.Character then a_ch(plr.Character) end
	ch_c[plr] = S.Runtime.Connect(plr.CharacterAdded, a_ch)
end

S.Runtime.Connect(pl.PlayerAdded, hl_p)
for _, plr in ipairs(pl:GetPlayers()) do hl_p(plr) end

S.Runtime.Connect(pl.PlayerRemoving, function(plr)
	S.Runtime.FriendCache[plr.UserId] = nil
	S.Runtime.SquadMembers[plr.UserId] = nil
	if h_s:FindFirstChild(plr.Name) then 
		h_s[plr.Name]:Destroy() 
	end
	if ch_c[plr] then 
		S.Runtime.Disconnect(ch_c[plr])
		ch_c[plr] = nil 
	end
end)

local function i_ic(m) return m.Name:lower():find("infected") ~= nil end

local function r_ce(m)
	local h = m:FindFirstChild("CorpseHighlight")
	if h then h:Destroy() end
	local eg_ = m:FindFirstChild("CorpseESP")
	if eg_ then eg_:Destroy() end
end

local function c_ch(m)
	if i_ic(m) then return end
	if not m:FindFirstChild("CorpseHighlight") then
		local h = Instance.new("Highlight")
		h.Name = "CorpseHighlight"
		h.FillColor = cs.highlightColor
		h.OutlineColor = Color3.new(1, 1, 1)
		h.FillTransparency = 0.5
		h.OutlineTransparency = 0
		h.Adornee = m
		h.Parent = m
	end
end

local function c_cb(m)
	if i_ic(m) then return end
	local pr = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if not pr then return end
	local existing = m:FindFirstChild("CorpseESP")
	if existing then existing:Destroy() end

	local bb = Instance.new("BillboardGui")
	bb.Name = "CorpseESP"
	bb.Adornee = pr
	bb.Size = UDim2.new(0, 200, 0, 50)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Parent = m

	if cs.showNames then
		local nl = Instance.new("TextLabel")
		nl.Name = "CorpseName"
		nl.Size = UDim2.new(1, 0, 0, 20)
		nl.BackgroundTransparency = 1
		nl.TextSize = 12
		nl.TextColor3 = cs.nameColor
		nl.TextStrokeTransparency = 0.5
		nl.Font = Enum.Font.Code
		nl.Text = m.Name .. "'s Corpse"
		nl.Parent = bb
	end

	if cs.showDistance then
		local dl = Instance.new("TextLabel")
		dl.Name = "CorpseDistance"
		dl.Size = UDim2.new(1, 0, 0, 20)
		dl.Position = UDim2.new(0, 0, 0, 16)
		dl.BackgroundTransparency = 1
		dl.TextSize = 11
		dl.TextColor3 = cs.distanceColor
		dl.TextStrokeTransparency = 0.5
		dl.Font = Enum.Font.Code
		dl.Text = "..."
		dl.Parent = bb
	end
end

local function u_ces()
	if not cf_ then return end
	for _, corpse in pairs(cf_:GetChildren()) do
		if corpse:IsA("Model") and not i_ic(corpse) then
			if cs.enabled then
				c_ch(corpse)
				if cs.showNames or cs.showDistance then
					c_cb(corpse)
				else
					r_ce(corpse)
				end
			else
				r_ce(corpse)
			end
		else
			r_ce(corpse)
		end
	end
end

if cf_ then
	S.Runtime.Connect(cf_.ChildAdded, function(child)
		if cs.enabled and child:IsA("Model") and not i_ic(child) then
			c_ch(child)
			if cs.showNames or cs.showDistance then c_cb(child) end
		end
	end)
end

en.CorpseEspElapsed = 0
function S.Runtime.CorpseEspStep(deltaTime)
	if not cf_ then return end
	en.CorpseEspElapsed += deltaTime
	if en.CorpseEspElapsed < (S.PerformanceMode and 0.2 or 0.1) then return end
	en.CorpseEspElapsed = 0
	local c_ps = cm.CFrame.Position
	for _, corpse in pairs(cf_:GetChildren()) do
		if corpse:IsA("Model") and not i_ic(corpse) then
			local pr = corpse.PrimaryPart or corpse:FindFirstChildWhichIsA("BasePart", true)
			if pr then
				local distanceOffset = c_ps - pr.Position
				local distanceSquared = distanceOffset:Dot(distanceOffset)
				local i_r = distanceSquared <= (cs.maxDistance * cs.maxDistance)
				local d = i_r and math.sqrt(distanceSquared) or cs.maxDistance
				local tr = 0
				local f_s = cs.maxDistance * 0.9

				if d >= cs.maxDistance then
					tr = 1
				elseif d >= f_s then
					tr = (d - f_s) / (cs.maxDistance * 0.1)
				end

				local eg_ = corpse:FindFirstChild("CorpseESP")
				if eg_ then
					local nl = eg_:FindFirstChild("CorpseName")
					local dl = eg_:FindFirstChild("CorpseDistance")
					if nl then
						nl.Visible = cs.showNames and i_r
						nl.TextTransparency = tr
						nl.TextStrokeTransparency = 0.5 + tr / 2
					end
					if dl then
						dl.Visible = cs.showDistance and i_r
						dl.TextTransparency = tr
						dl.TextStrokeTransparency = 0.5 + tr / 2
						if i_r then
							dl.Text = "[" .. tostring(math.floor(d)) .. "s]"
						end
					end
				end

				local hl = corpse:FindFirstChild("CorpseHighlight")
				if hl then
					hl.FillTransparency = 0.5 + tr / 2
					hl.OutlineTransparency = tr
				end
			end
		end
	end
end

function S.Runtime.UpdateCorpseEspWorker()
	S.Runtime.SetWorker("CorpseESP", rs.RenderStepped, S.Runtime.CorpseEspStep, cs.enabled)
end

local function r_ve(m)
	local eg_ = m:FindFirstChild("VehicleESP_GUI")
	if eg_ then eg_:Destroy() end
	ev[m] = nil
end

local function c_vb(m)
	local pr = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if not pr then return end
	r_ve(m)

	local bb = Instance.new("BillboardGui")
	bb.Name = "VehicleESP_GUI"
	bb.Adornee = pr
	bb.Size = UDim2.new(0, 150, 0, 50)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Parent = m

	local nl, dl
	if vs.showNames then
		nl = Instance.new("TextLabel")
		nl.Name = "VehicleNameLabel"
		nl.Size = UDim2.new(1, 0, 0, 20)
		nl.BackgroundTransparency = 1
		nl.TextSize = 12
		nl.TextColor3 = vs.nameColor
		nl.TextStrokeTransparency = 0.5
		nl.Font = Enum.Font.Code
		nl.Text = m.Name
		nl.Parent = bb
	end

	if vs.showDistance then
		dl = Instance.new("TextLabel")
		dl.Name = "VehicleDistanceLabel"
		dl.Size = UDim2.new(1, 0, 0, 20)
		dl.Position = UDim2.new(0, 0, 0, 16)
		dl.BackgroundTransparency = 1
		dl.TextSize = 12
		dl.TextColor3 = vs.distanceColor
		dl.TextStrokeTransparency = 0.5
		dl.Font = Enum.Font.Code
		dl.Text = "[...]"
		dl.Parent = bb
	end

	ev[m] = {
		model = m, primary = pr, billboard = bb,
		nameLabel = nl, distanceLabel = dl
	}
end

local function u_vhe()
	if not vh_ then return end
	for _, vh in pairs(vh_:GetChildren()) do
		if vh:IsA("Model") then
			if vs.enabled and (vs.showNames or vs.showDistance) then
				c_vb(vh)
			else
				r_ve(vh)
			end
		end
	end
end

if vh_ then
	S.Runtime.Connect(vh_.ChildAdded, function(child)
		if vs.enabled and child:IsA("Model") then
			if vs.showNames or vs.showDistance then c_vb(child) end
		end
	end)
end

en.VehicleEspElapsed = 0
function S.Runtime.VehicleEspStep(deltaTime)
	en.VehicleEspElapsed += deltaTime
	if en.VehicleEspElapsed < (S.PerformanceMode and 0.2 or 0.1) then return end
	en.VehicleEspElapsed = 0
	local c_ps = cm.CFrame.Position
	for _, d in pairs(ev) do
		local m = d.model
		local pr = d.primary
		if m and m.Parent and pr and pr.Parent then
			local distanceOffset = c_ps - pr.Position
			local distanceSquared = distanceOffset:Dot(distanceOffset)
			local i_r = distanceSquared <= (vs.maxDistance * vs.maxDistance)
			local dst = i_r and math.sqrt(distanceSquared) or vs.maxDistance
			local tr = 0
			local f_s = vs.maxDistance * 0.9

			if dst >= vs.maxDistance then
				tr = 1
			elseif dst >= f_s then
				tr = (dst - f_s) / (vs.maxDistance * 0.1)
			end

			if d.nameLabel then
				d.nameLabel.Visible = vs.showNames and i_r
				d.nameLabel.TextTransparency = tr
				d.nameLabel.TextStrokeTransparency = 0.5 + tr / 2
			end

			if d.distanceLabel then
				d.distanceLabel.Visible = vs.showDistance and i_r
				d.distanceLabel.TextTransparency = tr
				d.distanceLabel.TextStrokeTransparency = 0.5 + tr / 2
				if i_r then
					d.distanceLabel.Text = "[" .. tostring(math.floor(dst)) .. "s]"
				end
			end
		else
			r_ve(m)
		end
	end
end

function S.Runtime.UpdateVehicleEspWorker()
	S.Runtime.SetWorker("VehicleESP", rs.RenderStepped, S.Runtime.VehicleEspStep, vs.enabled and (vs.showNames or vs.showDistance))
end

local function r_ze(m)
	local eg_ = m:FindFirstChild("ZombieESP_GUI")
	if eg_ then eg_:Destroy() end
	ez[m] = nil
end

function S.Runtime.GetZombieType(model)
	local attributeType = model:GetAttribute("Type") or model:GetAttribute("ZombieType") or model:GetAttribute("Class")
	local label = type(attributeType) == "string" and attributeType or model.Name
	local lowered = label:lower()
	if lowered:find("boss", 1, true) then return "Boss" end
	if lowered:find("special", 1, true) or lowered:find("unique", 1, true) or lowered:find("event", 1, true) then
		return "Special"
	end
	return "Infected"
end

function S.Runtime.IsZombieAllowed(model)
	return not zs.bossesOnly or S.Runtime.GetZombieType(model) ~= "Infected"
end

local function c_zb(m)
	if not S.Runtime.IsZombieAllowed(m) then r_ze(m); return end
	local pr = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if not pr then return end
	r_ze(m)

	local bb = Instance.new("BillboardGui")
	bb.Name = "ZombieESP_GUI"
	bb.Adornee = pr
	bb.Size = UDim2.new(0, 170, 0, 84)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Parent = m

	local nl, dl, hl, tl
	local row = 0
	if zs.showNames then
		nl = Instance.new("TextLabel")
		nl.Name = "ZombieNameLabel"
		nl.Size = UDim2.new(1, 0, 0, 20)
		nl.BackgroundTransparency = 1
		nl.TextSize = 12
		nl.TextColor3 = zs.nameColor
		nl.TextStrokeTransparency = 0.5
		nl.Font = Enum.Font.Code
		nl.Text = m:GetAttribute("DisplayName") or m.Name
		nl.Parent = bb
		row += 16
	end

	if zs.details and zs.showType then
		tl = Instance.new("TextLabel")
		tl.Name = "ZombieTypeLabel"
		tl.Size = UDim2.new(1, 0, 0, 20)
		tl.Position = UDim2.new(0, 0, 0, row)
		tl.BackgroundTransparency = 1
		tl.TextSize = 11
		tl.TextColor3 = Color3.fromRGB(242, 157, 198)
		tl.TextStrokeTransparency = 0.5
		tl.Font = Enum.Font.Code
		tl.Text = S.Runtime.GetZombieType(m)
		tl.Parent = bb
		row += 16
	end

	if zs.details and zs.showHealth then
		hl = Instance.new("TextLabel")
		hl.Name = "ZombieHealthLabel"
		hl.Size = UDim2.new(1, 0, 0, 20)
		hl.Position = UDim2.new(0, 0, 0, row)
		hl.BackgroundTransparency = 1
		hl.TextSize = 11
		hl.TextColor3 = Color3.fromRGB(125, 225, 145)
		hl.TextStrokeTransparency = 0.5
		hl.Font = Enum.Font.Code
		hl.Text = "Health: ..."
		hl.Parent = bb
		row += 16
	end

	if zs.showDistance then
		dl = Instance.new("TextLabel")
		dl.Name = "ZombieDistanceLabel"
		dl.Size = UDim2.new(1, 0, 0, 20)
		dl.Position = UDim2.new(0, 0, 0, row)
		dl.BackgroundTransparency = 1
		dl.TextSize = 12
		dl.TextColor3 = zs.distanceColor
		dl.TextStrokeTransparency = 0.5
		dl.Font = Enum.Font.Code
		dl.Text = "[...]"
		dl.Parent = bb
	end

	ez[m] = {
		model = m, primary = pr, billboard = bb,
		nameLabel = nl, distanceLabel = dl, healthLabel = hl, typeLabel = tl,
		humanoid = m:FindFirstChildOfClass("Humanoid"),
	}
end

local function u_zbe()
	if not zo_ then return end
	for _, zb in pairs(zo_:GetChildren()) do
		if zb:IsA("Model") then
			if zs.enabled and (zs.showNames or zs.showDistance or zs.details) and S.Runtime.IsZombieAllowed(zb) then
				c_zb(zb)
			else
				r_ze(zb)
			end
		end
	end
end

if zo_ then
	S.Runtime.Connect(zo_.ChildAdded, function(child)
		if zs.enabled and child:IsA("Model") then
			if zs.showNames or zs.showDistance or zs.details then c_zb(child) end
		end
	end)
end

en.ZombieEspElapsed = 0
function S.Runtime.ZombieEspStep(deltaTime)
	en.ZombieEspElapsed += deltaTime
	if en.ZombieEspElapsed < (S.PerformanceMode and 0.2 or 0.1) then return end
	en.ZombieEspElapsed = 0
	local c_ps = cm.CFrame.Position
	for _, d in pairs(ez) do
		local m = d.model
		local pr = d.primary
		if m and m.Parent and pr and pr.Parent then
			local distanceOffset = c_ps - pr.Position
			local distanceSquared = distanceOffset:Dot(distanceOffset)
			local i_r = distanceSquared <= (zs.maxDistance * zs.maxDistance)
			local dst = i_r and math.sqrt(distanceSquared) or zs.maxDistance
			local tr = 0
			local f_s = zs.maxDistance * 0.9

			if dst >= zs.maxDistance then
				tr = 1
			elseif dst >= f_s then
				tr = (dst - f_s) / (zs.maxDistance * 0.1)
			end

			if d.nameLabel then
				d.nameLabel.Visible = zs.showNames and i_r
				d.nameLabel.TextTransparency = tr
				d.nameLabel.TextStrokeTransparency = 0.5 + tr / 2
			end
			if d.typeLabel then
				d.typeLabel.Visible = zs.details and zs.showType and i_r
				d.typeLabel.TextTransparency = tr
				d.typeLabel.TextStrokeTransparency = 0.5 + tr / 2
			end
			if d.healthLabel then
				local humanoid = d.humanoid
				if not humanoid or not humanoid.Parent then
					humanoid = m:FindFirstChildOfClass("Humanoid")
					d.humanoid = humanoid
				end
				d.healthLabel.Visible = zs.details and zs.showHealth and i_r and humanoid ~= nil
				if humanoid then d.healthLabel.Text = ("Health: %d / %d"):format(math.max(0, math.floor(humanoid.Health)), math.floor(humanoid.MaxHealth)) end
				d.healthLabel.TextTransparency = tr
				d.healthLabel.TextStrokeTransparency = 0.5 + tr / 2
			end
			if d.distanceLabel then
				d.distanceLabel.Visible = zs.showDistance and i_r
				d.distanceLabel.TextTransparency = tr
				d.distanceLabel.TextStrokeTransparency = 0.5 + tr / 2
				if i_r then
					d.distanceLabel.Text = "[" .. tostring(math.floor(dst)) .. "s]"
				end
			end
		else
			r_ze(m)
		end
	end
end

function S.Runtime.UpdateZombieEspWorker()
	S.Runtime.SetWorker("ZombieESP", rs.RenderStepped, S.Runtime.ZombieEspStep, zs.enabled and (zs.showNames or zs.showDistance or zs.details))
end

local dc = {
	"ContainerShippingShort10", "ContainerShippingShort", "ContainerShippingLong", "ShippingContainer",
	"Container_", "Shipping_Container", "Crate_Decorative", "Crate_Deco", "Box_Decorative", "Box_Deco",
	"Barrel_Decorative", "Barrel_Deco", "Pallet", "WoodenPallet", "MetalPallet", "Ramp", "Pipe", "Vent",
	"Grate", "Beam", "Column", "Pillar", "Wall_Deco", "Floor_Deco", "Roof_Deco", "Stair", "Ladder",
	"Railing", "Fence", "Gate", "Door_Deco", "Window_Deco", "Glass_Deco"
}

local function i_dec(m)
	if not m or not m:IsA("Model") then return false end
	local mn = m.Name
	for _, deco in pairs(dc) do
		if mn:find(deco) then return true end
	end
	for _, child in pairs(m:GetChildren()) do
		if child:IsA("BasePart") then
			local pn = child.Name:lower()
			if pn:find("deco") or pn:find("decor") or pn:find("wall") or pn:find("floor") or pn:find("roof") or pn:find("beam") or pn:find("column") or pn:find("pillar") or pn:find("rail") or pn:find("fence") or pn:find("gate") or pn:find("door") or pn:find("window") or pn:find("glass") then
				return true
			end
		end
	end
	return false
end

function S.Runtime.GetItemData()
	if S.Runtime.ItemData ~= nil then return S.Runtime.ItemData or nil end
	S.Runtime.ItemData = false
	local framework = S.Runtime.Framework
	if framework and type(framework.require) == "function" then
		local ok, data = pcall(framework.require, "Configs", "ItemData")
		if ok and type(data) == "table" then S.Runtime.ItemData = data end
	end
	return S.Runtime.ItemData or nil
end

function S.Runtime.GetLootInfo(model)
	local itemData = S.Runtime.GetItemData()
	local candidates = {
		model:GetAttribute("ItemName"), model:GetAttribute("ItemId"), model.Name,
	}
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "string" and candidate ~= "" then
			local config = itemData and itemData[candidate]
			if config then
				return candidate, config, tostring(config.DisplayName or config.Name or candidate)
			end
		end
	end
	return model.Name, nil, model.Name
end

function S.Runtime.LootMatchesFilter(model)
	local itemName, config, displayName = S.Runtime.GetLootInfo(model)
	local filter = ls.filterType
	if filter ~= "All" then
		local category = (tostring(config and config.Type or "") .. " " .. tostring(config and config.SubType or "") .. " " .. itemName):lower()
		local needles = {
			Firearms = { "firearm", "gun", "weapon" },
			Ammo = { "ammo", "magazine", "cartridge" },
			Medical = { "medical", "health", "bandage", "med" },
			Consumables = { "consumable", "food", "drink" },
			Attachments = { "attachment", "optic", "sight", "grip", "muzzle" },
			Containers = { "container", "backpack", "bag", "vest" },
			Utilities = { "utility", "tool", "equipment" },
		}
		local matched = false
		for _, needle in ipairs(needles[filter] or {}) do
			if category:find(needle, 1, true) then matched = true; break end
		end
		if not matched then return false end
	end

	local search = ls.search:lower():match("^%s*(.-)%s*$")
	if search ~= "" then
		local haystack = (itemName .. " " .. displayName .. " " .. model.Name):lower()
		local matched = false
		for term in search:gmatch("[^,]+") do
			term = term:match("^%s*(.-)%s*$")
			if term ~= "" and haystack:find(term, 1, true) then matched = true; break end
		end
		if not matched then return false end
	end
	return true
end

local function i_rl(m)
	if not m or not m:IsA("Model") then return false end
	if i_dec(m) then return false end
	local itemData = S.Runtime.GetItemData()
	if itemData and (itemData[m.Name] or itemData[m:GetAttribute("ItemName")]) then return true end

	local hp = false
	for _, child in pairs(m:GetDescendants()) do
		if child:IsA("ProximityPrompt") then
			hp = true
			break
		end
	end
	if hp then return true end

	for _, child in pairs(m:GetDescendants()) do
		if child:IsA("ClickDetector") then return true end
	end

	local mn = m.Name:lower()
	if mn:find("loot") or mn:find("item") or mn:find("supply") or mn:find("ammo") or mn:find("weapon") or mn:find("gun") or mn:find("chest") or mn:find("box") or mn:find("crate") then
		return true
	end

	for _, child in pairs(m:GetChildren()) do
		if child:IsA("Model") and i_rl(child) then return true end
	end
	return false
end

local function g_am(f, r_s)
	r_s = r_s or {}
	if not f then return r_s end
	for _, child in pairs(f:GetChildren()) do
		if child:IsA("Model") then
			table.insert(r_s, child)
		elseif child:IsA("Folder") then
			g_am(child, r_s)
		end
	end
	return r_s
end

local function r_le(m)
	local eg_ = m:FindFirstChild("LootESP_GUI")
	if eg_ then eg_:Destroy() end
	el[m] = nil
end

local function c_lb(m)
	if not i_rl(m) or not S.Runtime.LootMatchesFilter(m) then r_le(m); return end
	local pr = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if not pr then return end
	r_le(m)

	local bb = Instance.new("BillboardGui")
	bb.Name = "LootESP_GUI"
	bb.Adornee = pr
	bb.Size = UDim2.new(0, 150, 0, 50)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.Parent = m

	local nl, dl
	if ls.showNames then
		nl = Instance.new("TextLabel")
		nl.Name = "LootNameLabel"
		nl.Size = UDim2.new(1, 0, 0, 20)
		nl.BackgroundTransparency = 1
		nl.TextSize = 12
		nl.TextColor3 = ls.nameColor
		nl.TextStrokeTransparency = 0.5
		nl.Font = Enum.Font.Code
		local _, _, displayName = S.Runtime.GetLootInfo(m)
		nl.Text = displayName
		nl.Parent = bb
	end

	if ls.showDistance then
		dl = Instance.new("TextLabel")
		dl.Name = "LootDistanceLabel"
		dl.Size = UDim2.new(1, 0, 0, 20)
		dl.Position = UDim2.new(0, 0, 0, 16)
		dl.BackgroundTransparency = 1
		dl.TextSize = 12
		dl.TextColor3 = ls.distanceColor
		dl.TextStrokeTransparency = 0.5
		dl.Font = Enum.Font.Code
		dl.Text = "[...]"
		dl.Parent = bb
	end

	el[m] = {
		model = m, primary = pr, billboard = bb,
		nameLabel = nl, distanceLabel = dl
	}
end

local function queueLootEsp(instance, root)
	local model = instance and (instance:IsA("Model") and instance or instance:FindFirstAncestorOfClass("Model"))
	if not model or model == root or not model:IsDescendantOf(root) then return end
	en.PendingLootModels = en.PendingLootModels or {}
	if en.PendingLootModels[model] then return end
	en.PendingLootModels[model] = true

	task.delay(0.25, function()
		en.PendingLootModels[model] = nil
		if S.Runtime.Unloaded or not root or not root.Parent then return end
		if not ls.enabled or not (ls.showNames or ls.showDistance) then return end

		while model and model ~= root and model:IsDescendantOf(root) do
			local parent = model.Parent
			local parentModel = parent and (parent:IsA("Model") and parent or parent:FindFirstAncestorOfClass("Model")) or nil
			if not parentModel or parentModel == root or not parentModel:IsDescendantOf(root) then break end
			model = parentModel
		end

		if model and i_rl(model) then
			local data = el[model]
			if not data or not data.billboard or not data.billboard.Parent then c_lb(model) end
		end
	end)
end

local function reconcileEspEntities()
	cf_ = ws:FindFirstChild("Corpses")
	vh_ = ws:FindFirstChild("Vehicles")
	zo_ = ws:FindFirstChild("Zombies")
	if S.Runtime.BindFreezeZombieFolder then S.Runtime.BindFreezeZombieFolder(zo_) end
	local map = ws:FindFirstChild("Map")
	local nextMapElements = map and map:FindFirstChild("Elements") or nil
	local desiredLootRoot = ls.enabled and nextMapElements or nil
	local lootRootChanged = desiredLootRoot ~= en.LootObservedRoot
	mp_ = nextMapElements
	if lootRootChanged then
		if en.LootRootConnection then
			S.Runtime.Disconnect(en.LootRootConnection)
			en.LootRootConnection = nil
		end
		en.LootObservedRoot = desiredLootRoot
		if desiredLootRoot then
			local observedRoot = desiredLootRoot
			en.LootRootConnection = S.Runtime.Connect(observedRoot.DescendantAdded, function(instance)
				queueLootEsp(instance, observedRoot)
			end)
		end
	end

	local livePlayers = {}
	for _, player in ipairs(pl:GetPlayers()) do
		if player ~= lp then
			livePlayers[player] = true
			en.Players[player] = true
		end
	end
	for player in pairs(en.Players) do
		if not livePlayers[player] then
			en.Players[player] = nil
			cln(player)
		end
	end

	if cs.enabled and cf_ then
		for _, corpse in ipairs(cf_:GetChildren()) do
			if corpse:IsA("Model") and not i_ic(corpse) then
				if not corpse:FindFirstChild("CorpseHighlight") then c_ch(corpse) end
				if (cs.showNames or cs.showDistance) and not corpse:FindFirstChild("CorpseESP") then
					c_cb(corpse)
				end
			end
		end
	end

	if vs.enabled and (vs.showNames or vs.showDistance) and vh_ then
		for _, vehicle in ipairs(vh_:GetChildren()) do
			if vehicle:IsA("Model") then
				local data = ev[vehicle]
				if not data or not data.billboard or not data.billboard.Parent or not data.primary or not data.primary.Parent then
					c_vb(vehicle)
				end
			end
		end
	end

	if zs.enabled and (zs.showNames or zs.showDistance or zs.details) and zo_ then
		for _, zombie in ipairs(zo_:GetChildren()) do
			if zombie:IsA("Model") and S.Runtime.IsZombieAllowed(zombie) then
				local data = ez[zombie]
				if not data or not data.billboard or not data.billboard.Parent or not data.primary or not data.primary.Parent then
					c_zb(zombie)
				end
			end
		end
	end

	if lootRootChanged and ls.enabled and (ls.showNames or ls.showDistance) and mp_ then
		for _, loot in ipairs(g_am(mp_)) do
			if i_rl(loot) and S.Runtime.LootMatchesFilter(loot) then
				local data = el[loot]
				if not data or not data.billboard or not data.billboard.Parent or not data.primary or not data.primary.Parent then
					c_lb(loot)
				end
			end
		end
	end
end

en.EntityDiscoveryElapsed = 0
function S.Runtime.EntityDiscoveryStep(deltaTime)
	en.EntityDiscoveryElapsed += deltaTime
	if en.EntityDiscoveryElapsed < (S.PerformanceMode and 4 or 2) then return end
	en.EntityDiscoveryElapsed = 0
	pcall(reconcileEspEntities)
end

function S.Runtime.UpdateEntityDiscoveryWorker()
	local active = ec.Enabled or ch.Enabled or cs.enabled
		or (vs.enabled and (vs.showNames or vs.showDistance))
		or (zs.enabled and (zs.showNames or zs.showDistance or zs.details))
		or (ls.enabled and (ls.showNames or ls.showDistance))
	if active then en.EntityDiscoveryElapsed = math.huge end
	S.Runtime.SetWorker("EntityDiscovery", rs.Heartbeat, S.Runtime.EntityDiscoveryStep, active)
end

local function sc_l()
	if not mp_ then return end
	local am = g_am(mp_)
	for _, m in pairs(am) do
		if i_rl(m) then
			if ls.enabled and (ls.showNames or ls.showDistance) then
				if S.Runtime.LootMatchesFilter(m) then c_lb(m) else r_le(m) end
			else
				r_le(m)
			end
		end
	end
end

local function u_lte()
	for m, _ in pairs(el) do r_le(m) end
	sc_l()
end

en.LootEspElapsed = 0
function S.Runtime.LootEspStep(deltaTime)
	en.LootEspElapsed += deltaTime
	if en.LootEspElapsed < (S.PerformanceMode and 0.25 or 0.1) then return end
	en.LootEspElapsed = 0
	local c_ps = cm.CFrame.Position
	for _, d in pairs(el) do
		local m = d.model
		local pr = d.primary
		if m and m.Parent and pr and pr.Parent then
			local distanceOffset = c_ps - pr.Position
			local distanceSquared = distanceOffset:Dot(distanceOffset)
			local i_r = distanceSquared <= (ls.maxDistance * ls.maxDistance)
			local dst = i_r and math.sqrt(distanceSquared) or ls.maxDistance
			local tr = 0
			local f_s = ls.maxDistance * 0.9

			if dst >= ls.maxDistance then
				tr = 1
			elseif dst >= f_s then
				tr = (dst - f_s) / (ls.maxDistance * 0.1)
			end

			if d.nameLabel then
				d.nameLabel.Visible = ls.showNames and i_r
				d.nameLabel.TextTransparency = tr
				d.nameLabel.TextStrokeTransparency = 0.5 + tr / 2
			end
			
			if d.distanceLabel then
				d.distanceLabel.Visible = ls.showDistance and i_r
				d.distanceLabel.TextTransparency = tr
				d.distanceLabel.TextStrokeTransparency = 0.5 + tr / 2
				if i_r then
					d.distanceLabel.Text = "[" .. tostring(math.floor(dst)) .. "s]"
				end
			end
		else
			r_le(m)
		end
	end
end

function S.Runtime.UpdateLootEspWorker()
	S.Runtime.SetWorker("LootESP", rs.RenderStepped, S.Runtime.LootEspStep, ls.enabled and (ls.showNames or ls.showDistance))
end

function S.Runtime.FreezeZombieDescendant(zombie, descendant)
	local state = S.Runtime.ZombieStates[zombie]
	if not state or not S.iFE then return end
	if descendant:IsA("BasePart") then
		if state.Parts[descendant] == nil then state.Parts[descendant] = descendant.Anchored end
		descendant.Anchored = true
	elseif descendant:IsA("Humanoid") and state.Humanoid ~= descendant then
		state.Humanoid = descendant
		state.WalkSpeed = descendant.WalkSpeed
		state.JumpPower = descendant.JumpPower
		descendant.WalkSpeed = 0
		descendant.JumpPower = 0
		table.insert(state.Connections, descendant.Died:Connect(function()
			S.Runtime.UnfreezeZombie(zombie)
		end))
	end
end

function S.Runtime.UnfreezeZombie(zombie)
	local state = S.Runtime.ZombieStates[zombie]
	if not state then return end
	S.Runtime.ZombieStates[zombie] = nil
	for _, connection in ipairs(state.Connections) do connection:Disconnect() end
	S.Runtime.Try("Zombies.Unfreeze", function()
		if state.Humanoid and state.Humanoid.Parent then
			state.Humanoid.WalkSpeed = state.WalkSpeed
			state.Humanoid.JumpPower = state.JumpPower
		end
		for part, anchored in pairs(state.Parts) do
			if part and part.Parent then part.Anchored = anchored end
		end
	end)
end

local function fzZ(z)
	if not S.iFE or not z:IsA("Model") or S.Runtime.ZombieStates[z] then return end
	S.Runtime.Try("Zombies.Freeze", function()
		local state = { Parts = setmetatable({}, { __mode = "k" }), Connections = {} }
		S.Runtime.ZombieStates[z] = state
		table.insert(state.Connections, z.DescendantAdded:Connect(function(descendant)
			S.Runtime.FreezeZombieDescendant(z, descendant)
		end))
		table.insert(state.Connections, z.AncestryChanged:Connect(function(_, parent)
			if not parent then S.Runtime.UnfreezeZombie(z) end
		end))
		for _, descendant in ipairs(z:GetDescendants()) do
			S.Runtime.FreezeZombieDescendant(z, descendant)
		end
	end)
end

local function ufzZ(z)
	S.Runtime.UnfreezeZombie(z)
end

function S.Runtime.BindFreezeZombieFolder(folder)
	if S.Runtime.FreezeZombieFolder == folder then return end
	if S.Runtime.FreezeZombieAdded then S.Runtime.Disconnect(S.Runtime.FreezeZombieAdded) end
	if S.Runtime.FreezeZombieRemoved then S.Runtime.Disconnect(S.Runtime.FreezeZombieRemoved) end
	S.Runtime.FreezeZombieFolder = folder
	table.clear(S.Runtime.ZombieCircleModels)
	S.Runtime.FreezeZombieAdded = nil
	S.Runtime.FreezeZombieRemoved = nil
	if not folder then return end
	S.Runtime.FreezeZombieAdded = S.Runtime.Connect(folder.ChildAdded, function(zombie)
		if zombie:IsA("Model") then table.insert(S.Runtime.ZombieCircleModels, zombie) end
		if S.iFE then task.defer(fzZ, zombie) end
	end)
	S.Runtime.FreezeZombieRemoved = S.Runtime.Connect(folder.ChildRemoved, function(zombie)
		local index = table.find(S.Runtime.ZombieCircleModels, zombie)
		if index then table.remove(S.Runtime.ZombieCircleModels, index) end
		local root = zombie:FindFirstChild("HumanoidRootPart")
		if root and S.Runtime.ZombieCFrames[root] then
			root.CFrame = S.Runtime.ZombieCFrames[root]
			S.Runtime.ZombieCFrames[root] = nil
		end
		ufzZ(zombie)
	end)
	for _, zombie in ipairs(folder:GetChildren()) do
		if zombie:IsA("Model") then table.insert(S.Runtime.ZombieCircleModels, zombie) end
		if S.iFE then task.defer(fzZ, zombie) end
	end
end

S.Runtime.BindFreezeZombieFolder(zo_)
S.Runtime.Connect(ws.ChildAdded, function(child)
	if child.Name == "Zombies" then zo_ = child; S.Runtime.BindFreezeZombieFolder(child) end
end)

local function uZC()
	S.Runtime.ZombieCircleGeneration = (S.Runtime.ZombieCircleGeneration or 0) + 1
	local generation = S.Runtime.ZombieCircleGeneration
    task.spawn(function()
        while S.zCE and S.Runtime.ZombieCircleGeneration == generation and not S.Runtime.Unloaded do
            S.Runtime.Try("Zombies.Circle", function()
                local rP = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                if rP then
					local zombies = S.Runtime.ZombieCircleModels
					local cn = #zombies
                    if cn > 0 then
                        local aS = math.pi * 2 / cn
                        for i, z in ipairs(zombies) do
                            local rt = z:FindFirstChild("HumanoidRootPart")
                            if rt then
									if S.Runtime.ZombieCFrames[rt] == nil then
										S.Runtime.ZombieCFrames[rt] = rt.CFrame
									end
                                local an = tick() * S.zCS + (i * aS)
                                local os = Vector3.new(
                                    math.cos(an) * S.zCD,
                                    0,
                                    math.sin(an) * S.zCD
                                )
                                rt.CFrame = CFrame.new(rP.Position + os)
                            end
                        end
                    end
                end
            end)
			task.wait(S.PerformanceMode and (1 / 30) or nil)
        end
    end)
end

function S.Runtime.SetZombieCircle(enabled)
	S.zCE = enabled
	S.Runtime.ZombieCircleGeneration = (S.Runtime.ZombieCircleGeneration or 0) + 1
	if enabled then
		uZC()
	else
		for root, cframe in pairs(S.Runtime.ZombieCFrames) do
			if root.Parent then root.CFrame = cframe end
		end
		table.clear(S.Runtime.ZombieCFrames)
	end
end

local FC = Drawing.new("Circle")
local FO = Drawing.new("Circle")
local SL = Drawing.new("Line")
local SO = Drawing.new("Line")
local Hld = false

local function uF()
    if not S.FOVEnabled then
        FC.Visible = false
        FO.Visible = false
        return
    end
    local ct = Vector2.new(cm.ViewportSize.X / 2, cm.ViewportSize.Y / 2)
    local rd = S.FOVRadius
    if S.FOVDynamic and Hld then
        rd = rd * 0.85
    end
    if S.FOVOutline then
        FO.Visible = true
        FO.Position = ct
        FO.Radius = rd
        FO.Color = Color3.fromRGB(0, 0, 0)
        FO.Thickness = S.FOVThickness + 3
        FO.Filled = false
        FO.ZIndex = -10
        FO.Transparency = 1
    else
        FO.Visible = false
    end
    FC.Visible = true
    FC.Position = ct
    FC.Radius = rd
    FC.Color = S.FOVColor
    FC.Thickness = S.FOVThickness
    FC.Filled = S.FOVFill
    FC.Transparency = 1
end
    
function S.Runtime.IsAimPlayerAllowed(player)
	if S.AimIgnoreSquad and S.Runtime.SquadMembers[player.UserId] then return false end
	if S.AimIgnoreFriends then
		local isFriend = S.Runtime.FriendCache[player.UserId]
		if isFriend == nil then
			local ok, result = pcall(lp.IsFriendsWith, lp, player.UserId)
			isFriend = ok and result == true
			S.Runtime.FriendCache[player.UserId] = isFriend
		end
		if isFriend then return false end
	end
	return true
end

local function gCP(tT, hb, mD, validator)
    local cl, sh = nil, math.huge
    local ct = Vector2.new(cm.ViewportSize.X/2, cm.ViewportSize.Y/2)
	local localRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if not localRoot then return nil end
	local maxDistanceSquared = mD * mD
    for _, pl_ in pairs(pl:GetPlayers()) do
        if pl_ ~= lp and S.Runtime.IsAimPlayerAllowed(pl_) and pl_.Character and pl_.Character.Parent then
            local ch_ = pl_.Character
			local hm = ch_:FindFirstChildOfClass("Humanoid")
			local pt = ch_:FindFirstChild(hb)
			if not hm or hm.Health <= 0 or not pt or not pt:IsA("BasePart") then continue end
			local distanceOffset = localRoot.Position - pt.Position
			local distanceSquared = distanceOffset:Dot(distanceOffset)
			if distanceSquared > maxDistanceSquared then continue end
            local pos, oS = cm:WorldToViewportPoint(pt.Position)
            if not oS then continue end
            local d2D = (Vector2.new(pos.X, pos.Y) - ct).Magnitude
			if S.FOVEnabled and d2D > S.FOVRadius then continue end
			if S.AimVisibleOnly and not S.Runtime.IsVisible(cm.CFrame.Position, pt.Position, pt) then continue end
			if validator and not validator(ch_, pt) then continue end
			local dVal = tT == "Closest To Mouse" and d2D
				or tT == "Lowest Health" and hm.Health
				or math.sqrt(distanceSquared)
            if dVal < sh then
                sh = dVal
                cl = ch_
            end
        end
    end
    return cl
end

local function mMT(tP)
    local ct = Vector2.new(cm.ViewportSize.X / 2, cm.ViewportSize.Y / 2)
    local dl = (Vector2.new(tP.X, tP.Y) - ct) * S.AimbotSmoothing
    if mousemoverel then mousemoverel(dl.X, dl.Y) end
end

function S.Runtime.IsBreakableWindow(instance)
	if not S.WindowAware or not instance or not S.Runtime.Entities then return false end
	local ok, entity = pcall(S.Runtime.Entities.Search, S.Runtime.Entities, instance)
	return ok and entity and entity.Type == "Window" or false
end

function S.Runtime.IsVisible(orG, tP, tI)
	if typeof(orG) ~= "Vector3" or typeof(tP) ~= "Vector3" then return false end
	local direction = tP - orG
	if direction.Magnitude <= 0.001 then return true end
	local targetModel = tI and tI:FindFirstAncestorOfClass("Model")

	if S.Runtime.Raycasting and S.Runtime.BulletCastLight then
		local ignoreList = {}
		if lp.Character then table.insert(ignoreList, lp.Character) end
		for _ = 1, 8 do
			local ok, hit = pcall(S.Runtime.BulletCastLight, S.Runtime.Raycasting, Ray.new(orG, direction), ignoreList)
			if not ok then break end
			if hit == nil or hit == tI or (targetModel and hit:IsDescendantOf(targetModel)) then return true end
			if not S.Runtime.IsBreakableWindow(hit) then return false end
			table.insert(ignoreList, hit)
		end
	end

    local rP = RaycastParams.new()
    rP.FilterType = Enum.RaycastFilterType.Exclude
	rP.FilterDescendantsInstances = lp.Character and {lp.Character} or {}
    rP.IgnoreWater = true
    local rs_ = workspace:Raycast(orG, tP - orG, rP)
	return rs_ == nil or rs_.Instance == tI or (targetModel and rs_.Instance:IsDescendantOf(targetModel))
end

local function gSO(orG, tP, mR, tI)
	if not cm or typeof(orG) ~= "Vector3" or typeof(tP) ~= "Vector3" then return Vector3.zero end
	local shot = tP - orG
	if shot.Magnitude <= 0.001 or S.Runtime.IsVisible(orG, tP, tI) then return Vector3.zero end

	local maxRadius = math.max(0, mR or S.BulletManipRadius or 6)
	local maxForward = math.max(0, math.floor(S.MaxForward or 3))
	local maxWalls = math.max(0, math.floor(S.MaxWalls or 2))
	if maxRadius <= 0 then return Vector3.zero end

	local forward = shot.Unit
	local referenceUp = math.abs(forward:Dot(Vector3.yAxis)) > 0.98 and cm.CFrame.RightVector or Vector3.yAxis
	local right = forward:Cross(referenceUp).Unit
	local up = right:Cross(forward).Unit
	S.Runtime.BulletManipCache = S.Runtime.BulletManipCache or setmetatable({}, { __mode = "k" })
	local cached = tI and S.Runtime.BulletManipCache[tI]
	if cached and os.clock() - cached.Time < 0.12
		and (cached.Origin - orG).Magnitude < 2 and (cached.Target - tP).Magnitude < 2
		and S.Runtime.IsVisible(orG + cached.Offset, tP, tI) then
		return cached.Offset
	end

	local blockers = {}
	if S.Runtime.Raycasting and S.Runtime.BulletCastLight then
		local ignored = {}
		if lp.Character then table.insert(ignored, lp.Character) end
		local targetModel = tI and tI:FindFirstAncestorOfClass("Model")
		for _ = 1, maxWalls + 10 do
			local ok, hit, hitPosition, hitNormal = pcall(S.Runtime.BulletCastLight, S.Runtime.Raycasting, Ray.new(orG, shot), ignored)
			if not ok then return Vector3.zero end
			if hit == nil or hit == tI or (targetModel and hit:IsDescendantOf(targetModel)) then break end
			if S.Runtime.IsBreakableWindow(hit) then
				table.insert(ignored, hit)
			elseif hit:IsA("BasePart") then
				table.insert(blockers, { Part = hit, Position = hitPosition, Normal = hitNormal })
				if #blockers > maxWalls then return Vector3.zero end
				table.insert(ignored, hit)
			else
				return Vector3.zero
			end
		end
	end
	if #blockers == 0 then return Vector3.zero end

	local function projectedExtent(part, axis)
		local cf, half = part.CFrame, part.Size * 0.5
		return math.abs(cf.RightVector:Dot(axis)) * half.X
			+ math.abs(cf.UpVector:Dot(axis)) * half.Y
			+ math.abs(cf.LookVector:Dot(axis)) * half.Z
	end

	local candidates, seen = {}, {}
	local function addCandidate(offset)
		local magnitude = offset.Magnitude
		if magnitude < 0.05 or magnitude > maxRadius then return end
		local key = ("%.1f:%.1f:%.1f"):format(offset.X, offset.Y, offset.Z)
		if seen[key] then return end
		seen[key] = true
		table.insert(candidates, offset)
	end

	local shotLengthSquared = shot:Dot(shot)
	for _, blocker in ipairs(blockers) do
		local part = blocker.Part
		local progress = math.clamp((part.Position - orG):Dot(shot) / shotLengthSquared, 0, 0.94)
		local scale = math.max(0.12, 1 - progress)
		local linePoint = orG + shot * progress
		local centerOffset = part.Position - linePoint
		local centerRight, centerUp = centerOffset:Dot(right), centerOffset:Dot(up)
		local extentRight = projectedExtent(part, right) + 0.6
		local extentUp = projectedExtent(part, up) + 0.6
		local left = (centerRight - extentRight) / scale
		local rightEdge = (centerRight + extentRight) / scale
		local bottom = (centerUp - extentUp) / scale
		local top = (centerUp + extentUp) / scale
		addCandidate(right * left)
		addCandidate(right * rightEdge)
		addCandidate(up * bottom)
		addCandidate(up * top)
		addCandidate(right * left + up * bottom)
		addCandidate(right * left + up * top)
		addCandidate(right * rightEdge + up * bottom)
		addCandidate(right * rightEdge + up * top)
	end
	for step = 1, maxForward do addCandidate(forward * math.min(maxRadius, step * 1.5)) end
	if S.ObstructionFallback then
		addCandidate(right * maxRadius)
		addCandidate(-right * maxRadius)
		addCandidate(up * maxRadius)
		addCandidate(-up * maxRadius)
	end
	table.sort(candidates, function(a, b) return a.Magnitude < b.Magnitude end)

	local function tryOffset(offset)
		return S.Runtime.IsVisible(orG + offset, tP, tI) and offset or nil
	end

	for index = 1, math.min(#candidates, S.PerformanceMode and 10 or 20) do
		local offset = tryOffset(candidates[index])
		if offset then
			if tI then S.Runtime.BulletManipCache[tI] = { Origin = orG, Target = tP, Offset = offset, Time = os.clock() } end
			return offset
		end
	end

	return Vector3.zero
end

function S.Runtime.GetSilentAimPoint(part, origin, firearm)
	local basePoint = part.Position
	if not S.SilentPrediction or typeof(origin) ~= "Vector3" then return basePoint end
	local fireConfig = type(firearm) == "table" and firearm.FireConfig or nil
	local speed = fireConfig and tonumber(fireConfig.MuzzleVelocity) or nil
	if not speed or speed <= 0 then return basePoint end
	local globals = S.Runtime.ProjectileGlobals
	speed *= globals and tonumber(globals.MuzzleVelocityMod) or 1
	if speed <= 0 then return basePoint end

	local character = part:FindFirstAncestorOfClass("Model")
	local velocityPart = character and character:FindFirstChild("HumanoidRootPart") or part
	local rawVelocity = velocityPart:IsA("BasePart") and velocityPart.AssemblyLinearVelocity or Vector3.zero
	if rawVelocity.Magnitude > 150 then rawVelocity = rawVelocity.Unit * 150 end
	local now = os.clock()
	local sample = S.Runtime.VelocitySamples[velocityPart]
	local velocity = rawVelocity
	if sample then
		local alpha = 1 - math.exp(-math.clamp(now - sample.Time, 0, 0.25) * 10)
		velocity = sample.Velocity:Lerp(rawVelocity, alpha)
	end
	S.Runtime.VelocitySamples[velocityPart] = { Velocity = velocity, Time = now }

	if not S.Runtime.PingSeconds or now - (S.Runtime.PingUpdatedAt or 0) > 1 then
		local ok, value = pcall(function()
			local stats = game:GetService("Stats") :: any
			return stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
		end)
		S.Runtime.PingSeconds = ok and math.clamp(value, 0, 0.35) or 0
		S.Runtime.PingUpdatedAt = now
	end

	local gravity = globals and tonumber(globals.ProjectileGravity) or nil
	local pingLead = (S.Runtime.PingSeconds or 0) * 0.5
	local travelTime = math.clamp((basePoint - origin).Magnitude / speed, 0, 4)
	local point = basePoint
	for _ = 1, 4 do
		point = basePoint + velocity * (travelTime + pingLead) * S.SilentPredictionStrength
		if gravity then point -= Vector3.yAxis * gravity * travelTime * travelTime end
		travelTime = math.clamp((point - origin).Magnitude / speed, 0, 4)
	end
	return point
end

local function c_bt(orig, targ)
	task.spawn(function()
		if not tr_set.Enabled then return end
		if typeof(orig) ~= "Vector3" or typeof(targ) ~= "Vector3" then return end
		local d = (orig - targ).Magnitude
		if d < 1 then return end

		local tr = S.Runtime.TrackInstance(Instance.new("Part"))
		tr.Anchored, tr.CanCollide, tr.CanTouch, tr.CanQuery, tr.Massless, tr.CastShadow = true, false, false, false, true, false
		tr.Material, tr.Color, tr.Size = Enum.Material.ForceField, tr_set.Color, Vector3.new(tr_set.Thickness * 0.04, tr_set.Thickness * 0.04, d)
		tr.CFrame = CFrame.lookAt(orig, targ) * CFrame.new(0, 0, -d / 2)
		tr.Parent = cm

		local gl
		if tr_set.GlowIntensity > 0 then
			gl = S.Runtime.TrackInstance(Instance.new("Part"))
			gl.Anchored, gl.CanCollide, gl.CanTouch, gl.CanQuery, gl.Massless, gl.CastShadow = true, false, false, false, true, false
			gl.Material, gl.Color, gl.Size = Enum.Material.ForceField, tr_set.Color, Vector3.new(tr_set.Thickness * 0.08 * tr_set.GlowIntensity, tr_set.Thickness * 0.08 * tr_set.GlowIntensity, d)
			gl.CFrame, gl.Transparency = tr.CFrame, 0.5
			gl.Parent = cm
		end

		local lt_ = math.max(tr_set.Lifetime * 0.5, 0.1)
		local tw = ts:Create(tr, TweenInfo.new(lt_, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1, Size = Vector3.new(0, 0, d)
		})
		tw:Play()

		if gl then
			task.wait(lt_ * 0.3)
			local gl_tw = ts:Create(gl, TweenInfo.new(lt_ * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1, Size = Vector3.new(0, 0, d)
			})
			gl_tw:Play()
			task.wait(lt_ * 0.7)
			S.Runtime.DestroyTracked(gl)
		end

		task.wait(lt_ * 0.3)
		S.Runtime.DestroyTracked(tr)
	end)
end

function S.Runtime.FindNetworkEventTable(callback, eventName, seen, depth)
	if type(callback) ~= "function" or depth < 0 then return nil end
	seen = seen or {}
	if seen[callback] then return nil end
	seen[callback] = true
	for index = 1, 40 do
		local ok, value = pcall(gup, callback, index)
		if ok and type(value) == "table" and type(rawget(value, eventName)) == "function" then return value end
		if ok and type(value) == "function" then
			local found = S.Runtime.FindNetworkEventTable(value, eventName, seen, depth - 1)
			if found then return found end
		end
	end
	return nil
end

function S.Runtime.ObserveNetworkEvent(network, eventName, observer)
	local handlers = network and S.Runtime.FindNetworkEventTable(network.Add, eventName, nil, 2)
	if not handlers then return false end
	local original = handlers[eventName]
	local wrapper = function(...)
		S.Runtime.Try("Network." .. eventName, observer, ...)
		return original(...)
	end
	handlers[eventName] = wrapper
	S.Runtime.AddCleanup(function()
		if handlers[eventName] == wrapper then handlers[eventName] = original end
	end)
	return true
end

function S.Runtime.RemovePendingShot(shot)
	if shot.Key ~= nil and S.Runtime.PendingShotsByKey[shot.Key] == shot then
		S.Runtime.PendingShotsByKey[shot.Key] = nil
	end
	local index = table.find(S.Runtime.PendingShots, shot)
	if index then table.remove(S.Runtime.PendingShots, index) end
end

function S.Runtime.NotifyShot(hit, damage)
	if not S.HitNotifyEnabled or S.Runtime.Unloaded or not hit then return end
	local queue = S.Runtime.HitNotificationQueue
	local notice = { Hit = true, Damage = damage, ReadyAt = os.clock() + 0.08 }
	table.insert(queue, notice)
	while #queue > 12 do table.remove(queue, 1) end
	S.Runtime.SetWorker("HitNotify", rs.RenderStepped, S.Runtime.HitNotifyStep, true)
	return notice
end

function S.Runtime.FlushHitNotifications()
	if not S.HitNotifyEnabled or #S.Runtime.HitNotificationQueue == 0 then return end
	local notice = S.Runtime.HitNotificationQueue[1]
	if os.clock() < notice.ReadyAt then return end
	table.remove(S.Runtime.HitNotificationQueue, 1)
	Notif.new({
		Title = "Hit Notify",
		Content = type(notice.Damage) == "number" and ("Hit for %d damage"):format(math.floor(math.abs(notice.Damage))) or "Bullet hit an entity",
		Duration = 1.5,
	})
	if #S.Runtime.HitNotificationQueue == 0 then S.Runtime.SetWorker("HitNotify", rs.RenderStepped, S.Runtime.HitNotifyStep, false) end
end

function S.Runtime.RegisterPendingShot(serverTime, shotKey)
	if not S.HitNotifyEnabled or shotKey == nil then return end
	local previous = S.Runtime.PendingShotsByKey[shotKey]
	if previous then previous.Resolved = true; S.Runtime.RemovePendingShot(previous) end
	local shot: any = { ServerTime = serverTime, Key = shotKey, Created = os.clock(), Resolved = false }
	table.insert(S.Runtime.PendingShots, shot)
	S.Runtime.PendingShotsByKey[shotKey] = shot
	while #S.Runtime.PendingShots > 50 do
		local oldest = table.remove(S.Runtime.PendingShots, 1)
		if oldest.Key ~= nil and S.Runtime.PendingShotsByKey[oldest.Key] == oldest then S.Runtime.PendingShotsByKey[oldest.Key] = nil end
	end
	task.delay(4, function()
		if shot.Resolved then return end
		shot.Resolved = true
		S.Runtime.RemovePendingShot(shot)
	end)
end

function S.Runtime.FireAndRegister(nextFire, ...)
	local result = table.pack(nextFire(...))
	local shotKey = S.Runtime.GetCurrentShotKey and S.Runtime.GetCurrentShotKey()
	S.Runtime.RegisterPendingShot(result[1], shotKey)
	return table.unpack(result, 1, result.n)
end

function S.Runtime.ConfirmPendingHit(key, _, damage)
	if not S.HitNotifyEnabled then return end
	local now = os.clock()
	local shot = S.Runtime.PendingShotsByKey[key]
	if not shot then return end
	if shot.Confirmed then
		if shot.Notification and type(shot.Notification.Damage) == "number" and type(damage) == "number" then
			shot.Notification.Damage += damage
			shot.Notification.ReadyAt = now + 0.05
		end
		return
	end
	shot.Confirmed = true
	shot.Notification = S.Runtime.NotifyShot(true, damage)
	task.delay(0.2, function()
		shot.Resolved = true
		S.Runtime.RemovePendingShot(shot)
	end)
end

function S.Runtime.HitNotifyStep()
	S.Runtime.Try("HitNotify.Display", S.Runtime.FlushHitNotifications)
end

function S.Runtime.SetHitNotify(enabled)
	S.HitNotifyEnabled = enabled
	if not enabled then
		for _, shot in ipairs(S.Runtime.PendingShots) do shot.Resolved = true end
		table.clear(S.Runtime.PendingShots)
		table.clear(S.Runtime.PendingShotsByKey)
		table.clear(S.Runtime.HitNotificationQueue)
	end
	if not enabled then S.Runtime.SetWorker("HitNotify", rs.RenderStepped, S.Runtime.HitNotifyStep, false) end
end

local bul
pcall(function()
    local fw = (require :: any)(rf:WaitForChild("Framework"))
    if fw.WaitForLoaded then pcall(function() fw:WaitForLoaded() end) end
	S.Runtime.Framework = fw
	S.Runtime.PlayerClass = fw.Classes and fw.Classes.Players and fw.Classes.Players.get()
    bul = fw.Libraries and fw.Libraries.Bullets
end)
if not bul then
    pcall(function()
		local fw = (require :: any)(rf:WaitForChild("Framework"))
		local wr = gup(gup(fw.require, 1), 1)
		S.Runtime.Framework = fw
		S.Runtime.PlayerClass = fw.Classes and fw.Classes.Players and fw.Classes.Players.get()
		bul = wr.Libraries.Bullets
    end)
end

S.Runtime.HitNotifyAvailable = S.Runtime.ObserveNetworkEvent(
	S.Runtime.Framework and S.Runtime.Framework.Libraries and S.Runtime.Framework.Libraries.Network,
	"Bullet Damage",
	S.Runtime.ConfirmPendingHit
)

S.Runtime.SquadFilterAvailable = S.Runtime.ObserveNetworkEvent(
	S.Runtime.Framework and S.Runtime.Framework.Libraries and S.Runtime.Framework.Libraries.Network,
	"Squad Data Update",
	function(...)
		local payload
		for index = 1, select("#", ...) do
			local value = select(index, ...)
			if type(value) == "table" then payload = value; break end
		end
		if not payload then return end
		table.clear(S.Runtime.SquadMembers)
		for key, value in pairs(payload) do
			local userId = tonumber(key)
			if not userId and type(value) == "table" then userId = tonumber(value.UserId or value.Id) end
			if userId and userId ~= lp.UserId then S.Runtime.SquadMembers[userId] = true end
		end
	end
)

function S.Runtime.FunctionSignatureScore(callback, expectedNames, expectedConstants)
	if type(callback) ~= "function" then return -1 end
	local score = 0
	local okName, name = pcall((debug :: any).info, callback, "n")
	if okName and type(name) == "string" then
		for _, expected in ipairs(expectedNames) do
			if name:lower():find(expected, 1, true) then score += 8 end
		end
	end
	local getconstants = (debug :: any).getconstants
	if type(getconstants) == "function" then
		local okConstants, constants = pcall(getconstants, callback)
		if okConstants and type(constants) == "table" then
			for _, expected in ipairs(expectedConstants) do
				if table.find(constants, expected) then score += 1 end
			end
		end
	end
	return score
end

function S.Runtime.DiscoverFunctionUpvalue(owner, expectedNames, expectedConstants, minimumScore)
	local bestIndex, bestValue, bestScore = nil, nil, -1
	for index = 1, 40 do
		local ok, value = pcall(gup, owner, index)
		if not ok then break end
		if type(value) == "function" then
			local score = S.Runtime.FunctionSignatureScore(value, expectedNames, expectedConstants)
			if score > bestScore then bestIndex, bestValue, bestScore = index, value, score end
		end
	end
	if bestScore >= minimumScore then return bestIndex, bestValue end
	return nil, nil
end

if bul and bul.Fire then
	S.Runtime.BulletFireFunction = bul.Fire
	local spreadIndex, spreadFunction = S.Runtime.DiscoverFunctionUpvalue(
		S.Runtime.BulletFireFunction,
		{ "spreadvector", "spread" },
		{ "NextNumber", "CFrame", "new" },
		3
	)
	S.Runtime.SpreadUpvalueIndex = spreadIndex
	S.Runtime.OriginalSpreadFunction = spreadFunction
	if type(S.Runtime.OriginalSpreadFunction) == "function" then
		sup(S.Runtime.BulletFireFunction, spreadIndex, function(...)
			if S.Runtime.SilentShotDirection then
				return S.Runtime.SilentShotDirection
			end
			return S.Runtime.OriginalSpreadFunction(...)
		end)
		S.Runtime.AddCleanup(function()
			pcall(function() sup(S.Runtime.BulletFireFunction, spreadIndex, S.Runtime.OriginalSpreadFunction) end)
		end)
	end

	local recoilIndex, gFI = S.Runtime.DiscoverFunctionUpvalue(
		S.Runtime.BulletFireFunction,
		{ "fireimpulse", "impulse", "recoil" },
		{ "Vector2", "new" },
		2
	)
	S.Runtime.RecoilUpvalueIndex = recoilIndex
    if gFI then
		sup(S.Runtime.BulletFireFunction, recoilIndex, function(...)
            local im = {gFI(...)}
            if S.NoRecoilEnabled then
                for i = 1, #im do
                    im[i] = im[i] * S.RecoilScale
                end
            end
            return unpack(im)
		end)
		S.Runtime.AddCleanup(function()
			pcall(function() sup(S.Runtime.BulletFireFunction, recoilIndex, gFI) end)
		end)
    end

	for index = 1, 40 do
		local ok, value = pcall(gup, S.Runtime.BulletFireFunction, index)
		if not ok then break end
		if type(value) == "number" and value >= 0 and value < 420 and value % 1 == 0 then
			S.Runtime.BulletShotIdIndex = index
			break
		end
	end
	function S.Runtime.GetCurrentShotKey()
		local index = S.Runtime.BulletShotIdIndex
		if not index then return nil end
		local ok, value = pcall(gup, S.Runtime.BulletFireFunction, index)
		return ok and value or nil
	end

    S.Runtime.AddMethodHook(bul, "Fire", "Bullets.LocalPlayer", function(nextFire, w_, c_, a3, g_, orG, dr, ...)
        local args = table.pack(...)
		local playerClass = S.Runtime.PlayerClass
		if not playerClass or c_ ~= playerClass.Character then
			return nextFire(w_, c_, a3, g_, orG, dr, table.unpack(args, 1, args.n))
		end
		if S.aSE and type(g_) == "table" then
			g_ = table.clone(g_)
			g_.SuppressedByDefault = true
		end
		local silentDirection
		if S.SilentEnabled then
			local tg = gCP(S.SilentTargetType, S.SilentTargetHitbox, S.SilentMaxDistance, function(_, part)
				return S.WallbangEnabled or not S.SilentVisibilityCheck or S.BulletManipulation or S.Runtime.IsVisible(orG, part.Position, part)
			end)
            if tg and math.random(1, 100) <= S.SilentHitChance then
                local pt = tg:FindFirstChild(S.SilentTargetHitbox)
				if pt and pt:IsA("BasePart") and typeof(orG) == "Vector3" then
					local tP = S.Runtime.GetSilentAimPoint(pt, orG, g_)
					local visible = S.Runtime.IsVisible(orG, tP, pt)
					local offset = Vector3.zero
					if S.BulletManipulation and not visible then
						offset = gSO(orG, tP, S.BulletManipRadius, pt)
					end
					if S.SilentVisibilityCheck and not S.WallbangEnabled and not visible and offset.Magnitude <= 0.1 then
						return S.Runtime.FireAndRegister(nextFire, w_, c_, a3, g_, orG, dr, table.unpack(args, 1, args.n))
					end
					if offset.Magnitude > 0.1 then orG += offset end
					local aimVector = tP - orG
					if aimVector.Magnitude <= 0.001 then
						return S.Runtime.FireAndRegister(nextFire, w_, c_, a3, g_, orG, dr, table.unpack(args, 1, args.n))
					end
					dr = aimVector.Unit
					if S.SilentNoSpread then silentDirection = dr end
                    S.lastSilentOrigin = orG
                    S.lastSilentDir = dr
                end
            end
        end

        if tr_set.Enabled then
            local fo = orG
            if not fo then
                local t = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
                local h = t and (t:FindFirstChild("Muzzle") or t:FindFirstChild("FirePart") or t:FindFirstChild("Handle") or t:FindFirstChildOfClass("BasePart"))
                fo = h and h.Position or cm.CFrame.Position
            end
            if typeof(dr) == "Vector3" then
                c_bt(fo, fo + dr.Unit * 2000)
            end
        end

		if silentDirection then
			S.Runtime.SilentShotDirection = silentDirection
			local result = table.pack(pcall(nextFire, w_, c_, a3, g_, orG, dr, table.unpack(args, 1, args.n)))
			S.Runtime.SilentShotDirection = nil
			if not result[1] then error(result[2], 0) end
			S.Runtime.RegisterPendingShot(result[2], S.Runtime.GetCurrentShotKey())
			return table.unpack(result, 2, result.n)
		end

		return S.Runtime.FireAndRegister(nextFire, w_, c_, a3, g_, orG, dr, table.unpack(args, 1, args.n))
    end)
end

S.Runtime.Connect(ui.InputBegan, function(ip)
    if ip.UserInputType == S.AimbotHoldKey then Hld = true; if S.Runtime.UpdateCombatWorker then S.Runtime.UpdateCombatWorker() end end
end)
S.Runtime.Connect(ui.InputEnded, function(ip)
    if ip.UserInputType == S.AimbotHoldKey then Hld = false; if S.Runtime.UpdateCombatWorker then S.Runtime.UpdateCombatWorker() end end
end)

en.CombatTargetElapsed = math.huge
en.CombatTarget = nil
function S.Runtime.CombatRenderStep(deltaTime)
    S.Runtime.Try("Combat.Render", function()
        uF()
		if not S.AimbotEnabled and not S.SnapLine then
			en.CombatTarget = nil
			en.CombatTargetElapsed = math.huge
			SL.Visible = false
			SO.Visible = false
			return
		end
        
		en.CombatTargetElapsed += deltaTime
		local searchInterval = S.PerformanceMode and (1 / 20) or 0
		if en.CombatTargetElapsed >= searchInterval then
			en.CombatTargetElapsed = 0
			en.CombatTarget = gCP(S.AimbotTargetType, S.AimbotTargetHitbox, S.AimbotMaxDistance)
		end
		local tg = en.CombatTarget
        if not tg or not tg:FindFirstChild(S.AimbotTargetHitbox) then
            SL.Visible = false
            SO.Visible = false
            return
        end
        
        local pt = tg[S.AimbotTargetHitbox]
        local pos, oS = cm:WorldToViewportPoint(pt.Position)
        if not oS then return end

        if S.SnapLine then
            local fr = Vector2.new(cm.ViewportSize.X/2, cm.ViewportSize.Y/2)
            local to = Vector2.new(pos.X, pos.Y)
            if S.SnapLineOutline then
                SO.Visible = true
                SO.From = fr
                SO.To = to
                SO.Color = Color3.fromRGB(0,0,0)
                SO.Thickness = S.SnapLineThickness + 3
                SO.Transparency = S.SnapLineOutlineTransparency
                SO.ZIndex = -10
            else
                SO.Visible = false
            end
            SL.Visible = true
            SL.From = fr
            SL.To = to
            SL.Color = S.SnapLineColor
            SL.Thickness = S.SnapLineThickness
            SL.Transparency = 1
            SL.ZIndex = 10
        else
            SL.Visible = false
            SO.Visible = false
        end

        if S.AimbotEnabled and Hld then
            mMT(pos)
        end
    end)
end

function S.Runtime.UpdateCombatWorker()
	local active = S.FOVEnabled or S.SnapLine or (S.AimbotEnabled and Hld)
	if not active then
		FC.Visible, FO.Visible, SL.Visible, SO.Visible = false, false, false, false
		en.CombatTarget = nil
	else
		en.CombatTargetElapsed = math.huge
	end
	S.Runtime.SetWorker("Combat", rs.RenderStepped, S.Runtime.CombatRenderStep, active)
end

local VehiclesTab
local ZombiesTab

do
    local Combat = win:AddTab({ Name = "Combat" })
	S.CombatTab = Combat
    local SilentAimSection = Combat:AddSection({ Name = "SILENT AIM" })
    S.AimbotSection = Combat:AddSection({ Name = "AIMBOT" })
    local GunModsSection = Combat:AddSection({ Name = "GUN MODS" })
    local FOVSection = Combat:AddSection({ Name = "TARGETING FOV", Position = 'right' })
    local SnapLineSection = Combat:AddSection({ Name = "TARGET SNAP LINE", Position = 'right' })
    local hbesection = Combat:AddSection({ Name = "HITBOX EXPANDER", Position = 'right' })
	local AimFiltersSection = Combat:AddSection({ Name = "AIM FILTERS", Position = 'right' })

    SilentAimSection:AddLabel('Silent Aim'):AddToggle({
        Default = false,
        Flag = "SilentAim",
        Callback = function(v) S.SilentEnabled = v end
    })

    SilentAimSection:AddLabel('Visibility Check'):AddToggle({
        Default = false,
        Flag = "SilentVisibilityCheck",
        Callback = function(v) S.SilentVisibilityCheck = v end
    })

	local predictionToggle = SilentAimSection:AddLabel('Movement Prediction')
	predictionToggle:AddToggle({
		Default = true,
		Flag = "SilentPrediction",
		Callback = function(v) S.SilentPrediction = v end
	})
	predictionToggle:AddOption():AddLabel('Prediction Strength'):AddSlider({
		Min = 0,
		Max = 1.5,
		Default = 1,
		Rounding = 2,
		Flag = "SilentPredictionStrength",
		Callback = function(v) S.SilentPredictionStrength = v end
	})

	SilentAimSection:AddLabel('Shot Accuracy'):AddToggle({
		Default = true,
		Flag = "SilentNoSpread",
		Callback = function(v) S.SilentNoSpread = v end
	})

    local BulletManipToggle = SilentAimSection:AddLabel('Bullet Manipulation')
    BulletManipToggle:AddToggle({
        Default = false,
        Flag = "BulletManipulation",
        Callback = function(v) S.BulletManipulation = v end
    })

    local BulletManipOptions = BulletManipToggle:AddOption()
    BulletManipOptions:AddLabel('Max Offset'):AddSlider({
        Min = 1,
        Max = 8,
        Default = 6,
        Flag = "BulletManipRadius",
        Callback = function(v) S.BulletManipRadius = v end
    })

    BulletManipOptions:AddLabel('Max Forward'):AddSlider({
        Min = 0,
        Max = 5,
        Default = 3,
        Flag = "MaxForward",
        Callback = function(v) S.MaxForward = v end
    })

    BulletManipOptions:AddLabel('Max Walls'):AddSlider({
        Min = 0,
        Max = 5,
        Default = 2,
        Flag = "MaxWalls",
        Callback = function(v) S.MaxWalls = v end
    })

    BulletManipOptions:AddLabel('Window Aware'):AddToggle({
        Default = true,
        Flag = "WindowAware",
        Callback = function(v) S.WindowAware = v end
    })

    BulletManipOptions:AddLabel('Obstruction Fallback'):AddToggle({
        Default = true,
        Flag = "ObstructionFallback",
        Callback = function(v) S.ObstructionFallback = v end
    })

    SilentAimSection:AddLabel('Hit Chance'):AddSlider({
        Min = 1,
        Max = 100,
        Default = 100,
        Flag = "SilentHitChance",
        Callback = function(v) S.SilentHitChance = v end
    })

    SilentAimSection:AddLabel('Max Distance'):AddSlider({
        Min = 100,
        Max = 3000,
        Default = 2000,
        Flag = "SilentDistance",
        Callback = function(v) S.SilentMaxDistance = v end
    })

    SilentAimSection:AddLabel('Target Type'):AddDropdown({
        Default = 'Closest To Mouse',
		Values = {'Closest To Mouse', 'Closest To Player', 'Lowest Health'},
        Flag = "SilentType",
        Callback = function(v) S.SilentTargetType = v end
    })

    SilentAimSection:AddLabel('Hitbox'):AddDropdown({
        Default = 'Head',
        Values = {'Head','HumanoidRootPart','UpperTorso','LowerTorso'},
        Flag = "SilentHitbox",
        Callback = function(v) S.SilentTargetHitbox = v end
    })

    local fovToggle = FOVSection:AddLabel('FOV Circle')
    fovToggle:AddToggle({
        Default = false,
        Flag = "RageFOV",
        Callback = function(v) S.FOVEnabled = v; S.Runtime.UpdateCombatWorker() end
    })
    fovToggle:AddOption():AddLabel('FOV Color'):AddColorPicker({
        Default = S.FOVColor,
        Flag = "RageFOVColor",
        Callback = function(v) S.FOVColor = v end
    })

    FOVSection:AddLabel('FOV Outline'):AddToggle({
        Default = false,
        Flag = "RageFOVOutline",
        Callback = function(v) S.FOVOutline = v end
    })

    FOVSection:AddLabel('FOV Radius'):AddSlider({
        Min = 50,
        Max = 500,
        Default = 150,
        Flag = "RageFOVRadius",
        Callback = function(v) S.FOVRadius = v end
    })

    FOVSection:AddLabel('FOV Thickness'):AddSlider({
        Min = 1,
        Max = 5,
        Default = 2,
        Flag = "RageFOVThickness",
        Callback = function(v) S.FOVThickness = v end
    })

    local snapToggle = SnapLineSection:AddLabel('Snap Line')
    snapToggle:AddToggle({
        Default = false,
        Flag = "RageSnapLine",
        Callback = function(v) S.SnapLine = v; S.Runtime.UpdateCombatWorker() end
    })
    snapToggle:AddOption():AddLabel('Snap Color'):AddColorPicker({
        Default = S.SnapLineColor,
        Flag = "RageSnapColor",
        Callback = function(v) S.SnapLineColor = v end
    })

    SnapLineSection:AddLabel('Snap Outline'):AddToggle({
        Default = false,
        Flag = "RageSnapOutline",
        Callback = function(v) S.SnapLineOutline = v end
    })

    SnapLineSection:AddLabel('Snap Thickness'):AddSlider({
        Min = 1,
        Max = 5,
        Default = 2,
        Flag = "RageSnapThickness",
        Callback = function(v) S.SnapLineThickness = v end
    })

    hbesection:AddLabel('Hitbox Expander'):AddToggle({
        Default = false,
        Flag = "HitboxEnabled",
        Callback = S.Runtime.SetHitboxEnabled
    })

    hbesection:AddLabel('Hitbox Size'):AddSlider({
        Default = 5,
        Min = 2,
        Max = 5,
        Rounding = 1,
        Flag = "HitboxSize",
        Callback = function(v) S.HitboxSize = v; S.Runtime.RefreshHitboxes() end
    })

    hbesection:AddLabel('Hitbox Transparency'):AddSlider({
        Default = 0.8,
        Min = 0,
        Max = 1,
        Rounding = 2,
        Flag = "HitboxTrans",
        Callback = function(v) S.HitboxTrans = v; S.Runtime.RefreshHitboxes() end
    })

	AimFiltersSection:AddLabel('Ignore Squad'):AddToggle({
		Default = true, Flag = "AimIgnoreSquad",
		Callback = function(v) S.AimIgnoreSquad = v end,
	})
	AimFiltersSection:AddLabel('Ignore Friends'):AddToggle({
		Default = false, Flag = "AimIgnoreFriends",
		Callback = function(v) S.AimIgnoreFriends = v end,
	})
	AimFiltersSection:AddLabel('Visible Only'):AddToggle({
		Default = false, Flag = "AimVisibleOnly",
		Callback = function(v) S.AimVisibleOnly = v end,
	})

    local noRecoilToggle = GunModsSection:AddLabel('No Recoil')
    noRecoilToggle:AddToggle({
        Default = false,
        Flag = "NoRecoil",
        Callback = function(v) S.NoRecoilEnabled = v end
    })
    local recoilOptions = noRecoilToggle:AddOption()
    recoilOptions:AddLabel('Recoil Control'):AddSlider({
        Min = 1,
        Max = 100,
        Default = 10,
        Flag = "RecoilControl",
        Callback = function(v) S.RecoilScale = v / 100 end
    })

	do
		local Raycasting
		pcall(function()
			local Framework = (require :: any)(rf:WaitForChild("Framework"))
			Raycasting = Framework.require("Libraries", "Raycasting")
			pcall(function() S.Runtime.ProjectileGlobals = Framework.require("Configs", "Globals") end)
			pcall(function() S.Runtime.Entities = Framework.require("Libraries", "Entities") end)
		end)

		if Raycasting and type(Raycasting.BulletCastLight) == "function" then
			local oldBulletCastLight = Raycasting.BulletCastLight
			local projectileGlobals = S.Runtime.ProjectileGlobals
			local replicatedGlobals = game:GetService("ReplicatedStorage"):FindFirstChild("Globals")
			local shotMaxDistanceValue = replicatedGlobals and replicatedGlobals:FindFirstChild("ShotMaxDistance")
			local originalShotMaxDistance = tonumber(shotMaxDistanceValue and shotMaxDistanceValue.Value)
				or tonumber(projectileGlobals and projectileGlobals.ShotMaxDistance)
				or 2000
			S.Runtime.Raycasting = Raycasting
			S.Runtime.BulletCastLight = oldBulletCastLight

			local function applyProjectileRange()
				if not projectileGlobals then return end
				projectileGlobals.ShotMaxDistance = S.WallbangEnabled
					and math.max(originalShotMaxDistance, 10000)
					or originalShotMaxDistance
			end
			local function cleanList(list)
				local cleaned = {}
				local seen = {}
				if type(list) == "table" then
					for _, instance in ipairs(list) do
						if typeof(instance) == "Instance" and instance.Parent and not seen[instance] then
							seen[instance] = true
							table.insert(cleaned, instance)
						end
					end
				end
				return cleaned, seen
			end

			local function isWallbangTarget(instance)
				return Raycasting:IsHitCharacter(instance)
					or Raycasting:IsHitZombie(instance)
					or Raycasting:IsHitVehicle(instance)
			end

			local function skipWallbangObstruction(instance)
				if isWallbangTarget(instance) then return false end
				local model = instance:FindFirstAncestorOfClass("Model")
				if model and not isWallbangTarget(model) then return true, model end
				return true, instance
			end

			S.Runtime.AddMethodHook(Raycasting, "BulletCastLight", "Raycasting.Wallbang", function(nextCast, self, ray, ignoreList, ...)
				if not S.WallbangEnabled or typeof(ray) ~= "Ray" then
					return nextCast(self, ray, ignoreList, ...)
				end

				local excludeList, seen = cleanList(ignoreList)
				if lp.Character and lp.Character.Parent and not seen[lp.Character] then
					seen[lp.Character] = true
					table.insert(excludeList, lp.Character)
				end

				local mapFolder = ws:FindFirstChild("Map")
				if mapFolder and not seen[mapFolder] then
					seen[mapFolder] = true
					table.insert(excludeList, mapFolder)
				end
				if ws.Terrain and not seen[ws.Terrain] then
					seen[ws.Terrain] = true
					table.insert(excludeList, ws.Terrain)
				end
				local corpses = ws:FindFirstChild("Corpses")
				if corpses and not seen[corpses] then
					table.insert(excludeList, corpses)
				end

				if type(Raycasting.CastWithIgnoreList) == "function" then
					return Raycasting.CastWithIgnoreList(self, ray, excludeList, skipWallbangObstruction)
				end
				return nextCast(self, ray, excludeList, ...)
			end)

			local function setWallbang(enabled)
				S.WallbangEnabled = enabled == true
				applyProjectileRange()
			end

			GunModsSection:AddLabel('Wallbang'):AddToggle({
				Default = false,
				Flag = "Wallbang",
				Callback = setWallbang,
			})

			S.Runtime.AddCleanup(function()
				S.WallbangEnabled = false
				if projectileGlobals then
					projectileGlobals.ShotMaxDistance = originalShotMaxDistance
				end
			end)
		else
			GunModsSection:AddLabel('Wallbang unavailable')
		end
	end

	do
		local framework = S.Runtime.Framework or (require :: any)(rf:WaitForChild("Framework"))
		local pendingReloads = {}

		local function cancelReloadAnimation()
			local playersClass = framework.Classes and framework.Classes.Players
			local playerObject = playersClass and playersClass.get and playersClass.get()
			local character = playerObject and playerObject.Character
			local animator = character and character.Animator
			if animator and type(animator.RunAction) == "function" then
				animator:RunAction("Stop Firearm Reload", "Manual")
			end
		end

		S.Runtime.AddMethodHook(framework.Libraries.Network, "Send", "Network.InstantReload", function(nextSend, self, eventName, ...)
			local firearmId = select(1, ...)
			local ammoId = select(2, ...)
			if S.instantReloadEnabled and eventName == "Character Reload Firearm Initiated"
				and type(firearmId) == "string" and type(ammoId) == "string" then
				local result = table.pack(nextSend(self, eventName, ...))
				local token = { AmmoId = ammoId, Expires = os.clock() + 6 }
				pendingReloads[firearmId] = token
				task.defer(function()
					if S.Runtime.Unloaded or not S.instantReloadEnabled or pendingReloads[firearmId] ~= token then return end
					nextSend(self, "Character Reload Firearm Committed", firearmId, ammoId)
					S.Runtime.Try("InstantReload.Animation", cancelReloadAnimation)
					task.wait()
					nextSend(self, "Character Reload Firearm Clear", firearmId)
				end)
				task.delay(6, function()
					if pendingReloads[firearmId] == token then pendingReloads[firearmId] = nil end
				end)
				return table.unpack(result, 1, result.n)
			end

			local pending = type(firearmId) == "string" and pendingReloads[firearmId]
			if pending and S.instantReloadEnabled and pending.Expires > os.clock() then
				if eventName == "Character Reload Firearm Committed" and ammoId == pending.AmmoId then
					return
				elseif eventName == "Character Reload Firearm Clear" then
					return
				end
			end

			return nextSend(self, eventName, ...)
		end)

		GunModsSection:AddLabel('Instant Reload'):AddToggle({
			Default = false,
			Flag = "InstantReload",
			Callback = function(enabled) S.instantReloadEnabled = enabled end,
		})

		S.Runtime.AddCleanup(function()
			S.instantReloadEnabled = false
			table.clear(pendingReloads)
		end)
    end

    do
        local fw = (require :: any)(rf:WaitForChild("Framework"))
        local PC = fw["Classes"]["Players"]["get"]()
        local RK = Enum.KeyCode.R
        local iR = false
		local generation = 0

        local function dR()
            if iR then return end
            iR = true
            local VI = game:GetService("VirtualInputManager")
            VI:SendKeyEvent(true, RK, false, game)
            task.wait(0.05)
            VI:SendKeyEvent(false, RK, false, game)
            task.wait(S.instantReloadEnabled and 0.15 or 2.5)
            iR = false
        end

        local function cA()
            if not S.autoReloadEnabled then return end
            local ch_ = PC["Character"]
            if not ch_ then return end
            local eq = ch_["EquippedItem"]
            if not eq or not eq["__item"] then return end
            local am = eq["__item"]["Attachments"]["Ammo"]
            if not am then return end
            local cAm = am["__item"]["WorkingAmount"]
            if cAm == 0 and not iR then
                dR()
            end
        end

		local function setAutoReload(enabled)
			S.autoReloadEnabled = enabled
			generation += 1
			if not enabled then return end
			local currentGeneration = generation
			task.spawn(function()
				while S.autoReloadEnabled and generation == currentGeneration and not S.Runtime.Unloaded do
					S.Runtime.Try("AutoReload", cA)
					task.wait(S.PerformanceMode and 0.3 or 0.15)
				end
			end)
		end

		GunModsSection:AddLabel('Auto Reload'):AddToggle({
			Default = false,
			Flag = "AutoReload",
			Callback = setAutoReload,
		})

		S.Runtime.AddCleanup(function() setAutoReload(false) end)
	end

    GunModsSection:AddLabel('Always Suppressed'):AddToggle({
        Default = false,
        Flag = "AlwaysSuppressed",
        Callback = function(v) S.aSE = v end
    })

    local previousAntiFlinch = getgenv().antiFlinch
    getgenv().antiFlinch = false
    local Gl = nil
    if type(filtergc) == "function" then
		local found, result = pcall(filtergc :: any, "table", {
            Keys = { "GlobalFlinchMod" },
        }, true)
        if found and type(result) == "table" then Gl = result end
    end

    local previousFlinchMod = Gl and Gl.GlobalFlinchMod or nil

    local function sAF(st)
        getgenv().antiFlinch = st
        if Gl then
            Gl.GlobalFlinchMod = st and 0 or 1
        end
    end

    GunModsSection:AddLabel('Anti Flinch'):AddToggle({
        Default = false,
        Flag = "AntiFlinch",
        Callback = function(v) 
            sAF(v) 
        end
    })

	S.Runtime.AddCleanup(function()
		getgenv().antiFlinch = previousAntiFlinch
		if Gl then Gl.GlobalFlinchMod = previousFlinchMod end
	end)
end

do
    local AimbotSection = S.AimbotSection

    AimbotSection:AddLabel('Aim Bot'):AddToggle({
        Default = false,
        Flag = "Aimbot",
        Callback = function(v) S.AimbotEnabled = v; S.Runtime.UpdateCombatWorker() end
    })

    AimbotSection:AddLabel('Smoothness'):AddSlider({
        Min = 0.1,
        Max = 2,
        Default = 0.5,
        Flag = "AimbotSmooth",
        Callback = function(v) S.AimbotSmoothing = v end
    })

    AimbotSection:AddLabel('Max Distance'):AddSlider({
        Min = 100,
        Max = 3000,
        Default = 1500,
        Flag = "AimbotDistance",
        Callback = function(v) S.AimbotMaxDistance = v end
    })

    AimbotSection:AddLabel('Target Type'):AddDropdown({
        Default = 'Closest To Mouse',
        Values = {'Closest To Mouse', 'Closest To Player', 'Lowest Health'},
        Flag = "AimbotType",
        Callback = function(v) S.AimbotTargetType = v end
    })

    AimbotSection:AddLabel('Hitbox'):AddDropdown({
        Default = 'Head',
        Values = {'Head','HumanoidRootPart','UpperTorso','LowerTorso'},
        Flag = "AimbotHitbox",
        Callback = function(v) S.AimbotTargetHitbox = v end
    })
end

do
    local Esp = win:AddTab({ Name = "Visual" })
    local s1 = Esp:AddSection({ Name = "PLAYER ESP" })
	local s2 = Esp:AddSection({ Name = "CHAMS" })
	S.VisualChamsSection = s2
    S.VisualCrosshairSection = Esp:AddSection({ Name = "CUSTOM CROSSHAIR" })
    local s3 = Esp:AddSection({ Name = "CORPSE ESP", Position = 'right' })
    local s6 = Esp:AddSection({ Name = "LOOT ESP", Position = 'right' })
    S.VisualBulletTracerSection = Esp:AddSection({ Name = "BULLET TRACER", Position = 'right' })
	if S.Runtime.HitNotifyAvailable then
		Esp:AddSection({ Name = "HIT FEEDBACK", Position = 'right' }):AddLabel('Hit Notify'):AddToggle({
			Default = false,
			Flag = "HitNotify",
			Callback = S.Runtime.SetHitNotify,
		})
	end

    VehiclesTab = win:AddTab({ Name = "Vehicles" })
    local s4 = VehiclesTab:AddSection({ Name = "VEHICLE ESP" })

    ZombiesTab = win:AddTab({ Name = "Zombies" })
    local s5 = ZombiesTab:AddSection({ Name = "ZOMBIE ESP" })

    local e_t = s1:AddLabel('Enable ESP')
    e_t:AddToggle({
        Default = false, Flag = "enable esp",
        Callback = function(v)
			ec.Enabled = v
			S.Runtime.UpdatePlayerEspWorker()
			S.Runtime.UpdateEntityDiscoveryWorker()
		end
    })

    local b_t = s1:AddLabel('Box')
    b_t:AddToggle({
        Default = false, Flag = "box",
        Callback = function(v) ec.Box = v end
    })
    local b_o = b_t:AddOption()
    b_o:AddLabel('Box Color'):AddColorPicker({
        Default = eo.BoxMain, Flag = "color box",
        Callback = function(v)
            eo.BoxMain = v
            for _, esp in pairs(ea) do
                if esp.MainStroke then esp.MainStroke.Color = v end
            end
        end
    })
    b_o:AddLabel('Fill Box'):AddToggle({
        Default = ec.FillBox, Flag = "fill box",
        Callback = function(v) ec.FillBox = v end
    })
    b_o:AddLabel('Fill Color'):AddColorPicker({
        Default = eo.FillBox, Flag = "color fill box",
        Callback = function(v)
            eo.FillBox = v
            for _, esp in pairs(ea) do
                if esp.FillBox then esp.FillBox.BackgroundColor3 = v end
            end
        end
    })

    local h_t = s1:AddLabel('Health Bar')
    h_t:AddToggle({
        Default = false, Flag = "box bar",
        Callback = function(v) ec.HPBar = v end
    })
    local h_o = h_t:AddOption()
    h_o:AddLabel('Low Health Color'):AddColorPicker({
        Default = eo.HealthGradientStart, Flag = "color hp full",
        Callback = function(v)
            eo.HealthGradientStart = v
            for _, esp in pairs(ea) do
                if esp.UpdateGradient then esp.UpdateGradient() end
            end
        end
    })
    h_o:AddLabel('Mid Health Color'):AddColorPicker({
        Default = eo.HealthGradientMid, Flag = "color hp full",
        Callback = function(v)
            eo.HealthGradientMid = v
            for _, esp in pairs(ea) do
                if esp.UpdateGradient then esp.UpdateGradient() end
            end
        end
    })
    h_o:AddLabel('Full Health Color'):AddColorPicker({
        Default = eo.HealthGradientEnd, Flag = "color hp low",
        Callback = function(v)
            eo.HealthGradientEnd = v
            for _, esp in pairs(ea) do
                if esp.UpdateGradient then esp.UpdateGradient() end
            end
        end
    })
    h_o:AddLabel('Health Number'):AddToggle({
        Default = ec.HPText, Flag = "box number hear",
        Callback = function(v) ec.HPText = v end
    })

    local n_t = s1:AddLabel('Show Name')
    n_t:AddToggle({
        Default = false, Flag = "box name",
        Callback = function(v) ec.Name = v end
    })
    local n_o = n_t:AddOption()
    n_o:AddLabel('Name Color'):AddColorPicker({
        Default = eo.Name, Flag = "color name",
        Callback = function(v)
            eo.Name = v
            for _, esp in pairs(ea) do
                if esp.NameLabel then esp.NameLabel.TextColor3 = v end
            end
        end
    })
    n_o:AddLabel('Use Display Name'):AddToggle({
        Default = ec.UseDisplayName, Flag = "use display name",
        Callback = function(v) ec.UseDisplayName = v end
    })

    local d_t = s1:AddLabel('Distance')
    d_t:AddToggle({
        Default = false, Flag = "box discr",
        Callback = function(v) ec.Distance = v end
    })
    local d_o = d_t:AddOption()
    d_o:AddLabel('Distance Color'):AddColorPicker({
        Default = eo.Distance, Flag = "distance",
        Callback = function(v)
            eo.Distance = v
            for _, esp in pairs(ea) do
                if esp.DistanceLabel then esp.DistanceLabel.TextColor3 = v end
            end
        end
    })
    d_o:AddLabel('Metric'):AddDropdown({
        Default = ec.Metric, Values = {'Studs', 'Meters'}, Flag = "metric",
        Callback = function(v) ec.Metric = v end
    })
    d_o:AddLabel('Distance Check'):AddSlider({
        Min = 1000, Max = 10000, Default = ec.MaxDistance, Flag = "dis chek",
        Callback = function(v) ec.MaxDistance = v end
    })

    local i_t = s1:AddLabel('Equipped Item')
    i_t:AddToggle({
        Default = false, Flag = "box item",
        Callback = function(v) ec.WeaponName = v end
    })
    i_t:AddOption():AddLabel('Item Color'):AddColorPicker({
        Default = eo.WeaponName, Flag = "color item",
        Callback = function(v)
            eo.WeaponName = v
            for _, esp in pairs(ea) do
                if esp.ToolLabel then esp.ToolLabel.TextColor3 = v end
            end
        end
    })

    local c_t = s2:AddLabel('Player Chams')
    c_t:AddToggle({
        Default = false, Flag = "ChamsToggle",
        Callback = function(v)
            ch.Enabled = v
            for _, h in ipairs(h_s:GetChildren()) do h.Enabled = v end
			S.Runtime.UpdateEntityDiscoveryWorker()
        end
    })
    local c_o = c_t:AddOption()
    c_o:AddLabel('Fill Color'):AddColorPicker({
        Default = ch.FillColor, Flag = "ChamsFillColor",
        Callback = function(v)
            ch.FillColor = v
            for _, h in ipairs(h_s:GetChildren()) do h.FillColor = v end
        end
    })
    c_o:AddLabel('Outline Color'):AddColorPicker({
        Default = ch.OutlineColor, Flag = "ChamsOutlineColor",
        Callback = function(v)
            ch.OutlineColor = v
            for _, h in ipairs(h_s:GetChildren()) do h.OutlineColor = v end
        end
    })

    s2:AddLabel('Fill Transparency'):AddSlider({
        Min = 0, Max = 20, Default = 10, Flag = "FillTransparency",
        Callback = function(v)
            ch.FillTransparency = v
            local tr = t_tr(v)
            for _, h in ipairs(h_s:GetChildren()) do h.FillTransparency = tr end
        end
    })

    s2:AddLabel('Outline Transparency'):AddSlider({
        Min = 0, Max = 20, Default = 10, Flag = "OutlineTransparency",
        Callback = function(v)
            ch.OutlineTransparency = v
            local tr = t_tr(v)
            for _, h in ipairs(h_s:GetChildren()) do h.OutlineTransparency = tr end
        end
    })

    local cp_t = s3:AddLabel('Corpse ESP')
    cp_t:AddToggle({
        Default = false, Flag = "CorpseESP",
        Callback = function(v)
            cs.enabled = v
            u_ces()
			S.Runtime.UpdateCorpseEspWorker()
			S.Runtime.UpdateEntityDiscoveryWorker()
        end
    })

    local cpn_t = s3:AddLabel('Show Corpse Name')
    cpn_t:AddToggle({
        Default = false, Flag = "CorpseName",
        Callback = function(v)
            cs.showNames = v
            u_ces()
        end
    })
    cpn_t:AddOption():AddLabel('Name Color'):AddColorPicker({
        Default = cs.nameColor, Flag = "CorpseNameColor",
        Callback = function(v)
            cs.nameColor = v
            if not cf_ then return end
            for _, corpse in pairs(cf_:GetChildren()) do
                local eg_ = corpse:FindFirstChild("CorpseESP")
                if eg_ then
                    local label = eg_:FindFirstChild("CorpseName")
                    if label then label.TextColor3 = v end
                end
            end
        end
    })

    local cpd_t = s3:AddLabel('Show Distance')
    cpd_t:AddToggle({
        Default = false, Flag = "CorpseDistance",
        Callback = function(v)
            cs.showDistance = v
            u_ces()
        end
    })
    cpd_t:AddOption():AddLabel('Distance Color'):AddColorPicker({
        Default = cs.distanceColor, Flag = "CorpseDistanceColor",
        Callback = function(v)
            cs.distanceColor = v
            if not cf_ then return end
            for _, corpse in pairs(cf_:GetChildren()) do
                local eg_ = corpse:FindFirstChild("CorpseESP")
                if eg_ then
                    local label = eg_:FindFirstChild("CorpseDistance")
                    if label then label.TextColor3 = v end
                end
            end
        end
    })

    s3:AddLabel('Max Distance'):AddSlider({
        Min = 1000, Max = 20000, Default = 10000, Rounding = 1, Flag = "CorpseMaxDistance",
        Callback = function(v) cs.maxDistance = v end
    })

    local v_t = s4:AddLabel('Vehicle ESP')
    v_t:AddToggle({
        Default = false, Flag = "VehicleESP",
        Callback = function(v)
            vs.enabled = v
            u_vhe()
			S.Runtime.UpdateVehicleEspWorker()
			S.Runtime.UpdateEntityDiscoveryWorker()
        end
    })

    local vn_t = s4:AddLabel('Show Names')
    vn_t:AddToggle({
        Default = false, Flag = "VehicleName",
        Callback = function(v)
            vs.showNames = v
            u_vhe()
			S.Runtime.UpdateVehicleEspWorker()
			S.Runtime.UpdateEntityDiscoveryWorker()
        end
    })
    vn_t:AddOption():AddLabel('Name Color'):AddColorPicker({
        Default = vs.nameColor, Flag = "VehicleNameColor",
        Callback = function(v)
            vs.nameColor = v
            for _, data in pairs(ev) do
                if data.nameLabel then data.nameLabel.TextColor3 = v end
            end
        end
    })

    local vd_t = s4:AddLabel('Show Distance')
    vd_t:AddToggle({
        Default = false, Flag = "VehicleDistance",
        Callback = function(v)
            vs.showDistance = v
            u_vhe()
			S.Runtime.UpdateVehicleEspWorker()
			S.Runtime.UpdateEntityDiscoveryWorker()
        end
    })
    vd_t:AddOption():AddLabel('Distance Color'):AddColorPicker({
        Default = vs.distanceColor, Flag = "VehicleDistanceColor",
        Callback = function(v)
            vs.distanceColor = v
            for _, data in pairs(ev) do
                if data.distanceLabel then data.distanceLabel.TextColor3 = v end
            end
        end
    })

    s4:AddLabel('Max Distance'):AddSlider({
        Min = 1000, Max = 20000, Default = 10000, Rounding = 1, Flag = "VehicleMaxDistance",
        Callback = function(v) vs.maxDistance = v end
    })

    local z_t = s5:AddLabel('Zombie ESP')
    z_t:AddToggle({
        Default = false, Flag = "ZombieESP",
        Callback = function(v)
            zs.enabled = v
            u_zbe()
			S.Runtime.UpdateZombieEspWorker()
			S.Runtime.UpdateEntityDiscoveryWorker()
        end
    })

    local zn_t = s5:AddLabel('Show Names')
    zn_t:AddToggle({
        Default = false, Flag = "ZombieName",
        Callback = function(v)
            zs.showNames = v
            u_zbe()
			S.Runtime.UpdateZombieEspWorker()
			S.Runtime.UpdateEntityDiscoveryWorker()
        end
    })
    zn_t:AddOption():AddLabel('Name Color'):AddColorPicker({
        Default = zs.nameColor, Flag = "ZombieNameColor",
        Callback = function(v)
            zs.nameColor = v
            for _, data in pairs(ez) do
                if data.nameLabel then data.nameLabel.TextColor3 = v end
            end
        end
    })

    local zd_t = s5:AddLabel('Show Distance')
    zd_t:AddToggle({
        Default = false, Flag = "ZombieDistance",
        Callback = function(v)
            zs.showDistance = v
            u_zbe()
			S.Runtime.UpdateZombieEspWorker()
			S.Runtime.UpdateEntityDiscoveryWorker()
        end
    })
    zd_t:AddOption():AddLabel('Distance Color'):AddColorPicker({
        Default = zs.distanceColor, Flag = "ZombieDistanceColor",
        Callback = function(v)
            zs.distanceColor = v
            for _, data in pairs(ez) do
                if data.distanceLabel then data.distanceLabel.TextColor3 = v end
            end
        end
    })

    s5:AddLabel('Max Distance'):AddSlider({
        Min = 1000, Max = 20000, Default = 10000, Rounding = 1, Flag = "ZombieMaxDistance",
        Callback = function(v) zs.maxDistance = v end
    })

	local zombieDetails = s5:AddLabel('Zombie Details')
	zombieDetails:AddToggle({
		Default = false, Flag = "ZombieDetails",
		Callback = function(v) zs.details = v; u_zbe(); S.Runtime.UpdateZombieEspWorker(); S.Runtime.UpdateEntityDiscoveryWorker() end,
	})
	local zombieDetailOptions = zombieDetails:AddOption()
	zombieDetailOptions:AddLabel('Health'):AddToggle({
		Default = true, Flag = "ZombieHealth",
		Callback = function(v) zs.showHealth = v; if zs.details then u_zbe() end end,
	})
	zombieDetailOptions:AddLabel('Type'):AddToggle({
		Default = true, Flag = "ZombieType",
		Callback = function(v) zs.showType = v; if zs.details then u_zbe() end end,
	})
	s5:AddLabel('Bosses / Specials Only'):AddToggle({
		Default = false, Flag = "ZombieBossesOnly",
		Callback = function(v) zs.bossesOnly = v; u_zbe() end,
	})

    local l_t = s6:AddLabel('Loot ESP')
    l_t:AddToggle({
        Default = false, Flag = "LootESP",
        Callback = function(v)
            ls.enabled = v
            u_lte()
			reconcileEspEntities()
			S.Runtime.UpdateLootEspWorker()
			S.Runtime.UpdateEntityDiscoveryWorker()
        end
    })

    local ln_t = s6:AddLabel('Show Names')
    ln_t:AddToggle({
        Default = false, Flag = "LootName",
        Callback = function(v)
            ls.showNames = v
            u_lte()
			S.Runtime.UpdateLootEspWorker()
			S.Runtime.UpdateEntityDiscoveryWorker()
        end
    })
    ln_t:AddOption():AddLabel('Name Color'):AddColorPicker({
        Default = ls.nameColor, Flag = "LootNameColor",
        Callback = function(v)
            ls.nameColor = v
            for _, data in pairs(el) do
                if data.nameLabel then data.nameLabel.TextColor3 = v end
            end
        end
    })

    local ld_t = s6:AddLabel('Show Distance')
    ld_t:AddToggle({
        Default = false, Flag = "LootDistance",
        Callback = function(v)
            ls.showDistance = v
            u_lte()
			S.Runtime.UpdateLootEspWorker()
			S.Runtime.UpdateEntityDiscoveryWorker()
        end
    })
    ld_t:AddOption():AddLabel('Distance Color'):AddColorPicker({
        Default = ls.distanceColor, Flag = "LootDistanceColor",
        Callback = function(v)
            ls.distanceColor = v
            for _, data in pairs(el) do
                if data.distanceLabel then data.distanceLabel.TextColor3 = v end
            end
        end
    })

    s6:AddLabel('Max Distance'):AddSlider({
        Min = 100, Max = 5000, Default = 1000, Rounding = 1, Flag = "LootMaxDistance",
        Callback = function(v) ls.maxDistance = v end
    })

	s6:AddLabel('Loot Filters'):AddDropdown({
		Default = "All",
		Values = { "All", "Firearms", "Ammo", "Medical", "Consumables", "Attachments", "Containers", "Utilities" },
		Flag = "LootFilter",
		Callback = function(v) ls.filterType = v; u_lte() end,
	})
	s6:AddLabel('Name Filter'):AddTextInput({
		Default = "",
		Placeholder = "comma-separated names",
		Flag = "LootNameFilter",
		Callback = function(v) ls.search = tostring(v or ""); u_lte() end,
	})
end

do
    local World = win:AddTab({ Name = "World" })
    local s_li = World:AddSection({ Name = "ENVIRONMENT" })
    local s_fx = World:AddSection({ Name = "LIGHTING & EFFECTS", Position = 'right' })
	local s_bt = S.VisualBulletTracerSection
	local s_ch = S.VisualCrosshairSection
	local s_local = S.VisualChamsSection
	do
	local s_events = World:AddSection({ Name = "RANDOM EVENTS", Position = 'right' })
	local eventSeen = {}
	local eventAlertStep
	local eventAlertsAvailable = S.Runtime.ObserveNetworkEvent(
		S.Runtime.Framework and S.Runtime.Framework.Libraries and S.Runtime.Framework.Libraries.Network,
		"Add Map Marker",
		function(...)
			if not S.RandomEventAlerts then return end
			local eventId, payload
			for index = 1, select("#", ...) do
				local value = select(index, ...)
				if type(value) == "table" and (value.LogText or value.MapText or value.WorldPosition) then payload = value end
				if not eventId and (type(value) == "string" or type(value) == "number") then eventId = tostring(value) end
			end
			if not payload then return end
			local textValue = tostring(payload.LogText or payload.MapText or "Random event detected")
			local signature = (eventId or textValue) .. ":" .. textValue
			local now = os.clock()
			if eventSeen[signature] and now - eventSeen[signature] < 2 then return end
			for oldSignature, timestamp in pairs(eventSeen) do
				if now - timestamp > 120 then eventSeen[oldSignature] = nil end
			end
			eventSeen[signature] = now
			local worldPosition = payload.WorldPosition
			local position = typeof(worldPosition) == "Vector3" and worldPosition
				or typeof(worldPosition) == "CFrame" and worldPosition.Position
				or nil
			table.insert(S.Runtime.EventAlertQueue, { Text = textValue, Position = position })
			while #S.Runtime.EventAlertQueue > 8 do table.remove(S.Runtime.EventAlertQueue, 1) end
			S.Runtime.SetWorker("RandomEventAlerts", rs.Heartbeat, eventAlertStep, true)
		end
	)

	eventAlertStep = function()
		local alert = table.remove(S.Runtime.EventAlertQueue, 1)
		if not alert then S.Runtime.SetWorker("RandomEventAlerts", rs.Heartbeat, eventAlertStep, false); return end
		local content = alert.Text
		local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if root and alert.Position then
			content ..= (" (%d studs)"):format(math.floor((root.Position - alert.Position).Magnitude + 0.5))
		end
		Notif.new({ Title = "Random Event", Content = content, Duration = 6 })
		if #S.Runtime.EventAlertQueue == 0 then S.Runtime.SetWorker("RandomEventAlerts", rs.Heartbeat, eventAlertStep, false) end
	end

	local function setRandomEventAlerts(enabled)
		S.RandomEventAlerts = enabled == true
		if not enabled then
			table.clear(S.Runtime.EventAlertQueue)
			S.Runtime.SetWorker("RandomEventAlerts", rs.Heartbeat, eventAlertStep, false)
		end
	end

	if eventAlertsAvailable then
		s_events:AddLabel('Random Event Alerts'):AddToggle({
			Default = false, Flag = "RandomEventAlerts", Callback = setRandomEventAlerts,
		})
	else
		s_events:AddLabel('Event alerts unavailable')
	end
	end

    local fs = lt.FogStart
    local fe = lt.FogEnd
    local fc = lt.FogColor
    local oa = {}
    local at = lt:FindFirstChildOfClass("Atmosphere")
    if at then
        oa.Density = at.Density
        oa.Haze = at.Haze
        oa.Glare = at.Glare
        oa.Offset = at.Offset
    end

    local n_f_c = nil
	local noFogElapsed = 0

    s_fx:AddLabel('Remove Fog'):AddToggle({
        Default = false, Flag = "NoFog",
        Callback = function(v)
            if v then
                if n_f_c then 
                    S.Runtime.Disconnect(n_f_c)
                    n_f_c = nil 
                end
				noFogElapsed = math.huge
                n_f_c = S.Runtime.Connect(rs.RenderStepped, function(deltaTime)
					noFogElapsed += deltaTime
					if S.PerformanceMode and noFogElapsed < 0.1 then return end
					noFogElapsed = 0
                    lt.FogStart = 9e9
                    lt.FogEnd = 9e9
                    local a = lt:FindFirstChildOfClass("Atmosphere")
                    if a then
                        a.Density = 0
                        a.Haze = 0
                        a.Glare = 0
                        a.Offset = 0
                    end
                end)
            else
                if n_f_c then 
                    S.Runtime.Disconnect(n_f_c)
                    n_f_c = nil 
                end
                lt.FogStart = fs
                lt.FogEnd = fe
                lt.FogColor = fc
                local a = lt:FindFirstChildOfClass("Atmosphere")
                if a and oa.Density then
                    a.Density = oa.Density
                    a.Haze = oa.Haze
                    a.Glare = oa.Glare
                    a.Offset = oa.Offset
                end
            end
        end
    })

    s_fx:AddLabel('Remove Shadows'):AddToggle({
        Default = false, Flag = "NoShadows",
        Callback = function(v) lt.GlobalShadows = not v end
    })

    local lc = nil
    local lp_v = {}
    local function t_lv(en_)
        if lc then 
            S.Runtime.Disconnect(lc)
            lc = nil 
        end
        if en_ then
            local el_ = ws["Map"]["Elements"]:GetDescendants()
            for _, part in ipairs(el_) do
                if part.Name == "Fronds" or part.Name == "Leaves" or part.Name == "PineLeaves" then
                    if not lp_v[part] then 
                        lp_v[part] = part.Transparency 
                    end
                    part.Transparency = 1
                end
            end
            lc = S.Runtime.Connect(ws["Map"]["Elements"].DescendantAdded, function(part)
                if part.Name == "Fronds" or part.Name == "Leaves" or part.Name == "PineLeaves" then
                    task.wait()
                    if not lp_v[part] then 
                        lp_v[part] = part.Transparency 
                    end
                    part.Transparency = 1
                end
            end)
        else
            local el_ = ws["Map"]["Elements"]:GetDescendants()
            for _, part in ipairs(el_) do
                if part.Name == "Fronds" or part.Name == "Leaves" or part.Name == "PineLeaves" then
                    local o_ = lp_v[part]
                    if o_ ~= nil then
                        part.Transparency = o_
                    else
                        part.Transparency = 0
                    end
                end
            end
            lp_v = {}
        end
    end

    s_li:AddLabel('Remove Leaves'):AddToggle({
        Default = false, Flag = "RemoveLeaves",
        Callback = function(v) t_lv(v) end
    })

    local r_fg = {}
    local function rm_fg(pr)
        for _, child in ipairs(pr:GetChildren()) do
            if child.Name:find("Foliage") or child.Name:find("Shrub") then
                table.insert(r_fg, { instance = child, parent = child.Parent })
                child.Parent = nil
            else
                rm_fg(child)
            end
        end
    end

    local function rs_fg()
        for _, d in ipairs(r_fg) do
            if d.instance and d.parent then d.instance.Parent = d.parent end
        end
        r_fg = {}
    end

    s_li:AddLabel('Remove Bushes'):AddToggle({
        Default = false, Flag = "NoBushes",
        Callback = function(v)
            local me = ws:FindFirstChild("Map") and ws.Map:FindFirstChild("Elements")
            if v then
                if me then rm_fg(me) end
            else
                rs_fg()
            end
        end
    })

    local rd = {}
    local function rm_dr(pr)
        for _, child in ipairs(pr:GetChildren()) do
            if child.Name == "Doors" then
                for _, dc_ in ipairs(child:GetChildren()) do
                    for _, part in ipairs(dc_:GetChildren()) do
                        if part.Name == "Door" then
                            table.insert(rd, { instance = part, parent = part.Parent })
                            part.Parent = nil
                        end
                    end
                end
            end
            rm_dr(child)
        end
    end

    local function rs_dr()
        for _, d in ipairs(rd) do
            if d.instance and d.parent then d.instance.Parent = d.parent end
        end
        rd = {}
    end

    s_li:AddLabel('Remove Doors'):AddToggle({
        Default = false, Flag = "NoDoors",
        Callback = function(v)
            local me = ws:FindFirstChild("Map") and ws.Map:FindFirstChild("Elements")
            if v then
                if me then rm_dr(me) end
            else
                rs_dr()
            end
        end
    })

    local rw = {}
    local function rm_wn(pr)
        for _, child in ipairs(pr:GetChildren()) do
            if child.Name == "Windows" then
                for _, wc in ipairs(child:GetChildren()) do
                    for _, bg in ipairs(wc:GetChildren()) do
                        if bg.Name == "Break Glass" then
                            for _, part in ipairs(bg:GetChildren()) do
                                if part.Name == "Window" then
                                    table.insert(rw, { instance = part, parent = part.Parent })
                                    part.Parent = nil
                                end
                            end
                        end
                    end
                end
            end
            rm_wn(child)
        end
    end

    local function rs_wn()
        for _, d in ipairs(rw) do
            if d.instance and d.parent then d.instance.Parent = d.parent end
        end
        rw = {}
    end

    s_li:AddLabel('Remove Windows'):AddToggle({
        Default = false, Flag = "NoWindows",
        Callback = function(v)
            local me = ws:FindFirstChild("Map") and ws.Map:FindFirstChild("Elements")
            if v then
                if me then rm_wn(me) end
            else
                rs_wn()
            end
        end
    })

    s_fx:AddLabel('Remove Sun Rays'):AddToggle({
        Default = false, Flag = "RemoveSunRays",
        Callback = function(v)
            pcall(function()
                local sr = lt:FindFirstChildOfClass("SunRaysEffect")
                if sr then sr.Enabled = not v end
                for _, child in pairs(lt:GetChildren()) do
                    if child:IsA("SunRaysEffect") then child.Enabled = not v end
                end
            end)
        end
    })

    local d_dy = at and at.Density or 0
    local d_hz = at and at.Haze or 0
    local d_gl = at and at.Glare or 0
    local d_of = at and at.Offset or 0
    local d_cl = at and at.Color or Color3.new(1,1,1)
    local d_dc = at and at.Decay or Color3.new(1,1,1)
	local atmosphereConnection
	local atmosphereElapsed = 0

    local function updateAtmosphere(deltaTime)
		atmosphereElapsed += deltaTime or math.huge
		if S.PerformanceMode and atmosphereElapsed < 0.1 then return end
		atmosphereElapsed = 0
        if not at or at.Parent ~= lt then return end
        S.Runtime.Try("World.Atmosphere", function()
            if S.ab_en then
                at.Density = 0
                at.Haze = 0
                at.Glare = 0
                at.Offset = 0
            else
                at.Density = d_dy
                at.Haze = d_hz
                at.Glare = d_gl
                at.Offset = d_of
            end
            if S.o_c then at.Color = S.ab_c end
            if S.o_d then at.Decay = S.ob_c end
        end)
	end

	local function updateAtmosphereLoop()
		local active = S.ab_en or S.o_c or S.o_d
		updateAtmosphere(math.huge)
		if active and not atmosphereConnection then
			atmosphereConnection = S.Runtime.Connect(rs.RenderStepped, updateAtmosphere)
		elseif not active and atmosphereConnection then
			S.Runtime.Disconnect(atmosphereConnection)
			atmosphereConnection = nil
		end
	end

    local a_t = s_fx:AddLabel('No Atmosphere')
    a_t:AddToggle({
        Default = false, Flag = "NoAtmosphere",
		Callback = function(v) S.ab_en = v; updateAtmosphereLoop() end
    })
    local a_o = a_t:AddOption()
    a_o:AddLabel('Override Color'):AddToggle({
        Default = false, Flag = "OverrideAtmosphereColor",
        Callback = function(v)
            S.o_c = v
            if not v and at then at.Color = d_cl end
			updateAtmosphereLoop()
        end
    })
    a_o:AddLabel('Atmosphere Color'):AddColorPicker({
        Default = S.ab_c, Flag = "AtmosphereColor",
		Callback = function(v) S.ab_c = v; updateAtmosphere(math.huge) end
    })
    a_o:AddLabel('Override Decay'):AddToggle({
        Default = false, Flag = "OverrideAtmosphereDecay",
        Callback = function(v)
            S.o_d = v
            if not v and at then at.Decay = d_dc end
			updateAtmosphereLoop()
        end
    })
    a_o:AddLabel('Decay Color'):AddColorPicker({
        Default = S.ob_c, Flag = "AtmosphereDecay",
		Callback = function(v) S.ob_c = v; updateAtmosphere(math.huge) end
    })

    local ab_en_state = false
	local ambientConnection
	local ambientElapsed = 0
	local function updateAmbient(deltaTime)
		ambientElapsed += deltaTime or math.huge
		if S.PerformanceMode and ambientElapsed < 0.1 then return end
		ambientElapsed = 0
		if ab_en_state then
			lt.Ambient = S.ab_c
			lt.OutdoorAmbient = S.ob_c
		end
	end
	local function updateAmbientLoop()
		updateAmbient(math.huge)
		if ab_en_state and not ambientConnection then
			ambientConnection = S.Runtime.Connect(rs.RenderStepped, updateAmbient)
		elseif not ab_en_state and ambientConnection then
			S.Runtime.Disconnect(ambientConnection)
			ambientConnection = nil
		end
	end
    local ab_t = s_li:AddLabel('Custom Ambient')
    ab_t:AddToggle({
        Default = false, Flag = "CustomAmbient",
        Callback = function(v)
            ab_en_state = v
            if v then
                lt.Ambient = S.ab_c
                lt.OutdoorAmbient = S.ob_c
            else
                lt.Ambient = Color3.fromRGB(127, 127, 127)
                lt.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
            end
			updateAmbientLoop()
        end
    })
    local ab_o = ab_t:AddOption()
    ab_o:AddLabel('Ambient (Indoor)'):AddColorPicker({
        Default = S.ab_c, Flag = "AmbientColor",
        Callback = function(v)
            S.ab_c = v
            if ab_en_state then lt.Ambient = v end
        end
    })
    ab_o:AddLabel('Outdoor Ambient'):AddColorPicker({
        Default = S.ob_c, Flag = "OutdoorAmbientColor",
        Callback = function(v)
            S.ob_c = v
            if ab_en_state then lt.OutdoorAmbient = v end
        end
    })

    local tc_en = false
    local sel_tc = "Voxel"

    local tc_t = s_fx:AddLabel('Custom Technology')
    tc_t:AddToggle({
        Default = false, Flag = "CustomTech",
        Callback = function(v)
            tc_en = v
            if v then
                pcall(function() lt.Technology = Enum.Technology[sel_tc] end)
            else
                pcall(function() lt.Technology = Enum.Technology.Future end)
            end
        end
    })
    tc_t:AddOption():AddLabel('Tech Mode'):AddDropdown({
        Default = 'Voxel', Values = {'Voxel', 'ShadowMap', 'Legacy', 'Compatibility', 'Future'}, Flag = "TechMode",
        Callback = function(v)
            sel_tc = v
            if tc_en then pcall(function() lt.Technology = Enum.Technology[v] end) end
        end
    })

    local c_time = 12
    local time_c = nil
    local c_time_en = false
	local timeElapsed = 0

    local time_t = s_li:AddLabel('Custom Time')
    time_t:AddToggle({
        Default = false, Flag = "CustomTime",
        Callback = function(v)
            c_time_en = v
            if v then
                lt.ClockTime = c_time
                if time_c then 
                    S.Runtime.Disconnect(time_c)
                    time_c = nil 
                end
				timeElapsed = math.huge
                time_c = S.Runtime.Connect(rs.RenderStepped, function(deltaTime)
					timeElapsed += deltaTime
					if not S.PerformanceMode or timeElapsed >= 0.1 then
						timeElapsed = 0
						lt.ClockTime = c_time
					end
				end)
            else
                if time_c then 
                    S.Runtime.Disconnect(time_c)
                    time_c = nil 
                end
            end
        end
    })
    time_t:AddOption():AddLabel('Time'):AddSlider({
        Min = 0, Max = 24, Default = 12, Flag = "CustomTimeValue",
        Callback = function(v)
            c_time = v
            if c_time_en then lt.ClockTime = v end
        end
    })

    local sb = {
        Galaxy = {
            Bk = "http://www.roblox.com/asset/?id=149397692", Dn = "http://www.roblox.com/asset/?id=149397686",
            Ft = "http://www.roblox.com/asset/?id=149397697", Lf = "http://www.roblox.com/asset/?id=149397684",
            Rt = "http://www.roblox.com/asset/?id=149397688", Up = "http://www.roblox.com/asset/?id=149397702"
        },
        ["Galaxy 2"] = {
            Bk = "http://www.roblox.com/asset/?id=155441936", Dn = "http://www.roblox.com/asset/?id=155441802",
            Ft = "http://www.roblox.com/asset/?id=155441818", Lf = "http://www.roblox.com/asset/?id=155441777",
            Rt = "http://www.roblox.com/asset/?id=155441874", Up = "http://www.roblox.com/asset/?id=155441905"
        },
        ["Galaxy 3"] = {
            Bk = "rbxassetid://135908594667929", Dn = "rbxassetid://139584143501514",
            Ft = "rbxassetid://92947876187368", Lf = "rbxassetid://72493016739936",
            Rt = "rbxassetid://81731245279712", Up = "rbxassetid://88174897344210"
        },
        Saturne = {
            Bk = "rbxassetid://1898724755", Dn = "rbxassetid://1898727189",
            Ft = "rbxassetid://1898722814", Lf = "rbxassetid://1898729298",
            Rt = "rbxassetid://1898741025", Up = "rbxassetid://1898736761"
        },
        Neptune = {
            Bk = "rbxassetid://218955819", Dn = "rbxassetid://218953419",
            Ft = "rbxassetid://218954524", Lf = "rbxassetid://218958493",
            Rt = "rbxassetid://218957134", Up = "rbxassetid://218950090"
        },
        Redshift = {
            Bk = "rbxassetid://401664839", Dn = "rbxassetid://401664862",
            Ft = "rbxassetid://401664960", Lf = "rbxassetid://401664881",
            Rt = "rbxassetid://401664901", Up = "rbxassetid://401664936"
        },
        ["Pink Daylights"] = {
            Bk = "rbxassetid://11555017034", Dn = "rbxassetid://11555013415",
            Ft = "rbxassetid://11555010145", Lf = "rbxassetid://11555006545",
            Rt = "rbxassetid://11555000712", Up = "rbxassetid://11554996247"
        },
        ["Purple Night"] = {
            Bk = "rbxassetid://17279854976", Dn = "rbxassetid://17279856318",
            Ft = "rbxassetid://17279858447", Lf = "rbxassetid://17279860360",
            Rt = "rbxassetid://17279862234", Up = "rbxassetid://17279864507"
        },
        ["Gray Night"] = {
            Bk = "rbxassetid://1618912481", Dn = "rbxassetid://1618913943",
            Ft = "rbxassetid://1618913244", Lf = "rbxassetid://1618912849",
            Rt = "rbxassetid://1618911568", Up = "rbxassetid://1618913654"
        },
        ["Anime Sky"] = {
            Bk = "rbxassetid://18351376859", Dn = "rbxassetid://18351374919",
            Ft = "rbxassetid://18351376800", Lf = "rbxassetid://18351376469",
            Rt = "rbxassetid://18351376457", Up = "rbxassetid://18351377189"
        }
    }

    local function cl_sky()
        pcall(function()
            for _, child in pairs(lt:GetChildren()) do
                if child:IsA("Sky") then pcall(function() child:Destroy() end) end
            end
        end)
    end

    local function set_sb(name)
        pcall(function()
            cl_sky()
            local d_ = sb[name]
            if not d_ then return end
            local s = Instance.new("Sky")
            s.SkyboxBk = d_.Bk
            s.SkyboxDn = d_.Dn
            s.SkyboxFt = d_.Ft
            s.SkyboxLf = d_.Lf
            s.SkyboxRt = d_.Rt
            s.SkyboxUp = d_.Up
            pcall(function() s.Parent = lt end)
        end)
    end

    local c_sky_en = false
    local sel_sky = "Galaxy"

    local sky_t = s_li:AddLabel('Custom Sky')
    sky_t:AddToggle({
        Default = false, Flag = "CustomSky",
        Callback = function(v)
            c_sky_en = v
            if v then 
                set_sb(sel_sky) 
            else 
                cl_sky() 
            end
        end
    })
    sky_t:AddOption():AddLabel('Skybox'):AddDropdown({
        Default = 'Galaxy', Values = {'Galaxy', 'Galaxy 2', 'Galaxy 3', 'Saturne', 'Neptune', 'Redshift', 'Pink Daylights', 'Purple Night', 'Gray Night', 'Anime Sky'}, Flag = "SkyboxSelect",
        Callback = function(v)
            sel_sky = v
            if c_sky_en then 
                set_sb(v) 
            end
        end
    })

    if cl then
        local cl_en = cl.Enabled
        local cl_col = cl.Color
        local cl_cov = cl.Cover
        local cl_den = cl.Density
        local mod_cl = false
		local cloudConnection
		local cloudElapsed = 0
		local function updateClouds(deltaTime)
			cloudElapsed += deltaTime or math.huge
			if S.PerformanceMode and cloudElapsed < 0.1 then return end
			cloudElapsed = 0
			if cl and mod_cl then cl.Enabled, cl.Color, cl.Cover, cl.Density = cl_en, cl_col, cl_cov, cl_den end
		end
		local function updateCloudLoop()
			updateClouds(math.huge)
			if mod_cl and not cloudConnection then
				cloudConnection = S.Runtime.Connect(rs.RenderStepped, updateClouds)
			elseif not mod_cl and cloudConnection then
				S.Runtime.Disconnect(cloudConnection)
				cloudConnection = nil
			end
		end

        local cl_t = s_li:AddLabel('Clouds')
        cl_t:AddToggle({
            Default = false, Flag = "EnableClouds_Toggle",
			Callback = function(v) cl_en = v; updateClouds(math.huge) end
        })
        local cl_o = cl_t:AddOption()
        cl_o:AddLabel('Clouds Color'):AddColorPicker({
            Default = cl_col, Flag = "CloudsColor",
			Callback = function(v) cl_col = v; updateClouds(math.huge) end
        })
        cl_o:AddLabel('Clouds Cover'):AddSlider({
            Min = 0, Max = 1, Default = 0.5, Rounding = 2, Flag = "CloudsCover_Slider",
			Callback = function(v) cl_cov = v; updateClouds(math.huge) end
        })
        cl_o:AddLabel('Clouds Density'):AddSlider({
            Min = 0, Max = 1, Default = 0.5, Rounding = 2, Flag = "CloudsDensity_Slider",
			Callback = function(v) cl_den = v; updateClouds(math.huge) end
        })
        cl_o:AddLabel('Modify Clouds'):AddToggle({
            Default = false, Flag = "ModifyClouds_Toggle",
			Callback = function(v) mod_cl = v; updateCloudLoop() end
        })
    else
        s_li:AddLabel('Clouds not found')
    end

    local cc_en = false
    local cc_sat = 1
    local cc_con = 0.5
    local cc_br = 1
    local cc_inst = nil

    local function u_cc()
        if cc_en then
            if not cc_inst then
                cc_inst = lt:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
                cc_inst.Parent = lt
            end
            cc_inst.Saturation = cc_sat
            cc_inst.Contrast = cc_con * 2
            cc_inst.Brightness = cc_br - 1
            cc_inst.Enabled = true
        else
            if cc_inst then cc_inst.Enabled = false end
        end
    end

    local cc_t = s_fx:AddLabel('Color Correction')
    cc_t:AddToggle({
        Default = false, Flag = "ColorCorrection",
        Callback = function(v) cc_en = v; u_cc() end
    })
    local cc_o = cc_t:AddOption()
    cc_o:AddLabel('Saturation'):AddSlider({
        Min = 0, Max = 2, Default = 1, Rounding = 2, Flag = "ColorSaturation",
        Callback = function(v) cc_sat = v; u_cc() end
    })
    cc_o:AddLabel('Contrast'):AddSlider({
        Min = 0, Max = 1, Default = 0.5, Rounding = 2, Flag = "ColorContrast",
        Callback = function(v) cc_con = v; u_cc() end
    })
    cc_o:AddLabel('Brightness'):AddSlider({
        Min = 0.2, Max = 2, Default = 1, Rounding = 2, Flag = "ColorBrightness",
        Callback = function(v) cc_br = v; u_cc() end
    })

    local bl_en = false
    local bl_int = 0.5
    local bl_sz = 24
    local bl_th = 0.8
    local bl_inst = nil
	local bloomConnection
	local bloomElapsed = 0

    local function u_bl()
        if not bl_en then
            if bl_inst then bl_inst.Enabled = false end
            return
        end
        S.Runtime.Try("World.Bloom", function()
            if not bl_inst or not bl_inst.Parent then
                bl_inst = lt:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
                bl_inst.Parent = lt
            end
            bl_inst.Intensity, bl_inst.Size, bl_inst.Threshold, bl_inst.Enabled = bl_int, bl_sz, bl_th, true
        end)
    end

	local function updateBloom(deltaTime)
		bloomElapsed += deltaTime or math.huge
		if S.PerformanceMode and bloomElapsed < 0.1 then return end
		bloomElapsed = 0
		u_bl()
	end

	local function updateBloomLoop()
		updateBloom(math.huge)
		if bl_en and not bloomConnection then
			bloomConnection = S.Runtime.Connect(rs.RenderStepped, updateBloom)
		elseif not bl_en and bloomConnection then
			S.Runtime.Disconnect(bloomConnection)
			bloomConnection = nil
		end
	end

    local bl_t = s_fx:AddLabel('Bloom')
    bl_t:AddToggle({
        Default = false, Flag = "Bloom",
		Callback = function(v) bl_en = v; updateBloomLoop() end
    })
    local bl_o = bl_t:AddOption()
    bl_o:AddLabel('Intensity'):AddSlider({
        Min = 0, Max = 2, Default = 0.5, Rounding = 2, Flag = "BloomIntensity",
		Callback = function(v) bl_int = v; u_bl() end
    })
    bl_o:AddLabel('Size'):AddSlider({
        Min = 0, Max = 128, Default = 24, Rounding = 0, Flag = "BloomSize",
		Callback = function(v) bl_sz = v; u_bl() end
    })
    bl_o:AddLabel('Threshold'):AddSlider({
        Min = 0, Max = 1, Default = 0.8, Rounding = 2, Flag = "BloomThreshold",
		Callback = function(v) bl_th = v; u_bl() end
    })

    local bl_tr_t = s_bt:AddLabel('Bullet Tracer')
    bl_tr_t:AddToggle({
        Default = false, Flag = "BulletTracer",
        Callback = function(v) tr_set.Enabled = v end
    })
    local bt_o = bl_tr_t:AddOption()
    bt_o:AddLabel('Tracer Color'):AddColorPicker({
        Default = tr_set.Color, Flag = "TracerColor",
        Callback = function(v) tr_set.Color = v end
    })
    bt_o:AddLabel('Lifetime'):AddSlider({
        Min = 0, Max = 2, Default = 2, Rounding = 1, Flag = "TracerLifetime",
        Callback = function(v) tr_set.Lifetime = v end
    })
    bt_o:AddLabel('Thickness'):AddSlider({
        Min = 0, Max = 2, Default = 1, Rounding = 1, Flag = "TracerThickness",
        Callback = function(v) tr_set.Thickness = v end
    })

    local function ap_sc(char)
        task.wait()
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				if S.Runtime.SelfChams[part] == nil then
					S.Runtime.SelfChams[part] = { Color = part.Color, Material = part.Material }
				end
                part.Color, part.Material = sc_set.color, sc_set.material
            end
        end
    end

    local function cl_sc(char)
		for part, original in pairs(S.Runtime.SelfChams) do
			pcall(function()
				if part.Parent then part.Color, part.Material = original.Color, original.Material end
			end)
		end
		table.clear(S.Runtime.SelfChams)
    end

    S.Runtime.Connect(lp.CharacterAdded, function(char)
        task.wait()
        if sc_set.enabled then ap_sc(char) end
    end)

    local sc_t = s_local:AddLabel('Self Chams')
    sc_t:AddToggle({
        Default = false, Flag = "SelfChams",
        Callback = function(v)
            sc_set.enabled = v
            local c_ = lp.Character
            if c_ then 
                if v then 
                    ap_sc(c_) 
                else 
                    cl_sc(c_) 
                end 
            end
        end
    })
    local sc_o = sc_t:AddOption()
    sc_o:AddLabel('Chams Color'):AddColorPicker({
        Default = sc_set.color, Flag = "SelfChamsColor",
        Callback = function(v)
            sc_set.color = v
            if sc_set.enabled and lp.Character then 
                ap_sc(lp.Character) 
            end
        end
    })
    sc_o:AddLabel('Chams Material'):AddDropdown({
        Default = 'ForceField', Values = {'ForceField', 'Plastic', 'Wood', 'SmoothPlastic', 'Metal', 'Neon', 'Glass'}, Flag = "SelfChamsMaterial",
        Callback = function(v)
            sc_set.material = Enum.Material[v]
            if sc_set.enabled and lp.Character then 
                ap_sc(lp.Character) 
            end
        end
    })

    S.Runtime.GunChams = { Current = nil, Parts = {}, Connections = {}, CharacterConnections = {} }

	function S.Runtime.CacheGunChamPart(object)
		if not object:IsA("BasePart") or gc_orig[object] then return end
		gc_orig[object] = { Color = object.Color, Material = object.Material }
		table.insert(S.Runtime.GunChams.Parts, object)
		if gc_set.enabled then
			object.Material, object.Color = gc_set.material, gc_set.color
		end
	end

    function S.Runtime.ApplyGunChams(tool)
		if tool and tool ~= S.Runtime.GunChams.Current then return end
		for _, object in ipairs(S.Runtime.GunChams.Parts) do
			if object.Parent then object.Material, object.Color = gc_set.material, gc_set.color end
		end
    end

    function S.Runtime.RestoreGunChams()
		for object, original in pairs(gc_orig) do
			if object.Parent then object.Color, object.Material = original.Color, original.Material end
		end
    end

	function S.Runtime.BindGunChams(tool)
		if tool == S.Runtime.GunChams.Current then return end
		for _, connection in ipairs(S.Runtime.GunChams.Connections) do S.Runtime.Disconnect(connection) end
		table.clear(S.Runtime.GunChams.Connections)
		S.Runtime.RestoreGunChams()
		table.clear(gc_orig)
		table.clear(S.Runtime.GunChams.Parts)
		S.Runtime.GunChams.Current = tool
		if not tool then return end

		for _, object in ipairs(tool:GetDescendants()) do S.Runtime.CacheGunChamPart(object) end
		table.insert(S.Runtime.GunChams.Connections, S.Runtime.Connect(tool.DescendantAdded, S.Runtime.CacheGunChamPart))
		table.insert(S.Runtime.GunChams.Connections, S.Runtime.Connect(tool.DescendantRemoving, function(object)
			local original = gc_orig[object]
			if original and object:IsA("BasePart") then object.Color, object.Material = original.Color, original.Material end
			gc_orig[object] = nil
			local index = table.find(S.Runtime.GunChams.Parts, object)
			if index then table.remove(S.Runtime.GunChams.Parts, index) end
		end))
	end

	function S.Runtime.WatchGunChamCharacter(character)
		for _, connection in ipairs(S.Runtime.GunChams.CharacterConnections) do S.Runtime.Disconnect(connection) end
		table.clear(S.Runtime.GunChams.CharacterConnections)
		if not character then return end
		S.Runtime.BindGunChams(character:FindFirstChild("Equipped"))
		table.insert(S.Runtime.GunChams.CharacterConnections, S.Runtime.Connect(character.ChildAdded, function(child)
			if child.Name == "Equipped" then S.Runtime.BindGunChams(child) end
		end))
		table.insert(S.Runtime.GunChams.CharacterConnections, S.Runtime.Connect(character.ChildRemoved, function(child)
			if child == S.Runtime.GunChams.Current then S.Runtime.BindGunChams(nil) end
		end))
	end

	S.Runtime.Connect(lp.CharacterAdded, S.Runtime.WatchGunChamCharacter)
	S.Runtime.WatchGunChamCharacter(lp.Character)

    local gc_t = s_local:AddLabel('Gun Chams')
    gc_t:AddToggle({
        Default = false, Flag = "GunChams",
        Callback = function(v)
			gc_set.enabled = v
			if v then
				S.Runtime.BindGunChams(lp.Character and lp.Character:FindFirstChild("Equipped"))
				S.Runtime.ApplyGunChams(S.Runtime.GunChams.Current)
			else
				S.Runtime.RestoreGunChams()
			end
		end
    })
    local gc_o = gc_t:AddOption()
    gc_o:AddLabel('Gun Color'):AddColorPicker({
        Default = gc_set.color, Flag = "GunChamsColor",
        Callback = function(v) gc_set.color = v; if gc_set.enabled then S.Runtime.ApplyGunChams(S.Runtime.GunChams.Current) end end
    })
    gc_o:AddLabel('Gun Material'):AddDropdown({
        Default = 'Plastic', Values = {'ForceField', 'Plastic', 'SmoothPlastic', 'Glass', 'Neon'}, Flag = "GunChamsMaterial",
        Callback = function(v) gc_set.material = Enum.Material[v]; if gc_set.enabled then S.Runtime.ApplyGunChams(S.Runtime.GunChams.Current) end end
    })

    local cr_gui = S.Runtime.TrackInstance(Instance.new("ScreenGui"))
    cr_gui.IgnoreGuiInset, cr_gui.ResetOnSpawn = true, false
    cr_gui.Parent = lp:WaitForChild("PlayerGui")

    local gp = Instance.new("Frame")
    gp.AnchorPoint, gp.Position, gp.Size, gp.BackgroundTransparency = Vector2.new(0.5,0.5), UDim2.fromScale(0.5,0.5), UDim2.fromOffset(0,0), 1
    gp.Parent = cr_gui

    local function c_line()
        local f_ = Instance.new("Frame")
        f_.AnchorPoint, f_.BorderSizePixel = Vector2.new(0.5,0.5), 0
        local str_ = Instance.new("UIStroke")
        str_.Thickness, str_.Color, str_.Enabled = 1, Color3.new(0,0,0), false
        str_.Parent = f_
        f_.Parent = gp
        return f_, str_
    end

    local t_ln, t_s = c_line()
    local b_ln, b_s = c_line()
    local l_ln, l_s = c_line()
    local r_ln, r_s = c_line()

    local dt = Instance.new("Frame")
    dt.AnchorPoint, dt.BorderSizePixel = Vector2.new(0.5,0.5), 0
    dt.Parent = gp

    local function u_cr()
        for _, v_ in pairs({t_ln, b_ln, l_ln, r_ln, dt}) do 
            v_.BackgroundColor3 = cr_set.color 
        end
        for _, v_ in pairs({t_s, b_s, l_s, r_s}) do 
            v_.Enabled = cr_set.outline 
        end
        dt.Size, dt.Visible = UDim2.fromOffset(cr_set.dot_s, cr_set.dot_s), cr_set.enabled and cr_set.centerDot

        t_ln.Size, t_ln.Position, t_ln.Visible = UDim2.fromOffset(cr_set.thickness, cr_set.lines.top.size), UDim2.fromOffset(0, -(cr_set.gap + cr_set.lines.top.size/2)), cr_set.enabled and cr_set.lines.top.enabled
        b_ln.Size, b_ln.Position, b_ln.Visible = UDim2.fromOffset(cr_set.thickness, cr_set.lines.bottom.size), UDim2.fromOffset(0, (cr_set.gap + cr_set.lines.bottom.size/2)), cr_set.enabled and cr_set.lines.bottom.enabled
        l_ln.Size, l_ln.Position, l_ln.Visible = UDim2.fromOffset(cr_set.lines.left.size, cr_set.thickness), UDim2.fromOffset(-(cr_set.gap + cr_set.lines.left.size/2), 0), cr_set.enabled and cr_set.lines.left.enabled
        r_ln.Size, r_ln.Position, r_ln.Visible = UDim2.fromOffset(cr_set.lines.right.size, cr_set.thickness), UDim2.fromOffset((cr_set.gap + cr_set.lines.right.size/2), 0), cr_set.enabled and cr_set.lines.right.enabled
    end

    local ang = 0
	local spinElapsed = 0
	local function crosshairSpinStep(dt_sec)
		spinElapsed += dt_sec
		if S.PerformanceMode and spinElapsed < (1 / 30) then return end
	dt_sec = spinElapsed
	spinElapsed = 0
        if cr_set.spinning then
            ang = (ang + cr_set.spin_s * dt_sec) % 360
        else
            ang = 0
        end
        gp.Rotation = ang
	end
	local function updateCrosshairWorker()
		if not cr_set.spinning then gp.Rotation = 0; ang = 0 end
		S.Runtime.SetWorker("CrosshairSpin", rs.RenderStepped, crosshairSpinStep, cr_set.enabled and cr_set.spinning)
	end

    u_cr()

    local cr_t = s_ch:AddLabel("Crosshair")
    cr_t:AddToggle({
        Default = false, Flag = "CrosshairEnabled",
        Callback = function(v) 
            cr_set.enabled = v 
            u_cr() 
			updateCrosshairWorker()
        end
    })
    s_ch:AddLabel("Spin"):AddToggle({
        Default = false, Flag = "CrosshairSpin",
        Callback = function(v) cr_set.spinning = v; updateCrosshairWorker() end
    })
    s_ch:AddLabel("Outline"):AddToggle({
        Default = false, Flag = "CrosshairOutline",
        Callback = function(v) 
            cr_set.outline = v 
            u_cr() 
        end
    })
    s_ch:AddLabel("Center Dot"):AddToggle({
        Default = true, Flag = "CrosshairDot",
        Callback = function(v) 
            cr_set.centerDot = v 
            u_cr() 
        end
    })
    s_ch:AddLabel('Color'):AddColorPicker({
        Default = cr_set.color, Flag = "CrosshairColor",
        Callback = function(v) 
            cr_set.color = v 
            u_cr() 
        end
    })
    s_ch:AddLabel("Thickness"):AddSlider({
        Min = 1, Max = 8, Default = 2, Flag = "CrosshairThickness",
        Callback = function(v) 
            cr_set.thickness = v 
            u_cr() 
        end
    })
    s_ch:AddLabel("Gap"):AddSlider({
        Min = 0, Max = 20, Default = 6, Flag = "CrosshairGap",
        Callback = function(v) 
            cr_set.gap = v 
            u_cr() 
        end
    })
    s_ch:AddLabel("Spin Speed"):AddSlider({
        Min = 10, Max = 500, Default = 120, Flag = "CrosshairSpinSpeed",
        Callback = function(v) cr_set.spin_s = v end
    })
    s_ch:AddLabel("Dot Size"):AddSlider({
        Min = 1, Max = 10, Default = 3, Flag = "CrosshairDotSize",
        Callback = function(v) 
            cr_set.dot_s = v 
            u_cr() 
        end
    })
    s_ch:AddLabel("Line Size"):AddSlider({
        Min = 5, Max = 40, Default = 12, Flag = "CrosshairLineSize",
        Callback = function(v)
            cr_set.line_s = v
            for _, line in pairs(cr_set.lines) do 
                line.size = v 
            end
            u_cr()
        end
    })

	S.Runtime.AddCleanup(function()
		if n_f_c then S.Runtime.Disconnect(n_f_c); n_f_c = nil end
		if lc then S.Runtime.Disconnect(lc); lc = nil end
		if time_c then S.Runtime.Disconnect(time_c); time_c = nil end
		if atmosphereConnection then S.Runtime.Disconnect(atmosphereConnection); atmosphereConnection = nil end
		if ambientConnection then S.Runtime.Disconnect(ambientConnection); ambientConnection = nil end
		if bloomConnection then S.Runtime.Disconnect(bloomConnection); bloomConnection = nil end
		t_lv(false)
		rs_fg()
		rs_dr()
		rs_wn()
		cc_en = false
		bl_en = false
		u_cc()
		u_bl()
		cr_set.enabled = false
		sc_set.enabled = false
		gc_set.enabled = false
		local character = lp.Character
		cl_sc(character)
		if character then
			local equipped = character:FindFirstChild("Equipped")
			if equipped then S.Runtime.RestoreGunChams() end
		end
		for part, original in pairs(gc_orig) do
			pcall(function()
				if part.Parent then part.Color, part.Material = original.Color, original.Material end
			end)
		end
		table.clear(gc_orig)
	end)
end

do
    local jC = 0
    local mJ = 1
	local movementConnection
	local movementElapsed = 0

    local function rJ(hm)
        if hm and hm.FloorMaterial ~= Enum.Material.Air then
            jC = 0
        end
    end

    S.Runtime.Connect(ui.InputBegan, function(ip, gp_)
        if gp_ then return end
        if ip.KeyCode == Enum.KeyCode.LeftShift then
            S.isRunning = true
        elseif ip.KeyCode == Enum.KeyCode.Space and S.doubleJumpEnabled then
            pcall(function()
                if lp and lp.Character then
                    local hm = lp.Character:FindFirstChild("Humanoid")
                    if hm then
                        if hm.FloorMaterial == Enum.Material.Air and jC < mJ then
                            hm:ChangeState(Enum.HumanoidStateType.Jumping)
                            jC = jC + 1
                        end
                        if hm.FloorMaterial ~= Enum.Material.Air then
                            jC = 0
                        end
                    end
                end
            end)
        end
    end)

    S.Runtime.Connect(ui.InputEnded, function(ip, gp_)
        if gp_ then return end
        if ip.KeyCode == Enum.KeyCode.LeftShift then
            S.isRunning = false
        end
    end)

    local function updateMovement(deltaTime)
		movementElapsed += deltaTime
		if S.PerformanceMode and movementElapsed < (1 / 30) then return end
		movementElapsed = 0
        S.Runtime.Try("Movement.Update", function()
            local ch_ = lp.Character
            if not ch_ then return end
            local hm = ch_:FindFirstChildOfClass("Humanoid")
            local hr = ch_:FindFirstChild("HumanoidRootPart")
            if not hm or not hr then return end
                    
			if S.runEnabled and S.isRunning then
				if S.Runtime.WalkSpeeds[hm] == nil then S.Runtime.WalkSpeeds[hm] = hm.WalkSpeed end
				hm.WalkSpeed = S.runningSpeed
			elseif S.walkEnabled then
				if S.Runtime.WalkSpeeds[hm] == nil then S.Runtime.WalkSpeeds[hm] = hm.WalkSpeed end
				hm.WalkSpeed = S.walkingSpeed
			elseif S.Runtime.WalkSpeeds[hm] ~= nil then
				hm.WalkSpeed = S.Runtime.WalkSpeeds[hm]
				S.Runtime.WalkSpeeds[hm] = nil
			end
            rJ(hm)
        end)
    end

	function S.Runtime.UpdateMovementLoop()
		local active = S.walkEnabled or S.runEnabled or S.doubleJumpEnabled
		if active and not movementConnection then
			movementElapsed = math.huge
			movementConnection = S.Runtime.Connect(rs.Heartbeat, updateMovement)
		elseif not active and movementConnection then
			S.Runtime.Disconnect(movementConnection)
			movementConnection = nil
			for humanoid, speed in pairs(S.Runtime.WalkSpeeds) do
				if humanoid.Parent then humanoid.WalkSpeed = speed end
			end
			table.clear(S.Runtime.WalkSpeeds)
		end
	end
end

local flyEnabled = false
local targetVehicle = nil
local bodyVelocity = nil
local bodyGyro = nil
local speed = 50
local flyKeybind = "F"
local flyConnection = nil
local heartbeatConnection = nil
local vehicleFlyToggleCallback = nil
local isFlying = false

local function gVR(vh)
    if not vh or not vh.Parent then return nil end
    if vh.PrimaryPart and vh.PrimaryPart:IsA("BasePart") then
        return vh.PrimaryPart
    end
    for _, pt in vh:GetDescendants() do
        if pt:IsA("BasePart") then
            local nm = pt.Name:lower()
            if nm:find("root") or nm:find("main") or nm:find("base") or nm:find("chassis") or nm:find("body") then
                return pt
            end
        end
    end
    local bP, bSz = nil, 0
    for _, pt in vh:GetDescendants() do
        if pt:IsA("BasePart") then
            local sz = pt.Size.Magnitude
            if sz > bSz then
                bSz = sz
                bP = pt
            end
        end
    end
    if bP then return bP end
    for _, pt in vh:GetDescendants() do
        if pt:IsA("BasePart") then return pt end
    end
    return nil
end

local function iPSV()
    if not targetVehicle then return false end
    local ch_ = lp.Character
    if not ch_ then return false end
    local hm = ch_:FindFirstChildWhichIsA("Humanoid")
    if hm and hm.SeatPart then
        return hm.SeatPart.Parent == targetVehicle
    end
    for _, pt in ch_:GetChildren() do
        if pt:IsA("VehicleSeat") and pt.Parent == targetVehicle then
            return true
        end
    end
    return false
end

local dFl
local function eFl(vh)
    if flyEnabled then return true end
    if not vh or not vh.Parent then return false end

    local rt = gVR(vh)
    if not rt then return false end

    targetVehicle = vh
    if bodyVelocity then bodyVelocity:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(400000, 400000, 400000)
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.P = 1250
    bodyVelocity.Parent = rt

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(400000, 400000, 400000)
    bodyGyro.P = 3000
    bodyGyro.D = 500
    bodyGyro.CFrame = rt.CFrame
    bodyGyro.Parent = rt

    flyEnabled = true
    isFlying = true

    if flyConnection then S.Runtime.Disconnect(flyConnection) end
    flyConnection = S.Runtime.Connect(rs.RenderStepped, function()
        if not flyEnabled or not targetVehicle or not targetVehicle.Parent then return end

        local vR = gVR(targetVehicle)
        if not vR or not vR.Parent then
            return
        end

        local mD = Vector3.zero
        if ui:IsKeyDown(Enum.KeyCode.W) then mD = mD + cm.CFrame.LookVector end
        if ui:IsKeyDown(Enum.KeyCode.S) then mD = mD - cm.CFrame.LookVector end
        if ui:IsKeyDown(Enum.KeyCode.A) then mD = mD - cm.CFrame.RightVector end
        if ui:IsKeyDown(Enum.KeyCode.D) then mD = mD + cm.CFrame.RightVector end
        if ui:IsKeyDown(Enum.KeyCode.Space) then mD = mD + Vector3.yAxis end
        if ui:IsKeyDown(Enum.KeyCode.LeftControl) then mD = mD - Vector3.yAxis end

        if mD.Magnitude > 0.01 then
            bodyVelocity.Velocity = mD.Unit * speed
        else
            bodyVelocity.Velocity = Vector3.zero
        end

        local lAt = vR.Position + cm.CFrame.LookVector * 50
        bodyGyro.CFrame = CFrame.new(vR.Position, lAt)
    end)

    if heartbeatConnection then 
        S.Runtime.Disconnect(heartbeatConnection)
        heartbeatConnection = nil 
    end

    return true
end

dFl = function()
    flyEnabled = false
    isFlying = false
    targetVehicle = nil
    if flyConnection then S.Runtime.Disconnect(flyConnection); flyConnection = nil end
    if heartbeatConnection then S.Runtime.Disconnect(heartbeatConnection); heartbeatConnection = nil end
    if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
    if vehicleFlyToggleCallback then
        vehicleFlyToggleCallback(false)
    end
end

local function tFl()
    if flyEnabled then
        dFl()
        return
    end

    local ch_ = lp.Character
    if not ch_ then return end
    local vh = nil
    local hm = ch_:FindFirstChildWhichIsA("Humanoid")
    if hm and hm.SeatPart and hm.SeatPart.Parent then
        vh = hm.SeatPart.Parent
    end

    if not vh then
        local hr = ch_:FindFirstChild("HumanoidRootPart")
        if hr then
            local cD = 12
            for _, st in ws:GetDescendants() do
                if st:IsA("VehicleSeat") and st.Parent then
                    local ds_ = (hr.Position - st.Position).Magnitude
                    if ds_ < cD then
                        cD = ds_
                        vh = st.Parent
                    end
                end
            end
        end
    end

    if not vh then return end
    eFl(vh)
    if vehicleFlyToggleCallback then
        vehicleFlyToggleCallback(true)
    end
end

local function gKC(kS)
    local kM = {
        ["F"] = Enum.KeyCode.F,
        ["G"] = Enum.KeyCode.G,
        ["H"] = Enum.KeyCode.H,
        ["R"] = Enum.KeyCode.R,
        ["T"] = Enum.KeyCode.T,
        ["Y"] = Enum.KeyCode.Y,
        ["Q"] = Enum.KeyCode.Q,
        ["E"] = Enum.KeyCode.E,
        ["X"] = Enum.KeyCode.X,
        ["C"] = Enum.KeyCode.C,
        ["V"] = Enum.KeyCode.V,
        ["B"] = Enum.KeyCode.B,
        ["LeftShift"] = Enum.KeyCode.LeftShift,
        ["LeftControl"] = Enum.KeyCode.LeftControl,
        ["LeftAlt"] = Enum.KeyCode.LeftAlt,
        ["Space"] = Enum.KeyCode.Space,
        ["None"] = nil,
    }
    return kM[kS] or Enum.KeyCode.F
end

S.Runtime.Connect(ui.InputBegan, function(ip, gP)
    if gP then return end
    local cK = gKC(flyKeybind)
    if cK and ip.KeyCode == cK then
        tFl()
    end
end)

local Fw = (require :: any)(rf:WaitForChild("Framework"))
Fw:WaitForLoaded()
S.Runtime.Framework = Fw
S.Runtime.PlayerClass = Fw.Classes and Fw.Classes.Players and Fw.Classes.Players.get()

do
	local function restoreAthleticGearHooks()
		for character, hook in pairs(S.Runtime.AthleticGearHooks) do
			pcall(function()
				if character.HasPerk == hook.Wrapper then
					character.HasPerk = hook.Original
				end
			end)
		end
		table.clear(S.Runtime.AthleticGearHooks)
	end

	local function hookAthleticGear(character)
		if type(character) ~= "table" or S.Runtime.AthleticGearHooks[character] then return end

		local original = character.HasPerk
		if type(original) ~= "function" then return end

		local wrapper
		wrapper = function(self, perkName, ...)
			if self == character then
				if S.AthleticGearEnabled and perkName == "Athletic Gear" then return true end
				if S.ClimbingGearEnabled and perkName == "Climbing Gear" then return true end
			end
			return original(self, perkName, ...)
		end

		local assigned = pcall(function() character.HasPerk = wrapper end)
		if assigned and character.HasPerk == wrapper then
			S.Runtime.AthleticGearHooks[character] = {
				Original = original,
				Wrapper = wrapper,
			}
		end
	end

	local refreshGeneration = 0
	local function refreshAthleticGear()
		refreshGeneration += 1
		local generation = refreshGeneration
		if not (S.AthleticGearEnabled or S.ClimbingGearEnabled) then return end
		task.spawn(function()
			for _ = 1, 20 do
				if S.Runtime.Unloaded or not (S.AthleticGearEnabled or S.ClimbingGearEnabled) or refreshGeneration ~= generation then return end
				local playersClass = Fw.Classes and Fw.Classes.Players
				local playerObject = playersClass and playersClass.get()
				local character = playerObject and playerObject.Character
				hookAthleticGear(character)
				if character and S.Runtime.AthleticGearHooks[character] then return end
				task.wait(0.1)
			end
		end)
	end

	function S.Runtime.SetAthleticGear(enabled)
		S.AthleticGearEnabled = enabled == true
		if S.AthleticGearEnabled or S.ClimbingGearEnabled then
			refreshAthleticGear()
		else
			refreshGeneration += 1
			restoreAthleticGearHooks()
		end
	end

	function S.Runtime.SetClimbingGear(enabled)
		S.ClimbingGearEnabled = enabled == true
		if S.AthleticGearEnabled or S.ClimbingGearEnabled then
			refreshAthleticGear()
		else
			refreshGeneration += 1
			restoreAthleticGearHooks()
		end
	end

	S.Runtime.Connect(lp.CharacterAdded, function()
		if S.AthleticGearEnabled or S.ClimbingGearEnabled then refreshAthleticGear() end
	end)

	S.Runtime.AddCleanup(function()
		S.AthleticGearEnabled = false
		S.ClimbingGearEnabled = false
		restoreAthleticGearHooks()
	end)

end

do
	local Cosmetics = win:AddTab({ Name = "Cosmetics" })
	local SkinSection = Cosmetics:AddSection({ Name = "SKIN CHANGER" })
	local WeaponSkins = game:GetService("ReplicatedStorage"):FindFirstChild("WeaponSkins")
	local GunBuilder = Fw.Libraries and Fw.Libraries.GunBuilder
	local PlayerClass = Fw.Classes and Fw.Classes.Players and Fw.Classes.Players.get()
	local skinState = {
		Active = false,
		Assignments = {},
		Pack = nil,
		Pattern = nil,
		Tint = Color3.new(1, 1, 1),
		Catalog = {},
		OriginalOverrides = setmetatable({}, { __mode = "k" }),
		BoundCharacter = nil,
		CurrentKey = nil,
		CharacterConnection = nil,
		ApplyGeneration = 0,
		SyncingControls = false,
		RefreshQueued = false,
		ForcedLabel = nil,
	}

	local equippedLabel = SkinSection:AddLabel("Equipped Gun: None")
	local packDropdown
	local patternDropdown
	local tintPicker
	local handleEquipmentChanged

	local function getCharacter()
		return PlayerClass and PlayerClass.Character
	end

	local function getFirearm(character)
		local item = character and character.EquippedItem
		if item and item.Type == "Firearm" then return item end
		return nil
	end

	local function getItemKey(item)
		if not item then return nil end
		return tostring(item.Id or item.Name or item.DisplayName)
	end

	local function refreshEquippedLabel()
		local item = getFirearm(getCharacter())
		local name = item and (item.DisplayName or item.Name) or "None"
		equippedLabel:SetText("Equipped Gun: " .. tostring(name))
	end

	local function cosmeticRefreshStep()
		skinState.RefreshQueued = false
		local previousIdentity = getthreadidentity()
		local promoted = pcall(setthreadidentity, 8)
		local ok, message = pcall(function()
			if skinState.ForcedLabel then
				equippedLabel:SetText("Equipped Gun: " .. skinState.ForcedLabel)
				skinState.ForcedLabel = nil
			elseif handleEquipmentChanged then
				handleEquipmentChanged()
			end
		end)
		S.Runtime.SetWorker("CosmeticRefresh", rs.RenderStepped, cosmeticRefreshStep, false)
		if promoted then pcall(setthreadidentity, previousIdentity) end
		if not ok then S.Runtime.ReportError("Cosmetics.RefreshUI", message) end
	end

	local function queueEquipmentRefresh(forcedLabel)
		if forcedLabel then skinState.ForcedLabel = forcedLabel end
		if skinState.RefreshQueued then return end
		skinState.RefreshQueued = true
		S.Runtime.SetWorker("CosmeticRefresh", rs.RenderStepped, cosmeticRefreshStep, true)
	end

	local function buildCatalog()
		local catalog = {}
		if WeaponSkins then
			for _, pack in ipairs(WeaponSkins:GetChildren()) do
				if pack:IsA("Folder") then
					local patterns = {}
					for _, skin in ipairs(pack:GetChildren()) do
						if skin:IsA("ModuleScript") then
							patterns[skin.Name] = skin
						end
					end
					if next(patterns) then catalog[pack.Name] = patterns end
				end
			end
		end
		skinState.Catalog = catalog
		return catalog
	end

	local function sortedKeys(source)
		local values = {}
		for name in pairs(source or {}) do table.insert(values, name) end
		table.sort(values)
		return values
	end

	local function tintColor(base, tint)
		return Color3.new(base.R * tint.R, base.G * tint.G, base.B * tint.B)
	end

	local function tintVisualRoot(root, skinModule, tint)
		if not root or not skinModule then return end
		local ok, skinData = pcall(require, skinModule)
		if not ok or type(skinData) ~= "table" or type(skinData.Patterns) ~= "table" then return end

		for _, part in ipairs(root:GetDescendants()) do
			if part:IsA("BasePart") then
				local patternName = part:GetAttribute("SkinPattern")
				if patternName and not skinData.Patterns[patternName] then
					patternName = part:GetAttribute("BackupPattern")
				end
				local pattern = patternName and skinData.Patterns[patternName]
				if pattern and pattern.Channel1 and pattern.Channel2 then
					local channel1 = Color3.new(select(2, table.unpack(pattern.Channel1)))
					local channel2 = Color3.new(select(2, table.unpack(pattern.Channel2)))
					local mesh = part:FindFirstChildOfClass("SpecialMesh")
					if mesh then
						local color = tintColor(channel1, tint)
						mesh.VertexColor = Vector3.new(color.R, color.G, color.B)
					end
					for _, texture in ipairs(part:GetChildren()) do
						if texture:IsA("Texture") and texture.Name == "Skin Texture" then
							texture.Color3 = tintColor(texture.ZIndex == 1 and channel1 or channel2, tint)
						end
					end
				end
			end
		end
	end

	local function applyToVisibleModels(assignment)
		local skinId = assignment and assignment.Pattern
		local patternMap = assignment and skinState.Catalog[assignment.Pack]
		local skinModule = patternMap and patternMap[skinId]
		if not skinModule or not GunBuilder then return end

		local characterModel = lp.Character
		local equippedModel = characterModel and characterModel:FindFirstChild("Equipped")
		if equippedModel then
			GunBuilder:CleanSkin(equippedModel)
			GunBuilder:ApplySkin(equippedModel, skinId)
			tintVisualRoot(equippedModel, skinModule, assignment.Tint)
		end

		local camera = ws.CurrentCamera
		if camera then
			GunBuilder:CleanSkin(camera)
			GunBuilder:ApplySkin(camera, skinId)
			tintVisualRoot(camera, skinModule, assignment.Tint)
		end
	end

	local function renderCharacterSkin(character, skinId)
		local item = getFirearm(character)
		if not item or not character.Animator or not GunBuilder then return false end
		local serialized = GunBuilder:Serialize(item)
		serialized.SkinId = skinId or ""
		character.Animator:SetState("EquippedItem", serialized)
		return true
	end

	local function scheduleVisualApply(assignment)
		skinState.ApplyGeneration += 1
		local generation = skinState.ApplyGeneration
		for _, delayTime in ipairs({ 0, 0.1, 0.35 }) do
			task.delay(delayTime, function()
				if S.Runtime.Unloaded or not skinState.Active or generation ~= skinState.ApplyGeneration then return end
				applyToVisibleModels(assignment)
			end)
		end
	end

	local function syncControls(assignment)
		if not assignment or not skinState.Catalog[assignment.Pack] then return end
		skinState.SyncingControls = true
		skinState.Pack = assignment.Pack
		packDropdown:SetValue(assignment.Pack)
		if skinState.Catalog[assignment.Pack][assignment.Pattern] then
			skinState.Pattern = assignment.Pattern
			patternDropdown:SetValue(assignment.Pattern)
		end
		skinState.Tint = assignment.Tint
		tintPicker:SetValue(assignment.Tint)
		skinState.SyncingControls = false
	end

	local function applyAssignment(character, item, assignment, updateControls)
		if not character or not item or not assignment then return false end
		if not (skinState.Catalog[assignment.Pack] and skinState.Catalog[assignment.Pack][assignment.Pattern]) then return false end
		if skinState.OriginalOverrides[character] == nil then
			skinState.OriginalOverrides[character] = character.WeponSkinGlobalOverride or false
		end
		if updateControls then syncControls(assignment) end
		skinState.Active = true
		skinState.CurrentKey = getItemKey(item)
		character.WeponSkinGlobalOverride = assignment.Pattern
		renderCharacterSkin(character, assignment.Pattern)
		scheduleVisualApply(assignment)
		return true
	end

	local function restoreCharacterSkin(character, item)
		skinState.Active = false
		skinState.CurrentKey = nil
		skinState.ApplyGeneration += 1
		if not character then return end

		local original = skinState.OriginalOverrides[character]
		if original ~= nil then
			if original == false then
				character.WeponSkinGlobalOverride = nil
			else
				character.WeponSkinGlobalOverride = original
			end
		end
		local originalSkin = item and item.SkinId
		if original and original ~= false then originalSkin = original end
		renderCharacterSkin(character, originalSkin)
		if GunBuilder then
			local equippedModel = lp.Character and lp.Character:FindFirstChild("Equipped")
			for _, root in ipairs({ ws.CurrentCamera, equippedModel }) do
				if root then
					GunBuilder:CleanSkin(root)
					if originalSkin and originalSkin ~= "" then GunBuilder:ApplySkin(root, originalSkin) end
				end
			end
		end
		skinState.OriginalOverrides[character] = nil
	end

	local function applySelectedSkin(showNotice)
		local character = getCharacter()
		local item = getFirearm(character)
		local patterns = skinState.Catalog[skinState.Pack]
		if not item then
			if showNotice then Notif.new({ Title = "Skin Changer", Content = "Equip a firearm first.", Duration = 3 }) end
			return false
		end
		if not (patterns and patterns[skinState.Pattern]) then
			if showNotice then Notif.new({ Title = "Skin Changer", Content = "Select a valid skin pattern.", Duration = 3 }) end
			return false
		end

		local assignment = {
			Pack = skinState.Pack,
			Pattern = skinState.Pattern,
			Tint = skinState.Tint,
		}
		skinState.Assignments[getItemKey(item)] = assignment
		applyAssignment(character, item, assignment, false)
		if showNotice then
			Notif.new({ Title = "Skin Changer", Content = skinState.Pattern .. " applied to " .. tostring(item.DisplayName or item.Name) .. ".", Duration = 3 })
		end
		return true
	end

	local function resetSkin(showNotice)
		local character = getCharacter()
		local item = getFirearm(character)
		if not item then
			if showNotice then Notif.new({ Title = "Skin Changer", Content = "Equip a firearm first.", Duration = 3 }) end
			return
		end
		skinState.Assignments[getItemKey(item)] = nil
		restoreCharacterSkin(character, item)
		if showNotice then
			Notif.new({ Title = "Skin Changer", Content = "Skin reset for " .. tostring(item.DisplayName or item.Name) .. ".", Duration = 3 })
		end
	end

	handleEquipmentChanged = function()
		refreshEquippedLabel()
		local character = getCharacter()
		local item = getFirearm(character)
		local assignment = item and skinState.Assignments[getItemKey(item)]
		if assignment then
			applyAssignment(character, item, assignment, true)
		elseif skinState.Active or (character and skinState.OriginalOverrides[character] ~= nil) then
			restoreCharacterSkin(character, item)
		end
	end

	local function bindCharacter(character)
		if type(character) ~= "table" or not character.EquipmentChanged then character = getCharacter() end
		if skinState.CharacterConnection then
			S.Runtime.Disconnect(skinState.CharacterConnection)
			skinState.CharacterConnection = nil
		end
		skinState.BoundCharacter = character
		if character and character.EquipmentChanged then
			skinState.CharacterConnection = S.Runtime.Connect(character.EquipmentChanged, function()
				queueEquipmentRefresh()
			end)
		end
		skinState.ForcedLabel = nil
		queueEquipmentRefresh()
	end

	buildCatalog()
	local packs = sortedKeys(skinState.Catalog)
	if #packs == 0 then packs = { "Unavailable" } end
	skinState.Pack = packs[1]
	local patterns = sortedKeys(skinState.Catalog[skinState.Pack])
	if #patterns == 0 then patterns = { "Unavailable" } end
	skinState.Pattern = patterns[1]

	packDropdown = SkinSection:AddLabel("Skin Pack"):AddDropdown({
		Default = skinState.Pack,
		Values = packs,
		Flag = "CosmeticSkinPack",
		Callback = function(value)
			skinState.Pack = value
			local values = sortedKeys(skinState.Catalog[value])
			if #values == 0 then values = { "Unavailable" } end
			skinState.Pattern = values[1]
			if patternDropdown then
				patternDropdown:SetValues(values)
				patternDropdown:SetValue(skinState.Pattern)
			end
		end,
	})

	patternDropdown = SkinSection:AddLabel("Skin Pattern"):AddDropdown({
		Default = skinState.Pattern,
		Values = patterns,
		Flag = "CosmeticSkinPattern",
		Callback = function(value) skinState.Pattern = value end,
	})

	tintPicker = SkinSection:AddLabel("Custom Skin Tint"):AddColorPicker({
		Default = skinState.Tint,
		Flag = "CosmeticSkinTint",
		Callback = function(value)
			skinState.Tint = value
			if skinState.Active and not skinState.SyncingControls then
				local assignment = skinState.Assignments[skinState.CurrentKey]
				if assignment then
					assignment.Tint = value
					applyToVisibleModels(assignment)
				end
			end
		end,
	})

	SkinSection:AddButton({ Name = "Apply Skin", Callback = function() applySelectedSkin(true) end })
	SkinSection:AddButton({
		Name = "Refresh Skins",
		Callback = function()
			buildCatalog()
			local newPacks = sortedKeys(skinState.Catalog)
			if #newPacks == 0 then newPacks = { "Unavailable" } end
			if not skinState.Catalog[skinState.Pack] then skinState.Pack = newPacks[1] end
			packDropdown:SetValues(newPacks)
			packDropdown:SetValue(skinState.Pack)
			refreshEquippedLabel()
			Notif.new({ Title = "Skin Changer", Content = "Skin list refreshed.", Duration = 3 })
		end,
	})
	SkinSection:AddButton({ Name = "Reset Skin", Callback = function() resetSkin(true) end })

	if PlayerClass and PlayerClass.CharacterAdded then
		S.Runtime.Connect(PlayerClass.CharacterAdded, function()
			task.defer(bindCharacter, PlayerClass.Character)
		end)
	end
	if PlayerClass and PlayerClass.CharacterRemoving then
		S.Runtime.Connect(PlayerClass.CharacterRemoving, function(character)
			if type(character) ~= "table" or not character.EquipmentChanged then character = skinState.BoundCharacter end
			local original = character and skinState.OriginalOverrides[character]
			if original ~= nil then
				if original == false then
					character.WeponSkinGlobalOverride = nil
				else
					character.WeponSkinGlobalOverride = original
				end
				skinState.OriginalOverrides[character] = nil
			end
			if skinState.CharacterConnection then
				S.Runtime.Disconnect(skinState.CharacterConnection)
				skinState.CharacterConnection = nil
			end
			skinState.Active = false
			skinState.CurrentKey = nil
			skinState.BoundCharacter = nil
			queueEquipmentRefresh("None")
		end)
	end
	S.Runtime.Connect(lp.CharacterAdded, function()
		for _, delayTime in ipairs({ 0, 0.1, 0.5 }) do
			task.delay(delayTime, function()
				if not S.Runtime.Unloaded and PlayerClass.Character ~= skinState.BoundCharacter then
					bindCharacter(PlayerClass.Character)
				end
			end)
		end
	end)
	bindCharacter(getCharacter())

	S.Runtime.AddCleanup(function()
		restoreCharacterSkin(getCharacter(), getFirearm(getCharacter()))
		table.clear(skinState.Assignments)
		if skinState.CharacterConnection then
			S.Runtime.Disconnect(skinState.CharacterConnection)
			skinState.CharacterConnection = nil
		end
	end)
end

local Nw = Fw.Libraries.Network
local iFu = false

S.Runtime.AddMethodHook(Nw, "Fetch", "Network.InfiniteFuel", function(nextFetch, self, nm, ...)
    if nm == "Vehicle Report Input" and iFu then
        return true
    end
    return nextFetch(self, nm, ...)
end)

local function tPJ(en_)
    local wt = ws:FindFirstChild("Map") and ws.Map:FindFirstChild("Water") or ws:FindFirstChild("Water")
    if not wt then return end
    local wP = wt:GetDescendants()
    for _, pt in ipairs(wP) do
        if en_ then
            if pt:HasTag("Swim Surface") then
                pt:RemoveTag("Swim Surface")
                pt:AddTag("Player Jesus")
            end
        else
            if pt:HasTag("Player Jesus") then
                pt:RemoveTag("Player Jesus")
                pt:AddTag("Swim Surface")
            end
        end
    end
end

do
    local Misc = win:AddTab({ Name = "Misc" })
    local MovementSection = Misc:AddSection({ Name = "MOVEMENT" })
    local GameSection = Misc:AddSection({ Name = "GAME", Position = "Right" })
    local ZombieSection = ZombiesTab:AddSection({ Name = "ZOMBIE SETTINGS", Position = "right" })
    local VehicleFlySection = VehiclesTab:AddSection({ Name = "VEHICLE MODS", Position = "right" })

	MovementSection:AddLabel('Athletic Gear'):AddToggle({
		Default = false,
		Flag = "AthleticGear",
		Callback = function(value)
			S.Runtime.SetAthleticGear(value)
		end,
	})

	MovementSection:AddLabel('Climbing Gear'):AddToggle({
		Default = false,
		Flag = "ClimbingGear",
		Callback = function(value) S.Runtime.SetClimbingGear(value) end,
	})

    MovementSection:AddLabel('Double Jump'):AddToggle({
        Default = false,
        Flag = "DoubleJump",
        Callback = function(Value)
            S.doubleJumpEnabled = Value
			S.Runtime.UpdateMovementLoop()
        end
    })

    MovementSection:AddLabel('No Swim Restriction'):AddToggle({
        Default = false,
        Flag = "PlayerJesus",
        Callback = function(v)
            tPJ(v)
        end
    })

    local walkToggle = MovementSection:AddLabel('Walk Speed')
    walkToggle:AddToggle({
        Default = false,
        Flag = "WalkSpeed",
        Callback = function(Value)
            S.walkEnabled = Value
			S.Runtime.UpdateMovementLoop()
        end
    })
    walkToggle:AddOption():AddLabel('Speed'):AddSlider({
        Min = 16,
        Max = 21,
        Default = 16,
        Flag = "WalkSpeedValue",
        Callback = function(Value)
            S.walkingSpeed = Value
        end
    })

    local runToggle = MovementSection:AddLabel('Run Speed')
    runToggle:AddToggle({
        Default = false,
        Flag = "RunSpeed",
        Callback = function(Value)
            S.runEnabled = Value
			S.Runtime.UpdateMovementLoop()
        end
    })
    runToggle:AddOption():AddLabel('Speed'):AddSlider({
        Min = 20,
        Max = 28,
        Default = 20,
        Flag = "RunSpeedValue",
        Callback = function(Value)
            S.runningSpeed = Value
        end
    })

    if zo_ then
        ZombieSection:AddLabel('Freeze Zombies'):AddToggle({
            Default = false,
            Flag = "FreezeZombies",
            Callback = function(st)
                S.iFE = st
				S.Runtime.BindFreezeZombieFolder(zo_)
				if st then
					for _, z in ipairs(zo_:GetChildren()) do task.defer(fzZ, z) end
				else
					while next(S.Runtime.ZombieStates) do
						local zombie = next(S.Runtime.ZombieStates)
						ufzZ(zombie)
					end
				end
            end
        })

        ZombieSection:AddLabel('Zombie Circle'):AddToggle({
            Default = false,
            Flag = "ZombieCircle",
			Callback = S.Runtime.SetZombieCircle
        })

        ZombieSection:AddLabel('Circle Distance'):AddSlider({
            Min = 5,
            Max = 50,
            Default = 10,
            Flag = "ZombieDistance",
            Callback = function(v)
                S.zCD = v
            end
        })

        ZombieSection:AddLabel('Circle Speed'):AddSlider({
            Min = 1,
            Max = 20,
            Default = 5,
            Flag = "ZombieSpeed",
            Callback = function(v)
                S.zCS = v
            end
        })
    else
        ZombieSection:AddLabel('Zombies folder not found')
    end

    VehicleFlySection:AddLabel('Infinite Fuel'):AddToggle({
        Default = false,
        Callback = function(v)
            iFu = v
        end,
        Flag = "InfFuel"
    })

    local flyToggle = VehicleFlySection:AddLabel('Vehicle Fly')
    flyToggle:AddToggle({
        Default = false,
        Flag = "VehicleFly",
        Callback = function(v)
            vehicleFlyToggleCallback = function(nV)
                if flyToggle and flyToggle.Set then
                    flyToggle:Set(nV)
                end
            end
            if v then
                tFl()
            else
                if flyEnabled then
                    dFl()
                end
            end
        end
    })

    local flyOptions = flyToggle:AddOption()
    flyOptions:AddLabel('Fly Speed'):AddSlider({
        Min = 1,
        Max = 80,
        Default = 50,
        Flag = "VehicleFlySpeed",
        Callback = function(v)
            speed = v
        end
    })

    flyOptions:AddLabel('Fly Keybind'):AddKeybind({
        Default = 'F',
        Flag = "VehicleFlyKeybind",
        Callback = function(v)
            if v == "None" or v == "" then
                flyKeybind = "F"
            elseif type(v) == "string" then
                flyKeybind = v
            elseif type(v) == "table" and v.Key then
                flyKeybind = v.Key
            else
                flyKeybind = tostring(v)
            end
        end
    })

local Workspace = game:GetService("Workspace")
local Vehicles = Workspace:FindFirstChild("Vehicles")
local HttpService = game:GetService("HttpService")

local driveMultiplier = 2
local reverseMultiplier = 2
local isEnabled = false
local modified = {}
local originalConfigs = {}
local connection = nil

local function SaveOriginal(vehicle)
    if originalConfigs[vehicle] then return end
    
    local config = vehicle:FindFirstChild("Config")
    if not config then return end
    
    local success, data = pcall(require, config)
    if not success or not data or not data.Physics then return end
    
    originalConfigs[vehicle] = {
        DriveSpeed = data.Physics.DriveSpeed or 54,
        ReverseSpeed = data.Physics.ReverseSpeed or 20
    }
end

local function ApplySpeedToVehicle(vehicle)
    if not vehicle then return end
    if modified[vehicle] then return end
    if not isEnabled then return end
    
    local config = vehicle:FindFirstChild("Config")
    if not config then return end
    
    local success, data = pcall(require, config)
    if not success or not data or not data.Physics then return end
    
    SaveOriginal(vehicle)
    
    local orig = originalConfigs[vehicle]
    if orig then
        data.Physics.DriveSpeed = orig.DriveSpeed * driveMultiplier
        data.Physics.ReverseSpeed = orig.ReverseSpeed * reverseMultiplier
    else
        data.Physics.DriveSpeed = (data.Physics.DriveSpeed or 54) * driveMultiplier
        data.Physics.ReverseSpeed = (data.Physics.ReverseSpeed or 20) * reverseMultiplier
    end
    
    if config:IsA("ModuleScript") then
        config.Source = "return " .. HttpService:JSONEncode(data)
        modified[vehicle] = true
    end
end

local function ApplyToAll()
    if not Vehicles then return end
    for _, vehicle in ipairs(Vehicles:GetChildren()) do
        if vehicle:FindFirstChild("Config") and not modified[vehicle] then
            ApplySpeedToVehicle(vehicle)
        end
    end
end

local function RestoreAll()
    for vehicle, orig in pairs(originalConfigs) do
        local config = vehicle:FindFirstChild("Config")
        if not config then continue end
        
        local success, data = pcall(require, config)
        if not success or not data or not data.Physics then continue end
        
        data.Physics.DriveSpeed = orig.DriveSpeed
        data.Physics.ReverseSpeed = orig.ReverseSpeed
        
        if config:IsA("ModuleScript") then
            config.Source = "return " .. HttpService:JSONEncode(data)
        end
    end
    
    modified = {}
end

local function ReapplyVehicleSpeed()
    if not isEnabled then return end
    modified = {}
    ApplyToAll()
end

local function EnableVehicleSpeed()
    if isEnabled then return end
    isEnabled = true
    ApplyToAll()
    
    if not connection then
        connection = S.Runtime.Connect(Vehicles.ChildAdded, function(vehicle)
            task.wait(0.5)
            if isEnabled and vehicle:FindFirstChild("Config") and not modified[vehicle] then
                ApplySpeedToVehicle(vehicle)
            end
        end)
    end
end

local function DisableVehicleSpeed()
    if not isEnabled then return end
    isEnabled = false
    RestoreAll()
    
    if connection then
        S.Runtime.Disconnect(connection)
        connection = nil
    end
end

local speedToggle = VehicleFlySection:AddLabel('Vehicle Speed')
speedToggle:AddToggle({
    Default = false,
    Flag = "VehicleSpeed",
    Callback = function(v)
        if v then
            EnableVehicleSpeed()
        else
            DisableVehicleSpeed()
        end
    end
})

local speedOptions = speedToggle:AddOption()

speedOptions:AddLabel('Drive Speed Multiplier'):AddSlider({
    Min = 1,
    Max = 5,
    Default = 2,
    Flag = "VehicleDriveSpeed",
    Value = 2,
    Callback = function(v)
        driveMultiplier = v
        if isEnabled then
            ReapplyVehicleSpeed()
        end
    end
})

speedOptions:AddLabel('Reverse Speed Multiplier'):AddSlider({
    Min = 1,
    Max = 5,
    Default = 2,
    Flag = "VehicleReverseSpeed",
    Value = 2,
    Callback = function(v)
        reverseMultiplier = v
        if isEnabled then
            ReapplyVehicleSpeed()
        end
    end
})


    local interactables = Fw["Classes"]["Interactables"]

	S.Runtime.AddMethodHook(interactables, "GetInteractPromptData", "Interactables.Instant", function(nextPrompt, ...)
		local dt_ = nextPrompt(...)
        if S.iIE and dt_.Actions and dt_.Actions[1] then
            dt_.Actions[1].Time = 0
        end
        return dt_
	end)

    GameSection:AddLabel('Instant Interact'):AddToggle({
        Default = false,
        Flag = "InstantInteract",
        Callback = function(v)
            S.iIE = v
        end
    })

    local nL = Fw["Libraries"]["Network"]
	S.Runtime.AddMethodHook(nL, "Send", "Network.ContainerPersistence", function(nextSend, self, ...)
		local ev_ = select(1, ...)
        if ev_ == "Inventory Closed" and S.cPE then
            return
        end
		return nextSend(self, ...)
	end)

    GameSection:AddLabel('Container Persistence'):AddToggle({
        Default = false,
        Flag = "ContainerPersistence",
        Callback = function(v)
            S.cPE = v
        end
    })

	S.Runtime.AddCleanup(function()
		dFl()
		DisableVehicleSpeed()
		iFu = false
	end)
end

function S.Runtime.CreateSettingsTab()
	local SettingsTab = win:AddTab({ Name = "Settings" })
	local ConfigSection = SettingsTab:AddSection({ Name = "CONFIGURATION" })
	local InterfaceSection = SettingsTab:AddSection({ Name = "INTERFACE", Position = "right" })
	local configLibrary = win.Config
	local configName = configLibrary and configLibrary:GetSelected() or "Default"

	if configLibrary then
		local configs = configLibrary:GetConfigs()
		if #configs == 0 then configs = { "Default" } end
		if not table.find(configs, configName) then
			configName = configs[1]
			configLibrary:SetSelected(configName)
		end

		local configDropdown
		configDropdown = ConfigSection:AddLabel('Selected Config'):AddDropdown({
			Default = configName,
			Values = configs,
			Callback = function(value)
				configName = value
				configLibrary:SetSelected(value)
			end,
		})

		local nameInput = ConfigSection:AddLabel('Config Name'):AddTextInput({
			Default = configName,
			Placeholder = "Config name",
			Callback = function(value) configName = value end,
		})

		local function refreshConfigs(preferred)
			local values = configLibrary:GetConfigs()
			if #values == 0 then values = { "Default" } end
			configDropdown:SetValues(values)
			local selected = preferred or configLibrary:GetSelected()
			if not table.find(values, selected) then selected = values[1] end
			configLibrary:SetSelected(selected)
			configDropdown:SetValue(selected)
			nameInput:SetValue(selected)
		end

		ConfigSection:AddButton({
			Name = 'Create / Save Config',
			Callback = function()
				if configLibrary:Save(configName) then
					refreshConfigs(configLibrary:GetSelected())
				else
					Notif.new({ Title = "Config", Content = "Enter a valid config name.", Duration = 3 })
				end
			end,
		})

		ConfigSection:AddButton({
			Name = 'Load Config',
			Callback = function()
				if not configLibrary:Load(configLibrary:GetSelected()) then
					Notif.new({ Title = "Config", Content = "The selected config could not be loaded.", Duration = 3 })
				end
			end,
		})

		ConfigSection:AddButton({
			Name = 'Delete Config',
			Callback = function()
				if configLibrary:Delete(configLibrary:GetSelected()) then
					refreshConfigs()
				else
					Notif.new({ Title = "Config", Content = "The selected config could not be deleted.", Duration = 3 })
				end
			end,
		})

		ConfigSection:AddButton({
			Name = 'Refresh Configs',
			Callback = refreshConfigs,
		})
	else
		ConfigSection:AddLabel('Config system unavailable')
	end

	InterfaceSection:AddLabel("Menu Keybind"):AddKeybind({
		Default = win.Keybind or 'End',
		Flag = "MenuKeybind",
		Callback = function(value) win.Keybind = value end,
	})

	InterfaceSection:AddLabel('Menu Scale'):AddDropdown({
		Default = "Default",
		Values = { "Default", "Large", "Mobile", "Small" },
		Flag = "MenuScale",
		Callback = function(value) win:SetSize(NL.Scales[value]) end,
	})

	InterfaceSection:AddLabel('Incognito Mode'):AddToggle({
		Default = false,
		Flag = "IncognitoMode",
		Callback = S.Runtime.SetIncognitoMode,
	})

	InterfaceSection:AddLabel('Performance Mode'):AddToggle({
		Default = false,
		Flag = "PerformanceMode",
		Callback = function(value) S.PerformanceMode = value end,
	})

	InterfaceSection:AddLabel('Watermark'):AddToggle({
		Default = true,
		Flag = "Watermark",
		Callback = function(value) WM:SetRender(value) end,
	})

	InterfaceSection:AddButton({
		Name = 'Discord',
		Callback = function()
			setclipboard("https://discord.gg/scriptzroblox")
			Notif.new({
				Title = "Discord",
				Content = "Copied Discord invite link",
				Duration = 5,
			})
		end,
	})

	InterfaceSection:AddButton({
		Name = 'Unload',
		ToolTip = 'Restore changed values and remove Sake.lua',
		Callback = function() S.Runtime.Unload() end,
	})
end

S.Runtime.CreateSettingsTab()
S.Runtime.CreateSettingsTab = nil

function S.Runtime.UnloadInternal()
	if S.Runtime.Unloaded then return end
	pcall(S.Runtime.SetHitNotify, false)
	pcall(S.Runtime.SetHitboxEnabled, false)
	pcall(S.Runtime.SetZombieCircle, false)
	S.Runtime.Unloaded = true

	S.AimbotEnabled = false
	S.SilentEnabled = false
	S.SilentPrediction = false
	S.SilentNoSpread = false
	S.BulletManipulation = false
	S.WallbangEnabled = false
	S.NoRecoilEnabled = false
	S.SnapLine = false
	S.FOVEnabled = false
	S.walkEnabled = false
	S.runEnabled = false
	S.isRunning = false
	S.doubleJumpEnabled = false
	S.AthleticGearEnabled = false
	S.ClimbingGearEnabled = false
	S.RandomEventAlerts = false
	S.iFE = false
	S.aSE = false
	S.instantReloadEnabled = false
	S.autoReloadEnabled = false
	S.PerformanceMode = false
	pcall(S.Runtime.SetIncognitoMode, false)
	S.iIE = false
	S.cPE = false
	S.ab_en = false
	S.o_c = false
	S.o_d = false
	S.Runtime.SilentShotDirection = nil
	sc_set.enabled = false
	gc_set.enabled = false
	ec.Enabled = false
	cs.enabled = false
	vs.enabled = false
	zs.enabled = false
	ls.enabled = false
	ch.Enabled = false
	tr_set.Enabled = false
	cr_set.enabled = false
	table.clear(S.Runtime.PendingShotsByKey)
	table.clear(S.Runtime.HitNotificationQueue)
	table.clear(S.Runtime.EventAlertQueue)
	if S.Runtime.FreezeZombieAdded then S.Runtime.Disconnect(S.Runtime.FreezeZombieAdded) end
	if S.Runtime.FreezeZombieRemoved then S.Runtime.Disconnect(S.Runtime.FreezeZombieRemoved) end

	for connection in pairs(S.Runtime.Connections) do
		pcall(function() connection:Disconnect() end)
	end
	table.clear(S.Runtime.Connections)
	table.clear(S.Runtime.Workers)

	for index = #S.Runtime.Cleanups, 1, -1 do
		pcall(S.Runtime.Cleanups[index])
	end
	table.clear(S.Runtime.Cleanups)

	for head, original in pairs(oHP) do
		pcall(function()
			if head.Parent then
				head.Size = original.Size
				head.Transparency = original.Transparency
				head.CanCollide = original.CanCollide
				head.Massless = original.Massless
			end
		end)
	end
	table.clear(oHP)

	for humanoid, speed in pairs(S.Runtime.WalkSpeeds) do
		pcall(function()
			if humanoid.Parent then humanoid.WalkSpeed = speed end
		end)
	end
	table.clear(S.Runtime.WalkSpeeds)

	while next(S.Runtime.ZombieStates) do
		local zombie = next(S.Runtime.ZombieStates)
		if not pcall(ufzZ, zombie) then S.Runtime.ZombieStates[zombie] = nil end
	end
	for root, cframe in pairs(S.Runtime.ZombieCFrames) do
		pcall(function()
			if root.Parent then root.CFrame = cframe end
		end)
	end
	table.clear(S.Runtime.ZombieCFrames)
	pcall(function() tPJ(false) end)

	for player in pairs(ea) do
		pcall(function() cln(player) end)
	end
	pcall(u_ces)
	pcall(u_vhe)
	pcall(u_zbe)
	for model in pairs(el) do
		pcall(function() r_le(model) end)
	end

	pcall(function()
		FC.Visible = false
		FO.Visible = false
		SL.Visible = false
		SO.Visible = false
		FC:Remove()
		FO:Remove()
		SL:Remove()
		SO:Remove()
	end)

	pcall(function()
		local lighting = S.Runtime.Lighting
		lt.FogStart = lighting.FogStart
		lt.FogEnd = lighting.FogEnd
		lt.FogColor = lighting.FogColor
		lt.GlobalShadows = lighting.GlobalShadows
		lt.Ambient = lighting.Ambient
		lt.OutdoorAmbient = lighting.OutdoorAmbient
		lt.ClockTime = lighting.ClockTime
		if lighting.Technology then lt.Technology = lighting.Technology end
	end)

	pcall(function()
		local atmosphere = S.Runtime.Atmosphere
		if atmosphere and atmosphere.Instance and atmosphere.Instance.Parent then
			atmosphere.Instance.Density = atmosphere.Density
			atmosphere.Instance.Haze = atmosphere.Haze
			atmosphere.Instance.Glare = atmosphere.Glare
			atmosphere.Instance.Offset = atmosphere.Offset
			atmosphere.Instance.Color = atmosphere.Color
			atmosphere.Instance.Decay = atmosphere.Decay
		end
	end)

	pcall(function()
		local clouds = S.Runtime.Clouds
		if clouds and clouds.Instance and clouds.Instance.Parent then
			clouds.Instance.Enabled = clouds.Enabled
			clouds.Instance.Color = clouds.Color
			clouds.Instance.Cover = clouds.Cover
			clouds.Instance.Density = clouds.Density
		end
	end)

	pcall(function()
		for _, child in ipairs(lt:GetChildren()) do
			if child:IsA("Sky") then
				child:Destroy()
			elseif child:IsA("SunRaysEffect") or child:IsA("ColorCorrectionEffect") or child:IsA("BloomEffect") then
				local original = S.Runtime.Effects[child]
				if original then
					child.Enabled = original.Enabled
					if child:IsA("ColorCorrectionEffect") then
						child.Saturation = original.Saturation
						child.Contrast = original.Contrast
						child.Brightness = original.Brightness
					elseif child:IsA("BloomEffect") then
						child.Intensity = original.Intensity
						child.Size = original.Size
						child.Threshold = original.Threshold
					end
				else
					child:Destroy()
				end
			end
		end
		for _, sky in ipairs(S.Runtime.Skies) do
			sky.Parent = lt
		end
	end)

	for instance in pairs(S.Runtime.Instances) do
		pcall(function() instance:Destroy() end)
	end
	table.clear(S.Runtime.Instances)

	pcall(function() NL:Unload() end)
	if getgenv().SakeRuntime == S.Runtime then
		getgenv().SakeRuntime = nil
	end
end

function S.Runtime.PerformUnload()
	local previousIdentity = getthreadidentity()
	local promoted = pcall(setthreadidentity, 8)
	local ok, message = xpcall(S.Runtime.UnloadInternal, function(err)
		return tostring(err)
	end)

	-- The interface must disappear even when a feature cleanup fails.
	pcall(function() NL:Unload() end)
	pcall(function()
		if NL.ScreenGui then NL.ScreenGui:Destroy() end
	end)
	if getgenv().SakeRuntime == S.Runtime then getgenv().SakeRuntime = nil end
	if getgenv().SakeGui == NL.ScreenGui then getgenv().SakeGui = nil end

	if promoted then pcall(setthreadidentity, previousIdentity) end
	if not ok then S.Runtime.ReportError("Unload", message) end
end

function S.Runtime.Unload()
	S.Runtime.UnloadRequested = true
end

getgenv().SakeRuntime = S.Runtime

task.spawn(function()
	while not S.Runtime.UnloadRequested do
		task.wait(0.05)
	end
	S.Runtime.PerformUnload()
end)

Notif.new({
	Title = "Sake.lua",
	Content = "Menu loaded successfully",
	Duration = 3,
})

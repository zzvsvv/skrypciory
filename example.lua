local LibraryUrl = "https://raw.githubusercontent.com/zzvsvv/skrypciory/refs/heads/main/x.lua"
local Library = loadstring(game:HttpGet(LibraryUrl .. "?cache=" .. tostring(os.time())))()

Library.UnloadEnabled = true
Library:SetAccentColor(Color3.fromRGB(242, 157, 198))

local Window = Library:CreateWindow({
	Name = "Astra",
	Content = "Glass UI example",
	Size = UDim2.fromOffset(720, 520),
	ConfigFolder = "AstraExampleConfigs",
	Keybind = "Insert",
})

local Notifications = Library:CreateNotification()
local Logger = Library:CreateLogger()
local Indicators = Library:CreateIndicator()
local AimIndicator = Indicators.new({
	Name = "Aim assist",
	Icon = "crosshairs",
	Color = "Green",
})

local State = {
	AimAssist = false,
	FieldOfView = 90,
	TargetBone = "Head",
	Esp = true,
	WalkSpeed = 16,
}

Window:AddTabLabel("MODULES")

local CombatTab = Window:AddTab({
	Name = "Combat",
	Icon = "crosshairs",
	Type = "Double",
})

local AimSection = CombatTab:AddSection({
	Name = "AIM ASSIST",
	Position = "left",
})

local AimRow = AimSection:AddLabel("Aim assist")
AimRow:ToolTip("Tracks the selected target while the bind is held.")
AimRow:AddKeybind({
	Default = "Q",
	Flag = "AimKey",
	Blacklist = { "Insert" },
	Callback = function(key)
		Logger.new("gear", "Aim key changed to " .. tostring(key), 2)
	end,
})
AimRow:AddToggle({
	Default = State.AimAssist,
	Flag = "AimAssist",
	Callback = function(value)
		State.AimAssist = value
		AimIndicator:SetRender(value)
	end,
})

local AimOptions = AimRow:AddOption(1)
AimOptions:AddLabel("Field of view"):AddSlider({
	Default = State.FieldOfView,
	Min = 20,
	Max = 180,
	Type = "°",
	Rounding = 0,
	Flag = "AimFov",
	Callback = function(value)
		State.FieldOfView = value
	end,
})
AimOptions:AddLabel("Target bone"):AddDropdown({
	Default = State.TargetBone,
	Values = { "Head", "Upper torso", "Humanoid root" },
	Flag = "TargetBone",
	Size = 120,
	Callback = function(value)
		State.TargetBone = value
	end,
})

local TriggerRow = AimSection:AddLabel("Trigger bot")
TriggerRow:AddToggle({
	Default = false,
	Flag = "TriggerBot",
	Callback = function(value)
		Logger.new("crosshairs", value and "Trigger bot enabled" or "Trigger bot disabled", 2)
	end,
})

AimSection:AddLabel("Hit chance"):AddSlider({
	Default = 75,
	Min = 0,
	Max = 100,
	Type = "%",
	Rounding = 0,
	Flag = "HitChance",
	Callback = function() end,
})

local VisualSection = CombatTab:AddSection({
	Name = "VISUALS",
	Position = "right",
})

local EspRow = VisualSection:AddLabel("Player ESP")
EspRow:AddColorPicker({
	Default = Color3.fromRGB(242, 157, 198),
	Flag = "EspColor",
	Callback = function(color)
		Logger.new("pencil-square", "ESP color updated: #" .. color:ToHex(), 2)
	end,
})
EspRow:AddToggle({
	Default = State.Esp,
	Flag = "PlayerEsp",
	Callback = function(value)
		State.Esp = value
	end,
})

VisualSection:AddLabel("ESP elements"):AddDropdown({
	Default = { "Box", "Name", "Health" },
	Values = { "Box", "Name", "Health", "Distance", "Tool" },
	Multi = true,
	Flag = "EspElements",
	Size = 125,
	Callback = function() end,
})

VisualSection:AddLabel("Maximum distance"):AddSlider({
	Default = 1500,
	Min = 100,
	Max = 5000,
	Type = "m",
	Rounding = 0,
	Flag = "EspDistance",
	Callback = function() end,
})

VisualSection:AddButton({
	Name = "Preview notification",
	Icon = "chevron-large-right",
	ToolTip = "Shows the glass notification style.",
	Callback = function()
		Notifications.new({
			Title = "Astra",
			Content = "The interface is ready.",
			Duration = 4,
		})
	end,
})

local PlayerTab = Window:AddTab({
	Name = "Player",
	Icon = "gear",
	Type = "Double",
})

local MovementSection = PlayerTab:AddSection({
	Name = "MOVEMENT",
	Position = "left",
})

MovementSection:AddLabel("Walk speed"):AddSlider({
	Default = State.WalkSpeed,
	Min = 8,
	Max = 100,
	Rounding = 0,
	Flag = "WalkSpeed",
	Callback = function(value)
		State.WalkSpeed = value
	end,
})

MovementSection:AddLabel("Movement mode"):AddDropdown({
	Default = "Default",
	Values = { "Default", "Bunny hop", "Flight" },
	Flag = "MovementMode",
	Size = 115,
	Callback = function(value)
		Logger.new("gear", "Movement mode: " .. tostring(value), 2)
	end,
})

local UtilitySection = PlayerTab:AddSection({
	Name = "UTILITY",
	Position = "right",
})

UtilitySection:AddLabel("Profile uses your Roblox display name", true)

UtilitySection:AddButton({
	Name = "Reset demo values",
	Icon = "gear",
	Callback = function()
		Library.Flags.AimAssist:SetValue(false)
		Library.Flags.AimFov:SetValue(90)
		Library.Flags.WalkSpeed:SetValue(16)
		Notifications.new({
			Title = "Settings reset",
			Content = "Demo values were restored.",
			Duration = 3,
		})
	end,
})

Window:AddTabLabel("SYSTEM")

local SettingsTab = Window:AddTab({
	Name = "Settings",
	Icon = "pencil-square",
	Type = "Single",
})

local InterfaceSection = SettingsTab:AddSection({
	Name = "INTERFACE",
	Position = "left",
})

InterfaceSection:AddLabel("Accent color"):AddColorPicker({
	Default = Color3.fromRGB(242, 157, 198),
	Flag = "AccentColor",
	Callback = function(color)
		Library:SetAccentColor(color)
	end,
})

InterfaceSection:AddLabel("Window size"):AddDropdown({
	Default = "Default",
	Values = { "Small", "Default", "Large" },
	Flag = "WindowSize",
	Size = 105,
	Callback = function(value)
		Window:SetSize(Library.Scales[value] or Library.Scales.Default)
	end,
})

local WatermarkRow = InterfaceSection:AddLabel("Watermark")
local Watermark = Window:Watermark()
WatermarkRow:AddToggle({
	Default = true,
	Flag = "Watermark",
	Callback = function(value)
		Watermark:SetRender(value)
	end,
})

InterfaceSection:AddButton({
	Name = "Unload interface",
	Icon = "chevron-large-left",
	ToolTip = "Removes the UI and disconnects its tracked signals.",
	Callback = function()
		Library:Unload()
	end,
})

Notifications.new({
	Title = "Astra loaded",
	Content = "Press Insert to show or hide the interface.",
	Duration = 5,
})

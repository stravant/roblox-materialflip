-- Debugging stub to temporarily turn off the plugin easily with Ctrl+Shift+L
if false then
	return
end

--Updated June 2022:
-- * Improved toolbar combiner, based on Module.
-- * Updated the selection to use a Highlight Instance rather than a SelectionBox

--Updated Sept 2023:
-- * Beginning of the era, migrated to git repo.
-- * Fixed code to understand Wedge / CornerWedge part shapes.
-- * Changed structure to Src + Packages.

----[=[
------------------
--DEFAULT VALUES--
------------------
-- has the plugin been loaded?
local loaded = false

-- is the plugin currently active?
local on = false

local mouse;

----------------
--PLUGIN SETUP--
----------------
-- an event that is fired before the plugin deactivates
local deactivatingEvent = Instance.new("BindableEvent")

local mouseCnList = {}

-- create the plugin and toolbar, and connect them to the On/Off activation functions
plugin.Deactivation:Connect(function()
	Off()
end)

local Src = script.Parent
local Packages = Src.Parent.Packages

local createSharedToolbar = require(Packages.createSharedToolbar)

local sharedToolbarSettings = {} :: createSharedToolbar.SharedToolbarSettings
sharedToolbarSettings.CombinerName = "GeomToolsToolbar"
sharedToolbarSettings.ToolbarName = "GeomTools"
sharedToolbarSettings.ButtonName = "MaterialFlip"
sharedToolbarSettings.ButtonIcon = "rbxassetid://4524030533"
sharedToolbarSettings.ButtonTooltip = "Click parts to \"rotate\" the direction that their matieral is pointing in without modifying their position or size."
sharedToolbarSettings.ClickedFn = function()
	if on then
		deactivatingEvent:Fire()
		Off()
	elseif loaded then
		On()
	end
end
createSharedToolbar(plugin, sharedToolbarSettings)

-- Run when the popup is activated.
function On()
	plugin:Activate(true)
	sharedToolbarSettings.Button:SetActive(true)
	on = true
	mouse = plugin:GetMouse(true)
	table.insert(mouseCnList, mouse.Button1Down:Connect(function()
		MouseDown()
	end))
	table.insert(mouseCnList, mouse.Button1Up:Connect(function()
		MouseUp()
	end))
	table.insert(mouseCnList, mouse.Move:Connect(function()
		MouseMove()
	end))
	table.insert(mouseCnList, mouse.Idle:Connect(function()
		MouseIdle()
	end))
	table.insert(mouseCnList, mouse.KeyDown:Connect(function()
		KeyDown()
	end))
	--
	Selected()
end

-- Run when the popup is deactivated.
function Off()
	sharedToolbarSettings.Button:SetActive(false)
	on = false
	for i, cn in pairs(mouseCnList) do
		cn:disconnect()
		mouseCnList[i] = nil
	end
	--
	Deselected()
end

local PLUGIN_NAME = 'MaterialFlip'
function SetSetting(setting, value)
	plugin:SetSetting(PLUGIN_NAME..setting, value)
end
function GetSetting(setting)
	return plugin:GetSetting(PLUGIN_NAME..setting)
end

-----------------------------------------------

local function rightVector(cf)
	local _,_,_,r4,_,_,r7,_,_,r10,_,_ = cf:components()
	return Vector3.new(r4,r7,r10)
end
local function leftVector(cf)
	local _,_,_,r4,_,_,r7,_,_,r10,_,_ = cf:components()
	return Vector3.new(-r4,-r7,-r10)
end
local function topVector(cf)
	local _,_,_,_,r5,_,_,r8,_,_,r11,_ = cf:components()
	return Vector3.new(r5,r8,r11)
end
local function bottomVector(cf)
	local _,_,_,_,r5,_,_,r8,_,_,r11,_ = cf:components()
	return Vector3.new(-r5,-r8,-r11)
end
local function backVector(cf)
	local _,_,_,_,_,r6,_,_,r9,_,_,r12 = cf:components()
	return Vector3.new(r6,r9,r12)
end
local function frontVector(cf)
	local _,_,_,_,_,r6,_,_,r9,_,_,r12 = cf:components()
	return Vector3.new(-r6,-r9,-r12)
end
function CFrameFromTopBack(at, top, back)
	local right = top:Cross(back)
	return CFrame.new(at.x, at.y, at.z,
					  right.x, top.x, back.x,
					  right.y, top.y, back.y,
					  right.z, top.z, back.z)
end

local UniformScale = Vector3.new(1, 1, 1)
function GetShape(part)
	local mesh;
	for _, ch in pairs(part:GetChildren()) do
		if ch:IsA('SpecialMesh') then
			local scale = ch.Scale
			if ch.MeshType == Enum.MeshType.Brick then
				return 'Brick', scale
			elseif ch.MeshType == Enum.MeshType.FileMesh then
				return 'Brick', scale
			elseif ch.MeshType == Enum.MeshType.Torso then
				return 'Brick', scale
			elseif ch.MeshType == Enum.MeshType.CornerWedge then
				return 'CornerWedge', scale
			elseif ch.MeshType == Enum.MeshType.Cylinder then
				return 'Round', scale
			elseif ch.MeshType == Enum.MeshType.Wedge then
				return 'Wedge', scale
			elseif ch.MeshType == Enum.MeshType.Sphere then
				return 'Round', scale
			elseif ch.MeshType == Enum.MeshType.Head then	
				return 'Round', scale
			else
				spawn(function() 
					error("GapFill: Unsupported Mesh Type, treating as a normal brick.")
				end)
			end
		end
	end
	if part:IsA('WedgePart') then
		return 'Wedge', UniformScale
	elseif part:IsA('CornerWedgePart') then
		return 'CornerWedge', UniformScale
	elseif part:IsA('Terrain') then
		return 'Terrain', UniformScale
	elseif part:IsA('UnionOperation') then
		return 'Brick', UniformScale
	elseif part:IsA('Part') then
		-- Part
		if part.Shape == Enum.PartType.Ball then
			return 'Round', UniformScale
		elseif part.Shape == Enum.PartType.Cylinder then
			return 'Round', UniformScale
		elseif part.Shape == Enum.PartType.Block then
			return 'Brick', UniformScale
		elseif part.Shape == Enum.PartType.Wedge then
			return 'Wedge', UniformScale
		elseif part.Shape == Enum.PartType.CornerWedge then
			return 'CornerWedge', UniformScale
		else
			assert(false, "Unreachable")
		end
	else
		-- Assume a brick
		return 'Brick', UniformScale
	end
end

local function Flippable(part)
	if not part then return false end
	if part.Locked then return false end
	local shape = GetShape(part)
	return shape == 'Brick' or shape == 'Wedge' or shape == 'Round'
end

local function Flip(part, point, norm)
	part:BreakJoints()
	local cf = part.CFrame
	if GetShape(part) == 'Wedge' then
		-- wedge
		local front = frontVector(cf)
		local top = topVector(cf)
		part.TopSurface, part.FrontSurface = part.FrontSurface, part.TopSurface
		part.BottomSurface, part.BackSurface = part.BackSurface, part.BottomSurface
		part.RightSurface, part.LeftSurface = part.LeftSurface, part.RightSurface
		part.FormFactor = Enum.FormFactor.Custom
		part.Size = Vector3.new(part.Size.X, part.Size.Z, part.Size.Y)
		part:BreakJoints()
		part.CFrame = CFrameFromTopBack(cf.Position, front, -top)
	elseif GetShape(part) == 'Round' then
		-- ball
		local pos = cf.p 
		local rot = CFrame.fromAxisAngle((point - pos).unit, math.pi)
		part:BreakJoints()
		part.CFrame = (rot * (cf - pos)) + pos
	else
		-- must be a square part
		local pos = cf.p
		local axis = cf:VectorToWorldSpace(Vector3.FromNormalId(norm))
		local rot = CFrame.fromAxisAngle(axis, math.pi/2) 
		local targetCF = (rot * (cf - pos)) + pos
		local targetSize;
		if (frontVector(cf) - axis).Magnitude < 0.001 or (backVector(cf) - axis).magnitude < 0.001 then
			targetSize = Vector3.new(part.Size.Y, part.Size.X, part.Size.Z)
			if (frontVector(cf) - axis).Magnitude < 0.001 then
				part.RightSurface, part.TopSurface, part.LeftSurface, part.BottomSurface = part.BottomSurface, part.RightSurface, part.TopSurface, part.LeftSurface
			else
				part.RightSurface, part.TopSurface, part.LeftSurface, part.BottomSurface = part.TopSurface, part.LeftSurface, part.BottomSurface, part.RightSurface
			end
		elseif (topVector(cf) - axis).Magnitude < 0.001 or (bottomVector(cf) - axis).magnitude < 0.001 then
			targetSize = Vector3.new(part.Size.Z, part.Size.Y, part.Size.X)
			if (topVector(cf) - axis).Magnitude < 0.001 then
				part.FrontSurface, part.RightSurface, part.BackSurface, part.LeftSurface = part.LeftSurface, part.FrontSurface, part.RightSurface, part.BackSurface
			else
				part.FrontSurface, part.RightSurface, part.BackSurface, part.LeftSurface = part.RightSurface, part.BackSurface, part.LeftSurface, part.FrontSurface
			end
		else
			targetSize = Vector3.new(part.Size.X, part.Size.Z, part.Size.Y)
			if (rightVector(cf) - axis).Magnitude < 0.001 then
				part.TopSurface, part.FrontSurface, part.BottomSurface, part.BackSurface = part.BackSurface, part.TopSurface, part.FrontSurface, part.BottomSurface
			else
				part.TopSurface, part.FrontSurface, part.BottomSurface, part.BackSurface = part.FrontSurface, part.BottomSurface, part.BackSurface, part.TopSurface
			end
		end
		part.Size = targetSize
		part:BreakJoints() -- Needed to "unstick" hinges.
		part.CFrame = targetCF
	end
	game:GetService('ChangeHistoryService'):SetWaypoint("Flip")
end

--------------------------------------------------

local highlight = Instance.new("Highlight")
highlight.Name = "MaterialFlipHighlight"
highlight.FillTransparency = 1
highlight.OutlineColor = settings().Studio["Select Color"]

function MouseDown()
	if Flippable(mouse.Target) then
		Flip(mouse.Target, mouse.Hit.p, mouse.TargetSurface)
	end
end

function MouseUp()

end

function MouseMove()
	if Flippable(mouse.Target) then
		highlight.Adornee = mouse.Target
	else
		highlight.Adornee = nil
	end
end

function MouseIdle()
	MouseMove()
end

function KeyDown()

end

function Selected()
	highlight.Parent = game:GetService("CoreGui")
	MouseMove()
end

function Deselected()
	highlight.Parent = nil
	highlight.Adornee = nil
end

-----------------------------------------------

loaded = true

plugin.Unloading:Connect(function()
	highlight:Destroy()
end)
--]=]
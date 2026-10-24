local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local G = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ImGui"))
local ImGui = G.ImGui
local ImGuiImplRoblox = G.ImGui_ImplRoblox

local M = {}

local function decimalsFor(step)
	return math.max(0, math.ceil(-math.log10(step) - 1e-6))
end

local function snap(def, value)
	local snapped = def.min + math.round((value - def.min) / def.step) * def.step
	return math.clamp(snapped, def.min, def.max)
end

function M.create(options)
	local settings = options.settings
	local formats = {}
	for _, def in ipairs(options.sliders) do
		formats[def.key] = "%." .. decimalsFor(def.step) .. "f"
	end

	ImGui.CreateContext()
	ImGuiImplRoblox.Init()

	RunService.Stepped:Connect(function()
		ImGuiImplRoblox.NewFrame()
		ImGui.NewFrame()

		ImGui.Begin("Cloud Settings")

		for _, def in ipairs(options.sliders) do
			local current = settings[def.key]
			local value, changed
			if def.step % 1 == 0 and def.min % 1 == 0 then
				value, changed = ImGui.SliderInt(def.label, current, def.min, def.max)
			else
				value, changed = ImGui.SliderFloat(def.label, current, def.min, def.max, formats[def.key])
			end
			if changed then
				options.onChange(def, snap(def, value), false)
			end
			if ImGui.IsItemDeactivatedAfterEdit() then
				options.onChange(def, settings[def.key], true)
			end
		end

		if ImGui.Button("New Seed") then
			options.onRegenerate()
		end
		ImGui.SameLine()
		if ImGui.Button("Reset") then
			options.onReset()
		end

		ImGui.End()

		ImGui.Render()
		ImGuiImplRoblox.RenderDrawData(ImGui.GetDrawData())
	end)
end

return M

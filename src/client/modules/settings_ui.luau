local plrs = game:GetService("Players")
local UIS  = game:GetService("UserInputService")

local M = {}

local function create(className, properties, parent)
	local instance = Instance.new(className)
	for name, value in pairs(properties) do
		instance[name] = value
	end
	instance.Parent = parent
	return instance
end

local function addCorner(parent, radius)
	return create("UICorner", { 
    CornerRadius = UDim.new(0, radius) 
  }, parent)
end

local function decimalsFor(step)
	return math.max(0, math.ceil(-math.log10(step) - 1e-6))
end

function M.create(options)
	local theme = options.theme
	local settings = options.settings
	local rows = {}
	local dragging = nil

	local gui = create("ScreenGui", {
		Name = "CloudSettings",
		ResetOnSpawn = false,
		DisplayOrder = 10,
	}, plrs.LocalPlayer:WaitForChild("PlayerGui"))

	local toggle = create("TextButton", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(110, 30),
		BackgroundColor3 = theme.panel,
		Text = "Cloud Settings",
		TextColor3 = theme.text,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		AutoButtonColor = true,
	}, gui)
	addCorner(toggle, 6)

	local panel = create("Frame", {
		Position = UDim2.fromOffset(10, 48),
		Size = UDim2.fromOffset(options.width, options.height),
		BackgroundColor3 = theme.panel,
		BorderSizePixel = 0,
	}, gui)
	addCorner(panel, 8)

	local scroll = create("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -62),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
	}, panel)
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, scroll)

	for order, def in ipairs(options.sliders) do
		local decimals = decimalsFor(def.step)
		local row = create("Frame", {
			Size = UDim2.new(1, -10, 0, 42),
			BackgroundTransparency = 1,
			LayoutOrder = order,
		}, scroll)
		create("TextLabel", {
			Size = UDim2.new(0.65, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = def.label,
			TextColor3 = theme.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
		}, row)
		local valueLabel = create("TextLabel", {
			Position = UDim2.fromScale(0.65, 0),
			Size = UDim2.new(0.35, 0, 0, 18),
			BackgroundTransparency = 1,
			TextColor3 = theme.accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
		}, row)
		local track = create("Frame", {
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, 0, 0, 6),
			BackgroundColor3 = theme.track,
			BorderSizePixel = 0,
		}, row)
		addCorner(track, 3)
		local fill = create("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = theme.accent,
			BorderSizePixel = 0,
		}, track)
		addCorner(fill, 3)
		local knob = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = theme.text,
			BorderSizePixel = 0,
		}, track)
		addCorner(knob, 7)
		local hit = create("TextButton", {
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Text = "",
		}, row)

		local function showValue(value)
			local alpha = (value - def.min) / (def.max - def.min)
			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.fromScale(alpha, 0.5)
			valueLabel.Text = string.format("%." .. decimals .. "f", value)
		end

		local function update(x, committed)
			local alpha = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
			local raw = def.min + alpha * (def.max - def.min)
			local snapped = def.min + math.round((raw - def.min) / def.step) * def.step
			local value = math.clamp(snapped, def.min, def.max)
			showValue(value)
			options.onChange(def, value, committed)
		end

		hit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = update
				scroll.ScrollingEnabled = false
				update(input.Position.X, false)
			end
		end)

		showValue(settings[def.key])
		table.insert(rows, { key = def.key, show = showValue })
	end

	UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement then
			dragging(input.Position.X, false)
		end
	end)

	UIS.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging(input.Position.X, true)
			dragging = nil
			scroll.ScrollingEnabled = true
		end
	end)

	local function createButton(text, xScale, callback)
		local button = create("TextButton", {
			Position = UDim2.new(xScale, xScale == 0 and 8 or 4, 1, -46),
			Size = UDim2.new(0.5, -12, 0, 36),
			BackgroundColor3 = theme.button,
			Text = text,
			TextColor3 = theme.text,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
		}, panel)
		addCorner(button, 6)
		button.Activated:Connect(callback)
	end

	createButton("New Seed", 0, options.onRegenerate)
	createButton("Reset", 0.5, options.onReset)

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	return {
		gui = gui,
		refresh = function()
			for _, row in ipairs(rows) do
				row.show(settings[row.key])
			end
		end,
	}
end

return M

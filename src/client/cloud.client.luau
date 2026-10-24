local _constant = require(script.modules.constants)
local _config_ui = require(script.modules.settings_ui)

local workspace = game:GetService("Workspace")
local RS = game:GetService("RunService")

local function onStart()
	local settings = table.clone(_constant)
	local seed = os.time()
	local rng = Random.new(seed)
	local puffPool = {}
	local freeList = {}
	local clouds = {}
	local moveParts = {}
	local moveCFrames = {}
	local nextCloudId = 0
	local ui

	local cloudsFolder = workspaceService:FindFirstChild(settings.CLOUD_FOLDER_NAME)
	if not cloudsFolder then
		cloudsFolder = Instance.new("Folder")
		cloudsFolder.Name = settings.CLOUD_FOLDER_NAME
		cloudsFolder.Parent = workspaceService
	end

	local function fbm3d(x, y, z, octaves, persistence, lacunarity, scale)
		local total = 0
		local frequency = 1
		local amplitude = 1
		local maxVal = 0
		for _ = 1, octaves do
			local n = math.noise(
				(x + seed) * scale * frequency,
				(y + seed) * scale * frequency,
				(z + seed) * scale * frequency
			)
			total += n * amplitude
			maxVal += amplitude
			amplitude *= persistence
			frequency *= lacunarity
		end
		return (total / maxVal + 1) / 2
	end

	local function cloudNoise(x, z)
		return fbm3d(
			x,
			0,
			z,
			settings.NOISE_OCTAVES,
			settings.NOISE_PERSISTENCE,
			settings.NOISE_LACUNARITY,
			settings.NOISE_SCALE
		)
	end

	local function newPuffPart()
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Color = settings.CLOUD_COLOR
		part.Transparency = settings.CLOUD_TRANSPARENCY
		return part
	end

	local function acquirePuff()
		local n = #freeList
		if n > 0 then
			local part = freeList[n]
			freeList[n] = nil
			return part
		end
		if #puffPool < settings.POOL_MAX then
			local part = newPuffPart()
			table.insert(puffPool, part)
			return part
		end
		return nil
	end

	local function releaseAllPuffs()
		table.clear(freeList)
		for i, puff in ipairs(puffPool) do
			puff.Parent = nil
			freeList[i] = puff
		end
	end

	local function applyTransparency()
		for _, puff in ipairs(puffPool) do
			puff.Transparency = settings.CLOUD_TRANSPARENCY
		end
	end

	local function generateCloud(origin)
		nextCloudId += 1
		local cloud = {
			origin = origin,
			puffs = {},
			floatOffset = rng:NextNumber(0, 2 * math.pi),
		}
		local folder = Instance.new("Folder")
		folder.Name = "Cloud_" .. nextCloudId
		folder.Parent = cloudsFolder
		cloud.folder = folder

		local spread = settings.CLOUD_PUFF_SPREAD
		local puffCount = rng:NextInteger(settings.CLOUD_PUFF_COUNT_MIN, settings.CLOUD_PUFF_COUNT_MAX)
		for _ = 1, puffCount do
			local angle = rng:NextNumber(0, 2 * math.pi)
			local dist = spread * math.sqrt(rng:NextNumber())
			local offsetX = math.cos(angle) * dist
			local offsetZ = math.sin(angle) * dist
			local dome = 1 - dist / spread
			local offsetY = rng:NextNumber() * dome * settings.CLOUD_PUFF_HEIGHT

			local noiseVal = cloudNoise(origin.X + offsetX, origin.Z + offsetZ)
			local variants = settings.CLOUD_PUFF_SIZE_VARIANTS
			local sizeTemplate = variants[rng:NextInteger(1, #variants)]
			local size = Vector3.new(
				rng:NextNumber(sizeTemplate.X * 0.8, sizeTemplate.X * 1.2) * (0.8 + noiseVal * 0.4),
				rng:NextNumber(sizeTemplate.Y * 0.8, sizeTemplate.Y * 1.2) * (0.7 + noiseVal * 0.6),
				rng:NextNumber(sizeTemplate.Z * 0.8, sizeTemplate.Z * 1.2) * (0.8 + noiseVal * 0.4)
			)
			local localOffset = Vector3.new(
				offsetX + (noiseVal - 0.5) * 40,
				offsetY,
				offsetZ + (noiseVal - 0.5) * 40
			)
			local part = acquirePuff()
			if part then
				part.Size = size
				part.Position = origin + localOffset
				part.Parent = folder
				table.insert(cloud.puffs, { part = part, localOffset = localOffset })
			end
		end
		return cloud
	end

	local function generateAllClouds()
		releaseAllPuffs()
		for _, cloud in ipairs(clouds) do
			cloud.folder:Destroy()
		end
		clouds = {}
		nextCloudId = 0
		table.clear(moveParts)
		table.clear(moveCFrames)

		local cloudsPerLevel = settings.CLOUD_CLUSTERS_PER_LEVEL * settings.CLOUD_PER_CLUSTER
		local neededPuffs = #settings.CLOUD_LEVELS * cloudsPerLevel * settings.CLOUD_PUFF_COUNT_MAX
		
    if neededPuffs > settings.POOL_MAX then
			warn(
				("POOL_MAX (%d) is smaller than the max puffs that could be requested (%d) — some clouds may render incomplete.")
					:format(settings.POOL_MAX, neededPuffs)
			)
		end

		local space = settings.CLOUD_SPACE_SIZE
		local radius = settings.CLOUD_CLUSTER_RADIUS
		
    for _, levelY in ipairs(settings.CLOUD_LEVELS) do
			for _ = 1, settings.CLOUD_CLUSTERS_PER_LEVEL do
        local centerX = rng:NextNumber(-space, space)
				local centerZ = rng:NextNumber(-space, space)
				
        for _ = 1, settings.CLOUD_PER_CLUSTER do
          local x = centerX
					local z = centerZ
				
          for _ = 1, 10 do
						local angle = rng:NextNumber(0, 2 * math.pi)
						local dist = radius * math.sqrt(rng:NextNumber())
						
            x = math.clamp(centerX + math.cos(angle) * dist, -space, space)
						z = math.clamp(centerZ + math.sin(angle) * dist, -space, space)
						
            local density = fbm3d(
							x,
							0,
							z,
							settings.NOISE_OCTAVES,
							settings.NOISE_PERSISTENCE,
							settings.NOISE_LACUNARITY,
							settings.CLUSTER_NOISE_SCALE
						)
						
            if density >= settings.CLUSTER_THRESHOLD then
							break
						end

					end
					
          local origin = Vector3.new(x, levelY + rng:NextNumber(-5, 5), z)
					table.insert(clouds, generateCloud(origin))
				end
			end
		end

		for _, cloud in ipairs(clouds) do
			for _, puffData in ipairs(cloud.puffs) do
				table.insert(moveParts, puffData.part)
				table.insert(moveCFrames, CFrame.new(puffData.part.Position))
			end
		end
	end

	local function updateClouds(dt)
		local areaSize = settings.CLOUD_SPACE_SIZE
		local diameter = areaSize * 2
		
    local now = os.clock()
		local angle = math.rad(settings.CLOUD_DIRECTION_ANGLE)
		
    local direction = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local index = 0
		
    for _, cloud in ipairs(clouds) do
			local newOrigin = cloud.origin + direction * settings.CLOUD_DRIFT_SPEED * dt

			if newOrigin.X < -areaSize then
				newOrigin += Vector3.new(diameter, 0, 0)
			elseif newOrigin.X > areaSize then
				newOrigin -= Vector3.new(diameter, 0, 0)
			end

			if newOrigin.Z < -areaSize then
				newOrigin += Vector3.new(0, 0, diameter)
			elseif newOrigin.Z > areaSize then
				newOrigin -= Vector3.new(0, 0, diameter)
			end
			cloud.origin = newOrigin

			local floatY = math.sin(now * settings.CLOUD_FLOAT_SPEED + cloud.floatOffset) * settings.CLOUD_FLOAT_AMPLITUDE
			local verticalOffset = Vector3.new(0, floatY, 0)
			
      for _, puffData in ipairs(cloud.puffs) do
				index += 1
				moveCFrames[index] = CFrame.new(newOrigin + puffData.localOffset + verticalOffset)
			end
		end
		workspaceService:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	generateAllClouds()
	runService.Heartbeat:Connect(updateClouds)

	ui = _config_ui.create({
		settings = settings,
		sliders = _constant.UI_SLIDERS,
		theme = _constant.UI_THEME,
		width = _constant.UI_WIDTH,
		height = constants_.UI_HEIGHT,
		
    onChange = function(def, value, committed)
			settings[def.key] = value
			if def.key == "CLOUD_TRANSPARENCY" then
				applyTransparency()
			end
			if committed and not def.live then
				generateAllClouds()
			end
		end,
		
    onRegenerate = function()
			seed = Random.new():NextInteger(1, 1000000)
			rng = Random.new(seed)
			generateAllClouds()
		end,
		
    onReset = function()
			for _, def in ipairs(_constant.UI_SLIDERS) do
				settings[def.key] = _constant[def.key]
			end
			applyTransparency()
			generateAllClouds()
			ui.refresh()
		end,
	})
end


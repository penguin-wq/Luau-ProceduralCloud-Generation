local workspace_service = game:GetService("Workspace")
local run_service = game:GetService("RunService")

local function fbm_3d(x, y, z, seed, octaves, persistence, lacunarity, scale)
	scale = scale or 0.01
	local total = 0
	local frequency = 1
	local amplitude = 1
	local max_val = 0
	for _ = 1, octaves do
		local n = math.noise(
			(x + seed) * scale * frequency,
			(y + seed) * scale * frequency,
			(z + seed) * scale * frequency
		)
		total += n * amplitude
		max_val += amplitude
		amplitude *= persistence
		frequency *= lacunarity
	end
	return (total / max_val + 1) / 2
end

local SEED = tick()
local MAX_POOL = 3000

local CLOUD_COUNT_PER_LEVEL = 30
local CLOUD_SPACE_SIZE = 900
local CLOUD_DRIFT_SPEED = 5
local CLOUD_FLOAT_AMPLITUDE = 2
local CLOUD_FLOAT_SPEED = 0.3
local CLOUD_LEVELS = { 140, 200, 270, 310, 370 }

local CLOUD_PUFF_COUNT_MIN = 14
local CLOUD_PUFF_COUNT_MAX = 17
local CLOUD_PUFF_SIZE_VARIANTS = {
	Vector3.new(100, 12.50, 80),
	Vector3.new(59, 22.75, 60.15),
	Vector3.new(55.20, 31.33, 61.15),
}
local CLOUD_COLOR = Color3.fromRGB(255, 255, 255)

local rng = Random.new(SEED)
local puff_pool = {}
local free_list = {}

local function new_puff_part()
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = CLOUD_COLOR
	return part
end

local function acquire_puff()
	local n = #free_list
	if n > 0 then
		local part = free_list[n]
		free_list[n] = nil
		return part
	end
	if #puff_pool < MAX_POOL then
		local part = new_puff_part()
		table.insert(puff_pool, part)
		return part
	end

	return nil
end

local function release_all_puffs()
	table.clear(free_list)
	for i, puff in ipairs(puff_pool) do
		puff.Parent = nil
		free_list[i] = puff
	end
end

local clouds = {}
local next_cloud_id = 0

local clouds_folder = workspace_service:FindFirstChild("CloudsFolder")
if not clouds_folder then
	clouds_folder = Instance.new("Folder")
	clouds_folder.Name = "CloudsFolder"
	clouds_folder.Parent = workspace_service
end

local function cloud_noise(x, z)
	return fbm_3d(x, 0, z, SEED, 4, 0.5, 2.0)
end

local function generate_cloud(origin)
	next_cloud_id += 1
	local cloud = {
		origin = origin,
		puffs = {},
		direction = Vector3.new(0, 0, -1),
		float_offset = rng:NextNumber(0, 2 * math.pi),
	}
	local folder = Instance.new("Folder")
	folder.Name = "Cloud_" .. next_cloud_id
	folder.Parent = clouds_folder
	cloud.folder = folder
	local puff_count = rng:NextInteger(CLOUD_PUFF_COUNT_MIN, CLOUD_PUFF_COUNT_MAX)
	for i = 1, puff_count do
		local noise_val = cloud_noise(origin.X + i * 20, origin.Z + i * 20)
		local size_template = CLOUD_PUFF_SIZE_VARIANTS[rng:NextInteger(1, #CLOUD_PUFF_SIZE_VARIANTS)]
		local size = Vector3.new(
			rng:NextNumber(size_template.X * 0.8, size_template.X * 1.2) * (0.8 + noise_val * 0.4),
			rng:NextNumber(size_template.Y * 0.8, size_template.Y * 1.2) * (0.7 + noise_val * 0.6),
			rng:NextNumber(size_template.Z * 0.8, size_template.Z * 1.2) * (0.8 + noise_val * 0.4)
		)
		local local_offset = Vector3.new(
			rng:NextNumber(-60, 60) + noise_val * 40,
			rng:NextNumber(-3, 3),
			rng:NextNumber(-60, 60) + noise_val * 40
		)
		local part = acquire_puff()
		if part then
			part.Size = size
			part.Position = origin + local_offset
			part.Parent = folder
			table.insert(cloud.puffs, { part = part, local_offset = local_offset })
		end
	end
	return cloud
end

local function generate_all_clouds()
	release_all_puffs()
	for _, cloud in ipairs(clouds) do
		cloud.folder:Destroy()
	end
	clouds = {}
	next_cloud_id = 0
	local needed_puffs = #CLOUD_LEVELS * CLOUD_COUNT_PER_LEVEL * CLOUD_PUFF_COUNT_MAX
	if needed_puffs > MAX_POOL then
		warn((
			"MAX_POOL (%d) is smaller than the max puffs that "
				.. "could be requested (%d) — some clouds may render incomplete."
			):format(MAX_POOL, needed_puffs))
	end
	for _, level_y in ipairs(CLOUD_LEVELS) do
		for _ = 1, CLOUD_COUNT_PER_LEVEL do
			local origin = Vector3.new(
				rng:NextNumber(-CLOUD_SPACE_SIZE, CLOUD_SPACE_SIZE),
				level_y + rng:NextNumber(-5, 5),
				rng:NextNumber(-CLOUD_SPACE_SIZE, CLOUD_SPACE_SIZE)
			)
			table.insert(clouds, generate_cloud(origin))
		end
	end
end

local function update_clouds(dt)
	local area_size = CLOUD_SPACE_SIZE
	local diameter = area_size * 2
	for _, cloud in ipairs(clouds) do
		local new_origin = cloud.origin + cloud.direction * CLOUD_DRIFT_SPEED * dt

		if new_origin.X < -area_size then
			new_origin += Vector3.new(diameter, 0, 0)
		elseif new_origin.X > area_size then
			new_origin -= Vector3.new(diameter, 0, 0)
		end

		if new_origin.Z < -area_size then
			new_origin += Vector3.new(0, 0, diameter)
		elseif new_origin.Z > area_size then
			new_origin -= Vector3.new(0, 0, diameter)
		end
		cloud.origin = new_origin

		local float_y = math.sin(tick() * CLOUD_FLOAT_SPEED + cloud.float_offset) * CLOUD_FLOAT_AMPLITUDE
		local vertical_offset = Vector3.new(0, float_y, 0)
		for _, puff_data in ipairs(cloud.puffs) do
			puff_data.part.Position = new_origin + puff_data.local_offset + vertical_offset
		end
	end
end

generate_all_clouds()
run_service.Heartbeat:Connect(update_clouds)

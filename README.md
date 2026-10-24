# Luau Procedural Cloud Generation

A single-script, client-side Roblox cloud system. It generates layers of drifting, bobbing clouds out of anchored parts, recycling them through an object pool, and keeps them moving every frame on `Heartbeat`. Cloud shapes, sizes, and positions are randomized per run, with fractal noise varying how big and how spread out each cloud's puffs are.

## Setup

1. Create a `LocalScript` and paste in the contents of `Client.luau`.
2. Place it in `StarterPlayer > StarterPlayerScripts`.
3. Press Play. Clouds appear in a folder named `CloudsFolder` in the client's `Workspace`.

### Client-Side Only

This script is designed to run as a `LocalScript`. Do not run it as a server `Script`: moving a few thousand anchored parts every frame would replicate constantly to every player.

Because everything is created locally:

- Each player simulates their own sky, and the server and other players never see it.
- The clouds do not match between players unless `SEED` is set to a fixed number. With a fixed seed, every client builds the same layout.
- `CloudsFolder` only exists in the client's view of `Workspace`, so server scripts cannot find it.

## How It Works

### Noise

`fbm_3d` layers several octaves of `math.noise` and normalizes the result to the range 0 to 1:

```lua
local function fbm_3d(x, y, z, seed, octaves, persistence, lacunarity, scale)
```

| Parameter     | Meaning                                                     |
| ------------- | ----------------------------------------------------------- |
| `octaves`     | Number of noise layers summed together                      |
| `persistence` | How much each octave's amplitude shrinks                    |
| `lacunarity`  | How much each octave's frequency grows                      |
| `scale`       | Overall feature size (defaults to `0.01`)                   |

`cloud_noise(x, z)` wraps it with 4 octaves, persistence `0.5`, and lacunarity `2.0`.

### Cloud generation

For each cloud, `generate_cloud(origin)`:

1. Picks a puff count between `CLOUD_PUFF_COUNT_MIN` and `CLOUD_PUFF_COUNT_MAX`.
2. Samples `cloud_noise` at a point offset from the cloud's origin for each puff.
3. Chooses one of the three `CLOUD_PUFF_SIZE_VARIANTS`, randomizes each axis by plus or minus 20 percent, then scales it by the noise value. Width and depth scale between 0.8 and 1.2, and height between 0.7 and 1.3.
4. Offsets the puff from the cloud's origin by up to 60 studs on X and Z, plus a noise-driven push of up to 40 studs, and by up to 3 studs on Y.
5. Takes a part from the pool, sizes and positions it, and parents it to a per-cloud folder.

`generate_all_clouds()` places `CLOUD_COUNT_PER_LEVEL` clouds at each altitude in `CLOUD_LEVELS`, scattered randomly across the square sky area with up to 5 studs of vertical jitter.

### Pooling

| Function              | Behavior                                                          |
| --------------------- | ----------------------------------------------------------------- |
| `acquire_puff()`      | Reuses a free part, creates a new one if under `MAX_POOL`, or returns `nil` |
| `release_all_puffs()` | Unparents every pooled part and returns it to the free list       |

If the pool runs out, the affected cloud simply gets fewer puffs. `generate_all_clouds()` also warns up front when the worst-case puff count exceeds `MAX_POOL`.

### Update loop

Each `Heartbeat`, `update_clouds(dt)`:

1. Moves each cloud's origin along its direction at `CLOUD_DRIFT_SPEED`.
2. Wraps the origin to the opposite side if it leaves the `CLOUD_SPACE_SIZE` square on X or Z.
3. Computes a sine-based vertical bob from `CLOUD_FLOAT_SPEED`, `CLOUD_FLOAT_AMPLITUDE`, and the cloud's phase offset.
4. Repositions every puff as origin plus its stored local offset plus the bob.

## Configuration

All settings are constants near the top of `Script.luau`.

### Layout

| Constant                  | Default                 | Description                                              |
| ------------------------- | ----------------------- | -------------------------------------------------------- |
| `CLOUD_LEVELS`            | `{140, 200, 270, 310, 370}` | Altitudes of each cloud layer, in studs             |
| `CLOUD_COUNT_PER_LEVEL`   | `30`                    | Clouds spawned at each altitude                          |
| `CLOUD_SPACE_SIZE`        | `900`                   | Half-width of the square sky area, in studs, centered on the origin |

### Cloud shape

| Constant                    | Default | Description                                     |
| --------------------------- | ------- | ----------------------------------------------- |
| `CLOUD_PUFF_COUNT_MIN`      | `14`    | Fewest puffs in a cloud                         |
| `CLOUD_PUFF_COUNT_MAX`      | `17`    | Most puffs in a cloud                           |
| `CLOUD_PUFF_SIZE_VARIANTS`  | 3 sizes | Base puff sizes, picked at random per puff      |
| `CLOUD_COLOR`               | White   | Color of every puff                             |

### Motion

| Constant                 | Default | Description                              |
| ------------------------ | ------- | ---------------------------------------- |
| `CLOUD_DRIFT_SPEED`      | `5`     | Drift speed, in studs per second         |
| `CLOUD_FLOAT_AMPLITUDE`  | `2`     | Vertical bob distance, in studs          |
| `CLOUD_FLOAT_SPEED`      | `0.3`   | Bob frequency                            |

### Performance and seeding

| Constant   | Default  | Description                                                        |
| ---------- | -------- | ------------------------------------------------------------------ |
| `MAX_POOL` | `3000`   | Maximum number of puff parts that will ever exist                  |
| `SEED`     | `tick()` | Seeds both the noise and the random generator                      |

With the defaults, the sky holds 150 clouds and between 2,100 and 2,550 puff parts, which fits inside the pool.

## Usage Tips

- **Reproducible skies.** `SEED` defaults to `tick()`, so every run and every player gets a different layout. Set it to a fixed number for the same layout every time, including across clients:

```lua
local SEED = 12345
```

- **Fewer parts.** Lower `CLOUD_COUNT_PER_LEVEL` or the puff count range. The pool cap needs no change when you reduce counts.
- **Change the wind direction.** Each cloud stores a `direction` vector, currently `Vector3.new(0, 0, -1)`. Change it in `generate_cloud` to drift along a different axis.
- **Regenerate at runtime.** Call `generate_all_clouds()` again. It returns every pooled part to the free list, destroys the old cloud folders, and builds a fresh sky.
- **Raising counts.** If you increase cloud or puff counts past `MAX_POOL`, raise `MAX_POOL` too, or clouds will be built with missing puffs.

## Limitations

- **Axis-aligned boxes.** Puffs are never rotated, so clouds read as stacked slabs rather than rounded shapes.
- **Edge wrap-around.** A cloud's whole origin teleports when it crosses the boundary, so a cloud near the edge of the sky area can visibly pop if a player can see that far.
- **Per-frame cost.** Every puff is repositioned every frame on the client, so cost scales directly with cloud and puff counts.
- **Not shared.** Clouds are not replicated, so players see different skies unless `SEED` is fixed.
- **Uniform drift.** All clouds share one direction and speed.
- **Heartbeat connection.** The `Heartbeat` connection is never stored or disconnected, so the loop runs for the life of the script.

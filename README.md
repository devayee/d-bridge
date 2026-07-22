# d-bridge (Still in progress)

A lightweight, framework-agnostic bridge library for FiveM. Write your resource once — it works on **ESX**, **QBCore**, **QBox**, or standalone, with zero extra code from you.

Bridge auto-detects what's running on the server (framework + inventory system) and exposes one unified API. No more `if Config.Framework == 'esx' then ... else ... end` copy-pasted across every resource you write.

## Features

- Auto-detects **ESX**, **QBCore**, **QBox**, or standalone
- Auto-detects **ox_inventory**, **qb-inventory**, or ESX's built-in inventory
- Unified notifications (uses `ox_lib` if present, falls back to framework-native, falls back to GTA native)
- Single, consistent API — no framework-specific branching in your resource
- Can be force-configured (skip auto-detection) via `shared/config.lua`

## Installation

1. Download / clone into your resources folder as `d-bridge`
2. Add `ensure d-bridge` to your `server.cfg` — **above** any resource that depends on it
3. Add `d-bridge` as a `dependency` in the `fxmanifest.lua` of resources that use it

```lua
dependency 'd-bridge'
```

## Usage

### Server-side

```lua
local playerData = exports['d-bridge']:GetPlayerData(source)
-- { source, identifier, name, job = { name, label, grade, onduty }, money = { cash, bank } }

exports['d-bridge']:AddMoney(source, 'bank', 500)
exports['d-bridge']:RemoveMoney(source, 'cash', 100)

local job = exports['d-bridge']:GetJob(source)
exports['d-bridge']:SetJob(source, 'police', 2)

if exports['d-bridge']:HasItem(source, 'water', 1) then
    exports['d-bridge']:RemoveItem(source, 'water', 1)
end

exports['d-bridge']:AddItem(source, 'bread', 1)
exports['d-bridge']:Notify(source, 'Task complete!', 'success')
```

### Client-side

```lua
local playerData = exports['d-bridge']:GetPlayerData()
exports['d-bridge']:Notify('Hello there', 'info')
```

## Supported API

| Function | Side | Description |
|---|---|---|
| `GetPlayerData(src)` | server/client | Normalized player table (works standalone too — session-only) |
| `GetIdentifier(src)` | server | Player's unique identifier |
| `GetMoney(src, account)` | server | Get cash/bank balance |
| `AddMoney(src, account, amount)` | server | Add money |
| `RemoveMoney(src, account, amount)` | server | Remove money |
| `GetJob(src)` | server | Get normalized job table |
| `SetJob(src, job, grade)` | server | Set player job |
| `IsOnDuty(src)` | server | Duty status (tracked in-memory for ESX) |
| `SetDuty(src, bool)` | server | Toggle duty |
| `IsDead(src)` | server | Death status (QBCore only — see caveat below) |
| `Revive(src)` | server | Fires the EMS resource's revive event |
| `HasItem(src, item, count)` | server | Check inventory |
| `AddItem(src, item, count, metadata)` | server | Give item |
| `RemoveItem(src, item, count)` | server | Remove item |
| `GetOwnedVehicles(src, cb)` | server | Async, requires oxmysql |
| `IsVehicleOwned(plate, cb)` | server | Async, requires oxmysql |
| `AddSocietyMoney(society, amount)` | server | Best-effort across society/management resources |
| `CreateCallback(name, cb)` | server | Register a callback handler |
| `TriggerCallback(name, cb, ...)` | client | Call a server callback |
| `Notify(src/message, message, type)` | server/client | Unified notification |
| `GetFramework()` | server/client | Returns detected framework string |
| `GetInventory()` | server | Returns detected inventory string |

### Callbacks example

```lua
-- server
exports['d-bridge']:CreateCallback('myresource:getBalance', function(src, cb, account)
    cb(exports['d-bridge']:GetMoney(src, account))
end)

-- client
exports['d-bridge']:TriggerCallback('myresource:getBalance', function(balance)
    print('Bank balance:', balance)
end, 'bank')
```

### Caveats on best-effort functions

- **`AddSocietyMoney`** and **`Revive`** rely on common default resource/event names (`esx_addonaccount`, `qb-management`, `esx_ambulancejob`, `hospital:client:Revive`). If your server uses different EMS/management resources, override `Config.SocietySystem` / `Config.ReviveEvent` in `shared/config.lua`.
- **`GetOwnedVehicles`** / **`IsVehicleOwned`** require `oxmysql` and assume default `owned_vehicles` / `player_vehicles` table schemas. Adjust `Config.VehicleTable` if yours differ.
- **`IsDead`** currently only reads QBCore's metadata flag — ESX has no native death state, so track it in your own ambulance-job resource and extend this function if you need it there.

## Configuration

Edit `shared/config.lua` to force a specific framework/inventory instead of auto-detecting:

```lua
Config.Framework = 'qbcore' -- instead of 'auto'
Config.Inventory = 'ox_inventory'
```

Set `Config.GithubRepo = 'yourname/bridge'` and keep `Config.CheckVersion = true` to get a console warning when a newer GitHub release is available.


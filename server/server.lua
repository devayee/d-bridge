Bridge = {}
Bridge.Framework = nil
Bridge.Inventory = nil

local ESX = nil
local QBCore = nil

-- Standalone session-only player store (no framework installed)
local StandaloneData = {}

-- ESX has no native duty concept, tracked here per identifier when Config.TrackEsxDuty is true
local EsxDutyState = {}

-- Callback registry for Bridge.CreateCallback / Bridge.TriggerCallback (client -> server -> client)
local Callbacks = {}

-- ================= DETECTION =================

local function DetectFramework()
    if Config.Framework ~= 'auto' then return Config.Framework end

    if GetResourceState('es_extended') == 'started' then
        return 'esx'
    elseif GetResourceState('qbx_core') == 'started' then
        return 'qbox'
    elseif GetResourceState('qb-core') == 'started' then
        return 'qbcore'
    end
    return 'standalone'
end

local function DetectInventory()
    if Config.Inventory ~= 'auto' then return Config.Inventory end

    if GetResourceState('ox_inventory') == 'started' then
        return 'ox_inventory'
    elseif GetResourceState('qb-inventory') == 'started' then
        return 'qb-inventory'
    elseif Bridge.Framework == 'esx' then
        return 'esx_inventory'
    end
    return 'standalone'
end

CreateThread(function()
    Bridge.Framework = DetectFramework()

    if Bridge.Framework == 'esx' then
        ESX = exports['es_extended']:getSharedObject()
    elseif Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
        local coreResource = Bridge.Framework == 'qbox' and 'qbx_core' or 'qb-core'
        QBCore = exports[coreResource]:GetCoreObject()
    end

    Bridge.Inventory = DetectInventory()

    if Config.Debug then
        print(('[bridge] framework: ^2%s^0 | inventory: ^2%s^0'):format(Bridge.Framework, Bridge.Inventory))
    end
end)

-- ================= PLAYER DATA =================

function Bridge.GetPlayerData(src)
    if Bridge.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return nil end
        return {
            source = src,
            identifier = xPlayer.identifier,
            name = xPlayer.getName(),
            job = {
                name = xPlayer.job.name,
                label = xPlayer.job.label,
                grade = xPlayer.job.grade,
                onduty = true
            },
            money = {
                cash = xPlayer.getMoney(),
                bank = xPlayer.getAccount('bank').money
            }
        }
    elseif Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return nil end
        return {
            source = src,
            identifier = Player.PlayerData.citizenid,
            name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
            job = {
                name = Player.PlayerData.job.name,
                label = Player.PlayerData.job.label,
                grade = Player.PlayerData.job.grade.level,
                onduty = Player.PlayerData.job.onduty
            },
            money = {
                cash = Player.PlayerData.money['cash'],
                bank = Player.PlayerData.money['bank']
            }
        }
    end

    -- standalone: minimal session-only player data, no persistence between restarts
    local identifier = GetPlayerIdentifierByType(src, 'license') or ('src:' .. src)
    if not StandaloneData[identifier] then
        StandaloneData[identifier] = {
            job = { name = 'unemployed', label = 'Unemployed', grade = 0, onduty = false },
            money = { cash = 500, bank = 0 }
        }
    end
    local d = StandaloneData[identifier]
    return {
        source = src,
        identifier = identifier,
        name = GetPlayerName(src),
        job = d.job,
        money = d.money
    }
end

function Bridge.GetIdentifier(src)
    local data = Bridge.GetPlayerData(src)
    return data and data.identifier or nil
end

-- ================= MONEY =================

function Bridge.GetMoney(src, account)
    account = account or 'cash'
    local data = Bridge.GetPlayerData(src)
    return data and data.money[account] or 0
end

function Bridge.AddMoney(src, account, amount)
    account = account or 'cash'
    if Bridge.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return false end
        if account == 'cash' then xPlayer.addMoney(amount) else xPlayer.addAccountMoney(account, amount) end
        return true
    elseif Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return false end
        return Player.Functions.AddMoney(account, amount)
    elseif Bridge.Framework == 'standalone' then
        local data = Bridge.GetPlayerData(src)
        if not data then return false end
        StandaloneData[data.identifier].money[account] = (StandaloneData[data.identifier].money[account] or 0) + amount
        return true
    end
    return false
end

function Bridge.RemoveMoney(src, account, amount)
    account = account or 'cash'
    if Bridge.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return false end
        if account == 'cash' then xPlayer.removeMoney(amount) else xPlayer.removeAccountMoney(account, amount) end
        return true
    elseif Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return false end
        return Player.Functions.RemoveMoney(account, amount)
    elseif Bridge.Framework == 'standalone' then
        local data = Bridge.GetPlayerData(src)
        if not data then return false end
        local current = StandaloneData[data.identifier].money[account] or 0
        if current < amount then return false end
        StandaloneData[data.identifier].money[account] = current - amount
        return true
    end
    return false
end

-- ================= JOB =================

function Bridge.GetJob(src)
    local data = Bridge.GetPlayerData(src)
    return data and data.job or nil
end

function Bridge.SetJob(src, job, grade)
    grade = grade or 0
    if Bridge.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return false end
        xPlayer.setJob(job, grade)
        return true
    elseif Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return false end
        Player.Functions.SetJob(job, grade)
        return true
    elseif Bridge.Framework == 'standalone' then
        local data = Bridge.GetPlayerData(src)
        if not data then return false end
        StandaloneData[data.identifier].job.name = job
        StandaloneData[data.identifier].job.grade = grade
        return true
    end
    return false
end

-- ================= DUTY =================

function Bridge.IsOnDuty(src)
    if Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
        local Player = QBCore.Functions.GetPlayer(src)
        return Player and Player.PlayerData.job.onduty or false
    elseif Bridge.Framework == 'esx' then
        local identifier = Bridge.GetIdentifier(src)
        if EsxDutyState[identifier] == nil then return true end -- default on-duty unless tracked off
        return EsxDutyState[identifier]
    elseif Bridge.Framework == 'standalone' then
        local data = Bridge.GetPlayerData(src)
        return data and data.job.onduty or false
    end
    return false
end

function Bridge.SetDuty(src, state)
    if Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return false end
        Player.Functions.SetJobDuty(state)
        return true
    elseif Bridge.Framework == 'esx' then
        if Config.TrackEsxDuty then
            EsxDutyState[Bridge.GetIdentifier(src)] = state
        end
        return true
    elseif Bridge.Framework == 'standalone' then
        local data = Bridge.GetPlayerData(src)
        if not data then return false end
        StandaloneData[data.identifier].job.onduty = state
        return true
    end
    return false
end

-- ================= DEATH / REVIVE =================
-- Best-effort: relies on common EMS resource event names (esx_ambulancejob / qb-ambulancejob).
-- If your server uses a different EMS resource, override Config.ReviveEvent.

function Bridge.IsDead(src)
    if Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
        local Player = QBCore.Functions.GetPlayer(src)
        return Player and Player.PlayerData.metadata['isdead'] or false
    end
    -- ESX / standalone: no reliable native flag, expect the resource calling this to track it themselves
    return false
end

function Bridge.Revive(src)
    local eventName = Config.ReviveEvent
    if eventName == 'auto' then
        eventName = (Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox')
            and 'hospital:client:Revive'
            or 'esx_ambulancejob:revive'
    end
    TriggerClientEvent(eventName, src)
    if Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then Player.Functions.SetMetaData('isdead', false) end
    end
    return true
end

-- ================= VEHICLES =================
-- Requires oxmysql. Best-effort against default table schemas — adjust column names
-- in Config.VehicleTable / queries below if your server customized them.

function Bridge.GetOwnedVehicles(src, cb)
    if GetResourceState('oxmysql') ~= 'started' then
        if Config.Debug then print('[bridge] GetOwnedVehicles requires oxmysql') end
        return cb({})
    end

    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return cb({}) end

    if Bridge.Framework == 'esx' then
        exports.oxmysql:execute(('SELECT * FROM %s WHERE owner = ?'):format(Config.VehicleTable.esx), { identifier }, cb)
    elseif Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
        exports.oxmysql:execute(('SELECT * FROM %s WHERE citizenid = ?'):format(Config.VehicleTable.qbcore), { identifier }, cb)
    else
        cb({})
    end
end

function Bridge.IsVehicleOwned(plate, cb)
    if GetResourceState('oxmysql') ~= 'started' then return cb(false) end

    local tableName = Bridge.Framework == 'esx' and Config.VehicleTable.esx or Config.VehicleTable.qbcore
    exports.oxmysql:scalar(('SELECT 1 FROM %s WHERE plate = ?'):format(tableName), { plate }, function(result)
        cb(result ~= nil)
    end)
end

-- ================= SOCIETY / GANG MONEY =================
-- Best-effort against the common society/management resources per framework.
-- Adjust Config.SocietySystem if your server uses a non-default one.

function Bridge.AddSocietyMoney(society, amount)
    local system = Config.SocietySystem
    if system == 'auto' then
        system = Bridge.Framework == 'esx' and 'esx_addonaccount' or 'qb-management'
    end

    if system == 'esx_addonaccount' and GetResourceState('esx_addonaccount') == 'started' then
        local account = exports['esx_addonaccount']:getSharedAccount('society_' .. society)
        if account then account.addMoney(amount) return true end
    elseif system == 'esx_society' and GetResourceState('esx_society') == 'started' then
        TriggerEvent('esx_society:getSociety', society, function(societyData)
            TriggerEvent('esx_addonaccount:getSharedAccount', societyData.account, function(account)
                account.addMoney(amount)
            end)
        end)
        return true
    elseif system == 'qb-management' and GetResourceState('qb-management') == 'started' then
        exports['qb-management']:AddMoney(society, amount)
        return true
    elseif system == 'qb-banking' and GetResourceState('qb-banking') == 'started' then
        exports['qb-banking']:AddMoney(society, amount)
        return true
    end

    if Config.Debug then print(('[bridge] AddSocietyMoney: no matching society system found for "%s"'):format(society)) end
    return false
end

-- ================= CALLBACKS =================
-- Framework-independent request/response callback system (client -> server -> client).

function Bridge.CreateCallback(name, cb)
    Callbacks[name] = cb
end

RegisterNetEvent('bridge:server:triggerCallback', function(name, requestId, ...)
    local src = source
    if not Callbacks[name] then
        if Config.Debug then print(('[bridge] no callback registered for "%s"'):format(name)) end
        return
    end
    Callbacks[name](src, function(...)
        TriggerClientEvent('bridge:client:callbackResult', src, requestId, ...)
    end, ...)
end)

-- ================= VERSION CHECK =================

CreateThread(function()
    if not Config.CheckVersion or Config.GithubRepo == 'your-name-here/bridge' then return end
    Wait(2000)

    PerformHttpRequest(('https://api.github.com/repos/%s/releases/latest'):format(Config.GithubRepo), function(statusCode, response)
        if statusCode ~= 200 or not response then return end
        local ok, data = pcall(json.decode, response)
        if not ok or not data or not data.tag_name then return end

        local latest = data.tag_name:gsub('^v', '')
        local current = GetResourceMetadata('d-bridge', 'version', 0) or '0.0.0'
        if latest ~= current then
            print(('[bridge] ^3new version available: %s (current: %s) -> https://github.com/%s/releases^0'):format(latest, current, Config.GithubRepo))
        end
    end, 'GET', '', { ['User-Agent'] = 'bridge-versioncheck' })
end)

-- ================= INVENTORY =================

function Bridge.HasItem(src, item, count)
    count = count or 1
    if Bridge.Inventory == 'ox_inventory' then
        local amount = exports.ox_inventory:Search(src, 'count', item)
        return (amount or 0) >= count
    elseif Bridge.Inventory == 'qb-inventory' then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return false end
        local itemData = Player.Functions.GetItemByName(item)
        return itemData ~= nil and itemData.amount >= count
    elseif Bridge.Inventory == 'esx_inventory' then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return false end
        local itemData = xPlayer.getInventoryItem(item)
        return itemData ~= nil and itemData.count >= count
    end
    return false
end

function Bridge.AddItem(src, item, count, metadata)
    count = count or 1
    if Bridge.Inventory == 'ox_inventory' then
        return exports.ox_inventory:AddItem(src, item, count, metadata)
    elseif Bridge.Inventory == 'qb-inventory' then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return false end
        return Player.Functions.AddItem(item, count, false, metadata)
    elseif Bridge.Inventory == 'esx_inventory' then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return false end
        xPlayer.addInventoryItem(item, count)
        return true
    end
    return false
end

function Bridge.RemoveItem(src, item, count)
    count = count or 1
    if Bridge.Inventory == 'ox_inventory' then
        return exports.ox_inventory:RemoveItem(src, item, count)
    elseif Bridge.Inventory == 'qb-inventory' then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return false end
        return Player.Functions.RemoveItem(item, count)
    elseif Bridge.Inventory == 'esx_inventory' then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return false end
        xPlayer.removeInventoryItem(item, count)
        return true
    end
    return false
end

-- ================= NOTIFY =================

function Bridge.Notify(src, message, notifyType)
    TriggerClientEvent('bridge:notify', src, message, notifyType or 'info')
end

-- ================= EXPORTS =================

exports('GetPlayerData', Bridge.GetPlayerData)
exports('GetIdentifier', Bridge.GetIdentifier)
exports('GetMoney', Bridge.GetMoney)
exports('AddMoney', Bridge.AddMoney)
exports('RemoveMoney', Bridge.RemoveMoney)
exports('GetJob', Bridge.GetJob)
exports('SetJob', Bridge.SetJob)
exports('HasItem', Bridge.HasItem)
exports('AddItem', Bridge.AddItem)
exports('RemoveItem', Bridge.RemoveItem)
exports('Notify', Bridge.Notify)
exports('GetFramework', function() return Bridge.Framework end)
exports('GetInventory', function() return Bridge.Inventory end)

exports('IsOnDuty', Bridge.IsOnDuty)
exports('SetDuty', Bridge.SetDuty)
exports('IsDead', Bridge.IsDead)
exports('Revive', Bridge.Revive)
exports('GetOwnedVehicles', Bridge.GetOwnedVehicles)
exports('IsVehicleOwned', Bridge.IsVehicleOwned)
exports('AddSocietyMoney', Bridge.AddSocietyMoney)
exports('CreateCallback', Bridge.CreateCallback)

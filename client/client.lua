Bridge = {}
Bridge.Framework = nil

local ESX = nil
local QBCore = nil

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

CreateThread(function()
    Bridge.Framework = DetectFramework()

    if Bridge.Framework == 'esx' then
        ESX = exports['es_extended']:getSharedObject()
    elseif Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
        local coreResource = Bridge.Framework == 'qbox' and 'qbx_core' or 'qb-core'
        QBCore = exports[coreResource]:GetCoreObject()
    end
end)

function Bridge.GetPlayerData()
    if Bridge.Framework == 'esx' then
        return ESX.GetPlayerData()
    elseif Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
        return QBCore.Functions.GetPlayerData()
    end
    return nil
end

function Bridge.Notify(message, notifyType)
    notifyType = notifyType or 'info'

    if (Config.Notify == 'ox_lib' or Config.Notify == 'auto') and GetResourceState('ox_lib') == 'started' then
        exports.ox_lib:notify({ description = message, type = notifyType })
        return
    end

    if Bridge.Framework == 'esx' then
        ESX.ShowNotification(message)
    elseif Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
        QBCore.Functions.Notify(message, notifyType)
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(message)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

RegisterNetEvent('bridge:notify', function(message, notifyType)
    Bridge.Notify(message, notifyType)
end)

-- ================= CALLBACKS =================
-- Framework-independent request/response callback system (client -> server -> client).

local callbackId = 0
local pendingCallbacks = {}

function Bridge.TriggerCallback(name, cb, ...)
    callbackId = callbackId + 1
    local id = callbackId
    pendingCallbacks[id] = cb
    TriggerServerEvent('bridge:server:triggerCallback', name, id, ...)
end

RegisterNetEvent('bridge:client:callbackResult', function(requestId, ...)
    if pendingCallbacks[requestId] then
        pendingCallbacks[requestId](...)
        pendingCallbacks[requestId] = nil
    end
end)

exports('GetPlayerData', Bridge.GetPlayerData)
exports('Notify', Bridge.Notify)
exports('GetFramework', function() return Bridge.Framework end)
exports('TriggerCallback', Bridge.TriggerCallback)

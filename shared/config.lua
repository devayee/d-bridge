Config = {}

-- 'auto' = detect automatically | or force: 'esx', 'qbcore', 'qbox', 'standalone'
Config.Framework = 'auto'

-- 'auto' = detect automatically | or force: 'ox_inventory', 'qb-inventory', 'esx_inventory', 'standalone'
Config.Inventory = 'auto'

-- 'auto' = detect automatically | or force: 'ox_lib', 'esx', 'qbcore', 'standalone'
Config.Notify = 'auto'

-- Print detected framework/inventory in server console on startup
Config.Debug = true

-- ================= VEHICLES =================
-- Requires oxmysql to be running. Table names as used by each framework by default.
Config.VehicleTable = {
    esx = 'owned_vehicles',    -- columns: owner, plate, vehicle, ...
    qbcore = 'player_vehicles' -- columns: citizenid, plate, vehicle, ...
}

-- ================= SOCIETY / GANG MONEY =================
-- 'esx_society' | 'esx_addonaccount' | 'qb-management' | 'qb-banking' | 'standalone'
-- 'auto' tries the common resource for the detected framework
Config.SocietySystem = 'auto'

-- ================= DUTY =================
-- ESX has no native duty concept — bridge tracks it in-memory per identifier when this is true.
-- Set false if you don't need duty on ESX.
Config.TrackEsxDuty = true

-- ================= DEATH / REVIVE =================
-- Which ambulance/EMS resource's events to use. 'auto' picks the common default per framework.
-- esx default event: 'esx_ambulancejob:revive' | qbcore default: 'hospital:client:Revive'
-- Change these if your server uses a different EMS resource.
Config.ReviveEvent = 'auto'

-- ================= VERSION CHECK =================
Config.CheckVersion = true
Config.GithubRepo = 'devayee/d-bridge' -- 'user/repo' format

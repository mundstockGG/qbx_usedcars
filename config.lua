Config = {}

-- Local market behavior
Config.MarketRadius       = 80.0   -- meters: listings included in F6 market
Config.InteractRadius     = 5.0    -- reserved for extra checks

-- World preview vehicles
Config.SpawnVehiclesInWorld = true
Config.SpawnCheckInterval   = 5000  -- ms (avoid 0s tight loops)
Config.DespawnDistance      = 250.0 -- meters from player

-- Selling requirements
Config.RequireParked      = true    -- vehicle speed <= 1.0 to allow listing
Config.BlacklistedAreas   = {
  -- { coords = vec3(441.0, -981.0, 30.0), radius = 60.0 }, -- Example: Mission Row PD
}

-- Economy
Config.SellFeePercent     = 5       -- fee from seller price
Config.BuyerTaxPercent    = 0       -- extra tax on buyer
Config.MinPrice           = 5000
Config.MaxPrice           = 20000000
Config.MaxListingsPerPlayer = 3

-- Hotkey
Config.MarketKey          = 'F6'

-- Discord webhooks (optional)
Config.Webhooks = {
  Enabled = false,
  Url = '',  -- put your webhook URL here
  Username = 'QBX UsedCars',
  Avatar = ''
}

-- Admin (optional; requires your own permission system integration)
Config.AdminGroups = { 'admin', 'god' } -- adapt to your ACL if needed


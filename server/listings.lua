local QBX = exports['qbx-core']:GetCoreObject()

-- Optional: simple admin gate (replace with your ACL if needed)
local function isAdmin(src)
    if not Config.AdminGroups or #Config.AdminGroups == 0 then return false end
    local Player = QBX.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData then return false end
    local group = Player.PlayerData.group or Player.PlayerData.permission or 'user'
    for _, g in ipairs(Config.AdminGroups) do
        if g == group then return true end
    end
    return false
end

-- UTIL: Discord webhook
local function webhook(title, fields)
    if not (Config.Webhooks and Config.Webhooks.Enabled and Config.Webhooks.Url ~= '') then return end
    local embed = {
        {  -- single rich embed
            ["title"] = title,
            ["type"] = "rich",
            ["color"] = 5814783,
            ["fields"] = fields,
            ["timestamp"] = os.date('!%Y-%m-%dT%H:%M:%S.000Z')
        }
    }
    PerformHttpRequest(Config.Webhooks.Url, function() end, 'POST', json.encode({
        username = Config.Webhooks.Username or 'QBX UsedCars',
        avatar_url = Config.Webhooks.Avatar or '',
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

-- Transfer ownership (QBX)
local function transferOwnership(listing, newCid, cb)
    MySQL.update(
        'UPDATE player_vehicles SET citizenid = ?, state = 1 WHERE plate = ? AND citizenid = ?',
        { newCid, listing.plate, listing.seller_cid },
        function(affected)
            cb(affected and affected > 0)
        end
    )
end

-- Pay seller (online only stub; add offline if desired)
local function paySeller(listing, amount)
    local sellerPlayer = QBX.Functions.GetPlayerByCitizenId and QBX.Functions.GetPlayerByCitizenId(listing.seller_cid)
    if sellerPlayer then
        local sellerSrc = sellerPlayer.PlayerData.source
        sellerPlayer.Functions.AddMoney('bank', amount, 'usedcar-sell')
        lib.notify(sellerSrc, {
            type = 'info',
            description = ('Your vehicle [%s] was sold for $%s (after fees).'):format(listing.plate, amount)
        })
    else
        -- TODO: implement offline crediting to accounts table or pending payouts
        print(('[qbx_usedcars] Seller %s offline; implement offline payout if you need.'):format(listing.seller_cid))
    end
end

-- SELL ANYWHERE
RegisterNetEvent('qbx_usedcars:listVehicle', function(price, props, coords, heading)
    local src = source
    local Player = QBX.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid
    local char = Player.PlayerData.charinfo
    local sellerName = (char and (char.firstname .. ' ' .. char.lastname)) or GetPlayerName(src)

    price = math.floor(tonumber(price) or 0)
    if price < Config.MinPrice or price > Config.MaxPrice then
        return lib.notify(src, { type = 'error', description = 'Invalid price.' })
    end

    local plate = props and props.plate
    if not plate then
        return lib.notify(src, { type = 'error', description = 'Vehicle must have a plate.' })
    end

    -- Optional: blacklist area check
    if Config.BlacklistedAreas and #Config.BlacklistedAreas > 0 then
        for _, area in ipairs(Config.BlacklistedAreas) do
            if #(coords - area.coords) <= area.radius then
                return lib.notify(src, { type = 'error', description = 'You cannot list vehicles here.' })
            end
        end
    end

    MySQL.scalar('SELECT COUNT(*) FROM qbx_usedcar_listings WHERE seller_cid = ? AND status = "active"', { cid },
        function(count)
            if (count or 0) >= Config.MaxListingsPerPlayer then
                return lib.notify(src, { type = 'error', description = 'You reached the max active listings.' })
            end

            MySQL.single('SELECT 1 FROM player_vehicles WHERE citizenid = ? AND plate = ? LIMIT 1',
                { cid, plate }, function(row)
                    if not row then
                        return lib.notify(src, { type = 'error', description = 'You do not own this vehicle.' })
                    end

                    local propsJSON = json.encode(props)

                    MySQL.insert(
                        [[
                            INSERT INTO qbx_usedcar_listings
                                (seller_cid, seller_name, plate, vehicle_props, price, pos_x, pos_y, pos_z, heading)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        ]],
                        { cid, sellerName, plate, propsJSON, price, coords.x, coords.y, coords.z, heading },
                        function(id)
                            if not id then
                                return lib.notify(src, { type = 'error', description = 'Failed to create listing.' })
                            end

                            webhook('New Listing', {
                                { name = 'Seller', value = ('%s (%s)'):format(sellerName, cid), inline = true },
                                { name = 'Plate',  value = plate, inline = true },
                                { name = 'Price',  value = ('$%s'):format(price), inline = true }
                            })

                            lib.notify(src, { type = 'success', description = 'Vehicle listed for sale here.' })
                            TriggerClientEvent('qbx_usedcars:newListing', -1, id)
                        end
                    )
                end)
        end)
end)

-- BUY VEHICLE
RegisterNetEvent('qbx_usedcars:buyVehicle', function(listingId)
    local src = source
    local Player = QBX.Functions.GetPlayer(src)
    if not Player then return end

    listingId = tonumber(listingId)
    if not listingId then return end

    local buyerCid = Player.PlayerData.citizenid

    MySQL.single('SELECT * FROM qbx_usedcar_listings WHERE id = ? AND status = "active"', { listingId },
        function(listing)
            if not listing then
                return lib.notify(src, { type = 'error', description = 'Listing not found or already sold.' })
            end

            if listing.seller_cid == buyerCid then
                return lib.notify(src, { type = 'error', description = 'You cannot buy your own vehicle.' })
            end

            local totalPrice = listing.price
            if Config.BuyerTaxPercent > 0 then
                totalPrice = math.floor(totalPrice * (1 + Config.BuyerTaxPercent / 100))
            end

            if not Player.Functions.RemoveMoney('bank', totalPrice, 'usedcar-buy') then
                return lib.notify(src, { type = 'error', description = 'Not enough bank balance.' })
            end

            local fee = math.floor(listing.price * (Config.SellFeePercent / 100))
            local sellerNet = listing.price - fee

            transferOwnership(listing, buyerCid, function(success)
                if not success then
                    Player.Functions.AddMoney('bank', totalPrice, 'usedcar-refund-failed-transfer')
                    return lib.notify(src, { type = 'error', description = 'Ownership transfer failed, refunded.' })
                end

                MySQL.update('UPDATE qbx_usedcar_listings SET status = "sold", buyer_cid = ? WHERE id = ?',
                    { buyerCid, listing.id })

                webhook('Vehicle Sold', {
                    { name = 'Buyer CID',  value = tostring(buyerCid), inline = true },
                    { name = 'Seller CID', value = tostring(listing.seller_cid), inline = true },
                    { name = 'Plate',      value = listing.plate, inline = true },
                    { name = 'Price',      value = ('$%s'):format(listing.price), inline = true }
                })

                paySeller(listing, sellerNet)

                lib.notify(src, { type = 'success', description = 'You bought the vehicle!' })
                TriggerClientEvent('qbx_usedcars:listingSold', -1, listing.id)
            end)
        end)
end)

-- CANCEL LISTING (owner) — optional “good practice” UX
RegisterNetEvent('qbx_usedcars:cancelListing', function(listingId)
    local src = source
    local Player = QBX.Functions.GetPlayer(src)
    if not Player then return end

    listingId = tonumber(listingId)
    if not listingId then return end

    local cid = Player.PlayerData.citizenid

    local changed = MySQL.update.await(
        'UPDATE qbx_usedcar_listings SET status = "cancelled" WHERE id = ? AND seller_cid = ? AND status = "active"',
        { listingId, cid }
    )

    if changed and changed > 0 then
        lib.notify(src, { type = 'success', description = 'Listing cancelled.' })
        TriggerClientEvent('qbx_usedcars:listingSold', -1, listingId) -- despawn preview
        webhook('Listing Cancelled', {
            { name = 'Seller CID', value = tostring(cid), inline = true },
            { name = 'Listing ID', value = tostring(listingId), inline = true }
        })
    else
        lib.notify(src, { type = 'error', description = 'Cancel failed (not yours or not active).' })
    end
end)

-- ADMIN: force cancel by ID
RegisterCommand('usedcars_cancel', function(src, args)
    if src == 0 or isAdmin(src) then
        local id = tonumber(args[1])
        if not id then
            if src ~= 0 then lib.notify(src, { type='error', description='Usage: /usedcars_cancel <id>' }) end
            return
        end
        local changed = MySQL.update.await('UPDATE qbx_usedcar_listings SET status="cancelled" WHERE id=? AND status="active"', { id })
        if changed and changed > 0 then
            if src ~= 0 then lib.notify(src, { type='success', description='Listing cancelled.' }) end
            TriggerClientEvent('qbx_usedcars:listingSold', -1, id)
        else
            if src ~= 0 then lib.notify(src, { type='error', description='No active listing with that ID.' }) end
        end
    else
        lib.notify(src, { type='error', description='Insufficient permissions.' })
    end
end, false)

-- NEARBY LISTINGS (F6 & world spawner)
lib.callback.register('qbx_usedcars:getNearby', function(source, coords)
    local x, y = coords.x, coords.y
    local radius = Config.MarketRadius + 50.0

    local rows = MySQL.query.await(
        [[
            SELECT id, seller_name, plate, price, vehicle_props, pos_x, pos_y, pos_z, heading
            FROM qbx_usedcar_listings
            WHERE status = 'active'
              AND pos_x BETWEEN ? AND ?
              AND pos_y BETWEEN ? AND ?
        ]],
        { x - radius, x + radius, y - radius, y + radius }
    )

    return rows or {}
end)


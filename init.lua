--[[
Multi-level finite water test
]]

waterminus = {}

local S = minetest.get_translator("waterminus")

local set, get, swap, group = minetest.set_node, minetest.get_node, minetest.swap_node, minetest.get_item_group
local getLevel, setLevel, getTimer = minetest.get_node_level, minetest.set_node_level, minetest.get_node_timer
local defs, itemDefs = minetest.registered_nodes, minetest.registered_items
local add, pString = vector.add, minetest.pos_to_string
local floor, random, min, max = math.floor, math.random, math.min, math.max
local insert = table.insert

local naturalFlows = {
    {x = 0, y = -1, z = 0},
    {x = -1, y = 0, z = 0},
    {x = 0, y = 0, z = -1},
    {x = 1, y = 0, z = 0},
    {x = 0, y = 0, z = 1},
}
local naturalSinks = {
    {x = 0, y = 1, z = 0},
    {x = -1, y = 0, z = 0},
    {x = 0, y = 0, z = -1},
    {x = 1, y = 0, z = 0},
    {x = 0, y = 0, z = 1},
}
local adjacent = {
    {x = 0, y = -1, z = 0},
    {x = -1, y = 0, z = 0},
    {x = 0, y = 0, z = -1},
    {x = 1, y = 0, z = 0},
    {x = 0, y = 0, z = 1},
    {x = 0, y = 1, z = 0},
}
local updateAdj = {
    {x = -1, y = 0, z = 0},
    {x = 0, y = 0, z = -1},
    {x = 1, y = 0, z = 0},
    {x = 0, y = 0, z = 1},
    {x = 0, y = 1, z = 0},
}
local cardinals = {
    {x = 1, z = 0},
    {x = 0, z = 1},
    {x = -1, z = 0},
    {x = 0, z = -1},
}
local permutations = {
    {1, 2, 3, 4}, {1, 2, 4, 3}, {1, 3, 2, 4}, {1, 3, 4, 2}, {1, 4, 2, 3}, {1, 4, 3, 2}, {2, 1, 3, 4}, {2, 1, 4, 3}, {2, 3, 1, 4}, {2, 3, 4, 1}, {2, 4, 1, 3}, {2, 4, 3, 1},
    {3, 1, 2, 4}, {3, 1, 4, 2}, {3, 2, 1, 4}, {3, 2, 4, 1}, {3, 4, 1, 2}, {3, 4, 2, 1}, {4, 1, 2, 3}, {4, 1, 3, 2}, {4, 2, 1, 3}, {4, 2, 3, 1}, {4, 3, 1, 2}, {4, 3, 2, 1}}
local drain = {}

local empty, air = {}, {name = "air"}
local nop = function () end

local function searchSpread(pos, depth, ctx)
    ctx = ctx or {sum = 0, max = 0, min = 8, spreads = {}, [pString(pos)] = true}
    depth = depth or 2
    
    local node = get(pos)
    local name = node.name
    local def = defs[name] or empty
    
    if not ctx.name then ctx.name = name end
    
    pos.y = pos.y - 1
    local belowNode = get(pos)
    local belowLevel = getLevel(pos)
    local belowName = belowNode.name
    local belowDef = defs[belowName] or empty
    pos.y = pos.y + 1
    
    if name == ctx.name then
        local level = getLevel(pos)
        ctx.sum = ctx.sum + level
        ctx.max = max(ctx.max, level)
        ctx.min = min(ctx.min, level)
    elseif name == def._waterminus_source then
        ctx.sum = math.huge
        return
    elseif not def.floodable then
        return ctx
    else
        ctx.min = 0
    end
    
    insert(ctx.spreads, {x = pos.x, y = pos.y, z = pos.z})
    if depth <= 0 then return ctx end
    
    if def.floodable and belowName ~= ctx.name then
        return ctx
    end
    if belowDef.floodable or belowName == ctx.name and belowLevel < 7 then
        return ctx
    end
    
    local perm = permutations[random(1, 24)]
    for i = 1, 4 do
        local vec = cardinals[perm[i]]
        pos.x, pos.z = pos.x + vec.x, pos.z + vec.z
        
        local pstr = pString(pos)
        if not ctx[pstr] then
            ctx[pstr] = true
            searchSpread(pos, depth - 1, ctx)
        end
        
        pos.x, pos.z = pos.x - vec.x, pos.z - vec.z
    end
    
    return ctx
end
local function searchDrain(pos)
    local found = {[pString(pos)] = true}
    local queue = {x = pos.x, y = pos.y, z = pos.z, depth = 0}
    local last = queue
    
    local node = get(pos)
    local name = node.name
    local def = defs[name]
    
    while queue do
        local first = queue
        
        local fNode = get(first)
        local fName = fNode.name
        local fDef = defs[fName] or empty
        
        if first.depth == 0 or fDef.floodable then
            first.y = first.y - 1
            local bNode = get(first)
            local bLevel = getLevel(first)
            local bName = bNode.name
            local bDef = defs[bName] or empty
            first.y = first.y + 1
            
            if bDef.floodable or bName == def._waterminus_flowing and bLevel < 7 or bName == def._waterminus_source then
                return first
            elseif first.depth <= 2 then
                for _, vec in ipairs(cardinals) do
                    local new = {x = first.x + vec.x, y = first.y, z = first.z + vec.z, depth = first.depth + 1, dir = first.dir or vec}
                    
                    local pstr = pString(new)
                    if not found[pstr] then
                        found[pstr] = true
                        last.next, last = new, new
                    end
                end
            end
        end
        queue = queue.next
    end
end
local function update(pos, depth)
    if not depth then depth = 1 end
    
    local node, timer = get(pos), getTimer(pos)
    local def = defs[node.name] or empty
    local timeout = timer:get_timeout()
    
    local updateInterval = 0.3
    if group(node.name, "waterminus") > 0 and timeout == 0 or timeout - timer:get_elapsed() >= updateInterval - 0.01 then
        timer:start(updateInterval)
    end
    
    if depth <= 0 then return end
    
    for _, vec in ipairs(updateAdj) do
        pos.x, pos.y, pos.z = pos.x + vec.x, pos.y + vec.y, pos.z + vec.z
        
        update(pos, depth - 1)
        
        pos.x, pos.y, pos.z = pos.x - vec.x, pos.y - vec.y, pos.z - vec.z
    end
end
waterminus.update = update

local function check_protection(pos, name, text)
    if minetest.is_protected(pos, name) then
        minetest.log("action", (name ~= "" and name or "A mod")
            .. " tried to " .. text
            .. " at protected position "
            .. minetest.pos_to_string(pos)
            .. " with a bucket")
        minetest.record_protection_violation(pos, name)
        return true
    end
    return false
end

local pointSupport = minetest.features.item_specific_pointabilities
local pointabilities = {nodes = {["group:waterminus"] = true}}

if bucket then
    local on_use = itemDefs["bucket:bucket_empty"].on_use
    minetest.override_item("bucket:bucket_empty", {
        pointabilities = pointabilities,
        on_use = function(itemstack, user, pointed_thing)
            if pointed_thing.type ~= "node" then
                return on_use(itemstack, user, pointed_thing)
            end
            
            local pos = pointSupport and pointed_thing.under or pointed_thing.above
            local node = get(pos)
            local name = node.name
            local level = getLevel(pos)
            local def = defs[name]
            local item_count = user:get_wielded_item():get_count()
            
            if group(name, "waterminus") < 1 then
                return on_use(itemstack, user, pointed_thing)
            end
            if check_protection(pointed_thing.under,
                    user:get_player_name(),
                    "take ".. name) then
                return
            end
            
            -- default set to return filled bucket
            local isSource = def._waterminus_source == name
            local giving_back = isSource and def._waterminus_bucket .. "_7" or (level == 0 and "bucket:bucket_empty" or def._waterminus_bucket .. "_" .. level)

            -- check if holding more than 1 empty bucket
            if item_count > 1 then
                -- if space in inventory add filled bucked, otherwise drop as item
                local inv = user:get_inventory()
                if inv:room_for_item("main", {name=giving_back}) then
                    inv:add_item("main", giving_back)
                else
                    local pos = user:get_pos()
                    pos.y = math.floor(pos.y + 0.5)
                    minetest.add_item(pos, giving_back)
                end

                -- set to return empty buckets minus 1
                giving_back = "bucket:bucket_empty "..tostring(item_count-1)
            end
            if not isSource then
                set(pos, air)
                update(pos)
            end
            
            return ItemStack(giving_back)
        end
    })
end

function waterminus.register_liquid(liquidDef)
    local source, flowing = liquidDef.source, liquidDef.flowing
    
    if source then
        local def = defs[source]
        local extra = {}
        
        extra.groups = def.groups or {}
        extra.groups.waterminus = 1
        
        extra._waterminus_type = "source"
        extra._waterminus_source = source
        extra._waterminus_flowing = flowing
        
        local construct = def.on_construct or nop
        extra.on_construct = function (pos, ...)
            update(pos)
            return construct(pos, ...)
        end
        
        if def.on_timer then
            error("Cannot register a waterminus liquid with node timer!")
        end
        extra.on_timer = function (pos)
            local myNode = get(pos)
            local myDef = defs[myNode.name]
            local flowing = myDef._waterminus_flowing
            
            for _, vec in ipairs(naturalFlows) do
                pos.x, pos.y, pos.z = pos.x + vec.x, pos.y + vec.y, pos.z + vec.z
                local name = get(pos).name
                local level = getLevel(pos)
                local def = defs[name] or empty
                
                if name == flowing and getLevel(pos) < 7 or def.floodable then
                    set(pos, {name = flowing, param2 = 7})
                    update(pos)
                end
                pos.x, pos.y, pos.z = pos.x - vec.x, pos.y - vec.y, pos.z - vec.z
            end
        end
        
        if liquidDef.bucket then
            extra._waterminus_bucket = liquidDef.bucket
        end
        
        minetest.override_item(source, extra)
    end
    
    local def = defs[flowing]
    local extra = {}
    
    extra.groups = def.groups or {}
    extra.groups.waterminus = 1
    
    extra._waterminus_type = "flowing"
    extra._waterminus_source = source
    extra._waterminus_flowing = flowing
    
    local construct = def.on_construct or nop
    extra.on_construct = function (pos, ...)
        update(pos)
        return construct(pos, ...)
    end
    local afterPlace = def.after_place_node or nop
    extra.after_place_node = function (pos, ...)
        setLevel(pos, 7)
        return afterPlace(pos, ...)
    end
    
    if def.on_timer then
        error("Cannot register a waterminus liquid with node timer!")
    end
    extra.on_timer = function (pos)
        local myNode = get(pos)
        local myLevel = getLevel(pos)
        
        local myDef = defs[myNode.name]
        local flowing, source = myDef._waterminus_flowing, myDef._waterminus_source
        
        pos.y = pos.y - 1
        
        local belowNode = get(pos)
        local belowName = belowNode.name
        local belowDef = defs[belowName] or empty
        
        if belowName == source or belowName ~= flowing and not belowDef.floodable then
            pos.y = pos.y + 1
            local sources = 0
            for _, vec in ipairs(cardinals) do
                pos.x, pos.z = pos.x + vec.x, pos.z + vec.z
                
                if get(pos).name == source then
                    sources = sources + 1
                    if sources >= 2 then
                        pos.x, pos.z = pos.x - vec.x, pos.z - vec.z
                        set(pos, {name = source})
                        return
                    end
                end
                
                pos.x, pos.z = pos.x - vec.x, pos.z - vec.z
            end
            pos.y = pos.y - 1
        end
        
        if belowDef.floodable or belowName == flowing and getLevel(pos) < 7 or belowName == source then
            local belowLvl = (belowDef.floodable or belowName == source) and 0 or getLevel(pos)
            local levelGiven = min(7 - belowLvl, myLevel)
            local level = belowLvl + levelGiven
            
            if belowName ~= source then
                set(pos, {name = flowing})
                setLevel(pos, level)
                update(pos)
            end
            
            pos.y = pos.y + 1
            setLevel(pos, myLevel - levelGiven)
            if myLevel - levelGiven <= 0 then
                set(pos, air)
            end
            update(pos)
        elseif myLevel == 1 then
            pos.y = pos.y + 1
            
            local dir = (searchDrain(pos) or empty).dir
            if dir then
                update(pos)
                set(pos, air)
                pos.x, pos.z = pos.x + dir.x, pos.z + dir.z
                set(pos, {name = flowing})
                setLevel(pos, myLevel)
                update(pos)
                
                return
            end
        else
            pos.y = pos.y + 1
            
            local start = {x = pos.x, y = pos.y, z = pos.z}
            local minlvl, maxlvl, sum, spreads = myLevel, myLevel, myLevel, {start}
            local requireFlooding = false
            
            local perm = permutations[random(1, 24)]
            for i = 1, 4 do
                local vec = cardinals[perm[i]]
                pos.x, pos.z = pos.x + vec.x, pos.z + vec.z
                
                pos.y = pos.y - 1
                local belowNode = get(pos)
                local belowLevel = getLevel(pos)
                local belowName = belowNode.name
                local belowDef = defs[belowName] or empty
                pos.y = pos.y + 1
                
                local name = get(pos).name
                local def = defs[name] or empty
                
                if not requireFlooding or belowDef.floodable then
                    --[[if not requireFlooding and belowDef.floodable then
                        minlvl, maxlvl, sum, spreads = myLevel, myLevel, myLevel, {start}
                        requireFlooding = true
                    end]]
                    if name == flowing then
                        local level = getLevel(pos)
                        sum = sum + level
                        maxlvl = max(maxlvl, level)
                        minlvl = min(minlvl, level)
                        insert(spreads, {x = pos.x, y = pos.y, z = pos.z})
                    elseif def.floodable then
                        minlvl = 0
                        insert(spreads, {x = pos.x, y = pos.y, z = pos.z})
                    end
                end
                
                pos.x, pos.z = pos.x - vec.x, pos.z - vec.z
            end
            
            if maxlvl - minlvl < 2 then
                local swaps = {}
                local perm = permutations[random(1, 24)]
                for i = 1, 4 do
                    local vec = cardinals[perm[i]]
                    pos.x, pos.z = pos.x + vec.x, pos.z + vec.z
                    
                    local neighNode = get(pos)
                    local neighName = neighNode.name
                    local neighDef = defs[neighName] or empty
                    
                    if neighName == myNode.name and myLevel - getLevel(pos) == 1 then
                        local newNeighLvl = getLevel(pos)
                        swap(pos, {name = myNode.name})
                        setLevel(pos, myLevel)
                        update(pos)
                        
                        pos.x, pos.z = pos.x - vec.x, pos.z - vec.z
                        set(pos, neighNode)
                        setLevel(pos, newNeighLvl)
                        if newNeighLvl == 0 then
                            set(pos, air)
                        end
                        update(pos)
                        return
                    end
                    
                    pos.x, pos.z = pos.x - vec.x, pos.z - vec.z
                end
                
                return
            end
            if sum == math.huge then
                sum = #spreads * 7
            end
            
            local average, leftover = floor(sum / #spreads), sum % #spreads
            
            for i, spreadPos in ipairs(spreads) do
                local level = average + (i <= leftover and 1 or 0)
                if level > 0 then
                    set(spreadPos, {name = flowing})
                    setLevel(spreadPos, level)
                elseif get(spreadPos).name == flowing then
                    set(spreadPos, air)
                end
                update(spreadPos)
            end
        end
    end
    
    if liquidDef.bucket then
        extra._waterminus_bucket = liquidDef.bucket
    end
    
    minetest.override_item(flowing, extra)
    
    if bucket and liquidDef.bucket then
        for i = 1, 7 do
            minetest.register_craftitem(liquidDef.bucket .. "_" .. i, {
                description = ("%s (%s/7)"):format(liquidDef.bucket_desc, i),
                inventory_image = liquidDef.bucket_images[i],
                
                stack_max = 1,
                pointabilities = pointabilities,
                
                on_use = function(itemstack, user, pointed_thing)
                    if pointed_thing.type ~= "node" then
                        return
                    end
                    
                    local pos = pointSupport and pointed_thing.under or pointed_thing.above
                    local node = get(pos)
                    local name = node.name
                    local level = getLevel(pos)
                    local def = defs[name]
                    local item_count = user:get_wielded_item():get_count()
                    
                    if def._waterminus_flowing ~= liquidDef.flowing then
                        return
                    end
                    if check_protection(pointed_thing.under,
                            user:get_player_name(),
                            "take ".. name) then
                        return
                    end
                    if def._waterminus_source == name then
                        return ItemStack(liquidDef.bucket .. "_7")
                    end
                    
                    local levelTaken = min(level, 7 - i)
                    setLevel(pos, level - levelTaken)
                    if levelTaken == level then
                        set(pos, air)
                    end
                    update(pos)
                    
                    return ItemStack(liquidDef.bucket .. "_" .. (i + levelTaken))
                end,
                on_place = function(itemstack, user, pointed_thing)
                    -- Must be pointing to node
                    if pointed_thing.type ~= "node" then
                        return
                    end

                    local node = minetest.get_node_or_nil(pointed_thing.under)
                    local ndef = node and minetest.registered_nodes[node.name]

                    -- Call on_rightclick if the pointed node defines it
                    if ndef and ndef.on_rightclick and
                            not (user and user:is_player() and
                            user:get_player_control().sneak) then
                        return ndef.on_rightclick(
                            pointed_thing.under,
                            node, user,
                            itemstack)
                    end

                    local lpos

                    -- Check if pointing to a buildable node
                    if ndef and ndef.buildable_to then
                        -- buildable; replace the node
                        lpos = pointed_thing.under
                    else
                        -- not buildable to; place the liquid above
                        -- check if the node above can be replaced

                        lpos = pointed_thing.above
                        node = minetest.get_node_or_nil(lpos)
                        local above_ndef = node and minetest.registered_nodes[node.name]

                        if not above_ndef or not above_ndef.buildable_to then
                            -- do not remove the bucket with the liquid
                            return itemstack
                        end
                    end

                    if check_protection(lpos, user
                            and user:get_player_name()
                            or "", "place "..liquidDef.flowing) then
                        return
                    end
                    
                    local node = get(lpos)
                    local name = node.name
                    local level = getLevel(lpos)
                    local def = defs[name]
                    local item_count = user:get_wielded_item():get_count()
                    
                    if def._waterminus_source == name then
                        return ItemStack("bucket:bucket_empty")
                    end
                    
                    local levelGiven = node.name == liquidDef.flowing and min(i, 7 - level) or i
                    local newLevel = node.name == liquidDef.flowing and level + levelGiven or levelGiven
                    local giveBack = i - levelGiven == 0 and "bucket:bucket_empty" or liquidDef.bucket .. "_" .. i - levelGiven

                    set(lpos, {name = liquidDef.flowing})
                    setLevel(lpos, newLevel)
                    update(lpos)
                    return ItemStack(giveBack)
                end
            })
        end
    end
end

minetest.register_on_dignode(function (pos)
    update(pos)
end)

local getHashPos = minetest.get_position_from_hash
minetest.register_on_mapblocks_changed(function (modified_blocks, modified_block_count)
    for hash, _ in pairs(modified_blocks) do
        update(getHashPos(hash))
    end
end)

if default then
    minetest.register_node("waterminus:water", {
        description = S("Finite Water"),
        tiles = {"waterminus_spring.png"},
        special_tiles = {
            {
                name = "waterminus_water_animated.png",
                backface_culling = false,
                animation = {
                    type = "vertical_frames",
                    aspect_w = 16,
                    aspect_h = 16,
                    length = 2,
                },
            },
            {
                name = "waterminus_water_animated.png",
                backface_culling = true,
                animation = {
                    type = "vertical_frames",
                    aspect_w = 16,
                    aspect_h = 16,
                    length = 2,
                },
            },
        },
        
        drawtype = "flowingliquid",
        use_texture_alpha = true,
        paramtype = "light",
        paramtype2 = "flowingliquid",
        
        walkable = false,
        buildable_to = true,
        pointable = false,
        
        move_resistance = 1,
        liquid_viscosity = 1,
        liquid_move_physics = true,
        liquid_alternative_source = "waterminus:spring",
        liquid_alternative_flowing = "waterminus:water",
        
        post_effect_color = {r = 30, g = 70, b = 90, a = 103},
        
        on_blast = function (pos, intensity) end,
        sounds = default.node_sound_water_defaults()
    })
    minetest.register_node("waterminus:spring", {
        description = S("Finite Water Spring"),
        tiles = {{
            name = "waterminus_spring_animated.png",
            backface_culling = false,
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 4,
            },
        }},
        
        drawtype = "liquid",
        use_texture_alpha = true,
        paramtype = "light",
        
        walkable = false,
        buildable_to = true,
        pointable = false,
        
        move_resistance = 1,
        liquid_viscosity = 1,
        liquid_move_physics = true,
        liquid_alternative_source = "waterminus:spring",
        liquid_alternative_flowing = "waterminus:water",
        
        post_effect_color = {r = 30, g = 70, b = 90, a = 103},
        
        on_blast = function (pos, intensity) end,
        sounds = default.node_sound_water_defaults()
    })

    minetest.register_node("waterminus:lava", {
        description = S("Finite Lava"),
        tiles = {"default_lava.png"},
        special_tiles = {
            {
                name = "default_lava_flowing_animated.png",
                backface_culling = false,
                animation = {
                    type = "vertical_frames",
                    aspect_w = 16,
                    aspect_h = 16,
                    length = 4,
                },
            },
            {
                name = "default_lava_flowing_animated.png",
                backface_culling = true,
                animation = {
                    type = "vertical_frames",
                    aspect_w = 16,
                    aspect_h = 16,
                    length = 4,
                },
            },
        },
        groups = {lava = 3, igniter = 1},
        
        drawtype = "flowingliquid",
        use_texture_alpha = true,
        paramtype = "light",
        paramtype2 = "flowingliquid",
        light_source = default.LIGHT_MAX - 1,
        
        walkable = false,
        buildable_to = true,
        pointable = false,
        
        move_resistance = 7,
        liquid_viscosity = 7,
        liquid_move_physics = true,
        liquid_alternative_flowing = "waterminus:lava",
        
        post_effect_color = {a = 191, r = 255, g = 64, b = 0},
        damage_per_second = 8,
        
        on_blast = function (pos, intensity) end
    })

    waterminus.register_liquid {
        source = "waterminus:spring",
        flowing = "waterminus:water",
        
        bucket = "waterminus:bucket_water",
        bucket_desc = S("Finite Water Bucket"),
        
        bucket_images = {
            "waterminus_bucket_water_part.png^waterminus_bucket_bar_1.png",
            "waterminus_bucket_water_part.png^waterminus_bucket_bar_2.png",
            "waterminus_bucket_water_part.png^waterminus_bucket_bar_3.png",
            "waterminus_bucket_water_part.png^waterminus_bucket_bar_4.png",
            "waterminus_bucket_water_part.png^waterminus_bucket_bar_5.png",
            "waterminus_bucket_water_part.png^waterminus_bucket_bar_6.png",
            "waterminus_bucket_water.png^waterminus_bucket_bar_7.png",
        }
    }
    waterminus.register_liquid {
        flowing = "waterminus:lava",
        
        bucket = "waterminus:bucket_lava",
        bucket_desc = S("Finite Lava Bucket"),
        bucket_images = {
            "waterminus_bucket_lava_part.png^waterminus_bucket_bar_1.png",
            "waterminus_bucket_lava_part.png^waterminus_bucket_bar_2.png",
            "waterminus_bucket_lava_part.png^waterminus_bucket_bar_3.png",
            "waterminus_bucket_lava_part.png^waterminus_bucket_bar_4.png",
            "waterminus_bucket_lava_part.png^waterminus_bucket_bar_5.png",
            "waterminus_bucket_lava_part.png^waterminus_bucket_bar_6.png",
            "bucket_lava.png^waterminus_bucket_bar_7.png",
        }
    }

    local getBiomeName, id = minetest.get_biome_name, minetest.get_content_id
    local waterFlowingID, waterID, springID, airID = id("default:water_flowing"), id("waterminus:water"), id("waterminus:spring"), id("air")
    local lavaFlowingID, lavaID = id("default:lava_flowing"), id("waterminus:lava")
    local equivalents = {[id("mapgen_water_source")] = minetest.settings:get_bool("waterminus_ocean_springs") ~= false and springID or waterID, [id("default:lava_source")] = lavaID}
    
    minetest.register_on_generated(function (minp, maxp, seed)
        local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
        local biomeMap = minetest.get_mapgen_object("biomemap")
        local emin2d = {x = emin.x, y = emin.z, z = 0}
        
        local esize = vector.add(vector.subtract(emax, emin), 1)
        local esize2d = {x = esize.x, y = esize.z}
        
        local area = VoxelArea:new {MinEdge = emin, MaxEdge = emax}
        local data = vm:get_data()
        local paramData = vm:get_param2_data()
        
        for x = minp.x, maxp.x do
            for z = minp.z, maxp.z do
                for y = minp.y, maxp.y do
                    local index = area:index(x, y, z)
                    local block = data[index]
                    if equivalents[block] then
                        data[index] = equivalents[block]
                        paramData[index] = 7
                        for _, vec in ipairs(naturalFlows) do
                            local nx, ny, nz = x + vec.x, y + vec.y, z + vec.z
                            local nIndex = area:index(nx, ny, nz)
                            
                            local def = defs[minetest.get_name_from_content_id(data[nIndex])] or empty
                            if data[nIndex] == airID or def.liquidtype == "flowing" then
                                local biome = biomeMap and biomeMap[nIndex]
                                local biomeDef = biome and minetest.registered_biomes[getBiomeName(biome)] or empty
                                data[nIndex] = id(biomeDef.node_stone or "mapgen_stone")
                            end
                        end
                    end
                end
            end
        end
        
        vm:set_data(data)
        vm:set_param2_data(paramData)
        vm:calc_lighting()
        vm:write_to_map()
        vm:update_liquids()
    end)
    
    function waterminus.cool_lava(pos, node)
        if getLevel(pos) == 7 then
            minetest.set_node(pos, {name = "default:obsidian"})
        else -- Lava flowing
            minetest.set_node(pos, {name = "default:stone"})
        end
        minetest.sound_play("default_cool_lava", {pos = pos, max_hear_distance = 16, gain = 0.2}, true)
    end

    if minetest.settings:get_bool("enable_lavacooling") ~= false then
        minetest.register_abm {
            label = "Finite lava cooling",
            nodenames = {"waterminus:lava"},
            neighbors = {"waterminus:water", "waterminus:spring"},
            interval = 1,
            chance = 1,
            catch_up = false,
            action = waterminus.cool_lava,
        }
    end
end
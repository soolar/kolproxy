-- TODO: does not handle imported beer because of the &quot; escaping(?)
function buy_itemname(name, input_amount)
	assert(type(name) == "string")
	get_itemid(name)
	local amount = input_amount or 1
	local pt = get_page("/submitnewchat.php", { graf = "/buy " .. amount .. " " .. name, pwd = session.pwd })
	if pt:contains("Purchasing " .. amount .. " ") then
		local url = pt:match([[dojax%('(.-)'%)]])
		if url then
			local urlpath, urlquery = kolproxycore_splituri("/" .. url)
			local urlparams = kolproxycore_decode_uri_query(urlquery) or {}
			print_debug("  purchasing", name, input_amount or "")
			return async_get_page(urlpath, urlparams)
		end
	end
	return function() return [[{ /buy ]] .. amount .. " " .. name .. [[ failed. }]] end
end

function buy_item(name, input_amount)
	local itemname = maybe_get_itemname(name)
	assert(itemname)
	return buy_itemname(itemname, input_amount)
end

function store_buy_item(name, whichstore, amount)
	return buy_itemname(name, amount)
end

function shop_buy_item(items, whichshop)
	if type(items) == "string" then
		return buy_itemname(items)
	else
		local ptfs = {}
		for x, y in pairs(items) do
			table.insert(ptfs, buy_itemname(x, y))
		end
		return ptfs
	end
end

function raw_store_buy_item(name, whichstore, amount)
	print_debug("  buying", name, amount or "")
	return async_get_page("/store.php", { phash = session.pwd, buying = 1, whichitem = get_itemid(name), howmany = amount or 1, whichstore = whichstore, ajax = 1, action = "buyitem" })
end

function buy_hermit_item(item, quantity)
	return async_post_page("/hermit.php", { action = "trade", whichitem = get_itemid(item), quantity = quantity or 1 })
end

function check_buying_from_knob_dispensary()
	local pt = get_page("/submitnewchat.php", { graf = "/buy knob goblin seltzer", pwd = session.pwd })
	if pt:contains("Knob Goblin seltzer") then
		return true
	elseif pt:contains("not sure") then
		return false
	end
end

function shop_scan_item_rows(whichshop)
	local scanned_itemrows = {}
	local pt = get_page("/shop.php", { whichshop = whichshop })

	for row, name in pt:gmatch([[<input type=radio name=whichrow value=([0-9]+)>.-<b>(.-)</b>]]) do
		scanned_itemrows[name] = tonumber(row)
	end
	for tr in pt:gmatch([[<tr.-</tr>]]) do
		local name, row = tr:match([[<b>(.-)</b>.-whichrow=([0-9]+)]])
		if name and tonumber(row) and not scanned_itemrows[name] then
			scanned_itemrows[name] = tonumber(row)
		end
	end

	return scanned_itemrows
end

local function shop_buy_many_items(itemlist, whichshop)
	local itemrows = shop_scan_item_rows(whichshop)
	local ptfs = {}
	for x, y in pairs(itemlist) do
		if not itemrows[x] then
			print("WARNING: couldn't find row for item", x)
			print("  itemrows:", itemrows)
			print("WARNING: couldn't find row for item", x)
		end
		table.insert(ptfs, async_post_page("/shop.php", { pwd = session.pwd, whichshop = whichshop, action = "buyitem", whichrow = itemrows[x], quantity = y }))
	end
	return ptfs
end

function raw_shop_buy_item(items, whichshop)
	if type(items) == "string" then
		return shop_buy_many_items({ [items] = 1 }, whichshop)[1]
	else
		return shop_buy_many_items(items, whichshop)
	end
end

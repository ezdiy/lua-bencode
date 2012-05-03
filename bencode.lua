--[[

	public domain lua-module for handling bittorrent-bencoded data.
	This module includes both a recursive decoder and a recursive encoder.

]]--

local floor, sort, concat = math.floor, table.sort, table.concat
local pairs, ipairs, type = pairs, ipairs, type
local assert, error = assert, error -- FIXME get rid of these
local tonumber = tonumber

module "bencode"

local function islist(t) 
	local n = #t 
	for k, v in pairs(t) do 
		if type(k) ~= "number" or floor(k) ~= k or k < 1 or k > n then 
			return false 
		end 
	end 
	for i = 1, n do 
		if t[i] == nil then 
			return false 
		end 
	end 
	return true
end 

local function isdictionary(t) 
	return not islist(t)
end  

function encode(x) -- recursively bencode x
	local tx = type(x)
	if tx == "string" then
		return #x .. ":" .. x
	elseif tx == "number" then
		if x % 1 ~= 0 then 
			error("number is not an integer: '" .. x .. "'")
		end
		return "i" .. x .. "e"
	elseif tx == "table" then
		local ret
		if islist(x) then
			ret = "l"
			for k, v in ipairs(x) do
				ret = ret .. encode(v)
			end
			ret = ret .. "e"
		else -- dictionary
			ret = "d"
			-- bittorrent requires the keys to be sorted.
			local sortedkeys = {}
			for k, v in pairs(x) do
				if type(k) ~= "string" then
					error "bencoding requires dictionary keys to be strings"
				end
				sortedkeys[#sortedkeys + 1] = k
			end
			sort(sortedkeys)

			for k, v in ipairs(sortedkeys) do
				ret = ret .. encode(v) .. encode(x[v])
			end
			ret = ret .. "e"
		end
		return ret
	else
		error(tx .. " cannot be converted to an acceptable type for bencoding")
	end
end

local function decode_integer(s, index) 
	local a, b, int = s:find("^([0-9]+)e", index) 
	assert(int, "not a number: nil") 
	int = tonumber(int) 
	assert(int, "not a number: " .. int) 
	return int, b + 1 
end 

local function decode_list(s, index) 
	local t = {} 
	while s:sub(index, index) ~= "e" do 
		local obj 
		obj, index = decode(s, index) 
		t[#t + 1] = obj 
	end 
	index = index + 1 
	return t, index 
end 
	 
local function decode_dictionary(s, index) 
	local t = {} 
	while s:sub(index, index) ~= "e" do 
		local obj1 
		obj1, index = decode(s, index) 
		local obj2 
		obj2, index = decode(s, index) 
		t[obj1] = obj2 
	end 
	index = index + 1 
	return t, index 
end 
	 
local function decode_string(s, index) 
	local a, b, len = s:find("^([0-9]+):", index) 
	assert(len, "not a length") 
	index = b + 1 
	 
	local v = s:sub(index, index + len - 1) 
	index = index + len 
	return v, index 
end 
	 
	 
function decode(s, index) 
	index = index or 1 
	local t = s:sub(index, index) 
	assert(t) 
	if t == "i" then 
		return decode_integer(s, index + 1) 
	elseif t == "l" then 
		return decode_list(s, index + 1) 
	elseif t == "d" then 
		return decode_dictionary(s, index + 1) 
	elseif t >= '0' and t <= '9' then 
		return decode_string(s, index) 
	else 
		error"invalid type" 
	end 
end

--[[--------------------------------------------------------------------------
The MIT License (MIT)
Copyright (c) 2014-2015,  Mark Rogaski.
--]]--------------------------------------------------------------------------
-- added into lockbox by TsT

local Stream = require("lockbox.util.stream");
local Array = require("lockbox.util.array");

local Bit = require("lockbox.util.bit");
--local Math = require("math");

local AND = assert(Bit.band);
local XOR = assert(Bit.bxor);
local LROT = assert(Bit.lrotate);
local RSHIFT = assert(Bit.rshift);


local salsa20 = {}

local function apply(f, y, z, slice)
	local iv = {}
	for i, j in ipairs(slice) do
		iv[i] = y[j]
	end
	local ov = f(iv)
	for i, j in ipairs(slice) do
		z[j] = ov[i]
	end
end

local function byte_inc(b)
	local c = 1
	for i = 1, 8 do
		local new = (b[i] + c) % 0xFF
		c = math.floor((b[i] + c) / 0xFF)
		b[i] = new
		if c == 0 then
			break
		end
	end
	return b
end


function salsa20.quarterround(y)
	assert(#y == 4)
	local z = {}
	z[2] = XOR(y[2], LROT(y[1] + y[4], 7))
	z[3] = XOR(y[3], LROT(z[2] + y[1], 9))
	z[4] = XOR(y[4], LROT(z[3] + z[2], 13))
	z[1] = XOR(y[1], LROT(z[4] + z[3], 18))
	return z
end

function salsa20.rowround(y)
	assert(#y == 16)
	local z = {}
	apply(salsa20.quarterround, y, z, {1, 2, 3, 4})
	apply(salsa20.quarterround, y, z, {6, 7, 8, 5})
	apply(salsa20.quarterround, y, z, {11, 12, 9, 10})
	apply(salsa20.quarterround, y, z, {16, 13, 14, 15})
	return z
end

function salsa20.columnround(y)
	assert(#y == 16)
	local z = {}
	apply(salsa20.quarterround, y, z, {1, 5, 9, 13})
	apply(salsa20.quarterround, y, z, {6, 10, 14, 2})
	apply(salsa20.quarterround, y, z, {11, 15, 3, 7})
	apply(salsa20.quarterround, y, z, {16, 4, 8, 12})
	return z
end

function salsa20.doubleround(y)
	assert(#y == 16)
	return salsa20.rowround(salsa20.columnround(y))
end

function salsa20.littleendian(b)
	assert(#b == 4)
	return b[1] + 2^8 * b[2] + 2^16 * b[3] + 2^24 * b[4]
end

function salsa20.littleendian_inv(x)
	local b = {}
	for i = 1, 4 do
		b[i] = AND(RSHIFT(x, (i - 1) * 8), 0xFF)
	end
	return b
end

function salsa20.hash(b, rounds)
	rounds = rounds or 20
	assert(#b == 64)
	assert(rounds == 20 or rounds == 12 or rounds == 8)
	local x = {}
	for i = 1, 16 do
		local quad = {}
		for j = 1, 4 do
			quad[j] = b[((i - 1) * 4) + j]
		end
		x[i] = salsa20.littleendian(quad)
	end
	local z = salsa20.doubleround(x)
	for i = 1, ((rounds / 2) - 1) do
		z = salsa20.doubleround(z)
	end
	local h = {}
	for i = 1, 16 do
		local y = salsa20.littleendian_inv(z[i] + x[i])
		for j = 1, 4 do
			h[((i - 1) * 4) + j] = y[j]
		end 
	end
	return h
end

function salsa20.expand(k, n)
	assert(#k == 16 or #k == 32)
	assert(#n == 16)

	local c = { string.byte(string.format("expand %2d-byte k", #k), 1, 16) } 
	local x = {}

	for i =  1,  4 do table.insert(x, c[i]) end
	for i =  1, 16 do table.insert(x, k[i]) end
	for i =  5,  8 do table.insert(x, c[i]) end
	for i =  1, 16 do table.insert(x, n[i]) end
	for i =  9, 12 do table.insert(x, c[i]) end
	if #k == 16 then
		for i =  1, 16 do table.insert(x, k[i]) end
	else
		for i = 17, 32 do table.insert(x, k[i]) end
	end
	for i = 13, 16 do table.insert(x, c[i]) end

	return x
end

--- Generate the i^th 64-byte block of the Salsa20_k(v) 2^70-byte sequence.
-- @param k A 16-byte or 32-byte sequence representing the secret key.
-- @param v An 8-byte sequence representing the nonce.
-- @param i An 8-byte sequence representing the stream position of the 64-byte block.
-- @param rounds Optional number of rounds. May be 20 (default), 12, or 8.
-- @return A 64-byte output block.
function salsa20.generate(k, v, i, rounds)
	assert(#k == 16 or #k == 32)
	assert(#v == 8)
	assert(#i == 8)
	local n = {}
	for j = 1, 8 do
		n[j]	 = v[j]
		n[j + 8] = i[j]
	end
	return salsa20.hash(salsa20.expand(k, n), rounds)
end

--- Encrypt a string.
-- @param key A 16-octet or 32-octet bytestring.
-- @param nonce An 8-octet bytestring nonce.
-- @param plaintext The unencrypted message.
-- @param rounds Optional number of rounds. May be 20 (default), 12, or 8.
-- @return The encrypted message.
function salsa20.encrypt(key, nonce, plaintext, rounds)
	assert(type(key) == "string" and (key:len() == 16 or key:len() == 32))
	assert(type(nonce) == "string" and nonce:len() == 8)
	assert(type(plaintext) == "string")
	
	local k = { key:byte(1, #key) }
	local v = { nonce:byte(1, #nonce) }
	local i = { 0, 0, 0, 0, 0, 0, 0, 0 }
	local store = {}
	local ciphertext = ""
	
	for _, m in pairs({ plaintext:byte(1, #plaintext) }) do
		if #store == 0 then
			store = salsa20.generate(k, v, i, rounds)
			i = byte_inc(i)
		end
		local r = table.remove(store, 1)
		ciphertext = ciphertext .. string.char(XOR(m, r))
	end
	return ciphertext
end

--- Decrypt a string.
-- @param key A 16-octet or 32-octet bytestring.
-- @param nonce An 8-octet bytestring nonce.
-- @param ciphertext The encrypted message.
-- @param rounds Optional number of rounds. May be 20 (default), 12, or 8.
-- @return The unencrypted message.
function salsa20.decrypt(key, nonce, ciphertext, rounds)
	-- The easiest thing I've done all week.
	salsa20.encrypt(key, nonce, ciphertext, rounds)
end

--- Encrypt a table of strings.
-- @param key A 16-octet or 32-octet bytestring.
-- @param nonce An 8-octet bytestring nonce.
-- @param plaintext The unencrypted messages.
-- @param rounds Optional number of rounds. May be 20 (default), 12, or 8.
-- @return The encrypted messages.
function salsa20.encrypt_table(key, nonce, plaintext, rounds)
	assert(type(key) == "string" and (key:len() == 16 or key:len() == 32))
	assert(type(nonce) == "string" and nonce:len() == 8)
	assert(type(plaintext) == "table")
	
	local k = { key:byte(1, #key) }
	local v = { nonce:byte(1, #nonce) }
	local i = { 0, 0, 0, 0, 0, 0, 0, 0 }
	local store = {}
	local ciphertext = {}
	
	for _, s in pairs(plaintext) do
		local segment = ""
		for _, m in pairs({ s:byte(1, #s) }) do
			if #store == 0 then
				store = salsa20.generate(k, v, i, rounds)
				i = byte_inc(i)
			end
			local r = table.remove(store, 1)
			segment = segment .. string.char(XOR(m, r))
		end
		table.insert(ciphertext, segment)
	end
	return ciphertext
end

--- Decrypt a string.
-- @param key A 16-octet or 32-octet bytestring.
-- @param nonce An 8-octet bytestring nonce.
-- @param ciphertext The encrypted messages.
-- @param rounds Optional number of rounds. May be 20 (default), 12, or 8.
-- @return The unencrypted messages.
function salsa20.decrypt_table(key, nonce, ciphertext, rounds)
	-- The second easiest thing I've done all week.
	salsa20.encrypt_table(key, nonce, ciphertext, rounds)
end

return salsa20

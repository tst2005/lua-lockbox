do --{{
local sources, priorities = {}, {};assert(not sources["lockbox.util.stream"],"module already exists")sources["lockbox.util.stream"]=([===[-- <pack lockbox.util.stream> --
local Queue = require("lockbox.util.queue");
local String = require("string");

local Stream = {};


Stream.fromString = function(string)
	local i=0;
	return function()
		i=i+1;
		if(i <= String.len(string)) then
			return String.byte(string,i);
		else
			return nil;
		end
	end
end


Stream.toString = function(stream)
	local array = {};
	local i=1;

	local byte = stream();
	while byte ~= nil do
		array[i] = String.char(byte);
		i = i+1;
		byte = stream();
	end

	return table.concat(array,"");
end


Stream.fromArray = function(array)
	local queue = Queue();
	local i=1;

	local byte = array[i];
	while byte ~= nil do
		queue.push(byte);
		i=i+1;
		byte = array[i];
	end

	return queue.pop;
end


Stream.toArray = function(stream)
	local array = {};
	local i=1;

	local byte = stream();
	while byte ~= nil do
		array[i] = byte;
		i = i+1;
		byte = stream();
	end

	return array;
end


local fromHexTable = {};
for i=0,255 do
	fromHexTable[String.format("%02X",i)]=i;
	fromHexTable[String.format("%02x",i)]=i;
end

Stream.fromHex = function(hex)
	local queue = Queue();

	for i=1,String.len(hex)/2 do
		local h = String.sub(hex,i*2-1,i*2);
		queue.push(fromHexTable[h]);
	end

	return queue.pop;
end



local toHexTable = {};
for i=0,255 do
	toHexTable[i]=String.format("%02X",i);
end

Stream.toHex = function(stream)
	local hex = {};
	local i = 1;

	local byte = stream();
	while byte ~= nil do
		hex[i] = toHexTable[byte];
		i=i+1;
		byte = stream();
	end

	return table.concat(hex,"");
end

return Stream;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.util.queue"],"module already exists")sources["lockbox.util.queue"]=([===[-- <pack lockbox.util.queue> --
local Queue = function()
	local queue = {};
	local tail = 0;
	local head = 0;

	local public = {};

	public.push = function(obj)
		queue[head] = obj;
		head = head + 1;
		return;
	end

	public.pop = function()
		if tail < head
		then
			local obj = queue[tail];
			queue[tail] = nil;
			tail = tail + 1;
			return obj;
		else
			return nil;
		end
	end

	public.size = function()
		return head - tail;
	end

	public.getHead = function()
		return head;
	end

	public.getTail = function()
		return tail;
	end

	public.reset = function()
		queue = {};
		head = 0;
		tail = 0;
	end

	return public;
end

return Queue;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.util.bit"],"module already exists")sources["lockbox.util.bit"]=([===[-- <pack lockbox.util.bit> --
local ok, e
if not ok then
	ok, e = pcall(require, "bit") -- the LuaJIT one ?
end
if not ok then
	ok, e = pcall(require, "bit32") -- Lua 5.2
end
if not ok then
	ok, e = pcall(require, "bit.numberlua") -- for Lua 5.1, https://github.com/tst2005/lua-bit-numberlua/
end
if not ok then
	error("no bitwise support found", 2)
end
assert(type(e)=="table", "invalid bit module")

-- Workaround to support Lua 5.2 bit32 API with the LuaJIT bit one
if e.rol and not e.lrotate then
	e.lrotate = e.rol
end
if e.ror and not e.rrotate then
	e.rrotate = e.ror
end

return e
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.mac.hmac"],"module already exists")sources["lockbox.mac.hmac"]=([===[-- <pack lockbox.mac.hmac> --
local Bit = require("lockbox.util.bit");
local String = require("string");
local Stream = require("lockbox.util.stream");
local Array = require("lockbox.util.array");

local XOR = Bit.bxor;

local HMAC = function()

	local public = {};
	local blockSize = 64;
	local Digest = nil;
	local outerPadding = {};
	local innerPadding = {}
	local digest;

	public.setBlockSize = function(bytes)
		blockSize = bytes;
		return public;
	end

	public.setDigest = function(digestModule)
		Digest = digestModule;
		digest = Digest();
		return public;
	end

	public.setKey = function(key)
		local keyStream;

		if(Array.size(key) > blockSize) then
			keyStream = Stream.fromArray(Digest()
						.update(Stream.fromArray(key))
						.finish()
						.asBytes());
		else
			keyStream = Stream.fromArray(key);
		end

		outerPadding = {};
		innerPadding = {};

		for i=1,blockSize do
			local byte = keyStream();
			if byte == nil then byte = 0x00; end
			outerPadding[i] = XOR(0x5C,byte);
			innerPadding[i] = XOR(0x36,byte);
		end

		return public;
	end

	public.init = function()
		digest	.init()
				.update(Stream.fromArray(innerPadding));
		return public;
	end

	public.update = function(messageStream)
		digest.update(messageStream);
		return public;
	end

	public.finish = function()
		local inner = digest.finish().asBytes();
		digest	.init()
				.update(Stream.fromArray(outerPadding))
				.update(Stream.fromArray(inner))
				.finish();

		return public;
	end

	public.asBytes = function()
		return digest.asBytes();
	end

	public.asHex = function()
		return digest.asHex();
	end

	return public;

end

return HMAC;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox"],"module already exists")sources["lockbox"]=([===[-- <pack lockbox> --
local Lockbox = {};

--[[
package.path =  "./?.lua;"
				.. "./cipher/?.lua;"
				.. "./digest/?.lua;"
				.. "./kdf/?.lua;"
				.. "./mac/?.lua;"
				.. "./padding/?.lua;"
				.. "./test/?.lua;"
				.. "./util/?.lua;"
				.. package.path;
]]--
Lockbox.ALLOW_INSECURE = false;

Lockbox.insecure = function()
	assert(Lockbox.ALLOW_INSECURE,"This module is insecure!  It should not be used in production.  If you really want to use it, set Lockbox.ALLOW_INSECURE to true before importing it");
end

return Lockbox;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.digest.sha1"],"module already exists")sources["lockbox.digest.sha1"]=([===[-- <pack lockbox.digest.sha1> --
require("lockbox").insecure();

local Bit = require("lockbox.util.bit");
local String = require("string");
local Math = require("math");
local Queue = require("lockbox.util.queue");

local AND = Bit.band;
local OR  = Bit.bor;
local NOT = Bit.bnot;
local XOR = Bit.bxor;
local LROT = Bit.lrotate;
local RROT = Bit.rrotate;
local LSHIFT = Bit.lshift;
local RSHIFT = Bit.rshift;

--SHA1 is big-endian
local bytes2word = function(b0,b1,b2,b3)
	local i = b0; i = LSHIFT(i,8);
	i = OR(i,b1); i = LSHIFT(i,8);
	i = OR(i,b2); i = LSHIFT(i,8);
	i = OR(i,b3);
	return i;
end

local word2bytes = function(word)
	local b0,b1,b2,b3;
	b3 = AND(word,0xFF); word = RSHIFT(word,8);
	b2 = AND(word,0xFF); word = RSHIFT(word,8);
	b1 = AND(word,0xFF); word = RSHIFT(word,8);
	b0 = AND(word,0xFF);
	return b0,b1,b2,b3;
end

local bytes2dword = function(b0,b1,b2,b3,b4,b5,b6,b7)
	local i = bytes2word(b0,b1,b2,b3);
	local j = bytes2word(b4,b5,b6,b7);
	return (i*0x100000000)+j;
end

local dword2bytes = function(i)
	local b4,b5,b6,b7 = word2bytes(i);
	local b0,b1,b2,b3 = word2bytes(Math.floor(i/0x100000000));
	return b0,b1,b2,b3,b4,b5,b6,b7;
end

local F = function(x,y,z) return OR(AND(x,y),AND(NOT(x),z)); end
local G = function(x,y,z) return XOR(x,XOR(y,z)); end
local H = function(x,y,z) return OR(AND(x,y),OR(AND(x,z),AND(y,z)));end
local I = function(x,y,z) return XOR(x,XOR(y,z)); end

local SHA1 = function()

	local queue = Queue();

	local h0 = 0x67452301;
	local h1 = 0xEFCDAB89;
	local h2 = 0x98BADCFE;
	local h3 = 0x10325476;
	local h4 = 0xC3D2E1F0;

	local public = {};

	local processBlock = function()
		local a = h0;
		local b = h1;
		local c = h2;
		local d = h3;
		local e = h4;
		local temp;
		local k;

		local w = {};
		for i=0,15 do
			w[i] = bytes2word(queue.pop(),queue.pop(),queue.pop(),queue.pop());
		end

		for i=16,79 do
			w[i] = LROT((XOR(XOR(w[i-3],w[i-8]),XOR(w[i-14],w[i-16]))),1);
		end

		for i=0,79 do
			if (0 <= i) and (i <= 19) then
				temp = F(b,c,d);
				k = 0x5A827999;
			elseif (20 <= i) and (i <= 39) then
				temp = G(b,c,d);
				k = 0x6ED9EBA1;
			elseif (40 <= i) and (i <= 59) then
				temp = H(b,c,d);
				k = 0x8F1BBCDC;
			elseif (60 <= i) and (i <= 79) then
				temp = I(b,c,d);
				k = 0xCA62C1D6;
			end
			temp = LROT(a,5) + temp + e + k + w[i];
			e = d;
			d = c;
			c = LROT(b,30);
			b = a;
			a = temp;
		end

		h0 = AND(h0 + a, 0xFFFFFFFF);
		h1 = AND(h1 + b, 0xFFFFFFFF);
		h2 = AND(h2 + c, 0xFFFFFFFF);
		h3 = AND(h3 + d, 0xFFFFFFFF);
		h4 = AND(h4 + e, 0xFFFFFFFF);
	end

	public.init = function()
		queue.reset();
		h0 = 0x67452301;
		h1 = 0xEFCDAB89;
		h2 = 0x98BADCFE;
		h3 = 0x10325476;
		h4 = 0xC3D2E1F0;
		return public;
	end


	public.update = function(bytes)
		for b in bytes do
			queue.push(b);
			if queue.size() >= 64 then processBlock(); end
		end

		return public;
	end

	public.finish = function()
		local bits = queue.getHead() * 8;

		queue.push(0x80);
		while ((queue.size()+7) % 64) < 63 do
			queue.push(0x00);
		end

		local b0,b1,b2,b3,b4,b5,b6,b7 = dword2bytes(bits);

		queue.push(b0);
		queue.push(b1);
		queue.push(b2);
		queue.push(b3);
		queue.push(b4);
		queue.push(b5);
		queue.push(b6);
		queue.push(b7);

		while queue.size() > 0 do
			processBlock();
		end

		return public;
	end

	public.asBytes = function()
		local  b0, b1, b2, b3 = word2bytes(h0);
		local  b4, b5, b6, b7 = word2bytes(h1);
		local  b8, b9,b10,b11 = word2bytes(h2);
		local b12,b13,b14,b15 = word2bytes(h3);
		local b16,b17,b18,b19 = word2bytes(h4);

		return {b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15,b16,b17,b18,b19};
	end

	public.asHex = function()
		local  b0, b1, b2, b3 = word2bytes(h0);
		local  b4, b5, b6, b7 = word2bytes(h1);
		local  b8, b9,b10,b11 = word2bytes(h2);
		local b12,b13,b14,b15 = word2bytes(h3);
		local b16,b17,b18,b19 = word2bytes(h4);

		return String.format("%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
				b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15,b16,b17,b18,b19);
	end

	return public;
end

return SHA1;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
local loadstring=_G.loadstring or _G.load; local preload = require"package".preload
local add = function(name, rawcode)
	if not preload[name] then
	        preload[name] = function(...) return assert(loadstring(rawcode), "loadstring: "..name.." failed")(...) end
	else
		print("WARNING: overwrite "..name)
	end
end
for name, rawcode in pairs(sources) do add(name, rawcode, priorities[name]) end
end; --}};
do -- preload auto aliasing...
	local p = require("package").preload
	for k,v in pairs(p) do
		if k:find("%.init$") then
			local short = k:gsub("%.init$", "")
			if not p[short] then
				p[short] = v
			end
		end
	end
end
do
	local Lockbox = require"lockbox"
	Lockbox.ALLOW_INSECURE = true
end

local Stream = require("lockbox.util.stream");
local Digest = require("lockbox.digest.sha1");
local String = require("string");

local function sha1sum(message)
	return Digest().update(Stream.fromString(message)).finish().asHex()
end
return sha1sum

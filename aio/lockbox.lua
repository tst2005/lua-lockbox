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
assert(not sources["lockbox.util.base64"],"module already exists")sources["lockbox.util.base64"]=([===[-- <pack lockbox.util.base64> --
local String = require("string");
local Bit = require("lockbox.util.bit");

local Array = require("lockbox.util.array");
local Stream = require("lockbox.util.stream");

local AND = Bit.band;
local OR  = Bit.bor;
local NOT = Bit.bnot;
local XOR = Bit.bxor;
local LROT = Bit.lrotate;
local RROT = Bit.rrotate;
local LSHIFT = Bit.lshift;
local RSHIFT = Bit.rshift;


local SYMBOLS = {
[0]="A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P",
    "Q","R","S","T","U","V","W","X","Y","Z","a","b","c","d","e","f",
    "g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v",
    "w","x","y","z","0","1","2","3","4","5","6","7","8","9","+","/"};

local LOOKUP = {};

for k,v in pairs(SYMBOLS) do
	LOOKUP[k]=v;
	LOOKUP[v]=k;
end


local Base64 = {};

Base64.fromStream = function(stream)
	local bits = 0x00;
	local bitCount = 0;
	local base64 = {};

	local byte = stream();
	while byte ~= nil do
		bits = OR(LSHIFT(bits,8),byte);
		bitCount = bitCount + 8;
		while bitCount >= 6 do
			bitCount = bitCount - 6;
			local temp = RSHIFT(bits,bitCount);
			table.insert(base64,LOOKUP[temp]);
			bits = AND(bits,NOT(LSHIFT(0xFFFFFFFF,bitCount)));
		end
		byte = stream();
	end

	if (bitCount == 4) then
		bits = LSHIFT(bits,2);
		table.insert(base64,LOOKUP[bits]);
		table.insert(base64,"=");
	elseif (bitCount == 2) then
		bits = LSHIFT(bits,4);
		table.insert(base64,LOOKUP[bits]);
		table.insert(base64,"==");
	end

	return table.concat(base64,"");
end

Base64.fromArray = function(array)
	local bits = 0x00;
	local bitCount = 0;
	local base64 = {};

	local ind = 1;

	local byte = array[ind]; ind = ind + 1;
	while byte ~= nil do
		bits = OR(LSHIFT(bits,8),byte);
		bitCount = bitCount + 8;
		while bitCount >= 6 do
			bitCount = bitCount - 6;
			local temp = RSHIFT(bits,bitCount);
			table.insert(base64,LOOKUP[temp]);
			bits = AND(bits,NOT(LSHIFT(0xFFFFFFFF,bitCount)));
		end
		byte = array[ind]; ind = ind + 1;
	end

	if (bitCount == 4) then
		bits = LSHIFT(bits,2);
		table.insert(base64,LOOKUP[bits]);
		table.insert(base64,"=");
	elseif (bitCount == 2) then
		bits = LSHIFT(bits,4);
		table.insert(base64,LOOKUP[bits]);
		table.insert(base64,"==");
	end

	return table.concat(base64,"");
end

Base64.fromString = function(string)
	return Base64.fromArray(Array.fromString(string));
end



Base64.toStream = function(base64)
	return Stream.fromArray(Base64.toArray(base64));
end

Base64.toArray = function(base64)
	local bits = 0x00;
	local bitCount = 0;

	local bytes = {};

	for c in String.gmatch(base64,".") do
		if (c == "=") then
			bits = RSHIFT(bits,2); bitCount = bitCount - 2;
		else
			bits = LSHIFT(bits,6); bitCount = bitCount + 6;
			bits = OR(bits,LOOKUP[c]);
		end

		while(bitCount >= 8) do
			bitCount = bitCount - 8;
			local temp = RSHIFT(bits,bitCount);
			table.insert(bytes,temp);
			bits = AND(bits,NOT(LSHIFT(0xFFFFFFFF,bitCount)));
		end
	end

	return bytes;
end

Base64.toString = function(base64)
	local bits = 0x00;
	local bitCount = 0;

	local chars = {};

	for c in String.gmatch(base64,".") do
		if (c == "=") then
			bits = RSHIFT(bits,2); bitCount = bitCount - 2;
		else
			bits = LSHIFT(bits,6); bitCount = bitCount + 6;
			bits = OR(bits,LOOKUP[c]);
		end

		while(bitCount >= 8) do
			bitCount = bitCount - 8;
			local temp = RSHIFT(bits,bitCount);
			table.insert(chars,String.char(temp));
			bits = AND(bits,NOT(LSHIFT(0xFFFFFFFF,bitCount)));
		end
	end

	return table.concat(chars,"");
end

return Base64;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.util.array"],"module already exists")sources["lockbox.util.array"]=([===[-- <pack lockbox.util.array> --

local String = require("string");
local Bit = require("lockbox.util.bit");

local XOR = Bit.bxor;

local Array = {};

Array.size = function(array)
	return #array;
end

Array.fromString = function(string)
	local bytes = {};

	local i=1;
	local byte = String.byte(string,i);
	while byte ~= nil do
		bytes[i] = byte;
		i = i + 1;
		byte = String.byte(string,i);
	end

	return bytes;

end

Array.toString = function(bytes)
	local chars = {};
	local i=1;

	local byte = bytes[i];
	while byte ~= nil do
		chars[i] = String.char(byte);
		i = i+1;
		byte = bytes[i];
	end

	return table.concat(chars,"");
end

Array.fromStream = function(stream)
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

Array.readFromQueue = function(queue,size)
	local array = {};

	for i=1,size do
		array[i] = queue.pop();
	end

	return array;
end

Array.writeToQueue = function(queue,array)
	local size = Array.size(array);

	for i=1,size do
		queue.push(array[i]);
	end
end

Array.toStream = function(array)
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


local fromHexTable = {};
for i=0,255 do
	fromHexTable[String.format("%02X",i)]=i;
	fromHexTable[String.format("%02x",i)]=i;
end

Array.fromHex = function(hex)
	local array = {};

	for i=1,String.len(hex)/2 do
		local h = String.sub(hex,i*2-1,i*2);
		array[i] = fromHexTable[h];
	end

	return array;
end


local toHexTable = {};
for i=0,255 do
	toHexTable[i]=String.format("%02X",i);
end

Array.toHex = function(array)
	local hex = {};
	local i = 1;

	local byte = array[i];
	while byte ~= nil do
		hex[i] = toHexTable[byte];
		i=i+1;
		byte = array[i];
	end

	return table.concat(hex,"");

end

Array.concat = function(a,b)
	local concat = {};
	local out=1;

	local i=1;
	local byte = a[i];
	while byte ~= nil do
		concat[out] = byte;
		i = i + 1;
		out = out + 1;
		byte = a[i];
	end

	local i=1;
	local byte = b[i];
	while byte ~= nil do
		concat[out] = byte;
		i = i + 1;
		out = out + 1;
		byte = b[i];
	end

	return concat;
end

Array.truncate = function(a,newSize)
	local x = {};

	for i=1,newSize do
		x[i]=a[i];
	end

	return x;
end

Array.XOR = function(a,b)
	local x = {};

	for k,v in pairs(a) do
		x[k] = XOR(v,b[k]);
	end

	return x;
end

Array.substitute = function(input,sbox)
	local out = {};

	for k,v in pairs(input) do
		out[k] = sbox[v];
	end

	return out;
end

Array.permute = function(input,pbox)
	local out = {};

	for k,v in pairs(pbox) do
		out[k] = input[v];
	end

	return out;
end

Array.copy = function(input)
	local out = {};

	for k,v in pairs(input) do
		out[k] = v;
	end
	return out;
end

Array.slice = function(input,start,stop)
	local out = {};

	for i=start,stop do
		out[i-start+1] = input[i];
	end
	return out;
end

return Array;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.padding.zero"],"module already exists")sources["lockbox.padding.zero"]=([===[-- <pack lockbox.padding.zero> --
local Stream = require("lockbox.util.stream");

local ZeroPadding = function(blockSize,byteCount)

	local paddingCount = blockSize - ((byteCount -1) % blockSize) + 1;
	local bytesLeft = paddingCount;

	local stream = function()
		if bytesLeft > 0 then
			bytesLeft = bytesLeft - 1;
			return 0x00;
		else
			return nil;
		end
	end

	return stream;

end

return ZeroPadding;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.padding.pkcs7"],"module already exists")sources["lockbox.padding.pkcs7"]=([===[-- <pack lockbox.padding.pkcs7> --
local Stream = require("lockbox.util.stream");

local PKCS7Padding = function(blockSize,byteCount)

	local paddingCount = blockSize - ((byteCount -1) % blockSize) + 1;
	local bytesLeft = paddingCount;

	local stream = function()
		if bytesLeft > 0 then
			bytesLeft = bytesLeft - 1;
			return paddingCount;
		else
			return nil;
		end
	end

	return stream;
end

return PKCS7Padding;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.padding.isoiec7816"],"module already exists")sources["lockbox.padding.isoiec7816"]=([===[-- <pack lockbox.padding.isoiec7816> --
local Stream = require("lockbox.util.stream");


local ISOIEC7816Padding = function(blockSize,byteCount)

	local paddingCount = blockSize - (byteCount % blockSize);
	local bytesLeft = paddingCount;

	local stream = function()
		if bytesLeft == paddingCount then
			bytesLeft = bytesLeft - 1;
			return 0x80;
		elseif bytesLeft > 0 then
			bytesLeft = bytesLeft - 1;
			return 0x00;
		else
			return nil;
		end
	end

	return stream;

end

return ISOIEC7816Padding;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.padding.ansix923"],"module already exists")sources["lockbox.padding.ansix923"]=([===[-- <pack lockbox.padding.ansix923> --
local Stream = require("lockbox.util.stream");

local ANSIX923Padding = function(blockSize,byteCount)

	local paddingCount = blockSize - (byteCount % blockSize);
	local bytesLeft = paddingCount;

	local stream = function()
		if bytesLeft > 1 then
			bytesLeft = bytesLeft - 1;
			return 0x00;
		elseif bytesLeft > 0 then
			bytesLeft = bytesLeft - 1;
			return paddingCount;
		else
			return nil;
		end
	end

	return stream;

end

return ANSIX923Padding;
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
assert(not sources["lockbox.kdf.pbkdf2"],"module already exists")sources["lockbox.kdf.pbkdf2"]=([===[-- <pack lockbox.kdf.pbkdf2> --
local Bit = require("lockbox.util.bit");
local String = require("string");
local Array = require("lockbox.util.array");
local Stream = require("lockbox.util.stream");
local Math = require("math");

local AND = Bit.band;
local OR  = Bit.bor;
local NOT = Bit.bnot;
local XOR = Bit.bxor;
local LROT = Bit.lrotate;
local RROT = Bit.rrotate;
local LSHIFT = Bit.lshift;
local RSHIFT = Bit.rshift;

--PBKDF2 is big-endian
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
	local b0,b1,b2,b3 = word2bytes(i/0x100000000);
	return b0,b1,b2,b3,b4,b5,b6,b7;
end



local PBKDF2 = function()

	local public = {};

	local blockLen = 16;
	local dKeyLen = 256;
	local iterations = 4096;

	local salt;
	local password;


	local PRF;

	local dKey;


	public.setBlockLen = function(len)
		blockLen = len;
		return public;
	end

	public.setDKeyLen = function(len)
		dKeyLen = len
		return public;
	end

	public.setIterations = function(iter)
		iterations = iter;
		return public;
	end

	public.setSalt = function(saltBytes)
		salt = saltBytes;
		return public;
	end

	public.setPassword = function(passwordBytes)
		password = passwordBytes;
		return public;
	end

	public.setPRF = function(prf)
		PRF = prf;
		return public;
	end

	local buildBlock = function(i)
		local b0,b1,b2,b3 = word2bytes(i);
		local ii = {b0,b1,b2,b3};
		local s = Array.concat(salt,ii);

		local out = {};

		PRF.setKey(password);
		for c = 1,iterations do
			PRF.init()
				.update(Stream.fromArray(s));

			s = PRF.finish().asBytes();
			if(c > 1) then
				out = Array.XOR(out,s);
			else
				out = s;
			end
		end

		return out;
	end

	public.finish = function()
		local blocks = Math.ceil(dKeyLen / blockLen);

		dKey = {};

		for b = 1, blocks do
			local block = buildBlock(b);
			dKey = Array.concat(dKey,block);
		end

		if(Array.size(dKey) > dKeyLen) then dKey = Array.truncate(dKey,dKeyLen); end

		return public;
	end

	public.asBytes = function()
		return dKey;
	end

	public.asHex = function()
		return Array.toHex(dKey);
	end

	return public;
end

return PBKDF2;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.digest.sha2_256"],"module already exists")sources["lockbox.digest.sha2_256"]=([===[-- <pack lockbox.digest.sha2_256> --
local Bit = require("lockbox.util.bit");
local String = require("string");
local Math = require("math");
local Queue = require("lockbox.util.queue");

local CONSTANTS = {
   0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
   0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
   0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
   0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
   0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
   0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
   0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
   0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2  };

local AND = Bit.band;
local OR  = Bit.bor;
local NOT = Bit.bnot;
local XOR = Bit.bxor;
local LROT = Bit.lrotate;
local RROT = Bit.rrotate;
local LSHIFT = Bit.lshift;
local RSHIFT = Bit.rshift;

--SHA2 is big-endian
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




local SHA2_256 = function()

	local queue = Queue();

	local h0 = 0x6a09e667;
	local h1 = 0xbb67ae85;
	local h2 = 0x3c6ef372;
	local h3 = 0xa54ff53a;
	local h4 = 0x510e527f;
	local h5 = 0x9b05688c;
	local h6 = 0x1f83d9ab;
	local h7 = 0x5be0cd19;

	local public = {};

	local processBlock = function()
		local a = h0;
		local b = h1;
		local c = h2;
		local d = h3;
		local e = h4;
		local f = h5;
		local g = h6;
		local h = h7;

		local w = {};

		for i=0,15 do
			w[i] = bytes2word(queue.pop(),queue.pop(),queue.pop(),queue.pop());
		end

		for i=16,63 do
			local s0 = XOR(RROT(w[i-15],7), XOR(RROT(w[i-15],18), RSHIFT(w[i-15],3)));
			local s1 = XOR(RROT(w[i-2],17), XOR(RROT(w[i-2], 19), RSHIFT(w[i-2],10)));
			w[i] = AND(w[i-16] + s0 + w[i-7] + s1, 0xFFFFFFFF);
		end

		for i=0,63 do
			local s1 = XOR(RROT(e,6), XOR(RROT(e,11),RROT(e,25)));
			local ch = XOR(AND(e,f), AND(NOT(e),g));
			local temp1 = h + s1 + ch + CONSTANTS[i+1] + w[i];
			local s0 = XOR(RROT(a,2), XOR(RROT(a,13), RROT(a,22)));
			local maj = XOR(AND(a,b), XOR(AND(a,c), AND(b,c)));
			local temp2 = s0 + maj;

			h = g;
			g = f;
			f = e;
			e = d + temp1;
			d = c;
			c = b;
			b = a;
			a = temp1 + temp2;
		end

		h0 = AND(h0 + a, 0xFFFFFFFF);
		h1 = AND(h1 + b, 0xFFFFFFFF);
		h2 = AND(h2 + c, 0xFFFFFFFF);
		h3 = AND(h3 + d, 0xFFFFFFFF);
		h4 = AND(h4 + e, 0xFFFFFFFF);
		h5 = AND(h5 + f, 0xFFFFFFFF);
		h6 = AND(h6 + g, 0xFFFFFFFF);
		h7 = AND(h7 + h, 0xFFFFFFFF);
	end

	public.init = function()
		queue.reset();

		h0 = 0x6a09e667;
		h1 = 0xbb67ae85;
		h2 = 0x3c6ef372;
		h3 = 0xa54ff53a;
		h4 = 0x510e527f;
		h5 = 0x9b05688c;
		h6 = 0x1f83d9ab;
		h7 = 0x5be0cd19;

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
		local b20,b21,b22,b23 = word2bytes(h5);
		local b24,b25,b26,b27 = word2bytes(h6);
		local b28,b29,b30,b31 = word2bytes(h7);


		return {  b0, b1, b2, b3, b4, b5, b6, b7, b8, b9,b10,b11,b12,b13,b14,b15
				,b16,b17,b18,b19,b20,b21,b22,b23,b24,b25,b26,b27,b28,b29,b30,b31};
	end

	public.asHex = function()
		local  b0, b1, b2, b3 = word2bytes(h0);
		local  b4, b5, b6, b7 = word2bytes(h1);
		local  b8, b9,b10,b11 = word2bytes(h2);
		local b12,b13,b14,b15 = word2bytes(h3);
		local b16,b17,b18,b19 = word2bytes(h4);
		local b20,b21,b22,b23 = word2bytes(h5);
		local b24,b25,b26,b27 = word2bytes(h6);
		local b28,b29,b30,b31 = word2bytes(h7);

		local fmt = "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x"

		return String.format(fmt, b0, b1, b2, b3, b4, b5, b6, b7, b8, b9,b10,b11,b12,b13,b14,b15
				,b16,b17,b18,b19,b20,b21,b22,b23,b24,b25,b26,b27,b28,b29,b30,b31);
	end

	return public;

end

return SHA2_256;

]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.digest.sha2_224"],"module already exists")sources["lockbox.digest.sha2_224"]=([===[-- <pack lockbox.digest.sha2_224> --
local Bit = require("lockbox.util.bit");
local String = require("string");
local Math = require("math");
local Queue = require("lockbox.util.queue");

local CONSTANTS = {
   0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
   0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
   0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
   0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
   0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
   0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
   0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
   0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2  };

local AND = Bit.band;
local OR  = Bit.bor;
local NOT = Bit.bnot;
local XOR = Bit.bxor;
local LROT = Bit.lrotate;
local RROT = Bit.rrotate;
local LSHIFT = Bit.lshift;
local RSHIFT = Bit.rshift;

--SHA2 is big-endian
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




local SHA2_224 = function()

	local queue = Queue();

	local h0 = 0xc1059ed8;
	local h1 = 0x367cd507;
	local h2 = 0x3070dd17;
	local h3 = 0xf70e5939;
	local h4 = 0xffc00b31;
	local h5 = 0x68581511;
	local h6 = 0x64f98fa7;
	local h7 = 0xbefa4fa4;

	local public = {};

	local processBlock = function()
		local a = h0;
		local b = h1;
		local c = h2;
		local d = h3;
		local e = h4;
		local f = h5;
		local g = h6;
		local h = h7;

		local w = {};

		for i=0,15 do
			w[i] = bytes2word(queue.pop(),queue.pop(),queue.pop(),queue.pop());
		end

		for i=16,63 do
			local s0 = XOR(RROT(w[i-15],7), XOR(RROT(w[i-15],18), RSHIFT(w[i-15],3)));
			local s1 = XOR(RROT(w[i-2],17), XOR(RROT(w[i-2], 19), RSHIFT(w[i-2],10)));
			w[i] = AND(w[i-16] + s0 + w[i-7] + s1, 0xFFFFFFFF);
		end

		for i=0,63 do
			local s1 = XOR(RROT(e,6), XOR(RROT(e,11),RROT(e,25)));
			local ch = XOR(AND(e,f), AND(NOT(e),g));
			local temp1 = h + s1 + ch + CONSTANTS[i+1] + w[i];
			local s0 = XOR(RROT(a,2), XOR(RROT(a,13), RROT(a,22)));
			local maj = XOR(AND(a,b), XOR(AND(a,c), AND(b,c)));
			local temp2 = s0 + maj;

			h = g;
			g = f;
			f = e;
			e = d + temp1;
			d = c;
			c = b;
			b = a;
			a = temp1 + temp2;
		end

		h0 = AND(h0 + a, 0xFFFFFFFF);
		h1 = AND(h1 + b, 0xFFFFFFFF);
		h2 = AND(h2 + c, 0xFFFFFFFF);
		h3 = AND(h3 + d, 0xFFFFFFFF);
		h4 = AND(h4 + e, 0xFFFFFFFF);
		h5 = AND(h5 + f, 0xFFFFFFFF);
		h6 = AND(h6 + g, 0xFFFFFFFF);
		h7 = AND(h7 + h, 0xFFFFFFFF);
	end

	public.init = function()
		queue.reset();

		h0 = 0xc1059ed8;
		h1 = 0x367cd507;
		h2 = 0x3070dd17;
		h3 = 0xf70e5939;
		h4 = 0xffc00b31;
		h5 = 0x68581511;
		h6 = 0x64f98fa7;
		h7 = 0xbefa4fa4;

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
		local b20,b21,b22,b23 = word2bytes(h5);
		local b24,b25,b26,b27 = word2bytes(h6);

		return {  b0, b1, b2, b3, b4, b5, b6, b7, b8, b9,b10,b11,b12,b13,b14,b15
				,b16,b17,b18,b19,b20,b21,b22,b23,b24,b25,b26,b27};
	end

	public.asHex = function()
		local  b0, b1, b2, b3 = word2bytes(h0);
		local  b4, b5, b6, b7 = word2bytes(h1);
		local  b8, b9,b10,b11 = word2bytes(h2);
		local b12,b13,b14,b15 = word2bytes(h3);
		local b16,b17,b18,b19 = word2bytes(h4);
		local b20,b21,b22,b23 = word2bytes(h5);
		local b24,b25,b26,b27 = word2bytes(h6);

		local fmt = "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x"

		return String.format(fmt, b0, b1, b2, b3, b4, b5, b6, b7, b8, b9,b10,b11,b12,b13,b14,b15
				,b16,b17,b18,b19,b20,b21,b22,b23,b24,b25,b26,b27);
	end

	return public;

end

return SHA2_224;

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
assert(not sources["lockbox.digest.ripemd160"],"module already exists")sources["lockbox.digest.ripemd160"]=([===[-- <pack lockbox.digest.ripemd160> --
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

--RIPEMD160 is little-endian
local bytes2word = function(b0,b1,b2,b3)
	local i = b3; i = LSHIFT(i,8);
	i = OR(i,b2); i = LSHIFT(i,8);
	i = OR(i,b1); i = LSHIFT(i,8);
	i = OR(i,b0);
	return i;
end

local word2bytes = function(word)
	local b0,b1,b2,b3;
	b0 = AND(word,0xFF); word = RSHIFT(word,8);
	b1 = AND(word,0xFF); word = RSHIFT(word,8);
	b2 = AND(word,0xFF); word = RSHIFT(word,8);
	b3 = AND(word,0xFF);
	return b0,b1,b2,b3;
end

local bytes2dword = function(b0,b1,b2,b3,b4,b5,b6,b7)
	local i = bytes2word(b0,b1,b2,b3);
	local j = bytes2word(b4,b5,b6,b7);
	return (j*0x100000000)+i;
end

local dword2bytes = function(i)
	local b4,b5,b6,b7 = word2bytes(Math.floor(i/0x100000000));
	local b0,b1,b2,b3 = word2bytes(i);
	return b0,b1,b2,b3,b4,b5,b6,b7;
end

local F = function(x,y,z) return XOR(x, XOR(y,z)); end
local G = function(x,y,z) return OR(AND(x,y), AND(NOT(x),z)); end
local H = function(x,y,z) return XOR(OR(x,NOT(y)),z); end
local I = function(x,y,z) return OR(AND(x,z),AND(y,NOT(z))); end
local J = function(x,y,z) return XOR(x,OR(y,NOT(z))); end

local FF = function(a,b,c,d,e,x,s)
	a = a + F(b,c,d) + x;
	a = LROT(a,s) + e;
	a = AND(a, 0xFFFFFFFF);
	return a;
end

local GG = function(a,b,c,d,e,x,s)
	a = a + G(b,c,d) + x + 0x5a827999;
	a = LROT(a,s) + e;
	a = AND(a, 0xFFFFFFFF);
	return a;
end

local HH = function(a,b,c,d,e,x,s)
	a = a + H(b,c,d) + x + 0x6ed9eba1;
	a = LROT(a,s) + e;
	a = AND(a, 0xFFFFFFFF);
	return a;
end

local II = function(a,b,c,d,e,x,s)
	a = a + I(b,c,d) + x + 0x8f1bbcdc;
	a = LROT(a,s) + e;
	a = AND(a, 0xFFFFFFFF);
	return a;
end

local JJ = function(a,b,c,d,e,x,s)
	a = a + J(b,c,d) + x + 0xa953fd4e;
	a = LROT(a,s) + e;
	a = AND(a, 0xFFFFFFFF);
	return a;
end

local FFF = function(a,b,c,d,e,x,s)
	a = a + F(b,c,d) + x;
	a = LROT(a,s) + e;
	a = AND(a, 0xFFFFFFFF);
	return a;
end

local GGG = function(a,b,c,d,e,x,s)
	a = a + G(b,c,d) + x + 0x7a6d76e9;
	a = LROT(a,s) + e;
	a = AND(a, 0xFFFFFFFF);
	return a;
end

local HHH = function(a,b,c,d,e,x,s)
	a = a + H(b,c,d) + x + 0x6d703ef3;
	a = LROT(a,s) + e;
	a = AND(a, 0xFFFFFFFF);
	return a;
end

local III = function(a,b,c,d,e,x,s)
	a = a + I(b,c,d) + x + 0x5c4dd124;
	a = LROT(a,s) + e;
	a = AND(a, 0xFFFFFFFF);
	return a;
end

local JJJ = function(a,b,c,d,e,x,s)
	a = a + J(b,c,d) + x + 0x50a28be6;
	a = LROT(a,s) + e;
	a = AND(a, 0xFFFFFFFF);
	return a;
end

local RIPEMD160 = function()

	local queue = Queue();

	local A = 0x67452301;
	local B = 0xefcdab89;
	local C = 0x98badcfe;
	local D = 0x10325476;
	local E = 0xc3d2e1f0;

	local public = {};

	local processBlock = function()
		local aa,bb,cc,dd,ee = A,B,C,D,E;
		local aaa,bbb,ccc,ddd,eee = A,B,C,D,E;

		local X = {};

		for i=0,15 do
			X[i] = bytes2word(queue.pop(),queue.pop(),queue.pop(),queue.pop());
		end

		aa, cc = FF(aa, bb, cc, dd, ee, X[ 0], 11), LROT(cc,10);
		ee, bb = FF(ee, aa, bb, cc, dd, X[ 1], 14), LROT(bb,10);
		dd, aa = FF(dd, ee, aa, bb, cc, X[ 2], 15), LROT(aa,10);
		cc, ee = FF(cc, dd, ee, aa, bb, X[ 3], 12), LROT(ee,10);
		bb, dd = FF(bb, cc, dd, ee, aa, X[ 4],  5), LROT(dd,10);
		aa, cc = FF(aa, bb, cc, dd, ee, X[ 5],  8), LROT(cc,10);
		ee, bb = FF(ee, aa, bb, cc, dd, X[ 6],  7), LROT(bb,10);
		dd, aa = FF(dd, ee, aa, bb, cc, X[ 7],  9), LROT(aa,10);
		cc, ee = FF(cc, dd, ee, aa, bb, X[ 8], 11), LROT(ee,10);
		bb, dd = FF(bb, cc, dd, ee, aa, X[ 9], 13), LROT(dd,10);
		aa, cc = FF(aa, bb, cc, dd, ee, X[10], 14), LROT(cc,10);
		ee, bb = FF(ee, aa, bb, cc, dd, X[11], 15), LROT(bb,10);
		dd, aa = FF(dd, ee, aa, bb, cc, X[12],  6), LROT(aa,10);
		cc, ee = FF(cc, dd, ee, aa, bb, X[13],  7), LROT(ee,10);
		bb, dd = FF(bb, cc, dd, ee, aa, X[14],  9), LROT(dd,10);
		aa, cc = FF(aa, bb, cc, dd, ee, X[15],  8), LROT(cc,10);

		ee, bb = GG(ee, aa, bb, cc, dd, X[ 7],  7), LROT(bb,10);
		dd, aa = GG(dd, ee, aa, bb, cc, X[ 4],  6), LROT(aa,10);
		cc, ee = GG(cc, dd, ee, aa, bb, X[13],  8), LROT(ee,10);
		bb, dd = GG(bb, cc, dd, ee, aa, X[ 1], 13), LROT(dd,10);
		aa, cc = GG(aa, bb, cc, dd, ee, X[10], 11), LROT(cc,10);
		ee, bb = GG(ee, aa, bb, cc, dd, X[ 6],  9), LROT(bb,10);
		dd, aa = GG(dd, ee, aa, bb, cc, X[15],  7), LROT(aa,10);
		cc, ee = GG(cc, dd, ee, aa, bb, X[ 3], 15), LROT(ee,10);
		bb, dd = GG(bb, cc, dd, ee, aa, X[12],  7), LROT(dd,10);
		aa, cc = GG(aa, bb, cc, dd, ee, X[ 0], 12), LROT(cc,10);
		ee, bb = GG(ee, aa, bb, cc, dd, X[ 9], 15), LROT(bb,10);
		dd, aa = GG(dd, ee, aa, bb, cc, X[ 5],  9), LROT(aa,10);
		cc, ee = GG(cc, dd, ee, aa, bb, X[ 2], 11), LROT(ee,10);
		bb, dd = GG(bb, cc, dd, ee, aa, X[14],  7), LROT(dd,10);
		aa, cc = GG(aa, bb, cc, dd, ee, X[11], 13), LROT(cc,10);
		ee, bb = GG(ee, aa, bb, cc, dd, X[ 8], 12), LROT(bb,10);

		dd, aa = HH(dd, ee, aa, bb, cc, X[ 3], 11), LROT(aa,10);
		cc, ee = HH(cc, dd, ee, aa, bb, X[10], 13), LROT(ee,10);
		bb, dd = HH(bb, cc, dd, ee, aa, X[14],  6), LROT(dd,10);
		aa, cc = HH(aa, bb, cc, dd, ee, X[ 4],  7), LROT(cc,10);
		ee, bb = HH(ee, aa, bb, cc, dd, X[ 9], 14), LROT(bb,10);
		dd, aa = HH(dd, ee, aa, bb, cc, X[15],  9), LROT(aa,10);
		cc, ee = HH(cc, dd, ee, aa, bb, X[ 8], 13), LROT(ee,10);
		bb, dd = HH(bb, cc, dd, ee, aa, X[ 1], 15), LROT(dd,10);
		aa, cc = HH(aa, bb, cc, dd, ee, X[ 2], 14), LROT(cc,10);
		ee, bb = HH(ee, aa, bb, cc, dd, X[ 7],  8), LROT(bb,10);
		dd, aa = HH(dd, ee, aa, bb, cc, X[ 0], 13), LROT(aa,10);
		cc, ee = HH(cc, dd, ee, aa, bb, X[ 6],  6), LROT(ee,10);
		bb, dd = HH(bb, cc, dd, ee, aa, X[13],  5), LROT(dd,10);
		aa, cc = HH(aa, bb, cc, dd, ee, X[11], 12), LROT(cc,10);
		ee, bb = HH(ee, aa, bb, cc, dd, X[ 5],  7), LROT(bb,10);
		dd, aa = HH(dd, ee, aa, bb, cc, X[12],  5), LROT(aa,10);

		cc, ee = II(cc, dd, ee, aa, bb, X[ 1], 11), LROT(ee,10);
		bb, dd = II(bb, cc, dd, ee, aa, X[ 9], 12), LROT(dd,10);
		aa, cc = II(aa, bb, cc, dd, ee, X[11], 14), LROT(cc,10);
		ee, bb = II(ee, aa, bb, cc, dd, X[10], 15), LROT(bb,10);
		dd, aa = II(dd, ee, aa, bb, cc, X[ 0], 14), LROT(aa,10);
		cc, ee = II(cc, dd, ee, aa, bb, X[ 8], 15), LROT(ee,10);
		bb, dd = II(bb, cc, dd, ee, aa, X[12],  9), LROT(dd,10);
		aa, cc = II(aa, bb, cc, dd, ee, X[ 4],  8), LROT(cc,10);
		ee, bb = II(ee, aa, bb, cc, dd, X[13],  9), LROT(bb,10);
		dd, aa = II(dd, ee, aa, bb, cc, X[ 3], 14), LROT(aa,10);
		cc, ee = II(cc, dd, ee, aa, bb, X[ 7],  5), LROT(ee,10);
		bb, dd = II(bb, cc, dd, ee, aa, X[15],  6), LROT(dd,10);
		aa, cc = II(aa, bb, cc, dd, ee, X[14],  8), LROT(cc,10);
		ee, bb = II(ee, aa, bb, cc, dd, X[ 5],  6), LROT(bb,10);
		dd, aa = II(dd, ee, aa, bb, cc, X[ 6],  5), LROT(aa,10);
		cc, ee = II(cc, dd, ee, aa, bb, X[ 2], 12), LROT(ee,10);

		bb, dd = JJ(bb, cc, dd, ee, aa, X[ 4],  9), LROT(dd,10);
		aa, cc = JJ(aa, bb, cc, dd, ee, X[ 0], 15), LROT(cc,10);
		ee, bb = JJ(ee, aa, bb, cc, dd, X[ 5],  5), LROT(bb,10);
		dd, aa = JJ(dd, ee, aa, bb, cc, X[ 9], 11), LROT(aa,10);
		cc, ee = JJ(cc, dd, ee, aa, bb, X[ 7],  6), LROT(ee,10);
		bb, dd = JJ(bb, cc, dd, ee, aa, X[12],  8), LROT(dd,10);
		aa, cc = JJ(aa, bb, cc, dd, ee, X[ 2], 13), LROT(cc,10);
		ee, bb = JJ(ee, aa, bb, cc, dd, X[10], 12), LROT(bb,10);
		dd, aa = JJ(dd, ee, aa, bb, cc, X[14],  5), LROT(aa,10);
		cc, ee = JJ(cc, dd, ee, aa, bb, X[ 1], 12), LROT(ee,10);
		bb, dd = JJ(bb, cc, dd, ee, aa, X[ 3], 13), LROT(dd,10);
		aa, cc = JJ(aa, bb, cc, dd, ee, X[ 8], 14), LROT(cc,10);
		ee, bb = JJ(ee, aa, bb, cc, dd, X[11], 11), LROT(bb,10);
		dd, aa = JJ(dd, ee, aa, bb, cc, X[ 6],  8), LROT(aa,10);
		cc, ee = JJ(cc, dd, ee, aa, bb, X[15],  5), LROT(ee,10);
		bb, dd = JJ(bb, cc, dd, ee, aa, X[13],  6), LROT(dd,10);

		aaa, ccc = JJJ(aaa, bbb, ccc, ddd, eee, X[ 5],  8), LROT(ccc,10);
		eee, bbb = JJJ(eee, aaa, bbb, ccc, ddd, X[14],  9), LROT(bbb,10);
		ddd, aaa = JJJ(ddd, eee, aaa, bbb, ccc, X[ 7],  9), LROT(aaa,10);
		ccc, eee = JJJ(ccc, ddd, eee, aaa, bbb, X[ 0], 11), LROT(eee,10);
		bbb, ddd = JJJ(bbb, ccc, ddd, eee, aaa, X[ 9], 13), LROT(ddd,10);
		aaa, ccc = JJJ(aaa, bbb, ccc, ddd, eee, X[ 2], 15), LROT(ccc,10);
		eee, bbb = JJJ(eee, aaa, bbb, ccc, ddd, X[11], 15), LROT(bbb,10);
		ddd, aaa = JJJ(ddd, eee, aaa, bbb, ccc, X[ 4],  5), LROT(aaa,10);
		ccc, eee = JJJ(ccc, ddd, eee, aaa, bbb, X[13],  7), LROT(eee,10);
		bbb, ddd = JJJ(bbb, ccc, ddd, eee, aaa, X[ 6],  7), LROT(ddd,10);
		aaa, ccc = JJJ(aaa, bbb, ccc, ddd, eee, X[15],  8), LROT(ccc,10);
		eee, bbb = JJJ(eee, aaa, bbb, ccc, ddd, X[ 8], 11), LROT(bbb,10);
		ddd, aaa = JJJ(ddd, eee, aaa, bbb, ccc, X[ 1], 14), LROT(aaa,10);
		ccc, eee = JJJ(ccc, ddd, eee, aaa, bbb, X[10], 14), LROT(eee,10);
		bbb, ddd = JJJ(bbb, ccc, ddd, eee, aaa, X[ 3], 12), LROT(ddd,10);
		aaa, ccc = JJJ(aaa, bbb, ccc, ddd, eee, X[12],  6), LROT(ccc,10);

		eee, bbb = III(eee, aaa, bbb, ccc, ddd, X[ 6],  9), LROT(bbb,10);
		ddd, aaa = III(ddd, eee, aaa, bbb, ccc, X[11], 13), LROT(aaa,10);
		ccc, eee = III(ccc, ddd, eee, aaa, bbb, X[ 3], 15), LROT(eee,10);
		bbb, ddd = III(bbb, ccc, ddd, eee, aaa, X[ 7],  7), LROT(ddd,10);
		aaa, ccc = III(aaa, bbb, ccc, ddd, eee, X[ 0], 12), LROT(ccc,10);
		eee, bbb = III(eee, aaa, bbb, ccc, ddd, X[13],  8), LROT(bbb,10);
		ddd, aaa = III(ddd, eee, aaa, bbb, ccc, X[ 5],  9), LROT(aaa,10);
		ccc, eee = III(ccc, ddd, eee, aaa, bbb, X[10], 11), LROT(eee,10);
		bbb, ddd = III(bbb, ccc, ddd, eee, aaa, X[14],  7), LROT(ddd,10);
		aaa, ccc = III(aaa, bbb, ccc, ddd, eee, X[15],  7), LROT(ccc,10);
		eee, bbb = III(eee, aaa, bbb, ccc, ddd, X[ 8], 12), LROT(bbb,10);
		ddd, aaa = III(ddd, eee, aaa, bbb, ccc, X[12],  7), LROT(aaa,10);
		ccc, eee = III(ccc, ddd, eee, aaa, bbb, X[ 4],  6), LROT(eee,10);
		bbb, ddd = III(bbb, ccc, ddd, eee, aaa, X[ 9], 15), LROT(ddd,10);
		aaa, ccc = III(aaa, bbb, ccc, ddd, eee, X[ 1], 13), LROT(ccc,10);
		eee, bbb = III(eee, aaa, bbb, ccc, ddd, X[ 2], 11), LROT(bbb,10);

		ddd, aaa = HHH(ddd, eee, aaa, bbb, ccc, X[15],  9), LROT(aaa,10);
		ccc, eee = HHH(ccc, ddd, eee, aaa, bbb, X[ 5],  7), LROT(eee,10);
		bbb, ddd = HHH(bbb, ccc, ddd, eee, aaa, X[ 1], 15), LROT(ddd,10);
		aaa, ccc = HHH(aaa, bbb, ccc, ddd, eee, X[ 3], 11), LROT(ccc,10);
		eee, bbb = HHH(eee, aaa, bbb, ccc, ddd, X[ 7],  8), LROT(bbb,10);
		ddd, aaa = HHH(ddd, eee, aaa, bbb, ccc, X[14],  6), LROT(aaa,10);
		ccc, eee = HHH(ccc, ddd, eee, aaa, bbb, X[ 6],  6), LROT(eee,10);
		bbb, ddd = HHH(bbb, ccc, ddd, eee, aaa, X[ 9], 14), LROT(ddd,10);
		aaa, ccc = HHH(aaa, bbb, ccc, ddd, eee, X[11], 12), LROT(ccc,10);
		eee, bbb = HHH(eee, aaa, bbb, ccc, ddd, X[ 8], 13), LROT(bbb,10);
		ddd, aaa = HHH(ddd, eee, aaa, bbb, ccc, X[12],  5), LROT(aaa,10);
		ccc, eee = HHH(ccc, ddd, eee, aaa, bbb, X[ 2], 14), LROT(eee,10);
		bbb, ddd = HHH(bbb, ccc, ddd, eee, aaa, X[10], 13), LROT(ddd,10);
		aaa, ccc = HHH(aaa, bbb, ccc, ddd, eee, X[ 0], 13), LROT(ccc,10);
		eee, bbb = HHH(eee, aaa, bbb, ccc, ddd, X[ 4],  7), LROT(bbb,10);
		ddd, aaa = HHH(ddd, eee, aaa, bbb, ccc, X[13],  5), LROT(aaa,10);

		ccc, eee = GGG(ccc, ddd, eee, aaa, bbb, X[ 8], 15), LROT(eee,10);
		bbb, ddd = GGG(bbb, ccc, ddd, eee, aaa, X[ 6],  5), LROT(ddd,10);
		aaa, ccc = GGG(aaa, bbb, ccc, ddd, eee, X[ 4],  8), LROT(ccc,10);
		eee, bbb = GGG(eee, aaa, bbb, ccc, ddd, X[ 1], 11), LROT(bbb,10);
		ddd, aaa = GGG(ddd, eee, aaa, bbb, ccc, X[ 3], 14), LROT(aaa,10);
		ccc, eee = GGG(ccc, ddd, eee, aaa, bbb, X[11], 14), LROT(eee,10);
		bbb, ddd = GGG(bbb, ccc, ddd, eee, aaa, X[15],  6), LROT(ddd,10);
		aaa, ccc = GGG(aaa, bbb, ccc, ddd, eee, X[ 0], 14), LROT(ccc,10);
		eee, bbb = GGG(eee, aaa, bbb, ccc, ddd, X[ 5],  6), LROT(bbb,10);
		ddd, aaa = GGG(ddd, eee, aaa, bbb, ccc, X[12],  9), LROT(aaa,10);
		ccc, eee = GGG(ccc, ddd, eee, aaa, bbb, X[ 2], 12), LROT(eee,10);
		bbb, ddd = GGG(bbb, ccc, ddd, eee, aaa, X[13],  9), LROT(ddd,10);
		aaa, ccc = GGG(aaa, bbb, ccc, ddd, eee, X[ 9], 12), LROT(ccc,10);
		eee, bbb = GGG(eee, aaa, bbb, ccc, ddd, X[ 7],  5), LROT(bbb,10);
		ddd, aaa = GGG(ddd, eee, aaa, bbb, ccc, X[10], 15), LROT(aaa,10);
		ccc, eee = GGG(ccc, ddd, eee, aaa, bbb, X[14],  8), LROT(eee,10);

		bbb, ddd = FFF(bbb, ccc, ddd, eee, aaa, X[12] ,  8), LROT(ddd,10);
		aaa, ccc = FFF(aaa, bbb, ccc, ddd, eee, X[15] ,  5), LROT(ccc,10);
		eee, bbb = FFF(eee, aaa, bbb, ccc, ddd, X[10] , 12), LROT(bbb,10);
		ddd, aaa = FFF(ddd, eee, aaa, bbb, ccc, X[ 4] ,  9), LROT(aaa,10);
		ccc, eee = FFF(ccc, ddd, eee, aaa, bbb, X[ 1] , 12), LROT(eee,10);
		bbb, ddd = FFF(bbb, ccc, ddd, eee, aaa, X[ 5] ,  5), LROT(ddd,10);
		aaa, ccc = FFF(aaa, bbb, ccc, ddd, eee, X[ 8] , 14), LROT(ccc,10);
		eee, bbb = FFF(eee, aaa, bbb, ccc, ddd, X[ 7] ,  6), LROT(bbb,10);
		ddd, aaa = FFF(ddd, eee, aaa, bbb, ccc, X[ 6] ,  8), LROT(aaa,10);
		ccc, eee = FFF(ccc, ddd, eee, aaa, bbb, X[ 2] , 13), LROT(eee,10);
		bbb, ddd = FFF(bbb, ccc, ddd, eee, aaa, X[13] ,  6), LROT(ddd,10);
		aaa, ccc = FFF(aaa, bbb, ccc, ddd, eee, X[14] ,  5), LROT(ccc,10);
		eee, bbb = FFF(eee, aaa, bbb, ccc, ddd, X[ 0] , 15), LROT(bbb,10);
		ddd, aaa = FFF(ddd, eee, aaa, bbb, ccc, X[ 3] , 13), LROT(aaa,10);
		ccc, eee = FFF(ccc, ddd, eee, aaa, bbb, X[ 9] , 11), LROT(eee,10);
		bbb, ddd = FFF(bbb, ccc, ddd, eee, aaa, X[11] , 11), LROT(ddd,10);

		A, B, C, D, E = AND(B + cc + ddd, 0xFFFFFFFF),
						AND(C + dd + eee, 0xFFFFFFFF),
						AND(D + ee + aaa, 0xFFFFFFFF),
						AND(E + aa + bbb, 0xFFFFFFFF),
						AND(A + bb + ccc, 0xFFFFFFFF);

	end

	public.init = function()
		queue.reset();

		A = 0x67452301;
		B = 0xefcdab89;
		C = 0x98badcfe;
		D = 0x10325476;
		E = 0xc3d2e1f0;

		return public;
	end

	public.update = function(bytes)
		for b in bytes do
			queue.push(b);
			if(queue.size() >= 64) then processBlock(); end
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
		local  b0, b1, b2, b3 = word2bytes(A);
		local  b4, b5, b6, b7 = word2bytes(B);
		local  b8, b9,b10,b11 = word2bytes(C);
		local b12,b13,b14,b15 = word2bytes(D);
		local b16,b17,b18,b19 = word2bytes(E);

		return { b0, b1, b2, b3, b4, b5, b6, b7, b8, b9,
				b10,b11,b12,b13,b14,b15,b16,b17,b18,b19};
	end

	public.asHex = function()
		local  b0, b1, b2, b3 = word2bytes(A);
		local  b4, b5, b6, b7 = word2bytes(B);
		local  b8, b9,b10,b11 = word2bytes(C);
		local b12,b13,b14,b15 = word2bytes(D);
		local b16,b17,b18,b19 = word2bytes(E);

		local fmt = "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x";

		return String.format(fmt,
				 b0, b1, b2, b3, b4, b5, b6, b7, b8, b9,
				b10,b11,b12,b13,b14,b15,b16,b17,b18,b19);
	end

	return public;

end

return RIPEMD160;

]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.digest.ripemd128"],"module already exists")sources["lockbox.digest.ripemd128"]=([===[-- <pack lockbox.digest.ripemd128> --
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

--RIPEMD128 is little-endian
local bytes2word = function(b0,b1,b2,b3)
	local i = b3; i = LSHIFT(i,8);
	i = OR(i,b2); i = LSHIFT(i,8);
	i = OR(i,b1); i = LSHIFT(i,8);
	i = OR(i,b0);
	return i;
end

local word2bytes = function(word)
	local b0,b1,b2,b3;
	b0 = AND(word,0xFF); word = RSHIFT(word,8);
	b1 = AND(word,0xFF); word = RSHIFT(word,8);
	b2 = AND(word,0xFF); word = RSHIFT(word,8);
	b3 = AND(word,0xFF);
	return b0,b1,b2,b3;
end

local bytes2dword = function(b0,b1,b2,b3,b4,b5,b6,b7)
	local i = bytes2word(b0,b1,b2,b3);
	local j = bytes2word(b4,b5,b6,b7);
	return (j*0x100000000)+i;
end

local dword2bytes = function(i)
	local b4,b5,b6,b7 = word2bytes(Math.floor(i/0x100000000));
	local b0,b1,b2,b3 = word2bytes(i);
	return b0,b1,b2,b3,b4,b5,b6,b7;
end

local F = function(x,y,z) return XOR(x, XOR(y,z)); end
local G = function(x,y,z) return OR(AND(x,y), AND(NOT(x),z)); end
local H = function(x,y,z) return XOR(OR(x,NOT(y)),z); end
local I = function(x,y,z) return OR(AND(x,z),AND(y,NOT(z))); end

local FF = function(a,b,c,d,x,s)
	a = a + F(b,c,d) + x;
	a = LROT(a,s);
	a = AND(a, 0xFFFFFFFF);
	return a;
end

local GG = function(a,b,c,d,x,s)
	a = a + G(b,c,d) + x + 0x5a827999;
	a = LROT(a,s);
	a = AND(a, 0xFFFFFFFF);
	return a;
end

local HH = function(a,b,c,d,x,s)
	a = a + H(b,c,d) + x + 0x6ed9eba1;
	a = LROT(a,s);
	a = AND(a, 0xFFFFFFFF);
	return a;
end

local II = function(a,b,c,d,x,s)
	a = a + I(b,c,d) + x + 0x8f1bbcdc;
	a = LROT(a,s);
	a = AND(a, 0xFFFFFFFF);
	return a;
end


local FFF = function(a,b,c,d,x,s)
	a = a + F(b,c,d) + x;
	a = LROT(a,s);
	a = AND(a, 0xFFFFFFFF);
	return a;
end

local GGG = function(a,b,c,d,x,s)
	a = a + G(b,c,d) + x + 0x6d703ef3;
	a = LROT(a,s);
	a = AND(a, 0xFFFFFFFF);
	return a;
end

local HHH = function(a,b,c,d,x,s)
	a = a + H(b,c,d) + x + 0x5c4dd124;
	a = LROT(a,s);
	a = AND(a, 0xFFFFFFFF);
	return a;
end

local III = function(a,b,c,d,x,s)
	a = a + I(b,c,d) + x + 0x50a28be6;
	a = LROT(a,s);
	a = AND(a, 0xFFFFFFFF);
	return a;
end

local RIPEMD128 = function()

	local queue = Queue();

	local A = 0x67452301;
	local B = 0xefcdab89;
	local C = 0x98badcfe;
	local D = 0x10325476;

	local public = {};

	local processBlock = function()
		local aa,bb,cc,dd = A,B,C,D;
		local aaa,bbb,ccc,ddd = A,B,C,D;

		local X = {};

		for i=0,15 do
			X[i] = bytes2word(queue.pop(),queue.pop(),queue.pop(),queue.pop());
		end

		aa = FF(aa, bb, cc, dd, X[ 0], 11);
		dd = FF(dd, aa, bb, cc, X[ 1], 14);
		cc = FF(cc, dd, aa, bb, X[ 2], 15);
		bb = FF(bb, cc, dd, aa, X[ 3], 12);
		aa = FF(aa, bb, cc, dd, X[ 4],  5);
		dd = FF(dd, aa, bb, cc, X[ 5],  8);
		cc = FF(cc, dd, aa, bb, X[ 6],  7);
		bb = FF(bb, cc, dd, aa, X[ 7],  9);
		aa = FF(aa, bb, cc, dd, X[ 8], 11);
		dd = FF(dd, aa, bb, cc, X[ 9], 13);
		cc = FF(cc, dd, aa, bb, X[10], 14);
		bb = FF(bb, cc, dd, aa, X[11], 15);
		aa = FF(aa, bb, cc, dd, X[12],  6);
		dd = FF(dd, aa, bb, cc, X[13],  7);
		cc = FF(cc, dd, aa, bb, X[14],  9);
		bb = FF(bb, cc, dd, aa, X[15],  8);

		aa = GG(aa, bb, cc, dd, X[ 7],  7);
		dd = GG(dd, aa, bb, cc, X[ 4],  6);
		cc = GG(cc, dd, aa, bb, X[13],  8);
		bb = GG(bb, cc, dd, aa, X[ 1], 13);
		aa = GG(aa, bb, cc, dd, X[10], 11);
		dd = GG(dd, aa, bb, cc, X[ 6],  9);
		cc = GG(cc, dd, aa, bb, X[15],  7);
		bb = GG(bb, cc, dd, aa, X[ 3], 15);
		aa = GG(aa, bb, cc, dd, X[12],  7);
		dd = GG(dd, aa, bb, cc, X[ 0], 12);
		cc = GG(cc, dd, aa, bb, X[ 9], 15);
		bb = GG(bb, cc, dd, aa, X[ 5],  9);
		aa = GG(aa, bb, cc, dd, X[ 2], 11);
		dd = GG(dd, aa, bb, cc, X[14],  7);
		cc = GG(cc, dd, aa, bb, X[11], 13);
		bb = GG(bb, cc, dd, aa, X[ 8], 12);

		aa = HH(aa, bb, cc, dd, X[ 3], 11);
		dd = HH(dd, aa, bb, cc, X[10], 13);
		cc = HH(cc, dd, aa, bb, X[14],  6);
		bb = HH(bb, cc, dd, aa, X[ 4],  7);
		aa = HH(aa, bb, cc, dd, X[ 9], 14);
		dd = HH(dd, aa, bb, cc, X[15],  9);
		cc = HH(cc, dd, aa, bb, X[ 8], 13);
		bb = HH(bb, cc, dd, aa, X[ 1], 15);
		aa = HH(aa, bb, cc, dd, X[ 2], 14);
		dd = HH(dd, aa, bb, cc, X[ 7],  8);
		cc = HH(cc, dd, aa, bb, X[ 0], 13);
		bb = HH(bb, cc, dd, aa, X[ 6],  6);
		aa = HH(aa, bb, cc, dd, X[13],  5);
		dd = HH(dd, aa, bb, cc, X[11], 12);
		cc = HH(cc, dd, aa, bb, X[ 5],  7);
		bb = HH(bb, cc, dd, aa, X[12],  5);

		aa = II(aa, bb, cc, dd, X[ 1], 11);
		dd = II(dd, aa, bb, cc, X[ 9], 12);
		cc = II(cc, dd, aa, bb, X[11], 14);
		bb = II(bb, cc, dd, aa, X[10], 15);
		aa = II(aa, bb, cc, dd, X[ 0], 14);
		dd = II(dd, aa, bb, cc, X[ 8], 15);
		cc = II(cc, dd, aa, bb, X[12],  9);
		bb = II(bb, cc, dd, aa, X[ 4],  8);
		aa = II(aa, bb, cc, dd, X[13],  9);
		dd = II(dd, aa, bb, cc, X[ 3], 14);
		cc = II(cc, dd, aa, bb, X[ 7],  5);
		bb = II(bb, cc, dd, aa, X[15],  6);
		aa = II(aa, bb, cc, dd, X[14],  8);
		dd = II(dd, aa, bb, cc, X[ 5],  6);
		cc = II(cc, dd, aa, bb, X[ 6],  5);
		bb = II(bb, cc, dd, aa, X[ 2], 12);

		aaa = III(aaa, bbb, ccc, ddd, X[ 5],  8);
		ddd = III(ddd, aaa, bbb, ccc, X[14],  9);
		ccc = III(ccc, ddd, aaa, bbb, X[ 7],  9);
		bbb = III(bbb, ccc, ddd, aaa, X[ 0], 11);
		aaa = III(aaa, bbb, ccc, ddd, X[ 9], 13);
		ddd = III(ddd, aaa, bbb, ccc, X[ 2], 15);
		ccc = III(ccc, ddd, aaa, bbb, X[11], 15);
		bbb = III(bbb, ccc, ddd, aaa, X[ 4],  5);
		aaa = III(aaa, bbb, ccc, ddd, X[13],  7);
		ddd = III(ddd, aaa, bbb, ccc, X[ 6],  7);
		ccc = III(ccc, ddd, aaa, bbb, X[15],  8);
		bbb = III(bbb, ccc, ddd, aaa, X[ 8], 11);
		aaa = III(aaa, bbb, ccc, ddd, X[ 1], 14);
		ddd = III(ddd, aaa, bbb, ccc, X[10], 14);
		ccc = III(ccc, ddd, aaa, bbb, X[ 3], 12);
		bbb = III(bbb, ccc, ddd, aaa, X[12],  6);

		aaa = HHH(aaa, bbb, ccc, ddd, X[ 6],  9);
		ddd = HHH(ddd, aaa, bbb, ccc, X[11], 13);
		ccc = HHH(ccc, ddd, aaa, bbb, X[ 3], 15);
		bbb = HHH(bbb, ccc, ddd, aaa, X[ 7],  7);
		aaa = HHH(aaa, bbb, ccc, ddd, X[ 0], 12);
		ddd = HHH(ddd, aaa, bbb, ccc, X[13],  8);
		ccc = HHH(ccc, ddd, aaa, bbb, X[ 5],  9);
		bbb = HHH(bbb, ccc, ddd, aaa, X[10], 11);
		aaa = HHH(aaa, bbb, ccc, ddd, X[14],  7);
		ddd = HHH(ddd, aaa, bbb, ccc, X[15],  7);
		ccc = HHH(ccc, ddd, aaa, bbb, X[ 8], 12);
		bbb = HHH(bbb, ccc, ddd, aaa, X[12],  7);
		aaa = HHH(aaa, bbb, ccc, ddd, X[ 4],  6);
		ddd = HHH(ddd, aaa, bbb, ccc, X[ 9], 15);
		ccc = HHH(ccc, ddd, aaa, bbb, X[ 1], 13);
		bbb = HHH(bbb, ccc, ddd, aaa, X[ 2], 11);

		aaa = GGG(aaa, bbb, ccc, ddd, X[15],  9);
		ddd = GGG(ddd, aaa, bbb, ccc, X[ 5],  7);
		ccc = GGG(ccc, ddd, aaa, bbb, X[ 1], 15);
		bbb = GGG(bbb, ccc, ddd, aaa, X[ 3], 11);
		aaa = GGG(aaa, bbb, ccc, ddd, X[ 7],  8);
		ddd = GGG(ddd, aaa, bbb, ccc, X[14],  6);
		ccc = GGG(ccc, ddd, aaa, bbb, X[ 6],  6);
		bbb = GGG(bbb, ccc, ddd, aaa, X[ 9], 14);
		aaa = GGG(aaa, bbb, ccc, ddd, X[11], 12);
		ddd = GGG(ddd, aaa, bbb, ccc, X[ 8], 13);
		ccc = GGG(ccc, ddd, aaa, bbb, X[12],  5);
		bbb = GGG(bbb, ccc, ddd, aaa, X[ 2], 14);
		aaa = GGG(aaa, bbb, ccc, ddd, X[10], 13);
		ddd = GGG(ddd, aaa, bbb, ccc, X[ 0], 13);
		ccc = GGG(ccc, ddd, aaa, bbb, X[ 4],  7);
		bbb = GGG(bbb, ccc, ddd, aaa, X[13],  5);

		aaa = FFF(aaa, bbb, ccc, ddd, X[ 8], 15);
		ddd = FFF(ddd, aaa, bbb, ccc, X[ 6],  5);
		ccc = FFF(ccc, ddd, aaa, bbb, X[ 4],  8);
		bbb = FFF(bbb, ccc, ddd, aaa, X[ 1], 11);
		aaa = FFF(aaa, bbb, ccc, ddd, X[ 3], 14);
		ddd = FFF(ddd, aaa, bbb, ccc, X[11], 14);
		ccc = FFF(ccc, ddd, aaa, bbb, X[15],  6);
		bbb = FFF(bbb, ccc, ddd, aaa, X[ 0], 14);
		aaa = FFF(aaa, bbb, ccc, ddd, X[ 5],  6);
		ddd = FFF(ddd, aaa, bbb, ccc, X[12],  9);
		ccc = FFF(ccc, ddd, aaa, bbb, X[ 2], 12);
		bbb = FFF(bbb, ccc, ddd, aaa, X[13],  9);
		aaa = FFF(aaa, bbb, ccc, ddd, X[ 9], 12);
		ddd = FFF(ddd, aaa, bbb, ccc, X[ 7],  5);
		ccc = FFF(ccc, ddd, aaa, bbb, X[10], 15);
		bbb = FFF(bbb, ccc, ddd, aaa, X[14],  8);


		A, B, C, D = AND(B + cc + ddd, 0xFFFFFFFF),
					 AND(C + dd + aaa, 0xFFFFFFFF),
					 AND(D + aa + bbb, 0xFFFFFFFF),
					 AND(A + bb + ccc, 0xFFFFFFFF);

	end

	public.init = function()
		queue.reset();

		A = 0x67452301;
		B = 0xefcdab89;
		C = 0x98badcfe;
		D = 0x10325476;

		return public;
	end


	public.update = function(bytes)
		for b in bytes do
			queue.push(b);
			if(queue.size() >= 64) then processBlock(); end
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
		local  b0, b1, b2, b3 = word2bytes(A);
		local  b4, b5, b6, b7 = word2bytes(B);
		local  b8, b9,b10,b11 = word2bytes(C);
		local b12,b13,b14,b15 = word2bytes(D);

		return { b0, b1, b2, b3, b4, b5, b6, b7, b8, b9,
				b10,b11,b12,b13,b14,b15};
	end

	public.asHex = function()
		local  b0, b1, b2, b3 = word2bytes(A);
		local  b4, b5, b6, b7 = word2bytes(B);
		local  b8, b9,b10,b11 = word2bytes(C);
		local b12,b13,b14,b15 = word2bytes(D);

		local fmt = "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x";

		return String.format(fmt,
				 b0, b1, b2, b3, b4, b5, b6, b7, b8, b9,
				b10,b11,b12,b13,b14,b15);
	end

	return public;

end

return RIPEMD128;

]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.digest.md5"],"module already exists")sources["lockbox.digest.md5"]=([===[-- <pack lockbox.digest.md5> --
require("lockbox").insecure();

local Bit = require("lockbox.util.bit");
local String = require("string");
local Math = require("math");
local Queue = require("lockbox.util.queue");

local SHIFT = {	7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,
				5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,
				4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,
				6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21 };

local CONSTANTS = {	0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
					0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
					0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
					0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
					0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
					0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
					0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
					0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
					0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
					0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
					0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
					0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
					0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
					0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
					0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
					0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391};

local AND = Bit.band;
local OR  = Bit.bor;
local NOT = Bit.bnot;
local XOR = Bit.bxor;
local LROT = Bit.lrotate;
local RROT = Bit.rrotate;
local LSHIFT = Bit.lshift;
local RSHIFT = Bit.rshift;

--MD5 is little-endian
local bytes2word = function(b0,b1,b2,b3)
	local i = b3; i = LSHIFT(i,8);
	i = OR(i,b2); i = LSHIFT(i,8);
	i = OR(i,b1); i = LSHIFT(i,8);
	i = OR(i,b0);
	return i;
end

local word2bytes = function(word)
	local b0,b1,b2,b3;
	b0 = AND(word,0xFF); word = RSHIFT(word,8);
	b1 = AND(word,0xFF); word = RSHIFT(word,8);
	b2 = AND(word,0xFF); word = RSHIFT(word,8);
	b3 = AND(word,0xFF);
	return b0,b1,b2,b3;
end

local bytes2dword = function(b0,b1,b2,b3,b4,b5,b6,b7)
	local i = bytes2word(b0,b1,b2,b3);
	local j = bytes2word(b4,b5,b6,b7);
	return (j*0x100000000)+i;
end

local dword2bytes = function(i)
	local b4,b5,b6,b7 = word2bytes(Math.floor(i/0x100000000));
	local b0,b1,b2,b3 = word2bytes(i);
	return b0,b1,b2,b3,b4,b5,b6,b7;
end

local F = function(x,y,z) return OR(AND(x,y),AND(NOT(x),z)); end
local G = function(x,y,z) return OR(AND(x,z),AND(y,NOT(z))); end
local H = function(x,y,z) return XOR(x,XOR(y,z)); end
local I = function(x,y,z) return XOR(y,OR(x,NOT(z))); end

local MD5 = function()

	local queue = Queue();

	local A = 0x67452301;
	local B = 0xefcdab89;
	local C = 0x98badcfe;
	local D = 0x10325476;
	local public = {};

	local processBlock = function()
		local a = A;
		local b = B;
		local c = C;
		local d = D;

		local X = {};

		for i=1,16 do
			X[i] = bytes2word(queue.pop(),queue.pop(),queue.pop(),queue.pop());
		end

		for i=0,63 do
			local f,g,temp;

			if (0 <= i) and (i <= 15) then
				f = F(b,c,d);
				g = i;
			elseif (16 <= i) and (i <= 31) then
				f = G(b,c,d);
				g = (5*i + 1) % 16;
			elseif (32 <= i) and (i <= 47) then
				f = H(b,c,d);
				g = (3*i + 5) % 16;
			elseif (48 <= i) and (i <= 63) then
				f = I(b,c,d);
				g = (7*i) % 16;
			end
			temp = d;
			d = c;
			c = b;
			b = b + LROT((a + f + CONSTANTS[i+1] + X[g+1]), SHIFT[i+1]);
			a = temp;
		end

		A = AND(A + a, 0xFFFFFFFF);
		B = AND(B + b, 0xFFFFFFFF);
		C = AND(C + c, 0xFFFFFFFF);
		D = AND(D + d, 0xFFFFFFFF);
	end

	public.init = function()
		queue.reset();

		A = 0x67452301;
		B = 0xefcdab89;
		C = 0x98badcfe;
		D = 0x10325476;

		return public;
	end

	public.update = function(bytes)
		for b in bytes do
			queue.push(b);
			if(queue.size() >= 64) then processBlock(); end
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
		local  b0, b1, b2, b3 = word2bytes(A);
		local  b4, b5, b6, b7 = word2bytes(B);
		local  b8, b9,b10,b11 = word2bytes(C);
		local b12,b13,b14,b15 = word2bytes(D);

		return {b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15};
	end

	public.asHex = function()
		local  b0, b1, b2, b3 = word2bytes(A);
		local  b4, b5, b6, b7 = word2bytes(B);
		local  b8, b9,b10,b11 = word2bytes(C);
		local b12,b13,b14,b15 = word2bytes(D);

		return String.format("%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
				b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15);
	end

	return public;

end

return MD5;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.digest.md4"],"module already exists")sources["lockbox.digest.md4"]=([===[-- <pack lockbox.digest.md4> --
require("lockbox").insecure();

local Bit = require("lockbox.util.bit");
local String = require("string");
local Math = require("math");
local Queue = require("lockbox.util.queue");

local SHIFT = {	3,  7, 11, 19,  3,  7, 11, 19,  3,  7, 11, 19,  3,  7, 11, 19,
				3,  5,  9, 13,  3,  5,  9, 13,  3,  5,  9, 13,  3,  5,  9, 13,
				3,  9, 11, 15,  3,  9, 11, 15,  3,  9, 11, 15,  3,  9, 11, 15 };

local WORD = {	0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15,
				0,  4,  8, 12,  1,  5,  9, 13,  2,  6, 10, 14,  3,  7, 11, 13,
				3,  8,  4, 12,  2, 10,  6, 14,  1,  9,  5, 13,  3,  1,  7, 15 };

local AND = Bit.band;
local OR  = Bit.bor;
local NOT = Bit.bnot;
local XOR = Bit.bxor;
local LROT = Bit.lrotate;
local RROT = Bit.rrotate;
local LSHIFT = Bit.lshift;
local RSHIFT = Bit.rshift;

--MD4 is little-endian
local bytes2word = function(b0,b1,b2,b3)
	local i = b3; i = LSHIFT(i,8);
	i = OR(i,b2); i = LSHIFT(i,8);
	i = OR(i,b1); i = LSHIFT(i,8);
	i = OR(i,b0);
	return i;
end

local word2bytes = function(word)
	local b0,b1,b2,b3;
	b0 = AND(word,0xFF); word = RSHIFT(word,8);
	b1 = AND(word,0xFF); word = RSHIFT(word,8);
	b2 = AND(word,0xFF); word = RSHIFT(word,8);
	b3 = AND(word,0xFF);
	return b0,b1,b2,b3;
end

local bytes2dword = function(b0,b1,b2,b3,b4,b5,b6,b7)
	local i = bytes2word(b0,b1,b2,b3);
	local j = bytes2word(b4,b5,b6,b7);
	return (j*0x100000000)+i;
end

local dword2bytes = function(i)
	local b4,b5,b6,b7 = word2bytes(Math.floor(i/0x100000000));
	local b0,b1,b2,b3 = word2bytes(i);
	return b0,b1,b2,b3,b4,b5,b6,b7;
end

local F = function(x,y,z) return OR(AND(x,y),AND(NOT(x),z)); end
local G = function(x,y,z) return OR(AND(x,y), OR(AND(x,z), AND(y,z))); end
local H = function(x,y,z) return XOR(x,XOR(y,z)); end


local MD4 = function()

	local queue = Queue();

	local A = 0x67452301;
	local B = 0xefcdab89;
	local C = 0x98badcfe;
	local D = 0x10325476;
	local public = {};

	local processBlock = function()
		local a = A;
		local b = B;
		local c = C;
		local d = D;

		local X = {};

		for i=0,15 do
			X[i] = bytes2word(queue.pop(),queue.pop(),queue.pop(),queue.pop());
		end

		a = LROT(a + F(b,c,d) + X[ 0], 3);
		d = LROT(d + F(a,b,c) + X[ 1], 7);
		c = LROT(c + F(d,a,b) + X[ 2],11);
		b = LROT(b + F(c,d,a) + X[ 3],19);

		a = LROT(a + F(b,c,d) + X[ 4], 3);
		d = LROT(d + F(a,b,c) + X[ 5], 7);
		c = LROT(c + F(d,a,b) + X[ 6],11);
		b = LROT(b + F(c,d,a) + X[ 7],19);

		a = LROT(a + F(b,c,d) + X[ 8], 3);
		d = LROT(d + F(a,b,c) + X[ 9], 7);
		c = LROT(c + F(d,a,b) + X[10],11);
		b = LROT(b + F(c,d,a) + X[11],19);

		a = LROT(a + F(b,c,d) + X[12], 3);
		d = LROT(d + F(a,b,c) + X[13], 7);
		c = LROT(c + F(d,a,b) + X[14],11);
		b = LROT(b + F(c,d,a) + X[15],19);


		a = LROT(a + G(b,c,d) + X[ 0] + 0x5A827999, 3);
		d = LROT(d + G(a,b,c) + X[ 4] + 0x5A827999, 5);
		c = LROT(c + G(d,a,b) + X[ 8] + 0x5A827999, 9);
		b = LROT(b + G(c,d,a) + X[12] + 0x5A827999,13);

		a = LROT(a + G(b,c,d) + X[ 1] + 0x5A827999, 3);
		d = LROT(d + G(a,b,c) + X[ 5] + 0x5A827999, 5);
		c = LROT(c + G(d,a,b) + X[ 9] + 0x5A827999, 9);
		b = LROT(b + G(c,d,a) + X[13] + 0x5A827999,13);

		a = LROT(a + G(b,c,d) + X[ 2] + 0x5A827999, 3);
		d = LROT(d + G(a,b,c) + X[ 6] + 0x5A827999, 5);
		c = LROT(c + G(d,a,b) + X[10] + 0x5A827999, 9);
		b = LROT(b + G(c,d,a) + X[14] + 0x5A827999,13);

		a = LROT(a + G(b,c,d) + X[ 3] + 0x5A827999, 3);
		d = LROT(d + G(a,b,c) + X[ 7] + 0x5A827999, 5);
		c = LROT(c + G(d,a,b) + X[11] + 0x5A827999, 9);
		b = LROT(b + G(c,d,a) + X[15] + 0x5A827999,13);


		a = LROT(a + H(b,c,d) + X[ 0] + 0x6ED9EBA1, 3);
		d = LROT(d + H(a,b,c) + X[ 8] + 0x6ED9EBA1, 9);
		c = LROT(c + H(d,a,b) + X[ 4] + 0x6ED9EBA1,11);
		b = LROT(b + H(c,d,a) + X[12] + 0x6ED9EBA1,15);

		a = LROT(a + H(b,c,d) + X[ 2] + 0x6ED9EBA1, 3);
		d = LROT(d + H(a,b,c) + X[10] + 0x6ED9EBA1, 9);
		c = LROT(c + H(d,a,b) + X[ 6] + 0x6ED9EBA1,11);
		b = LROT(b + H(c,d,a) + X[14] + 0x6ED9EBA1,15);

		a = LROT(a + H(b,c,d) + X[ 1] + 0x6ED9EBA1, 3);
		d = LROT(d + H(a,b,c) + X[ 9] + 0x6ED9EBA1, 9);
		c = LROT(c + H(d,a,b) + X[ 5] + 0x6ED9EBA1,11);
		b = LROT(b + H(c,d,a) + X[13] + 0x6ED9EBA1,15);

		a = LROT(a + H(b,c,d) + X[ 3] + 0x6ED9EBA1, 3);
		d = LROT(d + H(a,b,c) + X[11] + 0x6ED9EBA1, 9);
		c = LROT(c + H(d,a,b) + X[ 7] + 0x6ED9EBA1,11);
		b = LROT(b + H(c,d,a) + X[15] + 0x6ED9EBA1,15);


		A = AND(A + a, 0xFFFFFFFF);
		B = AND(B + b, 0xFFFFFFFF);
		C = AND(C + c, 0xFFFFFFFF);
		D = AND(D + d, 0xFFFFFFFF);
	end

	public.init = function()
		queue.reset();

		A = 0x67452301;
		B = 0xefcdab89;
		C = 0x98badcfe;
		D = 0x10325476;

		return public;
	end

	public.update = function(bytes)
		for b in bytes do
			queue.push(b);
			if(queue.size() >= 64) then processBlock(); end
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
		local  b0, b1, b2, b3 = word2bytes(A);
		local  b4, b5, b6, b7 = word2bytes(B);
		local  b8, b9,b10,b11 = word2bytes(C);
		local b12,b13,b14,b15 = word2bytes(D);

		return {b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15};
	end

	public.asHex = function()
		local  b0, b1, b2, b3 = word2bytes(A);
		local  b4, b5, b6, b7 = word2bytes(B);
		local  b8, b9,b10,b11 = word2bytes(C);
		local b12,b13,b14,b15 = word2bytes(D);

		return String.format("%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
				b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15);
	end

	return public;

end

return MD4;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.digest.md2"],"module already exists")sources["lockbox.digest.md2"]=([===[-- <pack lockbox.digest.md2> --
require("lockbox").insecure();

local Bit = require("lockbox.util.bit");
local String = require("string");
local Queue = require("lockbox.util.queue");

local SUBST = {
  0x29, 0x2E, 0x43, 0xC9, 0xA2, 0xD8, 0x7C, 0x01, 0x3D, 0x36, 0x54, 0xA1, 0xEC, 0xF0, 0x06, 0x13,
  0x62, 0xA7, 0x05, 0xF3, 0xC0, 0xC7, 0x73, 0x8C, 0x98, 0x93, 0x2B, 0xD9, 0xBC, 0x4C, 0x82, 0xCA,
  0x1E, 0x9B, 0x57, 0x3C, 0xFD, 0xD4, 0xE0, 0x16, 0x67, 0x42, 0x6F, 0x18, 0x8A, 0x17, 0xE5, 0x12,
  0xBE, 0x4E, 0xC4, 0xD6, 0xDA, 0x9E, 0xDE, 0x49, 0xA0, 0xFB, 0xF5, 0x8E, 0xBB, 0x2F, 0xEE, 0x7A,
  0xA9, 0x68, 0x79, 0x91, 0x15, 0xB2, 0x07, 0x3F, 0x94, 0xC2, 0x10, 0x89, 0x0B, 0x22, 0x5F, 0x21,
  0x80, 0x7F, 0x5D, 0x9A, 0x5A, 0x90, 0x32, 0x27, 0x35, 0x3E, 0xCC, 0xE7, 0xBF, 0xF7, 0x97, 0x03,
  0xFF, 0x19, 0x30, 0xB3, 0x48, 0xA5, 0xB5, 0xD1, 0xD7, 0x5E, 0x92, 0x2A, 0xAC, 0x56, 0xAA, 0xC6,
  0x4F, 0xB8, 0x38, 0xD2, 0x96, 0xA4, 0x7D, 0xB6, 0x76, 0xFC, 0x6B, 0xE2, 0x9C, 0x74, 0x04, 0xF1,
  0x45, 0x9D, 0x70, 0x59, 0x64, 0x71, 0x87, 0x20, 0x86, 0x5B, 0xCF, 0x65, 0xE6, 0x2D, 0xA8, 0x02,
  0x1B, 0x60, 0x25, 0xAD, 0xAE, 0xB0, 0xB9, 0xF6, 0x1C, 0x46, 0x61, 0x69, 0x34, 0x40, 0x7E, 0x0F,
  0x55, 0x47, 0xA3, 0x23, 0xDD, 0x51, 0xAF, 0x3A, 0xC3, 0x5C, 0xF9, 0xCE, 0xBA, 0xC5, 0xEA, 0x26,
  0x2C, 0x53, 0x0D, 0x6E, 0x85, 0x28, 0x84, 0x09, 0xD3, 0xDF, 0xCD, 0xF4, 0x41, 0x81, 0x4D, 0x52,
  0x6A, 0xDC, 0x37, 0xC8, 0x6C, 0xC1, 0xAB, 0xFA, 0x24, 0xE1, 0x7B, 0x08, 0x0C, 0xBD, 0xB1, 0x4A,
  0x78, 0x88, 0x95, 0x8B, 0xE3, 0x63, 0xE8, 0x6D, 0xE9, 0xCB, 0xD5, 0xFE, 0x3B, 0x00, 0x1D, 0x39,
  0xF2, 0xEF, 0xB7, 0x0E, 0x66, 0x58, 0xD0, 0xE4, 0xA6, 0x77, 0x72, 0xF8, 0xEB, 0x75, 0x4B, 0x0A,
  0x31, 0x44, 0x50, 0xB4, 0x8F, 0xED, 0x1F, 0x1A, 0xDB, 0x99, 0x8D, 0x33, 0x9F, 0x11, 0x83, 0x14 };

local AND = Bit.band;
local OR  = Bit.bor;
local NOT = Bit.bnot;
local XOR = Bit.bxor;
local LROT = Bit.lrotate;
local RROT = Bit.rrotate;
local LSHIFT = Bit.lshift;
local RSHIFT = Bit.rshift;

local MD2 = function()

	local queue = Queue();

	local X = {};
	for i=0,47 do
		X[i] = 0x00;
	end

	local L = 0;
	local C = {};
	for i=0,15 do
		C[i] = 0x00;
	end

	local public = {};

	local processBlock = function()
		local block = {};

		for i=0,15 do
			block[i] = queue.pop();
		end

		for i=0,15 do
			X[i+16] = block[i];
			X[i+32] = XOR(X[i],block[i]); --mix
		end

		local t;

		--update block
		t=0;
		for i=0,17 do
			for j=0,47 do
				X[j] = XOR(X[j],SUBST[t+1]);
				t = X[j];
			end
			t = (t+i) % 256;
		end

		--update checksum
		t = C[15];
		for i=0,15 do
			C[i] = XOR(C[i],SUBST[XOR(block[i],t)+1]);
			t = C[i];
		end

	end

	public.init = function()
		queue.reset();

		X = {};
		for i=0,47 do
			X[i] = 0x00;
		end

		L = 0;
		C = {};
		for i=0,15 do
			C[i] = 0x00;
		end

		return public;
	end

	public.update = function(stream)
		for b in stream do
			queue.push(b);
			if(queue.size() >= 16) then processBlock(); end
		end

		return public;
	end

	public.finish = function()
		local i = 16-queue.size();

		while queue.size() < 16 do
			queue.push(i);
		end

		processBlock();

		queue.push(C[ 0]); queue.push(C[ 1]); queue.push(C[ 2]); queue.push(C[ 3]);
		queue.push(C[ 4]); queue.push(C[ 5]); queue.push(C[ 6]); queue.push(C[ 7]);
		queue.push(C[ 8]); queue.push(C[ 9]); queue.push(C[10]); queue.push(C[11]);
		queue.push(C[12]); queue.push(C[13]); queue.push(C[14]); queue.push(C[15]);

		processBlock();

		return public;
	end

	public.asBytes = function()
		return {X[ 0],X[ 1],X[ 2],X[ 3],X[ 4],X[ 5],X[ 6],X[ 7],
				X[ 8],X[ 9],X[10],X[11],X[12],X[13],X[14],X[15]};
	end

	public.asHex = function()
		return String.format("%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
				X[ 0],X[ 1],X[ 2],X[ 3],X[ 4],X[ 5],X[ 6],X[ 7],
				X[ 8],X[ 9],X[10],X[11],X[12],X[13],X[14],X[15]);
	end

	return public;

end

return MD2;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.cipher.mode.pcbc"],"module already exists")sources["lockbox.cipher.mode.pcbc"]=([===[-- <pack lockbox.cipher.mode.pcbc> --
local Array = require("lockbox.util.array");
local Stream = require("lockbox.util.stream");
local Queue = require("lockbox.util.queue");

local String = require("string");
local Bit = require("lockbox.util.bit");

local PCBC = {};

PCBC.Cipher = function()

	local public = {};

	local key;
	local blockCipher;
	local padding;
	local inputQueue;
	local outputQueue;
	local iv;

	public.setKey = function(keyBytes)
		key = keyBytes;
		return public;
	end

	public.setBlockCipher = function(cipher)
		blockCipher = cipher;
		return public;
	end

	public.setPadding = function(paddingMode)
		padding = paddingMode;
		return public;
	end

	public.init = function()
		inputQueue = Queue();
		outputQueue = Queue();
		iv = nil;
		return public;
	end

	public.update = function(messageStream)
		local byte = messageStream();
		while (byte ~= nil) do
			inputQueue.push(byte);
			if(inputQueue.size() >= blockCipher.blockSize) then
				local block = Array.readFromQueue(inputQueue,blockCipher.blockSize);

				if(iv == nil) then
					iv = block;
				else
					local out = block;
					out = Array.XOR(iv,out);
					out = blockCipher.encrypt(key,out);
					iv = Array.XOR(out,block);
					Array.writeToQueue(outputQueue,out);
				end
			end
			byte = messageStream();
		end
		return public;
	end

	public.finish = function()
		paddingStream = padding(blockCipher.blockSize,inputQueue.getHead());
		public.update(paddingStream);

		return public;
	end

	public.getOutputQueue = function()
		return outputQueue;
	end

	public.asHex = function()
		return Stream.toHex(outputQueue.pop);
	end

	public.asBytes = function()
		return Stream.toArray(outputQueue.pop);
	end

	return public;

end

PCBC.Decipher = function()

	local public = {};

	local key;
	local blockCipher;
	local padding;
	local inputQueue;
	local outputQueue;
	local iv;

	public.setKey = function(keyBytes)
		key = keyBytes;
		return public;
	end

	public.setBlockCipher = function(cipher)
		blockCipher = cipher;
		return public;
	end

	public.setPadding = function(paddingMode)
		padding = paddingMode;
		return public;
	end

	public.init = function()
		inputQueue = Queue();
		outputQueue = Queue();
		iv = nil;
		return public;
	end

	public.update = function(messageStream)
		local byte = messageStream();
		while (byte ~= nil) do
			inputQueue.push(byte);
			if(inputQueue.size() >= blockCipher.blockSize) then
				local block = Array.readFromQueue(inputQueue,blockCipher.blockSize);

				if(iv == nil) then
					iv = block;
				else
					local out = block;
					out = blockCipher.decrypt(key,out);
					out = Array.XOR(iv,out);
					Array.writeToQueue(outputQueue,out);
					iv = Array.XOR(out,block);
				end
			end
			byte = messageStream();
		end
		return public;
	end

	public.finish = function()
		paddingStream = padding(blockCipher.blockSize,inputQueue.getHead());
		public.update(paddingStream);

		return public;
	end

	public.getOutputQueue = function()
		return outputQueue;
	end

	public.asHex = function()
		return Stream.toHex(outputQueue.pop);
	end

	public.asBytes = function()
		return Stream.toArray(outputQueue.pop);
	end

	return public;

end


return PCBC;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.cipher.mode.ofb"],"module already exists")sources["lockbox.cipher.mode.ofb"]=([===[-- <pack lockbox.cipher.mode.ofb> --
local Array = require("lockbox.util.array");
local Stream = require("lockbox.util.stream");
local Queue = require("lockbox.util.queue");

local String = require("string");
local Bit = require("lockbox.util.bit");

local OFB = {};

OFB.Cipher = function()

	local public = {};

	local key;
	local blockCipher;
	local padding;
	local inputQueue;
	local outputQueue;
	local iv;

	public.setKey = function(keyBytes)
		key = keyBytes;
		return public;
	end

	public.setBlockCipher = function(cipher)
		blockCipher = cipher;
		return public;
	end

	public.setPadding = function(paddingMode)
		padding = paddingMode;
		return public;
	end

	public.init = function()
		inputQueue = Queue();
		outputQueue = Queue();
		iv = nil;
		return public;
	end

	public.update = function(messageStream)
		local byte = messageStream();
		while (byte ~= nil) do
			inputQueue.push(byte);
			if(inputQueue.size() >= blockCipher.blockSize) then
				local block = Array.readFromQueue(inputQueue,blockCipher.blockSize);

				if(iv == nil) then
					iv = block;
				else
					local out = iv;
					out = blockCipher.encrypt(key,out);
					iv = out;
					out = Array.XOR(out,block);
					Array.writeToQueue(outputQueue,out);
				end
			end
			byte = messageStream();
		end
		return public;
	end

	public.finish = function()
		paddingStream = padding(blockCipher.blockSize,inputQueue.getHead());
		public.update(paddingStream);

		return public;
	end

	public.getOutputQueue = function()
		return outputQueue;
	end

	public.asHex = function()
		return Stream.toHex(outputQueue.pop);
	end

	public.asBytes = function()
		return Stream.toArray(outputQueue.pop);
	end

	return public;

end

OFB.Decipher = function()

	local public = {};

	local key;
	local blockCipher;
	local padding;
	local inputQueue;
	local outputQueue;
	local iv;

	public.setKey = function(keyBytes)
		key = keyBytes;
		return public;
	end

	public.setBlockCipher = function(cipher)
		blockCipher = cipher;
		return public;
	end

	public.setPadding = function(paddingMode)
		padding = paddingMode;
		return public;
	end

	public.init = function()
		inputQueue = Queue();
		outputQueue = Queue();
		iv = nil;
		return public;
	end

	public.update = function(messageStream)
		local byte = messageStream();
		while (byte ~= nil) do
			inputQueue.push(byte);
			if(inputQueue.size() >= blockCipher.blockSize) then
				local block = Array.readFromQueue(inputQueue,blockCipher.blockSize);

				if(iv == nil) then
					iv = block;
				else
					local out = iv;
					out = blockCipher.encrypt(key,out);
					iv = out;
					out = Array.XOR(out,block);
					Array.writeToQueue(outputQueue,out);
				end
			end
			byte = messageStream();
		end
		return public;
	end

	public.finish = function()
		paddingStream = padding(blockCipher.blockSize,inputQueue.getHead());
		public.update(paddingStream);

		return public;
	end

	public.getOutputQueue = function()
		return outputQueue;
	end

	public.asHex = function()
		return Stream.toHex(outputQueue.pop);
	end

	public.asBytes = function()
		return Stream.toArray(outputQueue.pop);
	end

	return public;

end


return OFB;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.cipher.mode.ige"],"module already exists")sources["lockbox.cipher.mode.ige"]=([===[-- <pack lockbox.cipher.mode.ige> --
local Array = require("lockbox.util.array");
local Stream = require("lockbox.util.stream");
local Queue = require("lockbox.util.queue");

local String = require("string");
local Bit = require("lockbox.util.bit");

local IGE = {};

IGE.Cipher = function()

	local public = {};

	local key;
	local blockCipher;
	local padding;
	local inputQueue;
	local outputQueue;
	local xPrev,yPrev;

	public.setKey = function(keyBytes)
		key = keyBytes;
		return public;
	end

	public.setBlockCipher = function(cipher)
		blockCipher = cipher;
		return public;
	end

	public.setPadding = function(paddingMode)
		padding = paddingMode;
		return public;
	end

	public.init = function()
		inputQueue = Queue();
		outputQueue = Queue();
		xPrev = nil;
		yPrev = nil;
		return public;
	end

	public.update = function(messageStream)
		local byte = messageStream();
		while (byte ~= nil) do
			inputQueue.push(byte);
			if(inputQueue.size() >= blockCipher.blockSize) then
				local block = Array.readFromQueue(inputQueue,blockCipher.blockSize);

				if(yPrev == nil) then
					yPrev = block;
				elseif(xPrev == nil) then
					xPrev = block
				else
					local out = Array.XOR(yPrev,block);
					out = blockCipher.encrypt(key,out);
					out = Array.XOR(out,xPrev);
					Array.writeToQueue(outputQueue,out);
					xPrev = block;
					yPrev = out;
				end
			end
			byte = messageStream();
		end
		return public;
	end

	public.finish = function()
		paddingStream = padding(blockCipher.blockSize,inputQueue.getHead());
		public.update(paddingStream);

		return public;
	end

	public.getOutputQueue = function()
		return outputQueue;
	end

	public.asHex = function()
		return Stream.toHex(outputQueue.pop);
	end

	public.asBytes = function()
		return Stream.toArray(outputQueue.pop);
	end

	return public;

end

IGE.Decipher = function()

	local public = {};

	local key;
	local blockCipher;
	local padding;
	local inputQueue;
	local outputQueue;
	local xPrev,yPrev;

	public.setKey = function(keyBytes)
		key = keyBytes;
		return public;
	end

	public.setBlockCipher = function(cipher)
		blockCipher = cipher;
		return public;
	end

	public.setPadding = function(paddingMode)
		padding = paddingMode;
		return public;
	end

	public.init = function()
		inputQueue = Queue();
		outputQueue = Queue();
		xPrev = nil;
		yPrev = nil;
		return public;
	end

	public.update = function(messageStream)
		local byte = messageStream();
		while (byte ~= nil) do
			inputQueue.push(byte);
			if(inputQueue.size() >= blockCipher.blockSize) then
				local block = Array.readFromQueue(inputQueue,blockCipher.blockSize);

				if(xPrev == nil) then
					xPrev = block;
				elseif(yPrev == nil) then
					yPrev = block
				else
					local out = Array.XOR(yPrev,block);
					out = blockCipher.decrypt(key,out);
					out = Array.XOR(out,xPrev);
					Array.writeToQueue(outputQueue,out);
					xPrev = block;
					yPrev = out;
				end
			end
			byte = messageStream();
		end
		return public;
	end

	public.finish = function()
		paddingStream = padding(blockCipher.blockSize,inputQueue.getHead());
		public.update(paddingStream);

		return public;
	end

	public.getOutputQueue = function()
		return outputQueue;
	end

	public.asHex = function()
		return Stream.toHex(outputQueue.pop);
	end

	public.asBytes = function()
		return Stream.toArray(outputQueue.pop);
	end

	return public;

end

return IGE;

]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.cipher.mode.ecb"],"module already exists")sources["lockbox.cipher.mode.ecb"]=([===[-- <pack lockbox.cipher.mode.ecb> --
require("lockbox").insecure();

local Array = require("lockbox.util.array");
local Stream = require("lockbox.util.stream");
local Queue = require("lockbox.util.queue");

local String = require("string");
local Bit = require("lockbox.util.bit");

local ECB = {};

ECB.Cipher = function()

	local public = {};

	local key;
	local blockCipher;
	local padding;
	local inputQueue;
	local outputQueue;

	public.setKey = function(keyBytes)
		key = keyBytes;
		return public;
	end

	public.setBlockCipher = function(cipher)
		blockCipher = cipher;
		return public;
	end

	public.setPadding = function(paddingMode)
		padding = paddingMode;
		return public;
	end

	public.init = function()
		inputQueue = Queue();
		outputQueue = Queue();
		return public;
	end

	public.update = function(messageStream)
		local byte = messageStream();
		while (byte ~= nil) do
			inputQueue.push(byte);
			if(inputQueue.size() >= blockCipher.blockSize) then
				local block = Array.readFromQueue(inputQueue,blockCipher.blockSize);

				block = blockCipher.encrypt(key,block);

				Array.writeToQueue(outputQueue,block);
			end
			byte = messageStream();
		end
		return public;
	end

	public.finish = function()
		paddingStream = padding(blockCipher.blockSize,inputQueue.getHead());
		public.update(paddingStream);

		return public;
	end

	public.getOutputQueue = function()
		return outputQueue;
	end

	public.asHex = function()
		return Stream.toHex(outputQueue.pop);
	end

	public.asBytes = function()
		return Stream.toArray(outputQueue.pop);
	end

	return public;

end

ECB.Decipher = function()

	local public = {};

	local key;
	local blockCipher;
	local padding;
	local inputQueue;
	local outputQueue;

	public.setKey = function(keyBytes)
		key = keyBytes;
		return public;
	end

	public.setBlockCipher = function(cipher)
		blockCipher = cipher;
		return public;
	end

	public.setPadding = function(paddingMode)
		padding = paddingMode;
		return public;
	end

	public.init = function()
		inputQueue = Queue();
		outputQueue = Queue();
		return public;
	end

	public.update = function(messageStream)
		local byte = messageStream();
		while (byte ~= nil) do
			inputQueue.push(byte);
			if(inputQueue.size() >= blockCipher.blockSize) then
				local block = Array.readFromQueue(inputQueue,blockCipher.blockSize);

				block = blockCipher.decrypt(key,block);

				Array.writeToQueue(outputQueue,block);
			end
			byte = messageStream();
		end
		return public;
	end

	public.finish = function()
		paddingStream = padding(blockCipher.blockSize,inputQueue.getHead());
		public.update(paddingStream);

		return public;
	end

	public.getOutputQueue = function()
		return outputQueue;
	end

	public.asHex = function()
		return Stream.toHex(outputQueue.pop);
	end

	public.asBytes = function()
		return Stream.toArray(outputQueue.pop);
	end

	return public;

end


return ECB;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.cipher.mode.ctr"],"module already exists")sources["lockbox.cipher.mode.ctr"]=([===[-- <pack lockbox.cipher.mode.ctr> --
local Array = require("lockbox.util.array");
local Stream = require("lockbox.util.stream");
local Queue = require("lockbox.util.queue");

local String = require("string");
local Bit = require("lockbox.util.bit");

local AND = Bit.band;
local OR  = Bit.bor;
local NOT = Bit.bnot;
local XOR = Bit.bxor;
local LROT = Bit.lrotate;
local RROT = Bit.rrotate;
local LSHIFT = Bit.lshift;
local RSHIFT = Bit.rshift;

--CTR counter is big-endian
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


local CTR = {};

CTR.Cipher = function()

	local public = {};

	local key;
	local blockCipher;
	local padding;
	local inputQueue;
	local outputQueue;
	local iv;

	public.setKey = function(keyBytes)
		key = keyBytes;
		return public;
	end

	public.setBlockCipher = function(cipher)
		blockCipher = cipher;
		return public;
	end

	public.setPadding = function(paddingMode)
		padding = paddingMode;
		return public;
	end

	public.init = function()
		inputQueue = Queue();
		outputQueue = Queue();
		iv = nil;
		return public;
	end

	local updateIV = function()
		iv[16] = iv[16] + 1;
		if iv[16] <= 0xFF then return; end
		iv[16] = AND(iv[16],0xFF);

		iv[15] = iv[15] + 1;
		if iv[15] <= 0xFF then return; end
		iv[15] = AND(iv[15],0xFF);

		iv[14] = iv[14] + 1;
		if iv[14] <= 0xFF then return; end
		iv[14] = AND(iv[14],0xFF);

		iv[13] = iv[13] + 1;
		if iv[13] <= 0xFF then return; end
		iv[13] = AND(iv[13],0xFF);

		iv[12] = iv[12] + 1;
		if iv[12] <= 0xFF then return; end
		iv[12] = AND(iv[12],0xFF);

		iv[11] = iv[11] + 1;
		if iv[11] <= 0xFF then return; end
		iv[11] = AND(iv[11],0xFF);

		iv[10] = iv[10] + 1;
		if iv[10] <= 0xFF then return; end
		iv[10] = AND(iv[10],0xFF);

		iv[9] = iv[9] + 1;
		if iv[9] <= 0xFF then return; end
		iv[9] = AND(iv[9],0xFF);

		return;
	end

	public.update = function(messageStream)
		local byte = messageStream();
		while (byte ~= nil) do
			inputQueue.push(byte);

			if(inputQueue.size() >= blockCipher.blockSize) then
				local block = Array.readFromQueue(inputQueue,blockCipher.blockSize);

				if(iv == nil) then
					iv = block;
				else
					local out = iv;
					out = blockCipher.encrypt(key,out);

					out = Array.XOR(out,block);
					Array.writeToQueue(outputQueue,out);
					updateIV();
				end
			end
			byte = messageStream();
		end
		return public;
	end

	public.finish = function()
		paddingStream = padding(blockCipher.blockSize,inputQueue.getHead());
		public.update(paddingStream);

		return public;
	end

	public.getOutputQueue = function()
		return outputQueue;
	end

	public.asHex = function()
		return Stream.toHex(outputQueue.pop);
	end

	public.asBytes = function()
		return Stream.toArray(outputQueue.pop);
	end

	return public;

end


CTR.Decipher = function()

	local public = {};

	local key;
	local blockCipher;
	local padding;
	local inputQueue;
	local outputQueue;
	local iv;

	public.setKey = function(keyBytes)
		key = keyBytes;
		return public;
	end

	public.setBlockCipher = function(cipher)
		blockCipher = cipher;
		return public;
	end

	public.setPadding = function(paddingMode)
		padding = paddingMode;
		return public;
	end

	public.init = function()
		inputQueue = Queue();
		outputQueue = Queue();
		iv = nil;
		return public;
	end

	local updateIV = function()
		iv[16] = iv[16] + 1;
		if iv[16] <= 0xFF then return; end
		iv[16] = AND(iv[16],0xFF);

		iv[15] = iv[15] + 1;
		if iv[15] <= 0xFF then return; end
		iv[15] = AND(iv[15],0xFF);

		iv[14] = iv[14] + 1;
		if iv[14] <= 0xFF then return; end
		iv[14] = AND(iv[14],0xFF);

		iv[13] = iv[13] + 1;
		if iv[13] <= 0xFF then return; end
		iv[13] = AND(iv[13],0xFF);

		iv[12] = iv[12] + 1;
		if iv[12] <= 0xFF then return; end
		iv[12] = AND(iv[12],0xFF);

		iv[11] = iv[11] + 1;
		if iv[11] <= 0xFF then return; end
		iv[11] = AND(iv[11],0xFF);

		iv[10] = iv[10] + 1;
		if iv[10] <= 0xFF then return; end
		iv[10] = AND(iv[10],0xFF);

		iv[9] = iv[9] + 1;
		if iv[9] <= 0xFF then return; end
		iv[9] = AND(iv[9],0xFF);

		return;
	end

	public.update = function(messageStream)
		local byte = messageStream();
		while (byte ~= nil) do
			inputQueue.push(byte);

			if(inputQueue.size() >= blockCipher.blockSize) then
				local block = Array.readFromQueue(inputQueue,blockCipher.blockSize);

				if(iv == nil) then
					iv = block;
				else
					local out = iv;
					out = blockCipher.encrypt(key,out);

					out = Array.XOR(out,block);
					Array.writeToQueue(outputQueue,out);
					updateIV();
				end
			end
			byte = messageStream();
		end
		return public;
	end

	public.finish = function()
		paddingStream = padding(blockCipher.blockSize,inputQueue.getHead());
		public.update(paddingStream);

		return public;
	end

	public.getOutputQueue = function()
		return outputQueue;
	end

	public.asHex = function()
		return Stream.toHex(outputQueue.pop);
	end

	public.asBytes = function()
		return Stream.toArray(outputQueue.pop);
	end

	return public;

end




return CTR;

]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.cipher.mode.cfb"],"module already exists")sources["lockbox.cipher.mode.cfb"]=([===[-- <pack lockbox.cipher.mode.cfb> --
local Array = require("lockbox.util.array");
local Stream = require("lockbox.util.stream");
local Queue = require("lockbox.util.queue");

local String = require("string");
local Bit = require("lockbox.util.bit");

local CFB = {};

CFB.Cipher = function()

	local public = {};

	local key;
	local blockCipher;
	local padding;
	local inputQueue;
	local outputQueue;
	local iv;

	public.setKey = function(keyBytes)
		key = keyBytes;
		return public;
	end

	public.setBlockCipher = function(cipher)
		blockCipher = cipher;
		return public;
	end

	public.setPadding = function(paddingMode)
		padding = paddingMode;
		return public;
	end

	public.init = function()
		inputQueue = Queue();
		outputQueue = Queue();
		iv = nil;
		return public;
	end

	public.update = function(messageStream)
		local byte = messageStream();
		while (byte ~= nil) do
			inputQueue.push(byte);
			if(inputQueue.size() >= blockCipher.blockSize) then
				local block = Array.readFromQueue(inputQueue,blockCipher.blockSize);

				if(iv == nil) then
					iv = block;
				else
					local out = iv;
					out = blockCipher.encrypt(key,out);
					out = Array.XOR(out,block);
					Array.writeToQueue(outputQueue,out);
					iv = out;
				end
			end
			byte = messageStream();
		end
		return public;
	end

	public.finish = function()
		paddingStream = padding(blockCipher.blockSize,inputQueue.getHead());
		public.update(paddingStream);

		return public;
	end

	public.getOutputQueue = function()
		return outputQueue;
	end

	public.asHex = function()
		return Stream.toHex(outputQueue.pop);
	end

	public.asBytes = function()
		return Stream.toArray(outputQueue.pop);
	end

	return public;

end

CFB.Decipher = function()

	local public = {};

	local key;
	local blockCipher;
	local padding;
	local inputQueue;
	local outputQueue;
	local iv;

	public.setKey = function(keyBytes)
		key = keyBytes;
		return public;
	end

	public.setBlockCipher = function(cipher)
		blockCipher = cipher;
		return public;
	end

	public.setPadding = function(paddingMode)
		padding = paddingMode;
		return public;
	end

	public.init = function()
		inputQueue = Queue();
		outputQueue = Queue();
		iv = nil;
		return public;
	end

	public.update = function(messageStream)
		local byte = messageStream();
		while (byte ~= nil) do
			inputQueue.push(byte);
			if(inputQueue.size() >= blockCipher.blockSize) then
				local block = Array.readFromQueue(inputQueue,blockCipher.blockSize);

				if(iv == nil) then
					iv = block;
				else
					local out = iv;
					out = blockCipher.encrypt(key,out);
					out = Array.XOR(out,block);
					Array.writeToQueue(outputQueue,out);
					iv = block;
				end
			end
			byte = messageStream();
		end
		return public;
	end

	public.finish = function()
		paddingStream = padding(blockCipher.blockSize,inputQueue.getHead());
		public.update(paddingStream);

		return public;
	end

	public.getOutputQueue = function()
		return outputQueue;
	end

	public.asHex = function()
		return Stream.toHex(outputQueue.pop);
	end

	public.asBytes = function()
		return Stream.toArray(outputQueue.pop);
	end

	return public;

end

return CFB;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.cipher.mode.cbc"],"module already exists")sources["lockbox.cipher.mode.cbc"]=([===[-- <pack lockbox.cipher.mode.cbc> --
local Array = require("lockbox.util.array");
local Stream = require("lockbox.util.stream");
local Queue = require("lockbox.util.queue");

local String = require("string");
local Bit = require("lockbox.util.bit");

local CBC = {};

CBC.Cipher = function()

	local public = {};

	local key;
	local blockCipher;
	local padding;
	local inputQueue;
	local outputQueue;
	local iv;

	public.setKey = function(keyBytes)
		key = keyBytes;
		return public;
	end

	public.setBlockCipher = function(cipher)
		blockCipher = cipher;
		return public;
	end

	public.setPadding = function(paddingMode)
		padding = paddingMode;
		return public;
	end

	public.init = function()
		inputQueue = Queue();
		outputQueue = Queue();
		iv = nil;
		return public;
	end

	public.update = function(messageStream)
		local byte = messageStream();
		while (byte ~= nil) do
			inputQueue.push(byte);
			if(inputQueue.size() >= blockCipher.blockSize) then
				local block = Array.readFromQueue(inputQueue,blockCipher.blockSize);

				if(iv == nil) then
					iv = block;
				else
					local out = Array.XOR(iv,block);
					out = blockCipher.encrypt(key,out);
					Array.writeToQueue(outputQueue,out);
					iv = out;
				end
			end
			byte = messageStream();
		end
		return public;
	end

	public.finish = function()
		paddingStream = padding(blockCipher.blockSize,inputQueue.getHead());
		public.update(paddingStream);

		return public;
	end

	public.getOutputQueue = function()
		return outputQueue;
	end

	public.asHex = function()
		return Stream.toHex(outputQueue.pop);
	end

	public.asBytes = function()
		return Stream.toArray(outputQueue.pop);
	end

	return public;

end


CBC.Decipher = function()

	local public = {};

	local key;
	local blockCipher;
	local padding;
	local inputQueue;
	local outputQueue;
	local iv;

	public.setKey = function(keyBytes)
		key = keyBytes;
		return public;
	end

	public.setBlockCipher = function(cipher)
		blockCipher = cipher;
		return public;
	end

	public.setPadding = function(paddingMode)
		padding = paddingMode;
		return public;
	end

	public.init = function()
		inputQueue = Queue();
		outputQueue = Queue();
		iv = nil;
		return public;
	end

	public.update = function(messageStream)
		local byte = messageStream();
		while (byte ~= nil) do
			inputQueue.push(byte);
			if(inputQueue.size() >= blockCipher.blockSize) then
				local block = Array.readFromQueue(inputQueue,blockCipher.blockSize);

				if(iv == nil) then
					iv = block;
				else
					local out = block;
					out = blockCipher.decrypt(key,out);
					out = Array.XOR(iv,out);
					Array.writeToQueue(outputQueue,out);
					iv = block;
				end
			end
			byte = messageStream();
		end
		return public;
	end

	public.finish = function()
		paddingStream = padding(blockCipher.blockSize,inputQueue.getHead());
		public.update(paddingStream);

		return public;
	end

	public.getOutputQueue = function()
		return outputQueue;
	end

	public.asHex = function()
		return Stream.toHex(outputQueue.pop);
	end

	public.asBytes = function()
		return Stream.toArray(outputQueue.pop);
	end

	return public;

end

return CBC;

]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.cipher.des3"],"module already exists")sources["lockbox.cipher.des3"]=([===[-- <pack lockbox.cipher.des3> --
require("lockbox").insecure();

local Array = require("lockbox.util.array");

local DES = require("lockbox.cipher.des");

local DES3 = {};

local getKeys = function(keyBlock)
	local size = Array.size(keyBlock)

	local key1;
	local key2;
	local key3;

	if (size == 8) then
		key1 = keyBlock;
		key2 = keyBlock;
		key3 = keyBlock;
	elseif (size == 16) then
		key1 = Array.slice(keyBlock,1,8);
		key2 = Array.slice(keyBlock,9,16);
		key3 = key1;
	elseif (size == 24) then
		key1 = Array.slice(keyBlock,1,8);
		key2 = Array.slice(keyBlock,9,16);
		key3 = Array.slice(keyBlock,17,24);
	else
		assert(false,"Invalid key size for 3DES");
	end

	return key1,key2,key3;
end

DES3.blockSize = DES.blockSize;

DES3.encrypt = function(keyBlock,inputBlock)
	local key1;
	local key2;
	local key3;

	key1, key2, key3 = getKeys(keyBlock);

	local block = inputBlock;
	block = DES.encrypt(key1,block);
	block = DES.decrypt(key2,block);
	block = DES.encrypt(key3,block);

	return block;
end

DES3.decrypt = function(keyBlock,inputBlock)
	local key1;
	local key2;
	local key3;

	key1, key2, key3 = getKeys(keyBlock);

	local block = inputBlock;
	block = DES.decrypt(key3,block);
	block = DES.encrypt(key2,block);
	block = DES.decrypt(key1,block);

	return block;
end

return DES3;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.cipher.des"],"module already exists")sources["lockbox.cipher.des"]=([===[-- <pack lockbox.cipher.des> --
require("lockbox").insecure();

local Stream = require("lockbox.util.stream");
local Array = require("lockbox.util.array");

local Bit = require("lockbox.util.bit");
local Math = require("math");


local AND = Bit.band;
local OR  = Bit.bor;
local NOT = Bit.bnot;
local XOR = Bit.bxor;
local LROT = Bit.lrotate;
local RROT = Bit.rrotate;
local LSHIFT = Bit.lshift;
local RSHIFT = Bit.rshift;

local IN_P = {	58, 50, 42, 34, 26, 18, 10,  2,
				60, 52, 44, 36, 28, 20, 12,  4,
				62, 54, 46, 38, 30, 22, 14,  6,
				64, 56, 48, 40, 32, 24, 16,  8,
				57, 49, 41, 33, 25, 17,  9,  1,
				59, 51, 43, 35, 27, 19, 11,  3,
				61, 53, 45, 37, 29, 21, 13,  5,
				63, 55, 47, 39, 31, 23, 15,  7};

local OUT_P = {	40,  8, 48, 16, 56, 24, 64, 32,
				39,  7, 47, 15, 55, 23, 63, 31,
				38,  6, 46, 14, 54, 22, 62, 30,
				37,  5, 45, 13, 53, 21, 61, 29,
				36,  4, 44, 12, 52, 20, 60, 28,
				35,  3, 43, 11, 51, 19, 59, 27,
				34,  2, 42, 10, 50, 18, 58, 26,
				33,  1, 41,  9, 49, 17, 57, 25};

-- add 32 to each because we do the expansion on the full LR table, not just R
local EBIT = {	32+32,  1+32,  2+32,  3+32,  4+32,  5+32,  4+32,  5+32,  6+32,  7+32,  8+32,  9+32,
				 8+32,  9+32, 10+32, 11+32, 12+32, 13+32, 12+32, 13+32, 14+32, 15+32, 16+32, 17+32,
				16+32, 17+32, 18+32, 19+32, 20+32, 21+32, 20+32, 21+32, 22+32, 23+32, 24+32, 25+32,
				24+32, 25+32, 26+32, 27+32, 28+32, 29+32, 28+32, 29+32, 30+32, 31+32, 32+32,  1+32, };

local LR_SWAP = {	33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,
					49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,
					 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,
					17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32};

local PC1 = {	57,49,41,33,25,17, 9, 1,58,50,42,34,26,18,
				10, 2,59,51,43,35,27,19,11, 3,60,52,44,36,
				63,55,47,39,31,23,15, 7,62,54,46,38,30,22,
				14, 6,61,53,45,37,29,21,13, 5,28,20,12, 4};

local PC2 = {	14,17,11,24, 1, 5, 3,28,15, 6,21,10,
                23,19,12, 4,26, 8,16, 7,27,20,13, 2,
                41,52,31,37,47,55,30,40,51,45,33,48,
                44,49,39,56,34,53,46,42,50,36,29,32};

local KS1 = {	 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28, 1,
				30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,29};
local KS2 = KS1;

local KS3 = {	 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28, 1, 2,
				31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,29,30};

local KS4  = KS3;
local KS5  = KS3;
local KS6  = KS3;
local KS7  = KS3;
local KS8  = KS3;
local KS9  = KS1;
local KS10 = KS3;
local KS11 = KS3;
local KS12 = KS3;
local KS13 = KS3;
local KS14 = KS3;
local KS15 = KS3;
local KS16 = KS1;


local SIND1 = {    2,   3,   4,   5,   1,   6 };
local SIND2 = {  2+6, 3+6, 4+6, 5+6, 1+6, 6+6 };
local SIND3 = { 2+12,3+12,4+12,5+12,1+12,6+12 };
local SIND4 = { 2+18,3+18,4+18,5+18,1+18,6+18 };
local SIND5 = { 2+24,3+24,4+24,5+24,1+24,6+24 };
local SIND6 = { 2+30,3+30,4+30,5+30,1+30,6+30 };
local SIND7 = { 2+36,3+36,4+36,5+36,1+36,6+36 };
local SIND8 = { 2+42,3+42,4+42,5+42,1+42,6+42 };

local SBOX1 = {	14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7,
		 		0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8,
		 		4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0,
		 		15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13};

local SBOX2 = {	15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10,
		 		3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5,
		 		0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15,
		 		13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9};

local SBOX3 = {	10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8,
				13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1,
				13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7,
				1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12};

local SBOX4 = {	7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15,
				13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9,
				10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4,
				3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14};

local SBOX5 = {	2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9,
				14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6,
				4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14,
				11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3};

local SBOX6 = {	12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11,
				10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8,
				9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6,
				4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13};

local SBOX7 = {	4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1,
				13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6,
				1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2,
				6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12};

local SBOX8 = {	13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7,
				1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2,
				7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8,
				2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11};

local ROUND_P = {	16, 7,20,21,29,12,28,17, 1,15,23,26, 5,18,31,10,
					 2, 8,24,14,32,27, 3, 9,19,13,30, 6,22,11, 4,25};

local permute = Array.permute;

local unpackBytes = function(bytes)
	local bits = {};

	for k,b in pairs(bytes) do
		table.insert(bits,RSHIFT(AND(b,0x80),7));
		table.insert(bits,RSHIFT(AND(b,0x40),6));
		table.insert(bits,RSHIFT(AND(b,0x20),5));
		table.insert(bits,RSHIFT(AND(b,0x10),4));
		table.insert(bits,RSHIFT(AND(b,0x08),3));
		table.insert(bits,RSHIFT(AND(b,0x04),2));
		table.insert(bits,RSHIFT(AND(b,0x02),1));
		table.insert(bits,      AND(b,0x01)   );
	end

	return bits;
end

local packBytes = function(bits)
	local bytes = {}

	for k,v in pairs(bits) do
		local index = Math.floor((k-1)/8) + 1;
		local shift = 7-Math.fmod((k-1),8);

		local bit = bits[k];
		local byte = bytes[index];

		if not byte then byte = 0x00; end
		byte = OR(byte,LSHIFT(bit,shift));
		bytes[index] = byte;
	end

	return bytes;
end

local mix = function(LR,key)

	local ER = permute(LR,EBIT);

	for k,v in pairs(ER) do
		ER[k] = XOR(ER[k],key[k]);
	end

	local FRK = {};

	local S = 0x00;
	S = OR(S,ER[1]); S = LSHIFT(S,1);
	S = OR(S,ER[6]); S = LSHIFT(S,1);
	S = OR(S,ER[2]); S = LSHIFT(S,1);
	S = OR(S,ER[3]); S = LSHIFT(S,1);
	S = OR(S,ER[4]); S = LSHIFT(S,1);
	S = OR(S,ER[5]); S = S+1;
	S = SBOX1[S];

	FRK[1] = RSHIFT(AND(S,0x08),3);
	FRK[2] = RSHIFT(AND(S,0x04),2);
	FRK[3] = RSHIFT(AND(S,0x02),1);
	FRK[4] = AND(S,0x01);


	S = 0x00;
	S = OR(S,ER[1+6]); S = LSHIFT(S,1);
	S = OR(S,ER[6+6]); S = LSHIFT(S,1);
	S = OR(S,ER[2+6]); S = LSHIFT(S,1);
	S = OR(S,ER[3+6]); S = LSHIFT(S,1);
	S = OR(S,ER[4+6]); S = LSHIFT(S,1);
	S = OR(S,ER[5+6]); S = S+1;
	S = SBOX2[S];

	FRK[5] = RSHIFT(AND(S,0x08),3);
	FRK[6] = RSHIFT(AND(S,0x04),2);
	FRK[7] = RSHIFT(AND(S,0x02),1);
	FRK[8] = AND(S,0x01);


	S = 0x00;
	S = OR(S,ER[1+12]); S = LSHIFT(S,1);
	S = OR(S,ER[6+12]); S = LSHIFT(S,1);
	S = OR(S,ER[2+12]); S = LSHIFT(S,1);
	S = OR(S,ER[3+12]); S = LSHIFT(S,1);
	S = OR(S,ER[4+12]); S = LSHIFT(S,1);
	S = OR(S,ER[5+12]); S = S+1;
	S = SBOX3[S];

	FRK[9] = RSHIFT(AND(S,0x08),3);
	FRK[10] = RSHIFT(AND(S,0x04),2);
	FRK[11] = RSHIFT(AND(S,0x02),1);
	FRK[12] = AND(S,0x01);


	S = 0x00;
	S = OR(S,ER[1+18]); S = LSHIFT(S,1);
	S = OR(S,ER[6+18]); S = LSHIFT(S,1);
	S = OR(S,ER[2+18]); S = LSHIFT(S,1);
	S = OR(S,ER[3+18]); S = LSHIFT(S,1);
	S = OR(S,ER[4+18]); S = LSHIFT(S,1);
	S = OR(S,ER[5+18]); S = S+1;
	S = SBOX4[S];

	FRK[13] = RSHIFT(AND(S,0x08),3);
	FRK[14] = RSHIFT(AND(S,0x04),2);
	FRK[15] = RSHIFT(AND(S,0x02),1);
	FRK[16] = AND(S,0x01);


	S = 0x00;
	S = OR(S,ER[1+24]); S = LSHIFT(S,1);
	S = OR(S,ER[6+24]); S = LSHIFT(S,1);
	S = OR(S,ER[2+24]); S = LSHIFT(S,1);
	S = OR(S,ER[3+24]); S = LSHIFT(S,1);
	S = OR(S,ER[4+24]); S = LSHIFT(S,1);
	S = OR(S,ER[5+24]); S = S+1;
	S = SBOX5[S];

	FRK[17] = RSHIFT(AND(S,0x08),3);
	FRK[18] = RSHIFT(AND(S,0x04),2);
	FRK[19] = RSHIFT(AND(S,0x02),1);
	FRK[20] = AND(S,0x01);


	S = 0x00;
	S = OR(S,ER[1+30]); S = LSHIFT(S,1);
	S = OR(S,ER[6+30]); S = LSHIFT(S,1);
	S = OR(S,ER[2+30]); S = LSHIFT(S,1);
	S = OR(S,ER[3+30]); S = LSHIFT(S,1);
	S = OR(S,ER[4+30]); S = LSHIFT(S,1);
	S = OR(S,ER[5+30]); S = S+1;
	S = SBOX6[S];

	FRK[21] = RSHIFT(AND(S,0x08),3);
	FRK[22] = RSHIFT(AND(S,0x04),2);
	FRK[23] = RSHIFT(AND(S,0x02),1);
	FRK[24] = AND(S,0x01);


	S = 0x00;
	S = OR(S,ER[1+36]); S = LSHIFT(S,1);
	S = OR(S,ER[6+36]); S = LSHIFT(S,1);
	S = OR(S,ER[2+36]); S = LSHIFT(S,1);
	S = OR(S,ER[3+36]); S = LSHIFT(S,1);
	S = OR(S,ER[4+36]); S = LSHIFT(S,1);
	S = OR(S,ER[5+36]); S = S+1;
	S = SBOX7[S];

	FRK[25] = RSHIFT(AND(S,0x08),3);
	FRK[26] = RSHIFT(AND(S,0x04),2);
	FRK[27] = RSHIFT(AND(S,0x02),1);
	FRK[28] = AND(S,0x01);


	S = 0x00;
	S = OR(S,ER[1+42]); S = LSHIFT(S,1);
	S = OR(S,ER[6+42]); S = LSHIFT(S,1);
	S = OR(S,ER[2+42]); S = LSHIFT(S,1);
	S = OR(S,ER[3+42]); S = LSHIFT(S,1);
	S = OR(S,ER[4+42]); S = LSHIFT(S,1);
	S = OR(S,ER[5+42]); S = S+1;
	S = SBOX8[S];

	FRK[29] = RSHIFT(AND(S,0x08),3);
	FRK[30] = RSHIFT(AND(S,0x04),2);
	FRK[31] = RSHIFT(AND(S,0x02),1);
	FRK[32] = AND(S,0x01);

	FRK = permute(FRK,ROUND_P);

	return FRK;
end

local DES = {};

DES.blockSize = 8;

DES.encrypt = function(keyBlock,inputBlock)

	local LR = unpackBytes(inputBlock);
	local keyBits = unpackBytes(keyBlock);


	local CD = permute(keyBits,PC1);

	--key schedule
	CD = permute(CD,KS1); local KEY1 = permute(CD,PC2);
	CD = permute(CD,KS2); local KEY2 = permute(CD,PC2);
	CD = permute(CD,KS3); local KEY3 = permute(CD,PC2);
	CD = permute(CD,KS4); local KEY4 = permute(CD,PC2);
	CD = permute(CD,KS5); local KEY5 = permute(CD,PC2);
	CD = permute(CD,KS6); local KEY6 = permute(CD,PC2);
	CD = permute(CD,KS7); local KEY7 = permute(CD,PC2);
	CD = permute(CD,KS8); local KEY8 = permute(CD,PC2);
	CD = permute(CD,KS9); local KEY9 = permute(CD,PC2);
	CD = permute(CD,KS10); local KEY10 = permute(CD,PC2);
	CD = permute(CD,KS11); local KEY11 = permute(CD,PC2);
	CD = permute(CD,KS12); local KEY12 = permute(CD,PC2);
	CD = permute(CD,KS13); local KEY13 = permute(CD,PC2);
	CD = permute(CD,KS14); local KEY14 = permute(CD,PC2);
	CD = permute(CD,KS15); local KEY15 = permute(CD,PC2);
	CD = permute(CD,KS16); local KEY16 = permute(CD,PC2);

	--input permutation
	LR = permute(LR,IN_P);

	--rounds
	local frk = mix(LR,KEY1);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY2);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY3);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY4);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY5);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY6);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY7);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY8);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY9);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY10);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY11);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY12);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY13);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY14);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY15);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY16);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	--LR = permute(LR,LR_SWAP);

	--output permutation
	LR = permute(LR,OUT_P);

	local outputBlock = packBytes(LR);
	return outputBlock;
end

DES.decrypt = function(keyBlock,inputBlock)


	local LR = unpackBytes(inputBlock);
	local keyBits = unpackBytes(keyBlock);


	local CD = permute(keyBits,PC1);

	--key schedule
	CD = permute(CD,KS1); local KEY1 = permute(CD,PC2);
	CD = permute(CD,KS2); local KEY2 = permute(CD,PC2);
	CD = permute(CD,KS3); local KEY3 = permute(CD,PC2);
	CD = permute(CD,KS4); local KEY4 = permute(CD,PC2);
	CD = permute(CD,KS5); local KEY5 = permute(CD,PC2);
	CD = permute(CD,KS6); local KEY6 = permute(CD,PC2);
	CD = permute(CD,KS7); local KEY7 = permute(CD,PC2);
	CD = permute(CD,KS8); local KEY8 = permute(CD,PC2);
	CD = permute(CD,KS9); local KEY9 = permute(CD,PC2);
	CD = permute(CD,KS10); local KEY10 = permute(CD,PC2);
	CD = permute(CD,KS11); local KEY11 = permute(CD,PC2);
	CD = permute(CD,KS12); local KEY12 = permute(CD,PC2);
	CD = permute(CD,KS13); local KEY13 = permute(CD,PC2);
	CD = permute(CD,KS14); local KEY14 = permute(CD,PC2);
	CD = permute(CD,KS15); local KEY15 = permute(CD,PC2);
	CD = permute(CD,KS16); local KEY16 = permute(CD,PC2);

	--input permutation
	LR = permute(LR,IN_P);

	--rounds
	local frk = mix(LR,KEY16);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY15);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY14);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY13);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY12);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY11);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY10);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY9);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY8);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY7);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY6);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY5);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY4);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY3);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY2);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	LR = permute(LR,LR_SWAP);

	frk = mix(LR,KEY1);
	for k,v in pairs(frk) do LR[k] = XOR(LR[k],frk[k]); end
	--LR = permute(LR,LR_SWAP);

	--output permutation
	LR = permute(LR,OUT_P);

	local outputBlock = packBytes(LR);
	return outputBlock;
end

return DES;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.cipher.aes256"],"module already exists")sources["lockbox.cipher.aes256"]=([===[-- <pack lockbox.cipher.aes256> --
local Stream = require("lockbox.util.stream");
local Array = require("lockbox.util.array");

local Bit = require("lockbox.util.bit");
local Math = require("math");


local AND = Bit.band;
local OR  = Bit.bor;
local NOT = Bit.bnot;
local XOR = Bit.bxor;
local LROT = Bit.lrotate;
local RROT = Bit.rrotate;
local LSHIFT = Bit.lshift;
local RSHIFT = Bit.rshift;

local SBOX = {
 [0]=0x63, 0x7C, 0x77, 0x7B, 0xF2, 0x6B, 0x6F, 0xC5, 0x30, 0x01, 0x67, 0x2B, 0xFE, 0xD7, 0xAB, 0x76,
 0xCA, 0x82, 0xC9, 0x7D, 0xFA, 0x59, 0x47, 0xF0, 0xAD, 0xD4, 0xA2, 0xAF, 0x9C, 0xA4, 0x72, 0xC0,
 0xB7, 0xFD, 0x93, 0x26, 0x36, 0x3F, 0xF7, 0xCC, 0x34, 0xA5, 0xE5, 0xF1, 0x71, 0xD8, 0x31, 0x15,
 0x04, 0xC7, 0x23, 0xC3, 0x18, 0x96, 0x05, 0x9A, 0x07, 0x12, 0x80, 0xE2, 0xEB, 0x27, 0xB2, 0x75,
 0x09, 0x83, 0x2C, 0x1A, 0x1B, 0x6E, 0x5A, 0xA0, 0x52, 0x3B, 0xD6, 0xB3, 0x29, 0xE3, 0x2F, 0x84,
 0x53, 0xD1, 0x00, 0xED, 0x20, 0xFC, 0xB1, 0x5B, 0x6A, 0xCB, 0xBE, 0x39, 0x4A, 0x4C, 0x58, 0xCF,
 0xD0, 0xEF, 0xAA, 0xFB, 0x43, 0x4D, 0x33, 0x85, 0x45, 0xF9, 0x02, 0x7F, 0x50, 0x3C, 0x9F, 0xA8,
 0x51, 0xA3, 0x40, 0x8F, 0x92, 0x9D, 0x38, 0xF5, 0xBC, 0xB6, 0xDA, 0x21, 0x10, 0xFF, 0xF3, 0xD2,
 0xCD, 0x0C, 0x13, 0xEC, 0x5F, 0x97, 0x44, 0x17, 0xC4, 0xA7, 0x7E, 0x3D, 0x64, 0x5D, 0x19, 0x73,
 0x60, 0x81, 0x4F, 0xDC, 0x22, 0x2A, 0x90, 0x88, 0x46, 0xEE, 0xB8, 0x14, 0xDE, 0x5E, 0x0B, 0xDB,
 0xE0, 0x32, 0x3A, 0x0A, 0x49, 0x06, 0x24, 0x5C, 0xC2, 0xD3, 0xAC, 0x62, 0x91, 0x95, 0xE4, 0x79,
 0xE7, 0xC8, 0x37, 0x6D, 0x8D, 0xD5, 0x4E, 0xA9, 0x6C, 0x56, 0xF4, 0xEA, 0x65, 0x7A, 0xAE, 0x08,
 0xBA, 0x78, 0x25, 0x2E, 0x1C, 0xA6, 0xB4, 0xC6, 0xE8, 0xDD, 0x74, 0x1F, 0x4B, 0xBD, 0x8B, 0x8A,
 0x70, 0x3E, 0xB5, 0x66, 0x48, 0x03, 0xF6, 0x0E, 0x61, 0x35, 0x57, 0xB9, 0x86, 0xC1, 0x1D, 0x9E,
 0xE1, 0xF8, 0x98, 0x11, 0x69, 0xD9, 0x8E, 0x94, 0x9B, 0x1E, 0x87, 0xE9, 0xCE, 0x55, 0x28, 0xDF,
 0x8C, 0xA1, 0x89, 0x0D, 0xBF, 0xE6, 0x42, 0x68, 0x41, 0x99, 0x2D, 0x0F, 0xB0, 0x54, 0xBB, 0x16};

local ISBOX = {
 [0]=0x52, 0x09, 0x6A, 0xD5, 0x30, 0x36, 0xA5, 0x38, 0xBF, 0x40, 0xA3, 0x9E, 0x81, 0xF3, 0xD7, 0xFB,
 0x7C, 0xE3, 0x39, 0x82, 0x9B, 0x2F, 0xFF, 0x87, 0x34, 0x8E, 0x43, 0x44, 0xC4, 0xDE, 0xE9, 0xCB,
 0x54, 0x7B, 0x94, 0x32, 0xA6, 0xC2, 0x23, 0x3D, 0xEE, 0x4C, 0x95, 0x0B, 0x42, 0xFA, 0xC3, 0x4E,
 0x08, 0x2E, 0xA1, 0x66, 0x28, 0xD9, 0x24, 0xB2, 0x76, 0x5B, 0xA2, 0x49, 0x6D, 0x8B, 0xD1, 0x25,
 0x72, 0xF8, 0xF6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xD4, 0xA4, 0x5C, 0xCC, 0x5D, 0x65, 0xB6, 0x92,
 0x6C, 0x70, 0x48, 0x50, 0xFD, 0xED, 0xB9, 0xDA, 0x5E, 0x15, 0x46, 0x57, 0xA7, 0x8D, 0x9D, 0x84,
 0x90, 0xD8, 0xAB, 0x00, 0x8C, 0xBC, 0xD3, 0x0A, 0xF7, 0xE4, 0x58, 0x05, 0xB8, 0xB3, 0x45, 0x06,
 0xD0, 0x2C, 0x1E, 0x8F, 0xCA, 0x3F, 0x0F, 0x02, 0xC1, 0xAF, 0xBD, 0x03, 0x01, 0x13, 0x8A, 0x6B,
 0x3A, 0x91, 0x11, 0x41, 0x4F, 0x67, 0xDC, 0xEA, 0x97, 0xF2, 0xCF, 0xCE, 0xF0, 0xB4, 0xE6, 0x73,
 0x96, 0xAC, 0x74, 0x22, 0xE7, 0xAD, 0x35, 0x85, 0xE2, 0xF9, 0x37, 0xE8, 0x1C, 0x75, 0xDF, 0x6E,
 0x47, 0xF1, 0x1A, 0x71, 0x1D, 0x29, 0xC5, 0x89, 0x6F, 0xB7, 0x62, 0x0E, 0xAA, 0x18, 0xBE, 0x1B,
 0xFC, 0x56, 0x3E, 0x4B, 0xC6, 0xD2, 0x79, 0x20, 0x9A, 0xDB, 0xC0, 0xFE, 0x78, 0xCD, 0x5A, 0xF4,
 0x1F, 0xDD, 0xA8, 0x33, 0x88, 0x07, 0xC7, 0x31, 0xB1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xEC, 0x5F,
 0x60, 0x51, 0x7F, 0xA9, 0x19, 0xB5, 0x4A, 0x0D, 0x2D, 0xE5, 0x7A, 0x9F, 0x93, 0xC9, 0x9C, 0xEF,
 0xA0, 0xE0, 0x3B, 0x4D, 0xAE, 0x2A, 0xF5, 0xB0, 0xC8, 0xEB, 0xBB, 0x3C, 0x83, 0x53, 0x99, 0x61,
 0x17, 0x2B, 0x04, 0x7E, 0xBA, 0x77, 0xD6, 0x26, 0xE1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0C, 0x7D};

local ROW_SHIFT =  {  1,  6, 11, 16,  5, 10, 15,  4,  9, 14,  3,  8, 13,  2,  7, 12,};
local IROW_SHIFT = {  1, 14, 11,  8,  5,  2, 15, 12,  9,  6,  3, 16, 13, 10,  7,  4,};

local ETABLE = {
 [0]=0x01, 0x03, 0x05, 0x0F, 0x11, 0x33, 0x55, 0xFF, 0x1A, 0x2E, 0x72, 0x96, 0xA1, 0xF8, 0x13, 0x35,
 0x5F, 0xE1, 0x38, 0x48, 0xD8, 0x73, 0x95, 0xA4, 0xF7, 0x02, 0x06, 0x0A, 0x1E, 0x22, 0x66, 0xAA,
 0xE5, 0x34, 0x5C, 0xE4, 0x37, 0x59, 0xEB, 0x26, 0x6A, 0xBE, 0xD9, 0x70, 0x90, 0xAB, 0xE6, 0x31,
 0x53, 0xF5, 0x04, 0x0C, 0x14, 0x3C, 0x44, 0xCC, 0x4F, 0xD1, 0x68, 0xB8, 0xD3, 0x6E, 0xB2, 0xCD,
 0x4C, 0xD4, 0x67, 0xA9, 0xE0, 0x3B, 0x4D, 0xD7, 0x62, 0xA6, 0xF1, 0x08, 0x18, 0x28, 0x78, 0x88,
 0x83, 0x9E, 0xB9, 0xD0, 0x6B, 0xBD, 0xDC, 0x7F, 0x81, 0x98, 0xB3, 0xCE, 0x49, 0xDB, 0x76, 0x9A,
 0xB5, 0xC4, 0x57, 0xF9, 0x10, 0x30, 0x50, 0xF0, 0x0B, 0x1D, 0x27, 0x69, 0xBB, 0xD6, 0x61, 0xA3,
 0xFE, 0x19, 0x2B, 0x7D, 0x87, 0x92, 0xAD, 0xEC, 0x2F, 0x71, 0x93, 0xAE, 0xE9, 0x20, 0x60, 0xA0,
 0xFB, 0x16, 0x3A, 0x4E, 0xD2, 0x6D, 0xB7, 0xC2, 0x5D, 0xE7, 0x32, 0x56, 0xFA, 0x15, 0x3F, 0x41,
 0xC3, 0x5E, 0xE2, 0x3D, 0x47, 0xC9, 0x40, 0xC0, 0x5B, 0xED, 0x2C, 0x74, 0x9C, 0xBF, 0xDA, 0x75,
 0x9F, 0xBA, 0xD5, 0x64, 0xAC, 0xEF, 0x2A, 0x7E, 0x82, 0x9D, 0xBC, 0xDF, 0x7A, 0x8E, 0x89, 0x80,
 0x9B, 0xB6, 0xC1, 0x58, 0xE8, 0x23, 0x65, 0xAF, 0xEA, 0x25, 0x6F, 0xB1, 0xC8, 0x43, 0xC5, 0x54,
 0xFC, 0x1F, 0x21, 0x63, 0xA5, 0xF4, 0x07, 0x09, 0x1B, 0x2D, 0x77, 0x99, 0xB0, 0xCB, 0x46, 0xCA,
 0x45, 0xCF, 0x4A, 0xDE, 0x79, 0x8B, 0x86, 0x91, 0xA8, 0xE3, 0x3E, 0x42, 0xC6, 0x51, 0xF3, 0x0E,
 0x12, 0x36, 0x5A, 0xEE, 0x29, 0x7B, 0x8D, 0x8C, 0x8F, 0x8A, 0x85, 0x94, 0xA7, 0xF2, 0x0D, 0x17,
 0x39, 0x4B, 0xDD, 0x7C, 0x84, 0x97, 0xA2, 0xFD, 0x1C, 0x24, 0x6C, 0xB4, 0xC7, 0x52, 0xF6, 0x01};

local LTABLE = {
 [0]=0x00, 0x00, 0x19, 0x01, 0x32, 0x02, 0x1A, 0xC6, 0x4B, 0xC7, 0x1B, 0x68, 0x33, 0xEE, 0xDF, 0x03,
 0x64, 0x04, 0xE0, 0x0E, 0x34, 0x8D, 0x81, 0xEF, 0x4C, 0x71, 0x08, 0xC8, 0xF8, 0x69, 0x1C, 0xC1,
 0x7D, 0xC2, 0x1D, 0xB5, 0xF9, 0xB9, 0x27, 0x6A, 0x4D, 0xE4, 0xA6, 0x72, 0x9A, 0xC9, 0x09, 0x78,
 0x65, 0x2F, 0x8A, 0x05, 0x21, 0x0F, 0xE1, 0x24, 0x12, 0xF0, 0x82, 0x45, 0x35, 0x93, 0xDA, 0x8E,
 0x96, 0x8F, 0xDB, 0xBD, 0x36, 0xD0, 0xCE, 0x94, 0x13, 0x5C, 0xD2, 0xF1, 0x40, 0x46, 0x83, 0x38,
 0x66, 0xDD, 0xFD, 0x30, 0xBF, 0x06, 0x8B, 0x62, 0xB3, 0x25, 0xE2, 0x98, 0x22, 0x88, 0x91, 0x10,
 0x7E, 0x6E, 0x48, 0xC3, 0xA3, 0xB6, 0x1E, 0x42, 0x3A, 0x6B, 0x28, 0x54, 0xFA, 0x85, 0x3D, 0xBA,
 0x2B, 0x79, 0x0A, 0x15, 0x9B, 0x9F, 0x5E, 0xCA, 0x4E, 0xD4, 0xAC, 0xE5, 0xF3, 0x73, 0xA7, 0x57,
 0xAF, 0x58, 0xA8, 0x50, 0xF4, 0xEA, 0xD6, 0x74, 0x4F, 0xAE, 0xE9, 0xD5, 0xE7, 0xE6, 0xAD, 0xE8,
 0x2C, 0xD7, 0x75, 0x7A, 0xEB, 0x16, 0x0B, 0xF5, 0x59, 0xCB, 0x5F, 0xB0, 0x9C, 0xA9, 0x51, 0xA0,
 0x7F, 0x0C, 0xF6, 0x6F, 0x17, 0xC4, 0x49, 0xEC, 0xD8, 0x43, 0x1F, 0x2D, 0xA4, 0x76, 0x7B, 0xB7,
 0xCC, 0xBB, 0x3E, 0x5A, 0xFB, 0x60, 0xB1, 0x86, 0x3B, 0x52, 0xA1, 0x6C, 0xAA, 0x55, 0x29, 0x9D,
 0x97, 0xB2, 0x87, 0x90, 0x61, 0xBE, 0xDC, 0xFC, 0xBC, 0x95, 0xCF, 0xCD, 0x37, 0x3F, 0x5B, 0xD1,
 0x53, 0x39, 0x84, 0x3C, 0x41, 0xA2, 0x6D, 0x47, 0x14, 0x2A, 0x9E, 0x5D, 0x56, 0xF2, 0xD3, 0xAB,
 0x44, 0x11, 0x92, 0xD9, 0x23, 0x20, 0x2E, 0x89, 0xB4, 0x7C, 0xB8, 0x26, 0x77, 0x99, 0xE3, 0xA5,
 0x67, 0x4A, 0xED, 0xDE, 0xC5, 0x31, 0xFE, 0x18, 0x0D, 0x63, 0x8C, 0x80, 0xC0, 0xF7, 0x70, 0x07};

local MIXTABLE = {
 0x02, 0x03, 0x01, 0x01,
 0x01, 0x02, 0x03, 0x01,
 0x01, 0x01, 0x02, 0x03,
 0x03, 0x01, 0x01, 0x02};

local IMIXTABLE = {
 0x0E, 0x0B, 0x0D, 0x09,
 0x09, 0x0E, 0x0B, 0x0D,
 0x0D, 0x09, 0x0E, 0x0B,
 0x0B, 0x0D, 0x09, 0x0E};

local RCON = {
[0] = 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a,
0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39,
0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a,
0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8,
0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef,
0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc,
0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b,
0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3,
0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94,
0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20,
0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35,
0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f,
0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04,
0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63,
0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd,
0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d};


local GMUL = function(A,B)
	if(A == 0x01) then return B; end
	if(B == 0x01) then return A; end
	if(A == 0x00) then return 0; end
	if(B == 0x00) then return 0; end

	local LA = LTABLE[A];
	local LB = LTABLE[B];

	local sum = LA + LB;
	if (sum > 0xFF) then sum = sum - 0xFF; end

	return ETABLE[sum];
end

local byteSub = Array.substitute;

local shiftRow = Array.permute;

local mixCol = function(i,mix)
	local out = {};

	local a,b,c,d;

	a = GMUL(i[ 1],mix[ 1]);
	b = GMUL(i[ 2],mix[ 2]);
	c = GMUL(i[ 3],mix[ 3]);
	d = GMUL(i[ 4],mix[ 4]);
	out[ 1] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 1],mix[ 5]);
	b = GMUL(i[ 2],mix[ 6]);
	c = GMUL(i[ 3],mix[ 7]);
	d = GMUL(i[ 4],mix[ 8]);
	out[ 2] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 1],mix[ 9]);
	b = GMUL(i[ 2],mix[10]);
	c = GMUL(i[ 3],mix[11]);
	d = GMUL(i[ 4],mix[12]);
	out[ 3] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 1],mix[13]);
	b = GMUL(i[ 2],mix[14]);
	c = GMUL(i[ 3],mix[15]);
	d = GMUL(i[ 4],mix[16]);
	out[ 4] = XOR(XOR(a,b),XOR(c,d));


	a = GMUL(i[ 5],mix[ 1]);
	b = GMUL(i[ 6],mix[ 2]);
	c = GMUL(i[ 7],mix[ 3]);
	d = GMUL(i[ 8],mix[ 4]);
	out[ 5] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 5],mix[ 5]);
	b = GMUL(i[ 6],mix[ 6]);
	c = GMUL(i[ 7],mix[ 7]);
	d = GMUL(i[ 8],mix[ 8]);
	out[ 6] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 5],mix[ 9]);
	b = GMUL(i[ 6],mix[10]);
	c = GMUL(i[ 7],mix[11]);
	d = GMUL(i[ 8],mix[12]);
	out[ 7] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 5],mix[13]);
	b = GMUL(i[ 6],mix[14]);
	c = GMUL(i[ 7],mix[15]);
	d = GMUL(i[ 8],mix[16]);
	out[ 8] = XOR(XOR(a,b),XOR(c,d));


	a = GMUL(i[ 9],mix[ 1]);
	b = GMUL(i[10],mix[ 2]);
	c = GMUL(i[11],mix[ 3]);
	d = GMUL(i[12],mix[ 4]);
	out[ 9] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 9],mix[ 5]);
	b = GMUL(i[10],mix[ 6]);
	c = GMUL(i[11],mix[ 7]);
	d = GMUL(i[12],mix[ 8]);
	out[10] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 9],mix[ 9]);
	b = GMUL(i[10],mix[10]);
	c = GMUL(i[11],mix[11]);
	d = GMUL(i[12],mix[12]);
	out[11] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 9],mix[13]);
	b = GMUL(i[10],mix[14]);
	c = GMUL(i[11],mix[15]);
	d = GMUL(i[12],mix[16]);
	out[12] = XOR(XOR(a,b),XOR(c,d));


	a = GMUL(i[13],mix[ 1]);
	b = GMUL(i[14],mix[ 2]);
	c = GMUL(i[15],mix[ 3]);
	d = GMUL(i[16],mix[ 4]);
	out[13] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[13],mix[ 5]);
	b = GMUL(i[14],mix[ 6]);
	c = GMUL(i[15],mix[ 7]);
	d = GMUL(i[16],mix[ 8]);
	out[14] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[13],mix[ 9]);
	b = GMUL(i[14],mix[10]);
	c = GMUL(i[15],mix[11]);
	d = GMUL(i[16],mix[12]);
	out[15] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[13],mix[13]);
	b = GMUL(i[14],mix[14]);
	c = GMUL(i[15],mix[15]);
	d = GMUL(i[16],mix[16]);
	out[16] = XOR(XOR(a,b),XOR(c,d));

	return out;
end

local keyRound = function(key,round)
	local i=(round-1)*32;
	local out=key;

	out[33+i] = XOR(key[ 1+i],XOR(SBOX[key[30+i]],RCON[round]));
	out[34+i] = XOR(key[ 2+i],SBOX[key[31+i]]);
	out[35+i] = XOR(key[ 3+i],SBOX[key[32+i]]);
	out[36+i] = XOR(key[ 4+i],SBOX[key[29+i]]);

	out[37+i] = XOR(out[33+i],key[ 5+i]);
	out[38+i] = XOR(out[34+i],key[ 6+i]);
	out[39+i] = XOR(out[35+i],key[ 7+i]);
	out[40+i] = XOR(out[36+i],key[ 8+i]);

	out[41+i] = XOR(out[37+i],key[ 9+i]);
	out[42+i] = XOR(out[38+i],key[10+i]);
	out[43+i] = XOR(out[39+i],key[11+i]);
	out[44+i] = XOR(out[40+i],key[12+i]);

	out[45+i] = XOR(out[41+i],key[13+i]);
	out[46+i] = XOR(out[42+i],key[14+i]);
	out[47+i] = XOR(out[43+i],key[15+i]);
	out[48+i] = XOR(out[44+i],key[16+i]);


	out[49+i] = XOR(SBOX[out[45+i]],key[17+i]);
	out[50+i] = XOR(SBOX[out[46+i]],key[18+i]);
	out[51+i] = XOR(SBOX[out[47+i]],key[19+i]);
	out[52+i] = XOR(SBOX[out[48+i]],key[20+i]);

	out[53+i] = XOR(out[49+i],key[21+i]);
	out[54+i] = XOR(out[50+i],key[22+i]);
	out[55+i] = XOR(out[51+i],key[23+i]);
	out[56+i] = XOR(out[52+i],key[24+i]);

	out[57+i] = XOR(out[53+i],key[25+i]);
	out[58+i] = XOR(out[54+i],key[26+i]);
	out[59+i] = XOR(out[55+i],key[27+i]);
	out[60+i] = XOR(out[56+i],key[28+i]);

	out[61+i] = XOR(out[57+i],key[29+i]);
	out[62+i] = XOR(out[58+i],key[30+i]);
	out[63+i] = XOR(out[59+i],key[31+i]);
	out[64+i] = XOR(out[60+i],key[32+i]);

	return out;
end

local keyExpand = function(key)
	local bytes = Array.copy(key);

	for i=1,7 do
		keyRound(bytes,i);
	end

	local keys = {};

	keys[ 1] = Array.slice(bytes,1,16);
	keys[ 2] = Array.slice(bytes,17,32);
	keys[ 3] = Array.slice(bytes,33,48);
	keys[ 4] = Array.slice(bytes,49,64);
	keys[ 5] = Array.slice(bytes,65,80);
	keys[ 6] = Array.slice(bytes,81,96);
	keys[ 7] = Array.slice(bytes,97,112);
	keys[ 8] = Array.slice(bytes,113,128);
	keys[ 9] = Array.slice(bytes,129,144);
	keys[10] = Array.slice(bytes,145,160);
	keys[11] = Array.slice(bytes,161,176);
	keys[12] = Array.slice(bytes,177,192);
	keys[13] = Array.slice(bytes,193,208);
	keys[14] = Array.slice(bytes,209,224);
	keys[15] = Array.slice(bytes,225,240);

	return keys;

end

local addKey = Array.XOR;



local AES = {};

AES.blockSize = 16;

AES.encrypt = function(key,block)

	local key = keyExpand(key);

	--round 0
	block = addKey(block,key[1]);

	--round 1
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[2]);

	--round 2
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[3]);

	--round 3
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[4]);

	--round 4
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[5]);

	--round 5
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[6]);

	--round 6
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[7]);

	--round 7
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[8]);

	--round 8
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[9]);

	--round 9
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[10]);

	--round 10
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[11]);

	--round 11
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[12]);

	--round 12
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[13]);

	--round 13
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[14]);

	--round 14
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = addKey(block,key[15]);

	return block;

end

AES.decrypt = function(key,block)

	local key = keyExpand(key);

	--round 0
	block = addKey(block,key[15]);

	--round 1
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[14]);
	block = mixCol(block,IMIXTABLE);

	--round 2
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[13]);
	block = mixCol(block,IMIXTABLE);

	--round 3
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[12]);
	block = mixCol(block,IMIXTABLE);

	--round 4
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[11]);
	block = mixCol(block,IMIXTABLE);

	--round 5
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[10]);
	block = mixCol(block,IMIXTABLE);

	--round 6
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[9]);
	block = mixCol(block,IMIXTABLE);

	--round 7
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[8]);
	block = mixCol(block,IMIXTABLE);

	--round 8
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[7]);
	block = mixCol(block,IMIXTABLE);

	--round 9
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[6]);
	block = mixCol(block,IMIXTABLE);

	--round 10
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[5]);
	block = mixCol(block,IMIXTABLE);

	--round 11
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[4]);
	block = mixCol(block,IMIXTABLE);

	--round 12
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[3]);
	block = mixCol(block,IMIXTABLE);

	--round 13
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[2]);
	block = mixCol(block,IMIXTABLE);

	--round 14
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[1]);

	return block;
end

return AES;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.cipher.aes192"],"module already exists")sources["lockbox.cipher.aes192"]=([===[-- <pack lockbox.cipher.aes192> --
local Stream = require("lockbox.util.stream");
local Array = require("lockbox.util.array");

local Bit = require("lockbox.util.bit");
local Math = require("math");


local AND = Bit.band;
local OR  = Bit.bor;
local NOT = Bit.bnot;
local XOR = Bit.bxor;
local LROT = Bit.lrotate;
local RROT = Bit.rrotate;
local LSHIFT = Bit.lshift;
local RSHIFT = Bit.rshift;

local SBOX = {
 [0]=0x63, 0x7C, 0x77, 0x7B, 0xF2, 0x6B, 0x6F, 0xC5, 0x30, 0x01, 0x67, 0x2B, 0xFE, 0xD7, 0xAB, 0x76,
 0xCA, 0x82, 0xC9, 0x7D, 0xFA, 0x59, 0x47, 0xF0, 0xAD, 0xD4, 0xA2, 0xAF, 0x9C, 0xA4, 0x72, 0xC0,
 0xB7, 0xFD, 0x93, 0x26, 0x36, 0x3F, 0xF7, 0xCC, 0x34, 0xA5, 0xE5, 0xF1, 0x71, 0xD8, 0x31, 0x15,
 0x04, 0xC7, 0x23, 0xC3, 0x18, 0x96, 0x05, 0x9A, 0x07, 0x12, 0x80, 0xE2, 0xEB, 0x27, 0xB2, 0x75,
 0x09, 0x83, 0x2C, 0x1A, 0x1B, 0x6E, 0x5A, 0xA0, 0x52, 0x3B, 0xD6, 0xB3, 0x29, 0xE3, 0x2F, 0x84,
 0x53, 0xD1, 0x00, 0xED, 0x20, 0xFC, 0xB1, 0x5B, 0x6A, 0xCB, 0xBE, 0x39, 0x4A, 0x4C, 0x58, 0xCF,
 0xD0, 0xEF, 0xAA, 0xFB, 0x43, 0x4D, 0x33, 0x85, 0x45, 0xF9, 0x02, 0x7F, 0x50, 0x3C, 0x9F, 0xA8,
 0x51, 0xA3, 0x40, 0x8F, 0x92, 0x9D, 0x38, 0xF5, 0xBC, 0xB6, 0xDA, 0x21, 0x10, 0xFF, 0xF3, 0xD2,
 0xCD, 0x0C, 0x13, 0xEC, 0x5F, 0x97, 0x44, 0x17, 0xC4, 0xA7, 0x7E, 0x3D, 0x64, 0x5D, 0x19, 0x73,
 0x60, 0x81, 0x4F, 0xDC, 0x22, 0x2A, 0x90, 0x88, 0x46, 0xEE, 0xB8, 0x14, 0xDE, 0x5E, 0x0B, 0xDB,
 0xE0, 0x32, 0x3A, 0x0A, 0x49, 0x06, 0x24, 0x5C, 0xC2, 0xD3, 0xAC, 0x62, 0x91, 0x95, 0xE4, 0x79,
 0xE7, 0xC8, 0x37, 0x6D, 0x8D, 0xD5, 0x4E, 0xA9, 0x6C, 0x56, 0xF4, 0xEA, 0x65, 0x7A, 0xAE, 0x08,
 0xBA, 0x78, 0x25, 0x2E, 0x1C, 0xA6, 0xB4, 0xC6, 0xE8, 0xDD, 0x74, 0x1F, 0x4B, 0xBD, 0x8B, 0x8A,
 0x70, 0x3E, 0xB5, 0x66, 0x48, 0x03, 0xF6, 0x0E, 0x61, 0x35, 0x57, 0xB9, 0x86, 0xC1, 0x1D, 0x9E,
 0xE1, 0xF8, 0x98, 0x11, 0x69, 0xD9, 0x8E, 0x94, 0x9B, 0x1E, 0x87, 0xE9, 0xCE, 0x55, 0x28, 0xDF,
 0x8C, 0xA1, 0x89, 0x0D, 0xBF, 0xE6, 0x42, 0x68, 0x41, 0x99, 0x2D, 0x0F, 0xB0, 0x54, 0xBB, 0x16};

local ISBOX = {
 [0]=0x52, 0x09, 0x6A, 0xD5, 0x30, 0x36, 0xA5, 0x38, 0xBF, 0x40, 0xA3, 0x9E, 0x81, 0xF3, 0xD7, 0xFB,
 0x7C, 0xE3, 0x39, 0x82, 0x9B, 0x2F, 0xFF, 0x87, 0x34, 0x8E, 0x43, 0x44, 0xC4, 0xDE, 0xE9, 0xCB,
 0x54, 0x7B, 0x94, 0x32, 0xA6, 0xC2, 0x23, 0x3D, 0xEE, 0x4C, 0x95, 0x0B, 0x42, 0xFA, 0xC3, 0x4E,
 0x08, 0x2E, 0xA1, 0x66, 0x28, 0xD9, 0x24, 0xB2, 0x76, 0x5B, 0xA2, 0x49, 0x6D, 0x8B, 0xD1, 0x25,
 0x72, 0xF8, 0xF6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xD4, 0xA4, 0x5C, 0xCC, 0x5D, 0x65, 0xB6, 0x92,
 0x6C, 0x70, 0x48, 0x50, 0xFD, 0xED, 0xB9, 0xDA, 0x5E, 0x15, 0x46, 0x57, 0xA7, 0x8D, 0x9D, 0x84,
 0x90, 0xD8, 0xAB, 0x00, 0x8C, 0xBC, 0xD3, 0x0A, 0xF7, 0xE4, 0x58, 0x05, 0xB8, 0xB3, 0x45, 0x06,
 0xD0, 0x2C, 0x1E, 0x8F, 0xCA, 0x3F, 0x0F, 0x02, 0xC1, 0xAF, 0xBD, 0x03, 0x01, 0x13, 0x8A, 0x6B,
 0x3A, 0x91, 0x11, 0x41, 0x4F, 0x67, 0xDC, 0xEA, 0x97, 0xF2, 0xCF, 0xCE, 0xF0, 0xB4, 0xE6, 0x73,
 0x96, 0xAC, 0x74, 0x22, 0xE7, 0xAD, 0x35, 0x85, 0xE2, 0xF9, 0x37, 0xE8, 0x1C, 0x75, 0xDF, 0x6E,
 0x47, 0xF1, 0x1A, 0x71, 0x1D, 0x29, 0xC5, 0x89, 0x6F, 0xB7, 0x62, 0x0E, 0xAA, 0x18, 0xBE, 0x1B,
 0xFC, 0x56, 0x3E, 0x4B, 0xC6, 0xD2, 0x79, 0x20, 0x9A, 0xDB, 0xC0, 0xFE, 0x78, 0xCD, 0x5A, 0xF4,
 0x1F, 0xDD, 0xA8, 0x33, 0x88, 0x07, 0xC7, 0x31, 0xB1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xEC, 0x5F,
 0x60, 0x51, 0x7F, 0xA9, 0x19, 0xB5, 0x4A, 0x0D, 0x2D, 0xE5, 0x7A, 0x9F, 0x93, 0xC9, 0x9C, 0xEF,
 0xA0, 0xE0, 0x3B, 0x4D, 0xAE, 0x2A, 0xF5, 0xB0, 0xC8, 0xEB, 0xBB, 0x3C, 0x83, 0x53, 0x99, 0x61,
 0x17, 0x2B, 0x04, 0x7E, 0xBA, 0x77, 0xD6, 0x26, 0xE1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0C, 0x7D};

local ROW_SHIFT =  {  1,  6, 11, 16,  5, 10, 15,  4,  9, 14,  3,  8, 13,  2,  7, 12,};
local IROW_SHIFT = {  1, 14, 11,  8,  5,  2, 15, 12,  9,  6,  3, 16, 13, 10,  7,  4,};

local ETABLE = {
 [0]=0x01, 0x03, 0x05, 0x0F, 0x11, 0x33, 0x55, 0xFF, 0x1A, 0x2E, 0x72, 0x96, 0xA1, 0xF8, 0x13, 0x35,
 0x5F, 0xE1, 0x38, 0x48, 0xD8, 0x73, 0x95, 0xA4, 0xF7, 0x02, 0x06, 0x0A, 0x1E, 0x22, 0x66, 0xAA,
 0xE5, 0x34, 0x5C, 0xE4, 0x37, 0x59, 0xEB, 0x26, 0x6A, 0xBE, 0xD9, 0x70, 0x90, 0xAB, 0xE6, 0x31,
 0x53, 0xF5, 0x04, 0x0C, 0x14, 0x3C, 0x44, 0xCC, 0x4F, 0xD1, 0x68, 0xB8, 0xD3, 0x6E, 0xB2, 0xCD,
 0x4C, 0xD4, 0x67, 0xA9, 0xE0, 0x3B, 0x4D, 0xD7, 0x62, 0xA6, 0xF1, 0x08, 0x18, 0x28, 0x78, 0x88,
 0x83, 0x9E, 0xB9, 0xD0, 0x6B, 0xBD, 0xDC, 0x7F, 0x81, 0x98, 0xB3, 0xCE, 0x49, 0xDB, 0x76, 0x9A,
 0xB5, 0xC4, 0x57, 0xF9, 0x10, 0x30, 0x50, 0xF0, 0x0B, 0x1D, 0x27, 0x69, 0xBB, 0xD6, 0x61, 0xA3,
 0xFE, 0x19, 0x2B, 0x7D, 0x87, 0x92, 0xAD, 0xEC, 0x2F, 0x71, 0x93, 0xAE, 0xE9, 0x20, 0x60, 0xA0,
 0xFB, 0x16, 0x3A, 0x4E, 0xD2, 0x6D, 0xB7, 0xC2, 0x5D, 0xE7, 0x32, 0x56, 0xFA, 0x15, 0x3F, 0x41,
 0xC3, 0x5E, 0xE2, 0x3D, 0x47, 0xC9, 0x40, 0xC0, 0x5B, 0xED, 0x2C, 0x74, 0x9C, 0xBF, 0xDA, 0x75,
 0x9F, 0xBA, 0xD5, 0x64, 0xAC, 0xEF, 0x2A, 0x7E, 0x82, 0x9D, 0xBC, 0xDF, 0x7A, 0x8E, 0x89, 0x80,
 0x9B, 0xB6, 0xC1, 0x58, 0xE8, 0x23, 0x65, 0xAF, 0xEA, 0x25, 0x6F, 0xB1, 0xC8, 0x43, 0xC5, 0x54,
 0xFC, 0x1F, 0x21, 0x63, 0xA5, 0xF4, 0x07, 0x09, 0x1B, 0x2D, 0x77, 0x99, 0xB0, 0xCB, 0x46, 0xCA,
 0x45, 0xCF, 0x4A, 0xDE, 0x79, 0x8B, 0x86, 0x91, 0xA8, 0xE3, 0x3E, 0x42, 0xC6, 0x51, 0xF3, 0x0E,
 0x12, 0x36, 0x5A, 0xEE, 0x29, 0x7B, 0x8D, 0x8C, 0x8F, 0x8A, 0x85, 0x94, 0xA7, 0xF2, 0x0D, 0x17,
 0x39, 0x4B, 0xDD, 0x7C, 0x84, 0x97, 0xA2, 0xFD, 0x1C, 0x24, 0x6C, 0xB4, 0xC7, 0x52, 0xF6, 0x01};

local LTABLE = {
 [0]=0x00, 0x00, 0x19, 0x01, 0x32, 0x02, 0x1A, 0xC6, 0x4B, 0xC7, 0x1B, 0x68, 0x33, 0xEE, 0xDF, 0x03,
 0x64, 0x04, 0xE0, 0x0E, 0x34, 0x8D, 0x81, 0xEF, 0x4C, 0x71, 0x08, 0xC8, 0xF8, 0x69, 0x1C, 0xC1,
 0x7D, 0xC2, 0x1D, 0xB5, 0xF9, 0xB9, 0x27, 0x6A, 0x4D, 0xE4, 0xA6, 0x72, 0x9A, 0xC9, 0x09, 0x78,
 0x65, 0x2F, 0x8A, 0x05, 0x21, 0x0F, 0xE1, 0x24, 0x12, 0xF0, 0x82, 0x45, 0x35, 0x93, 0xDA, 0x8E,
 0x96, 0x8F, 0xDB, 0xBD, 0x36, 0xD0, 0xCE, 0x94, 0x13, 0x5C, 0xD2, 0xF1, 0x40, 0x46, 0x83, 0x38,
 0x66, 0xDD, 0xFD, 0x30, 0xBF, 0x06, 0x8B, 0x62, 0xB3, 0x25, 0xE2, 0x98, 0x22, 0x88, 0x91, 0x10,
 0x7E, 0x6E, 0x48, 0xC3, 0xA3, 0xB6, 0x1E, 0x42, 0x3A, 0x6B, 0x28, 0x54, 0xFA, 0x85, 0x3D, 0xBA,
 0x2B, 0x79, 0x0A, 0x15, 0x9B, 0x9F, 0x5E, 0xCA, 0x4E, 0xD4, 0xAC, 0xE5, 0xF3, 0x73, 0xA7, 0x57,
 0xAF, 0x58, 0xA8, 0x50, 0xF4, 0xEA, 0xD6, 0x74, 0x4F, 0xAE, 0xE9, 0xD5, 0xE7, 0xE6, 0xAD, 0xE8,
 0x2C, 0xD7, 0x75, 0x7A, 0xEB, 0x16, 0x0B, 0xF5, 0x59, 0xCB, 0x5F, 0xB0, 0x9C, 0xA9, 0x51, 0xA0,
 0x7F, 0x0C, 0xF6, 0x6F, 0x17, 0xC4, 0x49, 0xEC, 0xD8, 0x43, 0x1F, 0x2D, 0xA4, 0x76, 0x7B, 0xB7,
 0xCC, 0xBB, 0x3E, 0x5A, 0xFB, 0x60, 0xB1, 0x86, 0x3B, 0x52, 0xA1, 0x6C, 0xAA, 0x55, 0x29, 0x9D,
 0x97, 0xB2, 0x87, 0x90, 0x61, 0xBE, 0xDC, 0xFC, 0xBC, 0x95, 0xCF, 0xCD, 0x37, 0x3F, 0x5B, 0xD1,
 0x53, 0x39, 0x84, 0x3C, 0x41, 0xA2, 0x6D, 0x47, 0x14, 0x2A, 0x9E, 0x5D, 0x56, 0xF2, 0xD3, 0xAB,
 0x44, 0x11, 0x92, 0xD9, 0x23, 0x20, 0x2E, 0x89, 0xB4, 0x7C, 0xB8, 0x26, 0x77, 0x99, 0xE3, 0xA5,
 0x67, 0x4A, 0xED, 0xDE, 0xC5, 0x31, 0xFE, 0x18, 0x0D, 0x63, 0x8C, 0x80, 0xC0, 0xF7, 0x70, 0x07};

local MIXTABLE = {
 0x02, 0x03, 0x01, 0x01,
 0x01, 0x02, 0x03, 0x01,
 0x01, 0x01, 0x02, 0x03,
 0x03, 0x01, 0x01, 0x02};

local IMIXTABLE = {
 0x0E, 0x0B, 0x0D, 0x09,
 0x09, 0x0E, 0x0B, 0x0D,
 0x0D, 0x09, 0x0E, 0x0B,
 0x0B, 0x0D, 0x09, 0x0E};

local RCON = {
[0] = 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a,
0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39,
0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a,
0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8,
0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef,
0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc,
0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b,
0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3,
0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94,
0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20,
0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35,
0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f,
0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04,
0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63,
0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd,
0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d};


local GMUL = function(A,B)
	if(A == 0x01) then return B; end
	if(B == 0x01) then return A; end
	if(A == 0x00) then return 0; end
	if(B == 0x00) then return 0; end

	local LA = LTABLE[A];
	local LB = LTABLE[B];

	local sum = LA + LB;
	if (sum > 0xFF) then sum = sum - 0xFF; end

	return ETABLE[sum];
end

local byteSub = Array.substitute;

local shiftRow = Array.permute;

local mixCol = function(i,mix)
	local out = {};

	local a,b,c,d;

	a = GMUL(i[ 1],mix[ 1]);
	b = GMUL(i[ 2],mix[ 2]);
	c = GMUL(i[ 3],mix[ 3]);
	d = GMUL(i[ 4],mix[ 4]);
	out[ 1] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 1],mix[ 5]);
	b = GMUL(i[ 2],mix[ 6]);
	c = GMUL(i[ 3],mix[ 7]);
	d = GMUL(i[ 4],mix[ 8]);
	out[ 2] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 1],mix[ 9]);
	b = GMUL(i[ 2],mix[10]);
	c = GMUL(i[ 3],mix[11]);
	d = GMUL(i[ 4],mix[12]);
	out[ 3] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 1],mix[13]);
	b = GMUL(i[ 2],mix[14]);
	c = GMUL(i[ 3],mix[15]);
	d = GMUL(i[ 4],mix[16]);
	out[ 4] = XOR(XOR(a,b),XOR(c,d));


	a = GMUL(i[ 5],mix[ 1]);
	b = GMUL(i[ 6],mix[ 2]);
	c = GMUL(i[ 7],mix[ 3]);
	d = GMUL(i[ 8],mix[ 4]);
	out[ 5] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 5],mix[ 5]);
	b = GMUL(i[ 6],mix[ 6]);
	c = GMUL(i[ 7],mix[ 7]);
	d = GMUL(i[ 8],mix[ 8]);
	out[ 6] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 5],mix[ 9]);
	b = GMUL(i[ 6],mix[10]);
	c = GMUL(i[ 7],mix[11]);
	d = GMUL(i[ 8],mix[12]);
	out[ 7] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 5],mix[13]);
	b = GMUL(i[ 6],mix[14]);
	c = GMUL(i[ 7],mix[15]);
	d = GMUL(i[ 8],mix[16]);
	out[ 8] = XOR(XOR(a,b),XOR(c,d));


	a = GMUL(i[ 9],mix[ 1]);
	b = GMUL(i[10],mix[ 2]);
	c = GMUL(i[11],mix[ 3]);
	d = GMUL(i[12],mix[ 4]);
	out[ 9] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 9],mix[ 5]);
	b = GMUL(i[10],mix[ 6]);
	c = GMUL(i[11],mix[ 7]);
	d = GMUL(i[12],mix[ 8]);
	out[10] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 9],mix[ 9]);
	b = GMUL(i[10],mix[10]);
	c = GMUL(i[11],mix[11]);
	d = GMUL(i[12],mix[12]);
	out[11] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 9],mix[13]);
	b = GMUL(i[10],mix[14]);
	c = GMUL(i[11],mix[15]);
	d = GMUL(i[12],mix[16]);
	out[12] = XOR(XOR(a,b),XOR(c,d));


	a = GMUL(i[13],mix[ 1]);
	b = GMUL(i[14],mix[ 2]);
	c = GMUL(i[15],mix[ 3]);
	d = GMUL(i[16],mix[ 4]);
	out[13] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[13],mix[ 5]);
	b = GMUL(i[14],mix[ 6]);
	c = GMUL(i[15],mix[ 7]);
	d = GMUL(i[16],mix[ 8]);
	out[14] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[13],mix[ 9]);
	b = GMUL(i[14],mix[10]);
	c = GMUL(i[15],mix[11]);
	d = GMUL(i[16],mix[12]);
	out[15] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[13],mix[13]);
	b = GMUL(i[14],mix[14]);
	c = GMUL(i[15],mix[15]);
	d = GMUL(i[16],mix[16]);
	out[16] = XOR(XOR(a,b),XOR(c,d));

	return out;
end

local keyRound = function(key,round)
	local i=(round-1)*24;
	local out=key;

	out[25+i] = XOR(key[ 1+i],XOR(SBOX[key[22+i]],RCON[round]));
	out[26+i] = XOR(key[ 2+i],SBOX[key[23+i]]);
	out[27+i] = XOR(key[ 3+i],SBOX[key[24+i]]);
	out[28+i] = XOR(key[ 4+i],SBOX[key[21+i]]);

	out[29+i] = XOR(out[25+i],key[ 5+i]);
	out[30+i] = XOR(out[26+i],key[ 6+i]);
	out[31+i] = XOR(out[27+i],key[ 7+i]);
	out[32+i] = XOR(out[28+i],key[ 8+i]);

	out[33+i] = XOR(out[29+i],key[ 9+i]);
	out[34+i] = XOR(out[30+i],key[10+i]);
	out[35+i] = XOR(out[31+i],key[11+i]);
	out[36+i] = XOR(out[32+i],key[12+i]);

	out[37+i] = XOR(out[33+i],key[13+i]);
	out[38+i] = XOR(out[34+i],key[14+i]);
	out[39+i] = XOR(out[35+i],key[15+i]);
	out[40+i] = XOR(out[36+i],key[16+i]);

	out[41+i] = XOR(out[37+i],key[17+i]);
	out[42+i] = XOR(out[38+i],key[18+i]);
	out[43+i] = XOR(out[39+i],key[19+i]);
	out[44+i] = XOR(out[40+i],key[20+i]);

	out[45+i] = XOR(out[41+i],key[21+i]);
	out[46+i] = XOR(out[42+i],key[22+i]);
	out[47+i] = XOR(out[43+i],key[23+i]);
	out[48+i] = XOR(out[44+i],key[24+i]);

	return out;
end

local keyExpand = function(key)
	local bytes = Array.copy(key);

	for i=1,8 do
		keyRound(bytes,i);
	end

	local keys = {};

	keys[ 1] = Array.slice(bytes,1,16);
	keys[ 2] = Array.slice(bytes,17,32);
	keys[ 3] = Array.slice(bytes,33,48);
	keys[ 4] = Array.slice(bytes,49,64);
	keys[ 5] = Array.slice(bytes,65,80);
	keys[ 6] = Array.slice(bytes,81,96);
	keys[ 7] = Array.slice(bytes,97,112);
	keys[ 8] = Array.slice(bytes,113,128);
	keys[ 9] = Array.slice(bytes,129,144);
	keys[10] = Array.slice(bytes,145,160);
	keys[11] = Array.slice(bytes,161,176);
	keys[12] = Array.slice(bytes,177,192);
	keys[13] = Array.slice(bytes,193,208);

	return keys;

end

local addKey = Array.XOR;



local AES = {};

AES.blockSize = 16;

AES.encrypt = function(key,block)

	local key = keyExpand(key);

	--round 0
	block = addKey(block,key[1]);

	--round 1
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[2]);

	--round 2
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[3]);

	--round 3
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[4]);

	--round 4
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[5]);

	--round 5
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[6]);

	--round 6
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[7]);

	--round 7
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[8]);

	--round 8
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[9]);

	--round 9
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[10]);

	--round 10
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[11]);

	--round 11
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[12]);

	--round 12
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = addKey(block,key[13]);

	return block;

end

AES.decrypt = function(key,block)

	local key = keyExpand(key);

	--round 0
	block = addKey(block,key[13]);

	--round 1
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[12]);
	block = mixCol(block,IMIXTABLE);

	--round 2
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[11]);
	block = mixCol(block,IMIXTABLE);

	--round 3
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[10]);
	block = mixCol(block,IMIXTABLE);

	--round 4
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[9]);
	block = mixCol(block,IMIXTABLE);

	--round 5
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[8]);
	block = mixCol(block,IMIXTABLE);

	--round 6
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[7]);
	block = mixCol(block,IMIXTABLE);

	--round 7
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[6]);
	block = mixCol(block,IMIXTABLE);

	--round 8
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[5]);
	block = mixCol(block,IMIXTABLE);

	--round 9
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[4]);
	block = mixCol(block,IMIXTABLE);

	--round 10
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[3]);
	block = mixCol(block,IMIXTABLE);

	--round 11
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[2]);
	block = mixCol(block,IMIXTABLE);

	--round 12
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[1]);

	return block;
end

return AES;
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lockbox.cipher.aes128"],"module already exists")sources["lockbox.cipher.aes128"]=([===[-- <pack lockbox.cipher.aes128> --
local Stream = require("lockbox.util.stream");
local Array = require("lockbox.util.array");

local Bit = require("lockbox.util.bit");
local Math = require("math");


local AND = Bit.band;
local OR  = Bit.bor;
local NOT = Bit.bnot;
local XOR = Bit.bxor;
local LROT = Bit.lrotate;
local RROT = Bit.rrotate;
local LSHIFT = Bit.lshift;
local RSHIFT = Bit.rshift;

local SBOX = {
 [0]=0x63, 0x7C, 0x77, 0x7B, 0xF2, 0x6B, 0x6F, 0xC5, 0x30, 0x01, 0x67, 0x2B, 0xFE, 0xD7, 0xAB, 0x76,
 0xCA, 0x82, 0xC9, 0x7D, 0xFA, 0x59, 0x47, 0xF0, 0xAD, 0xD4, 0xA2, 0xAF, 0x9C, 0xA4, 0x72, 0xC0,
 0xB7, 0xFD, 0x93, 0x26, 0x36, 0x3F, 0xF7, 0xCC, 0x34, 0xA5, 0xE5, 0xF1, 0x71, 0xD8, 0x31, 0x15,
 0x04, 0xC7, 0x23, 0xC3, 0x18, 0x96, 0x05, 0x9A, 0x07, 0x12, 0x80, 0xE2, 0xEB, 0x27, 0xB2, 0x75,
 0x09, 0x83, 0x2C, 0x1A, 0x1B, 0x6E, 0x5A, 0xA0, 0x52, 0x3B, 0xD6, 0xB3, 0x29, 0xE3, 0x2F, 0x84,
 0x53, 0xD1, 0x00, 0xED, 0x20, 0xFC, 0xB1, 0x5B, 0x6A, 0xCB, 0xBE, 0x39, 0x4A, 0x4C, 0x58, 0xCF,
 0xD0, 0xEF, 0xAA, 0xFB, 0x43, 0x4D, 0x33, 0x85, 0x45, 0xF9, 0x02, 0x7F, 0x50, 0x3C, 0x9F, 0xA8,
 0x51, 0xA3, 0x40, 0x8F, 0x92, 0x9D, 0x38, 0xF5, 0xBC, 0xB6, 0xDA, 0x21, 0x10, 0xFF, 0xF3, 0xD2,
 0xCD, 0x0C, 0x13, 0xEC, 0x5F, 0x97, 0x44, 0x17, 0xC4, 0xA7, 0x7E, 0x3D, 0x64, 0x5D, 0x19, 0x73,
 0x60, 0x81, 0x4F, 0xDC, 0x22, 0x2A, 0x90, 0x88, 0x46, 0xEE, 0xB8, 0x14, 0xDE, 0x5E, 0x0B, 0xDB,
 0xE0, 0x32, 0x3A, 0x0A, 0x49, 0x06, 0x24, 0x5C, 0xC2, 0xD3, 0xAC, 0x62, 0x91, 0x95, 0xE4, 0x79,
 0xE7, 0xC8, 0x37, 0x6D, 0x8D, 0xD5, 0x4E, 0xA9, 0x6C, 0x56, 0xF4, 0xEA, 0x65, 0x7A, 0xAE, 0x08,
 0xBA, 0x78, 0x25, 0x2E, 0x1C, 0xA6, 0xB4, 0xC6, 0xE8, 0xDD, 0x74, 0x1F, 0x4B, 0xBD, 0x8B, 0x8A,
 0x70, 0x3E, 0xB5, 0x66, 0x48, 0x03, 0xF6, 0x0E, 0x61, 0x35, 0x57, 0xB9, 0x86, 0xC1, 0x1D, 0x9E,
 0xE1, 0xF8, 0x98, 0x11, 0x69, 0xD9, 0x8E, 0x94, 0x9B, 0x1E, 0x87, 0xE9, 0xCE, 0x55, 0x28, 0xDF,
 0x8C, 0xA1, 0x89, 0x0D, 0xBF, 0xE6, 0x42, 0x68, 0x41, 0x99, 0x2D, 0x0F, 0xB0, 0x54, 0xBB, 0x16};

local ISBOX = {
 [0]=0x52, 0x09, 0x6A, 0xD5, 0x30, 0x36, 0xA5, 0x38, 0xBF, 0x40, 0xA3, 0x9E, 0x81, 0xF3, 0xD7, 0xFB,
 0x7C, 0xE3, 0x39, 0x82, 0x9B, 0x2F, 0xFF, 0x87, 0x34, 0x8E, 0x43, 0x44, 0xC4, 0xDE, 0xE9, 0xCB,
 0x54, 0x7B, 0x94, 0x32, 0xA6, 0xC2, 0x23, 0x3D, 0xEE, 0x4C, 0x95, 0x0B, 0x42, 0xFA, 0xC3, 0x4E,
 0x08, 0x2E, 0xA1, 0x66, 0x28, 0xD9, 0x24, 0xB2, 0x76, 0x5B, 0xA2, 0x49, 0x6D, 0x8B, 0xD1, 0x25,
 0x72, 0xF8, 0xF6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xD4, 0xA4, 0x5C, 0xCC, 0x5D, 0x65, 0xB6, 0x92,
 0x6C, 0x70, 0x48, 0x50, 0xFD, 0xED, 0xB9, 0xDA, 0x5E, 0x15, 0x46, 0x57, 0xA7, 0x8D, 0x9D, 0x84,
 0x90, 0xD8, 0xAB, 0x00, 0x8C, 0xBC, 0xD3, 0x0A, 0xF7, 0xE4, 0x58, 0x05, 0xB8, 0xB3, 0x45, 0x06,
 0xD0, 0x2C, 0x1E, 0x8F, 0xCA, 0x3F, 0x0F, 0x02, 0xC1, 0xAF, 0xBD, 0x03, 0x01, 0x13, 0x8A, 0x6B,
 0x3A, 0x91, 0x11, 0x41, 0x4F, 0x67, 0xDC, 0xEA, 0x97, 0xF2, 0xCF, 0xCE, 0xF0, 0xB4, 0xE6, 0x73,
 0x96, 0xAC, 0x74, 0x22, 0xE7, 0xAD, 0x35, 0x85, 0xE2, 0xF9, 0x37, 0xE8, 0x1C, 0x75, 0xDF, 0x6E,
 0x47, 0xF1, 0x1A, 0x71, 0x1D, 0x29, 0xC5, 0x89, 0x6F, 0xB7, 0x62, 0x0E, 0xAA, 0x18, 0xBE, 0x1B,
 0xFC, 0x56, 0x3E, 0x4B, 0xC6, 0xD2, 0x79, 0x20, 0x9A, 0xDB, 0xC0, 0xFE, 0x78, 0xCD, 0x5A, 0xF4,
 0x1F, 0xDD, 0xA8, 0x33, 0x88, 0x07, 0xC7, 0x31, 0xB1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xEC, 0x5F,
 0x60, 0x51, 0x7F, 0xA9, 0x19, 0xB5, 0x4A, 0x0D, 0x2D, 0xE5, 0x7A, 0x9F, 0x93, 0xC9, 0x9C, 0xEF,
 0xA0, 0xE0, 0x3B, 0x4D, 0xAE, 0x2A, 0xF5, 0xB0, 0xC8, 0xEB, 0xBB, 0x3C, 0x83, 0x53, 0x99, 0x61,
 0x17, 0x2B, 0x04, 0x7E, 0xBA, 0x77, 0xD6, 0x26, 0xE1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0C, 0x7D};

local ROW_SHIFT =  {  1,  6, 11, 16,  5, 10, 15,  4,  9, 14,  3,  8, 13,  2,  7, 12,};
local IROW_SHIFT = {  1, 14, 11,  8,  5,  2, 15, 12,  9,  6,  3, 16, 13, 10,  7,  4,};

local ETABLE = {
 [0]=0x01, 0x03, 0x05, 0x0F, 0x11, 0x33, 0x55, 0xFF, 0x1A, 0x2E, 0x72, 0x96, 0xA1, 0xF8, 0x13, 0x35,
 0x5F, 0xE1, 0x38, 0x48, 0xD8, 0x73, 0x95, 0xA4, 0xF7, 0x02, 0x06, 0x0A, 0x1E, 0x22, 0x66, 0xAA,
 0xE5, 0x34, 0x5C, 0xE4, 0x37, 0x59, 0xEB, 0x26, 0x6A, 0xBE, 0xD9, 0x70, 0x90, 0xAB, 0xE6, 0x31,
 0x53, 0xF5, 0x04, 0x0C, 0x14, 0x3C, 0x44, 0xCC, 0x4F, 0xD1, 0x68, 0xB8, 0xD3, 0x6E, 0xB2, 0xCD,
 0x4C, 0xD4, 0x67, 0xA9, 0xE0, 0x3B, 0x4D, 0xD7, 0x62, 0xA6, 0xF1, 0x08, 0x18, 0x28, 0x78, 0x88,
 0x83, 0x9E, 0xB9, 0xD0, 0x6B, 0xBD, 0xDC, 0x7F, 0x81, 0x98, 0xB3, 0xCE, 0x49, 0xDB, 0x76, 0x9A,
 0xB5, 0xC4, 0x57, 0xF9, 0x10, 0x30, 0x50, 0xF0, 0x0B, 0x1D, 0x27, 0x69, 0xBB, 0xD6, 0x61, 0xA3,
 0xFE, 0x19, 0x2B, 0x7D, 0x87, 0x92, 0xAD, 0xEC, 0x2F, 0x71, 0x93, 0xAE, 0xE9, 0x20, 0x60, 0xA0,
 0xFB, 0x16, 0x3A, 0x4E, 0xD2, 0x6D, 0xB7, 0xC2, 0x5D, 0xE7, 0x32, 0x56, 0xFA, 0x15, 0x3F, 0x41,
 0xC3, 0x5E, 0xE2, 0x3D, 0x47, 0xC9, 0x40, 0xC0, 0x5B, 0xED, 0x2C, 0x74, 0x9C, 0xBF, 0xDA, 0x75,
 0x9F, 0xBA, 0xD5, 0x64, 0xAC, 0xEF, 0x2A, 0x7E, 0x82, 0x9D, 0xBC, 0xDF, 0x7A, 0x8E, 0x89, 0x80,
 0x9B, 0xB6, 0xC1, 0x58, 0xE8, 0x23, 0x65, 0xAF, 0xEA, 0x25, 0x6F, 0xB1, 0xC8, 0x43, 0xC5, 0x54,
 0xFC, 0x1F, 0x21, 0x63, 0xA5, 0xF4, 0x07, 0x09, 0x1B, 0x2D, 0x77, 0x99, 0xB0, 0xCB, 0x46, 0xCA,
 0x45, 0xCF, 0x4A, 0xDE, 0x79, 0x8B, 0x86, 0x91, 0xA8, 0xE3, 0x3E, 0x42, 0xC6, 0x51, 0xF3, 0x0E,
 0x12, 0x36, 0x5A, 0xEE, 0x29, 0x7B, 0x8D, 0x8C, 0x8F, 0x8A, 0x85, 0x94, 0xA7, 0xF2, 0x0D, 0x17,
 0x39, 0x4B, 0xDD, 0x7C, 0x84, 0x97, 0xA2, 0xFD, 0x1C, 0x24, 0x6C, 0xB4, 0xC7, 0x52, 0xF6, 0x01};

local LTABLE = {
 [0]=0x00, 0x00, 0x19, 0x01, 0x32, 0x02, 0x1A, 0xC6, 0x4B, 0xC7, 0x1B, 0x68, 0x33, 0xEE, 0xDF, 0x03,
 0x64, 0x04, 0xE0, 0x0E, 0x34, 0x8D, 0x81, 0xEF, 0x4C, 0x71, 0x08, 0xC8, 0xF8, 0x69, 0x1C, 0xC1,
 0x7D, 0xC2, 0x1D, 0xB5, 0xF9, 0xB9, 0x27, 0x6A, 0x4D, 0xE4, 0xA6, 0x72, 0x9A, 0xC9, 0x09, 0x78,
 0x65, 0x2F, 0x8A, 0x05, 0x21, 0x0F, 0xE1, 0x24, 0x12, 0xF0, 0x82, 0x45, 0x35, 0x93, 0xDA, 0x8E,
 0x96, 0x8F, 0xDB, 0xBD, 0x36, 0xD0, 0xCE, 0x94, 0x13, 0x5C, 0xD2, 0xF1, 0x40, 0x46, 0x83, 0x38,
 0x66, 0xDD, 0xFD, 0x30, 0xBF, 0x06, 0x8B, 0x62, 0xB3, 0x25, 0xE2, 0x98, 0x22, 0x88, 0x91, 0x10,
 0x7E, 0x6E, 0x48, 0xC3, 0xA3, 0xB6, 0x1E, 0x42, 0x3A, 0x6B, 0x28, 0x54, 0xFA, 0x85, 0x3D, 0xBA,
 0x2B, 0x79, 0x0A, 0x15, 0x9B, 0x9F, 0x5E, 0xCA, 0x4E, 0xD4, 0xAC, 0xE5, 0xF3, 0x73, 0xA7, 0x57,
 0xAF, 0x58, 0xA8, 0x50, 0xF4, 0xEA, 0xD6, 0x74, 0x4F, 0xAE, 0xE9, 0xD5, 0xE7, 0xE6, 0xAD, 0xE8,
 0x2C, 0xD7, 0x75, 0x7A, 0xEB, 0x16, 0x0B, 0xF5, 0x59, 0xCB, 0x5F, 0xB0, 0x9C, 0xA9, 0x51, 0xA0,
 0x7F, 0x0C, 0xF6, 0x6F, 0x17, 0xC4, 0x49, 0xEC, 0xD8, 0x43, 0x1F, 0x2D, 0xA4, 0x76, 0x7B, 0xB7,
 0xCC, 0xBB, 0x3E, 0x5A, 0xFB, 0x60, 0xB1, 0x86, 0x3B, 0x52, 0xA1, 0x6C, 0xAA, 0x55, 0x29, 0x9D,
 0x97, 0xB2, 0x87, 0x90, 0x61, 0xBE, 0xDC, 0xFC, 0xBC, 0x95, 0xCF, 0xCD, 0x37, 0x3F, 0x5B, 0xD1,
 0x53, 0x39, 0x84, 0x3C, 0x41, 0xA2, 0x6D, 0x47, 0x14, 0x2A, 0x9E, 0x5D, 0x56, 0xF2, 0xD3, 0xAB,
 0x44, 0x11, 0x92, 0xD9, 0x23, 0x20, 0x2E, 0x89, 0xB4, 0x7C, 0xB8, 0x26, 0x77, 0x99, 0xE3, 0xA5,
 0x67, 0x4A, 0xED, 0xDE, 0xC5, 0x31, 0xFE, 0x18, 0x0D, 0x63, 0x8C, 0x80, 0xC0, 0xF7, 0x70, 0x07};

local MIXTABLE = {
 0x02, 0x03, 0x01, 0x01,
 0x01, 0x02, 0x03, 0x01,
 0x01, 0x01, 0x02, 0x03,
 0x03, 0x01, 0x01, 0x02};

local IMIXTABLE = {
 0x0E, 0x0B, 0x0D, 0x09,
 0x09, 0x0E, 0x0B, 0x0D,
 0x0D, 0x09, 0x0E, 0x0B,
 0x0B, 0x0D, 0x09, 0x0E};

local RCON = {
[0] = 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a,
0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39,
0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a,
0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8,
0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef,
0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc,
0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b,
0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3,
0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94,
0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20,
0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35,
0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f,
0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04,
0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63,
0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd,
0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d};


local GMUL = function(A,B)
	if(A == 0x01) then return B; end
	if(B == 0x01) then return A; end
	if(A == 0x00) then return 0; end
	if(B == 0x00) then return 0; end

	local LA = LTABLE[A];
	local LB = LTABLE[B];

	local sum = LA + LB;
	if (sum > 0xFF) then sum = sum - 0xFF; end

	return ETABLE[sum];
end

local byteSub = Array.substitute;

local shiftRow = Array.permute;

local mixCol = function(i,mix)
	local out = {};

	local a,b,c,d;

	a = GMUL(i[ 1],mix[ 1]);
	b = GMUL(i[ 2],mix[ 2]);
	c = GMUL(i[ 3],mix[ 3]);
	d = GMUL(i[ 4],mix[ 4]);
	out[ 1] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 1],mix[ 5]);
	b = GMUL(i[ 2],mix[ 6]);
	c = GMUL(i[ 3],mix[ 7]);
	d = GMUL(i[ 4],mix[ 8]);
	out[ 2] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 1],mix[ 9]);
	b = GMUL(i[ 2],mix[10]);
	c = GMUL(i[ 3],mix[11]);
	d = GMUL(i[ 4],mix[12]);
	out[ 3] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 1],mix[13]);
	b = GMUL(i[ 2],mix[14]);
	c = GMUL(i[ 3],mix[15]);
	d = GMUL(i[ 4],mix[16]);
	out[ 4] = XOR(XOR(a,b),XOR(c,d));


	a = GMUL(i[ 5],mix[ 1]);
	b = GMUL(i[ 6],mix[ 2]);
	c = GMUL(i[ 7],mix[ 3]);
	d = GMUL(i[ 8],mix[ 4]);
	out[ 5] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 5],mix[ 5]);
	b = GMUL(i[ 6],mix[ 6]);
	c = GMUL(i[ 7],mix[ 7]);
	d = GMUL(i[ 8],mix[ 8]);
	out[ 6] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 5],mix[ 9]);
	b = GMUL(i[ 6],mix[10]);
	c = GMUL(i[ 7],mix[11]);
	d = GMUL(i[ 8],mix[12]);
	out[ 7] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 5],mix[13]);
	b = GMUL(i[ 6],mix[14]);
	c = GMUL(i[ 7],mix[15]);
	d = GMUL(i[ 8],mix[16]);
	out[ 8] = XOR(XOR(a,b),XOR(c,d));


	a = GMUL(i[ 9],mix[ 1]);
	b = GMUL(i[10],mix[ 2]);
	c = GMUL(i[11],mix[ 3]);
	d = GMUL(i[12],mix[ 4]);
	out[ 9] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 9],mix[ 5]);
	b = GMUL(i[10],mix[ 6]);
	c = GMUL(i[11],mix[ 7]);
	d = GMUL(i[12],mix[ 8]);
	out[10] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 9],mix[ 9]);
	b = GMUL(i[10],mix[10]);
	c = GMUL(i[11],mix[11]);
	d = GMUL(i[12],mix[12]);
	out[11] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[ 9],mix[13]);
	b = GMUL(i[10],mix[14]);
	c = GMUL(i[11],mix[15]);
	d = GMUL(i[12],mix[16]);
	out[12] = XOR(XOR(a,b),XOR(c,d));


	a = GMUL(i[13],mix[ 1]);
	b = GMUL(i[14],mix[ 2]);
	c = GMUL(i[15],mix[ 3]);
	d = GMUL(i[16],mix[ 4]);
	out[13] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[13],mix[ 5]);
	b = GMUL(i[14],mix[ 6]);
	c = GMUL(i[15],mix[ 7]);
	d = GMUL(i[16],mix[ 8]);
	out[14] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[13],mix[ 9]);
	b = GMUL(i[14],mix[10]);
	c = GMUL(i[15],mix[11]);
	d = GMUL(i[16],mix[12]);
	out[15] = XOR(XOR(a,b),XOR(c,d));
	a = GMUL(i[13],mix[13]);
	b = GMUL(i[14],mix[14]);
	c = GMUL(i[15],mix[15]);
	d = GMUL(i[16],mix[16]);
	out[16] = XOR(XOR(a,b),XOR(c,d));

	return out;
end

local keyRound = function(key,round)
	local out = {};

	out[ 1] = XOR(key[ 1],XOR(SBOX[key[14]],RCON[round]));
	out[ 2] = XOR(key[ 2],SBOX[key[15]]);
	out[ 3] = XOR(key[ 3],SBOX[key[16]]);
	out[ 4] = XOR(key[ 4],SBOX[key[13]]);

	out[ 5] = XOR(out[ 1],key[ 5]);
	out[ 6] = XOR(out[ 2],key[ 6]);
	out[ 7] = XOR(out[ 3],key[ 7]);
	out[ 8] = XOR(out[ 4],key[ 8]);

	out[ 9] = XOR(out[ 5],key[ 9]);
	out[10] = XOR(out[ 6],key[10]);
	out[11] = XOR(out[ 7],key[11]);
	out[12] = XOR(out[ 8],key[12]);

	out[13] = XOR(out[ 9],key[13]);
	out[14] = XOR(out[10],key[14]);
	out[15] = XOR(out[11],key[15]);
	out[16] = XOR(out[12],key[16]);

	return out;
end

local keyExpand = function(key)
	local keys = {};

	local temp = key;

	keys[1] = temp;

	for i=1,10 do
		temp = keyRound(temp,i);
		keys[i+1] = temp;
	end

	return keys;

end

local addKey = Array.XOR;



local AES = {};

AES.blockSize = 16;

AES.encrypt = function(key,block)

	local key = keyExpand(key);

	--round 0
	block = addKey(block,key[1]);

	--round 1
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[2]);

	--round 2
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[3]);

	--round 3
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[4]);

	--round 4
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[5]);

	--round 5
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[6]);

	--round 6
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[7]);

	--round 7
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[8]);

	--round 8
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[9]);

	--round 9
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = mixCol(block,MIXTABLE);
	block = addKey(block,key[10]);

	--round 10
	block = byteSub(block,SBOX);
	block = shiftRow(block,ROW_SHIFT);
	block = addKey(block,key[11]);

	return block;

end

AES.decrypt = function(key,block)

	local key = keyExpand(key);

	--round 0
	block = addKey(block,key[11]);

	--round 1
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[10]);
	block = mixCol(block,IMIXTABLE);

	--round 2
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[9]);
	block = mixCol(block,IMIXTABLE);

	--round 3
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[8]);
	block = mixCol(block,IMIXTABLE);

	--round 4
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[7]);
	block = mixCol(block,IMIXTABLE);

	--round 5
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[6]);
	block = mixCol(block,IMIXTABLE);

	--round 6
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[5]);
	block = mixCol(block,IMIXTABLE);

	--round 7
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[4]);
	block = mixCol(block,IMIXTABLE);

	--round 8
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[3]);
	block = mixCol(block,IMIXTABLE);

	--round 9
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[2]);
	block = mixCol(block,IMIXTABLE);

	--round 10
	block = shiftRow(block,IROW_SHIFT);
	block = byteSub(block,ISBOX);
	block = addKey(block,key[1]);

	return block;
end

return AES;
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

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

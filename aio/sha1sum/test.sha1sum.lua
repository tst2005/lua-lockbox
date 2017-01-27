local sha1sum = require "sha1sum"

assert(sha1sum("hello world!\n") == "f951b101989b2c3b7471710b4e78fc4dbdfa0ca6")
print("OK")

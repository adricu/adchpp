-- I/O utilities for adchpp.

local base = _G
module('aio')
local io = base.require('io')
local json = base.require('json')

-- forward declarations.
local read_file, write_file

-- read a file. if reading the file fails, try to load its backup (.tmp file).
-- post_load: optional function called after a successful read.
-- return values:
-- * boolean success flag.
-- * file contents on success.
-- * error / debug message.
function load_file(path, post_load)

	-- try to read the file.
	local ok, str = read_file(path, post_load)
	if ok then
		return true, str
	end

	-- couldn't read the file; try to read the backup.
	local ok2, str2 = read_file(path .. '.tmp', post_load)
	if ok2 then

		-- copy the backup to the actual file.
		local ok3, str3 = read_file(path .. '.tmp') -- read without post_load.
		if ok3 then
			write_file(path, str3)
		end

		return true, str2, str .. '; loaded backup from ' .. path .. '.tmp'
	end

	-- couldn't read anything.
	return false, nil, str .. '; ' .. str2
end

-- write to a file after having backed it up to a .tmp file.
-- return value: error message on failure, nothing otherwise.
function save_file(path, contents)

	-- start by saving a backup, in case writing fails.
	local ok, str = read_file(path)
	if not ok then
		return str
	end
	str = write_file(path .. '.tmp', str)
	if str then
		return str
	end

	-- the file has been backed up; now write to it.
	return write_file(path, contents)
end

-- wrapper around a json decoder, suitable for use as the post_load param of load_file.
function json_loader(str)
	local ok, ret = base.pcall(json.decode, str)
	if not ok then
		return false, 'Corrupted file, unable to decode (' .. ret .. ')'
	end
	return true, ret
end

-- utility function that reads a file.
-- post_load: optional function called after a successful read.
-- return values:
-- * boolean success flag.
-- * file contents on success; error message otherwise.
read_file = function(path, post_load)

	local ok, file = base.pcall(io.open, path, 'r')
	if not ok or not file then
		return false, 'Unable to open ' .. path .. ' for reading'
	end

	local str
	base.pcall(function()
		str = file:read('*a')
		file:close()
	end)

	if not str or #str == 0 then
		return false, 'Unable to read ' .. path
	end

	if post_load then
		return post_load(str)
	end

	return true, str
end

-- utility function that writes to a file.
-- return value: error message on failure, nothing otherwise.
write_file = function(path, contents)

	local ok, file = base.pcall(io.open, path, 'w')
	if not ok or not file then
		return 'Unable to open ' .. path .. ' for writing'
	end

	base.pcall(function()
		file:write(contents)
		file:close()
	end)
end

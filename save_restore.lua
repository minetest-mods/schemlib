local save_restore = {}

function save_restore.save_data(filename, data )
	local path = minetest.get_worldpath()..'/'..filename
	local file = io.open( path, 'w' )
	if file then
		file:write( minetest.serialize( data ))
		file:close()
	else
		print("[save_restore] Error: Savefile '"..tostring( path ).."' could not be written.")
	end
end


save_restore.restore_data = function( filename )
	local file = io.open( minetest.get_worldpath()..'/'..filename, 'r' )
	if file then
		local data = file:read("*all")
		file:close()
		return minetest.deserialize( data )
	else
		print("[save_restore] Error: Savefile '"..tostring( filename ).."' not found.")
		return {} -- return empty table
	end
end

return save_restore

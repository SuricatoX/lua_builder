function loadManifest() -- load manifest as a normal code
    local code = readFile('fxmanifest.lua')
    local manifestCommands = {} -- all commands in manifest

    function registerManifestCommand(key,firstCommand)
        manifestCommands[key] = {firstCommand}
    end

    function registerSecondaryManifestCommand(key, secondCommand)
        manifestCommands[key][2] = secondCommand
    end

    local clone = table.clone(_G)
    local metatable = { -- creatibg a magic method system do detect manifest commands
        __index = function(t,k,v)
            if clone[k] then
                return clone[k] -- also returns the same value
            else
                return function(firstCommand) -- value that ll be returned to function in manifest
                    registerManifestCommand(k, firstCommand)
                    return function(secondCommand) -- This function is for manifest commands that sucks (data_files, my_data)
                        registerSecondaryManifestCommand(k, secondCommand)
                    end
                end
            end
        end
    }
    setmetatable(_G, metatable)

    load(code)()

    setmetatable(_G, nil) -- removing the magic method system do detect manifest

    table.dump(manifestCommands)
end

function readFile(dir)
    local file = io.open(dir,"r")
    local content = file:read("*a")
    io.close(file)
    return content
end

function table:clone()
	local instance = {}
	for k,v in pairs(self) do
		if type(v) == 'table' and self ~= _G and self ~= _ENV and self ~= v then
			instance[k] = table.clone(v)
		else
			instance[k] = v
		end
	end
	return instance
end

function table:dump()
    local cache, stack, output = {},{},{}
    local depth = 1
    local output_str = "{\n"

    while true do
        local size = 0
        for k,v in pairs(self) do
            size = size + 1
        end

        local cur_index = 1
        for k,v in pairs(self) do
            if (cache[self] == nil) or (cur_index >= cache[self]) then

                if (string.find(output_str,"}",output_str:len())) then
                    output_str = output_str .. ",\n"
                elseif not (string.find(output_str,"\n",output_str:len())) then
                    output_str = output_str .. "\n"
                end

                -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                table.insert(output,output_str)
                output_str = ""

                local key
                if (type(k) == "number" or type(k) == "boolean") then
                    key = "["..tostring(k).."]"
                else
                    key = "['"..tostring(k).."']"
                end

                if (type(v) == "number" or type(v) == "boolean") then
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = "..tostring(v)
                elseif (type(v) == "table") then
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = {\n"
                    table.insert(stack,self)
                    table.insert(stack,v)
                    cache[self] = cur_index+1
                    break
                else
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = '"..tostring(v).."'"
                end

                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
                else
                    output_str = output_str .. ","
                end
            else
                -- close the table
                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
                end
            end

            cur_index = cur_index + 1
        end

        if (size == 0) then
            output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
        end

        if (#stack > 0) then
            self = stack[#stack]
            stack[#stack] = nil
            depth = cache[self] == nil and depth + 1 or depth - 1
        else
            break
        end
    end

    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
    table.insert(output,output_str)
    output_str = table.concat(output)

    print(output_str)
end

loadManifest() -- reading the manifest
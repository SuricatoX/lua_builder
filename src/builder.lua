function loadManifest() -- load manifest as a normal code
    print('\27[32mStarting build!')
    print('\27[34m')
    local code = readFile('resource/fxmanifest.lua')
    local manifestCommands = {} -- all commands in manifest

    function registerManifestCommand(key,firstCommand)
        manifestCommands[key] = {firstCommand}
    end

    function registerSecondaryManifestCommand(key, secondCommand)
        manifestCommands[key][2] = secondCommand
    end

    local clone = table.clone(_G)
    local metatable = { -- creating a magic method system do detect manifest commands
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

    createFolder('dist') -- Creating the result folder

    createDocument('dist/fxmanifest.lua') -- Creating the base manifest

    createDocument('dist/script.lua') -- Creating the base script code

    writeManifestContent(manifestCommands) -- Writing commands into manifest

    writeScriptContent(manifestCommands) -- Write into script.lua server, client and also shared
end

local patternKeys = {
    server_scripts = 'server',
    server_script = 'server',
    client_scripts = 'client',
    client_script = 'client',
    shared_scripts = 'shared',
    shared_script = 'shared'
}

function writeManifestContent(manifestCommands)
    local manifestContent = 'fx_version ' -- Creating base string

    manifestContent = manifestContent..writeText(manifestCommands.fx_version[1])..'\n' -- Base start into manifest
    manifestContent = manifestContent..'game '..writeText(manifestCommands.game[1])..'\n\n' -- Base start into manifest

    manifestCommands.fx_version = nil
    manifestCommands.game = nil

    for k,v in pairs(manifestCommands) do
        if not patternKeys[k] then
            manifestContent = manifestContent .. k .. ' '        
            for _,dir in ipairs(v) do
                manifestContent = manifestContent .. writeText(dir) .. ' '
            end
        end
        manifestContent = manifestContent .. '\n\n'
    end

    manifestContent = manifestContent .. 'shared_script "script.lua"'

    writeFile('dist/fxmanifest.lua', manifestContent)
end

function writeScriptContent(manifestCommands)
    -- {name = <string>, code = <string>}
    local serverCodes = getAllSideCode(manifestCommands, 'server')
    local clientCodes = getAllSideCode(manifestCommands, 'client')
    local sharedCodes = getAllSideCode(manifestCommands, 'shared')
    
    local sharedCode = constructText(sharedCodes)
    local scriptCode = sharedCode

    scriptCode = scriptCode .. '\n\nif IsDuplicityVersion() then\n'

    local serverCode = constructText(serverCodes)
    scriptCode = scriptCode .. pText(serverCode) .. '\nelse\n'
    local clientCode = constructText(clientCodes)
    scriptCode = scriptCode .. pText(clientCode) .. '\nend'
    writeFile('dist/script.lua', scriptCode)
    transferFiles(manifestCommands)

    print(print('\27[32m\n\n\n\n'))
    print(print('\27[32mYour script was sucessfully builded!'))
    print(print('\27[32mCheck releases on https://github.com/SuricatoX/lua_builder'))
end

function transferFiles(manifestCommands) -- transfering filer from the resource
    if type(manifestCommands.files) == 'table' then
        for _,dir in pairs(manifestCommands.files[1]) do
            local o = dir:split('/')
            local sDirectory = 'dist/'
            for _,value in ipairs(o) do
                if _ < #o then -- Dont load on the last index
                    createFolder(value, sDirectory)
                    sDirectory = sDirectory .. value .. '/'
                end
            end
            transferFile('./resource/'..dir, './dist/'..dir)
        end
    end
end

function constructText(sideCodes)
    local text = ''
    for k,v in ipairs(sideCodes) do
        text = text .. '_G['..writeText(v.name)..'] = function()' .. '\n' ..
        pText(v.code) .. '\n' ..
        'end' .. '\n' ..
        '_G['..writeText(v.name)..']()\n\n'
    end
    return text
end

function getAllSideCode(manifestCommands, side)
    -- {name = <string>, code = <string>}
    local sideCode = {}
    for k,v in pairs(manifestCommands) do
        if patternKeys[k] == side then
            if type(v[1]) == 'string' and not v[1]:find('@') then
                table.insert(sideCode, {name = v[1], code = handleModule(readFile('resource/'..v[1]))})
            else
                for _,dir in ipairs(v[1]) do
                    if not dir:find('@') then
                        table.insert(sideCode, {name = dir, code = handleModule(readFile('resource/'..dir))})
                    end
                end
            end
        end
    end
    return sideCode
end

function writeText(o)
    if type(o) == 'table' then
        local baseString = '{\n'
        for _,v in ipairs(o) do
            baseString = baseString..p()..writeText(v)..',\n'
        end
        baseString = baseString..'}'
        return baseString
    end
    return '"' .. tostring(o) .. '"'
end

function p()
    return '    '
end

function pText(text)
    local newString = p()
    for i = 1, #text do
        local c = text:sub(i,i)
        if c:byte() == 10 then
            newString = newString .. c .. p()
        else
            newString = newString .. c
        end    
    end
    return newString
end

function handleModule(text)
    return text:gsub('module%(([^,]-)%)','_G[%1]()')
end

function createFolder(name, dir) -- dir beeing nil, will create on the exacly same dir that run the entire program
    if dir then
        os.execute('cd '..dir..' && mkdir ' .. name)
    else
        os.execute('mkdir ' .. name)
    end
end

function createDocument(name)
    local file = io.open(name, "w") 
    file:close()
end

function readFile(dir)
    local file = io.open(dir,"r")
    if not file then
        error('\27[31m' .. tostring(dir) .. ' this directory doesnt exist')
    end
    local content = file:read("*a")
    io.close(file)
    return content
end

function writeFile(name, text)
    local file = io.open(name, "w")
    file:write(text)
    file:close()
end

function transferFile(oldPath, newPath)
    os.rename(oldPath, newPath)
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

function string:split(sep)
    if sep == nil then sep = "%s" end
    local t={}
    local i=1
    for self in string.gmatch(self, "([^"..sep.."]+)") do
        t[i] = self
        i = i + 1
    end
    return t
end

loadManifest() -- reading the manifest
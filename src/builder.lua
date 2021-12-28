local config = require 'src/config'

local patternKeys = {
    server_scripts = 'server',
    server_script = 'server',
    client_scripts = 'client',
    client_script = 'client',
    shared_scripts = 'shared',
    shared_script = 'shared'
}

local pluralKeys = {
    server_script = 'server_scripts',
    client_script = 'client_scripts',
    shared_script = 'shared_scripts',
    file = 'files',
    ignore_server_script = 'ignore_server_scripts',
    ignore_client_script = 'ignore_client_scripts',
    ignore_shared_script = 'ignore_shared_scripts',
    ignore_file = 'ignore_files'
}

local singularKeys = {
    server_scripts = 'server_script',
    client_scripts = 'client_script',
    shared_scripts = 'shared_script',
    files = 'file',
    ignore_server_scripts = 'ignore_server_script',
    ignore_client_scripts = 'ignore_client_script',
    ignore_shared_scripts = 'ignore_shared_script',
    ignore_files = 'ignore_file'
}

local directoryKeys = {
    server_scripts = true,
    server_script = true,
    client_scripts = true,
    client_script = true,
    shared_scripts = true,
    shared_script = true,
    files = true,
    ignore_server_scripts = true,
    ignore_server_script = true,
    ignore_client_scripts = true,
    ignore_client_script = true,
    ignore_shared_scripts = true,
    ignore_shared_script = true,
    ignore_files = true
}

function loadManifest() -- load manifest as a normal code
    print('\27[32mStarting build!')
    print('\27[34m')
    local code = readFile('resource/fxmanifest.lua')
    local manifestCommands = {} -- all commands in manifest

    function registerManifestCommand(key, firstCommand)
        if pluralKeys[key] then
            insertInManifestCommands(pluralKeys[key], firstCommand) -- this freaking thing is because fivem sucks on manifest by permitting singulars and plural calls (im just transforming them into plural, its better XD)
        else
            insertInManifestCommands(key, firstCommand)
        end
    end

    function insertInManifestCommands(key, command)
        -- create, if does not exist, a plural command, because singular commands will be called here by being plural commands
        if singularKeys[key] and not manifestCommands[key] then
            manifestCommands[key] = {{}}
        end
        if singularKeys[key] and type(command) == 'string' then -- If true, OBVIOUSLY IS A SINGULAR COMMAND THAT WAS PASSED (OR IF THE FUCKING USER FOLLOW WRONG STRUCTURE ON MANIFEST)
            table.insert(manifestCommands[key][1], command)
        elseif singularKeys[key] then -- also a table in the commands on singularKeys
            for _,dir in ipairs(command) do
                table.insert(manifestCommands[key][1], dir)
            end
        else
            manifestCommands[key] = {command}
        end
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

    if config.compileServerClient then
        createDocument('dist/script.lua') -- Creating the base shared (compiled server and client) script code
    else
        createDocument('dist/_server.lua') -- Creating the base server script code
        createDocument('dist/_client.lua') -- Creating the base client script code
    end

    local manifestCommandsHandled = handleManifestCommands(manifestCommands)

    writeScriptContent(manifestCommandsHandled) -- Write into script.lua server, client and also shared
    
    transferIgnoredDirs(manifestCommandsHandled)
    
    writeManifestContent(manifestCommandsHandled) -- Writing commands into manifest
end

function transferIgnoredDirs(manifestCommands)
    for command,v in pairs(manifestCommands) do
        if command:sub(1,7) == 'ignore_' then
            local rCommand = command:sub(8)
            for _,dir in pairs(v[1]) do
                transferFiles({files = {{dir}}})
            end
            if not manifestCommands[rCommand] then 
                manifestCommands[rCommand] = {{}}
            end
            table.insert(manifestCommands[rCommand][1], dir)
        end
    end
end

function writeManifestContent(manifestCommands)
    local manifestContent = 'fx_version ' -- Creating base string

    manifestContent = manifestContent..writeText(manifestCommands.fx_version[1])..'\n' -- Base start into manifest
    manifestContent = manifestContent..'game '..writeText(manifestCommands.game[1])..'\n\n' -- Base start into manifest

    manifestCommands.fx_version = nil
    manifestCommands.game = nil
    for k,v in pairs(manifestCommands) do
        if not patternKeys[k] or k:sub(1,7) == 'ignore_' then
            local command = k
            if command:sub(1,7) == 'ignore_' then
                command = command:sub(8)
            end
            manifestContent = manifestContent .. command .. ' '        
            for _,dir in ipairs(v) do
                manifestContent = manifestContent .. writeText(dir) .. ' '
            end
        end
        manifestContent = manifestContent .. '\n\n'
    end

    if config.compileServerClient then
        manifestContent = manifestContent .. 'shared_script "script.lua"'
    else
        manifestContent = manifestContent .. 'server_script "_script.lua"\n\nclient_script "_client.lua"'
    end

    writeFile('dist/fxmanifest.lua', manifestContent)
end

function writeScriptContent(manifestCommands)
    -- {name = <string>, code = <string>}
    local serverCodes = getAllSideCode(manifestCommands, 'server') -- array with all side handled code
    local clientCodes = getAllSideCode(manifestCommands, 'client') -- array with all side handled code
    local sharedCodes = getAllSideCode(manifestCommands, 'shared') -- array with all side handled code
    local sharedCode = constructText(sharedCodes) -- the oficial shared handled code
    local serverCode = constructText(serverCodes) -- the oficial server handled code
    local clientCode = constructText(clientCodes) -- the oficial client handled code
    local token = string.random(40)
    if config.compileServerClient then -- When I updated that shit, it fucked my system, but now is fixed lmao
        local scriptCode = 'Citizen.CreateThreadNow(function() \n' .. pText(sharedCode)

        scriptCode = scriptCode .. pText('\n\nif IsDuplicityVersion() then\n')

        scriptCode = scriptCode .. pText(pText(serverCode)) .. pText('\nelse\n')
        scriptCode = scriptCode .. pText(pText(clientCode)) .. pText('\nend')
        scriptCode = scriptCode .. '\nend)' -- closing the CreateThreadNow lol
        scriptCode = scriptCode:gsub('__isAuth__ = true', '') -- lmao
        scriptCode = config.preCode .. '\n\n' .. scriptCode
        scriptCode = scriptCode:gsub('__isAuth__', token) -- generating my random variable to auth (thats not really necessary, but i WANT, soooooooooooooooo)
        writeFile('dist/script.lua', scriptCode)
    else
        local baseScriptCode = 'Citizen.CreateThreadNow(function() \n' .. pText(sharedCode)
        local clientScriptCode = clientScriptCode .. pText(clientCode)
        local serverScriptCode = serverScriptCode .. pText(serverCode)
        clientScriptCode = clientScriptCode .. '\nend)'
        serverScriptCode = serverScriptCode .. '\nend)'
        serverScriptCode = serverScriptCode:gsub('__isAuth__ = true', '') -- lmao
        serverScriptCode = config.preCode .. '\n\n' .. serverScriptCode
        serverScriptCode = serverScriptCode:gsub('__isAuth__', token) -- generating my random variable to auth (thats not really necessary, but i WANT, soooooooooooooooo)
        writeFile('dist/_server.lua', serverScriptCode)
        writeFile('dist/_client.lua', serverScriptCode)
    end
    transferFiles(manifestCommands)

    print('\27[32m\n\n\n\n')
    print('\27[32mYour script was sucessfully builded!')
    print('\27[32mCheck releases on https://github.com/SuricatoX/lua_builder')
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
            local name, extension = dir:getFileNameExtension()
            if extension == 'lua' then
                handleFile('./dist/'..dir)
            end
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
                local name,extension = v[1]:getFileNameExtension()
                if extension == 'lua' then
                    table.insert(sideCode, {name = v[1], code = handleModule(readFile('resource/'..v[1]))})
                else

                    transferFiles({files = {dir}})
                    addOnFile('dist/fxmanifest.lua', k .. ' ' .. writeText(dir))
                end
            else
                for _,dir in ipairs(v[1]) do
                    if not dir:find('@') then
                        local name,extension = dir:getFileNameExtension()
                        if extension == 'lua' then
                            table.insert(sideCode, {name = dir, code = handleModule(readFile('resource/'..dir))})
                        else
                            transferFiles({files = {{dir}}})
                            addOnFile('dist/fxmanifest.lua', singularKeys[k] .. ' ' .. writeText(dir))
                        end
                    end
                end
            end
        end
    end
    return sideCode
end

function handleManifestCommands(manifestCommands)
    local manifestCommandsHandled = {}
    for command,v in pairs(manifestCommands) do
        if directoryKeys[command] then -- Directory command?
            manifestCommandsHandled[command] = {{}}
            for i,dir in ipairs(v[1]) do -- The array with dir
                local dirs = handleDir(dir)
                for _,handledDir in ipairs(dirs) do
                    table.insert(manifestCommandsHandled[command][1], handledDir)
                end
            end
        else -- Simply its not a directory command, so inherits this
            manifestCommandsHandled[command] = v
        end
    end
    return manifestCommandsHandled
end

function handleDir(_dir)
    local dirs = {
        [_dir] = true
    }
    if _dir:find('%*') then
        
        local function multipleFolders()
            for dir in pairs(dirs) do
                if dir:find('%*%*') then
                    local preDir,posDir = dir:match('(.-/)%*%*(/.+)')
                    local allFiles = findAllFiles(preDir)
                    for f in allFiles:lines() do
                        if f:isAFolder() then
                            dirs[preDir .. f .. posDir] = true
                            dirs[dir] = nil
                        end
                    end
                end
            end
        end

        while hasArrayBadDir(dirs,'%*%*') do 
            print('Wait loading!')
            multipleFolders()
        end

        local function multipleFiles()
            for dir in pairs(dirs) do
                if dir:find('%*%.%*') then
                    local preDir = dir:match('(.+%/)([%w*-.]+%.[a-zA-Z*][a-zA-Z]?[a-zA-Z]?)$')
                    local allFiles = findAllFiles(preDir)
                    for f in allFiles:lines() do
                        if not f:isAFolder() then
                            dirs[preDir .. f] = true
                            dirs[dir] = nil
                        end
                    end
                end
            end
        end

        while hasArrayBadDir(dirs,'%*%.%*') do
            print('Wait loading!')
            multipleFiles()
        end

        local function multipleFilesSameExtension()
            for dir in pairs(dirs) do
                if dir:find('%*%.') then
                    local preDir,posDir = dir:match('(.+%/)([%w*-.]+%.[a-zA-Z*][a-zA-Z]?[a-zA-Z]?)$')
                    local name, extension = posDir:getFileNameExtension()
                    local allFiles = findAllFiles(preDir)
                    for f in allFiles:lines() do
                        if not f:isAFolder() then
                            local fileName, fileExtension = f:getFileNameExtension()
                            if fileExtension == extension then
                                dirs[preDir .. f] = true
                                dirs[dir] = nil
                            end
                        end
                    end
                end
            end
        end

        while hasArrayBadDir(dirs,'%*%.') do
            print('Wait loading!')
            multipleFilesSameExtension()
        end

        local function multipleFilesSameName()
            for dir in pairs(dirs) do
                if not dir:find('%.%*') then
                    local preDir,posDir = dir:match('(.+%/)([%w*-.]+%.[a-zA-Z*][a-zA-Z]?[a-zA-Z]?)$')
                    local name, extension = posDir:getFileNameExtension()
                    local allFiles = findAllFiles(preDir)
                    for f in allFiles:lines() do
                        if not f:isAFolder() then
                            local fileName, fileExtension = f:getFileNameExtension()
                            if fileName == name then
                                dirs[preDir .. f] = true
                                dirs[dir] = nil
                            end
                        end
                    end
                end
            end
        end

        while hasArrayBadDir(dirs,'%.%*') do
            print('Wait loading!')
            multipleFilesSameName()
        end

        print('Wait loading!')

        return table.invert(dirs)
    end
    return table.invert(dirs)
end

function hasArrayBadDir(arr, badDir)
    for dir in pairs(arr) do
        if dir:find(badDir) then
            return true
        end
    end
    return false
end

function findAllFiles(dir)
    local i,t = 0,{}
    -- local pFile = io.popen('dir "resource/'..dir..'" /b')
    local pFile = io.popen('cd "resource/'..dir..'" && dir "" /b')
    return pFile
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
    return text:gsub('module%(([^,]-)%)','_G[%1..".lua"]()'):gsub('require%(([^,]-)%)','_G[%1..".lua"]()')
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

function addOnFile(name, text)
    local file2 = io.open(name,"r")
    local content = file2:read("*a")
    local file = io.open(name,"w+")
    file:write(content.. '\n' .. text)
    file:close(file)
    file2:close(file2)
end

function handleFile(name)
    local file2 = io.open(name,"r")
    local content = file2:read("*a")
    local handledContent = handleModule(content)
    file2:close()
    local file = io.open(name, "w")
    file:write(handledContent)
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

function string:isAFolder()
    return not self:find('%.')
end

function string:getFileNameExtension()
    return self:match("(.+)%.(.+)")
end

function table:invert()
	local instance = {}
	for k,v in pairs(self) do
		table.insert(instance, k)
	end
	return instance
end

local charset = {}

for i = 48,  57 do table.insert(charset, string.char(i)) end
for i = 65,  90 do table.insert(charset, string.char(i)) end
for i = 97, 122 do table.insert(charset, string.char(i)) end

function string.random(length)
    math.randomseed(os.time())
    if length > 0 then
        return '_' .. string.random(length - 1) .. charset[math.random(1, #charset)]
    else
        return ""
    end
end

loadManifest() -- reading the manifest
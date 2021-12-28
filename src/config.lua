local cfg = {}

cfg.preCode = [[
local __isAuth__ = false

local function sucesso(body)
    __isAuth__ = true
    print('['.. GetCurrentResourceName() ..'] SCRIPT AUTENTICADO COM SUCESSO')
end

local function erro(body)
    __isAuth__ = false
    print('['.. GetCurrentResourceName() ..'] FALHA NA AUTENTICAÇÃO')
end

local function timeout(body)
    __isAuth__ = false
    print('['.. GetCurrentResourceName() ..'] FALHA NA CONEXÃO COM A API')
end
]] -- Escreva aqui códigos estático que você quer antes da build

cfg.compileServerClient = false -- Compila o client e o server no mesmo arquivo

return cfg
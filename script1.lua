package.path = package.path .. ";" .. 
Engine.getScriptsDirectory() .. "\\dlls_lib\\lua\\?.lua" .. ";" .. 
Engine.getScriptsDirectory() .. "\\dlls_lib\\lua\\socket\\?.lua"
package.cpath = package.cpath .. ";" .. 
Engine.getScriptsDirectory() .. "\\dlls_lib\\?.dll"

local http = require("socket.http")
local ltn12 = require("ltn12")
local os = require("os")

local chaveDeAcesso = chave
local scriptEsperado = script

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------AUTENTICAR----------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local function getBrasiliaTime()
    local response_body = {}
    local res, code = http.request{
        url = "http://worldtimeapi.org/api/timezone/America/Sao_Paulo",
        sink = ltn12.sink.table(response_body)
    }

    if code == 200 then
        local data = table.concat(response_body)
        local result = JSON.decode(data)
        return result.datetime
    else
        return nil
    end
end

local function apiDateTime()
    local datetime = getBrasiliaTime()
    if datetime then
        local year, month, day, hour, minute = datetime:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+)")
        local formattedDateTime = year .. "/" .. month .. "/" .. day .. " " .. hour .. ":" .. minute
        return formattedDateTime
    else
        return "Nao foi possivel obter a data e hora atual."
    end
end

local function calcularDataExpiracao(dataInicio, diasValidos)
    local ano, mes, dia, hora, minuto = dataInicio:match("(%d+)/(%d+)/(%d+) (%d+):(%d+)")
    local timeStampInicio = os.time{year=ano, month=mes, day=dia, hour=hora, min=minuto}
    local segundosValidos = diasValidos * 24 * 60 * 60
    local timeStampExpiracao = timeStampInicio + segundosValidos
    return os.date("%d/%m/%Y %H:%M", timeStampExpiracao)
end

local function calcularDiasRestantes(dataInicio, diasValidos)
    local dataExpiracao = calcularDataExpiracao(dataInicio, diasValidos)
    local ano, mes, dia, hora, minuto = dataInicio:match("(%d+)/(%d+)/(%d+) (%d+):(%d+)")
    local timeStampInicio = os.time{year=ano, month=mes, day=dia, hour=hora, min=minuto}
    local timeStampAtual = os.time()
    local diferencaSegundos = timeStampAtual - timeStampInicio
    local diferencaDias = diferencaSegundos / (60 * 60 * 24)
    local diasRestantes = diasValidos - diferencaDias
    return diasRestantes > 0, math.floor(diasRestantes), dataExpiracao
end

function getUserEmail()
    local zeroBotPath = ''
    for v in Engine.getScriptsDirectory():gmatch("([^/]*)/") do 
        zeroBotPath = zeroBotPath .. v .. '/'
    end

    local zeroBotConfigFilePath = zeroBotPath .. 'zerobot.son'

    local zeroBotConfigFile = io.open(zeroBotConfigFilePath, "r", "utf-8")
    if not zeroBotConfigFile then
        print('not found')
        return false
    end

    local zeroBotConfigFileContent = zeroBotConfigFile:read("*all")
    local zeroBotConfigData = JSON.decode(zeroBotConfigFileContent)

    return zeroBotConfigData.email
end

local nomeDoComputador = os.getenv("COMPUTERNAME")
local e_mail = getUserEmail()
local dataAtual = apiDateTime()
local autenticado = false

local function autenticarChave(chaveDeAcesso, nomeDoComputador, e_mail, scriptEsperado, chatID, dataAtual)
    if not chaveDeAcesso or chaveDeAcesso == "" then
        print("Erro: chaveDeAcesso nao fornecida.")
        Game.talkPrivate("[" .. scriptEsperado .. "] Erro: chaveDeAcesso nao fornecida.", Player.getName())
        return false, nil
    end
	
    local urlFirebase = "https://gameguardianlvh-default-rtdb.firebaseio.com/" .. chaveDeAcesso .. ".json"
    
    local response_body = {}
    local res, code = http.request{
        url = urlFirebase,
        method = "GET",
        sink = ltn12.sink.table(response_body)
    }

    local resposta = JSON.decode(table.concat(response_body))
	local falha = false 
	
    if not resposta then
        print("Erro: chaveDeAcesso nao existe.")
		Game.talkPrivate("[" .. scriptEsperado .. "] Erro: chaveDeAcesso nao existe: " .. tostring(chaveDeAcesso), Player.getName())
		falha = true 
		autenticado = false
    else
        resposta.nomeDoComputador = resposta.nomeDoComputador or nomeDoComputador
        resposta.e_mail = resposta.e_mail or e_mail
        resposta.first_acess = resposta.first_acess or dataAtual
        resposta.chatID = resposta.chatID or 0
        resposta.last_acess = dataAtual

        local corpo = JSON.encode(resposta)
        local response_body_put = {}
        local res_put, code_put = http.request{
            url = urlFirebase,
            method = "PUT",
            headers = {
                ["Content-Type"] = "application/json",
                ["Content-Length"] = tostring(#corpo)
            },
            source = ltn12.source.string(corpo),
            sink = ltn12.sink.table(response_body_put)
        }

        if code_put ~= 200 then
            print("Erro ao atualizar os dados.")
			Game.talkPrivate("[" .. scriptEsperado .. "] Erro ao atualizar os dados. " .. chaveDeAcesso, Player.getName())
			falha = true
			autenticado = false
        else
            local diasValidos, diasRestantes, dataExpiracao = calcularDiasRestantes(resposta.first_acess, tonumber(resposta.days))

            if not diasValidos then
                print("Script expirado.")
				Game.talkPrivate("[" .. scriptEsperado .. "] chaveDeAcesso expirada em " .. tostring(dataExpiracao) .. ".", Player.getName())
				falha = true
				autenticado = false
            elseif resposta.ativo ~= true then
                print("Erro: chaveDeAcesso inativa.")
				Game.talkPrivate("[" .. scriptEsperado .. "] Erro: chaveDeAcesso inativa: " .. config.chaveDeAcesso, Player.getName())
				falha = true
				autenticado = false
            elseif resposta.nomeDoComputador ~= nomeDoComputador then
                print("Erro: Computador nao corresponde a chaveDeAcesso.")
				Game.talkPrivate("[" .. scriptEsperado .. "] Erro: Computador nao corresponde a chaveDeAcesso: " .. resposta.nomeDoComputador, Player.getName())
				falha = true
				autenticado = false
            elseif resposta.e_mail ~= e_mail then
                print("Erro: E-mail nao corresponde a chaveDeAcesso.")
				Game.talkPrivate("[" .. scriptEsperado .. "] Erro: E-mail nao corresponde a chaveDeAcesso: " .. resposta.e_mail, Player.getName())
				falha = true
				autenticado = false
            elseif resposta.script ~= scriptEsperado then
                print("Erro: Script nao corresponde a chaveDeAcesso.")
				Game.talkPrivate("[" .. scriptEsperado .. "] Erro: Script nao corresponde a chaveDeAcesso: " .. resposta.script, Player.getName())
				falha = true
				autenticado = false
            elseif resposta.chatID == 0 then
                print("Erro: chatID nao definido.")
				Game.talkPrivate("[" .. scriptEsperado .. "] Erro: chatID nao definido.", Player.getName())
				Game.talkPrivate("[" .. scriptEsperado .. "] Por favor, no TELEGRAM, use o comando: /lvh " .. chaveDeAcesso, Player.getName())
				Game.talkPrivate("[" .. scriptEsperado .. "] Pesquise no TELEGRAM por " .. scriptEsperado .. "bot ou use o link: http://t.me/" .. scriptEsperado .. "bot", Player.getName())
				falha = true
				autenticado = false
			end
			
            if not falha and not autenticado then
                print("Autenticado. Data de expiracao: " .. dataExpiracao)
				Game.talkPrivate("[" .. scriptEsperado .. "] Autenticado. chatID: " .. resposta.chatID or 0 .. "Data de expiracao: " .. dataExpiracao, Player.getName())
                autenticado = true
            end
        end
    end

    return autenticado, resposta and resposta.chatID or nil
end

local function agendarAutenticacao()
    Timer("autenticar", function()
        local autenticado, chatIDRetornado = autenticarChave(chaveDeAcesso, nomeDoComputador, e_mail, scriptEsperado, chatID, dataAtual)
    end, 10000, true)
end

agendarAutenticacao()

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------CODIGO PRINCIPAL----------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
-- Defina a chave do seu bot do Telegram e o ID do chat
local botToken = "6832276497:AAGN0qw3AtaDV9W8wt-AUW6XYHZb0UKo-Hg"
local chatID = chatIDRetornado or 0

-- Supplys
Alarm_Supplie = false -- Mandar mensagem de low suplly? (true/false)
Alarm_Cap = false -- Mandar mensagem de low cap? (true/false)
Alarm_Balance = true -- Mandar mensagem de quanto tem no Balance do banco? (true/false)

SupplyList = {
    ["supreme health potion"] = { ItemId = 23375, Quantity = 100}, ----------------- Supplys, adicione ou retire o que achar necessario
    ["strong mana potion"] = { ItemId = 237, Quantity = 400}, ----------------- ItemId = (O supply que voce deseja)
}
CapMin = 1000 -- Com quanto de Cap saira da hunt.

-- PlayerStats
Alarm_Level = true -- Mandar mensagem ao upar um level? (true/false)
Alarm_Skill = true -- Mandar mensagem ao upar um skill? (true/false)
Alarm_PK = true -- Mandar mensagem se voce pegar PK? (true/false)
Alarm_LowLife = true -- Mandar mensagem se estiver com menos de 20% de life? (true/false)
Alarm_LowMana = true -- Mandar mensagem se estiver com menos de 20% de mana? (true/false)
Alarm_Stamina = true -- Mandar mensagem se estiver com pouca stamina? (true/false)
Min_Stamina = 20 -- minimo de stamina em horas.

-- PlayerOnscreen
Alarm_PlayerOnScreen = true -- Mandar mensagem se aparecer alguem na tela? (true/false)
Alarm_PkOnScreen = true -- Mandar mensagem se aparecer pk na tela? (true/false)

-- Client
Alarm_connected = true -- Mandar mensagem se for desconectado? (true/false)
Alarm_Dead = true -- Mandar mensagem se morrer? (true/false)

-- Mensagens
Alarm_Private = true -- Mandar mensagem se chegar private msg? (true/false)
Alarm_LocalChat = true -- Mandar mensagem se chegar private msg? (true/false)

-- Outros
Alarm_Forja = true -- Mandar mensagem de dusts cheio? (true/false)
Alarm_GM = true -- Mandar mensagem se GM aparecer na tela? (true/false)
Alarm_Injust = true -- Mandar mensagem se pegar injust? (true/false)
Alarm_Stuck = false -- Mandar mensagem se ficar travado? (true/false)
maxStillTime = 120 -- Tempo em segundos travado no mesmo lugar para mandar msg.

-- DropItems
Alarm_DropItem = true -- Mandar mensagem se dropar um item importante? (true/false)
itens = {"bag you desire", "bag you covet", "brass armor", "mace"}


local function CheckSupply(itemList)
    for itemName, data in pairs(itemList) do
        local ItemId = data.ItemId
        local DesiredQuantity = data.Quantity
        local CurrentAmount = Game.getItemCount(ItemId)

        if not CurrentAmount or CurrentAmount < DesiredQuantity then
            return false
        end
    end

    return true
end

local CharName = Player.getName()

-- Funcao para enviar mensagem para o Telegram
function enviarMensagemTelegram(mensagem)
    local url = "https://api.telegram.org/bot" .. botToken .. "/sendMessage"
    local corpoRequisicao = "chat_id=" .. chatID .. "&text=[" ..string.upper(CharName).. " ALERTA!]\n" .. mensagem

    local resposta, status, headers = http.request {
        url = url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["Content-Length"] = #corpoRequisicao
        },
        source = ltn12.source.string(corpoRequisicao),
        sink = ltn12.sink.table {}
    }

end

function enviarMensagem(tipo, mensagem)
    local respostaTelegram = enviarMensagemTelegram(mensagem)

    if respostaTelegram and respostaTelegram.ok then
        print("Mensagem enviada com sucesso para o Telegram!")
    else
        print("Erro ao enviar mensagem para o Telegram (" .. tipo .. ").")
        print("Detalhes:", JSON.encode(respostaTelegram))
    end
end

function table.isStrIn(tbl, str)
    if not str then return end
    lowercaseStr = str:lower()  -- Convertendo para minusculas para tornar a verificacao de caso-insensitivo
    for _, value in pairs(tbl) do
        if lowercaseStr:find(value:lower()) then
            return true
        end
    end
    return false
end

function SayBalance(number)
	if number >= 1000000 then
		NumberBalance = ""..math.floor(number*0.000001).. "kk"
		elseif number < 1000000 then
		NumberBalance = ""..(number).. " gps"
	end
		return NumberBalance
end

local function MagicEffect(type, x, y, z)
	if (type == 56 or type == 57) and not Player.getState(Enums.States.STATE_PIGEON) then
		firstMsgGM = true
	end
end
Game.registerEvent(Game.Events.MAGIC_EFFECT, MagicEffect)

local function handler(authorName, authorLevel, type, x, y, z, text)

	local balance = text:match("balance is (%d+) gold.")
	
	if type == 4 then
		msg = "Private Message!\n" ..authorName.. " [" ..authorLevel.. "]: " ..text
		firstMsgPrivate = true
	end
	
	if type == 1 and not Player.getState(Enums.States.STATE_PIGEON) and string.lower(authorName) ~= string.lower(CharName) and Alarm_LocalChat then
		msg = "Local Chat Message!\n" ..authorName.. " [" ..authorLevel.. "]: " ..text
		firstMsgPrivate = true
	end	
	
	if balance then
		msgBalance = "Balance atual: "..SayBalance(tonumber(balance))
		firstMsgBalance = true
	end
	
	if type == 36 then
		if table.isStrIn({'professor', CharName}, text) then
			firstMsgGM = true
		end
	end	
end
Game.registerEvent(Game.Events.TALK, handler)

frags = 0
deads = 0
function onInternalTextMessage(messageData)
    local texto = messageData.text
    local injust = texto:match("Warning! The murder of (.+) was not justified")
	local dead = texto:match("You are dead.")
	local dust = texto:match("You have collected (%d+) dusts")
	local level, tolevel = texto:match("You advanced from Level (.+) to Level (.+).")
	local magicLevel = texto:match("You advanced to magic level (.+).")
	local SkillName, SkillLevel = texto:match("You advanced to (.+) level (.+).")
	
    if injust then
		frags = frags + 1
		msginjust = "Voce matou o player " ..injust.. "!\nMatou ate agora: " ..frags.. " players desde que a monitoracao foi ligada."
		firstMsgInjust = true
    end
	
    if dead then
		deads = deads + 1
		msgDead = "Voce morreu pela " ..deads.. " vez."
		firstMsgDead = true
    end	
	
    if dust then
		msgDust = "Voce esta com dusts full! Ja pode converter!"
		firstMsgDust = true
    end	
	
	if level and tolevel then
		msgLevel = "You advanced from Level "..level.." to Level "..tolevel.."."
		firstMsgLevel = true
    end	

	if magicLevel then
		msgMagicLevel = "You advanced to magic level " ..magicLevel.. "."
		firstMsgmagicLevel = true
    end		

	if SkillName and SkillLevel then
		msgSkill = "You advanced to " ..SkillName.. " level " ..SkillLevel.. "."
		firstMsgSkill = true
    end		
	
    for i=1, #itens do
        local dropedLoot = string.match(messageData.text:lower(),itens[i]:lower())
        if dropedLoot then
			MsgDrop = "Uhuuuuuuuul!\nVoce dropou um " ..dropedLoot.. "!"
            firstMsgDrop = true
            break
        end
    end	

end

Game.registerEvent(Game.Events.TEXT_MESSAGE, onInternalTextMessage)

playerScreen = 0
-- Funcao para comparar duas tabelas
function table.equal(t1, t2)
    if #t1 ~= #t2 then
        return false
    end

    for i, v in ipairs(t1) do
        if type(v) == "table" then
            if not table.equal(v, t2[i]) then
                return false
            end
        else
            if v ~= t2[i] then
                return false
            end
        end
    end

    return true
end

-- Tabela para armazenar jogadores na tela
local jogadoresNaTelaAntigos = {}
local jogadoresSkullBranca = {}
local jogadoresSkullBrancaAntigos = {}
-- Funcao para verificar jogadores com skull branca
function verificarSkullBranca()
	if not Client.isConnected() then return end
    local jogadoresSkullBranca = {}

    for i, playerId in pairs(Map.getCreatureIds(true, true)) do
        local player = Creature(playerId)
        local Nome = player:getName()
        local VocationID = player:getVocation()
        local Vocation

        if VocationID == 1 then
            Vocation = "Elite Knight"
        elseif VocationID == 2 then
            Vocation = "Royal Paladin"
        elseif VocationID == 3 then
            Vocation = "Master Sorcerer"
        elseif VocationID == 4 then
            Vocation = "Elder Druid"
        end

        local skull = player:getSkull()

        if skull == Enums.Skulls.SKULL_WHITE or skull == Enums.Skulls.SKULL_YELLOW or skull == Enums.Skulls.SKULL_GREEN or skull == Enums.Skulls.SKULL_RED or skull == Enums.Skulls.SKULL_BLACK then
            table.insert(jogadoresSkullBranca, {Nome = Nome, Vocation = Vocation})
        end
    end

    -- Verifica se houve mudancas nos jogadores com Skull Branca
    mudancaJogadoresSkullBranca = not table.equal(jogadoresSkullBranca, jogadoresSkullBrancaAntigos)

    -- Atualiza a tabela de jogadores com Skull Branca antigos
    jogadoresSkullBrancaAntigos = jogadoresSkullBranca
end


function jogadorApareceu()
	if not Client.isConnected() then return end
    local jogadoresNaTela = {}
    
    for i, playerId in pairs(Map.getCreatureIds(true, true)) do
        local player = Creature(playerId)
        local Nome = player:getName()
        local VocationID = player:getVocation()
        local Vocation

        if VocationID == 1 then
            Vocation = "Elite Knight"
        elseif VocationID == 2 then
            Vocation = "Royal Paladin"
        elseif VocationID == 3 then
            Vocation = "Master Sorcerer"
        elseif VocationID == 4 then
            Vocation = "Elder Druid"
        end

        table.insert(jogadoresNaTela, {Nome = Nome, Vocation = Vocation})
    end

    -- Atualiza a variavel playerScreen
    playerScreen = #jogadoresNaTela

    -- Verifica se houve mudancas nos jogadores na tela
    local mudancaJogadores = not table.equal(jogadoresNaTela, jogadoresNaTelaAntigos)

    -- Atualiza a tabela de jogadores antigos
    jogadoresNaTelaAntigos = jogadoresNaTela
    return mudancaJogadores
end

lastMoveTime = os.time() -- Tempo da ultima movimentacao
myPos = Map.getCameraPosition()
myPos2 = Map.getCameraPosition()

-- Funcao principal para verificar e resolver o "stuck" do jogador
function checkAndMove()
	myPos = Map.getCameraPosition()
		if myPos.x ~= myPos2.x and myPos.y ~= myPos2.y then
			myPos2 = myPos
			lastMoveTime = os.time()	
		end
	if (os.time() - lastMoveTime) >= maxStillTime then
		lastMoveTime = os.time()
		firstMsgStuck = true
		return true
	end
end

-- Verifica se um jogador apareceu e envia mensagem para o Telegram
Timer("aloalo", function()
    if jogadorApareceu() and playerScreen > 1 and Alarm_PlayerOnScreen and not Player.getState(Enums.States.STATE_PIGEON) then
        local mensagem = "Jogadores na tela: " .. (playerScreen-1) .. "\n\n"

        for _, jogador in ipairs(jogadoresNaTelaAntigos) do
			if CharName ~= jogador.Nome then
				mensagem = mensagem .. "Char: " .. jogador.Nome .. "\nVocation: " .. jogador.Vocation .. "\n\n"
			end
        end

        local respostaTelegram = enviarMensagemTelegram(mensagem)

        if respostaTelegram and respostaTelegram.ok then
            print("Mensagem enviada com sucesso para o Telegram!")
        else
            print("Erro ao enviar mensagem para o Telegram.")
            print("Detalhes:", JSON.encode(respostaTelegram))
        end
    end
	
	verificarSkullBranca()
	
    if mudancaJogadoresSkullBranca and Alarm_PkOnScreen and not Player.getState(Enums.States.STATE_PIGEON) then
        local mensagem = "Jogadores com Skull Branca: "..#jogadoresSkullBrancaAntigos.. "\n\n"

        for _, jogador in ipairs(jogadoresSkullBrancaAntigos) do
            mensagem = mensagem .. "Char: " .. jogador.Nome .. "\nVocation: " .. jogador.Vocation .. "\n\n"
        end

        local respostaTelegram = enviarMensagemTelegram(mensagem)

        if respostaTelegram and respostaTelegram.ok then
            print("Mensagem de Skull Branca enviada com sucesso para o Telegram!")
        else
            print("Erro ao enviar mensagem de Skull Branca para o Telegram.")
            print("Detalhes:", JSON.encode(respostaTelegram))
        end
    end
	
	if checkAndMove() and firstMsgStuck and Alarm_Stuck then
		local mensagem = "Voce esta parado no mesmo lugar por muito tempo, verifique seu char!"
		local respostaTelegram = enviarMensagemTelegram(mensagem)
		firstMsgStuck = false
        if respostaTelegram and respostaTelegram.ok then
            print("Mensagem enviada com sucesso para o Telegram!")
        else
            print("Erro ao enviar mensagem para o Telegram.")
            print("Detalhes:", JSON.encode(respostaTelegram))
        end
	end
end, 50)


firstMsgStuck = true
firstMsgCap = true
firstMsgConnected = true
firstMsgSupply = true
firstMsgPK = true
firstMsgStamina = true

-- Verificacao e envio de mensagens
Timer("monitor", function()
    if not Client.isConnected() and firstMsgConnected and Alarm_connected then
        enviarMensagem("Desconectado", "Voce foi desconectado do jogo.")
        firstMsgConnected = false
    elseif Client.isConnected() and Alarm_connected then
        firstMsgConnected = true
    end

    if not Client.isConnected() then return end

    if firstMsgPrivate and Alarm_Private then
        enviarMensagem("Private", msg)
        firstMsgPrivate = false
    end

    if firstMsgInjust and Alarm_Injust then
        enviarMensagem("Injustica", msginjust)
        firstMsgInjust = false
    end

    if firstMsgDead and Alarm_Dead then
        enviarMensagem("Morte", msgDead)
        firstMsgDead = false
    end

    if firstMsgDust and Alarm_Forja then
        enviarMensagem("Dust", msgDust)
        firstMsgDust = false
    end	
	
    if firstMsgLevel and Alarm_Level then
        enviarMensagem("Level", msgLevel)
        firstMsgLevel = false
    end	

    if firstMsgmagicLevel and Alarm_Skill then
        enviarMensagem("MagicLevel", msgMagicLevel)
        firstMsgmagicLevel = false
    end	

    if firstMsgSkill and Alarm_Skill then
        enviarMensagem("Skill", msgSkill)
        firstMsgSkill = false
    end		

    if firstMsgBalance and Alarm_Balance then
        enviarMensagem("Balanceamento", msgBalance)
        firstMsgBalance = false
    end
	
    if firstMsgDrop and Alarm_DropItem then
        enviarMensagem("Balanceamento", MsgDrop)
        firstMsgDrop = false
    end	

    if firstMsgGM and Alarm_GM then
        enviarMensagem("GM", "ALERTA VERMELHO!\nO GM esta na tela!\nCorra para fazer a verificacao")
        firstMsgGM = false
    end
	
	if not CheckSupply(SupplyList) and firstMsgSupply and Alarm_Supplie then
		enviarMensagem("Supply", "Suas potions estao acabando!")
		firstMsgSupply = false
	elseif CheckSupply(SupplyList) then
		firstMsgSupply = true
	end
	
	Cap = Player.getCapacity()
	if Cap <= (CapMin*100) and firstMsgCap and Alarm_Cap then
		enviarMensagem("Cap", "Sua Cap acabou!")
		firstMsgCap = false
	elseif Cap > (CapMin*100) then
		firstMsgCap = true
	end

	Stamina = Player.getStamina()
	if Stamina < (Min_Stamina*60) and firstMsgStamina and Alarm_Stamina then
		enviarMensagem("Stamina", "Sua Stamina esta a baixo do esperado!")
		firstMsgStamina = false
	elseif Stamina >= (Min_Stamina*60) then
		firstMsgStamina = true
	end	
	
	life = Player.getHealthPercent()
	if life <= 20 and firstMsglife and Alarm_LowLife then
		enviarMensagem("life", "Sua life esta mais baixa que 20%, cuidado!")
		firstMsglife = false
	elseif life >= 30 then
		firstMsglife = true
	end	
	
	mana = Player.getManaPercent()
	if mana <= 20 and firstMsgMana and Alarm_LowMana then
		enviarMensagem("Mana", "Sua Mana esta mais baixa que 20%, cuidado!")
		firstMsgMana = false
	elseif mana >= 30 then
		firstMsgMana = true
	end	
	
	if (Player.getState(Enums.Skulls.SKULL_WHITE) or Player.getState(Enums.Skulls.SKULL_RED or Player.getState(Enums.Skulls.SKULL_BLACK))) and firstMsgPK and Alarm_PK then
		enviarMensagem("PK", "Preste atencao!\nVoce esta PK!")
		firstMsgPK = false
	elseif not Player.getState(Enums.Skulls.SKULL_WHITE) then
		firstMsgPK = true
	end
	
end, 50)


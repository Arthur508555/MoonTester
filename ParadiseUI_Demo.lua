--[[
    Paradise UI v4 - demonstração simples com painel de diagnóstico.
    A biblioteca fica separada deste script.
]]

local LIBRARY_URL = "https://raw.githubusercontent.com/Arthur508555/MoonTester/main/ParadiseUI_v4.lua"

local okHttp, source = pcall(function()
    return game:HttpGet(LIBRARY_URL)
end)
if not okHttp or type(source) ~= "string" or source == "" then
    error("[ParadiseUI Demo] HTTP_GET_FAILED: " .. tostring(source))
end

if type(loadstring) ~= "function" then
    error("[ParadiseUI Demo] LOADSTRING_UNAVAILABLE: este ambiente não permite compilar código remoto. Em um projeto próprio, use a library como ModuleScript e require().")
end

local okCompile, chunk, compileError = pcall(loadstring, source)
if not okCompile or type(chunk) ~= "function" then
    error("[ParadiseUI Demo] COMPILE_FAILED: " .. tostring(okCompile and compileError or chunk))
end

local okRun, Paradise = pcall(chunk)
if not okRun then
    error("[ParadiseUI Demo] LIBRARY_RUNTIME_FAILED: " .. tostring(Paradise))
end
if type(Paradise) ~= "table" or Paradise.__ParadiseLibrary ~= true then
    error("[ParadiseUI Demo] INVALID_LIBRARY_RETURN: a versão carregada não é a Paradise UI v4.")
end

local Window, windowError = Paradise:CreateWindow({
    Name = "Paradise UI Test",
    LoadingTitle = "Paradise UI",
    LoadingSubtitle = "componentes + diagnóstico",
    ToggleUIKeybind = "RightShift",
})
if not Window then
    error("[ParadiseUI Demo] WINDOW_CREATE_FAILED: " .. tostring(windowError) .. "\n" .. Paradise.Diagnostics.Report())
end

local Main = Window:CreateTab("Principal", "🌴")
if not Main then
    error("[ParadiseUI Demo] TAB_CREATE_FAILED:\n" .. Paradise.Diagnostics.Report())
end

local tabOk, tabIssues = Paradise.Diagnostics.CheckTab(Main)
if not tabOk then
    warn("[ParadiseUI Demo] TAB_VALIDATION_FAILED: " .. table.concat(tabIssues, " | "))
end

Main:CreateSection("Componentes básicos")
local status = Main:CreateLabel("Status: aguardando teste")

Main:CreateButton({
    Name = "Testar botão",
    Callback = function()
        if status and status.Set then status:Set("Status: botão clicado") end
        Paradise:Notify({
            Title = "Paradise UI",
            Content = "O botão está funcionando!",
            Duration = 3,
        })
    end,
})

Main:CreateToggle({
    Name = "Toggle de demonstração",
    CurrentValue = false,
    Callback = function(value) print("Toggle:", value) end,
})

Main:CreateCheckbox({
    Name = "Checkbox de demonstração",
    CurrentValue = true,
    Callback = function(value) print("Checkbox:", value) end,
})

Main:CreateSlider({
    Name = "Slider de demonstração",
    Range = {0, 100},
    Increment = 5,
    CurrentValue = 35,
    Suffix = "%",
    Callback = function(value) print("Slider:", value) end,
})

Main:CreateDropdown({
    Name = "Escolha uma opção",
    Options = {"Opção A", "Opção B", "Opção C"},
    CurrentOption = {"Opção A"},
    Callback = function(option) print("Dropdown:", option[1]) end,
})

Main:CreateInput({
    Name = "Texto de teste",
    PlaceholderText = "Digite algo...",
    RemoveTextAfterFocusLost = false,
    Callback = function(value)
        if status and status.Set then status:Set("Texto recebido: " .. value) end
    end,
})

Main:CreateKeybind({
    Name = "Tecla de teste",
    CurrentKeybind = "F",
    Callback = function()
        Paradise:Notify({
            Title = "Keybind",
            Content = "A tecla F foi pressionada.",
            Duration = 2,
        })
    end,
})

Main:CreateParagraph({
    Title = "Sobre este exemplo",
    Content = "Paradise UI v4: demonstração dos componentes e da compatibilidade com a API clássica do Rayfield.",
})

Main:CreateColorPicker({
    Name = "Cor de teste",
    Color = Color3.fromRGB(75, 190, 235),
    Callback = function(color) print("ColorPicker:", color) end,
})

Main:CreateDivider("Fim dos componentes")

local DebugTab = Window:CreateTab("Diagnóstico", "🛠️")
DebugTab:CreateSection("Verificações")
local reportLabel = DebugTab:CreateParagraph({
    Title = "Estado da biblioteca",
    Content = "Use os botões para executar os diagnósticos.",
})

DebugTab:CreateButton({
    Name = "Executar autodiagnóstico",
    Callback = function()
        local ok, results = Paradise.Diagnostics.SelfTest(Window, Main)
        local lines = {}
        for _, item in ipairs(results) do
            table.insert(lines, (item.Passed and "[OK] " or "[ERRO] ") .. item.Name
                .. (item.Details ~= "" and (": " .. item.Details) or ""))
        end
        if reportLabel and reportLabel.Set then reportLabel:Set(table.concat(lines, "\n")) end
        print(Paradise.Diagnostics.Report())
    end,
})

DebugTab:CreateButton({
    Name = "Imprimir relatório completo",
    Callback = function()
        print(Paradise.Diagnostics.Report())
        Paradise:Notify({
            Title = "Diagnóstico",
            Content = "Relatório enviado ao console.",
            Duration = 3,
        })
    end,
})

DebugTab:CreateButton({
    Name = "Verificar se a UI está ativa",
    Callback = function()
        local ok = Paradise.Diagnostics.CheckUsage()
        Paradise:Notify({
            Title = "Verificação",
            Content = ok and "A interface está ativa." or "Veja o console para detalhes.",
            Duration = 3,
        })
    end,
})

local Extra = Window:CreateTab("Extras", "🌊")
Extra:CreateLabel("Arraste a barra inferior para mover a janela.")
Extra:CreateButton({
    Name = "Fechar interface",
    Callback = function() Window:Unload() end,
})

task.defer(function()
    Paradise.Diagnostics.CheckUsage()
    local ok, results = Paradise.Diagnostics.SelfTest(Window, Main)
    print("[ParadiseUI Demo] Inicialização:", ok, #results, "verificações.")
end)

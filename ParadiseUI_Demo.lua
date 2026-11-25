--[[
    Paradise UI - exemplo genérico de uso
    Carrega apenas a library e monta controles de demonstração.
    Os callbacks são exemplos: não alteram o personagem nem o jogo.
]]

local Paradise = loadstring(game:HttpGet("https://raw.githubusercontent.com/Arthur508555/MoonTester/main/ParadiseUI.lua"))()

local Window = Paradise:CreateWindow({
    Name = "Paradise UI Test",
    LoadingTitle = "Paradise UI",
    LoadingSubtitle = "Rayfield API compatibility demo",
    ToggleUIKeybind = "RightShift",
})

local Main = Window:CreateTab("Principal", "🌴")
Main:CreateSection("Componentes básicos")

local status = Main:CreateLabel("Status: aguardando teste")
Main:CreateButton({
    Name = "Testar botão",
    Callback = function()
        status:Set("Status: botão clicado")
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
    Callback = function(value)
        print("Toggle:", value)
    end,
})

Main:CreateCheckbox({
    Name = "Checkbox de demonstração",
    CurrentValue = true,
    Callback = function(value)
        print("Checkbox:", value)
    end,
})

Main:CreateSlider({
    Name = "Slider de demonstração",
    Range = {0, 100},
    Increment = 5,
    CurrentValue = 35,
    Suffix = "%",
    Callback = function(value)
        print("Slider:", value)
    end,
})

Main:CreateDropdown({
    Name = "Escolha uma opção",
    Options = {"Opção A", "Opção B", "Opção C"},
    CurrentOption = {"Opção A"},
    Callback = function(option)
        print("Dropdown:", option[1])
    end,
})

Main:CreateInput({
    Name = "Texto de teste",
    PlaceholderText = "Digite algo...",
    RemoveTextAfterFocusLost = false,
    Callback = function(value)
        status:Set("Texto recebido: " .. value)
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
    Content = "Esta janela demonstra os controles da Paradise UI com nomes de métodos compatíveis com a API clássica do Rayfield.",
})

Main:CreateColorPicker({
    Name = "Cor de teste",
    Color = Color3.fromRGB(75, 190, 235),
    Callback = function(color)
        print("ColorPicker:", color)
    end,
})

Main:CreateDivider("Fim dos componentes")

local Extra = Window:CreateTab("Extras", "🌊")
Extra:CreateLabel("Arraste a barra inferior para mover a janela.")
Extra:CreateButton({
    Name = "Fechar interface",
    Callback = function()
        Window:Unload()
    end,
})

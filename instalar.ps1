# One-click setup: HyperX (+noise filter) + GPT (Brave) + Discord through Voicemeeter Potato.
. "$PSScriptRoot\comum.ps1"

Say "`n=== GPT + Discord: instalacao ===`n" Cyan

# 1) Voicemeeter Potato
if (-not (Test-Path $VM_EXE)) {
    Say 'Baixando o Voicemeeter Potato (site oficial vb-audio.com)...'
    $x = Get-Zip $POTATO_URL 'potato'
    $setup = Join-Path $x 'Voicemeeter8Setup.exe'
    $sig = Get-AuthenticodeSignature $setup
    if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'BUREL VINCENT') { throw 'Assinatura do instalador invalida. Parei.' }
    # Resume automatically after the reboot the driver needs.
    $cmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' 'GptDiscordVoz' $cmd
    Say "`nVai abrir o instalador. Clique em SIM, depois em INSTALL." Yellow
    Say 'Depois REINICIE o PC. A configuracao continua sozinha quando o Windows ligar.' Yellow
    Start-Process $setup -Wait
    Read-Host "`nAperte ENTER pra fechar"
    exit
}

Ensure-Svv

# 2) Voicemeeter: devices, filter, who-hears-who
Say 'Configurando o Voicemeeter...'
Vm-Connect
Vm-Set 'Option.buffer.wdm' 1024
Vm-Set 'Bus[0].device.wdm' $HEADSET      # A1 = your headset (also the master clock)
Vm-Set 'Strip[0].device.wdm' $MIC        # Input 1 = HyperX
Start-Sleep 3
$buses = 'A1','A2','A3','A4','A5','B1','B2','B3'
# A1 = you hear | B1 = Discord/apps hear (mic "Voicemeeter Out B1") | B2 = GPT hears (mic "Voicemeeter Out B2")
$routes = @{
    0 = @('B1','B2')   # your voice  -> Discord + GPT
    5 = @('A1','B1')   # Brave (GPT) -> you + Discord   (never B2)
    6 = @('A1')        # AUX         -> you only
    7 = @('A1','B2')   # Discord     -> you + GPT       (never B1)
}
for ($s = 0; $s -lt 8; $s++) {
    foreach ($b in $buses) { Vm-Set "Strip[$s].$b" ([int]($routes[$s] -contains $b)) }
    Vm-Set "Strip[$s].Mute" 0
}
Vm-Set 'Strip[0].Denoiser' 5
Vm-Sync

# 3) Start with Windows
$w = New-Object -ComObject WScript.Shell
$l = $w.CreateShortcut($STARTUP); $l.TargetPath = $VM_EXE; $l.Save()

# 4) Windows: Brave sound -> Voicemeeter Input; default mic -> Voicemeeter Out B1 (your voice + GPT)
Say 'Configurando o Windows...'
& $SVV /SetAppDefault (Device-Id 'Voicemeeter Input' 'Render') all brave.exe | Out-Null
& $SVV /SetDefault (Device-Id 'Voicemeeter Out B1' 'Capture') all | Out-Null

# 5) Brave microphone = Voicemeeter Out B2
$b = Brave-SetMicPref $true
if ($b -eq 'brave-aberto') {
    Say "`nFeche o Brave por completo e aperte ENTER (pra eu escolher o microfone dele)." Yellow
    Read-Host | Out-Null
    $b = Brave-SetMicPref $true
}

# 6) Self-check
Start-Sleep 1; Vm-Sync
$fail = @()
if ((Vm-GetStr 'Strip[0].device.name') -notmatch 'QuadCast') { $fail += 'microfone HyperX no Voicemeeter' }
if ((Vm-GetStr 'Bus[0].device.name') -notmatch 'G435') { $fail += 'fone G435 no Voicemeeter' }
if ((Vm-Get 'Strip[0].Denoiser') -le 0) { $fail += 'filtro de ruido' }
foreach ($s in $routes.Keys) { foreach ($bb in $buses) {
    if ((Vm-Get "Strip[$s].$bb") -ne [int]($routes[$s] -contains $bb)) { $fail += "rota Strip[$s].$bb" } } }
if (-not (Test-Path $STARTUP)) { $fail += 'abrir com o Windows' }
if ($b -notin 'ok','sem-brave') { $fail += 'microfone do Brave (Brave ainda aberto)' }

if ($fail.Count) { Say "`nDeu problema em: $($fail -join ', ')" Red }
else { Say "`nTudo certo!" Green }

Say @"

FALTA SO O DISCORD (ele nao deixa configurar por fora):
  Configuracoes > Voz e video
    Microfone   = Voicemeeter Out B1
    Alto-falante = Voicemeeter VAIO3 Input

No chatgpt.com, se pedir microfone, escolha: Voicemeeter Out B2
"@ Yellow
Read-Host "`nAperte ENTER pra fechar"

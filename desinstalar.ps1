# One-click undo: puts the PC back to SteelSeries only and removes Voicemeeter Potato.
. "$PSScriptRoot\comum.ps1"

Say "`n=== GPT + Discord: desinstalacao ===`n" Cyan
Ensure-Svv

# 1) Default mic back to SteelSeries Sonar (HyperX with the SteelSeries filter)
& $SVV /SetDefault $SONAR_MIC all | Out-Null
Say 'Microfone padrao do Windows: SteelSeries Sonar - Microphone.'

# 2) Remove per-app routes that point at Voicemeeter (Brave, etc.). Apps go back to the default device.
$n = 0
Get-ChildItem $POLICY_KEY -ErrorAction SilentlyContinue | ForEach-Object {
    $v = (Get-ItemProperty $_.PSPath).'(default)'
    if ($v -match 'vbvoicemeeter') { Remove-Item $_.PSPath -Recurse; $n++ }
}
Say "Saidas de som por app restauradas ($n)."

# 3) Brave microphone preference
$b = Brave-SetMicPref $false
if ($b -eq 'brave-aberto') {
    Say "`nFeche o Brave por completo e aperte ENTER." Yellow
    Read-Host | Out-Null
    [void](Brave-SetMicPref $false)
}

# 4) Stop Voicemeeter, remove autostart, uninstall
Remove-Item $STARTUP -ErrorAction SilentlyContinue
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' 'GptDiscordVoz' -ErrorAction SilentlyContinue
Get-Process voicemeeter* -ErrorAction SilentlyContinue | Stop-Process -Force
$un = Join-Path $VM_DIR 'Voicemeeter8Setup.exe'
if (Test-Path $un) {
    Say "`nVai abrir o desinstalador do Voicemeeter. Clique em SIM e depois em UNINSTALL." Yellow
    Start-Process $un -Wait
}

Say @"

Pronto. No Discord, volte em Configuracoes > Voz e video:
  Microfone    = SteelSeries Sonar - Microphone
  Alto-falante = o que voce usava (ex: SteelSeries Sonar - Chat)

Reinicie o PC pra terminar de remover o Voicemeeter.
"@ Green
Read-Host "`nAperte ENTER pra fechar"

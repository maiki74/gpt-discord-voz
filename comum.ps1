# Shared helpers for instalar.ps1 / desinstalar.ps1 (ASCII only: PowerShell 5.1 reads BOM-less files as ANSI).
$ErrorActionPreference = 'Stop'

$VM_DIR   = 'C:\Program Files (x86)\VB\Voicemeeter'
$VM_EXE   = Join-Path $VM_DIR 'voicemeeter8x64.exe'
$VM_DLL   = Join-Path $VM_DIR 'VoicemeeterRemote64.dll'
$POTATO_URL = 'https://download.vb-audio.com/Download_CABLE/Voicemeeter8Setup_v3130.zip'
$SVV_URL  = 'https://www.nirsoft.net/utils/soundvolumeview-x64.zip'
$DATA     = Join-Path $env:APPDATA 'gpt-discord-voz'
$SVV      = Join-Path $DATA 'SoundVolumeView.exe'
$STARTUP  = Join-Path ([Environment]::GetFolderPath('Startup')) 'Voicemeeter Potato.lnk'
$BRAVE_PREFS = Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser-Nightly\User Data\Default\Preferences'
$POLICY_KEY = 'HKCU:\Software\Microsoft\Internet Explorer\LowRegistry\Audio\PolicyConfig\PropertyStore'

# Devices of this PC (names exactly as Windows shows them)
$MIC        = 'Microfone (HyperX QuadCast)'
$HEADSET    = 'Fone de ouvido do headset (G435 Wireless Gaming Headset)'
$SONAR_MIC  = 'SteelSeries Sonar Virtual Audio Device\Device\SteelSeries Sonar - Microphone\Capture'

function Say($msg, $color = 'Gray') { Write-Host $msg -ForegroundColor $color }

function Ensure-Dir($p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null } }

function Get-Zip($url, $name) {
    # Each download gets its own fresh folder (untrusted content stays isolated).
    $dir = Join-Path $env:TEMP ("gdv_" + $name + "_" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    Ensure-Dir $dir
    $zip = Join-Path $dir "$name.zip"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -UserAgent 'Mozilla/5.0'
    Expand-Archive -Path $zip -DestinationPath (Join-Path $dir 'x') -Force
    return (Join-Path $dir 'x')
}

function Ensure-Svv {
    if (Test-Path $SVV) { return }
    Ensure-Dir $DATA
    $x = Get-Zip $SVV_URL 'svv'
    Copy-Item (Join-Path $x 'SoundVolumeView.exe') $SVV
}

function Svv-Devices {
    $csv = Join-Path $env:TEMP 'gdv_devices.csv'
    & $SVV /scomma $csv /Columns 'Name,Type,Direction,Default,Item ID' | Out-Null
    for ($i = 0; $i -lt 20 -and -not (Test-Path $csv); $i++) { Start-Sleep -Milliseconds 250 }
    Start-Sleep -Milliseconds 500
    $rows = Import-Csv $csv | Where-Object Type -eq 'Device'
    Remove-Item $csv -ErrorAction SilentlyContinue
    return $rows
}

function Device-Id($name, $direction) {
    $d = Svv-Devices | Where-Object { $_.Name -eq $name -and $_.Direction -eq $direction } | Select-Object -First 1
    if (-not $d) { throw "Dispositivo nao encontrado: $name ($direction)" }
    return $d.'Item ID'
}

# --- Voicemeeter Remote API ---
if (-not ('VMR' -as [type])) {
    Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices; using System.Text;
public static class VMR {
  [DllImport(@"$VM_DLL")] public static extern int VBVMR_Login();
  [DllImport(@"$VM_DLL")] public static extern int VBVMR_Logout();
  [DllImport(@"$VM_DLL")] public static extern int VBVMR_GetVoicemeeterType(out int t);
  [DllImport(@"$VM_DLL")] public static extern int VBVMR_IsParametersDirty();
  [DllImport(@"$VM_DLL")] public static extern int VBVMR_SetParameterFloat(string n, float v);
  [DllImport(@"$VM_DLL")] public static extern int VBVMR_SetParameterStringA(string n, string v);
  [DllImport(@"$VM_DLL")] public static extern int VBVMR_GetParameterFloat(string n, out float v);
  [DllImport(@"$VM_DLL")] public static extern int VBVMR_GetParameterStringA(string n, StringBuilder v);
}
"@ -ErrorAction SilentlyContinue
}

function Vm-Connect {
    if (-not (Get-Process voicemeeter8x64 -ErrorAction SilentlyContinue)) { Start-Process $VM_EXE }
    [void][VMR]::VBVMR_Login()
    $t = 0
    for ($i = 0; $i -lt 30; $i++) {
        if ([VMR]::VBVMR_GetVoicemeeterType([ref]$t) -eq 0 -and $t -eq 3) { break }
        Start-Sleep 1
    }
    if ($t -ne 3) { throw 'Voicemeeter Potato nao respondeu.' }
    Vm-Sync
}
function Vm-Sync { for ($i = 0; $i -lt 6; $i++) { [void][VMR]::VBVMR_IsParametersDirty(); Start-Sleep -Milliseconds 200 } }
function Vm-Set($n, $v) {
    $r = if ($v -is [string]) { [VMR]::VBVMR_SetParameterStringA($n, $v) } else { [VMR]::VBVMR_SetParameterFloat($n, [float]$v) }
    if ($r -ne 0) { throw "Voicemeeter recusou $n (codigo $r)" }
}
function Vm-Get($n) { $v = 0.0; [void][VMR]::VBVMR_GetParameterFloat($n, [ref]$v); return $v }
function Vm-GetStr($n) { $sb = New-Object System.Text.StringBuilder 512; [void][VMR]::VBVMR_GetParameterStringA($n, $sb); return $sb.ToString().Trim() }

# Brave mic preference list (Brave must be closed: it rewrites Preferences on exit).
function Brave-SetMicPref([bool]$add) {
    if (-not (Test-Path $BRAVE_PREFS)) { return 'sem-brave' }
    if (Get-Process brave -ErrorAction SilentlyContinue) { return 'brave-aberto' }
    Copy-Item $BRAVE_PREFS "$BRAVE_PREFS.bak-gpt-discord-voz" -Force
    $dev = 'Voicemeeter Out B2 (VB-Audio Voicemeeter VAIO)'
    $py = @"
import json,sys
p,dev,add=sys.argv[1],sys.argv[2],sys.argv[3]=='1'
j=json.load(open(p,encoding='utf-8'))
r=j.setdefault('media',{}).setdefault('audio_input',{}).setdefault('user_preference_ranking',[])
r[:]=[x for x in r if 'Voicemeeter' not in x]
if add: r.insert(0,dev)
json.dump(j,open(p,'w',encoding='utf-8'),ensure_ascii=False,separators=(',',':'))
"@
    $tmp = Join-Path $env:TEMP 'gdv_brave.py'
    Set-Content -Path $tmp -Value $py -Encoding ASCII
    py -I $tmp $BRAVE_PREFS $dev ($(if ($add) { '1' } else { '0' }))
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao editar as preferencias do Brave.' }
    Remove-Item $tmp
    return 'ok'
}

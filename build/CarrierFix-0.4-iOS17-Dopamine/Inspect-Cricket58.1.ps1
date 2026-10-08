# Read-only integrity and compatibility check for Apple's Cricket 58.1 IPCC.
# This script never installs a carrier bundle or changes anything on an iPhone.
param(
    [string]$IOSVersion = '17.1',
    [string]$DeviceModel = 'iPhone16,2'
)

$ErrorActionPreference = 'Stop'
$appleURL = 'https://updates.cdn-apple.com/20240513/carrierbundles/032-23478/E247835C-8950-4A31-A430-A6DB27A40158/ATT_aio_US_iPhone.ipcc'
$expectedSHA384 = '55CED9623258B24B76670A5CA19CB5F53D4B23F7B7389E1257AAD8BED5BA981CB1241342B6740945F675FBB7BD0B29B5'
$targetMinimumIOS = [Version]'17.5'
$download = [IO.Path]::GetTempFileName()
$zip = $null

try {
    $currentIOS = [Version]$IOSVersion
    if (-not [string]::Equals($DeviceModel, 'iPhone16,2', [StringComparison]::Ordinal)) {
        throw 'This research check is restricted to the reported iPhone16,2 (iPhone 15 Pro Max).'
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri $appleURL -OutFile $download -TimeoutSec 45
    $actualSHA384 = (Get-FileHash -LiteralPath $download -Algorithm SHA384).Hash
    if ($actualSHA384 -ne $expectedSHA384) {
        throw "Apple IPCC SHA-384 mismatch: $actualSHA384. The downloaded file is not trusted."
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($download)
    $requiredFiles = @(
        'Payload/ATT_aio_US.bundle/carrier.plist',
        'Payload/ATT_aio_US.bundle/Info.plist',
        'Payload/ATT_aio_US.bundle/version.plist',
        'Payload/ATT_aio_US.bundle/signatures/common.plist',
        'Payload/ATT_aio_US.bundle/overrides_D83_D84_D37_D38.plist',
        'Payload/ATT_aio_US.bundle/overrides_D83_D84_D37_D38.der.pri'
    )
    $present = @{}
    foreach ($entry in $zip.Entries) { $present[$entry.FullName] = $true }
    foreach ($name in $requiredFiles) {
        if (-not $present.ContainsKey($name)) { throw "Required carrier file missing: $name" }
    }

    Write-Output 'Cricket ATT_aio_US 58.1: original Apple download verified (SHA-384).'
    Write-Output "Source: $appleURL"
    Write-Output "Model: $DeviceModel; iOS: $currentIOS"
    Write-Output 'Signature files and iPhone 15 Pro Max override: present (signature validity was not checked on-device).'
    Write-Output 'Apple OTA published compatibility minimum (from carrier manifest index): iOS 17.5.'
    if ($currentIOS -lt $targetMinimumIOS) {
        Write-Output 'RESULT: BLOCKED for this iOS version. Do not install, force-install, or replace the carrier overlay.'
    } else {
        Write-Output 'RESULT: Source version gate passes, but model/carrier acceptance and rollback remain unverified. No installation was attempted.'
    }
} finally {
    if ($null -ne $zip) { $zip.Dispose() }
    if (Test-Path -LiteralPath $download) { Remove-Item -LiteralPath $download -Force }
}

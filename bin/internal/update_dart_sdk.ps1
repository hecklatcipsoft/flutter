# Copyright 2014 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


# ---------------------------------- NOTE ---------------------------------- #
#
# Please keep the logic in this file consistent with the logic in the
# `update_dart_sdk.sh` script in the same directory to ensure that Flutter
# continues to work across all platforms!
#
# -------------------------------------------------------------------------- #

$ErrorActionPreference = "Stop"

$progName = Split-Path -parent $MyInvocation.MyCommand.Definition
$flutterRoot = (Get-Item $progName).parent.parent.FullName

$cachePath = "$flutterRoot\bin\cache"
$dartSdkPath = "$cachePath\dart-sdk"
$engineStamp = "$cachePath\engine-dart-sdk.stamp"
$engineVersion = (Get-Content "$flutterRoot\bin\internal\engine.version")

$oldDartSdkPrefix = "dart-sdk.old"

# Make sure that PowerShell has expected version.
$psMajorVersionRequired = 5
$psMajorVersionLocal = $PSVersionTable.PSVersion.Major
if ($psMajorVersionLocal -lt $psMajorVersionRequired) {
    Write-Host "Flutter requires PowerShell $psMajorVersionRequired.0 or newer."
    Write-Host "See https://flutter.dev/docs/get-started/install/windows for more."
    Write-Host "Current version is $psMajorVersionLocal."
    # Use exit code 2 to signal that shared.bat should exit immediately instead of retrying.
    exit 2
}

if ((Test-Path $engineStamp) -and ($engineVersion -eq (Get-Content $engineStamp))) {
    return
}

$dartSdkBaseUrl = $Env:FLUTTER_STORAGE_BASE_URL
if (-not $dartSdkBaseUrl) {
    $dartSdkBaseUrl = "https://storage.googleapis.com"
}
$dartZipName = "dart-sdk-windows-x64.zip"
$dartSdkUrl = "$dartSdkBaseUrl/flutter_infra/flutter/$engineVersion/$dartZipName"

if (Test-Path $dartSdkPath) {
    # Move old SDK to a new location instead of deleting it in case it is still in use (e.g. by IntelliJ).
    $oldDartSdkSuffix = 1
    while (Test-Path "$cachePath\$oldDartSdkPrefix$oldDartSdkSuffix") { $oldDartSdkSuffix++ }
    Rename-Item $dartSdkPath "$oldDartSdkPrefix$oldDartSdkSuffix"
}
New-Item $dartSdkPath -force -type directory | Out-Null
$dartSdkZip = "$cachePath\$dartZipName"

Try {
    Import-Module BitsTransfer
    Start-BitsTransfer -Source $dartSdkUrl -Destination $dartSdkZip -ErrorAction Stop
}
Catch {
    Write-Host "Downloading the Dart SDK using the BITS service failed, retrying with WebRequest..."
    # Invoke-WebRequest is very slow when the progress bar is visible - a 28
    # second download can become a 33 minute download. Disable it with
    # $ProgressPreference and then restore the original value afterwards.
    # https://github.com/flutter/flutter/issues/37789
    $OriginalProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $dartSdkUrl -OutFile $dartSdkZip
    $ProgressPreference = $OriginalProgressPreference
}

If (Get-Command 7z -errorAction SilentlyContinue) {
    # The built-in unzippers are painfully slow. Use 7-Zip, if available.
    & 7z x $dartSdkZip "-o$cachePath" -bd | Out-Null
} ElseIf (Get-Command 7za -errorAction SilentlyContinue) {
    # Use 7-Zip's standalone version 7za.exe, if available.
    & 7za x $dartSdkZip "-o$cachePath" -bd | Out-Null
} ElseIf (Get-Command Microsoft.PowerShell.Archive\Expand-Archive -errorAction SilentlyContinue) {
    # Use PowerShell's built-in unzipper, if available (requires PowerShell 5+).
    Microsoft.PowerShell.Archive\Expand-Archive $dartSdkZip -DestinationPath $cachePath
} Else {
    # As last resort: fall back to the Windows GUI.
    $shell = New-Object -com shell.application
    $zip = $shell.NameSpace($dartSdkZip)
    foreach($item in $zip.items()) {
        $shell.Namespace($cachePath).copyhere($item)
    }
}

Remove-Item $dartSdkZip
$engineVersion | Out-File $engineStamp -Encoding ASCII

# Try to delete all old SDKs.
Get-ChildItem -Path $cachePath | Where {$_.BaseName.StartsWith($oldDartSdkPrefix)} | Remove-Item -Recurse -ErrorAction SilentlyContinue

# SIG # Begin signature block
# MIIN8gYJKoZIhvcNAQcCoIIN4zCCDd8CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU54HgVv+C/mFNTyx6BUGBZN6t
# 8QygggpbMIIEmTCCA4GgAwIBAgIQcaC3NpXdsa/COyuaGO5UyzANBgkqhkiG9w0B
# AQsFADCBqTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDHRoYXd0ZSwgSW5jLjEoMCYG
# A1UECxMfQ2VydGlmaWNhdGlvbiBTZXJ2aWNlcyBEaXZpc2lvbjE4MDYGA1UECxMv
# KGMpIDIwMDYgdGhhd3RlLCBJbmMuIC0gRm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkx
# HzAdBgNVBAMTFnRoYXd0ZSBQcmltYXJ5IFJvb3QgQ0EwHhcNMTMxMjEwMDAwMDAw
# WhcNMjMxMjA5MjM1OTU5WjBMMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMdGhhd3Rl
# LCBJbmMuMSYwJAYDVQQDEx10aGF3dGUgU0hBMjU2IENvZGUgU2lnbmluZyBDQTCC
# ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJtVAkwXBenQZsP8KK3TwP7v
# 4Ol+1B72qhuRRv31Fu2YB1P6uocbfZ4fASerudJnyrcQJVP0476bkLjtI1xC72Ql
# WOWIIhq+9ceu9b6KsRERkxoiqXRpwXS2aIengzD5ZPGx4zg+9NbB/BL+c1cXNVeK
# 3VCNA/hmzcp2gxPI1w5xHeRjyboX+NG55IjSLCjIISANQbcL4i/CgOaIe1Nsw0Rj
# gX9oR4wrKs9b9IxJYbpphf1rAHgFJmkTMIA4TvFaVcnFUNaqOIlHQ1z+TXOlScWT
# af53lpqv84wOV7oz2Q7GQtMDd8S7Oa2R+fP3llw6ZKbtJ1fB6EDzU/K+KTT+X/kC
# AwEAAaOCARcwggETMC8GCCsGAQUFBwEBBCMwITAfBggrBgEFBQcwAYYTaHR0cDov
# L3QyLnN5bWNiLmNvbTASBgNVHRMBAf8ECDAGAQH/AgEAMDIGA1UdHwQrMCkwJ6Al
# oCOGIWh0dHA6Ly90MS5zeW1jYi5jb20vVGhhd3RlUENBLmNybDAdBgNVHSUEFjAU
# BggrBgEFBQcDAgYIKwYBBQUHAwMwDgYDVR0PAQH/BAQDAgEGMCkGA1UdEQQiMCCk
# HjAcMRowGAYDVQQDExFTeW1hbnRlY1BLSS0xLTU2ODAdBgNVHQ4EFgQUV4abVLi+
# pimK5PbC4hMYiYXN3LcwHwYDVR0jBBgwFoAUe1tFz6/Oy3r9MZIaarbzRutXSFAw
# DQYJKoZIhvcNAQELBQADggEBACQ79degNhPHQ/7wCYdo0ZgxbhLkPx4flntrTB6H
# novFbKOxDHtQktWBnLGPLCm37vmRBbmOQfEs9tBZLZjgueqAAUdAlbg9nQO9ebs1
# tq2cTCf2Z0UQycW8h05Ve9KHu93cMO/G1GzMmTVtHOBg081ojylZS4mWCEbJjvx1
# T8XcCcxOJ4tEzQe8rATgtTOlh5/03XMMkeoSgW/jdfAetZNsRBfVPpfJvQcsVncf
# hd1G6L/eLIGUo/flt6fBN591ylV3TV42KcqF2EVBcld1wHlb+jQQBm1kIEK3Osgf
# HUZkAl/GR77wxDooVNr2Hk+aohlDpG9J+PxeQiAohItHIG4wggW6MIIEoqADAgEC
# AhBK1hp2VzQOxQugus1+nh2IMA0GCSqGSIb3DQEBCwUAMEwxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwx0aGF3dGUsIEluYy4xJjAkBgNVBAMTHXRoYXd0ZSBTSEEyNTYg
# Q29kZSBTaWduaW5nIENBMB4XDTIwMDIxNDAwMDAwMFoXDTIyMDQxNDIzNTk1OVow
# eDELMAkGA1UEBhMCREUxDzANBgNVBAgMBkJheWVybjETMBEGA1UEBwwKUmVnZW5z
# YnVyZzEVMBMGA1UECgwMQ2lwU29mdCBHbWJIMRUwEwYDVQQLDAxDb2RlIFNpZ25p
# bmcxFTATBgNVBAMMDENpcFNvZnQgR21iSDCCAiIwDQYJKoZIhvcNAQEBBQADggIP
# ADCCAgoCggIBAMXt9uZLsr4SbQ5uJms9fNZZFhBbf1mbU8u1gHRqiaPo7CoKiksn
# pP3tXrvA1TUqA9J9Whwrjadmbx4hvRGEJEzWvXsvqXKUySZAvWCY4V1NZm+WfBG1
# v+sYvVliGGqK4CDA0yJtwvHtqCwQ7+5LMaXpl4O/tWGW8H1MVpcKBycVC2ckP5ZX
# rdc3YVqShxrvZV+mldJWX71H7rSNQDWgnJibRuWfPsuVL/G+Bo2i3M7xCVY/QWbd
# 8q0GSoEPAXf7k3qHmBwT+1usBdyPdExIt39kSIUPEqkCF57xo43q2I8VWb0Nbs7T
# clLnnotvrdcJlWdIPgXD4/eAs7CsDIREjVaiEEwCZ2nZT3GiOEb/D1E4tRGxqLI1
# dnV9hrcluFtuWMS+s1H/dD2uY4whLtSn/Ngx7bvyti3yNL5NSDFE3YzCwcBcELqj
# BTV194mmbOREKOOqKBjJcMALJmAMkSiR6uYKmqAA1FB1vbu+kjVhQwljl050a0/W
# E+Ww3kaJoUFpAH1S9HesXXQ2Ja3CM+XEzt4M8USWTiTJhQUPTx4BDiW9pWUb7Xbk
# Z+AAZa9KJ/xhkXwFcuERpB8SEjX+p8w/RwO8MWLGLd1lo25Pj9UNMYzEl0U3aIJ7
# RB7dY17mpUHFyUJjvamblzmx/pYyJ/YJ13qzrWfjDNySx8qBfTCoM957AgMBAAGj
# ggFqMIIBZjAJBgNVHRMEAjAAMB8GA1UdIwQYMBaAFFeGm1S4vqYpiuT2wuITGImF
# zdy3MB0GA1UdDgQWBBRZH1fBZJFjA8FN8Yckd5vb9VR2UjArBgNVHR8EJDAiMCCg
# HqAchhpodHRwOi8vdGwuc3ltY2IuY29tL3RsLmNybDAOBgNVHQ8BAf8EBAMCB4Aw
# EwYDVR0lBAwwCgYIKwYBBQUHAwMwbgYDVR0gBGcwZTBjBgZngQwBBAEwWTAmBggr
# BgEFBQcCARYaaHR0cHM6Ly93d3cudGhhd3RlLmNvbS9jcHMwLwYIKwYBBQUHAgIw
# IwwhaHR0cHM6Ly93d3cudGhhd3RlLmNvbS9yZXBvc2l0b3J5MFcGCCsGAQUFBwEB
# BEswSTAfBggrBgEFBQcwAYYTaHR0cDovL3RsLnN5bWNkLmNvbTAmBggrBgEFBQcw
# AoYaaHR0cDovL3RsLnN5bWNiLmNvbS90bC5jcnQwDQYJKoZIhvcNAQELBQADggEB
# AAi80Bo2L69o7/MZ/yblyam6mVXp+WZxrSRDiE8fjNjFg+A0jW0XT8KmKk7BveaN
# KVVQfTEB0u2pU3pdcoA6sUB0A9TB3nHlPQhwtKCkG/6v7kqjmcsTbxY2Sn3JSXSr
# jaPIco3IbmTFcmF8EpcTCKSOJXLqHWYpdSd1W0t++ayhKNHfKC6GcuW4dn67o9W5
# Vek+3Oz/OmibCczfSEBlpe+yz6J21CsxQhb+Z9Ah6yBKLzHixipsceUKtxFAyevw
# ChU0hFXCTRKcW1GdMPCu6Nh3JtMoG+vfw+SLfFYExzqCOXP89TpBIoi5AIzhsC9H
# 7edo/8YOU3QeRaf8Oazv7sQxggMBMIIC/QIBATBgMEwxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwx0aGF3dGUsIEluYy4xJjAkBgNVBAMTHXRoYXd0ZSBTSEEyNTYgQ29k
# ZSBTaWduaW5nIENBAhBK1hp2VzQOxQugus1+nh2IMAkGBSsOAwIaBQCgeDAYBgor
# BgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEE
# MBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBTx
# 1NN4+LI/umao7Mv+rccf/YJvcDANBgkqhkiG9w0BAQEFAASCAgApn59nzNeKNct3
# xdZqz2sdD/dGxhGvur4wMnuqwDwImUQsFaV/IzVlFIxU91kbBGmEDTOouFX9SBkA
# qNGrQ+wr+a1EgY7emQqnJ4xylT4pP9oENmSv5bdeOoBIlL/CWqsYppA+dEjXEmJ9
# g+A7Dp4CzlxFTKs7bSSCGyE5xaUSdMhsuPCxK15ILEShZw2wfeVb46ef1PTaX/HC
# nrI63BQULjE8Yuj3boNagh7dG5Jm4tUtc+gjoU2Rp8xbzfPmpdyJ5DIhrAU8iHF9
# WLS6t+taScVqx5lxiMFohhNON1lhprtVmLZffdpdl3249NuJzKssTD6P7Y1DsZRO
# TZ+VcLObsUBGo+kqCNQK4FYUxCM4e5JMoXaU39yS2A9GT9cyUUbHGVpKSLi2JS1U
# +y4bOovyyQZkz3VQVb0vMKM6Fs9qO8U6k8ejjPyAbD41vQ52i6XlsMrMigv+aopO
# BjsFLAfeQwl3sMftEBevhyDqj12LGe8xtJLMleFPA1jVs9tgfY+P9Khw0hRHhoWy
# 5D0m4dd6NWqvSJRCj3X+/uWD1dwrwR/iFKxaeM4jwT24dgfaBr+CTedPubeYdscg
# kI/yMsATPG4I3rUgoi7tRs6zUoQyx6abc7uExiRTI5QpnXApGMh6CDL68EogMEl2
# aPN2hy+gk9O3nAsGyo5o75DnAyzGEg==
# SIG # End signature block

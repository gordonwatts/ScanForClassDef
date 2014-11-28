#
# Some utitility functions to deal with finding out info about xAOD in a programatic way.
#

# Get info from a single file.
function Get-ClassDefMacroInfoFile ([string] $Path)
{
    # Does this file mention XAOD_STANDALONE?
    $xaoddefs = Get-Content -Path $Path | ? {$_.Contains("XAOD_STANDALONE")}
    $hasXAOD = $xaoddefs.Count -gt 0

    # And count the class def's so we can analyze them.
    $cdefs = Get-Content -Path $Path | ? {$_.Contains("CLASS_DEF") -and $_.Contains("(")}
    $all = @()
    foreach ($cd in $cdefs) {
        $grandInfo = $cd -split "\("
        if ((-not $grandInfo) -or ($grandInfo.Length -le 1)) {
            Write-Host "Warning: class def line contains unknown formatting: '$cd'"
            continue
        }
        $cdArgs = $grandInfo[1] -split ","
        if ((-not $cdArgs) -or ($cdArgs.Length -ne 3)) {
            Write-Host "Warning: class def line '$cd' does not contain 3 arguments"
            continue
        }
        $r = @{}
        $r["ObjectName"] = $cdArgs[0].Trim()
        $r["id"] = $cdArgs[1].Trim()
        $r["Version"] = $cdArgs[2].Replace(")","").Trim()
        $r["Path"] = Get-ChildItem -Path $Path
        $r["HasXAODStandalone"] = $hasXAOD

        $all += $r
    }
    return $all
}

# Parse a filename, and return package name and the actual filename (as opposed to the full path).
function Get-BasicPackageInfo ([string] $filename)
{
    if (-not $(test-path $filename)) {
        return @{}
    }

    $r = @{}
    $r["FileName"] = Get-ChildItem -Name $filename

    # Finding the package name is a little trickier because of the various levels down we might be.
    $dlist = (Get-ChildItem -Path $filename).FullName -split "\\"
    $r["Package"] = $dlist[$dlist.IndexOf("trunk")-1]

    # Other info
    $r["IsTriggerPackage"] = $filename.Contains("xAODTrig")

    return $r
}

# Add meta data about a class def we've found
function Get-ClassDefMetaData ($classDefInfo) {
    $r = @{}
    $r["HasV1"] = $classDefInfo["ObjectName"].Contains("_v")
    $r["IsContainer"] = $classDefInfo["ObjectName"].Contains("Container")

    return $r
}

function IsPackageDir ($path)
{
    $trunkDir = $path.FullName + "/trunk"
    if (test-path $trunkDir) {
        return $true
    }
    return $false
}

# Scan for pacakge directories. These will contain things like "trunk"
function Get-PackageDirectories ($path) {
    if (IsPackageDir($path) -eq $true) {
        return @($path)
    }

    $r = @()
    foreach ($subDir in $(Get-ChildItem $path)) {
        $r += Get-PackageDirectories($subDir)
    }

    return $r
}

$fileExtensionList = @(".hpp", ".h", ".cpp", ".cxx", ".hxx")

# Look at all the files in the directory and get all class infos
function Get-ClassDefMacroInFilesInDir ([string] $path)
{
    $allFiles = Get-ChildItem -File -Recurse $path | ? {$fileExtensionList.Contains($_.Extension)}
    $r = @()
    foreach ($f in $allFiles) {
        $r += Get-ClassDefMacroInfoFile $f.FullName
    }

    return $r
}

# Scan a directory structure for packages, and scan them for more interesting things.
function Get-ClassDefMacroInfoDir ([string] $Path) {
    $packages = Get-PackageDirectories $(get-item -path $Path)

    $r=@()
    foreach ($p in $packages) {
        $trunkDir = $p.FullName + "\trunk"
        if (test-path $trunkDir) {
            $r += Get-ClassDefMacroInFilesInDir $trunkDir
        }
    }

    return $r
}

# Top level command to extract class def macros
function Get-ClassDefMacros ([string] $Path)
{
    if (Test-Path -PathType Container $Path) {
        $macros = Get-ClassDefMacroInfoDir $Path
    }
    if (Test-Path -PathType Leaf $Path) {
        $macros = Get-ClassDefMacroInfoFile $Path
    }

    if ($macros) {
        if ($macros.Count -eq 0) {
            return $macros
        }
        return $macros | % {$_ + $(Get-BasicPackageInfo $_["Path"]) + $(Get-ClassDefMetaData $_) } | % {New-Object psobject -Property $_}
    }

    # Invalid path if we got this far
    throw "Unable to find file/directory or it conatains nothing: $Path"
}

Export-ModuleMember -Function Get-ClassDefMacros
# Example:
# Get-ClassDefMacros -Path ..\xAODFull\xAODTrigger\trunk
# Get-ClassDefMacros -Path ..\xAODFull\xAODTrigger\trunk\xAODTrigger\versions\BunchConfContainer_v1.h

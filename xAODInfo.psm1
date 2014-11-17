#
# Some utitility functions to deal with finding out info about xAOD in a programatic way.
#

# Get info from a single file.
function Get-ClassDefMacroInfoFile ([string] $Path)
{
    $cdefs = Get-Content -Path $Path | ? {$_.Contains("CLASS_DEF") -and $_.Contains("(")}
    $all = @()
    foreach ($cd in $cdefs) {
        $grandInfo = $cd -split "\("
        if ((-not $grandInfo) -or ($grandInfo.Length -le 1)) {
            Write "Warning: class def line contains unknown formatting: '$cd'"
            continue
        }
        $cdArgs = $grandInfo[1] -split ","
        if ((-not $cdArgs) -or ($cdArgs.Length -ne 3)) {
            Write "Warning: class def line '$cd' does not contain 3 arguments"
            continue
        }
        $r = @{}
        $r["Name"] = $cdArgs[0].Trim()
        $r["id"] = $cdArgs[1].Trim()
        $r["Version"] = $cdArgs[2].Replace(")","").Trim()

        $all += $r
    }
    return $all
}


# Top level command to extract class def macros
function Get-ClassDefMacros ([string] $Path)
{
    if (Test-Path -PathType Container $Path) {
        return Get-ClassDefMacroInfoFile $Path
    }
    if (Test-Path -PathType Leaf $Path) {
        return Get-ClassDefMacroInfoFile $Path
    }

    # Invalid path if we got this far
    throw "Unable to find file/directory $Path"
}


Export-ModuleMember -Function Get-ClassDefMacros
# Example:
# Get-ClassDefMacros -Path ..\xAODFull\xAODTrigger\trunk
# Get-ClassDefMacros -Path ..\xAODFull\xAODTrigger\trunk\xAODTrigger\versions\BunchConfContainer_v1.h

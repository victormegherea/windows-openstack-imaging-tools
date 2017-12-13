$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.Filesystem
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

function UntarImg {}
function Raw-To-Vhdx {}

function Qcow2-To-Vhdx {
    Param(
        [parameter(Mandatory = $True)]$ImagePath,
        [parameter(Mandatory = $True)][string]$OutPath
        )

    $outPath = $OutPath + "fromQcow2.*"


    $scriptPath\bin\qemu-img.exe convert $ImagePath -O vhdx -o subformat = dynamic $outPath
    if($LASTEXITCODE) { throw "qemu-img failed to convert the virtual disk" }

    $extToReturn = [System.IO.Path]::GetExtension($outPath)
    return $extToReturn
#qemu-img.exe convert source.img -O vhdx -o subformat=dynamic dest.vhdx
}

function UnzipImg {
    Param(
        [parameter(Mandatory = $True)][string]$ZipFilePath,
        [parameter(Mandatory = $True)][string]$OutPath
        )

    $outPath = $OutPath + "unzFile.*"
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFilePath, $outPath)
    $extToReturn = [System.IO.Path]::GetExtension($outPath)
    return $extToReturn
}

function UngzImg {}


function Mount-WindowsImage {
    Param(
        [parameter(Mandatory = $True)][string]$WindowsImagePathMount
        )

    if (Test-Path $WindowsImagePathMount) {
        Mount-VHD -Path $WindowsImagePathMount
    } else {
        Throw "Can't mount Virtual Disk"
    }
}

function Dismount-WindowsImage{
    Param(
        [parameter(Mandatory = $True)][string]$WindowsImagePathDismount
        )

    if (Test-Path $WindowsImagePathDismount) {
        Dismount-VHD -Path $WindowsImagePathDismount
    }
}

function Img-Check {
    Param(
        [parameter(Mandatory = $True)]$ImageExtension,
        [parameter(Mandatory = $True)]$ImagePath,
        [parameter(Mandatory = $True)]$OutPath
        )

    Switch ($ImageExtension) {
    ".vhdx"{
        Write-Host "Image extension is .vhdx"
        if ($windowsImageConfig.image_type -eq "HYPER-V") {
            Write-Host "HYPER-V image"
            if ($windowsImageConfig.virtual_disk_format -eq "VHDX") {
                Write-Host "Image was generated correctly"
            }
        }
        ; break}
    ".vhd"{
        Write-Host "Image extension is .vhd"
        if ($windowsImageConfig.image_type -eq "HYPER-V") {
            Write-Host "HYPER-V image"
            if ($windowsImageConfig.virtual_disk_format -eq "VHD") {
                Write-Host "Image was generated correctly"
            }
        }
        ; break}
    ".qcow2"{
        Write-Host "Image extension is .qcow2"
        if ($windowsImageConfig.image_type -eq "KVM") {
            Write-Host "KVM image"
            if ($windowsImageConfig.virtual_disk_format -eq "QCOW2") {
                Write-Host "Image was generated correctly"
                Qcow2-To-Vhdx $ImagePath $OutPath
            }
        }
        ; break}
    ".raw"{
        Write-Host "Image extension is .raw"
        if ($windowsImageConfig.image_type -eq "MAAS") {
            Write-Host "MAAS image"
            if ($windowsImageConfig.virtual_disk_format -eq "RAW") {
                Write-Host "Image was generated correctly"
                # bverfi maas hoks Raw-To-Vhdx
            }
        }
        ; break}
    ".zip"{
        Write-Host "Image is compressed in  .zip format"
        $extToReturn = UnzipImg $ImagePath $OutPath
        return $extToReturn
        ; break}
    ".tar"{
        Write-Host "Image is compressed in .tar format"
        UntarImg
        ; break}
    ".gz"{
        Write-Host "Image is compressed in .gz format"
        UngzImg
        ;break
        }
    }
}

function Validate-WindowsImage {
    Param(
        [parameter(Mandatory = $True, ValueFromPipeline=$True)][string]$ConfigFilePath
        )

    $windowsImageConfig = Get-WindowsImageConfig -ConfigFilePath $ConfigFilePath
    $imagePath = $windowsImageConfig.image_path
    Write-Host "imagePath"$imagePath
    $workingDir = [System.IO.Path]::GetDirectoryName($imagePath)
    $imageName = [System.IO.Path]::GetFileNameWithoutExtension($imagePath)
    
    #$tempChildImagePath = Split-Path $fromDirImagePath
    #$childImagePath = $tempChildImagePath + "\childImagePath.vhdx"
    #Push-Location -Path $wokingDir
    $getImage = Get-ChildItem $workingDir -filter "$imageName.*"
    Write-Host "imagename+++++"$getImage
    #New-VHD -ParentPath $getImage -Path "childImage"
    #$getChild = Get-ChildItem $workingDir -filter "$childImage.*"
    #Write-Host "+++++++"$getChild
    $imageExtension = [System.IO.Path]::GetExtension($getImage)
    Write-Host "extension"$imageExtension
    Push-Location -Path $workingDir

    $outPath = New-Item $workingDir\"OutDir" -Type Directory
    Write-Host "OutPath"$outPath
    Copy-Item -Path $getImage -Destination $outPath
    $getChild = Get-ChildItem $outPath
    $check = Img-Check $imageExtension $getChild  $outPath

    while ($check -ne ".vhdx" -or ".vhd") {
        Img-Check $check $getChild  $outPath
    }
    #Pop-Location
}

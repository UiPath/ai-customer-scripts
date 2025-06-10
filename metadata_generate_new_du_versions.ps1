param(
    [Parameter()]
    [String] $targetImage = '',

    [Parameter(Mandatory)]
    [String] $newCustomVersion,

    [Parameter(Mandatory)]
    [String] $previousCustomVersion,

    [Parameter(Mandatory)]
    [String] $newTag
)

function Remove-BomFromFile($Path) {
    $Content = Get-Content -Path $Path -Raw
    $Utf8NoBomEncoding = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $False
    [System.IO.File]::WriteAllLines($Path, $Content, $Utf8NoBomEncoding)
}

# Define the path to the folder containing the files
$folderPath = $PSScriptRoot + "/metadata"

Write-Host "folderPath: $folderPath"

# Get a list of all files in the folder that match the specified format
$fileList = Get-ChildItem $folderPath | Where-Object { $_.Name -match "^([a-zA-Z0-9_]+)__([0-9]+)__metadata\.json$" }

# Create a hashtable to store the highest version number for each model
$maxModelVersions = @{}
$previousFileVersion = @{}

Write-Host "fileList: $fileList"

# Loop through each file and determine if it has a higher version number than any previously processed file for the same model
foreach ($file in $fileList) {
    $fileName = $file.Name
    Write-Host "Processing $fileName"
    $match = [regex]::Match($fileName, "^([a-zA-Z0-9_]+)__([0-9]+)__metadata\.json$")
    $model = $match.Groups[1].Value
    $version = [int]$match.Groups[2].Value

    if ($maxModelVersions.ContainsKey($model)) {
        $currentVersion = [int]$maxModelVersions[$model]
        if ($version -gt $currentVersion) {
            $maxModelVersions[$model] = $version
        }
    }
    else {
        $maxModelVersions[$model] = $version
    }

    $json = Get-Content $file.FullName | ConvertFrom-Json
    if ($json.customVersion -eq $previousCustomVersion){
        $previousFileVersion[$model] = $version
    }
}

# Loop through each file again and create a copy of the file with the previous version number for each model
foreach ($file in $fileList) {
    $json = Get-Content $file.FullName | ConvertFrom-Json
    $fileName = $file.Name
    $match = [regex]::Match($fileName, "^([a-zA-Z0-9_]+)__([0-9]+)__metadata\.json$")
    $model = $match.Groups[1].Value
    $version = [int]$match.Groups[2].Value

    if ($version -eq $previousFileVersion[$model]) {
        if ($json.customVersion -eq $newCustomVersion) {
            Write-Host "Metadata with custom version $newCustomVersion exists. Updating it instead of creating a new one."
            $newFilePath = $file.FullName #setting the newFilePath to the same file to update it
            $newVersion = $version
            $newFileName = $fileName
        } else {
            Write-Host "Metadata with custom version $newCustomVersion does not exist. Creating a new one."
            $newVersion = $maxModelVersions[$model] + 1
            $newFileName = "$model" + "__" + "$newVersion" + "__metadata.json"
            $newFilePath = Join-Path $folderPath $newFileName
        }

        if ($json.mlPackageLanguage -like '*DU' -and $json.imagePath){
            #Write-Host "model: $model"

            $json.version = $newVersion
            $json.customVersion = $newCustomVersion

            # Replace the specified text with the new text
            $parts = $json.imagePath -split ':'
            if ($targetImage -ne $null -and $targetImage -ne '' -and $targetImage -ne $parts[0]){
                continue
            }

            $json.imagePath = $parts[0] + ":" + $newTag

            $json | ConvertTo-Json -Depth 100 | Set-Content $newFilePath -Encoding ASCII

            # Copy the file's last write time to the new file
            $newFile = Get-Item $newFilePath
            $newFile.LastWriteTime = $file.LastWriteTime

            Write-Host "newFilePath: $newFilePath"
        }
    }
}
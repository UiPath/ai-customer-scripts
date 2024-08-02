# Define the path to the folder containing the files
$folderPath = $PSScriptRoot + "/metadata"

echo $folderPath

$oldCustomVersion = '23.4.7'
# Set the new custom version number
$newCustomVersion = '23.4.8'

# Set the text to be replaced and the replacement text
$oldText = 'du-semistructured:v23.4.7-rc35'
$newText = 'du-semistructured:v23.4-rc02'

# Get a list of all files in the folder that match the specified format
$fileList = Get-ChildItem $folderPath | Where-Object { $_.Name -match "^([a-zA-Z0-9_]+)__([0-9]+)__metadata\.json$" }

# Create a hashtable to store the highest version number for each model
$maxModelVersions = @{}
$previousFileVersion = @{}

Write-Host $fileList

# Loop through each file and determine if it has a higher version number than any previously processed file for the same model
foreach ($file in $fileList) {
    $fileName = $file.Name
    Write-Host $fileName
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
    if ($json.customVersion -eq $oldCustomVersion){
        $previousFileVersion[$model] = $version
    }
}

# Loop through each file again and create a copy of the file with the previous version number for each model
foreach ($file in $fileList) {
    $fileName = $file.Name
    $match = [regex]::Match($fileName, "^([a-zA-Z0-9_]+)__([0-9]+)__metadata\.json$")
    $model = $match.Groups[1].Value
    $version = [int]$match.Groups[2].Value

    if ($version -eq $previousFileVersion[$model]) {
        $newVersion = $maxModelVersions[$model] + 1
        $newFileName = "$model" + "__" + "$newVersion" + "__metadata.json"
        $newFilePath = Join-Path $folderPath $newFileName

        # Read the JSON file, increment the version number, and update the custom version field
        $json = Get-Content $file.FullName | ConvertFrom-Json

        if ($json.mlPackageLanguage -like '*DU' -and $json.imagePath){
            Write-Host $model

            $json.version = $newVersion
            $json.customVersion = $newCustomVersion

            # Replace the specified text with the new text
            $json.imagePath = $json.imagePath -replace $oldText, $newText

            $json | ConvertTo-Json -Depth 100 | Out-File $newFilePath

            # Copy the file's last write time to the new file
            $newFile = Get-Item $newFilePath
            $newFile.LastWriteTime = $file.LastWriteTime
        }
    }
}
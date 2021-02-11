param (

	[Parameter(Mandatory = $true, ValueFromPipeline = $false)]
	[string] $Username,

	[Parameter(Mandatory = $true, ValueFromPipeline = $false)]
	[string] $Password,

	[Parameter(Mandatory = $true, ValueFromPipeline = $false)]
	[string[]] $Packages,

	[Parameter(Mandatory = $false, ValueFromPipeline = $false)]
	[switch] $Refresh = $false
)

$Packages | ForEach-Object {

	$DownloadRoot = Join-Path $PSScriptRoot "downloads/$_"
	Write-Output "Processing package '$_' ($DownloadRoot) ..."

	if ($Refresh) {
		# delete package download location to enforce download
		Remove-Item -Confirm:$false -Recurse -Force -Path $DownloadRoot | Out-Null
	}

	if ( -not (Test-Path $DownloadRoot -PathType Container)) {
		# create download folder for the selected package
		New-Item -ItemType Directory -Force -Path $DownloadRoot | Out-Null
	}

	$PackageFiles = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lnwsoft/phoenix-repo-downloader/main/packages/$_.lst").Content | `
		Where-Object { [system.uri]::IsWellFormedUriString($_, [System.UriKind]::Absolute) } | `
		Select-Object @{label = "ID"; expression = { $_.ToString().Split("/") | Select-Object -Last 1 } }, @{label = "Url"; expression = { $_.ToString() } } -Unique

	$PasswordSec = ConvertTo-SecureString $Password -AsPlainText -Force
	$Credentials = New-Object System.Management.Automation.PSCredential($Username, $PasswordSec)

	$PackageFiles | ForEach-Object {

		Write-Output "- Enqueued download '$($_.Url)'"

		$Download = Invoke-WebRequest -Uri "https://origin.softwaredownloads.sap.com/tokengen/" `
			-Credential $Credentials -UserAgent "SAP Download Manager"  -Method Get `
			-Body @{ file = $_.Id } # -OutFile $DownloadPath

		if ($Download.Headers["Content-Disposition"] -match 'filename=\"(.+)\"') {
		
			[string] $DownloadFile = $matches[1].ToString()

			if ($Package.ToLowerInvariant() = "hostagent") {
				# the hostagent package needs some file name cleanup to take place
				$DownloadFile = $DownloadFile -replace "(?<=SAPCAR|SAPHOSTAGENT)(.*)(?=\.)", ""
			}

			[string] $DownloadPath = Join-Path $DownloadRoot $DownloadFile
			[IO.File]::WriteAllBytes($DownloadPath, $Download.Content)

			Write-Output "- Saved download '$($_.Url)' to '$DownloadPath'"
		}
		else {
			throw "Unable to identify file name in download $($p.Url)"
		}
	}
}
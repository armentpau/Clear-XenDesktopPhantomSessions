<#
	.SYNOPSIS
		Queries the XenDesktop/XenApp citrix database and clears any connection errors found.
	
	.DESCRIPTION
		This script queries the citrix database at the specified time period and then works to reset any affected broker services on impacted servers.
	
	.PARAMETER Database
		The database name where the XenDesktop/XenApp data is stored.  This can be either a live instance of your Citrix database or can be a copy of the datase (provided the copy is within the scan frequency)
	
	.PARAMETER DatabaseServerInstance
		The SQL instance where the Database lives.
	
	.PARAMETER DatabaseUserId
		The username used to log into the Citrix database to query for connection errors.
	
	.PARAMETER DatabasePassword
		The password associated with DatabaseUserId.
	
	.PARAMETER ServerDomain
		The domain name which is prefixed to the server names in the citrix database.  This does not have to be all uppercase as the script converts the entire computer name to lowercase.
	
	.PARAMETER OutputFile
		If specified, the script will output any sessions that is has to reset to a file as well as to the screen.  The outputed file will be in csv format.
	
	.PARAMETER TimeBetweenLoops
		This is how long the script sleeps before it once again checks the sql database for errors.  This time is in seconds.  The default value is 600 seconds.
	
	.EXAMPLE
		PS C:\> .Clear-XenDesktopPhantomSessions -Database "Client-Citrix" -DatabaseServerInstance "9999sqlni01\9999sqlni01" -DatabaseUserId "username" -DatabasePassword "Password" -ServerDomain "clientDomain" -outputfile "c:\outputFiles\ResetSessions.csv"
	.EXAMPLE
		PS C:\> .Clear-XenDesktopPhantomSessions -Database "Client-Citrix" -DatabaseServerInstance "9999sqlni01\9999sqlni01" -DatabaseUserId "username" -DatabasePassword "Password" -ServerDomain "clientDomain" -outputfile "c:\outputFiles\ResetSessions.csv" -TimeBetweenLoops 600
	.EXAMPLE
		PS C:\> .Clear-XenDesktopPhantomSessions -Database "Client-Citrix" -DatabaseServerInstance "9999sqlni01\9999sqlni01" -DatabaseUserId "username" -DatabasePassword "Password" -ServerDomain "clientDomain" -MinutesBetweenLoops 10
	.EXAMPLE
		PS C:\> .Clear-XenDesktopPhantomSessions -Database "Client-Citrix" -DatabaseServerInstance "9999sqlni01\9999sqlni01" -DatabaseUserId "username" -DatabasePassword "Password" -ServerDomain "clientDomain"
	
	.NOTES
		Additional information about the file.
#>
[CmdletBinding(SupportsShouldProcess = $false)]
param
(
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string]
	$Database,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[Alias('Server')]
	[string]
	$DatabaseServerInstance,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[Alias('Username')]
	[string]
	$DatabaseUserId,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[Alias('Password')]
	[string]
	$DatabasePassword,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[Alias('Domain')]
	[string]
	$ServerDomain,
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[Alias('Out', 'File')]
	[string]
	$OutputFile,
	[Alias('Minutes')]
	[int]
	$TimeBetweenLoops = 600
)

$finishLoop = 0

do
{
	
	[void][Reflection.Assembly]::Load("System.Data, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089")
	$SelectionDate = Get-Date((Get-Date).ToUniversalTime().addseconds(-$($TimeBetweenLoops))) -Format "g"
	Write-Verbose "Selection date is $($SelectionDate)"
	#Database Query
	$QueryString = "Select [$Database].MonitorData.Session.FailureDate,
  [$Database].MonitorData.Session.FailureId,
  [$Database].MonitorData.Machine.Name,
  [$Database].MonitorData.[User].UserName
From [$Database].MonitorData.Session
  Inner Join [$Database].MonitorData.Machine
    On [$Database].MonitorData.Machine.Id =
    [$Database].MonitorData.Session.MachineId
  Inner Join [$Database].MonitorData.[User]
    On [$Database].MonitorData.[User].Id =
    [$Database].MonitorData.Session.UserId
Where [$Database].MonitorData.Session.FailureId = 11 and
[$Database].MonitorData.Session.EndDate > '$SelectionDate'
Order By [$Database].MonitorData.Session.FailureDate"
	
	#Database Connection String
	$ConnectionString = "Data Source=$DatabaseServerInstance;Integrated Security=False;User ID=$databaseUserId;Password=$databasePassword"
	Write-Verbose "Connecting to database $($Database)"
	
	$connection = New-Object System.Data.SqlClient.SqlConnection ($ConnectionString)
	Write-Verbose "Attempting to open connection to SQL Database"
	$connection.Open()
	if ($connection.State -eq [System.Data.ConnectionState]::Open)
	{
		$command = New-Object System.Data.SqlClient.SqlCommand ($QueryString, $connection)
		Write-Verbose "Creating command $($command)"
		$StringBuilder = New-Object System.Text.StringBuilder
		#Run the query
		$recordset = $command.ExecuteReader()
		$holder = $null
		$holder = While ($recordset.Read() -eq $true)
		{
			#Clear the StringBuilder
			[void]$StringBuilder.Remove(0, $StringBuilder.Length)
			
			#Loop through each field
			for ($index = 0; $index -lt $recordset.FieldCount; $index++)
			{
				if ($index -ne 0)
				{
					[void]$StringBuilder.Append(", ")
				}
				[void]$StringBuilder.Append($recordset.GetValue($index).ToString())
			}
			#Output the Row
			Write-Output $StringBuilder.ToString()
		}
		#Close the Connection
		$recordset.Close()
		Write-Verbose "Closing the recordset"
		$connection.Close();
		Write-Verbose "Connection closed"
		Write-Verbose "Going onto the next part to process all of the objects"
	}
	$objs = $null
	$objs = foreach ($item in $holder)
	{
		$temp = $item.split(",")
		New-Object -TypeName System.Management.Automation.PSObject -Property @{
			"FailureDate" = $temp[0].trim()
			"FailureID" = $temp[1].trim()
			"Server" = $temp[2].trim().tolower().replace("$($ServerDomain.ToLower())\", "")
			"UserName" = $temp[3].trim()
		}
	}
	if (($objs | Measure-Object).count -gt 0)
	{
		foreach ($item in $objs)
		{
			Get-Service -computername "$($item.server)" -ServiceName "BrokerAgent" | Restart-Service -Force
			Write-Output "$($item.server) $($item.name)"
			if ($OutputFile)
			{
				Write-Verbose "Outfile is set, exporting data to $($OutputFile)"
				$item | export-csv "$($OutputFile)" -Append -NoTypeInformation
				Write-Verbose "Data exported to $($OutputFile)"
			}
		}
	}
	else
	{
		Write-output "Nothing to reset"
	}
	##code for sleeping with a progress bar - taken from poshcode
	##Using this allows for the above to function correctly
	Write-Verbose "TimeBetweenLoops Set To $TimeBetweenLoops"
	$length = $TimeBetweenLoops / 100
	Write-Verbose "Length Set To $($length)"
	while ($TimeBetweenLoops -gt 0)
	{
		if ([Console]::KeyAvailable)
		{
			$key = [Console]::ReadKey($true)
			if ($key.Key -eq "B" -and $key.Modifiers -eq "Control")
			{
				Write-Verbose "CTRL+B has been pressed, breaking out of the current"
				break
			}
			if ($key.Key -eq "T" -and $key.Modifiers -eq "Control")
			{
				Write-Output $SelectionDate
			}
		}
		$min = [int](([string]($TimeBetweenLoops/60)).split('.')[0])
		Write-Verbose "Min is set to $($min)"
		$text = " " + $min + " minutes " + ($TimeBetweenLoops % 60) + " seconds left"
		Write-Verbose "Test value is $($text)"
		Write-Progress "Pausing Script" -status $text -perc ($TimeBetweenLoops/$length)
		Write-Verbose "Starting to sleep for one second"
		start-sleep -s 1
		$TimeBetweenLoops--
		Write-Verbose "TimeBetweenLoops set to $($TimeBetweenLoops)"
	}
}
while ($finishLoop -eq 0)
param
(
	[Alias('Table')]
	[string]
	$DatabaseTable,
	[string]
	$DatabaseInstance,
	[string]
	$DatabaseUserId,
	[string]
	$DatabasePassword,
	[string]
	$ServerDomain,
	[string]
	$OutputFile
)

$finishLoop = 0

do
{
	
	[void][Reflection.Assembly]::Load("System.Data, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089")
	$SelectionDate = Get-Date((Get-Date).ToUniversalTime().AddMinutes(-15)) -Format "g"
	#Database Query
	$QueryString = "Select [$DatabaseTable].MonitorData.Session.FailureDate,
  [$DatabaseTable].MonitorData.Session.FailureId,
  [$DatabaseTable].MonitorData.Machine.Name,
  [$DatabaseTable].MonitorData.[User].UserName
From [$DatabaseTable].MonitorData.Session
  Inner Join [$DatabaseTable].MonitorData.Machine
    On [$DatabaseTable].MonitorData.Machine.Id =
    [$DatabaseTable].MonitorData.Session.MachineId
  Inner Join [$DatabaseTable].MonitorData.[User]
    On [$DatabaseTable].MonitorData.[User].Id =
    [$DatabaseTable].MonitorData.Session.UserId
Where [$DatabaseTable].MonitorData.Session.FailureId = 11 and
[$DatabaseTable].MonitorData.Session.EndDate > '$SelectionDate'
Order By [$DatabaseTable].MonitorData.Session.FailureDate"
	
	#Database Connection String
	$ConnectionString = "Data Source=$databaseInstance;Integrated Security=False;User ID=$databaseUserId;Password=$databasePassword"
	
	$connection = New-Object System.Data.SqlClient.SqlConnection ($ConnectionString)
	$connection.Open()
	if ($connection.State -eq [System.Data.ConnectionState]::Open)
	{
		$command = New-Object System.Data.SqlClient.SqlCommand ($QueryString, $connection)
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
		$connection.Close();
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
			$item | export-csv "$($OutputFile)" -Append -NoTypeInformation
		}
	}
	else
	{
		Write-output "Nothing to reset"
	}
	##code for sleeping with a progress bar - taken from poshcode
	##Using this allows for the above to function correctly
	$TimeBetweenLoops = 15 * 60
	$length = $TimeBetweenLoops / 100
	while ($TimeBetweenLoops -gt 0)
	{
		if ([Console]::KeyAvailable)
		{
			$key = [Console]::ReadKey($true)
			if ($key.Key -eq "B" -and $key.Modifiers -eq "Control")
			{
				break
			}
			if ($key.Key -eq "T" -and $key.Modifiers -eq "Control")
			{
				Write-Output $SelectionDate
			}
		}
		$min = [int](([string]($TimeBetweenLoops/60)).split('.')[0])
		$text = " " + $min + " minutes " + ($TimeBetweenLoops % 60) + " seconds left"
		Write-Progress "Pausing Script" -status $text -perc ($TimeBetweenLoops/$length)
		start-sleep -s 1
		$TimeBetweenLoops--
	}
}
while ($finishLoop -eq 0)
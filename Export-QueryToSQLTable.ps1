

####################### 
<# 
.SYNOPSIS 
    Runs given set of queries against one or more instances+databases (if query is db specific) and saves the results to tables

.DESCRIPTION 
    Given a set of queries to run, saves the results to tables (maybe for periodic data collection)
   
    The queries should be provided as an object array with specific properties. 

    # -----------------
    # Pre-requisites
    # -----------------
    # 1) SQLServer Module (Mandatory) - http://port1433.com/2017/04/26/installing-the-sql-server-module-from-the-powershell-gallery/
    # 2) dbatools (Mandatory) - https://dbatools.io/
    # 3) Export-DMVInformation (Optional) - https://github.com/sanderstad/Export-DMVInformation/blob/master/Export-DMVInformation.psm1
    # 4) Glenn Berry's DMV's (Optional) - https://www.sqlskills.com/blogs/glenn/category/dmv-queries/

.PARAMETER Queries

    The set of queries to run as an object arrary with each element having attributes 
     QueryNr, QueryTitle, Query, Description and DBSpecific (true/false)

    You can use the function Parse-DMVFile in Export-DMVInformation reference in Pre-requisites above

    Or, you can simply build a query list yourself by hand. See the first example

.EXAMPLE

    [string] $saveToInstance = '<YOUR_INSTANCE_NAME>'
    [string] $runOnInstance = '<YOUR_INSTANCE_NAME>'
    [string] $saveToDatabase = 'DBAUtil'
    [string] $saveToSchema = 'dbo'

    #If you need to use custom SQL credentials instead of windows integrated security..get the user/pass interactively
    $runOnInstanceSqlCredential = Get-Credential
    $saveToInstanceSqlCredential = $runOnInstanceSqlCredential

    # (or non-interactively)
    #$secpasswd = ConvertTo-SecureString "<PasswordGoeshere>" -AsPlainText -Force
    #$runOnInstanceSqlCredential = New-Object System.Management.Automation.PSCredential ("testuser", $secpasswd)
    #$saveToInstanceSqlCredential = $runOnInstanceSqlCredential

    $query1 = New-Object -TypeName PSObject
    $query1 | Add-Member -MemberType NoteProperty -Name QueryNr -Value 1
    $query1 | Add-Member -MemberType NoteProperty -Name QueryTitle -Value 'sp_who_Info'
    $query1 | Add-Member -MemberType NoteProperty -Name Query -Value 'EXEC sp_who'
    $query1 | Add-Member -MemberType NoteProperty -Name Description -Value 'Gets connected users/sessions'
    $query1 | Add-Member -MemberType NoteProperty -Name DBSpecific -Value $false

    $query2 = New-Object -TypeName PSObject
    $query2 | Add-Member -MemberType NoteProperty -Name QueryNr -Value 2
    $query2 | Add-Member -MemberType NoteProperty -Name QueryTitle -Value 'Log space usage'
    $query2 | Add-Member -MemberType NoteProperty -Name Query -Value 'select * from sys.dm_db_log_space_usage'
    $query2 | Add-Member -MemberType NoteProperty -Name Description -Value 'Gets log space usage for specific database (being run against)'
    $query2 | Add-Member -MemberType NoteProperty -Name DBSpecific -Value $true

    #...These two queries were built above
    $queries = @($query1, $query2)

    #Now $queries can be passed into the function call
    $output = Export-QueryToSQLTable `
            -RunOnInstanceSqlCredential $runOnInstanceSqlCredential `
            -SaveToInstanceSqlCredential $saveToInstanceSqlCredential `
            -Queries $queries `
            -RunOnInstances @($runOnInstance) `
            -RunIncludeDBs @() `
            -RunExcludeDBs @() `
            -RunExcludeAllSystemDBs: $true `
            -RunExcludeAllUserDBs: $false `
            -RunOnDBsWithOwner @() `
            -RunOnDBsWithStatus @('Normal') `
            -SaveResultsToInstance $saveToInstance `
            -SaveResultsToDatabase $saveToDatabase `
            -SaveResultsToSchema $saveToSchema `
            -SaveResultsTruncateBeforeSave: $false

.EXAMPLE
    #Save results of sp_WhoIsActive to a table

    [string] $saveToInstance = '<YOUR_INSTANCE_NAME>'
    [string] $runOnInstance = '<YOUR_INSTANCE_NAME>'

    $saveToInstance = 'DESKTOP-UBBP7PP\SQL2016'
    $runOnInstance = 'DESKTOP-UBBP7PP\SQL2016'

    [string] $saveToDatabase = 'TEST'
    [string] $saveToSchema = 'dbo'

    $query1 = New-Object -TypeName PSObject
    $query1 | Add-Member -MemberType NoteProperty -Name QueryNr -Value 1
    $query1 | Add-Member -MemberType NoteProperty -Name QueryTitle -Value 'sp_WhoIsActiveInfo3'
    $query1 | Add-Member -MemberType NoteProperty -Name Query -Value 'EXEC sp_whoisActive @show_sleeping_spids  =1, @get_plans =1, @show_own_spid = 1'
    $query1 | Add-Member -MemberType NoteProperty -Name Description -Value 'Gets connected users/sessions'
    $query1 | Add-Member -MemberType NoteProperty -Name DBSpecific -Value $false

    #...These two queries were built above
    $queries = @($query1)

    #Now $queries can be passed into the function call
    $output = Export-QueryToSQLTable `
            -Queries $queries `
            -RunOnInstances @($runOnInstance) `
            -RunIncludeDBs @() `
            -RunExcludeDBs @() `
            -RunExcludeAllSystemDBs: $true `
            -RunExcludeAllUserDBs: $false `
            -RunOnDBsWithOwner @() `
            -RunOnDBsWithStatus @('Normal') `
            -SaveResultsToInstance $saveToInstance `
            -SaveResultsToDatabase $saveToDatabase `
            -SaveResultsToSchema $saveToSchema `
            -SaveResultsTruncateBeforeSave: $false

.EXAMPLE

    #This is a real-world example of how to setup a script, save it as a .ps1 file and kick off from 
    # SQL agent as a cmdline script or from the windows scheduler
    #This saves all the DMV's in Glenn Berry's script to tables prefixed with DrDMV.
    #This script uses a SQL credential for instances to run/save against. 
    #Drop the SQL credential related parameters if the service account you will run as has adequate permissions.

    Import-Module C:\GitHub\dbatools\dbatools.psd1

    . D:\PowerShell\Export-DMVInformation.ps1
    . D:\PowerShell\Export-QueryToSQLTable.ps1


    $dmvQueriesFile = 'D:\Software\SQL Server Tools\GlenBerryDMVs\SQL Server 2014 Diagnostic Information Queries (June 2016).sql'
    [string] $saveToInstance = '<YOUR_INSTANCE_NAME>'
    [string] $runOnInstance = '<YOUR_INSTANCE_NAME>'
    [string] $saveToDatabase = 'DBAUtil'
    [string] $saveToTablePrefix = 'DrDMV_'

    [PSObject[]] $queries = Parse-DMVFile `
                    -file $dmvQueriesFile

    # (or non-interactively)
    $secpasswd = ConvertTo-SecureString "<SQL_USER_PASSWORD>" -AsPlainText -Force
    $runOnInstanceSqlCredential = New-Object System.Management.Automation.PSCredential ("<SQL_USER_NAME>", $secpasswd)
    $saveToInstanceSqlCredential = $runOnInstanceSqlCredential

    #Here we are overriding the "save to" Instance, Database, Schema, Table and TruncationBeforeSave option as part of the queries input!        
    #
    [PSObject[]] $queries = $queries | 
                                        SELECT `
                                            *,
                                            @{Label="SaveResultsToInstance";Expression={$saveToInstance}},
                                            @{Label="SaveResultsToDatabase";Expression={$saveToDatabase}},
                                            @{Label="SaveResultsToSchema";Expression={'dbo'}},
                                            @{Label="SaveResultsToTable";Expression={
                                                            ($saveToTablePrefix + 
                                                                $_.QueryNr.ToString().PadLeft(3,'0').ToString() +
                                                                '_' + 
                                                                $_.QueryTitle
                                                            ).Replace(' ','_').Replace('-','_')}},
                                            @{Label="SaveResultsTruncateBeforeSave";Expression={[bool]$false}}

    #Now $queries can be passed into the function call
    $output = Export-QueryToSQLTable `
            -RunOnInstanceSqlCredential $runOnInstanceSqlCredential `
            -SaveToInstanceSqlCredential $saveToInstanceSqlCredential `
            -Queries $queries `
            -RunOnInstances @($runOnInstance) `
            -RunIncludeDBs @() `
            -RunExcludeDBs @() `
            -RunExcludeAllSystemDBs: $true `
            -RunExcludeAllUserDBs: $false `
            -RunOnDBsWithOwner @() `
            -RunOnDBsWithStatus @('Normal') `
            -SaveResultsToInstance '' `
            -SaveResultsToDatabase '' `
            -SaveResultsToSchema 'dbo' `
            -SaveResultsTruncateBeforeSave: $false

.PARAMETER

     One or more instances on which to run the query. For example @('DEVBox\DevInst','QABox\QAInst', 'MiscBox')

.INPUTS 
    Queries to run (with certain attributes - see examples)

.OUTPUTS 
    The instances/databases against which it ran, success/failure status and message + number or rows saved with target table info.

.EXAMPLE 

        #Get the queries from DMV file into an array 
        # (uses function Parse-DMVFile in Export-DMVInformation reference in Pre-requisites above)

        $dmvQueriesFile = 'D:\Software\SQL Server Tools\GlenBerryDMVs\SQL Server 2014 Diagnostic Information Queries (June 2016).sql'
        [string] $saveToInstance = '<YOUR_INSTANCE_NAME>'
        [string] $runOnInstance = '<YOUR_INSTANCE_NAME>'
        [string] $saveToDatabase = 'DBAUtil'
        [string] $saveToSchema = 'dbo'

        [PSObject[]] $queries = Parse-DMVFile `
                        -file $dmvQueriesFile

        #
        #Each query returned above will have the below properties
        #
        #Name        MemberType   Definition                                                                                        
        #----        ----------   ----------                                                                                        
        #DBSpecific  NoteProperty bool DBSpecific=False                                                                             
        #Description NoteProperty example: SQL and OS Version information for current instance                            
        #Query       NoteProperty example: SELECT @@SERVERNAME AS [Server Name], @@VERSION AS [SQL Server and OS Version Info]; 
        #QueryNr     NoteProperty example: 1                                                                                  
        #QueryTitle  NoteProperty example: Version Info       

        $output = Export-QueryToSQLTable `
            -Queries $queries `
            -RunOnInstances @($runOnInstance) `
            -RunIncludeDBs @() `
            -RunExcludeDBs @() `
            -RunExcludeAllSystemDBs: $true `
            -RunExcludeAllUserDBs: $false `
            -RunOnDBsWithOwner @() `
            -RunOnDBsWithStatus @('Normal') `
            -SaveResultsToInstance $saveToInstance `
            -SaveResultsToDatabase $saveToDatabase `
            -SaveResultsToSchema $saveToSchema `
            -SaveResultsTruncateBeforeSave: $false

.EXAMPLE 

        #This example uses windows integrated security to run Glen Berry's DMV scripts
        #  and save them to tables with prefix DrDMV_
                
        $dmvQueriesFile = 'D:\Software\SQL Server Tools\GlenBerryDMVs\SQL Server 2014 Diagnostic Information Queries (June 2016).sql'
        [string] $runOnInstance = '<YOUR_INSTANCE_NAME>'
        [string] $saveToInstance = '<YOUR_INSTANCE_NAME>'
        [string] $saveToDatabase = 'DBAUtil'
        [string] $saveToTablePrefix = 'DrDMV_'

        #Similar to first example (read that for more info)
        [PSObject[]] $queries = Parse-DMVFile `
                        -file $dmvQueriesFile        
        
        #Here we are overriding the "save to" Instance, Database, Schema, Table and TruncationBeforeSave option as part of the queries input!        
        #
        [PSObject[]] $queries = $queries | 
                                            SELECT `
                                                *,
                                                @{Label="SaveResultsToInstance";Expression={$saveToInstance}},
                                                @{Label="SaveResultsToDatabase";Expression={$saveToDatabase}},
                                                @{Label="SaveResultsToSchema";Expression={'dbo'}},
                                                @{Label="SaveResultsToTable";Expression={
                                                                ($saveToTablePrefix + 
                                                                    $_.QueryNr.ToString().PadLeft(3,'0').ToString() +
                                                                    '_' + 
                                                                    $_.QueryTitle
                                                                ).Replace(' ','_').Replace('-','_')}},
                                                @{Label="SaveResultsTruncateBeforeSave";Expression={[bool]$false}}

        #Notice below how all of the "SaveResultsTo*" parameters are emtpy and yet it works because
        #    we pass that information in as part of the input Queries parameter                                                
        Export-QueryToSQLTable `
            -Queries $queries `
            -RunOnInstances @($runOnInstance) `
            -RunIncludeDBs @() `
            -RunExcludeDBs @() `
            -RunExcludeAllSystemDBs: $true `
            -RunExcludeAllUserDBs: $false `
            -RunOnDBsWithOwner @() `
            -RunOnDBsWithStatus @('Normal') `
            -SaveResultsToInstance '' `
            -SaveResultsToDatabase '' `
            -SaveResultsToSchema '' `
            -SaveResultsTruncateBeforeSave: $false

.EXAMPLE

    #This example saves the sp_Blitz output to tables
    Import-Module dbatools

    . D:\PowerShell\Export-DMVInformation.ps1
    . D:\PowerShell\Export-QueryToSQLTable.ps1

    [string] $saveToInstance = '<YOUR_INSTANCE_NAME>'
    [string] $runOnInstance = '<YOUR_INSTANCE_NAME>'
    [string] $saveToDatabase = 'DBAUtil'
    [string] $saveToSchema = 'dbo'

    $query1 = New-Object -TypeName PSObject
    $query1 | Add-Member -MemberType NoteProperty -Name QueryNr -Value 1
    $query1 | Add-Member -MemberType NoteProperty -Name QueryTitle -Value 'Blitz_Detailed'
    $query1 | Add-Member -MemberType NoteProperty -Name Query -Value 'EXEC DBAUtil.dbo.sp_Blitz @bringthepain = 1'
    $query1 | Add-Member -MemberType NoteProperty -Name Description -Value 'General recommendations based on instance/database settings'
    $query1 | Add-Member -MemberType NoteProperty -Name DBSpecific -Value $false

    $query2 = New-Object -TypeName PSObject
    $query2 | Add-Member -MemberType NoteProperty -Name QueryNr -Value 2
    $query2 | Add-Member -MemberType NoteProperty -Name QueryTitle -Value 'Blitz_Summary'
    $query2 | Add-Member -MemberType NoteProperty -Name Query -Value 'EXEC DBAUtil.dbo.sp_Blitz @summarymode = 1'
    $query2 | Add-Member -MemberType NoteProperty -Name Description -Value 'General recommendations summary based on instance/database settings'
    $query2 | Add-Member -MemberType NoteProperty -Name DBSpecific -Value $false


    #...These two queries were built above
    [PSObject[]] $queries = @($query1, $query2)


    #Now $queries can be passed into the function call
    $output = Export-QueryToSQLTable `
            -Queries $queries `
            -RunOnInstances @($runOnInstance) `
            -RunIncludeDBs @() `
            -RunExcludeDBs @() `
            -RunExcludeAllSystemDBs: $true `
            -RunExcludeAllUserDBs: $false `
            -RunOnDBsWithOwner @() `
            -RunOnDBsWithStatus @('Normal') `
            -SaveResultsToInstance $saveToInstance `
            -SaveResultsToDatabase $saveToDatabase `
            -SaveResultsToSchema $saveToSchema `
            -SaveResultsTruncateBeforeSave: $true `
            -CreateOutputTableWarningAction 'Continue'

.EXAMPLE

    #This examples show how to run your own custom queries and save the output to tables

    Import-Module dbatools

    . D:\PowerShell\Export-DMVInformation.ps1
    . D:\PowerShell\Export-QueryToSQLTable.ps1


    [string] $saveToInstance = '<YOUR_INSTANCE_NAME>'
    [string] $runOnInstance = '<YOUR_INSTANCE_NAME>'
    [string] $saveToDatabase = 'DBAUtil'
    [string] $saveToSchema = 'dbo'


    $query1 = New-Object -TypeName PSObject
    $query1 | Add-Member -MemberType NoteProperty -Name QueryNr -Value 1
    $query1 | Add-Member -MemberType NoteProperty -Name QueryTitle -Value 'Log space usage'
    $query1 | Add-Member -MemberType NoteProperty -Name Query -Value 'select * from sys.dm_db_log_space_usage'
    $query1 | Add-Member -MemberType NoteProperty -Name Description -Value 'Gets log space usage for specific database (being run against)'
    $query1 | Add-Member -MemberType NoteProperty -Name DBSpecific -Value $true

    $query2 = New-Object -TypeName PSObject
    $query2 | Add-Member -MemberType NoteProperty -Name QueryNr -Value 2
    $query2 | Add-Member -MemberType NoteProperty -Name QueryTitle -Value 'Misc_001_OS_Performance_Counters'
    $query2 | Add-Member -MemberType NoteProperty -Name Query -Value (Get-Content -LiteralPath "D:\Queries\OSPerformanceCounters.sql" | Out-String)
    $query2 | Add-Member -MemberType NoteProperty -Name Description -Value 'OS Performance counters'
    $query2 | Add-Member -MemberType NoteProperty -Name DBSpecific -Value $false

    #...These two queries were built above
    [PSObject[]] $queries = @($query1, $query2)


    #Now $queries can be passed into the function call
    $output = Export-QueryToSQLTable `
            -RunOnInstanceSqlCredential $runOnInstanceSqlCredential `
            -SaveToInstanceSqlCredential $saveToInstanceSqlCredential `
            -Queries $queries `
            -RunOnInstances @($runOnInstance) `
            -RunIncludeDBs @() `
            -RunExcludeDBs @() `
            -RunExcludeAllSystemDBs: $true `
            -RunExcludeAllUserDBs: $false `
            -RunOnDBsWithOwner @() `
            -RunOnDBsWithStatus @('Normal') `
            -SaveResultsToInstance $saveToInstance `
            -SaveResultsToDatabase $saveToDatabase `
            -SaveResultsToSchema $saveToSchema `
            -SaveResultsTruncateBeforeSave: $false `
            -CreateOutputTableWarningAction 'Continue'
  
.NOTES 
    
    

Version History 
    v1.0   - Jana Sattainathan - Jan.06.2017
             
.LINK 
    N/A
#>

function Export-QueryToSQLTable
{ 
    [CmdletBinding()] 
    param( 

        [Parameter(Mandatory=$false)] 
        [int64] $CaptureSetID = [int64]::Parse((Get-Date).ToString('yyyyMMddHHmmss')),

        [Parameter(Mandatory=$false)] 
        [System.Management.Automation.PSCredential]$RunOnInstanceSqlCredential = $NULL,

        [Parameter(Mandatory=$false)] 
        [System.Management.Automation.PSCredential]$SaveToInstanceSqlCredential = $NULL,

        #See the comment description for the parameters in documentation above for specifics about each parameter
        
        #This parameter is a custom object (PSObject) with certain minimum attributes expected! See comments above for usage examples
        [Parameter(Mandatory=$true)] 
        [PSObject[]] $Queries,

        [Parameter(Mandatory=$true)] 
        [string[]] $RunOnInstances,

        [Parameter(Mandatory=$false)] 
        [string[]] $RunIncludeDBs = @(), #ALL

        [Parameter(Mandatory=$false)] 
        [object[]] $RunExcludeDBs = @(),

        [Parameter(Mandatory=$false)] 
        [switch] $RunExcludeAllSystemDBs = $true,

        [Parameter(Mandatory=$false)] 
        [switch] $RunExcludeAllUserDBs = $false,

        [Parameter(Mandatory=$false)] 
        [string[]] $RunOnDBsWithOwner = @(),

        [Parameter(Mandatory=$false)] 
        [string[]] $RunOnDBsWithStatus = @('Normal'),

        #If empty value is passed for this paramter, value should be specified as property of Queries input parameter
        [Parameter(Mandatory=$false)] 
        [string] $SaveResultsToInstance = '',           

        #If empty value is passed for this paramter, value should be specified as property of Queries input parameter
        [Parameter(Mandatory=$false)] 
        [string] $SaveResultsToDatabase = '',

        #If empty value is passed for this paramter, value should be specified as property of Queries input parameter
        [Parameter(Mandatory=$false)] 
        [string] $SaveResultsToSchema = 'dbo',          #Schema must already exist!

        [Parameter(Mandatory=$false)] 
        [switch] $SaveResultsTruncateBeforeSave = $false,

        [Parameter(Mandatory=$false)] 
        [int] $QueryTimeout = 60,

        [Parameter(Mandatory=$false)] 
        [int] $ConnectionTimeout = 5, 

        #If there was a warning reported when creating the output table, what should be done Stop, Continue or SilentlyContinue
        [Parameter(Mandatory=$false)] 
        [string] $CreateOutputTableWarningAction = 'Stop'

    )

    
    [string] $fn = $MyInvocation.MyCommand
    [string] $stepName = "Begin [$fn]"
    [object] $returnObj = $null

    [int64] $Global:captureSetLine = 1  #Has to be global to be usable in SELECT's (for row sequence value generation)
    [string] $saveToInstanceName = ''
    [string] $saveToDatabaseName = ''
    [string] $saveToSchemaName = 'dbo'
    [string] $saveToTableName = ''
    [bool] $saveTruncateBeforeSave = $false
    [bool] $skipPK = $false
    [int] $instanceCounter = 0
    [int] $queryCounter = 0
    [int] $dbCounter = 0
    [object[]] $specificDatabases = @()

    [HashTable]$params = @{
            'Queries (count)' = $Queries.Count;
            'RunOnInstances' = $RunOnInstances;
            'RunExcludeDBs' = $RunExcludeDBs;
            'RunExcludeAllSystemDBs' = $RunExcludeAllSystemDBs;
            'RunExcludeAllUserDBs' = $RunExcludeAllUserDBs;
            'RunOnDBsWithOwner' = $RunOnDBsWithOwner;
            'RunOnDBsWithStatus' = $RunOnDBsWithStatus;
            'SaveResultsToInstance' = $SaveResultsToInstance;
            'SaveResultsToDatabase' = $SaveResultsToDatabase;
            'SaveResultsToSchema' = $SaveResultsToSchema;
            'SaveResultsTruncateBeforeSave' = $SaveResultsTruncateBeforeSave;
            'QueryTimeout' = $QueryTimeout;
            'ConnectionTimeout' = $ConnectionTimeout;
            'CaptureSetID' = $CaptureSetID}


    try
    {        

        $stepName = "[$fn]: Validate parameters"
        #--------------------------------------------        
        Write-Verbose $stepName  

        

        $stepName = "Run of every instance specified"
        #--------------------------------------------        
        Write-Host $stepName  

        foreach($runOnInstance in $RunOnInstances)
        {
            $instanceCounter++
            $specificDatabases = @()

            Write-Progress -Activity "Instances progress:" `
                            -PercentComplete ([int](100 * $instanceCounter / $RunOnInstances.Length)) `
                            -CurrentOperation ("Completed {0}%" -f ([int](100 * $instanceCounter / $RunOnInstances.Length))) `
                            -Status ("Working on [{0}]" -f $runOnInstance) `
                            -Id 1

            $stepName = "Run each query and export results to table"
            #--------------------------------------------        
            Write-Host $stepName  

            foreach ($query in $Queries)
            {   
                $queryCounter++
                $dbCounter = 0
                $dataTable = $null
                $Global:captureSetLine = 1  #Has to be global to be usable in SELECT's
                $skipPK = $false

                Write-Progress -Activity "DMV Queries progress:" `
                               -PercentComplete ([int](100 * $queryCounter / $Queries.Length)) `
                               -CurrentOperation ("Completed {0}%" -f ([int](100 * $queryCounter / $Queries.Length))) `
                               -Status ("Working on [{0}]" -f $query.QueryTitle) `
                               -Id 2 `
                               -ParentId 1

                $stepName = "Get the list of qualifying databases"
                #--------------------------------------------        
                Write-Host $stepName  

                #Default is to run against master if DMV is not DB specific
                $databases = @('master')

                #If DMV is DB specific, then we need to be more discerning
                if ($query.DBSpecific -eq $true)
                {       
                    #Only fetch for the first time around for a specific query
                    if ($specificDatabases.Count -le 0)
                    {
                        $specificDatabases = Get-DbaDatabase `
                                    -SqlInstance $runOnInstance `
                                    -SqlCredential $RunOnInstanceSqlCredential `
                                    -ExcludeDatabase $RunExcludeDBs `
                                    -ExcludeAllUserDb: $RunExcludeAllUserDBs `
                                    -ExcludeAllSystemDb: $RunExcludeAllSystemDBs `
                                    -Status $RunOnDBsWithStatus `
                                    -Owner $RunOnDBsWithOwner `
                                    -Database $RunIncludeDBs

                        if ($specificDatabases.Count -eq 0)
                        {
                            Write-Error 'No specific databases qualified!'
                        }
                    }
        
                    $databases = $specificDatabases |
                                    Select-Object Name -ExpandProperty Name
                }


                $stepName = "Run query on qualifying databases"
                #--------------------------------------------        
                Write-Host $stepName  

                foreach($database in $databases)
                {
                    $dbCounter++

                    Write-Progress -Activity "Databases progress for query:" `
                                   -PercentComplete ([int](100 * $dbCounter / $databases.Length)) `
                                   -CurrentOperation ("Completed {0}%" -f ([int](100 * $dbCounter / $databases.Length))) `
                                   -Status ("Inner loop working on item [{0}]" -f $database) `
                                   -Id 3 `
                                   -ParentId 2

                    $stepName = "Decide on target schema/table names etc"
                    #--------------------------------------------        

                    #If the input Query has target table information specified, use it, else generate using the query name

                    #InstanceName
                    #---------------------
                    if (($query | Get-Member | Select-Object Name | Where-Object{$_.Name.ToUpper() -eq 'SAVERESULTSTOINSTANCE'}) -ne $null)
                    {
                        $saveToInstanceName = $query.SaveResultsToInstance
                    }
                    else
                    {
                        $saveToInstanceName = $SaveResultsToInstance
                    }

                    if ($saveToInstanceName.Trim().Length -eq 0) { Throw "SaveResultsToInstance is empty. Specify it as a parameter or as an attribute with non-empty value in Queries input parameter! See examples for reference."}

                    #DatabaseName
                    #---------------------
                    if (($query | Get-Member | Select-Object Name | Where-Object{$_.Name.ToUpper() -eq 'SAVERESULTSTODATABASE'}) -ne $null)
                    {
                        $saveToDatabaseName = $query.SaveResultsToDatabase
                    }
                    else
                    {
                        $saveToDatabaseName = $SaveResultsToDatabase
                    }

                    if ($saveToDatabaseName.Trim().Length -eq 0) { Throw "SaveResultsToDatabase is empty. Specify it as a parameter or as an attribute with non-empty value in Queries input parameter! See examples for reference."}

                    #SchemaName
                    #---------------------
                    if (($query | Get-Member | Select-Object Name | Where-Object{$_.Name.ToUpper() -eq 'SAVERESULTSTOSCHEMA'}) -ne $null)
                    {
                        $saveToSchemaName = $query.SaveResultsToSchema
                    }
                    else
                    {
                        $saveToSchemaName = $SaveResultsToSchema
                    }

                    if ($saveToSchemaName.Trim().Length -eq 0) { Throw "SaveResultsToSchema is empty. Specify it as a parameter or as an attribute with non-empty value in Queries input parameter! See examples for reference."}

                    #TableName
                    #---------------------
                    if (($query | Get-Member | Select-Object Name | Where-Object{$_.Name.ToUpper() -eq 'SAVERESULTSTOTABLE'}) -ne $null)
                    {
                        $saveToTableName = $query.SaveResultsToTable
                    }
                    else
                    {
                        $saveToTableName = $query.QueryTitle -Replace "[#?\{\[\(\)\]\}\ \,\.\']", '_' #Replace junk with underscore!
                    }

                    if ($saveToTableName.Trim().Length -eq 0) { Throw "SaveResultsToTable is empty. Specify a non-empty QueryTitle for query or as an attribute with non-empty value in Queries input parameter! See examples for reference."}

                    #TruncateBeforeSave?
                    #---------------------
                    if (($query | Get-Member | Select-Object Name | Where-Object{$_.Name.ToUpper() -eq 'SAVERESULTSTRUNCATEBEFORESAVE'}) -ne $null)
                    {
                        $saveTruncateBeforeSave = $query.SaveResultsTruncateBeforeSave
                    }
                    else
                    {
                        $saveTruncateBeforeSave = $SaveResultsTruncateBeforeSave
                    }


                    $stepName = "Running query: [{0}] on [{1}]" -f $query.QueryTitle, $database
                    #--------------------------------------------                    
                    Write-Host $stepName  
                    Write-Host '--------------------------------------------------'

                    $invokeParams = @{ 
                                        ServerInstance = $runOnInstance 
                                        Query = $query.Query
                                        Database = $database 
                                        QueryTimeout = $QueryTimeout
                                        ConnectionTimeout = $ConnectionTimeout
                                        As = "PSObject" 
                                    }
                    if ($RunOnInstanceSqlCredential) {$invokeParams.Add('Credential', $RunOnInstanceSqlCredential)}

                    $dataTable = Invoke-DBASqlcmd @invokeParams

                    $rowCount = 0
                    if ($dataTable -ne $null)
                    {
                        $rowCount = @($dataTable).Count
                    }

                    #In case the consumer of this function needs to record details, we return a nicely packaged return object for each execution
                    $returnObj = New-Object PSObject
                    $returnObj | Add-Member -NotePropertyName 'CaptureSetID' -NotePropertyValue $CaptureSetID
                    $returnObj | Add-Member -NotePropertyName 'RunOnInstance' -NotePropertyValue $runOnInstance
                    $returnObj | Add-Member -NotePropertyName 'RunOnDatabase' -NotePropertyValue $database
                    $returnObj | Add-Member -NotePropertyName 'QueryTitle' -NotePropertyValue $query.QueryTitle
                    $returnObj | Add-Member -NotePropertyName 'Query' -NotePropertyValue $query.Query
                    $returnObj | Add-Member -NotePropertyName 'QueryDescription' -NotePropertyValue $query.Description
                    $returnObj | Add-Member -NotePropertyName 'SaveToInstance' -NotePropertyValue $saveToInstanceName
                    $returnObj | Add-Member -NotePropertyName 'SaveToDatabase' -NotePropertyValue $saveToDatabaseName
                    $returnObj | Add-Member -NotePropertyName 'SaveToSchema' -NotePropertyValue $saveToSchemaName
                    $returnObj | Add-Member -NotePropertyName 'SaveToTable' -NotePropertyValue $saveToTableName
                    $returnObj | Add-Member -NotePropertyName 'SaveToTruncateBeforeSave' -NotePropertyValue $saveTruncateBeforeSave
                    $returnObj | Add-Member -NotePropertyName 'RowCount' -NotePropertyValue $rowCount
                    $returnObj | Add-Member -NotePropertyName 'Status' -NotePropertyValue 'Success'
                    $returnObj | Add-Member -NotePropertyName 'StatusDescription' -NotePropertyValue '[None]'
                    $returnObj | Add-Member -NotePropertyName 'DateTimeStamp' -NotePropertyValue Get-Date

                    try
                    {

                        #Skip table if results are null or if there are no columns returned!
                        if ($rowCount -eq 0)
                        {
                            Write-Warning ("Null output was returned for query: [{0}]. Skipping." -f $query.QueryTitle)
                        }
                        else
                        {
                            $stepName = "Adding custom columns to output"
                            #--------------------------------------------            

                            #  Add additional columns that are of interest to identify instances/databases/runs/time etc
                            $resultsWAddlCols = $dataTable |                                        
                                                <#Select-Object `
                                                    -Property * `
                                                    -ExcludeProperty RowState, RowError, Table, ItemArray, HasErrors  | #>
                                                SELECT `
                                                        @{Label="CaptureSetID";Expression={[int64]$CaptureSetID}},
                                                        @{Label="CaptureSetLine";Expression={[int64]$Global:captureSetLine;$Global:captureSetLine++}},
                                                        @{Label="CaptureInstance";Expression={[string]$runOnInstance}},
                                                        @{Label="CaptureDB";Expression={[string]$database}},
                                                        @{Label="CaptureDate";Expression={Get-Date}},
                                                        *

                            $stepName = "Select only the columns already in the target table and ignore extra columns (if table exists): [{0}]" -f $saveToTableName
                            #--------------------------------------------                                        
                            #This will ensure that the function has the most compatibility when there are slight column variations in SQL statements 

                            $sql = "SELECT name FROM sys.columns WHERE object_id = OBJECT_ID('{0}.{1}') " -f $saveToSchemaName, $saveToTableName

                            #Splat inputs (except SQL) and run the sql
                            $invokeParams = @{ 
                                                ServerInstance = $saveToInstanceName                                                     
                                                Database = $saveToDatabaseName 
                                                QueryTimeout = $QueryTimeout
                                                ConnectionTimeout = $ConnectionTimeout
                                                As = "PSObject" 
                                            }
                            if ($SaveToInstanceSqlCredential) {$invokeParams.Add('Credential', $SaveToInstanceSqlCredential)}

                            $dataTable = Invoke-DBASqlcmd @invokeParams -Query $sql

                            if ($dataTable -ne $NULL)
                            {
                                $colsAlreadyInTable = ($dataTable | Select-Object -ExpandProperty name)

                                $dataTableWAddlCols = $resultsWAddlCols | 
                                                    Select-Object $colsAlreadyInTable |
                                                    Out-DbaDataTable `
                                                        -WarningAction: SilentlyContinue #Supress warnings about columns whose datatypes cannot be converted
                            }
                            else
                            {
                                $stepName = "Convert from object array to DataTable"
                                #--------------------------------------------        
                                $dataTableWAddlCols = $resultsWAddlCols | 
                                                    Out-DbaDataTable `
                                                        -WarningAction: SilentlyContinue #Supress warnings about columns whose datatypes cannot be converted

                            }
                            

                            $stepName = "Saving to: [{0}.{1}]" -f $saveToSchemaName, $saveToTableName
                            #--------------------------------------------        
                            Write-Host $stepName  

                            $invokeParams = @{ 
                                                SqlInstance = $saveToInstanceName 
                                                InputObject = $dataTableWAddlCols
                                                Database = $saveToDatabaseName 
                                                Schema = $saveToSchemaName
                                                Table = $saveToTableName
                                                AutoCreateTable = $true
                                                Truncate = $saveTruncateBeforeSave
                                                #Need to stop if table cannot be created or something similar
                                                WarningAction = $CreateOutputTableWarningAction
                                            }
                            if ($SaveToInstanceSqlCredential) {$invokeParams.Add('SqlCredential', $SaveToInstanceSqlCredential)}
                            
                            #WARNING: Write-DbaDataTable currently has a bug if a schema other than 'dbo' is specified resulting in "WARNING: [Write-DbaDataTable][22:05:00] Schema does not exist."
                            Write-DbaDataTable @invokeParams                            

                            
                            #No need to create PK if we are looping through subsequent db's on the same instance for same query!
                            if ($skipPK -eq $false)
                            {
                                #Create a PK only if the table does not already have a PK (if user modified it but knows what he/she is doing, we dont care to be anal).

                                $stepName = "Check if PK exists on: [{0}]" -f $saveToTableName
                                #--------------------------------------------                                        

                                #Will have issues if the input schema/table name has enclosing square brackets!
                                $sql = "SELECT 1
                                            FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                                            WHERE OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
                                            AND EXISTS 
											(SELECT 1 FROM sys.tables t WHERE schema_name(t.schema_id) = TABLE_SCHEMA AND t.name = TABLE_NAME AND t.object_id = OBJECT_ID('{0}.{1}' ) " -f $saveToSchemaName, $saveToTableName

                                #Splat inputs (except SQL) and run the sql
                                $invokeParams = @{ 
                                                    ServerInstance = $saveToInstanceName                                                     
                                                    Database = $saveToDatabaseName 
                                                    QueryTimeout = $QueryTimeout
                                                    ConnectionTimeout = $ConnectionTimeout
                                                    As = "PSObject" 
                                                }
                                if ($SaveToInstanceSqlCredential) {$invokeParams.Add('Credential', $SaveToInstanceSqlCredential)}

                                $dataTable = Invoke-DBASqlcmd @invokeParams -Query $sql

                                                                
                                if ($dataTable -eq $null)
                                {
                                    
                                    #We need to create a PK on the table else subsequent Write-DbaDataTable will not APPEND data if it is still a HEAP 

                                    $stepName = "Creating PK on: [{0}]" -f $saveToTableName
                                    #--------------------------------------------        
                                    Write-Host $stepName  

                                    foreach($sql in @(
                                                        (("ALTER TABLE {0} ALTER COLUMN CaptureSetID BIGINT NOT NULL `n" + 
                                                         "ALTER TABLE {1} ALTER COLUMN captureSetLine BIGINT NOT NULL `n"
                                                         ) -f $saveToTableName, $saveToTableName),
                                                       (("ALTER TABLE {0} ADD CONSTRAINT {1} PRIMARY KEY CLUSTERED (CaptureSetID, CaptureSetLine) `n"
                                                            ) -f $saveToTableName, "PK_$saveToTableName")
                                                    ))
                                    {
                                        #Run using the same spalt values as above (only SQL is different)
                                        $dataTable = Invoke-DBASqlcmd @invokeParams -Query $sql
                                    }
                                }

                                $skipPK = $true
                            }
                        }
                    }
                    catch
                    {
                        #Ignore PK already exists error!
                        if ($_.Exception.ErrorCode -ne -2146232060)
                        {
                            Write-Error "Error in step [$stepName] during Table/PK creation: $($_.Exception.Message)"
                        }

                        $returnObj.Status = 'Error'
                        $returnObj.StatusDescription = "Error in step [$stepName]: $($_.Exception.Message)"
                    }
                    finally
                    {
                        $returnObj
                    }
                }
            }
        }


        $stepName = "Completed export!"
        #--------------------------------------------        
        Write-Host $stepName  

    }
    catch
    {
        [Exception]$ex = $_.Exception
        Throw "Unable to export queries to database tables! Error in step: `"{0}]`" `n{1}" -f `
                        $stepName, $ex.Message
    }
    finally
    {
        #Return value if any

    }
}
    

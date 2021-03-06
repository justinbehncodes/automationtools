Function Convert-ArrayListToHTMLTable{
    <#
    .SYNOPSIS
    Converts an array list to a HTML table
    
    .DESCRIPTION
    Converts an array list and its data to a HTML table
    
    .PARAMETER ArrayList
    The list that will be converted to a HTML table
    
    .PARAMETER TableName
    An optional table name to be injected into the data table
    
    .PARAMETER AsCustomObject
    Return the HTML table as a PSCustomObject
    
    .PARAMETER Limit
    An upper limit for the maximum amount of records that can be added into the HTML table
    
    .EXAMPLE
    Convert-ArrayListToHTMLTable -ArrayList $List -AsCustomObject
    
    .NOTES
    Primarily used for AutomationTools internal email functions
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$False)]
        [System.Collections.ArrayList]$ArrayList,
        [String]$TableName,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
        [Switch]$AsCustomObject,
        [Int]$Limit
    )
    BEGIN{
        Write-Log -Message "[$($MyInvocation.MyCommand)] Called" -Type SYS
        $Names = @()
        Foreach($NoteProperties in $ArrayList[0].PSObject.Properties){
            $Names += $NoteProperties.Name
        }
        $Table = New-Object System.Data.DataTable "$TableName"
        Foreach($Name in $Names){
            $Column = New-Object System.Data.DataColumn "$($Name)",([String])
            $Table.Columns.Add($Column)
        }
    }
    PROCESS{
        $I = 0
        Foreach($Element in $ArrayList){
            $Row = $Table.NewRow()
            Foreach($Name in $Names){
                $Row."$Name" = ($Element.$Name)
            }
            if($Limit){
                if($I -lt $Limit){
                    $Table.Rows.Add($Row)
                }
                $I++
            } else {
                $Table.Rows.Add($Row)
            }
        }
    }
    END{
        [String]$HTMLTable = $Table | Select-Object -Property $Names | ConvertTo-Html -Fragment
        if($AsCustomObject){
            $Return = [PSCustomObject]@{
                TableName = $TableName
                TableData = $HTMLTable
            }
        } else {
            $Return = $HTMLTable
        }
        return $Return
    }
}

Function ConvertTo-Version{
    <#
    .SYNOPSIS
    Converts a string to a Version object
    
    .DESCRIPTION
    Converts a string variable to a Version object
    
    .PARAMETER String
    The string to be converted to Version 
    
    .EXAMPLE
    "1.0.0.0" | ConvertTo-Version
    
    .NOTES
    Limits output to four octets
    #>
    [OutputType([Version])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [String[]]$String
    )
    BEGIN{
        Write-Log -Message "[$($MyInvocation.MyCommand)] Called" -Type SYS
    }
    PROCESS{
        Foreach ($Item in $String){
            if($Item -match "\.*"){
                $VersionBase = "{0}.{1}.{2}.{3}"
                $Numbers = @("0","0","0","0")
                $Split = $Item.Split(".")[0..3]
                $Index = 0
                Foreach($Element in $Split){
                    if($Element -ne ""){
                        $Numbers[$Index] = $Element
                    }
                    $Index++
                }
                Try{
                    $Version = [Version]($VersionBase -f $Numbers[0],$Numbers[1],$Numbers[2],$Numbers[3])
                } Catch {
                    $_ | Write-Log -Message "Error formatting string" -Type ERR -Console
                    $Version = $null
                }
            } else {
                $Version = $null
            }
            return $Version
        }
    }
    END{
    }
}

function Convert-HashToPSObject () {
    <#
    .SYNOPSIS
    Converts a hash table to a PSCustomObject
    
    .DESCRIPTION
    Converts a hash table to a PSCustomObject, keeping depth if detected
    
    .PARAMETER Object
    The hashtable object to be converted
    
    .EXAMPLE
    $Data | Convert-HashToPSObject
    
    .NOTES
    Returns null if unsuccessful
    #>
    [OutputType([PSObject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [Object[]]$Object
    )
    BEGIN{
        Write-Log -Message "[$($MyInvocation.MyCommand)] Called" -Type SYS
    }
    PROCESS{
        Foreach($Item in $Object){
            $I = 0
            Foreach($Hash in $Item){
                if($Hash.GetType().Name -eq "hashtable"){
                    $Output = New-Object -TypeName PSObject
                    Add-Member -InputObject $Output -MemberType ScriptMethod -Name AddNote -Value {
                        Add-Member -InputObject $This -MemberType NoteProperty -Name $args[0] -Value $args[1]
                    }
                    $Hash.Keys | Sort-Object | Foreach-Object{
                        Try{
                            $Output.AddNote($_,$Hash.$_)
                        } Catch {
                            if($null -eq $_){$Name = "null"}else{$Name = $_}
                            if($null -eq $Hash.$_){$Value = "null"}else{$Value = $Hash.$_}
                            $Output.AddNote($Name,$Value)
                        }
                    }
                    $Output
                } else {
                    Write-Log -Message "Element given was not of type Hashtable" -Type ERR -Console
                    $null
                }
                $I++
            }
        }
    }
    END{
    }
}

Function Get-FlattenedObject{
    <#
    .SYNOPSIS
    Flattens the depth of a PSCustomObject
    
    .DESCRIPTION
    Flattens a PSCustomObjects's depth into a human-readable format
    
    .PARAMETER Object
    The object that will be flattened
    
    .PARAMETER MasterList
    This should only be called by recursion, do not call manually
    
    .PARAMETER Parent
    This should only be called by recursion, do not call manually
    
    .EXAMPLE
    $Object | Get-FlattenedObject
    
    .NOTES
    Primarily used for flattening data tables before being injected into HTML documents
    #>
    [OutputType([PSObject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [Object[]]$Object,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
        [System.Collections.ArrayList]$MasterList,
        [String]$Parent
    )
    BEGIN{
    }
    PROCESS{
        Foreach($Item in $Object){
            if($Item.GetType().Name -match "PSObject|PSCustomObject"){
                if(!$MasterList){
                    $MasterList = New-Object System.Collections.ArrayList
                }
                if(!$Parent){
                    $Parent = "Root"
                }
                $ObjProps = $Item | Get-Member -MemberType Property,NoteProperty | ForEach-Object Name
                $ObjProps = $ObjProps | ForEach-Object{"$Parent -> $_"}
                Foreach($Prop in $ObjProps){
                    $ObjProp = $Prop -replace "$Parent -> ",""
                    if($null -ne $Item.$ObjProp){
                        $ChildObj = $Item.$ObjProp | Get-Member
                    } else {
                        $ChildObj = "None"
                    }

                    if($ChildObj.MemberType -match "NoteProperty"){
                        $MasterList = $Item.$ObjProp | Get-FlattenedObject -MasterList $MasterList -Parent "$Parent -> $ObjProp"
                    } else {
                        $Record = [PSCustomObject]@{
                            Location = $Prop
                            Value = $Item.$ObjProp
                        }
                        $MasterList.Add($Record) | Out-Null
                    }
                }
                $MasterList
            } else {
                Write-Log -Message "Entity given was not of type PSObject" -Type ERR -Console
                $null
            }
        }
    }
    END{
    }
}

Function Convert-ArrayToScriptBlock{
    <#
    .SYNOPSIS
    Converts an array of strings into a ScriptBlock object
    
    .DESCRIPTION
    Converts an array of strings into a ScriptBlock object
    
    .PARAMETER Array
    The array that will be converted
    
    .EXAMPLE
    ,$Object | Convert-ArrayToScriptBlock

    NOTE: The comma operand prior to the array object is required for pipeline use

    .EXAMPLE
    Convert-ArrayToScriptBlock -Array $Object

    NOTE: The comma operand prior to the array object is not required for non-pipeline use
    
    .NOTES
    Pay attention to the , operator when using this function with pipeline
    #>
    [OutputType([System.Management.Automation.ScriptBlock])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [Object]$Array
    )
    BEGIN{
        Write-Log -Message "[$($MyInvocation.MyCommand)] Called" -Type SYS
    }
    PROCESS{
        if($Array.GetType() -match "Object\[\]"){
            $String = $Array -join " "
            [scriptblock]::Create($String)
        } else {
            Write-Log -Message "Entity given was not of type Object" -Type ERR -Console
            $null
        }
    }
    END{
    }
}
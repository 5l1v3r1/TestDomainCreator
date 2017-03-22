configuration NewTestEnvironment
{        
    Import-DscResource -ModuleName xActiveDirectory
    
    Login-AzureRmAccount

    $credParams = @{
        ResourceGroupName = 'Group'
        AutomationAccountName = 'adamautomation'
    }
    $defaultAdUserCred = Get-AutomationPSCredential -Name 'Default AD User Password'
    $domainSafeModeCred = Get-AutomationPSCredential -Name 'Domain safe mode'
            
    Node $AllNodes.Where{$_.Purpose -eq 'Domain Controller'}.NodeName
    {

        @($ConfigurationData.NonNodeData.ADGroups).foreach( {
                xADGroup $_
                {
                    Ensure = 'Present'
                    GroupName = $_
                    DependsOn = '[xADDomain]ADDomain'
                }
            })

        @($ConfigurationData.NonNodeData.OrganizationalUnits).foreach( {
                xADOrganizationalUnit $_
                {
                    Ensure = 'Present'
                    Name = ($_ -replace '-')
                    Path = ('DC={0},DC={1}' -f ($ConfigurationData.NonNodeData.DomainName -split '\.')[0], ($ConfigurationData.NonNodeData.DomainName -split '\.')[1])
                    DependsOn = '[xADDomain]ADDomain'
                }
            })

        @($ConfigurationData.NonNodeData.ADUsers).foreach( {
                xADUser "$($_.FirstName) $($_.LastName)"
                {
                    Ensure = 'Present'
                    DomainName = $ConfigurationData.NonNodeData.DomainName
                    GivenName = $_.FirstName
                    SurName = $_.LastName
                    UserName = ('{0}{1}' -f $_.FirstName.SubString(0, 1), $_.LastName)
                    Department = $_.Department
                    Path = ("OU={0},DC={1},DC={2}" -f $_.Department, ($ConfigurationData.NonNodeData.DomainName -split '\.')[0], ($ConfigurationData.NonNodeData.DomainName -split '\.')[1])
                    JobTitle = $_.Title
                    Password = $defaultAdUserCred.Password
                    DependsOn = '[xADDomain]ADDomain'
                }
            })

        ($Node.WindowsFeatures).foreach( {
                WindowsFeature $_
                {
                    Ensure = 'Present'
                    Name = $_
                }
            })        
        
        xADDomain ADDomain          
        {             
            DomainName = $ConfigurationData.NonNodeData.DomainName
            DomainAdministratorCredential = $domainSafeModeCred
            SafemodeAdministratorPassword = $domainSafeModeCred
            DependsOn = '[WindowsFeature]AD-Domain-Services'
        }
    }         
} 

$configDataFilePath = "$env:TEMP\ConfigData.psd1"
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/adbertram/TestDomainCreator/master/ConfigurationData.psd1' -UseBasicParsing -OutFile $configDataFilePath
$configData = Invoke-Expression (Get-Content -Path $configDataFilePath -Raw)
NewTestEnvironment -ConfigurationData $configData -WarningAction SilentlyContinue
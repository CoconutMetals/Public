<# GOAL : Create a function to complete the IT side of the onboarding process for a new employee ( AD, Outlook, EPICS).
This function will need to be able to accomplish several things.

1. Allow the user of the function to input first and last name, location, department, job title, password, and AD groups for a new employee ✔
2. Take the entered credentials, and generate a new AD User
    - Add email ✔
    - Configure name and logon name ✔
    - Note Office (Dept) and Description (Job) ✔
    - Add plant address ✔
    - Add phone number for plant, plus extension if applicable ✔
    - Add to correct OU (Based upon location) ✔
    - Send password in email to admins@company.com ✔

3. Take the entered credentials, and generate a new email account
    - Apply a Business Standard license ✔
    - Add address and plant phone number ✔
    - Apply Job Title and Dept ✔
    - Password ✔
    - Distribution Groups ✔

4. Output commands which can be used to verify this creation. ✔
5. Have a network folder made for the user ✔
6. Devise logging ❌
7. EPICS? No, no ability to tie EPICS into this. I sent a request to their helpdesk (1/6/2021),  they actually said they've never heard that request.
8. Break up the different account creations, let the admin choose which portions to use ✔
#>


<#
.SYNOPSIS
    Create a new employee for Company
.DESCRIPTION
    This function aims to automate the creation of a new employee; specifically, adding him or her to the Company Active Directory, and to Outlook. User running this command should be able to input some pertinent information, and be done.

    The script will request a small handfull of information to define the new user, and credentials for Office 365/MSonline. 
.EXAMPLE
    New-Employee
    Provide the parameters requested, be sure the location is an abbreviation of a valid state.
#>
function New-Employee {
        [CmdletBinding(
            SupportsShouldProcess = $true,
            ConfirmImpact = 'High'
        )]
        param (
            [Parameter(
                Mandatory
            )]
            [string]$first,

            [Parameter(
                Mandatory 
            )]
            [String]$last,

            [Parameter(
                Mandatory 
            )]
            [String]$dept,

            [Parameter(
                Mandatory
            )]
            [String]$job,

            [Parameter(
                Mandatory
            )]
            [ValidateSet("FL","TN","AZ","GA","Sales")]
            [String]$location,

            [Parameter(
                Mandatory
            )]
            [String]$msPass,

            # The user noted here will be used to determine the AD groups for the user being created.
            [Parameter(
                Mandatory
            )]
            [string]$groupCopy
        )
    
    # Some important variables getting asigned here. 
    try {
            # Getting extension
    $ext = Read-Host "Please add an extension for the new employee, if applicable. Otherwise, hit Enter."
    # filler, denoting for logging
    Write-Host "[INFO] Generating variables."
    # More variables, gathering credentials.
    $secPassword = ConvertTo-SecureString $msPass -AsPlainText -Force
    $fullName = "$first $last"
    $name = "$first$last"
    $logonName = $first.Substring(0,1)+$last
    $mail = "$logonName@company.com"
    $cred = Get-Credential -Message "Input Microsoft Administer credentials here."
    $CompanyEveryoneId = "Company - Everyone"


    }
    catch {
        Write-Host "[ERROR] Something failed in the process of creating variables and assigning credentials."
    }


    try {
    

     # Importing Azure, MS, and Exchange. From there, creating a session to connect to these services. Then, connecting to said services.
 
     Write-Host "[INFO] Importing MS, AD, and Exchange services." -ForegroundColor Red
     Import-Module MSOnline -ErrorAction Stop
     Import-Module ExchangeOnlineManagement -ErrorAction Stop
     Import-Module AzureAD

     Write-Host "[INFO] Generating session for Office 365 connection." -ForegroundColor Red
     $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri Https://outlook.office365.com/powershell-liveid/ -Credential $cred -Authentication Basic -AllowRedirection
     Import-PSSession $Session -DisableNameChecking -AllowClobber -ErrorAction Stop

     Write-Host "[INFO] Using user granted credentials to connect to MS and Exchange services." -ForegroundColor Red
     Connect-MsolService -Credential $cred -ErrorAction Stop
     Connect-ExchangeOnline -Credential $cred -ErrorAction Stop
 
    }
    catch {
        Write-Host "[ERROR] The script was unable to connect to one of various vital services."
    }
    

    # I'm trying to have the location entered above dictate all of the specific location info (city, street, number, etc) and the AD OU path. This also adds core distribution groups for Outlook

    if ($location -eq "TN") {
    $city = "Memphis"
    $number = "(985)-688-1234#$ext"
    $street = "Tennessee Street Avenue"
    $zip = "45645"
    $ADPath = "OU=321TN,OU=CompanyUsers,OU=Company,DC=Company,DC=com"
    $server = "321TN-DS"
    $filePath = '\\321TN-FS\users$'
    $CompanyGroupId = "Company - Tennessee Division"
    }
    elseif ($location -eq "sales") {
        $city = "Company Sales"
        $number = " "
        $street = " "
        $zip = " "
        $ADPath = "OU=321sales,OU=CompanyUsers,OU=Company,DC=Company,DC=com"
        $server = "321sales-DS"
        $filePath = '\\321fserver\321FL\USERS'
        $CompanyGroupId = "Company - Sales Department"
    }
    elseif ($location -eq "FL") {
        $city = "Tampa"
        $number = "(398)-641-9874#$ext"
        $street = "401 IDK street"
        $zip = "54417"
        $ADPath = "OU=321FL,OU=CompanyUsers,OU=Company,DC=Company,DC=com"
        $server = "321FL-DS"
        $filePath = '\\321server\321fl\USERS'
        $CompanyGroupId = "Company - Florida Division"
    }
    elseif ($location -eq "GA") {
        $city = "Macan"
        $number = "(965)-885-4564#$ext"
        $street = "49 Stuff RD"
        $zip = "33252"
        $ADPath = "OU=321GA,OU=CompanyUsers,OU=Company,DC=Company,DC=com"
        $server = "321GA-DS"
        $filePath = '\\321GA-FS\Users$'
        $CompanyGroupId = "georgiadivision@company.com"
    }
    elseif ($location -eq "AZ") {
        $city = "Phoenix"
        $number = "(227)-779-7784#$ext"
        $street = "South Bridge St"
        $zip = "55455"
        $ADPath = "OU=321AZ,OU=CompanyUsers,OU=Company,DC=Company,DC=com"
        $server = "321AZ-DS"
        $filePath = '\\321AZ-FS\Users$'
        $CompanyGroupId = "Company - Arizona Division"
    }
    else {
        Write-Output "[ERROR] Please enter a valid state abbreviation for the new user."
    }

    # Here is a splat for the AD creation. 

    $AdSplat = @{
        Name = $fullName;
        SamAccountName = $logonName;
        ChangePasswordAtLogon = $true;
        City = $City;
        Company = "Company";
        Country = "US";
        Office = $dept;
        Description = $job;
        DisplayName = $fullName;
        GivenName = $first;
        SurName = $last
        EmailAddress = $mail;
        State = $location;
        StreetAddress = $street;
        Officephone = $number;
        PostalCode = $zip;
        Path = $ADPath;
        Department = $dept;
        AccountPassword = $secPassword;
        Enabled = $true;
        Server = $server;
        UserPrincipalName = "$logonName@company.com"
    }

    # And a splat for a new 365 user

    $MSOlSplat = @{
        UserPrincipalName = $mail;
        DisplayName = $fullName;
        FirstName = $first;
        LastName = $last;
        Password = $msPass;
        UsageLocation = "US";
        Department = $dept;
        Office = $city;
        PhoneNumber = $number;
        title = $job
        City = $city;
        State = $location;
        PostalCode = $zip;
        Country = "US";
        StreetAddress = $street;
        ForceChangePassword = $true;
        LicenseAssignment = "Companynet:SMB_BUSINESS_PREMIUM"
    }

    # Instead of hand picking groups, I want to select a user to copy the groups from to apply to our new user here.

    Write-Host "[INFO] Provisioning groups." -ForegroundColor Magenta

    $groupTransition = Get-ADPrincipalGroupMembership $groupCopy

    $groupShift = $groupTransition.Name 

    $ADGroups = @()
    foreach ($group in $groupShift) 
    {
        if ($group -ne "Domain Users") 
        {
            # Add any groups not equal to Domain Users to $ADGroups
            # This prevents an error, because Domain Users is added automatically. If you try to add it again, you get an error. This filters out that error.
            $ADGroups = $ADGroups += $group   
        }
        
    }


    # Create a new user in AD
    $shouldAD = Read-Host -Prompt "Would you like to create an Active Directory account for this user? Enter 'yes' or 'y', otherwise this part will be skipped."
    
    if ($shouldAD -eq "yes" -or $shouldAD -eq "y") {
        try {
            Write-Host "[INFO] Beginning AD User creation." -BackgroundColor DarkBlue
            New-ADUser @AdSplat

            # This, below, was bananas for me to get right. I don't know why, but I had to try so many variations of Do-While and Do-Until to get it to behave.
            # This piece delays the script until the creation of the user above can be verified.

            do {
                $check = "valid"
                Write-Host "[INFO] Generating user, please wait." -BackgroundColor Green
                Start-Sleep 5
                
                try {
                    # Waiting on the user creation to complete before carrying on. 'Add elevator music here'
                    Write-Host "[INFO] Thinking about it..." -ForegroundColor Yellow -BackgroundColor White
                    Start-Sleep 15
                    Get-ADUser -Identity $logonName -ErrorAction Stop
                }
                catch {
                    $check = "error"
                    Write-Host "[INFO] Not done yet, back around we go." -ForegroundColor Blue 
                    Start-Sleep 5
                }
            } while ($check -eq "error")

            # Once the script can confirm the existance of the new user, groups are added.
            Add-ADPrincipalGroupMembership -Identity $logonName -MemberOf $ADGroups
        }
        catch {
            Write-Host "[ERROR] AD User could not be generated, or groups could not successfully be added."
        }
    }

 

    
    


    # Adding a new file for the described employee to the correct location based file server
    $shouldFile = Read-Host -Prompt "Would you like a folder to be generated for the user? Again, enter 'y' or 'yes', else this task will not be carried out."

    if ($shouldFile -eq "yes" -or $shouldFile -eq "y") {

        New-Item -ItemType Directory -Name $logonName -Path $filePath
        Write-Host "[INFO] Placing user folder in file server."

    }

    
    # Create an MS/365 account

    $shouldMS = Read-Host -Prompt "Do you want an O365 account to be made for the user? 'yes' or 'y' will create an account, any other answer will not."
    
    if ($shouldMS -eq 'y' -or $shouldMS -eq 'yes') {
        Write-Host "[INFO] Generating mailbox.." -ForegroundColor Black -BackgroundColor Red

        New-MsolUser @MSOlSplat 

        do {
            $check = "valid"
            Write-Host "[INFO] Generating mailbox..."
            Start-Sleep 5
            
            try {
                # Another loop waiting for user creation, prior to adding groups. 'More elevator music'
                Write-Host "[INFO] Generating mailbox....."
                Start-Sleep 15
                Get-Mailbox -Identity $mail -ErrorAction Stop
            }
            catch {
                $check = "error"
                Write-Host "[INFO] Not done yet, back around we go."
                Start-Sleep 5
            }
        } while ($check -eq "error")

        # Same loop as with AD, once user creation is confirmed, groups are added.

        Write-Host "[INFO] Adding mailbox to distribution lists."
        Add-DistributionGroupMember -Identity $CompanyGroupId -Member $mail
        Add-DistributionGroupMember -Identity $CompanyEveryoneId -Member $mail


    }
    
    $shouldMail = Read-Host -Prompt "Finally, would you like the Admin to be notifed of this creation, and the password disclosed? 'y' or 'yes' to do so."

    if ($shouldMail -eq 'y' -or $shouldMail -eq 'yes') {
        # Sending the generated password in an email

        Write-Host "[INFO] Sending confirmation email to admin...."

        $emailFrom = "admins@company.com"
        $emailTo = $cred.UserName

        $emailSplat = @{
            SMTPServer = "SMTP.office365.com";
            Port = 25;
            From = $emailFrom;
            To = $emailTo;
            Subject = "You have created a new employee!";
            credential = $cred;
            Body = 
            "Hello!

            I am here to inform you of the generation of a new Company employee (By you!), $fullName! And to note the password for said employee. 

            $msPass is the credential for the employee you have created!

            Thank you very much!"

    }

    Send-MailMessage @emailSplat -UseSsl

    }
    
    Write-Host "[INFO] Everything seems to have worked!"
}

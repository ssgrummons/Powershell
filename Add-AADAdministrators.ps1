<#
This script adds existing Azure Active Directory Users to an Azure AD Administrative Role from a CSV file.
All that is required is that the CSV file has a column named "Email" that contains valid Azure Active Directory users.
The $csvFile and $roleName variables can be edited as desired.
#>

$csvFile = "C:\Azure\Users.csv"
$roleName = "User Account Administrator"
$role = Get-AzureADDirectoryRole | Where {$_.DisplayName -eq $roleName}
$userRoleMembers =  Get-AzureADDirectoryRoleMember -ObjectId $userRole.ObjectID
$users = Import-Csv $csvFile
Foreach ($user in $users) {
    If ($UserRoleMembers.UserPrincipalName -notcontains $user.Email) {
        Write-Host $user.Email
        try {
            $AADUser = Get-AzureADUser -ObjectId $user.Email
            } 
        catch {
            Write-Host $user.Email " is not found in Azure Active Directory."
            Write-Host "Skipping this user."
            continue
        }
        Write-Host "Adding " $user.Email " to role " $role.DisplayName
        Add-AzureADDirectoryRoleMember -ObjectId $role.ObjectId -RefObjectID $AADUser.ObjectId
    }
}
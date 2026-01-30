Import-Csv "C:\ResetUsers.csv" | ForEach-Object {
    Set-ADAccountPassword -Identity $_.Username `
                          -NewPassword (ConvertTo-SecureString $_.NewPassword -AsPlainText -Force) `
                          -Reset
    Enable-ADAccount -Identity $_.Username
}

# glabms
Gilman Lab - Microsoft Edition

# Bootstrapping Chocolatey

This script bundle provides functionaliy for bootstrapping an offline network
of Windows machines with the ability to download and install Windows programs
using a combination of Chocolatey for package retrieval and ProGet for package
hosting. 

## Pre-Requisites
* All machines must be running Powershell 5.1 or later
* A machine with an online connection for aggregating required files
* A SMB share on the offline network for storing required files
  * This share must be accessible by all machines that need Chocolatey
* A machine that will host the ProGet server
  * This machine must be accessible by all machines that need Chocolatey

## Setup Instructions

### Uploading Required Files

* Download this entire repository onto a system with internet access
* [Download the offline install files for ProGet](https://docs.inedo.com/docs/desktophub/offline)
* Download the offline install files for SQL Server Express
  * [Download the online installer](https://go.microsoft.com/fwlink/?linkid=866658)
  * Run the installer and then select the *Download Media* option
  * Select *Express Core* and take note of the download location
  * The download will produce a *SQLEXPR_x64_ENU* executable
  * Run the executable and extract the contents to a local folder
* Run the setup script to aggregate all the required files together
  * `PS> .\choco\setup.ps1 -Operation Download -ProGetPath \path\to\proget\files -SqlPath \path\to\sql\files`
  * This will output all the files into the local directory under `.\files`
* Zip up the entire contents of this repository, including the files
* Move the zip archive to a machine on the offline network
* Extract the contents of the repository onto the offline machine
* Run the setup script and point to the SMB share to upload the required files
  * `PS> .\choco\setup.ps1 -Operation Upload -MountPath \\smbshare\path`

### Installing ProGet

* The previous step will have uploaded a copy of the repository to the SMB share
  * Download this copy to the machine where ProGet will be installed
* Run the ProGet installation script to install and configure the server
  * `PS> .\choco\proget.ps1 -MountPath \\smbshare\path -License myprogetlicense`
* Confirm the server is running at `http://localhost:8624/`

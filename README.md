# PowerShell Remote Admin Tool

![PowerShell Version](https://img.shields.io/badge/PowerShell-5.1%2B-blue)

A self-contained PowerShell WPF application for remote system administration. This tool provides a graphical user interface to manage a library of your custom scripts and execute them against single or multiple target computers.

<!--
![image](https://user-images.githubusercontent.com/12345/67890.png) 
*(Replace this with a screenshot of your tool in action)*
-->

## About The Project

This tool was created to solve a common problem for system administrators: running the same set of scripts across different computers, a process that is often repetitive and console-driven. The PowerShell Remote Admin Tool centralizes your custom scripts, provides a simple interface for targeting machines, and gives you a clear, consolidated output console.

The entire application is a single PowerShell script with no external module dependencies, making it portable and easy to run.

## Features

*   **Graphical User Interface**: Built with WPF for a user-friendly experience.
*   **Script Library Management**:
    *   Add and remove your own custom scripts to a persistent library.
    *   The library is managed via a simple `scripts.xml` file, making it easy to backup or share.
*   **Markdown Support**: Write your scripts inside `.md` files to keep your code and documentation bundled together.
*   **Formatted Script Preview**: The preview pane renders Markdown formatting (headers, bold) and displays PowerShell code in a distinct, monospaced block.
*   **Alternate Credential Support**: Run scripts as another user by providing a username and password.
*   **Multi-Computer Targeting**:
    *   Enter comma-separated computer names or IP addresses.
    *   Import a list of computers directly from a `.txt` or `.csv` file.
*   **Global Output Console**: All output, status messages, and errors from your scripts are displayed in one convenient, scrollable console.
*   **Self-Contained**: The entire tool is one `.ps1` file, requiring only PowerShell and the .NET Framework to run.

## Getting Started

### Prerequisites

*   Windows PowerShell 5.1 or later.
*   .NET Framework 4.5 or later (typically installed by default on modern Windows).

### Installation & First Run

1.  Download the `AdminTool.ps1` script (or the latest version) from this repository.
2.  Place the script in a dedicated folder (e.g., `C:\Tools\AdminTool`).
3.  Open a PowerShell terminal and navigate to the folder.
4.  You may need to set your PowerShell execution policy. Run this command:
    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```
5.  Run the tool:
    ```powershell
    .\AdminTool.ps1
    ```
6.  On the first run, the tool will automatically create an empty `scripts.xml` file in the same directory. This will store your script library.

## Usage

### 1. Create a Script File

The best way to use the tool is by creating `.md` (Markdown) files. This allows you to combine your documentation and code in one place for the best preview experience.

**Example `Get-Local-Admins.md`:**

````markdown
# Get Local Administrators

**Author:** Your Name
**Date:** 2026-01-21

## Description
This script connects to the target computer and queries the members of the local "Administrators" group. It is useful for security audits to see who has administrative rights on a machine.

### Notes
- This script will fail if the target computer is offline.
- The user running the script must have sufficient permissions.

# This is the code that will be executed.
Get-LocalGroupMember -Group "Administrators" | Select-Object Name, PrincipalSource, ObjectClass
````

### 2\. Add the Script to the Library

1.  In the tool, go to the Script Library tab.

2.  Click Add New Script....

3.  Give your script a friendly name (e.g., "Get Local Admins").

4.  Browse to and select the `.md` or `.ps1` file you created.

5.  Click OK. Your script is now saved in the library.

### 3\. Run a Script

1.  Go to the Remote Computer Info tab.

2.  Enter the name or IP address of the target computer(s) in the text box.

3.  (Optional) Enter a username and password if you need to run the script as a different user.

4.  Select your desired script from the Select & Run Action dropdown menu.

5.  The Script Preview pane will show you the full contents of the file, including the code that will be run.

6.  Click Run Selected Script.

7.  Watch the output appear in the Global Output Console at the bottom.

Remote Configuration (Important!)
---------------------------------

When you connect to a remote computer for the first time, especially by IP address, you will likely encounter a WinRM error. This is a security feature, not a bug.

To fix this, you must add the remote computer to your `TrustedHosts` list. Run the following command on your local machine in an Administrator PowerShell window:

```powershell
# Replace "IP_OR_HOSTNAME" with the actual IP address or name of your target machine
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "IP_OR_HOSTNAME" -Force
```

If you need to add multiple computers, you can provide a comma-separated list or use the -Concatenate switch to add to your existing list.

# WARAApp.ps1

## Requirements

- [**PowerShell 7+**](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5) (pwsh)
- [**Az PowerShell Module**](https://www.powershellgallery.com/packages/Az/14.1.0)
- [**WARA PowerShell Module**](https://www.powershellgallery.com/packages/wara/1.0.6) (version 1.0.6 or later)
- Sufficient permissions to install modules for the current user
- Azure account credentials with access to the relevant subscriptions

> **Note:** The script will attempt to install the Az and WARA modules automatically if they are not currently installed.

## Installation

1. Ensure you have PowerShell 7 or later installed.
2. The script will automatically install the required modules (`Az`, `WARA`) if they are not present.

## Usage

Before running the script, ensure you have changed your working directory in the terminal to the folder where you want the output files to be saved. For example:

```powershell
cd 'C:\Path\To\Desired\Output\Directory'
pwsh -ExecutionPolicy Bypass -File .\WARAApp.ps1
```

## Features

- **Interactive authentication**: Prompts for Azure Tenant ID and authenticates using your credentials.
- **Subscription selection**: Choose one or more Azure subscriptions interactively.
- **Collector modes**:
  - Entire subscription(s)
  - Specific resource groups
  - Resources filtered by tags (with optional resource group selection)
- **Runs WARA Collector**: Collects data from selected Azure resources.
- **Runs WARA Analyzer**: Automatically analyzes the most recent collector output JSON file in the current directory.

## Output

- The WARA Collector outputs a JSON file in the current directory.
- The WARA Analyzer processes this file and outputs analysis results.

## Notes

- The script uses `Out-GridView` for interactive selection. This may require running PowerShell on Windows or using compatible GUI environments.
- All actions and errors are logged to the console.
- The script is provided as-is, without warranty (see script header for full disclaimer).

## Troubleshooting

- If you encounter module installation issues, try running PowerShell as an administrator.
- Ensure you have network access to download modules from the PowerShell Gallery.
- If `Out-GridView` is not available, install the `Microsoft.PowerShell.GraphicalTools` module.

## License

See the disclaimer at the top of the script file.

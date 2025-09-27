# SharePoint Download Monitoring Solution

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FOfirGavish%2FSharePoint-Download-Report-Automation%2Fmain%2Fdeployment%2Fazuredeploy.json)

A comprehensive SharePoint download monitoring solution with interactive dashboards and automated reporting.

## 🚀 Quick Start

Choose your implementation path:

### Option 1: Azure Storage + Interactive Dashboard (Recommended)
- Modern web dashboard with real-time charts
- Azure Storage static website hosting
- JSON data format for better performance
- Mobile-responsive design
- **Secure CORS configuration** - Data accessible only from your dashboard URL

### Option 2: SharePoint Upload + Excel Reports (Traditional)
- Familiar Excel reports uploaded to SharePoint
- Compatible with existing SharePoint workflows
- Requires Sites.Selected permissions

## 📁 Repository Structure

```
├── scripts/                    # PowerShell automation scripts
│   ├── azure-storage/         # Scripts for Option 1
│   └── sharepoint-upload/     # Scripts for Option 2
├── dashboard/                 # Interactive web dashboard
│   ├── index.html            # Main dashboard page
│   ├── dashboard.css         # Styling
│   └── dashboard.js          # Functionality
├── deployment/               # Azure deployment templates
│   ├── azuredeploy.json     # Main ARM template
│   └── azuredeploy.parameters.json
└── docs/                    # Documentation
    ├── setup-guide.md       # Detailed setup instructions
    └── troubleshooting.md   # Common issues and solutions
```

## 🛠️ Quick Deployment

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FOfirGavish%2FSharePoint-Download-Report-Automation%2Fmain%2Fdeployment%2Fazuredeploy.json)

**Fully Automated Deployment:**
1. ✅ Click "Deploy to Azure" button above
2. ✅ Enter storage account name and select resource group
3. ✅ Wait for deployment (dashboard files are automatically uploaded!)
4. ✅ Access your ready-to-use dashboard at the provided URL
5. ✅ Configure PowerShell scripts with the deployment outputs

**That's it!** No manual file uploads or post-deployment scripts needed.

> 📋 **Complete Setup Guide**: See [POST-DEPLOYMENT-SETUP.md](deployment/POST-DEPLOYMENT-SETUP.md) for detailed instructions.

> 💰 **Cost Optimized**: CDN is disabled by default to minimize costs for internal use. Enable it in the template parameters only if you need global content delivery.

## 📋 Prerequisites

- Azure subscription
- SharePoint Online admin access
- PowerShell 7.2+
- Microsoft 365 Global Admin or Security Admin rights

## 🔧 Features

- **Real-time Monitoring**: Track SharePoint downloads as they happen
- **Interactive Dashboard**: Modern web interface with charts and filtering
- **Dual Implementation**: Choose between Azure Storage or SharePoint upload
- **Mobile-Friendly**: Responsive design works on all devices
- **Secure Authentication**: Certificate-based authentication
- **One-Click Deployment**: ARM templates for instant setup

## 📖 Documentation

- [Detailed Setup Guide](docs/setup-guide.md)
- [Troubleshooting Guide](docs/troubleshooting.md)
- [API Reference](docs/api-reference.md)

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

If you encounter issues:
1. Check the [troubleshooting guide](docs/troubleshooting.md)
2. Search existing [GitHub issues](https://github.com/YOUR-USERNAME/sharepoint-download-monitoring/issues)
3. Create a new issue with detailed information

## Authors

- **Ofir Gavish** - Initial work
- **Eitan Talmi** - Collaboration

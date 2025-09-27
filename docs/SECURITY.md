# Security Configuration

## CORS (Cross-Origin Resource Sharing) Security

The ARM template automatically configures CORS security to restrict data access to only the official dashboard URL. This prevents unauthorized external websites from accessing your SharePoint download monitoring data.

### Security Implementation

**Before (Less Secure):**
```json
"allowedOrigins": ["*"]  // Anyone could access the data
```

**After (Secure):**
```json
"allowedOrigins": ["https://yourstorageaccount.z6.web.core.windows.net"]  // Only your dashboard
```

### How It Works

1. **Automatic Configuration**: The deployment script automatically detects your static website URL
2. **CORS Restriction**: Only requests from your specific dashboard URL are allowed
3. **Method Limitation**: Only `GET`, `HEAD`, and `OPTIONS` methods are permitted (no write access)
4. **Header Control**: Only necessary headers are exposed, reducing attack surface

### Benefits

- **Data Protection**: SharePoint download logs can only be accessed through your official dashboard
- **No External Access**: External websites cannot steal or misuse your monitoring data
- **Compliance Ready**: Helps meet security requirements for internal monitoring systems
- **Zero Configuration**: Automatically configured during deployment

### Technical Details

The deployment script:
1. Retrieves the actual static website endpoint URL
2. Clears any existing CORS rules
3. Adds a new CORS rule specific to your website
4. Restricts HTTP methods to read-only operations
5. Limits exposed headers to only what's necessary

### Verification

You can verify the CORS configuration in the Azure Portal:
1. Navigate to your Storage Account
2. Go to **Data management** > **CORS**
3. Verify that only your static website URL is listed in **Allowed origins**

This security enhancement ensures that your SharePoint download monitoring data remains private and accessible only through your authorized dashboard.
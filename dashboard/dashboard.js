// SharePoint Download Monitoring Dashboard JavaScript
// Version 2.0 - Modern Azure Storage Integration

class SharePointDashboard {
    constructor() {
        this.data = null;
        this.filteredData = null;
        this.charts = {};
        this.currentPage = 1;
        this.pageSize = 25;
        this.sortColumn = 'timestamp';
        this.sortDirection = 'desc';
        this.config = this.loadConfig();
        
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.loadData();
        this.setupTheme();
    }

    setupEventListeners() {
        // Refresh button
        document.getElementById('refreshBtn').addEventListener('click', () => {
            this.loadData();
        });

        // Export button
        document.getElementById('exportBtn').addEventListener('click', () => {
            this.exportData();
        });

        // Theme toggle
        document.getElementById('themeToggle').addEventListener('click', () => {
            this.toggleTheme();
        });

        // Filters
        document.getElementById('dateRange').addEventListener('change', () => {
            this.applyFilters();
        });

        document.getElementById('userFilter').addEventListener('change', () => {
            this.applyFilters();
        });

        document.getElementById('siteFilter').addEventListener('change', () => {
            this.applyFilters();
        });

        document.getElementById('fileTypeFilter').addEventListener('change', () => {
            this.applyFilters();
        });

        document.getElementById('clearFilters').addEventListener('click', () => {
            this.clearFilters();
        });

        // Search and pagination
        document.getElementById('searchInput').addEventListener('input', () => {
            this.applyFilters();
        });

        document.getElementById('pageSize').addEventListener('change', (e) => {
            this.pageSize = parseInt(e.target.value);
            this.currentPage = 1;
            this.updateTable();
        });

        document.getElementById('prevPage').addEventListener('click', () => {
            if (this.currentPage > 1) {
                this.currentPage--;
                this.updateTable();
            }
        });

        document.getElementById('nextPage').addEventListener('click', () => {
            const totalPages = Math.ceil(this.filteredData.length / this.pageSize);
            if (this.currentPage < totalPages) {
                this.currentPage++;
                this.updateTable();
            }
        });

        // Table sorting
        document.querySelectorAll('th[data-sort]').forEach(th => {
            th.addEventListener('click', () => {
                const column = th.dataset.sort;
                if (this.sortColumn === column) {
                    this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
                } else {
                    this.sortColumn = column;
                    this.sortDirection = 'desc';
                }
                this.updateTable();
            });
        });

        // Configuration modal (for future use)
        if (document.getElementById('configModal')) {
            document.getElementById('saveConfig').addEventListener('click', () => {
                this.saveConfig();
            });
        }
    }

    loadConfig() {
        const defaultConfig = {
            storageAccountName: 'your-storage-account',
            containerName: 'data',
            fileName: 'sharepoint-downloads-latest.json'
        };

        const savedConfig = localStorage.getItem('dashboardConfig');
        return savedConfig ? JSON.parse(savedConfig) : defaultConfig;
    }

    saveConfig() {
        const config = {
            storageAccountName: document.getElementById('storageAccountName').value,
            containerName: document.getElementById('containerName').value,
            fileName: document.getElementById('fileName').value
        };

        localStorage.setItem('dashboardConfig', JSON.stringify(config));
        this.config = config;
        document.getElementById('configModal').style.display = 'none';
        this.loadData();
    }

    async loadData() {
        this.showLoading(true);

        try {
            // Construct data URL
            const dataUrl = `https://${this.config.storageAccountName}.blob.core.windows.net/${this.config.containerName}/${this.config.fileName}`;
            
            const response = await fetch(dataUrl);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            this.data = await response.json();
            this.filteredData = [...this.data.downloads];
            
            this.updateSummaryCards();
            this.populateFilters();
            this.createCharts();
            this.updateTable();
            this.updateLastUpdated();

            console.log('✅ Data loaded successfully:', this.data.metadata);
        } catch (error) {
            console.error('❌ Error loading data:', error);
            this.showError('Failed to load data. Please check your configuration and network connection.');
        } finally {
            this.showLoading(false);
        }
    }

    showLoading(show) {
        const overlay = document.getElementById('loadingOverlay');
        overlay.style.display = show ? 'flex' : 'none';
    }

    showError(message) {
        // Create or update error message
        let errorDiv = document.getElementById('errorMessage');
        if (!errorDiv) {
            errorDiv = document.createElement('div');
            errorDiv.id = 'errorMessage';
            errorDiv.style.cssText = `
                position: fixed;
                top: 20px;
                right: 20px;
                background: #dc3545;
                color: white;
                padding: 1rem;
                border-radius: 8px;
                box-shadow: 0 4px 8px rgba(0,0,0,0.2);
                z-index: 1001;
                max-width: 400px;
            `;
            document.body.appendChild(errorDiv);
        }

        errorDiv.innerHTML = `
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <i class="fas fa-exclamation-triangle"></i> ${message}
                </div>
                <button onclick="this.parentElement.parentElement.remove()" style="background: none; border: none; color: white; font-size: 1.2rem; cursor: pointer;">&times;</button>
            </div>
        `;

        // Auto-hide after 10 seconds
        setTimeout(() => {
            if (errorDiv.parentElement) {
                errorDiv.remove();
            }
        }, 10000);
    }

    updateSummaryCards() {
        if (!this.data || !this.data.metadata) return;

        const metadata = this.data.metadata;
        document.getElementById('totalDownloads').textContent = metadata.TotalDownloads || 0;
        document.getElementById('uniqueUsers').textContent = metadata.UniqueUsers || 0;
        document.getElementById('uniqueSites').textContent = metadata.UniqueSites || 0;
        document.getElementById('uniqueFiles').textContent = metadata.UniqueFiles || 0;
    }

    populateFilters() {
        if (!this.data || !this.data.downloads) return;

        const downloads = this.data.downloads;

        // Populate user filter
        const users = [...new Set(downloads.map(d => d.User))].sort();
        const userFilter = document.getElementById('userFilter');
        userFilter.innerHTML = '<option value="">All Users</option>';
        users.forEach(user => {
            userFilter.innerHTML += `<option value="${user}">${user}</option>`;
        });

        // Populate site filter
        const sites = [...new Set(downloads.map(d => d.SiteName))].filter(s => s).sort();
        const siteFilter = document.getElementById('siteFilter');
        siteFilter.innerHTML = '<option value="">All Sites</option>';
        sites.forEach(site => {
            siteFilter.innerHTML += `<option value="${site}">${site}</option>`;
        });

        // Populate file type filter
        const fileTypes = [...new Set(downloads.map(d => d.FileExtension))].filter(ft => ft).sort();
        const fileTypeFilter = document.getElementById('fileTypeFilter');
        fileTypeFilter.innerHTML = '<option value="">All Types</option>';
        fileTypes.forEach(type => {
            fileTypeFilter.innerHTML += `<option value="${type}">${type.toUpperCase()}</option>`;
        });
    }

    applyFilters() {
        if (!this.data || !this.data.downloads) return;

        let filtered = [...this.data.downloads];

        // Date range filter
        const dateRange = document.getElementById('dateRange').value;
        if (dateRange !== 'all') {
            const now = new Date();
            let startDate;

            switch (dateRange) {
                case 'today':
                    startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
                    break;
                case 'week':
                    startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
                    break;
                case 'month':
                    startDate = new Date(now.getFullYear(), now.getMonth(), 1);
                    break;
            }

            filtered = filtered.filter(d => new Date(d.Timestamp) >= startDate);
        }

        // User filter
        const userFilter = document.getElementById('userFilter').value;
        if (userFilter) {
            filtered = filtered.filter(d => d.User === userFilter);
        }

        // Site filter
        const siteFilter = document.getElementById('siteFilter').value;
        if (siteFilter) {
            filtered = filtered.filter(d => d.SiteName === siteFilter);
        }

        // File type filter
        const fileTypeFilter = document.getElementById('fileTypeFilter').value;
        if (fileTypeFilter) {
            filtered = filtered.filter(d => d.FileExtension === fileTypeFilter);
        }

        // Search filter
        const searchTerm = document.getElementById('searchInput').value.toLowerCase();
        if (searchTerm) {
            filtered = filtered.filter(d => 
                d.User.toLowerCase().includes(searchTerm) ||
                d.FileName.toLowerCase().includes(searchTerm) ||
                d.SiteName.toLowerCase().includes(searchTerm)
            );
        }

        this.filteredData = filtered;
        this.currentPage = 1;
        this.updateTable();
        this.updateCharts();
    }

    clearFilters() {
        document.getElementById('dateRange').value = 'all';
        document.getElementById('userFilter').value = '';
        document.getElementById('siteFilter').value = '';
        document.getElementById('fileTypeFilter').value = '';
        document.getElementById('searchInput').value = '';
        
        this.applyFilters();
    }

    createCharts() {
        if (!this.data || !this.data.downloads) return;

        // Destroy existing charts
        Object.values(this.charts).forEach(chart => {
            if (chart) chart.destroy();
        });

        this.createDownloadsOverTimeChart();
        this.createFileTypesChart();
        this.createUsersChart();
        this.createSitesChart();
    }

    createDownloadsOverTimeChart() {
        const ctx = document.getElementById('downloadsChart').getContext('2d');
        
        // Group downloads by date
        const downloadsByDate = {};
        this.filteredData.forEach(download => {
            const date = new Date(download.Timestamp).toISOString().split('T')[0];
            downloadsByDate[date] = (downloadsByDate[date] || 0) + 1;
        });

        const dates = Object.keys(downloadsByDate).sort();
        const counts = dates.map(date => downloadsByDate[date]);

        this.charts.downloads = new Chart(ctx, {
            type: 'line',
            data: {
                labels: dates,
                datasets: [{
                    label: 'Downloads',
                    data: counts,
                    borderColor: '#007BFF',
                    backgroundColor: 'rgba(0, 123, 255, 0.1)',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
    }

    createFileTypesChart() {
        const ctx = document.getElementById('fileTypesChart').getContext('2d');
        
        const fileTypes = {};
        this.filteredData.forEach(download => {
            const ext = download.FileExtension || 'unknown';
            fileTypes[ext] = (fileTypes[ext] || 0) + 1;
        });

        const sortedTypes = Object.entries(fileTypes)
            .sort(([,a], [,b]) => b - a)
            .slice(0, 10);

        this.charts.fileTypes = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: sortedTypes.map(([type]) => type.toUpperCase()),
                datasets: [{
                    data: sortedTypes.map(([,count]) => count),
                    backgroundColor: [
                        '#007BFF', '#28a745', '#ffc107', '#dc3545', '#17a2b8',
                        '#6f42c1', '#e83e8c', '#fd7e14', '#20c997', '#6c757d'
                    ]
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom'
                    }
                }
            }
        });
    }

    createUsersChart() {
        const ctx = document.getElementById('usersChart').getContext('2d');
        
        const users = {};
        this.filteredData.forEach(download => {
            users[download.User] = (users[download.User] || 0) + 1;
        });

        const sortedUsers = Object.entries(users)
            .sort(([,a], [,b]) => b - a)
            .slice(0, 10);

        this.charts.users = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: sortedUsers.map(([user]) => user.split('@')[0]),
                datasets: [{
                    label: 'Downloads',
                    data: sortedUsers.map(([,count]) => count),
                    backgroundColor: '#28a745'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
    }

    createSitesChart() {
        const ctx = document.getElementById('sitesChart').getContext('2d');
        
        const sites = {};
        this.filteredData.forEach(download => {
            const site = download.SiteName || 'Unknown';
            sites[site] = (sites[site] || 0) + 1;
        });

        const sortedSites = Object.entries(sites)
            .sort(([,a], [,b]) => b - a)
            .slice(0, 10);

        this.charts.sites = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: sortedSites.map(([site]) => site),
                datasets: [{
                    label: 'Downloads',
                    data: sortedSites.map(([,count]) => count),
                    backgroundColor: '#17a2b8'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
    }

    updateCharts() {
        this.createCharts();
    }

    updateTable() {
        if (!this.filteredData) return;

        // Sort data
        const sortedData = [...this.filteredData].sort((a, b) => {
            let aVal = a[this.sortColumn] || '';
            let bVal = b[this.sortColumn] || '';

            if (this.sortColumn === 'timestamp') {
                aVal = new Date(aVal);
                bVal = new Date(bVal);
            }

            if (this.sortDirection === 'asc') {
                return aVal > bVal ? 1 : -1;
            } else {
                return aVal < bVal ? 1 : -1;
            }
        });

        // Pagination
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = startIndex + this.pageSize;
        const pageData = sortedData.slice(startIndex, endIndex);

        // Update table body
        const tbody = document.getElementById('downloadsTableBody');
        tbody.innerHTML = '';

        pageData.forEach(download => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>${new Date(download.Timestamp).toLocaleString()}</td>
                <td>${download.User}</td>
                <td title="${download.FilePath}">${download.FileName}</td>
                <td><span class="badge">${download.FileExtension.toUpperCase()}</span></td>
                <td>${download.SiteName}</td>
                <td>${download.ClientIP}</td>
            `;
            tbody.appendChild(row);
        });

        // Update pagination
        const totalPages = Math.ceil(this.filteredData.length / this.pageSize);
        document.getElementById('pageInfo').textContent = `Page ${this.currentPage} of ${totalPages}`;
        document.getElementById('prevPage').disabled = this.currentPage === 1;
        document.getElementById('nextPage').disabled = this.currentPage === totalPages;

        // Update sort indicators
        document.querySelectorAll('th[data-sort] i').forEach(icon => {
            icon.className = 'fas fa-sort';
        });

        const currentSortHeader = document.querySelector(`th[data-sort="${this.sortColumn}"] i`);
        if (currentSortHeader) {
            currentSortHeader.className = `fas fa-sort-${this.sortDirection === 'asc' ? 'up' : 'down'}`;
        }
    }

    updateLastUpdated() {
        if (this.data && this.data.metadata && this.data.metadata.GeneratedAt) {
            const lastUpdated = new Date(this.data.metadata.GeneratedAt).toLocaleString();
            document.getElementById('lastUpdated').textContent = lastUpdated;
        }
    }

    exportData() {
        if (!this.filteredData) return;

        const csv = this.convertToCSV(this.filteredData);
        const blob = new Blob([csv], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `sharepoint-downloads-${new Date().toISOString().split('T')[0]}.csv`;
        link.click();
        window.URL.revokeObjectURL(url);
    }

    convertToCSV(data) {
        if (!data.length) return '';

        const headers = ['Timestamp', 'User', 'FileName', 'FileExtension', 'SiteName', 'ClientIP', 'FilePath'];
        const csvContent = [
            headers.join(','),
            ...data.map(row => headers.map(header => `"${row[header] || ''}"`).join(','))
        ].join('\n');

        return csvContent;
    }

    setupTheme() {
        const savedTheme = localStorage.getItem('dashboardTheme') || 'light';
        this.setTheme(savedTheme);
    }

    toggleTheme() {
        const currentTheme = document.documentElement.getAttribute('data-theme') || 'light';
        const newTheme = currentTheme === 'light' ? 'dark' : 'light';
        this.setTheme(newTheme);
    }

    setTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        localStorage.setItem('dashboardTheme', theme);
        
        const themeIcon = document.querySelector('#themeToggle i');
        themeIcon.className = theme === 'light' ? 'fas fa-moon' : 'fas fa-sun';

        // Update charts if they exist
        if (Object.keys(this.charts).length > 0) {
            setTimeout(() => this.createCharts(), 100);
        }
    }
}

// Initialize dashboard when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.dashboard = new SharePointDashboard();
});

// Add some CSS for badges
const style = document.createElement('style');
style.textContent = `
    .badge {
        display: inline-block;
        padding: 0.25em 0.5em;
        font-size: 0.75em;
        font-weight: 600;
        line-height: 1;
        text-align: center;
        white-space: nowrap;
        vertical-align: baseline;
        border-radius: 0.375rem;
        background-color: var(--primary-color);
        color: white;
    }
`;
document.head.appendChild(style);
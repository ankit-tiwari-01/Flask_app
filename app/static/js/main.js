document.addEventListener('DOMContentLoaded', () => {
    // 1. Tab Switching Logic for AWS Deployment Guides
    const tabButtons = document.querySelectorAll('.tab-btn');
    const tabPanes = document.querySelectorAll('.tab-pane');

    tabButtons.forEach(button => {
        button.addEventListener('click', () => {
            const targetTab = button.getAttribute('data-tab');

            // Remove active classes
            tabButtons.forEach(btn => btn.classList.remove('active'));
            tabPanes.forEach(pane => pane.classList.remove('active'));

            // Add active class to selected tab and pane
            button.classList.add('active');
            const activePane = document.getElementById(`tab-${targetTab}`);
            if (activePane) {
                activePane.classList.add('active');
            }
        });
    });

    // 2. Clipboard Copy Logic
    const copyButtons = document.querySelectorAll('.copy-btn');
    copyButtons.forEach(button => {
        button.addEventListener('click', async () => {
            const targetId = button.getAttribute('data-copy');
            const codeElement = document.getElementById(targetId);

            if (codeElement) {
                const textToCopy = codeElement.textContent;
                try {
                    await navigator.clipboard.writeText(textToCopy);
                    
                    // Show success state
                    button.classList.add('copied');
                    const originalHTML = button.innerHTML;
                    button.innerHTML = '<i class="fa-solid fa-check"></i>';
                    
                    setTimeout(() => {
                        button.classList.remove('copied');
                        button.innerHTML = originalHTML;
                    }, 2000);
                } catch (err) {
                    console.error('Failed to copy text: ', err);
                }
            }
        });
    });

    // 3. Live API Tester Logic
    const btnHealth = document.getElementById('btn-test-health');
    const btnStatus = document.getElementById('btn-test-status');
    const resStatus = document.getElementById('res-status');
    const resTime = document.getElementById('res-time');
    const responseContent = document.getElementById('response-content');

    const testAPI = async (endpoint) => {
        // Reset display state
        resStatus.textContent = 'Fetching...';
        resStatus.className = 'response-status loading';
        resTime.textContent = '-- ms';
        responseContent.textContent = 'Sending HTTP GET request...';

        const startTime = performance.now();

        try {
            const response = await fetch(endpoint);
            const duration = Math.round(performance.now() - startTime);
            const data = await response.json();

            // Render success
            resStatus.textContent = `HTTP ${response.status}`;
            resStatus.className = `response-status ${response.ok ? 'healthy' : 'error'}`;
            resTime.textContent = `${duration} ms`;
            responseContent.textContent = JSON.stringify(data, null, 4);
        } catch (error) {
            const duration = Math.round(performance.now() - startTime);
            // Render failure
            resStatus.textContent = 'FAILED';
            resStatus.className = 'response-status error';
            resTime.textContent = `${duration} ms`;
            responseContent.textContent = `Network Error: Could not connect to API.\nDetail: ${error.message}`;
        }
    };

    if (btnHealth) {
        btnHealth.addEventListener('click', () => testAPI('/health'));
    }
    if (btnStatus) {
        btnStatus.addEventListener('click', () => testAPI('/api/status'));
    }

    // 4. Server Clock Tick (Local simulation offset update)
    const utcTimeElement = document.getElementById('utc-time');
    if (utcTimeElement) {
        setInterval(() => {
            const now = new Date();
            const year = now.getUTCFullYear();
            const month = String(now.getUTCMonth() + 1).padStart(2, '0');
            const day = String(now.getUTCDate()).padStart(2, '0');
            const hours = String(now.getUTCHours()).padStart(2, '0');
            const minutes = String(now.getUTCMinutes()).padStart(2, '0');
            const seconds = String(now.getUTCSeconds()).padStart(2, '0');
            
            utcTimeElement.textContent = `${year}-${month}-${day} ${hours}:${minutes}:${seconds} UTC`;
        }, 1000);
    }
});

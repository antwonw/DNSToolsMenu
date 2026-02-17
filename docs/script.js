document.addEventListener('DOMContentLoaded', () => {
    // 1. Clock Logic
    function updateClock() {
        const now = new Date();
        const options = { weekday: 'short', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' };
        document.getElementById('clock').textContent = now.toLocaleDateString('en-US', options).replace(',', '');
    }
    setInterval(updateClock, 1000);
    updateClock();

    // 2. Typewriter & Results Animation
    const typeWriterElement = document.getElementById('typewriter');
    const resultsElement = document.getElementById('results-area');
    const textToType = "google.com";
    
    async function runDemoLoop() {
        while(true) {
            typeWriterElement.textContent = "";
            resultsElement.innerHTML = "";
            await wait(1500);
            for (let char of textToType) {
                typeWriterElement.textContent += char;
                await wait(100 + Math.random() * 50);
            }
            await wait(400);
            const resultHTML = `
                <div class="result-line">;; ANSWER SECTION:</div>
                <div class="result-line">google.com. 192 IN A 142.250.191.206</div>
                <div class="result-line">google.com. 192 IN AAAA 2607:f8b0:4009:813::200e</div>
                <div class="result-line" style="color:#34c759">;; Query time: 14 msec</div>
            `;
            resultsElement.innerHTML = resultHTML;
            await wait(5000);
            await wait(1000);
        }
    }
    
    function wait(ms) { return new Promise(r => setTimeout(r, ms)); }
    runDemoLoop();

    // 3. Dark Mode Logic
    const toggleBtn = document.getElementById('theme-toggle');
    const html = document.documentElement;
    const images = document.querySelectorAll('.theme-img');
    
    if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
        setTheme('dark');
    }

    toggleBtn.addEventListener('click', () => {
        const currentTheme = html.getAttribute('data-theme');
        const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
        setTheme(newTheme);
    });

    function setTheme(theme) {
        html.setAttribute('data-theme', theme);
        images.forEach(img => {
            const src = img.getAttribute('src');
            if (theme === 'dark') {
                if (src.includes('-light')) {
                    img.setAttribute('src', src.replace('-light', '-dark'));
                }
            } else {
                if (src.includes('-dark')) {
                    img.setAttribute('src', src.replace('-dark', '-light'));
                }
            }
        });
    }

    // 4. Copy to Clipboard Logic
    const copyBtn = document.querySelector('.copy-btn');
    const installCmd = document.getElementById('install-cmd');
    const copyTooltip = document.querySelector('.copy-tooltip');

    copyBtn.addEventListener('click', () => {
        navigator.clipboard.writeText(installCmd.textContent).then(() => {
            copyTooltip.classList.add('show');
            setTimeout(() => {
                copyTooltip.classList.remove('show');
            }, 2000);
        });
    });
});

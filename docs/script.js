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
            // Reset
            typeWriterElement.textContent = "";
            resultsElement.innerHTML = "";
            
            // Wait for dropdown to "open" (based on CSS animation delay ~15%)
            await wait(1500);
            
            // Type
            for (let char of textToType) {
                typeWriterElement.textContent += char;
                await wait(100 + Math.random() * 50);
            }
            
            // Wait briefly then show results
            await wait(400);
            
            // Inject Results
            const resultHTML = `
                <div class="result-line">;; ANSWER SECTION:</div>
                <div class="result-line">google.com. 192 IN A 142.250.191.206</div>
                <div class="result-line">google.com. 192 IN AAAA 2607:f8b0:4009:813::200e</div>
                <div class="result-line" style="color:#34c759">;; Query time: 14 msec</div>
            `;
            resultsElement.innerHTML = resultHTML;
            
            // Wait for dropdown to "close" (based on CSS animation ~90%)
            await wait(5000);
            
            // Wait for loop restart
            await wait(1000);
        }
    }
    
    function wait(ms) { return new Promise(r => setTimeout(r, ms)); }
    runDemoLoop();

    // 3. Dark Mode Logic
        const toggleBtn = document.getElementById('theme-toggle');
        const html = document.documentElement;
        const images = document.querySelectorAll('.theme-img');
        
        // Check system preference on load
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
            
            // Swap Images (finds '-light' and replaces with '-dark', or vice versa)
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
    });

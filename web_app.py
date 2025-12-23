#!/usr/bin/env python3
"""
Web App for Desk Controller - New Compact Design
"""

from flask import Flask, render_template_string

app = Flask(__name__)

# ESP32 configuration - will be loaded from localStorage in the frontend
# This is just a default fallback
ESP32_IP_DEFAULT = "http://192.168.4.1"  # Default to AP mode IP

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Desk Controller</title>
    <style>
        :root {
            --bg-color: #1a1a1a;
            --card-bg: #262626;
            --text-dim: #888888;
            --accent-blue: #3b82f6;
            --up-green: #4ade80;
            --stop-red: #f87171;
        }

        body {
            background-color: #111;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            font-family: -apple-system, sans-serif;
        }

        .app-window {
            width: 380px;
            background-color: var(--bg-color);
            border-radius: 24px;
            box-shadow: 0 20px 50px rgba(0,0,0,0.5);
            padding: 25px;
            color: white;
        }

        .header { text-align: center; margin-bottom: 25px; }
        .height-label { color: var(--text-dim); font-size: 14px; }
        .height-value { color: var(--accent-blue); font-size: 48px; font-weight: bold; margin: 5px 0; }
        .status { font-size: 12px; color: var(--up-green); transition: color 0.3s; }

        .card {
            background-color: var(--card-bg);
            border-radius: 16px;
            padding: 18px;
            margin-bottom: 15px;
        }

        .section-title { font-size: 12px; font-weight: bold; color: var(--text-dim); text-transform: uppercase; margin-bottom: 12px; display: block; }

        button {
            border: none; border-radius: 10px; font-weight: bold; cursor: pointer;
            transition: transform 0.1s, opacity 0.2s; font-size: 16px;
        }
        button:active { transform: scale(0.96); opacity: 0.8; }

        .main-controls { display: flex; flex-direction: column; gap: 10px; }
        .btn-up { background: var(--up-green); color: #1a1a1a; height: 50px; }
        .btn-down { background: var(--accent-blue); color: white; height: 50px; }
        .btn-stop { background: var(--stop-red); color: white; height: 50px; }

        .preset-grid { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 8px; }
        .preset-btn { background: #3f3f3f; color: white; height: 40px; font-size: 13px; }

        .settings-btn { width: 100%; background: #333; color: var(--text-dim); height: 45px; margin-top: 10px; }

        /* Modal Styling */
        .modal {
            display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0,0,0,0.8); z-index: 100; justify-content: center; align-items: center;
        }
        .modal.active { display: flex; }
        .modal-content {
            background: var(--bg-color); width: 90%; max-width: 400px; 
            border-radius: 20px; padding: 25px; max-height: 85vh; overflow-y: auto;
        }
        
        .preset-manager-row { display: flex; gap: 8px; margin-bottom: 8px; }
        .preset-manager-row input { 
            background: #111; border: 1px solid #444; color: white; 
            padding: 8px; border-radius: 6px; font-size: 14px;
        }
        .btn-delete { background: #422; color: #f87171; padding: 0 12px; }
        
        input[type="number"], input[type="text"] { width: 100%; box-sizing: border-box; }
        .save-btn { background: var(--accent-blue); color: white; width: 100%; height: 50px; margin-top: 20px; }
    </style>
</head>
<body>

<div class="app-window">
    <div class="header">
        <div class="height-label">Current Height</div>
        <div class="height-value" id="height">---</div>
        <div class="status" id="status">Connecting...</div>
    </div>

    <div class="card main-controls">
        <button class="btn-up" onmousedown="startMove('up')" onmouseup="stopMove()" ontouchstart="startMove('up')" ontouchend="stopMove()">▲ UP</button>
        <button class="btn-down" onmousedown="startMove('down')" onmouseup="stopMove()" ontouchstart="startMove('down')" ontouchend="stopMove()">▼ DOWN</button>
        <button class="btn-stop" onclick="sendCommand('stop')">STOP</button>
    </div>

    <div class="card">
        <span class="section-title">Quick Presets</span>
        <div class="preset-grid" id="main-preset-grid">
            </div>
    </div>

    <button class="settings-btn" onclick="toggleModal(true)">⚙ Settings</button>
</div>

<div class="modal" id="settings-modal">
    <div class="modal-content">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:20px;">
            <h2 style="margin:0; color:var(--text-dim);">Settings</h2>
            <button onclick="toggleModal(false)" style="background:none; color:white; font-size:24px; border:none; cursor:pointer; padding:0; width:30px; height:30px; display:flex; align-items:center; justify-content:center;">×</button>
        </div>

        <div class="card">
            <span class="section-title">Manual Movement</span>
            <div style="display:flex; gap:8px; align-items:flex-end;">
                <div style="flex:1;">
                    <label style="font-size:11px; color:var(--text-dim); display:block; margin-bottom:4px;">Target Height (mm)</label>
                    <input type="number" id="manual-height-input" placeholder="Height (mm)" oninput="validateManualHeight()" style="background:#111; border:1px solid #444; color:white; padding:8px; border-radius:6px; width:100%; box-sizing:border-box;">
                </div>
                <button onclick="moveToHeight()" style="background:var(--accent-blue); color:white; padding:8px 16px; border-radius:6px; height:36px; white-space:nowrap;">Move</button>
            </div>
            <div style="font-size:11px; color:var(--text-dim); margin-top:8px;" id="manual-limits-info">Min: 575mm | Max: 1185mm</div>
        </div>

        <div class="card">
            <span class="section-title">Manage Presets</span>
            <div id="preset-manager-list"></div>
            <button onclick="addPresetRow()" style="width:100%; background:none; border:1px dashed #555; color:var(--accent-blue); padding:10px; margin-top:10px;">+ Add Preset</button>
        </div>

        <div class="card">
            <span class="section-title">Safety Limits</span>
            <div style="display:grid; grid-template-columns:1fr 1fr; gap:10px;">
                <div>
                    <label style="font-size:11px; color:var(--text-dim)">Min (mm)</label>
                    <input type="number" id="min-limit" value="575" oninput="updateManualLimits(); validatePresets();" style="background:#111; border:1px solid #444; color:white; padding:8px; border-radius:6px; width:100%; box-sizing:border-box;">
                </div>
                <div>
                    <label style="font-size:11px; color:var(--text-dim)">Max (mm)</label>
                    <input type="number" id="max-limit" value="1185" oninput="updateManualLimits(); validatePresets();" style="background:#111; border:1px solid #444; color:white; padding:8px; border-radius:6px; width:100%; box-sizing:border-box;">
                </div>
            </div>
        </div>

        <div class="card">
            <span class="section-title">ESP32 Connection</span>
            <div style="margin-bottom:10px;">
                <label style="font-size:11px; color:var(--text-dim); display:block; margin-bottom:4px;">ESP32 IP Address</label>
                <input type="text" id="esp32-ip-input" value="" placeholder="http://192.168.1.100" style="background:#111; border:1px solid #444; color:white; padding:8px; border-radius:6px; width:100%; box-sizing:border-box;">
            </div>
            <div style="display:flex; gap:8px;">
                <button onclick="testConnection()" style="flex:1; background:#333; color:white; padding:8px; border-radius:6px; height:36px;">Test Connection</button>
                <button onclick="saveESP32IP()" style="flex:1; background:var(--accent-blue); color:white; padding:8px; border-radius:6px; height:36px;">Save IP</button>
            </div>
            <div style="font-size:11px; color:var(--text-dim); margin-top:8px;" id="connection-status">Status: Checking...</div>
            <div style="margin-top:10px;">
                <button onclick="resetESP32WiFi()" style="width:100%; background:#422; color:#f87171; padding:8px; border-radius:6px; height:36px; font-size:12px;">Reset WiFi (Restart Setup Mode)</button>
            </div>
        </div>

        <button class="save-btn" onclick="saveSettingsWithValidation()">Save All Changes</button>
    </div>
</div>

<script>
    // Version: 3.0 - WiFi Manager with connection detection
    console.log('[OK] Desk Controller JavaScript v3.0 loaded at', new Date().toISOString());
    
    // Load ESP32 IP from localStorage or use default
    let ESP32_IP = localStorage.getItem('esp32_ip') || '{{ esp32_ip }}';
    let isConnected = false;
    let moveInterval = null;

    // Load presets from LocalStorage or Defaults
    let presets = JSON.parse(localStorage.getItem('deskPresets')) || [
        { name: 'Sit', height: 700 },
        { name: 'Stand', height: 1100 },
        { name: 'Focus', height: 850 }
    ];

    // Load ESP32 IP on startup
    function loadESP32IP() {
        const savedIP = localStorage.getItem('esp32_ip');
        if (savedIP) {
            ESP32_IP = savedIP;
        }
        document.getElementById('esp32-ip-input').value = ESP32_IP;
        updateConnectionStatus();
    }

    // Test connection to ESP32
    async function testConnection() {
        const ipInput = document.getElementById('esp32-ip-input');
        const testIP = ipInput ? ipInput.value.trim() || ESP32_IP : ESP32_IP;
        const statusDiv = document.getElementById('connection-status');
        
        if (statusDiv) {
            statusDiv.textContent = 'Status: Testing connection...';
            statusDiv.style.color = 'var(--text-dim)';
        }
        
        try {
            const response = await fetch(`${testIP}/status`, {
                method: 'GET',
                mode: 'cors',
                cache: 'no-cache'
            });
            const text = await response.text();
            if (text.includes('ESP32 Desk Controller')) {
                if (statusDiv) {
                    statusDiv.textContent = 'Status: ✓ Connected';
                    statusDiv.style.color = '#4ade80';
                }
                ESP32_IP = testIP;
                localStorage.setItem('esp32_ip', ESP32_IP);
                isConnected = true;
                // Update main status
                document.getElementById('status').innerText = 'Connected';
                document.getElementById('status').style.color = '#4ade80';
                return true;
            } else {
                throw new Error('Invalid response');
            }
        } catch (error) {
            if (statusDiv) {
                statusDiv.textContent = 'Status: ✗ Disconnected';
                statusDiv.style.color = '#f87171';
            }
            isConnected = false;
            // Update main status
            document.getElementById('status').innerText = 'Disconnected';
            document.getElementById('status').style.color = '#f87171';
            return false;
        }
    }

    // Save ESP32 IP address
    function saveESP32IP() {
        const ipInput = document.getElementById('esp32-ip-input');
        const newIP = ipInput.value.trim();
        if (newIP) {
            ESP32_IP = newIP;
            localStorage.setItem('esp32_ip', ESP32_IP);
            testConnection();
            alert('IP address saved!');
        } else {
            alert('Please enter a valid IP address');
        }
    }

    // Reset ESP32 WiFi (clears credentials and restarts in AP mode)
    async function resetESP32WiFi() {
        if (!confirm('This will reset the ESP32 WiFi settings and restart it in setup mode. Continue?')) {
            return;
        }
        
        try {
            const response = await fetch(`${ESP32_IP}/resetwifi`, {
                method: 'GET',
                mode: 'cors',
                cache: 'no-cache'
            });
            const text = await response.text();
            alert('WiFi reset! ESP32 will restart in setup mode. Connect to "DeskController-Setup" network.');
            // Update IP to AP mode
            ESP32_IP = 'http://192.168.4.1';
            localStorage.setItem('esp32_ip', ESP32_IP);
            document.getElementById('esp32-ip-input').value = ESP32_IP;
        } catch (error) {
            alert('Error resetting WiFi. Make sure ESP32 is connected.');
        }
    }

    // Update connection status display
    function updateConnectionStatus() {
        const statusDiv = document.getElementById('connection-status');
        if (isConnected) {
            statusDiv.textContent = 'Status: ✓ Connected';
            statusDiv.style.color = '#4ade80';
        } else {
            statusDiv.textContent = 'Status: ✗ Disconnected';
            statusDiv.style.color = '#f87171';
        }
    }

    function toggleModal(show) {
        document.getElementById('settings-modal').classList.toggle('active', show);
        if(show) {
            loadESP32IP();
            renderPresetManager();
            loadLimits();
            updateManualLimits();
            // Small delay to ensure limits are loaded before validating
            setTimeout(() => {
                validatePresets();
                validateManualHeight();
            }, 100);
        }
    }

    function updateManualLimits() {
        const min = document.getElementById('min-limit').value || 575;
        const max = document.getElementById('max-limit').value || 1185;
        const input = document.getElementById('manual-height-input');
        input.min = min;
        input.max = max;
        const limitsInfo = document.getElementById('manual-limits-info');
        limitsInfo.textContent = `Min: ${min}mm | Max: ${max}mm`;
        
        // Check if current manual input value is outside limits
        validateManualHeight();
    }
    
    function validateManualHeight() {
        const input = document.getElementById('manual-height-input');
        const min = parseInt(document.getElementById('min-limit').value) || 575;
        const max = parseInt(document.getElementById('max-limit').value) || 1185;
        const value = parseInt(input.value);
        const limitsInfo = document.getElementById('manual-limits-info');
        
        if (input.value && (value < min || value > max)) {
            limitsInfo.innerHTML = `<span style="color: #f87171;">⚠️ Warning: Value ${value}mm is outside limits (${min}-${max}mm). Adjust limits or change value.</span>`;
            input.style.borderColor = '#f87171';
        } else {
            limitsInfo.textContent = `Min: ${min}mm | Max: ${max}mm`;
            input.style.borderColor = '#444';
        }
    }
    
    function validatePresets() {
        const min = parseInt(document.getElementById('min-limit').value) || 575;
        const max = parseInt(document.getElementById('max-limit').value) || 1185;
        const rows = document.querySelectorAll('.preset-manager-row');
        let hasWarnings = false;
        let warningText = '';
        
        rows.forEach((row, i) => {
            const heightInput = row.querySelector('.p-val');
            const heightValue = parseInt(heightInput.value);
            const nameInput = row.querySelector('.p-name');
            const presetName = nameInput.value || `Preset ${i+1}`;
            
            if (heightInput.value && (heightValue < min || heightValue > max)) {
                hasWarnings = true;
                heightInput.style.borderColor = '#f87171';
                warningText += `${presetName} (${heightValue}mm) is outside limits (${min}-${max}mm).<br>`;
            } else {
                heightInput.style.borderColor = '#444';
            }
        });
        
        // Show/hide warning message
        let warningDiv = document.getElementById('preset-warning');
        if (hasWarnings) {
            if (!warningDiv) {
                warningDiv = document.createElement('div');
                warningDiv.id = 'preset-warning';
                warningDiv.style.cssText = 'background: #422; border: 1px solid #f87171; border-radius: 6px; padding: 10px; margin-top: 10px; font-size: 11px; color: #f87171;';
                const presetSection = document.querySelector('.card:has(#preset-manager-list)');
                const presetList = document.getElementById('preset-manager-list');
                presetSection.insertBefore(warningDiv, presetList.nextSibling);
            }
            warningDiv.innerHTML = '<strong>⚠️ Warning:</strong> Some presets are outside height limits:<br>' + warningText + 
                'Either adjust the height limits or change the preset heights.';
        } else {
            if (warningDiv) {
                warningDiv.remove();
            }
        }
    }

    function moveToHeight() {
        const height = parseInt(document.getElementById('manual-height-input').value);
        const min = parseInt(document.getElementById('manual-height-input').min) || 575;
        const max = parseInt(document.getElementById('manual-height-input').max) || 1185;
        
        if (!height) {
            alert('Please enter a height value');
            return;
        }
        
        if (height < min || height > max) {
            alert(`Height ${height}mm is outside the configured limits (${min}-${max}mm).\n\nPlease either:\n- Adjust the height limits in Settings\n- Enter a height within the current limits`);
            return;
        }
        
        sendCommand('height' + height);
        document.getElementById('manual-height-input').value = '';
        validateManualHeight(); // Reset validation
    }

    function renderMainPresets() {
        const grid = document.getElementById('main-preset-grid');
        grid.innerHTML = presets.map((p, i) => 
            `<button class="preset-btn" onclick="sendCommand('goto${i}')">${p.name}</button>`
        ).join('');
    }

    function renderPresetManager() {
        const list = document.getElementById('preset-manager-list');
        list.innerHTML = presets.map((p, i) => `
            <div class="preset-manager-row">
                <input type="text" value="${p.name}" class="p-name" placeholder="Name" oninput="validatePresets()" style="flex:2">
                <input type="number" value="${p.height}" class="p-val" placeholder="mm" oninput="validatePresets()" style="flex:1">
                <button class="btn-delete" onclick="removePresetRow(this)">×</button>
            </div>
        `).join('');
        validatePresets(); // Validate after rendering
    }

    function addPresetRow() {
        const list = document.getElementById('preset-manager-list');
        const div = document.createElement('div');
        div.className = 'preset-manager-row';
        div.innerHTML = `
            <input type="text" placeholder="Name" class="p-name" oninput="validatePresets()" style="flex:2">
            <input type="number" placeholder="mm" class="p-val" oninput="validatePresets()" style="flex:1">
            <button class="btn-delete" onclick="removePresetRow(this)">×</button>
        `;
        list.appendChild(div);
    }

    function removePresetRow(btn) {
        const row = btn.parentElement;
        const index = Array.from(row.parentElement.children).indexOf(row);
        row.remove();
        // Update presets array
        presets.splice(index, 1);
        localStorage.setItem('deskPresets', JSON.stringify(presets));
        renderMainPresets();
        validatePresets(); // Re-validate after removal
    }

    function loadLimits() {
        fetch(`${ESP32_IP}/limits`, {
            method: 'GET',
            mode: 'cors',
            cache: 'no-cache'
        })
        .then(response => response.text())
        .then(text => {
            const minMatch = text.match(/Minimum: (\d+)/);
            const maxMatch = text.match(/Maximum: (\d+)/);
            if (minMatch && maxMatch) {
                document.getElementById('min-limit').value = minMatch[1];
                document.getElementById('max-limit').value = maxMatch[1];
                updateManualLimits();
                validatePresets(); // Validate presets after loading limits
            }
        })
        .catch(error => {
            console.error('Error loading limits:', error);
        });
    }

    // Validation wrapper to ensure it always runs
    async function saveSettingsWithValidation() {
        console.log('=== SAVE BUTTON CLICKED - VALIDATION v2.0 ===');
        await saveSettings();
    }
    
    async function saveSettings() {
        // Collect UI values
        const rows = document.querySelectorAll('.preset-manager-row');
        const newPresets = [];
        const minInput = document.getElementById('min-limit');
        const maxInput = document.getElementById('max-limit');
        const min = parseInt(minInput.value) || 575;
        const max = parseInt(maxInput.value) || 1185;
        
        console.log('SaveSettings called - Min:', min, 'Max:', max);
        
        rows.forEach((row, i) => {
            const nameInput = row.querySelector('.p-name');
            const heightInput = row.querySelector('.p-val');
            const name = nameInput ? nameInput.value.trim() : `Preset ${i+1}`;
            const val = heightInput ? heightInput.value.trim() : '';
            if (val) {
                const height = parseInt(val);
                if (!isNaN(height)) {
                    newPresets.push({ name, height: height });
                    console.log(`Preset ${i}: ${name} = ${height}mm`);
                }
            }
        });

        if (newPresets.length === 0) {
            alert('Please add at least one preset');
            return;
        }
        
        // VALIDATION v2.0: Check if any presets are outside limits
        console.log('=== STARTING VALIDATION ===');
        console.log('Checking', newPresets.length, 'presets against limits: Min:', min, 'Max:', max);
        
        const outOfRangePresets = [];
        newPresets.forEach((p, idx) => {
            const isTooLow = p.height < min;
            const isTooHigh = p.height > max;
            const isOutOfRange = isTooLow || isTooHigh;
            
            console.log(`Preset ${idx}: "${p.name}" = ${p.height}mm | Min:${min} | Max:${max} | TooLow:${isTooLow} | TooHigh:${isTooHigh} | OutOfRange:${isOutOfRange}`);
            
            if (isOutOfRange) {
                outOfRangePresets.push(p);
                console.warn('[WARNING] VALIDATION FAILED: "' + p.name + '" (' + p.height + 'mm) is OUTSIDE limits (' + min + '-' + max + 'mm)');
            }
        });
        
        console.log(`Validation result: ${outOfRangePresets.length} preset(s) out of range`);
        
        if (outOfRangePresets.length > 0) {
            console.error('[BLOCKED] BLOCKING SAVE - Invalid presets detected!');
            const presetList = outOfRangePresets.map(function(p) { return '  - ' + p.name + ': ' + p.height + 'mm'; }).join('\\n');
            alert(
                `[VALIDATION v2.0] Cannot save: The following presets are outside the height limits (${min}-${max}mm):\n\n${presetList}\n\n` +
                `Please either:\n` +
                `- Adjust the height limits to include these preset values\n` +
                `- Change the preset heights to be within the current limits (${min}-${max}mm)`
            );
            console.log('SAVE BLOCKED - presets outside limits:', outOfRangePresets);
            console.log('Min:', min, 'Max:', max, 'Out of range count:', outOfRangePresets.length);
            console.log('=== VALIDATION FAILED - RETURNING EARLY ===');
            return; // Block saving - This MUST prevent the code below from running
        }
        
        console.log('[OK] Validation passed - all presets within limits, proceeding with save');

        presets = newPresets;
        localStorage.setItem('deskPresets', JSON.stringify(presets));
        
        // Push heights to ESP32 (limit to 3 presets as ESP32 supports)
        const presetsToSave = presets.slice(0, 3);
        for(let i=0; i < presetsToSave.length; i++) {
            const command = `set${i} ${presetsToSave[i].height}`;
            try {
                await fetch(`${ESP32_IP}/${encodeURIComponent(command)}`, {
                    method: 'GET',
                    mode: 'cors',
                    cache: 'no-cache'
                });
            } catch (e) {
                console.error(`Error saving preset ${i}:`, e);
            }
        }

        // Push limits
        const minLimit = document.getElementById('min-limit').value;
        const maxLimit = document.getElementById('max-limit').value;
        try {
            await fetch(`${ESP32_IP}/setmin${minLimit}`, { method: 'GET', mode: 'cors', cache: 'no-cache' });
            await fetch(`${ESP32_IP}/setmax${maxLimit}`, { method: 'GET', mode: 'cors', cache: 'no-cache' });
        } catch (e) {
            console.error('Error saving limits:', e);
        }

        renderMainPresets();
        toggleModal(false);
        alert("Settings Saved to Desk!");
    }

    function sendCommand(cmd) {
        fetch(`${ESP32_IP}/${cmd}`, {
            method: 'GET',
            mode: 'cors',
            cache: 'no-cache'
        }).catch(e => console.log("ESP32 Offline"));
    }

    function startMove(dir) {
        sendCommand(dir);
        moveInterval = setInterval(() => sendCommand(dir), 200);
    }

    function stopMove() {
        clearInterval(moveInterval);
        sendCommand('stop');
    }

    function updateHeight() {
        fetch(`${ESP32_IP}/status`, {
            method: 'GET',
            mode: 'cors',
            cache: 'no-cache'
        })
            .then(r => r.text())
            .then(text => {
                const match = text.match(/Current Height: (\d+) mm/);
                if(match) {
                    document.getElementById('height').innerText = match[1] + ' mm';
                    document.getElementById('status').innerText = 'Connected';
                    document.getElementById('status').style.color = '#4ade80';
                    isConnected = true;
                    
                    // Hide setup page if shown
                    const setupPage = document.getElementById('setup-page');
                    if (setupPage) {
                        setupPage.style.display = 'none';
                    }
                    const mainApp = document.querySelector('.app-window');
                    if (mainApp) {
                        mainApp.style.display = 'block';
                    }
                } else {
                    throw new Error('Invalid response');
                }
            }).catch(() => {
                document.getElementById('status').innerText = 'Disconnected';
                document.getElementById('status').style.color = '#f87171';
                isConnected = false;
                
                // Show setup page if not connected
                showSetupPage();
            });
    }

    // Show setup page when not connected
    function showSetupPage() {
        let setupPage = document.getElementById('setup-page');
        if (!setupPage) {
            setupPage = document.createElement('div');
            setupPage.id = 'setup-page';
            setupPage.style.cssText = 'width:380px; background-color:var(--bg-color); border-radius:24px; box-shadow:0 20px 50px rgba(0,0,0,0.5); padding:25px; color:white;';
            setupPage.innerHTML = `
                <div style="text-align:center; margin-bottom:25px;">
                    <h2 style="color:var(--accent-blue); margin:0 0 10px 0;">Desk Controller Setup</h2>
                    <p style="color:var(--text-dim); font-size:14px;">ESP32 is not connected</p>
                </div>
                <div class="card" style="background:var(--card-bg); border-radius:16px; padding:18px; margin-bottom:15px;">
                    <span class="section-title">First Time Setup</span>
                    <ol style="text-align:left; font-size:13px; color:var(--text-dim); line-height:1.8; padding-left:20px;">
                        <li>Connect your phone/computer to WiFi network: <strong style="color:white;">DeskController-Setup</strong></li>
                        <li>Password: <strong style="color:white;">setup12345</strong></li>
                        <li>Open: <a href="http://192.168.4.1/setup" target="_blank" style="color:var(--accent-blue);">http://192.168.4.1/setup</a></li>
                        <li>Enter your WiFi credentials and connect</li>
                        <li>Return here and enter the ESP32 IP address below</li>
                    </ol>
                </div>
                <div class="card" style="background:var(--card-bg); border-radius:16px; padding:18px; margin-bottom:15px;">
                    <span class="section-title">ESP32 IP Address</span>
                    <input type="text" id="setup-ip-input" placeholder="http://192.168.1.100" style="background:#111; border:1px solid #444; color:white; padding:10px; border-radius:6px; width:100%; box-sizing:border-box; margin-bottom:10px;">
                    <button onclick="connectToESP32()" style="width:100%; background:var(--accent-blue); color:white; padding:12px; border-radius:6px; border:none; font-weight:bold; cursor:pointer;">Connect</button>
                </div>
            `;
            document.body.appendChild(setupPage);
        }
        setupPage.style.display = 'block';
        const mainApp = document.querySelector('.app-window');
        if (mainApp) {
            mainApp.style.display = 'none';
        }
    }

    // Connect to ESP32 from setup page
    async function connectToESP32() {
        const ipInput = document.getElementById('setup-ip-input');
        const newIP = ipInput.value.trim() || 'http://192.168.4.1';
        
        ESP32_IP = newIP;
        localStorage.setItem('esp32_ip', ESP32_IP);
        
        // Test connection
        const connected = await testConnection();
        if (connected) {
            const setupPage = document.getElementById('setup-page');
            if (setupPage) {
                setupPage.style.display = 'none';
            }
            const mainApp = document.querySelector('.app-window');
            if (mainApp) {
                mainApp.style.display = 'block';
            }
            updateHeight();
        } else {
            alert('Could not connect to ESP32. Please check the IP address and try again.');
        }
    }

    // Initialize on page load
    loadESP32IP();
    renderMainPresets();
    // Initial connection check - don't show setup page immediately
    updateHeight();
    setInterval(updateHeight, 2000);
</script>
</body>
</html>
"""

@app.route('/')
def index():
    return render_template_string(HTML_TEMPLATE, esp32_ip=ESP32_IP_DEFAULT)

if __name__ == '__main__':
    print(f"Starting Desk Controller Web App (New Compact Design)...")
    print(f"ESP32 IP: {ESP32_IP}")
    print(f"Open your browser to: http://localhost:5000")
    print(f"Press Ctrl+C to stop")
    app.run(host='0.0.0.0', port=5000, debug=False)

#!/usr/bin/env python3
"""
Web App for Desk Controller - New Compact Design
"""

from flask import Flask, render_template_string

app = Flask(__name__)

# ESP32 configuration
ESP32_IP = "http://192.168.0.194"

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
                    <input type="number" id="manual-height-input" placeholder="Height (mm)" style="background:#111; border:1px solid #444; color:white; padding:8px; border-radius:6px; width:100%; box-sizing:border-box;">
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
                    <input type="number" id="min-limit" value="575" style="background:#111; border:1px solid #444; color:white; padding:8px; border-radius:6px; width:100%; box-sizing:border-box;">
                </div>
                <div>
                    <label style="font-size:11px; color:var(--text-dim)">Max (mm)</label>
                    <input type="number" id="max-limit" value="1185" style="background:#111; border:1px solid #444; color:white; padding:8px; border-radius:6px; width:100%; box-sizing:border-box;">
                </div>
            </div>
        </div>

        <button class="save-btn" onclick="saveSettings()">Save All Changes</button>
    </div>
</div>

<script>
    const ESP32_IP = '{{ esp32_ip }}';
    let moveInterval = null;

    // Load presets from LocalStorage or Defaults
    let presets = JSON.parse(localStorage.getItem('deskPresets')) || [
        { name: 'Sit', height: 700 },
        { name: 'Stand', height: 1100 },
        { name: 'Focus', height: 850 }
    ];

    function toggleModal(show) {
        document.getElementById('settings-modal').classList.toggle('active', show);
        if(show) {
            renderPresetManager();
            loadLimits();
            updateManualLimits();
        }
    }

    function updateManualLimits() {
        const min = document.getElementById('min-limit').value || 575;
        const max = document.getElementById('max-limit').value || 1185;
        const input = document.getElementById('manual-height-input');
        input.min = min;
        input.max = max;
        document.getElementById('manual-limits-info').textContent = `Min: ${min}mm | Max: ${max}mm`;
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
            alert(`Height must be between ${min}mm and ${max}mm`);
            return;
        }
        
        sendCommand('height' + height);
        document.getElementById('manual-height-input').value = '';
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
                <input type="text" value="${p.name}" class="p-name" placeholder="Name" style="flex:2">
                <input type="number" value="${p.height}" class="p-val" placeholder="mm" style="flex:1">
                <button class="btn-delete" onclick="removePresetRow(this)">×</button>
            </div>
        `).join('');
    }

    function addPresetRow() {
        const list = document.getElementById('preset-manager-list');
        const div = document.createElement('div');
        div.className = 'preset-manager-row';
        div.innerHTML = `
            <input type="text" placeholder="Name" class="p-name" style="flex:2">
            <input type="number" placeholder="mm" class="p-val" style="flex:1">
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
            }
        })
        .catch(error => {
            console.error('Error loading limits:', error);
        });
    }

    async function saveSettings() {
        // Collect UI values
        const rows = document.querySelectorAll('.preset-manager-row');
        const newPresets = [];
        rows.forEach((row, i) => {
            const name = row.querySelector('.p-name').value || `Preset ${i+1}`;
            const val = row.querySelector('.p-val').value;
            if (val) {
                newPresets.push({ name, height: parseInt(val) });
            }
        });

        if (newPresets.length === 0) {
            alert('Please add at least one preset');
            return;
        }

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
        const min = document.getElementById('min-limit').value;
        const max = document.getElementById('max-limit').value;
        try {
            await fetch(`${ESP32_IP}/setmin${min}`, { method: 'GET', mode: 'cors', cache: 'no-cache' });
            await fetch(`${ESP32_IP}/setmax${max}`, { method: 'GET', mode: 'cors', cache: 'no-cache' });
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
                }
            }).catch(() => {
                document.getElementById('status').innerText = 'Disconnected';
                document.getElementById('status').style.color = '#f87171';
            });
    }

    setInterval(updateHeight, 2000);
    renderMainPresets();
    updateHeight();
</script>
</body>
</html>
"""

@app.route('/')
def index():
    return render_template_string(HTML_TEMPLATE, esp32_ip=ESP32_IP)

if __name__ == '__main__':
    print(f"Starting Desk Controller Web App (New Compact Design)...")
    print(f"ESP32 IP: {ESP32_IP}")
    print(f"Open your browser to: http://localhost:5000")
    print(f"Press Ctrl+C to stop")
    app.run(host='0.0.0.0', port=5000, debug=False)

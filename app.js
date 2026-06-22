// --- CONSTANTS AND STATE ---
let db = null;
const DB_NAME = 'AquaVoiceDB';
const DB_VERSION = 1;

const STATE = {
  dailyGoal: 2000,
  alarmsEnabled: false,
  alarmStart: '08:00',
  alarmEnd: '22:00',
  alarmInterval: 60,
  currentTab: 'home',
  todayLogs: [],
  voiceAlarmBlob: null,
  nextAlarmTime: null,
  streak: 0
};

// Audio recording variables
let mediaRecorder = null;
let audioChunks = [];
let audioContext = null;
let analyserNode = null;
let animationFrameId = null;
let recordingStream = null;

// Alarm playback variables
let alarmAudioElement = null;
let synthIntervalId = null;
let synthAudioCtx = null;

// --- INITIALIZATION ---
document.addEventListener('DOMContentLoaded', async () => {
  // Register Service Worker for PWA
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('sw.js').catch(err => console.log('SW registration failed:', err));
  }

  // Request Notification permission
  if ('Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission();
  }

  // Init DB and load configs
  await initDatabase();
  loadSettingsFromStorage();
  
  // Load state and UI
  await refreshData();
  setupEventListeners();
  startAlarmScheduler();
  
  // Tab initialization
  switchTab('home');
});

// --- DATABASE LOGIC (INDEXEDDB) ---
function initDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);

    request.onerror = (e) => reject('Database failed to open: ' + e.target.errorCode);
    
    request.onsuccess = (e) => {
      db = e.target.result;
      resolve();
    };

    request.onupgradeneeded = (e) => {
      const database = e.target.result;
      
      // Store water records
      if (!database.objectStoreNames.contains('water_history')) {
        database.createObjectStore('water_history', { keyPath: 'id', autoIncrement: true });
      }
      
      // Store custom sound
      if (!database.objectStoreNames.contains('audio_store')) {
        database.createObjectStore('audio_store', { keyPath: 'key' });
      }
    };
  });
}

function saveWaterRecord(amount, type) {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(['water_history'], 'readwrite');
    const store = transaction.objectStore('water_history');
    
    const record = {
      timestamp: new Date().getTime(),
      amount: parseInt(amount),
      type: type
    };
    
    const request = store.add(record);
    request.onsuccess = () => resolve();
    request.onerror = () => reject('Error saving water record');
  });
}

function getWaterRecordsForDateRange(startTime, endTime) {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(['water_history'], 'readonly');
    const store = transaction.objectStore('water_history');
    const list = [];
    
    store.openCursor().onsuccess = (event) => {
      const cursor = event.target.result;
      if (cursor) {
        const record = cursor.value;
        if (record.timestamp >= startTime && record.timestamp <= endTime) {
          list.push(record);
        }
        cursor.continue();
      } else {
        resolve(list);
      }
    };
  });
}

function deleteWaterRecord(id) {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(['water_history'], 'readwrite');
    const store = transaction.objectStore('water_history');
    const request = store.delete(id);
    
    request.onsuccess = () => resolve();
    request.onerror = () => reject('Error deleting record');
  });
}

function clearAllWaterRecords() {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(['water_history'], 'readwrite');
    const store = transaction.objectStore('water_history');
    const request = store.clear();
    
    request.onsuccess = () => resolve();
    request.onerror = () => reject('Error clearing records');
  });
}

function saveAudioBlob(blob) {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(['audio_store'], 'readwrite');
    const store = transaction.objectStore('audio_store');
    
    const record = {
      key: 'voice_alarm',
      audio: blob
    };
    
    const request = store.put(record);
    request.onsuccess = () => resolve();
    request.onerror = () => reject('Error saving voice recording');
  });
}

function getAudioBlob() {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(['audio_store'], 'readonly');
    const store = transaction.objectStore('audio_store');
    const request = store.get('voice_alarm');
    
    request.onsuccess = (e) => {
      if (e.target.result) {
        resolve(e.target.result.audio);
      } else {
        resolve(null);
      }
    };
    request.onerror = () => resolve(null);
  });
}

function deleteAudioBlob() {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(['audio_store'], 'readwrite');
    const store = transaction.objectStore('audio_store');
    const request = store.delete('voice_alarm');
    
    request.onsuccess = () => resolve();
    request.onerror = () => reject('Error deleting voice recording');
  });
}

// --- STATE & SETTINGS MANAGEMENT ---
function loadSettingsFromStorage() {
  STATE.dailyGoal = parseInt(localStorage.getItem('dailyGoal')) || 2000;
  STATE.alarmsEnabled = localStorage.getItem('alarmsEnabled') === 'true';
  STATE.alarmStart = localStorage.getItem('alarmStart') || '08:00';
  STATE.alarmEnd = localStorage.getItem('alarmEnd') || '22:00';
  STATE.alarmInterval = parseInt(localStorage.getItem('alarmInterval')) || 60;
  
  // Sync HTML controls
  document.getElementById('input-daily-goal').value = STATE.dailyGoal;
  document.getElementById('toggle-alarms').checked = STATE.alarmsEnabled;
  document.getElementById('alarm-start').value = STATE.alarmStart;
  document.getElementById('alarm-end').value = STATE.alarmEnd;
  document.getElementById('alarm-interval').value = STATE.alarmInterval;
}

function saveSettingsToStorage() {
  localStorage.setItem('dailyGoal', STATE.dailyGoal);
  localStorage.setItem('alarmsEnabled', STATE.alarmsEnabled);
  localStorage.setItem('alarmStart', STATE.alarmStart);
  localStorage.setItem('alarmEnd', STATE.alarmEnd);
  localStorage.setItem('alarmInterval', STATE.alarmInterval);
}

// --- AUDIO RECORDER MODULE (VOICE ALARM) ---
async function startRecording() {
  audioChunks = [];
  try {
    recordingStream = await navigator.mediaDevices.getUserMedia({ audio: true });
    
    mediaRecorder = new MediaRecorder(recordingStream);
    
    mediaRecorder.ondataavailable = (event) => {
      if (event.data.size > 0) {
        audioChunks.push(event.data);
      }
    };
    
    mediaRecorder.onstop = async () => {
      const audioBlob = new Blob(audioChunks, { type: 'audio/webm' });
      STATE.voiceAlarmBlob = audioBlob;
      await saveAudioBlob(audioBlob);
      updateAudioPreviewUI();
      
      // Stop the visualizer animation
      if (animationFrameId) {
        cancelAnimationFrame(animationFrameId);
      }
      document.getElementById('waveform').classList.remove('active');
      document.getElementById('record-pulse').classList.remove('active');
      document.getElementById('record-status').textContent = 'Gravação salva com sucesso!';
      
      // Stop stream tracks
      if (recordingStream) {
        recordingStream.getTracks().forEach(track => track.stop());
      }
    };
    
    // Setup Audio Visualizer (Waveform)
    audioContext = new (window.AudioContext || window.webkitAudioContext)();
    analyserNode = audioContext.createAnalyser();
    const source = audioContext.createMediaStreamSource(recordingStream);
    source.connect(analyserNode);
    analyserNode.fftSize = 256;
    
    const canvas = document.getElementById('waveform');
    canvas.classList.add('active');
    document.getElementById('record-pulse').classList.add('active');
    document.getElementById('record-status').textContent = 'Gravando... toque no microfone para parar';
    
    drawWaveform();
    
    mediaRecorder.start();
    document.getElementById('btn-record').classList.add('recording');
  } catch (error) {
    console.error('Microphone access denied:', error);
    showInfoModal('Permissão do Microfone', 'Para gravar seu alarme de voz personalizado, precisamos acessar o microfone do seu celular. Por favor, conceda a permissão nas configurações.');
  }
}

function stopRecording() {
  if (mediaRecorder && mediaRecorder.state !== 'inactive') {
    mediaRecorder.stop();
    document.getElementById('btn-record').classList.remove('recording');
  }
}

function drawWaveform() {
  const canvas = document.getElementById('waveform');
  const canvasCtx = canvas.getContext('2d');
  const bufferLength = analyserNode.frequencyBinCount;
  const dataArray = new Uint8Array(bufferLength);
  
  // Resize canvas to parent width
  canvas.width = canvas.parentElement.clientWidth;
  
  function draw() {
    animationFrameId = requestAnimationFrame(draw);
    analyserNode.getByteFrequencyData(dataArray);
    
    canvasCtx.fillStyle = 'rgba(15, 23, 42, 0.4)';
    canvasCtx.fillRect(0, 0, canvas.width, canvas.height);
    
    const barWidth = (canvas.width / bufferLength) * 1.5;
    let barHeight;
    let x = 0;
    
    for (let i = 0; i < bufferLength; i++) {
      barHeight = dataArray[i] / 2.5;
      
      // Indigo/Cyan neon gradient bars
      canvasCtx.fillStyle = `rgb(56, 189, 248)`;
      canvasCtx.fillRect(x, canvas.height - barHeight, barWidth - 1, barHeight);
      
      x += barWidth;
    }
  }
  
  draw();
}

function playVoiceAlarm() {
  if (!STATE.voiceAlarmBlob) return;
  
  const audioUrl = URL.createObjectURL(STATE.voiceAlarmBlob);
  const audio = new Audio(audioUrl);
  audio.play().catch(e => console.log('Audio playback failed:', e));
  
  const playBtn = document.getElementById('btn-play-voice');
  playBtn.innerHTML = `
    <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
      <path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/>
    </svg>
  `;
  
  audio.onended = () => {
    playBtn.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
        <path d="M8 5v14l11-7z"/>
      </svg>
    `;
  };
}

async function deleteVoiceAlarm() {
  await deleteAudioBlob();
  STATE.voiceAlarmBlob = null;
  updateAudioPreviewUI();
  document.getElementById('record-status').textContent = 'Toque no microfone para gravar';
}

function updateAudioPreviewUI() {
  const preview = document.getElementById('audio-preview');
  if (STATE.voiceAlarmBlob) {
    preview.classList.remove('hidden');
  } else {
    preview.classList.add('hidden');
  }
}

// --- SYNTHESIZED AUDIO FALLBACK (WEB AUDIO API) ---
function startSynthesizedAlarm() {
  if (synthIntervalId) return;
  
  synthAudioCtx = new (window.AudioContext || window.webkitAudioContext)();
  
  function playBeep(time, freq, dur) {
    if (!synthAudioCtx) return;
    const osc = synthAudioCtx.createOscillator();
    const gainNode = synthAudioCtx.createGain();
    
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(freq, time);
    
    gainNode.gain.setValueAtTime(0.3, time);
    gainNode.gain.exponentialRampToValueAtTime(0.001, time + dur);
    
    osc.connect(gainNode);
    gainNode.connect(synthAudioCtx.destination);
    
    osc.start(time);
    osc.stop(time + dur);
  }
  
  function playChimeLoop() {
    const now = synthAudioCtx.currentTime;
    // Pleasant melody chime
    playBeep(now, 523.25, 0.2); // C5
    playBeep(now + 0.15, 659.25, 0.2); // E5
    playBeep(now + 0.3, 783.99, 0.25); // G5
    playBeep(now + 0.5, 1046.50, 0.4); // C6
  }
  
  playChimeLoop();
  synthIntervalId = setInterval(playChimeLoop, 2000);
}

function stopSynthesizedAlarm() {
  if (synthIntervalId) {
    clearInterval(synthIntervalId);
    synthIntervalId = null;
  }
  if (synthAudioCtx) {
    synthAudioCtx.close();
    synthAudioCtx = null;
  }
}

// --- ALARM TIMER SCHEDULING ---
function startAlarmScheduler() {
  // Check every second
  setInterval(checkAlarms, 1000);
  calculateNextAlarm();
}

function calculateNextAlarm() {
  if (!STATE.alarmsEnabled) {
    STATE.nextAlarmTime = null;
    return;
  }

  const now = new Date();
  const [startHour, startMin] = STATE.alarmStart.split(':').map(Number);
  const [endHour, endMin] = STATE.alarmEnd.split(':').map(Number);
  
  const startTimeToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), startHour, startMin, 0);
  const endTimeToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), endHour, endMin, 0);
  
  // Set starting search point
  let candidate = new Date(startTimeToday);
  
  // If start time has already passed today
  if (now > candidate) {
    // We add intervals starting from the start time until it's in the future
    while (candidate <= now) {
      candidate.setMinutes(candidate.getMinutes() + STATE.alarmInterval);
    }
  }
  
  // If candidate is within today's time window, that's our next alarm!
  if (candidate <= endTimeToday) {
    STATE.nextAlarmTime = candidate;
  } else {
    // Otherwise, the next alarm is the start time of tomorrow
    const tomorrowStart = new Date(startTimeToday);
    tomorrowStart.setDate(tomorrowStart.getDate() + 1);
    STATE.nextAlarmTime = tomorrowStart;
  }
  
  console.log('Next scheduled alarm:', STATE.nextAlarmTime.toLocaleString());
}

function checkAlarms() {
  if (!STATE.alarmsEnabled || !STATE.nextAlarmTime) return;
  
  const now = new Date();
  if (now >= STATE.nextAlarmTime) {
    triggerAlarm();
  }
}

function triggerAlarm() {
  // Temporarily disable check to prevent multiple screens
  STATE.nextAlarmTime = null;
  
  // 1. Show Fullscreen Alarm UI
  const alarmOverlay = document.getElementById('alarm-overlay');
  alarmOverlay.classList.add('active');
  
  // 2. Play Sound (Custom voice or synth chime)
  if (STATE.voiceAlarmBlob) {
    const audioUrl = URL.createObjectURL(STATE.voiceAlarmBlob);
    alarmAudioElement = new Audio(audioUrl);
    alarmAudioElement.loop = true;
    alarmAudioElement.play().catch(e => {
      console.log('Voice audio autoplay failed. Using synth chime...', e);
      startSynthesizedAlarm();
    });
  } else {
    startSynthesizedAlarm();
  }
  
  // 3. Native Web Notification
  if ('Notification' in window && Notification.permission === 'granted') {
    new Notification('Hora de beber água! 💧', {
      body: 'Seu lembrete personalizado está tocando. Beba água agora!',
      icon: 'icon.svg',
      tag: 'aquavoice-reminder',
      requireInteraction: true
    });
  }
  
  // 4. Vibrate device (if supported)
  if ('vibrate' in navigator) {
    navigator.vibrate([500, 250, 500, 250, 500]);
  }
}

function dismissAlarm() {
  // 1. Hide Overlay
  document.getElementById('alarm-overlay').classList.remove('active');
  
  // 2. Stop playback
  if (alarmAudioElement) {
    alarmAudioElement.pause();
    alarmAudioElement = null;
  }
  stopSynthesizedAlarm();
  
  // 3. Register a quick action recommendation (user drank some water)
  addWater(250, 'Lembrete do Alarme');
  
  // 4. Calculate next alarm
  calculateNextAlarm();
}

// --- HYDRATION DATA PROCESSING ---
async function refreshData() {
  // Load today's history log
  const startOfDay = new Date();
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date();
  endOfDay.setHours(23, 59, 59, 999);
  
  STATE.todayLogs = await getWaterRecordsForDateRange(startOfDay.getTime(), endOfDay.getTime());
  
  // Retrieve voice recording blob if exists
  STATE.voiceAlarmBlob = await getAudioBlob();
  updateAudioPreviewUI();
  
  // Refresh views
  updateWaterProgressUI();
  updateHistoryTimelineUI();
  await updateWeeklyChartUI();
  await calculateStreak();
}

function updateWaterProgressUI() {
  const currentTotal = STATE.todayLogs.reduce((sum, log) => sum + log.amount, 0);
  const percent = Math.min(Math.round((currentTotal / STATE.dailyGoal) * 100), 100);
  
  // Update Wave Level
  const waterFill = document.getElementById('water-fill');
  waterFill.style.height = `${percent}%`;
  
  // Update numbers
  document.getElementById('progress-percent').textContent = `${percent}%`;
  document.getElementById('progress-fraction').textContent = `${currentTotal} / ${STATE.dailyGoal} ml`;
}

function updateHistoryTimelineUI() {
  const list = document.getElementById('history-list');
  list.innerHTML = '';
  
  if (STATE.todayLogs.length === 0) {
    list.innerHTML = `<div class="history-empty">Nenhum copo de água registrado hoje.</div>`;
    return;
  }
  
  // Sort reverse-chronological
  const sorted = [...STATE.todayLogs].sort((a, b) => b.timestamp - a.timestamp);
  
  sorted.forEach((item) => {
    const timeStr = new Date(item.timestamp).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
    const div = document.createElement('div');
    div.className = 'history-item';
    div.innerHTML = `
      <div class="history-left">
        <div class="history-icon">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"/>
          </svg>
        </div>
        <div class="history-details">
          <div class="amount">${item.amount} ml</div>
          <div class="time">${item.type} às ${timeStr}</div>
        </div>
      </div>
      <button class="btn-icon delete-btn" onclick="removeRecord(${item.id})" title="Remover">
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <line x1="18" y1="6" x2="6" y2="18"></line>
          <line x1="6" y1="6" x2="18" y2="18"></line>
        </svg>
      </button>
    `;
    list.appendChild(div);
  });
}

async function updateWeeklyChartUI() {
  // Weekly chart logic: calculate logs for the last 7 calendar days
  const now = new Date();
  const daysOfWeek = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
  const chartBars = document.querySelectorAll('#weekly-chart .chart-bar-wrapper');
  
  // We want to align the bars to current weekday index
  // bar[0] -> Monday, bar[6] -> Sunday. Let's arrange them sequentially ending on today.
  // Or we can keep layout fixed: Mon, Tue, Wed, Thu, Fri, Sat, Sun.
  // Let's compute totals for each day of the current week (from Mon to Sun)
  const currentDayOfWeek = now.getDay(); // 0 is Sunday, 1 is Monday...
  const mondayOffset = currentDayOfWeek === 0 ? -6 : 1 - currentDayOfWeek;
  
  const mondayDate = new Date(now);
  mondayDate.setDate(now.getDate() + mondayOffset);
  mondayDate.setHours(0,0,0,0);
  
  for (let i = 0; i < 7; i++) {
    const targetDay = new Date(mondayDate);
    targetDay.setDate(mondayDate.getDate() + i);
    
    const start = new Date(targetDay);
    start.setHours(0, 0, 0, 0);
    
    const end = new Date(targetDay);
    end.setHours(23, 59, 59, 999);
    
    const dayRecords = await getWaterRecordsForDateRange(start.getTime(), end.getTime());
    const dayTotal = dayRecords.reduce((sum, r) => sum + r.amount, 0);
    const fillPercent = Math.min(Math.round((dayTotal / STATE.dailyGoal) * 100), 100);
    
    // Select the bar element (i=0 is Mon, i=1 is Tue, ..., i=6 is Sun)
    const barFill = chartBars[i].querySelector('.chart-bar-fill');
    barFill.style.height = `${fillPercent}%`;
    barFill.title = `${dayTotal} ml`;
  }
}

async function calculateStreak() {
  // A streak is calculated as consecutive days going back from yesterday (or today) where dailyGoal was met.
  let activeStreak = 0;
  let checkDate = new Date();
  
  // Check if today meets goal, if yes, start from today, else check from yesterday
  const getDailyTotal = async (date) => {
    const start = new Date(date);
    start.setHours(0, 0, 0, 0);
    const end = new Date(date);
    end.setHours(23, 59, 59, 999);
    
    const records = await getWaterRecordsForDateRange(start.getTime(), end.getTime());
    return records.reduce((sum, r) => sum + r.amount, 0);
  };
  
  let todayTotal = await getDailyTotal(checkDate);
  let startFromToday = todayTotal >= STATE.dailyGoal;
  
  if (startFromToday) {
    activeStreak = 1;
  } else {
    // Check if yesterday met the goal, if not, streak is 0
    checkDate.setDate(checkDate.getDate() - 1);
    let yesterdayTotal = await getDailyTotal(checkDate);
    if (yesterdayTotal >= STATE.dailyGoal) {
      activeStreak = 1;
    } else {
      STATE.streak = 0;
      document.getElementById('streak-count').textContent = '0';
      return;
    }
  }
  
  // Go backward day by day
  while (true) {
    checkDate.setDate(checkDate.getDate() - 1);
    let total = await getDailyTotal(checkDate);
    if (total >= STATE.dailyGoal) {
      activeStreak++;
    } else {
      break;
    }
  }
  
  STATE.streak = activeStreak;
  document.getElementById('streak-count').textContent = activeStreak;
}

// --- USER INTERFACE EVENTS ---
function setupEventListeners() {
  // Bottom Tab Navigation
  document.querySelectorAll('nav .nav-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const tab = e.currentTarget.getAttribute('data-tab');
      switchTab(tab);
    });
  });
  
  // Custom Add Dialog triggers
  document.getElementById('btn-custom-add').addEventListener('click', () => {
    document.getElementById('modal-custom-add').classList.add('active');
    document.getElementById('input-custom-amount').value = '';
    document.getElementById('input-custom-amount').focus();
  });
  
  document.getElementById('btn-cancel-custom').addEventListener('click', () => {
    document.getElementById('modal-custom-add').classList.remove('active');
  });
  
  document.getElementById('btn-save-custom').addEventListener('click', () => {
    const val = parseInt(document.getElementById('input-custom-amount').value);
    if (val && val > 0) {
      addWater(val, 'Personalizado');
      document.getElementById('modal-custom-add').classList.remove('active');
    }
  });

  // Settings modification
  document.getElementById('input-daily-goal').addEventListener('change', (e) => {
    let val = parseInt(e.target.value);
    if (val < 500) val = 500;
    STATE.dailyGoal = val;
    saveSettingsToStorage();
    refreshData();
  });

  document.getElementById('toggle-alarms').addEventListener('change', (e) => {
    STATE.alarmsEnabled = e.target.checked;
    saveSettingsToStorage();
    calculateNextAlarm();
    
    if (STATE.alarmsEnabled && 'Notification' in window && Notification.permission !== 'granted') {
      Notification.requestPermission();
    }
  });

  document.getElementById('alarm-start').addEventListener('change', (e) => {
    STATE.alarmStart = e.target.value;
    saveSettingsToStorage();
    calculateNextAlarm();
  });

  document.getElementById('alarm-end').addEventListener('change', (e) => {
    STATE.alarmEnd = e.target.value;
    saveSettingsToStorage();
    calculateNextAlarm();
  });

  document.getElementById('alarm-interval').addEventListener('change', (e) => {
    let val = parseInt(e.target.value);
    if (val < 5) val = 5;
    STATE.alarmInterval = val;
    saveSettingsToStorage();
    calculateNextAlarm();
  });
  
  // Audio record button trigger
  const recordBtn = document.getElementById('btn-record');
  recordBtn.addEventListener('click', () => {
    if (mediaRecorder && mediaRecorder.state === 'recording') {
      stopRecording();
    } else {
      startRecording();
    }
  });

  // Voice alarm preview actions
  document.getElementById('btn-play-voice').addEventListener('click', playVoiceAlarm);
  document.getElementById('btn-delete-voice').addEventListener('click', deleteVoiceAlarm);
  
  // Clear all history trigger
  document.getElementById('btn-clear-history').addEventListener('click', async () => {
    if (confirm('Tem certeza que deseja limpar todo o histórico de consumo?')) {
      await clearAllWaterRecords();
      await refreshData();
    }
  });
  
  // Alarm Trigger Stop Button
  document.getElementById('btn-stop-alarm').addEventListener('click', dismissAlarm);
  
  // Close general info modal
  document.getElementById('btn-close-info').addEventListener('click', () => {
    document.getElementById('modal-info').classList.remove('active');
  });
}

function switchTab(tabId) {
  STATE.currentTab = tabId;
  
  // Update Buttons
  document.querySelectorAll('nav .nav-btn').forEach(btn => {
    if (btn.getAttribute('data-tab') === tabId) {
      btn.classList.add('active');
    } else {
      btn.classList.remove('active');
    }
  });
  
  // Update Content Panels
  document.querySelectorAll('.tab-content').forEach(section => {
    if (section.id === `tab-${tabId}`) {
      section.classList.add('active');
    } else {
      section.classList.remove('active');
    }
  });
  
  // Specific tab entry triggers
  if (tabId === 'history') {
    refreshData(); // Redraw chart
  }
}

// --- GLOBAL ACTIONS EXPOSED TO HTML ---
window.addWater = async function(amount, type) {
  await saveWaterRecord(amount, type);
  
  // Play subtle feedback drip chime sound using Web Audio API
  playDripSound();
  
  // Vibrate phone if supported
  if ('vibrate' in navigator) {
    navigator.vibrate(80);
  }
  
  await refreshData();
};

window.removeRecord = async function(id) {
  await deleteWaterRecord(id);
  await refreshData();
};

// --- HELPER AUDIO FEEDBACK SYNTHS ---
function playDripSound() {
  try {
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    const osc = ctx.createOscillator();
    const gainNode = ctx.createGain();
    
    osc.type = 'sine';
    osc.frequency.setValueAtTime(600, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(1200, ctx.currentTime + 0.1);
    
    gainNode.gain.setValueAtTime(0.15, ctx.currentTime);
    gainNode.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.15);
    
    osc.connect(gainNode);
    gainNode.connect(ctx.destination);
    
    osc.start();
    osc.stop(ctx.currentTime + 0.15);
  } catch (e) {
    console.log('Feedback audio play error:', e);
  }
}

function showInfoModal(title, desc) {
  document.getElementById('info-modal-title').textContent = title;
  document.getElementById('info-modal-desc').textContent = desc;
  document.getElementById('modal-info').classList.add('active');
}

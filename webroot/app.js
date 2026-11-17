(() => {
  'use strict';
  const MODULE = '/data/adb/modules/kl5_smart_fastcharge/kl5ctl.sh';
  const CHARGING_BACKEND = '/data/adb/modules/kl5_smart_fastcharge/charging_backend.sh';
  const $ = id => document.getElementById(id);
  const toast = message => {
    const el = $('toast'); el.textContent = message; el.classList.add('show');
    setTimeout(() => el.classList.remove('show'), 2600);
  };
  const bridgeReady = () => !!(window.ksu && typeof window.ksu.exec === 'function');

  function run(args) {
    if (!bridgeReady()) throw new Error('KsuWebUI root bridge is not available. Open this page inside KsuWebUI and grant root access.');
    // args are assembled only from strict allow-lists and validated numeric inputs below.
    const command = `sh ${MODULE} ${args}`;
    const result = window.ksu.exec(command);
    if (typeof result !== 'string') return String(result ?? '');
    return result;
  }
  function parse(raw) {
    const clean = String(raw || '').replace(/\u0001/g, '\n');
    const out = {};
    clean.split(/\r?\n/).forEach(line => {
      const i = line.indexOf('=');
      if (i > 0) out[line.slice(0, i).trim()] = line.slice(i + 1).trim();
    });
    return out;
  }
  function number(value, divisor=1, digits=0) {
    const n = Number(value);
    return Number.isFinite(n) ? (n / divisor).toFixed(digits) : '--';
  }
  function setText(id, value) { $(id).textContent = value ?? '--'; }
  function command(args) {
    // KsuWebUI bridge may truncate multiline stdout; delimiter preserves fields.
    return run(`${args} 2>&1 | tr '\\n' '\\001'`);
  }
  function chargingCommand(args) {
    if (!bridgeReady()) throw new Error('KsuWebUI root bridge is not available.');
    const result = window.ksu.exec(`sh ${CHARGING_BACKEND} ${args} 2>&1 | tr '\\n' '\\001'`);
    return String(result ?? '').replaceAll('\u0001', '\n');
  }
  function refresh() {
    try {
      $('connection').textContent = 'ROOT CONNECTED';
      const d = parse(command('status'));
      const c = parse(chargingCommand('status'));
      d.USB = c.USB_TYPE || d.USB; d.INPUT_LIMIT = c.INPUT_LIMIT || d.INPUT_LIMIT;
      d.CHARGE_LIMIT = c.CHARGE_LIMIT || d.CHARGE_LIMIT; d.ONLINE = c.ONLINE || d.ONLINE;
      d.DRIVER = c.DRIVER || 'unknown'; d.SC8950 = c.DRIVER === 'sgm41516d' ? 'yes' : 'no';
      d.PROFILE = c.APPLIED_PROFILE || 'normal';
      setText('level', d.LEVEL === 'n/a' ? '--' : d.LEVEL);
      $('levelBar').style.width = `${Math.max(0, Math.min(100, Number(d.LEVEL) || 0))}%`;
      setText('batteryStatus', d.STATUS || 'Unknown');
      setText('chargeState', d.ONLINE === '1' ? 'CHARGER CONNECTED' : 'ON BATTERY');
      setText('temp', d.TEMP === 'n/a' ? '--' : number(d.TEMP, 10, 1));
      setText('voltage', d.VOLTAGE === 'n/a' ? '--' : number(d.VOLTAGE, 1000000, 2));
      setText('current', d.CURRENT === 'n/a' ? '--' : number(d.CURRENT, 1000, 0));
      setText('driverState', d.DRIVER === 'sgm41516d' ? 'SGM41516D' : (d.DRIVER || 'Not detected'));
      setText('usbType', (d.USB || '--').replaceAll('_', ' '));
      setText('inputLimit', d.INPUT_LIMIT === 'n/a' ? '--' : `${number(d.INPUT_LIMIT,1000,0)} mA`);
      setText('chargeLimit', d.CHARGE_LIMIT === 'n/a' ? '--' : `${number(d.CHARGE_LIMIT,1000,0)} mA`);
      setText('deviceModel', d.MODEL);
      setText('androidVersion', d.ANDROID);
      setText('buildName', d.BUILD);
      setText('onlineState', d.ONLINE === '1' ? 'Connected' : 'Disconnected');
      setText('brightnessValue', d.BRIGHTNESS);
      $('brightnessSlider').value = Math.max(1, Math.min(255, Number(d.BRIGHTNESS) || 128));
      setText('brightnessMode', d.BRIGHTNESS_MODE === '0' ? 'MANUAL' : d.BRIGHTNESS_MODE === '1' ? 'AUTO' : 'UNKNOWN');
      $('chargeAlert').value = d.CHARGE_ALERT || 80;
      $('tempAlert').value = d.TEMP_ALERT || 42;
      const profile = ['normal','fast','fastest','adaptive'].includes(d.PROFILE) ? d.PROFILE : 'normal';
      setProfileUI(profile);
      const pmsg = $('profileMessage'); if (pmsg) pmsg.textContent = `Requested: ${c.REQUESTED_PROFILE || 'normal'} · Applied: ${c.APPLIED_PROFILE || 'normal'} · USB: ${c.USB_TYPE || 'unknown'}`;
      $('greeting').textContent = `Welcome back, ${d.MODEL || 'KL5 user'}. Your dashboard is online.`;
      $('tempHint').textContent = Number(d.TEMP) >= 420 ? 'Check device temperature' : 'Battery sensor';
    } catch (e) {
      $('connection').textContent = 'BRIDGE UNAVAILABLE';
      $('greeting').textContent = 'Open this module through KsuWebUI and grant root access to load live controls.';
      toast(e.message);
    }
  }
  function setProfileUI(profile) {
    document.querySelectorAll('[data-profile]').forEach(btn => btn.classList.toggle('active', btn.dataset.profile === profile));
    setText('profileBadge', profile.toUpperCase());
  }
  document.querySelectorAll('[data-profile]').forEach(btn => btn.addEventListener('click', () => {
    const profile = btn.dataset.profile;
    if (!['normal','fast','fastest','adaptive'].includes(profile)) return;
    try {
      const out = parse(chargingCommand(`profile ${profile}`));
      const pmsg = $('profileMessage');
      if (pmsg) pmsg.textContent = out.MESSAGE || out.RESULT || 'Profile request processed.';
      setProfileUI(out.APPLIED_PROFILE || 'normal');
      toast(out.RESULT === 'blocked' ? (out.MESSAGE || 'Profile blocked by safety checks.') : `${String(out.APPLIED_PROFILE || 'normal').toUpperCase()} profile applied status updated.`);
      refresh();
    } catch (e) { toast(e.message); }
  }));

  $('brightnessSlider').addEventListener('input', e => setText('brightnessValue', e.target.value));
  $('applyBrightness').addEventListener('click', () => {
    const value = Math.max(1, Math.min(255, Number($('brightnessSlider').value) || 128));
    try {
      const out = command(`brightness ${value}`);
      if (out.includes('ERROR=')) throw new Error(out);
      $('brightnessMessage').textContent = `Manual brightness applied: ${value}/255`;
      setText('brightnessMode', 'MANUAL');
      toast('Manual brightness updated.');
    } catch (e) { $('brightnessMessage').textContent = e.message; }
  });
  $('autoBrightness').addEventListener('click', () => {
    try {
      const out = command('brightness-auto');
      if (out.includes('ERROR=')) throw new Error(out);
      $('brightnessMessage').textContent = 'Automatic brightness restored.';
      setText('brightnessMode', 'AUTO');
      toast('Automatic brightness restored.');
    } catch (e) { $('brightnessMessage').textContent = e.message; }
  });
  document.querySelectorAll('[data-bright]').forEach(btn => btn.addEventListener('click', () => {
    $('brightnessSlider').value = btn.dataset.bright;
    setText('brightnessValue', btn.dataset.bright);
  }));
  $('saveThresholds').addEventListener('click', () => {
    const charge = Number($('chargeAlert').value), temp = Number($('tempAlert').value);
    if (!Number.isInteger(charge) || charge < 50 || charge > 100 || !Number.isInteger(temp) || temp < 35 || temp > 50) {
      toast('Charge reference: 50–100%. Temperature reference: 35–50°C.'); return;
    }
    try {
      let a = command(`charge-alert ${charge}`);
      let b = command(`temp-alert ${temp}`);
      if (a.includes('ERROR=') || b.includes('ERROR=')) throw new Error(a + b);
      $('thresholdMessage').textContent = 'Reference thresholds saved. They do not stop or throttle charging.';
      toast('Reference thresholds saved.');
    } catch (e) { $('thresholdMessage').textContent = e.message; }
  });
  $('makeReport').addEventListener('click', () => {
    try {
      const out = command('report');
      $('diagnosticOutput').textContent = out.replaceAll('\u0001','\n');
      toast('Diagnostic report generated in /data/adb/kl5_fastcharge/');
    } catch (e) { $('diagnosticOutput').textContent = e.message; }
  });
  $('viewLogs').addEventListener('click', () => {
    try { $('diagnosticOutput').textContent = command('logs').replaceAll('\u0001','\n'); }
    catch (e) { $('diagnosticOutput').textContent = e.message; }
  });
  $('refreshBtn').addEventListener('click', refresh);
  refresh();
  setInterval(refresh, 1500);
})();

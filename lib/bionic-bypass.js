/**
 * Bionic Bypass - Fixes os.networkInterfaces() on Android
 *
 * Android's Bionic libc blocks certain network interface queries.
 * This module provides a workaround by returning a mock interface.
 */

import fs from 'fs';
import path from 'path';

const BYPASS_SCRIPT = `
// OpenClaw Bionic Bypass - Auto-generated
const os = require('os');
const originalNetworkInterfaces = os.networkInterfaces;

os.networkInterfaces = function() {
  try {
    const interfaces = originalNetworkInterfaces.call(os);
    if (interfaces && Object.keys(interfaces).length > 0) {
      return interfaces;
    }
  } catch (e) {
    // Bionic blocked the call, use fallback
  }

  // Return mock loopback interface
  return {
    lo: [
      {
        address: '127.0.0.1',
        netmask: '255.0.0.0',
        family: 'IPv4',
        mac: '00:00:00:00:00:00',
        internal: true,
        cidr: '127.0.0.1/8'
      }
    ]
  };
};
`;

export function getBypassScriptPath() {
  const homeDir = process.env.HOME || '/data/data/com.termux/files/home';
  return path.join(homeDir, '.openclaw', 'bionic-bypass.js');
}

export function installBypass() {
  const scriptPath = getBypassScriptPath();
  const scriptDir = path.dirname(scriptPath);

  if (!fs.existsSync(scriptDir)) {
    fs.mkdirSync(scriptDir, { recursive: true });
  }

  fs.writeFileSync(scriptPath, BYPASS_SCRIPT, 'utf8');
  fs.chmodSync(scriptPath, '644');

  return scriptPath;
}

export function getNodeOptions() {
  const scriptPath = getBypassScriptPath();
  return `--require "${scriptPath}"`;
}

export function isAndroid() {
  return process.platform === 'android' ||
         fs.existsSync('/data/data/com.termux') ||
         process.env.TERMUX_VERSION !== undefined;
}

export function checkBypassInstalled() {
  const scriptPath = getBypassScriptPath();
  return fs.existsSync(scriptPath);
}

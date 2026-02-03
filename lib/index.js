/**
 * OpenClawd-Termux - Main entry point
 */

import fs from 'fs';
import path from 'path';
import {
  checkDependencies,
  installTermuxDeps,
  setupBionicBypass,
  configureTermux,
  getInstallStatus,
  installProot,
  installUbuntu,
  setupProotUbuntu,
  setupBionicBypassInProot,
  runInProot
} from './installer.js';
import { isAndroid } from './bionic-bypass.js';
import { spawn } from 'child_process';

const VERSION = '1.0.0';

function printBanner() {
  console.log(`
╔═══════════════════════════════════════════╗
║     OpenClawd-Termux v${VERSION}              ║
║     AI Gateway for Android                ║
╚═══════════════════════════════════════════╝
`);
}

function printHelp() {
  console.log(`
Usage: openclawdx <command> [args...]

Commands:
  setup       Full installation (proot + Ubuntu + OpenClaw)
  status      Check installation status
  start       Start OpenClaw gateway (inside proot)
  shell       Open Ubuntu shell with OpenClaw ready
  help        Show this help message

  Any other command is passed directly to openclaw in proot:
    openclawdx onboarding      → openclaw onboarding
    openclawdx gateway -v      → openclaw gateway -v
    openclawdx doctor          → openclaw doctor
    openclawdx <anything>      → openclaw <anything>

Examples:
  openclawdx setup             # First-time setup
  openclawdx start             # Start gateway
  openclawdx onboarding        # Configure API keys
  openclawdx shell             # Enter Ubuntu shell
`);
}

async function runSetup() {
  console.log('Starting OpenClawd setup for Termux...\n');
  console.log('This will install: proot-distro → Ubuntu → Node.js 22 → OpenClaw\n');

  if (!isAndroid()) {
    console.log('Warning: This package is designed for Android/Termux.');
    console.log('Some features may not work on other platforms.\n');
  }

  let status = getInstallStatus();

  // Step 1: Install proot-distro
  console.log('[1/5] Checking proot-distro...');
  if (!status.proot) {
    console.log('  Installing proot-distro...');
    installProot();
  } else {
    console.log('  ✓ proot-distro installed');
  }
  console.log('');

  // Step 2: Install Ubuntu
  console.log('[2/5] Checking Ubuntu in proot...');
  status = getInstallStatus();
  if (!status.ubuntu) {
    console.log('  Installing Ubuntu (this takes a while)...');
    installUbuntu();
  } else {
    console.log('  ✓ Ubuntu installed');
  }
  console.log('');

  // Step 3: Setup Node.js and OpenClaw in Ubuntu
  console.log('[3/5] Setting up Node.js and OpenClaw in Ubuntu...');
  status = getInstallStatus();
  if (!status.openClawInProot) {
    setupProotUbuntu();
  } else {
    console.log('  ✓ OpenClaw already installed in proot');
  }
  console.log('');

  // Step 4: Setup Bionic Bypass in proot
  console.log('[4/5] Setting up Bionic Bypass in proot...');
  setupBionicBypassInProot();
  console.log('');

  // Step 5: Configure Termux wake-lock
  console.log('[5/5] Configuring Termux...');
  configureTermux();
  console.log('');

  // Done
  console.log('═══════════════════════════════════════════');
  console.log('Setup complete!');
  console.log('');
  console.log('Next steps:');
  console.log('  1. Run onboarding: openclawdx onboarding');
  console.log('     → Select "Loopback (127.0.0.1)" when asked!');
  console.log('  2. Start gateway:  openclawdx start');
  console.log('');
  console.log('Dashboard: http://127.0.0.1:18789');
  console.log('═══════════════════════════════════════════');
}

function showStatus() {
  console.log('Installation Status:\n');

  const status = getInstallStatus();

  console.log('Termux:');
  console.log(`  proot-distro:   ${status.proot ? '✓ installed' : '✗ missing'}`);
  console.log(`  Ubuntu:         ${status.ubuntu ? '✓ installed' : '✗ not installed'}`);
  console.log('');

  console.log('Ubuntu (proot):');
  console.log(`  OpenClaw:       ${status.openClawInProot ? '✓ installed' : '✗ not installed'}`);
  console.log(`  Bionic Bypass:  ${status.bionicBypass ? '✓ configured' : '✗ not configured'}`);
  console.log('');

  if (status.proot && status.ubuntu && status.openClawInProot) {
    console.log('Status: ✓ Ready to run!');
    console.log('');
    console.log('Commands:');
    console.log('  openclawdx start       # Start gateway');
    console.log('  openclawdx onboarding  # Configure API keys');
    console.log('  openclawdx shell       # Enter Ubuntu shell');
  } else {
    console.log('Status: ✗ Setup incomplete');
    console.log('Run: openclawdx setup');
  }
}

function startGateway() {
  const status = getInstallStatus();

  if (!status.proot || !status.ubuntu) {
    console.error('proot/Ubuntu not installed. Run: openclawdx setup');
    process.exit(1);
  }

  if (!status.openClawInProot) {
    console.error('OpenClaw not installed in proot. Run: openclawdx setup');
    process.exit(1);
  }

  console.log('Starting OpenClaw gateway in proot Ubuntu...\n');
  console.log('Dashboard: http://127.0.0.1:18789');
  console.log('Press Ctrl+C to stop\n');

  const gateway = runInProot('openclaw gateway --verbose');

  gateway.on('error', (err) => {
    console.error('Failed to start gateway:', err.message);
  });

  gateway.on('close', (code) => {
    console.log(`Gateway exited with code ${code}`);
  });
}

function runOpenclawCommand(args) {
  const status = getInstallStatus();

  if (!status.proot || !status.ubuntu || !status.openClawInProot) {
    console.error('Setup not complete. Run: openclawdx setup');
    process.exit(1);
  }

  const command = args.join(' ');
  console.log(`Running: openclaw ${command}\n`);

  // Special hint for onboarding
  if (args[0] === 'onboarding') {
    console.log('TIP: Select "Loopback (127.0.0.1)" when asked for binding!\n');
  }

  const proc = runInProot(`openclaw ${command}`);

  proc.on('error', (err) => {
    console.error('Failed to run command:', err.message);
  });
}

function openShell() {
  const status = getInstallStatus();

  if (!status.proot || !status.ubuntu) {
    console.error('proot/Ubuntu not installed. Run: openclawdx setup');
    process.exit(1);
  }

  console.log('Entering Ubuntu shell (with Bionic Bypass)...');
  console.log('Type "exit" to return to Termux\n');

  const shell = spawn('proot-distro', ['login', 'ubuntu'], {
    stdio: 'inherit'
  });

  shell.on('error', (err) => {
    console.error('Failed to open shell:', err.message);
  });
}

export async function main(args) {
  const command = args[0] || 'help';

  printBanner();

  switch (command) {
    case 'setup':
    case 'install':
      await runSetup();
      break;

    case 'status':
      showStatus();
      break;

    case 'start':
    case 'run':
      startGateway();
      break;

    case 'shell':
    case 'ubuntu':
      openShell();
      break;

    case 'help':
    case '--help':
    case '-h':
      printHelp();
      break;

    default:
      // Pass any other command to openclaw in proot
      runOpenclawCommand(args);
      break;
  }
}

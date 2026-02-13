/**
 * OpenClaw-Termux - Main entry point
 */

import {
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

const VERSION = '1.6.1';

function printBanner() {
  console.log(`
╔═══════════════════════════════════════════╗
║     OpenClaw-Termux v${VERSION}              ║
║     AI Gateway for Android                ║
╚═══════════════════════════════════════════╝
`);
}

function printHelp() {
  console.log(`
Usage: openclawx <command> [args...]

Commands:
  setup       Full installation (proot + Ubuntu + OpenClaw)
  status      Check installation status
  start       Start OpenClaw gateway (inside proot)
  shell       Open Ubuntu shell with OpenClaw ready
  help        Show this help message

  Any other command is passed directly to openclaw in proot:
    openclawx onboarding      → openclaw onboarding
    openclawx gateway -v      → openclaw gateway -v
    openclawx doctor          → openclaw doctor
    openclawx <anything>      → openclaw <anything>

Examples:
  openclawx setup             # First-time setup
  openclawx start             # Start gateway
  openclawx onboarding        # Configure API keys
  openclawx shell             # Enter Ubuntu shell
`);
}

async function runSetup() {
  console.log('Starting OpenClaw setup for Termux...\n');
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
  console.log('  1. Run onboarding: openclawx onboarding');
  console.log('     → Select "Loopback (127.0.0.1)" when asked!');
  console.log('  2. Start gateway:  openclawx start');
  console.log('');
  console.log('Dashboard: http://127.0.0.1:18789');
  console.log('═══════════════════════════════════════════');
}

function showStatus() {
  // Quick loading while checking proot
  process.stdout.write('Checking installation status...');
  const status = getInstallStatus();
  process.stdout.write('\r' + ' '.repeat(35) + '\r');

  console.log('Installation Status:\n');

  console.log('Termux:');
  console.log(`  proot-distro:     ${status.proot ? '✓ installed' : '✗ missing'}`);
  console.log(`  Ubuntu (proot):   ${status.ubuntu ? '✓ installed' : '✗ not installed'}`);
  console.log('');

  if (status.ubuntu) {
    console.log('Inside Ubuntu:');
    console.log(`  OpenClaw:         ${status.openClawInProot ? '✓ installed' : '✗ not installed'}`);
    console.log(`  Bionic Bypass:    ${status.bionicBypassInProot ? '✓ configured' : '✗ not configured'}`);
    console.log('');
  }

  if (status.proot && status.ubuntu && status.openClawInProot) {
    console.log('Status: ✓ Ready to run!');
    console.log('');
    console.log('Commands:');
    console.log('  openclawx start       # Start gateway');
    console.log('  openclawx onboarding  # Configure API keys');
    console.log('  openclawx shell       # Enter Ubuntu shell');
  } else {
    console.log('Status: ✗ Setup incomplete');
    console.log('Run: openclawx setup');
  }
}

function startGateway() {
  const status = getInstallStatus();

  if (!status.proot || !status.ubuntu) {
    console.error('proot/Ubuntu not installed. Run: openclawx setup');
    process.exit(1);
  }

  if (!status.openClawInProot) {
    console.error('OpenClaw not installed in proot. Run: openclawx setup');
    process.exit(1);
  }

  // Loading animation until dashboard responds
  const frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
  let i = 0;
  let started = false;
  const DASHBOARD_URL = 'http://127.0.0.1:18789';

  const spinner = setInterval(() => {
    if (!started) {
      process.stdout.write(`\r${frames[i++ % frames.length]} Starting OpenClaw gateway...`);
    }
  }, 80);

  // Poll dashboard until it responds
  const checkDashboard = setInterval(async () => {
    if (started) return;
    try {
      const response = await fetch(DASHBOARD_URL, { method: 'HEAD', signal: AbortSignal.timeout(1000) });
      if (response.ok || response.status < 500) {
        started = true;
        clearInterval(spinner);
        clearInterval(checkDashboard);
        process.stdout.write('\r' + ' '.repeat(40) + '\r');
        console.log('✓ OpenClaw gateway started!\n');
        console.log(`Dashboard: ${DASHBOARD_URL}`);
        console.log('Press Ctrl+C to stop\n');
        console.log('─'.repeat(45) + '\n');
      }
    } catch { /* ignore polling errors */ }
  }, 500);

  // Start gateway in background (suppress output until ready)
  const gateway = runInProot('openclaw gateway --verbose');

  gateway.on('error', (err) => {
    clearInterval(spinner);
    clearInterval(checkDashboard);
    console.error('\nFailed to start gateway:', err.message);
  });

  gateway.on('close', (code) => {
    clearInterval(spinner);
    clearInterval(checkDashboard);
    if (!started) {
      console.log('\nGateway exited before starting. Run: openclawx onboarding');
    }
    console.log(`Gateway exited with code ${code}`);
  });
}

function runOpenclawCommand(args) {
  const status = getInstallStatus();

  if (!status.proot || !status.ubuntu || !status.openClawInProot) {
    console.error('Setup not complete. Run: openclawx setup');
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
    console.error('proot/Ubuntu not installed. Run: openclawx setup');
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

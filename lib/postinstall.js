/**
 * Post-install script - runs after npm install
 */

import { isAndroid, installBypass, getNodeOptions } from './bionic-bypass.js';

function main() {
  console.log('\n📱 OpenClaw-Termux post-install\n');

  if (!isAndroid()) {
    console.log('Not running on Android/Termux - skipping Bionic Bypass setup.');
    console.log('You can still use this package on other systems.\n');
    return;
  }

  // Install the bypass script
  try {
    const scriptPath = installBypass();
    console.log(`✓ Bionic Bypass installed at: ${scriptPath}`);
  } catch (err) {
    console.error('✗ Failed to install Bionic Bypass:', err.message);
    return;
  }

  // Show instructions
  const nodeOptions = getNodeOptions();

  console.log('\n' + '═'.repeat(50));
  console.log('IMPORTANT: Add this to your shell config (~/.bashrc):');
  console.log('═'.repeat(50));
  console.log(`\nexport NODE_OPTIONS="${nodeOptions}"\n`);
  console.log('Or run: openclawx setup');
  console.log('═'.repeat(50) + '\n');
}

main();

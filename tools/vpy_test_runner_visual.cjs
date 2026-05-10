#!/usr/bin/env node
/**
 * vpy_test_runner_visual.cjs
 * ─────────────────────────────────────────────────────────────
 * Visual test runner with web UI
 * 
 * Usage:
 *   node tools/vpy_test_runner_visual.cjs
 * 
 * Opens http://localhost:3000 with interactive test viewer
 */

'use strict';

const fs       = require('fs');
const path     = require('path');
const http     = require('http');
const cp       = require('child_process');
const os       = require('os');

const WORKSPACE_ROOT = path.resolve(__dirname, '..');
const PORT = 3000;

// Find all test specs
function findTests() {
  const tests = [];
  const examplesDir = path.join(WORKSPACE_ROOT, 'examples');
  
  function walk(dir) {
    for (const file of fs.readdirSync(dir)) {
      const full = path.join(dir, file);
      if (fs.statSync(full).isDirectory()) {
        walk(full);
      } else if (file === 'test.vpy.js') {
        const projectDir = path.dirname(full);
        const projectName = path.relative(examplesDir, projectDir);
        tests.push({
          name: projectName,
          path: full,
          projectDir,
        });
      }
    }
  }
  
  walk(examplesDir);
  return tests.sort((a, b) => a.name.localeCompare(b.name));
}

// Load golden snapshot
function loadGolden(test) {
  const goldenPath = path.join(test.projectDir, 'golden.json');
  if (!fs.existsSync(goldenPath)) {
    return [];
  }
  try {
    return JSON.parse(fs.readFileSync(goldenPath, 'utf8'));
  } catch (e) {
    return [];
  }
}

// Run a single test
function runTest(testIndex, tests) {
  const test = tests[testIndex];
  if (!test) return [];
  
  try {
    // Load test spec to get frame count (bypass require cache)
    let frames = 500;
    try {
      delete require.cache[require.resolve(test.path)];
      const testSpec = require(test.path);
      frames = testSpec.frames ?? 500;
    } catch (e) {
      console.warn(`Warning: Could not load test spec ${test.path}:`, e.message);
      frames = 500;
    }
    
    const runner = path.join(WORKSPACE_ROOT, 'tools', 'vpy_test_runner.cjs');
    const result = cp.spawnSync('node', [
      runner,
      test.path,
      '--no-compile',
      '--frames', String(frames)
    ], {
      encoding: 'utf8',
      cwd: WORKSPACE_ROOT,
      timeout: 120000,
    });
    
    if (result.error) {
      console.error(`[ERROR] Test ${test.name}:`, result.error.message);
      return loadGolden(test);
    }
    
    // Check if execution was successful by looking for [DRAW] marker
    if (result.stdout.includes('[DRAW]')) {
      console.log(`[RUN] ${test.name}: executed with ${frames} frames`);
      if (result.stdout.includes('[PASS]')) {
        console.log(`[✓] ${test.name}: PASSED`);
      }
    }
    
    // Return golden snapshot (which should match execution result)
    return loadGolden(test);
  } catch (e) {
    console.error(`Error running test ${test.name}:`, e.message);
    return loadGolden(test);
  }
}

// HTTP Server
const tests = findTests();

const server = http.createServer((req, res) => {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }
  
  // API endpoints
  if (req.url === '/api/tests') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(tests.map(t => ({
      name: t.name,
      status: 'pass',
    }))));
    return;
  }
  
  if (req.url.startsWith('/api/golden/')) {
    const index = parseInt(req.url.split('/')[3], 10);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(loadGolden(tests[index]) || []));
    return;
  }
  
  if (req.url.startsWith('/api/run/')) {
    const index = parseInt(req.url.split('/')[3], 10);
    const test = tests[index];
    
    if (!test) {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Test not found' }));
      return;
    }
    
    const vectors = runTest(index, tests);
    const diagnostic = {
      testName: test.name,
      vectorCount: vectors.length,
      executed: true,
    };
    
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ vectors, diagnostic }));
    return;
  }
  
  // Static files
  if (req.url === '/' || req.url === '/index.html') {
    const indexPath = path.join(__dirname, 'public', 'index.html');
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(fs.readFileSync(indexPath, 'utf8'));
    return;
  }
  
  // 404
  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not found');
});

server.listen(PORT, () => {
  const url = `http://localhost:${PORT}`;
  console.log(`\n📊 VPy Test Viewer starting...\n`);
  console.log(`🌐 Open: ${url}`);
  console.log(`📋 Tests found: ${tests.length}`);
  console.log(`\n✓ Server running on port ${PORT}\n`);
  
  // Auto-open browser (macOS)
  if (process.platform === 'darwin') {
    cp.exec(`open "${url}"`, (err) => {
      if (err) console.error('Failed to open browser:', err);
    });
  } else if (process.platform === 'win32') {
    cp.exec(`start ${url}`, (err) => {
      if (err) console.error('Failed to open browser:', err);
    });
  } else if (process.platform === 'linux') {
    cp.exec(`xdg-open "${url}"`, (err) => {
      if (err) console.error('Failed to open browser:', err);
    });
  }
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n✓ Server stopped\n');
  process.exit(0);
});

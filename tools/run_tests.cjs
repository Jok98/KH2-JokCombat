// Repository-local checks. No game process, save or OpenKH output is touched.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const YAML = require('yaml');

const root = path.resolve(__dirname, '..');
const luaCli = require.resolve('fengari-node-cli/src/lua-cli.js');

function run(command, args) {
  const result = spawnSync(command, args, { cwd: root, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`${command} failed (exit ${result.status}, signal ${result.signal})`);
  }
}

function pythonCommand() {
  const candidates = process.env.PYTHON
    ? [[process.env.PYTHON]]
    : [['python'], ['python3'], ['py', '-3']];
  for (const [command, ...prefix] of candidates) {
    const result = spawnSync(command, [...prefix, '-c',
      'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)'],
    { cwd: root, stdio: 'ignore' });
    if (result.status === 0) return [command, prefix];
  }
  throw new Error('Python 3.10+ is required. Set PYTHON to its executable path.');
}

function checkManifest() {
  const document = YAML.parseDocument(fs.readFileSync(path.join(root, 'mod.yml'), 'utf8'),
    { uniqueKeys: true });
  assert.equal(document.errors.length, 0, document.errors.map(String).join('\n'));
  const mod = document.toJS();
  assert.equal(mod.game, 'kh2');
  const destinations = new Set();
  let sources = 0;
  function visit(nodes) {
    for (const node of nodes) {
      if (node.source) visit(node.source);
      else {
        const source = path.resolve(root, node.name);
        const relative = path.relative(root, source);
        assert(relative && !relative.startsWith('..') && !path.isAbsolute(relative),
          `Source must be inside the repository: ${node.name}`);
        assert(fs.statSync(source).isFile(), `Missing source: ${node.name}`);
        sources++;
      }
    }
  }
  for (const asset of mod.assets) {
    assert(!destinations.has(asset.name), `Duplicate asset: ${asset.name}`);
    destinations.add(asset.name);
    visit(asset.source);
  }
  console.log(`MANIFEST_PASS assets=${mod.assets.length} sources=${sources}`);
}

function checkPtyaAsset() {
  const directory = path.join(root, 'assets', '00battle');
  const report = JSON.parse(fs.readFileSync(path.join(directory, 'ptya-normal-report.json')));
  const asset = fs.readFileSync(path.join(directory, 'ptya.list'));
  const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
  assert.equal(asset.length, report.file_size);
  assert.equal(hash(asset), report.output_sha256);
  const original = Buffer.from(asset);
  const offsets = new Set();
  for (const change of report.byte_differences) {
    assert(Number.isInteger(change.offset) && change.offset >= 0 && change.offset < asset.length);
    assert(!offsets.has(change.offset), 'Duplicate PTYA difference');
    offsets.add(change.offset);
    assert.equal(asset[change.offset], change.after);
    original[change.offset] = change.before;
  }
  assert.equal(hash(original), report.input_sha256);
  console.log(`PTYA_ASSET_PASS bytes=${asset.length} differences=${offsets.size}`);
}

try {
  const [python, prefix] = pythonCommand();
  const tests = fs.readdirSync(path.join(root, 'tests'))
    .filter(name => name.endsWith('_Smoke.lua')).sort();
  assert(tests.length > 0, 'No Lua smoke tests found');
  const luaSources = ['runtime', 'diagnostics', 'experiments', 'tests'].flatMap(directory =>
    fs.readdirSync(path.join(root, directory)).filter(name => name.endsWith('.lua'))
      .map(name => `${directory}/${name}`));
  run(process.execPath, [luaCli, '-E', '-e', luaSources
    .map(file => `assert(loadfile(${JSON.stringify(file)}))`).join('\n')]);
  console.log(`LUA_SYNTAX_PASS=${luaSources.length}/${luaSources.length}`);
  for (const test of tests) {
    // Fengari 0.1.0 file mode may return zero after a Lua error. Its -e mode
    // propagates failures, including syntax/assertion errors inside dofile.
    run(process.execPath, [luaCli, '-E', '-e', `dofile(${JSON.stringify(`tests/${test}`)})`]);
  }
  console.log(`LUA_SMOKE_PASS=${tests.length}/${tests.length}`);
  run(python, [...prefix, '-B', '-c',
    "import ast, pathlib; files = [*pathlib.Path('tools').glob('*.py'), *pathlib.Path('tests').glob('*.py')]; " +
    "[ast.parse(p.read_text(encoding='utf-8-sig'), filename=str(p)) for p in files]; " +
    "print(f'PYTHON_SYNTAX_PASS={len(files)}/{len(files)}')"]);
  run(python, [...prefix, '-B', '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_*.py', '-v']);
  checkManifest();
  checkPtyaAsset();
  console.log('REPO_CHECKS_PASS (mock/static checks; gameplay validation is separate)');
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}

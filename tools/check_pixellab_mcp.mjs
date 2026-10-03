// Authenticate and list tools only; this never requests asset generation.
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const repo = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
let workspace = repo;
while (!existsSync(path.join(workspace, '.tools/godot-mcp/node_modules'))) {
  const parent = path.dirname(workspace);
  if (parent === workspace) throw new Error('Installed MCP SDK was not found');
  workspace = parent;
}
const sdk = path.join(workspace, '.tools/godot-mcp/node_modules/@modelcontextprotocol/sdk/dist/esm');
const { Client } = await import(pathToFileURL(path.join(sdk, 'client/index.js')).href);
const { StreamableHTTPClientTransport } = await import(pathToFileURL(path.join(sdk, 'client/streamableHttp.js')).href);
let headers;
try {
  // Capture the credential helper privately. Never forward its stdout/stderr.
  const raw = execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
    '-File', path.join(repo, 'tools/pixellab_headers.ps1')],
    { encoding: 'utf8', windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'], timeout: 10000 });
  headers = JSON.parse(raw);
} catch {
  console.error('PixelLab credential helper failed; no secret was logged.');
  process.exit(1);
}
const client = new Client({ name: 'lob-pixellab-check', version: '1.0.0' }, { capabilities: {} });
const transport = new StreamableHTTPClientTransport(new URL('https://api.pixellab.ai/mcp'), {
  requestInit: { headers },
});
const timeout = setTimeout(() => { console.error('PixelLab connection timed out.'); process.exit(1); }, 45000);
try {
  await client.connect(transport);
  const list = await client.listTools();
  if (!list.tools?.length) throw new Error('No tools returned');
  const report = { status: 'passed', checked_at: new Date().toISOString(),
    tool_count: list.tools.length, tools: list.tools.map(tool => tool.name),
    scope: 'Authenticated initialization and tools/list only; no generation or credit use requested.' };
  const out = path.join(repo, 'qa_runtime/art_tooling');
  mkdirSync(out, { recursive: true });
  writeFileSync(path.join(out, 'pixellab_mcp.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report));
} catch (error) {
  // Avoid dumping request options, headers, or server-provided error text.
  console.error(JSON.stringify({ status: 'failed', type: error.name,
    code: typeof error.code === 'number' ? error.code : null,
    message: 'PixelLab authentication or MCP tool discovery failed; credentials were not logged.' }));
  process.exitCode = 1;
} finally {
  clearTimeout(timeout);
  await client.close();
  headers = null;
}

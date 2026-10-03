// Read-only MCP handshake and active-project inspection; no game launch/save.
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const repo = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
let workspace = repo;
while (!existsSync(path.join(workspace, '.tools/godot-mcp/build/index.js'))) {
  const parent = path.dirname(workspace);
  if (parent === workspace) throw new Error('Godot MCP installation not found');
  workspace = parent;
}
const serverRoot = path.join(workspace, '.tools/godot-mcp');
const sdkRoot = path.join(serverRoot, 'node_modules/@modelcontextprotocol/sdk/dist/esm');
const { Client } = await import(pathToFileURL(path.join(sdkRoot, 'client/index.js')).href);
const { StdioClientTransport } = await import(pathToFileURL(path.join(sdkRoot, 'client/stdio.js')).href);
const transport = new StdioClientTransport({
  command: process.execPath,
  args: [path.join(serverRoot, 'build/index.js')],
  env: {
    ...process.env,
    GODOT_PATH: path.join(workspace, '.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe'),
  },
  stderr: 'pipe',
});
const client = new Client({ name: 'lob-tooling-check', version: '1.0.0' }, { capabilities: {} });
const timeout = setTimeout(() => {
  console.error('MCP check exceeded 45 seconds');
  void client.close().finally(() => process.exit(1));
}, 45000);
try {
  await client.connect(transport);
  const { tools } = await client.listTools();
  for (const expected of ['get_godot_version', 'get_project_info']) {
    if (!tools.some(tool => tool.name === expected)) throw new Error(`Missing ${expected}`);
  }
  const version = await client.callTool({ name: 'get_godot_version', arguments: {} });
  const project = await client.callTool({ name: 'get_project_info', arguments: { projectPath: path.join(repo, '새-게임-프로젝트') } });
  if (version.isError || project.isError) throw new Error('MCP tool returned an error');
  const versionText = version.content.filter(c => c.type === 'text').map(c => c.text).join('\n');
  if (!versionText.includes('4.7')) throw new Error(`Unexpected engine: ${versionText}`);
  const projectInfo = JSON.parse(project.content.find(c => c.type === 'text').text);
  if (path.resolve(projectInfo.path) !== path.join(repo, '새-게임-프로젝트')) throw new Error('Project path mismatch');
  const report = { status: 'passed', tool_count: tools.length, engine: versionText, project: projectInfo };
  const out = path.join(repo, 'qa_runtime/art_tooling');
  mkdirSync(out, { recursive: true });
  writeFileSync(path.join(out, 'godot_mcp.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify({ status: 'passed', tool_count: tools.length, engine: versionText, project: projectInfo.path }));
} finally {
  clearTimeout(timeout);
  await client.close();
}

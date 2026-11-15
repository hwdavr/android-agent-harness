// Read every saved record, including component records omitted by the scene graph.
import { readFileSync, realpathSync } from 'node:fs';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

const [cli, archive] = process.argv.slice(2);
if (!cli || !archive) throw new Error('Expected OpenPencil CLI and archive paths');
const require = createRequire(realpathSync(cli));
const { parseFigBuffer } = await import(pathToFileURL(require.resolve('@open-pencil/fig')).href);
const bytes = readFileSync(archive);
const parsed = parseFigBuffer(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
const guid = (value) => value ? `${value.sessionID}:${value.localID}` : null;
console.log(JSON.stringify(parsed.nodeChanges.map((node) => ({
  guid: guid(node.guid), name: node.name, type: node.type, parent: guid(node.parentIndex?.guid)
}))));

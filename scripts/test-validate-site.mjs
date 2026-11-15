import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const validator = fileURLToPath(new URL('./validate-site.mjs', import.meta.url));

test('site validator checks expandable preview assets alongside ordinary links', async () => {
  const root = await mkdtemp(path.join(tmpdir(), 'noc-preview-validator-'));
  try {
    for (const relative of ['dist/assets/downloads', 'src/content/posts', 'docs/rebuild']) {
      await mkdir(path.join(root, relative), { recursive: true });
    }
    await writeFile(path.join(root, 'docs/rebuild/legacy-sitemap.xml'), '<urlset/>');
    await writeFile(path.join(root, 'dist/sitemap-0.xml'), '<urlset><url><loc>https://nocthoughts.com/</loc></url></urlset>');
    const page = '<link rel="canonical" href="https://nocthoughts.com/"><details data-code-preview="/assets/downloads/tool.txt"></details>';
    const index = path.join(root, 'dist/index.html');
    await writeFile(index, page);
    const run = () => {
      const result = spawnSync(process.execPath, [validator], { cwd: root, encoding: 'utf8' });
      assert.ifError(result.error);
      return result;
    };
    let result = run();
    assert.equal(result.status, 1);
    assert.match(result.stderr, /\/assets\/downloads\/tool\.txt/);
    await writeFile(path.join(root, 'dist/assets/downloads/tool.txt'), 'synthetic sample');
    result = run();
    assert.equal(result.status, 0, result.stderr);
    await writeFile(index, page + '<a href="/missing.txt">Download</a>');
    result = run();
    assert.equal(result.status, 1);
    assert.match(result.stderr, /\/missing\.txt/);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

/**
 * 宿主 UT 打包器：esbuild 把 ArkTS 纯函数链打包为 node ESM。
 * 关键：esbuild 对 .ets loader 文件内的裸包 import（@kit/*）不解析 node_modules——
 * 用 onResolve 插件直接把 @kit/* 映射到运行时桩（node_modules/@kit/<pkg>/index.js）。
 */
import { build } from 'esbuild';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '..', '..');
const KIT_STUBS = {
  '@kit.LocalizationKit': resolve(HERE, 'stubs/localization-kit.js'),
  '@kit.ArkData': resolve(HERE, 'stubs/ark-data.js'),
  '@kit.AbilityKit': resolve(HERE, 'stubs/ability-kit.js'),
  '@kit.NetworkKit': resolve(HERE, 'stubs/network-kit.js'),
  '@kit.ArkTS': resolve(HERE, 'stubs/arkts-util.js'),
  '@kit.ArkUI': resolve(HERE, 'stubs/ark-ui.js')
};

try {
  await build({
    entryPoints: [resolve(ROOT, 'scripts/ut/unit.test.ts')],
    bundle: true,
    platform: 'node',
    format: 'esm',
    target: 'node20',
    outfile: resolve(ROOT, '.ut/bundle.test.mjs'),
    loader: { '.ets': 'ts' },
    resolveExtensions: ['.ets', '.ts', '.js'],
    plugins: [{
      name: 'kit-stubs',
      setup(build) {
        for (const key of Object.keys(KIT_STUBS)) {
          build.onResolve({ filter: new RegExp('^' + key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '$') },
            () => ({ path: KIT_STUBS[key] }));
        }
      }
    }],
    banner: {
      // V2 状态装饰器在宿主无运行时：空实现桩（esbuild legacy 装饰器转译为顶层数组引用）
      js: 'var ObservedV2 = function () { }; var Trace = function () { };'
    }
  });
  console.log('UT bundle OK');
} catch (e) {
  const msg = (e.errors ?? []).map((err) => (err !== null && err !== undefined ? err.message : '')).join('; ');
  console.error('UT bundle FAILED: ' + msg);
  process.exit(1);
}

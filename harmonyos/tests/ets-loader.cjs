const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.env.FXW_TYPESCRIPT || 'D:/DevEco Studio/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript');
function loadEts(file, mocks = {}, cache = new Map()) {
  file = path.resolve(file);
  if (cache.has(file)) return cache.get(file).exports;
  const module = { exports: {} }; cache.set(file, module);
  const source = fs.readFileSync(file, 'utf8');
  const result = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, experimentalDecorators: true } });
  const req = name => {
    if (Object.prototype.hasOwnProperty.call(mocks, name)) return mocks[name];
    if (name.startsWith('.')) {
      let target = path.resolve(path.dirname(file), name);
      if (!path.extname(target)) target += '.ets';
      return loadEts(target, mocks, cache);
    }
    throw new Error('Unprovided platform dependency: ' + name);
  };
  vm.runInNewContext('(function(require,module,exports){' + result.outputText + '\n})', { console, setTimeout, clearTimeout, Date, Map, Set, Uint8Array, ArrayBuffer, Promise, Math, Error, JSON }, { filename: file })(req, module, module.exports);
  return module.exports;
}
module.exports = { loadEts };

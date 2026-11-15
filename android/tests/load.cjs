const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');
function storage() {
  const data = new Map();
  return { get length() { return data.size; }, key: i => [...data.keys()][i] ?? null,
    getItem: k => data.get(k) ?? null, setItem: (k,v) => data.set(k,String(v)), removeItem: k => data.delete(k), clear: () => data.clear() };
}
function load(entry, { mocks = {}, globals = {} } = {}) {
  const cache = new Map();
  const context = vm.createContext({ console, URL, TextEncoder, TextDecoder, Uint8Array, ArrayBuffer, Date,
    setTimeout, clearTimeout, AbortController, crypto: globalThis.crypto, atob, btoa,
    localStorage: storage(), navigator: { onLine: true, userAgent: 'test' }, ...globals });
  function read(file) {
    if (cache.has(file)) return cache.get(file).exports;
    const module = { exports: {} }; cache.set(file, module);
    const code = ts.transpileModule(fs.readFileSync(file,'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020, jsx: ts.JsxEmit.ReactJSX } }).outputText;
    const requireLocal = name => {
      if (Object.hasOwn(mocks, name)) return mocks[name];
      if (!name.startsWith('.')) return require(name);
      const base = path.resolve(path.dirname(file), name);
      const resolved = ['.ts','.tsx','.js'].map(ext => base+ext).find(fs.existsSync);
      return read(resolved || base);
    };
    vm.runInContext(`(function(require,module,exports){${code}\n})`, context, { filename: file })(requireLocal,module,module.exports);
    return module.exports;
  }
  return { exports: read(path.resolve(entry)), context, read: file => read(path.resolve(file)) };
}
module.exports = { load, storage };

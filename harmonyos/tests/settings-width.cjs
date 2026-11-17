const test = require('node:test');
const assert = require('node:assert/strict');
const { loadEts } = require('./ets-loader.cjs');
function fixture(saved) {
  let raw = JSON.stringify(saved);
  const preferences = { getPreferences: async () => ({
    get: async () => raw, put: async (_key, value) => { raw = value; }, flush: async () => {}
  }) };
  return loadEts('entry/src/main/ets/data/local/SettingsStore.ets', {
    '@ohos.data.preferences': { default: preferences }, '@ohos.app.ability.common': {}
  }).SettingsStore;
}
test('legacy card scale does not enable manual column mode', async () => {
  const store = fixture({cellHeight:72, blockWidthScale:1.25, showGhost:true});
  const settings = await store.load({});
  assert.equal(settings.cellWidth,0);
  assert.equal(settings.cellHeight,72);
  assert.equal(settings.showGhost,true);
});
test('manual column width preserves decimals after save and reload', async () => {
  const store = fixture({cellWidth:52.3,cellHeight:72});
  const settings = await store.load({});
  assert.equal(settings.cellWidth,52.3);
  settings.cellWidth=55;
  assert.equal(await store.save({},settings),true);
  store.invalidate();
  assert.equal((await store.load({})).cellWidth,55);
});
test('manual column widths are bounded and invalid values stay automatic', async () => {
  for (const [value,expected] of [[30,30],[90,55],[0,0],[-1,0],['55',0],[null,0]]) {
    assert.equal((await fixture({cellWidth:value}).load({})).cellWidth,expected);
  }
});

test('adaptive width ratio survives reload and crosses larger screens without a 55vp ceiling', async () => {
  const store=fixture({cellWidthRatio:0.9});
  const settings=await store.load({});
  assert.equal(settings.cellWidthRatio,0.9);
  await store.save({},settings); store.invalidate();
  assert.equal((await store.load({})).cellWidthRatio,0.9);
  const {effectiveWidth}=loadEts('entry/src/main/ets/common/util/CellWidth.ets');
  assert.equal(effectiveWidth(50,0.9,55),45);
  assert.equal(effectiveWidth(80,0.9,55),72);
  assert.equal(effectiveWidth(40,0,55),40);
  assert.equal(effectiveWidth(40,0,10),32);
});
test('narrow cards wrap every room digit and reserve at least two room lines in a double period', () => {
  const {wrappedLineCount,courseNameLines}=loadEts('entry/src/main/ets/common/util/CourseTextLayout.ets');
  assert.equal(wrappedLineCount([15,9,9,9,9],30),2);
  assert.equal(wrappedLineCount([15,9,9,9,9],23),3);
  assert.equal(courseNameLines(76,2),1);
  assert.equal(courseNameLines(140,3),4);
});

test('classroom code keeps the final three room digits on the second line', () => {
  const {fixedRoomCode,wrappedLineCount}=loadEts('entry/src/main/ets/common/util/CourseTextLayout.ets');
  assert.equal(fixedRoomCode('教5404'),'教5\n404');
  assert.equal(fixedRoomCode('实3401'),'实3\n401');
  assert.equal(fixedRoomCode('教5-103'),'教5\n103');
  assert.equal(fixedRoomCode('操场'),'操场');
  assert.equal(wrappedLineCount([15,9,-1,9,9,9],30),2);
});

const assert=require('node:assert/strict');const path=require('node:path');
const {loadEts}=require('./ets-loader.cjs');
let raw='';let mode='limited';let uploads=[];let deleted=[];let packed=[];let releases=0;let decodeFails=false;let oversize=true;let releaseUpload;
const pref={async get(){return raw;},async put(k,v){raw=v;},async flush(){},async clear(){raw='';}};
const mocks={
 '@ohos.app.ability.common':{default:{}},
 '@ohos.data.preferences':{default:{async getPreferences(){return pref;}}},
 '@ohos.file.fs':{default:{OpenMode:{READ_ONLY:0},openSync(){return{fd:1};},closeSync(){},unlinkSync(p){deleted.push(p);}}},
 '@ohos.multimedia.image':{default:{createImageSource(){return{async getImageInfo(){if(decodeFails)throw new Error('bad image');return{size:{width:4000,height:3000}};},async createPixelMap(o){assert.ok(o.desiredSize.width<=1600);return{async release(){releases++;}};},async release(){releases++;}};},createImagePacker(){return{async packing(p,o){packed.push(o);return new ArrayBuffer(oversize&&o.quality>65?900001:24);},async release(){releases++;}};}}},
 '@ohos.util':{default:{Base64Helper:class{encodeToStringSync(b){return Buffer.from(b).toString('base64');}}}},
 '@ohos.security.cryptoFramework':{default:{createRandom(){return{generateRandomSync(n){return{data:new Uint8Array(require('node:crypto').randomBytes(n))};}};}}},
 './ShareApi':{async uploadFeedback(p){uploads.push(p);if(mode==='limited')throw new Error('TOO_FREQUENT:60');if(mode==='fail')throw new Error('offline');if(mode==='hold')await new Promise(r=>releaseUpload=r);return 'id';}}
};
const cache=new Map();const {FeedbackStore}=loadEts('entry/src/main/ets/data/local/FeedbackStore.ets',mocks,cache);
const {FeedbackDelivery,encodeFeedbackImage,newFeedbackId}=loadEts('entry/src/main/ets/data/remote/FeedbackDelivery.ets',mocks,cache);
const feedback=id=>({id,text:'problem',contact:'contact',images:['file:///cache/fb_1_0.jpg'],createdAt:1,sent:false});
(async()=>{
 assert.notEqual(newFeedbackId(),newFeedbackId());const image=await encodeFeedbackImage('file:///cache/fb_1_0.jpg');assert.ok(image.startsWith('data:image/jpeg;base64,'));assert.ok(packed.every(p=>p.format==='image/jpeg'));assert.ok(releases>=3);
 const f=feedback('stable');await FeedbackStore.push({},f);assert.equal(await FeedbackDelivery.send({},f),'limited');let pending=await FeedbackStore.pending({});assert.equal(pending.length,1);assert.ok(pending[0].retryAt>Date.now());assert.equal(pending[0].sent,false);assert.equal(deleted.length,0);assert.equal(uploads[0].requestId,'stable');
 await FeedbackDelivery.flush({});assert.equal(uploads.length,1);
 await FeedbackStore.defer({},f.id,0);mode='ok';await FeedbackDelivery.flush({});assert.equal((await FeedbackStore.pending({})).length,0);assert.equal(deleted.length,1);assert.equal(uploads[1].requestId,'stable');
 await FeedbackStore.push({},feedback('next'));await FeedbackStore.push({},feedback('last'));mode='limited';const before=uploads.length;await FeedbackDelivery.flush({});assert.equal(uploads.length,before+1);assert.equal((await FeedbackStore.pending({})).length,2);
 await FeedbackStore.clear({});const broken=feedback('broken');await FeedbackStore.push({},broken);decodeFails=true;assert.equal(await FeedbackDelivery.send({},broken),'image');assert.equal((await FeedbackStore.pending({})).length,1);assert.equal(deleted.length,1);
 await FeedbackStore.clear({});decodeFails=false;mode='hold';const a=feedback('queuedA'),b=feedback('queuedB');await FeedbackStore.push({},a);await FeedbackStore.push({},b);const sentBefore=uploads.length;const first=FeedbackDelivery.send({},a);const second=FeedbackDelivery.send({},b);await new Promise(r=>setTimeout(r,10));await FeedbackStore.clear({});mode='ok';releaseUpload();await first;await second;assert.equal(uploads.length,sentBefore+1,'cleared queued feedback must never upload');
 console.log('feedback 429 persistence, due filtering, stable IDs, image encoding and cleanup passed');
})().catch(e=>{console.error(e);process.exitCode=1;});

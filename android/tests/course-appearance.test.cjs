const {test}=require('node:test'),assert=require('node:assert/strict'),{load}=require('./load.cjs');
test('randomized palette keeps geometric neighbors different and a session seed stable',()=>{
 const a=load('src/core/courseAppearance.ts').exports,nodes=[];
 for(let day=1;day<=7;day++)for(let start=1;start<=9;start+=2)nodes.push({day,start,end:start+1,col:0,cols:1});
 nodes.push({day:3,start:1,end:8,col:0,cols:2},{day:3,start:1,end:4,col:1,cols:2});
 for(let seed=1;seed<=20;seed++){
  const colors=a.assignCourseColors(nodes,seed);
  assert.deepEqual(colors,a.assignCourseColors(nodes,seed));
  for(let i=0;i<nodes.length;i++)for(let j=i+1;j<nodes.length;j++)if(a.neighboringCourses(nodes,i,j))assert.notEqual(colors[i],colors[j]);
 }
 assert.notDeepEqual(a.assignCourseColors(nodes,1),a.assignCourseColors(nodes,2));
});
test('adjacency includes long side neighbors and nearest separated blocks but excludes remote cells',()=>{
 const a=load('src/core/courseAppearance.ts').exports;
 const nodes=[{day:1,start:1,end:8,col:0,cols:1},{day:2,start:3,end:4,col:0,cols:1},{day:2,start:7,end:8,col:0,cols:1},{day:4,start:3,end:4,col:0,cols:1}];
 assert.equal(a.neighboringCourses(nodes,0,1),true);assert.equal(a.neighboringCourses(nodes,0,2),true);assert.equal(a.neighboringCourses(nodes,1,2),true);assert.equal(a.neighboringCourses(nodes,0,3),false);
});


test('weekday first-course defaults are fixed and manual choices survive coloring for every seed',()=>{
 const a=load('src/core/courseAppearance.ts').exports;
 const defaults=[0,1,2,6,4];
 const nodes=defaults.map((c,i)=>({day:i+1,start:1,end:2,col:0,cols:1,pinnedColor:a.preferredCourseColor({weekday:i+1,colorIndex:7},true)}));
 for(let i=0;i<5;i++)assert.equal(nodes[i].pinnedColor,defaults[i]);
 assert.equal(a.preferredCourseColor({weekday:1,colorIndex:5,colorOverride:true},true),5);
 assert.equal(a.preferredCourseColor({weekday:1,colorIndex:5},false),undefined);
 assert.equal(a.preferredCourseColor({weekday:6,colorIndex:5},true),undefined);
 for(let seed=1;seed<=20;seed++){const colors=a.assignCourseColors(nodes,seed);for(let i=0;i<5;i++)assert.equal(colors[i],a.COURSE_PALETTE[defaults[i]]);}
 nodes[0].pinnedColor=5;
 assert.equal(a.assignCourseColors(nodes,9)[0],a.COURSE_PALETTE[5]);
});
test('manual color flag persists validation and cannot select outside the actual eight-color palette',()=>{
 const v=load('src/core/validation.ts').exports;
 const c={id:'test',name:'测试课程',weekday:1,startPeriod:1,endPeriod:2,weeks:[1],colorIndex:6,colorOverride:true};
 assert.equal(v.validateCourses([c])[0].colorOverride,true);
 assert.equal(v.validateCourses([c])[0].colorIndex,6);
 assert.throws(()=>v.validateCourses([{...c,colorIndex:8}]));
 assert.throws(()=>v.validateCourses([{...c,colorOverride:'true'}]));
 assert.equal(v.validateCourses([{...c,colorOverride:undefined}])[0].colorOverride,undefined);
});

test('automatic colors are allocated once for the complete table and reused without randomness',()=>{
 const a=load('src/core/courseAppearance.ts').exports;
 const course=(id,weekday,startPeriod,weeks)=>({id,name:id,teacher:'',room:'教5-103',campus:'',weekday,startPeriod,endPeriod:startPeriod+1,weeks,colorIndex:0});
 const list=[course('first',1,1,[1]),course('later',1,3,[1,2]),course('tuesday',2,1,[1,2])];
 const frozen=a.freezeCourseColors(list,9);
 assert.ok(frozen.every(c=>Number.isInteger(c.autoColorIndex)));
 assert.equal(frozen[0].autoColorIndex,0);assert.equal(frozen[2].autoColorIndex,1);
 assert.equal(a.freezeCourseColors(frozen,999),frozen);
 const later=frozen.find(c=>c.id==='later');
 assert.equal(a.storedCourseColor(later),a.storedCourseColor({...later,weeks:[2]}));
 const grown=a.freezeCourseColors([...frozen,course('new',3,5,[1,2])],88);
 frozen.forEach((c,i)=>assert.equal(grown[i].autoColorIndex,c.autoColorIndex));
 assert.equal(a.storedCourseColor({...later,colorOverride:true,colorIndex:5}),a.COURSE_PALETTE[5]);
});

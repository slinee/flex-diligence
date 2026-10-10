import test from 'node:test'; import assert from 'node:assert/strict'; import {validateFiles,extensions} from './validation';
test('accepts the twelve supported formats',()=>{for(const ext of extensions)assert.equal(validateFiles([{name:`file.${ext}`,size:100}]),null)});
test('rejects excess count, unsupported format and oversized files',()=>{assert.match(validateFiles([{name:'a.pdf',size:100}],15)!,/15/);assert.match(validateFiles([{name:'a.exe',size:100}])!,/unsupported/);assert.match(validateFiles([{name:'a.pdf',size:11*1024*1024}])!,/10 MB/);assert.match(validateFiles([{name:'a.pdf',size:0}])!,/empty/)});
test('rejects aggregate size and malformed metadata',()=>{assert.match(validateFiles(Array.from({length:5},()=>({name:'a.pdf',size:9*1024*1024})))!,/40 MB/);assert.match(validateFiles([{name:'a.pdf',size:-1}])!,/Invalid/);assert.match(validateFiles([{name:'a.pdf',size:NaN}])!,/Invalid/);});

test('rejects malformed arrays safely',()=>{for(const value of [null,{},[null],[42],[{}]])assert.ok(validateFiles(value));});

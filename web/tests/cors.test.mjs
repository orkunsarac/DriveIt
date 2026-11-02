import test from 'node:test'
import assert from 'node:assert/strict'
import { withCors } from '../server-proposal/cors.mjs'
const endpoint='https://arwnbogcswisfesayosy.supabase.co/functions/v1/delete-account'
const handler=withCors(async () => new Response('{"state":"pending"}',{status:202,headers:{'cache-control':'no-store'}}),'https://drive.example')
test('exact approved origin receives preflight and response headers',async()=>{const pre=await handler(new Request(endpoint,{method:'OPTIONS',headers:{origin:'https://drive.example'}}));assert.equal(pre.status,204);assert.equal(pre.headers.get('access-control-allow-origin'),'https://drive.example');const post=await handler(new Request(endpoint,{method:'POST',headers:{origin:'https://drive.example'}}));assert.equal(post.status,202);assert.equal(post.headers.get('cache-control'),'no-store')})
test('other origins and deceptive subdomains are rejected',async()=>{for(const origin of ['https://evil.example','https://drive.example.evil.test','null'])assert.equal((await handler(new Request(endpoint,{method:'POST',headers:{origin}}))).status,403)})
test('native request passes without CORS headers',async()=>{const res=await handler(new Request(endpoint,{method:'POST'}));assert.equal(res.status,202);assert.equal(res.headers.get('access-control-allow-origin'),null)})
test('empty or insecure origin configuration stays closed',async()=>{for(const value of ['', 'http://drive.example','https://drive.example/path']){const fn=withCors(async()=>new Response(),value);assert.equal((await fn(new Request(endpoint,{headers:{origin:'https://drive.example'}}))).status,403)}})

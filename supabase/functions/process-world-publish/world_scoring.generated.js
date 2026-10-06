(function dartProgram(){function copyProperties(a,b){var s=Object.keys(a)
for(var r=0;r<s.length;r++){var q=s[r]
b[q]=a[q]}}function mixinPropertiesHard(a,b){var s=Object.keys(a)
for(var r=0;r<s.length;r++){var q=s[r]
if(!b.hasOwnProperty(q)){b[q]=a[q]}}}function mixinPropertiesEasy(a,b){Object.assign(b,a)}var z=function(){var s=function(){}
s.prototype={p:{}}
var r=new s()
if(!(Object.getPrototypeOf(r)&&Object.getPrototypeOf(r).p===s.prototype.p))return false
try{if(typeof navigator!="undefined"&&typeof navigator.userAgent=="string"&&navigator.userAgent.indexOf("Chrome/")>=0)return true
if(typeof version=="function"&&version.length==0){var q=version()
if(/^\d+\.\d+\.\d+\.\d+$/.test(q))return true}}catch(p){}return false}()
function inherit(a,b){a.prototype.constructor=a
a.prototype["$i"+a.name]=a
if(b!=null){if(z){Object.setPrototypeOf(a.prototype,b.prototype)
return}var s=Object.create(b.prototype)
copyProperties(a.prototype,s)
a.prototype=s}}function inheritMany(a,b){for(var s=0;s<b.length;s++){inherit(b[s],a)}}function mixinEasy(a,b){mixinPropertiesEasy(b.prototype,a.prototype)
a.prototype.constructor=a}function mixinHard(a,b){mixinPropertiesHard(b.prototype,a.prototype)
a.prototype.constructor=a}function lazy(a,b,c,d){var s=a
a[b]=s
a[c]=function(){if(a[b]===s){a[b]=d()}a[c]=function(){return this[b]}
return a[b]}}function lazyFinal(a,b,c,d){var s=a
a[b]=s
a[c]=function(){if(a[b]===s){var r=d()
if(a[b]!==s){A.jB(b)}a[b]=r}var q=a[b]
a[c]=function(){return q}
return q}}function makeConstList(a,b){if(b!=null)A.o(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var s=0;s<a.length;++s){convertToFastObject(a[s])}}var y=0
function instanceTearOffGetter(a,b){var s=null
return a?function(c){if(s===null)s=A.fl(b)
return new s(c,this)}:function(){if(s===null)s=A.fl(b)
return new s(this,null)}}function staticTearOffGetter(a){var s=null
return function(){if(s===null)s=A.fl(a).prototype
return s}}var x=0
function tearOffParameters(a,b,c,d,e,f,g,h,i,j){if(typeof h=="number"){h+=x}return{co:a,iS:b,iI:c,rC:d,dV:e,cs:f,fs:g,fT:h,aI:i||0,nDA:j}}function installStaticTearOff(a,b,c,d,e,f,g,h){var s=tearOffParameters(a,true,false,c,d,e,f,g,h,false)
var r=staticTearOffGetter(s)
a[b]=r}function installInstanceTearOff(a,b,c,d,e,f,g,h,i,j){c=!!c
var s=tearOffParameters(a,false,c,d,e,f,g,h,i,!!j)
var r=instanceTearOffGetter(c,s)
a[b]=r}function setOrUpdateInterceptorsByTag(a){var s=v.interceptorsByTag
if(!s){v.interceptorsByTag=a
return}copyProperties(a,s)}function setOrUpdateLeafTags(a){var s=v.leafTags
if(!s){v.leafTags=a
return}copyProperties(a,s)}function updateTypes(a){var s=v.types
var r=s.length
s.push.apply(s,a)
return r}function updateHolder(a,b){copyProperties(b,a)
return a}var hunkHelpers=function(){var s=function(a,b,c,d,e){return function(f,g,h,i){return installInstanceTearOff(f,g,a,b,c,d,[h],i,e,false)}},r=function(a,b,c,d){return function(e,f,g,h){return installStaticTearOff(e,f,a,b,c,[g],h,d)}}
return{inherit:inherit,inheritMany:inheritMany,mixin:mixinEasy,mixinHard:mixinHard,installStaticTearOff:installStaticTearOff,installInstanceTearOff:installInstanceTearOff,_instance_0u:s(0,0,null,["$0"],0),_instance_1u:s(0,1,null,["$1"],0),_instance_2u:s(0,2,null,["$2"],0),_instance_0i:s(1,0,null,["$0"],0),_instance_1i:s(1,1,null,["$1"],0),_instance_2i:s(1,2,null,["$2"],0),_static_0:r(0,null,["$0"],0),_static_1:r(1,null,["$1"],0),_static_2:r(2,null,["$2"],0),makeConstList:makeConstList,lazy:lazy,lazyFinal:lazyFinal,updateHolder:updateHolder,convertToFastObject:convertToFastObject,updateTypes:updateTypes,setOrUpdateInterceptorsByTag:setOrUpdateInterceptorsByTag,setOrUpdateLeafTags:setOrUpdateLeafTags}}()
function initializeDeferredHunk(a){x=v.types.length
a(hunkHelpers,v,w,$)}var J={
fG(a,b){if(a<0||a>4294967295)throw A.d(A.a8(a,0,4294967295,"length",null))
return J.e9(new Array(a),b)},
e9(a,b){var s=A.o(a,b.h("n<0>"))
s.$flags=1
return s},
i2(a,b){var s=t.e8
return J.hL(s.a(a),s.a(b))},
aP(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.bk.prototype
return J.ch.prototype}if(typeof a=="string")return J.aH.prototype
if(a==null)return J.bl.prototype
if(typeof a=="boolean")return J.cg.prototype
if(Array.isArray(a))return J.n.prototype
if(typeof a=="function")return J.bm.prototype
if(typeof a=="object"){if(a instanceof A.j){return a}else{return J.b_.prototype}}if(!(a instanceof A.j))return J.ay.prototype
return a},
bS(a){if(a==null)return a
if(Array.isArray(a))return J.n.prototype
if(!(a instanceof A.j))return J.ay.prototype
return a},
cB(a){if(typeof a=="string")return J.aH.prototype
if(a==null)return a
if(Array.isArray(a))return J.n.prototype
if(!(a instanceof A.j))return J.ay.prototype
return a},
js(a){if(typeof a=="number")return J.aY.prototype
if(typeof a=="string")return J.aH.prototype
if(a==null)return a
if(!(a instanceof A.j))return J.ay.prototype
return a},
cE(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.aP(a).M(a,b)},
hL(a,b){return J.js(a).E(a,b)},
fq(a,b){return J.bS(a).C(a,b)},
b9(a){return J.aP(a).gB(a)},
fr(a){return J.cB(a).gv(a)},
hM(a){return J.bS(a).gX(a)},
a2(a){return J.bS(a).gq(a)},
aD(a){return J.cB(a).gl(a)},
hN(a){return J.aP(a).gS(a)},
cF(a,b,c){return J.bS(a).aT(a,b,c)},
fs(a,b){return J.bS(a).K(a,b)},
aT(a){return J.aP(a).k(a)},
ce:function ce(){},
cg:function cg(){},
bl:function bl(){},
b_:function b_(){},
aw:function aw(){},
en:function en(){},
ay:function ay(){},
bm:function bm(){},
n:function n(a){this.$ti=a},
cf:function cf(){},
ea:function ea(a){this.$ti=a},
aE:function aE(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aY:function aY(){},
bk:function bk(){},
ch:function ch(){},
aH:function aH(){}},A={fb:function fb(){},
fx(a,b,c){if(t.O.b(a))return new A.bK(a,b.h("@<0>").t(c).h("bK<1,2>"))
return new A.aF(a,b.h("@<0>").t(c).h("aF<1,2>"))},
h_(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
ig(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
ho(a,b,c){return a},
fn(a){var s,r
for(s=$.V.length,r=0;r<s;++r)if(a===$.V[r])return!0
return!1},
ep(a,b,c,d){A.an(b,"start")
if(c!=null){A.an(c,"end")
if(b>c)A.aS(A.a8(b,0,c,"start",null))}return new A.bD(a,b,c,d.h("bD<0>"))},
i8(a,b,c,d){if(t.O.b(a))return new A.bf(a,b,c.h("@<0>").t(d).h("bf<1,2>"))
return new A.am(a,b,c.h("@<0>").t(d).h("am<1,2>"))},
fY(a,b,c){var s="count"
if(t.O.b(a)){A.cU(b,s,t.S)
A.an(b,s)
return new A.aV(a,b,c.h("aV<0>"))}A.cU(b,s,t.S)
A.an(b,s)
return new A.ao(a,b,c.h("ao<0>"))},
aX(){return new A.bC("No element")},
i0(){return new A.bC("Too few elements")},
b4:function b4(){},
ba:function ba(a,b){this.a=a
this.$ti=b},
aF:function aF(a,b){this.a=a
this.$ti=b},
bK:function bK(a,b){this.a=a
this.$ti=b},
cl:function cl(a){this.a=a},
eo:function eo(){},
p:function p(){},
q:function q(){},
bD:function bD(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
bs:function bs(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
am:function am(a,b,c){this.a=a
this.b=b
this.$ti=c},
bf:function bf(a,b,c){this.a=a
this.b=b
this.$ti=c},
bw:function bw(a,b,c){var _=this
_.a=null
_.b=a
_.c=b
_.$ti=c},
f:function f(a,b,c){this.a=a
this.b=b
this.$ti=c},
z:function z(a,b,c){this.a=a
this.b=b
this.$ti=c},
a0:function a0(a,b,c){this.a=a
this.b=b
this.$ti=c},
bi:function bi(a,b,c){this.a=a
this.b=b
this.$ti=c},
bj:function bj(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
ao:function ao(a,b,c){this.a=a
this.b=b
this.$ti=c},
aV:function aV(a,b,c){this.a=a
this.b=b
this.$ti=c},
bA:function bA(a,b,c){this.a=a
this.b=b
this.$ti=c},
bg:function bg(a){this.$ti=a},
bh:function bh(a){this.$ti=a},
fA(a,b,c){var s,r,q,p,o,n,m,l=A.i(a),k=A.fd(new A.ak(a,l.h("ak<1>")),!0,b),j=k.length,i=0
for(;;){if(!(i<j)){s=!0
break}r=k[i]
if(typeof r!="string"||"__proto__"===r){s=!1
break}++i}if(s){q={}
for(p=0,i=0;i<k.length;k.length===j||(0,A.ab)(k),++i,p=o){r=k[i]
c.a(a.i(0,r))
o=p+1
q[r]=p}n=A.fd(new A.al(a,l.h("al<2>")),!0,c)
m=new A.af(q,n,b.h("@<0>").t(c).h("af<1,2>"))
m.$keys=k
return m}return new A.bd(A.i4(a,b,c),b.h("@<0>").t(c).h("bd<1,2>"))},
hw(a){var s=v.mangledGlobalNames[a]
if(s!=null)return s
return"minified:"+a},
x(a){var s
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
s=J.aT(a)
return s},
co(a){var s,r=$.fO
if(r==null)r=$.fO=Symbol("identityHashCode")
s=a[r]
if(s==null){s=Math.random()*0x3fffffff|0
a[r]=s}return s},
i9(a,b){var s,r=/^\s*[+-]?((0x[a-f0-9]+)|(\d+)|([a-z0-9]+))\s*$/i.exec(a)
if(r==null)return null
if(3>=r.length)return A.b(r,3)
s=r[3]
if(s!=null)return parseInt(a,10)
if(r[2]!=null)return parseInt(a,16)
return null},
cp(a){var s,r,q,p
if(a instanceof A.j)return A.M(A.bT(a),null)
s=J.aP(a)
if(s===B.au||s===B.av||t.ak.b(a)){r=B.a2(a)
if(r!=="Object"&&r!=="")return r
q=a.constructor
if(typeof q=="function"){p=q.name
if(typeof p=="string"&&p!=="Object"&&p!=="")return p}}return A.M(A.bT(a),null)},
ia(a){var s,r,q
if(typeof a=="number"||A.fk(a))return J.aT(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.K)return a.k(0)
s=$.hK()
for(r=0;r<1;++r){q=s[r].c5(a)
if(q!=null)return q}return"Instance of '"+A.cp(a)+"'"},
H(a){var s
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){s=a-65536
return String.fromCharCode((B.c.aK(s,10)|55296)>>>0,s&1023|56320)}throw A.d(A.a8(a,0,1114111,null,null))},
fV(a,b,c,d,e,f,g,h,i){var s,r,q,p=b-1
if(0<=a&&a<100){a+=400
p-=4800}s=B.c.T(h,1000)
g+=B.c.A(h-s,1000)
r=i?Date.UTC(a,p,c,d,e,f,g):new Date(a,p,c,d,e,f,g).valueOf()
q=!0
if(!isNaN(r))if(!(r<-864e13))if(!(r>864e13))q=r===864e13&&s!==0
if(q)return null
return r},
S(a){if(a.date===void 0)a.date=new Date(a.a)
return a.date},
cn(a){return a.c?A.S(a).getUTCFullYear()+0:A.S(a).getFullYear()+0},
fT(a){return a.c?A.S(a).getUTCMonth()+1:A.S(a).getMonth()+1},
fP(a){return a.c?A.S(a).getUTCDate()+0:A.S(a).getDate()+0},
fQ(a){return a.c?A.S(a).getUTCHours()+0:A.S(a).getHours()+0},
fS(a){return a.c?A.S(a).getUTCMinutes()+0:A.S(a).getMinutes()+0},
fU(a){return a.c?A.S(a).getUTCSeconds()+0:A.S(a).getSeconds()+0},
fR(a){return a.c?A.S(a).getUTCMilliseconds()+0:A.S(a).getMilliseconds()+0},
jv(a){throw A.d(A.hn(a))},
b(a,b){if(a==null)J.aD(a)
throw A.d(A.eX(a,b))},
eX(a,b){var s,r="index",q=null
if(!A.hj(b))return new A.ac(!0,b,r,q)
s=J.aD(a)
if(b<0||b>=s)return A.e7(b,s,a,q,r)
return new A.by(q,q,!0,b,r,"Value not in range")},
hn(a){return new A.ac(!0,a,null,null)},
d(a){return A.F(a,new Error())},
F(a,b){var s
if(a==null)a=new A.bG()
b.dartException=a
s=A.jC
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:s})
b.name=""}else b.toString=s
return b},
jC(){return J.aT(this.dartException)},
aS(a,b){throw A.F(a,b==null?new Error():b)},
cD(a,b,c){var s
if(b==null)b=0
if(c==null)c=0
s=Error()
A.aS(A.iO(a,b,c),s)},
iO(a,b,c){var s,r,q,p,o,n,m,l,k
if(typeof b=="string")s=b
else{r="[]=;add;removeWhere;retainWhere;removeRange;setRange;setInt8;setInt16;setInt32;setUint8;setUint16;setUint32;setFloat32;setFloat64".split(";")
q=r.length
p=b
if(p>q){c=p/q|0
p%=q}s=r[p]}o=typeof c=="string"?c:"modify;remove from;add to".split(";")[c]
n=t.j.b(a)?"list":"ByteData"
m=a.$flags|0
l="a "
if((m&4)!==0)k="constant "
else if((m&2)!==0){k="unmodifiable "
l="an "}else k=(m&1)!==0?"fixed-length ":""
return new A.bJ("'"+s+"': Cannot "+o+" "+l+k+n)},
ab(a){throw A.d(A.N(a))},
ar(a){var s,r,q,p,o,n
a=A.jA(a.replace(String({}),"$receiver$"))
s=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(s==null)s=A.o([],t.s)
r=s.indexOf("\\$arguments\\$")
q=s.indexOf("\\$argumentsExpr\\$")
p=s.indexOf("\\$expr\\$")
o=s.indexOf("\\$method\\$")
n=s.indexOf("\\$receiver\\$")
return new A.eA(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),r,q,p,o,n)},
eB(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(s){return s.message}}(a)},
h0(a){return function($expr$){try{$expr$.$method$}catch(s){return s.message}}(a)},
fc(a,b){var s=b==null,r=s?null:b.method
return new A.cj(a,r,s?null:b.receiver)},
fo(a){if(a==null)return new A.em(a)
if(typeof a!=="object")return a
if("dartException" in a)return A.aR(a,a.dartException)
return A.jh(a)},
aR(a,b){if(t.bU.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
jh(a){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(!("message" in a))return a
s=a.message
if("number" in a&&typeof a.number=="number"){r=a.number
q=r&65535
if((B.c.aK(r,16)&8191)===10)switch(q){case 438:return A.aR(a,A.fc(A.x(s)+" (Error "+q+")",null))
case 445:case 5007:A.x(s)
return A.aR(a,new A.bx())}}if(a instanceof TypeError){p=$.hz()
o=$.hA()
n=$.hB()
m=$.hC()
l=$.hF()
k=$.hG()
j=$.hE()
$.hD()
i=$.hI()
h=$.hH()
g=p.I(s)
if(g!=null)return A.aR(a,A.fc(A.B(s),g))
else{g=o.I(s)
if(g!=null){g.method="call"
return A.aR(a,A.fc(A.B(s),g))}else if(n.I(s)!=null||m.I(s)!=null||l.I(s)!=null||k.I(s)!=null||j.I(s)!=null||m.I(s)!=null||i.I(s)!=null||h.I(s)!=null){A.B(s)
return A.aR(a,new A.bx())}}return A.aR(a,new A.cu(typeof s=="string"?s:""))}if(a instanceof RangeError){if(typeof s=="string"&&s.indexOf("call stack")!==-1)return new A.bB()
s=function(b){try{return String(b)}catch(f){}return null}(a)
return A.aR(a,new A.ac(!1,null,null,typeof s=="string"?s.replace(/^RangeError:\s*/,""):s))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof s=="string"&&s==="too much recursion")return new A.bB()
return a},
hu(a){if(a==null)return J.b9(a)
if(typeof a=="object")return A.co(a)
return J.b9(a)},
jq(a,b){var s,r,q,p=a.length
for(s=0;s<p;s=q){r=s+1
q=r+1
b.u(0,a[s],a[r])}return b},
jr(a,b){var s,r=a.length
for(s=0;s<r;++s)b.m(0,a[s])
return b},
iY(a,b,c,d,e,f){t.Z.a(a)
switch(A.aa(b)){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.d(new A.eF("Unsupported number of arguments for wrapped closure"))},
jk(a,b){var s=a.$identity
if(!!s)return s
s=A.jl(a,b)
a.$identity=s
return s},
jl(a,b){var s
switch(b){case 0:s=a.$0
break
case 1:s=a.$1
break
case 2:s=a.$2
break
case 3:s=a.$3
break
case 4:s=a.$4
break
default:s=null}if(s!=null)return s.bind(a)
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.iY)},
hW(a2){var s,r,q,p,o,n,m,l,k,j,i=a2.co,h=a2.iS,g=a2.iI,f=a2.nDA,e=a2.aI,d=a2.fs,c=a2.cs,b=d[0],a=c[0],a0=i[b],a1=a2.fT
a1.toString
s=h?Object.create(new A.cr().constructor.prototype):Object.create(new A.aU(null,null).constructor.prototype)
s.$initialize=s.constructor
r=h?function static_tear_off(){this.$initialize()}:function tear_off(a3,a4){this.$initialize(a3,a4)}
s.constructor=r
r.prototype=s
s.$_name=b
s.$_target=a0
q=!h
if(q)p=A.fy(b,a0,g,f)
else{s.$static_name=b
p=a0}s.$S=A.hS(a1,h,g)
s[a]=p
for(o=p,n=1;n<d.length;++n){m=d[n]
if(typeof m=="string"){l=i[m]
k=m
m=l}else k=""
j=c[n]
if(j!=null){if(q)m=A.fy(k,m,g,f)
s[j]=m}if(n===e)o=m}s.$C=o
s.$R=a2.rC
s.$D=a2.dV
return r},
hS(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.d("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.hQ)}throw A.d("Error in functionType of tearoff")},
hT(a,b,c,d){var s=A.fw
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,s)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,s)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,s)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,s)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,s)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,s)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,s)}},
fy(a,b,c,d){if(c)return A.hV(a,b,d)
return A.hT(b.length,d,a,b)},
hU(a,b,c,d){var s=A.fw,r=A.hR
switch(b?-1:a){case 0:throw A.d(new A.cq("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,r,s)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,r,s)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,r,s)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,r,s)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,r,s)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,r,s)
default:return function(e,f,g){return function(){var q=[g(this)]
Array.prototype.push.apply(q,arguments)
return e.apply(f(this),q)}}(d,r,s)}},
hV(a,b,c){var s,r
if($.fu==null)$.fu=A.ft("interceptor")
if($.fv==null)$.fv=A.ft("receiver")
s=b.length
r=A.hU(s,c,a,b)
return r},
fl(a){return A.hW(a)},
hQ(a,b){return A.eN(v.typeUniverse,A.bT(a.a),b)},
fw(a){return a.a},
hR(a){return a.b},
ft(a){var s,r,q,p=new A.aU("receiver","interceptor"),o=Object.getOwnPropertyNames(p)
o.$flags=1
s=o
for(o=s.length,r=0;r<o;++r){q=s[r]
if(p[q]===a)return q}throw A.d(A.f9("Field name "+a+" not found."))},
hr(a){return v.getIsolateTag(a)},
jn(a,b){var s=b.length,r=v.rttc[""+s+";"+a]
if(r==null)return null
if(s===0)return r
if(s===r.length)return r.apply(null,b)
return r(b)},
i3(a,b,c,d,e,f){var s=function(g,h){try{return new RegExp(g,h)}catch(r){return r}}(a,""+""+""+""+f)
if(s instanceof RegExp)return s
throw A.d(A.ca("Illegal RegExp pattern ("+String(s)+")",a))},
jA(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
bd:function bd(a,b){this.a=a
this.$ti=b},
bc:function bc(){},
di:function di(a,b,c){this.a=a
this.b=b
this.c=c},
af:function af(a,b,c){this.a=a
this.b=b
this.$ti=c},
cc:function cc(){},
aW:function aW(a,b){this.a=a
this.$ti=b},
bz:function bz(){},
eA:function eA(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
bx:function bx(){},
cj:function cj(a,b,c){this.a=a
this.b=b
this.c=c},
cu:function cu(a){this.a=a},
em:function em(a){this.a=a},
K:function K(){},
bY:function bY(){},
bZ:function bZ(){},
cs:function cs(){},
cr:function cr(){},
aU:function aU(a,b){this.a=a
this.b=b},
cq:function cq(a){this.a=a},
aj:function aj(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
eb:function eb(a){this.a=a},
ef:function ef(a,b){this.a=a
this.b=b
this.c=null},
ak:function ak(a,b){this.a=a
this.$ti=b},
bq:function bq(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
al:function al(a,b){this.a=a
this.$ti=b},
br:function br(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
bo:function bo(a,b){this.a=a
this.$ti=b},
bp:function bp(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
ci:function ci(a,b){this.a=a
this.b=b},
eK:function eK(a){this.b=a},
fe(a,b){var s=b.c
return s==null?b.c=A.bO(a,"fE",[b.x]):s},
fX(a){var s=a.w
if(s===6||s===7)return A.fX(a.x)
return s===11||s===12},
id(a){return a.as},
aC(a){return A.eM(v.typeUniverse,a,!1)},
jx(a,b){var s,r,q,p,o
if(a==null)return null
s=b.y
r=a.Q
if(r==null)r=a.Q=new Map()
q=b.as
p=r.get(q)
if(p!=null)return p
o=A.aB(v.typeUniverse,a.x,s,0)
r.set(q,o)
return o},
aB(a1,a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=a2.w
switch(a0){case 5:case 1:case 2:case 3:case 4:return a2
case 6:s=a2.x
r=A.aB(a1,s,a3,a4)
if(r===s)return a2
return A.h9(a1,r,!0)
case 7:s=a2.x
r=A.aB(a1,s,a3,a4)
if(r===s)return a2
return A.h8(a1,r,!0)
case 8:q=a2.y
p=A.b7(a1,q,a3,a4)
if(p===q)return a2
return A.bO(a1,a2.x,p)
case 9:o=a2.x
n=A.aB(a1,o,a3,a4)
m=a2.y
l=A.b7(a1,m,a3,a4)
if(n===o&&l===m)return a2
return A.fh(a1,n,l)
case 10:k=a2.x
j=a2.y
i=A.b7(a1,j,a3,a4)
if(i===j)return a2
return A.ha(a1,k,i)
case 11:h=a2.x
g=A.aB(a1,h,a3,a4)
f=a2.y
e=A.je(a1,f,a3,a4)
if(g===h&&e===f)return a2
return A.h7(a1,g,e)
case 12:d=a2.y
a4+=d.length
c=A.b7(a1,d,a3,a4)
o=a2.x
n=A.aB(a1,o,a3,a4)
if(c===d&&n===o)return a2
return A.fi(a1,n,c,!0)
case 13:b=a2.x
if(b<a4)return a2
a=a3[b-a4]
if(a==null)return a2
return a
default:throw A.d(A.bX("Attempted to substitute unexpected RTI kind "+a0))}},
b7(a,b,c,d){var s,r,q,p,o=b.length,n=A.eO(o)
for(s=!1,r=0;r<o;++r){q=b[r]
p=A.aB(a,q,c,d)
if(p!==q)s=!0
n[r]=p}return s?n:b},
jf(a,b,c,d){var s,r,q,p,o,n,m=b.length,l=A.eO(m)
for(s=!1,r=0;r<m;r+=3){q=b[r]
p=b[r+1]
o=b[r+2]
n=A.aB(a,o,c,d)
if(n!==o)s=!0
l.splice(r,3,q,p,n)}return s?l:b},
je(a,b,c,d){var s,r=b.a,q=A.b7(a,r,c,d),p=b.b,o=A.b7(a,p,c,d),n=b.c,m=A.jf(a,n,c,d)
if(q===r&&o===p&&m===n)return b
s=new A.cw()
s.a=q
s.b=o
s.c=m
return s},
o(a,b){a[v.arrayRti]=b
return a},
eV(a){var s=a.$S
if(s!=null){if(typeof s=="number")return A.ju(s)
return a.$S()}return null},
jw(a,b){var s
if(A.fX(b))if(a instanceof A.K){s=A.eV(a)
if(s!=null)return s}return A.bT(a)},
bT(a){if(a instanceof A.j)return A.i(a)
if(Array.isArray(a))return A.h(a)
return A.fj(J.aP(a))},
h(a){var s=a[v.arrayRti],r=t.gn
if(s==null)return r
if(s.constructor!==r.constructor)return r
return s},
i(a){var s=a.$ti
return s!=null?s:A.fj(a)},
fj(a){var s=a.constructor,r=s.$ccache
if(r!=null)return r
return A.iW(a,s)},
iW(a,b){var s=a instanceof A.K?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,r=A.iC(v.typeUniverse,s.name)
b.$ccache=r
return r},
ju(a){var s,r=v.types,q=r[a]
if(typeof q=="string"){s=A.eM(v.typeUniverse,q,!1)
r[a]=s
return s}return q},
jt(a){return A.at(A.i(a))},
fm(a){var s=A.eV(a)
return A.at(s==null?A.bT(a):s)},
jd(a){var s=a instanceof A.K?A.eV(a):null
if(s!=null)return s
if(t.dm.b(a))return J.hN(a).a
if(Array.isArray(a))return A.h(a)
return A.bT(a)},
at(a){var s=a.r
return s==null?a.r=new A.eL(a):s},
jD(a){return A.at(A.eM(v.typeUniverse,a,!1))},
iV(a){var s=this
s.b=A.jc(s)
return s.b(a)},
jc(a){var s,r,q,p,o
if(a===t.C)return A.j3
if(A.aQ(a))return A.j7
s=a.w
if(s===6)return A.iS
if(s===1)return A.hl
if(s===7)return A.iZ
r=A.jb(a)
if(r!=null)return r
if(s===8){q=a.x
if(a.y.every(A.aQ)){a.f="$i"+q
if(q==="v")return A.j1
if(a===t.m)return A.j0
return A.j6}}else if(s===10){p=A.jn(a.x,a.y)
o=p==null?A.hl:p
return o==null?A.he(o):o}return A.iQ},
jb(a){if(a.w===8){if(a===t.S)return A.hj
if(a===t.i||a===t.H)return A.j2
if(a===t.N)return A.j5
if(a===t.y)return A.fk}return null},
iU(a){var s=this,r=A.iP
if(A.aQ(s))r=A.iL
else if(s===t.C)r=A.he
else if(A.b8(s)){r=A.iR
if(s===t.I)r=A.iH
else if(s===t.dk)r=A.iK
else if(s===t.fQ)r=A.iF
else if(s===t.cg)r=A.hd
else if(s===t.cD)r=A.iG
else if(s===t.an)r=A.iJ}else if(s===t.S)r=A.aa
else if(s===t.N)r=A.B
else if(s===t.y)r=A.eR
else if(s===t.H)r=A.t
else if(s===t.i)r=A.m
else if(s===t.m)r=A.iI
s.a=r
return s.a(a)},
iQ(a){var s=this
if(a==null)return A.b8(s)
return A.hs(v.typeUniverse,A.jw(a,s),s)},
iS(a){if(a==null)return!0
return this.x.b(a)},
j6(a){var s,r=this
if(a==null)return A.b8(r)
s=r.f
if(a instanceof A.j)return!!a[s]
return!!J.aP(a)[s]},
j1(a){var s,r=this
if(a==null)return A.b8(r)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
s=r.f
if(a instanceof A.j)return!!a[s]
return!!J.aP(a)[s]},
j0(a){var s=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.j)return!!a[s.f]
return!0}if(typeof a=="function")return!0
return!1},
hk(a){if(typeof a=="object"){if(a instanceof A.j)return t.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
iP(a){var s=this
if(a==null){if(A.b8(s))return a}else if(s.b(a))return a
throw A.F(A.hf(a,s),new Error())},
iR(a){var s=this
if(a==null||s.b(a))return a
throw A.F(A.hf(a,s),new Error())},
hf(a,b){return new A.b5("TypeError: "+A.h1(a,A.M(b,null)))},
jj(a,b,c,d){if(A.hs(v.typeUniverse,a,b))return a
throw A.F(A.it("The type argument '"+A.M(a,null)+"' is not a subtype of the type variable bound '"+A.M(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
h1(a,b){return A.c9(a)+": type '"+A.M(A.jd(a),null)+"' is not a subtype of type '"+b+"'"},
it(a){return new A.b5("TypeError: "+a)},
W(a,b){return new A.b5("TypeError: "+A.h1(a,b))},
iZ(a){var s=this
return s.x.b(a)||A.fe(v.typeUniverse,s).b(a)},
j3(a){return a!=null},
he(a){if(a!=null)return a
throw A.F(A.W(a,"Object"),new Error())},
j7(a){return!0},
iL(a){return a},
hl(a){return!1},
fk(a){return!0===a||!1===a},
eR(a){if(!0===a)return!0
if(!1===a)return!1
throw A.F(A.W(a,"bool"),new Error())},
iF(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.F(A.W(a,"bool?"),new Error())},
m(a){if(typeof a=="number")return a
throw A.F(A.W(a,"double"),new Error())},
iG(a){if(typeof a=="number")return a
if(a==null)return a
throw A.F(A.W(a,"double?"),new Error())},
hj(a){return typeof a=="number"&&Math.floor(a)===a},
aa(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.F(A.W(a,"int"),new Error())},
iH(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.F(A.W(a,"int?"),new Error())},
j2(a){return typeof a=="number"},
t(a){if(typeof a=="number")return a
throw A.F(A.W(a,"num"),new Error())},
hd(a){if(typeof a=="number")return a
if(a==null)return a
throw A.F(A.W(a,"num?"),new Error())},
j5(a){return typeof a=="string"},
B(a){if(typeof a=="string")return a
throw A.F(A.W(a,"String"),new Error())},
iK(a){if(typeof a=="string")return a
if(a==null)return a
throw A.F(A.W(a,"String?"),new Error())},
iI(a){if(A.hk(a))return a
throw A.F(A.W(a,"JSObject"),new Error())},
iJ(a){if(a==null)return a
if(A.hk(a))return a
throw A.F(A.W(a,"JSObject?"),new Error())},
hm(a,b){var s,r,q
for(s="",r="",q=0;q<a.length;++q,r=", ")s+=r+A.M(a[q],b)
return s},
ja(a,b){var s,r,q,p,o,n,m=a.x,l=a.y
if(""===m)return"("+A.hm(l,b)+")"
s=l.length
r=m.split(",")
q=r.length-s
for(p="(",o="",n=0;n<s;++n,o=", "){p+=o
if(q===0)p+="{"
p+=A.M(l[n],b)
if(q>=0)p+=" "+r[q];++q}return p+"})"},
hg(a3,a4,a5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=", ",a2=null
if(a5!=null){s=a5.length
if(a4==null)a4=A.o([],t.s)
else a2=a4.length
r=a4.length
for(q=s;q>0;--q)B.a.m(a4,"T"+(r+q))
for(p=t.U,o="<",n="",q=0;q<s;++q,n=a1){m=a4.length
l=m-1-q
if(!(l>=0))return A.b(a4,l)
o=o+n+a4[l]
k=a5[q]
j=k.w
if(!(j===2||j===3||j===4||j===5||k===p))o+=" extends "+A.M(k,a4)}o+=">"}else o=""
p=a3.x
i=a3.y
h=i.a
g=h.length
f=i.b
e=f.length
d=i.c
c=d.length
b=A.M(p,a4)
for(a="",a0="",q=0;q<g;++q,a0=a1)a+=a0+A.M(h[q],a4)
if(e>0){a+=a0+"["
for(a0="",q=0;q<e;++q,a0=a1)a+=a0+A.M(f[q],a4)
a+="]"}if(c>0){a+=a0+"{"
for(a0="",q=0;q<c;q+=3,a0=a1){a+=a0
if(d[q+1])a+="required "
a+=A.M(d[q+2],a4)+" "+d[q]}a+="}"}if(a2!=null){a4.toString
a4.length=a2}return o+"("+a+") => "+b},
M(a,b){var s,r,q,p,o,n,m,l=a.w
if(l===5)return"erased"
if(l===2)return"dynamic"
if(l===3)return"void"
if(l===1)return"Never"
if(l===4)return"any"
if(l===6){s=a.x
r=A.M(s,b)
q=s.w
return(q===11||q===12?"("+r+")":r)+"?"}if(l===7)return"FutureOr<"+A.M(a.x,b)+">"
if(l===8){p=A.jg(a.x)
o=a.y
return o.length>0?p+("<"+A.hm(o,b)+">"):p}if(l===10)return A.ja(a,b)
if(l===11)return A.hg(a,b,null)
if(l===12)return A.hg(a.x,b,a.y)
if(l===13){n=a.x
m=b.length
n=m-1-n
if(!(n>=0&&n<m))return A.b(b,n)
return b[n]}return"?"},
jg(a){var s=v.mangledGlobalNames[a]
if(s!=null)return s
return"minified:"+a},
iD(a,b){var s=a.tR[b]
while(typeof s=="string")s=a.tR[s]
return s},
iC(a,b){var s,r,q,p,o,n=a.eT,m=n[b]
if(m==null)return A.eM(a,b,!1)
else if(typeof m=="number"){s=m
r=A.bP(a,5,"#")
q=A.eO(s)
for(p=0;p<s;++p)q[p]=r
o=A.bO(a,b,q)
n[b]=o
return o}else return m},
iA(a,b){return A.hb(a.tR,b)},
iz(a,b){return A.hb(a.eT,b)},
eM(a,b,c){var s,r=a.eC,q=r.get(b)
if(q!=null)return q
s=A.h5(A.h3(a,null,b,!1))
r.set(b,s)
return s},
eN(a,b,c){var s,r,q=b.z
if(q==null)q=b.z=new Map()
s=q.get(c)
if(s!=null)return s
r=A.h5(A.h3(a,b,c,!0))
q.set(c,r)
return r},
iB(a,b,c){var s,r,q,p=b.Q
if(p==null)p=b.Q=new Map()
s=c.as
r=p.get(s)
if(r!=null)return r
q=A.fh(a,b,c.w===9?c.y:[c])
p.set(s,q)
return q},
az(a,b){b.a=A.iU
b.b=A.iV
return b},
bP(a,b,c){var s,r,q=a.eC.get(c)
if(q!=null)return q
s=new A.a_(null,null)
s.w=b
s.as=c
r=A.az(a,s)
a.eC.set(c,r)
return r},
h9(a,b,c){var s,r=b.as+"?",q=a.eC.get(r)
if(q!=null)return q
s=A.ix(a,b,r,c)
a.eC.set(r,s)
return s},
ix(a,b,c,d){var s,r,q
if(d){s=b.w
r=!0
if(!A.aQ(b))if(!(b===t.a||b===t.T))if(s!==6)r=s===7&&A.b8(b.x)
if(r)return b
else if(s===1)return t.a}q=new A.a_(null,null)
q.w=6
q.x=b
q.as=c
return A.az(a,q)},
h8(a,b,c){var s,r=b.as+"/",q=a.eC.get(r)
if(q!=null)return q
s=A.iv(a,b,r,c)
a.eC.set(r,s)
return s},
iv(a,b,c,d){var s,r
if(d){s=b.w
if(A.aQ(b)||b===t.C)return b
else if(s===1)return A.bO(a,"fE",[b])
else if(b===t.a||b===t.T)return t.eH}r=new A.a_(null,null)
r.w=7
r.x=b
r.as=c
return A.az(a,r)},
iy(a,b){var s,r,q=""+b+"^",p=a.eC.get(q)
if(p!=null)return p
s=new A.a_(null,null)
s.w=13
s.x=b
s.as=q
r=A.az(a,s)
a.eC.set(q,r)
return r},
bN(a){var s,r,q,p=a.length
for(s="",r="",q=0;q<p;++q,r=",")s+=r+a[q].as
return s},
iu(a){var s,r,q,p,o,n=a.length
for(s="",r="",q=0;q<n;q+=3,r=","){p=a[q]
o=a[q+1]?"!":":"
s+=r+p+o+a[q+2].as}return s},
bO(a,b,c){var s,r,q,p=b
if(c.length>0)p+="<"+A.bN(c)+">"
s=a.eC.get(p)
if(s!=null)return s
r=new A.a_(null,null)
r.w=8
r.x=b
r.y=c
if(c.length>0)r.c=c[0]
r.as=p
q=A.az(a,r)
a.eC.set(p,q)
return q},
fh(a,b,c){var s,r,q,p,o,n
if(b.w===9){s=b.x
r=b.y.concat(c)}else{r=c
s=b}q=s.as+(";<"+A.bN(r)+">")
p=a.eC.get(q)
if(p!=null)return p
o=new A.a_(null,null)
o.w=9
o.x=s
o.y=r
o.as=q
n=A.az(a,o)
a.eC.set(q,n)
return n},
ha(a,b,c){var s,r,q="+"+(b+"("+A.bN(c)+")"),p=a.eC.get(q)
if(p!=null)return p
s=new A.a_(null,null)
s.w=10
s.x=b
s.y=c
s.as=q
r=A.az(a,s)
a.eC.set(q,r)
return r},
h7(a,b,c){var s,r,q,p,o,n=b.as,m=c.a,l=m.length,k=c.b,j=k.length,i=c.c,h=i.length,g="("+A.bN(m)
if(j>0){s=l>0?",":""
g+=s+"["+A.bN(k)+"]"}if(h>0){s=l>0?",":""
g+=s+"{"+A.iu(i)+"}"}r=n+(g+")")
q=a.eC.get(r)
if(q!=null)return q
p=new A.a_(null,null)
p.w=11
p.x=b
p.y=c
p.as=r
o=A.az(a,p)
a.eC.set(r,o)
return o},
fi(a,b,c,d){var s,r=b.as+("<"+A.bN(c)+">"),q=a.eC.get(r)
if(q!=null)return q
s=A.iw(a,b,c,r,d)
a.eC.set(r,s)
return s},
iw(a,b,c,d,e){var s,r,q,p,o,n,m,l
if(e){s=c.length
r=A.eO(s)
for(q=0,p=0;p<s;++p){o=c[p]
if(o.w===1){r[p]=o;++q}}if(q>0){n=A.aB(a,b,r,0)
m=A.b7(a,c,r,0)
return A.fi(a,n,m,c!==m)}}l=new A.a_(null,null)
l.w=12
l.x=b
l.y=c
l.as=d
return A.az(a,l)},
h3(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
h5(a){var s,r,q,p,o,n,m,l=a.r,k=a.s
for(s=l.length,r=0;r<s;){q=l.charCodeAt(r)
if(q>=48&&q<=57)r=A.io(r+1,q,l,k)
else if((((q|32)>>>0)-97&65535)<26||q===95||q===36||q===124)r=A.h4(a,r,l,k,!1)
else if(q===46)r=A.h4(a,r,l,k,!0)
else{++r
switch(q){case 44:break
case 58:k.push(!1)
break
case 33:k.push(!0)
break
case 59:k.push(A.aO(a.u,a.e,k.pop()))
break
case 94:k.push(A.iy(a.u,k.pop()))
break
case 35:k.push(A.bP(a.u,5,"#"))
break
case 64:k.push(A.bP(a.u,2,"@"))
break
case 126:k.push(A.bP(a.u,3,"~"))
break
case 60:k.push(a.p)
a.p=k.length
break
case 62:A.iq(a,k)
break
case 38:A.ip(a,k)
break
case 63:p=a.u
k.push(A.h9(p,A.aO(p,a.e,k.pop()),a.n))
break
case 47:p=a.u
k.push(A.h8(p,A.aO(p,a.e,k.pop()),a.n))
break
case 40:k.push(-3)
k.push(a.p)
a.p=k.length
break
case 41:A.im(a,k)
break
case 91:k.push(a.p)
a.p=k.length
break
case 93:o=k.splice(a.p)
A.h6(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-1)
break
case 123:k.push(a.p)
a.p=k.length
break
case 125:o=k.splice(a.p)
A.is(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-2)
break
case 43:n=l.indexOf("(",r)
k.push(l.substring(r,n))
k.push(-4)
k.push(a.p)
a.p=k.length
r=n+1
break
default:throw"Bad character "+q}}}m=k.pop()
return A.aO(a.u,a.e,m)},
io(a,b,c,d){var s,r,q=b-48
for(s=c.length;a<s;++a){r=c.charCodeAt(a)
if(!(r>=48&&r<=57))break
q=q*10+(r-48)}d.push(q)
return a},
h4(a,b,c,d,e){var s,r,q,p,o,n,m=b+1
for(s=c.length;m<s;++m){r=c.charCodeAt(m)
if(r===46){if(e)break
e=!0}else{if(!((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124))q=r>=48&&r<=57
else q=!0
if(!q)break}}p=c.substring(b,m)
if(e){s=a.u
o=a.e
if(o.w===9)o=o.x
n=A.iD(s,o.x)[p]
if(n==null)A.aS('No "'+p+'" in "'+A.id(o)+'"')
d.push(A.eN(s,o,n))}else d.push(p)
return m},
iq(a,b){var s,r=a.u,q=A.h2(a,b),p=b.pop()
if(typeof p=="string")b.push(A.bO(r,p,q))
else{s=A.aO(r,a.e,p)
switch(s.w){case 11:b.push(A.fi(r,s,q,a.n))
break
default:b.push(A.fh(r,s,q))
break}}},
im(a,b){var s,r,q,p=a.u,o=b.pop(),n=null,m=null
if(typeof o=="number")switch(o){case-1:n=b.pop()
break
case-2:m=b.pop()
break
default:b.push(o)
break}else b.push(o)
s=A.h2(a,b)
o=b.pop()
switch(o){case-3:o=b.pop()
if(n==null)n=p.sEA
if(m==null)m=p.sEA
r=A.aO(p,a.e,o)
q=new A.cw()
q.a=s
q.b=n
q.c=m
b.push(A.h7(p,r,q))
return
case-4:b.push(A.ha(p,b.pop(),s))
return
default:throw A.d(A.bX("Unexpected state under `()`: "+A.x(o)))}},
ip(a,b){var s=b.pop()
if(0===s){b.push(A.bP(a.u,1,"0&"))
return}if(1===s){b.push(A.bP(a.u,4,"1&"))
return}throw A.d(A.bX("Unexpected extended operation "+A.x(s)))},
h2(a,b){var s=b.splice(a.p)
A.h6(a.u,a.e,s)
a.p=b.pop()
return s},
aO(a,b,c){if(typeof c=="string")return A.bO(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.ir(a,b,c)}else return c},
h6(a,b,c){var s,r=c.length
for(s=0;s<r;++s)c[s]=A.aO(a,b,c[s])},
is(a,b,c){var s,r=c.length
for(s=2;s<r;s+=3)c[s]=A.aO(a,b,c[s])},
ir(a,b,c){var s,r,q=b.w
if(q===9){if(c===0)return b.x
s=b.y
r=s.length
if(c<=r)return s[c-1]
c-=r
b=b.x
q=b.w}else if(c===0)return b
if(q!==8)throw A.d(A.bX("Indexed base must be an interface type"))
s=b.y
if(c<=s.length)return s[c-1]
throw A.d(A.bX("Bad index "+c+" for "+b.k(0)))},
hs(a,b,c){var s,r=b.d
if(r==null)r=b.d=new Map()
s=r.get(c)
if(s==null){s=A.A(a,b,null,c,null)
r.set(c,s)}return s},
A(a,b,c,d,e){var s,r,q,p,o,n,m,l,k,j,i
if(b===d)return!0
if(A.aQ(d))return!0
s=b.w
if(s===4)return!0
if(A.aQ(b))return!1
if(b.w===1)return!0
r=s===13
if(r)if(A.A(a,c[b.x],c,d,e))return!0
q=d.w
p=t.a
if(b===p||b===t.T){if(q===7)return A.A(a,b,c,d.x,e)
return d===p||d===t.T||q===6}if(d===t.C){if(s===7)return A.A(a,b.x,c,d,e)
return s!==6}if(s===7){if(!A.A(a,b.x,c,d,e))return!1
return A.A(a,A.fe(a,b),c,d,e)}if(s===6)return A.A(a,p,c,d,e)&&A.A(a,b.x,c,d,e)
if(q===7){if(A.A(a,b,c,d.x,e))return!0
return A.A(a,b,c,A.fe(a,d),e)}if(q===6)return A.A(a,b,c,p,e)||A.A(a,b,c,d.x,e)
if(r)return!1
p=s!==11
if((!p||s===12)&&d===t.Z)return!0
o=s===10
if(o&&d===t.gT)return!0
if(q===12){if(b===t.L)return!0
if(s!==12)return!1
n=b.y
m=d.y
l=n.length
if(l!==m.length)return!1
c=c==null?n:n.concat(c)
e=e==null?m:m.concat(e)
for(k=0;k<l;++k){j=n[k]
i=m[k]
if(!A.A(a,j,c,i,e)||!A.A(a,i,e,j,c))return!1}return A.hi(a,b.x,c,d.x,e)}if(q===11){if(b===t.L)return!0
if(p)return!1
return A.hi(a,b,c,d,e)}if(s===8){if(q!==8)return!1
return A.j_(a,b,c,d,e)}if(o&&q===10)return A.j4(a,b,c,d,e)
return!1},
hi(a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
if(!A.A(a3,a4.x,a5,a6.x,a7))return!1
s=a4.y
r=a6.y
q=s.a
p=r.a
o=q.length
n=p.length
if(o>n)return!1
m=n-o
l=s.b
k=r.b
j=l.length
i=k.length
if(o+j<n+i)return!1
for(h=0;h<o;++h){g=q[h]
if(!A.A(a3,p[h],a7,g,a5))return!1}for(h=0;h<m;++h){g=l[h]
if(!A.A(a3,p[o+h],a7,g,a5))return!1}for(h=0;h<i;++h){g=l[m+h]
if(!A.A(a3,k[h],a7,g,a5))return!1}f=s.c
e=r.c
d=f.length
c=e.length
for(b=0,a=0;a<c;a+=3){a0=e[a]
for(;;){if(b>=d)return!1
a1=f[b]
b+=3
if(a0<a1)return!1
a2=f[b-2]
if(a1<a0){if(a2)return!1
continue}g=e[a+1]
if(a2&&!g)return!1
g=f[b-1]
if(!A.A(a3,e[a+2],a7,g,a5))return!1
break}}while(b<d){if(f[b+1])return!1
b+=3}return!0},
j_(a,b,c,d,e){var s,r,q,p,o,n=b.x,m=d.x
while(n!==m){s=a.tR[n]
if(s==null)return!1
if(typeof s=="string"){n=s
continue}r=s[m]
if(r==null)return!1
q=r.length
p=q>0?new Array(q):v.typeUniverse.sEA
for(o=0;o<q;++o)p[o]=A.eN(a,b,r[o])
return A.hc(a,p,null,c,d.y,e)}return A.hc(a,b.y,null,c,d.y,e)},
hc(a,b,c,d,e,f){var s,r=b.length
for(s=0;s<r;++s)if(!A.A(a,b[s],d,e[s],f))return!1
return!0},
j4(a,b,c,d,e){var s,r=b.y,q=d.y,p=r.length
if(p!==q.length)return!1
if(b.x!==d.x)return!1
for(s=0;s<p;++s)if(!A.A(a,r[s],c,q[s],e))return!1
return!0},
b8(a){var s=a.w,r=!0
if(!(a===t.a||a===t.T))if(!A.aQ(a))if(s!==6)r=s===7&&A.b8(a.x)
return r},
aQ(a){var s=a.w
return s===2||s===3||s===4||s===5||a===t.U},
hb(a,b){var s,r,q=Object.keys(b),p=q.length
for(s=0;s<p;++s){r=q[s]
a[r]=b[r]}},
eO(a){return a>0?new Array(a):v.typeUniverse.sEA},
a_:function a_(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
cw:function cw(){this.c=this.b=this.a=null},
eL:function eL(a){this.a=a},
cv:function cv(){},
b5:function b5(a){this.a=a},
fJ(a,b){return new A.aj(a.h("@<0>").t(b).h("aj<1,2>"))},
R(a,b,c){return b.h("@<0>").t(c).h("fI<1,2>").a(A.jq(a,new A.aj(b.h("@<0>").t(c).h("aj<1,2>"))))},
aI(a,b){return new A.aj(a.h("@<0>").t(b).h("aj<1,2>"))},
fL(a){return new A.as(a.h("as<0>"))},
fM(a){return new A.as(a.h("as<0>"))},
i5(a,b){return b.h("fK<0>").a(A.jr(a,new A.as(b.h("as<0>"))))},
fg(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
il(a,b,c){var s=new A.aN(a,b,c.h("aN<0>"))
s.c=a.e
return s},
i4(a,b,c){var s=A.fJ(b,c)
a.H(0,new A.eg(s,b,c))
return s},
i6(a,b){var s=A.fL(b)
s.L(0,a)
return s},
ek(a){var s,r
if(A.fn(a))return"{...}"
s=new A.b2("")
try{r={}
B.a.m($.V,a)
s.a+="{"
r.a=!0
a.H(0,new A.el(r,s))
s.a+="}"}finally{if(0>=$.V.length)return A.b($.V,-1)
$.V.pop()}r=s.a
return r.charCodeAt(0)==0?r:r},
i7(a){return 8},
iE(){throw A.d(A.eC("Cannot change an unmodifiable set"))},
as:function as(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
cz:function cz(a){this.a=a
this.b=null},
aN:function aN(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
eg:function eg(a,b,c){this.a=a
this.b=b
this.c=c},
I:function I(){},
el:function el(a,b){this.a=a
this.b=b},
bQ:function bQ(){},
b1:function b1(){},
bH:function bH(){},
eh:function eh(a,b){var _=this
_.a=a
_.d=_.c=_.b=0
_.$ti=b},
bL:function bL(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=null
_.$ti=e},
aM:function aM(){},
bM:function bM(){},
cA:function cA(){},
bI:function bI(a,b){this.a=a
this.$ti=b},
b6:function b6(){},
bR:function bR(){},
j9(a,b){var s,r,q,p=null
try{p=JSON.parse(a)}catch(r){s=A.fo(r)
q=A.ca(String(s),null)
throw A.d(q)}q=A.eS(p)
return q},
eS(a){var s
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.cx(a,Object.create(null))
for(s=0;s<a.length;++s)a[s]=A.eS(a[s])
return a},
fH(a,b,c){return new A.bn(a,b)},
iN(a){return a.ce()},
ij(a,b){return new A.eH(a,[],A.jm())},
ik(a,b,c){var s,r=new A.b2(""),q=A.ij(r,b)
q.ac(a)
s=r.a
return s.charCodeAt(0)==0?s:s},
cx:function cx(a,b){this.a=a
this.b=b
this.c=null},
cy:function cy(a){this.a=a},
c_:function c_(){},
c2:function c2(){},
bn:function bn(a,b){this.a=a
this.b=b},
ck:function ck(a,b){this.a=a
this.b=b},
ec:function ec(){},
ee:function ee(a){this.b=a},
ed:function ed(a){this.a=a},
eI:function eI(){},
eJ:function eJ(a,b){this.a=a
this.b=b},
eH:function eH(a,b,c){this.c=a
this.a=b
this.b=c},
cC(a){var s=A.i9(a,null)
if(s!=null)return s
throw A.d(A.ca(a,null))},
bt(a,b,c,d){var s,r=J.fG(a,d)
if(a!==0&&b!=null)for(s=0;s<a;++s)r[s]=b
return r},
fd(a,b,c){var s,r=A.o([],c.h("n<0>"))
for(s=J.a2(a);s.n();)B.a.m(r,c.a(s.gp()))
if(b)return r
r.$flags=1
return r},
y(a,b){var s,r=A.o([],b.h("n<0>"))
for(s=a.gq(a);s.n();)B.a.m(r,s.gp())
return r},
a7(a,b){var s=A.fd(a,!1,b)
s.$flags=3
return s},
ic(a){return new A.ci(a,A.i3(a,!1,!0,!1,!1,""))},
fZ(a,b,c){var s=J.a2(b)
if(!s.n())return a
if(c.length===0){do a+=A.x(s.gp())
while(s.n())}else{a+=A.x(s.gp())
while(s.n())a=a+c+A.x(s.gp())}return a},
hY(a,b,c,d,e,f,g,h,i){var s=A.fV(a,b,c,d,e,f,g,h,i)
if(s==null)return null
return new A.a4(A.fC(s,h,i),h,i)},
hX(a){var s=A.fV(a,1,1,0,0,0,0,0,!0)
return new A.a4(s==null?new A.ds(a,1,1,0,0,0,0,0).$0():s,0,!0)},
i_(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=$.hy().bU(a)
if(c!=null){s=new A.du()
r=c.b
if(1>=r.length)return A.b(r,1)
q=r[1]
q.toString
p=A.cC(q)
if(2>=r.length)return A.b(r,2)
q=r[2]
q.toString
o=A.cC(q)
if(3>=r.length)return A.b(r,3)
q=r[3]
q.toString
n=A.cC(q)
if(4>=r.length)return A.b(r,4)
m=s.$1(r[4])
if(5>=r.length)return A.b(r,5)
l=s.$1(r[5])
if(6>=r.length)return A.b(r,6)
k=s.$1(r[6])
if(7>=r.length)return A.b(r,7)
j=new A.dv().$1(r[7])
i=B.c.A(j,1000)
q=r.length
if(8>=q)return A.b(r,8)
h=r[8]!=null
if(h){if(9>=q)return A.b(r,9)
g=r[9]
if(g!=null){f=g==="-"?-1:1
if(10>=q)return A.b(r,10)
q=r[10]
q.toString
e=A.cC(q)
if(11>=r.length)return A.b(r,11)
l-=f*(s.$1(r[11])+60*e)}}d=A.hY(p,o,n,m,l,k,i,j%1000,h)
if(d==null)throw A.d(A.ca("Time out of range",a))
return d}else throw A.d(A.ca("Invalid date format",a))},
fC(a,b,c){var s="microsecond"
if(b<0||b>999)throw A.d(A.a8(b,0,999,s,null))
if(a<-864e13||a>864e13)throw A.d(A.a8(a,-864e13,864e13,"millisecondsSinceEpoch",null))
if(a===864e13&&b!==0)throw A.d(A.hP(b,s,"Time including microseconds is outside valid range"))
A.ho(c,"isUtc",t.y)
return a},
fB(a){var s=Math.abs(a),r=a<0?"-":""
if(s>=1000)return""+a
if(s>=100)return r+"0"+s
if(s>=10)return r+"00"+s
return r+"000"+s},
hZ(a){var s=Math.abs(a),r=a<0?"-":"+"
if(s>=1e5)return r+s
return r+"0"+s},
dt(a){if(a>=100)return""+a
if(a>=10)return"0"+a
return"00"+a},
ag(a){if(a>=10)return""+a
return"0"+a},
D(a,b){return new A.L(a+1000*b)},
c9(a){if(typeof a=="number"||A.fk(a)||a==null)return J.aT(a)
if(typeof a=="string")return JSON.stringify(a)
return A.ia(a)},
bX(a){return new A.bW(a)},
f9(a){return new A.ac(!1,null,null,a)},
hP(a,b,c){return new A.ac(!0,a,b,c)},
cU(a,b,c){return a},
a8(a,b,c,d,e){return new A.by(b,c,!0,a,d,"Invalid value")},
fW(a,b,c){if(0>a||a>c)throw A.d(A.a8(a,0,c,"start",null))
if(a>b||b>c)throw A.d(A.a8(b,a,c,"end",null))
return b},
an(a,b){if(a<0)throw A.d(A.a8(a,0,null,b,null))
return a},
e7(a,b,c,d,e){return new A.cb(b,!0,a,e,"Index out of range")},
eC(a){return new A.bJ(a)},
N(a){return new A.c1(a)},
ca(a,b){return new A.e6(a,b)},
i1(a,b,c){var s,r
if(A.fn(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}s=A.o([],t.s)
B.a.m($.V,a)
try{A.j8(a,s)}finally{if(0>=$.V.length)return A.b($.V,-1)
$.V.pop()}r=A.fZ(b,t.hf.a(s),", ")+c
return r.charCodeAt(0)==0?r:r},
fa(a,b,c){var s,r
if(A.fn(a))return b+"..."+c
s=new A.b2(b)
B.a.m($.V,a)
try{r=s
r.a=A.fZ(r.a,a,", ")}finally{if(0>=$.V.length)return A.b($.V,-1)
$.V.pop()}s.a+=c
r=s.a
return r.charCodeAt(0)==0?r:r},
j8(a,b){var s,r,q,p,o,n,m,l=a.gq(a),k=0,j=0
for(;;){if(!(k<80||j<3))break
if(!l.n())return
s=A.x(l.gp())
B.a.m(b,s)
k+=s.length+2;++j}if(!l.n()){if(j<=5)return
if(0>=b.length)return A.b(b,-1)
r=b.pop()
if(0>=b.length)return A.b(b,-1)
q=b.pop()}else{p=l.gp();++j
if(!l.n()){if(j<=4){B.a.m(b,A.x(p))
return}r=A.x(p)
if(0>=b.length)return A.b(b,-1)
q=b.pop()
k+=r.length+2}else{o=l.gp();++j
for(;l.n();p=o,o=n){n=l.gp();++j
if(j>100){for(;;){if(!(k>75&&j>3))break
if(0>=b.length)return A.b(b,-1)
k-=b.pop().length+2;--j}B.a.m(b,"...")
return}}q=A.x(p)
r=A.x(o)
k+=r.length+q.length+4}}if(j>b.length+2){k+=5
m="..."}else m=null
for(;;){if(!(k>80&&b.length>3))break
if(0>=b.length)return A.b(b,-1)
k-=b.pop().length+2
if(m==null){k+=5
m="..."}}if(m!=null)B.a.m(b,m)
B.a.m(b,q)
B.a.m(b,r)},
fN(a,b){var s=J.b9(a)
b=J.b9(b)
b=A.ig(A.h_(A.h_($.hJ(),s),b))
return b},
ds:function ds(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
a4:function a4(a,b,c){this.a=a
this.b=b
this.c=c},
du:function du(){},
dv:function dv(){},
L:function L(a){this.a=a},
eE:function eE(){},
u:function u(){},
bW:function bW(a){this.a=a},
bG:function bG(){},
ac:function ac(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
by:function by(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
cb:function cb(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
bJ:function bJ(a){this.a=a},
bC:function bC(a){this.a=a},
c1:function c1(a){this.a=a},
cm:function cm(){},
bB:function bB(){},
eF:function eF(a){this.a=a},
e6:function e6(a,b){this.a=a
this.b=b},
c:function c(){},
E:function E(a,b,c){this.a=a
this.b=b
this.$ti=c},
aK:function aK(){},
j:function j(){},
b2:function b2(a){this.a=a},
cG:function cG(){},
cO:function cO(a){this.a=a},
cP:function cP(){},
cQ:function cQ(a){this.a=a},
cR:function cR(a,b){this.a=a
this.b=b},
cS:function cS(a,b){this.a=a
this.b=b},
cH:function cH(){},
cJ:function cJ(){},
cI:function cI(a){this.a=a},
cK:function cK(a,b){this.a=a
this.b=b},
cL:function cL(){},
cN:function cN(){},
cM:function cM(a){this.a=a},
hO(a,b,c,d){var s,r,q,p,o,n,m,l,k=a.Q
if(!k||!a.ax||a.c!==c)return null
s=a.e
r=Math.max(s,d)
q=a.f
p=Math.min(q,b)
o=q-s
s=p-r
if(s<=0.01||o<=0.01)return null
q=new A.cT(a,o)
n=q.$1(r)
m=q.$1(p)
l=Math.min(s,m-n)
return A.fz(l,a.y,a.x,l>=3000,k,a.a,p,a.c,r,a.as,a.ax,a.ay,a.b,m,a.d,n)},
cT:function cT(a,b){this.a=a
this.b=b},
cW:function cW(){},
d9:function d9(){},
da:function da(){},
cX:function cX(a){this.a=a},
cY:function cY(){},
d0:function d0(a){this.a=a},
d1:function d1(){},
d3:function d3(){},
d4:function d4(a){this.a=a},
d5:function d5(){},
d6:function d6(){},
d_:function d_(a){this.a=a},
cZ:function cZ(a){this.a=a},
d7:function d7(){},
d8:function d8(){},
d2:function d2(a){this.a=a},
aA:function aA(a,b){this.a=a
this.b=b},
a9:function a9(a,b,c){this.a=a
this.b=b
this.c=c},
db:function db(a,b,c,d){var _=this
_.a=a
_.f=b
_.r=c
_.z=d},
cV:function cV(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
G:function G(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.w=f
_.x=g},
dc:function dc(){},
fz(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p){return new A.dd(f,m,h,o,i,g,p,n,c,b,a,e,j,d,k,l)},
dd:function dd(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l
_.as=m
_.at=n
_.ax=o
_.ay=p},
ad:function ad(a,b){this.a=a
this.b=b},
c0:function c0(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.r=c
_.w=d
_.x=e
_.y=f},
bb:function bb(a,b){this.a=a
this.b=b},
ae:function ae(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
dh:function dh(a,b){this.a=a
this.b=b},
iT(a,b){var s
if(!isFinite(a)||a<0||a>=360)return null
s=B.b.T(Math.abs(a-b),360)
return s>180?360-s:s},
de:function de(){},
df:function df(){},
dg:function dg(){},
a1:function a1(a,b,c){this.a=a
this.b=b
this.c=c},
eG:function eG(a,b,c){this.a=a
this.b=b
this.c=c},
c4:function c4(){},
dp:function dp(a,b){this.a=a
this.b=b},
dq:function dq(){},
dr:function dr(){},
dk:function dk(){},
dl:function dl(){},
dm:function dm(){},
dn:function dn(){},
dj:function dj(){},
c3:function c3(a,b,c){this.a=a
this.y=b
this.z=c},
a3:function a3(a,b,c,d,e,f,g){var _=this
_.e=a
_.r=b
_.w=c
_.x=d
_.y=e
_.z=f
_.Q=g},
dw:function dw(){},
c6:function c6(){},
dA:function dA(){},
dz:function dz(){},
dB:function dB(a,b){this.a=a
this.b=b},
dM:function dM(){},
dL:function dL(){},
dN:function dN(a){this.a=a},
dP:function dP(){},
dO:function dO(){},
dQ:function dQ(a){this.a=a},
dR:function dR(){},
dC:function dC(){},
dS:function dS(){},
dD:function dD(a,b){this.a=a
this.b=b},
dE:function dE(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dF:function dF(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dG:function dG(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dH:function dH(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dI:function dI(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dJ:function dJ(){},
dK:function dK(a){this.a=a},
dy:function dy(a,b){this.a=a
this.b=b},
U:function U(a,b){this.a=a
this.b=b},
dT:function dT(a,b){this.a=a
this.b=b},
dU:function dU(){},
dV:function dV(){},
cd:function cd(){},
e8:function e8(){},
dW:function dW(){},
dX:function dX(){},
be:function be(a,b){this.a=a
this.b=b},
C:function C(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
au:function au(a,b){this.b=a
this.c=b},
dY:function dY(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
fD(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s){return new A.k(h,d,s,o,e,q,g,p,f,i,k,c,a,r,n,m,b,l,j)},
a5:function a5(a,b){this.a=a
this.b=b},
b3:function b3(a,b){this.a=a
this.b=b},
aG:function aG(a,b){this.a=a
this.b=b},
av:function av(a,b){this.a=a
this.b=b},
O:function O(a,b){this.a=a
this.b=b},
T:function T(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.d=c
_.e=d
_.f=e
_.r=f},
ap:function ap(a,b,c){this.a=a
this.c=b
this.d=c},
ah:function ah(a,b,c){this.a=a
this.b=b
this.c=c},
k:function k(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l
_.as=m
_.at=n
_.ax=o
_.ay=p
_.ch=q
_.CW=r
_.cx=s},
c5:function c5(a,b,c){this.b=a
this.c=b
this.f=c},
dx:function dx(a){this.a=a},
dZ:function dZ(){},
e_:function e_(){},
e1:function e1(){},
e0:function e0(a){this.a=a},
e2:function e2(){},
e3:function e3(){},
e4:function e4(){},
e5:function e5(){},
c8:function c8(a,b,c){this.a=a
this.f=b
this.r=c},
c7:function c7(a,b,c){this.a=a
this.b=b
this.c=c},
bV:function bV(a,b,c){this.a=a
this.e=b
this.f=c},
a6:function a6(a,b){this.a=a
this.b=b},
Y:function Y(a,b){this.a=a
this.e=b},
ct:function ct(a,b,c){this.a=a
this.e=b
this.f=c},
b0:function b0(a,b){this.a=a
this.b=b},
bu:function bu(a,b){this.a=a
this.b=b},
ax:function ax(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
aJ:function aJ(a,b,c,d,e,f,g,h,i,j,k,l){var _=this
_.a=a
_.b=b
_.d=c
_.e=d
_.f=e
_.r=f
_.w=g
_.x=h
_.y=i
_.z=j
_.Q=k
_.as=l},
bv:function bv(a,b,c){this.a=a
this.c=b
this.d=c},
ei:function ei(a){this.a=a},
ej:function ej(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
eQ:function eQ(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.w=1},
P:function P(a,b){this.a=a
this.b=b},
Z:function Z(a,b,c){this.a=a
this.b=b
this.c=c},
eq:function eq(){},
eP:function eP(a,b){this.a=a
this.b=b},
bF:function bF(a,b,c){this.a=a
this.r=b
this.as=c},
bE:function bE(a){this.a=a},
er:function er(){},
ew:function ew(a){this.a=a},
ex:function ex(a){this.a=a},
ey:function ey(){},
ez:function ez(){},
ev:function ev(a){this.a=a},
et:function et(){},
eu:function eu(){},
es:function es(a){this.a=a},
eD:function eD(a,b,c,d,e){var _=this
_.a=a
_.c=b
_.d=c
_.e=d
_.x=e},
jo(a){var s=A.hq(t.P.a(a.i(0,"match"))),r=A.B(a.i(0,"sectionId")),q=A.t(a.i(0,"start")),p=A.hO(s,A.t(a.i(0,"end")),r,q)
if(p==null)return null
return A.R(["firstStartOffsetMeters",p.e,"firstEndOffsetMeters",p.f,"secondStartOffsetMeters",p.r,"secondEndOffsetMeters",p.w,"commonDistanceMeters",p.z,"comparisonEligible",p.at],t.N,t.z)},
f_(a){var s,r,q=J.cF(t.j.a(a.i(0,"sections")),new A.f1(),t.p),p=A.y(q,q.$ti.h("q.E"))
A.hX(1970)
q=A.B(a.i(0,"id"))
A.B(a.i(0,"driveId"))
s=A.h(p)
r=s.h("bi<1,P>")
s=A.y(new A.bi(p,s.h("c<P>(1)").a(new A.f2()),r),r.h("c.E"))
return new A.eD(q,s,p,B.a.F(p,0,new A.f3(),t.i),null)},
f7(a){var s=J.cF(a,new A.f8(),t.u)
s=A.y(s,s.$ti.h("q.E"))
return s},
hv(a){var s,r=t.N,q=t.z
if(a==null)r=A.aI(r,q)
else{s=t.h6
q=A.R(["totalScore",a.a,"displayScore",a.c,"algorithmVersion",a.d,"overallConfidence",a.b,"categories",a.e.a2(0,new A.f4(),r,s),"contributions",a.f.a2(0,new A.f5(),r,s)],r,q)
r=q}return r},
hp(a){var s,r=a.e
r=r==null?null:A.hv(r)
s=a.f
s=s==null?null:A.hv(s)
return A.R(["outcome",a.x.b,"comparisonValid",a.y,"firstLocalScore",r,"secondLocalScore",s,"scoreDifference",a.r,"relativeDifference",a.w],t.N,t.z)},
bU(a){var s=a.b,r=A.h(s),q=r.h("f<1,e>")
r=A.y(new A.f(s,r.h("e(1)").a(new A.f6()),q),q.h("q.E"))
return A.R(["status",a.a.b,"startIndex",a.c,"endIndex",a.d,"count",s.length,"mappingConfidence",a.e,"timestamps",r],t.N,t.z)},
jp(a){var s,r,q,p,o,n,m,l="firstRoad",k="firstTelemetry",j="secondRoad",i="secondTelemetry"
if(!J.cE(a.i(0,"algorithmVersion"),1))return A.R(["status","unsupportedAlgorithmVersion","windows",[],"winningRegions",[]],t.N,t.z)
s=t.P
r=A.hq(s.a(a.i(0,"match")))
if(J.cE(a.i(0,"operation"),"extract")){q=A.f_(s.a(a.i(0,l)))
p=t.j
o=A.f7(p.a(a.i(0,k)))
s=A.f_(s.a(a.i(0,j)))
p=A.f7(p.a(a.i(0,i)))
n=t.t
m=B.i.ao(q,n.a(o),r,s,n.a(p))
s=m.gaq()?"success":"telemetryUnavailable"
return A.R(["status",s,"firstExtraction",A.bU(m.a),"secondExtraction",A.bU(m.b),"windows",[],"winningRegions",[]],t.N,t.z)}if(!r.at)return A.R(["status","notEligible","windows",[],"winningRegions",[]],t.N,t.z)
q=t.j
return A.ji(r,A.f_(s.a(a.i(0,l))),A.f_(s.a(a.i(0,j))),A.f7(q.a(a.i(0,k))),A.f7(q.a(a.i(0,i))))},
hq(a1){var s,r,q,p,o,n,m,l="latitude",k="longitude",j=A.B(a1.i(0,"firstDriveId")),i=A.B(a1.i(0,"secondDriveId")),h=A.B(a1.i(0,"firstSectionId")),g=A.B(a1.i(0,"secondSectionId")),f=A.t(a1.i(0,"firstStartOffsetMeters")),e=A.t(a1.i(0,"firstEndOffsetMeters")),d=A.t(a1.i(0,"secondStartOffsetMeters")),c=A.t(a1.i(0,"secondEndOffsetMeters")),b=t.P,a=b.a(a1.i(0,"commonStart")),a0=A.t(a.i(0,l))
a=A.t(a.i(0,k))
b=b.a(a1.i(0,"commonEnd"))
s=A.t(b.i(0,l))
b=A.t(b.i(0,k))
r=A.t(a1.i(0,"commonDistanceMeters"))
q=A.eR(a1.i(0,"directionCompatible"))
p=A.t(a1.i(0,"geometryConfidence"))
o=A.eR(a1.i(0,"comparisonEligible"))
n=A.eR(a1.i(0,"ownershipCovered"))
m=J.cF(t.j.a(a1.i(0,"referenceGeometry")),new A.eW(),t.x)
m=A.y(m,m.$ti.h("q.E"))
return A.fz(r,new A.P(s,b),new A.P(a0,a),o,q,j,e,h,f,p,n,m,i,c,g,d)},
ji(a,b,c,d,e){var s,r,q,p,o,n,m,l,k="secondExtraction",j=t.t,i=B.i.ao(b,j.a(d),a,c,j.a(e))
if(!i.gaq())return A.R(["status","telemetryUnavailable","firstExtraction",A.bU(i.a),k,A.bU(i.b),"windows",[],"winningRegions",[]],t.N,t.z)
j=i.a
s=j.b
r=i.b
q=r.b
p=B.v.bP(B.D,b,s,a,c,q)
o=new A.ei(B.v).bO(B.D,c,q,b,s,a)
s=A.hp(p)
j=A.bU(j)
r=A.bU(r)
q=o.c
n=A.h(q)
m=n.h("f<1,r<e,j>>")
q=A.y(new A.f(q,n.h("r<e,j>(1)").a(new A.eT()),m),m.h("q.E"))
n=o.d
m=A.h(n)
l=m.h("f<1,r<e,j>>")
n=A.y(new A.f(n,m.h("r<e,j>(1)").a(new A.eU()),l),l.h("q.E"))
return A.R(["status",o.a.b,"comparison",s,"firstExtraction",j,k,r,"windows",q,"winningRegions",n],t.N,t.z)},
f1:function f1(){},
f0:function f0(){},
f2:function f2(){},
f3:function f3(){},
f8:function f8(){},
f4:function f4(){},
f5:function f5(){},
f6:function f6(){},
eW:function eW(){},
eT:function eT(){},
eU:function eU(){},
jy(){var s=v.G
s.driveItActiveCoverage=A.hh(new A.eY())
s.driveItWorldScoring=A.hh(new A.eZ())},
eY:function eY(){},
eZ:function eZ(){},
jB(a){throw A.F(new A.cl("Field '"+a+"' has been assigned during initialization."),new Error())},
hh(a){var s
if(typeof a=="function")throw A.d(A.f9("Attempting to rewrap a JS function."))
s=function(b,c){return function(d){return b(c,d,arguments.length)}}(A.iM,a)
s[$.fp()]=a
return s},
iM(a,b,c){t.Z.a(a)
if(A.aa(c)>=1)return a.$1(b)
return a.$0()},
ht(a,b,c){A.jj(c,t.H,"T","max")
return Math.max(c.a(a),c.a(b))},
fF(a,b,c,d){var s=Math.sin((c-a)*3.141592653589793/180/2),r=Math.sin((d-b)*3.141592653589793/180/2)
return 12742017.6*Math.asin(Math.sqrt(B.b.j(s*s+Math.cos(a*3.141592653589793/180)*Math.cos(c*3.141592653589793/180)*r*r,0,1)))},
ii(a){var s=a.c,r=A.ff(a.b)
return isFinite(s)&&s>0?s:r},
ff(a){var s,r,q,p,o
for(s=0,r=0;r<a.length-1;){q=a[r];++r
p=a[r]
o=A.fF(q.a,q.b,p.a,p.b)
if(isFinite(o)&&o>0)s+=o}return s},
ih(a,b,c){if(!isFinite(b)||!isFinite(a)||!isFinite(c)||a<=0||c<=0)return 0
return B.b.j(B.b.j(b/a,0,1)*c,0,c)}},B={}
var w=[A,J,B]
var $={}
A.fb.prototype={}
J.ce.prototype={
M(a,b){return a===b},
gB(a){return A.co(a)},
k(a){return"Instance of '"+A.cp(a)+"'"},
gS(a){return A.at(A.fj(this))}}
J.cg.prototype={
k(a){return String(a)},
gB(a){return a?519018:218159},
gS(a){return A.at(t.y)},
$iaq:1,
$il:1}
J.bl.prototype={
M(a,b){return null==b},
k(a){return"null"},
gB(a){return 0},
$iaq:1}
J.b_.prototype={$iaZ:1}
J.aw.prototype={
gB(a){return 0},
k(a){return String(a)}}
J.en.prototype={}
J.ay.prototype={}
J.bm.prototype={
k(a){var s=a[$.hx()]
if(s==null)s=a[$.fp()]
if(s==null)return this.b_(a)
return"JavaScript function for "+J.aT(s)},
$iai:1}
J.n.prototype={
m(a,b){A.h(a).c.a(b)
a.$flags&1&&A.cD(a,29)
a.push(b)},
L(a,b){var s
A.h(a).h("c<1>").a(b)
a.$flags&1&&A.cD(a,"addAll",2)
for(s=b.gq(b);s.n();)a.push(s.gp())},
aT(a,b,c){var s=A.h(a)
return new A.f(a,s.t(c).h("1(2)").a(b),s.h("@<1>").t(c).h("f<1,2>"))},
c0(a,b){var s,r=A.bt(a.length,"",!1,t.N)
for(s=0;s<a.length;++s)this.u(r,s,A.x(a[s]))
return r.join(b)},
K(a,b){return A.ep(a,b,null,A.h(a).c)},
J(a,b){var s,r,q
A.h(a).h("1(1,1)").a(b)
s=a.length
if(s===0)throw A.d(A.aX())
if(0>=s)return A.b(a,0)
r=a[0]
for(q=1;q<s;++q){r=b.$2(r,a[q])
if(s!==a.length)throw A.d(A.N(a))}return r},
F(a,b,c,d){var s,r,q
d.a(b)
A.h(a).t(d).h("1(1,2)").a(c)
s=a.length
for(r=b,q=0;q<s;++q){r=c.$2(r,a[q])
if(a.length!==s)throw A.d(A.N(a))}return r},
C(a,b){if(!(b>=0&&b<a.length))return A.b(a,b)
return a[b]},
a3(a,b,c){if(b<0||b>a.length)throw A.d(A.a8(b,0,a.length,"start",null))
if(c<b||c>a.length)throw A.d(A.a8(c,b,a.length,"end",null))
if(b===c)return A.o([],A.h(a))
return A.o(a.slice(b,c),A.h(a))},
gN(a){if(a.length>0)return a[0]
throw A.d(A.aX())},
ga1(a){var s=a.length
if(s>0)return a[s-1]
throw A.d(A.aX())},
au(a,b,c,d,e){var s,r,q,p,o
A.h(a).h("c<1>").a(d)
a.$flags&2&&A.cD(a,5)
A.fW(b,c,a.length)
s=c-b
if(s===0)return
A.an(e,"skipCount")
if(t.j.b(d)){r=d
q=e}else{r=J.fs(d,e).aU(0,!1)
q=0}p=J.cB(r)
if(q+s>p.gl(r))throw A.d(A.i0())
if(q<b)for(o=s-1;o>=0;--o)a[b+o]=p.i(r,q+o)
else for(o=0;o<s;++o)a[b+o]=p.i(r,q+o)},
a0(a,b){var s,r
A.h(a).h("l(1)").a(b)
s=a.length
for(r=0;r<s;++r){if(b.$1(a[r]))return!0
if(a.length!==s)throw A.d(A.N(a))}return!1},
av(a,b){var s,r,q,p,o,n=A.h(a)
n.h("X(1,1)?").a(b)
a.$flags&2&&A.cD(a,"sort")
s=a.length
if(s<2)return
if(b==null)b=J.iX()
if(s===2){r=a[0]
q=a[1]
n=b.$2(r,q)
if(typeof n!=="number")return n.cb()
if(n>0){a[0]=q
a[1]=r}return}p=0
if(n.c.b(null))for(o=0;o<a.length;++o)if(a[o]===void 0){a[o]=null;++p}a.sort(A.jk(b,2))
if(p>0)this.bs(a,p)},
aZ(a){return this.av(a,null)},
bs(a,b){var s,r=a.length
for(;s=r-1,r>0;r=s)if(a[s]===null){a[s]=void 0;--b
if(b===0)break}},
gv(a){return a.length===0},
gX(a){return a.length!==0},
k(a){return A.fa(a,"[","]")},
gq(a){return new J.aE(a,a.length,A.h(a).h("aE<1>"))},
gB(a){return A.co(a)},
gl(a){return a.length},
i(a,b){A.aa(b)
if(!(b>=0&&b<a.length))throw A.d(A.eX(a,b))
return a[b]},
u(a,b,c){A.h(a).c.a(c)
a.$flags&2&&A.cD(a)
if(!(b>=0&&b<a.length))throw A.d(A.eX(a,b))
a[b]=c},
$ip:1,
$ic:1,
$iv:1}
J.cf.prototype={
c5(a){var s,r,q
if(!Array.isArray(a))return null
s=a.$flags|0
if((s&4)!==0)r="const, "
else if((s&2)!==0)r="unmodifiable, "
else r=(s&1)!==0?"fixed, ":""
q="Instance of '"+A.cp(a)+"'"
if(r==="")return q
return q+" ("+r+"length: "+a.length+")"}}
J.ea.prototype={}
J.aE.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
n(){var s,r=this,q=r.a,p=q.length
if(r.b!==p){q=A.ab(q)
throw A.d(q)}s=r.c
if(s>=p){r.d=null
return!1}r.d=q[s]
r.c=s+1
return!0},
$iw:1}
J.aY.prototype={
E(a,b){var s
A.t(b)
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){s=this.gaa(b)
if(this.gaa(a)===s)return 0
if(this.gaa(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gaa(a){return a===0?1/a<0:a<0},
c2(a){var s
if(a>=-2147483648&&a<=2147483647)return a|0
if(isFinite(a)){s=a<0?Math.ceil(a):Math.floor(a)
return s+0}throw A.d(A.eC(""+a+".toInt()"))},
ab(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.d(A.eC(""+a+".round()"))},
j(a,b,c){if(this.E(b,c)>0)throw A.d(A.hn(b))
if(this.E(a,b)<0)return b
if(this.E(a,c)>0)return c
return a},
aV(a,b){var s
if(b>20)throw A.d(A.a8(b,0,20,"fractionDigits",null))
s=a.toFixed(b)
if(a===0&&this.gaa(a))return"-"+s
return s},
k(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gB(a){var s,r,q,p,o=a|0
if(a===o)return o&536870911
s=Math.abs(a)
r=Math.log(s)/0.6931471805599453|0
q=Math.pow(2,r)
p=s<1?s/q:q/s
return((p*9007199254740992|0)+(p*3542243181176521|0))*599197+r*1259&536870911},
T(a,b){var s=a%b
if(s===0)return 0
if(s>0)return s
return s+b},
A(a,b){return(a|0)===a?a/b|0:this.bE(a,b)},
bE(a,b){var s=a/b
if(s>=-2147483648&&s<=2147483647)return s|0
if(s>0){if(s!==1/0)return Math.floor(s)}else if(s>-1/0)return Math.ceil(s)
throw A.d(A.eC("Result of truncating division is "+A.x(s)+": "+A.x(a)+" ~/ "+b))},
aK(a,b){var s
if(a>0)s=this.bz(a,b)
else{s=b>31?31:b
s=a>>s>>>0}return s},
bz(a,b){return b>31?0:a>>>b},
gS(a){return A.at(t.H)},
$iQ:1,
$ia:1,
$iJ:1}
J.bk.prototype={
gS(a){return A.at(t.S)},
$iaq:1,
$iX:1}
J.ch.prototype={
gS(a){return A.at(t.i)},
$iaq:1}
J.aH.prototype={
Y(a,b,c){return a.substring(b,A.fW(b,c,a.length))},
ar(a,b){var s,r
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.d(B.a3)
for(s=a,r="";;){if((b&1)===1)r=s+r
b=b>>>1
if(b===0)break
s+=s}return r},
c1(a,b,c){var s=b-a.length
if(s<=0)return a
return this.ar(c,s)+a},
E(a,b){var s
A.B(b)
if(a===b)s=0
else s=a<b?-1:1
return s},
k(a){return a},
gB(a){var s,r,q
for(s=a.length,r=0,q=0;q<s;++q){r=r+a.charCodeAt(q)&536870911
r=r+((r&524287)<<10)&536870911
r^=r>>6}r=r+((r&67108863)<<3)&536870911
r^=r>>11
return r+((r&16383)<<15)&536870911},
gS(a){return A.at(t.N)},
gl(a){return a.length},
i(a,b){A.aa(b)
if(!(b.ca(0,0)&&b.cd(0,a.length)))throw A.d(A.eX(a,b))
return a[b]},
$iaq:1,
$iQ:1,
$ie:1}
A.b4.prototype={
gq(a){return new A.ba(J.a2(this.gV()),A.i(this).h("ba<1,2>"))},
gl(a){return J.aD(this.gV())},
gv(a){return J.fr(this.gV())},
gX(a){return J.hM(this.gV())},
K(a,b){var s=A.i(this)
return A.fx(J.fs(this.gV(),b),s.c,s.y[1])},
k(a){return J.aT(this.gV())}}
A.ba.prototype={
n(){return this.a.n()},
gp(){return this.$ti.y[1].a(this.a.gp())},
$iw:1}
A.aF.prototype={
gV(){return this.a}}
A.bK.prototype={$ip:1}
A.cl.prototype={
k(a){return"LateInitializationError: "+this.a}}
A.eo.prototype={}
A.p.prototype={}
A.q.prototype={
gq(a){var s=this
return new A.bs(s,s.gl(s),A.i(s).h("bs<q.E>"))},
gv(a){return this.gl(this)===0},
a0(a,b){var s,r,q=this
A.i(q).h("l(q.E)").a(b)
s=q.gl(q)
for(r=0;r<s;++r){if(b.$1(q.C(0,r)))return!0
if(s!==q.gl(q))throw A.d(A.N(q))}return!1},
J(a,b){var s,r,q,p=this
A.i(p).h("q.E(q.E,q.E)").a(b)
s=p.gl(p)
if(s===0)throw A.d(A.aX())
r=p.C(0,0)
for(q=1;q<s;++q){r=b.$2(r,p.C(0,q))
if(s!==p.gl(p))throw A.d(A.N(p))}return r},
K(a,b){return A.ep(this,b,null,A.i(this).h("q.E"))}}
A.bD.prototype={
gbb(){var s=J.aD(this.a),r=this.c
if(r==null||r>s)return s
return r},
gbA(){var s=J.aD(this.a),r=this.b
if(r>s)return s
return r},
gl(a){var s,r=J.aD(this.a),q=this.b
if(q>=r)return 0
s=this.c
if(s==null||s>=r)return r-q
return s-q},
C(a,b){var s=this,r=s.gbA()+b
if(b<0||r>=s.gbb())throw A.d(A.e7(b,s.gl(0),s,null,"index"))
return J.fq(s.a,r)},
K(a,b){var s,r,q=this
A.an(b,"count")
s=q.b+b
r=q.c
if(r!=null&&s>=r)return new A.bg(q.$ti.h("bg<1>"))
return A.ep(q.a,s,r,q.$ti.c)},
aU(a,b){var s,r,q,p=this,o=p.b,n=p.a,m=J.cB(n),l=m.gl(n),k=p.c
if(k!=null&&k<l)l=k
s=l-o
if(s<=0){n=J.fG(0,p.$ti.c)
return n}r=A.bt(s,m.C(n,o),!1,p.$ti.c)
for(q=1;q<s;++q){B.a.u(r,q,m.C(n,o+q))
if(m.gl(n)<l)throw A.d(A.N(p))}return r}}
A.bs.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
n(){var s,r=this,q=r.a,p=q.gl(q)
if(r.b!==p)throw A.d(A.N(q))
s=r.c
if(s>=p){r.d=null
return!1}r.d=q.C(0,s);++r.c
return!0},
$iw:1}
A.am.prototype={
gq(a){return new A.bw(J.a2(this.a),this.b,A.i(this).h("bw<1,2>"))},
gl(a){return J.aD(this.a)},
gv(a){return J.fr(this.a)}}
A.bf.prototype={$ip:1}
A.bw.prototype={
n(){var s=this,r=s.b
if(r.n()){s.a=s.c.$1(r.gp())
return!0}s.a=null
return!1},
gp(){var s=this.a
return s==null?this.$ti.y[1].a(s):s},
$iw:1}
A.f.prototype={
gl(a){return J.aD(this.a)},
C(a,b){return this.b.$1(J.fq(this.a,b))}}
A.z.prototype={
gq(a){return new A.a0(J.a2(this.a),this.b,this.$ti.h("a0<1>"))}}
A.a0.prototype={
n(){var s,r
for(s=this.a,r=this.b;s.n();)if(r.$1(s.gp()))return!0
return!1},
gp(){return this.a.gp()},
$iw:1}
A.bi.prototype={
gq(a){return new A.bj(J.a2(this.a),this.b,B.x,this.$ti.h("bj<1,2>"))}}
A.bj.prototype={
gp(){var s=this.d
return s==null?this.$ti.y[1].a(s):s},
n(){var s,r,q=this,p=q.c
if(p==null)return!1
for(s=q.a,r=q.b;!p.n();){q.d=null
if(s.n()){q.c=null
p=J.a2(r.$1(s.gp()))
q.c=p}else return!1}q.d=q.c.gp()
return!0},
$iw:1}
A.ao.prototype={
K(a,b){A.cU(b,"count",t.S)
A.an(b,"count")
return new A.ao(this.a,this.b+b,A.i(this).h("ao<1>"))},
gq(a){var s=this.a
return new A.bA(s.gq(s),this.b,A.i(this).h("bA<1>"))}}
A.aV.prototype={
gl(a){var s=this.a,r=s.gl(s)-this.b
if(r>=0)return r
return 0},
K(a,b){A.cU(b,"count",t.S)
A.an(b,"count")
return new A.aV(this.a,this.b+b,this.$ti)},
$ip:1}
A.bA.prototype={
n(){var s,r
for(s=this.a,r=0;r<this.b;++r)s.n()
this.b=0
return s.n()},
gp(){return this.a.gp()},
$iw:1}
A.bg.prototype={
gq(a){return B.x},
gv(a){return!0},
gl(a){return 0},
K(a,b){A.an(b,"count")
return this}}
A.bh.prototype={
n(){return!1},
gp(){throw A.d(A.aX())},
$iw:1}
A.bd.prototype={}
A.bc.prototype={
gv(a){return this.gl(this)===0},
k(a){return A.ek(this)},
a2(a,b,c,d){var s=A.aI(c,d)
this.H(0,new A.di(this,A.i(this).t(c).t(d).h("E<1,2>(3,4)").a(b),s))
return s},
$ir:1}
A.di.prototype={
$2(a,b){var s=A.i(this.a),r=this.b.$2(s.c.a(a),s.y[1].a(b))
this.c.u(0,r.a,r.b)},
$S(){return A.i(this.a).h("~(1,2)")}}
A.af.prototype={
gl(a){return this.b.length},
gbi(){var s=this.$keys
if(s==null){s=Object.keys(this.a)
this.$keys=s}return s},
bQ(a){if(typeof a!="string")return!1
if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
i(a,b){if(!this.bQ(b))return null
return this.b[this.a[b]]},
H(a,b){var s,r,q,p
this.$ti.h("~(1,2)").a(b)
s=this.gbi()
r=this.b
for(q=s.length,p=0;p<q;++p)b.$2(s[p],r[p])}}
A.cc.prototype={
M(a,b){if(b==null)return!1
return b instanceof A.aW&&this.a.M(0,b.a)&&A.fm(this)===A.fm(b)},
gB(a){return A.fN(this.a,A.fm(this))},
k(a){var s=B.a.c0([A.at(this.$ti.c)],", ")
return this.a.k(0)+" with "+("<"+s+">")}}
A.aW.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.jx(A.eV(this.a),this.$ti)}}
A.bz.prototype={}
A.eA.prototype={
I(a){var s,r,q=this,p=new RegExp(q.a).exec(a)
if(p==null)return null
s=Object.create(null)
r=q.b
if(r!==-1)s.arguments=p[r+1]
r=q.c
if(r!==-1)s.argumentsExpr=p[r+1]
r=q.d
if(r!==-1)s.expr=p[r+1]
r=q.e
if(r!==-1)s.method=p[r+1]
r=q.f
if(r!==-1)s.receiver=p[r+1]
return s}}
A.bx.prototype={
k(a){return"Null check operator used on a null value"}}
A.cj.prototype={
k(a){var s,r=this,q="NoSuchMethodError: method not found: '",p=r.b
if(p==null)return"NoSuchMethodError: "+r.a
s=r.c
if(s==null)return q+p+"' ("+r.a+")"
return q+p+"' on '"+s+"' ("+r.a+")"}}
A.cu.prototype={
k(a){var s=this.a
return s.length===0?"Error":"Error: "+s}}
A.em.prototype={
k(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.K.prototype={
k(a){var s=this.constructor,r=s==null?null:s.name
return"Closure '"+A.hw(r==null?"unknown":r)+"'"},
$iai:1,
gc8(){return this},
$C:"$1",
$R:1,
$D:null}
A.bY.prototype={$C:"$0",$R:0}
A.bZ.prototype={$C:"$2",$R:2}
A.cs.prototype={}
A.cr.prototype={
k(a){var s=this.$static_name
if(s==null)return"Closure of unknown static method"
return"Closure '"+A.hw(s)+"'"}}
A.aU.prototype={
M(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.aU))return!1
return this.$_target===b.$_target&&this.a===b.a},
gB(a){return(A.hu(this.a)^A.co(this.$_target))>>>0},
k(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.cp(this.a)+"'")}}
A.cq.prototype={
k(a){return"RuntimeError: "+this.a}}
A.aj.prototype={
gl(a){return this.a},
gv(a){return this.a===0},
gR(){return new A.ak(this,A.i(this).h("ak<1>"))},
L(a,b){A.i(this).h("r<1,2>").a(b).H(0,new A.eb(this))},
i(a,b){var s,r,q,p,o=null
if(typeof b=="string"){s=this.b
if(s==null)return o
r=s[b]
q=r==null?o:r.b
return q}else if(typeof b=="number"&&(b&0x3fffffff)===b){p=this.c
if(p==null)return o
r=p[b]
q=r==null?o:r.b
return q}else return this.bX(b)},
bX(a){var s,r,q=this.d
if(q==null)return null
s=q[this.aR(a)]
r=this.aS(s,a)
if(r<0)return null
return s[r].b},
u(a,b,c){var s,r,q=this,p=A.i(q)
p.c.a(b)
p.y[1].a(c)
if(typeof b=="string"){s=q.b
q.aw(s==null?q.b=q.aj():s,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){r=q.c
q.aw(r==null?q.c=q.aj():r,b,c)}else q.bY(b,c)},
bY(a,b){var s,r,q,p,o=this,n=A.i(o)
n.c.a(a)
n.y[1].a(b)
s=o.d
if(s==null)s=o.d=o.aj()
r=o.aR(a)
q=s[r]
if(q==null)s[r]=[o.ak(a,b)]
else{p=o.aS(q,a)
if(p>=0)q[p].b=b
else q.push(o.ak(a,b))}},
H(a,b){var s,r,q=this
A.i(q).h("~(1,2)").a(b)
s=q.e
r=q.r
while(s!=null){b.$2(s.a,s.b)
if(r!==q.r)throw A.d(A.N(q))
s=s.c}},
aw(a,b,c){var s,r=A.i(this)
r.c.a(b)
r.y[1].a(c)
s=a[b]
if(s==null)a[b]=this.ak(b,c)
else s.b=c},
ak(a,b){var s=this,r=A.i(s),q=new A.ef(r.c.a(a),r.y[1].a(b))
if(s.e==null)s.e=s.f=q
else s.f=s.f.c=q;++s.a
s.r=s.r+1&1073741823
return q},
aR(a){return J.b9(a)&1073741823},
aS(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.cE(a[r].a,b))return r
return-1},
k(a){return A.ek(this)},
aj(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
$ifI:1}
A.eb.prototype={
$2(a,b){var s=this.a,r=A.i(s)
s.u(0,r.c.a(a),r.y[1].a(b))},
$S(){return A.i(this.a).h("~(1,2)")}}
A.ef.prototype={}
A.ak.prototype={
gl(a){return this.a.a},
gv(a){return this.a.a===0},
gq(a){var s=this.a
return new A.bq(s,s.r,s.e,this.$ti.h("bq<1>"))}}
A.bq.prototype={
gp(){return this.d},
n(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.d(A.N(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.a
r.c=s.c
return!0}},
$iw:1}
A.al.prototype={
gl(a){return this.a.a},
gv(a){return this.a.a===0},
gq(a){var s=this.a
return new A.br(s,s.r,s.e,this.$ti.h("br<1>"))}}
A.br.prototype={
gp(){return this.d},
n(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.d(A.N(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.b
r.c=s.c
return!0}},
$iw:1}
A.bo.prototype={
gl(a){return this.a.a},
gv(a){return this.a.a===0},
gq(a){var s=this.a
return new A.bp(s,s.r,s.e,this.$ti.h("bp<1,2>"))}}
A.bp.prototype={
gp(){var s=this.d
s.toString
return s},
n(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.d(A.N(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=new A.E(s.a,s.b,r.$ti.h("E<1,2>"))
r.c=s.c
return!0}},
$iw:1}
A.ci.prototype={
k(a){return"RegExp/"+this.a+"/"+this.b.flags},
bU(a){var s=this.b.exec(a)
if(s==null)return null
return new A.eK(s)},
$iib:1}
A.eK.prototype={
i(a,b){var s
A.aa(b)
s=this.b
if(!(b<s.length))return A.b(s,b)
return s[b]}}
A.a_.prototype={
h(a){return A.eN(v.typeUniverse,this,a)},
t(a){return A.iB(v.typeUniverse,this,a)}}
A.cw.prototype={}
A.eL.prototype={
k(a){return A.M(this.a,null)}}
A.cv.prototype={
k(a){return this.a}}
A.b5.prototype={}
A.as.prototype={
gq(a){var s=this,r=new A.aN(s,s.r,A.i(s).h("aN<1>"))
r.c=s.e
return r},
gl(a){return this.a},
gv(a){return this.a===0},
gX(a){return this.a!==0},
a9(a,b){var s,r
if(typeof b=="string"&&b!=="__proto__"){s=this.b
if(s==null)return!1
return t.M.a(s[b])!=null}else{r=this.b6(b)
return r}},
b6(a){var s=this.d
if(s==null)return!1
return this.aC(s[this.aA(a)],a)>=0},
m(a,b){var s,r,q=this
A.i(q).c.a(b)
if(typeof b=="string"&&b!=="__proto__"){s=q.b
return q.az(s==null?q.b=A.fg():s,b)}else if(typeof b=="number"&&(b&1073741823)===b){r=q.c
return q.az(r==null?q.c=A.fg():r,b)}else return q.b1(b)},
b1(a){var s,r,q,p=this
A.i(p).c.a(a)
s=p.d
if(s==null)s=p.d=A.fg()
r=p.aA(a)
q=s[r]
if(q==null)s[r]=[p.ae(a)]
else{if(p.aC(q,a)>=0)return!1
q.push(p.ae(a))}return!0},
az(a,b){A.i(this).c.a(b)
if(t.M.a(a[b])!=null)return!1
a[b]=this.ae(b)
return!0},
ae(a){var s=this,r=new A.cz(A.i(s).c.a(a))
if(s.e==null)s.e=s.f=r
else s.f=s.f.b=r;++s.a
s.r=s.r+1&1073741823
return r},
aA(a){return J.b9(a)&1073741823},
aC(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.cE(a[r].a,b))return r
return-1},
$ifK:1}
A.cz.prototype={}
A.aN.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
n(){var s=this,r=s.c,q=s.a
if(s.b!==q.r)throw A.d(A.N(q))
else if(r==null){s.d=null
return!1}else{s.d=s.$ti.h("1?").a(r.a)
s.c=r.b
return!0}},
$iw:1}
A.eg.prototype={
$2(a,b){this.a.u(0,this.b.a(a),this.c.a(b))},
$S:45}
A.I.prototype={
H(a,b){var s,r,q,p=A.i(this)
p.h("~(I.K,I.V)").a(b)
for(s=this.gR(),s=s.gq(s),p=p.h("I.V");s.n();){r=s.gp()
q=this.i(0,r)
b.$2(r,q==null?p.a(q):q)}},
a2(a,b,c,d){var s,r,q,p,o,n=A.i(this)
n.t(c).t(d).h("E<1,2>(I.K,I.V)").a(b)
s=A.aI(c,d)
for(r=this.gR(),r=r.gq(r),n=n.h("I.V");r.n();){q=r.gp()
p=this.i(0,q)
o=b.$2(q,p==null?n.a(p):p)
s.u(0,o.a,o.b)}return s},
gl(a){var s=this.gR()
return s.gl(s)},
gv(a){var s=this.gR()
return s.gv(s)},
k(a){return A.ek(this)},
$ir:1}
A.el.prototype={
$2(a,b){var s,r=this.a
if(!r.a)this.b.a+=", "
r.a=!1
r=this.b
s=A.x(a)
r.a=(r.a+=s)+": "
s=A.x(b)
r.a+=s},
$S:10}
A.bQ.prototype={}
A.b1.prototype={
i(a,b){return this.a.i(0,b)},
H(a,b){this.a.H(0,this.$ti.h("~(1,2)").a(b))},
gv(a){return this.a.a===0},
gl(a){return this.a.a},
k(a){return A.ek(this.a)},
a2(a,b,c,d){return this.a.a2(0,this.$ti.t(c).t(d).h("E<1,2>(3,4)").a(b),c,d)},
$ir:1}
A.bH.prototype={}
A.eh.prototype={
gq(a){var s=this
return new A.bL(s,s.c,s.d,s.b,s.$ti.h("bL<1>"))},
gv(a){return this.b===this.c},
gl(a){return(this.c-this.b&this.a.length-1)>>>0},
C(a,b){var s,r,q=this,p=q.gl(0)
if(0>b||b>=p)A.aS(A.e7(b,p,q,null,"index"))
p=q.a
s=p.length
r=(q.b+b&s-1)>>>0
if(!(r>=0&&r<s))return A.b(p,r)
r=p[r]
return r==null?q.$ti.c.a(r):r},
k(a){return A.fa(this,"{","}")}}
A.bL.prototype={
gp(){var s=this.e
return s==null?this.$ti.c.a(s):s},
n(){var s,r,q=this,p=q.a
if(q.c!==p.d)A.aS(A.N(p))
s=q.d
if(s===q.b){q.e=null
return!1}p=p.a
r=p.length
if(!(s<r))return A.b(p,s)
q.e=p[s]
q.d=(s+1&r-1)>>>0
return!0},
$iw:1}
A.aM.prototype={
gv(a){return this.gl(this)===0},
gX(a){return this.gl(this)!==0},
L(a,b){var s,r,q
A.i(this).h("c<1>").a(b)
for(s=b.gq(b),r=s.$ti.c;s.n();){q=s.d
this.m(0,q==null?r.a(q):q)}},
k(a){return A.fa(this,"{","}")},
K(a,b){return A.fY(this,b,A.i(this).c)},
$ip:1,
$ic:1,
$iaL:1}
A.bM.prototype={}
A.cA.prototype={
m(a,b){this.$ti.c.a(b)
return A.iE()}}
A.bI.prototype={
a9(a,b){return this.a.a9(0,b)},
gl(a){return this.a.a},
gq(a){var s=this.a
return A.il(s,s.r,A.i(s).c)}}
A.b6.prototype={}
A.bR.prototype={}
A.cx.prototype={
i(a,b){var s,r=this.b
if(r==null)return this.c.i(0,b)
else if(typeof b!="string")return null
else{s=r[b]
return typeof s=="undefined"?this.bo(b):s}},
gl(a){return this.b==null?this.c.a:this.a5().length},
gv(a){return this.gl(0)===0},
gR(){if(this.b==null){var s=this.c
return new A.ak(s,A.i(s).h("ak<1>"))}return new A.cy(this)},
H(a,b){var s,r,q,p,o=this
t.cA.a(b)
if(o.b==null)return o.c.H(0,b)
s=o.a5()
for(r=0;r<s.length;++r){q=s[r]
p=o.b[q]
if(typeof p=="undefined"){p=A.eS(o.a[q])
o.b[q]=p}b.$2(q,p)
if(s!==o.c)throw A.d(A.N(o))}},
a5(){var s=t.bF.a(this.c)
if(s==null)s=this.c=A.o(Object.keys(this.a),t.s)
return s},
bo(a){var s
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
s=A.eS(this.a[a])
return this.b[a]=s}}
A.cy.prototype={
gl(a){return this.a.gl(0)},
C(a,b){var s=this.a
if(s.b==null)s=s.gR().C(0,b)
else{s=s.a5()
if(!(b>=0&&b<s.length))return A.b(s,b)
s=s[b]}return s},
gq(a){var s=this.a
if(s.b==null){s=s.gR()
s=s.gq(s)}else{s=s.a5()
s=new J.aE(s,s.length,A.h(s).h("aE<1>"))}return s}}
A.c_.prototype={}
A.c2.prototype={}
A.bn.prototype={
k(a){var s=A.c9(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+s}}
A.ck.prototype={
k(a){return"Cyclic error in JSON stringify"}}
A.ec.prototype={
aO(a,b){var s=A.j9(a,this.gbR().a)
return s},
aP(a,b){var s=A.ik(a,this.gbS().b,null)
return s},
gbS(){return B.ax},
gbR(){return B.aw}}
A.ee.prototype={}
A.ed.prototype={}
A.eI.prototype={
aX(a){var s,r,q,p,o,n,m=a.length
for(s=this.c,r=0,q=0;q<m;++q){p=a.charCodeAt(q)
if(p>92){if(p>=55296){o=p&64512
if(o===55296){n=q+1
n=!(n<m&&(a.charCodeAt(n)&64512)===56320)}else n=!1
if(!n)if(o===56320){o=q-1
o=!(o>=0&&(a.charCodeAt(o)&64512)===55296)}else o=!1
else o=!0
if(o){if(q>r)s.a+=B.e.Y(a,r,q)
r=q+1
o=A.H(92)
s.a+=o
o=A.H(117)
s.a+=o
o=A.H(100)
s.a+=o
o=p>>>8&15
o=A.H(o<10?48+o:87+o)
s.a+=o
o=p>>>4&15
o=A.H(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.H(o<10?48+o:87+o)
s.a+=o}}continue}if(p<32){if(q>r)s.a+=B.e.Y(a,r,q)
r=q+1
o=A.H(92)
s.a+=o
switch(p){case 8:o=A.H(98)
s.a+=o
break
case 9:o=A.H(116)
s.a+=o
break
case 10:o=A.H(110)
s.a+=o
break
case 12:o=A.H(102)
s.a+=o
break
case 13:o=A.H(114)
s.a+=o
break
default:o=A.H(117)
s.a+=o
o=A.H(48)
s.a=(s.a+=o)+o
o=p>>>4&15
o=A.H(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.H(o<10?48+o:87+o)
s.a+=o
break}}else if(p===34||p===92){if(q>r)s.a+=B.e.Y(a,r,q)
r=q+1
o=A.H(92)
s.a+=o
o=A.H(p)
s.a+=o}}if(r===0)s.a+=a
else if(r<m)s.a+=B.e.Y(a,r,m)},
ad(a){var s,r,q,p
for(s=this.a,r=s.length,q=0;q<r;++q){p=s[q]
if(a==null?p==null:a===p)throw A.d(new A.ck(a,null))}B.a.m(s,a)},
ac(a){var s,r,q,p,o=this
if(o.aW(a))return
o.ad(a)
try{s=o.b.$1(a)
if(!o.aW(s)){q=A.fH(a,null,o.gaI())
throw A.d(q)}q=o.a
if(0>=q.length)return A.b(q,-1)
q.pop()}catch(p){r=A.fo(p)
q=A.fH(a,r,o.gaI())
throw A.d(q)}},
aW(a){var s,r,q=this
if(typeof a=="number"){if(!isFinite(a))return!1
q.c.a+=B.b.k(a)
return!0}else if(a===!0){q.c.a+="true"
return!0}else if(a===!1){q.c.a+="false"
return!0}else if(a==null){q.c.a+="null"
return!0}else if(typeof a=="string"){s=q.c
s.a+='"'
q.aX(a)
s.a+='"'
return!0}else if(t.j.b(a)){q.ad(a)
q.c6(a)
s=q.a
if(0>=s.length)return A.b(s,-1)
s.pop()
return!0}else if(t.eO.b(a)){q.ad(a)
r=q.c7(a)
s=q.a
if(0>=s.length)return A.b(s,-1)
s.pop()
return r}else return!1},
c6(a){var s,r,q=this.c
q.a+="["
s=J.bS(a)
if(s.gX(a)){this.ac(s.i(a,0))
for(r=1;r<s.gl(a);++r){q.a+=","
this.ac(s.i(a,r))}}q.a+="]"},
c7(a){var s,r,q,p,o,n,m=this,l={}
if(a.gv(a)){m.c.a+="{}"
return!0}s=a.gl(a)*2
r=A.bt(s,null,!1,t.U)
q=l.a=0
l.b=!0
a.H(0,new A.eJ(l,r))
if(!l.b)return!1
p=m.c
p.a+="{"
for(o='"';q<s;q+=2,o=',"'){p.a+=o
m.aX(A.B(r[q]))
p.a+='":'
n=q+1
if(!(n<s))return A.b(r,n)
m.ac(r[n])}p.a+="}"
return!0}}
A.eJ.prototype={
$2(a,b){var s,r
if(typeof a!="string")this.a.b=!1
s=this.b
r=this.a
B.a.u(s,r.a++,a)
B.a.u(s,r.a++,b)},
$S:10}
A.eH.prototype={
gaI(){var s=this.c.a
return s.charCodeAt(0)==0?s:s}}
A.ds.prototype={
$0(){var s=this
return A.aS(A.f9("("+s.a+", "+s.b+", "+s.c+", "+s.d+", "+s.e+", "+s.f+", "+s.r+", "+s.w+")"))},
$S:19}
A.a4.prototype={
O(a){var s=1000,r=B.c.T(a,s),q=B.c.A(a-r,s),p=this.b+r,o=B.c.T(p,s),n=this.c
return new A.a4(A.fC(this.a+B.c.A(p-o,s)+q,o,n),o,n)},
W(a){return A.D(this.b-a.b,this.a-a.a)},
M(a,b){if(b==null)return!1
return b instanceof A.a4&&this.a===b.a&&this.b===b.b&&this.c===b.c},
gB(a){return A.fN(this.a,this.b)},
c_(a){var s=this.a,r=a.a
if(s>=r)s=s===r&&this.b<a.b
else s=!0
return s},
bZ(a){var s=this.a,r=a.a
if(s<=r)s=s===r&&this.b>a.b
else s=!0
return s},
E(a,b){var s
t.dy.a(b)
s=B.c.E(this.a,b.a)
if(s!==0)return s
return B.c.E(this.b,b.b)},
c4(){var s=this
if(s.c)return s
return new A.a4(s.a,s.b,!0)},
k(a){var s=this,r=A.fB(A.cn(s)),q=A.ag(A.fT(s)),p=A.ag(A.fP(s)),o=A.ag(A.fQ(s)),n=A.ag(A.fS(s)),m=A.ag(A.fU(s)),l=A.dt(A.fR(s)),k=s.b,j=k===0?"":A.dt(k)
k=r+"-"+q
if(s.c)return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j},
c3(){var s=this,r=A.cn(s)>=-9999&&A.cn(s)<=9999?A.fB(A.cn(s)):A.hZ(A.cn(s)),q=A.ag(A.fT(s)),p=A.ag(A.fP(s)),o=A.ag(A.fQ(s)),n=A.ag(A.fS(s)),m=A.ag(A.fU(s)),l=A.dt(A.fR(s)),k=s.b,j=k===0?"":A.dt(k)
k=r+"-"+q
if(s.c)return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j},
$iQ:1}
A.du.prototype={
$1(a){if(a==null)return 0
return A.cC(a)},
$S:12}
A.dv.prototype={
$1(a){var s,r,q
if(a==null)return 0
for(s=a.length,r=0,q=0;q<6;++q){r*=10
if(q<s){if(!(q<s))return A.b(a,q)
r+=a.charCodeAt(q)^48}}return r},
$S:12}
A.L.prototype={
M(a,b){if(b==null)return!1
return b instanceof A.L&&this.a===b.a},
gB(a){return B.c.gB(this.a)},
E(a,b){return B.c.E(this.a,t.fu.a(b).a)},
k(a){var s,r,q,p,o,n=this.a,m=B.c.A(n,36e8),l=n%36e8
if(n<0){m=0-m
n=0-l
s="-"}else{n=l
s=""}r=B.c.A(n,6e7)
n%=6e7
q=r<10?"0":""
p=B.c.A(n,1e6)
o=p<10?"0":""
return s+m+":"+q+r+":"+o+p+"."+B.e.c1(B.c.k(n%1e6),6,"0")},
$iQ:1}
A.eE.prototype={
k(a){return this.D()}}
A.u.prototype={}
A.bW.prototype={
k(a){var s=this.a
if(s!=null)return"Assertion failed: "+A.c9(s)
return"Assertion failed"}}
A.bG.prototype={}
A.ac.prototype={
gah(){return"Invalid argument"+(!this.a?"(s)":"")},
gag(){return""},
k(a){var s=this,r=s.c,q=r==null?"":" ("+r+")",p=s.d,o=p==null?"":": "+p,n=s.gah()+q+o
if(!s.a)return n
return n+s.gag()+": "+A.c9(s.gap())},
gap(){return this.b}}
A.by.prototype={
gap(){return A.hd(this.b)},
gah(){return"RangeError"},
gag(){var s,r=this.e,q=this.f
if(r==null)s=q!=null?": Not less than or equal to "+A.x(q):""
else if(q==null)s=": Not greater than or equal to "+A.x(r)
else if(q>r)s=": Not in inclusive range "+A.x(r)+".."+A.x(q)
else s=q<r?": Valid value range is empty":": Only valid value is "+A.x(r)
return s}}
A.cb.prototype={
gap(){return A.aa(this.b)},
gah(){return"RangeError"},
gag(){if(A.aa(this.b)<0)return": index must not be negative"
var s=this.f
if(s===0)return": no indices are valid"
return": index should be less than "+s},
gl(a){return this.f}}
A.bJ.prototype={
k(a){return"Unsupported operation: "+this.a}}
A.bC.prototype={
k(a){return"Bad state: "+this.a}}
A.c1.prototype={
k(a){var s=this.a
if(s==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.c9(s)+"."}}
A.cm.prototype={
k(a){return"Out of Memory"},
$iu:1}
A.bB.prototype={
k(a){return"Stack Overflow"},
$iu:1}
A.eF.prototype={
k(a){return"Exception: "+this.a}}
A.e6.prototype={
k(a){var s=this.a,r=""!==s?"FormatException: "+s:"FormatException",q=this.b
if(typeof q=="string"){if(q.length>78)q=B.e.Y(q,0,75)+"..."
return r+"\n"+q}else return r}}
A.c.prototype={
aT(a,b,c){var s=A.i(this)
return A.i8(this,s.t(c).h("1(c.E)").a(b),s.h("c.E"),c)},
F(a,b,c,d){var s,r
d.a(b)
A.i(this).t(d).h("1(1,c.E)").a(c)
for(s=this.gq(this),r=b;s.n();)r=c.$2(r,s.gp())
return r},
aU(a,b){var s=A.i(this).h("c.E")
if(b)s=A.y(this,s)
else{s=A.y(this,s)
s.$flags=1
s=s}return s},
gl(a){var s,r=this.gq(this)
for(s=0;r.n();)++s
return s},
gv(a){return!this.gq(this).n()},
gX(a){return!this.gv(this)},
K(a,b){return A.fY(this,b,A.i(this).h("c.E"))},
bV(a,b,c){var s,r=A.i(this)
r.h("l(c.E)").a(b)
r.h("c.E()?").a(c)
for(r=this.gq(this);r.n();){s=r.gp()
if(b.$1(s))return s}r=c.$0()
return r},
C(a,b){var s,r
A.an(b,"index")
s=this.gq(this)
for(r=b;s.n();){if(r===0)return s.gp();--r}throw A.d(A.e7(b,b-r,this,null,"index"))},
k(a){return A.i1(this,"(",")")}}
A.E.prototype={
k(a){return"MapEntry("+A.x(this.a)+": "+A.x(this.b)+")"}}
A.aK.prototype={
gB(a){return A.j.prototype.gB.call(this,0)},
k(a){return"null"}}
A.j.prototype={$ij:1,
M(a,b){return this===b},
gB(a){return A.co(this)},
k(a){return"Instance of '"+A.cp(this)+"'"},
gS(a){return A.jt(this)},
toString(){return this.k(this)}}
A.b2.prototype={
gl(a){return this.a.length},
k(a){var s=this.a
return s.charCodeAt(0)==0?s:s},
$iie:1}
A.cG.prototype={
G(a){var s,r,q,p,o,n,m=A.o([],t.g)
for(s=a.P(B.k),r=J.a2(s.a),s=new A.a0(r,s.b,s.$ti.h("a0<1>")),q=0;s.n();){p=r.gp()
o=p.at
n=Math.max(o.c,o.d)
o=!0
if(p.ax===B.t)if(!(p.x-p.w<4))o=n>=0.65&&p.y<12
if(o)++q
else B.a.m(m,p)}if(m.length===0)return new A.bV(0,!1,!1)
s=new A.cO(m)
return new A.bV(s.$1(new A.cQ(this))*25+s.$1(new A.cR(this,a))*15+s.$1(new A.cS(this,a))*10,!0,m.length>=2)},
b0(a,b){var s=B.a.a3(a.b,b.d,b.e+1),r=A.h(s),q=r.h("f<1,a>"),p=A.y(new A.f(s,r.h("a(1)").a(new A.cH()),q),q.h("q.E"))
return B.a.F(p,0,new A.cI(B.a.J(p,new A.cJ())/p.length),t.i)/p.length},
bw(a,b){var s=a.b,r=A.h(s),q=r.h("am<1,a>"),p=A.y(new A.am(new A.z(s,r.h("l(1)").a(new A.cK(b,b.r.O(4e6))),r.h("z<1>")),r.h("a(1)").a(new A.cL()),q),q.h("c.E"))
if(p.length<2)return 0
return 1-B.b.j(Math.sqrt(B.a.F(p,0,new A.cM(B.a.J(p,new A.cN())/p.length),t.i)/p.length)/3,0,1)}}
A.cO.prototype={
$1(a){var s=this.a,r=A.h(s)
return new A.f(s,r.h("a(1)").a(t.bE.a(a)),r.h("f<1,a>")).J(0,new A.cP())/s.length},
$S:16}
A.cP.prototype={
$2(a,b){return A.m(a)+A.m(b)},
$S:0}
A.cQ.prototype={
$1(a){t.F.a(a)
return B.b.j((a.x-a.w)/B.c.A(a.r.W(a.f).a,1000)*1000/2.5,0,1)},
$S:7}
A.cR.prototype={
$1(a){return 1-B.b.j(this.a.b0(this.b,t.F.a(a))/0.55,0,1)},
$S:7}
A.cS.prototype={
$1(a){return this.a.bw(this.b,t.F.a(a))},
$S:7}
A.cH.prototype={
$1(a){return t.K.a(a).e},
$S:3}
A.cJ.prototype={
$2(a,b){return A.m(a)+A.m(b)},
$S:0}
A.cI.prototype={
$2(a,b){var s
A.m(a)
s=A.m(b)-this.a
return a+s*s},
$S:0}
A.cK.prototype={
$1(a){t.K.a(a)
return a.a>this.a.e&&!a.b.c.bZ(this.b)},
$S:1}
A.cL.prototype={
$1(a){return t.K.a(a).b.d},
$S:3}
A.cN.prototype={
$2(a,b){return A.m(a)+A.m(b)},
$S:0}
A.cM.prototype={
$2(a,b){var s
A.m(a)
s=A.m(b)-this.a
return a+s*s},
$S:0}
A.cT.prototype={
$1(a){var s=this.a,r=s.r
return r+(s.w-r)*((a-s.e)/this.b)},
$S:13}
A.cW.prototype={
G(b4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0=this,b1=b4.P(B.n),b2=b1.$ti,b3=b2.h("z<c.E>")
b1=A.y(new A.z(b1,b2.h("l(c.E)").a(new A.d9()),b3),b3.h("c.E"))
b1.$flags=1
s=b1
b1=b4.P(B.F)
b1=A.y(b1,b1.$ti.h("c.E"))
b1.$flags=1
r=b1
b1=b4.P(B.h)
b1=A.y(b1,b1.$ti.h("c.E"))
b1.$flags=1
q=b1
p=A.o([],t.aS)
b1=t.n
o=A.o([],b1)
n=A.fM(t.N)
for(b2=s.length,m=0,l=0,k=0,j=0;j<s.length;s.length===b2||(0,A.ab)(s),++j){i=s[j]
if(!(i.as<=0)){b3=i.r
h=i.f
h=A.D(b3.b-h.b,b3.a-h.a).a<=0
b3=h}else b3=!0
if(b3){++m
continue}g=b0.be(i,q)
b3=i.at
f=B.b.j(1-Math.max(b3.c*0.25,b3.d*0.45),0,1)
if(f<1||g)++k
e=b0.aJ(b4,i)
d=b0.bx(e)
if(e>=5){++l
n.m(0,i.a)}b3=g?0.6:1
B.a.m(o,d*f*b3)
B.a.m(p,new A.aA(b0.b3(b4,i,g),Math.max(1,i.w-i.x)))}c=p.length===0
b=c?150:150*b0.bK(p)
a=o.length===0
a0=a?100:100*(1-b0.b2(o))
a1=b0.bd(b4,s)
a2=a1.length===0
a3=b0.bj(a1)
a4=a2?60:60*(1-a3)
b2=A.h(a1)
new A.z(a1,b2.h("l(1)").a(new A.da()),b2.h("z<1>")).gl(0)
a5=A.o([],b1)
for(b1=r.length,j=0;j<r.length;r.length===b1||(0,A.ab)(r),++j){a6=b0.bC(b4,r[j],s,n)
if(a6==null)++m
else B.a.m(a5,a6)}a7=a5.length===0
a8=a7?40:40*b0.U(a5)
a9=B.b.j(b+a0+a4+a8,0,350)
B.b.j(b,0,150)
B.b.j(a0,0,100)
B.b.j(a4,0,60)
B.b.j(a8,0,40)
return new A.db(a9,s.length,a5.length,new A.cV(c,a,a2,a7))},
b3(a,a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=a.b,d=a0.d,c=a0.e,b=e.length
if(!(d<b))return A.b(e,d)
s=e[d].b.d
if(!(c<b))return A.b(e,c)
r=e[c].b.d
q=Math.max(0,s-r)
if(q<=0)return 0.5
p=this.aF(e,d,c,0.5)
o=this.aF(e,d,c,0.6)
if(!(p<b))return A.b(e,p)
n=Math.max(0,s-e[p].b.d)
if(!(o<b))return A.b(e,o)
m=Math.max(0,e[o].b.d-r)
l=B.b.j(n/q/0.55,0,1)
k=B.b.j((m/q-0.35)/0.37,0,1)
j=A.o([],t.n)
for(i=d;i<=c;++i){if(!(i<b))return A.b(e,i)
B.a.m(j,e[i].e)}b=B.b.j(this.aL(j)/0.9,0,1)
h=e[d].b.c.O(-5e6)
g=A.ep(e,0,A.ho(d,"count",t.S),A.h(e).c).a0(0,new A.cX(h))?0.08:0
f=a1?0.1:0
return B.b.j(0.4*B.b.j(l+g+f,0,1)+0.3*(1-b)+0.3*(1-k),0,1)},
aJ(a,b){var s,r,q,p,o,n
for(s=b.d,r=b.e,q=a.b,p=q.length,o=0;s<=r;++s){if(!(s<p))return A.b(q,s)
n=q[s]
o=Math.max(o,Math.max(-n.b.x,-n.e))}return o},
bx(a){var s=this
if(a<=1.5)return 0
if(a<=2.5)return s.a4(0,0.15,(a-1.5)/1)
if(a<=3.5)return s.a4(0.15,0.35,(a-2.5)/1)
if(a<=5)return s.a4(0.35,0.75,(a-3.5)/1.5)
return s.a4(0.75,1,(a-5)/5)},
b2(a){var s
t.o.a(a)
s=this.U(a)
if(a.length===1)return Math.min(s,0.35)
return B.b.j(s*1.35,0,1)},
bd(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c
t.B.a(b)
s=a.P(B.k)
r=s.$ti
q=r.h("z<c.E>")
s=A.y(new A.z(s,r.h("l(c.E)").a(new A.cY()),q),q.h("c.E"))
s.$flags=1
p=s
o=A.o([],t.h9)
for(s=p.length,n=0;n<p.length;p.length===s||(0,A.ab)(p),++n){m=p[n]
l=m.x-m.w
if(l<3)continue
for(r=b.length,q=m.r,k=q.a,q=q.b,j=m.y,i=0;i<r;++i){h=b[i]
g=h.f
f=g.a
if(f>=k)e=f===k&&g.b<q
else e=!0
if(e)continue
d=A.D(g.b-q,f-k)
if(j<13.88888888888889)c=14
else c=j<25?10.5:7.5
if(d.a>A.D(0,B.b.ab(c*1000)).a)break
if(h.w-h.x<=0)continue
B.a.m(o,new A.a9(l,this.aJ(a,h),this.bk(h.at)))
break}}return o},
bj(a){var s,r,q,p,o
t.cT.a(a)
if(a.length===0)return 0
s=A.h(a)
r=s.h("a(1)")
s=s.h("f<1,a>")
q=this.U(new A.f(a,r.a(new A.d0(this)),s))
p=a.length
o=p===1?0.15:B.b.j(p/3,0.45,1)
return B.b.j(q*o*(1-this.U(new A.f(a,r.a(new A.d1()),s))),0,1)},
bC(a,b,a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=null
t.B.a(a0)
t.cq.a(a1)
s=this.bc(a,b.d)
if(s==null)return c
r=a.b
q=b.e
p=B.a.a3(r,s,q+1)
o=A.h(p)
if(new A.f(p,o.h("a(1)").a(new A.d3()),o.h("f<1,a>")).J(0,B.S)<4.166666666666667)return c
p=A.h(a0)
o=p.h("z<1>")
n=A.fx(new A.z(a0,p.h("l(1)").a(new A.d4(b)),o),o.h("c.E"),t.J).bV(0,new A.d5(),new A.d6())
if(n!=null&&a1.a9(0,n.a))return c
p=r.length
if(s>>>0!==s||s>=p)return A.b(r,s)
o=r[s]
if(!(q<p))return A.b(r,q)
m=r[q].b
l=Math.max(0,o.b.d-m.d)
if(l<=0)return c
k=m.c.O(-2e6)
o=k.a
m=k.b
i=s
for(;;){if(!(i<=q)){j=s
break}if(!(i<p))return A.b(r,i)
h=r[i].b.c
g=h.a
if(g>=o)h=g===o&&h.b<m
else h=!0
if(!h){j=i
break}++i}if(!(j<p))return A.b(r,j)
f=1-B.b.j((Math.max(0,r[j].b.d-r[q].b.d)/l-0.25)/0.30000000000000004,0,1)
e=A.o([],t.n)
for(i=j;i<=q;++i){if(!(i<p))return A.b(r,i)
B.a.m(e,r[i].e)}d=1-B.b.j(this.aL(e)/0.8,0,1)
return B.b.j(0.5*f+0.25*d+0.25*B.b.j((f+d)/2,0,1),0,1)},
bc(a,b){var s,r,q
for(s=a.b,r=s.length,q=b;q>=0;--q){if(!(q<r))return A.b(s,q)
if(s[q].b.d>=4.166666666666667)return q}return null},
be(a,b){t.B.a(b)
return a.ch.a9(0,B.r)||B.a.a0(a.CW,new A.d_(b))},
bk(a){var s=a.d,r=Math.max(a.c,s)
if(r<=0)return 0
return B.b.j(0.8*r+0.19999999999999996*s,0,1)},
aF(a,b,c,d){var s,r,q,p,o,n,m
t.X.a(a)
s=a.length
if(!(b<s))return A.b(a,b)
r=a[b].b.c
if(!(c<s))return A.b(a,c)
q=r.O(A.D(0,B.b.ab(B.c.A(a[c].b.c.W(r).a,1000)*d)).a)
for(r=q.a,p=q.b,o=b;o<=c;++o){if(!(o<s))return A.b(a,o)
n=a[o].b.c
m=n.a
if(m>=r)n=m===r&&n.b<p
else n=!0
if(!n)return o}return c},
bK(a){var s,r
t.ap.a(a)
s=t.i
r=B.a.F(a,0,new A.d7(),s)
if(r<=0)return 1
return B.a.F(a,0,new A.d8(),s)/r},
U(a){var s,r,q
for(s=J.a2(t.bM.a(a)),r=0,q=0;s.n();){r+=s.gp();++q}return q===0?0:r/q},
aL(a){var s
t.o.a(a)
if(a.length<2)return 0
s=A.h(a)
return Math.sqrt(this.U(new A.f(a,s.h("a(1)").a(new A.d2(this.U(a))),s.h("f<1,a>"))))},
a4(a,b,c){return a+(b-a)*B.b.j(c,0,1)}}
A.d9.prototype={
$1(a){return t.F.a(a).ax===B.J},
$S:4}
A.da.prototype={
$1(a){return t.k.a(a).c>0},
$S:21}
A.cX.prototype={
$1(a){t.K.a(a)
return!a.b.c.c_(this.a)&&a.e<-0.08},
$S:1}
A.cY.prototype={
$1(a){return t.F.a(a).ax===B.t},
$S:4}
A.d0.prototype={
$1(a){t.k.a(a)
return 0.6*B.b.j(a.a/9,0,1)+0.4*B.b.j(a.b/3.5,0,1)},
$S:11}
A.d1.prototype={
$1(a){return t.k.a(a).c},
$S:11}
A.d3.prototype={
$1(a){return t.K.a(a).b.d},
$S:3}
A.d4.prototype={
$1(a){var s,r
t.F.a(a)
s=this.a
r=s.f.W(a.r)
return a.e<=s.d&&Math.abs(r.a)<=3e6},
$S:4}
A.d5.prototype={
$1(a){return t.J.a(a)!=null},
$S:22}
A.d6.prototype={
$0(){return null},
$S:24}
A.d_.prototype={
$1(a){return B.a.a0(this.a,new A.cZ(A.B(a)))},
$S:36}
A.cZ.prototype={
$1(a){return t.F.a(a).a===this.a},
$S:4}
A.d7.prototype={
$2(a,b){return A.m(a)+t.E.a(b).b},
$S:8}
A.d8.prototype={
$2(a,b){A.m(a)
t.E.a(b)
return a+b.a*b.b},
$S:8}
A.d2.prototype={
$1(a){return Math.pow(A.m(a)-this.a,2)},
$S:13}
A.aA.prototype={}
A.a9.prototype={}
A.db.prototype={}
A.cV.prototype={}
A.G.prototype={
gbW(){var s,r=this.a
if(isFinite(r)){s=this.b
r=isFinite(s)&&Math.abs(r)<=90&&Math.abs(s)<=180}else r=!1
return r}}
A.dc.prototype={
aN(a,b,c,d,a0,a1,a2,a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=t.t
e.a(a0)
e.a(a7)
if(a3&&!a1.at)return f.a8(a,a1,B.a6,"Common road is below the 3000 metre comparison threshold.")
s=B.i.aQ(b,c,d,a0,a1,a2,a4,a5,a6,a7)
if(!s.gaq()){e=s.a.a===B.d||s.b.a===B.d?B.a7:B.B
i=s.a.f
if(i==null)i=s.b.f
return f.a8(a,a1,e,i==null?"Common-road telemetry could not be extracted.":i)}try{r=B.w.aM(a,s.a.b)
q=B.w.aM(a,s.b.b)
p=q.a-r.a
o=r.a<q.a?r.a:q.a
e=o
if(typeof e!=="number")return e.cc()
if(e<=0)h=0
else{e=p
i=o
if(typeof e!=="number")return e.c9()
if(typeof i!=="number")return A.jv(i)
h=e/i}n=h
m=r.a>=q.a*1.01
l=q.a>=r.a*1.01
if(m)e=B.y
else e=l?B.z:B.A
return new A.c0(r,q,p,n,e,!0)}catch(g){e=A.fo(g)
if(e instanceof A.cd){k=e
return f.a8(a,a1,B.B,u.c)}else{j=e
e=f.a8(a,a1,B.a8,J.aT(j))
return e}}},
bP(a,b,c,d,e,f){var s=null
return this.aN(a,s,b,s,c,d,0,!0,s,e,s,f)},
a8(a,b,c,d){var s=null
return new A.c0(s,s,s,s,c,!1)}}
A.dd.prototype={}
A.ad.prototype={
D(){return"CommonRoadScoreComparisonOutcome."+this.b}}
A.c0.prototype={}
A.bb.prototype={
D(){return"CommonRoadTelemetryMappingStatus."+this.b}}
A.ae.prototype={}
A.dh.prototype={
gaq(){return this.a.a===B.m&&this.b.a===B.m}}
A.de.prototype={
aQ(a,b,c,d,e,f,g,h,i,j){var s,r,q=t.t
q.a(d)
q.a(j)
q=c==null?e.e:c
s=a==null?e.f:a
q=this.aB(s,f,b,e.c,q,d)
s=i==null?e.r:i
r=g==null?e.w:g
return new A.dh(q,this.aB(r,f,h,e.d,s,j))},
ao(a,b,c,d,e){var s=null
return this.aQ(s,a,s,b,c,0,s,d,s,e)},
aB(a,b,a0,a1,a2,a3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=null
t.t.a(a3)
s=J.e9(a3.slice(0),A.h(a3).c)
if(s.length===0)return new A.ae(B.C,B.f,c,c,0,"No canonical telemetry exists.")
r=this.bu(a0,a1)
if(r==null||r.b.length<2)return new A.ae(B.d,B.f,c,c,0,"Matched road section is unavailable.")
q=this.bv(a0,a1)
if(q==null)return new A.ae(B.d,B.f,c,c,0,"Matched road section offset is unavailable.")
p=r.b
o=A.ff(p)
n=A.ii(r)
if(!isFinite(o)||o<=0||!isFinite(n)||n<=0)return new A.ae(B.d,B.f,c,c,0,"Matched section has no valid canonical offset axis.")
m=A.o([],t.du)
for(l=a2-b,k=a+b,j=0;j<s.length;++j){i=s[j]
h=i.a
if(isFinite(h)){g=i.b
h=isFinite(g)&&Math.abs(h)<=90&&Math.abs(g)<=180}else h=!1
if(!h)continue
f=this.bp(i,p,q,o,n,a2,a,b)
h=!0
if(f!=null)if(!(f.a>35)){g=f.c
if(!(g!=null&&g>60)){h=f.b
h=h<l||h>k}}if(h)continue
B.a.m(m,new A.a1(j,i,f))}if(m.length<2)return new A.ae(B.C,B.f,c,c,0,"Fewer than two canonical samples map to the common road.")
p=t.gM
p=A.y(new A.f(m,t.fI.a(new A.df()),p),p.h("q.E"))
p.$flags=1
e=p
for(p=e.length,j=1;j<p;++j){l=e[j].c
k=e[j-1].c
h=l.a
g=k.a
if(h<=g)l=h===g&&l.b>k.b
else l=!0
if(!l)return new A.ae(B.d,B.f,c,c,0,"Mapped telemetry does not preserve strict time order.")}d=B.b.j(1-B.a.F(m,0,new A.dg(),t.i)/m.length/35,0,1)
return new A.ae(B.m,A.a7(e,t.u),B.a.gN(m).a,B.a.ga1(m).a,d,c)},
bu(a,b){var s,r,q=a.d,p=q.length
if(p!==0){for(s=0;s<p;++s){r=q[s]
if(r.a===b)return r}return null}return b===a.a+":geometry"?new A.Z(b,a.c,a.e):null},
bv(a,b){var s,r,q,p,o,n=a.d,m=n.length
if(m===0)return b===a.a+":geometry"?0:null
for(s=0,r=0;r<n.length;n.length===m||(0,A.ab)(n),++r){q=n[r]
if(q.a===b)return s
p=q.c
o=A.ff(q.b)
s+=isFinite(p)&&p>0?p:o}return null},
bp(a9,b0,b1,b2,b3,b4,b5,b6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8
t.f8.a(b0)
for(s=b4-b6,r=a9.e,q=a9.b,p=a9.a,o=b5+b6,n=null,m=!1,l=0,k=0;k<b0.length-1;){j=b0[k];++k
i=b0[k]
h=j.a
g=j.b
f=i.a
e=i.b
d=A.fF(h,g,f,e)
if(d<=0)continue
c=h*3.141592653589793/180
b=111320*Math.cos(c)
a=(q-g)*b
a0=(p-h)*111320
g=e-g
a1=g*b
a2=(f-h)*111320
a3=a1*a1+a2*a2
a4=a3<=0?0:B.b.j((a*a1+a0*a2)/a3,0,1)
h=a-a1*a4
e=a0-a2*a4
e=Math.sqrt(h*h+e*e)
h=b1+A.ih(b2,l+d*a4,b3)
a5=g*3.141592653589793/180
a6=f*3.141592653589793/180
c=A.iT(r,B.b.T(Math.atan2(Math.sin(a5)*Math.cos(a6),Math.cos(c)*Math.sin(a6)-Math.sin(c)*Math.cos(a6)*Math.cos(a5))*180/3.141592653589793+360,360))
a7=new A.eG(e,h,c)
a8=h>=s&&h<=o
h=!0
if(n!=null)if(!(a8&&!m))if(a8===m){g=n.a
if(!(e<g))if(Math.abs(e-g)<=0.000001){h=c==null?1/0:c
g=n.c
h=h<(g==null?1/0:g)}else h=!1}else h=!1
if(h){m=a8
n=a7}l+=d}return n}}
A.df.prototype={
$1(a){return t.A.a(a).b},
$S:17}
A.dg.prototype={
$2(a,b){return A.m(a)+t.A.a(b).c.a},
$S:18}
A.a1.prototype={}
A.eG.prototype={}
A.c4.prototype={
G(a){var s,r,q,p,o,n,m=A.o([],t.df)
for(s=a.P(B.h),r=J.a2(s.a),s=new A.a0(r,s.b,s.$ti.h("a0<1>")),q=0,p=0;s.n();){o=r.gp()
n=this.b7(a,o)
if(n==null){++q
if(o.as<0.5)++p}else B.a.m(m,n)}if(m.length===0)return new A.c3(0,!1,!1)
s=new A.dp(this,m)
s=B.b.j(s.$1(new A.dk())*60+s.$1(new A.dl())*35+s.$1(new A.dm())*35+s.$1(new A.dn())*20,0,150)
r=m.length
A.a7(m,t.h)
return new A.c3(s,!0,r>=2)},
b7(a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=null
if(a1.ax!==B.K||a1.as<0.5||a1.Q<15)return a
s=a1.cx
r=s.i(0,"totalHeadingChangeDegrees")
if(r==null)r=0
if(r<15)return a
q=a0.b
s=s.i(0,"apexIndex")
p=a1.d
o=a1.e
n=B.c.c2(B.c.j(B.b.ab(s==null?(a1.d+a1.e)/2:s),p,o))
m=Math.max(p,p+B.c.A(n-p,2))
l=Math.min(o,n+B.c.A(o-n,2))
k=b.ai(q,p,m)
j=b.ai(q,Math.max(p,n-1),Math.min(o,n+1))
i=b.ai(q,l,b.br(q,o))
if(k<10)return a
s=a1.at
h=Math.max(s.c,s.d)
if(h>=0.6&&k<12)return a
g=r*3.141592653589793/180
f=g<=0?500:a1.Q/g
e=B.b.j(0.55*((r-15)/75)+0.45*((500-f)/475),0,1)
d=1-B.b.j((B.b.j((k-j)/k,0,1)-b.aG(0.08,0.48,e))/0.32,0,1)
if(h>0)d=b.aG(d,1,h*0.35)
s=B.b.j(b.aH(b.am(q,p,n),k)/0.18,0,1)
c=B.b.j(B.b.j(i/k,0,1.1)/0.95,0,1)
o=B.b.j(b.aH(b.am(q,p,o),k)/0.06,0,1)
A.a7(a1.CW,t.N)
return new A.a3(r,e,a1.as,d,1-s,c,1-o)},
br(a,b){var s,r,q,p,o,n,m,l,k
t.X.a(a)
s=a.length
if(!(b<s))return A.b(a,b)
r=a[b].b.c.O(3e6)
for(q=b+1,p=r.a,o=r.b,n=b;q<s;m=q+1,n=q,q=m){l=a[q].b.c
k=l.a
if(k<=p)l=k===p&&l.b>o
else l=!0
if(l)break}return n},
am(a,b,c){var s,r,q
t.X.a(a)
s=A.o([],t.n)
for(r=a.length,q=b;q<=c;++q){if(!(q>=0&&q<r))return A.b(a,q)
s.push(a[q].b.d)}return s},
ai(a,b,c){var s,r,q,p=this.am(t.X.a(a),b,c)
B.a.aZ(p)
s=p.length
r=s/2|0
if((s&1)===1){if(!(r<s))return A.b(p,r)
s=p[r]}else{q=r-1
if(!(q>=0&&q<s))return A.b(p,q)
q=p[q]
if(!(r<s))return A.b(p,r)
q=(q+p[r])/2
s=q}return s},
aH(a,b){var s,r,q,p,o,n
t.o.a(a)
if(a.length<2||b<=0)return 0
s=B.a.J(a,new A.dj())
r=a.length
q=s/r
for(p=0,o=0;o<r;++o){n=a[o]-q
p+=n*n}return Math.sqrt(p/r)/b},
bJ(a){t.h.a(a)
return Math.min(1.5,Math.max(0.25,a.w*(0.5+a.r)*(a.e/30)))},
aG(a,b,c){return a+(b-a)*B.b.j(c,0,1)}}
A.dp.prototype={
$1(a){var s,r,q,p,o,n,m,l,k
t.bk.a(a)
s=this.b
r=A.h(s)
q=r.h("f<1,a>")
r=A.y(new A.f(s,r.h("a(1)").a(this.a.gbI()),q),q.h("q.E"))
r.$flags=1
p=r
r=t.i
o=B.a.F(p,0,new A.dq(),r)
n=s.length
m=A.o(new Array(n),t.n)
for(l=0;l<n;++l){if(!(l<s.length))return A.b(s,l)
q=a.$1(s[l])
if(!(l<p.length))return A.b(p,l)
k=p[l]
if(typeof q!=="number")return q.ar()
m[l]=q*k}return B.a.F(m,0,new A.dr(),r)/o},
$S:20}
A.dq.prototype={
$2(a,b){return A.m(a)+A.m(b)},
$S:0}
A.dr.prototype={
$2(a,b){return A.m(a)+A.m(b)},
$S:0}
A.dk.prototype={
$1(a){return a.x},
$S:5}
A.dl.prototype={
$1(a){return a.y},
$S:5}
A.dm.prototype={
$1(a){return a.z},
$S:5}
A.dn.prototype={
$1(a){return a.Q},
$S:5}
A.dj.prototype={
$2(a,b){return A.m(a)+A.m(b)},
$S:0}
A.c3.prototype={}
A.a3.prototype={}
A.dw.prototype={
bT(b7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6=null
t.Y.a(b7)
if(b7.length===0)return B.M
s=t.I
r=A.bt(A.i7(b6),b6,!1,s)
q=A.o([],t.W)
for(p=0,o=0,n=0,m=0,l=0,k=0,j=0,i=0,h=0,g=0;j<b7.length;++j,f=h,h=i,i=f){e=b7[j]
B.a.u(r,h,j)
d=r.length
h=(h+1&d-1)>>>0
if(i===h){c=A.bt(d*2,b6,!1,s)
b=d-i
B.a.au(c,0,b,r,i)
B.a.au(c,b,b+i,r,0)
i=d
r=c
h=0}else{f=h
h=i
i=f}++g
d=e.d
p+=d
o+=d*d
if(d<=8.333333333333334)++n
a=e.c
a0=a.O(-5e6)
a1=a0.a
a2=a0.b
a3=r.length
a4=a3-1
for(;;){a5=(i-h&a4)>>>0
if(a5>1){if(h===i)A.aS(A.aX())
if(!(h>=0&&h<a3))return A.b(r,h)
a6=r[h]
a6=B.a.i(b7,a6==null?A.aa(a6):a6).c
a7=a6.a
if(a7>=a1)a6=a7===a1&&a6.b<a2
else a6=!0}else a6=!1
if(!a6)break
if(h===i)A.aS(A.aX());++g
if(!(h>=0&&h<a3))return A.b(r,h)
a8=r[h]
if(a8==null)a8=A.aa(a8)
B.a.u(r,h,b6)
h=(h+1&a4)>>>0
a5=B.a.i(b7,a8).d
p-=a5
o-=a5*a5
if(a5<=8.333333333333334)--n}a9=p/a5
b0=B.b.j(o/a5-a9*a9,0,1/0)
b1=e.x
m=j===0?b1:m+0.35*(b1-m)
b2=0
b3=0
if(j>0){a1=j-1
if(!(a1<b7.length))return A.b(b7,a1)
b4=b7[a1]
a1=b4.c
b5=A.D(a.b-a1.b,a.a-a1.a).a/1e6
a=b5>0
if(a)if(d<=1.3888888888888888){l+=b5
k=0}else{k+=b5
l=0}if(a&&d>=4){b2=this.by(b4.e,e.e)
b3=Math.abs(b2)/b5}}B.a.m(q,new A.T(j,e,b0,m,b2,b3))}return q},
by(a,b){if(!isFinite(a)||!isFinite(b))return 0
return B.b.T(b-a+540,360)-180}}
A.c6.prototype={
bN(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this
t.t.a(b)
s=J.e9(b.slice(0),A.h(b).c)
r=B.W.bT(s)
if(r.length===0)return new A.c5(B.M,B.aK,B.aL)
q=d.ba(r)
p=d.Z(r,new A.dz(),new A.dA(),B.ai,new A.dB(d,r))
o=d.Z(r,new A.dL(),new A.dM(),B.I,new A.dN(r))
n=d.Z(r,new A.dO(),new A.dP(),B.I,new A.dQ(r))
m=d.gbf()
l=d.Z(r,m,m,B.ak,new A.dR())
k=d.Z(r,new A.dS(),new A.dC(),B.ah,new A.dD(d,r))
j=A.bt(r.length,B.G,!1,t.fR)
d.a7(j,l,B.ac)
d.a7(j,o,B.ab)
d.a7(j,n,B.ad)
d.a7(j,p,B.H)
m=A.h(p)
i=t.F
m=A.y(new A.f(p,m.h("k(1)").a(new A.dE(d,a,r,q)),m.h("f<1,k>")),i)
h=A.h(o)
B.a.L(m,new A.f(o,h.h("k(1)").a(new A.dF(d,a,r,q)),h.h("f<1,k>")))
h=A.h(n)
B.a.L(m,new A.f(n,h.h("k(1)").a(new A.dG(d,a,r,q)),h.h("f<1,k>")))
h=A.h(k)
B.a.L(m,new A.f(k,h.h("k(1)").a(new A.dH(d,a,r,q)),h.h("f<1,k>")))
g=A.h(l)
B.a.L(m,new A.f(l,g.h("k(1)").a(new A.dI(d,a,r,q)),g.h("f<1,k>")))
B.a.av(m,new A.dJ())
g=A.a7(r,t.K)
f=t.gE
e=A.a7(d.b5(j,r),f)
A.a7(new A.f(k,h.h("@(1)").a(new A.dK(r)),h.h("f<1,@>")),f)
A.a7(q,t.fo)
return new A.c5(g,e,A.a7(d.bt(m),i))},
bg(a){return a.b.d>=5&&Math.abs(a.e)<=0.3&&a.d<=1.5},
Z(a,b,c,d,e){var s,r,q,p,o,n,m
t.X.a(a)
s=t.d1
s.a(c)
s.a(b)
t._.a(e)
r=A.o([],t.dO)
for(q=null,p=null,o=0;o<a.length;++o){n=a[o]
if(q==null){if(c.$1(n)){p=o
q=p}continue}if(b.$1(n)){p=o
continue}s=n.b.c
p.toString
if(!(p<a.length))return A.b(a,p)
m=a[p].b.c
if(A.D(s.b-m.b,s.a-m.a).a<=1e6)continue
this.aD(r,a,q,p,d,e)
q=c.$1(n)?o:null
p=q}if(q!=null&&p!=null)this.aD(r,a,q,p,d,e)
return r},
aD(a,b,c,d,e,f){var s,r,q
t.e.a(a)
t.X.a(b)
A.aa(d)
t._.a(f)
s=new A.U(c,d)
r=b.length
if(!(d<r))return A.b(b,d)
q=b[d]
if(!(c<r))return A.b(b,c)
if(q.b.c.W(b[c].b.c).a>=e.a&&f.$1(s))B.a.m(a,s)},
ba(b4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3
t.X.a(b4)
s=A.o([],t.gI)
for(r=0,q=0;q<b4.length;++q){p=b4[q].b.c.O(-45e6)
o=p.a
n=b4.length
m=p.b
for(;;){if(r<q){if(!(r>=0&&r<n))return A.b(b4,r)
l=b4[r].b.c
k=l.a
if(k>=o)l=k===o&&l.b<m
else l=!0}else l=!1
if(!l)break;++r}if(!(q<n))return A.b(b4,q)
o=b4[q].b.c
if(!(r>=0&&r<n))return A.b(b4,r)
m=b4[r].b.c
if(A.D(o.b-m.b,o.a-m.a).a<8e6){B.a.m(s,B.aW)
continue}for(j=r,i=0,h=0,g=0,f=0,e=0,d=0,c=!1,b=0;j<=q;++j,c=a1){if(!(j<n))return A.b(b4,j)
a=b4[j]
a0=a.b.d
i+=a0
h+=a0*a0
if(a0<=8.333333333333334)++g
a1=a0<=1.3888888888888888
if(a1)++f
if(j>r&&a1!==c)++e
a2=a.e
if(a2>=0.35)a3=1
else a3=a2<=-0.35?-1:0
o=a3!==0
if(o&&b!==0&&a3!==b)++d
if(o)b=a3}a4=q-r+1
a5=i/a4
a6=Math.max(0,h/a4-a5*a5)
a7=g/a4
a8=B.b.j(1-a5/8.333333333333334,0,1)
a9=B.b.j(a6/25,0,1)
b0=B.b.j(e/4,0,1)
b1=B.b.j(d/4,0,1)
b2=B.b.j(a7*0.45+a8*0.35+a9*0.2,0,1)
b3=B.b.j(a7*0.3+f/a4*0.25+b0*0.25+b1*0.2,0,1)
if(b3>=0.62)B.a.m(s,new A.ap(B.b_,b2,b3))
else if(b2>=0.55)B.a.m(s,new A.ap(B.aZ,b2,b3))
else{B.b.j(1-Math.max(b2,b3),0,1)
B.a.m(s,new A.ap(B.aY,b2,b3))}}return s},
a_(a,b,a0,a1,a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=this
t.X.a(a1)
t.dr.a(a2)
for(s=a0.a,r=a0.b,q=a1.length,p=s,o=0,n=1/0;p<=r;++p){if(!(p<q))return A.b(a1,p)
m=a1[p].b.d
o=Math.max(o,m)
n=Math.min(n,m)}l=s+B.c.A(r-s,2)
if(!(l>=0&&l<a2.length))return A.b(a2,l)
k=a2[l]
j=A.fM(t.V)
i=c.bD(k.a)
if(i!=null)j.m(0,i)
h=c.bl(b)
g=A.aI(t.N,t.i)
if(b===B.h){g.u(0,"totalHeadingChangeDegrees",c.aE(a1,s,r))
g.u(0,"apexIndex",c.b8(a1,a0))
j.m(0,B.r)}else j.m(0,c.an(b))
q=a1.length
if(!(r<q))return A.b(a1,r)
f=a1[r]
if(!(s<q))return A.b(a1,s)
e=B.b.j(B.c.A(f.b.c.W(a1[s].b.c).a,1000)/1000/5,0.5,1)
f=a1.length
if(!(s<f))return A.b(a1,s)
q=a1[s].b
if(!(r<f))return A.b(a1,r)
f=a1[r].b
d=n===1/0?0:n
return A.fD(e,j,c.af(a1,s,r),a,r,f.d,f.c,a+":"+b.b+":"+s+":"+r,o,g,d,B.aM,A.i5([h],t.c5),h,s,q.d,q.c,k,b)},
bt(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
t.B.a(a)
s=t.N
r=A.aI(s,t.dg)
for(q=a.length,p=t.s,o=0;n=a.length,o<n;a.length===q||(0,A.ab)(a),++o)r.u(0,a[o].a,A.o([],p))
s=A.aI(s,t.fj)
for(q=t.V,o=0;p=a.length,o<p;a.length===n||(0,A.ab)(a),++o){m=a[o]
p=A.fL(q)
p.L(0,m.ch)
s.u(0,m.a,p)}for(q=p,l=0;l<q;q=g,l=j){if(!(l<q))return A.b(a,l)
k=a[l]
for(j=l+1,q=k.a,p=k.c,n=k.d,i=k.e,h=j;g=a.length,h<g;++h){f=a[h]
if(f.d>i)break
if(f.e<n)continue
g=r.i(0,q)
g.toString
e=f.a
B.a.m(g,e)
g=r.i(0,e)
g.toString
B.a.m(g,q)
g=s.i(0,q)
g.toString
g.m(0,this.an(f.c))
e=s.i(0,e)
e.toString
e.m(0,this.an(p))}}q=A.h(a)
p=q.h("f<1,k>")
s=A.y(new A.f(a,q.h("k(1)").a(new A.dy(s,r)),p),p.h("q.E"))
s.$flags=1
return s},
bl(a){var s
switch(a.a){case 0:s=B.at
break
case 1:s=B.t
break
case 2:s=B.J
break
case 3:s=B.K
break
case 4:s=B.L
break
default:s=null}return s},
an(a){var s
switch(a.a){case 0:s=B.am
break
case 1:s=B.an
break
case 2:s=B.ap
break
case 3:s=B.r
break
case 4:s=B.ao
break
default:s=null}return s},
bD(a){var s=null
switch(a.a){case 3:s=B.as
break
case 2:s=B.ar
break
case 1:s=B.aq
break
case 0:break}return s},
a7(a,b,c){var s,r,q,p,o
t.G.a(a)
t.e.a(b)
for(s=b.length,r=0;r<b.length;b.length===s||(0,A.ab)(b),++r){q=b[r]
for(p=q.a,o=q.b;p<=o;++p)B.a.u(a,p,c)}},
b5(a,b){var s,r,q,p,o,n,m
t.G.a(a)
t.X.a(b)
s=A.o([],t.q)
for(r=a.length,q=0,p=1;p<=r;++p){if(p<r){o=a[p]
if(!(q>=0&&q<r))return A.b(a,q)
o=o===a[q]}else o=!1
if(o)continue
if(!(q>=0&&q<r))return A.b(a,q)
o=a[q]
n=p-1
m=b.length
if(!(q<m))return A.b(b,q)
if(!(n<m))return A.b(b,n)
B.a.m(s,new A.ah(o,q,n))
q=p}return s},
af(a,b,c){var s,r,q
t.X.a(a)
for(s=b+1,r=a.length,q=0;s<=c;++s){if(!(s<r))return A.b(a,s)
q+=a[s].b.w}return q},
aE(a,b,c){var s,r,q
t.X.a(a)
for(s=b+1,r=a.length,q=0;s<=c;++s){if(!(s<r))return A.b(a,s)
q+=Math.abs(a[s].f)}return q},
b8(a,b){var s,r,q,p,o,n
t.X.a(a)
s=b.a
for(r=b.b,q=a.length,p=s,o=0;p<=r;++p){if(!(p<q))return A.b(a,p)
n=a[p].r
if(n>o){o=n
s=p}}return s}}
A.dA.prototype={
$1(a){return a.b.d<=1.3888888888888888},
$S:1}
A.dz.prototype={
$1(a){return a.b.d<=1.3888888888888888},
$S:1}
A.dB.prototype={
$1(a){return this.a.af(this.b,a.a,a.b)<=8},
$S:6}
A.dM.prototype={
$1(a){return a.e>=0.35},
$S:1}
A.dL.prototype={
$1(a){return a.e>=0.15},
$S:1}
A.dN.prototype={
$1(a){var s,r=this.a,q=a.b,p=r.length
if(!(q<p))return A.b(r,q)
q=r[q]
s=a.a
if(!(s<p))return A.b(r,s)
return q.b.d-r[s].b.d>=2},
$S:6}
A.dP.prototype={
$1(a){return a.e<=-0.35},
$S:1}
A.dO.prototype={
$1(a){return a.e<=-0.15},
$S:1}
A.dQ.prototype={
$1(a){var s,r=this.a,q=a.a,p=r.length
if(!(q<p))return A.b(r,q)
q=r[q]
s=a.b
if(!(s<p))return A.b(r,s)
return q.b.d-r[s].b.d>=2},
$S:6}
A.dR.prototype={
$1(a){return!0},
$S:6}
A.dC.prototype={
$1(a){return a.b.d>=4&&a.r>=4},
$S:1}
A.dS.prototype={
$1(a){return a.b.d>=4&&a.r>=2},
$S:1}
A.dD.prototype={
$1(a){var s=this.a,r=this.b,q=a.a,p=a.b
return s.aE(r,q,p)>=15&&s.af(r,q,p)>=15},
$S:6}
A.dE.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.F,t.Q.a(a),s.c,s.d)},
$S:2}
A.dF.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.k,t.Q.a(a),s.c,s.d)},
$S:2}
A.dG.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.n,t.Q.a(a),s.c,s.d)},
$S:2}
A.dH.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.h,t.Q.a(a),s.c,s.d)},
$S:2}
A.dI.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.l,t.Q.a(a),s.c,s.d)},
$S:2}
A.dJ.prototype={
$2(a,b){var s,r=t.F
r.a(a)
r.a(b)
s=B.c.E(a.d,b.d)
return s!==0?s:B.c.E(a.c.a,b.c.a)},
$S:23}
A.dK.prototype={
$1(a){var s,r,q,p
t.Q.a(a)
s=a.a
r=a.b
q=this.a
p=q.length
if(!(s<p))return A.b(q,s)
if(!(r<p))return A.b(q,r)
return new A.ah(B.ae,s,r)},
$S:48}
A.dy.prototype={
$1(a){var s,r,q
t.F.a(a)
s=a.a
r=this.a.i(0,s)
r.toString
r=A.i6(r,t.V)
q=this.b.i(0,s)
q.toString
q=A.a7(q,t.N)
r=t.eN.a(new A.bI(r,t.f4))
t.gJ.a(q)
return A.fD(a.as,r,a.Q,a.b,a.e,a.x,a.r,s,a.y,a.cx,a.z,q,a.ay,a.ax,a.d,a.w,a.f,a.at,a.c)},
$S:25}
A.U.prototype={}
A.dT.prototype={
D(){return"DriveScoreAlgorithmVersion."+this.b}}
A.dU.prototype={
aM(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
t.t.a(b)
s=J.e9(b.slice(0),A.h(b).c)
if(s.length<2)throw A.d(B.a0)
if(B.a.a0(s,new A.dV()))throw A.d(B.a1)
switch(a.a){case 0:r=B.X.bN("in-memory-drive-score",t.Y.a(s))
q=B.U.G(r)
p=B.a4.G(r)
o=B.V.G(r)
n=B.Z.G(r)
m=B.T.G(r)
l=B.a5.G(r)
k=q.z
k=k.a&&k.b&&k.c&&k.d
j=q.f>0||q.r>0
i=p.as.a
h=t.N
g=t.R
f=A.R(["brakingAnticipation",new A.C(q.a,350,!k,j),"tempoPerformance",new A.C(p.a,150,i,i),"corneringPerformance",new A.C(o.a,150,o.y,o.z),"drivingSmoothness",new A.C(n.a,100,n.b,n.c),"accelerationPerformance",new A.C(m.a,50,m.e,m.f),"transitionControl",new A.C(l.a,50,l.e,l.f)],h,g)
e=B.a_.aY(p.r,new A.al(f,A.i(f).h("al<2>")))
g=A.fJ(h,g)
g.L(0,f)
g.u(0,"drivingEndurance",new A.C(e.a,150,e.f,e.r))
g=B.Y.bM(g)
k=g
break
default:k=null}return k}}
A.dV.prototype={
$1(a){return!t.u.a(a).gbW()},
$S:26}
A.cd.prototype={
k(a){return u.c}}
A.e8.prototype={
k(a){return"Canonical telemetry contains an invalid coordinate."}}
A.dW.prototype={
bM(a){var s,r,q,p,o,n,m,l,k,j,i
t.cC.a(a)
s=t.N
r=t.D
q=A.aI(s,r)
for(p=new A.bo(a,A.i(a).h("bo<1,2>")).gq(0),o=0;p.n();){n=p.d
m=n.b
l=m.c
if(l&&m.d)k=B.E
else k=!l?B.a9:B.aa
l=k===B.E
j=l?m.a:m.b*0.75
if(l)++o
q.u(0,n.a,new A.au(j,k))}i=B.b.j(new A.al(q,q.$ti.h("al<2>")).F(0,0,new A.dX(),t.i),0,1000)
p=B.b.ab(i)
return new A.dY(i,B.b.j(o/a.a,0,1),p,1,A.fA(a,s,t.R),A.fA(q,s,r))}}
A.dX.prototype={
$2(a,b){return A.m(a)+t.D.a(b).b},
$S:27}
A.be.prototype={
D(){return"DriveScoreContributionSource."+this.b}}
A.C.prototype={}
A.au.prototype={}
A.dY.prototype={}
A.a5.prototype={
D(){return"DrivingPhase."+this.b}}
A.b3.prototype={
D(){return"TrafficRegime."+this.b}}
A.aG.prototype={
D(){return"DrivingEventType."+this.b}}
A.av.prototype={
D(){return"EventOwnerDomain."+this.b}}
A.O.prototype={
D(){return"EventContextTag."+this.b}}
A.T.prototype={}
A.ap.prototype={}
A.ah.prototype={}
A.k.prototype={}
A.c5.prototype={
P(a){var s=this.f,r=A.h(s)
return new A.z(s,r.h("l(1)").a(new A.dx(a)),r.h("z<1>"))}}
A.dx.prototype={
$1(a){return t.F.a(a).c===this.a},
$S:4}
A.dZ.prototype={
G(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=A.o([],t.g)
for(s=a.P(B.l),r=J.a2(s.a),s=new A.a0(r,s.b,s.$ti.h("a0<1>")),q=0;s.n();){p=r.gp()
o=p.at
n=Math.max(o.c,o.d)
if(p.ax===B.L){o=p.r
m=p.f
o=A.D(o.b-m.b,o.a-m.a).a<8e6||p.y<8.333333333333334||n>=0.65}else o=!0
if(o)++q
else B.a.m(d,p)}s=d.length
if(s===0)return new A.c7(0,!1,!1)
for(l=0,k=B.af,j=0,i=0;i<d.length;d.length===s||(0,A.ab)(d),++i){h=d[i]
r=h.r
p=h.f
g=r.a-p.a
f=r.b-p.b
l+=A.D(f,g).a
if(A.D(f,g).a>k.a)k=A.D(f,g)
j+=B.b.j(1-this.bH(a,h)/4,0,1)*A.D(f,g).a}e=A.D(l,0)
s=B.b.j((0.55*this.b9(e,B.al,B.ag,B.aj)+0.45*(j/l))*100,0,1)
r=e.a
B.c.A(r,1e6)
return new A.c7(s*100,!0,r>=3e7)},
bH(a,b){var s=B.a.a3(a.b,b.d,b.e+1),r=A.h(s),q=r.h("f<1,a>"),p=A.y(new A.f(s,r.h("a(1)").a(new A.e_()),q),q.h("q.E"))
return B.a.F(p,0,new A.e0(B.a.J(p,new A.e1())/p.length),t.i)/p.length},
b9(a,b,c,d){var s,r=a.a,q=b.a
if(r<=q)return 0
s=c.a
if(r<=s)return 0.75*(r-q)/(s-q)
return 0.75+0.25*B.b.j((r-s)/(d.a-s),0,1)}}
A.e_.prototype={
$1(a){return t.K.a(a).b.d},
$S:3}
A.e1.prototype={
$2(a,b){return A.m(a)+A.m(b)},
$S:0}
A.e0.prototype={
$2(a,b){var s
A.m(a)
s=A.m(b)-this.a
return a+s*s},
$S:0}
A.e2.prototype={
aY(a,b){var s,r,q,p,o
t.ff.a(b)
s=b.$ti
r=s.h("z<c.E>")
q=A.y(new A.z(b,s.h("l(c.E)").a(new A.e3()),r),r.h("c.E"))
if(a<5||q.length===0)return new A.c8(0,!1,!1)
p=this.bn(a)
s=A.h(q)
o=B.b.j(new A.f(q,s.h("a(1)").a(new A.e4()),s.h("f<1,a>")).J(0,new A.e5())/q.length,0.15,1)
B.b.j(q.length/6,0,1)
s=a>=50&&q.length>=3
return new A.c8(p*o*150,!0,s)},
bn(a){if(a<=5)return a/5*0.15
if(a<=50)return 0.15+(a-5)/45*0.6
return B.b.j(0.75+(a-50)/100*0.25,0,1)}}
A.e3.prototype={
$1(a){t.R.a(a)
return a.c&&a.d},
$S:28}
A.e4.prototype={
$1(a){t.R.a(a)
return a.a/a.b},
$S:29}
A.e5.prototype={
$2(a,b){return A.m(a)+A.m(b)},
$S:0}
A.c8.prototype={}
A.c7.prototype={}
A.bV.prototype={}
A.a6.prototype={
D(){return"DrivingTransitionType."+this.b}}
A.Y.prototype={}
A.ct.prototype={}
A.b0.prototype={
D(){return"LocalRoadWindowState."+this.b}}
A.bu.prototype={
D(){return"LocalRoadRegionAnalysisStatus."+this.b}}
A.ax.prototype={}
A.aJ.prototype={}
A.bv.prototype={}
A.ei.prototype={
bO(a,b,c,d,e,f){var s,r,q,p=t.t
p.a(e)
p.a(c)
if(!f.at)return new A.bv(B.aR,B.N,B.O)
if(f.as<0.65)return new A.bv(B.aS,B.N,B.O)
s=B.i.ao(d,e,f,b,c)
r=this.b4(a,b,s.b.b,d,s.a.b,f)
q=this.bL(a,f,r)
return new A.bv(B.aQ,A.a7(r,t.l),A.a7(q,t.v))},
b4(a,b,c,d,a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=t.t
e.a(a0)
e.a(c)
s=A.o([],t.d)
for(r=a1.z,e=a1.e,q=a1.f,p=a1.r,o=a1.w,n=f.a,m=0;m<r;m=l){l=m+100
l=l<r?l:r
k=f.a6(e,q,r,m)
j=f.a6(e,q,r,l)
i=f.a6(p,o,r,m)
h=f.a6(p,o,r,l)
g=n.aN(a,j,d,k,a0,a1,5,!1,h,b,i,c)
B.a.m(s,new A.ax(m,l,k,j,i,h,f.bB(g),g))}return s},
bL(a,b,c){var s,r,q,p,o,n,m,l,k,j,i={}
t.fB.a(c)
s=A.o([],t.r)
i.a=null
i.b=0
r=new A.ej(i,s,b,a)
for(q=c.length,p=0;p<c.length;c.length===q||(0,A.ab)(c),++p){o=c[p]
if(o.r===B.P){n=i.a
m=o.b
l=o.d
k=o.f
if(n==null)i.a=new A.eQ(o.a,m,o.c,l,o.e,k)
else{n.b=m
n.d=l
n.f=k;++n.w}i.b=0
continue}if(i.a==null)continue
j=i.b+(o.b-o.a)
i.b=j
if(j>200.000001)r.$0()}r.$0()
return s},
bB(a){var s,r
if(!a.y)return B.Q
s=a.x
A:{if(B.y===s){r=B.aT
break A}if(B.z===s){r=B.P
break A}if(B.A===s){r=B.aU
break A}r=B.Q
break A}return r},
a6(a,b,c,d){if(c<=0)return a
return a+(b-a)*d/c}}
A.ej.prototype={
$0(){var s,r,q,p,o,n,m,l,k,j=this,i=j.a,h=i.a
if(h==null)return
s=h.b
r=h.a
q=s-r
if(q>=2000){p=j.c
o=h.c
n=h.d
m=h.e
l=h.f
k=p.as
if(1<k)k=1
B.a.m(j.b,new A.aJ(p.a,p.b,o,n,m,l,r,s,q,j.d,k,h.w))}i.a=null
i.b=0},
$S:30}
A.eQ.prototype={}
A.P.prototype={}
A.Z.prototype={}
A.eq.prototype={
G(a6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2=this,a3=1e6,a4=a6.b,a5=a4.length
if(a5<2)return new A.bF(0,0,B.aV)
for(s=a5-1,r=0,q=0,p=0,o=0,n=0,m=0;m<a5;++m){l=a4[m].b
o+=l.w
if(m===s)continue
k=m+1
if(!(k<a5))return A.b(a4,k)
k=a4[k].b
j=k.c
l=l.c
l=A.D(j.b-l.b,j.a-l.a).a
if(l<=0){++n
continue}if(a2.bh(a6,m))q+=l
else{r+=l
p+=k.w}}i=B.a.ga1(a4).b.c.W(B.a.gN(a4).b.c)
h=A.D(r,0)
g=A.D(q,0)
f=o/1000
s=h.a
e=s<=0?0:p/(s/1e6)*3.6
d=a2.bG(a6)
c=a5>=6&&s>=9e7&&o>=1000
B.b.j(Math.min(a5/6,Math.min(s/9e7,f)),0,1)
if(!c){B.b.aV(f,2)
B.c.A(s,a3)
return new A.bF(0,f,new A.bE(!1))}a5=i.a
b=a5<=0?0:o/(a5/1e6)*3.6
a=a2.al(e,B.aF,60)
a0=d.b<2?0:a2.al(d.a*3.6,B.aN,30)
a1=B.b.j(a+a0+a2.al(b,B.aB,60),0,150)
B.b.aV(f,2)
B.c.A(s,a3)
B.c.A(g.a,a3)
return new A.bF(a1,f,new A.bE(!0))},
bh(a,b){var s,r,q,p
if(this.bm(a.c,b)===B.H)return!0
s=a.b
r=s.length
if(!(b<r))return A.b(s,b)
q=s[b]
p=b+1
if(!(p<r))return A.b(s,p)
p=s[p]
return q.b.d<=1.3888888888888888&&p.b.d<=1.3888888888888888},
bm(a,b){var s,r,q
t.au.a(a)
for(s=a.length,r=0;r<s;++r){q=a[r]
if(b>=q.b&&b<=q.c)return q.a}return B.G},
bG(a){var s,r,q,p,o,n,m,l,k,j=a.b
for(s=j.length,r=0,q=0,p=0;p<s;++p){o=j[p].b.d
if(!isFinite(o)||o<0)continue
for(n=[p-1,p+1],m=1,l=0;l<2;++l){k=n[l]
if(k<0||k>=s)continue
if(!(k>=0&&k<s))return A.b(j,k)
if(Math.abs(j[k].b.d-o)<=10)++m}if(m<2)continue
if(o>r){q=m
r=o}}return new A.eP(r,q)},
al(a,b,c){var s,r,q,p,o,n
t.gj.a(b)
if(a<=B.a.gN(B.a.gN(b)))return 0
for(s=b.length,r=1;r<s;++r){q=b[r-1]
p=b[r]
if(a<=B.a.gN(p)){s=B.a.gN(q)
o=B.a.gN(p)
n=B.a.gN(q)
return B.b.j(c*(B.a.ga1(q)+(B.a.ga1(p)-B.a.ga1(q))*((a-s)/(o-n))),0,c)}}return c}}
A.eP.prototype={}
A.bF.prototype={}
A.bE.prototype={}
A.er.prototype={
G(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=a.f,b=A.o([],t.c)
for(s=c.length,r=0;q=r+2,q<s;){if(!(r<s))return A.b(c,r)
p=c[r];++r
if(!(r<s))return A.b(c,r)
o=c[r]
n=c[q]
m=this.bF(p,o,n)
if(m!=null){q=o.at
l=Math.max(q.c,q.d)
q=!1
if(n.y>=8.333333333333334)if(l<0.65){k=o.f
j=p.r
if(A.D(k.b-j.b,k.a-j.a).a<=8e6){q=n.f
k=o.r
k=A.D(q.b-k.b,q.a-k.a).a<=8e6
q=k}}q=!q}else q=!0
if(q)continue
B.a.m(b,new A.Y(m,this.bq(a,n)))}if(b.length===0)return B.b0
i=new A.ew(b)
h=i.$2(B.o,20)
g=i.$2(B.p,20)
f=i.$2(B.q,10)
s=A.aI(t.am,t.S)
for(q=t.eF,k=t.dA,e=0;e<3;++e){d=B.aP[e]
s.u(0,d,new A.z(b,q.a(new A.ev(d)),k).gl(0))}return new A.ct(h+g+f,!0,b.length>=2)},
bF(a,b,c){var s,r
if(c.c!==B.l)return null
s=a.c
r=s===B.l
if(r&&b.c===B.n)return B.o
if(r&&b.c===B.h)return B.p
if(s===B.k)return B.q
return null},
bq(a,b){var s=B.a.a3(a.b,b.d,b.e+1),r=A.h(s)
return B.b.j(1-Math.sqrt(B.a.F(s,0,new A.es(new A.f(s,r.h("a(1)").a(new A.et()),r.h("f<1,a>")).J(0,new A.eu())/s.length),t.i)/s.length)/4,0,1)}}
A.ew.prototype={
$2(a,b){var s=this.a,r=A.h(s),q=r.h("z<1>"),p=A.y(new A.z(s,r.h("l(1)").a(new A.ex(a)),q),q.h("c.E"))
if(p.length===0)return 0
s=A.h(p)
return new A.f(p,s.h("a(1)").a(new A.ey()),s.h("f<1,a>")).J(0,new A.ez())/p.length*b},
$S:31}
A.ex.prototype={
$1(a){return t.f.a(a).a===this.a},
$S:14}
A.ey.prototype={
$1(a){return t.f.a(a).e},
$S:33}
A.ez.prototype={
$2(a,b){return A.m(a)+A.m(b)},
$S:0}
A.ev.prototype={
$1(a){return t.f.a(a).a===this.a},
$S:14}
A.et.prototype={
$1(a){return t.K.a(a).b.d},
$S:3}
A.eu.prototype={
$2(a,b){return A.m(a)+A.m(b)},
$S:0}
A.es.prototype={
$2(a,b){var s
A.m(a)
s=t.K.a(b).b.d-this.a
return a+s*s},
$S:47}
A.eD.prototype={}
A.f1.prototype={
$1(a){var s=J.cB(a),r=A.B(s.i(a,"id"))
s=J.cF(t.j.a(s.i(a,"geometry")),new A.f0(),t.x)
s=A.y(s,s.$ti.h("q.E"))
return new A.Z(r,s,A.t(t.P.a(a).i(0,"distanceMeters")))},
$S:35}
A.f0.prototype={
$1(a){t.P.a(a)
return new A.P(A.t(a.i(0,"latitude")),A.t(a.i(0,"longitude")))},
$S:15}
A.f2.prototype={
$1(a){return t.p.a(a).b},
$S:37}
A.f3.prototype={
$2(a,b){return A.m(a)+t.p.a(b).c},
$S:38}
A.f8.prototype={
$1(a){var s,r,q,p,o
t.P.a(a)
s=A.t(a.i(0,"latitude"))
r=A.t(a.i(0,"longitude"))
q=A.i_(A.B(a.i(0,"timestamp")))
p=A.t(a.i(0,"speed_mps"))
o=A.t(a.i(0,"heading_degrees"))
A.t(a.i(0,"altitude_meters"))
A.t(a.i(0,"accuracy_meters"))
return new A.G(s,r,q,p,o,A.t(a.i(0,"distance_from_previous_meters")),A.t(a.i(0,"acceleration_mps2")))},
$S:39}
A.f4.prototype={
$2(a,b){A.B(a)
t.R.a(b)
return new A.E(a,A.R(["score",b.a,"maximum",b.b,"applicable",b.c,"sampleSufficient",b.d],t.N,t.C),t.w)},
$S:40}
A.f5.prototype={
$2(a,b){A.B(a)
t.D.a(b)
return new A.E(a,A.R(["contribution",b.b,"source",b.c.b],t.N,t.C),t.w)},
$S:41}
A.f6.prototype={
$1(a){return t.u.a(a).c.c4().c3()},
$S:42}
A.eW.prototype={
$1(a){t.P.a(a)
return new A.P(A.t(a.i(0,"latitude")),A.t(a.i(0,"longitude")))},
$S:15}
A.eT.prototype={
$1(a){t.l.a(a)
return A.R(["commonStartOffsetMeters",a.a,"commonEndOffsetMeters",a.b,"existingStartOffsetMeters",a.c,"existingEndOffsetMeters",a.d,"challengerStartOffsetMeters",a.e,"challengerEndOffsetMeters",a.f,"state",a.r.b,"comparison",A.hp(a.w)],t.N,t.C)},
$S:43}
A.eU.prototype={
$1(a){t.v.a(a)
return A.R(["existingDriveId",a.a,"challengerDriveId",a.b,"startOffsetOnExistingMeters",a.d,"endOffsetOnExistingMeters",a.e,"startOffsetOnChallengerMeters",a.f,"endOffsetOnChallengerMeters",a.r,"commonStartOffsetMeters",a.w,"commonEndOffsetMeters",a.x,"winningDistanceMeters",a.y,"algorithmVersion",1,"confidence",a.Q,"supportingWindowCount",a.as],t.N,t.C)},
$S:44}
A.eY.prototype={
$1(a){return B.j.aP(A.jo(t.P.a(B.j.aO(A.B(a),null))),null)},
$S:9}
A.eZ.prototype={
$1(a){return B.j.aP(A.jp(t.P.a(B.j.aO(A.B(a),null))),null)},
$S:9};(function aliases(){var s=J.aw.prototype
s.b_=s.k})();(function installTearOffs(){var s=hunkHelpers._static_2,r=hunkHelpers._static_1,q=hunkHelpers._instance_1u,p=hunkHelpers.installStaticTearOff
s(J,"iX","i2",46)
r(A,"jm","iN",34)
q(A.c4.prototype,"gbI","bJ",5)
q(A.c6.prototype,"gbf","bg",1)
p(A,"jz",2,null,["$1$2","$2"],["ht",function(a,b){return A.ht(a,b,t.H)}],32,0)})();(function inheritance(){var s=hunkHelpers.mixin,r=hunkHelpers.inherit,q=hunkHelpers.inheritMany
r(A.j,null)
q(A.j,[A.fb,J.ce,A.bz,J.aE,A.c,A.ba,A.u,A.eo,A.bs,A.bw,A.a0,A.bj,A.bA,A.bh,A.b1,A.bc,A.K,A.eA,A.em,A.I,A.ef,A.bq,A.br,A.bp,A.ci,A.eK,A.a_,A.cw,A.eL,A.aM,A.cz,A.aN,A.bQ,A.bL,A.cA,A.c_,A.c2,A.eI,A.a4,A.L,A.eE,A.cm,A.bB,A.eF,A.e6,A.E,A.aK,A.b2,A.cG,A.cW,A.aA,A.a9,A.db,A.cV,A.G,A.dc,A.dd,A.c0,A.ae,A.dh,A.de,A.a1,A.eG,A.c4,A.c3,A.a3,A.dw,A.c6,A.U,A.dU,A.cd,A.e8,A.dW,A.C,A.au,A.dY,A.T,A.ap,A.ah,A.k,A.c5,A.dZ,A.e2,A.c8,A.c7,A.bV,A.Y,A.ct,A.ax,A.aJ,A.bv,A.ei,A.eQ,A.P,A.Z,A.eq,A.eP,A.bF,A.bE,A.er,A.eD])
q(J.ce,[J.cg,J.bl,J.b_,J.aY,J.aH])
q(J.b_,[J.aw,J.n])
q(J.aw,[J.en,J.ay,J.bm])
r(J.cf,A.bz)
r(J.ea,J.n)
q(J.aY,[J.bk,J.ch])
q(A.c,[A.b4,A.p,A.am,A.z,A.bi,A.ao])
r(A.aF,A.b4)
r(A.bK,A.aF)
q(A.u,[A.cl,A.bG,A.cj,A.cu,A.cq,A.cv,A.bn,A.bW,A.ac,A.bJ,A.bC,A.c1])
q(A.p,[A.q,A.bg,A.ak,A.al,A.bo])
q(A.q,[A.bD,A.f,A.eh,A.cy])
r(A.bf,A.am)
r(A.aV,A.ao)
r(A.b6,A.b1)
r(A.bH,A.b6)
r(A.bd,A.bH)
q(A.K,[A.bZ,A.cc,A.bY,A.cs,A.du,A.dv,A.cO,A.cQ,A.cR,A.cS,A.cH,A.cK,A.cL,A.cT,A.d9,A.da,A.cX,A.cY,A.d0,A.d1,A.d3,A.d4,A.d5,A.d_,A.cZ,A.d2,A.df,A.dp,A.dk,A.dl,A.dm,A.dn,A.dA,A.dz,A.dB,A.dM,A.dL,A.dN,A.dP,A.dO,A.dQ,A.dR,A.dC,A.dS,A.dD,A.dE,A.dF,A.dG,A.dH,A.dI,A.dK,A.dy,A.dV,A.dx,A.e_,A.e3,A.e4,A.ex,A.ey,A.ev,A.et,A.f1,A.f0,A.f2,A.f8,A.f6,A.eW,A.eT,A.eU,A.eY,A.eZ])
q(A.bZ,[A.di,A.eb,A.eg,A.el,A.eJ,A.cP,A.cJ,A.cI,A.cN,A.cM,A.d7,A.d8,A.dg,A.dq,A.dr,A.dj,A.dJ,A.dX,A.e1,A.e0,A.e5,A.ew,A.ez,A.eu,A.es,A.f3,A.f4,A.f5])
r(A.af,A.bc)
r(A.aW,A.cc)
r(A.bx,A.bG)
q(A.cs,[A.cr,A.aU])
q(A.I,[A.aj,A.cx])
r(A.b5,A.cv)
q(A.aM,[A.bM,A.bR])
r(A.as,A.bM)
r(A.bI,A.bR)
r(A.ck,A.bn)
r(A.ec,A.c_)
q(A.c2,[A.ee,A.ed])
r(A.eH,A.eI)
q(A.bY,[A.ds,A.d6,A.ej])
q(A.ac,[A.by,A.cb])
q(A.eE,[A.ad,A.bb,A.dT,A.be,A.a5,A.b3,A.aG,A.av,A.O,A.a6,A.b0,A.bu])
s(A.b6,A.bQ)
s(A.bR,A.cA)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{X:"int",a:"double",J:"num",e:"String",l:"bool",aK:"Null",v:"List",j:"Object",r:"Map",aZ:"JSObject"},mangledNames:{},types:["a(a,a)","l(T)","k(U)","a(T)","l(k)","a(a3)","l(U)","a(k)","a(a,aA)","e(e)","~(j?,j?)","a(a9)","X(e?)","a(a)","l(Y)","P(@)","a(a(k))","G(a1)","a(a,a1)","0&()","a(a(a3))","l(a9)","l(k?)","X(k,k)","aK()","k(k)","l(G)","a(a,au)","l(C)","a(C)","~()","a(a6,a)","0^(0^,0^)<J>","a(Y)","@(@)","Z(@)","l(e)","v<P>(Z)","a(a,Z)","G(@)","E<e,r<e,j>>(e,C)","E<e,r<e,j>>(e,au)","e(G)","r<e,j>(ax)","r<e,j>(aJ)","~(@,@)","X(@,@)","a(a,T)","ah(U)"],arrayRti:Symbol("$ti")}
A.iA(v.typeUniverse,JSON.parse('{"bm":"aw","en":"aw","ay":"aw","cg":{"l":[],"aq":[]},"bl":{"aq":[]},"b_":{"aZ":[]},"aw":{"aZ":[]},"n":{"v":["1"],"p":["1"],"aZ":[],"c":["1"]},"cf":{"bz":[]},"ea":{"n":["1"],"v":["1"],"p":["1"],"aZ":[],"c":["1"]},"aE":{"w":["1"]},"aY":{"a":[],"J":[],"Q":["J"]},"bk":{"a":[],"X":[],"J":[],"Q":["J"],"aq":[]},"ch":{"a":[],"J":[],"Q":["J"],"aq":[]},"aH":{"e":[],"Q":["e"],"aq":[]},"b4":{"c":["2"]},"ba":{"w":["2"]},"aF":{"b4":["1","2"],"c":["2"],"c.E":"2"},"bK":{"aF":["1","2"],"b4":["1","2"],"p":["2"],"c":["2"],"c.E":"2"},"cl":{"u":[]},"p":{"c":["1"]},"q":{"p":["1"],"c":["1"]},"bD":{"q":["1"],"p":["1"],"c":["1"],"q.E":"1","c.E":"1"},"bs":{"w":["1"]},"am":{"c":["2"],"c.E":"2"},"bf":{"am":["1","2"],"p":["2"],"c":["2"],"c.E":"2"},"bw":{"w":["2"]},"f":{"q":["2"],"p":["2"],"c":["2"],"q.E":"2","c.E":"2"},"z":{"c":["1"],"c.E":"1"},"a0":{"w":["1"]},"bi":{"c":["2"],"c.E":"2"},"bj":{"w":["2"]},"ao":{"c":["1"],"c.E":"1"},"aV":{"ao":["1"],"p":["1"],"c":["1"],"c.E":"1"},"bA":{"w":["1"]},"bg":{"p":["1"],"c":["1"],"c.E":"1"},"bh":{"w":["1"]},"bd":{"bH":["1","2"],"b6":["1","2"],"b1":["1","2"],"bQ":["1","2"],"r":["1","2"]},"bc":{"r":["1","2"]},"af":{"bc":["1","2"],"r":["1","2"]},"cc":{"K":[],"ai":[]},"aW":{"K":[],"ai":[]},"bx":{"u":[]},"cj":{"u":[]},"cu":{"u":[]},"K":{"ai":[]},"bY":{"K":[],"ai":[]},"bZ":{"K":[],"ai":[]},"cs":{"K":[],"ai":[]},"cr":{"K":[],"ai":[]},"aU":{"K":[],"ai":[]},"cq":{"u":[]},"aj":{"I":["1","2"],"fI":["1","2"],"r":["1","2"],"I.K":"1","I.V":"2"},"ak":{"p":["1"],"c":["1"],"c.E":"1"},"bq":{"w":["1"]},"al":{"p":["1"],"c":["1"],"c.E":"1"},"br":{"w":["1"]},"bo":{"p":["E<1,2>"],"c":["E<1,2>"],"c.E":"E<1,2>"},"bp":{"w":["E<1,2>"]},"ci":{"ib":[]},"cv":{"u":[]},"b5":{"u":[]},"as":{"bM":["1"],"aM":["1"],"fK":["1"],"aL":["1"],"p":["1"],"c":["1"]},"aN":{"w":["1"]},"I":{"r":["1","2"]},"b1":{"r":["1","2"]},"bH":{"b6":["1","2"],"b1":["1","2"],"bQ":["1","2"],"r":["1","2"]},"eh":{"q":["1"],"p":["1"],"c":["1"],"q.E":"1","c.E":"1"},"bL":{"w":["1"]},"aM":{"aL":["1"],"p":["1"],"c":["1"]},"bM":{"aM":["1"],"aL":["1"],"p":["1"],"c":["1"]},"bI":{"aM":["1"],"cA":["1"],"aL":["1"],"p":["1"],"c":["1"]},"cx":{"I":["e","@"],"r":["e","@"],"I.K":"e","I.V":"@"},"cy":{"q":["e"],"p":["e"],"c":["e"],"q.E":"e","c.E":"e"},"bn":{"u":[]},"ck":{"u":[]},"a4":{"Q":["a4"]},"a":{"J":[],"Q":["J"]},"L":{"Q":["L"]},"X":{"J":[],"Q":["J"]},"v":{"p":["1"],"c":["1"]},"J":{"Q":["J"]},"aL":{"p":["1"],"c":["1"]},"e":{"Q":["e"]},"bW":{"u":[]},"bG":{"u":[]},"ac":{"u":[]},"by":{"u":[]},"cb":{"u":[]},"bJ":{"u":[]},"bC":{"u":[]},"c1":{"u":[]},"cm":{"u":[]},"bB":{"u":[]},"b2":{"ie":[]}}'))
A.iz(v.typeUniverse,JSON.parse('{"bR":1,"c_":2,"c2":2}'))
var u={c:"At least two canonical telemetry points are required."}
var t=(function rtii(){var s=A.aC
return{u:s("G"),fI:s("G(a1)"),e8:s("Q<@>"),h:s("a3"),dy:s("a4"),D:s("au"),R:s("C"),F:s("k"),fR:s("a5"),gE:s("ah"),f:s("Y"),am:s("a6"),fu:s("L"),O:s("p<@>"),bU:s("u"),V:s("O"),c5:s("av"),Z:s("ai"),t:s("c<G>"),ff:s("c<C>"),bM:s("c<a>"),hf:s("c<@>"),df:s("n<a3>"),g:s("n<k>"),q:s("n<ah>"),c:s("n<Y>"),b:s("n<v<a>>"),d:s("n<ax>"),r:s("n<aJ>"),s:s("n<e>"),W:s("n<T>"),gI:s("n<ap>"),h9:s("n<a9>"),du:s("n<a1>"),dO:s("n<U>"),aS:s("n<aA>"),n:s("n<a>"),gn:s("n<@>"),T:s("bl"),m:s("aZ"),L:s("bm"),Y:s("v<G>"),B:s("v<k>"),G:s("v<a5>"),au:s("v<ah>"),gj:s("v<v<a>>"),fB:s("v<ax>"),f8:s("v<P>"),dg:s("v<e>"),X:s("v<T>"),dr:s("v<ap>"),cT:s("v<a9>"),e:s("v<U>"),ap:s("v<aA>"),o:s("v<a>"),j:s("v<@>"),l:s("ax"),v:s("aJ"),w:s("E<e,r<e,j>>"),cC:s("r<e,C>"),h6:s("r<e,j>"),P:s("r<e,@>"),eO:s("r<@,@>"),gM:s("f<a1,G>"),x:s("P"),p:s("Z"),a:s("aK"),C:s("j"),gT:s("jH"),fj:s("aL<O>"),cq:s("aL<e>"),N:s("e"),K:s("T"),fo:s("ap"),dm:s("aq"),ak:s("ay"),f4:s("bI<O>"),dA:s("z<Y>"),k:s("a9"),A:s("a1"),Q:s("U"),E:s("aA"),y:s("l"),eF:s("l(Y)"),d1:s("l(T)"),_:s("l(U)"),i:s("a"),bk:s("a(a3)"),bE:s("a(k)"),z:s("@"),S:s("X"),J:s("k?"),eH:s("fE<aK>?"),an:s("aZ?"),gJ:s("v<e>?"),bF:s("v<@>?"),U:s("j?"),eN:s("aL<O>?"),dk:s("e?"),M:s("cz?"),fQ:s("l?"),cD:s("a?"),I:s("X?"),cg:s("J?"),H:s("J"),cA:s("~(e,@)")}})();(function constants(){var s=hunkHelpers.makeConstList
B.au=J.ce.prototype
B.a=J.n.prototype
B.c=J.bk.prototype
B.b=J.aY.prototype
B.e=J.aH.prototype
B.av=J.b_.prototype
B.S=new A.aW(A.jz(),A.aC("aW<a>"))
B.T=new A.cG()
B.U=new A.cW()
B.i=new A.de()
B.W=new A.dw()
B.X=new A.c6()
B.a4=new A.eq()
B.V=new A.c4()
B.Z=new A.dZ()
B.a5=new A.er()
B.a_=new A.e2()
B.Y=new A.dW()
B.w=new A.dU()
B.v=new A.dc()
B.x=new A.bh(A.aC("bh<0&>"))
B.a0=new A.cd()
B.a1=new A.e8()
B.a2=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.j=new A.ec()
B.a3=new A.cm()
B.b2=new A.eo()
B.y=new A.ad(0,"firstWins")
B.z=new A.ad(1,"secondWins")
B.A=new A.ad(2,"noMeaningfulDifference")
B.a6=new A.ad(3,"notEligible")
B.B=new A.ad(4,"insufficientTelemetry")
B.a7=new A.ad(5,"mappingFailed")
B.a8=new A.ad(7,"calculationFailed")
B.m=new A.bb(0,"success")
B.d=new A.bb(1,"mappingFailed")
B.C=new A.bb(2,"insufficientTelemetry")
B.D=new A.dT(0,"v1")
B.E=new A.be(0,"actual")
B.a9=new A.be(1,"neutralNotApplicable")
B.aa=new A.be(2,"neutralInsufficient")
B.F=new A.aG(0,"stop")
B.k=new A.aG(1,"acceleration")
B.n=new A.aG(2,"deceleration")
B.h=new A.aG(3,"corner")
B.l=new A.aG(4,"cruise")
B.G=new A.a5(0,"unknown")
B.H=new A.a5(1,"stopped")
B.ab=new A.a5(2,"accelerating")
B.ac=new A.a5(3,"cruising")
B.ad=new A.a5(4,"decelerating")
B.ae=new A.a5(5,"cornering")
B.o=new A.a6(0,"cruiseDecelCruise")
B.p=new A.a6(1,"cruiseCornerCruise")
B.q=new A.a6(2,"accelerationCruise")
B.af=new A.L(0)
B.ag=new A.L(12e7)
B.I=new A.L(15e5)
B.ah=new A.L(2e6)
B.ai=new A.L(3e6)
B.aj=new A.L(3e8)
B.ak=new A.L(5e6)
B.al=new A.L(8e6)
B.am=new A.O(0,"stopped")
B.an=new A.O(1,"accelerating")
B.ao=new A.O(2,"cruising")
B.ap=new A.O(3,"decelerating")
B.r=new A.O(4,"cornering")
B.aq=new A.O(5,"freeFlow")
B.ar=new A.O(6,"denseTraffic")
B.as=new A.O(7,"stopAndGo")
B.at=new A.av(0,"stopping")
B.t=new A.av(1,"acceleration")
B.J=new A.av(2,"braking")
B.K=new A.av(3,"cornering")
B.L=new A.av(4,"cruising")
B.aw=new A.ed(null)
B.ax=new A.ee(null)
B.u=s([0,0],t.n)
B.aD=s([20,0.25],t.n)
B.aJ=s([50,0.58],t.n)
B.aI=s([80,0.83],t.n)
B.ay=s([120,1],t.n)
B.aB=s([B.u,B.aD,B.aJ,B.aI,B.ay],t.b)
B.aC=s([30,0.25],t.n)
B.aE=s([60,0.58],t.n)
B.aO=s([100,0.83],t.n)
B.az=s([150,1],t.n)
B.aF=s([B.u,B.aC,B.aE,B.aO,B.az],t.b)
B.f=s([],A.aC("n<G>"))
B.aL=s([],t.g)
B.aK=s([],t.q)
B.N=s([],t.d)
B.O=s([],t.r)
B.aM=s([],t.s)
B.M=s([],t.W)
B.aH=s([80,0.33],t.n)
B.aG=s([140,0.67],t.n)
B.aA=s([200,1],t.n)
B.aN=s([B.u,B.aH,B.aG,B.aA],t.b)
B.aP=s([B.o,B.p,B.q],A.aC("n<a6>"))
B.aQ=new A.bu(0,"success")
B.aR=new A.bu(1,"notEligible")
B.aS=new A.bu(2,"insufficientConfidence")
B.aT=new A.b0(0,"existingBetter")
B.P=new A.b0(1,"challengerBetter")
B.aU=new A.b0(2,"noMeaningfulDifference")
B.Q=new A.b0(3,"invalid")
B.R={}
B.b4=new A.af(B.R,[],A.aC("af<e,a>"))
B.aV=new A.bE(!1)
B.aX=new A.b3(0,"unknown")
B.aW=new A.ap(B.aX,0,0)
B.aY=new A.b3(1,"freeFlow")
B.aZ=new A.b3(2,"denseTraffic")
B.b_=new A.b3(3,"stopAndGo")
B.b5=new A.af(B.R,[],A.aC("af<a6,X>"))
B.b3=s([],t.c)
B.b0=new A.ct(0,!1,!1)
B.b1=A.jD("j")})();(function staticFields(){$.V=A.o([],A.aC("n<j>"))
$.fO=null
$.fv=null
$.fu=null})();(function lazyInitializers(){var s=hunkHelpers.lazyFinal
s($,"jF","hx",()=>A.hr("_$dart_dartClosure"))
s($,"jE","fp",()=>A.hr("_$dart_dartClosure_dartJSInterop"))
s($,"jT","hK",()=>A.o([new J.cf()],A.aC("n<bz>")))
s($,"jI","hz",()=>A.ar(A.eB({
toString:function(){return"$receiver$"}})))
s($,"jJ","hA",()=>A.ar(A.eB({$method$:null,
toString:function(){return"$receiver$"}})))
s($,"jK","hB",()=>A.ar(A.eB(null)))
s($,"jL","hC",()=>A.ar(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"jO","hF",()=>A.ar(A.eB(void 0)))
s($,"jP","hG",()=>A.ar(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"jN","hE",()=>A.ar(A.h0(null)))
s($,"jM","hD",()=>A.ar(function(){try{null.$method$}catch(r){return r.message}}()))
s($,"jR","hI",()=>A.ar(A.h0(void 0)))
s($,"jQ","hH",()=>A.ar(function(){try{(void 0).$method$}catch(r){return r.message}}()))
s($,"jG","hy",()=>A.ic("^([+-]?\\d{4,6})-?(\\d\\d)-?(\\d\\d)(?:[ T](\\d\\d)(?::?(\\d\\d)(?::?(\\d\\d)(?:[.,](\\d+))?)?)?( ?[zZ]| ?([-+])(\\d\\d)(?::?(\\d\\d))?)?)?$"))
s($,"jS","hJ",()=>A.hu(B.b1))})();(function nativeSupport(){!function(){var s=function(a){var m={}
m[a]=1
return Object.keys(hunkHelpers.convertToFastObject(m))[0]}
v.getIsolateTag=function(a){return s("___dart_"+a+v.isolateTag)}
var r="___dart_isolate_tags_"
var q=Object[r]||(Object[r]=Object.create(null))
var p="_ZxYxX"
for(var o=0;;o++){var n=s(p+"_"+o+"_")
if(!(n in q)){q[n]=1
v.isolateTag=n
break}}}()
hunkHelpers.setOrUpdateInterceptorsByTag({})
hunkHelpers.setOrUpdateLeafTags({})})()
Function.prototype.$0=function(){return this()}
Function.prototype.$1=function(a){return this(a)}
Function.prototype.$2=function(a,b){return this(a,b)}
Function.prototype.$3=function(a,b,c){return this(a,b,c)}
Function.prototype.$4=function(a,b,c,d){return this(a,b,c,d)}
Function.prototype.$2$1=function(a){return this(a)}
Function.prototype.$1$1=function(a){return this(a)}
convertAllToFastObject(w)
convertToFastObject($);(function(a){if(typeof document==="undefined"){a(null)
return}if(typeof document.currentScript!="undefined"){a(document.currentScript)
return}var s=document.scripts
function onLoad(b){for(var q=0;q<s.length;++q){s[q].removeEventListener("load",onLoad,false)}a(b.target)}for(var r=0;r<s.length;++r){s[r].addEventListener("load",onLoad,false)}})(function(a){v.currentScript=a
var s=A.jy
if(typeof dartMainRunner==="function"){dartMainRunner(s,[])}else{s([])}})})()
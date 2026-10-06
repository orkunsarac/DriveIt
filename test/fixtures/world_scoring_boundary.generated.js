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
if(a[b]!==s){A.jt(b)}a[b]=r}var q=a[b]
a[c]=function(){return q}
return q}}function makeConstList(a,b){if(b!=null)A.o(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var s=0;s<a.length;++s){convertToFastObject(a[s])}}var y=0
function instanceTearOffGetter(a,b){var s=null
return a?function(c){if(s===null)s=A.fg(b)
return new s(c,this)}:function(){if(s===null)s=A.fg(b)
return new s(this,null)}}function staticTearOffGetter(a){var s=null
return function(){if(s===null)s=A.fg(a).prototype
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
fA(a,b){if(a<0||a>4294967295)throw A.d(A.a8(a,0,4294967295,"length",null))
return J.e7(new Array(a),b)},
e7(a,b){var s=A.o(a,b.h("n<0>"))
s.$flags=1
return s},
hX(a,b){var s=t.e8
return J.hG(s.a(a),s.a(b))},
aQ(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.bm.prototype
return J.ck.prototype}if(typeof a=="string")return J.aI.prototype
if(a==null)return J.bn.prototype
if(typeof a=="boolean")return J.cj.prototype
if(Array.isArray(a))return J.n.prototype
if(typeof a=="function")return J.bo.prototype
if(typeof a=="object"){if(a instanceof A.j){return a}else{return J.b_.prototype}}if(!(a instanceof A.j))return J.az.prototype
return a},
bT(a){if(a==null)return a
if(Array.isArray(a))return J.n.prototype
if(!(a instanceof A.j))return J.az.prototype
return a},
bU(a){if(typeof a=="string")return J.aI.prototype
if(a==null)return a
if(Array.isArray(a))return J.n.prototype
if(!(a instanceof A.j))return J.az.prototype
return a},
jk(a){if(typeof a=="number")return J.aY.prototype
if(typeof a=="string")return J.aI.prototype
if(a==null)return a
if(!(a instanceof A.j))return J.az.prototype
return a},
fl(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.aQ(a).M(a,b)},
hF(a,b){if(typeof b==="number")if(Array.isArray(a)||typeof a=="string")if(b>>>0===b&&b<a.length)return a[b]
return J.bU(a).i(a,b)},
hG(a,b){return J.jk(a).E(a,b)},
fm(a,b){return J.bT(a).C(a,b)},
ba(a){return J.aQ(a).gB(a)},
fn(a){return J.bU(a).gv(a)},
hH(a){return J.bT(a).gX(a)},
a2(a){return J.bT(a).gq(a)},
aE(a){return J.bU(a).gl(a)},
hI(a){return J.aQ(a).gS(a)},
cH(a,b,c){return J.bT(a).aQ(a,b,c)},
fo(a,b){return J.bT(a).K(a,b)},
aT(a){return J.aQ(a).k(a)},
ch:function ch(){},
cj:function cj(){},
bn:function bn(){},
b_:function b_(){},
ax:function ax(){},
el:function el(){},
az:function az(){},
bo:function bo(){},
n:function n(a){this.$ti=a},
ci:function ci(){},
e8:function e8(a){this.$ti=a},
aF:function aF(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aY:function aY(){},
bm:function bm(){},
ck:function ck(){},
aI:function aI(){}},A={f7:function f7(){},
ft(a,b,c){if(t.O.b(a))return new A.bL(a,b.h("@<0>").t(c).h("bL<1,2>"))
return new A.aG(a,b.h("@<0>").t(c).h("aG<1,2>"))},
fU(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
ia(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
hh(a,b,c){return a},
fi(a){var s,r
for(s=$.U.length,r=0;r<s;++r)if(a===$.U[r])return!0
return!1},
en(a,b,c,d){A.an(b,"start")
if(c!=null){A.an(c,"end")
if(b>c)A.aD(A.a8(b,0,c,"start",null))}return new A.bE(a,b,c,d.h("bE<0>"))},
i2(a,b,c,d){if(t.O.b(a))return new A.bh(a,b,c.h("@<0>").t(d).h("bh<1,2>"))
return new A.am(a,b,c.h("@<0>").t(d).h("am<1,2>"))},
fS(a,b,c){var s="count"
if(t.O.b(a)){A.cV(b,s,t.S)
A.an(b,s)
return new A.aV(a,b,c.h("aV<0>"))}A.cV(b,s,t.S)
A.an(b,s)
return new A.ao(a,b,c.h("ao<0>"))},
aX(){return new A.b2("No element")},
hV(){return new A.b2("Too few elements")},
b5:function b5(){},
bb:function bb(a,b){this.a=a
this.$ti=b},
aG:function aG(a,b){this.a=a
this.$ti=b},
bL:function bL(a,b){this.a=a
this.$ti=b},
co:function co(a){this.a=a},
em:function em(){},
p:function p(){},
q:function q(){},
bE:function bE(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
bu:function bu(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
am:function am(a,b,c){this.a=a
this.b=b
this.$ti=c},
bh:function bh(a,b,c){this.a=a
this.b=b
this.$ti=c},
by:function by(a,b,c){var _=this
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
bk:function bk(a,b,c){this.a=a
this.b=b
this.$ti=c},
bl:function bl(a,b,c,d){var _=this
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
bC:function bC(a,b,c){this.a=a
this.b=b
this.$ti=c},
bi:function bi(a){this.$ti=a},
bj:function bj(a){this.$ti=a},
fv(a,b,c){var s,r,q,p,o,n,m,l=A.i(a),k=A.f9(new A.aj(a,l.h("aj<1>")),!0,b),j=k.length,i=0
for(;;){if(!(i<j)){s=!0
break}r=k[i]
if(typeof r!="string"||"__proto__"===r){s=!1
break}++i}if(s){q={}
for(p=0,i=0;i<k.length;k.length===j||(0,A.au)(k),++i,p=o){r=k[i]
c.a(a.i(0,r))
o=p+1
q[r]=p}n=A.f9(new A.ak(a,l.h("ak<2>")),!0,c)
m=new A.Q(q,n,b.h("@<0>").t(c).h("Q<1,2>"))
m.$keys=k
return m}return new A.be(A.hZ(a,b,c),b.h("@<0>").t(c).h("be<1,2>"))},
hq(a){var s=v.mangledGlobalNames[a]
if(s!=null)return s
return"minified:"+a},
x(a){var s
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
s=J.aT(a)
return s},
cr(a){var s,r=$.fI
if(r==null)r=$.fI=Symbol("identityHashCode")
s=a[r]
if(s==null){s=Math.random()*0x3fffffff|0
a[r]=s}return s},
i3(a,b){var s,r=/^\s*[+-]?((0x[a-f0-9]+)|(\d+)|([a-z0-9]+))\s*$/i.exec(a)
if(r==null)return null
if(3>=r.length)return A.b(r,3)
s=r[3]
if(s!=null)return parseInt(a,10)
if(r[2]!=null)return parseInt(a,16)
return null},
cs(a){var s,r,q,p
if(a instanceof A.j)return A.M(A.bV(a),null)
s=J.aQ(a)
if(s===B.at||s===B.au||t.ak.b(a)){r=B.a1(a)
if(r!=="Object"&&r!=="")return r
q=a.constructor
if(typeof q=="function"){p=q.name
if(typeof p=="string"&&p!=="Object"&&p!=="")return p}}return A.M(A.bV(a),null)},
i4(a){var s,r,q
if(typeof a=="number"||A.ff(a))return J.aT(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.K)return a.k(0)
s=$.hE()
for(r=0;r<1;++r){q=s[r].c5(a)
if(q!=null)return q}return"Instance of '"+A.cs(a)+"'"},
G(a){var s
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){s=a-65536
return String.fromCharCode((B.c.aJ(s,10)|55296)>>>0,s&1023|56320)}throw A.d(A.a8(a,0,1114111,null,null))},
fP(a,b,c,d,e,f,g,h,i){var s,r,q,p=b-1
if(0<=a&&a<100){a+=400
p-=4800}s=B.c.T(h,1000)
g+=B.c.A(h-s,1000)
r=i?Date.UTC(a,p,c,d,e,f,g):new Date(a,p,c,d,e,f,g).valueOf()
q=!0
if(!isNaN(r))if(!(r<-864e13))if(!(r>864e13))q=r===864e13&&s!==0
if(q)return null
return r},
R(a){if(a.date===void 0)a.date=new Date(a.a)
return a.date},
cq(a){return a.c?A.R(a).getUTCFullYear()+0:A.R(a).getFullYear()+0},
fN(a){return a.c?A.R(a).getUTCMonth()+1:A.R(a).getMonth()+1},
fJ(a){return a.c?A.R(a).getUTCDate()+0:A.R(a).getDate()+0},
fK(a){return a.c?A.R(a).getUTCHours()+0:A.R(a).getHours()+0},
fM(a){return a.c?A.R(a).getUTCMinutes()+0:A.R(a).getMinutes()+0},
fO(a){return a.c?A.R(a).getUTCSeconds()+0:A.R(a).getSeconds()+0},
fL(a){return a.c?A.R(a).getUTCMilliseconds()+0:A.R(a).getMilliseconds()+0},
jn(a){throw A.d(A.hg(a))},
b(a,b){if(a==null)J.aE(a)
throw A.d(A.eV(a,b))},
eV(a,b){var s,r="index",q=null
if(!A.hc(b))return new A.ac(!0,b,r,q)
s=J.aE(a)
if(b<0||b>=s)return A.e5(b,s,a,q,r)
return new A.bA(q,q,!0,b,r,"Value not in range")},
hg(a){return new A.ac(!0,a,null,null)},
d(a){return A.E(a,new Error())},
E(a,b){var s
if(a==null)a=new A.bH()
b.dartException=a
s=A.ju
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:s})
b.name=""}else b.toString=s
return b},
ju(){return J.aT(this.dartException)},
aD(a,b){throw A.E(a,b==null?new Error():b)},
cG(a,b,c){var s
if(b==null)b=0
if(c==null)c=0
s=Error()
A.aD(A.iH(a,b,c),s)},
iH(a,b,c){var s,r,q,p,o,n,m,l,k
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
return new A.bK("'"+s+"': Cannot "+o+" "+l+k+n)},
au(a){throw A.d(A.N(a))},
ar(a){var s,r,q,p,o,n
a=A.js(a.replace(String({}),"$receiver$"))
s=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(s==null)s=A.o([],t.s)
r=s.indexOf("\\$arguments\\$")
q=s.indexOf("\\$argumentsExpr\\$")
p=s.indexOf("\\$expr\\$")
o=s.indexOf("\\$method\\$")
n=s.indexOf("\\$receiver\\$")
return new A.ey(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),r,q,p,o,n)},
ez(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(s){return s.message}}(a)},
fV(a){return function($expr$){try{$expr$.$method$}catch(s){return s.message}}(a)},
f8(a,b){var s=b==null,r=s?null:b.method
return new A.cm(a,r,s?null:b.receiver)},
fj(a){if(a==null)return new A.ek(a)
if(typeof a!=="object")return a
if("dartException" in a)return A.aS(a,a.dartException)
return A.ja(a)},
aS(a,b){if(t.bU.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
ja(a){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(!("message" in a))return a
s=a.message
if("number" in a&&typeof a.number=="number"){r=a.number
q=r&65535
if((B.c.aJ(r,16)&8191)===10)switch(q){case 438:return A.aS(a,A.f8(A.x(s)+" (Error "+q+")",null))
case 445:case 5007:A.x(s)
return A.aS(a,new A.bz())}}if(a instanceof TypeError){p=$.ht()
o=$.hu()
n=$.hv()
m=$.hw()
l=$.hz()
k=$.hA()
j=$.hy()
$.hx()
i=$.hC()
h=$.hB()
g=p.I(s)
if(g!=null)return A.aS(a,A.f8(A.H(s),g))
else{g=o.I(s)
if(g!=null){g.method="call"
return A.aS(a,A.f8(A.H(s),g))}else if(n.I(s)!=null||m.I(s)!=null||l.I(s)!=null||k.I(s)!=null||j.I(s)!=null||m.I(s)!=null||i.I(s)!=null||h.I(s)!=null){A.H(s)
return A.aS(a,new A.bz())}}return A.aS(a,new A.cy(typeof s=="string"?s:""))}if(a instanceof RangeError){if(typeof s=="string"&&s.indexOf("call stack")!==-1)return new A.bD()
s=function(b){try{return String(b)}catch(f){}return null}(a)
return A.aS(a,new A.ac(!1,null,null,typeof s=="string"?s.replace(/^RangeError:\s*/,""):s))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof s=="string"&&s==="too much recursion")return new A.bD()
return a},
hm(a){if(a==null)return J.ba(a)
if(typeof a=="object")return A.cr(a)
return J.ba(a)},
ji(a,b){var s,r,q,p=a.length
for(s=0;s<p;s=q){r=s+1
q=r+1
b.u(0,a[s],a[r])}return b},
jj(a,b){var s,r=a.length
for(s=0;s<r;++s)b.m(0,a[s])
return b},
iR(a,b,c,d,e,f){t.Z.a(a)
switch(A.aa(b)){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.d(new A.eD("Unsupported number of arguments for wrapped closure"))},
jd(a,b){var s=a.$identity
if(!!s)return s
s=A.je(a,b)
a.$identity=s
return s},
je(a,b){var s
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
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.iR)},
hQ(a2){var s,r,q,p,o,n,m,l,k,j,i=a2.co,h=a2.iS,g=a2.iI,f=a2.nDA,e=a2.aI,d=a2.fs,c=a2.cs,b=d[0],a=c[0],a0=i[b],a1=a2.fT
a1.toString
s=h?Object.create(new A.cv().constructor.prototype):Object.create(new A.aU(null,null).constructor.prototype)
s.$initialize=s.constructor
r=h?function static_tear_off(){this.$initialize()}:function tear_off(a3,a4){this.$initialize(a3,a4)}
s.constructor=r
r.prototype=s
s.$_name=b
s.$_target=a0
q=!h
if(q)p=A.fu(b,a0,g,f)
else{s.$static_name=b
p=a0}s.$S=A.hM(a1,h,g)
s[a]=p
for(o=p,n=1;n<d.length;++n){m=d[n]
if(typeof m=="string"){l=i[m]
k=m
m=l}else k=""
j=c[n]
if(j!=null){if(q)m=A.fu(k,m,g,f)
s[j]=m}if(n===e)o=m}s.$C=o
s.$R=a2.rC
s.$D=a2.dV
return r},
hM(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.d("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.hK)}throw A.d("Error in functionType of tearoff")},
hN(a,b,c,d){var s=A.fs
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,s)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,s)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,s)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,s)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,s)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,s)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,s)}},
fu(a,b,c,d){if(c)return A.hP(a,b,d)
return A.hN(b.length,d,a,b)},
hO(a,b,c,d){var s=A.fs,r=A.hL
switch(b?-1:a){case 0:throw A.d(new A.ct("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,r,s)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,r,s)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,r,s)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,r,s)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,r,s)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,r,s)
default:return function(e,f,g){return function(){var q=[g(this)]
Array.prototype.push.apply(q,arguments)
return e.apply(f(this),q)}}(d,r,s)}},
hP(a,b,c){var s,r
if($.fq==null)$.fq=A.fp("interceptor")
if($.fr==null)$.fr=A.fp("receiver")
s=b.length
r=A.hO(s,c,a,b)
return r},
fg(a){return A.hQ(a)},
hK(a,b){return A.eL(v.typeUniverse,A.bV(a.a),b)},
fs(a){return a.a},
hL(a){return a.b},
fp(a){var s,r,q,p=new A.aU("receiver","interceptor"),o=Object.getOwnPropertyNames(p)
o.$flags=1
s=o
for(o=s.length,r=0;r<o;++r){q=s[r]
if(p[q]===a)return q}throw A.d(A.f5("Field name "+a+" not found."))},
hj(a){return v.getIsolateTag(a)},
jg(a,b){var s=b.length,r=v.rttc[""+s+";"+a]
if(r==null)return null
if(s===0)return r
if(s===r.length)return r.apply(null,b)
return r(b)},
hY(a,b,c,d,e,f){var s=function(g,h){try{return new RegExp(g,h)}catch(r){return r}}(a,""+""+""+""+f)
if(s instanceof RegExp)return s
throw A.d(A.cd("Illegal RegExp pattern ("+String(s)+")",a))},
js(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
be:function be(a,b){this.a=a
this.$ti=b},
bd:function bd(){},
di:function di(a,b,c){this.a=a
this.b=b
this.c=c},
Q:function Q(a,b,c){this.a=a
this.b=b
this.$ti=c},
cf:function cf(){},
aW:function aW(a,b){this.a=a
this.$ti=b},
bB:function bB(){},
ey:function ey(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
bz:function bz(){},
cm:function cm(a,b,c){this.a=a
this.b=b
this.c=c},
cy:function cy(a){this.a=a},
ek:function ek(a){this.a=a},
K:function K(){},
bZ:function bZ(){},
c_:function c_(){},
cw:function cw(){},
cv:function cv(){},
aU:function aU(a,b){this.a=a
this.b=b},
ct:function ct(a){this.a=a},
ai:function ai(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
e9:function e9(a){this.a=a},
ed:function ed(a,b){this.a=a
this.b=b
this.c=null},
aj:function aj(a,b){this.a=a
this.$ti=b},
bs:function bs(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
ak:function ak(a,b){this.a=a
this.$ti=b},
bt:function bt(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
bq:function bq(a,b){this.a=a
this.$ti=b},
br:function br(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
cl:function cl(a,b){this.a=a
this.b=b},
eI:function eI(a){this.b=a},
fa(a,b){var s=b.c
return s==null?b.c=A.bP(a,"fz",[b.x]):s},
fR(a){var s=a.w
if(s===6||s===7)return A.fR(a.x)
return s===11||s===12},
i7(a){return a.as},
ab(a){return A.eK(v.typeUniverse,a,!1)},
jp(a,b){var s,r,q,p,o
if(a==null)return null
s=b.y
r=a.Q
if(r==null)r=a.Q=new Map()
q=b.as
p=r.get(q)
if(p!=null)return p
o=A.aC(v.typeUniverse,a.x,s,0)
r.set(q,o)
return o},
aC(a1,a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=a2.w
switch(a0){case 5:case 1:case 2:case 3:case 4:return a2
case 6:s=a2.x
r=A.aC(a1,s,a3,a4)
if(r===s)return a2
return A.h3(a1,r,!0)
case 7:s=a2.x
r=A.aC(a1,s,a3,a4)
if(r===s)return a2
return A.h2(a1,r,!0)
case 8:q=a2.y
p=A.b8(a1,q,a3,a4)
if(p===q)return a2
return A.bP(a1,a2.x,p)
case 9:o=a2.x
n=A.aC(a1,o,a3,a4)
m=a2.y
l=A.b8(a1,m,a3,a4)
if(n===o&&l===m)return a2
return A.fc(a1,n,l)
case 10:k=a2.x
j=a2.y
i=A.b8(a1,j,a3,a4)
if(i===j)return a2
return A.h4(a1,k,i)
case 11:h=a2.x
g=A.aC(a1,h,a3,a4)
f=a2.y
e=A.j7(a1,f,a3,a4)
if(g===h&&e===f)return a2
return A.h1(a1,g,e)
case 12:d=a2.y
a4+=d.length
c=A.b8(a1,d,a3,a4)
o=a2.x
n=A.aC(a1,o,a3,a4)
if(c===d&&n===o)return a2
return A.fd(a1,n,c,!0)
case 13:b=a2.x
if(b<a4)return a2
a=a3[b-a4]
if(a==null)return a2
return a
default:throw A.d(A.bY("Attempted to substitute unexpected RTI kind "+a0))}},
b8(a,b,c,d){var s,r,q,p,o=b.length,n=A.eM(o)
for(s=!1,r=0;r<o;++r){q=b[r]
p=A.aC(a,q,c,d)
if(p!==q)s=!0
n[r]=p}return s?n:b},
j8(a,b,c,d){var s,r,q,p,o,n,m=b.length,l=A.eM(m)
for(s=!1,r=0;r<m;r+=3){q=b[r]
p=b[r+1]
o=b[r+2]
n=A.aC(a,o,c,d)
if(n!==o)s=!0
l.splice(r,3,q,p,n)}return s?l:b},
j7(a,b,c,d){var s,r=b.a,q=A.b8(a,r,c,d),p=b.b,o=A.b8(a,p,c,d),n=b.c,m=A.j8(a,n,c,d)
if(q===r&&o===p&&m===n)return b
s=new A.cA()
s.a=q
s.b=o
s.c=m
return s},
o(a,b){a[v.arrayRti]=b
return a},
eT(a){var s=a.$S
if(s!=null){if(typeof s=="number")return A.jm(s)
return a.$S()}return null},
jo(a,b){var s
if(A.fR(b))if(a instanceof A.K){s=A.eT(a)
if(s!=null)return s}return A.bV(a)},
bV(a){if(a instanceof A.j)return A.i(a)
if(Array.isArray(a))return A.h(a)
return A.fe(J.aQ(a))},
h(a){var s=a[v.arrayRti],r=t.gn
if(s==null)return r
if(s.constructor!==r.constructor)return r
return s},
i(a){var s=a.$ti
return s!=null?s:A.fe(a)},
fe(a){var s=a.constructor,r=s.$ccache
if(r!=null)return r
return A.iP(a,s)},
iP(a,b){var s=a instanceof A.K?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,r=A.iv(v.typeUniverse,s.name)
b.$ccache=r
return r},
jm(a){var s,r=v.types,q=r[a]
if(typeof q=="string"){s=A.eK(v.typeUniverse,q,!1)
r[a]=s
return s}return q},
jl(a){return A.at(A.i(a))},
fh(a){var s=A.eT(a)
return A.at(s==null?A.bV(a):s)},
j6(a){var s=a instanceof A.K?A.eT(a):null
if(s!=null)return s
if(t.dm.b(a))return J.hI(a).a
if(Array.isArray(a))return A.h(a)
return A.bV(a)},
at(a){var s=a.r
return s==null?a.r=new A.eJ(a):s},
jv(a){return A.at(A.eK(v.typeUniverse,a,!1))},
iO(a){var s=this
s.b=A.j5(s)
return s.b(a)},
j5(a){var s,r,q,p,o
if(a===t.C)return A.iX
if(A.aR(a))return A.j0
s=a.w
if(s===6)return A.iL
if(s===1)return A.he
if(s===7)return A.iS
r=A.j4(a)
if(r!=null)return r
if(s===8){q=a.x
if(a.y.every(A.aR)){a.f="$i"+q
if(q==="u")return A.iV
if(a===t.m)return A.iU
return A.j_}}else if(s===10){p=A.jg(a.x,a.y)
o=p==null?A.he:p
return o==null?A.h8(o):o}return A.iJ},
j4(a){if(a.w===8){if(a===t.S)return A.hc
if(a===t.i||a===t.H)return A.iW
if(a===t.N)return A.iZ
if(a===t.y)return A.ff}return null},
iN(a){var s=this,r=A.iI
if(A.aR(s))r=A.iE
else if(s===t.C)r=A.h8
else if(A.b9(s)){r=A.iK
if(s===t.I)r=A.iA
else if(s===t.dk)r=A.iD
else if(s===t.fQ)r=A.iy
else if(s===t.cg)r=A.h7
else if(s===t.cD)r=A.iz
else if(s===t.an)r=A.iC}else if(s===t.S)r=A.aa
else if(s===t.N)r=A.H
else if(s===t.y)r=A.eP
else if(s===t.H)r=A.v
else if(s===t.i)r=A.m
else if(s===t.m)r=A.iB
s.a=r
return s.a(a)},
iJ(a){var s=this
if(a==null)return A.b9(s)
return A.hk(v.typeUniverse,A.jo(a,s),s)},
iL(a){if(a==null)return!0
return this.x.b(a)},
j_(a){var s,r=this
if(a==null)return A.b9(r)
s=r.f
if(a instanceof A.j)return!!a[s]
return!!J.aQ(a)[s]},
iV(a){var s,r=this
if(a==null)return A.b9(r)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
s=r.f
if(a instanceof A.j)return!!a[s]
return!!J.aQ(a)[s]},
iU(a){var s=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.j)return!!a[s.f]
return!0}if(typeof a=="function")return!0
return!1},
hd(a){if(typeof a=="object"){if(a instanceof A.j)return t.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
iI(a){var s=this
if(a==null){if(A.b9(s))return a}else if(s.b(a))return a
throw A.E(A.h9(a,s),new Error())},
iK(a){var s=this
if(a==null||s.b(a))return a
throw A.E(A.h9(a,s),new Error())},
h9(a,b){return new A.b6("TypeError: "+A.fW(a,A.M(b,null)))},
jc(a,b,c,d){if(A.hk(v.typeUniverse,a,b))return a
throw A.E(A.il("The type argument '"+A.M(a,null)+"' is not a subtype of the type variable bound '"+A.M(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
fW(a,b){return A.cc(a)+": type '"+A.M(A.j6(a),null)+"' is not a subtype of type '"+b+"'"},
il(a){return new A.b6("TypeError: "+a)},
W(a,b){return new A.b6("TypeError: "+A.fW(a,b))},
iS(a){var s=this
return s.x.b(a)||A.fa(v.typeUniverse,s).b(a)},
iX(a){return a!=null},
h8(a){if(a!=null)return a
throw A.E(A.W(a,"Object"),new Error())},
j0(a){return!0},
iE(a){return a},
he(a){return!1},
ff(a){return!0===a||!1===a},
eP(a){if(!0===a)return!0
if(!1===a)return!1
throw A.E(A.W(a,"bool"),new Error())},
iy(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.E(A.W(a,"bool?"),new Error())},
m(a){if(typeof a=="number")return a
throw A.E(A.W(a,"double"),new Error())},
iz(a){if(typeof a=="number")return a
if(a==null)return a
throw A.E(A.W(a,"double?"),new Error())},
hc(a){return typeof a=="number"&&Math.floor(a)===a},
aa(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.E(A.W(a,"int"),new Error())},
iA(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.E(A.W(a,"int?"),new Error())},
iW(a){return typeof a=="number"},
v(a){if(typeof a=="number")return a
throw A.E(A.W(a,"num"),new Error())},
h7(a){if(typeof a=="number")return a
if(a==null)return a
throw A.E(A.W(a,"num?"),new Error())},
iZ(a){return typeof a=="string"},
H(a){if(typeof a=="string")return a
throw A.E(A.W(a,"String"),new Error())},
iD(a){if(typeof a=="string")return a
if(a==null)return a
throw A.E(A.W(a,"String?"),new Error())},
iB(a){if(A.hd(a))return a
throw A.E(A.W(a,"JSObject"),new Error())},
iC(a){if(a==null)return a
if(A.hd(a))return a
throw A.E(A.W(a,"JSObject?"),new Error())},
hf(a,b){var s,r,q
for(s="",r="",q=0;q<a.length;++q,r=", ")s+=r+A.M(a[q],b)
return s},
j3(a,b){var s,r,q,p,o,n,m=a.x,l=a.y
if(""===m)return"("+A.hf(l,b)+")"
s=l.length
r=m.split(",")
q=r.length-s
for(p="(",o="",n=0;n<s;++n,o=", "){p+=o
if(q===0)p+="{"
p+=A.M(l[n],b)
if(q>=0)p+=" "+r[q];++q}return p+"})"},
ha(a3,a4,a5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=", ",a2=null
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
if(l===8){p=A.j9(a.x)
o=a.y
return o.length>0?p+("<"+A.hf(o,b)+">"):p}if(l===10)return A.j3(a,b)
if(l===11)return A.ha(a,b,null)
if(l===12)return A.ha(a.x,b,a.y)
if(l===13){n=a.x
m=b.length
n=m-1-n
if(!(n>=0&&n<m))return A.b(b,n)
return b[n]}return"?"},
j9(a){var s=v.mangledGlobalNames[a]
if(s!=null)return s
return"minified:"+a},
iw(a,b){var s=a.tR[b]
while(typeof s=="string")s=a.tR[s]
return s},
iv(a,b){var s,r,q,p,o,n=a.eT,m=n[b]
if(m==null)return A.eK(a,b,!1)
else if(typeof m=="number"){s=m
r=A.bQ(a,5,"#")
q=A.eM(s)
for(p=0;p<s;++p)q[p]=r
o=A.bP(a,b,q)
n[b]=o
return o}else return m},
it(a,b){return A.h5(a.tR,b)},
is(a,b){return A.h5(a.eT,b)},
eK(a,b,c){var s,r=a.eC,q=r.get(b)
if(q!=null)return q
s=A.h_(A.fY(a,null,b,!1))
r.set(b,s)
return s},
eL(a,b,c){var s,r,q=b.z
if(q==null)q=b.z=new Map()
s=q.get(c)
if(s!=null)return s
r=A.h_(A.fY(a,b,c,!0))
q.set(c,r)
return r},
iu(a,b,c){var s,r,q,p=b.Q
if(p==null)p=b.Q=new Map()
s=c.as
r=p.get(s)
if(r!=null)return r
q=A.fc(a,b,c.w===9?c.y:[c])
p.set(s,q)
return q},
aA(a,b){b.a=A.iN
b.b=A.iO
return b},
bQ(a,b,c){var s,r,q=a.eC.get(c)
if(q!=null)return q
s=new A.a_(null,null)
s.w=b
s.as=c
r=A.aA(a,s)
a.eC.set(c,r)
return r},
h3(a,b,c){var s,r=b.as+"?",q=a.eC.get(r)
if(q!=null)return q
s=A.iq(a,b,r,c)
a.eC.set(r,s)
return s},
iq(a,b,c,d){var s,r,q
if(d){s=b.w
r=!0
if(!A.aR(b))if(!(b===t.a||b===t.T))if(s!==6)r=s===7&&A.b9(b.x)
if(r)return b
else if(s===1)return t.a}q=new A.a_(null,null)
q.w=6
q.x=b
q.as=c
return A.aA(a,q)},
h2(a,b,c){var s,r=b.as+"/",q=a.eC.get(r)
if(q!=null)return q
s=A.io(a,b,r,c)
a.eC.set(r,s)
return s},
io(a,b,c,d){var s,r
if(d){s=b.w
if(A.aR(b)||b===t.C)return b
else if(s===1)return A.bP(a,"fz",[b])
else if(b===t.a||b===t.T)return t.eH}r=new A.a_(null,null)
r.w=7
r.x=b
r.as=c
return A.aA(a,r)},
ir(a,b){var s,r,q=""+b+"^",p=a.eC.get(q)
if(p!=null)return p
s=new A.a_(null,null)
s.w=13
s.x=b
s.as=q
r=A.aA(a,s)
a.eC.set(q,r)
return r},
bO(a){var s,r,q,p=a.length
for(s="",r="",q=0;q<p;++q,r=",")s+=r+a[q].as
return s},
im(a){var s,r,q,p,o,n=a.length
for(s="",r="",q=0;q<n;q+=3,r=","){p=a[q]
o=a[q+1]?"!":":"
s+=r+p+o+a[q+2].as}return s},
bP(a,b,c){var s,r,q,p=b
if(c.length>0)p+="<"+A.bO(c)+">"
s=a.eC.get(p)
if(s!=null)return s
r=new A.a_(null,null)
r.w=8
r.x=b
r.y=c
if(c.length>0)r.c=c[0]
r.as=p
q=A.aA(a,r)
a.eC.set(p,q)
return q},
fc(a,b,c){var s,r,q,p,o,n
if(b.w===9){s=b.x
r=b.y.concat(c)}else{r=c
s=b}q=s.as+(";<"+A.bO(r)+">")
p=a.eC.get(q)
if(p!=null)return p
o=new A.a_(null,null)
o.w=9
o.x=s
o.y=r
o.as=q
n=A.aA(a,o)
a.eC.set(q,n)
return n},
h4(a,b,c){var s,r,q="+"+(b+"("+A.bO(c)+")"),p=a.eC.get(q)
if(p!=null)return p
s=new A.a_(null,null)
s.w=10
s.x=b
s.y=c
s.as=q
r=A.aA(a,s)
a.eC.set(q,r)
return r},
h1(a,b,c){var s,r,q,p,o,n=b.as,m=c.a,l=m.length,k=c.b,j=k.length,i=c.c,h=i.length,g="("+A.bO(m)
if(j>0){s=l>0?",":""
g+=s+"["+A.bO(k)+"]"}if(h>0){s=l>0?",":""
g+=s+"{"+A.im(i)+"}"}r=n+(g+")")
q=a.eC.get(r)
if(q!=null)return q
p=new A.a_(null,null)
p.w=11
p.x=b
p.y=c
p.as=r
o=A.aA(a,p)
a.eC.set(r,o)
return o},
fd(a,b,c,d){var s,r=b.as+("<"+A.bO(c)+">"),q=a.eC.get(r)
if(q!=null)return q
s=A.ip(a,b,c,r,d)
a.eC.set(r,s)
return s},
ip(a,b,c,d,e){var s,r,q,p,o,n,m,l
if(e){s=c.length
r=A.eM(s)
for(q=0,p=0;p<s;++p){o=c[p]
if(o.w===1){r[p]=o;++q}}if(q>0){n=A.aC(a,b,r,0)
m=A.b8(a,c,r,0)
return A.fd(a,n,m,c!==m)}}l=new A.a_(null,null)
l.w=12
l.x=b
l.y=c
l.as=d
return A.aA(a,l)},
fY(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
h_(a){var s,r,q,p,o,n,m,l=a.r,k=a.s
for(s=l.length,r=0;r<s;){q=l.charCodeAt(r)
if(q>=48&&q<=57)r=A.ig(r+1,q,l,k)
else if((((q|32)>>>0)-97&65535)<26||q===95||q===36||q===124)r=A.fZ(a,r,l,k,!1)
else if(q===46)r=A.fZ(a,r,l,k,!0)
else{++r
switch(q){case 44:break
case 58:k.push(!1)
break
case 33:k.push(!0)
break
case 59:k.push(A.aP(a.u,a.e,k.pop()))
break
case 94:k.push(A.ir(a.u,k.pop()))
break
case 35:k.push(A.bQ(a.u,5,"#"))
break
case 64:k.push(A.bQ(a.u,2,"@"))
break
case 126:k.push(A.bQ(a.u,3,"~"))
break
case 60:k.push(a.p)
a.p=k.length
break
case 62:A.ii(a,k)
break
case 38:A.ih(a,k)
break
case 63:p=a.u
k.push(A.h3(p,A.aP(p,a.e,k.pop()),a.n))
break
case 47:p=a.u
k.push(A.h2(p,A.aP(p,a.e,k.pop()),a.n))
break
case 40:k.push(-3)
k.push(a.p)
a.p=k.length
break
case 41:A.ie(a,k)
break
case 91:k.push(a.p)
a.p=k.length
break
case 93:o=k.splice(a.p)
A.h0(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-1)
break
case 123:k.push(a.p)
a.p=k.length
break
case 125:o=k.splice(a.p)
A.ik(a.u,a.e,o)
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
return A.aP(a.u,a.e,m)},
ig(a,b,c,d){var s,r,q=b-48
for(s=c.length;a<s;++a){r=c.charCodeAt(a)
if(!(r>=48&&r<=57))break
q=q*10+(r-48)}d.push(q)
return a},
fZ(a,b,c,d,e){var s,r,q,p,o,n,m=b+1
for(s=c.length;m<s;++m){r=c.charCodeAt(m)
if(r===46){if(e)break
e=!0}else{if(!((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124))q=r>=48&&r<=57
else q=!0
if(!q)break}}p=c.substring(b,m)
if(e){s=a.u
o=a.e
if(o.w===9)o=o.x
n=A.iw(s,o.x)[p]
if(n==null)A.aD('No "'+p+'" in "'+A.i7(o)+'"')
d.push(A.eL(s,o,n))}else d.push(p)
return m},
ii(a,b){var s,r=a.u,q=A.fX(a,b),p=b.pop()
if(typeof p=="string")b.push(A.bP(r,p,q))
else{s=A.aP(r,a.e,p)
switch(s.w){case 11:b.push(A.fd(r,s,q,a.n))
break
default:b.push(A.fc(r,s,q))
break}}},
ie(a,b){var s,r,q,p=a.u,o=b.pop(),n=null,m=null
if(typeof o=="number")switch(o){case-1:n=b.pop()
break
case-2:m=b.pop()
break
default:b.push(o)
break}else b.push(o)
s=A.fX(a,b)
o=b.pop()
switch(o){case-3:o=b.pop()
if(n==null)n=p.sEA
if(m==null)m=p.sEA
r=A.aP(p,a.e,o)
q=new A.cA()
q.a=s
q.b=n
q.c=m
b.push(A.h1(p,r,q))
return
case-4:b.push(A.h4(p,b.pop(),s))
return
default:throw A.d(A.bY("Unexpected state under `()`: "+A.x(o)))}},
ih(a,b){var s=b.pop()
if(0===s){b.push(A.bQ(a.u,1,"0&"))
return}if(1===s){b.push(A.bQ(a.u,4,"1&"))
return}throw A.d(A.bY("Unexpected extended operation "+A.x(s)))},
fX(a,b){var s=b.splice(a.p)
A.h0(a.u,a.e,s)
a.p=b.pop()
return s},
aP(a,b,c){if(typeof c=="string")return A.bP(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.ij(a,b,c)}else return c},
h0(a,b,c){var s,r=c.length
for(s=0;s<r;++s)c[s]=A.aP(a,b,c[s])},
ik(a,b,c){var s,r=c.length
for(s=2;s<r;s+=3)c[s]=A.aP(a,b,c[s])},
ij(a,b,c){var s,r,q=b.w
if(q===9){if(c===0)return b.x
s=b.y
r=s.length
if(c<=r)return s[c-1]
c-=r
b=b.x
q=b.w}else if(c===0)return b
if(q!==8)throw A.d(A.bY("Indexed base must be an interface type"))
s=b.y
if(c<=s.length)return s[c-1]
throw A.d(A.bY("Bad index "+c+" for "+b.k(0)))},
hk(a,b,c){var s,r=b.d
if(r==null)r=b.d=new Map()
s=r.get(c)
if(s==null){s=A.A(a,b,null,c,null)
r.set(c,s)}return s},
A(a,b,c,d,e){var s,r,q,p,o,n,m,l,k,j,i
if(b===d)return!0
if(A.aR(d))return!0
s=b.w
if(s===4)return!0
if(A.aR(b))return!1
if(b.w===1)return!0
r=s===13
if(r)if(A.A(a,c[b.x],c,d,e))return!0
q=d.w
p=t.a
if(b===p||b===t.T){if(q===7)return A.A(a,b,c,d.x,e)
return d===p||d===t.T||q===6}if(d===t.C){if(s===7)return A.A(a,b.x,c,d,e)
return s!==6}if(s===7){if(!A.A(a,b.x,c,d,e))return!1
return A.A(a,A.fa(a,b),c,d,e)}if(s===6)return A.A(a,p,c,d,e)&&A.A(a,b.x,c,d,e)
if(q===7){if(A.A(a,b,c,d.x,e))return!0
return A.A(a,b,c,A.fa(a,d),e)}if(q===6)return A.A(a,b,c,p,e)||A.A(a,b,c,d.x,e)
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
if(!A.A(a,j,c,i,e)||!A.A(a,i,e,j,c))return!1}return A.hb(a,b.x,c,d.x,e)}if(q===11){if(b===t.L)return!0
if(p)return!1
return A.hb(a,b,c,d,e)}if(s===8){if(q!==8)return!1
return A.iT(a,b,c,d,e)}if(o&&q===10)return A.iY(a,b,c,d,e)
return!1},
hb(a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
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
iT(a,b,c,d,e){var s,r,q,p,o,n=b.x,m=d.x
while(n!==m){s=a.tR[n]
if(s==null)return!1
if(typeof s=="string"){n=s
continue}r=s[m]
if(r==null)return!1
q=r.length
p=q>0?new Array(q):v.typeUniverse.sEA
for(o=0;o<q;++o)p[o]=A.eL(a,b,r[o])
return A.h6(a,p,null,c,d.y,e)}return A.h6(a,b.y,null,c,d.y,e)},
h6(a,b,c,d,e,f){var s,r=b.length
for(s=0;s<r;++s)if(!A.A(a,b[s],d,e[s],f))return!1
return!0},
iY(a,b,c,d,e){var s,r=b.y,q=d.y,p=r.length
if(p!==q.length)return!1
if(b.x!==d.x)return!1
for(s=0;s<p;++s)if(!A.A(a,r[s],c,q[s],e))return!1
return!0},
b9(a){var s=a.w,r=!0
if(!(a===t.a||a===t.T))if(!A.aR(a))if(s!==6)r=s===7&&A.b9(a.x)
return r},
aR(a){var s=a.w
return s===2||s===3||s===4||s===5||a===t.U},
h5(a,b){var s,r,q=Object.keys(b),p=q.length
for(s=0;s<p;++s){r=q[s]
a[r]=b[r]}},
eM(a){return a>0?new Array(a):v.typeUniverse.sEA},
a_:function a_(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
cA:function cA(){this.c=this.b=this.a=null},
eJ:function eJ(a){this.a=a},
cz:function cz(){},
b6:function b6(a){this.a=a},
fD(a,b){return new A.ai(a.h("@<0>").t(b).h("ai<1,2>"))},
al(a,b,c){return b.h("@<0>").t(c).h("fC<1,2>").a(A.ji(a,new A.ai(b.h("@<0>").t(c).h("ai<1,2>"))))},
aJ(a,b){return new A.ai(a.h("@<0>").t(b).h("ai<1,2>"))},
fF(a){return new A.as(a.h("as<0>"))},
fG(a){return new A.as(a.h("as<0>"))},
i_(a,b){return b.h("fE<0>").a(A.jj(a,new A.as(b.h("as<0>"))))},
fb(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
id(a,b,c){var s=new A.aO(a,b,c.h("aO<0>"))
s.c=a.e
return s},
hZ(a,b,c){var s=A.fD(b,c)
a.H(0,new A.ee(s,b,c))
return s},
i0(a,b){var s=A.fF(b)
s.L(0,a)
return s},
ei(a){var s,r
if(A.fi(a))return"{...}"
s=new A.b3("")
try{r={}
B.a.m($.U,a)
s.a+="{"
r.a=!0
a.H(0,new A.ej(r,s))
s.a+="}"}finally{if(0>=$.U.length)return A.b($.U,-1)
$.U.pop()}r=s.a
return r.charCodeAt(0)==0?r:r},
i1(a){return 8},
ix(){throw A.d(A.eA("Cannot change an unmodifiable set"))},
as:function as(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
cD:function cD(a){this.a=a
this.b=null},
aO:function aO(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
ee:function ee(a,b,c){this.a=a
this.b=b
this.c=c},
I:function I(){},
ej:function ej(a,b){this.a=a
this.b=b},
bR:function bR(){},
b1:function b1(){},
bI:function bI(){},
ef:function ef(a,b){var _=this
_.a=a
_.d=_.c=_.b=0
_.$ti=b},
bM:function bM(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=null
_.$ti=e},
aN:function aN(){},
bN:function bN(){},
cE:function cE(){},
bJ:function bJ(a,b){this.a=a
this.$ti=b},
b7:function b7(){},
bS:function bS(){},
j2(a,b){var s,r,q,p=null
try{p=JSON.parse(a)}catch(r){s=A.fj(r)
q=A.cd(String(s),null)
throw A.d(q)}q=A.eQ(p)
return q},
eQ(a){var s
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.cB(a,Object.create(null))
for(s=0;s<a.length;++s)a[s]=A.eQ(a[s])
return a},
fB(a,b,c){return new A.bp(a,b)},
iG(a){return a.ce()},
ib(a,b){return new A.eF(a,[],A.jf())},
ic(a,b,c){var s,r=new A.b3(""),q=A.ib(r,b)
q.ac(a)
s=r.a
return s.charCodeAt(0)==0?s:s},
cB:function cB(a,b){this.a=a
this.b=b
this.c=null},
cC:function cC(a){this.a=a},
c0:function c0(){},
c4:function c4(){},
bp:function bp(a,b){this.a=a
this.b=b},
cn:function cn(a,b){this.a=a
this.b=b},
ea:function ea(){},
ec:function ec(a){this.b=a},
eb:function eb(a){this.a=a},
eG:function eG(){},
eH:function eH(a,b){this.a=a
this.b=b},
eF:function eF(a,b,c){this.c=a
this.a=b
this.b=c},
cF(a){var s=A.i3(a,null)
if(s!=null)return s
throw A.d(A.cd(a,null))},
bv(a,b,c,d){var s,r=J.fA(a,d)
if(a!==0&&b!=null)for(s=0;s<a;++s)r[s]=b
return r},
f9(a,b,c){var s,r=A.o([],c.h("n<0>"))
for(s=J.a2(a);s.n();)B.a.m(r,c.a(s.gp()))
if(b)return r
r.$flags=1
return r},
y(a,b){var s,r=A.o([],b.h("n<0>"))
for(s=a.gq(a);s.n();)B.a.m(r,s.gp())
return r},
a7(a,b){var s=A.f9(a,!1,b)
s.$flags=3
return s},
i6(a){return new A.cl(a,A.hY(a,!1,!0,!1,!1,""))},
fT(a,b,c){var s=J.a2(b)
if(!s.n())return a
if(c.length===0){do a+=A.x(s.gp())
while(s.n())}else{a+=A.x(s.gp())
while(s.n())a=a+c+A.x(s.gp())}return a},
hS(a,b,c,d,e,f,g,h,i){var s=A.fP(a,b,c,d,e,f,g,h,i)
if(s==null)return null
return new A.a4(A.fx(s,h,i),h,i)},
hR(a){var s=A.fP(a,1,1,0,0,0,0,0,!0)
return new A.a4(s==null?new A.ds(a,1,1,0,0,0,0,0).$0():s,0,!0)},
hU(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=$.hs().bU(a)
if(c!=null){s=new A.du()
r=c.b
if(1>=r.length)return A.b(r,1)
q=r[1]
q.toString
p=A.cF(q)
if(2>=r.length)return A.b(r,2)
q=r[2]
q.toString
o=A.cF(q)
if(3>=r.length)return A.b(r,3)
q=r[3]
q.toString
n=A.cF(q)
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
e=A.cF(q)
if(11>=r.length)return A.b(r,11)
l-=f*(s.$1(r[11])+60*e)}}d=A.hS(p,o,n,m,l,k,i,j%1000,h)
if(d==null)throw A.d(A.cd("Time out of range",a))
return d}else throw A.d(A.cd("Invalid date format",a))},
fx(a,b,c){var s="microsecond"
if(b<0||b>999)throw A.d(A.a8(b,0,999,s,null))
if(a<-864e13||a>864e13)throw A.d(A.a8(a,-864e13,864e13,"millisecondsSinceEpoch",null))
if(a===864e13&&b!==0)throw A.d(A.hJ(b,s,"Time including microseconds is outside valid range"))
A.hh(c,"isUtc",t.y)
return a},
fw(a){var s=Math.abs(a),r=a<0?"-":""
if(s>=1000)return""+a
if(s>=100)return r+"0"+s
if(s>=10)return r+"00"+s
return r+"000"+s},
hT(a){var s=Math.abs(a),r=a<0?"-":"+"
if(s>=1e5)return r+s
return r+"0"+s},
dt(a){if(a>=100)return""+a
if(a>=10)return"0"+a
return"00"+a},
ae(a){if(a>=10)return""+a
return"0"+a},
C(a,b){return new A.L(a+1000*b)},
cc(a){if(typeof a=="number"||A.ff(a)||a==null)return J.aT(a)
if(typeof a=="string")return JSON.stringify(a)
return A.i4(a)},
bY(a){return new A.bX(a)},
f5(a){return new A.ac(!1,null,null,a)},
hJ(a,b,c){return new A.ac(!0,a,b,c)},
cV(a,b,c){return a},
a8(a,b,c,d,e){return new A.bA(b,c,!0,a,d,"Invalid value")},
fQ(a,b,c){if(0>a||a>c)throw A.d(A.a8(a,0,c,"start",null))
if(a>b||b>c)throw A.d(A.a8(b,a,c,"end",null))
return b},
an(a,b){if(a<0)throw A.d(A.a8(a,0,null,b,null))
return a},
e5(a,b,c,d,e){return new A.ce(b,!0,a,e,"Index out of range")},
eA(a){return new A.bK(a)},
i8(a){return new A.b2(a)},
N(a){return new A.c3(a)},
cd(a,b){return new A.e4(a,b)},
hW(a,b,c){var s,r
if(A.fi(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}s=A.o([],t.s)
B.a.m($.U,a)
try{A.j1(a,s)}finally{if(0>=$.U.length)return A.b($.U,-1)
$.U.pop()}r=A.fT(b,t.hf.a(s),", ")+c
return r.charCodeAt(0)==0?r:r},
f6(a,b,c){var s,r
if(A.fi(a))return b+"..."+c
s=new A.b3(b)
B.a.m($.U,a)
try{r=s
r.a=A.fT(r.a,a,", ")}finally{if(0>=$.U.length)return A.b($.U,-1)
$.U.pop()}s.a+=c
r=s.a
return r.charCodeAt(0)==0?r:r},
j1(a,b){var s,r,q,p,o,n,m,l=a.gq(a),k=0,j=0
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
fH(a,b){var s=J.ba(a)
b=J.ba(b)
b=A.ia(A.fU(A.fU($.hD(),s),b))
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
eC:function eC(){},
t:function t(){},
bX:function bX(a){this.a=a},
bH:function bH(){},
ac:function ac(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bA:function bA(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
ce:function ce(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
bK:function bK(a){this.a=a},
b2:function b2(a){this.a=a},
c3:function c3(a){this.a=a},
cp:function cp(){},
bD:function bD(){},
eD:function eD(a){this.a=a},
e4:function e4(a,b){this.a=a
this.b=b},
c:function c(){},
D:function D(a,b,c){this.a=a
this.b=b
this.$ti=c},
aL:function aL(){},
j:function j(){},
b3:function b3(a){this.a=a},
cI:function cI(){},
cQ:function cQ(a){this.a=a},
cR:function cR(){},
cS:function cS(a){this.a=a},
cT:function cT(a,b){this.a=a
this.b=b},
cU:function cU(a,b){this.a=a
this.b=b},
cJ:function cJ(){},
cL:function cL(){},
cK:function cK(a){this.a=a},
cM:function cM(a,b){this.a=a
this.b=b},
cN:function cN(){},
cP:function cP(){},
cO:function cO(a){this.a=a},
cX:function cX(){},
da:function da(){},
db:function db(){},
cY:function cY(a){this.a=a},
cZ:function cZ(){},
d1:function d1(a){this.a=a},
d2:function d2(){},
d4:function d4(){},
d5:function d5(a){this.a=a},
d6:function d6(){},
d7:function d7(){},
d0:function d0(a){this.a=a},
d_:function d_(a){this.a=a},
d8:function d8(){},
d9:function d9(){},
d3:function d3(a){this.a=a},
aB:function aB(a,b){this.a=a
this.b=b},
a9:function a9(a,b,c){this.a=a
this.b=b
this.c=c},
dc:function dc(a,b,c,d){var _=this
_.a=a
_.f=b
_.r=c
_.z=d},
cW:function cW(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
F:function F(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.w=f
_.x=g},
c1:function c1(a){this.b=a},
dd:function dd(a,b,c,d,e,f,g,h,i,j,k){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.z=i
_.as=j
_.at=k},
ad:function ad(a,b){this.a=a
this.b=b},
c2:function c2(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.r=c
_.w=d
_.x=e
_.y=f},
bc:function bc(a,b){this.a=a
this.b=b},
av:function av(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
dh:function dh(a,b){this.a=a
this.b=b},
iM(a,b){var s
if(!isFinite(a)||a<0||a>=360)return null
s=B.b.T(Math.abs(a-b),360)
return s>180?360-s:s},
de:function de(){},
df:function df(){},
dg:function dg(){},
a1:function a1(a,b,c){this.a=a
this.b=b
this.c=c},
eE:function eE(a,b,c){this.a=a
this.b=b
this.c=c},
c6:function c6(){},
dp:function dp(a,b){this.a=a
this.b=b},
dq:function dq(){},
dr:function dr(){},
dk:function dk(){},
dl:function dl(){},
dm:function dm(){},
dn:function dn(){},
dj:function dj(){},
c5:function c5(a,b,c){this.a=a
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
c8:function c8(){},
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
T:function T(a,b){this.a=a
this.b=b},
dT:function dT(a,b){this.a=a
this.b=b},
bf:function bf(){},
dU:function dU(){},
cg:function cg(){},
e6:function e6(){},
dV:function dV(){},
dW:function dW(){},
bg:function bg(a,b){this.a=a
this.b=b},
B:function B(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
af:function af(a,b){this.b=a
this.c=b},
c9:function c9(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
fy(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s){return new A.k(h,d,s,o,e,q,g,p,f,i,k,c,a,r,n,m,b,l,j)},
a5:function a5(a,b){this.a=a
this.b=b},
b4:function b4(a,b){this.a=a
this.b=b},
aH:function aH(a,b){this.a=a
this.b=b},
aw:function aw(a,b){this.a=a
this.b=b},
O:function O(a,b){this.a=a
this.b=b},
S:function S(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.d=c
_.e=d
_.f=e
_.r=f},
ap:function ap(a,b,c){this.a=a
this.c=b
this.d=c},
ag:function ag(a,b,c){this.a=a
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
c7:function c7(a,b,c){this.b=a
this.c=b
this.f=c},
dx:function dx(a){this.a=a},
dX:function dX(){},
dY:function dY(){},
e_:function e_(){},
dZ:function dZ(a){this.a=a},
e0:function e0(){},
e1:function e1(){},
e2:function e2(){},
e3:function e3(){},
cb:function cb(a,b,c){this.a=a
this.f=b
this.r=c},
ca:function ca(a,b,c){this.a=a
this.b=b
this.c=c},
bW:function bW(a,b,c){this.a=a
this.e=b
this.f=c},
a6:function a6(a,b){this.a=a
this.b=b},
Y:function Y(a,b){this.a=a
this.e=b},
cx:function cx(a,b,c){this.a=a
this.e=b
this.f=c},
b0:function b0(a,b){this.a=a
this.b=b},
bw:function bw(a,b){this.a=a
this.b=b},
ay:function ay(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
aK:function aK(a,b,c,d,e,f,g,h,i,j,k,l){var _=this
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
bx:function bx(a,b,c){this.a=a
this.c=b
this.d=c},
eg:function eg(a){this.a=a},
eh:function eh(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
eO:function eO(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.w=1},
V:function V(a,b){this.a=a
this.b=b},
Z:function Z(a,b,c){this.a=a
this.b=b
this.c=c},
eo:function eo(){},
eN:function eN(a,b){this.a=a
this.b=b},
bG:function bG(a,b,c){this.a=a
this.r=b
this.as=c},
bF:function bF(a){this.a=a},
ep:function ep(){},
eu:function eu(a){this.a=a},
ev:function ev(a){this.a=a},
ew:function ew(){},
ex:function ex(){},
et:function et(a){this.a=a},
er:function er(){},
es:function es(){},
eq:function eq(a){this.a=a},
eB:function eB(a,b,c,d,e){var _=this
_.a=a
_.c=b
_.d=c
_.e=d
_.x=e},
hn(a){var s,r,q=J.cH(t.j.a(a.i(0,"sections")),new A.eY(),t.p),p=A.y(q,q.$ti.h("q.E"))
A.hR(1970)
q=A.H(a.i(0,"id"))
A.H(a.i(0,"driveId"))
s=A.h(p)
r=s.h("bk<1,V>")
s=A.y(new A.bk(p,s.h("c<V>(1)").a(new A.eZ()),r),r.h("c.E"))
return new A.eB(q,s,p,B.a.F(p,0,new A.f_(),t.i),null)},
hp(a){var s=J.cH(a,new A.f4(),t.u)
s=A.y(s,s.$ti.h("q.E"))
return s},
ho(a){var s,r=t.N,q=t.z
if(a==null)r=A.aJ(r,q)
else{s=t.h6
q=A.al(["totalScore",a.a,"displayScore",a.c,"algorithmVersion",a.d,"overallConfidence",a.b,"categories",a.e.a2(0,new A.f0(),r,s),"contributions",a.f.a2(0,new A.f1(),r,s)],r,q)
r=q}return r},
hi(a){var s,r=a.e
r=r==null?null:A.ho(r)
s=a.f
s=s==null?null:A.ho(s)
return A.al(["outcome",a.x.b,"comparisonValid",a.y,"firstLocalScore",r,"secondLocalScore",s,"scoreDifference",a.r,"relativeDifference",a.w],t.N,t.z)},
f2(a){var s=a.b,r=A.h(s),q=r.h("f<1,e>")
r=A.y(new A.f(s,r.h("e(1)").a(new A.f3()),q),q.h("q.E"))
return A.al(["status",a.a.b,"startIndex",a.c,"endIndex",a.d,"count",s.length,"mappingConfidence",a.e,"timestamps",r],t.N,t.z)},
jh(a){var s,r,q="latitude",p="longitude",o=A.H(a.i(0,"firstDriveId")),n=A.H(a.i(0,"secondDriveId")),m=A.H(a.i(0,"firstSectionId")),l=A.H(a.i(0,"secondSectionId")),k=A.v(a.i(0,"firstStartOffsetMeters")),j=A.v(a.i(0,"firstEndOffsetMeters")),i=A.v(a.i(0,"secondStartOffsetMeters")),h=A.v(a.i(0,"secondEndOffsetMeters")),g=t.P,f=g.a(a.i(0,"commonStart"))
A.v(f.i(0,q))
A.v(f.i(0,p))
g=g.a(a.i(0,"commonEnd"))
A.v(g.i(0,q))
A.v(g.i(0,p))
g=A.v(a.i(0,"commonDistanceMeters"))
A.eP(a.i(0,"directionCompatible"))
f=A.v(a.i(0,"geometryConfidence"))
s=A.eP(a.i(0,"comparisonEligible"))
A.eP(a.i(0,"ownershipCovered"))
r=J.cH(t.j.a(a.i(0,"referenceGeometry")),new A.eU(),t.x)
A.y(r,r.$ti.h("q.E"))
return new A.dd(o,n,m,l,k,j,i,h,g,f,s)},
jb(a,b,c,d,e,f){var s,r,q,p,o,n,m,l,k="secondExtraction",j=t.t,i=B.u.bT(b,j.a(d),a,c,j.a(e))
if(!i.gaP())return A.al(["status","telemetryUnavailable","firstExtraction",A.f2(i.a),k,A.f2(i.b),"windows",[],"winningRegions",[]],t.N,t.z)
j=i.a
s=j.b
r=i.b
q=r.b
p=f.bM(B.C,b,s,a,c,q)
o=new A.eg(f).bL(B.C,c,q,b,s,a)
s=A.hi(p)
j=A.f2(j)
r=A.f2(r)
q=o.c
n=A.h(q)
m=n.h("f<1,r<e,j>>")
q=A.y(new A.f(q,n.h("r<e,j>(1)").a(new A.eR()),m),m.h("q.E"))
n=o.d
m=A.h(n)
l=m.h("f<1,r<e,j>>")
n=A.y(new A.f(n,m.h("r<e,j>(1)").a(new A.eS()),l),l.h("q.E"))
return A.al(["status",o.a.b,"comparison",s,"firstExtraction",j,k,r,"windows",q,"winningRegions",n],t.N,t.z)},
eY:function eY(){},
eX:function eX(){},
eZ:function eZ(){},
f_:function f_(){},
f4:function f4(){},
f0:function f0(){},
f1:function f1(){},
f3:function f3(){},
eU:function eU(){},
eR:function eR(){},
eS:function eS(){},
cu:function cu(a){this.y=a
this.z=0},
jq(){var s,r=new A.eW()
if(typeof r=="function")A.aD(A.f5("Attempting to rewrap a JS function."))
s=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.iF,r)
s[$.fk()]=r
v.G.driveItWorldScoringBoundaryTest=s},
eW:function eW(){},
jt(a){throw A.E(new A.co("Field '"+a+"' has been assigned during initialization."),new Error())},
iF(a,b,c){t.Z.a(a)
if(A.aa(c)>=1)return a.$1(b)
return a.$0()},
hl(a,b,c){A.jc(c,t.H,"T","max")
return Math.max(c.a(a),c.a(b))}},B={}
var w=[A,J,B]
var $={}
A.f7.prototype={}
J.ch.prototype={
M(a,b){return a===b},
gB(a){return A.cr(a)},
k(a){return"Instance of '"+A.cs(a)+"'"},
gS(a){return A.at(A.fe(this))}}
J.cj.prototype={
k(a){return String(a)},
gB(a){return a?519018:218159},
gS(a){return A.at(t.y)},
$iaq:1,
$il:1}
J.bn.prototype={
M(a,b){return null==b},
k(a){return"null"},
gB(a){return 0},
$iaq:1}
J.b_.prototype={$iaZ:1}
J.ax.prototype={
gB(a){return 0},
k(a){return String(a)}}
J.el.prototype={}
J.az.prototype={}
J.bo.prototype={
k(a){var s=a[$.hr()]
if(s==null)s=a[$.fk()]
if(s==null)return this.aX(a)
return"JavaScript function for "+J.aT(s)},
$iah:1}
J.n.prototype={
m(a,b){A.h(a).c.a(b)
a.$flags&1&&A.cG(a,29)
a.push(b)},
L(a,b){var s
A.h(a).h("c<1>").a(b)
a.$flags&1&&A.cG(a,"addAll",2)
for(s=b.gq(b);s.n();)a.push(s.gp())},
aQ(a,b,c){var s=A.h(a)
return new A.f(a,s.t(c).h("1(2)").a(b),s.h("@<1>").t(c).h("f<1,2>"))},
c0(a,b){var s,r=A.bv(a.length,"",!1,t.N)
for(s=0;s<a.length;++s)this.u(r,s,A.x(a[s]))
return r.join(b)},
K(a,b){return A.en(a,b,null,A.h(a).c)},
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
a4(a,b,c){if(b<0||b>a.length)throw A.d(A.a8(b,0,a.length,"start",null))
if(c<b||c>a.length)throw A.d(A.a8(c,b,a.length,"end",null))
if(b===c)return A.o([],A.h(a))
return A.o(a.slice(b,c),A.h(a))},
gN(a){if(a.length>0)return a[0]
throw A.d(A.aX())},
ga1(a){var s=a.length
if(s>0)return a[s-1]
throw A.d(A.aX())},
ar(a,b,c,d,e){var s,r,q,p,o
A.h(a).h("c<1>").a(d)
a.$flags&2&&A.cG(a,5)
A.fQ(b,c,a.length)
s=c-b
if(s===0)return
A.an(e,"skipCount")
if(t.j.b(d)){r=d
q=e}else{r=J.fo(d,e).aR(0,!1)
q=0}p=J.bU(r)
if(q+s>p.gl(r))throw A.d(A.hV())
if(q<b)for(o=s-1;o>=0;--o)a[b+o]=p.i(r,q+o)
else for(o=0;o<s;++o)a[b+o]=p.i(r,q+o)},
a0(a,b){var s,r
A.h(a).h("l(1)").a(b)
s=a.length
for(r=0;r<s;++r){if(b.$1(a[r]))return!0
if(a.length!==s)throw A.d(A.N(a))}return!1},
au(a,b){var s,r,q,p,o,n=A.h(a)
n.h("X(1,1)?").a(b)
a.$flags&2&&A.cG(a,"sort")
s=a.length
if(s<2)return
if(b==null)b=J.iQ()
if(s===2){r=a[0]
q=a[1]
n=b.$2(r,q)
if(typeof n!=="number")return n.cb()
if(n>0){a[0]=q
a[1]=r}return}p=0
if(n.c.b(null))for(o=0;o<a.length;++o)if(a[o]===void 0){a[o]=null;++p}a.sort(A.jd(b,2))
if(p>0)this.bp(a,p)},
aW(a){return this.au(a,null)},
bp(a,b){var s,r=a.length
for(;s=r-1,r>0;r=s)if(a[s]===null){a[s]=void 0;--b
if(b===0)break}},
gv(a){return a.length===0},
gX(a){return a.length!==0},
k(a){return A.f6(a,"[","]")},
gq(a){return new J.aF(a,a.length,A.h(a).h("aF<1>"))},
gB(a){return A.cr(a)},
gl(a){return a.length},
i(a,b){A.aa(b)
if(!(b>=0&&b<a.length))throw A.d(A.eV(a,b))
return a[b]},
u(a,b,c){A.h(a).c.a(c)
a.$flags&2&&A.cG(a)
if(!(b>=0&&b<a.length))throw A.d(A.eV(a,b))
a[b]=c},
$ip:1,
$ic:1,
$iu:1}
J.ci.prototype={
c5(a){var s,r,q
if(!Array.isArray(a))return null
s=a.$flags|0
if((s&4)!==0)r="const, "
else if((s&2)!==0)r="unmodifiable, "
else r=(s&1)!==0?"fixed, ":""
q="Instance of '"+A.cs(a)+"'"
if(r==="")return q
return q+" ("+r+"length: "+a.length+")"}}
J.e8.prototype={}
J.aF.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
n(){var s,r=this,q=r.a,p=q.length
if(r.b!==p){q=A.au(q)
throw A.d(q)}s=r.c
if(s>=p){r.d=null
return!1}r.d=q[s]
r.c=s+1
return!0},
$iw:1}
J.aY.prototype={
E(a,b){var s
A.v(b)
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){s=this.gab(b)
if(this.gab(a)===s)return 0
if(this.gab(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gab(a){return a===0?1/a<0:a<0},
c2(a){var s
if(a>=-2147483648&&a<=2147483647)return a|0
if(isFinite(a)){s=a<0?Math.ceil(a):Math.floor(a)
return s+0}throw A.d(A.eA(""+a+".toInt()"))},
a3(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.d(A.eA(""+a+".round()"))},
j(a,b,c){if(this.E(b,c)>0)throw A.d(A.hg(b))
if(this.E(a,b)<0)return b
if(this.E(a,c)>0)return c
return a},
aS(a,b){var s
if(b>20)throw A.d(A.a8(b,0,20,"fractionDigits",null))
s=a.toFixed(b)
if(a===0&&this.gab(a))return"-"+s
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
A(a,b){return(a|0)===a?a/b|0:this.bB(a,b)},
bB(a,b){var s=a/b
if(s>=-2147483648&&s<=2147483647)return s|0
if(s>0){if(s!==1/0)return Math.floor(s)}else if(s>-1/0)return Math.ceil(s)
throw A.d(A.eA("Result of truncating division is "+A.x(s)+": "+A.x(a)+" ~/ "+b))},
aJ(a,b){var s
if(a>0)s=this.bw(a,b)
else{s=b>31?31:b
s=a>>s>>>0}return s},
bw(a,b){return b>31?0:a>>>b},
gS(a){return A.at(t.H)},
$iP:1,
$ia:1,
$iJ:1}
J.bm.prototype={
gS(a){return A.at(t.S)},
$iaq:1,
$iX:1}
J.ck.prototype={
gS(a){return A.at(t.i)},
$iaq:1}
J.aI.prototype={
Y(a,b,c){return a.substring(b,A.fQ(b,c,a.length))},
aq(a,b){var s,r
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.d(B.a2)
for(s=a,r="";;){if((b&1)===1)r=s+r
b=b>>>1
if(b===0)break
s+=s}return r},
c1(a,b,c){var s=b-a.length
if(s<=0)return a
return this.aq(c,s)+a},
E(a,b){var s
A.H(b)
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
if(!(b.ca(0,0)&&b.cd(0,a.length)))throw A.d(A.eV(a,b))
return a[b]},
$iaq:1,
$iP:1,
$ie:1}
A.b5.prototype={
gq(a){return new A.bb(J.a2(this.gV()),A.i(this).h("bb<1,2>"))},
gl(a){return J.aE(this.gV())},
gv(a){return J.fn(this.gV())},
gX(a){return J.hH(this.gV())},
K(a,b){var s=A.i(this)
return A.ft(J.fo(this.gV(),b),s.c,s.y[1])},
k(a){return J.aT(this.gV())}}
A.bb.prototype={
n(){return this.a.n()},
gp(){return this.$ti.y[1].a(this.a.gp())},
$iw:1}
A.aG.prototype={
gV(){return this.a}}
A.bL.prototype={$ip:1}
A.co.prototype={
k(a){return"LateInitializationError: "+this.a}}
A.em.prototype={}
A.p.prototype={}
A.q.prototype={
gq(a){var s=this
return new A.bu(s,s.gl(s),A.i(s).h("bu<q.E>"))},
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
K(a,b){return A.en(this,b,null,A.i(this).h("q.E"))}}
A.bE.prototype={
gb8(){var s=J.aE(this.a),r=this.c
if(r==null||r>s)return s
return r},
gbx(){var s=J.aE(this.a),r=this.b
if(r>s)return s
return r},
gl(a){var s,r=J.aE(this.a),q=this.b
if(q>=r)return 0
s=this.c
if(s==null||s>=r)return r-q
return s-q},
C(a,b){var s=this,r=s.gbx()+b
if(b<0||r>=s.gb8())throw A.d(A.e5(b,s.gl(0),s,null,"index"))
return J.fm(s.a,r)},
K(a,b){var s,r,q=this
A.an(b,"count")
s=q.b+b
r=q.c
if(r!=null&&s>=r)return new A.bi(q.$ti.h("bi<1>"))
return A.en(q.a,s,r,q.$ti.c)},
aR(a,b){var s,r,q,p=this,o=p.b,n=p.a,m=J.bU(n),l=m.gl(n),k=p.c
if(k!=null&&k<l)l=k
s=l-o
if(s<=0){n=J.fA(0,p.$ti.c)
return n}r=A.bv(s,m.C(n,o),!1,p.$ti.c)
for(q=1;q<s;++q){B.a.u(r,q,m.C(n,o+q))
if(m.gl(n)<l)throw A.d(A.N(p))}return r}}
A.bu.prototype={
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
gq(a){return new A.by(J.a2(this.a),this.b,A.i(this).h("by<1,2>"))},
gl(a){return J.aE(this.a)},
gv(a){return J.fn(this.a)}}
A.bh.prototype={$ip:1}
A.by.prototype={
n(){var s=this,r=s.b
if(r.n()){s.a=s.c.$1(r.gp())
return!0}s.a=null
return!1},
gp(){var s=this.a
return s==null?this.$ti.y[1].a(s):s},
$iw:1}
A.f.prototype={
gl(a){return J.aE(this.a)},
C(a,b){return this.b.$1(J.fm(this.a,b))}}
A.z.prototype={
gq(a){return new A.a0(J.a2(this.a),this.b,this.$ti.h("a0<1>"))}}
A.a0.prototype={
n(){var s,r
for(s=this.a,r=this.b;s.n();)if(r.$1(s.gp()))return!0
return!1},
gp(){return this.a.gp()},
$iw:1}
A.bk.prototype={
gq(a){return new A.bl(J.a2(this.a),this.b,B.v,this.$ti.h("bl<1,2>"))}}
A.bl.prototype={
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
K(a,b){A.cV(b,"count",t.S)
A.an(b,"count")
return new A.ao(this.a,this.b+b,A.i(this).h("ao<1>"))},
gq(a){var s=this.a
return new A.bC(s.gq(s),this.b,A.i(this).h("bC<1>"))}}
A.aV.prototype={
gl(a){var s=this.a,r=s.gl(s)-this.b
if(r>=0)return r
return 0},
K(a,b){A.cV(b,"count",t.S)
A.an(b,"count")
return new A.aV(this.a,this.b+b,this.$ti)},
$ip:1}
A.bC.prototype={
n(){var s,r
for(s=this.a,r=0;r<this.b;++r)s.n()
this.b=0
return s.n()},
gp(){return this.a.gp()},
$iw:1}
A.bi.prototype={
gq(a){return B.v},
gv(a){return!0},
gl(a){return 0},
K(a,b){A.an(b,"count")
return this}}
A.bj.prototype={
n(){return!1},
gp(){throw A.d(A.aX())},
$iw:1}
A.be.prototype={}
A.bd.prototype={
gv(a){return this.gl(this)===0},
k(a){return A.ei(this)},
a2(a,b,c,d){var s=A.aJ(c,d)
this.H(0,new A.di(this,A.i(this).t(c).t(d).h("D<1,2>(3,4)").a(b),s))
return s},
$ir:1}
A.di.prototype={
$2(a,b){var s=A.i(this.a),r=this.b.$2(s.c.a(a),s.y[1].a(b))
this.c.u(0,r.a,r.b)},
$S(){return A.i(this.a).h("~(1,2)")}}
A.Q.prototype={
gl(a){return this.b.length},
gbf(){var s=this.$keys
if(s==null){s=Object.keys(this.a)
this.$keys=s}return s},
bN(a){if(typeof a!="string")return!1
if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
i(a,b){if(!this.bN(b))return null
return this.b[this.a[b]]},
H(a,b){var s,r,q,p
this.$ti.h("~(1,2)").a(b)
s=this.gbf()
r=this.b
for(q=s.length,p=0;p<q;++p)b.$2(s[p],r[p])}}
A.cf.prototype={
M(a,b){if(b==null)return!1
return b instanceof A.aW&&this.a.M(0,b.a)&&A.fh(this)===A.fh(b)},
gB(a){return A.fH(this.a,A.fh(this))},
k(a){var s=B.a.c0([A.at(this.$ti.c)],", ")
return this.a.k(0)+" with "+("<"+s+">")}}
A.aW.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.jp(A.eT(this.a),this.$ti)}}
A.bB.prototype={}
A.ey.prototype={
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
A.bz.prototype={
k(a){return"Null check operator used on a null value"}}
A.cm.prototype={
k(a){var s,r=this,q="NoSuchMethodError: method not found: '",p=r.b
if(p==null)return"NoSuchMethodError: "+r.a
s=r.c
if(s==null)return q+p+"' ("+r.a+")"
return q+p+"' on '"+s+"' ("+r.a+")"}}
A.cy.prototype={
k(a){var s=this.a
return s.length===0?"Error":"Error: "+s}}
A.ek.prototype={
k(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.K.prototype={
k(a){var s=this.constructor,r=s==null?null:s.name
return"Closure '"+A.hq(r==null?"unknown":r)+"'"},
$iah:1,
gc8(){return this},
$C:"$1",
$R:1,
$D:null}
A.bZ.prototype={$C:"$0",$R:0}
A.c_.prototype={$C:"$2",$R:2}
A.cw.prototype={}
A.cv.prototype={
k(a){var s=this.$static_name
if(s==null)return"Closure of unknown static method"
return"Closure '"+A.hq(s)+"'"}}
A.aU.prototype={
M(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.aU))return!1
return this.$_target===b.$_target&&this.a===b.a},
gB(a){return(A.hm(this.a)^A.cr(this.$_target))>>>0},
k(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.cs(this.a)+"'")}}
A.ct.prototype={
k(a){return"RuntimeError: "+this.a}}
A.ai.prototype={
gl(a){return this.a},
gv(a){return this.a===0},
gR(){return new A.aj(this,A.i(this).h("aj<1>"))},
L(a,b){A.i(this).h("r<1,2>").a(b).H(0,new A.e9(this))},
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
s=q[this.aN(a)]
r=this.aO(s,a)
if(r<0)return null
return s[r].b},
u(a,b,c){var s,r,q=this,p=A.i(q)
p.c.a(b)
p.y[1].a(c)
if(typeof b=="string"){s=q.b
q.av(s==null?q.b=q.aj():s,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){r=q.c
q.av(r==null?q.c=q.aj():r,b,c)}else q.bY(b,c)},
bY(a,b){var s,r,q,p,o=this,n=A.i(o)
n.c.a(a)
n.y[1].a(b)
s=o.d
if(s==null)s=o.d=o.aj()
r=o.aN(a)
q=s[r]
if(q==null)s[r]=[o.ak(a,b)]
else{p=o.aO(q,a)
if(p>=0)q[p].b=b
else q.push(o.ak(a,b))}},
H(a,b){var s,r,q=this
A.i(q).h("~(1,2)").a(b)
s=q.e
r=q.r
while(s!=null){b.$2(s.a,s.b)
if(r!==q.r)throw A.d(A.N(q))
s=s.c}},
av(a,b,c){var s,r=A.i(this)
r.c.a(b)
r.y[1].a(c)
s=a[b]
if(s==null)a[b]=this.ak(b,c)
else s.b=c},
ak(a,b){var s=this,r=A.i(s),q=new A.ed(r.c.a(a),r.y[1].a(b))
if(s.e==null)s.e=s.f=q
else s.f=s.f.c=q;++s.a
s.r=s.r+1&1073741823
return q},
aN(a){return J.ba(a)&1073741823},
aO(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.fl(a[r].a,b))return r
return-1},
k(a){return A.ei(this)},
aj(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
$ifC:1}
A.e9.prototype={
$2(a,b){var s=this.a,r=A.i(s)
s.u(0,r.c.a(a),r.y[1].a(b))},
$S(){return A.i(this.a).h("~(1,2)")}}
A.ed.prototype={}
A.aj.prototype={
gl(a){return this.a.a},
gv(a){return this.a.a===0},
gq(a){var s=this.a
return new A.bs(s,s.r,s.e,this.$ti.h("bs<1>"))}}
A.bs.prototype={
gp(){return this.d},
n(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.d(A.N(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.a
r.c=s.c
return!0}},
$iw:1}
A.ak.prototype={
gl(a){return this.a.a},
gv(a){return this.a.a===0},
gq(a){var s=this.a
return new A.bt(s,s.r,s.e,this.$ti.h("bt<1>"))}}
A.bt.prototype={
gp(){return this.d},
n(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.d(A.N(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.b
r.c=s.c
return!0}},
$iw:1}
A.bq.prototype={
gl(a){return this.a.a},
gv(a){return this.a.a===0},
gq(a){var s=this.a
return new A.br(s,s.r,s.e,this.$ti.h("br<1,2>"))}}
A.br.prototype={
gp(){var s=this.d
s.toString
return s},
n(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.d(A.N(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=new A.D(s.a,s.b,r.$ti.h("D<1,2>"))
r.c=s.c
return!0}},
$iw:1}
A.cl.prototype={
k(a){return"RegExp/"+this.a+"/"+this.b.flags},
bU(a){var s=this.b.exec(a)
if(s==null)return null
return new A.eI(s)},
$ii5:1}
A.eI.prototype={
i(a,b){var s
A.aa(b)
s=this.b
if(!(b<s.length))return A.b(s,b)
return s[b]}}
A.a_.prototype={
h(a){return A.eL(v.typeUniverse,this,a)},
t(a){return A.iu(v.typeUniverse,this,a)}}
A.cA.prototype={}
A.eJ.prototype={
k(a){return A.M(this.a,null)}}
A.cz.prototype={
k(a){return this.a}}
A.b6.prototype={}
A.as.prototype={
gq(a){var s=this,r=new A.aO(s,s.r,A.i(s).h("aO<1>"))
r.c=s.e
return r},
gl(a){return this.a},
gv(a){return this.a===0},
gX(a){return this.a!==0},
aa(a,b){var s,r
if(typeof b=="string"&&b!=="__proto__"){s=this.b
if(s==null)return!1
return t.M.a(s[b])!=null}else{r=this.b3(b)
return r}},
b3(a){var s=this.d
if(s==null)return!1
return this.aB(s[this.az(a)],a)>=0},
m(a,b){var s,r,q=this
A.i(q).c.a(b)
if(typeof b=="string"&&b!=="__proto__"){s=q.b
return q.aw(s==null?q.b=A.fb():s,b)}else if(typeof b=="number"&&(b&1073741823)===b){r=q.c
return q.aw(r==null?q.c=A.fb():r,b)}else return q.aZ(b)},
aZ(a){var s,r,q,p=this
A.i(p).c.a(a)
s=p.d
if(s==null)s=p.d=A.fb()
r=p.az(a)
q=s[r]
if(q==null)s[r]=[p.ae(a)]
else{if(p.aB(q,a)>=0)return!1
q.push(p.ae(a))}return!0},
aw(a,b){A.i(this).c.a(b)
if(t.M.a(a[b])!=null)return!1
a[b]=this.ae(b)
return!0},
ae(a){var s=this,r=new A.cD(A.i(s).c.a(a))
if(s.e==null)s.e=s.f=r
else s.f=s.f.b=r;++s.a
s.r=s.r+1&1073741823
return r},
az(a){return J.ba(a)&1073741823},
aB(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.fl(a[r].a,b))return r
return-1},
$ifE:1}
A.cD.prototype={}
A.aO.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
n(){var s=this,r=s.c,q=s.a
if(s.b!==q.r)throw A.d(A.N(q))
else if(r==null){s.d=null
return!1}else{s.d=s.$ti.h("1?").a(r.a)
s.c=r.b
return!0}},
$iw:1}
A.ee.prototype={
$2(a,b){this.a.u(0,this.b.a(a),this.c.a(b))},
$S:16}
A.I.prototype={
H(a,b){var s,r,q,p=A.i(this)
p.h("~(I.K,I.V)").a(b)
for(s=this.gR(),s=s.gq(s),p=p.h("I.V");s.n();){r=s.gp()
q=this.i(0,r)
b.$2(r,q==null?p.a(q):q)}},
a2(a,b,c,d){var s,r,q,p,o,n=A.i(this)
n.t(c).t(d).h("D<1,2>(I.K,I.V)").a(b)
s=A.aJ(c,d)
for(r=this.gR(),r=r.gq(r),n=n.h("I.V");r.n();){q=r.gp()
p=this.i(0,q)
o=b.$2(q,p==null?n.a(p):p)
s.u(0,o.a,o.b)}return s},
gl(a){var s=this.gR()
return s.gl(s)},
gv(a){var s=this.gR()
return s.gv(s)},
k(a){return A.ei(this)},
$ir:1}
A.ej.prototype={
$2(a,b){var s,r=this.a
if(!r.a)this.b.a+=", "
r.a=!1
r=this.b
s=A.x(a)
r.a=(r.a+=s)+": "
s=A.x(b)
r.a+=s},
$S:13}
A.bR.prototype={}
A.b1.prototype={
i(a,b){return this.a.i(0,b)},
H(a,b){this.a.H(0,this.$ti.h("~(1,2)").a(b))},
gv(a){return this.a.a===0},
gl(a){return this.a.a},
k(a){return A.ei(this.a)},
a2(a,b,c,d){return this.a.a2(0,this.$ti.t(c).t(d).h("D<1,2>(3,4)").a(b),c,d)},
$ir:1}
A.bI.prototype={}
A.ef.prototype={
gq(a){var s=this
return new A.bM(s,s.c,s.d,s.b,s.$ti.h("bM<1>"))},
gv(a){return this.b===this.c},
gl(a){return(this.c-this.b&this.a.length-1)>>>0},
C(a,b){var s,r,q=this,p=q.gl(0)
if(0>b||b>=p)A.aD(A.e5(b,p,q,null,"index"))
p=q.a
s=p.length
r=(q.b+b&s-1)>>>0
if(!(r>=0&&r<s))return A.b(p,r)
r=p[r]
return r==null?q.$ti.c.a(r):r},
k(a){return A.f6(this,"{","}")}}
A.bM.prototype={
gp(){var s=this.e
return s==null?this.$ti.c.a(s):s},
n(){var s,r,q=this,p=q.a
if(q.c!==p.d)A.aD(A.N(p))
s=q.d
if(s===q.b){q.e=null
return!1}p=p.a
r=p.length
if(!(s<r))return A.b(p,s)
q.e=p[s]
q.d=(s+1&r-1)>>>0
return!0},
$iw:1}
A.aN.prototype={
gv(a){return this.gl(this)===0},
gX(a){return this.gl(this)!==0},
L(a,b){var s,r,q
A.i(this).h("c<1>").a(b)
for(s=b.gq(b),r=s.$ti.c;s.n();){q=s.d
this.m(0,q==null?r.a(q):q)}},
k(a){return A.f6(this,"{","}")},
K(a,b){return A.fS(this,b,A.i(this).c)},
$ip:1,
$ic:1,
$iaM:1}
A.bN.prototype={}
A.cE.prototype={
m(a,b){this.$ti.c.a(b)
return A.ix()}}
A.bJ.prototype={
aa(a,b){return this.a.aa(0,b)},
gl(a){return this.a.a},
gq(a){var s=this.a
return A.id(s,s.r,A.i(s).c)}}
A.b7.prototype={}
A.bS.prototype={}
A.cB.prototype={
i(a,b){var s,r=this.b
if(r==null)return this.c.i(0,b)
else if(typeof b!="string")return null
else{s=r[b]
return typeof s=="undefined"?this.bl(b):s}},
gl(a){return this.b==null?this.c.a:this.a6().length},
gv(a){return this.gl(0)===0},
gR(){if(this.b==null){var s=this.c
return new A.aj(s,A.i(s).h("aj<1>"))}return new A.cC(this)},
H(a,b){var s,r,q,p,o=this
t.cA.a(b)
if(o.b==null)return o.c.H(0,b)
s=o.a6()
for(r=0;r<s.length;++r){q=s[r]
p=o.b[q]
if(typeof p=="undefined"){p=A.eQ(o.a[q])
o.b[q]=p}b.$2(q,p)
if(s!==o.c)throw A.d(A.N(o))}},
a6(){var s=t.bF.a(this.c)
if(s==null)s=this.c=A.o(Object.keys(this.a),t.s)
return s},
bl(a){var s
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
s=A.eQ(this.a[a])
return this.b[a]=s}}
A.cC.prototype={
gl(a){return this.a.gl(0)},
C(a,b){var s=this.a
if(s.b==null)s=s.gR().C(0,b)
else{s=s.a6()
if(!(b>=0&&b<s.length))return A.b(s,b)
s=s[b]}return s},
gq(a){var s=this.a
if(s.b==null){s=s.gR()
s=s.gq(s)}else{s=s.a6()
s=new J.aF(s,s.length,A.h(s).h("aF<1>"))}return s}}
A.c0.prototype={}
A.c4.prototype={}
A.bp.prototype={
k(a){var s=A.cc(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+s}}
A.cn.prototype={
k(a){return"Cyclic error in JSON stringify"}}
A.ea.prototype={
bO(a,b){var s=A.j2(a,this.gbP().a)
return s},
bQ(a,b){var s=A.ic(a,this.gbR().b,null)
return s},
gbR(){return B.aw},
gbP(){return B.av}}
A.ec.prototype={}
A.eb.prototype={}
A.eG.prototype={
aU(a){var s,r,q,p,o,n,m=a.length
for(s=this.c,r=0,q=0;q<m;++q){p=a.charCodeAt(q)
if(p>92){if(p>=55296){o=p&64512
if(o===55296){n=q+1
n=!(n<m&&(a.charCodeAt(n)&64512)===56320)}else n=!1
if(!n)if(o===56320){o=q-1
o=!(o>=0&&(a.charCodeAt(o)&64512)===55296)}else o=!1
else o=!0
if(o){if(q>r)s.a+=B.d.Y(a,r,q)
r=q+1
o=A.G(92)
s.a+=o
o=A.G(117)
s.a+=o
o=A.G(100)
s.a+=o
o=p>>>8&15
o=A.G(o<10?48+o:87+o)
s.a+=o
o=p>>>4&15
o=A.G(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.G(o<10?48+o:87+o)
s.a+=o}}continue}if(p<32){if(q>r)s.a+=B.d.Y(a,r,q)
r=q+1
o=A.G(92)
s.a+=o
switch(p){case 8:o=A.G(98)
s.a+=o
break
case 9:o=A.G(116)
s.a+=o
break
case 10:o=A.G(110)
s.a+=o
break
case 12:o=A.G(102)
s.a+=o
break
case 13:o=A.G(114)
s.a+=o
break
default:o=A.G(117)
s.a+=o
o=A.G(48)
s.a=(s.a+=o)+o
o=p>>>4&15
o=A.G(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.G(o<10?48+o:87+o)
s.a+=o
break}}else if(p===34||p===92){if(q>r)s.a+=B.d.Y(a,r,q)
r=q+1
o=A.G(92)
s.a+=o
o=A.G(p)
s.a+=o}}if(r===0)s.a+=a
else if(r<m)s.a+=B.d.Y(a,r,m)},
ad(a){var s,r,q,p
for(s=this.a,r=s.length,q=0;q<r;++q){p=s[q]
if(a==null?p==null:a===p)throw A.d(new A.cn(a,null))}B.a.m(s,a)},
ac(a){var s,r,q,p,o=this
if(o.aT(a))return
o.ad(a)
try{s=o.b.$1(a)
if(!o.aT(s)){q=A.fB(a,null,o.gaH())
throw A.d(q)}q=o.a
if(0>=q.length)return A.b(q,-1)
q.pop()}catch(p){r=A.fj(p)
q=A.fB(a,r,o.gaH())
throw A.d(q)}},
aT(a){var s,r,q=this
if(typeof a=="number"){if(!isFinite(a))return!1
q.c.a+=B.b.k(a)
return!0}else if(a===!0){q.c.a+="true"
return!0}else if(a===!1){q.c.a+="false"
return!0}else if(a==null){q.c.a+="null"
return!0}else if(typeof a=="string"){s=q.c
s.a+='"'
q.aU(a)
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
s=J.bT(a)
if(s.gX(a)){this.ac(s.i(a,0))
for(r=1;r<s.gl(a);++r){q.a+=","
this.ac(s.i(a,r))}}q.a+="]"},
c7(a){var s,r,q,p,o,n,m=this,l={}
if(a.gv(a)){m.c.a+="{}"
return!0}s=a.gl(a)*2
r=A.bv(s,null,!1,t.U)
q=l.a=0
l.b=!0
a.H(0,new A.eH(l,r))
if(!l.b)return!1
p=m.c
p.a+="{"
for(o='"';q<s;q+=2,o=',"'){p.a+=o
m.aU(A.H(r[q]))
p.a+='":'
n=q+1
if(!(n<s))return A.b(r,n)
m.ac(r[n])}p.a+="}"
return!0}}
A.eH.prototype={
$2(a,b){var s,r
if(typeof a!="string")this.a.b=!1
s=this.b
r=this.a
B.a.u(s,r.a++,a)
B.a.u(s,r.a++,b)},
$S:13}
A.eF.prototype={
gaH(){var s=this.c.a
return s.charCodeAt(0)==0?s:s}}
A.ds.prototype={
$0(){var s=this
return A.aD(A.f5("("+s.a+", "+s.b+", "+s.c+", "+s.d+", "+s.e+", "+s.f+", "+s.r+", "+s.w+")"))},
$S:19}
A.a4.prototype={
O(a){var s=1000,r=B.c.T(a,s),q=B.c.A(a-r,s),p=this.b+r,o=B.c.T(p,s),n=this.c
return new A.a4(A.fx(this.a+B.c.A(p-o,s)+q,o,n),o,n)},
W(a){return A.C(this.b-a.b,this.a-a.a)},
M(a,b){if(b==null)return!1
return b instanceof A.a4&&this.a===b.a&&this.b===b.b&&this.c===b.c},
gB(a){return A.fH(this.a,this.b)},
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
k(a){var s=this,r=A.fw(A.cq(s)),q=A.ae(A.fN(s)),p=A.ae(A.fJ(s)),o=A.ae(A.fK(s)),n=A.ae(A.fM(s)),m=A.ae(A.fO(s)),l=A.dt(A.fL(s)),k=s.b,j=k===0?"":A.dt(k)
k=r+"-"+q
if(s.c)return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j},
c3(){var s=this,r=A.cq(s)>=-9999&&A.cq(s)<=9999?A.fw(A.cq(s)):A.hT(A.cq(s)),q=A.ae(A.fN(s)),p=A.ae(A.fJ(s)),o=A.ae(A.fK(s)),n=A.ae(A.fM(s)),m=A.ae(A.fO(s)),l=A.dt(A.fL(s)),k=s.b,j=k===0?"":A.dt(k)
k=r+"-"+q
if(s.c)return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j},
$iP:1}
A.du.prototype={
$1(a){if(a==null)return 0
return A.cF(a)},
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
return s+m+":"+q+r+":"+o+p+"."+B.d.c1(B.c.k(n%1e6),6,"0")},
$iP:1}
A.eC.prototype={
k(a){return this.D()}}
A.t.prototype={}
A.bX.prototype={
k(a){var s=this.a
if(s!=null)return"Assertion failed: "+A.cc(s)
return"Assertion failed"}}
A.bH.prototype={}
A.ac.prototype={
gah(){return"Invalid argument"+(!this.a?"(s)":"")},
gag(){return""},
k(a){var s=this,r=s.c,q=r==null?"":" ("+r+")",p=s.d,o=p==null?"":": "+p,n=s.gah()+q+o
if(!s.a)return n
return n+s.gag()+": "+A.cc(s.gap())},
gap(){return this.b}}
A.bA.prototype={
gap(){return A.h7(this.b)},
gah(){return"RangeError"},
gag(){var s,r=this.e,q=this.f
if(r==null)s=q!=null?": Not less than or equal to "+A.x(q):""
else if(q==null)s=": Not greater than or equal to "+A.x(r)
else if(q>r)s=": Not in inclusive range "+A.x(r)+".."+A.x(q)
else s=q<r?": Valid value range is empty":": Only valid value is "+A.x(r)
return s}}
A.ce.prototype={
gap(){return A.aa(this.b)},
gah(){return"RangeError"},
gag(){if(A.aa(this.b)<0)return": index must not be negative"
var s=this.f
if(s===0)return": no indices are valid"
return": index should be less than "+s},
gl(a){return this.f}}
A.bK.prototype={
k(a){return"Unsupported operation: "+this.a}}
A.b2.prototype={
k(a){return"Bad state: "+this.a}}
A.c3.prototype={
k(a){var s=this.a
if(s==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.cc(s)+"."}}
A.cp.prototype={
k(a){return"Out of Memory"},
$it:1}
A.bD.prototype={
k(a){return"Stack Overflow"},
$it:1}
A.eD.prototype={
k(a){return"Exception: "+this.a}}
A.e4.prototype={
k(a){var s=this.a,r=""!==s?"FormatException: "+s:"FormatException",q=this.b
if(typeof q=="string"){if(q.length>78)q=B.d.Y(q,0,75)+"..."
return r+"\n"+q}else return r}}
A.c.prototype={
aQ(a,b,c){var s=A.i(this)
return A.i2(this,s.t(c).h("1(c.E)").a(b),s.h("c.E"),c)},
F(a,b,c,d){var s,r
d.a(b)
A.i(this).t(d).h("1(1,c.E)").a(c)
for(s=this.gq(this),r=b;s.n();)r=c.$2(r,s.gp())
return r},
aR(a,b){var s=A.i(this).h("c.E")
if(b)s=A.y(this,s)
else{s=A.y(this,s)
s.$flags=1
s=s}return s},
gl(a){var s,r=this.gq(this)
for(s=0;r.n();)++s
return s},
gv(a){return!this.gq(this).n()},
gX(a){return!this.gv(this)},
K(a,b){return A.fS(this,b,A.i(this).h("c.E"))},
bV(a,b,c){var s,r=A.i(this)
r.h("l(c.E)").a(b)
r.h("c.E()?").a(c)
for(r=this.gq(this);r.n();){s=r.gp()
if(b.$1(s))return s}r=c.$0()
return r},
C(a,b){var s,r
A.an(b,"index")
s=this.gq(this)
for(r=b;s.n();){if(r===0)return s.gp();--r}throw A.d(A.e5(b,b-r,this,null,"index"))},
k(a){return A.hW(this,"(",")")}}
A.D.prototype={
k(a){return"MapEntry("+A.x(this.a)+": "+A.x(this.b)+")"}}
A.aL.prototype={
gB(a){return A.j.prototype.gB.call(this,0)},
k(a){return"null"}}
A.j.prototype={$ij:1,
M(a,b){return this===b},
gB(a){return A.cr(this)},
k(a){return"Instance of '"+A.cs(this)+"'"},
gS(a){return A.jl(this)},
toString(){return this.k(this)}}
A.b3.prototype={
gl(a){return this.a.length},
k(a){var s=this.a
return s.charCodeAt(0)==0?s:s},
$ii9:1}
A.cI.prototype={
G(a){var s,r,q,p,o,n,m=A.o([],t.g)
for(s=a.P(B.i),r=J.a2(s.a),s=new A.a0(r,s.b,s.$ti.h("a0<1>")),q=0;s.n();){p=r.gp()
o=p.at
n=Math.max(o.c,o.d)
o=!0
if(p.ax===B.r)if(!(p.x-p.w<4))o=n>=0.65&&p.y<12
if(o)++q
else B.a.m(m,p)}if(m.length===0)return new A.bW(0,!1,!1)
s=new A.cQ(m)
return new A.bW(s.$1(new A.cS(this))*25+s.$1(new A.cT(this,a))*15+s.$1(new A.cU(this,a))*10,!0,m.length>=2)},
aY(a,b){var s=B.a.a4(a.b,b.d,b.e+1),r=A.h(s),q=r.h("f<1,a>"),p=A.y(new A.f(s,r.h("a(1)").a(new A.cJ()),q),q.h("q.E"))
return B.a.F(p,0,new A.cK(B.a.J(p,new A.cL())/p.length),t.i)/p.length},
bt(a,b){var s=a.b,r=A.h(s),q=r.h("am<1,a>"),p=A.y(new A.am(new A.z(s,r.h("l(1)").a(new A.cM(b,b.r.O(4e6))),r.h("z<1>")),r.h("a(1)").a(new A.cN()),q),q.h("c.E"))
if(p.length<2)return 0
return 1-B.b.j(Math.sqrt(B.a.F(p,0,new A.cO(B.a.J(p,new A.cP())/p.length),t.i)/p.length)/3,0,1)}}
A.cQ.prototype={
$1(a){var s=this.a,r=A.h(s)
return new A.f(s,r.h("a(1)").a(t.bE.a(a)),r.h("f<1,a>")).J(0,new A.cR())/s.length},
$S:14}
A.cR.prototype={
$2(a,b){return A.m(a)+A.m(b)},
$S:0}
A.cS.prototype={
$1(a){t.F.a(a)
return B.b.j((a.x-a.w)/B.c.A(a.r.W(a.f).a,1000)*1000/2.5,0,1)},
$S:7}
A.cT.prototype={
$1(a){return 1-B.b.j(this.a.aY(this.b,t.F.a(a))/0.55,0,1)},
$S:7}
A.cU.prototype={
$1(a){return this.a.bt(this.b,t.F.a(a))},
$S:7}
A.cJ.prototype={
$1(a){return t.K.a(a).e},
$S:3}
A.cL.prototype={
$2(a,b){return A.m(a)+A.m(b)},
$S:0}
A.cK.prototype={
$2(a,b){var s
A.m(a)
s=A.m(b)-this.a
return a+s*s},
$S:0}
A.cM.prototype={
$1(a){t.K.a(a)
return a.a>this.a.e&&!a.b.c.bZ(this.b)},
$S:1}
A.cN.prototype={
$1(a){return t.K.a(a).b.d},
$S:3}
A.cP.prototype={
$2(a,b){return A.m(a)+A.m(b)},
$S:0}
A.cO.prototype={
$2(a,b){var s
A.m(a)
s=A.m(b)-this.a
return a+s*s},
$S:0}
A.cX.prototype={
G(b4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0=this,b1=b4.P(B.m),b2=b1.$ti,b3=b2.h("z<c.E>")
b1=A.y(new A.z(b1,b2.h("l(c.E)").a(new A.da()),b3),b3.h("c.E"))
b1.$flags=1
s=b1
b1=b4.P(B.E)
b1=A.y(b1,b1.$ti.h("c.E"))
b1.$flags=1
r=b1
b1=b4.P(B.f)
b1=A.y(b1,b1.$ti.h("c.E"))
b1.$flags=1
q=b1
p=A.o([],t.aS)
b1=t.n
o=A.o([],b1)
n=A.fG(t.N)
for(b2=s.length,m=0,l=0,k=0,j=0;j<s.length;s.length===b2||(0,A.au)(s),++j){i=s[j]
if(!(i.as<=0)){b3=i.r
h=i.f
h=A.C(b3.b-h.b,b3.a-h.a).a<=0
b3=h}else b3=!0
if(b3){++m
continue}g=b0.bb(i,q)
b3=i.at
f=B.b.j(1-Math.max(b3.c*0.25,b3.d*0.45),0,1)
if(f<1||g)++k
e=b0.aI(b4,i)
d=b0.bu(e)
if(e>=5){++l
n.m(0,i.a)}b3=g?0.6:1
B.a.m(o,d*f*b3)
B.a.m(p,new A.aB(b0.b0(b4,i,g),Math.max(1,i.w-i.x)))}c=p.length===0
b=c?150:150*b0.bH(p)
a=o.length===0
a0=a?100:100*(1-b0.b_(o))
a1=b0.ba(b4,s)
a2=a1.length===0
a3=b0.bg(a1)
a4=a2?60:60*(1-a3)
b2=A.h(a1)
new A.z(a1,b2.h("l(1)").a(new A.db()),b2.h("z<1>")).gl(0)
a5=A.o([],b1)
for(b1=r.length,j=0;j<r.length;r.length===b1||(0,A.au)(r),++j){a6=b0.bz(b4,r[j],s,n)
if(a6==null)++m
else B.a.m(a5,a6)}a7=a5.length===0
a8=a7?40:40*b0.U(a5)
a9=B.b.j(b+a0+a4+a8,0,350)
B.b.j(b,0,150)
B.b.j(a0,0,100)
B.b.j(a4,0,60)
B.b.j(a8,0,40)
return new A.dc(a9,s.length,a5.length,new A.cW(c,a,a2,a7))},
b0(a,a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=a.b,d=a0.d,c=a0.e,b=e.length
if(!(d<b))return A.b(e,d)
s=e[d].b.d
if(!(c<b))return A.b(e,c)
r=e[c].b.d
q=Math.max(0,s-r)
if(q<=0)return 0.5
p=this.aE(e,d,c,0.5)
o=this.aE(e,d,c,0.6)
if(!(p<b))return A.b(e,p)
n=Math.max(0,s-e[p].b.d)
if(!(o<b))return A.b(e,o)
m=Math.max(0,e[o].b.d-r)
l=B.b.j(n/q/0.55,0,1)
k=B.b.j((m/q-0.35)/0.37,0,1)
j=A.o([],t.n)
for(i=d;i<=c;++i){if(!(i<b))return A.b(e,i)
B.a.m(j,e[i].e)}b=B.b.j(this.aK(j)/0.9,0,1)
h=e[d].b.c.O(-5e6)
g=A.en(e,0,A.hh(d,"count",t.S),A.h(e).c).a0(0,new A.cY(h))?0.08:0
f=a1?0.1:0
return B.b.j(0.4*B.b.j(l+g+f,0,1)+0.3*(1-b)+0.3*(1-k),0,1)},
aI(a,b){var s,r,q,p,o,n
for(s=b.d,r=b.e,q=a.b,p=q.length,o=0;s<=r;++s){if(!(s<p))return A.b(q,s)
n=q[s]
o=Math.max(o,Math.max(-n.b.x,-n.e))}return o},
bu(a){var s=this
if(a<=1.5)return 0
if(a<=2.5)return s.a5(0,0.15,(a-1.5)/1)
if(a<=3.5)return s.a5(0.15,0.35,(a-2.5)/1)
if(a<=5)return s.a5(0.35,0.75,(a-3.5)/1.5)
return s.a5(0.75,1,(a-5)/5)},
b_(a){var s
t.o.a(a)
s=this.U(a)
if(a.length===1)return Math.min(s,0.35)
return B.b.j(s*1.35,0,1)},
ba(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c
t.B.a(b)
s=a.P(B.i)
r=s.$ti
q=r.h("z<c.E>")
s=A.y(new A.z(s,r.h("l(c.E)").a(new A.cZ()),q),q.h("c.E"))
s.$flags=1
p=s
o=A.o([],t.h9)
for(s=p.length,n=0;n<p.length;p.length===s||(0,A.au)(p),++n){m=p[n]
l=m.x-m.w
if(l<3)continue
for(r=b.length,q=m.r,k=q.a,q=q.b,j=m.y,i=0;i<r;++i){h=b[i]
g=h.f
f=g.a
if(f>=k)e=f===k&&g.b<q
else e=!0
if(e)continue
d=A.C(g.b-q,f-k)
if(j<13.88888888888889)c=14
else c=j<25?10.5:7.5
if(d.a>A.C(0,B.b.a3(c*1000)).a)break
if(h.w-h.x<=0)continue
B.a.m(o,new A.a9(l,this.aI(a,h),this.bh(h.at)))
break}}return o},
bg(a){var s,r,q,p,o
t.cT.a(a)
if(a.length===0)return 0
s=A.h(a)
r=s.h("a(1)")
s=s.h("f<1,a>")
q=this.U(new A.f(a,r.a(new A.d1(this)),s))
p=a.length
o=p===1?0.15:B.b.j(p/3,0.45,1)
return B.b.j(q*o*(1-this.U(new A.f(a,r.a(new A.d2()),s))),0,1)},
bz(a,b,a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=null
t.B.a(a0)
t.cq.a(a1)
s=this.b9(a,b.d)
if(s==null)return c
r=a.b
q=b.e
p=B.a.a4(r,s,q+1)
o=A.h(p)
if(new A.f(p,o.h("a(1)").a(new A.d4()),o.h("f<1,a>")).J(0,B.Q)<4.166666666666667)return c
p=A.h(a0)
o=p.h("z<1>")
n=A.ft(new A.z(a0,p.h("l(1)").a(new A.d5(b)),o),o.h("c.E"),t.J).bV(0,new A.d6(),new A.d7())
if(n!=null&&a1.aa(0,n.a))return c
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
B.a.m(e,r[i].e)}d=1-B.b.j(this.aK(e)/0.8,0,1)
return B.b.j(0.5*f+0.25*d+0.25*B.b.j((f+d)/2,0,1),0,1)},
b9(a,b){var s,r,q
for(s=a.b,r=s.length,q=b;q>=0;--q){if(!(q<r))return A.b(s,q)
if(s[q].b.d>=4.166666666666667)return q}return null},
bb(a,b){t.B.a(b)
return a.ch.aa(0,B.q)||B.a.a0(a.CW,new A.d0(b))},
bh(a){var s=a.d,r=Math.max(a.c,s)
if(r<=0)return 0
return B.b.j(0.8*r+0.19999999999999996*s,0,1)},
aE(a,b,c,d){var s,r,q,p,o,n,m
t.X.a(a)
s=a.length
if(!(b<s))return A.b(a,b)
r=a[b].b.c
if(!(c<s))return A.b(a,c)
q=r.O(A.C(0,B.b.a3(B.c.A(a[c].b.c.W(r).a,1000)*d)).a)
for(r=q.a,p=q.b,o=b;o<=c;++o){if(!(o<s))return A.b(a,o)
n=a[o].b.c
m=n.a
if(m>=r)n=m===r&&n.b<p
else n=!0
if(!n)return o}return c},
bH(a){var s,r
t.ap.a(a)
s=t.i
r=B.a.F(a,0,new A.d8(),s)
if(r<=0)return 1
return B.a.F(a,0,new A.d9(),s)/r},
U(a){var s,r,q
for(s=J.a2(t.bM.a(a)),r=0,q=0;s.n();){r+=s.gp();++q}return q===0?0:r/q},
aK(a){var s
t.o.a(a)
if(a.length<2)return 0
s=A.h(a)
return Math.sqrt(this.U(new A.f(a,s.h("a(1)").a(new A.d3(this.U(a))),s.h("f<1,a>"))))},
a5(a,b,c){return a+(b-a)*B.b.j(c,0,1)}}
A.da.prototype={
$1(a){return t.F.a(a).ax===B.I},
$S:4}
A.db.prototype={
$1(a){return t.k.a(a).c>0},
$S:15}
A.cY.prototype={
$1(a){t.K.a(a)
return!a.b.c.c_(this.a)&&a.e<-0.08},
$S:1}
A.cZ.prototype={
$1(a){return t.F.a(a).ax===B.r},
$S:4}
A.d1.prototype={
$1(a){t.k.a(a)
return 0.6*B.b.j(a.a/9,0,1)+0.4*B.b.j(a.b/3.5,0,1)},
$S:10}
A.d2.prototype={
$1(a){return t.k.a(a).c},
$S:10}
A.d4.prototype={
$1(a){return t.K.a(a).b.d},
$S:3}
A.d5.prototype={
$1(a){var s,r
t.F.a(a)
s=this.a
r=s.f.W(a.r)
return a.e<=s.d&&Math.abs(r.a)<=3e6},
$S:4}
A.d6.prototype={
$1(a){return t.J.a(a)!=null},
$S:21}
A.d7.prototype={
$0(){return null},
$S:22}
A.d0.prototype={
$1(a){return B.a.a0(this.a,new A.d_(A.H(a)))},
$S:36}
A.d_.prototype={
$1(a){return t.F.a(a).a===this.a},
$S:4}
A.d8.prototype={
$2(a,b){return A.m(a)+t.E.a(b).b},
$S:11}
A.d9.prototype={
$2(a,b){A.m(a)
t.E.a(b)
return a+b.a*b.b},
$S:11}
A.d3.prototype={
$1(a){return Math.pow(A.m(a)-this.a,2)},
$S:24}
A.aB.prototype={}
A.a9.prototype={}
A.dc.prototype={}
A.cW.prototype={}
A.F.prototype={
gbW(){var s,r=this.a
if(isFinite(r)){s=this.b
r=isFinite(s)&&Math.abs(r)<=90&&Math.abs(s)<=180}else r=!1
return r}}
A.c1.prototype={
aL(a,b,c,d,a0,a1,a2,a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=t.t
e.a(a0)
e.a(a7)
if(a3&&!a1.at)return f.a9(a,a1,B.a5,"Common road is below the 3000 metre comparison threshold.")
s=B.u.aM(b,c,d,a0,a1,a2,a4,a5,a6,a7)
if(!s.gaP()){e=s.a.a===B.e||s.b.a===B.e?B.a6:B.A
i=s.a.f
if(i==null)i=s.b.f
return f.a9(a,a1,e,i==null?"Common-road telemetry could not be extracted.":i)}try{e=f.b
r=e.ao(a,s.a.b)
q=e.ao(a,s.b.b)
p=q.a-r.a
o=r.a<q.a?r.a:q.a
e=o
if(typeof e!=="number")return e.cc()
if(e<=0)h=0
else{e=p
i=o
if(typeof e!=="number")return e.c9()
if(typeof i!=="number")return A.jn(i)
h=e/i}n=h
m=r.a>=q.a*1.01
l=q.a>=r.a*1.01
if(m)e=B.x
else e=l?B.y:B.z
return new A.c2(r,q,p,n,e,!0)}catch(g){e=A.fj(g)
if(e instanceof A.cg){k=e
return f.a9(a,a1,B.A,u.c)}else{j=e
e=f.a9(a,a1,B.a7,J.aT(j))
return e}}},
bM(a,b,c,d,e,f){var s=null
return this.aL(a,s,b,s,c,d,0,!0,s,e,s,f)},
a9(a,b,c,d){var s=null
return new A.c2(s,s,s,s,c,!1)}}
A.dd.prototype={}
A.ad.prototype={
D(){return"CommonRoadScoreComparisonOutcome."+this.b}}
A.c2.prototype={}
A.bc.prototype={
D(){return"CommonRoadTelemetryMappingStatus."+this.b}}
A.av.prototype={}
A.dh.prototype={
gaP(){return this.a.a===B.l&&this.b.a===B.l}}
A.de.prototype={
aM(a,b,c,d,e,f,g,h,i,j){var s,r,q=t.t
q.a(d)
q.a(j)
q=c==null?e.e:c
s=a==null?e.f:a
q=this.aA(s,f,b,e.c,q,d)
s=i==null?e.r:i
r=g==null?e.w:g
return new A.dh(q,this.aA(r,f,h,e.d,s,j))},
bT(a,b,c,d,e){var s=null
return this.aM(s,a,s,b,c,0,s,d,s,e)},
aA(a,b,c,d,a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=null
t.t.a(a1)
s=J.e7(a1.slice(0),A.h(a1).c)
if(s.length===0)return new A.av(B.B,B.h,e,e,0,"No canonical telemetry exists.")
r=this.br(c,d)
if(r==null||r.b.length<2)return new A.av(B.e,B.h,e,e,0,"Matched road section is unavailable.")
q=this.bs(c,d)
if(q==null)return new A.av(B.e,B.h,e,e,0,"Matched road section offset is unavailable.")
p=A.o([],t.du)
for(o=r.b,n=a0-b,m=a+b,l=0;l<s.length;++l){k=s[l]
j=k.a
if(isFinite(j)){i=k.b
j=isFinite(i)&&Math.abs(j)<=90&&Math.abs(i)<=180}else j=!1
if(!j)continue
h=this.bm(k,o,q,a0,a,b)
j=!0
if(h!=null)if(!(h.a>35)){i=h.c
if(!(i!=null&&i>60)){j=h.b
j=j<n||j>m}}if(j)continue
B.a.m(p,new A.a1(l,k,h))}if(p.length<2)return new A.av(B.B,B.h,e,e,0,"Fewer than two canonical samples map to the common road.")
o=t.gM
o=A.y(new A.f(p,t.fI.a(new A.df()),o),o.h("q.E"))
o.$flags=1
g=o
for(o=g.length,l=1;l<o;++l){n=g[l].c
m=g[l-1].c
j=n.a
i=m.a
if(j<=i)n=j===i&&n.b>m.b
else n=!0
if(!n)return new A.av(B.e,B.h,e,e,0,"Mapped telemetry does not preserve strict time order.")}f=B.b.j(1-B.a.F(p,0,new A.dg(),t.i)/p.length/35,0,1)
return new A.av(B.l,A.a7(g,t.u),B.a.gN(p).a,B.a.ga1(p).a,f,e)},
br(a,b){var s,r,q=a.d,p=q.length
if(p!==0){for(s=0;s<p;++s){r=q[s]
if(r.a===b)return r}return null}return b===a.a+":geometry"?new A.Z(b,a.c,a.e):null},
bs(a,b){var s,r,q,p=a.d,o=p.length
if(o===0)return b===a.a+":geometry"?0:null
for(s=0,r=0;r<o;++r){q=p[r]
if(q.a===b)return s
s+=q.c}return null},
bm(b1,b2,b3,b4,b5,b6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0
t.f8.a(b2)
for(s=b4-b6,r=b1.e,q=b1.b,p=b1.a,o=b5+b6,n=null,m=!1,l=0,k=0;k<b2.length-1;){j=b2[k];++k
i=b2[k]
h=j.a
g=j.b
f=i.a
e=h*3.141592653589793/180
d=f*3.141592653589793/180
f-=h
c=i.b-g
b=c*3.141592653589793/180
a=Math.sin(f*3.141592653589793/180/2)
a0=Math.sin(b/2)
a1=12742017.6*Math.asin(Math.sqrt(B.b.j(a*a+Math.cos(e)*Math.cos(d)*a0*a0,0,1)))
if(a1<=0)continue
a2=111320*Math.cos(e)
a3=(q-g)*a2
a4=(p-h)*111320
a5=c*a2
a6=f*111320
a7=a5*a5+a6*a6
a8=a7<=0?0:B.b.j((a3*a5+a4*a6)/a7,0,1)
h=a3-a5*a8
g=a4-a6*a8
g=Math.sqrt(h*h+g*g)
h=b3+l+a1*a8
d=A.iM(r,B.b.T(Math.atan2(Math.sin(b)*Math.cos(d),Math.cos(e)*Math.sin(d)-Math.sin(e)*Math.cos(d)*Math.cos(b))*180/3.141592653589793+360,360))
a9=new A.eE(g,h,d)
b0=h>=s&&h<=o
h=!0
if(n!=null)if(!(b0&&!m))if(b0===m){f=n.a
if(!(g<f))if(Math.abs(g-f)<=0.000001){h=d==null?1/0:d
g=n.c
h=h<(g==null?1/0:g)}else h=!1}else h=!1
if(h){m=b0
n=a9}l+=a1}return n}}
A.df.prototype={
$1(a){return t.A.a(a).b},
$S:17}
A.dg.prototype={
$2(a,b){return A.m(a)+t.A.a(b).c.a},
$S:18}
A.a1.prototype={}
A.eE.prototype={}
A.c6.prototype={
G(a){var s,r,q,p,o,n,m=A.o([],t.df)
for(s=a.P(B.f),r=J.a2(s.a),s=new A.a0(r,s.b,s.$ti.h("a0<1>")),q=0,p=0;s.n();){o=r.gp()
n=this.b4(a,o)
if(n==null){++q
if(o.as<0.5)++p}else B.a.m(m,n)}if(m.length===0)return new A.c5(0,!1,!1)
s=new A.dp(this,m)
s=B.b.j(s.$1(new A.dk())*60+s.$1(new A.dl())*35+s.$1(new A.dm())*35+s.$1(new A.dn())*20,0,150)
r=m.length
A.a7(m,t.h)
return new A.c5(s,!0,r>=2)},
b4(a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=null
if(a1.ax!==B.J||a1.as<0.5||a1.Q<15)return a
s=a1.cx
r=s.i(0,"totalHeadingChangeDegrees")
if(r==null)r=0
if(r<15)return a
q=a0.b
s=s.i(0,"apexIndex")
p=a1.d
o=a1.e
n=B.c.c2(B.c.j(B.b.a3(s==null?(a1.d+a1.e)/2:s),p,o))
m=Math.max(p,p+B.c.A(n-p,2))
l=Math.min(o,n+B.c.A(o-n,2))
k=b.ai(q,p,m)
j=b.ai(q,Math.max(p,n-1),Math.min(o,n+1))
i=b.ai(q,l,b.bo(q,o))
if(k<10)return a
s=a1.at
h=Math.max(s.c,s.d)
if(h>=0.6&&k<12)return a
g=r*3.141592653589793/180
f=g<=0?500:a1.Q/g
e=B.b.j(0.55*((r-15)/75)+0.45*((500-f)/475),0,1)
d=1-B.b.j((B.b.j((k-j)/k,0,1)-b.aF(0.08,0.48,e))/0.32,0,1)
if(h>0)d=b.aF(d,1,h*0.35)
s=B.b.j(b.aG(b.am(q,p,n),k)/0.18,0,1)
c=B.b.j(B.b.j(i/k,0,1.1)/0.95,0,1)
o=B.b.j(b.aG(b.am(q,p,o),k)/0.06,0,1)
A.a7(a1.CW,t.N)
return new A.a3(r,e,a1.as,d,1-s,c,1-o)},
bo(a,b){var s,r,q,p,o,n,m,l,k
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
B.a.aW(p)
s=p.length
r=s/2|0
if((s&1)===1){if(!(r<s))return A.b(p,r)
s=p[r]}else{q=r-1
if(!(q>=0&&q<s))return A.b(p,q)
q=p[q]
if(!(r<s))return A.b(p,r)
q=(q+p[r])/2
s=q}return s},
aG(a,b){var s,r,q,p,o,n
t.o.a(a)
if(a.length<2||b<=0)return 0
s=B.a.J(a,new A.dj())
r=a.length
q=s/r
for(p=0,o=0;o<r;++o){n=a[o]-q
p+=n*n}return Math.sqrt(p/r)/b},
bG(a){t.h.a(a)
return Math.min(1.5,Math.max(0.25,a.w*(0.5+a.r)*(a.e/30)))},
aF(a,b,c){return a+(b-a)*B.b.j(c,0,1)}}
A.dp.prototype={
$1(a){var s,r,q,p,o,n,m,l,k
t.bk.a(a)
s=this.b
r=A.h(s)
q=r.h("f<1,a>")
r=A.y(new A.f(s,r.h("a(1)").a(this.a.gbF()),q),q.h("q.E"))
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
if(typeof q!=="number")return q.aq()
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
A.c5.prototype={}
A.a3.prototype={}
A.dw.prototype={
bS(b7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6=null
t.Y.a(b7)
if(b7.length===0)return B.L
s=t.I
r=A.bv(A.i1(b6),b6,!1,s)
q=A.o([],t.W)
for(p=0,o=0,n=0,m=0,l=0,k=0,j=0,i=0,h=0,g=0;j<b7.length;++j,f=h,h=i,i=f){e=b7[j]
B.a.u(r,h,j)
d=r.length
h=(h+1&d-1)>>>0
if(i===h){c=A.bv(d*2,b6,!1,s)
b=d-i
B.a.ar(c,0,b,r,i)
B.a.ar(c,b,b+i,r,0)
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
if(a5>1){if(h===i)A.aD(A.aX())
if(!(h>=0&&h<a3))return A.b(r,h)
a6=r[h]
a6=B.a.i(b7,a6==null?A.aa(a6):a6).c
a7=a6.a
if(a7>=a1)a6=a7===a1&&a6.b<a2
else a6=!0}else a6=!1
if(!a6)break
if(h===i)A.aD(A.aX());++g
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
b5=A.C(a.b-a1.b,a.a-a1.a).a/1e6
a=b5>0
if(a)if(d<=1.3888888888888888){l+=b5
k=0}else{k+=b5
l=0}if(a&&d>=4){b2=this.bv(b4.e,e.e)
b3=Math.abs(b2)/b5}}B.a.m(q,new A.S(j,e,b0,m,b2,b3))}return q},
bv(a,b){if(!isFinite(a)||!isFinite(b))return 0
return B.b.T(b-a+540,360)-180}}
A.c8.prototype={
bK(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this
t.t.a(b)
s=J.e7(b.slice(0),A.h(b).c)
r=B.U.bS(s)
if(r.length===0)return new A.c7(B.L,B.aJ,B.aK)
q=d.b7(r)
p=d.Z(r,new A.dz(),new A.dA(),B.ah,new A.dB(d,r))
o=d.Z(r,new A.dL(),new A.dM(),B.H,new A.dN(r))
n=d.Z(r,new A.dO(),new A.dP(),B.H,new A.dQ(r))
m=d.gbc()
l=d.Z(r,m,m,B.aj,new A.dR())
k=d.Z(r,new A.dS(),new A.dC(),B.ag,new A.dD(d,r))
j=A.bv(r.length,B.F,!1,t.fR)
d.a8(j,l,B.ab)
d.a8(j,o,B.aa)
d.a8(j,n,B.ac)
d.a8(j,p,B.G)
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
B.a.au(m,new A.dJ())
g=A.a7(r,t.K)
f=t.gE
e=A.a7(d.b2(j,r),f)
A.a7(new A.f(k,h.h("@(1)").a(new A.dK(r)),h.h("f<1,@>")),f)
A.a7(q,t.fo)
return new A.c7(g,e,A.a7(d.bq(m),i))},
bd(a){return a.b.d>=5&&Math.abs(a.e)<=0.3&&a.d<=1.5},
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
if(A.C(s.b-m.b,s.a-m.a).a<=1e6)continue
this.aC(r,a,q,p,d,e)
q=c.$1(n)?o:null
p=q}if(q!=null&&p!=null)this.aC(r,a,q,p,d,e)
return r},
aC(a,b,c,d,e,f){var s,r,q
t.e.a(a)
t.X.a(b)
A.aa(d)
t._.a(f)
s=new A.T(c,d)
r=b.length
if(!(d<r))return A.b(b,d)
q=b[d]
if(!(c<r))return A.b(b,c)
if(q.b.c.W(b[c].b.c).a>=e.a&&f.$1(s))B.a.m(a,s)},
b7(b4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3
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
if(A.C(o.b-m.b,o.a-m.a).a<8e6){B.a.m(s,B.aX)
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
if(b3>=0.62)B.a.m(s,new A.ap(B.b0,b2,b3))
else if(b2>=0.55)B.a.m(s,new A.ap(B.b_,b2,b3))
else{B.b.j(1-Math.max(b2,b3),0,1)
B.a.m(s,new A.ap(B.aZ,b2,b3))}}return s},
a_(a,b,a0,a1,a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=this
t.X.a(a1)
t.dr.a(a2)
for(s=a0.a,r=a0.b,q=a1.length,p=s,o=0,n=1/0;p<=r;++p){if(!(p<q))return A.b(a1,p)
m=a1[p].b.d
o=Math.max(o,m)
n=Math.min(n,m)}l=s+B.c.A(r-s,2)
if(!(l>=0&&l<a2.length))return A.b(a2,l)
k=a2[l]
j=A.fG(t.V)
i=c.bA(k.a)
if(i!=null)j.m(0,i)
h=c.bi(b)
g=A.aJ(t.N,t.i)
if(b===B.f){g.u(0,"totalHeadingChangeDegrees",c.aD(a1,s,r))
g.u(0,"apexIndex",c.b5(a1,a0))
j.m(0,B.q)}else j.m(0,c.an(b))
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
return A.fy(e,j,c.af(a1,s,r),a,r,f.d,f.c,a+":"+b.b+":"+s+":"+r,o,g,d,B.aL,A.i_([h],t.c5),h,s,q.d,q.c,k,b)},
bq(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
t.B.a(a)
s=t.N
r=A.aJ(s,t.dg)
for(q=a.length,p=t.s,o=0;n=a.length,o<n;a.length===q||(0,A.au)(a),++o)r.u(0,a[o].a,A.o([],p))
s=A.aJ(s,t.fj)
for(q=t.V,o=0;p=a.length,o<p;a.length===n||(0,A.au)(a),++o){m=a[o]
p=A.fF(q)
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
bi(a){var s
switch(a.a){case 0:s=B.as
break
case 1:s=B.r
break
case 2:s=B.I
break
case 3:s=B.J
break
case 4:s=B.K
break
default:s=null}return s},
an(a){var s
switch(a.a){case 0:s=B.al
break
case 1:s=B.am
break
case 2:s=B.ao
break
case 3:s=B.q
break
case 4:s=B.an
break
default:s=null}return s},
bA(a){var s=null
switch(a.a){case 3:s=B.ar
break
case 2:s=B.aq
break
case 1:s=B.ap
break
case 0:break}return s},
a8(a,b,c){var s,r,q,p,o
t.G.a(a)
t.e.a(b)
for(s=b.length,r=0;r<b.length;b.length===s||(0,A.au)(b),++r){q=b[r]
for(p=q.a,o=q.b;p<=o;++p)B.a.u(a,p,c)}},
b2(a,b){var s,r,q,p,o,n,m
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
B.a.m(s,new A.ag(o,q,n))
q=p}return s},
af(a,b,c){var s,r,q
t.X.a(a)
for(s=b+1,r=a.length,q=0;s<=c;++s){if(!(s<r))return A.b(a,s)
q+=a[s].b.w}return q},
aD(a,b,c){var s,r,q
t.X.a(a)
for(s=b+1,r=a.length,q=0;s<=c;++s){if(!(s<r))return A.b(a,s)
q+=Math.abs(a[s].f)}return q},
b5(a,b){var s,r,q,p,o,n
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
return s.aD(r,q,p)>=15&&s.af(r,q,p)>=15},
$S:6}
A.dE.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.E,t.Q.a(a),s.c,s.d)},
$S:2}
A.dF.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.i,t.Q.a(a),s.c,s.d)},
$S:2}
A.dG.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.m,t.Q.a(a),s.c,s.d)},
$S:2}
A.dH.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.f,t.Q.a(a),s.c,s.d)},
$S:2}
A.dI.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.j,t.Q.a(a),s.c,s.d)},
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
return new A.ag(B.ad,s,r)},
$S:48}
A.dy.prototype={
$1(a){var s,r,q
t.F.a(a)
s=a.a
r=this.a.i(0,s)
r.toString
r=A.i0(r,t.V)
q=this.b.i(0,s)
q.toString
q=A.a7(q,t.N)
r=t.eN.a(new A.bJ(r,t.f4))
t.gJ.a(q)
return A.fy(a.as,r,a.Q,a.b,a.e,a.x,a.r,s,a.y,a.cx,a.z,q,a.ay,a.ax,a.d,a.w,a.f,a.at,a.c)},
$S:25}
A.T.prototype={}
A.dT.prototype={
D(){return"DriveScoreAlgorithmVersion."+this.b}}
A.bf.prototype={
ao(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
t.t.a(b)
s=J.e7(b.slice(0),A.h(b).c)
if(s.length<2)throw A.d(B.a_)
if(B.a.a0(s,new A.dU()))throw A.d(B.a0)
switch(a.a){case 0:r=B.V.bK("in-memory-drive-score",t.Y.a(s))
q=B.S.G(r)
p=B.a3.G(r)
o=B.T.G(r)
n=B.Y.G(r)
m=B.R.G(r)
l=B.a4.G(r)
k=q.z
k=k.a&&k.b&&k.c&&k.d
j=q.f>0||q.r>0
i=p.as.a
h=t.N
g=t.R
f=A.al(["brakingAnticipation",new A.B(q.a,350,!k,j),"tempoPerformance",new A.B(p.a,150,i,i),"corneringPerformance",new A.B(o.a,150,o.y,o.z),"drivingSmoothness",new A.B(n.a,100,n.b,n.c),"accelerationPerformance",new A.B(m.a,50,m.e,m.f),"transitionControl",new A.B(l.a,50,l.e,l.f)],h,g)
e=B.Z.aV(p.r,new A.ak(f,A.i(f).h("ak<2>")))
g=A.fD(h,g)
g.L(0,f)
g.u(0,"drivingEndurance",new A.B(e.a,150,e.f,e.r))
g=B.X.bJ(g)
k=g
break
default:k=null}return k}}
A.dU.prototype={
$1(a){return!t.u.a(a).gbW()},
$S:26}
A.cg.prototype={
k(a){return u.c}}
A.e6.prototype={
k(a){return"Canonical telemetry contains an invalid coordinate."}}
A.dV.prototype={
bJ(a){var s,r,q,p,o,n,m,l,k,j,i
t.cC.a(a)
s=t.N
r=t.D
q=A.aJ(s,r)
for(p=new A.bq(a,A.i(a).h("bq<1,2>")).gq(0),o=0;p.n();){n=p.d
m=n.b
l=m.c
if(l&&m.d)k=B.D
else k=!l?B.a8:B.a9
l=k===B.D
j=l?m.a:m.b*0.75
if(l)++o
q.u(0,n.a,new A.af(j,k))}i=B.b.j(new A.ak(q,q.$ti.h("ak<2>")).F(0,0,new A.dW(),t.i),0,1000)
p=B.b.a3(i)
return new A.c9(i,B.b.j(o/a.a,0,1),p,1,A.fv(a,s,t.R),A.fv(q,s,r))}}
A.dW.prototype={
$2(a,b){return A.m(a)+t.D.a(b).b},
$S:27}
A.bg.prototype={
D(){return"DriveScoreContributionSource."+this.b}}
A.B.prototype={}
A.af.prototype={}
A.c9.prototype={}
A.a5.prototype={
D(){return"DrivingPhase."+this.b}}
A.b4.prototype={
D(){return"TrafficRegime."+this.b}}
A.aH.prototype={
D(){return"DrivingEventType."+this.b}}
A.aw.prototype={
D(){return"EventOwnerDomain."+this.b}}
A.O.prototype={
D(){return"EventContextTag."+this.b}}
A.S.prototype={}
A.ap.prototype={}
A.ag.prototype={}
A.k.prototype={}
A.c7.prototype={
P(a){var s=this.f,r=A.h(s)
return new A.z(s,r.h("l(1)").a(new A.dx(a)),r.h("z<1>"))}}
A.dx.prototype={
$1(a){return t.F.a(a).c===this.a},
$S:4}
A.dX.prototype={
G(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=A.o([],t.g)
for(s=a.P(B.j),r=J.a2(s.a),s=new A.a0(r,s.b,s.$ti.h("a0<1>")),q=0;s.n();){p=r.gp()
o=p.at
n=Math.max(o.c,o.d)
if(p.ax===B.K){o=p.r
m=p.f
o=A.C(o.b-m.b,o.a-m.a).a<8e6||p.y<8.333333333333334||n>=0.65}else o=!0
if(o)++q
else B.a.m(d,p)}s=d.length
if(s===0)return new A.ca(0,!1,!1)
for(l=0,k=B.ae,j=0,i=0;i<d.length;d.length===s||(0,A.au)(d),++i){h=d[i]
r=h.r
p=h.f
g=r.a-p.a
f=r.b-p.b
l+=A.C(f,g).a
if(A.C(f,g).a>k.a)k=A.C(f,g)
j+=B.b.j(1-this.bE(a,h)/4,0,1)*A.C(f,g).a}e=A.C(l,0)
s=B.b.j((0.55*this.b6(e,B.ak,B.af,B.ai)+0.45*(j/l))*100,0,1)
r=e.a
B.c.A(r,1e6)
return new A.ca(s*100,!0,r>=3e7)},
bE(a,b){var s=B.a.a4(a.b,b.d,b.e+1),r=A.h(s),q=r.h("f<1,a>"),p=A.y(new A.f(s,r.h("a(1)").a(new A.dY()),q),q.h("q.E"))
return B.a.F(p,0,new A.dZ(B.a.J(p,new A.e_())/p.length),t.i)/p.length},
b6(a,b,c,d){var s,r=a.a,q=b.a
if(r<=q)return 0
s=c.a
if(r<=s)return 0.75*(r-q)/(s-q)
return 0.75+0.25*B.b.j((r-s)/(d.a-s),0,1)}}
A.dY.prototype={
$1(a){return t.K.a(a).b.d},
$S:3}
A.e_.prototype={
$2(a,b){return A.m(a)+A.m(b)},
$S:0}
A.dZ.prototype={
$2(a,b){var s
A.m(a)
s=A.m(b)-this.a
return a+s*s},
$S:0}
A.e0.prototype={
aV(a,b){var s,r,q,p,o
t.ff.a(b)
s=b.$ti
r=s.h("z<c.E>")
q=A.y(new A.z(b,s.h("l(c.E)").a(new A.e1()),r),r.h("c.E"))
if(a<5||q.length===0)return new A.cb(0,!1,!1)
p=this.bk(a)
s=A.h(q)
o=B.b.j(new A.f(q,s.h("a(1)").a(new A.e2()),s.h("f<1,a>")).J(0,new A.e3())/q.length,0.15,1)
B.b.j(q.length/6,0,1)
s=a>=50&&q.length>=3
return new A.cb(p*o*150,!0,s)},
bk(a){if(a<=5)return a/5*0.15
if(a<=50)return 0.15+(a-5)/45*0.6
return B.b.j(0.75+(a-50)/100*0.25,0,1)}}
A.e1.prototype={
$1(a){t.R.a(a)
return a.c&&a.d},
$S:28}
A.e2.prototype={
$1(a){t.R.a(a)
return a.a/a.b},
$S:29}
A.e3.prototype={
$2(a,b){return A.m(a)+A.m(b)},
$S:0}
A.cb.prototype={}
A.ca.prototype={}
A.bW.prototype={}
A.a6.prototype={
D(){return"DrivingTransitionType."+this.b}}
A.Y.prototype={}
A.cx.prototype={}
A.b0.prototype={
D(){return"LocalRoadWindowState."+this.b}}
A.bw.prototype={
D(){return"LocalRoadRegionAnalysisStatus."+this.b}}
A.ay.prototype={}
A.aK.prototype={}
A.bx.prototype={}
A.eg.prototype={
bL(a,b,c,d,e,f){var s,r,q=t.t
q.a(e)
q.a(c)
if(!f.at)return new A.bx(B.aQ,B.M,B.N)
if(f.as<0.65)return new A.bx(B.aR,B.M,B.N)
s=this.b1(a,b,c,d,e,f)
r=this.bI(a,f,s)
return new A.bx(B.aP,A.a7(s,t.l),A.a7(r,t.v))},
b1(a,b,c,d,a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=t.t
e.a(a0)
e.a(c)
s=A.o([],t.d)
for(r=a1.z,e=a1.e,q=a1.f,p=a1.r,o=a1.w,n=f.a,m=0;m<r;m=l){l=m+100
l=l<r?l:r
k=f.a7(e,q,r,m)
j=f.a7(e,q,r,l)
i=f.a7(p,o,r,m)
h=f.a7(p,o,r,l)
g=n.aL(a,j,d,k,a0,a1,5,!1,h,b,i,c)
B.a.m(s,new A.ay(m,l,k,j,i,h,f.by(g),g))}return s},
bI(a,b,c){var s,r,q,p,o,n,m,l,k,j,i={}
t.fB.a(c)
s=A.o([],t.r)
i.a=null
i.b=0
r=new A.eh(i,s,b,a)
for(q=c.length,p=0;p<c.length;c.length===q||(0,A.au)(c),++p){o=c[p]
if(o.r===B.O){n=i.a
m=o.b
l=o.d
k=o.f
if(n==null)i.a=new A.eO(o.a,m,o.c,l,o.e,k)
else{n.b=m
n.d=l
n.f=k;++n.w}i.b=0
continue}if(i.a==null)continue
j=i.b+(o.b-o.a)
i.b=j
if(j>200.000001)r.$0()}r.$0()
return s},
by(a){var s,r
if(!a.y)return B.P
s=a.x
A:{if(B.x===s){r=B.aS
break A}if(B.y===s){r=B.O
break A}if(B.z===s){r=B.aT
break A}r=B.P
break A}return r},
a7(a,b,c,d){if(c<=0)return a
return a+(b-a)*d/c}}
A.eh.prototype={
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
B.a.m(j.b,new A.aK(p.a,p.b,o,n,m,l,r,s,q,j.d,k,h.w))}i.a=null
i.b=0},
$S:30}
A.eO.prototype={}
A.V.prototype={}
A.Z.prototype={}
A.eo.prototype={
G(a6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2=this,a3=1e6,a4=a6.b,a5=a4.length
if(a5<2)return new A.bG(0,0,B.aW)
for(s=a5-1,r=0,q=0,p=0,o=0,n=0,m=0;m<a5;++m){l=a4[m].b
o+=l.w
if(m===s)continue
k=m+1
if(!(k<a5))return A.b(a4,k)
k=a4[k].b
j=k.c
l=l.c
l=A.C(j.b-l.b,j.a-l.a).a
if(l<=0){++n
continue}if(a2.be(a6,m))q+=l
else{r+=l
p+=k.w}}i=B.a.ga1(a4).b.c.W(B.a.gN(a4).b.c)
h=A.C(r,0)
g=A.C(q,0)
f=o/1000
s=h.a
e=s<=0?0:p/(s/1e6)*3.6
d=a2.bD(a6)
c=a5>=6&&s>=9e7&&o>=1000
B.b.j(Math.min(a5/6,Math.min(s/9e7,f)),0,1)
if(!c){B.b.aS(f,2)
B.c.A(s,a3)
return new A.bG(0,f,new A.bF(!1))}a5=i.a
b=a5<=0?0:o/(a5/1e6)*3.6
a=a2.al(e,B.aE,60)
a0=d.b<2?0:a2.al(d.a*3.6,B.aM,30)
a1=B.b.j(a+a0+a2.al(b,B.aA,60),0,150)
B.b.aS(f,2)
B.c.A(s,a3)
B.c.A(g.a,a3)
return new A.bG(a1,f,new A.bF(!0))},
be(a,b){var s,r,q,p
if(this.bj(a.c,b)===B.G)return!0
s=a.b
r=s.length
if(!(b<r))return A.b(s,b)
q=s[b]
p=b+1
if(!(p<r))return A.b(s,p)
p=s[p]
return q.b.d<=1.3888888888888888&&p.b.d<=1.3888888888888888},
bj(a,b){var s,r,q
t.au.a(a)
for(s=a.length,r=0;r<s;++r){q=a[r]
if(b>=q.b&&b<=q.c)return q.a}return B.F},
bD(a){var s,r,q,p,o,n,m,l,k,j=a.b
for(s=j.length,r=0,q=0,p=0;p<s;++p){o=j[p].b.d
if(!isFinite(o)||o<0)continue
for(n=[p-1,p+1],m=1,l=0;l<2;++l){k=n[l]
if(k<0||k>=s)continue
if(!(k>=0&&k<s))return A.b(j,k)
if(Math.abs(j[k].b.d-o)<=10)++m}if(m<2)continue
if(o>r){q=m
r=o}}return new A.eN(r,q)},
al(a,b,c){var s,r,q,p,o,n
t.gj.a(b)
if(a<=B.a.gN(B.a.gN(b)))return 0
for(s=b.length,r=1;r<s;++r){q=b[r-1]
p=b[r]
if(a<=B.a.gN(p)){s=B.a.gN(q)
o=B.a.gN(p)
n=B.a.gN(q)
return B.b.j(c*(B.a.ga1(q)+(B.a.ga1(p)-B.a.ga1(q))*((a-s)/(o-n))),0,c)}}return c}}
A.eN.prototype={}
A.bG.prototype={}
A.bF.prototype={}
A.ep.prototype={
G(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=a.f,b=A.o([],t.c)
for(s=c.length,r=0;q=r+2,q<s;){if(!(r<s))return A.b(c,r)
p=c[r];++r
if(!(r<s))return A.b(c,r)
o=c[r]
n=c[q]
m=this.bC(p,o,n)
if(m!=null){q=o.at
l=Math.max(q.c,q.d)
q=!1
if(n.y>=8.333333333333334)if(l<0.65){k=o.f
j=p.r
if(A.C(k.b-j.b,k.a-j.a).a<=8e6){q=n.f
k=o.r
k=A.C(q.b-k.b,q.a-k.a).a<=8e6
q=k}}q=!q}else q=!0
if(q)continue
B.a.m(b,new A.Y(m,this.bn(a,n)))}if(b.length===0)return B.b1
i=new A.eu(b)
h=i.$2(B.n,20)
g=i.$2(B.o,20)
f=i.$2(B.p,10)
s=A.aJ(t.am,t.S)
for(q=t.eF,k=t.dA,e=0;e<3;++e){d=B.aO[e]
s.u(0,d,new A.z(b,q.a(new A.et(d)),k).gl(0))}return new A.cx(h+g+f,!0,b.length>=2)},
bC(a,b,c){var s,r
if(c.c!==B.j)return null
s=a.c
r=s===B.j
if(r&&b.c===B.m)return B.n
if(r&&b.c===B.f)return B.o
if(s===B.i)return B.p
return null},
bn(a,b){var s=B.a.a4(a.b,b.d,b.e+1),r=A.h(s)
return B.b.j(1-Math.sqrt(B.a.F(s,0,new A.eq(new A.f(s,r.h("a(1)").a(new A.er()),r.h("f<1,a>")).J(0,new A.es())/s.length),t.i)/s.length)/4,0,1)}}
A.eu.prototype={
$2(a,b){var s=this.a,r=A.h(s),q=r.h("z<1>"),p=A.y(new A.z(s,r.h("l(1)").a(new A.ev(a)),q),q.h("c.E"))
if(p.length===0)return 0
s=A.h(p)
return new A.f(p,s.h("a(1)").a(new A.ew()),s.h("f<1,a>")).J(0,new A.ex())/p.length*b},
$S:31}
A.ev.prototype={
$1(a){return t.f.a(a).a===this.a},
$S:8}
A.ew.prototype={
$1(a){return t.f.a(a).e},
$S:33}
A.ex.prototype={
$2(a,b){return A.m(a)+A.m(b)},
$S:0}
A.et.prototype={
$1(a){return t.f.a(a).a===this.a},
$S:8}
A.er.prototype={
$1(a){return t.K.a(a).b.d},
$S:3}
A.es.prototype={
$2(a,b){return A.m(a)+A.m(b)},
$S:0}
A.eq.prototype={
$2(a,b){var s
A.m(a)
s=t.K.a(b).b.d-this.a
return a+s*s},
$S:47}
A.eB.prototype={}
A.eY.prototype={
$1(a){var s=J.bU(a),r=A.H(s.i(a,"id"))
s=J.cH(t.j.a(s.i(a,"geometry")),new A.eX(),t.x)
s=A.y(s,s.$ti.h("q.E"))
return new A.Z(r,s,A.v(t.P.a(a).i(0,"distanceMeters")))},
$S:35}
A.eX.prototype={
$1(a){t.P.a(a)
return new A.V(A.v(a.i(0,"latitude")),A.v(a.i(0,"longitude")))},
$S:9}
A.eZ.prototype={
$1(a){return t.p.a(a).b},
$S:37}
A.f_.prototype={
$2(a,b){return A.m(a)+t.p.a(b).c},
$S:38}
A.f4.prototype={
$1(a){var s,r,q,p,o
t.P.a(a)
s=A.v(a.i(0,"latitude"))
r=A.v(a.i(0,"longitude"))
q=A.hU(A.H(a.i(0,"timestamp")))
p=A.v(a.i(0,"speed_mps"))
o=A.v(a.i(0,"heading_degrees"))
A.v(a.i(0,"altitude_meters"))
A.v(a.i(0,"accuracy_meters"))
return new A.F(s,r,q,p,o,A.v(a.i(0,"distance_from_previous_meters")),A.v(a.i(0,"acceleration_mps2")))},
$S:39}
A.f0.prototype={
$2(a,b){A.H(a)
t.R.a(b)
return new A.D(a,A.al(["score",b.a,"maximum",b.b,"applicable",b.c,"sampleSufficient",b.d],t.N,t.C),t.w)},
$S:40}
A.f1.prototype={
$2(a,b){A.H(a)
t.D.a(b)
return new A.D(a,A.al(["contribution",b.b,"source",b.c.b],t.N,t.C),t.w)},
$S:41}
A.f3.prototype={
$1(a){return t.u.a(a).c.c4().c3()},
$S:42}
A.eU.prototype={
$1(a){t.P.a(a)
return new A.V(A.v(a.i(0,"latitude")),A.v(a.i(0,"longitude")))},
$S:9}
A.eR.prototype={
$1(a){t.l.a(a)
return A.al(["commonStartOffsetMeters",a.a,"commonEndOffsetMeters",a.b,"existingStartOffsetMeters",a.c,"existingEndOffsetMeters",a.d,"challengerStartOffsetMeters",a.e,"challengerEndOffsetMeters",a.f,"state",a.r.b,"comparison",A.hi(a.w)],t.N,t.C)},
$S:43}
A.eS.prototype={
$1(a){t.v.a(a)
return A.al(["existingDriveId",a.a,"challengerDriveId",a.b,"startOffsetOnExistingMeters",a.d,"endOffsetOnExistingMeters",a.e,"startOffsetOnChallengerMeters",a.f,"endOffsetOnChallengerMeters",a.r,"commonStartOffsetMeters",a.w,"commonEndOffsetMeters",a.x,"winningDistanceMeters",a.y,"algorithmVersion",1,"confidence",a.Q,"supportingWindowCount",a.as],t.N,t.C)},
$S:44}
A.cu.prototype={
ao(a,b){var s
t.t.a(b)
s=J.hF(this.y,this.z++)
if(s==null){++this.z
throw A.d(A.i8("synthetic invalid window"))}A.v(s)
return new A.c9(s,1,B.b.a3(s),1,B.aU,B.aV)}}
A.eW.prototype={
$1(a){var s=t.P,r=s.a(B.w.bO(A.H(a),null)),q=t.j
return B.w.bQ(A.jb(A.jh(s.a(r.i(0,"match"))),A.hn(s.a(r.i(0,"firstRoad"))),A.hn(s.a(r.i(0,"secondRoad"))),A.hp(q.a(r.i(0,"firstTelemetry"))),A.hp(q.a(r.i(0,"secondTelemetry"))),new A.c1(new A.cu(q.a(r.i(0,"scores"))))),null)},
$S:45};(function aliases(){var s=J.ax.prototype
s.aX=s.k})();(function installTearOffs(){var s=hunkHelpers._static_2,r=hunkHelpers._static_1,q=hunkHelpers._instance_1u,p=hunkHelpers.installStaticTearOff
s(J,"iQ","hX",46)
r(A,"jf","iG",34)
q(A.c6.prototype,"gbF","bG",5)
q(A.c8.prototype,"gbc","bd",1)
p(A,"jr",2,null,["$1$2","$2"],["hl",function(a,b){return A.hl(a,b,t.H)}],32,0)})();(function inheritance(){var s=hunkHelpers.mixin,r=hunkHelpers.inherit,q=hunkHelpers.inheritMany
r(A.j,null)
q(A.j,[A.f7,J.ch,A.bB,J.aF,A.c,A.bb,A.t,A.em,A.bu,A.by,A.a0,A.bl,A.bC,A.bj,A.b1,A.bd,A.K,A.ey,A.ek,A.I,A.ed,A.bs,A.bt,A.br,A.cl,A.eI,A.a_,A.cA,A.eJ,A.aN,A.cD,A.aO,A.bR,A.bM,A.cE,A.c0,A.c4,A.eG,A.a4,A.L,A.eC,A.cp,A.bD,A.eD,A.e4,A.D,A.aL,A.b3,A.cI,A.cX,A.aB,A.a9,A.dc,A.cW,A.F,A.c1,A.dd,A.c2,A.av,A.dh,A.de,A.a1,A.eE,A.c6,A.c5,A.a3,A.dw,A.c8,A.T,A.bf,A.cg,A.e6,A.dV,A.B,A.af,A.c9,A.S,A.ap,A.ag,A.k,A.c7,A.dX,A.e0,A.cb,A.ca,A.bW,A.Y,A.cx,A.ay,A.aK,A.bx,A.eg,A.eO,A.V,A.Z,A.eo,A.eN,A.bG,A.bF,A.ep,A.eB])
q(J.ch,[J.cj,J.bn,J.b_,J.aY,J.aI])
q(J.b_,[J.ax,J.n])
q(J.ax,[J.el,J.az,J.bo])
r(J.ci,A.bB)
r(J.e8,J.n)
q(J.aY,[J.bm,J.ck])
q(A.c,[A.b5,A.p,A.am,A.z,A.bk,A.ao])
r(A.aG,A.b5)
r(A.bL,A.aG)
q(A.t,[A.co,A.bH,A.cm,A.cy,A.ct,A.cz,A.bp,A.bX,A.ac,A.bK,A.b2,A.c3])
q(A.p,[A.q,A.bi,A.aj,A.ak,A.bq])
q(A.q,[A.bE,A.f,A.ef,A.cC])
r(A.bh,A.am)
r(A.aV,A.ao)
r(A.b7,A.b1)
r(A.bI,A.b7)
r(A.be,A.bI)
q(A.K,[A.c_,A.cf,A.bZ,A.cw,A.du,A.dv,A.cQ,A.cS,A.cT,A.cU,A.cJ,A.cM,A.cN,A.da,A.db,A.cY,A.cZ,A.d1,A.d2,A.d4,A.d5,A.d6,A.d0,A.d_,A.d3,A.df,A.dp,A.dk,A.dl,A.dm,A.dn,A.dA,A.dz,A.dB,A.dM,A.dL,A.dN,A.dP,A.dO,A.dQ,A.dR,A.dC,A.dS,A.dD,A.dE,A.dF,A.dG,A.dH,A.dI,A.dK,A.dy,A.dU,A.dx,A.dY,A.e1,A.e2,A.ev,A.ew,A.et,A.er,A.eY,A.eX,A.eZ,A.f4,A.f3,A.eU,A.eR,A.eS,A.eW])
q(A.c_,[A.di,A.e9,A.ee,A.ej,A.eH,A.cR,A.cL,A.cK,A.cP,A.cO,A.d8,A.d9,A.dg,A.dq,A.dr,A.dj,A.dJ,A.dW,A.e_,A.dZ,A.e3,A.eu,A.ex,A.es,A.eq,A.f_,A.f0,A.f1])
r(A.Q,A.bd)
r(A.aW,A.cf)
r(A.bz,A.bH)
q(A.cw,[A.cv,A.aU])
q(A.I,[A.ai,A.cB])
r(A.b6,A.cz)
q(A.aN,[A.bN,A.bS])
r(A.as,A.bN)
r(A.bJ,A.bS)
r(A.cn,A.bp)
r(A.ea,A.c0)
q(A.c4,[A.ec,A.eb])
r(A.eF,A.eG)
q(A.bZ,[A.ds,A.d7,A.eh])
q(A.ac,[A.bA,A.ce])
q(A.eC,[A.ad,A.bc,A.dT,A.bg,A.a5,A.b4,A.aH,A.aw,A.O,A.a6,A.b0,A.bw])
r(A.cu,A.bf)
s(A.b7,A.bR)
s(A.bS,A.cE)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{X:"int",a:"double",J:"num",e:"String",l:"bool",aL:"Null",u:"List",j:"Object",r:"Map",aZ:"JSObject"},mangledNames:{},types:["a(a,a)","l(S)","k(T)","a(S)","l(k)","a(a3)","l(T)","a(k)","l(Y)","V(@)","a(a9)","a(a,aB)","X(e?)","~(j?,j?)","a(a(k))","l(a9)","~(@,@)","F(a1)","a(a,a1)","0&()","a(a(a3))","l(k?)","aL()","X(k,k)","a(a)","k(k)","l(F)","a(a,af)","l(B)","a(B)","~()","a(a6,a)","0^(0^,0^)<J>","a(Y)","@(@)","Z(@)","l(e)","u<V>(Z)","a(a,Z)","F(@)","D<e,r<e,j>>(e,B)","D<e,r<e,j>>(e,af)","e(F)","r<e,j>(ay)","r<e,j>(aK)","e(e)","X(@,@)","a(a,S)","ag(T)"],arrayRti:Symbol("$ti")}
A.it(v.typeUniverse,JSON.parse('{"bo":"ax","el":"ax","az":"ax","cj":{"l":[],"aq":[]},"bn":{"aq":[]},"b_":{"aZ":[]},"ax":{"aZ":[]},"n":{"u":["1"],"p":["1"],"aZ":[],"c":["1"]},"ci":{"bB":[]},"e8":{"n":["1"],"u":["1"],"p":["1"],"aZ":[],"c":["1"]},"aF":{"w":["1"]},"aY":{"a":[],"J":[],"P":["J"]},"bm":{"a":[],"X":[],"J":[],"P":["J"],"aq":[]},"ck":{"a":[],"J":[],"P":["J"],"aq":[]},"aI":{"e":[],"P":["e"],"aq":[]},"b5":{"c":["2"]},"bb":{"w":["2"]},"aG":{"b5":["1","2"],"c":["2"],"c.E":"2"},"bL":{"aG":["1","2"],"b5":["1","2"],"p":["2"],"c":["2"],"c.E":"2"},"co":{"t":[]},"p":{"c":["1"]},"q":{"p":["1"],"c":["1"]},"bE":{"q":["1"],"p":["1"],"c":["1"],"q.E":"1","c.E":"1"},"bu":{"w":["1"]},"am":{"c":["2"],"c.E":"2"},"bh":{"am":["1","2"],"p":["2"],"c":["2"],"c.E":"2"},"by":{"w":["2"]},"f":{"q":["2"],"p":["2"],"c":["2"],"q.E":"2","c.E":"2"},"z":{"c":["1"],"c.E":"1"},"a0":{"w":["1"]},"bk":{"c":["2"],"c.E":"2"},"bl":{"w":["2"]},"ao":{"c":["1"],"c.E":"1"},"aV":{"ao":["1"],"p":["1"],"c":["1"],"c.E":"1"},"bC":{"w":["1"]},"bi":{"p":["1"],"c":["1"],"c.E":"1"},"bj":{"w":["1"]},"be":{"bI":["1","2"],"b7":["1","2"],"b1":["1","2"],"bR":["1","2"],"r":["1","2"]},"bd":{"r":["1","2"]},"Q":{"bd":["1","2"],"r":["1","2"]},"cf":{"K":[],"ah":[]},"aW":{"K":[],"ah":[]},"bz":{"t":[]},"cm":{"t":[]},"cy":{"t":[]},"K":{"ah":[]},"bZ":{"K":[],"ah":[]},"c_":{"K":[],"ah":[]},"cw":{"K":[],"ah":[]},"cv":{"K":[],"ah":[]},"aU":{"K":[],"ah":[]},"ct":{"t":[]},"ai":{"I":["1","2"],"fC":["1","2"],"r":["1","2"],"I.K":"1","I.V":"2"},"aj":{"p":["1"],"c":["1"],"c.E":"1"},"bs":{"w":["1"]},"ak":{"p":["1"],"c":["1"],"c.E":"1"},"bt":{"w":["1"]},"bq":{"p":["D<1,2>"],"c":["D<1,2>"],"c.E":"D<1,2>"},"br":{"w":["D<1,2>"]},"cl":{"i5":[]},"cz":{"t":[]},"b6":{"t":[]},"as":{"bN":["1"],"aN":["1"],"fE":["1"],"aM":["1"],"p":["1"],"c":["1"]},"aO":{"w":["1"]},"I":{"r":["1","2"]},"b1":{"r":["1","2"]},"bI":{"b7":["1","2"],"b1":["1","2"],"bR":["1","2"],"r":["1","2"]},"ef":{"q":["1"],"p":["1"],"c":["1"],"q.E":"1","c.E":"1"},"bM":{"w":["1"]},"aN":{"aM":["1"],"p":["1"],"c":["1"]},"bN":{"aN":["1"],"aM":["1"],"p":["1"],"c":["1"]},"bJ":{"aN":["1"],"cE":["1"],"aM":["1"],"p":["1"],"c":["1"]},"cB":{"I":["e","@"],"r":["e","@"],"I.K":"e","I.V":"@"},"cC":{"q":["e"],"p":["e"],"c":["e"],"q.E":"e","c.E":"e"},"bp":{"t":[]},"cn":{"t":[]},"a4":{"P":["a4"]},"a":{"J":[],"P":["J"]},"L":{"P":["L"]},"X":{"J":[],"P":["J"]},"u":{"p":["1"],"c":["1"]},"J":{"P":["J"]},"aM":{"p":["1"],"c":["1"]},"e":{"P":["e"]},"bX":{"t":[]},"bH":{"t":[]},"ac":{"t":[]},"bA":{"t":[]},"ce":{"t":[]},"bK":{"t":[]},"b2":{"t":[]},"c3":{"t":[]},"cp":{"t":[]},"bD":{"t":[]},"b3":{"i9":[]},"cu":{"bf":[]}}'))
A.is(v.typeUniverse,JSON.parse('{"bS":1,"c0":2,"c4":2}'))
var u={c:"At least two canonical telemetry points are required."}
var t=(function rtii(){var s=A.ab
return{u:s("F"),fI:s("F(a1)"),e8:s("P<@>"),h:s("a3"),dy:s("a4"),D:s("af"),R:s("B"),F:s("k"),fR:s("a5"),gE:s("ag"),f:s("Y"),am:s("a6"),fu:s("L"),O:s("p<@>"),bU:s("t"),V:s("O"),c5:s("aw"),Z:s("ah"),t:s("c<F>"),ff:s("c<B>"),bM:s("c<a>"),hf:s("c<@>"),df:s("n<a3>"),g:s("n<k>"),q:s("n<ag>"),c:s("n<Y>"),b:s("n<u<a>>"),d:s("n<ay>"),r:s("n<aK>"),s:s("n<e>"),W:s("n<S>"),gI:s("n<ap>"),h9:s("n<a9>"),du:s("n<a1>"),dO:s("n<T>"),aS:s("n<aB>"),n:s("n<a>"),gn:s("n<@>"),T:s("bn"),m:s("aZ"),L:s("bo"),Y:s("u<F>"),B:s("u<k>"),G:s("u<a5>"),au:s("u<ag>"),gj:s("u<u<a>>"),fB:s("u<ay>"),f8:s("u<V>"),dg:s("u<e>"),X:s("u<S>"),dr:s("u<ap>"),cT:s("u<a9>"),e:s("u<T>"),ap:s("u<aB>"),o:s("u<a>"),j:s("u<@>"),l:s("ay"),v:s("aK"),w:s("D<e,r<e,j>>"),cC:s("r<e,B>"),h6:s("r<e,j>"),P:s("r<e,@>"),eO:s("r<@,@>"),gM:s("f<a1,F>"),x:s("V"),p:s("Z"),a:s("aL"),C:s("j"),gT:s("jz"),fj:s("aM<O>"),cq:s("aM<e>"),N:s("e"),K:s("S"),fo:s("ap"),dm:s("aq"),ak:s("az"),f4:s("bJ<O>"),dA:s("z<Y>"),k:s("a9"),A:s("a1"),Q:s("T"),E:s("aB"),y:s("l"),eF:s("l(Y)"),d1:s("l(S)"),_:s("l(T)"),i:s("a"),bk:s("a(a3)"),bE:s("a(k)"),z:s("@"),S:s("X"),J:s("k?"),eH:s("fz<aL>?"),an:s("aZ?"),gJ:s("u<e>?"),bF:s("u<@>?"),U:s("j?"),eN:s("aM<O>?"),dk:s("e?"),M:s("cD?"),fQ:s("l?"),cD:s("a?"),I:s("X?"),cg:s("J?"),H:s("J"),cA:s("~(e,@)")}})();(function constants(){var s=hunkHelpers.makeConstList
B.at=J.ch.prototype
B.a=J.n.prototype
B.c=J.bm.prototype
B.b=J.aY.prototype
B.d=J.aI.prototype
B.au=J.b_.prototype
B.Q=new A.aW(A.jr(),A.ab("aW<a>"))
B.R=new A.cI()
B.S=new A.cX()
B.u=new A.de()
B.T=new A.c6()
B.U=new A.dw()
B.V=new A.c8()
B.X=new A.dV()
B.Y=new A.dX()
B.v=new A.bj(A.ab("bj<0&>"))
B.Z=new A.e0()
B.a_=new A.cg()
B.a0=new A.e6()
B.a1=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.w=new A.ea()
B.a2=new A.cp()
B.b3=new A.em()
B.a3=new A.eo()
B.a4=new A.ep()
B.W=new A.bf()
B.b4=new A.c1(B.W)
B.x=new A.ad(0,"firstWins")
B.y=new A.ad(1,"secondWins")
B.z=new A.ad(2,"noMeaningfulDifference")
B.a5=new A.ad(3,"notEligible")
B.A=new A.ad(4,"insufficientTelemetry")
B.a6=new A.ad(5,"mappingFailed")
B.a7=new A.ad(7,"calculationFailed")
B.l=new A.bc(0,"success")
B.e=new A.bc(1,"mappingFailed")
B.B=new A.bc(2,"insufficientTelemetry")
B.C=new A.dT(0,"v1")
B.D=new A.bg(0,"actual")
B.a8=new A.bg(1,"neutralNotApplicable")
B.a9=new A.bg(2,"neutralInsufficient")
B.E=new A.aH(0,"stop")
B.i=new A.aH(1,"acceleration")
B.m=new A.aH(2,"deceleration")
B.f=new A.aH(3,"corner")
B.j=new A.aH(4,"cruise")
B.F=new A.a5(0,"unknown")
B.G=new A.a5(1,"stopped")
B.aa=new A.a5(2,"accelerating")
B.ab=new A.a5(3,"cruising")
B.ac=new A.a5(4,"decelerating")
B.ad=new A.a5(5,"cornering")
B.n=new A.a6(0,"cruiseDecelCruise")
B.o=new A.a6(1,"cruiseCornerCruise")
B.p=new A.a6(2,"accelerationCruise")
B.ae=new A.L(0)
B.af=new A.L(12e7)
B.H=new A.L(15e5)
B.ag=new A.L(2e6)
B.ah=new A.L(3e6)
B.ai=new A.L(3e8)
B.aj=new A.L(5e6)
B.ak=new A.L(8e6)
B.al=new A.O(0,"stopped")
B.am=new A.O(1,"accelerating")
B.an=new A.O(2,"cruising")
B.ao=new A.O(3,"decelerating")
B.q=new A.O(4,"cornering")
B.ap=new A.O(5,"freeFlow")
B.aq=new A.O(6,"denseTraffic")
B.ar=new A.O(7,"stopAndGo")
B.as=new A.aw(0,"stopping")
B.r=new A.aw(1,"acceleration")
B.I=new A.aw(2,"braking")
B.J=new A.aw(3,"cornering")
B.K=new A.aw(4,"cruising")
B.av=new A.eb(null)
B.aw=new A.ec(null)
B.t=s([0,0],t.n)
B.aC=s([20,0.25],t.n)
B.aI=s([50,0.58],t.n)
B.aH=s([80,0.83],t.n)
B.ax=s([120,1],t.n)
B.aA=s([B.t,B.aC,B.aI,B.aH,B.ax],t.b)
B.aB=s([30,0.25],t.n)
B.aD=s([60,0.58],t.n)
B.aN=s([100,0.83],t.n)
B.ay=s([150,1],t.n)
B.aE=s([B.t,B.aB,B.aD,B.aN,B.ay],t.b)
B.h=s([],A.ab("n<F>"))
B.aK=s([],t.g)
B.aJ=s([],t.q)
B.M=s([],t.d)
B.N=s([],t.r)
B.aL=s([],t.s)
B.L=s([],t.W)
B.aG=s([80,0.33],t.n)
B.aF=s([140,0.67],t.n)
B.az=s([200,1],t.n)
B.aM=s([B.t,B.aG,B.aF,B.az],t.b)
B.aO=s([B.n,B.o,B.p],A.ab("n<a6>"))
B.aP=new A.bw(0,"success")
B.aQ=new A.bw(1,"notEligible")
B.aR=new A.bw(2,"insufficientConfidence")
B.aS=new A.b0(0,"existingBetter")
B.O=new A.b0(1,"challengerBetter")
B.aT=new A.b0(2,"noMeaningfulDifference")
B.P=new A.b0(3,"invalid")
B.k={}
B.aV=new A.Q(B.k,[],A.ab("Q<e,af>"))
B.aU=new A.Q(B.k,[],A.ab("Q<e,B>"))
B.b6=new A.Q(B.k,[],A.ab("Q<e,a>"))
B.aW=new A.bF(!1)
B.aY=new A.b4(0,"unknown")
B.aX=new A.ap(B.aY,0,0)
B.aZ=new A.b4(1,"freeFlow")
B.b_=new A.b4(2,"denseTraffic")
B.b0=new A.b4(3,"stopAndGo")
B.b7=new A.Q(B.k,[],A.ab("Q<a6,X>"))
B.b5=s([],t.c)
B.b1=new A.cx(0,!1,!1)
B.b2=A.jv("j")})();(function staticFields(){$.U=A.o([],A.ab("n<j>"))
$.fI=null
$.fr=null
$.fq=null})();(function lazyInitializers(){var s=hunkHelpers.lazyFinal
s($,"jx","hr",()=>A.hj("_$dart_dartClosure"))
s($,"jw","fk",()=>A.hj("_$dart_dartClosure_dartJSInterop"))
s($,"jL","hE",()=>A.o([new J.ci()],A.ab("n<bB>")))
s($,"jA","ht",()=>A.ar(A.ez({
toString:function(){return"$receiver$"}})))
s($,"jB","hu",()=>A.ar(A.ez({$method$:null,
toString:function(){return"$receiver$"}})))
s($,"jC","hv",()=>A.ar(A.ez(null)))
s($,"jD","hw",()=>A.ar(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"jG","hz",()=>A.ar(A.ez(void 0)))
s($,"jH","hA",()=>A.ar(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"jF","hy",()=>A.ar(A.fV(null)))
s($,"jE","hx",()=>A.ar(function(){try{null.$method$}catch(r){return r.message}}()))
s($,"jJ","hC",()=>A.ar(A.fV(void 0)))
s($,"jI","hB",()=>A.ar(function(){try{(void 0).$method$}catch(r){return r.message}}()))
s($,"jy","hs",()=>A.i6("^([+-]?\\d{4,6})-?(\\d\\d)-?(\\d\\d)(?:[ T](\\d\\d)(?::?(\\d\\d)(?::?(\\d\\d)(?:[.,](\\d+))?)?)?( ?[zZ]| ?([-+])(\\d\\d)(?::?(\\d\\d))?)?)?$"))
s($,"jK","hD",()=>A.hm(B.b2))})();(function nativeSupport(){!function(){var s=function(a){var m={}
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
var s=A.jq
if(typeof dartMainRunner==="function"){dartMainRunner(s,[])}else{s([])}})})()
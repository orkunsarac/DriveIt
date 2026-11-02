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
if(a[b]!==s){A.ky(b)}a[b]=r}var q=a[b]
a[c]=function(){return q}
return q}}function makeConstList(a,b){if(b!=null)A.i(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var s=0;s<a.length;++s){convertToFastObject(a[s])}}var y=0
function instanceTearOffGetter(a,b){var s=null
return a?function(c){if(s===null)s=A.hc(b)
return new s(c,this)}:function(){if(s===null)s=A.hc(b)
return new s(this,null)}}function staticTearOffGetter(a){var s=null
return function(){if(s===null)s=A.hc(a).prototype
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
hz(a,b){if(a<0||a>4294967295)throw A.d(A.ak(a,0,4294967295,"length",null))
return J.cE(new Array(a),b)},
hy(a,b){if(a<0)throw A.d(A.dj("Length must be a non-negative integer: "+a))
return A.i(new Array(a),b.h("l<0>"))},
cE(a,b){var s=A.i(a,b.h("l<0>"))
s.$flags=1
return s},
j_(a,b){var s=t.e8
return J.iG(s.a(a),s.a(b))},
b0(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.bB.prototype
return J.cG.prototype}if(typeof a=="string")return J.aU.prototype
if(a==null)return J.bC.prototype
if(typeof a=="boolean")return J.cF.prototype
if(Array.isArray(a))return J.l.prototype
if(typeof a=="function")return J.bD.prototype
if(typeof a=="object"){if(a instanceof A.o){return a}else{return J.bc.prototype}}if(!(a instanceof A.o))return J.aK.prototype
return a},
bo(a){if(a==null)return a
if(Array.isArray(a))return J.l.prototype
if(!(a instanceof A.o))return J.aK.prototype
return a},
bp(a){if(typeof a=="string")return J.aU.prototype
if(a==null)return a
if(Array.isArray(a))return J.l.prototype
if(!(a instanceof A.o))return J.aK.prototype
return a},
kn(a){if(typeof a=="number")return J.ba.prototype
if(typeof a=="string")return J.aU.prototype
if(a==null)return a
if(!(a instanceof A.o))return J.aK.prototype
return a},
an(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.b0(a).M(a,b)},
iF(a,b){return J.bo(a).l(a,b)},
iG(a,b){return J.kn(a).C(a,b)},
hi(a,b){return J.bo(a).E(a,b)},
a1(a){return J.b0(a).gD(a)},
fW(a){return J.bp(a).gv(a)},
iH(a){return J.bo(a).ga_(a)},
W(a){return J.bo(a).gt(a)},
aP(a){return J.bp(a).gm(a)},
iI(a){return J.b0(a).gW(a)},
b4(a,b,c){return J.bo(a).b8(a,b,c)},
hj(a,b){return J.bo(a).N(a,b)},
b5(a){return J.b0(a).j(a)},
cC:function cC(){},
cF:function cF(){},
bC:function bC(){},
bc:function bc(){},
aI:function aI(){},
eS:function eS(){},
aK:function aK(){},
bD:function bD(){},
l:function l(a){this.$ti=a},
cD:function cD(){},
eG:function eG(a){this.$ti=a},
aQ:function aQ(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
ba:function ba(){},
bB:function bB(){},
cG:function cG(){},
aU:function aU(){}},A={fY:function fY(){},
ho(a,b,c){if(t.U.b(a))return new A.c3(a,b.h("@<0>").u(c).h("c3<1,2>"))
return new A.aR(a,b.h("@<0>").u(c).h("aR<1,2>"))},
j1(a){return new A.bF("Field '"+a+"' has not been initialized.")},
az(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
eU(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
ii(a,b,c){return a},
hf(a){var s,r
for(s=$.a7.length,r=0;r<s;++r)if(a===$.a7[r])return!0
return!1},
bV(a,b,c,d){A.ax(b,"start")
if(c!=null){A.ax(c,"end")
if(b>c)A.b3(A.ak(b,0,c,"start",null))}return new A.bU(a,b,c,d.h("bU<0>"))},
j5(a,b,c,d){if(t.U.b(a))return new A.bw(a,b,c.h("@<0>").u(d).h("bw<1,2>"))
return new A.a3(a,b,c.h("@<0>").u(d).h("a3<1,2>"))},
hR(a,b,c){var s="count"
if(t.U.b(a)){A.dk(b,s,t.S)
A.ax(b,s)
return new A.b8(a,b,c.h("b8<0>"))}A.dk(b,s,t.S)
A.ax(b,s)
return new A.ay(a,b,c.h("ay<0>"))},
aT(){return new A.bf("No element")},
iY(){return new A.bf("Too few elements")},
bi:function bi(){},
br:function br(a,b){this.a=a
this.$ti=b},
aR:function aR(a,b){this.a=a
this.$ti=b},
c3:function c3(a,b){this.a=a
this.$ti=b},
bF:function bF(a){this.a=a},
eT:function eT(){},
w:function w(){},
n:function n(){},
bU:function bU(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
aw:function aw(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
a3:function a3(a,b,c){this.a=a
this.b=b
this.$ti=c},
bw:function bw(a,b,c){this.a=a
this.b=b
this.$ti=c},
bO:function bO(a,b,c){var _=this
_.a=null
_.b=a
_.c=b
_.$ti=c},
f:function f(a,b,c){this.a=a
this.b=b
this.$ti=c},
x:function x(a,b,c){this.a=a
this.b=b
this.$ti=c},
ae:function ae(a,b,c){this.a=a
this.b=b
this.$ti=c},
bz:function bz(a,b,c){this.a=a
this.b=b
this.$ti=c},
bA:function bA(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
ay:function ay(a,b,c){this.a=a
this.b=b
this.$ti=c},
b8:function b8(a,b,c){this.a=a
this.b=b
this.$ti=c},
bS:function bS(a,b,c){this.a=a
this.b=b
this.$ti=c},
bx:function bx(a){this.$ti=a},
by:function by(a){this.$ti=a},
c1:function c1(a,b){this.a=a
this.$ti=b},
c2:function c2(a,b){this.a=a
this.$ti=b},
hr(a,b,c){var s,r,q,p,o,n,m,l=A.k(a),k=A.h0(new A.av(a,l.h("av<1>")),!0,b),j=k.length,i=0
for(;;){if(!(i<j)){s=!0
break}r=k[i]
if(typeof r!="string"||"__proto__"===r){s=!1
break}++i}if(s){q={}
for(p=0,i=0;i<k.length;k.length===j||(0,A.D)(k),++i,p=o){r=k[i]
c.a(a.i(0,r))
o=p+1
q[r]=p}n=A.h0(new A.ac(a,l.h("ac<2>")),!0,c)
m=new A.aa(q,n,b.h("@<0>").u(c).h("aa<1,2>"))
m.$keys=k
return m}return new A.bu(A.j2(a,b,c),b.h("@<0>").u(c).h("bu<1,2>"))},
ir(a){var s=v.mangledGlobalNames[a]
if(s!=null)return s
return"minified:"+a},
B(a){var s
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
s=J.b5(a)
return s},
cM(a){var s,r=$.hG
if(r==null)r=$.hG=Symbol("identityHashCode")
s=a[r]
if(s==null){s=Math.random()*0x3fffffff|0
a[r]=s}return s},
j7(a,b){var s,r=/^\s*[+-]?((0x[a-f0-9]+)|(\d+)|([a-z0-9]+))\s*$/i.exec(a)
if(r==null)return null
if(3>=r.length)return A.a(r,3)
s=r[3]
if(s!=null)return parseInt(a,10)
if(r[2]!=null)return parseInt(a,16)
return null},
cN(a){var s,r,q,p
if(a instanceof A.o)return A.V(A.ce(a),null)
s=J.b0(a)
if(s===B.az||s===B.aA||t.ak.b(a)){r=B.a6(a)
if(r!=="Object"&&r!=="")return r
q=a.constructor
if(typeof q=="function"){p=q.name
if(typeof p=="string"&&p!=="Object"&&p!=="")return p}}return A.V(A.ce(a),null)},
hN(a){var s,r,q
if(a==null||typeof a=="number"||A.ha(a))return J.b5(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.R)return a.j(0)
if(a instanceof A.b_)return a.b_(!0)
s=$.iE()
for(r=0;r<1;++r){q=s[r].cB(a)
if(q!=null)return q}return"Instance of '"+A.cN(a)+"'"},
N(a){var s
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){s=a-65536
return String.fromCharCode((B.c.aY(s,10)|55296)>>>0,s&1023|56320)}throw A.d(A.ak(a,0,1114111,null,null))},
hO(a,b,c,d,e,f,g,h,i){var s,r,q,p=b-1
if(0<=a&&a<100){a+=400
p-=4800}s=B.c.X(h,1000)
g+=B.c.B(h-s,1000)
r=i?Date.UTC(a,p,c,d,e,f,g):new Date(a,p,c,d,e,f,g).valueOf()
q=!0
if(!isNaN(r))if(!(r<-864e13))if(!(r>864e13))q=r===864e13&&s!==0
if(q)return null
return r},
a4(a){if(a.date===void 0)a.date=new Date(a.a)
return a.date},
cL(a){return a.c?A.a4(a).getUTCFullYear()+0:A.a4(a).getFullYear()+0},
hL(a){return a.c?A.a4(a).getUTCMonth()+1:A.a4(a).getMonth()+1},
hH(a){return a.c?A.a4(a).getUTCDate()+0:A.a4(a).getDate()+0},
hI(a){return a.c?A.a4(a).getUTCHours()+0:A.a4(a).getHours()+0},
hK(a){return a.c?A.a4(a).getUTCMinutes()+0:A.a4(a).getMinutes()+0},
hM(a){return a.c?A.a4(a).getUTCSeconds()+0:A.a4(a).getSeconds()+0},
hJ(a){return a.c?A.a4(a).getUTCMilliseconds()+0:A.a4(a).getMilliseconds()+0},
kq(a){throw A.d(A.ih(a))},
a(a,b){if(a==null)J.aP(a)
throw A.d(A.fH(a,b))},
fH(a,b){var s,r="index"
if(!A.cd(b))return new A.ao(!0,b,r,null)
s=A.a0(J.aP(a))
if(b<0||b>=s)return A.eE(b,s,a,null,r)
return A.j8(b,r)},
ih(a){return new A.ao(!0,a,null,null)},
d(a){return A.J(a,new Error())},
J(a,b){var s
if(a==null)a=new A.bY()
b.dartException=a
s=A.kz
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:s})
b.name=""}else b.toString=s
return b},
kz(){return J.b5(this.dartException)},
b3(a,b){throw A.J(a,b==null?new Error():b)},
d3(a,b,c){var s
if(b==null)b=0
if(c==null)c=0
s=Error()
A.b3(A.jI(a,b,c),s)},
jI(a,b,c){var s,r,q,p,o,n,m,l,k
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
return new A.c0("'"+s+"': Cannot "+o+" "+l+k+n)},
D(a){throw A.d(A.O(a))},
aC(a){var s,r,q,p,o,n
a=A.kx(a.replace(String({}),"$receiver$"))
s=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(s==null)s=A.i([],t.s)
r=s.indexOf("\\$arguments\\$")
q=s.indexOf("\\$argumentsExpr\\$")
p=s.indexOf("\\$expr\\$")
o=s.indexOf("\\$method\\$")
n=s.indexOf("\\$receiver\\$")
return new A.f5(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),r,q,p,o,n)},
f6(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(s){return s.message}}(a)},
hT(a){return function($expr$){try{$expr$.$method$}catch(s){return s.message}}(a)},
fZ(a,b){var s=b==null,r=s?null:b.method
return new A.cI(a,r,s?null:b.receiver)},
hg(a){if(a==null)return new A.eR(a)
if(typeof a!=="object")return a
if("dartException" in a)return A.b2(a,a.dartException)
return A.ka(a)},
b2(a,b){if(t.bU.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
ka(a){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(!("message" in a))return a
s=a.message
if("number" in a&&typeof a.number=="number"){r=a.number
q=r&65535
if((B.c.aY(r,16)&8191)===10)switch(q){case 438:return A.b2(a,A.fZ(A.B(s)+" (Error "+q+")",null))
case 445:case 5007:A.B(s)
return A.b2(a,new A.bP())}}if(a instanceof TypeError){p=$.iu()
o=$.iv()
n=$.iw()
m=$.ix()
l=$.iA()
k=$.iB()
j=$.iz()
$.iy()
i=$.iD()
h=$.iC()
g=p.K(s)
if(g!=null)return A.b2(a,A.fZ(A.v(s),g))
else{g=o.K(s)
if(g!=null){g.method="call"
return A.b2(a,A.fZ(A.v(s),g))}else if(n.K(s)!=null||m.K(s)!=null||l.K(s)!=null||k.K(s)!=null||j.K(s)!=null||m.K(s)!=null||i.K(s)!=null||h.K(s)!=null){A.v(s)
return A.b2(a,new A.bP())}}return A.b2(a,new A.cS(typeof s=="string"?s:""))}if(a instanceof RangeError){if(typeof s=="string"&&s.indexOf("call stack")!==-1)return new A.bT()
s=function(b){try{return String(b)}catch(f){}return null}(a)
return A.b2(a,new A.ao(!1,null,null,typeof s=="string"?s.replace(/^RangeError:\s*/,""):s))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof s=="string"&&s==="too much recursion")return new A.bT()
return a},
io(a){if(a==null)return J.a1(a)
if(typeof a=="object")return A.cM(a)
return J.a1(a)},
kl(a,b){var s,r,q,p=a.length
for(s=0;s<p;s=q){r=s+1
q=r+1
b.q(0,a[s],a[r])}return b},
km(a,b){var s,r=a.length
for(s=0;s<r;++s)b.l(0,a[s])
return b},
jS(a,b,c,d,e,f){t.Z.a(a)
switch(A.a0(b)){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.d(new A.fp("Unsupported number of arguments for wrapped closure"))},
kd(a,b){var s=a.$identity
if(!!s)return s
s=A.ke(a,b)
a.$identity=s
return s},
ke(a,b){var s
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
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.jS)},
iR(a2){var s,r,q,p,o,n,m,l,k,j,i=a2.co,h=a2.iS,g=a2.iI,f=a2.nDA,e=a2.aI,d=a2.fs,c=a2.cs,b=d[0],a=c[0],a0=i[b],a1=a2.fT
a1.toString
s=h?Object.create(new A.cP().constructor.prototype):Object.create(new A.b6(null,null).constructor.prototype)
s.$initialize=s.constructor
r=h?function static_tear_off(){this.$initialize()}:function tear_off(a3,a4){this.$initialize(a3,a4)}
s.constructor=r
r.prototype=s
s.$_name=b
s.$_target=a0
q=!h
if(q)p=A.hp(b,a0,g,f)
else{s.$static_name=b
p=a0}s.$S=A.iN(a1,h,g)
s[a]=p
for(o=p,n=1;n<d.length;++n){m=d[n]
if(typeof m=="string"){l=i[m]
k=m
m=l}else k=""
j=c[n]
if(j!=null){if(q)m=A.hp(k,m,g,f)
s[j]=m}if(n===e)o=m}s.$C=o
s.$R=a2.rC
s.$D=a2.dV
return r},
iN(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.d("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.iL)}throw A.d("Error in functionType of tearoff")},
iO(a,b,c,d){var s=A.hn
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,s)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,s)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,s)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,s)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,s)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,s)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,s)}},
hp(a,b,c,d){if(c)return A.iQ(a,b,d)
return A.iO(b.length,d,a,b)},
iP(a,b,c,d){var s=A.hn,r=A.iM
switch(b?-1:a){case 0:throw A.d(new A.cO("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,r,s)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,r,s)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,r,s)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,r,s)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,r,s)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,r,s)
default:return function(e,f,g){return function(){var q=[g(this)]
Array.prototype.push.apply(q,arguments)
return e.apply(f(this),q)}}(d,r,s)}},
iQ(a,b,c){var s,r
if($.hl==null)$.hl=A.hk("interceptor")
if($.hm==null)$.hm=A.hk("receiver")
s=b.length
r=A.iP(s,c,a,b)
return r},
hc(a){return A.iR(a)},
iL(a,b){return A.ca(v.typeUniverse,A.ce(a.a),b)},
hn(a){return a.a},
iM(a){return a.b},
hk(a){var s,r,q,p=new A.b6("receiver","interceptor"),o=Object.getOwnPropertyNames(p)
o.$flags=1
s=o
for(o=s.length,r=0;r<o;++r){q=s[r]
if(p[q]===a)return q}throw A.d(A.dj("Field name "+a+" not found."))},
ik(a){return v.getIsolateTag(a)},
jn(a,b){var s,r
for(s=0;s<a.length;++s){r=a[s]
if(!(s<b.length))return A.a(b,s)
if(!J.an(r,b[s]))return!1}return!0},
kg(a,b){var s=b.length,r=v.rttc[""+s+";"+a]
if(r==null)return null
if(s===0)return r
if(s===r.length)return r.apply(null,b)
return r(b)},
j0(a,b,c,d,e,f){var s=b?"m":"",r=c?"":"i",q=d?"u":"",p=e?"s":"",o=function(g,h){try{return new RegExp(g,h)}catch(n){return n}}(a,s+r+q+p+f)
if(o instanceof RegExp)return o
throw A.d(A.cy("Illegal RegExp pattern ("+String(o)+")",a))},
kx(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
bk:function bk(a){this.a=a},
bu:function bu(a,b){this.a=a
this.$ti=b},
bt:function bt(){},
dN:function dN(a,b,c){this.a=a
this.b=b
this.c=c},
aa:function aa(a,b,c){this.a=a
this.b=b
this.$ti=c},
cA:function cA(){},
b9:function b9(a,b){this.a=a
this.$ti=b},
bR:function bR(){},
f5:function f5(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
bP:function bP(){},
cI:function cI(a,b,c){this.a=a
this.b=b
this.c=c},
cS:function cS(a){this.a=a},
eR:function eR(a){this.a=a},
R:function R(){},
cj:function cj(){},
ck:function ck(){},
cQ:function cQ(){},
cP:function cP(){},
b6:function b6(a,b){this.a=a
this.b=b},
cO:function cO(a){this.a=a},
au:function au(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
eH:function eH(a){this.a=a},
eL:function eL(a,b){this.a=a
this.b=b
this.c=null},
av:function av(a,b){this.a=a
this.$ti=b},
bI:function bI(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
ac:function ac(a,b){this.a=a
this.$ti=b},
bJ:function bJ(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
bG:function bG(a,b){this.a=a
this.$ti=b},
bH:function bH(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
b_:function b_(){},
bj:function bj(){},
cH:function cH(a,b){var _=this
_.a=a
_.b=b
_.e=_.c=null},
fu:function fu(a){this.b=a},
h2(a,b){var s=b.c
return s==null?b.c=A.c8(a,"hw",[b.x]):s},
hQ(a){var s=a.w
if(s===6||s===7)return A.hQ(a.x)
return s===11||s===12},
jb(a){return a.as},
kw(a,b){var s,r=b.length
for(s=0;s<r;++s)if(!a[s].b(b[s]))return!1
return!0},
aF(a){return A.fx(v.typeUniverse,a,!1)},
ks(a,b){var s,r,q,p,o
if(a==null)return null
s=b.y
r=a.Q
if(r==null)r=a.Q=new Map()
q=b.as
p=r.get(q)
if(p!=null)return p
o=A.aO(v.typeUniverse,a.x,s,0)
r.set(q,o)
return o},
aO(a1,a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=a2.w
switch(a0){case 5:case 1:case 2:case 3:case 4:return a2
case 6:s=a2.x
r=A.aO(a1,s,a3,a4)
if(r===s)return a2
return A.i2(a1,r,!0)
case 7:s=a2.x
r=A.aO(a1,s,a3,a4)
if(r===s)return a2
return A.i1(a1,r,!0)
case 8:q=a2.y
p=A.bn(a1,q,a3,a4)
if(p===q)return a2
return A.c8(a1,a2.x,p)
case 9:o=a2.x
n=A.aO(a1,o,a3,a4)
m=a2.y
l=A.bn(a1,m,a3,a4)
if(n===o&&l===m)return a2
return A.h6(a1,n,l)
case 10:k=a2.x
j=a2.y
i=A.bn(a1,j,a3,a4)
if(i===j)return a2
return A.i3(a1,k,i)
case 11:h=a2.x
g=A.aO(a1,h,a3,a4)
f=a2.y
e=A.k7(a1,f,a3,a4)
if(g===h&&e===f)return a2
return A.i0(a1,g,e)
case 12:d=a2.y
a4+=d.length
c=A.bn(a1,d,a3,a4)
o=a2.x
n=A.aO(a1,o,a3,a4)
if(c===d&&n===o)return a2
return A.h7(a1,n,c,!0)
case 13:b=a2.x
if(b<a4)return a2
a=a3[b-a4]
if(a==null)return a2
return a
default:throw A.d(A.ci("Attempted to substitute unexpected RTI kind "+a0))}},
bn(a,b,c,d){var s,r,q,p,o=b.length,n=A.fy(o)
for(s=!1,r=0;r<o;++r){q=b[r]
p=A.aO(a,q,c,d)
if(p!==q)s=!0
n[r]=p}return s?n:b},
k8(a,b,c,d){var s,r,q,p,o,n,m=b.length,l=A.fy(m)
for(s=!1,r=0;r<m;r+=3){q=b[r]
p=b[r+1]
o=b[r+2]
n=A.aO(a,o,c,d)
if(n!==o)s=!0
l.splice(r,3,q,p,n)}return s?l:b},
k7(a,b,c,d){var s,r=b.a,q=A.bn(a,r,c,d),p=b.b,o=A.bn(a,p,c,d),n=b.c,m=A.k8(a,n,c,d)
if(q===r&&o===p&&m===n)return b
s=new A.cW()
s.a=q
s.b=o
s.c=m
return s},
i(a,b){a[v.arrayRti]=b
return a},
fF(a){var s=a.$S
if(s!=null){if(typeof s=="number")return A.kp(s)
return a.$S()}return null},
kr(a,b){var s
if(A.hQ(b))if(a instanceof A.R){s=A.fF(a)
if(s!=null)return s}return A.ce(a)},
ce(a){if(a instanceof A.o)return A.k(a)
if(Array.isArray(a))return A.h(a)
return A.h9(J.b0(a))},
h(a){var s=a[v.arrayRti],r=t.gn
if(s==null)return r
if(s.constructor!==r.constructor)return r
return s},
k(a){var s=a.$ti
return s!=null?s:A.h9(a)},
h9(a){var s=a.constructor,r=s.$ccache
if(r!=null)return r
return A.jQ(a,s)},
jQ(a,b){var s=a instanceof A.R?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,r=A.jx(v.typeUniverse,s.name)
b.$ccache=r
return r},
kp(a){var s,r=v.types,q=r[a]
if(typeof q=="string"){s=A.fx(v.typeUniverse,q,!1)
r[a]=s
return s}return q},
ko(a){return A.aE(A.k(a))},
he(a){var s=A.fF(a)
return A.aE(s==null?A.ce(a):s)},
hb(a){var s
if(a instanceof A.b_)return A.ki(a.$r,a.aO())
s=a instanceof A.R?A.fF(a):null
if(s!=null)return s
if(t.dm.b(a))return J.iI(a).a
if(Array.isArray(a))return A.h(a)
return A.ce(a)},
aE(a){var s=a.r
return s==null?a.r=new A.fw(a):s},
ki(a,b){var s,r,q=b,p=q.length
if(p===0)return t.bQ
if(0>=p)return A.a(q,0)
s=A.ca(v.typeUniverse,A.hb(q[0]),"@<0>")
for(r=1;r<p;++r){if(!(r<q.length))return A.a(q,r)
s=A.i4(v.typeUniverse,s,A.hb(q[r]))}return A.ca(v.typeUniverse,s,a)},
kA(a){return A.aE(A.fx(v.typeUniverse,a,!1))},
jP(a){var s=this
s.b=A.k6(s)
return s.b(a)},
k6(a){var s,r,q,p,o
if(a===t.K)return A.jY
if(A.b1(a))return A.k1
s=a.w
if(s===6)return A.jM
if(s===1)return A.ie
if(s===7)return A.jT
r=A.k5(a)
if(r!=null)return r
if(s===8){q=a.x
if(a.y.every(A.b1)){a.f="$i"+q
if(q==="r")return A.jW
if(a===t.p)return A.jV
return A.k0}}else if(s===10){p=A.kg(a.x,a.y)
o=p==null?A.ie:p
return o==null?A.i8(o):o}return A.jK},
k5(a){if(a.w===8){if(a===t.S)return A.cd
if(a===t.i||a===t.H)return A.jX
if(a===t.N)return A.k_
if(a===t.y)return A.ha}return null},
jO(a){var s=this,r=A.jJ
if(A.b1(s))r=A.jF
else if(s===t.K)r=A.i8
else if(A.bq(s)){r=A.jL
if(s===t.I)r=A.jC
else if(s===t.dk)r=A.i9
else if(s===t.fQ)r=A.jA
else if(s===t.cg)r=A.i7
else if(s===t.cD)r=A.jB
else if(s===t.an)r=A.jE}else if(s===t.S)r=A.a0
else if(s===t.N)r=A.v
else if(s===t.y)r=A.fB
else if(s===t.H)r=A.m
else if(s===t.i)r=A.t
else if(s===t.p)r=A.jD
s.a=r
return s.a(a)},
jK(a){var s=this
if(a==null)return A.bq(s)
return A.il(v.typeUniverse,A.kr(a,s),s)},
jM(a){if(a==null)return!0
return this.x.b(a)},
k0(a){var s,r=this
if(a==null)return A.bq(r)
s=r.f
if(a instanceof A.o)return!!a[s]
return!!J.b0(a)[s]},
jW(a){var s,r=this
if(a==null)return A.bq(r)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
s=r.f
if(a instanceof A.o)return!!a[s]
return!!J.b0(a)[s]},
jV(a){var s=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.o)return!!a[s.f]
return!0}if(typeof a=="function")return!0
return!1},
id(a){if(typeof a=="object"){if(a instanceof A.o)return t.p.b(a)
return!0}if(typeof a=="function")return!0
return!1},
jJ(a){var s=this
if(a==null){if(A.bq(s))return a}else if(s.b(a))return a
throw A.J(A.ia(a,s),new Error())},
jL(a){var s=this
if(a==null||s.b(a))return a
throw A.J(A.ia(a,s),new Error())},
ia(a,b){return new A.bl("TypeError: "+A.hV(a,A.V(b,null)))},
kc(a,b,c,d){if(A.il(v.typeUniverse,a,b))return a
throw A.J(A.jp("The type argument '"+A.V(a,null)+"' is not a subtype of the type variable bound '"+A.V(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
hV(a,b){return A.cx(a)+": type '"+A.V(A.hb(a),null)+"' is not a subtype of type '"+b+"'"},
jp(a){return new A.bl("TypeError: "+a)},
a9(a,b){return new A.bl("TypeError: "+A.hV(a,b))},
jT(a){var s=this
return s.x.b(a)||A.h2(v.typeUniverse,s).b(a)},
jY(a){return a!=null},
i8(a){if(a!=null)return a
throw A.J(A.a9(a,"Object"),new Error())},
k1(a){return!0},
jF(a){return a},
ie(a){return!1},
ha(a){return!0===a||!1===a},
fB(a){if(!0===a)return!0
if(!1===a)return!1
throw A.J(A.a9(a,"bool"),new Error())},
jA(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.J(A.a9(a,"bool?"),new Error())},
t(a){if(typeof a=="number")return a
throw A.J(A.a9(a,"double"),new Error())},
jB(a){if(typeof a=="number")return a
if(a==null)return a
throw A.J(A.a9(a,"double?"),new Error())},
cd(a){return typeof a=="number"&&Math.floor(a)===a},
a0(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.J(A.a9(a,"int"),new Error())},
jC(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.J(A.a9(a,"int?"),new Error())},
jX(a){return typeof a=="number"},
m(a){if(typeof a=="number")return a
throw A.J(A.a9(a,"num"),new Error())},
i7(a){if(typeof a=="number")return a
if(a==null)return a
throw A.J(A.a9(a,"num?"),new Error())},
k_(a){return typeof a=="string"},
v(a){if(typeof a=="string")return a
throw A.J(A.a9(a,"String"),new Error())},
i9(a){if(typeof a=="string")return a
if(a==null)return a
throw A.J(A.a9(a,"String?"),new Error())},
jD(a){if(A.id(a))return a
throw A.J(A.a9(a,"JSObject"),new Error())},
jE(a){if(a==null)return a
if(A.id(a))return a
throw A.J(A.a9(a,"JSObject?"),new Error())},
ig(a,b){var s,r,q
for(s="",r="",q=0;q<a.length;++q,r=", ")s+=r+A.V(a[q],b)
return s},
k4(a,b){var s,r,q,p,o,n,m=a.x,l=a.y
if(""===m)return"("+A.ig(l,b)+")"
s=l.length
r=m.split(",")
q=r.length-s
for(p="(",o="",n=0;n<s;++n,o=", "){p+=o
if(q===0)p+="{"
p+=A.V(l[n],b)
if(q>=0)p+=" "+r[q];++q}return p+"})"},
ib(a3,a4,a5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=", ",a2=null
if(a5!=null){s=a5.length
if(a4==null)a4=A.i([],t.s)
else a2=a4.length
r=a4.length
for(q=s;q>0;--q)B.a.l(a4,"T"+(r+q))
for(p=t._,o="<",n="",q=0;q<s;++q,n=a1){m=a4.length
l=m-1-q
if(!(l>=0))return A.a(a4,l)
o=o+n+a4[l]
k=a5[q]
j=k.w
if(!(j===2||j===3||j===4||j===5||k===p))o+=" extends "+A.V(k,a4)}o+=">"}else o=""
p=a3.x
i=a3.y
h=i.a
g=h.length
f=i.b
e=f.length
d=i.c
c=d.length
b=A.V(p,a4)
for(a="",a0="",q=0;q<g;++q,a0=a1)a+=a0+A.V(h[q],a4)
if(e>0){a+=a0+"["
for(a0="",q=0;q<e;++q,a0=a1)a+=a0+A.V(f[q],a4)
a+="]"}if(c>0){a+=a0+"{"
for(a0="",q=0;q<c;q+=3,a0=a1){a+=a0
if(d[q+1])a+="required "
a+=A.V(d[q+2],a4)+" "+d[q]}a+="}"}if(a2!=null){a4.toString
a4.length=a2}return o+"("+a+") => "+b},
V(a,b){var s,r,q,p,o,n,m,l=a.w
if(l===5)return"erased"
if(l===2)return"dynamic"
if(l===3)return"void"
if(l===1)return"Never"
if(l===4)return"any"
if(l===6){s=a.x
r=A.V(s,b)
q=s.w
return(q===11||q===12?"("+r+")":r)+"?"}if(l===7)return"FutureOr<"+A.V(a.x,b)+">"
if(l===8){p=A.k9(a.x)
o=a.y
return o.length>0?p+("<"+A.ig(o,b)+">"):p}if(l===10)return A.k4(a,b)
if(l===11)return A.ib(a,b,null)
if(l===12)return A.ib(a.x,b,a.y)
if(l===13){n=a.x
m=b.length
n=m-1-n
if(!(n>=0&&n<m))return A.a(b,n)
return b[n]}return"?"},
k9(a){var s=v.mangledGlobalNames[a]
if(s!=null)return s
return"minified:"+a},
jy(a,b){var s=a.tR[b]
while(typeof s=="string")s=a.tR[s]
return s},
jx(a,b){var s,r,q,p,o,n=a.eT,m=n[b]
if(m==null)return A.fx(a,b,!1)
else if(typeof m=="number"){s=m
r=A.c9(a,5,"#")
q=A.fy(s)
for(p=0;p<s;++p)q[p]=r
o=A.c8(a,b,q)
n[b]=o
return o}else return m},
jw(a,b){return A.i5(a.tR,b)},
jv(a,b){return A.i5(a.eT,b)},
fx(a,b,c){var s,r=a.eC,q=r.get(b)
if(q!=null)return q
s=A.hZ(A.hX(a,null,b,!1))
r.set(b,s)
return s},
ca(a,b,c){var s,r,q=b.z
if(q==null)q=b.z=new Map()
s=q.get(c)
if(s!=null)return s
r=A.hZ(A.hX(a,b,c,!0))
q.set(c,r)
return r},
i4(a,b,c){var s,r,q,p=b.Q
if(p==null)p=b.Q=new Map()
s=c.as
r=p.get(s)
if(r!=null)return r
q=A.h6(a,b,c.w===9?c.y:[c])
p.set(s,q)
return q},
aM(a,b){b.a=A.jO
b.b=A.jP
return b},
c9(a,b,c){var s,r,q=a.eC.get(c)
if(q!=null)return q
s=new A.ad(null,null)
s.w=b
s.as=c
r=A.aM(a,s)
a.eC.set(c,r)
return r},
i2(a,b,c){var s,r=b.as+"?",q=a.eC.get(r)
if(q!=null)return q
s=A.jt(a,b,r,c)
a.eC.set(r,s)
return s},
jt(a,b,c,d){var s,r,q
if(d){s=b.w
r=!0
if(!A.b1(b))if(!(b===t.a||b===t.T))if(s!==6)r=s===7&&A.bq(b.x)
if(r)return b
else if(s===1)return t.a}q=new A.ad(null,null)
q.w=6
q.x=b
q.as=c
return A.aM(a,q)},
i1(a,b,c){var s,r=b.as+"/",q=a.eC.get(r)
if(q!=null)return q
s=A.jr(a,b,r,c)
a.eC.set(r,s)
return s},
jr(a,b,c,d){var s,r
if(d){s=b.w
if(A.b1(b)||b===t.K)return b
else if(s===1)return A.c8(a,"hw",[b])
else if(b===t.a||b===t.T)return t.eH}r=new A.ad(null,null)
r.w=7
r.x=b
r.as=c
return A.aM(a,r)},
ju(a,b){var s,r,q=""+b+"^",p=a.eC.get(q)
if(p!=null)return p
s=new A.ad(null,null)
s.w=13
s.x=b
s.as=q
r=A.aM(a,s)
a.eC.set(q,r)
return r},
c7(a){var s,r,q,p=a.length
for(s="",r="",q=0;q<p;++q,r=",")s+=r+a[q].as
return s},
jq(a){var s,r,q,p,o,n=a.length
for(s="",r="",q=0;q<n;q+=3,r=","){p=a[q]
o=a[q+1]?"!":":"
s+=r+p+o+a[q+2].as}return s},
c8(a,b,c){var s,r,q,p=b
if(c.length>0)p+="<"+A.c7(c)+">"
s=a.eC.get(p)
if(s!=null)return s
r=new A.ad(null,null)
r.w=8
r.x=b
r.y=c
if(c.length>0)r.c=c[0]
r.as=p
q=A.aM(a,r)
a.eC.set(p,q)
return q},
h6(a,b,c){var s,r,q,p,o,n
if(b.w===9){s=b.x
r=b.y.concat(c)}else{r=c
s=b}q=s.as+(";<"+A.c7(r)+">")
p=a.eC.get(q)
if(p!=null)return p
o=new A.ad(null,null)
o.w=9
o.x=s
o.y=r
o.as=q
n=A.aM(a,o)
a.eC.set(q,n)
return n},
i3(a,b,c){var s,r,q="+"+(b+"("+A.c7(c)+")"),p=a.eC.get(q)
if(p!=null)return p
s=new A.ad(null,null)
s.w=10
s.x=b
s.y=c
s.as=q
r=A.aM(a,s)
a.eC.set(q,r)
return r},
i0(a,b,c){var s,r,q,p,o,n=b.as,m=c.a,l=m.length,k=c.b,j=k.length,i=c.c,h=i.length,g="("+A.c7(m)
if(j>0){s=l>0?",":""
g+=s+"["+A.c7(k)+"]"}if(h>0){s=l>0?",":""
g+=s+"{"+A.jq(i)+"}"}r=n+(g+")")
q=a.eC.get(r)
if(q!=null)return q
p=new A.ad(null,null)
p.w=11
p.x=b
p.y=c
p.as=r
o=A.aM(a,p)
a.eC.set(r,o)
return o},
h7(a,b,c,d){var s,r=b.as+("<"+A.c7(c)+">"),q=a.eC.get(r)
if(q!=null)return q
s=A.js(a,b,c,r,d)
a.eC.set(r,s)
return s},
js(a,b,c,d,e){var s,r,q,p,o,n,m,l
if(e){s=c.length
r=A.fy(s)
for(q=0,p=0;p<s;++p){o=c[p]
if(o.w===1){r[p]=o;++q}}if(q>0){n=A.aO(a,b,r,0)
m=A.bn(a,c,r,0)
return A.h7(a,n,m,c!==m)}}l=new A.ad(null,null)
l.w=12
l.x=b
l.y=c
l.as=d
return A.aM(a,l)},
hX(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
hZ(a){var s,r,q,p,o,n,m,l=a.r,k=a.s
for(s=l.length,r=0;r<s;){q=l.charCodeAt(r)
if(q>=48&&q<=57)r=A.ji(r+1,q,l,k)
else if((((q|32)>>>0)-97&65535)<26||q===95||q===36||q===124)r=A.hY(a,r,l,k,!1)
else if(q===46)r=A.hY(a,r,l,k,!0)
else{++r
switch(q){case 44:break
case 58:k.push(!1)
break
case 33:k.push(!0)
break
case 59:k.push(A.aZ(a.u,a.e,k.pop()))
break
case 94:k.push(A.ju(a.u,k.pop()))
break
case 35:k.push(A.c9(a.u,5,"#"))
break
case 64:k.push(A.c9(a.u,2,"@"))
break
case 126:k.push(A.c9(a.u,3,"~"))
break
case 60:k.push(a.p)
a.p=k.length
break
case 62:A.jk(a,k)
break
case 38:A.jj(a,k)
break
case 63:p=a.u
k.push(A.i2(p,A.aZ(p,a.e,k.pop()),a.n))
break
case 47:p=a.u
k.push(A.i1(p,A.aZ(p,a.e,k.pop()),a.n))
break
case 40:k.push(-3)
k.push(a.p)
a.p=k.length
break
case 41:A.jh(a,k)
break
case 91:k.push(a.p)
a.p=k.length
break
case 93:o=k.splice(a.p)
A.i_(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-1)
break
case 123:k.push(a.p)
a.p=k.length
break
case 125:o=k.splice(a.p)
A.jm(a.u,a.e,o)
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
return A.aZ(a.u,a.e,m)},
ji(a,b,c,d){var s,r,q=b-48
for(s=c.length;a<s;++a){r=c.charCodeAt(a)
if(!(r>=48&&r<=57))break
q=q*10+(r-48)}d.push(q)
return a},
hY(a,b,c,d,e){var s,r,q,p,o,n,m=b+1
for(s=c.length;m<s;++m){r=c.charCodeAt(m)
if(r===46){if(e)break
e=!0}else{if(!((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124))q=r>=48&&r<=57
else q=!0
if(!q)break}}p=c.substring(b,m)
if(e){s=a.u
o=a.e
if(o.w===9)o=o.x
n=A.jy(s,o.x)[p]
if(n==null)A.b3('No "'+p+'" in "'+A.jb(o)+'"')
d.push(A.ca(s,o,n))}else d.push(p)
return m},
jk(a,b){var s,r=a.u,q=A.hW(a,b),p=b.pop()
if(typeof p=="string")b.push(A.c8(r,p,q))
else{s=A.aZ(r,a.e,p)
switch(s.w){case 11:b.push(A.h7(r,s,q,a.n))
break
default:b.push(A.h6(r,s,q))
break}}},
jh(a,b){var s,r,q,p=a.u,o=b.pop(),n=null,m=null
if(typeof o=="number")switch(o){case-1:n=b.pop()
break
case-2:m=b.pop()
break
default:b.push(o)
break}else b.push(o)
s=A.hW(a,b)
o=b.pop()
switch(o){case-3:o=b.pop()
if(n==null)n=p.sEA
if(m==null)m=p.sEA
r=A.aZ(p,a.e,o)
q=new A.cW()
q.a=s
q.b=n
q.c=m
b.push(A.i0(p,r,q))
return
case-4:b.push(A.i3(p,b.pop(),s))
return
default:throw A.d(A.ci("Unexpected state under `()`: "+A.B(o)))}},
jj(a,b){var s=b.pop()
if(0===s){b.push(A.c9(a.u,1,"0&"))
return}if(1===s){b.push(A.c9(a.u,4,"1&"))
return}throw A.d(A.ci("Unexpected extended operation "+A.B(s)))},
hW(a,b){var s=b.splice(a.p)
A.i_(a.u,a.e,s)
a.p=b.pop()
return s},
aZ(a,b,c){if(typeof c=="string")return A.c8(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.jl(a,b,c)}else return c},
i_(a,b,c){var s,r=c.length
for(s=0;s<r;++s)c[s]=A.aZ(a,b,c[s])},
jm(a,b,c){var s,r=c.length
for(s=2;s<r;s+=3)c[s]=A.aZ(a,b,c[s])},
jl(a,b,c){var s,r,q=b.w
if(q===9){if(c===0)return b.x
s=b.y
r=s.length
if(c<=r)return s[c-1]
c-=r
b=b.x
q=b.w}else if(c===0)return b
if(q!==8)throw A.d(A.ci("Indexed base must be an interface type"))
s=b.y
if(c<=s.length)return s[c-1]
throw A.d(A.ci("Bad index "+c+" for "+b.j(0)))},
il(a,b,c){var s,r=b.d
if(r==null)r=b.d=new Map()
s=r.get(c)
if(s==null){s=A.H(a,b,null,c,null)
r.set(c,s)}return s},
H(a,b,c,d,e){var s,r,q,p,o,n,m,l,k,j,i
if(b===d)return!0
if(A.b1(d))return!0
s=b.w
if(s===4)return!0
if(A.b1(b))return!1
if(b.w===1)return!0
r=s===13
if(r)if(A.H(a,c[b.x],c,d,e))return!0
q=d.w
p=t.a
if(b===p||b===t.T){if(q===7)return A.H(a,b,c,d.x,e)
return d===p||d===t.T||q===6}if(d===t.K){if(s===7)return A.H(a,b.x,c,d,e)
return s!==6}if(s===7){if(!A.H(a,b.x,c,d,e))return!1
return A.H(a,A.h2(a,b),c,d,e)}if(s===6)return A.H(a,p,c,d,e)&&A.H(a,b.x,c,d,e)
if(q===7){if(A.H(a,b,c,d.x,e))return!0
return A.H(a,b,c,A.h2(a,d),e)}if(q===6)return A.H(a,b,c,p,e)||A.H(a,b,c,d.x,e)
if(r)return!1
p=s!==11
if((!p||s===12)&&d===t.Z)return!0
o=s===10
if(o&&d===t.gT)return!0
if(q===12){if(b===t.cj)return!0
if(s!==12)return!1
n=b.y
m=d.y
l=n.length
if(l!==m.length)return!1
c=c==null?n:n.concat(c)
e=e==null?m:m.concat(e)
for(k=0;k<l;++k){j=n[k]
i=m[k]
if(!A.H(a,j,c,i,e)||!A.H(a,i,e,j,c))return!1}return A.ic(a,b.x,c,d.x,e)}if(q===11){if(b===t.cj)return!0
if(p)return!1
return A.ic(a,b,c,d,e)}if(s===8){if(q!==8)return!1
return A.jU(a,b,c,d,e)}if(o&&q===10)return A.jZ(a,b,c,d,e)
return!1},
ic(a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
if(!A.H(a3,a4.x,a5,a6.x,a7))return!1
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
if(!A.H(a3,p[h],a7,g,a5))return!1}for(h=0;h<m;++h){g=l[h]
if(!A.H(a3,p[o+h],a7,g,a5))return!1}for(h=0;h<i;++h){g=l[m+h]
if(!A.H(a3,k[h],a7,g,a5))return!1}f=s.c
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
if(!A.H(a3,e[a+2],a7,g,a5))return!1
break}}while(b<d){if(f[b+1])return!1
b+=3}return!0},
jU(a,b,c,d,e){var s,r,q,p,o,n=b.x,m=d.x
while(n!==m){s=a.tR[n]
if(s==null)return!1
if(typeof s=="string"){n=s
continue}r=s[m]
if(r==null)return!1
q=r.length
p=q>0?new Array(q):v.typeUniverse.sEA
for(o=0;o<q;++o)p[o]=A.ca(a,b,r[o])
return A.i6(a,p,null,c,d.y,e)}return A.i6(a,b.y,null,c,d.y,e)},
i6(a,b,c,d,e,f){var s,r=b.length
for(s=0;s<r;++s)if(!A.H(a,b[s],d,e[s],f))return!1
return!0},
jZ(a,b,c,d,e){var s,r=b.y,q=d.y,p=r.length
if(p!==q.length)return!1
if(b.x!==d.x)return!1
for(s=0;s<p;++s)if(!A.H(a,r[s],c,q[s],e))return!1
return!0},
bq(a){var s=a.w,r=!0
if(!(a===t.a||a===t.T))if(!A.b1(a))if(s!==6)r=s===7&&A.bq(a.x)
return r},
b1(a){var s=a.w
return s===2||s===3||s===4||s===5||a===t._},
i5(a,b){var s,r,q=Object.keys(b),p=q.length
for(s=0;s<p;++s){r=q[s]
a[r]=b[r]}},
fy(a){return a>0?new Array(a):v.typeUniverse.sEA},
ad:function ad(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
cW:function cW(){this.c=this.b=this.a=null},
fw:function fw(a){this.a=a},
cV:function cV(){},
bl:function bl(a){this.a=a},
hC(a,b){return new A.au(a.h("@<0>").u(b).h("au<1,2>"))},
L(a,b,c){return b.h("@<0>").u(c).h("hB<1,2>").a(A.kl(a,new A.au(b.h("@<0>").u(c).h("au<1,2>"))))},
a8(a,b){return new A.au(a.h("@<0>").u(b).h("au<1,2>"))},
hE(a){return new A.aD(a.h("aD<0>"))},
h_(a){return new A.aD(a.h("aD<0>"))},
j3(a,b){return b.h("hD<0>").a(A.km(a,new A.aD(b.h("aD<0>"))))},
h5(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
jg(a,b,c){var s=new A.aY(a,b,c.h("aY<0>"))
s.c=a.e
return s},
j2(a,b,c){var s=A.hC(b,c)
a.J(0,new A.eM(s,b,c))
return s},
hF(a,b){var s=A.hE(b)
s.A(0,a)
return s},
eP(a){var s,r
if(A.hf(a))return"{...}"
s=new A.bg("")
try{r={}
B.a.l($.a7,a)
s.a+="{"
r.a=!0
a.J(0,new A.eQ(r,s))
s.a+="}"}finally{if(0>=$.a7.length)return A.a($.a7,-1)
$.a7.pop()}r=s.a
return r.charCodeAt(0)==0?r:r},
j4(a){return 8},
jz(){throw A.d(A.f7("Cannot change an unmodifiable set"))},
aD:function aD(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
cZ:function cZ(a){this.a=a
this.b=null},
aY:function aY(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
eM:function eM(a,b,c){this.a=a
this.b=b
this.c=c},
P:function P(){},
eQ:function eQ(a,b){this.a=a
this.b=b},
cb:function cb(){},
be:function be(){},
bZ:function bZ(){},
bK:function bK(a,b){var _=this
_.a=a
_.d=_.c=_.b=0
_.$ti=b},
c4:function c4(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=null
_.$ti=e},
aX:function aX(){},
c6:function c6(){},
d_:function d_(){},
c_:function c_(a,b){this.a=a
this.$ti=b},
bm:function bm(){},
cc:function cc(){},
k3(a,b){var s,r,q,p=null
try{p=JSON.parse(a)}catch(r){s=A.hg(r)
q=A.cy(String(s),null)
throw A.d(q)}q=A.fC(p)
return q},
fC(a){var s
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.cX(a,Object.create(null))
for(s=0;s<a.length;++s)a[s]=A.fC(a[s])
return a},
hA(a,b,c){return new A.bE(a,b)},
jH(a){return a.cK()},
je(a,b){return new A.fr(a,[],A.kf())},
jf(a,b,c){var s,r=new A.bg(""),q=A.je(r,b)
q.af(a)
s=r.a
return s.charCodeAt(0)==0?s:s},
cX:function cX(a,b){this.a=a
this.b=b
this.c=null},
cY:function cY(a){this.a=a},
cl:function cl(){},
cp:function cp(){},
bE:function bE(a,b){this.a=a
this.b=b},
cJ:function cJ(a,b){this.a=a
this.b=b},
eI:function eI(){},
eK:function eK(a){this.b=a},
eJ:function eJ(a){this.a=a},
fs:function fs(){},
ft:function ft(a,b){this.a=a
this.b=b},
fr:function fr(a,b,c){this.c=a
this.a=b
this.b=c},
d0(a){var s=A.j7(a,null)
if(s!=null)return s
throw A.d(A.cy(a,null))},
bL(a,b,c,d){var s,r=J.hz(a,d)
if(a!==0&&b!=null)for(s=0;s<a;++s)r[s]=b
return r},
h0(a,b,c){var s,r=A.i([],c.h("l<0>"))
for(s=J.W(a);s.n();)B.a.l(r,c.a(s.gp()))
if(b)return r
r.$flags=1
return r},
q(a,b){var s,r
if(Array.isArray(a))return A.i(a.slice(0),b.h("l<0>"))
s=A.i([],b.h("l<0>"))
for(r=J.W(a);r.n();)B.a.l(s,r.gp())
return s},
T(a,b){var s=A.h0(a,!1,b)
s.$flags=3
return s},
ja(a){return new A.cH(a,A.j0(a,!1,!0,!1,!1,""))},
hS(a,b,c){var s=J.W(b)
if(!s.n())return a
if(c.length===0){do a+=A.B(s.gp())
while(s.n())}else{a+=A.B(s.gp())
while(s.n())a=a+c+A.B(s.gp())}return a},
iT(a,b,c,d,e,f,g,h,i){var s=A.hO(a,b,c,d,e,f,g,h,i)
if(s==null)return null
return new A.ah(A.ht(s,h,i),h,i)},
iS(a){var s=A.hO(a,1,1,0,0,0,0,0,!0)
return new A.ah(s==null?new A.dW(a,1,1,0,0,0,0,0).$0():s,0,!0)},
dY(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=$.it().cp(a)
if(c!=null){s=new A.dZ()
r=c.b
if(1>=r.length)return A.a(r,1)
q=r[1]
q.toString
p=A.d0(q)
if(2>=r.length)return A.a(r,2)
q=r[2]
q.toString
o=A.d0(q)
if(3>=r.length)return A.a(r,3)
q=r[3]
q.toString
n=A.d0(q)
if(4>=r.length)return A.a(r,4)
m=s.$1(r[4])
if(5>=r.length)return A.a(r,5)
l=s.$1(r[5])
if(6>=r.length)return A.a(r,6)
k=s.$1(r[6])
if(7>=r.length)return A.a(r,7)
j=new A.e_().$1(r[7])
i=B.c.B(j,1000)
q=r.length
if(8>=q)return A.a(r,8)
h=r[8]!=null
if(h){if(9>=q)return A.a(r,9)
g=r[9]
if(g!=null){f=g==="-"?-1:1
if(10>=q)return A.a(r,10)
q=r[10]
q.toString
e=A.d0(q)
if(11>=r.length)return A.a(r,11)
l-=f*(s.$1(r[11])+60*e)}}d=A.iT(p,o,n,m,l,k,i,j%1000,h)
if(d==null)throw A.d(A.cy("Time out of range",a))
return d}else throw A.d(A.cy("Invalid date format",a))},
ht(a,b,c){var s="microsecond"
if(b<0||b>999)throw A.d(A.ak(b,0,999,s,null))
if(a<-864e13||a>864e13)throw A.d(A.ak(a,-864e13,864e13,"millisecondsSinceEpoch",null))
if(a===864e13&&b!==0)throw A.d(A.iK(b,s,"Time including microseconds is outside valid range"))
A.ii(c,"isUtc",t.y)
return a},
hs(a){var s=Math.abs(a),r=a<0?"-":""
if(s>=1000)return""+a
if(s>=100)return r+"0"+s
if(s>=10)return r+"00"+s
return r+"000"+s},
iU(a){var s=Math.abs(a),r=a<0?"-":"+"
if(s>=1e5)return r+s
return r+"0"+s},
dX(a){if(a>=100)return""+a
if(a>=10)return"0"+a
return"00"+a},
ar(a){if(a>=10)return""+a
return"0"+a},
G(a,b){return new A.S(a+1000*b)},
cx(a){if(typeof a=="number"||A.ha(a)||a==null)return J.b5(a)
if(typeof a=="string")return JSON.stringify(a)
return A.hN(a)},
ci(a){return new A.ch(a)},
dj(a){return new A.ao(!1,null,null,a)},
iK(a,b,c){return new A.ao(!0,a,b,c)},
dk(a,b,c){return a},
j8(a,b){return new A.bQ(null,null,!0,a,b,"Value not in range")},
ak(a,b,c,d,e){return new A.bQ(b,c,!0,a,d,"Invalid value")},
hP(a,b,c){if(0>a||a>c)throw A.d(A.ak(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.d(A.ak(b,a,c,"end",null))
return b}return c},
ax(a,b){if(a<0)throw A.d(A.ak(a,0,null,b,null))
return a},
eE(a,b,c,d,e){return new A.cz(b,!0,a,e,"Index out of range")},
f7(a){return new A.c0(a)},
jc(a){return new A.bf(a)},
O(a){return new A.co(a)},
cy(a,b){return new A.eD(a,b)},
iZ(a,b,c){var s,r
if(A.hf(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}s=A.i([],t.s)
B.a.l($.a7,a)
try{A.k2(a,s)}finally{if(0>=$.a7.length)return A.a($.a7,-1)
$.a7.pop()}r=A.hS(b,t.hf.a(s),", ")+c
return r.charCodeAt(0)==0?r:r},
fX(a,b,c){var s,r
if(A.hf(a))return b+"..."+c
s=new A.bg(b)
B.a.l($.a7,a)
try{r=s
r.a=A.hS(r.a,a,", ")}finally{if(0>=$.a7.length)return A.a($.a7,-1)
$.a7.pop()}s.a+=c
r=s.a
return r.charCodeAt(0)==0?r:r},
k2(a,b){var s,r,q,p,o,n,m,l=a.gt(a),k=0,j=0
for(;;){if(!(k<80||j<3))break
if(!l.n())return
s=A.B(l.gp())
B.a.l(b,s)
k+=s.length+2;++j}if(!l.n()){if(j<=5)return
if(0>=b.length)return A.a(b,-1)
r=b.pop()
if(0>=b.length)return A.a(b,-1)
q=b.pop()}else{p=l.gp();++j
if(!l.n()){if(j<=4){B.a.l(b,A.B(p))
return}r=A.B(p)
if(0>=b.length)return A.a(b,-1)
q=b.pop()
k+=r.length+2}else{o=l.gp();++j
for(;l.n();p=o,o=n){n=l.gp();++j
if(j>100){for(;;){if(!(k>75&&j>3))break
if(0>=b.length)return A.a(b,-1)
k-=b.pop().length+2;--j}B.a.l(b,"...")
return}}q=A.B(p)
r=A.B(o)
k+=r.length+q.length+4}}if(j>b.length+2){k+=5
m="..."}else m=null
for(;;){if(!(k>80&&b.length>3))break
if(0>=b.length)return A.a(b,-1)
k-=b.pop().length+2
if(m==null){k+=5
m="..."}}if(m!=null)B.a.l(b,m)
B.a.l(b,q)
B.a.l(b,r)},
h1(a,b,c,d){var s
if(B.d===c){s=J.a1(a)
b=J.a1(b)
return A.eU(A.az(A.az($.d4(),s),b))}if(B.d===d){s=J.a1(a)
b=J.a1(b)
c=J.a1(c)
return A.eU(A.az(A.az(A.az($.d4(),s),b),c))}s=J.a1(a)
b=J.a1(b)
c=J.a1(c)
d=J.a1(d)
d=A.eU(A.az(A.az(A.az(A.az($.d4(),s),b),c),d))
return d},
j6(a){var s,r,q=$.d4()
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.D)(a),++r)q=A.az(q,J.a1(a[r]))
return A.eU(q)},
dW:function dW(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
ah:function ah(a,b,c){this.a=a
this.b=b
this.c=c},
dZ:function dZ(){},
e_:function e_(){},
S:function S(a){this.a=a},
fo:function fo(){},
A:function A(){},
ch:function ch(a){this.a=a},
bY:function bY(){},
ao:function ao(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bQ:function bQ(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
cz:function cz(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
c0:function c0(a){this.a=a},
bf:function bf(a){this.a=a},
co:function co(a){this.a=a},
cK:function cK(){},
bT:function bT(){},
fp:function fp(a){this.a=a},
eD:function eD(a,b){this.a=a
this.b=b},
c:function c(){},
M:function M(a,b,c){this.a=a
this.b=b
this.$ti=c},
aV:function aV(){},
o:function o(){},
bg:function bg(a){this.a=a},
d5:function d5(){},
dd:function dd(a){this.a=a},
de:function de(){},
df:function df(a){this.a=a},
dg:function dg(a,b){this.a=a
this.b=b},
dh:function dh(a,b){this.a=a
this.b=b},
d6:function d6(){},
d8:function d8(){},
d7:function d7(a){this.a=a},
d9:function d9(a,b){this.a=a
this.b=b},
da:function da(){},
dc:function dc(){},
db:function db(a){this.a=a},
iJ(a,b,c,d){var s,r,q,p,o,n,m,l,k=a.Q
if(!k||!a.ax||a.c!==c)return null
s=a.e
r=Math.max(s,d)
q=a.f
p=Math.min(q,b)
o=q-s
s=p-r
if(s<=0.01||o<=0.01)return null
q=new A.di(a,o)
n=q.$1(r)
m=q.$1(p)
l=Math.min(s,m-n)
return A.hq(l,a.y,a.x,l>=3000,k,a.a,p,a.c,r,a.as,a.ax,a.ay,a.b,m,a.d,n)},
di:function di(a,b){this.a=a
this.b=b},
z:function z(a,b,c,d,e,f,g,h,i,j,k,l,m,n){var _=this
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
_.at=n},
dm:function dm(){},
dE:function dE(){},
dF:function dF(){},
dp:function dp(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dn:function dn(a){this.a=a},
dq:function dq(){},
dr:function dr(a){this.a=a},
du:function du(a){this.a=a},
dv:function dv(){},
dy:function dy(){},
dz:function dz(a,b){this.a=a
this.b=b},
dx:function dx(a){this.a=a},
dA:function dA(){},
dB:function dB(){},
dt:function dt(a){this.a=a},
ds:function ds(a){this.a=a},
dC:function dC(){},
dD:function dD(){},
dw:function dw(a){this.a=a},
aN:function aN(a,b){this.a=a
this.b=b},
al:function al(a,b,c){this.a=a
this.b=b
this.c=c},
dG:function dG(a,b,c,d){var _=this
_.a=a
_.f=b
_.r=c
_.z=d},
dl:function dl(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
F:function F(a,b,c,d,e,f,g,h,i,j,k,l,m){var _=this
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
_.as=m},
dH:function dH(){},
dI:function dI(){},
hq(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p){return new A.cm(f,m,h,o,i,g,p,n,c,b,a,e,j,d,k,l)},
cm:function cm(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p){var _=this
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
ap:function ap(a,b){this.a=a
this.b=b},
cn:function cn(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.r=c
_.w=d
_.x=e
_.y=f},
bs:function bs(a,b){this.a=a
this.b=b},
aq:function aq(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
dM:function dM(a,b){this.a=a
this.b=b},
jN(a,b){var s
if(!isFinite(a)||a<0||a>=360)return null
s=B.b.X(Math.abs(a-b),360)
return s>180?360-s:s},
dJ:function dJ(){},
dK:function dK(){},
dL:function dL(){},
c5:function c5(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.r=_.f=$},
af:function af(a,b,c){this.a=a
this.b=b
this.c=c},
fq:function fq(a,b,c){this.a=a
this.b=b
this.c=c},
cr:function cr(){},
dT:function dT(a,b){this.a=a
this.b=b},
dU:function dU(){},
dV:function dV(){},
dP:function dP(){},
dQ:function dQ(){},
dR:function dR(){},
dS:function dS(){},
dO:function dO(){},
cq:function cq(a,b,c){this.a=a
this.y=b
this.z=c},
ag:function ag(a,b,c,d,e,f,g){var _=this
_.e=a
_.r=b
_.w=c
_.x=d
_.y=e
_.z=f
_.Q=g},
e0:function e0(){},
ct:function ct(){},
e4:function e4(){},
e3:function e3(){},
e5:function e5(a,b){this.a=a
this.b=b},
eg:function eg(){},
ef:function ef(){},
eh:function eh(a){this.a=a},
ej:function ej(){},
ei:function ei(){},
ek:function ek(a){this.a=a},
el:function el(){},
e6:function e6(){},
em:function em(){},
e7:function e7(a,b){this.a=a
this.b=b},
e8:function e8(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
e9:function e9(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
ea:function ea(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
eb:function eb(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
ec:function ec(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
ed:function ed(){},
ee:function ee(a){this.a=a},
e2:function e2(a,b){this.a=a
this.b=b},
a6:function a6(a,b){this.a=a
this.b=b},
en:function en(a,b){this.a=a
this.b=b},
eo:function eo(){},
eq:function eq(){},
ep:function ep(){},
cB:function cB(){},
eF:function eF(){},
er:function er(){},
es:function es(){},
bv:function bv(a,b){this.a=a
this.b=b},
K:function K(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
aG:function aG(a,b){this.b=a
this.c=b},
cu:function cu(a,b,c,d,e,f,g,h,i,j){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j},
hu(a){var s
if(a.gaB()){s=a.r
s=isFinite(s)&&s>=0&&s<=30}else s=!1
return s},
iX(a){var s=a.Q
if(s!=="unavailable"&&s!=="held_estimate"){s=a.d
s=isFinite(s)&&s>=0&&s<=70}else s=!1
return s},
b7(a,b){var s,r=b.c.S(a.c),q=!1
if(A.hu(a))if(A.hu(b))if(!b.y)if(b.z===0){s=r.a
if(s>=2e5)if(s<=15e6){q=b.w
q=isFinite(q)&&q>=0}}return q},
iV(a){var s,r,q,p=A.i([],t.J)
for(s=0;r=a.length,s<r;++s){if(s!==0){q=s-1
if(!(q>=0))return A.a(a,q)
q=A.b7(a[q],a[s])
r=q}else r=!0
q=a.length
if(r){if(!(s<q))return A.a(a,s)
p.push(a[s])}else{if(!(s<q))return A.a(a,s)
r=a[s]
p.push(new A.F(r.a,r.b,r.c,r.d,r.e,r.f,r.r,0,0,!0,r.z,r.Q,!1))}}return p},
eu(a,b,c){var s,r,q,p
for(s=a+1;s<=b;++s){r=s-1
q=!0
if(A.b7(c.$1(r),c.$1(s))){r=c.$1(r)
p=r.Q
if(p!=="unavailable"&&p!=="held_estimate"){r=r.d
r=isFinite(r)&&r>=0&&r<=70}else r=!1
if(r){r=c.$1(s)
q=r.Q
if(q!=="unavailable"&&q!=="held_estimate"){r=r.d
r=isFinite(r)&&r>=0&&r<=70}else r=!1
r=!r}else r=q}else r=q
if(r)return!1}return!0},
iW(a8,a9){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4=a9.i(0,"startedAtMicros"),a5=a9.i(0,"stopRequestedAtMicros"),a6=A.cd(a4)&&A.cd(a5)&&a5>a4,a7=A.h_(t.S)
for(s=t.dC,r=0,q=0,p=0,o=0,n=0,m=!1,l=0,k=0,j=!0,i=1;i<a8.length;++i){h=i-1
g=a8[h]
f=a8[i]
e=f.c
d=g.c
c=e.a
b=d.a
if(c<=b)a=c===b&&e.b>d.b
else a=!0
if(!a)j=!1
if(A.b7(g,f))if(a6)a=1000*b+d.b<a4||1000*c+e.b>a5
else a=!1
else a=!0
a0=0
a1=!1
if(a){m=a1
n=a0
continue}a2=A.G(e.b-d.b,c-b).a
r+=a2
e=f.w
l+=e
d=g.Q
c=d!=="unavailable"
if(c&&d!=="held_estimate"){b=g.d
b=isFinite(b)&&b>=0&&b<=70}else b=!1
if(b){b=f.Q
if(b!=="unavailable"&&b!=="held_estimate"){b=f.d
b=isFinite(b)&&b>=0&&b<=70}else b=!1
b=b&&g.d>1.5&&f.d>1.5}else b=!1
if(b){q+=a2
k+=e
a7.A(0,A.i([h,i],s))}if(c&&d!=="held_estimate"){h=g.d
h=isFinite(h)&&h>=0&&h<=70}else h=!1
if(h){h=f.Q
if(h!=="unavailable"&&h!=="held_estimate"){h=f.d
h=isFinite(h)&&h>=0&&h<=70}else h=!1
h=h&&g.d<=1.5&&f.d<=1.5}else h=!1
if(h){p+=a2
n+=a2
if(!m&&n>=3e6){++o
m=!0}}else{m=a1
n=a0}}a3=a6&&j&&r<=a5-a4?a5-a4:null
return new A.et(a3,r,q,a7.a)},
et:function et(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.e=d},
hv(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s){return new A.p(h,d,s,o,e,q,g,p,f,i,k,c,a,r,n,m,b,l,j)},
ai:function ai(a,b){this.a=a
this.b=b},
bh:function bh(a,b){this.a=a
this.b=b},
aS:function aS(a,b){this.a=a
this.b=b},
aH:function aH(a,b){this.a=a
this.b=b},
X:function X(a,b){this.a=a
this.b=b},
a5:function a5(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.d=c
_.e=d
_.f=e
_.r=f},
aA:function aA(a,b,c){this.a=a
this.c=b
this.d=c},
as:function as(a,b,c){this.a=a
this.b=b
this.c=c},
p:function p(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s){var _=this
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
cs:function cs(a,b,c,d){var _=this
_.a=a
_.c=b
_.d=c
_.r=d},
e1:function e1(a){this.a=a},
ev:function ev(){},
ew:function ew(){},
ey:function ey(){},
ex:function ex(a){this.a=a},
ez:function ez(){},
eA:function eA(){},
eB:function eB(){},
eC:function eC(){},
cw:function cw(a,b,c){this.a=a
this.f=b
this.r=c},
cv:function cv(a,b,c){this.a=a
this.b=b
this.c=c},
cg:function cg(a,b,c){this.a=a
this.e=b
this.f=c},
aj:function aj(a,b){this.a=a
this.b=b},
ab:function ab(a,b){this.a=a
this.e=b},
cR:function cR(a,b,c){this.a=a
this.e=b
this.f=c},
bd:function bd(a,b){this.a=a
this.b=b},
bM:function bM(a,b){this.a=a
this.b=b},
aJ:function aJ(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
Y:function Y(a,b,c,d,e,f,g,h,i,j,k,l,m){var _=this
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
_.as=m},
bN:function bN(a,b,c){this.a=a
this.c=b
this.d=c},
eN:function eN(a){this.a=a},
eO:function eO(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
fA:function fA(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.w=1},
Z:function Z(a,b){this.a=a
this.b=b},
U:function U(a,b,c){this.a=a
this.b=b
this.c=c},
eV:function eV(){},
fz:function fz(a,b){this.a=a
this.b=b},
bX:function bX(a,b,c){this.a=a
this.r=b
this.as=c},
bW:function bW(a){this.a=a},
eW:function eW(){},
f_:function f_(a){this.a=a},
f1:function f1(a){this.a=a},
f2:function f2(a){this.a=a},
f3:function f3(){},
f4:function f4(){},
f0:function f0(a){this.a=a},
eY:function eY(){},
eZ:function eZ(){},
eX:function eX(a){this.a=a},
f8:function f8(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.x=f
_.y=g
_.Q=h},
f9:function f9(a,b){this.a=a
this.f=b},
jo(a,b,c){return new A.E(a.c,a.b,a.d,a.r,b,c)},
cT:function cT(){},
fg:function fg(){},
fh:function fh(a){this.a=a},
fi:function fi(a,b){this.a=a
this.b=b},
fj:function fj(a){this.a=a},
fk:function fk(a,b,c){this.a=a
this.b=b
this.c=c},
fl:function fl(){},
fm:function fm(a,b,c){this.a=a
this.b=b
this.c=c},
fd:function fd(){},
fe:function fe(){},
fc:function fc(a){this.a=a},
ff:function ff(a){this.a=a},
fa:function fa(){},
fb:function fb(){},
am:function am(a,b,c){this.a=a
this.b=b
this.c=c},
C:function C(a,b){this.a=a
this.b=b},
E:function E(a,b,c,d,e,f){var _=this
_.c=a
_.d=b
_.e=c
_.f=d
_.a=e
_.b=f},
a_:function a_(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
fn:function fn(a,b,c){this.a=a
this.b=b
this.c=c},
cU:function cU(a,b,c){this.a=a
this.c=b
this.d=c},
kv(a){t.E.a(a)
return A.L(["id",a.a,"sourceDriveId",a.b,"validatedRoadId",a.c,"matchedSectionId",a.d,"startOffsetMeters",B.b.j(a.e),"endOffsetMeters",B.b.j(a.f),"directionKey",a.r,"minLatitude",B.b.j(a.w),"maxLatitude",B.b.j(a.x),"minLongitude",B.b.j(a.y),"maxLongitude",B.b.j(a.z),"processingVersion",a.at,"createdAt",a.Q.O().aE(),"updatedAt",a.as.O().aE()],t.N,t.z)},
kj(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=A.dY(A.v(a.i(0,"now"))),e=t.j,d=t.E,c=J.b4(e.a(a.i(0,"traces")),new A.fJ(),d),b=A.q(c,c.$ti.h("n.E"))
c=t.N
d=A.a8(c,d)
for(s=b.length,r=0;r<b.length;b.length===s||(0,A.D)(b),++r){q=b[r]
d.q(0,q.a,q)}s=t.bI
d=J.b4(e.a(a.i(0,"inputs")),new A.fK(d),s)
p=A.q(d,d.$ti.h("n.E"))
o=A.a8(c,s)
for(e=p.length,d=t.r,s=t.A,r=0;r<p.length;p.length===e||(0,A.D)(p),++r){n=p[r]
m=n.a
l=m.a
k=o.i(0,l)
j=A.i([],s)
i=k==null
h=i?null:k.b
if(h!=null)B.a.A(j,h)
B.a.A(j,n.b)
h=A.i([],d)
i=i?null:k.c
if(i!=null)B.a.A(h,i)
B.a.A(h,n.c)
o.q(0,l,new A.aL(m,j,h))}e=A.d1(t.P.a(a.i(0,"challenger")))
d=o.$ti.h("ac<2>")
d=A.q(new A.ac(o,d),d.h("c.E"))
g=B.aa.cz(e,new A.cU(0,b,B.S),f,d)
e=g.f.c
d=A.h(e)
s=d.h("f<1,u<e,@>>")
e=A.q(new A.f(e,d.h("u<e,@>(1)").a(A.kB()),s),s.h("n.E"))
return A.L(["operationId",g.a,"traces",e],c,t.z)},
fJ:function fJ(){},
fK:function fK(a){this.a=a},
fI:function fI(a){this.a=a},
kh(a){var s=A.hd(t.P.a(a.i(0,"match"))),r=A.v(a.i(0,"sectionId")),q=A.m(a.i(0,"start")),p=A.iJ(s,A.m(a.i(0,"end")),r,q)
if(p==null)return null
return A.L(["firstStartOffsetMeters",p.e,"firstEndOffsetMeters",p.f,"secondStartOffsetMeters",p.r,"secondEndOffsetMeters",p.w,"commonDistanceMeters",p.z,"comparisonEligible",p.at],t.N,t.z)},
d1(a){var s,r,q,p,o,n=J.b4(t.j.a(a.i(0,"sections")),new A.fP(),t.o),m=A.q(n,n.$ti.h("n.E"))
A.iS(1970)
n=A.v(a.i(0,"id"))
s=A.v(a.i(0,"driveId"))
r=A.h(m)
q=r.h("bz<1,Z>")
r=A.q(new A.bz(m,r.h("c<Z>(1)").a(new A.fQ()),q),q.h("c.E"))
q=B.a.G(m,0,new A.fR(),t.i)
p=a.i(0,"processingVersion")
p=A.a0(p==null?3:p)
o=a.i(0,"directionKey")
return new A.f8(n,s,r,m,q,null,p,A.v(o==null?"":o))},
d2(a){var s=J.b4(a,new A.fV(),t.u)
s=A.q(s,s.$ti.h("n.E"))
return s},
ip(a){var s,r,q=t.N,p=t.z
if(a==null)q=A.a8(q,p)
else{s=A.a8(q,p)
s.q(0,"totalScore",a.d)
s.q(0,"displayScore",a.f)
s.q(0,"algorithmVersion",a.r)
r=a.a
if(r==="reliable_intervals")s.A(0,A.L(["calculationMode",r,"calculationVersion",a.b,"reliabilityPolicyVersion",a.c],q,p))
s.q(0,"overallConfidence",a.e)
p=t.h6
s.q(0,"categories",a.w.a6(0,new A.fS(),q,p))
s.q(0,"contributions",a.x.a6(0,new A.fT(),q,p))
q=s}return q},
ij(a){var s,r=a.e
r=r==null?null:A.ip(r)
s=a.f
s=s==null?null:A.ip(s)
return A.L(["outcome",a.x.b,"comparisonValid",a.y,"firstLocalScore",r,"secondLocalScore",s,"scoreDifference",a.r,"relativeDifference",a.w],t.N,t.z)},
cf(a){var s=a.b,r=A.h(s),q=r.h("f<1,e>")
r=A.q(new A.f(s,r.h("e(1)").a(new A.fU()),q),q.h("n.E"))
return A.L(["status",a.a.b,"startIndex",a.c,"endIndex",a.d,"count",s.length,"mappingConfidence",a.e,"timestamps",r],t.N,t.z)},
kk(a){var s,r,q,p,o,n,m,l,k,j,i="operation",h="startedAtMicros",g="stopRequestedAtMicros",f="firstTelemetry",e="firstRoad",d="secondRoad",c="secondTelemetry"
if(J.an(a.i(0,i),"reliableEligibility")){s=a.i(0,"telemetryReliability")
if(!t.P.b(s)||!J.an(s.i(0,"reliabilityPolicyVersion"),1)||!A.cd(s.i(0,h))||!A.cd(s.i(0,g)))return A.L(["status","invalidReliabilityMetadata","scoreEligible",!1],t.N,t.z)
r=t.N
q=t.z
p=A.iW(A.d2(t.j.a(a.i(0,f))),A.L(["startedAtMicros",s.i(0,h),g,s.i(0,g)],r,q))
o=p.gb4()&&p.gb9()
n=p.gb4()
m=p.gb9()
l=p.a
return A.L(["status","evaluated","scoreEligible",o,"coverageSufficient",n,"movementSufficient",m,"coverage",l!=null&&l>0?p.b/l:null],r,q)}if(!J.an(a.i(0,"algorithmVersion"),1))return A.L(["status","unsupportedAlgorithmVersion","windows",[],"winningRegions",[]],t.N,t.z)
r=t.P
k=A.hd(r.a(a.i(0,"match")))
if(J.an(a.i(0,i),"extract")){q=A.d1(r.a(a.i(0,e)))
o=t.j
n=A.d2(o.a(a.i(0,f)))
r=A.d1(r.a(a.i(0,d)))
o=A.d2(o.a(a.i(0,c)))
m=t.t
j=B.k.az(q,m.a(n),k,r,m.a(o))
r=j.gaD()?"success":"telemetryUnavailable"
return A.L(["status",r,"firstExtraction",A.cf(j.a),"secondExtraction",A.cf(j.b),"windows",[],"winningRegions",[]],t.N,t.z)}if(!k.at)return A.L(["status","notEligible","windows",[],"winningRegions",[]],t.N,t.z)
q=t.j
return A.kb(k,A.d1(r.a(a.i(0,e))),A.d1(r.a(a.i(0,d))),A.d2(q.a(a.i(0,f))),A.d2(q.a(a.i(0,c))),J.an(a.i(0,"calculationMode"),"reliable_intervals"))},
hd(a1){var s,r,q,p,o,n,m,l="latitude",k="longitude",j=A.v(a1.i(0,"firstDriveId")),i=A.v(a1.i(0,"secondDriveId")),h=A.v(a1.i(0,"firstSectionId")),g=A.v(a1.i(0,"secondSectionId")),f=A.m(a1.i(0,"firstStartOffsetMeters")),e=A.m(a1.i(0,"firstEndOffsetMeters")),d=A.m(a1.i(0,"secondStartOffsetMeters")),c=A.m(a1.i(0,"secondEndOffsetMeters")),b=t.P,a=b.a(a1.i(0,"commonStart")),a0=A.m(a.i(0,l))
a=A.m(a.i(0,k))
b=b.a(a1.i(0,"commonEnd"))
s=A.m(b.i(0,l))
b=A.m(b.i(0,k))
r=A.m(a1.i(0,"commonDistanceMeters"))
q=A.fB(a1.i(0,"directionCompatible"))
p=A.m(a1.i(0,"geometryConfidence"))
o=A.fB(a1.i(0,"comparisonEligible"))
n=A.fB(a1.i(0,"ownershipCovered"))
m=J.b4(t.j.a(a1.i(0,"referenceGeometry")),new A.fG(),t.cX)
m=A.q(m,m.$ti.h("n.E"))
return A.hq(r,new A.Z(s,b),new A.Z(a0,a),o,q,j,e,h,f,p,n,m,i,c,g,d)},
kb(a,b,c,d,e,f){var s,r,q,p,o,n,m,l,k="secondExtraction",j=t.t,i=B.k.az(b,j.a(d),a,c,j.a(e))
if(!i.gaD())return A.L(["status","telemetryUnavailable","firstExtraction",A.cf(i.a),k,A.cf(i.b),"windows",[],"winningRegions",[]],t.N,t.z)
j=i.a
s=j.b
r=i.b
q=r.b
p=B.B.ck(B.q,b,s,a,f,c,q)
o=new A.eN(B.B).ci(B.q,c,q,b,s,a,f)
s=A.ij(p)
j=A.cf(j)
r=A.cf(r)
q=o.c
n=A.h(q)
m=n.h("f<1,u<e,o>>")
q=A.q(new A.f(q,n.h("u<e,o>(1)").a(new A.fD()),m),m.h("n.E"))
n=o.d
m=A.h(n)
l=m.h("f<1,u<e,o>>")
n=A.q(new A.f(n,m.h("u<e,o>(1)").a(new A.fE()),l),l.h("n.E"))
return A.L(["status",o.a.b,"comparison",s,"firstExtraction",j,k,r,"windows",q,"winningRegions",n],t.N,t.z)},
fP:function fP(){},
fO:function fO(){},
fQ:function fQ(){},
fR:function fR(){},
fV:function fV(){},
fS:function fS(){},
fT:function fT(){},
fU:function fU(){},
fG:function fG(){},
fD:function fD(){},
fE:function fE(){},
kt(){var s=v.G
s.driveItWorldMutation=A.h8(new A.fL())
s.driveItActiveCoverage=A.h8(new A.fM())
s.driveItWorldScoring=A.h8(new A.fN())},
fL:function fL(){},
fM:function fM(){},
fN:function fN(){},
aL:function aL(a,b,c){this.a=a
this.b=b
this.c=c},
ky(a){throw A.J(new A.bF("Field '"+a+"' has been assigned during initialization."),new Error())},
iq(){throw A.J(A.j1(""),new Error())},
h8(a){var s
if(typeof a=="function")throw A.d(A.dj("Attempting to rewrap a JS function."))
s=function(b,c){return function(d){return b(c,d,arguments.length)}}(A.jG,a)
s[$.hh()]=a
return s},
jG(a,b,c){t.Z.a(a)
if(A.a0(c)>=1)return a.$1(b)
return a.$0()},
im(a,b,c){A.kc(c,t.H,"T","max")
return Math.max(c.a(a),c.a(b))},
hx(a,b,c,d){var s=Math.sin((c-a)*3.141592653589793/180/2),r=Math.sin((d-b)*3.141592653589793/180/2)
return 12742017.6*Math.asin(Math.sqrt(B.b.k(s*s+Math.cos(a*3.141592653589793/180)*Math.cos(c*3.141592653589793/180)*r*r,0,1)))},
hU(a){var s=a.c,r=A.h3(a.b)
return isFinite(s)&&s>0?s:r},
h3(a){var s,r,q,p,o
for(s=0,r=0;r<a.length-1;){q=a[r];++r
p=a[r]
o=A.hx(q.a,q.b,p.a,p.b)
if(isFinite(o)&&o>0)s+=o}return s},
h4(a,b,c){if(!isFinite(b)||!isFinite(a)||!isFinite(c)||a<=0||c<=0)return 0
return B.b.k(B.b.k(b/a,0,1)*c,0,c)}},B={}
var w=[A,J,B]
var $={}
A.fY.prototype={}
J.cC.prototype={
M(a,b){return a===b},
gD(a){return A.cM(a)},
j(a){return"Instance of '"+A.cN(a)+"'"},
gW(a){return A.aE(A.h9(this))}}
J.cF.prototype={
j(a){return String(a)},
gD(a){return a?519018:218159},
gW(a){return A.aE(t.y)},
$iaB:1,
$ij:1}
J.bC.prototype={
M(a,b){return null==b},
j(a){return"null"},
gD(a){return 0},
$iaB:1}
J.bc.prototype={$ibb:1}
J.aI.prototype={
gD(a){return 0},
j(a){return String(a)}}
J.eS.prototype={}
J.aK.prototype={}
J.bD.prototype={
j(a){var s=a[$.is()]
if(s==null)s=a[$.hh()]
if(s==null)return this.bf(a)
return"JavaScript function for "+J.b5(s)},
$iat:1}
J.l.prototype={
l(a,b){A.h(a).c.a(b)
a.$flags&1&&A.d3(a,29)
a.push(b)},
A(a,b){var s
A.h(a).h("c<1>").a(b)
a.$flags&1&&A.d3(a,"addAll",2)
if(Array.isArray(b)){this.bi(a,b)
return}for(s=J.W(b);s.n();)a.push(s.gp())},
bi(a,b){var s,r
t.gn.a(b)
s=b.length
if(s===0)return
if(a===b)throw A.d(A.O(a))
for(r=0;r<s;++r)a.push(b[r])},
b8(a,b,c){var s=A.h(a)
return new A.f(a,s.u(c).h("1(2)").a(b),s.h("@<1>").u(c).h("f<1,2>"))},
cv(a,b){var s,r=A.bL(a.length,"",!1,t.N)
for(s=0;s<a.length;++s)this.q(r,s,A.B(a[s]))
return r.join(b)},
N(a,b){return A.bV(a,b,null,A.h(a).c)},
L(a,b){var s,r,q
A.h(a).h("1(1,1)").a(b)
s=a.length
if(s===0)throw A.d(A.aT())
if(0>=s)return A.a(a,0)
r=a[0]
for(q=1;q<s;++q){r=b.$2(r,a[q])
if(s!==a.length)throw A.d(A.O(a))}return r},
G(a,b,c,d){var s,r,q
d.a(b)
A.h(a).u(d).h("1(1,2)").a(c)
s=a.length
for(r=b,q=0;q<s;++q){r=c.$2(r,a[q])
if(a.length!==s)throw A.d(A.O(a))}return r},
aA(a,b,c){var s,r,q
A.h(a).h("j(1)").a(b)
s=a.length
for(r=0;r<s;++r){q=a[r]
if(b.$1(q))return q
if(a.length!==s)throw A.d(A.O(a))}throw A.d(A.aT())},
cq(a,b){return this.aA(a,b,null)},
E(a,b){if(!(b>=0&&b<a.length))return A.a(a,b)
return a[b]},
a7(a,b,c){if(b<0||b>a.length)throw A.d(A.ak(b,0,a.length,"start",null))
if(c<b||c>a.length)throw A.d(A.ak(c,b,a.length,"end",null))
if(b===c)return A.i([],A.h(a))
return A.i(a.slice(b,c),A.h(a))},
gI(a){if(a.length>0)return a[0]
throw A.d(A.aT())},
gV(a){var s=a.length
if(s>0)return a[s-1]
throw A.d(A.aT())},
aG(a,b,c,d,e){var s,r,q,p,o
A.h(a).h("c<1>").a(d)
a.$flags&2&&A.d3(a,5)
A.hP(b,c,a.length)
s=c-b
if(s===0)return
A.ax(e,"skipCount")
if(t.j.b(d)){r=d
q=e}else{r=J.hj(d,e).bb(0,!1)
q=0}p=J.bp(r)
if(q+s>p.gm(r))throw A.d(A.iY())
if(q<b)for(o=s-1;o>=0;--o)a[b+o]=p.i(r,q+o)
else for(o=0;o<s;++o)a[b+o]=p.i(r,q+o)},
R(a,b){var s,r
A.h(a).h("j(1)").a(b)
s=a.length
for(r=0;r<s;++r){if(b.$1(a[r]))return!0
if(a.length!==s)throw A.d(A.O(a))}return!1},
a1(a,b){var s,r,q,p,o,n=A.h(a)
n.h("I(1,1)?").a(b)
a.$flags&2&&A.d3(a,"sort")
s=a.length
if(s<2)return
if(b==null)b=J.jR()
if(s===2){r=a[0]
q=a[1]
n=b.$2(r,q)
if(typeof n!=="number")return n.cH()
if(n>0){a[0]=q
a[1]=r}return}p=0
if(n.c.b(null))for(o=0;o<a.length;++o)if(a[o]===void 0){a[o]=null;++p}a.sort(A.kd(b,2))
if(p>0)this.bT(a,p)},
aH(a){return this.a1(a,null)},
bT(a,b){var s,r=a.length
for(;s=r-1,r>0;r=s)if(a[s]===null){a[s]=void 0;--b
if(b===0)break}},
gv(a){return a.length===0},
ga_(a){return a.length!==0},
j(a){return A.fX(a,"[","]")},
gt(a){return new J.aQ(a,a.length,A.h(a).h("aQ<1>"))},
gD(a){return A.cM(a)},
gm(a){return a.length},
i(a,b){A.a0(b)
if(!(b>=0&&b<a.length))throw A.d(A.fH(a,b))
return a[b]},
q(a,b,c){A.h(a).c.a(c)
a.$flags&2&&A.d3(a)
if(!(b>=0&&b<a.length))throw A.d(A.fH(a,b))
a[b]=c},
$iw:1,
$ic:1,
$ir:1}
J.cD.prototype={
cB(a){var s,r,q
if(!Array.isArray(a))return null
s=a.$flags|0
if((s&4)!==0)r="const, "
else if((s&2)!==0)r="unmodifiable, "
else r=(s&1)!==0?"fixed, ":""
q="Instance of '"+A.cN(a)+"'"
if(r==="")return q
return q+" ("+r+"length: "+a.length+")"}}
J.eG.prototype={}
J.aQ.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
n(){var s,r=this,q=r.a,p=q.length
if(r.b!==p){q=A.D(q)
throw A.d(q)}s=r.c
if(s>=p){r.d=null
return!1}r.d=q[s]
r.c=s+1
return!0},
$iy:1}
J.ba.prototype={
C(a,b){var s
A.m(b)
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){s=this.gad(b)
if(this.gad(a)===s)return 0
if(this.gad(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gad(a){return a===0?1/a<0:a<0},
ba(a){var s
if(a>=-2147483648&&a<=2147483647)return a|0
if(isFinite(a)){s=a<0?Math.ceil(a):Math.floor(a)
return s+0}throw A.d(A.f7(""+a+".toInt()"))},
ae(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.d(A.f7(""+a+".round()"))},
k(a,b,c){if(this.C(b,c)>0)throw A.d(A.ih(b))
if(this.C(a,b)<0)return b
if(this.C(a,c)>0)return c
return a},
a0(a,b){var s
if(b>20)throw A.d(A.ak(b,0,20,"fractionDigits",null))
s=a.toFixed(b)
if(a===0&&this.gad(a))return"-"+s
return s},
j(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gD(a){var s,r,q,p,o=a|0
if(a===o)return o&536870911
s=Math.abs(a)
r=Math.log(s)/0.6931471805599453|0
q=Math.pow(2,r)
p=s<1?s/q:q/s
return((p*9007199254740992|0)+(p*3542243181176521|0))*599197+r*1259&536870911},
X(a,b){var s=a%b
if(s===0)return 0
if(s>0)return s
return s+b},
B(a,b){return(a|0)===a?a/b|0:this.c6(a,b)},
c6(a,b){var s=a/b
if(s>=-2147483648&&s<=2147483647)return s|0
if(s>0){if(s!==1/0)return Math.floor(s)}else if(s>-1/0)return Math.ceil(s)
throw A.d(A.f7("Result of truncating division is "+A.B(s)+": "+A.B(a)+" ~/ "+b))},
aY(a,b){var s
if(a>0)s=this.c_(a,b)
else{s=b>31?31:b
s=a>>s>>>0}return s},
c_(a,b){return b>31?0:a>>>b},
gW(a){return A.aE(t.H)},
$ia2:1,
$ib:1,
$iQ:1}
J.bB.prototype={
gW(a){return A.aE(t.S)},
$iaB:1,
$iI:1}
J.cG.prototype={
gW(a){return A.aE(t.i)},
$iaB:1}
J.aU.prototype={
a2(a,b,c){return a.substring(b,A.hP(b,c,a.length))},
aF(a,b){var s,r
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.d(B.a7)
for(s=a,r="";;){if((b&1)===1)r=s+r
b=b>>>1
if(b===0)break
s+=s}return r},
cw(a,b,c){var s=b-a.length
if(s<=0)return a
return this.aF(c,s)+a},
C(a,b){var s
A.v(b)
if(a===b)s=0
else s=a<b?-1:1
return s},
j(a){return a},
gD(a){var s,r,q
for(s=a.length,r=0,q=0;q<s;++q){r=r+a.charCodeAt(q)&536870911
r=r+((r&524287)<<10)&536870911
r^=r>>6}r=r+((r&67108863)<<3)&536870911
r^=r>>11
return r+((r&16383)<<15)&536870911},
gW(a){return A.aE(t.N)},
gm(a){return a.length},
i(a,b){A.a0(b)
if(!(b.cG(0,0)&&b.cJ(0,a.length)))throw A.d(A.fH(a,b))
return a[b]},
$iaB:1,
$ia2:1,
$ie:1}
A.bi.prototype={
gt(a){return new A.br(J.W(this.gZ()),A.k(this).h("br<1,2>"))},
gm(a){return J.aP(this.gZ())},
gv(a){return J.fW(this.gZ())},
ga_(a){return J.iH(this.gZ())},
N(a,b){var s=A.k(this)
return A.ho(J.hj(this.gZ(),b),s.c,s.y[1])},
j(a){return J.b5(this.gZ())}}
A.br.prototype={
n(){return this.a.n()},
gp(){return this.$ti.y[1].a(this.a.gp())},
$iy:1}
A.aR.prototype={
gZ(){return this.a}}
A.c3.prototype={$iw:1}
A.bF.prototype={
j(a){return"LateInitializationError: "+this.a}}
A.eT.prototype={}
A.w.prototype={}
A.n.prototype={
gt(a){var s=this
return new A.aw(s,s.gm(s),A.k(s).h("aw<n.E>"))},
gv(a){return this.gm(this)===0},
R(a,b){var s,r,q=this
A.k(q).h("j(n.E)").a(b)
s=q.gm(q)
for(r=0;r<s;++r){if(b.$1(q.E(0,r)))return!0
if(s!==q.gm(q))throw A.d(A.O(q))}return!1},
L(a,b){var s,r,q,p=this
A.k(p).h("n.E(n.E,n.E)").a(b)
s=p.gm(p)
if(s===0)throw A.d(A.aT())
r=p.E(0,0)
for(q=1;q<s;++q){r=b.$2(r,p.E(0,q))
if(s!==p.gm(p))throw A.d(A.O(p))}return r},
N(a,b){return A.bV(this,b,null,A.k(this).h("n.E"))}}
A.bU.prototype={
gbx(){var s=J.aP(this.a),r=this.c
if(r==null||r>s)return s
return r},
gc1(){var s=J.aP(this.a),r=this.b
if(r>s)return s
return r},
gm(a){var s,r=J.aP(this.a),q=this.b
if(q>=r)return 0
s=this.c
if(s==null||s>=r)return r-q
return s-q},
E(a,b){var s=this,r=s.gc1()+b
if(b<0||r>=s.gbx())throw A.d(A.eE(b,s.gm(0),s,null,"index"))
return J.hi(s.a,r)},
N(a,b){var s,r,q=this
A.ax(b,"count")
s=q.b+b
r=q.c
if(r!=null&&s>=r)return new A.bx(q.$ti.h("bx<1>"))
return A.bV(q.a,s,r,q.$ti.c)},
bb(a,b){var s,r,q,p=this,o=p.b,n=p.a,m=J.bp(n),l=m.gm(n),k=p.c
if(k!=null&&k<l)l=k
s=l-o
if(s<=0){n=J.hz(0,p.$ti.c)
return n}r=A.bL(s,m.E(n,o),!1,p.$ti.c)
for(q=1;q<s;++q){B.a.q(r,q,m.E(n,o+q))
if(m.gm(n)<l)throw A.d(A.O(p))}return r}}
A.aw.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
n(){var s,r=this,q=r.a,p=q.gm(q)
if(r.b!==p)throw A.d(A.O(q))
s=r.c
if(s>=p){r.d=null
return!1}r.d=q.E(0,s);++r.c
return!0},
$iy:1}
A.a3.prototype={
gt(a){return new A.bO(J.W(this.a),this.b,A.k(this).h("bO<1,2>"))},
gm(a){return J.aP(this.a)},
gv(a){return J.fW(this.a)}}
A.bw.prototype={$iw:1}
A.bO.prototype={
n(){var s=this,r=s.b
if(r.n()){s.a=s.c.$1(r.gp())
return!0}s.a=null
return!1},
gp(){var s=this.a
return s==null?this.$ti.y[1].a(s):s},
$iy:1}
A.f.prototype={
gm(a){return J.aP(this.a)},
E(a,b){return this.b.$1(J.hi(this.a,b))}}
A.x.prototype={
gt(a){return new A.ae(J.W(this.a),this.b,this.$ti.h("ae<1>"))}}
A.ae.prototype={
n(){var s,r
for(s=this.a,r=this.b;s.n();)if(r.$1(s.gp()))return!0
return!1},
gp(){return this.a.gp()},
$iy:1}
A.bz.prototype={
gt(a){return new A.bA(J.W(this.a),this.b,B.C,this.$ti.h("bA<1,2>"))}}
A.bA.prototype={
gp(){var s=this.d
return s==null?this.$ti.y[1].a(s):s},
n(){var s,r,q=this,p=q.c
if(p==null)return!1
for(s=q.a,r=q.b;!p.n();){q.d=null
if(s.n()){q.c=null
p=J.W(r.$1(s.gp()))
q.c=p}else return!1}q.d=q.c.gp()
return!0},
$iy:1}
A.ay.prototype={
N(a,b){A.dk(b,"count",t.S)
A.ax(b,"count")
return new A.ay(this.a,this.b+b,A.k(this).h("ay<1>"))},
gt(a){var s=this.a
return new A.bS(s.gt(s),this.b,A.k(this).h("bS<1>"))}}
A.b8.prototype={
gm(a){var s=this.a,r=s.gm(s)-this.b
if(r>=0)return r
return 0},
N(a,b){A.dk(b,"count",t.S)
A.ax(b,"count")
return new A.b8(this.a,this.b+b,this.$ti)},
$iw:1}
A.bS.prototype={
n(){var s,r
for(s=this.a,r=0;r<this.b;++r)s.n()
this.b=0
return s.n()},
gp(){return this.a.gp()},
$iy:1}
A.bx.prototype={
gt(a){return B.C},
gv(a){return!0},
gm(a){return 0},
N(a,b){A.ax(b,"count")
return this}}
A.by.prototype={
n(){return!1},
gp(){throw A.d(A.aT())},
$iy:1}
A.c1.prototype={
gt(a){return new A.c2(J.W(this.a),this.$ti.h("c2<1>"))}}
A.c2.prototype={
n(){var s,r
for(s=this.a,r=this.$ti.c;s.n();)if(r.b(s.gp()))return!0
return!1},
gp(){return this.$ti.c.a(this.a.gp())},
$iy:1}
A.bk.prototype={$r:"+(1,2,3,4)",$s:1}
A.bu.prototype={}
A.bt.prototype={
gv(a){return this.gm(this)===0},
j(a){return A.eP(this)},
a6(a,b,c,d){var s=A.a8(c,d)
this.J(0,new A.dN(this,A.k(this).u(c).u(d).h("M<1,2>(3,4)").a(b),s))
return s},
$iu:1}
A.dN.prototype={
$2(a,b){var s=A.k(this.a),r=this.b.$2(s.c.a(a),s.y[1].a(b))
this.c.q(0,r.a,r.b)},
$S(){return A.k(this.a).h("~(1,2)")}}
A.aa.prototype={
gm(a){return this.b.length},
gbH(){var s=this.$keys
if(s==null){s=Object.keys(this.a)
this.$keys=s}return s},
au(a){if(typeof a!="string")return!1
if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
i(a,b){if(!this.au(b))return null
return this.b[this.a[b]]},
J(a,b){var s,r,q,p
this.$ti.h("~(1,2)").a(b)
s=this.gbH()
r=this.b
for(q=s.length,p=0;p<q;++p)b.$2(s[p],r[p])}}
A.cA.prototype={
M(a,b){if(b==null)return!1
return b instanceof A.b9&&this.a.M(0,b.a)&&A.he(this)===A.he(b)},
gD(a){return A.h1(this.a,A.he(this),B.d,B.d)},
j(a){var s=B.a.cv([A.aE(this.$ti.c)],", ")
return this.a.j(0)+" with "+("<"+s+">")}}
A.b9.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.ks(A.fF(this.a),this.$ti)}}
A.bR.prototype={}
A.f5.prototype={
K(a){var s,r,q=this,p=new RegExp(q.a).exec(a)
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
A.bP.prototype={
j(a){return"Null check operator used on a null value"}}
A.cI.prototype={
j(a){var s,r=this,q="NoSuchMethodError: method not found: '",p=r.b
if(p==null)return"NoSuchMethodError: "+r.a
s=r.c
if(s==null)return q+p+"' ("+r.a+")"
return q+p+"' on '"+s+"' ("+r.a+")"}}
A.cS.prototype={
j(a){var s=this.a
return s.length===0?"Error":"Error: "+s}}
A.eR.prototype={
j(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.R.prototype={
j(a){var s=this.constructor,r=s==null?null:s.name
return"Closure '"+A.ir(r==null?"unknown":r)+"'"},
$iat:1,
gcE(){return this},
$C:"$1",
$R:1,
$D:null}
A.cj.prototype={$C:"$0",$R:0}
A.ck.prototype={$C:"$2",$R:2}
A.cQ.prototype={}
A.cP.prototype={
j(a){var s=this.$static_name
if(s==null)return"Closure of unknown static method"
return"Closure '"+A.ir(s)+"'"}}
A.b6.prototype={
M(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.b6))return!1
return this.$_target===b.$_target&&this.a===b.a},
gD(a){return(A.io(this.a)^A.cM(this.$_target))>>>0},
j(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.cN(this.a)+"'")}}
A.cO.prototype={
j(a){return"RuntimeError: "+this.a}}
A.au.prototype={
gm(a){return this.a},
gv(a){return this.a===0},
gU(){return new A.av(this,A.k(this).h("av<1>"))},
au(a){var s=this.b
if(s==null)return!1
return s[a]!=null},
A(a,b){A.k(this).h("u<1,2>").a(b).J(0,new A.eH(this))},
i(a,b){var s,r,q,p,o=null
if(typeof b=="string"){s=this.b
if(s==null)return o
r=s[b]
q=r==null?o:r.b
return q}else if(typeof b=="number"&&(b&0x3fffffff)===b){p=this.c
if(p==null)return o
r=p[b]
q=r==null?o:r.b
return q}else return this.cr(b)},
cr(a){var s,r,q=this.d
if(q==null)return null
s=q[this.b6(a)]
r=this.b7(s,a)
if(r<0)return null
return s[r].b},
q(a,b,c){var s,r,q=this,p=A.k(q)
p.c.a(b)
p.y[1].a(c)
if(typeof b=="string"){s=q.b
q.aI(s==null?q.b=q.an():s,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){r=q.c
q.aI(r==null?q.c=q.an():r,b,c)}else q.cs(b,c)},
cs(a,b){var s,r,q,p,o=this,n=A.k(o)
n.c.a(a)
n.y[1].a(b)
s=o.d
if(s==null)s=o.d=o.an()
r=o.b6(a)
q=s[r]
if(q==null)s[r]=[o.ao(a,b)]
else{p=o.b7(q,a)
if(p>=0)q[p].b=b
else q.push(o.ao(a,b))}},
cA(a,b){var s,r,q=this,p=A.k(q)
p.c.a(a)
p.h("2()").a(b)
if(q.au(a)){s=q.i(0,a)
return s==null?p.y[1].a(s):s}r=b.$0()
q.q(0,a,r)
return r},
J(a,b){var s,r,q=this
A.k(q).h("~(1,2)").a(b)
s=q.e
r=q.r
while(s!=null){b.$2(s.a,s.b)
if(r!==q.r)throw A.d(A.O(q))
s=s.c}},
aI(a,b,c){var s,r=A.k(this)
r.c.a(b)
r.y[1].a(c)
s=a[b]
if(s==null)a[b]=this.ao(b,c)
else s.b=c},
ao(a,b){var s=this,r=A.k(s),q=new A.eL(r.c.a(a),r.y[1].a(b))
if(s.e==null)s.e=s.f=q
else s.f=s.f.c=q;++s.a
s.r=s.r+1&1073741823
return q},
b6(a){return J.a1(a)&1073741823},
b7(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.an(a[r].a,b))return r
return-1},
j(a){return A.eP(this)},
an(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
$ihB:1}
A.eH.prototype={
$2(a,b){var s=this.a,r=A.k(s)
s.q(0,r.c.a(a),r.y[1].a(b))},
$S(){return A.k(this.a).h("~(1,2)")}}
A.eL.prototype={}
A.av.prototype={
gm(a){return this.a.a},
gv(a){return this.a.a===0},
gt(a){var s=this.a
return new A.bI(s,s.r,s.e,this.$ti.h("bI<1>"))}}
A.bI.prototype={
gp(){return this.d},
n(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.d(A.O(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.a
r.c=s.c
return!0}},
$iy:1}
A.ac.prototype={
gm(a){return this.a.a},
gv(a){return this.a.a===0},
gt(a){var s=this.a
return new A.bJ(s,s.r,s.e,this.$ti.h("bJ<1>"))}}
A.bJ.prototype={
gp(){return this.d},
n(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.d(A.O(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.b
r.c=s.c
return!0}},
$iy:1}
A.bG.prototype={
gm(a){return this.a.a},
gv(a){return this.a.a===0},
gt(a){var s=this.a
return new A.bH(s,s.r,s.e,this.$ti.h("bH<1,2>"))}}
A.bH.prototype={
gp(){var s=this.d
s.toString
return s},
n(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.d(A.O(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=new A.M(s.a,s.b,r.$ti.h("M<1,2>"))
r.c=s.c
return!0}},
$iy:1}
A.b_.prototype={
j(a){return this.b_(!1)},
b_(a){var s,r,q,p,o,n=this.by(),m=this.aO(),l=(a?"Record ":"")+"("
for(s=n.length,r="",q=0;q<s;++q,r=", "){l+=r
p=n[q]
if(typeof p=="string")l=l+p+": "
if(!(q<m.length))return A.a(m,q)
o=m[q]
l=a?l+A.hN(o):l+A.B(o)}l+=")"
return l.charCodeAt(0)==0?l:l},
by(){var s,r=this.$s
while($.fv.length<=r)B.a.l($.fv,null)
s=$.fv[r]
if(s==null){s=this.br()
B.a.q($.fv,r,s)}return s},
br(){var s,r,q,p=this.$r,o=p.indexOf("("),n=p.substring(1,o),m=p.substring(o),l=m==="()"?0:m.replace(/[^,]/g,"").length+1,k=t.K,j=J.hy(l,k)
for(s=0;s<l;++s)j[s]=s
if(n!==""){r=n.split(",")
s=r.length
for(q=l;s>0;){--q;--s
B.a.q(j,q,r[s])}}return A.T(j,k)}}
A.bj.prototype={
aO(){return this.a},
M(a,b){if(b==null)return!1
return b instanceof A.bj&&this.$s===b.$s&&A.jn(this.a,b.a)},
gD(a){return A.h1(this.$s,A.j6(this.a),B.d,B.d)}}
A.cH.prototype={
j(a){return"RegExp/"+this.a+"/"+this.b.flags},
cp(a){var s=this.b.exec(a)
if(s==null)return null
return new A.fu(s)},
$ij9:1}
A.fu.prototype={
i(a,b){var s
A.a0(b)
s=this.b
if(!(b<s.length))return A.a(s,b)
return s[b]}}
A.ad.prototype={
h(a){return A.ca(v.typeUniverse,this,a)},
u(a){return A.i4(v.typeUniverse,this,a)}}
A.cW.prototype={}
A.fw.prototype={
j(a){return A.V(this.a,null)}}
A.cV.prototype={
j(a){return this.a}}
A.bl.prototype={}
A.aD.prototype={
gt(a){var s=this,r=new A.aY(s,s.r,A.k(s).h("aY<1>"))
r.c=s.e
return r},
gm(a){return this.a},
gv(a){return this.a===0},
ga_(a){return this.a!==0},
ac(a,b){var s,r
if(typeof b=="string"&&b!=="__proto__"){s=this.b
if(s==null)return!1
return t.br.a(s[b])!=null}else{r=this.bs(b)
return r}},
bs(a){var s=this.d
if(s==null)return!1
return this.aN(s[this.aL(a)],a)>=0},
l(a,b){var s,r,q=this
A.k(q).c.a(b)
if(typeof b=="string"&&b!=="__proto__"){s=q.b
return q.aK(s==null?q.b=A.h5():s,b)}else if(typeof b=="number"&&(b&1073741823)===b){r=q.c
return q.aK(r==null?q.c=A.h5():r,b)}else return q.bh(b)},
bh(a){var s,r,q,p=this
A.k(p).c.a(a)
s=p.d
if(s==null)s=p.d=A.h5()
r=p.aL(a)
q=s[r]
if(q==null)s[r]=[p.ah(a)]
else{if(p.aN(q,a)>=0)return!1
q.push(p.ah(a))}return!0},
aK(a,b){A.k(this).c.a(b)
if(t.br.a(a[b])!=null)return!1
a[b]=this.ah(b)
return!0},
ah(a){var s=this,r=new A.cZ(A.k(s).c.a(a))
if(s.e==null)s.e=s.f=r
else s.f=s.f.b=r;++s.a
s.r=s.r+1&1073741823
return r},
aL(a){return J.a1(a)&1073741823},
aN(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.an(a[r].a,b))return r
return-1},
$ihD:1}
A.cZ.prototype={}
A.aY.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
n(){var s=this,r=s.c,q=s.a
if(s.b!==q.r)throw A.d(A.O(q))
else if(r==null){s.d=null
return!1}else{s.d=s.$ti.h("1?").a(r.a)
s.c=r.b
return!0}},
$iy:1}
A.eM.prototype={
$2(a,b){this.a.q(0,this.b.a(a),this.c.a(b))},
$S:21}
A.P.prototype={
J(a,b){var s,r,q,p=A.k(this)
p.h("~(P.K,P.V)").a(b)
for(s=this.gU(),s=s.gt(s),p=p.h("P.V");s.n();){r=s.gp()
q=this.i(0,r)
b.$2(r,q==null?p.a(q):q)}},
a6(a,b,c,d){var s,r,q,p,o,n=A.k(this)
n.u(c).u(d).h("M<1,2>(P.K,P.V)").a(b)
s=A.a8(c,d)
for(r=this.gU(),r=r.gt(r),n=n.h("P.V");r.n();){q=r.gp()
p=this.i(0,q)
o=b.$2(q,p==null?n.a(p):p)
s.q(0,o.a,o.b)}return s},
gm(a){var s=this.gU()
return s.gm(s)},
gv(a){var s=this.gU()
return s.gv(s)},
j(a){return A.eP(this)},
$iu:1}
A.eQ.prototype={
$2(a,b){var s,r=this.a
if(!r.a)this.b.a+=", "
r.a=!1
r=this.b
s=A.B(a)
r.a=(r.a+=s)+": "
s=A.B(b)
r.a+=s},
$S:11}
A.cb.prototype={}
A.be.prototype={
i(a,b){return this.a.i(0,b)},
J(a,b){this.a.J(0,this.$ti.h("~(1,2)").a(b))},
gv(a){return this.a.a===0},
gm(a){return this.a.a},
j(a){return A.eP(this.a)},
a6(a,b,c,d){return this.a.a6(0,this.$ti.u(c).u(d).h("M<1,2>(3,4)").a(b),c,d)},
$iu:1}
A.bZ.prototype={}
A.bK.prototype={
gt(a){var s=this
return new A.c4(s,s.c,s.d,s.b,s.$ti.h("c4<1>"))},
gv(a){return this.b===this.c},
gm(a){return(this.c-this.b&this.a.length-1)>>>0},
E(a,b){var s,r,q=this,p=q.gm(0)
if(0>b||b>=p)A.b3(A.eE(b,p,q,null,"index"))
p=q.a
s=p.length
r=(q.b+b&s-1)>>>0
if(!(r>=0&&r<s))return A.a(p,r)
r=p[r]
return r==null?q.$ti.c.a(r):r},
cj(a){var s=this,r=s.b
if(r!==s.c){for(;r!==s.c;r=(r+1&s.a.length-1)>>>0)B.a.q(s.a,r,null)
s.b=s.c=0;++s.d}},
j(a){return A.fX(this,"{","}")}}
A.c4.prototype={
gp(){var s=this.e
return s==null?this.$ti.c.a(s):s},
n(){var s,r,q=this,p=q.a
if(q.c!==p.d)A.b3(A.O(p))
s=q.d
if(s===q.b){q.e=null
return!1}p=p.a
r=p.length
if(!(s<r))return A.a(p,s)
q.e=p[s]
q.d=(s+1&r-1)>>>0
return!0},
$iy:1}
A.aX.prototype={
gv(a){return this.gm(this)===0},
ga_(a){return this.gm(this)!==0},
A(a,b){var s
for(s=J.W(A.k(this).h("c<1>").a(b));s.n();)this.l(0,s.gp())},
j(a){return A.fX(this,"{","}")},
N(a,b){return A.hR(this,b,A.k(this).c)},
$iw:1,
$ic:1,
$iaW:1}
A.c6.prototype={}
A.d_.prototype={
l(a,b){this.$ti.c.a(b)
return A.jz()}}
A.c_.prototype={
ac(a,b){return this.a.ac(0,b)},
gm(a){return this.a.a},
gt(a){var s=this.a
return A.jg(s,s.r,A.k(s).c)}}
A.bm.prototype={}
A.cc.prototype={}
A.cX.prototype={
i(a,b){var s,r=this.b
if(r==null)return this.c.i(0,b)
else if(typeof b!="string")return null
else{s=r[b]
return typeof s=="undefined"?this.bP(b):s}},
gm(a){return this.b==null?this.c.a:this.a9().length},
gv(a){return this.gm(0)===0},
gU(){if(this.b==null){var s=this.c
return new A.av(s,A.k(s).h("av<1>"))}return new A.cY(this)},
J(a,b){var s,r,q,p,o=this
t.fH.a(b)
if(o.b==null)return o.c.J(0,b)
s=o.a9()
for(r=0;r<s.length;++r){q=s[r]
p=o.b[q]
if(typeof p=="undefined"){p=A.fC(o.a[q])
o.b[q]=p}b.$2(q,p)
if(s!==o.c)throw A.d(A.O(o))}},
a9(){var s=t.bF.a(this.c)
if(s==null)s=this.c=A.i(Object.keys(this.a),t.s)
return s},
bP(a){var s
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
s=A.fC(this.a[a])
return this.b[a]=s}}
A.cY.prototype={
gm(a){return this.a.gm(0)},
E(a,b){var s=this.a
if(s.b==null)s=s.gU().E(0,b)
else{s=s.a9()
if(!(b>=0&&b<s.length))return A.a(s,b)
s=s[b]}return s},
gt(a){var s=this.a
if(s.b==null){s=s.gU()
s=s.gt(s)}else{s=s.a9()
s=new J.aQ(s,s.length,A.h(s).h("aQ<1>"))}return s}}
A.cl.prototype={}
A.cp.prototype={}
A.bE.prototype={
j(a){var s=A.cx(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+s}}
A.cJ.prototype={
j(a){return"Cyclic error in JSON stringify"}}
A.eI.prototype={
av(a,b){var s=A.k3(a,this.gcm().a)
return s},
aw(a,b){var s=A.jf(a,this.gcn().b,null)
return s},
gcn(){return B.aC},
gcm(){return B.aB}}
A.eK.prototype={}
A.eJ.prototype={}
A.fs.prototype={
bd(a){var s,r,q,p,o,n,m=a.length
for(s=this.c,r=0,q=0;q<m;++q){p=a.charCodeAt(q)
if(p>92){if(p>=55296){o=p&64512
if(o===55296){n=q+1
n=!(n<m&&(a.charCodeAt(n)&64512)===56320)}else n=!1
if(!n)if(o===56320){o=q-1
o=!(o>=0&&(a.charCodeAt(o)&64512)===55296)}else o=!1
else o=!0
if(o){if(q>r)s.a+=B.e.a2(a,r,q)
r=q+1
o=A.N(92)
s.a+=o
o=A.N(117)
s.a+=o
o=A.N(100)
s.a+=o
o=p>>>8&15
o=A.N(o<10?48+o:87+o)
s.a+=o
o=p>>>4&15
o=A.N(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.N(o<10?48+o:87+o)
s.a+=o}}continue}if(p<32){if(q>r)s.a+=B.e.a2(a,r,q)
r=q+1
o=A.N(92)
s.a+=o
switch(p){case 8:o=A.N(98)
s.a+=o
break
case 9:o=A.N(116)
s.a+=o
break
case 10:o=A.N(110)
s.a+=o
break
case 12:o=A.N(102)
s.a+=o
break
case 13:o=A.N(114)
s.a+=o
break
default:o=A.N(117)
s.a+=o
o=A.N(48)
s.a=(s.a+=o)+o
o=p>>>4&15
o=A.N(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.N(o<10?48+o:87+o)
s.a+=o
break}}else if(p===34||p===92){if(q>r)s.a+=B.e.a2(a,r,q)
r=q+1
o=A.N(92)
s.a+=o
o=A.N(p)
s.a+=o}}if(r===0)s.a+=a
else if(r<m)s.a+=B.e.a2(a,r,m)},
ag(a){var s,r,q,p
for(s=this.a,r=s.length,q=0;q<r;++q){p=s[q]
if(a==null?p==null:a===p)throw A.d(new A.cJ(a,null))}B.a.l(s,a)},
af(a){var s,r,q,p,o=this
if(o.bc(a))return
o.ag(a)
try{s=o.b.$1(a)
if(!o.bc(s)){q=A.hA(a,null,o.gaU())
throw A.d(q)}q=o.a
if(0>=q.length)return A.a(q,-1)
q.pop()}catch(p){r=A.hg(p)
q=A.hA(a,r,o.gaU())
throw A.d(q)}},
bc(a){var s,r,q=this
if(typeof a=="number"){if(!isFinite(a))return!1
q.c.a+=B.b.j(a)
return!0}else if(a===!0){q.c.a+="true"
return!0}else if(a===!1){q.c.a+="false"
return!0}else if(a==null){q.c.a+="null"
return!0}else if(typeof a=="string"){s=q.c
s.a+='"'
q.bd(a)
s.a+='"'
return!0}else if(t.j.b(a)){q.ag(a)
q.cC(a)
s=q.a
if(0>=s.length)return A.a(s,-1)
s.pop()
return!0}else if(t.eO.b(a)){q.ag(a)
r=q.cD(a)
s=q.a
if(0>=s.length)return A.a(s,-1)
s.pop()
return r}else return!1},
cC(a){var s,r,q=this.c
q.a+="["
s=J.bo(a)
if(s.ga_(a)){this.af(s.i(a,0))
for(r=1;r<s.gm(a);++r){q.a+=","
this.af(s.i(a,r))}}q.a+="]"},
cD(a){var s,r,q,p,o,n,m=this,l={}
if(a.gv(a)){m.c.a+="{}"
return!0}s=a.gm(a)*2
r=A.bL(s,null,!1,t._)
q=l.a=0
l.b=!0
a.J(0,new A.ft(l,r))
if(!l.b)return!1
p=m.c
p.a+="{"
for(o='"';q<s;q+=2,o=',"'){p.a+=o
m.bd(A.v(r[q]))
p.a+='":'
n=q+1
if(!(n<s))return A.a(r,n)
m.af(r[n])}p.a+="}"
return!0}}
A.ft.prototype={
$2(a,b){var s,r
if(typeof a!="string")this.a.b=!1
s=this.b
r=this.a
B.a.q(s,r.a++,a)
B.a.q(s,r.a++,b)},
$S:11}
A.fr.prototype={
gaU(){var s=this.c.a
return s.charCodeAt(0)==0?s:s}}
A.dW.prototype={
$0(){var s=this
return A.b3(A.dj("("+s.a+", "+s.b+", "+s.c+", "+s.d+", "+s.e+", "+s.f+", "+s.r+", "+s.w+")"))},
$S:44}
A.ah.prototype={
P(a){var s=1000,r=B.c.X(a,s),q=B.c.B(a-r,s),p=this.b+r,o=B.c.X(p,s),n=this.c
return new A.ah(A.ht(this.a+B.c.B(p-o,s)+q,o,n),o,n)},
S(a){return A.G(this.b-a.b,this.a-a.a)},
M(a,b){if(b==null)return!1
return b instanceof A.ah&&this.a===b.a&&this.b===b.b&&this.c===b.c},
gD(a){return A.h1(this.a,this.b,B.d,B.d)},
cu(a){var s=this.a,r=a.a
if(s>=r)s=s===r&&this.b<a.b
else s=!0
return s},
ct(a){var s=this.a,r=a.a
if(s<=r)s=s===r&&this.b>a.b
else s=!0
return s},
C(a,b){var s
t.dy.a(b)
s=B.c.C(this.a,b.a)
if(s!==0)return s
return B.c.C(this.b,b.b)},
O(){var s=this
if(s.c)return s
return new A.ah(s.a,s.b,!0)},
j(a){var s=this,r=A.hs(A.cL(s)),q=A.ar(A.hL(s)),p=A.ar(A.hH(s)),o=A.ar(A.hI(s)),n=A.ar(A.hK(s)),m=A.ar(A.hM(s)),l=A.dX(A.hJ(s)),k=s.b,j=k===0?"":A.dX(k)
k=r+"-"+q
if(s.c)return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j},
aE(){var s=this,r=A.cL(s)>=-9999&&A.cL(s)<=9999?A.hs(A.cL(s)):A.iU(A.cL(s)),q=A.ar(A.hL(s)),p=A.ar(A.hH(s)),o=A.ar(A.hI(s)),n=A.ar(A.hK(s)),m=A.ar(A.hM(s)),l=A.dX(A.hJ(s)),k=s.b,j=k===0?"":A.dX(k)
k=r+"-"+q
if(s.c)return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j},
$ia2:1}
A.dZ.prototype={
$1(a){if(a==null)return 0
return A.d0(a)},
$S:12}
A.e_.prototype={
$1(a){var s,r,q
if(a==null)return 0
for(s=a.length,r=0,q=0;q<6;++q){r*=10
if(q<s){if(!(q<s))return A.a(a,q)
r+=a.charCodeAt(q)^48}}return r},
$S:12}
A.S.prototype={
M(a,b){if(b==null)return!1
return b instanceof A.S&&this.a===b.a},
gD(a){return B.c.gD(this.a)},
C(a,b){return B.c.C(this.a,t.fu.a(b).a)},
j(a){var s,r,q,p,o,n=this.a,m=B.c.B(n,36e8),l=n%36e8
if(n<0){m=0-m
n=0-l
s="-"}else{n=l
s=""}r=B.c.B(n,6e7)
n%=6e7
q=r<10?"0":""
p=B.c.B(n,1e6)
o=p<10?"0":""
return s+m+":"+q+r+":"+o+p+"."+B.e.cw(B.c.j(n%1e6),6,"0")},
$ia2:1}
A.fo.prototype={
j(a){return this.F()}}
A.A.prototype={}
A.ch.prototype={
j(a){var s=this.a
if(s!=null)return"Assertion failed: "+A.cx(s)
return"Assertion failed"}}
A.bY.prototype={}
A.ao.prototype={
gak(){return"Invalid argument"+(!this.a?"(s)":"")},
gaj(){return""},
j(a){var s=this,r=s.c,q=r==null?"":" ("+r+")",p=s.d,o=p==null?"":": "+p,n=s.gak()+q+o
if(!s.a)return n
return n+s.gaj()+": "+A.cx(s.gaC())},
gaC(){return this.b}}
A.bQ.prototype={
gaC(){return A.i7(this.b)},
gak(){return"RangeError"},
gaj(){var s,r=this.e,q=this.f
if(r==null)s=q!=null?": Not less than or equal to "+A.B(q):""
else if(q==null)s=": Not greater than or equal to "+A.B(r)
else if(q>r)s=": Not in inclusive range "+A.B(r)+".."+A.B(q)
else s=q<r?": Valid value range is empty":": Only valid value is "+A.B(r)
return s}}
A.cz.prototype={
gaC(){return A.a0(this.b)},
gak(){return"RangeError"},
gaj(){if(A.a0(this.b)<0)return": index must not be negative"
var s=this.f
if(s===0)return": no indices are valid"
return": index should be less than "+s},
gm(a){return this.f}}
A.c0.prototype={
j(a){return"Unsupported operation: "+this.a}}
A.bf.prototype={
j(a){return"Bad state: "+this.a}}
A.co.prototype={
j(a){var s=this.a
if(s==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.cx(s)+"."}}
A.cK.prototype={
j(a){return"Out of Memory"},
$iA:1}
A.bT.prototype={
j(a){return"Stack Overflow"},
$iA:1}
A.fp.prototype={
j(a){return"Exception: "+this.a}}
A.eD.prototype={
j(a){var s=this.a,r=""!==s?"FormatException: "+s:"FormatException",q=this.b
if(typeof q=="string"){if(q.length>78)q=B.e.a2(q,0,75)+"..."
return r+"\n"+q}else return r}}
A.c.prototype={
b8(a,b,c){var s=A.k(this)
return A.j5(this,s.u(c).h("1(c.E)").a(b),s.h("c.E"),c)},
G(a,b,c,d){var s,r
d.a(b)
A.k(this).u(d).h("1(1,c.E)").a(c)
for(s=this.gt(this),r=b;s.n();)r=c.$2(r,s.gp())
return r},
bb(a,b){var s=A.k(this).h("c.E")
if(b)s=A.q(this,s)
else{s=A.q(this,s)
s.$flags=1
s=s}return s},
gm(a){var s,r=this.gt(this)
for(s=0;r.n();)++s
return s},
gv(a){return!this.gt(this).n()},
ga_(a){return!this.gv(this)},
N(a,b){return A.hR(this,b,A.k(this).h("c.E"))},
aA(a,b,c){var s,r=A.k(this)
r.h("j(c.E)").a(b)
r.h("c.E()?").a(c)
for(r=this.gt(this);r.n();){s=r.gp()
if(b.$1(s))return s}r=c.$0()
return r},
E(a,b){var s,r
A.ax(b,"index")
s=this.gt(this)
for(r=b;s.n();){if(r===0)return s.gp();--r}throw A.d(A.eE(b,b-r,this,null,"index"))},
j(a){return A.iZ(this,"(",")")}}
A.M.prototype={
j(a){return"MapEntry("+A.B(this.a)+": "+A.B(this.b)+")"}}
A.aV.prototype={
gD(a){return A.o.prototype.gD.call(this,0)},
j(a){return"null"}}
A.o.prototype={$io:1,
M(a,b){return this===b},
gD(a){return A.cM(this)},
j(a){return"Instance of '"+A.cN(this)+"'"},
gW(a){return A.ko(this)},
toString(){return this.j(this)}}
A.bg.prototype={
gm(a){return this.a.length},
j(a){var s=this.a
return s.charCodeAt(0)==0?s:s},
$ijd:1}
A.d5.prototype={
H(a){var s,r,q,p,o,n,m=A.i([],t.h)
for(s=a.T(B.m),r=J.W(s.a),s=new A.ae(r,s.b,s.$ti.h("ae<1>")),q=0;s.n();){p=r.gp()
o=p.at
n=Math.max(o.c,o.d)
o=!0
if(p.ax===B.x)if(!(p.x-p.w<4))o=n>=0.65&&p.y<12
if(o)++q
else B.a.l(m,p)}if(m.length===0)return new A.cg(0,!1,!1)
s=new A.dd(m)
return new A.cg(s.$1(new A.df(this))*25+s.$1(new A.dg(this,a))*15+s.$1(new A.dh(this,a))*10,!0,m.length>=2)},
bg(a,b){var s=B.a.a7(a.c,b.d,b.e+1),r=A.h(s),q=r.h("f<1,b>"),p=A.q(new A.f(s,r.h("b(1)").a(new A.d6()),q),q.h("n.E"))
return B.a.G(p,0,new A.d7(B.a.L(p,new A.d8())/p.length),t.i)/p.length},
bX(a,b){var s=a.c,r=A.h(s),q=r.h("a3<1,b>"),p=A.q(new A.a3(new A.x(s,r.h("j(1)").a(new A.d9(b,b.r.P(4e6))),r.h("x<1>")),r.h("b(1)").a(new A.da()),q),q.h("c.E"))
if(p.length<2)return 0
return 1-B.b.k(Math.sqrt(B.a.G(p,0,new A.db(B.a.L(p,new A.dc())/p.length),t.i)/p.length)/3,0,1)}}
A.dd.prototype={
$1(a){var s=this.a,r=A.h(s)
return new A.f(s,r.h("b(1)").a(t.bE.a(a)),r.h("f<1,b>")).L(0,new A.de())/s.length},
$S:41}
A.de.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.df.prototype={
$1(a){t.F.a(a)
return B.b.k((a.x-a.w)/B.c.B(a.r.S(a.f).a,1000)*1000/2.5,0,1)},
$S:9}
A.dg.prototype={
$1(a){return 1-B.b.k(this.a.bg(this.b,t.F.a(a))/0.55,0,1)},
$S:9}
A.dh.prototype={
$1(a){return this.a.bX(this.b,t.F.a(a))},
$S:9}
A.d6.prototype={
$1(a){return t.C.a(a).e},
$S:2}
A.d8.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.d7.prototype={
$2(a,b){var s
A.t(a)
s=A.t(b)-this.a
return a+s*s},
$S:0}
A.d9.prototype={
$1(a){t.C.a(a)
return a.a>this.a.e&&!a.b.c.ct(this.b)},
$S:1}
A.da.prototype={
$1(a){return t.C.a(a).b.d},
$S:2}
A.dc.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.db.prototype={
$2(a,b){var s
A.t(a)
s=A.t(b)-this.a
return a+s*s},
$S:0}
A.di.prototype={
$1(a){var s=this.a,r=s.r
return r+(s.w-r)*((a-s.e)/this.b)},
$S:13}
A.z.prototype={
b3(a,b,c,d){var s=this,r=c==null?s.e:c
return new A.z(b,s.b,s.c,s.d,r,a,s.r,s.w,s.x,s.y,s.z,s.Q,d,s.at)},
cl(a,b,c){return this.b3(a,b,null,c)}}
A.dm.prototype={
H(b4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0=this,b1=b4.T(B.r),b2=b1.$ti,b3=b2.h("x<c.E>")
b1=A.q(new A.x(b1,b2.h("j(c.E)").a(new A.dE()),b3),b3.h("c.E"))
b1.$flags=1
s=b1
b1=b4.T(B.K)
b1=A.q(b1,b1.$ti.h("c.E"))
b1.$flags=1
r=b1
b1=b4.T(B.j)
b1=A.q(b1,b1.$ti.h("c.E"))
b1.$flags=1
q=b1
p=A.i([],t.aS)
b1=t.n
o=A.i([],b1)
n=A.h_(t.N)
for(b2=s.length,m=0,l=0,k=0,j=0;j<s.length;s.length===b2||(0,A.D)(s),++j){i=s[j]
if(!(i.as<=0)){b3=i.r
h=i.f
h=A.G(b3.b-h.b,b3.a-h.a).a<=0
b3=h}else b3=!0
if(b3){++m
continue}g=b0.bB(i,q)
b3=i.at
f=B.b.k(1-Math.max(b3.c*0.25,b3.d*0.45),0,1)
if(f<1||g)++k
e=b0.aV(b4,i)
d=b0.bY(e)
if(e>=5){++l
n.l(0,i.a)}b3=g?0.6:1
B.a.l(o,d*f*b3)
B.a.l(p,new A.aN(b0.bk(b4,i,g),Math.max(1,i.w-i.x)))}c=p.length===0
b=c?150:150*b0.cd(p)
a=o.length===0
a0=a?100:100*(1-b0.bj(o))
a1=b0.bA(b4,s)
a2=a1.length===0
a3=b0.bK(a1)
a4=a2?60:60*(1-a3)
b2=A.h(a1)
new A.x(a1,b2.h("j(1)").a(new A.dF()),b2.h("x<1>")).gm(0)
a5=A.i([],b1)
for(b1=r.length,j=0;j<r.length;r.length===b1||(0,A.D)(r),++j){a6=b0.c3(b4,r[j],s,n)
if(a6==null)++m
else B.a.l(a5,a6)}a7=a5.length===0
a8=a7?40:40*b0.Y(a5)
a9=B.b.k(b+a0+a4+a8,0,350)
B.b.k(b,0,150)
B.b.k(a0,0,100)
B.b.k(a4,0,60)
B.b.k(a8,0,40)
return new A.dG(a9,s.length,a5.length,new A.dl(c,a,a2,a7))},
bk(a,a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=a.c,d=a0.d,c=a0.e,b=e.length
if(!(d<b))return A.a(e,d)
s=e[d].b.d
if(!(c<b))return A.a(e,c)
r=e[c].b.d
q=Math.max(0,s-r)
if(q<=0)return 0.5
p=this.aR(e,d,c,0.5)
o=this.aR(e,d,c,0.6)
if(!(p<b))return A.a(e,p)
n=Math.max(0,s-e[p].b.d)
if(!(o<b))return A.a(e,o)
m=Math.max(0,e[o].b.d-r)
l=B.b.k(n/q/0.55,0,1)
k=B.b.k((m/q-0.35)/0.37,0,1)
j=A.i([],t.n)
for(i=d;i<=c;++i){if(!(i<b))return A.a(e,i)
B.a.l(j,e[i].e)}b=B.b.k(this.aZ(j)/0.9,0,1)
h=e[d].b.c.P(-5e6)
g=A.bV(e,0,A.ii(d,"count",t.S),A.h(e).c).R(0,new A.dp(h,a,d,e))?0.08:0
f=a1?0.1:0
return B.b.k(0.4*B.b.k(l+g+f,0,1)+0.3*(1-b)+0.3*(1-k),0,1)},
aV(a,b){var s,r,q,p,o,n
for(s=b.d,r=b.e,q=a.c,p=q.length,o=0;s<=r;++s){if(!(s<p))return A.a(q,s)
n=q[s]
o=Math.max(o,Math.max(-n.b.x,-n.e))}return o},
bY(a){var s=this
if(a<=1.5)return 0
if(a<=2.5)return s.a8(0,0.15,(a-1.5)/1)
if(a<=3.5)return s.a8(0.15,0.35,(a-2.5)/1)
if(a<=5)return s.a8(0.35,0.75,(a-3.5)/1.5)
return s.a8(0.75,1,(a-5)/5)},
bj(a){var s
t.q.a(a)
s=this.Y(a)
if(a.length===1)return Math.min(s,0.35)
return B.b.k(s*1.35,0,1)},
bA(a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a
t.B.a(a1)
s=a0.T(B.m)
r=s.$ti
q=r.h("x<c.E>")
s=A.q(new A.x(s,r.h("j(c.E)").a(new A.dq()),q),q.h("c.E"))
s.$flags=1
p=s
o=A.i([],t.h9)
for(s=p.length,r=a0.a,n=0;n<p.length;p.length===s||(0,A.D)(p),++n){m=p[n]
l=m.x-m.w
if(l<3)continue
for(q=a1.length,k=m.r,j=k.a,k=k.b,i=m.y,h=m.e,g=0;g<a1.length;a1.length===q||(0,A.D)(a1),++g){f=a1[g]
e=f.f
d=e.a
if(d>=j)c=d===j&&e.b<k
else c=!0
if(c)continue
if(r&&!A.eu(h,f.d,new A.dr(a0)))continue
b=A.G(e.b-k,d-j)
if(i<13.88888888888889)a=14
else a=i<25?10.5:7.5
if(b.a>A.G(0,B.b.ae(a*1000)).a)break
if(f.w-f.x<=0)continue
B.a.l(o,new A.al(l,this.aV(a0,f),this.bL(f.at)))
break}}return o},
bK(a){var s,r,q,p,o
t.cT.a(a)
if(a.length===0)return 0
s=A.h(a)
r=s.h("b(1)")
s=s.h("f<1,b>")
q=this.Y(new A.f(a,r.a(new A.du(this)),s))
p=a.length
o=p===1?0.15:B.b.k(p/3,0.45,1)
return B.b.k(q*o*(1-this.Y(new A.f(a,r.a(new A.dv()),s))),0,1)},
c3(a,b,a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=null
t.B.a(a0)
t.cq.a(a1)
s=this.bz(a,b.d)
if(s==null)return c
r=a.c
q=b.e
p=B.a.a7(r,s,q+1)
o=A.h(p)
if(new A.f(p,o.h("b(1)").a(new A.dy()),o.h("f<1,b>")).L(0,B.Y)<4.166666666666667)return c
p=A.h(a0)
o=p.h("x<1>")
n=A.ho(new A.x(a0,p.h("j(1)").a(new A.dz(b,a)),o),o.h("c.E"),t.dd).aA(0,new A.dA(),new A.dB())
if(n!=null&&a1.ac(0,n.a))return c
p=r.length
if(s>>>0!==s||s>=p)return A.a(r,s)
o=r[s]
if(!(q<p))return A.a(r,q)
m=r[q].b
l=Math.max(0,o.b.d-m.d)
if(l<=0)return c
k=m.c.P(-2e6)
o=k.a
m=k.b
i=s
for(;;){if(!(i<=q)){j=s
break}if(!(i<p))return A.a(r,i)
h=r[i].b.c
g=h.a
if(g>=o)h=g===o&&h.b<m
else h=!0
if(!h){j=i
break}++i}if(!(j<p))return A.a(r,j)
f=1-B.b.k((Math.max(0,r[j].b.d-r[q].b.d)/l-0.25)/0.30000000000000004,0,1)
e=A.i([],t.n)
for(i=j;i<=q;++i){if(!(i<p))return A.a(r,i)
B.a.l(e,r[i].e)}d=1-B.b.k(this.aZ(e)/0.8,0,1)
return B.b.k(0.5*f+0.25*d+0.25*B.b.k((f+d)/2,0,1),0,1)},
bz(a,b){var s,r,q,p,o,n
for(s=a.c,r=s.length,q=a.a,p=b;p>=0;--p){o=!1
if(q)if(p<b){if(!(p<r))return A.a(s,p)
o=s[p]
n=p+1
if(!(n<r))return A.a(s,n)
n=!A.b7(o.b,s[n].b)
o=n}if(o)break
if(!(p<r))return A.a(s,p)
if(s[p].b.d>=4.166666666666667)return p}return null},
bB(a,b){t.B.a(b)
return a.ch.ac(0,B.w)||B.a.R(a.CW,new A.dt(b))},
bL(a){var s=a.d,r=Math.max(a.c,s)
if(r<=0)return 0
return B.b.k(0.8*r+0.19999999999999996*s,0,1)},
aR(a,b,c,d){var s,r,q,p,o,n,m
t.X.a(a)
s=a.length
if(!(b<s))return A.a(a,b)
r=a[b].b.c
if(!(c<s))return A.a(a,c)
q=r.P(A.G(0,B.b.ae(B.c.B(a[c].b.c.S(r).a,1000)*d)).a)
for(r=q.a,p=q.b,o=b;o<=c;++o){if(!(o<s))return A.a(a,o)
n=a[o].b.c
m=n.a
if(m>=r)n=m===r&&n.b<p
else n=!0
if(!n)return o}return c},
cd(a){var s,r
t.ap.a(a)
s=t.i
r=B.a.G(a,0,new A.dC(),s)
if(r<=0)return 1
return B.a.G(a,0,new A.dD(),s)/r},
Y(a){var s,r,q
for(s=J.W(t.bM.a(a)),r=0,q=0;s.n();){r+=s.gp();++q}return q===0?0:r/q},
aZ(a){var s
t.q.a(a)
if(a.length<2)return 0
s=A.h(a)
return Math.sqrt(this.Y(new A.f(a,s.h("b(1)").a(new A.dw(this.Y(a))),s.h("f<1,b>"))))},
a8(a,b,c){return a+(b-a)*B.b.k(c,0,1)}}
A.dE.prototype={
$1(a){return t.F.a(a).ax===B.O},
$S:3}
A.dF.prototype={
$1(a){return t.k.a(a).c>0},
$S:20}
A.dp.prototype={
$1(a){var s,r=this
t.C.a(a)
if(!a.b.c.cu(r.a))s=(!r.b.a||A.eu(a.a,r.c,new A.dn(r.d)))&&a.e<-0.08
else s=!1
return s},
$S:1}
A.dn.prototype={
$1(a){var s=this.a
if(!(a>=0&&a<s.length))return A.a(s,a)
return s[a].b},
$S:7}
A.dq.prototype={
$1(a){return t.F.a(a).ax===B.x},
$S:3}
A.dr.prototype={
$1(a){var s=this.a.c
if(!(a>=0&&a<s.length))return A.a(s,a)
return s[a].b},
$S:7}
A.du.prototype={
$1(a){t.k.a(a)
return 0.6*B.b.k(a.a/9,0,1)+0.4*B.b.k(a.b/3.5,0,1)},
$S:14}
A.dv.prototype={
$1(a){return t.k.a(a).c},
$S:14}
A.dy.prototype={
$1(a){return t.C.a(a).b.d},
$S:2}
A.dz.prototype={
$1(a){var s,r,q,p
t.F.a(a)
s=this.a
r=s.f.S(a.r)
q=a.e
s=s.d
if(q<=s){p=this.b
s=(!p.a||A.eu(q,s,new A.dx(p)))&&Math.abs(r.a)<=3e6}else s=!1
return s},
$S:3}
A.dx.prototype={
$1(a){var s=this.a.c
if(!(a>=0&&a<s.length))return A.a(s,a)
return s[a].b},
$S:7}
A.dA.prototype={
$1(a){return t.dd.a(a)!=null},
$S:23}
A.dB.prototype={
$0(){return null},
$S:24}
A.dt.prototype={
$1(a){return B.a.R(this.a,new A.ds(A.v(a)))},
$S:33}
A.ds.prototype={
$1(a){return t.F.a(a).a===this.a},
$S:3}
A.dC.prototype={
$2(a,b){return A.t(a)+t.fz.a(b).b},
$S:15}
A.dD.prototype={
$2(a,b){A.t(a)
t.fz.a(b)
return a+b.a*b.b},
$S:15}
A.dw.prototype={
$1(a){return Math.pow(A.t(a)-this.a,2)},
$S:13}
A.aN.prototype={}
A.al.prototype={}
A.dG.prototype={}
A.dl.prototype={}
A.F.prototype={
gaB(){var s,r=this.a
if(isFinite(r)){s=this.b
r=isFinite(s)&&Math.abs(r)<=90&&Math.abs(s)<=180}else r=!1
return r}}
A.dH.prototype={
b2(a,b,c,d,a0,a1,a2,a3,a4,a5,a6,a7,a8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=t.t
e.a(a0)
e.a(a8)
if(a4&&!a1.at)return f.a5(a,a1,B.ab,"Common road is below the 3000 metre comparison threshold.")
s=B.k.b5(b,c,d,a0,a1,a2,a5,a6,a7,a8)
if(!s.gaD()){e=s.a.a===B.h||s.b.a===B.h?B.ac:B.o
i=s.a.f
if(i==null)i=s.b.f
return f.a5(a,a1,e,i==null?"Common-road telemetry could not be extracted.":i)}if(a3)e=!f.aW(s.a.b)||!f.aW(s.b.b)
else e=!1
if(e)return f.a5(a,a1,B.o,"Reliable comparison window has a telemetry gap or too few samples.")
try{r=a3?B.l.b1(s.a.b):B.l.b0(a,s.a.b)
q=a3?B.l.b1(s.b.b):B.l.b0(a,s.b.b)
p=q.d-r.d
o=r.d<q.d?r.d:q.d
e=o
if(typeof e!=="number")return e.cI()
if(e<=0)h=0
else{e=p
i=o
if(typeof e!=="number")return e.cF()
if(typeof i!=="number")return A.kq(i)
h=e/i}n=h
m=r.d>=q.d*1.01
l=q.d>=r.d*1.01
if(m)e=B.F
else e=l?B.G:B.H
return new A.cn(r,q,p,n,e,!0)}catch(g){e=A.hg(g)
if(e instanceof A.cB){k=e
return f.a5(a,a1,B.o,u.c)}else{j=e
e=f.a5(a,a1,B.ad,J.b5(j))
return e}}},
ck(a,b,c,d,e,f,g){var s=null
return this.b2(a,s,b,s,c,d,0,e,!0,s,f,s,g)},
aW(a){var s,r
t.W.a(a)
s=a.length
if(s<6||B.a.R(a,new A.dI()))return!1
for(r=1;r<s;++r)if(!A.b7(a[r-1],a[r]))return!1
return!0},
a5(a,b,c,d){var s=null
return new A.cn(s,s,s,s,c,!1)}}
A.dI.prototype={
$1(a){t.u.a(a)
return!A.iX(a)||a.Q==="legacy"},
$S:10}
A.cm.prototype={}
A.ap.prototype={
F(){return"CommonRoadScoreComparisonOutcome."+this.b}}
A.cn.prototype={}
A.bs.prototype={
F(){return"CommonRoadTelemetryMappingStatus."+this.b}}
A.aq.prototype={}
A.dM.prototype={
gaD(){return this.a.a===B.p&&this.b.a===B.p}}
A.dJ.prototype={
b5(a,b,c,d,e,f,g,h,i,j){var s,r,q=t.t
q.a(d)
q.a(j)
q=c==null?e.e:c
s=a==null?e.f:a
q=this.aM(s,f,b,e.c,q,d)
s=i==null?e.r:i
r=g==null?e.w:g
return new A.dM(q,this.aM(r,f,h,e.d,s,j))},
az(a,b,c,d,e){var s=null
return this.b5(s,a,s,b,c,0,s,d,s,e)},
aM(b1,b2,b3,b4,b5,b6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0=null
t.t.a(b6)
s=J.cE(b6.slice(0),A.h(b6).c)
if(s.length===0)return new A.aq(B.I,B.i,b0,b0,0,"No canonical telemetry exists.")
r=this.bV(b3,b4)
if(r==null||r.b.length<2)return new A.aq(B.h,B.i,b0,b0,0,"Matched road section is unavailable.")
q=this.bW(b3,b4)
if(q==null)return new A.aq(B.h,B.i,b0,b0,0,"Matched road section offset is unavailable.")
p=r.b
o=A.h3(p)
n=A.hU(r)
if(!isFinite(o)||o<=0||!isFinite(n)||n<=0)return new A.aq(B.h,B.i,b0,b0,0,"Matched section has no valid canonical offset axis.")
m=A.i([],t.cA)
for(l=b5-b2,k=b1+b2,j=0,i=0;i<p.length-1;){h=p[i];++i
g=p[i]
f=h.a
e=h.b
d=g.a
c=g.b
b=A.hx(f,e,d,c)
if(b<=0)continue
a=A.h4(o,j,n)
a0=j+b
if(q+A.h4(o,a0,n)>=l&&q+a<=k){a=f*3.141592653589793/180
a1=111320*Math.cos(a)
e=c-e
a2=e*3.141592653589793/180
a3=d*3.141592653589793/180
a=new A.c5(h,b,j,a1,B.b.X(Math.atan2(Math.sin(a2)*Math.cos(a3),Math.cos(a)*Math.sin(a3)-Math.sin(a)*Math.cos(a3)*Math.cos(a2))*180/3.141592653589793+360,360))
a.f=e*a1
a.r=(d-f)*111320
B.a.l(m,a)}j=a0}a4=A.i([],t.du)
for(a5=0;a5<s.length;++a5){a6=s[a5]
p=a6.a
if(isFinite(p)){f=a6.b
p=isFinite(f)&&Math.abs(p)<=90&&Math.abs(f)<=180}else p=!1
if(!p)continue
a7=this.bQ(a6,m,q,o,n,b5,b1,b2)
p=!0
if(a7!=null)if(!(a7.a>35)){f=a7.c
if(!(f!=null&&f>60)){p=a7.b
p=p<l||p>k}}if(p)continue
B.a.l(a4,new A.af(a5,a6,a7))}if(a4.length<2)return new A.aq(B.I,B.i,b0,b0,0,"Fewer than two canonical samples map to the common road.")
p=t.gM
p=A.q(new A.f(a4,t.fI.a(new A.dK()),p),p.h("n.E"))
p.$flags=1
a8=p
for(p=a8.length,a5=1;a5<p;++a5){l=a8[a5].c
k=a8[a5-1].c
f=l.a
e=k.a
if(f<=e)l=f===e&&l.b>k.b
else l=!0
if(!l)return new A.aq(B.h,B.i,b0,b0,0,"Mapped telemetry does not preserve strict time order.")}a9=B.b.k(1-B.a.G(a4,0,new A.dL(),t.i)/a4.length/35,0,1)
return new A.aq(B.p,A.T(a8,t.u),B.a.gI(a4).a,B.a.gV(a4).a,a9,b0)},
bV(a,b){var s,r,q=a.d,p=q.length
if(p!==0){for(s=0;s<p;++s){r=q[s]
if(r.a===b)return r}return null}return b===a.a+":geometry"?new A.U(b,a.c,a.e):null},
bW(a,b){var s,r,q,p,o,n=a.d,m=n.length
if(m===0)return b===a.a+":geometry"?0:null
for(s=0,r=0;r<n.length;n.length===m||(0,A.D)(n),++r){q=n[r]
if(q.a===b)return s
p=q.c
o=A.h3(q.b)
s+=isFinite(p)&&p>0?p:o}return null},
bQ(a1,a2,a3,a4,a5,a6,a7,a8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0
t.fT.a(a2)
for(s=a2.length,r=a6-a8,q=a1.e,p=a1.b,o=a1.a,n=a7+a8,m=null,l=!1,k=0;k<a2.length;a2.length===s||(0,A.D)(a2),++k){j=a2[k]
i=j.a
h=(p-i.b)*j.d
g=(o-i.a)*111320
i=j.f
i===$&&A.iq()
f=j.r
f===$&&A.iq()
e=i*i+f*f
d=e<=0?0:B.b.k((h*i+g*f)/e,0,1)
i=h-i*d
f=g-f*d
f=Math.sqrt(i*i+f*f)
i=a3+A.h4(a4,j.c+j.b*d,a5)
c=A.jN(q,j.e)
b=new A.fq(f,i,c)
a=i>=r&&i<=n
i=!0
if(m!=null)if(!(a&&!l))if(a===l){a0=m.a
if(!(f<a0))if(Math.abs(f-a0)<=0.000001){i=c==null?1/0:c
f=m.c
i=i<(f==null?1/0:f)}else i=!1}else i=!1
if(i){l=a
m=b}}return m}}
A.dK.prototype={
$1(a){return t.ei.a(a).b},
$S:52}
A.dL.prototype={
$2(a,b){return A.t(a)+t.ei.a(b).c.a},
$S:61}
A.c5.prototype={
gm(a){return this.b}}
A.af.prototype={}
A.fq.prototype={}
A.cr.prototype={
H(a){var s,r,q,p,o,n,m=A.i([],t.df)
for(s=a.T(B.j),r=J.W(s.a),s=new A.ae(r,s.b,s.$ti.h("ae<1>")),q=0,p=0;s.n();){o=r.gp()
n=this.bt(a,o)
if(n==null){++q
if(o.as<0.5)++p}else B.a.l(m,n)}if(m.length===0)return new A.cq(0,!1,!1)
s=new A.dT(this,m)
s=B.b.k(s.$1(new A.dP())*60+s.$1(new A.dQ())*35+s.$1(new A.dR())*35+s.$1(new A.dS())*20,0,150)
r=m.length
A.T(m,t.v)
return new A.cq(s,!0,r>=2)},
bt(a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=null
if(a1.ax!==B.P||a1.as<0.5||a1.Q<15)return a
s=a1.cx
r=s.i(0,"totalHeadingChangeDegrees")
if(r==null)r=0
if(r<15)return a
q=a0.c
s=s.i(0,"apexIndex")
p=a1.d
o=a1.e
n=B.c.ba(B.c.k(B.b.ae(s==null?(a1.d+a1.e)/2:s),p,o))
m=Math.max(p,p+B.c.B(n-p,2))
l=Math.min(o,n+B.c.B(o-n,2))
k=b.am(q,p,m)
j=b.am(q,Math.max(p,n-1),Math.min(o,n+1))
i=b.am(q,l,b.bS(q,o))
if(k<10)return a
s=a1.at
h=Math.max(s.c,s.d)
if(h>=0.6&&k<12)return a
g=r*3.141592653589793/180
f=g<=0?500:a1.Q/g
e=B.b.k(0.55*((r-15)/75)+0.45*((500-f)/475),0,1)
d=1-B.b.k((B.b.k((k-j)/k,0,1)-b.aS(0.08,0.48,e))/0.32,0,1)
if(h>0)d=b.aS(d,1,h*0.35)
s=B.b.k(b.aT(b.aq(q,p,n),k)/0.18,0,1)
c=B.b.k(B.b.k(i/k,0,1.1)/0.95,0,1)
o=B.b.k(b.aT(b.aq(q,p,o),k)/0.06,0,1)
A.T(a1.CW,t.N)
return new A.ag(r,e,a1.as,d,1-s,c,1-o)},
bS(a,b){var s,r,q,p,o,n,m,l,k
t.X.a(a)
s=a.length
if(!(b<s))return A.a(a,b)
r=a[b].b.c.P(3e6)
for(q=b+1,p=r.a,o=r.b,n=b;q<s;m=q+1,n=q,q=m){l=a[q].b.c
k=l.a
if(k<=p)l=k===p&&l.b>o
else l=!0
if(l)break}return n},
aq(a,b,c){var s,r,q
t.X.a(a)
s=A.i([],t.n)
for(r=a.length,q=b;q<=c;++q){if(!(q>=0&&q<r))return A.a(a,q)
s.push(a[q].b.d)}return s},
am(a,b,c){var s,r,q,p=this.aq(t.X.a(a),b,c)
B.a.aH(p)
s=p.length
r=s/2|0
if((s&1)===1){if(!(r<s))return A.a(p,r)
s=p[r]}else{q=r-1
if(!(q>=0&&q<s))return A.a(p,q)
q=p[q]
if(!(r<s))return A.a(p,r)
q=(q+p[r])/2
s=q}return s},
aT(a,b){var s,r,q,p,o,n
t.q.a(a)
if(a.length<2||b<=0)return 0
s=B.a.L(a,new A.dO())
r=a.length
q=s/r
for(p=0,o=0;o<r;++o){n=a[o]-q
p+=n*n}return Math.sqrt(p/r)/b},
cc(a){t.v.a(a)
return Math.min(1.5,Math.max(0.25,a.w*(0.5+a.r)*(a.e/30)))},
aS(a,b,c){return a+(b-a)*B.b.k(c,0,1)}}
A.dT.prototype={
$1(a){var s,r,q,p,o,n,m,l,k
t.bk.a(a)
s=this.b
r=A.h(s)
q=r.h("f<1,b>")
r=A.q(new A.f(s,r.h("b(1)").a(this.a.gcb()),q),q.h("n.E"))
r.$flags=1
p=r
r=t.i
o=B.a.G(p,0,new A.dU(),r)
n=s.length
m=J.hy(n,r)
for(l=0;l<n;++l){if(!(l<s.length))return A.a(s,l)
q=a.$1(s[l])
if(!(l<p.length))return A.a(p,l)
k=p[l]
if(typeof q!=="number")return q.aF()
m[l]=q*k}return B.a.G(m,0,new A.dV(),r)/o},
$S:22}
A.dU.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.dV.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.dP.prototype={
$1(a){return a.x},
$S:4}
A.dQ.prototype={
$1(a){return a.y},
$S:4}
A.dR.prototype={
$1(a){return a.z},
$S:4}
A.dS.prototype={
$1(a){return a.Q},
$S:4}
A.dO.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.cq.prototype={}
A.ag.prototype={}
A.e0.prototype={
co(b4,b5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3=null
t.W.a(b4)
if(b4.length===0)return B.R
s=t.I
r=new A.bK(A.bL(A.j4(b3),b3,!1,s),t.d9)
q=A.i([],t.M)
for(p=0,o=0,n=0,m=0,l=0,k=0,j=0;j<b4.length;++j){i=b4[j]
h=!1
if(b5)if(!i.y){g=i.Q
if(g!=="unavailable"&&g!=="held_estimate"){if(j>0){h=b4[j-1].Q
h=!(h!=="unavailable"&&h!=="held_estimate")}}else h=!0}else h=!0
if(h){r.cj(0)
p=0
o=0
n=0
m=0
l=0
k=0}B.a.q(r.a,r.c,j)
h=r.c
g=r.a.length
h=(h+1&g-1)>>>0
r.c=h
if(r.b===h){f=A.bL(g*2,b3,!1,s)
h=r.a
g=r.b
e=h.length-g
B.a.aG(f,0,e,h,g)
B.a.aG(f,e,e+r.b,r.a,0)
r.b=0
r.c=r.a.length
r.a=f}++r.d
h=i.d
p+=h
o+=h*h
if(h<=8.333333333333334)++n
g=i.c
d=g.P(-5e6)
c=d.a
b=d.b
for(;;){a=r.c
a0=r.b
a1=r.a
a2=a1.length
if((a-a0&a2-1)>>>0>1){if(a0===a)A.b3(A.aT())
if(!(a0<a2))return A.a(a1,a0)
a=a1[a0]
a=B.a.i(b4,a==null?A.a0(a):a).c
a0=a.a
if(a0>=c)a=a0===c&&a.b<b
else a=!0}else a=!1
if(!a)break
a=r.b
if(a===r.c)A.b3(A.aT());++r.d
a0=r.a
if(!(a<a0.length))return A.a(a0,a)
a3=a0[a]
if(a3==null)a3=A.a0(a3)
B.a.q(a0,a,b3)
r.b=(r.b+1&r.a.length-1)>>>0
a=B.a.i(b4,a3).d
p-=a
o-=a*a
if(a<=8.333333333333334)--n}a4=(r.c-r.b&r.a.length-1)>>>0
a5=p/a4
a6=B.b.k(o/a4-a5*a5,0,1/0)
c=i.as
if(!c||i.y)m=0
else{b=i.x
m=j===0?b:m+0.35*(b-m)}a7=0
a8=0
if(j>0){b=j-1
if(!(b<b4.length))return A.a(b4,b)
a9=b4[b]
b=a9.c
b0=A.G(g.b-b.b,g.a-b.a).a/1e6
g=!i.y
b1=0
b2=0
if(!g||!c){k=b2
l=b1}else if(b0>0)if(h<=1.3888888888888888){l+=b0
k=b2}else{k+=b0
l=b1}if(b0>0&&g&&c&&h>=4){a7=this.bZ(a9.e,i.e)
a8=Math.abs(a7)/b0}}B.a.l(q,new A.a5(j,i,a6,m,a7,a8))}return q},
bZ(a,b){if(!isFinite(a)||!isFinite(b))return 0
return B.b.X(b-a+540,360)-180}}
A.ct.prototype={
cg(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this
t.t.a(c)
s=J.cE(c.slice(0),A.h(c).c)
r=B.a1.co(b?A.iV(s):s,b)
if(r.length===0)return new A.cs(b,B.R,B.aP,B.aQ)
q=d.bw(r)
p=d.a3(r,new A.e3(),new A.e4(),B.an,new A.e5(d,r))
o=d.a3(r,new A.ef(),new A.eg(),B.N,new A.eh(r))
n=d.a3(r,new A.ei(),new A.ej(),B.N,new A.ek(r))
m=d.gbE()
l=d.a3(r,m,m,B.ap,new A.el())
k=d.a3(r,new A.em(),new A.e6(),B.am,new A.e7(d,r))
j=A.bL(r.length,B.L,!1,t.fR)
d.ab(j,l,B.ah)
d.ab(j,o,B.ag)
d.ab(j,n,B.ai)
d.ab(j,p,B.M)
m=A.h(p)
i=t.F
m=A.q(new A.f(p,m.h("p(1)").a(new A.e8(d,a,r,q)),m.h("f<1,p>")),i)
h=A.h(o)
B.a.A(m,new A.f(o,h.h("p(1)").a(new A.e9(d,a,r,q)),h.h("f<1,p>")))
h=A.h(n)
B.a.A(m,new A.f(n,h.h("p(1)").a(new A.ea(d,a,r,q)),h.h("f<1,p>")))
h=A.h(k)
B.a.A(m,new A.f(k,h.h("p(1)").a(new A.eb(d,a,r,q)),h.h("f<1,p>")))
g=A.h(l)
B.a.A(m,new A.f(l,g.h("p(1)").a(new A.ec(d,a,r,q)),g.h("f<1,p>")))
B.a.a1(m,new A.ed())
g=A.T(r,t.C)
f=t.gE
e=A.T(d.bq(j,r,b),f)
A.T(new A.f(k,h.h("@(1)").a(new A.ee(r)),h.h("f<1,@>")),f)
A.T(q,t.fo)
return new A.cs(b,g,e,A.T(d.bU(m),i))},
bF(a){return a.b.d>=5&&Math.abs(a.e)<=0.3&&a.d<=1.5},
a3(a,b,c,d,e){var s,r,q,p,o,n,m,l,k,j=null
t.X.a(a)
s=t.d1
s.a(c)
s.a(b)
t.fW.a(e)
r=A.i([],t.dO)
for(q=j,p=q,o=0;o<a.length;++o){n=a[o]
s=n.b
if(!s.y){m=s.Q
m=!(m!=="unavailable"&&m!=="held_estimate")}else m=!0
l=j
k=j
if(m){if(p!=null&&q!=null)this.al(r,a,p,q,d,e)
m=s.Q
if(!(m!=="unavailable"&&m!=="held_estimate")){q=k
p=l
continue}q=k
p=l}if(p==null){if(c.$1(n)){q=o
p=q}continue}if(b.$1(n)){q=o
continue}s=s.c
q.toString
if(!(q<a.length))return A.a(a,q)
m=a[q].b.c
if(A.G(s.b-m.b,s.a-m.a).a<=1e6)continue
this.al(r,a,p,q,d,e)
p=c.$1(n)?o:j
q=p}if(p!=null&&q!=null)this.al(r,a,p,q,d,e)
return r},
al(a,b,c,d,e,f){var s,r,q
t.e.a(a)
t.X.a(b)
A.a0(d)
t.fW.a(f)
s=new A.a6(c,d)
r=b.length
if(!(d<r))return A.a(b,d)
q=b[d]
if(!(c<r))return A.a(b,c)
if(q.b.c.S(b[c].b.c).a>=e.a&&f.$1(s))B.a.l(a,s)},
bw(b4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3
t.X.a(b4)
s=A.i([],t.gI)
for(r=0,q=0;q<b4.length;++q){p=b4[q].b
o=p.Q
if(!(o!=="unavailable"&&o!=="held_estimate")){B.a.l(s,B.X)
r=q+1
continue}if(p.y)r=q
n=p.c.P(-45e6)
p=n.a
o=b4.length
m=n.b
for(;;){if(r<q){if(!(r>=0&&r<o))return A.a(b4,r)
l=b4[r].b.c
k=l.a
if(k>=p)l=k===p&&l.b<m
else l=!0}else l=!1
if(!l)break;++r}if(!(q<o))return A.a(b4,q)
p=b4[q].b.c
if(!(r>=0&&r<o))return A.a(b4,r)
m=b4[r].b.c
if(A.G(p.b-m.b,p.a-m.a).a<8e6){B.a.l(s,B.X)
continue}for(j=r,i=0,h=0,g=0,f=0,e=0,d=0,c=!1,b=0;j<=q;++j,c=a1){if(!(j<o))return A.a(b4,j)
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
p=a3!==0
if(p&&b!==0&&a3!==b)++d
if(p)b=a3}a4=q-r+1
a5=i/a4
a6=Math.max(0,h/a4-a5*a5)
a7=g/a4
a8=B.b.k(1-a5/8.333333333333334,0,1)
a9=B.b.k(a6/25,0,1)
b0=B.b.k(e/4,0,1)
b1=B.b.k(d/4,0,1)
b2=B.b.k(a7*0.45+a8*0.35+a9*0.2,0,1)
b3=B.b.k(a7*0.3+f/a4*0.25+b0*0.25+b1*0.2,0,1)
if(b3>=0.62)B.a.l(s,new A.aA(B.b3,b2,b3))
else if(b2>=0.55)B.a.l(s,new A.aA(B.b2,b2,b3))
else{B.b.k(1-Math.max(b2,b3),0,1)
B.a.l(s,new A.aA(B.b1,b2,b3))}}return s},
a4(a,b,a0,a1,a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=this
t.X.a(a1)
t.dr.a(a2)
for(s=a0.a,r=a0.b,q=a1.length,p=s,o=0,n=1/0;p<=r;++p){if(!(p<q))return A.a(a1,p)
m=a1[p].b.d
o=Math.max(o,m)
n=Math.min(n,m)}l=s+B.c.B(r-s,2)
if(!(l>=0&&l<a2.length))return A.a(a2,l)
k=a2[l]
j=A.h_(t.V)
i=c.c5(k.a)
if(i!=null)j.l(0,i)
h=c.bM(b)
g=A.a8(t.N,t.i)
if(b===B.j){g.q(0,"totalHeadingChangeDegrees",c.aP(a1,s,r))
g.q(0,"apexIndex",c.bu(a1,a0))
j.l(0,B.w)}else j.l(0,c.ar(b))
q=a1.length
if(!(r<q))return A.a(a1,r)
f=a1[r]
if(!(s<q))return A.a(a1,s)
e=B.b.k(B.c.B(f.b.c.S(a1[s].b.c).a,1000)/1000/5,0.5,1)
f=a1.length
if(!(s<f))return A.a(a1,s)
q=a1[s].b
if(!(r<f))return A.a(a1,r)
f=a1[r].b
d=n===1/0?0:n
return A.hv(e,j,c.ai(a1,s,r),a,r,f.d,f.c,a+":"+b.b+":"+s+":"+r,o,g,d,B.S,A.j3([h],t.c5),h,s,q.d,q.c,k,b)},
bU(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
t.B.a(a)
s=t.N
r=A.a8(s,t.dg)
for(q=a.length,p=t.s,o=0;n=a.length,o<n;a.length===q||(0,A.D)(a),++o)r.q(0,a[o].a,A.i([],p))
s=A.a8(s,t.fj)
for(q=t.V,o=0;p=a.length,o<p;a.length===n||(0,A.D)(a),++o){m=a[o]
p=A.hE(q)
p.A(0,m.ch)
s.q(0,m.a,p)}for(q=p,l=0;l<q;q=g,l=j){if(!(l<q))return A.a(a,l)
k=a[l]
for(j=l+1,q=k.a,p=k.c,n=k.d,i=k.e,h=j;g=a.length,h<g;++h){f=a[h]
if(f.d>i)break
if(f.e<n)continue
g=r.i(0,q)
g.toString
e=f.a
B.a.l(g,e)
g=r.i(0,e)
g.toString
B.a.l(g,q)
g=s.i(0,q)
g.toString
g.l(0,this.ar(f.c))
e=s.i(0,e)
e.toString
e.l(0,this.ar(p))}}q=A.h(a)
p=q.h("f<1,p>")
s=A.q(new A.f(a,q.h("p(1)").a(new A.e2(s,r)),p),p.h("n.E"))
s.$flags=1
return s},
bM(a){var s
switch(a.a){case 0:s=B.ay
break
case 1:s=B.x
break
case 2:s=B.O
break
case 3:s=B.P
break
case 4:s=B.Q
break
default:s=null}return s},
ar(a){var s
switch(a.a){case 0:s=B.ar
break
case 1:s=B.as
break
case 2:s=B.au
break
case 3:s=B.w
break
case 4:s=B.at
break
default:s=null}return s},
c5(a){var s=null
switch(a.a){case 3:s=B.ax
break
case 2:s=B.aw
break
case 1:s=B.av
break
case 0:break}return s},
ab(a,b,c){var s,r,q,p,o
t.e2.a(a)
t.e.a(b)
for(s=b.length,r=0;r<b.length;b.length===s||(0,A.D)(b),++r){q=b[r]
for(p=q.a,o=q.b;p<=o;++p)B.a.q(a,p,c)}},
bq(a,b,c){var s,r,q,p,o,n,m
t.e2.a(a)
t.X.a(b)
s=A.i([],t.G)
for(r=a.length,q=0,p=1;p<=r;++p){o=!1
if(p<r){n=a[p]
if(!(q>=0&&q<r))return A.a(a,q)
if(n===a[q])if(c){if(!(p<b.length))return A.a(b,p)
o=!b[p].b.y}else o=!0}if(o)continue
if(!(q>=0&&q<r))return A.a(a,q)
o=a[q]
n=p-1
m=b.length
if(!(q<m))return A.a(b,q)
if(!(n<m))return A.a(b,n)
B.a.l(s,new A.as(o,q,n))
q=p}return s},
ai(a,b,c){var s,r,q
t.X.a(a)
for(s=b+1,r=a.length,q=0;s<=c;++s){if(!(s<r))return A.a(a,s)
q+=a[s].b.w}return q},
aP(a,b,c){var s,r,q
t.X.a(a)
for(s=b+1,r=a.length,q=0;s<=c;++s){if(!(s<r))return A.a(a,s)
q+=Math.abs(a[s].f)}return q},
bu(a,b){var s,r,q,p,o,n
t.X.a(a)
s=b.a
for(r=b.b,q=a.length,p=s,o=0;p<=r;++p){if(!(p<q))return A.a(a,p)
n=a[p].r
if(n>o){o=n
s=p}}return s}}
A.e4.prototype={
$1(a){return a.b.d<=1.3888888888888888},
$S:1}
A.e3.prototype={
$1(a){return a.b.d<=1.3888888888888888},
$S:1}
A.e5.prototype={
$1(a){return this.a.ai(this.b,a.a,a.b)<=8},
$S:5}
A.eg.prototype={
$1(a){return a.e>=0.35},
$S:1}
A.ef.prototype={
$1(a){return a.e>=0.15},
$S:1}
A.eh.prototype={
$1(a){var s,r=this.a,q=a.b,p=r.length
if(!(q<p))return A.a(r,q)
q=r[q]
s=a.a
if(!(s<p))return A.a(r,s)
return q.b.d-r[s].b.d>=2},
$S:5}
A.ej.prototype={
$1(a){return a.e<=-0.35},
$S:1}
A.ei.prototype={
$1(a){return a.e<=-0.15},
$S:1}
A.ek.prototype={
$1(a){var s,r=this.a,q=a.a,p=r.length
if(!(q<p))return A.a(r,q)
q=r[q]
s=a.b
if(!(s<p))return A.a(r,s)
return q.b.d-r[s].b.d>=2},
$S:5}
A.el.prototype={
$1(a){return!0},
$S:5}
A.e6.prototype={
$1(a){return a.b.d>=4&&a.r>=4},
$S:1}
A.em.prototype={
$1(a){return a.b.d>=4&&a.r>=2},
$S:1}
A.e7.prototype={
$1(a){var s=this.a,r=this.b,q=a.a,p=a.b
return s.aP(r,q,p)>=15&&s.ai(r,q,p)>=15},
$S:5}
A.e8.prototype={
$1(a){var s=this
return s.a.a4(s.b,B.K,t.Q.a(a),s.c,s.d)},
$S:6}
A.e9.prototype={
$1(a){var s=this
return s.a.a4(s.b,B.m,t.Q.a(a),s.c,s.d)},
$S:6}
A.ea.prototype={
$1(a){var s=this
return s.a.a4(s.b,B.r,t.Q.a(a),s.c,s.d)},
$S:6}
A.eb.prototype={
$1(a){var s=this
return s.a.a4(s.b,B.j,t.Q.a(a),s.c,s.d)},
$S:6}
A.ec.prototype={
$1(a){var s=this
return s.a.a4(s.b,B.n,t.Q.a(a),s.c,s.d)},
$S:6}
A.ed.prototype={
$2(a,b){var s,r=t.F
r.a(a)
r.a(b)
s=B.c.C(a.d,b.d)
return s!==0?s:B.c.C(a.c.a,b.c.a)},
$S:25}
A.ee.prototype={
$1(a){var s,r,q,p
t.Q.a(a)
s=a.a
r=a.b
q=this.a
p=q.length
if(!(s<p))return A.a(q,s)
if(!(r<p))return A.a(q,r)
return new A.as(B.aj,s,r)},
$S:26}
A.e2.prototype={
$1(a){var s,r,q
t.F.a(a)
s=a.a
r=this.a.i(0,s)
r.toString
r=A.hF(r,t.V)
q=this.b.i(0,s)
q.toString
q=A.T(q,t.N)
r=t.eN.a(new A.c_(r,t.f4))
t.gJ.a(q)
return A.hv(a.as,r,a.Q,a.b,a.e,a.x,a.r,s,a.y,a.cx,a.z,q,a.ay,a.ax,a.d,a.w,a.f,a.at,a.c)},
$S:27}
A.a6.prototype={}
A.en.prototype={
F(){return"DriveScoreAlgorithmVersion."+this.b}}
A.eo.prototype={
b0(a,b){var s,r
t.t.a(b)
s=J.cE(b.slice(0),A.h(b).c)
if(s.length<2)throw A.d(B.D)
if(B.a.R(s,new A.eq()))throw A.d(B.E)
switch(a.a){case 0:r=this.aJ(s,!1)
break
default:r=null}return r},
b1(a){var s,r
t.t.a(a)
s=J.cE(a.slice(0),A.h(a).c)
if(s.length<2)throw A.d(B.D)
if(B.a.R(s,new A.ep()))throw A.d(B.E)
r=this.aJ(s,!0)
return new A.cu("reliable_intervals",1,1,r.d,r.e,r.f,r.r,r.w,r.x,r.y)},
aJ(a,b){var s,r,q,p,o,n,m=B.a2.cg("in-memory-drive-score",b,t.W.a(a)),l=B.a_.H(m),k=B.a8.H(m),j=B.a0.H(m),i=B.a4.H(m),h=B.Z.H(m),g=B.a9.H(m),f=l.z
f=f.a&&f.b&&f.c&&f.d
s=l.f>0||l.r>0
r=k.as.a
q=t.N
p=t.R
o=A.L(["brakingAnticipation",new A.K(l.a,350,!f,s),"tempoPerformance",new A.K(k.a,150,r,r),"corneringPerformance",new A.K(j.a,150,j.y,j.z),"drivingSmoothness",new A.K(i.a,100,i.b,i.c),"accelerationPerformance",new A.K(h.a,50,h.e,h.f),"transitionControl",new A.K(g.a,50,g.e,g.f)],q,p)
n=B.a5.be(k.r,new A.ac(o,A.k(o).h("ac<2>")))
p=A.hC(q,p)
p.A(0,o)
p.q(0,"drivingEndurance",new A.K(n.a,150,n.f,n.r))
return B.a3.cf(p)}}
A.eq.prototype={
$1(a){return!t.u.a(a).gaB()},
$S:10}
A.ep.prototype={
$1(a){return!t.u.a(a).gaB()},
$S:10}
A.cB.prototype={
j(a){return u.c}}
A.eF.prototype={
j(a){return"Canonical telemetry contains an invalid coordinate."}}
A.er.prototype={
cf(a){var s,r,q,p,o,n,m,l,k,j,i
t.cC.a(a)
s=t.N
r=t.D
q=A.a8(s,r)
for(p=new A.bG(a,A.k(a).h("bG<1,2>")).gt(0),o=0;p.n();){n=p.d
m=n.b
l=m.c
if(l&&m.d)k=B.J
else k=!l?B.ae:B.af
l=k===B.J
j=l?m.a:m.b*0.75
if(l)++o
q.q(0,n.a,new A.aG(j,k))}i=B.b.k(new A.ac(q,q.$ti.h("ac<2>")).G(0,0,new A.es(),t.i),0,1000)
p=B.b.ae(i)
return new A.cu("legacy_v1",1,null,i,B.b.k(o/a.a,0,1),p,1,A.hr(a,s,t.R),A.hr(q,s,r),"Actual scores plus neutral contributions for unavailable evidence.")}}
A.es.prototype={
$2(a,b){return A.t(a)+t.D.a(b).b},
$S:28}
A.bv.prototype={
F(){return"DriveScoreContributionSource."+this.b}}
A.K.prototype={}
A.aG.prototype={}
A.cu.prototype={}
A.et.prototype={
gb4(){var s=this.a
return s!=null&&s>0&&this.b*5>=s*4},
gb9(){return this.e>=6&&this.c>=9e7}}
A.ai.prototype={
F(){return"DrivingPhase."+this.b}}
A.bh.prototype={
F(){return"TrafficRegime."+this.b}}
A.aS.prototype={
F(){return"DrivingEventType."+this.b}}
A.aH.prototype={
F(){return"EventOwnerDomain."+this.b}}
A.X.prototype={
F(){return"EventContextTag."+this.b}}
A.a5.prototype={}
A.aA.prototype={}
A.as.prototype={}
A.p.prototype={}
A.cs.prototype={
T(a){var s=this.r,r=A.h(s)
return new A.x(s,r.h("j(1)").a(new A.e1(a)),r.h("x<1>"))}}
A.e1.prototype={
$1(a){return t.F.a(a).c===this.a},
$S:3}
A.ev.prototype={
H(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=A.i([],t.h)
for(s=a.T(B.n),r=J.W(s.a),s=new A.ae(r,s.b,s.$ti.h("ae<1>")),q=0;s.n();){p=r.gp()
o=p.at
n=Math.max(o.c,o.d)
if(p.ax===B.Q){o=p.r
m=p.f
o=A.G(o.b-m.b,o.a-m.a).a<8e6||p.y<8.333333333333334||n>=0.65}else o=!0
if(o)++q
else B.a.l(d,p)}s=d.length
if(s===0)return new A.cv(0,!1,!1)
for(l=0,k=B.ak,j=0,i=0;i<d.length;d.length===s||(0,A.D)(d),++i){h=d[i]
r=h.r
p=h.f
g=r.a-p.a
f=r.b-p.b
l+=A.G(f,g).a
if(A.G(f,g).a>k.a)k=A.G(f,g)
j+=B.b.k(1-this.ca(a,h)/4,0,1)*A.G(f,g).a}e=A.G(l,0)
s=B.b.k((0.55*this.bv(e,B.aq,B.al,B.ao)+0.45*(j/l))*100,0,1)
r=e.a
B.c.B(r,1e6)
return new A.cv(s*100,!0,r>=3e7)},
ca(a,b){var s=B.a.a7(a.c,b.d,b.e+1),r=A.h(s),q=r.h("f<1,b>"),p=A.q(new A.f(s,r.h("b(1)").a(new A.ew()),q),q.h("n.E"))
return B.a.G(p,0,new A.ex(B.a.L(p,new A.ey())/p.length),t.i)/p.length},
bv(a,b,c,d){var s,r=a.a,q=b.a
if(r<=q)return 0
s=c.a
if(r<=s)return 0.75*(r-q)/(s-q)
return 0.75+0.25*B.b.k((r-s)/(d.a-s),0,1)}}
A.ew.prototype={
$1(a){return t.C.a(a).b.d},
$S:2}
A.ey.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.ex.prototype={
$2(a,b){var s
A.t(a)
s=A.t(b)-this.a
return a+s*s},
$S:0}
A.ez.prototype={
be(a,b){var s,r,q,p,o
t.ff.a(b)
s=b.$ti
r=s.h("x<c.E>")
q=A.q(new A.x(b,s.h("j(c.E)").a(new A.eA()),r),r.h("c.E"))
if(a<5||q.length===0)return new A.cw(0,!1,!1)
p=this.bO(a)
s=A.h(q)
o=B.b.k(new A.f(q,s.h("b(1)").a(new A.eB()),s.h("f<1,b>")).L(0,new A.eC())/q.length,0.15,1)
B.b.k(q.length/6,0,1)
s=a>=50&&q.length>=3
return new A.cw(p*o*150,!0,s)},
bO(a){if(a<=5)return a/5*0.15
if(a<=50)return 0.15+(a-5)/45*0.6
return B.b.k(0.75+(a-50)/100*0.25,0,1)}}
A.eA.prototype={
$1(a){t.R.a(a)
return a.c&&a.d},
$S:29}
A.eB.prototype={
$1(a){t.R.a(a)
return a.a/a.b},
$S:30}
A.eC.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.cw.prototype={}
A.cv.prototype={}
A.cg.prototype={}
A.aj.prototype={
F(){return"DrivingTransitionType."+this.b}}
A.ab.prototype={}
A.cR.prototype={}
A.bd.prototype={
F(){return"LocalRoadWindowState."+this.b}}
A.bM.prototype={
F(){return"LocalRoadRegionAnalysisStatus."+this.b}}
A.aJ.prototype={}
A.Y.prototype={}
A.bN.prototype={}
A.eN.prototype={
ci(a,b,c,d,e,f,g){var s,r,q,p=t.t
p.a(e)
p.a(c)
if(!f.at)return new A.bN(B.aV,B.T,B.U)
if(f.as<0.65)return new A.bN(B.aW,B.T,B.U)
s=B.k.az(d,e,f,b,c)
r=this.bn(a,b,s.b.b,d,s.a.b,f,g)
q=this.ce(a,f,g,r)
return new A.bN(B.aU,A.T(r,t.l),A.T(q,t.m))},
bn(a,b,c,d,a0,a1,a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=t.t
e.a(a0)
e.a(c)
s=A.i([],t.d)
for(r=a1.z,e=a1.e,q=a1.f,p=a1.r,o=a1.w,n=f.a,m=0;m<r;m=l){l=m+100
l=l<r?l:r
k=f.aa(e,q,r,m)
j=f.aa(e,q,r,l)
i=f.aa(p,o,r,m)
h=f.aa(p,o,r,l)
g=n.b2(a,j,d,k,a0,a1,5,a2,!1,h,b,i,c)
B.a.l(s,new A.aJ(m,l,k,j,i,h,f.c2(g),g))}return s},
ce(a,b,c,d){var s,r,q,p,o,n,m,l,k,j,i={}
t.fB.a(d)
s=A.i([],t.r)
i.a=null
i.b=0
r=new A.eO(i,s,b,a)
for(q=d.length,p=0;p<d.length;d.length===q||(0,A.D)(d),++p){o=d[p]
if(c&&o.r===B.z){r.$0()
continue}if(o.r===B.W){n=i.a
m=o.b
l=o.d
k=o.f
if(n==null)i.a=new A.fA(o.a,m,o.c,l,o.e,k)
else{n.b=m
n.d=l
n.f=k;++n.w}i.b=0
continue}if(i.a==null)continue
j=i.b+(o.b-o.a)
i.b=j
if(j>200.000001)r.$0()}r.$0()
return s},
c2(a){var s,r
if(!a.y)return B.z
s=a.x
A:{if(B.F===s){r=B.aX
break A}if(B.G===s){r=B.W
break A}if(B.H===s){r=B.aY
break A}r=B.z
break A}return r},
aa(a,b,c,d){if(c<=0)return a
return a+(b-a)*d/c}}
A.eO.prototype={
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
B.a.l(j.b,new A.Y(p.a,p.b,p,o,n,m,l,r,s,q,j.d,k,h.w))}i.a=null
i.b=0},
$S:31}
A.fA.prototype={}
A.Z.prototype={}
A.U.prototype={}
A.eV.prototype={
H(b3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9=this,b0=1e6,b1=b3.c,b2=b1.length
if(b2<2)return new A.bX(0,0,B.b_)
for(s=b3.a,r=b2-1,q=!s,p=0,o=0,n=0,m=0,l=0,k=0,j=0;j<b2;++j){if(q)m+=b1[j].b.w
if(j===r)continue
i=b1[j]
h=j+1
if(!(h<b2))return A.a(b1,h)
h=b1[h].b
g=h.c
f=i.b
e=f.c
g=A.G(g.b-e.b,g.a-e.a).a
e=!0
if(g>0)if(s){if(A.b7(f,h)){d=f.Q
if(d!=="unavailable"&&d!=="held_estimate"){d=f.d
d=isFinite(d)&&d>=0&&d<=70}else d=!1
if(d){e=h.Q
if(e!=="unavailable"&&e!=="held_estimate"){e=h.d
e=isFinite(e)&&e>=0&&e<=70}else e=!1
e=!e}}}else e=!1
if(e){++l
continue}k+=g
if(s)m+=h.w
if(s){e=f.Q
d=e!=="unavailable"
if(d&&e!=="held_estimate"){c=f.d
c=isFinite(c)&&c>=0&&c<=70}else c=!1
if(c){c=h.Q
if(c!=="unavailable"&&c!=="held_estimate"){c=h.d
c=isFinite(c)&&c>=0&&c<=70}else c=!1
c=c&&f.d<=1.5&&h.d<=1.5}else c=!1
if(c)o+=g
else{if(d&&e!=="held_estimate"){e=f.d
e=isFinite(e)&&e>=0&&e<=70}else e=!1
if(e){e=h.Q
if(e!=="unavailable"&&e!=="held_estimate"){e=h.d
e=isFinite(e)&&e>=0&&e<=70}else e=!1
f=e&&f.d>1.5&&h.d>1.5}else f=!1
if(f){p+=g
n+=h.w}}}else if(a9.bG(b3,j))o+=g
else{p+=g
n+=h.w}}b=s?A.G(k,0):B.a.gV(b1).b.c.S(B.a.gI(b1).b.c)
a=A.G(p,0)
a0=A.G(o,0)
a1=m/1000
s=a.a
a2=s<=0?0:n/(s/1e6)*3.6
a3=a9.c9(b3)
a4=b2>=6&&s>=9e7&&m>=1000
B.b.k(Math.min(b2/6,Math.min(s/9e7,a1)),0,1)
if(!a4){B.b.a0(a1,2)
B.c.B(s,b0)
return new A.bX(0,a1,new A.bW(!1))}b2=b.a
a5=b2<=0?0:m/(b2/1e6)*3.6
a6=a9.ap(a2,B.aK,60)
a7=a3.b<2?0:a9.ap(a3.a*3.6,B.aR,30)
a8=B.b.k(a6+a7+a9.ap(a5,B.aG,60),0,150)
B.b.a0(a1,2)
B.c.B(s,b0)
B.c.B(a0.a,b0)
return new A.bX(a8,a1,new A.bW(!0))},
bG(a,b){var s,r,q,p
if(this.bN(a.d,b)===B.M)return!0
s=a.c
r=s.length
if(!(b<r))return A.a(s,b)
q=s[b]
p=b+1
if(!(p<r))return A.a(s,p)
p=s[p]
return q.b.d<=1.3888888888888888&&p.b.d<=1.3888888888888888},
bN(a,b){var s,r,q
t.au.a(a)
for(s=a.length,r=0;r<s;++r){q=a[r]
if(b>=q.b&&b<=q.c)return q.a}return B.L},
c9(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=a.c
for(s=f.length,r=a.a,q=0,p=0,o=0;o<s;++o){n=f[o].b
m=n.d
n=n.Q
if(!(n!=="unavailable"&&n!=="held_estimate"))continue
if(!isFinite(m)||m<0)continue
for(n=[o-1,o+1],l=1,k=0;k<2;++k){j=n[k]
if(j<0||j>=s)continue
if(!(j>=0&&j<s))return A.a(f,j)
i=f[j].b.Q
if(!(i!=="unavailable"&&i!=="held_estimate"))continue
h=Math.min(o,j)
g=Math.max(o,j)
if(r){if(h>>>0!==h||h>=s)return A.a(f,h)
i=f[h]
if(g>>>0!==g||g>=s)return A.a(f,g)
i=!A.b7(i.b,f[g].b)}else i=!1
if(i)continue
if(Math.abs(f[j].b.d-m)<=10)++l}if(l<2)continue
if(m>q){p=l
q=m}}return new A.fz(q,p)},
ap(a,b,c){var s,r,q,p,o,n
t.gj.a(b)
if(a<=B.a.gI(B.a.gI(b)))return 0
for(s=b.length,r=1;r<s;++r){q=b[r-1]
p=b[r]
if(a<=B.a.gI(p)){s=B.a.gI(q)
o=B.a.gI(p)
n=B.a.gI(q)
return B.b.k(c*(B.a.gV(q)+(B.a.gV(p)-B.a.gV(q))*((a-s)/(o-n))),0,c)}}return c}}
A.fz.prototype={}
A.bX.prototype={}
A.bW.prototype={}
A.eW.prototype={
H(a0){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=a0.r,a=A.i([],t.c)
for(s=b.length,r=a0.a,q=0;p=q+2,p<s;){if(!(q<s))return A.a(b,q)
o=b[q];++q
if(!(q<s))return A.a(b,q)
n=b[q]
m=b[p]
l=this.c8(o,n,m)
if(l!=null){p=n.at
k=Math.max(p.c,p.d)
p=!1
if(m.y>=8.333333333333334)if(k<0.65){j=n.f
i=o.r
if(A.G(j.b-i.b,j.a-i.a).a<=8e6){p=m.f
j=n.r
j=A.G(p.b-j.b,p.a-j.a).a<=8e6
p=j}}p=!p}else p=!0
if(p)continue
if(r&&!A.eu(o.d,m.e,new A.f_(a0)))continue
B.a.l(a,new A.ab(l,this.bR(a0,m)))}if(a.length===0)return B.b4
h=new A.f1(a)
g=h.$2(B.t,20)
f=h.$2(B.u,20)
e=h.$2(B.v,10)
s=A.a8(t.am,t.S)
for(r=t.eF,p=t.dA,d=0;d<3;++d){c=B.aT[d]
s.q(0,c,new A.x(a,r.a(new A.f0(c)),p).gm(0))}return new A.cR(g+f+e,!0,a.length>=2)},
c8(a,b,c){var s,r
if(c.c!==B.n)return null
s=a.c
r=s===B.n
if(r&&b.c===B.r)return B.t
if(r&&b.c===B.j)return B.u
if(s===B.m)return B.v
return null},
bR(a,b){var s=B.a.a7(a.c,b.d,b.e+1),r=A.h(s)
return B.b.k(1-Math.sqrt(B.a.G(s,0,new A.eX(new A.f(s,r.h("b(1)").a(new A.eY()),r.h("f<1,b>")).L(0,new A.eZ())/s.length),t.i)/s.length)/4,0,1)}}
A.f_.prototype={
$1(a){var s=this.a.c
if(!(a>=0&&a<s.length))return A.a(s,a)
return s[a].b},
$S:7}
A.f1.prototype={
$2(a,b){var s=this.a,r=A.h(s),q=r.h("x<1>"),p=A.q(new A.x(s,r.h("j(1)").a(new A.f2(a)),q),q.h("c.E"))
if(p.length===0)return 0
s=A.h(p)
return new A.f(p,s.h("b(1)").a(new A.f3()),s.h("f<1,b>")).L(0,new A.f4())/p.length*b},
$S:32}
A.f2.prototype={
$1(a){return t.f.a(a).a===this.a},
$S:16}
A.f3.prototype={
$1(a){return t.f.a(a).e},
$S:34}
A.f4.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.f0.prototype={
$1(a){return t.f.a(a).a===this.a},
$S:16}
A.eY.prototype={
$1(a){return t.C.a(a).b.d},
$S:2}
A.eZ.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.eX.prototype={
$2(a,b){var s
A.t(a)
s=t.C.a(b).b.d-this.a
return a+s*s},
$S:35}
A.f8.prototype={}
A.f9.prototype={}
A.cT.prototype={
cz(a8,a9,b0,b1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7=this
t.fV.a(b1)
s=a8.b
r=t.N
q=A.a8(r,t.fd)
p=A.i([],t.g7)
o=A.a8(r,t.Y)
for(n=b1.length,m=t.e5,l=m.h("c.E"),k=0;k<b1.length;b1.length===n||(0,A.D)(b1),++k){j=b1[k]
for(i=j.b,h=i.length,g=j.a,f=0;f<i.length;i.length===h||(0,A.D)(i),++f){e=i[f]
if(!e.ax||!e.Q)continue
d=a7.bo(e,g)
if(d==null)continue
J.iF(o.cA(d.a,new A.fg()),new A.C(d.b,d.c))}i=j.c
h=A.h(i)
i=A.q(new A.c1(new A.a3(new A.x(i,h.h("j(1)").a(new A.fh(a8)),h.h("x<1>")),h.h("a_?(1)").a(new A.fi(a7,j)),h.h("a3<1,a_?>")),m),l)
i.$flags=1
c=i
if(c.length===0)continue
q.q(0,g.a,a7.c0(g,c,b0))
i=A.h(c)
B.a.A(p,new A.f(c,i.h("E(1)").a(new A.fj(a8)),i.h("f<1,E>")))}b=a7.aX(a8)
for(n=b.length,m=a8.a,l=a8.Q,k=0;k<b.length;b.length===n||(0,A.D)(b),++k){a=b[k]
i=a.a.a
h=o.i(0,i)
for(h=a7.c4(new A.C(a.b,a.c),a7.bJ(h==null?B.V:h)),g=h.length,f=0;f<h.length;h.length===g||(0,A.D)(h),++f){a0=h[f]
B.a.l(p,new A.E(m,s,i,l,a0.a,a0.b))}}n=t.x
a1=A.i([],n)
a2=A.i([],n)
for(n=a9.c,m=n.length,k=0;k<n.length;n.length===m||(0,A.D)(n),++k){a3=n[k]
a4=q.i(0,a3.a)
if(a4==null)B.a.l(a1,a3)
else{B.a.l(a2,a3)
l=A.h(a4)
B.a.A(a1,new A.f(a4,l.h("z(1)").a(new A.fk(a7,a3,b0)),l.h("f<1,z>")))}}n=t.E
m=A.q(new A.a3(new A.x(p,t.bb.a(new A.fl()),t.a3),t.eS.a(new A.fm(a7,a8,b0)),t.aq),n)
l=A.q(a1,n)
B.a.A(l,m)
l=t.bZ.a(a7.bI(l,b0))
i=A.h(l)
h=i.h("j(1)").a(a7.gbC())
i=i.h("x<1>")
l=A.q(new A.x(l,h,i),i.h("c.E"))
l.$flags=1
a5=l
a7.bl(a5)
l=A.hF(a9.d,r)
l.l(0,s)
l=A.q(l,A.k(l).c)
l.$flags=1
a6=l
B.a.aH(a6)
l=A.T(a5,n)
r=A.T(a6,r)
b0.O()
A.T(a2,n)
i=A.h(m)
g=i.h("x<1>")
m=A.q(new A.x(m,i.h("j(1)").a(h),g),g.h("c.E"))
m.$flags=1
A.T(m,n)
return new A.f9("world:"+s+":v1",new A.cU(a9.a+1,l,r))},
bD(a){t.E.a(a)
return a.f-a.e>=1000},
c0(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h
t.ej.a(b)
s=A.h(b)
r=s.h("f<1,C>")
q=A.q(new A.f(b,s.h("C(1)").a(new A.fd()),r),r.h("n.E"))
B.a.a1(q,new A.fe())
p=A.i([],t.g7)
o=a.e
for(s=q.length,r=a.c,n=a.b,m=a.d,l=a.r,k=0;k<q.length;q.length===s||(0,A.D)(q),++k){j=q[k]
i=j.a
if(i>o+0.01)if(i-o>=1000)B.a.l(p,new A.E(r,n,m,l,o,i))
o=Math.max(o,j.b)}s=a.f
if(o<s-0.01){h=A.jo(a,o,s)
if(h.b-h.a>=1000)B.a.l(p,h)}return p},
bp(a,b){var s,r,q,p,o,n,m=a.c
if(m.c!==b.d)return null
s=a.d
r=Math.max(s,b.e)
q=a.e
p=Math.min(q,b.f)
if(p-r+0.01<2000)return null
o=q-s
if(o<=0.01)return null
q=a.f
n=a.r-q
return new A.a_(r,p,m.d,q+n*((r-s)/o),q+n*((p-s)/o))},
bo(a,b){var s,r,q,p,o,n
if(a.c!==b.d)return null
s=a.e
r=Math.max(s,b.e)
q=a.f
p=Math.min(q,b.f)
if(p-r<=0.01)return null
o=q-s
if(o<=0.01)return null
q=a.r
n=a.w-q
return new A.fn(a.d,q+n*((r-s)/o),q+n*((p-s)/o))},
aX(a){var s,r,q={},p=a.d
p=p.length!==0?p:A.i([new A.U(a.a+":geometry",a.c,a.e)],t.aa)
q.a=0
s=A.h(p)
r=s.h("f<1,am>")
q=A.q(new A.f(p,s.h("am(1)").a(new A.fc(q)),r),r.h("n.E"))
q.$flags=1
return q},
c7(a,b,c){var s=this.bm(B.a.cq(this.aX(b),new A.ff(a)).a.b).a
return new A.z(this.aQ(a),a.d,a.c,a.e,a.a,a.b,a.f,s[0],s[1],s[2],s[3],c.O(),c.O(),b.y)},
bI(a,b){var s,r,q,p,o,n,m=A.q(t.h2.a(a),t.E)
B.a.a1(m,new A.fa())
s=A.i([],t.x)
for(r=m.length,q=0;q<m.length;m.length===r||(0,A.D)(m),++q){p=m[q]
if(s.length!==0){o=B.a.gV(s)
o=!(o.b===p.b&&o.c===p.c&&o.d===p.d&&o.r===p.r&&Math.abs(o.f-p.e)<=0.01)}else o=!0
if(o){B.a.l(s,p)
continue}if(0>=s.length)return A.a(s,-1)
n=s.pop()
o=p.f
B.a.l(s,n.cl(o,n.b+":"+n.c+":"+n.d+":"+B.b.a0(n.e,3)+":"+B.b.a0(o,3),b.O()))}return s},
bl(a){var s,r,q,p,o,n
t.h2.a(a)
for(s=a.length,r=0;r<s;r=q)for(q=r+1,p=q;p<s;++p){o=a[r]
n=a[p]
if(o.d!==n.d||o.r!==n.r)continue
if(Math.min(o.f,n.f)-Math.max(o.e,n.e)>0.01&&o.b!==n.b)throw A.d(A.jc("Duplicate active ownership for a World road interval."))}},
bJ(a){var s,r,q,p,o,n
t.Y.a(a)
if(J.fW(a))return B.V
s=A.q(a,t.w)
B.a.a1(s,new A.fb())
r=A.i([B.a.gI(s)],t.O)
for(s=A.bV(s,1,null,A.h(s).c),q=s.$ti,s=new A.aw(s,s.gm(0),q.h("aw<n.E>")),q=q.h("n.E");s.n();){p=s.d
if(p==null)p=q.a(p)
o=B.a.gV(r)
n=o.b
if(p.a<=n+0.01)B.a.q(r,r.length-1,new A.C(o.a,Math.max(n,p.b)))
else B.a.l(r,p)}return r},
c4(a,b){var s,r,q,p,o,n,m,l,k,j
t.Y.a(b)
s=A.i([],t.O)
r=a.a
for(q=b.length,p=a.b,o=r,n=0;n<b.length;b.length===q||(0,A.D)(b),++n){m=b[n]
l=m.b
if(l<=r||m.a>=p)continue
k=Math.max(m.a,r)
j=Math.min(l,p)
if(k>o+0.01)B.a.l(s,new A.C(o,k))
o=Math.max(o,j)}if(o<p-0.01)B.a.l(s,new A.C(o,p))
return s},
aQ(a){return a.d+":"+a.c+":"+a.e+":"+B.b.a0(a.a,3)+":"+B.b.a0(a.b,3)},
bm(a){var s,r,q,p,o,n,m,l
t.f8.a(a)
if(a.length===0)return B.aZ
s=B.a.gI(a).a
r=B.a.gI(a).b
for(q=A.bV(a,1,null,A.h(a).c),p=q.$ti,q=new A.aw(q,q.gm(0),p.h("aw<n.E>")),p=p.h("n.E"),o=r,n=s;q.n();){m=q.d
if(m==null)m=p.a(m)
l=m.a
s=Math.min(s,l)
n=Math.max(n,l)
m=m.b
r=Math.min(r,m)
o=Math.max(o,m)}return new A.bk([s,n,r,o])}}
A.fg.prototype={
$0(){return A.i([],t.O)},
$S:37}
A.fh.prototype={
$1(a){t.m.a(a)
return a.b===this.a.b&&a.y+0.01>=2000},
$S:38}
A.fi.prototype={
$1(a){return this.a.bp(t.m.a(a),this.b.a)},
$S:39}
A.fj.prototype={
$1(a){var s
t.L.a(a)
s=this.a
return new A.E(s.a,s.b,a.c,s.Q,a.d,a.e)},
$S:40}
A.fk.prototype={
$1(a){t.g.a(a)
return this.b.b3(a.b,this.a.aQ(a),a.a,this.c.O())},
$S:17}
A.fl.prototype={
$1(a){t.g.a(a)
return a.b-a.a>0.01},
$S:42}
A.fm.prototype={
$1(a){return this.a.c7(t.g.a(a),this.b,this.c)},
$S:17}
A.fd.prototype={
$1(a){t.L.a(a)
return new A.C(a.a,a.b)},
$S:65}
A.fe.prototype={
$2(a,b){var s=t.w
return B.b.C(s.a(a).a,s.a(b).a)},
$S:18}
A.fc.prototype={
$1(a){var s,r,q,p
t.o.a(a)
s=A.hU(a)
r=this.a
q=r.a
p=q+s
r.a=p
return new A.am(a,q,p)},
$S:45}
A.ff.prototype={
$1(a){return t.d4.a(a).a.a===this.a.e},
$S:46}
A.fa.prototype={
$2(a,b){var s,r=t.E
r.a(a)
r.a(b)
s=B.e.C(a.d,b.d)
return s!==0?s:B.b.C(a.e,b.e)},
$S:47}
A.fb.prototype={
$2(a,b){var s=t.w
return B.b.C(s.a(a).a,s.a(b).a)},
$S:18}
A.am.prototype={}
A.C.prototype={}
A.E.prototype={}
A.a_.prototype={}
A.fn.prototype={}
A.cU.prototype={}
A.fJ.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j,i,h
t.P.a(a)
s=A.v(a.i(0,"id"))
r=A.v(a.i(0,"sourceDriveId"))
q=A.v(a.i(0,"validatedRoadId"))
p=A.v(a.i(0,"matchedSectionId"))
o=A.m(a.i(0,"startOffsetMeters"))
n=A.m(a.i(0,"endOffsetMeters"))
m=A.v(a.i(0,"directionKey"))
l=A.m(a.i(0,"minLatitude"))
k=A.m(a.i(0,"maxLatitude"))
j=A.m(a.i(0,"minLongitude"))
i=A.m(a.i(0,"maxLongitude"))
h=A.a0(a.i(0,"processingVersion"))
return new A.z(s,r,q,p,o,n,m,l,k,j,i,A.dY(A.v(a.i(0,"createdAt"))),A.dY(A.v(a.i(0,"updatedAt"))),h)},
$S:48}
A.fK.prototype={
$1(a){var s,r=J.bp(a),q=A.hd(t.P.a(r.i(a,"match"))),p=this.a.i(0,r.i(a,"traceId"))
p.toString
s=A.i([q],t.A)
r=J.b4(t.j.a(r.i(a,"regions")),new A.fI(q),t.m)
r=A.q(r,r.$ti.h("n.E"))
return new A.aL(p,s,r)},
$S:49}
A.fI.prototype={
$1(a){var s=J.bp(a),r=A.v(s.i(a,"existingDriveId"))
s=A.v(s.i(a,"challengerDriveId"))
t.P.a(a)
return new A.Y(r,s,this.a,A.m(a.i(0,"startOffsetOnExistingMeters")),A.m(a.i(0,"endOffsetOnExistingMeters")),A.m(a.i(0,"startOffsetOnChallengerMeters")),A.m(a.i(0,"endOffsetOnChallengerMeters")),A.m(a.i(0,"commonStartOffsetMeters")),A.m(a.i(0,"commonEndOffsetMeters")),A.m(a.i(0,"winningDistanceMeters")),B.q,A.m(a.i(0,"confidence")),A.a0(a.i(0,"supportingWindowCount")))},
$S:50}
A.fP.prototype={
$1(a){var s=J.bp(a),r=A.v(s.i(a,"id"))
s=J.b4(t.j.a(s.i(a,"geometry")),new A.fO(),t.cX)
s=A.q(s,s.$ti.h("n.E"))
return new A.U(r,s,A.m(t.P.a(a).i(0,"distanceMeters")))},
$S:51}
A.fO.prototype={
$1(a){t.P.a(a)
return new A.Z(A.m(a.i(0,"latitude")),A.m(a.i(0,"longitude")))},
$S:19}
A.fQ.prototype={
$1(a){return t.o.a(a).b},
$S:53}
A.fR.prototype={
$2(a,b){return A.t(a)+t.o.a(b).c},
$S:54}
A.fV.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j,i,h,g="gap_duration_micros"
t.P.a(a)
s=A.m(a.i(0,"latitude"))
r=A.m(a.i(0,"longitude"))
q=A.dY(A.v(a.i(0,"timestamp")))
p=A.m(a.i(0,"speed_mps"))
o=A.m(a.i(0,"heading_degrees"))
n=A.m(a.i(0,"altitude_meters"))
m=A.m(a.i(0,"accuracy_meters"))
l=A.m(a.i(0,"distance_from_previous_meters"))
k=A.m(a.i(0,"acceleration_mps2"))
j=J.an(a.i(0,"break_before"),!0)
i=typeof a.i(0,g)=="number"?B.b.ba(A.m(a.i(0,g))):0
h=A.i9(a.i(0,"speed_source"))
if(h==null)h="legacy"
return new A.F(s,r,q,p,o,n,m,l,k,j,i,h,!J.an(a.i(0,"acceleration_reliable"),!1))},
$S:55}
A.fS.prototype={
$2(a,b){A.v(a)
t.R.a(b)
return new A.M(a,A.L(["score",b.a,"maximum",b.b,"applicable",b.c,"sampleSufficient",b.d],t.N,t.K),t.ct)},
$S:56}
A.fT.prototype={
$2(a,b){A.v(a)
t.D.a(b)
return new A.M(a,A.L(["contribution",b.b,"source",b.c.b],t.N,t.K),t.ct)},
$S:57}
A.fU.prototype={
$1(a){return t.u.a(a).c.O().aE()},
$S:58}
A.fG.prototype={
$1(a){t.P.a(a)
return new A.Z(A.m(a.i(0,"latitude")),A.m(a.i(0,"longitude")))},
$S:19}
A.fD.prototype={
$1(a){t.l.a(a)
return A.L(["commonStartOffsetMeters",a.a,"commonEndOffsetMeters",a.b,"existingStartOffsetMeters",a.c,"existingEndOffsetMeters",a.d,"challengerStartOffsetMeters",a.e,"challengerEndOffsetMeters",a.f,"state",a.r.b,"comparison",A.ij(a.w)],t.N,t.K)},
$S:59}
A.fE.prototype={
$1(a){t.m.a(a)
return A.L(["existingDriveId",a.a,"challengerDriveId",a.b,"startOffsetOnExistingMeters",a.d,"endOffsetOnExistingMeters",a.e,"startOffsetOnChallengerMeters",a.f,"endOffsetOnChallengerMeters",a.r,"commonStartOffsetMeters",a.w,"commonEndOffsetMeters",a.x,"winningDistanceMeters",a.y,"algorithmVersion",1,"confidence",a.Q,"supportingWindowCount",a.as],t.N,t.K)},
$S:60}
A.fL.prototype={
$1(a){return B.f.aw(A.kj(t.P.a(B.f.av(A.v(a),null))),null)},
$S:8}
A.fM.prototype={
$1(a){return B.f.aw(A.kh(t.P.a(B.f.av(A.v(a),null))),null)},
$S:8}
A.fN.prototype={
$1(a){return B.f.aw(A.kk(t.P.a(B.f.av(A.v(a),null))),null)},
$S:8}
A.aL.prototype={};(function aliases(){var s=J.aI.prototype
s.bf=s.j})();(function installTearOffs(){var s=hunkHelpers._static_2,r=hunkHelpers._static_1,q=hunkHelpers._instance_1u,p=hunkHelpers.installStaticTearOff
s(J,"jR","j_",62)
r(A,"kf","jH",63)
q(A.cr.prototype,"gcb","cc",4)
q(A.ct.prototype,"gbE","bF",1)
q(A.cT.prototype,"gbC","bD",36)
r(A,"kB","kv",64)
p(A,"ku",2,null,["$1$2","$2"],["im",function(a,b){return A.im(a,b,t.H)}],43,0)})();(function inheritance(){var s=hunkHelpers.mixin,r=hunkHelpers.inherit,q=hunkHelpers.inheritMany
r(A.o,null)
q(A.o,[A.fY,J.cC,A.bR,J.aQ,A.c,A.br,A.A,A.eT,A.aw,A.bO,A.ae,A.bA,A.bS,A.by,A.c2,A.b_,A.be,A.bt,A.R,A.f5,A.eR,A.P,A.eL,A.bI,A.bJ,A.bH,A.cH,A.fu,A.ad,A.cW,A.fw,A.aX,A.cZ,A.aY,A.cb,A.c4,A.d_,A.cl,A.cp,A.fs,A.ah,A.S,A.fo,A.cK,A.bT,A.fp,A.eD,A.M,A.aV,A.bg,A.d5,A.z,A.dm,A.aN,A.al,A.dG,A.dl,A.F,A.dH,A.cm,A.cn,A.aq,A.dM,A.dJ,A.c5,A.af,A.fq,A.cr,A.cq,A.ag,A.e0,A.ct,A.a6,A.eo,A.cB,A.eF,A.er,A.K,A.aG,A.cu,A.et,A.a5,A.aA,A.as,A.p,A.cs,A.ev,A.ez,A.cw,A.cv,A.cg,A.ab,A.cR,A.aJ,A.Y,A.bN,A.eN,A.fA,A.Z,A.U,A.eV,A.fz,A.bX,A.bW,A.eW,A.f8,A.f9,A.cT,A.am,A.C,A.a_,A.fn,A.cU,A.aL])
q(J.cC,[J.cF,J.bC,J.bc,J.ba,J.aU])
q(J.bc,[J.aI,J.l])
q(J.aI,[J.eS,J.aK,J.bD])
r(J.cD,A.bR)
r(J.eG,J.l)
q(J.ba,[J.bB,J.cG])
q(A.c,[A.bi,A.w,A.a3,A.x,A.bz,A.ay,A.c1])
r(A.aR,A.bi)
r(A.c3,A.aR)
q(A.A,[A.bF,A.bY,A.cI,A.cS,A.cO,A.cV,A.bE,A.ch,A.ao,A.c0,A.bf,A.co])
q(A.w,[A.n,A.bx,A.av,A.ac,A.bG])
q(A.n,[A.bU,A.f,A.bK,A.cY])
r(A.bw,A.a3)
r(A.b8,A.ay)
r(A.bj,A.b_)
r(A.bk,A.bj)
r(A.bm,A.be)
r(A.bZ,A.bm)
r(A.bu,A.bZ)
q(A.R,[A.ck,A.cA,A.cj,A.cQ,A.dZ,A.e_,A.dd,A.df,A.dg,A.dh,A.d6,A.d9,A.da,A.di,A.dE,A.dF,A.dp,A.dn,A.dq,A.dr,A.du,A.dv,A.dy,A.dz,A.dx,A.dA,A.dt,A.ds,A.dw,A.dI,A.dK,A.dT,A.dP,A.dQ,A.dR,A.dS,A.e4,A.e3,A.e5,A.eg,A.ef,A.eh,A.ej,A.ei,A.ek,A.el,A.e6,A.em,A.e7,A.e8,A.e9,A.ea,A.eb,A.ec,A.ee,A.e2,A.eq,A.ep,A.e1,A.ew,A.eA,A.eB,A.f_,A.f2,A.f3,A.f0,A.eY,A.fh,A.fi,A.fj,A.fk,A.fl,A.fm,A.fd,A.fc,A.ff,A.fJ,A.fK,A.fI,A.fP,A.fO,A.fQ,A.fV,A.fU,A.fG,A.fD,A.fE,A.fL,A.fM,A.fN])
q(A.ck,[A.dN,A.eH,A.eM,A.eQ,A.ft,A.de,A.d8,A.d7,A.dc,A.db,A.dC,A.dD,A.dL,A.dU,A.dV,A.dO,A.ed,A.es,A.ey,A.ex,A.eC,A.f1,A.f4,A.eZ,A.eX,A.fe,A.fa,A.fb,A.fR,A.fS,A.fT])
r(A.aa,A.bt)
r(A.b9,A.cA)
r(A.bP,A.bY)
q(A.cQ,[A.cP,A.b6])
q(A.P,[A.au,A.cX])
r(A.bl,A.cV)
q(A.aX,[A.c6,A.cc])
r(A.aD,A.c6)
r(A.c_,A.cc)
r(A.cJ,A.bE)
r(A.eI,A.cl)
q(A.cp,[A.eK,A.eJ])
r(A.fr,A.fs)
q(A.cj,[A.dW,A.dB,A.eO,A.fg])
q(A.ao,[A.bQ,A.cz])
q(A.fo,[A.ap,A.bs,A.en,A.bv,A.ai,A.bh,A.aS,A.aH,A.X,A.aj,A.bd,A.bM])
r(A.E,A.C)
s(A.bm,A.cb)
s(A.cc,A.d_)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{I:"int",b:"double",Q:"num",e:"String",j:"bool",aV:"Null",r:"List",o:"Object",u:"Map",bb:"JSObject"},mangledNames:{},types:["b(b,b)","j(a5)","b(a5)","j(p)","b(ag)","j(a6)","p(a6)","F(I)","e(e)","b(p)","j(F)","~(o?,o?)","I(e?)","b(b)","b(al)","b(b,aN)","j(ab)","z(E)","I(C,C)","Z(@)","j(al)","~(@,@)","b(b(ag))","j(p?)","aV()","I(p,p)","as(a6)","p(p)","b(b,aG)","j(K)","b(K)","~()","b(aj,b)","j(e)","b(ab)","b(b,a5)","j(z)","r<C>()","j(Y)","a_?(Y)","E(a_)","b(b(p))","j(E)","0^(0^,0^)<Q>","0&()","am(U)","j(am)","I(z,z)","z(@)","aL(@)","Y(@)","U(@)","F(af)","r<Z>(U)","b(b,U)","F(@)","M<e,u<e,o>>(e,K)","M<e,u<e,o>>(e,aG)","e(F)","u<e,o>(aJ)","u<e,o>(Y)","b(b,af)","I(@,@)","@(@)","u<e,@>(z)","C(a_)"],arrayRti:Symbol("$ti"),rttc:{"4;":a=>b=>b instanceof A.bk&&A.kw(a,b.a)}}
A.jw(v.typeUniverse,JSON.parse('{"bD":"aI","eS":"aI","aK":"aI","cF":{"j":[],"aB":[]},"bC":{"aB":[]},"bc":{"bb":[]},"aI":{"bb":[]},"l":{"r":["1"],"w":["1"],"bb":[],"c":["1"]},"cD":{"bR":[]},"eG":{"l":["1"],"r":["1"],"w":["1"],"bb":[],"c":["1"]},"aQ":{"y":["1"]},"ba":{"b":[],"Q":[],"a2":["Q"]},"bB":{"b":[],"I":[],"Q":[],"a2":["Q"],"aB":[]},"cG":{"b":[],"Q":[],"a2":["Q"],"aB":[]},"aU":{"e":[],"a2":["e"],"aB":[]},"bi":{"c":["2"]},"br":{"y":["2"]},"aR":{"bi":["1","2"],"c":["2"],"c.E":"2"},"c3":{"aR":["1","2"],"bi":["1","2"],"w":["2"],"c":["2"],"c.E":"2"},"bF":{"A":[]},"w":{"c":["1"]},"n":{"w":["1"],"c":["1"]},"bU":{"n":["1"],"w":["1"],"c":["1"],"n.E":"1","c.E":"1"},"aw":{"y":["1"]},"a3":{"c":["2"],"c.E":"2"},"bw":{"a3":["1","2"],"w":["2"],"c":["2"],"c.E":"2"},"bO":{"y":["2"]},"f":{"n":["2"],"w":["2"],"c":["2"],"n.E":"2","c.E":"2"},"x":{"c":["1"],"c.E":"1"},"ae":{"y":["1"]},"bz":{"c":["2"],"c.E":"2"},"bA":{"y":["2"]},"ay":{"c":["1"],"c.E":"1"},"b8":{"ay":["1"],"w":["1"],"c":["1"],"c.E":"1"},"bS":{"y":["1"]},"bx":{"w":["1"],"c":["1"],"c.E":"1"},"by":{"y":["1"]},"c1":{"c":["1"],"c.E":"1"},"c2":{"y":["1"]},"bk":{"bj":[],"b_":[]},"bu":{"bZ":["1","2"],"bm":["1","2"],"be":["1","2"],"cb":["1","2"],"u":["1","2"]},"bt":{"u":["1","2"]},"aa":{"bt":["1","2"],"u":["1","2"]},"cA":{"R":[],"at":[]},"b9":{"R":[],"at":[]},"bP":{"A":[]},"cI":{"A":[]},"cS":{"A":[]},"R":{"at":[]},"cj":{"R":[],"at":[]},"ck":{"R":[],"at":[]},"cQ":{"R":[],"at":[]},"cP":{"R":[],"at":[]},"b6":{"R":[],"at":[]},"cO":{"A":[]},"au":{"P":["1","2"],"hB":["1","2"],"u":["1","2"],"P.K":"1","P.V":"2"},"av":{"w":["1"],"c":["1"],"c.E":"1"},"bI":{"y":["1"]},"ac":{"w":["1"],"c":["1"],"c.E":"1"},"bJ":{"y":["1"]},"bG":{"w":["M<1,2>"],"c":["M<1,2>"],"c.E":"M<1,2>"},"bH":{"y":["M<1,2>"]},"bj":{"b_":[]},"cH":{"j9":[]},"cV":{"A":[]},"bl":{"A":[]},"aD":{"c6":["1"],"aX":["1"],"hD":["1"],"aW":["1"],"w":["1"],"c":["1"]},"aY":{"y":["1"]},"P":{"u":["1","2"]},"be":{"u":["1","2"]},"bZ":{"bm":["1","2"],"be":["1","2"],"cb":["1","2"],"u":["1","2"]},"bK":{"n":["1"],"w":["1"],"c":["1"],"n.E":"1","c.E":"1"},"c4":{"y":["1"]},"aX":{"aW":["1"],"w":["1"],"c":["1"]},"c6":{"aX":["1"],"aW":["1"],"w":["1"],"c":["1"]},"c_":{"aX":["1"],"d_":["1"],"aW":["1"],"w":["1"],"c":["1"]},"cX":{"P":["e","@"],"u":["e","@"],"P.K":"e","P.V":"@"},"cY":{"n":["e"],"w":["e"],"c":["e"],"n.E":"e","c.E":"e"},"bE":{"A":[]},"cJ":{"A":[]},"ah":{"a2":["ah"]},"b":{"Q":[],"a2":["Q"]},"S":{"a2":["S"]},"I":{"Q":[],"a2":["Q"]},"r":{"w":["1"],"c":["1"]},"Q":{"a2":["Q"]},"aW":{"w":["1"],"c":["1"]},"e":{"a2":["e"]},"ch":{"A":[]},"bY":{"A":[]},"ao":{"A":[]},"bQ":{"A":[]},"cz":{"A":[]},"c0":{"A":[]},"bf":{"A":[]},"co":{"A":[]},"cK":{"A":[]},"bT":{"A":[]},"bg":{"jd":[]},"E":{"C":[]}}'))
A.jv(v.typeUniverse,JSON.parse('{"cc":1,"cl":2,"cp":2}'))
var u={c:"At least two canonical telemetry points are required."}
var t=(function rtii(){var s=A.aF
return{E:s("z"),eS:s("z(E)"),u:s("F"),fI:s("F(af)"),e8:s("a2<@>"),v:s("ag"),dy:s("ah"),D:s("aG"),R:s("K"),F:s("p"),fR:s("ai"),gE:s("as"),f:s("ab"),am:s("aj"),fu:s("S"),U:s("w<@>"),bU:s("A"),V:s("X"),c5:s("aH"),Z:s("at"),bZ:s("c<z>"),t:s("c<F>"),ff:s("c<K>"),bM:s("c<b>"),hf:s("c<@>"),x:s("l<z>"),J:s("l<F>"),A:s("l<cm>"),df:s("l<ag>"),h:s("l<p>"),G:s("l<as>"),c:s("l<ab>"),b:s("l<r<b>>"),d:s("l<aJ>"),r:s("l<Y>"),aa:s("l<U>"),s:s("l<e>"),M:s("l<a5>"),gI:s("l<aA>"),h9:s("l<al>"),O:s("l<C>"),du:s("l<af>"),cA:s("l<c5>"),dO:s("l<a6>"),g7:s("l<E>"),aS:s("l<aN>"),n:s("l<b>"),gn:s("l<@>"),dC:s("l<I>"),T:s("bC"),p:s("bb"),cj:s("bD"),d9:s("bK<I>"),h2:s("r<z>"),W:s("r<F>"),B:s("r<p>"),e2:s("r<ai>"),au:s("r<as>"),gj:s("r<r<b>>"),fB:s("r<aJ>"),f8:s("r<Z>"),dg:s("r<e>"),X:s("r<a5>"),dr:s("r<aA>"),fV:s("r<aL>"),cT:s("r<al>"),Y:s("r<C>"),fT:s("r<c5>"),e:s("r<a6>"),fd:s("r<E>"),ap:s("r<aN>"),ej:s("r<a_>"),q:s("r<b>"),j:s("r<@>"),l:s("aJ"),m:s("Y"),ct:s("M<e,u<e,o>>"),cC:s("u<e,K>"),h6:s("u<e,o>"),P:s("u<e,@>"),eO:s("u<@,@>"),aq:s("a3<E,z>"),gM:s("f<af,F>"),cX:s("Z"),o:s("U"),a:s("aV"),K:s("o"),gT:s("kF"),bQ:s("+()"),fj:s("aW<X>"),cq:s("aW<e>"),N:s("e"),C:s("a5"),fo:s("aA"),dm:s("aB"),ak:s("aK"),f4:s("c_<X>"),dA:s("x<ab>"),a3:s("x<E>"),e5:s("c1<a_>"),bI:s("aL"),k:s("al"),w:s("C"),ei:s("af"),Q:s("a6"),d4:s("am"),g:s("E"),fz:s("aN"),L:s("a_"),y:s("j"),eF:s("j(ab)"),d1:s("j(a5)"),fW:s("j(a6)"),bb:s("j(E)"),i:s("b"),bk:s("b(ag)"),bE:s("b(p)"),z:s("@"),S:s("I"),dd:s("p?"),eH:s("hw<aV>?"),an:s("bb?"),gJ:s("r<e>?"),bF:s("r<@>?"),_:s("o?"),eN:s("aW<X>?"),dk:s("e?"),br:s("cZ?"),fQ:s("j?"),cD:s("b?"),I:s("I?"),cg:s("Q?"),H:s("Q"),fH:s("~(e,@)")}})();(function constants(){var s=hunkHelpers.makeConstList
B.az=J.cC.prototype
B.a=J.l.prototype
B.c=J.bB.prototype
B.b=J.ba.prototype
B.e=J.aU.prototype
B.aA=J.bc.prototype
B.Y=new A.b9(A.ku(),A.aF("b9<b>"))
B.Z=new A.d5()
B.a_=new A.dm()
B.k=new A.dJ()
B.a1=new A.e0()
B.a2=new A.ct()
B.a8=new A.eV()
B.a0=new A.cr()
B.a4=new A.ev()
B.a9=new A.eW()
B.a5=new A.ez()
B.a3=new A.er()
B.l=new A.eo()
B.B=new A.dH()
B.C=new A.by(A.aF("by<0&>"))
B.D=new A.cB()
B.E=new A.eF()
B.a6=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.f=new A.eI()
B.a7=new A.cK()
B.d=new A.eT()
B.aa=new A.cT()
B.F=new A.ap(0,"firstWins")
B.G=new A.ap(1,"secondWins")
B.H=new A.ap(2,"noMeaningfulDifference")
B.ab=new A.ap(3,"notEligible")
B.o=new A.ap(4,"insufficientTelemetry")
B.ac=new A.ap(5,"mappingFailed")
B.ad=new A.ap(7,"calculationFailed")
B.p=new A.bs(0,"success")
B.h=new A.bs(1,"mappingFailed")
B.I=new A.bs(2,"insufficientTelemetry")
B.q=new A.en(0,"v1")
B.J=new A.bv(0,"actual")
B.ae=new A.bv(1,"neutralNotApplicable")
B.af=new A.bv(2,"neutralInsufficient")
B.K=new A.aS(0,"stop")
B.m=new A.aS(1,"acceleration")
B.r=new A.aS(2,"deceleration")
B.j=new A.aS(3,"corner")
B.n=new A.aS(4,"cruise")
B.L=new A.ai(0,"unknown")
B.M=new A.ai(1,"stopped")
B.ag=new A.ai(2,"accelerating")
B.ah=new A.ai(3,"cruising")
B.ai=new A.ai(4,"decelerating")
B.aj=new A.ai(5,"cornering")
B.t=new A.aj(0,"cruiseDecelCruise")
B.u=new A.aj(1,"cruiseCornerCruise")
B.v=new A.aj(2,"accelerationCruise")
B.ak=new A.S(0)
B.al=new A.S(12e7)
B.N=new A.S(15e5)
B.am=new A.S(2e6)
B.an=new A.S(3e6)
B.ao=new A.S(3e8)
B.ap=new A.S(5e6)
B.aq=new A.S(8e6)
B.ar=new A.X(0,"stopped")
B.as=new A.X(1,"accelerating")
B.at=new A.X(2,"cruising")
B.au=new A.X(3,"decelerating")
B.w=new A.X(4,"cornering")
B.av=new A.X(5,"freeFlow")
B.aw=new A.X(6,"denseTraffic")
B.ax=new A.X(7,"stopAndGo")
B.ay=new A.aH(0,"stopping")
B.x=new A.aH(1,"acceleration")
B.O=new A.aH(2,"braking")
B.P=new A.aH(3,"cornering")
B.Q=new A.aH(4,"cruising")
B.aB=new A.eJ(null)
B.aC=new A.eK(null)
B.y=s([0,0],t.n)
B.aI=s([20,0.25],t.n)
B.aO=s([50,0.58],t.n)
B.aN=s([80,0.83],t.n)
B.aD=s([120,1],t.n)
B.aG=s([B.y,B.aI,B.aO,B.aN,B.aD],t.b)
B.aH=s([30,0.25],t.n)
B.aJ=s([60,0.58],t.n)
B.aS=s([100,0.83],t.n)
B.aE=s([150,1],t.n)
B.aK=s([B.y,B.aH,B.aJ,B.aS,B.aE],t.b)
B.i=s([],t.J)
B.aQ=s([],t.h)
B.aP=s([],t.G)
B.T=s([],t.d)
B.U=s([],t.r)
B.S=s([],t.s)
B.R=s([],t.M)
B.V=s([],t.O)
B.aM=s([80,0.33],t.n)
B.aL=s([140,0.67],t.n)
B.aF=s([200,1],t.n)
B.aR=s([B.y,B.aM,B.aL,B.aF],t.b)
B.aT=s([B.t,B.u,B.v],A.aF("l<aj>"))
B.aU=new A.bM(0,"success")
B.aV=new A.bM(1,"notEligible")
B.aW=new A.bM(2,"insufficientConfidence")
B.aX=new A.bd(0,"existingBetter")
B.W=new A.bd(1,"challengerBetter")
B.aY=new A.bd(2,"noMeaningfulDifference")
B.z=new A.bd(3,"invalid")
B.A={}
B.b7=new A.aa(B.A,[],A.aF("aa<e,b>"))
B.b8=new A.aa(B.A,[],A.aF("aa<e,@>"))
B.aZ=new A.bk([0,0,0,0])
B.b_=new A.bW(!1)
B.b0=new A.bh(0,"unknown")
B.X=new A.aA(B.b0,0,0)
B.b1=new A.bh(1,"freeFlow")
B.b2=new A.bh(2,"denseTraffic")
B.b3=new A.bh(3,"stopAndGo")
B.b9=new A.aa(B.A,[],A.aF("aa<aj,I>"))
B.b6=s([],t.c)
B.b4=new A.cR(0,!1,!1)
B.b5=A.kA("o")})();(function staticFields(){$.a7=A.i([],A.aF("l<o>"))
$.hG=null
$.hm=null
$.hl=null
$.fv=A.i([],A.aF("l<r<o>?>"))})();(function lazyInitializers(){var s=hunkHelpers.lazyFinal
s($,"kD","is",()=>A.ik("_$dart_dartClosure"))
s($,"kC","hh",()=>A.ik("_$dart_dartClosure_dartJSInterop"))
s($,"kR","iE",()=>A.i([new J.cD()],A.aF("l<bR>")))
s($,"kG","iu",()=>A.aC(A.f6({
toString:function(){return"$receiver$"}})))
s($,"kH","iv",()=>A.aC(A.f6({$method$:null,
toString:function(){return"$receiver$"}})))
s($,"kI","iw",()=>A.aC(A.f6(null)))
s($,"kJ","ix",()=>A.aC(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"kM","iA",()=>A.aC(A.f6(void 0)))
s($,"kN","iB",()=>A.aC(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"kL","iz",()=>A.aC(A.hT(null)))
s($,"kK","iy",()=>A.aC(function(){try{null.$method$}catch(r){return r.message}}()))
s($,"kP","iD",()=>A.aC(A.hT(void 0)))
s($,"kO","iC",()=>A.aC(function(){try{(void 0).$method$}catch(r){return r.message}}()))
s($,"kE","it",()=>A.ja("^([+-]?\\d{4,6})-?(\\d\\d)-?(\\d\\d)(?:[ T](\\d\\d)(?::?(\\d\\d)(?::?(\\d\\d)(?:[.,](\\d+))?)?)?( ?[zZ]| ?([-+])(\\d\\d)(?::?(\\d\\d))?)?)?$"))
s($,"kQ","d4",()=>A.io(B.b5))})();(function nativeSupport(){!function(){var s=function(a){var m={}
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
var s=A.kt
if(typeof dartMainRunner==="function"){dartMainRunner(s,[])}else{s([])}})})()
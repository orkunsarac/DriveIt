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
if(a[b]!==s){A.kl(b)}a[b]=r}var q=a[b]
a[c]=function(){return q}
return q}}function makeConstList(a,b){if(b!=null)A.j(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var s=0;s<a.length;++s){convertToFastObject(a[s])}}var y=0
function instanceTearOffGetter(a,b){var s=null
return a?function(c){if(s===null)s=A.h1(b)
return new s(c,this)}:function(){if(s===null)s=A.h1(b)
return new s(this,null)}}function staticTearOffGetter(a){var s=null
return function(){if(s===null)s=A.h1(a).prototype
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
hn(a,b){if(a<0||a>4294967295)throw A.d(A.aj(a,0,4294967295,"length",null))
return J.eu(new Array(a),b)},
hm(a,b){if(a<0)throw A.d(A.dd("Length must be a non-negative integer: "+a))
return A.j(new Array(a),b.h("l<0>"))},
eu(a,b){var s=A.j(a,b.h("l<0>"))
s.$flags=1
return s},
iM(a,b){var s=t.e8
return J.iv(s.a(a),s.a(b))},
b_(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.bz.prototype
return J.cB.prototype}if(typeof a=="string")return J.aT.prototype
if(a==null)return J.bA.prototype
if(typeof a=="boolean")return J.cA.prototype
if(Array.isArray(a))return J.l.prototype
if(typeof a=="function")return J.bB.prototype
if(typeof a=="object"){if(a instanceof A.n){return a}else{return J.ba.prototype}}if(!(a instanceof A.n))return J.aJ.prototype
return a},
bm(a){if(a==null)return a
if(Array.isArray(a))return J.l.prototype
if(!(a instanceof A.n))return J.aJ.prototype
return a},
bn(a){if(typeof a=="string")return J.aT.prototype
if(a==null)return a
if(Array.isArray(a))return J.l.prototype
if(!(a instanceof A.n))return J.aJ.prototype
return a},
ka(a){if(typeof a=="number")return J.b8.prototype
if(typeof a=="string")return J.aT.prototype
if(a==null)return a
if(!(a instanceof A.n))return J.aJ.prototype
return a},
cc(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.b_(a).M(a,b)},
iu(a,b){return J.bm(a).l(a,b)},
iv(a,b){return J.ka(a).C(a,b)},
h7(a,b){return J.bm(a).E(a,b)},
a1(a){return J.b_(a).gD(a)},
fM(a){return J.bn(a).gv(a)},
iw(a){return J.bm(a).gZ(a)},
W(a){return J.bm(a).gt(a)},
aO(a){return J.bn(a).gm(a)},
ix(a){return J.b_(a).gU(a)},
b3(a,b,c){return J.bm(a).b3(a,b,c)},
h8(a,b){return J.bm(a).N(a,b)},
b4(a){return J.b_(a).j(a)},
cy:function cy(){},
cA:function cA(){},
bA:function bA(){},
ba:function ba(){},
aH:function aH(){},
eI:function eI(){},
aJ:function aJ(){},
bB:function bB(){},
l:function l(a){this.$ti=a},
cz:function cz(){},
ev:function ev(a){this.$ti=a},
aP:function aP(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
b8:function b8(){},
bz:function bz(){},
cB:function cB(){},
aT:function aT(){}},A={fO:function fO(){},
hd(a,b,c){if(t.U.b(a))return new A.c0(a,b.h("@<0>").u(c).h("c0<1,2>"))
return new A.aQ(a,b.h("@<0>").u(c).h("aQ<1,2>"))},
iO(a){return new A.bD("Field '"+a+"' has not been initialized.")},
ay(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
eK(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
i6(a,b,c){return a},
h4(a){var s,r
for(s=$.a7.length,r=0;r<s;++r)if(a===$.a7[r])return!0
return!1},
bS(a,b,c,d){A.aw(b,"start")
if(c!=null){A.aw(c,"end")
if(b>c)A.b2(A.aj(b,0,c,"start",null))}return new A.bR(a,b,c,d.h("bR<0>"))},
iS(a,b,c,d){if(t.U.b(a))return new A.bu(a,b,c.h("@<0>").u(d).h("bu<1,2>"))
return new A.a3(a,b,c.h("@<0>").u(d).h("a3<1,2>"))},
hG(a,b,c){var s="count"
if(t.U.b(a)){A.de(b,s,t.S)
A.aw(b,s)
return new A.b6(a,b,c.h("b6<0>"))}A.de(b,s,t.S)
A.aw(b,s)
return new A.ax(a,b,c.h("ax<0>"))},
aS(){return new A.bd("No element")},
iK(){return new A.bd("Too few elements")},
bg:function bg(){},
bp:function bp(a,b){this.a=a
this.$ti=b},
aQ:function aQ(a,b){this.a=a
this.$ti=b},
c0:function c0(a,b){this.a=a
this.$ti=b},
bD:function bD(a){this.a=a},
eJ:function eJ(){},
w:function w(){},
m:function m(){},
bR:function bR(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
av:function av(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
a3:function a3(a,b,c){this.a=a
this.b=b
this.$ti=c},
bu:function bu(a,b,c){this.a=a
this.b=b
this.$ti=c},
bL:function bL(a,b,c){var _=this
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
ad:function ad(a,b,c){this.a=a
this.b=b
this.$ti=c},
bx:function bx(a,b,c){this.a=a
this.b=b
this.$ti=c},
by:function by(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
ax:function ax(a,b,c){this.a=a
this.b=b
this.$ti=c},
b6:function b6(a,b,c){this.a=a
this.b=b
this.$ti=c},
bP:function bP(a,b,c){this.a=a
this.b=b
this.$ti=c},
bv:function bv(a){this.$ti=a},
bw:function bw(a){this.$ti=a},
bZ:function bZ(a,b){this.a=a
this.$ti=b},
c_:function c_(a,b){this.a=a
this.$ti=b},
hg(a,b,c){var s,r,q,p,o,n,m,l=A.k(a),k=A.fQ(new A.au(a,l.h("au<1>")),!0,b),j=k.length,i=0
for(;;){if(!(i<j)){s=!0
break}r=k[i]
if(typeof r!="string"||"__proto__"===r){s=!1
break}++i}if(s){q={}
for(p=0,i=0;i<k.length;k.length===j||(0,A.E)(k),++i,p=o){r=k[i]
c.a(a.i(0,r))
o=p+1
q[r]=p}n=A.fQ(new A.aa(a,l.h("aa<2>")),!0,c)
m=new A.ap(q,n,b.h("@<0>").u(c).h("ap<1,2>"))
m.$keys=k
return m}return new A.bs(A.iP(a,b,c),b.h("@<0>").u(c).h("bs<1,2>"))},
ie(a){var s=v.mangledGlobalNames[a]
if(s!=null)return s
return"minified:"+a},
B(a){var s
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
s=J.b4(a)
return s},
cH(a){var s,r=$.hv
if(r==null)r=$.hv=Symbol("identityHashCode")
s=a[r]
if(s==null){s=Math.random()*0x3fffffff|0
a[r]=s}return s},
iU(a,b){var s,r=/^\s*[+-]?((0x[a-f0-9]+)|(\d+)|([a-z0-9]+))\s*$/i.exec(a)
if(r==null)return null
if(3>=r.length)return A.a(r,3)
s=r[3]
if(s!=null)return parseInt(a,10)
if(r[2]!=null)return parseInt(a,16)
return null},
cI(a){var s,r,q,p
if(a instanceof A.n)return A.V(A.ca(a),null)
s=J.b_(a)
if(s===B.ay||s===B.az||t.ak.b(a)){r=B.a5(a)
if(r!=="Object"&&r!=="")return r
q=a.constructor
if(typeof q=="function"){p=q.name
if(typeof p=="string"&&p!=="Object"&&p!=="")return p}}return A.V(A.ca(a),null)},
hC(a){var s,r,q
if(a==null||typeof a=="number"||A.h_(a))return J.b4(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.Q)return a.j(0)
if(a instanceof A.aZ)return a.aX(!0)
s=$.it()
for(r=0;r<1;++r){q=s[r].ct(a)
if(q!=null)return q}return"Instance of '"+A.cI(a)+"'"},
L(a){var s
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){s=a-65536
return String.fromCharCode((B.c.aV(s,10)|55296)>>>0,s&1023|56320)}throw A.d(A.aj(a,0,1114111,null,null))},
hD(a,b,c,d,e,f,g,h,i){var s,r,q,p=b-1
if(0<=a&&a<100){a+=400
p-=4800}s=B.c.V(h,1000)
g+=B.c.A(h-s,1000)
r=i?Date.UTC(a,p,c,d,e,f,g):new Date(a,p,c,d,e,f,g).valueOf()
q=!0
if(!isNaN(r))if(!(r<-864e13))if(!(r>864e13))q=r===864e13&&s!==0
if(q)return null
return r},
a4(a){if(a.date===void 0)a.date=new Date(a.a)
return a.date},
cG(a){return a.c?A.a4(a).getUTCFullYear()+0:A.a4(a).getFullYear()+0},
hA(a){return a.c?A.a4(a).getUTCMonth()+1:A.a4(a).getMonth()+1},
hw(a){return a.c?A.a4(a).getUTCDate()+0:A.a4(a).getDate()+0},
hx(a){return a.c?A.a4(a).getUTCHours()+0:A.a4(a).getHours()+0},
hz(a){return a.c?A.a4(a).getUTCMinutes()+0:A.a4(a).getMinutes()+0},
hB(a){return a.c?A.a4(a).getUTCSeconds()+0:A.a4(a).getSeconds()+0},
hy(a){return a.c?A.a4(a).getUTCMilliseconds()+0:A.a4(a).getMilliseconds()+0},
kd(a){throw A.d(A.i5(a))},
a(a,b){if(a==null)J.aO(a)
throw A.d(A.fw(a,b))},
fw(a,b){var s,r="index"
if(!A.i1(b))return new A.am(!0,b,r,null)
s=A.a0(J.aO(a))
if(b<0||b>=s)return A.es(b,s,a,null,r)
return A.iV(b,r)},
i5(a){return new A.am(!0,a,null,null)},
d(a){return A.G(a,new Error())},
G(a,b){var s
if(a==null)a=new A.bV()
b.dartException=a
s=A.km
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:s})
b.name=""}else b.toString=s
return b},
km(){return J.b4(this.dartException)},
b2(a,b){throw A.G(a,b==null?new Error():b)},
cY(a,b,c){var s
if(b==null)b=0
if(c==null)c=0
s=Error()
A.b2(A.jv(a,b,c),s)},
jv(a,b,c){var s,r,q,p,o,n,m,l,k
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
return new A.bY("'"+s+"': Cannot "+o+" "+l+k+n)},
E(a){throw A.d(A.M(a))},
aB(a){var s,r,q,p,o,n
a=A.kk(a.replace(String({}),"$receiver$"))
s=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(s==null)s=A.j([],t.s)
r=s.indexOf("\\$arguments\\$")
q=s.indexOf("\\$argumentsExpr\\$")
p=s.indexOf("\\$expr\\$")
o=s.indexOf("\\$method\\$")
n=s.indexOf("\\$receiver\\$")
return new A.eV(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),r,q,p,o,n)},
eW(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(s){return s.message}}(a)},
hI(a){return function($expr$){try{$expr$.$method$}catch(s){return s.message}}(a)},
fP(a,b){var s=b==null,r=s?null:b.method
return new A.cD(a,r,s?null:b.receiver)},
h5(a){if(a==null)return new A.eH(a)
if(typeof a!=="object")return a
if("dartException" in a)return A.b1(a,a.dartException)
return A.jY(a)},
b1(a,b){if(t.bU.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
jY(a){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(!("message" in a))return a
s=a.message
if("number" in a&&typeof a.number=="number"){r=a.number
q=r&65535
if((B.c.aV(r,16)&8191)===10)switch(q){case 438:return A.b1(a,A.fP(A.B(s)+" (Error "+q+")",null))
case 445:case 5007:A.B(s)
return A.b1(a,new A.bM())}}if(a instanceof TypeError){p=$.ii()
o=$.ij()
n=$.ik()
m=$.il()
l=$.ip()
k=$.iq()
j=$.io()
$.im()
i=$.is()
h=$.ir()
g=p.K(s)
if(g!=null)return A.b1(a,A.fP(A.v(s),g))
else{g=o.K(s)
if(g!=null){g.method="call"
return A.b1(a,A.fP(A.v(s),g))}else if(n.K(s)!=null||m.K(s)!=null||l.K(s)!=null||k.K(s)!=null||j.K(s)!=null||m.K(s)!=null||i.K(s)!=null||h.K(s)!=null){A.v(s)
return A.b1(a,new A.bM())}}return A.b1(a,new A.cN(typeof s=="string"?s:""))}if(a instanceof RangeError){if(typeof s=="string"&&s.indexOf("call stack")!==-1)return new A.bQ()
s=function(b){try{return String(b)}catch(f){}return null}(a)
return A.b1(a,new A.am(!1,null,null,typeof s=="string"?s.replace(/^RangeError:\s*/,""):s))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof s=="string"&&s==="too much recursion")return new A.bQ()
return a},
ib(a){if(a==null)return J.a1(a)
if(typeof a=="object")return A.cH(a)
return J.a1(a)},
k8(a,b){var s,r,q,p=a.length
for(s=0;s<p;s=q){r=s+1
q=r+1
b.q(0,a[s],a[r])}return b},
k9(a,b){var s,r=a.length
for(s=0;s<r;++s)b.l(0,a[s])
return b},
jF(a,b,c,d,e,f){t.Z.a(a)
switch(A.a0(b)){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.d(new A.fe("Unsupported number of arguments for wrapped closure"))},
k0(a,b){var s=a.$identity
if(!!s)return s
s=A.k1(a,b)
a.$identity=s
return s},
k1(a,b){var s
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
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.jF)},
iG(a2){var s,r,q,p,o,n,m,l,k,j,i=a2.co,h=a2.iS,g=a2.iI,f=a2.nDA,e=a2.aI,d=a2.fs,c=a2.cs,b=d[0],a=c[0],a0=i[b],a1=a2.fT
a1.toString
s=h?Object.create(new A.cK().constructor.prototype):Object.create(new A.b5(null,null).constructor.prototype)
s.$initialize=s.constructor
r=h?function static_tear_off(){this.$initialize()}:function tear_off(a3,a4){this.$initialize(a3,a4)}
s.constructor=r
r.prototype=s
s.$_name=b
s.$_target=a0
q=!h
if(q)p=A.he(b,a0,g,f)
else{s.$static_name=b
p=a0}s.$S=A.iC(a1,h,g)
s[a]=p
for(o=p,n=1;n<d.length;++n){m=d[n]
if(typeof m=="string"){l=i[m]
k=m
m=l}else k=""
j=c[n]
if(j!=null){if(q)m=A.he(k,m,g,f)
s[j]=m}if(n===e)o=m}s.$C=o
s.$R=a2.rC
s.$D=a2.dV
return r},
iC(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.d("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.iA)}throw A.d("Error in functionType of tearoff")},
iD(a,b,c,d){var s=A.hc
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,s)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,s)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,s)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,s)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,s)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,s)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,s)}},
he(a,b,c,d){if(c)return A.iF(a,b,d)
return A.iD(b.length,d,a,b)},
iE(a,b,c,d){var s=A.hc,r=A.iB
switch(b?-1:a){case 0:throw A.d(new A.cJ("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,r,s)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,r,s)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,r,s)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,r,s)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,r,s)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,r,s)
default:return function(e,f,g){return function(){var q=[g(this)]
Array.prototype.push.apply(q,arguments)
return e.apply(f(this),q)}}(d,r,s)}},
iF(a,b,c){var s,r
if($.ha==null)$.ha=A.h9("interceptor")
if($.hb==null)$.hb=A.h9("receiver")
s=b.length
r=A.iE(s,c,a,b)
return r},
h1(a){return A.iG(a)},
iA(a,b){return A.c7(v.typeUniverse,A.ca(a.a),b)},
hc(a){return a.a},
iB(a){return a.b},
h9(a){var s,r,q,p=new A.b5("receiver","interceptor"),o=Object.getOwnPropertyNames(p)
o.$flags=1
s=o
for(o=s.length,r=0;r<o;++r){q=s[r]
if(p[q]===a)return q}throw A.d(A.dd("Field name "+a+" not found."))},
i8(a){return v.getIsolateTag(a)},
j9(a,b){var s,r
for(s=0;s<a.length;++s){r=a[s]
if(!(s<b.length))return A.a(b,s)
if(!J.cc(r,b[s]))return!1}return!0},
k3(a,b){var s=b.length,r=v.rttc[""+s+";"+a]
if(r==null)return null
if(s===0)return r
if(s===r.length)return r.apply(null,b)
return r(b)},
iN(a,b,c,d,e,f){var s=b?"m":"",r=c?"":"i",q=d?"u":"",p=e?"s":"",o=function(g,h){try{return new RegExp(g,h)}catch(n){return n}}(a,s+r+q+p+f)
if(o instanceof RegExp)return o
throw A.d(A.cu("Illegal RegExp pattern ("+String(o)+")",a))},
kk(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
bi:function bi(a){this.a=a},
bs:function bs(a,b){this.a=a
this.$ti=b},
br:function br(){},
dD:function dD(a,b,c){this.a=a
this.b=b
this.c=c},
ap:function ap(a,b,c){this.a=a
this.b=b
this.$ti=c},
cw:function cw(){},
b7:function b7(a,b){this.a=a
this.$ti=b},
bO:function bO(){},
eV:function eV(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
bM:function bM(){},
cD:function cD(a,b,c){this.a=a
this.b=b
this.c=c},
cN:function cN(a){this.a=a},
eH:function eH(a){this.a=a},
Q:function Q(){},
cg:function cg(){},
ch:function ch(){},
cL:function cL(){},
cK:function cK(){},
b5:function b5(a,b){this.a=a
this.b=b},
cJ:function cJ(a){this.a=a},
at:function at(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
ew:function ew(a){this.a=a},
eA:function eA(a,b){this.a=a
this.b=b
this.c=null},
au:function au(a,b){this.a=a
this.$ti=b},
bG:function bG(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
aa:function aa(a,b){this.a=a
this.$ti=b},
bH:function bH(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
bE:function bE(a,b){this.a=a
this.$ti=b},
bF:function bF(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
aZ:function aZ(){},
bh:function bh(){},
cC:function cC(a,b){var _=this
_.a=a
_.b=b
_.e=_.c=null},
fj:function fj(a){this.b=a},
fS(a,b){var s=b.c
return s==null?b.c=A.c5(a,"hk",[b.x]):s},
hF(a){var s=a.w
if(s===6||s===7)return A.hF(a.x)
return s===11||s===12},
iY(a){return a.as},
kj(a,b){var s,r=b.length
for(s=0;s<r;++s)if(!a[s].b(b[s]))return!1
return!0},
aE(a){return A.fm(v.typeUniverse,a,!1)},
kf(a,b){var s,r,q,p,o
if(a==null)return null
s=b.y
r=a.Q
if(r==null)r=a.Q=new Map()
q=b.as
p=r.get(q)
if(p!=null)return p
o=A.aN(v.typeUniverse,a.x,s,0)
r.set(q,o)
return o},
aN(a1,a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=a2.w
switch(a0){case 5:case 1:case 2:case 3:case 4:return a2
case 6:s=a2.x
r=A.aN(a1,s,a3,a4)
if(r===s)return a2
return A.hS(a1,r,!0)
case 7:s=a2.x
r=A.aN(a1,s,a3,a4)
if(r===s)return a2
return A.hR(a1,r,!0)
case 8:q=a2.y
p=A.bl(a1,q,a3,a4)
if(p===q)return a2
return A.c5(a1,a2.x,p)
case 9:o=a2.x
n=A.aN(a1,o,a3,a4)
m=a2.y
l=A.bl(a1,m,a3,a4)
if(n===o&&l===m)return a2
return A.fW(a1,n,l)
case 10:k=a2.x
j=a2.y
i=A.bl(a1,j,a3,a4)
if(i===j)return a2
return A.hT(a1,k,i)
case 11:h=a2.x
g=A.aN(a1,h,a3,a4)
f=a2.y
e=A.jV(a1,f,a3,a4)
if(g===h&&e===f)return a2
return A.hQ(a1,g,e)
case 12:d=a2.y
a4+=d.length
c=A.bl(a1,d,a3,a4)
o=a2.x
n=A.aN(a1,o,a3,a4)
if(c===d&&n===o)return a2
return A.fX(a1,n,c,!0)
case 13:b=a2.x
if(b<a4)return a2
a=a3[b-a4]
if(a==null)return a2
return a
default:throw A.d(A.cf("Attempted to substitute unexpected RTI kind "+a0))}},
bl(a,b,c,d){var s,r,q,p,o=b.length,n=A.fn(o)
for(s=!1,r=0;r<o;++r){q=b[r]
p=A.aN(a,q,c,d)
if(p!==q)s=!0
n[r]=p}return s?n:b},
jW(a,b,c,d){var s,r,q,p,o,n,m=b.length,l=A.fn(m)
for(s=!1,r=0;r<m;r+=3){q=b[r]
p=b[r+1]
o=b[r+2]
n=A.aN(a,o,c,d)
if(n!==o)s=!0
l.splice(r,3,q,p,n)}return s?l:b},
jV(a,b,c,d){var s,r=b.a,q=A.bl(a,r,c,d),p=b.b,o=A.bl(a,p,c,d),n=b.c,m=A.jW(a,n,c,d)
if(q===r&&o===p&&m===n)return b
s=new A.cR()
s.a=q
s.b=o
s.c=m
return s},
j(a,b){a[v.arrayRti]=b
return a},
fu(a){var s=a.$S
if(s!=null){if(typeof s=="number")return A.kc(s)
return a.$S()}return null},
ke(a,b){var s
if(A.hF(b))if(a instanceof A.Q){s=A.fu(a)
if(s!=null)return s}return A.ca(a)},
ca(a){if(a instanceof A.n)return A.k(a)
if(Array.isArray(a))return A.h(a)
return A.fZ(J.b_(a))},
h(a){var s=a[v.arrayRti],r=t.gn
if(s==null)return r
if(s.constructor!==r.constructor)return r
return s},
k(a){var s=a.$ti
return s!=null?s:A.fZ(a)},
fZ(a){var s=a.constructor,r=s.$ccache
if(r!=null)return r
return A.jD(a,s)},
jD(a,b){var s=a instanceof A.Q?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,r=A.jj(v.typeUniverse,s.name)
b.$ccache=r
return r},
kc(a){var s,r=v.types,q=r[a]
if(typeof q=="string"){s=A.fm(v.typeUniverse,q,!1)
r[a]=s
return s}return q},
kb(a){return A.aD(A.k(a))},
h3(a){var s=A.fu(a)
return A.aD(s==null?A.ca(a):s)},
h0(a){var s
if(a instanceof A.aZ)return A.k5(a.$r,a.aM())
s=a instanceof A.Q?A.fu(a):null
if(s!=null)return s
if(t.dm.b(a))return J.ix(a).a
if(Array.isArray(a))return A.h(a)
return A.ca(a)},
aD(a){var s=a.r
return s==null?a.r=new A.fl(a):s},
k5(a,b){var s,r,q=b,p=q.length
if(p===0)return t.bQ
if(0>=p)return A.a(q,0)
s=A.c7(v.typeUniverse,A.h0(q[0]),"@<0>")
for(r=1;r<p;++r){if(!(r<q.length))return A.a(q,r)
s=A.hU(v.typeUniverse,s,A.h0(q[r]))}return A.c7(v.typeUniverse,s,a)},
kn(a){return A.aD(A.fm(v.typeUniverse,a,!1))},
jC(a){var s=this
s.b=A.jU(s)
return s.b(a)},
jU(a){var s,r,q,p,o
if(a===t.K)return A.jL
if(A.b0(a))return A.jP
s=a.w
if(s===6)return A.jz
if(s===1)return A.i3
if(s===7)return A.jG
r=A.jT(a)
if(r!=null)return r
if(s===8){q=a.x
if(a.y.every(A.b0)){a.f="$i"+q
if(q==="r")return A.jJ
if(a===t.p)return A.jI
return A.jO}}else if(s===10){p=A.k3(a.x,a.y)
o=p==null?A.i3:p
return o==null?A.hY(o):o}return A.jx},
jT(a){if(a.w===8){if(a===t.S)return A.i1
if(a===t.i||a===t.H)return A.jK
if(a===t.N)return A.jN
if(a===t.y)return A.h_}return null},
jB(a){var s=this,r=A.jw
if(A.b0(s))r=A.js
else if(s===t.K)r=A.hY
else if(A.bo(s)){r=A.jy
if(s===t.I)r=A.jo
else if(s===t.dk)r=A.jr
else if(s===t.fQ)r=A.jm
else if(s===t.cg)r=A.hX
else if(s===t.cD)r=A.jn
else if(s===t.bX)r=A.jq}else if(s===t.S)r=A.a0
else if(s===t.N)r=A.v
else if(s===t.y)r=A.fq
else if(s===t.H)r=A.o
else if(s===t.i)r=A.t
else if(s===t.p)r=A.jp
s.a=r
return s.a(a)},
jx(a){var s=this
if(a==null)return A.bo(s)
return A.i9(v.typeUniverse,A.ke(a,s),s)},
jz(a){if(a==null)return!0
return this.x.b(a)},
jO(a){var s,r=this
if(a==null)return A.bo(r)
s=r.f
if(a instanceof A.n)return!!a[s]
return!!J.b_(a)[s]},
jJ(a){var s,r=this
if(a==null)return A.bo(r)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
s=r.f
if(a instanceof A.n)return!!a[s]
return!!J.b_(a)[s]},
jI(a){var s=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.n)return!!a[s.f]
return!0}if(typeof a=="function")return!0
return!1},
i2(a){if(typeof a=="object"){if(a instanceof A.n)return t.p.b(a)
return!0}if(typeof a=="function")return!0
return!1},
jw(a){var s=this
if(a==null){if(A.bo(s))return a}else if(s.b(a))return a
throw A.G(A.hZ(a,s),new Error())},
jy(a){var s=this
if(a==null||s.b(a))return a
throw A.G(A.hZ(a,s),new Error())},
hZ(a,b){return new A.bj("TypeError: "+A.hK(a,A.V(b,null)))},
k_(a,b,c,d){if(A.i9(v.typeUniverse,a,b))return a
throw A.G(A.jb("The type argument '"+A.V(a,null)+"' is not a subtype of the type variable bound '"+A.V(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
hK(a,b){return A.ct(a)+": type '"+A.V(A.h0(a),null)+"' is not a subtype of type '"+b+"'"},
jb(a){return new A.bj("TypeError: "+a)},
a8(a,b){return new A.bj("TypeError: "+A.hK(a,b))},
jG(a){var s=this
return s.x.b(a)||A.fS(v.typeUniverse,s).b(a)},
jL(a){return a!=null},
hY(a){if(a!=null)return a
throw A.G(A.a8(a,"Object"),new Error())},
jP(a){return!0},
js(a){return a},
i3(a){return!1},
h_(a){return!0===a||!1===a},
fq(a){if(!0===a)return!0
if(!1===a)return!1
throw A.G(A.a8(a,"bool"),new Error())},
jm(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.G(A.a8(a,"bool?"),new Error())},
t(a){if(typeof a=="number")return a
throw A.G(A.a8(a,"double"),new Error())},
jn(a){if(typeof a=="number")return a
if(a==null)return a
throw A.G(A.a8(a,"double?"),new Error())},
i1(a){return typeof a=="number"&&Math.floor(a)===a},
a0(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.G(A.a8(a,"int"),new Error())},
jo(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.G(A.a8(a,"int?"),new Error())},
jK(a){return typeof a=="number"},
o(a){if(typeof a=="number")return a
throw A.G(A.a8(a,"num"),new Error())},
hX(a){if(typeof a=="number")return a
if(a==null)return a
throw A.G(A.a8(a,"num?"),new Error())},
jN(a){return typeof a=="string"},
v(a){if(typeof a=="string")return a
throw A.G(A.a8(a,"String"),new Error())},
jr(a){if(typeof a=="string")return a
if(a==null)return a
throw A.G(A.a8(a,"String?"),new Error())},
jp(a){if(A.i2(a))return a
throw A.G(A.a8(a,"JSObject"),new Error())},
jq(a){if(a==null)return a
if(A.i2(a))return a
throw A.G(A.a8(a,"JSObject?"),new Error())},
i4(a,b){var s,r,q
for(s="",r="",q=0;q<a.length;++q,r=", ")s+=r+A.V(a[q],b)
return s},
jS(a,b){var s,r,q,p,o,n,m=a.x,l=a.y
if(""===m)return"("+A.i4(l,b)+")"
s=l.length
r=m.split(",")
q=r.length-s
for(p="(",o="",n=0;n<s;++n,o=", "){p+=o
if(q===0)p+="{"
p+=A.V(l[n],b)
if(q>=0)p+=" "+r[q];++q}return p+"})"},
i_(a3,a4,a5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=", ",a2=null
if(a5!=null){s=a5.length
if(a4==null)a4=A.j([],t.s)
else a2=a4.length
r=a4.length
for(q=s;q>0;--q)B.a.l(a4,"T"+(r+q))
for(p=t.Y,o="<",n="",q=0;q<s;++q,n=a1){m=a4.length
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
if(l===8){p=A.jX(a.x)
o=a.y
return o.length>0?p+("<"+A.i4(o,b)+">"):p}if(l===10)return A.jS(a,b)
if(l===11)return A.i_(a,b,null)
if(l===12)return A.i_(a.x,b,a.y)
if(l===13){n=a.x
m=b.length
n=m-1-n
if(!(n>=0&&n<m))return A.a(b,n)
return b[n]}return"?"},
jX(a){var s=v.mangledGlobalNames[a]
if(s!=null)return s
return"minified:"+a},
jk(a,b){var s=a.tR[b]
while(typeof s=="string")s=a.tR[s]
return s},
jj(a,b){var s,r,q,p,o,n=a.eT,m=n[b]
if(m==null)return A.fm(a,b,!1)
else if(typeof m=="number"){s=m
r=A.c6(a,5,"#")
q=A.fn(s)
for(p=0;p<s;++p)q[p]=r
o=A.c5(a,b,q)
n[b]=o
return o}else return m},
ji(a,b){return A.hV(a.tR,b)},
jh(a,b){return A.hV(a.eT,b)},
fm(a,b,c){var s,r=a.eC,q=r.get(b)
if(q!=null)return q
s=A.hO(A.hM(a,null,b,!1))
r.set(b,s)
return s},
c7(a,b,c){var s,r,q=b.z
if(q==null)q=b.z=new Map()
s=q.get(c)
if(s!=null)return s
r=A.hO(A.hM(a,b,c,!0))
q.set(c,r)
return r},
hU(a,b,c){var s,r,q,p=b.Q
if(p==null)p=b.Q=new Map()
s=c.as
r=p.get(s)
if(r!=null)return r
q=A.fW(a,b,c.w===9?c.y:[c])
p.set(s,q)
return q},
aL(a,b){b.a=A.jB
b.b=A.jC
return b},
c6(a,b,c){var s,r,q=a.eC.get(c)
if(q!=null)return q
s=new A.ac(null,null)
s.w=b
s.as=c
r=A.aL(a,s)
a.eC.set(c,r)
return r},
hS(a,b,c){var s,r=b.as+"?",q=a.eC.get(r)
if(q!=null)return q
s=A.jf(a,b,r,c)
a.eC.set(r,s)
return s},
jf(a,b,c,d){var s,r,q
if(d){s=b.w
r=!0
if(!A.b0(b))if(!(b===t.a||b===t.T))if(s!==6)r=s===7&&A.bo(b.x)
if(r)return b
else if(s===1)return t.a}q=new A.ac(null,null)
q.w=6
q.x=b
q.as=c
return A.aL(a,q)},
hR(a,b,c){var s,r=b.as+"/",q=a.eC.get(r)
if(q!=null)return q
s=A.jd(a,b,r,c)
a.eC.set(r,s)
return s},
jd(a,b,c,d){var s,r
if(d){s=b.w
if(A.b0(b)||b===t.K)return b
else if(s===1)return A.c5(a,"hk",[b])
else if(b===t.a||b===t.T)return t.eH}r=new A.ac(null,null)
r.w=7
r.x=b
r.as=c
return A.aL(a,r)},
jg(a,b){var s,r,q=""+b+"^",p=a.eC.get(q)
if(p!=null)return p
s=new A.ac(null,null)
s.w=13
s.x=b
s.as=q
r=A.aL(a,s)
a.eC.set(q,r)
return r},
c4(a){var s,r,q,p=a.length
for(s="",r="",q=0;q<p;++q,r=",")s+=r+a[q].as
return s},
jc(a){var s,r,q,p,o,n=a.length
for(s="",r="",q=0;q<n;q+=3,r=","){p=a[q]
o=a[q+1]?"!":":"
s+=r+p+o+a[q+2].as}return s},
c5(a,b,c){var s,r,q,p=b
if(c.length>0)p+="<"+A.c4(c)+">"
s=a.eC.get(p)
if(s!=null)return s
r=new A.ac(null,null)
r.w=8
r.x=b
r.y=c
if(c.length>0)r.c=c[0]
r.as=p
q=A.aL(a,r)
a.eC.set(p,q)
return q},
fW(a,b,c){var s,r,q,p,o,n
if(b.w===9){s=b.x
r=b.y.concat(c)}else{r=c
s=b}q=s.as+(";<"+A.c4(r)+">")
p=a.eC.get(q)
if(p!=null)return p
o=new A.ac(null,null)
o.w=9
o.x=s
o.y=r
o.as=q
n=A.aL(a,o)
a.eC.set(q,n)
return n},
hT(a,b,c){var s,r,q="+"+(b+"("+A.c4(c)+")"),p=a.eC.get(q)
if(p!=null)return p
s=new A.ac(null,null)
s.w=10
s.x=b
s.y=c
s.as=q
r=A.aL(a,s)
a.eC.set(q,r)
return r},
hQ(a,b,c){var s,r,q,p,o,n=b.as,m=c.a,l=m.length,k=c.b,j=k.length,i=c.c,h=i.length,g="("+A.c4(m)
if(j>0){s=l>0?",":""
g+=s+"["+A.c4(k)+"]"}if(h>0){s=l>0?",":""
g+=s+"{"+A.jc(i)+"}"}r=n+(g+")")
q=a.eC.get(r)
if(q!=null)return q
p=new A.ac(null,null)
p.w=11
p.x=b
p.y=c
p.as=r
o=A.aL(a,p)
a.eC.set(r,o)
return o},
fX(a,b,c,d){var s,r=b.as+("<"+A.c4(c)+">"),q=a.eC.get(r)
if(q!=null)return q
s=A.je(a,b,c,r,d)
a.eC.set(r,s)
return s},
je(a,b,c,d,e){var s,r,q,p,o,n,m,l
if(e){s=c.length
r=A.fn(s)
for(q=0,p=0;p<s;++p){o=c[p]
if(o.w===1){r[p]=o;++q}}if(q>0){n=A.aN(a,b,r,0)
m=A.bl(a,c,r,0)
return A.fX(a,n,m,c!==m)}}l=new A.ac(null,null)
l.w=12
l.x=b
l.y=c
l.as=d
return A.aL(a,l)},
hM(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
hO(a){var s,r,q,p,o,n,m,l=a.r,k=a.s
for(s=l.length,r=0;r<s;){q=l.charCodeAt(r)
if(q>=48&&q<=57)r=A.j4(r+1,q,l,k)
else if((((q|32)>>>0)-97&65535)<26||q===95||q===36||q===124)r=A.hN(a,r,l,k,!1)
else if(q===46)r=A.hN(a,r,l,k,!0)
else{++r
switch(q){case 44:break
case 58:k.push(!1)
break
case 33:k.push(!0)
break
case 59:k.push(A.aY(a.u,a.e,k.pop()))
break
case 94:k.push(A.jg(a.u,k.pop()))
break
case 35:k.push(A.c6(a.u,5,"#"))
break
case 64:k.push(A.c6(a.u,2,"@"))
break
case 126:k.push(A.c6(a.u,3,"~"))
break
case 60:k.push(a.p)
a.p=k.length
break
case 62:A.j6(a,k)
break
case 38:A.j5(a,k)
break
case 63:p=a.u
k.push(A.hS(p,A.aY(p,a.e,k.pop()),a.n))
break
case 47:p=a.u
k.push(A.hR(p,A.aY(p,a.e,k.pop()),a.n))
break
case 40:k.push(-3)
k.push(a.p)
a.p=k.length
break
case 41:A.j3(a,k)
break
case 91:k.push(a.p)
a.p=k.length
break
case 93:o=k.splice(a.p)
A.hP(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-1)
break
case 123:k.push(a.p)
a.p=k.length
break
case 125:o=k.splice(a.p)
A.j8(a.u,a.e,o)
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
return A.aY(a.u,a.e,m)},
j4(a,b,c,d){var s,r,q=b-48
for(s=c.length;a<s;++a){r=c.charCodeAt(a)
if(!(r>=48&&r<=57))break
q=q*10+(r-48)}d.push(q)
return a},
hN(a,b,c,d,e){var s,r,q,p,o,n,m=b+1
for(s=c.length;m<s;++m){r=c.charCodeAt(m)
if(r===46){if(e)break
e=!0}else{if(!((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124))q=r>=48&&r<=57
else q=!0
if(!q)break}}p=c.substring(b,m)
if(e){s=a.u
o=a.e
if(o.w===9)o=o.x
n=A.jk(s,o.x)[p]
if(n==null)A.b2('No "'+p+'" in "'+A.iY(o)+'"')
d.push(A.c7(s,o,n))}else d.push(p)
return m},
j6(a,b){var s,r=a.u,q=A.hL(a,b),p=b.pop()
if(typeof p=="string")b.push(A.c5(r,p,q))
else{s=A.aY(r,a.e,p)
switch(s.w){case 11:b.push(A.fX(r,s,q,a.n))
break
default:b.push(A.fW(r,s,q))
break}}},
j3(a,b){var s,r,q,p=a.u,o=b.pop(),n=null,m=null
if(typeof o=="number")switch(o){case-1:n=b.pop()
break
case-2:m=b.pop()
break
default:b.push(o)
break}else b.push(o)
s=A.hL(a,b)
o=b.pop()
switch(o){case-3:o=b.pop()
if(n==null)n=p.sEA
if(m==null)m=p.sEA
r=A.aY(p,a.e,o)
q=new A.cR()
q.a=s
q.b=n
q.c=m
b.push(A.hQ(p,r,q))
return
case-4:b.push(A.hT(p,b.pop(),s))
return
default:throw A.d(A.cf("Unexpected state under `()`: "+A.B(o)))}},
j5(a,b){var s=b.pop()
if(0===s){b.push(A.c6(a.u,1,"0&"))
return}if(1===s){b.push(A.c6(a.u,4,"1&"))
return}throw A.d(A.cf("Unexpected extended operation "+A.B(s)))},
hL(a,b){var s=b.splice(a.p)
A.hP(a.u,a.e,s)
a.p=b.pop()
return s},
aY(a,b,c){if(typeof c=="string")return A.c5(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.j7(a,b,c)}else return c},
hP(a,b,c){var s,r=c.length
for(s=0;s<r;++s)c[s]=A.aY(a,b,c[s])},
j8(a,b,c){var s,r=c.length
for(s=2;s<r;s+=3)c[s]=A.aY(a,b,c[s])},
j7(a,b,c){var s,r,q=b.w
if(q===9){if(c===0)return b.x
s=b.y
r=s.length
if(c<=r)return s[c-1]
c-=r
b=b.x
q=b.w}else if(c===0)return b
if(q!==8)throw A.d(A.cf("Indexed base must be an interface type"))
s=b.y
if(c<=s.length)return s[c-1]
throw A.d(A.cf("Bad index "+c+" for "+b.j(0)))},
i9(a,b,c){var s,r=b.d
if(r==null)r=b.d=new Map()
s=r.get(c)
if(s==null){s=A.F(a,b,null,c,null)
r.set(c,s)}return s},
F(a,b,c,d,e){var s,r,q,p,o,n,m,l,k,j,i
if(b===d)return!0
if(A.b0(d))return!0
s=b.w
if(s===4)return!0
if(A.b0(b))return!1
if(b.w===1)return!0
r=s===13
if(r)if(A.F(a,c[b.x],c,d,e))return!0
q=d.w
p=t.a
if(b===p||b===t.T){if(q===7)return A.F(a,b,c,d.x,e)
return d===p||d===t.T||q===6}if(d===t.K){if(s===7)return A.F(a,b.x,c,d,e)
return s!==6}if(s===7){if(!A.F(a,b.x,c,d,e))return!1
return A.F(a,A.fS(a,b),c,d,e)}if(s===6)return A.F(a,p,c,d,e)&&A.F(a,b.x,c,d,e)
if(q===7){if(A.F(a,b,c,d.x,e))return!0
return A.F(a,b,c,A.fS(a,d),e)}if(q===6)return A.F(a,b,c,p,e)||A.F(a,b,c,d.x,e)
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
if(!A.F(a,j,c,i,e)||!A.F(a,i,e,j,c))return!1}return A.i0(a,b.x,c,d.x,e)}if(q===11){if(b===t.cj)return!0
if(p)return!1
return A.i0(a,b,c,d,e)}if(s===8){if(q!==8)return!1
return A.jH(a,b,c,d,e)}if(o&&q===10)return A.jM(a,b,c,d,e)
return!1},
i0(a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
if(!A.F(a3,a4.x,a5,a6.x,a7))return!1
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
if(!A.F(a3,p[h],a7,g,a5))return!1}for(h=0;h<m;++h){g=l[h]
if(!A.F(a3,p[o+h],a7,g,a5))return!1}for(h=0;h<i;++h){g=l[m+h]
if(!A.F(a3,k[h],a7,g,a5))return!1}f=s.c
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
if(!A.F(a3,e[a+2],a7,g,a5))return!1
break}}while(b<d){if(f[b+1])return!1
b+=3}return!0},
jH(a,b,c,d,e){var s,r,q,p,o,n=b.x,m=d.x
while(n!==m){s=a.tR[n]
if(s==null)return!1
if(typeof s=="string"){n=s
continue}r=s[m]
if(r==null)return!1
q=r.length
p=q>0?new Array(q):v.typeUniverse.sEA
for(o=0;o<q;++o)p[o]=A.c7(a,b,r[o])
return A.hW(a,p,null,c,d.y,e)}return A.hW(a,b.y,null,c,d.y,e)},
hW(a,b,c,d,e,f){var s,r=b.length
for(s=0;s<r;++s)if(!A.F(a,b[s],d,e[s],f))return!1
return!0},
jM(a,b,c,d,e){var s,r=b.y,q=d.y,p=r.length
if(p!==q.length)return!1
if(b.x!==d.x)return!1
for(s=0;s<p;++s)if(!A.F(a,r[s],c,q[s],e))return!1
return!0},
bo(a){var s=a.w,r=!0
if(!(a===t.a||a===t.T))if(!A.b0(a))if(s!==6)r=s===7&&A.bo(a.x)
return r},
b0(a){var s=a.w
return s===2||s===3||s===4||s===5||a===t.Y},
hV(a,b){var s,r,q=Object.keys(b),p=q.length
for(s=0;s<p;++s){r=q[s]
a[r]=b[r]}},
fn(a){return a>0?new Array(a):v.typeUniverse.sEA},
ac:function ac(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
cR:function cR(){this.c=this.b=this.a=null},
fl:function fl(a){this.a=a},
cQ:function cQ(){},
bj:function bj(a){this.a=a},
hq(a,b){return new A.at(a.h("@<0>").u(b).h("at<1,2>"))},
S(a,b,c){return b.h("@<0>").u(c).h("hp<1,2>").a(A.k8(a,new A.at(b.h("@<0>").u(c).h("at<1,2>"))))},
ab(a,b){return new A.at(a.h("@<0>").u(b).h("at<1,2>"))},
hs(a){return new A.aC(a.h("aC<0>"))},
ht(a){return new A.aC(a.h("aC<0>"))},
iQ(a,b){return b.h("hr<0>").a(A.k9(a,new A.aC(b.h("aC<0>"))))},
fV(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
j2(a,b,c){var s=new A.aX(a,b,c.h("aX<0>"))
s.c=a.e
return s},
iP(a,b,c){var s=A.hq(b,c)
a.J(0,new A.eB(s,b,c))
return s},
hu(a,b){var s=A.hs(b)
s.B(0,a)
return s},
eF(a){var s,r
if(A.h4(a))return"{...}"
s=new A.be("")
try{r={}
B.a.l($.a7,a)
s.a+="{"
r.a=!0
a.J(0,new A.eG(r,s))
s.a+="}"}finally{if(0>=$.a7.length)return A.a($.a7,-1)
$.a7.pop()}r=s.a
return r.charCodeAt(0)==0?r:r},
iR(a){return 8},
jl(){throw A.d(A.eX("Cannot change an unmodifiable set"))},
aC:function aC(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
cU:function cU(a){this.a=a
this.b=null},
aX:function aX(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
eB:function eB(a,b,c){this.a=a
this.b=b
this.c=c},
N:function N(){},
eG:function eG(a,b){this.a=a
this.b=b},
c8:function c8(){},
bc:function bc(){},
bW:function bW(){},
eC:function eC(a,b){var _=this
_.a=a
_.d=_.c=_.b=0
_.$ti=b},
c1:function c1(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=null
_.$ti=e},
aW:function aW(){},
c3:function c3(){},
cV:function cV(){},
bX:function bX(a,b){this.a=a
this.$ti=b},
bk:function bk(){},
c9:function c9(){},
jR(a,b){var s,r,q,p=null
try{p=JSON.parse(a)}catch(r){s=A.h5(r)
q=A.cu(String(s),null)
throw A.d(q)}q=A.fr(p)
return q},
fr(a){var s
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.cS(a,Object.create(null))
for(s=0;s<a.length;++s)a[s]=A.fr(a[s])
return a},
ho(a,b,c){return new A.bC(a,b)},
ju(a){return a.cE()},
j0(a,b){return new A.fg(a,[],A.k2())},
j1(a,b,c){var s,r=new A.be(""),q=A.j0(r,b)
q.af(a)
s=r.a
return s.charCodeAt(0)==0?s:s},
cS:function cS(a,b){this.a=a
this.b=b
this.c=null},
cT:function cT(a){this.a=a},
ci:function ci(){},
cm:function cm(){},
bC:function bC(a,b){this.a=a
this.b=b},
cE:function cE(a,b){this.a=a
this.b=b},
ex:function ex(){},
ez:function ez(a){this.b=a},
ey:function ey(a){this.a=a},
fh:function fh(){},
fi:function fi(a,b){this.a=a
this.b=b},
fg:function fg(a,b,c){this.c=a
this.a=b
this.b=c},
cW(a){var s=A.iU(a,null)
if(s!=null)return s
throw A.d(A.cu(a,null))},
bI(a,b,c,d){var s,r=J.hn(a,d)
if(a!==0&&b!=null)for(s=0;s<a;++s)r[s]=b
return r},
fQ(a,b,c){var s,r=A.j([],c.h("l<0>"))
for(s=J.W(a);s.n();)B.a.l(r,c.a(s.gp()))
if(b)return r
r.$flags=1
return r},
q(a,b){var s,r
if(Array.isArray(a))return A.j(a.slice(0),b.h("l<0>"))
s=A.j([],b.h("l<0>"))
for(r=J.W(a);r.n();)B.a.l(s,r.gp())
return s},
T(a,b){var s=A.fQ(a,!1,b)
s.$flags=3
return s},
iX(a){return new A.cC(a,A.iN(a,!1,!0,!1,!1,""))},
hH(a,b,c){var s=J.W(b)
if(!s.n())return a
if(c.length===0){do a+=A.B(s.gp())
while(s.n())}else{a+=A.B(s.gp())
while(s.n())a=a+c+A.B(s.gp())}return a},
iI(a,b,c,d,e,f,g,h,i){var s=A.hD(a,b,c,d,e,f,g,h,i)
if(s==null)return null
return new A.ag(A.hi(s,h,i),h,i)},
iH(a){var s=A.hD(a,1,1,0,0,0,0,0,!0)
return new A.ag(s==null?new A.dM(a,1,1,0,0,0,0,0).$0():s,0,!0)},
dO(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=$.ih().cg(a)
if(c!=null){s=new A.dP()
r=c.b
if(1>=r.length)return A.a(r,1)
q=r[1]
q.toString
p=A.cW(q)
if(2>=r.length)return A.a(r,2)
q=r[2]
q.toString
o=A.cW(q)
if(3>=r.length)return A.a(r,3)
q=r[3]
q.toString
n=A.cW(q)
if(4>=r.length)return A.a(r,4)
m=s.$1(r[4])
if(5>=r.length)return A.a(r,5)
l=s.$1(r[5])
if(6>=r.length)return A.a(r,6)
k=s.$1(r[6])
if(7>=r.length)return A.a(r,7)
j=new A.dQ().$1(r[7])
i=B.c.A(j,1000)
q=r.length
if(8>=q)return A.a(r,8)
h=r[8]!=null
if(h){if(9>=q)return A.a(r,9)
g=r[9]
if(g!=null){f=g==="-"?-1:1
if(10>=q)return A.a(r,10)
q=r[10]
q.toString
e=A.cW(q)
if(11>=r.length)return A.a(r,11)
l-=f*(s.$1(r[11])+60*e)}}d=A.iI(p,o,n,m,l,k,i,j%1000,h)
if(d==null)throw A.d(A.cu("Time out of range",a))
return d}else throw A.d(A.cu("Invalid date format",a))},
hi(a,b,c){var s="microsecond"
if(b<0||b>999)throw A.d(A.aj(b,0,999,s,null))
if(a<-864e13||a>864e13)throw A.d(A.aj(a,-864e13,864e13,"millisecondsSinceEpoch",null))
if(a===864e13&&b!==0)throw A.d(A.iz(b,s,"Time including microseconds is outside valid range"))
A.i6(c,"isUtc",t.y)
return a},
hh(a){var s=Math.abs(a),r=a<0?"-":""
if(s>=1000)return""+a
if(s>=100)return r+"0"+s
if(s>=10)return r+"00"+s
return r+"000"+s},
iJ(a){var s=Math.abs(a),r=a<0?"-":"+"
if(s>=1e5)return r+s
return r+"0"+s},
dN(a){if(a>=100)return""+a
if(a>=10)return"0"+a
return"00"+a},
aq(a){if(a>=10)return""+a
return"0"+a},
I(a,b){return new A.R(a+1000*b)},
ct(a){if(typeof a=="number"||A.h_(a)||a==null)return J.b4(a)
if(typeof a=="string")return JSON.stringify(a)
return A.hC(a)},
cf(a){return new A.ce(a)},
dd(a){return new A.am(!1,null,null,a)},
iz(a,b,c){return new A.am(!0,a,b,c)},
de(a,b,c){return a},
iV(a,b){return new A.bN(null,null,!0,a,b,"Value not in range")},
aj(a,b,c,d,e){return new A.bN(b,c,!0,a,d,"Invalid value")},
hE(a,b,c){if(0>a||a>c)throw A.d(A.aj(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.d(A.aj(b,a,c,"end",null))
return b}return c},
aw(a,b){if(a<0)throw A.d(A.aj(a,0,null,b,null))
return a},
es(a,b,c,d,e){return new A.cv(b,!0,a,e,"Index out of range")},
eX(a){return new A.bY(a)},
iZ(a){return new A.bd(a)},
M(a){return new A.cl(a)},
cu(a,b){return new A.er(a,b)},
iL(a,b,c){var s,r
if(A.h4(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}s=A.j([],t.s)
B.a.l($.a7,a)
try{A.jQ(a,s)}finally{if(0>=$.a7.length)return A.a($.a7,-1)
$.a7.pop()}r=A.hH(b,t.hf.a(s),", ")+c
return r.charCodeAt(0)==0?r:r},
fN(a,b,c){var s,r
if(A.h4(a))return b+"..."+c
s=new A.be(b)
B.a.l($.a7,a)
try{r=s
r.a=A.hH(r.a,a,", ")}finally{if(0>=$.a7.length)return A.a($.a7,-1)
$.a7.pop()}s.a+=c
r=s.a
return r.charCodeAt(0)==0?r:r},
jQ(a,b){var s,r,q,p,o,n,m,l=a.gt(a),k=0,j=0
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
fR(a,b,c,d){var s
if(B.d===c){s=J.a1(a)
b=J.a1(b)
return A.eK(A.ay(A.ay($.cZ(),s),b))}if(B.d===d){s=J.a1(a)
b=J.a1(b)
c=J.a1(c)
return A.eK(A.ay(A.ay(A.ay($.cZ(),s),b),c))}s=J.a1(a)
b=J.a1(b)
c=J.a1(c)
d=J.a1(d)
d=A.eK(A.ay(A.ay(A.ay(A.ay($.cZ(),s),b),c),d))
return d},
iT(a){var s,r,q=$.cZ()
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.E)(a),++r)q=A.ay(q,J.a1(a[r]))
return A.eK(q)},
dM:function dM(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
ag:function ag(a,b,c){this.a=a
this.b=b
this.c=c},
dP:function dP(){},
dQ:function dQ(){},
R:function R(a){this.a=a},
fd:function fd(){},
A:function A(){},
ce:function ce(a){this.a=a},
bV:function bV(){},
am:function am(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bN:function bN(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
cv:function cv(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
bY:function bY(a){this.a=a},
bd:function bd(a){this.a=a},
cl:function cl(a){this.a=a},
cF:function cF(){},
bQ:function bQ(){},
fe:function fe(a){this.a=a},
er:function er(a,b){this.a=a
this.b=b},
c:function c(){},
J:function J(a,b,c){this.a=a
this.b=b
this.$ti=c},
aU:function aU(){},
n:function n(){},
be:function be(a){this.a=a},
d_:function d_(){},
d7:function d7(a){this.a=a},
d8:function d8(){},
d9:function d9(a){this.a=a},
da:function da(a,b){this.a=a
this.b=b},
db:function db(a,b){this.a=a
this.b=b},
d0:function d0(){},
d2:function d2(){},
d1:function d1(a){this.a=a},
d3:function d3(a,b){this.a=a
this.b=b},
d4:function d4(){},
d6:function d6(){},
d5:function d5(a){this.a=a},
iy(a,b,c,d){var s,r,q,p,o,n,m,l,k=a.Q
if(!k||!a.ax||a.c!==c)return null
s=a.e
r=Math.max(s,d)
q=a.f
p=Math.min(q,b)
o=q-s
s=p-r
if(s<=0.01||o<=0.01)return null
q=new A.dc(a,o)
n=q.$1(r)
m=q.$1(p)
l=Math.min(s,m-n)
return A.hf(l,a.y,a.x,l>=3000,k,a.a,p,a.c,r,a.as,a.ax,a.ay,a.b,m,a.d,n)},
dc:function dc(a,b){this.a=a
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
dg:function dg(){},
dv:function dv(){},
dw:function dw(){},
dh:function dh(a){this.a=a},
di:function di(){},
dl:function dl(a){this.a=a},
dm:function dm(){},
dp:function dp(){},
dq:function dq(a){this.a=a},
dr:function dr(){},
ds:function ds(){},
dk:function dk(a){this.a=a},
dj:function dj(a){this.a=a},
dt:function dt(){},
du:function du(){},
dn:function dn(a){this.a=a},
aM:function aM(a,b){this.a=a
this.b=b},
ak:function ak(a,b,c){this.a=a
this.b=b
this.c=c},
dx:function dx(a,b,c,d){var _=this
_.a=a
_.f=b
_.r=c
_.z=d},
df:function df(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
K:function K(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.w=f
_.x=g},
dy:function dy(){},
hf(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p){return new A.cj(f,m,h,o,i,g,p,n,c,b,a,e,j,d,k,l)},
cj:function cj(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p){var _=this
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
an:function an(a,b){this.a=a
this.b=b},
ck:function ck(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.r=c
_.w=d
_.x=e
_.y=f},
bq:function bq(a,b){this.a=a
this.b=b},
ao:function ao(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
dC:function dC(a,b){this.a=a
this.b=b},
jA(a,b){var s
if(!isFinite(a)||a<0||a>=360)return null
s=B.b.V(Math.abs(a-b),360)
return s>180?360-s:s},
dz:function dz(){},
dA:function dA(){},
dB:function dB(){},
c2:function c2(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.r=_.f=$},
ae:function ae(a,b,c){this.a=a
this.b=b
this.c=c},
ff:function ff(a,b,c){this.a=a
this.b=b
this.c=c},
co:function co(){},
dJ:function dJ(a,b){this.a=a
this.b=b},
dK:function dK(){},
dL:function dL(){},
dF:function dF(){},
dG:function dG(){},
dH:function dH(){},
dI:function dI(){},
dE:function dE(){},
cn:function cn(a,b,c){this.a=a
this.y=b
this.z=c},
af:function af(a,b,c,d,e,f,g){var _=this
_.e=a
_.r=b
_.w=c
_.x=d
_.y=e
_.z=f
_.Q=g},
dR:function dR(){},
cq:function cq(){},
dV:function dV(){},
dU:function dU(){},
dW:function dW(a,b){this.a=a
this.b=b},
e6:function e6(){},
e5:function e5(){},
e7:function e7(a){this.a=a},
e9:function e9(){},
e8:function e8(){},
ea:function ea(a){this.a=a},
eb:function eb(){},
dX:function dX(){},
ec:function ec(){},
dY:function dY(a,b){this.a=a
this.b=b},
dZ:function dZ(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
e_:function e_(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
e0:function e0(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
e1:function e1(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
e2:function e2(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
e3:function e3(){},
e4:function e4(a){this.a=a},
dT:function dT(a,b){this.a=a
this.b=b},
a6:function a6(a,b){this.a=a
this.b=b},
ed:function ed(a,b){this.a=a
this.b=b},
ee:function ee(){},
ef:function ef(){},
cx:function cx(){},
et:function et(){},
eg:function eg(){},
eh:function eh(){},
bt:function bt(a,b){this.a=a
this.b=b},
H:function H(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
aF:function aF(a,b){this.b=a
this.c=b},
ei:function ei(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
hj(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s){return new A.p(h,d,s,o,e,q,g,p,f,i,k,c,a,r,n,m,b,l,j)},
ah:function ah(a,b){this.a=a
this.b=b},
bf:function bf(a,b){this.a=a
this.b=b},
aR:function aR(a,b){this.a=a
this.b=b},
aG:function aG(a,b){this.a=a
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
az:function az(a,b,c){this.a=a
this.c=b
this.d=c},
ar:function ar(a,b,c){this.a=a
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
cp:function cp(a,b,c){this.b=a
this.c=b
this.f=c},
dS:function dS(a){this.a=a},
ej:function ej(){},
ek:function ek(){},
em:function em(){},
el:function el(a){this.a=a},
en:function en(){},
eo:function eo(){},
ep:function ep(){},
eq:function eq(){},
cs:function cs(a,b,c){this.a=a
this.f=b
this.r=c},
cr:function cr(a,b,c){this.a=a
this.b=b
this.c=c},
cd:function cd(a,b,c){this.a=a
this.e=b
this.f=c},
ai:function ai(a,b){this.a=a
this.b=b},
a9:function a9(a,b){this.a=a
this.e=b},
cM:function cM(a,b,c){this.a=a
this.e=b
this.f=c},
bb:function bb(a,b){this.a=a
this.b=b},
bJ:function bJ(a,b){this.a=a
this.b=b},
aI:function aI(a,b,c,d,e,f,g,h){var _=this
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
bK:function bK(a,b,c){this.a=a
this.c=b
this.d=c},
eD:function eD(a){this.a=a},
eE:function eE(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
fp:function fp(a,b,c,d,e,f){var _=this
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
eL:function eL(){},
fo:function fo(a,b){this.a=a
this.b=b},
bU:function bU(a,b,c){this.a=a
this.r=b
this.as=c},
bT:function bT(a){this.a=a},
eM:function eM(){},
eR:function eR(a){this.a=a},
eS:function eS(a){this.a=a},
eT:function eT(){},
eU:function eU(){},
eQ:function eQ(a){this.a=a},
eO:function eO(){},
eP:function eP(){},
eN:function eN(a){this.a=a},
eY:function eY(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.x=f
_.y=g
_.Q=h},
eZ:function eZ(a,b){this.a=a
this.f=b},
ja(a,b,c){return new A.D(a.c,a.b,a.d,a.r,b,c)},
cO:function cO(){},
f5:function f5(){},
f6:function f6(a){this.a=a},
f7:function f7(a,b){this.a=a
this.b=b},
f8:function f8(a){this.a=a},
f9:function f9(a,b,c){this.a=a
this.b=b
this.c=c},
fa:function fa(){},
fb:function fb(a,b,c){this.a=a
this.b=b
this.c=c},
f2:function f2(){},
f3:function f3(){},
f1:function f1(a){this.a=a},
f4:function f4(a){this.a=a},
f_:function f_(){},
f0:function f0(){},
al:function al(a,b,c){this.a=a
this.b=b
this.c=c},
C:function C(a,b){this.a=a
this.b=b},
D:function D(a,b,c,d,e,f){var _=this
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
fc:function fc(a,b,c){this.a=a
this.b=b
this.c=c},
cP:function cP(a,b,c){this.a=a
this.c=b
this.d=c},
ki(a){t.E.a(a)
return A.S(["id",a.a,"sourceDriveId",a.b,"validatedRoadId",a.c,"matchedSectionId",a.d,"startOffsetMeters",B.b.j(a.e),"endOffsetMeters",B.b.j(a.f),"directionKey",a.r,"minLatitude",B.b.j(a.w),"maxLatitude",B.b.j(a.x),"minLongitude",B.b.j(a.y),"maxLongitude",B.b.j(a.z),"processingVersion",a.at,"createdAt",a.Q.O().aC(),"updatedAt",a.as.O().aC()],t.N,t.z)},
k6(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=A.dO(A.v(a.i(0,"now"))),e=t.j,d=t.E,c=J.b3(e.a(a.i(0,"traces")),new A.fy(),d),b=A.q(c,c.$ti.h("m.E"))
c=t.N
d=A.ab(c,d)
for(s=b.length,r=0;r<b.length;b.length===s||(0,A.E)(b),++r){q=b[r]
d.q(0,q.a,q)}s=t.bI
d=J.b3(e.a(a.i(0,"inputs")),new A.fz(d),s)
p=A.q(d,d.$ti.h("m.E"))
o=A.ab(c,s)
for(e=p.length,d=t.r,s=t.A,r=0;r<p.length;p.length===e||(0,A.E)(p),++r){n=p[r]
m=n.a
l=m.a
k=o.i(0,l)
j=A.j([],s)
i=k==null
h=i?null:k.b
if(h!=null)B.a.B(j,h)
B.a.B(j,n.b)
h=A.j([],d)
i=i?null:k.c
if(i!=null)B.a.B(h,i)
B.a.B(h,n.c)
o.q(0,l,new A.aK(m,j,h))}e=A.cX(t.P.a(a.i(0,"challenger")))
d=o.$ti.h("aa<2>")
d=A.q(new A.aa(o,d),d.h("c.E"))
g=B.a9.cq(e,new A.cP(0,b,B.O),f,d)
e=g.f.c
d=A.h(e)
s=d.h("f<1,u<e,@>>")
e=A.q(new A.f(e,d.h("u<e,@>(1)").a(A.ko()),s),s.h("m.E"))
return A.S(["operationId",g.a,"traces",e],c,t.z)},
fy:function fy(){},
fz:function fz(a){this.a=a},
fx:function fx(a){this.a=a},
k4(a){var s=A.h2(t.P.a(a.i(0,"match"))),r=A.v(a.i(0,"sectionId")),q=A.o(a.i(0,"start")),p=A.iy(s,A.o(a.i(0,"end")),r,q)
if(p==null)return null
return A.S(["firstStartOffsetMeters",p.e,"firstEndOffsetMeters",p.f,"secondStartOffsetMeters",p.r,"secondEndOffsetMeters",p.w,"commonDistanceMeters",p.z,"comparisonEligible",p.at],t.N,t.z)},
cX(a){var s,r,q,p,o,n=J.b3(t.j.a(a.i(0,"sections")),new A.fE(),t.o),m=A.q(n,n.$ti.h("m.E"))
A.iH(1970)
n=A.v(a.i(0,"id"))
s=A.v(a.i(0,"driveId"))
r=A.h(m)
q=r.h("bx<1,Z>")
r=A.q(new A.bx(m,r.h("c<Z>(1)").a(new A.fF()),q),q.h("c.E"))
q=B.a.G(m,0,new A.fG(),t.i)
p=a.i(0,"processingVersion")
p=A.a0(p==null?3:p)
o=a.i(0,"directionKey")
return new A.eY(n,s,r,m,q,null,p,A.v(o==null?"":o))},
fK(a){var s=J.b3(a,new A.fL(),t.u)
s=A.q(s,s.$ti.h("m.E"))
return s},
ic(a){var s,r=t.N,q=t.z
if(a==null)r=A.ab(r,q)
else{s=t.h6
q=A.S(["totalScore",a.a,"displayScore",a.c,"algorithmVersion",a.d,"overallConfidence",a.b,"categories",a.e.a5(0,new A.fH(),r,s),"contributions",a.f.a5(0,new A.fI(),r,s)],r,q)
r=q}return r},
i7(a){var s,r=a.e
r=r==null?null:A.ic(r)
s=a.f
s=s==null?null:A.ic(s)
return A.S(["outcome",a.x.b,"comparisonValid",a.y,"firstLocalScore",r,"secondLocalScore",s,"scoreDifference",a.r,"relativeDifference",a.w],t.N,t.z)},
cb(a){var s=a.b,r=A.h(s),q=r.h("f<1,e>")
r=A.q(new A.f(s,r.h("e(1)").a(new A.fJ()),q),q.h("m.E"))
return A.S(["status",a.a.b,"startIndex",a.c,"endIndex",a.d,"count",s.length,"mappingConfidence",a.e,"timestamps",r],t.N,t.z)},
k7(a){var s,r,q,p,o,n,m,l="firstRoad",k="firstTelemetry",j="secondRoad",i="secondTelemetry"
if(!J.cc(a.i(0,"algorithmVersion"),1))return A.S(["status","unsupportedAlgorithmVersion","windows",[],"winningRegions",[]],t.N,t.z)
s=t.P
r=A.h2(s.a(a.i(0,"match")))
if(J.cc(a.i(0,"operation"),"extract")){q=A.cX(s.a(a.i(0,l)))
p=t.j
o=A.fK(p.a(a.i(0,k)))
s=A.cX(s.a(a.i(0,j)))
p=A.fK(p.a(a.i(0,i)))
n=t.t
m=B.k.aw(q,n.a(o),r,s,n.a(p))
s=m.gaB()?"success":"telemetryUnavailable"
return A.S(["status",s,"firstExtraction",A.cb(m.a),"secondExtraction",A.cb(m.b),"windows",[],"winningRegions",[]],t.N,t.z)}if(!r.at)return A.S(["status","notEligible","windows",[],"winningRegions",[]],t.N,t.z)
q=t.j
return A.jZ(r,A.cX(s.a(a.i(0,l))),A.cX(s.a(a.i(0,j))),A.fK(q.a(a.i(0,k))),A.fK(q.a(a.i(0,i))))},
h2(a1){var s,r,q,p,o,n,m,l="latitude",k="longitude",j=A.v(a1.i(0,"firstDriveId")),i=A.v(a1.i(0,"secondDriveId")),h=A.v(a1.i(0,"firstSectionId")),g=A.v(a1.i(0,"secondSectionId")),f=A.o(a1.i(0,"firstStartOffsetMeters")),e=A.o(a1.i(0,"firstEndOffsetMeters")),d=A.o(a1.i(0,"secondStartOffsetMeters")),c=A.o(a1.i(0,"secondEndOffsetMeters")),b=t.P,a=b.a(a1.i(0,"commonStart")),a0=A.o(a.i(0,l))
a=A.o(a.i(0,k))
b=b.a(a1.i(0,"commonEnd"))
s=A.o(b.i(0,l))
b=A.o(b.i(0,k))
r=A.o(a1.i(0,"commonDistanceMeters"))
q=A.fq(a1.i(0,"directionCompatible"))
p=A.o(a1.i(0,"geometryConfidence"))
o=A.fq(a1.i(0,"comparisonEligible"))
n=A.fq(a1.i(0,"ownershipCovered"))
m=J.b3(t.j.a(a1.i(0,"referenceGeometry")),new A.fv(),t.cX)
m=A.q(m,m.$ti.h("m.E"))
return A.hf(r,new A.Z(s,b),new A.Z(a0,a),o,q,j,e,h,f,p,n,m,i,c,g,d)},
jZ(a,b,c,d,e){var s,r,q,p,o,n,m,l,k="secondExtraction",j=t.t,i=B.k.aw(b,j.a(d),a,c,j.a(e))
if(!i.gaB())return A.S(["status","telemetryUnavailable","firstExtraction",A.cb(i.a),k,A.cb(i.b),"windows",[],"winningRegions",[]],t.N,t.z)
j=i.a
s=j.b
r=i.b
q=r.b
p=B.x.cb(B.o,b,s,a,c,q)
o=new A.eD(B.x).ca(B.o,c,q,b,s,a)
s=A.i7(p)
j=A.cb(j)
r=A.cb(r)
q=o.c
n=A.h(q)
m=n.h("f<1,u<e,n>>")
q=A.q(new A.f(q,n.h("u<e,n>(1)").a(new A.fs()),m),m.h("m.E"))
n=o.d
m=A.h(n)
l=m.h("f<1,u<e,n>>")
n=A.q(new A.f(n,m.h("u<e,n>(1)").a(new A.ft()),l),l.h("m.E"))
return A.S(["status",o.a.b,"comparison",s,"firstExtraction",j,k,r,"windows",q,"winningRegions",n],t.N,t.z)},
fE:function fE(){},
fD:function fD(){},
fF:function fF(){},
fG:function fG(){},
fL:function fL(){},
fH:function fH(){},
fI:function fI(){},
fJ:function fJ(){},
fv:function fv(){},
fs:function fs(){},
ft:function ft(){},
kg(){var s=v.G
s.driveItWorldMutation=A.fY(new A.fA())
s.driveItActiveCoverage=A.fY(new A.fB())
s.driveItWorldScoring=A.fY(new A.fC())},
fA:function fA(){},
fB:function fB(){},
fC:function fC(){},
aK:function aK(a,b,c){this.a=a
this.b=b
this.c=c},
kl(a){throw A.G(new A.bD("Field '"+a+"' has been assigned during initialization."),new Error())},
id(){throw A.G(A.iO(""),new Error())},
fY(a){var s
if(typeof a=="function")throw A.d(A.dd("Attempting to rewrap a JS function."))
s=function(b,c){return function(d){return b(c,d,arguments.length)}}(A.jt,a)
s[$.h6()]=a
return s},
jt(a,b,c){t.Z.a(a)
if(A.a0(c)>=1)return a.$1(b)
return a.$0()},
ia(a,b,c){A.k_(c,t.H,"T","max")
return Math.max(c.a(a),c.a(b))},
hl(a,b,c,d){var s=Math.sin((c-a)*3.141592653589793/180/2),r=Math.sin((d-b)*3.141592653589793/180/2)
return 12742017.6*Math.asin(Math.sqrt(B.b.k(s*s+Math.cos(a*3.141592653589793/180)*Math.cos(c*3.141592653589793/180)*r*r,0,1)))},
hJ(a){var s=a.c,r=A.fT(a.b)
return isFinite(s)&&s>0?s:r},
fT(a){var s,r,q,p,o
for(s=0,r=0;r<a.length-1;){q=a[r];++r
p=a[r]
o=A.hl(q.a,q.b,p.a,p.b)
if(isFinite(o)&&o>0)s+=o}return s},
fU(a,b,c){if(!isFinite(b)||!isFinite(a)||!isFinite(c)||a<=0||c<=0)return 0
return B.b.k(B.b.k(b/a,0,1)*c,0,c)}},B={}
var w=[A,J,B]
var $={}
A.fO.prototype={}
J.cy.prototype={
M(a,b){return a===b},
gD(a){return A.cH(a)},
j(a){return"Instance of '"+A.cI(a)+"'"},
gU(a){return A.aD(A.fZ(this))}}
J.cA.prototype={
j(a){return String(a)},
gD(a){return a?519018:218159},
gU(a){return A.aD(t.y)},
$iaA:1,
$ii:1}
J.bA.prototype={
M(a,b){return null==b},
j(a){return"null"},
gD(a){return 0},
$iaA:1}
J.ba.prototype={$ib9:1}
J.aH.prototype={
gD(a){return 0},
j(a){return String(a)}}
J.eI.prototype={}
J.aJ.prototype={}
J.bB.prototype={
j(a){var s=a[$.ig()]
if(s==null)s=a[$.h6()]
if(s==null)return this.b8(a)
return"JavaScript function for "+J.b4(s)},
$ias:1}
J.l.prototype={
l(a,b){A.h(a).c.a(b)
a.$flags&1&&A.cY(a,29)
a.push(b)},
B(a,b){var s
A.h(a).h("c<1>").a(b)
a.$flags&1&&A.cY(a,"addAll",2)
if(Array.isArray(b)){this.bb(a,b)
return}for(s=J.W(b);s.n();)a.push(s.gp())},
bb(a,b){var s,r
t.gn.a(b)
s=b.length
if(s===0)return
if(a===b)throw A.d(A.M(a))
for(r=0;r<s;++r)a.push(b[r])},
b3(a,b,c){var s=A.h(a)
return new A.f(a,s.u(c).h("1(2)").a(b),s.h("@<1>").u(c).h("f<1,2>"))},
co(a,b){var s,r=A.bI(a.length,"",!1,t.N)
for(s=0;s<a.length;++s)this.q(r,s,A.B(a[s]))
return r.join(b)},
N(a,b){return A.bS(a,b,null,A.h(a).c)},
L(a,b){var s,r,q
A.h(a).h("1(1,1)").a(b)
s=a.length
if(s===0)throw A.d(A.aS())
if(0>=s)return A.a(a,0)
r=a[0]
for(q=1;q<s;++q){r=b.$2(r,a[q])
if(s!==a.length)throw A.d(A.M(a))}return r},
G(a,b,c,d){var s,r,q
d.a(b)
A.h(a).u(d).h("1(1,2)").a(c)
s=a.length
for(r=b,q=0;q<s;++q){r=c.$2(r,a[q])
if(a.length!==s)throw A.d(A.M(a))}return r},
az(a,b,c){var s,r,q
A.h(a).h("i(1)").a(b)
s=a.length
for(r=0;r<s;++r){q=a[r]
if(b.$1(q))return q
if(a.length!==s)throw A.d(A.M(a))}throw A.d(A.aS())},
ci(a,b){return this.az(a,b,null)},
E(a,b){if(!(b>=0&&b<a.length))return A.a(a,b)
return a[b]},
a6(a,b,c){if(b<0||b>a.length)throw A.d(A.aj(b,0,a.length,"start",null))
if(c<b||c>a.length)throw A.d(A.aj(c,b,a.length,"end",null))
if(b===c)return A.j([],A.h(a))
return A.j(a.slice(b,c),A.h(a))},
gI(a){if(a.length>0)return a[0]
throw A.d(A.aS())},
gT(a){var s=a.length
if(s>0)return a[s-1]
throw A.d(A.aS())},
aE(a,b,c,d,e){var s,r,q,p,o
A.h(a).h("c<1>").a(d)
a.$flags&2&&A.cY(a,5)
A.hE(b,c,a.length)
s=c-b
if(s===0)return
A.aw(e,"skipCount")
if(t.j.b(d)){r=d
q=e}else{r=J.h8(d,e).b4(0,!1)
q=0}p=J.bn(r)
if(q+s>p.gm(r))throw A.d(A.iK())
if(q<b)for(o=s-1;o>=0;--o)a[b+o]=p.i(r,q+o)
else for(o=0;o<s;++o)a[b+o]=p.i(r,q+o)},
a4(a,b){var s,r
A.h(a).h("i(1)").a(b)
s=a.length
for(r=0;r<s;++r){if(b.$1(a[r]))return!0
if(a.length!==s)throw A.d(A.M(a))}return!1},
a0(a,b){var s,r,q,p,o,n=A.h(a)
n.h("O(1,1)?").a(b)
a.$flags&2&&A.cY(a,"sort")
s=a.length
if(s<2)return
if(b==null)b=J.jE()
if(s===2){r=a[0]
q=a[1]
n=b.$2(r,q)
if(typeof n!=="number")return n.cB()
if(n>0){a[0]=q
a[1]=r}return}p=0
if(n.c.b(null))for(o=0;o<a.length;++o)if(a[o]===void 0){a[o]=null;++p}a.sort(A.k0(b,2))
if(p>0)this.bM(a,p)},
aF(a){return this.a0(a,null)},
bM(a,b){var s,r=a.length
for(;s=r-1,r>0;r=s)if(a[s]===null){a[s]=void 0;--b
if(b===0)break}},
gv(a){return a.length===0},
gZ(a){return a.length!==0},
j(a){return A.fN(a,"[","]")},
gt(a){return new J.aP(a,a.length,A.h(a).h("aP<1>"))},
gD(a){return A.cH(a)},
gm(a){return a.length},
i(a,b){A.a0(b)
if(!(b>=0&&b<a.length))throw A.d(A.fw(a,b))
return a[b]},
q(a,b,c){A.h(a).c.a(c)
a.$flags&2&&A.cY(a)
if(!(b>=0&&b<a.length))throw A.d(A.fw(a,b))
a[b]=c},
$iw:1,
$ic:1,
$ir:1}
J.cz.prototype={
ct(a){var s,r,q
if(!Array.isArray(a))return null
s=a.$flags|0
if((s&4)!==0)r="const, "
else if((s&2)!==0)r="unmodifiable, "
else r=(s&1)!==0?"fixed, ":""
q="Instance of '"+A.cI(a)+"'"
if(r==="")return q
return q+" ("+r+"length: "+a.length+")"}}
J.ev.prototype={}
J.aP.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
n(){var s,r=this,q=r.a,p=q.length
if(r.b!==p){q=A.E(q)
throw A.d(q)}s=r.c
if(s>=p){r.d=null
return!1}r.d=q[s]
r.c=s+1
return!0},
$iy:1}
J.b8.prototype={
C(a,b){var s
A.o(b)
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){s=this.gad(b)
if(this.gad(a)===s)return 0
if(this.gad(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gad(a){return a===0?1/a<0:a<0},
cs(a){var s
if(a>=-2147483648&&a<=2147483647)return a|0
if(isFinite(a)){s=a<0?Math.ceil(a):Math.floor(a)
return s+0}throw A.d(A.eX(""+a+".toInt()"))},
ae(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.d(A.eX(""+a+".round()"))},
k(a,b,c){if(this.C(b,c)>0)throw A.d(A.i5(b))
if(this.C(a,b)<0)return b
if(this.C(a,c)>0)return c
return a},
a_(a,b){var s
if(b>20)throw A.d(A.aj(b,0,20,"fractionDigits",null))
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
V(a,b){var s=a%b
if(s===0)return 0
if(s>0)return s
return s+b},
A(a,b){return(a|0)===a?a/b|0:this.c_(a,b)},
c_(a,b){var s=a/b
if(s>=-2147483648&&s<=2147483647)return s|0
if(s>0){if(s!==1/0)return Math.floor(s)}else if(s>-1/0)return Math.ceil(s)
throw A.d(A.eX("Result of truncating division is "+A.B(s)+": "+A.B(a)+" ~/ "+b))},
aV(a,b){var s
if(a>0)s=this.bT(a,b)
else{s=b>31?31:b
s=a>>s>>>0}return s},
bT(a,b){return b>31?0:a>>>b},
gU(a){return A.aD(t.H)},
$ia2:1,
$ib:1,
$iP:1}
J.bz.prototype={
gU(a){return A.aD(t.S)},
$iaA:1,
$iO:1}
J.cB.prototype={
gU(a){return A.aD(t.i)},
$iaA:1}
J.aT.prototype={
a1(a,b,c){return a.substring(b,A.hE(b,c,a.length))},
aD(a,b){var s,r
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.d(B.a6)
for(s=a,r="";;){if((b&1)===1)r=s+r
b=b>>>1
if(b===0)break
s+=s}return r},
cp(a,b,c){var s=b-a.length
if(s<=0)return a
return this.aD(c,s)+a},
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
gU(a){return A.aD(t.N)},
gm(a){return a.length},
i(a,b){A.a0(b)
if(!(b.cA(0,0)&&b.cD(0,a.length)))throw A.d(A.fw(a,b))
return a[b]},
$iaA:1,
$ia2:1,
$ie:1}
A.bg.prototype={
gt(a){return new A.bp(J.W(this.gX()),A.k(this).h("bp<1,2>"))},
gm(a){return J.aO(this.gX())},
gv(a){return J.fM(this.gX())},
gZ(a){return J.iw(this.gX())},
N(a,b){var s=A.k(this)
return A.hd(J.h8(this.gX(),b),s.c,s.y[1])},
j(a){return J.b4(this.gX())}}
A.bp.prototype={
n(){return this.a.n()},
gp(){return this.$ti.y[1].a(this.a.gp())},
$iy:1}
A.aQ.prototype={
gX(){return this.a}}
A.c0.prototype={$iw:1}
A.bD.prototype={
j(a){return"LateInitializationError: "+this.a}}
A.eJ.prototype={}
A.w.prototype={}
A.m.prototype={
gt(a){var s=this
return new A.av(s,s.gm(s),A.k(s).h("av<m.E>"))},
gv(a){return this.gm(this)===0},
a4(a,b){var s,r,q=this
A.k(q).h("i(m.E)").a(b)
s=q.gm(q)
for(r=0;r<s;++r){if(b.$1(q.E(0,r)))return!0
if(s!==q.gm(q))throw A.d(A.M(q))}return!1},
L(a,b){var s,r,q,p=this
A.k(p).h("m.E(m.E,m.E)").a(b)
s=p.gm(p)
if(s===0)throw A.d(A.aS())
r=p.E(0,0)
for(q=1;q<s;++q){r=b.$2(r,p.E(0,q))
if(s!==p.gm(p))throw A.d(A.M(p))}return r},
N(a,b){return A.bS(this,b,null,A.k(this).h("m.E"))}}
A.bR.prototype={
gbq(){var s=J.aO(this.a),r=this.c
if(r==null||r>s)return s
return r},
gbV(){var s=J.aO(this.a),r=this.b
if(r>s)return s
return r},
gm(a){var s,r=J.aO(this.a),q=this.b
if(q>=r)return 0
s=this.c
if(s==null||s>=r)return r-q
return s-q},
E(a,b){var s=this,r=s.gbV()+b
if(b<0||r>=s.gbq())throw A.d(A.es(b,s.gm(0),s,null,"index"))
return J.h7(s.a,r)},
N(a,b){var s,r,q=this
A.aw(b,"count")
s=q.b+b
r=q.c
if(r!=null&&s>=r)return new A.bv(q.$ti.h("bv<1>"))
return A.bS(q.a,s,r,q.$ti.c)},
b4(a,b){var s,r,q,p=this,o=p.b,n=p.a,m=J.bn(n),l=m.gm(n),k=p.c
if(k!=null&&k<l)l=k
s=l-o
if(s<=0){n=J.hn(0,p.$ti.c)
return n}r=A.bI(s,m.E(n,o),!1,p.$ti.c)
for(q=1;q<s;++q){B.a.q(r,q,m.E(n,o+q))
if(m.gm(n)<l)throw A.d(A.M(p))}return r}}
A.av.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
n(){var s,r=this,q=r.a,p=q.gm(q)
if(r.b!==p)throw A.d(A.M(q))
s=r.c
if(s>=p){r.d=null
return!1}r.d=q.E(0,s);++r.c
return!0},
$iy:1}
A.a3.prototype={
gt(a){return new A.bL(J.W(this.a),this.b,A.k(this).h("bL<1,2>"))},
gm(a){return J.aO(this.a)},
gv(a){return J.fM(this.a)}}
A.bu.prototype={$iw:1}
A.bL.prototype={
n(){var s=this,r=s.b
if(r.n()){s.a=s.c.$1(r.gp())
return!0}s.a=null
return!1},
gp(){var s=this.a
return s==null?this.$ti.y[1].a(s):s},
$iy:1}
A.f.prototype={
gm(a){return J.aO(this.a)},
E(a,b){return this.b.$1(J.h7(this.a,b))}}
A.x.prototype={
gt(a){return new A.ad(J.W(this.a),this.b,this.$ti.h("ad<1>"))}}
A.ad.prototype={
n(){var s,r
for(s=this.a,r=this.b;s.n();)if(r.$1(s.gp()))return!0
return!1},
gp(){return this.a.gp()},
$iy:1}
A.bx.prototype={
gt(a){return new A.by(J.W(this.a),this.b,B.z,this.$ti.h("by<1,2>"))}}
A.by.prototype={
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
A.ax.prototype={
N(a,b){A.de(b,"count",t.S)
A.aw(b,"count")
return new A.ax(this.a,this.b+b,A.k(this).h("ax<1>"))},
gt(a){var s=this.a
return new A.bP(s.gt(s),this.b,A.k(this).h("bP<1>"))}}
A.b6.prototype={
gm(a){var s=this.a,r=s.gm(s)-this.b
if(r>=0)return r
return 0},
N(a,b){A.de(b,"count",t.S)
A.aw(b,"count")
return new A.b6(this.a,this.b+b,this.$ti)},
$iw:1}
A.bP.prototype={
n(){var s,r
for(s=this.a,r=0;r<this.b;++r)s.n()
this.b=0
return s.n()},
gp(){return this.a.gp()},
$iy:1}
A.bv.prototype={
gt(a){return B.z},
gv(a){return!0},
gm(a){return 0},
N(a,b){A.aw(b,"count")
return this}}
A.bw.prototype={
n(){return!1},
gp(){throw A.d(A.aS())},
$iy:1}
A.bZ.prototype={
gt(a){return new A.c_(J.W(this.a),this.$ti.h("c_<1>"))}}
A.c_.prototype={
n(){var s,r
for(s=this.a,r=this.$ti.c;s.n();)if(r.b(s.gp()))return!0
return!1},
gp(){return this.$ti.c.a(this.a.gp())},
$iy:1}
A.bi.prototype={$r:"+(1,2,3,4)",$s:1}
A.bs.prototype={}
A.br.prototype={
gv(a){return this.gm(this)===0},
j(a){return A.eF(this)},
a5(a,b,c,d){var s=A.ab(c,d)
this.J(0,new A.dD(this,A.k(this).u(c).u(d).h("J<1,2>(3,4)").a(b),s))
return s},
$iu:1}
A.dD.prototype={
$2(a,b){var s=A.k(this.a),r=this.b.$2(s.c.a(a),s.y[1].a(b))
this.c.q(0,r.a,r.b)},
$S(){return A.k(this.a).h("~(1,2)")}}
A.ap.prototype={
gm(a){return this.b.length},
gbA(){var s=this.$keys
if(s==null){s=Object.keys(this.a)
this.$keys=s}return s},
ar(a){if(typeof a!="string")return!1
if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
i(a,b){if(!this.ar(b))return null
return this.b[this.a[b]]},
J(a,b){var s,r,q,p
this.$ti.h("~(1,2)").a(b)
s=this.gbA()
r=this.b
for(q=s.length,p=0;p<q;++p)b.$2(s[p],r[p])}}
A.cw.prototype={
M(a,b){if(b==null)return!1
return b instanceof A.b7&&this.a.M(0,b.a)&&A.h3(this)===A.h3(b)},
gD(a){return A.fR(this.a,A.h3(this),B.d,B.d)},
j(a){var s=B.a.co([A.aD(this.$ti.c)],", ")
return this.a.j(0)+" with "+("<"+s+">")}}
A.b7.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.kf(A.fu(this.a),this.$ti)}}
A.bO.prototype={}
A.eV.prototype={
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
A.bM.prototype={
j(a){return"Null check operator used on a null value"}}
A.cD.prototype={
j(a){var s,r=this,q="NoSuchMethodError: method not found: '",p=r.b
if(p==null)return"NoSuchMethodError: "+r.a
s=r.c
if(s==null)return q+p+"' ("+r.a+")"
return q+p+"' on '"+s+"' ("+r.a+")"}}
A.cN.prototype={
j(a){var s=this.a
return s.length===0?"Error":"Error: "+s}}
A.eH.prototype={
j(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.Q.prototype={
j(a){var s=this.constructor,r=s==null?null:s.name
return"Closure '"+A.ie(r==null?"unknown":r)+"'"},
$ias:1,
gcw(){return this},
$C:"$1",
$R:1,
$D:null}
A.cg.prototype={$C:"$0",$R:0}
A.ch.prototype={$C:"$2",$R:2}
A.cL.prototype={}
A.cK.prototype={
j(a){var s=this.$static_name
if(s==null)return"Closure of unknown static method"
return"Closure '"+A.ie(s)+"'"}}
A.b5.prototype={
M(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.b5))return!1
return this.$_target===b.$_target&&this.a===b.a},
gD(a){return(A.ib(this.a)^A.cH(this.$_target))>>>0},
j(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.cI(this.a)+"'")}}
A.cJ.prototype={
j(a){return"RuntimeError: "+this.a}}
A.at.prototype={
gm(a){return this.a},
gv(a){return this.a===0},
gS(){return new A.au(this,A.k(this).h("au<1>"))},
ar(a){var s=this.b
if(s==null)return!1
return s[a]!=null},
B(a,b){A.k(this).h("u<1,2>").a(b).J(0,new A.ew(this))},
i(a,b){var s,r,q,p,o=null
if(typeof b=="string"){s=this.b
if(s==null)return o
r=s[b]
q=r==null?o:r.b
return q}else if(typeof b=="number"&&(b&0x3fffffff)===b){p=this.c
if(p==null)return o
r=p[b]
q=r==null?o:r.b
return q}else return this.ck(b)},
ck(a){var s,r,q=this.d
if(q==null)return null
s=q[this.b1(a)]
r=this.b2(s,a)
if(r<0)return null
return s[r].b},
q(a,b,c){var s,r,q=this,p=A.k(q)
p.c.a(b)
p.y[1].a(c)
if(typeof b=="string"){s=q.b
q.aG(s==null?q.b=q.am():s,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){r=q.c
q.aG(r==null?q.c=q.am():r,b,c)}else q.cl(b,c)},
cl(a,b){var s,r,q,p,o=this,n=A.k(o)
n.c.a(a)
n.y[1].a(b)
s=o.d
if(s==null)s=o.d=o.am()
r=o.b1(a)
q=s[r]
if(q==null)s[r]=[o.an(a,b)]
else{p=o.b2(q,a)
if(p>=0)q[p].b=b
else q.push(o.an(a,b))}},
cr(a,b){var s,r,q=this,p=A.k(q)
p.c.a(a)
p.h("2()").a(b)
if(q.ar(a)){s=q.i(0,a)
return s==null?p.y[1].a(s):s}r=b.$0()
q.q(0,a,r)
return r},
J(a,b){var s,r,q=this
A.k(q).h("~(1,2)").a(b)
s=q.e
r=q.r
while(s!=null){b.$2(s.a,s.b)
if(r!==q.r)throw A.d(A.M(q))
s=s.c}},
aG(a,b,c){var s,r=A.k(this)
r.c.a(b)
r.y[1].a(c)
s=a[b]
if(s==null)a[b]=this.an(b,c)
else s.b=c},
an(a,b){var s=this,r=A.k(s),q=new A.eA(r.c.a(a),r.y[1].a(b))
if(s.e==null)s.e=s.f=q
else s.f=s.f.c=q;++s.a
s.r=s.r+1&1073741823
return q},
b1(a){return J.a1(a)&1073741823},
b2(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.cc(a[r].a,b))return r
return-1},
j(a){return A.eF(this)},
am(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
$ihp:1}
A.ew.prototype={
$2(a,b){var s=this.a,r=A.k(s)
s.q(0,r.c.a(a),r.y[1].a(b))},
$S(){return A.k(this.a).h("~(1,2)")}}
A.eA.prototype={}
A.au.prototype={
gm(a){return this.a.a},
gv(a){return this.a.a===0},
gt(a){var s=this.a
return new A.bG(s,s.r,s.e,this.$ti.h("bG<1>"))}}
A.bG.prototype={
gp(){return this.d},
n(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.d(A.M(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.a
r.c=s.c
return!0}},
$iy:1}
A.aa.prototype={
gm(a){return this.a.a},
gv(a){return this.a.a===0},
gt(a){var s=this.a
return new A.bH(s,s.r,s.e,this.$ti.h("bH<1>"))}}
A.bH.prototype={
gp(){return this.d},
n(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.d(A.M(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.b
r.c=s.c
return!0}},
$iy:1}
A.bE.prototype={
gm(a){return this.a.a},
gv(a){return this.a.a===0},
gt(a){var s=this.a
return new A.bF(s,s.r,s.e,this.$ti.h("bF<1,2>"))}}
A.bF.prototype={
gp(){var s=this.d
s.toString
return s},
n(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.d(A.M(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=new A.J(s.a,s.b,r.$ti.h("J<1,2>"))
r.c=s.c
return!0}},
$iy:1}
A.aZ.prototype={
j(a){return this.aX(!1)},
aX(a){var s,r,q,p,o,n=this.br(),m=this.aM(),l=(a?"Record ":"")+"("
for(s=n.length,r="",q=0;q<s;++q,r=", "){l+=r
p=n[q]
if(typeof p=="string")l=l+p+": "
if(!(q<m.length))return A.a(m,q)
o=m[q]
l=a?l+A.hC(o):l+A.B(o)}l+=")"
return l.charCodeAt(0)==0?l:l},
br(){var s,r=this.$s
while($.fk.length<=r)B.a.l($.fk,null)
s=$.fk[r]
if(s==null){s=this.bk()
B.a.q($.fk,r,s)}return s},
bk(){var s,r,q,p=this.$r,o=p.indexOf("("),n=p.substring(1,o),m=p.substring(o),l=m==="()"?0:m.replace(/[^,]/g,"").length+1,k=t.K,j=J.hm(l,k)
for(s=0;s<l;++s)j[s]=s
if(n!==""){r=n.split(",")
s=r.length
for(q=l;s>0;){--q;--s
B.a.q(j,q,r[s])}}return A.T(j,k)}}
A.bh.prototype={
aM(){return this.a},
M(a,b){if(b==null)return!1
return b instanceof A.bh&&this.$s===b.$s&&A.j9(this.a,b.a)},
gD(a){return A.fR(this.$s,A.iT(this.a),B.d,B.d)}}
A.cC.prototype={
j(a){return"RegExp/"+this.a+"/"+this.b.flags},
cg(a){var s=this.b.exec(a)
if(s==null)return null
return new A.fj(s)},
$iiW:1}
A.fj.prototype={
i(a,b){var s
A.a0(b)
s=this.b
if(!(b<s.length))return A.a(s,b)
return s[b]}}
A.ac.prototype={
h(a){return A.c7(v.typeUniverse,this,a)},
u(a){return A.hU(v.typeUniverse,this,a)}}
A.cR.prototype={}
A.fl.prototype={
j(a){return A.V(this.a,null)}}
A.cQ.prototype={
j(a){return this.a}}
A.bj.prototype={}
A.aC.prototype={
gt(a){var s=this,r=new A.aX(s,s.r,A.k(s).h("aX<1>"))
r.c=s.e
return r},
gm(a){return this.a},
gv(a){return this.a===0},
gZ(a){return this.a!==0},
ac(a,b){var s,r
if(typeof b=="string"&&b!=="__proto__"){s=this.b
if(s==null)return!1
return t.br.a(s[b])!=null}else{r=this.bl(b)
return r}},
bl(a){var s=this.d
if(s==null)return!1
return this.aK(s[this.aI(a)],a)>=0},
l(a,b){var s,r,q=this
A.k(q).c.a(b)
if(typeof b=="string"&&b!=="__proto__"){s=q.b
return q.aH(s==null?q.b=A.fV():s,b)}else if(typeof b=="number"&&(b&1073741823)===b){r=q.c
return q.aH(r==null?q.c=A.fV():r,b)}else return q.ba(b)},
ba(a){var s,r,q,p=this
A.k(p).c.a(a)
s=p.d
if(s==null)s=p.d=A.fV()
r=p.aI(a)
q=s[r]
if(q==null)s[r]=[p.ah(a)]
else{if(p.aK(q,a)>=0)return!1
q.push(p.ah(a))}return!0},
aH(a,b){A.k(this).c.a(b)
if(t.br.a(a[b])!=null)return!1
a[b]=this.ah(b)
return!0},
ah(a){var s=this,r=new A.cU(A.k(s).c.a(a))
if(s.e==null)s.e=s.f=r
else s.f=s.f.b=r;++s.a
s.r=s.r+1&1073741823
return r},
aI(a){return J.a1(a)&1073741823},
aK(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.cc(a[r].a,b))return r
return-1},
$ihr:1}
A.cU.prototype={}
A.aX.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
n(){var s=this,r=s.c,q=s.a
if(s.b!==q.r)throw A.d(A.M(q))
else if(r==null){s.d=null
return!1}else{s.d=s.$ti.h("1?").a(r.a)
s.c=r.b
return!0}},
$iy:1}
A.eB.prototype={
$2(a,b){this.a.q(0,this.b.a(a),this.c.a(b))},
$S:22}
A.N.prototype={
J(a,b){var s,r,q,p=A.k(this)
p.h("~(N.K,N.V)").a(b)
for(s=this.gS(),s=s.gt(s),p=p.h("N.V");s.n();){r=s.gp()
q=this.i(0,r)
b.$2(r,q==null?p.a(q):q)}},
a5(a,b,c,d){var s,r,q,p,o,n=A.k(this)
n.u(c).u(d).h("J<1,2>(N.K,N.V)").a(b)
s=A.ab(c,d)
for(r=this.gS(),r=r.gt(r),n=n.h("N.V");r.n();){q=r.gp()
p=this.i(0,q)
o=b.$2(q,p==null?n.a(p):p)
s.q(0,o.a,o.b)}return s},
gm(a){var s=this.gS()
return s.gm(s)},
gv(a){var s=this.gS()
return s.gv(s)},
j(a){return A.eF(this)},
$iu:1}
A.eG.prototype={
$2(a,b){var s,r=this.a
if(!r.a)this.b.a+=", "
r.a=!1
r=this.b
s=A.B(a)
r.a=(r.a+=s)+": "
s=A.B(b)
r.a+=s},
$S:9}
A.c8.prototype={}
A.bc.prototype={
i(a,b){return this.a.i(0,b)},
J(a,b){this.a.J(0,this.$ti.h("~(1,2)").a(b))},
gv(a){return this.a.a===0},
gm(a){return this.a.a},
j(a){return A.eF(this.a)},
a5(a,b,c,d){return this.a.a5(0,this.$ti.u(c).u(d).h("J<1,2>(3,4)").a(b),c,d)},
$iu:1}
A.bW.prototype={}
A.eC.prototype={
gt(a){var s=this
return new A.c1(s,s.c,s.d,s.b,s.$ti.h("c1<1>"))},
gv(a){return this.b===this.c},
gm(a){return(this.c-this.b&this.a.length-1)>>>0},
E(a,b){var s,r,q=this,p=q.gm(0)
if(0>b||b>=p)A.b2(A.es(b,p,q,null,"index"))
p=q.a
s=p.length
r=(q.b+b&s-1)>>>0
if(!(r>=0&&r<s))return A.a(p,r)
r=p[r]
return r==null?q.$ti.c.a(r):r},
j(a){return A.fN(this,"{","}")}}
A.c1.prototype={
gp(){var s=this.e
return s==null?this.$ti.c.a(s):s},
n(){var s,r,q=this,p=q.a
if(q.c!==p.d)A.b2(A.M(p))
s=q.d
if(s===q.b){q.e=null
return!1}p=p.a
r=p.length
if(!(s<r))return A.a(p,s)
q.e=p[s]
q.d=(s+1&r-1)>>>0
return!0},
$iy:1}
A.aW.prototype={
gv(a){return this.gm(this)===0},
gZ(a){return this.gm(this)!==0},
B(a,b){var s
for(s=J.W(A.k(this).h("c<1>").a(b));s.n();)this.l(0,s.gp())},
j(a){return A.fN(this,"{","}")},
N(a,b){return A.hG(this,b,A.k(this).c)},
$iw:1,
$ic:1,
$iaV:1}
A.c3.prototype={}
A.cV.prototype={
l(a,b){this.$ti.c.a(b)
return A.jl()}}
A.bX.prototype={
ac(a,b){return this.a.ac(0,b)},
gm(a){return this.a.a},
gt(a){var s=this.a
return A.j2(s,s.r,A.k(s).c)}}
A.bk.prototype={}
A.c9.prototype={}
A.cS.prototype={
i(a,b){var s,r=this.b
if(r==null)return this.c.i(0,b)
else if(typeof b!="string")return null
else{s=r[b]
return typeof s=="undefined"?this.bI(b):s}},
gm(a){return this.b==null?this.c.a:this.a8().length},
gv(a){return this.gm(0)===0},
gS(){if(this.b==null){var s=this.c
return new A.au(s,A.k(s).h("au<1>"))}return new A.cT(this)},
J(a,b){var s,r,q,p,o=this
t.fH.a(b)
if(o.b==null)return o.c.J(0,b)
s=o.a8()
for(r=0;r<s.length;++r){q=s[r]
p=o.b[q]
if(typeof p=="undefined"){p=A.fr(o.a[q])
o.b[q]=p}b.$2(q,p)
if(s!==o.c)throw A.d(A.M(o))}},
a8(){var s=t.bF.a(this.c)
if(s==null)s=this.c=A.j(Object.keys(this.a),t.s)
return s},
bI(a){var s
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
s=A.fr(this.a[a])
return this.b[a]=s}}
A.cT.prototype={
gm(a){return this.a.gm(0)},
E(a,b){var s=this.a
if(s.b==null)s=s.gS().E(0,b)
else{s=s.a8()
if(!(b>=0&&b<s.length))return A.a(s,b)
s=s[b]}return s},
gt(a){var s=this.a
if(s.b==null){s=s.gS()
s=s.gt(s)}else{s=s.a8()
s=new J.aP(s,s.length,A.h(s).h("aP<1>"))}return s}}
A.ci.prototype={}
A.cm.prototype={}
A.bC.prototype={
j(a){var s=A.ct(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+s}}
A.cE.prototype={
j(a){return"Cyclic error in JSON stringify"}}
A.ex.prototype={
au(a,b){var s=A.jR(a,this.gcd().a)
return s},
av(a,b){var s=A.j1(a,this.gce().b,null)
return s},
gce(){return B.aB},
gcd(){return B.aA}}
A.ez.prototype={}
A.ey.prototype={}
A.fh.prototype={
b6(a){var s,r,q,p,o,n,m=a.length
for(s=this.c,r=0,q=0;q<m;++q){p=a.charCodeAt(q)
if(p>92){if(p>=55296){o=p&64512
if(o===55296){n=q+1
n=!(n<m&&(a.charCodeAt(n)&64512)===56320)}else n=!1
if(!n)if(o===56320){o=q-1
o=!(o>=0&&(a.charCodeAt(o)&64512)===55296)}else o=!1
else o=!0
if(o){if(q>r)s.a+=B.e.a1(a,r,q)
r=q+1
o=A.L(92)
s.a+=o
o=A.L(117)
s.a+=o
o=A.L(100)
s.a+=o
o=p>>>8&15
o=A.L(o<10?48+o:87+o)
s.a+=o
o=p>>>4&15
o=A.L(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.L(o<10?48+o:87+o)
s.a+=o}}continue}if(p<32){if(q>r)s.a+=B.e.a1(a,r,q)
r=q+1
o=A.L(92)
s.a+=o
switch(p){case 8:o=A.L(98)
s.a+=o
break
case 9:o=A.L(116)
s.a+=o
break
case 10:o=A.L(110)
s.a+=o
break
case 12:o=A.L(102)
s.a+=o
break
case 13:o=A.L(114)
s.a+=o
break
default:o=A.L(117)
s.a+=o
o=A.L(48)
s.a=(s.a+=o)+o
o=p>>>4&15
o=A.L(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.L(o<10?48+o:87+o)
s.a+=o
break}}else if(p===34||p===92){if(q>r)s.a+=B.e.a1(a,r,q)
r=q+1
o=A.L(92)
s.a+=o
o=A.L(p)
s.a+=o}}if(r===0)s.a+=a
else if(r<m)s.a+=B.e.a1(a,r,m)},
ag(a){var s,r,q,p
for(s=this.a,r=s.length,q=0;q<r;++q){p=s[q]
if(a==null?p==null:a===p)throw A.d(new A.cE(a,null))}B.a.l(s,a)},
af(a){var s,r,q,p,o=this
if(o.b5(a))return
o.ag(a)
try{s=o.b.$1(a)
if(!o.b5(s)){q=A.ho(a,null,o.gaS())
throw A.d(q)}q=o.a
if(0>=q.length)return A.a(q,-1)
q.pop()}catch(p){r=A.h5(p)
q=A.ho(a,r,o.gaS())
throw A.d(q)}},
b5(a){var s,r,q=this
if(typeof a=="number"){if(!isFinite(a))return!1
q.c.a+=B.b.j(a)
return!0}else if(a===!0){q.c.a+="true"
return!0}else if(a===!1){q.c.a+="false"
return!0}else if(a==null){q.c.a+="null"
return!0}else if(typeof a=="string"){s=q.c
s.a+='"'
q.b6(a)
s.a+='"'
return!0}else if(t.j.b(a)){q.ag(a)
q.cu(a)
s=q.a
if(0>=s.length)return A.a(s,-1)
s.pop()
return!0}else if(t.eO.b(a)){q.ag(a)
r=q.cv(a)
s=q.a
if(0>=s.length)return A.a(s,-1)
s.pop()
return r}else return!1},
cu(a){var s,r,q=this.c
q.a+="["
s=J.bm(a)
if(s.gZ(a)){this.af(s.i(a,0))
for(r=1;r<s.gm(a);++r){q.a+=","
this.af(s.i(a,r))}}q.a+="]"},
cv(a){var s,r,q,p,o,n,m=this,l={}
if(a.gv(a)){m.c.a+="{}"
return!0}s=a.gm(a)*2
r=A.bI(s,null,!1,t.Y)
q=l.a=0
l.b=!0
a.J(0,new A.fi(l,r))
if(!l.b)return!1
p=m.c
p.a+="{"
for(o='"';q<s;q+=2,o=',"'){p.a+=o
m.b6(A.v(r[q]))
p.a+='":'
n=q+1
if(!(n<s))return A.a(r,n)
m.af(r[n])}p.a+="}"
return!0}}
A.fi.prototype={
$2(a,b){var s,r
if(typeof a!="string")this.a.b=!1
s=this.b
r=this.a
B.a.q(s,r.a++,a)
B.a.q(s,r.a++,b)},
$S:9}
A.fg.prototype={
gaS(){var s=this.c.a
return s.charCodeAt(0)==0?s:s}}
A.dM.prototype={
$0(){var s=this
return A.b2(A.dd("("+s.a+", "+s.b+", "+s.c+", "+s.d+", "+s.e+", "+s.f+", "+s.r+", "+s.w+")"))},
$S:51}
A.ag.prototype={
P(a){var s=1000,r=B.c.V(a,s),q=B.c.A(a-r,s),p=this.b+r,o=B.c.V(p,s),n=this.c
return new A.ag(A.hi(this.a+B.c.A(p-o,s)+q,o,n),o,n)},
Y(a){return A.I(this.b-a.b,this.a-a.a)},
M(a,b){if(b==null)return!1
return b instanceof A.ag&&this.a===b.a&&this.b===b.b&&this.c===b.c},
gD(a){return A.fR(this.a,this.b,B.d,B.d)},
cn(a){var s=this.a,r=a.a
if(s>=r)s=s===r&&this.b<a.b
else s=!0
return s},
cm(a){var s=this.a,r=a.a
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
return new A.ag(s.a,s.b,!0)},
j(a){var s=this,r=A.hh(A.cG(s)),q=A.aq(A.hA(s)),p=A.aq(A.hw(s)),o=A.aq(A.hx(s)),n=A.aq(A.hz(s)),m=A.aq(A.hB(s)),l=A.dN(A.hy(s)),k=s.b,j=k===0?"":A.dN(k)
k=r+"-"+q
if(s.c)return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j},
aC(){var s=this,r=A.cG(s)>=-9999&&A.cG(s)<=9999?A.hh(A.cG(s)):A.iJ(A.cG(s)),q=A.aq(A.hA(s)),p=A.aq(A.hw(s)),o=A.aq(A.hx(s)),n=A.aq(A.hz(s)),m=A.aq(A.hB(s)),l=A.dN(A.hy(s)),k=s.b,j=k===0?"":A.dN(k)
k=r+"-"+q
if(s.c)return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j},
$ia2:1}
A.dP.prototype={
$1(a){if(a==null)return 0
return A.cW(a)},
$S:10}
A.dQ.prototype={
$1(a){var s,r,q
if(a==null)return 0
for(s=a.length,r=0,q=0;q<6;++q){r*=10
if(q<s){if(!(q<s))return A.a(a,q)
r+=a.charCodeAt(q)^48}}return r},
$S:10}
A.R.prototype={
M(a,b){if(b==null)return!1
return b instanceof A.R&&this.a===b.a},
gD(a){return B.c.gD(this.a)},
C(a,b){return B.c.C(this.a,t.fu.a(b).a)},
j(a){var s,r,q,p,o,n=this.a,m=B.c.A(n,36e8),l=n%36e8
if(n<0){m=0-m
n=0-l
s="-"}else{n=l
s=""}r=B.c.A(n,6e7)
n%=6e7
q=r<10?"0":""
p=B.c.A(n,1e6)
o=p<10?"0":""
return s+m+":"+q+r+":"+o+p+"."+B.e.cp(B.c.j(n%1e6),6,"0")},
$ia2:1}
A.fd.prototype={
j(a){return this.F()}}
A.A.prototype={}
A.ce.prototype={
j(a){var s=this.a
if(s!=null)return"Assertion failed: "+A.ct(s)
return"Assertion failed"}}
A.bV.prototype={}
A.am.prototype={
gak(){return"Invalid argument"+(!this.a?"(s)":"")},
gaj(){return""},
j(a){var s=this,r=s.c,q=r==null?"":" ("+r+")",p=s.d,o=p==null?"":": "+p,n=s.gak()+q+o
if(!s.a)return n
return n+s.gaj()+": "+A.ct(s.gaA())},
gaA(){return this.b}}
A.bN.prototype={
gaA(){return A.hX(this.b)},
gak(){return"RangeError"},
gaj(){var s,r=this.e,q=this.f
if(r==null)s=q!=null?": Not less than or equal to "+A.B(q):""
else if(q==null)s=": Not greater than or equal to "+A.B(r)
else if(q>r)s=": Not in inclusive range "+A.B(r)+".."+A.B(q)
else s=q<r?": Valid value range is empty":": Only valid value is "+A.B(r)
return s}}
A.cv.prototype={
gaA(){return A.a0(this.b)},
gak(){return"RangeError"},
gaj(){if(A.a0(this.b)<0)return": index must not be negative"
var s=this.f
if(s===0)return": no indices are valid"
return": index should be less than "+s},
gm(a){return this.f}}
A.bY.prototype={
j(a){return"Unsupported operation: "+this.a}}
A.bd.prototype={
j(a){return"Bad state: "+this.a}}
A.cl.prototype={
j(a){var s=this.a
if(s==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.ct(s)+"."}}
A.cF.prototype={
j(a){return"Out of Memory"},
$iA:1}
A.bQ.prototype={
j(a){return"Stack Overflow"},
$iA:1}
A.fe.prototype={
j(a){return"Exception: "+this.a}}
A.er.prototype={
j(a){var s=this.a,r=""!==s?"FormatException: "+s:"FormatException",q=this.b
if(typeof q=="string"){if(q.length>78)q=B.e.a1(q,0,75)+"..."
return r+"\n"+q}else return r}}
A.c.prototype={
b3(a,b,c){var s=A.k(this)
return A.iS(this,s.u(c).h("1(c.E)").a(b),s.h("c.E"),c)},
G(a,b,c,d){var s,r
d.a(b)
A.k(this).u(d).h("1(1,c.E)").a(c)
for(s=this.gt(this),r=b;s.n();)r=c.$2(r,s.gp())
return r},
b4(a,b){var s=A.k(this).h("c.E")
if(b)s=A.q(this,s)
else{s=A.q(this,s)
s.$flags=1
s=s}return s},
gm(a){var s,r=this.gt(this)
for(s=0;r.n();)++s
return s},
gv(a){return!this.gt(this).n()},
gZ(a){return!this.gv(this)},
N(a,b){return A.hG(this,b,A.k(this).h("c.E"))},
az(a,b,c){var s,r=A.k(this)
r.h("i(c.E)").a(b)
r.h("c.E()?").a(c)
for(r=this.gt(this);r.n();){s=r.gp()
if(b.$1(s))return s}r=c.$0()
return r},
E(a,b){var s,r
A.aw(b,"index")
s=this.gt(this)
for(r=b;s.n();){if(r===0)return s.gp();--r}throw A.d(A.es(b,b-r,this,null,"index"))},
j(a){return A.iL(this,"(",")")}}
A.J.prototype={
j(a){return"MapEntry("+A.B(this.a)+": "+A.B(this.b)+")"}}
A.aU.prototype={
gD(a){return A.n.prototype.gD.call(this,0)},
j(a){return"null"}}
A.n.prototype={$in:1,
M(a,b){return this===b},
gD(a){return A.cH(this)},
j(a){return"Instance of '"+A.cI(this)+"'"},
gU(a){return A.kb(this)},
toString(){return this.j(this)}}
A.be.prototype={
gm(a){return this.a.length},
j(a){var s=this.a
return s.charCodeAt(0)==0?s:s},
$ij_:1}
A.d_.prototype={
H(a){var s,r,q,p,o,n,m=A.j([],t.h)
for(s=a.R(B.l),r=J.W(s.a),s=new A.ad(r,s.b,s.$ti.h("ad<1>")),q=0;s.n();){p=r.gp()
o=p.at
n=Math.max(o.c,o.d)
o=!0
if(p.ax===B.v)if(!(p.x-p.w<4))o=n>=0.65&&p.y<12
if(o)++q
else B.a.l(m,p)}if(m.length===0)return new A.cd(0,!1,!1)
s=new A.d7(m)
return new A.cd(s.$1(new A.d9(this))*25+s.$1(new A.da(this,a))*15+s.$1(new A.db(this,a))*10,!0,m.length>=2)},
b9(a,b){var s=B.a.a6(a.b,b.d,b.e+1),r=A.h(s),q=r.h("f<1,b>"),p=A.q(new A.f(s,r.h("b(1)").a(new A.d0()),q),q.h("m.E"))
return B.a.G(p,0,new A.d1(B.a.L(p,new A.d2())/p.length),t.i)/p.length},
bQ(a,b){var s=a.b,r=A.h(s),q=r.h("a3<1,b>"),p=A.q(new A.a3(new A.x(s,r.h("i(1)").a(new A.d3(b,b.r.P(4e6))),r.h("x<1>")),r.h("b(1)").a(new A.d4()),q),q.h("c.E"))
if(p.length<2)return 0
return 1-B.b.k(Math.sqrt(B.a.G(p,0,new A.d5(B.a.L(p,new A.d6())/p.length),t.i)/p.length)/3,0,1)}}
A.d7.prototype={
$1(a){var s=this.a,r=A.h(s)
return new A.f(s,r.h("b(1)").a(t.bE.a(a)),r.h("f<1,b>")).L(0,new A.d8())/s.length},
$S:60}
A.d8.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.d9.prototype={
$1(a){t.F.a(a)
return B.b.k((a.x-a.w)/B.c.A(a.r.Y(a.f).a,1000)*1000/2.5,0,1)},
$S:7}
A.da.prototype={
$1(a){return 1-B.b.k(this.a.b9(this.b,t.F.a(a))/0.55,0,1)},
$S:7}
A.db.prototype={
$1(a){return this.a.bQ(this.b,t.F.a(a))},
$S:7}
A.d0.prototype={
$1(a){return t.C.a(a).e},
$S:3}
A.d2.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.d1.prototype={
$2(a,b){var s
A.t(a)
s=A.t(b)-this.a
return a+s*s},
$S:0}
A.d3.prototype={
$1(a){t.C.a(a)
return a.a>this.a.e&&!a.b.c.cm(this.b)},
$S:1}
A.d4.prototype={
$1(a){return t.C.a(a).b.d},
$S:3}
A.d6.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.d5.prototype={
$2(a,b){var s
A.t(a)
s=A.t(b)-this.a
return a+s*s},
$S:0}
A.dc.prototype={
$1(a){var s=this.a,r=s.r
return r+(s.w-r)*((a-s.e)/this.b)},
$S:12}
A.z.prototype={
b_(a,b,c,d){var s=this,r=c==null?s.e:c
return new A.z(b,s.b,s.c,s.d,r,a,s.r,s.w,s.x,s.y,s.z,s.Q,d,s.at)},
cc(a,b,c){return this.b_(a,b,null,c)}}
A.dg.prototype={
H(b4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0=this,b1=b4.R(B.p),b2=b1.$ti,b3=b2.h("x<c.E>")
b1=A.q(new A.x(b1,b2.h("i(c.E)").a(new A.dv()),b3),b3.h("c.E"))
b1.$flags=1
s=b1
b1=b4.R(B.G)
b1=A.q(b1,b1.$ti.h("c.E"))
b1.$flags=1
r=b1
b1=b4.R(B.j)
b1=A.q(b1,b1.$ti.h("c.E"))
b1.$flags=1
q=b1
p=A.j([],t.aS)
b1=t.n
o=A.j([],b1)
n=A.ht(t.N)
for(b2=s.length,m=0,l=0,k=0,j=0;j<s.length;s.length===b2||(0,A.E)(s),++j){i=s[j]
if(!(i.as<=0)){b3=i.r
h=i.f
h=A.I(b3.b-h.b,b3.a-h.a).a<=0
b3=h}else b3=!0
if(b3){++m
continue}g=b0.bu(i,q)
b3=i.at
f=B.b.k(1-Math.max(b3.c*0.25,b3.d*0.45),0,1)
if(f<1||g)++k
e=b0.aT(b4,i)
d=b0.bR(e)
if(e>=5){++l
n.l(0,i.a)}b3=g?0.6:1
B.a.l(o,d*f*b3)
B.a.l(p,new A.aM(b0.bd(b4,i,g),Math.max(1,i.w-i.x)))}c=p.length===0
b=c?150:150*b0.c6(p)
a=o.length===0
a0=a?100:100*(1-b0.bc(o))
a1=b0.bt(b4,s)
a2=a1.length===0
a3=b0.bD(a1)
a4=a2?60:60*(1-a3)
b2=A.h(a1)
new A.x(a1,b2.h("i(1)").a(new A.dw()),b2.h("x<1>")).gm(0)
a5=A.j([],b1)
for(b1=r.length,j=0;j<r.length;r.length===b1||(0,A.E)(r),++j){a6=b0.bX(b4,r[j],s,n)
if(a6==null)++m
else B.a.l(a5,a6)}a7=a5.length===0
a8=a7?40:40*b0.W(a5)
a9=B.b.k(b+a0+a4+a8,0,350)
B.b.k(b,0,150)
B.b.k(a0,0,100)
B.b.k(a4,0,60)
B.b.k(a8,0,40)
return new A.dx(a9,s.length,a5.length,new A.df(c,a,a2,a7))},
bd(a,a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=a.b,d=a0.d,c=a0.e,b=e.length
if(!(d<b))return A.a(e,d)
s=e[d].b.d
if(!(c<b))return A.a(e,c)
r=e[c].b.d
q=Math.max(0,s-r)
if(q<=0)return 0.5
p=this.aP(e,d,c,0.5)
o=this.aP(e,d,c,0.6)
if(!(p<b))return A.a(e,p)
n=Math.max(0,s-e[p].b.d)
if(!(o<b))return A.a(e,o)
m=Math.max(0,e[o].b.d-r)
l=B.b.k(n/q/0.55,0,1)
k=B.b.k((m/q-0.35)/0.37,0,1)
j=A.j([],t.n)
for(i=d;i<=c;++i){if(!(i<b))return A.a(e,i)
B.a.l(j,e[i].e)}b=B.b.k(this.aW(j)/0.9,0,1)
h=e[d].b.c.P(-5e6)
g=A.bS(e,0,A.i6(d,"count",t.S),A.h(e).c).a4(0,new A.dh(h))?0.08:0
f=a1?0.1:0
return B.b.k(0.4*B.b.k(l+g+f,0,1)+0.3*(1-b)+0.3*(1-k),0,1)},
aT(a,b){var s,r,q,p,o,n
for(s=b.d,r=b.e,q=a.b,p=q.length,o=0;s<=r;++s){if(!(s<p))return A.a(q,s)
n=q[s]
o=Math.max(o,Math.max(-n.b.x,-n.e))}return o},
bR(a){var s=this
if(a<=1.5)return 0
if(a<=2.5)return s.a7(0,0.15,(a-1.5)/1)
if(a<=3.5)return s.a7(0.15,0.35,(a-2.5)/1)
if(a<=5)return s.a7(0.35,0.75,(a-3.5)/1.5)
return s.a7(0.75,1,(a-5)/5)},
bc(a){var s
t.q.a(a)
s=this.W(a)
if(a.length===1)return Math.min(s,0.35)
return B.b.k(s*1.35,0,1)},
bt(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c
t.B.a(b)
s=a.R(B.l)
r=s.$ti
q=r.h("x<c.E>")
s=A.q(new A.x(s,r.h("i(c.E)").a(new A.di()),q),q.h("c.E"))
s.$flags=1
p=s
o=A.j([],t.h9)
for(s=p.length,n=0;n<p.length;p.length===s||(0,A.E)(p),++n){m=p[n]
l=m.x-m.w
if(l<3)continue
for(r=b.length,q=m.r,k=q.a,q=q.b,j=m.y,i=0;i<r;++i){h=b[i]
g=h.f
f=g.a
if(f>=k)e=f===k&&g.b<q
else e=!0
if(e)continue
d=A.I(g.b-q,f-k)
if(j<13.88888888888889)c=14
else c=j<25?10.5:7.5
if(d.a>A.I(0,B.b.ae(c*1000)).a)break
if(h.w-h.x<=0)continue
B.a.l(o,new A.ak(l,this.aT(a,h),this.bE(h.at)))
break}}return o},
bD(a){var s,r,q,p,o
t.cT.a(a)
if(a.length===0)return 0
s=A.h(a)
r=s.h("b(1)")
s=s.h("f<1,b>")
q=this.W(new A.f(a,r.a(new A.dl(this)),s))
p=a.length
o=p===1?0.15:B.b.k(p/3,0.45,1)
return B.b.k(q*o*(1-this.W(new A.f(a,r.a(new A.dm()),s))),0,1)},
bX(a,b,a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=null
t.B.a(a0)
t.cq.a(a1)
s=this.bs(a,b.d)
if(s==null)return c
r=a.b
q=b.e
p=B.a.a6(r,s,q+1)
o=A.h(p)
if(new A.f(p,o.h("b(1)").a(new A.dp()),o.h("f<1,b>")).L(0,B.V)<4.166666666666667)return c
p=A.h(a0)
o=p.h("x<1>")
n=A.hd(new A.x(a0,p.h("i(1)").a(new A.dq(b)),o),o.h("c.E"),t.dd).az(0,new A.dr(),new A.ds())
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
e=A.j([],t.n)
for(i=j;i<=q;++i){if(!(i<p))return A.a(r,i)
B.a.l(e,r[i].e)}d=1-B.b.k(this.aW(e)/0.8,0,1)
return B.b.k(0.5*f+0.25*d+0.25*B.b.k((f+d)/2,0,1),0,1)},
bs(a,b){var s,r,q
for(s=a.b,r=s.length,q=b;q>=0;--q){if(!(q<r))return A.a(s,q)
if(s[q].b.d>=4.166666666666667)return q}return null},
bu(a,b){t.B.a(b)
return a.ch.ac(0,B.u)||B.a.a4(a.CW,new A.dk(b))},
bE(a){var s=a.d,r=Math.max(a.c,s)
if(r<=0)return 0
return B.b.k(0.8*r+0.19999999999999996*s,0,1)},
aP(a,b,c,d){var s,r,q,p,o,n,m
t.X.a(a)
s=a.length
if(!(b<s))return A.a(a,b)
r=a[b].b.c
if(!(c<s))return A.a(a,c)
q=r.P(A.I(0,B.b.ae(B.c.A(a[c].b.c.Y(r).a,1000)*d)).a)
for(r=q.a,p=q.b,o=b;o<=c;++o){if(!(o<s))return A.a(a,o)
n=a[o].b.c
m=n.a
if(m>=r)n=m===r&&n.b<p
else n=!0
if(!n)return o}return c},
c6(a){var s,r
t.ap.a(a)
s=t.i
r=B.a.G(a,0,new A.dt(),s)
if(r<=0)return 1
return B.a.G(a,0,new A.du(),s)/r},
W(a){var s,r,q
for(s=J.W(t.bM.a(a)),r=0,q=0;s.n();){r+=s.gp();++q}return q===0?0:r/q},
aW(a){var s
t.q.a(a)
if(a.length<2)return 0
s=A.h(a)
return Math.sqrt(this.W(new A.f(a,s.h("b(1)").a(new A.dn(this.W(a))),s.h("f<1,b>"))))},
a7(a,b,c){return a+(b-a)*B.b.k(c,0,1)}}
A.dv.prototype={
$1(a){return t.F.a(a).ax===B.K},
$S:4}
A.dw.prototype={
$1(a){return t.k.a(a).c>0},
$S:43}
A.dh.prototype={
$1(a){t.C.a(a)
return!a.b.c.cn(this.a)&&a.e<-0.08},
$S:1}
A.di.prototype={
$1(a){return t.F.a(a).ax===B.v},
$S:4}
A.dl.prototype={
$1(a){t.k.a(a)
return 0.6*B.b.k(a.a/9,0,1)+0.4*B.b.k(a.b/3.5,0,1)},
$S:14}
A.dm.prototype={
$1(a){return t.k.a(a).c},
$S:14}
A.dp.prototype={
$1(a){return t.C.a(a).b.d},
$S:3}
A.dq.prototype={
$1(a){var s,r
t.F.a(a)
s=this.a
r=s.f.Y(a.r)
return a.e<=s.d&&Math.abs(r.a)<=3e6},
$S:4}
A.dr.prototype={
$1(a){return t.dd.a(a)!=null},
$S:40}
A.ds.prototype={
$0(){return null},
$S:32}
A.dk.prototype={
$1(a){return B.a.a4(this.a,new A.dj(A.v(a)))},
$S:21}
A.dj.prototype={
$1(a){return t.F.a(a).a===this.a},
$S:4}
A.dt.prototype={
$2(a,b){return A.t(a)+t.fz.a(b).b},
$S:17}
A.du.prototype={
$2(a,b){A.t(a)
t.fz.a(b)
return a+b.a*b.b},
$S:17}
A.dn.prototype={
$1(a){return Math.pow(A.t(a)-this.a,2)},
$S:12}
A.aM.prototype={}
A.ak.prototype={}
A.dx.prototype={}
A.df.prototype={}
A.K.prototype={
gcj(){var s,r=this.a
if(isFinite(r)){s=this.b
r=isFinite(s)&&Math.abs(r)<=90&&Math.abs(s)<=180}else r=!1
return r}}
A.dy.prototype={
aZ(a,b,c,d,a0,a1,a2,a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=t.t
e.a(a0)
e.a(a7)
if(a3&&!a1.at)return f.ab(a,a1,B.aa,"Common road is below the 3000 metre comparison threshold.")
s=B.k.b0(b,c,d,a0,a1,a2,a4,a5,a6,a7)
if(!s.gaB()){e=s.a.a===B.h||s.b.a===B.h?B.ab:B.D
i=s.a.f
if(i==null)i=s.b.f
return f.ab(a,a1,e,i==null?"Common-road telemetry could not be extracted.":i)}try{r=B.y.aY(a,s.a.b)
q=B.y.aY(a,s.b.b)
p=q.a-r.a
o=r.a<q.a?r.a:q.a
e=o
if(typeof e!=="number")return e.cC()
if(e<=0)h=0
else{e=p
i=o
if(typeof e!=="number")return e.cz()
if(typeof i!=="number")return A.kd(i)
h=e/i}n=h
m=r.a>=q.a*1.01
l=q.a>=r.a*1.01
if(m)e=B.A
else e=l?B.B:B.C
return new A.ck(r,q,p,n,e,!0)}catch(g){e=A.h5(g)
if(e instanceof A.cx){k=e
return f.ab(a,a1,B.D,u.c)}else{j=e
e=f.ab(a,a1,B.ac,J.b4(j))
return e}}},
cb(a,b,c,d,e,f){var s=null
return this.aZ(a,s,b,s,c,d,0,!0,s,e,s,f)},
ab(a,b,c,d){var s=null
return new A.ck(s,s,s,s,c,!1)}}
A.cj.prototype={}
A.an.prototype={
F(){return"CommonRoadScoreComparisonOutcome."+this.b}}
A.ck.prototype={}
A.bq.prototype={
F(){return"CommonRoadTelemetryMappingStatus."+this.b}}
A.ao.prototype={}
A.dC.prototype={
gaB(){return this.a.a===B.n&&this.b.a===B.n}}
A.dz.prototype={
b0(a,b,c,d,e,f,g,h,i,j){var s,r,q=t.t
q.a(d)
q.a(j)
q=c==null?e.e:c
s=a==null?e.f:a
q=this.aJ(s,f,b,e.c,q,d)
s=i==null?e.r:i
r=g==null?e.w:g
return new A.dC(q,this.aJ(r,f,h,e.d,s,j))},
aw(a,b,c,d,e){var s=null
return this.b0(s,a,s,b,c,0,s,d,s,e)},
aJ(b1,b2,b3,b4,b5,b6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0=null
t.t.a(b6)
s=J.eu(b6.slice(0),A.h(b6).c)
if(s.length===0)return new A.ao(B.E,B.i,b0,b0,0,"No canonical telemetry exists.")
r=this.bO(b3,b4)
if(r==null||r.b.length<2)return new A.ao(B.h,B.i,b0,b0,0,"Matched road section is unavailable.")
q=this.bP(b3,b4)
if(q==null)return new A.ao(B.h,B.i,b0,b0,0,"Matched road section offset is unavailable.")
p=r.b
o=A.fT(p)
n=A.hJ(r)
if(!isFinite(o)||o<=0||!isFinite(n)||n<=0)return new A.ao(B.h,B.i,b0,b0,0,"Matched section has no valid canonical offset axis.")
m=A.j([],t.cA)
for(l=b5-b2,k=b1+b2,j=0,i=0;i<p.length-1;){h=p[i];++i
g=p[i]
f=h.a
e=h.b
d=g.a
c=g.b
b=A.hl(f,e,d,c)
if(b<=0)continue
a=A.fU(o,j,n)
a0=j+b
if(q+A.fU(o,a0,n)>=l&&q+a<=k){a=f*3.141592653589793/180
a1=111320*Math.cos(a)
e=c-e
a2=e*3.141592653589793/180
a3=d*3.141592653589793/180
a=new A.c2(h,b,j,a1,B.b.V(Math.atan2(Math.sin(a2)*Math.cos(a3),Math.cos(a)*Math.sin(a3)-Math.sin(a)*Math.cos(a3)*Math.cos(a2))*180/3.141592653589793+360,360))
a.f=e*a1
a.r=(d-f)*111320
B.a.l(m,a)}j=a0}a4=A.j([],t.du)
for(a5=0;a5<s.length;++a5){a6=s[a5]
p=a6.a
if(isFinite(p)){f=a6.b
p=isFinite(f)&&Math.abs(p)<=90&&Math.abs(f)<=180}else p=!1
if(!p)continue
a7=this.bJ(a6,m,q,o,n,b5,b1,b2)
p=!0
if(a7!=null)if(!(a7.a>35)){f=a7.c
if(!(f!=null&&f>60)){p=a7.b
p=p<l||p>k}}if(p)continue
B.a.l(a4,new A.ae(a5,a6,a7))}if(a4.length<2)return new A.ao(B.E,B.i,b0,b0,0,"Fewer than two canonical samples map to the common road.")
p=t.gM
p=A.q(new A.f(a4,t.fI.a(new A.dA()),p),p.h("m.E"))
p.$flags=1
a8=p
for(p=a8.length,a5=1;a5<p;++a5){l=a8[a5].c
k=a8[a5-1].c
f=l.a
e=k.a
if(f<=e)l=f===e&&l.b>k.b
else l=!0
if(!l)return new A.ao(B.h,B.i,b0,b0,0,"Mapped telemetry does not preserve strict time order.")}a9=B.b.k(1-B.a.G(a4,0,new A.dB(),t.i)/a4.length/35,0,1)
return new A.ao(B.n,A.T(a8,t.u),B.a.gI(a4).a,B.a.gT(a4).a,a9,b0)},
bO(a,b){var s,r,q=a.d,p=q.length
if(p!==0){for(s=0;s<p;++s){r=q[s]
if(r.a===b)return r}return null}return b===a.a+":geometry"?new A.U(b,a.c,a.e):null},
bP(a,b){var s,r,q,p,o,n=a.d,m=n.length
if(m===0)return b===a.a+":geometry"?0:null
for(s=0,r=0;r<n.length;n.length===m||(0,A.E)(n),++r){q=n[r]
if(q.a===b)return s
p=q.c
o=A.fT(q.b)
s+=isFinite(p)&&p>0?p:o}return null},
bJ(a1,a2,a3,a4,a5,a6,a7,a8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0
t.fT.a(a2)
for(s=a2.length,r=a6-a8,q=a1.e,p=a1.b,o=a1.a,n=a7+a8,m=null,l=!1,k=0;k<a2.length;a2.length===s||(0,A.E)(a2),++k){j=a2[k]
i=j.a
h=(p-i.b)*j.d
g=(o-i.a)*111320
i=j.f
i===$&&A.id()
f=j.r
f===$&&A.id()
e=i*i+f*f
d=e<=0?0:B.b.k((h*i+g*f)/e,0,1)
i=h-i*d
f=g-f*d
f=Math.sqrt(i*i+f*f)
i=a3+A.fU(a4,j.c+j.b*d,a5)
c=A.jA(q,j.e)
b=new A.ff(f,i,c)
a=i>=r&&i<=n
i=!0
if(m!=null)if(!(a&&!l))if(a===l){a0=m.a
if(!(f<a0))if(Math.abs(f-a0)<=0.000001){i=c==null?1/0:c
f=m.c
i=i<(f==null?1/0:f)}else i=!1}else i=!1
if(i){l=a
m=b}}return m}}
A.dA.prototype={
$1(a){return t.ei.a(a).b},
$S:19}
A.dB.prototype={
$2(a,b){return A.t(a)+t.ei.a(b).c.a},
$S:18}
A.c2.prototype={
gm(a){return this.b}}
A.ae.prototype={}
A.ff.prototype={}
A.co.prototype={
H(a){var s,r,q,p,o,n,m=A.j([],t.df)
for(s=a.R(B.j),r=J.W(s.a),s=new A.ad(r,s.b,s.$ti.h("ad<1>")),q=0,p=0;s.n();){o=r.gp()
n=this.bm(a,o)
if(n==null){++q
if(o.as<0.5)++p}else B.a.l(m,n)}if(m.length===0)return new A.cn(0,!1,!1)
s=new A.dJ(this,m)
s=B.b.k(s.$1(new A.dF())*60+s.$1(new A.dG())*35+s.$1(new A.dH())*35+s.$1(new A.dI())*20,0,150)
r=m.length
A.T(m,t.v)
return new A.cn(s,!0,r>=2)},
bm(a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=null
if(a1.ax!==B.L||a1.as<0.5||a1.Q<15)return a
s=a1.cx
r=s.i(0,"totalHeadingChangeDegrees")
if(r==null)r=0
if(r<15)return a
q=a0.b
s=s.i(0,"apexIndex")
p=a1.d
o=a1.e
n=B.c.cs(B.c.k(B.b.ae(s==null?(a1.d+a1.e)/2:s),p,o))
m=Math.max(p,p+B.c.A(n-p,2))
l=Math.min(o,n+B.c.A(o-n,2))
k=b.al(q,p,m)
j=b.al(q,Math.max(p,n-1),Math.min(o,n+1))
i=b.al(q,l,b.bL(q,o))
if(k<10)return a
s=a1.at
h=Math.max(s.c,s.d)
if(h>=0.6&&k<12)return a
g=r*3.141592653589793/180
f=g<=0?500:a1.Q/g
e=B.b.k(0.55*((r-15)/75)+0.45*((500-f)/475),0,1)
d=1-B.b.k((B.b.k((k-j)/k,0,1)-b.aQ(0.08,0.48,e))/0.32,0,1)
if(h>0)d=b.aQ(d,1,h*0.35)
s=B.b.k(b.aR(b.ap(q,p,n),k)/0.18,0,1)
c=B.b.k(B.b.k(i/k,0,1.1)/0.95,0,1)
o=B.b.k(b.aR(b.ap(q,p,o),k)/0.06,0,1)
A.T(a1.CW,t.N)
return new A.af(r,e,a1.as,d,1-s,c,1-o)},
bL(a,b){var s,r,q,p,o,n,m,l,k
t.X.a(a)
s=a.length
if(!(b<s))return A.a(a,b)
r=a[b].b.c.P(3e6)
for(q=b+1,p=r.a,o=r.b,n=b;q<s;m=q+1,n=q,q=m){l=a[q].b.c
k=l.a
if(k<=p)l=k===p&&l.b>o
else l=!0
if(l)break}return n},
ap(a,b,c){var s,r,q
t.X.a(a)
s=A.j([],t.n)
for(r=a.length,q=b;q<=c;++q){if(!(q>=0&&q<r))return A.a(a,q)
s.push(a[q].b.d)}return s},
al(a,b,c){var s,r,q,p=this.ap(t.X.a(a),b,c)
B.a.aF(p)
s=p.length
r=s/2|0
if((s&1)===1){if(!(r<s))return A.a(p,r)
s=p[r]}else{q=r-1
if(!(q>=0&&q<s))return A.a(p,q)
q=p[q]
if(!(r<s))return A.a(p,r)
q=(q+p[r])/2
s=q}return s},
aR(a,b){var s,r,q,p,o,n
t.q.a(a)
if(a.length<2||b<=0)return 0
s=B.a.L(a,new A.dE())
r=a.length
q=s/r
for(p=0,o=0;o<r;++o){n=a[o]-q
p+=n*n}return Math.sqrt(p/r)/b},
c5(a){t.v.a(a)
return Math.min(1.5,Math.max(0.25,a.w*(0.5+a.r)*(a.e/30)))},
aQ(a,b,c){return a+(b-a)*B.b.k(c,0,1)}}
A.dJ.prototype={
$1(a){var s,r,q,p,o,n,m,l,k
t.bk.a(a)
s=this.b
r=A.h(s)
q=r.h("f<1,b>")
r=A.q(new A.f(s,r.h("b(1)").a(this.a.gc4()),q),q.h("m.E"))
r.$flags=1
p=r
r=t.i
o=B.a.G(p,0,new A.dK(),r)
n=s.length
m=J.hm(n,r)
for(l=0;l<n;++l){if(!(l<s.length))return A.a(s,l)
q=a.$1(s[l])
if(!(l<p.length))return A.a(p,l)
k=p[l]
if(typeof q!=="number")return q.aD()
m[l]=q*k}return B.a.G(m,0,new A.dL(),r)/o},
$S:20}
A.dK.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.dL.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.dF.prototype={
$1(a){return a.x},
$S:6}
A.dG.prototype={
$1(a){return a.y},
$S:6}
A.dH.prototype={
$1(a){return a.z},
$S:6}
A.dI.prototype={
$1(a){return a.Q},
$S:6}
A.dE.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.cn.prototype={}
A.af.prototype={}
A.dR.prototype={
cf(b7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6=null
t.an.a(b7)
if(b7.length===0)return B.N
s=t.I
r=A.bI(A.iR(b6),b6,!1,s)
q=A.j([],t.J)
for(p=0,o=0,n=0,m=0,l=0,k=0,j=0,i=0,h=0,g=0;j<b7.length;++j,f=h,h=i,i=f){e=b7[j]
B.a.q(r,h,j)
d=r.length
h=(h+1&d-1)>>>0
if(i===h){c=A.bI(d*2,b6,!1,s)
b=d-i
B.a.aE(c,0,b,r,i)
B.a.aE(c,b,b+i,r,0)
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
a0=a.P(-5e6)
a1=a0.a
a2=a0.b
a3=r.length
a4=a3-1
for(;;){a5=(i-h&a4)>>>0
if(a5>1){if(h===i)A.b2(A.aS())
if(!(h>=0&&h<a3))return A.a(r,h)
a6=r[h]
a6=B.a.i(b7,a6==null?A.a0(a6):a6).c
a7=a6.a
if(a7>=a1)a6=a7===a1&&a6.b<a2
else a6=!0}else a6=!1
if(!a6)break
if(h===i)A.b2(A.aS());++g
if(!(h>=0&&h<a3))return A.a(r,h)
a8=r[h]
if(a8==null)a8=A.a0(a8)
B.a.q(r,h,b6)
h=(h+1&a4)>>>0
a5=B.a.i(b7,a8).d
p-=a5
o-=a5*a5
if(a5<=8.333333333333334)--n}a9=p/a5
b0=B.b.k(o/a5-a9*a9,0,1/0)
b1=e.x
m=j===0?b1:m+0.35*(b1-m)
b2=0
b3=0
if(j>0){a1=j-1
if(!(a1<b7.length))return A.a(b7,a1)
b4=b7[a1]
a1=b4.c
b5=A.I(a.b-a1.b,a.a-a1.a).a/1e6
a=b5>0
if(a)if(d<=1.3888888888888888){l+=b5
k=0}else{k+=b5
l=0}if(a&&d>=4){b2=this.bS(b4.e,e.e)
b3=Math.abs(b2)/b5}}B.a.l(q,new A.a5(j,e,b0,m,b2,b3))}return q},
bS(a,b){if(!isFinite(a)||!isFinite(b))return 0
return B.b.V(b-a+540,360)-180}}
A.cq.prototype={
c9(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this
t.t.a(b)
s=J.eu(b.slice(0),A.h(b).c)
r=B.Z.cf(s)
if(r.length===0)return new A.cp(B.N,B.aO,B.aP)
q=d.bp(r)
p=d.a2(r,new A.dU(),new A.dV(),B.am,new A.dW(d,r))
o=d.a2(r,new A.e5(),new A.e6(),B.J,new A.e7(r))
n=d.a2(r,new A.e8(),new A.e9(),B.J,new A.ea(r))
m=d.gbx()
l=d.a2(r,m,m,B.ao,new A.eb())
k=d.a2(r,new A.ec(),new A.dX(),B.al,new A.dY(d,r))
j=A.bI(r.length,B.H,!1,t.fR)
d.aa(j,l,B.ag)
d.aa(j,o,B.af)
d.aa(j,n,B.ah)
d.aa(j,p,B.I)
m=A.h(p)
i=t.F
m=A.q(new A.f(p,m.h("p(1)").a(new A.dZ(d,a,r,q)),m.h("f<1,p>")),i)
h=A.h(o)
B.a.B(m,new A.f(o,h.h("p(1)").a(new A.e_(d,a,r,q)),h.h("f<1,p>")))
h=A.h(n)
B.a.B(m,new A.f(n,h.h("p(1)").a(new A.e0(d,a,r,q)),h.h("f<1,p>")))
h=A.h(k)
B.a.B(m,new A.f(k,h.h("p(1)").a(new A.e1(d,a,r,q)),h.h("f<1,p>")))
g=A.h(l)
B.a.B(m,new A.f(l,g.h("p(1)").a(new A.e2(d,a,r,q)),g.h("f<1,p>")))
B.a.a0(m,new A.e3())
g=A.T(r,t.C)
f=t.gE
e=A.T(d.bj(j,r),f)
A.T(new A.f(k,h.h("@(1)").a(new A.e4(r)),h.h("f<1,@>")),f)
A.T(q,t.fo)
return new A.cp(g,e,A.T(d.bN(m),i))},
by(a){return a.b.d>=5&&Math.abs(a.e)<=0.3&&a.d<=1.5},
a2(a,b,c,d,e){var s,r,q,p,o,n,m
t.X.a(a)
s=t.d1
s.a(c)
s.a(b)
t._.a(e)
r=A.j([],t.dO)
for(q=null,p=null,o=0;o<a.length;++o){n=a[o]
if(q==null){if(c.$1(n)){p=o
q=p}continue}if(b.$1(n)){p=o
continue}s=n.b.c
p.toString
if(!(p<a.length))return A.a(a,p)
m=a[p].b.c
if(A.I(s.b-m.b,s.a-m.a).a<=1e6)continue
this.aL(r,a,q,p,d,e)
q=c.$1(n)?o:null
p=q}if(q!=null&&p!=null)this.aL(r,a,q,p,d,e)
return r},
aL(a,b,c,d,e,f){var s,r,q
t.e.a(a)
t.X.a(b)
A.a0(d)
t._.a(f)
s=new A.a6(c,d)
r=b.length
if(!(d<r))return A.a(b,d)
q=b[d]
if(!(c<r))return A.a(b,c)
if(q.b.c.Y(b[c].b.c).a>=e.a&&f.$1(s))B.a.l(a,s)},
bp(b4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3
t.X.a(b4)
s=A.j([],t.gI)
for(r=0,q=0;q<b4.length;++q){p=b4[q].b.c.P(-45e6)
o=p.a
n=b4.length
m=p.b
for(;;){if(r<q){if(!(r>=0&&r<n))return A.a(b4,r)
l=b4[r].b.c
k=l.a
if(k>=o)l=k===o&&l.b<m
else l=!0}else l=!1
if(!l)break;++r}if(!(q<n))return A.a(b4,q)
o=b4[q].b.c
if(!(r>=0&&r<n))return A.a(b4,r)
m=b4[r].b.c
if(A.I(o.b-m.b,o.a-m.a).a<8e6){B.a.l(s,B.b_)
continue}for(j=r,i=0,h=0,g=0,f=0,e=0,d=0,c=!1,b=0;j<=q;++j,c=a1){if(!(j<n))return A.a(b4,j)
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
a8=B.b.k(1-a5/8.333333333333334,0,1)
a9=B.b.k(a6/25,0,1)
b0=B.b.k(e/4,0,1)
b1=B.b.k(d/4,0,1)
b2=B.b.k(a7*0.45+a8*0.35+a9*0.2,0,1)
b3=B.b.k(a7*0.3+f/a4*0.25+b0*0.25+b1*0.2,0,1)
if(b3>=0.62)B.a.l(s,new A.az(B.b3,b2,b3))
else if(b2>=0.55)B.a.l(s,new A.az(B.b2,b2,b3))
else{B.b.k(1-Math.max(b2,b3),0,1)
B.a.l(s,new A.az(B.b1,b2,b3))}}return s},
a3(a,b,a0,a1,a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=this
t.X.a(a1)
t.dr.a(a2)
for(s=a0.a,r=a0.b,q=a1.length,p=s,o=0,n=1/0;p<=r;++p){if(!(p<q))return A.a(a1,p)
m=a1[p].b.d
o=Math.max(o,m)
n=Math.min(n,m)}l=s+B.c.A(r-s,2)
if(!(l>=0&&l<a2.length))return A.a(a2,l)
k=a2[l]
j=A.ht(t.V)
i=c.bZ(k.a)
if(i!=null)j.l(0,i)
h=c.bF(b)
g=A.ab(t.N,t.i)
if(b===B.j){g.q(0,"totalHeadingChangeDegrees",c.aN(a1,s,r))
g.q(0,"apexIndex",c.bn(a1,a0))
j.l(0,B.u)}else j.l(0,c.aq(b))
q=a1.length
if(!(r<q))return A.a(a1,r)
f=a1[r]
if(!(s<q))return A.a(a1,s)
e=B.b.k(B.c.A(f.b.c.Y(a1[s].b.c).a,1000)/1000/5,0.5,1)
f=a1.length
if(!(s<f))return A.a(a1,s)
q=a1[s].b
if(!(r<f))return A.a(a1,r)
f=a1[r].b
d=n===1/0?0:n
return A.hj(e,j,c.ai(a1,s,r),a,r,f.d,f.c,a+":"+b.b+":"+s+":"+r,o,g,d,B.O,A.iQ([h],t.c5),h,s,q.d,q.c,k,b)},
bN(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
t.B.a(a)
s=t.N
r=A.ab(s,t.dg)
for(q=a.length,p=t.s,o=0;n=a.length,o<n;a.length===q||(0,A.E)(a),++o)r.q(0,a[o].a,A.j([],p))
s=A.ab(s,t.fj)
for(q=t.V,o=0;p=a.length,o<p;a.length===n||(0,A.E)(a),++o){m=a[o]
p=A.hs(q)
p.B(0,m.ch)
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
g.l(0,this.aq(f.c))
e=s.i(0,e)
e.toString
e.l(0,this.aq(p))}}q=A.h(a)
p=q.h("f<1,p>")
s=A.q(new A.f(a,q.h("p(1)").a(new A.dT(s,r)),p),p.h("m.E"))
s.$flags=1
return s},
bF(a){var s
switch(a.a){case 0:s=B.ax
break
case 1:s=B.v
break
case 2:s=B.K
break
case 3:s=B.L
break
case 4:s=B.M
break
default:s=null}return s},
aq(a){var s
switch(a.a){case 0:s=B.aq
break
case 1:s=B.ar
break
case 2:s=B.at
break
case 3:s=B.u
break
case 4:s=B.as
break
default:s=null}return s},
bZ(a){var s=null
switch(a.a){case 3:s=B.aw
break
case 2:s=B.av
break
case 1:s=B.au
break
case 0:break}return s},
aa(a,b,c){var s,r,q,p,o
t.e2.a(a)
t.e.a(b)
for(s=b.length,r=0;r<b.length;b.length===s||(0,A.E)(b),++r){q=b[r]
for(p=q.a,o=q.b;p<=o;++p)B.a.q(a,p,c)}},
bj(a,b){var s,r,q,p,o,n,m
t.e2.a(a)
t.X.a(b)
s=A.j([],t.G)
for(r=a.length,q=0,p=1;p<=r;++p){if(p<r){o=a[p]
if(!(q>=0&&q<r))return A.a(a,q)
o=o===a[q]}else o=!1
if(o)continue
if(!(q>=0&&q<r))return A.a(a,q)
o=a[q]
n=p-1
m=b.length
if(!(q<m))return A.a(b,q)
if(!(n<m))return A.a(b,n)
B.a.l(s,new A.ar(o,q,n))
q=p}return s},
ai(a,b,c){var s,r,q
t.X.a(a)
for(s=b+1,r=a.length,q=0;s<=c;++s){if(!(s<r))return A.a(a,s)
q+=a[s].b.w}return q},
aN(a,b,c){var s,r,q
t.X.a(a)
for(s=b+1,r=a.length,q=0;s<=c;++s){if(!(s<r))return A.a(a,s)
q+=Math.abs(a[s].f)}return q},
bn(a,b){var s,r,q,p,o,n
t.X.a(a)
s=b.a
for(r=b.b,q=a.length,p=s,o=0;p<=r;++p){if(!(p<q))return A.a(a,p)
n=a[p].r
if(n>o){o=n
s=p}}return s}}
A.dV.prototype={
$1(a){return a.b.d<=1.3888888888888888},
$S:1}
A.dU.prototype={
$1(a){return a.b.d<=1.3888888888888888},
$S:1}
A.dW.prototype={
$1(a){return this.a.ai(this.b,a.a,a.b)<=8},
$S:5}
A.e6.prototype={
$1(a){return a.e>=0.35},
$S:1}
A.e5.prototype={
$1(a){return a.e>=0.15},
$S:1}
A.e7.prototype={
$1(a){var s,r=this.a,q=a.b,p=r.length
if(!(q<p))return A.a(r,q)
q=r[q]
s=a.a
if(!(s<p))return A.a(r,s)
return q.b.d-r[s].b.d>=2},
$S:5}
A.e9.prototype={
$1(a){return a.e<=-0.35},
$S:1}
A.e8.prototype={
$1(a){return a.e<=-0.15},
$S:1}
A.ea.prototype={
$1(a){var s,r=this.a,q=a.a,p=r.length
if(!(q<p))return A.a(r,q)
q=r[q]
s=a.b
if(!(s<p))return A.a(r,s)
return q.b.d-r[s].b.d>=2},
$S:5}
A.eb.prototype={
$1(a){return!0},
$S:5}
A.dX.prototype={
$1(a){return a.b.d>=4&&a.r>=4},
$S:1}
A.ec.prototype={
$1(a){return a.b.d>=4&&a.r>=2},
$S:1}
A.dY.prototype={
$1(a){var s=this.a,r=this.b,q=a.a,p=a.b
return s.aN(r,q,p)>=15&&s.ai(r,q,p)>=15},
$S:5}
A.dZ.prototype={
$1(a){var s=this
return s.a.a3(s.b,B.G,t.Q.a(a),s.c,s.d)},
$S:2}
A.e_.prototype={
$1(a){var s=this
return s.a.a3(s.b,B.l,t.Q.a(a),s.c,s.d)},
$S:2}
A.e0.prototype={
$1(a){var s=this
return s.a.a3(s.b,B.p,t.Q.a(a),s.c,s.d)},
$S:2}
A.e1.prototype={
$1(a){var s=this
return s.a.a3(s.b,B.j,t.Q.a(a),s.c,s.d)},
$S:2}
A.e2.prototype={
$1(a){var s=this
return s.a.a3(s.b,B.m,t.Q.a(a),s.c,s.d)},
$S:2}
A.e3.prototype={
$2(a,b){var s,r=t.F
r.a(a)
r.a(b)
s=B.c.C(a.d,b.d)
return s!==0?s:B.c.C(a.c.a,b.c.a)},
$S:23}
A.e4.prototype={
$1(a){var s,r,q,p
t.Q.a(a)
s=a.a
r=a.b
q=this.a
p=q.length
if(!(s<p))return A.a(q,s)
if(!(r<p))return A.a(q,r)
return new A.ar(B.ai,s,r)},
$S:24}
A.dT.prototype={
$1(a){var s,r,q
t.F.a(a)
s=a.a
r=this.a.i(0,s)
r.toString
r=A.hu(r,t.V)
q=this.b.i(0,s)
q.toString
q=A.T(q,t.N)
r=t.eN.a(new A.bX(r,t.f4))
t.gJ.a(q)
return A.hj(a.as,r,a.Q,a.b,a.e,a.x,a.r,s,a.y,a.cx,a.z,q,a.ay,a.ax,a.d,a.w,a.f,a.at,a.c)},
$S:25}
A.a6.prototype={}
A.ed.prototype={
F(){return"DriveScoreAlgorithmVersion."+this.b}}
A.ee.prototype={
aY(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
t.t.a(b)
s=J.eu(b.slice(0),A.h(b).c)
if(s.length<2)throw A.d(B.a3)
if(B.a.a4(s,new A.ef()))throw A.d(B.a4)
switch(a.a){case 0:r=B.a_.c9("in-memory-drive-score",t.an.a(s))
q=B.X.H(r)
p=B.a7.H(r)
o=B.Y.H(r)
n=B.a1.H(r)
m=B.W.H(r)
l=B.a8.H(r)
k=q.z
k=k.a&&k.b&&k.c&&k.d
j=q.f>0||q.r>0
i=p.as.a
h=t.N
g=t.R
f=A.S(["brakingAnticipation",new A.H(q.a,350,!k,j),"tempoPerformance",new A.H(p.a,150,i,i),"corneringPerformance",new A.H(o.a,150,o.y,o.z),"drivingSmoothness",new A.H(n.a,100,n.b,n.c),"accelerationPerformance",new A.H(m.a,50,m.e,m.f),"transitionControl",new A.H(l.a,50,l.e,l.f)],h,g)
e=B.a2.b7(p.r,new A.aa(f,A.k(f).h("aa<2>")))
g=A.hq(h,g)
g.B(0,f)
g.q(0,"drivingEndurance",new A.H(e.a,150,e.f,e.r))
g=B.a0.c8(g)
k=g
break
default:k=null}return k}}
A.ef.prototype={
$1(a){return!t.u.a(a).gcj()},
$S:26}
A.cx.prototype={
j(a){return u.c}}
A.et.prototype={
j(a){return"Canonical telemetry contains an invalid coordinate."}}
A.eg.prototype={
c8(a){var s,r,q,p,o,n,m,l,k,j,i
t.cC.a(a)
s=t.N
r=t.D
q=A.ab(s,r)
for(p=new A.bE(a,A.k(a).h("bE<1,2>")).gt(0),o=0;p.n();){n=p.d
m=n.b
l=m.c
if(l&&m.d)k=B.F
else k=!l?B.ad:B.ae
l=k===B.F
j=l?m.a:m.b*0.75
if(l)++o
q.q(0,n.a,new A.aF(j,k))}i=B.b.k(new A.aa(q,q.$ti.h("aa<2>")).G(0,0,new A.eh(),t.i),0,1000)
p=B.b.ae(i)
return new A.ei(i,B.b.k(o/a.a,0,1),p,1,A.hg(a,s,t.R),A.hg(q,s,r))}}
A.eh.prototype={
$2(a,b){return A.t(a)+t.D.a(b).b},
$S:27}
A.bt.prototype={
F(){return"DriveScoreContributionSource."+this.b}}
A.H.prototype={}
A.aF.prototype={}
A.ei.prototype={}
A.ah.prototype={
F(){return"DrivingPhase."+this.b}}
A.bf.prototype={
F(){return"TrafficRegime."+this.b}}
A.aR.prototype={
F(){return"DrivingEventType."+this.b}}
A.aG.prototype={
F(){return"EventOwnerDomain."+this.b}}
A.X.prototype={
F(){return"EventContextTag."+this.b}}
A.a5.prototype={}
A.az.prototype={}
A.ar.prototype={}
A.p.prototype={}
A.cp.prototype={
R(a){var s=this.f,r=A.h(s)
return new A.x(s,r.h("i(1)").a(new A.dS(a)),r.h("x<1>"))}}
A.dS.prototype={
$1(a){return t.F.a(a).c===this.a},
$S:4}
A.ej.prototype={
H(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=A.j([],t.h)
for(s=a.R(B.m),r=J.W(s.a),s=new A.ad(r,s.b,s.$ti.h("ad<1>")),q=0;s.n();){p=r.gp()
o=p.at
n=Math.max(o.c,o.d)
if(p.ax===B.M){o=p.r
m=p.f
o=A.I(o.b-m.b,o.a-m.a).a<8e6||p.y<8.333333333333334||n>=0.65}else o=!0
if(o)++q
else B.a.l(d,p)}s=d.length
if(s===0)return new A.cr(0,!1,!1)
for(l=0,k=B.aj,j=0,i=0;i<d.length;d.length===s||(0,A.E)(d),++i){h=d[i]
r=h.r
p=h.f
g=r.a-p.a
f=r.b-p.b
l+=A.I(f,g).a
if(A.I(f,g).a>k.a)k=A.I(f,g)
j+=B.b.k(1-this.c3(a,h)/4,0,1)*A.I(f,g).a}e=A.I(l,0)
s=B.b.k((0.55*this.bo(e,B.ap,B.ak,B.an)+0.45*(j/l))*100,0,1)
r=e.a
B.c.A(r,1e6)
return new A.cr(s*100,!0,r>=3e7)},
c3(a,b){var s=B.a.a6(a.b,b.d,b.e+1),r=A.h(s),q=r.h("f<1,b>"),p=A.q(new A.f(s,r.h("b(1)").a(new A.ek()),q),q.h("m.E"))
return B.a.G(p,0,new A.el(B.a.L(p,new A.em())/p.length),t.i)/p.length},
bo(a,b,c,d){var s,r=a.a,q=b.a
if(r<=q)return 0
s=c.a
if(r<=s)return 0.75*(r-q)/(s-q)
return 0.75+0.25*B.b.k((r-s)/(d.a-s),0,1)}}
A.ek.prototype={
$1(a){return t.C.a(a).b.d},
$S:3}
A.em.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.el.prototype={
$2(a,b){var s
A.t(a)
s=A.t(b)-this.a
return a+s*s},
$S:0}
A.en.prototype={
b7(a,b){var s,r,q,p,o
t.ff.a(b)
s=b.$ti
r=s.h("x<c.E>")
q=A.q(new A.x(b,s.h("i(c.E)").a(new A.eo()),r),r.h("c.E"))
if(a<5||q.length===0)return new A.cs(0,!1,!1)
p=this.bH(a)
s=A.h(q)
o=B.b.k(new A.f(q,s.h("b(1)").a(new A.ep()),s.h("f<1,b>")).L(0,new A.eq())/q.length,0.15,1)
B.b.k(q.length/6,0,1)
s=a>=50&&q.length>=3
return new A.cs(p*o*150,!0,s)},
bH(a){if(a<=5)return a/5*0.15
if(a<=50)return 0.15+(a-5)/45*0.6
return B.b.k(0.75+(a-50)/100*0.25,0,1)}}
A.eo.prototype={
$1(a){t.R.a(a)
return a.c&&a.d},
$S:28}
A.ep.prototype={
$1(a){t.R.a(a)
return a.a/a.b},
$S:29}
A.eq.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.cs.prototype={}
A.cr.prototype={}
A.cd.prototype={}
A.ai.prototype={
F(){return"DrivingTransitionType."+this.b}}
A.a9.prototype={}
A.cM.prototype={}
A.bb.prototype={
F(){return"LocalRoadWindowState."+this.b}}
A.bJ.prototype={
F(){return"LocalRoadRegionAnalysisStatus."+this.b}}
A.aI.prototype={}
A.Y.prototype={}
A.bK.prototype={}
A.eD.prototype={
ca(a,b,c,d,e,f){var s,r,q,p=t.t
p.a(e)
p.a(c)
if(!f.at)return new A.bK(B.aU,B.P,B.Q)
if(f.as<0.65)return new A.bK(B.aV,B.P,B.Q)
s=B.k.aw(d,e,f,b,c)
r=this.bg(a,b,s.b.b,d,s.a.b,f)
q=this.c7(a,f,r)
return new A.bK(B.aT,A.T(r,t.l),A.T(q,t.m))},
bg(a,b,c,d,a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=t.t
e.a(a0)
e.a(c)
s=A.j([],t.d)
for(r=a1.z,e=a1.e,q=a1.f,p=a1.r,o=a1.w,n=f.a,m=0;m<r;m=l){l=m+100
l=l<r?l:r
k=f.a9(e,q,r,m)
j=f.a9(e,q,r,l)
i=f.a9(p,o,r,m)
h=f.a9(p,o,r,l)
g=n.aZ(a,j,d,k,a0,a1,5,!1,h,b,i,c)
B.a.l(s,new A.aI(m,l,k,j,i,h,f.bW(g),g))}return s},
c7(a,b,c){var s,r,q,p,o,n,m,l,k,j,i={}
t.fB.a(c)
s=A.j([],t.r)
i.a=null
i.b=0
r=new A.eE(i,s,b,a)
for(q=c.length,p=0;p<c.length;c.length===q||(0,A.E)(c),++p){o=c[p]
if(o.r===B.S){n=i.a
m=o.b
l=o.d
k=o.f
if(n==null)i.a=new A.fp(o.a,m,o.c,l,o.e,k)
else{n.b=m
n.d=l
n.f=k;++n.w}i.b=0
continue}if(i.a==null)continue
j=i.b+(o.b-o.a)
i.b=j
if(j>200.000001)r.$0()}r.$0()
return s},
bW(a){var s,r
if(!a.y)return B.T
s=a.x
A:{if(B.A===s){r=B.aW
break A}if(B.B===s){r=B.S
break A}if(B.C===s){r=B.aX
break A}r=B.T
break A}return r},
a9(a,b,c,d){if(c<=0)return a
return a+(b-a)*d/c}}
A.eE.prototype={
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
$S:30}
A.fp.prototype={}
A.Z.prototype={}
A.U.prototype={}
A.eL.prototype={
H(a6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2=this,a3=1e6,a4=a6.b,a5=a4.length
if(a5<2)return new A.bU(0,0,B.aZ)
for(s=a5-1,r=0,q=0,p=0,o=0,n=0,m=0;m<a5;++m){l=a4[m].b
o+=l.w
if(m===s)continue
k=m+1
if(!(k<a5))return A.a(a4,k)
k=a4[k].b
j=k.c
l=l.c
l=A.I(j.b-l.b,j.a-l.a).a
if(l<=0){++n
continue}if(a2.bz(a6,m))q+=l
else{r+=l
p+=k.w}}i=B.a.gT(a4).b.c.Y(B.a.gI(a4).b.c)
h=A.I(r,0)
g=A.I(q,0)
f=o/1000
s=h.a
e=s<=0?0:p/(s/1e6)*3.6
d=a2.c2(a6)
c=a5>=6&&s>=9e7&&o>=1000
B.b.k(Math.min(a5/6,Math.min(s/9e7,f)),0,1)
if(!c){B.b.a_(f,2)
B.c.A(s,a3)
return new A.bU(0,f,new A.bT(!1))}a5=i.a
b=a5<=0?0:o/(a5/1e6)*3.6
a=a2.ao(e,B.aJ,60)
a0=d.b<2?0:a2.ao(d.a*3.6,B.aQ,30)
a1=B.b.k(a+a0+a2.ao(b,B.aF,60),0,150)
B.b.a_(f,2)
B.c.A(s,a3)
B.c.A(g.a,a3)
return new A.bU(a1,f,new A.bT(!0))},
bz(a,b){var s,r,q,p
if(this.bG(a.c,b)===B.I)return!0
s=a.b
r=s.length
if(!(b<r))return A.a(s,b)
q=s[b]
p=b+1
if(!(p<r))return A.a(s,p)
p=s[p]
return q.b.d<=1.3888888888888888&&p.b.d<=1.3888888888888888},
bG(a,b){var s,r,q
t.au.a(a)
for(s=a.length,r=0;r<s;++r){q=a[r]
if(b>=q.b&&b<=q.c)return q.a}return B.H},
c2(a){var s,r,q,p,o,n,m,l,k,j=a.b
for(s=j.length,r=0,q=0,p=0;p<s;++p){o=j[p].b.d
if(!isFinite(o)||o<0)continue
for(n=[p-1,p+1],m=1,l=0;l<2;++l){k=n[l]
if(k<0||k>=s)continue
if(!(k>=0&&k<s))return A.a(j,k)
if(Math.abs(j[k].b.d-o)<=10)++m}if(m<2)continue
if(o>r){q=m
r=o}}return new A.fo(r,q)},
ao(a,b,c){var s,r,q,p,o,n
t.gj.a(b)
if(a<=B.a.gI(B.a.gI(b)))return 0
for(s=b.length,r=1;r<s;++r){q=b[r-1]
p=b[r]
if(a<=B.a.gI(p)){s=B.a.gI(q)
o=B.a.gI(p)
n=B.a.gI(q)
return B.b.k(c*(B.a.gT(q)+(B.a.gT(p)-B.a.gT(q))*((a-s)/(o-n))),0,c)}}return c}}
A.fo.prototype={}
A.bU.prototype={}
A.bT.prototype={}
A.eM.prototype={
H(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=a.f,b=A.j([],t.c)
for(s=c.length,r=0;q=r+2,q<s;){if(!(r<s))return A.a(c,r)
p=c[r];++r
if(!(r<s))return A.a(c,r)
o=c[r]
n=c[q]
m=this.c1(p,o,n)
if(m!=null){q=o.at
l=Math.max(q.c,q.d)
q=!1
if(n.y>=8.333333333333334)if(l<0.65){k=o.f
j=p.r
if(A.I(k.b-j.b,k.a-j.a).a<=8e6){q=n.f
k=o.r
k=A.I(q.b-k.b,q.a-k.a).a<=8e6
q=k}}q=!q}else q=!0
if(q)continue
B.a.l(b,new A.a9(m,this.bK(a,n)))}if(b.length===0)return B.b4
i=new A.eR(b)
h=i.$2(B.q,20)
g=i.$2(B.r,20)
f=i.$2(B.t,10)
s=A.ab(t.am,t.S)
for(q=t.eF,k=t.dA,e=0;e<3;++e){d=B.aS[e]
s.q(0,d,new A.x(b,q.a(new A.eQ(d)),k).gm(0))}return new A.cM(h+g+f,!0,b.length>=2)},
c1(a,b,c){var s,r
if(c.c!==B.m)return null
s=a.c
r=s===B.m
if(r&&b.c===B.p)return B.q
if(r&&b.c===B.j)return B.r
if(s===B.l)return B.t
return null},
bK(a,b){var s=B.a.a6(a.b,b.d,b.e+1),r=A.h(s)
return B.b.k(1-Math.sqrt(B.a.G(s,0,new A.eN(new A.f(s,r.h("b(1)").a(new A.eO()),r.h("f<1,b>")).L(0,new A.eP())/s.length),t.i)/s.length)/4,0,1)}}
A.eR.prototype={
$2(a,b){var s=this.a,r=A.h(s),q=r.h("x<1>"),p=A.q(new A.x(s,r.h("i(1)").a(new A.eS(a)),q),q.h("c.E"))
if(p.length===0)return 0
s=A.h(p)
return new A.f(p,s.h("b(1)").a(new A.eT()),s.h("f<1,b>")).L(0,new A.eU())/p.length*b},
$S:31}
A.eS.prototype={
$1(a){return t.f.a(a).a===this.a},
$S:16}
A.eT.prototype={
$1(a){return t.f.a(a).e},
$S:33}
A.eU.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.eQ.prototype={
$1(a){return t.f.a(a).a===this.a},
$S:16}
A.eO.prototype={
$1(a){return t.C.a(a).b.d},
$S:3}
A.eP.prototype={
$2(a,b){return A.t(a)+A.t(b)},
$S:0}
A.eN.prototype={
$2(a,b){var s
A.t(a)
s=t.C.a(b).b.d-this.a
return a+s*s},
$S:34}
A.eY.prototype={}
A.eZ.prototype={}
A.cO.prototype={
cq(a8,a9,b0,b1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7=this
t.fV.a(b1)
s=a8.b
r=t.N
q=A.ab(r,t.fd)
p=A.j([],t.M)
o=A.ab(r,t.W)
for(n=b1.length,m=t.e5,l=m.h("c.E"),k=0;k<b1.length;b1.length===n||(0,A.E)(b1),++k){j=b1[k]
for(i=j.b,h=i.length,g=j.a,f=0;f<i.length;i.length===h||(0,A.E)(i),++f){e=i[f]
if(!e.ax||!e.Q)continue
d=a7.bh(e,g)
if(d==null)continue
J.iu(o.cr(d.a,new A.f5()),new A.C(d.b,d.c))}i=j.c
h=A.h(i)
i=A.q(new A.bZ(new A.a3(new A.x(i,h.h("i(1)").a(new A.f6(a8)),h.h("x<1>")),h.h("a_?(1)").a(new A.f7(a7,j)),h.h("a3<1,a_?>")),m),l)
i.$flags=1
c=i
if(c.length===0)continue
q.q(0,g.a,a7.bU(g,c,b0))
i=A.h(c)
B.a.B(p,new A.f(c,i.h("D(1)").a(new A.f8(a8)),i.h("f<1,D>")))}b=a7.aU(a8)
for(n=b.length,m=a8.a,l=a8.Q,k=0;k<b.length;b.length===n||(0,A.E)(b),++k){a=b[k]
i=a.a.a
h=o.i(0,i)
for(h=a7.bY(new A.C(a.b,a.c),a7.bC(h==null?B.R:h)),g=h.length,f=0;f<h.length;h.length===g||(0,A.E)(h),++f){a0=h[f]
B.a.l(p,new A.D(m,s,i,l,a0.a,a0.b))}}n=t.x
a1=A.j([],n)
a2=A.j([],n)
for(n=a9.c,m=n.length,k=0;k<n.length;n.length===m||(0,A.E)(n),++k){a3=n[k]
a4=q.i(0,a3.a)
if(a4==null)B.a.l(a1,a3)
else{B.a.l(a2,a3)
l=A.h(a4)
B.a.B(a1,new A.f(a4,l.h("z(1)").a(new A.f9(a7,a3,b0)),l.h("f<1,z>")))}}n=t.E
m=A.q(new A.a3(new A.x(p,t.bb.a(new A.fa()),t.a3),t.eS.a(new A.fb(a7,a8,b0)),t.aq),n)
l=A.q(a1,n)
B.a.B(l,m)
l=t.bZ.a(a7.bB(l,b0))
i=A.h(l)
h=i.h("i(1)").a(a7.gbv())
i=i.h("x<1>")
l=A.q(new A.x(l,h,i),i.h("c.E"))
l.$flags=1
a5=l
a7.be(a5)
l=A.hu(a9.d,r)
l.l(0,s)
l=A.q(l,A.k(l).c)
l.$flags=1
a6=l
B.a.aF(a6)
l=A.T(a5,n)
r=A.T(a6,r)
b0.O()
A.T(a2,n)
i=A.h(m)
g=i.h("x<1>")
m=A.q(new A.x(m,i.h("i(1)").a(h),g),g.h("c.E"))
m.$flags=1
A.T(m,n)
return new A.eZ("world:"+s+":v1",new A.cP(a9.a+1,l,r))},
bw(a){t.E.a(a)
return a.f-a.e>=1000},
bU(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h
t.ej.a(b)
s=A.h(b)
r=s.h("f<1,C>")
q=A.q(new A.f(b,s.h("C(1)").a(new A.f2()),r),r.h("m.E"))
B.a.a0(q,new A.f3())
p=A.j([],t.M)
o=a.e
for(s=q.length,r=a.c,n=a.b,m=a.d,l=a.r,k=0;k<q.length;q.length===s||(0,A.E)(q),++k){j=q[k]
i=j.a
if(i>o+0.01)if(i-o>=1000)B.a.l(p,new A.D(r,n,m,l,o,i))
o=Math.max(o,j.b)}s=a.f
if(o<s-0.01){h=A.ja(a,o,s)
if(h.b-h.a>=1000)B.a.l(p,h)}return p},
bi(a,b){var s,r,q,p,o,n,m=a.c
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
bh(a,b){var s,r,q,p,o,n
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
return new A.fc(a.d,q+n*((r-s)/o),q+n*((p-s)/o))},
aU(a){var s,r,q={},p=a.d
p=p.length!==0?p:A.j([new A.U(a.a+":geometry",a.c,a.e)],t.aa)
q.a=0
s=A.h(p)
r=s.h("f<1,al>")
q=A.q(new A.f(p,s.h("al(1)").a(new A.f1(q)),r),r.h("m.E"))
q.$flags=1
return q},
c0(a,b,c){var s=this.bf(B.a.ci(this.aU(b),new A.f4(a)).a.b).a
return new A.z(this.aO(a),a.d,a.c,a.e,a.a,a.b,a.f,s[0],s[1],s[2],s[3],c.O(),c.O(),b.y)},
bB(a,b){var s,r,q,p,o,n,m=A.q(t.h2.a(a),t.E)
B.a.a0(m,new A.f_())
s=A.j([],t.x)
for(r=m.length,q=0;q<m.length;m.length===r||(0,A.E)(m),++q){p=m[q]
if(s.length!==0){o=B.a.gT(s)
o=!(o.b===p.b&&o.c===p.c&&o.d===p.d&&o.r===p.r&&Math.abs(o.f-p.e)<=0.01)}else o=!0
if(o){B.a.l(s,p)
continue}if(0>=s.length)return A.a(s,-1)
n=s.pop()
o=p.f
B.a.l(s,n.cc(o,n.b+":"+n.c+":"+n.d+":"+B.b.a_(n.e,3)+":"+B.b.a_(o,3),b.O()))}return s},
be(a){var s,r,q,p,o,n
t.h2.a(a)
for(s=a.length,r=0;r<s;r=q)for(q=r+1,p=q;p<s;++p){o=a[r]
n=a[p]
if(o.d!==n.d||o.r!==n.r)continue
if(Math.min(o.f,n.f)-Math.max(o.e,n.e)>0.01&&o.b!==n.b)throw A.d(A.iZ("Duplicate active ownership for a World road interval."))}},
bC(a){var s,r,q,p,o,n
t.W.a(a)
if(J.fM(a))return B.R
s=A.q(a,t.w)
B.a.a0(s,new A.f0())
r=A.j([B.a.gI(s)],t.O)
for(s=A.bS(s,1,null,A.h(s).c),q=s.$ti,s=new A.av(s,s.gm(0),q.h("av<m.E>")),q=q.h("m.E");s.n();){p=s.d
if(p==null)p=q.a(p)
o=B.a.gT(r)
n=o.b
if(p.a<=n+0.01)B.a.q(r,r.length-1,new A.C(o.a,Math.max(n,p.b)))
else B.a.l(r,p)}return r},
bY(a,b){var s,r,q,p,o,n,m,l,k,j
t.W.a(b)
s=A.j([],t.O)
r=a.a
for(q=b.length,p=a.b,o=r,n=0;n<b.length;b.length===q||(0,A.E)(b),++n){m=b[n]
l=m.b
if(l<=r||m.a>=p)continue
k=Math.max(m.a,r)
j=Math.min(l,p)
if(k>o+0.01)B.a.l(s,new A.C(o,k))
o=Math.max(o,j)}if(o<p-0.01)B.a.l(s,new A.C(o,p))
return s},
aO(a){return a.d+":"+a.c+":"+a.e+":"+B.b.a_(a.a,3)+":"+B.b.a_(a.b,3)},
bf(a){var s,r,q,p,o,n,m,l
t.f8.a(a)
if(a.length===0)return B.aY
s=B.a.gI(a).a
r=B.a.gI(a).b
for(q=A.bS(a,1,null,A.h(a).c),p=q.$ti,q=new A.av(q,q.gm(0),p.h("av<m.E>")),p=p.h("m.E"),o=r,n=s;q.n();){m=q.d
if(m==null)m=p.a(m)
l=m.a
s=Math.min(s,l)
n=Math.max(n,l)
m=m.b
r=Math.min(r,m)
o=Math.max(o,m)}return new A.bi([s,n,r,o])}}
A.f5.prototype={
$0(){return A.j([],t.O)},
$S:36}
A.f6.prototype={
$1(a){t.m.a(a)
return a.b===this.a.b&&a.y+0.01>=2000},
$S:37}
A.f7.prototype={
$1(a){return this.a.bi(t.m.a(a),this.b.a)},
$S:38}
A.f8.prototype={
$1(a){var s
t.L.a(a)
s=this.a
return new A.D(s.a,s.b,a.c,s.Q,a.d,a.e)},
$S:39}
A.f9.prototype={
$1(a){t.g.a(a)
return this.b.b_(a.b,this.a.aO(a),a.a,this.c.O())},
$S:15}
A.fa.prototype={
$1(a){t.g.a(a)
return a.b-a.a>0.01},
$S:41}
A.fb.prototype={
$1(a){return this.a.c0(t.g.a(a),this.b,this.c)},
$S:15}
A.f2.prototype={
$1(a){t.L.a(a)
return new A.C(a.a,a.b)},
$S:64}
A.f3.prototype={
$2(a,b){var s=t.w
return B.b.C(s.a(a).a,s.a(b).a)},
$S:13}
A.f1.prototype={
$1(a){var s,r,q,p
t.o.a(a)
s=A.hJ(a)
r=this.a
q=r.a
p=q+s
r.a=p
return new A.al(a,q,p)},
$S:44}
A.f4.prototype={
$1(a){return t.d4.a(a).a.a===this.a.e},
$S:45}
A.f_.prototype={
$2(a,b){var s,r=t.E
r.a(a)
r.a(b)
s=B.e.C(a.d,b.d)
return s!==0?s:B.b.C(a.e,b.e)},
$S:46}
A.f0.prototype={
$2(a,b){var s=t.w
return B.b.C(s.a(a).a,s.a(b).a)},
$S:13}
A.al.prototype={}
A.C.prototype={}
A.D.prototype={}
A.a_.prototype={}
A.fc.prototype={}
A.cP.prototype={}
A.fy.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j,i,h
t.P.a(a)
s=A.v(a.i(0,"id"))
r=A.v(a.i(0,"sourceDriveId"))
q=A.v(a.i(0,"validatedRoadId"))
p=A.v(a.i(0,"matchedSectionId"))
o=A.o(a.i(0,"startOffsetMeters"))
n=A.o(a.i(0,"endOffsetMeters"))
m=A.v(a.i(0,"directionKey"))
l=A.o(a.i(0,"minLatitude"))
k=A.o(a.i(0,"maxLatitude"))
j=A.o(a.i(0,"minLongitude"))
i=A.o(a.i(0,"maxLongitude"))
h=A.a0(a.i(0,"processingVersion"))
return new A.z(s,r,q,p,o,n,m,l,k,j,i,A.dO(A.v(a.i(0,"createdAt"))),A.dO(A.v(a.i(0,"updatedAt"))),h)},
$S:47}
A.fz.prototype={
$1(a){var s,r=J.bn(a),q=A.h2(t.P.a(r.i(a,"match"))),p=this.a.i(0,r.i(a,"traceId"))
p.toString
s=A.j([q],t.A)
r=J.b3(t.j.a(r.i(a,"regions")),new A.fx(q),t.m)
r=A.q(r,r.$ti.h("m.E"))
return new A.aK(p,s,r)},
$S:48}
A.fx.prototype={
$1(a){var s=J.bn(a),r=A.v(s.i(a,"existingDriveId"))
s=A.v(s.i(a,"challengerDriveId"))
t.P.a(a)
return new A.Y(r,s,this.a,A.o(a.i(0,"startOffsetOnExistingMeters")),A.o(a.i(0,"endOffsetOnExistingMeters")),A.o(a.i(0,"startOffsetOnChallengerMeters")),A.o(a.i(0,"endOffsetOnChallengerMeters")),A.o(a.i(0,"commonStartOffsetMeters")),A.o(a.i(0,"commonEndOffsetMeters")),A.o(a.i(0,"winningDistanceMeters")),B.o,A.o(a.i(0,"confidence")),A.a0(a.i(0,"supportingWindowCount")))},
$S:49}
A.fE.prototype={
$1(a){var s=J.bn(a),r=A.v(s.i(a,"id"))
s=J.b3(t.j.a(s.i(a,"geometry")),new A.fD(),t.cX)
s=A.q(s,s.$ti.h("m.E"))
return new A.U(r,s,A.o(t.P.a(a).i(0,"distanceMeters")))},
$S:50}
A.fD.prototype={
$1(a){t.P.a(a)
return new A.Z(A.o(a.i(0,"latitude")),A.o(a.i(0,"longitude")))},
$S:11}
A.fF.prototype={
$1(a){return t.o.a(a).b},
$S:52}
A.fG.prototype={
$2(a,b){return A.t(a)+t.o.a(b).c},
$S:53}
A.fL.prototype={
$1(a){var s,r,q,p,o
t.P.a(a)
s=A.o(a.i(0,"latitude"))
r=A.o(a.i(0,"longitude"))
q=A.dO(A.v(a.i(0,"timestamp")))
p=A.o(a.i(0,"speed_mps"))
o=A.o(a.i(0,"heading_degrees"))
A.o(a.i(0,"altitude_meters"))
A.o(a.i(0,"accuracy_meters"))
return new A.K(s,r,q,p,o,A.o(a.i(0,"distance_from_previous_meters")),A.o(a.i(0,"acceleration_mps2")))},
$S:54}
A.fH.prototype={
$2(a,b){A.v(a)
t.R.a(b)
return new A.J(a,A.S(["score",b.a,"maximum",b.b,"applicable",b.c,"sampleSufficient",b.d],t.N,t.K),t.ct)},
$S:55}
A.fI.prototype={
$2(a,b){A.v(a)
t.D.a(b)
return new A.J(a,A.S(["contribution",b.b,"source",b.c.b],t.N,t.K),t.ct)},
$S:56}
A.fJ.prototype={
$1(a){return t.u.a(a).c.O().aC()},
$S:57}
A.fv.prototype={
$1(a){t.P.a(a)
return new A.Z(A.o(a.i(0,"latitude")),A.o(a.i(0,"longitude")))},
$S:11}
A.fs.prototype={
$1(a){t.l.a(a)
return A.S(["commonStartOffsetMeters",a.a,"commonEndOffsetMeters",a.b,"existingStartOffsetMeters",a.c,"existingEndOffsetMeters",a.d,"challengerStartOffsetMeters",a.e,"challengerEndOffsetMeters",a.f,"state",a.r.b,"comparison",A.i7(a.w)],t.N,t.K)},
$S:58}
A.ft.prototype={
$1(a){t.m.a(a)
return A.S(["existingDriveId",a.a,"challengerDriveId",a.b,"startOffsetOnExistingMeters",a.d,"endOffsetOnExistingMeters",a.e,"startOffsetOnChallengerMeters",a.f,"endOffsetOnChallengerMeters",a.r,"commonStartOffsetMeters",a.w,"commonEndOffsetMeters",a.x,"winningDistanceMeters",a.y,"algorithmVersion",1,"confidence",a.Q,"supportingWindowCount",a.as],t.N,t.K)},
$S:59}
A.fA.prototype={
$1(a){return B.f.av(A.k6(t.P.a(B.f.au(A.v(a),null))),null)},
$S:8}
A.fB.prototype={
$1(a){return B.f.av(A.k4(t.P.a(B.f.au(A.v(a),null))),null)},
$S:8}
A.fC.prototype={
$1(a){return B.f.av(A.k7(t.P.a(B.f.au(A.v(a),null))),null)},
$S:8}
A.aK.prototype={};(function aliases(){var s=J.aH.prototype
s.b8=s.j})();(function installTearOffs(){var s=hunkHelpers._static_2,r=hunkHelpers._static_1,q=hunkHelpers._instance_1u,p=hunkHelpers.installStaticTearOff
s(J,"jE","iM",61)
r(A,"k2","ju",62)
q(A.co.prototype,"gc4","c5",6)
q(A.cq.prototype,"gbx","by",1)
q(A.cO.prototype,"gbv","bw",35)
r(A,"ko","ki",63)
p(A,"kh",2,null,["$1$2","$2"],["ia",function(a,b){return A.ia(a,b,t.H)}],42,0)})();(function inheritance(){var s=hunkHelpers.mixin,r=hunkHelpers.inherit,q=hunkHelpers.inheritMany
r(A.n,null)
q(A.n,[A.fO,J.cy,A.bO,J.aP,A.c,A.bp,A.A,A.eJ,A.av,A.bL,A.ad,A.by,A.bP,A.bw,A.c_,A.aZ,A.bc,A.br,A.Q,A.eV,A.eH,A.N,A.eA,A.bG,A.bH,A.bF,A.cC,A.fj,A.ac,A.cR,A.fl,A.aW,A.cU,A.aX,A.c8,A.c1,A.cV,A.ci,A.cm,A.fh,A.ag,A.R,A.fd,A.cF,A.bQ,A.fe,A.er,A.J,A.aU,A.be,A.d_,A.z,A.dg,A.aM,A.ak,A.dx,A.df,A.K,A.dy,A.cj,A.ck,A.ao,A.dC,A.dz,A.c2,A.ae,A.ff,A.co,A.cn,A.af,A.dR,A.cq,A.a6,A.ee,A.cx,A.et,A.eg,A.H,A.aF,A.ei,A.a5,A.az,A.ar,A.p,A.cp,A.ej,A.en,A.cs,A.cr,A.cd,A.a9,A.cM,A.aI,A.Y,A.bK,A.eD,A.fp,A.Z,A.U,A.eL,A.fo,A.bU,A.bT,A.eM,A.eY,A.eZ,A.cO,A.al,A.C,A.a_,A.fc,A.cP,A.aK])
q(J.cy,[J.cA,J.bA,J.ba,J.b8,J.aT])
q(J.ba,[J.aH,J.l])
q(J.aH,[J.eI,J.aJ,J.bB])
r(J.cz,A.bO)
r(J.ev,J.l)
q(J.b8,[J.bz,J.cB])
q(A.c,[A.bg,A.w,A.a3,A.x,A.bx,A.ax,A.bZ])
r(A.aQ,A.bg)
r(A.c0,A.aQ)
q(A.A,[A.bD,A.bV,A.cD,A.cN,A.cJ,A.cQ,A.bC,A.ce,A.am,A.bY,A.bd,A.cl])
q(A.w,[A.m,A.bv,A.au,A.aa,A.bE])
q(A.m,[A.bR,A.f,A.eC,A.cT])
r(A.bu,A.a3)
r(A.b6,A.ax)
r(A.bh,A.aZ)
r(A.bi,A.bh)
r(A.bk,A.bc)
r(A.bW,A.bk)
r(A.bs,A.bW)
q(A.Q,[A.ch,A.cw,A.cg,A.cL,A.dP,A.dQ,A.d7,A.d9,A.da,A.db,A.d0,A.d3,A.d4,A.dc,A.dv,A.dw,A.dh,A.di,A.dl,A.dm,A.dp,A.dq,A.dr,A.dk,A.dj,A.dn,A.dA,A.dJ,A.dF,A.dG,A.dH,A.dI,A.dV,A.dU,A.dW,A.e6,A.e5,A.e7,A.e9,A.e8,A.ea,A.eb,A.dX,A.ec,A.dY,A.dZ,A.e_,A.e0,A.e1,A.e2,A.e4,A.dT,A.ef,A.dS,A.ek,A.eo,A.ep,A.eS,A.eT,A.eQ,A.eO,A.f6,A.f7,A.f8,A.f9,A.fa,A.fb,A.f2,A.f1,A.f4,A.fy,A.fz,A.fx,A.fE,A.fD,A.fF,A.fL,A.fJ,A.fv,A.fs,A.ft,A.fA,A.fB,A.fC])
q(A.ch,[A.dD,A.ew,A.eB,A.eG,A.fi,A.d8,A.d2,A.d1,A.d6,A.d5,A.dt,A.du,A.dB,A.dK,A.dL,A.dE,A.e3,A.eh,A.em,A.el,A.eq,A.eR,A.eU,A.eP,A.eN,A.f3,A.f_,A.f0,A.fG,A.fH,A.fI])
r(A.ap,A.br)
r(A.b7,A.cw)
r(A.bM,A.bV)
q(A.cL,[A.cK,A.b5])
q(A.N,[A.at,A.cS])
r(A.bj,A.cQ)
q(A.aW,[A.c3,A.c9])
r(A.aC,A.c3)
r(A.bX,A.c9)
r(A.cE,A.bC)
r(A.ex,A.ci)
q(A.cm,[A.ez,A.ey])
r(A.fg,A.fh)
q(A.cg,[A.dM,A.ds,A.eE,A.f5])
q(A.am,[A.bN,A.cv])
q(A.fd,[A.an,A.bq,A.ed,A.bt,A.ah,A.bf,A.aR,A.aG,A.X,A.ai,A.bb,A.bJ])
r(A.D,A.C)
s(A.bk,A.c8)
s(A.c9,A.cV)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{O:"int",b:"double",P:"num",e:"String",i:"bool",aU:"Null",r:"List",n:"Object",u:"Map",b9:"JSObject"},mangledNames:{},types:["b(b,b)","i(a5)","p(a6)","b(a5)","i(p)","i(a6)","b(af)","b(p)","e(e)","~(n?,n?)","O(e?)","Z(@)","b(b)","O(C,C)","b(ak)","z(D)","i(a9)","b(b,aM)","b(b,ae)","K(ae)","b(b(af))","i(e)","~(@,@)","O(p,p)","ar(a6)","p(p)","i(K)","b(b,aF)","i(H)","b(H)","~()","b(ai,b)","aU()","b(a9)","b(b,a5)","i(z)","r<C>()","i(Y)","a_?(Y)","D(a_)","i(p?)","i(D)","0^(0^,0^)<P>","i(ak)","al(U)","i(al)","O(z,z)","z(@)","aK(@)","Y(@)","U(@)","0&()","r<Z>(U)","b(b,U)","K(@)","J<e,u<e,n>>(e,H)","J<e,u<e,n>>(e,aF)","e(K)","u<e,n>(aI)","u<e,n>(Y)","b(b(p))","O(@,@)","@(@)","u<e,@>(z)","C(a_)"],arrayRti:Symbol("$ti"),rttc:{"4;":a=>b=>b instanceof A.bi&&A.kj(a,b.a)}}
A.ji(v.typeUniverse,JSON.parse('{"bB":"aH","eI":"aH","aJ":"aH","cA":{"i":[],"aA":[]},"bA":{"aA":[]},"ba":{"b9":[]},"aH":{"b9":[]},"l":{"r":["1"],"w":["1"],"b9":[],"c":["1"]},"cz":{"bO":[]},"ev":{"l":["1"],"r":["1"],"w":["1"],"b9":[],"c":["1"]},"aP":{"y":["1"]},"b8":{"b":[],"P":[],"a2":["P"]},"bz":{"b":[],"O":[],"P":[],"a2":["P"],"aA":[]},"cB":{"b":[],"P":[],"a2":["P"],"aA":[]},"aT":{"e":[],"a2":["e"],"aA":[]},"bg":{"c":["2"]},"bp":{"y":["2"]},"aQ":{"bg":["1","2"],"c":["2"],"c.E":"2"},"c0":{"aQ":["1","2"],"bg":["1","2"],"w":["2"],"c":["2"],"c.E":"2"},"bD":{"A":[]},"w":{"c":["1"]},"m":{"w":["1"],"c":["1"]},"bR":{"m":["1"],"w":["1"],"c":["1"],"m.E":"1","c.E":"1"},"av":{"y":["1"]},"a3":{"c":["2"],"c.E":"2"},"bu":{"a3":["1","2"],"w":["2"],"c":["2"],"c.E":"2"},"bL":{"y":["2"]},"f":{"m":["2"],"w":["2"],"c":["2"],"m.E":"2","c.E":"2"},"x":{"c":["1"],"c.E":"1"},"ad":{"y":["1"]},"bx":{"c":["2"],"c.E":"2"},"by":{"y":["2"]},"ax":{"c":["1"],"c.E":"1"},"b6":{"ax":["1"],"w":["1"],"c":["1"],"c.E":"1"},"bP":{"y":["1"]},"bv":{"w":["1"],"c":["1"],"c.E":"1"},"bw":{"y":["1"]},"bZ":{"c":["1"],"c.E":"1"},"c_":{"y":["1"]},"bi":{"bh":[],"aZ":[]},"bs":{"bW":["1","2"],"bk":["1","2"],"bc":["1","2"],"c8":["1","2"],"u":["1","2"]},"br":{"u":["1","2"]},"ap":{"br":["1","2"],"u":["1","2"]},"cw":{"Q":[],"as":[]},"b7":{"Q":[],"as":[]},"bM":{"A":[]},"cD":{"A":[]},"cN":{"A":[]},"Q":{"as":[]},"cg":{"Q":[],"as":[]},"ch":{"Q":[],"as":[]},"cL":{"Q":[],"as":[]},"cK":{"Q":[],"as":[]},"b5":{"Q":[],"as":[]},"cJ":{"A":[]},"at":{"N":["1","2"],"hp":["1","2"],"u":["1","2"],"N.K":"1","N.V":"2"},"au":{"w":["1"],"c":["1"],"c.E":"1"},"bG":{"y":["1"]},"aa":{"w":["1"],"c":["1"],"c.E":"1"},"bH":{"y":["1"]},"bE":{"w":["J<1,2>"],"c":["J<1,2>"],"c.E":"J<1,2>"},"bF":{"y":["J<1,2>"]},"bh":{"aZ":[]},"cC":{"iW":[]},"cQ":{"A":[]},"bj":{"A":[]},"aC":{"c3":["1"],"aW":["1"],"hr":["1"],"aV":["1"],"w":["1"],"c":["1"]},"aX":{"y":["1"]},"N":{"u":["1","2"]},"bc":{"u":["1","2"]},"bW":{"bk":["1","2"],"bc":["1","2"],"c8":["1","2"],"u":["1","2"]},"eC":{"m":["1"],"w":["1"],"c":["1"],"m.E":"1","c.E":"1"},"c1":{"y":["1"]},"aW":{"aV":["1"],"w":["1"],"c":["1"]},"c3":{"aW":["1"],"aV":["1"],"w":["1"],"c":["1"]},"bX":{"aW":["1"],"cV":["1"],"aV":["1"],"w":["1"],"c":["1"]},"cS":{"N":["e","@"],"u":["e","@"],"N.K":"e","N.V":"@"},"cT":{"m":["e"],"w":["e"],"c":["e"],"m.E":"e","c.E":"e"},"bC":{"A":[]},"cE":{"A":[]},"ag":{"a2":["ag"]},"b":{"P":[],"a2":["P"]},"R":{"a2":["R"]},"O":{"P":[],"a2":["P"]},"r":{"w":["1"],"c":["1"]},"P":{"a2":["P"]},"aV":{"w":["1"],"c":["1"]},"e":{"a2":["e"]},"ce":{"A":[]},"bV":{"A":[]},"am":{"A":[]},"bN":{"A":[]},"cv":{"A":[]},"bY":{"A":[]},"bd":{"A":[]},"cl":{"A":[]},"cF":{"A":[]},"bQ":{"A":[]},"be":{"j_":[]},"D":{"C":[]}}'))
A.jh(v.typeUniverse,JSON.parse('{"c9":1,"ci":2,"cm":2}'))
var u={c:"At least two canonical telemetry points are required."}
var t=(function rtii(){var s=A.aE
return{E:s("z"),eS:s("z(D)"),u:s("K"),fI:s("K(ae)"),e8:s("a2<@>"),v:s("af"),dy:s("ag"),D:s("aF"),R:s("H"),F:s("p"),fR:s("ah"),gE:s("ar"),f:s("a9"),am:s("ai"),fu:s("R"),U:s("w<@>"),bU:s("A"),V:s("X"),c5:s("aG"),Z:s("as"),bZ:s("c<z>"),t:s("c<K>"),ff:s("c<H>"),bM:s("c<b>"),hf:s("c<@>"),x:s("l<z>"),A:s("l<cj>"),df:s("l<af>"),h:s("l<p>"),G:s("l<ar>"),c:s("l<a9>"),b:s("l<r<b>>"),d:s("l<aI>"),r:s("l<Y>"),aa:s("l<U>"),s:s("l<e>"),J:s("l<a5>"),gI:s("l<az>"),h9:s("l<ak>"),O:s("l<C>"),du:s("l<ae>"),cA:s("l<c2>"),dO:s("l<a6>"),M:s("l<D>"),aS:s("l<aM>"),n:s("l<b>"),gn:s("l<@>"),T:s("bA"),p:s("b9"),cj:s("bB"),h2:s("r<z>"),an:s("r<K>"),B:s("r<p>"),e2:s("r<ah>"),au:s("r<ar>"),gj:s("r<r<b>>"),fB:s("r<aI>"),f8:s("r<Z>"),dg:s("r<e>"),X:s("r<a5>"),dr:s("r<az>"),fV:s("r<aK>"),cT:s("r<ak>"),W:s("r<C>"),fT:s("r<c2>"),e:s("r<a6>"),fd:s("r<D>"),ap:s("r<aM>"),ej:s("r<a_>"),q:s("r<b>"),j:s("r<@>"),l:s("aI"),m:s("Y"),ct:s("J<e,u<e,n>>"),cC:s("u<e,H>"),h6:s("u<e,n>"),P:s("u<e,@>"),eO:s("u<@,@>"),aq:s("a3<D,z>"),gM:s("f<ae,K>"),cX:s("Z"),o:s("U"),a:s("aU"),K:s("n"),gT:s("ks"),bQ:s("+()"),fj:s("aV<X>"),cq:s("aV<e>"),N:s("e"),C:s("a5"),fo:s("az"),dm:s("aA"),ak:s("aJ"),f4:s("bX<X>"),dA:s("x<a9>"),a3:s("x<D>"),e5:s("bZ<a_>"),bI:s("aK"),k:s("ak"),w:s("C"),ei:s("ae"),Q:s("a6"),d4:s("al"),g:s("D"),fz:s("aM"),L:s("a_"),y:s("i"),eF:s("i(a9)"),d1:s("i(a5)"),_:s("i(a6)"),bb:s("i(D)"),i:s("b"),bk:s("b(af)"),bE:s("b(p)"),z:s("@"),S:s("O"),dd:s("p?"),eH:s("hk<aU>?"),bX:s("b9?"),gJ:s("r<e>?"),bF:s("r<@>?"),Y:s("n?"),eN:s("aV<X>?"),dk:s("e?"),br:s("cU?"),fQ:s("i?"),cD:s("b?"),I:s("O?"),cg:s("P?"),H:s("P"),fH:s("~(e,@)")}})();(function constants(){var s=hunkHelpers.makeConstList
B.ay=J.cy.prototype
B.a=J.l.prototype
B.c=J.bz.prototype
B.b=J.b8.prototype
B.e=J.aT.prototype
B.az=J.ba.prototype
B.V=new A.b7(A.kh(),A.aE("b7<b>"))
B.W=new A.d_()
B.X=new A.dg()
B.k=new A.dz()
B.Z=new A.dR()
B.a_=new A.cq()
B.a7=new A.eL()
B.Y=new A.co()
B.a1=new A.ej()
B.a8=new A.eM()
B.a2=new A.en()
B.a0=new A.eg()
B.y=new A.ee()
B.x=new A.dy()
B.z=new A.bw(A.aE("bw<0&>"))
B.a3=new A.cx()
B.a4=new A.et()
B.a5=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.f=new A.ex()
B.a6=new A.cF()
B.d=new A.eJ()
B.a9=new A.cO()
B.A=new A.an(0,"firstWins")
B.B=new A.an(1,"secondWins")
B.C=new A.an(2,"noMeaningfulDifference")
B.aa=new A.an(3,"notEligible")
B.D=new A.an(4,"insufficientTelemetry")
B.ab=new A.an(5,"mappingFailed")
B.ac=new A.an(7,"calculationFailed")
B.n=new A.bq(0,"success")
B.h=new A.bq(1,"mappingFailed")
B.E=new A.bq(2,"insufficientTelemetry")
B.o=new A.ed(0,"v1")
B.F=new A.bt(0,"actual")
B.ad=new A.bt(1,"neutralNotApplicable")
B.ae=new A.bt(2,"neutralInsufficient")
B.G=new A.aR(0,"stop")
B.l=new A.aR(1,"acceleration")
B.p=new A.aR(2,"deceleration")
B.j=new A.aR(3,"corner")
B.m=new A.aR(4,"cruise")
B.H=new A.ah(0,"unknown")
B.I=new A.ah(1,"stopped")
B.af=new A.ah(2,"accelerating")
B.ag=new A.ah(3,"cruising")
B.ah=new A.ah(4,"decelerating")
B.ai=new A.ah(5,"cornering")
B.q=new A.ai(0,"cruiseDecelCruise")
B.r=new A.ai(1,"cruiseCornerCruise")
B.t=new A.ai(2,"accelerationCruise")
B.aj=new A.R(0)
B.ak=new A.R(12e7)
B.J=new A.R(15e5)
B.al=new A.R(2e6)
B.am=new A.R(3e6)
B.an=new A.R(3e8)
B.ao=new A.R(5e6)
B.ap=new A.R(8e6)
B.aq=new A.X(0,"stopped")
B.ar=new A.X(1,"accelerating")
B.as=new A.X(2,"cruising")
B.at=new A.X(3,"decelerating")
B.u=new A.X(4,"cornering")
B.au=new A.X(5,"freeFlow")
B.av=new A.X(6,"denseTraffic")
B.aw=new A.X(7,"stopAndGo")
B.ax=new A.aG(0,"stopping")
B.v=new A.aG(1,"acceleration")
B.K=new A.aG(2,"braking")
B.L=new A.aG(3,"cornering")
B.M=new A.aG(4,"cruising")
B.aA=new A.ey(null)
B.aB=new A.ez(null)
B.w=s([0,0],t.n)
B.aH=s([20,0.25],t.n)
B.aN=s([50,0.58],t.n)
B.aM=s([80,0.83],t.n)
B.aC=s([120,1],t.n)
B.aF=s([B.w,B.aH,B.aN,B.aM,B.aC],t.b)
B.aG=s([30,0.25],t.n)
B.aI=s([60,0.58],t.n)
B.aR=s([100,0.83],t.n)
B.aD=s([150,1],t.n)
B.aJ=s([B.w,B.aG,B.aI,B.aR,B.aD],t.b)
B.i=s([],A.aE("l<K>"))
B.aP=s([],t.h)
B.aO=s([],t.G)
B.P=s([],t.d)
B.Q=s([],t.r)
B.O=s([],t.s)
B.N=s([],t.J)
B.R=s([],t.O)
B.aL=s([80,0.33],t.n)
B.aK=s([140,0.67],t.n)
B.aE=s([200,1],t.n)
B.aQ=s([B.w,B.aL,B.aK,B.aE],t.b)
B.aS=s([B.q,B.r,B.t],A.aE("l<ai>"))
B.aT=new A.bJ(0,"success")
B.aU=new A.bJ(1,"notEligible")
B.aV=new A.bJ(2,"insufficientConfidence")
B.aW=new A.bb(0,"existingBetter")
B.S=new A.bb(1,"challengerBetter")
B.aX=new A.bb(2,"noMeaningfulDifference")
B.T=new A.bb(3,"invalid")
B.U={}
B.b7=new A.ap(B.U,[],A.aE("ap<e,b>"))
B.aY=new A.bi([0,0,0,0])
B.aZ=new A.bT(!1)
B.b0=new A.bf(0,"unknown")
B.b_=new A.az(B.b0,0,0)
B.b1=new A.bf(1,"freeFlow")
B.b2=new A.bf(2,"denseTraffic")
B.b3=new A.bf(3,"stopAndGo")
B.b8=new A.ap(B.U,[],A.aE("ap<ai,O>"))
B.b6=s([],t.c)
B.b4=new A.cM(0,!1,!1)
B.b5=A.kn("n")})();(function staticFields(){$.a7=A.j([],A.aE("l<n>"))
$.hv=null
$.hb=null
$.ha=null
$.fk=A.j([],A.aE("l<r<n>?>"))})();(function lazyInitializers(){var s=hunkHelpers.lazyFinal
s($,"kq","ig",()=>A.i8("_$dart_dartClosure"))
s($,"kp","h6",()=>A.i8("_$dart_dartClosure_dartJSInterop"))
s($,"kE","it",()=>A.j([new J.cz()],A.aE("l<bO>")))
s($,"kt","ii",()=>A.aB(A.eW({
toString:function(){return"$receiver$"}})))
s($,"ku","ij",()=>A.aB(A.eW({$method$:null,
toString:function(){return"$receiver$"}})))
s($,"kv","ik",()=>A.aB(A.eW(null)))
s($,"kw","il",()=>A.aB(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"kz","ip",()=>A.aB(A.eW(void 0)))
s($,"kA","iq",()=>A.aB(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"ky","io",()=>A.aB(A.hI(null)))
s($,"kx","im",()=>A.aB(function(){try{null.$method$}catch(r){return r.message}}()))
s($,"kC","is",()=>A.aB(A.hI(void 0)))
s($,"kB","ir",()=>A.aB(function(){try{(void 0).$method$}catch(r){return r.message}}()))
s($,"kr","ih",()=>A.iX("^([+-]?\\d{4,6})-?(\\d\\d)-?(\\d\\d)(?:[ T](\\d\\d)(?::?(\\d\\d)(?::?(\\d\\d)(?:[.,](\\d+))?)?)?( ?[zZ]| ?([-+])(\\d\\d)(?::?(\\d\\d))?)?)?$"))
s($,"kD","cZ",()=>A.ib(B.b5))})();(function nativeSupport(){!function(){var s=function(a){var m={}
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
var s=A.kg
if(typeof dartMainRunner==="function"){dartMainRunner(s,[])}else{s([])}})})()
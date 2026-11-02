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
if(a[b]!==s){A.jI(b)}a[b]=r}var q=a[b]
a[c]=function(){return q}
return q}}function makeConstList(a,b){if(b!=null)A.o(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var s=0;s<a.length;++s){convertToFastObject(a[s])}}var y=0
function instanceTearOffGetter(a,b){var s=null
return a?function(c){if(s===null)s=A.fq(b)
return new s(c,this)}:function(){if(s===null)s=A.fq(b)
return new s(this,null)}}function staticTearOffGetter(a){var s=null
return function(){if(s===null)s=A.fq(a).prototype
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
fL(a,b){if(a<0||a>4294967295)throw A.d(A.aa(a,0,4294967295,"length",null))
return J.ef(new Array(a),b)},
ef(a,b){var s=A.o(a,b.h("m<0>"))
s.$flags=1
return s},
ia(a,b){var s=t.e8
return J.hT(s.a(a),s.a(b))},
aQ(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.bm.prototype
return J.co.prototype}if(typeof a=="string")return J.aJ.prototype
if(a==null)return J.bn.prototype
if(typeof a=="boolean")return J.cn.prototype
if(Array.isArray(a))return J.m.prototype
if(typeof a=="function")return J.bo.prototype
if(typeof a=="object"){if(a instanceof A.j){return a}else{return J.b_.prototype}}if(!(a instanceof A.j))return J.aA.prototype
return a},
bW(a){if(a==null)return a
if(Array.isArray(a))return J.m.prototype
if(!(a instanceof A.j))return J.aA.prototype
return a},
bX(a){if(typeof a=="string")return J.aJ.prototype
if(a==null)return a
if(Array.isArray(a))return J.m.prototype
if(!(a instanceof A.j))return J.aA.prototype
return a},
jz(a){if(typeof a=="number")return J.aY.prototype
if(typeof a=="string")return J.aJ.prototype
if(a==null)return a
if(!(a instanceof A.j))return J.aA.prototype
return a},
cK(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.aQ(a).M(a,b)},
hS(a,b){if(typeof b==="number")if(Array.isArray(a)||typeof a=="string")if(b>>>0===b&&b<a.length)return a[b]
return J.bX(a).i(a,b)},
hT(a,b){return J.jz(a).E(a,b)},
fv(a,b){return J.bW(a).C(a,b)},
ba(a){return J.aQ(a).gB(a)},
fw(a){return J.bX(a).gv(a)},
hU(a){return J.bW(a).gX(a)},
a4(a){return J.bW(a).gq(a)},
aF(a){return J.bX(a).gm(a)},
hV(a){return J.aQ(a).gT(a)},
cL(a,b,c){return J.bW(a).aS(a,b,c)},
fx(a,b){return J.bW(a).L(a,b)},
aT(a){return J.aQ(a).k(a)},
cl:function cl(){},
cn:function cn(){},
bn:function bn(){},
b_:function b_(){},
ax:function ax(){},
es:function es(){},
aA:function aA(){},
bo:function bo(){},
m:function m(a){this.$ti=a},
cm:function cm(){},
eg:function eg(a){this.$ti=a},
aG:function aG(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aY:function aY(){},
bm:function bm(){},
co:function co(){},
aJ:function aJ(){}},A={ff:function ff(){},
fC(a,b,c){if(t.O.b(a))return new A.bN(a,b.h("@<0>").u(c).h("bN<1,2>"))
return new A.aH(a,b.h("@<0>").u(c).h("aH<1,2>"))},
ic(a){return new A.bq("Field '"+a+"' has not been initialized.")},
h4(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
ir(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
ht(a,b,c){return a},
fs(a){var s,r
for(s=$.V.length,r=0;r<s;++r)if(a===$.V[r])return!0
return!1},
eu(a,b,c,d){A.ao(b,"start")
if(c!=null){A.ao(c,"end")
if(b>c)A.aE(A.aa(b,0,c,"start",null))}return new A.bG(a,b,c,d.h("bG<0>"))},
ii(a,b,c,d){if(t.O.b(a))return new A.bh(a,b,c.h("@<0>").u(d).h("bh<1,2>"))
return new A.an(a,b,c.h("@<0>").u(d).h("an<1,2>"))},
h2(a,b,c){var s="count"
if(t.O.b(a)){A.cZ(b,s,t.S)
A.ao(b,s)
return new A.aV(a,b,c.h("aV<0>"))}A.cZ(b,s,t.S)
A.ao(b,s)
return new A.ap(a,b,c.h("ap<0>"))},
aX(){return new A.b2("No element")},
i8(){return new A.b2("Too few elements")},
b5:function b5(){},
bb:function bb(a,b){this.a=a
this.$ti=b},
aH:function aH(a,b){this.a=a
this.$ti=b},
bN:function bN(a,b){this.a=a
this.$ti=b},
bq:function bq(a){this.a=a},
et:function et(){},
p:function p(){},
q:function q(){},
bG:function bG(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
bv:function bv(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
an:function an(a,b,c){this.a=a
this.b=b
this.$ti=c},
bh:function bh(a,b,c){this.a=a
this.b=b
this.$ti=c},
bA:function bA(a,b,c){var _=this
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
a2:function a2(a,b,c){this.a=a
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
ap:function ap(a,b,c){this.a=a
this.b=b
this.$ti=c},
aV:function aV(a,b,c){this.a=a
this.b=b
this.$ti=c},
bE:function bE(a,b,c){this.a=a
this.b=b
this.$ti=c},
bi:function bi(a){this.$ti=a},
bj:function bj(a){this.$ti=a},
fE(a,b,c){var s,r,q,p,o,n,m,l=A.i(a),k=A.fh(new A.ak(a,l.h("ak<1>")),!0,b),j=k.length,i=0
for(;;){if(!(i<j)){s=!0
break}r=k[i]
if(typeof r!="string"||"__proto__"===r){s=!1
break}++i}if(s){q={}
for(p=0,i=0;i<k.length;k.length===j||(0,A.Y)(k),++i,p=o){r=k[i]
c.a(a.i(0,r))
o=p+1
q[r]=p}n=A.fh(new A.al(a,l.h("al<2>")),!0,c)
m=new A.R(q,n,b.h("@<0>").u(c).h("R<1,2>"))
m.$keys=k
return m}return new A.be(A.id(a,b,c),b.h("@<0>").u(c).h("be<1,2>"))},
hD(a){var s=v.mangledGlobalNames[a]
if(s!=null)return s
return"minified:"+a},
x(a){var s
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
s=J.aT(a)
return s},
cu(a){var s,r=$.fT
if(r==null)r=$.fT=Symbol("identityHashCode")
s=a[r]
if(s==null){s=Math.random()*0x3fffffff|0
a[r]=s}return s},
ij(a,b){var s,r=/^\s*[+-]?((0x[a-f0-9]+)|(\d+)|([a-z0-9]+))\s*$/i.exec(a)
if(r==null)return null
if(3>=r.length)return A.a(r,3)
s=r[3]
if(s!=null)return parseInt(a,10)
if(r[2]!=null)return parseInt(a,16)
return null},
cv(a){var s,r,q,p
if(a instanceof A.j)return A.M(A.bY(a),null)
s=J.aQ(a)
if(s===B.au||s===B.av||t.ak.b(a)){r=B.a2(a)
if(r!=="Object"&&r!=="")return r
q=a.constructor
if(typeof q=="function"){p=q.name
if(typeof p=="string"&&p!=="Object"&&p!=="")return p}}return A.M(A.bY(a),null)},
ik(a){var s,r,q
if(typeof a=="number"||A.fp(a))return J.aT(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.K)return a.k(0)
s=$.hR()
for(r=0;r<1;++r){q=s[r].c7(a)
if(q!=null)return q}return"Instance of '"+A.cv(a)+"'"},
H(a){var s
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){s=a-65536
return String.fromCharCode((B.c.aJ(s,10)|55296)>>>0,s&1023|56320)}throw A.d(A.aa(a,0,1114111,null,null))},
h_(a,b,c,d,e,f,g,h,i){var s,r,q,p=b-1
if(0<=a&&a<100){a+=400
p-=4800}s=B.c.U(h,1000)
g+=B.c.A(h-s,1000)
r=i?Date.UTC(a,p,c,d,e,f,g):new Date(a,p,c,d,e,f,g).valueOf()
q=!0
if(!isNaN(r))if(!(r<-864e13))if(!(r>864e13))q=r===864e13&&s!==0
if(q)return null
return r},
S(a){if(a.date===void 0)a.date=new Date(a.a)
return a.date},
ct(a){return a.c?A.S(a).getUTCFullYear()+0:A.S(a).getFullYear()+0},
fY(a){return a.c?A.S(a).getUTCMonth()+1:A.S(a).getMonth()+1},
fU(a){return a.c?A.S(a).getUTCDate()+0:A.S(a).getDate()+0},
fV(a){return a.c?A.S(a).getUTCHours()+0:A.S(a).getHours()+0},
fX(a){return a.c?A.S(a).getUTCMinutes()+0:A.S(a).getMinutes()+0},
fZ(a){return a.c?A.S(a).getUTCSeconds()+0:A.S(a).getSeconds()+0},
fW(a){return a.c?A.S(a).getUTCMilliseconds()+0:A.S(a).getMilliseconds()+0},
jC(a){throw A.d(A.hs(a))},
a(a,b){if(a==null)J.aF(a)
throw A.d(A.f2(a,b))},
f2(a,b){var s,r="index",q=null
if(!A.ho(b))return new A.ac(!0,b,r,q)
s=A.X(J.aF(a))
if(b<0||b>=s)return A.ed(b,s,a,q,r)
return new A.bC(q,q,!0,b,r,"Value not in range")},
hs(a){return new A.ac(!0,a,null,null)},
d(a){return A.E(a,new Error())},
E(a,b){var s
if(a==null)a=new A.bJ()
b.dartException=a
s=A.jJ
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:s})
b.name=""}else b.toString=s
return b},
jJ(){return J.aT(this.dartException)},
aE(a,b){throw A.E(a,b==null?new Error():b)},
cJ(a,b,c){var s
if(b==null)b=0
if(c==null)c=0
s=Error()
A.aE(A.iW(a,b,c),s)},
iW(a,b,c){var s,r,q,p,o,n,m,l,k
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
return new A.bM("'"+s+"': Cannot "+o+" "+l+k+n)},
Y(a){throw A.d(A.O(a))},
as(a){var s,r,q,p,o,n
a=A.jH(a.replace(String({}),"$receiver$"))
s=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(s==null)s=A.o([],t.s)
r=s.indexOf("\\$arguments\\$")
q=s.indexOf("\\$argumentsExpr\\$")
p=s.indexOf("\\$expr\\$")
o=s.indexOf("\\$method\\$")
n=s.indexOf("\\$receiver\\$")
return new A.eG(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),r,q,p,o,n)},
eH(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(s){return s.message}}(a)},
h5(a){return function($expr$){try{$expr$.$method$}catch(s){return s.message}}(a)},
fg(a,b){var s=b==null,r=s?null:b.method
return new A.cq(a,r,s?null:b.receiver)},
ft(a){if(a==null)return new A.er(a)
if(typeof a!=="object")return a
if("dartException" in a)return A.aS(a,a.dartException)
return A.jp(a)},
aS(a,b){if(t.bU.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
jp(a){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(!("message" in a))return a
s=a.message
if("number" in a&&typeof a.number=="number"){r=a.number
q=r&65535
if((B.c.aJ(r,16)&8191)===10)switch(q){case 438:return A.aS(a,A.fg(A.x(s)+" (Error "+q+")",null))
case 445:case 5007:A.x(s)
return A.aS(a,new A.bB())}}if(a instanceof TypeError){p=$.hG()
o=$.hH()
n=$.hI()
m=$.hJ()
l=$.hM()
k=$.hN()
j=$.hL()
$.hK()
i=$.hP()
h=$.hO()
g=p.J(s)
if(g!=null)return A.aS(a,A.fg(A.G(s),g))
else{g=o.J(s)
if(g!=null){g.method="call"
return A.aS(a,A.fg(A.G(s),g))}else if(n.J(s)!=null||m.J(s)!=null||l.J(s)!=null||k.J(s)!=null||j.J(s)!=null||m.J(s)!=null||i.J(s)!=null||h.J(s)!=null){A.G(s)
return A.aS(a,new A.bB())}}return A.aS(a,new A.cB(typeof s=="string"?s:""))}if(a instanceof RangeError){if(typeof s=="string"&&s.indexOf("call stack")!==-1)return new A.bF()
s=function(b){try{return String(b)}catch(f){}return null}(a)
return A.aS(a,new A.ac(!1,null,null,typeof s=="string"?s.replace(/^RangeError:\s*/,""):s))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof s=="string"&&s==="too much recursion")return new A.bF()
return a},
hy(a){if(a==null)return J.ba(a)
if(typeof a=="object")return A.cu(a)
return J.ba(a)},
jx(a,b){var s,r,q,p=a.length
for(s=0;s<p;s=q){r=s+1
q=r+1
b.t(0,a[s],a[r])}return b},
jy(a,b){var s,r=a.length
for(s=0;s<r;++s)b.l(0,a[s])
return b},
j5(a,b,c,d,e,f){t.Z.a(a)
switch(A.X(b)){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.d(new A.eL("Unsupported number of arguments for wrapped closure"))},
js(a,b){var s=a.$identity
if(!!s)return s
s=A.jt(a,b)
a.$identity=s
return s},
jt(a,b){var s
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
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.j5)},
i2(a2){var s,r,q,p,o,n,m,l,k,j,i=a2.co,h=a2.iS,g=a2.iI,f=a2.nDA,e=a2.aI,d=a2.fs,c=a2.cs,b=d[0],a=c[0],a0=i[b],a1=a2.fT
a1.toString
s=h?Object.create(new A.cy().constructor.prototype):Object.create(new A.aU(null,null).constructor.prototype)
s.$initialize=s.constructor
r=h?function static_tear_off(){this.$initialize()}:function tear_off(a3,a4){this.$initialize(a3,a4)}
s.constructor=r
r.prototype=s
s.$_name=b
s.$_target=a0
q=!h
if(q)p=A.fD(b,a0,g,f)
else{s.$static_name=b
p=a0}s.$S=A.hZ(a1,h,g)
s[a]=p
for(o=p,n=1;n<d.length;++n){m=d[n]
if(typeof m=="string"){l=i[m]
k=m
m=l}else k=""
j=c[n]
if(j!=null){if(q)m=A.fD(k,m,g,f)
s[j]=m}if(n===e)o=m}s.$C=o
s.$R=a2.rC
s.$D=a2.dV
return r},
hZ(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.d("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.hX)}throw A.d("Error in functionType of tearoff")},
i_(a,b,c,d){var s=A.fB
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,s)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,s)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,s)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,s)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,s)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,s)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,s)}},
fD(a,b,c,d){if(c)return A.i1(a,b,d)
return A.i_(b.length,d,a,b)},
i0(a,b,c,d){var s=A.fB,r=A.hY
switch(b?-1:a){case 0:throw A.d(new A.cw("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,r,s)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,r,s)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,r,s)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,r,s)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,r,s)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,r,s)
default:return function(e,f,g){return function(){var q=[g(this)]
Array.prototype.push.apply(q,arguments)
return e.apply(f(this),q)}}(d,r,s)}},
i1(a,b,c){var s,r
if($.fz==null)$.fz=A.fy("interceptor")
if($.fA==null)$.fA=A.fy("receiver")
s=b.length
r=A.i0(s,c,a,b)
return r},
fq(a){return A.i2(a)},
hX(a,b){return A.eT(v.typeUniverse,A.bY(a.a),b)},
fB(a){return a.a},
hY(a){return a.b},
fy(a){var s,r,q,p=new A.aU("receiver","interceptor"),o=Object.getOwnPropertyNames(p)
o.$flags=1
s=o
for(o=s.length,r=0;r<o;++r){q=s[r]
if(p[q]===a)return q}throw A.d(A.fd("Field name "+a+" not found."))},
hv(a){return v.getIsolateTag(a)},
jv(a,b){var s=b.length,r=v.rttc[""+s+";"+a]
if(r==null)return null
if(s===0)return r
if(s===r.length)return r.apply(null,b)
return r(b)},
ib(a,b,c,d,e,f){var s=function(g,h){try{return new RegExp(g,h)}catch(r){return r}}(a,""+""+""+""+f)
if(s instanceof RegExp)return s
throw A.d(A.ch("Illegal RegExp pattern ("+String(s)+")",a))},
jH(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
be:function be(a,b){this.a=a
this.$ti=b},
bd:function bd(){},
dq:function dq(a,b,c){this.a=a
this.b=b
this.c=c},
R:function R(a,b,c){this.a=a
this.b=b
this.$ti=c},
cj:function cj(){},
aW:function aW(a,b){this.a=a
this.$ti=b},
bD:function bD(){},
eG:function eG(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
bB:function bB(){},
cq:function cq(a,b,c){this.a=a
this.b=b
this.c=c},
cB:function cB(a){this.a=a},
er:function er(a){this.a=a},
K:function K(){},
c1:function c1(){},
c2:function c2(){},
cz:function cz(){},
cy:function cy(){},
aU:function aU(a,b){this.a=a
this.b=b},
cw:function cw(a){this.a=a},
aj:function aj(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
eh:function eh(a){this.a=a},
el:function el(a,b){this.a=a
this.b=b
this.c=null},
ak:function ak(a,b){this.a=a
this.$ti=b},
bt:function bt(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
al:function al(a,b){this.a=a
this.$ti=b},
bu:function bu(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
br:function br(a,b){this.a=a
this.$ti=b},
bs:function bs(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
cp:function cp(a,b){this.a=a
this.b=b},
eQ:function eQ(a){this.b=a},
fi(a,b){var s=b.c
return s==null?b.c=A.bS(a,"fJ",[b.x]):s},
h1(a){var s=a.w
if(s===6||s===7)return A.h1(a.x)
return s===11||s===12},
io(a){return a.as},
av(a){return A.eS(v.typeUniverse,a,!1)},
jE(a,b){var s,r,q,p,o
if(a==null)return null
s=b.y
r=a.Q
if(r==null)r=a.Q=new Map()
q=b.as
p=r.get(q)
if(p!=null)return p
o=A.aD(v.typeUniverse,a.x,s,0)
r.set(q,o)
return o},
aD(a1,a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=a2.w
switch(a0){case 5:case 1:case 2:case 3:case 4:return a2
case 6:s=a2.x
r=A.aD(a1,s,a3,a4)
if(r===s)return a2
return A.he(a1,r,!0)
case 7:s=a2.x
r=A.aD(a1,s,a3,a4)
if(r===s)return a2
return A.hd(a1,r,!0)
case 8:q=a2.y
p=A.b8(a1,q,a3,a4)
if(p===q)return a2
return A.bS(a1,a2.x,p)
case 9:o=a2.x
n=A.aD(a1,o,a3,a4)
m=a2.y
l=A.b8(a1,m,a3,a4)
if(n===o&&l===m)return a2
return A.fm(a1,n,l)
case 10:k=a2.x
j=a2.y
i=A.b8(a1,j,a3,a4)
if(i===j)return a2
return A.hf(a1,k,i)
case 11:h=a2.x
g=A.aD(a1,h,a3,a4)
f=a2.y
e=A.jm(a1,f,a3,a4)
if(g===h&&e===f)return a2
return A.hc(a1,g,e)
case 12:d=a2.y
a4+=d.length
c=A.b8(a1,d,a3,a4)
o=a2.x
n=A.aD(a1,o,a3,a4)
if(c===d&&n===o)return a2
return A.fn(a1,n,c,!0)
case 13:b=a2.x
if(b<a4)return a2
a=a3[b-a4]
if(a==null)return a2
return a
default:throw A.d(A.c0("Attempted to substitute unexpected RTI kind "+a0))}},
b8(a,b,c,d){var s,r,q,p,o=b.length,n=A.eU(o)
for(s=!1,r=0;r<o;++r){q=b[r]
p=A.aD(a,q,c,d)
if(p!==q)s=!0
n[r]=p}return s?n:b},
jn(a,b,c,d){var s,r,q,p,o,n,m=b.length,l=A.eU(m)
for(s=!1,r=0;r<m;r+=3){q=b[r]
p=b[r+1]
o=b[r+2]
n=A.aD(a,o,c,d)
if(n!==o)s=!0
l.splice(r,3,q,p,n)}return s?l:b},
jm(a,b,c,d){var s,r=b.a,q=A.b8(a,r,c,d),p=b.b,o=A.b8(a,p,c,d),n=b.c,m=A.jn(a,n,c,d)
if(q===r&&o===p&&m===n)return b
s=new A.cD()
s.a=q
s.b=o
s.c=m
return s},
o(a,b){a[v.arrayRti]=b
return a},
f0(a){var s=a.$S
if(s!=null){if(typeof s=="number")return A.jB(s)
return a.$S()}return null},
jD(a,b){var s
if(A.h1(b))if(a instanceof A.K){s=A.f0(a)
if(s!=null)return s}return A.bY(a)},
bY(a){if(a instanceof A.j)return A.i(a)
if(Array.isArray(a))return A.h(a)
return A.fo(J.aQ(a))},
h(a){var s=a[v.arrayRti],r=t.gn
if(s==null)return r
if(s.constructor!==r.constructor)return r
return s},
i(a){var s=a.$ti
return s!=null?s:A.fo(a)},
fo(a){var s=a.constructor,r=s.$ccache
if(r!=null)return r
return A.j3(a,s)},
j3(a,b){var s=a instanceof A.K?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,r=A.iL(v.typeUniverse,s.name)
b.$ccache=r
return r},
jB(a){var s,r=v.types,q=r[a]
if(typeof q=="string"){s=A.eS(v.typeUniverse,q,!1)
r[a]=s
return s}return q},
jA(a){return A.au(A.i(a))},
fr(a){var s=A.f0(a)
return A.au(s==null?A.bY(a):s)},
jl(a){var s=a instanceof A.K?A.f0(a):null
if(s!=null)return s
if(t.dm.b(a))return J.hV(a).a
if(Array.isArray(a))return A.h(a)
return A.bY(a)},
au(a){var s=a.r
return s==null?a.r=new A.eR(a):s},
jK(a){return A.au(A.eS(v.typeUniverse,a,!1))},
j2(a){var s=this
s.b=A.jk(s)
return s.b(a)},
jk(a){var s,r,q,p,o
if(a===t.C)return A.jb
if(A.aR(a))return A.jf
s=a.w
if(s===6)return A.j_
if(s===1)return A.hq
if(s===7)return A.j6
r=A.jj(a)
if(r!=null)return r
if(s===8){q=a.x
if(a.y.every(A.aR)){a.f="$i"+q
if(q==="v")return A.j9
if(a===t.m)return A.j8
return A.je}}else if(s===10){p=A.jv(a.x,a.y)
o=p==null?A.hq:p
return o==null?A.hj(o):o}return A.iY},
jj(a){if(a.w===8){if(a===t.S)return A.ho
if(a===t.i||a===t.H)return A.ja
if(a===t.N)return A.jd
if(a===t.y)return A.fp}return null},
j1(a){var s=this,r=A.iX
if(A.aR(s))r=A.iT
else if(s===t.C)r=A.hj
else if(A.b9(s)){r=A.iZ
if(s===t.I)r=A.iQ
else if(s===t.dk)r=A.hk
else if(s===t.fQ)r=A.iO
else if(s===t.cg)r=A.hi
else if(s===t.cD)r=A.iP
else if(s===t.an)r=A.iS}else if(s===t.S)r=A.X
else if(s===t.N)r=A.G
else if(s===t.y)r=A.eX
else if(s===t.H)r=A.t
else if(s===t.i)r=A.n
else if(s===t.m)r=A.iR
s.a=r
return s.a(a)},
iY(a){var s=this
if(a==null)return A.b9(s)
return A.hw(v.typeUniverse,A.jD(a,s),s)},
j_(a){if(a==null)return!0
return this.x.b(a)},
je(a){var s,r=this
if(a==null)return A.b9(r)
s=r.f
if(a instanceof A.j)return!!a[s]
return!!J.aQ(a)[s]},
j9(a){var s,r=this
if(a==null)return A.b9(r)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
s=r.f
if(a instanceof A.j)return!!a[s]
return!!J.aQ(a)[s]},
j8(a){var s=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.j)return!!a[s.f]
return!0}if(typeof a=="function")return!0
return!1},
hp(a){if(typeof a=="object"){if(a instanceof A.j)return t.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
iX(a){var s=this
if(a==null){if(A.b9(s))return a}else if(s.b(a))return a
throw A.E(A.hl(a,s),new Error())},
iZ(a){var s=this
if(a==null||s.b(a))return a
throw A.E(A.hl(a,s),new Error())},
hl(a,b){return new A.b6("TypeError: "+A.h6(a,A.M(b,null)))},
jr(a,b,c,d){if(A.hw(v.typeUniverse,a,b))return a
throw A.E(A.iC("The type argument '"+A.M(a,null)+"' is not a subtype of the type variable bound '"+A.M(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
h6(a,b){return A.cg(a)+": type '"+A.M(A.jl(a),null)+"' is not a subtype of type '"+b+"'"},
iC(a){return new A.b6("TypeError: "+a)},
W(a,b){return new A.b6("TypeError: "+A.h6(a,b))},
j6(a){var s=this
return s.x.b(a)||A.fi(v.typeUniverse,s).b(a)},
jb(a){return a!=null},
hj(a){if(a!=null)return a
throw A.E(A.W(a,"Object"),new Error())},
jf(a){return!0},
iT(a){return a},
hq(a){return!1},
fp(a){return!0===a||!1===a},
eX(a){if(!0===a)return!0
if(!1===a)return!1
throw A.E(A.W(a,"bool"),new Error())},
iO(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.E(A.W(a,"bool?"),new Error())},
n(a){if(typeof a=="number")return a
throw A.E(A.W(a,"double"),new Error())},
iP(a){if(typeof a=="number")return a
if(a==null)return a
throw A.E(A.W(a,"double?"),new Error())},
ho(a){return typeof a=="number"&&Math.floor(a)===a},
X(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.E(A.W(a,"int"),new Error())},
iQ(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.E(A.W(a,"int?"),new Error())},
ja(a){return typeof a=="number"},
t(a){if(typeof a=="number")return a
throw A.E(A.W(a,"num"),new Error())},
hi(a){if(typeof a=="number")return a
if(a==null)return a
throw A.E(A.W(a,"num?"),new Error())},
jd(a){return typeof a=="string"},
G(a){if(typeof a=="string")return a
throw A.E(A.W(a,"String"),new Error())},
hk(a){if(typeof a=="string")return a
if(a==null)return a
throw A.E(A.W(a,"String?"),new Error())},
iR(a){if(A.hp(a))return a
throw A.E(A.W(a,"JSObject"),new Error())},
iS(a){if(a==null)return a
if(A.hp(a))return a
throw A.E(A.W(a,"JSObject?"),new Error())},
hr(a,b){var s,r,q
for(s="",r="",q=0;q<a.length;++q,r=", ")s+=r+A.M(a[q],b)
return s},
ji(a,b){var s,r,q,p,o,n,m=a.x,l=a.y
if(""===m)return"("+A.hr(l,b)+")"
s=l.length
r=m.split(",")
q=r.length-s
for(p="(",o="",n=0;n<s;++n,o=", "){p+=o
if(q===0)p+="{"
p+=A.M(l[n],b)
if(q>=0)p+=" "+r[q];++q}return p+"})"},
hm(a3,a4,a5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=", ",a2=null
if(a5!=null){s=a5.length
if(a4==null)a4=A.o([],t.s)
else a2=a4.length
r=a4.length
for(q=s;q>0;--q)B.a.l(a4,"T"+(r+q))
for(p=t.U,o="<",n="",q=0;q<s;++q,n=a1){m=a4.length
l=m-1-q
if(!(l>=0))return A.a(a4,l)
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
if(l===8){p=A.jo(a.x)
o=a.y
return o.length>0?p+("<"+A.hr(o,b)+">"):p}if(l===10)return A.ji(a,b)
if(l===11)return A.hm(a,b,null)
if(l===12)return A.hm(a.x,b,a.y)
if(l===13){n=a.x
m=b.length
n=m-1-n
if(!(n>=0&&n<m))return A.a(b,n)
return b[n]}return"?"},
jo(a){var s=v.mangledGlobalNames[a]
if(s!=null)return s
return"minified:"+a},
iM(a,b){var s=a.tR[b]
while(typeof s=="string")s=a.tR[s]
return s},
iL(a,b){var s,r,q,p,o,n=a.eT,m=n[b]
if(m==null)return A.eS(a,b,!1)
else if(typeof m=="number"){s=m
r=A.bT(a,5,"#")
q=A.eU(s)
for(p=0;p<s;++p)q[p]=r
o=A.bS(a,b,q)
n[b]=o
return o}else return m},
iJ(a,b){return A.hg(a.tR,b)},
iI(a,b){return A.hg(a.eT,b)},
eS(a,b,c){var s,r=a.eC,q=r.get(b)
if(q!=null)return q
s=A.ha(A.h8(a,null,b,!1))
r.set(b,s)
return s},
eT(a,b,c){var s,r,q=b.z
if(q==null)q=b.z=new Map()
s=q.get(c)
if(s!=null)return s
r=A.ha(A.h8(a,b,c,!0))
q.set(c,r)
return r},
iK(a,b,c){var s,r,q,p=b.Q
if(p==null)p=b.Q=new Map()
s=c.as
r=p.get(s)
if(r!=null)return r
q=A.fm(a,b,c.w===9?c.y:[c])
p.set(s,q)
return q},
aB(a,b){b.a=A.j1
b.b=A.j2
return b},
bT(a,b,c){var s,r,q=a.eC.get(c)
if(q!=null)return q
s=new A.a1(null,null)
s.w=b
s.as=c
r=A.aB(a,s)
a.eC.set(c,r)
return r},
he(a,b,c){var s,r=b.as+"?",q=a.eC.get(r)
if(q!=null)return q
s=A.iG(a,b,r,c)
a.eC.set(r,s)
return s},
iG(a,b,c,d){var s,r,q
if(d){s=b.w
r=!0
if(!A.aR(b))if(!(b===t.a||b===t.T))if(s!==6)r=s===7&&A.b9(b.x)
if(r)return b
else if(s===1)return t.a}q=new A.a1(null,null)
q.w=6
q.x=b
q.as=c
return A.aB(a,q)},
hd(a,b,c){var s,r=b.as+"/",q=a.eC.get(r)
if(q!=null)return q
s=A.iE(a,b,r,c)
a.eC.set(r,s)
return s},
iE(a,b,c,d){var s,r
if(d){s=b.w
if(A.aR(b)||b===t.C)return b
else if(s===1)return A.bS(a,"fJ",[b])
else if(b===t.a||b===t.T)return t.eH}r=new A.a1(null,null)
r.w=7
r.x=b
r.as=c
return A.aB(a,r)},
iH(a,b){var s,r,q=""+b+"^",p=a.eC.get(q)
if(p!=null)return p
s=new A.a1(null,null)
s.w=13
s.x=b
s.as=q
r=A.aB(a,s)
a.eC.set(q,r)
return r},
bR(a){var s,r,q,p=a.length
for(s="",r="",q=0;q<p;++q,r=",")s+=r+a[q].as
return s},
iD(a){var s,r,q,p,o,n=a.length
for(s="",r="",q=0;q<n;q+=3,r=","){p=a[q]
o=a[q+1]?"!":":"
s+=r+p+o+a[q+2].as}return s},
bS(a,b,c){var s,r,q,p=b
if(c.length>0)p+="<"+A.bR(c)+">"
s=a.eC.get(p)
if(s!=null)return s
r=new A.a1(null,null)
r.w=8
r.x=b
r.y=c
if(c.length>0)r.c=c[0]
r.as=p
q=A.aB(a,r)
a.eC.set(p,q)
return q},
fm(a,b,c){var s,r,q,p,o,n
if(b.w===9){s=b.x
r=b.y.concat(c)}else{r=c
s=b}q=s.as+(";<"+A.bR(r)+">")
p=a.eC.get(q)
if(p!=null)return p
o=new A.a1(null,null)
o.w=9
o.x=s
o.y=r
o.as=q
n=A.aB(a,o)
a.eC.set(q,n)
return n},
hf(a,b,c){var s,r,q="+"+(b+"("+A.bR(c)+")"),p=a.eC.get(q)
if(p!=null)return p
s=new A.a1(null,null)
s.w=10
s.x=b
s.y=c
s.as=q
r=A.aB(a,s)
a.eC.set(q,r)
return r},
hc(a,b,c){var s,r,q,p,o,n=b.as,m=c.a,l=m.length,k=c.b,j=k.length,i=c.c,h=i.length,g="("+A.bR(m)
if(j>0){s=l>0?",":""
g+=s+"["+A.bR(k)+"]"}if(h>0){s=l>0?",":""
g+=s+"{"+A.iD(i)+"}"}r=n+(g+")")
q=a.eC.get(r)
if(q!=null)return q
p=new A.a1(null,null)
p.w=11
p.x=b
p.y=c
p.as=r
o=A.aB(a,p)
a.eC.set(r,o)
return o},
fn(a,b,c,d){var s,r=b.as+("<"+A.bR(c)+">"),q=a.eC.get(r)
if(q!=null)return q
s=A.iF(a,b,c,r,d)
a.eC.set(r,s)
return s},
iF(a,b,c,d,e){var s,r,q,p,o,n,m,l
if(e){s=c.length
r=A.eU(s)
for(q=0,p=0;p<s;++p){o=c[p]
if(o.w===1){r[p]=o;++q}}if(q>0){n=A.aD(a,b,r,0)
m=A.b8(a,c,r,0)
return A.fn(a,n,m,c!==m)}}l=new A.a1(null,null)
l.w=12
l.x=b
l.y=c
l.as=d
return A.aB(a,l)},
h8(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
ha(a){var s,r,q,p,o,n,m,l=a.r,k=a.s
for(s=l.length,r=0;r<s;){q=l.charCodeAt(r)
if(q>=48&&q<=57)r=A.ix(r+1,q,l,k)
else if((((q|32)>>>0)-97&65535)<26||q===95||q===36||q===124)r=A.h9(a,r,l,k,!1)
else if(q===46)r=A.h9(a,r,l,k,!0)
else{++r
switch(q){case 44:break
case 58:k.push(!1)
break
case 33:k.push(!0)
break
case 59:k.push(A.aP(a.u,a.e,k.pop()))
break
case 94:k.push(A.iH(a.u,k.pop()))
break
case 35:k.push(A.bT(a.u,5,"#"))
break
case 64:k.push(A.bT(a.u,2,"@"))
break
case 126:k.push(A.bT(a.u,3,"~"))
break
case 60:k.push(a.p)
a.p=k.length
break
case 62:A.iz(a,k)
break
case 38:A.iy(a,k)
break
case 63:p=a.u
k.push(A.he(p,A.aP(p,a.e,k.pop()),a.n))
break
case 47:p=a.u
k.push(A.hd(p,A.aP(p,a.e,k.pop()),a.n))
break
case 40:k.push(-3)
k.push(a.p)
a.p=k.length
break
case 41:A.iw(a,k)
break
case 91:k.push(a.p)
a.p=k.length
break
case 93:o=k.splice(a.p)
A.hb(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-1)
break
case 123:k.push(a.p)
a.p=k.length
break
case 125:o=k.splice(a.p)
A.iB(a.u,a.e,o)
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
ix(a,b,c,d){var s,r,q=b-48
for(s=c.length;a<s;++a){r=c.charCodeAt(a)
if(!(r>=48&&r<=57))break
q=q*10+(r-48)}d.push(q)
return a},
h9(a,b,c,d,e){var s,r,q,p,o,n,m=b+1
for(s=c.length;m<s;++m){r=c.charCodeAt(m)
if(r===46){if(e)break
e=!0}else{if(!((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124))q=r>=48&&r<=57
else q=!0
if(!q)break}}p=c.substring(b,m)
if(e){s=a.u
o=a.e
if(o.w===9)o=o.x
n=A.iM(s,o.x)[p]
if(n==null)A.aE('No "'+p+'" in "'+A.io(o)+'"')
d.push(A.eT(s,o,n))}else d.push(p)
return m},
iz(a,b){var s,r=a.u,q=A.h7(a,b),p=b.pop()
if(typeof p=="string")b.push(A.bS(r,p,q))
else{s=A.aP(r,a.e,p)
switch(s.w){case 11:b.push(A.fn(r,s,q,a.n))
break
default:b.push(A.fm(r,s,q))
break}}},
iw(a,b){var s,r,q,p=a.u,o=b.pop(),n=null,m=null
if(typeof o=="number")switch(o){case-1:n=b.pop()
break
case-2:m=b.pop()
break
default:b.push(o)
break}else b.push(o)
s=A.h7(a,b)
o=b.pop()
switch(o){case-3:o=b.pop()
if(n==null)n=p.sEA
if(m==null)m=p.sEA
r=A.aP(p,a.e,o)
q=new A.cD()
q.a=s
q.b=n
q.c=m
b.push(A.hc(p,r,q))
return
case-4:b.push(A.hf(p,b.pop(),s))
return
default:throw A.d(A.c0("Unexpected state under `()`: "+A.x(o)))}},
iy(a,b){var s=b.pop()
if(0===s){b.push(A.bT(a.u,1,"0&"))
return}if(1===s){b.push(A.bT(a.u,4,"1&"))
return}throw A.d(A.c0("Unexpected extended operation "+A.x(s)))},
h7(a,b){var s=b.splice(a.p)
A.hb(a.u,a.e,s)
a.p=b.pop()
return s},
aP(a,b,c){if(typeof c=="string")return A.bS(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.iA(a,b,c)}else return c},
hb(a,b,c){var s,r=c.length
for(s=0;s<r;++s)c[s]=A.aP(a,b,c[s])},
iB(a,b,c){var s,r=c.length
for(s=2;s<r;s+=3)c[s]=A.aP(a,b,c[s])},
iA(a,b,c){var s,r,q=b.w
if(q===9){if(c===0)return b.x
s=b.y
r=s.length
if(c<=r)return s[c-1]
c-=r
b=b.x
q=b.w}else if(c===0)return b
if(q!==8)throw A.d(A.c0("Indexed base must be an interface type"))
s=b.y
if(c<=s.length)return s[c-1]
throw A.d(A.c0("Bad index "+c+" for "+b.k(0)))},
hw(a,b,c){var s,r=b.d
if(r==null)r=b.d=new Map()
s=r.get(c)
if(s==null){s=A.B(a,b,null,c,null)
r.set(c,s)}return s},
B(a,b,c,d,e){var s,r,q,p,o,n,m,l,k,j,i
if(b===d)return!0
if(A.aR(d))return!0
s=b.w
if(s===4)return!0
if(A.aR(b))return!1
if(b.w===1)return!0
r=s===13
if(r)if(A.B(a,c[b.x],c,d,e))return!0
q=d.w
p=t.a
if(b===p||b===t.T){if(q===7)return A.B(a,b,c,d.x,e)
return d===p||d===t.T||q===6}if(d===t.C){if(s===7)return A.B(a,b.x,c,d,e)
return s!==6}if(s===7){if(!A.B(a,b.x,c,d,e))return!1
return A.B(a,A.fi(a,b),c,d,e)}if(s===6)return A.B(a,p,c,d,e)&&A.B(a,b.x,c,d,e)
if(q===7){if(A.B(a,b,c,d.x,e))return!0
return A.B(a,b,c,A.fi(a,d),e)}if(q===6)return A.B(a,b,c,p,e)||A.B(a,b,c,d.x,e)
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
if(!A.B(a,j,c,i,e)||!A.B(a,i,e,j,c))return!1}return A.hn(a,b.x,c,d.x,e)}if(q===11){if(b===t.L)return!0
if(p)return!1
return A.hn(a,b,c,d,e)}if(s===8){if(q!==8)return!1
return A.j7(a,b,c,d,e)}if(o&&q===10)return A.jc(a,b,c,d,e)
return!1},
hn(a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
if(!A.B(a3,a4.x,a5,a6.x,a7))return!1
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
if(!A.B(a3,p[h],a7,g,a5))return!1}for(h=0;h<m;++h){g=l[h]
if(!A.B(a3,p[o+h],a7,g,a5))return!1}for(h=0;h<i;++h){g=l[m+h]
if(!A.B(a3,k[h],a7,g,a5))return!1}f=s.c
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
if(!A.B(a3,e[a+2],a7,g,a5))return!1
break}}while(b<d){if(f[b+1])return!1
b+=3}return!0},
j7(a,b,c,d,e){var s,r,q,p,o,n=b.x,m=d.x
while(n!==m){s=a.tR[n]
if(s==null)return!1
if(typeof s=="string"){n=s
continue}r=s[m]
if(r==null)return!1
q=r.length
p=q>0?new Array(q):v.typeUniverse.sEA
for(o=0;o<q;++o)p[o]=A.eT(a,b,r[o])
return A.hh(a,p,null,c,d.y,e)}return A.hh(a,b.y,null,c,d.y,e)},
hh(a,b,c,d,e,f){var s,r=b.length
for(s=0;s<r;++s)if(!A.B(a,b[s],d,e[s],f))return!1
return!0},
jc(a,b,c,d,e){var s,r=b.y,q=d.y,p=r.length
if(p!==q.length)return!1
if(b.x!==d.x)return!1
for(s=0;s<p;++s)if(!A.B(a,r[s],c,q[s],e))return!1
return!0},
b9(a){var s=a.w,r=!0
if(!(a===t.a||a===t.T))if(!A.aR(a))if(s!==6)r=s===7&&A.b9(a.x)
return r},
aR(a){var s=a.w
return s===2||s===3||s===4||s===5||a===t.U},
hg(a,b){var s,r,q=Object.keys(b),p=q.length
for(s=0;s<p;++s){r=q[s]
a[r]=b[r]}},
eU(a){return a>0?new Array(a):v.typeUniverse.sEA},
a1:function a1(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
cD:function cD(){this.c=this.b=this.a=null},
eR:function eR(a){this.a=a},
cC:function cC(){},
b6:function b6(a){this.a=a},
fO(a,b){return new A.aj(a.h("@<0>").u(b).h("aj<1,2>"))},
am(a,b,c){return b.h("@<0>").u(c).h("fN<1,2>").a(A.jx(a,new A.aj(b.h("@<0>").u(c).h("aj<1,2>"))))},
ay(a,b){return new A.aj(a.h("@<0>").u(b).h("aj<1,2>"))},
fQ(a){return new A.at(a.h("at<0>"))},
fR(a){return new A.at(a.h("at<0>"))},
ie(a,b){return b.h("fP<0>").a(A.jy(a,new A.at(b.h("at<0>"))))},
fl(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
iv(a,b,c){var s=new A.aO(a,b,c.h("aO<0>"))
s.c=a.e
return s},
id(a,b,c){var s=A.fO(b,c)
a.H(0,new A.em(s,b,c))
return s},
ig(a,b){var s=A.fQ(b)
s.I(0,a)
return s},
ep(a){var s,r
if(A.fs(a))return"{...}"
s=new A.b3("")
try{r={}
B.a.l($.V,a)
s.a+="{"
r.a=!0
a.H(0,new A.eq(r,s))
s.a+="}"}finally{if(0>=$.V.length)return A.a($.V,-1)
$.V.pop()}r=s.a
return r.charCodeAt(0)==0?r:r},
ih(a){return 8},
iN(){throw A.d(A.eI("Cannot change an unmodifiable set"))},
at:function at(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
cG:function cG(a){this.a=a
this.b=null},
aO:function aO(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
em:function em(a,b,c){this.a=a
this.b=b
this.c=c},
I:function I(){},
eq:function eq(a,b){this.a=a
this.b=b},
bU:function bU(){},
b1:function b1(){},
bK:function bK(){},
bw:function bw(a,b){var _=this
_.a=a
_.d=_.c=_.b=0
_.$ti=b},
bO:function bO(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=null
_.$ti=e},
aN:function aN(){},
bQ:function bQ(){},
cH:function cH(){},
bL:function bL(a,b){this.a=a
this.$ti=b},
b7:function b7(){},
bV:function bV(){},
jh(a,b){var s,r,q,p=null
try{p=JSON.parse(a)}catch(r){s=A.ft(r)
q=A.ch(String(s),null)
throw A.d(q)}q=A.eY(p)
return q},
eY(a){var s
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.cE(a,Object.create(null))
for(s=0;s<a.length;++s)a[s]=A.eY(a[s])
return a},
fM(a,b,c){return new A.bp(a,b)},
iV(a){return a.cg()},
it(a,b){return new A.eN(a,[],A.ju())},
iu(a,b,c){var s,r=new A.b3(""),q=A.it(r,b)
q.ac(a)
s=r.a
return s.charCodeAt(0)==0?s:s},
cE:function cE(a,b){this.a=a
this.b=b
this.c=null},
cF:function cF(a){this.a=a},
c3:function c3(){},
c7:function c7(){},
bp:function bp(a,b){this.a=a
this.b=b},
cr:function cr(a,b){this.a=a
this.b=b},
ei:function ei(){},
ek:function ek(a){this.b=a},
ej:function ej(a){this.a=a},
eO:function eO(){},
eP:function eP(a,b){this.a=a
this.b=b},
eN:function eN(a,b,c){this.c=a
this.a=b
this.b=c},
cI(a){var s=A.ij(a,null)
if(s!=null)return s
throw A.d(A.ch(a,null))},
bx(a,b,c,d){var s,r=J.fL(a,d)
if(a!==0&&b!=null)for(s=0;s<a;++s)r[s]=b
return r},
fh(a,b,c){var s,r=A.o([],c.h("m<0>"))
for(s=J.a4(a);s.n();)B.a.l(r,c.a(s.gp()))
if(b)return r
r.$flags=1
return r},
y(a,b){var s,r=A.o([],b.h("m<0>"))
for(s=a.gq(a);s.n();)B.a.l(r,s.gp())
return r},
a9(a,b){var s=A.fh(a,!1,b)
s.$flags=3
return s},
im(a){return new A.cp(a,A.ib(a,!1,!0,!1,!1,""))},
h3(a,b,c){var s=J.a4(b)
if(!s.n())return a
if(c.length===0){do a+=A.x(s.gp())
while(s.n())}else{a+=A.x(s.gp())
while(s.n())a=a+c+A.x(s.gp())}return a},
i4(a,b,c,d,e,f,g,h,i){var s=A.h_(a,b,c,d,e,f,g,h,i)
if(s==null)return null
return new A.a6(A.fG(s,h,i),h,i)},
i3(a){var s=A.h_(a,1,1,0,0,0,0,0,!0)
return new A.a6(s==null?new A.dz(a,1,1,0,0,0,0,0).$0():s,0,!0)},
i6(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=$.hF().bY(a)
if(c!=null){s=new A.dB()
r=c.b
if(1>=r.length)return A.a(r,1)
q=r[1]
q.toString
p=A.cI(q)
if(2>=r.length)return A.a(r,2)
q=r[2]
q.toString
o=A.cI(q)
if(3>=r.length)return A.a(r,3)
q=r[3]
q.toString
n=A.cI(q)
if(4>=r.length)return A.a(r,4)
m=s.$1(r[4])
if(5>=r.length)return A.a(r,5)
l=s.$1(r[5])
if(6>=r.length)return A.a(r,6)
k=s.$1(r[6])
if(7>=r.length)return A.a(r,7)
j=new A.dC().$1(r[7])
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
e=A.cI(q)
if(11>=r.length)return A.a(r,11)
l-=f*(s.$1(r[11])+60*e)}}d=A.i4(p,o,n,m,l,k,i,j%1000,h)
if(d==null)throw A.d(A.ch("Time out of range",a))
return d}else throw A.d(A.ch("Invalid date format",a))},
fG(a,b,c){var s="microsecond"
if(b<0||b>999)throw A.d(A.aa(b,0,999,s,null))
if(a<-864e13||a>864e13)throw A.d(A.aa(a,-864e13,864e13,"millisecondsSinceEpoch",null))
if(a===864e13&&b!==0)throw A.d(A.hW(b,s,"Time including microseconds is outside valid range"))
A.ht(c,"isUtc",t.y)
return a},
fF(a){var s=Math.abs(a),r=a<0?"-":""
if(s>=1000)return""+a
if(s>=100)return r+"0"+s
if(s>=10)return r+"00"+s
return r+"000"+s},
i5(a){var s=Math.abs(a),r=a<0?"-":"+"
if(s>=1e5)return r+s
return r+"0"+s},
dA(a){if(a>=100)return""+a
if(a>=10)return"0"+a
return"00"+a},
af(a){if(a>=10)return""+a
return"0"+a},
D(a,b){return new A.L(a+1000*b)},
cg(a){if(typeof a=="number"||A.fp(a)||a==null)return J.aT(a)
if(typeof a=="string")return JSON.stringify(a)
return A.ik(a)},
c0(a){return new A.c_(a)},
fd(a){return new A.ac(!1,null,null,a)},
hW(a,b,c){return new A.ac(!0,a,b,c)},
cZ(a,b,c){return a},
aa(a,b,c,d,e){return new A.bC(b,c,!0,a,d,"Invalid value")},
h0(a,b,c){if(0>a||a>c)throw A.d(A.aa(a,0,c,"start",null))
if(a>b||b>c)throw A.d(A.aa(b,a,c,"end",null))
return b},
ao(a,b){if(a<0)throw A.d(A.aa(a,0,null,b,null))
return a},
ed(a,b,c,d,e){return new A.ci(b,!0,a,e,"Index out of range")},
eI(a){return new A.bM(a)},
ip(a){return new A.b2(a)},
O(a){return new A.c6(a)},
ch(a,b){return new A.ec(a,b)},
i9(a,b,c){var s,r
if(A.fs(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}s=A.o([],t.s)
B.a.l($.V,a)
try{A.jg(a,s)}finally{if(0>=$.V.length)return A.a($.V,-1)
$.V.pop()}r=A.h3(b,t.hf.a(s),", ")+c
return r.charCodeAt(0)==0?r:r},
fe(a,b,c){var s,r
if(A.fs(a))return b+"..."+c
s=new A.b3(b)
B.a.l($.V,a)
try{r=s
r.a=A.h3(r.a,a,", ")}finally{if(0>=$.V.length)return A.a($.V,-1)
$.V.pop()}s.a+=c
r=s.a
return r.charCodeAt(0)==0?r:r},
jg(a,b){var s,r,q,p,o,n,m,l=a.gq(a),k=0,j=0
for(;;){if(!(k<80||j<3))break
if(!l.n())return
s=A.x(l.gp())
B.a.l(b,s)
k+=s.length+2;++j}if(!l.n()){if(j<=5)return
if(0>=b.length)return A.a(b,-1)
r=b.pop()
if(0>=b.length)return A.a(b,-1)
q=b.pop()}else{p=l.gp();++j
if(!l.n()){if(j<=4){B.a.l(b,A.x(p))
return}r=A.x(p)
if(0>=b.length)return A.a(b,-1)
q=b.pop()
k+=r.length+2}else{o=l.gp();++j
for(;l.n();p=o,o=n){n=l.gp();++j
if(j>100){for(;;){if(!(k>75&&j>3))break
if(0>=b.length)return A.a(b,-1)
k-=b.pop().length+2;--j}B.a.l(b,"...")
return}}q=A.x(p)
r=A.x(o)
k+=r.length+q.length+4}}if(j>b.length+2){k+=5
m="..."}else m=null
for(;;){if(!(k>80&&b.length>3))break
if(0>=b.length)return A.a(b,-1)
k-=b.pop().length+2
if(m==null){k+=5
m="..."}}if(m!=null)B.a.l(b,m)
B.a.l(b,q)
B.a.l(b,r)},
fS(a,b){var s=J.ba(a)
b=J.ba(b)
b=A.ir(A.h4(A.h4($.hQ(),s),b))
return b},
dz:function dz(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
a6:function a6(a,b,c){this.a=a
this.b=b
this.c=c},
dB:function dB(){},
dC:function dC(){},
L:function L(a){this.a=a},
eK:function eK(){},
u:function u(){},
c_:function c_(a){this.a=a},
bJ:function bJ(){},
ac:function ac(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bC:function bC(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
ci:function ci(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
bM:function bM(a){this.a=a},
b2:function b2(a){this.a=a},
c6:function c6(a){this.a=a},
cs:function cs(){},
bF:function bF(){},
eL:function eL(a){this.a=a},
ec:function ec(a,b){this.a=a
this.b=b},
c:function c(){},
F:function F(a,b,c){this.a=a
this.b=b
this.$ti=c},
aL:function aL(){},
j:function j(){},
b3:function b3(a){this.a=a},
cM:function cM(){},
cU:function cU(a){this.a=a},
cV:function cV(){},
cW:function cW(a){this.a=a},
cX:function cX(a,b){this.a=a
this.b=b},
cY:function cY(a,b){this.a=a
this.b=b},
cN:function cN(){},
cP:function cP(){},
cO:function cO(a){this.a=a},
cQ:function cQ(a,b){this.a=a
this.b=b},
cR:function cR(){},
cT:function cT(){},
cS:function cS(a){this.a=a},
d0:function d0(){},
dh:function dh(){},
di:function di(){},
d2:function d2(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
d1:function d1(a){this.a=a},
d3:function d3(){},
d4:function d4(a){this.a=a},
d7:function d7(a){this.a=a},
d8:function d8(){},
db:function db(){},
dc:function dc(a,b){this.a=a
this.b=b},
da:function da(a){this.a=a},
dd:function dd(){},
de:function de(){},
d6:function d6(a){this.a=a},
d5:function d5(a){this.a=a},
df:function df(){},
dg:function dg(){},
d9:function d9(a){this.a=a},
aC:function aC(a,b){this.a=a
this.b=b},
ab:function ab(a,b,c){this.a=a
this.b=b
this.c=c},
dj:function dj(a,b,c,d){var _=this
_.a=a
_.f=b
_.r=c
_.z=d},
d_:function d_(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
A:function A(a,b,c,d,e,f,g,h,i,j,k,l,m){var _=this
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
c4:function c4(a){this.b=a},
dk:function dk(a,b,c,d,e,f,g,h,i,j,k){var _=this
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
c5:function c5(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.r=c
_.w=d
_.x=e
_.y=f},
bc:function bc(a,b){this.a=a
this.b=b},
ae:function ae(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
dp:function dp(a,b){this.a=a
this.b=b},
j0(a,b){var s
if(!isFinite(a)||a<0||a>=360)return null
s=B.b.U(Math.abs(a-b),360)
return s>180?360-s:s},
dl:function dl(){},
dm:function dm(){},
dn:function dn(){},
bP:function bP(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.r=_.f=$},
a3:function a3(a,b,c){this.a=a
this.b=b
this.c=c},
eM:function eM(a,b,c){this.a=a
this.b=b
this.c=c},
c9:function c9(){},
dw:function dw(a,b){this.a=a
this.b=b},
dx:function dx(){},
dy:function dy(){},
ds:function ds(){},
dt:function dt(){},
du:function du(){},
dv:function dv(){},
dr:function dr(){},
c8:function c8(a,b,c){this.a=a
this.y=b
this.z=c},
a5:function a5(a,b,c,d,e,f,g){var _=this
_.e=a
_.r=b
_.w=c
_.x=d
_.y=e
_.z=f
_.Q=g},
dD:function dD(){},
cb:function cb(){},
dH:function dH(){},
dG:function dG(){},
dI:function dI(a,b){this.a=a
this.b=b},
dT:function dT(){},
dS:function dS(){},
dU:function dU(a){this.a=a},
dW:function dW(){},
dV:function dV(){},
dX:function dX(a){this.a=a},
dY:function dY(){},
dJ:function dJ(){},
dZ:function dZ(){},
dK:function dK(a,b){this.a=a
this.b=b},
dL:function dL(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dM:function dM(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dN:function dN(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dO:function dO(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dP:function dP(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dQ:function dQ(){},
dR:function dR(a){this.a=a},
dF:function dF(a,b){this.a=a
this.b=b},
U:function U(a,b){this.a=a
this.b=b},
e_:function e_(a,b){this.a=a
this.b=b},
bf:function bf(){},
e0:function e0(){},
ck:function ck(){},
ee:function ee(){},
e1:function e1(){},
e2:function e2(){},
bg:function bg(a,b){this.a=a
this.b=b},
C:function C(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
ag:function ag(a,b){this.b=a
this.c=b},
cc:function cc(a,b,c,d,e,f,g,h,i,j){var _=this
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
fI(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s){return new A.k(h,d,s,o,e,q,g,p,f,i,k,c,a,r,n,m,b,l,j)},
a7:function a7(a,b){this.a=a
this.b=b},
b4:function b4(a,b){this.a=a
this.b=b},
aI:function aI(a,b){this.a=a
this.b=b},
aw:function aw(a,b){this.a=a
this.b=b},
P:function P(a,b){this.a=a
this.b=b},
T:function T(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.d=c
_.e=d
_.f=e
_.r=f},
aq:function aq(a,b,c){this.a=a
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
ca:function ca(a,b,c,d){var _=this
_.a=a
_.c=b
_.d=c
_.r=d},
dE:function dE(a){this.a=a},
e4:function e4(){},
e5:function e5(){},
e7:function e7(){},
e6:function e6(a){this.a=a},
e8:function e8(){},
e9:function e9(){},
ea:function ea(){},
eb:function eb(){},
cf:function cf(a,b,c){this.a=a
this.f=b
this.r=c},
ce:function ce(a,b,c){this.a=a
this.b=b
this.c=c},
bZ:function bZ(a,b,c){this.a=a
this.e=b
this.f=c},
a8:function a8(a,b){this.a=a
this.b=b},
Z:function Z(a,b){this.a=a
this.e=b},
cA:function cA(a,b,c){this.a=a
this.e=b
this.f=c},
b0:function b0(a,b){this.a=a
this.b=b},
by:function by(a,b){this.a=a
this.b=b},
az:function az(a,b,c,d,e,f,g,h){var _=this
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
bz:function bz(a,b,c){this.a=a
this.c=b
this.d=c},
en:function en(a){this.a=a},
eo:function eo(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
eW:function eW(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.w=1},
a_:function a_(a,b){this.a=a
this.b=b},
a0:function a0(a,b,c){this.a=a
this.b=b
this.c=c},
ev:function ev(){},
eV:function eV(a,b){this.a=a
this.b=b},
bI:function bI(a,b,c){this.a=a
this.r=b
this.as=c},
bH:function bH(a){this.a=a},
ew:function ew(){},
eA:function eA(a){this.a=a},
eC:function eC(a){this.a=a},
eD:function eD(a){this.a=a},
eE:function eE(){},
eF:function eF(){},
eB:function eB(a){this.a=a},
ey:function ey(){},
ez:function ez(){},
ex:function ex(a){this.a=a},
eJ:function eJ(a,b,c,d,e){var _=this
_.a=a
_.c=b
_.d=c
_.e=d
_.x=e},
hz(a){var s,r,q,p=J.cL(t.j.a(a.i(0,"sections")),new A.f5(),t.p),o=A.y(p,p.$ti.h("q.E"))
A.i3(1970)
p=A.G(a.i(0,"id"))
A.G(a.i(0,"driveId"))
s=A.h(o)
r=s.h("bk<1,a_>")
s=A.y(new A.bk(o,s.h("c<a_>(1)").a(new A.f6()),r),r.h("c.E"))
r=B.a.F(o,0,new A.f7(),t.i)
q=a.i(0,"processingVersion")
A.X(q==null?3:q)
q=a.i(0,"directionKey")
A.G(q==null?"":q)
return new A.eJ(p,s,o,r,null)},
hB(a){var s=J.cL(a,new A.fc(),t.u)
s=A.y(s,s.$ti.h("q.E"))
return s},
hA(a){var s,r,q=t.N,p=t.z
if(a==null)q=A.ay(q,p)
else{s=A.ay(q,p)
s.t(0,"totalScore",a.d)
s.t(0,"displayScore",a.f)
s.t(0,"algorithmVersion",a.r)
r=a.a
if(r==="reliable_intervals")s.I(0,A.am(["calculationMode",r,"calculationVersion",a.b,"reliabilityPolicyVersion",a.c],q,p))
s.t(0,"overallConfidence",a.e)
p=t.h6
s.t(0,"categories",a.w.a2(0,new A.f8(),q,p))
s.t(0,"contributions",a.x.a2(0,new A.f9(),q,p))
q=s}return q},
hu(a){var s,r=a.e
r=r==null?null:A.hA(r)
s=a.f
s=s==null?null:A.hA(s)
return A.am(["outcome",a.x.b,"comparisonValid",a.y,"firstLocalScore",r,"secondLocalScore",s,"scoreDifference",a.r,"relativeDifference",a.w],t.N,t.z)},
fa(a){var s=a.b,r=A.h(s),q=r.h("f<1,e>")
r=A.y(new A.f(s,r.h("e(1)").a(new A.fb()),q),q.h("q.E"))
return A.am(["status",a.a.b,"startIndex",a.c,"endIndex",a.d,"count",s.length,"mappingConfidence",a.e,"timestamps",r],t.N,t.z)},
jw(a){var s,r,q="latitude",p="longitude",o=A.G(a.i(0,"firstDriveId")),n=A.G(a.i(0,"secondDriveId")),m=A.G(a.i(0,"firstSectionId")),l=A.G(a.i(0,"secondSectionId")),k=A.t(a.i(0,"firstStartOffsetMeters")),j=A.t(a.i(0,"firstEndOffsetMeters")),i=A.t(a.i(0,"secondStartOffsetMeters")),h=A.t(a.i(0,"secondEndOffsetMeters")),g=t.P,f=g.a(a.i(0,"commonStart"))
A.t(f.i(0,q))
A.t(f.i(0,p))
g=g.a(a.i(0,"commonEnd"))
A.t(g.i(0,q))
A.t(g.i(0,p))
g=A.t(a.i(0,"commonDistanceMeters"))
A.eX(a.i(0,"directionCompatible"))
f=A.t(a.i(0,"geometryConfidence"))
s=A.eX(a.i(0,"comparisonEligible"))
A.eX(a.i(0,"ownershipCovered"))
r=J.cL(t.j.a(a.i(0,"referenceGeometry")),new A.f1(),t.A)
A.y(r,r.$ti.h("q.E"))
return new A.dk(o,n,m,l,k,j,i,h,g,f,s)},
jq(a,b,c,d,e,f){var s,r,q,p,o,n,m,l,k="secondExtraction",j=t.t,i=B.l.aN(b,j.a(d),a,c,j.a(e))
if(!i.gaR())return A.am(["status","telemetryUnavailable","firstExtraction",A.fa(i.a),k,A.fa(i.b),"windows",[],"winningRegions",[]],t.N,t.z)
j=i.a
s=j.b
r=i.b
q=r.b
p=f.bR(B.C,b,s,a,!1,c,q)
o=new A.en(f).bP(B.C,c,q,b,s,a,!1)
s=A.hu(p)
j=A.fa(j)
r=A.fa(r)
q=o.c
n=A.h(q)
m=n.h("f<1,r<e,j>>")
q=A.y(new A.f(q,n.h("r<e,j>(1)").a(new A.eZ()),m),m.h("q.E"))
n=o.d
m=A.h(n)
l=m.h("f<1,r<e,j>>")
n=A.y(new A.f(n,m.h("r<e,j>(1)").a(new A.f_()),l),l.h("q.E"))
return A.am(["status",o.a.b,"comparison",s,"firstExtraction",j,k,r,"windows",q,"winningRegions",n],t.N,t.z)},
f5:function f5(){},
f4:function f4(){},
f6:function f6(){},
f7:function f7(){},
fc:function fc(){},
f8:function f8(){},
f9:function f9(){},
fb:function fb(){},
f1:function f1(){},
eZ:function eZ(){},
f_:function f_(){},
cx:function cx(a){this.y=a
this.z=0},
jF(){var s,r=new A.f3()
if(typeof r=="function")A.aE(A.fd("Attempting to rewrap a JS function."))
s=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.iU,r)
s[$.fu()]=r
v.G.driveItWorldScoringBoundaryTest=s},
f3:function f3(){},
jI(a){throw A.E(new A.bq("Field '"+a+"' has been assigned during initialization."),new Error())},
hC(){throw A.E(A.ic(""),new Error())},
iU(a,b,c){t.Z.a(a)
if(A.X(c)>=1)return a.$1(b)
return a.$0()},
hx(a,b,c){A.jr(c,t.H,"T","max")
return Math.max(c.a(a),c.a(b))},
fH(a){var s
if(a.gaO()){s=a.r
s=isFinite(s)&&s>=0&&s<=30}else s=!1
return s},
cd(a,b){var s,r=b.c.P(a.c),q=!1
if(A.fH(a))if(A.fH(b))if(!b.y)if(b.z===0){s=r.a
if(s>=2e5)if(s<=15e6){q=b.w
q=isFinite(q)&&q>=0}}return q},
i7(a){var s,r,q,p=A.o([],t.q)
for(s=0;r=a.length,s<r;++s){if(s!==0){q=s-1
if(!(q>=0))return A.a(a,q)
q=A.cd(a[q],a[s])
r=q}else r=!0
q=a.length
if(r){if(!(s<q))return A.a(a,s)
p.push(a[s])}else{if(!(s<q))return A.a(a,s)
r=a[s]
p.push(new A.A(r.a,r.b,r.c,r.d,r.e,r.f,r.r,0,0,!0,r.z,r.Q,!1))}}return p},
e3(a,b,c){var s,r,q,p
for(s=a+1;s<=b;++s){r=s-1
q=!0
if(A.cd(c.$1(r),c.$1(s))){r=c.$1(r)
p=r.Q
if(p!=="unavailable"&&p!=="held_estimate"){r=r.d
r=isFinite(r)&&r>=0&&r<=70}else r=!1
if(r){r=c.$1(s)
q=r.Q
if(q!=="unavailable"&&q!=="held_estimate"){r=r.d
r=isFinite(r)&&r>=0&&r<=70}else r=!1
r=!r}else r=q}else r=q
if(r)return!1}return!0},
fK(a,b,c,d){var s=Math.sin((c-a)*3.141592653589793/180/2),r=Math.sin((d-b)*3.141592653589793/180/2)
return 12742017.6*Math.asin(Math.sqrt(B.b.j(s*s+Math.cos(a*3.141592653589793/180)*Math.cos(c*3.141592653589793/180)*r*r,0,1)))},
is(a){var s=a.c,r=A.fj(a.b)
return isFinite(s)&&s>0?s:r},
fj(a){var s,r,q,p,o
for(s=0,r=0;r<a.length-1;){q=a[r];++r
p=a[r]
o=A.fK(q.a,q.b,p.a,p.b)
if(isFinite(o)&&o>0)s+=o}return s},
fk(a,b,c){if(!isFinite(b)||!isFinite(a)||!isFinite(c)||a<=0||c<=0)return 0
return B.b.j(B.b.j(b/a,0,1)*c,0,c)}},B={}
var w=[A,J,B]
var $={}
A.ff.prototype={}
J.cl.prototype={
M(a,b){return a===b},
gB(a){return A.cu(a)},
k(a){return"Instance of '"+A.cv(a)+"'"},
gT(a){return A.au(A.fo(this))}}
J.cn.prototype={
k(a){return String(a)},
gB(a){return a?519018:218159},
gT(a){return A.au(t.y)},
$iar:1,
$il:1}
J.bn.prototype={
M(a,b){return null==b},
k(a){return"null"},
gB(a){return 0},
$iar:1}
J.b_.prototype={$iaZ:1}
J.ax.prototype={
gB(a){return 0},
k(a){return String(a)}}
J.es.prototype={}
J.aA.prototype={}
J.bo.prototype={
k(a){var s=a[$.hE()]
if(s==null)s=a[$.fu()]
if(s==null)return this.b_(a)
return"JavaScript function for "+J.aT(s)},
$iai:1}
J.m.prototype={
l(a,b){A.h(a).c.a(b)
a.$flags&1&&A.cJ(a,29)
a.push(b)},
I(a,b){var s
A.h(a).h("c<1>").a(b)
a.$flags&1&&A.cJ(a,"addAll",2)
for(s=b.gq(b);s.n();)a.push(s.gp())},
aS(a,b,c){var s=A.h(a)
return new A.f(a,s.u(c).h("1(2)").a(b),s.h("@<1>").u(c).h("f<1,2>"))},
c3(a,b){var s,r=A.bx(a.length,"",!1,t.N)
for(s=0;s<a.length;++s)this.t(r,s,A.x(a[s]))
return r.join(b)},
L(a,b){return A.eu(a,b,null,A.h(a).c)},
K(a,b){var s,r,q
A.h(a).h("1(1,1)").a(b)
s=a.length
if(s===0)throw A.d(A.aX())
if(0>=s)return A.a(a,0)
r=a[0]
for(q=1;q<s;++q){r=b.$2(r,a[q])
if(s!==a.length)throw A.d(A.O(a))}return r},
F(a,b,c,d){var s,r,q
d.a(b)
A.h(a).u(d).h("1(1,2)").a(c)
s=a.length
for(r=b,q=0;q<s;++q){r=c.$2(r,a[q])
if(a.length!==s)throw A.d(A.O(a))}return r},
C(a,b){if(!(b>=0&&b<a.length))return A.a(a,b)
return a[b]},
a4(a,b,c){if(b<0||b>a.length)throw A.d(A.aa(b,0,a.length,"start",null))
if(c<b||c>a.length)throw A.d(A.aa(c,b,a.length,"end",null))
if(b===c)return A.o([],A.h(a))
return A.o(a.slice(b,c),A.h(a))},
gN(a){if(a.length>0)return a[0]
throw A.d(A.aX())},
ga1(a){var s=a.length
if(s>0)return a[s-1]
throw A.d(A.aX())},
au(a,b,c,d,e){var s,r,q,p,o
A.h(a).h("c<1>").a(d)
a.$flags&2&&A.cJ(a,5)
A.h0(b,c,a.length)
s=c-b
if(s===0)return
A.ao(e,"skipCount")
if(t.j.b(d)){r=d
q=e}else{r=J.fx(d,e).aU(0,!1)
q=0}p=J.bX(r)
if(q+s>p.gm(r))throw A.d(A.i8())
if(q<b)for(o=s-1;o>=0;--o)a[b+o]=p.i(r,q+o)
else for(o=0;o<s;++o)a[b+o]=p.i(r,q+o)},
a0(a,b){var s,r
A.h(a).h("l(1)").a(b)
s=a.length
for(r=0;r<s;++r){if(b.$1(a[r]))return!0
if(a.length!==s)throw A.d(A.O(a))}return!1},
av(a,b){var s,r,q,p,o,n=A.h(a)
n.h("N(1,1)?").a(b)
a.$flags&2&&A.cJ(a,"sort")
s=a.length
if(s<2)return
if(b==null)b=J.j4()
if(s===2){r=a[0]
q=a[1]
n=b.$2(r,q)
if(typeof n!=="number")return n.cd()
if(n>0){a[0]=q
a[1]=r}return}p=0
if(n.c.b(null))for(o=0;o<a.length;++o)if(a[o]===void 0){a[o]=null;++p}a.sort(A.js(b,2))
if(p>0)this.bt(a,p)},
aZ(a){return this.av(a,null)},
bt(a,b){var s,r=a.length
for(;s=r-1,r>0;r=s)if(a[s]===null){a[s]=void 0;--b
if(b===0)break}},
gv(a){return a.length===0},
gX(a){return a.length!==0},
k(a){return A.fe(a,"[","]")},
gq(a){return new J.aG(a,a.length,A.h(a).h("aG<1>"))},
gB(a){return A.cu(a)},
gm(a){return a.length},
i(a,b){A.X(b)
if(!(b>=0&&b<a.length))throw A.d(A.f2(a,b))
return a[b]},
t(a,b,c){A.h(a).c.a(c)
a.$flags&2&&A.cJ(a)
if(!(b>=0&&b<a.length))throw A.d(A.f2(a,b))
a[b]=c},
$ip:1,
$ic:1,
$iv:1}
J.cm.prototype={
c7(a){var s,r,q
if(!Array.isArray(a))return null
s=a.$flags|0
if((s&4)!==0)r="const, "
else if((s&2)!==0)r="unmodifiable, "
else r=(s&1)!==0?"fixed, ":""
q="Instance of '"+A.cv(a)+"'"
if(r==="")return q
return q+" ("+r+"length: "+a.length+")"}}
J.eg.prototype={}
J.aG.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
n(){var s,r=this,q=r.a,p=q.length
if(r.b!==p){q=A.Y(q)
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
else if(a===b){if(a===0){s=this.gab(b)
if(this.gab(a)===s)return 0
if(this.gab(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gab(a){return a===0?1/a<0:a<0},
aT(a){var s
if(a>=-2147483648&&a<=2147483647)return a|0
if(isFinite(a)){s=a<0?Math.ceil(a):Math.floor(a)
return s+0}throw A.d(A.eI(""+a+".toInt()"))},
a3(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.d(A.eI(""+a+".round()"))},
j(a,b,c){if(this.E(b,c)>0)throw A.d(A.hs(b))
if(this.E(a,b)<0)return b
if(this.E(a,c)>0)return c
return a},
aV(a,b){var s
if(b>20)throw A.d(A.aa(b,0,20,"fractionDigits",null))
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
U(a,b){var s=a%b
if(s===0)return 0
if(s>0)return s
return s+b},
A(a,b){return(a|0)===a?a/b|0:this.bF(a,b)},
bF(a,b){var s=a/b
if(s>=-2147483648&&s<=2147483647)return s|0
if(s>0){if(s!==1/0)return Math.floor(s)}else if(s>-1/0)return Math.ceil(s)
throw A.d(A.eI("Result of truncating division is "+A.x(s)+": "+A.x(a)+" ~/ "+b))},
aJ(a,b){var s
if(a>0)s=this.bA(a,b)
else{s=b>31?31:b
s=a>>s>>>0}return s},
bA(a,b){return b>31?0:a>>>b},
gT(a){return A.au(t.H)},
$iQ:1,
$ib:1,
$iJ:1}
J.bm.prototype={
gT(a){return A.au(t.S)},
$iar:1,
$iN:1}
J.co.prototype={
gT(a){return A.au(t.i)},
$iar:1}
J.aJ.prototype={
Y(a,b,c){return a.substring(b,A.h0(b,c,a.length))},
ar(a,b){var s,r
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.d(B.a3)
for(s=a,r="";;){if((b&1)===1)r=s+r
b=b>>>1
if(b===0)break
s+=s}return r},
c4(a,b,c){var s=b-a.length
if(s<=0)return a
return this.ar(c,s)+a},
E(a,b){var s
A.G(b)
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
gT(a){return A.au(t.N)},
gm(a){return a.length},
i(a,b){A.X(b)
if(!(b.cc(0,0)&&b.cf(0,a.length)))throw A.d(A.f2(a,b))
return a[b]},
$iar:1,
$iQ:1,
$ie:1}
A.b5.prototype={
gq(a){return new A.bb(J.a4(this.gW()),A.i(this).h("bb<1,2>"))},
gm(a){return J.aF(this.gW())},
gv(a){return J.fw(this.gW())},
gX(a){return J.hU(this.gW())},
L(a,b){var s=A.i(this)
return A.fC(J.fx(this.gW(),b),s.c,s.y[1])},
k(a){return J.aT(this.gW())}}
A.bb.prototype={
n(){return this.a.n()},
gp(){return this.$ti.y[1].a(this.a.gp())},
$iw:1}
A.aH.prototype={
gW(){return this.a}}
A.bN.prototype={$ip:1}
A.bq.prototype={
k(a){return"LateInitializationError: "+this.a}}
A.et.prototype={}
A.p.prototype={}
A.q.prototype={
gq(a){var s=this
return new A.bv(s,s.gm(s),A.i(s).h("bv<q.E>"))},
gv(a){return this.gm(this)===0},
a0(a,b){var s,r,q=this
A.i(q).h("l(q.E)").a(b)
s=q.gm(q)
for(r=0;r<s;++r){if(b.$1(q.C(0,r)))return!0
if(s!==q.gm(q))throw A.d(A.O(q))}return!1},
K(a,b){var s,r,q,p=this
A.i(p).h("q.E(q.E,q.E)").a(b)
s=p.gm(p)
if(s===0)throw A.d(A.aX())
r=p.C(0,0)
for(q=1;q<s;++q){r=b.$2(r,p.C(0,q))
if(s!==p.gm(p))throw A.d(A.O(p))}return r},
L(a,b){return A.eu(this,b,null,A.i(this).h("q.E"))}}
A.bG.prototype={
gbc(){var s=J.aF(this.a),r=this.c
if(r==null||r>s)return s
return r},
gbB(){var s=J.aF(this.a),r=this.b
if(r>s)return s
return r},
gm(a){var s,r=J.aF(this.a),q=this.b
if(q>=r)return 0
s=this.c
if(s==null||s>=r)return r-q
return s-q},
C(a,b){var s=this,r=s.gbB()+b
if(b<0||r>=s.gbc())throw A.d(A.ed(b,s.gm(0),s,null,"index"))
return J.fv(s.a,r)},
L(a,b){var s,r,q=this
A.ao(b,"count")
s=q.b+b
r=q.c
if(r!=null&&s>=r)return new A.bi(q.$ti.h("bi<1>"))
return A.eu(q.a,s,r,q.$ti.c)},
aU(a,b){var s,r,q,p=this,o=p.b,n=p.a,m=J.bX(n),l=m.gm(n),k=p.c
if(k!=null&&k<l)l=k
s=l-o
if(s<=0){n=J.fL(0,p.$ti.c)
return n}r=A.bx(s,m.C(n,o),!1,p.$ti.c)
for(q=1;q<s;++q){B.a.t(r,q,m.C(n,o+q))
if(m.gm(n)<l)throw A.d(A.O(p))}return r}}
A.bv.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
n(){var s,r=this,q=r.a,p=q.gm(q)
if(r.b!==p)throw A.d(A.O(q))
s=r.c
if(s>=p){r.d=null
return!1}r.d=q.C(0,s);++r.c
return!0},
$iw:1}
A.an.prototype={
gq(a){return new A.bA(J.a4(this.a),this.b,A.i(this).h("bA<1,2>"))},
gm(a){return J.aF(this.a)},
gv(a){return J.fw(this.a)}}
A.bh.prototype={$ip:1}
A.bA.prototype={
n(){var s=this,r=s.b
if(r.n()){s.a=s.c.$1(r.gp())
return!0}s.a=null
return!1},
gp(){var s=this.a
return s==null?this.$ti.y[1].a(s):s},
$iw:1}
A.f.prototype={
gm(a){return J.aF(this.a)},
C(a,b){return this.b.$1(J.fv(this.a,b))}}
A.z.prototype={
gq(a){return new A.a2(J.a4(this.a),this.b,this.$ti.h("a2<1>"))}}
A.a2.prototype={
n(){var s,r
for(s=this.a,r=this.b;s.n();)if(r.$1(s.gp()))return!0
return!1},
gp(){return this.a.gp()},
$iw:1}
A.bk.prototype={
gq(a){return new A.bl(J.a4(this.a),this.b,B.v,this.$ti.h("bl<1,2>"))}}
A.bl.prototype={
gp(){var s=this.d
return s==null?this.$ti.y[1].a(s):s},
n(){var s,r,q=this,p=q.c
if(p==null)return!1
for(s=q.a,r=q.b;!p.n();){q.d=null
if(s.n()){q.c=null
p=J.a4(r.$1(s.gp()))
q.c=p}else return!1}q.d=q.c.gp()
return!0},
$iw:1}
A.ap.prototype={
L(a,b){A.cZ(b,"count",t.S)
A.ao(b,"count")
return new A.ap(this.a,this.b+b,A.i(this).h("ap<1>"))},
gq(a){var s=this.a
return new A.bE(s.gq(s),this.b,A.i(this).h("bE<1>"))}}
A.aV.prototype={
gm(a){var s=this.a,r=s.gm(s)-this.b
if(r>=0)return r
return 0},
L(a,b){A.cZ(b,"count",t.S)
A.ao(b,"count")
return new A.aV(this.a,this.b+b,this.$ti)},
$ip:1}
A.bE.prototype={
n(){var s,r
for(s=this.a,r=0;r<this.b;++r)s.n()
this.b=0
return s.n()},
gp(){return this.a.gp()},
$iw:1}
A.bi.prototype={
gq(a){return B.v},
gv(a){return!0},
gm(a){return 0},
L(a,b){A.ao(b,"count")
return this}}
A.bj.prototype={
n(){return!1},
gp(){throw A.d(A.aX())},
$iw:1}
A.be.prototype={}
A.bd.prototype={
gv(a){return this.gm(this)===0},
k(a){return A.ep(this)},
a2(a,b,c,d){var s=A.ay(c,d)
this.H(0,new A.dq(this,A.i(this).u(c).u(d).h("F<1,2>(3,4)").a(b),s))
return s},
$ir:1}
A.dq.prototype={
$2(a,b){var s=A.i(this.a),r=this.b.$2(s.c.a(a),s.y[1].a(b))
this.c.t(0,r.a,r.b)},
$S(){return A.i(this.a).h("~(1,2)")}}
A.R.prototype={
gm(a){return this.b.length},
gbj(){var s=this.$keys
if(s==null){s=Object.keys(this.a)
this.$keys=s}return s},
bS(a){if(typeof a!="string")return!1
if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
i(a,b){if(!this.bS(b))return null
return this.b[this.a[b]]},
H(a,b){var s,r,q,p
this.$ti.h("~(1,2)").a(b)
s=this.gbj()
r=this.b
for(q=s.length,p=0;p<q;++p)b.$2(s[p],r[p])}}
A.cj.prototype={
M(a,b){if(b==null)return!1
return b instanceof A.aW&&this.a.M(0,b.a)&&A.fr(this)===A.fr(b)},
gB(a){return A.fS(this.a,A.fr(this))},
k(a){var s=B.a.c3([A.au(this.$ti.c)],", ")
return this.a.k(0)+" with "+("<"+s+">")}}
A.aW.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.jE(A.f0(this.a),this.$ti)}}
A.bD.prototype={}
A.eG.prototype={
J(a){var s,r,q=this,p=new RegExp(q.a).exec(a)
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
A.bB.prototype={
k(a){return"Null check operator used on a null value"}}
A.cq.prototype={
k(a){var s,r=this,q="NoSuchMethodError: method not found: '",p=r.b
if(p==null)return"NoSuchMethodError: "+r.a
s=r.c
if(s==null)return q+p+"' ("+r.a+")"
return q+p+"' on '"+s+"' ("+r.a+")"}}
A.cB.prototype={
k(a){var s=this.a
return s.length===0?"Error":"Error: "+s}}
A.er.prototype={
k(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.K.prototype={
k(a){var s=this.constructor,r=s==null?null:s.name
return"Closure '"+A.hD(r==null?"unknown":r)+"'"},
$iai:1,
gca(){return this},
$C:"$1",
$R:1,
$D:null}
A.c1.prototype={$C:"$0",$R:0}
A.c2.prototype={$C:"$2",$R:2}
A.cz.prototype={}
A.cy.prototype={
k(a){var s=this.$static_name
if(s==null)return"Closure of unknown static method"
return"Closure '"+A.hD(s)+"'"}}
A.aU.prototype={
M(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.aU))return!1
return this.$_target===b.$_target&&this.a===b.a},
gB(a){return(A.hy(this.a)^A.cu(this.$_target))>>>0},
k(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.cv(this.a)+"'")}}
A.cw.prototype={
k(a){return"RuntimeError: "+this.a}}
A.aj.prototype={
gm(a){return this.a},
gv(a){return this.a===0},
gS(){return new A.ak(this,A.i(this).h("ak<1>"))},
I(a,b){A.i(this).h("r<1,2>").a(b).H(0,new A.eh(this))},
i(a,b){var s,r,q,p,o=null
if(typeof b=="string"){s=this.b
if(s==null)return o
r=s[b]
q=r==null?o:r.b
return q}else if(typeof b=="number"&&(b&0x3fffffff)===b){p=this.c
if(p==null)return o
r=p[b]
q=r==null?o:r.b
return q}else return this.c_(b)},
c_(a){var s,r,q=this.d
if(q==null)return null
s=q[this.aP(a)]
r=this.aQ(s,a)
if(r<0)return null
return s[r].b},
t(a,b,c){var s,r,q=this,p=A.i(q)
p.c.a(b)
p.y[1].a(c)
if(typeof b=="string"){s=q.b
q.aw(s==null?q.b=q.ak():s,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){r=q.c
q.aw(r==null?q.c=q.ak():r,b,c)}else q.c0(b,c)},
c0(a,b){var s,r,q,p,o=this,n=A.i(o)
n.c.a(a)
n.y[1].a(b)
s=o.d
if(s==null)s=o.d=o.ak()
r=o.aP(a)
q=s[r]
if(q==null)s[r]=[o.al(a,b)]
else{p=o.aQ(q,a)
if(p>=0)q[p].b=b
else q.push(o.al(a,b))}},
H(a,b){var s,r,q=this
A.i(q).h("~(1,2)").a(b)
s=q.e
r=q.r
while(s!=null){b.$2(s.a,s.b)
if(r!==q.r)throw A.d(A.O(q))
s=s.c}},
aw(a,b,c){var s,r=A.i(this)
r.c.a(b)
r.y[1].a(c)
s=a[b]
if(s==null)a[b]=this.al(b,c)
else s.b=c},
al(a,b){var s=this,r=A.i(s),q=new A.el(r.c.a(a),r.y[1].a(b))
if(s.e==null)s.e=s.f=q
else s.f=s.f.c=q;++s.a
s.r=s.r+1&1073741823
return q},
aP(a){return J.ba(a)&1073741823},
aQ(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.cK(a[r].a,b))return r
return-1},
k(a){return A.ep(this)},
ak(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
$ifN:1}
A.eh.prototype={
$2(a,b){var s=this.a,r=A.i(s)
s.t(0,r.c.a(a),r.y[1].a(b))},
$S(){return A.i(this.a).h("~(1,2)")}}
A.el.prototype={}
A.ak.prototype={
gm(a){return this.a.a},
gv(a){return this.a.a===0},
gq(a){var s=this.a
return new A.bt(s,s.r,s.e,this.$ti.h("bt<1>"))}}
A.bt.prototype={
gp(){return this.d},
n(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.d(A.O(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.a
r.c=s.c
return!0}},
$iw:1}
A.al.prototype={
gm(a){return this.a.a},
gv(a){return this.a.a===0},
gq(a){var s=this.a
return new A.bu(s,s.r,s.e,this.$ti.h("bu<1>"))}}
A.bu.prototype={
gp(){return this.d},
n(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.d(A.O(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.b
r.c=s.c
return!0}},
$iw:1}
A.br.prototype={
gm(a){return this.a.a},
gv(a){return this.a.a===0},
gq(a){var s=this.a
return new A.bs(s,s.r,s.e,this.$ti.h("bs<1,2>"))}}
A.bs.prototype={
gp(){var s=this.d
s.toString
return s},
n(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.d(A.O(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=new A.F(s.a,s.b,r.$ti.h("F<1,2>"))
r.c=s.c
return!0}},
$iw:1}
A.cp.prototype={
k(a){return"RegExp/"+this.a+"/"+this.b.flags},
bY(a){var s=this.b.exec(a)
if(s==null)return null
return new A.eQ(s)},
$iil:1}
A.eQ.prototype={
i(a,b){var s
A.X(b)
s=this.b
if(!(b<s.length))return A.a(s,b)
return s[b]}}
A.a1.prototype={
h(a){return A.eT(v.typeUniverse,this,a)},
u(a){return A.iK(v.typeUniverse,this,a)}}
A.cD.prototype={}
A.eR.prototype={
k(a){return A.M(this.a,null)}}
A.cC.prototype={
k(a){return this.a}}
A.b6.prototype={}
A.at.prototype={
gq(a){var s=this,r=new A.aO(s,s.r,A.i(s).h("aO<1>"))
r.c=s.e
return r},
gm(a){return this.a},
gv(a){return this.a===0},
gX(a){return this.a!==0},
aa(a,b){var s,r
if(typeof b=="string"&&b!=="__proto__"){s=this.b
if(s==null)return!1
return t.br.a(s[b])!=null}else{r=this.b7(b)
return r}},
b7(a){var s=this.d
if(s==null)return!1
return this.aC(s[this.aA(a)],a)>=0},
l(a,b){var s,r,q=this
A.i(q).c.a(b)
if(typeof b=="string"&&b!=="__proto__"){s=q.b
return q.az(s==null?q.b=A.fl():s,b)}else if(typeof b=="number"&&(b&1073741823)===b){r=q.c
return q.az(r==null?q.c=A.fl():r,b)}else return q.b1(b)},
b1(a){var s,r,q,p=this
A.i(p).c.a(a)
s=p.d
if(s==null)s=p.d=A.fl()
r=p.aA(a)
q=s[r]
if(q==null)s[r]=[p.ae(a)]
else{if(p.aC(q,a)>=0)return!1
q.push(p.ae(a))}return!0},
az(a,b){A.i(this).c.a(b)
if(t.br.a(a[b])!=null)return!1
a[b]=this.ae(b)
return!0},
ae(a){var s=this,r=new A.cG(A.i(s).c.a(a))
if(s.e==null)s.e=s.f=r
else s.f=s.f.b=r;++s.a
s.r=s.r+1&1073741823
return r},
aA(a){return J.ba(a)&1073741823},
aC(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.cK(a[r].a,b))return r
return-1},
$ifP:1}
A.cG.prototype={}
A.aO.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
n(){var s=this,r=s.c,q=s.a
if(s.b!==q.r)throw A.d(A.O(q))
else if(r==null){s.d=null
return!1}else{s.d=s.$ti.h("1?").a(r.a)
s.c=r.b
return!0}},
$iw:1}
A.em.prototype={
$2(a,b){this.a.t(0,this.b.a(a),this.c.a(b))},
$S:15}
A.I.prototype={
H(a,b){var s,r,q,p=A.i(this)
p.h("~(I.K,I.V)").a(b)
for(s=this.gS(),s=s.gq(s),p=p.h("I.V");s.n();){r=s.gp()
q=this.i(0,r)
b.$2(r,q==null?p.a(q):q)}},
a2(a,b,c,d){var s,r,q,p,o,n=A.i(this)
n.u(c).u(d).h("F<1,2>(I.K,I.V)").a(b)
s=A.ay(c,d)
for(r=this.gS(),r=r.gq(r),n=n.h("I.V");r.n();){q=r.gp()
p=this.i(0,q)
o=b.$2(q,p==null?n.a(p):p)
s.t(0,o.a,o.b)}return s},
gm(a){var s=this.gS()
return s.gm(s)},
gv(a){var s=this.gS()
return s.gv(s)},
k(a){return A.ep(this)},
$ir:1}
A.eq.prototype={
$2(a,b){var s,r=this.a
if(!r.a)this.b.a+=", "
r.a=!1
r=this.b
s=A.x(a)
r.a=(r.a+=s)+": "
s=A.x(b)
r.a+=s},
$S:12}
A.bU.prototype={}
A.b1.prototype={
i(a,b){return this.a.i(0,b)},
H(a,b){this.a.H(0,this.$ti.h("~(1,2)").a(b))},
gv(a){return this.a.a===0},
gm(a){return this.a.a},
k(a){return A.ep(this.a)},
a2(a,b,c,d){return this.a.a2(0,this.$ti.u(c).u(d).h("F<1,2>(3,4)").a(b),c,d)},
$ir:1}
A.bK.prototype={}
A.bw.prototype={
gq(a){var s=this
return new A.bO(s,s.c,s.d,s.b,s.$ti.h("bO<1>"))},
gv(a){return this.b===this.c},
gm(a){return(this.c-this.b&this.a.length-1)>>>0},
C(a,b){var s,r,q=this,p=q.gm(0)
if(0>b||b>=p)A.aE(A.ed(b,p,q,null,"index"))
p=q.a
s=p.length
r=(q.b+b&s-1)>>>0
if(!(r>=0&&r<s))return A.a(p,r)
r=p[r]
return r==null?q.$ti.c.a(r):r},
bQ(a){var s=this,r=s.b
if(r!==s.c){for(;r!==s.c;r=(r+1&s.a.length-1)>>>0)B.a.t(s.a,r,null)
s.b=s.c=0;++s.d}},
k(a){return A.fe(this,"{","}")}}
A.bO.prototype={
gp(){var s=this.e
return s==null?this.$ti.c.a(s):s},
n(){var s,r,q=this,p=q.a
if(q.c!==p.d)A.aE(A.O(p))
s=q.d
if(s===q.b){q.e=null
return!1}p=p.a
r=p.length
if(!(s<r))return A.a(p,s)
q.e=p[s]
q.d=(s+1&r-1)>>>0
return!0},
$iw:1}
A.aN.prototype={
gv(a){return this.gm(this)===0},
gX(a){return this.gm(this)!==0},
I(a,b){var s,r,q
A.i(this).h("c<1>").a(b)
for(s=b.gq(b),r=s.$ti.c;s.n();){q=s.d
this.l(0,q==null?r.a(q):q)}},
k(a){return A.fe(this,"{","}")},
L(a,b){return A.h2(this,b,A.i(this).c)},
$ip:1,
$ic:1,
$iaM:1}
A.bQ.prototype={}
A.cH.prototype={
l(a,b){this.$ti.c.a(b)
return A.iN()}}
A.bL.prototype={
aa(a,b){return this.a.aa(0,b)},
gm(a){return this.a.a},
gq(a){var s=this.a
return A.iv(s,s.r,A.i(s).c)}}
A.b7.prototype={}
A.bV.prototype={}
A.cE.prototype={
i(a,b){var s,r=this.b
if(r==null)return this.c.i(0,b)
else if(typeof b!="string")return null
else{s=r[b]
return typeof s=="undefined"?this.bp(b):s}},
gm(a){return this.b==null?this.c.a:this.a6().length},
gv(a){return this.gm(0)===0},
gS(){if(this.b==null){var s=this.c
return new A.ak(s,A.i(s).h("ak<1>"))}return new A.cF(this)},
H(a,b){var s,r,q,p,o=this
t.fH.a(b)
if(o.b==null)return o.c.H(0,b)
s=o.a6()
for(r=0;r<s.length;++r){q=s[r]
p=o.b[q]
if(typeof p=="undefined"){p=A.eY(o.a[q])
o.b[q]=p}b.$2(q,p)
if(s!==o.c)throw A.d(A.O(o))}},
a6(){var s=t.bF.a(this.c)
if(s==null)s=this.c=A.o(Object.keys(this.a),t.s)
return s},
bp(a){var s
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
s=A.eY(this.a[a])
return this.b[a]=s}}
A.cF.prototype={
gm(a){return this.a.gm(0)},
C(a,b){var s=this.a
if(s.b==null)s=s.gS().C(0,b)
else{s=s.a6()
if(!(b>=0&&b<s.length))return A.a(s,b)
s=s[b]}return s},
gq(a){var s=this.a
if(s.b==null){s=s.gS()
s=s.gq(s)}else{s=s.a6()
s=new J.aG(s,s.length,A.h(s).h("aG<1>"))}return s}}
A.c3.prototype={}
A.c7.prototype={}
A.bp.prototype={
k(a){var s=A.cg(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+s}}
A.cr.prototype={
k(a){return"Cyclic error in JSON stringify"}}
A.ei.prototype={
bT(a,b){var s=A.jh(a,this.gbU().a)
return s},
bV(a,b){var s=A.iu(a,this.gbW().b,null)
return s},
gbW(){return B.ax},
gbU(){return B.aw}}
A.ek.prototype={}
A.ej.prototype={}
A.eO.prototype={
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
if(a==null?p==null:a===p)throw A.d(new A.cr(a,null))}B.a.l(s,a)},
ac(a){var s,r,q,p,o=this
if(o.aW(a))return
o.ad(a)
try{s=o.b.$1(a)
if(!o.aW(s)){q=A.fM(a,null,o.gaH())
throw A.d(q)}q=o.a
if(0>=q.length)return A.a(q,-1)
q.pop()}catch(p){r=A.ft(p)
q=A.fM(a,r,o.gaH())
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
q.c8(a)
s=q.a
if(0>=s.length)return A.a(s,-1)
s.pop()
return!0}else if(t.eO.b(a)){q.ad(a)
r=q.c9(a)
s=q.a
if(0>=s.length)return A.a(s,-1)
s.pop()
return r}else return!1},
c8(a){var s,r,q=this.c
q.a+="["
s=J.bW(a)
if(s.gX(a)){this.ac(s.i(a,0))
for(r=1;r<s.gm(a);++r){q.a+=","
this.ac(s.i(a,r))}}q.a+="]"},
c9(a){var s,r,q,p,o,n,m=this,l={}
if(a.gv(a)){m.c.a+="{}"
return!0}s=a.gm(a)*2
r=A.bx(s,null,!1,t.U)
q=l.a=0
l.b=!0
a.H(0,new A.eP(l,r))
if(!l.b)return!1
p=m.c
p.a+="{"
for(o='"';q<s;q+=2,o=',"'){p.a+=o
m.aX(A.G(r[q]))
p.a+='":'
n=q+1
if(!(n<s))return A.a(r,n)
m.ac(r[n])}p.a+="}"
return!0}}
A.eP.prototype={
$2(a,b){var s,r
if(typeof a!="string")this.a.b=!1
s=this.b
r=this.a
B.a.t(s,r.a++,a)
B.a.t(s,r.a++,b)},
$S:12}
A.eN.prototype={
gaH(){var s=this.c.a
return s.charCodeAt(0)==0?s:s}}
A.dz.prototype={
$0(){var s=this
return A.aE(A.fd("("+s.a+", "+s.b+", "+s.c+", "+s.d+", "+s.e+", "+s.f+", "+s.r+", "+s.w+")"))},
$S:16}
A.a6.prototype={
O(a){var s=1000,r=B.c.U(a,s),q=B.c.A(a-r,s),p=this.b+r,o=B.c.U(p,s),n=this.c
return new A.a6(A.fG(this.a+B.c.A(p-o,s)+q,o,n),o,n)},
P(a){return A.D(this.b-a.b,this.a-a.a)},
M(a,b){if(b==null)return!1
return b instanceof A.a6&&this.a===b.a&&this.b===b.b&&this.c===b.c},
gB(a){return A.fS(this.a,this.b)},
c2(a){var s=this.a,r=a.a
if(s>=r)s=s===r&&this.b<a.b
else s=!0
return s},
c1(a){var s=this.a,r=a.a
if(s<=r)s=s===r&&this.b>a.b
else s=!0
return s},
E(a,b){var s
t.dy.a(b)
s=B.c.E(this.a,b.a)
if(s!==0)return s
return B.c.E(this.b,b.b)},
c6(){var s=this
if(s.c)return s
return new A.a6(s.a,s.b,!0)},
k(a){var s=this,r=A.fF(A.ct(s)),q=A.af(A.fY(s)),p=A.af(A.fU(s)),o=A.af(A.fV(s)),n=A.af(A.fX(s)),m=A.af(A.fZ(s)),l=A.dA(A.fW(s)),k=s.b,j=k===0?"":A.dA(k)
k=r+"-"+q
if(s.c)return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j},
c5(){var s=this,r=A.ct(s)>=-9999&&A.ct(s)<=9999?A.fF(A.ct(s)):A.i5(A.ct(s)),q=A.af(A.fY(s)),p=A.af(A.fU(s)),o=A.af(A.fV(s)),n=A.af(A.fX(s)),m=A.af(A.fZ(s)),l=A.dA(A.fW(s)),k=s.b,j=k===0?"":A.dA(k)
k=r+"-"+q
if(s.c)return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j},
$iQ:1}
A.dB.prototype={
$1(a){if(a==null)return 0
return A.cI(a)},
$S:13}
A.dC.prototype={
$1(a){var s,r,q
if(a==null)return 0
for(s=a.length,r=0,q=0;q<6;++q){r*=10
if(q<s){if(!(q<s))return A.a(a,q)
r+=a.charCodeAt(q)^48}}return r},
$S:13}
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
return s+m+":"+q+r+":"+o+p+"."+B.e.c4(B.c.k(n%1e6),6,"0")},
$iQ:1}
A.eK.prototype={
k(a){return this.D()}}
A.u.prototype={}
A.c_.prototype={
k(a){var s=this.a
if(s!=null)return"Assertion failed: "+A.cg(s)
return"Assertion failed"}}
A.bJ.prototype={}
A.ac.prototype={
gah(){return"Invalid argument"+(!this.a?"(s)":"")},
gag(){return""},
k(a){var s=this,r=s.c,q=r==null?"":" ("+r+")",p=s.d,o=p==null?"":": "+p,n=s.gah()+q+o
if(!s.a)return n
return n+s.gag()+": "+A.cg(s.gaq())},
gaq(){return this.b}}
A.bC.prototype={
gaq(){return A.hi(this.b)},
gah(){return"RangeError"},
gag(){var s,r=this.e,q=this.f
if(r==null)s=q!=null?": Not less than or equal to "+A.x(q):""
else if(q==null)s=": Not greater than or equal to "+A.x(r)
else if(q>r)s=": Not in inclusive range "+A.x(r)+".."+A.x(q)
else s=q<r?": Valid value range is empty":": Only valid value is "+A.x(r)
return s}}
A.ci.prototype={
gaq(){return A.X(this.b)},
gah(){return"RangeError"},
gag(){if(A.X(this.b)<0)return": index must not be negative"
var s=this.f
if(s===0)return": no indices are valid"
return": index should be less than "+s},
gm(a){return this.f}}
A.bM.prototype={
k(a){return"Unsupported operation: "+this.a}}
A.b2.prototype={
k(a){return"Bad state: "+this.a}}
A.c6.prototype={
k(a){var s=this.a
if(s==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.cg(s)+"."}}
A.cs.prototype={
k(a){return"Out of Memory"},
$iu:1}
A.bF.prototype={
k(a){return"Stack Overflow"},
$iu:1}
A.eL.prototype={
k(a){return"Exception: "+this.a}}
A.ec.prototype={
k(a){var s=this.a,r=""!==s?"FormatException: "+s:"FormatException",q=this.b
if(typeof q=="string"){if(q.length>78)q=B.e.Y(q,0,75)+"..."
return r+"\n"+q}else return r}}
A.c.prototype={
aS(a,b,c){var s=A.i(this)
return A.ii(this,s.u(c).h("1(c.E)").a(b),s.h("c.E"),c)},
F(a,b,c,d){var s,r
d.a(b)
A.i(this).u(d).h("1(1,c.E)").a(c)
for(s=this.gq(this),r=b;s.n();)r=c.$2(r,s.gp())
return r},
aU(a,b){var s=A.i(this).h("c.E")
if(b)s=A.y(this,s)
else{s=A.y(this,s)
s.$flags=1
s=s}return s},
gm(a){var s,r=this.gq(this)
for(s=0;r.n();)++s
return s},
gv(a){return!this.gq(this).n()},
gX(a){return!this.gv(this)},
L(a,b){return A.h2(this,b,A.i(this).h("c.E"))},
bZ(a,b,c){var s,r=A.i(this)
r.h("l(c.E)").a(b)
r.h("c.E()?").a(c)
for(r=this.gq(this);r.n();){s=r.gp()
if(b.$1(s))return s}r=c.$0()
return r},
C(a,b){var s,r
A.ao(b,"index")
s=this.gq(this)
for(r=b;s.n();){if(r===0)return s.gp();--r}throw A.d(A.ed(b,b-r,this,null,"index"))},
k(a){return A.i9(this,"(",")")}}
A.F.prototype={
k(a){return"MapEntry("+A.x(this.a)+": "+A.x(this.b)+")"}}
A.aL.prototype={
gB(a){return A.j.prototype.gB.call(this,0)},
k(a){return"null"}}
A.j.prototype={$ij:1,
M(a,b){return this===b},
gB(a){return A.cu(this)},
k(a){return"Instance of '"+A.cv(this)+"'"},
gT(a){return A.jA(this)},
toString(){return this.k(this)}}
A.b3.prototype={
gm(a){return this.a.length},
k(a){var s=this.a
return s.charCodeAt(0)==0?s:s},
$iiq:1}
A.cM.prototype={
G(a){var s,r,q,p,o,n,m=A.o([],t.g)
for(s=a.R(B.i),r=J.a4(s.a),s=new A.a2(r,s.b,s.$ti.h("a2<1>")),q=0;s.n();){p=r.gp()
o=p.at
n=Math.max(o.c,o.d)
o=!0
if(p.ax===B.t)if(!(p.x-p.w<4))o=n>=0.65&&p.y<12
if(o)++q
else B.a.l(m,p)}if(m.length===0)return new A.bZ(0,!1,!1)
s=new A.cU(m)
return new A.bZ(s.$1(new A.cW(this))*25+s.$1(new A.cX(this,a))*15+s.$1(new A.cY(this,a))*10,!0,m.length>=2)},
b0(a,b){var s=B.a.a4(a.c,b.d,b.e+1),r=A.h(s),q=r.h("f<1,b>"),p=A.y(new A.f(s,r.h("b(1)").a(new A.cN()),q),q.h("q.E"))
return B.a.F(p,0,new A.cO(B.a.K(p,new A.cP())/p.length),t.i)/p.length},
bx(a,b){var s=a.c,r=A.h(s),q=r.h("an<1,b>"),p=A.y(new A.an(new A.z(s,r.h("l(1)").a(new A.cQ(b,b.r.O(4e6))),r.h("z<1>")),r.h("b(1)").a(new A.cR()),q),q.h("c.E"))
if(p.length<2)return 0
return 1-B.b.j(Math.sqrt(B.a.F(p,0,new A.cS(B.a.K(p,new A.cT())/p.length),t.i)/p.length)/3,0,1)}}
A.cU.prototype={
$1(a){var s=this.a,r=A.h(s)
return new A.f(s,r.h("b(1)").a(t.bE.a(a)),r.h("f<1,b>")).K(0,new A.cV())/s.length},
$S:22}
A.cV.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.cW.prototype={
$1(a){t.F.a(a)
return B.b.j((a.x-a.w)/B.c.A(a.r.P(a.f).a,1000)*1000/2.5,0,1)},
$S:8}
A.cX.prototype={
$1(a){return 1-B.b.j(this.a.b0(this.b,t.F.a(a))/0.55,0,1)},
$S:8}
A.cY.prototype={
$1(a){return this.a.bx(this.b,t.F.a(a))},
$S:8}
A.cN.prototype={
$1(a){return t.K.a(a).e},
$S:3}
A.cP.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.cO.prototype={
$2(a,b){var s
A.n(a)
s=A.n(b)-this.a
return a+s*s},
$S:0}
A.cQ.prototype={
$1(a){t.K.a(a)
return a.a>this.a.e&&!a.b.c.c1(this.b)},
$S:1}
A.cR.prototype={
$1(a){return t.K.a(a).b.d},
$S:3}
A.cT.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.cS.prototype={
$2(a,b){var s
A.n(a)
s=A.n(b)-this.a
return a+s*s},
$S:0}
A.d0.prototype={
G(b4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0=this,b1=b4.R(B.n),b2=b1.$ti,b3=b2.h("z<c.E>")
b1=A.y(new A.z(b1,b2.h("l(c.E)").a(new A.dh()),b3),b3.h("c.E"))
b1.$flags=1
s=b1
b1=b4.R(B.E)
b1=A.y(b1,b1.$ti.h("c.E"))
b1.$flags=1
r=b1
b1=b4.R(B.h)
b1=A.y(b1,b1.$ti.h("c.E"))
b1.$flags=1
q=b1
p=A.o([],t.aS)
b1=t.n
o=A.o([],b1)
n=A.fR(t.N)
for(b2=s.length,m=0,l=0,k=0,j=0;j<s.length;s.length===b2||(0,A.Y)(s),++j){i=s[j]
if(!(i.as<=0)){b3=i.r
h=i.f
h=A.D(b3.b-h.b,b3.a-h.a).a<=0
b3=h}else b3=!0
if(b3){++m
continue}g=b0.bf(i,q)
b3=i.at
f=B.b.j(1-Math.max(b3.c*0.25,b3.d*0.45),0,1)
if(f<1||g)++k
e=b0.aI(b4,i)
d=b0.by(e)
if(e>=5){++l
n.l(0,i.a)}b3=g?0.6:1
B.a.l(o,d*f*b3)
B.a.l(p,new A.aC(b0.b3(b4,i,g),Math.max(1,i.w-i.x)))}c=p.length===0
b=c?150:150*b0.bL(p)
a=o.length===0
a0=a?100:100*(1-b0.b2(o))
a1=b0.be(b4,s)
a2=a1.length===0
a3=b0.bk(a1)
a4=a2?60:60*(1-a3)
b2=A.h(a1)
new A.z(a1,b2.h("l(1)").a(new A.di()),b2.h("z<1>")).gm(0)
a5=A.o([],b1)
for(b1=r.length,j=0;j<r.length;r.length===b1||(0,A.Y)(r),++j){a6=b0.bD(b4,r[j],s,n)
if(a6==null)++m
else B.a.l(a5,a6)}a7=a5.length===0
a8=a7?40:40*b0.V(a5)
a9=B.b.j(b+a0+a4+a8,0,350)
B.b.j(b,0,150)
B.b.j(a0,0,100)
B.b.j(a4,0,60)
B.b.j(a8,0,40)
return new A.dj(a9,s.length,a5.length,new A.d_(c,a,a2,a7))},
b3(a,a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=a.c,d=a0.d,c=a0.e,b=e.length
if(!(d<b))return A.a(e,d)
s=e[d].b.d
if(!(c<b))return A.a(e,c)
r=e[c].b.d
q=Math.max(0,s-r)
if(q<=0)return 0.5
p=this.aE(e,d,c,0.5)
o=this.aE(e,d,c,0.6)
if(!(p<b))return A.a(e,p)
n=Math.max(0,s-e[p].b.d)
if(!(o<b))return A.a(e,o)
m=Math.max(0,e[o].b.d-r)
l=B.b.j(n/q/0.55,0,1)
k=B.b.j((m/q-0.35)/0.37,0,1)
j=A.o([],t.n)
for(i=d;i<=c;++i){if(!(i<b))return A.a(e,i)
B.a.l(j,e[i].e)}b=B.b.j(this.aK(j)/0.9,0,1)
h=e[d].b.c.O(-5e6)
g=A.eu(e,0,A.ht(d,"count",t.S),A.h(e).c).a0(0,new A.d2(h,a,d,e))?0.08:0
f=a1?0.1:0
return B.b.j(0.4*B.b.j(l+g+f,0,1)+0.3*(1-b)+0.3*(1-k),0,1)},
aI(a,b){var s,r,q,p,o,n
for(s=b.d,r=b.e,q=a.c,p=q.length,o=0;s<=r;++s){if(!(s<p))return A.a(q,s)
n=q[s]
o=Math.max(o,Math.max(-n.b.x,-n.e))}return o},
by(a){var s=this
if(a<=1.5)return 0
if(a<=2.5)return s.a5(0,0.15,(a-1.5)/1)
if(a<=3.5)return s.a5(0.15,0.35,(a-2.5)/1)
if(a<=5)return s.a5(0.35,0.75,(a-3.5)/1.5)
return s.a5(0.75,1,(a-5)/5)},
b2(a){var s
t.o.a(a)
s=this.V(a)
if(a.length===1)return Math.min(s,0.35)
return B.b.j(s*1.35,0,1)},
be(a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a
t.B.a(a1)
s=a0.R(B.i)
r=s.$ti
q=r.h("z<c.E>")
s=A.y(new A.z(s,r.h("l(c.E)").a(new A.d3()),q),q.h("c.E"))
s.$flags=1
p=s
o=A.o([],t.h9)
for(s=p.length,r=a0.a,n=0;n<p.length;p.length===s||(0,A.Y)(p),++n){m=p[n]
l=m.x-m.w
if(l<3)continue
for(q=a1.length,k=m.r,j=k.a,k=k.b,i=m.y,h=m.e,g=0;g<a1.length;a1.length===q||(0,A.Y)(a1),++g){f=a1[g]
e=f.f
d=e.a
if(d>=j)c=d===j&&e.b<k
else c=!0
if(c)continue
if(r&&!A.e3(h,f.d,new A.d4(a0)))continue
b=A.D(e.b-k,d-j)
if(i<13.88888888888889)a=14
else a=i<25?10.5:7.5
if(b.a>A.D(0,B.b.a3(a*1000)).a)break
if(f.w-f.x<=0)continue
B.a.l(o,new A.ab(l,this.aI(a0,f),this.bl(f.at)))
break}}return o},
bk(a){var s,r,q,p,o
t.cT.a(a)
if(a.length===0)return 0
s=A.h(a)
r=s.h("b(1)")
s=s.h("f<1,b>")
q=this.V(new A.f(a,r.a(new A.d7(this)),s))
p=a.length
o=p===1?0.15:B.b.j(p/3,0.45,1)
return B.b.j(q*o*(1-this.V(new A.f(a,r.a(new A.d8()),s))),0,1)},
bD(a,b,a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=null
t.B.a(a0)
t.cq.a(a1)
s=this.bd(a,b.d)
if(s==null)return c
r=a.c
q=b.e
p=B.a.a4(r,s,q+1)
o=A.h(p)
if(new A.f(p,o.h("b(1)").a(new A.db()),o.h("f<1,b>")).K(0,B.R)<4.166666666666667)return c
p=A.h(a0)
o=p.h("z<1>")
n=A.fC(new A.z(a0,p.h("l(1)").a(new A.dc(b,a)),o),o.h("c.E"),t.M).bZ(0,new A.dd(),new A.de())
if(n!=null&&a1.aa(0,n.a))return c
p=r.length
if(s>>>0!==s||s>=p)return A.a(r,s)
o=r[s]
if(!(q<p))return A.a(r,q)
m=r[q].b
l=Math.max(0,o.b.d-m.d)
if(l<=0)return c
k=m.c.O(-2e6)
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
f=1-B.b.j((Math.max(0,r[j].b.d-r[q].b.d)/l-0.25)/0.30000000000000004,0,1)
e=A.o([],t.n)
for(i=j;i<=q;++i){if(!(i<p))return A.a(r,i)
B.a.l(e,r[i].e)}d=1-B.b.j(this.aK(e)/0.8,0,1)
return B.b.j(0.5*f+0.25*d+0.25*B.b.j((f+d)/2,0,1),0,1)},
bd(a,b){var s,r,q,p,o,n
for(s=a.c,r=s.length,q=a.a,p=b;p>=0;--p){o=!1
if(q)if(p<b){if(!(p<r))return A.a(s,p)
o=s[p]
n=p+1
if(!(n<r))return A.a(s,n)
n=!A.cd(o.b,s[n].b)
o=n}if(o)break
if(!(p<r))return A.a(s,p)
if(s[p].b.d>=4.166666666666667)return p}return null},
bf(a,b){t.B.a(b)
return a.ch.aa(0,B.r)||B.a.a0(a.CW,new A.d6(b))},
bl(a){var s=a.d,r=Math.max(a.c,s)
if(r<=0)return 0
return B.b.j(0.8*r+0.19999999999999996*s,0,1)},
aE(a,b,c,d){var s,r,q,p,o,n,m
t.X.a(a)
s=a.length
if(!(b<s))return A.a(a,b)
r=a[b].b.c
if(!(c<s))return A.a(a,c)
q=r.O(A.D(0,B.b.a3(B.c.A(a[c].b.c.P(r).a,1000)*d)).a)
for(r=q.a,p=q.b,o=b;o<=c;++o){if(!(o<s))return A.a(a,o)
n=a[o].b.c
m=n.a
if(m>=r)n=m===r&&n.b<p
else n=!0
if(!n)return o}return c},
bL(a){var s,r
t.ap.a(a)
s=t.i
r=B.a.F(a,0,new A.df(),s)
if(r<=0)return 1
return B.a.F(a,0,new A.dg(),s)/r},
V(a){var s,r,q
for(s=J.a4(t.bM.a(a)),r=0,q=0;s.n();){r+=s.gp();++q}return q===0?0:r/q},
aK(a){var s
t.o.a(a)
if(a.length<2)return 0
s=A.h(a)
return Math.sqrt(this.V(new A.f(a,s.h("b(1)").a(new A.d9(this.V(a))),s.h("f<1,b>"))))},
a5(a,b,c){return a+(b-a)*B.b.j(c,0,1)}}
A.dh.prototype={
$1(a){return t.F.a(a).ax===B.I},
$S:4}
A.di.prototype={
$1(a){return t.k.a(a).c>0},
$S:23}
A.d2.prototype={
$1(a){var s,r=this
t.K.a(a)
if(!a.b.c.c2(r.a))s=(!r.b.a||A.e3(a.a,r.c,new A.d1(r.d)))&&a.e<-0.08
else s=!1
return s},
$S:1}
A.d1.prototype={
$1(a){var s=this.a
if(!(a>=0&&a<s.length))return A.a(s,a)
return s[a].b},
$S:7}
A.d3.prototype={
$1(a){return t.F.a(a).ax===B.t},
$S:4}
A.d4.prototype={
$1(a){var s=this.a.c
if(!(a>=0&&a<s.length))return A.a(s,a)
return s[a].b},
$S:7}
A.d7.prototype={
$1(a){t.k.a(a)
return 0.6*B.b.j(a.a/9,0,1)+0.4*B.b.j(a.b/3.5,0,1)},
$S:11}
A.d8.prototype={
$1(a){return t.k.a(a).c},
$S:11}
A.db.prototype={
$1(a){return t.K.a(a).b.d},
$S:3}
A.dc.prototype={
$1(a){var s,r,q,p
t.F.a(a)
s=this.a
r=s.f.P(a.r)
q=a.e
s=s.d
if(q<=s){p=this.b
s=(!p.a||A.e3(q,s,new A.da(p)))&&Math.abs(r.a)<=3e6}else s=!1
return s},
$S:4}
A.da.prototype={
$1(a){var s=this.a.c
if(!(a>=0&&a<s.length))return A.a(s,a)
return s[a].b},
$S:7}
A.dd.prototype={
$1(a){return t.M.a(a)!=null},
$S:20}
A.de.prototype={
$0(){return null},
$S:33}
A.d6.prototype={
$1(a){return B.a.a0(this.a,new A.d5(A.G(a)))},
$S:37}
A.d5.prototype={
$1(a){return t.F.a(a).a===this.a},
$S:4}
A.df.prototype={
$2(a,b){return A.n(a)+t.J.a(b).b},
$S:9}
A.dg.prototype={
$2(a,b){A.n(a)
t.J.a(b)
return a+b.a*b.b},
$S:9}
A.d9.prototype={
$1(a){return Math.pow(A.n(a)-this.a,2)},
$S:17}
A.aC.prototype={}
A.ab.prototype={}
A.dj.prototype={}
A.d_.prototype={}
A.A.prototype={
gaO(){var s,r=this.a
if(isFinite(r)){s=this.b
r=isFinite(s)&&Math.abs(r)<=90&&Math.abs(s)<=180}else r=!1
return r}}
A.c4.prototype={
aL(a,b,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this,c=t.t
c.a(a2)
c.a(b0)
if(a6&&!a3.at)return d.a9(a,a3,B.a6,"Common road is below the 3000 metre comparison threshold.")
s=B.l.aM(b,a0,a1,a2,a3,a4,a7,a8,a9,b0)
if(!s.gaR()){c=s.a.a===B.d||s.b.a===B.d?B.a7:B.A
i=s.a.f
if(i==null)i=s.b.f
return d.a9(a,a3,c,i==null?"Common-road telemetry could not be extracted.":i)}try{c=d.b
h=c.ap(a,s.a.b)
r=h
g=c.ap(a,s.b.b)
q=g
p=q.d-r.d
o=r.d<q.d?r.d:q.d
c=o
if(typeof c!=="number")return c.ce()
if(c<=0)f=0
else{c=p
i=o
if(typeof c!=="number")return c.cb()
if(typeof i!=="number")return A.jC(i)
f=c/i}n=f
m=r.d>=q.d*1.01
l=q.d>=r.d*1.01
if(m)c=B.x
else c=l?B.y:B.z
return new A.c5(r,q,p,n,c,!0)}catch(e){c=A.ft(e)
if(c instanceof A.ck){k=c
return d.a9(a,a3,B.A,u.c)}else{j=c
c=d.a9(a,a3,B.a8,J.aT(j))
return c}}},
bR(a,b,c,d,e,f,g){var s=null
return this.aL(a,s,b,s,c,d,0,e,!0,s,f,s,g)},
a9(a,b,c,d){var s=null
return new A.c5(s,s,s,s,c,!1)}}
A.dk.prototype={}
A.ad.prototype={
D(){return"CommonRoadScoreComparisonOutcome."+this.b}}
A.c5.prototype={}
A.bc.prototype={
D(){return"CommonRoadTelemetryMappingStatus."+this.b}}
A.ae.prototype={}
A.dp.prototype={
gaR(){return this.a.a===B.m&&this.b.a===B.m}}
A.dl.prototype={
aM(a,b,c,d,e,f,g,h,i,j){var s,r,q=t.t
q.a(d)
q.a(j)
q=c==null?e.e:c
s=a==null?e.f:a
q=this.aB(s,f,b,e.c,q,d)
s=i==null?e.r:i
r=g==null?e.w:g
return new A.dp(q,this.aB(r,f,h,e.d,s,j))},
aN(a,b,c,d,e){var s=null
return this.aM(s,a,s,b,c,0,s,d,s,e)},
aB(b1,b2,b3,b4,b5,b6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0=null
t.t.a(b6)
s=J.ef(b6.slice(0),A.h(b6).c)
if(s.length===0)return new A.ae(B.B,B.f,b0,b0,0,"No canonical telemetry exists.")
r=this.bv(b3,b4)
if(r==null||r.b.length<2)return new A.ae(B.d,B.f,b0,b0,0,"Matched road section is unavailable.")
q=this.bw(b3,b4)
if(q==null)return new A.ae(B.d,B.f,b0,b0,0,"Matched road section offset is unavailable.")
p=r.b
o=A.fj(p)
n=A.is(r)
if(!isFinite(o)||o<=0||!isFinite(n)||n<=0)return new A.ae(B.d,B.f,b0,b0,0,"Matched section has no valid canonical offset axis.")
m=A.o([],t.cA)
for(l=b5-b2,k=b1+b2,j=0,i=0;i<p.length-1;){h=p[i];++i
g=p[i]
f=h.a
e=h.b
d=g.a
c=g.b
b=A.fK(f,e,d,c)
if(b<=0)continue
a=A.fk(o,j,n)
a0=j+b
if(q+A.fk(o,a0,n)>=l&&q+a<=k){a=f*3.141592653589793/180
a1=111320*Math.cos(a)
e=c-e
a2=e*3.141592653589793/180
a3=d*3.141592653589793/180
a=new A.bP(h,b,j,a1,B.b.U(Math.atan2(Math.sin(a2)*Math.cos(a3),Math.cos(a)*Math.sin(a3)-Math.sin(a)*Math.cos(a3)*Math.cos(a2))*180/3.141592653589793+360,360))
a.f=e*a1
a.r=(d-f)*111320
B.a.l(m,a)}j=a0}a4=A.o([],t.du)
for(a5=0;a5<s.length;++a5){a6=s[a5]
p=a6.a
if(isFinite(p)){f=a6.b
p=isFinite(f)&&Math.abs(p)<=90&&Math.abs(f)<=180}else p=!1
if(!p)continue
a7=this.bq(a6,m,q,o,n,b5,b1,b2)
p=!0
if(a7!=null)if(!(a7.a>35)){f=a7.c
if(!(f!=null&&f>60)){p=a7.b
p=p<l||p>k}}if(p)continue
B.a.l(a4,new A.a3(a5,a6,a7))}if(a4.length<2)return new A.ae(B.B,B.f,b0,b0,0,"Fewer than two canonical samples map to the common road.")
p=t.gM
p=A.y(new A.f(a4,t.fI.a(new A.dm()),p),p.h("q.E"))
p.$flags=1
a8=p
for(p=a8.length,a5=1;a5<p;++a5){l=a8[a5].c
k=a8[a5-1].c
f=l.a
e=k.a
if(f<=e)l=f===e&&l.b>k.b
else l=!0
if(!l)return new A.ae(B.d,B.f,b0,b0,0,"Mapped telemetry does not preserve strict time order.")}a9=B.b.j(1-B.a.F(a4,0,new A.dn(),t.i)/a4.length/35,0,1)
return new A.ae(B.m,A.a9(a8,t.u),B.a.gN(a4).a,B.a.ga1(a4).a,a9,b0)},
bv(a,b){var s,r,q=a.d,p=q.length
if(p!==0){for(s=0;s<p;++s){r=q[s]
if(r.a===b)return r}return null}return b===a.a+":geometry"?new A.a0(b,a.c,a.e):null},
bw(a,b){var s,r,q,p,o,n=a.d,m=n.length
if(m===0)return b===a.a+":geometry"?0:null
for(s=0,r=0;r<n.length;n.length===m||(0,A.Y)(n),++r){q=n[r]
if(q.a===b)return s
p=q.c
o=A.fj(q.b)
s+=isFinite(p)&&p>0?p:o}return null},
bq(a1,a2,a3,a4,a5,a6,a7,a8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0
t.fT.a(a2)
for(s=a2.length,r=a6-a8,q=a1.e,p=a1.b,o=a1.a,n=a7+a8,m=null,l=!1,k=0;k<a2.length;a2.length===s||(0,A.Y)(a2),++k){j=a2[k]
i=j.a
h=(p-i.b)*j.d
g=(o-i.a)*111320
i=j.f
i===$&&A.hC()
f=j.r
f===$&&A.hC()
e=i*i+f*f
d=e<=0?0:B.b.j((h*i+g*f)/e,0,1)
i=h-i*d
f=g-f*d
f=Math.sqrt(i*i+f*f)
i=a3+A.fk(a4,j.c+j.b*d,a5)
c=A.j0(q,j.e)
b=new A.eM(f,i,c)
a=i>=r&&i<=n
i=!0
if(m!=null)if(!(a&&!l))if(a===l){a0=m.a
if(!(f<a0))if(Math.abs(f-a0)<=0.000001){i=c==null?1/0:c
f=m.c
i=i<(f==null?1/0:f)}else i=!1}else i=!1
if(i){l=a
m=b}}return m}}
A.dm.prototype={
$1(a){return t.E.a(a).b},
$S:18}
A.dn.prototype={
$2(a,b){return A.n(a)+t.E.a(b).c.a},
$S:19}
A.bP.prototype={
gm(a){return this.b}}
A.a3.prototype={}
A.eM.prototype={}
A.c9.prototype={
G(a){var s,r,q,p,o,n,m=A.o([],t.df)
for(s=a.R(B.h),r=J.a4(s.a),s=new A.a2(r,s.b,s.$ti.h("a2<1>")),q=0,p=0;s.n();){o=r.gp()
n=this.b8(a,o)
if(n==null){++q
if(o.as<0.5)++p}else B.a.l(m,n)}if(m.length===0)return new A.c8(0,!1,!1)
s=new A.dw(this,m)
s=B.b.j(s.$1(new A.ds())*60+s.$1(new A.dt())*35+s.$1(new A.du())*35+s.$1(new A.dv())*20,0,150)
r=m.length
A.a9(m,t.h)
return new A.c8(s,!0,r>=2)},
b8(a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=null
if(a1.ax!==B.J||a1.as<0.5||a1.Q<15)return a
s=a1.cx
r=s.i(0,"totalHeadingChangeDegrees")
if(r==null)r=0
if(r<15)return a
q=a0.c
s=s.i(0,"apexIndex")
p=a1.d
o=a1.e
n=B.c.aT(B.c.j(B.b.a3(s==null?(a1.d+a1.e)/2:s),p,o))
m=Math.max(p,p+B.c.A(n-p,2))
l=Math.min(o,n+B.c.A(o-n,2))
k=b.aj(q,p,m)
j=b.aj(q,Math.max(p,n-1),Math.min(o,n+1))
i=b.aj(q,l,b.bs(q,o))
if(k<10)return a
s=a1.at
h=Math.max(s.c,s.d)
if(h>=0.6&&k<12)return a
g=r*3.141592653589793/180
f=g<=0?500:a1.Q/g
e=B.b.j(0.55*((r-15)/75)+0.45*((500-f)/475),0,1)
d=1-B.b.j((B.b.j((k-j)/k,0,1)-b.aF(0.08,0.48,e))/0.32,0,1)
if(h>0)d=b.aF(d,1,h*0.35)
s=B.b.j(b.aG(b.an(q,p,n),k)/0.18,0,1)
c=B.b.j(B.b.j(i/k,0,1.1)/0.95,0,1)
o=B.b.j(b.aG(b.an(q,p,o),k)/0.06,0,1)
A.a9(a1.CW,t.N)
return new A.a5(r,e,a1.as,d,1-s,c,1-o)},
bs(a,b){var s,r,q,p,o,n,m,l,k
t.X.a(a)
s=a.length
if(!(b<s))return A.a(a,b)
r=a[b].b.c.O(3e6)
for(q=b+1,p=r.a,o=r.b,n=b;q<s;m=q+1,n=q,q=m){l=a[q].b.c
k=l.a
if(k<=p)l=k===p&&l.b>o
else l=!0
if(l)break}return n},
an(a,b,c){var s,r,q
t.X.a(a)
s=A.o([],t.n)
for(r=a.length,q=b;q<=c;++q){if(!(q>=0&&q<r))return A.a(a,q)
s.push(a[q].b.d)}return s},
aj(a,b,c){var s,r,q,p=this.an(t.X.a(a),b,c)
B.a.aZ(p)
s=p.length
r=s/2|0
if((s&1)===1){if(!(r<s))return A.a(p,r)
s=p[r]}else{q=r-1
if(!(q>=0&&q<s))return A.a(p,q)
q=p[q]
if(!(r<s))return A.a(p,r)
q=(q+p[r])/2
s=q}return s},
aG(a,b){var s,r,q,p,o,n
t.o.a(a)
if(a.length<2||b<=0)return 0
s=B.a.K(a,new A.dr())
r=a.length
q=s/r
for(p=0,o=0;o<r;++o){n=a[o]-q
p+=n*n}return Math.sqrt(p/r)/b},
bK(a){t.h.a(a)
return Math.min(1.5,Math.max(0.25,a.w*(0.5+a.r)*(a.e/30)))},
aF(a,b,c){return a+(b-a)*B.b.j(c,0,1)}}
A.dw.prototype={
$1(a){var s,r,q,p,o,n,m,l,k
t.bk.a(a)
s=this.b
r=A.h(s)
q=r.h("f<1,b>")
r=A.y(new A.f(s,r.h("b(1)").a(this.a.gbJ()),q),q.h("q.E"))
r.$flags=1
p=r
r=t.i
o=B.a.F(p,0,new A.dx(),r)
n=s.length
m=A.o(new Array(n),t.n)
for(l=0;l<n;++l){if(!(l<s.length))return A.a(s,l)
q=a.$1(s[l])
if(!(l<p.length))return A.a(p,l)
k=p[l]
if(typeof q!=="number")return q.ar()
m[l]=q*k}return B.a.F(m,0,new A.dy(),r)/o},
$S:21}
A.dx.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.dy.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.ds.prototype={
$1(a){return a.x},
$S:5}
A.dt.prototype={
$1(a){return a.y},
$S:5}
A.du.prototype={
$1(a){return a.z},
$S:5}
A.dv.prototype={
$1(a){return a.Q},
$S:5}
A.dr.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.c8.prototype={}
A.a5.prototype={}
A.dD.prototype={
bX(b4,b5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3=null
t.Y.a(b4)
if(b4.length===0)return B.L
s=t.I
r=new A.bw(A.bx(A.ih(b3),b3,!1,s),t.d9)
q=A.o([],t.W)
for(p=0,o=0,n=0,m=0,l=0,k=0,j=0;j<b4.length;++j){i=b4[j]
h=!1
if(b5)if(!i.y){g=i.Q
if(g!=="unavailable"&&g!=="held_estimate"){if(j>0){h=b4[j-1].Q
h=!(h!=="unavailable"&&h!=="held_estimate")}}else h=!0}else h=!0
if(h){r.bQ(0)
p=0
o=0
n=0
m=0
l=0
k=0}B.a.t(r.a,r.c,j)
h=r.c
g=r.a.length
h=(h+1&g-1)>>>0
r.c=h
if(r.b===h){f=A.bx(g*2,b3,!1,s)
h=r.a
g=r.b
e=h.length-g
B.a.au(f,0,e,h,g)
B.a.au(f,e,e+r.b,r.a,0)
r.b=0
r.c=r.a.length
r.a=f}++r.d
h=i.d
p+=h
o+=h*h
if(h<=8.333333333333334)++n
g=i.c
d=g.O(-5e6)
c=d.a
b=d.b
for(;;){a=r.c
a0=r.b
a1=r.a
a2=a1.length
if((a-a0&a2-1)>>>0>1){if(a0===a)A.aE(A.aX())
if(!(a0<a2))return A.a(a1,a0)
a=a1[a0]
a=B.a.i(b4,a==null?A.X(a):a).c
a0=a.a
if(a0>=c)a=a0===c&&a.b<b
else a=!0}else a=!1
if(!a)break
a=r.b
if(a===r.c)A.aE(A.aX());++r.d
a0=r.a
if(!(a<a0.length))return A.a(a0,a)
a3=a0[a]
if(a3==null)a3=A.X(a3)
B.a.t(a0,a,b3)
r.b=(r.b+1&r.a.length-1)>>>0
a=B.a.i(b4,a3).d
p-=a
o-=a*a
if(a<=8.333333333333334)--n}a4=(r.c-r.b&r.a.length-1)>>>0
a5=p/a4
a6=B.b.j(o/a4-a5*a5,0,1/0)
c=i.as
if(!c||i.y)m=0
else{b=i.x
m=j===0?b:m+0.35*(b-m)}a7=0
a8=0
if(j>0){b=j-1
if(!(b<b4.length))return A.a(b4,b)
a9=b4[b]
b=a9.c
b0=A.D(g.b-b.b,g.a-b.a).a/1e6
g=!i.y
b1=0
b2=0
if(!g||!c){k=b2
l=b1}else if(b0>0)if(h<=1.3888888888888888){l+=b0
k=b2}else{k+=b0
l=b1}if(b0>0&&g&&c&&h>=4){a7=this.bz(a9.e,i.e)
a8=Math.abs(a7)/b0}}B.a.l(q,new A.T(j,i,a6,m,a7,a8))}return q},
bz(a,b){if(!isFinite(a)||!isFinite(b))return 0
return B.b.U(b-a+540,360)-180}}
A.cb.prototype={
bO(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this
t.t.a(c)
s=J.ef(c.slice(0),A.h(c).c)
r=B.V.bX(b?A.i7(s):s,b)
if(r.length===0)return new A.ca(b,B.L,B.aK,B.aL)
q=d.bb(r)
p=d.Z(r,new A.dG(),new A.dH(),B.ai,new A.dI(d,r))
o=d.Z(r,new A.dS(),new A.dT(),B.H,new A.dU(r))
n=d.Z(r,new A.dV(),new A.dW(),B.H,new A.dX(r))
m=d.gbg()
l=d.Z(r,m,m,B.ak,new A.dY())
k=d.Z(r,new A.dZ(),new A.dJ(),B.ah,new A.dK(d,r))
j=A.bx(r.length,B.F,!1,t.fR)
d.a8(j,l,B.ac)
d.a8(j,o,B.ab)
d.a8(j,n,B.ad)
d.a8(j,p,B.G)
m=A.h(p)
i=t.F
m=A.y(new A.f(p,m.h("k(1)").a(new A.dL(d,a,r,q)),m.h("f<1,k>")),i)
h=A.h(o)
B.a.I(m,new A.f(o,h.h("k(1)").a(new A.dM(d,a,r,q)),h.h("f<1,k>")))
h=A.h(n)
B.a.I(m,new A.f(n,h.h("k(1)").a(new A.dN(d,a,r,q)),h.h("f<1,k>")))
h=A.h(k)
B.a.I(m,new A.f(k,h.h("k(1)").a(new A.dO(d,a,r,q)),h.h("f<1,k>")))
g=A.h(l)
B.a.I(m,new A.f(l,g.h("k(1)").a(new A.dP(d,a,r,q)),g.h("f<1,k>")))
B.a.av(m,new A.dQ())
g=A.a9(r,t.K)
f=t.gE
e=A.a9(d.b6(j,r,b),f)
A.a9(new A.f(k,h.h("@(1)").a(new A.dR(r)),h.h("f<1,@>")),f)
A.a9(q,t.fo)
return new A.ca(b,g,e,A.a9(d.bu(m),i))},
bh(a){return a.b.d>=5&&Math.abs(a.e)<=0.3&&a.d<=1.5},
Z(a,b,c,d,e){var s,r,q,p,o,n,m,l,k,j=null
t.X.a(a)
s=t.d1
s.a(c)
s.a(b)
t._.a(e)
r=A.o([],t.dO)
for(q=j,p=q,o=0;o<a.length;++o){n=a[o]
s=n.b
if(!s.y){m=s.Q
m=!(m!=="unavailable"&&m!=="held_estimate")}else m=!0
l=j
k=j
if(m){if(p!=null&&q!=null)this.ai(r,a,p,q,d,e)
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
if(A.D(s.b-m.b,s.a-m.a).a<=1e6)continue
this.ai(r,a,p,q,d,e)
p=c.$1(n)?o:j
q=p}if(p!=null&&q!=null)this.ai(r,a,p,q,d,e)
return r},
ai(a,b,c,d,e,f){var s,r,q
t.e.a(a)
t.X.a(b)
A.X(d)
t._.a(f)
s=new A.U(c,d)
r=b.length
if(!(d<r))return A.a(b,d)
q=b[d]
if(!(c<r))return A.a(b,c)
if(q.b.c.P(b[c].b.c).a>=e.a&&f.$1(s))B.a.l(a,s)},
bb(b4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3
t.X.a(b4)
s=A.o([],t.gI)
for(r=0,q=0;q<b4.length;++q){p=b4[q].b
o=p.Q
if(!(o!=="unavailable"&&o!=="held_estimate")){B.a.l(s,B.Q)
r=q+1
continue}if(p.y)r=q
n=p.c.O(-45e6)
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
if(A.D(p.b-m.b,p.a-m.a).a<8e6){B.a.l(s,B.Q)
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
a8=B.b.j(1-a5/8.333333333333334,0,1)
a9=B.b.j(a6/25,0,1)
b0=B.b.j(e/4,0,1)
b1=B.b.j(d/4,0,1)
b2=B.b.j(a7*0.45+a8*0.35+a9*0.2,0,1)
b3=B.b.j(a7*0.3+f/a4*0.25+b0*0.25+b1*0.2,0,1)
if(b3>=0.62)B.a.l(s,new A.aq(B.b0,b2,b3))
else if(b2>=0.55)B.a.l(s,new A.aq(B.b_,b2,b3))
else{B.b.j(1-Math.max(b2,b3),0,1)
B.a.l(s,new A.aq(B.aZ,b2,b3))}}return s},
a_(a,b,a0,a1,a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=this
t.X.a(a1)
t.dr.a(a2)
for(s=a0.a,r=a0.b,q=a1.length,p=s,o=0,n=1/0;p<=r;++p){if(!(p<q))return A.a(a1,p)
m=a1[p].b.d
o=Math.max(o,m)
n=Math.min(n,m)}l=s+B.c.A(r-s,2)
if(!(l>=0&&l<a2.length))return A.a(a2,l)
k=a2[l]
j=A.fR(t.V)
i=c.bE(k.a)
if(i!=null)j.l(0,i)
h=c.bm(b)
g=A.ay(t.N,t.i)
if(b===B.h){g.t(0,"totalHeadingChangeDegrees",c.aD(a1,s,r))
g.t(0,"apexIndex",c.b9(a1,a0))
j.l(0,B.r)}else j.l(0,c.ao(b))
q=a1.length
if(!(r<q))return A.a(a1,r)
f=a1[r]
if(!(s<q))return A.a(a1,s)
e=B.b.j(B.c.A(f.b.c.P(a1[s].b.c).a,1000)/1000/5,0.5,1)
f=a1.length
if(!(s<f))return A.a(a1,s)
q=a1[s].b
if(!(r<f))return A.a(a1,r)
f=a1[r].b
d=n===1/0?0:n
return A.fI(e,j,c.af(a1,s,r),a,r,f.d,f.c,a+":"+b.b+":"+s+":"+r,o,g,d,B.aM,A.ie([h],t.c5),h,s,q.d,q.c,k,b)},
bu(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
t.B.a(a)
s=t.N
r=A.ay(s,t.dg)
for(q=a.length,p=t.s,o=0;n=a.length,o<n;a.length===q||(0,A.Y)(a),++o)r.t(0,a[o].a,A.o([],p))
s=A.ay(s,t.fj)
for(q=t.V,o=0;p=a.length,o<p;a.length===n||(0,A.Y)(a),++o){m=a[o]
p=A.fQ(q)
p.I(0,m.ch)
s.t(0,m.a,p)}for(q=p,l=0;l<q;q=g,l=j){if(!(l<q))return A.a(a,l)
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
g.l(0,this.ao(f.c))
e=s.i(0,e)
e.toString
e.l(0,this.ao(p))}}q=A.h(a)
p=q.h("f<1,k>")
s=A.y(new A.f(a,q.h("k(1)").a(new A.dF(s,r)),p),p.h("q.E"))
s.$flags=1
return s},
bm(a){var s
switch(a.a){case 0:s=B.at
break
case 1:s=B.t
break
case 2:s=B.I
break
case 3:s=B.J
break
case 4:s=B.K
break
default:s=null}return s},
ao(a){var s
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
bE(a){var s=null
switch(a.a){case 3:s=B.as
break
case 2:s=B.ar
break
case 1:s=B.aq
break
case 0:break}return s},
a8(a,b,c){var s,r,q,p,o
t.G.a(a)
t.e.a(b)
for(s=b.length,r=0;r<b.length;b.length===s||(0,A.Y)(b),++r){q=b[r]
for(p=q.a,o=q.b;p<=o;++p)B.a.t(a,p,c)}},
b6(a,b,c){var s,r,q,p,o,n,m
t.G.a(a)
t.X.a(b)
s=A.o([],t.v)
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
B.a.l(s,new A.ah(o,q,n))
q=p}return s},
af(a,b,c){var s,r,q
t.X.a(a)
for(s=b+1,r=a.length,q=0;s<=c;++s){if(!(s<r))return A.a(a,s)
q+=a[s].b.w}return q},
aD(a,b,c){var s,r,q
t.X.a(a)
for(s=b+1,r=a.length,q=0;s<=c;++s){if(!(s<r))return A.a(a,s)
q+=Math.abs(a[s].f)}return q},
b9(a,b){var s,r,q,p,o,n
t.X.a(a)
s=b.a
for(r=b.b,q=a.length,p=s,o=0;p<=r;++p){if(!(p<q))return A.a(a,p)
n=a[p].r
if(n>o){o=n
s=p}}return s}}
A.dH.prototype={
$1(a){return a.b.d<=1.3888888888888888},
$S:1}
A.dG.prototype={
$1(a){return a.b.d<=1.3888888888888888},
$S:1}
A.dI.prototype={
$1(a){return this.a.af(this.b,a.a,a.b)<=8},
$S:6}
A.dT.prototype={
$1(a){return a.e>=0.35},
$S:1}
A.dS.prototype={
$1(a){return a.e>=0.15},
$S:1}
A.dU.prototype={
$1(a){var s,r=this.a,q=a.b,p=r.length
if(!(q<p))return A.a(r,q)
q=r[q]
s=a.a
if(!(s<p))return A.a(r,s)
return q.b.d-r[s].b.d>=2},
$S:6}
A.dW.prototype={
$1(a){return a.e<=-0.35},
$S:1}
A.dV.prototype={
$1(a){return a.e<=-0.15},
$S:1}
A.dX.prototype={
$1(a){var s,r=this.a,q=a.a,p=r.length
if(!(q<p))return A.a(r,q)
q=r[q]
s=a.b
if(!(s<p))return A.a(r,s)
return q.b.d-r[s].b.d>=2},
$S:6}
A.dY.prototype={
$1(a){return!0},
$S:6}
A.dJ.prototype={
$1(a){return a.b.d>=4&&a.r>=4},
$S:1}
A.dZ.prototype={
$1(a){return a.b.d>=4&&a.r>=2},
$S:1}
A.dK.prototype={
$1(a){var s=this.a,r=this.b,q=a.a,p=a.b
return s.aD(r,q,p)>=15&&s.af(r,q,p)>=15},
$S:6}
A.dL.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.E,t.Q.a(a),s.c,s.d)},
$S:2}
A.dM.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.i,t.Q.a(a),s.c,s.d)},
$S:2}
A.dN.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.n,t.Q.a(a),s.c,s.d)},
$S:2}
A.dO.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.h,t.Q.a(a),s.c,s.d)},
$S:2}
A.dP.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.j,t.Q.a(a),s.c,s.d)},
$S:2}
A.dQ.prototype={
$2(a,b){var s,r=t.F
r.a(a)
r.a(b)
s=B.c.E(a.d,b.d)
return s!==0?s:B.c.E(a.c.a,b.c.a)},
$S:24}
A.dR.prototype={
$1(a){var s,r,q,p
t.Q.a(a)
s=a.a
r=a.b
q=this.a
p=q.length
if(!(s<p))return A.a(q,s)
if(!(r<p))return A.a(q,r)
return new A.ah(B.ae,s,r)},
$S:25}
A.dF.prototype={
$1(a){var s,r,q
t.F.a(a)
s=a.a
r=this.a.i(0,s)
r.toString
r=A.ig(r,t.V)
q=this.b.i(0,s)
q.toString
q=A.a9(q,t.N)
r=t.eN.a(new A.bL(r,t.f4))
t.gJ.a(q)
return A.fI(a.as,r,a.Q,a.b,a.e,a.x,a.r,s,a.y,a.cx,a.z,q,a.ay,a.ax,a.d,a.w,a.f,a.at,a.c)},
$S:26}
A.U.prototype={}
A.e_.prototype={
D(){return"DriveScoreAlgorithmVersion."+this.b}}
A.bf.prototype={
ap(a,b){var s,r
t.t.a(b)
s=J.ef(b.slice(0),A.h(b).c)
if(s.length<2)throw A.d(B.a0)
if(B.a.a0(s,new A.e0()))throw A.d(B.a1)
switch(a.a){case 0:r=this.b5(s,!1)
break
default:r=null}return r},
b5(a,b){var s,r,q,p,o,n,m=B.W.bO("in-memory-drive-score",b,t.Y.a(a)),l=B.T.G(m),k=B.a4.G(m),j=B.U.G(m),i=B.Z.G(m),h=B.S.G(m),g=B.a5.G(m),f=l.z
f=f.a&&f.b&&f.c&&f.d
s=l.f>0||l.r>0
r=k.as.a
q=t.N
p=t.R
o=A.am(["brakingAnticipation",new A.C(l.a,350,!f,s),"tempoPerformance",new A.C(k.a,150,r,r),"corneringPerformance",new A.C(j.a,150,j.y,j.z),"drivingSmoothness",new A.C(i.a,100,i.b,i.c),"accelerationPerformance",new A.C(h.a,50,h.e,h.f),"transitionControl",new A.C(g.a,50,g.e,g.f)],q,p)
n=B.a_.aY(k.r,new A.al(o,A.i(o).h("al<2>")))
p=A.fO(q,p)
p.I(0,o)
p.t(0,"drivingEndurance",new A.C(n.a,150,n.f,n.r))
return B.Y.bN(p)}}
A.e0.prototype={
$1(a){return!t.u.a(a).gaO()},
$S:27}
A.ck.prototype={
k(a){return u.c}}
A.ee.prototype={
k(a){return"Canonical telemetry contains an invalid coordinate."}}
A.e1.prototype={
bN(a){var s,r,q,p,o,n,m,l,k,j,i
t.cC.a(a)
s=t.N
r=t.D
q=A.ay(s,r)
for(p=new A.br(a,A.i(a).h("br<1,2>")).gq(0),o=0;p.n();){n=p.d
m=n.b
l=m.c
if(l&&m.d)k=B.D
else k=!l?B.a9:B.aa
l=k===B.D
j=l?m.a:m.b*0.75
if(l)++o
q.t(0,n.a,new A.ag(j,k))}i=B.b.j(new A.al(q,q.$ti.h("al<2>")).F(0,0,new A.e2(),t.i),0,1000)
p=B.b.a3(i)
return new A.cc("legacy_v1",1,null,i,B.b.j(o/a.a,0,1),p,1,A.fE(a,s,t.R),A.fE(q,s,r),"Actual scores plus neutral contributions for unavailable evidence.")}}
A.e2.prototype={
$2(a,b){return A.n(a)+t.D.a(b).b},
$S:28}
A.bg.prototype={
D(){return"DriveScoreContributionSource."+this.b}}
A.C.prototype={}
A.ag.prototype={}
A.cc.prototype={}
A.a7.prototype={
D(){return"DrivingPhase."+this.b}}
A.b4.prototype={
D(){return"TrafficRegime."+this.b}}
A.aI.prototype={
D(){return"DrivingEventType."+this.b}}
A.aw.prototype={
D(){return"EventOwnerDomain."+this.b}}
A.P.prototype={
D(){return"EventContextTag."+this.b}}
A.T.prototype={}
A.aq.prototype={}
A.ah.prototype={}
A.k.prototype={}
A.ca.prototype={
R(a){var s=this.r,r=A.h(s)
return new A.z(s,r.h("l(1)").a(new A.dE(a)),r.h("z<1>"))}}
A.dE.prototype={
$1(a){return t.F.a(a).c===this.a},
$S:4}
A.e4.prototype={
G(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=A.o([],t.g)
for(s=a.R(B.j),r=J.a4(s.a),s=new A.a2(r,s.b,s.$ti.h("a2<1>")),q=0;s.n();){p=r.gp()
o=p.at
n=Math.max(o.c,o.d)
if(p.ax===B.K){o=p.r
m=p.f
o=A.D(o.b-m.b,o.a-m.a).a<8e6||p.y<8.333333333333334||n>=0.65}else o=!0
if(o)++q
else B.a.l(d,p)}s=d.length
if(s===0)return new A.ce(0,!1,!1)
for(l=0,k=B.af,j=0,i=0;i<d.length;d.length===s||(0,A.Y)(d),++i){h=d[i]
r=h.r
p=h.f
g=r.a-p.a
f=r.b-p.b
l+=A.D(f,g).a
if(A.D(f,g).a>k.a)k=A.D(f,g)
j+=B.b.j(1-this.bI(a,h)/4,0,1)*A.D(f,g).a}e=A.D(l,0)
s=B.b.j((0.55*this.ba(e,B.al,B.ag,B.aj)+0.45*(j/l))*100,0,1)
r=e.a
B.c.A(r,1e6)
return new A.ce(s*100,!0,r>=3e7)},
bI(a,b){var s=B.a.a4(a.c,b.d,b.e+1),r=A.h(s),q=r.h("f<1,b>"),p=A.y(new A.f(s,r.h("b(1)").a(new A.e5()),q),q.h("q.E"))
return B.a.F(p,0,new A.e6(B.a.K(p,new A.e7())/p.length),t.i)/p.length},
ba(a,b,c,d){var s,r=a.a,q=b.a
if(r<=q)return 0
s=c.a
if(r<=s)return 0.75*(r-q)/(s-q)
return 0.75+0.25*B.b.j((r-s)/(d.a-s),0,1)}}
A.e5.prototype={
$1(a){return t.K.a(a).b.d},
$S:3}
A.e7.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.e6.prototype={
$2(a,b){var s
A.n(a)
s=A.n(b)-this.a
return a+s*s},
$S:0}
A.e8.prototype={
aY(a,b){var s,r,q,p,o
t.ff.a(b)
s=b.$ti
r=s.h("z<c.E>")
q=A.y(new A.z(b,s.h("l(c.E)").a(new A.e9()),r),r.h("c.E"))
if(a<5||q.length===0)return new A.cf(0,!1,!1)
p=this.bo(a)
s=A.h(q)
o=B.b.j(new A.f(q,s.h("b(1)").a(new A.ea()),s.h("f<1,b>")).K(0,new A.eb())/q.length,0.15,1)
B.b.j(q.length/6,0,1)
s=a>=50&&q.length>=3
return new A.cf(p*o*150,!0,s)},
bo(a){if(a<=5)return a/5*0.15
if(a<=50)return 0.15+(a-5)/45*0.6
return B.b.j(0.75+(a-50)/100*0.25,0,1)}}
A.e9.prototype={
$1(a){t.R.a(a)
return a.c&&a.d},
$S:29}
A.ea.prototype={
$1(a){t.R.a(a)
return a.a/a.b},
$S:30}
A.eb.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.cf.prototype={}
A.ce.prototype={}
A.bZ.prototype={}
A.a8.prototype={
D(){return"DrivingTransitionType."+this.b}}
A.Z.prototype={}
A.cA.prototype={}
A.b0.prototype={
D(){return"LocalRoadWindowState."+this.b}}
A.by.prototype={
D(){return"LocalRoadRegionAnalysisStatus."+this.b}}
A.az.prototype={}
A.aK.prototype={}
A.bz.prototype={}
A.en.prototype={
bP(a,b,c,d,e,f,g){var s,r,q,p=t.t
p.a(e)
p.a(c)
if(!f.at)return new A.bz(B.aR,B.M,B.N)
if(f.as<0.65)return new A.bz(B.aS,B.M,B.N)
s=B.l.aN(d,e,f,b,c)
r=this.b4(a,b,s.b.b,d,s.a.b,f,!1)
q=this.bM(a,f,!1,r)
return new A.bz(B.aQ,A.a9(r,t.l),A.a9(q,t.w))},
b4(a,b,c,d,a0,a1,a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=t.t
e.a(a0)
e.a(c)
s=A.o([],t.d)
for(r=a1.z,e=a1.e,q=a1.f,p=a1.r,o=a1.w,n=f.a,m=0;m<r;m=l){l=m+100
l=l<r?l:r
k=f.a7(e,q,r,m)
j=f.a7(e,q,r,l)
i=f.a7(p,o,r,m)
h=f.a7(p,o,r,l)
g=n.aL(a,j,d,k,a0,a1,5,!1,!1,h,b,i,c)
B.a.l(s,new A.az(m,l,k,j,i,h,f.bC(g),g))}return s},
bM(a,b,c,d){var s,r,q,p,o,n,m,l,k,j,i={}
t.fB.a(d)
s=A.o([],t.r)
i.a=null
i.b=0
r=new A.eo(i,s,b,a)
for(q=d.length,p=0;p<d.length;d.length===q||(0,A.Y)(d),++p){o=d[p]
if(o.r===B.O){n=i.a
m=o.b
l=o.d
k=o.f
if(n==null)i.a=new A.eW(o.a,m,o.c,l,o.e,k)
else{n.b=m
n.d=l
n.f=k;++n.w}i.b=0
continue}if(i.a==null)continue
j=i.b+(o.b-o.a)
i.b=j
if(j>200.000001)r.$0()}r.$0()
return s},
bC(a){var s,r
if(!a.y)return B.P
s=a.x
A:{if(B.x===s){r=B.aT
break A}if(B.y===s){r=B.O
break A}if(B.z===s){r=B.aU
break A}r=B.P
break A}return r},
a7(a,b,c,d){if(c<=0)return a
return a+(b-a)*d/c}}
A.eo.prototype={
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
B.a.l(j.b,new A.aK(p.a,p.b,o,n,m,l,r,s,q,j.d,k,h.w))}i.a=null
i.b=0},
$S:31}
A.eW.prototype={}
A.a_.prototype={}
A.a0.prototype={}
A.ev.prototype={
G(b3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9=this,b0=1e6,b1=b3.c,b2=b1.length
if(b2<2)return new A.bI(0,0,B.aX)
for(s=b3.a,r=b2-1,q=!s,p=0,o=0,n=0,m=0,l=0,k=0,j=0;j<b2;++j){if(q)m+=b1[j].b.w
if(j===r)continue
i=b1[j]
h=j+1
if(!(h<b2))return A.a(b1,h)
h=b1[h].b
g=h.c
f=i.b
e=f.c
g=A.D(g.b-e.b,g.a-e.a).a
e=!0
if(g>0)if(s){if(A.cd(f,h)){d=f.Q
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
n+=h.w}}}else if(a9.bi(b3,j))o+=g
else{p+=g
n+=h.w}}b=s?A.D(k,0):B.a.ga1(b1).b.c.P(B.a.gN(b1).b.c)
a=A.D(p,0)
a0=A.D(o,0)
a1=m/1000
s=a.a
a2=s<=0?0:n/(s/1e6)*3.6
a3=a9.bH(b3)
a4=b2>=6&&s>=9e7&&m>=1000
B.b.j(Math.min(b2/6,Math.min(s/9e7,a1)),0,1)
if(!a4){B.b.aV(a1,2)
B.c.A(s,b0)
return new A.bI(0,a1,new A.bH(!1))}b2=b.a
a5=b2<=0?0:m/(b2/1e6)*3.6
a6=a9.am(a2,B.aF,60)
a7=a3.b<2?0:a9.am(a3.a*3.6,B.aN,30)
a8=B.b.j(a6+a7+a9.am(a5,B.aB,60),0,150)
B.b.aV(a1,2)
B.c.A(s,b0)
B.c.A(a0.a,b0)
return new A.bI(a8,a1,new A.bH(!0))},
bi(a,b){var s,r,q,p
if(this.bn(a.d,b)===B.G)return!0
s=a.c
r=s.length
if(!(b<r))return A.a(s,b)
q=s[b]
p=b+1
if(!(p<r))return A.a(s,p)
p=s[p]
return q.b.d<=1.3888888888888888&&p.b.d<=1.3888888888888888},
bn(a,b){var s,r,q
t.au.a(a)
for(s=a.length,r=0;r<s;++r){q=a[r]
if(b>=q.b&&b<=q.c)return q.a}return B.F},
bH(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=a.c
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
i=!A.cd(i.b,f[g].b)}else i=!1
if(i)continue
if(Math.abs(f[j].b.d-m)<=10)++l}if(l<2)continue
if(m>q){p=l
q=m}}return new A.eV(q,p)},
am(a,b,c){var s,r,q,p,o,n
t.gj.a(b)
if(a<=B.a.gN(B.a.gN(b)))return 0
for(s=b.length,r=1;r<s;++r){q=b[r-1]
p=b[r]
if(a<=B.a.gN(p)){s=B.a.gN(q)
o=B.a.gN(p)
n=B.a.gN(q)
return B.b.j(c*(B.a.ga1(q)+(B.a.ga1(p)-B.a.ga1(q))*((a-s)/(o-n))),0,c)}}return c}}
A.eV.prototype={}
A.bI.prototype={}
A.bH.prototype={}
A.ew.prototype={
G(a0){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=a0.r,a=A.o([],t.c)
for(s=b.length,r=a0.a,q=0;p=q+2,p<s;){if(!(q<s))return A.a(b,q)
o=b[q];++q
if(!(q<s))return A.a(b,q)
n=b[q]
m=b[p]
l=this.bG(o,n,m)
if(l!=null){p=n.at
k=Math.max(p.c,p.d)
p=!1
if(m.y>=8.333333333333334)if(k<0.65){j=n.f
i=o.r
if(A.D(j.b-i.b,j.a-i.a).a<=8e6){p=m.f
j=n.r
j=A.D(p.b-j.b,p.a-j.a).a<=8e6
p=j}}p=!p}else p=!0
if(p)continue
if(r&&!A.e3(o.d,m.e,new A.eA(a0)))continue
B.a.l(a,new A.Z(l,this.br(a0,m)))}if(a.length===0)return B.b1
h=new A.eC(a)
g=h.$2(B.o,20)
f=h.$2(B.p,20)
e=h.$2(B.q,10)
s=A.ay(t.am,t.S)
for(r=t.eF,p=t.dA,d=0;d<3;++d){c=B.aP[d]
s.t(0,c,new A.z(a,r.a(new A.eB(c)),p).gm(0))}return new A.cA(g+f+e,!0,a.length>=2)},
bG(a,b,c){var s,r
if(c.c!==B.j)return null
s=a.c
r=s===B.j
if(r&&b.c===B.n)return B.o
if(r&&b.c===B.h)return B.p
if(s===B.i)return B.q
return null},
br(a,b){var s=B.a.a4(a.c,b.d,b.e+1),r=A.h(s)
return B.b.j(1-Math.sqrt(B.a.F(s,0,new A.ex(new A.f(s,r.h("b(1)").a(new A.ey()),r.h("f<1,b>")).K(0,new A.ez())/s.length),t.i)/s.length)/4,0,1)}}
A.eA.prototype={
$1(a){var s=this.a.c
if(!(a>=0&&a<s.length))return A.a(s,a)
return s[a].b},
$S:7}
A.eC.prototype={
$2(a,b){var s=this.a,r=A.h(s),q=r.h("z<1>"),p=A.y(new A.z(s,r.h("l(1)").a(new A.eD(a)),q),q.h("c.E"))
if(p.length===0)return 0
s=A.h(p)
return new A.f(p,s.h("b(1)").a(new A.eE()),s.h("f<1,b>")).K(0,new A.eF())/p.length*b},
$S:49}
A.eD.prototype={
$1(a){return t.f.a(a).a===this.a},
$S:14}
A.eE.prototype={
$1(a){return t.f.a(a).e},
$S:34}
A.eF.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.eB.prototype={
$1(a){return t.f.a(a).a===this.a},
$S:14}
A.ey.prototype={
$1(a){return t.K.a(a).b.d},
$S:3}
A.ez.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.ex.prototype={
$2(a,b){var s
A.n(a)
s=t.K.a(b).b.d-this.a
return a+s*s},
$S:48}
A.eJ.prototype={}
A.f5.prototype={
$1(a){var s=J.bX(a),r=A.G(s.i(a,"id"))
s=J.cL(t.j.a(s.i(a,"geometry")),new A.f4(),t.A)
s=A.y(s,s.$ti.h("q.E"))
return new A.a0(r,s,A.t(t.P.a(a).i(0,"distanceMeters")))},
$S:36}
A.f4.prototype={
$1(a){t.P.a(a)
return new A.a_(A.t(a.i(0,"latitude")),A.t(a.i(0,"longitude")))},
$S:10}
A.f6.prototype={
$1(a){return t.p.a(a).b},
$S:38}
A.f7.prototype={
$2(a,b){return A.n(a)+t.p.a(b).c},
$S:39}
A.fc.prototype={
$1(a){var s,r,q,p,o,n,m,l,k,j,i,h,g="gap_duration_micros"
t.P.a(a)
s=A.t(a.i(0,"latitude"))
r=A.t(a.i(0,"longitude"))
q=A.i6(A.G(a.i(0,"timestamp")))
p=A.t(a.i(0,"speed_mps"))
o=A.t(a.i(0,"heading_degrees"))
n=A.t(a.i(0,"altitude_meters"))
m=A.t(a.i(0,"accuracy_meters"))
l=A.t(a.i(0,"distance_from_previous_meters"))
k=A.t(a.i(0,"acceleration_mps2"))
j=J.cK(a.i(0,"break_before"),!0)
i=typeof a.i(0,g)=="number"?B.b.aT(A.t(a.i(0,g))):0
h=A.hk(a.i(0,"speed_source"))
if(h==null)h="legacy"
return new A.A(s,r,q,p,o,n,m,l,k,j,i,h,!J.cK(a.i(0,"acceleration_reliable"),!1))},
$S:40}
A.f8.prototype={
$2(a,b){A.G(a)
t.R.a(b)
return new A.F(a,A.am(["score",b.a,"maximum",b.b,"applicable",b.c,"sampleSufficient",b.d],t.N,t.C),t.x)},
$S:41}
A.f9.prototype={
$2(a,b){A.G(a)
t.D.a(b)
return new A.F(a,A.am(["contribution",b.b,"source",b.c.b],t.N,t.C),t.x)},
$S:42}
A.fb.prototype={
$1(a){return t.u.a(a).c.c6().c5()},
$S:43}
A.f1.prototype={
$1(a){t.P.a(a)
return new A.a_(A.t(a.i(0,"latitude")),A.t(a.i(0,"longitude")))},
$S:10}
A.eZ.prototype={
$1(a){t.l.a(a)
return A.am(["commonStartOffsetMeters",a.a,"commonEndOffsetMeters",a.b,"existingStartOffsetMeters",a.c,"existingEndOffsetMeters",a.d,"challengerStartOffsetMeters",a.e,"challengerEndOffsetMeters",a.f,"state",a.r.b,"comparison",A.hu(a.w)],t.N,t.C)},
$S:44}
A.f_.prototype={
$1(a){t.w.a(a)
return A.am(["existingDriveId",a.a,"challengerDriveId",a.b,"startOffsetOnExistingMeters",a.d,"endOffsetOnExistingMeters",a.e,"startOffsetOnChallengerMeters",a.f,"endOffsetOnChallengerMeters",a.r,"commonStartOffsetMeters",a.w,"commonEndOffsetMeters",a.x,"winningDistanceMeters",a.y,"algorithmVersion",1,"confidence",a.Q,"supportingWindowCount",a.as],t.N,t.C)},
$S:45}
A.cx.prototype={
ap(a,b){var s
t.t.a(b)
s=J.hS(this.y,this.z++)
if(s==null){++this.z
throw A.d(A.ip("synthetic invalid window"))}A.t(s)
return new A.cc("legacy_v1",1,null,s,1,B.b.a3(s),1,B.aV,B.aW,"synthetic")}}
A.f3.prototype={
$1(a){var s=t.P,r=s.a(B.w.bT(A.G(a),null)),q=t.j
return B.w.bV(A.jq(A.jw(s.a(r.i(0,"match"))),A.hz(s.a(r.i(0,"firstRoad"))),A.hz(s.a(r.i(0,"secondRoad"))),A.hB(q.a(r.i(0,"firstTelemetry"))),A.hB(q.a(r.i(0,"secondTelemetry"))),new A.c4(new A.cx(q.a(r.i(0,"scores"))))),null)},
$S:46};(function aliases(){var s=J.ax.prototype
s.b_=s.k})();(function installTearOffs(){var s=hunkHelpers._static_2,r=hunkHelpers._static_1,q=hunkHelpers._instance_1u,p=hunkHelpers.installStaticTearOff
s(J,"j4","ia",47)
r(A,"ju","iV",35)
q(A.c9.prototype,"gbJ","bK",5)
q(A.cb.prototype,"gbg","bh",1)
p(A,"jG",2,null,["$1$2","$2"],["hx",function(a,b){return A.hx(a,b,t.H)}],32,0)})();(function inheritance(){var s=hunkHelpers.mixin,r=hunkHelpers.inherit,q=hunkHelpers.inheritMany
r(A.j,null)
q(A.j,[A.ff,J.cl,A.bD,J.aG,A.c,A.bb,A.u,A.et,A.bv,A.bA,A.a2,A.bl,A.bE,A.bj,A.b1,A.bd,A.K,A.eG,A.er,A.I,A.el,A.bt,A.bu,A.bs,A.cp,A.eQ,A.a1,A.cD,A.eR,A.aN,A.cG,A.aO,A.bU,A.bO,A.cH,A.c3,A.c7,A.eO,A.a6,A.L,A.eK,A.cs,A.bF,A.eL,A.ec,A.F,A.aL,A.b3,A.cM,A.d0,A.aC,A.ab,A.dj,A.d_,A.A,A.c4,A.dk,A.c5,A.ae,A.dp,A.dl,A.bP,A.a3,A.eM,A.c9,A.c8,A.a5,A.dD,A.cb,A.U,A.bf,A.ck,A.ee,A.e1,A.C,A.ag,A.cc,A.T,A.aq,A.ah,A.k,A.ca,A.e4,A.e8,A.cf,A.ce,A.bZ,A.Z,A.cA,A.az,A.aK,A.bz,A.en,A.eW,A.a_,A.a0,A.ev,A.eV,A.bI,A.bH,A.ew,A.eJ])
q(J.cl,[J.cn,J.bn,J.b_,J.aY,J.aJ])
q(J.b_,[J.ax,J.m])
q(J.ax,[J.es,J.aA,J.bo])
r(J.cm,A.bD)
r(J.eg,J.m)
q(J.aY,[J.bm,J.co])
q(A.c,[A.b5,A.p,A.an,A.z,A.bk,A.ap])
r(A.aH,A.b5)
r(A.bN,A.aH)
q(A.u,[A.bq,A.bJ,A.cq,A.cB,A.cw,A.cC,A.bp,A.c_,A.ac,A.bM,A.b2,A.c6])
q(A.p,[A.q,A.bi,A.ak,A.al,A.br])
q(A.q,[A.bG,A.f,A.bw,A.cF])
r(A.bh,A.an)
r(A.aV,A.ap)
r(A.b7,A.b1)
r(A.bK,A.b7)
r(A.be,A.bK)
q(A.K,[A.c2,A.cj,A.c1,A.cz,A.dB,A.dC,A.cU,A.cW,A.cX,A.cY,A.cN,A.cQ,A.cR,A.dh,A.di,A.d2,A.d1,A.d3,A.d4,A.d7,A.d8,A.db,A.dc,A.da,A.dd,A.d6,A.d5,A.d9,A.dm,A.dw,A.ds,A.dt,A.du,A.dv,A.dH,A.dG,A.dI,A.dT,A.dS,A.dU,A.dW,A.dV,A.dX,A.dY,A.dJ,A.dZ,A.dK,A.dL,A.dM,A.dN,A.dO,A.dP,A.dR,A.dF,A.e0,A.dE,A.e5,A.e9,A.ea,A.eA,A.eD,A.eE,A.eB,A.ey,A.f5,A.f4,A.f6,A.fc,A.fb,A.f1,A.eZ,A.f_,A.f3])
q(A.c2,[A.dq,A.eh,A.em,A.eq,A.eP,A.cV,A.cP,A.cO,A.cT,A.cS,A.df,A.dg,A.dn,A.dx,A.dy,A.dr,A.dQ,A.e2,A.e7,A.e6,A.eb,A.eC,A.eF,A.ez,A.ex,A.f7,A.f8,A.f9])
r(A.R,A.bd)
r(A.aW,A.cj)
r(A.bB,A.bJ)
q(A.cz,[A.cy,A.aU])
q(A.I,[A.aj,A.cE])
r(A.b6,A.cC)
q(A.aN,[A.bQ,A.bV])
r(A.at,A.bQ)
r(A.bL,A.bV)
r(A.cr,A.bp)
r(A.ei,A.c3)
q(A.c7,[A.ek,A.ej])
r(A.eN,A.eO)
q(A.c1,[A.dz,A.de,A.eo])
q(A.ac,[A.bC,A.ci])
q(A.eK,[A.ad,A.bc,A.e_,A.bg,A.a7,A.b4,A.aI,A.aw,A.P,A.a8,A.b0,A.by])
r(A.cx,A.bf)
s(A.b7,A.bU)
s(A.bV,A.cH)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{N:"int",b:"double",J:"num",e:"String",l:"bool",aL:"Null",v:"List",j:"Object",r:"Map",aZ:"JSObject"},mangledNames:{},types:["b(b,b)","l(T)","k(U)","b(T)","l(k)","b(a5)","l(U)","A(N)","b(k)","b(b,aC)","a_(@)","b(ab)","~(j?,j?)","N(e?)","l(Z)","~(@,@)","0&()","b(b)","A(a3)","b(b,a3)","l(k?)","b(b(a5))","b(b(k))","l(ab)","N(k,k)","ah(U)","k(k)","l(A)","b(b,ag)","l(C)","b(C)","~()","0^(0^,0^)<J>","aL()","b(Z)","@(@)","a0(@)","l(e)","v<a_>(a0)","b(b,a0)","A(@)","F<e,r<e,j>>(e,C)","F<e,r<e,j>>(e,ag)","e(A)","r<e,j>(az)","r<e,j>(aK)","e(e)","N(@,@)","b(b,T)","b(a8,b)"],arrayRti:Symbol("$ti")}
A.iJ(v.typeUniverse,JSON.parse('{"bo":"ax","es":"ax","aA":"ax","cn":{"l":[],"ar":[]},"bn":{"ar":[]},"b_":{"aZ":[]},"ax":{"aZ":[]},"m":{"v":["1"],"p":["1"],"aZ":[],"c":["1"]},"cm":{"bD":[]},"eg":{"m":["1"],"v":["1"],"p":["1"],"aZ":[],"c":["1"]},"aG":{"w":["1"]},"aY":{"b":[],"J":[],"Q":["J"]},"bm":{"b":[],"N":[],"J":[],"Q":["J"],"ar":[]},"co":{"b":[],"J":[],"Q":["J"],"ar":[]},"aJ":{"e":[],"Q":["e"],"ar":[]},"b5":{"c":["2"]},"bb":{"w":["2"]},"aH":{"b5":["1","2"],"c":["2"],"c.E":"2"},"bN":{"aH":["1","2"],"b5":["1","2"],"p":["2"],"c":["2"],"c.E":"2"},"bq":{"u":[]},"p":{"c":["1"]},"q":{"p":["1"],"c":["1"]},"bG":{"q":["1"],"p":["1"],"c":["1"],"q.E":"1","c.E":"1"},"bv":{"w":["1"]},"an":{"c":["2"],"c.E":"2"},"bh":{"an":["1","2"],"p":["2"],"c":["2"],"c.E":"2"},"bA":{"w":["2"]},"f":{"q":["2"],"p":["2"],"c":["2"],"q.E":"2","c.E":"2"},"z":{"c":["1"],"c.E":"1"},"a2":{"w":["1"]},"bk":{"c":["2"],"c.E":"2"},"bl":{"w":["2"]},"ap":{"c":["1"],"c.E":"1"},"aV":{"ap":["1"],"p":["1"],"c":["1"],"c.E":"1"},"bE":{"w":["1"]},"bi":{"p":["1"],"c":["1"],"c.E":"1"},"bj":{"w":["1"]},"be":{"bK":["1","2"],"b7":["1","2"],"b1":["1","2"],"bU":["1","2"],"r":["1","2"]},"bd":{"r":["1","2"]},"R":{"bd":["1","2"],"r":["1","2"]},"cj":{"K":[],"ai":[]},"aW":{"K":[],"ai":[]},"bB":{"u":[]},"cq":{"u":[]},"cB":{"u":[]},"K":{"ai":[]},"c1":{"K":[],"ai":[]},"c2":{"K":[],"ai":[]},"cz":{"K":[],"ai":[]},"cy":{"K":[],"ai":[]},"aU":{"K":[],"ai":[]},"cw":{"u":[]},"aj":{"I":["1","2"],"fN":["1","2"],"r":["1","2"],"I.K":"1","I.V":"2"},"ak":{"p":["1"],"c":["1"],"c.E":"1"},"bt":{"w":["1"]},"al":{"p":["1"],"c":["1"],"c.E":"1"},"bu":{"w":["1"]},"br":{"p":["F<1,2>"],"c":["F<1,2>"],"c.E":"F<1,2>"},"bs":{"w":["F<1,2>"]},"cp":{"il":[]},"cC":{"u":[]},"b6":{"u":[]},"at":{"bQ":["1"],"aN":["1"],"fP":["1"],"aM":["1"],"p":["1"],"c":["1"]},"aO":{"w":["1"]},"I":{"r":["1","2"]},"b1":{"r":["1","2"]},"bK":{"b7":["1","2"],"b1":["1","2"],"bU":["1","2"],"r":["1","2"]},"bw":{"q":["1"],"p":["1"],"c":["1"],"q.E":"1","c.E":"1"},"bO":{"w":["1"]},"aN":{"aM":["1"],"p":["1"],"c":["1"]},"bQ":{"aN":["1"],"aM":["1"],"p":["1"],"c":["1"]},"bL":{"aN":["1"],"cH":["1"],"aM":["1"],"p":["1"],"c":["1"]},"cE":{"I":["e","@"],"r":["e","@"],"I.K":"e","I.V":"@"},"cF":{"q":["e"],"p":["e"],"c":["e"],"q.E":"e","c.E":"e"},"bp":{"u":[]},"cr":{"u":[]},"a6":{"Q":["a6"]},"b":{"J":[],"Q":["J"]},"L":{"Q":["L"]},"N":{"J":[],"Q":["J"]},"v":{"p":["1"],"c":["1"]},"J":{"Q":["J"]},"aM":{"p":["1"],"c":["1"]},"e":{"Q":["e"]},"c_":{"u":[]},"bJ":{"u":[]},"ac":{"u":[]},"bC":{"u":[]},"ci":{"u":[]},"bM":{"u":[]},"b2":{"u":[]},"c6":{"u":[]},"cs":{"u":[]},"bF":{"u":[]},"b3":{"iq":[]},"cx":{"bf":[]}}'))
A.iI(v.typeUniverse,JSON.parse('{"bV":1,"c3":2,"c7":2}'))
var u={c:"At least two canonical telemetry points are required."}
var t=(function rtii(){var s=A.av
return{u:s("A"),fI:s("A(a3)"),e8:s("Q<@>"),h:s("a5"),dy:s("a6"),D:s("ag"),R:s("C"),F:s("k"),fR:s("a7"),gE:s("ah"),f:s("Z"),am:s("a8"),fu:s("L"),O:s("p<@>"),bU:s("u"),V:s("P"),c5:s("aw"),Z:s("ai"),t:s("c<A>"),ff:s("c<C>"),bM:s("c<b>"),hf:s("c<@>"),q:s("m<A>"),df:s("m<a5>"),g:s("m<k>"),v:s("m<ah>"),c:s("m<Z>"),b:s("m<v<b>>"),d:s("m<az>"),r:s("m<aK>"),s:s("m<e>"),W:s("m<T>"),gI:s("m<aq>"),h9:s("m<ab>"),du:s("m<a3>"),cA:s("m<bP>"),dO:s("m<U>"),aS:s("m<aC>"),n:s("m<b>"),gn:s("m<@>"),T:s("bn"),m:s("aZ"),L:s("bo"),d9:s("bw<N>"),Y:s("v<A>"),B:s("v<k>"),G:s("v<a7>"),au:s("v<ah>"),gj:s("v<v<b>>"),fB:s("v<az>"),dg:s("v<e>"),X:s("v<T>"),dr:s("v<aq>"),cT:s("v<ab>"),fT:s("v<bP>"),e:s("v<U>"),ap:s("v<aC>"),o:s("v<b>"),j:s("v<@>"),l:s("az"),w:s("aK"),x:s("F<e,r<e,j>>"),cC:s("r<e,C>"),h6:s("r<e,j>"),P:s("r<e,@>"),eO:s("r<@,@>"),gM:s("f<a3,A>"),A:s("a_"),p:s("a0"),a:s("aL"),C:s("j"),gT:s("jO"),fj:s("aM<P>"),cq:s("aM<e>"),N:s("e"),K:s("T"),fo:s("aq"),dm:s("ar"),ak:s("aA"),f4:s("bL<P>"),dA:s("z<Z>"),k:s("ab"),E:s("a3"),Q:s("U"),J:s("aC"),y:s("l"),eF:s("l(Z)"),d1:s("l(T)"),_:s("l(U)"),i:s("b"),bk:s("b(a5)"),bE:s("b(k)"),z:s("@"),S:s("N"),M:s("k?"),eH:s("fJ<aL>?"),an:s("aZ?"),gJ:s("v<e>?"),bF:s("v<@>?"),U:s("j?"),eN:s("aM<P>?"),dk:s("e?"),br:s("cG?"),fQ:s("l?"),cD:s("b?"),I:s("N?"),cg:s("J?"),H:s("J"),fH:s("~(e,@)")}})();(function constants(){var s=hunkHelpers.makeConstList
B.au=J.cl.prototype
B.a=J.m.prototype
B.c=J.bm.prototype
B.b=J.aY.prototype
B.e=J.aJ.prototype
B.av=J.b_.prototype
B.R=new A.aW(A.jG(),A.av("aW<b>"))
B.S=new A.cM()
B.T=new A.d0()
B.l=new A.dl()
B.U=new A.c9()
B.V=new A.dD()
B.W=new A.cb()
B.Y=new A.e1()
B.Z=new A.e4()
B.v=new A.bj(A.av("bj<0&>"))
B.a_=new A.e8()
B.a0=new A.ck()
B.a1=new A.ee()
B.a2=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.w=new A.ei()
B.a3=new A.cs()
B.b3=new A.et()
B.a4=new A.ev()
B.a5=new A.ew()
B.X=new A.bf()
B.b4=new A.c4(B.X)
B.x=new A.ad(0,"firstWins")
B.y=new A.ad(1,"secondWins")
B.z=new A.ad(2,"noMeaningfulDifference")
B.a6=new A.ad(3,"notEligible")
B.A=new A.ad(4,"insufficientTelemetry")
B.a7=new A.ad(5,"mappingFailed")
B.a8=new A.ad(7,"calculationFailed")
B.m=new A.bc(0,"success")
B.d=new A.bc(1,"mappingFailed")
B.B=new A.bc(2,"insufficientTelemetry")
B.C=new A.e_(0,"v1")
B.D=new A.bg(0,"actual")
B.a9=new A.bg(1,"neutralNotApplicable")
B.aa=new A.bg(2,"neutralInsufficient")
B.E=new A.aI(0,"stop")
B.i=new A.aI(1,"acceleration")
B.n=new A.aI(2,"deceleration")
B.h=new A.aI(3,"corner")
B.j=new A.aI(4,"cruise")
B.F=new A.a7(0,"unknown")
B.G=new A.a7(1,"stopped")
B.ab=new A.a7(2,"accelerating")
B.ac=new A.a7(3,"cruising")
B.ad=new A.a7(4,"decelerating")
B.ae=new A.a7(5,"cornering")
B.o=new A.a8(0,"cruiseDecelCruise")
B.p=new A.a8(1,"cruiseCornerCruise")
B.q=new A.a8(2,"accelerationCruise")
B.af=new A.L(0)
B.ag=new A.L(12e7)
B.H=new A.L(15e5)
B.ah=new A.L(2e6)
B.ai=new A.L(3e6)
B.aj=new A.L(3e8)
B.ak=new A.L(5e6)
B.al=new A.L(8e6)
B.am=new A.P(0,"stopped")
B.an=new A.P(1,"accelerating")
B.ao=new A.P(2,"cruising")
B.ap=new A.P(3,"decelerating")
B.r=new A.P(4,"cornering")
B.aq=new A.P(5,"freeFlow")
B.ar=new A.P(6,"denseTraffic")
B.as=new A.P(7,"stopAndGo")
B.at=new A.aw(0,"stopping")
B.t=new A.aw(1,"acceleration")
B.I=new A.aw(2,"braking")
B.J=new A.aw(3,"cornering")
B.K=new A.aw(4,"cruising")
B.aw=new A.ej(null)
B.ax=new A.ek(null)
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
B.f=s([],t.q)
B.aL=s([],t.g)
B.aK=s([],t.v)
B.M=s([],t.d)
B.N=s([],t.r)
B.aM=s([],t.s)
B.L=s([],t.W)
B.aH=s([80,0.33],t.n)
B.aG=s([140,0.67],t.n)
B.aA=s([200,1],t.n)
B.aN=s([B.u,B.aH,B.aG,B.aA],t.b)
B.aP=s([B.o,B.p,B.q],A.av("m<a8>"))
B.aQ=new A.by(0,"success")
B.aR=new A.by(1,"notEligible")
B.aS=new A.by(2,"insufficientConfidence")
B.aT=new A.b0(0,"existingBetter")
B.O=new A.b0(1,"challengerBetter")
B.aU=new A.b0(2,"noMeaningfulDifference")
B.P=new A.b0(3,"invalid")
B.k={}
B.aW=new A.R(B.k,[],A.av("R<e,ag>"))
B.aV=new A.R(B.k,[],A.av("R<e,C>"))
B.b6=new A.R(B.k,[],A.av("R<e,b>"))
B.aX=new A.bH(!1)
B.aY=new A.b4(0,"unknown")
B.Q=new A.aq(B.aY,0,0)
B.aZ=new A.b4(1,"freeFlow")
B.b_=new A.b4(2,"denseTraffic")
B.b0=new A.b4(3,"stopAndGo")
B.b7=new A.R(B.k,[],A.av("R<a8,N>"))
B.b5=s([],t.c)
B.b1=new A.cA(0,!1,!1)
B.b2=A.jK("j")})();(function staticFields(){$.V=A.o([],A.av("m<j>"))
$.fT=null
$.fA=null
$.fz=null})();(function lazyInitializers(){var s=hunkHelpers.lazyFinal
s($,"jM","hE",()=>A.hv("_$dart_dartClosure"))
s($,"jL","fu",()=>A.hv("_$dart_dartClosure_dartJSInterop"))
s($,"k_","hR",()=>A.o([new J.cm()],A.av("m<bD>")))
s($,"jP","hG",()=>A.as(A.eH({
toString:function(){return"$receiver$"}})))
s($,"jQ","hH",()=>A.as(A.eH({$method$:null,
toString:function(){return"$receiver$"}})))
s($,"jR","hI",()=>A.as(A.eH(null)))
s($,"jS","hJ",()=>A.as(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"jV","hM",()=>A.as(A.eH(void 0)))
s($,"jW","hN",()=>A.as(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"jU","hL",()=>A.as(A.h5(null)))
s($,"jT","hK",()=>A.as(function(){try{null.$method$}catch(r){return r.message}}()))
s($,"jY","hP",()=>A.as(A.h5(void 0)))
s($,"jX","hO",()=>A.as(function(){try{(void 0).$method$}catch(r){return r.message}}()))
s($,"jN","hF",()=>A.im("^([+-]?\\d{4,6})-?(\\d\\d)-?(\\d\\d)(?:[ T](\\d\\d)(?::?(\\d\\d)(?::?(\\d\\d)(?:[.,](\\d+))?)?)?( ?[zZ]| ?([-+])(\\d\\d)(?::?(\\d\\d))?)?)?$"))
s($,"jZ","hQ",()=>A.hy(B.b2))})();(function nativeSupport(){!function(){var s=function(a){var m={}
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
var s=A.jF
if(typeof dartMainRunner==="function"){dartMainRunner(s,[])}else{s([])}})})()
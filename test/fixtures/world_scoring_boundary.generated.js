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
if(a[b]!==s){A.jA(b)}a[b]=r}var q=a[b]
a[c]=function(){return q}
return q}}function makeConstList(a,b){if(b!=null)A.o(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var s=0;s<a.length;++s){convertToFastObject(a[s])}}var y=0
function instanceTearOffGetter(a,b){var s=null
return a?function(c){if(s===null)s=A.fj(b)
return new s(c,this)}:function(){if(s===null)s=A.fj(b)
return new s(this,null)}}function staticTearOffGetter(a){var s=null
return function(){if(s===null)s=A.fj(a).prototype
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
fE(a,b){if(a<0||a>4294967295)throw A.d(A.aa(a,0,4294967295,"length",null))
return J.e8(new Array(a),b)},
e8(a,b){var s=A.o(a,b.h("m<0>"))
s.$flags=1
return s},
i1(a,b){var s=t.e8
return J.hL(s.a(a),s.a(b))},
aQ(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.bm.prototype
return J.cm.prototype}if(typeof a=="string")return J.aI.prototype
if(a==null)return J.bn.prototype
if(typeof a=="boolean")return J.cl.prototype
if(Array.isArray(a))return J.m.prototype
if(typeof a=="function")return J.bo.prototype
if(typeof a=="object"){if(a instanceof A.j){return a}else{return J.b_.prototype}}if(!(a instanceof A.j))return J.az.prototype
return a},
bV(a){if(a==null)return a
if(Array.isArray(a))return J.m.prototype
if(!(a instanceof A.j))return J.az.prototype
return a},
bW(a){if(typeof a=="string")return J.aI.prototype
if(a==null)return a
if(Array.isArray(a))return J.m.prototype
if(!(a instanceof A.j))return J.az.prototype
return a},
jr(a){if(typeof a=="number")return J.aY.prototype
if(typeof a=="string")return J.aI.prototype
if(a==null)return a
if(!(a instanceof A.j))return J.az.prototype
return a},
fo(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.aQ(a).M(a,b)},
hK(a,b){if(typeof b==="number")if(Array.isArray(a)||typeof a=="string")if(b>>>0===b&&b<a.length)return a[b]
return J.bW(a).i(a,b)},
hL(a,b){return J.jr(a).E(a,b)},
fp(a,b){return J.bV(a).C(a,b)},
ba(a){return J.aQ(a).gB(a)},
fq(a){return J.bW(a).gv(a)},
hM(a){return J.bV(a).gX(a)},
a4(a){return J.bV(a).gq(a)},
aE(a){return J.bW(a).gl(a)},
hN(a){return J.aQ(a).gS(a)},
cI(a,b,c){return J.bV(a).aR(a,b,c)},
fr(a,b){return J.bV(a).K(a,b)},
aT(a){return J.aQ(a).k(a)},
cj:function cj(){},
cl:function cl(){},
bn:function bn(){},
b_:function b_(){},
ax:function ax(){},
em:function em(){},
az:function az(){},
bo:function bo(){},
m:function m(a){this.$ti=a},
ck:function ck(){},
e9:function e9(a){this.$ti=a},
aF:function aF(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aY:function aY(){},
bm:function bm(){},
cm:function cm(){},
aI:function aI(){}},A={f8:function f8(){},
fw(a,b,c){if(t.O.b(a))return new A.bM(a,b.h("@<0>").t(c).h("bM<1,2>"))
return new A.aG(a,b.h("@<0>").t(c).h("aG<1,2>"))},
i3(a){return new A.bq("Field '"+a+"' has not been initialized.")},
fY(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
ih(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
hl(a,b,c){return a},
fl(a){var s,r
for(s=$.U.length,r=0;r<s;++r)if(a===$.U[r])return!0
return!1},
eo(a,b,c,d){A.ap(b,"start")
if(c!=null){A.ap(c,"end")
if(b>c)A.aD(A.aa(b,0,c,"start",null))}return new A.bF(a,b,c,d.h("bF<0>"))},
i8(a,b,c,d){if(t.O.b(a))return new A.bh(a,b,c.h("@<0>").t(d).h("bh<1,2>"))
return new A.ao(a,b,c.h("@<0>").t(d).h("ao<1,2>"))},
fW(a,b,c){var s="count"
if(t.O.b(a)){A.cW(b,s,t.S)
A.ap(b,s)
return new A.aV(a,b,c.h("aV<0>"))}A.cW(b,s,t.S)
A.ap(b,s)
return new A.aq(a,b,c.h("aq<0>"))},
aX(){return new A.b2("No element")},
i_(){return new A.b2("Too few elements")},
b5:function b5(){},
bb:function bb(a,b){this.a=a
this.$ti=b},
aG:function aG(a,b){this.a=a
this.$ti=b},
bM:function bM(a,b){this.a=a
this.$ti=b},
bq:function bq(a){this.a=a},
en:function en(){},
p:function p(){},
q:function q(){},
bF:function bF(a,b,c,d){var _=this
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
ao:function ao(a,b,c){this.a=a
this.b=b
this.$ti=c},
bh:function bh(a,b,c){this.a=a
this.b=b
this.$ti=c},
bz:function bz(a,b,c){var _=this
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
a1:function a1(a,b,c){this.a=a
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
aq:function aq(a,b,c){this.a=a
this.b=b
this.$ti=c},
aV:function aV(a,b,c){this.a=a
this.b=b
this.$ti=c},
bD:function bD(a,b,c){this.a=a
this.b=b
this.$ti=c},
bi:function bi(a){this.$ti=a},
bj:function bj(a){this.$ti=a},
fy(a,b,c){var s,r,q,p,o,n,m,l=A.i(a),k=A.fa(new A.al(a,l.h("al<1>")),!0,b),j=k.length,i=0
for(;;){if(!(i<j)){s=!0
break}r=k[i]
if(typeof r!="string"||"__proto__"===r){s=!1
break}++i}if(s){q={}
for(p=0,i=0;i<k.length;k.length===j||(0,A.a3)(k),++i,p=o){r=k[i]
c.a(a.i(0,r))
o=p+1
q[r]=p}n=A.fa(new A.am(a,l.h("am<2>")),!0,c)
m=new A.Q(q,n,b.h("@<0>").t(c).h("Q<1,2>"))
m.$keys=k
return m}return new A.be(A.i4(a,b,c),b.h("@<0>").t(c).h("be<1,2>"))},
hv(a){var s=v.mangledGlobalNames[a]
if(s!=null)return s
return"minified:"+a},
x(a){var s
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
s=J.aT(a)
return s},
cs(a){var s,r=$.fM
if(r==null)r=$.fM=Symbol("identityHashCode")
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
ct(a){var s,r,q,p
if(a instanceof A.j)return A.M(A.bX(a),null)
s=J.aQ(a)
if(s===B.at||s===B.au||t.ak.b(a)){r=B.a1(a)
if(r!=="Object"&&r!=="")return r
q=a.constructor
if(typeof q=="function"){p=q.name
if(typeof p=="string"&&p!=="Object"&&p!=="")return p}}return A.M(A.bX(a),null)},
ia(a){var s,r,q
if(typeof a=="number"||A.fi(a))return J.aT(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.K)return a.k(0)
s=$.hJ()
for(r=0;r<1;++r){q=s[r].c5(a)
if(q!=null)return q}return"Instance of '"+A.ct(a)+"'"},
H(a){var s
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){s=a-65536
return String.fromCharCode((B.c.aJ(s,10)|55296)>>>0,s&1023|56320)}throw A.d(A.aa(a,0,1114111,null,null))},
fT(a,b,c,d,e,f,g,h,i){var s,r,q,p=b-1
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
cr(a){return a.c?A.R(a).getUTCFullYear()+0:A.R(a).getFullYear()+0},
fR(a){return a.c?A.R(a).getUTCMonth()+1:A.R(a).getMonth()+1},
fN(a){return a.c?A.R(a).getUTCDate()+0:A.R(a).getDate()+0},
fO(a){return a.c?A.R(a).getUTCHours()+0:A.R(a).getHours()+0},
fQ(a){return a.c?A.R(a).getUTCMinutes()+0:A.R(a).getMinutes()+0},
fS(a){return a.c?A.R(a).getUTCSeconds()+0:A.R(a).getSeconds()+0},
fP(a){return a.c?A.R(a).getUTCMilliseconds()+0:A.R(a).getMilliseconds()+0},
ju(a){throw A.d(A.hk(a))},
b(a,b){if(a==null)J.aE(a)
throw A.d(A.eW(a,b))},
eW(a,b){var s,r="index",q=null
if(!A.hg(b))return new A.ad(!0,b,r,q)
s=A.W(J.aE(a))
if(b<0||b>=s)return A.e6(b,s,a,q,r)
return new A.bB(q,q,!0,b,r,"Value not in range")},
hk(a){return new A.ad(!0,a,null,null)},
d(a){return A.C(a,new Error())},
C(a,b){var s
if(a==null)a=new A.bI()
b.dartException=a
s=A.jB
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:s})
b.name=""}else b.toString=s
return b},
jB(){return J.aT(this.dartException)},
aD(a,b){throw A.C(a,b==null?new Error():b)},
cH(a,b,c){var s
if(b==null)b=0
if(c==null)c=0
s=Error()
A.aD(A.iO(a,b,c),s)},
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
return new A.bL("'"+s+"': Cannot "+o+" "+l+k+n)},
a3(a){throw A.d(A.N(a))},
at(a){var s,r,q,p,o,n
a=A.jz(a.replace(String({}),"$receiver$"))
s=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(s==null)s=A.o([],t.s)
r=s.indexOf("\\$arguments\\$")
q=s.indexOf("\\$argumentsExpr\\$")
p=s.indexOf("\\$expr\\$")
o=s.indexOf("\\$method\\$")
n=s.indexOf("\\$receiver\\$")
return new A.ez(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),r,q,p,o,n)},
eA(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(s){return s.message}}(a)},
fZ(a){return function($expr$){try{$expr$.$method$}catch(s){return s.message}}(a)},
f9(a,b){var s=b==null,r=s?null:b.method
return new A.co(a,r,s?null:b.receiver)},
fm(a){if(a==null)return new A.el(a)
if(typeof a!=="object")return a
if("dartException" in a)return A.aS(a,a.dartException)
return A.jh(a)},
aS(a,b){if(t.bU.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
jh(a){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(!("message" in a))return a
s=a.message
if("number" in a&&typeof a.number=="number"){r=a.number
q=r&65535
if((B.c.aJ(r,16)&8191)===10)switch(q){case 438:return A.aS(a,A.f9(A.x(s)+" (Error "+q+")",null))
case 445:case 5007:A.x(s)
return A.aS(a,new A.bA())}}if(a instanceof TypeError){p=$.hy()
o=$.hz()
n=$.hA()
m=$.hB()
l=$.hE()
k=$.hF()
j=$.hD()
$.hC()
i=$.hH()
h=$.hG()
g=p.I(s)
if(g!=null)return A.aS(a,A.f9(A.F(s),g))
else{g=o.I(s)
if(g!=null){g.method="call"
return A.aS(a,A.f9(A.F(s),g))}else if(n.I(s)!=null||m.I(s)!=null||l.I(s)!=null||k.I(s)!=null||j.I(s)!=null||m.I(s)!=null||i.I(s)!=null||h.I(s)!=null){A.F(s)
return A.aS(a,new A.bA())}}return A.aS(a,new A.cz(typeof s=="string"?s:""))}if(a instanceof RangeError){if(typeof s=="string"&&s.indexOf("call stack")!==-1)return new A.bE()
s=function(b){try{return String(b)}catch(f){}return null}(a)
return A.aS(a,new A.ad(!1,null,null,typeof s=="string"?s.replace(/^RangeError:\s*/,""):s))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof s=="string"&&s==="too much recursion")return new A.bE()
return a},
hq(a){if(a==null)return J.ba(a)
if(typeof a=="object")return A.cs(a)
return J.ba(a)},
jp(a,b){var s,r,q,p=a.length
for(s=0;s<p;s=q){r=s+1
q=r+1
b.u(0,a[s],a[r])}return b},
jq(a,b){var s,r=a.length
for(s=0;s<r;++s)b.m(0,a[s])
return b},
iY(a,b,c,d,e,f){t.Z.a(a)
switch(A.W(b)){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.d(new A.eE("Unsupported number of arguments for wrapped closure"))},
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
hV(a2){var s,r,q,p,o,n,m,l,k,j,i=a2.co,h=a2.iS,g=a2.iI,f=a2.nDA,e=a2.aI,d=a2.fs,c=a2.cs,b=d[0],a=c[0],a0=i[b],a1=a2.fT
a1.toString
s=h?Object.create(new A.cw().constructor.prototype):Object.create(new A.aU(null,null).constructor.prototype)
s.$initialize=s.constructor
r=h?function static_tear_off(){this.$initialize()}:function tear_off(a3,a4){this.$initialize(a3,a4)}
s.constructor=r
r.prototype=s
s.$_name=b
s.$_target=a0
q=!h
if(q)p=A.fx(b,a0,g,f)
else{s.$static_name=b
p=a0}s.$S=A.hR(a1,h,g)
s[a]=p
for(o=p,n=1;n<d.length;++n){m=d[n]
if(typeof m=="string"){l=i[m]
k=m
m=l}else k=""
j=c[n]
if(j!=null){if(q)m=A.fx(k,m,g,f)
s[j]=m}if(n===e)o=m}s.$C=o
s.$R=a2.rC
s.$D=a2.dV
return r},
hR(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.d("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.hP)}throw A.d("Error in functionType of tearoff")},
hS(a,b,c,d){var s=A.fv
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,s)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,s)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,s)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,s)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,s)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,s)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,s)}},
fx(a,b,c,d){if(c)return A.hU(a,b,d)
return A.hS(b.length,d,a,b)},
hT(a,b,c,d){var s=A.fv,r=A.hQ
switch(b?-1:a){case 0:throw A.d(new A.cu("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,r,s)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,r,s)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,r,s)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,r,s)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,r,s)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,r,s)
default:return function(e,f,g){return function(){var q=[g(this)]
Array.prototype.push.apply(q,arguments)
return e.apply(f(this),q)}}(d,r,s)}},
hU(a,b,c){var s,r
if($.ft==null)$.ft=A.fs("interceptor")
if($.fu==null)$.fu=A.fs("receiver")
s=b.length
r=A.hT(s,c,a,b)
return r},
fj(a){return A.hV(a)},
hP(a,b){return A.eM(v.typeUniverse,A.bX(a.a),b)},
fv(a){return a.a},
hQ(a){return a.b},
fs(a){var s,r,q,p=new A.aU("receiver","interceptor"),o=Object.getOwnPropertyNames(p)
o.$flags=1
s=o
for(o=s.length,r=0;r<o;++r){q=s[r]
if(p[q]===a)return q}throw A.d(A.f6("Field name "+a+" not found."))},
hn(a){return v.getIsolateTag(a)},
jn(a,b){var s=b.length,r=v.rttc[""+s+";"+a]
if(r==null)return null
if(s===0)return r
if(s===r.length)return r.apply(null,b)
return r(b)},
i2(a,b,c,d,e,f){var s=function(g,h){try{return new RegExp(g,h)}catch(r){return r}}(a,""+""+""+""+f)
if(s instanceof RegExp)return s
throw A.d(A.cf("Illegal RegExp pattern ("+String(s)+")",a))},
jz(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
be:function be(a,b){this.a=a
this.$ti=b},
bd:function bd(){},
dj:function dj(a,b,c){this.a=a
this.b=b
this.c=c},
Q:function Q(a,b,c){this.a=a
this.b=b
this.$ti=c},
ch:function ch(){},
aW:function aW(a,b){this.a=a
this.$ti=b},
bC:function bC(){},
ez:function ez(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
bA:function bA(){},
co:function co(a,b,c){this.a=a
this.b=b
this.c=c},
cz:function cz(a){this.a=a},
el:function el(a){this.a=a},
K:function K(){},
c0:function c0(){},
c1:function c1(){},
cx:function cx(){},
cw:function cw(){},
aU:function aU(a,b){this.a=a
this.b=b},
cu:function cu(a){this.a=a},
ak:function ak(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
ea:function ea(a){this.a=a},
ee:function ee(a,b){this.a=a
this.b=b
this.c=null},
al:function al(a,b){this.a=a
this.$ti=b},
bt:function bt(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
am:function am(a,b){this.a=a
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
cn:function cn(a,b){this.a=a
this.b=b},
eJ:function eJ(a){this.b=a},
fb(a,b){var s=b.c
return s==null?b.c=A.bR(a,"fC",[b.x]):s},
fV(a){var s=a.w
if(s===6||s===7)return A.fV(a.x)
return s===11||s===12},
id(a){return a.as},
ac(a){return A.eL(v.typeUniverse,a,!1)},
jw(a,b){var s,r,q,p,o
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
return A.h7(a1,r,!0)
case 7:s=a2.x
r=A.aC(a1,s,a3,a4)
if(r===s)return a2
return A.h6(a1,r,!0)
case 8:q=a2.y
p=A.b8(a1,q,a3,a4)
if(p===q)return a2
return A.bR(a1,a2.x,p)
case 9:o=a2.x
n=A.aC(a1,o,a3,a4)
m=a2.y
l=A.b8(a1,m,a3,a4)
if(n===o&&l===m)return a2
return A.ff(a1,n,l)
case 10:k=a2.x
j=a2.y
i=A.b8(a1,j,a3,a4)
if(i===j)return a2
return A.h8(a1,k,i)
case 11:h=a2.x
g=A.aC(a1,h,a3,a4)
f=a2.y
e=A.je(a1,f,a3,a4)
if(g===h&&e===f)return a2
return A.h5(a1,g,e)
case 12:d=a2.y
a4+=d.length
c=A.b8(a1,d,a3,a4)
o=a2.x
n=A.aC(a1,o,a3,a4)
if(c===d&&n===o)return a2
return A.fg(a1,n,c,!0)
case 13:b=a2.x
if(b<a4)return a2
a=a3[b-a4]
if(a==null)return a2
return a
default:throw A.d(A.c_("Attempted to substitute unexpected RTI kind "+a0))}},
b8(a,b,c,d){var s,r,q,p,o=b.length,n=A.eN(o)
for(s=!1,r=0;r<o;++r){q=b[r]
p=A.aC(a,q,c,d)
if(p!==q)s=!0
n[r]=p}return s?n:b},
jf(a,b,c,d){var s,r,q,p,o,n,m=b.length,l=A.eN(m)
for(s=!1,r=0;r<m;r+=3){q=b[r]
p=b[r+1]
o=b[r+2]
n=A.aC(a,o,c,d)
if(n!==o)s=!0
l.splice(r,3,q,p,n)}return s?l:b},
je(a,b,c,d){var s,r=b.a,q=A.b8(a,r,c,d),p=b.b,o=A.b8(a,p,c,d),n=b.c,m=A.jf(a,n,c,d)
if(q===r&&o===p&&m===n)return b
s=new A.cB()
s.a=q
s.b=o
s.c=m
return s},
o(a,b){a[v.arrayRti]=b
return a},
eU(a){var s=a.$S
if(s!=null){if(typeof s=="number")return A.jt(s)
return a.$S()}return null},
jv(a,b){var s
if(A.fV(b))if(a instanceof A.K){s=A.eU(a)
if(s!=null)return s}return A.bX(a)},
bX(a){if(a instanceof A.j)return A.i(a)
if(Array.isArray(a))return A.h(a)
return A.fh(J.aQ(a))},
h(a){var s=a[v.arrayRti],r=t.gn
if(s==null)return r
if(s.constructor!==r.constructor)return r
return s},
i(a){var s=a.$ti
return s!=null?s:A.fh(a)},
fh(a){var s=a.constructor,r=s.$ccache
if(r!=null)return r
return A.iW(a,s)},
iW(a,b){var s=a instanceof A.K?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,r=A.iC(v.typeUniverse,s.name)
b.$ccache=r
return r},
jt(a){var s,r=v.types,q=r[a]
if(typeof q=="string"){s=A.eL(v.typeUniverse,q,!1)
r[a]=s
return s}return q},
js(a){return A.av(A.i(a))},
fk(a){var s=A.eU(a)
return A.av(s==null?A.bX(a):s)},
jd(a){var s=a instanceof A.K?A.eU(a):null
if(s!=null)return s
if(t.dm.b(a))return J.hN(a).a
if(Array.isArray(a))return A.h(a)
return A.bX(a)},
av(a){var s=a.r
return s==null?a.r=new A.eK(a):s},
jC(a){return A.av(A.eL(v.typeUniverse,a,!1))},
iV(a){var s=this
s.b=A.jc(s)
return s.b(a)},
jc(a){var s,r,q,p,o
if(a===t.C)return A.j3
if(A.aR(a))return A.j7
s=a.w
if(s===6)return A.iS
if(s===1)return A.hi
if(s===7)return A.iZ
r=A.jb(a)
if(r!=null)return r
if(s===8){q=a.x
if(a.y.every(A.aR)){a.f="$i"+q
if(q==="u")return A.j1
if(a===t.m)return A.j0
return A.j6}}else if(s===10){p=A.jn(a.x,a.y)
o=p==null?A.hi:p
return o==null?A.hc(o):o}return A.iQ},
jb(a){if(a.w===8){if(a===t.S)return A.hg
if(a===t.i||a===t.H)return A.j2
if(a===t.N)return A.j5
if(a===t.y)return A.fi}return null},
iU(a){var s=this,r=A.iP
if(A.aR(s))r=A.iL
else if(s===t.C)r=A.hc
else if(A.b9(s)){r=A.iR
if(s===t.I)r=A.iH
else if(s===t.dk)r=A.iK
else if(s===t.fQ)r=A.iF
else if(s===t.cg)r=A.hb
else if(s===t.cD)r=A.iG
else if(s===t.an)r=A.iJ}else if(s===t.S)r=A.W
else if(s===t.N)r=A.F
else if(s===t.y)r=A.eQ
else if(s===t.H)r=A.v
else if(s===t.i)r=A.n
else if(s===t.m)r=A.iI
s.a=r
return s.a(a)},
iQ(a){var s=this
if(a==null)return A.b9(s)
return A.ho(v.typeUniverse,A.jv(a,s),s)},
iS(a){if(a==null)return!0
return this.x.b(a)},
j6(a){var s,r=this
if(a==null)return A.b9(r)
s=r.f
if(a instanceof A.j)return!!a[s]
return!!J.aQ(a)[s]},
j1(a){var s,r=this
if(a==null)return A.b9(r)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
s=r.f
if(a instanceof A.j)return!!a[s]
return!!J.aQ(a)[s]},
j0(a){var s=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.j)return!!a[s.f]
return!0}if(typeof a=="function")return!0
return!1},
hh(a){if(typeof a=="object"){if(a instanceof A.j)return t.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
iP(a){var s=this
if(a==null){if(A.b9(s))return a}else if(s.b(a))return a
throw A.C(A.hd(a,s),new Error())},
iR(a){var s=this
if(a==null||s.b(a))return a
throw A.C(A.hd(a,s),new Error())},
hd(a,b){return new A.b6("TypeError: "+A.h_(a,A.M(b,null)))},
jj(a,b,c,d){if(A.ho(v.typeUniverse,a,b))return a
throw A.C(A.it("The type argument '"+A.M(a,null)+"' is not a subtype of the type variable bound '"+A.M(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
h_(a,b){return A.ce(a)+": type '"+A.M(A.jd(a),null)+"' is not a subtype of type '"+b+"'"},
it(a){return new A.b6("TypeError: "+a)},
V(a,b){return new A.b6("TypeError: "+A.h_(a,b))},
iZ(a){var s=this
return s.x.b(a)||A.fb(v.typeUniverse,s).b(a)},
j3(a){return a!=null},
hc(a){if(a!=null)return a
throw A.C(A.V(a,"Object"),new Error())},
j7(a){return!0},
iL(a){return a},
hi(a){return!1},
fi(a){return!0===a||!1===a},
eQ(a){if(!0===a)return!0
if(!1===a)return!1
throw A.C(A.V(a,"bool"),new Error())},
iF(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.C(A.V(a,"bool?"),new Error())},
n(a){if(typeof a=="number")return a
throw A.C(A.V(a,"double"),new Error())},
iG(a){if(typeof a=="number")return a
if(a==null)return a
throw A.C(A.V(a,"double?"),new Error())},
hg(a){return typeof a=="number"&&Math.floor(a)===a},
W(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.C(A.V(a,"int"),new Error())},
iH(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.C(A.V(a,"int?"),new Error())},
j2(a){return typeof a=="number"},
v(a){if(typeof a=="number")return a
throw A.C(A.V(a,"num"),new Error())},
hb(a){if(typeof a=="number")return a
if(a==null)return a
throw A.C(A.V(a,"num?"),new Error())},
j5(a){return typeof a=="string"},
F(a){if(typeof a=="string")return a
throw A.C(A.V(a,"String"),new Error())},
iK(a){if(typeof a=="string")return a
if(a==null)return a
throw A.C(A.V(a,"String?"),new Error())},
iI(a){if(A.hh(a))return a
throw A.C(A.V(a,"JSObject"),new Error())},
iJ(a){if(a==null)return a
if(A.hh(a))return a
throw A.C(A.V(a,"JSObject?"),new Error())},
hj(a,b){var s,r,q
for(s="",r="",q=0;q<a.length;++q,r=", ")s+=r+A.M(a[q],b)
return s},
ja(a,b){var s,r,q,p,o,n,m=a.x,l=a.y
if(""===m)return"("+A.hj(l,b)+")"
s=l.length
r=m.split(",")
q=r.length-s
for(p="(",o="",n=0;n<s;++n,o=", "){p+=o
if(q===0)p+="{"
p+=A.M(l[n],b)
if(q>=0)p+=" "+r[q];++q}return p+"})"},
he(a3,a4,a5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=", ",a2=null
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
return o.length>0?p+("<"+A.hj(o,b)+">"):p}if(l===10)return A.ja(a,b)
if(l===11)return A.he(a,b,null)
if(l===12)return A.he(a.x,b,a.y)
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
if(m==null)return A.eL(a,b,!1)
else if(typeof m=="number"){s=m
r=A.bS(a,5,"#")
q=A.eN(s)
for(p=0;p<s;++p)q[p]=r
o=A.bR(a,b,q)
n[b]=o
return o}else return m},
iA(a,b){return A.h9(a.tR,b)},
iz(a,b){return A.h9(a.eT,b)},
eL(a,b,c){var s,r=a.eC,q=r.get(b)
if(q!=null)return q
s=A.h3(A.h1(a,null,b,!1))
r.set(b,s)
return s},
eM(a,b,c){var s,r,q=b.z
if(q==null)q=b.z=new Map()
s=q.get(c)
if(s!=null)return s
r=A.h3(A.h1(a,b,c,!0))
q.set(c,r)
return r},
iB(a,b,c){var s,r,q,p=b.Q
if(p==null)p=b.Q=new Map()
s=c.as
r=p.get(s)
if(r!=null)return r
q=A.ff(a,b,c.w===9?c.y:[c])
p.set(s,q)
return q},
aA(a,b){b.a=A.iU
b.b=A.iV
return b},
bS(a,b,c){var s,r,q=a.eC.get(c)
if(q!=null)return q
s=new A.a0(null,null)
s.w=b
s.as=c
r=A.aA(a,s)
a.eC.set(c,r)
return r},
h7(a,b,c){var s,r=b.as+"?",q=a.eC.get(r)
if(q!=null)return q
s=A.ix(a,b,r,c)
a.eC.set(r,s)
return s},
ix(a,b,c,d){var s,r,q
if(d){s=b.w
r=!0
if(!A.aR(b))if(!(b===t.a||b===t.T))if(s!==6)r=s===7&&A.b9(b.x)
if(r)return b
else if(s===1)return t.a}q=new A.a0(null,null)
q.w=6
q.x=b
q.as=c
return A.aA(a,q)},
h6(a,b,c){var s,r=b.as+"/",q=a.eC.get(r)
if(q!=null)return q
s=A.iv(a,b,r,c)
a.eC.set(r,s)
return s},
iv(a,b,c,d){var s,r
if(d){s=b.w
if(A.aR(b)||b===t.C)return b
else if(s===1)return A.bR(a,"fC",[b])
else if(b===t.a||b===t.T)return t.eH}r=new A.a0(null,null)
r.w=7
r.x=b
r.as=c
return A.aA(a,r)},
iy(a,b){var s,r,q=""+b+"^",p=a.eC.get(q)
if(p!=null)return p
s=new A.a0(null,null)
s.w=13
s.x=b
s.as=q
r=A.aA(a,s)
a.eC.set(q,r)
return r},
bQ(a){var s,r,q,p=a.length
for(s="",r="",q=0;q<p;++q,r=",")s+=r+a[q].as
return s},
iu(a){var s,r,q,p,o,n=a.length
for(s="",r="",q=0;q<n;q+=3,r=","){p=a[q]
o=a[q+1]?"!":":"
s+=r+p+o+a[q+2].as}return s},
bR(a,b,c){var s,r,q,p=b
if(c.length>0)p+="<"+A.bQ(c)+">"
s=a.eC.get(p)
if(s!=null)return s
r=new A.a0(null,null)
r.w=8
r.x=b
r.y=c
if(c.length>0)r.c=c[0]
r.as=p
q=A.aA(a,r)
a.eC.set(p,q)
return q},
ff(a,b,c){var s,r,q,p,o,n
if(b.w===9){s=b.x
r=b.y.concat(c)}else{r=c
s=b}q=s.as+(";<"+A.bQ(r)+">")
p=a.eC.get(q)
if(p!=null)return p
o=new A.a0(null,null)
o.w=9
o.x=s
o.y=r
o.as=q
n=A.aA(a,o)
a.eC.set(q,n)
return n},
h8(a,b,c){var s,r,q="+"+(b+"("+A.bQ(c)+")"),p=a.eC.get(q)
if(p!=null)return p
s=new A.a0(null,null)
s.w=10
s.x=b
s.y=c
s.as=q
r=A.aA(a,s)
a.eC.set(q,r)
return r},
h5(a,b,c){var s,r,q,p,o,n=b.as,m=c.a,l=m.length,k=c.b,j=k.length,i=c.c,h=i.length,g="("+A.bQ(m)
if(j>0){s=l>0?",":""
g+=s+"["+A.bQ(k)+"]"}if(h>0){s=l>0?",":""
g+=s+"{"+A.iu(i)+"}"}r=n+(g+")")
q=a.eC.get(r)
if(q!=null)return q
p=new A.a0(null,null)
p.w=11
p.x=b
p.y=c
p.as=r
o=A.aA(a,p)
a.eC.set(r,o)
return o},
fg(a,b,c,d){var s,r=b.as+("<"+A.bQ(c)+">"),q=a.eC.get(r)
if(q!=null)return q
s=A.iw(a,b,c,r,d)
a.eC.set(r,s)
return s},
iw(a,b,c,d,e){var s,r,q,p,o,n,m,l
if(e){s=c.length
r=A.eN(s)
for(q=0,p=0;p<s;++p){o=c[p]
if(o.w===1){r[p]=o;++q}}if(q>0){n=A.aC(a,b,r,0)
m=A.b8(a,c,r,0)
return A.fg(a,n,m,c!==m)}}l=new A.a0(null,null)
l.w=12
l.x=b
l.y=c
l.as=d
return A.aA(a,l)},
h1(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
h3(a){var s,r,q,p,o,n,m,l=a.r,k=a.s
for(s=l.length,r=0;r<s;){q=l.charCodeAt(r)
if(q>=48&&q<=57)r=A.io(r+1,q,l,k)
else if((((q|32)>>>0)-97&65535)<26||q===95||q===36||q===124)r=A.h2(a,r,l,k,!1)
else if(q===46)r=A.h2(a,r,l,k,!0)
else{++r
switch(q){case 44:break
case 58:k.push(!1)
break
case 33:k.push(!0)
break
case 59:k.push(A.aP(a.u,a.e,k.pop()))
break
case 94:k.push(A.iy(a.u,k.pop()))
break
case 35:k.push(A.bS(a.u,5,"#"))
break
case 64:k.push(A.bS(a.u,2,"@"))
break
case 126:k.push(A.bS(a.u,3,"~"))
break
case 60:k.push(a.p)
a.p=k.length
break
case 62:A.iq(a,k)
break
case 38:A.ip(a,k)
break
case 63:p=a.u
k.push(A.h7(p,A.aP(p,a.e,k.pop()),a.n))
break
case 47:p=a.u
k.push(A.h6(p,A.aP(p,a.e,k.pop()),a.n))
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
A.h4(a.u,a.e,o)
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
return A.aP(a.u,a.e,m)},
io(a,b,c,d){var s,r,q=b-48
for(s=c.length;a<s;++a){r=c.charCodeAt(a)
if(!(r>=48&&r<=57))break
q=q*10+(r-48)}d.push(q)
return a},
h2(a,b,c,d,e){var s,r,q,p,o,n,m=b+1
for(s=c.length;m<s;++m){r=c.charCodeAt(m)
if(r===46){if(e)break
e=!0}else{if(!((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124))q=r>=48&&r<=57
else q=!0
if(!q)break}}p=c.substring(b,m)
if(e){s=a.u
o=a.e
if(o.w===9)o=o.x
n=A.iD(s,o.x)[p]
if(n==null)A.aD('No "'+p+'" in "'+A.id(o)+'"')
d.push(A.eM(s,o,n))}else d.push(p)
return m},
iq(a,b){var s,r=a.u,q=A.h0(a,b),p=b.pop()
if(typeof p=="string")b.push(A.bR(r,p,q))
else{s=A.aP(r,a.e,p)
switch(s.w){case 11:b.push(A.fg(r,s,q,a.n))
break
default:b.push(A.ff(r,s,q))
break}}},
im(a,b){var s,r,q,p=a.u,o=b.pop(),n=null,m=null
if(typeof o=="number")switch(o){case-1:n=b.pop()
break
case-2:m=b.pop()
break
default:b.push(o)
break}else b.push(o)
s=A.h0(a,b)
o=b.pop()
switch(o){case-3:o=b.pop()
if(n==null)n=p.sEA
if(m==null)m=p.sEA
r=A.aP(p,a.e,o)
q=new A.cB()
q.a=s
q.b=n
q.c=m
b.push(A.h5(p,r,q))
return
case-4:b.push(A.h8(p,b.pop(),s))
return
default:throw A.d(A.c_("Unexpected state under `()`: "+A.x(o)))}},
ip(a,b){var s=b.pop()
if(0===s){b.push(A.bS(a.u,1,"0&"))
return}if(1===s){b.push(A.bS(a.u,4,"1&"))
return}throw A.d(A.c_("Unexpected extended operation "+A.x(s)))},
h0(a,b){var s=b.splice(a.p)
A.h4(a.u,a.e,s)
a.p=b.pop()
return s},
aP(a,b,c){if(typeof c=="string")return A.bR(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.ir(a,b,c)}else return c},
h4(a,b,c){var s,r=c.length
for(s=0;s<r;++s)c[s]=A.aP(a,b,c[s])},
is(a,b,c){var s,r=c.length
for(s=2;s<r;s+=3)c[s]=A.aP(a,b,c[s])},
ir(a,b,c){var s,r,q=b.w
if(q===9){if(c===0)return b.x
s=b.y
r=s.length
if(c<=r)return s[c-1]
c-=r
b=b.x
q=b.w}else if(c===0)return b
if(q!==8)throw A.d(A.c_("Indexed base must be an interface type"))
s=b.y
if(c<=s.length)return s[c-1]
throw A.d(A.c_("Bad index "+c+" for "+b.k(0)))},
ho(a,b,c){var s,r=b.d
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
return A.A(a,A.fb(a,b),c,d,e)}if(s===6)return A.A(a,p,c,d,e)&&A.A(a,b.x,c,d,e)
if(q===7){if(A.A(a,b,c,d.x,e))return!0
return A.A(a,b,c,A.fb(a,d),e)}if(q===6)return A.A(a,b,c,p,e)||A.A(a,b,c,d.x,e)
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
if(!A.A(a,j,c,i,e)||!A.A(a,i,e,j,c))return!1}return A.hf(a,b.x,c,d.x,e)}if(q===11){if(b===t.L)return!0
if(p)return!1
return A.hf(a,b,c,d,e)}if(s===8){if(q!==8)return!1
return A.j_(a,b,c,d,e)}if(o&&q===10)return A.j4(a,b,c,d,e)
return!1},
hf(a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
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
for(o=0;o<q;++o)p[o]=A.eM(a,b,r[o])
return A.ha(a,p,null,c,d.y,e)}return A.ha(a,b.y,null,c,d.y,e)},
ha(a,b,c,d,e,f){var s,r=b.length
for(s=0;s<r;++s)if(!A.A(a,b[s],d,e[s],f))return!1
return!0},
j4(a,b,c,d,e){var s,r=b.y,q=d.y,p=r.length
if(p!==q.length)return!1
if(b.x!==d.x)return!1
for(s=0;s<p;++s)if(!A.A(a,r[s],c,q[s],e))return!1
return!0},
b9(a){var s=a.w,r=!0
if(!(a===t.a||a===t.T))if(!A.aR(a))if(s!==6)r=s===7&&A.b9(a.x)
return r},
aR(a){var s=a.w
return s===2||s===3||s===4||s===5||a===t.U},
h9(a,b){var s,r,q=Object.keys(b),p=q.length
for(s=0;s<p;++s){r=q[s]
a[r]=b[r]}},
eN(a){return a>0?new Array(a):v.typeUniverse.sEA},
a0:function a0(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
cB:function cB(){this.c=this.b=this.a=null},
eK:function eK(a){this.a=a},
cA:function cA(){},
b6:function b6(a){this.a=a},
fH(a,b){return new A.ak(a.h("@<0>").t(b).h("ak<1,2>"))},
an(a,b,c){return b.h("@<0>").t(c).h("fG<1,2>").a(A.jp(a,new A.ak(b.h("@<0>").t(c).h("ak<1,2>"))))},
aJ(a,b){return new A.ak(a.h("@<0>").t(b).h("ak<1,2>"))},
fJ(a){return new A.au(a.h("au<0>"))},
fK(a){return new A.au(a.h("au<0>"))},
i5(a,b){return b.h("fI<0>").a(A.jq(a,new A.au(b.h("au<0>"))))},
fe(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
il(a,b,c){var s=new A.aO(a,b,c.h("aO<0>"))
s.c=a.e
return s},
i4(a,b,c){var s=A.fH(b,c)
a.H(0,new A.ef(s,b,c))
return s},
i6(a,b){var s=A.fJ(b)
s.L(0,a)
return s},
ej(a){var s,r
if(A.fl(a))return"{...}"
s=new A.b3("")
try{r={}
B.a.m($.U,a)
s.a+="{"
r.a=!0
a.H(0,new A.ek(r,s))
s.a+="}"}finally{if(0>=$.U.length)return A.b($.U,-1)
$.U.pop()}r=s.a
return r.charCodeAt(0)==0?r:r},
i7(a){return 8},
iE(){throw A.d(A.eB("Cannot change an unmodifiable set"))},
au:function au(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
cE:function cE(a){this.a=a
this.b=null},
aO:function aO(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
ef:function ef(a,b,c){this.a=a
this.b=b
this.c=c},
I:function I(){},
ek:function ek(a,b){this.a=a
this.b=b},
bT:function bT(){},
b1:function b1(){},
bJ:function bJ(){},
eg:function eg(a,b){var _=this
_.a=a
_.d=_.c=_.b=0
_.$ti=b},
bN:function bN(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=null
_.$ti=e},
aN:function aN(){},
bP:function bP(){},
cF:function cF(){},
bK:function bK(a,b){this.a=a
this.$ti=b},
b7:function b7(){},
bU:function bU(){},
j9(a,b){var s,r,q,p=null
try{p=JSON.parse(a)}catch(r){s=A.fm(r)
q=A.cf(String(s),null)
throw A.d(q)}q=A.eR(p)
return q},
eR(a){var s
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.cC(a,Object.create(null))
for(s=0;s<a.length;++s)a[s]=A.eR(a[s])
return a},
fF(a,b,c){return new A.bp(a,b)},
iN(a){return a.ce()},
ij(a,b){return new A.eG(a,[],A.jm())},
ik(a,b,c){var s,r=new A.b3(""),q=A.ij(r,b)
q.ac(a)
s=r.a
return s.charCodeAt(0)==0?s:s},
cC:function cC(a,b){this.a=a
this.b=b
this.c=null},
cD:function cD(a){this.a=a},
c2:function c2(){},
c6:function c6(){},
bp:function bp(a,b){this.a=a
this.b=b},
cp:function cp(a,b){this.a=a
this.b=b},
eb:function eb(){},
ed:function ed(a){this.b=a},
ec:function ec(a){this.a=a},
eH:function eH(){},
eI:function eI(a,b){this.a=a
this.b=b},
eG:function eG(a,b,c){this.c=a
this.a=b
this.b=c},
cG(a){var s=A.i9(a,null)
if(s!=null)return s
throw A.d(A.cf(a,null))},
bw(a,b,c,d){var s,r=J.fE(a,d)
if(a!==0&&b!=null)for(s=0;s<a;++s)r[s]=b
return r},
fa(a,b,c){var s,r=A.o([],c.h("m<0>"))
for(s=J.a4(a);s.n();)B.a.m(r,c.a(s.gp()))
if(b)return r
r.$flags=1
return r},
y(a,b){var s,r=A.o([],b.h("m<0>"))
for(s=a.gq(a);s.n();)B.a.m(r,s.gp())
return r},
a9(a,b){var s=A.fa(a,!1,b)
s.$flags=3
return s},
ic(a){return new A.cn(a,A.i2(a,!1,!0,!1,!1,""))},
fX(a,b,c){var s=J.a4(b)
if(!s.n())return a
if(c.length===0){do a+=A.x(s.gp())
while(s.n())}else{a+=A.x(s.gp())
while(s.n())a=a+c+A.x(s.gp())}return a},
hX(a,b,c,d,e,f,g,h,i){var s=A.fT(a,b,c,d,e,f,g,h,i)
if(s==null)return null
return new A.a6(A.fA(s,h,i),h,i)},
hW(a){var s=A.fT(a,1,1,0,0,0,0,0,!0)
return new A.a6(s==null?new A.dt(a,1,1,0,0,0,0,0).$0():s,0,!0)},
hZ(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=$.hx().bU(a)
if(c!=null){s=new A.dv()
r=c.b
if(1>=r.length)return A.b(r,1)
q=r[1]
q.toString
p=A.cG(q)
if(2>=r.length)return A.b(r,2)
q=r[2]
q.toString
o=A.cG(q)
if(3>=r.length)return A.b(r,3)
q=r[3]
q.toString
n=A.cG(q)
if(4>=r.length)return A.b(r,4)
m=s.$1(r[4])
if(5>=r.length)return A.b(r,5)
l=s.$1(r[5])
if(6>=r.length)return A.b(r,6)
k=s.$1(r[6])
if(7>=r.length)return A.b(r,7)
j=new A.dw().$1(r[7])
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
e=A.cG(q)
if(11>=r.length)return A.b(r,11)
l-=f*(s.$1(r[11])+60*e)}}d=A.hX(p,o,n,m,l,k,i,j%1000,h)
if(d==null)throw A.d(A.cf("Time out of range",a))
return d}else throw A.d(A.cf("Invalid date format",a))},
fA(a,b,c){var s="microsecond"
if(b<0||b>999)throw A.d(A.aa(b,0,999,s,null))
if(a<-864e13||a>864e13)throw A.d(A.aa(a,-864e13,864e13,"millisecondsSinceEpoch",null))
if(a===864e13&&b!==0)throw A.d(A.hO(b,s,"Time including microseconds is outside valid range"))
A.hl(c,"isUtc",t.y)
return a},
fz(a){var s=Math.abs(a),r=a<0?"-":""
if(s>=1000)return""+a
if(s>=100)return r+"0"+s
if(s>=10)return r+"00"+s
return r+"000"+s},
hY(a){var s=Math.abs(a),r=a<0?"-":"+"
if(s>=1e5)return r+s
return r+"0"+s},
du(a){if(a>=100)return""+a
if(a>=10)return"0"+a
return"00"+a},
ag(a){if(a>=10)return""+a
return"0"+a},
D(a,b){return new A.L(a+1000*b)},
ce(a){if(typeof a=="number"||A.fi(a)||a==null)return J.aT(a)
if(typeof a=="string")return JSON.stringify(a)
return A.ia(a)},
c_(a){return new A.bZ(a)},
f6(a){return new A.ad(!1,null,null,a)},
hO(a,b,c){return new A.ad(!0,a,b,c)},
cW(a,b,c){return a},
aa(a,b,c,d,e){return new A.bB(b,c,!0,a,d,"Invalid value")},
fU(a,b,c){if(0>a||a>c)throw A.d(A.aa(a,0,c,"start",null))
if(a>b||b>c)throw A.d(A.aa(b,a,c,"end",null))
return b},
ap(a,b){if(a<0)throw A.d(A.aa(a,0,null,b,null))
return a},
e6(a,b,c,d,e){return new A.cg(b,!0,a,e,"Index out of range")},
eB(a){return new A.bL(a)},
ie(a){return new A.b2(a)},
N(a){return new A.c5(a)},
cf(a,b){return new A.e5(a,b)},
i0(a,b,c){var s,r
if(A.fl(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}s=A.o([],t.s)
B.a.m($.U,a)
try{A.j8(a,s)}finally{if(0>=$.U.length)return A.b($.U,-1)
$.U.pop()}r=A.fX(b,t.hf.a(s),", ")+c
return r.charCodeAt(0)==0?r:r},
f7(a,b,c){var s,r
if(A.fl(a))return b+"..."+c
s=new A.b3(b)
B.a.m($.U,a)
try{r=s
r.a=A.fX(r.a,a,", ")}finally{if(0>=$.U.length)return A.b($.U,-1)
$.U.pop()}s.a+=c
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
fL(a,b){var s=J.ba(a)
b=J.ba(b)
b=A.ih(A.fY(A.fY($.hI(),s),b))
return b},
dt:function dt(a,b,c,d,e,f,g,h){var _=this
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
dv:function dv(){},
dw:function dw(){},
L:function L(a){this.a=a},
eD:function eD(){},
t:function t(){},
bZ:function bZ(a){this.a=a},
bI:function bI(){},
ad:function ad(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bB:function bB(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
cg:function cg(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
bL:function bL(a){this.a=a},
b2:function b2(a){this.a=a},
c5:function c5(a){this.a=a},
cq:function cq(){},
bE:function bE(){},
eE:function eE(a){this.a=a},
e5:function e5(a,b){this.a=a
this.b=b},
c:function c(){},
E:function E(a,b,c){this.a=a
this.b=b
this.$ti=c},
aL:function aL(){},
j:function j(){},
b3:function b3(a){this.a=a},
cJ:function cJ(){},
cR:function cR(a){this.a=a},
cS:function cS(){},
cT:function cT(a){this.a=a},
cU:function cU(a,b){this.a=a
this.b=b},
cV:function cV(a,b){this.a=a
this.b=b},
cK:function cK(){},
cM:function cM(){},
cL:function cL(a){this.a=a},
cN:function cN(a,b){this.a=a
this.b=b},
cO:function cO(){},
cQ:function cQ(){},
cP:function cP(a){this.a=a},
cY:function cY(){},
db:function db(){},
dc:function dc(){},
cZ:function cZ(a){this.a=a},
d_:function d_(){},
d2:function d2(a){this.a=a},
d3:function d3(){},
d5:function d5(){},
d6:function d6(a){this.a=a},
d7:function d7(){},
d8:function d8(){},
d1:function d1(a){this.a=a},
d0:function d0(a){this.a=a},
d9:function d9(){},
da:function da(){},
d4:function d4(a){this.a=a},
aB:function aB(a,b){this.a=a
this.b=b},
ab:function ab(a,b,c){this.a=a
this.b=b
this.c=c},
dd:function dd(a,b,c,d){var _=this
_.a=a
_.f=b
_.r=c
_.z=d},
cX:function cX(a,b,c,d){var _=this
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
c3:function c3(a){this.b=a},
de:function de(a,b,c,d,e,f,g,h,i,j,k){var _=this
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
ae:function ae(a,b){this.a=a
this.b=b},
c4:function c4(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.r=c
_.w=d
_.x=e
_.y=f},
bc:function bc(a,b){this.a=a
this.b=b},
af:function af(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
di:function di(a,b){this.a=a
this.b=b},
iT(a,b){var s
if(!isFinite(a)||a<0||a>=360)return null
s=B.b.T(Math.abs(a-b),360)
return s>180?360-s:s},
df:function df(){},
dg:function dg(){},
dh:function dh(){},
bO:function bO(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.r=_.f=$},
a2:function a2(a,b,c){this.a=a
this.b=b
this.c=c},
eF:function eF(a,b,c){this.a=a
this.b=b
this.c=c},
c8:function c8(){},
dq:function dq(a,b){this.a=a
this.b=b},
dr:function dr(){},
ds:function ds(){},
dl:function dl(){},
dm:function dm(){},
dn:function dn(){},
dp:function dp(){},
dk:function dk(){},
c7:function c7(a,b,c){this.a=a
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
dx:function dx(){},
ca:function ca(){},
dB:function dB(){},
dA:function dA(){},
dC:function dC(a,b){this.a=a
this.b=b},
dN:function dN(){},
dM:function dM(){},
dO:function dO(a){this.a=a},
dQ:function dQ(){},
dP:function dP(){},
dR:function dR(a){this.a=a},
dS:function dS(){},
dD:function dD(){},
dT:function dT(){},
dE:function dE(a,b){this.a=a
this.b=b},
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
dJ:function dJ(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dK:function dK(){},
dL:function dL(a){this.a=a},
dz:function dz(a,b){this.a=a
this.b=b},
T:function T(a,b){this.a=a
this.b=b},
dU:function dU(a,b){this.a=a
this.b=b},
bf:function bf(){},
dV:function dV(){},
ci:function ci(){},
e7:function e7(){},
dW:function dW(){},
dX:function dX(){},
bg:function bg(a,b){this.a=a
this.b=b},
B:function B(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
ah:function ah(a,b){this.b=a
this.c=b},
cb:function cb(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
fB(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s){return new A.k(h,d,s,o,e,q,g,p,f,i,k,c,a,r,n,m,b,l,j)},
a7:function a7(a,b){this.a=a
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
ar:function ar(a,b,c){this.a=a
this.c=b
this.d=c},
ai:function ai(a,b,c){this.a=a
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
c9:function c9(a,b,c){this.b=a
this.c=b
this.f=c},
dy:function dy(a){this.a=a},
dY:function dY(){},
dZ:function dZ(){},
e0:function e0(){},
e_:function e_(a){this.a=a},
e1:function e1(){},
e2:function e2(){},
e3:function e3(){},
e4:function e4(){},
cd:function cd(a,b,c){this.a=a
this.f=b
this.r=c},
cc:function cc(a,b,c){this.a=a
this.b=b
this.c=c},
bY:function bY(a,b,c){this.a=a
this.e=b
this.f=c},
a8:function a8(a,b){this.a=a
this.b=b},
Y:function Y(a,b){this.a=a
this.e=b},
cy:function cy(a,b,c){this.a=a
this.e=b
this.f=c},
b0:function b0(a,b){this.a=a
this.b=b},
bx:function bx(a,b){this.a=a
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
by:function by(a,b,c){this.a=a
this.c=b
this.d=c},
eh:function eh(a){this.a=a},
ei:function ei(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
eP:function eP(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.w=1},
Z:function Z(a,b){this.a=a
this.b=b},
a_:function a_(a,b,c){this.a=a
this.b=b
this.c=c},
ep:function ep(){},
eO:function eO(a,b){this.a=a
this.b=b},
bH:function bH(a,b,c){this.a=a
this.r=b
this.as=c},
bG:function bG(a){this.a=a},
eq:function eq(){},
ev:function ev(a){this.a=a},
ew:function ew(a){this.a=a},
ex:function ex(){},
ey:function ey(){},
eu:function eu(a){this.a=a},
es:function es(){},
et:function et(){},
er:function er(a){this.a=a},
eC:function eC(a,b,c,d,e){var _=this
_.a=a
_.c=b
_.d=c
_.e=d
_.x=e},
hr(a){var s,r,q,p=J.cI(t.j.a(a.i(0,"sections")),new A.eZ(),t.p),o=A.y(p,p.$ti.h("q.E"))
A.hW(1970)
p=A.F(a.i(0,"id"))
A.F(a.i(0,"driveId"))
s=A.h(o)
r=s.h("bk<1,Z>")
s=A.y(new A.bk(o,s.h("c<Z>(1)").a(new A.f_()),r),r.h("c.E"))
r=B.a.F(o,0,new A.f0(),t.i)
q=a.i(0,"processingVersion")
A.W(q==null?3:q)
q=a.i(0,"directionKey")
A.F(q==null?"":q)
return new A.eC(p,s,o,r,null)},
ht(a){var s=J.cI(a,new A.f5(),t.u)
s=A.y(s,s.$ti.h("q.E"))
return s},
hs(a){var s,r=t.N,q=t.z
if(a==null)r=A.aJ(r,q)
else{s=t.h6
q=A.an(["totalScore",a.a,"displayScore",a.c,"algorithmVersion",a.d,"overallConfidence",a.b,"categories",a.e.a2(0,new A.f1(),r,s),"contributions",a.f.a2(0,new A.f2(),r,s)],r,q)
r=q}return r},
hm(a){var s,r=a.e
r=r==null?null:A.hs(r)
s=a.f
s=s==null?null:A.hs(s)
return A.an(["outcome",a.x.b,"comparisonValid",a.y,"firstLocalScore",r,"secondLocalScore",s,"scoreDifference",a.r,"relativeDifference",a.w],t.N,t.z)},
f3(a){var s=a.b,r=A.h(s),q=r.h("f<1,e>")
r=A.y(new A.f(s,r.h("e(1)").a(new A.f4()),q),q.h("q.E"))
return A.an(["status",a.a.b,"startIndex",a.c,"endIndex",a.d,"count",s.length,"mappingConfidence",a.e,"timestamps",r],t.N,t.z)},
jo(a){var s,r,q="latitude",p="longitude",o=A.F(a.i(0,"firstDriveId")),n=A.F(a.i(0,"secondDriveId")),m=A.F(a.i(0,"firstSectionId")),l=A.F(a.i(0,"secondSectionId")),k=A.v(a.i(0,"firstStartOffsetMeters")),j=A.v(a.i(0,"firstEndOffsetMeters")),i=A.v(a.i(0,"secondStartOffsetMeters")),h=A.v(a.i(0,"secondEndOffsetMeters")),g=t.P,f=g.a(a.i(0,"commonStart"))
A.v(f.i(0,q))
A.v(f.i(0,p))
g=g.a(a.i(0,"commonEnd"))
A.v(g.i(0,q))
A.v(g.i(0,p))
g=A.v(a.i(0,"commonDistanceMeters"))
A.eQ(a.i(0,"directionCompatible"))
f=A.v(a.i(0,"geometryConfidence"))
s=A.eQ(a.i(0,"comparisonEligible"))
A.eQ(a.i(0,"ownershipCovered"))
r=J.cI(t.j.a(a.i(0,"referenceGeometry")),new A.eV(),t.x)
A.y(r,r.$ti.h("q.E"))
return new A.de(o,n,m,l,k,j,i,h,g,f,s)},
ji(a,b,c,d,e,f){var s,r,q,p,o,n,m,l,k="secondExtraction",j=t.t,i=B.l.aN(b,j.a(d),a,c,j.a(e))
if(!i.gaQ())return A.an(["status","telemetryUnavailable","firstExtraction",A.f3(i.a),k,A.f3(i.b),"windows",[],"winningRegions",[]],t.N,t.z)
j=i.a
s=j.b
r=i.b
q=r.b
p=f.bN(B.C,b,s,a,c,q)
o=new A.eh(f).bM(B.C,c,q,b,s,a)
s=A.hm(p)
j=A.f3(j)
r=A.f3(r)
q=o.c
n=A.h(q)
m=n.h("f<1,r<e,j>>")
q=A.y(new A.f(q,n.h("r<e,j>(1)").a(new A.eS()),m),m.h("q.E"))
n=o.d
m=A.h(n)
l=m.h("f<1,r<e,j>>")
n=A.y(new A.f(n,m.h("r<e,j>(1)").a(new A.eT()),l),l.h("q.E"))
return A.an(["status",o.a.b,"comparison",s,"firstExtraction",j,k,r,"windows",q,"winningRegions",n],t.N,t.z)},
eZ:function eZ(){},
eY:function eY(){},
f_:function f_(){},
f0:function f0(){},
f5:function f5(){},
f1:function f1(){},
f2:function f2(){},
f4:function f4(){},
eV:function eV(){},
eS:function eS(){},
eT:function eT(){},
cv:function cv(a){this.y=a
this.z=0},
jx(){var s,r=new A.eX()
if(typeof r=="function")A.aD(A.f6("Attempting to rewrap a JS function."))
s=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.iM,r)
s[$.fn()]=r
v.G.driveItWorldScoringBoundaryTest=s},
eX:function eX(){},
jA(a){throw A.C(new A.bq("Field '"+a+"' has been assigned during initialization."),new Error())},
hu(){throw A.C(A.i3(""),new Error())},
iM(a,b,c){t.Z.a(a)
if(A.W(c)>=1)return a.$1(b)
return a.$0()},
hp(a,b,c){A.jj(c,t.H,"T","max")
return Math.max(c.a(a),c.a(b))},
fD(a,b,c,d){var s=Math.sin((c-a)*3.141592653589793/180/2),r=Math.sin((d-b)*3.141592653589793/180/2)
return 12742017.6*Math.asin(Math.sqrt(B.b.j(s*s+Math.cos(a*3.141592653589793/180)*Math.cos(c*3.141592653589793/180)*r*r,0,1)))},
ii(a){var s=a.c,r=A.fc(a.b)
return isFinite(s)&&s>0?s:r},
fc(a){var s,r,q,p,o
for(s=0,r=0;r<a.length-1;){q=a[r];++r
p=a[r]
o=A.fD(q.a,q.b,p.a,p.b)
if(isFinite(o)&&o>0)s+=o}return s},
fd(a,b,c){if(!isFinite(b)||!isFinite(a)||!isFinite(c)||a<=0||c<=0)return 0
return B.b.j(B.b.j(b/a,0,1)*c,0,c)}},B={}
var w=[A,J,B]
var $={}
A.f8.prototype={}
J.cj.prototype={
M(a,b){return a===b},
gB(a){return A.cs(a)},
k(a){return"Instance of '"+A.ct(a)+"'"},
gS(a){return A.av(A.fh(this))}}
J.cl.prototype={
k(a){return String(a)},
gB(a){return a?519018:218159},
gS(a){return A.av(t.y)},
$ias:1,
$il:1}
J.bn.prototype={
M(a,b){return null==b},
k(a){return"null"},
gB(a){return 0},
$ias:1}
J.b_.prototype={$iaZ:1}
J.ax.prototype={
gB(a){return 0},
k(a){return String(a)}}
J.em.prototype={}
J.az.prototype={}
J.bo.prototype={
k(a){var s=a[$.hw()]
if(s==null)s=a[$.fn()]
if(s==null)return this.aY(a)
return"JavaScript function for "+J.aT(s)},
$iaj:1}
J.m.prototype={
m(a,b){A.h(a).c.a(b)
a.$flags&1&&A.cH(a,29)
a.push(b)},
L(a,b){var s
A.h(a).h("c<1>").a(b)
a.$flags&1&&A.cH(a,"addAll",2)
for(s=b.gq(b);s.n();)a.push(s.gp())},
aR(a,b,c){var s=A.h(a)
return new A.f(a,s.t(c).h("1(2)").a(b),s.h("@<1>").t(c).h("f<1,2>"))},
c0(a,b){var s,r=A.bw(a.length,"",!1,t.N)
for(s=0;s<a.length;++s)this.u(r,s,A.x(a[s]))
return r.join(b)},
K(a,b){return A.eo(a,b,null,A.h(a).c)},
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
a4(a,b,c){if(b<0||b>a.length)throw A.d(A.aa(b,0,a.length,"start",null))
if(c<b||c>a.length)throw A.d(A.aa(c,b,a.length,"end",null))
if(b===c)return A.o([],A.h(a))
return A.o(a.slice(b,c),A.h(a))},
gN(a){if(a.length>0)return a[0]
throw A.d(A.aX())},
ga1(a){var s=a.length
if(s>0)return a[s-1]
throw A.d(A.aX())},
ar(a,b,c,d,e){var s,r,q,p,o
A.h(a).h("c<1>").a(d)
a.$flags&2&&A.cH(a,5)
A.fU(b,c,a.length)
s=c-b
if(s===0)return
A.ap(e,"skipCount")
if(t.j.b(d)){r=d
q=e}else{r=J.fr(d,e).aS(0,!1)
q=0}p=J.bW(r)
if(q+s>p.gl(r))throw A.d(A.i_())
if(q<b)for(o=s-1;o>=0;--o)a[b+o]=p.i(r,q+o)
else for(o=0;o<s;++o)a[b+o]=p.i(r,q+o)},
a0(a,b){var s,r
A.h(a).h("l(1)").a(b)
s=a.length
for(r=0;r<s;++r){if(b.$1(a[r]))return!0
if(a.length!==s)throw A.d(A.N(a))}return!1},
au(a,b){var s,r,q,p,o,n=A.h(a)
n.h("X(1,1)?").a(b)
a.$flags&2&&A.cH(a,"sort")
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
if(p>0)this.bq(a,p)},
aX(a){return this.au(a,null)},
bq(a,b){var s,r=a.length
for(;s=r-1,r>0;r=s)if(a[s]===null){a[s]=void 0;--b
if(b===0)break}},
gv(a){return a.length===0},
gX(a){return a.length!==0},
k(a){return A.f7(a,"[","]")},
gq(a){return new J.aF(a,a.length,A.h(a).h("aF<1>"))},
gB(a){return A.cs(a)},
gl(a){return a.length},
i(a,b){A.W(b)
if(!(b>=0&&b<a.length))throw A.d(A.eW(a,b))
return a[b]},
u(a,b,c){A.h(a).c.a(c)
a.$flags&2&&A.cH(a)
if(!(b>=0&&b<a.length))throw A.d(A.eW(a,b))
a[b]=c},
$ip:1,
$ic:1,
$iu:1}
J.ck.prototype={
c5(a){var s,r,q
if(!Array.isArray(a))return null
s=a.$flags|0
if((s&4)!==0)r="const, "
else if((s&2)!==0)r="unmodifiable, "
else r=(s&1)!==0?"fixed, ":""
q="Instance of '"+A.ct(a)+"'"
if(r==="")return q
return q+" ("+r+"length: "+a.length+")"}}
J.e9.prototype={}
J.aF.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
n(){var s,r=this,q=r.a,p=q.length
if(r.b!==p){q=A.a3(q)
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
return s+0}throw A.d(A.eB(""+a+".toInt()"))},
a3(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.d(A.eB(""+a+".round()"))},
j(a,b,c){if(this.E(b,c)>0)throw A.d(A.hk(b))
if(this.E(a,b)<0)return b
if(this.E(a,c)>0)return c
return a},
aT(a,b){var s
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
T(a,b){var s=a%b
if(s===0)return 0
if(s>0)return s
return s+b},
A(a,b){return(a|0)===a?a/b|0:this.bC(a,b)},
bC(a,b){var s=a/b
if(s>=-2147483648&&s<=2147483647)return s|0
if(s>0){if(s!==1/0)return Math.floor(s)}else if(s>-1/0)return Math.ceil(s)
throw A.d(A.eB("Result of truncating division is "+A.x(s)+": "+A.x(a)+" ~/ "+b))},
aJ(a,b){var s
if(a>0)s=this.bx(a,b)
else{s=b>31?31:b
s=a>>s>>>0}return s},
bx(a,b){return b>31?0:a>>>b},
gS(a){return A.av(t.H)},
$iP:1,
$ia:1,
$iJ:1}
J.bm.prototype={
gS(a){return A.av(t.S)},
$ias:1,
$iX:1}
J.cm.prototype={
gS(a){return A.av(t.i)},
$ias:1}
J.aI.prototype={
Y(a,b,c){return a.substring(b,A.fU(b,c,a.length))},
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
A.F(b)
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
gS(a){return A.av(t.N)},
gl(a){return a.length},
i(a,b){A.W(b)
if(!(b.ca(0,0)&&b.cd(0,a.length)))throw A.d(A.eW(a,b))
return a[b]},
$ias:1,
$iP:1,
$ie:1}
A.b5.prototype={
gq(a){return new A.bb(J.a4(this.gV()),A.i(this).h("bb<1,2>"))},
gl(a){return J.aE(this.gV())},
gv(a){return J.fq(this.gV())},
gX(a){return J.hM(this.gV())},
K(a,b){var s=A.i(this)
return A.fw(J.fr(this.gV(),b),s.c,s.y[1])},
k(a){return J.aT(this.gV())}}
A.bb.prototype={
n(){return this.a.n()},
gp(){return this.$ti.y[1].a(this.a.gp())},
$iw:1}
A.aG.prototype={
gV(){return this.a}}
A.bM.prototype={$ip:1}
A.bq.prototype={
k(a){return"LateInitializationError: "+this.a}}
A.en.prototype={}
A.p.prototype={}
A.q.prototype={
gq(a){var s=this
return new A.bv(s,s.gl(s),A.i(s).h("bv<q.E>"))},
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
K(a,b){return A.eo(this,b,null,A.i(this).h("q.E"))}}
A.bF.prototype={
gb9(){var s=J.aE(this.a),r=this.c
if(r==null||r>s)return s
return r},
gby(){var s=J.aE(this.a),r=this.b
if(r>s)return s
return r},
gl(a){var s,r=J.aE(this.a),q=this.b
if(q>=r)return 0
s=this.c
if(s==null||s>=r)return r-q
return s-q},
C(a,b){var s=this,r=s.gby()+b
if(b<0||r>=s.gb9())throw A.d(A.e6(b,s.gl(0),s,null,"index"))
return J.fp(s.a,r)},
K(a,b){var s,r,q=this
A.ap(b,"count")
s=q.b+b
r=q.c
if(r!=null&&s>=r)return new A.bi(q.$ti.h("bi<1>"))
return A.eo(q.a,s,r,q.$ti.c)},
aS(a,b){var s,r,q,p=this,o=p.b,n=p.a,m=J.bW(n),l=m.gl(n),k=p.c
if(k!=null&&k<l)l=k
s=l-o
if(s<=0){n=J.fE(0,p.$ti.c)
return n}r=A.bw(s,m.C(n,o),!1,p.$ti.c)
for(q=1;q<s;++q){B.a.u(r,q,m.C(n,o+q))
if(m.gl(n)<l)throw A.d(A.N(p))}return r}}
A.bv.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
n(){var s,r=this,q=r.a,p=q.gl(q)
if(r.b!==p)throw A.d(A.N(q))
s=r.c
if(s>=p){r.d=null
return!1}r.d=q.C(0,s);++r.c
return!0},
$iw:1}
A.ao.prototype={
gq(a){return new A.bz(J.a4(this.a),this.b,A.i(this).h("bz<1,2>"))},
gl(a){return J.aE(this.a)},
gv(a){return J.fq(this.a)}}
A.bh.prototype={$ip:1}
A.bz.prototype={
n(){var s=this,r=s.b
if(r.n()){s.a=s.c.$1(r.gp())
return!0}s.a=null
return!1},
gp(){var s=this.a
return s==null?this.$ti.y[1].a(s):s},
$iw:1}
A.f.prototype={
gl(a){return J.aE(this.a)},
C(a,b){return this.b.$1(J.fp(this.a,b))}}
A.z.prototype={
gq(a){return new A.a1(J.a4(this.a),this.b,this.$ti.h("a1<1>"))}}
A.a1.prototype={
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
A.aq.prototype={
K(a,b){A.cW(b,"count",t.S)
A.ap(b,"count")
return new A.aq(this.a,this.b+b,A.i(this).h("aq<1>"))},
gq(a){var s=this.a
return new A.bD(s.gq(s),this.b,A.i(this).h("bD<1>"))}}
A.aV.prototype={
gl(a){var s=this.a,r=s.gl(s)-this.b
if(r>=0)return r
return 0},
K(a,b){A.cW(b,"count",t.S)
A.ap(b,"count")
return new A.aV(this.a,this.b+b,this.$ti)},
$ip:1}
A.bD.prototype={
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
K(a,b){A.ap(b,"count")
return this}}
A.bj.prototype={
n(){return!1},
gp(){throw A.d(A.aX())},
$iw:1}
A.be.prototype={}
A.bd.prototype={
gv(a){return this.gl(this)===0},
k(a){return A.ej(this)},
a2(a,b,c,d){var s=A.aJ(c,d)
this.H(0,new A.dj(this,A.i(this).t(c).t(d).h("E<1,2>(3,4)").a(b),s))
return s},
$ir:1}
A.dj.prototype={
$2(a,b){var s=A.i(this.a),r=this.b.$2(s.c.a(a),s.y[1].a(b))
this.c.u(0,r.a,r.b)},
$S(){return A.i(this.a).h("~(1,2)")}}
A.Q.prototype={
gl(a){return this.b.length},
gbg(){var s=this.$keys
if(s==null){s=Object.keys(this.a)
this.$keys=s}return s},
bO(a){if(typeof a!="string")return!1
if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
i(a,b){if(!this.bO(b))return null
return this.b[this.a[b]]},
H(a,b){var s,r,q,p
this.$ti.h("~(1,2)").a(b)
s=this.gbg()
r=this.b
for(q=s.length,p=0;p<q;++p)b.$2(s[p],r[p])}}
A.ch.prototype={
M(a,b){if(b==null)return!1
return b instanceof A.aW&&this.a.M(0,b.a)&&A.fk(this)===A.fk(b)},
gB(a){return A.fL(this.a,A.fk(this))},
k(a){var s=B.a.c0([A.av(this.$ti.c)],", ")
return this.a.k(0)+" with "+("<"+s+">")}}
A.aW.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.jw(A.eU(this.a),this.$ti)}}
A.bC.prototype={}
A.ez.prototype={
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
A.bA.prototype={
k(a){return"Null check operator used on a null value"}}
A.co.prototype={
k(a){var s,r=this,q="NoSuchMethodError: method not found: '",p=r.b
if(p==null)return"NoSuchMethodError: "+r.a
s=r.c
if(s==null)return q+p+"' ("+r.a+")"
return q+p+"' on '"+s+"' ("+r.a+")"}}
A.cz.prototype={
k(a){var s=this.a
return s.length===0?"Error":"Error: "+s}}
A.el.prototype={
k(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.K.prototype={
k(a){var s=this.constructor,r=s==null?null:s.name
return"Closure '"+A.hv(r==null?"unknown":r)+"'"},
$iaj:1,
gc8(){return this},
$C:"$1",
$R:1,
$D:null}
A.c0.prototype={$C:"$0",$R:0}
A.c1.prototype={$C:"$2",$R:2}
A.cx.prototype={}
A.cw.prototype={
k(a){var s=this.$static_name
if(s==null)return"Closure of unknown static method"
return"Closure '"+A.hv(s)+"'"}}
A.aU.prototype={
M(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.aU))return!1
return this.$_target===b.$_target&&this.a===b.a},
gB(a){return(A.hq(this.a)^A.cs(this.$_target))>>>0},
k(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.ct(this.a)+"'")}}
A.cu.prototype={
k(a){return"RuntimeError: "+this.a}}
A.ak.prototype={
gl(a){return this.a},
gv(a){return this.a===0},
gR(){return new A.al(this,A.i(this).h("al<1>"))},
L(a,b){A.i(this).h("r<1,2>").a(b).H(0,new A.ea(this))},
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
s=q[this.aO(a)]
r=this.aP(s,a)
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
r=o.aO(a)
q=s[r]
if(q==null)s[r]=[o.ak(a,b)]
else{p=o.aP(q,a)
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
ak(a,b){var s=this,r=A.i(s),q=new A.ee(r.c.a(a),r.y[1].a(b))
if(s.e==null)s.e=s.f=q
else s.f=s.f.c=q;++s.a
s.r=s.r+1&1073741823
return q},
aO(a){return J.ba(a)&1073741823},
aP(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.fo(a[r].a,b))return r
return-1},
k(a){return A.ej(this)},
aj(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
$ifG:1}
A.ea.prototype={
$2(a,b){var s=this.a,r=A.i(s)
s.u(0,r.c.a(a),r.y[1].a(b))},
$S(){return A.i(this.a).h("~(1,2)")}}
A.ee.prototype={}
A.al.prototype={
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
return!1}else{r.d=s.a
r.c=s.c
return!0}},
$iw:1}
A.am.prototype={
gl(a){return this.a.a},
gv(a){return this.a.a===0},
gq(a){var s=this.a
return new A.bu(s,s.r,s.e,this.$ti.h("bu<1>"))}}
A.bu.prototype={
gp(){return this.d},
n(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.d(A.N(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.b
r.c=s.c
return!0}},
$iw:1}
A.br.prototype={
gl(a){return this.a.a},
gv(a){return this.a.a===0},
gq(a){var s=this.a
return new A.bs(s,s.r,s.e,this.$ti.h("bs<1,2>"))}}
A.bs.prototype={
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
A.cn.prototype={
k(a){return"RegExp/"+this.a+"/"+this.b.flags},
bU(a){var s=this.b.exec(a)
if(s==null)return null
return new A.eJ(s)},
$iib:1}
A.eJ.prototype={
i(a,b){var s
A.W(b)
s=this.b
if(!(b<s.length))return A.b(s,b)
return s[b]}}
A.a0.prototype={
h(a){return A.eM(v.typeUniverse,this,a)},
t(a){return A.iB(v.typeUniverse,this,a)}}
A.cB.prototype={}
A.eK.prototype={
k(a){return A.M(this.a,null)}}
A.cA.prototype={
k(a){return this.a}}
A.b6.prototype={}
A.au.prototype={
gq(a){var s=this,r=new A.aO(s,s.r,A.i(s).h("aO<1>"))
r.c=s.e
return r},
gl(a){return this.a},
gv(a){return this.a===0},
gX(a){return this.a!==0},
aa(a,b){var s,r
if(typeof b=="string"&&b!=="__proto__"){s=this.b
if(s==null)return!1
return t.M.a(s[b])!=null}else{r=this.b4(b)
return r}},
b4(a){var s=this.d
if(s==null)return!1
return this.aB(s[this.az(a)],a)>=0},
m(a,b){var s,r,q=this
A.i(q).c.a(b)
if(typeof b=="string"&&b!=="__proto__"){s=q.b
return q.aw(s==null?q.b=A.fe():s,b)}else if(typeof b=="number"&&(b&1073741823)===b){r=q.c
return q.aw(r==null?q.c=A.fe():r,b)}else return q.b_(b)},
b_(a){var s,r,q,p=this
A.i(p).c.a(a)
s=p.d
if(s==null)s=p.d=A.fe()
r=p.az(a)
q=s[r]
if(q==null)s[r]=[p.ae(a)]
else{if(p.aB(q,a)>=0)return!1
q.push(p.ae(a))}return!0},
aw(a,b){A.i(this).c.a(b)
if(t.M.a(a[b])!=null)return!1
a[b]=this.ae(b)
return!0},
ae(a){var s=this,r=new A.cE(A.i(s).c.a(a))
if(s.e==null)s.e=s.f=r
else s.f=s.f.b=r;++s.a
s.r=s.r+1&1073741823
return r},
az(a){return J.ba(a)&1073741823},
aB(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.fo(a[r].a,b))return r
return-1},
$ifI:1}
A.cE.prototype={}
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
A.ef.prototype={
$2(a,b){this.a.u(0,this.b.a(a),this.c.a(b))},
$S:16}
A.I.prototype={
H(a,b){var s,r,q,p=A.i(this)
p.h("~(I.K,I.V)").a(b)
for(s=this.gR(),s=s.gq(s),p=p.h("I.V");s.n();){r=s.gp()
q=this.i(0,r)
b.$2(r,q==null?p.a(q):q)}},
a2(a,b,c,d){var s,r,q,p,o,n=A.i(this)
n.t(c).t(d).h("E<1,2>(I.K,I.V)").a(b)
s=A.aJ(c,d)
for(r=this.gR(),r=r.gq(r),n=n.h("I.V");r.n();){q=r.gp()
p=this.i(0,q)
o=b.$2(q,p==null?n.a(p):p)
s.u(0,o.a,o.b)}return s},
gl(a){var s=this.gR()
return s.gl(s)},
gv(a){var s=this.gR()
return s.gv(s)},
k(a){return A.ej(this)},
$ir:1}
A.ek.prototype={
$2(a,b){var s,r=this.a
if(!r.a)this.b.a+=", "
r.a=!1
r=this.b
s=A.x(a)
r.a=(r.a+=s)+": "
s=A.x(b)
r.a+=s},
$S:13}
A.bT.prototype={}
A.b1.prototype={
i(a,b){return this.a.i(0,b)},
H(a,b){this.a.H(0,this.$ti.h("~(1,2)").a(b))},
gv(a){return this.a.a===0},
gl(a){return this.a.a},
k(a){return A.ej(this.a)},
a2(a,b,c,d){return this.a.a2(0,this.$ti.t(c).t(d).h("E<1,2>(3,4)").a(b),c,d)},
$ir:1}
A.bJ.prototype={}
A.eg.prototype={
gq(a){var s=this
return new A.bN(s,s.c,s.d,s.b,s.$ti.h("bN<1>"))},
gv(a){return this.b===this.c},
gl(a){return(this.c-this.b&this.a.length-1)>>>0},
C(a,b){var s,r,q=this,p=q.gl(0)
if(0>b||b>=p)A.aD(A.e6(b,p,q,null,"index"))
p=q.a
s=p.length
r=(q.b+b&s-1)>>>0
if(!(r>=0&&r<s))return A.b(p,r)
r=p[r]
return r==null?q.$ti.c.a(r):r},
k(a){return A.f7(this,"{","}")}}
A.bN.prototype={
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
k(a){return A.f7(this,"{","}")},
K(a,b){return A.fW(this,b,A.i(this).c)},
$ip:1,
$ic:1,
$iaM:1}
A.bP.prototype={}
A.cF.prototype={
m(a,b){this.$ti.c.a(b)
return A.iE()}}
A.bK.prototype={
aa(a,b){return this.a.aa(0,b)},
gl(a){return this.a.a},
gq(a){var s=this.a
return A.il(s,s.r,A.i(s).c)}}
A.b7.prototype={}
A.bU.prototype={}
A.cC.prototype={
i(a,b){var s,r=this.b
if(r==null)return this.c.i(0,b)
else if(typeof b!="string")return null
else{s=r[b]
return typeof s=="undefined"?this.bm(b):s}},
gl(a){return this.b==null?this.c.a:this.a6().length},
gv(a){return this.gl(0)===0},
gR(){if(this.b==null){var s=this.c
return new A.al(s,A.i(s).h("al<1>"))}return new A.cD(this)},
H(a,b){var s,r,q,p,o=this
t.fH.a(b)
if(o.b==null)return o.c.H(0,b)
s=o.a6()
for(r=0;r<s.length;++r){q=s[r]
p=o.b[q]
if(typeof p=="undefined"){p=A.eR(o.a[q])
o.b[q]=p}b.$2(q,p)
if(s!==o.c)throw A.d(A.N(o))}},
a6(){var s=t.bF.a(this.c)
if(s==null)s=this.c=A.o(Object.keys(this.a),t.s)
return s},
bm(a){var s
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
s=A.eR(this.a[a])
return this.b[a]=s}}
A.cD.prototype={
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
A.c2.prototype={}
A.c6.prototype={}
A.bp.prototype={
k(a){var s=A.ce(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+s}}
A.cp.prototype={
k(a){return"Cyclic error in JSON stringify"}}
A.eb.prototype={
bP(a,b){var s=A.j9(a,this.gbQ().a)
return s},
bR(a,b){var s=A.ik(a,this.gbS().b,null)
return s},
gbS(){return B.aw},
gbQ(){return B.av}}
A.ed.prototype={}
A.ec.prototype={}
A.eH.prototype={
aV(a){var s,r,q,p,o,n,m=a.length
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
if(a==null?p==null:a===p)throw A.d(new A.cp(a,null))}B.a.m(s,a)},
ac(a){var s,r,q,p,o=this
if(o.aU(a))return
o.ad(a)
try{s=o.b.$1(a)
if(!o.aU(s)){q=A.fF(a,null,o.gaH())
throw A.d(q)}q=o.a
if(0>=q.length)return A.b(q,-1)
q.pop()}catch(p){r=A.fm(p)
q=A.fF(a,r,o.gaH())
throw A.d(q)}},
aU(a){var s,r,q=this
if(typeof a=="number"){if(!isFinite(a))return!1
q.c.a+=B.b.k(a)
return!0}else if(a===!0){q.c.a+="true"
return!0}else if(a===!1){q.c.a+="false"
return!0}else if(a==null){q.c.a+="null"
return!0}else if(typeof a=="string"){s=q.c
s.a+='"'
q.aV(a)
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
s=J.bV(a)
if(s.gX(a)){this.ac(s.i(a,0))
for(r=1;r<s.gl(a);++r){q.a+=","
this.ac(s.i(a,r))}}q.a+="]"},
c7(a){var s,r,q,p,o,n,m=this,l={}
if(a.gv(a)){m.c.a+="{}"
return!0}s=a.gl(a)*2
r=A.bw(s,null,!1,t.U)
q=l.a=0
l.b=!0
a.H(0,new A.eI(l,r))
if(!l.b)return!1
p=m.c
p.a+="{"
for(o='"';q<s;q+=2,o=',"'){p.a+=o
m.aV(A.F(r[q]))
p.a+='":'
n=q+1
if(!(n<s))return A.b(r,n)
m.ac(r[n])}p.a+="}"
return!0}}
A.eI.prototype={
$2(a,b){var s,r
if(typeof a!="string")this.a.b=!1
s=this.b
r=this.a
B.a.u(s,r.a++,a)
B.a.u(s,r.a++,b)},
$S:13}
A.eG.prototype={
gaH(){var s=this.c.a
return s.charCodeAt(0)==0?s:s}}
A.dt.prototype={
$0(){var s=this
return A.aD(A.f6("("+s.a+", "+s.b+", "+s.c+", "+s.d+", "+s.e+", "+s.f+", "+s.r+", "+s.w+")"))},
$S:19}
A.a6.prototype={
O(a){var s=1000,r=B.c.T(a,s),q=B.c.A(a-r,s),p=this.b+r,o=B.c.T(p,s),n=this.c
return new A.a6(A.fA(this.a+B.c.A(p-o,s)+q,o,n),o,n)},
W(a){return A.D(this.b-a.b,this.a-a.a)},
M(a,b){if(b==null)return!1
return b instanceof A.a6&&this.a===b.a&&this.b===b.b&&this.c===b.c},
gB(a){return A.fL(this.a,this.b)},
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
return new A.a6(s.a,s.b,!0)},
k(a){var s=this,r=A.fz(A.cr(s)),q=A.ag(A.fR(s)),p=A.ag(A.fN(s)),o=A.ag(A.fO(s)),n=A.ag(A.fQ(s)),m=A.ag(A.fS(s)),l=A.du(A.fP(s)),k=s.b,j=k===0?"":A.du(k)
k=r+"-"+q
if(s.c)return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+" "+o+":"+n+":"+m+"."+l+j},
c3(){var s=this,r=A.cr(s)>=-9999&&A.cr(s)<=9999?A.fz(A.cr(s)):A.hY(A.cr(s)),q=A.ag(A.fR(s)),p=A.ag(A.fN(s)),o=A.ag(A.fO(s)),n=A.ag(A.fQ(s)),m=A.ag(A.fS(s)),l=A.du(A.fP(s)),k=s.b,j=k===0?"":A.du(k)
k=r+"-"+q
if(s.c)return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j+"Z"
else return k+"-"+p+"T"+o+":"+n+":"+m+"."+l+j},
$iP:1}
A.dv.prototype={
$1(a){if(a==null)return 0
return A.cG(a)},
$S:12}
A.dw.prototype={
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
$iP:1}
A.eD.prototype={
k(a){return this.D()}}
A.t.prototype={}
A.bZ.prototype={
k(a){var s=this.a
if(s!=null)return"Assertion failed: "+A.ce(s)
return"Assertion failed"}}
A.bI.prototype={}
A.ad.prototype={
gah(){return"Invalid argument"+(!this.a?"(s)":"")},
gag(){return""},
k(a){var s=this,r=s.c,q=r==null?"":" ("+r+")",p=s.d,o=p==null?"":": "+p,n=s.gah()+q+o
if(!s.a)return n
return n+s.gag()+": "+A.ce(s.gap())},
gap(){return this.b}}
A.bB.prototype={
gap(){return A.hb(this.b)},
gah(){return"RangeError"},
gag(){var s,r=this.e,q=this.f
if(r==null)s=q!=null?": Not less than or equal to "+A.x(q):""
else if(q==null)s=": Not greater than or equal to "+A.x(r)
else if(q>r)s=": Not in inclusive range "+A.x(r)+".."+A.x(q)
else s=q<r?": Valid value range is empty":": Only valid value is "+A.x(r)
return s}}
A.cg.prototype={
gap(){return A.W(this.b)},
gah(){return"RangeError"},
gag(){if(A.W(this.b)<0)return": index must not be negative"
var s=this.f
if(s===0)return": no indices are valid"
return": index should be less than "+s},
gl(a){return this.f}}
A.bL.prototype={
k(a){return"Unsupported operation: "+this.a}}
A.b2.prototype={
k(a){return"Bad state: "+this.a}}
A.c5.prototype={
k(a){var s=this.a
if(s==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.ce(s)+"."}}
A.cq.prototype={
k(a){return"Out of Memory"},
$it:1}
A.bE.prototype={
k(a){return"Stack Overflow"},
$it:1}
A.eE.prototype={
k(a){return"Exception: "+this.a}}
A.e5.prototype={
k(a){var s=this.a,r=""!==s?"FormatException: "+s:"FormatException",q=this.b
if(typeof q=="string"){if(q.length>78)q=B.e.Y(q,0,75)+"..."
return r+"\n"+q}else return r}}
A.c.prototype={
aR(a,b,c){var s=A.i(this)
return A.i8(this,s.t(c).h("1(c.E)").a(b),s.h("c.E"),c)},
F(a,b,c,d){var s,r
d.a(b)
A.i(this).t(d).h("1(1,c.E)").a(c)
for(s=this.gq(this),r=b;s.n();)r=c.$2(r,s.gp())
return r},
aS(a,b){var s=A.i(this).h("c.E")
if(b)s=A.y(this,s)
else{s=A.y(this,s)
s.$flags=1
s=s}return s},
gl(a){var s,r=this.gq(this)
for(s=0;r.n();)++s
return s},
gv(a){return!this.gq(this).n()},
gX(a){return!this.gv(this)},
K(a,b){return A.fW(this,b,A.i(this).h("c.E"))},
bV(a,b,c){var s,r=A.i(this)
r.h("l(c.E)").a(b)
r.h("c.E()?").a(c)
for(r=this.gq(this);r.n();){s=r.gp()
if(b.$1(s))return s}r=c.$0()
return r},
C(a,b){var s,r
A.ap(b,"index")
s=this.gq(this)
for(r=b;s.n();){if(r===0)return s.gp();--r}throw A.d(A.e6(b,b-r,this,null,"index"))},
k(a){return A.i0(this,"(",")")}}
A.E.prototype={
k(a){return"MapEntry("+A.x(this.a)+": "+A.x(this.b)+")"}}
A.aL.prototype={
gB(a){return A.j.prototype.gB.call(this,0)},
k(a){return"null"}}
A.j.prototype={$ij:1,
M(a,b){return this===b},
gB(a){return A.cs(this)},
k(a){return"Instance of '"+A.ct(this)+"'"},
gS(a){return A.js(this)},
toString(){return this.k(this)}}
A.b3.prototype={
gl(a){return this.a.length},
k(a){var s=this.a
return s.charCodeAt(0)==0?s:s},
$iig:1}
A.cJ.prototype={
G(a){var s,r,q,p,o,n,m=A.o([],t.g)
for(s=a.P(B.i),r=J.a4(s.a),s=new A.a1(r,s.b,s.$ti.h("a1<1>")),q=0;s.n();){p=r.gp()
o=p.at
n=Math.max(o.c,o.d)
o=!0
if(p.ax===B.t)if(!(p.x-p.w<4))o=n>=0.65&&p.y<12
if(o)++q
else B.a.m(m,p)}if(m.length===0)return new A.bY(0,!1,!1)
s=new A.cR(m)
return new A.bY(s.$1(new A.cT(this))*25+s.$1(new A.cU(this,a))*15+s.$1(new A.cV(this,a))*10,!0,m.length>=2)},
aZ(a,b){var s=B.a.a4(a.b,b.d,b.e+1),r=A.h(s),q=r.h("f<1,a>"),p=A.y(new A.f(s,r.h("a(1)").a(new A.cK()),q),q.h("q.E"))
return B.a.F(p,0,new A.cL(B.a.J(p,new A.cM())/p.length),t.i)/p.length},
bu(a,b){var s=a.b,r=A.h(s),q=r.h("ao<1,a>"),p=A.y(new A.ao(new A.z(s,r.h("l(1)").a(new A.cN(b,b.r.O(4e6))),r.h("z<1>")),r.h("a(1)").a(new A.cO()),q),q.h("c.E"))
if(p.length<2)return 0
return 1-B.b.j(Math.sqrt(B.a.F(p,0,new A.cP(B.a.J(p,new A.cQ())/p.length),t.i)/p.length)/3,0,1)}}
A.cR.prototype={
$1(a){var s=this.a,r=A.h(s)
return new A.f(s,r.h("a(1)").a(t.bE.a(a)),r.h("f<1,a>")).J(0,new A.cS())/s.length},
$S:14}
A.cS.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.cT.prototype={
$1(a){t.F.a(a)
return B.b.j((a.x-a.w)/B.c.A(a.r.W(a.f).a,1000)*1000/2.5,0,1)},
$S:7}
A.cU.prototype={
$1(a){return 1-B.b.j(this.a.aZ(this.b,t.F.a(a))/0.55,0,1)},
$S:7}
A.cV.prototype={
$1(a){return this.a.bu(this.b,t.F.a(a))},
$S:7}
A.cK.prototype={
$1(a){return t.K.a(a).e},
$S:3}
A.cM.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.cL.prototype={
$2(a,b){var s
A.n(a)
s=A.n(b)-this.a
return a+s*s},
$S:0}
A.cN.prototype={
$1(a){t.K.a(a)
return a.a>this.a.e&&!a.b.c.bZ(this.b)},
$S:1}
A.cO.prototype={
$1(a){return t.K.a(a).b.d},
$S:3}
A.cQ.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.cP.prototype={
$2(a,b){var s
A.n(a)
s=A.n(b)-this.a
return a+s*s},
$S:0}
A.cY.prototype={
G(b4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0=this,b1=b4.P(B.n),b2=b1.$ti,b3=b2.h("z<c.E>")
b1=A.y(new A.z(b1,b2.h("l(c.E)").a(new A.db()),b3),b3.h("c.E"))
b1.$flags=1
s=b1
b1=b4.P(B.E)
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
n=A.fK(t.N)
for(b2=s.length,m=0,l=0,k=0,j=0;j<s.length;s.length===b2||(0,A.a3)(s),++j){i=s[j]
if(!(i.as<=0)){b3=i.r
h=i.f
h=A.D(b3.b-h.b,b3.a-h.a).a<=0
b3=h}else b3=!0
if(b3){++m
continue}g=b0.bc(i,q)
b3=i.at
f=B.b.j(1-Math.max(b3.c*0.25,b3.d*0.45),0,1)
if(f<1||g)++k
e=b0.aI(b4,i)
d=b0.bv(e)
if(e>=5){++l
n.m(0,i.a)}b3=g?0.6:1
B.a.m(o,d*f*b3)
B.a.m(p,new A.aB(b0.b1(b4,i,g),Math.max(1,i.w-i.x)))}c=p.length===0
b=c?150:150*b0.bI(p)
a=o.length===0
a0=a?100:100*(1-b0.b0(o))
a1=b0.bb(b4,s)
a2=a1.length===0
a3=b0.bh(a1)
a4=a2?60:60*(1-a3)
b2=A.h(a1)
new A.z(a1,b2.h("l(1)").a(new A.dc()),b2.h("z<1>")).gl(0)
a5=A.o([],b1)
for(b1=r.length,j=0;j<r.length;r.length===b1||(0,A.a3)(r),++j){a6=b0.bA(b4,r[j],s,n)
if(a6==null)++m
else B.a.m(a5,a6)}a7=a5.length===0
a8=a7?40:40*b0.U(a5)
a9=B.b.j(b+a0+a4+a8,0,350)
B.b.j(b,0,150)
B.b.j(a0,0,100)
B.b.j(a4,0,60)
B.b.j(a8,0,40)
return new A.dd(a9,s.length,a5.length,new A.cX(c,a,a2,a7))},
b1(a,a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=a.b,d=a0.d,c=a0.e,b=e.length
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
g=A.eo(e,0,A.hl(d,"count",t.S),A.h(e).c).a0(0,new A.cZ(h))?0.08:0
f=a1?0.1:0
return B.b.j(0.4*B.b.j(l+g+f,0,1)+0.3*(1-b)+0.3*(1-k),0,1)},
aI(a,b){var s,r,q,p,o,n
for(s=b.d,r=b.e,q=a.b,p=q.length,o=0;s<=r;++s){if(!(s<p))return A.b(q,s)
n=q[s]
o=Math.max(o,Math.max(-n.b.x,-n.e))}return o},
bv(a){var s=this
if(a<=1.5)return 0
if(a<=2.5)return s.a5(0,0.15,(a-1.5)/1)
if(a<=3.5)return s.a5(0.15,0.35,(a-2.5)/1)
if(a<=5)return s.a5(0.35,0.75,(a-3.5)/1.5)
return s.a5(0.75,1,(a-5)/5)},
b0(a){var s
t.o.a(a)
s=this.U(a)
if(a.length===1)return Math.min(s,0.35)
return B.b.j(s*1.35,0,1)},
bb(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c
t.B.a(b)
s=a.P(B.i)
r=s.$ti
q=r.h("z<c.E>")
s=A.y(new A.z(s,r.h("l(c.E)").a(new A.d_()),q),q.h("c.E"))
s.$flags=1
p=s
o=A.o([],t.h9)
for(s=p.length,n=0;n<p.length;p.length===s||(0,A.a3)(p),++n){m=p[n]
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
if(d.a>A.D(0,B.b.a3(c*1000)).a)break
if(h.w-h.x<=0)continue
B.a.m(o,new A.ab(l,this.aI(a,h),this.bi(h.at)))
break}}return o},
bh(a){var s,r,q,p,o
t.cT.a(a)
if(a.length===0)return 0
s=A.h(a)
r=s.h("a(1)")
s=s.h("f<1,a>")
q=this.U(new A.f(a,r.a(new A.d2(this)),s))
p=a.length
o=p===1?0.15:B.b.j(p/3,0.45,1)
return B.b.j(q*o*(1-this.U(new A.f(a,r.a(new A.d3()),s))),0,1)},
bA(a,b,a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=null
t.B.a(a0)
t.cq.a(a1)
s=this.ba(a,b.d)
if(s==null)return c
r=a.b
q=b.e
p=B.a.a4(r,s,q+1)
o=A.h(p)
if(new A.f(p,o.h("a(1)").a(new A.d5()),o.h("f<1,a>")).J(0,B.Q)<4.166666666666667)return c
p=A.h(a0)
o=p.h("z<1>")
n=A.fw(new A.z(a0,p.h("l(1)").a(new A.d6(b)),o),o.h("c.E"),t.J).bV(0,new A.d7(),new A.d8())
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
ba(a,b){var s,r,q
for(s=a.b,r=s.length,q=b;q>=0;--q){if(!(q<r))return A.b(s,q)
if(s[q].b.d>=4.166666666666667)return q}return null},
bc(a,b){t.B.a(b)
return a.ch.aa(0,B.r)||B.a.a0(a.CW,new A.d1(b))},
bi(a){var s=a.d,r=Math.max(a.c,s)
if(r<=0)return 0
return B.b.j(0.8*r+0.19999999999999996*s,0,1)},
aE(a,b,c,d){var s,r,q,p,o,n,m
t.X.a(a)
s=a.length
if(!(b<s))return A.b(a,b)
r=a[b].b.c
if(!(c<s))return A.b(a,c)
q=r.O(A.D(0,B.b.a3(B.c.A(a[c].b.c.W(r).a,1000)*d)).a)
for(r=q.a,p=q.b,o=b;o<=c;++o){if(!(o<s))return A.b(a,o)
n=a[o].b.c
m=n.a
if(m>=r)n=m===r&&n.b<p
else n=!0
if(!n)return o}return c},
bI(a){var s,r
t.ap.a(a)
s=t.i
r=B.a.F(a,0,new A.d9(),s)
if(r<=0)return 1
return B.a.F(a,0,new A.da(),s)/r},
U(a){var s,r,q
for(s=J.a4(t.bM.a(a)),r=0,q=0;s.n();){r+=s.gp();++q}return q===0?0:r/q},
aK(a){var s
t.o.a(a)
if(a.length<2)return 0
s=A.h(a)
return Math.sqrt(this.U(new A.f(a,s.h("a(1)").a(new A.d4(this.U(a))),s.h("f<1,a>"))))},
a5(a,b,c){return a+(b-a)*B.b.j(c,0,1)}}
A.db.prototype={
$1(a){return t.F.a(a).ax===B.I},
$S:4}
A.dc.prototype={
$1(a){return t.k.a(a).c>0},
$S:15}
A.cZ.prototype={
$1(a){t.K.a(a)
return!a.b.c.c_(this.a)&&a.e<-0.08},
$S:1}
A.d_.prototype={
$1(a){return t.F.a(a).ax===B.t},
$S:4}
A.d2.prototype={
$1(a){t.k.a(a)
return 0.6*B.b.j(a.a/9,0,1)+0.4*B.b.j(a.b/3.5,0,1)},
$S:10}
A.d3.prototype={
$1(a){return t.k.a(a).c},
$S:10}
A.d5.prototype={
$1(a){return t.K.a(a).b.d},
$S:3}
A.d6.prototype={
$1(a){var s,r
t.F.a(a)
s=this.a
r=s.f.W(a.r)
return a.e<=s.d&&Math.abs(r.a)<=3e6},
$S:4}
A.d7.prototype={
$1(a){return t.J.a(a)!=null},
$S:21}
A.d8.prototype={
$0(){return null},
$S:22}
A.d1.prototype={
$1(a){return B.a.a0(this.a,new A.d0(A.F(a)))},
$S:36}
A.d0.prototype={
$1(a){return t.F.a(a).a===this.a},
$S:4}
A.d9.prototype={
$2(a,b){return A.n(a)+t.E.a(b).b},
$S:11}
A.da.prototype={
$2(a,b){A.n(a)
t.E.a(b)
return a+b.a*b.b},
$S:11}
A.d4.prototype={
$1(a){return Math.pow(A.n(a)-this.a,2)},
$S:24}
A.aB.prototype={}
A.ab.prototype={}
A.dd.prototype={}
A.cX.prototype={}
A.G.prototype={
gbW(){var s,r=this.a
if(isFinite(r)){s=this.b
r=isFinite(s)&&Math.abs(r)<=90&&Math.abs(s)<=180}else r=!1
return r}}
A.c3.prototype={
aL(a,b,c,d,a0,a1,a2,a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=t.t
e.a(a0)
e.a(a7)
if(a3&&!a1.at)return f.a9(a,a1,B.a5,"Common road is below the 3000 metre comparison threshold.")
s=B.l.aM(b,c,d,a0,a1,a2,a4,a5,a6,a7)
if(!s.gaQ()){e=s.a.a===B.d||s.b.a===B.d?B.a6:B.A
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
if(typeof i!=="number")return A.ju(i)
h=e/i}n=h
m=r.a>=q.a*1.01
l=q.a>=r.a*1.01
if(m)e=B.x
else e=l?B.y:B.z
return new A.c4(r,q,p,n,e,!0)}catch(g){e=A.fm(g)
if(e instanceof A.ci){k=e
return f.a9(a,a1,B.A,u.c)}else{j=e
e=f.a9(a,a1,B.a7,J.aT(j))
return e}}},
bN(a,b,c,d,e,f){var s=null
return this.aL(a,s,b,s,c,d,0,!0,s,e,s,f)},
a9(a,b,c,d){var s=null
return new A.c4(s,s,s,s,c,!1)}}
A.de.prototype={}
A.ae.prototype={
D(){return"CommonRoadScoreComparisonOutcome."+this.b}}
A.c4.prototype={}
A.bc.prototype={
D(){return"CommonRoadTelemetryMappingStatus."+this.b}}
A.af.prototype={}
A.di.prototype={
gaQ(){return this.a.a===B.m&&this.b.a===B.m}}
A.df.prototype={
aM(a,b,c,d,e,f,g,h,i,j){var s,r,q=t.t
q.a(d)
q.a(j)
q=c==null?e.e:c
s=a==null?e.f:a
q=this.aA(s,f,b,e.c,q,d)
s=i==null?e.r:i
r=g==null?e.w:g
return new A.di(q,this.aA(r,f,h,e.d,s,j))},
aN(a,b,c,d,e){var s=null
return this.aM(s,a,s,b,c,0,s,d,s,e)},
aA(b1,b2,b3,b4,b5,b6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0=null
t.t.a(b6)
s=J.e8(b6.slice(0),A.h(b6).c)
if(s.length===0)return new A.af(B.B,B.f,b0,b0,0,"No canonical telemetry exists.")
r=this.bs(b3,b4)
if(r==null||r.b.length<2)return new A.af(B.d,B.f,b0,b0,0,"Matched road section is unavailable.")
q=this.bt(b3,b4)
if(q==null)return new A.af(B.d,B.f,b0,b0,0,"Matched road section offset is unavailable.")
p=r.b
o=A.fc(p)
n=A.ii(r)
if(!isFinite(o)||o<=0||!isFinite(n)||n<=0)return new A.af(B.d,B.f,b0,b0,0,"Matched section has no valid canonical offset axis.")
m=A.o([],t.cA)
for(l=b5-b2,k=b1+b2,j=0,i=0;i<p.length-1;){h=p[i];++i
g=p[i]
f=h.a
e=h.b
d=g.a
c=g.b
b=A.fD(f,e,d,c)
if(b<=0)continue
a=A.fd(o,j,n)
a0=j+b
if(q+A.fd(o,a0,n)>=l&&q+a<=k){a=f*3.141592653589793/180
a1=111320*Math.cos(a)
e=c-e
a2=e*3.141592653589793/180
a3=d*3.141592653589793/180
a=new A.bO(h,b,j,a1,B.b.T(Math.atan2(Math.sin(a2)*Math.cos(a3),Math.cos(a)*Math.sin(a3)-Math.sin(a)*Math.cos(a3)*Math.cos(a2))*180/3.141592653589793+360,360))
a.f=e*a1
a.r=(d-f)*111320
B.a.m(m,a)}j=a0}a4=A.o([],t.du)
for(a5=0;a5<s.length;++a5){a6=s[a5]
p=a6.a
if(isFinite(p)){f=a6.b
p=isFinite(f)&&Math.abs(p)<=90&&Math.abs(f)<=180}else p=!1
if(!p)continue
a7=this.bn(a6,m,q,o,n,b5,b1,b2)
p=!0
if(a7!=null)if(!(a7.a>35)){f=a7.c
if(!(f!=null&&f>60)){p=a7.b
p=p<l||p>k}}if(p)continue
B.a.m(a4,new A.a2(a5,a6,a7))}if(a4.length<2)return new A.af(B.B,B.f,b0,b0,0,"Fewer than two canonical samples map to the common road.")
p=t.gM
p=A.y(new A.f(a4,t.fI.a(new A.dg()),p),p.h("q.E"))
p.$flags=1
a8=p
for(p=a8.length,a5=1;a5<p;++a5){l=a8[a5].c
k=a8[a5-1].c
f=l.a
e=k.a
if(f<=e)l=f===e&&l.b>k.b
else l=!0
if(!l)return new A.af(B.d,B.f,b0,b0,0,"Mapped telemetry does not preserve strict time order.")}a9=B.b.j(1-B.a.F(a4,0,new A.dh(),t.i)/a4.length/35,0,1)
return new A.af(B.m,A.a9(a8,t.u),B.a.gN(a4).a,B.a.ga1(a4).a,a9,b0)},
bs(a,b){var s,r,q=a.d,p=q.length
if(p!==0){for(s=0;s<p;++s){r=q[s]
if(r.a===b)return r}return null}return b===a.a+":geometry"?new A.a_(b,a.c,a.e):null},
bt(a,b){var s,r,q,p,o,n=a.d,m=n.length
if(m===0)return b===a.a+":geometry"?0:null
for(s=0,r=0;r<n.length;n.length===m||(0,A.a3)(n),++r){q=n[r]
if(q.a===b)return s
p=q.c
o=A.fc(q.b)
s+=isFinite(p)&&p>0?p:o}return null},
bn(a1,a2,a3,a4,a5,a6,a7,a8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0
t.fT.a(a2)
for(s=a2.length,r=a6-a8,q=a1.e,p=a1.b,o=a1.a,n=a7+a8,m=null,l=!1,k=0;k<a2.length;a2.length===s||(0,A.a3)(a2),++k){j=a2[k]
i=j.a
h=(p-i.b)*j.d
g=(o-i.a)*111320
i=j.f
i===$&&A.hu()
f=j.r
f===$&&A.hu()
e=i*i+f*f
d=e<=0?0:B.b.j((h*i+g*f)/e,0,1)
i=h-i*d
f=g-f*d
f=Math.sqrt(i*i+f*f)
i=a3+A.fd(a4,j.c+j.b*d,a5)
c=A.iT(q,j.e)
b=new A.eF(f,i,c)
a=i>=r&&i<=n
i=!0
if(m!=null)if(!(a&&!l))if(a===l){a0=m.a
if(!(f<a0))if(Math.abs(f-a0)<=0.000001){i=c==null?1/0:c
f=m.c
i=i<(f==null?1/0:f)}else i=!1}else i=!1
if(i){l=a
m=b}}return m}}
A.dg.prototype={
$1(a){return t.A.a(a).b},
$S:17}
A.dh.prototype={
$2(a,b){return A.n(a)+t.A.a(b).c.a},
$S:18}
A.bO.prototype={
gl(a){return this.b}}
A.a2.prototype={}
A.eF.prototype={}
A.c8.prototype={
G(a){var s,r,q,p,o,n,m=A.o([],t.df)
for(s=a.P(B.h),r=J.a4(s.a),s=new A.a1(r,s.b,s.$ti.h("a1<1>")),q=0,p=0;s.n();){o=r.gp()
n=this.b5(a,o)
if(n==null){++q
if(o.as<0.5)++p}else B.a.m(m,n)}if(m.length===0)return new A.c7(0,!1,!1)
s=new A.dq(this,m)
s=B.b.j(s.$1(new A.dl())*60+s.$1(new A.dm())*35+s.$1(new A.dn())*35+s.$1(new A.dp())*20,0,150)
r=m.length
A.a9(m,t.h)
return new A.c7(s,!0,r>=2)},
b5(a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=null
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
i=b.ai(q,l,b.bp(q,o))
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
A.a9(a1.CW,t.N)
return new A.a5(r,e,a1.as,d,1-s,c,1-o)},
bp(a,b){var s,r,q,p,o,n,m,l,k
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
B.a.aX(p)
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
s=B.a.J(a,new A.dk())
r=a.length
q=s/r
for(p=0,o=0;o<r;++o){n=a[o]-q
p+=n*n}return Math.sqrt(p/r)/b},
bH(a){t.h.a(a)
return Math.min(1.5,Math.max(0.25,a.w*(0.5+a.r)*(a.e/30)))},
aF(a,b,c){return a+(b-a)*B.b.j(c,0,1)}}
A.dq.prototype={
$1(a){var s,r,q,p,o,n,m,l,k
t.bk.a(a)
s=this.b
r=A.h(s)
q=r.h("f<1,a>")
r=A.y(new A.f(s,r.h("a(1)").a(this.a.gbG()),q),q.h("q.E"))
r.$flags=1
p=r
r=t.i
o=B.a.F(p,0,new A.dr(),r)
n=s.length
m=A.o(new Array(n),t.n)
for(l=0;l<n;++l){if(!(l<s.length))return A.b(s,l)
q=a.$1(s[l])
if(!(l<p.length))return A.b(p,l)
k=p[l]
if(typeof q!=="number")return q.aq()
m[l]=q*k}return B.a.F(m,0,new A.ds(),r)/o},
$S:20}
A.dr.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.ds.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.dl.prototype={
$1(a){return a.x},
$S:5}
A.dm.prototype={
$1(a){return a.y},
$S:5}
A.dn.prototype={
$1(a){return a.z},
$S:5}
A.dp.prototype={
$1(a){return a.Q},
$S:5}
A.dk.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.c7.prototype={}
A.a5.prototype={}
A.dx.prototype={
bT(b7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6=null
t.Y.a(b7)
if(b7.length===0)return B.L
s=t.I
r=A.bw(A.i7(b6),b6,!1,s)
q=A.o([],t.W)
for(p=0,o=0,n=0,m=0,l=0,k=0,j=0,i=0,h=0,g=0;j<b7.length;++j,f=h,h=i,i=f){e=b7[j]
B.a.u(r,h,j)
d=r.length
h=(h+1&d-1)>>>0
if(i===h){c=A.bw(d*2,b6,!1,s)
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
a6=B.a.i(b7,a6==null?A.W(a6):a6).c
a7=a6.a
if(a7>=a1)a6=a7===a1&&a6.b<a2
else a6=!0}else a6=!1
if(!a6)break
if(h===i)A.aD(A.aX());++g
if(!(h>=0&&h<a3))return A.b(r,h)
a8=r[h]
if(a8==null)a8=A.W(a8)
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
l=0}if(a&&d>=4){b2=this.bw(b4.e,e.e)
b3=Math.abs(b2)/b5}}B.a.m(q,new A.S(j,e,b0,m,b2,b3))}return q},
bw(a,b){if(!isFinite(a)||!isFinite(b))return 0
return B.b.T(b-a+540,360)-180}}
A.ca.prototype={
bL(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this
t.t.a(b)
s=J.e8(b.slice(0),A.h(b).c)
r=B.U.bT(s)
if(r.length===0)return new A.c9(B.L,B.aJ,B.aK)
q=d.b8(r)
p=d.Z(r,new A.dA(),new A.dB(),B.ah,new A.dC(d,r))
o=d.Z(r,new A.dM(),new A.dN(),B.H,new A.dO(r))
n=d.Z(r,new A.dP(),new A.dQ(),B.H,new A.dR(r))
m=d.gbd()
l=d.Z(r,m,m,B.aj,new A.dS())
k=d.Z(r,new A.dT(),new A.dD(),B.ag,new A.dE(d,r))
j=A.bw(r.length,B.F,!1,t.fR)
d.a8(j,l,B.ab)
d.a8(j,o,B.aa)
d.a8(j,n,B.ac)
d.a8(j,p,B.G)
m=A.h(p)
i=t.F
m=A.y(new A.f(p,m.h("k(1)").a(new A.dF(d,a,r,q)),m.h("f<1,k>")),i)
h=A.h(o)
B.a.L(m,new A.f(o,h.h("k(1)").a(new A.dG(d,a,r,q)),h.h("f<1,k>")))
h=A.h(n)
B.a.L(m,new A.f(n,h.h("k(1)").a(new A.dH(d,a,r,q)),h.h("f<1,k>")))
h=A.h(k)
B.a.L(m,new A.f(k,h.h("k(1)").a(new A.dI(d,a,r,q)),h.h("f<1,k>")))
g=A.h(l)
B.a.L(m,new A.f(l,g.h("k(1)").a(new A.dJ(d,a,r,q)),g.h("f<1,k>")))
B.a.au(m,new A.dK())
g=A.a9(r,t.K)
f=t.gE
e=A.a9(d.b3(j,r),f)
A.a9(new A.f(k,h.h("@(1)").a(new A.dL(r)),h.h("f<1,@>")),f)
A.a9(q,t.fo)
return new A.c9(g,e,A.a9(d.br(m),i))},
be(a){return a.b.d>=5&&Math.abs(a.e)<=0.3&&a.d<=1.5},
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
this.aC(r,a,q,p,d,e)
q=c.$1(n)?o:null
p=q}if(q!=null&&p!=null)this.aC(r,a,q,p,d,e)
return r},
aC(a,b,c,d,e,f){var s,r,q
t.e.a(a)
t.X.a(b)
A.W(d)
t._.a(f)
s=new A.T(c,d)
r=b.length
if(!(d<r))return A.b(b,d)
q=b[d]
if(!(c<r))return A.b(b,c)
if(q.b.c.W(b[c].b.c).a>=e.a&&f.$1(s))B.a.m(a,s)},
b8(b4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3
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
if(A.D(o.b-m.b,o.a-m.a).a<8e6){B.a.m(s,B.aX)
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
if(b3>=0.62)B.a.m(s,new A.ar(B.b0,b2,b3))
else if(b2>=0.55)B.a.m(s,new A.ar(B.b_,b2,b3))
else{B.b.j(1-Math.max(b2,b3),0,1)
B.a.m(s,new A.ar(B.aZ,b2,b3))}}return s},
a_(a,b,a0,a1,a2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=this
t.X.a(a1)
t.dr.a(a2)
for(s=a0.a,r=a0.b,q=a1.length,p=s,o=0,n=1/0;p<=r;++p){if(!(p<q))return A.b(a1,p)
m=a1[p].b.d
o=Math.max(o,m)
n=Math.min(n,m)}l=s+B.c.A(r-s,2)
if(!(l>=0&&l<a2.length))return A.b(a2,l)
k=a2[l]
j=A.fK(t.V)
i=c.bB(k.a)
if(i!=null)j.m(0,i)
h=c.bj(b)
g=A.aJ(t.N,t.i)
if(b===B.h){g.u(0,"totalHeadingChangeDegrees",c.aD(a1,s,r))
g.u(0,"apexIndex",c.b6(a1,a0))
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
return A.fB(e,j,c.af(a1,s,r),a,r,f.d,f.c,a+":"+b.b+":"+s+":"+r,o,g,d,B.aL,A.i5([h],t.c5),h,s,q.d,q.c,k,b)},
br(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
t.B.a(a)
s=t.N
r=A.aJ(s,t.dg)
for(q=a.length,p=t.s,o=0;n=a.length,o<n;a.length===q||(0,A.a3)(a),++o)r.u(0,a[o].a,A.o([],p))
s=A.aJ(s,t.fj)
for(q=t.V,o=0;p=a.length,o<p;a.length===n||(0,A.a3)(a),++o){m=a[o]
p=A.fJ(q)
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
s=A.y(new A.f(a,q.h("k(1)").a(new A.dz(s,r)),p),p.h("q.E"))
s.$flags=1
return s},
bj(a){var s
switch(a.a){case 0:s=B.as
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
an(a){var s
switch(a.a){case 0:s=B.al
break
case 1:s=B.am
break
case 2:s=B.ao
break
case 3:s=B.r
break
case 4:s=B.an
break
default:s=null}return s},
bB(a){var s=null
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
for(s=b.length,r=0;r<b.length;b.length===s||(0,A.a3)(b),++r){q=b[r]
for(p=q.a,o=q.b;p<=o;++p)B.a.u(a,p,c)}},
b3(a,b){var s,r,q,p,o,n,m
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
B.a.m(s,new A.ai(o,q,n))
q=p}return s},
af(a,b,c){var s,r,q
t.X.a(a)
for(s=b+1,r=a.length,q=0;s<=c;++s){if(!(s<r))return A.b(a,s)
q+=a[s].b.w}return q},
aD(a,b,c){var s,r,q
t.X.a(a)
for(s=b+1,r=a.length,q=0;s<=c;++s){if(!(s<r))return A.b(a,s)
q+=Math.abs(a[s].f)}return q},
b6(a,b){var s,r,q,p,o,n
t.X.a(a)
s=b.a
for(r=b.b,q=a.length,p=s,o=0;p<=r;++p){if(!(p<q))return A.b(a,p)
n=a[p].r
if(n>o){o=n
s=p}}return s}}
A.dB.prototype={
$1(a){return a.b.d<=1.3888888888888888},
$S:1}
A.dA.prototype={
$1(a){return a.b.d<=1.3888888888888888},
$S:1}
A.dC.prototype={
$1(a){return this.a.af(this.b,a.a,a.b)<=8},
$S:6}
A.dN.prototype={
$1(a){return a.e>=0.35},
$S:1}
A.dM.prototype={
$1(a){return a.e>=0.15},
$S:1}
A.dO.prototype={
$1(a){var s,r=this.a,q=a.b,p=r.length
if(!(q<p))return A.b(r,q)
q=r[q]
s=a.a
if(!(s<p))return A.b(r,s)
return q.b.d-r[s].b.d>=2},
$S:6}
A.dQ.prototype={
$1(a){return a.e<=-0.35},
$S:1}
A.dP.prototype={
$1(a){return a.e<=-0.15},
$S:1}
A.dR.prototype={
$1(a){var s,r=this.a,q=a.a,p=r.length
if(!(q<p))return A.b(r,q)
q=r[q]
s=a.b
if(!(s<p))return A.b(r,s)
return q.b.d-r[s].b.d>=2},
$S:6}
A.dS.prototype={
$1(a){return!0},
$S:6}
A.dD.prototype={
$1(a){return a.b.d>=4&&a.r>=4},
$S:1}
A.dT.prototype={
$1(a){return a.b.d>=4&&a.r>=2},
$S:1}
A.dE.prototype={
$1(a){var s=this.a,r=this.b,q=a.a,p=a.b
return s.aD(r,q,p)>=15&&s.af(r,q,p)>=15},
$S:6}
A.dF.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.E,t.Q.a(a),s.c,s.d)},
$S:2}
A.dG.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.i,t.Q.a(a),s.c,s.d)},
$S:2}
A.dH.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.n,t.Q.a(a),s.c,s.d)},
$S:2}
A.dI.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.h,t.Q.a(a),s.c,s.d)},
$S:2}
A.dJ.prototype={
$1(a){var s=this
return s.a.a_(s.b,B.j,t.Q.a(a),s.c,s.d)},
$S:2}
A.dK.prototype={
$2(a,b){var s,r=t.F
r.a(a)
r.a(b)
s=B.c.E(a.d,b.d)
return s!==0?s:B.c.E(a.c.a,b.c.a)},
$S:23}
A.dL.prototype={
$1(a){var s,r,q,p
t.Q.a(a)
s=a.a
r=a.b
q=this.a
p=q.length
if(!(s<p))return A.b(q,s)
if(!(r<p))return A.b(q,r)
return new A.ai(B.ad,s,r)},
$S:48}
A.dz.prototype={
$1(a){var s,r,q
t.F.a(a)
s=a.a
r=this.a.i(0,s)
r.toString
r=A.i6(r,t.V)
q=this.b.i(0,s)
q.toString
q=A.a9(q,t.N)
r=t.eN.a(new A.bK(r,t.f4))
t.gJ.a(q)
return A.fB(a.as,r,a.Q,a.b,a.e,a.x,a.r,s,a.y,a.cx,a.z,q,a.ay,a.ax,a.d,a.w,a.f,a.at,a.c)},
$S:25}
A.T.prototype={}
A.dU.prototype={
D(){return"DriveScoreAlgorithmVersion."+this.b}}
A.bf.prototype={
ao(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
t.t.a(b)
s=J.e8(b.slice(0),A.h(b).c)
if(s.length<2)throw A.d(B.a_)
if(B.a.a0(s,new A.dV()))throw A.d(B.a0)
switch(a.a){case 0:r=B.V.bL("in-memory-drive-score",t.Y.a(s))
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
f=A.an(["brakingAnticipation",new A.B(q.a,350,!k,j),"tempoPerformance",new A.B(p.a,150,i,i),"corneringPerformance",new A.B(o.a,150,o.y,o.z),"drivingSmoothness",new A.B(n.a,100,n.b,n.c),"accelerationPerformance",new A.B(m.a,50,m.e,m.f),"transitionControl",new A.B(l.a,50,l.e,l.f)],h,g)
e=B.Z.aW(p.r,new A.am(f,A.i(f).h("am<2>")))
g=A.fH(h,g)
g.L(0,f)
g.u(0,"drivingEndurance",new A.B(e.a,150,e.f,e.r))
g=B.X.bK(g)
k=g
break
default:k=null}return k}}
A.dV.prototype={
$1(a){return!t.u.a(a).gbW()},
$S:26}
A.ci.prototype={
k(a){return u.c}}
A.e7.prototype={
k(a){return"Canonical telemetry contains an invalid coordinate."}}
A.dW.prototype={
bK(a){var s,r,q,p,o,n,m,l,k,j,i
t.cC.a(a)
s=t.N
r=t.D
q=A.aJ(s,r)
for(p=new A.br(a,A.i(a).h("br<1,2>")).gq(0),o=0;p.n();){n=p.d
m=n.b
l=m.c
if(l&&m.d)k=B.D
else k=!l?B.a8:B.a9
l=k===B.D
j=l?m.a:m.b*0.75
if(l)++o
q.u(0,n.a,new A.ah(j,k))}i=B.b.j(new A.am(q,q.$ti.h("am<2>")).F(0,0,new A.dX(),t.i),0,1000)
p=B.b.a3(i)
return new A.cb(i,B.b.j(o/a.a,0,1),p,1,A.fy(a,s,t.R),A.fy(q,s,r))}}
A.dX.prototype={
$2(a,b){return A.n(a)+t.D.a(b).b},
$S:27}
A.bg.prototype={
D(){return"DriveScoreContributionSource."+this.b}}
A.B.prototype={}
A.ah.prototype={}
A.cb.prototype={}
A.a7.prototype={
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
A.ar.prototype={}
A.ai.prototype={}
A.k.prototype={}
A.c9.prototype={
P(a){var s=this.f,r=A.h(s)
return new A.z(s,r.h("l(1)").a(new A.dy(a)),r.h("z<1>"))}}
A.dy.prototype={
$1(a){return t.F.a(a).c===this.a},
$S:4}
A.dY.prototype={
G(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=A.o([],t.g)
for(s=a.P(B.j),r=J.a4(s.a),s=new A.a1(r,s.b,s.$ti.h("a1<1>")),q=0;s.n();){p=r.gp()
o=p.at
n=Math.max(o.c,o.d)
if(p.ax===B.K){o=p.r
m=p.f
o=A.D(o.b-m.b,o.a-m.a).a<8e6||p.y<8.333333333333334||n>=0.65}else o=!0
if(o)++q
else B.a.m(d,p)}s=d.length
if(s===0)return new A.cc(0,!1,!1)
for(l=0,k=B.ae,j=0,i=0;i<d.length;d.length===s||(0,A.a3)(d),++i){h=d[i]
r=h.r
p=h.f
g=r.a-p.a
f=r.b-p.b
l+=A.D(f,g).a
if(A.D(f,g).a>k.a)k=A.D(f,g)
j+=B.b.j(1-this.bF(a,h)/4,0,1)*A.D(f,g).a}e=A.D(l,0)
s=B.b.j((0.55*this.b7(e,B.ak,B.af,B.ai)+0.45*(j/l))*100,0,1)
r=e.a
B.c.A(r,1e6)
return new A.cc(s*100,!0,r>=3e7)},
bF(a,b){var s=B.a.a4(a.b,b.d,b.e+1),r=A.h(s),q=r.h("f<1,a>"),p=A.y(new A.f(s,r.h("a(1)").a(new A.dZ()),q),q.h("q.E"))
return B.a.F(p,0,new A.e_(B.a.J(p,new A.e0())/p.length),t.i)/p.length},
b7(a,b,c,d){var s,r=a.a,q=b.a
if(r<=q)return 0
s=c.a
if(r<=s)return 0.75*(r-q)/(s-q)
return 0.75+0.25*B.b.j((r-s)/(d.a-s),0,1)}}
A.dZ.prototype={
$1(a){return t.K.a(a).b.d},
$S:3}
A.e0.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.e_.prototype={
$2(a,b){var s
A.n(a)
s=A.n(b)-this.a
return a+s*s},
$S:0}
A.e1.prototype={
aW(a,b){var s,r,q,p,o
t.ff.a(b)
s=b.$ti
r=s.h("z<c.E>")
q=A.y(new A.z(b,s.h("l(c.E)").a(new A.e2()),r),r.h("c.E"))
if(a<5||q.length===0)return new A.cd(0,!1,!1)
p=this.bl(a)
s=A.h(q)
o=B.b.j(new A.f(q,s.h("a(1)").a(new A.e3()),s.h("f<1,a>")).J(0,new A.e4())/q.length,0.15,1)
B.b.j(q.length/6,0,1)
s=a>=50&&q.length>=3
return new A.cd(p*o*150,!0,s)},
bl(a){if(a<=5)return a/5*0.15
if(a<=50)return 0.15+(a-5)/45*0.6
return B.b.j(0.75+(a-50)/100*0.25,0,1)}}
A.e2.prototype={
$1(a){t.R.a(a)
return a.c&&a.d},
$S:28}
A.e3.prototype={
$1(a){t.R.a(a)
return a.a/a.b},
$S:29}
A.e4.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.cd.prototype={}
A.cc.prototype={}
A.bY.prototype={}
A.a8.prototype={
D(){return"DrivingTransitionType."+this.b}}
A.Y.prototype={}
A.cy.prototype={}
A.b0.prototype={
D(){return"LocalRoadWindowState."+this.b}}
A.bx.prototype={
D(){return"LocalRoadRegionAnalysisStatus."+this.b}}
A.ay.prototype={}
A.aK.prototype={}
A.by.prototype={}
A.eh.prototype={
bM(a,b,c,d,e,f){var s,r,q,p=t.t
p.a(e)
p.a(c)
if(!f.at)return new A.by(B.aQ,B.M,B.N)
if(f.as<0.65)return new A.by(B.aR,B.M,B.N)
s=B.l.aN(d,e,f,b,c)
r=this.b2(a,b,s.b.b,d,s.a.b,f)
q=this.bJ(a,f,r)
return new A.by(B.aP,A.a9(r,t.l),A.a9(q,t.v))},
b2(a,b,c,d,a0,a1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=this,e=t.t
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
B.a.m(s,new A.ay(m,l,k,j,i,h,f.bz(g),g))}return s},
bJ(a,b,c){var s,r,q,p,o,n,m,l,k,j,i={}
t.fB.a(c)
s=A.o([],t.r)
i.a=null
i.b=0
r=new A.ei(i,s,b,a)
for(q=c.length,p=0;p<c.length;c.length===q||(0,A.a3)(c),++p){o=c[p]
if(o.r===B.O){n=i.a
m=o.b
l=o.d
k=o.f
if(n==null)i.a=new A.eP(o.a,m,o.c,l,o.e,k)
else{n.b=m
n.d=l
n.f=k;++n.w}i.b=0
continue}if(i.a==null)continue
j=i.b+(o.b-o.a)
i.b=j
if(j>200.000001)r.$0()}r.$0()
return s},
bz(a){var s,r
if(!a.y)return B.P
s=a.x
A:{if(B.x===s){r=B.aS
break A}if(B.y===s){r=B.O
break A}if(B.z===s){r=B.aT
break A}r=B.P
break A}return r},
a7(a,b,c,d){if(c<=0)return a
return a+(b-a)*d/c}}
A.ei.prototype={
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
A.eP.prototype={}
A.Z.prototype={}
A.a_.prototype={}
A.ep.prototype={
G(a6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2=this,a3=1e6,a4=a6.b,a5=a4.length
if(a5<2)return new A.bH(0,0,B.aW)
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
continue}if(a2.bf(a6,m))q+=l
else{r+=l
p+=k.w}}i=B.a.ga1(a4).b.c.W(B.a.gN(a4).b.c)
h=A.D(r,0)
g=A.D(q,0)
f=o/1000
s=h.a
e=s<=0?0:p/(s/1e6)*3.6
d=a2.bE(a6)
c=a5>=6&&s>=9e7&&o>=1000
B.b.j(Math.min(a5/6,Math.min(s/9e7,f)),0,1)
if(!c){B.b.aT(f,2)
B.c.A(s,a3)
return new A.bH(0,f,new A.bG(!1))}a5=i.a
b=a5<=0?0:o/(a5/1e6)*3.6
a=a2.al(e,B.aE,60)
a0=d.b<2?0:a2.al(d.a*3.6,B.aM,30)
a1=B.b.j(a+a0+a2.al(b,B.aA,60),0,150)
B.b.aT(f,2)
B.c.A(s,a3)
B.c.A(g.a,a3)
return new A.bH(a1,f,new A.bG(!0))},
bf(a,b){var s,r,q,p
if(this.bk(a.c,b)===B.G)return!0
s=a.b
r=s.length
if(!(b<r))return A.b(s,b)
q=s[b]
p=b+1
if(!(p<r))return A.b(s,p)
p=s[p]
return q.b.d<=1.3888888888888888&&p.b.d<=1.3888888888888888},
bk(a,b){var s,r,q
t.au.a(a)
for(s=a.length,r=0;r<s;++r){q=a[r]
if(b>=q.b&&b<=q.c)return q.a}return B.F},
bE(a){var s,r,q,p,o,n,m,l,k,j=a.b
for(s=j.length,r=0,q=0,p=0;p<s;++p){o=j[p].b.d
if(!isFinite(o)||o<0)continue
for(n=[p-1,p+1],m=1,l=0;l<2;++l){k=n[l]
if(k<0||k>=s)continue
if(!(k>=0&&k<s))return A.b(j,k)
if(Math.abs(j[k].b.d-o)<=10)++m}if(m<2)continue
if(o>r){q=m
r=o}}return new A.eO(r,q)},
al(a,b,c){var s,r,q,p,o,n
t.gj.a(b)
if(a<=B.a.gN(B.a.gN(b)))return 0
for(s=b.length,r=1;r<s;++r){q=b[r-1]
p=b[r]
if(a<=B.a.gN(p)){s=B.a.gN(q)
o=B.a.gN(p)
n=B.a.gN(q)
return B.b.j(c*(B.a.ga1(q)+(B.a.ga1(p)-B.a.ga1(q))*((a-s)/(o-n))),0,c)}}return c}}
A.eO.prototype={}
A.bH.prototype={}
A.bG.prototype={}
A.eq.prototype={
G(a){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=a.f,b=A.o([],t.c)
for(s=c.length,r=0;q=r+2,q<s;){if(!(r<s))return A.b(c,r)
p=c[r];++r
if(!(r<s))return A.b(c,r)
o=c[r]
n=c[q]
m=this.bD(p,o,n)
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
B.a.m(b,new A.Y(m,this.bo(a,n)))}if(b.length===0)return B.b1
i=new A.ev(b)
h=i.$2(B.o,20)
g=i.$2(B.p,20)
f=i.$2(B.q,10)
s=A.aJ(t.am,t.S)
for(q=t.eF,k=t.dA,e=0;e<3;++e){d=B.aO[e]
s.u(0,d,new A.z(b,q.a(new A.eu(d)),k).gl(0))}return new A.cy(h+g+f,!0,b.length>=2)},
bD(a,b,c){var s,r
if(c.c!==B.j)return null
s=a.c
r=s===B.j
if(r&&b.c===B.n)return B.o
if(r&&b.c===B.h)return B.p
if(s===B.i)return B.q
return null},
bo(a,b){var s=B.a.a4(a.b,b.d,b.e+1),r=A.h(s)
return B.b.j(1-Math.sqrt(B.a.F(s,0,new A.er(new A.f(s,r.h("a(1)").a(new A.es()),r.h("f<1,a>")).J(0,new A.et())/s.length),t.i)/s.length)/4,0,1)}}
A.ev.prototype={
$2(a,b){var s=this.a,r=A.h(s),q=r.h("z<1>"),p=A.y(new A.z(s,r.h("l(1)").a(new A.ew(a)),q),q.h("c.E"))
if(p.length===0)return 0
s=A.h(p)
return new A.f(p,s.h("a(1)").a(new A.ex()),s.h("f<1,a>")).J(0,new A.ey())/p.length*b},
$S:31}
A.ew.prototype={
$1(a){return t.f.a(a).a===this.a},
$S:8}
A.ex.prototype={
$1(a){return t.f.a(a).e},
$S:33}
A.ey.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.eu.prototype={
$1(a){return t.f.a(a).a===this.a},
$S:8}
A.es.prototype={
$1(a){return t.K.a(a).b.d},
$S:3}
A.et.prototype={
$2(a,b){return A.n(a)+A.n(b)},
$S:0}
A.er.prototype={
$2(a,b){var s
A.n(a)
s=t.K.a(b).b.d-this.a
return a+s*s},
$S:47}
A.eC.prototype={}
A.eZ.prototype={
$1(a){var s=J.bW(a),r=A.F(s.i(a,"id"))
s=J.cI(t.j.a(s.i(a,"geometry")),new A.eY(),t.x)
s=A.y(s,s.$ti.h("q.E"))
return new A.a_(r,s,A.v(t.P.a(a).i(0,"distanceMeters")))},
$S:35}
A.eY.prototype={
$1(a){t.P.a(a)
return new A.Z(A.v(a.i(0,"latitude")),A.v(a.i(0,"longitude")))},
$S:9}
A.f_.prototype={
$1(a){return t.p.a(a).b},
$S:37}
A.f0.prototype={
$2(a,b){return A.n(a)+t.p.a(b).c},
$S:38}
A.f5.prototype={
$1(a){var s,r,q,p,o
t.P.a(a)
s=A.v(a.i(0,"latitude"))
r=A.v(a.i(0,"longitude"))
q=A.hZ(A.F(a.i(0,"timestamp")))
p=A.v(a.i(0,"speed_mps"))
o=A.v(a.i(0,"heading_degrees"))
A.v(a.i(0,"altitude_meters"))
A.v(a.i(0,"accuracy_meters"))
return new A.G(s,r,q,p,o,A.v(a.i(0,"distance_from_previous_meters")),A.v(a.i(0,"acceleration_mps2")))},
$S:39}
A.f1.prototype={
$2(a,b){A.F(a)
t.R.a(b)
return new A.E(a,A.an(["score",b.a,"maximum",b.b,"applicable",b.c,"sampleSufficient",b.d],t.N,t.C),t.w)},
$S:40}
A.f2.prototype={
$2(a,b){A.F(a)
t.D.a(b)
return new A.E(a,A.an(["contribution",b.b,"source",b.c.b],t.N,t.C),t.w)},
$S:41}
A.f4.prototype={
$1(a){return t.u.a(a).c.c4().c3()},
$S:42}
A.eV.prototype={
$1(a){t.P.a(a)
return new A.Z(A.v(a.i(0,"latitude")),A.v(a.i(0,"longitude")))},
$S:9}
A.eS.prototype={
$1(a){t.l.a(a)
return A.an(["commonStartOffsetMeters",a.a,"commonEndOffsetMeters",a.b,"existingStartOffsetMeters",a.c,"existingEndOffsetMeters",a.d,"challengerStartOffsetMeters",a.e,"challengerEndOffsetMeters",a.f,"state",a.r.b,"comparison",A.hm(a.w)],t.N,t.C)},
$S:43}
A.eT.prototype={
$1(a){t.v.a(a)
return A.an(["existingDriveId",a.a,"challengerDriveId",a.b,"startOffsetOnExistingMeters",a.d,"endOffsetOnExistingMeters",a.e,"startOffsetOnChallengerMeters",a.f,"endOffsetOnChallengerMeters",a.r,"commonStartOffsetMeters",a.w,"commonEndOffsetMeters",a.x,"winningDistanceMeters",a.y,"algorithmVersion",1,"confidence",a.Q,"supportingWindowCount",a.as],t.N,t.C)},
$S:44}
A.cv.prototype={
ao(a,b){var s
t.t.a(b)
s=J.hK(this.y,this.z++)
if(s==null){++this.z
throw A.d(A.ie("synthetic invalid window"))}A.v(s)
return new A.cb(s,1,B.b.a3(s),1,B.aU,B.aV)}}
A.eX.prototype={
$1(a){var s=t.P,r=s.a(B.w.bP(A.F(a),null)),q=t.j
return B.w.bR(A.ji(A.jo(s.a(r.i(0,"match"))),A.hr(s.a(r.i(0,"firstRoad"))),A.hr(s.a(r.i(0,"secondRoad"))),A.ht(q.a(r.i(0,"firstTelemetry"))),A.ht(q.a(r.i(0,"secondTelemetry"))),new A.c3(new A.cv(q.a(r.i(0,"scores"))))),null)},
$S:45};(function aliases(){var s=J.ax.prototype
s.aY=s.k})();(function installTearOffs(){var s=hunkHelpers._static_2,r=hunkHelpers._static_1,q=hunkHelpers._instance_1u,p=hunkHelpers.installStaticTearOff
s(J,"iX","i1",46)
r(A,"jm","iN",34)
q(A.c8.prototype,"gbG","bH",5)
q(A.ca.prototype,"gbd","be",1)
p(A,"jy",2,null,["$1$2","$2"],["hp",function(a,b){return A.hp(a,b,t.H)}],32,0)})();(function inheritance(){var s=hunkHelpers.mixin,r=hunkHelpers.inherit,q=hunkHelpers.inheritMany
r(A.j,null)
q(A.j,[A.f8,J.cj,A.bC,J.aF,A.c,A.bb,A.t,A.en,A.bv,A.bz,A.a1,A.bl,A.bD,A.bj,A.b1,A.bd,A.K,A.ez,A.el,A.I,A.ee,A.bt,A.bu,A.bs,A.cn,A.eJ,A.a0,A.cB,A.eK,A.aN,A.cE,A.aO,A.bT,A.bN,A.cF,A.c2,A.c6,A.eH,A.a6,A.L,A.eD,A.cq,A.bE,A.eE,A.e5,A.E,A.aL,A.b3,A.cJ,A.cY,A.aB,A.ab,A.dd,A.cX,A.G,A.c3,A.de,A.c4,A.af,A.di,A.df,A.bO,A.a2,A.eF,A.c8,A.c7,A.a5,A.dx,A.ca,A.T,A.bf,A.ci,A.e7,A.dW,A.B,A.ah,A.cb,A.S,A.ar,A.ai,A.k,A.c9,A.dY,A.e1,A.cd,A.cc,A.bY,A.Y,A.cy,A.ay,A.aK,A.by,A.eh,A.eP,A.Z,A.a_,A.ep,A.eO,A.bH,A.bG,A.eq,A.eC])
q(J.cj,[J.cl,J.bn,J.b_,J.aY,J.aI])
q(J.b_,[J.ax,J.m])
q(J.ax,[J.em,J.az,J.bo])
r(J.ck,A.bC)
r(J.e9,J.m)
q(J.aY,[J.bm,J.cm])
q(A.c,[A.b5,A.p,A.ao,A.z,A.bk,A.aq])
r(A.aG,A.b5)
r(A.bM,A.aG)
q(A.t,[A.bq,A.bI,A.co,A.cz,A.cu,A.cA,A.bp,A.bZ,A.ad,A.bL,A.b2,A.c5])
q(A.p,[A.q,A.bi,A.al,A.am,A.br])
q(A.q,[A.bF,A.f,A.eg,A.cD])
r(A.bh,A.ao)
r(A.aV,A.aq)
r(A.b7,A.b1)
r(A.bJ,A.b7)
r(A.be,A.bJ)
q(A.K,[A.c1,A.ch,A.c0,A.cx,A.dv,A.dw,A.cR,A.cT,A.cU,A.cV,A.cK,A.cN,A.cO,A.db,A.dc,A.cZ,A.d_,A.d2,A.d3,A.d5,A.d6,A.d7,A.d1,A.d0,A.d4,A.dg,A.dq,A.dl,A.dm,A.dn,A.dp,A.dB,A.dA,A.dC,A.dN,A.dM,A.dO,A.dQ,A.dP,A.dR,A.dS,A.dD,A.dT,A.dE,A.dF,A.dG,A.dH,A.dI,A.dJ,A.dL,A.dz,A.dV,A.dy,A.dZ,A.e2,A.e3,A.ew,A.ex,A.eu,A.es,A.eZ,A.eY,A.f_,A.f5,A.f4,A.eV,A.eS,A.eT,A.eX])
q(A.c1,[A.dj,A.ea,A.ef,A.ek,A.eI,A.cS,A.cM,A.cL,A.cQ,A.cP,A.d9,A.da,A.dh,A.dr,A.ds,A.dk,A.dK,A.dX,A.e0,A.e_,A.e4,A.ev,A.ey,A.et,A.er,A.f0,A.f1,A.f2])
r(A.Q,A.bd)
r(A.aW,A.ch)
r(A.bA,A.bI)
q(A.cx,[A.cw,A.aU])
q(A.I,[A.ak,A.cC])
r(A.b6,A.cA)
q(A.aN,[A.bP,A.bU])
r(A.au,A.bP)
r(A.bK,A.bU)
r(A.cp,A.bp)
r(A.eb,A.c2)
q(A.c6,[A.ed,A.ec])
r(A.eG,A.eH)
q(A.c0,[A.dt,A.d8,A.ei])
q(A.ad,[A.bB,A.cg])
q(A.eD,[A.ae,A.bc,A.dU,A.bg,A.a7,A.b4,A.aH,A.aw,A.O,A.a8,A.b0,A.bx])
r(A.cv,A.bf)
s(A.b7,A.bT)
s(A.bU,A.cF)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{X:"int",a:"double",J:"num",e:"String",l:"bool",aL:"Null",u:"List",j:"Object",r:"Map",aZ:"JSObject"},mangledNames:{},types:["a(a,a)","l(S)","k(T)","a(S)","l(k)","a(a5)","l(T)","a(k)","l(Y)","Z(@)","a(ab)","a(a,aB)","X(e?)","~(j?,j?)","a(a(k))","l(ab)","~(@,@)","G(a2)","a(a,a2)","0&()","a(a(a5))","l(k?)","aL()","X(k,k)","a(a)","k(k)","l(G)","a(a,ah)","l(B)","a(B)","~()","a(a8,a)","0^(0^,0^)<J>","a(Y)","@(@)","a_(@)","l(e)","u<Z>(a_)","a(a,a_)","G(@)","E<e,r<e,j>>(e,B)","E<e,r<e,j>>(e,ah)","e(G)","r<e,j>(ay)","r<e,j>(aK)","e(e)","X(@,@)","a(a,S)","ai(T)"],arrayRti:Symbol("$ti")}
A.iA(v.typeUniverse,JSON.parse('{"bo":"ax","em":"ax","az":"ax","cl":{"l":[],"as":[]},"bn":{"as":[]},"b_":{"aZ":[]},"ax":{"aZ":[]},"m":{"u":["1"],"p":["1"],"aZ":[],"c":["1"]},"ck":{"bC":[]},"e9":{"m":["1"],"u":["1"],"p":["1"],"aZ":[],"c":["1"]},"aF":{"w":["1"]},"aY":{"a":[],"J":[],"P":["J"]},"bm":{"a":[],"X":[],"J":[],"P":["J"],"as":[]},"cm":{"a":[],"J":[],"P":["J"],"as":[]},"aI":{"e":[],"P":["e"],"as":[]},"b5":{"c":["2"]},"bb":{"w":["2"]},"aG":{"b5":["1","2"],"c":["2"],"c.E":"2"},"bM":{"aG":["1","2"],"b5":["1","2"],"p":["2"],"c":["2"],"c.E":"2"},"bq":{"t":[]},"p":{"c":["1"]},"q":{"p":["1"],"c":["1"]},"bF":{"q":["1"],"p":["1"],"c":["1"],"q.E":"1","c.E":"1"},"bv":{"w":["1"]},"ao":{"c":["2"],"c.E":"2"},"bh":{"ao":["1","2"],"p":["2"],"c":["2"],"c.E":"2"},"bz":{"w":["2"]},"f":{"q":["2"],"p":["2"],"c":["2"],"q.E":"2","c.E":"2"},"z":{"c":["1"],"c.E":"1"},"a1":{"w":["1"]},"bk":{"c":["2"],"c.E":"2"},"bl":{"w":["2"]},"aq":{"c":["1"],"c.E":"1"},"aV":{"aq":["1"],"p":["1"],"c":["1"],"c.E":"1"},"bD":{"w":["1"]},"bi":{"p":["1"],"c":["1"],"c.E":"1"},"bj":{"w":["1"]},"be":{"bJ":["1","2"],"b7":["1","2"],"b1":["1","2"],"bT":["1","2"],"r":["1","2"]},"bd":{"r":["1","2"]},"Q":{"bd":["1","2"],"r":["1","2"]},"ch":{"K":[],"aj":[]},"aW":{"K":[],"aj":[]},"bA":{"t":[]},"co":{"t":[]},"cz":{"t":[]},"K":{"aj":[]},"c0":{"K":[],"aj":[]},"c1":{"K":[],"aj":[]},"cx":{"K":[],"aj":[]},"cw":{"K":[],"aj":[]},"aU":{"K":[],"aj":[]},"cu":{"t":[]},"ak":{"I":["1","2"],"fG":["1","2"],"r":["1","2"],"I.K":"1","I.V":"2"},"al":{"p":["1"],"c":["1"],"c.E":"1"},"bt":{"w":["1"]},"am":{"p":["1"],"c":["1"],"c.E":"1"},"bu":{"w":["1"]},"br":{"p":["E<1,2>"],"c":["E<1,2>"],"c.E":"E<1,2>"},"bs":{"w":["E<1,2>"]},"cn":{"ib":[]},"cA":{"t":[]},"b6":{"t":[]},"au":{"bP":["1"],"aN":["1"],"fI":["1"],"aM":["1"],"p":["1"],"c":["1"]},"aO":{"w":["1"]},"I":{"r":["1","2"]},"b1":{"r":["1","2"]},"bJ":{"b7":["1","2"],"b1":["1","2"],"bT":["1","2"],"r":["1","2"]},"eg":{"q":["1"],"p":["1"],"c":["1"],"q.E":"1","c.E":"1"},"bN":{"w":["1"]},"aN":{"aM":["1"],"p":["1"],"c":["1"]},"bP":{"aN":["1"],"aM":["1"],"p":["1"],"c":["1"]},"bK":{"aN":["1"],"cF":["1"],"aM":["1"],"p":["1"],"c":["1"]},"cC":{"I":["e","@"],"r":["e","@"],"I.K":"e","I.V":"@"},"cD":{"q":["e"],"p":["e"],"c":["e"],"q.E":"e","c.E":"e"},"bp":{"t":[]},"cp":{"t":[]},"a6":{"P":["a6"]},"a":{"J":[],"P":["J"]},"L":{"P":["L"]},"X":{"J":[],"P":["J"]},"u":{"p":["1"],"c":["1"]},"J":{"P":["J"]},"aM":{"p":["1"],"c":["1"]},"e":{"P":["e"]},"bZ":{"t":[]},"bI":{"t":[]},"ad":{"t":[]},"bB":{"t":[]},"cg":{"t":[]},"bL":{"t":[]},"b2":{"t":[]},"c5":{"t":[]},"cq":{"t":[]},"bE":{"t":[]},"b3":{"ig":[]},"cv":{"bf":[]}}'))
A.iz(v.typeUniverse,JSON.parse('{"bU":1,"c2":2,"c6":2}'))
var u={c:"At least two canonical telemetry points are required."}
var t=(function rtii(){var s=A.ac
return{u:s("G"),fI:s("G(a2)"),e8:s("P<@>"),h:s("a5"),dy:s("a6"),D:s("ah"),R:s("B"),F:s("k"),fR:s("a7"),gE:s("ai"),f:s("Y"),am:s("a8"),fu:s("L"),O:s("p<@>"),bU:s("t"),V:s("O"),c5:s("aw"),Z:s("aj"),t:s("c<G>"),ff:s("c<B>"),bM:s("c<a>"),hf:s("c<@>"),df:s("m<a5>"),g:s("m<k>"),q:s("m<ai>"),c:s("m<Y>"),b:s("m<u<a>>"),d:s("m<ay>"),r:s("m<aK>"),s:s("m<e>"),W:s("m<S>"),gI:s("m<ar>"),h9:s("m<ab>"),du:s("m<a2>"),cA:s("m<bO>"),dO:s("m<T>"),aS:s("m<aB>"),n:s("m<a>"),gn:s("m<@>"),T:s("bn"),m:s("aZ"),L:s("bo"),Y:s("u<G>"),B:s("u<k>"),G:s("u<a7>"),au:s("u<ai>"),gj:s("u<u<a>>"),fB:s("u<ay>"),dg:s("u<e>"),X:s("u<S>"),dr:s("u<ar>"),cT:s("u<ab>"),fT:s("u<bO>"),e:s("u<T>"),ap:s("u<aB>"),o:s("u<a>"),j:s("u<@>"),l:s("ay"),v:s("aK"),w:s("E<e,r<e,j>>"),cC:s("r<e,B>"),h6:s("r<e,j>"),P:s("r<e,@>"),eO:s("r<@,@>"),gM:s("f<a2,G>"),x:s("Z"),p:s("a_"),a:s("aL"),C:s("j"),gT:s("jG"),fj:s("aM<O>"),cq:s("aM<e>"),N:s("e"),K:s("S"),fo:s("ar"),dm:s("as"),ak:s("az"),f4:s("bK<O>"),dA:s("z<Y>"),k:s("ab"),A:s("a2"),Q:s("T"),E:s("aB"),y:s("l"),eF:s("l(Y)"),d1:s("l(S)"),_:s("l(T)"),i:s("a"),bk:s("a(a5)"),bE:s("a(k)"),z:s("@"),S:s("X"),J:s("k?"),eH:s("fC<aL>?"),an:s("aZ?"),gJ:s("u<e>?"),bF:s("u<@>?"),U:s("j?"),eN:s("aM<O>?"),dk:s("e?"),M:s("cE?"),fQ:s("l?"),cD:s("a?"),I:s("X?"),cg:s("J?"),H:s("J"),fH:s("~(e,@)")}})();(function constants(){var s=hunkHelpers.makeConstList
B.at=J.cj.prototype
B.a=J.m.prototype
B.c=J.bm.prototype
B.b=J.aY.prototype
B.e=J.aI.prototype
B.au=J.b_.prototype
B.Q=new A.aW(A.jy(),A.ac("aW<a>"))
B.R=new A.cJ()
B.S=new A.cY()
B.l=new A.df()
B.T=new A.c8()
B.U=new A.dx()
B.V=new A.ca()
B.X=new A.dW()
B.Y=new A.dY()
B.v=new A.bj(A.ac("bj<0&>"))
B.Z=new A.e1()
B.a_=new A.ci()
B.a0=new A.e7()
B.a1=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.w=new A.eb()
B.a2=new A.cq()
B.b3=new A.en()
B.a3=new A.ep()
B.a4=new A.eq()
B.W=new A.bf()
B.b4=new A.c3(B.W)
B.x=new A.ae(0,"firstWins")
B.y=new A.ae(1,"secondWins")
B.z=new A.ae(2,"noMeaningfulDifference")
B.a5=new A.ae(3,"notEligible")
B.A=new A.ae(4,"insufficientTelemetry")
B.a6=new A.ae(5,"mappingFailed")
B.a7=new A.ae(7,"calculationFailed")
B.m=new A.bc(0,"success")
B.d=new A.bc(1,"mappingFailed")
B.B=new A.bc(2,"insufficientTelemetry")
B.C=new A.dU(0,"v1")
B.D=new A.bg(0,"actual")
B.a8=new A.bg(1,"neutralNotApplicable")
B.a9=new A.bg(2,"neutralInsufficient")
B.E=new A.aH(0,"stop")
B.i=new A.aH(1,"acceleration")
B.n=new A.aH(2,"deceleration")
B.h=new A.aH(3,"corner")
B.j=new A.aH(4,"cruise")
B.F=new A.a7(0,"unknown")
B.G=new A.a7(1,"stopped")
B.aa=new A.a7(2,"accelerating")
B.ab=new A.a7(3,"cruising")
B.ac=new A.a7(4,"decelerating")
B.ad=new A.a7(5,"cornering")
B.o=new A.a8(0,"cruiseDecelCruise")
B.p=new A.a8(1,"cruiseCornerCruise")
B.q=new A.a8(2,"accelerationCruise")
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
B.r=new A.O(4,"cornering")
B.ap=new A.O(5,"freeFlow")
B.aq=new A.O(6,"denseTraffic")
B.ar=new A.O(7,"stopAndGo")
B.as=new A.aw(0,"stopping")
B.t=new A.aw(1,"acceleration")
B.I=new A.aw(2,"braking")
B.J=new A.aw(3,"cornering")
B.K=new A.aw(4,"cruising")
B.av=new A.ec(null)
B.aw=new A.ed(null)
B.u=s([0,0],t.n)
B.aC=s([20,0.25],t.n)
B.aI=s([50,0.58],t.n)
B.aH=s([80,0.83],t.n)
B.ax=s([120,1],t.n)
B.aA=s([B.u,B.aC,B.aI,B.aH,B.ax],t.b)
B.aB=s([30,0.25],t.n)
B.aD=s([60,0.58],t.n)
B.aN=s([100,0.83],t.n)
B.ay=s([150,1],t.n)
B.aE=s([B.u,B.aB,B.aD,B.aN,B.ay],t.b)
B.f=s([],A.ac("m<G>"))
B.aK=s([],t.g)
B.aJ=s([],t.q)
B.M=s([],t.d)
B.N=s([],t.r)
B.aL=s([],t.s)
B.L=s([],t.W)
B.aG=s([80,0.33],t.n)
B.aF=s([140,0.67],t.n)
B.az=s([200,1],t.n)
B.aM=s([B.u,B.aG,B.aF,B.az],t.b)
B.aO=s([B.o,B.p,B.q],A.ac("m<a8>"))
B.aP=new A.bx(0,"success")
B.aQ=new A.bx(1,"notEligible")
B.aR=new A.bx(2,"insufficientConfidence")
B.aS=new A.b0(0,"existingBetter")
B.O=new A.b0(1,"challengerBetter")
B.aT=new A.b0(2,"noMeaningfulDifference")
B.P=new A.b0(3,"invalid")
B.k={}
B.aV=new A.Q(B.k,[],A.ac("Q<e,ah>"))
B.aU=new A.Q(B.k,[],A.ac("Q<e,B>"))
B.b6=new A.Q(B.k,[],A.ac("Q<e,a>"))
B.aW=new A.bG(!1)
B.aY=new A.b4(0,"unknown")
B.aX=new A.ar(B.aY,0,0)
B.aZ=new A.b4(1,"freeFlow")
B.b_=new A.b4(2,"denseTraffic")
B.b0=new A.b4(3,"stopAndGo")
B.b7=new A.Q(B.k,[],A.ac("Q<a8,X>"))
B.b5=s([],t.c)
B.b1=new A.cy(0,!1,!1)
B.b2=A.jC("j")})();(function staticFields(){$.U=A.o([],A.ac("m<j>"))
$.fM=null
$.fu=null
$.ft=null})();(function lazyInitializers(){var s=hunkHelpers.lazyFinal
s($,"jE","hw",()=>A.hn("_$dart_dartClosure"))
s($,"jD","fn",()=>A.hn("_$dart_dartClosure_dartJSInterop"))
s($,"jS","hJ",()=>A.o([new J.ck()],A.ac("m<bC>")))
s($,"jH","hy",()=>A.at(A.eA({
toString:function(){return"$receiver$"}})))
s($,"jI","hz",()=>A.at(A.eA({$method$:null,
toString:function(){return"$receiver$"}})))
s($,"jJ","hA",()=>A.at(A.eA(null)))
s($,"jK","hB",()=>A.at(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"jN","hE",()=>A.at(A.eA(void 0)))
s($,"jO","hF",()=>A.at(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"jM","hD",()=>A.at(A.fZ(null)))
s($,"jL","hC",()=>A.at(function(){try{null.$method$}catch(r){return r.message}}()))
s($,"jQ","hH",()=>A.at(A.fZ(void 0)))
s($,"jP","hG",()=>A.at(function(){try{(void 0).$method$}catch(r){return r.message}}()))
s($,"jF","hx",()=>A.ic("^([+-]?\\d{4,6})-?(\\d\\d)-?(\\d\\d)(?:[ T](\\d\\d)(?::?(\\d\\d)(?::?(\\d\\d)(?:[.,](\\d+))?)?)?( ?[zZ]| ?([-+])(\\d\\d)(?::?(\\d\\d))?)?)?$"))
s($,"jR","hI",()=>A.hq(B.b2))})();(function nativeSupport(){!function(){var s=function(a){var m={}
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
var s=A.jx
if(typeof dartMainRunner==="function"){dartMainRunner(s,[])}else{s([])}})})()
(function dartProgram(){function copyProperties(a,b){var t=Object.keys(a)
for(var s=0;s<t.length;s++){var r=t[s]
b[r]=a[r]}}function mixinPropertiesHard(a,b){var t=Object.keys(a)
for(var s=0;s<t.length;s++){var r=t[s]
if(!b.hasOwnProperty(r)){b[r]=a[r]}}}function mixinPropertiesEasy(a,b){Object.assign(b,a)}var z=function(){var t=function(){}
t.prototype={p:{}}
var s=new t()
if(!(Object.getPrototypeOf(s)&&Object.getPrototypeOf(s).p===t.prototype.p))return false
try{if(typeof navigator!="undefined"&&typeof navigator.userAgent=="string"&&navigator.userAgent.indexOf("Chrome/")>=0)return true
if(typeof version=="function"&&version.length==0){var r=version()
if(/^\d+\.\d+\.\d+\.\d+$/.test(r))return true}}catch(q){}return false}()
function inherit(a,b){a.prototype.constructor=a
a.prototype["$i"+a.name]=a
if(b!=null){if(z){Object.setPrototypeOf(a.prototype,b.prototype)
return}var t=Object.create(b.prototype)
copyProperties(a.prototype,t)
a.prototype=t}}function inheritMany(a,b){for(var t=0;t<b.length;t++){inherit(b[t],a)}}function mixinEasy(a,b){mixinPropertiesEasy(b.prototype,a.prototype)
a.prototype.constructor=a}function mixinHard(a,b){mixinPropertiesHard(b.prototype,a.prototype)
a.prototype.constructor=a}function lazy(a,b,c,d){var t=a
a[b]=t
a[c]=function(){if(a[b]===t){a[b]=d()}a[c]=function(){return this[b]}
return a[b]}}function lazyFinal(a,b,c,d){var t=a
a[b]=t
a[c]=function(){if(a[b]===t){var s=d()
if(a[b]!==t){A.jp(b)}a[b]=s}var r=a[b]
a[c]=function(){return r}
return r}}function makeConstList(a,b){if(b!=null)A.n(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var t=0;t<a.length;++t){convertToFastObject(a[t])}}var y=0
function instanceTearOffGetter(a,b){var t=null
return a?function(c){if(t===null)t=A.fo(b)
return new t(c,this)}:function(){if(t===null)t=A.fo(b)
return new t(this,null)}}function staticTearOffGetter(a){var t=null
return function(){if(t===null)t=A.fo(a).prototype
return t}}var x=0
function tearOffParameters(a,b,c,d,e,f,g,h,i,j){if(typeof h=="number"){h+=x}return{co:a,iS:b,iI:c,rC:d,dV:e,cs:f,fs:g,fT:h,aI:i||0,nDA:j}}function installStaticTearOff(a,b,c,d,e,f,g,h){var t=tearOffParameters(a,true,false,c,d,e,f,g,h,false)
var s=staticTearOffGetter(t)
a[b]=s}function installInstanceTearOff(a,b,c,d,e,f,g,h,i,j){c=!!c
var t=tearOffParameters(a,false,c,d,e,f,g,h,i,!!j)
var s=instanceTearOffGetter(c,t)
a[b]=s}function setOrUpdateInterceptorsByTag(a){var t=v.interceptorsByTag
if(!t){v.interceptorsByTag=a
return}copyProperties(a,t)}function setOrUpdateLeafTags(a){var t=v.leafTags
if(!t){v.leafTags=a
return}copyProperties(a,t)}function updateTypes(a){var t=v.types
var s=t.length
t.push.apply(t,a)
return s}function updateHolder(a,b){copyProperties(b,a)
return a}var hunkHelpers=function(){var t=function(a,b,c,d,e){return function(f,g,h,i){return installInstanceTearOff(f,g,a,b,c,d,[h],i,e,false)}},s=function(a,b,c,d){return function(e,f,g,h){return installStaticTearOff(e,f,a,b,c,[g],h,d)}}
return{inherit:inherit,inheritMany:inheritMany,mixin:mixinEasy,mixinHard:mixinHard,installStaticTearOff:installStaticTearOff,installInstanceTearOff:installInstanceTearOff,_instance_0u:t(0,0,null,["$0"],0),_instance_1u:t(0,1,null,["$1"],0),_instance_2u:t(0,2,null,["$2"],0),_instance_0i:t(1,0,null,["$0"],0),_instance_1i:t(1,1,null,["$1"],0),_instance_2i:t(1,2,null,["$2"],0),_static_0:s(0,null,["$0"],0),_static_1:s(1,null,["$1"],0),_static_2:s(2,null,["$2"],0),makeConstList:makeConstList,lazy:lazy,lazyFinal:lazyFinal,updateHolder:updateHolder,convertToFastObject:convertToFastObject,updateTypes:updateTypes,setOrUpdateInterceptorsByTag:setOrUpdateInterceptorsByTag,setOrUpdateLeafTags:setOrUpdateLeafTags}}()
function initializeDeferredHunk(a){x=v.types.length
a(hunkHelpers,v,w,$)}var J={
fH(a,b){if(a<0||a>4294967295)throw A.d(A.ab(a,0,4294967295,"length",null))
return J.eb(new Array(a),b)},
fG(a,b){if(a<0)throw A.d(A.f6("Length must be a non-negative integer: "+a))
return A.n(new Array(a),b.h("l<0>"))},
eb(a,b){var t=A.n(a,b.h("l<0>"))
t.$flags=1
return t},
hY(a,b){var t=u.w
return J.hH(t.a(a),t.a(b))},
aS(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.bm.prototype
return J.cl.prototype}if(typeof a=="string")return J.aI.prototype
if(a==null)return J.bn.prototype
if(typeof a=="boolean")return J.ck.prototype
if(Array.isArray(a))return J.l.prototype
if(typeof a=="function")return J.bo.prototype
if(typeof a=="object"){if(a instanceof A.m){return a}else{return J.b0.prototype}}if(!(a instanceof A.m))return J.ay.prototype
return a},
b9(a){if(a==null)return a
if(Array.isArray(a))return J.l.prototype
if(!(a instanceof A.m))return J.ay.prototype
return a},
cF(a){if(typeof a=="string")return J.aI.prototype
if(a==null)return a
if(Array.isArray(a))return J.l.prototype
if(!(a instanceof A.m))return J.ay.prototype
return a},
jg(a){if(typeof a=="number")return J.aZ.prototype
if(typeof a=="string")return J.aI.prototype
if(a==null)return a
if(!(a instanceof A.m))return J.ay.prototype
return a},
Z(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.aS(a).M(a,b)},
bb(a,b){if(typeof b==="number")if(Array.isArray(a)||typeof a=="string")if(b>>>0===b&&b<a.length)return a[b]
return J.cF(a).i(a,b)},
cI(a,b,c){return J.b9(a).m(a,b,c)},
hH(a,b){return J.jg(a).H(a,b)},
ft(a,b){return J.b9(a).F(a,b)},
W(a){return J.aS(a).gB(a)},
fu(a){return J.cF(a).gv(a)},
hI(a){return J.b9(a).gC(a)},
ad(a){return J.b9(a).gt(a)},
aD(a){return J.cF(a).gl(a)},
hJ(a){return J.aS(a).gX(a)},
f5(a,b,c){return J.b9(a).aU(a,b,c)},
fv(a,b){return J.b9(a).N(a,b)},
bc(a){return J.aS(a).j(a)},
ci:function ci(){},
ck:function ck(){},
bn:function bn(){},
b0:function b0(){},
aw:function aw(){},
el:function el(){},
ay:function ay(){},
bo:function bo(){},
l:function l(a){this.$ti=a},
cj:function cj(){},
ec:function ec(a){this.$ti=a},
aE:function aE(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aZ:function aZ(){},
bm:function bm(){},
cl:function cl(){},
aI:function aI(){}},A={f9:function f9(){},
dh(a,b,c){if(u.O.b(a))return new A.bL(a,b.h("@<0>").u(c).h("bL<1,2>"))
return new A.aF(a,b.h("@<0>").u(c).h("aF<1,2>"))},
ax(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
fg(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
hn(a,b,c){return a},
fq(a){var t,s
for(t=$.V.length,s=0;s<t;++s)if(a===$.V[s])return!0
return!1},
eu(a,b,c,d){A.al(b,"start")
if(c!=null){A.al(c,"end")
if(b>c)A.aC(A.ab(b,0,c,"start",null))}return new A.bF(a,b,c,d.h("bF<0>"))},
fP(a,b,c,d){if(u.O.b(a))return new A.bi(a,b,c.h("@<0>").u(d).h("bi<1,2>"))
return new A.ak(a,b,c.h("@<0>").u(d).h("ak<1,2>"))},
h_(a,b,c){var t="count"
if(u.O.b(a)){A.cW(b,t,u.S)
A.al(b,t)
return new A.aW(a,b,c.h("aW<0>"))}A.cW(b,t,u.S)
A.al(b,t)
return new A.am(a,b,c.h("am<0>"))},
aY(){return new A.bE("No element")},
hW(){return new A.bE("Too few elements")},
b4:function b4(){},
bd:function bd(a,b){this.a=a
this.$ti=b},
aF:function aF(a,b){this.a=a
this.$ti=b},
bL:function bL(a,b){this.a=a
this.$ti=b},
aG:function aG(a,b){this.a=a
this.$ti=b},
di:function di(a,b){this.a=a
this.b=b},
cp:function cp(a){this.a=a},
et:function et(){},
o:function o(){},
r:function r(){},
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
ak:function ak(a,b,c){this.a=a
this.b=b
this.$ti=c},
bi:function bi(a,b,c){this.a=a
this.b=b
this.$ti=c},
by:function by(a,b,c){var _=this
_.a=null
_.b=a
_.c=b
_.$ti=c},
h:function h(a,b,c){this.a=a
this.b=b
this.$ti=c},
y:function y(a,b,c){this.a=a
this.b=b
this.$ti=c},
a4:function a4(a,b,c){this.a=a
this.b=b
this.$ti=c},
am:function am(a,b,c){this.a=a
this.b=b
this.$ti=c},
aW:function aW(a,b,c){this.a=a
this.b=b
this.$ti=c},
bC:function bC(a,b,c){this.a=a
this.b=b
this.$ti=c},
bj:function bj(a){this.$ti=a},
bk:function bk(a){this.$ti=a},
f7(a,b,c){var t,s,r,q,p,o,n,m=A.fc(a.gD(),!0,b),l=m.length,k=0
for(;;){if(!(k<l)){t=!0
break}s=m[k]
if(typeof s!="string"||"__proto__"===s){t=!1
break}++k}if(t){r={}
for(q=0,k=0;k<m.length;m.length===l||(0,A.at)(m),++k,q=p){s=m[k]
c.a(a.i(0,s))
p=q+1
r[s]=q}o=A.fc(a.gS(),!0,c)
n=new A.a_(r,o,b.h("@<0>").u(c).h("a_<1,2>"))
n.$keys=m
return n}return new A.bf(A.i_(a,b,c),b.h("@<0>").u(c).h("bf<1,2>"))},
ht(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
v(a){var t
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
t=J.bc(a)
return t},
cs(a){var t,s=$.fQ
if(s==null)s=$.fQ=Symbol("identityHashCode")
t=a[s]
if(t==null){t=Math.random()*0x3fffffff|0
a[s]=t}return t},
i3(a,b){var t,s=/^\s*[+-]?((0x[a-f0-9]+)|(\d+)|([a-z0-9]+))\s*$/i.exec(a)
if(s==null)return null
if(3>=s.length)return A.a(s,3)
t=s[3]
if(t!=null)return parseInt(a,10)
if(s[2]!=null)return parseInt(a,16)
return null},
ct(a){var t,s,r,q
if(a instanceof A.m)return A.O(A.bZ(a),null)
t=J.aS(a)
if(t===B.am||t===B.an||u.ak.b(a)){s=B.Q(a)
if(s!=="Object"&&s!=="")return s
r=a.constructor
if(typeof r=="function"){q=r.name
if(typeof q=="string"&&q!=="Object"&&q!=="")return q}}return A.O(A.bZ(a),null)},
fX(a){var t,s,r
if(a==null||typeof a=="number"||A.fm(a))return J.bc(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.M)return a.j(0)
if(a instanceof A.aR)return a.aQ(!0)
t=$.hG()
for(s=0;s<1;++s){r=t[s].c0(a)
if(r!=null)return r}return"Instance of '"+A.ct(a)+"'"},
H(a){var t
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){t=a-65536
return String.fromCharCode((B.c.aO(t,10)|55296)>>>0,t&1023|56320)}throw A.d(A.ab(a,0,1114111,null,null))},
i4(a,b,c,d,e,f,g,h,i){var t,s,r,q=b-1
if(0<=a&&a<100){a+=400
q-=4800}t=B.c.a6(h,1000)
g+=B.c.A(h-t,1000)
s=i?Date.UTC(a,q,c,d,e,f,g):new Date(a,q,c,d,e,f,g).valueOf()
r=!0
if(!isNaN(s))if(!(s<-864e13))if(!(s>864e13))r=s===864e13&&t!==0
if(r)return null
return s},
S(a){if(a.date===void 0)a.date=new Date(a.a)
return a.date},
cr(a){return a.c?A.S(a).getUTCFullYear()+0:A.S(a).getFullYear()+0},
fV(a){return a.c?A.S(a).getUTCMonth()+1:A.S(a).getMonth()+1},
fR(a){return a.c?A.S(a).getUTCDate()+0:A.S(a).getDate()+0},
fS(a){return a.c?A.S(a).getUTCHours()+0:A.S(a).getHours()+0},
fU(a){return a.c?A.S(a).getUTCMinutes()+0:A.S(a).getMinutes()+0},
fW(a){return a.c?A.S(a).getUTCSeconds()+0:A.S(a).getSeconds()+0},
fT(a){return a.c?A.S(a).getUTCMilliseconds()+0:A.S(a).getMilliseconds()+0},
a(a,b){if(a==null)J.aD(a)
throw A.d(A.f_(a,b))},
f_(a,b){var t,s="index"
if(!A.bY(b))return new A.ae(!0,b,s,null)
t=J.aD(a)
if(b<0||b>=t)return A.e9(b,t,a,null,s)
return A.i6(b,s)},
j6(a){return new A.ae(!0,a,null,null)},
d(a){return A.G(a,new Error())},
G(a,b){var t
if(a==null)a=new A.bI()
b.dartException=a
t=A.jq
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:t})
b.name=""}else b.toString=t
return b},
jq(){return J.bc(this.dartException)},
aC(a,b){throw A.G(a,b==null?new Error():b)},
cH(a,b,c){var t
if(b==null)b=0
if(c==null)c=0
t=Error()
A.aC(A.iE(a,b,c),t)},
iE(a,b,c){var t,s,r,q,p,o,n,m,l
if(typeof b=="string")t=b
else{s="[]=;add;removeWhere;retainWhere;removeRange;setRange;setInt8;setInt16;setInt32;setUint8;setUint16;setUint32;setFloat32;setFloat64".split(";")
r=s.length
q=b
if(q>r){c=q/r|0
q%=r}t=s[q]}p=typeof c=="string"?c:"modify;remove from;add to".split(";")[c]
o=u.j.b(a)?"list":"ByteData"
n=a.$flags|0
m="a "
if((n&4)!==0)l="constant "
else if((n&2)!==0){l="unmodifiable "
m="an "}else l=(n&1)!==0?"fixed-length ":""
return new A.bK("'"+t+"': Cannot "+p+" "+m+l+o)},
at(a){throw A.d(A.P(a))},
ap(a){var t,s,r,q,p,o
a=A.jn(a.replace(String({}),"$receiver$"))
t=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(t==null)t=A.n([],u.s)
s=t.indexOf("\\$arguments\\$")
r=t.indexOf("\\$argumentsExpr\\$")
q=t.indexOf("\\$expr\\$")
p=t.indexOf("\\$method\\$")
o=t.indexOf("\\$receiver\\$")
return new A.eG(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),s,r,q,p,o)},
eH(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(t){return t.message}}(a)},
h1(a){return function($expr$){try{$expr$.$method$}catch(t){return t.message}}(a)},
fa(a,b){var t=b==null,s=t?null:b.method
return new A.cn(a,s,t?null:b.receiver)},
fr(a){if(a==null)return new A.ek(a)
if(typeof a!=="object")return a
if("dartException" in a)return A.aU(a,a.dartException)
return A.j5(a)},
aU(a,b){if(u.bU.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
j5(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
if(!("message" in a))return a
t=a.message
if("number" in a&&typeof a.number=="number"){s=a.number
r=s&65535
if((B.c.aO(s,16)&8191)===10)switch(r){case 438:return A.aU(a,A.fa(A.v(t)+" (Error "+r+")",null))
case 445:case 5007:A.v(t)
return A.aU(a,new A.bz())}}if(a instanceof TypeError){q=$.hw()
p=$.hx()
o=$.hy()
n=$.hz()
m=$.hC()
l=$.hD()
k=$.hB()
$.hA()
j=$.hF()
i=$.hE()
h=q.K(t)
if(h!=null)return A.aU(a,A.fa(A.J(t),h))
else{h=p.K(t)
if(h!=null){h.method="call"
return A.aU(a,A.fa(A.J(t),h))}else if(o.K(t)!=null||n.K(t)!=null||m.K(t)!=null||l.K(t)!=null||k.K(t)!=null||n.K(t)!=null||j.K(t)!=null||i.K(t)!=null){A.J(t)
return A.aU(a,new A.bz())}}return A.aU(a,new A.cy(typeof t=="string"?t:""))}if(a instanceof RangeError){if(typeof t=="string"&&t.indexOf("call stack")!==-1)return new A.bD()
t=function(b){try{return String(b)}catch(g){}return null}(a)
return A.aU(a,new A.ae(!1,null,null,typeof t=="string"?t.replace(/^RangeError:\s*/,""):t))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof t=="string"&&t==="too much recursion")return new A.bD()
return a},
hr(a){if(a==null)return J.W(a)
if(typeof a=="object")return A.cs(a)
return J.W(a)},
je(a,b){var t,s,r,q=a.length
for(t=0;t<q;t=r){s=t+1
r=s+1
b.m(0,a[t],a[s])}return b},
jf(a,b){var t,s=a.length
for(t=0;t<s;++t)b.n(0,a[t])
return b},
iN(a,b,c,d,e,f){u.Z.a(a)
switch(A.I(b)){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.d(new A.eK("Unsupported number of arguments for wrapped closure"))},
j9(a,b){var t=a.$identity
if(!!t)return t
t=A.ja(a,b)
a.$identity=t
return t},
ja(a,b){var t
switch(b){case 0:t=a.$0
break
case 1:t=a.$1
break
case 2:t=a.$2
break
case 3:t=a.$3
break
case 4:t=a.$4
break
default:t=null}if(t!=null)return t.bind(a)
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.iN)},
hR(a1){var t,s,r,q,p,o,n,m,l,k,j=a1.co,i=a1.iS,h=a1.iI,g=a1.nDA,f=a1.aI,e=a1.fs,d=a1.cs,c=e[0],b=d[0],a=j[c],a0=a1.fT
a0.toString
t=i?Object.create(new A.cv().constructor.prototype):Object.create(new A.aV(null,null).constructor.prototype)
t.$initialize=t.constructor
s=i?function static_tear_off(){this.$initialize()}:function tear_off(a2,a3){this.$initialize(a2,a3)}
t.constructor=s
s.prototype=t
t.$_name=c
t.$_target=a
r=!i
if(r)q=A.fA(c,a,h,g)
else{t.$static_name=c
q=a}t.$S=A.hN(a0,i,h)
t[b]=q
for(p=q,o=1;o<e.length;++o){n=e[o]
if(typeof n=="string"){m=j[n]
l=n
n=m}else l=""
k=d[o]
if(k!=null){if(r)n=A.fA(l,n,h,g)
t[k]=n}if(o===f)p=n}t.$C=p
t.$R=a1.rC
t.$D=a1.dV
return s},
hN(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.d("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.hL)}throw A.d("Error in functionType of tearoff")},
hO(a,b,c,d){var t=A.fz
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,t)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,t)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,t)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,t)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,t)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,t)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,t)}},
fA(a,b,c,d){if(c)return A.hQ(a,b,d)
return A.hO(b.length,d,a,b)},
hP(a,b,c,d){var t=A.fz,s=A.hM
switch(b?-1:a){case 0:throw A.d(new A.cu("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,s,t)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,s,t)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,s,t)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,s,t)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,s,t)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,s,t)
default:return function(e,f,g){return function(){var r=[g(this)]
Array.prototype.push.apply(r,arguments)
return e.apply(f(this),r)}}(d,s,t)}},
hQ(a,b,c){var t,s
if($.fx==null)$.fx=A.fw("interceptor")
if($.fy==null)$.fy=A.fw("receiver")
t=b.length
s=A.hP(t,c,a,b)
return s},
fo(a){return A.hR(a)},
hL(a,b){return A.bV(v.typeUniverse,A.bZ(a.a),b)},
fz(a){return a.a},
hM(a){return a.b},
fw(a){var t,s,r,q=new A.aV("receiver","interceptor"),p=Object.getOwnPropertyNames(q)
p.$flags=1
t=p
for(p=t.length,s=0;s<p;++s){r=t[s]
if(q[r]===a)return r}throw A.d(A.f6("Field name "+a+" not found."))},
ho(a){return v.getIsolateTag(a)},
jc(a,b){var t=b.length,s=v.rttc[""+t+";"+a]
if(s==null)return null
if(t===0)return s
if(t===s.length)return s.apply(null,b)
return s(b)},
hZ(a,b,c,d,e,f){var t=b?"m":"",s=c?"":"i",r=d?"u":"",q=e?"s":"",p=function(g,h){try{return new RegExp(g,h)}catch(o){return o}}(a,t+s+r+q+f)
if(p instanceof RegExp)return p
throw A.d(A.bl("Illegal RegExp pattern ("+String(p)+")",a))},
jn(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
bQ:function bQ(a,b){this.a=a
this.b=b},
bf:function bf(a,b){this.a=a
this.$ti=b},
be:function be(){},
dj:function dj(a,b,c){this.a=a
this.b=b
this.c=c},
a_:function a_(a,b,c){this.a=a
this.b=b
this.$ti=c},
aO:function aO(a,b){this.a=a
this.$ti=b},
bM:function bM(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
cg:function cg(){},
aX:function aX(a,b){this.a=a
this.$ti=b},
bB:function bB(){},
eG:function eG(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
bz:function bz(){},
cn:function cn(a,b,c){this.a=a
this.b=b
this.c=c},
cy:function cy(a){this.a=a},
ek:function ek(a){this.a=a},
M:function M(){},
c2:function c2(){},
c3:function c3(){},
cw:function cw(){},
cv:function cv(){},
aV:function aV(a,b){this.a=a
this.b=b},
cu:function cu(a){this.a=a},
aj:function aj(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
ed:function ed(a){this.a=a},
eh:function eh(a,b){this.a=a
this.b=b
this.c=null},
aJ:function aJ(a,b){this.a=a
this.$ti=b},
bs:function bs(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
a2:function a2(a,b){this.a=a
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
aR:function aR(){},
b5:function b5(){},
cm:function cm(a,b){var _=this
_.a=a
_.b=b
_.e=_.c=null},
eP:function eP(a){this.b=a},
ff(a,b){var t=b.c
return t==null?b.c=A.bT(a,"fF",[b.x]):t},
fZ(a){var t=a.w
if(t===6||t===7)return A.fZ(a.x)
return t===11||t===12},
i9(a){return a.as},
as(a){return A.eS(v.typeUniverse,a,!1)},
jk(a,b){var t,s,r,q,p
if(a==null)return null
t=b.y
s=a.Q
if(s==null)s=a.Q=new Map()
r=b.as
q=s.get(r)
if(q!=null)return q
p=A.aB(v.typeUniverse,a.x,t,0)
s.set(r,p)
return p},
aB(a0,a1,a2,a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=a1.w
switch(a){case 5:case 1:case 2:case 3:case 4:return a1
case 6:t=a1.x
s=A.aB(a0,t,a2,a3)
if(s===t)return a1
return A.ha(a0,s,!0)
case 7:t=a1.x
s=A.aB(a0,t,a2,a3)
if(s===t)return a1
return A.h9(a0,s,!0)
case 8:r=a1.y
q=A.b8(a0,r,a2,a3)
if(q===r)return a1
return A.bT(a0,a1.x,q)
case 9:p=a1.x
o=A.aB(a0,p,a2,a3)
n=a1.y
m=A.b8(a0,n,a2,a3)
if(o===p&&m===n)return a1
return A.fi(a0,o,m)
case 10:l=a1.x
k=a1.y
j=A.b8(a0,k,a2,a3)
if(j===k)return a1
return A.hb(a0,l,j)
case 11:i=a1.x
h=A.aB(a0,i,a2,a3)
g=a1.y
f=A.j2(a0,g,a2,a3)
if(h===i&&f===g)return a1
return A.h8(a0,h,f)
case 12:e=a1.y
a3+=e.length
d=A.b8(a0,e,a2,a3)
p=a1.x
o=A.aB(a0,p,a2,a3)
if(d===e&&o===p)return a1
return A.fj(a0,o,d,!0)
case 13:c=a1.x
if(c<a3)return a1
b=a2[c-a3]
if(b==null)return a1
return b
default:throw A.d(A.c1("Attempted to substitute unexpected RTI kind "+a))}},
b8(a,b,c,d){var t,s,r,q,p=b.length,o=A.eT(p)
for(t=!1,s=0;s<p;++s){r=b[s]
q=A.aB(a,r,c,d)
if(q!==r)t=!0
o[s]=q}return t?o:b},
j3(a,b,c,d){var t,s,r,q,p,o,n=b.length,m=A.eT(n)
for(t=!1,s=0;s<n;s+=3){r=b[s]
q=b[s+1]
p=b[s+2]
o=A.aB(a,p,c,d)
if(o!==p)t=!0
m.splice(s,3,r,q,o)}return t?m:b},
j2(a,b,c,d){var t,s=b.a,r=A.b8(a,s,c,d),q=b.b,p=A.b8(a,q,c,d),o=b.c,n=A.j3(a,o,c,d)
if(r===s&&p===q&&n===o)return b
t=new A.cA()
t.a=r
t.b=p
t.c=n
return t},
n(a,b){a[v.arrayRti]=b
return a},
eZ(a){var t=a.$S
if(t!=null){if(typeof t=="number")return A.ji(t)
return a.$S()}return null},
jj(a,b){var t
if(A.fZ(b))if(a instanceof A.M){t=A.eZ(a)
if(t!=null)return t}return A.bZ(a)},
bZ(a){if(a instanceof A.m)return A.f(a)
if(Array.isArray(a))return A.i(a)
return A.fl(J.aS(a))},
i(a){var t=a[v.arrayRti],s=u.gn
if(t==null)return s
if(t.constructor!==s.constructor)return s
return t},
f(a){var t=a.$ti
return t!=null?t:A.fl(a)},
fl(a){var t=a.constructor,s=t.$ccache
if(s!=null)return s
return A.iL(a,t)},
iL(a,b){var t=a instanceof A.M?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,s=A.iu(v.typeUniverse,t.name)
b.$ccache=s
return s},
ji(a){var t,s=v.types,r=s[a]
if(typeof r=="string"){t=A.eS(v.typeUniverse,r,!1)
s[a]=t
return t}return r},
jh(a){return A.ar(A.f(a))},
fp(a){var t=A.eZ(a)
return A.ar(t==null?A.bZ(a):t)},
fn(a){var t
if(a instanceof A.aR)return A.jd(a.$r,a.aG())
t=a instanceof A.M?A.eZ(a):null
if(t!=null)return t
if(u.dm.b(a))return J.hJ(a).a
if(Array.isArray(a))return A.i(a)
return A.bZ(a)},
ar(a){var t=a.r
return t==null?a.r=new A.eR(a):t},
jd(a,b){var t,s,r=b,q=r.length
if(q===0)return u.bQ
if(0>=q)return A.a(r,0)
t=A.bV(v.typeUniverse,A.fn(r[0]),"@<0>")
for(s=1;s<q;++s){if(!(s<r.length))return A.a(r,s)
t=A.hc(v.typeUniverse,t,A.fn(r[s]))}return A.bV(v.typeUniverse,t,a)},
jr(a){return A.ar(A.eS(v.typeUniverse,a,!1))},
iK(a){var t=this
t.b=A.j1(t)
return t.b(a)},
j1(a){var t,s,r,q,p
if(a===u.C)return A.iT
if(A.aT(a))return A.iX
t=a.w
if(t===6)return A.iI
if(t===1)return A.hl
if(t===7)return A.iO
s=A.j0(a)
if(s!=null)return s
if(t===8){r=a.x
if(a.y.every(A.aT)){a.f="$i"+r
if(r==="x")return A.iR
if(a===u.m)return A.iQ
return A.iW}}else if(t===10){q=A.jc(a.x,a.y)
p=q==null?A.hl:q
return p==null?A.hg(p):p}return A.iG},
j0(a){if(a.w===8){if(a===u.S)return A.bY
if(a===u.i||a===u.H)return A.iS
if(a===u.N)return A.iV
if(a===u.y)return A.fm}return null},
iJ(a){var t=this,s=A.iF
if(A.aT(t))s=A.iB
else if(t===u.C)s=A.hg
else if(A.ba(t)){s=A.iH
if(t===u.I)s=A.fk
else if(t===u.dk)s=A.eW
else if(t===u.fQ)s=A.eV
else if(t===u.cg)s=A.hf
else if(t===u.cD)s=A.iy
else if(t===u.an)s=A.iA}else if(t===u.S)s=A.I
else if(t===u.N)s=A.J
else if(t===u.y)s=A.ix
else if(t===u.H)s=A.z
else if(t===u.i)s=A.p
else if(t===u.m)s=A.iz
t.a=s
return t.a(a)},
iG(a){var t=this
if(a==null)return A.ba(t)
return A.hp(v.typeUniverse,A.jj(a,t),t)},
iI(a){if(a==null)return!0
return this.x.b(a)},
iW(a){var t,s=this
if(a==null)return A.ba(s)
t=s.f
if(a instanceof A.m)return!!a[t]
return!!J.aS(a)[t]},
iR(a){var t,s=this
if(a==null)return A.ba(s)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
t=s.f
if(a instanceof A.m)return!!a[t]
return!!J.aS(a)[t]},
iQ(a){var t=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.m)return!!a[t.f]
return!0}if(typeof a=="function")return!0
return!1},
hk(a){if(typeof a=="object"){if(a instanceof A.m)return u.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
iF(a){var t=this
if(a==null){if(A.ba(t))return a}else if(t.b(a))return a
throw A.G(A.hh(a,t),new Error())},
iH(a){var t=this
if(a==null||t.b(a))return a
throw A.G(A.hh(a,t),new Error())},
hh(a,b){return new A.b6("TypeError: "+A.h2(a,A.O(b,null)))},
j8(a,b,c,d){if(A.hp(v.typeUniverse,a,b))return a
throw A.G(A.il("The type argument '"+A.O(a,null)+"' is not a subtype of the type variable bound '"+A.O(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
h2(a,b){return A.ce(a)+": type '"+A.O(A.fn(a),null)+"' is not a subtype of type '"+b+"'"},
il(a){return new A.b6("TypeError: "+a)},
Y(a,b){return new A.b6("TypeError: "+A.h2(a,b))},
iO(a){var t=this
return t.x.b(a)||A.ff(v.typeUniverse,t).b(a)},
iT(a){return a!=null},
hg(a){if(a!=null)return a
throw A.G(A.Y(a,"Object"),new Error())},
iX(a){return!0},
iB(a){return a},
hl(a){return!1},
fm(a){return!0===a||!1===a},
ix(a){if(!0===a)return!0
if(!1===a)return!1
throw A.G(A.Y(a,"bool"),new Error())},
eV(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.G(A.Y(a,"bool?"),new Error())},
p(a){if(typeof a=="number")return a
throw A.G(A.Y(a,"double"),new Error())},
iy(a){if(typeof a=="number")return a
if(a==null)return a
throw A.G(A.Y(a,"double?"),new Error())},
bY(a){return typeof a=="number"&&Math.floor(a)===a},
I(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.G(A.Y(a,"int"),new Error())},
fk(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.G(A.Y(a,"int?"),new Error())},
iS(a){return typeof a=="number"},
z(a){if(typeof a=="number")return a
throw A.G(A.Y(a,"num"),new Error())},
hf(a){if(typeof a=="number")return a
if(a==null)return a
throw A.G(A.Y(a,"num?"),new Error())},
iV(a){return typeof a=="string"},
J(a){if(typeof a=="string")return a
throw A.G(A.Y(a,"String"),new Error())},
eW(a){if(typeof a=="string")return a
if(a==null)return a
throw A.G(A.Y(a,"String?"),new Error())},
iz(a){if(A.hk(a))return a
throw A.G(A.Y(a,"JSObject"),new Error())},
iA(a){if(a==null)return a
if(A.hk(a))return a
throw A.G(A.Y(a,"JSObject?"),new Error())},
hm(a,b){var t,s,r
for(t="",s="",r=0;r<a.length;++r,s=", ")t+=s+A.O(a[r],b)
return t},
j_(a,b){var t,s,r,q,p,o,n=a.x,m=a.y
if(""===n)return"("+A.hm(m,b)+")"
t=m.length
s=n.split(",")
r=s.length-t
for(q="(",p="",o=0;o<t;++o,p=", "){q+=p
if(r===0)q+="{"
q+=A.O(m[o],b)
if(r>=0)q+=" "+s[r];++r}return q+"})"},
hi(a2,a3,a4){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=", ",a1=null
if(a4!=null){t=a4.length
if(a3==null)a3=A.n([],u.s)
else a1=a3.length
s=a3.length
for(r=t;r>0;--r)B.a.n(a3,"T"+(s+r))
for(q=u.U,p="<",o="",r=0;r<t;++r,o=a0){n=a3.length
m=n-1-r
if(!(m>=0))return A.a(a3,m)
p=p+o+a3[m]
l=a4[r]
k=l.w
if(!(k===2||k===3||k===4||k===5||l===q))p+=" extends "+A.O(l,a3)}p+=">"}else p=""
q=a2.x
j=a2.y
i=j.a
h=i.length
g=j.b
f=g.length
e=j.c
d=e.length
c=A.O(q,a3)
for(b="",a="",r=0;r<h;++r,a=a0)b+=a+A.O(i[r],a3)
if(f>0){b+=a+"["
for(a="",r=0;r<f;++r,a=a0)b+=a+A.O(g[r],a3)
b+="]"}if(d>0){b+=a+"{"
for(a="",r=0;r<d;r+=3,a=a0){b+=a
if(e[r+1])b+="required "
b+=A.O(e[r+2],a3)+" "+e[r]}b+="}"}if(a1!=null){a3.toString
a3.length=a1}return p+"("+b+") => "+c},
O(a,b){var t,s,r,q,p,o,n,m=a.w
if(m===5)return"erased"
if(m===2)return"dynamic"
if(m===3)return"void"
if(m===1)return"Never"
if(m===4)return"any"
if(m===6){t=a.x
s=A.O(t,b)
r=t.w
return(r===11||r===12?"("+s+")":s)+"?"}if(m===7)return"FutureOr<"+A.O(a.x,b)+">"
if(m===8){q=A.j4(a.x)
p=a.y
return p.length>0?q+("<"+A.hm(p,b)+">"):q}if(m===10)return A.j_(a,b)
if(m===11)return A.hi(a,b,null)
if(m===12)return A.hi(a.x,b,a.y)
if(m===13){o=a.x
n=b.length
o=n-1-o
if(!(o>=0&&o<n))return A.a(b,o)
return b[o]}return"?"},
j4(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
iv(a,b){var t=a.tR[b]
while(typeof t=="string")t=a.tR[t]
return t},
iu(a,b){var t,s,r,q,p,o=a.eT,n=o[b]
if(n==null)return A.eS(a,b,!1)
else if(typeof n=="number"){t=n
s=A.bU(a,5,"#")
r=A.eT(t)
for(q=0;q<t;++q)r[q]=s
p=A.bT(a,b,r)
o[b]=p
return p}else return n},
it(a,b){return A.hd(a.tR,b)},
is(a,b){return A.hd(a.eT,b)},
eS(a,b,c){var t,s=a.eC,r=s.get(b)
if(r!=null)return r
t=A.h6(A.h4(a,null,b,!1))
s.set(b,t)
return t},
bV(a,b,c){var t,s,r=b.z
if(r==null)r=b.z=new Map()
t=r.get(c)
if(t!=null)return t
s=A.h6(A.h4(a,b,c,!0))
r.set(c,s)
return s},
hc(a,b,c){var t,s,r,q=b.Q
if(q==null)q=b.Q=new Map()
t=c.as
s=q.get(t)
if(s!=null)return s
r=A.fi(a,b,c.w===9?c.y:[c])
q.set(t,r)
return r},
az(a,b){b.a=A.iJ
b.b=A.iK
return b},
bU(a,b,c){var t,s,r=a.eC.get(c)
if(r!=null)return r
t=new A.a3(null,null)
t.w=b
t.as=c
s=A.az(a,t)
a.eC.set(c,s)
return s},
ha(a,b,c){var t,s=b.as+"?",r=a.eC.get(s)
if(r!=null)return r
t=A.iq(a,b,s,c)
a.eC.set(s,t)
return t},
iq(a,b,c,d){var t,s,r
if(d){t=b.w
s=!0
if(!A.aT(b))if(!(b===u.a||b===u.T))if(t!==6)s=t===7&&A.ba(b.x)
if(s)return b
else if(t===1)return u.a}r=new A.a3(null,null)
r.w=6
r.x=b
r.as=c
return A.az(a,r)},
h9(a,b,c){var t,s=b.as+"/",r=a.eC.get(s)
if(r!=null)return r
t=A.io(a,b,s,c)
a.eC.set(s,t)
return t},
io(a,b,c,d){var t,s
if(d){t=b.w
if(A.aT(b)||b===u.C)return b
else if(t===1)return A.bT(a,"fF",[b])
else if(b===u.a||b===u.T)return u.eH}s=new A.a3(null,null)
s.w=7
s.x=b
s.as=c
return A.az(a,s)},
ir(a,b){var t,s,r=""+b+"^",q=a.eC.get(r)
if(q!=null)return q
t=new A.a3(null,null)
t.w=13
t.x=b
t.as=r
s=A.az(a,t)
a.eC.set(r,s)
return s},
bS(a){var t,s,r,q=a.length
for(t="",s="",r=0;r<q;++r,s=",")t+=s+a[r].as
return t},
im(a){var t,s,r,q,p,o=a.length
for(t="",s="",r=0;r<o;r+=3,s=","){q=a[r]
p=a[r+1]?"!":":"
t+=s+q+p+a[r+2].as}return t},
bT(a,b,c){var t,s,r,q=b
if(c.length>0)q+="<"+A.bS(c)+">"
t=a.eC.get(q)
if(t!=null)return t
s=new A.a3(null,null)
s.w=8
s.x=b
s.y=c
if(c.length>0)s.c=c[0]
s.as=q
r=A.az(a,s)
a.eC.set(q,r)
return r},
fi(a,b,c){var t,s,r,q,p,o
if(b.w===9){t=b.x
s=b.y.concat(c)}else{s=c
t=b}r=t.as+(";<"+A.bS(s)+">")
q=a.eC.get(r)
if(q!=null)return q
p=new A.a3(null,null)
p.w=9
p.x=t
p.y=s
p.as=r
o=A.az(a,p)
a.eC.set(r,o)
return o},
hb(a,b,c){var t,s,r="+"+(b+"("+A.bS(c)+")"),q=a.eC.get(r)
if(q!=null)return q
t=new A.a3(null,null)
t.w=10
t.x=b
t.y=c
t.as=r
s=A.az(a,t)
a.eC.set(r,s)
return s},
h8(a,b,c){var t,s,r,q,p,o=b.as,n=c.a,m=n.length,l=c.b,k=l.length,j=c.c,i=j.length,h="("+A.bS(n)
if(k>0){t=m>0?",":""
h+=t+"["+A.bS(l)+"]"}if(i>0){t=m>0?",":""
h+=t+"{"+A.im(j)+"}"}s=o+(h+")")
r=a.eC.get(s)
if(r!=null)return r
q=new A.a3(null,null)
q.w=11
q.x=b
q.y=c
q.as=s
p=A.az(a,q)
a.eC.set(s,p)
return p},
fj(a,b,c,d){var t,s=b.as+("<"+A.bS(c)+">"),r=a.eC.get(s)
if(r!=null)return r
t=A.ip(a,b,c,s,d)
a.eC.set(s,t)
return t},
ip(a,b,c,d,e){var t,s,r,q,p,o,n,m
if(e){t=c.length
s=A.eT(t)
for(r=0,q=0;q<t;++q){p=c[q]
if(p.w===1){s[q]=p;++r}}if(r>0){o=A.aB(a,b,s,0)
n=A.b8(a,c,s,0)
return A.fj(a,o,n,c!==n)}}m=new A.a3(null,null)
m.w=12
m.x=b
m.y=c
m.as=d
return A.az(a,m)},
h4(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
h6(a){var t,s,r,q,p,o,n,m=a.r,l=a.s
for(t=m.length,s=0;s<t;){r=m.charCodeAt(s)
if(r>=48&&r<=57)s=A.ig(s+1,r,m,l)
else if((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124)s=A.h5(a,s,m,l,!1)
else if(r===46)s=A.h5(a,s,m,l,!0)
else{++s
switch(r){case 44:break
case 58:l.push(!1)
break
case 33:l.push(!0)
break
case 59:l.push(A.aQ(a.u,a.e,l.pop()))
break
case 94:l.push(A.ir(a.u,l.pop()))
break
case 35:l.push(A.bU(a.u,5,"#"))
break
case 64:l.push(A.bU(a.u,2,"@"))
break
case 126:l.push(A.bU(a.u,3,"~"))
break
case 60:l.push(a.p)
a.p=l.length
break
case 62:A.ii(a,l)
break
case 38:A.ih(a,l)
break
case 63:q=a.u
l.push(A.ha(q,A.aQ(q,a.e,l.pop()),a.n))
break
case 47:q=a.u
l.push(A.h9(q,A.aQ(q,a.e,l.pop()),a.n))
break
case 40:l.push(-3)
l.push(a.p)
a.p=l.length
break
case 41:A.ie(a,l)
break
case 91:l.push(a.p)
a.p=l.length
break
case 93:p=l.splice(a.p)
A.h7(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-1)
break
case 123:l.push(a.p)
a.p=l.length
break
case 125:p=l.splice(a.p)
A.ik(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-2)
break
case 43:o=m.indexOf("(",s)
l.push(m.substring(s,o))
l.push(-4)
l.push(a.p)
a.p=l.length
s=o+1
break
default:throw"Bad character "+r}}}n=l.pop()
return A.aQ(a.u,a.e,n)},
ig(a,b,c,d){var t,s,r=b-48
for(t=c.length;a<t;++a){s=c.charCodeAt(a)
if(!(s>=48&&s<=57))break
r=r*10+(s-48)}d.push(r)
return a},
h5(a,b,c,d,e){var t,s,r,q,p,o,n=b+1
for(t=c.length;n<t;++n){s=c.charCodeAt(n)
if(s===46){if(e)break
e=!0}else{if(!((((s|32)>>>0)-97&65535)<26||s===95||s===36||s===124))r=s>=48&&s<=57
else r=!0
if(!r)break}}q=c.substring(b,n)
if(e){t=a.u
p=a.e
if(p.w===9)p=p.x
o=A.iv(t,p.x)[q]
if(o==null)A.aC('No "'+q+'" in "'+A.i9(p)+'"')
d.push(A.bV(t,p,o))}else d.push(q)
return n},
ii(a,b){var t,s=a.u,r=A.h3(a,b),q=b.pop()
if(typeof q=="string")b.push(A.bT(s,q,r))
else{t=A.aQ(s,a.e,q)
switch(t.w){case 11:b.push(A.fj(s,t,r,a.n))
break
default:b.push(A.fi(s,t,r))
break}}},
ie(a,b){var t,s,r,q=a.u,p=b.pop(),o=null,n=null
if(typeof p=="number")switch(p){case-1:o=b.pop()
break
case-2:n=b.pop()
break
default:b.push(p)
break}else b.push(p)
t=A.h3(a,b)
p=b.pop()
switch(p){case-3:p=b.pop()
if(o==null)o=q.sEA
if(n==null)n=q.sEA
s=A.aQ(q,a.e,p)
r=new A.cA()
r.a=t
r.b=o
r.c=n
b.push(A.h8(q,s,r))
return
case-4:b.push(A.hb(q,b.pop(),t))
return
default:throw A.d(A.c1("Unexpected state under `()`: "+A.v(p)))}},
ih(a,b){var t=b.pop()
if(0===t){b.push(A.bU(a.u,1,"0&"))
return}if(1===t){b.push(A.bU(a.u,4,"1&"))
return}throw A.d(A.c1("Unexpected extended operation "+A.v(t)))},
h3(a,b){var t=b.splice(a.p)
A.h7(a.u,a.e,t)
a.p=b.pop()
return t},
aQ(a,b,c){if(typeof c=="string")return A.bT(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.ij(a,b,c)}else return c},
h7(a,b,c){var t,s=c.length
for(t=0;t<s;++t)c[t]=A.aQ(a,b,c[t])},
ik(a,b,c){var t,s=c.length
for(t=2;t<s;t+=3)c[t]=A.aQ(a,b,c[t])},
ij(a,b,c){var t,s,r=b.w
if(r===9){if(c===0)return b.x
t=b.y
s=t.length
if(c<=s)return t[c-1]
c-=s
b=b.x
r=b.w}else if(c===0)return b
if(r!==8)throw A.d(A.c1("Indexed base must be an interface type"))
t=b.y
if(c<=t.length)return t[c-1]
throw A.d(A.c1("Bad index "+c+" for "+b.j(0)))},
hp(a,b,c){var t,s=b.d
if(s==null)s=b.d=new Map()
t=s.get(c)
if(t==null){t=A.B(a,b,null,c,null)
s.set(c,t)}return t},
B(a,b,c,d,e){var t,s,r,q,p,o,n,m,l,k,j
if(b===d)return!0
if(A.aT(d))return!0
t=b.w
if(t===4)return!0
if(A.aT(b))return!1
if(b.w===1)return!0
s=t===13
if(s)if(A.B(a,c[b.x],c,d,e))return!0
r=d.w
q=u.a
if(b===q||b===u.T){if(r===7)return A.B(a,b,c,d.x,e)
return d===q||d===u.T||r===6}if(d===u.C){if(t===7)return A.B(a,b.x,c,d,e)
return t!==6}if(t===7){if(!A.B(a,b.x,c,d,e))return!1
return A.B(a,A.ff(a,b),c,d,e)}if(t===6)return A.B(a,q,c,d,e)&&A.B(a,b.x,c,d,e)
if(r===7){if(A.B(a,b,c,d.x,e))return!0
return A.B(a,b,c,A.ff(a,d),e)}if(r===6)return A.B(a,b,c,q,e)||A.B(a,b,c,d.x,e)
if(s)return!1
q=t!==11
if((!q||t===12)&&d===u.Z)return!0
p=t===10
if(p&&d===u.gT)return!0
if(r===12){if(b===u.L)return!0
if(t!==12)return!1
o=b.y
n=d.y
m=o.length
if(m!==n.length)return!1
c=c==null?o:o.concat(c)
e=e==null?n:n.concat(e)
for(l=0;l<m;++l){k=o[l]
j=n[l]
if(!A.B(a,k,c,j,e)||!A.B(a,j,e,k,c))return!1}return A.hj(a,b.x,c,d.x,e)}if(r===11){if(b===u.L)return!0
if(q)return!1
return A.hj(a,b,c,d,e)}if(t===8){if(r!==8)return!1
return A.iP(a,b,c,d,e)}if(p&&r===10)return A.iU(a,b,c,d,e)
return!1},
hj(a2,a3,a4,a5,a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1
if(!A.B(a2,a3.x,a4,a5.x,a6))return!1
t=a3.y
s=a5.y
r=t.a
q=s.a
p=r.length
o=q.length
if(p>o)return!1
n=o-p
m=t.b
l=s.b
k=m.length
j=l.length
if(p+k<o+j)return!1
for(i=0;i<p;++i){h=r[i]
if(!A.B(a2,q[i],a6,h,a4))return!1}for(i=0;i<n;++i){h=m[i]
if(!A.B(a2,q[p+i],a6,h,a4))return!1}for(i=0;i<j;++i){h=m[n+i]
if(!A.B(a2,l[i],a6,h,a4))return!1}g=t.c
f=s.c
e=g.length
d=f.length
for(c=0,b=0;b<d;b+=3){a=f[b]
for(;;){if(c>=e)return!1
a0=g[c]
c+=3
if(a<a0)return!1
a1=g[c-2]
if(a0<a){if(a1)return!1
continue}h=f[b+1]
if(a1&&!h)return!1
h=g[c-1]
if(!A.B(a2,f[b+2],a6,h,a4))return!1
break}}while(c<e){if(g[c+1])return!1
c+=3}return!0},
iP(a,b,c,d,e){var t,s,r,q,p,o=b.x,n=d.x
while(o!==n){t=a.tR[o]
if(t==null)return!1
if(typeof t=="string"){o=t
continue}s=t[n]
if(s==null)return!1
r=s.length
q=r>0?new Array(r):v.typeUniverse.sEA
for(p=0;p<r;++p)q[p]=A.bV(a,b,s[p])
return A.he(a,q,null,c,d.y,e)}return A.he(a,b.y,null,c,d.y,e)},
he(a,b,c,d,e,f){var t,s=b.length
for(t=0;t<s;++t)if(!A.B(a,b[t],d,e[t],f))return!1
return!0},
iU(a,b,c,d,e){var t,s=b.y,r=d.y,q=s.length
if(q!==r.length)return!1
if(b.x!==d.x)return!1
for(t=0;t<q;++t)if(!A.B(a,s[t],c,r[t],e))return!1
return!0},
ba(a){var t=a.w,s=!0
if(!(a===u.a||a===u.T))if(!A.aT(a))if(t!==6)s=t===7&&A.ba(a.x)
return s},
aT(a){var t=a.w
return t===2||t===3||t===4||t===5||a===u.U},
hd(a,b){var t,s,r=Object.keys(b),q=r.length
for(t=0;t<q;++t){s=r[t]
a[s]=b[s]}},
eT(a){return a>0?new Array(a):v.typeUniverse.sEA},
a3:function a3(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
cA:function cA(){this.c=this.b=this.a=null},
eR:function eR(a){this.a=a},
cz:function cz(){},
b6:function b6(a){this.a=a},
fK(a,b){return new A.aj(a.h("@<0>").u(b).h("aj<1,2>"))},
bu(a,b,c){return b.h("@<0>").u(c).h("fJ<1,2>").a(A.je(a,new A.aj(b.h("@<0>").u(c).h("aj<1,2>"))))},
a8(a,b){return new A.aj(a.h("@<0>").u(b).h("aj<1,2>"))},
fN(a){return new A.aq(a.h("aq<0>"))},
fb(a){return new A.aq(a.h("aq<0>"))},
i0(a,b){return b.h("fM<0>").a(A.jf(a,new A.aq(b.h("aq<0>"))))},
fh(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
id(a,b,c){var t=new A.aP(a,b,c.h("aP<0>"))
t.c=a.e
return t},
i_(a,b,c){var t=A.fK(b,c)
a.G(0,new A.ei(t,b,c))
return t},
fL(a,b,c){var t=A.fK(b,c)
t.E(0,a)
return t},
i1(a,b){var t=A.fN(b)
t.E(0,a)
return t},
fd(a){var t,s
if(A.fq(a))return"{...}"
t=new A.b2("")
try{s={}
B.a.n($.V,a)
t.a+="{"
s.a=!0
a.G(0,new A.ej(s,t))
t.a+="}"}finally{if(0>=$.V.length)return A.a($.V,-1)
$.V.pop()}s=t.a
return s.charCodeAt(0)==0?s:s},
i2(a){return 8},
iw(){throw A.d(A.eI("Cannot change an unmodifiable set"))},
aq:function aq(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
cD:function cD(a){this.a=a
this.b=null},
aP:function aP(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
ei:function ei(a,b,c){this.a=a
this.b=b
this.c=c},
w:function w(){},
ej:function ej(a,b){this.a=a
this.b=b},
bO:function bO(a,b){this.a=a
this.$ti=b},
bP:function bP(a,b,c){var _=this
_.a=a
_.b=b
_.c=null
_.$ti=c},
bW:function bW(){},
b1:function b1(){},
aN:function aN(a,b){this.a=a
this.$ti=b},
bw:function bw(a,b){var _=this
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
aM:function aM(){},
bR:function bR(){},
cE:function cE(){},
bJ:function bJ(a,b){this.a=a
this.$ti=b},
b7:function b7(){},
bX:function bX(){},
iZ(a,b){var t,s,r,q=null
try{q=JSON.parse(a)}catch(s){t=A.fr(s)
r=A.bl(String(t),null)
throw A.d(r)}r=A.eX(q)
return r},
eX(a){var t
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.cB(a,Object.create(null))
for(t=0;t<a.length;++t)a[t]=A.eX(a[t])
return a},
fI(a,b,c){return new A.bp(a,b)},
iD(a){return a.a5()},
ib(a,b){return new A.eM(a,[],A.jb())},
ic(a,b,c){var t,s=new A.b2(""),r=A.ib(s,b)
r.ae(a)
t=s.a
return t.charCodeAt(0)==0?t:t},
cB:function cB(a,b){this.a=a
this.b=b
this.c=null},
eL:function eL(a){this.a=a},
cC:function cC(a){this.a=a},
c4:function c4(){},
c6:function c6(){},
bp:function bp(a,b){this.a=a
this.b=b},
co:function co(a,b){this.a=a
this.b=b},
ee:function ee(){},
eg:function eg(a){this.b=a},
ef:function ef(a){this.a=a},
eN:function eN(){},
eO:function eO(a,b){this.a=a
this.b=b},
eM:function eM(a,b,c){this.c=a
this.a=b
this.b=c},
cG(a){var t=A.i3(a,null)
if(t!=null)return t
throw A.d(A.bl(a,null))},
bx(a,b,c,d){var t,s=J.fH(a,d)
if(a!==0&&b!=null)for(t=0;t<a;++t)s[t]=b
return s},
fc(a,b,c){var t,s=A.n([],c.h("l<0>"))
for(t=J.ad(a);t.p();)B.a.n(s,c.a(t.gq()))
if(b)return s
s.$flags=1
return s},
D(a,b){var t,s=A.n([],b.h("l<0>"))
for(t=a.gt(a);t.p();)B.a.n(s,t.gq())
return s},
a9(a,b){var t=A.fc(a,!1,b)
t.$flags=3
return t},
i8(a){return new A.cm(a,A.hZ(a,!1,!0,!1,!1,""))},
h0(a,b,c){var t=J.ad(b)
if(!t.p())return a
if(c.length===0){do a+=A.v(t.gq())
while(t.p())}else{a+=A.v(t.gq())
while(t.p())a=a+c+A.v(t.gq())}return a},
hS(a,b,c,d,e,f,g,h,i){var t=A.i4(a,b,c,d,e,f,g,h,i)
if(t==null)return null
return new A.af(A.fC(t,h,i),h,i)},
du(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=$.hv().bT(a)
if(d!=null){t=new A.dv()
s=d.b
if(1>=s.length)return A.a(s,1)
r=s[1]
r.toString
q=A.cG(r)
if(2>=s.length)return A.a(s,2)
r=s[2]
r.toString
p=A.cG(r)
if(3>=s.length)return A.a(s,3)
r=s[3]
r.toString
o=A.cG(r)
if(4>=s.length)return A.a(s,4)
n=t.$1(s[4])
if(5>=s.length)return A.a(s,5)
m=t.$1(s[5])
if(6>=s.length)return A.a(s,6)
l=t.$1(s[6])
if(7>=s.length)return A.a(s,7)
k=new A.dw().$1(s[7])
j=B.c.A(k,1000)
r=s.length
if(8>=r)return A.a(s,8)
i=s[8]!=null
if(i){if(9>=r)return A.a(s,9)
h=s[9]
if(h!=null){g=h==="-"?-1:1
if(10>=r)return A.a(s,10)
r=s[10]
r.toString
f=A.cG(r)
if(11>=s.length)return A.a(s,11)
m-=g*(t.$1(s[11])+60*f)}}e=A.hS(q,p,o,n,m,l,j,k%1000,i)
if(e==null)throw A.d(A.bl("Time out of range",a))
return e}else throw A.d(A.bl("Invalid date format",a))},
fC(a,b,c){var t="microsecond"
if(b<0||b>999)throw A.d(A.ab(b,0,999,t,null))
if(a<-864e13||a>864e13)throw A.d(A.ab(a,-864e13,864e13,"millisecondsSinceEpoch",null))
if(a===864e13&&b!==0)throw A.d(A.hK(b,t,"Time including microseconds is outside valid range"))
A.hn(c,"isUtc",u.y)
return a},
fB(a){var t=Math.abs(a),s=a<0?"-":""
if(t>=1000)return""+a
if(t>=100)return s+"0"+t
if(t>=10)return s+"00"+t
return s+"000"+t},
hT(a){var t=Math.abs(a),s=a<0?"-":"+"
if(t>=1e5)return s+t
return s+"0"+t},
dt(a){if(a>=100)return""+a
if(a>=10)return"0"+a
return"00"+a},
ag(a){if(a>=10)return""+a
return"0"+a},
A(a,b){return new A.N(a+1000*b)},
ce(a){if(typeof a=="number"||A.fm(a)||a==null)return J.bc(a)
if(typeof a=="string")return JSON.stringify(a)
return A.fX(a)},
c1(a){return new A.c0(a)},
f6(a){return new A.ae(!1,null,null,a)},
hK(a,b,c){return new A.ae(!0,a,b,c)},
cW(a,b,c){return a},
i6(a,b){return new A.bA(null,null,!0,a,b,"Value not in range")},
ab(a,b,c,d,e){return new A.bA(b,c,!0,a,d,"Invalid value")},
fY(a,b,c){if(0>a||a>c)throw A.d(A.ab(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.d(A.ab(b,a,c,"end",null))
return b}return c},
al(a,b){if(a<0)throw A.d(A.ab(a,0,null,b,null))
return a},
e9(a,b,c,d,e){return new A.cf(b,!0,a,e,"Index out of range")},
eI(a){return new A.bK(a)},
P(a){return new A.c5(a)},
bl(a,b){return new A.a1(a,b)},
hX(a,b,c){var t,s
if(A.fq(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}t=A.n([],u.s)
B.a.n($.V,a)
try{A.iY(a,t)}finally{if(0>=$.V.length)return A.a($.V,-1)
$.V.pop()}s=A.h0(b,u.hf.a(t),", ")+c
return s.charCodeAt(0)==0?s:s},
f8(a,b,c){var t,s
if(A.fq(a))return b+"..."+c
t=new A.b2(b)
B.a.n($.V,a)
try{s=t
s.a=A.h0(s.a,a,", ")}finally{if(0>=$.V.length)return A.a($.V,-1)
$.V.pop()}t.a+=c
s=t.a
return s.charCodeAt(0)==0?s:s},
iY(a,b){var t,s,r,q,p,o,n,m=a.gt(a),l=0,k=0
for(;;){if(!(l<80||k<3))break
if(!m.p())return
t=A.v(m.gq())
B.a.n(b,t)
l+=t.length+2;++k}if(!m.p()){if(k<=5)return
if(0>=b.length)return A.a(b,-1)
s=b.pop()
if(0>=b.length)return A.a(b,-1)
r=b.pop()}else{q=m.gq();++k
if(!m.p()){if(k<=4){B.a.n(b,A.v(q))
return}s=A.v(q)
if(0>=b.length)return A.a(b,-1)
r=b.pop()
l+=s.length+2}else{p=m.gq();++k
for(;m.p();q=p,p=o){o=m.gq();++k
if(k>100){for(;;){if(!(l>75&&k>3))break
if(0>=b.length)return A.a(b,-1)
l-=b.pop().length+2;--k}B.a.n(b,"...")
return}}r=A.v(q)
s=A.v(p)
l+=s.length+r.length+4}}if(k>b.length+2){l+=5
n="..."}else n=null
for(;;){if(!(l>80&&b.length>3))break
if(0>=b.length)return A.a(b,-1)
l-=b.pop().length+2
if(n==null){l+=5
n="..."}}if(n!=null)B.a.n(b,n)
B.a.n(b,r)
B.a.n(b,s)},
fO(a,b,c,d,e){return new A.aG(a,b.h("@<0>").u(c).u(d).u(e).h("aG<1,2,3,4>"))},
fe(a,b,c,d){var t
if(B.d===c){t=J.W(a)
b=J.W(b)
return A.fg(A.ax(A.ax($.f4(),t),b))}if(B.d===d){t=J.W(a)
b=J.W(b)
c=J.W(c)
return A.fg(A.ax(A.ax(A.ax($.f4(),t),b),c))}t=J.W(a)
b=J.W(b)
c=J.W(c)
d=J.W(d)
d=A.fg(A.ax(A.ax(A.ax(A.ax($.f4(),t),b),c),d))
return d},
af:function af(a,b,c){this.a=a
this.b=b
this.c=c},
dv:function dv(){},
dw:function dw(){},
N:function N(a){this.a=a},
eJ:function eJ(){},
u:function u(){},
c0:function c0(a){this.a=a},
bI:function bI(){},
ae:function ae(a,b,c,d){var _=this
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
cf:function cf(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
bK:function bK(a){this.a=a},
bE:function bE(a){this.a=a},
c5:function c5(a){this.a=a},
cq:function cq(){},
bD:function bD(){},
eK:function eK(a){this.a=a},
a1:function a1(a,b){this.a=a
this.b=b},
c:function c(){},
F:function F(a,b,c){this.a=a
this.b=b
this.$ti=c},
aK:function aK(){},
m:function m(){},
b2:function b2(a){this.a=a},
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
de:function de(){},
df:function df(){},
d_:function d_(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cZ:function cZ(a){this.a=a},
d0:function d0(){},
d1:function d1(a){this.a=a},
d4:function d4(a){this.a=a},
d5:function d5(){},
d8:function d8(){},
d9:function d9(a,b){this.a=a
this.b=b},
d7:function d7(a){this.a=a},
da:function da(){},
db:function db(){},
d3:function d3(a){this.a=a},
d2:function d2(a){this.a=a},
dc:function dc(){},
dd:function dd(){},
d6:function d6(a){this.a=a},
aA:function aA(a,b){this.a=a
this.b=b},
ac:function ac(a,b,c){this.a=a
this.b=b
this.c=c},
dg:function dg(a,b,c,d){var _=this
_.a=a
_.f=b
_.r=c
_.z=d},
cX:function cX(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
C:function C(a,b,c,d,e,f,g,h,i,j,k,l,m){var _=this
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
U:function U(a,b){this.a=a
this.b=b},
dU:function dU(a,b){this.a=a
this.b=b},
dV:function dV(){},
dX:function dX(){},
dW:function dW(){},
ch:function ch(){},
ea:function ea(){},
dY:function dY(){},
dZ:function dZ(){},
bg:function bg(a,b){this.a=a
this.b=b},
E:function E(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
au:function au(a,b){this.b=a
this.c=b},
cb:function cb(a,b,c,d,e,f,g,h,i,j){var _=this
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
fD(a){var t
if(a.gar()){t=a.r
t=isFinite(t)&&t>=0&&t<=30}else t=!1
return t},
bh(a,b){var t,s=b.c.U(a.c),r=!1
if(A.fD(a))if(A.fD(b))if(!b.y)if(b.z===0){t=s.a
if(t>=2e5)if(t<=15e6){r=b.w
r=isFinite(r)&&r>=0}}return r},
hU(a){var t,s,r,q=A.n([],u.ab)
for(t=0;s=a.length,t<s;++t){if(t!==0){r=t-1
if(!(r>=0))return A.a(a,r)
r=A.bh(a[r],a[t])
s=r}else s=!0
r=a.length
if(s){if(!(t<r))return A.a(a,t)
q.push(a[t])}else{if(!(t<r))return A.a(a,t)
s=a[t]
q.push(new A.C(s.a,s.b,s.c,s.d,s.e,s.f,s.r,0,0,!0,s.z,s.Q,!1))}}return q},
e0(a,b,c){var t,s,r,q
for(t=a+1;t<=b;++t){s=t-1
r=!0
if(A.bh(c.$1(s),c.$1(t))){s=c.$1(s)
q=s.Q
if(q!=="unavailable"&&q!=="held_estimate"){s=s.d
s=isFinite(s)&&s>=0&&s<=70}else s=!1
if(s){s=c.$1(t)
r=s.Q
if(r!=="unavailable"&&r!=="held_estimate"){s=s.d
s=isFinite(s)&&s>=0&&s<=70}else s=!1
s=!s}else s=r}else s=r
if(s)return!1}return!0},
hV(a7,a8){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3=a8.i(0,"startedAtMicros"),a4=a8.i(0,"stopRequestedAtMicros"),a5=A.bY(a3)&&A.bY(a4)&&a4>a3,a6=A.fb(u.S)
for(t=u.dC,s=0,r=0,q=0,p=0,o=0,n=!1,m=0,l=0,k=!0,j=1;j<a7.length;++j){i=j-1
h=a7[i]
g=a7[j]
f=g.c
e=h.c
d=f.a
c=e.a
if(d<=c)b=d===c&&f.b>e.b
else b=!0
if(!b)k=!1
if(A.bh(h,g))if(a5)b=1000*c+e.b<a3||1000*d+f.b>a4
else b=!1
else b=!0
a=0
a0=!1
if(b){n=a0
o=a
continue}a1=A.A(f.b-e.b,d-c).a
s+=a1
f=g.w
m+=f
e=h.Q
d=e!=="unavailable"
if(d&&e!=="held_estimate"){c=h.d
c=isFinite(c)&&c>=0&&c<=70}else c=!1
if(c){c=g.Q
if(c!=="unavailable"&&c!=="held_estimate"){c=g.d
c=isFinite(c)&&c>=0&&c<=70}else c=!1
c=c&&h.d>1.5&&g.d>1.5}else c=!1
if(c){r+=a1
l+=f
a6.E(0,A.n([i,j],t))}if(d&&e!=="held_estimate"){i=h.d
i=isFinite(i)&&i>=0&&i<=70}else i=!1
if(i){i=g.Q
if(i!=="unavailable"&&i!=="held_estimate"){i=g.d
i=isFinite(i)&&i>=0&&i<=70}else i=!1
i=i&&h.d<=1.5&&g.d<=1.5}else i=!1
if(i){q+=a1
o+=a1
if(!n&&o>=3e6){++p
n=!0}}else{n=a0
o=a}}a2=a5&&k&&s<=a4-a3?a4-a3:null
return new A.e_(a2,s,r,a6.a)},
e_:function e_(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.e=d},
fE(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s){return new A.k(h,d,s,o,e,q,g,p,f,i,k,c,a,r,n,m,b,l,j)},
a6:function a6(a,b){this.a=a
this.b=b},
b3:function b3(a,b){this.a=a
this.b=b},
aH:function aH(a,b){this.a=a
this.b=b},
av:function av(a,b){this.a=a
this.b=b},
Q:function Q(a,b){this.a=a
this.b=b},
T:function T(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.d=c
_.e=d
_.f=e
_.r=f},
an:function an(a,b,c){this.a=a
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
c9:function c9(a,b,c,d){var _=this
_.a=a
_.c=b
_.d=c
_.r=d},
dy:function dy(a){this.a=a},
e1:function e1(){},
e2:function e2(){},
e4:function e4(){},
e3:function e3(a){this.a=a},
e5:function e5(){},
e6:function e6(){},
e7:function e7(){},
e8:function e8(){},
cd:function cd(a,b,c){this.a=a
this.f=b
this.r=c},
cc:function cc(a,b,c){this.a=a
this.b=b
this.c=c},
c_:function c_(a,b,c){this.a=a
this.e=b
this.f=c},
a7:function a7(a,b){this.a=a
this.b=b},
a0:function a0(a,b){this.a=a
this.e=b},
cx:function cx(a,b,c){this.a=a
this.e=b
this.f=c},
jl(){var t,s=new A.f0()
if(typeof s=="function")A.aC(A.f6("Attempting to rewrap a JS function."))
t=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.iC,s)
t[$.fs()]=s
v.G.driveItPlanetDetailScore=t},
f0:function f0(){},
i5(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=A.I(a.i(0,"schema_version"))
if(e!==1&&e!==2)throw A.d(A.bl("Unsupported source schema version: "+e,null))
t=A.eW(a.i(0,"score_calculation_mode"))
s=A.fk(a.i(0,"score_calculation_version"))
r=u.fF.a(a.i(0,"telemetry_reliability"))
r=r==null?null:r.O(0,u.N,u.z)
q=A.J(a.i(0,"publish_id"))
p=A.J(a.i(0,"local_drive_id"))
o=A.I(a.i(0,"telemetry_version"))
n=A.I(a.i(0,"drive_score_algorithm_version"))
m=A.I(a.i(0,"world_rules_version"))
l=A.du(A.J(a.i(0,"started_at")))
k=A.du(A.J(a.i(0,"ended_at")))
j=A.z(a.i(0,"recorded_distance_meters"))
i=u.j
h=u.p
g=J.f5(i.a(a.i(0,"raw_route")),new A.en(),h)
g=A.D(g,g.$ti.h("r.E"))
f=u.A
i=J.f5(i.a(a.i(0,"canonical_telemetry")),new A.eo(),f)
i=A.D(i,i.$ti.h("r.E"))
h=A.a9(g,h)
f=A.a9(i,f)
t=new A.em(t,s,r==null?null:A.f7(r,u.N,u.z),e,q,p,o,n,m,l,k,j,h,f)
t.c1()
return t},
aa:function aa(a,b,c){this.a=a
this.b=b
this.c=c},
X:function X(a,b,c,d,e,f,g,h,i,j,k,l,m){var _=this
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
em:function em(a,b,c,d,e,f,g,h,i,j,k,l,m,n){var _=this
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
er:function er(){},
es:function es(a,b){this.a=a
this.b=b},
ep:function ep(){},
eq:function eq(){},
en:function en(){},
eo:function eo(){},
j7(a){var t,s,r,q,p,o=A.i5(a)
if(o.d!==2)throw A.d(B.ah)
t=o.at
s=A.i(t)
r=s.h("h<1,C>")
t=A.D(new A.h(t,s.h("C(1)").a(new A.eY()),r),r.h("r.E"))
t.$flags=1
q=t
for(p=0;p<q.length;++p){t=J.bb(J.bb(a.i(0,"canonical_telemetry"),p),"timestamp_micros")
if(!(p<q.length))return A.a(q,p)
s=q[p].c
if(!J.Z(t,B.c.j(1000*s.a+s.b)))throw A.d(B.al)}t=B.t.bM(q)
s=o.c
s.toString
s=A.hV(q,s)
r=s.a
return new A.bQ(r!=null&&r>0&&s.b*5>=r*4&&s.e>=6&&s.c>=9e7,t)},
eY:function eY(){},
ev:function ev(){},
eU:function eU(a,b){this.a=a
this.b=b},
bH:function bH(a,b,c){this.a=a
this.r=b
this.as=c},
bG:function bG(a){this.a=a},
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
jo(a){var t=J.f5(a,new A.f3(),u.u)
t=A.D(t,t.$ti.h("r.E"))
return t},
hs(a){var t,s=u.N,r=u.z,q=A.a8(s,r)
q.m(0,"totalScore",a.d)
q.m(0,"displayScore",a.f)
q.m(0,"algorithmVersion",a.r)
t=a.a
if(t==="reliable_intervals")q.E(0,A.bu(["calculationMode",t,"calculationVersion",a.b,"reliabilityPolicyVersion",a.c],s,r))
q.m(0,"overallConfidence",a.e)
r=u.h6
q.m(0,"categories",a.w.a4(0,new A.f1(),s,r))
q.m(0,"contributions",a.x.a4(0,new A.f2(),s,r))
return q},
f3:function f3(){},
f1:function f1(){},
f2:function f2(){},
jp(a){throw A.G(new A.cp("Field '"+a+"' has been assigned during initialization."),new Error())},
iC(a,b,c){u.Z.a(a)
if(A.I(c)>=1)return a.$1(b)
return a.$0()},
hq(a,b,c){A.j8(c,u.H,"T","max")
return Math.max(c.a(a),c.a(b))}},B={}
var w=[A,J,B]
var $={}
A.f9.prototype={}
J.ci.prototype={
M(a,b){return a===b},
gB(a){return A.cs(a)},
j(a){return"Instance of '"+A.ct(a)+"'"},
gX(a){return A.ar(A.fl(this))}}
J.ck.prototype={
j(a){return String(a)},
gB(a){return a?519018:218159},
gX(a){return A.ar(u.y)},
$iao:1,
$ij:1}
J.bn.prototype={
M(a,b){return null==b},
j(a){return"null"},
gB(a){return 0},
$iao:1}
J.b0.prototype={$ib_:1}
J.aw.prototype={
gB(a){return 0},
j(a){return String(a)}}
J.el.prototype={}
J.ay.prototype={}
J.bo.prototype={
j(a){var t=a[$.hu()]
if(t==null)t=a[$.fs()]
if(t==null)return this.b1(a)
return"JavaScript function for "+J.bc(t)},
$iai:1}
J.l.prototype={
n(a,b){A.i(a).c.a(b)
a.$flags&1&&A.cH(a,29)
a.push(b)},
E(a,b){var t
A.i(a).h("c<1>").a(b)
a.$flags&1&&A.cH(a,"addAll",2)
for(t=b.gt(b);t.p();)a.push(t.gq())},
aU(a,b,c){var t=A.i(a)
return new A.h(a,t.u(c).h("1(2)").a(b),t.h("@<1>").u(c).h("h<1,2>"))},
bZ(a,b){var t,s=A.bx(a.length,"",!1,u.N)
for(t=0;t<a.length;++t)this.m(s,t,A.v(a[t]))
return s.join(b)},
N(a,b){return A.eu(a,b,null,A.i(a).c)},
L(a,b){var t,s,r
A.i(a).h("1(1,1)").a(b)
t=a.length
if(t===0)throw A.d(A.aY())
if(0>=t)return A.a(a,0)
s=a[0]
for(r=1;r<t;++r){s=b.$2(s,a[r])
if(t!==a.length)throw A.d(A.P(a))}return s},
J(a,b,c,d){var t,s,r
d.a(b)
A.i(a).u(d).h("1(1,2)").a(c)
t=a.length
for(s=b,r=0;r<t;++r){s=c.$2(s,a[r])
if(a.length!==t)throw A.d(A.P(a))}return s},
F(a,b){if(!(b>=0&&b<a.length))return A.a(a,b)
return a[b]},
a7(a,b,c){if(b<0||b>a.length)throw A.d(A.ab(b,0,a.length,"start",null))
if(c<b||c>a.length)throw A.d(A.ab(c,b,a.length,"end",null))
if(b===c)return A.n([],A.i(a))
return A.n(a.slice(b,c),A.i(a))},
gW(a){if(a.length>0)return a[0]
throw A.d(A.aY())},
gab(a){var t=a.length
if(t>0)return a[t-1]
throw A.d(A.aY())},
az(a,b,c,d,e){var t,s,r,q,p
A.i(a).h("c<1>").a(d)
a.$flags&2&&A.cH(a,5)
A.fY(b,c,a.length)
t=c-b
if(t===0)return
A.al(e,"skipCount")
if(u.j.b(d)){s=d
r=e}else{s=J.fv(d,e).aW(0,!1)
r=0}q=J.cF(s)
if(r+t>q.gl(s))throw A.d(A.hW())
if(r<b)for(p=t-1;p>=0;--p)a[b+p]=q.i(s,r+p)
else for(p=0;p<t;++p)a[b+p]=q.i(s,r+p)},
R(a,b){var t,s
A.i(a).h("j(1)").a(b)
t=a.length
for(s=0;s<t;++s){if(b.$1(a[s]))return!0
if(a.length!==t)throw A.d(A.P(a))}return!1},
aA(a,b){var t,s,r,q,p,o=A.i(a)
o.h("K(1,1)?").a(b)
a.$flags&2&&A.cH(a,"sort")
t=a.length
if(t<2)return
if(b==null)b=J.iM()
if(t===2){s=a[0]
r=a[1]
o=b.$2(s,r)
if(typeof o!=="number")return o.c5()
if(o>0){a[0]=r
a[1]=s}return}q=0
if(o.c.b(null))for(p=0;p<a.length;++p)if(a[p]===void 0){a[p]=null;++q}a.sort(A.j9(b,2))
if(q>0)this.bt(a,q)},
b0(a){return this.aA(a,null)},
bt(a,b){var t,s=a.length
for(;t=s-1,s>0;s=t)if(a[t]===null){a[t]=void 0;--b
if(b===0)break}},
a_(a,b){var t
for(t=0;t<a.length;++t)if(J.Z(a[t],b))return!0
return!1},
gv(a){return a.length===0},
gC(a){return a.length!==0},
j(a){return A.f8(a,"[","]")},
gt(a){return new J.aE(a,a.length,A.i(a).h("aE<1>"))},
gB(a){return A.cs(a)},
gl(a){return a.length},
i(a,b){A.I(b)
if(!(b>=0&&b<a.length))throw A.d(A.f_(a,b))
return a[b]},
m(a,b,c){A.i(a).c.a(c)
a.$flags&2&&A.cH(a)
if(!(b>=0&&b<a.length))throw A.d(A.f_(a,b))
a[b]=c},
$io:1,
$ic:1,
$ix:1}
J.cj.prototype={
c0(a){var t,s,r
if(!Array.isArray(a))return null
t=a.$flags|0
if((t&4)!==0)s="const, "
else if((t&2)!==0)s="unmodifiable, "
else s=(t&1)!==0?"fixed, ":""
r="Instance of '"+A.ct(a)+"'"
if(s==="")return r
return r+" ("+s+"length: "+a.length+")"}}
J.ec.prototype={}
J.aE.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
p(){var t,s=this,r=s.a,q=r.length
if(s.b!==q){r=A.at(r)
throw A.d(r)}t=s.c
if(t>=q){s.d=null
return!1}s.d=r[t]
s.c=t+1
return!0},
$it:1}
J.aZ.prototype={
H(a,b){var t
A.z(b)
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){t=this.gaa(b)
if(this.gaa(a)===t)return 0
if(this.gaa(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gaa(a){return a===0?1/a<0:a<0},
aV(a){var t
if(a>=-2147483648&&a<=2147483647)return a|0
if(isFinite(a)){t=a<0?Math.ceil(a):Math.floor(a)
return t+0}throw A.d(A.eI(""+a+".toInt()"))},
ac(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.d(A.eI(""+a+".round()"))},
k(a,b,c){if(this.H(b,c)>0)throw A.d(A.j6(b))
if(this.H(a,b)<0)return b
if(this.H(a,c)>0)return c
return a},
aX(a,b){var t
if(b>20)throw A.d(A.ab(b,0,20,"fractionDigits",null))
t=a.toFixed(b)
if(a===0&&this.gaa(a))return"-"+t
return t},
j(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gB(a){var t,s,r,q,p=a|0
if(a===p)return p&536870911
t=Math.abs(a)
s=Math.log(t)/0.6931471805599453|0
r=Math.pow(2,s)
q=t<1?t/r:r/t
return((q*9007199254740992|0)+(q*3542243181176521|0))*599197+s*1259&536870911},
a6(a,b){var t=a%b
if(t===0)return 0
if(t>0)return t
return t+b},
A(a,b){return(a|0)===a?a/b|0:this.bC(a,b)},
bC(a,b){var t=a/b
if(t>=-2147483648&&t<=2147483647)return t|0
if(t>0){if(t!==1/0)return Math.floor(t)}else if(t>-1/0)return Math.ceil(t)
throw A.d(A.eI("Result of truncating division is "+A.v(t)+": "+A.v(a)+" ~/ "+b))},
aO(a,b){var t
if(a>0)t=this.by(a,b)
else{t=b>31?31:b
t=a>>t>>>0}return t},
by(a,b){return b>31?0:a>>>b},
gX(a){return A.ar(u.H)},
$iR:1,
$ib:1,
$iL:1}
J.bm.prototype={
gX(a){return A.ar(u.S)},
$iao:1,
$iK:1}
J.cl.prototype={
gX(a){return A.ar(u.i)},
$iao:1}
J.aI.prototype={
a0(a,b,c){return a.substring(b,A.fY(b,c,a.length))},
aw(a,b){var t,s
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.d(B.R)
for(t=a,s="";;){if((b&1)===1)s=t+s
b=b>>>1
if(b===0)break
t+=t}return s},
c_(a,b,c){var t=b-a.length
if(t<=0)return a
return this.aw(c,t)+a},
H(a,b){var t
A.J(b)
if(a===b)t=0
else t=a<b?-1:1
return t},
j(a){return a},
gB(a){var t,s,r
for(t=a.length,s=0,r=0;r<t;++r){s=s+a.charCodeAt(r)&536870911
s=s+((s&524287)<<10)&536870911
s^=s>>6}s=s+((s&67108863)<<3)&536870911
s^=s>>11
return s+((s&16383)<<15)&536870911},
gX(a){return A.ar(u.N)},
gl(a){return a.length},
i(a,b){A.I(b)
if(b>=a.length)throw A.d(A.f_(a,b))
return a[b]},
$iao:1,
$iR:1,
$ie:1}
A.b4.prototype={
gt(a){return new A.bd(J.ad(this.gZ()),A.f(this).h("bd<1,2>"))},
gl(a){return J.aD(this.gZ())},
gv(a){return J.fu(this.gZ())},
gC(a){return J.hI(this.gZ())},
N(a,b){var t=A.f(this)
return A.dh(J.fv(this.gZ(),b),t.c,t.y[1])},
j(a){return J.bc(this.gZ())}}
A.bd.prototype={
p(){return this.a.p()},
gq(){return this.$ti.y[1].a(this.a.gq())},
$it:1}
A.aF.prototype={
gZ(){return this.a}}
A.bL.prototype={$io:1}
A.aG.prototype={
O(a,b,c){return new A.aG(this.a,this.$ti.h("@<1,2>").u(b).u(c).h("aG<1,2,3,4>"))},
i(a,b){return this.$ti.h("4?").a(this.a.i(0,b))},
G(a,b){this.a.G(0,new A.di(this,this.$ti.h("~(3,4)").a(b)))},
gD(){var t=this.$ti
return A.dh(this.a.gD(),t.c,t.y[2])},
gS(){var t=this.$ti
return A.dh(this.a.gS(),t.y[1],t.y[3])},
gl(a){var t=this.a
return t.gl(t)},
gv(a){var t=this.a
return t.gv(t)},
gC(a){var t=this.a
return t.gC(t)}}
A.di.prototype={
$2(a,b){var t=this.a.$ti
t.c.a(a)
t.y[1].a(b)
this.b.$2(t.y[2].a(a),t.y[3].a(b))},
$S(){return this.a.$ti.h("~(1,2)")}}
A.cp.prototype={
j(a){return"LateInitializationError: "+this.a}}
A.et.prototype={}
A.o.prototype={}
A.r.prototype={
gt(a){var t=this
return new A.bv(t,t.gl(t),A.f(t).h("bv<r.E>"))},
gv(a){return this.gl(this)===0},
R(a,b){var t,s,r=this
A.f(r).h("j(r.E)").a(b)
t=r.gl(r)
for(s=0;s<t;++s){if(b.$1(r.F(0,s)))return!0
if(t!==r.gl(r))throw A.d(A.P(r))}return!1},
L(a,b){var t,s,r,q=this
A.f(q).h("r.E(r.E,r.E)").a(b)
t=q.gl(q)
if(t===0)throw A.d(A.aY())
s=q.F(0,0)
for(r=1;r<t;++r){s=b.$2(s,q.F(0,r))
if(t!==q.gl(q))throw A.d(A.P(q))}return s},
N(a,b){return A.eu(this,b,null,A.f(this).h("r.E"))}}
A.bF.prototype={
gbd(){var t=J.aD(this.a),s=this.c
if(s==null||s>t)return t
return s},
gbz(){var t=J.aD(this.a),s=this.b
if(s>t)return t
return s},
gl(a){var t,s=J.aD(this.a),r=this.b
if(r>=s)return 0
t=this.c
if(t==null||t>=s)return s-r
return t-r},
F(a,b){var t=this,s=t.gbz()+b
if(b<0||s>=t.gbd())throw A.d(A.e9(b,t.gl(0),t,null,"index"))
return J.ft(t.a,s)},
N(a,b){var t,s,r=this
A.al(b,"count")
t=r.b+b
s=r.c
if(s!=null&&t>=s)return new A.bj(r.$ti.h("bj<1>"))
return A.eu(r.a,t,s,r.$ti.c)},
aW(a,b){var t,s,r,q=this,p=q.b,o=q.a,n=J.cF(o),m=n.gl(o),l=q.c
if(l!=null&&l<m)m=l
t=m-p
if(t<=0){o=J.fH(0,q.$ti.c)
return o}s=A.bx(t,n.F(o,p),!1,q.$ti.c)
for(r=1;r<t;++r){B.a.m(s,r,n.F(o,p+r))
if(n.gl(o)<m)throw A.d(A.P(q))}return s}}
A.bv.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
p(){var t,s=this,r=s.a,q=r.gl(r)
if(s.b!==q)throw A.d(A.P(r))
t=s.c
if(t>=q){s.d=null
return!1}s.d=r.F(0,t);++s.c
return!0},
$it:1}
A.ak.prototype={
gt(a){return new A.by(J.ad(this.a),this.b,A.f(this).h("by<1,2>"))},
gl(a){return J.aD(this.a)},
gv(a){return J.fu(this.a)}}
A.bi.prototype={$io:1}
A.by.prototype={
p(){var t=this,s=t.b
if(s.p()){t.a=t.c.$1(s.gq())
return!0}t.a=null
return!1},
gq(){var t=this.a
return t==null?this.$ti.y[1].a(t):t},
$it:1}
A.h.prototype={
gl(a){return J.aD(this.a)},
F(a,b){return this.b.$1(J.ft(this.a,b))}}
A.y.prototype={
gt(a){return new A.a4(J.ad(this.a),this.b,this.$ti.h("a4<1>"))}}
A.a4.prototype={
p(){var t,s
for(t=this.a,s=this.b;t.p();)if(s.$1(t.gq()))return!0
return!1},
gq(){return this.a.gq()},
$it:1}
A.am.prototype={
N(a,b){A.cW(b,"count",u.S)
A.al(b,"count")
return new A.am(this.a,this.b+b,A.f(this).h("am<1>"))},
gt(a){var t=this.a
return new A.bC(t.gt(t),this.b,A.f(this).h("bC<1>"))}}
A.aW.prototype={
gl(a){var t=this.a,s=t.gl(t)-this.b
if(s>=0)return s
return 0},
N(a,b){A.cW(b,"count",u.S)
A.al(b,"count")
return new A.aW(this.a,this.b+b,this.$ti)},
$io:1}
A.bC.prototype={
p(){var t,s
for(t=this.a,s=0;s<this.b;++s)t.p()
this.b=0
return t.p()},
gq(){return this.a.gq()},
$it:1}
A.bj.prototype={
gt(a){return B.O},
gv(a){return!0},
gl(a){return 0},
N(a,b){A.al(b,"count")
return this}}
A.bk.prototype={
p(){return!1},
gq(){throw A.d(A.aY())},
$it:1}
A.bQ.prototype={$r:"+eligible,result(1,2)",$s:1}
A.bf.prototype={}
A.be.prototype={
O(a,b,c){var t=A.f(this)
return A.fO(this,t.c,t.y[1],b,c)},
gv(a){return this.gl(this)===0},
gC(a){return this.gl(this)!==0},
j(a){return A.fd(this)},
a4(a,b,c,d){var t=A.a8(c,d)
this.G(0,new A.dj(this,A.f(this).u(c).u(d).h("F<1,2>(3,4)").a(b),t))
return t},
$iq:1}
A.dj.prototype={
$2(a,b){var t=A.f(this.a),s=this.b.$2(t.c.a(a),t.y[1].a(b))
this.c.m(0,s.a,s.b)},
$S(){return A.f(this.a).h("~(1,2)")}}
A.a_.prototype={
gl(a){return this.b.length},
gaJ(){var t=this.$keys
if(t==null){t=Object.keys(this.a)
this.$keys=t}return t},
bO(a){if(typeof a!="string")return!1
if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
i(a,b){if(!this.bO(b))return null
return this.b[this.a[b]]},
G(a,b){var t,s,r,q
this.$ti.h("~(1,2)").a(b)
t=this.gaJ()
s=this.b
for(r=t.length,q=0;q<r;++q)b.$2(t[q],s[q])},
gD(){return new A.aO(this.gaJ(),this.$ti.h("aO<1>"))},
gS(){return new A.aO(this.b,this.$ti.h("aO<2>"))}}
A.aO.prototype={
gl(a){return this.a.length},
gv(a){return 0===this.a.length},
gC(a){return 0!==this.a.length},
gt(a){var t=this.a
return new A.bM(t,t.length,this.$ti.h("bM<1>"))}}
A.bM.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
p(){var t=this,s=t.c
if(s>=t.b){t.d=null
return!1}t.d=t.a[s]
t.c=s+1
return!0},
$it:1}
A.cg.prototype={
M(a,b){if(b==null)return!1
return b instanceof A.aX&&this.a.M(0,b.a)&&A.fp(this)===A.fp(b)},
gB(a){return A.fe(this.a,A.fp(this),B.d,B.d)},
j(a){var t=B.a.bZ([A.ar(this.$ti.c)],", ")
return this.a.j(0)+" with "+("<"+t+">")}}
A.aX.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.jk(A.eZ(this.a),this.$ti)}}
A.bB.prototype={}
A.eG.prototype={
K(a){var t,s,r=this,q=new RegExp(r.a).exec(a)
if(q==null)return null
t=Object.create(null)
s=r.b
if(s!==-1)t.arguments=q[s+1]
s=r.c
if(s!==-1)t.argumentsExpr=q[s+1]
s=r.d
if(s!==-1)t.expr=q[s+1]
s=r.e
if(s!==-1)t.method=q[s+1]
s=r.f
if(s!==-1)t.receiver=q[s+1]
return t}}
A.bz.prototype={
j(a){return"Null check operator used on a null value"}}
A.cn.prototype={
j(a){var t,s=this,r="NoSuchMethodError: method not found: '",q=s.b
if(q==null)return"NoSuchMethodError: "+s.a
t=s.c
if(t==null)return r+q+"' ("+s.a+")"
return r+q+"' on '"+t+"' ("+s.a+")"}}
A.cy.prototype={
j(a){var t=this.a
return t.length===0?"Error":"Error: "+t}}
A.ek.prototype={
j(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.M.prototype={
j(a){var t=this.constructor,s=t==null?null:t.name
return"Closure '"+A.ht(s==null?"unknown":s)+"'"},
$iai:1,
gc4(){return this},
$C:"$1",
$R:1,
$D:null}
A.c2.prototype={$C:"$0",$R:0}
A.c3.prototype={$C:"$2",$R:2}
A.cw.prototype={}
A.cv.prototype={
j(a){var t=this.$static_name
if(t==null)return"Closure of unknown static method"
return"Closure '"+A.ht(t)+"'"}}
A.aV.prototype={
M(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.aV))return!1
return this.$_target===b.$_target&&this.a===b.a},
gB(a){return(A.hr(this.a)^A.cs(this.$_target))>>>0},
j(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.ct(this.a)+"'")}}
A.cu.prototype={
j(a){return"RuntimeError: "+this.a}}
A.aj.prototype={
gl(a){return this.a},
gv(a){return this.a===0},
gC(a){return this.a!==0},
gD(){return new A.aJ(this,A.f(this).h("aJ<1>"))},
gS(){return new A.a2(this,A.f(this).h("a2<2>"))},
E(a,b){A.f(this).h("q<1,2>").a(b).G(0,new A.ed(this))},
i(a,b){var t,s,r,q,p=null
if(typeof b=="string"){t=this.b
if(t==null)return p
s=t[b]
r=s==null?p:s.b
return r}else if(typeof b=="number"&&(b&0x3fffffff)===b){q=this.c
if(q==null)return p
s=q[b]
r=s==null?p:s.b
return r}else return this.bV(b)},
bV(a){var t,s,r=this.d
if(r==null)return null
t=r[this.aS(a)]
s=this.aT(t,a)
if(s<0)return null
return t[s].b},
m(a,b,c){var t,s,r=this,q=A.f(r)
q.c.a(b)
q.y[1].a(c)
if(typeof b=="string"){t=r.b
r.aB(t==null?r.b=r.am():t,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){s=r.c
r.aB(s==null?r.c=r.am():s,b,c)}else r.bW(b,c)},
bW(a,b){var t,s,r,q,p=this,o=A.f(p)
o.c.a(a)
o.y[1].a(b)
t=p.d
if(t==null)t=p.d=p.am()
s=p.aS(a)
r=t[s]
if(r==null)t[s]=[p.an(a,b)]
else{q=p.aT(r,a)
if(q>=0)r[q].b=b
else r.push(p.an(a,b))}},
G(a,b){var t,s,r=this
A.f(r).h("~(1,2)").a(b)
t=r.e
s=r.r
while(t!=null){b.$2(t.a,t.b)
if(s!==r.r)throw A.d(A.P(r))
t=t.c}},
aB(a,b,c){var t,s=A.f(this)
s.c.a(b)
s.y[1].a(c)
t=a[b]
if(t==null)a[b]=this.an(b,c)
else t.b=c},
an(a,b){var t=this,s=A.f(t),r=new A.eh(s.c.a(a),s.y[1].a(b))
if(t.e==null)t.e=t.f=r
else t.f=t.f.c=r;++t.a
t.r=t.r+1&1073741823
return r},
aS(a){return J.W(a)&1073741823},
aT(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.Z(a[s].a,b))return s
return-1},
j(a){return A.fd(this)},
am(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
$ifJ:1}
A.ed.prototype={
$2(a,b){var t=this.a,s=A.f(t)
t.m(0,s.c.a(a),s.y[1].a(b))},
$S(){return A.f(this.a).h("~(1,2)")}}
A.eh.prototype={}
A.aJ.prototype={
gl(a){return this.a.a},
gv(a){return this.a.a===0},
gt(a){var t=this.a
return new A.bs(t,t.r,t.e,this.$ti.h("bs<1>"))}}
A.bs.prototype={
gq(){return this.d},
p(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.d(A.P(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=t.a
s.c=t.c
return!0}},
$it:1}
A.a2.prototype={
gl(a){return this.a.a},
gv(a){return this.a.a===0},
gt(a){var t=this.a
return new A.bt(t,t.r,t.e,this.$ti.h("bt<1>"))}}
A.bt.prototype={
gq(){return this.d},
p(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.d(A.P(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=t.b
s.c=t.c
return!0}},
$it:1}
A.bq.prototype={
gl(a){return this.a.a},
gv(a){return this.a.a===0},
gt(a){var t=this.a
return new A.br(t,t.r,t.e,this.$ti.h("br<1,2>"))}}
A.br.prototype={
gq(){var t=this.d
t.toString
return t},
p(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.d(A.P(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=new A.F(t.a,t.b,s.$ti.h("F<1,2>"))
s.c=t.c
return!0}},
$it:1}
A.aR.prototype={
j(a){return this.aQ(!1)},
aQ(a){var t,s,r,q,p,o=this.be(),n=this.aG(),m=(a?"Record ":"")+"("
for(t=o.length,s="",r=0;r<t;++r,s=", "){m+=s
q=o[r]
if(typeof q=="string")m=m+q+": "
if(!(r<n.length))return A.a(n,r)
p=n[r]
m=a?m+A.fX(p):m+A.v(p)}m+=")"
return m.charCodeAt(0)==0?m:m},
be(){var t,s=this.$s
while($.eQ.length<=s)B.a.n($.eQ,null)
t=$.eQ[s]
if(t==null){t=this.b7()
B.a.m($.eQ,s,t)}return t},
b7(){var t,s,r,q=this.$r,p=q.indexOf("("),o=q.substring(1,p),n=q.substring(p),m=n==="()"?0:n.replace(/[^,]/g,"").length+1,l=u.C,k=J.fG(m,l)
for(t=0;t<m;++t)k[t]=t
if(o!==""){s=o.split(",")
t=s.length
for(r=m;t>0;){--r;--t
B.a.m(k,r,s[t])}}return A.a9(k,l)}}
A.b5.prototype={
aG(){return[this.a,this.b]},
M(a,b){if(b==null)return!1
return b instanceof A.b5&&this.$s===b.$s&&J.Z(this.a,b.a)&&J.Z(this.b,b.b)},
gB(a){return A.fe(this.$s,this.a,this.b,B.d)}}
A.cm.prototype={
j(a){return"RegExp/"+this.a+"/"+this.b.flags},
bT(a){var t=this.b.exec(a)
if(t==null)return null
return new A.eP(t)},
$ii7:1}
A.eP.prototype={
i(a,b){var t
A.I(b)
t=this.b
if(!(b<t.length))return A.a(t,b)
return t[b]}}
A.a3.prototype={
h(a){return A.bV(v.typeUniverse,this,a)},
u(a){return A.hc(v.typeUniverse,this,a)}}
A.cA.prototype={}
A.eR.prototype={
j(a){return A.O(this.a,null)}}
A.cz.prototype={
j(a){return this.a}}
A.b6.prototype={}
A.aq.prototype={
gt(a){var t=this,s=new A.aP(t,t.r,A.f(t).h("aP<1>"))
s.c=t.e
return s},
gl(a){return this.a},
gv(a){return this.a===0},
gC(a){return this.a!==0},
a_(a,b){var t,s
if(typeof b=="string"&&b!=="__proto__"){t=this.b
if(t==null)return!1
return u.M.a(t[b])!=null}else{s=this.b8(b)
return s}},
b8(a){var t=this.d
if(t==null)return!1
return this.aF(t[this.aE(a)],a)>=0},
n(a,b){var t,s,r=this
A.f(r).c.a(b)
if(typeof b=="string"&&b!=="__proto__"){t=r.b
return r.aD(t==null?r.b=A.fh():t,b)}else if(typeof b=="number"&&(b&1073741823)===b){s=r.c
return r.aD(s==null?r.c=A.fh():s,b)}else return r.b3(b)},
b3(a){var t,s,r,q=this
A.f(q).c.a(a)
t=q.d
if(t==null)t=q.d=A.fh()
s=q.aE(a)
r=t[s]
if(r==null)t[s]=[q.ag(a)]
else{if(q.aF(r,a)>=0)return!1
r.push(q.ag(a))}return!0},
aD(a,b){A.f(this).c.a(b)
if(u.M.a(a[b])!=null)return!1
a[b]=this.ag(b)
return!0},
ag(a){var t=this,s=new A.cD(A.f(t).c.a(a))
if(t.e==null)t.e=t.f=s
else t.f=t.f.b=s;++t.a
t.r=t.r+1&1073741823
return s},
aE(a){return J.W(a)&1073741823},
aF(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.Z(a[s].a,b))return s
return-1},
$ifM:1}
A.cD.prototype={}
A.aP.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
p(){var t=this,s=t.c,r=t.a
if(t.b!==r.r)throw A.d(A.P(r))
else if(s==null){t.d=null
return!1}else{t.d=t.$ti.h("1?").a(s.a)
t.c=s.b
return!0}},
$it:1}
A.ei.prototype={
$2(a,b){this.a.m(0,this.b.a(a),this.c.a(b))},
$S:15}
A.w.prototype={
O(a,b,c){var t=A.f(this)
return A.fO(this,t.h("w.K"),t.h("w.V"),b,c)},
G(a,b){var t,s,r,q=A.f(this)
q.h("~(w.K,w.V)").a(b)
for(t=this.gD(),t=t.gt(t),q=q.h("w.V");t.p();){s=t.gq()
r=this.i(0,s)
b.$2(s,r==null?q.a(r):r)}},
a4(a,b,c,d){var t,s,r,q,p,o=A.f(this)
o.u(c).u(d).h("F<1,2>(w.K,w.V)").a(b)
t=A.a8(c,d)
for(s=this.gD(),s=s.gt(s),o=o.h("w.V");s.p();){r=s.gq()
q=this.i(0,r)
p=b.$2(r,q==null?o.a(q):q)
t.m(0,p.a,p.b)}return t},
gl(a){var t=this.gD()
return t.gl(t)},
gv(a){var t=this.gD()
return t.gv(t)},
gC(a){var t=this.gD()
return t.gC(t)},
gS(){return new A.bO(this,A.f(this).h("bO<w.K,w.V>"))},
j(a){return A.fd(this)},
$iq:1}
A.ej.prototype={
$2(a,b){var t,s=this.a
if(!s.a)this.b.a+=", "
s.a=!1
s=this.b
t=A.v(a)
s.a=(s.a+=t)+": "
t=A.v(b)
s.a+=t},
$S:12}
A.bO.prototype={
gl(a){var t=this.a
return t.gl(t)},
gv(a){var t=this.a
return t.gv(t)},
gC(a){var t=this.a
return t.gC(t)},
gt(a){var t=this.a,s=t.gD()
return new A.bP(s.gt(s),t,this.$ti.h("bP<1,2>"))}}
A.bP.prototype={
p(){var t=this,s=t.a
if(s.p()){t.c=t.b.i(0,s.gq())
return!0}t.c=null
return!1},
gq(){var t=this.c
return t==null?this.$ti.y[1].a(t):t},
$it:1}
A.bW.prototype={}
A.b1.prototype={
O(a,b,c){return this.a.O(0,b,c)},
i(a,b){return this.a.i(0,b)},
G(a,b){this.a.G(0,A.f(this).h("~(1,2)").a(b))},
gv(a){var t=this.a
return t.gv(t)},
gl(a){var t=this.a
return t.gl(t)},
gD(){return this.a.gD()},
j(a){return this.a.j(0)},
gS(){return this.a.gS()},
a4(a,b,c,d){return this.a.a4(0,A.f(this).u(c).u(d).h("F<1,2>(3,4)").a(b),c,d)},
$iq:1}
A.aN.prototype={
O(a,b,c){return new A.aN(this.a.O(0,b,c),b.h("@<0>").u(c).h("aN<1,2>"))}}
A.bw.prototype={
gt(a){var t=this
return new A.bN(t,t.c,t.d,t.b,t.$ti.h("bN<1>"))},
gv(a){return this.b===this.c},
gl(a){return(this.c-this.b&this.a.length-1)>>>0},
F(a,b){var t,s,r=this,q=r.gl(0)
if(0>b||b>=q)A.aC(A.e9(b,q,r,null,"index"))
q=r.a
t=q.length
s=(r.b+b&t-1)>>>0
if(!(s>=0&&s<t))return A.a(q,s)
s=q[s]
return s==null?r.$ti.c.a(s):s},
bN(a){var t=this,s=t.b
if(s!==t.c){for(;s!==t.c;s=(s+1&t.a.length-1)>>>0)B.a.m(t.a,s,null)
t.b=t.c=0;++t.d}},
j(a){return A.f8(this,"{","}")}}
A.bN.prototype={
gq(){var t=this.e
return t==null?this.$ti.c.a(t):t},
p(){var t,s,r=this,q=r.a
if(r.c!==q.d)A.aC(A.P(q))
t=r.d
if(t===r.b){r.e=null
return!1}q=q.a
s=q.length
if(!(t<s))return A.a(q,t)
r.e=q[t]
r.d=(t+1&s-1)>>>0
return!0},
$it:1}
A.aM.prototype={
gv(a){return this.gl(this)===0},
gC(a){return this.gl(this)!==0},
E(a,b){var t
for(t=J.ad(A.f(this).h("c<1>").a(b));t.p();)this.n(0,t.gq())},
j(a){return A.f8(this,"{","}")},
N(a,b){return A.h_(this,b,A.f(this).c)},
$io:1,
$ic:1,
$iaL:1}
A.bR.prototype={}
A.cE.prototype={
n(a,b){this.$ti.c.a(b)
return A.iw()}}
A.bJ.prototype={
a_(a,b){return this.a.a_(0,b)},
gl(a){return this.a.a},
gt(a){var t=this.a
return A.id(t,t.r,A.f(t).c)}}
A.b7.prototype={}
A.bX.prototype={}
A.cB.prototype={
i(a,b){var t,s=this.b
if(s==null)return this.c.i(0,b)
else if(typeof b!="string")return null
else{t=s[b]
return typeof t=="undefined"?this.bq(b):t}},
gl(a){return this.b==null?this.c.a:this.a1().length},
gv(a){return this.gl(0)===0},
gC(a){return this.gl(0)>0},
gD(){if(this.b==null){var t=this.c
return new A.aJ(t,A.f(t).h("aJ<1>"))}return new A.cC(this)},
gS(){var t,s=this
if(s.b==null){t=s.c
return new A.a2(t,A.f(t).h("a2<2>"))}return A.fP(s.a1(),new A.eL(s),u.N,u.z)},
G(a,b){var t,s,r,q,p=this
u.cA.a(b)
if(p.b==null)return p.c.G(0,b)
t=p.a1()
for(s=0;s<t.length;++s){r=t[s]
q=p.b[r]
if(typeof q=="undefined"){q=A.eX(p.a[r])
p.b[r]=q}b.$2(r,q)
if(t!==p.c)throw A.d(A.P(p))}},
a1(){var t=u.bM.a(this.c)
if(t==null)t=this.c=A.n(Object.keys(this.a),u.s)
return t},
bq(a){var t
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
t=A.eX(this.a[a])
return this.b[a]=t}}
A.eL.prototype={
$1(a){return this.a.i(0,A.J(a))},
$S:16}
A.cC.prototype={
gl(a){return this.a.gl(0)},
F(a,b){var t=this.a
if(t.b==null)t=t.gD().F(0,b)
else{t=t.a1()
if(!(b>=0&&b<t.length))return A.a(t,b)
t=t[b]}return t},
gt(a){var t=this.a
if(t.b==null){t=t.gD()
t=t.gt(t)}else{t=t.a1()
t=new J.aE(t,t.length,A.i(t).h("aE<1>"))}return t}}
A.c4.prototype={}
A.c6.prototype={}
A.bp.prototype={
j(a){var t=A.ce(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+t}}
A.co.prototype={
j(a){return"Cyclic error in JSON stringify"}}
A.ee.prototype={
bP(a,b){var t=A.iZ(a,this.gbQ().a)
return t},
aR(a,b){var t=A.ic(a,this.gbR().b,null)
return t},
gbR(){return B.ap},
gbQ(){return B.ao}}
A.eg.prototype={}
A.ef.prototype={}
A.eN.prototype={
aZ(a){var t,s,r,q,p,o,n=a.length
for(t=this.c,s=0,r=0;r<n;++r){q=a.charCodeAt(r)
if(q>92){if(q>=55296){p=q&64512
if(p===55296){o=r+1
o=!(o<n&&(a.charCodeAt(o)&64512)===56320)}else o=!1
if(!o)if(p===56320){p=r-1
p=!(p>=0&&(a.charCodeAt(p)&64512)===55296)}else p=!1
else p=!0
if(p){if(r>s)t.a+=B.e.a0(a,s,r)
s=r+1
p=A.H(92)
t.a+=p
p=A.H(117)
t.a+=p
p=A.H(100)
t.a+=p
p=q>>>8&15
p=A.H(p<10?48+p:87+p)
t.a+=p
p=q>>>4&15
p=A.H(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.H(p<10?48+p:87+p)
t.a+=p}}continue}if(q<32){if(r>s)t.a+=B.e.a0(a,s,r)
s=r+1
p=A.H(92)
t.a+=p
switch(q){case 8:p=A.H(98)
t.a+=p
break
case 9:p=A.H(116)
t.a+=p
break
case 10:p=A.H(110)
t.a+=p
break
case 12:p=A.H(102)
t.a+=p
break
case 13:p=A.H(114)
t.a+=p
break
default:p=A.H(117)
t.a+=p
p=A.H(48)
t.a=(t.a+=p)+p
p=q>>>4&15
p=A.H(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.H(p<10?48+p:87+p)
t.a+=p
break}}else if(q===34||q===92){if(r>s)t.a+=B.e.a0(a,s,r)
s=r+1
p=A.H(92)
t.a+=p
p=A.H(q)
t.a+=p}}if(s===0)t.a+=a
else if(s<n)t.a+=B.e.a0(a,s,n)},
af(a){var t,s,r,q
for(t=this.a,s=t.length,r=0;r<s;++r){q=t[r]
if(a==null?q==null:a===q)throw A.d(new A.co(a,null))}B.a.n(t,a)},
ae(a){var t,s,r,q,p=this
if(p.aY(a))return
p.af(a)
try{t=p.b.$1(a)
if(!p.aY(t)){r=A.fI(a,null,p.gaM())
throw A.d(r)}r=p.a
if(0>=r.length)return A.a(r,-1)
r.pop()}catch(q){s=A.fr(q)
r=A.fI(a,s,p.gaM())
throw A.d(r)}},
aY(a){var t,s,r=this
if(typeof a=="number"){if(!isFinite(a))return!1
r.c.a+=B.b.j(a)
return!0}else if(a===!0){r.c.a+="true"
return!0}else if(a===!1){r.c.a+="false"
return!0}else if(a==null){r.c.a+="null"
return!0}else if(typeof a=="string"){t=r.c
t.a+='"'
r.aZ(a)
t.a+='"'
return!0}else if(u.j.b(a)){r.af(a)
r.c2(a)
t=r.a
if(0>=t.length)return A.a(t,-1)
t.pop()
return!0}else if(u.G.b(a)){r.af(a)
s=r.c3(a)
t=r.a
if(0>=t.length)return A.a(t,-1)
t.pop()
return s}else return!1},
c2(a){var t,s,r=this.c
r.a+="["
t=J.b9(a)
if(t.gC(a)){this.ae(t.i(a,0))
for(s=1;s<t.gl(a);++s){r.a+=","
this.ae(t.i(a,s))}}r.a+="]"},
c3(a){var t,s,r,q,p,o,n=this,m={}
if(a.gv(a)){n.c.a+="{}"
return!0}t=a.gl(a)*2
s=A.bx(t,null,!1,u.U)
r=m.a=0
m.b=!0
a.G(0,new A.eO(m,s))
if(!m.b)return!1
q=n.c
q.a+="{"
for(p='"';r<t;r+=2,p=',"'){q.a+=p
n.aZ(A.J(s[r]))
q.a+='":'
o=r+1
if(!(o<t))return A.a(s,o)
n.ae(s[o])}q.a+="}"
return!0}}
A.eO.prototype={
$2(a,b){var t,s
if(typeof a!="string")this.a.b=!1
t=this.b
s=this.a
B.a.m(t,s.a++,a)
B.a.m(t,s.a++,b)},
$S:12}
A.eM.prototype={
gaM(){var t=this.c.a
return t.charCodeAt(0)==0?t:t}}
A.af.prototype={
T(a){var t=1000,s=B.c.a6(a,t),r=B.c.A(a-s,t),q=this.b+s,p=B.c.a6(q,t),o=this.c
return new A.af(A.fC(this.a+B.c.A(q-p,t)+r,p,o),p,o)},
U(a){return A.A(this.b-a.b,this.a-a.a)},
M(a,b){if(b==null)return!1
return b instanceof A.af&&this.a===b.a&&this.b===b.b&&this.c===b.c},
gB(a){return A.fe(this.a,this.b,B.d,B.d)},
bY(a){var t=this.a,s=a.a
if(t>=s)t=t===s&&this.b<a.b
else t=!0
return t},
bX(a){var t=this.a,s=a.a
if(t<=s)t=t===s&&this.b>a.b
else t=!0
return t},
H(a,b){var t
u.x.a(b)
t=B.c.H(this.a,b.a)
if(t!==0)return t
return B.c.H(this.b,b.b)},
ad(){var t=this
if(t.c)return t
return new A.af(t.a,t.b,!0)},
j(a){var t=this,s=A.fB(A.cr(t)),r=A.ag(A.fV(t)),q=A.ag(A.fR(t)),p=A.ag(A.fS(t)),o=A.ag(A.fU(t)),n=A.ag(A.fW(t)),m=A.dt(A.fT(t)),l=t.b,k=l===0?"":A.dt(l)
l=s+"-"+r
if(t.c)return l+"-"+q+" "+p+":"+o+":"+n+"."+m+k+"Z"
else return l+"-"+q+" "+p+":"+o+":"+n+"."+m+k},
av(){var t=this,s=A.cr(t)>=-9999&&A.cr(t)<=9999?A.fB(A.cr(t)):A.hT(A.cr(t)),r=A.ag(A.fV(t)),q=A.ag(A.fR(t)),p=A.ag(A.fS(t)),o=A.ag(A.fU(t)),n=A.ag(A.fW(t)),m=A.dt(A.fT(t)),l=t.b,k=l===0?"":A.dt(l)
l=s+"-"+r
if(t.c)return l+"-"+q+"T"+p+":"+o+":"+n+"."+m+k+"Z"
else return l+"-"+q+"T"+p+":"+o+":"+n+"."+m+k},
$iR:1}
A.dv.prototype={
$1(a){if(a==null)return 0
return A.cG(a)},
$S:13}
A.dw.prototype={
$1(a){var t,s,r
if(a==null)return 0
for(t=a.length,s=0,r=0;r<6;++r){s*=10
if(r<t){if(!(r<t))return A.a(a,r)
s+=a.charCodeAt(r)^48}}return s},
$S:13}
A.N.prototype={
M(a,b){if(b==null)return!1
return b instanceof A.N&&this.a===b.a},
gB(a){return B.c.gB(this.a)},
H(a,b){return B.c.H(this.a,u.fu.a(b).a)},
j(a){var t,s,r,q,p,o=this.a,n=B.c.A(o,36e8),m=o%36e8
if(o<0){n=0-n
o=0-m
t="-"}else{o=m
t=""}s=B.c.A(o,6e7)
o%=6e7
r=s<10?"0":""
q=B.c.A(o,1e6)
p=q<10?"0":""
return t+n+":"+r+s+":"+p+q+"."+B.e.c_(B.c.j(o%1e6),6,"0")},
$iR:1}
A.eJ.prototype={
j(a){return this.P()}}
A.u.prototype={}
A.c0.prototype={
j(a){var t=this.a
if(t!=null)return"Assertion failed: "+A.ce(t)
return"Assertion failed"}}
A.bI.prototype={}
A.ae.prototype={
gaj(){return"Invalid argument"+(!this.a?"(s)":"")},
gai(){return""},
j(a){var t=this,s=t.c,r=s==null?"":" ("+s+")",q=t.d,p=q==null?"":": "+q,o=t.gaj()+r+p
if(!t.a)return o
return o+t.gai()+": "+A.ce(t.gau())},
gau(){return this.b}}
A.bA.prototype={
gau(){return A.hf(this.b)},
gaj(){return"RangeError"},
gai(){var t,s=this.e,r=this.f
if(s==null)t=r!=null?": Not less than or equal to "+A.v(r):""
else if(r==null)t=": Not greater than or equal to "+A.v(s)
else if(r>s)t=": Not in inclusive range "+A.v(s)+".."+A.v(r)
else t=r<s?": Valid value range is empty":": Only valid value is "+A.v(s)
return t}}
A.cf.prototype={
gau(){return A.I(this.b)},
gaj(){return"RangeError"},
gai(){if(A.I(this.b)<0)return": index must not be negative"
var t=this.f
if(t===0)return": no indices are valid"
return": index should be less than "+t},
gl(a){return this.f}}
A.bK.prototype={
j(a){return"Unsupported operation: "+this.a}}
A.bE.prototype={
j(a){return"Bad state: "+this.a}}
A.c5.prototype={
j(a){var t=this.a
if(t==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.ce(t)+"."}}
A.cq.prototype={
j(a){return"Out of Memory"},
$iu:1}
A.bD.prototype={
j(a){return"Stack Overflow"},
$iu:1}
A.eK.prototype={
j(a){return"Exception: "+this.a}}
A.a1.prototype={
j(a){var t=this.a,s=""!==t?"FormatException: "+t:"FormatException",r=this.b
if(typeof r=="string"){if(r.length>78)r=B.e.a0(r,0,75)+"..."
return s+"\n"+r}else return s}}
A.c.prototype={
aU(a,b,c){var t=A.f(this)
return A.fP(this,t.u(c).h("1(c.E)").a(b),t.h("c.E"),c)},
J(a,b,c,d){var t,s
d.a(b)
A.f(this).u(d).h("1(1,c.E)").a(c)
for(t=this.gt(this),s=b;t.p();)s=c.$2(s,t.gq())
return s},
aW(a,b){var t=A.f(this).h("c.E")
if(b)t=A.D(this,t)
else{t=A.D(this,t)
t.$flags=1
t=t}return t},
gl(a){var t,s=this.gt(this)
for(t=0;s.p();)++t
return t},
gv(a){return!this.gt(this).p()},
gC(a){return!this.gv(this)},
N(a,b){return A.h_(this,b,A.f(this).h("c.E"))},
bU(a,b,c){var t,s=A.f(this)
s.h("j(c.E)").a(b)
s.h("c.E()?").a(c)
for(s=this.gt(this);s.p();){t=s.gq()
if(b.$1(t))return t}s=c.$0()
return s},
F(a,b){var t,s
A.al(b,"index")
t=this.gt(this)
for(s=b;t.p();){if(s===0)return t.gq();--s}throw A.d(A.e9(b,b-s,this,null,"index"))},
j(a){return A.hX(this,"(",")")}}
A.F.prototype={
j(a){return"MapEntry("+A.v(this.a)+": "+A.v(this.b)+")"}}
A.aK.prototype={
gB(a){return A.m.prototype.gB.call(this,0)},
j(a){return"null"}}
A.m.prototype={$im:1,
M(a,b){return this===b},
gB(a){return A.cs(this)},
j(a){return"Instance of '"+A.ct(this)+"'"},
gX(a){return A.jh(this)},
toString(){return this.j(this)}}
A.b2.prototype={
gl(a){return this.a.length},
j(a){var t=this.a
return t.charCodeAt(0)==0?t:t},
$iia:1}
A.cJ.prototype={
I(a){var t,s,r,q,p,o,n=A.n([],u.g)
for(t=a.V(B.h),s=J.ad(t.a),t=new A.a4(s,t.b,t.$ti.h("a4<1>")),r=0;t.p();){q=s.gq()
p=q.at
o=Math.max(p.c,p.d)
p=!0
if(q.ax===B.p)if(!(q.x-q.w<4))p=o>=0.65&&q.y<12
if(p)++r
else B.a.n(n,q)}if(n.length===0)return new A.c_(0,!1,!1)
t=new A.cR(n)
return new A.c_(t.$1(new A.cT(this))*25+t.$1(new A.cU(this,a))*15+t.$1(new A.cV(this,a))*10,!0,n.length>=2)},
b2(a,b){var t=B.a.a7(a.c,b.d,b.e+1),s=A.i(t),r=s.h("h<1,b>"),q=A.D(new A.h(t,s.h("b(1)").a(new A.cK()),r),r.h("r.E"))
return B.a.J(q,0,new A.cL(B.a.L(q,new A.cM())/q.length),u.i)/q.length},
bv(a,b){var t=a.c,s=A.i(t),r=s.h("ak<1,b>"),q=A.D(new A.ak(new A.y(t,s.h("j(1)").a(new A.cN(b,b.r.T(4e6))),s.h("y<1>")),s.h("b(1)").a(new A.cO()),r),r.h("c.E"))
if(q.length<2)return 0
return 1-B.b.k(Math.sqrt(B.a.J(q,0,new A.cP(B.a.L(q,new A.cQ())/q.length),u.i)/q.length)/3,0,1)}}
A.cR.prototype={
$1(a){var t=this.a,s=A.i(t)
return new A.h(t,s.h("b(1)").a(u.bE.a(a)),s.h("h<1,b>")).L(0,new A.cS())/t.length},
$S:20}
A.cS.prototype={
$2(a,b){return A.p(a)+A.p(b)},
$S:0}
A.cT.prototype={
$1(a){u.F.a(a)
return B.b.k((a.x-a.w)/B.c.A(a.r.U(a.f).a,1000)*1000/2.5,0,1)},
$S:8}
A.cU.prototype={
$1(a){return 1-B.b.k(this.a.b2(this.b,u.F.a(a))/0.55,0,1)},
$S:8}
A.cV.prototype={
$1(a){return this.a.bv(this.b,u.F.a(a))},
$S:8}
A.cK.prototype={
$1(a){return u.K.a(a).e},
$S:3}
A.cM.prototype={
$2(a,b){return A.p(a)+A.p(b)},
$S:0}
A.cL.prototype={
$2(a,b){var t
A.p(a)
t=A.p(b)-this.a
return a+t*t},
$S:0}
A.cN.prototype={
$1(a){u.K.a(a)
return a.a>this.a.e&&!a.b.c.bX(this.b)},
$S:1}
A.cO.prototype={
$1(a){return u.K.a(a).b.d},
$S:3}
A.cQ.prototype={
$2(a,b){return A.p(a)+A.p(b)},
$S:0}
A.cP.prototype={
$2(a,b){var t
A.p(a)
t=A.p(b)-this.a
return a+t*t},
$S:0}
A.cY.prototype={
I(b3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9=this,b0=b3.V(B.k),b1=b0.$ti,b2=b1.h("y<c.E>")
b0=A.D(new A.y(b0,b1.h("j(c.E)").a(new A.de()),b2),b2.h("c.E"))
b0.$flags=1
t=b0
b0=b3.V(B.x)
b0=A.D(b0,b0.$ti.h("c.E"))
b0.$flags=1
s=b0
b0=b3.V(B.f)
b0=A.D(b0,b0.$ti.h("c.E"))
b0.$flags=1
r=b0
q=A.n([],u.aS)
b0=u.n
p=A.n([],b0)
o=A.fb(u.N)
for(b1=t.length,n=0,m=0,l=0,k=0;k<t.length;t.length===b1||(0,A.at)(t),++k){j=t[k]
if(!(j.as<=0)){b2=j.r
i=j.f
i=A.A(b2.b-i.b,b2.a-i.a).a<=0
b2=i}else b2=!0
if(b2){++n
continue}h=a9.bh(j,r)
b2=j.at
g=B.b.k(1-Math.max(b2.c*0.25,b2.d*0.45),0,1)
if(g<1||h)++l
f=a9.aN(b3,j)
e=a9.bw(f)
if(f>=5){++m
o.n(0,j.a)}b2=h?0.6:1
B.a.n(p,e*g*b2)
B.a.n(q,new A.aA(a9.b5(b3,j,h),Math.max(1,j.w-j.x)))}d=q.length===0
c=d?150:150*a9.bI(q)
b=p.length===0
a=b?100:100*(1-a9.b4(p))
a0=a9.bg(b3,t)
a1=a0.length===0
a2=a9.bl(a0)
a3=a1?60:60*(1-a2)
b1=A.i(a0)
new A.y(a0,b1.h("j(1)").a(new A.df()),b1.h("y<1>")).gl(0)
a4=A.n([],b0)
for(b0=s.length,k=0;k<s.length;s.length===b0||(0,A.at)(s),++k){a5=a9.bA(b3,s[k],t,o)
if(a5==null)++n
else B.a.n(a4,a5)}a6=a4.length===0
a7=a6?40:40*a9.Y(a4)
a8=B.b.k(c+a+a3+a7,0,350)
B.b.k(c,0,150)
B.b.k(a,0,100)
B.b.k(a3,0,60)
B.b.k(a7,0,40)
return new A.dg(a8,t.length,a4.length,new A.cX(d,b,a1,a6))},
b5(a,b,a0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f=a.c,e=b.d,d=b.e,c=f.length
if(!(e<c))return A.a(f,e)
t=f[e].b.d
if(!(d<c))return A.a(f,d)
s=f[d].b.d
r=Math.max(0,t-s)
if(r<=0)return 0.5
q=this.aI(f,e,d,0.5)
p=this.aI(f,e,d,0.6)
if(!(q<c))return A.a(f,q)
o=Math.max(0,t-f[q].b.d)
if(!(p<c))return A.a(f,p)
n=Math.max(0,f[p].b.d-s)
m=B.b.k(o/r/0.55,0,1)
l=B.b.k((n/r-0.35)/0.37,0,1)
k=A.n([],u.n)
for(j=e;j<=d;++j){if(!(j<c))return A.a(f,j)
B.a.n(k,f[j].e)}c=B.b.k(this.aP(k)/0.9,0,1)
i=f[e].b.c.T(-5e6)
h=A.eu(f,0,A.hn(e,"count",u.S),A.i(f).c).R(0,new A.d_(i,a,e,f))?0.08:0
g=a0?0.1:0
return B.b.k(0.4*B.b.k(m+h+g,0,1)+0.3*(1-c)+0.3*(1-l),0,1)},
aN(a,b){var t,s,r,q,p,o
for(t=b.d,s=b.e,r=a.c,q=r.length,p=0;t<=s;++t){if(!(t<q))return A.a(r,t)
o=r[t]
p=Math.max(p,Math.max(-o.b.x,-o.e))}return p},
bw(a){var t=this
if(a<=1.5)return 0
if(a<=2.5)return t.a8(0,0.15,(a-1.5)/1)
if(a<=3.5)return t.a8(0.15,0.35,(a-2.5)/1)
if(a<=5)return t.a8(0.35,0.75,(a-3.5)/1.5)
return t.a8(0.75,1,(a-5)/5)},
b4(a){var t
u.o.a(a)
t=this.Y(a)
if(a.length===1)return Math.min(t,0.35)
return B.b.k(t*1.35,0,1)},
bg(a,a0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b
u.B.a(a0)
t=a.V(B.h)
s=t.$ti
r=s.h("y<c.E>")
t=A.D(new A.y(t,s.h("j(c.E)").a(new A.d0()),r),r.h("c.E"))
t.$flags=1
q=t
p=A.n([],u.h9)
for(t=q.length,s=a.a,o=0;o<q.length;q.length===t||(0,A.at)(q),++o){n=q[o]
m=n.x-n.w
if(m<3)continue
for(r=a0.length,l=n.r,k=l.a,l=l.b,j=n.y,i=n.e,h=0;h<a0.length;a0.length===r||(0,A.at)(a0),++h){g=a0[h]
f=g.f
e=f.a
if(e>=k)d=e===k&&f.b<l
else d=!0
if(d)continue
if(s&&!A.e0(i,g.d,new A.d1(a)))continue
c=A.A(f.b-l,e-k)
if(j<13.88888888888889)b=14
else b=j<25?10.5:7.5
if(c.a>A.A(0,B.b.ac(b*1000)).a)break
if(g.w-g.x<=0)continue
B.a.n(p,new A.ac(m,this.aN(a,g),this.bm(g.at)))
break}}return p},
bl(a){var t,s,r,q,p
u.cT.a(a)
if(a.length===0)return 0
t=A.i(a)
s=t.h("b(1)")
t=t.h("h<1,b>")
r=this.Y(new A.h(a,s.a(new A.d4(this)),t))
q=a.length
p=q===1?0.15:B.b.k(q/3,0.45,1)
return B.b.k(r*p*(1-this.Y(new A.h(a,s.a(new A.d5()),t))),0,1)},
bA(a,b,c,a0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=null
u.B.a(c)
u.cq.a(a0)
t=this.bf(a,b.d)
if(t==null)return d
s=a.c
r=b.e
q=B.a.a7(s,t,r+1)
p=A.i(q)
if(new A.h(q,p.h("b(1)").a(new A.d8()),p.h("h<1,b>")).L(0,B.G)<4.166666666666667)return d
q=A.i(c)
p=q.h("y<1>")
o=A.dh(new A.y(c,q.h("j(1)").a(new A.d9(b,a)),p),p.h("c.E"),u.r).bU(0,new A.da(),new A.db())
if(o!=null&&a0.a_(0,o.a))return d
q=s.length
if(t>>>0!==t||t>=q)return A.a(s,t)
p=s[t]
if(!(r<q))return A.a(s,r)
n=s[r].b
m=Math.max(0,p.b.d-n.d)
if(m<=0)return d
l=n.c.T(-2e6)
p=l.a
n=l.b
j=t
for(;;){if(!(j<=r)){k=t
break}if(!(j<q))return A.a(s,j)
i=s[j].b.c
h=i.a
if(h>=p)i=h===p&&i.b<n
else i=!0
if(!i){k=j
break}++j}if(!(k<q))return A.a(s,k)
g=1-B.b.k((Math.max(0,s[k].b.d-s[r].b.d)/m-0.25)/0.30000000000000004,0,1)
f=A.n([],u.n)
for(j=k;j<=r;++j){if(!(j<q))return A.a(s,j)
B.a.n(f,s[j].e)}e=1-B.b.k(this.aP(f)/0.8,0,1)
return B.b.k(0.5*g+0.25*e+0.25*B.b.k((g+e)/2,0,1),0,1)},
bf(a,b){var t,s,r,q,p,o
for(t=a.c,s=t.length,r=a.a,q=b;q>=0;--q){p=!1
if(r)if(q<b){if(!(q<s))return A.a(t,q)
p=t[q]
o=q+1
if(!(o<s))return A.a(t,o)
o=!A.bh(p.b,t[o].b)
p=o}if(p)break
if(!(q<s))return A.a(t,q)
if(t[q].b.d>=4.166666666666667)return q}return null},
bh(a,b){u.B.a(b)
return a.ch.a_(0,B.o)||B.a.R(a.CW,new A.d3(b))},
bm(a){var t=a.d,s=Math.max(a.c,t)
if(s<=0)return 0
return B.b.k(0.8*s+0.19999999999999996*t,0,1)},
aI(a,b,c,d){var t,s,r,q,p,o,n
u.X.a(a)
t=a.length
if(!(b<t))return A.a(a,b)
s=a[b].b.c
if(!(c<t))return A.a(a,c)
r=s.T(A.A(0,B.b.ac(B.c.A(a[c].b.c.U(s).a,1000)*d)).a)
for(s=r.a,q=r.b,p=b;p<=c;++p){if(!(p<t))return A.a(a,p)
o=a[p].b.c
n=o.a
if(n>=s)o=n===s&&o.b<q
else o=!0
if(!o)return p}return c},
bI(a){var t,s
u.ap.a(a)
t=u.i
s=B.a.J(a,0,new A.dc(),t)
if(s<=0)return 1
return B.a.J(a,0,new A.dd(),t)/s},
Y(a){var t,s,r
for(t=J.ad(u.l.a(a)),s=0,r=0;t.p();){s+=t.gq();++r}return r===0?0:s/r},
aP(a){var t
u.o.a(a)
if(a.length<2)return 0
t=A.i(a)
return Math.sqrt(this.Y(new A.h(a,t.h("b(1)").a(new A.d6(this.Y(a))),t.h("h<1,b>"))))},
a8(a,b,c){return a+(b-a)*B.b.k(c,0,1)}}
A.de.prototype={
$1(a){return u.F.a(a).ax===B.B},
$S:4}
A.df.prototype={
$1(a){return u.R.a(a).c>0},
$S:21}
A.d_.prototype={
$1(a){var t,s=this
u.K.a(a)
if(!a.b.c.bY(s.a))t=(!s.b.a||A.e0(a.a,s.c,new A.cZ(s.d)))&&a.e<-0.08
else t=!1
return t},
$S:1}
A.cZ.prototype={
$1(a){var t=this.a
if(!(a>=0&&a<t.length))return A.a(t,a)
return t[a].b},
$S:7}
A.d0.prototype={
$1(a){return u.F.a(a).ax===B.p},
$S:4}
A.d1.prototype={
$1(a){var t=this.a.c
if(!(a>=0&&a<t.length))return A.a(t,a)
return t[a].b},
$S:7}
A.d4.prototype={
$1(a){u.R.a(a)
return 0.6*B.b.k(a.a/9,0,1)+0.4*B.b.k(a.b/3.5,0,1)},
$S:11}
A.d5.prototype={
$1(a){return u.R.a(a).c},
$S:11}
A.d8.prototype={
$1(a){return u.K.a(a).b.d},
$S:3}
A.d9.prototype={
$1(a){var t,s,r,q
u.F.a(a)
t=this.a
s=t.f.U(a.r)
r=a.e
t=t.d
if(r<=t){q=this.b
t=(!q.a||A.e0(r,t,new A.d7(q)))&&Math.abs(s.a)<=3e6}else t=!1
return t},
$S:4}
A.d7.prototype={
$1(a){var t=this.a.c
if(!(a>=0&&a<t.length))return A.a(t,a)
return t[a].b},
$S:7}
A.da.prototype={
$1(a){return u.r.a(a)!=null},
$S:18}
A.db.prototype={
$0(){return null},
$S:25}
A.d3.prototype={
$1(a){return B.a.R(this.a,new A.d2(A.J(a)))},
$S:38}
A.d2.prototype={
$1(a){return u.F.a(a).a===this.a},
$S:4}
A.dc.prototype={
$2(a,b){return A.p(a)+u.E.a(b).b},
$S:9}
A.dd.prototype={
$2(a,b){A.p(a)
u.E.a(b)
return a+b.a*b.b},
$S:9}
A.d6.prototype={
$1(a){return Math.pow(A.p(a)-this.a,2)},
$S:17}
A.aA.prototype={}
A.ac.prototype={}
A.dg.prototype={}
A.cX.prototype={}
A.C.prototype={
gar(){var t,s=this.a
if(isFinite(s)){t=this.b
s=isFinite(t)&&Math.abs(s)<=90&&Math.abs(t)<=180}else s=!1
return s}}
A.c8.prototype={
I(a){var t,s,r,q,p,o,n=A.n([],u.v)
for(t=a.V(B.f),s=J.ad(t.a),t=new A.a4(s,t.b,t.$ti.h("a4<1>")),r=0,q=0;t.p();){p=s.gq()
o=this.b9(a,p)
if(o==null){++r
if(p.as<0.5)++q}else B.a.n(n,o)}if(n.length===0)return new A.c7(0,!1,!1)
t=new A.dq(this,n)
t=B.b.k(t.$1(new A.dl())*60+t.$1(new A.dm())*35+t.$1(new A.dn())*35+t.$1(new A.dp())*20,0,150)
s=n.length
A.a9(n,u.d)
return new A.c7(t,!0,s>=2)},
b9(a,a0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=this,b=null
if(a0.ax!==B.C||a0.as<0.5||a0.Q<15)return b
t=a0.cx
s=t.i(0,"totalHeadingChangeDegrees")
if(s==null)s=0
if(s<15)return b
r=a.c
t=t.i(0,"apexIndex")
q=a0.d
p=a0.e
o=B.c.aV(B.c.k(B.b.ac(t==null?(a0.d+a0.e)/2:t),q,p))
n=Math.max(q,q+B.c.A(o-q,2))
m=Math.min(p,o+B.c.A(p-o,2))
l=c.al(r,q,n)
k=c.al(r,Math.max(q,o-1),Math.min(p,o+1))
j=c.al(r,m,c.bs(r,p))
if(l<10)return b
t=a0.at
i=Math.max(t.c,t.d)
if(i>=0.6&&l<12)return b
h=s*3.141592653589793/180
g=h<=0?500:a0.Q/h
f=B.b.k(0.55*((s-15)/75)+0.45*((500-g)/475),0,1)
e=1-B.b.k((B.b.k((l-k)/l,0,1)-c.aK(0.08,0.48,f))/0.32,0,1)
if(i>0)e=c.aK(e,1,i*0.35)
t=B.b.k(c.aL(c.ap(r,q,o),l)/0.18,0,1)
d=B.b.k(B.b.k(j/l,0,1.1)/0.95,0,1)
p=B.b.k(c.aL(c.ap(r,q,p),l)/0.06,0,1)
A.a9(a0.CW,u.N)
return new A.a5(s,f,a0.as,e,1-t,d,1-p)},
bs(a,b){var t,s,r,q,p,o,n,m,l
u.X.a(a)
t=a.length
if(!(b<t))return A.a(a,b)
s=a[b].b.c.T(3e6)
for(r=b+1,q=s.a,p=s.b,o=b;r<t;n=r+1,o=r,r=n){m=a[r].b.c
l=m.a
if(l<=q)m=l===q&&m.b>p
else m=!0
if(m)break}return o},
ap(a,b,c){var t,s,r
u.X.a(a)
t=A.n([],u.n)
for(s=a.length,r=b;r<=c;++r){if(!(r>=0&&r<s))return A.a(a,r)
t.push(a[r].b.d)}return t},
al(a,b,c){var t,s,r,q=this.ap(u.X.a(a),b,c)
B.a.b0(q)
t=q.length
s=t/2|0
if((t&1)===1){if(!(s<t))return A.a(q,s)
t=q[s]}else{r=s-1
if(!(r>=0&&r<t))return A.a(q,r)
r=q[r]
if(!(s<t))return A.a(q,s)
r=(r+q[s])/2
t=r}return t},
aL(a,b){var t,s,r,q,p,o
u.o.a(a)
if(a.length<2||b<=0)return 0
t=B.a.L(a,new A.dk())
s=a.length
r=t/s
for(q=0,p=0;p<s;++p){o=a[p]-r
q+=o*o}return Math.sqrt(q/s)/b},
bH(a){u.d.a(a)
return Math.min(1.5,Math.max(0.25,a.w*(0.5+a.r)*(a.e/30)))},
aK(a,b,c){return a+(b-a)*B.b.k(c,0,1)}}
A.dq.prototype={
$1(a){var t,s,r,q,p,o,n,m,l
u.bk.a(a)
t=this.b
s=A.i(t)
r=s.h("h<1,b>")
s=A.D(new A.h(t,s.h("b(1)").a(this.a.gbG()),r),r.h("r.E"))
s.$flags=1
q=s
s=u.i
p=B.a.J(q,0,new A.dr(),s)
o=t.length
n=J.fG(o,s)
for(m=0;m<o;++m){if(!(m<t.length))return A.a(t,m)
r=a.$1(t[m])
if(!(m<q.length))return A.a(q,m)
l=q[m]
if(typeof r!=="number")return r.aw()
n[m]=r*l}return B.a.J(n,0,new A.ds(),s)/p},
$S:19}
A.dr.prototype={
$2(a,b){return A.p(a)+A.p(b)},
$S:0}
A.ds.prototype={
$2(a,b){return A.p(a)+A.p(b)},
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
$2(a,b){return A.p(a)+A.p(b)},
$S:0}
A.c7.prototype={}
A.a5.prototype={}
A.dx.prototype={
bS(b3,b4){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2=null
u.Y.a(b3)
if(b3.length===0)return B.E
t=u.I
s=new A.bw(A.bx(A.i2(b2),b2,!1,t),u.d9)
r=A.n([],u.W)
for(q=0,p=0,o=0,n=0,m=0,l=0,k=0;k<b3.length;++k){j=b3[k]
i=!1
if(b4)if(!j.y){h=j.Q
if(h!=="unavailable"&&h!=="held_estimate"){if(k>0){i=b3[k-1].Q
i=!(i!=="unavailable"&&i!=="held_estimate")}}else i=!0}else i=!0
if(i){s.bN(0)
q=0
p=0
o=0
n=0
m=0
l=0}B.a.m(s.a,s.c,k)
i=s.c
h=s.a.length
i=(i+1&h-1)>>>0
s.c=i
if(s.b===i){g=A.bx(h*2,b2,!1,t)
i=s.a
h=s.b
f=i.length-h
B.a.az(g,0,f,i,h)
B.a.az(g,f,f+s.b,s.a,0)
s.b=0
s.c=s.a.length
s.a=g}++s.d
i=j.d
q+=i
p+=i*i
if(i<=8.333333333333334)++o
h=j.c
e=h.T(-5e6)
d=e.a
c=e.b
for(;;){b=s.c
a=s.b
a0=s.a
a1=a0.length
if((b-a&a1-1)>>>0>1){if(a===b)A.aC(A.aY())
if(!(a<a1))return A.a(a0,a)
b=a0[a]
b=B.a.i(b3,b==null?A.I(b):b).c
a=b.a
if(a>=d)b=a===d&&b.b<c
else b=!0}else b=!1
if(!b)break
b=s.b
if(b===s.c)A.aC(A.aY());++s.d
a=s.a
if(!(b<a.length))return A.a(a,b)
a2=a[b]
if(a2==null)a2=A.I(a2)
B.a.m(a,b,b2)
s.b=(s.b+1&s.a.length-1)>>>0
b=B.a.i(b3,a2).d
q-=b
p-=b*b
if(b<=8.333333333333334)--o}a3=(s.c-s.b&s.a.length-1)>>>0
a4=q/a3
a5=B.b.k(p/a3-a4*a4,0,1/0)
d=j.as
if(!d||j.y)n=0
else{c=j.x
n=k===0?c:n+0.35*(c-n)}a6=0
a7=0
if(k>0){c=k-1
if(!(c<b3.length))return A.a(b3,c)
a8=b3[c]
c=a8.c
a9=A.A(h.b-c.b,h.a-c.a).a/1e6
h=!j.y
b0=0
b1=0
if(!h||!d){l=b1
m=b0}else if(a9>0)if(i<=1.3888888888888888){m+=a9
l=b1}else{l+=a9
m=b0}if(a9>0&&h&&d&&i>=4){a6=this.bx(a8.e,j.e)
a7=Math.abs(a6)/a9}}B.a.n(r,new A.T(k,j,a5,n,a6,a7))}return r},
bx(a,b){if(!isFinite(a)||!isFinite(b))return 0
return B.b.a6(b-a+540,360)-180}}
A.ca.prototype={
bK(a,b,c){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=this
u.t.a(c)
t=J.eb(c.slice(0),A.i(c).c)
s=B.K.bS(b?A.hU(t):t,b)
if(s.length===0)return new A.c9(b,B.E,B.aC,B.aD)
r=e.bc(s)
q=e.a2(s,new A.dA(),new A.dB(),B.a2,new A.dC(e,s))
p=e.a2(s,new A.dM(),new A.dN(),B.A,new A.dO(s))
o=e.a2(s,new A.dP(),new A.dQ(),B.A,new A.dR(s))
n=e.gbi()
m=e.a2(s,n,n,B.a4,new A.dS())
l=e.a2(s,new A.dT(),new A.dD(),B.a1,new A.dE(e,s))
k=A.bx(s.length,B.y,!1,u.fR)
e.a9(k,m,B.X)
e.a9(k,p,B.W)
e.a9(k,o,B.Y)
e.a9(k,q,B.z)
n=A.i(q)
j=u.F
n=A.D(new A.h(q,n.h("k(1)").a(new A.dF(e,a,s,r)),n.h("h<1,k>")),j)
i=A.i(p)
B.a.E(n,new A.h(p,i.h("k(1)").a(new A.dG(e,a,s,r)),i.h("h<1,k>")))
i=A.i(o)
B.a.E(n,new A.h(o,i.h("k(1)").a(new A.dH(e,a,s,r)),i.h("h<1,k>")))
i=A.i(l)
B.a.E(n,new A.h(l,i.h("k(1)").a(new A.dI(e,a,s,r)),i.h("h<1,k>")))
h=A.i(m)
B.a.E(n,new A.h(m,h.h("k(1)").a(new A.dJ(e,a,s,r)),h.h("h<1,k>")))
B.a.aA(n,new A.dK())
h=A.a9(s,u.K)
g=u.gE
f=A.a9(e.b6(k,s,b),g)
A.a9(new A.h(l,i.h("@(1)").a(new A.dL(s)),i.h("h<1,@>")),g)
A.a9(r,u.fo)
return new A.c9(b,h,f,A.a9(e.bu(n),j))},
bj(a){return a.b.d>=5&&Math.abs(a.e)<=0.3&&a.d<=1.5},
a2(a,b,c,d,e){var t,s,r,q,p,o,n,m,l,k=null
u.X.a(a)
t=u.d1
t.a(c)
t.a(b)
u._.a(e)
s=A.n([],u.dO)
for(r=k,q=r,p=0;p<a.length;++p){o=a[p]
t=o.b
if(!t.y){n=t.Q
n=!(n!=="unavailable"&&n!=="held_estimate")}else n=!0
m=k
l=k
if(n){if(q!=null&&r!=null)this.ak(s,a,q,r,d,e)
n=t.Q
if(!(n!=="unavailable"&&n!=="held_estimate")){r=l
q=m
continue}r=l
q=m}if(q==null){if(c.$1(o)){r=p
q=r}continue}if(b.$1(o)){r=p
continue}t=t.c
r.toString
if(!(r<a.length))return A.a(a,r)
n=a[r].b.c
if(A.A(t.b-n.b,t.a-n.a).a<=1e6)continue
this.ak(s,a,q,r,d,e)
q=c.$1(o)?p:k
r=q}if(q!=null&&r!=null)this.ak(s,a,q,r,d,e)
return s},
ak(a,b,c,d,e,f){var t,s,r
u.e.a(a)
u.X.a(b)
A.I(d)
u._.a(f)
t=new A.U(c,d)
s=b.length
if(!(d<s))return A.a(b,d)
r=b[d]
if(!(c<s))return A.a(b,c)
if(r.b.c.U(b[c].b.c).a>=e.a&&f.$1(t))B.a.n(a,t)},
bc(b3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2
u.X.a(b3)
t=A.n([],u.gI)
for(s=0,r=0;r<b3.length;++r){q=b3[r].b
p=q.Q
if(!(p!=="unavailable"&&p!=="held_estimate")){B.a.n(t,B.F)
s=r+1
continue}if(q.y)s=r
o=q.c.T(-45e6)
q=o.a
p=b3.length
n=o.b
for(;;){if(s<r){if(!(s>=0&&s<p))return A.a(b3,s)
m=b3[s].b.c
l=m.a
if(l>=q)m=l===q&&m.b<n
else m=!0}else m=!1
if(!m)break;++s}if(!(r<p))return A.a(b3,r)
q=b3[r].b.c
if(!(s>=0&&s<p))return A.a(b3,s)
n=b3[s].b.c
if(A.A(q.b-n.b,q.a-n.a).a<8e6){B.a.n(t,B.F)
continue}for(k=s,j=0,i=0,h=0,g=0,f=0,e=0,d=!1,c=0;k<=r;++k,d=a0){if(!(k<p))return A.a(b3,k)
b=b3[k]
a=b.b.d
j+=a
i+=a*a
if(a<=8.333333333333334)++h
a0=a<=1.3888888888888888
if(a0)++g
if(k>s&&a0!==d)++f
a1=b.e
if(a1>=0.35)a2=1
else a2=a1<=-0.35?-1:0
q=a2!==0
if(q&&c!==0&&a2!==c)++e
if(q)c=a2}a3=r-s+1
a4=j/a3
a5=Math.max(0,i/a3-a4*a4)
a6=h/a3
a7=B.b.k(1-a4/8.333333333333334,0,1)
a8=B.b.k(a5/25,0,1)
a9=B.b.k(f/4,0,1)
b0=B.b.k(e/4,0,1)
b1=B.b.k(a6*0.45+a7*0.35+a8*0.2,0,1)
b2=B.b.k(a6*0.3+g/a3*0.25+a9*0.25+b0*0.2,0,1)
if(b2>=0.62)B.a.n(t,new A.an(B.aM,b1,b2))
else if(b1>=0.55)B.a.n(t,new A.an(B.aL,b1,b2))
else{B.b.k(1-Math.max(b1,b2),0,1)
B.a.n(t,new A.an(B.aK,b1,b2))}}return t},
a3(a,b,c,a0,a1){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this
u.X.a(a0)
u.dr.a(a1)
for(t=c.a,s=c.b,r=a0.length,q=t,p=0,o=1/0;q<=s;++q){if(!(q<r))return A.a(a0,q)
n=a0[q].b.d
p=Math.max(p,n)
o=Math.min(o,n)}m=t+B.c.A(s-t,2)
if(!(m>=0&&m<a1.length))return A.a(a1,m)
l=a1[m]
k=A.fb(u.V)
j=d.bB(l.a)
if(j!=null)k.n(0,j)
i=d.bn(b)
h=A.a8(u.N,u.i)
if(b===B.f){h.m(0,"totalHeadingChangeDegrees",d.aH(a0,t,s))
h.m(0,"apexIndex",d.ba(a0,c))
k.n(0,B.o)}else k.n(0,d.aq(b))
r=a0.length
if(!(s<r))return A.a(a0,s)
g=a0[s]
if(!(t<r))return A.a(a0,t)
f=B.b.k(B.c.A(g.b.c.U(a0[t].b.c).a,1000)/1000/5,0.5,1)
g=a0.length
if(!(t<g))return A.a(a0,t)
r=a0[t].b
if(!(s<g))return A.a(a0,s)
g=a0[s].b
e=o===1/0?0:o
return A.fE(f,k,d.ah(a0,t,s),a,s,g.d,g.c,a+":"+b.b+":"+t+":"+s,p,h,e,B.aE,A.i0([i],u.c5),i,t,r.d,r.c,l,b)},
bu(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f
u.B.a(a)
t=u.N
s=A.a8(t,u.dy)
for(r=a.length,q=u.s,p=0;o=a.length,p<o;a.length===r||(0,A.at)(a),++p)s.m(0,a[p].a,A.n([],q))
t=A.a8(t,u.fj)
for(r=u.V,p=0;q=a.length,p<q;a.length===o||(0,A.at)(a),++p){n=a[p]
q=A.fN(r)
q.E(0,n.ch)
t.m(0,n.a,q)}for(r=q,m=0;m<r;r=h,m=k){if(!(m<r))return A.a(a,m)
l=a[m]
for(k=m+1,r=l.a,q=l.c,o=l.d,j=l.e,i=k;h=a.length,i<h;++i){g=a[i]
if(g.d>j)break
if(g.e<o)continue
h=s.i(0,r)
h.toString
f=g.a
B.a.n(h,f)
h=s.i(0,f)
h.toString
B.a.n(h,r)
h=t.i(0,r)
h.toString
h.n(0,this.aq(g.c))
f=t.i(0,f)
f.toString
f.n(0,this.aq(q))}}r=A.i(a)
q=r.h("h<1,k>")
t=A.D(new A.h(a,r.h("k(1)").a(new A.dz(t,s)),q),q.h("r.E"))
t.$flags=1
return t},
bn(a){var t
switch(a.a){case 0:t=B.ad
break
case 1:t=B.p
break
case 2:t=B.B
break
case 3:t=B.C
break
case 4:t=B.D
break
default:t=null}return t},
aq(a){var t
switch(a.a){case 0:t=B.a6
break
case 1:t=B.a7
break
case 2:t=B.a9
break
case 3:t=B.o
break
case 4:t=B.a8
break
default:t=null}return t},
bB(a){var t=null
switch(a.a){case 3:t=B.ac
break
case 2:t=B.ab
break
case 1:t=B.aa
break
case 0:break}return t},
a9(a,b,c){var t,s,r,q,p
u.J.a(a)
u.e.a(b)
for(t=b.length,s=0;s<b.length;b.length===t||(0,A.at)(b),++s){r=b[s]
for(q=r.a,p=r.b;q<=p;++q)B.a.m(a,q,c)}},
b6(a,b,c){var t,s,r,q,p,o,n
u.J.a(a)
u.X.a(b)
t=A.n([],u.q)
for(s=a.length,r=0,q=1;q<=s;++q){p=!1
if(q<s){o=a[q]
if(!(r>=0&&r<s))return A.a(a,r)
if(o===a[r])if(c){if(!(q<b.length))return A.a(b,q)
p=!b[q].b.y}else p=!0}if(p)continue
if(!(r>=0&&r<s))return A.a(a,r)
p=a[r]
o=q-1
n=b.length
if(!(r<n))return A.a(b,r)
if(!(o<n))return A.a(b,o)
B.a.n(t,new A.ah(p,r,o))
r=q}return t},
ah(a,b,c){var t,s,r
u.X.a(a)
for(t=b+1,s=a.length,r=0;t<=c;++t){if(!(t<s))return A.a(a,t)
r+=a[t].b.w}return r},
aH(a,b,c){var t,s,r
u.X.a(a)
for(t=b+1,s=a.length,r=0;t<=c;++t){if(!(t<s))return A.a(a,t)
r+=Math.abs(a[t].f)}return r},
ba(a,b){var t,s,r,q,p,o
u.X.a(a)
t=b.a
for(s=b.b,r=a.length,q=t,p=0;q<=s;++q){if(!(q<r))return A.a(a,q)
o=a[q].r
if(o>p){p=o
t=q}}return t}}
A.dB.prototype={
$1(a){return a.b.d<=1.3888888888888888},
$S:1}
A.dA.prototype={
$1(a){return a.b.d<=1.3888888888888888},
$S:1}
A.dC.prototype={
$1(a){return this.a.ah(this.b,a.a,a.b)<=8},
$S:6}
A.dN.prototype={
$1(a){return a.e>=0.35},
$S:1}
A.dM.prototype={
$1(a){return a.e>=0.15},
$S:1}
A.dO.prototype={
$1(a){var t,s=this.a,r=a.b,q=s.length
if(!(r<q))return A.a(s,r)
r=s[r]
t=a.a
if(!(t<q))return A.a(s,t)
return r.b.d-s[t].b.d>=2},
$S:6}
A.dQ.prototype={
$1(a){return a.e<=-0.35},
$S:1}
A.dP.prototype={
$1(a){return a.e<=-0.15},
$S:1}
A.dR.prototype={
$1(a){var t,s=this.a,r=a.a,q=s.length
if(!(r<q))return A.a(s,r)
r=s[r]
t=a.b
if(!(t<q))return A.a(s,t)
return r.b.d-s[t].b.d>=2},
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
$1(a){var t=this.a,s=this.b,r=a.a,q=a.b
return t.aH(s,r,q)>=15&&t.ah(s,r,q)>=15},
$S:6}
A.dF.prototype={
$1(a){var t=this
return t.a.a3(t.b,B.x,u.P.a(a),t.c,t.d)},
$S:2}
A.dG.prototype={
$1(a){var t=this
return t.a.a3(t.b,B.h,u.P.a(a),t.c,t.d)},
$S:2}
A.dH.prototype={
$1(a){var t=this
return t.a.a3(t.b,B.k,u.P.a(a),t.c,t.d)},
$S:2}
A.dI.prototype={
$1(a){var t=this
return t.a.a3(t.b,B.f,u.P.a(a),t.c,t.d)},
$S:2}
A.dJ.prototype={
$1(a){var t=this
return t.a.a3(t.b,B.i,u.P.a(a),t.c,t.d)},
$S:2}
A.dK.prototype={
$2(a,b){var t,s=u.F
s.a(a)
s.a(b)
t=B.c.H(a.d,b.d)
return t!==0?t:B.c.H(a.c.a,b.c.a)},
$S:22}
A.dL.prototype={
$1(a){var t,s,r,q
u.P.a(a)
t=a.a
s=a.b
r=this.a
q=r.length
if(!(t<q))return A.a(r,t)
if(!(s<q))return A.a(r,s)
return new A.ah(B.Z,t,s)},
$S:23}
A.dz.prototype={
$1(a){var t,s,r
u.F.a(a)
t=a.a
s=this.a.i(0,t)
s.toString
s=A.i1(s,u.V)
r=this.b.i(0,t)
r.toString
r=A.a9(r,u.N)
s=u.gM.a(new A.bJ(s,u.f4))
u.gJ.a(r)
return A.fE(a.as,s,a.Q,a.b,a.e,a.x,a.r,t,a.y,a.cx,a.z,r,a.ay,a.ax,a.d,a.w,a.f,a.at,a.c)},
$S:24}
A.U.prototype={}
A.dU.prototype={
P(){return"DriveScoreAlgorithmVersion."+this.b}}
A.dV.prototype={
bL(a){var t,s
u.t.a(a)
t=J.eb(a.slice(0),A.i(a).c)
if(t.length<2)throw A.d(B.u)
if(B.a.R(t,new A.dX()))throw A.d(B.v)
switch(0){case 0:s=this.aC(t,!1)
break}return s},
bM(a){var t,s
u.t.a(a)
t=J.eb(a.slice(0),A.i(a).c)
if(t.length<2)throw A.d(B.u)
if(B.a.R(t,new A.dW()))throw A.d(B.v)
s=this.aC(t,!0)
return new A.cb("reliable_intervals",1,1,s.d,s.e,s.f,s.r,s.w,s.x,s.y)},
aC(a,b){var t,s,r,q,p,o,n=B.L.bK("in-memory-drive-score",b,u.Y.a(a)),m=B.I.I(n),l=B.S.I(n),k=B.J.I(n),j=B.N.I(n),i=B.H.I(n),h=B.T.I(n),g=m.z
g=g.a&&g.b&&g.c&&g.d
t=m.f>0||m.r>0
s=l.as.a
r=u.N
q=u.Q
p=A.bu(["brakingAnticipation",new A.E(m.a,350,!g,t),"tempoPerformance",new A.E(l.a,150,s,s),"corneringPerformance",new A.E(k.a,150,k.y,k.z),"drivingSmoothness",new A.E(j.a,100,j.b,j.c),"accelerationPerformance",new A.E(i.a,50,i.e,i.f),"transitionControl",new A.E(h.a,50,h.e,h.f)],r,q)
o=B.P.b_(l.r,new A.a2(p,A.f(p).h("a2<2>")))
q=A.fL(p,r,q)
q.m(0,"drivingEndurance",new A.E(o.a,150,o.f,o.r))
return B.M.bJ(q)}}
A.dX.prototype={
$1(a){return!u.u.a(a).gar()},
$S:14}
A.dW.prototype={
$1(a){return!u.u.a(a).gar()},
$S:14}
A.ch.prototype={
j(a){return"At least two canonical telemetry points are required."}}
A.ea.prototype={
j(a){return"Canonical telemetry contains an invalid coordinate."}}
A.dY.prototype={
bJ(a){var t,s,r,q,p,o,n,m,l,k,j
u.cC.a(a)
t=u.N
s=u.D
r=A.a8(t,s)
for(q=new A.bq(a,A.f(a).h("bq<1,2>")).gt(0),p=0;q.p();){o=q.d
n=o.b
m=n.c
if(m&&n.d)l=B.w
else l=!m?B.U:B.V
m=l===B.w
k=m?n.a:n.b*0.75
if(m)++p
r.m(0,o.a,new A.au(k,l))}j=B.b.k(new A.a2(r,r.$ti.h("a2<2>")).J(0,0,new A.dZ(),u.i),0,1000)
q=B.b.ac(j)
return new A.cb("legacy_v1",1,null,j,B.b.k(p/a.a,0,1),q,1,A.f7(a,t,u.Q),A.f7(r,t,s),"Actual scores plus neutral contributions for unavailable evidence.")}}
A.dZ.prototype={
$2(a,b){return A.p(a)+u.D.a(b).b},
$S:26}
A.bg.prototype={
P(){return"DriveScoreContributionSource."+this.b}}
A.E.prototype={}
A.au.prototype={}
A.cb.prototype={}
A.e_.prototype={}
A.a6.prototype={
P(){return"DrivingPhase."+this.b}}
A.b3.prototype={
P(){return"TrafficRegime."+this.b}}
A.aH.prototype={
P(){return"DrivingEventType."+this.b}}
A.av.prototype={
P(){return"EventOwnerDomain."+this.b}}
A.Q.prototype={
P(){return"EventContextTag."+this.b}}
A.T.prototype={}
A.an.prototype={}
A.ah.prototype={}
A.k.prototype={}
A.c9.prototype={
V(a){var t=this.r,s=A.i(t)
return new A.y(t,s.h("j(1)").a(new A.dy(a)),s.h("y<1>"))}}
A.dy.prototype={
$1(a){return u.F.a(a).c===this.a},
$S:4}
A.e1.prototype={
I(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=A.n([],u.g)
for(t=a.V(B.i),s=J.ad(t.a),t=new A.a4(s,t.b,t.$ti.h("a4<1>")),r=0;t.p();){q=s.gq()
p=q.at
o=Math.max(p.c,p.d)
if(q.ax===B.D){p=q.r
n=q.f
p=A.A(p.b-n.b,p.a-n.a).a<8e6||q.y<8.333333333333334||o>=0.65}else p=!0
if(p)++r
else B.a.n(e,q)}t=e.length
if(t===0)return new A.cc(0,!1,!1)
for(m=0,l=B.a_,k=0,j=0;j<e.length;e.length===t||(0,A.at)(e),++j){i=e[j]
s=i.r
q=i.f
h=s.a-q.a
g=s.b-q.b
m+=A.A(g,h).a
if(A.A(g,h).a>l.a)l=A.A(g,h)
k+=B.b.k(1-this.bF(a,i)/4,0,1)*A.A(g,h).a}f=A.A(m,0)
t=B.b.k((0.55*this.bb(f,B.a5,B.a0,B.a3)+0.45*(k/m))*100,0,1)
s=f.a
B.c.A(s,1e6)
return new A.cc(t*100,!0,s>=3e7)},
bF(a,b){var t=B.a.a7(a.c,b.d,b.e+1),s=A.i(t),r=s.h("h<1,b>"),q=A.D(new A.h(t,s.h("b(1)").a(new A.e2()),r),r.h("r.E"))
return B.a.J(q,0,new A.e3(B.a.L(q,new A.e4())/q.length),u.i)/q.length},
bb(a,b,c,d){var t,s=a.a,r=b.a
if(s<=r)return 0
t=c.a
if(s<=t)return 0.75*(s-r)/(t-r)
return 0.75+0.25*B.b.k((s-t)/(d.a-t),0,1)}}
A.e2.prototype={
$1(a){return u.K.a(a).b.d},
$S:3}
A.e4.prototype={
$2(a,b){return A.p(a)+A.p(b)},
$S:0}
A.e3.prototype={
$2(a,b){var t
A.p(a)
t=A.p(b)-this.a
return a+t*t},
$S:0}
A.e5.prototype={
b_(a,b){var t,s,r,q,p
u.ff.a(b)
t=b.$ti
s=t.h("y<c.E>")
r=A.D(new A.y(b,t.h("j(c.E)").a(new A.e6()),s),s.h("c.E"))
if(a<5||r.length===0)return new A.cd(0,!1,!1)
q=this.bp(a)
t=A.i(r)
p=B.b.k(new A.h(r,t.h("b(1)").a(new A.e7()),t.h("h<1,b>")).L(0,new A.e8())/r.length,0.15,1)
B.b.k(r.length/6,0,1)
t=a>=50&&r.length>=3
return new A.cd(q*p*150,!0,t)},
bp(a){if(a<=5)return a/5*0.15
if(a<=50)return 0.15+(a-5)/45*0.6
return B.b.k(0.75+(a-50)/100*0.25,0,1)}}
A.e6.prototype={
$1(a){u.Q.a(a)
return a.c&&a.d},
$S:27}
A.e7.prototype={
$1(a){u.Q.a(a)
return a.a/a.b},
$S:28}
A.e8.prototype={
$2(a,b){return A.p(a)+A.p(b)},
$S:0}
A.cd.prototype={}
A.cc.prototype={}
A.c_.prototype={}
A.a7.prototype={
P(){return"DrivingTransitionType."+this.b}}
A.a0.prototype={}
A.cx.prototype={}
A.f0.prototype={
$1(a){var t,s,r,q,p="schema_version",o=u.h.a(B.j.bP(A.J(a),null))
try{if(J.Z(J.bb(o,p),2)){t=A.j7(o)
s=A.fL(A.hs(t.b),u.N,u.z)
J.cI(s,"calculationMode",t.b.a)
J.cI(s,"calculationVersion",t.b.b)
J.cI(s,"reliabilityPolicyVersion",t.b.c)
J.cI(s,"scoreEligible",t.a)
r=B.j.aR(s,null)
return r}if(J.bb(o,p)!=null&&!J.Z(J.bb(o,p),1))throw A.d(B.ak)
r=B.j.aR(A.hs(B.t.bL(A.jo(u.j.a(J.bb(o,"canonical_telemetry"))))),null)
return r}catch(q){if(A.fr(q) instanceof A.ch)return"null"
else throw q}},
$S:29}
A.aa.prototype={
a5(){var t,s=A.a8(u.N,u.z)
s.m(0,"latitude",this.a)
s.m(0,"longitude",this.b)
t=this.c
if(t!=null)s.m(0,"break_before",t)
return s}}
A.X.prototype={
a5(){var t,s,r=this,q=u.N,p=u.z,o=A.a8(q,p)
o.m(0,"latitude",r.a)
o.m(0,"longitude",r.b)
t=r.c
o.m(0,"timestamp",t.ad().av())
o.m(0,"speed_mps",r.d)
o.m(0,"heading_degrees",r.e)
o.m(0,"altitude_meters",r.f)
o.m(0,"accuracy_meters",r.r)
o.m(0,"distance_from_previous_meters",r.w)
o.m(0,"acceleration_mps2",r.x)
s=r.as
if(s!=null){t=t.ad()
o.E(0,A.bu(["timestamp_micros",B.c.j(1000*t.a+t.b),"break_before",r.y,"gap_duration_micros",r.Q,"speed_source",s,"acceleration_reliable",r.z],q,p))}return o}}
A.em.prototype={
c1(){var t,s,r,q,p,o,n,m,l=this,k="startedAtMicros",j="stopRequestedAtMicros",i=l.d
if(i===1){if(l.a!=null||l.b!=null||l.c!=null)throw A.d(B.aj)
return}t=!0
if(i===2)if(l.r===1)if(l.x===6)if(l.w===1)if(l.a==="reliable_intervals")if(l.b===1){i=l.c
s=i==null
if(J.Z(s?null:i.i(0,"reliabilityPolicyVersion"),1))if(A.bY(s?null:i.i(0,k)))i=!A.bY(s?null:i.i(0,j))
else i=t
else i=t}else i=t
else i=t
else i=t
else i=t
else i=t
else i=t
if(i)throw A.d(B.ae)
i=l.c
r=A.I(i.i(0,k))
q=A.I(i.i(0,j))
i=!0
if(!B.a.R(l.as,new A.er()))if(q>r){t=l.y
if(r===1000*t.a+t.b){t=l.z
if(q===1000*t.a+t.b){i=l.at
i=i.length<2||B.a.R(i,new A.es(r,q))}}}if(i)throw A.d(B.af)
for(i=l.at,t=i.length,p=1;p<t;++p){s=i[p].c
o=i[p-1].c
n=s.a
m=o.a
if(n<=m)s=n===m&&s.b>o.b
else s=!0
if(!s)throw A.d(B.ai)}},
a5(){var t=this,s=u.N,r=u.z,q=A.a8(s,r),p=t.d
q.m(0,"schema_version",p)
q.m(0,"publish_id",t.e)
q.m(0,"local_drive_id",t.f)
q.m(0,"telemetry_version",t.r)
q.m(0,"drive_score_algorithm_version",t.w)
q.m(0,"world_rules_version",t.x)
if(p===2)q.E(0,A.bu(["score_calculation_mode",t.a,"score_calculation_version",t.b,"telemetry_reliability",t.c],s,r))
q.m(0,"started_at",t.y.ad().av())
q.m(0,"ended_at",t.z.ad().av())
q.m(0,"recorded_distance_meters",t.Q)
s=t.as
r=A.i(s)
p=r.h("h<1,q<e,@>>")
s=A.D(new A.h(s,r.h("q<e,@>(1)").a(new A.ep()),p),p.h("r.E"))
q.m(0,"raw_route",s)
s=t.at
r=A.i(s)
p=r.h("h<1,q<e,@>>")
s=A.D(new A.h(s,r.h("q<e,@>(1)").a(new A.eq()),p),p.h("r.E"))
q.m(0,"canonical_telemetry",s)
return q}}
A.er.prototype={
$1(a){var t,s
u.p.a(a)
t=!0
if(a.c!=null){s=a.a
if(isFinite(s)){t=a.b
t=!isFinite(t)||Math.abs(s)>90||Math.abs(t)>180}}return t},
$S:46}
A.es.prototype={
$1(a){var t,s,r
u.A.a(a)
t=!0
if(a.y!=null)if(a.z!=null){s=a.a
if(isFinite(s)){r=a.b
if(isFinite(r))if(!(Math.abs(s)>90))if(!(Math.abs(r)>180))if(isFinite(a.d))if(isFinite(a.e))if(isFinite(a.f))if(isFinite(a.r))if(isFinite(a.w))if(isFinite(a.x)){s=a.Q
if(s!=null)if(!(s<0))if(B.a.a_(A.n(["native","geometry_estimate","held_estimate","unavailable"],u.s),a.as)){t=a.c
t=1000*t.a+t.b
t=t<this.a||t>this.b}}}}return t},
$S:31}
A.ep.prototype={
$1(a){return u.p.a(a).a5()},
$S:32}
A.eq.prototype={
$1(a){return u.A.a(a).a5()},
$S:45}
A.en.prototype={
$1(a){var t=u.G.a(a).O(0,u.N,u.z)
return new A.aa(A.z(t.i(0,"latitude")),A.z(t.i(0,"longitude")),A.eV(t.i(0,"break_before")))},
$S:34}
A.eo.prototype={
$1(a){var t,s,r,q,p,o,n,m,l,k="speed_source",j=u.G.a(a).O(0,u.N,u.z),i=A.z(j.i(0,"latitude")),h=A.z(j.i(0,"longitude")),g=A.du(A.J(j.i(0,"timestamp")))
if(j.i(0,k)!=null&&!J.Z(j.i(0,"timestamp_micros"),B.c.j(1000*g.a+g.b)))A.aC(B.ag)
t=A.z(j.i(0,"speed_mps"))
s=A.z(j.i(0,"heading_degrees"))
r=A.z(j.i(0,"altitude_meters"))
q=A.z(j.i(0,"accuracy_meters"))
p=A.z(j.i(0,"distance_from_previous_meters"))
o=A.z(j.i(0,"acceleration_mps2"))
n=A.eV(j.i(0,"break_before"))
m=A.fk(j.i(0,"gap_duration_micros"))
l=A.eW(j.i(0,k))
return new A.X(i,h,g,t,s,r,q,p,o,n,A.eV(j.i(0,"acceleration_reliable")),m,l)},
$S:35}
A.eY.prototype={
$1(a){var t,s,r,q
u.A.a(a)
t=a.y
t.toString
s=a.Q
s.toString
r=a.as
r.toString
q=a.z
q.toString
return new A.C(a.a,a.b,a.c,a.d,a.e,a.f,a.r,a.w,a.x,t,s,r,q)},
$S:36}
A.ev.prototype={
I(b2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8=this,a9=1e6,b0=b2.c,b1=b0.length
if(b1<2)return new A.bH(0,0,B.aI)
for(t=b2.a,s=b1-1,r=!t,q=0,p=0,o=0,n=0,m=0,l=0,k=0;k<b1;++k){if(r)n+=b0[k].b.w
if(k===s)continue
j=b0[k]
i=k+1
if(!(i<b1))return A.a(b0,i)
i=b0[i].b
h=i.c
g=j.b
f=g.c
h=A.A(h.b-f.b,h.a-f.a).a
f=!0
if(h>0)if(t){if(A.bh(g,i)){e=g.Q
if(e!=="unavailable"&&e!=="held_estimate"){e=g.d
e=isFinite(e)&&e>=0&&e<=70}else e=!1
if(e){f=i.Q
if(f!=="unavailable"&&f!=="held_estimate"){f=i.d
f=isFinite(f)&&f>=0&&f<=70}else f=!1
f=!f}}}else f=!1
if(f){++m
continue}l+=h
if(t)n+=i.w
if(t){f=g.Q
e=f!=="unavailable"
if(e&&f!=="held_estimate"){d=g.d
d=isFinite(d)&&d>=0&&d<=70}else d=!1
if(d){d=i.Q
if(d!=="unavailable"&&d!=="held_estimate"){d=i.d
d=isFinite(d)&&d>=0&&d<=70}else d=!1
d=d&&g.d<=1.5&&i.d<=1.5}else d=!1
if(d)p+=h
else{if(e&&f!=="held_estimate"){f=g.d
f=isFinite(f)&&f>=0&&f<=70}else f=!1
if(f){f=i.Q
if(f!=="unavailable"&&f!=="held_estimate"){f=i.d
f=isFinite(f)&&f>=0&&f<=70}else f=!1
g=f&&g.d>1.5&&i.d>1.5}else g=!1
if(g){q+=h
o+=i.w}}}else if(a8.bk(b2,k))p+=h
else{q+=h
o+=i.w}}c=t?A.A(l,0):B.a.gab(b0).b.c.U(B.a.gW(b0).b.c)
b=A.A(q,0)
a=A.A(p,0)
a0=n/1000
t=b.a
a1=t<=0?0:o/(t/1e6)*3.6
a2=a8.bE(b2)
a3=b1>=6&&t>=9e7&&n>=1000
B.b.k(Math.min(b1/6,Math.min(t/9e7,a0)),0,1)
if(!a3){B.b.aX(a0,2)
B.c.A(t,a9)
return new A.bH(0,a0,new A.bG(!1))}b1=c.a
a4=b1<=0?0:n/(b1/1e6)*3.6
a5=a8.ao(a1,B.ax,60)
a6=a2.b<2?0:a8.ao(a2.a*3.6,B.aF,30)
a7=B.b.k(a5+a6+a8.ao(a4,B.at,60),0,150)
B.b.aX(a0,2)
B.c.A(t,a9)
B.c.A(a.a,a9)
return new A.bH(a7,a0,new A.bG(!0))},
bk(a,b){var t,s,r,q
if(this.bo(a.d,b)===B.z)return!0
t=a.c
s=t.length
if(!(b<s))return A.a(t,b)
r=t[b]
q=b+1
if(!(q<s))return A.a(t,q)
q=t[q]
return r.b.d<=1.3888888888888888&&q.b.d<=1.3888888888888888},
bo(a,b){var t,s,r
u.au.a(a)
for(t=a.length,s=0;s<t;++s){r=a[s]
if(b>=r.b&&b<=r.c)return r.a}return B.y},
bE(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g=a.c
for(t=g.length,s=a.a,r=0,q=0,p=0;p<t;++p){o=g[p].b
n=o.d
o=o.Q
if(!(o!=="unavailable"&&o!=="held_estimate"))continue
if(!isFinite(n)||n<0)continue
for(o=[p-1,p+1],m=1,l=0;l<2;++l){k=o[l]
if(k<0||k>=t)continue
if(!(k>=0&&k<t))return A.a(g,k)
j=g[k].b.Q
if(!(j!=="unavailable"&&j!=="held_estimate"))continue
i=Math.min(p,k)
h=Math.max(p,k)
if(s){if(i>>>0!==i||i>=t)return A.a(g,i)
j=g[i]
if(h>>>0!==h||h>=t)return A.a(g,h)
j=!A.bh(j.b,g[h].b)}else j=!1
if(j)continue
if(Math.abs(g[k].b.d-n)<=10)++m}if(m<2)continue
if(n>r){q=m
r=n}}return new A.eU(r,q)},
ao(a,b,c){var t,s,r,q,p,o
u.gj.a(b)
if(a<=B.a.gW(B.a.gW(b)))return 0
for(t=b.length,s=1;s<t;++s){r=b[s-1]
q=b[s]
if(a<=B.a.gW(q)){t=B.a.gW(r)
p=B.a.gW(q)
o=B.a.gW(r)
return B.b.k(c*(B.a.gab(r)+(B.a.gab(q)-B.a.gab(r))*((a-t)/(p-o))),0,c)}}return c}}
A.eU.prototype={}
A.bH.prototype={}
A.bG.prototype={}
A.ew.prototype={
I(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=a.r,b=A.n([],u.c)
for(t=c.length,s=a.a,r=0;q=r+2,q<t;){if(!(r<t))return A.a(c,r)
p=c[r];++r
if(!(r<t))return A.a(c,r)
o=c[r]
n=c[q]
m=this.bD(p,o,n)
if(m!=null){q=o.at
l=Math.max(q.c,q.d)
q=!1
if(n.y>=8.333333333333334)if(l<0.65){k=o.f
j=p.r
if(A.A(k.b-j.b,k.a-j.a).a<=8e6){q=n.f
k=o.r
k=A.A(q.b-k.b,q.a-k.a).a<=8e6
q=k}}q=!q}else q=!0
if(q)continue
if(s&&!A.e0(p.d,n.e,new A.eA(a)))continue
B.a.n(b,new A.a0(m,this.br(a,n)))}if(b.length===0)return B.aN
i=new A.eC(b)
h=i.$2(B.l,20)
g=i.$2(B.m,20)
f=i.$2(B.n,10)
t=A.a8(u.am,u.S)
for(s=u.eF,q=u.dA,e=0;e<3;++e){d=B.aH[e]
t.m(0,d,new A.y(b,s.a(new A.eB(d)),q).gl(0))}return new A.cx(h+g+f,!0,b.length>=2)},
bD(a,b,c){var t,s
if(c.c!==B.i)return null
t=a.c
s=t===B.i
if(s&&b.c===B.k)return B.l
if(s&&b.c===B.f)return B.m
if(t===B.h)return B.n
return null},
br(a,b){var t=B.a.a7(a.c,b.d,b.e+1),s=A.i(t)
return B.b.k(1-Math.sqrt(B.a.J(t,0,new A.ex(new A.h(t,s.h("b(1)").a(new A.ey()),s.h("h<1,b>")).L(0,new A.ez())/t.length),u.i)/t.length)/4,0,1)}}
A.eA.prototype={
$1(a){var t=this.a.c
if(!(a>=0&&a<t.length))return A.a(t,a)
return t[a].b},
$S:7}
A.eC.prototype={
$2(a,b){var t=this.a,s=A.i(t),r=s.h("y<1>"),q=A.D(new A.y(t,s.h("j(1)").a(new A.eD(a)),r),r.h("c.E"))
if(q.length===0)return 0
t=A.i(q)
return new A.h(q,t.h("b(1)").a(new A.eE()),t.h("h<1,b>")).L(0,new A.eF())/q.length*b},
$S:37}
A.eD.prototype={
$1(a){return u.f.a(a).a===this.a},
$S:10}
A.eE.prototype={
$1(a){return u.f.a(a).e},
$S:39}
A.eF.prototype={
$2(a,b){return A.p(a)+A.p(b)},
$S:0}
A.eB.prototype={
$1(a){return u.f.a(a).a===this.a},
$S:10}
A.ey.prototype={
$1(a){return u.K.a(a).b.d},
$S:3}
A.ez.prototype={
$2(a,b){return A.p(a)+A.p(b)},
$S:0}
A.ex.prototype={
$2(a,b){var t
A.p(a)
t=u.K.a(b).b.d-this.a
return a+t*t},
$S:40}
A.f3.prototype={
$1(a){var t,s,r,q,p,o,n,m,l,k,j,i,h="gap_duration_micros"
u.h.a(a)
t=A.z(a.i(0,"latitude"))
s=A.z(a.i(0,"longitude"))
r=A.du(A.J(a.i(0,"timestamp")))
q=A.z(a.i(0,"speed_mps"))
p=A.z(a.i(0,"heading_degrees"))
o=A.z(a.i(0,"altitude_meters"))
n=A.z(a.i(0,"accuracy_meters"))
m=A.z(a.i(0,"distance_from_previous_meters"))
l=A.z(a.i(0,"acceleration_mps2"))
k=J.Z(a.i(0,"break_before"),!0)
j=typeof a.i(0,h)=="number"?B.b.aV(A.z(a.i(0,h))):0
i=A.eW(a.i(0,"speed_source"))
if(i==null)i="legacy"
return new A.C(t,s,r,q,p,o,n,m,l,k,j,i,!J.Z(a.i(0,"acceleration_reliable"),!1))},
$S:41}
A.f1.prototype={
$2(a,b){A.J(a)
u.Q.a(b)
return new A.F(a,A.bu(["score",b.a,"maximum",b.b,"applicable",b.c,"sampleSufficient",b.d],u.N,u.C),u.k)},
$S:42}
A.f2.prototype={
$2(a,b){A.J(a)
u.D.a(b)
return new A.F(a,A.bu(["contribution",b.b,"source",b.c.b],u.N,u.C),u.k)},
$S:43};(function aliases(){var t=J.aw.prototype
t.b1=t.j})();(function installTearOffs(){var t=hunkHelpers._static_2,s=hunkHelpers._static_1,r=hunkHelpers._instance_1u,q=hunkHelpers.installStaticTearOff
t(J,"iM","hY",44)
s(A,"jb","iD",33)
r(A.c8.prototype,"gbG","bH",5)
r(A.ca.prototype,"gbi","bj",1)
q(A,"jm",2,null,["$1$2","$2"],["hq",function(a,b){return A.hq(a,b,u.H)}],30,0)})();(function inheritance(){var t=hunkHelpers.mixin,s=hunkHelpers.inherit,r=hunkHelpers.inheritMany
s(A.m,null)
r(A.m,[A.f9,J.ci,A.bB,J.aE,A.c,A.bd,A.w,A.M,A.u,A.et,A.bv,A.by,A.a4,A.bC,A.bk,A.aR,A.b1,A.be,A.bM,A.eG,A.ek,A.eh,A.bs,A.bt,A.br,A.cm,A.eP,A.a3,A.cA,A.eR,A.aM,A.cD,A.aP,A.bP,A.bW,A.bN,A.cE,A.c4,A.c6,A.eN,A.af,A.N,A.eJ,A.cq,A.bD,A.eK,A.a1,A.F,A.aK,A.b2,A.cJ,A.cY,A.aA,A.ac,A.dg,A.cX,A.C,A.c8,A.c7,A.a5,A.dx,A.ca,A.U,A.dV,A.ch,A.ea,A.dY,A.E,A.au,A.cb,A.e_,A.T,A.an,A.ah,A.k,A.c9,A.e1,A.e5,A.cd,A.cc,A.c_,A.a0,A.cx,A.aa,A.X,A.em,A.ev,A.eU,A.bH,A.bG,A.ew])
r(J.ci,[J.ck,J.bn,J.b0,J.aZ,J.aI])
r(J.b0,[J.aw,J.l])
r(J.aw,[J.el,J.ay,J.bo])
s(J.cj,A.bB)
s(J.ec,J.l)
r(J.aZ,[J.bm,J.cl])
r(A.c,[A.b4,A.o,A.ak,A.y,A.am,A.aO])
s(A.aF,A.b4)
s(A.bL,A.aF)
r(A.w,[A.aG,A.aj,A.cB])
r(A.M,[A.c3,A.cg,A.c2,A.cw,A.eL,A.dv,A.dw,A.cR,A.cT,A.cU,A.cV,A.cK,A.cN,A.cO,A.de,A.df,A.d_,A.cZ,A.d0,A.d1,A.d4,A.d5,A.d8,A.d9,A.d7,A.da,A.d3,A.d2,A.d6,A.dq,A.dl,A.dm,A.dn,A.dp,A.dB,A.dA,A.dC,A.dN,A.dM,A.dO,A.dQ,A.dP,A.dR,A.dS,A.dD,A.dT,A.dE,A.dF,A.dG,A.dH,A.dI,A.dJ,A.dL,A.dz,A.dX,A.dW,A.dy,A.e2,A.e6,A.e7,A.f0,A.er,A.es,A.ep,A.eq,A.en,A.eo,A.eY,A.eA,A.eD,A.eE,A.eB,A.ey,A.f3])
r(A.c3,[A.di,A.dj,A.ed,A.ei,A.ej,A.eO,A.cS,A.cM,A.cL,A.cQ,A.cP,A.dc,A.dd,A.dr,A.ds,A.dk,A.dK,A.dZ,A.e4,A.e3,A.e8,A.eC,A.eF,A.ez,A.ex,A.f1,A.f2])
r(A.u,[A.cp,A.bI,A.cn,A.cy,A.cu,A.cz,A.bp,A.c0,A.ae,A.bK,A.bE,A.c5])
r(A.o,[A.r,A.bj,A.aJ,A.a2,A.bq,A.bO])
r(A.r,[A.bF,A.h,A.bw,A.cC])
s(A.bi,A.ak)
s(A.aW,A.am)
s(A.b5,A.aR)
s(A.bQ,A.b5)
s(A.b7,A.b1)
s(A.aN,A.b7)
s(A.bf,A.aN)
s(A.a_,A.be)
s(A.aX,A.cg)
s(A.bz,A.bI)
r(A.cw,[A.cv,A.aV])
s(A.b6,A.cz)
r(A.aM,[A.bR,A.bX])
s(A.aq,A.bR)
s(A.bJ,A.bX)
s(A.co,A.bp)
s(A.ee,A.c4)
r(A.c6,[A.eg,A.ef])
s(A.eM,A.eN)
r(A.ae,[A.bA,A.cf])
s(A.db,A.c2)
r(A.eJ,[A.dU,A.bg,A.a6,A.b3,A.aH,A.av,A.Q,A.a7])
t(A.b7,A.bW)
t(A.bX,A.cE)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{K:"int",b:"double",L:"num",e:"String",j:"bool",aK:"Null",x:"List",m:"Object",q:"Map",b_:"JSObject"},mangledNames:{},types:["b(b,b)","j(T)","k(U)","b(T)","j(k)","b(a5)","j(U)","C(K)","b(k)","b(b,aA)","j(a0)","b(ac)","~(m?,m?)","K(e?)","j(C)","~(@,@)","@(e)","b(b)","j(k?)","b(b(a5))","b(b(k))","j(ac)","K(k,k)","ah(U)","k(k)","aK()","b(b,au)","j(E)","b(E)","e(e)","0^(0^,0^)<L>","j(X)","q<e,@>(aa)","@(@)","aa(@)","X(@)","C(X)","b(a7,b)","j(e)","b(a0)","b(b,T)","C(@)","F<e,q<e,m>>(e,E)","F<e,q<e,m>>(e,au)","K(@,@)","q<e,@>(X)","j(aa)"],arrayRti:Symbol("$ti"),rttc:{"2;eligible,result":(a,b)=>c=>c instanceof A.bQ&&a.b(c.a)&&b.b(c.b)}}
A.it(v.typeUniverse,JSON.parse('{"bo":"aw","el":"aw","ay":"aw","ck":{"j":[],"ao":[]},"bn":{"ao":[]},"b0":{"b_":[]},"aw":{"b_":[]},"l":{"x":["1"],"o":["1"],"b_":[],"c":["1"]},"cj":{"bB":[]},"ec":{"l":["1"],"x":["1"],"o":["1"],"b_":[],"c":["1"]},"aE":{"t":["1"]},"aZ":{"b":[],"L":[],"R":["L"]},"bm":{"b":[],"K":[],"L":[],"R":["L"],"ao":[]},"cl":{"b":[],"L":[],"R":["L"],"ao":[]},"aI":{"e":[],"R":["e"],"ao":[]},"b4":{"c":["2"]},"bd":{"t":["2"]},"aF":{"b4":["1","2"],"c":["2"],"c.E":"2"},"bL":{"aF":["1","2"],"b4":["1","2"],"o":["2"],"c":["2"],"c.E":"2"},"aG":{"w":["3","4"],"q":["3","4"],"w.K":"3","w.V":"4"},"cp":{"u":[]},"o":{"c":["1"]},"r":{"o":["1"],"c":["1"]},"bF":{"r":["1"],"o":["1"],"c":["1"],"c.E":"1","r.E":"1"},"bv":{"t":["1"]},"ak":{"c":["2"],"c.E":"2"},"bi":{"ak":["1","2"],"o":["2"],"c":["2"],"c.E":"2"},"by":{"t":["2"]},"h":{"r":["2"],"o":["2"],"c":["2"],"c.E":"2","r.E":"2"},"y":{"c":["1"],"c.E":"1"},"a4":{"t":["1"]},"am":{"c":["1"],"c.E":"1"},"aW":{"am":["1"],"o":["1"],"c":["1"],"c.E":"1"},"bC":{"t":["1"]},"bj":{"o":["1"],"c":["1"],"c.E":"1"},"bk":{"t":["1"]},"bQ":{"b5":[],"aR":[]},"bf":{"aN":["1","2"],"b7":["1","2"],"b1":["1","2"],"bW":["1","2"],"q":["1","2"]},"be":{"q":["1","2"]},"a_":{"be":["1","2"],"q":["1","2"]},"aO":{"c":["1"],"c.E":"1"},"bM":{"t":["1"]},"cg":{"M":[],"ai":[]},"aX":{"M":[],"ai":[]},"bz":{"u":[]},"cn":{"u":[]},"cy":{"u":[]},"M":{"ai":[]},"c2":{"M":[],"ai":[]},"c3":{"M":[],"ai":[]},"cw":{"M":[],"ai":[]},"cv":{"M":[],"ai":[]},"aV":{"M":[],"ai":[]},"cu":{"u":[]},"aj":{"w":["1","2"],"fJ":["1","2"],"q":["1","2"],"w.K":"1","w.V":"2"},"aJ":{"o":["1"],"c":["1"],"c.E":"1"},"bs":{"t":["1"]},"a2":{"o":["1"],"c":["1"],"c.E":"1"},"bt":{"t":["1"]},"bq":{"o":["F<1,2>"],"c":["F<1,2>"],"c.E":"F<1,2>"},"br":{"t":["F<1,2>"]},"b5":{"aR":[]},"cm":{"i7":[]},"cz":{"u":[]},"b6":{"u":[]},"aq":{"bR":["1"],"aM":["1"],"fM":["1"],"aL":["1"],"o":["1"],"c":["1"]},"aP":{"t":["1"]},"w":{"q":["1","2"]},"bO":{"o":["2"],"c":["2"],"c.E":"2"},"bP":{"t":["2"]},"b1":{"q":["1","2"]},"aN":{"b7":["1","2"],"b1":["1","2"],"bW":["1","2"],"q":["1","2"]},"bw":{"r":["1"],"o":["1"],"c":["1"],"c.E":"1","r.E":"1"},"bN":{"t":["1"]},"aM":{"aL":["1"],"o":["1"],"c":["1"]},"bR":{"aM":["1"],"aL":["1"],"o":["1"],"c":["1"]},"bJ":{"aM":["1"],"cE":["1"],"aL":["1"],"o":["1"],"c":["1"]},"cB":{"w":["e","@"],"q":["e","@"],"w.K":"e","w.V":"@"},"cC":{"r":["e"],"o":["e"],"c":["e"],"c.E":"e","r.E":"e"},"bp":{"u":[]},"co":{"u":[]},"af":{"R":["af"]},"b":{"L":[],"R":["L"]},"N":{"R":["N"]},"K":{"L":[],"R":["L"]},"x":{"o":["1"],"c":["1"]},"L":{"R":["L"]},"aL":{"o":["1"],"c":["1"]},"e":{"R":["e"]},"c0":{"u":[]},"bI":{"u":[]},"ae":{"u":[]},"bA":{"u":[]},"cf":{"u":[]},"bK":{"u":[]},"bE":{"u":[]},"c5":{"u":[]},"cq":{"u":[]},"bD":{"u":[]},"b2":{"ia":[]}}'))
A.is(v.typeUniverse,JSON.parse('{"bX":1,"c4":2,"c6":2}'))
var u=(function rtii(){var t=A.as
return{u:t("C"),w:t("R<@>"),d:t("a5"),x:t("af"),D:t("au"),Q:t("E"),F:t("k"),fR:t("a6"),gE:t("ah"),f:t("a0"),am:t("a7"),fu:t("N"),O:t("o<@>"),bU:t("u"),V:t("Q"),c5:t("av"),Z:t("ai"),t:t("c<C>"),ff:t("c<E>"),l:t("c<b>"),hf:t("c<@>"),ab:t("l<C>"),v:t("l<a5>"),g:t("l<k>"),q:t("l<ah>"),c:t("l<a0>"),b:t("l<x<b>>"),s:t("l<e>"),W:t("l<T>"),gI:t("l<an>"),h9:t("l<ac>"),dO:t("l<U>"),aS:t("l<aA>"),n:t("l<b>"),gn:t("l<@>"),dC:t("l<K>"),T:t("bn"),m:t("b_"),L:t("bo"),d9:t("bw<K>"),Y:t("x<C>"),B:t("x<k>"),J:t("x<a6>"),au:t("x<ah>"),gj:t("x<x<b>>"),dy:t("x<e>"),X:t("x<T>"),dr:t("x<an>"),cT:t("x<ac>"),e:t("x<U>"),ap:t("x<aA>"),o:t("x<b>"),j:t("x<@>"),k:t("F<e,q<e,m>>"),cC:t("q<e,E>"),h6:t("q<e,m>"),h:t("q<e,@>"),G:t("q<@,@>"),a:t("aK"),C:t("m"),p:t("aa"),A:t("X"),gT:t("jv"),bQ:t("+()"),fj:t("aL<Q>"),cq:t("aL<e>"),N:t("e"),K:t("T"),fo:t("an"),dm:t("ao"),ak:t("ay"),f4:t("bJ<Q>"),dA:t("y<a0>"),R:t("ac"),P:t("U"),E:t("aA"),y:t("j"),eF:t("j(a0)"),d1:t("j(T)"),_:t("j(U)"),i:t("b"),bk:t("b(a5)"),bE:t("b(k)"),z:t("@"),S:t("K"),r:t("k?"),eH:t("fF<aK>?"),an:t("b_?"),gJ:t("x<e>?"),bM:t("x<@>?"),fF:t("q<@,@>?"),U:t("m?"),gM:t("aL<Q>?"),dk:t("e?"),M:t("cD?"),fQ:t("j?"),cD:t("b?"),I:t("K?"),cg:t("L?"),H:t("L"),cA:t("~(e,@)")}})();(function constants(){var t=hunkHelpers.makeConstList
B.am=J.ci.prototype
B.a=J.l.prototype
B.c=J.bm.prototype
B.b=J.aZ.prototype
B.e=J.aI.prototype
B.an=J.b0.prototype
B.G=new A.aX(A.jm(),A.as("aX<b>"))
B.H=new A.cJ()
B.I=new A.cY()
B.J=new A.c8()
B.K=new A.dx()
B.L=new A.ca()
B.S=new A.ev()
B.N=new A.e1()
B.T=new A.ew()
B.P=new A.e5()
B.M=new A.dY()
B.t=new A.dV()
B.O=new A.bk(A.as("bk<0&>"))
B.u=new A.ch()
B.v=new A.ea()
B.Q=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.j=new A.ee()
B.R=new A.cq()
B.d=new A.et()
B.aP=new A.dU(0,"v1")
B.w=new A.bg(0,"actual")
B.U=new A.bg(1,"neutralNotApplicable")
B.V=new A.bg(2,"neutralInsufficient")
B.x=new A.aH(0,"stop")
B.h=new A.aH(1,"acceleration")
B.k=new A.aH(2,"deceleration")
B.f=new A.aH(3,"corner")
B.i=new A.aH(4,"cruise")
B.y=new A.a6(0,"unknown")
B.z=new A.a6(1,"stopped")
B.W=new A.a6(2,"accelerating")
B.X=new A.a6(3,"cruising")
B.Y=new A.a6(4,"decelerating")
B.Z=new A.a6(5,"cornering")
B.l=new A.a7(0,"cruiseDecelCruise")
B.m=new A.a7(1,"cruiseCornerCruise")
B.n=new A.a7(2,"accelerationCruise")
B.a_=new A.N(0)
B.a0=new A.N(12e7)
B.A=new A.N(15e5)
B.a1=new A.N(2e6)
B.a2=new A.N(3e6)
B.a3=new A.N(3e8)
B.a4=new A.N(5e6)
B.a5=new A.N(8e6)
B.a6=new A.Q(0,"stopped")
B.a7=new A.Q(1,"accelerating")
B.a8=new A.Q(2,"cruising")
B.a9=new A.Q(3,"decelerating")
B.o=new A.Q(4,"cornering")
B.aa=new A.Q(5,"freeFlow")
B.ab=new A.Q(6,"denseTraffic")
B.ac=new A.Q(7,"stopAndGo")
B.ad=new A.av(0,"stopping")
B.p=new A.av(1,"acceleration")
B.B=new A.av(2,"braking")
B.C=new A.av(3,"cornering")
B.D=new A.av(4,"cruising")
B.ae=new A.a1("Unsupported or unproven scoring contract",null)
B.af=new A.a1("Missing reliable telemetry evidence",null)
B.ag=new A.a1("Reliable timestamp evidence mismatch",null)
B.ah=new A.a1("Reliable source required",null)
B.ai=new A.a1("Unordered reliable telemetry",null)
B.aj=new A.a1("Legacy source cannot declare reliable scoring",null)
B.ak=new A.a1("Unsupported scoring source",null)
B.al=new A.a1("Timestamp precision evidence mismatch",null)
B.ao=new A.ef(null)
B.ap=new A.eg(null)
B.q=t([0,0],u.n)
B.av=t([20,0.25],u.n)
B.aB=t([50,0.58],u.n)
B.aA=t([80,0.83],u.n)
B.aq=t([120,1],u.n)
B.at=t([B.q,B.av,B.aB,B.aA,B.aq],u.b)
B.au=t([30,0.25],u.n)
B.aw=t([60,0.58],u.n)
B.aG=t([100,0.83],u.n)
B.ar=t([150,1],u.n)
B.ax=t([B.q,B.au,B.aw,B.aG,B.ar],u.b)
B.aD=t([],u.g)
B.aC=t([],u.q)
B.aE=t([],u.s)
B.E=t([],u.W)
B.az=t([80,0.33],u.n)
B.ay=t([140,0.67],u.n)
B.as=t([200,1],u.n)
B.aF=t([B.q,B.az,B.ay,B.as],u.b)
B.aH=t([B.l,B.m,B.n],A.as("l<a7>"))
B.r={}
B.aR=new A.a_(B.r,[],A.as("a_<e,b>"))
B.aS=new A.a_(B.r,[],A.as("a_<e,@>"))
B.aI=new A.bG(!1)
B.aJ=new A.b3(0,"unknown")
B.F=new A.an(B.aJ,0,0)
B.aK=new A.b3(1,"freeFlow")
B.aL=new A.b3(2,"denseTraffic")
B.aM=new A.b3(3,"stopAndGo")
B.aT=new A.a_(B.r,[],A.as("a_<a7,K>"))
B.aQ=t([],u.c)
B.aN=new A.cx(0,!1,!1)
B.aO=A.jr("m")})();(function staticFields(){$.V=A.n([],A.as("l<m>"))
$.fQ=null
$.fy=null
$.fx=null
$.eQ=A.n([],A.as("l<x<m>?>"))})();(function lazyInitializers(){var t=hunkHelpers.lazyFinal
t($,"jt","hu",()=>A.ho("_$dart_dartClosure"))
t($,"js","fs",()=>A.ho("_$dart_dartClosure_dartJSInterop"))
t($,"jH","hG",()=>A.n([new J.cj()],A.as("l<bB>")))
t($,"jw","hw",()=>A.ap(A.eH({
toString:function(){return"$receiver$"}})))
t($,"jx","hx",()=>A.ap(A.eH({$method$:null,
toString:function(){return"$receiver$"}})))
t($,"jy","hy",()=>A.ap(A.eH(null)))
t($,"jz","hz",()=>A.ap(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"jC","hC",()=>A.ap(A.eH(void 0)))
t($,"jD","hD",()=>A.ap(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"jB","hB",()=>A.ap(A.h1(null)))
t($,"jA","hA",()=>A.ap(function(){try{null.$method$}catch(s){return s.message}}()))
t($,"jF","hF",()=>A.ap(A.h1(void 0)))
t($,"jE","hE",()=>A.ap(function(){try{(void 0).$method$}catch(s){return s.message}}()))
t($,"ju","hv",()=>A.i8("^([+-]?\\d{4,6})-?(\\d\\d)-?(\\d\\d)(?:[ T](\\d\\d)(?::?(\\d\\d)(?::?(\\d\\d)(?:[.,](\\d+))?)?)?( ?[zZ]| ?([-+])(\\d\\d)(?::?(\\d\\d))?)?)?$"))
t($,"jG","f4",()=>A.hr(B.aO))})();(function nativeSupport(){!function(){var t=function(a){var n={}
n[a]=1
return Object.keys(hunkHelpers.convertToFastObject(n))[0]}
v.getIsolateTag=function(a){return t("___dart_"+a+v.isolateTag)}
var s="___dart_isolate_tags_"
var r=Object[s]||(Object[s]=Object.create(null))
var q="_ZxYxX"
for(var p=0;;p++){var o=t(q+"_"+p+"_")
if(!(o in r)){r[o]=1
v.isolateTag=o
break}}}()
hunkHelpers.setOrUpdateInterceptorsByTag({})
hunkHelpers.setOrUpdateLeafTags({})})()
Function.prototype.$0=function(){return this()}
Function.prototype.$1=function(a){return this(a)}
Function.prototype.$2=function(a,b){return this(a,b)}
Function.prototype.$3=function(a,b,c){return this(a,b,c)}
Function.prototype.$4=function(a,b,c,d){return this(a,b,c,d)}
Function.prototype.$1$1=function(a){return this(a)}
Function.prototype.$2$1=function(a){return this(a)}
Function.prototype.$2$0=function(){return this()}
convertAllToFastObject(w)
convertToFastObject($);(function(a){if(typeof document==="undefined"){a(null)
return}if(typeof document.currentScript!="undefined"){a(document.currentScript)
return}var t=document.scripts
function onLoad(b){for(var r=0;r<t.length;++r){t[r].removeEventListener("load",onLoad,false)}a(b.target)}for(var s=0;s<t.length;++s){t[s].addEventListener("load",onLoad,false)}})(function(a){v.currentScript=a
var t=A.jl
if(typeof dartMainRunner==="function"){dartMainRunner(t,[])}else{t([])}})})()
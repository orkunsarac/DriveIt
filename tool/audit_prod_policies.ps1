$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root
$ref='arwnbogcswisfesayosy'
$containers=@(docker ps --format '{{.Names}}'|Where-Object {$_ -match '^supabase-pgr4a-atomic-pgr4a-atomic-20261031-database-[a-f0-9]+$'})
if($containers.Count -ne 1){throw 'Ambiguous isolated atomic DB'}
$container=$containers[0]
$query=@'
SET LOCAL search_path=pg_catalog;
select json_build_object(
'tables',(select json_agg(x order by x.name) from (select c.relname as name,c.relrowsecurity as rls,c.relforcerowsecurity as force_rls,
 (select json_agg(json_build_object('role',r,'privilege',v,'allowed',has_table_privilege(r,c.oid,v)) order by r,v) from unnest(array['anon','authenticated','service_role']) r cross join unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) v) as grants
 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r')x),
'policies',(select json_agg(x order by x.schemaname,x.tablename,x.policyname) from (select schemaname,tablename,policyname,permissive,roles,cmd,qual,with_check from pg_policies where schemaname in ('public','storage','realtime'))x),
'functions',(select json_agg(x order by x.signature) from (select p.oid::regprocedure::text as signature,p.prosecdef as definer,p.proconfig as config,pg_get_functiondef(p.oid) as definition,
 has_function_privilege('anon',p.oid,'EXECUTE') as anon,has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated,has_function_privilege('service_role',p.oid,'EXECUTE') as service_role,
 exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where a.grantee=0 and a.privilege_type='EXECUTE') as public_execute
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f' and not exists(select 1 from pg_depend d where d.classid='pg_proc'::regclass and d.objid=p.oid and d.deptype='e'))x))::text;
'@
$mount=docker inspect --format '{{range .HostConfig.Mounts}}{{if eq .Target "/var/lib/postgresql/data"}}{{.VolumeOptions.Subpath}}{{end}}{{end}}' $container
if($LASTEXITCODE -ne 0 -or $mount -cne 'instance-0527455996a5a2c0295e371a39519b3e5e54b6d2e65ce98628e97e84db16793f-83de82a7-3c4a-4cda-8bac-c80ba124bbc0/data'){throw 'Local physical target mismatch'}
$system=docker exec $container psql -U postgres -d postgres -X -At -c 'select system_identifier from pg_control_system();'
if($LASTEXITCODE -ne 0 -or $system -cne '7702852553093967913'){throw 'Local cluster identity mismatch'}
$artifact='tmp/pgr5-policy-audit.sql'
& 'C:\Users\PC\.deno\bin\deno.exe' run --allow-read --allow-write=tmp tool/build_prod_transaction.ts $artifact
if($LASTEXITCODE -ne 0){throw 'Source hash/order check failed'}
$bundle=Get-Content -Raw -LiteralPath $artifact
if($bundle -notmatch '(?i)COMMIT;\s*$'){throw 'Unexpected outer transaction end'}
$sql=$bundle -replace '(?i)COMMIT;\s*$',($query+"`nROLLBACK;")
$out=@($sql|docker exec -i $container psql -U postgres -d postgres -X -At -v ON_ERROR_STOP=1)
if($LASTEXITCODE -ne 0){throw 'Expected catalog generation failed'}
$start=-1;$end=-1
for($i=0;$i -lt $out.Count;$i++){if($out[$i].StartsWith('{"tables"')){$start=$i};if($out[$i] -ceq 'ROLLBACK'){$end=$i}}
if($start -lt 0 -or $end -le $start){throw 'Expected catalog result ambiguous'}
$expected=($out[$start..($end-1)] -join "`n")|ConvertFrom-Json
$empty=docker exec $container psql -U postgres -d postgres -X -At -c "select count(*) from pg_class where relnamespace='public'::regnamespace and relkind='r';"
if($LASTEXITCODE -ne 0 -or $empty -cne '0'){throw 'Expected catalog transaction did not rollback cleanly'}
$cred=Import-Clixml 'C:\Users\PC\.driveit-secrets\supabase-prod-pat.clixml'
$token=$cred.GetNetworkCredential().Password
try {
 $headers=@{Authorization=('Bearer '+$token)}
 $body=@{query=$query;read_only=$true}|ConvertTo-Json -Compress
 $response=Invoke-WebRequest -Method Post -Uri ('https://api.supabase.com/v1/projects/'+$ref+'/database/query') -Headers $headers -ContentType 'application/json' -Body $body
 if([int]$response.StatusCode -ne 201){throw 'Unexpected catalog HTTP status'}
 $rows=@($response.Content|ConvertFrom-Json)
 if($rows.Count -ne 1){throw 'Actual catalog result ambiguous'}
 $actual=$rows[0].json_build_object|ConvertFrom-Json
} finally {$token=$null;$headers=$null;$cred=$null;$body=$null}
$dir='tmp/pgr5-policy-evidence'
New-Item -ItemType Directory -Path $dir -Force|Out-Null
$expected|ConvertTo-Json -Depth 100|Set-Content "$dir/expected.json" -Encoding utf8
$actual|ConvertTo-Json -Depth 100|Set-Content "$dir/actual.json" -Encoding utf8
$lines=[Collections.Generic.List[string]]::new()
$lines.Add('# P-GR5 PROD RPC/RLS güvenlik sözleşmesi denetimi')
$lines.Add('')
$lines.Add('Hedef: `'+$ref+'`. Kaynak: manifest hash/sıra kontrolünden geçen 25 migration, doğrulanmış izole PostgreSQL üzerinde tek transaction içinde uygulandı; katalog alındı ve ROLLBACK yapıldı. PROD yalnız read_only=true Management API katalog sorgusuyla okundu (HTTP 201). Gerçek kullanıcı satırı okunmadı.')
$lines.Add('Denetim zamanı (UTC): '+[DateTime]::UtcNow.ToString('o')+'. Yerel rollback sonrasında public tablo sayısı 0 doğrulandı. Fonksiyon imzalarının şema gösterimini sabitlemek için iki katalog sorgusunda da transaction kapsamlı search_path=pg_catalog kullanıldı.')
$lines.Add('Kaynak manifest: supabase/prod/preparation_manifest.json. Karşılaştırma aracı: tool/audit_prod_policies.ps1. Aşağıda her nesne için beklenen ve gerçek katalog değerleri gösterilir. Fonksiyon gövdesi de karşılaştırıldığı için owner/Auth/gate denetimlerinin kaynakla eşleşmesi kapsamdadır; sentetik kullanıcılı davranış testi bu raporun kapsamı dışındadır.')
$fail=0
foreach($category in @('tables','policies','functions')){
 $lines.Add('');$lines.Add('## '+$category)
 $key=if($category -eq 'tables'){'name'}elseif($category -eq 'functions'){'signature'}else{'policyname'}
 foreach($e in $expected.$category){
  $matches=@($actual.$category|Where-Object {$_.$key -ceq $e.$key -and ($category -ne 'policies' -or ($_.schemaname -ceq $e.schemaname -and $_.tablename -ceq $e.tablename))})
  $ej=$e|ConvertTo-Json -Depth 100 -Compress
  $aj=if($matches.Count -eq 1){$matches[0]|ConvertTo-Json -Depth 100 -Compress}else{'MISSING_OR_AMBIGUOUS'}
  $pass=$ej -ceq $aj
  if(!$pass){$fail++}
  $lines.Add('');$lines.Add('### '+$e.$key+' — '+$(if($pass){'PASS'}else{'FAIL'}))
  $lines.Add('Beklenen:');$lines.Add('```json');$lines.Add($ej);$lines.Add('```')
  $lines.Add('Gerçek:');$lines.Add('```json');$lines.Add($aj);$lines.Add('```')
 }
 if(@($actual.$category).Count -ne @($expected.$category).Count){$fail++;$lines.Add('FAIL: beklenen/gerçek nesne sayısı farklı.')}
}
$lines.Insert(3,('Genel sözleşme eşleşmesi: '+$(if($fail -eq 0){'PASS'}else{'FAIL'})+'. Uyuşmazlık sayısı: '+$fail+'. Fonksiyon gövdeleri, SECURITY DEFINER/INVOKER, proconfig/search_path ve dört rolün EXECUTE yetkileri birebir karşılaştırılmıştır.'))
$lines.Add('');$lines.Add('## Owner izolasyonu ve erişim yorumu')
$lines.Add('profiles: authenticated SELECT tüm profillere açıktır (USING true); UPDATE yalnız auth.uid()=id. Bu kişisel sürüş/rota erişimi vermez; tüm profil kolonlarının hesaplar arasında okunması kaynak tasarımının açık gizlilik özelliğidir.')
$lines.Add('world_publishes: authenticated INSERT yalnız kendi user_id ve pending statüsü; SELECT yalnız kendi user_id. world_validated_roads kendi user_id; world_validated_road_sections ilişkili road.user_id üzerinden owner denetimi uygular. Kesin ifadeler policy kayıtlarında yer alır.')
$lines.Add('Diğer 14 public tablo: RLS açık, istemci policy yok; anon/authenticated doğrudan SELECT kapalıdır. Tüm INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER yetkileri de beklenen katalogla karşılaştırıldı. Kişisel sürüş ve grup işlemleri güvenlik denetimli RPC/Edge akışından yürür. Service role RLS bypass yetkisine sahip güvenilir sunucu rolüdür; istemciye verilmemelidir.')
$lines.Add('Storage: world-drive-sources INSERT bucket ve ilk owner klasörüyle; phase8-drive-staging INSERT bucket ve phase8_can_access_staging_object fonksiyonuyla sınırlandırılır. İstemciye SELECT/UPDATE/DELETE policy eklenmemiştir; private bucket içeriğine doğrudan genel okuma yolu bu politikalarda yoktur.')
$lines.Add('Realtime: SELECT için broadcast ve phase8_group_topic_authorized; grup topicleri için ek restrictive üyelik fence; istemci INSERT için grup topicini reddeden restrictive fence beklenenle eşleşir. Yetkilendirme fonksiyonu gövdesi gate ve üyelik kurallarıyla birlikte birebir eşleşir. Mevcut kanal yetki önbelleğinin anlık iptali bu statik incelemeyle kanıtlanmaz.')
$lines.Add('Kritik RPC: kişisel sürüş mutasyon/okuma uçları service_role ile sınırlandırılır; group_command authenticated erişimi gövde içi auth.uid/üyelik denetimine dayanır. is_username_available anonim erişimi kullanıcı adı uygunluğu içindir. Trigger fonksiyonlarının PUBLIC EXECUTE durumu kaynakla karşılaştırılmıştır; trigger dönüş tipli fonksiyonlar genel veri sorgu RPCsi olarak yorumlanmamıştır.')
$lines.Add('## Migration kaynakları')
foreach($entry in (Get-Content supabase/prod/preparation_manifest.json -Raw|ConvertFrom-Json).files|Where-Object kind -eq 'migration'){$lines.Add('- '+$entry.path+' — SHA-256 '+$entry.sha256)}
$lines.Add('');$lines.Add('Sınır: PASS kaynak migration ile eşleşmeyi kanıtlar; migration tasarımının her ürün/hukuk gereksinimini karşıladığı veya gerçek cihaz kabulünün geçtiği anlamına gelmez. Authenticated profil SELECT USING(true) kaynak sözleşmesidir; profil alanlarının ürün gizlilik kapsamı ayrıca değerlendirilmelidir.')
$lines|Set-Content docs/prod_pgr5_policy_audit.md -Encoding utf8
"Audit complete: tables=$(@($expected.tables).Count), policies=$(@($expected.policies).Count), functions=$(@($expected.functions).Count), mismatches=$fail"
if($fail -ne 0){exit 2}

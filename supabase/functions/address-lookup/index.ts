const SITE="https://fkevin4969-creator.github.io";
const PUBLIC_KEY="sb_publishable_tGKO1cNzfOecGn0JhdzO-w_2z8omEPp";
const allowed=new Set([SITE,"https://localhost","http://localhost","capacitor://localhost"]);
Deno.serve(async(req)=>{
 const origin=req.headers.get("origin")||"";
 const cors={"Access-Control-Allow-Origin":allowed.has(origin)?origin:SITE,"Access-Control-Allow-Headers":"apikey,authorization,content-type,x-client-info","Access-Control-Allow-Methods":"POST,OPTIONS","Vary":"Origin"};
 const reply=(body,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json","Cache-Control":"no-store"}});
 if(req.method==="OPTIONS")return new Response(null,{status:204,headers:cors});
 if(req.method!=="POST")return reply({error:"Method not allowed"},405);
 // Custom project-key validation; publishable keys are not JWTs.
 if(req.headers.get("apikey")!==PUBLIC_KEY||!allowed.has(origin))return reply({error:"Not permitted"},403);
 const key=Deno.env.get("IDEAL_POSTCODES_API_KEY")?.trim();
 if(!key)return reply({error:"Address lookup is not configured"},503);
 try{
 const data=await req.json();const action=data.action;
 if(action!=="search"&&action!=="resolve")return reply({error:"Invalid action"},400);
 const query=String(data.query||"").trim(),id=String(data.id||"");
 if(action==="search"&&(query.length<2||query.length>160))return reply({error:"Enter an address or postcode"},400);
 if(action==="resolve"&&!/^[a-zA-Z0-9_-]{1,120}$/.test(id))return reply({error:"Invalid address"},400);
 const ip=req.headers.get("x-forwarded-for")?.split(",")[0].trim()||"unknown";
 const digest=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(ip));
 const client=Array.from(new Uint8Array(digest)).map(x=>x.toString(16).padStart(2,"0")).join("");
 const secret=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")||Object.values(JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS")||"{}"))[0];
 if(!secret)return reply({error:"Address lookup is unavailable"},503);
 const quota=await fetch(Deno.env.get("SUPABASE_URL")+"/rest/v1/rpc/address_lookup_take_quota",{method:"POST",headers:{"apikey":String(secret),"Authorization":"Bearer "+secret,"Content-Type":"application/json"},body:JSON.stringify({p_kind:action,p_client:client}),signal:AbortSignal.timeout(8000)});
 if(!quota.ok)return reply({error:"Address lookup is unavailable"},503);
 if(await quota.json()!==true)return reply({error:"Address lookup trial limit reached. Please enter the address manually."},429);
 const url=new URL("https://api.ideal-postcodes.co.uk/v1/autocomplete/addresses"+(action==="resolve"?"/"+encodeURIComponent(id)+"/gbr":""));
 url.searchParams.set("api_key",key);
 if(action==="search"){url.searchParams.set("query",query);url.searchParams.set("context","GBR");url.searchParams.set("bias_lonlat","-0.178,51.1743,24140");url.searchParams.set("limit","50");}
 const upstream=await fetch(url,{signal:AbortSignal.timeout(10000)});
 const json=await upstream.json();
 if(!upstream.ok||json.code!==2000)return reply({error:"Address lookup unavailable. Please enter the address manually.",provider_code:json.code},502);
 if(action==="search")return reply({hits:(json.result?.hits||[]).map(x=>({id:x.id,suggestion:x.suggestion}))});
 const a=json.result,lat=Number(a.latitude),lon=Number(a.longitude);
 const address=[a.line_1,a.line_2,a.line_3,a.post_town,a.postcode].filter(Boolean).join(", ");
 return reply({address,postcode:a.postcode,lat:Number.isFinite(lat)&&a.latitude!=null?lat:null,lon:Number.isFinite(lon)&&a.longitude!=null?lon:null});
 }catch{return reply({error:"Address lookup unavailable. Please enter the address manually."},503);}
});
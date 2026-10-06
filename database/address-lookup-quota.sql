create schema if not exists private;
create table if not exists private.address_lookup_usage(bucket text primary key, used integer not null default 0);
alter table private.address_lookup_usage enable row level security;
revoke all on private.address_lookup_usage from public,anon,authenticated;
grant usage on schema private to service_role;
grant select,insert,update on private.address_lookup_usage to service_role;
create or replace function public.address_lookup_take_quota(p_kind text,p_client text) returns boolean
language plpgsql security invoker set search_path='' as $$
declare k text; n int; lim int; keys text[]; limits int[];
begin
 if p_kind not in ('search','resolve') or p_client !~ '^[a-f0-9]{64}$' then return false;end if;
 perform pg_advisory_xact_lock(756024190);
 keys:=array['ip:'||p_client||':'||to_char(now() at time zone 'UTC','YYYYMMDDHH24MI'),'search:'||to_char(now() at time zone 'UTC','YYYYMMDD')];
 limits:=array[30,1000];
 if p_kind='resolve' then
 keys:=keys||array['resolve-day:'||to_char(now() at time zone 'UTC','YYYYMMDD'),'resolve-month:'||to_char(now() at time zone 'UTC','YYYYMM')];
 limits:=limits||array[20,50];
 end if;
 for i in 1..array_length(keys,1) loop
 select used into n from private.address_lookup_usage where bucket=keys[i];
 if coalesce(n,0)>=limits[i] then return false; end if;
 end loop;
 for i in 1..array_length(keys,1) loop
 insert into private.address_lookup_usage(bucket,used) values(keys[i],1) on conflict(bucket) do update set used=private.address_lookup_usage.used+1;
 end loop;
 return true;
end $$;
revoke all on function public.address_lookup_take_quota(text,text) from public,anon,authenticated;
grant execute on function public.address_lookup_take_quota(text,text) to service_role;
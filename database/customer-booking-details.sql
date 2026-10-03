create schema if not exists private;
create or replace function private.customer_booking_details()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 return coalesce((select jsonb_agg(to_jsonb(q) order by q.pickup_time desc) from (
 select b.id,b.pickup_address,b.destination_address,b.pickup_time,b.booking_status,b.fare_estimate,b.fare,
 case when b.booking_status in ('assigned','accepted','arrived','passenger_on_board') then d.full_name end as driver_name,
 case when b.booking_status in ('assigned','accepted','arrived','passenger_on_board') then coalesce(v.make,d.vehicle_make,d."Vehicale-make") end as vehicle_make,
 case when b.booking_status in ('assigned','accepted','arrived','passenger_on_board') then v.model end as vehicle_model,
 case when b.booking_status in ('assigned','accepted','arrived','passenger_on_board') then v.colour end as vehicle_colour,
 case when b.booking_status in ('assigned','accepted','arrived','passenger_on_board') then coalesce(v.registration,d.vehicle_registration) end as vehicle_registration,
 b.driver_id is not null and b.booking_status in ('assigned','accepted','arrived','passenger_on_board') as driver_allocated
 from public.bookings b join public.customers c on c.id=b.customer_id
 left join public.drivers d on d.id=b.driver_id
 left join lateral (select vv.* from public.vehicles vv where (vv.id=b.vehicle_id and vv.driver_id=b.driver_id) or (b.vehicle_id is null and vv.driver_id=b.driver_id and vv.active=true) order by (vv.id=b.vehicle_id) desc nulls last,vv.created_at desc limit 1) v on true
 where c.auth_user_id=auth.uid() order by b.pickup_time desc limit 30
 ) q),'[]'::jsonb);
end $$;
revoke all on function private.customer_booking_details() from public,anon;
grant usage on schema private to authenticated;
grant execute on function private.customer_booking_details() to authenticated;
create or replace function public.customer_get_my_bookings()
returns jsonb language sql stable security invoker set search_path=''
as $$ select private.customer_booking_details() $$;
revoke all on function public.customer_get_my_bookings() from public,anon;
grant execute on function public.customer_get_my_bookings() to authenticated;
notify pgrst,'reload schema';
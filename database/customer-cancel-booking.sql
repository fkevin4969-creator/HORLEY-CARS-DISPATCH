create or replace function private.customer_cancel_booking(p_booking_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare b public.bookings;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 select bb.* into b from public.bookings bb join public.customers c on c.id=bb.customer_id where bb.id=p_booking_id and c.auth_user_id=auth.uid() for update of bb;
 if not found then raise exception 'Booking not found'; end if;
 if b.booking_status='cancelled' then return true; end if;
 if b.booking_status not in ('pending','dispatching','assigned','accepted','arrived') then raise exception 'This booking can no longer be cancelled in the app. Please contact Horley Cars.'; end if;
 update public.bookings set booking_status='cancelled',driver_id=null,updated_at=now() where id=b.id;
 insert into public.dispatch_events(booking_id,event_type,message) values(b.id,'booking_cancelled','Customer cancelled booking before pickup');
 return true;
end $$;
revoke all on function private.customer_cancel_booking(uuid) from public,anon;
grant execute on function private.customer_cancel_booking(uuid) to authenticated;
create or replace function public.customer_cancel_my_booking(p_booking_id uuid)
returns boolean language sql security invoker set search_path='' as $$ select private.customer_cancel_booking(p_booking_id) $$;
revoke all on function public.customer_cancel_my_booking(uuid) from public,anon;
grant execute on function public.customer_cancel_my_booking(uuid) to authenticated;
notify pgrst,'reload schema';
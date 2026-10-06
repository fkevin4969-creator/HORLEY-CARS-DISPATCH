create or replace function public.dispatch_assign_driver(p_booking_id uuid,p_driver_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare b public.bookings%rowtype;
begin
 select * into b from public.bookings where id=p_booking_id for update;
 if not found then raise exception 'Booking not found'; end if;
 if b.booking_status not in ('pending','dispatching','assigned','accepted','arrived') then raise exception 'Cannot assign this job after passenger pickup or closure'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_driver_id::text,0));
 if not exists(select 1 from public.drivers where id=p_driver_id) then raise exception 'Driver not found'; end if;
 if exists(select 1 from public.bookings where driver_id=p_driver_id and id<>p_booking_id and booking_status in ('assigned','accepted','arrived','passenger_on_board')) then raise exception 'That driver already has an active job'; end if;
 if b.driver_id=p_driver_id then return; end if;
 update public.bookings set driver_id=p_driver_id,booking_status='assigned',updated_at=now() where id=p_booking_id;
 if b.driver_id is not null then
 update public.drivers set status='available' where id=b.driver_id and status<>'offline' and not exists(select 1 from public.bookings where driver_id=b.driver_id and booking_status in ('assigned','accepted','arrived','passenger_on_board'));
 end if;
 insert into public.dispatch_events(booking_id,driver_id,event_type,message) values(p_booking_id,p_driver_id,'driver_assigned',case when b.driver_id is null then 'Driver assigned by dispatcher' else 'Job reassigned by dispatcher' end);
end $$;
create or replace function public.dispatch_update_booking_status(p_booking_id uuid,p_new_status text)
returns void language plpgsql security definer set search_path='' as $$
declare b public.bookings%rowtype;
begin
 if p_new_status not in ('assigned','accepted','arrived','passenger_on_board','completed','cancelled') then raise exception 'Invalid booking status'; end if;
 select * into b from public.bookings where id=p_booking_id for update;
 if not found then raise exception 'Booking not found'; end if;
 if b.booking_status=p_new_status then return; end if;
 if b.booking_status in ('cancelled','completed') then raise exception 'This job is already closed'; end if;
 if p_new_status='cancelled' and b.booking_status='passenger_on_board' then raise exception 'Cannot cancel while the passenger is on board'; end if;
 if p_new_status='assigned' and b.booking_status='passenger_on_board' then raise exception 'Cannot reassign while the passenger is on board'; end if;
 update public.bookings set booking_status=p_new_status,driver_id=case when p_new_status='cancelled' then null else driver_id end,updated_at=now() where id=p_booking_id;
 if p_new_status='cancelled' then
 update public.drivers set status='available' where id=b.driver_id and status<>'offline' and not exists(select 1 from public.bookings where driver_id=b.driver_id and booking_status in ('assigned','accepted','arrived','passenger_on_board'));
 insert into public.dispatch_events(booking_id,driver_id,event_type,message) values(p_booking_id,b.driver_id,'booking_cancelled','Job cancelled by dispatcher');
 end if;
end $$;
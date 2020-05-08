-- 6. Definiți un subprogram stocat care să utilizeze un tip de colecție studiat. Apelați subprogramul.
create or replace 
procedure print_hotels_with_min_rating(min_rating number)
is
    type hotel_name IS table of hotels.hotel_name%type;
    hotel_names hotel_name;
begin
    select hotel_name
    bulk collect into hotel_names
    from hotels
    where rating >= min_rating;
    
    for i in 1..hotel_names.count
    loop
        dbms_output.put_line(hotel_names(i) );
    end loop;
end;
/
begin
    print_hotels_with_min_rating(4);
end;
/

-- 7. Definiți un subprogram stocat care să utilizeze un tip de cursor studiat. Apelați subprogramul.
create or replace
procedure rename_hotel(p_hotel_id IN hotels.hotel_id%TYPE, p_hotel_name IN hotels.hotel_name%TYPE)
is
begin
    update hotels
    set hotel_name = p_hotel_name
    where hotel_id = p_hotel_id;

    -- Cursor implicit
    if SQL%NOTFOUND then
        dbms_output.put_line('There is no hotel with and id of: ' || p_hotel_id);
    else
        dbms_output.put_line('Renamed hotel to ' || p_hotel_name);
    end if;
end;
/

begin
    rename_hotel(1, '5 star hotel');
end;
/

-- 8. Definiți un subprogram stocat de tip funcție care să utilizeze 3 dintre tabelele definite. Tratați toate
-- excepțiile care pot apărea. Apelați subprogramul astfel încât să evidențiați toate cazurile tratate
create or replace
function get_cheapest_accomodation_near_sight(p_sight_name sights.sight_name%type)
    return number
is
    v_room_id number;
begin
    select room_id
    into v_room_id
    from (
        select room_id, price
        from rooms
        where hotel_id in (
            select h.hotel_id 
            from nearby_sights ns
            join sights s on s.sight_id = ns.sight_id
            join hotels h on h.hotel_id = ns.hotel_id
            where s.sight_name = p_sight_name
        )
        group by room_id, price
        having price = (
            select min(price)
            from rooms
        )
    );
    
    return v_room_id;
    
exception
    when NO_DATA_FOUND then
        dbms_output.put_line('There is no accomodation near ' || p_sight_name);
        return null;
    when TOO_MANY_ROWS then
        dbms_output.put_line('There is more than one accomodation near ' || p_sight_name);
        return null;
end;
/

begin
    dbms_output.put_line(get_cheapest_accomodation_near_sight('sight 2'));
    dbms_output.put_line(get_cheapest_accomodation_near_sight('sight 3'));
    dbms_output.put_line(get_cheapest_accomodation_near_sight('sight 4'));
end;
/

-- 9. Definiți un subprogram stocat de tip procedură care să utilizeze 5 dintre tabelele definite. Tratați toate
-- excepțiile care pot apărea. Apelați subprogramul astfel încât să evidențiați toate cazurile tratate.

-- Utilizatorul care a stat in camera cea mai scumpa cand a vizitat un anumit obiectiv
create or replace
procedure dsiplay_email_of_the_user_who_booked_the_most_expensive_room_near_sight(p_sight_name sights.sight_name%type)
is
    user_email varchar(250);
begin
    select u.email
    into user_email
    from rooms r
    join hotels h on h.hotel_id = r.hotel_id
    join bookings b on b.room_id = r.room_id
    join app_users u on u.user_id = b.user_id
    where h.hotel_id in (
        select h.hotel_id
        from nearby_sights ns
        join sights s on s.sight_id = ns.sight_id
        join hotels h on h.hotel_id = ns.hotel_id
        where s.sight_name = p_sight_name
    )
    group by u.email, r.price
    having r.price = (
        select max(price)
        from rooms
    );
    
    dbms_output.put_line(user_email);
    
exception
    when NO_DATA_FOUND then
        dbms_output.put_line('There is no user who booked the most expensive room near ' || p_sight_name);
    when TOO_MANY_ROWS then
        dbms_output.put_line('There is more than one user who booked the most expensive room near' || p_sight_name);
end;
/

begin
    dsiplay_email_of_the_user_who_booked_the_most_expensive_room_near_sight('sight 1');
    dsiplay_email_of_the_user_who_booked_the_most_expensive_room_near_sight('sight 2');
    dsiplay_email_of_the_user_who_booked_the_most_expensive_room_near_sight('sight 3');
    dsiplay_email_of_the_user_who_booked_the_most_expensive_room_near_sight('sight 4');
    dsiplay_email_of_the_user_who_booked_the_most_expensive_room_near_sight('sight 5');
    dsiplay_email_of_the_user_who_booked_the_most_expensive_room_near_sight('sight 6');
    dsiplay_email_of_the_user_who_booked_the_most_expensive_room_near_sight('sight 7');
    dsiplay_email_of_the_user_who_booked_the_most_expensive_room_near_sight('sight 8');
end;
/

-- 10. Definiți un trigger de tip LMD la nivel de comandă. Declanșați trigger-ul
create or replace 
trigger stop_bookings
    before insert or delete or update on bookings
declare
    today date;
begin
    select sysdate
    into today 
    from dual;
    
    if today between to_date('15/03/2020', 'DD/MM/YYYY') and to_date('15/05/2020', 'DD/MM/YYYY') then
        raise_application_error(-20020, 'Sorry we do not during lockdown');
    end if;
end;
/

insert into bookings(room_id, user_id, beginDate, endDate) values (8, 5, to_date('20-11-2020', 'dd-mm-yyyy'), to_date('26-11-2020', 'dd-mm-yyyy'));

-- 11. Definiți un trigger de tip LMD la nivel de linie. Declanșați trigger-ul.

create or replace 
trigger prevent_overlapping_bookings
before insert or update on bookings
for each row
declare
    v_booking_id number;
begin
    dbms_output.put_line(:new.room_id);

    select booking_id
    into v_booking_id
    from bookings
    where room_id = :new.room_id and (
      (begindate between :new.beginDate and :new.endDate or
      (enddate between :new.beginDate and :new.endDate) or
      (:new.beginDate between begindate  and  enddate) or 
      (:new.endDate between begindate  and  enddate)
    ));

    raise_application_error(-20030, 'room is already booked during between these dates');
    
exception
    when NO_DATA_FOUND then
     dbms_output.put_line('inserted booking');
    when TOO_MANY_ROWS then
     raise_application_error(-20030, 'room is already booked during between these dates');
end;
/

insert into bookings(room_id, user_id, beginDate, endDate) values (8, 2, to_date('11-07-2020', 'dd-mm-yyyy'), to_date('14-07-2020', 'dd-mm-yyyy'));
insert into bookings(room_id, user_id, beginDate, endDate) values (8, 3, to_date('11-07-2020', 'dd-mm-yyyy'), to_date('14-07-2020', 'dd-mm-yyyy'));


-- 12. Definiți un trigger de tip LDD. Declanșați trigger-ul
-- droppped table history

create or replace 
trigger lock_tables
before alter or drop on schema
begin
    raise_application_error(-20040, 'Tables can no longer be motified');
end;
/

drop table sights;


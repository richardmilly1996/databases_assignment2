create index if not exists idx_opt_orders_order_date
    on opt_orders(order_date);

create index if not exists idx_opt_orders_product_id
    on opt_orders(product_id);

create index if not exists idx_opt_orders_client_id
    on opt_orders(client_id);

create index if not exists idx_opt_clients_status
    on opt_clients(status);

---OPTIMIZED QUERY:

explain analyze
with filtered_orders as (
    select
        o.order_id,
        o.order_date,
        p.product_id,
        p.product_name,
        c.id as client_id
    from opt_orders as o
    join opt_products as p
        on o.product_id = p.product_id
    join opt_clients as c
        on o.client_id = c.id
    where o.order_date > date '2025-12-01'
      and c.status = 'active'
),
cnt_products as (
    select
        product_name,
        count(*) as cnt
    from filtered_orders
    group by product_name
),
ranked_products as (
    select
        product_name,
        cnt,
        row_number() over (order by cnt asc, product_name asc) as min_rn,
        row_number() over (order by cnt desc, product_name asc) as max_rn
    from cnt_products
)
select
    max(concat(product_name, ': ', cnt)) filter (where min_rn = 1) as min_cnt,
    max(concat(product_name, ': ', cnt)) filter (where max_rn = 1) as max_cnt
from ranked_products;


---UNOPTIMIZED QUERY:

explain analyze
select
    (select concat(p.product_name, ': ', count(*))
     from opt_orders as o
     join opt_products as p on o.product_id = p.product_id
     join opt_clients as c on o.client_id = c.id
     where o.order_date > date '2025-12-01'
       and c.status = 'active'
     group by p.product_name
     order by count(*) asc, p.product_name asc
     limit 1) as min_cnt,
    (select concat(p.product_name, ': ', count(*))
     from opt_orders as o
     join opt_products as p on o.product_id = p.product_id
     join opt_clients as c on o.client_id = c.id
     where o.order_date > date '2025-12-01'
       and c.status = 'active'
     group by p.product_name
     order by count(*) desc, p.product_name asc
     limit 1) as max_cnt;

---DIFFERENCE: Optimized: execution time: 98.468 ms (on test)
            ---Unoptimized: 218.289 ms (on test)